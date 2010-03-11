# -*- mode: cperl -*-

use It;
use strict;
use warnings;
use Test::More tests => 14;
use File::Temp qw/tmpnam/;
use Data::Dumper;

BEGIN { use_ok("JMX::Jmx4Perl"); }

my $jmx = It->new(verbose => 0)->jmx4perl;

my $name_p = "jmx4perl.it:type=naming,name=%s";
my @names = 
  (
   "simple",
   "/slash-simple/",
   "/--/",
   "with%3acolon",
   "//server/client",
   "service%3ajmx%3armi%3a///jndi/rmi%3a//bhut%3a9999/jmxrmi"
#   "äöüßÄÖÜ"
  );

my @searches = 
  (
   [ "*:name=//server/client,*", qr|jmx4perl\.it:.*name=//server/client| ]
  );

for my $name (@names) {
    my $mbean = &search($jmx,sprintf($name_p,$name));
    my $scalar = $jmx->get_attribute($mbean,"Ok");
    is($scalar,"OK",$name);
}

for my $s (@searches) {
    my $r = $jmx->search($s->[0]);
    ok($r->[0] =~ $s->[1],"Search " . $s->[0]);    
}

sub search { 
    my $jmx = shift;
    my $prefix = shift;
    my $ret = $jmx->search($prefix . ",*");
    #print Dumper($ret);
    is(scalar(@$ret),1,"One MBean found");
    return $ret->[0];
}

