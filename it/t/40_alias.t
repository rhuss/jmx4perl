#!/usr/bin/perl

use It;
use Test::More tests => 2;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;

BEGIN { use_ok("JMX::Jmx4Perl::Alias"); }

my $jmx = new It()->jmx4perl;

my @aliases = JMX::Jmx4Perl::Alias->all;
eval {
    for my $alias (@aliases) {
        if ($jmx->supports_alias($alias) && $alias->type eq "attribute") {
            #print $alias->alias,": ",$jmx->get_attribute($alias),"\n";
            $jmx->get_attribute($alias);
        }
    }
};
ok(!$@,"Aliased called: $@");
