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
my $config_file = $FindBin::Bin . "/../check_jmx4perl/checks.cfg";

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check memory_heap"); 

is($ret,0,"Memory with value OK");
ok($content =~ /\(base\)/,"First level inheritance");
ok($content =~ /\(grandpa\)/,"Second level inheritance");
ok($content !~ /\$\{1:default_name\}/,"Default replacement");
ok($content =~ /default_name/,"Default replacement");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check blubber"); 
is($ret,3,"Unknown check");
ok($content =~ /blubber/,"Unknown check name contained");

# ========================================================================
# With arguments

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check outer_arg OuterArg"); 
is($ret,0,"OuterArg OK");
ok($content =~ /OuterArg/,"OuterArg replaced");

# No replacement
($ret,$content) = &exec_check_perl4jmx("--config $config_file --check outer_arg"); 
is($ret,0,"OuterArg OK");
ok($content =~ /default_name/,"OuterArg not-replaced");

# ===========================================================================
# No default value

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check thread_count"); 
is($ret,3,"No threshold given");
ok($content =~ /critical/i,"No threshold given");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check def_placeholder_1"); 
is($ret,1,"WARNING");
ok($content =~ /warning/i,"Warning expected");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check def_placeholder_1 1"); 
is($ret,1,"WARNING");
ok($content =~ /warning/i,"Warning expected");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check def_placeholder_2"); 
is($ret,1,"WARNING");
ok($content =~ /warning/i,"Warning expected");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check def_placeholder_2 1"); 
is($ret,2,"CRITICAL");
ok($content =~ /critical/i,"Critical expected");

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check def_placeholder_2 1 2 Blubber"); 
is($ret,2,"CRITICAL");
ok($content =~ /critical/i,"Critical expected");
ok($content =~ /Blubber/,"Name replacement from command line");

