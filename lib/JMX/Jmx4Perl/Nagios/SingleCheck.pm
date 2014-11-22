package JMX::Jmx4Perl::Nagios::SingleCheck;

use strict;
use warnings;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Response;
use JMX::Jmx4Perl::Alias;
use Data::Dumper;
use Nagios::Plugin;
use Nagios::Plugin::Functions qw(:codes %STATUS_TEXT);
use Carp;
use Scalar::Util qw(looks_like_number);
use URI::Escape;
use Text::ParseWords;
use JSON;

our $AUTOLOAD;

=head1 NAME

JMX::Jmx4Perl::Nagios::SingleCheck - A single nagios check

This is an package used internally by
L<JMX::Jmx4Perl::Nagios::CheckJmx4Perl>. It encapsulates the configuration for
single checks, which can be combined to a bulk JMX-Request so only a single
server turnaround is used to obtain multiple checks results at once.

=head1 METHODS

=over

=item $single_check = new $JMX::Jmx4Perl::Nagios::SingleCheck($nagios_plugin,$check_config)

Construct a new single check from a given L<Nagios::Plugin> object
C<$nagios_plugin> and a parsed check configuration $check_config, which is a
hash. 

=cut

sub new { 
    my $class = shift;
    my $np = shift || die "No Nagios Plugin given";
    my $config = shift;
    my $self = { 
                np => $np,
                config => $config
               };
    bless $self,(ref($class) || $class);
    return $self;
}

=item $requests = $single_check->get_requests($jmx,$args)

Called to obtain an arrayref of L<JMX::Jmx4Perl::Request> objects which should
be send to the server agent. C<$jmx> ist the L<JMX::Jmx4Perl> agent, C<$args>
are additonal arguments used for exec-operations,

Multiple request object are returned e.g. if a relative check has to be
performed in order to get the base value as well.

The returned array can contain coderefs which should be executed directly and
its return value should be used in order to perfoorm the check. 

=cut

sub get_requests {
    my $self = shift;
    my $jmx = shift;
    my $args = shift;
    # If a script is given, extract a subref and return it
    return [ $self->_extract_script_as_subref($jmx) ] if $self->script;

    my $do_read = $self->attribute || $self->value;
    my $do_exec = $self->operation;
    if ($self->alias) {
        my $alias = JMX::Jmx4Perl::Alias->by_name($self->alias);
        die "No alias '",$self->alias," known" unless $alias;
        $do_read = $alias->type eq "attribute";
    }
    my @requests = ();
    my $request;
    if ($do_read) {
        $request = JMX::Jmx4Perl::Request->new(READ,$self->_prepare_read_args($jmx));
    } elsif ($do_exec) {
        $request = JMX::Jmx4Perl::Request->new(EXEC,$self->_prepare_exec_args($jmx,@$args));
    } else {
        die "Neither an attribute/value, an operation or a script given";
    }
    my $method = $self->{np}->opts->{method} || $self->{config}->{method};
    if ($method) {
        $request->method($method);
    }
    push @requests,$request;

    if ($self->base || $self->base_mbean) {
        if (!looks_like_number($self->base)) {
            # It looks like a number, so we will use the base literally
            my $alias;
            
            if ($self->base) {
                $alias = JMX::Jmx4Perl::Alias->by_name($self->base);
            }
            if ($alias) {
                push @requests,new JMX::Jmx4Perl::Request(READ,$jmx->resolve_alias($self->base));
            } else {
                my ($mbean,$attr,$path) = $self->base_mbean ? 
                  ($self->base_mbean, $self->base_attribute, $self->base_path) : 
                    $self->_split_attr_spec($self->base);
                die "No MBean given in base name ",$self->base unless $mbean;
                die "No Attribute given in base name ",$self->base unless $attr;
                
                $mbean = URI::Escape::uri_unescape($mbean);
                $attr = URI::Escape::uri_unescape($attr);
                $path = URI::Escape::uri_unescape($path) if $path;
                push @requests,new JMX::Jmx4Perl::Request(READ,$mbean,$attr,$path);
            }
        }
    }
    
    return \@requests;
}

# Create a subref where all params from the outside are available as closures.
sub _extract_script_as_subref {
    my $self = shift;
    my $jmx = shift;
    my $script = $self->script || die "No script given";
    my $full_script = <<"EOT";
sub {
  my \$j4p = shift;
  return sub { 
     $script
  }
}
EOT
    #print $full_script,"\n";
    my $sub = eval $full_script;
    die "Cannot eval script for check ",$self->name,": $@" if $@;
    return &$sub($jmx);
}

=item $single_check->exract_responses($responses,$requests,$target)

Extract L<JMX::Jmx4Perl::Response> objects and add the deducted results to 
the nagios plugin (which was given at construction time).

C<$responses> is an arrayref to the returned responses, C<$requests> is an
arrayref to the original requests. Any response consumed from C<$requests>
should be removed from the array, as well as the corresponding request.
The requests/responses for this single request are always a the beginning of 
the arrays.

C<$target> is an optional target configuration if the request was used in
target proxy mode.

=cut

sub extract_responses {
    my $self = shift;    
    my $responses = shift;
    my $requests = shift;
    my $opts = shift || {};
    my $np = $self->{np};
    my $msg_handler = $np->{msg_handler} || $np; 

    # Get response/request pair
    my $resp = shift @{$responses};
    my $request = shift @{$requests};
    #print Dumper($resp);
    my @extra_requests = ();
    my $value;
    my $script_mode = undef;
    if (ref($request) eq "CODE") {
        # It's a script, so the 'response' is already the value
        $script_mode = 1;
        $value = $resp;
    } else {
        $self->_verify_response($request,$resp);
        $value = $self->_extract_value($request,$resp);
    }
   
    # Delta handling
    my $delta = $self->delta;
    if (defined($delta) && !$script_mode) {
        $value = $self->_delta_value($request,$resp,$delta);
        unless (defined($value)) {
            push @extra_requests,$self->_switch_on_history($request,$opts->{target});
            $value = 0;
        }
    }
    
    # Normalize value 
    my ($value_conv,$unit) = $self->_normalize_value($value);
    my $label = $self->_get_name(cleanup => 1);
    if ( ($self->base || $self->base_mbean) && !$script_mode) {
        # Calc relative value 
        my $base_value = $self->_base_value($self->base,$responses,$requests);
        my $rel_value = sprintf "%2.2f",$base_value ? (int((($value / $base_value) * 10000) + 0.5) / 100) : 0;
                
        # Performance data. Convert to absolute values before
        if ($self->_include_perf_data) {
            if ($self->perfdata && $self->perfdata =~ /^\s*\%\s*/) {
                $np->add_perfdata(label => $label, value => $rel_value, uom => '%',
                                  critical => $self->critical, warning => $self->warning);
            } else {
                my ($critical,$warning) = $self->_convert_relative_to_absolute($base_value,$self->critical,$self->warning);
                $np->add_perfdata(label => $label,value => $value,
                                  critical => $critical,warning => $warning,
                                  min => 0,max => $base_value,
                                  $self->unit ? (uom => $self->unit) : ());
            }
        }
        # Do the real check.
        my ($code,$mode) = $self->_check_threshold($rel_value);
        # For Multichecks, we remember the label of a currently failed check
        $self->update_error_stats($opts->{error_stat},$code) unless $code == OK;
        my ($base_conv,$base_unit) = $self->_normalize_value($base_value);
        $msg_handler->add_message($code,$self->_exit_message(code => $code,mode => $mode,rel_value => $rel_value, 
                                                    value => $value_conv, unit => $unit, base => $base_conv, 
                                                    base_unit => $base_unit, prefix => $opts->{prefix}));            
    } else {
        # Performance data
        $value = $self->_sanitize_value($value);
        if ($self->_include_perf_data) {
            $np->add_perfdata(label => $label,
                              critical => $self->critical, warning => $self->warning, 
                              value => $value,$self->unit ? (uom => $self->unit) : ());
        }
        
        # Do the real check.
        my ($code,$mode) = $self->_check_threshold($value);
        $self->update_error_stats($opts->{error_stat},$code) unless $code == OK;
        $msg_handler->add_message($code,$self->_exit_message(code => $code,mode => $mode,value => $value_conv, unit => $unit,
                                                             prefix => $opts->{prefix}));                    
    }
    return @extra_requests;
}

sub _include_perf_data {
    my $self = shift;
    # No perf dara for string based checks by default
    my $default = not defined($self->string);
    # If 'PerfData' is set explicitely to false/off/no/0 then no perfdata
    # will be included
    return $default unless defined($self->perfdata);
    return $self->perfdata !~ /^\s*(false|off|no|0)\s*$/i;
}

sub update_error_stats {
    my $self = shift;
    my $error_stat = shift || return;
    my $code = shift;

    my $label = $self->{config}->{name} || $self->{config}->{key};
    if ($label) {
        my $arr = $error_stat->{$code} || [];
        push @$arr,$label;
        $error_stat->{$code} = $arr;
    }
}

# Extract a single value, which is different, if the request was a pattern read
# request
sub _extract_value {
    my $self = shift;
    my $req = shift;
    my $resp = shift;
    if ($req->get('type') eq READ && $req->is_mbean_pattern) {
        return $self->_extract_value_from_pattern_request($resp->value);
    } else {
        return $self->_null_safe_value($resp->value);
    }
}

sub _null_safe_value {
    my $self = shift;
    my $value = shift;
    if (defined($value)) {
        if (JSON::is_bool($value)) {
            return "$value";
        } elsif (ref($value) && $self->string) {
            # We can deal with complex values withing string comparison
            if (ref($value) eq "ARRAY") {
                return join ",",@{$value};
            } else {
                return Dumper($value);
            }
        } else {
            return $value;
        }
    } else {
        # Our null value
        return defined($self->null) ? $self->null : "null";
    }
}

sub _extract_value_from_pattern_request {
    my $self = shift;
    my $val = shift;
    my $np = $self->{np};
    $self->_die("Pattern request does not result in a proper return format: " . Dumper($val))
      if (ref($val) ne "HASH");
    $self->_die("More than one MBean found for a pattern request: " . Dumper([keys %$val])) if keys %$val != 1;
    my $attr_val = (values(%$val))[0];
    $self->_die("Invalid response for pattern match: " . Dumper($attr_val)) unless ref($attr_val) eq "HASH";
    $self->_die("Only a single attribute can be used. Given: " . Dumper([keys %$attr_val])) if keys %$attr_val != 1;
    return $self->_null_safe_value((values(%$attr_val))[0]);
}

sub _delta_value {
    my ($self,$req,$resp,$delta) = @_;
    
    my $history = $resp->history;
    if (!$history) {
        # No delta on the first run
        return undef;
    } else {
        my $hist_val;
        if ($req->is_mbean_pattern) {
            $hist_val = $self->_extract_value_from_pattern_request($history);
        } else {
            $hist_val = $history;
        }
        if (!@$hist_val) {
            # Can happen in some scenarios when requesting the first history entry,
            # we return 0 here
            return 0;
        }
        my $old_value = $hist_val->[0]->{value};
        my $old_time = $hist_val->[0]->{timestamp};
        my $value = $self->_extract_value($req,$resp);
        if ($delta) {
            # Time average
            my $time_delta = $resp->timestamp - $old_time;
            return (($value - $old_value) / ($time_delta ? $time_delta : 1)) * $delta;
        } else {
            return $value - $old_value;
        }
    }    
}

sub _switch_on_history {
    my ($self,$orig_request,$target) = @_;
    my ($mbean,$operation) = ("jolokia:type=Config","setHistoryEntriesForAttribute");
    # Set history to 1 (we need only the last)
    return new JMX::Jmx4Perl::Request
      (EXEC,$mbean,$operation,
       $orig_request->get("mbean"),$orig_request->get("attribute"),$orig_request->get("path"),
       $target ? $target->{url} : undef,1,{target => undef});
}


sub _base_value {
    my $self = shift;
    my $np = $self->{np};
    my $name = shift;
    my $responses = shift;
    my $requests = shift;

    if (looks_like_number($name)) {
        # It looks like a number, so we suppose its the base value itself
        return $name;
    }
    my $resp = shift @{$responses};
    my $req = shift @{$requests};
    $self->_die($resp->{error}) if $resp->{error};
    #print Dumper($req,$resp);
    return $self->_extract_value($req,$resp);
}

# Normalize value if a unit-of-measurement is given.

# Units and how to convert from one level to the next
my @UNITS = ([ qw(ns us ms s m h d) ],[qw(B KB MB GB TB)]);
my %UNITS = 
  (
   ns => 1,   
   us => 10**3,
   ms => 10**3,
   s => 10**3,
   m => 60,
   h => 60,
   d => 24,

   B => 1,
   KB => 2**10,
   MB => 2**10,
   GB => 2**10,
   TB => 2**10   
  );

sub _normalize_value {
    my $self = shift;
    my $value = shift;
    my $unit = shift || $self->unit || return ($value,undef);
    
    for my $units (@UNITS) {
        for my $i (0 .. $#{$units}) {
            next unless $units->[$i] eq $unit;
            my $ret = $value;
            my $u = $unit;
            if (abs($ret) > 1) {
                # Go up the scale ...
                return ($value,$unit) if $i == $#{$units};
                for my $j ($i+1 .. $#{$units}) {
                    if (abs($ret / $UNITS{$units->[$j]}) >= 1) {                    
                        $ret /= $UNITS{$units->[$j]};
                        $u = $units->[$j];
                    } else {
                        return ($ret,$u);
                    }
                }             
            } else {
                # Go down the scale ...
                return ($value,$unit) if $i == 0;
                for my $j (reverse(0 .. $i-1)) {
                    if ($ret < 1) {     
                        $ret *= $UNITS{$units->[$j+1]};
                        $u = $units->[$j];
                    } else {
                        return ($ret,$u);
                    }
                }
                
            }
            return ($ret,$u);
        }
    }
    die "Unknown unit '$unit' for value $value";
}

sub _sanitize_value {
    my ($self,$value) = @_;
    if ($value =~ /\de/i) {
        $value = sprintf("%f", $value);
    }
    return $value;
}

sub _verify_response {
    my ($self,$req,$resp) = @_;
    my $np = $self->{np};
    if ($resp->is_error) {
        my $extra = "";
        if ($np->opts->{verbose}) {
            my $stacktrace = $resp->stacktrace;
            $extra = ref($stacktrace) eq "ARRAY" ? join "\n",@$stacktrace : $stacktrace if $stacktrace;
        }
        $self->_die("Error: ".$resp->status." ".$resp->error_text.$extra);
    }
    
    if (!$req->is_mbean_pattern && (ref($resp->value) && !$self->string) && !JSON::is_bool($resp->value)) { 
        $self->_die("Response value is a " . ref($resp->value) .
                        ", not a plain value. Did you forget a --path parameter ?". " Value: " . 
                        Dumper($resp->value));
    }
}

sub _get_name { 
    my $self = shift;
    my $args = { @_ };
    my $name = $args->{name};
    if (!$name) {
        if ($self->name) {
            $name = $self->name;
        } else {
            # Default name, tried to be generated from various parts
            if ($self->alias) {
                $name = "[".$self->alias.($self->path ? "," . $self->path : "") ."]";
            } else {
                my $val = $self->value;
                if ($val) {
                    $name = "[" . $val . "]";
                } else {
                    my $a_or_o = $self->attribute || $self->operation || "";
                    my $p = $self->path ? "," . $self->path : "";
                    $name = "[" . $self->mbean . "," . $a_or_o . $p . "]";
                }
            }
        }
    }
    if ($args->{cleanup}) {
        # Enable this when '=' gets forbidden
        $name =~ s/=/#/g;
    }
    # Prepare label for usage with Nagios::Plugin, which will blindly 
    # add quotes if a space is contained in the label.
    # We are doing the escape of quotes ourself here
    $name =~ s/'/''/g;
    return $name;
}

sub _prepare_read_args {
    my $self = shift;
    my $np = $self->{np};
    my $jmx = shift;

    if ($self->alias) {
        my @req_args = $jmx->resolve_alias($self->alias);
        $self->_die("Cannot resolve attribute alias ",$self->alias()) unless @req_args > 0;
        if ($self->path) {
            @req_args == 2 ? $req_args[2] = $self->path : $req_args[2] .= "/" . $self->path;
        }
        return @req_args;
    } elsif ($self->value) {
        return $self->_split_attr_spec($self->value);
    } else {
        return ($self->mbean,$self->attribute,$self->path);
    }
}

sub _prepare_exec_args {
    my $self = shift;
    my $np = $self->{np};
    my $jmx = shift;

    #print Dumper($self->{config});
    # Merge CLI arguments and arguments from the configuration,
    # with CLI arguments taking precedence
    my @cli_args = @_;
    my $config_args = $self->{config}->{argument};
    
    $config_args = [ $config_args ] if defined($config_args) && ref($config_args) ne "ARRAY";
    my @args = ();
    if ($config_args) {
        my @c_args = (@$config_args);
        while (@cli_args || @c_args) {
            my $cli_arg = shift @cli_args;
            my $config_arg = shift @c_args;
            push @args, defined($cli_arg) ? $cli_arg : $config_arg;
        }
    } else {
        @args = @cli_args;
    }
    if ($self->alias) {
        my @req_args = $jmx->resolve_alias($self->alias);
        $self->_die("Cannot resolve operation alias ",$self->alias()) unless @req_args >= 2;
        return (@req_args,@args);
    } else {
        return ($self->mbean,$self->operation,@args);
    }
}

sub _split_attr_spec {
    my $self = shift;
    my $name = shift;
    my @ret = ();
    # Text:ParseWords is used for split on "/" taking into account
    # quoting and escaping
    for my $p (parse_line("/",1,$name)) {
        # We need to 'unescape' things ourselves
        # since we want quotes to remain in the names (using '0'
        # above would kill those quotes, too). 
        $p =~ s|\\(.)|$1|sg;
        push @ret,$p;
    }    
    return (shift(@ret),shift(@ret),@ret ? join("/",@ret) : undef);
}

sub _check_threshold {
    my $self = shift;
    my $value = shift;
    my $np = $self->{np};
    my $numeric_check;
    if ($self->numeric || $self->string) {
        $numeric_check = $self->numeric ? 1 : 0;
    } else {
        $numeric_check = looks_like_number($value);
    }
    if ($numeric_check) {
        # Verify numeric thresholds
        my @ths = 
          (
           defined($self->critical) ? (critical => $self->critical) : (),
           defined($self->warning) ? (warning => $self->warning) : ()
          );  
        #print Dumper({check => $value,@ths});
        return (@ths ? $np->check_threshold(check => $value,@ths) : OK,"numeric");    
    } else {
        return
          ($self->_check_string_threshold($value,CRITICAL,$self->critical) ||
            $self->_check_string_threshold($value,WARNING,$self->warning) ||
              OK,
           $value =~ /^true|false$/i ? "boolean" : "string");
    }
}

sub _check_string_threshold {
    my $self = shift;
    my ($value,$level,$check_value) = @_;
    return undef unless $check_value;
    if ($check_value =~ m|^\s*qr(.)(.*)\1\s*$|) {
        return $value =~ m/$2/ ? $level : undef;
    }
    if ($check_value =~ s/^\!//) {
        return $value ne $check_value ? $level : undef; 
    } else {
        return $value eq $check_value ? $level : undef;
    }    
}

sub _convert_relative_to_absolute { 
    my $self = shift;
    my ($base_value,@to_convert) = @_;
    my @ret = ();
    for my $v (@to_convert) {
        $v =~ s|([\d\.]+)|($1 / 100) * $base_value|eg if $v;
        push @ret,$v;
    }
    return @ret;
}

# Prepare an exit message depending on the result of
# the check itself. Quite evolved, you can overwrite this always via '--label'.
sub _exit_message {
    my $self = shift;
    my $args = { @_ };       
    # Custom label has precedence
    return $self->_format_label($self->label,$args) if $self->label;

    my $code = $args->{code};
    my $mode = $args->{mode};
    if ($code == CRITICAL || $code == WARNING) {
        if ($self->base || $self->base_mbean) {
            return $self->_format_label
              ('%n : Threshold \'%t\' failed for value %.2r% ('. &_placeholder($args,"v") .' %u / '.
               &_placeholder($args,"b") . ' %u)',$args);
        } else {
            if ($mode ne "numeric") {
                return $self->_format_label('%n : \'%v\' matches threshold \'%t\'',$args);
            } else {
                return $self->_format_label
                  ('%n : Threshold \'%t\' failed for value '.&_placeholder($args,"v").' %u',$args);
            }
        }
    } else {
        if ($self->base || $self->base_mbean) {
            return $self->_format_label('%n : In range %.2r% ('. &_placeholder($args,"v") .' %u / '.
                                        &_placeholder($args,"b") . ' %w)',$args);
        } else {
            if ($mode ne "numeric") {
                return $self->_format_label('%n : \'%v\' as expected',$args);
            } else {
                return $self->_format_label('%n : Value '.&_placeholder($args,"v").' %u in range',$args);
            }
        }

    }
}

sub _placeholder {
    my ($args,$c) = @_;
    my $val;
    if ($c eq "v") {
        $val = $args->{value};
    } else {
        $val = $args->{base};
    }
    return ($val =~ /\./ ? "%.2" : "%") . $c;
}

sub _format_label {
    my $self = shift;
    my $label = shift;
    my $args = shift;
    # %r : relative value (as percent)
    # %q : relative value (as floating point)
    # %v : value
    # %f : value as floating point
    # %u : unit
    # %b : base value
    # %w : base unit
    # %t : threshold failed ("" for OK or UNKNOWN)
    # %c : code ("OK", "WARNING", "CRITICAL", "UNKNOWN")
    # %d : delta
    # 
    my @parts = split /(\%[\w\.\-]*\w)/,$label;
    my $ret = "";
    foreach my $p (@parts) {
        if ($p =~ /^(\%[\w\.\-]*)(\w)$/) {
            my ($format,$what) = ($1,$2);
            if ($what eq "r" || $what eq "q") {
                my $val = $args->{rel_value} || 0;
                $val = $what eq "r" ? $val : $val / 100; 
                $ret .= sprintf $format . "f",$val;
            } elsif ($what eq "b") {
                $ret .= sprintf $format . &_format_char($args->{base}),($args->{base} || 0);
            } elsif ($what eq "u" || $what eq "w") {
                $ret .= sprintf $format . "s",($what eq "u" ? $args->{unit} : $args->{base_unit}) || "";
                $ret =~ s/\s$//;
            } elsif ($what eq "f") {
                $ret .= sprintf $format . "f",$args->{value};
            } elsif ($what eq "v") {
                $ret .= &_format_value($format,$args->{mode},$args->{value});
            } elsif ($what eq "t") {
                my $code = $args->{code};
                my $val = $code == CRITICAL ? $self->critical : ($code == WARNING ? $self->warning : "");
                $ret .= sprintf $format . "s",defined($val) ? $val : "";
            } elsif ($what eq "c") {
                $ret .= sprintf $format . "s",$STATUS_TEXT{$args->{code}};
            } elsif ($what eq "n") {
                $ret .= sprintf $format . "s",$self->_get_name();
            } elsif ($what eq "d") {
                $ret .= sprintf $format . "d",$self->delta;
            } elsif ($what eq "y") {
                $ret .= &_format_value($format,$args->{mode},$self->warning);
            } elsif ($what eq "z") {
                $ret .= &_format_value($format,$args->{mode},$self->critical);                
            }
        } else {
            $ret .= $p;
        }
    }
    if ($args->{prefix}) {
        my $prefix = $args->{prefix};
        $prefix =~ s/\%c/$STATUS_TEXT{$args->{code}}/g;
        return  $prefix . $ret;
    } else {
        return $ret;
    }
}

sub _format_value {
    my $format = shift;
    my $mode = shift;
    my $value = shift;
    if ($mode ne "numeric") {
        return sprintf $format . "s",$value;
    } else {
        return sprintf $format . &_format_char($value),$value;
    }    
}
sub _format_char {
    my $val = shift;
    $val =~ /\./ ? "f" : "d";
}

sub _die {
    my $self = shift;
    my $msg = join("",@_);
    die $msg,"\n";
}

my $CHECK_CONFIG_KEYS = {
                         "critical" => "critical",
                         "warning" => "warning",
                         "mbean" => "mbean",
                         "attribute" => "attribute",
                         "operation" => "operation",
                         "alias" => "alias",        
                         "path" => "path",
                         "delta" => "delta",
                         "name" => "name",
                         "base" => "base",
                         "base-mbean" => "basembean",
                         "base-attribute" => "baseattribute",
                         "base-path" => "basepath",
                         "unit" => "unit",
                         "numeric" => "numeric",
                         "string" => "string",
                         "label" => "label",
                         "perfdata" => "perfdata",
                         "value" => "value",
                         "null" => "null",
                         "script" => "script"
                        };


# Get the proper configuration values

sub AUTOLOAD {
    my $self = shift;
    my $np = $self->{np};
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    $name =~ s/_/-/g;

    if ($CHECK_CONFIG_KEYS->{$name}) {
        return $np->opts->{$name} if defined($np->opts->{$name});
        if ($self->{config}) {
            return $self->{config}->{$CHECK_CONFIG_KEYS->{$name}};
        } else {
            return undef;
        }
    } else {
        $self->_die("No config attribute \"" . $name . "\" known");
    }
}


# To keep autoload happy
sub DESTROY {

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

=head1 AUTHOR

roland@cpan.org

=cut

1;
