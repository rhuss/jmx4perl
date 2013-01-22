use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use JMX::Jmx4Perl::Alias;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>0)->jmx4perl;
my ($ret,$content);

# ====================================================
# Incremental value checks

reset_history($jmx);

($ret,$content) = exec_check_perl4jmx("--alias MEMORY_HEAP_USED --delta -c 10 --name mem");
is($ret,0,"Initial history fetch returns OK");
ok($content =~ /mem=(\d+)/ && $1 eq "0","Initial history fetch returns 0 mem delta");

$jmx->get_attribute(MEMORY_HEAP_USED);
my $mem = $jmx->get_attribute(MEMORY_HEAP_MAX);
my $c = abs(0.50 * $mem);
#print "Mem: $mem\n";

# Trigger Garbage collection
#$jmx->execute("java.lang:type=Memory","gc");

for (0 .. 2) {
    $jmx->execute("java.lang:type=Memory","gc");
    ($ret,$content) = exec_check_perl4jmx("--alias MEMORY_HEAP_USED --unit B --delta -c -$c:$c --name mem");
    print Dumper($ret,$content);
    print "Heap: ",$jmx->get_attribute("java.lang:type=Memory","HeapMemoryUsage","used"),"\n";

    is($ret,0,"Second history fetch returns OK for -c $c");
    ok($content =~ /mem=([\-\d]+)/ && $1 ne "0","Second History fetch return non null Mem-Delta ($1)");
}
#print "$c: $content\n";

reset_history($jmx);

