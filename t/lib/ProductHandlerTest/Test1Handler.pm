package ProductHandlerTest::Test1Handler;

use JMX::Jmx4Perl::ProductHandler::BaseHandler;
use JMX::Jmx4Perl::Alias;

use vars qw(@ISA);
@ISA = qw(JMX::Jmx4Perl::ProductHandler::BaseHandler);

sub id { return "Test1" };

sub autodetect { return 1; }

sub _init_aliases {
    return { 
            attributes => 
          {
            MEMORY_HEAP => [ "resolved_name", "resolved_attr" ]
          }
           };
}

1;
