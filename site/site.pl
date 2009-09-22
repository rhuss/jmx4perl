#!/usr/bin/perl

use FindBin qw($Bin);
use lib qw(lib);
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
use Template;
use File::NCopy qw(copy);

use JMX::Jmx4Perl::Site::PodHtml;

my $config = 
  { new Config::General(-f "$Bin/site_local.cfg" ? "$Bin/site_local.cfg" : "$Bin/site.cfg")->getall };

# Target directory, each time afresh
(-d "$Bin/target" && rmtree("$Bin/target"));
mkdir "$Bin/target";

# Copy resources
&make_resources;

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

sub make_resources { 
    print ":::: Copying resources\n";

    # Copy over stylesheet an CSS files
    copy \1,"$Bin/style","$Bin/target/";
}

sub make_pods {
    print ":::: Making POD documentation\n";
    my $target = "$Bin/target/pod";
    mkdir $target;

    my $pod_search = new Pod::Simple::Search()->limit_glob("JMX::*");
    my $n2p = $pod_search->survey(realpath("$Bin/../lib"));
    my $pod = Pod::POM->new();
    my $template = Template->new
      ({
        INCLUDE_PATH => "$Bin/template:$Bin/template/inc",
        INTERPOLATE => 1,
        DEBUG => 1
       })
      || die Template->error(),"\n";    
    my $tt_args = 
    { 
     css_base_url => "../style/",
     top_navigation => [
                      { label => "Home", link => "../index.html" },
                      { label => "Documentation", link => "../doc/index.html", selected => 1}
                       ],
     sub_navigation => [
                       { label => "Manual", link => "../doc/manual/index.html" },
                       { label => "Modules", link => "../doc/modules/index.html", selected => 1}
                        ],
    };
    for my $name (keys %$n2p) {
        my $pom = $pod->parse_file($n2p->{$name});
        my $pod_html = $pom->present('JMX::Jmx4Perl::Site::PodHtml');
        $template->process("main.tt",{ %$tt_args, content => $pod_html }, "$target/" . &module2filename($name) . ".html")
          || die $template->error,"\n";
    }

    # TODO: 
    # - Linking (external and internal)
    # - Code sections beautified (possibly using a Syntax Higlighter). 
    #   At least, fix font width
    # - Right side boxes

    #print Dumper($pod);
    #print $pom->present('Pod::POM::View::HTML');

    #print $text,"\n";
    #print Dumper(new Pod::Simple::Search()->limit_glob("Pod::*")->survey());
}

sub module2filename {
    my $mod = shift;
    $mod =~ s/::/_/g;
    return $mod;
}
sub make_blog {

}

sub make_index {

}

sub deploy {

}

__END__
    my $text = "";
    print ">>>> ",(%$n2p)[3],"\n";
