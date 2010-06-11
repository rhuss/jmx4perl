#!/usr/bin/perl

package JMX::Jmx4Perl::J4psh::CommandHandler;

use strict;
use Data::Dumper;
use Term::ANSIColor qw(:constants);
use Module::Find;

=head1 NAME 

JMX::Jmx4Perl::J4psh::CommandHandler - Handler for j4psh commands

=head1 DESCRIPTION

This object is responsible for managing L<JMX::Jmx4Perl::Command> objects which
are at the heart of j4psh and provide all features. During startup it
registeres commands dynamically and pushes the L<JMX::Jmx4Perl::Shell> context to them
for allowing to access the agent and other handlers.

Registration is occurs in two phases:

...

It also keeps a stack of so called navigational I<context> which can be used to
provide a menu like structure (think of it like directories which can be
entered). If the stack contains elements, the navigational commands C<..> and
C</> are added to traverse the stack. C</> will always jump to the top of the
stack (the I<root directory>) whereas C<..> will pop up one level in the stack
(the I<parent directory>). Commands which want to manipulate the stack like
pushing themselves on the stack should use the methods L</push_on_stack> or
L</reset_stack> (for jumping to the top of the menu).

=cut

=head1 METHODS

=over

=item $command_handler = new JMX::Jmx4Perl::Shell::CommandHandler($context,$ui)

Create a new command handler object. The arguments to be passed are the context
object (C<$context>) and the shell object (C<$shell>) in order to update the
shell's current command set.

=cut 

sub new { 
    my $class = shift;
    my $context = shift || "No context object given";    
    my $shell = shift || "No shell given";
    my $extra = shift;
    $extra = { $extra, @_ } unless ref($extra) eq "HASH";
    my $self = {
                context => $context,
                shell => $shell,
                %{$extra}
               };
    $self->{stack} = [];
    bless $self,(ref($class) || $class);
    $shell->term->prompt($self->_prompt);
    $self->_register_commands;
    return $self;
}

=item $comand_handler->push_on_stack($context,$cmds)

Update the stack with an entry of name C<$context> which provides the commands
C<$cmds>. C<$cmds> must be a hashref as known to L<Term::ShellUI>, whose
C<commands> method is used to update the shell. Additionally it updates the
shell's prompt to reflect the state of the stack.

=cut 

sub push_on_stack {
    my $self = shift;
    # The new context
    my $context = shift;
    # Sub-commands within the context
    my $sub_cmds = shift;
    my $separator = shift || "/";
    my $contexts = $self->{stack};
    push @$contexts,{ name => $context, cmds => $sub_cmds, separator => $separator };
    #print Dumper(\@contexts);

    my $shell = $self->{shell};
    # Set sub-commands
    $shell->commands
      ({
        %$sub_cmds,
        %{$self->_global_commands},
        %{$self->_navigation_commands},
       }
      );    
}

=item $command_handler->reset_stack

Reset the stack and install the top and global commands as collected from the
registered L<OSGi::Osgish::Command>.

=cut

sub reset_stack {
    my $self = shift;
    my $shell = $self->{shell};
    $shell->commands({ %{$self->_top_commands}, %{$self->_global_commands}});
    $self->{stack} = [];
}

=item $command = $command_handler->command($command_name) 

Get a registered command by name

=cut 

sub command {
    my $self = shift;
    my $name = shift || die "No command name given";
    return $self->{commands}->{$name};
}

=back

=cut

# ============================================================================

sub _top_commands {
    my $self = shift;
    my $top = $self->{top_commands};
    my @ret = ();
    for my $command (values %$top) {
        push @ret, %{$command->top_commands};        
    }
    return { @ret };
}

sub _global_commands {
    my $self = shift;
    my $globals = $self->{global_commands};
    my @ret = ();
    for my $command (values %$globals) {
        push @ret, %{$command->global_commands};        
    }
    return { @ret };
}


sub _navigation_commands {
    my $self = shift;
    my $shell = $self->{shell};
    my $contexts = $self->{stack};
    if (@$contexts > 0) {
        return 
            {".." => {
                      desc => "Go up one level",
                      proc => 
                      sub { 
                          $self->pop_off_stack();
                      }
                     },
             "/" => { 
                     desc => "Go to the top level",
                     proc => 
                     sub { 
                         $self->reset_stack();
                     }
                    }
            };
    } else {
        return {};
    }
}

# Go up one in the hierarchy
sub pop_off_stack {
    my $self = shift;
    my $shell = $self->{shell};
    my $stack = $self->{stack};
    my $parent = pop @$stack;
    if (@$stack > 0) {
        $shell->commands
          ({
            %{$stack->[$#{$stack}]->{cmds}},
            %{$self->_global_commands},
            %{$self->_navigation_commands},
           }
          );    
    } else { 
        $shell->commands({ 
                          %{$self->_top_commands},
                          %{$self->_global_commands},
                         });
    }
}

sub _register_commands { 
    my $self = shift;
    my $context = $self->{context};
    my $modules = $self->find_commands();
    my $commands = {};
    my $top = {};
    my $globals = {};
    for my $module (@$modules) {
        my $file = $module;
        $file =~ s/::/\//g;
        require $file . ".pm";
        $module->import;
        my $command = eval "$module->new(\$context)";
        die "Cannot register $module: ",$@ if $@;
        $commands->{$command->name} = $command;
        my $top_cmd = $command->top_commands;
        if ($top_cmd) {
            $top->{$command->name} = $command;
        }
        my $global_cmd = $command->global_commands;
        if ($global_cmd) {
            $globals->{$command->name} = $command;
        }
    }
    $self->{commands} = $commands;
    $self->{top_commands} = $top;
    $self->{global_commands} = $globals;
    $self->reset_stack;
}

sub find_commands { 
    my $self = shift;
    my $command_pkgs = ref($self->{command_packages}) eq "ARRAY" ? $self->{command_packages} : [ $self->{command_packages} ];
    my @modules = ();
    for my $pkg (@{$command_pkgs}) {
        for my $command (findsubmod $pkg) {
            next unless $command;
            push @modules,$command;
        }
    }
    if ($self->{command_modules}) {
        my $command_modules = 
          ref($self->{command_modules}) eq "ARRAY" ? $self->{command_modules} : [ $self->{command_modules} ];
        for my $command (@$command_modules) {
            push @modules,$command;
        }
    }
    return \@modules;
}

sub _prompt {
    my $self = shift;
    my $context = $self->{context};
    my $shell = $self->{shell};
    return sub {
        my $term = shift;
        my $stack = $self->{stack};
        my $agent = $context->agent;
        my ($c_host,$c_context,$c_empty,$reset) = 
          $self->{no_color_prompt} ? ("","","","") : $shell->color("host","prompt_context","prompt_empty",RESET,{escape => 1});
        my $p = "[";
        $p .= $agent ? $c_host . $context->server : $c_empty . $context->name;
        $p .= $reset;
        $p .= " " . $c_context if @$stack;
        for my $i (0 .. $#{$stack}) {
            $p .= $stack->[$i]->{name};
            $p .= $i < $#{$stack} ? $stack->[$i]->{separator} : $reset;
        }
        $p .= "] : ";
        return $p;
    };
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



