#!/usr/bin/perl

=head1 NAME 

JMX::Jmx4Perl - Access to JMX via Perl

=head1 SYNOPSIS

Simple:

   use strict;
   use JMX::Jmx4Perl;
   use JMX::Jmx4Perl::Alias;   # Import MBean aliases 

   print "Memory Used: ",
          JMX::Jmx4Perl
              ->new(url => "http://localhost:8080/j4p")
              ->get_attribute(MEMORY_HEAP_USED);

Advanced:

   use strict;
   use JMX::Jmx4Perl;
   use JMX::Jmx4Perl::Request;   # Type constants are exported here
   
   my $jmx = new JMX::Jmx4Perl(url => "http://localhost:8080/j4p",
                               product => "jboss");
   my $request = new JMX::Jmx4Perl::Request({type => READ,
                                             mbean => "java.lang:type=Memory",
                                             attribute => "HeapMemoryUsage",
                                             path => "used"});
   my $response = $jmx->request($request);
   print "Memory used: ",$response->value(),"\n";

   # Get general server information
   print "Server Info: ",$jmx->info();

=head1 DESCRIPTION

Jmx4Perl is here to connect the Java and Perl Enterprise world by providing
transparent access to the Java Management Extensions (JMX) from the perl side. 

It uses a traditional request-response paradigma for performing JMX operations
on a remote Java Virtual machine. 

There a various ways how JMX information can be transfered. Jmx4Perl is based
on an I<agent>, a Java Servlet, which needs to deployed on a
Java application server. It plays the role of a proxy, which on one side
communicates with the MBeanServer within in the application server and
transfers JMX related information via HTTP and JSON to the client (i.e. this
module). Please refer to L<JMX::Jmx4Perl::Manual> for installation instructions
for how to deploy the agent servlet (which can be found in the distribution as
F<agent/j4p.war>).

An alternative and more 'java like' approach is the usage of JSR 160
connectors. However, the default connectors provided by the Java Virtual
Machine (JVM) since version 1.5 support only proprietary protocols which
require serialized Java objects to be exchanged. This implies that a JVM needs
to be started on the client side adding quite some overhead if used from
within Perl. Nevertheless plans are underway to support this operational mode
as well, which allows for monitoring Java applications which are not running
in a servlet container.

For further discussion comparing both approaches, please refer to
L<JMX::Jmx4Perl::Manual> 

JMX itself knows about the following operations on so called I<MBeans>, which
are specific "managed beans" designed for JMX and providing access to
management functions:

=over

=item * 

Reading and writing of attributes of an MBean (like memory usage or connected
users) 

=item *

Executing of exposed operations (like triggering a garbage collection)

=item * 

Registering of notifications which are send from the application server to a
listener when a certain event happens.

=back

=head1 METHODS

=over

=cut

package JMX::Jmx4Perl;

use Carp;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Config;
use strict;
use vars qw($VERSION $HANDLER_BASE_PACKAGE @PRODUCT_HANDLER_ORDERING);
use Data::Dumper;
use Module::Find;

$VERSION = "0.72";

my $REGISTRY = {
                # Agent based
                "agent" => "JMX::Jmx4Perl::Agent",
                "JMX::Jmx4Perl::Agent" => "JMX::Jmx4Perl::Agent",
                "JJAgent" => "JMX::Jmx4Perl::Agent",
               };

my %PRODUCT_HANDLER;

sub _register_handlers { 
    my $handler_package = shift;
    %PRODUCT_HANDLER = ();
    
    my @id2order = ();
    for my $handler (findsubmod $handler_package) {
        next unless $handler;
        my $handler_file = $handler;
        $handler_file =~ s|::|/|g;
        require $handler_file.".pm";
        next if $handler eq $handler_package."::BaseHandler";
        my $id = eval "${handler}::id()";
        die "No id() method on $handler: $@" if $@;
        $PRODUCT_HANDLER{lc $id} = $handler;
        push @id2order, [ lc $id, $handler->order() ];
    }
    # Ordering Schema according to $handler->order():
    # -10,-5,-3,0,undef,undef,undef,1,8,9,1000
    my @high = map { $_->[0] } sort { $a->[1] <=> $b->[1] } grep { defined($_->[1]) && $_->[1] <= 0 } @id2order;
    my @med  = map { $_->[0] } grep { not defined($_->[1]) } @id2order;
    my @low  = map { $_->[0] } sort { $a->[1] <=> $b->[1] } grep { defined($_->[1]) && $_->[1] > 0 } @id2order;
    @PRODUCT_HANDLER_ORDERING = (@high,@med,@low);
}

BEGIN {
    &_register_handlers("JMX::Jmx4Perl::Product");
}


=item $jmx = JMX::Jmx4Perl->new(mode => <access module>, ....)

Create a new instance. The call is dispatched to an Jmx4Perl implementation by
selecting an appropriate mode. For now, the only mode supported is "agent",
which uses the L<JMX::Jmx4Perl::Agent> backend. Hence, the mode can be
submitted for now.

Options can be given via key value pairs (or via a hash). Recognized options
are:

=over

=item server

You can provide a server name which is looked up in a configuration file. The
configuration file's name can be given via C<config_file> (see below) or, by
default, C<.j4p> in the users home directory is used.

=item config_file

Path to a configuration file to use

=item config

A L<JMX::Jmx4Perl::Config> object which is used for 
configuraton. Use this is you already read in the 
configuration on your own. 

=item product

If you provide a product id via the named parameter C<product> you can given
B<jmx4perl> a hint which server you are using. By default, this module uses
autodetection to guess the kind of server you are talking to. You need to
provide this argument only if you use B<jmx4perl>'s alias feature and if you
want to speed up things (autodetection can be quite slow since this requires
several JMX request to detect product specific MBean attributes).

=back

Any other named parameters are interpreted by the backend, please
refer to its documentation for details (i.e. L<JMX::Jmx4Perl::Agent>)

=cut

sub new {
    my $class = shift;
    my $cfg = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };

    # Merge in config from a configuration file if a server name is given
    if ($cfg->{server}) {
        my $config = $cfg->{config} ? $cfg->{config} : new JMX::Jmx4Perl::Config($cfg->{config_file});
        my $server_cfg = $config->get_server_config($cfg->{server});
        if (defined($server_cfg)) {
            $cfg = { %$server_cfg, %$cfg };
        }
    }
    
    my $mode = delete $cfg->{mode} || &autodiscover_mode();
    my $product = $cfg->{product} ? lc delete $cfg->{product} : undef;

    $class = $REGISTRY->{$mode} || croak "Unknown runtime mode " . $mode;
    if ($product && !$PRODUCT_HANDLER{lc $product}) {
        die "No handler for product '$product'. Known Handlers are [".(join ", ",keys %PRODUCT_HANDLER)."]";
    }

    eval "require $class";
    croak "Cannot load $class: $@" if $@;

    my $self = { 
                cfg => $cfg,
                product => $product
               };
    bless $self,(ref($class) || $class);
    $self->init();
    return $self;
}

# ==========================================================================

=item $value => $jmx->get_attribute(...)

  $value = $jmx->get_attribute($mbean,$attribute,$path) 
  $value = $jmx->get_attribute($alias)
  $value = $jmx->get_attribute(ALIAS)       # Literal alias as defined in
                                            # JMX::Jmx4Perl::Alias
  $value = $jmx->get_attribute({ domain => <domain>, 
                                 properties => { <key> => value }, 
                                 attribute => <attribute>, 
                                 path => <path> })
  $value = $jmx->get_attribute({ alias => <alias>, 
                                 path => <path })

Read a JMX attribute. In the first form, you provide the MBean name, the
attribute name and an optional path as positional arguments. The second
variant uses named parameters from a hashref. 

The Mbean name can be specified with the canonical name (key C<mbean>), or with
a domain name (key C<domain>) and one or more properties (key C<properties> or
C<props>) which contain key-value pairs in a Hashref. For more about naming of
MBeans please refer to
L<http://java.sun.com/j2se/1.5.0/docs/api/javax/management/ObjectName.html> for
more information about JMX naming.

Alternatively, you can provide an alias, which gets resolved to its real name
by so called I<product handler>. Several product handlers are provided out of
the box. If you have specified a C<product> id during construction of this
object, the associated handler is selected. Otherwise, autodetection is used to
guess the product. Note, that autodetection is potentially slow since it
involves several JMX calls to the server. If you call with a single, scalar
value, this argument is taken as alias (without any path). If you want to use
aliases together with a path, you need to use the second form with a hash ref
for providing the (named) arguments. 

Additionally you can use a pattern and/or an array ref for attributes to
combine multiple reads into a single request. With an array ref as attribute
argument, all the given attributes are queried. If C<$attribute> is C<undef>
all attributes on the MBean are queried.

If you provide a pattern as described for the L<"/search"> method, a search
will be performed on the server side, an for all MBeans found which carry the
given attribute(s), their value will be returned. Attributes which doesn't
apply to an MBean are ignored.

Note, that the C<path> feature is not available when using MBean patterns or
multiple values.

Depending on the arguments, this method return value has a different format:

=over 4

=item Single MBean, single attribute

The return value is the result of the serverside read operation. It will throw
an exception (die), if an error occurs on the server side, e.g. when the name
couldn't be found.

Example:

  $val = $jmx->get_attribute("java.lang:type=Memory","HeapMemoryUsage");
  print Dumper($val);

  {
    committed => 174530560,
    init => 134217728,
    max => "1580007424",
    used => 35029320
  }

=item Single MBean, multiple attributes

In this case, this method returns a map with the attribute name as keys and the
attribute values as map values. It will die if not a single attribute could be
fetched, otherwise unknown attributes are ignored.

  $val = $jmx->get_attribute(
      "java.lang:type=Memory",
      ["HeapMemoryUsage","NonHeapMemoryUsage"]
  );
  print Dumper($val);

  {
    HeapMemoryUsage => {
      committed => 174530560,
      init => 134217728,
      max => "1580007424",
      used => 37444832
    },
    NonHeapMemoryUsage => {
      committed => 87552000,
      init => 24317952,
      max => 218103808,
      used => 50510976
    }
  }

=item MBean pattern, one or more attributes

  $val = $jmx->get_attribute(
      "java.lang:type=*",
      ["HeapMemoryUsage","NonHeapMemoryUsage"]
  );
  print Dumper($val);

  {
    "java.lang:type=Memory" => {
      HeapMemoryUsage => {
        committed => 174530560,
        init => 134217728,
        max => "1580007424",
        used => 38868584
      },
      NonHeapMemoryUsage => {
        committed => 87552000,
        init => 24317952,
        max => 218103808,
        used => 50514304
      }
    }
  }

The return value is a map with the matching MBean names as keys and as value
another map, with attribute names keys and attribute value values. If not a
singel MBean matches or not a single attribute can be found on the matching
MBeans this method dies. This format is the same whether you are using a single
attribute or an array ref of attribute names. 

=back

Please don't overuse pattern matching (i.e. don't use patterns like "*:*"
except you really want to) since this could easily blow up your Java
application. The return value is generated completely in memory. E.g if you
want to retrieve all attributes for Weblogic with 

  $jmx->get_attribute("*:*",undef);

you will load more than 200 MB in to the Heap. Probably not something you
want to do. So please be nice to your appserver and use a more restrictive
pattern. 

=cut 

sub get_attribute {
    my $self = shift;
    my ($object,$attribute,$path) = $self->_extract_get_set_parameters(with_value => 0,params => [@_]);
    croak "No object name provided" unless $object;

    my $response;
    if (ref($object) eq "CODE") {       
        $response = $self->delegate_to_handler($object);                
    } else {
        #croak "No attribute provided for object $object" unless $attribute;        
        my $request = JMX::Jmx4Perl::Request->new(READ,$object,$attribute,$path);
        $response = $self->request($request);
        #print Dumper($response);
    }
    if ($response->is_error) {
        my $a = ref($attribute) eq "ARRAY" ? "[" . join(",",@$attribute) . "]" : $attribute;
        my $o = "(".$object.",".$a.($path ? "," . $path : "").")";
        croak "The attribute $o is not registered on the server side"
          if $response->status == 404;
        croak "Error requesting $o: ",$response->error_text;
    }
    return $response->value;
}

=item $resp = $jmx->set_attribute(...)

  $new_value = $jmx->set_attribute($mbean,$attribute,$value,$path)
  $new_value = $jmx->set_attribute($alias,$value)
  $new_value = $jmx->set_attribute(ALIAS,$value)  # Literal alias as defined in
                                                  # JMX::Jmx4Perl::Alias
  $new_value = $jmx->set_attribute({ domain => <domain>, 
                                     properties => { <key> => value }, 
                                     attribute => <attribute>, 
                                     value => <value>,
                                     path => <path> })
  $new_value = $jmx->set_attribute({ alias => <alias>, 
                                     value => <value>,
                                     path => <path })

Method for writing an attribute. It has the same signature as L</get_attribute>
except that it takes an additional parameter C<value> for setting the value. It
returns the old value of the attribute (or the object pointed to by an inner
path). 

As for C<get_attribute> you can use a path to specify an inner part of a more
complex data structure. The value is tried to set on the inner object which is
pointed to by the given path. 

Please note that only basic data types can be set this way. I.e you can set
only values of the following types

=over

=item C<java.lang.String>

=item C<java.lang.Boolean>

=item C<java.lang.Integer>

=back

=cut

sub set_attribute { 
    my $self = shift;

    my ($object,$attribute,$path,$value) = 
      $self->_extract_get_set_parameters(with_value => 1,params => [@_]);
    croak "No object name provided" unless $object;

    my $response;
    if (ref($object) eq "CODE") {
        $response =  $self->delegate_to_handler($object,$value);        
    } else {
        croak "No attribute provided for object $object" unless $attribute;
        croak "No value to set provided for object $object and attribute $attribute" unless defined($value);
        
        my $request = JMX::Jmx4Perl::Request->new(WRITE,$object,$attribute,$value,$path);
        $response = $self->request($request);
    }
    if ($response->status == 404) {
        return undef;
    }
    return $response->value;
}

=item $info = $jmx->info($verbose)

Get a textual description of the server as returned by a product specific
handler (see L<JMX::Jmx4Perl::Product::BaseHandler>). It uses the
autodetection facility if no product is given explicitely during construction. 

If C<$verbose> is true, print even more information

=cut

sub info {
    my $self = shift;
    my $verbose = shift;
    my $handler = $self->{product_handler} || $self->_create_handler();
    return $handler->info($verbose);
}


=item $mbean_list = $jmx->search($mbean_pattern)

Search for MBean based on a pattern and return a reference to the list of found
MBeans names (as string). If no MBean can be found, C<undef> is returned. For
example, 

 $jmx->search("*:j2eeType=J2EEServer,*")

searches all MBeans whose name are matching this pattern, which are according
to JSR77 all application servers in all available domains. 

=cut 

sub search {
    my $self = shift;
    my $pattern = shift || croak "No pattern provided";
    
    my $request = new JMX::Jmx4Perl::Request(SEARCH,$pattern);
    my $response = $self->request($request);

    return undef if $response->status == 404; # nothing found
    if ($response->is_error) {
        print Dumper($response);
        die "Error searching for $pattern: ",$response->error_text;
    }
    return $response->value;    
}

=item   $ret = $jmx->execute(...)

  $ret = $jmx->execute($mbean,$operation,$arg1,$arg2,...)
  $ret = $jmx->execute(ALIAS,$arg1,$arg2,...)

  $value = $jmx->execute({ domain => <domain>, 
                           properties => { <key> => value }, 
                           operation => <operation>, 
                           arguments => [ <arg1>, <arg2>, ... ] })
  $value = $jmx->execute({ alias => <alias>, 
                           arguments => [ <arg1,<arg2>, .... ]})

Execute a JMX operation with the given arguments. If used in the second form,
with an alias as first argument, it is recommended to use the constant as
exported by L<JMX::Jmx4Perl::Alias>, otherwise it is guessed, whether the first
string value is an alias or a MBean name. To be sure, use the variant with an
hashref as argument.

If you are calling an overloaded JMX operation (i.e. operations with the same
name but a different argument signature), the operation name must include the
signature as well. This is be done by adding the parameter types comma
separated within parentheses:

  ...
  operation => "overloadedMethod(java.lang.String,int)"
  ...

This method will croak, if something fails during execution of this
operation or when the MBean/Operation combination could not be found.

The return value of this method is the return value of the JMX operation.

=cut

sub execute {
    my $self = shift;

    my @args = @_;
    my ($mbean,$operation,$op_args) = $self->_extract_execute_parameters(@_);
    my $response;
    if (ref($mbean) eq "CODE") {        
        $response = $self->delegate_to_handler($mbean,@{$op_args});
    } else {
        my $request = new JMX::Jmx4Perl::Request(EXEC,$mbean,$operation,@{$op_args});
        $response = $self->request($request);
    }
    if ($response->is_error) {
        croak "No MBean ".$mbean." with operation ".$operation.
          (@$op_args ?  " (Args: [".join(",",@$op_args)."]" : "")."] found on the server side"
            if $response->status == 404;
        croak "Error executing operation $operation on MBean $mbean: ",$response->error_text;
    }
    return $response->value;
}


=item $resp = $jmx->version()

This method return the version of the agent as well as the j4p protocol
version. The agent's version is a regular program version and corresponds to 
jmx4perl's version from which the agent has been taken. The protocol version
is an integer number which indicates the version of the protocol specification.

The return value is a hash with the keys C<agent> and C<protocol>

=cut

sub version {
    my $self = shift;
    
    my $request = new JMX::Jmx4Perl::Request(VERSION);
    my $response = $self->request($request);

    if ($response->is_error) {
        die "Error getting the agent's version: ",$response->error_text;
    }
    return $response->value;    
}

=item $resp = $jmx->request($request)

Send a request to the underlying agent and return the response. This is an
abstract method which needs to be overwritten by a subclass. The argument must
be of type L<JMX::Jmx4Perl::Request> and it returns an object of type
L<JMX::Jmx4Perl::Response>.

=cut 

sub request {
    croak "Internal: Must be overwritten by a subclass";    
}

# ===========================================================================
# Alias handling

=item ($object,$attribute,$path) = $self->resolve_alias($alias)

Resolve an alias for an attibute or operation. This is done by querying registered
product handlers for resolving an alias. This method will croak if a handler
could be found but not such alias is known by C<jmx4perl>.

If the C<product> was not set during construction, the first call to this
method will try to autodetect the server. If it cannot determine the proper
server it will throw an exception. 

For an attribute, this method returns the object, attribute, path triple which
can be used for requesting the server or C<undef> if the handler can not
handle this alias.

For an operation, the MBean, method name and the (optional) path, which should be
applied to the return value, is returned or C<undef> if the handler cannot
handle this alias.

A handler can decide to handle the fetching of the alias value directly. In
this case, this metod returns the code reference which needs to be executed
with the handler as argument (see "delegate_to_handler") below. 

=cut

sub resolve_alias {
    my $self = shift;
    my $alias = shift || croak "No alias provided";

    my $handler = $self->{product_handler} || $self->_create_handler();    
    return $handler->alias($alias);
}

=item $do_support = $self->supports_alias($alias) 

Test for checking whether a handler supports a certain alias. 

=cut

sub supports_alias {
    my ($object) = shift->resolve_alias(shift);
    return $object ? 1 : 0;
}

=item $response = $self->delegate_to_handler($coderef,@args)

Execute a subroutine with the current handler as argument and returns the
return value of this subroutine. This method is used in conjunction with
C<resolve_alias> to allow handler a more sophisticated way to access the
MBeanServer. The method specified by C<$coderef> must return a
L<JMX::Jmx4Perl::Response> as answer.

The subroutine is supposed to handle reading and writing of attributes and
execution of operations. Optional additional parameters are given to the subref
as additional arguments.

=cut

sub delegate_to_handler {
    my $self = shift;
    my $code = shift;
    my $handler = $self->{product_handler} || $self->_create_handler();    
    return &{$code}($handler,@_);
}

=item $product = $self->product()

For supported application servers, this methods returns product handler 
which is an object of type L<JMX::Jmx4Perl::Product::BaseHandler>. 

This product is either detected automatically or provided during
construction time.

The most interesting methods on this object are C<id()>, C<name()> and
C<version()> 

=cut

sub product {
    my $self = shift;
    my $handler = $self->{product_handler} || $self->_create_handler();
    return $handler;
}

=item $value = $jmx->list($path)

Get all MBeans as registered at the specified server. A C<$path> can be
specified in order to fetchy only a subset of the information. When no path is
given, the returned value has the following format

  $value = { 
              <domain> => 
              { 
                <canonical property list> => 
                { 
                    "attr" => 
                    { 
                       <atrribute name> => 
                       {
                          desc => <description of attribute>
                          type => <java type>, 
                          rw => true/false 
                       }, 
                       .... 
                    },
                    "op" => 
                    { 
                       <operation name> => 
                       { 
                         desc => <description of operation>
                         ret => <return java type>
                         args =>
                         [
                            {
                              desc => <description>,
                              name => <name>,
                              type => <java type>
                            },
                            ....
                         ]
                       },
                       ....
                },
                .... 
              }
              .... 
           };

A complete path has the format C<"E<lt>domainE<gt>/E<lt>property
listE<gt>/("attribute"|"operation")/E<lt>indexE<gt>">
(e.g. C<java.lang/name=Code Cache,type=MemoryPool/attribute/0>). A path can be
provided partially, in which case the remaining map/array is returned. See also
L<JMX::Jmx4Perl::Agent::Protocol> for a more detailed discussion of inner
pathes. 

This method throws an exception if an error occurs.

=cut

sub list {
    my $self = shift;
    my $path = shift;

    my $request = JMX::Jmx4Perl::Request->new(LIST,$path);
    my $response = $self->request($request);
    if ($response->is_error) {
        my $txt = "Error while listing attributes: " . $response->error_text . "\n" .
          "Status: " . $response->status . "\n";
        #($response->stacktrace ? "\n" . $response->stacktrace . "\n" : "\n");
        die $txt;
    }
    return $response->value;    
}


=item ($domain,$attributes) = $jmx->parse_name($name)

Parse an object name into its domain and attribute part. If successful,
C<$domain> contains the domain part of the objectname, and C<$attribtutes> is a
hahsref to the attributes of the name with the attribute names as keys and the
attribute's values as values. This method returns C<undef> when the name could
not be parsed. Result of a C<search()> operation can be savely feed into this
method to get to the subparts of the name. JMX quoting is taken into account
properly, too.

Example:

  my ($domain,$attrs) = 
      $jmx->parse_name("java.lang:name=Code Cache,type=MemoryPool");
  print $domain,"\n",Dumper($attrs);

  java.lang
  {
    name => "Code Cache",
    type => "MemoryPool"
  }

=cut

sub parse_name {
    my $self = shift;
    my $name = shift;
    my $escaped = shift;

    return undef unless $name =~ /:/;
    my ($domain,$rest) = split(/:/,$name,2);
    my $attrs = {};
    while ($rest =~ s/([^=]+)\s*=\s*//) {
        #print "R: $rest\n";
        my $key = $1;
        my $value = undef;
        if ($rest =~ /^"/) {
            $rest =~ s/("((\\"|[^"])+)")(\s*,\s*|$)//;
            $value = $escaped ? $1 : $2;
            # Unescape escaped chars
            $value =~ s/\\([:",=*?])/$1/g unless $escaped;
        } else {
            if ($rest =~ s/([^,]+)(\s*,\s*|$)//) {
                $value = $1;
            } 
        }
        return undef unless defined($value);
        $attrs->{$key} = $value;
        #print "K: $key V: $value\n";
    }
    # If there is something left, we were not successful 
    # in parsing the name
    return undef if $rest;
    return ($domain,$attrs);
}


=item $formatted_text = $jmx->formatted_list($path)

=item $formatted_text = $jmx->formatted_list($resp)

Get the a formatted string representing the MBeans as returnded by C<list()>.
C<$path> is the optional inner path for selecting only a subset of all mbean.
See C<list()> for more details. If called with a L<JMX::Jmx4Perl::Response>
object, the list and the optional path will be taken from the provided response
object and not fetched again from the server.

=cut

sub formatted_list {
    my $self = shift;
    my $path_or_resp = shift;
    my $path;
    my $list;
    
    if ($path_or_resp && UNIVERSAL::isa($path_or_resp,"JMX::Jmx4Perl::Response")) {
        $path = $path_or_resp->request->get("path");
        $list = $path_or_resp->value;
    } else {
        $path = $path_or_resp;
        $list = $self->list($path);
    }
    my @path = ();
    @path = split m|/|,$path if $path;
    #print Dumper(\@path);
    croak "A path can be used only for a domain name or MBean name" if @path > 2;
    my $intent = "";
    my $ret = &_format_map("",$list,\@path,0);
}

# =============================================================================================== 

# Helper method for extracting parameters for the set/get methods.
sub _extract_get_set_parameters {
    my $self = shift;
    my %args = @_;
    my $p = $args{params};
    my $f = $p->[0];
    my $with_value = $args{with_value};
    my ($object,$attribute,$path,$value);
    if (ref($f) eq "HASH") {
        $value = $f->{value};
        if ($f->{alias}) {
            my $alias_path;
            ($object,$attribute,$alias_path) = 
              $self->resolve_alias($f->{alias});
            if (ref($object) eq "CODE") {
                # Let the handler do it
                return ($object,undef,undef,$args{with_value} ? $value : undef);
            }
            croak "No alias ",$f->{alias}," defined for handler ",$self->product->name unless $object; 
            if ($alias_path) {
                $path = $f->{path} ? $f->{path} . "/" . $alias_path : $alias_path;
            } else { 
                $path = $f->{path};
            }
        } else {
            $object = $f->{mbean} || $self->_glue_mbean_name($f) ||
              croak "No MBean name or domain + properties given";
            $attribute = $f->{attribute};
            $path = $f->{path};
        }        
    } else {
        if ( (@{$p} == 1 && !$args{with_value}) || 
             (@{$p} == 2 && $args{with_value}) || $self->_is_alias($p->[0])) {
            # A single argument can only be used as an alias
            ($object,$attribute,$path) = 
              $self->resolve_alias($f);
            $value = $_[1];
            if (ref($object) eq "CODE") {
                # Let the handler do it
                return ($object,undef,undef,$args{with_value} ? $value : undef);
            }
            croak "No alias ",$f," defined for handler ",$self->product->name unless $object; 
        } else {
            if ($args{with_value}) {
                ($object,$attribute,$value,$path) = @{$p};
            } else {
                ($object,$attribute,$path) = @{$p};
            }
        }
    }
    return ($object,$attribute,$path,$value);
}

sub _extract_execute_parameters {
    my $self = shift;
    my @args = @_;
    my ($mbean,$operation,$op_args);
    if (ref($args[0]) eq "HASH") {
        my $args = $args[0];
        if ($args->{alias}) {
            ($mbean,$operation) = $self->resolve_alias($args->{alias});
            if (ref($mbean) eq "CODE") {
                # Alias handles this completely on its own
                return ($mbean,undef,$args->{arguments} || $args->{args});
            }
            croak "No alias ",$args->{alias}," defined for handler ",$self->product->name unless $mbean; 
        } else {
            $mbean = $args->{mbean} || $self->_glue_mbean_name($args) || 
              croak "No MBean name or domain + properties given";
            $operation = $args->{operation} || croak "No operation given";
        }
        $op_args = $args->{arguments} || $args->{args};
    } else {
        if ($self->_is_alias($args[0])) {
            ($mbean,$operation) = $self->resolve_alias($args[0]);
            shift @args;
            if (ref($mbean) eq "CODE") {
                # Alias handles this completely on its own
                return ($mbean,undef,[ @args ]);
            }
            croak "No alias ",$args[0]," defined for handler ",$self->product->name unless $mbean;
            $op_args = [ @args ];
        } else {
            $mbean = shift @args;
            $operation = shift @args;
            $op_args = [ @args ];
        }
    }
    return ($mbean,$operation,$op_args);
}

# Check whether the argument is possibly an alias
sub _is_alias {
    my $self = shift;
    my $alias = shift;
    if (UNIVERSAL::isa($alias,"JMX::Jmx4Perl::Alias::Object")) {
        return 1;
    } elsif (JMX::Jmx4Perl::Alias->by_name($alias)) {
        return 1;
    } else {
        return 0;
    }
}

sub _glue_mbean_name {
    my $self = shift;
    my $f = shift;
    my $object = undef;
    if ($f->{domain} && ($f->{properties} || $f->{props})) {
        $object = $f->{domain} . ":";
        my $href = $f->{properties} || $f->{props};
        croak "'properties' is not a hashref" unless ref($href);
        for my $k (keys %{$href}) {
            $object .= $k . "=" . $href->{$k};
        }
    }
    return $object;
}

sub _create_handler {
    my $self = shift;
    if (!$self->{product}) {
        ($self->{product},$self->{product_handler}) = $self->_autodetect_product();
    }
    # Create product handler if not created during autodetectiong (e.g. if the
    # product has been set explicitely)
    $self->{product_handler} = $self->_new_handler($self->{product}) unless $self->{product_handler};
    croak "Cannot autodetect server product" unless $self->{product};
    return $self->{product_handler};        
}

sub _autodetect_product {
    my $self = shift;
    for my $id (@PRODUCT_HANDLER_ORDERING) {

        my $handler = $self->_new_handler($id);
        return ($id,$handler) if $handler->autodetect();
    }
    return undef;
}

sub _new_handler {
    my $self = shift;
    my $product = shift;

    my $handler = eval $PRODUCT_HANDLER{$product}."->new(\$self)";
    croak "Cannot create handler ",$self->{product},": $@" if $@;
    return $handler;
}


my $SPACE = 4;
my @SEPS = (":");
my $CURRENT_DOMAIN = "";

sub _format_map { 
    my ($ret,$map,$path,$level) = @_;

    my $p = shift @$path;
    my $sep = $SEPS[$level] ? $SEPS[$level] : "";
    if ($p) {
        $ret .= "$p".$sep;
        if (!@$path) {
            my $s = length($ret);
            $ret .= "\n".("=" x length($ret))."\n\n";
        }
        $ret = &_format_map($ret,$map,$path,$level);
    } else {
        for my $d (keys %$map) {
            my $prefix = "";
            if ($level == 0) {
                $CURRENT_DOMAIN = $d;
            } elsif ($level == 1) {
                $prefix = $CURRENT_DOMAIN . ":";
            } 
            $ret .= &_get_space($level).$prefix.$d.$sep."\n" unless ($d eq "attr" || $d eq "op" || $d eq "error" || $d eq "desc");
            my @args = ($ret,$map->{$d},$path);
            if ($d eq "attr") {
                $ret = &_format_attr_or_op(@args,$level,"attr","Attributes",\&_format_attribute);
            } elsif ($d eq "op") {
                $ret = &_format_attr_or_op(@args,$level,"op","Operations",\&_format_operation);
            } elsif ($d eq "desc") {
                # TODO: Print out description of an MBean
            } elsif ($d eq "error") {
                $ret = $ret . "\nError: ".$map->{error}->{message}."\n";
            } else {
                $ret = &_format_map(@args,$level+1);
                if ($level == 0) {
                    $ret .= "-" x 80 . "\n";
                } elsif ($level == 1) {
                    $ret .= "\n";
                }
            }
        }
    }
    return $ret;
}

sub _format_attr_or_op {
    my ($ret,$map,$path,$level,$top_key,$label,$format_sub) = @_;

    my $p = shift @$path;
    if ($p eq $top_key) {
        $p = shift @$path;
        if ($p) {
            $ret .= " ".$p."\n";
            return &$format_sub($ret,$p,$map->{$p},$level);
        } else {
            $ret .= " $label:\n";
        }
    } else {
        $ret .= &_get_space($level)."$label:\n";
    }
    for my $key (keys %$map) {
        $ret = &$format_sub($ret,$key,$map->{$key},$level+1);
    }
    return $ret;
}

sub _format_attribute {
    my ($ret,$name,$attr,$level) = @_;
    $ret .= &_get_space($level);
    $ret .= sprintf("%-35s %s\n",$name,$attr->{type}.((!$attr->{rw} || "false" eq lc $attr->{rw}) ? " [ro]" : "").", \"".$attr->{desc}."\"");
    return $ret;
}

sub _format_operation {
    my ($ret,$name,$op,$level) = @_;
    $ret .= &_get_space($level);
    my $list = ref($op) eq "HASH" ? [ $op ] : $op;
    my $first = 1;
    for my $o (@$list) {
        my $method = &_format_method($name,$o->{args},$o->{ret});
        $ret .= &_get_space($level) unless $first;
        $ret .= sprintf("%-35s \"%s\"\n",$method,$o->{desc});
        $first = 0;
    }
    return $ret;
}

sub _format_method { 
    my ($name,$args,$ret_type) = @_;
    my $ret = $ret_type." ".$name."(";
    if ($args) {
        for my $a (@$args) {
            $ret .= $a->{type} . " " . $a->{name} . ",";
        }
        chop $ret if @$args;
    }
    $ret .= ")";
    return $ret;
}

sub _get_space {
    my $level = shift;
    return " " x ($level * $SPACE);
}

sub cfg {
    my $self = shift;
    my $key = shift;
    my $val = shift;
    my $ret = $self->{cfg}->{$key};
    if (defined $val) {
        $self->{cfg}->{$key} = $val;
    }
    return $ret;
}

# ==========================================================================
# Methods used for overwriting

# Init method called during construction
sub init {
    # Do nothing by default
}

# ==========================================================================
#

sub autodiscover_mode {

    # For now, only *one* mode is supported. Additional
    # could be added (like calling up a local JVM)
    return "agent";
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

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or Nagios or JMX in
general), you might want to have a look at
http://www.consol.com/opensource/nagios/. Contact roland.huss@consol.de for
further information (or use the contact form at http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut

1;
