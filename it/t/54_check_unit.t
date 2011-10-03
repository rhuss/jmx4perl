use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>0)->jmx4perl;
my ($ret,$content);

# ================================================================================ 
# Unit conversion checking

($ret,$content) = exec_check_perl4jmx
  ("--mbean jolokia.it:type=attribute --attribute Bytes --critical 10000:");
is($ret,0,"Bytes: OK");
ok($content =~ /3670016/,"Bytes: Perfdata");
ok($content !~ /3\.50 MB/,"Bytes: Output");

($ret,$content) = exec_check_perl4jmx
  ("--mbean jolokia.it:type=attribute --attribute Bytes --critical 10000: --unit B");
is($ret,0,"Bytes: OK");
ok($content =~ /3670016B/,"Bytes Unit: Perfdata");
ok($content =~ /3\.50 MB/,"Bytes Unit: Output");

($ret,$content) = exec_check_perl4jmx
  ("--mbean jolokia.it:type=attribute --attribute LongSeconds --critical :10000 ");
is($ret,2,"SecondsLong: CRITICAL");
ok($content =~ /172800/,"SecondsLong: Perfdata");
ok($content !~ /2 d/,"SecondsLong: Output");

($ret,$content) = exec_check_perl4jmx
  ("--mbean jolokia.it:type=attribute --attribute LongSeconds --critical :10000 --unit s");
is($ret,2,"SecondsLong: CRITICAL");
ok($content =~ /172800/,"SecondsLong: Perfdata");
ok($content =~ /2 d/,"SecondsLong: Output");

($ret,$content) = exec_check_perl4jmx
  ("--mbean jolokia.it:type=attribute --attribute SmallMinutes --critical :10000 --unit m");
#print Dumper($ret,$content);
is($ret,0,"SmallMinutes: OK");
ok($content =~ /10.00 ms/,"SmallMinutes: Output");

($ret,$content) = exec_check_perl4jmx
  ("--value jolokia.it:type=attribute/MemoryUsed --base jolokia.it:type=attribute/MemoryMax --critical 80 --unit B");
#print Dumper($ret,$content);
is($ret,0,"Relative Memory: OK");
ok($content =~ /1\.99 GB/,"Relative Memory: Output");

