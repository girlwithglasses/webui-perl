############################################################################
# Run external Greengenes Blast.
#    --es 04/12/2007
############################################################################
package GreenGenesBlast;
my $section = "GreenGenesBlast";
require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    runNcbiBlast
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
use SequenceExportUtil;

$| = 1;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $taxon_lin_fna_dir = $env->{ taxon_lin_fna_dir };
my $verbose = $env->{ verbose };
my $greengenes_blast_url = $env->{ greengenes_blast_url };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    runGreenGenesBlast( );
}

############################################################################
# runGreenGenesBlast - Run from external BLAST databases.
#   Inputs:
#      gene_oid - gene object identifier
############################################################################
sub runGreenGenesBlast {

   my $gene_oid = param( "genePageGeneOid" );
   my $taxon_oid = param( "genePageTaxonOid" );
   my $data_type = param( "genePageDataType" );

   my $dna_seq = "";
   my $strand;
   my $scaf_oid;
   my @junk;

   if ( $taxon_oid && $data_type ) {
       # MER-FS gene
       require MetaUtil;
       ($dna_seq, $strand, $scaf_oid) = MetaUtil::getGeneFna($gene_oid, $taxon_oid, $data_type);
   }
   else {
       my $dbh = dbLogin( );
       ($dna_seq, @junk) = SequenceExportUtil::getGeneDnaSequence( $dbh, $gene_oid );
   }
   my $seq = wrapSeq( $dna_seq );

   my $ua = WebUtil::myLwpUserAgent(); 
   $ua->agent( "img/1.0" );

   my $url = $greengenes_blast_url;
   my $req = POST $url, [
   ];
   my $res = $ua->request( $req );
   if( $res->is_success( ) ) {
      processContent( $res->content, $seq );
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
   my( $content, $seq ) = @_;
   my @lines = split( /\n/, $content );
   for my $s( @lines ) {
      if(  $s =~ /textarea/ && $s =~ /paste/ ) {
          $s =~ s/><\/textarea>/>$seq<\/textarea>/;
	  print "$s\n";
      }
      elsif( $s =~ /form method/ && $s !~ /google/ && $s !~ /smallMenu/ ) {
	  my $x = "action='$greengenes_blast_url'";
          print "<form method=POST $x ENCTYPE='multipart/form-data'>\n";
      }
      elsif( $s =~ /<head>/ ) {
          print "$s\n";
	  print "<base href='$greengenes_blast_url' />\n";
      }
      else {
          print "$s\n";
      }
   }
}


1;


