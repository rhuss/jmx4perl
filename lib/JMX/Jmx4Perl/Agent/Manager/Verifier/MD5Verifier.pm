#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Manager::Verifier::MD5Verifier;

use Digest::MD5;
use strict;

sub new { 
    my $class = shift;
    my $self = {};
    bless $self,(ref($class) || $class);
}

sub extension { 
    return ".md5";
}

sub name { 
    return "MD5";
}

sub verify {
    my $self = shift;
    my %args = @_;
    my $logger = $args{logger};
    my $sig = $args{signature};    
    chomp $sig;
    my $md5 = new Digest::MD5();
    my $file = $args{path};
    if ($file) {
        open (my $fh, "<", $file) || ($logger->error("Cannot open $file for MD5 check: $!") && die "\n");
        $md5->addfile($fh);
        close $fh;
    } else {
        my $data = $args{data};
        $md5->add($data);        
    }
    my $md5_calc = $md5->hexdigest;
    if (lc($sig) eq lc($md5_calc)) {
        $logger->info("Passed MD5 check (" . $md5_calc . ")",($file ? " for file $file" : ""));
    } else {
        $logger->error("Failed MD5 check. Got: " . $md5_calc . ", Expected: " . $sig);
        die "\n";
    }
}

1;
