#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;

# Check for escaped pattern:

my $jmx = It->new(verbose => 0)->jmx4perl;
my $mbeans = $jmx->search("jmx4perl.it:type=escape,*");
for my $m (@$mbeans) {
    my $value = $jmx->get_attribute($m,"Ok");
    is($value,"OK",$m);
}

