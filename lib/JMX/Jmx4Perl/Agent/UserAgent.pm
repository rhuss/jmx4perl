#!/usr/bin/perl

# Helper package in order to provide credentials
# in the request

package JMX::Jmx4Perl::Agent::UserAgent;
use vars qw(@ISA);
@ISA = qw(LWP::UserAgent);

sub jjagent_config { 
    my $self = shift;
    $self->{jjagent_config} = shift;
}

sub get_basic_credentials { 
    my ($self, $realm, $uri, $isproxy) = @_;

    my $cfg = $self->{jjagent_config} || {};
    my $user = $isproxy ? $cfg->{proxy_user} : $cfg->{user};
    my $password = $isproxy ? $cfg->{proxy_password} : $cfg->{password};

    if ($user && $password) {
        return ($user,$password);
    } else {
        return (undef,undef);
    }
}

# This file is part of jmx4perl.
# Jmx4perl is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
# 
# jmx4perl is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

1;
