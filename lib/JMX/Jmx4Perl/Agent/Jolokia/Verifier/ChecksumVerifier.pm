#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Jolokia::Verifier::ChecksumVerifier;

=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::Verifier::ChecksumVerifier - Verifies a
checksum for a downloaded artifact.

=head1 DESCRIPTION

This verifier provides the base for simple checksum checking. It needs to be
subclassed to provide the proper extension (e.g. ".sha1") and creating of a
digester. 

=cut 


use strict;

sub new { 
    my $class = shift;
    my $self = {};
    bless $self,(ref($class) || $class);
}

sub extension {
    die "abstract";
}

sub name {
    die "abstract";
}

sub create_digester {
    die "abstract";
}

sub verify {
    my $self = shift;
    my %args = @_;
    my $logger = $args{logger};
    my $sig = $args{signature};
    chomp $sig;
    $sig =~ s/^([^\s]+).*$/$1/;
    my $digester = $self->create_digester;
    my $file = $args{path};
    if ($file) {
        open (my $fh, "<", $file) || ($logger->error("Cannot open $file for ",$self->name," check: $!") && die "\n");
        $digester->addfile($fh);
        close $fh;
    } else {
        my $data = $args{data};
        $digester->add($data);        
    }
    my $sig_calc = $digester->hexdigest;
    if (lc($sig) eq lc($sig_calc)) {
        $logger->info("Passed ",$self->name," check (" . $sig_calc . ")",($file ? " for file $file" : ""));
    } else {
        $logger->error("Failed ",$self->name," check. Got: " . $sig_calc . ", Expected: " . $sig);
        die "\n";
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
