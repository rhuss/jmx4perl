#!/usr/bin/perl

=head1 NAME

JMX::Jmx4Perl::Util - Utility methods for Jmx4Perl

=head1 DESCRIPTION

This class contains utility methods mostly for tools like C<jmx4perl> or
C<j4psh> for things like formatting data output. All methods are 'static'
methods which needs to be called like in 

   JMX::Jmx4Perl::Util->dump_value(...);

There is no constructor.

=over 

=cut

package JMX::Jmx4Perl::Util;

use Data::Dumper;
use JSON;

=item $is_object = JMX::Jmx4Perl::Util->is_object_to_dump($val) 

For dumping out, checks whether C<$val> is an object (i.e. it is a ref but not a
JSON::XS::Boolean) or not.

=cut 

sub is_object_to_dump {
    my $self = shift;
    my $val = shift;
    return ref($val) && !JSON::is_bool($val);
}

=item $text = JMX::Jmx4Perl::Util->dump_value($value,{ format => "json", boolean_string =>1})

Return a formatted text representation useful for tools printing out complex
response values. Two modes are available: C<data> which is the default and uses
L<Data::Dumper> for creating a textual description and C<json> which return the
result as JSON value. When C<data> is used as format, booleans are returned as 0
for false and 1 for true exception when the option C<boolean_string> is given in
which case it returns C<true> or C<false>. 

=cut

sub dump_value {
    my $self = shift;
    my $value = shift; 
    my $opts = shift || {};
    if ($opts && ref($opts) ne "HASH") {
        $opts = { $opts,@_ };
    }
    my $format = $opts->{format} || "data";
    my $ret;
    if ($format eq "json") {
        # Return a JSON representation of the data structure
        my $json = JSON->new->allow_nonref;
        $ret = $json->pretty->encode($value);
    } else {
        # Use data dumper, but resolve all JSON::XS::Booleans to either 0/1 or
        # true/false 
        local $Data::Dumper::Terse = 1;
        local $Data::Dumper::Indent = 1;
        # local $Data::Dumper::Useqq = 1;
        local $Data::Dumper::Deparse = 0;
        local $Data::Dumper::Quotekeys = 0;
        local $Data::Dumper::Sortkeys = 1;
        $ret = Dumper($self->_canonicalize_value($value,$opts->{booleans}));
    }
    my $indent = $opts->{indent} ? " " x $opts->{indent} : "    ";
    $ret =~ s/^/$indent/gm;
    return $ret;
}

=item $dump = JMX::Jmx4Perl::Util->dump_scalar($val,$format)

Dumps a scalar value with special handling for booleans.  If C<$val> is a
L<JSON::XS::Boolean> it is returned as string formatted according to
C<$format>. C<$format> must contain two values separated bu C</>. The first
part is taken for a C<true> value, the second for a C<false> value. If no
C<$format> is given, C<[true]/[false]> is used.

=cut 

sub dump_scalar {
    my $self = shift;
    my $value = shift;
    my $format = shift || "[true]/[false]";

    if (JSON::is_bool($value)) {
        my ($true,$false) = split /\//,$format;
        if ($value eq JSON::true) {
            return $true; 
        } else {
            return $false;
        }
    } else {
        return $value;
    }
}

# Replace all boolean values in 
sub _canonicalize_value {
    my $self = shift;
    my $value = shift;
    my $booleans = shift;
    if (ref($value) eq "HASH") {
        for my $k (keys %$value) {
            $value->{$k} = $self->_canonicalize_value($value->{$k},$booleans);
        }
        return $value;
    } elsif (ref($value) eq "ARRAY") {
        for my $i (0 .. $#$value) {
            $value->[$i] = $self->_canonicalize_value($value->[$i],$booleans);
        }
        return $value;
    } elsif (JSON::is_bool($value)) {
        $self->dump_scalar($value,$booleans);
    } else {
        return $value;
    }
}

=back 

=cut

1;
