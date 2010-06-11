#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


# Fetch all attributes 
my $jmx = new It(verbose => 0)->jmx4perl;
my $req = new JMX::Jmx4Perl::Request(READ,"jmx4perl.it:type=attribute");
my $resp = $jmx->request($req);
my $value = $resp->{value};
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{Bytes} == 3 * 1024 * 1024 +  1024 * 512,"Bytes");
ok(exists($value->{Null}) && !$value->{Null},"Null");

# Fetch an array ref of attributes
$jmx->execute("jmx4perl.it:type=attribute","reset");
my $req = new JMX::Jmx4Perl::Request(READ,"jmx4perl.it:type=attribute",["LongSeconds","State"],{method => "post"});
my $resp = $jmx->request($req);
my $value = $resp->{value};
#print Dumper($resp);
is(scalar(keys(%$value)),2,"2 Return values");
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{State} eq "true","State");
$jmx->execute("jmx4perl.it:type=attribute","reset");

my $value = $jmx->get_attribute("jmx4perl.it:type=attribute",["LongSeconds","State"]);
ok($value->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{State} eq "true","State");
$jmx->execute("jmx4perl.it:type=attribute","reset");

# Fetch a pattern with a single attribute
my $value = $jmx->get_attribute("jmx4perl.it:*","LongSeconds");
ok($value->{"jmx4perl.it:type=attribute"}->{LongSeconds} == 60*60*24*2,"LongSeconds");
$jmx->execute("jmx4perl.it:type=attribute","reset");

# Fetch a pattern with all attributes
my $value = $jmx->get_attribute("jmx4perl.it:*",undef);
ok($value->{"jmx4perl.it:type=attribute"}->{LongSeconds} == 60*60*24*2,"LongSeconds");
$jmx->execute("jmx4perl.it:type=attribute","reset");
is($value->{"jmx4perl.it:type=operation"},undef,"Operation missing");
is($value->{"jmx4perl.it:type=attribute"}->{Bytes},3670016,"Bytes with pattern");

# Fetch a pattern with multiple attributes
my $value = $jmx->get_attribute("jmx4perl.it:*",["LongSeconds","State"]);
ok($value->{"jmx4perl.it:type=attribute"}->{LongSeconds} == 60*60*24*2,"LongSeconds");
ok($value->{"jmx4perl.it:type=attribute"}->{State} eq "true","State");
$jmx->execute("jmx4perl.it:type=attribute","reset");

#print Dumper(\@resps);
