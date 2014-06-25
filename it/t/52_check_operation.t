use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use It;
use FindBin;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>0)->jmx4perl;
my ($ret,$content);

# ====================================================
# Operation return value check

# A single slash argument

$jmx->execute("jolokia.it:type=operation","reset");

($ret,$content) = exec_check_perl4jmx("--mbean jolokia.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,0,"Initial operation");
ok($content =~ /counter=(\d+)/ && $1 eq "0","Initial operation returns 0");
($ret,$content) = exec_check_perl4jmx("--mbean jolokia.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,0,"Second operation");
ok($content =~ /counter=(\d+)/ && $1 eq "1","Second operation returns 1");
($ret,$content) = exec_check_perl4jmx("--mbean jolokia.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,2,"Third operation");
ok($content =~ /counter=(\d+)/ && $1 eq "2","Third operation returns 2");

my $config_file = $FindBin::Bin . "/../check_jmx4perl/checks.cfg";
($ret,$content) = exec_check_perl4jmx("--config $config_file --check counter_operation");
ok($content =~ /value (\d+)/ && $1 eq "3","Fourth operation return 3");
is($ret,1,"Fourth operation");

#print Dumper($ret,$content);

($ret,$content) = exec_check_perl4jmx("--mbean jolokia.it:type=operation --operation emptyStringArgumentCheck",
                                       "-c 1 /");
is($ret,0,"Single slash argument (return code)");
ok($content =~ /false/,"Single slash argument (return message)");
$jmx->execute("jolokia.it:type=operation","reset");

