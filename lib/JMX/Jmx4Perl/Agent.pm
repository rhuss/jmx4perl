#!/usr/bin/perl
package JMX::Jmx4Perl::Agent;

use JSON;
use URI::Escape qw(uri_escape_utf8);
use HTTP::Request;
use Carp;
use strict;
use vars qw($VERSION $DEBUG @ISA);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Response;
use JMX::Jmx4Perl::Agent::UserAgent;
use Data::Dumper;

@ISA = qw(JMX::Jmx4Perl);

$VERSION = $JMX::Jmx4Perl::VERSION;

=head1 NAME 

JMX::Jmx4Perl::Agent - JSON-HTTP based acess to a remote JMX agent

=head1 SYNOPSIS

 my $agent = new JMX::Jmx4Perl(mode=>"agent", url => "http://jeeserver/j4p");
 my $answer = $agent->get_attribute("java.lang:type=Memory","HeapMemoryUsage");
 print Dumper($answer);

 $VAR1 = {
    'value' => {
                'committed' => 18292736,
                'used' => 15348352,
                'max' => 532742144,
                'init' => 0
               },
    'status' => 200,
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
name of the war archive. Example: C<http://localhost:8080/j4p> for a drop
in deployment of the agent in a standard Tomcat's webapp directory.

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

# HTTP Parameters to be used for transmitting the request
my %PARAM_MAPPING = (
                     "max_depth" => "maxDepth",
                     "max_list_size" => "maxCollectionSize",
                     "max_objects" => "maxObjects"
                    );


# Init called by parent package within 'new' for specific initialization. See
# above for the parameters recognized
sub init {
    my $self = shift;
        
    croak "No URL provided" unless $self->cfg('url');
    my $ua = JMX::Jmx4Perl::Agent::UserAgent->new();
    $ua->jjagent_config($self->{cfg});
    $ua->timeout($self->cfg-('timeout')) if $self->cfg('timeout');
    $ua->agent("JMX::Jmx4Perl::Agent $VERSION");
    # $ua->env_proxy;
    my $proxy = $self->cfg('proxy');
    if ($proxy) {
        if (ref($proxy) eq "HASH") {
            for my $k (keys %$proxy) {
                $ua->proxy($k,$proxy->{$k});
            }
        } else {
            if ($self->cfg('url') =~ m|^(.*?)://|) {
                # Set proxy for URL scheme used
                $ua->proxy($1,$proxy);
            } else {
                $ua->proxy('http',$proxy);
            }
        }
    }
    $self->{ua} = $ua;

    return $self;
}

=item $resp = $agent->request($request)

Implementation of the JMX request as specified in L<JMX::Jmx4Perl>. It uses a
L<HTTP::Request> sent via an L<LWP::UserAgent> for posting a JSON representation
of the request. This method shouldn't be called directly but via
L<JMX::Jmx4Perl>->request(). 

=cut

sub request {
    my $self = shift;
    my $jmx_request = shift;
 
    my $ua = $self->{ua};
    my $url = $self->request_url($jmx_request);
    print "Requesting $url\n" if $self->{cfg}->{verbose};
#    print $url;
    my $req = HTTP::Request->new(GET => $url);
    my $resp = $ua->request($req);
    my $ret = {};
    eval {
        $ret = from_json($resp->content());
    };
    if ($@) {
        if (!$resp->is_error) {
            return JMX::Jmx4Perl::Response->new
              ( 
               code => 400,
               request => $jmx_request,
               content => $resp->content,
               error => "Error while deserializing JSON answer (probably wrong URL)"
              );
        }
    }
    if ($resp->is_error && !$ret->{status}) {
        my $error = "Error while fetching $url :\n\n" . $resp->status_line . "\n";
        my $content = $resp->content;
        if ($content) {
            chomp $content;
            $error .=  "=" x length($resp->status_line) . "\n\n";
            my $short = substr($content,0,500);
            $error .=  $short . (length($short) < length($content) ? "\n\n.......\n\n" : "") . "\n" if $content ne $resp->status_line;
        }
        die $error;
    };
    return JMX::Jmx4Perl::Response->new(%{$ret},request => $jmx_request);
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
    my $req = $type . "/";
    $req .= $self->_escape($request->get("mbean"));
    if ($type eq READ) {
        $req .= "/" . $self->_escape($request->get("attribute"));
        $req .= $self->_extract_path($request->get("path"));
    } elsif ($type eq WRITE) {
        $req .= "/" . $self->_escape($request->get("attribute"));
        $req .= "/" . $self->_escape($self->_null_escape($request->get("value")));
        $req .= $self->_extract_path($request->get("path"));
    } elsif ($type eq LIST) {
        $req .= $self->_extract_path($request->get("path"));
    } elsif ($type eq EXEC) {
        $req .= "/" . $self->_escape($request->get("operation"));
        $req .= "/" . $self->_escape($self->_null_escape($_)) for @{$request->get("args")};
    } elsif ($type eq SEARCH) {
        # Nothing further to append.
    }
    # Squeeze multiple slashes
    $req =~ s|/{2,}|/|g;
    my @params;
    for my $k (keys %PARAM_MAPPING) {
        push @params, $PARAM_MAPPING{$k} . "=" . $request->get($k)
          if $request->get($k);
    }
    $req .= "?" . join("&",@params) if @params;
    return $url . $req;
}


# Extract path by splitting it up at "/", escape the parts, and join them again
sub _extract_path {
    my $self = shift;
    my $path = shift;
    return "" unless $path;
    return "/" . join("/",map { $self->_escape($_) } split(m|/|,$path));
}

# Escape '/' which are used as separators by using "/-/" as an escape sequence
# URI Encoding doesn't work for slashes, since some Appserver tend to mangle
# them up with pathinfo-slashes to early in the request cycle.
# E.g. Tomcat/Jboss croaks with a "HTTP/1.x 400 Invalid URI: noSlash" if one
# uses an encoded slash somewhere in the path-info part.
sub _escape {
    my $self = shift;
    my $input = shift;
    my $opts = { @_ };
    $input =~ s|(/+)|"/" . ('-' x length($1)) . "/"|eg;
    $input =~ s|-/$|+/|; # The last slash needs a special escape
    return URI::Escape::uri_escape_utf8($input,"^A-Za-z0-9\-_.!~*'()/");   # Added "/" to
                                                              # default
                                                              # set. See L<URI>
}

# Escape empty and undef values so that they can be detangled 
# on the server side
sub _null_escape {
    my $self = shift;
    my $value = shift;
    if (!defined($value)) {
        return "[null]";
    } elsif (! length($value)) {
        return "\"\"";
    } else {
        return $value;
    }
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
