#!/usr/bin/perl
package JMX::Jmx4Perl::J4psh::ServerHandler;

use strict;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

=head1 NAME 

JMX::Jmx4Perl::J4psh::ServerHandler - Handler for coordinating server access

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

sub new { 
    my $class = shift;
    my $context = shift || die "No context given";
    my $args = shift;
    my $self = {
                context => $context,
                args => $context->{args},
                config => $context->{config},
               };
    bless $self,(ref($class) || $class);
    my $server = $self->_init_server_list($context->{initial_server},$context);
    $self->connect_to_server($server) if $server;
    return $self;
}

sub connect_to_server {
    my $self = shift;    
    my $server = shift;
    my $name = shift;

    my $server_map = $self->{server_map};
    my $s = $server_map->{$server};
    unless ($s) {
        unless ($server =~ m|^\w+://[\w:]+/|) {
            print "Invalid URL $server\n";
            return;
        }
        $name ||= $self->_prepare_server_name($server);
        my $entry = { name => $name, url => $server };
        push @{$self->{server_list}},$entry;
        $self->{server_map}->{$name} = $entry;
        $s = $entry;
    }
    my $context = $self->{context};
    my ($old_server,$old_agent) = ($self->server,$context->agent);
    eval { 
        $self->create_agent($s->{name}) || die "Unknown $server (not an alias nor a proper URL).\n";;
        $self->{server} = $s->{name};
        $context->last_error("");
    };
    if ($@) {
        $context->last_error($@);
        $self->{server} = $old_server if $old_server;
        $context->agent($old_agent);
        die $@;
    }   
}

sub server {
    return shift->{server};
}

sub list {
    my $self = shift;
    return $self->{server_list};
}


sub _init_server_list {
    my $self = shift;
    my $server = shift;
    my $context = shift;
    my $config = $context->{config};
    my $args = $context->{args};
    my @servers = map { { name => $_->{name}, url => $_->{url}, from_config => 1 } } @{$config->get_servers};
    my $ret_server;
    if ($server) {
        my $config_s = $config->get_server_config($server);
        if ($config_s) {
            my $found = 0;
            my $i = 0;
            my $entry = { name => $server, url => $config_s->{url}, from_config => 1 } ;
            for my $s (@servers) {
                if ($s->{name} eq $server) {
                    $servers[$i] = $entry;
                    $found = 1;                 
                    last;
                }
                $i++;
            } 
            push @servers,$entry unless $found;
            $ret_server = $config_s->{name};
        } else {
            die "Invalid URL ",$server,"\n" unless ($server =~ m|^\w+://|);
            my $name = $self->_prepare_server_name($server);
            push @servers,{ name => $name, url => $server };
            $ret_server = $name;
        }
    }
    $self->{server_list} = \@servers;
    $self->{server_map} = { map { $_->{name} => $_ } @servers };
    return $ret_server;
}

# ========================================================================================= 

sub _prepare_server_name {
    my $self = shift;
    my $url = shift;
    if ($url =~ m|^\w+://([^/]+)/?|) { 
        return $1;
    } else {
        return $url;
    }
}

sub create_agent {
    my $self = shift;
    my $server = shift;
    return undef unless $server;
    # TODO: j4p_args, jmx_config;
    my $j4p_args = $self->_j4p_args($self->{args} || {});
    my $jmx_config = $self->{config} || {};
    my $sc = $self->{server_map}->{$server};
    return undef unless $sc;
    my $context = $self->{context};
    if ($sc->{from_config}) {
        $context->create_agent({ %$j4p_args, server => $server, config => $jmx_config});
    } else {
        $context->create_agent({ %$j4p_args, url => $sc->{url}});
    }
}

# Extract connection related args from the command line arguments
sub _j4p_args {
    my $self = shift;
    my $o = shift;
    my $ret = { };
    
    for my $arg qw(user password) {
        if (defined($o->{$arg})) {
            $ret->{$arg} = $o->{$arg};
        }
    }
    
    if (defined($o->{proxy})) {
        my $proxy = {};
        $proxy->{url} = $o->{proxy};
        for my $k (qw(proxy-user proxy-password)) {
            $proxy->{$k} = defined($o->{$k}) if $o->{$k};
        }
        $ret->{proxy} = $proxy;
    }        
    if (defined($o->{target})) {
        $ret->{target} = {
                          url => $o->{target},
                          $o->{'target-user'} ? (user => $o->{'target-user'}) : (),
                          $o->{'target-password'} ? (password => $o->{'target-password'}) : (),
                         };
    }
    return $ret;
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

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or Nagios or JMX in
general), you might want to have a look at
http://www.consol.com/opensource/nagios/. Contact roland.huss@consol.de for
further information (or use the contact form at http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut

1;

