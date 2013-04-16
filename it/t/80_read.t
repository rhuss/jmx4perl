#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


# Fetch all attributes 
my $jmx = new It(verbose => 0)->jmx4perl;

my $req = new JMX::Jmx4Perl::Request(READ,"jolokia.it:type=attribute");
my $resp = $jmx->request($req);
my $value = $resp->{value};
#print Dumper($resp);
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{Bytes} == 3 * 1024 * 1024 +  1024 * 512,"Bytes");
ok(exists($value->{Null}) && !$value->{Null},"Null");

# Fetch an array ref of attributes
$jmx->execute("jolokia.it:type=attribute","reset");
my $req = new JMX::Jmx4Perl::Request(READ,"jolokia.it:type=attribute",["LongSeconds","State"],{method => "post"});
my $resp = $jmx->request($req);
my $value = $resp->{value};
#print Dumper($resp);
is(scalar(keys(%$value)),2,"2 Return values");
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{State} eq "true","State");
$jmx->execute("jolokia.it:type=attribute","reset");

my $value = $jmx->get_attribute("jolokia.it:type=attribute",["LongSeconds","State"]);
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{State} eq "true","State");
$jmx->execute("jolokia.it:type=attribute","reset");

# Fetch a pattern with a single attribute
my $value = $jmx->get_attribute("jolokia.it:*","LongSeconds");
ok($value->{"jolokia.it:type=attribute"}->{LongSeconds} == 60*60*24*2,"LongSeconds");
$jmx->execute("jolokia.it:type=attribute","reset");

# Fetch a pattern with all attributes
my $value = $jmx->get_attribute("jolokia.it:*",undef);
ok($value->{"jolokia.it:type=attribute"}->{LongSeconds} == 60*60*24*2,"LongSeconds");
$jmx->execute("jolokia.it:type=attribute","reset");
is($value->{"jolokia.it:type=operation"},undef,"Operation missing");
is($value->{"jolokia.it:type=attribute"}->{Bytes},3670016,"Bytes with pattern");

# Fetch a pattern with multiple attributes
my $value = $jmx->get_attribute("jolokia.it:*",["LongSeconds","State"]);
ok($value->{"jolokia.it:type=attribute"}->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{"jolokia.it:type=attribute"}->{State} eq "true","State");
$jmx->execute("jolokia.it:type=attribute","reset");

my $value = $jmx->get_attribute("jolokia.it:type=attribute","ObjectName");
ok($value->{objectName} eq "bla:type=blub","object name simplified");
ok(!defined($value->{canonicalName}),"no superfluos parameters");

my $value = $jmx->get_attribute("jolokia.it:type=attribute","Set");
is(ref($value),"ARRAY","Set as array returned");
ok(scalar(grep("jolokia",@$value)),"contains 'jolokia'");
ok(scalar(grep("habanero",@$value)),"contains 'habanero'");

my $value = $jmx->get_attribute("jolokia.it:type=attribute","Utf8Content");
is($value,"☯","UTF-8 ☯ check passed");

my $value = $jmx->get_attribute("jolokia.it:type=attribute","Chili");
is($value,"AJI","Enum serialization passed");

# Fetch all attributes 
$req = new JMX::Jmx4Perl::Request(READ,"jolokia.it.jsonmbean:type=plain");
$resp = $jmx->request($req);
$value = $resp->{value};
#print Dumper($resp);
is($resp->status,200);

# Check Tabular data
$value = $jmx->get_attribute("jolokia.it:type=tabularData","Table2","Value0.0/Value0.1");
is($value->{Column1},"Value0.0","First column");
is($value->{Column2},"Value0.1","Second column");
$value = $jmx->get_attribute("jolokia.it:type=tabularData","Table2","Value0.1/Value0.0");
is($value,undef,"Path with no value");
#print Dumper($resp);
