#!/usr/bin/perl

# Helper package in order to provide credentials
# in the request
package JMX::Jmx4Perl::Agent::UserAgent;
use base qw(LWP::UserAgent);

use Sys::SigAction;

use vars qw($HAS_BLOWFISH_PP $BF);
use strict;

BEGIN {
    $HAS_BLOWFISH_PP = eval "require Crypt::Blowfish_PP; 1";
    if ($HAS_BLOWFISH_PP) {
        $BF = new Crypt::Blowfish_PP(pack("C10",0x16,0x51,0xAE,0x13,0xF2,0xFA,0x11,0x20,0x6E,0x6A));
    }
}


=head1 NAME

JMX::Jmx4Perl::Agent::UserAgent - Specialized L<LWP::UserAgent> adding
authentication support

=head1 DESCRIPTION

Simple subclass implementing an own C<get_basic_credentials> method for support
of basic and proxy authentication. This is an internal class used by
L<JMX::Jmx4Perl::Agent>. 

=cut 


# Constructor setting the proper SSL options (if possible)
sub new {
    my $class = shift;
    my @opts = @_ || ();
    if (LWP::UserAgent->VERSION >= 6.00) {
        # We don't verify Hostnames by default, since the information we are
        # sending is typically not critical. Also, we don't have yet a way to 
        # configure a keystore, so this is the only chance for now. Ask me to add
        # host certificate verification if wanted. It disabled only for LWP >= 6.00        
        push @opts,(ssl_opts => { verify_hostname => 0 });
    };
    return $class->SUPER::new(@opts);
}

# Request using a more robust timeout See
# http://stackoverflow.com/questions/73308/true-timeout-on-lwpuseragent-request-method 
# for details.
sub request {
    my $self = shift;
    my $req = shift;

    # Get whatever timeout is set for LWP and use that to 
    # enforce a maximum timeout per request.
    use Sys::SigAction qw(timeout_call);
    our $res = undef;
    if (timeout_call($self->timeout(), sub { $res = $self->SUPER::request($req); })) {
        # 408 == HTTP timeout
        my $ret = HTTP::Response->new(408,"Got timeout in " . $self->timeout() . "s "); 
        $ret->request($req);
        return $ret;
    } else {
        return $res;
    }

}

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
        return ($user,$self->conditionally_decrypt($password));
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

sub conditionally_decrypt { 
    my $self = shift;
    my $password = shift;
    if ($password =~ /^\[\[\s*(.*)\s*\]\]$/) {
        # It's a encrypted password, lets decrypt it here
        return decrypt($1);
    } else {
        return $password;
    }
}

sub decrypt {
    my $encrypted = shift;
    die "No encryption available. Please install Crypt::Blowfish_PP" unless $HAS_BLOWFISH_PP;
    my $rest = $encrypted; 
    my $ret = "";
    while (length($rest) > 0) {
        my $block = substr($rest,0,16);
        $rest = substr($rest,16);
        $ret .= $BF->decrypt(pack("H*",$block));
    }
    $ret =~ s/\s*$//;
    return $ret;
}

sub encrypt {
    my $plain = shift;    
    die "No encryption available. Please install Crypt::Blowfish_PP" unless $HAS_BLOWFISH_PP;
    my $rest = $plain; 
    my $ret = "";
    while (length($rest) > 0) {
        my $block = substr($rest,0,8);
        if (length($block) < 8) { 
            $block .= " " x (8 - length($block));
        }
        $rest = substr($rest,8);
        $ret .= unpack("H*",$BF->encrypt($block));
    }
    return $ret;
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

__DATA__
