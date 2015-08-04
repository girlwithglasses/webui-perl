############################################################################
# Run external PDB Blast.
#    --es 06/20/2007
#
# $Id: PdbBlast.pm 31512 2014-07-28 17:51:15Z klchu $
############################################################################
package PdbBlast;
my $section = "PdbBlast";
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    runPdbBlast
    processContent
);
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use ScaffoldPanel;
use LWP::UserAgent;
use HTTP::Request::Common qw( POST );
use WebConfig;
use WebUtil;

$| = 1;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $blast_data_dir = $env->{ blast_data_dir };
my $pdb_blast_url = $env->{ pdb_blast_url };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( paramMatch( "pdbBlast" ) ) {
        runPdbBlast( );
    }
    else {
        runPdbBlast( );
    }
}

############################################################################
# runPdbBlast - Run from external BLAST databases.
#   Inputs:
#      gene_oid - gene object identifier
############################################################################
sub runPdbBlast {
   my $gene_oid = param( "genePageGeneOid" );
   my $genome_type = param( "genome_type" );

   my $aa_residue;
   if ( $genome_type eq "metagenome" ) {
       my $taxon_oid = param( "taxon_oid" );
       my $data_type = param( "data_type" );
       require MetaUtil;
       $aa_residue = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
   } else {
       my $dbh = dbLogin( );
       $aa_residue = WebUtil::geneOid2AASeq( $dbh, $gene_oid );
       #$dbh->disconnect( );
   }

   my $seq = wrapSeq( $aa_residue );

   my $ua = WebUtil::myLwpUserAgent(); 
   $ua->agent( "img/1.0" );

   my $url = $pdb_blast_url;
   my $req = POST $url, [
   ];
   my $res = $ua->request( $req );
   if( $res->is_success( ) ) {
      processContent( $res->content, $gene_oid, $seq );
   }
   else {
      webError( $res->status_line );
      webLog $res->status_line;
   }
   WebUtil::webExit(0);
}

############################################################################
# processContent
############################################################################
sub processContent {
   my( $content, $gene_oid, $seq ) = @_;
   my @lines = split( /\n/, $content );
   #my $fasta = ">$gene_oid\n";
   my $fasta = "$seq\n";
   for my $s( @lines ) {
      if(  $s =~ /textarea/ && $s =~ /"sequence"/ ) {
          $s =~ s/><\/textarea>/>$fasta<\/textarea>/;
	  print "$s\n";
      }
      elsif( $s =~ /"radio"/ && $s =~ /inputFASTA_useStructureId/ ) {
	 if( $s =~  /"true"/ ) {
	    $s =~ s/"true"/"false"/;
	    $s =~ s/checked//;
	 }
	 elsif( $s =~  /"false"/ ) {
	    $s =~ s/"false"/"true"/;
	    $s =~ s/onClick/checked onClick/;
	 }
	 print "$s\n";
      }
      elsif( $s =~ /<head>/ ) {
          print "$s\n";
	  print "<base href='$pdb_blast_url' />\n";
      }
      else {
          print "$s\n";
      }
   }
}


1;


