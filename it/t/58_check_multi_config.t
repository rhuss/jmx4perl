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
my $config_file = $FindBin::Bin . "/../check_jmx4perl/test.cfg";

($ret,$content) = &exec_check_perl4jmx("--config $config_file --check memory"); 

is($ret,0,"Memory with value OK");
ok($content =~ /\(base\)/,"First level inheritance");
ok($content =~ /\(grandpa\)/,"Second level inheritance");
ok($content =~ /Heap Memory/,"Heap Memory Included");
ok($content =~ /Perm Gen/,"Perm Gen included");

