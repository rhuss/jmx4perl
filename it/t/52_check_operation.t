use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>0)->jmx4perl;
my ($ret,$content);

# ====================================================
# Operation return value check

# A single slash argument

$jmx->execute("jmx4perl.it:type=operation","reset");

($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,0,"Initial operation");
ok($content =~ /counter=(\d+)/ && $1 eq "0","Initial operation returns 0");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,0,"Second operation");
ok($content =~ /counter=(\d+)/ && $1 eq "1","Second operation returns 1");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=operation --operation fetchNumber",
                                       "-c 1 --name counter inc");
is($ret,2,"Third operation");
ok($content =~ /counter=(\d+)/ && $1 eq "2","Third operation returns 2");

($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=operation --operation emptyStringArgumentCheck",
                                       "-c 1 /");
is($ret,0,"Single slash argument (return code)");
ok($content =~ /false/,"Single slash argument (return message)");
$jmx->execute("jmx4perl.it:type=operation","reset");

