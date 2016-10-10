#!PERL_BIN_DIR/perl
#
## NOTE:  This program must be installed before running!!!!!
##        run:  sh install.sh
#
#
#
#	Name:		ssm.pl
#	Author:   	Jon Christensen (j.christensen@computer.org)
#	Company:  	Protech Engineering Servces
#	Date:		02/24/1999
#
#	Usage:          ssm.pl [-l logfile] [-c Configfile] 
#                       [-r report file] [-s sleeptime] [-D debug_level]
#                       [-S] [-v]
#
#	Modifications:
#                       03/17/1999-
#                          Found that alarm () does not work correctly
#                          for implementing a timeout when trying to access
#                          a hung FS.  Replaced with routine set_timeout
#                          which implements a timeout usint SIGINT.
#                       03/11/1999-
#                          Added Variable definitions for installation.
#                          Several Minor Modifications.  Officially included
#                          as part of release 1.10 of InfoWatcher.
#
# ssm.pl is a companion to the Main slm program.  It checks
# processes, hosts, File Systems, and FDFs (Hey, I used to work for Paracel ;) )
#

eval 'PERL_BIN_DIR/perl -S $0 ${1+"$@"}'
    if 0;

# The location of supporting libs
use lib 'IW_LIB_DIR';
use POSIX qw(setsid uname cuserid strftime);
use POSIX ":sys_wait_h";
use Sys::Syslog;
use Getopt::Std;
use Net::Ping;
require "syscall.ph";
require "IW_support.pl";

sub init
{
   $OSVER               = (POSIX::uname())[2];
   $ENV{'PATH'}         = '/usr/bin:/bin:/opt/ServerOne/sparc-sunos-'.${OSVER}.'/Current/bin:PERL_BIN_DIR:IW_BIN_DIR';
   $ENV{'IFS'}          = '' if $ENV{'IFS'} ne '';
   $ENV{'SHELL'}        = '/bin/sh';
   $0                   = rindex($0,"/")> -1 ? substr($0,rindex($0,"/")+1) : $0;
   $HostName            = (POSIX::uname())[1];

   $VERSION = '1.11';

   $SSM_Config           = "$ENV{'HOME'}/ssm.config";
   $SLM_Log             = "$ENV{'HOME'}/logs/slm.log";
   $LogFile             = "$ENV{'HOME'}/ssm.log";
   $Today               = POSIX::strftime(".%Y%m%d.",localtime(time));
   $Curr_day            = POSIX::strftime(".%Y%m%d.",localtime(time));
   $Max_Log             = 500000; # Max log size
   $Sleep_Time          = 30;     # Default sleep interval 
   $Debug_Level         = 0;    # Debugging flag:  0- OFF
                                #                  1- Minimal
                                #                  2- Maximum

   $Single_Pass         = 0;    # Flag to make a single pass 
                                # through all systems and then exit.

   $Done                = 0;    ### Done monitoring
   $Restart             = 1;    ### Restart monitoring
   $FSTimeOut           = 30;   # Default timout value
   $PPID                = sprintf("%d",$$);

   ####################################################################
   # Get the command line arguments and set the appropriate variables.
   ####################################################################

   getopts("l:c:D:s:r:Sv") || die usage();

   if ($opt_l) { $LogFile = $opt_l }
   if ($opt_c) { $SSM_Config = $opt_c }
   if ($opt_r) { $ReportFile = $opt_r }
   if ($opt_s) { $Sleep_Time = $opt_s }
   if ($opt_S) { $Single_Pass = 1 }

   if ($opt_D) { $Debug_Level = $opt_D }
   if ($opt_v) { usage(); }

   sub usage {

print STDERR <<ENDOFPRINT;

   ssm.pl- A process, space, and host monitoring daemon.
           A companion part of the slm program.
   Version: $VERSION
   Protech Engineering Services 
   02/24/1999

   usage: $0  [-l logfile] [-c Configfile] [-r report file] [-s sleeptime]
                   [-D debug_level] [-S] [-v]

ENDOFPRINT

   exit 1;
   }
}

sub run_as_daemon
{
   chdir "/";
   umask (0);
   return (0);
}

sub run_process
{
   $Restart          = 0;
   my($msg) = sprintf("%s:  *** %s-%s  pid=%s started.",
                       $HostName,${0},${VERSION},$$);
   log_msg($msg,1);
   read_config();

   do {

      if ($Suspend) {
         sleep ($Sleep_Time);
      }  else {
         if ($ReportFile) { print_header(); }
         if ($ReportFile) {
            print REPORT "<center><H2>Processes:</H2><HR></center>\n";
         }
         # Check the companion slm program to ensure it is alive, but only if
         # it's logfile exists.  If it is dead write a message in the correct format
         # to it's logfile.
         if ( -e $SLM_Log) {
            $retval = proc_check("slm ",$HostName);
            if ($retval) {
               $msg = sprintf("FATAL LR8000  %s/%s: ***** slm program not running.",
                       $HostName,$HostName);
               logit($msg,$SLM_Log);
            }
         }
         for $i (0 .. $#PROCS) {
            proc_check($PROCS[$i]->[0], $PROCS[$i]->[1]);
         }
         if ($ReportFile) {
            print REPORT "<center><H2>Hosts:</H2><HR></center>\n";
         }
         for $i (0 .. $#HOSTS) {
            ping_check($HOSTS[$i]);
         }
         if ($ReportFile) {
            print REPORT "<center><H2>FileSystems:</H2><HR></center>\n";
         }
         for $i (0 .. $#FS) {
            df_check($FS[$i]->[0],$FS[$i]->[1]);
         }
         if ($ReportFile) {
            print REPORT "<center><H2>FDFs:</H2><HR></center>\n";
         }
         for $i (0 .. $#FDF) {
            fdf_check($FDF[$i]);
         }

         if ($ReportFile) { print_footer(); }

         $Logsize = (stat $LogFile)[7];
         if ($Logsize >= $Max_Log) { mvlog(); }

         if ($Single_Pass) {
            $Restart = 1;
            $Done    = 1;
         }
         else {
            sleep ($Sleep_Time);
         }
     }
   } until $Restart;

}

#########################################
#
# Support subroutines
#
#########################################

sub read_config
{
   @PROCS = ();
   @HOSTS = ();
   @FS    = ();
   @FDF   = ();
   @lines = ();

   open (IN,"<$SSM_Config") ||
     die "$0: cannot open $SSM_Config: $!\n";
   @lines = <IN>;
   close(IN);

   for ($i=0; $i < @lines; $i++) {
      if ($lines[$i] =~ /^PROCESSES$/) {
         $i++;
         while ($lines[$i] !~ /^HOSTS$/) {
            if ($lines[$i] !~ /^#/ && $lines[$i] !~ /^$/) {
               chomp($lines[$i]);
               push @PROCS, [split(/\t+/,$lines[$i])];
            }
            $i++;
         }
      }
      if ($lines[$i] =~ /^HOSTS$/) {
         $i++;
         while ($lines[$i] !~ /^FS$/) {
            if ($lines[$i] !~ /^#/ && $lines[$i] !~ /^$/) {
               chomp($lines[$i]);
               push @HOSTS,$lines[$i];
            }
            $i++;
         }
      }
      if ($lines[$i] =~ /^FS$/) {
         $i++;
         while ($lines[$i] !~ /^FDF$/) {
            if ($lines[$i] !~ /^#/ && $lines[$i] !~ /^$/) {
               chomp($lines[$i]);
               push @FS,[split(/\t+/,$lines[$i])];
            }
            $i++;
         } 
      }
      if ($lines[$i] =~ /^FDF$/) {
         $i++;
         while ($lines[$i]) {
            if ($lines[$i] !~ /^#/ && $lines[$i] !~ /^$/) {
               chomp($lines[$i]);
               push @FDF,$lines[$i];
            }
            $i++;
         }
      }
   }

   if ($Debug_Level >= 2) {
      print "\nProcess Info\n\n";
      for $i (0 .. $#PROCS) {
         printf "\tProc %3d :  %-25s  %-15s\n",$i,$PROCS[$i]->[0],$PROCS[$i]->[1];
      }
      print "\nHost Info\n\n";
      for $i (0 .. $#HOSTS) {
         printf "\tHost %3d :  %-15s\n",$i,$HOSTS[$i];
      }
      print "\nFS Info\n\n";
      for $i (0 .. $#FS) {
         printf "\tFile System %3d :  %-25s  %5d%\n",$i,$FS[$i]->[0],$FS[$i]->[1];
      }
      print "\nFDF Info\n\n";
      for $i (0 .. $#FDF) {
         printf "\tFDF %3d :  %-15s\n",$i,$FDF[$i];
      }
      print "\n";
   }
}

#
# usage: ping_check($host);
#

sub ping_check
{
   my ($host) = @_;
   $p = Net::Ping->new()
      or log_msg("Couldn't open ping: $!",1);
   if ($p->ping($host)) {
       $msg = sprintf("%20s is Alive",$host);
      log_msg($msg,0);
   } else {
      $msg = sprintf("Host not responding - %20s",$host);
      log_msg($msg,2,"LOG_ERR");
   }
   $p->close;
}

#
# usage: proc_check($proc,$host);
#

sub proc_check
{
   my($proc,$host) = @_;
   my($proclist)   = '';
   if ($Debug_Level >= 1) {
      printf "Checking %20s on %20s\n",$proc,$host;
   }
   if ($HostName eq $host) {
      $proclist = `ps -ef | grep "$proc" | egrep -v " vi |edit | tail | more | cat |grep " 2>/dev/null`;
   }
   else {
      set_timeout(1);
      $proclist = `rsh $host -n 'ps -ef | grep "$proc" | egrep -v " vi |edit | tail | more | cat |grep "' 2>/dev/null`;
      set_timeout(0);
   }
   if (! $proclist) {
      $msg = sprintf("%20s not running on %20s",$proc,$host);
      log_msg ($msg,2,"LOG_ERR"); 
      return -1;
   }
   else {
      $msg = sprintf("%20s running on %20s",$proc,$host);
      log_msg ($msg,0);
      return 0;
   }
}

#
# usage: fdf_check($fdf);
#

sub fdf_check
{
   my($fdf) = @_;
   if ($Debug_Level >= 1) {
      printf "checking FDFs on: %20s\n",$fdf;
   }
   $status = `fdf -h $fdf df 2>&1 | egrep "client library|offline|RPC" 2>&1`;
   if ($status =~ /client library/) {
      log_msg("FDF Error:  Client Library error on host - $fdf",2,"LOG_ERR");
      return;
   }
   elsif ($status =~ /RPC/) {
      log_msg("FDF Error:  RPC Communication problems on host - $fdf",2,"LOG_ERR");
   }
   elsif ($status =~ /offline/) {
      log_msg("FDF Error:  Disks Offline on host - $fdf",2,"LOG_ERR");
   }
   $status = `fdf -h $fdf fdfstat 2>&1 | egrep "RPC|offline|client library|fdf not opened" 2>&1`;
   if ($status =~ /offline/) {
      log_msg("FDF Error:  MPs Offline on host - $fdf",2,"LOG_ERR");
   }
   elsif ($status =~ /client library/) {
      log_msg("FDF Error:  Client Library error on host - $fdf",2,"LOG_ERR");
      return;
   }
   elsif ($status =~ /RPC/) {
      log_msg("FDF Error:  RPC Communication problems on host - $fdf",2,"LOG_ERR");
   }
   elsif ($status =~ /fdf not opened/) {
      log_msg("FDF Error:  FDF device not opened on host - $fdf",2,"LOG_ERR");
   }
}

#
# usage: df_check($dir,$size);
#

sub df_check
{
    my ($dir,$max_size) = @_;
    my ($fmt, $res);

    # struct fields for statfs or statvfs....
    my ($bsize, $frsize, $blocks, $bfree, $bavail, $files, $ffree, $favail);

    $fmt = "\0" x 512;
    set_timeout(1);

    # Depending on operating system you may need to use statfs (i.e. Linux)

    $res = syscall (&main::SYS_statvfs, $dir, $fmt) ;
    set_timeout(0);

    ($bsize, $frsize, $blocks, $bfree, $bavail, $files, $ffree, $favail) =
      unpack ("L8", $fmt);
    
    if (!$blocks) { log_msg ("Could not stat $dir\n",2,"LOG_ERR"); return; }
    $reserved = sprintf("%.2f",($bfree - $bavail)/$blocks);
    $percent = (1-($bavail/($blocks - ($blocks*$reserved))))*100+1;

    if ($percent >= $max_size) {
       $msg = sprintf("FileSystem %-25s is %5d percent full.",$dir,$percent);
       log_msg($msg,2,"LOG_ERR");
    }
    elsif ($percent >= $max_size-10) {
       $msg = sprintf("Warning:  FileSystem %-25s is %5d percent full.",$dir,$percent);
       log_msg($msg,1);
    }
    else {
       $msg = sprintf("FileSystem %-25s is OK.\n",$dir);
       log_msg($msg,0);
    }

}

#
# usage: log_msg($text,$method,$level);
#

sub log_msg
{
   my($msg,$type,$level) = @_;
   if ($Single_Pass) {
      printf STDOUT "     %s\n",$msg;
      return;
   }
   if ($Debug_Level) {
      printf STDOUT "%s\n",$msg;
   }
   if ($type == 0) {
      if ($ReportFile) {
         printf REPORT "<TABLE><TR><TD width = 450><pre><H4>%-55s</H4></pre></TD><TD><pre><H4>Status = GREEN </H4></pre></TD></TR></TABLE>",$msg;
      }
   }
   elsif ($type == 1) {
      logit($msg,$LogFile);
      if ($ReportFile) {
         printf REPORT "<TABLE><TR><TD width = 450><pre><H4>%-55s</H4></pre></TD><TD><pre><H4>Status = YELLOW</H4></pre></TD></TR></TABLE>",$msg;
      }
   }
   elsif ($type == 2) {
      log_sys($msg,$level);
      if ($ReportFile) {
         printf REPORT "<TABLE><TR><TD width = 450><pre><H4>%-55s</H4></pre></TD><TD><pre><H4>Status = RED   </H4></pre></TD></TR></TABLE>",$msg;
      }
   } 
}

sub print_header
{
   open (REPORT,">$ReportFile");
   print REPORT "<head><title>System Status</title></head><body bgcolor=#00BFFF text=#000000>\n";
   print REPORT "<pre>\n";
}

sub print_footer
{
   print REPORT "</pre></body>\n";
   close (REPORT);
}

#
# usage: log_sys($message,$severity);
#

sub log_sys 
{
   my ($message,$severity) = @_;
   openlog ("ssm", "ndelay", "daemon");
   syslog ($severity,$message);
   closelog();
}

#
# usage: mvlog();
#

sub mvlog
{
   my($msg) = '';
   my($log_ext) = '';
   my($newname) = '';

   $msg = sprintf("%s:  Starting new log ...",$HostName);
   log_msg($msg,1);

   $log_ext = POSIX::strftime(".%Y%m%d.%H%M%S",localtime(time));
   $newname = $LogFile.$log_ext;
   rename ($LogFile,$newname);

   $msg = sprintf("%s:  Started new log.",$HostName);
   log_msg($msg,1);
}

####################
#
# Signal handlers
#
####################

#
# quit -- terminate gracefully
#
# usage: quit($SIGNAL);
#

sub quit
{
   my($sig) = @_;
   my($msg) = sprintf("%s:  Caught a SIG%s -- shutting down %s ...",
                          $HostName,$sig,$$);

   logit($msg,$LogFile);
   exit(0);
}

#
# usage: handle_sigint($SIGNAL);
#

sub handle_sigint
{
   my($sig) = @_;
   my($msg) = sprintf("%s:  Caught a SIG%s -- while processing a FileSystem.",
                          $HostName,$sig,$$);
   log_msg($msg,2,"LOG_ERR");
}

#
# restart -- Reread the config file and start over.
#
# usage: restart($SIGNAL);
#

sub restart
{
   my($sig) = @_;
   my($msg) = sprintf("%s:  Caught a SIG%s -- Restarting %s ...",
                        $HostName,$sig,$$);
   logit($msg,$LogFile);
   $Restart = 1;
}

#
# maint -- Hold Monitoring during maintenance.
#
# usage: maint($SIGNAL);
#

sub maint
{
   my($sig) = @_;

   if ($Suspend) {
      $Suspend = 0;
      my($msg) = sprintf("%s:  Caught a SIG%s -- Resuming Monitoring  ...",
                        $HostName,$sig,$$);
      logit($msg,$LogFile);
   }
   else {
      $Suspend = 1;
      my($msg) = sprintf("%s:  Caught a SIG%s -- Suspending Monitoring  ...",
                        $HostName,$sig,$$);
      logit($msg,$LogFile);
   }
}

####################
# Main section
####################

sub main
{
   init();
   run_as_daemon();

   do {
       ############################
       # Set up signal handlers
       ############################

       # catch these signals so that we can clean up before dying
       $SIG{'QUIT'} = $SIG{'TERM'} = 'quit';
       # catch this signal so that we can restart and re-read the config
       $SIG{'HUP'} = 'restart';
       # catch this signal so we stop reporting messages during maintenance
       $SIG{'USR1'} = 'maint';
       # Set up SIGCHLD handler to avoid zombied processes.
       $SIG{'CHLD'} = 'IGNORE';
       
       run_process();

   } until $Done;
}

main();
