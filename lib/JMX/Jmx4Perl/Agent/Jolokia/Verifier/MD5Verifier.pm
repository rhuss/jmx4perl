#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Jolokia::Verifier::MD5Verifier;

use Digest::MD5;
use JMX::Jmx4Perl::Agent::Jolokia::Verifier::ChecksumVerifier;
use base qw(JMX::Jmx4Perl::Agent::Jolokia::Verifier::ChecksumVerifier);
use strict;

sub extension { 
    return ".md5";
}

sub name { 
    return "MD5";
}

sub create_digester {
    return new Digest::MD5();
}

=head1 LICENSE

This file is part of jmx4perl.
Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
The Free Software Foundation, either version 2 of the License, or
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

