use It;
use Data::Dumper;
use Test::More tests => 2;

my $it = new It(verbose => 0);
my $agent = $it->userAgent;
my $j4p = $it->jmx4perl;
my $resp = $agent->get($j4p->url() . "/version");
my $date = $resp->date;
my $expire = $resp->expires;
#print Dumper($resp);
#print "Date: $date\nExpires: $expire\n";
ok($expire <= $date,"expires must be less or equal date");
ok($resp->header('Expires') =~ /\w{3}, \d{1,2} \w{3} \d{4} \d{2}:\d{2}:\d{2} GMT/,"RFC-1123 Format matched");
