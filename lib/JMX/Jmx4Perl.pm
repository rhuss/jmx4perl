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

$VERSION = "0.01_01";

my $REGISTRY = {
                # Agent base
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

=item $resp = $jmx->get_attribute($object_name,$attribute,$path) 

=item $resp = $jmx->get_attribute({ domain => <domain>, properties => { <key>
=> value }, attribute => <attribute>, path => <path>)

=cut 

sub get_attribute {
    my $self = shift;
    my ($object,$attribute,$path);
    if (ref($_[0]) eq "HASH") {
        $object = $_[0]->{object};
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

    $self->_get_attribute($object,$attribute,$path);
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

sub init {
    # Do nothing by default
}

# abstract method
sub _get_attribute {
    croak "Internal: Must be overwritten by a subclass";
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
