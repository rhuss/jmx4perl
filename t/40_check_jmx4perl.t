#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib qq($Bin/lib);
use vars qw(@ARGS);
use Test::More;
use Data::Dumper;

eval { require Nagios::Plugin };
if( $@ ) {
    plan skip_all => 'Nagios::Plugin not installed';
}
else {
    plan tests => 21;
}

Nagios::Plugin->import();

eval { require JMX::Jmx4Perl::Nagios::SingleCheck };
ok(!$@,"JMX::Jmx4Perl::Nagios::SingleCheck loads properly");

eval { require JMX::Jmx4Perl::Nagios::CheckJmx4Perl };
ok(!$@,"JMX::Jmx4Perl::Nagios::CheckJmx4Perl loads properly");

@ARGV=qw(--url http://localhost:8080/j4p -a MEMORY_HEAP_USED -c 1 -m 2 --name Memory --unit m);
my $cj4p = new JMX::Jmx4Perl::Nagios::CheckJmx4Perl();
my $scheck = $cj4p->{checks}->[0];
my ($value,$unit) = $scheck->_normalize_value("0.50","MB");
is($value,512);
is($unit,"KB");
($value,$unit) = $scheck->_normalize_value("2048","MB");
is($value,2);
is($unit,"GB");
($value,$unit) = $scheck->_normalize_value("0.5","m");
is($value,30);
is($unit,"s");
($value,$unit) = $scheck->_normalize_value("360","m");
is($value,6);
is($unit,"h");
($value,$unit) = $scheck->_normalize_value("0.5","us");
is($value,"0.5");
is($unit,"us");
($value,$unit) = $scheck->_normalize_value("300","us");
is($value,"300");
is($unit,"us");
($value,$unit) = $scheck->_normalize_value("20","d");
is($value,"20");
is($unit,"d");
($value,$unit) = $scheck->_normalize_value("200","TB");
is($value,"200");
is($unit,"TB");
($value,$unit) = $scheck->_normalize_value(1024*1024,"B");
is($value,1);
is($unit,"MB");

my $label = $scheck->_exit_message(code => &Nagios::Plugin::OK,mode => "numeric",value => "2.1", unit => "MB");
is($label,"Memory : Value 2.10 MB in range");

