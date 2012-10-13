#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use Data::Dumper;
#use Test::More tests => $ENV{JMX4PERL_PRODUCT} ? 2 : 1;


# Fetch all attributes 
my $jmx = new It(verbose => 0)->jmx4perl;
my $req = new JMX::Jmx4Perl::Request(EXEC,{ mbean => "jolokia.it:type=operation", operation => "mapArgument",arguments => [{ name => "Kyotake"}],method => "POST"} );
my $resp = $jmx->request($req);
my $value = $resp->{value};
is(ref($resp->{value}),"HASH");
is($resp->{value}->{name},"Kyotake");
#print Dumper($resp);
