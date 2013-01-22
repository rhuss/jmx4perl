use FindBin;
use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use JMX::Jmx4Perl::Alias;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose=>1)->jmx4perl;
my ($ret,$content);

my $time = time;
($ret,$content) = exec_check_perl4jmx("--mbean jolokia.it:type=operation --operation sleep --timeout 1 -c 1 2");
# print Dumper($ret,$content);
# print "Time ",time - $time,"\n";
ok($content =~ /timeout/i,"Timeout reached");
is($ret,3,"UNKNOWN status for timeouts");



