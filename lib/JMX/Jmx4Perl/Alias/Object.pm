package  JMX::Jmx4Perl::Alias::Object;

=head1 NAME

JMX::Jmx4Perl::Alias::Object - Internal object representing a concrete alias 

=head1 DESCRIPTION

Simple object which describes an alias. It knows about the following read-only
methods 

=over

=item $alias->alias()

alias name in uppercase form (e.g. C<MEMORY_HEAP_USED>)

=item $alias->name()

alias name in lowercase format (e.g. C<memory:heap:used>)

=item $alias->description()

short description of the alias

=item $alias->default()

default values for an alias, which can be overwritten by a specific
L<JMX::Jmx4Perl::Product::BaseHandler>. This is an arrayref with two values:
The MBean's name and the attribute or operation name.

=item $alias->type()

Either C<attribute> or C<operation>, depending on what kind of MBean part the
alias stands for.

=back

Additional, the C<"">, C<==> and C<!=> operators are overloaded to naturally
compare and stringify alias values.

=cut

use Scalar::Util qw(refaddr);

use overload
    q{""} => sub { (shift)->as_string(@_) },
    q{==} => sub { (shift)->equals(@_) },
    q{!=} => sub { !(shift)->equals(@_) };

sub equals { 
    return (ref $_[0] eq ref $_[1] && refaddr $_[0] == refaddr $_[1]) ? 1 : 0;
}

sub new { 
    my $class = shift;
    return bless { @_ },ref($class) || $class;
}

sub as_string { return $_[0]->{alias}; }
sub alias { return shift->{alias}; }
sub name { return shift->{name}; }
sub description { return shift->{description}; }
sub default { return shift->{default}; }
sub type { return shift->{type}; }

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
