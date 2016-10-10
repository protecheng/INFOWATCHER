#
#       Name:           IW_support.pl 
#       Author:         Jon Christensen (j.christensen@computer.org)
#       Company:        Protech Engineering Services 
#       Date:           11/14/1998
#
#       Contents:       exec_it ();
#                       mail_it ();
#                       write_it ();
#                       skip_message ();
#                       format_message ();
#                       s2hms ();
#                       hms2s ();
#                       log_time ();
#                       logit ();
#                       set_timeout ();
#
#       Modifications:
#                       03/17/1999-
#                          Added set_timeout() function to implement a
#                          timeout when making a call that can hang.
#                       01/07/1999-
#                          Fixed the way the skip_message() routine handles
#                          interval messages, and added a feature to enable
#                          a user to specify a minimum message count to
#                          be exceeded before actions are taken.  Also fixed
#                          a couple minor bugs.  Upped version to 1.0.
#                       11/27/1998-
#                          Several Modifications and bug fixes.
#
#
# InfoWatcher is a complete rewrite of the following program written by Todd 
# Atkins.  It was written to run as a daemon process and is able to monitor
# multiple files simultaneously without hanging any mounted filesystems. 
# There are numerous other numerous modifications (especially in message 
# handling) and multiple bug fixes.
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

use POSIX qw(strftime);

$MAILER = "/usr/lib/sendmail";
$WRITE 	= "/bin/write";
$VERSION = '1.11';

#
# exec_it -- fork and execute a command
#
# usage: exec_it($command_to_execute);
#

sub exec_it {
   my($Command) = @_;

   EXECFORK: {
      if ($pid = fork) {
         return;
      } elsif (defined $pid) {
         exec($Command);
      } elsif ($! =~ /No more processes/) {
         # EAGAIN, supposedly recoverable fork error
         sleep 5;
         redo EXECFORK;
      } else {
         warn "Can't fork to exec $Command: $!\n";
      }
   }
}

#
# mail_it -- send some mail using $MAILER.
#
# usage: mail_it($addresses_to_mail_to,
#		  $the_message);
#

sub mail_it {
   my($Addresses, $Msg) = @_;

   $Addresses =~ s/:/,/g;

   open(MAIL, "| $MAILER $Addresses")
      || warn "$0: cannot open pipe to $MAILER: $!\n" && return;

   print MAIL "To: $Addresses\n";
   print MAIL "Subject: ** ATTENTION **\n\n";
   print MAIL "$Msg\n";
   close(MAIL);
}


#
# write_it -- use $WRITE to send a message logged on users.
#
# usage: write_it($users_to_write_to,
#		   $the_message);
#

sub write_it {
   my($UserList, $Msg) = @_;

   for $User (split(/:/, $UserList)) {
      pipe_it("$WRITE $User", $Msg);
   }
}

#
# skip_message -- determines the disposition of a message by looking at its 
#	history
#
# inputs:	$message     -- the pattern hit on 
#               $host        -- host associated with this message
#		$min_time    -- minimum accepted time between messages (in seconds)
#		$min_count   -- minimum accepted time between messages (in seconds)
#		$pattern_num -- Pattern# of the message 
#		$msg         -- Text of the message 
#
# returns:	0 -- if the message arrived after $time of the last alike 
#			message and $min_count (Minimum message count if defined) 
#                       is greater than count.
#		1 -- if not.
#

sub skip_message {
   my($message,$host,$min_time,$min_count,$pattern_num,$msg) = @_;
   my($now_time) = time;

   $message = $message.".".$host;

   if (defined $Interval_MSG{$message}) {
      ## Increment the count for the entry ##
      $Interval_MSG{$message}{"Count"}++;
      if ( ($now_time - $Interval_MSG{$message}{"Time"}) > $min_time && $Interval_MSG{$message}{"Count"} >= $min_count) {
          ## set these for external use ##
          $Interval_MSG{$message}{"Time"} = $now_time - $Interval_MSG{$message}{"Time"};
          return 0;
      } elsif (($now_time - $Interval_MSG{$message}{"Time"}) > $min_time && $Interval_MSG{$message}{"Count"} < $min_count) {
          ## Delete the entry ##
          delete $Interval_MSG{$message};
          return 1;
      } else {
          return 1;
      }
   } else {
      ## create a new entry ##
      $Interval_MSG{$message}{"Text"} = $msg;
      $Interval_MSG{$message}{"Pattern"} = $pattern_num;
      $Interval_MSG{$message}{"Interval"} = $min_time;
      $Interval_MSG{$message}{"Time"} = $now_time;
      $Interval_MSG{$message}{"Count"} = 1;
      if ( $min_count != 0 ) {
         $Interval_MSG{$message}{"MinC"} = $min_count;
         return 1;
      } else {
         $Interval_MSG{$message}{"MinC"} = 2;
         return 0;
      }
   }
}

#
# format_message -- postpend the history info to the message
#
# input: 	$message -- the message key
#		$exact -- flag indicating where format was called from.
#
# uses:
#		$Interval_MSG{$message}{"Count"} -- no. of alike messages during interval
#		$Interval_MSG{$message}{"Time"} -- The time of the interval in seconds
#		$Interval_MSG{$message}{"Text"} -- The original message text 
#
# returns:	a formatted string with history information postpended to
#		the message.
#

sub format_message {
   my($message,$exact) = @_;
   my($new_msg,$time);

   if ($Interval_MSG{$message}{"Count"} == 1) { # return original message
      return $Interval_MSG{$message}{"Text"};
   } else {
      $time = s2hms($Interval_MSG{$message}{"Time"});
      chomp $Interval_MSG{$message}{"Text"};

      if ($exact == 1) {
         $new_msg .= "$Interval_MSG{$message}{\"Text\"} <== ** $Interval_MSG{$message}{\"Count\"} seen in $time\n";
         delete $Interval_MSG{$message};
      } else {
         $new_msg .= "$Interval_MSG{$message}{\"Text\"} ** $Interval_MSG{$message}{\"Count\"} seen in $time\n";
      }

      return $new_msg;
   }
}

####################
#
# Date/Time routines
#
####################

#
# s2hms -- converts seconds to a string which says
#	how many hours, minutes, and seconds it is.
#

sub s2hms {
   my($seconds) = @_;
   my($hours,$minutes);
   $hours = $seconds / (60*60);
   $seconds %= (60*60);
   $minutes = $seconds / 60;
   $seconds %= 60;

   return sprintf("%.2d:%2.2d:%2.2d", $hours, $minutes, $seconds);

}

#
# hms2s -- Take a string which may be in the form hours:minutes:seconds,
#       convert it to just seconds, and return the number of seconds
#

sub hms2s
{
   my($hms)     = @_;
   my($hours)   = 0;
   my($minutes) = 0;
   my($seconds) = 0;

   if ($hms =~ /[0-9]+:[0-9]+:[0-9]+/) {
       ($hours, $minutes, $seconds) = split(":", $hms);
   } elsif ($hms =~ /[0-9]+:[0-9]+/) {
       ($minutes, $seconds) = split(":", $hms);
   } else {
       $seconds = $hms;
   }

   return ($hours * 60 * 60) + ($minutes * 60) + $seconds;
}

#
#  Creates a timestamp in the format used in /var/adm/messages
#

sub log_time 
{
   $tstamp = POSIX::strftime("%Y/%m/%d-%T",localtime(time));
   return ($tstamp);
}

#
#  Log Routine
#

sub logit
{
   my($log_message,$LogFile) = @_;
   $fmt_time = log_time();
   open (LOGFILE,">>$LogFile") || 
       die "$fmt_time IW program cannot open $LogFile.  Unable to continue.\n";
   print LOGFILE "$fmt_time  $log_message\n";
   close (LOGFILE);
}

#
#  Sets up a timeout routine to prevent hangs when making stat calls.
#
#  set_timeout ()
#
#  input:              $install - A boolean value.   
#                                 1-  Setting up the signal_handler
#                                     and spawning a process to
#                                     implement a timeout.
#                                 0-  Uninstalling signal_handler.
#

sub set_timeout
{
   my($install) = @_;
   my($sigreg)  = '';

   if ($install) {
      undef $Pid;
      # Setup the signal handler within the parent
      $SIG{'INT'} = \&handle_sigint;
   }
   else {
      $SIG{'INT'} = 'IGNORE';
      kill USR2 => $Pid;
      waitpid( $Pid, 0);
      return (0);
   }

$sigreg = <<EndOfEval;
   
   sleep $FSTimeOut;
   kill INT => $PPID;
   exit (0);

EndOfEval

   FORK: {
      if ($Pid = fork) { return (0); }
      elsif (defined $Pid) {
         $mypid = open(SIGNALER, "| PERL_BIN_DIR/perl -") 
                  || die "$0: cannot open pipe into \"PERL_BIN_DIR/perl -\": $!\n";
          print SIGNALER "$sigreg";
          local $SIG{USR2} = sub { kill 9 => $mypid };
          close(SIGNALER);
          exit(0);
      }
   }
}

1;
