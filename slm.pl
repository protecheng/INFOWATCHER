#!PERL_BIN_DIR/perl
#
## NOTE:  This program must be installed before running!!!!!
##        run:  sh install.sh
#
#
#
#	Name:		slm.pl
#	Author:   	Jon Christensen (j.christensen@computer.org`)
#	Company:  	ProTech Engineering Services	
#	Date:		11/14/1998
#
#	Usage:  	slm.pl [-c Config_File] [-l logfile] \
#                                  [-A Action_Seperator] [-P Pattern_Seperator] \
#                                  [-s sleeptime] [-D debug_level] \
#                                  [-t logtime] [-S] [-v]
#
#	Modifications:
#                       11/25/1998-
#                          Multiple modifications to program and a couple
#                          documentation changes.  Upped version to 0.2 
#                          Thanks to Sean Murphy (SRA) and Chris Murphy
#                          (RABA Inc.) for their reviews and suggestions.
#                       11/27/1998-
#                          Complete rewrite of the main program. slm 
#                          no longer builds a child on the fly and spawns
#                          it.  All the work is done by the main program.
#                          Upped version to 0.3.
#                       11/29/1998-
#                          Modifications to handle dated logfiles, start
#                          a new logfile when it reaches 500KB or at midnight. 
#                          Added more checking to ensure nothing is
#                          missed in the logfiles.  Upped version to 0.4.
#			12/23/1998-
#                          Several minor bug fixes. Upped version to 0.5.
#                       01/07/1999-
#                          Fixed the way the skip_message() routine handles
#                          interval messages, and added a feature to enable
#                          a user to specify a minimum message count to 
#                          be exceeded before actions are taken.  Also fixed
#                          a couple minor bugs.  Upped version to 1.0.
#                       02/03/1999-
#                          Changed the point where the time stamp was added
#                          to the messages.  This was made necessary by the
#                          newly modified skip_message() routine.  Couple
#                          minor cleanups.  Also added debug level 3.
#                       03/05/1999-
#                          Changed debug 3 to Single_Pass.  Fixed a typo
#                          that caused the text in mail messages to be
#                          incorrect. Upped version to 1.01.
#                       03/09/1999-
#                          Added companion program "slm.pl" to
#                          check File System status, FDFs (since they are
#                          they are one of the major types of systems we 
#			   have ;) ), processes, and Hosts to ensure they 
#                          are alive.  The suite of programs is now known 
#                          as InfoWatcher. Upped version to 1.10.
#                       03/17/1999-
#                          Found that alarm () does not work correctly
#                          for implementing a timeout when trying to access
#                          a hung FS.  Replaced with routine set_timeout
#                          which implements a timeout usint SIGINT.
#                          Modified the error levels and upped version to 1.11.
#
#
#
# InfoWatcher is a complete rewrite of the following program written by Todd 
# Atkins.  It was written to run as a daemon process and is able to monitor
# multiple files simultaneously without hanging mounted filesystems. 
# There are numerous other modifications (especially in message handling
# and multiple bug fixes.
#
#   
# Swatch -- Simple Watcher
# Created on Thu Mar 19 10:10:19 PST 1992 by Todd.Atkins@CAST.Stanford.EDU
#
# Copyright (1995) The Board of Trustees of the Leland Stanford Junior
# Univeristy.  Except for commercial resale, lease, license or other commercial
# transactions, permission is hereby given to use, copy, modify, and distribute
# this software -- by exercising this permission you agree that this Notice
# shall accompany this software at all times. 
# 
# STANFORD MAKES NO REPRESENTATIONS OR WARRANTIES OF ANY KIND CONCERNING
# THIS SOFTWARE.
#

eval 'PERL_BIN_DIR/perl -S $0 ${1+"$@"}'
     if 0;

# The location of supporting libs
use lib 'IW_LIB_DIR';
use POSIX qw(setsid uname cuserid strftime);
use POSIX ":sys_wait_h";
use Getopt::Std;
require 'IW_support.pl';

sub init
{
   $ENV{'PATH'}         = '/usr/bin:/bin:PERL_BIN_DIR:IW_BIN_DIR';
   $ENV{'IFS'}          = '' if $ENV{'IFS'} ne '';
   $0                   = rindex($0,"/")> -1 ? substr($0,rindex($0,"/")+1) : $0;
   $HostName            = (POSIX::uname())[1];

   $VERSION = '1.11';

   # Some defaults
   $LogFile             = "$ENV{'HOME'}/logs/slm.log";
   $SLM_Config      = "$ENV{'HOME'}/slm.config";
   $Today               = POSIX::strftime(".%Y%m%d.",localtime(time));
   $Curr_day            = POSIX::strftime(".%Y%m%d.",localtime(time));
   $PatternSeparator    = ',';
   $ActionSeparator     = ',';
   $Sleep_Time          = 60;   # Number of seconds to sleep between checks
   $PPID                = sprintf("%d",$$); # Parent Pid.
   $FSTimeOut           = 30;   # Default value for implementing a timeout interval.
   $Debug_Level         = 0;    # Debugging flag:  0- OFF
                                #                  1- Minimal
                                #                  2- Maximum
   $Single_Pass         = 0;    # Flag to make a single pass 
                                # through all files and then exit.

   $Done                = 0;       ### Done monitoring
   $Restart             = 1;       ### Restart monitoring
   $Max_Log             = 500000;  ### Max log size in KB
   $START_INFO          = "INFO  LR0001";
   $SIG_HUP_INFO        = "INFO  LR0002";
   $SIG_INFO            = "INFO  LR0003";
   $SIG_TERM_WARN       = "WARN  LR2001";
   $OPEN_ERROR          = "ERROR LR4001";
   $FORK_FATAL          = "FATAL LR8001";

   ####################################################################
   # Get the command line arguments and set the appropriate variables.
   ####################################################################

   getopts("l:c:s:A:P:D:t:vS") || die usage();

   if ($opt_l) { $LogFile = $opt_l }
   if ($opt_c) { $SLM_Config = $opt_c }
   if ($opt_s) { $Sleep_Time = $opt_s }
   if ($opt_A) { $ActionSeparator = $opt_A }
   if ($opt_P) { $PatternSeparator = $opt_P }
   if ($opt_S) { $Single_Pass = 1; print "\n"; }

   if ($opt_D) { $Debug_Level = $opt_D }
   if ($opt_v) { usage(); }

   sub usage {

print STDERR <<ENDOFPRINT;

   slm.pl- A log monitoring and filter daemon program.
   Version: $VERSION
   Protech Engineering Services 
   03/12/1999

   usage: $0  [-l logfile] [-c Configfile] [-s sleeptime]
                   [-A action_separator] [-P pattern_separator]
                   [-D debug_level] [-S] [-v]

ENDOFPRINT

   exit 1;
   }
}

sub run_as_daemon
{
   if (!$Single_Pass) {
      FORK: {
         if (($pid=fork) < 0) { return (1); }
         elsif ($pid != 0) { exit (0); }

         setsid ();
         chdir "/";
         umask (0);
         return (0);
      }
   }
}

sub run_process
{
   my($curr_dev)     = 0;
   my($curr_ino)     = 0;
   my($curr_off)     = 0;
   my($curr_time)    = 0;
   my($file_to_read) = '';
   $Restart          = 0;

   my($msg) = sprintf("%s  %s/%s: ***** %s-%s  pid=%s started.",
                       $START_INFO,$HostName,$HostName,${0},${VERSION},$$);
   logit($msg,$LogFile);

   if ($Debug_Level >= 1) {
      print "$msg\n";
   }

   read_config();

   do {
      foreach $Monitor_File (keys %FILES) {
         if ($Monitor_File =~ /\.\$T\./) {
            $Curr_day = POSIX::strftime(".%Y%m%d.",localtime(time));
            $file_to_read = $Monitor_File;
            $file_to_read =~ s/\.\$T\./$Curr_day/;
            if ($FILES{$Monitor_File}{"current"} ne $file_to_read) {
               $curr_dev = 0;
               set_timeout(1);
               ($curr_dev,$curr_ino,$curr_off,$curr_time) =
                    (stat $FILES{$Monitor_File}{"current"})[0,1,7,9] or
                    $file_to_read = $FILES{$Monitor_File}{"current"};
               set_timeout(0);
               if(!$curr_dev) { $file_to_read = $FILES{$Monitor_File}{"current"}; } 
               if ($curr_time != $FILES{$Monitor_File}{"time"}) {
                  process_file($FILES{$Monitor_File}{"current"},$curr_dev,
                               $curr_ino,$curr_off,$curr_time);
               }
               $FILES{$Monitor_File}{"current"} = $file_to_read;
            }
         }
         else {
            $file_to_read = $Monitor_File;
         }

         $curr_dev = 0;
         set_timeout(1);
         ($curr_dev,$curr_ino,$curr_off,$curr_time) =
                               (stat $file_to_read)[0,1,7,9];
         set_timeout(0);
         if(!$curr_dev) { next; }
         if ($Single_Pass) {
            process_file($file_to_read,$curr_dev,$curr_ino,0,$curr_time);
         }
         else {
            next unless ($curr_time != $FILES{$Monitor_File}{"time"});
            process_file($file_to_read,$curr_dev,$curr_ino,$curr_off,$curr_time);
         }
      }

      # Check size of log and Current date before we sleep.
      # If size > $Max_Log KB, or date is new, mv it and start a new log.

      $Logsize = (stat $LogFile)[7];
      if ($Logsize >= $Max_Log || $Today ne $Curr_day) { mvlog(); }

      # Check for expired times on Interval messages

      my($now_time) = time;
      foreach $msgkey ( keys %Interval_MSG ) {

         if ($Debug_Level >= 1) {
            print "Interval Message key:  $msgkey\n";
         }

         if ($Single_Pass) {
            $now_time = $now_time + (24*3600);  # Expire all messages
            if (defined $Interval_MSG{$msgkey}{"MinC"}) {
               $Interval_MSG{$msgkey}{"MinC"} = 0;  # Print message no matter what minimum count
            }
         }

         if (defined $Interval_MSG{$msgkey}) {
            if (($now_time - $Interval_MSG{$msgkey}{"Time"}) > $Interval_MSG{$msgkey}{"Interval"} &&
                 $Interval_MSG{$msgkey}{"Count"} >= $Interval_MSG{$msgkey}{"MinC"}) {
               $Interval_MSG{$msgkey}{"Time"} = $now_time - $Interval_MSG{$msgkey}{"Time"};
               $echo_message = format_message($msgkey,0);
               perform_actions($Interval_MSG{$msgkey}{"Pattern"});
               delete $Interval_MSG{$msgkey};
            } 
            elsif (($now_time - $Interval_MSG{$msgkey}{"Time"}) > $Interval_MSG{$msgkey}{"Interval"} && 
                    $Interval_MSG{$msgkey}{"Count"} < $Interval_MSG{$msgkey}{"MinC"}) {
               delete $Interval_MSG{$msgkey};
            }
         }
      }

      if ($Single_Pass) {
         $Restart = 1;
         $Done    = 1;
      }
      else {
         sleep ($Sleep_Time);
      }
   } until $Restart;
}

#
#  Read new information out of a log file 
#
 
sub process_file
{
   my($file_to_read,$curr_dev,$curr_ino,$curr_off,$curr_time) = @_;
   my($buf)          = 0;

   if ($Debug_Level >= 2) {
      print "\n$Monitor_File\n\n";
      print "Host:   $FILES{$Monitor_File}{\"host\"}\n";
      print "dev:   $FILES{$Monitor_File}{\"dev\"}\n";
      print "off:   $FILES{$Monitor_File}{\"off\"}\n";
      print "ino:   $FILES{$Monitor_File}{\"ino\"}\n";
      print "time:   $FILES{$Monitor_File}{\"time\"}\n";
      print "data:   $FILES{$Monitor_File}{\"data\"}\n";
   }

   my($msg) = sprintf("%s  %s/%s: Can't open %s for monitoring.",
        $OPEN_ERROR,$HostName,$FILES{$Monitor_File}{"host"},$Monitor_File);
   open(INPUT_F,"<$file_to_read") || logit($msg,$LogFile);
   if ($curr_off > $FILES{$Monitor_File}{"off"} and
         ($curr_dev == $FILES{$Monitor_File}{"dev"} &&
         $curr_ino == $FILES{$Monitor_File}{"ino"})){
      seek ( INPUT_F, $FILES{$Monitor_File}{"off"}-100, 0 );
      read ( INPUT_F, $buf, 100);
      if ($FILES{$Monitor_File}{"data"} eq $buf) {
         seek ( INPUT_F, $FILES{$Monitor_File}{"off"}, 0 );
      }
      else {
         seek ( INPUT_F, 0, 0 );
      }
   }
   $FILES{$Monitor_File}{"dev"}  = $curr_dev;
   $FILES{$Monitor_File}{"ino"}  = $curr_ino;
   $FILES{$Monitor_File}{"off"}  = $curr_off;
   $FILES{$Monitor_File}{"time"} = $curr_time;
   if ($Debug_Level >= 1) {
      print "\nFile Changed:    $Monitor_File\n";
   }
   while (<INPUT_F>) {
      chomp;
      filter_msgs();
   }
   seek ( INPUT_F, $FILES{$Monitor_File}{"off"}-100, 0 );
   read ( INPUT_F, $FILES{$Monitor_File}{"data"}, 100);
   close(INPUT_F);
}

#
#  Filter the messages
#

sub filter_msgs
{
   my($value)           = '';
   my($hit_flag)        = 0;

   for $i (0 .. $#PATTERNS) {
      @Patterns = split($PatternSeparator, $PATTERNS[$i]->[0]);

      ### Check each pattern until we find a match. ###
      foreach $Pattern (@Patterns) {
         if ($Debug_Level >= 2) {
            print "Pattern:  $Pattern\n";
            print "INPUT:    $_\n";
         }

         if ($_ =~ $Pattern) {
            if ($PATTERNS[$i]->[1] =~ /ignore/o) { #If the action is ignore, short circuit processing
               return;
            }
            if ($Debug_Level >= 1) {
               print "Hit on pattern: $Pattern\n";
            }
            $hit_flag = 1;
            $MessageNum = $PATTERNS[$i]->[2];
            last;
         }
      }

      if ($hit_flag) {
         if ($Debug_Level >= 1) {
            print "Hit on MSG#:  $MessageNum\n";
         }
         if (exists $MSGS{$MessageNum} ) {
            if ($MessageNum eq "LR0000" || $MessageNum eq "LR2000" || 
                $MessageNum eq "LR4000" || $MessageNum eq "LR6000" ) {
               $new_msg = sprintf("%s %s  %s/%s: %s - $_\n",
                          $MSGS{$MessageNum}{"severity"},$MessageNum,$HostName,$FILES{$Monitor_File}{"host"},
                          $FILES{$Monitor_File}{"loginfo"});
            }
            else {
               $new_msg = sprintf("%s %s  %s/%s: %s - %s\n",
                          $MSGS{$MessageNum}{"severity"},$MessageNum,$HostName,$FILES{$Monitor_File}{"host"},
                          $FILES{$Monitor_File}{"loginfo"},$MSGS{$MessageNum}{"text"});
            }
         }

         if ($Debug_Level >= 1) {
            print "Message Text:  $new_msg\n";
         }

         ### Insert history list check if necessary ###
         if (defined $PATTERNS[$i]->[3]) {
            $Interval = hms2s(@{$PATTERNS[$i]}[3]);
            if (defined $PATTERNS[$i]->[4]) { $min_count = $PATTERNS[$i]->[4]; }
            else { $min_count = 0; }
            if (! skip_message($PATTERNS[$i]->[0], $FILES{$Monitor_File}{"host"}, 
                               $Interval,$min_count,$i,$new_msg)) {
               $echo_message = format_message($PATTERNS[$i]->[0].".".$FILES{$Monitor_File}{"host"},1);
               perform_actions($i);
            }
         }
         else {
            $echo_message = $new_msg;
            perform_actions($i);
         }

         last;                   #Short circuit looping since we found
                                 #a pattern and sent a message
         $hit_flag = 0;          #Reset the hitflag
      }
   }
}

#
# Perform the appropriate actions for the corresponding filter pattern
#

sub perform_actions
{
   my($index)     = @_;
   my($username)  = POSIX::cuserid();

   # Add a time stamp to the front of the message.
   $fmt_time = log_time();
   $print_message = sprintf("$fmt_time  %s",$echo_message);
   if ($Single_Pass) { printf "$print_message"; return; }
   
   @Actions = split($ActionSeparator, $PATTERNS[$index]->[1]);
   foreach $Action (@Actions) {
      ($Action, $value) = split("=", $Action, 2);
      $Action =~ tr/A-Z/a-z/;

      if ("log" eq $Action) {
         open(LOG,">>$LogFile") ||
             die "$0: cannot open $LogFile: $!";
         printf LOG "$print_message";
         close(LOG);
      } elsif ("exec" eq $Action || "system" eq $Action) {
         die "$0: 'exec' action requires a value \n" if !$value;
         if ("exec" eq $Action) {
            $cmd = convert_command($value);
            exec_it($cmd);
         } else {
            $cmd = convert_command($value);
            system($cmd);
         }
      } elsif ("mail" eq $Action) {
         $value = $username unless $value;
         mail_it($value, $print_message);
      } elsif ("write" eq $Action) {
         $value = $username unless $value;
         write_it($value, $print_message);
      } else {
         open(LOG,">>$LogFile") ||
             die "$0: cannot open $LogFile: $!";
         chomp $print_message;
         printf LOG "$print_message ****unrecognized action: $Action\n";
         close(LOG);
      }
   }

}


#########################################
#
# Support subroutines
#
#########################################


#
# convert_command -- convert wildcards for fields in command from
#       awk type to perl type.  Also, single quote wildcards
#       for better security.
#
# usage: convert_command($Command);
#

sub convert_command
{
   my($command) = @_;

   $command =~ s/\$[0*]/\$_/g;
   $command =~ s/\$([1-9])/\$_[$1]/g;

   return $command;
}

sub read_config
{
   my($filenam,$temp);
   @PATTERNS            = ();
   undef %FILES;
   undef %MSGS;
   @lines = ();

   open (IN,"<$SLM_Config") ||
     die "$0: cannot open $SLM_Config: $!\n";
   @lines = <IN>;
   close(IN);

   for ($i=0; $i < @lines; $i++) {
      if ($lines[$i] =~ /^FILES$/) {
         $i++;
         while ($lines[$i] !~ /^FILTERS$/) {
            if ($lines[$i] !~ /^#/ && $lines[$i] !~ /^$/) {
               chomp($lines[$i]);
               ($filenam,$host,$lognam) = split (/\t+/,$lines[$i]);

               $tmp = $filenam;
               if ($filenam =~ /\.\$T\./) {
                  $time = POSIX::strftime(".%Y%m%d.",localtime(time));
                  $filenam =~ s/\.\$T\./$time/;
               }
               my($msg) = sprintf("%s  %s/%s: Can't open %s for monitoring.",
                          $OPEN_ERROR,$HostName,$host,$filenam);

               $key = $tmp;
               $FILES{$key}{"current"} = $filenam;
               $FILES{$key}{"host"} = $host;
               $FILES{$key}{"loginfo"} = $lognam;
               set_timeout(1);
               ($FILES{$key}{"dev"},$FILES{$key}{"ino"},$FILES{$key}{"off"},
                   $FILES{$key}{"time"}) = (stat ($filenam))[0,1,7,9] or
                   logit($msg,$LogFile);
               set_timeout(0);
               if (!$FILES{$key}{"dev"} || !(-r $filenam)) { 
                  logit($msg,$LogFile); $i++; delete $FILES{$key}; next; 
               }
               open(INPUT_F,"<$filenam") or logit($msg,$LogFile);
               seek ( INPUT_F, $FILES{$key}{"off"}-100, 0 );
               read ( INPUT_F, $FILES{$key}{"data"}, 100);
               close(INPUT_F);
            }
            $i++;
         }
      }
      if ($lines[$i] =~ /^FILTERS$/) {
         $i++;
         while ($lines[$i] !~ /^MESSAGES$/) {
            if ($lines[$i] !~ /^#/ && $lines[$i] !~ /^$/) {
               chomp($lines[$i]);
               push @PATTERNS, [split(/\t+/, $lines[$i])];
            }
            $i++;
         }
      }
      if ($lines[$i] =~ /^MESSAGES$/) {
         $i++;
         while ($lines[$i]) {
            if ($lines[$i] !~ /^#/ && $lines[$i] !~ /^$/) {
               chomp($lines[$i]);
               ($msg_num,$severity,$text) = split (/\t+/,$lines[$i]);
               $MSGS{$msg_num}{"severity"} = $severity;
               $MSGS{$msg_num}{"text"} = $text;
            }
            $i++;
         }
      }
   }

   if ($Debug_Level >= 2) {
      print "\nFiles Info\n";
      foreach $file ( keys %FILES ) {
         print "\n$file: \n\n";
         foreach $part ( keys %{ $FILES{$file} } ) {
            print "$part=$FILES{$file}{$part} \n";
         }
      }
      print "\nPattern Info\n\n";
      for $i (0 .. $#PATTERNS) {
         print "LINE $i";
         print "\t [ $PATTERNS[$i]->[0] ]\n";
         print "\t [ $PATTERNS[$i]->[1] ]\n";
         print "\t [ $PATTERNS[$i]->[2] ]\n";
         print "\t [ $PATTERNS[$i]->[3] ]\n";
         print "\t [ $PATTERNS[$i]->[4] ]\n";
      }
      print "\nMessages Info\n\n";
      foreach $entry ( keys %MSGS ) {
         print "LINE:\n";
         print "\t [ $entry ]\n";
         print "\t [ $MSGS{$entry}{\"severity\"} ]\n";
         print "\t [ $MSGS{$entry}{\"text\"} ]\n\n";
      }
   }
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
   my($msg) = sprintf("%s  %s/%s:  Caught a SIG%s -- shutting down %s ...",
                          $SIG_TERM_WARN,$HostName,$HostName,$sig,$$);
   logit($msg,$LogFile);
   exit(0);
}


#
# restart -- Reread the config file and start over.
#
# usage: restart($SIGNAL);
#

sub restart
{
   my($sig) = @_;
   my($msg) = sprintf("%s  %s/%s:  Caught a SIG%s -- Restarting %s ...",
                        $SIG_HUP_INFO,$HostName,$HostName,$sig,$$);
   logit($msg,$LogFile);
   $Restart = 1;
}

#
# Move the current log to a log.$date.$time and begin a new log.
#
# usage: mvlog();
#

sub mvlog
{
   my($sig) = @_;
   my($msg) = '';
   $log_ext = '';
   $newname = '';

   $msg = sprintf("%s  %s/%s: Starting new log ...",
                       $SIG_INFO,$HostName,$HostName);
   logit($msg,$LogFile);

   $log_ext = POSIX::strftime(".%Y%m%d.%H%M%S",localtime(time));
   $newname = $LogFile.$log_ext;
   rename ($LogFile,$newname);

   $msg = sprintf("%s  %s/%s: Started new log.",
                       $SIG_INFO,$HostName,$HostName);
   logit($msg,$LogFile);
   $Today = $Curr_day;
}

#
# Not currently used.
#
# hh:mm  (24 Hour clock)
#
# usage: set_alarm($when);
#

sub set_alarm
{
   my($when) = @_;
   my($hour) = 0;
   my($minute) = 0;
   my($seconds) = 0;
   my($curtime) = 0;
   my($curhour, $curmin, $cursec);
   my($h, $m, $s);

   ($hour, $minute) = split(":", $when);

   $curtime = POSIX::strftime("%T",localtime(time));
   ($curhour, $curmin, $cursec) = split(/:/, $curtime);
   $m = $minute - $curmin > 0 ? $minute - $curmin
                                : 60 + $minute - $curmin;
   $h = $hour - $curhour > 0 ? $hour - $curhour : 24 + $hour - $curhour;
   if ($h != 0) { $h = $minute - $curmin > 0 ? $h : $h - 1; }
   $seconds = ((($h * 60) + $m) * 60) - $cursec;
   if ($seconds <= 2*$Sleep_Time) { $seconds = 24*60*60 - $seconds; }

   if ($Debug_Level >= 2) {
      print "\nSeconds to alarm:  $seconds\n";
   }

   alarm($seconds);
}

#
# usage: handle_sigint($SIGNAL);
#

sub handle_sigint
{
   my($sig) = @_;
   $msg = sprintf("%s  %s/%s: Caught a SIG%s -- while processing a FileSystem.",
                       $SIG_INFO,$HostName,$HostName,$sig);
   logit($msg,$LogFile);
}


####################
# Main section
####################

sub main
{
   init();
   $retval = run_as_daemon();
   if ($retval == 1) {
      my($msg) = sprintf("%s  %s/%s: Couldn't fork process.",
                          $FORK_FATAL,$HostName,$HostName);
      logit($msg,$LogFile);
      exit (1);
   }

   do {
       ############################
       # Set up signal handlers
       ############################

       # catch these signals so that we can clean up before dying
       $SIG{'QUIT'} = $SIG{'TERM'} = 'quit';
       # catch this signal so that we can restart and re-read the config
       $SIG{'HUP'} = 'restart';
       # Set SIGCHLD to IGNORE to avoid zombied processes
       $SIG{'CHLD'} = 'IGNORE';

       run_process();
   } until $Done;

   my($msg) = sprintf("%s  %s/%s:  Shutting down %s ...",
                          $SIG_TERM_WARN,$HostName,$HostName,$$);
   logit($msg,$LogFile);
   exit (0);
}

main();
