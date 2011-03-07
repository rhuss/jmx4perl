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
                "Pod::Usage" => 0,
                "Getopt::Long" => 0,
                "Carp" => 0,
                "Module::Find" => 0,
                "Scalar::Util" => 0,
                "base" => 0,
               },
   recommends => {
                   "Nagios::Plugin" => "0.27",
                   "Text::ParseWords" => 0,
                   "Config::General" => 0,
                   "Term::ShellUI" => 0,
                   "Term::Size" => "0.207",
                   "Term::Clui" => 0,
                   "File::SearchPath" => 0,
                   "Crypt::OpenPGP" => 0,
                   "Digest::MD5" => 0,
                   "Digest::SHA1" => 0,
                   "Archive::Zip" => 0
                  },
   build_requires => {
                      "Module::Build" => "0.34",
                      "Test::More" => "0",
                      "Test::Deep" => 0,
                      "Test" => "0"
                     },                       
   keywords => [  "JMX", "JEE", "Management", "Nagios" ],
  );

$build->create_build_script;
