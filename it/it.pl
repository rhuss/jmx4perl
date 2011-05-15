#!/usr/bin/perl

use FindBin;
use lib "$FindBin::Bin/../lib";
use Getopt::Long;
use strict;
use TAP::Harness;
use Data::Dumper;

my $dir = $FindBin::Bin . "/t";
my ($gateway_url,$user,$password,$product,$target_url,$target_user,$target_password);
GetOptions("dir=s" => \$dir,
           "url=s" => \$gateway_url,
           "target=s" => \$target_url,
           "target-user=s" => \$target_user,
           "target-password=s" => \$target_password,
           "user=s" => \$user,
           "password=s" => \$password,
           "product=s" => \$product);
die "No gateway url given. Please use option '--url' for pointing to the server with the agent installed\n" unless $gateway_url;

my @testfiles;
if (@ARGV) {
    @testfiles = prepare_filenames(@ARGV);
} else {
    opendir(D,$dir) || die "Cannot open test dir $dir : $!";
    @testfiles = prepare_filenames(grep { /\.t$/ } map { $dir . "/" . $_ } readdir(D));
    closedir D;   
}

my $harness = new TAP::Harness
  ({
    verbosity => 1,
    timer => 1,
    show_count => 0,
    color => 1,
    merge => 1,
    jobs => 1,
    lib => [ "$FindBin::Bin/../lib", "$FindBin::Bin/../t/lib" ]
   });

$ENV{JMX4PERL_GATEWAY} = $gateway_url;
$ENV{JMX4PERL_TARGET_URL} = $target_url;
$ENV{JMX4PERL_TARGET_USER} = $target_user;
$ENV{JMX4PERL_TARGET_PASSWORD} = $target_password;
$ENV{JMX4PERL_USER} = $user;
$ENV{JMX4PERL_PASSWORD} = $password;
$ENV{JMX4PERL_PRODUCT} = $product;

$harness->runtests(@testfiles);

sub prepare_filenames {
    my @files = @_;
    my @ret = ();
    for (@files) {
        my $name = $_;
        $name =~ s|.*/([^/]+)$|$1|;
        push @ret,[ $_, $name ];
    }
    return @ret;
}
