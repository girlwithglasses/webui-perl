############################################################################
# Run external EBI InterPro Scan.
#    --es 03/22/2007
############################################################################
package EbiIprScan;
my $section = "EbiIprScan";
require Exporter;
@ISA = qw( Exporter );
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
my $ebi_iprscan_url = $env->{ ebi_iprscan_url };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    runIprScan( );
}

############################################################################
# runIprScan - Run InterPro scan.
#   Inputs:
#      gene_oid - gene object identifier
############################################################################
sub runIprScan {
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
       #$dbh->disconnect();
   }

   my $seq = wrapSeq( $aa_residue );

   my $ua = WebUtil::myLwpUserAgent(); 
   $ua->agent( "img/1.0" );

   my $url = $ebi_iprscan_url;
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
      if(  $s =~ /textarea/ && $s =~ /sequence/ ) {
	  print "$s\n";
	  print "$seq\n";
      }
      elsif( $s =~ /<head>/ ) {
          print "$s\n";
	  print "<base href='$ebi_iprscan_url' />\n";
      }
      else {
          print "$s\n";
      }
   }
}


1;


