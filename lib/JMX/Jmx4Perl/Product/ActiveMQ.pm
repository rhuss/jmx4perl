#!/usr/bin/perl
package JMX::Jmx4Perl::Product::ActiveMQ;

use JMX::Jmx4Perl::Product::BaseHandler;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";
use Data::Dumper;

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::ActiveMQ - Handler for Jonas

=head1 DESCRIPTION

This is the product handler support for ActiveMQ
(L<http://activemq.apache.org/>) which works with the JVM Agent provided for
Sun JDK 6 based applications

=cut

sub id {
    return "activemq";
}

sub name {
    return "ActiveMQ";
}

sub vendor {
    return "Apache";
}

sub version {
    # No way to detect version until yet.
    return "";
}
sub order { 
    return 200;
}

sub autodetect_pattern {
    return sub { 
        my $self = shift;
        my $j4p = $self->{jmx4perl};        
        my $ret = $j4p->search("org.apache.activemq:*");
        #print Dumper($ret);
        return $ret;
    };
}

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
