#!/usr/bin/perl

package JMX::Jmx4Perl::Alias;

use strict;
use Data::Dumper;
use JMX::Jmx4Perl::Alias::Object;
use Carp;

=head1 NAME

JMX::Jmx4Perl::Alias - JMX alias names for jmx4perl

=head1 DESCRIPTION

Aliases are shortcuts for certain MBean attributes and
operations. Additionally, aliasing provides a thin abstraction layer which
allows to map common functionality with different naming schemes across
different application servers. E.g you can access the heap memory usage of your
application by using the alias C<MEMORY_HEAP_USED> regardless how the specific
MBean and its attributes are named on the target application server. Specific
L<JMX::Jmx4Perl::Product> take care about this mapping. 

Alias are normally named hierachically, from the most general to the most
specific, where the parts are separate by underscore
(C<_>). I.e. C<OS_MEMORY_TOTAL_PHYSICAL> specifies the total physical memory
installed on the machine. 

If you C<use> this module, be aware that B<all> aliases are imported in your
name space a subroutines (so that you an use them without a C<$>).

Most of the methods in C<JMX::Jmx4Perl> which allows for aliases can take an
alias in two forms. Either as a constant import by using this module or as
string. The string can be either the name of the alias itself or, as an
alternative format, a lower cased variant where underscores are replaced by
colons. E.g C<"MEMORY_HEAP_USED"> and C<"memory:heap:used"> are both valid
alias names. 

Each alias is an object of the package L<JMX::Jmx4Perl::Alias::Object> which
provides some additional informations about the alias.

To print out all available aliases, sorted by name and with a short
description, you can use the C<help> subroutine, e.g. like in

  perl -MJMX::Jmx4Perl::Alias -e 'JMX::Jmx4Perl::Alias::help'

=head1 METHODS

=over 

=cut

my %ALIAS_MAP = 
  (attribute => 
 {
  # ======================================================================================================== 
  SERVER_VERSION => ["Version of application server"],
  SERVER_NAME => ["Name of server software"],
  SERVER_ADDRESS => [ "IP Address of server, numeric"],
  SERVER_HOSTNAME => [ "Hostname of server"],
  

  # ======================================================================================================== 
  # Standard Java VM Attributes
  # Memory  
  MEMORY_HEAP => [ "Heap memory usage, multiple values", [ "java.lang:type=Memory", "HeapMemoryUsage" ]],
  MEMORY_HEAP_USED => [ "Used heap memory", [ "java.lang:type=Memory", "HeapMemoryUsage", "used" ]],
  MEMORY_HEAP_INIT => [ "Initially allocated heap memory", [ "java.lang:type=Memory", "HeapMemoryUsage", "init" ]],
  MEMORY_HEAP_COMITTED => [ "Committed heap memory. That's the memory currently available for this JVM", [ "java.lang:type=Memory", "HeapMemoryUsage", "committed" ]],
  MEMORY_HEAP_MAX => [ "Maximum available heap memory", [ "java.lang:type=Memory", "HeapMemoryUsage", "max" ]],

  MEMORY_NONHEAP => [ "Non-Heap memory usage, multiple values", [ "java.lang:type=Memory", "NonHeapMemoryUsage" ]],
  MEMORY_NONHEAP_USED => [ "Used non-heap memory (like a 'method area')", [ "java.lang:type=Memory", "NonHeapMemoryUsage", "used" ]],
  MEMORY_NONHEAP_INIT => [ "Initially allocated non-heap memory", [ "java.lang:type=Memory", "NonHeapMemoryUsage", "init" ]],
  MEMORY_NONHEAP_COMITTED => [ "Committed non-heap memory", [ "java.lang:type=Memory", "NonHeapMemoryUsage", "committed" ]],
  MEMORY_NONHEAP_MAX => [ "Maximum available non-heap memory", [ "java.lang:type=Memory", "NonHeapMemoryUsage", "max" ]],

  MEMORY_VERBOSE => [ "Switch on/off verbose messages concerning the garbage collector", ["java.lang:type=Memory", "Verbose"]],

  # Class loading
  CL_LOADED => [ "Number of currently loaded classes", [ "java.lang:type=ClassLoading", "LoadedClassCount"]],
  CL_UNLOADED => [ "Number of unloaded classes", [ "java.lang:type=ClassLoading", "UnloadedClassCount"]],       
  CL_TOTAL => [ "Number of classes loaded in total", [ "java.lang:type=ClassLoading", "TotalLoadedClassCount"]],
  
  # Threads
  THREAD_COUNT => ["Active threads in the system", [ "java.lang:type=Threading", "ThreadCount"]],
  THREAD_COUNT_PEAK => ["Peak thread count", [ "java.lang:type=Threading", "PeakThreadCount"]],
  THREAD_COUNT_STARTED => ["Count of threads started since system start", [ "java.lang:type=Threading", "TotalStartedThreadCount"]],
  THREAD_COUNT_DAEMON => ["Count of threads marked as daemons in the system", [ "java.lang:type=Threading", "DaemonThreadCount"]],
  
  # Operating System
  OS_MEMORY_PHYSICAL_FREE => ["The amount of free physical memory for the OS", [ "java.lang:type=OperatingSystem", "FreePhysicalMemorySize"]],
  OS_MEMORY_PHYSICAL_TOTAL => ["The amount of total physical memory for the OS", [ "java.lang:type=OperatingSystem", "TotalPhysicalMemorySize"]],
  OS_MEMORY_SWAP_FREE => ["The amount of free swap space for the OS", [ "java.lang:type=OperatingSystem", "FreeSwapSpaceSize"]],
  OS_MEMORY_SWAP_TOTAL => ["The amount of total swap memory available", [ "java.lang:type=OperatingSystem", "TotalSwapSpaceSize"]],
  OS_MEMORY_VIRTUAL => ["Size of virtual memory used by this process", [ "java.lang:type=OperatingSystem", "CommittedVirtualMemorySize"]],
  OS_FILE_DESC_OPEN => ["Number of open file descriptors", [ "java.lang:type=OperatingSystem", "OpenFileDescriptorCount"]],
  OS_FILE_DESC_MAX => ["Maximum number of open file descriptors", [ "java.lang:type=OperatingSystem", "MaxFileDescriptorCount"]],
  OS_CPU_TIME => ["The cpu time used by this process", [ "java.lang:type=OperatingSystem", "ProcessCpuTime"]],
  OS_INFO_PROCESSORS => ["Number of processors", [ "java.lang:type=OperatingSystem", "AvailableProcessors"]],
  OS_INFO_ARCH => ["Architecture", [ "java.lang:type=OperatingSystem", "Arch"]],
  OS_INFO_NAME => ["Operating system name", [ "java.lang:type=OperatingSystem", "Name"]],
  OS_INFO_VERSION => ["Operating system version", [ "java.lang:type=OperatingSystem", "Version"]],
  
  # Runtime
  RUNTIME_SYSTEM_PROPERTIES => ["System properties", [ "java.lang:type=Runtime", "SystemProperties"]],
  RUNTIME_VM_VERSION => ["Version of JVM", [ "java.lang:type=Runtime", "VmVersion"]],
  RUNTIME_VM_NAME => ["Name of JVM", [ "java.lang:type=Runtime", "VmName"]],
  RUNTIME_VM_VENDOR => ["JVM Vendor", [ "java.lang:type=Runtime", "VmVendor"]],
  RUNTIME_ARGUMENTS => ["Arguments when starting the JVM", [ "java.lang:type=Runtime", "InputArguments"]],
  RUNTIME_UPTIME => ["Total uptime of JVM", [ "java.lang:type=Runtime", "Uptime"]],
  RUNTIME_STARTTIME => ["Time when starting the JVM", [ "java.lang:type=Runtime", "StartTime"]],
  RUNTIME_CLASSPATH => ["Classpath", [ "java.lang:type=Runtime", "ClassPath"]],
  RUNTIME_BOOTCLASSPATH => ["Bootclasspath", [ "java.lang:type=Runtime", "BootClassPath"]],
  RUNTIME_LIBRARY_PATH => ["The LD_LIBRARY_PATH", [ "java.lang:type=Runtime", "LibraryPath"]],
  RUNTIME_NAME => ["Name of the runtime", [ "java.lang:type=Runtime", "Name"]],

  # Jmx4Perl
  JMX4PERL_HISTORY_SIZE => [ "Size of the history of all attributes and operations in bytes" , ["jmx4perl:type=Config","HistorySize"]],
  JMX4PERL_HISTORY_MAX_ENTRIES => [ "Maximum number of entries per attribute/operation possible" , ["jmx4perl:type=Config","HistoryMaxEntries"]],
  JMX4PERL_DEBUG => [ "Switch on/off debugging by setting this boolean" , ["jmx4perl:type=Config","Debug"]],
  JMX4PERL_DEBUG_MAX_ENTRIES => [ "Maximum number of entries for storing debug info" , ["jmx4perl:type=Config","MaxDebugEntries"]],
 },

   operation  => 
 {
  # Memory
  MEMORY_GC => [ "Run a garbage collection", [ "java.lang:type=Memory", "gc" ]],

  # Threads
  THREAD_DEADLOCKED => [ "Find cycles of threads that are in deadlock waiting to acquire object monitors", [ "java.lang:type=Threading", "findMonitorDeadlockedThreads"]],
  # TODO: Check for a default
  THREAD_DUMP => [ "Create a thread dump" ],

  # Jmx4Perl
  JMX4PERL_HISTORY_MAX_ATTRIBUTE => [ "Set the size of the history for a specific attribute" , ["jmx4perl:type=Config","setHistoryEntriesForAttribute"]],
  JMX4PERL_HISTORY_MAX_OPERATION => [ "Set the size of the history for a specific operation" , ["jmx4perl:type=Config","setHistoryEntriesForOperation"]],
  JMX4PERL_HISTORY_RESET => [ "Reset the history for all attributes and operations" , ["jmx4perl:type=Config","resetHistoryEntries"]],
  JMX4PERL_DEBUG_INFO => [ "Print out latest debug info", ["jmx4perl:type=Config","debugInfo"]],
  JMX4PERL_SERVER_INFO => [ "Show information about registered MBeanServers", ["jmx4perl:type=Config","mBeanServerInfo"]]
 });

my %NAME_TO_ALIAS_MAP;
my %ALIAS_OBJECT_MAP;
my $initialized = undef;

# Import alias names directly into the name space 
# of the importer
sub import {
    my $callpkg = caller;
    &_init() unless $initialized;
    do {
        no strict 'refs';
        for my $alias (keys %ALIAS_OBJECT_MAP) {
            my $object = $ALIAS_OBJECT_MAP{$alias};
            *{$callpkg."::".$alias} = sub { $object };
        }
    };    
}

=item $alias = JMX::Jmx4Perl::Alias->by_name("MEMORY_HEAP_USAGE")

Get an alias object by a name lookup. The argument provided must be a string
containing the name of an alias. If such an alias is not registered, this
method returns C<undef>.

=cut

sub by_name {
    my $self = shift;
    my $name = shift;
    my $ret;
    my $alias = $NAME_TO_ALIAS_MAP{$name};
    #Try name in form "memory:heap:usage"
    if ($alias) {
        return $ALIAS_OBJECT_MAP{$alias};
    } 
    # Try name in form "MEMORY_HEAP_USAGE"
    return $ALIAS_OBJECT_MAP{$name};
}

=item JMX::Jmx4Perl::Alias->all

Get all aliases defined, sorted by alias name.

=cut

sub all {
    return sort { $a->alias cmp $b->alias } values %ALIAS_OBJECT_MAP;
}

=item JMX::Jmx4Perl::Alias::help

Print out all registered aliases along with a short description

=cut

sub help {
    my @aliases = &JMX::Jmx4Perl::Alias::all;
    for my $alias (@aliases) {
        printf('%-30.30s %4.4s %s'."\n",$alias->alias,$alias->type,$alias->description);
    }
}

# Build up various hashes
sub _init {
    %NAME_TO_ALIAS_MAP = ();
    %ALIAS_OBJECT_MAP = ();
    for my $type (keys %ALIAS_MAP) {
        for my $alias (keys %{$ALIAS_MAP{$type}}) {        
            my $name = lc $alias;
            $name =~ s/_/:/g;
            $NAME_TO_ALIAS_MAP{$name} = $alias;
            $ALIAS_OBJECT_MAP{$alias} = 
              new JMX::Jmx4Perl::Alias::Object
                (
                 alias => $alias,
                 name => $name,
                 type => $type,
                 description => $ALIAS_MAP{$type}{$alias}[0],
                 default => $ALIAS_MAP{$type}{$alias}[1],
                );
        }
    }
    $initialized = 1;
}

=back

=head1 ALIASES

The currently aliases are as shown below. Note, that this information might be
outdated, to get the current one, use 

 perl -MJMX::Jmx4Perl::Alias -e 'JMX::Jmx4Perl::Alias::help'

 CL_LOADED                      attr Number of currently loaded classes
 CL_TOTAL                       attr Number of classes loaded in total
 CL_UNLOADED                    attr Number of unloaded classes
 JMX4PERL_DEBUG                 attr Switch on/off debugging by setting this boolean
 JMX4PERL_DEBUG_INFO            oper Print out latest debug info
 JMX4PERL_DEBUG_MAX_ENTRIES     attr Maximum number of entries for storing debug info
 JMX4PERL_HISTORY_MAX_ATTRIBUTE oper Set the size of the history for a specific attribute
 JMX4PERL_HISTORY_MAX_ENTRIES   attr Maximum number of entries per attribute/operation possible
 JMX4PERL_HISTORY_MAX_OPERATION oper Set the size of the history for a specific operation
 JMX4PERL_HISTORY_RESET         oper Reset the history for all attributes and operations
 JMX4PERL_HISTORY_SIZE          attr Size of the history of all attributes and operations in bytes
 JMX4PERL_SERVER_INFO           oper Show information about registered MBeanServers
 MEMORY_GC                      oper Run a garbage collection
 MEMORY_HEAP                    attr Heap memory usage, multiple values
 MEMORY_HEAP_COMITTED           attr Committed heap memory. That's the memory currently available for this JVM
 MEMORY_HEAP_INIT               attr Initially allocated heap memory
 MEMORY_HEAP_MAX                attr Maximum available heap memory
 MEMORY_HEAP_USED               attr Used heap memory
 MEMORY_NONHEAP                 attr Non-Heap memory usage, multiple values
 MEMORY_NONHEAP_COMITTED        attr Committed non-heap memory
 MEMORY_NONHEAP_INIT            attr Initially allocated non-heap memory
 MEMORY_NONHEAP_MAX             attr Maximum available non-heap memory
 MEMORY_NONHEAP_USED            attr Used non-heap memory (like a 'method area')
 MEMORY_VERBOSE                 attr Switch on/off verbose messages concerning the garbage collector
 OS_CPU_TIME                    attr The cpu time used by this process
 OS_FILE_DESC_MAX               attr Maximum number of open file descriptors
 OS_FILE_DESC_OPEN              attr Number of open file descriptors
 OS_INFO_ARCH                   attr Architecture
 OS_INFO_NAME                   attr Operating system name
 OS_INFO_PROCESSORS             attr Number of processors
 OS_INFO_VERSION                attr Operating system version
 OS_MEMORY_PHYSICAL_FREE        attr The amount of free physical memory for the OS
 OS_MEMORY_PHYSICAL_TOTAL       attr The amount of total physical memory for the OS
 OS_MEMORY_SWAP_FREE            attr The amount of free swap space for the OS
 OS_MEMORY_SWAP_TOTAL           attr The amount of total swap memory available
 OS_MEMORY_VIRTUAL              attr Size of virtual memory used by this process
 RUNTIME_ARGUMENTS              attr Arguments when starting the JVM
 RUNTIME_BOOTCLASSPATH          attr Bootclasspath
 RUNTIME_CLASSPATH              attr Classpath
 RUNTIME_LIBRARY_PATH           attr The LD_LIBRARY_PATH
 RUNTIME_NAME                   attr Name of the runtime
 RUNTIME_STARTTIME              attr Time when starting the JVM
 RUNTIME_SYSTEM_PROPERTIES      attr System properties
 RUNTIME_UPTIME                 attr Total uptime of JVM
 RUNTIME_VM_NAME                attr Name of JVM
 RUNTIME_VM_VENDOR              attr JVM Vendor
 RUNTIME_VM_VERSION             attr Version of JVM
 SERVER_ADDRESS                 attr IP Address of server, numeric
 SERVER_HOSTNAME                attr Hostname of server
 SERVER_NAME                    attr Name of server software
 SERVER_VERSION                 attr Version of application server
 THREAD_COUNT                   attr Active threads in the system
 THREAD_COUNT_DAEMON            attr Count of threads marked as daemons in the system
 THREAD_COUNT_PEAK              attr Peak thread count
 THREAD_COUNT_STARTED           attr Count of threads started since system start
 THREAD_DEADLOCKED              oper Find cycles of threads that are in deadlock waiting to acquire object monitors
 THREAD_DUMP                    oper Create a thread dump

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
