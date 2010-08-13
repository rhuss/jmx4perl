package JMX::Jmx4Perl::J4psh::Shell;

use strict;
use Term::ShellUI;
use Term::ANSIColor qw(:constants);
use Data::Dumper;

=head1 NAME 

JMX::Jmx4Perl::J4psh::Shell - Facade to Term::ShellUI

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut

my $USE_TERM_SIZE;
my $USE_SEARCH_PATH;
BEGIN {
    
    eval {
        require "Term/Size.pm";
        Term::Size->import('chars');
    };
    $USE_TERM_SIZE = $@ ? 0 : 1;

    eval {
        require "File::SearchPath";
        File::SearchPath->import('searchpath');
    };
    $USE_SEARCH_PATH = $@ ? 0 : 1;      
}


sub new { 
    my $class = shift;
    my $self = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    bless $self,(ref($class) || $class);
    $self->_init;
    return $self;
}

sub term {
    return shift->{term};
}

sub commands {
    my $self = shift;
    $self->{term}->commands(@_);
}

# Run ShellUI and never return. Provide some special
# ReadLine treatment
sub run {
    my $self = shift;
    my $t = $self->term;
    
    #$t->{debug_complete}=5;
    $t->run;
}

sub color { 
    my $self = shift;
    my @colors = @_;
    my $args = ref($colors[$#colors]) eq "HASH" ? pop @colors : {};
    if ($self->use_color) {
        if ($args->{escape}) {
            return map { "\01" . $self->_resolve_color($_) . "\02" } @colors;
        } else {
            return map { $self->_resolve_color($_) } @colors;
        }
    } else {
        return map { "" } @colors;
    }
}

sub color_theme {
    return shift->_get_set("color_theme",@_);
}

sub use_color {
    my $self = shift;
    my $value = shift;
    if (defined($value)) {
        $self->{use_color} = $value !~ /^(0|no|never|false)$/i;
    }
    return $self->{use_color};
}


sub _resolve_color {
    my $self = shift;
    my $c = shift;
    my $color = $self->{color_theme}->{$c};
    if (exists($self->{color_theme}->{$c})) {
        return defined($color) ? $color : "";
    } else {
        return $c;
    }
}

# ===========================================================================

sub _init {
    my $self = shift;

    # Create shell object
    my $term = new Term::ShellUI(
                                 history_file => "~/.j4psh_history",
                                );    
    $self->{term} = $term;
    my $rl_attribs = $term->{term}->Attribs;
    #$rl_attribs->{basic_word_break_characters} = " \t\n\"\\'`@$><;|&{(";
    $rl_attribs->{completer_word_break_characters} = " \t\n\\";
    $term->{term}->ornaments(0);

    my $config = $self->{config};
    # Set color mode
    $self->use_color(defined($self->{use_color}) || defined($config->{UseColor}) || "yes");
    # Init color theme
    $self->_init_theme($config->{theme});

    my $use_color = "yes";
    if (exists $self->{args}->{color}) {
        $use_color = $self->{args}->{color};
    } elsif (exists $self->{config}->{usecolor}) {
        $use_color = $self->{config}->{usecolor};
    } 
    $self->use_color($use_color);

    # Force pipe, quit if less than a screen-full.
    my @args = (
                '-f',  # force, needed for color output
#                '-E',  # Exit automatically at end of output
                '-X'   # no init
               );
    if ($self->use_color) {
        # Raw characters
        push @args,'-r';
    }
    if ($ENV{LESS}) {
        my $l = "";
        for my $a (@args) {
            $l .= $a . " " unless $ENV{LESS} =~ /$a/;
        }
        if (length($l)) {
            chop $l;
            $ENV{LESS} .= " " . $l;
        }
    } else {
        $ENV{LESS} = join " ",@args;
    }
    if ($self->{config}->{pager}) {
        $ENV{PAGER} = $self->{config}->{pager};
    } elsif (!$ENV{PAGER}) {
        # Try to find a suitable pager
        if ($USE_SEARCH_PATH) {
            for my $p (qw(less more)) {
                my $pager = searchpath($p, env => 'PATH', exe => 1 );
                if ($pager) {
                    $ENV{PAGER} = $pager;
                    last;
                }
            }
        }
        # No searching available, we rely on Term::Clue for finding the proper
        # pager.
    } 
      
    if ($ENV{PAGER} && $ENV{PAGER} =~ /more$/) {
        # If we are using "more", disable coloring
        $self->use_color("no");
    }
}

sub default_theme {
    my $self = shift;
    # Initial theme
    my $theme_light = { 
                       host => YELLOW,
                       prompt_context => BLUE,
                       prompt_empty => RED,
                       label => YELLOW,
                       domain_name => BLUE,
                       property_key => GREEN,
                       property_value => undef,
                       mbean_name => YELLOW,
                       attribute_name => GREEN,
                       operation_name => YELLOW,
                       stat_val => RED,
                       reset => RESET
                      };
    my $theme_dark = { 
                      host => YELLOW,
                      label => YELLOW,
                      prompt_context => CYAN,
                      prompt_empty => RED,
                      domain_name => YELLOW,
                      property_key => GREEN,
                      property_value => undef,
                      mbean_name => YELLOW,
                      attribute_name => GREEN,
                      operation_name => YELLOW,
                      stat_val => RED,
                      reset => RESET
                     };    
    return $theme_dark;
}


sub readline {
    my $self = shift;
    my $term = $self->term;
    return $term->{term}->ReadLine;
}

sub _init_theme {
    my $self = shift;
    my $theme_config = shift;
    my $theme = $self->default_theme;
    if ($theme_config) {
        for my $k (keys %$theme_config) {
            my $c = $theme_config->{$k};
            $theme->{$k} = $c eq "undef" ? undef : Term::ANSIColor::color($c);
        }
    }
    $self->{color_theme} = $theme;
    return $theme;
}

sub term_width { 
    if ($USE_TERM_SIZE) {
        return (chars)[0];
    } else {
        return 120;
    }
}

sub term_height {
    if ($USE_TERM_SIZE) {
        return (chars)[1];
    } else {
        return 24;
    }
}

=head1 LICENSE

This file is part of jmx4perl.

Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

jmx4perl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or Nagios or JMX in
general), you might want to have a look at
http://www.consol.com/opensource/nagios/. Contact roland.huss@consol.de for
further information (or use the contact form at http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut

1;

