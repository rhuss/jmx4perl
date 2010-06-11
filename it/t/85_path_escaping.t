# -*- mode: cperl -*-

use It;
use strict;
use warnings;
use Test::More tests => 2;
use File::Temp qw/tmpnam/;
use Data::Dumper;
use JMX::Jmx4Perl::Request;

my $jmx = It->new(verbose => 0)->jmx4perl;

my $list = $jmx->list("jmx4perl.it/name=\\/\\/server\\/client,type=naming/attr");
is($list->{Ok}->{type},"java.lang.String");
#my $list = $jmx->list("jmx4perl.it");
my $req = new JMX::Jmx4Perl::Request(LIST,"jmx4perl.it/name=\\/\\/server\\/client,type=naming/attr",{method => "POST"});
my $resp = $jmx->request($req);
is($resp->{value}->{Ok}->{type},"java.lang.String");
