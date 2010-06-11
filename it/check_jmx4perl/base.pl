# Base functions for various check_jmx4perl checks

use strict;
use FindBin;
use JMX::Jmx4Perl::Alias;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Response;

sub exec_check_perl4jmx {
    my @args;
    for (@_) {
        push @args,split;
    }
    my ($url,$user,$password,$product,$target,$target_user,$target_password) = 
      @ENV{"JMX4PERL_GATEWAY","JMX4PERL_USER",
             "JMX4PERL_PASSWORD","JMX4PERL_PRODUCT","JMX4PERL_TARGET_URL","JMX4PERL_TARGET_USER","JMX4PERL_TARGET_PASSWORD"};
    push @args,("--user",$user,"--password",$password) if $user;
    push @args,("--product",$product) if $product;
    push @args,("--url",$url);
    push @args,("--target",$target) if $target;
    push @args,("--target-user",$target_user,"--target-password",$target_password) if $target_user;
#    push @args,("--verbose");
   
    my $cmd = "perl $FindBin::Bin/../../scripts/check_jmx4perl "
          .join(" ",map { '"' . $_ . '"' } @args); 
    #print $cmd,"\n";
    open (F,"$cmd 2>&1 |") 
      || die "Cannot open check_jmx4perl: $!";
    my $content = join "",<F>;
    close F;
    
    if ($? == -1) {
        die "check_jmx4perl: failed to execute: $!\n";
    }
    elsif ($? & 127) {
        die "check_jmx4perl child died with signal %d, %s coredump\n",
          ($? & 127),  ($? & 128) ? 'with' : 'without';
    }
    return ($? >> 8,$content);
}

sub reset_history {
    my $jmx = shift;
    my ($mbean,$operation) = $jmx->resolve_alias(JMX4PERL_HISTORY_RESET);
    my $req = new JMX::Jmx4Perl::Request(EXEC,$mbean,$operation,{target => undef});
    $jmx->request($req);
}

1;
