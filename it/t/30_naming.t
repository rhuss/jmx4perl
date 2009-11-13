# -*- mode: cperl -*-

use It;
use strict;
use warnings;
use Test::More tests => 7;
use File::Temp qw/tmpnam/;

BEGIN { use_ok("JMX::Jmx4Perl"); }

my $jmx = It->new(verbose => 0)->jmx4perl;

my $name_p = "jmx4perl.it:type=naming,name=%s";
my @names = 
  (
   "simple",
   "/slash-simple/",
   "/--/",
   "with%3acolon",
   "//server/client"
#   "äöüßÄÖÜ"
  );

my @searches = 
  (
   [ "*:name=//server/client,*", qr|jmx4perl\.it:.*name=//server/client| ]
  );

for my $name (@names) {
    my $scalar = $jmx->get_attribute(sprintf($name_p,$name,),"Ok");
    is($scalar,"OK",$name);
}

for my $s (@searches) {
    my $r = $jmx->search($s->[0]);
    ok($r->[0] =~ $s->[1],"Search " . $s->[0]);    
}


