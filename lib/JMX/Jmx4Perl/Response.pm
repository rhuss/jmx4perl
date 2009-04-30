#!/usr/bin/perl

=head1 NAME

JMX::Jmx4Perl::Response - Encapsulates as JMX Response as it comes from the
observered Server

=SYNOPSIS

 my $jmx_response = $jmx_agent->request($jmx_request);
 my $value = $jmx_response->value();
 
=cut

package JMX::Jmx4Perl::Response;

use strict;
use vars qw(@ISA @EXPORT);

sub new {
    my $class = shift;
    my $self = { 
                status => shift,
                request => shift,
                value => shift,
               };
    $self->{error} = $_[0] if ($_[0]);
    $self->{stacktrace} = $_[1] if ($_[1]);

    return bless $self,(ref($class) || $class);
}

sub status {
    return shift->{status};
}
sub is_ok {
    return shift->{status} == 200;
}

sub is_error {
    return shift->{status} != 200;;
}

sub error_text {
    return shift->{error};
}

sub stacktrace {
    return shift->{stacktrace};
}

sub value {
    return shift->{value};
}

sub request {
    return shift->{request};
}

1;
