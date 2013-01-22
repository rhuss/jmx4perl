# -*- mode: cperl -*-

use It;
use strict;
use warnings;
use Test::More tests => 16;
use File::Temp qw/tmpnam/;
use Data::Dumper;
use JMX::Jmx4Perl::Request;

my $jmx = It->new(verbose => 0)->jmx4perl;

my ($req,$resp,$list);
for my $method ("post","get") {
    $req = new JMX::Jmx4Perl::Request(READ,"jolokia.it:type=attribute","ComplexNestedValue","Blub/1/numbers/1",{method => $method});
    $resp = $jmx->request($req);
    is($resp->{value},23);
    for my $path ("",undef,"/") {
        $req = new JMX::Jmx4Perl::Request(READ,"jolokia.it:type=attribute","Map",$path,{method => $method});       
        $resp = $jmx->request($req);
        is($resp->{value}->{fcn},"meister");
        $req = new JMX::Jmx4Perl::Request(LIST,$path,{method => $method});       
        $resp = $jmx->request($req);
        ok($resp->{value}->{'jolokia.it'});
    }
    $req = new JMX::Jmx4Perl::Request(LIST,"/java.lang/",{method => $method});
    $resp = $jmx->request($req);
    #print Dumper($resp);    
}

$list = $jmx->list("jolokia.it/name=!/!/server!/client,type=naming!//attr");
is($list->{Ok}->{type},"java.lang.String");
#my $list = $jmx->list("jolokia.it");
$req = new JMX::Jmx4Perl::Request(LIST,"jolokia.it/name=!/!/server!/client,type=naming!//attr",{method => "POST"});
$resp = $jmx->request($req);
#print Dumper($resp);
is($resp->{value}->{Ok}->{type},"java.lang.String");

