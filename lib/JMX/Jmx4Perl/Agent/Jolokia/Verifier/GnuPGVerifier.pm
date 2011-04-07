#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Jolokia::Verifier::GnuPGVerifier;

use Module::Find;
use Data::Dumper;
use File::Temp qw/tempfile/;

use strict;

=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::Verifier::GnuPGVerifier - Verifies PGP
signature with a natively installed GnuPG (with gpg found in the path)

=head1 DESCRIPTION

This verifier uses a natively installed GPG for validating a PGP signature
obtained from the download site. It's similar to
L<JMX::Jmx4Perl::Agent::Jolokia::Verifier::OpenPGPVerifier> except that it will
use a locally installed GnuPG installation. Please note, that it will import
the public key used for signature verification into the local keystore. 

=cut 

sub new { 
    my $class = shift;
    my $self = {};
    ($self->{gpg},$self->{version}) = &_gpg_version();
    bless $self,(ref($class) || $class);
}

sub extension { 
    return ".asc";
}

sub name { 
    return "GnuPG";
}

sub verify {
    my $self = shift;
    my %args = @_;

    my $log = $args{logger};
    my $gpg = $self->{gpg};

    die "Neither 'path' nor 'data' given for specifying the file/data to verify" 
      unless $args{path} || $args{data};

    my $signature_path = $self->_store_tempfile($args{signature});
    my $path = $args{path} ? $args{path} : $self->_store_tempfile($args{data});
    my @cmd = (
               $gpg,
               qw(--verify --batch --no-tty -q --logger-fd=1),
              );
    eval {
        push @cmd, $signature_path,$args{path};
        my $cmd = join ' ', @cmd;
        my $output = `$cmd`;
        if ($output =~ /public key/i) {
            # Import key and retry
            $self->_import_key(\%args);
            $output = `$cmd`;
        }
            
        $self->_verify_gpg_output($?,$output,\%args);
    };
    
    # Always cleanup
    my $error = $@;
    unlink $signature_path;
    unlink $path unless $args{path};
    die $error if $error;

}

sub _verify_gpg_output {
    my $self = shift;
    my $code = shift;
    my $output = shift;
    my $args = shift;
    my $log = $args->{logger};
    my $key = $1 if $output =~ /\s+([\dA-F]{8})/;
#    print $output,"\n";
    if ($code) {        
        $log->error("Invalid signature",$args->{path} ? " for " . $args->{path}  : "",$key ? " (key: $key)" : "");
        die "\n";        
    } else { 
        $log->info("Good PGP signature" . ($key ? " ($key)" : ""));
    }
}

sub _import_key {
    my $self = shift;
    my $args = shift;

    my $gpg = $self->{gpg};
    my $log = $args->{logger};
    my $fh = \*{JMX::Jmx4Perl::Agent::Jolokia::Verifier::GnuPGVerifier::DATA};    
    my $key =  join "",<$fh>;
    close $fh;
    my $key_path = $self->_store_tempfile($key);

    my @cmd = ($gpg,qw(--import --verbose --batch --no-tty  --logger-fd=1),$key_path);
    my $cmd = join ' ', @cmd;
    my $output = `$cmd`;
    if ($?) {
        $log->error("Cannot add public PGP used for verification to local keystore: $output");
        die "\n";
    } else {
        $log->info($output);
        my $info = $1 if $output =~ /([\dA-F]{8}.*)$/mi;
        $log->info($info ? $info : "Added jmx4perl key");
    }
    unlink $key_path;
}


sub _gpg_version {
    my $gpg = "gpg2";
    my $out = `gpg2 --version`;
    if ($?) {
        $out = `gpg --version`;
        $gpg = "gpg";
        if ($?) {
            die "Cannot find gpg or gpg2: $out\n";
        }
    }
    $out =~ /GnuPG.*?(\S+)\s*$/m or die "Cannot execute gpg: $out";
    return ($gpg,$1);
}

sub _store_tempfile {
    my $self = shift;
    my $sig = shift || die "No data given to store in temp file";
    my ($fh,$path) = tempfile();
    print $fh $sig;
    close $fh;
    return $path;
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
Version: GnuPG v1.4.10 (GNU/Linux)

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

