#!/usr/bin/perl

package JMX::Jmx4Perl::J4psh::Command::Server;
use strict;
use Term::ANSIColor qw(:constants);

use base qw(JMX::Jmx4Perl::J4psh::Command);


=head1 NAME 

JMX::Jmx4Perl::J4psh::Command::Server - Server related commands

=head1 DESCRIPTION

=head1 COMMANDS

=over

=cut 


sub name { "server" }

sub top_commands {
    my $self = shift;
    return {
            "servers" => { 
                          desc => "Show all configured servers",
                          proc => $self->cmd_server_list,
                          doc => <<EOT
List all servers stored in the configuration 
and those connected during this session 
(indicated by a '*')
EOT
                         }
           };
}

sub global_commands {
    my $self = shift;
    return {
            "connect" => { 
                          desc => "Connect to a server by its URL or symbolic name",
                          minargs => 1, maxargs => 2,
                          args => $self->complete->servers,
                          proc => $self->cmd_connect,
                          doc => <<EOT

connect <url or name> [<name>]

Connect to an agent. <url> is the URL under which the agent
is reachable. Alternatively a <name> as stored in the configuration
can be given. Is using the <url> form an additional <name>
can be given which will be used as name in the server list.
EOT
                         }
           };
}

# Connect to a server
sub cmd_connect {
    my $self = shift;
    return sub {
        my $arg = shift;
        my $name = shift;
        my $context = $self->context;
        $context->servers->connect_to_server($arg,$name);
        $context->commands->reset_stack;
        my ($yellow,$reset) = $context->color("host",RESET);
        print "Connected to " . $yellow . $context->server . $reset .  " (" . $context->agent->url . ").\n";
    }
}

# Show all servers
sub cmd_server_list {
    my $self = shift;
    return sub {
        my $context = $self->context;
        my $server_list = $context->servers->list;
        for my $s (@$server_list) {
            my ($ms,$me) = $context->color("host",RESET);
            my $sep = $s->{from_config} ? "-" : "*";
            printf " " . $ms . '%30.30s' . $me . ' %s %s' . "\n",$s->{name},$sep,$s->{url};
        }
    }
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

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or Nagios or JMX in
general), you might want to have a look at
http://www.consol.com/opensource/nagios/. Contact roland.huss@consol.de for
further information (or use the contact form at http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut

1;

