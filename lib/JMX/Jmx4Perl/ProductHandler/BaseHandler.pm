#!/usr/bin/perl

package JMX::Jmx4Perl::ProductHandler::BaseHandler;

use Carp qw(croak);

=head1 NAME

JMX::Jmx4Perl::ProductHandler::BaseHandler - Base package for product specific handler 

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=over 

=item $id = $handler->id()

Return the id of this handler, which must be unique among all handlers. This
method is abstract and must be overwritten by a subclass

=cut 

sub id { 
    my $self = shift;
    croak "Must be overwritten to return a name"
}

=item $is_product = $handler->autodetect($jmx4perl)

Return true, if the appserver to which the given L<JMX::Jmx4Perl> object is
connected can be handled by this product handler. If this module detects that
it definitely can not handler this application server, it returnd false. If an
error occurs during autodectection, this method should return C<undef>.

=cut

sub autodetect {
    my ($self,$jmx4perl) = @_;
    croak "Must be overwritten to return true " . 
      "in case we detect the server as the server we can handle";       
}

=item ($mbean,$attribute) = $self->attribute_alias($alias)

Return the mbean and attribute name for an registered alias. A subclass should
call this parent method if it doesn't know about this alias, since JVM
specific MBeans are aliased here.

Returns undef if this product handler doesn't know about the provided alias. 

=cut 

sub attribute_alias {
    my ($self,$alias) = @_;

    return undef;
}

1;
