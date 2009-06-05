#!/usr/bin/perl
package JMX::Jmx4Perl::Product::Glassfish3;

use JMX::Jmx4Perl::Product::BaseHandler;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::Glassfish3 - Handler for Glassfisch, Version 3

=head1 DESCRIPTION

This handler supports glassfish version 3 (L<https://glassfish.dev.java.net/>)

=cut

sub id {
    return "glassfish3";
}

sub name {
    return "Glassfish";
}

sub _try_version {
    return shift->try_attribute
      (
       "version",
       "amx:j2eeType=X-DomainRoot,name=domain1",
       "ApplicationServerFullVersion"
      );
}

sub jsr77 {
    return 1;
}

sub init_aliases {
    return 
    {
     attributes => 
   {
   },
     operations => 
   {
    # No method known yet
    THREAD_DUMP => [ "com.sun.appserv:category=monitor,server=server,type=JVMInformation", undef ]
   }
     # Alias => [ "mbean", "attribute", "path" ]
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
