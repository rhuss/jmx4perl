use FindBin;
use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use JMX::Jmx4Perl::Alias;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>1)->jmx4perl;
my ($ret,$content);

# ====================================================
# Configuration check
my $config_file = $FindBin::Bin . "/../check_jmx4perl/multi_check.cfg";

# Simple multicheck
($ret,$content) = exec_check_perl4jmx("--config $config_file --check memory"); 
#print ($ret,$content);
is($ret,0,"Memory with value OK");
ok($content =~ /\(base\)/,"First level inheritance");
ok($content =~ /\(grandpa\)/,"Second level inheritance");
ok($content =~ /Heap Memory/,"Heap Memory Included");
ok($content =~ /NonHeap Memory/,"NonHeap Memory included");
#print Dumper($ret,$content);

# Nested multichecks
($ret,$content) = exec_check_perl4jmx("--config $config_file --check nested"); 
#print Dumper($ret,$content);
is($ret,0,"Multicheck with value OK");
ok($content =~ /\(base\)/,"First level inheritance");
ok($content =~ /\(grandpa\)/,"Second level inheritance");
ok($content =~ /Thread-Count/,"Threads");
ok($content =~ /'Thread-Count'/,"Threads");
ok($content =~ /Heap Memory/,"Heap Memory Included");
ok($content =~ /NonHeap Memory/,"Non Heap Memory included");

# Multicheck with reference to checks with parameters
($ret,$content) = exec_check_perl4jmx("--config $config_file --check with_inner_args"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /WithInnerArgs/,"WithInnerArgs");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check with_outer_args WithOuterArgs"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /WithOuterArgs/,"WithOuterArgs");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check nested_with_args"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /NestedWithArgs/,"NestedWithArgs");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check nested_with_outer_args NestedWithOuterArgs"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /NestedWithOuterArgs/,"NestedWithOuterArgs");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check overloaded_multi_check"); 
is($ret,0,"Multicheck with argument for operation");
ok($content =~ /Value 1 in range/,"OperationWithArgument");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check failing_multi_check"); 
#print Dumper($ret,$content);
is($ret,2,"Failing memory multicheck is CRITICAL");
ok($content =~ /memory_non_heap/,"Failed check name is contained in summary");

# Check labeling of failed tests
($ret,$content) = exec_check_perl4jmx("--config $config_file --check label_test"); 
is($ret,2,"Should fail as critical");
my @lines = split /\n/,$content;
is($#lines,2,"3 lines has been returned");
ok($lines[0] =~ /bla/ && $lines[0] =~ /blub/,"Name of checks should be returned as critical values");
#print Dumper($ret,$content);

# TODO:

# Unknown multicheck name

# Unknown nested multicheck name

# Unknown check name within a multi check

# No multicheck name
