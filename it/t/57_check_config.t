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
my $config_file = $FindBin::Bin . "/../check_jmx4perl/checks.cfg";

for my $check (qw(memory_heap memory_heap2)) {
    ($ret,$content) = exec_check_perl4jmx("--config $config_file --check $check"); 
    is($ret,0,"$check: Memory with value OK");
    ok($content =~ /\(base\)/,"$check: First level inheritance");
    ok($content =~ /\(grandpa\)/,"$check: Second level inheritance");
    ok($content !~ /\$\{1:default_name\}/,"$check: Default replacement");
    ok($content =~ /default_name/,"$check: Default replacement");
}

($ret,$content) = exec_check_perl4jmx("--config $config_file --check blubber"); 
is($ret,3,"Unknown check");
ok($content =~ /blubber/,"Unknown check name contained");

# ========================================================================
# With arguments

($ret,$content) = exec_check_perl4jmx("--config $config_file --check outer_arg OuterArg"); 
#print Dumper($ret,$content);
is($ret,0,"OuterArg OK");
ok($content =~ /OuterArg/,"OuterArg replaced");
ok($content =~ /Warning: 80/,"Warning included in label");
ok($content =~ /Critical: 90/,"Critical included in label");

# No replacement
($ret,$content) = exec_check_perl4jmx("--config $config_file --check outer_arg"); 
is($ret,0,"OuterArg OK");
ok($content =~ /default_name/,"OuterArg not-replaced");

# ===========================================================================
# No default value

($ret,$content) = exec_check_perl4jmx("--config $config_file --check def_placeholder_1"); 
is($ret,1,"WARNING");
ok($content =~ /warning/i,"Warning expected");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check def_placeholder_1 1"); 
is($ret,1,"WARNING");
ok($content =~ /warning/i,"Warning expected");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check def_placeholder_2"); 
is($ret,1,"WARNING");
ok($content =~ /warning/i,"Warning expected");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check def_placeholder_2 1"); 
is($ret,2,"CRITICAL");
ok($content =~ /critical/i,"Critical expected");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check def_placeholder_2 1 2 Blubber"); 
is($ret,2,"CRITICAL");
ok($content =~ /critical/i,"Critical expected");
ok($content =~ /Blubber/,"Name replacement from command line");

($ret,$content) = exec_check_perl4jmx("--config $config_file --check invalid_method 10 20"); 
is($ret,3,"UNKNOWN");
ok($content =~ /Unknown.*method/,"Unknown request method");

($ret,$content) = exec_check_perl4jmx("--config $config_file --method invalid --check thread_count 10 20"); 
is($ret,3,"UNKNOWN");
ok($content =~ /Unknown.*method/,"Unknown request method");

($ret,$content) = exec_check_perl4jmx("--config $config_file --method get --check thread_count 300 400"); 
is($ret,0,"OK");
ok($content =~ /in range/,"In range");

# =============================================================================
# With scripting

($ret,$content) = exec_check_perl4jmx("--config $config_file --check script_check Eden");
is($ret,2);
ok($content =~ /threshold/i,"Script-Check: Threshold contained");


($ret,$content) = exec_check_perl4jmx("--config $config_file --check script_multi_check Perm");
is($ret,0);
#print Dumper($ret,$content);
ok($content =~ /Perm/,"Multi-Script-Check: Perm contained");
ok($content =~ /Eden/,"Multi-Script-Check: Eden contained");
ok($content =~ /thread_count/,"Multi-Script-Check: Thread_count contained");

# ===========================================================================
# Double values 

($ret,$content) = exec_check_perl4jmx("--config $config_file --check double_min"); 
$content =~ /double_min=(.*?);/;
my $min = $1;
#print Dumper($min,$ret ,$content,$1);
is($min,"0.000000","Small double numbers are converted to floats");

# ===========================================================================
# Without Thresholds

($ret,$content) = exec_check_perl4jmx("--config $config_file --check without_threshold");

#print Dumper($content);
