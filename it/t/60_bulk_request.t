#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


my $jmx = new It()->jmx4perl;
my @reqs = ( new JMX::Jmx4Perl::Request(READ,"java.lang:type=Memory", "HeapMemoryUsage", "used"),
             new JMX::Jmx4Perl::Request(READ,"java.lang:type=Memory", "HeapMemoryUsage", "max"),
             new JMX::Jmx4Perl::Request(READ,"java.lang:type=ClassLoading", "LoadedClassCount"),
             new JMX::Jmx4Perl::Request(SEARCH,"*:type=Memory,*"));

my @resps = $jmx->request(@reqs);
is(scalar(@resps),4,"4 Responses");
for (my $i = 0 .. 3) {
    is($resps[$i]->{request},$reqs[$i],"Request " . ($i+1));
}
#print Dumper(\@resps);
