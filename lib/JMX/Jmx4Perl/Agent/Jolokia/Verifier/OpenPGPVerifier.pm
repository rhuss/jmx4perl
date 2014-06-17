#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Jolokia::Verifier::OpenPGPVerifier;

use JMX::Jmx4Perl::Agent::Jolokia::Verifier::PGPKey;
use Crypt::OpenPGP::KeyRing;
use Crypt::OpenPGP;
use Module::Find;
use Data::Dumper;
use Cwd 'abs_path';

use strict;

=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::Verifier::OpenPGPVerifier - Verifies PGP
signature with L<Crypt::OpenPGP>

=head1 DESCRIPTION

This verifier uses L<Crypt::OpenPGP> for validating a PGP signature obtained
from the download site. Ie. each URL used for download should have (and does
have) and associated signature ending with F<.asc>. This verifier typically
quite robust, however installing L<Crypt::OpenPGP> is a bit clumsy, so you
might omit this one.

=head1 IMPORTANT

It is not used currently since the new agents has been signed with 'digest
algortihm 10' which is not supported by OpenPGP. Use a native GnuPG instead
(i.e. a 'gpg' which is in the path)

=cut 

sub new { 
    my $class = shift;
    my $self = {};
    $self->{keyring} = $JMX::Jmx4Perl::Agent::Jolokia::Verifier::PGPKey::KEY;
    bless $self,(ref($class) || $class);
}

sub extension { 
    return ".asc";
}

sub name { 
    return "OpenPGP";
}

sub verify {
    my $self = shift;
    my %args = @_;

    my $kr = new Crypt::OpenPGP::KeyRing(Data => $self->{keyring});
    my $pgp = new Crypt::OpenPGP(PubRing => $kr);
    my $path = $args{path};
    my $log = $args{logger};
    my $validate;
    if ($path) {
        $validate = $pgp->verify(Files => [abs_path($args{path})],Signature => $args{signature});
    } else {
        $validate = $pgp->verify(Data => $args{data},Signature => $args{signature});        
    }
    if ($validate) {
        my $key;
        if ($validate != 1) {
            my $kb = $kr->find_keyblock_by_uid($validate);
            if ($kb) {
                eval {
                    # Non-document method
                    $key = $kb->key->key_id_hex;
                    $key = substr $key,8,8 if length($key) > 8;
                };
            }
        }
        $log->info("Good PGP signature",
                   ($validate != 1 ? (", signed by ",$validate) : ""),
                   ($key ? " ($key)" :""));
        return 1;
    } elsif ($validate == 0) {        
        $log->error("Invalid signature",$path ? " for $path" : "",": " . $pgp->errstr);
        die "\n";
    } else {
        $log->error("Error occured while verifying signature: ",$pgp->errstr);
        die "\n";
    } 
}

1;

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
