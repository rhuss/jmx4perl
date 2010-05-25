use strict;
use warnings;
use Test::More qw(no_plan);
use Data::Dumper;
use It;

require "check_jmx4perl/base.pl";

my $jmx = It->new(verbose =>0)->jmx4perl;
my ($ret,$content);

# ====================================================
# Non-numerice Attributes return value check

# Boolean values
$jmx->execute("jmx4perl.it:type=attribute","reset");

($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute State --critical false");
is($ret,0,"Boolean: OK");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute State --critical false");
is($ret,2,"Boolean: CRITICAL");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute State --critical false --warning true");
is($ret,1,"Boolean: WARNING");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute State --critical false --warning true");
is($ret,2,"Boolean (as String): CRITICAL");

# String values
$jmx->execute("jmx4perl.it:type=attribute","reset");

($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute String --critical Started");
is($ret,2,"String: CRITICAL");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute String --critical Started");
is($ret,0,"String: OK");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute String --critical !Started");
is($ret,0,"String: OK");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute String --critical !Started");
is($ret,2,"String: CRITICAL");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute String --critical Stopped --warning qr/art/");
is($ret,1,"String: WARNING");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute String --critical qr/^St..p\\wd\$/ --warning qr/art/");
is($ret,2,"String: CRITICAL");

# Check for a null value
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute Null --critical null");
is($ret,2,"null: CRITICAL");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute Null --critical null --null bla");
is($ret,0,"null: OK");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute Null --critical bla --null bla");
is($ret,2,"null: CRITICAL");
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute Null --critical !null --string");
is($ret,0,"null: OK");

# Check for a string array value
($ret,$content) = &exec_check_perl4jmx("--mbean jmx4perl.it:type=attribute --attribute StringArray --string --critical qr/Stopped/");
is($ret,2,"String Array: CRITICAL");
ok($content =~ /Stopped/,"Matches Threshhold");


