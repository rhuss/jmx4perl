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

# Complete on mbean names
sub mbeans {
    my $self = shift;
    my %args = @_;
    my $attr;
    return sub {
        my ($term,$cmpl) = @_;
        my $all = $args{all};
        my $domain = $args{domain};
        #$term->{debug_complete}=5;
        my $context = $self->{context};
        my $mbeans = $context->mbeans_by_domain;
        my $str = $cmpl->{str} || "";
        my $len = length($str);
        if ($domain) {
            my $attrs = $mbeans->{$domain};
            return [] unless $attrs;
            my @kv = map { $_->{string} } @$attrs;
            return [ map { $_ } grep { substr($_,0,$len) eq $str } @kv ];
        } else {
            ($domain,$attr) = split(/:/,$str,2);
            if ($attr || $str =~ /:$/) {
                # Complete on attributes
                my $attrs = $mbeans->{$domain};
                return [] unless $attrs;
                my @kv = map { $_->{string} } @$attrs;
                if ($attr) {
                    return [ map { $domain . ":" . $_ } grep { substr($_,0,length($attr)) eq $attr } @kv ];
                } else {
                    return [ map { $domain . ":" . $_} @kv ];
                }            
            } else {
                # Complete on domains
                my $domains = $str ? [ grep { substr($_,0,$len) eq $str } keys %$mbeans ] : [ keys %$mbeans ];
                if ($all) {
                    $term->suppress_completion_append_character();
                }
                return $domains;
            }
        }
    };
}

sub mbean_attributes {
    return shift->_complete_attr_op(shift,"attr");
}

sub mbean_operations {
    return shift->_complete_attr_op(shift,"op");
}

sub _complete_attr_op {
    my $self = shift;
    my $m_info = shift;
    my $what = shift;
    my $attr;
    #print "> ",Dumper($m_info->{info}->{attr});
    return sub {
        my ($term,$cmpl) = @_;
        my $attrs = $m_info->{info}->{$what};
        #$term->{debug_complete}=5;
        my $context = $self->{context};
        my $str = $cmpl->{str} || "";
        my $len = length($str);
        return [ grep { substr($_,0,$len) eq $str } keys %$attrs ];
    }; 
}


# Method for completing based on key=value for an 
# arbitrary order of key, value pairs
sub _complete_props {
    my $self = shift;
    # List of MBeans for this domain
    my $mbeans_ref = shift;
    my @mbeans = ( @{$mbeans_ref} );
    my $input = shift;
    my $context = $self->{context};
    # Get all already completed
    my @parts = split /,/,$input;
    my $last = pop @parts;
    # Filter out already set types
    for my $p (@parts) {
        my ($k,$v) = split /=/m,$p,2;
        @mbeans = grep { $_->{props}->{$k} eq $v } @mbeans;
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



