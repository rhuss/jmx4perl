#!/usr/bin/perl
package JMX::Jmx4Perl::Site::PodHtml;
use base qw( Pod::POM::View::HTML );

sub view_pod {
    my ($self, $pod) = @_;
    $pod->content->present($self);
}


1;
