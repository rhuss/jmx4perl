#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


# Fetch all attributes 
my $jmx = new It(verbose => 0)->jmx4perl;
my $req = new JMX::Jmx4Perl::Request(EXEC,"jolokia.it:type=operation","mapArgument",{ name => "Kyotake"} );
my $resp = $jmx->request($req);
my $value = $resp->{value};

#print Dumper(\@resps);
