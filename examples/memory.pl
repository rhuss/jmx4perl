#!/usr/bin/perl
use JMX::Jmx4Perl;
use strict;
my $jmx = new JMX::Jmx4Perl(url => "http://localhost:8080/jolokia");
my $memory = $jmx->get_attribute("java.lang:type=Memory","HeapMemoryUsage");
my ($used,$max) = ($memory->{used},$memory->{max});
if ($memory->{used} / $memory->{max} > 0.9) {
    print "Memory exceeds 90% (used: $used / max: $max = ",int($used * 100 / $max),"%)\n";
    system("/etc/init.d/tomcat restart");
    sleep(120);
}
