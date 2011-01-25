#!/usr/bin/perl

# Helper package for dealing with meta data from 
# www.jolokia.org

package JMX::Jmx4Perl::Agent::Manager::JolokiaMeta;
use JSON;
use Data::Dumper;
use base qw(LWP::UserAgent);

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
    # Dummy logging if not provided
    $self->{log_handler} = { 
                            error => sub {},
                            info => sub {},
                           } 
      unless $self->{log_handler};
    bless $self,(ref($class) || $class);
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
    die "No yet loaded" unless $self->{_meta};
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
    # Load with HTTP-Client, hardcoded for now
    print "Load from server\n";
    return {
            repositories => [
                             "http://labs.consol.de/maven/repository"
                            ],            
            versions => {
                         "0.82" => { signed => 0 } ,
                         "0.81" => { signed => 0 } ,
                         "0.80" => { signed => 0 }                         
                        } 
           };
}

# Do something with errors and info messages
sub _error {
    my $self = shift;
    &{$self->{log_handler}->{error}}(@_);
}

sub _info {
    &{$self->{log_handler}->{info}}(@_);
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
