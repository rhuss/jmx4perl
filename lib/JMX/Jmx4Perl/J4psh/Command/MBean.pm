#!/usr/bin/perl

package JMX::Jmx4Perl::J4psh::Command::MBean;
use strict;
use vars qw(@ISA);
use JMX::Jmx4Perl::J4psh::Command;
use Data::Dumper;

@ISA = qw(JMX::Jmx4Perl::J4psh::Command);

=head1 NAME 

JMX::Jmx4Perl::J4psh::Command::MBean - MBean commands

=head1 DESCRIPTION

=head1 COMMANDS

=over

=cut 


# Name of this command
sub name { "mbean" }

# We hook into as top-level commands
sub top_commands {
    my $self = shift;
    return $self->agent ? $self->domain_commands : {};
}

# The 'real' commands
sub domain_commands {
    my $self = shift;
    return {
            "ls" => { 
                     desc => "List MBean Domains",
                     proc => $self->cmd_list_domains,
                     args => $self->complete->mbeans(all => 1),
                    },
            "cd" => { 
                     desc => "Enter a domain",
                     proc => sub { 
                         my $domain = shift;
                         my $prop;
                         if ($domain) {
                             $domain =~ s/:+$//;
                             ($domain,$prop) = split(/:/,$domain,2) if $domain =~ /:/;
                         }    
                         $self->_cd_domain($domain);
                         if ($prop) {
                             eval {
                                 $self->_cd_mbean($domain,$prop);
                             };
                             if ($@) {
                                 # We already entered the domain successfully
                                 $self->pop_off_stack;
                                 die $@;
                             }
                         } 
                     },
                     args => $self->complete->mbeans(all => 1),
                    }
           };
}

sub property_commands { 
    my $self = shift;
    my $domain = shift;
    my $prop_cmds = $self->mbean_commands;
    return {
            "ls" => { 
                     desc => "List MBeans for a domain",
                     proc => $self->cmd_list_domains($domain),
                     args => $self->complete->mbeans(domain => $domain),
                    },
            "cd" => { 
                     desc => "Enter a MBean",
                     proc => sub {
                         my $input = shift;
                         if (!$self->_handle_navigation($input)) {
                             $self->_cd_mbean($domain,$input);
                         }
                     },
                     args => $self->complete->mbeans(domain => $domain),
                    }
           };
}

sub mbean_commands {
    my $self = shift;
    my $mbean_props = shift;
    return {
            "ls" => { 
                     desc => "List MBeans for a domain",
                     proc => $self->cmd_show_mbean($mbean_props),
                     #args => $self->complete->mbean_attribs($mbean_props),
                    },
            "cd" => {
                     desc => "Navigate up (..) or to the top (/)",
                     proc => sub {
                         my $input = shift;
                         $self->_handle_navigation($input);
                     },
                    }
           };
    # Commands for examining a certain MBean
}


# =================================================================================================== 

=item cmd_list

List commands which can filter mbean by wildcard and knows about the
following options:

=over

=item -l

Show attributes and operations

=back

If a single mbean is given as argument its details are shown.

=cut

sub cmd_list_domains {
    my $self = shift; 
    my $domain = shift;
    return sub {
        my $context = $self->context;
        my $agent = $context->agent;
        print "Not connected to a server\n" and return unless $agent;        
        my ($opts,@filters) = $self->extract_command_options(["l!"],@_);
        # Show all
        if (@filters) {
            for my $filter (@filters) {
                my $regexp = $self->convert_wildcard_pattern_to_regexp($filter);
                my $mbean_filter;
                ($filter,$mbean_filter) = ($1,$2) if ($filter && $filter =~ /(.*?):(.*)/) ;
                # It's a domain (pattern)
                $self->show_domain($opts,$self->_filter($context->mbeans_by_domain,$filter),$mbean_filter);
            }
        } else {
            $self->show_domain($opts,$self->_filter($context->mbeans_by_domain));
        }
    }
}

sub cmd_list_mbeans {

}

sub cmd_show_mbean {

}

sub show_mbeans {
    my $self = shift;
    my $opts = shift;
    my $infos = shift;
    my $mbean_filter;
    my $l = "";
    for my $m_info (sort { $a->{string} cmp $b->{string} } values %$infos) {
        my ($c_d,$c_s,$c_r) = $self->color("domain_name","stat_val","reset");
        $l .= $c_d . $m_info->{domain} . $c_r . ":";
        $l .= $self->_color_props($m_info) . "\n";
    }
    $self->print_paged($l);
}


sub show_domain {
    my $self = shift;
    my $opts = shift;
    my $infos = shift;
    my $mbean_filter = shift;
    $mbean_filter = $self->convert_wildcard_pattern_to_regexp($mbean_filter) if $mbean_filter;
    my $text = "";
    for my $domain (keys %$infos) {
        my ($c_d,$c_reset) = $self->color("domain_name","reset");
        $text .= $c_d . "$domain:" . $c_reset . "\n";
        for my $m_info (sort { $a->{string} cmp $b->{string} } @{$infos->{$domain}}) {
            next if ($mbean_filter && $m_info->{string} !~ $mbean_filter);
            $text .= "    ".$self->_color_props($m_info)."\n";
            $text .= $self->_list_details("         ",$m_info) if $opts->{l};
        }        
        $text .= "\n";
    }
    $self->print_paged($text);
}

sub _list_details {
    my $self = shift;
    my $indent = shift;
    my $m_info = shift;
    my ($c_s,$c_r) = $self->color("stat_val","reset");

    my $line = "";
    if ($m_info->{info}->{desc}) {
        $line .= $m_info->{info}->{desc};
    }
    my $nr_attr = scalar(keys %{$m_info->{info}->{attr}});
    my $nr_op = scalar(keys %{$m_info->{info}->{op}});
    my $nr_notif = scalar(keys %{$m_info->{info}->{notif}});
    if ($nr_attr || $nr_op || $nr_notif) {
        my @f;
        push @f,"Attributes: " . $c_s . $nr_attr . $c_r if $nr_attr;
        push @f,"Operations: " . $c_s . $nr_op . $c_r if $nr_op;
        push @f,"Notifications: " . $c_s . $nr_notif . $c_r if $nr_notif;
        $line .= $indent . join(", ",@f) . "\n";
    }
    return $line;
}

sub _color_props {
    my $self = shift;
    my $info = shift;
    my ($c_k,$c_v,$c_r) = $self->color("property_key","property_value","reset");
    return join ",",map { $c_k . $_ . $c_r . "=" . $c_v . $info->{props}->{$_} . $c_r } sort keys %{$info->{props}};
}

sub _filter {
    my $self = shift;
    my $map = shift;
    my @filters = @_;
    my @keys = keys %{$map};

    if (@filters) {
        my %filtered;
        for my $f (@filters) {
            my $regexp = $self->convert_wildcard_pattern_to_regexp($f);
            for my $d (@keys) {
                $filtered{$d} = $map->{$d} if $d =~ $regexp;
            }
        }
        return \%filtered;
    } else {
        return $map;
    }
}

=back

=cut


sub _cd_domain {
    my $self = shift;
    my $domain = shift;
    die "No domain $domain\n" unless $self->_check_domain($domain);
    my $prop_cmds = $self->property_commands($domain);
    &{$self->push_on_stack($domain,$prop_cmds,":")};
}

sub _cd_mbean {
    my $self = shift;
    my $domain = shift;
    my $mbean = shift;

    my $mbean_props = $self->_get_mbean($domain,$mbean);
    die "No MBean $domain:$mbean\n" unless $mbean_props; 
    my $mbean_cmds = $self->mbean_commands($mbean_props);
    &{$self->push_on_stack($mbean_props->{prompt},$mbean_cmds)};    
}

sub _check_domain {
    my $self = shift;
    my $domain = shift;
    my $context = $self->context;
    return exists($context->mbeans_by_domain->{$domain});

}

sub _get_mbean {
    my $self = shift;
    my $domain = shift;
    my $mbean = shift;
    my $context = $self->context;
    return $context->mbeans_by_name->{$domain . ":" . $mbean};
}

# Handle navigational commands
sub _handle_navigation {
    my $self = shift;
    my $input = shift;
    if ($input eq "..") {
        $self->pop_off_stack;
        return 1;
    } elsif ($input eq "/" || !$input) {
        $self->reset_stack;
        return 1;
    } else {
        return 0;
    }
}

sub _filter_domains {

};


=head1 LICENSE

This file is part of osgish.

Osgish is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

osgish is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with osgish.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or JMX or OSGi in
general), you might want to have a look at www.consol.com Contact
roland.huss@consol.de for further information (or use the contact form at
http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut



1;

