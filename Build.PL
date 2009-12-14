#!/usr/bin/perl
use Module::Build 0.35;

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
      use FindBin;


      die "Distribution must not contain a j4p-access.xml" if -f "$FindBin::Bin/agent/j4p-access.xml";

      my $version_java = "$FindBin::Bin/agent/modules/j4p-jar/src/main/java/org/jmx4perl/Version.java";
      my $version_perl = "$FindBin::Bin/lib/JMX/Jmx4Perl.pm";
      my $pom          = "$FindBin::Bin/agent/pom.xml";


      open(F,"$version_perl") || die "Cannot open $version_perl : $!";
      my $v = join "",<F>;
      close F;
      my $version = $1 if $v =~ /^\s+\$VERSION\s+=\s+"([^"]+)"/m; 
      die "Cannot extract version from $version_perl" unless $version;

      &_replace_version($version_java,$version,
          sub {  
                my $v = shift;
                my $t = shift;
                $t =~ s/String\s+VERSION\s+=\s+"[^"]*"/String VERSION = "$v"/;
                return $t;
               });

      &_replace_version($pom,$version,
          sub {  
                my $v = shift;
                my $t = shift;
                $t =~ s|(<applicationVersion>)\s*(.+)\s*(</applicationVersion>)|$1$v$3|;
                return $t;
               });

      print "Cannot re-create agent.war" 
              unless $self->do_system(qw(ant -f agent/build.xml));
  }

  sub _replace_version {
      my $file = shift;
      my $version = shift;
      my $replace_sub = shift;

      print "Setting version to $version in $file\n";

      open(F,"$file") || die "Cannot open $file : $!";
      my $c = join "",<F>;
      close F;
      $c = &{$replace_sub}($version,$c);
      my $changed_perm = undef;
      if (! -w $file) {
         $changed_perm = 1;
         my $perm = (stat $file)[2] & 07777;
         chmod($perm | 0200,$file) || die "Cannot change write permission for $file : $!";
      }
      open(F,">$file") || die "Cannot open $file for writing: $!";
      print F $c;
      close F;
      if ($changed_perm) {
         my $perm = (stat $file)[2] & 0777;
         chmod($perm & 0577,$file) || die "Cannot remove write permission from $file : $!";
      }
  }
SUBCLASS

my $build = $class->new
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
                "Config::General" => 0,
               },
   recommends => {
                   "Nagios::Plugin" => "0.27",
                   "Config::General" => "0"
                  },
   build_requires => {
                      "Module::Build" => "0.35",
                      "Test::More" => "0",
                      "Test::Deep" => 0,
                      "Test" => "0"
                     },                       
   keywords => [  "JMX", "JEE", "Management" ],
  );

$build->create_build_script;
