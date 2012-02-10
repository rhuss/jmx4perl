#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Jolokia::WebXmlHandler;

=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::WebXmlHandler - Handler for web.xml 
transformation 

=head1 DESCRIPTION

This module is repsonsible for various manipulations on a F<web.xml> descriptor
as found in JEE WAR archives. It uses L<XML::LibXML> for the dirty work, and
L<XML::Tidy> to clean up after the manipulation. The later module is optional,
but recommended. 

=head1 METHODS

=over 4 

=cut

use Data::Dumper;
use vars qw($HAS_LIBXML $HAS_XML_TWIG);
use strict;

# Trigger for <login-config>
my $REALM = "Jolokia";

# Class used as proxy dispatcher
my $JSR_160_PROXY_CLASS = "org.jolokia.jsr160.Jsr160RequestDispatcher";

BEGIN {
    $HAS_LIBXML = eval "require XML::LibXML; use XML::LibXML::XPathContext; 1";
    $HAS_XML_TWIG = eval "require XML::Twig; 1";
}

=item $handler = JMX::Jmx4Perl::Agent::Jolokia::WebXmlHandler->new(%args)

Creates a new handler. The following arguments can be used:

  "logger"     Logger to use

=cut

sub new { 
    my $class = shift;
    my %args = @_;
    my $self = {logger => $args{logger}};
    bless $self,(ref($class) || $class);

    $self->_fatal("No XML::LibXML found. Please install it to allow changes and queries on web.xml") unless $HAS_LIBXML;

    return $self;
}

=item $handler->add_security($webxml,{ role => $role })

Add a security constraint to the given web.xml. This triggers on the realm
"Jolokia" on the loging-config and the URL-Pattern "/*" for the security
mapping. Any previous sections are removed and replaced.

C<$role> is the role to insert.

This method returns the updated web.xml as a string.

=cut

sub add_security {
    my $self = shift;
    my $webxml = shift;
    my $args = shift;

    my $doc = XML::LibXML->load_xml(string => $webxml);
    
    my $parent = $doc->getDocumentElement;
    $self->_remove_security_elements($doc);

    $self->_create_login_config($doc,$parent);
    $self->_create_security_constraint($doc,$parent,$args->{role});
    $self->_create_security_role($doc,$parent,$args->{role});
    $self->_info("Added security mapping for role ","[em]",$args->{role},"[/em]");    
    return $self->_cleanup_doc($doc);
}

=item $handler->remove_security($webxml)

Remove login-config with Realm "Jolokia" and security constraint to 
"/*" along with the associated role definit. Return the updated web.xml 
as string.

=cut

sub remove_security {
    my $self = shift;
    my $webxml = shift;

    my $doc = XML::LibXML->load_xml(string => $webxml);

    $self->_remove_security_elements($doc);
    $self->_info("Removed security mapping");
    
    return $self->_cleanup_doc($doc);
}

=item $handler->add_jsr160_proxy($webxml)

Adds a JSR-160 proxy declaration which is contained as init-param of the
servlet definition ("dispatcherClasses"). If the init-param is missing, a new
is created otherwise an existing is updated. Does nothing, if the init-param
"dispatcherClasses" already contains the JSR 160 dispacher.

Returns the updated web.xml as string.

=cut

sub add_jsr160_proxy {
    my $self = shift;
    my $webxml = shift;

    my $doc = XML::LibXML->load_xml(string => $webxml);
    my @init_params = $self->_init_params($doc,"dispatcherClasses");
    if (!@init_params) {
        $self->_add_jsr160_proxy($doc);
        $self->_info("Added JSR-160 proxy");
    } elsif (@init_params == 1) {
        my $param = $init_params[0];
        my ($value,$classes) = $self->_extract_dispatcher_classes($init_params[0]);
        unless (grep { $_ eq $JSR_160_PROXY_CLASS } @$classes) {
            $self->_update_text($value,join(",",@$classes,$JSR_160_PROXY_CLASS));
            $self->_info("Added JSR-160 proxy");
        } else {
            $self->_info("JSR-160 proxy already active");
            return undef;
        }
    } else {
        # Error
        $self->_fatal("More than one init-param 'dispatcherClasses' found");
    }

    return $self->_cleanup_doc($doc);
}

=item $handler->remove_jsr160_proxy($webxml)

Removes a JSR-160 proxy declaration which is contained as init-param of the
servlet definition ("dispatcherClasses"). Does nothing, if the init-param
"dispatcherClasses" already doese not contain the JSR 160 dispacher.

Returns the updated web.xml as string.

=cut

sub remove_jsr160_proxy {
    my $self = shift;
    my $webxml = shift;
    
    my $doc = XML::LibXML->load_xml(string => $webxml);
    my @init_params = $self->_init_params($doc,"dispatcherClasses");
    if (!@init_params) {
        $self->info("No JSR-160 proxy active");
        return undef;
    } elsif (@init_params == 1) {
        my ($value,$classes) = $self->_extract_dispatcher_classes($init_params[0]);
        if (grep { $_ eq $JSR_160_PROXY_CLASS } @$classes) {
            $self->_update_text($value,join(",",grep { $_ ne $JSR_160_PROXY_CLASS } @$classes));
            $self->_info("Removed JSR-160 proxy");
        } else {
            $self->_info("No JSR-160 proxy active");
            return undef;
        }
    } else {
        $self->_fatal("More than one init-param 'dispatcherClasses' found");
    }

    return $self->_cleanup_doc($doc);
}

=item $handler->find($webxml,$xquery)

Find a single element with a given XQuery query. Croaks if more than one
element is found. Returns either C<undef> (nothing found) or the matched
node's text content.

=cut

sub find {
    my $self = shift;
    my $webxml = shift;
    my $query = shift;

    my $doc = XML::LibXML->load_xml(string => $webxml);
    
    my @nodes = $self->_find_nodes($doc,$query);
    $self->_fatal("More than one element found matching $query") if @nodes > 1;
    return @nodes == 0 ? undef : $nodes[0]->textContent;
}

=item $handler->has_authentication($webxml)

Checks, whether authentication is switched on.

=cut

sub has_authentication {
    my $self = shift;
    my $webxml = shift;
    
    $self->find
      ($webxml,
       "//j2ee:security-constraint[j2ee:web-resource-collection/j2ee:url-pattern='/*']/j2ee:auth-constraint/j2ee:role-name");
}

=item $handler->has_jsr160_proxy($webxml)

Checks, whether a JSR-160 proxy is configured.

=cut

sub has_jsr160_proxy {
    my $self = shift;
    my $webxml = shift;

    my $doc = XML::LibXML->load_xml(string => $webxml);

    my @init_params = $self->_init_params($doc,"dispatcherClasses");
    if (@init_params > 1) {
        $self->_fatal("More than one dispatcherClasses init-param found");
    } elsif (@init_params == 1) {
        my $param = $init_params[0];
        my ($value,$classes) = $self->_extract_dispatcher_classes($init_params[0]);
        return grep { $_ eq $JSR_160_PROXY_CLASS } @$classes;
    } else {
        return 0;
    }
}

# =============================================================================== 

sub _remove_security_elements {
    my $self = shift;
    my $doc = shift;
    my $role = shift;

    $self->_remove_login_config($doc);
    my $role = $self->_remove_security_constraint($doc);
    $self->_remove_security_role($doc,$role);
}

sub _create_login_config {
    my $self = shift;
    my $doc = shift;
    my $parent = shift;
    my $l = _e($doc,$parent,"login-config");
    _e($doc,$l,"auth-method","BASIC");
    _e($doc,$l,"realm-name",$REALM);
}

sub _create_security_constraint {
    my $self = shift;
    my $doc = shift; 
    my $parent = shift;
    my $role = shift;

    my $s = _e($doc,$parent,"security-constraint");
    my $w = _e($doc,$s,"web-resource-collection");
    _e($doc,$w,"web-resource-name","Jolokia-Agent Access");
    _e($doc,$w,"url-pattern","/*");
    my $a = _e($doc,$s,"auth-constraint");
    _e($doc,$a,"role-name",$role);
}

sub _create_security_role {
    my $self = shift;
    my $doc = shift; 
    my $parent = shift;
    my $role = shift;

    my $s = _e($doc,$parent,"security-role");
    _e($doc,$s,"role-name",$role);
}

sub _remove_security_constraint {
    my $self = shift;
    my $doc = shift;

    my @s = $doc->getElementsByTagName("security-constraint");
    for my $s (@s) {
        my @r = $s->getElementsByTagName("role-name");
        my $role;
        for my $r (@r) {
            $role = $r->textContent;
        }
        my @u = $s->getElementsByTagName("url-pattern");
        for my $u (@u) {
            if ($u->textContent eq "/*") {
                $s->parentNode->removeChild($s);
                return $role;                
            }
        }
    }    
}

sub _remove_login_config {
    my $self = shift;
    my $doc = shift;

    my @l = $doc->getElementsByTagName("realm-name");
    for my $l (@l) {
        if ($l->textContent eq $REALM) {
            my $toRemove = $l->parentNode;
            $toRemove->parentNode->removeChild($toRemove);
            return;
        }
    }
}

sub _remove_security_role {
    my $self = shift;
    my $doc = shift;
    my $role = shift;

    my @s = $doc->getElementsByTagName("security-role");
    for my $s (@s) {
        my @r = $s->getElementsByTagName("role-name");
        for my $r (@r) {
            if ($r->textContent eq $role) {
                $s->parentNode->removeChild($s);
                return;                
            }
        }
    }        
}

sub _init_params {
    my $self = shift;
    my $doc = shift;
    my $param_name = shift;

    return $self->_find_nodes
      ($doc,
       "/j2ee:web-app/j2ee:servlet[j2ee:servlet-name='jolokia-agent']/j2ee:init-param[j2ee:param-name='$param_name']");
}

sub _extract_dispatcher_classes {
    my $self = shift;
    my $param = shift;

    my @values = $self->_find_nodes($param,"j2ee:param-value");
    $self->_fatal("No or more than one param-value found") if (!@values || @values > 1);
    my $value = $values[0];
    my $content = $value->textContent();
    my @classes = split /\s*,\s*/,$content;
    return ($value,\@classes);
}

sub _update_text {
    my $self = shift;
    my $el = shift;
    my $value = shift;

    my $parent = $el->parentNode;
    $parent->removeChild($el);
    $parent->appendTextChild($el->nodeName,$value);
}

sub _add_jsr160_proxy {
    my $self = shift;
    my $doc = shift;
    my @init_params = $self->_find_nodes
      ($doc,
       "/j2ee:web-app/j2ee:servlet[j2ee:servlet-name='jolokia-agent']/j2ee:init-param");
    my $first = $init_params[0] || $self->_fatal("No init-params found");
    my $new_init = $doc->createElement("init-param");
    _e($doc,$new_init,"param-name","dispatcherClasses");
    _e($doc,$new_init,"param-value",$JSR_160_PROXY_CLASS);        
    $first->parentNode->insertBefore($new_init,$first);
}

sub _find_nodes {
    my $self = shift;
    my $doc = shift;
    my $query = shift;

    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs('j2ee', 'http://java.sun.com/xml/ns/j2ee');
    return $xpc->findnodes($query,$doc);
}

sub _e {
    my $doc = shift;
    my $parent = shift;
    my $e = $doc->createElement(shift);
    my $c = shift;
    if ($c) {
        $e->appendChild($doc->createTextNode($c));
    }
    $parent->appendChild($e);
    return $e;
}

sub _cleanup_doc {
    my $self = shift;
    my $doc = shift;
    if ($HAS_XML_TWIG) {
        my $ret = XML::Twig->nparse_pp($doc->toString)->toString(1);
        #print $ret;
        return $ret;
    } else {
        return $doc->toString(1);
    }
}

sub _fatal {
    my $self = shift;
    $self->{logger}->error(@_);
    die "\n";
}

sub _info {
    my $self = shift;
    $self->{logger}->info(@_);
}

=back 

=head1 LICENSE

This file is part of jmx4perl.
Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
The Free Software Foundation, either version 2 of the License, or
(at your option) any later version.
 
jmx4perl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License
along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 AUTHOR

roland@cpan.org

=cut

1;
