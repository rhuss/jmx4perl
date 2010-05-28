#!/usr/bin/perl

use strict;
use warnings;
use JMX::Jmx4Perl;
use Data::Dumper;
use Test::More tests => 14;

my $data = 
    {
     "jmx4perl:lang=java,type=class" => [ "jmx4perl",{ lang => "java", type => "class"} ],
     "jmx4perl:lang=java,type=class" => [ "jmx4perl",{ lang => "java", type => "class"} ],
     "jmx4perl:lang=java:perl,type=x" => [ "jmx4perl",{ lang => "java:perl", type => "x"} ],
     "jmx4perl:lang=\"A\\*B\",type=\",\"" => [ "jmx4perl",{ lang => "A*B", type => ","} ],
     "jmx4perl:lang=\"A\\,B\",type=x" => [ "jmx4perl",{ lang => "A,B", type => "x"} ],
     'jmx4perl:name="\\"\\"\\"",type=escape' => [ "jmx4perl", { name => '"""', type => "escape" }],
     "bla:blub" => [ undef, undef ],
     "bla:blub=" => [ undef, undef ],
     "sDSDSADSDA" => [ undef, undef]
    };

my $jmx4perl = new JMX::Jmx4Perl(url => "localhost");
for my $k (sort keys %$data) {
    my ($domain,$attr) = $jmx4perl->parse_name($k);
    my $expected = $data->{$k};
#    print Dumper($attr);
    is($domain,$expected->[0],"Domain: " . ($domain ? $domain : "(undef)"));
    is_deeply($attr,$expected->[1],"Attributes for $k");
}
