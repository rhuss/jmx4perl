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

($ret,$content) = &exec_check_perl4jmx("--value java.lang:type=Memory/HeapMemoryUsage/used " . 
                                       "--base java.lang:type=Memory/HeapMemoryUsage/max " . 
                                       "--critical 90 ");
is($ret,0,"Memory with value OK");
ok($content =~ /^OK/,"Content contains OK");

# TODO: Check escaping
($ret,$content) = &exec_check_perl4jmx("--value jmx4perl.it:name=\\/\\/server\\/client,type=naming/Ok " . 
                                       "--critical OK");
is($ret,2,"CRITICAL expected");
ok($content =~ /jmx4perl.it:name=\\\/\\\/server\\\/client,type=naming\/Ok/,"Content contains MBean name");

