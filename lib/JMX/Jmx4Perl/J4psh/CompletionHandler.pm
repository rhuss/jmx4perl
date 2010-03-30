#!/usr/bin/perl

package JMX::Jmx4Perl::J4psh::CompletionHandler;

use strict;
use File::Spec;
use Data::Dumper;

=head1 NAME 

JMX::Jmx4Perl::J4psh::CompletionHandler - Custom completion routines for readline.

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=cut


sub new { 
    my $class = shift;
    my $context = shift || die "No context object given";
    my $self = {
                context => $context
               };
    bless $self,(ref($class) || $class);
    return $self;
}

sub files_extended {
    my $self = shift;
    return sub {
        my $term = shift;
        my $cmpl = shift;
        my $filter = undef;
        
        $term->suppress_completion_append_character();
        
        use File::Spec;
        my @path = File::Spec->splitdir($cmpl->{str} || ".");
        my $dir = File::Spec->catdir(@path[0..$#path-1]);
        my $lookup_dir = $dir;
        if ($dir =~ /^\~(.*)/) {
            my $user = $1 || "";
            $lookup_dir = glob("~$user");
        }
        my $file = $path[$#path];
        $file = '' unless $cmpl->{str};
        my $flen = length($file);
        
        my @files = ();
        $lookup_dir = length($lookup_dir) ? $lookup_dir : ".";
        if (opendir(DIR, $lookup_dir)) {
            if ($filter) {
                @files = grep { substr($_,0,$flen) eq $file && $file =~ $filter } readdir DIR;
            } else {
                @files = grep { substr($_,0,$flen) eq $file } readdir DIR;
            }
            closedir DIR;
            # eradicate dotfiles unless user's file begins with a dot
            @files = grep { /^[^.]/ } @files unless $file =~ /^\./;
            # reformat filenames to be exactly as user typed
            my @ret = ();
            for my $file (@files) {
                $file .= "/" if -d $lookup_dir . "/" . $file;
                $file = $dir eq '/' ? "/$file" : "$dir/$file" if length($dir);
                push @ret,$file;
        }
            return \@ret;
        } else {
            $term->completemsg("Couldn't read dir: $!\n");
            return [];
        }
    }
}

sub servers {
    my $self = shift;
    return sub {
        my ($term,$cmpl) = @_;
        my $context = $self->{context};
        my $server_list = $context->servers->list;
        return [] unless @$server_list;
        my $str = $cmpl->{str} || "";
        my $len = length($str);
        return [ grep { substr($_,0,$len) eq $str }  map { $_->{name} } @$server_list  ];
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



