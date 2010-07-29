#!/usr/bin/perl

package JMX::Jmx4Perl::J4psh;

use JMX::Jmx4Perl::J4psh::CompletionHandler;
use JMX::Jmx4Perl::J4psh::ServerHandler;
use JMX::Jmx4Perl::J4psh::CommandHandler;
use JMX::Jmx4Perl::J4psh::Shell;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl;
use Data::Dumper;
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
    $self->{shell} = new JMX::Jmx4Perl::J4psh::Shell(config => $self->config->{shell},args => $self->{args});;
    my $no_color_prompt = $self->{shell}->readline ne "Term::ReadLine::Gnu";
    $self->{commands} = new JMX::Jmx4Perl::J4psh::CommandHandler($self,$self->{shell},
                                                                 no_color_prompt => $no_color_prompt,
                                                                 command_packages => $self->command_packages);
}

sub command_packages {
    return [ "JMX::Jmx4Perl::J4psh::Command" ];
}

sub run {
    my $self = shift;
    $self->{shell}->run;
}

sub config {
    return shift->{config};
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

sub term_height {
    return shift->{shell}->term_height;
}

sub term_width {
    return shift->{shell}->term_width;
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
    $self->load_list($j4p);
    $self->agent($j4p);
    return $j4p;
}

sub load_list {
    my $self = shift;
    my $j4p = shift;
    
    my $old_list = $self->{list};
    eval { 
        my $req = new JMX::Jmx4Perl::Request(LIST);
        $self->{list} = $self->request($req,$j4p);
        ($self->{mbeans_by_domain},$self->{mbeans_by_name}) = $self->_prepare_mbean_names($j4p,$self->{list});
    };
    if ($@) {
        $self->{list} = $old_list;
        die $@;
    }      
};

sub list {
    return shift->{list};
}

sub mbeans_by_domain {
    return shift->{mbeans_by_domain};
}

sub mbeans_by_name {
    return shift->{mbeans_by_name};
}

sub request { 
    my $self = shift;
    my $request = shift;
    my $j4p = shift || $self->agent;

    my $response = $j4p->request($request);
    if ($response->is_error) {
        #print Dumper($response);
        if ($response->status == 404) {
            die "No agent running [Not found: ",$request->{mbean},",",$request->{operation},"].\n"
        } else {
            $self->{last_error} = $response->{error} . 
              ($response->stacktrace ? "\nStacktrace:\n" . $response->stacktrace : "");
            die $self->_prepare_error_message($response) . ".\n";
        }
    }
    return $response->value;
}

sub _prepare_error_message {
    my $self = shift;
    my $resp = shift;
    my $st = $resp->stacktrace;
    return "Connection refused" if $resp->{error} =~ /Connection\s+refused/i;

    if ($resp->{error} =~ /^(\d{3} [^\n]+)\n/m) {
        return $1;
    }
    return "Server Error: " . $resp->{error};
}


sub name { 
    return "j4psh";
}


# =========================================


sub _prepare_mbean_names {
    my $self = shift;
    my $j4p = shift;
    my $list = shift;
    my $mbeans_by_name = {};
    my $mbeans_by_domain = {};
    for my $domain (keys %$list) {
        for my $name (keys %{$list->{$domain}}) {
            my $full_name = $domain . ":" . $name;
            
            my $e = {};
            my ($domain_p,$props) = $j4p->parse_name($full_name,1);
            $e->{domain} = $domain;
            $e->{props} = $props;
            $e->{info} = $list->{$domain}->{$name};
            my $keys = $self->_canonical_ordered_keys($props);
            $e->{string} = join ",", map { $_ . "=" . $props->{$_ } } @$keys;
            $e->{prompt} = length($e->{string}) > 25 ?  $self->_prepare_prompt($props,25,$keys) : $e->{string};
            $e->{full} = $full_name;
            
            $mbeans_by_name->{$full_name} = $e;
            my $k_v = $mbeans_by_domain->{$domain} || [];
            push @$k_v,$e;
            $mbeans_by_domain->{$domain} = $k_v;
        }
    }
    return ($mbeans_by_domain,$mbeans_by_name);
}

# Order keys according to importance first and the alphabetically
my @PREFERED_PROPS = qw(name type service);
sub _order_keys {
    my $self = shift;
    my $props = shift;

    # Get additional properties, not known to the prefered ones
    my $extra = { map { $_ => 1 } keys %$props };
    my @ret = ();
    for my $p (@PREFERED_PROPS) {
        if (exists($props->{$p})) {
            push @ret,$p;
            delete $extra->{$p};
        }
    }
    push @ret,sort keys %{$extra};
    return \@ret;
}

# Canonical ordered means lexically sorted
sub _canonical_ordered_keys {
    my $self = shift;
    my $props = shift;
    return [ sort keys %{$props} ];
}

# Prepare property part of a mbean suitable for using in 
# a shell prompt
sub _prepare_prompt {
    my $self = shift;
    my $props = shift;
    my $max = shift;
    my $keys = shift;
    my $len = $max - 3;
    my $ret = "";

    for my $k (@$keys) {
        if (exists($props->{$k})) {
            my $p = $k . "=" . $props->{$k};
            if (!length($ret)) {
                $ret = $p;
                if (length($ret) > $max) {
                    return substr($ret,0,$len) . "...";
                }
            } else {
                if (length($ret) + length($p) > $len) {
                    return $ret . ", ...";
                } else {
                    $ret .= "," . $p;
                }
            }
        }
    }

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
