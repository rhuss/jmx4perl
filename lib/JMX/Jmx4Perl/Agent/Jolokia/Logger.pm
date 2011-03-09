#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Jolokia::Logger;

use vars qw($HAS_COLOR);
use strict;

=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::Logger - Simple logging abstraction for the
Jolokia agent manager

=head1 DESCRIPTION

Simple Logger used throughout 'jolokia' and its associated modules for
output. It knows about coloring and a quiet mode, where no output is generated
at all.

=cut

BEGIN {
    $HAS_COLOR = eval "require Term::ANSIColor; Term::ANSIColor->import(qw(:constants)); 1";
}


=head1 METHODS

=over 4 

=item $logger = JMX::Jmx4Perl::Agent::Jolokia::Logger->new(quiet=>1,color=>1)

Creates a logger. Dependening on the options (C<quiet> and C<color>) output can
be supressed completely or coloring can be used. Coloring only works, if the
Module L<Term::ANSIColor> is available (which is checked during runtime).

=cut

sub new { 
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };

    my $quiet = delete $self->{quiet};
    $HAS_COLOR &&= $self->{color};
    
    # No-op logger
    return new JMX::Jmx4Perl::Agent::Jolokia::Logger::None
      if $quiet;

    bless $self,(ref($class) || $class);    
}

=item $log->debug("....");

Debug output

=cut 

sub debug {
    my $self = shift;
    if ($self->{debug}) {
        print "+ ",join("",@_),"\n";
    }
}

=item $log->info("....","[em]","....","[/em]",...);

Info output. The tag "C<[em]>" can be used to higlight a portion of the
output. The tag must be provided in an extra element in the given list. 

=cut 


sub info { 
    my $self = shift;
    my $text = $self->_resolve_color(@_);
    my ($cs,$ce) = $HAS_COLOR ? (DARK . CYAN,RESET) : ("","");
    print $cs . "*" . $ce . " " . $text . "\n";
}

=item $log->warn(...)

Warning output (printed in yellow)

=cut 


sub warn { 
    my $self = shift;
    my $text = join "",@_;
    my ($cs,$ce) = $HAS_COLOR ? (YELLOW,RESET) : ("","");
    print $cs. "! " . $text . $ce ."\n";
}

=item $log->warn(...)

Error output (printed in red)

=cut 


sub error {
    my $self = shift;
    my $text = join "",@_;
    my ($cs,$ce) = $HAS_COLOR ? (RED,RESET) : ("","");
    print $cs . $text . $ce . "\n";
}

sub _resolve_color {
    my $self = shift;
    return join "",map { 
        if (lc($_) eq "[em]") {
            $HAS_COLOR ? GREEN : "" 
        } elsif (lc($_) eq "[/em]") {
            $HAS_COLOR ? RESET : ""             
        } else {
            $_ 
        }} @_;
}

=back

=head1 LICENSE

This file is part of jmx4perl.
Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
The Free Software Foundation, either version 2 of the License, or
(at your option) any later version.
 
jmx4perl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
 
You should have received a copy of the GNU General Public License
along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 AUTHOR

roland@cpan.org

=cut


package JMX::Jmx4Perl::Agent::Jolokia::Logger::None;
use base qw(JMX::Jmx4Perl::Agent::Jolokia::Logger);

=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::Logger::None - No-op logger

=head1 DESCRIPTION

No-op logger used when quiet mode is switched on. Doesn't print
out anything.

=cut

sub info { }
sub warn { }
sub error { }
sub debug { }


1;
