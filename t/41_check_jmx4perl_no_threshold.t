#!/usr/bin/perl
use Test::More;

eval { require Nagios::Plugin };
if ($@) {
    plan skip_all => 'Nagios::Plugin not installed';
}
else {
    plan tests => 29;
}

Nagios::Plugin->import();
my $np = new Nagios::Plugin();

print ($np->check_threshold(check => 10)),"\n";
