#!/usr/bin/perl

=head1 NAME 

JMX::Jmx4Perl - Access to JMX via Perl

=head1 SYNOPSIS
   
   my $jmx = new JMX::Jmx4Perl(url => "http://localhost:8080/j4p-agent");
   my $request = new JMX::Jmx4Perl::Request(type => READ_ATTRIBUTE,
                                            mbean => "java.lang:type=Memory",
                                            attribute => "HeapMemoryUsage",
                                            path => "used");
   my $response = $jmx->request($request);
   print "Memory used: ",$response->value(),"\n";

=head1 DESCRIPTION

Jmx4Perl is here to connect the Java and Perl Enterprise world by providing
transparent access to the Java Management Extensions (JMX) from the perl side. 

It uses a traditional request-response paradigma for performing JMX operations
on a remote Java Virtual machine. 

There a various ways how JMX information can be transfered. For now, a single
operational mode is supported. It is based on an I<agent>, a small (<30k) Java
Servlet, which needs to deployed on a Java application server. It plays the
role of a proxy, which on one side communicates with the MBeans server in the
application server and transfers JMX related information via HTPP and JSON to
the client (i.e. this module). Please refer to L<JMX::Jmx4Perl::Manual> for
installation instructions howto deploy the agent servlet (which can be found in
the distribution at F<agent/j4p-agent.war>).

An alternative, and more 'java like' approach, is the usage of JSR 160
connectors. The default connectors provided by the Java Virtual Machine (JVM)
since version 1.5 support only propriertary protocols which require serialized
Java objects to be exchanged. This implies that a JVM needs to be started on
the client side, adding quite some overhead if used from within
perl. Nevertheless, plans are underway to support this operational mode as
well, which allows for monitoring of Java application which are not running in
a servlet container.

For further discussion comparing both approaches, please refer to
L<JMX::Jmx4Perl::Manual> 

JMX itself knows about the following operations on so called I<MBeans>, which
are specific "managed beans" designed for JMX and providing access to
management functions:

=over

=item * 

Reading an writing of attributes of an MBean (like memory usage or connected
users) 

=item *

Executing of exposed operations (like triggering a garbage collection)

=item * 

Registering of notifications which are send from the application server to a
listener when a certain event happens.

=back

For now only reading of attributes are supported, but development has start to
support writing of attributes and executing of JMX operations. Notification
support might come (or not ;-)

=head1 METHODS

=over

=cut

package JMX::Jmx4Perl;

use Carp;
use JMX::Jmx4Perl::Request;
use strict;
use vars qw($VERSION);
use Data::Dumper;

$VERSION = "0.01_04";

my $REGISTRY = {
                # Agent based
                "agent" => "JMX::Jmx4Perl::Agent",
                "JMX::Jmx4Perl::Agent" => "JMX::Jmx4Perl::Agent",
                "JJAgent" => "JMX::Jmx4Perl::Agent",
               };

=item $jmx = JMX::Jmx4Perl->new(mode => <access module>, ....)

Create a new instance. The call is dispatched to an Jmx4Perl implementation by
selecting an appropriate mode. For now, the only mode supported is "agent",
which uses the L<JMX::Jmx4Perl::Agent> backend. Hence, the mode can be
submitted for now.

Any other named parameters are interpreted by the backend, please refer to its
documentation for details (i.e. L<JMX::Jmx4Perl::Agent>)

=cut

sub new {
    my $class = shift;
    my $cfg = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    
    my $mode = delete $cfg->{mode} || &autodiscover_mode();
    $class = $REGISTRY->{$mode} || croak "Unknown runtime mode " . $mode;
    eval "require $class";
    croak "Cannot load $class: $@" if $@;

    my $self = { 
                cfg => $cfg,
             };
    bless $self,(ref($class) || $class);
    $self->init();
    return $self;
}

# ==========================================================================

=item $resp => $jmx->get_attribute(...)

  $value = $jmx->get_attribute($mbean,$attribute,$path) 
  $value = $jmx->get_attribute({ domain => <domain>, 
                                properties => { <key> => value }, 
                                attribute => <attribute>, 
                                path => <path>)

Read a JMX attribute. In the first form, you provide the MBean name, the
attribute name and an optional path as positional arguments. The second
variant uses named parameters from a hashref. 

The Mbean name can be specified with the canoncial name (key C<mbean>), or with
a domain name (key C<domain>) and one or more properties (key C<properties> or
C<props>) which contain key-value pairs in a Hashref. For more about naming of
MBeans please refer to
L<http://java.sun.com/j2se/1.5.0/docs/api/javax/management/ObjectName.html> for
more information about JMX naming.

This method returns the value as it is returned from the server

=cut 

sub get_attribute {
    my $self = shift;
    my ($object,$attribute,$path);
    if (ref($_[0]) eq "HASH") {
        $object = $_[0]->{mbean};
        if (!$object && $_[0]->{domain} && ($_[0]->{properties} || $_[0]->{props})) {
            $object = $_[0]->{domain} . ":";
            my $href = $_[0]->{properties} || $_[0]->{props};
            croak "'properties' is not a hashref" unless ref($href);
            for my $k (keys %{$href}) {
                $object .= $k . "=" . $href->{$k};
            }
        }
        $attribute = $_[0]->{attribute};
        $path = $_[0]->{path};
    } else {
        ($object,$attribute,$path) = @_;
    }
    croak "No object name provided" unless $object;
    croak "No attribute provided for object $object" unless $attribute;

    my $request = JMX::Jmx4Perl::Request->new(READ_ATTRIBUTE,$object,$attribute,$path);
    my $response = $self->request($request);
    return $response->value;
}

=item $value = $jmx->list($path)

Get all MBeans as registered at the specified server. A C<$path> can be
specified in order to fetchy only a subset of the information. When no path is
given, the returned value has the following format

  $value = { 
              <domain> => 
              { 
                <canonical property list> => 
                { 
                    "attr" => 
                    { 
                       <atrribute name> => 
                       {
                          desc => <description of attribute>
                          type => <java type>, 
                          rw => true/false 
                       }, 
                       .... 
                    },
                    "op" => 
                    { 
                       <operation name> => 
                       { 
                         desc => <description of operation>
                         ret => <return java type>
                         args => [{ desc => <description>, name => <name>, type => <java type>}, .... ]
                       },
                       ....
                },
                .... 
              }
              .... 
           };

A complete path has the format C<"<domain>/<property
list>/("attribute"|"operation")/<index>"> (e.g. C<java.lang/name=Code
Cache,type=MemoryPool/attribute/0>). A path can be provided partially, in which
case the remaining map/array is returned.

=cut

sub list {
    my $self = shift;
    my $path = shift;

    my $request = JMX::Jmx4Perl::Request->new(LIST_MBEANS,$path);
    my $response = $self->request($request);
    return $response->value;    
}


=item $formatted_text = $jmx->formatted_list($path)

=item $formatted_text = $jmx->formatted_list($resp)

Get the a formatted string representing the MBeans as returnded by C<list()>.
C<$path> is the optional inner path for selecting only a subset of all mbean.
See C<list()> for more details. If called with a L<JMX::Jmx4Perl::Response>
object, the list will be taken from the provided response object and not
fetched from the server

=cut

sub formatted_list {
    my $self = shift;
    my $path_or_resp = shift;
    my $path;
    my $list;
    
    if ($path_or_resp && UNIVERSAL::isa($path_or_resp,"JMX::Jmx4Perl::Response")) {
        $path = $path_or_resp->request->get("path");
        $list = $path_or_resp->value;
    } else {
        $path = $path_or_resp;
        $list = $self->list($path);
    }
    
    my @path = ();
    @path = split m|/|,$path if $path;
    croak "A path can be used only for a domain name or MBean name" if @path > 2;
    my $intent = "";

    my $ret = &_format_map("",$list,\@path,0);
}

my $SPACE = 4;
my @SEPS = (":");
sub _format_map { 
    my ($ret,$map,$path,$level) = @_;
    
    my $p = shift @$path;
    my $sep = $SEPS[$level] ? $SEPS[$level] : "";
    if ($p) {
        $ret .= "$p".$sep;
        if (!@$path) {
            my $s = length($ret);
            $ret .= "\n".("=" x length($ret))."\n\n";
        }
        $ret = &_format_map($ret,$map,$path,$level);
    } else {
        for my $d (keys %$map) {
            $ret .= &_get_space($level).$d.$sep."\n" unless ($d eq "attr" || $d eq "op");
            my @args = ($ret,$map->{$d},$path);
            if ($d eq "attr") {
                $ret = &_format_attr_or_op(@args,$level,"attr","Attributes",\&_format_attribute);
            } elsif ($d eq "op") {
                $ret = &_format_attr_or_op(@args,$level,"op","Operations",\&_format_operation);
            } else {
                $ret = &_format_map(@args,$level+1);
                if ($level == 0) {
                    $ret .= "-" x 80 . "\n";
                } elsif ($level == 1) {
                    $ret .= "\n";
                }
            }
        }
    }
    return $ret;
}

sub _format_attr_or_op {
    my ($ret,$map,$path,$level,$top_key,$label,$format_sub) = @_;

    my $p = shift @$path;
    if ($p eq $top_key) {
        $p = shift @$path;
        if ($p) {
            $ret .= " ".$p."\n";
            return &$format_sub($ret,$p,$map->{$p},$level);
        } else {
            $ret .= " $label:\n";
        }
    } else {
        $ret .= &_get_space($level)."$label:\n";
    }
    for my $key (keys %$map) {
        $ret = &$format_sub($ret,$key,$map->{$key},$level+1);
    }
    return $ret;
}

sub _format_attribute {
    my ($ret,$name,$attr,$level) = @_;
    $ret .= &_get_space($level);
    $ret .= sprintf("%-35s %s\n",$name,$attr->{type}.(!$attr->{rw} ? " [ro]" : "").", \"".$attr->{desc}."\"");
    return $ret;
}

sub _format_operation {
    my ($ret,$name,$op,$level) = @_;
    $ret .= &_get_space($level);
    my $method = &_format_method($name,$op->{args},$op->{ret});
    $ret .= sprintf("%-35s \"%s\"\n",$method,$op->{desc});
    return $ret;
}

sub _format_method { 
    my ($name,$args,$ret_type) = @_;
    my $ret = $ret_type." ".$name."(";
    if ($args) {
        for my $a (@$args) {
            $ret .= $a->{type} . " " . $a->{name} . ",";
        }
        chop $ret if @$args;
    }
    $ret .= ")";
    return $ret;
}

sub _get_space {
    my $level = shift;
    return " " x ($level * $SPACE);
}

=item $resp = $jmx->request($request)

Send a request to the underlying agent and return the response. This is an
abstract method which needs to be overwritten by a subclass. The argument must
be of type L<JMX::Jmx4Perl::Request> and it returns an object of type
L<JMX::Jmx4Perl::Response>.

=cut 

sub request {
    croak "Internal: Must be overwritten by a subclass";    
}

sub cfg {
    my $self = shift;
    my $key = shift;
    my $val = shift;
    my $ret = $self->{cfg}->{$key};
    if (defined $val) {
        $self->{cfg}->{$key} = $val;
    }
    return $ret;
}

# ==========================================================================
# Methods used for overwriting

# Init method called during construction
sub init {
    # Do nothing by default
}

# ==========================================================================
#

sub autodiscover_mode {

    # For now, only *one* mode is supported. Additional
    # could be added (like calling up a local JVM)
    return "agent";
}

=back

=head1 ROADMAP

=over

=item * 

Suport for writing attributes 

=item * 

Support for executing JMX operations

=item *

Providing aliases for common MBean Attributes, which can be used for any
application server

=item *

JSR-160 access to a remote JMX Mbean-Server, which requires integration of a
JVM (with something like L<Java::Import>)

=back

=head1 LICENSE

This file is part of jmx4perl.

Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

jmx4perl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

=head1 AUTHOR

roland@cpan.org

=cut

1;
