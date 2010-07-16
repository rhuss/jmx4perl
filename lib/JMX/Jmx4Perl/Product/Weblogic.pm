#!/usr/bin/perl
package JMX::Jmx4Perl::Product::Weblogic;

use JMX::Jmx4Perl::Product::BaseHandler;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
use strict;
use base "JMX::Jmx4Perl::Product::BaseHandler";

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::Product::Weblogic - Handler for Oracle WebLogic

=head1 DESCRIPTION

This is the product handler support for Oracle Weblogic Server 9 and 10 
(L<http://www.oracle.com/appserver/>)

=cut

sub id {
    return "weblogic";
}

sub name {
    return "Oracle WebLogic Server";
}

sub order { 
    return undef;
}

sub _try_version {
    my $self = shift;
    my $is_weblogic = $self->_try_server_domain;
    return undef unless $is_weblogic;
    return $self->try_attribute("version",$self->{server_domain},"ConfigurationVersion");
}

sub vendor {
    return "Oracle";
}

sub server_info { 
    my $self = shift;
    my $ret = $self->SUPER::server_info();
    $ret .= sprintf("%-10.10s %s\n","IP:",$self->{jmx4perl}->get_attribute("SERVER_ADDRESS"));
}

sub _try_server_domain {
    my $self = shift;
    return $self->try_attribute
      ("server_domain",
       "com.bea:Name=RuntimeService,Type=weblogic.management.mbeanservers.runtime.RuntimeServiceMBean",
       "DomainConfiguration",
       "objectName");
}

sub jsr77 {
    return 0;
}

sub autodetect_pattern {
    return ("version",1);
}

sub init_aliases {
    return 
    {
     attributes => {
                    SERVER_ADDRESS => [ sub {
                                            my $self = shift;
                                            $self->_try_server_domain;
                                            $self->try_attribute("admin_server",
                                                                 $self->{server_domain},
                                                                 "AdminServerName");
                                            return [ "com.bea:Name=" . $self->{admin_server} . ",Type=ServerRuntime", 
                                                     "AdminServerHost" ];
                                        }],    
                   },
     operations => {
                    # Needs to be done in a more complex. Depends on admin server name *and*
                    # JVM used
                    THREAD_DUMP => \&exec_thread_dump
                   }
     # Alias => [ "mbean", "attribute", "path" ]
    };
}

sub exec_thread_dump {
    my $self = shift;
    my $jmx = $self->{jmx4perl};

    my $beans = $jmx->search("com.bea:Type=JRockitRuntime,*");
    if ($beans && @{$beans}) {
        my $bean = $beans->[0];
        my $request = new JMX::Jmx4Perl::Request(READ,$bean,"ThreadStackDump");
        return $jmx->request($request);
    }
    die $self->name,": Cannot execute THREAD_DUMP because I can't find a suitable JRockitRuntime";
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
