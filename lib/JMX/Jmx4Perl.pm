#!/usr/bin/perl

=head1 NAME 

JMX::Jmx4Perl - Access to JMX via Perl

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 METHODS

=over

=cut

package JMX::Jmx4Perl;

use Carp;
use JMX::Jmx4Perl::Request;

$VERSION = "0.01_02";

my $REGISTRY = {
                # Agent based
                "agent" => "JMX::Jmx4Perl::Agent",
                "JMX::Jmx4Perl::Agent" => "JMX::Jmx4Perl::Agent",
                "JJAgent" => "JMX::Jmx4Perl::Agent",
               };

=item $jmx = JMX::Jmx4Perl->new(mode => <access module>, ....)

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

=item $resp => $jmx_get_attribute(...)

  $resp = $jmx->get_attribute($mbean,$attribute,$path) 
  $resp = $jmx->get_attribute({ domain => <domain>, 
                                properties => { <key> => value }, 
                                attribute => <attribute>, 
                                path => <path>)

Read a JMX attribute. In the first form, you provide the MBean name, the
attribute name and an optional path as positional arguments. The second
variant uses named parameters from a hashref. 

The Mbean name can be specified with the canoncial name (key C<mbean), or with
a domain name (key C<domain>) and one or more properties (key C<properties> or
C<props>) which contain key-value pairs in a Hashref. For more about naming 
of MBeans please refer to L<http://java.sun.com/j2se/1.5.0/docs/api/javax/management/ObjectName.html>
for more information about JMX naming.

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
    return $self->request($request);
}

=item $resp = $jmx->request($request)

Send a request to the underlying agent and return the response. This is an
abstract method which needs to be overwritten by a subclass. The argument must
be of type L<JMX::Jmx4Perl::Request> and it returns an object of type
L<JMX::Jmx4Perl::Response> 

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

=AUTHOR

roland@cpan.org

=cut

1;
