#!/usr/bin/perl

package It;

use strict;
use JMX::Jmx4Perl;
use Exporter;
use vars qw(@EXPORT);
use Data::Dumper;

@EXPORT = qw($IT_BEAN);

my $IT_BEAN = "jmx4perl:type=it,name=testbean";


sub new { 
    my $class = shift;
    my %args = @_;
    my $self = {};
    $self->{url} = $args{gateway} || $ENV{JMX4PERL_GATEWAY} || die "No gateway URL given";
    $self->{product} = $args{product} || $ENV{JMX4PERL_PRODUCT};
    $self->{user} = $args{user} || $ENV{JMX4PERL_USER};
    $self->{password} = $args{password} || $ENV{JMX4PERL_PASSWORD};
    $self->{verbose} = $args{verbose} || $ENV{JMX4PERL_VERBOSE};
    my $t_url = $args{target_url} || $ENV{JMX4PERL_TARGET_URL};
    my $t_user = $args{target_user} || $ENV{JMX4PERL_TARGET_USER};
    my $t_password = $args{target_password} || $ENV{JMX4PERL_TARGET_PASSWORD};
    my @params = map { $_ => $self->{$_ } } qw(url product user password verbose);
    if ($t_url) {
        push @params, target => {
                                 url => $t_url,
                                 $t_user ? (user => $t_user) : (),
                                 $t_password ? (password => $t_password) : ()
                                };
    }
    $self->{jmx4perl} = new JMX::Jmx4Perl(@params);
    
    bless $self,(ref($class) || $class);

}

sub jmx4perl {
    my $self = shift;
    return $self->{jmx4perl};
}

1;
