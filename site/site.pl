#!/usr/bin/perl

use FindBin qw($Bin);
use Config::General;
use Cwd qw(realpath);
use File::Path;
use File::Find;
use strict;
use warnings;
use Data::Dumper;
use Pod::Simple::Search;
use Pod::POM;
use Pod::POM::View::HTML;

my $config = 
  { new Config::General(-f "$Bin/site_local.cfg" ? "$Bin/site_local.cfg" : "$Bin/site.cfg")->getall };

# Target directory, each time afresh
(-d "$Bin/target" && rmtree("$Bin/target"));
mkdir "$Bin/target";

# Pod documentation
&make_pods;

# Fetch blog entries for main site
# and convert to static pages
&make_blog;

# Main page and links
&make_index;

# Deploy to real site
&deploy;

# ========================================================================

sub make_pods {
    print ":::: Making POD documentation\n";
    my $pod_search = new Pod::Simple::Search()->limit_glob("JMX::*");
    my $n2p = $pod_search->survey(realpath("$Bin/../lib"));
    print Dumper($n2p);
    my $t = (%$n2p)[3];
    my $pom = Pod::POM->new();
    $pom->parse($t);
    #print Dumper($pod);
    print $pom->present('Pod::POM::View::HTML');

    #print Dumper(new Pod::Simple::Search()->limit_glob("Pod::*")->survey());
}

sub make_blog {

}

sub make_index {

}

sub deploy {

}
