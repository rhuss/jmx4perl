#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Manager::WebXmlHandler;

=head1 NAME

JMX::Jmx4Perl::Agent::Manager::WebXmlHandler - Handler for web.xml 
transformation 

=cut

use Data::Dumper;
use vars qw($HAS_LIBXML $HAS_XML_TIDY $ADD_SECURITY_XSL);
use strict;

my $REALM = "Jolokia";

BEGIN {
    $HAS_LIBXML = eval "require XML::LibXML; use XML::LibXML::XPathContext; 1";
    $HAS_XML_TIDY = eval "require XML::Tidy; 1";
}

&init_xsl();

sub new { 
    my $class = shift;
    my %args = @_;
    my $file = $args{file};
    my $self = {logger => $args{logger}, meta => $args{meta}};
    bless $self,(ref($class) || $class);
    return $self;
}

sub transform {
    my $self = shift;
    my $xsl = shift;    
    my $to_transform = shift;
    my $args = shift;

    my $xslt = XML::LibXSLT->new();
    
    my $source = XML::LibXML->load_xml(string => $to_transform);       
    my $stylesheet = $xslt->parse_stylesheet(XML::LibXML->load_xml(string => $xsl));
    
    my $results = $stylesheet->transform($source, XML::LibXSLT::xpath_to_string(%$args));
    return $results->toString(1);        
}

sub add_security {
    my $self = shift;
    my $webxml = shift;
    my $args = shift;
    $self->_info("Added security mapping for role ","[em]",$args->{role},"[/em]");

    my $doc = XML::LibXML->load_xml(string => $webxml);
    
    my $parent = $doc->getDocumentElement;
    $self->_remove_security_elements($doc);

    $self->_create_login_config($doc,$parent);
    $self->_create_security_constraint($doc,$parent,$args->{role});
    $self->_create_security_role($doc,$parent,$args->{role});
    
    return $self->_cleanup_doc($doc);
}

sub remove_security {
    my $self = shift;
    my $webxml = shift;

    my $doc = XML::LibXML->load_xml(string => $webxml);
    $self->_remove_security_elements($doc);
    $self->_info("Removed security mapping");
    
    return $self->_cleanup_doc($doc);
}

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
    if ($HAS_XML_TIDY) {
        my $ret = new XML::Tidy(xml => $doc->toString())->tidy->toString();
        return $ret;
    } else {
        return $doc->toString(1);
    }
}

# Check via XPath for an element and return its text value or undef if not 
# found
sub find {
    my $self = shift;
    my $webxml = shift;
    my $query = shift;

    $self->_fatal("No XML::LibXML found. Please install it to allow queries on web.xml") unless $HAS_LIBXML;

    my $doc = XML::LibXML->load_xml(string => $webxml);
    my $xpc = XML::LibXML::XPathContext->new;
    $xpc->registerNs('j2ee', 'http://java.sun.com/xml/ns/j2ee');
    my @nodes = $xpc->findnodes($query,$doc);
    $self->_fatal("More than one element found matching $query") if @nodes > 1;
    return @nodes == 0 ? undef : $nodes[0]->textContent;
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


sub init_xsl {
    $ADD_SECURITY_XSL =<<'EOT';
<?xml version="1.0"?>
<xsl:stylesheet version="2.0"
  xmlns="http://java.sun.com/xml/ns/j2ee"
  xmlns:j2ee="http://java.sun.com/xml/ns/j2ee"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes" />
  <xsl:template match="j2ee:servlet-mapping[last()]">
    <xsl:param name="role"/>

    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>


    <xsl:comment><xsl:value-of select="$role"/></xsl:comment>
    <login-config>
      <auth-method>BASIC</auth-method>
      <realm-name>Jolokia</realm-name>
    </login-config>

    <security-constraint>
      <web-resource-collection>
        <web-resource-name>Jolokia-Agent Access</web-resource-name>
        <url-pattern>/*</url-pattern>
      </web-resource-collection>
      <auth-constraint>
        <role-name></role-name>
      </auth-constraint>
    </security-constraint>

    <security-role>
      <role-name></role-name>
    </security-role>
  </xsl:template>
  
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
EOT
}

1;
