use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use JMX::Jmx4Perl::Alias;
use It;
use FindBin;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>0)->jmx4perl;
my ($ret,$content);

# ====================================================
# Given as command line

($ret,$content) = exec_check_perl4jmx("--value java.lang:type=Memory/HeapMemoryUsage/used " . 
                                       "--base java.lang:type=Memory/HeapMemoryUsage/max " . 
                                       "--critical 90 " .
                                       "--perfdata no");

ok($content !~ /\s*\|\s*/,"1: Content contains no perfdata");
($ret,$content) = exec_check_perl4jmx("--value java.lang:type=Memory/HeapMemoryUsage/used " . 
                                       "--base java.lang:type=Memory/HeapMemoryUsage/max " . 
                                       "--warn 80 " .
                                       "--critical 90 " .
                                       "--perfdata %");
ok($content =~ /\s*\|\s*/,"2: Content contains perfdata");
ok($content =~ /80;90/,"2a: Perfdata is relative");
print Dumper($ret,$content);

($ret,$content) = exec_check_perl4jmx("--mbean java.lang:type=Threading " . 
                                       "--operation findDeadlockedThreads " . 
                                       "--null 'nodeadlock' " .
                                       "--string " . 
                                       "--critical '!nodeadlock'");
ok($content !~ /\s*\|\s*/,"3: Content contains no perfdata");

# ====================================================
# Given in config

my $config_file = $FindBin::Bin . "/../check_jmx4perl/checks.cfg";
($ret,$content) = exec_check_perl4jmx("--config $config_file " . 
                                      "--check thread_deadlock"); 
ok($content !~ /\s*\|\s*/,"4: Content contains no perfdata");

($ret,$content) = exec_check_perl4jmx("--config $config_file " . 
                                      "--check memory_without_perfdata"); 
#print Dumper($ret,$content);

ok($content !~ /\s*\|\s*/,"5: Content contains no perfdata");

($ret,$content) = exec_check_perl4jmx("--config $config_file " . 
                                      "--check memory_with_perfdata"); 
#print Dumper($ret,$content);
ok($content =~ /\s*\|\s*/,"6: Content contains perfdata");



