#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib qq($Bin/lib);

use Test::More tests => 22;

BEGIN { use_ok("JMX::Jmx4Perl::Request"); }

ok(READ eq "read","Import of constants");

my $names = 
    {
     "jmx4perl.it:name=\"name\\*with\\?strange=\\\"chars\",type=escape" => 0,
     "*:*" => 1,
     "*:type=bla" => 1,
     "domain:*" => 1,
     "domain:name=blub,*" => 1,
     "domain:name=*,type=blub" => 1,
     "domain:name=*,*" => 1, 
     "domain:name=\"\\*\",type=blub" => 0,
     "domain:name" => 0,
     "domain:name=Bla*blub" => 1,
     "domain:name=\"Bla\\*blub\"" => 0,
     "domain:name=\"Bla\\*?blub\"" => 1,     
     "domain:name=\"Bla\\*\\?blub\"" => 0,     
     "domain:name=\"Bla\\*\\?blub\",type=?" => 1,
     "do*1:name=bla" => 1,
     "do?1:name=bla" => 1
    };

for my $name (keys %$names) {
    my $req = new JMX::Jmx4Perl::Request(READ,$name,"attribute");
    my $is_pattern = $req->is_mbean_pattern;
    is($is_pattern,$names->{$name},"Pattern: $name");
}

# Check for autodetection of requests
my $name="domain:attr=val";
my $req = new JMX::Jmx4Perl::Request(READ,$name,"attribute");
is($req->method(),"","Method not defined");
$req = new JMX::Jmx4Perl::Request(READ,$name,"attribute",{method => "PoSt"});
is($req->method(),"POST","Post method");
$req = new JMX::Jmx4Perl::Request(READ,$name,["a1","a2"]);    
is($req->method(),"POST","Read with attribute refs need POST");
eval {
    $req = new JMX::Jmx4Perl::Request(READ,$name,["a1","a2"],{method => "GET"});    
};
ok($@,"No attributes with GET");


