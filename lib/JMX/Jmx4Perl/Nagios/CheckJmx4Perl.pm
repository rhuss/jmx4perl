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
our $AUTOLOAD;

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
documentation on how to use this check. This module is probably I<not> of 
general interest and serves only the purpose described above.

=cut

sub new {
    my $class = shift;
    my $self = { 
                np => &_create_nagios_plugin(),
               };
    bless $self,(ref($class) || $class);
    $self->_verify_and_initialize();
    return $self;
}


sub execute {
    my $self = shift;
    my $np = $self->{np};
    eval {

        # Request
        my @optional = ();
        my $target = $self->target ? {
                                      url => $self->target,
                                      $self->target_user ? (user => $self->target_user) : (),
                                      $self->target_password ? (password => $self->target_password) : (),                      
                                     } : {};
        my $jmx = JMX::Jmx4Perl->new(mode => "agent", url => $self->url, user => $self->user, 
                                     password => $self->password,
                                     product => $self->product, proxy => $self->proxy,
                                     $self->target ? (target => $target) : ());

        my @requests;
        for my $check (@{$self->{checks}}) {
            push @requests,@{$check->get_requests($jmx,\@ARGV)};            
        }
        my $responses = $self->_send_requests($jmx,@requests);
        my @extra_requests = ();
        for my $check (@{$self->{checks}}) {
            # A check can consume more than one response
            my @r = $check->extract_responses($responses,\@requests,$target);
            push @extra_requests,@r if @r;
        }
        
        # Send extra requests
        if (@extra_requests) {
            $self->_send_requests($jmx,@extra_requests);
        }
        $np->nagios_exit($np->check_messages);
    };
    if ($@) {
        # p1.pl, the executing script of the embedded nagios perl interpreter
        # uses this tag to catch an exit code of a plugin. We rethrow this
        # exception if we detect this pattern.
        if ($@ !~ /^ExitTrap:/) {
            $np->nagios_die("Error: $@");
        } else {
            die $@;
        }
    }
}

sub _send_requests {
    my ($self,$jmx,@requests) = @_;
    my $o = $self->{opts};

    my $start_time;    
    if ($o->verbose) {
        # TODO: Print summary of request (GET vs POST)
        # print "Request URL: ",$jmx->request_url($request),"\n";
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

sub _verify_and_initialize { 
    my $self = shift;
    my $np = $self->{np};
    my $o = $np->opts;
    
    $self->{opts} = $self->{np}->opts;

    # Fetch configuration
    my $config = $self->_get_config($o->config);
    
    # Now, if a specific check is given, extract it, too.
    my $check_configs = $self->_extract_checks($config,$o->check);

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
          || $np->nagios_die("No server configuration for " . $o->server . " found");
    } 

    # Sanity checks
    $np->nagios_die("No Server URL given") unless $self->url;

    for my $check (@{$self->{checks}}) {
        my $name = $check->name ? " [Check: " . $check->name . "]" : "";
        $np->nagios_die("An MBean name and a attribute/operation must be provided" . $name)
          if ((!$check->mbean || (!$check->attribute && !$check->operation)) && !$check->alias && !$check->value);
        
        $np->nagios_die("At least a critical or warning threshold must be given" . $name) 
          if ((!defined($check->critical) && !defined($check->warning)));    
    }
}

# Extract one or more check configurations
sub _extract_checks {
    my $self = shift;
    my $config = shift;
    my $check = shift;

    my $np = $self->{np};

    if ($check) {
        $np->nagios_die("No configuration given") unless $config;
        $np->nagios_die("No checks defined in configuration") unless $config->{check};
        
        my $check_config = $config->{check}->{$check};
        unless ($check_config) {
            # Try it as a multi check
            my $multi_checks = $config->{multicheck};
            if ($multi_checks)  {
                my $m_check = $multi_checks->{$check};
                if ($m_check && $m_check->{check}) {
                    # Resolve all check;
                    my $c_names = ref($m_check->{check}) eq "ARRAY" ? $m_check->{check} : [ $m_check->{check} ];
                    for my $c_name (@$c_names) {
                        my $check = $config->{check}->{$c_name} ||
                          $np->nagios_die("Unknown check '" . $c_name . "' for multi check " . $check);
                        push @{$check_config},$check;
                    }
                }
            }
        } else {
            $check_config = ref($check_config) eq "ARRAY" ? $check_config : [ $check_config ];
        }
        $np->nagios_die("No check configuration with name " . $check . " found") unless ($check_config);
        return $check_config;
    } else {
        return undef;
    }
}

sub _get_config {
    my $self = shift;
    my $path = shift;
    my $np = $self->{np};
    $np->nagios_die("No configuration file " . $path . " found")
      if ($path && ! -e $path);
    return new JMX::Jmx4Perl::Config($path);
}

sub _server_config {
    return shift->{server_config};
}

sub _check_config {
    return shift->{check_config};
}

# =========================================================================================== 
  
# =========================================================================================== 

# =========================================================================================== 

sub _create_nagios_plugin {
    my $args = shift;
    my $np = Nagios::Plugin->
      new(
          usage => 
          "Usage: %s -u <agent-url> -m <mbean> -a <attribute> -c <threshold critical> -w <threshold warning> -n <label>\n" . 
          "                      [--alias <alias>] [--base <alias/number/mbean>] [--delta <time-base>] [--product <product>]\n".
          "                      [--user <user>] [--password <password>] [--proxy <proxy>]\n" .
          "                      [--target <target-url>] [--target-user <user>] [--target-password <password>]\n" .
          "                      [-v] [--help]",
          version => $JMX::Jmx4Perl::VERSION,
          url => "http://www.consol.com/opensource/nagios/",
          plugin => "check_jmx4perl",
          blurb => "This plugin checks for JMX attribute values on a remote Java application server",
          extra => "\n\nYou need to deploy j4p.war on the target application server or as an intermediate proxy.\n" .
          "Please refer to the documentation for JMX::Jmx4Perl for further details"
         );
    $np->shortname(undef);
    $np->add_arg(
                 spec => "url|u=s",
                 help => "URL to agent web application (e.g. http://server:8080/j4p/)",
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
                 spec => "unit=s",
                 help => "Unit of measurement of the data retreived. Recognized values are [B|KB|MN|GB|TB] for memory values and [us|ms|s|m|h|d] for time values"
                );
    $np->add_arg(
                 spec => "label|l=s",
                 help => "Label to be used for printing out the result of the check. Placeholders can be used."
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
    $np->getopts();
    return $np;
}

# Access to configuration informations
# Known config options (key: cmd line arguments, values: keys in config);
my $SERVER_CONFIG_KEYS = {
                          "url" => "url",
                          "target" => "target",
                          "user" => "user",
                          "password" => "password",
                          "product" => "product",
                          "target_user" => "target/user",
                          "target_password" => "target/password",
                          "target_url" => "target/url",
                          "proxy" => "proxy",
                          "proxy_url" => "proxy/url",
                          "proxy_user" => "proxy/user",
                          "proxy_password" => "proxy/password"
                         };

sub AUTOLOAD {
    my $self = shift;
    my $np = $self->{np};
    my $name = $AUTOLOAD;
    $name =~ s/.*://;   # strip fully-qualified portion
    $name =~ s/-/_/g;

    if ($SERVER_CONFIG_KEYS->{$name}) {        
        return $np->opts->{$name} if $np->opts->{$name};
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
        $np->nagios_die("No config attribute \"" . $name . "\" known");
    }
}

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
