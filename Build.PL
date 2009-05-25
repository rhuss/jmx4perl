#!/usr/bin/perl
use Module::Build;

my $class = Module::Build->subclass(
      class => "Module::Build::Custom",
      code => <<'SUBCLASS' );

  sub ACTION_dist {
      my $self = shift;
      $self->depends_on("buildagent");
      $self->SUPER::ACTION_dist;
  }

  sub ACTION_clean {
      my $self = shift;
      print "No ant installed, skipping ...\n" unless $self->do_system(qw(ant -f agent/build.xml clean));
      $self->SUPER::ACTION_clean;
  }

  sub ACTION_buildagent {
      my $self = shift;
      
      print "Cannot re-create agent.war" 
              unless $self->do_system(qw(ant -f agent/build.xml));
  }
SUBCLASS

my $build = $class->new
  (
   dist_name => "jmx4perl",
   dist_version_from => "lib/JMX/Jmx4Perl.pm",
   dist_author => 'Roland Huss (roland@cpan.org)',
   dist_abstract => 'Easy JMX access to Java Applications',
   installdirs => 'site',
   script_files => 'scripts',
   license => 'gpl',
   
   requires => {
                "JSON" => "2.12",
                "LWP::UserAgent" => 0,
                "URI" => 0,
                "Data::Dumper" => 0,
                "Pod::Usage" => 0,
                "Getopt::Long" => 0,
                "Carp" => 0,
                "Module::Find" => 0,
                "Object::Tiny" => "1.06",
                "Scalar::Util" => 0
               },
   recommends => {
                   "Nagios::Plugin" => "0.27"
                  },
   build_requires => {
                      "Module::Build" => "0",
                      "Test::More" => "0",
                      "Test" => "0"
                     },                       
   keywords => [  "JMX", "JEE", "Management" ],
  );

$build->create_build_script;
