#!/usr/bin/perl

use It;

use Test::More (tests => 14);
use LWP::UserAgent;
use Data::Dumper;
use strict;

my $url = $ENV{JMX4PERL_GATEWAY} || $ARGV[0];
$url .= "/" unless $url =~ /\/$/;
my $origin = "http://localhost:8080";
my $ua = new LWP::UserAgent();

if ($ENV{JMX4PERL_USER}) {
    my $netloc = $url;
    $netloc =~ s|^.*/([^:]+:\d+).*$|$1|;
    $ua->credentials($netloc,"jolokia",$ENV{JMX4PERL_USER},$ENV{JMX4PERL_PASSWORD});
}

$ua->default_headers()->header("Origin" => $origin);

# Test for CORS functionality. This is done without Jmx4Perl client library but
# with direct requests

# 1) Preflight Checks
my $req = new HTTP::Request("OPTIONS",$url);

my $resp = $ua->request($req);
#print Dumper($resp);
is($resp->header('Access-Control-Allow-Origin'),$origin,"Access-Control-Allow Origin properly set");
ok($resp->header('Access-Control-Allow-Max-Age') > 0,"Max Age set");
ok(!$resp->header('Access-Control-Allow-Request-Header'),"No Request headers set");
$req->header("Access-Control-Request-Headers","X-Extra, X-Extra2");
$req->header('X-Extra',"bla");
$resp = $ua->request($req);
is($resp->header('Access-Control-Allow-Headers'),'X-Extra, X-Extra2',"Allowed headers");

# 2) GET Requests with "Origin:"
$req = new HTTP::Request("GET",$url . "/read/java.lang:type=Memory/HeapMemoryUsage");
$resp = $ua->request($req);

verify_resp("GET",$resp);

# 3) POST Requests with "Origin:"
$req = new HTTP::Request("POST",$url);
$req->content(<<EOT);
{
    "type" : "read",
    "mbean" : "java.lang:type=Memory",
    "attribute" : "HeapMemoryUsage",
    "path" : "used"
}
EOT
$resp = $ua->request($req);

verify_resp("POST",$resp);

# 4) POST Request with "Origin:" and error

$req = new HTTP::Request("POST",$url);
$req->content(<<EOT);
{
    "type" : "bla"
}
EOT
$resp = $ua->request($req);

verify_resp("POST-Error",$resp);

# 5) Try request splitting attack

my $ua2 = new LWP::UserAgent();
$req = new HTTP::Request("GET",$url . "/read/java.lang:type=Memory/HeapMemoryUsage");
$req->header("Origin","http://bla.com\r\n\r\nInjected content");
$resp = $ua2->request($req);
ok($resp->header('Access-Control-Allow-Origin') !~ /[\r\n]/,"No new lines included");
#print Dumper($resp);

# ---------------------------------------------

sub verify_resp {
    my $pref = shift;
    my $resp = shift;

    is($resp->header('Access-Control-Allow-Origin'),$origin,"$pref: Access-Control-Allow Origin properly set");
    ok(!$resp->header('Access-Control-Allow-Max-Age'),"$pref: No Max Age set");
    ok(!$resp->header('Access-Control-Allow-Request-Header'),"$pref: No Request headers set");   
}

