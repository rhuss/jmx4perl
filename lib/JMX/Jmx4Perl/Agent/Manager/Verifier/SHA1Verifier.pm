#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Manager::Verifier::SHA1Verifier;

use Digest::SHA1;
use JMX::Jmx4Perl::Agent::Manager::Verifier::ChecksumVerifier;
use base qw(JMX::Jmx4Perl::Agent::Manager::Verifier::ChecksumVerifier);
use strict;

sub extension { 
    return ".sha1";
}

sub name { 
    return "SHA1";
}

sub create_digester {
    return new Digest::SHA1();
}

1;
