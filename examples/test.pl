#!/usr/bin/perl

use lib qw/lib/;
use Data::Dumper;
use JMX::Jmx4Perl;

my $agent = JMX::Jmx4Perl->new(url => "http://localhost:8080/json-jmx-agent");

my $ret = $agent->get_attribute("java.lang:type=Memory","HeapMemoryUsage");

print Dumper($ret);
