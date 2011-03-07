#!/usr/bin/perl

package JMX::Jmx4Perl::Agent::Manager::Verifier;

=head1 NAME

JMX::Jmx4Perl::Agent::Verifier - Handler for various verifiers which picks
the most secure one first.

=cut 

use Data::Dumper;
use vars qw(@VERIFIERS);
use strict;

# Pick the verifier, which is the most reliable

BEGIN { 
    @VERIFIERS = ();
    my @verifiers = (
                     [ "Crypt::OpenPGP", "JMX::Jmx4Perl::Agent::Manager::Verifier::OpenPGPVerifier" ],
                     [ "Digest::SHA1", "JMX::Jmx4Perl::Agent::Manager::Verifier::SHA1Verifier" ],                     
                     [ "Digest::MD5", "JMX::Jmx4Perl::Agent::Manager::Verifier::MD5Verifier" ],                     
                    );
    for my $v (@verifiers) {
        eval "require $v->[0]";
        if (!$@) {
            eval "require $v->[1]";
            die $@ if $@;
            my $verifier;
            eval "\$verifier = new $v->[1]()";
            die $@ if $@;
            push @VERIFIERS,$verifier;
        }
    }
}

sub new { 
    my $class = shift;
    my $self = {@_};
    bless $self,(ref($class) || $class);
}

sub verify {
    my $self = shift;
    my %args = @_;
    my $url = $args{url};
    
    my $ua = new JMX::Jmx4Perl::Agent::Manager::DownloadAgent($self->{ua_config});
    my $log = $self->{logger};
    for my $verifier (@VERIFIERS) {
        my $ext = $verifier->extension;
        if ($ext) {
            my $response = $ua->get($url . $ext);
            if ($response->is_success) {
                my $content = $response->decoded_content;
                $verifier->verify(%args,signature => $content,logger => $log);
                return;
            } else {
                $log->warn($verifier->name . ": Couldn't load $url$ext");
            }
        }
    }
    $log->warn("No suitable validation mechanism found with $url");
}

1;
