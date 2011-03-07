#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Manager::Logger;

use vars qw($HAS_COLOR);
use strict;

BEGIN {
    $HAS_COLOR = eval "require Term::ANSIColor; Term::ANSIColor->import(qw(:constants)); 1";
}

sub new { 
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };

    my $quiet = delete $self->{quiet};
    $HAS_COLOR &&= $self->{color};
    # No-op logger
    return new JMX::Jmx4Perl::Agent::Manager::Logger::None
      if $quiet;

    bless $self,(ref($class) || $class);    
}

sub debug {
    my $self = shift;
    if ($self->{debug}) {
        print "+ ",join("",@_),"\n";
    }
}

sub info { 
    my $self = shift;
    my $text = $self->_resolve_color(@_);
    my ($cs,$ce) = $HAS_COLOR ? (DARK . CYAN,RESET) : ("","");
    print $cs . "*" . $ce . " " . $text . "\n";
}

sub warn { 
    my $self = shift;
    my $text = join "",@_;
    my ($cs,$ce) = $HAS_COLOR ? (YELLOW,RESET) : ("","");
    print $cs. "! " . $text . $ce ."\n";
}

sub error {
    my $self = shift;
    my $text = join "",@_;
    my ($cs,$ce) = $HAS_COLOR ? (RED,RESET) : ("","");
    print $cs . $text . $ce . "\n";
}

sub _resolve_color {
    my $self = shift;
    return join "",map { 
        if (lc($_) eq "[em]") {
            $HAS_COLOR ? GREEN : "" 
        } elsif (lc($_) eq "[/em]") {
            $HAS_COLOR ? RESET : ""             
        } else {
            $_ 
        }} @_;
}


package JMX::Jmx4Perl::Agent::Manager::Logger::None;
use base qw(JMX::Jmx4Perl::Agent::Manager::Logger);

sub info { }
sub warn { }
sub error { }
sub debug { }
1;
