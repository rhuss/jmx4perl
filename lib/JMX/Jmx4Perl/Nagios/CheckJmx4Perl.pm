package JMX::Jmx4Perl::Nagios::CheckJmx4Perl;

use strict;
use warnings;
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Response;
use JMX::Jmx4Perl::Alias;
use Data::Dumper;
use Nagios::Plugin;
use Time::HiRes qw(gettimeofday tv_interval);
use Carp;
use Scalar::Util qw(looks_like_number);
use URI::Escape;

=head1 NAME

JMX::Jmx4Perl::CheckJmx4Perl - Module for encapsulating the functionality of
L<check_jmx4perl> 

=head1 SYNOPSIS

  # One line in check_jmx4perl to rule them all
  JMX::Jmx4Perl::CheckJmx4Perl->new()->execute();

=head1 DESCRIPTION

The purpose of this module is to encapsulate a single run of L<check_jmx4perl> 
in a perl object. This allows for C<check_jmx4perl> to run within the embedded
Nagios perl interpreter (ePN) wihout interfering with other, potential
concurrent, runs of this check. Please refer to L<check_jmx4perl> for
documentation on how to use this check. This module is probbaly I<not> of 
general interest and serves only the purpose described above.

=cut

sub new {
    my $class = shift;
    my $self = { 
                np => &_create_nagios_plugin(),
               };
    $self->{opts} = $self->{np}->opts;
    bless $self,(ref($class) || $class);
    $self->_verify_and_initialize();
    return $self;
}


sub execute {
    my $self = shift;
    my $np = $self->{np};
    eval {
        my $o = $self->{opts};

        # Request
        my $jmx = JMX::Jmx4Perl->new(mode => "agent", url => $o->url, user => $o->user, 
                                     password => $o->password,
                                     product => $o->product, proxy => $o->proxy);
        my $request;
        my $do_read = $o->get("attribute");
        if ($o->get("alias")) {
            my $alias = JMX::Jmx4Perl::Alias->by_name($o->get("alias"));
            die "No alias '",$o->get("alias")," known" unless $alias;
            $do_read = $alias->type eq "attribute";
        }
        if ($do_read) {
            $request = JMX::Jmx4Perl::Request->new(READ,$self->_prepare_read_args($jmx));
        } else {
            $request = JMX::Jmx4Perl::Request->new(EXEC,$self->_prepare_exec_args($jmx,@ARGV));
        }
        
        my $resp = $self->_send_request($jmx,$request);
        my $value = $resp->value;
        # Delta handling
        my $delta = $o->get("delta");
        if (defined($delta)) {
            $value = $self->_delta_value($jmx,$request,$resp,$delta);
        }
        
        # Base value handling
        if ($o->get("base")) {
            my $base_value = $self->_base_value($jmx,$o->get("base"));
            # Normalize to 2 digits preficison
            $value = sprintf "%2.2f",(int((($value / $base_value) * 10000) + 0.5) / 100) ;
        };
        
        # Add Nagios perfdata
        $np->add_perfdata(label => $self->_get_name(),value => $value,
                          critical => $o->critical, warning => $o->warning, 
                          $o->base ? (uom => '%') : ());

        my $code = $self->_check_threshhold($value);

        return $np->nagios_exit($code,$self->_get_name(). " : Threshold " . 
                         ($code == CRITICAL ? $o->critical : $o->warning) . 
                         " failed for value $value") if $code != OK;
        return $np->nagios_exit(OK,$self->_get_name() . " : $value in range");
    };
    if ($@) {
        # p1.pl, the executing script of the embedded nagios perl interpreted
        # uses this tag to catch an exit code of a plugin. We rethrow this
        # exception if we detect this pattern.
        if ($@ !~ /^ExitTrap:/) {
            $np->nagios_die("Error: $@");
        } else {
            die $@;
        }
    }
}

sub _get_name { 
    my $self = shift;
    my $o = $self->{opts};
    if ($o->name) {
        return $o->name;
    } else {
        # Default name
        return $o->alias ? 
          "[".$o->alias.($o->path ? "," . $o->path : "") ."]" : 
            "[".$o->mbean.",".$o->attribute.($o->path ? "," . $o->path : "")."]";
    }
}

sub _send_request {
    my ($self,$jmx,$request) = @_;
    my $o = $self->{opts};

    my $start_time;    
    if ($o->verbose) {
        print "Request URL: ",$jmx->request_url($request),"\n";
        if ($o->user) {
            print "Remote User: ",$o->user,"\n";
        }
        $start_time = [gettimeofday];
    }

    my $resp = $jmx->request($request);
    $self->_verify_response($resp);

    if ($o->verbose) {
        print "Result fetched in ",tv_interval($start_time) * 1000," ms:\n";
        print Dumper($resp);
    }

    return $resp;
}

sub _switch_on_history {
    my ($self,$jmx,$orig_request) = @_;
    my ($mbean,$operation) = $jmx->resolve_alias(JMX4PERL_HISTORY_MAX_ATTRIBUTE);
    # Set history to 1 (we need only the last
    my $switch_request = new JMX::Jmx4Perl::Request(EXEC,$mbean,$operation,
                                     $orig_request->get("mbean"),$orig_request->get("attribute"),$orig_request->get("path"),1);
    my $resp = $jmx->request($switch_request);
    if ($resp->is_error) {
        $self->{np}->nagios_die("Error: ".$resp->status." ".$resp->error_text."\nStacktrace:\n".$resp->stacktrace);
    }

    # Refetch value to initialize the history
    $resp = $jmx->request($orig_request);
    $self->_verify_response($resp);
}

sub _prepare_read_args {
    my $self = shift;
    my $np = $self->{np};
    my $jmx = shift;
    my $o = $np->opts;

    if ($o->alias) {
        my @req_args = $jmx->resolve_alias($o->alias);
        $np->nagios_die("Cannot resolve attribute alias ",$o->alias()) unless @req_args > 0;
        if ($o->path) {
            @req_args == 2 ? $req_args[2] = $o->path : $req_args[2] .= "/" . $o->path;
        }
        return @req_args;
    } else {
        return ($o->mbean,$o->attribute,$o->path);
    }
}

sub _prepare_exec_args {
    my $self = shift;
    my $np = $self->{np};
    my $jmx = shift;
    my @args = @_;
    my $o = $np->opts;

    if ($o->alias) {
        my @req_args = $jmx->resolve_alias($o->alias);
        $np->nagios_die("Cannot resolve operation alias ",$o->alias()) unless @req_args >= 2;
        return (@req_args,@args);
    } else {
        return ($o->mbean,$o->operation,@args);
    }
}

sub _verify_response {
    my ($self,$resp) = @_;
    my $np = $self->{np};
    if ($resp->is_error) {
        $np->nagios_die("Error: ".$resp->status." ".$resp->error_text."\nStacktrace:\n".$resp->stacktrace);
    }
    if (!defined($resp->value)) {
        $np->nagios_die("JMX Request " . $self->_get_name() . " returned a null value which can't be used yet. " . 
                        "Please let me know, whether you need such check for a null value");
    }
    if (ref($resp->value)) { 
        $np->nagios_die("Response value is a ".ref($resp->value).
                        ", not a plain value. Did you forget a --path parameter ?","Value: " . Dumper($resp->value));
    }
}

sub _verify_and_initialize { 
    my $self = shift;
    my $np = $self->{np};
    my $o = $np->opts;

    $np->nagios_die("An MBean name and a attribute must be provided")
      if ((!$o->mbean && !$o->attribute) && !$o->alias);
    
    $np->nagios_die("At least a critical or warning threshold must be given") 
      if ((!defined($o->critical) && !defined($o->warning)));
    
}

sub _delta_value {
    my ($self,$jmx,$request,$resp,$delta) = @_;
    
    my $history = $resp->history;
    if (!$history) {
        $self->_switch_on_history($jmx,$request);           
        # No delta on the first run
        return 0;
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

sub _base_value {
    my $self = shift;
    my $np = $self->{np};
    my $jmx = shift;
    my $name = shift;

    if (looks_like_number($name)) {
        # It looks like a number, so we suppose its  the base value itself
        return $name;
    }

    my $alias = JMX::Jmx4Perl::Alias->by_name($name);
    my $request;
    if ($alias) {
        $request = new JMX::Jmx4Perl::Request(READ,$jmx->resolve_alias($name));
    } else {
        my ($mbean,$attr,$path) = split m|/|,$name;
        die "No MBean given in base name ",$name unless $mbean;
        die "No Attribute given in base name ",$name unless $attr;
        
        $mbean = URI::Escape::uri_unescape($mbean);
        $attr = URI::Escape::uri_unescape($attr);
        $path = URI::Escape::uri_unescape($path) if $path;
        $request = new JMX::Jmx4Perl::Request(READ,$mbean,$attr,$path);
    }

    my $resp = $self->_send_request($jmx,$request);
    die "Base value is not a plain value but ",Dumper($resp->value) if ref($resp->value);
    return $resp->value;
}

sub _check_threshhold {
    my $self = shift;
    my $value = shift;
    my $np = $self->{np};
    my $o = $self->{opts};
    my $numeric_check;
    if ($o->numeric || $o->string) {
        $numeric_check = $o->numeric ? 1 : 0;
    } else {
        $numeric_check = looks_like_number($value);
    }
    if ($numeric_check) {
        # Verify numeric thresholds
        my @ths = 
          (
           $o->critical ? (critical => $o->critical) : (),
           $o->warning ? (warning => $o->warning) : ()
          );            
        return $np->check_threshold(check => $value,@ths);    
    } else {
        return
          $self->_check_string_threshold($value,CRITICAL,$o->critical) ||
            $self->_check_string_threshold($value,WARNING,$o->warning) ||
              OK;
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

# =========================================================================================== 

sub _create_nagios_plugin {
    my $args = shift;
    my $np = Nagios::Plugin->
      new(
          usage => 
          "Usage: %s -u <agent-url> -m <mbean> -a <attribute> -c <threshold critical> -w <threshold warning> -n <label>\n" . 
          "                      [--alias <alias>] [--base <alias/number/mbean>] [--delta <time-base>] [--product <product>]\n".
          "                      [--user <user>] [--password <password>] [--proxy <proxy>]\n" .
          "                      [-v] [--help]",
          version => $JMX::Jmx4Perl::VERSION,
          url => "http://www.consol.com/opensource/nagios/",
          plugin => "check_jmx4perl",
          blurb => "This plugin checks for JMX attribute values on a remote Java application server",
          extra => "\n\nYou need to deploy j4p.war on the target application server.\n" .
          "Please refer to the documentation for JMX::Jmx4Perl for further details"
         );
    $np->shortname(undef);
    $np->add_arg(
                 spec => "url|u=s",
                 help => "URL to agent web application (e.g. http://server:8080/j4p/)",
                 required => 1
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
                 spec => "base|base-alias|b=s",
                 help => "Base alias name, which when given, interprets critical and warning values as relative in the range 0 .. 100%",
                );
    $np->add_arg(
                 spec => "delta|d:s",
                 help => "Switches on incremental mode. Optional argument are seconds used for normalizing. ",
                );
    $np->add_arg(
                 spec => "path|p=s",
                 help => "Inner path for extracting a single value from a complex attribute or return value (e.g. \"used\")",
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
    $np->getopts();
    return $np;
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
