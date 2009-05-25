package ProductHandlerTest::Test2Handler;

use JMX::Jmx4Perl::ProductHandler::BaseHandler;
use vars qw(@ISA);
@ISA = qw(JMX::Jmx4Perl::ProductHandler::BaseHandler);

sub id { return "Test2" };

sub autodetect {
    return 0;
}

sub _init_aliases {
    return { attributes => 
           {
            MEMORY_HEAP => [ "resolved2_name", "resolved2_attr" ]
           }
           };
}

1;
