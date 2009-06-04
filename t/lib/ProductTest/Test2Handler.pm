package ProductTest::Test2Handler;

use JMX::Jmx4Perl::Product::BaseHandler;
use vars qw(@ISA);
@ISA = qw(JMX::Jmx4Perl::Product::BaseHandler);

sub id { return "Test2" };

sub autodetect {
    return 0;
}

sub order { 
    return -1;
}

sub init_aliases {
    return { attributes => 
           {
            MEMORY_HEAP => [ "resolved2_name", "resolved2_attr" ]
           }
           };
}

1;
