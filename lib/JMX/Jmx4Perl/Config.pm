#!/usr/bin/perl
package JMX::Jmx4Perl::Config;
use Data::Dumper;

my $HAS_CONFIG_GENERAL;

BEGIN {
    eval { 
        require "Config/General.pm";
    };
    $HAS_CONFIG_GENERAL = $@ ? 0 : 1;
}

=head1 NAME 

JMX::Jmx4Perl::Config - Configuration file support for Jmx4Perl

=head1 SYNOPSIS

=over

=item Configuration file format

  # ================================================================
  # Sample configuration for jmx4perl

  # localhost is the name how this config could accessed
  <Server localhost>
    # Options for JMX::Jmx4Perl->new, case is irrelevant
    Url  = http://localhost:8080/j4p
    User = roland
    Password = test
    Product = JBoss
    
    # HTTP proxy for accessing the agent
    <Proxy>
      Url = http://proxy:8001
      User = proxyuser
      Password = ppaasswwdd
    </Proxy>
    # Target for running j4p in proxy mode
    <Target>
      Url       service:jmx:iiop://....
      User      weblogic
      Password  weblogic
    </Target>       
  </Server>

=item Usage

  my $config = new JMX::Jmx4Perl::Config($config_file);

=back


=head1 DESCRIPTION


=head1 METHODS

=over

=item $cfg = JMX::Jmx4Perl::Config->new($file_or_hash)

Create a new configuration object with the given file name. If no file name 
is given the configuration F<~/.j4p> is tried. If the file does not 
exist, C<server_config_exists> will alway return C<false> and
C<get_server_config> will always return C<undef>

If a hash is given as argument, this hash is used to extract the server 
information.

=cut 

sub new { 
    my $class = shift;
    my $file_or_hash = shift;
    my $self = {};
    my $config = undef;;
    if (!ref($file_or_hash)) {
        my $file = $file_or_hash ? $file_or_hash : $ENV{HOME} . "/.j4p";
        if (-e $file) {
            if ($HAS_CONFIG_GENERAL) {
                local $SIG{__WARN__} = sub {};  # Keep Config::General silent
                                                # when including things twice
                $config = {
                           new Config::General(-ConfigFile => $file,-LowerCaseNames => 1,
                                               -UseApacheInclude => 1,-IncludeRelative => 1, -IncludeAgain => 0,
                                               -IncludeGlob => 1, -IncludeDirectories => 1,  -CComments => 0)->getall
                          };
            } else {
                warn "Configuration file $file found, but Config::General is not installed.\n" . 
                  "Please install Config::General, for the moment we are ignoring the content of $file\n\n";
            }
        }
    } elsif (ref($file_or_hash) eq "HASH") {
        $config = $file_or_hash;
    } else {
        die "Invalid argument ",$file_or_hash;
    }
    if ($config) {
        $self->{server_config} = &_extract_servers($config);
        $self->{servers} = [ values %{$self->{server_config}} ];
        map { $self->{$_} = $config->{$_ } } grep { $_ ne "server" } keys %$config;
        #print Dumper($self);
    }

    bless $self,(ref($class) || $class);
    return $self;   
}

=item $exists = $config->server_config_exists($name)

Check whether a configuration entry for the server with name $name
exist.

=cut

sub server_config_exists {
    my $self = shift;
    my $name = shift || die "No server name given to reference to get config for";
    my $cfg = $self->get_server_config($name);
    return defined($cfg) ? 1 : 0;
}

=item $server_config = $config->get_server_config($name)

Get the configuration for the given server or C<undef> 
if no such configuration exist.

=cut

sub get_server_config {
    my $self = shift;
    my $name = shift || die "No server name given to reference to get config for";
    return $self->{server_config} ? $self->{server_config}->{$name} : undef;
}

=item $servers = $config->get_servers 

Get an arrayref to all configured servers or an empty arrayref.

=cut

sub get_servers {
    my $self = shift;
    return $self->{servers} || [];
}

sub _extract_servers {
    my $config = shift;
    my $servers = $config->{server};
    my $ret = {};
    return $ret unless $servers;
    if (ref($servers) eq "ARRAY") {
        # Its a list of servers using old style (no named section, but with
        # embedded 'name'
        for my $s (@$servers) {
            die "No name given for server config " . Dumper($s) . "\n" unless $s->{name};
            $ret->{$s->{name}} = $s;
        }
        return $ret;
    } elsif (ref($servers) eq "HASH") {
        for my $name (keys %$servers) {
            if (ref($servers->{$name}) eq "HASH") {
                # A single, 'named' server section
                $servers->{$name}->{name} = $name;
            } else {
                # It's a single server entry with 'old' style naming (e.g. no
                # named section but a 'Name' property
                my $ret = {};
                my $name = $servers->{name} || die "Missing name for server section ",Dumper($servers);
                $ret->{$name} = $servers;
                return $ret;
            }
        }
        return $servers;
    } else {
        die "Invalid configuration type ",ref($servers),"\n";        
    }
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
