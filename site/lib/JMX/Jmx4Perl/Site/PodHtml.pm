#!/usr/bin/perl
package JMX::Jmx4Perl::Site::PodHtml;

use base qw( Pod::POM::View::HTML );
use Data::Dumper;

sub view_pod {
    my ($self, $pod) = @_;
    $pod->content->present($self);
}

sub view_head1 { 
    my $self = shift;
    $self->_parse_head(1,shift);
}
sub view_head2 { 
    my $self = shift;
    $self->_parse_head(2,shift);
}
sub view_head3 { 
    my $self = shift;
    $self->_parse_head(3,shift);
}
sub view_head4 { 
    my $self = shift;
    $self->_parse_head(4,shift);
}

sub _parse_head {
    my $self = shift;
    #print Dumper($self);
    my $level = shift;
    my $head = shift;
    my $title = $head->title;
    my $text = $title->present;
    $text =~ s/(\w)(\w+)/\U\1\E\L\2\E/g;
    #print $title->dump;
    #print $text,"\n";
    return "<h$level>$text</h$level>\n\n" . $head->content->present($self);
}
1;
