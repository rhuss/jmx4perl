#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


my $jmx = new It(verbose => 0)->jmx4perl;
my $req = new JMX::Jmx4Perl::Request(EXEC,"jolokia.it:type=operation", "overloadedMethod","bla");
my $resp = $jmx->request($req);
ok($resp->{error},"Error must be set");
$req = new JMX::Jmx4Perl::Request(EXEC,"jolokia.it:type=operation", "overloadedMethod()");
$resp = $jmx->request($req);
is($resp->{value},0,"No-Arg operation called");
$req = new JMX::Jmx4Perl::Request(EXEC,"jolokia.it:type=operation", "overloadedMethod(java.lang.String)","bla");
$resp = $jmx->request($req);
is($resp->{value},1,"First operation called");
$req = new JMX::Jmx4Perl::Request(EXEC,"jolokia.it:type=operation", "overloadedMethod(java.lang.String,int)","bla",1);
$resp = $jmx->request($req);
#print Dumper($resp);
is($resp->{value},2,"Second operation called");
$req = new JMX::Jmx4Perl::Request(EXEC,"jolokia.it:type=operation", "overloadedMethod([Ljava.lang.String;)","bla,blub");
$resp = $jmx->request($req);
#print Dumper($resp);
is($resp->{value},3,"Third operation called");
$req = new JMX::Jmx4Perl::Request(EXEC,"jolokia.it:type=operation", "overloadedMethod(java.lang.String,int,long)","bla",3,3);
$resp = $jmx->request($req);
ok($resp->{error},"No such method");
#print Dumper($resp);
#print Dumper(\@resps);
