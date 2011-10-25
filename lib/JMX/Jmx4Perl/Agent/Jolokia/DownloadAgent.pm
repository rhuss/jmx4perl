#!/usr/bin/perl
package JMX::Jmx4Perl::Agent::Jolokia::DownloadAgent;
use base qw(LWP::UserAgent);
use Data::Dumper;
use vars qw($HAS_PROGRESS_BAR $HAS_TERM_READKEY);
use strict;

BEGIN {
    $HAS_PROGRESS_BAR = eval "require Term::ProgressBar; 1";
    $HAS_TERM_READKEY = eval "require Term::ReadKey; 1";
}
 
=head1 NAME

JMX::Jmx4Perl::Agent::Jolokia::DownloadAgent - Specialized L<LWP::UserAgent>
adding some bells and whistles for downloading agents and other stuff.

=head1 DESCRIPTION

User agent for Jolokia artifact downloading. It decorates a regular User Agent
with a download bar and allows for proxy handling and authentication. For a
progress bar, the optional module L<Term::ProgressBar> must be installed.

=head1 METHODS

=over 4 

=item $ua  = JMX::Jmx4Perl::Agent::Jolokia::DownloadAgent->new(%args)

Create a new user agent, a subclass fro L<LWP::UserAgent>

Options:

   "http_proxy"      HTTP Proxy to use
   "https_proxy"     HTTPS Proxy to use 
   "quiet"           If true, dont show progressbar
   "proxy_user"      Proxy user for proxy authentication
   "proxy_password"  Proxy password for proxy authentication

=back 

=cut 

sub new { 
    my $class = shift;
    my %cfg = ref($_[0]) eq "HASH" ? %{$_[0]} :  @_;
    my $self = LWP::UserAgent::new($class,%cfg);    
    bless $self,(ref($class) || $class);

    # Proxy setting
    $self->env_proxy;
    $self->proxy("http",$cfg{http_proxy}) if $cfg{http_proxy};
    $self->proxy("https",$cfg{https_proxy}) if $cfg{https_proxy};
    $self->{show_progress} = !$cfg{quiet};
    return $self;
}

# Overwriting progress in order to show a progressbar or not
sub progress {
    my($self, $status, $m) = @_;
    return unless $self->{show_progress};
    # Use default progress bar if no progress is given
    unless ($HAS_PROGRESS_BAR) {
        $self->SUPER::progress($status,$m);
        return;
    } 
    if ($status eq "begin") {
        $self->{progress_bar} = undef;
    } elsif ($status eq "end") {
        my $progress = delete $self->{progress_bar};
        my $next = delete $self->{progress_next};
        $progress->update(1) if defined($next) && 1 >= $next;
    } elsif ($status eq "tick") {
        # Unknown length (todo: probably better switch to the default behaviour
        # in SUPER::progress())
        my $progress = $self->_progress_bar($m->filename,undef);
        $progress->update();
    } else {
        # Status contains percentage
        my $progress = $self->_progress_bar($m->filename,1);
        
     #   print $status," ",$HAS_PROGRESS_BAR,"\n";
        $self->{progress_next} = $progress->update($status)
          if $status >= $self->{progress_next};
    }
}

sub _progress_bar {
    my $self = shift;
    my $name = shift;
    my $count = shift;
    my $progress = $self->{progress_bar};
    unless ($progress) {
        no strict;
        local (%SIG);
        $progress = new Term::ProgressBar({
                                           name => "  " . $name, 
                                           count => $count,
                                           remove => 1,
                                           ETA => linear,
                                           !$HAS_TERM_READKEY ? (term_width => 120) : ()
                                          }
                                         );
        #$progress->minor(1);
        $progress->max_update_rate(1);
        $self->{progress_bar} = $progress;
    }
    return $progress;

}


# Get an optional proxy user
sub get_basic_credentials { 
    my ($self, $realm, $uri, $isproxy) = @_;
    
    if ($isproxy && $self->{proxy_user}) {
        return ($self->{proxy_user},$self->{proxy_password});
    } else {
        return (undef,undef);
    }
}

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

1;
