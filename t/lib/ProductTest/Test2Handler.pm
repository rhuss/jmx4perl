package ProductTest::Test2Handler;

use base qw(JMX::Jmx4Perl::Product::BaseHandler);

sub id { return "Test2" };

sub autodetect {
    return 0;
}

sub order { 
    return -1;
}

sub init_aliases {
    return 
    { 
     attributes => {
                    MEMORY_HEAP => [ "resolved2_name", "resolved2_attr" ]
                   },
     operations => { 
                    MEMORY_GC => [ "memory2_name", "gc2_op" ]
                   }
    };
}

1;
