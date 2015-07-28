package JMX::Jmx4Perl::Nagios::CactiJmx4Perl;

use strict;
use base qw(JMX::Jmx4Perl::Nagios::CheckJmx4Perl);
use Data::Dumper;

=head1 NAME

JMX::Jmx4Perl::Nagios::CactiJmx4Perl - Module for encapsulating the functionality of
L<cacti_jmx4perl> 

=head1 SYNOPSIS

  # One line in check_jmx4perl to rule them all
  JMX::Jmx4Perl::Nagios::CactiJmx4Perl->new(@ARGV)->execute();

=head1 DESCRIPTION

=cut 

sub create_nagios_plugin {
    my $self = shift;

    my $np = Monitoring::Plugin->
      new(
          usage => 
          "Usage: %s -u <agent-url> [-m <mbean>] [-a <attribute>]\n" . 
          "                  [--alias <alias>] [--value <shortcut>] [--base <alias/number/mbean>] [--delta <time-base>]\n" .
          "                  [--name <name>] [--product <product>]\n".
          "                  [--user <user>] [--password <password>] [--proxy <proxy>]\n" .
          "                  [--target <target-url>] [--target-user <user>] [--target-password <password>]\n" .
          "                  [--legacy-escape]\n" . 
          "                  [--config <config-file>] [--check <check-name>] [--server <server-alias>] [-v] [--help]\n" .
          "                  arg1 arg2 ....",
          version => $JMX::Jmx4Perl::VERSION,
          url => "http://www.jmx4perl.org",
          plugin => "cacti_jmx4perl",
          license => undef,
          blurb => "This script can be used as an script for a Cacti Data Input Method",
          extra => "\n\nYou need to deploy jolokia.war on the target application server or an intermediate proxy.\n" .
          "Please refer to the documentation for JMX::Jmx4Perl for further details.\n\n" .
          "For a complete documentation please consult the man page of cacti_jmx4perl or use the option --doc"
         );
    $np->shortname(undef);
    $self->add_common_np_args($np);
    # Add dummy thresholds to keep Nagios plugin happy
    $np->set_thresholds(warning => undef, critical => undef);
    $np->getopts();
    return $np;
}

sub verify_check {
    # Not needed
}

sub do_exit {
    my $self = shift;
    my $error_stat = shift;
    my $np = $self->{np};
    
    my $perf = $np->perfdata;
    my @res;
    for my $p (@$perf) {
        my $label = $p->label;
        $label =~ s/\s/_/g;
        push @res,@$perf > 1 ? $label . ":" . $p->value : $p->value;
    }
    print join(" ",@res),"\n";
    exit 0;
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

=head1 AUTHOR

roland@cpan.org

=cut

1;
