############################################################################
# PepStats.pm - Peptide statistics.   Run and show peptide stats
#   in the web UI.
#    --es 12/13/2005
#
# $Id: PepStats.pm 30360 2014-03-08 00:12:52Z jinghuahuang $
############################################################################
package PepStats;
my $section = "PepStats";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebUtil;
use WebConfig;

$| = 1;


my $env = getEnv( );
my $pepstats_bin = $env->{ pepstats_bin };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $bin_dir =  $env->{ bin_dir };
my $verbose = $env->{ verbose };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "" ) {
    }
    else {
    }
}

############################################################################
# printPepStats - Print peptide statistics.
############################################################################
sub printPepStats {
   my( $gene_oid ) = @_;

   my $dbh = dbLogin( );
   checkGenePerm( $dbh, $gene_oid );
   printMainForm( );
   print "<h1>Peptide Statistics</h1>\n";
   print "<p>\n";
   print "Peptide statistics are shown for the following protein.\n";
   print "</p>\n";

   my $sql = qq{
       select g.gene_oid, g.gene_display_name, scf.ext_accession, g.aa_residue
       from gene g, scaffold scf
       where g.gene_oid = ?
       and g.scaffold = scf.scaffold_oid 
   };
   my @binds = ($gene_oid);
   my $cur = execSql( $dbh, $sql, $verbose, @binds );
   my( $gene_oid, $gene_display_name, $ext_accession, $aa_residue ) = 
      $cur->fetchrow( );
   $cur->finish( );

   print "<pre>\n";
   print "<font color='blue'>";
   print ">$gene_oid $gene_display_name [$ext_accession]\n";
   print "</font>\n";
   my $seq2 = wrapSeq( $aa_residue );
   print "$seq2\n";

   my $tmpFile1 = "$cgi_tmp_dir/pepstats$$.faa";
   $tmpFile1 = checkTmpPath( $tmpFile1 );
   my $wfh = newWriteFileHandle( $tmpFile1, "printPepStats" );
   print $wfh ">$gene_oid $gene_display_name [$ext_accession]\n";
   print $wfh "$seq2\n";
   close $wfh;
   my $tmpFile2 = "$cgi_tmp_dir/pepstats$$.out";
   runCmd( "$pepstats_bin -sequence $tmpFile1 -outfile $tmpFile2" );
   my $rfh = newReadFileHandle( $tmpFile2, "printPepStats" );
   print "<font color='blue'>\n";
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       print "$s\n";
   }
   close $rfh;
   print "</font>\n";

   print "</pre>\n";
   wunlink( $tmpFile1 );
   wunlink( $tmpFile2 );
   print end_form( );
   #$dbh->disconnect( );
}

############################################################################
# cleanLibs - Clean library directory.
############################################################################
sub cleanLibs {
   my $tmp_libs = "$bin_dir/.libs";
   if( !-e $tmp_libs ) {
       warn( "cleanLibs: $tmp_libs does not exist\n" );
       return;
   }
   my @files = dirList( $tmp_libs );
   for my $f( @files ) {
      my $path = "$tmp_libs/$f";
      unlink( $path );
   }
}

1;

