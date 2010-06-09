#!/usr/bin/perl
use Module::Build 0.34;

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

  sub ACTION_get_war {
      &_download("j4p-war","war","j4p.war","");
  }

  sub ACTION_get_mule_agent {
      &_download("j4p-mule","jar","j4p-mule-agent.jar","-agent");
  }

  sub _download { 
     my ($name,$type,$file,$classifier) = @_;

      eval {
        require LWP;
      };
      if ($@) {
        print "No LWP installed\n";
        exit 1;
      }
      my $BASE_URL = "http://labs.consol.de/maven/repository/org/jmx4perl";
      my $version = &_extract_version();
      my $url = $BASE_URL . "/$name/$version/$name-${version}${classifier}.$type";
      my $ua = LWP::UserAgent->new;
      my $res = $ua->request(new HTTP::Request(GET => $url));
      my $content =  $res->content;
      if ($res->is_success) {
         open(F,">$file") || die "Cannot open $file: $!\n";
         print F $content;
         close F;
         print "Downloaded $file into local directory\n";
      } else {
         print "Error fetching $url\n";
         print $res->status_line,"\n";
         exit 1;
      }
      eval {
         require Digest::SHA1;
      };
      if ($@) {
         print "No Digest::SHA1 installed. Skipping checksum test\n";
         return;
      }
      $res = $ua->request(new HTTP::Request(GET => $url . ".sha1"));
      if ($res->is_success) {
         my $r_sha1 = $res->content;
         chomp $r_sha1;
         my $sha1 = new Digest::SHA1;
         $sha1->add($content);
         if ($r_sha1 ne $sha1->hexdigest) {
            print "CHECKSUM Error:\nRemote SHA1: $r_sha1\nLocal  SHA1: ",$sha1->hexdigest,"\n";
            exit 1;
         } else {
            print "SHA1 Checksum $r_sha1 verified\n";
            return;
         }
      } else {
         print $res->status_line,"\n";
         exit 1;
      }
  }

  sub ACTION_buildagent {
      my $self = shift;
      use FindBin;
      use File::Find;

      die "Distribution must not contain a j4p-access.xml" if -f "$FindBin::Bin/agent/j4p-access.xml";

      my $version_java = "$FindBin::Bin/agent/modules/j4p-jar/src/main/java/org/jmx4perl/Version.java";
      my $pom          = "$FindBin::Bin/agent/pom.xml";
      my $version = &_extract_version();

      die "Cannot extract version from $version_perl" unless $version;

      &_replace_version($version_java,$version,
          sub {  
                my $v = shift;
                my $t = shift;
                $t =~ s/String\s+VERSION\s+=\s+"[^"]*"/String VERSION = "$v"/;
                return $t;
               });

      find( sub { 
        if ($_ eq "pom.xml") {
          &_replace_version($File::Find::name,$version,
            sub {  
                  my $v = shift;
                  my $t = shift;
                  $t =~ s|(</artifactId>\s+<version>)\s*(.+)\s*(</version>)|$1$v$3|;
                  return $t;
                 });
         }
       },"$FindBin::Bin/agent/modules");

      print "Cannot re-create agent.war" 
              unless $self->do_system(qw(ant -f agent/build.xml));
  }

  sub _extract_version {
      my $version_perl = "$FindBin::Bin/lib/JMX/Jmx4Perl.pm";
      open(F,"$version_perl") || die "Cannot open $version_perl : $!";
      my $v = join "",<F>;
      close F;
      my $version = $1 if $v =~ /^\s+\$VERSION\s+=\s+"([^"]+)"/m; 
      return $version;
  }

  sub _replace_version {
      my $file = shift;
      my $version = shift;
      my $replace_sub = shift;

      my ($ma,$mi,$pa,$dev) = ($1,$2,$3,$4) if $version =~ /^(\d+)\.(\d+)(?:\.(\d+))?(?:_(\d+))?$/;
      $pa = "0" unless $pa;
      $version = "$ma.$mi.$pa";
      if ($dev) {
         $version .= ".M" . $dev;
      }
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
               },
   recommends => {
                   "Nagios::Plugin" => "0.27",
                   "Text::ParseWords" => 0,
                   "Config::General" => 0,
                   "Term::ShellUI" => 0,
                   "Term::Size" => "0.207",
                   "Term::Clui" => 0
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
