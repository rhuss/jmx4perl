#!/usr/bin/perl

package JMX::Jmx4Perl::J4psh::Command::MBean;
use strict;
use base qw(JMX::Jmx4Perl::J4psh::Command);
use JMX::Jmx4Perl::Request;
use Data::Dumper;


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
                    },
            "cat" => { 
                      desc => "Show value of an attribute",
                      proc => $self->cmd_show_attributes($mbean_props),
                      args => $self->complete->mbean_attributes($mbean_props),
                     },
            "set" => { 
                      desc => "Set value of an attribute",
                      proc => $self->cmd_set_attribute($mbean_props),
                      args => $self->complete->mbean_attributes($mbean_props),
                     },
             
            "exec" => { 
                       desc => "Execute an operation",
                       proc => $self->cmd_execute_operation($mbean_props),
                       args => $self->complete->mbean_operations($mbean_props),
                      },
             
           };
}

sub cmd_show_attributes {
    my $self = shift;
    my $m_info = shift; 
    return sub {
        my $attributes = @_;
        my $info = $m_info->{info};
        my $mbean = $m_info->{full};
        my $context = $self->context;
        my $agent = $context->agent;
        my @attrs = ();
        for my $a (@_) {
            if ($a =~ /[\*\?]/) {
                my $regexp = $self->convert_wildcard_pattern_to_regexp($a);
                push @attrs, grep { $_ =~ /^$regexp$/ } keys %{$m_info->{info}->{attr}};
            } else {
                push @attrs,$a;
            }
        }
        # Use only unique values
        my %attrM =  map { $_ => 1 } @attrs;
        @attrs = keys %attrM;
        if (@attrs == 0) {
            die "No attribute given\n";
        }
        my $request = JMX::Jmx4Perl::Request->new(READ,$mbean,\@attrs,{ignoreErrors => 1});
        my $response = $agent->request($request);
        if ($response->is_error) {
            die "Error: " . $response->error_text;
        }
        my $values = $response->value;
        my $p = "";
        my ($c_a,$c_r) = $self->color("attribute_name","reset");
        if (@attrs > 1) {
            # Print as list
            for my $attr (@attrs) {
                my $value = $values->{$attr};
                if (ref($value)) {
                    $p .= sprintf(" $c_a%-31.31s$c_r\n",$attr);
                    $p .= $self->_dump($value);
                } else {
                    $p .= sprintf(" $c_a%-31.31s$c_r %s\n",$attr,$value);
                }
            }
        } else {
            # Print single attribute
            my $value =  $values->{$attrs[0]};
            if (ref($value)) {
                $p .= $self->_dump($value);
            } else {
                $p .= $value."\n";
            }
        }
        $self->print_paged($p);
    };

}

sub cmd_set_attribute {
    my $self = shift;
    my $m_info = shift;
    return sub {
        my @args = @_;
        die "Usage: set <attribute-name> <value> [<path>]\n" if (@args != 2 && @args != 3);
        my $mbean = $m_info->{full};
        my $agent = $self->context->agent;
        my $req = new JMX::Jmx4Perl::Request(WRITE,$mbean,$args[0],$args[1],$args[2]);
        my $resp = $agent->request($req);
        if ($resp->is_error) {
            die $resp->error_text . "\n";
        }
        my $old_value = $resp->value;
        my ($c_l,$c_r) = $self->color("label","reset");

        my $p = "";
        if (ref($old_value)) {
            $p .= sprintf(" $c_l%-5.5ss$c_r\n","Old:");
            $p .= $self->_dump($old_value);
        } else {
            $p .= sprintf(" $c_l%-5.5s$c_r %s\n","Old:",$old_value);
        }
        $p .= sprintf(" $c_l%-5.5s$c_r %s\n","New:",$args[1]);;
        $self->print_paged($p);
    }
}

sub cmd_execute_operation {
    my $self = shift;
    my $m_info = shift;
    return sub {
        my @args = @_;
        die "Usage: exec <attribute-name> <value> [<path>]\n" if (!@args);
        my $mbean = $m_info->{full};
        my $agent = $self->context->agent;
        my $req = new JMX::Jmx4Perl::Request(EXEC,$mbean,@args,{ignoreErrors => 1});
        my $resp = $agent->request($req);
        if ($resp->is_error) {
            die $resp->error_text . "\n";
        }
        my $value = $resp->value;
        my ($c_l,$c_r) = $self->color("label","reset");

        my $p = "";
        if (ref($value)) {
            $p .= sprintf(" $c_l%-7.7s$c_r\n","Return:");
            $p .= $self->_dump($value);
        } else {
            $p .= sprintf(" $c_l%-7.7s$c_r %s\n","Return:",$value);
        }
        $self->print_paged($p);
    }
}

sub _dump {
    my $self = shift;
    my $value = shift;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Indent = 1;
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Deparse = 1;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Sortkeys = 1;
    my $ret = Dumper($value);
    $ret =~ s/^/   /gm;
    return $ret;
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
        if ($domain) {
            if (@filters) {
                @filters = map { $domain . ":" .$_ } @filters
            } else {
                @filters = "$domain:*";
            }
        }
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

sub cmd_show_mbean {
    my $self = shift;
    my $m_info = shift;
    return sub {
        my $info = $m_info->{info};
        my ($c_m,$c_a,$c_o,$c_r) = $self->color("mbean_name","attribute_name","operation_name","reset");
        my $op_len = 50 + length($c_o) + length($c_r);
        
        my $p = "";
        
        my $name = $m_info->{full};
        $p .= $c_m . $name . $c_r;
        $p .= "\n\n";
        
        #print Dumper($m_info);

        my $attrs = $info->{attr};
        if ($attrs && keys %$attrs) {
            $p .= "Attributes:\n";
            for my $attr (keys %$attrs) {
                if (length($attr) > 31) {
                    $p .= sprintf("  $c_a%s$c_r\n",$attr);
                    $p .= sprintf("  %-31.31s %-13.13s %-4.4s %s\n",
                                  $self->_pretty_print_type($attrs->{$attr}->{type}),
                                  $attrs->{$attr}->{rw} eq "false" ? "[ro]" : "",$attrs->{$attr}->{desc});
                } else {
                    $p .= sprintf("  $c_a%-31.31s$c_r %-13.13s %-4.4s %s\n",$attr,
                                  $self->_pretty_print_type($attrs->{$attr}->{type}),
                                  $attrs->{$attr}->{rw} eq "false" ? "[ro]" : "",$attrs->{$attr}->{desc});
                }
            }
            $p .= "\n";
        }
        my $ops = $info->{op};
        if ($ops && keys %$ops) {
            $p .= "Operations:\n";
            for my $op (keys %$ops) {
                my $overloaded = ref($ops->{$op}) eq "ARRAY" ? $ops->{$op} : [ $ops->{$op} ];
                for my $m_info (@$overloaded) {
                    my $sig = $self->_signature_to_print($op,$m_info);
                    if (length($sig) > $op_len) {
                        $p .= sprintf("  %s\n",$sig);
                        $p .= sprintf("  %-50.50s %s\n","",$m_info->{desc}) if $m_info->{desc};                        
                    } else {
                        $p .= sprintf("  %-${op_len}.${op_len}s %s\n",$sig,$m_info->{desc});
                    }
                }
            }
            $p .= "\n";
        }
        $self->print_paged($p);
        #print Dumper($info);
    }
}

sub _line_aligned {
    my $self = shift;
    my $max_lengths = shift;
    my $lengths = shift;
    my $parts = shift;
    my $opts = shift;
        
    my $term_width = $self->context->term_width;
    my $overflow = $opts->{overflow_col} || 0;
    my $wrap_last = $opts->{wrap};
    my $ret = "";
    for my $i (0 .. $overflow) {
        if ($lengths->[$i] > $max_lengths->[$i]) {
            
            # Do overflow
        }
    }
    
}

sub _signature_to_print {
    my $self = shift;
    my $op = shift;
    my $info = shift;
    my ($c_o,$c_r) = $self->color("operation_name","reset");
#    print Dumper($info);
    my $ret = $self->_pretty_print_type($info->{ret}) . " ";
    $ret .= $c_o . $op . $c_r;
    $ret .= "(";
    my $args = $info->{args};
    my @arg_cl = ();
    for my $a (@$args) {
        if (ref($a) eq "HASH") {
            push @arg_cl,$self->_pretty_print_type($a->{type})
        } else {
            push @arg_cl,$self->_pretty_print_type($a);
        }
    }
    $ret .= join ",",@arg_cl;
    $ret .= ")";
    return $ret;
}

sub _pretty_print_type {
    my $self = shift;
    my $type = shift;
    my $suffix = "";
    my $type_p;
    if ($type eq "[J") {
        return "long[]";
    } elsif ($type =~ /^\[L(.*);/) {
        $type_p = $1;
        $suffix = "[]";
    } else {
        $type_p = $type;
    }
    $type_p =~ s/^.*\.([^\.]+)$/$1/;
    return $type_p . $suffix;
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
    #return Dumper($info);
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

