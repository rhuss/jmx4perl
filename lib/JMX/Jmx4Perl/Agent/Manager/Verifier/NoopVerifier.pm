#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Manager::Verifier::NoopVerifier;

sub new { 
    my $class = shift;
    my $self = {};
    bless $self,(ref($class) || $class);
}

1;
