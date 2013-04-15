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
is(ref($resp->{value}),"HASH","Response type");
is($resp->{value}->{name},"Kyotake","Response value");

$value = $jmx->execute("jolokia.it:type=operation","findTimeUnit","MINUTES");
is($value,"MINUTES","Enum serialization up and done");

$value = $jmx->execute("jolokia.it:type=operation","addBigDecimal",1,"1e3");
is($value,1001,"Adding big decimal");
#print Dumper($resp);
