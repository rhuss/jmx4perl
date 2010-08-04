#!/usr/bin/perl

=head1 NAME

JMX::Jmx4Perl::Response - A jmx4perl response 

=head1 SYNOPSIS

 my $jmx_response = $jmx_agent->request($jmx_request);
 my $value = $jmx_response->value();
 
=head1 DESCRIPTION

A L<JMX::Jmx4Perl::Response> is the result of an JMX request and encapsulates
the answer as returned by a L<JMX::Jmx4Perl> backend. Depending on the
C<status> it either contains the result of a valid request or a error message.
The status is modelled after HTTP response codes (see
L<http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html>). For now, only the
codes C<200> and C<400 .. 599> codes are used to specified successful request
and errors respectively.

=head1 METHODS

=over

=cut

package JMX::Jmx4Perl::Response;

use strict;
use vars qw(@EXPORT);

=item $response = JMX::Jmx4Perl::Response->new($status,$request,$value,$error,$stacktrace)

Internal constructor for creating a response which is use withing requesting
the backend. C<$error> and C<$stacktrace> are optional and should only provided
when C<$status != 200>.

=cut

sub new {
    my $class = shift;
    my $self = { @_ };
    return bless $self,(ref($class) || $class);
}

=item $status = $response->status()

Return the status code of this response. Status codes are modelled after HTTP
return codes. C<200> is the code for a suceeded request. Any code in the range
500 - 599 specifies an error.

=cut

sub status {
    return shift->{status};
}

=item $timestamp = $response->timestamp()

Get the timestamp (i.e. epoch seconds) when the request was executed on the
serverside.

=cut

sub timestamp {
    return shift->{timestamp};
}

=item $history = $response->history() 

Get the history if history tracking is switched on. History tracking is
switchen on by executing a certain JMX operation on the C<jmx4perl:type=Config>
MBean. See the alias C<JMX4PERL_HISTORY_MAX_ATTRIBUTE> and L<jmx4perl/"HISTORY
TRACKING"> for details.

The returned arrayref (if any) contains hashes with two values: C<value>
contains the historical value and C<timestamp> the timestamp when this value
was recorded.

=cut 

sub history {
    return shift->{history};
}

=item $ok = $response->is_ok()

Return true if this object contains a valid response (i.e. the status code is
equal 200)

=cut

sub is_ok {
    return shift->{status} == 200;
}

=item $fault = $response->is_error()

Opposite of C<is_ok>, i.e. return true if the status code is B<not> equal to
200 

=cut 

sub is_error {
    return shift->{status} != 200;;
}

=item $error = $response->error_text()

Return the error text. Set only if C<is_error> is C<true>

=cut

sub error_text {
    return shift->{error};
}

=item $error = $response->stacktrace()

Returns the stacktrace of an Java error if any. This is only set when
C<is_error> is C<true> B<and> and Java exception occured on the Java agent's
side. 

=cut 

sub stacktrace { return shift->{stacktrace}; }

=item $content = $response->value() 

Return the content of this response, which is a represents the JSON response as
returned by the Java agent as a hash reference value. This is set only when C<is_ok> is
true.

=cut

sub value {
    return shift->{value};
}

=item $request = $response->request()

Return the L<JMX::Jmx4Perl::Request> which lead to this response

=cut

sub request {
    return shift->{request};
}

=back

=head1 LICENSE

This file is part of jmx4perl.

Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
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
