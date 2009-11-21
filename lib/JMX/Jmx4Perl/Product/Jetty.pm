#!/usr/bin/perl
package JMX::Jmx4Perl::Product::Jetty;

use JMX::Jmx4Perl::Product::BaseHandler;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::Jetty - Handler for Jetty 

=head1 DESCRIPTION

This is the product handler support Jetty. It supports Jetty version 5, 6 and 7.
(L<http://www.mortbay.org/jetty/>)

Please note, that you must have JMX support enabled in Jetty for autodetection
and aliasing to work. See the Jetty documentation for details.

=cut

sub id {
    return "jetty";
}

sub name { 
    return "Jetty";
}

sub _try_version {
    my $self = shift;
    my $jmx = $self->{jmx4perl};

    # Jetty V6 & 7
    my $servers = $jmx->search("*:id=0,type=server,*");
    my $ret;
    if ($servers) {
        $ret = $self->try_attribute("version",$servers->[0],"version");
    }

    # Jetty V5
    if (!length($self->{version})) {
        delete $self->{version};
        $ret = $self->try_attribute("version","org.mortbay:jetty=default","version");
    }

    $self->{version} =~ s/Jetty\/([^\s]+).*/$1/;
    return $ret;
}

sub autodetect_pattern {
    return "version";
}

sub vendor {
    return "Mortbay";
} 

sub jsr77 {
    return 0;
}

sub init_aliases {
    return 
    {
     attributes => 
   {
   },
     operations => 
   {
    THREAD_DUMP => [ "jboss.system:type=ServerInfo", "listThreadDump"]
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
