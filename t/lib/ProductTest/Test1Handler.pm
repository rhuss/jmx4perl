package ProductTest::Test1Handler;

use base qw(JMX::Jmx4Perl::Product::BaseHandler);
use JMX::Jmx4Perl::Alias;


sub id { return "Test1" };

sub autodetect { return 1; }

sub order { 
    return 1;
}
sub init_aliases {
    return { 
            attributes => 
          {
           MEMORY_HEAP => [ "resolved_name", "resolved_attr" ],
           SERVER_NAME => [ 
                           sub { 
                               return ["server","name"]
                           }
                           ],
           SERVER_ADDRESS => sub { 
               return "127.0.0.1";
           }
          }
           };
}

1;
