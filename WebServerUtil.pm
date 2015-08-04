############################################################################
#   Misc. WebServer utility functions.
#   Taken from WebUtil.pm, but intended to be lighter weight
#   for independent installation with minimal dependencies.
# 	--es 09/30/2006
############################################################################
package WebServerUtil;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    webLog
    webDie
    blockRobots
    checkEvalue
    checkPath
    sanitizeInt
    checkTmpPath
    unsetEnvPath
    resetEnvPath
    wsystem
    wunlink
    newReadFileHandle
    newWriteFileHandle
    newAppendFileHandle
    newCmdFileHandle
    runCmd
    runCmdNoExit
    file2Str
    str2File
    appendFile
    currDateTime
    blankStr
    strTrim
    showFile
    printFile
    showFileStderr
    fileSize
    fileAtime
    lastPathTok
    dirList
    array2Hash
    arrayRef2HashRef
    wrapSeq
    fileRoot
    blastProcCheck
    timeout
    purgeTmpDir
    waitLoop
);
use strict;
use Time::localtime;
use CGI qw( :standard );
use FileHandle;
use WebConfig;
use LWP;
use HTTP::Request::Common qw( GET );
#use CGI::Carp qw( fatalsToBrowser carpout set_message  );
use CGI::Carp qw( carpout set_message  );
use Cwd;
use WebUtil;

# Force flush
$| = 1;

###
# Environment variables
#
my $env = getEnv( );
my $web_log_file = $env->{ web_log_file };
my $err_log_file = $env->{ err_log_file };
my $web_log_override = 0;

my $base_dir = $env->{ base_dir };
my $tmp_dir = $env->{ tmp_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $common_tmp_dir = $env->{ common_tmp_dir };
my $cgi = new CGI;
my $envPath = $ENV{ PATH };

## --es 05/05/2005 limit no. of concurrent BLAST jobs.
my $max_blast_jobs = $env->{ max_blast_jobs };
$max_blast_jobs = 20 if $max_blast_jobs == 0;

my $verbose = $env->{ verbose };

if( $web_log_file eq "" ) {
   die( "env{ web_log_file } not define in WebConfig.pm\n" );
}
if( $err_log_file eq "" ) {
   die( "env{ err_log_file } not define in WebConfig.pm\n" );
}
## For web servers only, but not for developer doing "perl -c ...".
if( $ENV{ GATEWAY_INTERFACE } ne "" ) {
    my $err_fh = newAppendFileHandle( $err_log_file, "a" );
   if( !defined( $err_fh ) ) {
       die( "Unable to write '$err_log_file'\n" );
   }
   carpout( $err_fh );
}


############################################################################
# blockRobots - Block robots from using this script.
#   (robots.txt doesn't always work; so a little brute force ...)
############################################################################
sub blockRobots {
    ## .htaccess and robots.txt does not work; we force it.
    my $http_user_agent = $ENV{ HTTP_USER_AGENT };
    webLog( "HTTP_USER_AGENT='$http_user_agent'\n" ) if $verbose >= 1;
    my $page = param( "page" );
    if( $http_user_agent !~ /img2.x/ ) {
           print header( -status => '403 Forbidden' );
           print "<html>\n";
           print "<head>\n";
           print "<title>403 Forbidden</title>\n";
           print "</head>\n";
           print "<body>\n";
           print "<h1>Forbidden</h1>\n";
           print "Bots don't have permission.\n";
           print "</body>\n";
           print "</html>\n";
           webLog( "Exit for HTTP_USER_AGENT $http_user_agent\n" );
           WebUtil::webExit(0);
    }
}

############################################################################
# setWebLogOverride - Set flag for overding web logging file.
#   Mainly used by test applications.
############################################################################
sub setWebLogOverride {
    my( $bf ) = @_;
    $web_log_override = $bf;
}

############################################################################
# webLog - Do logging to STDERR or file.
############################################################################
sub webLog {
    my( $s ) = @_;
    if( $web_log_file eq "" || $web_log_override ) {
        print STDERR $s;
	return;
    }
    my $afh = newAppendFileHandle( $web_log_file, "webLog" );
    print $afh $s;
    close $afh;
}

############################################################################
# webDie  - Print messsage and exit.
############################################################################
sub webDie {
    my( $s ) = @_;
    print STDERR "$s\n";
    WebUtil::webExit(1);
}

############################################################################
# unsetEnvPath - Unset the environment path for external calls.
############################################################################
sub unsetEnvPath {
   $ENV{ PATH } = "";
}

############################################################################
# resetEnvPath - Rest environment path to original.
############################################################################
sub resetEnvPath {
   $ENV{ PATH } = $envPath;
}

############################################################################
# checkEvalue - Check option selection evalue from UI.
############################################################################
sub checkEvalue {
   my( $evalue ) = @_;
   $evalue =~ /([0-9]+e-?[0-9]+)/;
   my $evalue2 = $1;
   if( $evalue2 eq "" ) {
      webDie( "checkEvalue: invalid evalue='$evalue'\n" );
   }
   return $evalue2;
}

############################################################################
# checkPath - Check path for invalid characters.
############################################################################
sub checkPath {
    my( $path ) = @_;
    ## Catch bad pattern first.
    my @toks = split( /\//, $path );
    for my $t( @toks ) {
       next if $t eq ""; # for double slashes
       if( $t !~ /^[a-zA-Z0-9_\.\-]+$/ || $t eq ".." ) {
          webDie( "checkPath:1: invalid path '$path' tok='$t'\n" );
       }
    }
    ## Untaint.
    $path =~ /([a-zA-Z0-9\_\.\-\/]+)/;
    my $path2 = $1;
    if( $path2 eq "" ) {
       webLog( "checkPath:2: invalid path '$path2'\n" );
       WebUtil::webExit(-1);
    }
    return $path2;
}

############################################################################
# validFileName - Check for valid file name w/o full path.
############################################################################
sub validFileName {
   my( $fname ) = @_;
   $fname =~ /([a-zA-Z0-9\._]+)/;
   my $fname2 = $1;
   if( $fname2 eq "" ) {
      webLog( "validFileName: invalid file name '$fname'\n" );
      WebUtil::webExit(-1);
   }
   return $fname2;
}

############################################################################
# sanitizeInt - Sanitize to integer for security purposes.
############################################################################
sub sanitizeInt {
   my( $s ) = @_;
   if( $s !~ /^[0-9]+$/ ) {
      webDie( "sanitizeInt: invalid integer '$s'\n" );
   }
   $s =~ /([0-9]+)/;
   $s = $1;
   return $s;
}

############################################################################
# wunlink - Web version of unlink, check path.
############################################################################
sub wunlink {
   my( $path ) = @_;
   ## Sometimes in clustalw the current directory is changed to tmp.
   $path = checkPath( $path );
   #my $fname = lastPathTok( $path );
   #my $fname2 = validFileName( $fname );
   webLog( "unlink '$path'\n" ) if $verbose >= 2;
   unlink( $path );
}

############################################################################
# wsystem - system() for web. Use only first token as executable.
############################################################################
sub wsystem {
   my( $cmd ) = @_;
   $cmd =~ s/\s+/ /g;
   my @args = split( / /, $cmd );
   my $ex = shift( @args );
   checkPath( $ex );
   my $envPath = $ENV{ PATH };
   $ENV{ PATH } = "";
   my $st = system( $ex, @args );
   $ENV{ PATH } = $envPath;
   return $st;
}

############################################################################
# newReadFileHandle - Security wrapper for new FileHandle.
############################################################################
sub newReadFileHandle {
   my( $path, $func, $noExit ) = @_;

   $func = "newReadFileHandle" if $func eq "";
   $path = checkPath( $path );
   my $fh = new FileHandle( $path, "r" );
   if( !$fh && !$noExit ) {
      webLog( "$func: cannot read '$path'\n" );
      WebUtil::webExit(-1);
   }
   return $fh;
}

############################################################################
# newWriteFileHandle - Security wrapper for new FileHandle.
############################################################################
sub newWriteFileHandle {
   my( $path, $func, $noExit ) = @_;

   $func = "newWriteFileHandle" if $func eq "";
   $path = checkPath( $path );
   my $fh = new FileHandle( $path, "w" );
   if( !$fh && !$noExit ) {
      webLog( "$func: cannot write '$path'\n" );
      WebUtil::webExit(-1);
   }
   return $fh;
}

############################################################################
# newAppendFileHandle - Security wrapper for new FileHandle.
############################################################################
sub newAppendFileHandle {
   my( $path, $func, $noExit ) = @_;

   $func = "newAppendFileHandle" if $func eq "";
   $path = checkPath( $path );
   my $fh = new FileHandle( $path, "a" );
   if( !$fh && !$noExit ) {
      webLog( "$func: cannot append '$path'\n" );
      WebUtil::webExit(-1);
   }
   return $fh;
}

############################################################################
# newCmdFileHandle - Security wrapper for new FileHandle with command.
############################################################################
sub newCmdFileHandle {
   my( $cmd, $func, $noExit ) = @_;

   $func = "newCmdFileHandle" if $func eq "";
   my $fh = new FileHandle( "$cmd |" ); 
   if( !$fh && !$noExit ) {
      webLog( "$func: cannot '$cmd'\n" );
      WebUtil::webExit(-1);
   }
   return $fh;
}

#############################################################################
# runCmd - Run external command line tool.  Exit on failure, non-zero
#   exit status.
#############################################################################
sub runCmd {
  my ($cmd) = @_;
  webLog "+ $cmd\n";
  my $st = wsystem ($cmd);
  if ($st != 0) {
    webDie( "runCmd: execution error status $st\n" );
  }
}

#############################################################################
# runCmdNoExit - Run external command line, but do not exit on failure.
#############################################################################
sub runCmdNoExit {
  my ($cmd) = @_;
  webLog "+ $cmd\n";
  my $st = wsystem ($cmd);
  return $st;
}

############################################################################
# checkTmpPath - Wrap temp path for safety.  An additional
#   check for writing (or reading) to (from) temp directory.
############################################################################
sub checkTmpPath {
   my( $path ) = @_;
   if( $path !~ /^$tmp_dir/ &&  $path !~ /^$cgi_tmp_dir/ ) {
      webLog( "checkTmpPath: expected full temp directory " . 
           "'$tmp_dir' or '$cgi_tmp_dir'; got path '$path'\n" );
      WebUtil::webExit(-1);
   }
   $path = checkPath( $path );
   my $fname = lastPathTok( $path );
   my $fname2 = validFileName( $fname );
   return $path;
}

###########################################################################
# file2Str - Convert file contents to string.
###########################################################################
sub file2Str {
  my $file = shift;

  my $rfh = newReadFileHandle( $file, "file2Str" );
  my $line = "";
  my $s = "";
  while ($line = $rfh->getline( ) ) {
    $s .= $line;
  }
  close $rfh;
  return $s;
}

#############################################################################
# str2File - Write string to file.
#############################################################################
sub str2File {
  my ($str, $file) = @_;
  my $wfh = newWriteFileHandle( $file, "str2File" );
  print $wfh $str;
  close $wfh;
}

#############################################################################
# appendFile - Append string to file.
#############################################################################
sub appendFile {
  my ($file, $str) = @_;
  my $afh = newAppendFileHandle( $file, "appendFile" );
  print $afh $str;
  close $afh;
}

#############################################################################
# currDateTime - Get current date time string.
#############################################################################
sub currDateTime {
  my $s = sprintf ("%d/%d/%d %d:%d:%d",
    localtime->mon () + 1,
    localtime->mday (),
    localtime->year () + 1900,
    localtime->hour (),
    localtime->min (),
    localtime->sec ());
  return $s;
}

###########################################################################
# blankStr - Is blank string.  Return 1=true or 0=false.
###########################################################################
sub blankStr {
  my $s = shift;

  if ($s =~ /^[ \t\n]+$/ || $s eq "") {
    return 1;
  }
  else {
    return 0;
  }
}

###########################################################################
# strTrim - Trim string of preceding and ending spaces.
###########################################################################
sub strTrim {
  my $s = shift;

  $s =~ s/^\s+//;
  $s =~ s/\s+$//;
  return $s;
}

###########################################################################
# showFile - Show file to standard error output.
###########################################################################
sub showFile {
  my $file = shift;

  my $rfh = newReadFileHandle( $file, "showFile" );
  my $line = "";
  while ($line = $rfh->getline( ) ) {
    webLog ($line);
  }
  close $rfh;
}

###########################################################################
# printFile - Show file to standard output.
###########################################################################
sub printFile {
  my $file = shift;

  my $rfh = newReadFileHandle( $file, "printFile" );
  my $line = "";
  while ($line = $rfh->getline( ) ) {
    print  $line;
  }
  close $rfh;
}

###########################################################################
# showFileStderr - Show file to standard err output.
###########################################################################
sub showFileStderr {
  my $file = shift;

  my $rfh = newReadFileHandle( $file, "showFileStderr" );
  my $line = "";
  while ($line = $rfh->getline( ) ) {
    webLog "$line";
  }
  close $rfh;
}

#############################################################################
# fileSize - Return file size of file name.
#############################################################################
sub fileSize {
  my( $fileName ) = @_;
  my $rfh = newReadFileHandle( $fileName, "fileSize", 1 );
  return 0 if !$rfh;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
      $mtime,$ctime,$blksize,$blocks) = stat ( $rfh );
  close $rfh;
  return $size;
}

#############################################################################
# fileAtime - Return file access time for file name.
#############################################################################
sub fileAtime {
  my( $fileName ) = @_;
  my $rfh = newReadFileHandle( $fileName, "fileAtime", 1 );
  return 0 if !$rfh;
  my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,
      $mtime,$ctime,$blksize,$blocks) = stat ( $rfh );
  close $rfh;
  #return $atime;
  return $mtime;
}

#############################################################################
# lastPathTok - Last path token in file path, i.e, the file name.
#############################################################################
sub lastPathTok {
   my( $path ) = @_;
   my @toks = split( /\//, $path );
   my $i;
   my @toks2;
   foreach $i( @toks ) {
      next if $i eq "";
      push( @toks2, $i );
   }
   my $nToks = @toks2;
   return $toks2[$nToks-1];
}

#############################################################################
# dirList - Directory list of files given a directory.
#############################################################################
sub dirList {
    my( $dir ) = @_;
    opendir( Dir, $dir ) || webDie( "dirList: cannot read '$dir'\n" );
    my @paths = sort( readdir( Dir ) );
    closedir( Dir );
    my @paths2;
    my $i;
    for $i( @paths ) {
	next if $i =~ /^\./;
	next if $i eq "CVS";
	push( @paths2, $i );
    }
    return @paths2;
}

############################################################################
# arrray2Hash - Convert array values to hash.
############################################################################
sub array2Hash {
   my( @a ) = @_;
   my %h;
   for my $i( @a ) {
      $h{ $i } = $i;
   }
   return %h;
}

############################################################################
# arrayRef2HashRef - Convert array values to hash and initialize.
############################################################################
sub arrayRef2HashRef {
   my( $a_ref, $h_ref, $initVal ) = @_;
   for my $i( @$a_ref ) {
      $h_ref->{ $i } = $initVal;
   }
}

############################################################################
# wrapSeq - Wrap a sequence for pretty printing.
############################################################################
sub wrapSeq{ 
   my( $seq, $wrapLen ) = @_;
   if( $wrapLen eq "" ) {
      $wrapLen = 50;
   }
   my $i;
   my $s2;
   my $len = length( $seq );
   for( $i = 0; $i < $len; $i += $wrapLen ) {
       my $s = substr( $seq, $i, $wrapLen );
       $s2 .= $s . "\n";
   }
   return $s2;
}

############################################################################
# fileRoot - Get file name root from path.
############################################################################
sub fileRoot {
   my( $path ) = @_;
   my $fileName = lastPathTok( $path );
   my( $fileRoot, @exts ) = split( /\./, $fileName );
   return $fileRoot;
}

############################################################################
# blastProcCheck - Do system wide BLAST process check.  We don't
#    want too many hogs running at the same time so as to overwhelm
#    the system.  Do the error message here if it's too much.
#        --es  05/05/2005
############################################################################
sub blastProcCheck {
    my $cmd = "/bin/ps -ef";
    webLog "+ $cmd\n" if $verbose >= 5;
    my $count = 0;
    unsetEnvPath( );
    my $cfh = newCmdFileHandle( $cmd, "blastProcCheck" );
    while( my $s = $cfh->getline( ) ) {
       chomp $s;
       $count++ if $s =~ /blastall/;
    }
    close $cfh;
    resetEnvPath( );
    webLog "$count blastall's running\n" if $verbose >= 1;
    if( $count >= $max_blast_jobs ) {
       print( "ERROR:  " .
         "Maximum BLAST jobs ($max_blast_jobs) currently running. " .
         "Please try again later." );
    }
}   

############################################################################
# timeout - Timeout CGI processes that take too long.  Do not clog
#   up the process table.
# http://www.tutorialspoint.com/perl/perl_alarm.htm
# Sets the "alarm," causing the current process to receive a SIGALRM signal in
# EXPR seconds. If EXPR is omitted, the value of $_ is used instead.
# The actual time delay is not precise, since different systems implement
# the alarm functionality differently. The actual time may be up to a second
# more or less than the requested value. You can only set one alarm timer at any
# one time. If a timer is already running and you make a new call to the alarm
# function, the alarm timer is reset to the new value. A running timer can be
# reset without setting a new timer by specifying a value of 0.
############################################################################
sub timeout {
    my( $secs ) = @_;

    my $cwd = getcwd( );
    my $dt = currDateTime( );
    $SIG{ ALRM } = sub{
       print "<p> <font color='red'> Session has timeouted. " . 
         "Process is taking to long to run. </font> </p>\n";
       die( "$dt: $cwd: $0: pid=$$ timeout=($secs seconds)\n" );
    };
    alarm $secs;
}

############################################################################
# purgeTmpDir - Purge temp directory of file too old.
############################################################################
sub purgeTmpDir {
   my $max_time_diff = 60 * 5;

   return if $common_tmp_dir eq "";

   my @files = dirList( $common_tmp_dir );
   my $nFiles = @files;
   my $count = 0;
   my $now = time( );
   for my $f( @files ) {
       next if $f eq "index.html";
       next if $f !~ /^blast/;
       my $path = "$common_tmp_dir/$f";
       my $t = fileAtime( $path );
       my $diff = $now - $t;
       webLog( "path='$path' now=$now t=$t diff=$diff\n" )
          if $verbose >= 5;
       if( $diff > $max_time_diff ) {
           webLog( ">>> Purge tmp file '$path'\n" );
           $count++;
           wunlink( $path );
       }
   }
}


############################################################################
# timeVal - Get a sortable time value in seconds.
############################################################################
sub timeVal {
   my( $s ) = @_;
   
   my( $hr, $min, $sec ) = split( /:/, $s );
   return $sec + (60 * $min) + (60 * 60 * $hr );
}
   
############################################################################
# waitLoop - Wait so only the earlist perl process with blastall can
#   proceed.  This single threads the blast process to keep from
#   overwhelming the server host.
############################################################################
sub waitLoop {
    my( $nRetries, $waitSecs ) = @_;

    $nRetries = 10 if $nRetries eq "";
    $waitSecs = 10 if $waitSecs eq "";

    for( my $i = 0; $i < $nRetries; $i++ ) {
       webLog( "waitLoop: i=$i nRetries=$nRetries waitSecs=$waitSecs\n" );
       last if waitLoopPsOk( );
       sleep $waitSecs;
    }
    webLog( "waitLoop: ok to proceed\n" );
}

sub waitLoopPsOk {
    my $cmd = "/bin/ps -eo pid,ppid,user,comm,start | /bin/grep www-data";
    unsetEnvPath( );
    my $rfh = newCmdFileHandle( $cmd, "waitLoopPs" );
    my @rows;
    my %child;
    my %command;
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       $s =~ s/^\s+//;
       $s =~ s/\s+$//;
       $s =~ s/\s+/ /g;
       my( $pid, $ppid, $user, $comm, $start ) = split( / /, $s );
       push( @rows, $s );
       $child{ $ppid } = $pid;
       $command{ $pid } = $comm;
    }
    close $rfh;
    resetEnvPath( );
    my @rows2;
    for my $s( @rows ) {
       my( $pid, $ppid, $user, $comm, $start ) = split( / /, $s );
       my $startVal = timeVal( $start );
       my $s2 = "$startVal $s";
       next if $comm ne "perl";
       my $cpid = $child{ $pid };
       my $ccomm = $command{ $cpid };
       next if $pid != $$ && $ccomm ne "blastall";
       push( @rows2, $s2 );
    }
    my @rows3 = sort{ $a <=> $b }sort( @rows2 );
    my $count = 0;
    for my $s( @rows3 ) {
       my( $startVal, $pid, $ppid, $user, $comm, $start ) = split( / /, $s );
       $count++;
       if( $pid == $$ && $count == 1 ) {
	  webLog( "waitLoopPsOk: match self.pid=$$ with '$s'\n" );
          return 1;
       }
    }
    return 0;
}


1;
