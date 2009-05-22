#!/usr/bin/perl

package JMX::Jmx4Perl::ProductHandler::BaseHandler;

use strict;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Alias;
use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::ProductHandler::BaseHandler - Base package for product specific handler 

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 

=item $handler = JMX::Jmx4Perl::ProductHandler::MyHandler->new($jmx4perl);

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
    $self->{aliases} = $self->_init_aliases();
    return $self;
}

=item $id = $handler->id()

Return the id of this handler, which must be unique among all handlers. This
method is abstract and must be overwritten by a subclass

=cut 

sub id { 
    croak "Must be overwritten to return a name";
}

=item $version = $handler->version() 

Get the version of the underlying application server or return C<undef> if the
version can not be determined. Please note, that this method can be only called
after autodetect() has been called since this call is normally used to fill in
that version number.

=cut

sub version {
    
}

=item $is_product = $handler->autodetect()

Return true, if the appserver to which the given L<JMX::Jmx4Perl> (at
construction time) object is connected can be handled by this product
handler. If this module detects that it definitely can not handler this
application server, it returnd false. If an error occurs during autodectection,
this method should return C<undef>.

=cut

sub autodetect {
    my ($self) = @_;
    croak "Must be overwritten to return true " . 
      "in case we detect the server as the server we can handle";       
}

=item print $handler->description() 

Print an informal message about the handler under question. Should be
overwritten to print a more exhaustive description text

=cut

sub description {
    my $self = shift;
    return $self->id(); # By default, only the id is returned.
}


=item $can_jsr77 = $handler->knows_jsr77()

Return true if the app server represented by this handler is an implementation
of JSR77, which provides a well defined way how to access deployed applications
and other stuff on a JEE Server. I.e. it defines how MBean representing this
information has to be named. This base class returns false, but this method can
be overwritten by a subclass.

=cut

sub knows_jsr77 {
    return undef;
}

=item ($mbean,$attribute,$path) = $self->attribute_alias($alias)

Return the mbean and attribute name for an registered alias. A subclass should
call this parent method if it doesn't know about this alias, since JVM
specific MBeans are aliased here.

Returns undef if this product handler doesn't know about the provided alias. 

=cut 

sub attribute_alias {
    my ($self,$alias_or_name) = @_;
    my $alias;
    if (UNIVERSAL::isa($alias_or_name,"JMX::Jmx4Perl::Alias::Object")) {
        $alias = $alias_or_name;
    } else {
        $alias = JMX::Jmx4Perl::Alias->get_by_name($alias_or_name) 
          || croak "No alias $alias_or_name known";
    }
    return $self->resolve_attribute_alias($alias) || @{$alias->default()};
}

# Examines internal alias hash in order to return handler specific aliases
# Can be overwritten if something more esoteric is required
sub resolve_attribute_alias {
    my $self = shift;
    my $alias = shift;
    my $aliases = $self->{aliases}->{attributes};
    return $aliases && $aliases->{$alias};
}


# Internal method which sould be overwritten to return the special map (like in
# Aliases) for this product containing specific ($mbean,$attribute,$path) tuples1

sub _init_aliases {
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
        return $self->{$property} != 0;
    }
    my $request = JMX::Jmx4Perl::Request->new(READ_ATTRIBUTE,$object,$attribute,$path);
    my $response = $jmx4perl->request($request);
    if ($response->status == 404) {
        $self->{$property} = 0;
    } elsif ($response->is_ok) {
        $self->{$property} = $response->value;
    } else {
        croak "Error while trying to autodetect ",$self->id(),": ",$response->error_text();
    }
    return $self->{$property} != 0;
}

1;
