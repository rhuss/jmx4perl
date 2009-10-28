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
use Pod::POM::View::Text;
use JMX::Jmx4Perl::Site::PodHtml;

my $config = 
  { new Config::General(-f "$Bin/site_local.cfg" ? "$Bin/site_local.cfg" : "$Bin/site.cfg")->getall };


my $TOP_LEVEL_NAVI_ITEMS = 
  [
     { label => "Home", link => &make_link("../pages/index.html") },
     { label => "Documentation", link => &make_link("../pod/JMX_Jmx4Perl_Manual.html")},
     { label => "Download", link => &make_link("../pages/download.html")},
#     { label => "Nagios", link => &make_link("../nagios/index.html") },
#     { label => "Platforms", link => &make_link("../platforms/index.html") },
#     { label => "Agent", link => &make_link("../agent/index.html") },
  ];

#my $TOP_LEVEL_NAVI = {};
#$TOP_LEVEL_NAVI->{lc $i->{label}} = $i for (my $i @$TOP_LEVEL_NAVI_ITEMS);

# Target directory, each time afresh
(-d "$Bin/target" && rmtree("$Bin/target"));
mkdir "$Bin/target";

# Copy resources
&make_resources;

# Pod documentation
&make_module_docs;

# Make pages
&make_pages;

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

sub make_pages {
    my $target = "$Bin/target/pages";
    mkdir $target unless -d $target;

    &make_home_pages($target);
    &make_download($target);

}

sub make_home_pages {
    my $target = shift;
    print ":::: Making index pages\n";

    # Index
    my ($template,$base_args) = &_get_template("home");
    open(F,"$Bin/pages/index.html") || die "Cannot open index.html: $!";
    my $pod_html = join "",<F>;
    close F;
    my $tt_args = 
        {
         %$base_args,
         sub_navigation => [
                              { label => "News", link => &make_link("index.html") },
                              { label => "Blog", link => &make_link("blog.html") },
                           ]
        };
    &sub_navigation_select($tt_args,"news");

    $template->process("main.tt",{ %$tt_args, content => $pod_html },"$target/index.html")
      || die $template->error,"\n";
    
}


sub make_download {
    my $target = shift;
    print ":::: Making downoad pages\n";

    # Download
    my ($template,$base_args) = &_get_template("download");
    my $tt_args = 
        {
         %$base_args,
         sub_navigation => [
                              { label => "Distribution", link => &make_link("dowload.html") },
                              { label => "Agent", link => &make_link("agent.html") },
                           ]
        };
    &sub_navigation_select($tt_args,"distribution");
    open(F,"$Bin/pages/download.html") || die "Cannot open download.html: $!";
    my $pod_html = join "",<F>;
    close F;
    $template->process("main.tt",{ %$tt_args, content => $pod_html },"$target/download.html")
      || die $template->error,"\n";
}

sub make_module_docs {
    print ":::: Making Module documentation\n";
    my $target = "$Bin/target/pod";
    mkdir $target;

    my $pod_search = new Pod::Simple::Search()->limit_glob("JMX::*");
    my $n2p = $pod_search->survey(realpath("$Bin/../lib"));
    my $pod = Pod::POM->new();
    my ($template,$base_args) = &_get_template("documentation");
    my $module_map = &extract_module_map($n2p,$target);
    #print Dumper($module_map);
    my $tt_args = 
    { 
     %$base_args,
     sub_navigation => [
                       { label => "Manual", link => &make_link("JMX_Jmx4Perl_Manual.html") },
                       { label => "Modules", link => &make_link("modules.html") },
                       { label => "Protocol", link => &make_link("JMX_Jmx4Perl_Agent_Protocol.html") }
                        ],
    };
    
    for my $e (values %$module_map) {
        my $pom = $pod->parse_file($e->{pod});
        $module_map->{$e->{name}}->{pom} = $pom;
        my $pod_html = $pom->present('JMX::Jmx4Perl::Site::PodHtml');
        #print Dumper($boxes);
        my $type = $e->{name} =~ /::(Manual|Protocol)$/ ? lc($1) : "modules";
        my $boxes = [ &extract_module_sidebar_box($module_map,$e->{name}) ] if $type eq "modules";
        &sub_navigation_select($tt_args,$type);
        $template->process("main.tt",{ %$tt_args, boxes => $boxes, content => $pod_html },$e->{path})
          || die $template->error,"\n";
    }

    # Make modules.html
    &sub_navigation_select($tt_args,"modules");
    for my $e (grep { $_->{name} !~ /::(Manual|Protocol)$/ } sort { $a->{name} cmp $b->{name} } values %$module_map) {
        push @{$tt_args->{modules}},{ "link" => $e->{link},"name" => $e->{name}, 
                                      "description" => &extract_description($e->{pom}) };
    }
    my $modules_html;
    $template->process("modules.tt",$tt_args,\$modules_html);
    $template->process("main.tt",{ %$tt_args, content => $modules_html },"$target/modules.html")
      || die $template->error,"\n";
    
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

sub _get_template {
    my $menu_label = shift;
    my $top_navigation = &top_navi_with_selected($menu_label);

    my $template = Template->new
      ({
        INCLUDE_PATH => "$Bin/template:$Bin/template/inc",
        INTERPOLATE => 1,
        DEBUG => 1
       })
      || die Template->error(),"\n";    

    my $base_args = {
                     css_base_url => "../style/",
                     top_navigation => $top_navigation,
                    };
    return ($template,$base_args);
}

sub extract_description {
    my $pom = shift;
    my $head = $pom->head1()->[0];
    my $txt = $head->present('Pod::POM::View::Text');
    $txt =~ /^.*?\-\s*(.*)$/s;
    return $1;
}

sub sub_navigation_select { 
    my $pars = shift;
    my $label = shift;
    for my $e (@{$pars->{sub_navigation}}) {
        $e->{selected} = lc($e->{label}) eq lc($label) ? 1 : 0;
    }
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
             link => &make_link($html_name),
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
        unless ($e->{name} =~ /::(Protocol|Manual)$/) {
            push @items,
                {
                 label => $e->{name},
                 link => $e->{link},
                 $e->{name} eq $selected ? (selected => 1) : ()
                };
        }
    }
    return { 
            title => "Modules",
            items => \@items,
            include => "nav_box.tt"
           };
}

sub make_link { 
    my $link = shift;
    # return $link . "#start";
    return $link;
}

__END__
