#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Jolokia::Verifier;

=head1 NAME

JMX::Jmx4Perl::Agent::Verifier - Handler for various verifiers which picks
the most secure one first.

=head1 DESCRIPTION

Entry module for verification of downloaded artifacts. Depending on modules
installed, various validation mechanisms are tried in decreasing order fo
vialibility: 

=over 

=item L<Crypt::OpenPGP>

The strongest validation is provided by PGP signatures with which Jolokia
artifact is signed. The verifier uses L<Crypt::OpenPGP> for verifying PGP
signatures. 

=item L<Digest::SHA1>

If OpenPGP is not available or when no signature is provided from the Jolokia
site (unlikely), a simple SHA1 checksum is fetched and compared to the artifact
downloaded. This is not secure, but guarantees some degree of consistency.

=item L<Digest::MD5>

As last resort, when this module is availabl, a MD5 checksum is calculated and
compared to the checksum also downloaded from www.jolokia.org. 

=back 

=head1 METHODS

=over 4 

=cut 

use Data::Dumper;
use vars qw(@VERIFIERS @WARNINGS);
use strict;

# Pick the verifier, which is the most reliable

BEGIN { 
    @VERIFIERS = ();
    @WARNINGS = ();    

    my $create = sub {
        my $module = shift;
        eval "require $module";
        die $@ if $@;
        my $verifier;
        eval "\$verifier = new $module()";
        die $@ if $@;
        return $verifier;        
    };

    my $prefix = "JMX::Jmx4Perl::Agent::Jolokia::Verifier::";
    if (`gpg --version` =~ /GnuPG/m) {
        push @VERIFIERS,$create->($prefix . "GnuPGVerifier");        
    } else {
        push @WARNINGS,"No signature verification available. Please install GnupPG.";
    }

    # Disabled support for OpenPGP since it doesn't support the digest
    # algorithm used for signging the jolokia artefacts 
    # } elsif (eval "requireCrypt::OpenPGP; 1") { 
    #    push @VERIFIERS,$create->($prefix . "OpenPGPVerifier");

    push @VERIFIERS,$create->($prefix . "SHA1Verifier") if eval "require Digest::SHA1; 1";
    push @VERIFIERS,$create->($prefix . "MD5Verifier") if eval "require Digest::MD5; 1";
}

=item $verifier = JMX::Jmx4Perl::Agent::Jolokia::Verifier->new(%args)

Creates a new verifier. It takes an expanded hash als argument, where the
following keys are respected:

    "ua_config"         UserAgent configuration used for accessing 
                        remote signatures/checksums
    "logger"            Logger

=cut 

sub new { 
    my $class = shift;
    my $self = {@_};
    bless $self,(ref($class) || $class);
}

=item $verifier->verify(url => $url,path => $file)

=item $verifier->verify(url => $url,data => $data)

Verifies the given file (C<path>) or scalar data (C<data>) by trying various
validators in turn. Technically, each validator is asked for an extension
(e.g. ".asc" for a PGP signature), which is appended to URL and this URL is
tried for downloading the signature/checksum. If found, the content of the
signature/checksum is passed to specific verifier along with the data/file to
validate. A verifier will die, if validation fails, so one should put this in
an eval if required. If validation passes, the method returns silently. 

=back 

=cut 

sub verify {
    my $self = shift;
    my %args = @_;
    my $url = $args{url};
    
    my $ua = new JMX::Jmx4Perl::Agent::Jolokia::DownloadAgent($self->{ua_config});
    my $log = $self->{logger};
    $log->warn($_) for @WARNINGS;
    for my $verifier (@VERIFIERS) {
        my $ext = $verifier->extension;
        if ($ext) {
            my $response = $ua->get($url . $ext);
            if ($response->is_success) {
                my $content = $response->decoded_content;
                $verifier->verify(%args,signature => $content,logger => $log);
                return;
            } else {
                $log->warn($verifier->name . ": Couldn't load $url$ext");
            }
        }
    }
    $log->warn("No suitable validation mechanism found with $url");
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
