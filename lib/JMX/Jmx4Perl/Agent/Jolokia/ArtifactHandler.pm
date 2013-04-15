#!/usr/bin/perl 
package JMX::Jmx4Perl::Agent::Jolokia::ArtifactHandler;

=head1 NAME

JMX::Jmx4Perl::Agent::ArtifactHandler - Handler for extracting and manipulating
Jolokia artifacts

=head1 DESCRIPTION

This module is responsible for mangaging a singe JAR or WAR Archive. It
requires L<Archive::Zip> for proper operation.

I.e. this module can

=over 

=item *

Extract jolokia-access.xml and web.xml from WAR/JAR archives

=item *

Check for the esistance of jolokia-access.xml

=item *

Update web.xml for WAR files

=back

=cut

use Data::Dumper;
use strict;

use vars qw($HAS_ARCHIVE_ZIP $GLOBAL_ERROR);

BEGIN {
    $HAS_ARCHIVE_ZIP = eval "require Archive::Zip; Archive::Zip->import(qw(:ERROR_CODES)); 1";
    if ($HAS_ARCHIVE_ZIP) {
        Archive::Zip::setErrorHandler( sub {
                                           $GLOBAL_ERROR = join " ",@_;
                                           chomp $GLOBAL_ERROR;
                                       } );
    }
}

=head1 METHODS

=over 4 

=item $handler = JMX::Jmx4Perl::Agent::Jolokia::ArtifactHandler->new(...)

Create a new handler with the following options:

  file => $file      : Path to archive to handle
  logger => $logger  : Logger to use
  meta => $meta      : Jolokia-Meta handler to extract the type of an archive

=cut

sub new { 
    my $class = shift;
    my %args = @_;
    my $file = $args{file};
    my $self = { file => $file, logger => $args{logger}, meta => $args{meta}};
    bless $self,(ref($class) || $class);
    $self->_fatal("No Archive::Zip found. Please install it for handling Jolokia archives.") unless $HAS_ARCHIVE_ZIP;
    $self->_fatal("No file given") unless $file;
    $self->_fatal("No such file $file") unless -e $file;
    return $self;
}


=item $info = $handler->info() 

Extract information about an archive. Return value is a has with the following 
keys:

  "version"      Agent's version
  "type"         Agent type (war, osgi, osgi-bundle, mule, jdk6)
  "artifactId"   Maven artifact id 
  "groupId"      Maven group Id 

=cut

sub info {
    my $self = shift;
    my $file = $self->{file};
    my $jar = $self->_read_archive();
    my @props = $jar->membersMatching('META-INF/maven/org.jolokia/.*?/pom.properties');
    $self->_fatal("Cannot extract pom.properties from $file") unless @props;
    for my $prop (@props) {
        my ($content,$status) = $prop->contents;
        $self->_fatal("Cannot extract pom.properties: ",$GLOBAL_ERROR) unless $status eq AZ_OK();
        my $ret = {};
        for my $l (split /\n/,$content) {
            next if $l =~ /^\s*#/;
            my ($k,$v) = split /=/,$l,2;
            $ret->{$k} = $v;
        }
        $self->_fatal("$file is not a Jolokia archive") unless $ret->{groupId} eq "org.jolokia" ;
        my $type;
        if ($self->{meta}->initialized()) {
            $type = $self->{meta}->extract_type($ret->{artifactId});
        } else {
            $type = $self->_detect_type_by_heuristic($ret->{artifactId});
        }
        if ($type) {
            $ret->{type} = $type;
            return $ret;
        }
    }
    return {};
}

=item $handler->add_policy($policy)

Add or update the policy given as string to this archive. Dependening on
whether it is a WAR or another agent, it is put into the proper place

For "war" agents, this is F<WEB-INF/classes/jolokia-access.xml>, for all others
it is F</jolokia-access.xml>

=cut 

sub add_policy {
    my $self = shift;
    my $policy = shift;
    my $file = $self->{file};
    $self->_fatal("No such file $policy") unless -e $policy;
    
    my $jar = $self->_read_archive();
    my $path = $self->_policy_path;
    
    my $existing = $jar->removeMember($path);
    my $res = $jar->addFile($policy,$path);
    $self->_fatal("Cannot add $policy to $file as ",$path,": ",$GLOBAL_ERROR) unless $res;
    my $status = $jar->overwrite();
    $self->_fatal("Cannot write $file: ",$GLOBAL_ERROR) unless $status eq AZ_OK();
    $self->_info($existing ? "Replacing existing policy " : "Adding policy ","[em]",$path,"[/em]",$existing ? " in " : " to ","[em]",$file,"[/em]");
}

=item $handler->remove_policy()

Remove a policy file (no-op, when no policy is present)

=cut

sub remove_policy {
    my $self = shift;

    my $file = $self->{file};
    
    my $jar = $self->_read_archive();
    my $path = $self->_policy_path;
    
    my $existing = $jar->removeMember($path);
    if ($existing) {
        my $status = $jar->overwrite();
        $self->_fatal("Cannot write $file: ",$GLOBAL_ERROR) unless $status eq AZ_OK();    
        $self->_info("Removing policy","[em]",$path,"[/em]"," in ","[em]",$file,"[/em]");
    } else {
        $self->_info("No policy found, leaving ","[em]",$file,"[/em]"," untouched.");
    }
}

=item $handler->has_policy()

Returns true (i.e. the path to the policy file) if a policy file is contained,
C<undef> otherwise.

=cut

sub has_policy {
    my $self = shift;

    my $jar = $self->_read_archive();
    my $path = $self->_policy_path;
    return $jar->memberNamed($path) ? $path : undef;
}

=item $handler->get_policy()

Get the policy file as string or C<undef> if no policy is contained. 

=cut

sub get_policy {
    my $self = shift;

    my $jar = $self->_read_archive();
    my $path = $self->_policy_path;
    return $jar->contents($path);
}

=item $handler->extract_webxml()

Extract F<web.xml> from WAR agents, for other types, a fatal error is
raised. Return value is a string containing the web.xml.

=cut

sub extract_webxml {
    my $self = shift;
    my $type = $self->type;
    $self->_fatal("web.xml can only be read from 'war' archives (not '",$type,"')") unless $type eq "war";

    my $jar = $self->_read_archive();
    return $jar->contents("WEB-INF/web.xml");
}

=item $handler->update_webxml($webxml)

Update F<web.xml> in WAR agents, for other types, a fatal error is
raised. Return value is a string containing the web.xml. C<$webxml> is the
descriptor as a string.

=cut

sub update_webxml {
    my $self = shift;
    my $webxml = shift;
    my $type = $self->type;
    $self->_fatal("web.xml can only be updated in 'war' archives (not '",$type,"')") unless $type eq "war";

    my $jar = $self->_read_archive();
    $jar->removeMember("WEB-INF/web.xml");
    my $res = $jar->addString($webxml,"WEB-INF/web.xml");
    $self->_fatal("Cannot update WEB-INF/web.xml: ",$GLOBAL_ERROR) unless $res;
        my $status = $jar->overwrite();
    $self->_fatal("Cannot write ",$self->{file},": ",$GLOBAL_ERROR) unless $status eq AZ_OK();
    $self->_info("Updated ","[em]","web.xml","[/em]"," for ",$self->{file});
}

=item $handler->type()

Return the agent's type, which is one of "war", "osgi", "osgi-bundle", "mule"
or "jdk6"

=cut

sub type {
    my $self = shift;
    my $info = $self->info;
    return $info->{type};
}

=back

=cut

# ========================================================================

sub _detect_type_by_heuristic {
    my $self = shift;
    my $artifact_id = shift;
    return {
            "jolokia-osgi" => "osgi",
            "jolokia-mule" => "mule",
            "jolokia-osgi-bundle" => "osgi-bundle",
            "jolokia-jvm-jdk6"  => "jdk6",
            "jolokia-jvm" => "jvm", 
            "jolokia-war" => "war"
           }->{$artifact_id};
}

sub _read_archive {
    my $self = shift;
    my $file = $self->{file};
    my $jar = new Archive::Zip();
    my $status = $jar->read($file);
    $self->_fatal("Cannot read content of $file: ",$GLOBAL_ERROR) unless $status eq AZ_OK();
    return $jar;
}


sub _policy_path {
    my $self = shift;
    return ($self->type eq "war" ? "WEB-INF/classes/" : "") . "jolokia-access.xml";
}


sub _fatal {
    my $self = shift;
    $self->{logger}->error(@_);
    die "\n";
}

sub _info {
    my $self = shift;
    $self->{logger}->info(@_);
}

=head1 LICENSE

This file is part of jmx4perl.
Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
The Free Software Foundation, either version 2 of the License, or
(at your option) any later version.
 
jmx4perl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License
along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 AUTHOR

roland@cpan.org

=cut

1;

