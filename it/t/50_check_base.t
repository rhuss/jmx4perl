use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>1)->jmx4perl;
my ($ret,$content);

# ====================================================
# Basic checks
my %s = (
         ":10000000000" => [ 0, "OK" ],
         "0.2:" => [ 0, "OK" ],
         ":0.2" => [ 2, "CRITICAL" ],
         "5:6" => [ 2, "CRITICAL" ]
);
for my $k (keys %s) {
    ($ret,$content) = &exec_check_perl4jmx("--mbean java.lang:type=Memory --attribute HeapMemoryUsage",
                                           "--path used -c $k");
    is($ret,$s{$k}->[0],"Memory -c $k : $ret");
    ok($content =~ /^$s{$k}->[1]/,"Memory -c $k : " . $s{$k}->[1]);
}

# ====================================================
# Alias attribute checks

for my $k (keys %s) {
    ($ret,$content) = &exec_check_perl4jmx("--alias MEMORY_HEAP_USED -c $k");
    is($ret,$s{$k}->[0],"MEMORY_HEAP_USED -c $k : $ret");
    ok($content =~ /^$s{$k}->[1]/,"MEMORY_HEAP_USED $k : " . $s{$k}->[1]);
}

