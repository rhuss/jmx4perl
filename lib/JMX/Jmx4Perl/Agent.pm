#!/usr/bin/perl
package JMX::Jmx4Perl::Agent;

use JSON;
use URI::Escape qw(uri_escape_utf8);
use HTTP::Request;
use Carp;
use strict;
use vars qw($VERSION $DEBUG);
use base qw(JMX::Jmx4Perl);
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Response;
use JMX::Jmx4Perl::Agent::UserAgent;
use Data::Dumper;


$VERSION = $JMX::Jmx4Perl::VERSION;

=head1 NAME 

JMX::Jmx4Perl::Agent - JSON-HTTP based acess to a remote JMX agent

=head1 SYNOPSIS

 my $agent = new JMX::Jmx4Perl(mode=>"agent", url => "http://jeeserver/j4p");
 my $answer = $agent->get_attribute("java.lang:type=Memory","HeapMemoryUsage");
 print Dumper($answer);

 {
   request => {
     attribute => "HeapMemoryUsage",
     name => "java.lang:type=Memory"
   },
   status => 200,
   value => {
     committed => 18292736,
     init => 0,
     max => 532742144,
     used => 15348352
   }
 }

=head1 DESCRIPTION

This module is not used directly, but via L<JMX::Jmx4Perl>, which acts as a
proxy to this module. You can think of L<JMX::Jmx4Perl> as the interface which
is backed up by this module. Other implementations (e.g. 

=head1 METHODS

=over 4 

=item $jjagent = JMX::Jmx4Perl::Agent->new(url => $url, ....)

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

=item proxy => { url => <http_proxy> }

Optional proxy to use

=item proxy_user => <user>, proxy_password => <password>

Credentials to use for accessing the proxy

=item target

Add a target which is used for any request served by this object if not already
a target is present in the request. This way you can setup the default target
configuration if you are using the agent servlet as a proxy, e.g.

  ... target => { url => "service:jmx:...", user => "...", password => "..." }


=back 

=cut

# HTTP Parameters to be used for transmitting the request
my @PARAMS = ("maxDepth","maxCollectionSize","maxObjects","ignoreErrors");

# Regexp for detecting invalid chars which can not be used securily in pathinfos
my $INVALID_PATH_CHARS = qr/%(5C|3F|3B|2F)/i; # \ ? ; /

# Init called by parent package within 'new' for specific initialization. See
# above for the parameters recognized
sub init {
    my $self = shift;
        
    croak "No URL provided" unless $self->cfg('url');
    my $ua = JMX::Jmx4Perl::Agent::UserAgent->new();
    $ua->jjagent_config($self->{cfg});
    #push @{ $ua->requests_redirectable }, 'POST';
    $ua->timeout($self->cfg('timeout')) if $self->cfg('timeout');
    $ua->agent("JMX::Jmx4Perl::Agent $VERSION");
    # $ua->env_proxy;
    my $proxy = $self->cfg('proxy');
    if ($proxy) {
        my $url = ref($proxy) eq "HASH" ? $proxy->{url} : $proxy;
        if (ref($url) eq "HASH") {
            for my $k (keys %$url) {
                $ua->proxy($k,$url->{$k});
            }
        } else {
            if ($self->cfg('url') =~ m|^(.*?)://|) {
                # Set proxy for URL scheme used
                $ua->proxy($1,$url);
            } else {
                $ua->proxy('http',$proxy);
            }
        }
    }
    $self->{ua} = $ua;
    return $self;
}

=item $url = $agent->url()

Get the base URL for connecting to the agent. You cannot change the URL via this
method, it is immutable for a given agent.

=cut

sub url { 
    my $self = shift;
    return $self->cfg('url');
}

=item $resp = $agent->request($request)

Implementation of the JMX request as specified in L<JMX::Jmx4Perl>. It uses a
L<HTTP::Request> sent via an L<LWP::UserAgent> for posting a JSON representation
of the request. This method shouldn't be called directly but via
L<JMX::Jmx4Perl>->request(). 

=cut

sub request {
    my $self = shift;
    my @jmx_requests = $self->cfg('target') ? $self->_update_targets(@_) : @_;
    my $ua = $self->{ua};
    my $http_req = $self->_to_http_request(@jmx_requests);
    print "Requesting ",$http_req->uri,"\n" if $self->{cfg}->{verbose};
    #print Dumper($http_req);
    my $http_resp = $ua->request($http_req);
    my $json_resp = {};
    #print "Response: ",Dumper($http_resp) if $self->{cfg}->{verbose};
    eval {
        $json_resp = from_json($http_resp->content());
    };
    my $json_error = $@;
    if ($http_resp->is_error) {
        return JMX::Jmx4Perl::Response->new
          ( 
           status => $http_resp->code,
           value => $json_error ? $http_resp->content : $json_resp,
           error => $json_error ? $self->_prepare_http_error_text($http_resp) : 
           ref($json_resp) eq "ARRAY" ? join "\n",  map { $_->{error} } grep { $_->{error} } @$json_resp : $json_resp->{error},
           stacktrace => ref($json_resp) eq "ARRAY" ? $self->_extract_stacktraces($json_resp) : $json_resp->{stacktrace},
           request => @jmx_requests == 1 ? $jmx_requests[0] : \@jmx_requests
          );        
    } elsif ($json_error) {
        # If is not an HTTP-Error and deserialization fails, then we
        # probably got a wrong URL and get delivered some server side
        # document (with HTTP code 200)
        my $e = $json_error;
        $e =~ s/(.*)at .*?line.*$/$1/;
        return JMX::Jmx4Perl::Response->new
          ( 
           status => 400,
           error => 
           "Error while deserializing JSON answer (Wrong URL ?)\n" . $e,
           value => $http_resp->content
          );        
    }
    
    my @responses = ($self->_from_http_response($json_resp,@jmx_requests));
    if (!wantarray && scalar(@responses) == 1) {
        return shift @responses;
    } else {
        return @responses;
    }
}


# Create an HTTP-Request for calling the server
sub _to_http_request {
    my $self = shift;
    my @reqs = @_;
    if ($self->_use_GET_request(\@reqs)) {
        # Old, rest-style
        my $url = $self->request_url($reqs[0]);
        return HTTP::Request->new(GET => $url);
    } else {
        my $url = $self->cfg('url') || croak "No URL provided";
        $url .= "/" unless $url =~ m|/$|;
        my $request = HTTP::Request->new(POST => $url);
        my $content = to_json(@reqs > 1 ? \@reqs : $reqs[0], { convert_blessed => 1 });
        #print Dumper($reqs[0],$content);
        $request->content($content);
        return $request;
    }    
}

sub _use_GET_request {
    my $self = shift;
    my $reqs = shift;
    if (@$reqs == 1) {
        my $req = $reqs->[0];
        # For proxy configs and explicite set POST request, get is not used
        return !defined($req->get("target")) && $req->method ne "POST" ;
    } else {
        return 0;
    }
}

# Create one or more response objects for a given request
sub _from_http_response {
    my $self = shift;
    my $json_resp = shift;
    my @reqs = @_;
    if (ref($json_resp) eq "HASH") {
        return JMX::Jmx4Perl::Response->new(%{$json_resp},request => $reqs[0]);
    } elsif (ref($json_resp) eq "ARRAY") {
        die "Internal: Number of request and responses doesn't match (",scalar(@reqs)," vs. ",scalar(@$json_resp) 
          unless scalar(@reqs) == scalar(@$json_resp);
        
        my @ret = ();        
        for (my $i=0;$i<@reqs;$i++) {
            die "Internal: Not a hash --> ",$json_resp->[$i] unless ref($json_resp->[$i]) eq "HASH";
            my $response = JMX::Jmx4Perl::Response->new(%{$json_resp->[$i]},request => $reqs[$i]);
            push @ret,$response;
        }
        return @ret;
    } else {
        die "Internal: Not a hash nor an array but ",ref($json_resp) ? ref($json_resp) : $json_resp;
    }
}

# Update targets if not set in request.
sub _update_targets {
    my $self = shift;
    my @requests = @_;
    my $target = $self->_clone_target;
    for my $req (@requests) {
        $req->{target} = $target unless exists($req->{target});
        # A request with existing but undefined target removes
        # any default
        delete $req->{target} unless defined($req->{target});
    }
    return @requests;
}

sub _clone_target {
    my $self = shift;
    die "Internal: No target set" unless $self->cfg('target');
    my $target = { %{$self->cfg('target')} };
    if ($target->{env}) {
        $target->{env} = { %{$target->{env}}};
    }
    return $target;
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
        for my $arg (@{$request->get("arguments")}) {
            # Array refs are sticked together via ","
            my $a = ref($arg) eq "ARRAY" ? join ",",@{$arg} : $arg;
            $req .= "/" . $self->_escape($self->_null_escape($a));
        }
    } elsif ($type eq SEARCH) {
        # Nothing further to append.
    }
    # Squeeze multiple slashes
    $req =~ s|/{2,}|/|g;
    #print "R: $req\n";

    if ($req =~ $INVALID_PATH_CHARS || $request->{use_query}) {
        $req = "?p=$req";
    }
    my @params;
    for my $k (@PARAMS) {
        push @params, $k . "=" . $request->get($k)
          if $request->get($k);
    }
    $req .= ($req =~ /\?/ ? "&" : "?") . join("&",@params) if @params;
    return $url . $req;
}

# =============================================================================

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
    $input =~ s|^/-|/^|; # as well as the first slash

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

# Prepare some readable error text
sub _prepare_http_error_text {
    my $self = shift;
    my $http_resp = shift;   
    my $content = $http_resp->content;
    my $error = "Error while fetching ".$http_resp->request->uri." :\n\n" . $http_resp->status_line . "\n";
    chomp $content;
    if ($content && $content ne $http_resp->status_line) {
        my $error .=  "=" x length($http_resp->status_line) . "\n\n";
        my $short = substr($content,0,600);
        $error .=  $short . (length($short) < length($content) ? "\n\n... [truncated] ...\n\n" : "") . "\n" 
    }
    return $error;
}

# Extract all stacktraces stored in the given array ref of json responses
sub _extract_stacktraces {
    my $self = shift;
    my $json_resp = shift;
    my @ret = ();
    for my $j (@$json_resp) {
        push @ret,$j->{stacktrace} if $j->{stacktrace};
    }
    return @ret ? (scalar(@ret) == 1 ? $ret[0] : \@ret) : undef;
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
