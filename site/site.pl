#!/usr/bin/perl

use FindBin qw($Bin);
use Config::General;
use Cwd qw(realpath);
use File::Path;
use File::Find;
use strict;
use warnings;
use Data::Dumper;

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
    my $libdir = realpath("$Bin/../lib");
    my (@pms,@pods);
    find(sub {
             push @pms,$File::Find::name if /.pm$/;
             push @pods,$File::Find::name if /.pod$/;
         },$libdir);
    
    print Dumper(\@pms,\@pods);
    
}

sub make_blog {

}

sub make_index {

}

sub deploy {

}
