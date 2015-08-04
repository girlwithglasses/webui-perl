############################################################################
# DataEvolution.pm - Set up to show data evolutions results.
#   Customize img_version for each release.
#   --es 05/10/2005
############################################################################
package DataEvolution;

require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    printDataEvolutionPage
    printGenomeDeletedGenesList
    printCdsSummaryRows
);

use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use ScaffoldPanel;
use WebConfig;
use WebUtil;

my $section = "DataEvolution"; 
my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $base_dir = $env->{ base_dir };
my $img_internal = $env->{ img_internal };
my $tmp_dir = $env->{ tmp_dir };
my $verbose = $env->{ verbose };

my $img_version = "2.0";
$img_version = $env->{ img_version }
  if $env->{ img_version } ne "";

############################################################################
# dispatch
############################################################################
sub dispatch {
    my $page = param( "page" );
    if( $page eq "dataEvolutionPage" ) {
       printDataEvolutionPage( );
    }
    else {
       printDataEvolutionPage( );
    }
}

############################################################################
# printDataEvolutionPage - Print data evolution page.
############################################################################
sub printDataEvolutionPage {
    my $templateFile = "$base_dir/doc/dataEvolution.html";
    my $rfh = newReadFileHandle( $templateFile, "printDataEvolutionPage" );
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       $s =~ s/__main_cgi__/$section_cgi/g;
       if( $s =~ /__genome_delete_genes_list__/ ) {
          printGenomeDeletedGenesList( );
       }
       elsif( $s =~ /__spreadsheet__/ ) {
          printCdsSummaryRows( );
       }
       else {
          print "$s\n";
       }
    }
    close $rfh;
}

############################################################################
# printGenomeDeletedGenesList - Print genomes with deleted genes.
############################################################################
sub printGenomeDeletedGenesList {

    my $dbh = dbLogin( );
    if( ! WebUtil::tableExists( $dbh, "unmapped_genes_archive" ) ) {
        #$dbh->disconnect();
	print "(This database does not have any deleted gene mappings.)\n";
	print "<br/>\n";
	return;
    }
    my $sql = qq{
        select distinct uga.old_taxon_oid, uga.taxon_name
        from unmapped_genes_archive uga
	order by uga.taxon_name
    };
    my $cur = execSql( $dbh, $sql, $verbose  );
    print "<br/>\n";
    for( ;; ) {
        my( $taxon_oid, $taxon_display_name ) = $cur->fetchrow( );
	last if !$taxon_oid;
	my $url = "$main_cgi?section=TaxonDetail" . 
	   "&page=deletedGeneList&taxon_oid=$taxon_oid";
	print nbsp( 4 );
	print alink( $url, $taxon_display_name );
	print "<br/>\n";
    }
    #$dbh->disconnect();
}

############################################################################
# printCdsSummaryRows - Print CDS table rows.
############################################################################
sub printCdsSummaryRows {

    my $dbh = dbLogin( );
    if( ! WebUtil::tableExists( $dbh, "cds_mapping_summary" ) ) {
        #$dbh->disconnect();
	print "</table>\n";
	print "(This database does not have the CDS mapping summary table.)\n";
	print "<br/>\n";
	return;
    }
    
    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select ms.old_taxon_oid, ms.new_taxon_oid, ms.old_taxon_name, 
	   ms.new_taxon_name, ms.old_cds_count, ms.new_cds_count,
	   ms.total_mapped, ms.percent_mapped, ms.un_mapped_count, 
	   ms.replacement, ms.img_version
        from cds_mapping_summary ms, taxon tx
	where ms.new_taxon_oid = tx.taxon_oid
	$rclause
	$imgClause
	order by ms.old_taxon_name
    };
	#and tx.is_replaced = 'Yes'
	#and tx.img_version = 'IMG/W $img_version'
    my $cur = execSql( $dbh, $sql, $verbose  );
    print "<br/>\n";
    print "<p>\n";
    print "IMG/W $img_version replacements are shown below.<br/>\n";
    print "</p>\n";
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Old Taxon Name</th>\n";
    print "<th class='img'>New Taxon Name</th>\n";
    print "<th class='img'>Old Taxon ID</th>\n";
    print "<th class='img'>New Taxon ID</th>\n";
    print "<th class='img'>Old CDS Count</th>\n";
    print "<th class='img'>New CDS Count</th>\n";
    print "<th class='img'>Total Mapped</th>\n";
    print "<th class='img'>Percent Mapped</th>\n";
    print "<th class='img'>Unmapped Count</th>\n";
    print "<th class='img'>Replacement</th>\n";
    print "<th class='img'>IMG Version</th>\n";
    for( ;; ) {
        my( $old_taxon_oid, $new_taxon_oid, $old_taxon_name, $new_taxon_name,
	    $old_cds_count, $new_cds_count,
	    $total_mapped, $percent_mapped, $un_mapped_count, 
	    $replacment, $img_version ) = $cur->fetchrow( );
        last if !$old_taxon_oid;
	$percent_mapped = sprintf( "%.2f", $percent_mapped );
	print "<tr class='img' >\n";
	print "<td class='img' >" . escHtml( $old_taxon_name ) . "</td>\n";
	print "<td class='img' >" . escHtml( $new_taxon_name ) . "</td>\n";
	print "<td class='img' >$old_taxon_oid</td>\n";
	my $url = "$main_cgi?section=TaxonDetail" . 
	   "&page=taxonDetail&taxon_oid=$new_taxon_oid";
	print "<td class='img' >" . alink( $url, $new_taxon_oid ) . "</td>\n";
	print "<td class='img'  align='right'>$old_cds_count</td>\n";
	print "<td class='img'  align='right'>$new_cds_count</td>\n";
	print "<td class='img'  align='right'>$total_mapped</td>\n";
	print "<td class='img'  align='right'>$percent_mapped%</td>\n";
	print "<td class='img'  align='right'>$un_mapped_count</td>\n";
	print "<td class='img'  align='left'>" . 
	   escHtml( $replacment ) . "</td>\n";
	print "<td class='img'  align='left'>" . 
	   escHtml( $img_version ) . "</td>\n";
	print "</tr>\n";
    }
    #$dbh->disconnect();
    print "</table>\n";
}


1;
