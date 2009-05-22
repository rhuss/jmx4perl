#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib qq($Bin/lib);

use Test::More tests => 3;

BEGIN { use_ok("JMX::Jmx4Perl"); }

# Use a new handler directory
&JMX::Jmx4Perl::_register_handlers("ProductHandlerTest");

my $jmx4perl = new JMX::Jmx4Perl(url => "localhost");
my $res = $jmx4perl->resolve_attribute_alias("memory:heap");
ok($res && $res->[0] eq "resolved_name" && $res->[1] eq "resolved_attr","Resolved alias properly");

$jmx4perl = new JMX::Jmx4Perl(url => "localhost", product => "Test2");
my $alias = $jmx4perl->resolve_attribute_alias("memory:heap");
ok($alias && $alias->[0] eq "resolved2_name" && $alias->[1] eq "resolved2_attr","Resolved alias properly");

