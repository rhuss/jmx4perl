#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Jolokia::Meta;

use JMX::Jmx4Perl::Agent::Jolokia::DownloadAgent;
use JMX::Jmx4Perl::Agent::Jolokia::Logger;
use JMX::Jmx4Perl::Agent::Jolokia::Verifier;
use JSON;
use Data::Dumper;
use base qw(LWP::UserAgent);
use strict;

my $JOLOKIA_META_URL = "http://www.jolokia.org/jolokia.meta";

=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::Meta - Fetches, caches and parses Meta data from
www.jolokia.org

=head1 DESCRIPTION

This class is responsible for fetching meta data about available agents from
Jolokia. It knows how to parse those meta data and caches it for subsequent
usage in the local file system. 

=head1 METHODS

=over 4 

=item $meta = JMX::Jmx4Perl::Agent::Jolokia::Meta->new(....)

Create a new meta object which handles downloading of Jolokia meta information
and caching this data.

=cut 

sub new {
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    # Dummy logging if none is provided
    $self->{logger} = new JMX::Jmx4Perl::Agent::Jolokia::Logger::None unless $self->{logger};
    $self->{verifier} = new JMX::Jmx4Perl::Agent::Jolokia::Verifier(logger => $self->{logger},ua_config => $self->{ua_config});
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
    $force = $self->{force_load} unless defined($force);
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

=item $meta->initialized()

Returns C<true> if the meta data has been initialized, either by loading it or 
by using a cached data. If false the data can be loaded via L<load>

=cut 

sub initialized {
    my $self = shift;
    return defined($self->{_meta});
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


=item $jolokia_version = $meta->latest_matching_version($jmx4perl_version)

Get the latest matching Jolokia version for a given Jmx4Perl version

=cut

sub latest_matching_version {
    my $self = shift;
    my $jmx4perl_version = shift;
    # Iterate over all existing versions, starting from the newest one, 
    # and return the first matching
    my $version_info = $self->get("versions");
    for my $v (sort { $self->compare_versions($b,$a) } grep { $_ !~ /-SNAPSHOT$/ } keys %$version_info) {
        my $range = $version_info->{$v}->{jmx4perl};
        if ($range) {
            my $match = $self->_check_version($jmx4perl_version,$range);
            #print "Match: $match for $range (j4p: $jmx4perl_version)\n";
            return $v if $match;
        }
    }
    return undef;
}

# Compare two version which can contain one, two or more digits. Returns <0,0 or
# >0 if the first version is smaller, equal or larger than the second version.
# It doesn't take into account snapshot 
sub compare_versions {
    my $self = shift;
    my @first = _split_version(shift);
    my @second = _split_version(shift);
    my $len = $#first < $#second ? $#first : $#second;
    for my $i (0 ... $len) {
        next if $first[$i] == $second[$i];
        return $first[$i] - $second[$i];
    }
    return $#first - $#second;
}

sub _split_version {
    my $v = shift;
    $v =~ s/-.*$//;
    return split /\./,$v;
}

sub _check_version {
    my $self = shift;    
    my $jmx4perl_version = shift;
    my $range = shift;
    
    my ($l,$l_v,$u_v,$u) = ($1,$2,$3,$4) if $range =~ /^\s*([\[\(])\s*([\d\.]+)\s*,\s*([\d\.]+)\s*([\)\]])\s*$/;
    if ($l_v) {
        my $cond = "\$a " . ($l eq "[" ? ">=" : ">").  $l_v . " && \$a" . ($u eq "]" ? "<=" : "<") . $u_v;
        my $a = $jmx4perl_version;
        return eval $cond;
    }
    return undef;    
}

=item $meta->versions_compatible($jmx4perl_version,$jolokia_version)

Check, whether the Jolokia and Jmx4Perl versions are compaptible, i.e.
whether Jmx4Perl with the given version can interoperate with the given
Jolokia version

=cut

sub versions_compatible {
    my $self = shift;
    my $jmx4perl_version = shift;
    my $jolokia_version = shift;

    my $version_info = $self->get("versions");
    my $range = $version_info->{$jolokia_version}->{jmx4perl};
    if ($range) {
        return $self->_check_version($jmx4perl_version,$range);
    } else {
        return undef;
    }
}

=item $type = $meta->extract_type($artifact_name)

Extract the type for a given artifactId

=cut

sub extract_type { 
    my $self = shift;
    my $artifact = shift;
    my $mapping = $self->get("mapping");
    for my $k (keys %$mapping) {
        return $k if $mapping->{$k}->[0] eq $artifact;
    }
    return undef;
}

=item $meta->template_url($template_name,$version)

Download a template with the given name. The download URL is looked up 
in the meta data. If a version is given, the template for this specific
version is returned (if present, if not the default template is returned). 
If no version is given, the default template is returned. The downloaded
template is verified as any other downloaded artifact. 

The template is returned as a string.

=cut

sub template_url {
    my $self = shift;
    my $template = shift;
    my $version = shift;
    
    my $url;
    if ($version)  {
        my $version_info = $self->get("versions");
        my $v_data = $version_info->{$version};
        $self->_fatal("Cannot load template $template for version $version since $version is unknown") 
          unless $v_data;
        my $templs = $v_data->{templates};
        if ($templs) {
            $url = $templs->{$template};
        }
    }
    unless ($url) {
        my $templs = $self->get("templates");
        $self->_fatal("No templates defined in jolokia.meta") unless $templs;
        $url = $templs->{$template};
    }
    return $url;
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

    my $ua = new JMX::Jmx4Perl::Agent::Jolokia::DownloadAgent($self->{ua_config});
    my $response = $ua->get($JOLOKIA_META_URL);
    if ($response->is_success) {
        my $content = $response->decoded_content;  # or whatever
        $self->{verifier}->verify(ua_config => $self->{ua_config}, logger => $self->{logger},
                                  url => $JOLOKIA_META_URL, data => $content);
        return from_json($content, {utf8 => 1});
    }
    else {
        # Log an error, but do not exit ...
        $self->{logger}->error("Cannot load Jolokia Meta-Data from $JOLOKIA_META_URL: " . $response->status_line);
        return undef;
    }
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
            'snapshots-repositories' => [
                             "http://labs.consol.de/maven/snapshots-repository"
                            ],            
            versions => {
                         "0.90-SNAPSHOT" => { jmx4perl => "[0.90,1.0)" },
                         "0.83" => { jmx4perl => "[0.73,1.0)" },
                         "0.82" => { jmx4perl => "[0.73,1.0)" } ,
                         "0.81" => { jmx4perl => "[0.73,1.0)" } ,
                        },
            mapping => {
                        "war" => [ "jolokia-war", "jolokia-war-%v.war", "jolokia.war" ],
                        "osgi" => [ "jolokia-osgi", "jolokia-osgi-%v.jar", "jolokia.jar" ],
                        "osgi-bundle" => [ "jolokia-osgi-bundle", "jolokia-osgi-bundle-%v.jar", "jolokia-bundle.jar" ],
                        "mule" => [ "jolokia-mule", "jolokia-mule-%v.jar", "jolokia-mule.jar" ],
                        "jdk6" => [ "jolokia-jvm-jdk6", "jolokia-jvm-jdk6-%v-agent.jar", "jolokia.jar" ]
                       },
            templates => {
                          "jolokia-access.xml" => "http://www.jolokia.org/templates/jolokia-access.xml"
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
