use FindBin;
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
# Configuration check
my $config_file = $FindBin::Bin . "/../check_jmx4perl/multi_check.cfg";

# Simple multicheck
($ret,$content) = &exec_check_perl4jmx("--config $config_file --check memory"); 

is($ret,0,"Memory with value OK");
ok($content =~ /\(base\)/,"First level inheritance");
ok($content =~ /\(grandpa\)/,"Second level inheritance");
ok($content =~ /Heap Memory/,"Heap Memory Included");
ok($content =~ /Perm Gen/,"Perm Gen included");

# Nested multichecks
($ret,$content) = &exec_check_perl4jmx("--config $config_file --check nested"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /\(base\)/,"First level inheritance");
ok($content =~ /\(grandpa\)/,"Second level inheritance");
ok($content =~ /Thread-Count/,"Threads");
ok($content =~ /'Thread-Count'/,"Threads");
ok($content =~ /Heap Memory/,"Heap Memory Included");
ok($content =~ /Perm Gen/,"Perm Gen included");

# Multicheck with reference to checks with parameters
($ret,$content) = &exec_check_perl4jmx("--config $config_file --check with_inner_args"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /WithInnerArgs/,"WithInnerArgs");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check with_outer_args WithOuterArgs"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /WithOuterArgs/,"WithOuterArgs");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check nested_with_args"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /NestedWithArgs/,"NestedWithArgs");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check nested_with_outer_args NestedWithOuterArgs"); 
is($ret,0,"Multicheck with value OK");
ok($content =~ /HelloLabel/,"First param");
ok($content =~ /NestedWithOuterArgs/,"NestedWithOuterArgs");

# TODO:

# Unknown multicheck name

# Unknown nested multicheck name

# Unknown check name within a multi check
