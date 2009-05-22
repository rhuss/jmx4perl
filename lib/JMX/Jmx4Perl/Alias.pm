#!/usr/bin/perl

package JMX::Jmx4Perl::Alias;

use strict;
use Data::Dumper;
use Carp;

=head1 NAME

JMX::Jmx4Perl::Alias - JMX alias names for jmx4perl

=cut 

my %ALIAS_MAP = 
  (attributes => 
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
  MEMORY_HEAP_USED => [ "User heap memory", [ "java.lang:type=Memory", "HeapMemoryUsage", "used" ]],
  MEMORY_HEAP_INIT => [ "Initially allocated heap memory", [ "java.lang:type=Memory", "HeapMemoryUsage", "init" ]],
  MEMORY_HEAP_COMITTED => [ "Committed heap memory", [ "java.lang:type=Memory", "HeapMemoryUsage", "committed" ]],

  # Class loading
  CL_LOADED => [ "Number of currently loaded classes", [ "java.lang:type=ClassLoading", "LoadedClassCount"]],
  CL_UNLOADED => [ "Number of unloaded classes", [ "java.lang:type=ClassLoading", "UnloadedClassCount"]],       
  CL_TOTAL => [ "Number of classes loaded in total", [ "java.lang:type=ClassLoading", "TotalLoadedClassCount"]],
  
  # Threads
  THREAD_COUNT => ["Active threads in the system", [ "java.lang:type=Threading", "ThreadCount"]],
  THREAD_COUNT_PEAK => ["Peak count of active threads in the system", [ "java.lang:type=Threading", "PeakThreadCount"]],
  THREAD_COUNT_STARTED => ["Count of threads started since system start", [ "java.lang:type=Threading", "TotalStartedThreadCount"]],
  THREAD_COUNT_DAEMON => ["Count of threads marked as daemons in the system", [ "java.lang:type=Threading", "DaemonThreadCount"]],
  
  # Operating System
  OS_MEMORY_FREE_PHYSICAL => ["The amount of free physical memory for the OS", [ "java.lang:type=OperatingSystem", "FreePhysicalMemorySize"]],
  OS_MEMORY_FREE_SWAP => ["The amount of free swap space for the OS", [ "java.lang:type=OperatingSystem", "FreeSwapSpaceSize"]],
  OS_MEMORY_TOTAL_PHSICAL => ["The amount of total physical memory for the OS", [ "java.lang:type=OperatingSystem", "TotalPhysicalMemorySize"]],
  OS_MEMORY_TOTAL_SWAP => ["The amount of total swap memory available", [ "java.lang:type=OperatingSystem", "TotalSwapSpaceSize"]],
  OS_MEMORY_VIRTUAL => ["Size of virtual memory used by this process", [ "java.lang:type=OperatingSystem", "CommittedVirtualMemorySize"]],
  OS_FILE_OPEN_DESC => ["Number of open file descriptors", [ "java.lang:type=OperatingSystem", "OpenFileDescriptorCount"]],
  OS_FILE_MAX_DESC => ["Maximum number of open file descriptors", [ "java.lang:type=OperatingSystem", "MaxFileDescriptorCount"]],
  OS_CPU_TIME => ["The cpu time used by this process", [ "java.lang:type=OperatingSystem", "ProcessCpuTime"]],
  OS_INFO_PROCESSORS => ["Numer of processors", [ "java.lang:type=OperatingSystem", "AvailableProcessors"]],
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
  RUNTIME_STARTIME => ["Time when starting the JVM", [ "java.lang:type=Runtime", "StartTime"]],
  RUNTIME_CLASSPATH => ["Classpath", [ "java.lang:type=Runtime", "ClassPath"]],
  RUNTIME_BOOTCLASSPATH => ["Bootclasspath", [ "java.lang:type=Runtime", "BootClassPath"]],
  RUNTIME_LIBRARY_PATH => ["", [ "java.lang:type=Runtime", "LibraryPath"]],
  RUNTIME_NAME => ["", [ "java.lang:type=Runtime", "Name"]],
 },
   
   operations  => 
 {
  # Memory
  MEMORY_GC => [ "Run a garbage collection", [ "java.lang:type=Memory", "gc" ]],

  # Threads
  THREAD_DEADLOCKED => [ "Find cycles of threads that are in deadlock waiting to acquire object monitors", [ "java.lang:type=Threading", "findMonitorDeadlockedThreads"]],
  # TODO: Check for a default
  THREAD_DUMP => [ "Create a thread dump" ]
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
            *{$callpkg."::".$alias} = sub { return bless $object, "JMX::Jmx4Perl::Alias::Object"; };
        }
    };    
}

sub get_by_name {
    my $self = shift;
    my $name = shift;
    my $ret;
    my $alias = $NAME_TO_ALIAS_MAP{$name};
    # Try name in form "memory:heap:usage"
    if ($alias) {
        return $ALIAS_OBJECT_MAP{$alias};
    } 
    # Try name in form "MEMORY_HEAP_USAGE"
    return $ALIAS_OBJECT_MAP{$name};
}

=item JMX::Jmx4Perl::Alias->get_all

Get all aliases defined, sorted by alias name.

=cut

sub get_all {
    return sort { $a->alias cmp $b->alias } values %ALIAS_OBJECT_MAP;
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
              bless {                                           
                     alias => $alias,
                     name => $name,
                     type => $type,
                     description => $ALIAS_MAP{$type}{$alias}[0],
                     default => $ALIAS_MAP{$type}{$alias}[1],
                    },"JMX::Jmx4Perl::Alias::Object";
        }
    }
    $initialized = 1;
}
# ====================================================================================== 
# Internal object representing an alias

package  JMX::Jmx4Perl::Alias::Object;

use Scalar::Util qw(refaddr);

use overload
    q{""} => sub { (shift)->as_string(@_) },
    q{==} => sub { (shift)->equals(@_) },
    q{!=} => sub { !(shift)->equals(@_) };

sub equals { 
    return (ref $_[0] eq ref $_[1] && refaddr $_[0] == refaddr $_[1]) ? 1 : 0;
}

sub as_string { return $_[0]->{alias}; }
sub alias { return shift->{alias}; }
sub name { return shift->{name}; }
sub description { return shift->{description}; }
sub default { return shift->{default}; }
sub type { return shift->{type}; }

1;
