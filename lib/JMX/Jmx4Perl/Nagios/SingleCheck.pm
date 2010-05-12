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
our $AUTOLOAD;

=head1 NAME

JMX::Jmx4Perl::Nagios::SingleCheck - A single nagios check

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

sub get_requests {
    my $self = shift;
    my $jmx = shift;
    my $args = shift;

    my $request;
    my $do_read = $self->attribute || $self->value;
    if ($self->alias) {
        my $alias = JMX::Jmx4Perl::Alias->by_name($self->alias);
        die "No alias '",$self->alias," known" unless $alias;
        $do_read = $alias->type eq "attribute";
    }
    my @requests = ();
    if ($do_read) {
        push @requests,JMX::Jmx4Perl::Request->new(READ,$self->_prepare_read_args($jmx));
    } else {
        push @requests,JMX::Jmx4Perl::Request->new(EXEC,$self->_prepare_exec_args($jmx,@$args));
    }

    if ($self->base) {
        if (!looks_like_number($self->base)) {
            # It looks like a number, so we will use the base literally
            my $alias = JMX::Jmx4Perl::Alias->by_name($self->base);
            if ($alias) {
                push @requests,new JMX::Jmx4Perl::Request(READ,$jmx->resolve_alias($self->base));
            } else {
                my ($mbean,$attr,$path) = $self->_split_attr_spec($self->base);
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

sub extract_responses {
    my $self = shift;    
    my $responses = shift;
    my $requests = shift;
    my $target = shift;
    my $np = $self->{np};

    # Get response/request pair
    my $resp = shift @{$responses};
    my $request = shift @{$requests};

    my @extra_requests = ();
    $self->_verify_response($resp);
    my $value = $resp->value;
    # Delta handling
    my $delta = $self->delta;
    if (defined($delta)) {
        $value = $self->_delta_value($request,$resp,$delta);
        unless (defined($value)) {
            push @extra_requests,$self->_switch_on_history($request,$target);
            $value = 0;
        }
    }
    
    # Normalize value 
    my ($value_conv,$unit) = $self->_normalize_value($value);
    # Common args
    my $label = "'".$self->_get_name(cleanup => 1)."'";
    if ($self->base) {
        # Calc relative value 
        my $base_value = $self->_base_value($self->base,$responses,$requests);
        my $rel_value = sprintf "%2.2f",(int((($value / $base_value) * 10000) + 0.5) / 100) ;
                
        # Performance data. Convert to absolute values before
        my ($critical,$warning) = $self->_convert_relative_to_absolute($base_value,$self->critical,$self->warning);
        $np->add_perfdata(label => $label,value => $value,
                          critical => $critical,warning => $warning,
                          min => 0,max => $base_value,
                          $self->unit ? (uom => $self->unit) : ());
        
        # Do the real check.
        my ($code,$mode) = $self->_check_threshhold($rel_value);
        my ($base_conv,$base_unit) = $self->_normalize_value($base_value);
        $np->add_message($code,$self->_exit_message(code => $code,mode => $mode,rel_value => $rel_value, 
                                                           value => $value_conv, unit => $unit,base => $base_conv, 
                                                           base_unit => $base_unit));            
    } else {
        # Performance data
        $np->add_perfdata(label => $label,
                          critical => $self->critical, warning => $self->warning,
                          value => $value,$self->unit ? (uom => $self->unit) : ());
        
        # Do the real check.
        my ($code,$mode) = $self->_check_threshhold($value);
        $np->add_message($code,$self->_exit_message(code => $code,mode => $mode,value => $value_conv, unit => $unit));                    
    }
    return @extra_requests;
}

sub _delta_value {
    my ($self,$request,$resp,$delta) = @_;
    
    my $history = $resp->history;
    if (!$history) {
        # No delta on the first run
        return undef;
    } else {
        my $old_value = $history->[0]->{value};
        my $old_time = $history->[0]->{timestamp};
        if ($delta) {
            return (($resp->value - $old_value) / ($resp->timestamp - $old_time)) * $delta;
        } else {
            return $resp->value - $old_value;
        }
    }    
}

sub _switch_on_history {
    my ($self,$orig_request,$target) = @_;
    my ($mbean,$operation) = ("jmx4perl:type=Config","setHistoryEntriesForAttribute");
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
        # It looks like a number, so we suppose its  the base value itself
        return $name;
    }
    my $resp = shift @{$responses};
    # Clear request
    shift @{$requests};
    die "Base value is not a plain value but ",Dumper($resp->value) if ref($resp->value);
    return $resp->value;
}

# Normalize value if a unit-of-measurement is given.

# Units and how to convert from one level to the next
my @UNITS = ([ qw(us ms s m h d) ],[qw(B KB MB GB TB)]);
my %UNITS = 
  (
   us => 10**3,
   ms => 10**3,
   s => 1,
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
            if ($ret > 1) {
                # Go up the scale ...
                return ($value,$unit) if $i == $#{$units};
                for my $j ($i+1 .. $#{$units}) {
                    if ($ret / $UNITS{$units->[$j]} >= 1) {                    
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
                    if ($ret <= 1) {     
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



sub _verify_response {
    my ($self,$resp) = @_;
    my $np = $self->{np};
    if ($resp->is_error) {
        $np->nagios_die("Error: ".$resp->status." ".$resp->error_text."\nStacktrace:\n".$resp->stacktrace);
    }
    if (!defined($resp->value)) {
        $np->nagios_die("JMX Request " . $self->_get_name() . 
                        " returned a null value which can't be used yet. " . 
                        "Please let me know, whether you need such check for a null value");
    }
    if (ref($resp->value)) { 
        $np->nagios_die("Response value is a ".ref($resp->value).
                        ", not a plain value. Did you forget a --path parameter ?","Value: " . 
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
            # Default name
            $name = $self->alias ? 
          "[".$self->alias.($self->path ? "," . $self->path : "") ."]" : 
            $self->value ? 
              "[" . $self->value . "]" :
            "[".$self->mbean.",".$self->attribute.($self->path ? "," . $self->path : "")."]";
        }
    }
    if ($args->{cleanup}) {
        # Enable this when '=' gets forbidden
        $name =~ s/=/#/g;
    }
    return $name;
}

sub _prepare_read_args {
    my $self = shift;
    my $np = $self->{np};
    my $jmx = shift;

    if ($self->alias) {
        my @req_args = $jmx->resolve_alias($self->alias);
        $np->nagios_die("Cannot resolve attribute alias ",$self->alias()) unless @req_args > 0;
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

    my @args = @_;

    if ($self->alias) {
        my @req_args = $jmx->resolve_alias($self->alias);
        $np->nagios_die("Cannot resolve operation alias ",$self->alias()) unless @req_args >= 2;
        return (@req_args,@args);
    } else {
        return ($self->mbean,$self->operation,@args);
    }
}

sub _split_attr_spec {
    my $self = shift;
    my $name = shift;

    # TODO: Implement escaping
    return split m|/|,$name;
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
                         "unit" => "unit",
                         "numeric" => "numeric",
                         "string" => "string",
                         "label" => "label",
                         # New:
                         "value" => "value"
                        };


# Get the proper configuration values
sub AUTOLOAD {
    my $self = shift;
    my $np = $self->{np};
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    $name =~ s/-/_/g;

    if ($CHECK_CONFIG_KEYS->{$name}) {
        return $np->opts->{$name} if defined($np->opts->{$name});
        if ($self->{config}) {
            return $self->{config}->{$CHECK_CONFIG_KEYS->{$name}};
        } else {
            return undef;
        }
    } else {
        $np->nagios_die("No config attribute \"" . $name . "\" known");
    }
}

sub _check_threshhold {
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
           $self->critical ? (critical => $self->critical) : (),
           $self->warning ? (warning => $self->warning) : ()
          );            
        return ($np->check_threshold(check => $value,@ths),"numeric");    
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
        if ($self->base) {
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
        if ($self->base) {
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
    # %r : relative value
    # %v : value
    # %u : unit
    # %b : base value
    # %t : threshold failed ("" for OK or UNKNOWN)
    # %c : code ("OK", "WARNING", "CRITICAL", "UNKNOWN")

    my @parts = split /(\%[\w\.\-]*\w)/,$label;
    my $ret = "";
    foreach my $p (@parts) {
        if ($p =~ /^(\%[\w\.\-]*)(\w)$/) {
            my ($format,$what) = ($1,$2);
            if ($what eq "r") {
                $ret .= sprintf $format . "f",($args->{rel_value} || 0);
            } elsif ($what eq "b") {
                $ret .= sprintf $format . &_format_char($args->{base}),($args->{base} || 0);
            } elsif ($what eq "u" || $what eq "w") {
                $ret .= sprintf $format . "s",($what eq "u" ? $args->{unit} : $args->{base_unit}) || "";
                $ret =~ s/\s$//;
            } elsif ($what eq "v") {
                if ($args->{mode} ne "numeric") {
                    $ret .= sprintf $format . "s",$args->{value};
                } else {
                    $ret .= sprintf $format . &_format_char($args->{value}),$args->{value};
                }
            } elsif ($what eq "t") {
                my $code = $args->{code};
                $ret .= sprintf $format . "s",$code == CRITICAL ? $self->critical : ($code == WARNING ? $self->warning : "");
            } elsif ($what eq "c") {
                $ret .= sprintf $format . "s",$STATUS_TEXT{$args->{code}};
            } elsif ($what eq "n") {
                $ret .= sprintf $format . "s",$self->_get_name();
            }
        } else {
            $ret .= $p;
        }
    }
    return $ret;
}

sub _format_char {
    my $val = shift;
    $val =~ /\./ ? "f" : "d";
}


# To keep autoload happy
sub DESTROY {

}

1;
