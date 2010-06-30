#!/usr/bin/perl
use Test::More;
use FindBin qw($Bin);
use Data::Dumper;
use JMX::Jmx4Perl::Config;

my $HAS_CONFIG_GENERAL;
BEGIN { 
    eval "use Config::General";
    $HAS_CONFIG_GENERAL = $@ ? 0 : 1;
}
plan tests => $HAS_CONFIG_GENERAL ? 4 : 1;
$SIG{__WARN__} = sub { };
my $config = new JMX::Jmx4Perl::Config("$Bin/j4p_test.cfg");
if ($HAS_CONFIG_GENERAL) {
    is(scalar(keys(%{$config->{server_config}})),2,"2 configuration entries read in");    
    ok($config->server_config_exists("jboss"),"JBoss configuration exists");
    my $s = $config->get_server_config("weblogic");
    is($s->{product},"Weblogic","Proper product found");
    is(scalar(keys(%$s)),5,"Correct number of config elements");
} else {
    ok(scalar(keys(%{$config->{config}})) == 0,"No config read in");
}
