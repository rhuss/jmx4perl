#!/usr/bin/perl
package JMX::Jmx4Perl::Product::Glassfish;

use JMX::Jmx4Perl::Product::BaseHandler;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::Glassfish - Handler for Glassfish

=head1 DESCRIPTION

This handler supports glassfish version 2. (L<https://glassfish.dev.java.net/>)

=cut

sub id {
    return "glassfish";
}

sub name {
    return "Glassfish";
}

sub version {
    my $self = shift;
    my $version = $self->_version_or_vendor("version",qr/([\d\.]+)/m);
    return $version if $version;
    
    # Try for Glassfish V3
    my $jmx = $self->{jmx4perl};

    my $servers = $jmx->search("com.sun.appserv:type=Host,*");
    if ($servers) {
        $self->{"original_version"} = "GlassFish V3";
        $self->{"version"} = "3";
        return "3";
    }
    return undef;
}

sub vendor {
    return "Sun Microsystems";
}

sub autodetect_pattern {
    return (shift->original_version_sub,qr/GlassFish/i);
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
            THREAD_DUMP => [ "com.sun.appserv:category=monitor,server=server,type=JVMInformation", "getThreadDump"]
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
