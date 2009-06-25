# -*- mode: cperl -*-

use It;
use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok("JMX::Jmx4Perl"); }

my $jmx = It->new->jmx4perl;

my $name_p = "jmx4perl:type=naming,name=%s";
my @names = 
  (
   "simple",
   "/slash-simple/",
   "/--/",
#   "äöüßÄÖÜ"
  );

for my $name (@names) {
    my $scalar = $jmx->get_attribute(sprintf($name_p,$name,),"Ok");
    is($scalar,"OK",$name);
}


