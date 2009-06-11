#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib qq($Bin/lib);
use JMX::Jmx4Perl::Alias;
use Data::Dumper;
use Test::More tests => 10;

BEGIN { use_ok("JMX::Jmx4Perl"); }

# Use a new handler directory
&JMX::Jmx4Perl::_register_handlers("ProductTest");

my $jmx4perl = new JMX::Jmx4Perl(url => "localhost");
my @res = $jmx4perl->resolve_alias("memory:heap");
ok(@res && $res[0] eq "resolved_name" && $res[1] eq "resolved_attr","Resolved alias properly");

$jmx4perl = new JMX::Jmx4Perl(url => "localhost", product => "Test2");
my @alias = $jmx4perl->resolve_alias("memory:heap");
ok(@alias && $alias[0] eq "resolved2_name" && $alias[1] eq "resolved2_attr","Resolved alias properly");
@alias = $jmx4perl->resolve_alias("MEMORY_GC");
ok(@alias && $alias[0] eq "memory2_name" && $alias[1] eq "gc2_op","Resolved operation alias properly");

is($JMX::Jmx4Perl::PRODUCT_HANDLER_ORDERING[0],"test2","Test ordering");
is($JMX::Jmx4Perl::PRODUCT_HANDLER_ORDERING[1],"test1","Test ordering");

$jmx4perl = new JMX::Jmx4Perl(url => "localhost");
@res = $jmx4perl->resolve_alias(SERVER_NAME);
is($res[0],"server","Check for alias resolving by closure");
is($res[1],"name","Check for alias resolving by closure");
my $code = $jmx4perl->resolve_alias(SERVER_ADDRESS);
is(ref($code),"CODE","Check for code based resolving");
is(&$code,"127.0.0.1","Check for code based resolving");
