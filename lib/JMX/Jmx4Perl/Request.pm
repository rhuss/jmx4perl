#!/usr/bin/perl

=head1 NAME

JMX::Jmx4Perl::Request - A jmx4perl request 

=head1 SYNOPSIS

  $req = JMX::Jmx4Perl::Request->new(READ,$mbean,$attribute);

=head1 DESCRIPTION

A L<JMX::Jmx4Perl::Request> encapsulates a request for various operational
types. 

The following attributes are available:

=over

=item mbean

Name of the targetted mbean in its canonical format. 

=item type

Type of request, which should be one of the constants 

=over

=item READ

Get the value of a attribute

=item WRITE

Write an attribute

=item EXEC

Execute an JMX operation 

=item LIST

List all MBeans available

=item SEARCH

Search for MBeans

=item REGISTER_NOTIFICATION

Register for a JMX notification (not supported yet)

=item REMOVE_NOTIFICATION

Remove a JMX notification (not supported yet)

=back

=item attribute

If type is C<READ> or C<WRITE> this specifies the requested
attribute

=item value

For C<WRITE> this specifies the value to set

=item arguments

List of arguments of C<EXEC> operations

=item path

This optional parameter can be used to specify a nested value in an complex
mbean attribute or nested return value from a JMX operation. For example, the
MBean C<java.lang:type=Memory>'s attribute C<HeapMemoryUsage> is a complex
value, which looks in the JSON representation like

 "value":{"init":0,"max":518979584,"committed":41381888,"used":33442568}

So, to fetch the C<"used"> value only, specify C<used> as path within the
request. You can access deeper nested values by building up a path with "/" as
separator. This looks a bit like a simplified form of XPath.

=item maxDepth, maxObjects, maxCollectionSize, ignoreErrors

With these number you can restrict the size of the JSON structure
returned. C<maxDepth> gives the maximum nesting level of the JSON
object,C<maxObjects> returns the maximum number of objects to be returned in
total and C<maxCollectionSize> restrict the number of all arrays and
collections (maps, lists) in the answer. Note, that you should use this
restrictions if you are doing massive bulk operations. C<ignoreErrors> is
useful for read requests with multiple attributes to skip errors while reading
attribute values on the errors side (the error text will be set as value).

=item target

If given, the request is processed by the agent in proxy mode, i.e. it will
proxy to another server exposing via a JSR-160 connector. C<target> is a hash
which contains information how to reach the target service via the proxy. This
hash knows the following keys:

=over 

=item url

JMX service URL as specified in JSR-160 pointing to the target server. 

=item env

Further context information which is another hash.

=back

=back 

=head1 METHODS

=over 

=cut

package JMX::Jmx4Perl::Request;

use strict;
use vars qw(@EXPORT);
use Carp;
use Data::Dumper;

use base qw(Exporter);
@EXPORT = (
           "READ","WRITE","EXEC","LIST", "SEARCH",
           "REGNOTIF","REMNOTIF", "VERSION"
          );

use constant READ => "read";
use constant WRITE => "write";
use constant EXEC => "exec";
use constant LIST => "list";
use constant SEARCH => "search";
use constant REGNOTIF => "regnotif";
use constant REMNOTIF => "remnotif";
use constant VERSION => "version";

my $TYPES = 
{ map { $_ => 1 } (READ, WRITE, EXEC, LIST, SEARCH,
                   REGNOTIF, REMNOTIF, VERSION) };

=item  $req = new JMX::Jmx4Perl::Request(....);

 $req = new JMX::Jmx4Perl::Request(READ,$mbean,$attribute,$path, { ... options ... } );
 $req = new JMX::Jmx4Perl::Request(READ,{ mbean => $mbean,... });
 $req = new JMX::Jmx4Perl::Request({type => READ, mbean => $mbean, ... });

The constructor can be used in various way. In the simplest form, you provide
the type as first argument and depending on the type one or more additional
attributes which specify the request. The second form uses the type as first
parameter and a hashref containing named parameter for the request parameters
(for the names, see above). Finally you can specify the arguments completely as
a hashref, using 'type' for the entry specifying the request type.

For the options C<maxDepth>, C<maxObjects> and C<maxCollectionSize>, you can mix
them in into the hashref if using the hashed argument format. For the first
format, these options are given as a final hashref.

The option C<method> can be used to suggest a HTTP request method to use. By
default, the agent decides automatically which HTTP method to use depending on
the number of requests and whether an extended format should be used (which is
only possible with an HTTP POST request). The value of this option can be
either C<post> or C<get>, dependening on your preference. 

If the request should be proxied through this request, a target configuration
needs to be given as optional parameter. The target configuration consists of a
JMX service C<url> and a optional environment, which is given as a key-value
map. For example

 $req = new JMX::Jmx4Perl::Request(..., { 
                                     target => { 
                                                  url => "",
                                                  env => { ..... }
                                                }
                                     } );

Note, depending on the type, some parameters are mandatory. The mandatory
parameters and the order of the arguments for the constructor variant without
named parameters are:

=over

=item C<READ>

 Order    : $mbean, $attribute, $path
 Mandatory: $mbean, $attribute

Note that C<$attribute> can be either a single name or a reference to a list
of attribute names. 

=item C<WRITE> 

 Order    : $mbean, $attribute, $value, $path
 Mandatory: $mbean, $attribute, $value

=item C<EXEC> 

 Order    : $mbean, $operation, $arg1, $arg2, ...
 Mandatory: $mbean, $operation


=item C<LIST>
  
 Order    : $path

=item C<SEARCH>

 Order    : $pattern
 Mandatory: $pattern

=back

=cut

sub new {
    my $class = shift;
    my $type = shift;
    my $self;
    # Hash as argument
    if (ref($type) eq "HASH") {
        $self = $type;
        $type = $self->{type};
    }
    croak "Invalid type '",$type,"' given (should be one of ",join(" ",keys %$TYPES),")" unless $TYPES->{$type};
    
    # Hash comes after type
    if (!$self) {
        if (ref($_[0]) eq "HASH") {
            $self = $_[0];
            $self->{type} = $type;
        } else {
            # Unnamed arguments
            $self = {type =>  $type};

            # Options are given as last part
            my $opts = $_[scalar(@_)-1];
            if (ref($opts) eq "HASH") {
                pop @_;
                map { $self->{$_} = $opts->{$_} } keys %$opts;
                if ($self->{method}) {
                    # Canonicalize and verify
                    &method($self,$self->{method});                    
                }
            } 
            if ($type eq READ) {
                $self->{mbean} = shift;
                $self->{attribute} = shift;
                $self->{path} = shift;
                # Use post for complex read requests
                if (ref($self->{attribute}) eq "ARRAY") {
                    if (&method($self) eq "GET") {
                        # Was already explicitely set
                        die "Cannot query for multiple attributes " . join(",",@{$self->{attributes}}) . " with a GET request"
                          if ref($self->{attribute}) eq "ARRAY";
                    }
                    &method($self,"POST");
                }
            } elsif ($type eq WRITE) {
                $self->{mbean} = shift;
                $self->{attribute} = shift;
                $self->{value} = shift;
                $self->{path} = shift;
            } elsif ($type eq EXEC) {
                $self->{mbean} = shift;
                $self->{operation} = shift;
                $self->{arguments} = [ @_ ];
            } elsif ($type eq LIST) {
                $self->{path} = shift;
            } elsif ($type eq SEARCH) {
                $self->{mbean} = shift;
                #No check here until now, is done on the server side as well.
                #die "MBean name ",$self->{mbean}," is not a pattern" unless &is_mbean_pattern($self);
            } elsif ($type eq VERSION) {
                # No extra parameters required
            }  else {
                croak "Type ",$type," not supported yet";
            }
        }
    }
    bless $self,(ref($class) || $class);
    $self->_validate();
    return $self;
}

=item $req->method()

=item $req->method("POST")

Set the HTTP request method for this requst excplicitely. If not provided
either during construction time (config key 'method') a prefered request
method is determined dynamically based on the request contents.

=cut 

sub method {
    my $self = shift;
    my $value = shift;
    if (defined($value)) {
        die "Unknown request method ",$value if length($value) && $value !~ /^(POST|GET)$/i;
        $self->{method} = uc($value);
    }
    return defined($self->{method}) ? $self->{method} : "";
}

=item $req->is_mbean_pattern

Returns true, if the MBean name used in this request is a MBean pattern (which
can be used in C<SEARCH> or for C<READ>) or not

=cut

sub is_mbean_pattern {
    my $self = shift;
    my $mbean = shift || $self->{mbean};
    return 1 unless $mbean;
    my ($domain,$rest) = split(/:/,$mbean,2);
    return 1 if $domain =~ /[*?]/;
    return 1 if $rest =~  /\*$/;

    while ($rest) {
        #print "R: $rest\n";
        $rest =~ s/([^=]+)\s*=\s*//;
        my $key = $1;
        my $value;
        if ($rest =~ /^"/) {
            $rest =~ s/("(\\"|[^"])+")(\s*,\s*|$)//;
            $value = $1;
            # Pattern in quoted values must not be preceded by a \
            return 1 if $value =~ /(?<!\\)[\*\?]/;
        } else {
            $rest =~ s/([^,]+)(\s*,\s*|$)//;
            $value = $1;
            return 1 if $value =~ /[\*\?]/;
        }
        #print "K: $key V: $value\n";
    }
    return 0;
}

=item $request->get("type")

Get a request parameter

=cut 

sub get {
    my $self = shift;
    my $name = shift;
    return $self->{$name};
}

# Internal check for validating that all arguments are given
sub _validate {
    my $self = shift;
    if ($self->{type} eq READ ||  $self->{type} eq WRITE) {
        die $self->{type} . ": No mbean name given\n",Dumper($self) unless $self->{mbean};
        die $self->{type} . ": No attribute name but path is given\n" if (!$self->{attribute} && $self->{path});
    }
    if ($self->{type} eq WRITE) {
        die $self->{type} . ": No value given\n" unless defined($self->{value});
    }
    if ($self->{type} eq EXEC) {
        die $self->{type} . ": No mbean name given\n" unless $self->{mbean};
        die $self->{type} . ": No operation name given\n" unless $self->{operation};
    }
}

# Called for post requests
sub TO_JSON {
    my $self = shift;
    my $ret = {
               type => $self->{type} ? uc($self->{type}) : undef,
              };
    for my $k (qw(mbean attribute path value operation arguments target)) {
        $ret->{$k} = $self->{$k} if defined($self->{$k});
    }
    my %config;
    for my $k (qw(maxDepth maxObjects maxCollectionSize ignoreErrors)) {
        $config{$k} = $self->{$k} if defined($self->{$k});
    }
    $ret->{config} = \%config if keys(%config);
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
