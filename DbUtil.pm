############################################################################
# DbUtil.pm - Database utilities for Oracle.
############################################################################
package DbUtil;
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
   execSql
   execSqlFetch1
   execSqlOnly
   oracleLoginPw
   getTmpFile
   getScratchDir
);
use strict;
use DBI qw( :sql_types );
use MIME::Base64 qw( encode_base64 decode_base64 );
use WebServerUtil;

############################################################################
# execSql - Convenience wrapper to execute an SQL.
############################################################################
sub execSql{ 
   my( $dbh, $sql, $verbose, @args ) = @_;
   print( "$sql\n" ) if $verbose >= 1;
   my $nArgs = @args;
   if( $nArgs > 0 ) {
      my $s;
      for( my $i = 0; $i < $nArgs; $i++ ) {
         my $a = $args[ $i ];
         $s .= "arg[$i] '$a'\n";
      }
      print "$s\n" if $verbose >= 1;
   }
   my $cur = $dbh->prepare( $sql ) or
      webDie( "execSql: cannot preparse statement: $DBI::errstr\n" );
   $cur->execute( @args ) or
      webDie( "execSql: cannot execute: $DBI::errstr\n" );
   return $cur;
}   

############################################################################
# execSqlFetch1 - Convenience wrapper to execute an SQL and
#   fetch first row.
############################################################################
sub execSqlFetch1{ 
   my( $dbh, $sql, $verbose, @args ) = @_;
   print( "$sql\n" ) if $verbose >= 1;
   my $nArgs = @args;
   if( $nArgs > 0 ) {
      my $s;
      for( my $i = 0; $i < $nArgs; $i++ ) {
         my $a = $args[ $i ];
         $s .= "arg[$i] '$a'\n";
      }
      print "$s\n" if $verbose >= 1;
   }
   my $cur = $dbh->prepare( $sql ) ||
      webDie( "execSql: cannot preparse statement: $DBI::errstr\n" );
   $cur->execute( @args ) ||
      webDie( "execSql: cannot execute: $DBI::errstr\n" );
   return $cur->fetchrow( );
}   
    
############################################################################
# execSqlOnly - Convenience wrapper to execute an SQL. This does not
#   do any fetches.
############################################################################
sub execSqlOnly{
   my( $dbh, $sql, $verbose, @args ) = @_;
   print( "$sql\n" ) if $verbose >= 1;
   my $cur = $dbh->prepare( $sql ) ||
      webDie( "execSql: cannot preparse statement: $DBI::errstr\n" );
   my $nArgs = @args;
   if( $nArgs > 0 ) {
      my $s;
      for( my $i = 0; $i < $nArgs; $i++ ) {
         my $a = $args[ $i ];
         $s .= "arg[$i] '$a'\n";
      }
      print "$s\n";
   }
   $cur->execute( @args ) ||
      webDie( "execSql: cannot execute: $DBI::errstr\n" );
   $cur->finish( );
}

############################################################################
# prepSql - Prepare SQL
############################################################################
sub prepSql{ 
   my( $dbh, $sql, $verbose ) = @_;
   print "$sql\n" if $verbose >= 1;
   my $cur = $dbh->prepare( $sql ) ||
      webDie( "execSql: cannot preparse statement: $DBI::errstr\n" );
   return $cur;
}
############################################################################
# execSqlVars - Execute prep SQL variables.
############################################################################
sub execSqlVars {
   my( $cur, $verbose, @vars ) = @_;
   if( $verbose ) {
       my $nVars = @vars;
       print "execSqlVars:\n";
       for( my $i = 0; $i < $nVars; $i++ ) {
	  my $v = $vars[ $i ];
          print "  [$i] '$v'\n" if $verbose >= 1;
       }
       print "\n" if $verbose >= 1;
   }
   $cur->execute( @vars ) ||
      webDie( "execSqlVars: cannot execute $DBI::errstr\n" );
   return $cur;
}

############################################################################
# execStmt - Execulte SQL statement
############################################################################
sub execStmt {
   my( $cur, @vars ) = @_;
   $cur->execute( @vars ) ||
      webDie( "execStmt: cannot execute $DBI::errstr\n" );
   return $cur;
}
############################################################################
# execPrepSql - Execulte SQL statement
############################################################################
sub execPrepSql {
   my( $cur, @vars ) = @_;
   $cur->execute( @vars ) ||
      webDie( "execPrepSql: cannot execute $DBI::errstr\n" );
   return $cur;
}

############################################################################
# execStmtFetch - Execute and fetch row result.
############################################################################
sub execStmtFetch {
   my( $cur, @vars ) = @_;
   $cur->execute( @vars ) ||
      webDie( "execStmt: cannot execute $DBI::errstr\n" );
   return $cur->fetchrow( );
}

############################################################################
# oracleLoginPw - Oracle login with password.
############################################################################
sub oracleLoginPw {
   my( $pw ) = @_;

   my $oraDsn = $ENV{ ORA_DBI_DSN };
   my $oraUser = $ENV{ ORA_USER };
   my $oraPw = $ENV{ ORA_PASSWORD };

   print ">>> Login '$oraUser'\n";
   my $dbh;
   my $user = $ENV{ ORA_USER };
   if( defined( $ENV{ ORA_PORT } ) ) {
        $dbh = DBI->connect( "dbi:Oracle:host=$ENV{ORA_HOST};" .
           "sid=$ENV{ORA_SID};port=$ENV{ORA_PORT}", $user, pwDecode($pw) )
   }
   else {
       $dbh = DBI->connect( $oraDsn, $oraUser, pwDecode( $pw ) );
   }
   if( !defined( $dbh ) ) {
      webDie( "oracleLoginPw: cannot login '$oraUser' '$pw' \@ '$oraDsn'\n" );
   }
   my $maxClobSize = 40000;
   $dbh->{ LongReadLen } = $maxClobSize;
   $dbh->{ LongTruncOk } = 1;
   return $dbh;
}

############################################################################
# decode - Decode base64
############################################################################
sub decode {
   my( $b64 ) = @_;
   my $s = decode_base64( $b64 );
   return $s;
}

############################################################################
# pwDecode - Password decode if encoded.
############################################################################
sub pwDecode {
   my( $pw ) = @_;
   my( $tag, @toks ) = split( /:/, $pw );
   if( $tag eq "encoded" ) {
      my $val = join( ':', @toks );
      return decode( $val );
   }
   else {
      return $pw;
   }
}

############################################################################
# getTmpFile - Get path for temp file.
############################################################################
sub getTmpFile {
    my( $step, $filename ) = @_;

    $filename = lastPathTok( $filename );
    my $scratchDir = getScratchDir( );
    my $user = $ENV{ USER };
    return "$scratchDir/$user.$$.$step.$filename";
}

############################################################################
# getScratchDir - Get scratch directory.  This is usually larger than
#    /tmp or /var/tmp
############################################################################
sub getScratchDir {
   my( $subdir ) = @_;

   ## NERSC
   $ENV{ SCRATCH_DIR }= $ENV{ SCRATCH } if !blankStr( $ENV{ SCRATCH } );
   $ENV{ SCRATCH_DIR }= $ENV{ SCRATCH2 } if !blankStr( $ENV{ SCRATCH2 } );

   ## My own
   my $scratch_dir = $ENV{ SCRATCH_DIR };
   if( -w "/scratch" ) {
       return "/scratch/$subdir";
   }
   elsif( $scratch_dir ne "" && -w $scratch_dir ) {
       return "$scratch_dir/$subdir";
   }
   elsif( -w "/tmp" )  {
      return "/tmp/$subdir";
   }
   else {
       webDie( "getScratchDir: no suitable writable scratch\n" );
   }
}

