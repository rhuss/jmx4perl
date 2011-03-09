#!/usr/bin/perl

use JMX::Jmx4Perl;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Alias;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);
my $jmx = new JMX::Jmx4Perl(url => "http://localhost:8888/jolokia-proxy",
                            target => {
                                       url => "service:jmx:rmi:///jndi/rmi://bhut:9999/jmxrmi",
                                       env => { 
                                               user => "monitorRole",
                                               password => "consol",
                                              }
                                      }
                           );
my $req1 = new JMX::Jmx4Perl::Request(READ,{
                                           mbean => "java.lang:type=Memory",
                                           attribute => "HeapMemoryUsage",
                                           }
                                     );
my $req2 = new JMX::Jmx4Perl::Request(LIST);
my $req3 = new JMX::Jmx4Perl::Request(READ,{
                                            mbean => "jboss.system:type=ServerInfo",
                                            attribute => "HostAddress"
                                           }
                                           );
my $t0 = [gettimeofday];
my @resp = $jmx->request($req3);
print "Duration: ",tv_interval($t0,[gettimeofday]),"\n";
print Dumper(@resp);
