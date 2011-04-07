#!/usr/bin/perl 
use Module::Build 0.34;
use strict;
use Data::Dumper;


# Switch of warning locally
local $SIG{__WARN__} = sub { };
my $build = Module::Build->new
  (
   dist_name => "jmx4perl",
   dist_version_from => "lib/JMX/Jmx4Perl.pm",
   dist_author => 'Roland Huss (roland@cpan.org)',
   dist_abstract => 'Easy JMX access to Java JEE applications',
   sign => 1,
   installdirs => 'site',
   license => 'gpl',
   
   requires => {
                "JSON" => "2.12",
                "LWP::UserAgent" => 0,
                "URI" => "1.35",
                "Data::Dumper" => 0,
                "Getopt::Long" => 0,
                "Carp" => 0,
                "Module::Find" => 0,
                "Scalar::Util" => 0,
                "base" => 0,
               },
   recommends => {
                  # check_jmx4perl
                  # j4psh
                  # jolokia
                 },
   build_requires => {
                      "Module::Build" => "0.34",
                      "Test::More" => "0",
                     },                       
   configure_requires => { 'Module::Build' => 0.34 },
   keywords => [  "JMX", "JEE", "Management", "Nagios", "Java" ],
  );
$SIG{__WARN__} = undef;

# Ask for various installation options:

print <<EOT;

Jmx4Perl comes with a set of supporting scripts, which 
are not necessarily required for using JMX::Jmx4Perl 
programmatically
EOT

my $msg = <<EOT;

check_jmx4perl
==============

check_jmx4perl is a full featured Nagios Plugin (www.nagios.org) for 
monitoring JEE and other Java-servers.

Install 'check_jmx4perl' ? (y/n)
EOT

chomp $msg;
my $answer = $build->y_n($msg,"y");
if ($answer) {
    &add_reqs($build,
              "Nagios::Plugin" => "0.27", # req
              "Text::ParseWords" => 0,    # req
              "Config::General" => 0,     # req
              "Pod::Usage" => 0,          # opt
             );
    $build->script_files("scripts/check_jmx4perl" => 1);   
}

$msg = <<EOT;

cacti_jmx4perl
==============

cacti_jmx4perl is a script which can be used as a 
Cacti (www.cacti.net) plugin.

Install 'cacti_jmx4perl' ? (y/n)
EOT
chomp $msg;
$answer = $build->y_n($msg,"y");
if ($answer) {
    &add_reqs($build,
              "Nagios::Plugin" => "0.27", # req
              "Text::ParseWords" => 0,    # req
              "Config::General" => 0,     # req
              "Pod::Usage" => 0,          # opt
             );
    $build->script_files("scripts/cacti_jmx4perl" => 1);   
}

$msg = <<EOT;

j4psh
=====

j4psh is an interactive JMX shell with context sensitive command line
completion. It uses JMX::Jmx4Perl for connecting to the JMX backend
and has some Perl module dependencies.

Install 'j4psh' ? (y/n)
EOT
chomp $msg;
$answer = $build->y_n($msg,"y");

if ($answer) {
    &add_reqs($build,
              "Term::ShellUI" => 0,      # req
              "Term::Clui" => 0,         # req 
              "Term::Size" => "0.207",   # opt 
              "Config::General" => 0,    # opt
              "File::SearchPath" => 0    # opt 
             );
    $build->script_files("scripts/j4psh" => 1);
    # check for Term::ReadLine::Gnu
    my $has_gnu_readline = eval "require Term::ReadLine; require Term::ReadLine::Gnu; 1";
    my $has_perl_readline = eval "require Term::ReadLine::Perl; 1";
    if (!$has_gnu_readline) {
        $msg = <<EOT;

Term::ReadLine::Gnu is the recommended readline module, but is 
not necessarily required (Term::ReadLine::Perl). It requires
the libreadline installed with header files, though.

Use Term::ReadLine::Gnu ? (y/n)
EOT
        chomp $msg;
        $answer = $build->y_n($msg,"n");
        if ($answer) {
            &add_reqs($build,"Term::ReadLine::Gnu" => 0);
        } elsif (!$has_perl_readline) {
            &add_reqs($build,
                      "Term::ReadLine::Perl" => 0,
                      "Term::ReadKey" => 0);
        }
    }
}

$msg = <<EOT;

jolokia
=======

jolokia is an utility which helps in downloading
and managing the Jolokia agents (www.jolokia.org), which 
are required on the server side for using jmx4perl.

Install 'jolokia' ? (y/n)
EOT
chomp $msg;
$answer = $build->y_n($msg,"y");
if ($answer) {
    &add_reqs($build,
              "Archive::Zip" => 0,        # req
              "XML::LibXML" => 0,         # req
              "File::Temp" => 0,          # req
              "Digest::MD5" => 0,         # opt
              "Digest::SHA1" => 0,        # opt
              "XML::Tidy" => 0,           # opt
              "Term::ProgressBar" => 0    # opt
             );
    $build->script_files("scripts/jolokia" => 1);
    my $has_openpgp = eval "require Crypt::OpenPGP; 1";
    if (!$has_openpgp) {
        my $check = `gpg --version`;
        if ($?) {
            $check = `gpg2 --version`;
            if ($?) {
                $msg = <<EOT;
                
jolokia uses PGP verification of the files downloaded, but neither
Crypt::OpenPGP nor GnuPG is installed. It is highly recommended to 
install one of them. Installing Crypt::OpenPGP can be a pain due to its
large set of dependencies. 

Use Crypt::OpenPGP ? (y/n)
EOT
                chomp $msg;
                $answer = $build->y_n($msg,"y");
                if ($answer) {
                    &add_reqs($build,"Crypt::OpenPGP" => 0);
                }
            }
        }
    }
}

print "\n";
print "----------------------------------------------------------------\n";
if (!$build->check_prereq) {
    print <<EOF;

ERRORS/WARNINGS FOUND IN PREREQUISITES.  You may wish to install the versions
of the modules indicated above before proceeding with this installation

EOF
    if ($Module::Build::VERSION ge "0.36" && !$ENV{PERL5_CPANPLUS_IS_RUNNING} && !$ENV{PERL5_CPAN_IS_RUNNING}) {
        print <<EOF;
Run 'Build installdeps' to install missing prerequisites.

EOF
    }
  }

$build->create_build_script;

# Add extra requirements
sub add_reqs {
    my $build = shift;
    my %to_add = @_;
    for my $k (keys %to_add) {
        $build->requires($k => $to_add{$k});
    }
}
