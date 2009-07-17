#!/usr/bin/perl

use JMX::Jmx4Perl;
use strict;
use Data::Dumper;
use Getopt::Std;

my %opts;
getopts('s',\%opts); 


my $url = $ARGV[0] || die "No url given\n";

my $jmx = JMX::Jmx4Perl->new(url => $url,verbose => 0);

my $MODULE_HANDLER = &init_handler($jmx);
my %VISITED = ();

my $product = $jmx->product;
print "Product: ",$product->name," ",$product->version,"\n";
print "JSR77  : ",$product->jsr77 ? "Yes" : "No","\n\n";

my $domains = $jmx->search("*:j2eeType=J2EEDomain,*");
$domains = [ "(none)" ] unless $domains;
# Special fix for geronimo which seems to have a problem with properly spelling 
# the domain name
#push @$domains,"Geronimo:j2eeType=J2EEDomain,name=Geronimo" if grep { /^geronimo:/ } @$domains;
for my $d (@{$domains || []}) {    
    my $dn = $d eq "(none)" ? "*" : &print(1,$d,"Domain");
    my $servers = $jmx->search("$dn:j2eeType=J2EEServer,*");
    if (!$servers && $d eq "(none)") {
        # That's probably not a real jsr77 container
        # We are looking up all J2EEObject on our own without server and domain
        my $objects = [ grep { /j2eeType/ } @{$jmx->search("*:*")} ];
        &print_modules(1,$objects);
    } elsif (!$servers) {
        print "          == No servers defined for domain $dn ==\n";
    } else {
        for my $s (@{$servers || []}) {
            my $sn = &print(2,$s,"Server");
            for my $o (qw(deployedObjects resources javaVMs)) {
                my $objects = $jmx->get_attribute($s,$o);
                &print_modules(3,$objects);
            }
        }

    }
    print "\n";
}

# Special JBoss handling, since it seems than deployed WARs (WebModules) 
# don't appear below a server but stand on their own (despite the rules
# layed out in JSR77)
if ($product->id eq "jboss" || $product->id eq "weblogic") {
    my $web_modules = $jmx->search("*:j2eeType=WebModule,*");
    if ($web_modules) {
        print "\n=============================================\nJBoss WebModules:\n";
        my $new = [ grep { !$VISITED{$_} } @$web_modules ];
        &print_modules(1,$new);
    }
}

sub init_handler {
    my $jmx = shift;
    return {
            "J2EEApplication" => "modules",
            "AppClientModule" => 0,
            "ResourceAdapterModule" => "resourceAdapters",
            "WebModule" => "servlets",
            "Servlet" => 0,
            "EJBModule" => "ejbs",
            "MessageDrivenBean" => 0,
            "EntityBean" => 0,
            "StatelessSessionBean" => 0,
            "StatefulSessionBean" => 0,
            "JCAResource" => "connectionFactories",
            "JCAConnectionFactory" => "managedConnectionFactory",
            "JCAManagedConnectionFactory" => 0,
            "JavaMailResource" => 0,
            "JDBCResource" => "jdbcDataSources",
            "JDBCDataSource" => "jdbcDriver",
            "JDBCDriver" => 0,
            "JMSResource" => 0,
            "JNDIResource" => 0,
            "JTAResource" => 0,
            "RMI_IIOPResource" => 0,
            "URLResource" => 0,
            "JVM" => sub {
                my ($l,$mod) = @_;
                print "                            ",
                  join(", ",map { $jmx->get_attribute($mod,$_) } qw(javaVendor javaVersion node)),"\n";
            },
            # JBoss specific:
            "ServiceModule" => 0,
            "MBean" => 0
           };
}

sub print_modules {
    my ($l,$objects) = @_;
    for my $k (sort keys %$MODULE_HANDLER) {
        my @mods = grep { $_ =~ /j2eeType=$k/ } @$objects;
        if (@mods) {
            my $handler = $MODULE_HANDLER->{$k};
            for my $mod (@mods) {
                &print($l,$mod);
                if (ref($handler) eq "CODE") {
                    &$handler($l,$mod);
                } elsif ($handler && !ref($handler)) {
                    my $modules = $jmx->get_attribute($mod,$handler);
                    if ($modules) {
                        $modules = ref($modules) eq "ARRAY" ? $modules : [ $modules ];
                        # Fix for Jonas 4.1.2 with jetty, which includes the
                        # WebModule itself in the list of contained Servlets
                        $modules = [ grep { $_ !~ /j2eeType=$k/} @$modules ];
                        &print_modules($l+1,$modules) if scalar(@$modules);
                    }
                }
            }
        }
    }
}



sub print {
   my ($i,$s,$t) = @_;
   $VISITED{$s} = $s;
   my $n = &extract_name($s);
   unless ($t) { 
       $t = $1 if $s =~ /j2eeType=(\w+)/;
   }
   my $can_stat = &check_for_statistics($s);
   print "  " x $i,$t,": ",$n,($can_stat ? " [S] " : ""),"\n";
   print "  " x $i," " x length($t),"  ",$s,"\n";
   if ($opts{s} && $can_stat) {
       eval {
           my $ret = $jmx->get_attribute($s,"stats");
           print Dumper($ret);
       };
   }
   return $n;
}

sub check_for_statistics {
    my $mbean = shift;
    my $ret;
    eval {
        $ret = $jmx->get_attribute($mbean,"statisticsProvider");
    };
    return $@ ? undef : lc($ret) eq "true";
}

sub extract_name {
    my $s = shift;
    $s =~ /.*:.*name=([^,]+)/;
    return $1; 
}
