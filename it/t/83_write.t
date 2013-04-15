#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
use strict;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


# Write the object name ad re-read
my $jmx = new It(verbose => 0)->jmx4perl;
my $req = new JMX::Jmx4Perl::Request(WRITE,"jolokia.it:type=attribute","ObjectName","java.lang:type=Memory");
my $resp = $jmx->request($req);
#print Dumper(\$resp);
my $value = $resp->{value};
is($value->{objectName},"bla:type=blub","Set ObjectName: Old Name returned");

$value = $jmx->get_attribute("jolokia.it:type=attribute","ObjectName");
is($value->{objectName},"java.lang:type=Memory","Set ObjectName: New Name set");



$jmx->execute("jolokia.it:type=attribute","reset");

