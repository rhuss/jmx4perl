use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use JMX::Jmx4Perl::Alias;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose => 1)->jmx4perl;
my ($ret,$content);

# ====================================================
# Incremental value checks

reset_history($jmx);

my $membean = "--mbean java.lang:type=Memory --attribute HeapMemoryUsage";
my $cparams = $membean . " --path used --unit B --delta --name mem";


($ret,$content) = exec_check_perl4jmx($cparams);
is($ret,0,"Initial history fetch returns OK");
#print $content;
ok($content =~ /mem=(\d+)/ && $1 eq "0","Initial history fetch returns 0 mem delta");

my $max_mem = $jmx->get_attribute("java.lang:type=Memory", "HeapMemoryUsage","max");
my $c = abs(0.50 * $max_mem);
#print "Mem Max: $mem\n";
my $mem = $jmx->get_attribute("java.lang:type=Memory", "HeapMemoryUsage","used");
#print "Used Memory: $mem\n";

# Trigger Garbage collection
$jmx->execute("java.lang:type=Memory","gc");

for my $i (0 .. 2) {
    $jmx->execute("java.lang:type=Memory","gc");
    ($ret,$content) = exec_check_perl4jmx($cparams . " -c -$c:$c");
    is($ret,0,($i+1) . ". history fetch returns OK for -c $c");
    ok($content =~ /mem=([\-\d]+)/ && $1 ne "0",($i+1) . ". history fetch return non null Mem-Delta ($1)");
    #print Dumper($ret,$content);
    print "Heap: ",$jmx->get_attribute("java.lang:type=Memory","HeapMemoryUsage","used"),"\n";
}
#print "$c: $content\n";

reset_history($jmx);

