#!/usr/bin/perl
package JMX::Jmx4Perl::Product::Websphere;

use JMX::Jmx4Perl::Product::BaseHandler;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::Websphere - Handler for IBM Websphere

=head1 DESCRIPTION

This is the product handler support for IBM Websphere Application Server 6 and
7 (L<http://www.ibm.com/>)

=cut

sub id {
    return "websphere";
}

sub name {
    return "IBM Websphere Application Server";
}


sub version {
    return shift->_version_or_vendor("version",qr/^Version\s+(\d.*)\s*$/m);
}

sub autodetect_pattern {
    return (shift->original_version_sub,qr/IBM\s+WebSphere\s+Application\s+Server/i);
}

sub order { 
    return 100;
}

sub jsr77 {
    return 1;
}

sub init_aliases {
    my $self = shift;
    return {
            attributes => { 
                           OS_CPU_TIME => 0,   # Don't support these ones
                           OS_FILE_DESC_MAX => 0,
                           OS_FILE_DESC_OPEN => 0,
                           OS_MEMORY_PHYSICAL_FREE => 0,
                           OS_MEMORY_PHYSICAL_TOTAL => 0,
                           OS_MEMORY_SWAP_FREE => 0,
                           OS_MEMORY_SWAP_TOTAL => 0,
                           OS_MEMORY_VIRTUAL => 0
                          }
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
