#!/usr/bin/perl

package JMX::Jmx4Perl::Product::BaseHandler;

use strict;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Alias;
use Carp qw(croak);
use Data::Dumper;

=head1 NAME

JMX::Jmx4Perl::Product::BaseHandler - Base package for product specific handler 

=head1 DESCRIPTION

This base class is used for specific L<JMX::Jmx4Perl::Product> in order
to provide some common functionality. Extends this package if you want to hook
in your own product handler. Any module below
C<JMX::Jmx4Perl::Product::> will be automatically picked up by
L<JMX::Jmx4Perl>.

=head1 METHODS

=over 

=item $handler = JMX::Jmx4Perl::Product::MyHandler->new($jmx4perl);

Constructor which requires a L<JMX::Jmx4Perl> object as single argument. If you
overwrite this method in a subclass, dont forget to call C<SUPER::new>, but
normally there is little need for overwritting new.

=cut


sub new {
    my $class = shift;
    my $jmx4perl = shift || croak "No associated JMX::Jmx4Perl given";
    my $self = { 
                jmx4perl => $jmx4perl
               };
    bless $self,(ref($class) || $class);
    $self->{aliases} = $self->init_aliases();
    if ($self->{aliases} && $self->{aliases}->{attributes} 
        && !$self->{aliases}->{attributes}->{SERVER_VERSION}) {
        $self->{aliases}->{attributes}->{SERVER_VERSION} = sub { 
            # A little bit nasty, I know, but we have to rebuild
            # the response since it is burried to deep into the
            # version fetching mechanism. Still thinking about 
            # a cleaner solution .....
            return new JMX::Jmx4Perl::Response
              (
               value => shift->version(),
               status => 200,
               timestamp => time
              )
        };
    }
    return $self;
}

=item $id = $handler->id()

Return the id of this handler, which must be unique among all handlers. This
method is abstract and must be overwritten by a subclass

=cut 

sub id { 
    croak "Must be overwritten to return a name";
}

=item $id = $handler->name()

Return this handler's name. This method returns by default the id, but can 
be overwritten by a subclass to provide something more descriptive.

=cut 

sub name { 
    return shift->id;
}

=item $vendor = $handler->vendor()

Get the vendor for this product. If the handler support JSR 77 this is
extracted directly from the JSR 77 information. Otherwise, as handler is
recommended to detect the vendor on its own with a method C<_try_vendor>. Note, that he
shoudl query the server for this information and return C<undef> if it could
not be extracted from there. The default implementation of L</"autodetect">
relies on the information fetched here.

=cut

sub vendor {
    return shift->_version_or_vendor("vendor");
}

=item $version = $handler->version() 

Get the version of the underlying application server or return C<undef> if the
version can not be determined. Please note, that this method can be only called
after autodetect() has been called since this call is normally used to fill in
that version number.

=cut

sub version {
    return shift->_version_or_vendor("version");
}

sub _version_or_vendor {
    my $self = shift;
    my $what = shift;
    my $transform = shift;
    die "Internal Error: '$what' must be either 'version' or 'vendor'" 
      if $what ne "version" && $what ne "vendor";
    
    if (!defined $self->{$what}) {
        if ($self->can("_try_$what")) {
            my $val;
            eval "\$self->_try_$what";
            die $@ if $@;
        } elsif ($self->jsr77) {
            $self->{$what} = $self->_server_info_from_jsr77("server" . (uc substr($what,0,1)) . substr($what,1));
            $self->{"original_" . $what} = $self->{$what};
            if ($transform && $self->{$what}) {
                if (ref($transform) eq "CODE") {
                    $self->{$what} = &{$transform}($self->{$what});
                } elsif (ref($transform) eq "Regexp") {
                    $self->{$what} = $1 if $self->{$what} =~ $transform;                    
                }
            }
            $self->{$what} ||=  "" # Set to empty string if not found
        } else {
            die "Internal error: Not a JSR77 Handler and no _try_$what method";
        }        
    }
    return $self->{$what};    
}

# Return the original version, which is not transformed. This contains
# often the application info as well. This returns a subroutine, suitable
# for usie in autodetect_pattern
sub original_version_sub {
    return sub {
        my $self = shift;
        $self->version();
        return $self->{"original_version"};
    }
}

=item $is_product = $handler->autodetect()

Return true, if the appserver to which the given L<JMX::Jmx4Perl> (at
construction time) object is connected can be handled by this product
handler. If this module detects that it definitely can not handle this
application server, it returnd false. If an error occurs during autodectection,
this method should return C<undef>.

=cut

sub autodetect {
    my $self = shift;
    my ($what,$pattern) = $self->autodetect_pattern;
    if ($what) {
        #print "W: $what P: $pattern\n";
        my $val;
        if (ref($what) eq "CODE") {
            $val = &{$what}($self);
        } else {
            eval "\$val = \$self->$what";
            die $@ if $@;
        }
        return 1 if ($val && (!$pattern || ref($pattern) ne "Regexp"));
        return $val =~ $pattern if ($val && $pattern);
    }
    return undef;
}

=item ($what,$pattern) = $handler->autodetect_pattern()

Method returning a pattern which is applied to the vendor or version
information provided by the L</"version"> or L</"vendor"> in order to detect,
whether this handler matches the server queried. This pattern is used in the
default implementation of C<autodetect> to check for a specific product. By
default, this method returns (C<undef>,C<undef>) which implies, that autodetect
for this handler returns false. Override this with the pattern matching the
specific product to detect.

=cut

sub autodetect_pattern {
    return (undef,undef);
}

=item $order = $handler->order()

Return some hint for the ordering of product handlers in the autodetection
chain. This default implementation returns C<undef>, which implies no specific
ordering. If a subclass returns an negative integer it will be put in front of
the chain, if it returns a positive integer it will be put at the end of the
chain, in ascending order, respectively. E.g for the autodetection chain, the
ordering index of the included handlers looks like

  -10,-5,-3,-1,undef,undef,undef,undef,undef,2,3,10000

The ordering index of the fallback handler (which always fire) is 1000, so it
doesn't make sense to return a higher index for a custom producthandler.

=cut

sub order { 
    return undef;
}

=item $can_jsr77 = $handler->jsr77()

Return true if the app server represented by this handler is an implementation
of JSR77, which provides a well defined way how to access deployed applications
and other stuff on a JEE Server. I.e. it defines how MBean representing this
information has to be named. This base class returns false, but this method can
be overwritten by a subclass.

=cut

sub jsr77 {
    return undef;
}

=item ($mbean,$attribute,$path) = $self->alias($alias)

=item ($mbean,$operation) = $self->alias($alias)

Return the mbean and attribute name for an registered attribute alias, for an
operation alias, this method returns the mbean and the operation name. A
subclass should call this parent method if it doesn't know about a specific
alias, since JVM MXBeans are aliased here.

Returns undef if this product handler doesn't know about the provided alias. 

=cut 

sub alias {
    my ($self,$alias_or_name) = @_;
    my $alias;
    if (UNIVERSAL::isa($alias_or_name,"JMX::Jmx4Perl::Alias::Object")) {
        $alias = $alias_or_name;
    } else {
        $alias = JMX::Jmx4Perl::Alias->by_name($alias_or_name) 
          || croak "No alias $alias_or_name known";
    }
    my $resolved_ref = $self->resolve_alias($alias);
    # It has been defined by the handler, but set to 0. So it doesn't 
    # support this particular alias
    return undef if (defined($resolved_ref) && !$resolved_ref);
    # If the handler doesn't define the ref (so it's undef),
    # use the default
    my $aliasref =  $resolved_ref || $alias->default();
    # If there is no default, then there is no support, too.
    return undef unless defined($aliasref);

    return $aliasref if (ref($aliasref) eq "CODE"); # return coderefs directly
    croak "Internal: $self doesn't resolve $alias to an arrayref" if ref($aliasref) ne "ARRAY";
    if (ref($aliasref->[0]) eq "CODE") {
        # Resolve dynamically if required
        $aliasref = &{$aliasref->[0]}($self);
        croak "Internal: $self doesn't resolve $alias to an arrayref" if ref($aliasref) ne "ARRAY";
    }
    return $aliasref ? @$aliasref : undef;
}

=item $description = $self->info()

Get a textual description of the product handler. By default, it prints
out the id, the version and well known properties known by the Java VM

=cut

sub info {
    my $self = shift;
    my $verbose = shift;

    my $ret = "";
    $ret .= $self->server_info($verbose);
    $ret .= "-" x 80 . "\n";
    $ret .= $self->jvm_info($verbose);    
}


# Examines internal alias hash in order to return handler specific aliases
# Can be overwritten if something more esoteric is required
sub resolve_alias {
    my $self = shift;
    my $alias = shift;
    croak "Not an alias object " unless (UNIVERSAL::isa($alias,"JMX::Jmx4Perl::Alias::Object"));
    my $aliases = $self->{aliases}->{$alias->{type} eq "attribute" ? "attributes" : "operations"};
    return $aliases && $aliases->{$alias->{alias}};
}


=item my $aliases = $self->init_aliases()

Method used during construction of a handler for obtaining a translation map of
aliases to the real values. Each specific handler can overwrite this method to
return is own resolving map. The returned map has two top level keys:
C<attributes> and C<operations>. Below these keys are the maps for attribute
and operation aliases, respectively. These two maps have alias names as keys
(not the alias objects themselves) and a data structure for the getting to the
aliased values. This data structure can be written in three variants:

=over

=item * 

A arrayref having two or three string values for attributes describing the real
MBean's name, the attribute name and an optional path within the value. For
operations, it's an arrayref to an array with two elements: The MBean name and
the operation name.

=item * 

A arrayref to an array with a I<single> value which must be a coderef. This
subroutine is called with the handler as single argument and is expected to
return an arrayref in the form described above.

=item *

A coderef, which is executed when C<JMX::Jmx4Perl-E<gt>get_attribute()> or
C<JMX::Jmx4Perl-E<gt>execute()> is called and which is supossed to do the complete
lookup. The first argument to the subroutine is the handler which can be used
to access the L<JMX::Jmx4Perl> object. The additional argument are either the
value to set (for C<JMX::Jmx4Perl-E<gt>set_attribute()> or the operation's
arguments for C<JMX::Jmx4Perl-E<gt>execute()>. This is the most flexible way for a
handler to do anything it likes to do when an attribute value is requested or
an operation is about to be executed. You have to return a
L<JMX::Jmx4Perl::Response> object.

=back

Example : 

  sub init_aliases {
      my $self = shift;
      return {
         attributes => { 
             SERVER_ADDRESS => [ "jboss.system:type=ServerInfo", "HostAddress"],
             SERVER_VERSION => sub { 
                return shift->version();
             },
             SERVER_HOSTNAME => [ sub { return [ "jboss.system:type=ServerInfo", "HostName" ] } ]        
         },
         operations => {
             THREAD_DUMP => [ "jboss.system:type=ServerInfo", "listThreadDump"]
         }
      }
  }

Of course, you are free to overwrite C<alias> or
C<resolve_alias> on your own in order to do want you want it to do. 

This default implementation returns an empty hashref.

=cut 

sub init_aliases {
    my $self = shift;
    return {};
}


=item $has_attribute = $handler->try_attribute($jmx4perl,$property,$object,$attribute,$path)

Internal method which tries to request an attribute. If it could not be found,
it returns false. 

The first arguments C<$property> specifies an property of this object, which is
set with the value of the found attribute or C<0> if this attribute does not
exist. 

The server call is cached internally by examing C<$property>. So, never change
or set this property on this object manually.

=cut

sub try_attribute {
    my ($self,$property,$object,$attribute,$path) = @_;
    
    my $jmx4perl = $self->{jmx4perl};

    if (defined($self->{$property})) {
        return length($self->{$property});
    }
    my $request = JMX::Jmx4Perl::Request->new(READ,$object,$attribute,$path);
    my $response = $jmx4perl->request($request);
    if ($response->status == 404 || $response->status == 400) {
        $self->{$property} = "";
    } elsif ($response->is_ok) {
        $self->{$property} = $response->value;
    } else {
        croak "Error : ",$response->error_text();
    }
    return length($self->{$property});
}

=item $server_info = $handler->server_info()

Get's a textual description of the server. By default, this includes the id and
the version, but can (and should) be overidden by a subclass to contain more
specific information

=cut

sub server_info { 
    my $self = shift;
    my $jmx4perl = $self->{jmx4perl};
    my $ret = "";
    $ret .= sprintf("%-10.10s %s\n","Name:",$self->name);
    $ret .= sprintf("%-10.10s %s\n","Vendor:",$self->vendor) if $self->vendor && $self->vendor ne $self->name;
    $ret .= sprintf("%-10.10s %s\n","Version:",$self->version) if $self->version;
    return $ret;
}

=item $jvm_info = $handler->jvm_info()

Get information which is based on well known MBeans which are available for
every Virtual machine. This is a textual representation of the information. 

=cut


sub jvm_info {
    my $self = shift;
    my $verbose = shift;
    my $jmx4perl = $self->{jmx4perl};
    
    my @info = (
                "Memory" => [
                             "mem" => [ "Heap-Memory used", MEMORY_HEAP_USED ],
                             "mem" => [ "Heap-Memory alloc", MEMORY_HEAP_COMITTED ],
                             "mem" => [ "Heap-Memory max", MEMORY_HEAP_MAX ],
                             "mem" => [ "NonHeap-Memory max", MEMORY_NONHEAP_MAX ],
                            ],
                "Classes" => [
                              "nr" => [ "Classes loaded", CL_LOADED ],
                              "nr" => [ "Classes total", CL_TOTAL ]
                             ],
                "Threads" => [
                              "nr" => [ "Threads current", THREAD_COUNT ],
                              "nr" => [ "Threads peak", THREAD_COUNT_PEAK ]
                             ],
                "OS" => [
                         "str" => [ "CPU Arch", OS_INFO_ARCH ],
                         "str" => [ "CPU OS",OS_INFO_NAME,OS_INFO_VERSION],
                         "mem" => [ "Memory total",OS_MEMORY_PHYSICAL_FREE],
                         "mem" => [ "Memory free",OS_MEMORY_PHYSICAL_FREE],                
                         "mem" => [ "Swap total",OS_MEMORY_SWAP_TOTAL],                
                         "mem" => [ "Swap free",OS_MEMORY_SWAP_FREE],
                         "nr" => [ "FileDesc Open", OS_FILE_DESC_OPEN ],
                         "nr" => [ "FileDesc Max", OS_FILE_DESC_MAX ]
                        ],
                "Runtime" => [
                              "str" => [ "Name", RUNTIME_NAME ],
                              "str" => [ "JVM", RUNTIME_VM_VERSION,RUNTIME_VM_NAME,RUNTIME_VM_VENDOR ],
                              "duration" => [ "Uptime", RUNTIME_UPTIME ],
                              "time" => [ "Starttime", RUNTIME_STARTTIME ]                              
                             ]                         
               );
    my $ret = "";

    # Collect all alias and create a map with values
    my $info_map = $self->_fetch_info(\@info);
    # Prepare output
    while (@info) {
        my $titel = shift @info;
        my $e = shift @info;
        my $val = "";
        while (@$e) {
            $self->_append_info($info_map,\$val,shift @$e,shift @$e);            
        }
        if (length $val) {
            $ret .= $titel . ":\n";
            $ret .= $val;
        }
    }
    
    if ($verbose) {
        my $args = "";
        my $rt_args = $self->_get_attribute(RUNTIME_ARGUMENTS);
        if ($rt_args) {
            for my $arg (@{$rt_args}) {
                $args .= $arg . " ";
                my $i = 1;
                if (length($args) > $i * 60) {
                    $args .= "\n" . (" " x 24);
                    $i++;
                }
            }
            $ret .= sprintf("   %-20.20s %s\n","Arguments:",$args);    
        }
        my $sys_props = $self->_get_attribute(RUNTIME_SYSTEM_PROPERTIES);
        if ($sys_props) {
            $ret .= "System Properties:\n";
            if (ref($sys_props) eq "HASH") {
                $sys_props = [ values %$sys_props ];
            }
            for my $prop (@{$sys_props}) {
                $ret .= sprintf("   %-40.40s = %s\n",$prop->{key},$prop->{value});
            }
        }
    }
    return $ret;
}

# Bulk fetch of alias information
# Return: Map with aliases as keys and response values as values
sub _fetch_info {
    my $self = shift;
    my $info = shift;
    my $jmx4perl = $self->{jmx4perl};
    my @reqs = ();
    my @aliases = ();
    my $info_map = {};
    for (my $i=1; $i < @$info; $i += 2) {
        my $attr_list = $info->[$i];
        for (my $j=1;$j < @$attr_list;$j += 2) {
            my $alias_list = $attr_list->[$j];
            for (my $k=1;$k < @$alias_list;$k++) {
                my $alias = $alias_list->[$k];                
                my @args = $jmx4perl->resolve_alias($alias);
                next unless $args[0];
                push @reqs,new JMX::Jmx4Perl::Request(READ,@args);
                push @aliases,$alias;
            }
        }
    }
    my @resps = $jmx4perl->request(@reqs);
    #print Dumper(\@resps);
    foreach my $resp (@resps) {
        my $alias = shift @aliases;
        if ($resp->{status} == 200) {
            $info_map->{$alias} = $resp->{value};
        }
    }
    return $info_map;
}

# Fetch version and vendor from jrs77
sub _server_info_from_jsr77 {
    my $self = shift;
    my $info = shift;
    my $jmx = $self->{jmx4perl};

    my $servers = $jmx->search("*:j2eeType=J2EEServer,*");
    return "" if (!$servers || !@$servers);
    
    # Take first server and lookup its version
    return $jmx->get_attribute($servers->[0],$info);
}


sub _append_info {
    my $self = shift;
    my $info_map = shift;
    my $r = shift;
    my $type = shift;
    my $content = shift;
    my $label = shift @$content;
    my $value = $info_map->{shift @$content};
    return unless defined($value);
    if ($type eq "mem") {
        $value = int($value/(1024*1024)) . " MB";
    } elsif ($type eq "str" && @$content) {
        while (@$content) {
            $value .= " " . $info_map->{shift @$content};
        }
    } elsif ($type eq "duration") {
        $value = &_format_duration($value);
    } elsif ($type eq "time") {
        $value = scalar(localtime($value/1000));
    }
    $$r .= sprintf("   %-20.20s: %s\n",$label,$value);
}

sub _get_attribute { 
    my $self = shift;
    
    my $jmx4perl = $self->{jmx4perl};
    my @args = $jmx4perl->resolve_alias(shift);
    return undef unless $args[0];
    my $request = new JMX::Jmx4Perl::Request(READ,@args);
    my $response = $jmx4perl->request($request);
    return undef if $response->status == 404;     # Ignore attributes not found
    return $response->value if $response->is_ok;
    die "Error fetching attribute ","@_",": ",$response->error_text;
}

sub _format_duration {
    my $millis = shift;
    my $total = int($millis/1000);
    my $days = int($total/(60*60*24));
    $total -= $days * 60 * 60 * 24;
    my $hours = int($total/(60*60));
    $total -= $hours * 60 * 60;
    my $minutes = int($total/60);
    $total -= $minutes * 60;
    my $seconds = $total;
    my $ret = "";
    $ret .= "$days d, " if $days;
    $ret .= "$hours h, " if $hours;
    $ret .= "$minutes m, " if $minutes;
    $ret .= "$seconds s" if $seconds;
    return $ret;    
}



=back

=head1 LICENSE

This file is part of jmx4perl.

Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
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
