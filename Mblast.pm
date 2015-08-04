############################################################################
# Mblast.pm - Multiple BLAST interface.
#   Use $DATALOAD_HOME/steps/mblast for MPI syncrhonized
#   NCBI BLAST across multiple machines.
#       --es 07/14/10
############################################################################
package Mblast;
my $section = "Mblast";
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
   checkMblastUse
   runMblastM0
   runMblastM8
);

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use LwpHandle;

$| = 1;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $webMblast_url         = $env->{ webMblast_url };
my $webMblast_db          = $env->{ webMblast_db };
my $use_webMblast_genePage = $env->{ use_webMblast_genePage };
my $mblast_reports_dir    = $env->{ mblast_reports_dir };
my $mblast_tmp_dir        = $env->{ mblast_tmp_dir };
my $oracle_config         = $env->{ oracle_config };
my $max_wait_secs	  = 40 * 60;
my $blocking              = 1;

############################################################################
# checkMblastUse - Check to see if we're set up to use Mblast.
############################################################################
sub checkMblastUse {
   my( $pgm ) = @_;

   # We support only blastp for now.
   #return 0 if $pgm ne "blastp";
   return 0 if $pgm ne "blastp" && $pgm ne "blastx";

   return 1 if $webMblast_url ne "" && -e $mblast_reports_dir &&
      -e $mblast_tmp_dir;
   return 0;
}


############################################################################
# runMblastM0 - Run mblast as a client in -m 0 format.
############################################################################
sub runMblastM0 {
    my( $pgm, $seq_id, $seq, $evalue ) = @_;

    my( $purged, $nFiles ) = purgeMblastTmpDir( );
    webLog( "purge mblast $purged / $nFiles files\n" );

    $seq =~ s/\s+//g;
    if( $pgm eq "blastx" ) {
       my $x = $seq;
       $x =~ /([actgnACTGN]+)/;
       $x = $1;
       if( length( $seq ) != length( $x ) ) {
	   printStatusLine( "Error.", 2 );
	   webError( "Check that your BLASTX query sequence is DNA." );
           return;
       }
    }

    require $oracle_config;
    my $db = $ENV{ ORA_USER };
    $db = $webMblast_db if $webMblast_db ne "";

    my $dbh = dbLogin( );

    my $id = getSessionId( ) .  "_" . $$;

    my $tmpFasta = "$mblast_tmp_dir/$id.fa";
    my $wfh = newWriteFileHandle( $tmpFasta, "runMblast" );
    my $seq2 = wrapSeq( $seq );
    print $wfh ">$seq_id\n";
    print $wfh "$seq2\n";
    close $wfh;
    webLog( "runblatM0: tmpFasta='$tmpFasta'\n" );

    my $tmpValidTaxons = "$mblast_tmp_dir/$id.validTaxons.txt";
    my %validTaxons = WebUtil::getAllTaxonsHashed( $dbh );
    my @taxon_oids = sort{ $a <=> $b }keys( %validTaxons );
    my $wfh = newWriteFileHandle( $tmpValidTaxons, "runMblast" );
    for my $taxon_oid( @taxon_oids ) {
       print $wfh "$taxon_oid\n";
    }
    close $wfh;
    webLog( "runMblastM0: validTaxons='$tmpValidTaxons'\n" );

    printStartWorkingDiv( );

    if( $blocking ) {
	print "Searching ( please be patient )  ...<br/>\n";
    }

    my %args;
    $args{ id } = $id;
    $args{ qfile } = $tmpFasta;
    $args{ db } = $db;
    $args{ pgm } = $pgm;
    $args{ m } = 0;
    $args{ evalue } = $evalue;
    $args{ validTaxons } = $tmpValidTaxons;
    my @keys = keys( %args );
    my $s;
    for my $arg( @keys ) {
       my $val = $args{ $arg };
       $s .= "$arg='$val' ";
    }
    chop $s;
    webLog( "$webMblast_url: $s\n" );


    my $cfh = new LwpHandle( $webMblast_url, \%args );

    my $reportFile = "$mblast_reports_dir/$id.txt";
    my $doneFile = "$mblast_reports_dir/$id.done";

    if( !$blocking ) {
        print "Searching ";
        for( my $i = 0; $i < $max_wait_secs; $i++ ) {
            last if -e $doneFile;
	    print "." if $verbose >= 1;
	    sleep 1;
        }
        print "<br/>\n";
    }
    printEndWorkingDiv( );

    showReport( $reportFile, $db );

    unlink( $tmpFasta );
    unlink( $tmpValidTaxons );
    #$dbh->disconnect();
}

############################################################################
# runMblastM8 - Run mblast as a client in -m 8 format.
############################################################################
sub runMblastM8 {
    my( $pgm, $seq_id, $seq, $evalue ) = @_;

    my( $purged, $nFiles ) = purgeMblastTmpDir( );
    webLog( "purge mblast $purged / $nFiles files\n" );

    $seq =~ s/\s+//g;

    require $oracle_config;
    my $db = $ENV{ ORA_USER };
    $db = $webMblast_db if $webMblast_db ne "";

    my $dbh = dbLogin( );

    if( $seq eq "" ) {
       $seq = geneOid2AASeq( $dbh, $seq_id );
    }

    my $id = getSessionId( ) .  "_" . $$;

    my $tmpFasta = "$mblast_tmp_dir/$id.fa";
    my $wfh = newWriteFileHandle( $tmpFasta, "runMblast" );
    my $seq2 = wrapSeq( $seq );
    print $wfh ">$seq_id\n";
    print $wfh "$seq2\n";
    close $wfh;
    webLog( "runMblastM8: tmpFasta='$tmpFasta'\n" );

    my $tmpValidTaxons = "$mblast_tmp_dir/$id.validTaxons.txt";
    my %validTaxons = WebUtil::getAllTaxonsHashed( $dbh );
    my @taxon_oids = sort{ $a <=> $b }keys( %validTaxons );
    my $wfh = newWriteFileHandle( $tmpValidTaxons, "runMblast" );
    for my $taxon_oid( @taxon_oids ) {
       print $wfh "$taxon_oid\n";
    }
    close $wfh;
    webLog( "runMblastM8: validTaxons='$tmpValidTaxons'\n" );

    printStartWorkingDiv( );

    if( $blocking ) {
	print "Searching ( please be patient )  ...<br/>\n";
    }

    my %args;
    $args{ id } = $id;
    $args{ qfile } = $tmpFasta;
    $args{ db } = $db;
    $args{ pgm } = $pgm;
    $args{ m } = 8;
    $args{ evalue } = $evalue;
    $args{ validTaxons } = $tmpValidTaxons;
    my @keys = keys( %args );
    my $s;
    for my $arg( @keys ) {
       my $val = $args{ $arg };
       $s .= "$arg='$val' ";
    }
    chop $s;
    webLog( "$webMblast_url: $s\n" );


    my $cfh = new LwpHandle( $webMblast_url, \%args );

    my $reportFile = "$mblast_reports_dir/$id.txt";
    my $doneFile = "$mblast_reports_dir/$id.done";

    if( !$blocking ) {
        print "Searching ";
        for( my $i = 0; $i < $max_wait_secs; $i++ ) {
            last if -e $doneFile;
	    print "." if $verbose >= 1;
	    sleep 1;
        }
        print "<br/>\n";
    }
    printEndWorkingDiv( );

    my @rows;
    my $rfh = newReadFileHandle( $reportFile, "runBlastM8" );
    while( my $s = $rfh->getline( ) ) {
        chomp $s;
	push( @rows, $s );
    }
    close $rfh;

    unlink( $tmpFasta );
    unlink( $tmpValidTaxons );
    #$dbh->disconnect();
    return @rows;
}


############################################################################
# showReport - Show report and handle formatting.
############################################################################
sub showReport {
    my( $inFile, $db ) = @_;

    printMainForm( );
    print "<br/>\n";
    my $rfh = newReadFileHandle( $inFile, "showReport" );
    my $count = 0;
    while( my $s = $rfh->getline( ) ) {
        chomp $s;
	if( $s =~ /Database:/ ) {
	    print "Database: $db<br/>\n";
	}
	elsif( $s =~ /Sequences producing significant alignments/ ) {
	    printGeneCartFooter( );
	    print "$s\n";
	}
	elsif( $s =~ /<\/table>/ ) {
	    print "$s\n";
	    printGeneCartFooter( );
	}
	elsif( $s =~ /^>/ ) {
	    $count++;
	    my( $gene_oid, @toks ) = split( / /, $s );
	    $gene_oid =~ s/^>//;
	    my $desc = join( ' ', @toks );
	    my  $url = 
	      "$main_cgi?section=GeneDetail" .
	      "&page=geneDetail&gene_oid=$gene_oid";
	    print ">" . alink( $url, $gene_oid ) . nbsp( 1 ) . "$desc\n";
	}
	else {
	   print "$s\n";
	}
    }
    printStatusLine( "Loaded.", 2 );

    close $rfh;
    print end_form( );
}

############################################################################
# purgeMblastTmpDir
############################################################################
sub purgeMblastTmpDir {
   my $max_time_diff = 60 * 60 * 4;

   my @files = dirList( $mblast_tmp_dir );
   my $nFiles += scalar( @files );
   my $now = time( );
   my $count = 0;
   for my $f( @files ) {
       next if $f eq "index.html";
       my $path = "$mblast_tmp_dir/$f";
       my $t = fileAtime( $path );
       my $diff = $now - $t;
       webLog "path='$path' now=$now t=$t diff=$diff\n" if $verbose >= 5;
       if( $f =~ /^cgisess_/ && $diff > ( $max_time_diff * 240 ) ) {
           webLog "   purge\n" if $verbose >= 5;
           $count++;
           wunlink( $path );
       }
       elsif( $diff > $max_time_diff ) {
           webLog "   mblast purge\n" if $verbose >= 5;
           $count++;
           wunlink( $path );
       }
   }
   return( $count, $nFiles );
}


1;
