#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Jolokia::Verifier::OpenPGPVerifier;

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
have) and associated signature ending with F<.asc>. This contains a signature
which is verified with the public key contained in the __DATA__ section of this
module (i.e. my personal key with ID EF101165). This verifier is the most
robust one, however installing L<Crypt::OpenPGP> is a bit clumsy, so you might
omit this one.

=cut 

sub new { 
    my $class = shift;
    my $self = {};
    my $fh = \*{JMX::Jmx4Perl::Agent::Jolokia::Verifier::OpenPGPVerifier::DATA};    
    $self->{keyring} =  join "",<$fh>;
    close $fh;
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
        $log->error("Invalid signature",$path ? " for $path" : "");
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


__DATA__
-----BEGIN PGP PUBLIC KEY BLOCK-----
Version: GnuPG/MacGPG2 v2.0.16 (Darwin)

mQCNAzpoBEMAAAEEAMdDw9V+zMCjJI6Icjv+Z+s5mepNJ+tH848PVOfZohfDoEZx
pthbKW+U0EgFVtV8EE9iWDQOh68U3BvEaOvk+99YoahRRACuII1Y+Q445UaNV/Tn
hCGmofWITYY8Tbz6dcYnWsWMQ5XByM4aMwucM8pUARomkrrM9kKyJpPvEBFlAAUR
tCFSb2xhbmQgSHVzcyA8cm9sYW5kQGpteDRwZXJsLm9yZz6JAJUDBRNNcVaiQrIm
k+8QEWUBARSrA/9gp7YhV7kh47WWtzC25aaW/WS2FwiBqKsOIJ5z8kkrEDOqz3iU
TEzyHMgngwR7dNqZAM2xZlt6uTW1VuhraOFp27V0UVpQg/l1XaHF9JNVPvsbGmFG
MIu/2gQrkhI9/Amyy5Zi3w2mbwISQ897QVY0O98/BlcymFpl5hrx4qbSdbQdUm9s
YW5kIEh1c3MgPHJvbGFuZEBjcGFuLm9yZz6JAJUDBRA6aATCQrImk+8QEWUBAbKN
A/9IEGDcSG7bB7ZW2oDzny++6nhpsHzRlSIwcXJA20W73bu/So8+v6fl4CiBEtZW
KN6qCwqpreK6i8DHx+bGMkm8+uucO3G5vqi9FIF1yJt8ioLPyhPNktRGCCdSxbqG
uYlOaDFwa9J9ebcqPe3mS0/374ixaArqpQPB+S/OU3nuXbQeUm9sYW5kIEh1c3Mg
PHJvbGFuZEBjb25zb2wuZGU+iQCVAwUQOmgEQ0KyJpPvEBFlAQHI+AP9FbP3x5vs
moXO95yV3PHhw0FOo9Szpd4kgIoXGMRVGC5gFKyX7dSU8jwi5PnSQRmTg8jQUUBj
kVYi29nKHsOwp9J7oTbHlC02heaghjW5zTxxRv6lgmh3+cIsAimbi/fr3pRovRCT
MS75CQJTAQAXz4+ALBxU3sG71kEx1mVwEIS0IFJvbGFuZCBIdXNzIDxyb2xhbmRA
am9sb2tpYS5vcmc+iQCVAwUTTXFWgUKyJpPvEBFlAQHGcwP/UNWFVPiV+o3qWVfY
+g9EiJoN43YN6QI3VasZ6Gjda3ZCJ6aLQXL9UorcTQBSIpCOKvEElG5Sw+dH0IPW
jmrzWK1s9lnU2Qkx88QY5O489p+Z98SqbDGqW7DEIkYutYVou0nV7/SVyulMUNGe
vqmY3GlfyqrXMXL+lu6IRpCfHcw=
=HxAM
-----END PGP PUBLIC KEY BLOCK-----

