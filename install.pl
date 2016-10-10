# usage: install.pl [full_path_to_perl]
#
use File::Copy;

$PERL_BIN_DIR = $ARGV[0] ;
$PERL_BIN_DIR = substr($PERL_BIN_DIR, 0, rindex($PERL_BIN_DIR, '/')) ;

$ENV{'PATH'} = '/usr/bin:/bin:/usr/local/bin:$PERL_BIN_DIR' ;
$ENV{'IFS'} = '' if $ENV{'IFS'} ne '' ;


##
## Default values
##
     $PERL_LIB_DIR		= "/opt/perl/lib" ;
     $IW_BIN_DIR		= "/home/jon/IW/bin" ;
     $IW_MAN_DIR		= "/home/jon/IW/doc" ;
     $IW_LIB_DIR		= "/home/jon/IW/lib" ;
     $IW_CONF_DIR	 	= "/home/jon/IW" ;
     $IW_DATA_MODE		= 0644 ;
     $IW_SCRIPT_MODE		= 0744 ;
     $OWNER			= "jon" ;
     $GROUP			= "engineering" ;
     $SLM_PROG_NAME		= "slm" ;
     $SSM_PROG_NAME             = "ssm" ;
     $SLM_CONF_NAME		= "slm.config";
     $SSM_CONF_NAME		= "ssm.config";
     $SLM_PROG_MAN		= "slm.prog.man" ;
     $SSM_PROG_MAN		= "ssm.prog.man" ;
     $SLM_CONF_MAN		= "slm.conf.man" ;
     $SSM_CONF_MAN		= "ssm.conf.man" ;
     $IW_SUPPORT_LIB		= "IW_support.pl" ;

     $SED 			= "/usr/bin/sed" ; 

if ( ! -f $SED ) {
    chomp ($SED = `which sed`);
}

$ready = 0 ;
while (!$ready) {
    get_some_answers() ;
    print_values() ;
    print "\nAre these values okay (y or n)? " ;
    chomp($ans = <STDIN>);
    $ready = 1 if ($ans =~ /^y/i) ;
}

print "\nAre you ready to start the installation (y or n)? " ;
chomp($ans1 = <STDIN>) ;
do_the_install() if ($ans1 =~ /^y/i) ;
install_header_files() if ($ans1 =~ /^y/i) ;

sub install_header_files
{
   if (-e "$IW_LIB_DIR/syscall.h") {
      print "$IW_LIB_DIR/syscall.h exists.  Overwrite?  ";
      chomp($ans = <STDIN>) ;
      if ($ans =~ /^y/i) {
         print "Converting syscall.h to syscall.ph ... " ;
         copy ("/usr/include/sys/syscall.h", "$IW_LIB_DIR/syscall.h") or
               print " Copy failed. $!.\n";
         `cd $IW_LIB_DIR; $PERL_BIN_DIR/h2ph -d . syscall.h`;
         print "  Done.\n" ;
      }
      else {
          print "Skipping install of $IW_LIB_DIR/syscall.h.\n";
      }
   }
   else {
      print "Converting syscall.h to syscall.ph ... " ;
      copy ("/usr/include/sys/syscall.h", "$IW_LIB_DIR/syscall.h") or
            print " Copy failed. $!.\n";
      `cd $IW_LIB_DIR; $PERL_BIN_DIR/h2ph -d . syscall.h`;
      print "  Done.\n" ;
   }
   if (-e "$IW_LIB_DIR/statvfs.h") {
      print "$IW_LIB_DIR/statvfs.h exists.  Overwrite?  ";
      chomp($ans = <STDIN>) ;
      if ($ans =~ /^y/i) {
         print "Converting statvfs.h to statvfs.ph ... " ;
         copy ("/usr/include/sys/statvfs.h", "$IW_LIB_DIR/statvfs.h") or
               print " Copy failed. $!.";
         `cd $IW_LIB_DIR; $PERL_BIN_DIR/h2ph -d . statvfs.h`;
         print "  Done.\n" ;
      }
      else {
          print "Skipping install of $IW_LIB_DIR/statvfs.h.\n";
      }
   }
   else {
      print "Converting statvfs.h to statvfs.ph ... " ;
      copy ("/usr/include/sys/statvfs.h", "$IW_LIB_DIR/statvfs.h") or
            print " Copy failed. $!.\n";
      `cd $IW_LIB_DIR; $PERL_BIN_DIR/h2ph -d . statvfs.h`;
      print "  Done.\n" ;
   }
   if (-e "$IW_LIB_DIR/syslog.h") {
      print "$IW_LIB_DIR/syslog.h exists.  Overwrite?  ";
      chomp($ans = <STDIN>) ;
      if ($ans =~ /^y/i) {
         print "Converting syslog.h to syslog.ph ... " ;
         copy ("/usr/include/sys/syslog.h", "$IW_LIB_DIR/syslog.h") or
               print " Copy failed. $!.\n";
         `cd $IW_LIB_DIR; $PERL_BIN_DIR/h2ph -d . syslog.h`;
         print "  Done.\n" ;
      }
      else {
          print "Skipping install of $IW_LIB_DIR/syslog.h.\n";
      }
   }
   else {
      print "Converting syslog.h to syslog.ph ... " ;
      copy ("/usr/include/sys/syslog.h", "$IW_LIB_DIR/syslog.h") or
            print " Copy failed. $!.\n";
      `cd $IW_LIB_DIR; $PERL_BIN_DIR/h2ph -d . syslog.h`;
      print "  Done.\n" ;
   }

}


sub get_some_answers {
    my($question) ;
    my $dec_mode_prog = sprintf("%04o",$IW_SCRIPT_MODE);
    my $dec_mode_dat  = sprintf("%04o",$IW_DATA_MODE);

    $question = "\nEnter the directory where the InfoWatcher ";
    $question .= "executables are to\nbe installed:\n";
    $IW_BIN_DIR = get_answer($question, $IW_BIN_DIR) ;

    $question = "\nWhat user should own the installed";
    $question .= "InfoWatcher files?\n";
    $OWNER = get_answer($question, $OWNER) ;
    $monitor_uid = getpwnam($OWNER);

    $question = "\nWhat group should own the installed ";
    $question .= "InfoWatcher files?\n";
    $GROUP = get_answer($question, $GROUP) ;
    $monitor_gid = getgrnam($GROUP);

    $question = "\nWhat should the permissions (octal) be for the ";
    $question .= "installed\nInfoWatcher scripts?\n";
    $IW_SCRIPT_MODE = get_answer($question, $IW_SCRIPT_MODE, $dec_mode_prog) ;

    $question = "\nWhat should the permissions (octal) be for the ";
    $question .= "installed\nInfoWatcher libraries and man pages?\n";
    $IW_DATA_MODE = get_answer($question, $IW_DATA_MODE, $dec_mode_dat) ;

    $question = "\nEnter the name of the directory where the perl ";
    $question .= "library\nfiles are located:\n";
    $PERL_LIB_DIR = get_answer($question, $PERL_LIB_DIR) ;

    $question = "\nEnter the name of the directory where the ";
    $question .= "Infowatcher library\nfile is to be installed:\n";
    $IW_LIB_DIR = get_answer($question, $IW_LIB_DIR) ;

    $question = "\nWhat directory should the InfoWatcher  ";
    $question .= "configuration\nfiles be installed in:\n";
    $IW_CONF_DIR = get_answer($question, $IW_CONF_DIR) ;

    $question = "\nWhat directory should the InfoWatcher man pages";
    $question .= " be\ninstalled in:\n";
    $IW_MAN_DIR = get_answer($question, $IW_MAN_DIR) ;

}


sub do_the_install {
    system ("$SED -e \"s?PERL_LIB_DIR?$PERL_LIB_DIR?g\" -e \"s?IW_BIN_DIR?$IW_BIN_DIR?g\" -e \"s?IW_LIB_DIR?$IW_LIB_DIR?g\" -e \"s?PERL_BIN_DIR?$PERL_BIN_DIR?g\" $SLM_PROG_NAME.pl | grep -v \"^## \" > $SLM_PROG_NAME" ) ;

    system ("$SED -e \"s?PERL_LIB_DIR?$PERL_LIB_DIR?g\" -e \"s?IW_BIN_DIR?$IW_BIN_DIR?g\" -e \"s?IW_LIB_DIR?$IW_LIB_DIR?g\" -e \"s?PERL_BIN_DIR?$PERL_BIN_DIR?g\" $SSM_PROG_NAME.pl | grep -v \"^## \" > $SSM_PROG_NAME" ) ;

    system ("$SED -e \"s?PERL_LIB_DIR?$PERL_LIB_DIR?g\" -e \"s?IW_BIN_DIR?$IW_BIN_DIR?g\" -e \"s?IW_LIB_DIR?$IW_LIB_DIR?g\" -e \"s?PERL_BIN_DIR?$PERL_BIN_DIR?g\" $IW_SUPPORT_LIB | grep -v \"^## \" > $IW_SUPPORT_LIB.mod" ) ;

    print "\n";
    print "\n";
    install_it($monitor_uid, $monitor_gid, $IW_SCRIPT_MODE,
		$SLM_PROG_NAME, "$IW_BIN_DIR/$SLM_PROG_NAME") ;

    install_it($monitor_uid, $monitor_gid, $IW_SCRIPT_MODE,
		$SSM_PROG_NAME, "$IW_BIN_DIR/$SSM_PROG_NAME") ;

    install_it($monitor_uid, $monitor_gid, $IW_DATA_MODE,
		$IW_SUPPORT_LIB.".mod", "$IW_LIB_DIR/$IW_SUPPORT_LIB") ;

    install_it($monitor_uid, $monitor_gid, $IW_DATA_MODE,
		$SLM_CONF_NAME, "$IW_CONF_DIR/$SLM_CONF_NAME") ;

    install_it($monitor_uid, $monitor_gid, $IW_DATA_MODE,
		$SSM_CONF_NAME, "$IW_CONF_DIR/$SSM_CONF_NAME") ;

    install_it($monitor_uid, $monitor_gid, $IW_DATA_MODE,
		$SLM_PROG_MAN, "$IW_MAN_DIR/$SLM_PROG_NAME.8") ;

    install_it($monitor_uid, $monitor_gid, $IW_DATA_MODE,
		$SSM_PROG_MAN, "$IW_MAN_DIR/$SSM_PROG_NAME.8") ;

    install_it($monitor_uid, $monitor_gid, $IW_DATA_MODE,
		$SLM_CONF_MAN, "$IW_MAN_DIR/$SLM_PROG_NAME.5") ;

    install_it($monitor_uid, $monitor_gid, $IW_DATA_MODE,
		$SSM_CONF_MAN, "$IW_MAN_DIR/$SSM_PROG_NAME.5") ;
}


sub install_it {
    my($uid, $gid, $mode, $src_file, $dest_file) = @_ ;

    if (-e $dest_file && -W $dest_file) {
       print "$dest_file exists.  Overwrite?  ";
       chomp($ans = <STDIN>) ;
       if ($ans =~ /^y/i) { 
          print "Installing $src_file..." ;
          copy ($src_file, $dest_file) or 
               print " Copy failed. $!.";
          chmod $mode, $dest_file or 
               print " Chmod failed. $!.";
          chown($uid, $gid, $dest_file)  or 
               print " Chown failed. $!.";
          print "  Done.\n" ;
       }
       else {
          print "Skipping install of $src_file.\n";
       }
    }
    elsif (-e $dest_file && !(-W $dest_file)) {
          print "$dest_file exists.\n";
          print "  You do not have write permission.  Skipping...\n"
    } 
    else {
       print "Installing $src_file..." ;
       copy ($src_file, $dest_file) or
            print " Copy failed. $!.";
       chmod $mode, $dest_file or
            print " Chmod failed. $!.";
       chown($uid, $gid, $dest_file)  or
            print " Chown failed. $!.";
       print "  Done.\n" ;
   }
}

sub get_answer {
    my($msg, $dflt, $prnt) = @_ ;
    my($done) = 0 ;
    my($ans) ;

    while (!$done) {
        print "$msg" ;
        if ($prnt) {print "  (default '$prnt') ";}
        else { print "  (default '$dflt') ";}
        chomp($ans = <STDIN>) ;
        if ($ans eq '') { $ans = $dflt ; }
        $done = 1 ;
    }
    return $ans ;
}


sub print_values {
   my $dec_mode_prog = sprintf("%04o",$IW_SCRIPT_MODE);
   my $dec_mode_dat  = sprintf("%04o",$IW_DATA_MODE);

print <<ENDOFPRINT;

Here are the current values...

NOTE:  The directories specified must exist and be writable
       by the current UID.

   Perl Location Info:
      Perl binary location: $PERL_BIN_DIR
      Perl library: $PERL_LIB_DIR
   Monitor Location Info:
      Monitor binary location: $IW_BIN_DIR
      Monitor library location: $IW_LIB_DIR
      Monitor manual page location: $IW_MAN_DIR
      Monitor configfile location: $IW_CONF_DIR
   Ownership/Permission Info:
      Monitor data file permissions: $dec_mode_dat
      Monitor program permissions: $dec_mode_prog
      Monitor owner: $OWNER
      Monitor group: $GROUP
ENDOFPRINT
}
