#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use lib qq($Bin/lib);
use vars qw(@ARGS);
use Test::More tests => 20;


SKIP: {
    eval { require Nagios::Plugin };
    skip "Nagios::Plugin not installed", 20 if $@;
    Nagios::Plugin->import();

    eval { require JMX::Jmx4Perl::Nagios::CheckJmx4Perl };
    ok(!$@,"JMX::Jmx4Perl::Nagios::CheckJmx4Perl loads properly");

    @ARGV=qw(--url http://localhost:8080/j4p -a MEMORY_HEAP_USED -c 1 -m 2 --name Memory --unit m);
    my $cj4p = new JMX::Jmx4Perl::Nagios::CheckJmx4Perl();
    my ($value,$unit) = $cj4p->_normalize_value("0.50","MB");
    is($value,512);
    is($unit,"KB");
    ($value,$unit) = $cj4p->_normalize_value("2048","MB");
    is($value,2);
    is($unit,"GB");
    ($value,$unit) = $cj4p->_normalize_value("0.5","m");
    is($value,30);
    is($unit,"s");
    ($value,$unit) = $cj4p->_normalize_value("360","m");
    is($value,6);
    is($unit,"h");
    ($value,$unit) = $cj4p->_normalize_value("0.5","us");
    is($value,"0.5");
    is($unit,"us");
    ($value,$unit) = $cj4p->_normalize_value("300","us");
    is($value,"300");
    is($unit,"us");
    ($value,$unit) = $cj4p->_normalize_value("20","d");
    is($value,"20");
    is($unit,"d");
    ($value,$unit) = $cj4p->_normalize_value("200","TB");
    is($value,"200");
    is($unit,"TB");
    ($value,$unit) = $cj4p->_normalize_value(1024*1024,"B");
    is($value,1);
    is($unit,"MB");
    
    my $label = $cj4p->_exit_message(code => &Nagios::Plugin::OK,mode => "numeric",value => "2.1", unit => "MB");
    is($label,"Memory : Value 2.10 MB in range");
}
