#!/usr/bin/perl

=head1 NAME

JMX::Jmx4Perl::Response - Encapsulates as JMX Response as it comes from the
observerd Server

=SYNOPSIS

 my $jmx_response = $jmx_agent->request($jmx_request);
 my $value = $jmx_response->value();
 
=cut

package JMX::Jmx4Perl::Response;

use strict;
use vars qw(@ISA @EXPORT);

sub new {
    my $class = shift;
    my $request = shift;
    my $value = shift;

    my $self = { 
                value => $value,
                request => $request
               };
    return bless $self,(ref($class) || $class);
}

sub value {
    return shift->{value};
}

sub request {
    return shift->{request};
}

1;
