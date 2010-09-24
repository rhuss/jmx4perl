#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;

BEGIN { use_ok("JMX::Jmx4Perl"); }

my $jmx = new It()->jmx4perl;

my $product = $ENV{JMX4PERL_PRODUCT};
# Test autodetection
if ($product) {
    my $jmx_auto = new JMX::Jmx4Perl(map { $_ => $jmx->cfg($_) } qw(url user password));
    $jmx_auto->info;
    is($jmx_auto->product->id,$product,"Autodetected proper server " . $product);
}

# Test info and detected handler
my $info = $jmx->info();
my $info_product = $1 if $info =~ /^Name:\s+(.*)/m;
my $info_version = $1 if $info =~ /^Version:\s+(.*)/m;
is($jmx->product->name,$info_product || "unknown","Product name match");
is($jmx->product->version,$info_version,"Product version match") if $info_version;

