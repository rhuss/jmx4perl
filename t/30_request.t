#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib qq($Bin/lib);

use Test::More tests => 2;

BEGIN { use_ok("JMX::Jmx4Perl::Request"); }

ok(READ_ATTRIBUTE eq "read","Import of constants");
