# -*- mode: cperl -*-

use It;
use strict;
use warnings;
use Test::More tests => 4;
use File::Temp qw/tmpnam/;

BEGIN { use_ok("JMX::Jmx4Perl"); }

my $jmx = It->new->jmx4perl;

my $name_p = "jmx4perl.it:type=naming,name=%s";
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


