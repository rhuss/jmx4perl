#!/usr/bin/perl

# Helper package for dealing with meta data from 
# www.jolokia.org

package JMX::Jmx4Perl::Agent::Manager::JolokiaMeta;

use JMX::Jmx4Perl::Agent::Manager::DownloadAgent;
use JMX::Jmx4Perl::Agent::Manager::Logger;
use JMX::Jmx4Perl::Agent::Manager::Verifier;
use JSON;
use Data::Dumper;
use base qw(LWP::UserAgent);
use strict;

my $JOLOKIA_META_URL = "http://www.jolokia.org/jolokia.meta";

=head1 NAME

JMX::Jmx4Perl::Agent::Manager::JolokiaMeta - Fetches, caches and parses Meta data from
www.jolokia.org

=head1 DESCRIPTION

This class is responsible for fetching meta data about available agents from
Jolokia. It knows how to parse those meta data and caches it for subsequent
usage in the local file system. 

=head1 METHODS

=over 4 

=item $meta = JMX::Jmx4Perl::Agent::Manager::JolokiaMeta->new(....)

Create a new meta object which handles downloading of Jolokia meta information
and caching this data.

=cut 

sub new {
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    # Dummy logging if none is provided
    $self->{logger} = new JMX::Jmx4Perl::Agent::Manager::Logger::None unless $self->{logger};
    $self->{verifier} = new JMX::Jmx4Perl::Agent::Manager::Verifier(logger => $self->{logger},ua_config => $self->{ua_config});
    return bless $self,(ref($class) || $class);
}

=item $meta->load($force)

Load the meta data from the server or retrieve it from the cache. The data is
taken from the cache, if it is no older than $self->{cache_interval} seconds. 
If $force is given and true, the data is always fetched fresh from the server. 

This method return $self so that it can be used for chaining. Any error or
progress infos are given through to the C<log_handler> provided during
construction time. This method will return C<undef> if the data can't be
loaded. 

=cut 

sub load {
    my ($self,$force) = @_;
    my $meta_json;
    my $cached = undef;
    if (!$force) {
        $meta_json = $self->_from_cache;
        $cached = 1 if $meta_json;
    }
    $meta_json = $self->_load_from_server unless $meta_json; # Throws an error
                                                             # if it can't be
                                                             # loaded 
    return undef unless $meta_json;
    $self->_to_cache($meta_json) unless $cached;
    $self->{_meta} = $meta_json;
    return $self;
}

=item $value = $meta->get($key)

Get a value from the meta data. 

=cut

sub get { 
    my $self = shift;
    my $key = shift;
    $self->_fatal("No yet loaded") unless $self->{_meta};
    return $self->{_meta}->{$key};    
}

=back

=cut

# ===================================================================================

# Fetch from cache, but only if the cache file is older than $cache_interval
# seconds back in time
sub _from_cache {
    my $self = shift;
    my $cache_interval = $self->{cache_interval} || 12 * 60 * 60; # 12h by default
    my $cache_file = $self->{cache_file} || $ENV{HOME} . "/.jolokia_meta";
    my $mtime = (stat($cache_file))[9];    
    if ($mtime && $mtime >= time - $cache_interval) {
        if (!open(F,$cache_file)) {
            $self->_error("Cannot open $cache_file: $!");
            return undef;
        }
        my $ret = join "",<F>;
        close F;        
        $self->_debug("Loaded Jolokia meta data from cache");
        return from_json($ret,{utf8 => 1});
    } else {
        return undef;
    }
}

# Store to cache
sub _to_cache {
    my $self = shift;
    my $meta = shift;
    my $cache_file = $self->{cache_file} || $ENV{HOME} . "/.jolokia_meta";
    if (!open(F,">$cache_file")) {
        $self->_error("Cannot save $cache_file: $!");
        return;
    }
    print F to_json($meta,{utf8 => 1,pretty => 1});
    close F;
}

# Load from server
sub _load_from_server {
    my $self = shift;
     
    # Create sample meta-data
    return $self->_example_meta if ($ENV{USE_SAMPLE_JOLOKIA_META});

    # Load with HTTP-Client, hardcoded for now
    $self->_info("Loading Jolokia meta data from $JOLOKIA_META_URL");                                    

    my $ua = new JMX::Jmx4Perl::Agent::Manager::DownloadAgent($self->{ua_config});
    my $response = $ua->get($JOLOKIA_META_URL);
    if ($response->is_success) {
        my $content = $response->decoded_content;  # or whatever
        $self->{verifier}->verify(ua_config => $self->{ua_config}, logger => $self->{logger},
                                  url => $JOLOKIA_META_URL, data => $content);
        return from_json($content, {utf8 => 1});
    }
    else {
        $self->_fatal("Cannot load Jolokia Meta-Data from $JOLOKIA_META_URL: " . $response->status_line);
    }
}

# Get the latest matching Jolokia version for a given Jmx4Perl version
sub latest_matching_version {
    my $self = shift;
    my $jmx4perl_version = shift;
    # Iterate over all existing versions, starting from the newest one, 
    # and return the first matching
    my $version_info = $self->get("versions");
    for my $v (sort { $b <=> $a } keys %$version_info) {
        my $range = $version_info->{$v}->{jmx4perl};
        if ($range) {
            my ($l,$l_v,$u_v,$u) = ($1,$2,$3,$4) if $range =~ /^\s*([\[\(])\s*([\d\.]+)\s*,\s*([\d\.]+)\s*([\)\]])\s*$/;
            if ($l_v) {
                my $cond = "\$a " . ($l eq "[" ? ">=" : ">").  $l_v . " && \$a" . ($u eq "]" ? "<=" : "<") . $u_v;
                my $a = $jmx4perl_version;
                if (eval $cond) { 
                    return $v;
                }
            }
        }
    }
    return undef;
}

# Check, whether the Jolokia and Jmx4Perl versions match
sub versions_compatible {
    my $self = shift;
    my $jmx4perl_version = shift;
    my $jolokia_version = shift;

    return 1;
}

# Extract the type for a given artifactId
sub extract_type { 
    my $self = shift;
    my $artifact = shift;
    my $mapping = $self->get("mapping");
    for my $k (keys %$mapping) {
        return $k if $mapping->{$k}->[0] eq $artifact;
    }
    return undef;
}

# Do something with errors and info messages

sub _debug {
    shift->{logger}->debug(@_);
}

sub _error {
    my $self = shift;
    $self->{logger}->error(@_);
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

# Sample meta data, also used for creating site meta data.
sub _example_meta {
    return {
            repositories => [
                             "http://labs.consol.de/maven/repository"
                            ],            
            versions => {
                         "0.83" => { jmx4perl => "[0.73,1.0)" } ,
                         "0.82" => { jmx4perl => "[0.73,1.0)" } ,
                         "0.81" => { jmx4perl => "[0.73,1.0)" } ,
                        },
            mapping => {
                        "war" => [ "jolokia-war", "jolokia-war-%v.war", "jolokia.war" ],
                        "osgi" => [ "jolokia-osgi", "jolokia-osgi-%v.jar", "jolokia.jar" ],
                       "osgi-bundle" => [ "jolokia-osgi-bundle", "jolokia-osgi-bundle-%v.jar", "jolokia-bundle.jar" ],
                        "mule" => [ "jolokia-mule", "jolokia-mule-%v.jar", "jolokia-mule.jar" ],
                        "jdk6" => [ "jolokia-jvm-jdk6", "jolokia-jvm-jdk6-%v-agent.jar", "jolokia.jar" ]
                       }
           };
}


1; 

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
