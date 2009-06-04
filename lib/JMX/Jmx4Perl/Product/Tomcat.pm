#!/usr/bin/perl
package JMX::Jmx4Perl::Product::Tomcat;

use JMX::Jmx4Perl::Product::BaseHandler;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::Tomcat - Handler for Apache Tomcat

=head1 DESCRIPTION

This is the product handler supporting Tomcat, Version 4, 5 and 6. 

=cut

sub id {
    return "tomcat";
}

sub name { 
    return "Apache Tomcat";
}

# Let it run after JBoss
sub order {
    return -1;
}

sub _try_version {
    my $self = shift;
    # JBoss also has the tomcat tag, so we need to check this here as well
    my $is_jboss = $self->try_attribute("jboss_version","jboss.system:type=Server","VersionNumber");
    return undef if $is_jboss;

    my $res = $self->try_attribute("version","Catalina:type=Server","serverInfo");
    $self->{version} =~ s/^.*?\/?(.*)$/$1/;
    return $res;
}

sub jsr77 {
    return 1;
}

sub init_aliases {
    return 
    {
     attributes => 
   {
    #SERVER_ADDRESS => [ "jboss.system:type=ServerInfo", "HostAddress"],
    SERVER_HOSTNAME => [ "Catalina:type=Engine", "defaultHost"],
   },
     operations => 
   {
    #THREAD_DUMP => [ "jboss.system:type=ServerInfo", "listThreadDump"]
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
