#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib qq($Bin/lib);
use Data::Dumper;

use Test::More tests => 6;

BEGIN { use_ok("JMX::Jmx4Perl::Alias"); }

# Check names
is(MEMORY_HEAP->name,"memory:heap","Name");

# Check by name
for $_ (qw(memory:heap:used MEMORY_HEAP_USED)) {
    my $heap = JMX::Jmx4Perl::Alias->by_name($_);
    ok(MEMORY_HEAP_USED == $heap,"Equality");
    ok($heap->isa("JMX::Jmx4Perl::Alias::Object"),"isa");
}

