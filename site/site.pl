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


my $TOP_LEVEL_NAVI_ITEMS = 
  [
     { label => "Home", link => "../index.html" },
     { label => "Documentation", link => "../doc/index.html"},
     { label => "Nagios", link => "../nagios/index.html" },
     { label => "Platforms", link => "../platforms/index.html" },
     { label => "Agent", link => "../agent/index.html" },
  ];

#my $TOP_LEVEL_NAVI = {};
#$TOP_LEVEL_NAVI->{lc $i->{label}} = $i for (my $i @$TOP_LEVEL_NAVI_ITEMS);

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

    my $top_navigation = &top_navi_with_selected("documentation");
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
    my $module_map = &extract_module_map($n2p,$target);
    my $tt_args = 
    { 
     css_base_url => "../style/",
     top_navigation => $top_navigation,
     sub_navigation => [
                       { label => "Manual", link => "../doc/manual/index.html" },
                       { label => "Modules", link => "../doc/modules/index.html", selected => 1},
                       { label => "Protocol", link => "../doc/manual/protocol.html", selected => 1}
                        ],
    };
    
    for my $e (values %$module_map) {
        my $pom = $pod->parse_file($e->{pod});
        my $pod_html = $pom->present('JMX::Jmx4Perl::Site::PodHtml');
        my $boxes = [ &extract_module_sidebar_box($module_map,$e->{name}) ];
        #print Dumper($boxes);
        $template->process("main.tt",{ %$tt_args, boxes => $boxes, content => $pod_html },$e->{path})
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

sub extract_module_map {
    my $n2p = shift;
    my $target = shift;
    my $ret = {};
    for my $name (keys %$n2p) {
        my $html_name =  &module2filename($name) . ".html";
        $ret->{$name} = 
            { 
             path => "$target/$html_name",
             rel_path => $html_name,
             name => $name,
             pod => $n2p->{$name}
            };
    }
    return $ret;
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


sub top_navi_with_selected {
    my $label = shift;
    
    my @ret = ();
    for my $i (@$TOP_LEVEL_NAVI_ITEMS) {
        if (lc($i->{label}) eq lc($label)) {
            my %element = %{$i};
            $element{selected} = 1;
            push @ret,\%element;
        } else {
            push @ret,$i;
        }
    }
    return \@ret;
}

sub extract_module_sidebar_box {
    my $map = shift;
    my $selected = shift;
    my @items = ();
    for my $e (sort { $a->{name} cmp $b->{name} } values %$map) {
        push @items,
            {
             label => $e->{name},
             link => $e->{rel_path},
             $e->{name} eq $selected ? (selected => 1) : ()
            };
    }
    return { 
            title => "Modules",
            items => \@items,
            include => "nav_box.tt"
           };
}
__END__
    my $text = "";
    print ">>>> ",(%$n2p)[3],"\n";
