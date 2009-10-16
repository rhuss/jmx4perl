#!/usr/bin/perl
package JMX::Jmx4Perl::Config;
use Config::General;

=head1 NAME 

JMX::Jmx4Perl - Access to JMX via Perl

=head1 SYNOPSIS

Simple:

   use strict;
   use JMX::Jmx4Perl;
   use JMX::Jmx4Perl::Alias;   # Import certains aliases for MBeans

   print "Memory Used: ",
          JMX::Jmx4Perl
              ->new(url => "http://localhost:8080/j4p")
              ->get_attribute(MEMORY_HEAP_USED);

Advanced:

   use strict;
   use JMX::Jmx4Perl;
   use JMX::Jmx4Perl::Request;   # Type constants are exported here
   
   my $jmx = new JMX::Jmx4Perl(url => "http://localhost:8080/j4p",
                               product => "jboss");
   my $request = new JMX::Jmx4Perl::Request({type => READ,
                                             mbean => "java.lang:type=Memory",
                                             attribute => "HeapMemoryUsage",
                                             path => "used"});
   my $response = $jmx->request($request);
   print "Memory used: ",$response->value(),"\n";

   # Get general server information
   print "Server Info: ",$jmx->info();

=head1 DESCRIPTION


=head1 METHODS

=over

=item $cfg = JMX::Jmx4Perl::Config->new($file)

Create a new configuration object with the given file name. If no file name 
is given the configuration F<~/.j4p> is tried. If the file does not 
exist, C<server_config_exists> will alway return C<false> and
C<get_server_config> will always return C<undef>

=cut 

sub new { 
    my $class = shift;
    my $file = shift;
    $file = $ENV{HOME} . "/.j4p" unless $file;
    my $self = {};
    if (-e $file) {
        $self->{config} = 
          new Config::General(-ConfigFile => $file,  
                              -LowerCaseNames => 1)->getall;
    } else {
        $self->{config} = {};
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
    my $servers = $self->_get_configured_servers();
    for my $s (@$servers) {
        return $s if lc($s->{name}) eq $name;
    }
    return undef;    
}

sub _get_configured_servers {
    my $self = shift;
    my $servers = $self->{config}->{servers};
    return [] unless $servers;
    if (ref($servers) eq "HASH") {
        return [ map { $servers->{$_}->{name} = $_ && $servers->{$_} } keys %$servers ];
    } else if (!ref($servers)) {
        return [ $servers ];
    }
    return $servers;
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
