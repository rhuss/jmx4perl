#!/usr/bin/perl 
package JMX::Jmx4Perl::Agent::Manager::ArtifactHandler;

=head1 NAME

JMX::Jmx4Perl::Agent::ArtifactHandler - Handler for extracting and manipulating
Jolokia artifacts

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


sub info {
    my $self = shift;
    my $file = $self->{file};
    my $jar = new Archive::Zip();
    my $status = $jar->read($file);
    $self->_fatal("Cannot read content of $file: ",$GLOBAL_ERROR) unless $status eq AZ_OK();
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
        my $type = $self->{meta}->extract_type($ret->{artifactId});
        if ($type) {
            $ret->{type} = $type;
            return $ret;
        }
    }
    return {};
}

sub _fatal {
    my $self = shift;
    $self->{logger}->error(@_);
    die "\n";
}

1;
