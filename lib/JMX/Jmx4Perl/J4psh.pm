#!/usr/bin/perl

package JMX::Jmx4Perl::J4psh;

use JMX::Jmx4Perl::J4psh::CompletionHandler;
use JMX::Jmx4Perl::J4psh::ServerHandler;
use JMX::Jmx4Perl::J4psh::CommandHandler;
use JMX::Jmx4Perl::J4psh::Shell;
use JMX::Jmx4Perl;

use strict;

=head1 NAME

JMX::Jmx4Perl::J4psh - Central object for the JMX shell j4psh

=cut

sub new { 
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    bless $self,(ref($class) || $class);
    $self->init();
    return $self;
}

sub init {
    my $self = shift;
    $self->{complete} = new JMX::Jmx4Perl::J4psh::CompletionHandler($self);
    $self->{servers} = new JMX::Jmx4Perl::J4psh::ServerHandler($self);
    $self->{shell} = new JMX::Jmx4Perl::J4psh::Shell(use_color => $self->use_color =~ /(yes|true|on)$/);;
    my $no_color_prompt = $self->{shell}->readline ne "Term::ReadLine::Gnu";
    $self->{commands} = new JMX::Jmx4Perl::J4psh::CommandHandler($self,$self->{shell},
                                                                 no_color_prompt => $no_color_prompt,
                                                                command_packages => $self->command_packages);
}

sub command_packages {
    return [ "JMX::Jmx4Perl::J4psh::Command" ];
}

sub use_color { 
    my $self = shift;
    if (exists $self->{args}->{color}) {
        return $self->{args}->{color};
    } elsif (exists $self->{config}->{use_color}) {
        return $self->{config}->{use_color};
    } else {
        return "yes";
    }    
}

sub run {
    my $self = shift;
    $self->{shell}->run;
}

sub complete {
    return shift->{complete};
}

sub commands {
    return shift->{commands};
}

sub servers {
    return shift->{servers};
}

sub server {
    return shift->{servers}->{server};
}

sub color { 
    return shift->{shell}->color(@_);
}

sub agent {
    my $self = shift;
    my $agent = shift;
    if (defined($agent)) {
        $self->{agent} = $agent;
    }
    return $self->{agent};
}

sub last_error {
    my $self = shift;
    my $error = shift;
    if (defined($error)) {
        if (length($error)) {
            $self->{last_error} = $error;
        } else {
            delete $self->{last_error};
        }
    }
    return $self->{last_error};
}

sub create_agent {
    my $self = shift;
    my $args = shift;
    my $j4p = new JMX::Jmx4Perl($args);
    $self->agent($j4p);
    return $j4p;
}


sub name { 
    return "j4psh";
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
