#!/usr/bin/perl

use It;
use Test::More qw(no_plan);
use JMX::Jmx4Perl;
use Data::Dumper;
use strict;

my $jmx = new It(verbose => 0)->jmx4perl;

# Might find nothing, dependening on where it is run.
my $disc_class = urls(JMX::Jmx4Perl->discover_agents());
ok(defined($disc_class));
my $disc_obj = urls($jmx->discover_agents());
ok(defined($disc_obj));

my $agents_found = $jmx->execute("jolokia:type=Discovery","lookupAgents");
print Dumper($agents_found);
print Dumper($disc_class);
my $agent_urls = urls($agents_found);

for my $disc_p ($disc_class,$disc_obj) {
    for my $k (keys %$disc_p) {
        ok(defined($agent_urls->{$k}),"Agent URL " . $k . " detected");
    }
}

sub urls {
    my $agents = shift;
    my $ret = {};
    for my $agent (@$agents) {
        $ret->{$agent->{url}}++;
    }
    return $ret;
}
