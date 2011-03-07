#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Manager::Verifier::ChecksumVerifier;

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

1;
