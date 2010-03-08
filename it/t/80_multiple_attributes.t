#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


my $jmx = new It(verbose => 0)->jmx4perl;
my $req = new JMX::Jmx4Perl::Request(READ,"jmx4perl.it:type=attribute");
my $resp = $jmx->request($req);
my $value = $resp->{value};
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{Bytes} == 3 * 1024 * 1024 +  1024 * 512,"Bytes");
ok(exists($value->{Null}) && !$value->{Null},"Null");

$jmx->execute("jmx4perl.it:type=attribute","reset");
my $req = new JMX::Jmx4Perl::Request(READ,"jmx4perl.it:type=attribute",["LongSeconds","State"],{method => "post"});
my $resp = $jmx->request($req);
my $value = $resp->{value};
#print Dumper($resp);
is(scalar(keys(%$value)),2,"2 Return values");
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{State} eq "true","State");
$jmx->execute("jmx4perl.it:type=attribute","reset");

#print Dumper($resp);
#print Dumper(\@resps);
