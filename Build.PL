#!/usr/bin/perl 
use Module::Build 0.34;

my $build = Module::Build->new
  (
   dist_name => "jmx4perl",
   dist_version_from => "lib/JMX/Jmx4Perl.pm",
   dist_author => 'Roland Huss (roland@cpan.org)',
   dist_abstract => 'Easy JMX access to Java JEE applications',
   installdirs => 'site',
   script_files => 'scripts',
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
                  "Nagios::Plugin" => "0.27", # req
                  "Text::ParseWords" => 0,    # req
                  "Config::General" => 0,     # req
                  "Pod::Usage" => 0,          # opt
                  # j4psh
                  "Term::ShellUI" => 0,       # req
                  "Term::Clui" => 0,          # req
                  "Term::Size" => "0.207",    # opt
                  "File::SearchPath" => 0,    # opt
                  # jolokia
                  "Archive::Zip" => 0,        # req
                  "XML::LibXML" => 0,         # req
                  "Crypt::OpenPGP" => 0,      # opt
                  "Digest::MD5" => 0,         # opt
                  "Digest::SHA1" => 0,        # opt
                  "XML::Tidy" => 0,           # opt
                  "Term::ProgressBar" => 0    # opt
                 },
   build_requires => {
                      "Module::Build" => "0.34",
                      "Test::More" => "0",
                     },                       
   configure_requires => { 'Module::Build' => 0.34 },
   keywords => [  "JMX", "JEE", "Management", "Nagios", "Java" ],
  );

$build->create_build_script;
