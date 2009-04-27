#!/usr/bin/perl
package JMX::Jmx4Perl::Agent;

use JSON;
use LWP::UserAgent;
use HTTP::Request;
use Carp;
use strict;
use vars qw($VERSION $DEBUG @ISA);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;

@ISA = qw(JMX::Jmx4Perl);

=head1 NAME 

JMX::Jmx4Perl::Agent - Agent for JSON-HTTP Acess to a remote JMX Agent

=head1 SYNOPSIS

 my $agent = new JMX::Jmx4Perl::Agent(url => "http://jeeserver/jjagent");
 my $answer = $agent->fetch_attribute("java.lang:type=Memory","HeapMemoryUsage");
 print Dumper($answer);

 $VAR1 = {
    'value' => {
                'committed' => 18292736,
                'used' => 15348352,
                'max' => 532742144,
                'init' => 0
               },
    'request' => {
                   'attribute' => 'HeapMemoryUsage',
                   'name' => {
                              'keys' => {
                                         'type' => 'Memory'
                                        },
                              'domain' => 'java.lang',
                              'canonical' => 'java.lang:type=Memory'
                             }
                  },
 };

=head1 DESCRIPTION


=head1 METHODS

=over 4 

=item $jjagent = JMX::Jmx4Perl::Agent->new(url => $url)

Creates a new local agent for a given url 

=over

=item url => <url to JEE server>

The url where the agent is deployed. This is a mandatory parameter. The url
must include the context within the server, which is typically based on the
name of the war archive. Example: http://localhost:8080/jjagent for a drop in
deployment of the agent in a standard Tomcat's webapp directory. 

=item timeout => <timeout>

Timeout in seconds after which a request should be stopped if it not suceeds
within this time. This parameter is given through directly to the underlying
L<LWP::UserAgent> 

=item user => <user>, password => <password>

Credentials to use for the HTTP request

=item proxy => { http => '<http_proxy>', https => '<https_proxy>', ...  }
=item proxy => <http_proxy>

Optional proxy to use

=item proxy_user => <user>, proxy_password => <password>

Credentials to use for accessing the proxy

=cut

sub init {
    my $self = shift;
        
    croak "No URL provided" unless $self->cfg('url');
    my $ua = JMX::Jmx4Perl::Agent::UserAgent->new();
    $ua->jjagent_config($self->{cfg});
    $ua->timeout($self->cfg-('timeout')) if $self->cfg('timeout');
    $ua->agent("JMX::Jmx4Perl::Agent $VERSION");
    my $proxy = $self->cfg('proxy');
    if ($proxy) {
        if (ref($proxy) eq "HASH") {
            for my $k (keys %$proxy) {
                $ua->proxy($k,$proxy->{$k});
            }
        } else {
            $ua->proxy('http',$proxy);
        }
    }
    $self->{ua} = $ua;

    return $self;
}

sub request {
    my $self = shift;
    my $jmx_request = shift;
 
    my $ua = $self->{ua};
    my $url = $self->request_url($jmx_request);
    my $req = HTTP::Request->new(GET => $url);
    my $resp = $ua->request($req);
    if ($resp->is_error) {
        my $error = "Error while fetching $url :\n" . $resp->status_line . "\n";
        my $content = $resp->content;
        if ($content) {
            chomp $content;
            $error .=  $content if $content ne $resp->status_line;
        }
        croak $error;
    }
    
    my $ret = from_json($resp->content());
    return JMX::Jmx4Perl::Response->new($jmx_request,$ret->{value});
}

sub request_url {
    my $self = shift;
    my $request = shift;
    my $url = $self->cfg('url') || croak "No base url given in configuration";
    $url .= "/" unless $url =~ m|/$|;
    my $type = $request->get("type");
    $url .= $type . "/";
    $url .= $request->get("mbean") . "/";
    if ($type eq READ_ATTRIBUTE || $type eq WRITE_ATTRIBUTE) {
        $url .= $request->get("attribute");
        $url .= "/" . $request->get("path") if $request->get("path");
        if ($type eq WRITE_ATTRIBUTE) {
            $url .= "/" . $request->get("value");
        }
    }
    return $url;
}


# ===================================================================
# Specialized UserAgent for passing in credentials:

package JMX::Jmx4Perl::Agent::UserAgent;
use vars qw(@ISA);
@ISA = qw(LWP::UserAgent);

sub jjagent_config { 
    my $self = shift;
    $self->{jjagent_config} = shift;
}

sub get_basic_credentials { 
    my ($self, $realm, $uri, $isproxy) = @_;

    my $cfg = $self->{jjagent_config} || {};
    my $user = $isproxy ? $cfg->{proxy_user} : $cfg->{user};
    my $password = $isproxy ? $cfg->{proxy_password} : $cfg->{password};

    if ($user && $password) {
        return ($user,$password);
    } else {
        return (undef,undef);
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

=AUTHOR

roland@cpan.org

=cut

1;
