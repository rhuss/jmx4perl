#!/usr/bin/perl 

use Getopt::Long;
use JMX::Jmx4Perl;
use Data::Dumper;
use strict;
use warnings;

=head1 NAME

threadDump.pl - Print a thread dump of an JEE Server

=head1 SYNOPSIS
 
  threadDumpl.pl -f org.jmx4perl http://localhost:8080/j4p

  http-0.0.0.0-8080-1 (RUNNABLE):
     ....
     sun.management.ThreadImpl.dumpThreads0(ThreadImpl.java:unknown)
     org.jmx4perl.handler.ExecHandler.doHandleRequest(ExecHandler.java:77)
     org.jmx4perl.handler.RequestHandler.handleRequest(RequestHandler.java:89)
     org.jmx4perl.MBeanServerHandler.dispatchRequest(MBeanServerHandler.java:73)
     org.jmx4perl.AgentServlet.callRequestHandler(AgentServlet.java:205)
     org.jmx4perl.AgentServlet.handle(AgentServlet.java:152)
     org.jmx4perl.AgentServlet.doGet(AgentServlet.java:129)
     ....

=head1 DESCRIPTION

For JEE Server running with Java 6, this simple script prints out a thread
dump, possibly filtered by package name. This is done by executing the MBean
C<java.lang:type=Threading>'s operation C<dumpAllThreads>. 

=cut

my %opts = ();
my $result = GetOptions(\%opts,
                        "user|u=s","password|p=s",
                        "proxy=s",
                        "proxy-user=s","proxy-password=s",
                        "filter|f=s",
                        "verbose|v!",
                        "help|h!" => sub { Getopt::Long::HelpMessage() }
                       );

my $url = $ARGV[0] || die "No URL to j4p agent given\n";
my $jmx = new JMX::Jmx4Perl(url => $url,user => $opts{user},password => $opts{password},
                           proxy => $opts{proxy}, proxy_user => $opts{"proxy-user"});

my $dump;
eval {
    $dump = $jmx->execute("java.lang:type=Threading","dumpAllThreads","false","false");
};
die "Cannot execute thread dump. Remember, $0 works only with Java >= 1.6\n$@\n" if $@;

my @filters = split ",",$opts{filter} if $opts{filter};
for my $thread (@$dump) {
    print "-" x 75,"\n" if print_thread($thread);;
}

sub print_thread {
    my $thread = shift;
    my $st = get_stacktrace($thread->{stackTrace});
    if ($st) {
        print $thread->{threadName}," (",$thread->{threadState},"):\n";
        print $st;
        return 1;
    } else {
        return undef;
    }
}

sub get_stacktrace {
    my $trace = shift;
    my $ret = "";
    my $found = 0;
    my $flag = 1;
    my $last_line;
    for my $l (@$trace) {
        my $class = $l->{className};
        if (!@filters || grep { $class =~ /^\Q$_\E/ } @filters) {
            $ret .= $last_line if ($last_line && !$found);
            $ret .= format_stack_line($l);
            $found = 1;
            $flag = 1;
        } elsif ($flag) {
            $flag = 0;
            $ret .= "     ....\n";
            $last_line = format_stack_line($l);
        }
    }
    return $found ? $ret : undef;
}

sub format_stack_line {
    my $l = shift;
    my $ret = "     ".$l->{className}.".".$l->{methodName}."(".$l->{fileName}.":";
    $ret .= $l->{lineNumber} > 0 ? $l->{lineNumber} : "unknown";
    $ret .= ")\n";
    return $ret;

}
