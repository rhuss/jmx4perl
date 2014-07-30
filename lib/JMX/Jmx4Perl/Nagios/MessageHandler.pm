package JMX::Jmx4Perl::Nagios::MessageHandler;

use Nagios::Plugin::Functions qw(:codes %ERRORS %STATUS_TEXT);
use strict;

=head1 NAME

JMX::Jmx4Perl::Nagios::MessageHandler - Handling Nagios exit message (one or
many) 

=cut

sub new {
    my $class = shift;
    my $self = {
                messages => {}
               };
    bless $self,(ref($class) || $class);
    return $self;
}

sub add_message { 
    my $self = shift;
    my ($code,@messages) = @_;
    
    die "Invalid error code '$code'\n"
        unless defined($ERRORS{uc $code}) || defined($STATUS_TEXT{$code});

    # Store messages using strings rather than numeric codes
    $code = $STATUS_TEXT{$code} if $STATUS_TEXT{$code};
    $code = lc $code;
    
    $self->{messages}->{$code} = [] unless $self->{messages}->{$code};
    push @{$self->{messages}->{$code}}, @messages;
}

sub check_messages {
    my $self = shift;
    my %arg = @_;

    for my $code (qw(critical warning ok unknown)) {
        $arg{$code} = $self->{messages}->{$code} || [];
    }

    my $code = OK;
    $code ||= UNKNOWN   if @{$arg{unknown}};
    $code ||= CRITICAL  if @{$arg{critical}};
    $code ||= WARNING   if @{$arg{warning}};
    
    my $message = join( "\n",
                        map { @$_ ? join( "\n", @$_) : () }
                        $arg{unknown},
                        $arg{critical},
                        $arg{warning},
                        $arg{ok} ? (ref $arg{ok} ? $arg{ok} : [ $arg{ok} ]) : []
                      );
    return ($code, $message);
}

1;
