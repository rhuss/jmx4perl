#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Manager::Logger;

sub new { 
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };

    my $quiet = delete $self->{quiet};

    # No-op logger
    return new JMX::Jmx4Perl::Agent::Manager::Logger::None
      if $quiet;

    bless $self,(ref($class) || $class);    
}

sub info { 
    my $self = shift;
    my $text = shift;
    print "* " . $text . "\n";
}

sub error {
    my $self = shift;
    my $text = shift;
    print "! " . $text . "\n";
}

package JMX::Jmx4Perl::Agent::Manager::Logger::None;
use base qw(JMX::Jmx4Perl::Agent::Manager::Logger);

sub info { }
sub error { }

1;
