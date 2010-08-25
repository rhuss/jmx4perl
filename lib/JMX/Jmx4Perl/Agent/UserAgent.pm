#!/usr/bin/perl

# Helper package in order to provide credentials
# in the request
package JMX::Jmx4Perl::Agent::UserAgent;
use base qw(LWP::UserAgent);

=head1 NAME

JMX::Jmx4Perl::Agent::UserAgent - Specialized L<LWP::UserAgent> adding
authentication support

=head1 DESCRIPTION

Simple subclass implementing an own C<get_basic_credentials> method for support
of basic and proxy authentication. This is an internal class used by
L<JMX::Jmx4Perl::Agent>. 

=cut 

sub jjagent_config { 
    my $self = shift;
    $self->{jjagent_config} = shift;
}

sub get_basic_credentials { 
    my ($self, $realm, $uri, $isproxy) = @_;

    my $cfg = $self->{jjagent_config} || {};
    my $user = $isproxy ? $self->proxy_cfg($cfg,"user") : $cfg->{user};
    my $password = $isproxy ? $self->proxy_cfg($cfg,"password") : $cfg->{password};
    if ($user && $password) {
        return ($user,$password);
    } else {
        return (undef,undef);
    }
}

sub proxy_cfg {
    my ($self,$cfg,$what) = @_;
    my $proxy = $cfg->{proxy};
    if (ref($proxy) eq "HASH") {
        return $proxy->{$what};
    } else {
        return $cfg->{"proxy_" . $what};
    }
}

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
