use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>0)->jmx4perl;
my ($ret,$content);


# ====================================================
# Relative value checks
my %s = (
      ":90" => [ 0, "OK" ],
      "0.2:" => [ 0, "OK" ],
      ":0.2" => [ 1, "WARNING" ],
      "81:82" => [ 1, "WARNING" ]      
);

for my $base (qw(MEMORY_HEAP_MAX java.lang:type=Memory/HeapMemoryUsage/max 1000000000)) {
    for my $k (keys %s) {
        ($ret,$content) = &exec_check_perl4jmx("--alias MEMORY_HEAP_USED --base $base -w $k");
        is($ret,$s{$k}->[0],"Relative to $base -w $k : $ret");
        ok($content =~ /^$s{$k}->[1]/,"Relative to $base $k : " . $s{$k}->[1]);
    }
}

