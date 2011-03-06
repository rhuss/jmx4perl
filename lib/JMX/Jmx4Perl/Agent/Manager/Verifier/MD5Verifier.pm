#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Manager::Verifier::MD5Verifier;

use Digest::MD5;
use JMX::Jmx4Perl::Agent::Manager::Verifier::ChecksumVerifier;
use base qw(JMX::Jmx4Perl::Agent::Manager::Verifier::ChecksumVerifier);
use strict;

sub extension { 
    return ".md5";
}

sub name { 
    return "MD5";
}

sub create_digester {
    return new Digest::MD5();
}

1;

