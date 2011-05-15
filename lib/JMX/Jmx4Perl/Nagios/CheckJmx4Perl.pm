package JMX::Jmx4Perl::Nagios::CheckJmx4Perl;

use strict;
use warnings;
use JMX::Jmx4Perl::Nagios::SingleCheck;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Response;
use Data::Dumper;
use Nagios::Plugin;
use Nagios::Plugin::Functions qw(:codes %STATUS_TEXT);
use Time::HiRes qw(gettimeofday tv_interval);
use Carp;
use Text::ParseWords;

our $AUTOLOAD;

=head1 NAME

JMX::Jmx4Perl::Nagios::CheckJmx4Perl - Module for encapsulating the functionality of
L<check_jmx4perl> 

=head1 SYNOPSIS

  # One line in check_jmx4perl to rule them all
  JMX::Jmx4Perl::Nagios::CheckJmx4Perl->new()->execute();

=head1 DESCRIPTION

The purpose of this module is to encapsulate a single run of L<check_jmx4perl> 
in a perl object. This allows for C<check_jmx4perl> to run within the embedded
Nagios perl interpreter (ePN) wihout interfering with other, potential
concurrent, runs of this check. Please refer to L<check_jmx4perl> for
documentation on how to use this check. This module is probably I<not> of 
general interest and serves only the purpose described above.

Its main task is to set up one ore more L<JMX::Jmx4Perl::Nagios::SingleCheck>
objects from command line arguments and optionally from a configuration file. 

=head1 METHODS

=over

=item $check = new $JMX::Jmx4Perl::Nagios::CheckJmx4Perl()

Set up a object used for a single check. It will parse the command line
arguments and any configuation file given.

=cut

sub new {
    my $class = shift;
    my $self = { };
    bless $self,(ref($class) || $class);
    $self->{np} = $self->create_nagios_plugin();
    $self->{cmd_args} = [ @ARGV ];

    $self->_print_doc_and_exit($self->{np}->opts->{doc}) if defined $self->{np}->opts->{doc};
    $self->_verify_and_initialize();
    return $self;
}

=back

=head1 $check->execute()

Send the JMX request to the server monitored and print out a nagios output. 

=cut

sub execute {
    my $self = shift;
    my $np = $self->{np};
    eval {
        # Request
        my @optional = ();

        my $error_stat = { };
        my $target_config = $self->target_config;
        my $jmx = JMX::Jmx4Perl->new(mode => "agent", url => $self->url, user => $self->user, 
                                     password => $self->password,
                                     product => $self->product, 
                                     proxy => $self->proxy_config,
                                     timeout => $np->opts->{timeout} || 180,
                                     target => $target_config);
        my @requests;
        for my $check (@{$self->{checks}}) {
            push @requests,@{$check->get_requests($jmx,\@ARGV)};            
        }
        my $responses = $self->_send_requests($jmx,@requests);
        my @extra_requests = ();
        my $nr_checks = scalar(@{$self->{checks}});
        if ($nr_checks == 1) {
            my @r = $self->{checks}->[0]->extract_responses($responses,\@requests,{ target => $target_config });
            push @extra_requests,@r if @r;
        } else {
            my $i = 1;
            for my $check (@{$self->{checks}}) {
                # A check can consume more than one response
                my @r = $check->extract_responses($responses,\@requests,
                                                    { 
                                                     target => $target_config, 
                                                     prefix => $self->_multi_check_prefix($check,$i++,$nr_checks),
                                                     error_stat => $error_stat
                                                    });
                push @extra_requests,@r if @r;
            }
        }
        # Send extra requests, e.g. for switching on the history
        if (@extra_requests) {
            $self->_send_requests($jmx,@extra_requests);
        }

        # Different outputs for multi checks/single checks
        $self->do_exit($error_stat);
    };
    if ($@) {
        # p1.pl, the executing script of the embedded nagios perl interpreter
        # uses this tag to catch an exit code of a plugin. We rethrow this
        # exception if we detect this pattern.
        if ($@ !~ /^ExitTrap:/) {
            $self->nagios_die("Error: $@");
        } else {
            die $@;
        }
    }
}

=head1 $check->exit()

Write out result and exit. This method can be overridden to provide a custom
output, which can be extracted from NagiosPlugin object.

=cut 

sub do_exit {
    my $self = shift;
    my $error_stat = shift;
    my $np = $self->{np};

    my ($code,$message) = $np->check_messages(join => "\n", join_all => "\n");
    ($code,$message) = $self->_prepare_multicheck_message($np,$code,$message,$error_stat) if scalar(@{$self->{checks}}) > 1;
    
    $np->nagios_exit($code, $message);
}

sub _prepare_multicheck_message {
    my $self = shift;
    my $np = shift;
    my $code = shift;
    my $message = shift;
    my $error_stat = shift;

    my $summary;
    my $nr_checks = scalar(@{$self->{checks}});
    if ($code eq OK) {
        $summary = "All " . $nr_checks . " checks OK";            
    } else {
        my $nr_warnings = scalar(@{$np->messages->{warning} || []});
        my $nr_errors = scalar(@{$np->messages->{critical} || []});
        my @parts;
        my $extra = "";
        my $nr = 0;
        for my $code (CRITICAL,WARNING,UNKNOWN) {
            if (my $errs = $error_stat->{$code}) {
                $extra .= scalar(@$errs) . " " . $STATUS_TEXT{$code} . " (" . join (",",@$errs) . "), ";
                $nr += scalar(@$errs);
            }
        }
        if ($nr > 0) {
            # Cut off extra chars at the end
            $extra = substr($extra,0,-2);
        }
        $summary = $nr . " of " . $nr_checks . " failed: " . $extra;
    }
    return ($code,$summary . "\n" . $message);    
}

# Create a formatted prefix for multicheck output
sub _multi_check_prefix {
    my $self = shift;
    my $check = shift;
    my $idx = shift;
    my $max = shift;
    my $label = $check->{config}->{key} || $check->{config}->{name} || "";
    my $l = length($max);
    return sprintf("[%$l.${l}s] %%c %s: ",$idx,$label);
}


# Send the requests via the build up agent
sub _send_requests {
    my ($self,$jmx,@requests) = @_;
    my $o = $self->{opts};

    my $start_time;
    if ($o->verbose) {
        # TODO: Print summary of request (GET vs POST)
        if ($self->user) {
            print "Remote User: ",$o->user,"\n";
        }
        $start_time = [gettimeofday];
    }
    my @responses = $jmx->request(@requests);
    if ($o->verbose) {
        print "Result fetched in ",tv_interval($start_time) * 1000," ms:\n";
        print Dumper(\@responses);
    }
    #print Dumper(\@responses);
    return \@responses;
}

# Print online manual and exit (somewhat crude, I know)
sub _print_doc_and_exit {
    my $self = shift;
    my $section = shift;
    if (!eval "require Pod::Usage; Pod::Usage->import(qw(pod2usage)); 1;") {
        print "Please install Pod::Usage for creating the online help\n";
        exit 1;
    }
    if ($section) {
        my %sects = ( 
                     tutorial => "TUTORIAL",
                     reference => "REFERENCE",
                     options => "COMMAND LINE",
                     config => "CONFIGURATION",
                    );
        my $real_section = $sects{lc $section};
        if ($real_section) {
            pod2usage(-verbose => 99, -sections =>  $real_section );
        } else {
            print "Unknown documentation section '$section' (known: ",join (",",sort keys %sects),")\n";
            exit 1;
        }
    } else {
        pod2usage(-verbose => 99);
    }
}


# Initialize this object and validate the mandatory parameters (obtained from
# the command line or a configuration file). It will also build up 
# one or more SingleCheck which are later on sent as a bulk request to 
# the server.
sub _verify_and_initialize { 
    my $self = shift;
    my $np = $self->{np};
    my $o = $np->opts;
    
    $self->{opts} = $self->{np}->opts;

    # Fetch configuration
    my $config = $self->_get_config($o->config);
    
    # Now, if a specific check is given, extract it, too.
    my $check_configs;
    $check_configs = $self->_extract_checks($config,$o->check);
    if ($check_configs) {
        for my $c (@$check_configs) {
            my $s_c = new JMX::Jmx4Perl::Nagios::SingleCheck($np,$c);
            push @{$self->{checks}},$s_c;
        }
    } else {
        $self->{checks} = [ new JMX::Jmx4Perl::Nagios::SingleCheck($np) ];
    }
    # If a server name is given, we use that for the connection parameters
    if ($o->server) {
        $self->{server_config} = $config->get_server_config($o->server)
          || $self->nagios_die("No server configuration for " . $o->server . " found");
    } 

    # Sanity checks
    $self->nagios_die("No Server URL given") unless $self->url;

    for my $check (@{$self->{checks}}) {
        my $name = $check->name ? " [Check: " . $check->name . "]" : "";
        $self->nagios_die("An MBean name and a attribute/operation must be provided " . $name)
          if ((!$check->mbean || (!$check->attribute && !$check->operation)) && !$check->alias && !$check->value);
        $self->verify_check($check,$name);
    }
}

sub verify_check {
    my $self = shift;
    my $check = shift;
    my $name = shift;
    my $np = $self->{np};
    $self->nagios_die("At least a critical or warning threshold must be given " . $name) 
      if ((!defined($check->critical) && !defined($check->warning)));        
}

# Extract one or more check configurations which can be 
# simle <Check>s or <MultiCheck>s
sub _extract_checks {
    my $self = shift;
    my $config = shift;
    my $check = shift;
    
    my $np = $self->{np};
    if ($check) {
        $self->nagios_die("No configuration given") unless $config;
        $self->nagios_die("No checks defined in configuration") unless $config->{check};
        
        my $check_configs;
        unless ($config->{check}->{$check}) {
            $check_configs = $self->_resolve_multicheck($config,$check,$self->{cmd_args});
        } else {
            my $check_config = $config->{check}->{$check};
            $check_configs = ref($check_config) eq "ARRAY" ? $check_config : [ $check_config ];
            $check_configs->[0]->{key} = $check;
        }
        $self->nagios_die("No check configuration with name " . $check . " found") unless (@{$check_configs});

        # Resolve parent values
        for my $c (@{$check_configs}) {
            #print "[A] ",Dumper($c);
            $self->_resolve_check_config($c,$config,$self->{cmd_args});
            
            #print "[B] ",Dumper($c);
            # Finally, resolve any left over place holders
            for my $k (keys(%$c)) {
                $c->{$k} = $self->_replace_placeholder($c->{$k},undef) unless ref($c->{$k});
            }
            # print "[C] ",Dumper($c);
        }
        return $check_configs;
    } else {
        return undef;
    }    
}

# Resolve a multicheck configuration (<MultiCheck>)
sub _resolve_multicheck {
    my $self = shift;
    my $config = shift;
    my $check = shift;
    my $args = shift;
    my $np = $self->{np};
    my $multi_checks = $config->{multicheck};    
    my $check_config = [];
    if ($multi_checks)  {
        my $m_check = $multi_checks->{$check};
        if ($m_check) {
            if ($m_check->{check}) {
                # Resolve all checks
                my $c_names = ref($m_check->{check}) eq "ARRAY" ? $m_check->{check} : [ $m_check->{check} ];
                for my $name (@$c_names) {
                    my ($c_name,$c_args) = $self->_parse_check_ref($name);
                    my $args_merged = $self->_merge_multicheck_args($c_args,$args);
                    # We need a copy of the check hash to avoid mangling it up
                    # if it is referenced multiple times
                    $self->nagios_die("Unknown check '" . $c_name . "' for multi check " . $check) 
                      unless defined($config->{check}->{$c_name});
                    my $check = { %{$config->{check}->{$c_name}} };
                    $check->{key} = $c_name;
                    $check->{args} = $args_merged;
                    push @{$check_config},$check;
                }
            }
            if ($m_check->{multicheck}) {
                my $mc_names = ref($m_check->{multicheck}) eq "ARRAY" ? $m_check->{multicheck} : [ $m_check->{multicheck} ];
                for my $name (@$mc_names) {                    
                    my ($mc_name,$mc_args) = $self->_parse_check_ref($name);
                    my $args_merged = $self->_merge_multicheck_args($mc_args,$args);
                    $self->nagios_die("Unknown multi check '" . $mc_name . "'")
                      unless $multi_checks->{$mc_name};
                    push @{$check_config},@{$self->_resolve_multicheck($config,$mc_name,$args_merged)};
                }
            }
        }
    }
    return $check_config;
}

sub _merge_multicheck_args {
    my $self = shift;
    my $check_params = shift;
    my $args = shift;
    if (!$args || !$check_params) {
        return $check_params;
    }
    my $ret = [ @$check_params ]; # Copy it over
    for my $i (0 .. $#$check_params) {
        if ($check_params->[$i] =~ /^\$(\d+)$/) {
            my $j = $1;
            if ($j <= $#$args) {
                $ret->[$i] = $args->[$j];
                next;
            }
            # Nothing to replace
            $ret->[$i] = $check_params->[$i];
        }
    }
    return $ret;
}

# Resolve a singe <Check> configuration
sub _resolve_check_config {
    my $self = shift;
    my $check = shift;
    my $config = shift;
    # Args can come from the outside, but also as part of a multicheck (stored
    # in $self->{args})
    my $args = $check->{args} && @{$check->{args}} ? $check->{args} : shift;
    my $np = $self->{np};
    if ($check->{use}) {
        # Resolve parents
        my $parents = ref($check->{use}) eq "ARRAY" ? $check->{use} : [ $check->{use} ];
        my $parent_merged = {};
        for my $p (@$parents) {
            my ($p_name,$p_args) = $self->_parse_check_ref($p);
            $self->nagios_die("Unknown parent check '" . $p_name . "' for check '" . 
                            ($check->{key} ? $check->{key} : $check->{name}) . "'") 
              unless $config->{check}->{$p_name};
            # Clone it to avoid side effects when replacing checks inline
            my $p_check = { %{$config->{check}->{$p_name}} };
            $p_check->{key} = $p_name;
#            print "::::: ",Dumper($p_check,$p_args);

            $self->_resolve_check_config($p_check,$config,$p_args);

            #$self->_replace_args($p_check,$config,$p_args);
            $parent_merged->{$_} = $p_check->{$_} for keys %$p_check;
        }
        # Replace inherited values
        for my $k (keys %$parent_merged) {
            my $parent_val = $parent_merged->{$k} || "";
            if (defined($check->{$k})) {
                $check->{$k} =~ s/\$BASE/$parent_val/g;
            } else {
                $check->{$k} = $parent_val;
            }
        }
    }
    $self->_replace_args($check,$config,$args);
    #print Dumper($check);
    return $check;
}

# Replace argument placeholders with a given list of arguments
sub _replace_args {
    my $self = shift;
    my $check = shift;
    my $config = shift;
    my $args = shift;
    for my $k (keys(%$check)) {
        next if $k =~ /^(key|args)$/; # Internal keys
        $check->{$k} = 
          $self->_replace_placeholder($check->{$k},$args)
            if ($args && @$args && !ref($check->{$k}));
    }
}

sub _replace_placeholder {
    my $self = shift;
    my $val = shift;
    my $args = shift;

    my $index = defined($args) ? join "|",0 ... $#$args : "\\d+";

    my $regexp;
    eval '$regexp = qr/^(.*?)\$((' . $index . ')|\{\s*(' . $index . ')\s*:([^\}]+)\})(.*|$)/';
    die "Cannot create placeholder regexp" if $@;
    my $rest = $val;
    my $ret = "";
    while (defined($rest) && length($rest) && $rest =~ /$regexp/) {        
        my $start = defined($1) ? $1 : "";
        my $orig_val = '$' . $2;
        my $i = defined($3) ? $3 : $4;
        my $default = $5;
        my $end = defined($6) ? $6 : "";
        #print Dumper({start => $start, orig => $orig_val,end => $end, default=> $default, rest => $rest, i => $i}); 
        if (defined($args)) {
            my $repl = $args->[$i];            
            if (defined($repl)) { 
                if ($repl =~ /^\$(\d+)$/) {
                    my $new_index = $1;
                    #print "============== $val $new_index\n";
                    # Val is a placeholder itself
                    if (defined($default)) {
                        $ret .= $start . '${' . $new_index . ':' . $default . '}';
                    } else {
                        $ret .= $start . '$' . $new_index;
                    }
                } else {   
                    $ret .= $start . $repl;
                }
            } else {
                $ret .= $start . $orig_val;
            }
        } else {
            # We have to replace any left over placeholder either with its 
            # default value or with an empty value
            if (defined($default)) {
                $ret .= $start . $default;
            } elsif (length($start) || length($end)) {
                $ret .= $start;
            } else {
                if (!length($ret)) {
                    # No default value, nothing else for this value. We
                    # consider at undefined
                    return undef;
                }
            }
        }
        $rest = $end;
        #print "... $ret$rest\n";
    }
    return $ret . (defined($rest) ? $rest : "");
}

# Split up a 'Use' parent config reference, including possibly arguments
sub _parse_check_ref {
    my $self = shift;
    my $check_ref = shift;
    if ($check_ref =~/^\s*([^(]+)\(([^)]*)\)\s*$/) {
        my $name = $1;
        my $args_s = $2;
        my $args = [ parse_line('\s*,\s*',0,$args_s) ];
        return ($name,$args);
    } else {
        return $check_ref;
    }
}

# Get the configuration as a hash
sub _get_config {
    my $self = shift;
    my $path = shift;
    my $np = $self->{np};
    $self->nagios_die("No configuration file " . $path . " found")
      if ($path && ! -e $path);
    return new JMX::Jmx4Perl::Config($path);
}

# The global server config part
sub _server_config {
    return shift->{server_config};
}

# Create the nagios plugin used for preparing the nagious output
sub create_nagios_plugin {
    my $self = shift;
    my $np = Nagios::Plugin->
      new(
          usage => 
          "Usage: %s -u <agent-url> -m <mbean> -a <attribute> -c <threshold critical> -w <threshold warning>\n" . 
          "                      [--alias <alias>] [--value <shortcut>] [--base <alias/number/mbean>] [--delta <time-base>]\n" .
          "                      [--name <perf-data label>] [--label <output-label>] [--product <product>]\n".
          "                      [--user <user>] [--password <password>] [--proxy <proxy>]\n" .
          "                      [--target <target-url>] [--target-user <user>] [--target-password <password>]\n" .
          "                      [--config <config-file>] [--check <check-name>] [--server <server-alias>] [-v] [--help]\n" .
          "                      arg1 arg2 ....",
          version => $JMX::Jmx4Perl::VERSION,
          url => "http://www.jmx4perl.org",
          plugin => "check_jmx4perl",
          blurb => "This plugin checks for JMX attribute values on a remote Java application server",
          extra => "\n\nYou need to deploy jolokia.war on the target application server or an intermediate proxy.\n" .
          "Please refer to the documentation for JMX::Jmx4Perl for further details.\n\n" .
          "For a complete documentation please consult the man page of check_jmx4perl or use the option --doc"
         );
    $np->shortname(undef);
    $self->add_common_np_args($np);
    $self->add_nagios_np_args($np);
    $np->getopts();
    return $np;
}

sub add_common_np_args {
    my $self = shift;
    my $np = shift;

    $np->add_arg(
                 spec => "url|u=s",
                 help => "URL to agent web application (e.g. http://server:8080/jolokia/)",
                );
    $np->add_arg(
                 spec => "product=s",
                 help => "Name of app server product. (e.g. \"jboss\")",
                );
    $np->add_arg(
                 spec => "alias=s",
                 help => "Alias name for attribte (e.g. \"MEMORY_HEAP_USED\")",
                );
    $np->add_arg(
                 spec => "mbean|m=s",
                 help => "MBean name (e.g. \"java.lang:type=Memory\")",
        );
    $np->add_arg(
                 spec => "attribute|a=s",
                 help => "Attribute name (e.g. \"HeapMemoryUsage\")",
                );
    $np->add_arg(
                 spec => "operation|o=s",
                 help => "Operation to execute",
                );
    $np->add_arg(
                 spec => "value=s",
                 help => "Shortcut for specifying mbean/attribute/path. Slashes within names must be escaped with \\",
                );
    $np->add_arg(
                 spec => "delta|d:s",
                 help => "Switches on incremental mode. Optional argument are seconds used for normalizing.",
                );
    $np->add_arg(
                 spec => "path|p=s",
                 help => "Inner path for extracting a single value from a complex attribute or return value (e.g. \"used\")",
                );
    $np->add_arg(
                 spec => "target=s",
                 help => "JSR-160 Service URL specifing the target server"
                );
    $np->add_arg(
                 spec => "target-user=s",
                 help => "Username to use for JSR-160 connection (if --target is set)"
                );
    $np->add_arg(
                 spec => "target-password=s",
                 help => "Password to use for JSR-160 connection (if --target is set)"
                );
    $np->add_arg(
                 spec => "proxy=s",
                 help => "Proxy to use"
                );
    $np->add_arg(
                 spec => "user=s",
                 help => "User for HTTP authentication"
                );
    $np->add_arg(
                 spec => "password=s",
                 help => "Password for HTTP authentication"
                );
    $np->add_arg(
                 spec => "name|n=s",
                 help => "Name to use for output. Optional, by default a standard value based on the MBean ".
                 "and attribute will be used"
                );
    $np->add_arg(
                 spec => "config=s",
                 help => "Path to configuration file. Default: ~/.j4p"
                );
    $np->add_arg(
                 spec => "server=s",
                 help => "Symbolic name of server url to use, which needs to be configured in the configuration file"                 
                );
    $np->add_arg(
                 spec => "check=s",
                 help => "Name of a check configuration as defined in the configuration file"
                );
    $np->add_arg(
                 spec => "method=s",
                 help => "HTTP method to use. Either \"get\" or \"post\""
                );
    $np->add_arg(
                 spec => "doc:s",
                 help => "Print the documentation of check_jmx4perl, optionally specifying the section (tutorial, args, config)"
                );
}

sub add_nagios_np_args {
    my $self = shift;
    my $np = shift;

    $np->add_arg(
                 spec => "base|base-alias|b=s",
                 help => "Base alias name, which when given, interprets critical and warning values as relative in the range 0 .. 100%",
                );
    $np->add_arg(
                 spec => "unit=s",
                 help => "Unit of measurement of the data retreived. Recognized values are [B|KB|MN|GB|TB] for memory values and [us|ms|s|m|h|d] for time values"
                );    
    $np->add_arg(
                 spec => "null=s",
                 help => "Value which should be used in case of a null return value of an operation or attribute. Is \"null\" by default"
                );
    $np->add_arg(
                 spec => "string",
                 help => "Force string comparison for critical and warning checks"
                );
    $np->add_arg(
                 spec => "numeric",
                 help => "Force numeric comparison for critical and warning checks"
                );
    $np->add_arg(
                 spec => "critical|c=s",
                 help => "Critical Threshold for value. " . 
                 "See http://nagiosplug.sourceforge.net/developer-guidelines.html#THRESHOLDFORMAT " .
                 "for the threshold format.",
                );
    $np->add_arg(
                 spec => "warning|w=s",
                 help => "Warning Threshold for value.",
                );
    $np->add_arg(
                 spec => "label|l=s",
                 help => "Label to be used for printing out the result of the check. Placeholders can be used."
                );
    $np->add_arg(
                 spec => "unknown-is-critical",
                 help => "Map UNKNOWN errors to errors with a CRITICAL status"
                );
}

# Access to configuration informations
# Known config options (key: cmd line arguments, values: keys in config);
my $SERVER_CONFIG_KEYS = {
                          "url" => "url",
                          "user" => "user",
                          "password" => "password",
                          "product" => "product",
                         };

# Get target configuration or undef if no jmx-proxy mode
# is used
sub target_config {
    return shift->_target_or_proxy_config("target","target-user","target-password");
}

# Get proxy configuration or undef if no proxy configuration
# is used
sub proxy_config {
    return shift->_target_or_proxy_config("proxy","proxy-user","proxy-password");
}

sub _target_or_proxy_config {
    my $self = shift;
    
    my $main_key = shift;
    my $user_opt = shift;
    my $password_opt = shift;

    my $np = $self->{np};
    my $opts = $np->opts;
    my $server_config = $self->_server_config;
    if ($opts->{$main_key}) {
        # Use configuration from the command line:
        return { 
                url => $opts->{$main_key},
                user => $opts->{$user_opt},
                password => $opts->{$password_opt}
               }
    } elsif ($server_config && $server_config->{$main_key}) {
        # Use configuration directly from the server definition:
        return $server_config->{$main_key}
    } else {
        return undef;
    }
}

# Autoloading is used to fetch the proper connection parameters
sub AUTOLOAD {
    my $self = shift;
    my $np = $self->{np};
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    my $opts_name = $name;
    $opts_name =~ s/_/-/;

    if ($SERVER_CONFIG_KEYS->{$name}) {        
        return $np->opts->{$opts_name} if $np->opts->{$opts_name};
        my $c = $SERVER_CONFIG_KEYS->{$name};
        if ($c) {
            my @parts = split "/",$c;
            my $h = $self->_server_config ||
              return undef;
            while (@parts) {
                my $p = shift @parts;
                return undef unless $h->{$p};
                $h = $h->{$p};
                return $h unless @parts;
            }
        } else {
            return undef;
        }
    } else {
        $self->nagios_die("No config attribute \"" . $name . "\" known");
    }
}

sub nagios_die {
    my $self = shift;
    my @args = @_;
    
    my $np = $self->{np};
    $np->nagios_die(join("",@args),$np->opts->{'unknown-is-critical'} ? CRITICAL : UNKNOWN)
}

# Declared here to avoid AUTOLOAD confusions
sub DESTROY {

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

=head1 AUTHOR

roland@cpan.org

=cut

1;
