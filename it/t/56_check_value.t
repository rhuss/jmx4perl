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
# Check for --value

($ret,$content) = exec_check_perl4jmx("--value java.lang:type=Memory/HeapMemoryUsage/used " . 
                                       "--base java.lang:type=Memory/HeapMemoryUsage/max " . 
                                       "--critical 90 ");
is($ret,0,"Memory with value OK");
ok($content =~ /^OK/,"Content contains OK");

# TODO: Check escaping
($ret,$content) = exec_check_perl4jmx("--value jolokia.it:name=\\/\\/server\\/client,type=naming\\//Ok " . 
                                       "--critical OK");
#print Dumper($ret,$content);
is($ret,2,"CRITICAL expected");
ok($content =~ m|jolokia.it:name=\\/\\/server\\/client,type=naming\\//Ok|,"Content contains MBean name");

($ret,$content) = exec_check_perl4jmx("--value jolokia.it:type=naming\\/,name=\\\"jdbc/testDB\\\"/Ok " . 
                                       "--critical OK");
is($ret,2,"CRITICAL expected");
ok($content =~ m|jolokia.it:type=naming\\/,name="jdbc/testDB"/Ok|,"Content contains weired MBean name");
