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
use JMX::Jmx4Perl::Agent::UserAgent;

@ISA = qw(JMX::Jmx4Perl);

=head1 NAME 

JMX::Jmx4Perl::Agent - JSON-HTTP based acess to a remote JMX Agent

=head1 SYNOPSIS

 my $agent = new JMX::Jmx4Perl(mode=>"agent", url => "http://jeeserver/jjagent");
 my $answer = $agent->get_attribute("java.lang:type=Memory","HeapMemoryUsage");
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
                   'name' => 'java.lang:type=Memory'
                  },
 };

=head1 DESCRIPTION

This module is not used directly, but via L<JMX::Jmx4Perl>, which acts as a
proxy to this module. You can think of L<JMX::Jmx4Perl> as the interface which
is backed up by this module. Other implementations (e.g. 

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

=back 

=cut

# Init called by parent package within 'new' for specific initialization. See
# above for the parameters recognized
sub init {
    my $self = shift;
        
    croak "No URL provided" unless $self->cfg('url');
    my $ua = JMX::Jmx4Perl::Agent::UserAgent->new();
    $ua->jjagent_config($self->{cfg});
    $ua->timeout($self->cfg-('timeout')) if $self->cfg('timeout');
    $ua->agent("JMX::Jmx4Perl::Agent $VERSION");
    $ua->env_proxy;
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

=item $resp = $agent->request($request)

Implementation of the JMX request as specified in L<JMX::Jmx4Perl>. It uses a
L<HTTP:Request> sent via an L<LWP::UserAgent> for posting a JSON representation
of the request. This method shouldn't be called directly but via
L<JMX::Jmx4Perl>->request(). 

=cut

sub request {
    my $self = shift;
    my $jmx_request = shift;
 
    my $ua = $self->{ua};
    my $url = $self->request_url($jmx_request);
    my $req = HTTP::Request->new(GET => $url);
    my $resp = $ua->request($req);
    my $ret = from_json($resp->content());
    if ($resp->is_error && !$ret->{status}) {
        my $error = "Error while fetching $url :\n" . $resp->status_line . "\n";
        my $content = $resp->content;
        if ($content) {
            chomp $content;
            $error .=  $content if $content ne $resp->status_line;
        }
        croak $error;
    }
    

    return JMX::Jmx4Perl::Response->new($ret->{status},$jmx_request,$ret->{value},$ret->{error},$ret->{stacktrace});
}

=item $url = $agent->request_url($request)

Generate the URL for accessing the java agent based on a given request. 

=cut 

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
    } elsif ($type eq LIST_MBEANS) {
        $url .= $request->get("path") if $request->get("path");
    }
    return $url;
}

=back

=cut 

# ===================================================================
# Specialized UserAgent for passing in credentials:

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

=head1 AUTHOR

roland@cpan.org

=cut

1;
