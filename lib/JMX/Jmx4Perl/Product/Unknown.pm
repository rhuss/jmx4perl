#!/usr/bin/perl
package JMX::Jmx4Perl::Product::Unknown;

use JMX::Jmx4Perl::Product::BaseHandler;
use JMX::Jmx4Perl;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::Unknown - Fallback handler

=head1 DESCRIPTION

This fallback handler runs always as I<last> in the autodetection chain and
provides at least informations about the platform MXMBeans which are available
on any Java 5 platform.

=cut

sub id {
    return "unknown";
}

sub name {
    return "unknown";
}

# Highest ordering number
sub order { 
    return 1000;
}

sub info {
    my $self = shift;
    my $verbose = shift;

    my $ret = $self->jvm_info($verbose);    
    $ret .= "-" x 80 . "\n";    
    $ret .= "The application server's brand could not be auto-detected.\n";
    $ret .= "Known brands are: " . (join ", ",grep { $_ ne "unknown"} @JMX::Jmx4Perl::PRODUCT_HANDLER_ORDERING) . "\n\n";
    $ret .=
      "Please submit the output of 'jmx4perl list' and 'jmx4perl attributes' to\n" . 
      "roland\@cpan.de in order to provide a new product handler in the next release\n";
}

sub autodetect {
    # Since we are the last one in the chain, we will be the one 'found'
    return 1;
}

sub version {
    return "";
}

sub jsr77 {
    return 0;
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
