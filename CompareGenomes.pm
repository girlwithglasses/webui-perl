############################################################################
# CompareGenomes.pm - Main page for comparing genomes including
#   cumulative statistics.  Formerly taxonStatsRdbms.pl
#      --es 07/07/2005
#
# $Id: CompareGenomes.pm 33883 2015-08-03 23:46:04Z aireland $
############################################################################
package CompareGenomes;
my $section = "CompareGenomes";

use strict;
use warnings;

use CGI qw( :standard );
use DBI;
use ScaffoldPanel;
use Data::Dumper;
use CompTaxonStats;
use WebConfig;
use WebUtil;
use ChartUtil;
use InnerTable;
use TaxonDetail;
use DataEntryUtil;
use GenomeCart;
use HtmlUtil;

$| = 1;

my $env                  = getEnv();
my $tmp_url              = $env->{tmp_url};
my $base_url             = $env->{base_url};
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $img_internal         = $env->{img_internal};
my $img_lite             = $env->{img_lite};
my $include_metagenomes  = $env->{include_metagenomes};
my $include_img_terms    = $env->{include_img_terms};
my $img_er               = $env->{img_er};
my $img_geba             = $env->{img_geba};
my $chart_exe            = $env->{chart_exe};
my $show_myimg_login     = $env->{show_myimg_login};
my $vista_url_map_file   = $env->{vista_url_map_file};
my $verbose              = $env->{verbose};
my $user_restricted_site = $env->{user_restricted_site};
my $img_edu              = $env->{img_edu};
my $snp_enabled          = $env->{snp_enabled};
my $enable_cassette      = $env->{enable_cassette};
my $enable_biocluster    = $env->{enable_biocluster};
my $content_list         = $env->{content_list};
my $include_ht_stats     = $env->{include_ht_stats};
my $essential_gene       = $env->{essential_gene};
my $nvl                  = getNvl();
my $YUI                  = $env->{yui_dir_28};
my $enable_interpro = $env->{enable_interpro};
my $enable_ani    = $env->{enable_ani};

# Get user's MyIMG preference to show rows with zero counts
# -- per Natalia for IMG 3.3 +BSJ 10/15/10
my $hideZeroStats = getSessionParam("hideZeroStats");
$hideZeroStats = "Yes" if (!defined($hideZeroStats) || $hideZeroStats eq  "");

my $maxDbGenomeSelectionAllowed = 80;
my $maxMetagenomeSelectionAllowed = 15;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( paramMatch("exportCompStats") ne "" ) {
        checkAccess();
        printTaxonBreakdownStats("export");
        WebUtil::webExit(0);
    } elsif ( $page eq "taxonStats" ) {
        printStatsForOneTaxon();
    } elsif ( $page eq "compareKeggStats" ) {
        BarChartImage::dispatch();
    } elsif ( $page eq "compareGenomes" ) {
        printStatsForMultipleTaxons();
    } elsif ( $page eq "compareCOGStats" ) {
        BarChartImage::dispatch();
    } elsif ( $page eq "compareKOGStats" ) {
        BarChartImage::dispatch();
    } elsif ( $page eq "comparePfamStats" ) {
        BarChartImage::dispatch();
    } elsif ( $page eq "compareTIGRfamStats" ) {
        BarChartImage::dispatch();
    } elsif ( paramMatch("statTableName") ne ""
	      && ( $page eq "taxonBreakdownStats"
		   || paramMatch("setTaxonBreakdownStatCols") ne "" ) ) {
        printTaxonBreakdownStats("display");
    } elsif ( $page eq "essentialGeneList" ) {
    	require EssentialGene;
    	EssentialGene::essentialGeneList();
    } elsif ( paramMatch("requestTaxonRefresh") ne "" ||
	      $page eq "requestTaxonRefresh" ) {
    	addTaxonRefreshRequest();
    } else {
        webLog("CompareGenomes::dispatch: unknown page='$page'\n");
        warn("CompareGenomes::dispatch: unknown page='$page'\n");
    }
}

############################################################################
# printStatsForOneTaxon - Stats for current taxon page.
############################################################################
sub printStatsForOneTaxon {
    my $taxon_oid = param("taxon_oid");
    my @taxon_oids;
    push( @taxon_oids, $taxon_oid );
    my $dbh = dbLogin();
    #if ( validProxyGeneReads( $dbh, $taxon_oid ) ) {
    #    printStatsWithReads( $dbh, \@taxon_oids );
    #} else {
    printStats( $dbh, \@taxon_oids );
    #}
    #$dbh->disconnect();
}

############################################################################
# printStatsForPangenome - Stats for pangenome
############################################################################
sub printStatsForPangenome {
    my $taxon_oid = param("taxon_oid");
    my $dbh = dbLogin();
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql = qq{
        select distinct pangenome_composition
        from taxon_pangenome_composition t
        where t.taxon_oid = ?
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @taxon_oids;
    for (;;) {
        my ($id) = $cur->fetchrow();
        last if !$id;
	push( @taxon_oids, $id );
    }
    $cur->finish();

    my @taxon_oids; # temporarily
    push( @taxon_oids, $taxon_oid );
    printStats( $dbh, \@taxon_oids, "pangenome" );
    #$dbh->disconnect();
}

############################################################################
# printStatsForMultipleTaxons - Cumulative stats for all selected taxons.
############################################################################
sub printStatsForMultipleTaxons {
    printMainForm();

    my $dbh         = dbLogin();
    my $taxonClause = txsClause("tx", $dbh);
    my $rclause     = urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql         = qq{
       select tx.taxon_oid, tx.domain
       from taxon tx
       where 1 = 1
       $taxonClause
       $rclause
       $imgClause
    };

    my @taxon_oids;
    my %domainCount;
    $domainCount{Archaea}   = 0;
    $domainCount{Bacteria}  = 0;
    $domainCount{Eukaryota} = 0;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $domain ) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @taxon_oids, $taxon_oid );
        $domainCount{$domain}++;
    }
    $cur->finish();
    my $nTaxons = @taxon_oids;
    print pageAnchor("Genome Statistics");
    print "<h1>Genome Statistics</h1>\n";

    if ($content_list) {
        print qq{
            <p>
            &nbsp;&nbsp;&nbsp;&nbsp;<a href="#b1.0">Summary Statistics</a>
            <br>
            &nbsp;&nbsp;&nbsp;&nbsp;<a href="#b2.1">General Statistics</a>
            </p>
        };
    }

    print "<p>\n";
    print "Statistics for user-selected genomes.<br/>\n";
    my @keys = sort( keys(%domainCount) );
    for my $k (@keys) {
        my $count = $domainCount{$k};
        my $k2    = $k;
        $k2 = "Eukarya" if $k =~ /^Euk/;
        printf "%-20s : %d\n", $k2, $count;
        print nbsp(1);
    }
    print "</p>\n";
    print WebUtil::getHtmlBookmark( "b1.0", "<h2>Summary Statistics</h2>" );
    printStats( $dbh, \@taxon_oids, "compareGenomes" );

    my $url0 = "$section_cgi&page=taxonBreakdownStats";
    print WebUtil::getHtmlBookmark( "b2.1", "<h2>General Statistics</h2>" );
    my $url = "$url0&statTableName=taxon_stats&initial=1";
    print "<p>\n";
    print alink( $url, "Breakdown by selected genomes, general statistics." );
    print "</p>\n";

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# printTaxonBreakdownStats - for stats e.g. KEGG, COG, KOG, Pfam, TIGRfam
############################################################################
sub printTaxonBreakdownStats {
    my ($mode) = @_;
    my $statTableName = param("statTableName");
    my $pangenome_oid = param("pangenome_oid");

    if ( $statTableName eq "taxon_stats" ) {
        printTaxonBreakdownGenStats($mode);
    } elsif ( $statTableName eq "dt_kegg_stats" ) {
        printTaxonBreakdownKeggStats($mode, $pangenome_oid);
    } elsif ( $statTableName eq "dt_cog_stats" ) {
        printTaxonBreakdownCogStats($mode, 0, $pangenome_oid);
    } elsif ( $statTableName eq "dt_kog_stats" ) {
        printTaxonBreakdownCogStats($mode, "kog");
    } elsif ( $statTableName eq "dt_pfam_stats" ) {
        printTaxonBreakdownPfamStats($mode, $pangenome_oid);
    } elsif ( $statTableName eq "dt_tigrfam_stats" ) {
        printTaxonBreakdownTIGRfamStats($mode, $pangenome_oid);
    } else {
        webLog(   "printTaxonBreakdownStats: "
                . "unsupported statTableName='$statTableName'\n" );
        WebUtil::webExit(-1);
    }
}

#
# print book mark list
#
sub printHtmlBookmarkHeader {
    if ($content_list) {
	my $nbsp4 = "&nbsp;" x 4;
        print qq{
            <p>
            $nbsp4<a href="#genexport">Export Genome Table</a>
            <br>
            $nbsp4<a href="#genconfig">Configuration</a>
            </p>
        };
    }
}

sub printHintHeader {

    my $hideViruses  = getSessionParam("hideViruses");
    my $hidePlasmids = getSessionParam("hidePlasmids");
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    $hideViruses  = "Yes" if $hideViruses  eq "";
    $hidePlasmids = "Yes" if $hidePlasmids eq "";

    my $url = "$main_cgi?section=MyIMG&page=preferences";
    my $prefLink = alink( $url, "Preferences" );

    printHint( "- Columns can be added or removed using "
       . "the configuration table below.<br/>"
       . "- Hide Viruses: <b>$hideViruses</b> "
       . "- Hide Plasmids: <b>$hidePlasmids</b><br/>"
       . "- Hide GFragment: <b>$hideGFragment</b><br/>"
       . "- Go to $prefLink to change settings for "
       . "hiding plasmids, GFragment, and viruses."
    );

}


############################################################################
# printTaxonBreakdownGenStats - Print stats for each taxon.
#   Inputs:
#     mode - "display" or "export".
############################################################################
sub printTaxonBreakdownGenStats {
    my ($mode) = @_;

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1; # datatable.css should be loaded for the first table on page

    my $contact_oid = getContactOid();

    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    my $dbh                  = dbLogin();
    if ( $mode eq "" || $mode eq "display" ) {
        printMainForm();
        printStatusLine( "Loading ...", 1 );
        if ( blankStr($taxon_filter_oid_str) ) {
            print "<h1>Statistics For All Genomes</h1>\n";
        } else {
            print "<h1>Statistics For User-selected Genomes</h1>\n";
        }

        # html bookmark - ken
        printHtmlBookmarkHeader();
        printHintHeader();

        print "<p>\n";
        print domainLetterNote() . "<br/>\n";
        print completionLetterNote() . "<br/>\n";
        print "</p>\n";
    }

    my $cts = new CompTaxonStats( $dbh, "taxon_stats" );
    my @a_full = (
    	"taxon_oid",
    	"ncbi_taxon_id",
    	"phylum",
    	"ir_class",
    	"ir_order",
    	"family",
    	"genus",
        "gold_id",
    	"total_gene_count",
        "cds_genes",
        "cds_genes_pc",
        "rna_genes",
        "rrna_genes",
        "rrna5s_genes",
        "rrna16s_genes",
        "rrna18s_genes",
        "rrna23s_genes",
        "rrna28s_genes",
        "trna_genes",
        "other_rna_genes",
        "pseudo_genes",
        "pseudo_genes_pc",
        "uncharacterized_genes",
        "uncharacterized_genes_pc",

        #"dubious_genes",
        #"dubious_genes_pc",
        "genes_w_func_pred",
        "genes_w_func_pred_pc",
        "genes_wo_func_pred_sim",
        "genes_wo_func_pred_sim_pc",
        "genes_wo_func_pred_no_sim",
        "genes_wo_func_pred_no_sim_pc",

        "genes_in_enzymes",
        "genes_in_enzymes_pc",

        "genes_in_tc",
        "genes_in_tc_pc",

        "genes_in_kegg",
        "genes_in_kegg_pc",
        "genes_not_in_kegg",
        "genes_not_in_kegg_pc",

        "genes_in_ko",
        "genes_in_ko_pc",
        "genes_not_in_ko",
        "genes_not_in_ko_pc",

        "genes_in_orthologs",
        "genes_in_orthologs_pc",
        "genes_in_paralogs",
        "genes_in_paralogs_pc",
        "genes_in_cog",
        "genes_in_cog_pc",
        "genes_in_kog",
        "genes_in_kog_pc",
        "genes_in_pfam",
        "genes_in_pfam_pc",

        #"genes_in_tigrfam",
        #"genes_in_tigrfam_pc",
        "genes_signalp",
        "genes_signalp_pc",
        "genes_transmembrane",
        "genes_transmembrane_pc",
#        "genes_in_ipr",
#        "genes_in_ipr_pc",

        #"genes_in_img_terms",
        #"genes_in_img_terms_pc",
        #"genes_in_img_pways",
        #"genes_in_img_pways_pc",
        "genes_obsolete",
        "genes_obsolete_pc",
        "genes_revised",
        "genes_revised_pc",
        "pfam_clusters",
        "cog_clusters",
        "kog_clusters",
        "tigrfam_clusters",
        "paralog_groups",
        "ortholog_groups",
        "n_scaffolds",
        "crispr_count",
        "total_gc",
        "gc_percent",
        "total_bases",
        "total_coding_bases",
        "genes_in_eggnog",
        "genes_in_eggnog_pc"

    );
    my @a_lite = (
        "taxon_oid",
        "ncbi_taxon_id",
        "phylum",
        "ir_class",
        "ir_order",
        "family",
        "genus",
        "gold_id",
        "total_gene_count",
        "cds_genes",
        "cds_genes_pc",
        "rna_genes",
        "rrna_genes",
        "rrna5s_genes",
        "rrna16s_genes",
        "rrna18s_genes",
        "rrna23s_genes",
        "rrna28s_genes",
        "trna_genes",
        "other_rna_genes",
        "pseudo_genes",
        "pseudo_genes_pc",
        "uncharacterized_genes",
        "uncharacterized_genes_pc",
        "genes_w_func_pred",
        "genes_w_func_pred_pc",
        "genes_wo_func_pred_sim",
        "genes_wo_func_pred_sim_pc",
        "genes_wo_func_pred_no_sim",
        "genes_wo_func_pred_no_sim_pc",
        "genes_in_enzymes",
        "genes_in_enzymes_pc",
        "genes_in_tc",
        "genes_in_tc_pc",
        "genes_in_kegg",
        "genes_in_kegg_pc",
        "genes_not_in_kegg",
        "genes_not_in_kegg_pc",
        "genes_in_ko",
        "genes_in_ko_pc",
        "genes_not_in_ko",
        "genes_not_in_ko_pc",
        "genes_in_cog",
        "genes_in_cog_pc",
        "genes_in_kog",
        "genes_in_kog_pc",
        "genes_in_pfam",
        "genes_in_pfam_pc",
        "genes_in_tigrfam",
        "genes_in_tigrfam_pc",
        "genes_in_genome_prop",
        "genes_in_genome_prop_pc",
        "genes_signalp",
        "genes_signalp_pc",
        "genes_transmembrane",
        "genes_transmembrane_pc",
#        "genes_in_ipr",
#        "genes_in_ipr_pc",

        #"genes_in_img_terms",
        #"genes_in_img_terms_pc",
        #"genes_in_img_pways",
        #"genes_in_img_pways_pc",
        "genes_obsolete",
        "genes_obsolete_pc",
        "genes_revised",
        "genes_revised_pc",
        "pfam_clusters",
        "cog_clusters",
        "kog_clusters",
        "tigrfam_clusters",
        "n_scaffolds",
        "crispr_count",
        "total_gc",
        "gc_percent",
        "total_bases",
        "total_coding_bases",
        "genes_in_eggnog",
        "genes_in_eggnog_pc"

    );
    my @a = @a_full;
    @a = @a_lite if $img_lite;
    push( @a, "genes_in_tigrfam" );
    push( @a, "genes_in_tigrfam_pc" );
    if ($include_img_terms) {
        push( @a, "genes_in_img_terms" );
        push( @a, "genes_in_img_terms_pc" );
        push( @a, "genes_in_img_pways" );
        push( @a, "genes_in_img_pways_pc" );
        push( @a, "genes_in_parts_list" );
        push( @a, "genes_in_parts_list_pc" );
    }
    if ($show_myimg_login) {
        push( @a, "genes_in_myimg" );
        push( @a, "genes_in_myimg_pc" );
    }
    if ($img_internal) {
        push( @a, "genes_in_genome_prop" );
        push( @a, "genes_in_genome_prop_pc" );
	push( @a, "genes_in_img_clusters" );
	push( @a, "genes_in_img_clusters_pc" );
    }
    if ($img_internal || $include_ht_stats > 1) {
        push( @a, "genes_hor_transfer" );
        push( @a, "genes_hor_transfer_pc" );
    }

    # not internal for 2.6 - ken
    push( @a, "fused_genes" );
    push( @a, "fused_genes_pc" );
    push( @a, "fusion_components" );
    push( @a, "fusion_components_pc" );

    # TODO added cassettes columns - ken
    if ( $enable_cassette ) {
        # need to wait for taxon_stats to update column
        # this is only for 2.6
        push( @a, "genes_in_cassettes" );
        push( @a, "genes_in_cassettes_pc" );
        push( @a, "total_cassettes" );
    }

    push( @a, "genes_in_biosynthetic" );
    push( @a, "genes_in_biosynthetic_pc" );
    push( @a, "total_biosynthetic" );

    # metacyc 2.7
    push( @a, "genes_in_metacyc" );
    push( @a, "genes_in_metacyc_pc" );
    push( @a, "genes_not_in_metacyc" );
    push( @a, "genes_not_in_metacyc_pc" );

    push( @a, "genes_in_sp" );
    push( @a, "genes_in_sp_pc" );
    push( @a, "genes_not_in_sp" );
    push( @a, "genes_not_in_sp_pc" );

    # seed
#    push( @a, "genes_in_seed" );
#    push( @a, "genes_in_seed_pc" );
#    push( @a, "genes_not_in_seed" );
#    push( @a, "genes_not_in_seed_pc" );

    $cts->loadColNames( \@a );

    my $x = $cts->colName2Header();
    $x->{taxon_oid}                    = "Taxon Object ID";
    $x->{ncbi_taxon_id}                = "NCBI Taxon ID";
    $x->{taxon_display_name}           = "Genome Name";
    $x->{domain}                       = "D";
    $x->{seq_status}                   = "C";
    $x->{phylum}                       = "Phylum";
    $x->{ir_class}                     = "Class";
    $x->{ir_order}                     = "Order";
    $x->{family}                       = "Family";
    $x->{genus}                        = "Genus";
    $x->{gold_id}                      = "Proposal GOLD ID";
    $x->{total_gene_count}             = "Total gene count";
    $x->{cds_genes}                    = "Number of CDS genes";
    $x->{cds_genes_pc}                 = "CDS genes (percentage)";
    $x->{rna_genes}                    = "Number of RNA genes";
    $x->{rna_genes_pc}                 = "RNA genes (percentage)";
    $x->{rrna_genes}                   = "Number of rRNA genes";
    $x->{rrna5s_genes}                 = "Number of 5S rRNA's";
    $x->{rrna16s_genes}                = "Number of 16S rRNA's";
    $x->{rrna18s_genes}                = "Number of 18S rRNA's";
    $x->{rrna23s_genes}                = "Number of 23S rRNA's";
    $x->{rrna28s_genes}                = "Number of 28S rRNA's";
    $x->{trna_genes}                   = "Number of tRNA genes";
    $x->{other_rna_genes}              = "Number of Other (unclassified) RNA genes";
    $x->{genes_hor_transfer}           = "Number of horizontally transferred genes";
    $x->{genes_hor_transfer_pc}        = "Number of horizontally transferred genes (percentage)";
    $x->{pseudo_genes}                 = "Number of Pseudo Genes";
    $x->{pseudo_genes_pc}              = "Pseudo Genes (percentage)";
    $x->{uncharacterized_genes}        = "Number of Uncharacerized Genes";
    $x->{uncharacterized_genes_pc}     = "Uncharacterized Genes (percentage)";
    $x->{dubious_genes}                = "Number of Dubious ORFs";
    $x->{dubious_genes_pc}             = "Dubious ORFs (percentage)";
    $x->{genes_w_func_pred}            = "Number of Genes with Predicted Protein Product";
    $x->{genes_w_func_pred_pc}         = "Genes with Predicted Protein Product (percentage)";
    $x->{genes_wo_func_pred_sim}       = "Number of genes without function prediction with similarity";
    $x->{genes_wo_func_pred_sim_pc}    = "Genes without Predicted Protein Product with similarity (percentage)";
    $x->{genes_wo_func_pred_no_sim}    = "Number of genes without funcction prediction without similarity";
    $x->{genes_wo_func_pred_no_sim_pc} = "Genes without function prediction without similarity (percentage)";
    $x->{genes_in_enzymes}             = "Number of genes assigned to enzymes";
    $x->{genes_in_enzymes_pc}          = "Genes assigned to enzymes (percentage)";
    $x->{genes_in_tc}                  = "Number of genes assigned to Transporter Classification";
    $x->{genes_in_tc_pc}               = "Genes assigned to Transporter Classification (percentage)";
    $x->{genes_in_kegg}                = "Number of genes in KEGG";
    $x->{genes_in_kegg_pc}             = "Genes in KEGG (percentage)";
    $x->{genes_not_in_kegg}            = "Number of genes not in KEGG";
    $x->{genes_not_in_kegg_pc}         = "Genes not in KEGG (percentage)";
    $x->{genes_in_ko}                  = "Number of genes in KEGG Orthology (KO)";
    $x->{genes_in_ko_pc}               = "Genes in KEGG Orthology (KO) (percentage)";
    $x->{genes_not_in_ko}              = "Number of genes not in KEGG Orthology (KO)";
    $x->{genes_not_in_ko_pc}           = "Genes not in KEGG Orthology (KO) (percentage)";
    $x->{genes_in_orthologs}           = "Number of genes in orthologs";
    $x->{genes_in_orthologs_pc}        = "Genes in orthologs (percentage)";
    $x->{genes_in_img_clusters}        = "Number of genes in IMG clusters";
    $x->{genes_in_img_clusters_pc}     = "Genes in IMG Clusters (percentage)";
    $x->{genes_in_paralogs}            = "Number of genes in paralogs";
    $x->{genes_in_paralogs_pc}         = "Genes in paralogs (percentage)";
    $x->{fused_genes}                  = "Number of fused genes";
    $x->{fused_genes_pc}               = "Fused genes (percentage)";
    $x->{fusion_components}            = "Number of genes involved as fusion components";
    $x->{fusion_components_pc}         = "Genes involved as fusion components (percentage)";

    # TODO cassettes - ken
    $x->{genes_in_cassettes}    = "Number of genes in chromosomal cassette";
    $x->{genes_in_cassettes_pc} = "Genes in chromosomal cassette (percentage)";
    $x->{total_cassettes}       = "Number of chromosomal cassettes";

    $x->{genes_in_biosynthetic}    = "Number of genes in biosynthetic cluster";
    $x->{genes_in_biosynthetic_pc} = "Genes in biosynthetic (percentage)";
    $x->{total_biosynthetic}       = "Number of biosynthetic cluster";

    # metacyc 2.7
    $x->{genes_in_metacyc}        = "Number of genes in MetaCyc";
    $x->{genes_in_metacyc_pc}     = "Genes in MetaCyc (percentage)";
    $x->{genes_not_in_metacyc}    = "Number of genes not in MetaCyc";
    $x->{genes_not_in_metacyc_pc} = "Genes not in MetaCyc (percentage)";

    $x->{genes_in_sp}        = "Number of genes in SwissProt Protein Product";
    $x->{genes_in_sp_pc}     = "Genes in SwissProt Protein Product (percentage)";
    $x->{genes_not_in_sp}    = "Number of genes not in SwissProt Protein Product";
    $x->{genes_not_in_sp_pc} = "Genes not in SwissProt Protein Product (percentage)";

#    $x->{genes_in_seed}        = "Number of genes in SEED";
#    $x->{genes_in_seed_pc}     = "Genes in SEED (percentage)";
#    $x->{genes_not_in_seed}    = "Number of genes not in SEED";
#    $x->{genes_not_in_seed_pc} = "Genes not in SEED (percentage)";

    $x->{genes_in_cog}            = "Number of genes in COG";
    $x->{genes_in_cog_pc}         = "Genes in COG (percentage)";
    $x->{genes_in_kog}            = "Number of genes in KOG";
    $x->{genes_in_kog_pc}         = "Genes in KOG (percentage)";
    $x->{genes_in_pfam}           = "Number of genes in Pfam";
    $x->{genes_in_pfam_pc}        = "Genes in Pfam (percentage)";
    $x->{genes_in_tigrfam}        = "Number of genes in TIGRfam";
    $x->{genes_in_tigrfam_pc}     = "Genes in TIGRfam (percentage)";
    $x->{genes_in_genome_prop}    = "Number of genes in Genome Properties";
    $x->{genes_in_genome_prop_pc} = "Genes in Genome Properties (percentage)";
    $x->{genes_signalp}           = "Number of genes coding signal peptides";
    $x->{genes_signalp_pc}        = "Number of genes coding signal peptides (percentage)";
    $x->{genes_transmembrane}     = "Number of genes coding transmembrane proteins";
    $x->{genes_transmembrane_pc}  = "Number of genes coding transmembrane proteins (percentage)";
if($enable_interpro) {
    $x->{genes_in_ipr}            = "Number of genes in InterPro";
    $x->{genes_in_ipr_pc}         = "Genes in InterPro (percentage)";
}
    $x->{pfam_clusters}           = "Number of Pfam clusters";
    $x->{cog_clusters}            = "Number of COG clusters";
    $x->{kog_clusters}            = "Number of KOG clusters";
    $x->{tigrfam_clusters}        = "Number of TIGRfam clusters";
    $x->{paralog_groups}          = "Number of paralog groups";
    $x->{ortholog_groups}         = "Number of ortholog groups";
    $x->{n_scaffolds}             = "Number of scaffolds";
    $x->{crispr_count}            = "Number of CRISPR's";
    $x->{total_gc}                = "GC Count";
    $x->{gc_percent}              = "GC (percentage)";
    $x->{total_bases}             = "Total number of bases";
    $x->{total_coding_bases}      = "Total number of coding bases";
    $x->{genes_in_img_terms}      = "Number of genes with IMG Terms";
    $x->{genes_in_img_terms_pc}   = "Genes with IMG Terms (percentage)";
    $x->{genes_in_img_pways}      = "Number of genes in IMG pathwawys";
    $x->{genes_in_img_pways_pc}   = "Genes in IMG Pathways (percentage)";
    $x->{genes_in_parts_list}     = "Number of genes in IMG Parts List";
    $x->{genes_in_parts_list_pc}  = "Genes in IMG Parts List (percentage)";
    $x->{genes_in_myimg}          = "Number of genes with IMG annotations";
    $x->{genes_in_myimg_pc}       = "Genes with IMG annotations (percentage)";
    $x->{genes_obsolete}          = "Obsolete genes";
    $x->{genes_obsolete_pc}       = "Obsolete genes (percentage)";
    $x->{genes_revised}           = "Revised genes";
    $x->{genes_revised_pc}        = "Revised genes (percentage)";
    $x->{genes_in_eggnog}         = "EggNOG genes";
    $x->{genes_in_eggnog_pc}      = "EggNOG genes (percentage)";

    my $x = $cts->colNamesAutoSelected();
    $x->{total_gene_count} = 1;
    $x->{gc_percent}       = 1;
    $x->{total_bases}      = 1;

    my $x = $cts->colNameSortQual();

    if ( $mode eq "export" ) {
        $cts->printCompStatExport();
    }

    if ( $mode eq "" || $mode eq "display" ) {
        $cts->{ blockDatatableCss } = $blockDatatableCss;
        $cts->printOrgTable();

        print WebUtil::getHtmlBookmark( "genexport",
                                        "<h2>Export Genome Table</h2>" );
        $cts->printExport();
        print WebUtil::getHtmlBookmark( "genconfig",
					"<h2>Configuration</h2>" );

        print "\n";

        $cts->{ blockDatatableCss } = $blockDatatableCss;
        $cts->printConfigTable();

        print end_form();
        printStatusLine( $cts->{ genomeCount } . " genome(s) loaded.", 2 );
    }

    #$dbh->disconnect();

}

sub validNumOfSelection {
    my ( $dbh, $taxon_oids_ref ) = @_;

    my $nSelectedTaxons = scalar(@$taxon_oids_ref);
    my $isDbNumOfSelectionValid = 0;
    my $isMetaNumOfSelectionValid = 0;
    my $metaNumOfSelection = 0;

    if ( $nSelectedTaxons > 0 ) {
        my ( $dbTaxons_ref, $metaTaxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @$taxon_oids_ref );
        if ( $nSelectedTaxons > 0 && scalar(@$dbTaxons_ref) <= $maxDbGenomeSelectionAllowed ) {
            $isDbNumOfSelectionValid = 1;
        }
        if ( $nSelectedTaxons > 0 && scalar(@$metaTaxons_ref) <= $maxMetagenomeSelectionAllowed ) {
            $isMetaNumOfSelectionValid = 1;
        }
        $metaNumOfSelection = scalar(@$metaTaxons_ref);
    }
    return ( $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid, $metaNumOfSelection );
}

sub getMetaNote1 {
    my $note = "Statistics for metagenomes are not supported.";
    return $note;
}

sub getMetaNote2 {
    my $note = "Over $maxMetagenomeSelectionAllowed metagenomes in Genome Cart. Statistics for metagenomes are not supported.";
    return $note;
}

sub printStatisticsDisplayTitle {
    my ($dbh, $pangenome_oid, $func_type, $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid) = @_;

    my $title = '';
    if ( $func_type =~ /cog/i ) {
        $title = 'COG';
    }
    elsif ( $func_type =~ /kog/i ) {
        $title = 'KOG';
    }
    elsif ( $func_type =~ /kegg/i ) {
        $title = 'KEGG';
    }
    elsif ( $func_type =~ /pfam/i ) {
        $title = 'Pfam';
    }
    elsif ( $func_type =~ /tigr/i ) {
        $title = 'TIGRfam';
    }

    if ( $pangenome_oid ne "" ) {
        my ($taxon_name, $is_pangenome) =
            QueryUtil::fetchSingleTaxonNameAndPangenome($dbh, $pangenome_oid);
        print "<h1>Statistics For Pangenome by $title Categories</h1>\n";
        print "<p style='width: 650px;'>";
        my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$pangenome_oid";
        print alink( $url, $taxon_name );
        print "</p>";
    } else {
        if ( $nSelectedTaxons <= 0 ) {
            my $header = "Statistics For All Genomes by $title Categories";
            if ( $include_metagenomes ) {
                WebUtil::printHeaderWithInfo($header, '', '', '', 1);
                my $note = getMetaNote1();
                print "<p style='width: 950px;'>$note</p>\n";
            }
            else {
                print "<h1>$header</h1>\n";
            }
        } else {
            my $header = "Statistics for User-selected Genomes by $title Categories";
            if ( $include_metagenomes ) {
                if ( $func_type =~ /kog/i ) {
                    WebUtil::printHeaderWithInfo($header, '', '', '', 1);
                    my $note = getMetaNote1();
                    print "<p style='width: 950px;'>$note</p>\n";
                }
                elsif ( !$isMetaNumOfSelectionValid ) {
                    WebUtil::printHeaderWithInfo($header, '', '', '', 1);
                    my $note = getMetaNote2();
                    print "<p style='width: 950px;'>$note</p>\n";
                }
                else {
                    print "<h1>$header</h1>\n";
                }
            }
            else {
                print "<h1>$header</h1>\n";
            }
        }
    }

}

# kegg cat from ko
sub printTaxonBreakdownKeggStats {
    my ($mode, $pangenome_oid) = @_;

    my $dbh = dbLogin();

    my $taxon_oids_ref = GenomeCart::getAllGenomeOids();
    my ( $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid, $metaNumOfSelection )
        = validNumOfSelection( $dbh, $taxon_oids_ref );

    if ( $mode eq "display" || $mode eq "" ) {
        printStatusLine( "Loading ...", 1 );
        printMainForm();

        printStatisticsDisplayTitle($dbh, $pangenome_oid, 'kegg',
            $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);

        use TabHTML;
        TabHTML::printTabAPILinks("keggcatTab");
        my @tabIndex = ();
        my @tabNames = ();

        my $idx = 1;
        if ( $pangenome_oid ne "" || ($isDbNumOfSelectionValid && $isMetaNumOfSelectionValid)) {
            push @tabIndex, "keggcattab".$idx;
            push @tabNames, "Statistics for Genomes by specific KEGG category";
            $idx++;
        }

        if ( $pangenome_oid ne "" ) {
            push @tabIndex, "keggcattab".$idx;
            push @tabNames, "Pangenes by KEGG categories";
            $idx++;
        } else {
            push @tabIndex, "keggcattab".$idx;
            push @tabNames, "Statistics for Genomes by KEGG categories";
            $idx++;
        }

        TabHTML::printTabDiv("keggcatTab", \@tabIndex, \@tabNames);
    }

    my ($cat2geneCnt_href, $results_href, $id2cat_href, $taxon_domain_href)
        = getCategoryGeneCount($dbh, $pangenome_oid, 'kegg',
        $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);

    my $results_total_gene_count_href
        = getTaxonTotalFuncGeneCount( $dbh, $taxon_domain_href, 'kegg' );

    # colums to print
    # note columns ending in _pc are not in the DB
    my @columns = param("outputCol");
    if ( $#columns < 0 ) {
        # add default columns
        push( @columns, "Total KEGG Genes" );
        push( @columns, "Amino acid metabolism" );
        push( @columns, "Amino acid metabolism (percentage)" );
        push( @columns, "Carbohydrate metabolism" );
        push( @columns, "Carbohydrate metabolism (percentage)" );
    }

    if ( $mode eq "export" ) {
        printDataTableExport( $results_href, $results_total_gene_count_href,
                              $taxon_domain_href, \@columns );
    } else {
    	GenomeCart::insertToGtt($dbh);

        my $sql = "select count(id) from gtt_taxon_oid";
        my $cur = execSql( $dbh, $sql, $verbose);
        my $sessionCount = $cur->fetchrow();
        $cur->finish();

        my $max = 80;
        if ( $pangenome_oid ne "" || ($isDbNumOfSelectionValid && $isMetaNumOfSelectionValid) ) {
            print "<div id='keggcattab1'>";
            print "<h2>Statistics for Genomes by specific KEGG Category</h2>";
            printAllKeggTable($dbh, $pangenome_oid, $cat2geneCnt_href);
            print "</div>";
        }

        # print summary table
        if ($pangenome_oid ne "") {
            print "<div id='keggcattab2'>";
            print "<h2>Pangenes by KEGG Categories</h2>";
            printHint( "Columns can be added or removed "
                     . "using the configuration table below." );
        } else {
            print "<div id='keggcattab2'>";
            print "<h2>Statistics for Genomes by KEGG Categories</h2>";

            printHintHeader();
	    }
        print "<p>\n";
        print domainLetterNote() . "<br/>\n";
        print completionLetterNote() . "<br/>\n";
        print "</p>\n";

        printDataTable( $results_href, $results_total_gene_count_href,
                        $taxon_domain_href, \@columns, 'kegg'  );

        # export to excel button
        print "<h2>Export Genome Table</h2>";
        my $name = "_section_CompareGenomes_excel_exportCompStats";

        print "<input type='submit' class='lgdefbutton' name='_section_CompareGenomes_excel_exportCompStats' value='Export Tab Delimited to Excel' />";
#        print main::submit(
#            -name  => $name,
#            -value => "Export Tab Delimited To Excel",
#            -class => 'lgdefbutton'
#        );

        # print column selection table
        print "<h2>Configuration</h2>";
        my @category_list = getKeggCategoryList(  $dbh, $id2cat_href );
        printConfigTable( \@category_list, \@columns, $pangenome_oid, 'kegg' );

        print "</div>";
        TabHTML::printTabDivEnd();
    }

    #$dbh->disconnect();
    if ( $mode eq "" || $mode eq "display" ) {
        printStatusLine( "Loaded.", 2 );
        print end_form();
    }
}

sub getKeggCategoryList {
    my ( $dbh, $id2cat_href ) = @_;

    my @category_list;
    # add some initial categoies to be selected
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total KEGG Genes" );

    my %done_cat;
    my @ids = keys %$id2cat_href;
    if ( scalar(@ids) > 0 ) {
        for my $id (@ids) {
            my $cats_ref = $id2cat_href->{$id};
            for my $cat (@$cats_ref) {
                $done_cat{$cat} = 1;
            }
        }
    }
    else {
        # get all the categories
        my $sql = qq{
            select distinct $nvl(pw.category, 'Unclassified')
            from kegg_pathway pw
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($cat) = $cur->fetchrow();
            last if !$cat;
            $done_cat{$cat} = 1;
        }
        $cur->finish();
    }

    my @sortedCat = sort(keys %done_cat);
    for my $cat (@sortedCat) {
        push( @category_list, $cat );
        push( @category_list, "$cat (percentage)" );
    }
    #print "getKeggCategoryList() @category_list<br/>\n";

    return @category_list;
}

sub getCogCategoryList {
    my ( $dbh ) = @_;

    my @category_list;
    # add some initial categoies to be selected
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total COG Genes" );

    # get all the categories
    my $sql = qq{
        select distinct $nvl(cf.definition, 'Unclassified')
        from cog_function cf
        order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($cat) = $cur->fetchrow();
        last if !$cat;

        push( @category_list, $cat );
        push( @category_list, "$cat (percentage)" );

    }
    $cur->finish();
    #print "getCogCategoryList() @category_list<br/>\n";

    return @category_list;
}


sub getTaxonTotalFuncGeneCount {
    my ( $dbh, $taxon_domain_href, $func_type ) = @_;

    # total kegg gene count taxon oid => total kegg gene count
    my @goodTaxons = keys %$taxon_domain_href;
    my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @goodTaxons );
    my $taxonClause = qq{
        and ts.taxon_oid in ($taxon_str)
    };

    my $sql;
    if ( $func_type =~ /cog/i ) {
        $sql = qq{
            select ts.taxon_oid, ts.genes_in_cog
            from taxon_stats ts
            where 1 = 1
            $taxonClause
        };
    }
    elsif ( $func_type =~ /kegg/i ) {
        $sql = qq{
            select ts.taxon_oid, ts.genes_in_kegg
            from taxon_stats ts
            where 1 = 1
            $taxonClause
        };
    }
    #print "getTaxonTotalFuncGeneCount() sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );

    my %results_total_gene_count;
    for ( ; ; ) {
        my ( $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;
        $results_total_gene_count{$taxon_oid} = $cnt;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) if ( $taxon_str =~ /gtt_num_id/i );
    #print Dumper(\%results_total_gene_count);
    #print "<br/>\n";

    return (\%results_total_gene_count);
}

sub printKeggDataTableExport {
    my ( $results_href,      $results_total_gene_count_href,
         $taxon_domain_href, $selected_cols_aref
      )
      = @_;

    print "D\tC\tGenome Name\t";
    foreach my $colname (@$selected_cols_aref) {
        print "$colname\t";
    }
    print "\n";

    foreach my $taxon_oid ( keys %$taxon_domain_href ) {
        my $line = $taxon_domain_href->{$taxon_oid};
        my ( $taxon_display_name, $seq_status, $domain, $phylum, $ir_class,
             $ir_order, $family, $genus )
          = split( /\t/, $line );

        my $r;
        $r .= $domain . "\t";
        $r .= $seq_status . "\t";
        $r .= $taxon_display_name . "\t";

        # print user selected columns
        foreach my $cat (@$selected_cols_aref) {
            if ( $cat eq "Phylum" ) {
                $r .= $phylum . "\t";
            } elsif ( $cat eq "Class" ) {
                $r .= $ir_class . "\t";
            } elsif ( $cat eq "Order" ) {
                $r .= $ir_order . "\t";
            } elsif ( $cat eq "Family" ) {
                $r .= $family . "\t";
            } elsif ( $cat eq "Genus" ) {
                $r .= $genus . "\t";
            } elsif ( $cat eq "Total KEGG Genes" ) {
                my $cnt = $results_total_gene_count_href->{$taxon_oid};
                $r .= $cnt . "\t";
            } else {
                my $cat_href = $results_href->{$taxon_oid};
                if ( $cat_href eq "" ) {
                    # genome has no data for this category
                    $r .= 0 . "\t";
                } else {
                    # percentage  column
                    if ( $cat =~ / \(percentage\)$/ ) {
                        my $tmp = $cat;
                        $tmp =~ s/ \(percentage\)//;
                        my $cnt = $cat_href->{$tmp};
                        my $t   = $results_total_gene_count_href->{$taxon_oid};
                        if ( $t == 0 ) {
                            $r .= 0 . "\t";
                        } else {
                            $cnt = $cnt * 100 / $t;
                            my $pc = sprintf( "%.2f%%", $cnt );
                            $r .= $cnt . "\t";
                        }
                    } else {
                        my $cnt = $cat_href->{$cat};
                        $r .= $cnt . "\t";
                    }
                }
            }
        }
        print "$r\n";
    }
}

sub printDataTableExport {
    my ( $results_href,      $results_total_gene_count_href,
         $taxon_domain_href, $selected_cols_aref
      )
      = @_;

    #print "printDataTableExport\n";

    print "D\tC\tGenome Name\t";
    foreach my $colname (@$selected_cols_aref) {
        print "$colname\t";
    }
    print "\n";

    foreach my $taxon_oid ( keys %$taxon_domain_href ) {
        my $line = $taxon_domain_href->{$taxon_oid};
        my ( $taxon_display_name, $seq_status, $domain, $phylum, $ir_class,
             $ir_order, $family, $genus )
          = split( /\t/, $line );

        my $r;
        $r .= $domain . "\t";
        $r .= $seq_status . "\t";
        $r .= $taxon_display_name . "\t";

        # print user selected columns
        foreach my $cat (@$selected_cols_aref) {
            if ( $cat eq "Phylum" ) {
                $r .= $phylum . "\t";
            } elsif ( $cat eq "Class" ) {
                $r .= $ir_class . "\t";
            } elsif ( $cat eq "Order" ) {
                $r .= $ir_order . "\t";
            } elsif ( $cat eq "Family" ) {
                $r .= $family . "\t";
            } elsif ( $cat eq "Genus" ) {
                $r .= $genus . "\t";
            } elsif ( $cat eq "Total COG Genes"  || $cat eq "Total KEGG Genes" ) {
                my $cnt = $results_total_gene_count_href->{$taxon_oid};
                $r .= $cnt . "\t";
            } else {
                my $cat_href = $results_href->{$taxon_oid};
                if ( $cat_href eq "" ) {
                    # genome has no data for this category
                    $r .= 0 . "\t";
                } else {
                    # percentage  column
                    if ( $cat =~ / \(percentage\)$/ ) {
                        my $tmp = $cat;
                        $tmp =~ s/ \(percentage\)//;
                        my $cnt = $cat_href->{$tmp};
                        my $t   = $results_total_gene_count_href->{$taxon_oid};
                        if ( $t == 0 ) {
                            $r .= 0 . "\t";
                        } else {
                            $cnt = $cnt * 100 / $t;
                            my $pc = sprintf( "%.2f%%", $cnt );
                            $r .= $cnt . "\t";
                        }
                    } else {
                        my $cnt = $cat_href->{$cat};
                        $r .= $cnt . "\t";
                    }
                }
            }
        }
        print "$r\n";
    }
}


# hash of hash taxon oid => cat => gene count
# total kegg gene count taxon oid => total kegg gene count
# taxon oid => line of domain info
# array of selected columnes to disaply
sub printKeggDataTable {
    my ( $results_href,      $results_total_gene_count_href,
         $taxon_domain_href, $selected_cols_aref
      )
      = @_;

    my $it = new InnerTable( 1, "kegg$$", "kegg", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Domain", "asc", "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    foreach my $colname (@$selected_cols_aref) {
        if (    $colname eq "Phylum"
             || $colname eq "Class"
             || $colname eq "Order"
             || $colname eq "Family"
             || $colname eq "Genus" ) {
            $it->addColSpec( "$colname", "asc", "left" );
        } else {
            $it->addColSpec( "$colname", "desc", "right", "", "", "wrap" );
        }
    }

    my $count_rows = 0;
    foreach my $taxon_oid ( keys %$taxon_domain_href ) {
        my $line = $taxon_domain_href->{$taxon_oid};
        my ( $taxon_display_name, $seq_status, $domain, $phylum, $ir_class,
             $ir_order, $family, $genus )
          = split( /\t/, $line );
        my $r = $sd . "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />\t";
        $r .= $domain . $sd . substr( $domain,         0, 1 ) . "\t";
        $r .= $seq_status . $sd . substr( $seq_status, 0, 1 ) . "\t";
        my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
        $url = alink( $url, $taxon_display_name );
        $r .= $taxon_display_name . $sd . $url . "\t";

        # print user selected columns
        foreach my $cat (@$selected_cols_aref) {
            if ( $cat eq "Phylum" ) {
                $r .= $phylum . $sd . $phylum . "\t";
            } elsif ( $cat eq "Class" ) {
                $r .= $ir_class . $sd . $ir_class . "\t";
            } elsif ( $cat eq "Order" ) {
                $r .= $ir_order . $sd . $ir_order . "\t";
            } elsif ( $cat eq "Family" ) {
                $r .= $family . $sd . $family . "\t";
            } elsif ( $cat eq "Genus" ) {
                $r .= $genus . $sd . $genus . "\t";
            } elsif ( $cat eq "Total KEGG Genes" ) {
                my $cnt = $results_total_gene_count_href->{$taxon_oid};
                $r .= $cnt . $sd . $cnt . "\t";
            } else {
                my $cat_href = $results_href->{$taxon_oid};

                if ( $cat_href eq "" ) {
                    # genome has no data for this category
                    $r .= 0 . $sd . 0 . "\t";
                } else {
                    # percentage column
                    if ( $cat =~ /\(percentage\)$/ ) {
                        my $tmp = $cat;
                        $tmp =~ s/ \(percentage\)//;
                        #print "printKeggDataTable() tmp: $tmp<br/>\n";
                        my $cnt = $cat_href->{$tmp};
                        my $t   = $results_total_gene_count_href->{$taxon_oid};
                        if ( $t == 0 ) {
                            $r .= 0 . $sd . 0 . "\t";
                        } else {
                            $cnt = $cnt * 100 / $t;
                            my $pc = sprintf( "%.2f%%", $cnt );
                            $r .= $cnt . $sd . $pc . "\t";
                        }
                    } else {
                        my $cnt = $cat_href->{$cat};
                        $r .= $cnt . $sd . $cnt . "\t";
                    }
                }
            }
        }
        $count_rows++;
        $it->addRow($r);
        #print "printKeggDataTable() r: $r<br/>\n";
    }
    WebUtil::printGenomeCartFooter() if $count_rows > 10;
    $it->printOuterTable(1);
    WebUtil::printGenomeCartFooter();
}

# hash of hash taxon oid => cat => gene count
# taxon oid => line of domain info
# array of selected columnes to disaply
sub printDataTable {
    my ( $results_href, $results_total_gene_count_href, $taxon_domain_href,
        $selected_cols_aref, $func_type )
      = @_;

    my $it;
    if ( $func_type =~ /cog/i ) {
        $it = new InnerTable( 1, "cog$$", "cog", 2 );
    }
    elsif ( $func_type =~ /kegg/i ) {
        $it = new InnerTable( 1, "kegg$$", "kegg", 2 );
    }
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Domain", "asc", "center", "",
             "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "",
             "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    foreach my $colname (@$selected_cols_aref) {
        if (    $colname eq "Phylum"
             || $colname eq "Class"
             || $colname eq "Order"
             || $colname eq "Family"
             || $colname eq "Genus" ) {
            $it->addColSpec( "$colname", "asc", "left" );
        } else {
            $it->addColSpec( "$colname", "desc", "right", "", "", "wrap" );
        }
    }

    my $count_rows = 0;
    foreach my $taxon_oid ( keys %$taxon_domain_href ) {
        my $line = $taxon_domain_href->{$taxon_oid};
        my ( $taxon_display_name, $seq_status, $domain, $phylum, $ir_class,
             $ir_order, $family, $genus )
          = split( /\t/, $line );
        my $r = $sd . "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />\t";
        $r .= $domain . $sd . substr( $domain,         0, 1 ) . "\t";
        $r .= $seq_status . $sd . substr( $seq_status, 0, 1 ) . "\t";
        my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
        $url = alink( $url, $taxon_display_name );
        $r .= $taxon_display_name . $sd . $url . "\t";

        # print user selected columns
        foreach my $cat (@$selected_cols_aref) {
            if ( $cat eq "Phylum" ) {
                $r .= $phylum . $sd . $phylum . "\t";
            } elsif ( $cat eq "Class" ) {
                $r .= $ir_class . $sd . $ir_class . "\t";
            } elsif ( $cat eq "Order" ) {
                $r .= $ir_order . $sd . $ir_order . "\t";
            } elsif ( $cat eq "Family" ) {
                $r .= $family . $sd . $family . "\t";
            } elsif ( $cat eq "Genus" ) {
                $r .= $genus . $sd . $genus . "\t";
            } elsif ( $cat eq "Total COG Genes" || $cat eq "Total KEGG Genes" ) {
                my $cnt = $results_total_gene_count_href->{$taxon_oid};
                $r .= $cnt . $sd . $cnt . "\t";
            } else {
                my $cat_href = $results_href->{$taxon_oid};

                if ( $cat_href eq "" ) {
                    # genome has no data for this category
                    $r .= 0 . $sd . 0 . "\t";
                } else {
                    # percentage column
                    if ( $cat =~ /\(percentage\)$/ ) {
                        my $tmp = $cat;
                        $tmp =~ s/ \(percentage\)//;
                        #print "printDataTable() tmp: $tmp<br/>\n";
                        my $cnt = $cat_href->{$tmp};
                        my $t   = $results_total_gene_count_href->{$taxon_oid};
                        if ( $t == 0 ) {
                            $r .= 0 . $sd . 0 . "\t";
                        } else {
                            $cnt = $cnt * 100 / $t;
                            my $pc = sprintf( "%.2f%%", $cnt );
                            $r .= $cnt . $sd . $pc . "\t";
                        }
                    } else {
                        my $cnt = $cat_href->{$cat};
                        $r .= $cnt . $sd . $cnt . "\t";
                    }
                }
            }
        }
        $count_rows++;
        $it->addRow($r);
        #print "printDataTable() r: $r<br/>\n";
    }
    WebUtil::printGenomeCartFooter() if $count_rows > 10;
    $it->printOuterTable(1);
    WebUtil::printGenomeCartFooter();
}

# checks if column is selected for kegg stats
sub isColumnSelected {
    my ( $cat, $columns_aref ) = @_;
    foreach my $name (@$columns_aref) {
        if ( lc($cat) eq lc($name) ) {
            return "checked";
        }
    }
    return "";
}

# select columns for kegg stats table
sub printKeggConfigTable {
    my ( $category_list_aref, $columns_aref, $pangenome_oid ) = @_;

    my $checked = "";
    my $it = new InnerTable( 1, "keggconfig$$", "keggconfig", 2 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->hideAll();

    $it->addColSpec( "Select" );
    $it->addColSpec( "Column Name", "", "left" );

    foreach my $cat (@$category_list_aref) {
        $checked = isColumnSelected( $cat, $columns_aref );
        my $chkClause =
	    ( $checked eq "checked" )
	    ? "checked = '$checked'" : "";

        my $row;
        my $row = $sd."<input type='checkbox' "
                . "name='outputCol' value='$cat' $chkClause/>\t";
        $row .= $cat."\t";
        $it->addRow($row);
    }
    $it->printOuterTable("nopage");

    print hiddenVar( "statTableName", "dt_kegg_stats" );
    print hiddenVar( "pangenome_oid" , $pangenome_oid );

    my $name = "_section_CompareGenomes_setTaxonBreakdownStatCols";

	print  "<input type='submit' class='meddefbutton' id='dispGenomesButton' name='_section_CompareGenomes_setTaxonBreakdownStatCols' value='Display Genomes Again' />&nbsp;";
#    print main::submit(
#        -id    => "dispGenomesButton",
#        -name  => $name,
#        -value => "Display Genomes Again",
#        -class => "meddefbutton"
#    );
    # added id attribute to all buttons to distinguish from main table
    # Can not be replaced by WebUtil::printButtonFooter();
    print "<input id='selAll' type=button name='selectAll' "
	. "value='Select All' onClick='selectAllOutputCol(1)' "
	. "class='smbutton' />\n";
    print "<input id='selCnts' type=button name='selectAll' "
	. "value='Select Counts Only' "
	. "onClick='selectCountOutputCol(1)' class='smbutton' />\n";
    print "<input id='clrAll' type=button name='clearAll' value='Clear All' "
	. "onClick='selectAllOutputCol(0)' class='smbutton' />\n";
}

# select columns for cog stats table
sub printConfigTable {
    my ( $category_list_aref, $columns_aref, $pangenome_oid, $func_type ) = @_;

    my $checked = "";
    my $it;
    if ( $func_type =~ /cog/i ) {
        $it = new InnerTable( 1, "cogconfig$$", "cogconfig", 2 );
    }
    elsif ( $func_type =~ /kegg/i ) {
        $it = new InnerTable( 1, "keggconfig$$", "keggconfig", 2 );
    }
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->hideAll();

    $it->addColSpec( "Select" );
    $it->addColSpec( "Column Name", "", "left" );

    foreach my $cat (@$category_list_aref) {
        $checked = isColumnSelected( $cat, $columns_aref );
        my $chkClause =
        ( $checked eq "checked" )
        ? "checked = '$checked'" : "";

        my $row;
        my $row = $sd."<input type='checkbox' "
                . "name='outputCol' value='$cat' $chkClause/>\t";
        $row .= $cat."\t";
        $it->addRow($row);
    }
    $it->printOuterTable("nopage");

    if ( $func_type =~ /cog/i ) {
        print hiddenVar( "statTableName", "dt_cog_stats" );
    }
    elsif ( $func_type =~ /kegg/i ) {
        print hiddenVar( "statTableName", "dt_kegg_stats" );
    }
    print hiddenVar( "pangenome_oid" , $pangenome_oid );

#    my $name = "_section_CompareGenomes_setTaxonBreakdownStatCols";
#    print main::submit(
#        -id    => "dispGenomesButton",
#        -name  => $name,
#        -value => "Display Genomes Again",
#        -class => "meddefbutton"
#    );
	print  "<input type='submit' class='meddefbutton' id='dispGenomesButton' "
	. "name='_section_CompareGenomes_setTaxonBreakdownStatCols' value='Display Genomes Again' />\n";
    # added id attribute to all buttons to distinguish from main table
    # Can not be replaced by WebUtil::printButtonFooter();
    print "<input id='selAll' type=button name='selectAll' "
    . "value='Select All' onClick='selectAllOutputCol(1)' "
    . "class='smbutton' />\n";
    print "<input id='selCnts' type=button name='selectAll' "
    . "value='Select Counts Only' "
    . "onClick='selectCountOutputCol(1)' class='smbutton' />\n";
    print "<input id='clrAll' type=button name='clearAll' value='Clear All' "
    . "onClick='selectAllOutputCol(0)' class='smbutton' />\n";
}


############################################################################
# printAllKeggTable - Prints KEGG categories as links for selected genomes
############################################################################
sub printAllKeggTable {
    my ($dbh, $pangenome_oid, $cat2geneCnt_href) = @_;

    my $pangenome_url_frag = "";
    if ($pangenome_oid ne "") {
        $pangenome_url_frag = "&pangenome_oid=$pangenome_oid";
    }
    my $url2 = "xml.cgi?section=BarChartImage&page=compareKeggStats";
    $url2 .= $pangenome_url_frag;

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);

    #$chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME("kegg");
    my @chartseries;
    my @chartcategories;
    my @chartdata;
    #################################

    my $total = 0;
    my $unclassified_count = 0;
    my @sortedCat = sort(keys %$cat2geneCnt_href);
    for my $cat ( @sortedCat ) {
        my $gene_count = $cat2geneCnt_href->{$cat};
        $total = $total + $gene_count;

        if ( $cat eq "Unclassified" ) {
            $unclassified_count = $gene_count;
            next;
        }

        push @chartcategories, "$cat";
        push @chartdata, $gene_count;
    }

    #print "printAllKeggTable() chartcategories: @chartcategories<br/>\n";
    #print "printAllKeggTable() chartdata: @chartdata<br/>\n";
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->IMAGEMAP_ONCLICK('showImage');
    $chart->IMAGEMAP_HREF_ONCLICK('specificKeggStats');
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<script src='$base_url/chart.js'></script>\n";

    print qq{
        <link rel="stylesheet" type="text/css"
          href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript"
          src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript"
          src="$YUI/build/container/container-min.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js"></script>
        <script src="$YUI/build/event/event-min.js"></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
    };

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    my $it = new InnerTable(1, "allkeggcat$$", "allkeggcat", 1);
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "<span id='anchor'>KEGG Categories</span>",
		     "", "left", "", "", "wrap" );
    $it->addColSpec( "Gene Count", "", "right" );
    $it->addColSpec( "Percent", "", "right" );

    my $idx = 0;
    foreach my $category1 (@chartcategories) {
        last if !$category1;

        my $catUrl = massageToUrl($category1);
        my $url    = "xml.cgi?section=BarChartImage&page=compareKeggStats";
        $url .= $pangenome_url_frag;
        $url .= "&kegg=$catUrl";

        my $percent = ( ( $chartdata[$idx] ) / $total ) * 100;
        my $row;
        if ( $st == 0 ) {
	        $row .= escHtml($category1).$sd;
            $row .= "<a href='#specificKeggStats' "
                 . "onclick=javascript:showImage('$url')>";
            $row .= "<img src='$tmp_url/" . $chart->FILE_PREFIX
		         . "-color-" . $idx . ".png' border=0>";
            $row .= "</a>";
            $row .= "&nbsp;&nbsp;";
        }

        $row .= escHtml($category1)."\t";

        $row .= $chartdata[$idx].$sd
	         . "<a href='#specificKeggStats' "
             . "onclick=javascript:showImage('$url')>";
        $row .= $chartdata[$idx]."\t";
        $row .= sprintf("%.0f%%", $percent)."\t";
        $it->addRow($row);
	    $idx++;
    }

    # add the unclassified row:
    my $row;
    $row .= "Unclassified".$sd."&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "Unclassified";
    $row .= "\t";

    $row .= $unclassified_count."\t";
    my $unclassified_percent;
    if ( $total ) {
        $unclassified_percent = $unclassified_count / $total * 100;
    }
    $row .= sprintf( "%.0f%%", $unclassified_percent )."\t";
    $it->addRow($row);

    $it->printOuterTable("nopage");
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "printKeggs", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
		. $chart->FILE_PREFIX . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    print "</td></tr>\n";
    print "</table>\n";

    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{
        <script type='text/javascript'>
        YAHOO.namespace("example.container");
        YAHOO.util.Event.addListener(window, "load", initPanel("container"));
        </script>
    };
    print "</div>\n";
}

############################################################################
# printTaxonBreakdownCogStats - Print stats for each taxon, COG/KOG category.
############################################################################
sub printTaxonBreakdownCogStats {
    my ($mode, $isKOG, $pangenome_oid) = @_;

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1; # datatable.css should be loaded for the first table on page

    my $og = "cog"; # orthogonal group: cog|kog
    my $OG = "COG"; # orthogonal group text: COG|KOG

    if ($isKOG) {
    	$og = "kog";
    	$OG = "KOG";
    }

    my $dbh = dbLogin();

    my $taxon_oids_ref = GenomeCart::getAllGenomeOids();
    my ( $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid, $metaNumOfSelection )
        = validNumOfSelection( $dbh, $taxon_oids_ref );

    if ( $mode eq "display" || $mode eq "" ) {
        printMainForm();
        printStatusLine( "Loading ...", 1 );
    }

    use CogCategories;

    my ($cat2geneCnt_href, $results_href, $id2cat_href, $taxon_domain_href);
    if ( ( $isMetaNumOfSelectionValid && $metaNumOfSelection > 0 && !$isKOG )
        || ( $mode ne "export" && ($pangenome_oid ne "" || ($isDbNumOfSelectionValid && $isMetaNumOfSelectionValid) ) ) ){
        ($cat2geneCnt_href, $results_href, $id2cat_href, $taxon_domain_href)
            = getCategoryGeneCount($dbh, $pangenome_oid, $og,
            $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);
    }

    my @columns = ();
    my $results_no_code;
    my $results_total_gene_count_href;
    if ( $isMetaNumOfSelectionValid && $metaNumOfSelection > 0 && !$isKOG ){

            # colums to print
            # note columns ending in _pc are not in the DB
            #my @selected_cols = param("outputCol");
            #for my $col (@selected_cols) {
            #    push(@columns, CogCategories::getLabelForName($col));
            #}
            @columns = param("outputCol");
            if ( $#columns < 0 ) {
                # add default columns
                push( @columns, "Total COG Genes" );
                push( @columns, "Amino acid transport and metabolism" );
                push( @columns, "Amino acid transport and metabolism (percentage)" );
                push( @columns, "Carbohydrate transport and metabolism" );
                push( @columns, "Carbohydrate transport and metabolism (percentage)" );
            }

            $results_no_code = getResultsWithoutCode( $results_href );

            $results_total_gene_count_href
                = getTaxonTotalFuncGeneCount( $dbh, $taxon_domain_href, 'cog' );
    }

    if ( $mode eq "export" ) {
        if ( $isMetaNumOfSelectionValid && $metaNumOfSelection > 0 && !$isKOG ) {
            printDataTableExport( $results_no_code, $results_total_gene_count_href,
                                  $taxon_domain_href, \@columns );
        }
        else {
            my $cts = initCompTaxonStats( $dbh, $og, $pangenome_oid );
            $cts->printCompStatExport();
        }
    } else {

        printStatisticsDisplayTitle($dbh, $pangenome_oid, $og,
            $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);

    	use TabHTML;
    	TabHTML::printTabAPILinks("ogcatTab");
    	my @tabIndex = ();
    	my @tabNames = ();

    	my $idx = 1;
    	if ( $pangenome_oid ne "" || ($isDbNumOfSelectionValid && $isMetaNumOfSelectionValid) ) {
    	    push @tabIndex, "#ogcattab".$idx;
    	    push @tabNames, "Statistics for Genomes by specific $OG category";
    	    $idx++;
    	}

    	if ( $pangenome_oid ne "" ) {
    	    push @tabIndex, "#ogcattab".$idx;
    	    push @tabNames, "Pangenes by $OG categories";
    	    $idx++;
    	} else {
    	    push @tabIndex, "#ogcattab".$idx;
    	    push @tabNames, "Statistics for Genomes by $OG categories";
    	    $idx++;
    	}

    	TabHTML::printTabDiv("ogcatTab", \@tabIndex, \@tabNames);

    	GenomeCart::insertToGtt($dbh);
        my $sql = "select count(id) from gtt_taxon_oid";
        my $cur = execSql( $dbh, $sql, $verbose );
        my $sessionCount = $cur->fetchrow();
        $cur->finish();

        if ( $pangenome_oid ne "" || ($isDbNumOfSelectionValid && $isMetaNumOfSelectionValid) ) {
    	    print "<div id='ogcattab1'>";
    	    print "<h2>Statistics for Genomes by specific $OG Category</h2>";
            printAllCogTable($dbh, $pangenome_oid, $cat2geneCnt_href, $og, $blockDatatableCss);
    	    print "</div>";
        }

    	if ($pangenome_oid ne "") {
    	    print "<div id='ogcattab2'>";
    	    print "<h2>Pangenes by $OG Categories</h2>";
    	    printHint( "Columns can be added or removed "
    		     . "using the configuration table below." );
    	    print "<br/>";
    	} else {
    	    print "<div id='ogcattab2'>";
    	    print "<h2>Statistics for Genomes by $OG Categories</h2>";

            printHintHeader();

    	    print "<p>\n";
    	    print domainLetterNote() . "<br/>\n";
    	    print completionLetterNote() . "<br/>\n";
    	    print "</p>\n";
    	}

        if ( $isMetaNumOfSelectionValid && $metaNumOfSelection > 0 && !$isKOG ) {
            #print "inside isMetaNumOfSelectionValid columns: @columns<br/>\n";

            printDataTable( $results_no_code, $results_total_gene_count_href,
                            $taxon_domain_href, \@columns, 'cog' );

            # export to excel button
            print "<h2>Export Genome Table</h2>";
            my $name = "_section_CompareGenomes_excel_exportCompStats";

            my $contact_oid = WebUtil::getContactOid();
            my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name");
            print qq{
                <input class='lgdefbutton' name='$name' type="submit" value="Export Tab Delimited To Excel" $str>
            };

            # print column selection table
            print "<h2>Configuration</h2>";
            my @category_list = getCogCategoryList( $dbh );
            printConfigTable( \@category_list, \@columns, $pangenome_oid, 'cog' );

        }
        else {
            my $cts = initCompTaxonStats( $dbh, $og, $pangenome_oid );
            $cts->{ blockDatatableCss } = $blockDatatableCss;
            $cts->printOrgTable();

            print "<h2>Export Genome Table</h2>";
            $cts->printExport();

            print "<h2>Configuration</h2>";
            $cts->{ blockDatatableCss } = $blockDatatableCss;
            $cts->printConfigTable();
        }

    	print "</div>";

    	TabHTML::printTabDivEnd();
    }

    #$dbh->disconnect();
    if ( $mode eq "" || $mode eq "display" ) {
        printStatusLine( "Loaded.", 2 );
        print end_form();
    }
}

sub initCompTaxonStats {
    my ( $dbh, $og, $pangenome_oid ) = @_;

    my $cts = new CompTaxonStats( $dbh, "dt_${og}_stats", $pangenome_oid );

    my $lin = 1;
    if ($pangenome_oid ne "") {
        $lin = "";
    }
    my $a_ref = CogCategories::getAllCogNames($og, $lin);
    $cts->loadColNames( $a_ref );

    my $x = $cts->colName2Header();
    CogCategories::loadName2Header($x);

    my $x = $cts->colNamesAutoSelected();
    $x->{total_cog_gene_count}       = 1;
    $x->{total_kog_gene_count}       = 1;
    $x->{total_kegg_gene_count}      = 1;
    $x->{amino_acid_metabolism}      = 1;
    $x->{amino_acid_metabolism_pc}   = 1;
    $x->{carbohydrate_metabolism}    = 1;
    $x->{carbohydrate_metabolism_pc} = 1;
    $x->{lipid_metabolism}           = 1;
    $x->{lipid_metabolism_pc}        = 1;

    my $x = $cts->colNameSortQual();

    return $cts;
}


sub getResultsWithoutCode {
    my ( $results_href ) = @_;

    my %results;
    for my $t_oid ( keys %$results_href ) {
        my %cat_results;
        my $cat_href = $results_href->{$t_oid};
        for my $cat ( keys %$cat_href ) {
            my ( $definition, $function_code ) = split( /\t/, $cat );
            $cat_results{$definition} = $cat_href->{$cat};
        }
        $results{$t_oid} = \%cat_results;
    }

    return (\%results);
}

############################################################################
# getCategoryGeneCount
############################################################################
sub getCategoryGeneCount {
    my ($dbh, $pangenome_oid, $func_type,
        $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid) = @_;

    # taxon oid => line of domain info
    my %taxon_domain = getTaxonDomain( $dbh, $pangenome_oid );
    my @goodTaxons = keys %taxon_domain;
    my ( $dbTaxons_ref, $metaTaxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @goodTaxons );
    my @dbTaxons   = @$dbTaxons_ref;
    my @metaTaxons = @$metaTaxons_ref;

    # hash of hash taxon oid => cat => gene count
    my %results;

    if ( scalar(@dbTaxons) > 0 ) {
        my $taxonClause;
        if ( $nSelectedTaxons > 0 ) {
            my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @dbTaxons );
            $taxonClause = qq{
                and g.taxon in ( $taxon_str )
            };
        }

        my $sql;
        if ( $func_type =~ /cog/i || $func_type =~ /kog/i ) {
            my $og = $func_type;
            $sql = qq{
                select g.taxon, $nvl(cf.function_code, 'Unclassified'),
                    $nvl(cf.definition, 'Unclassified'), count(distinct g.gene_oid)
                from gene g, gene_${og}_groups gcg
                left join ${og}_functions cfs on gcg.${og} = cfs.${og}_id
                left join ${og}_function cf on cfs.functions = cf.function_code
                where g.gene_oid = gcg.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
                $taxonClause
                group by g.taxon, cf.function_code, cf.definition
                having count(distinct g.gene_oid) > 0
                order by cf.definition
            };
        }
        elsif ( $func_type =~ /pfam/i ) {
            $sql = qq{
                select g.taxon, $nvl(cf.function_code, 'Unclassified'),
                       $nvl(cf.definition, 'Unclassified'),
                       count( distinct g.gene_oid )
                from gene g, gene_pfam_families gpf
                left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession
                left join cog_function cf on pfc.functions = cf.function_code
                where g.gene_oid = gpf.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
                $taxonClause
                group by g.taxon, cf.function_code, cf.definition
                having count(distinct g.gene_oid) > 0
                order by cf.definition
            };
        }
        elsif ( $func_type =~ /tigr/i ) {
           $sql = qq{
                select g.taxon, $nvl(tr.main_role, 'Unclassified'), count( distinct g.gene_oid )
                from gene g, gene_tigrfams gtf
                left join tigrfam_roles trs on gtf.ext_accession = trs.ext_accession
                left join tigr_role tr on trs.roles = tr.role_id
                where g.gene_oid = gtf.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
                $taxonClause
                group by g.taxon, tr.main_role
                having count(distinct g.gene_oid) > 0
                order by tr.main_role
            };
        }
        elsif ( $func_type =~ /kegg/i ) {
            if ( $isDbNumOfSelectionValid ) {
                $sql = qq{
                    select g.taxon, $nvl(pw.category, 'Unclassified'), count( distinct g.gene_oid )
                    from gene g, gene_ko_terms gk
                    left join image_roi_ko_terms rk on gk.ko_terms = rk.ko_terms
                    left join image_roi roi on rk.roi_id = roi.roi_id
                    left join kegg_pathway pw on roi.pathway = pw.pathway_oid
                    where g.gene_oid = gk.gene_oid
                    and g.locus_type = ?
                    and g.obsolete_flag = ?
                    $taxonClause
                    group by g.taxon, pw.category
                    having count(distinct g.gene_oid) > 0
                    order by pw.category
                };
            }
            else {
                $sql = qq{
                    select g.taxon, $nvl(pw.category, 'Unclassified'), count(distinct g.gene_oid)
                    from dt_gene_ko_module_pwys g, kegg_pathway pw
                    where g.pathway_oid = pw.pathway_oid
                    $taxonClause
                    group by g.taxon, pw.category
                    having count(distinct g.gene_oid) > 0
                    order by pw.category
                };
            }
        }
        #print "getCategoryGeneCount() sql: $sql<br/>\n";

        my $cur;
        if ( $func_type =~ /kegg/i && !$isDbNumOfSelectionValid) {
            $cur = execSql( $dbh, $sql, $verbose );
        }
        else {
            $cur = execSql( $dbh, $sql, $verbose, 'CDS', 'No' );
        }

        if ( $func_type =~ /cog/i || $func_type =~ /kog/i || $func_type =~ /pfam/i ) {
            for ( ; ; ) {
                my ( $taxon_oid, $function_code, $definition, $gene_count ) = $cur->fetchrow();
                last if !$taxon_oid;

                if ( $taxon_domain{$taxon_oid} ) {
                    my $cat = $definition . "\t" . $function_code;
                    my $href = $results{$taxon_oid};
                    if ( $href eq "" ) {
                        my %hash;
                        $hash{$cat}          = $gene_count;
                        $results{$taxon_oid} = \%hash;
                    } else {
                        $href->{$cat} = $gene_count;
                    }
                }
            }
        }
        elsif ( $func_type =~ /tigr/i || $func_type =~ /kegg/i ) {
            for ( ; ; ) {
                my ( $taxon_oid, $cat, $gene_count ) = $cur->fetchrow();
                last if !$taxon_oid;

                if ( $taxon_domain{$taxon_oid} ) {
                    my $href = $results{$taxon_oid};
                    if ( $href eq "" ) {
                        my %hash;
                        $hash{$cat}          = $gene_count;
                        $results{$taxon_oid} = \%hash;
                    } else {
                        $href->{$cat} = $gene_count;
                    }
                }
            }
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
            if ( $taxonClause =~ /gtt_num_id/i );
    }

    my %id2cat;
    if ( $isMetaNumOfSelectionValid && scalar(@metaTaxons) > 0 ) {
        #no KOG for metagenome
        if ( $func_type =~ /cog/i || $func_type =~ /pfam/i || $func_type =~ /tigr/i ) {
            getMetagenomeCategoryGeneCount($dbh, \@metaTaxons, \%id2cat, \%results, $func_type);
        }
        elsif ( $func_type =~ /kegg/i ) {
            getMetagenomeKeggCategoryGeneCount($dbh, \@metaTaxons, \%id2cat, \%results);
        }
    }
    #print Dumper(\%results);
    #print "<br/>\n";

    my %cat2geneCnt;
    for my $taxon_oid (keys %results) {
        my $cat_href = $results{$taxon_oid};

        for my $cat (keys %$cat_href) {
            my $geneCnt = $cat_href->{$cat};

            my $cnt = $cat2geneCnt{$cat};
            if ( $cnt ) {
                $cat2geneCnt{$cat} = $geneCnt + $cnt;
            }
            else {
                $cat2geneCnt{$cat} = $geneCnt;
            }
        }
    }
    #print Dumper(%cat2geneCnt);
    #print "<br/>\n";

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    return (\%cat2geneCnt, \%results, \%id2cat, \%taxon_domain);
}

sub getTaxonDomain {
    my ( $dbh, $pangenome_oid ) = @_;

    my $taxonClause = txsClause("t", $dbh);

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    $virusClause = "and t.domain not like 'Vir%'"
        if $hideViruses eq "Yes";

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;
    $plasmidClause = "and t.domain not like 'Plasmid%'"
        if $hidePlasmids eq "Yes";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $gFragmentClause;
    $gFragmentClause = "and t.domain not like 'GFragment%'"
        if ( $hideGFragment eq "Yes" );

    if ( $pangenome_oid ne "" ) {
        my $aref = Pangenome::getCompGenomes( $dbh, $pangenome_oid );
        push( @$aref, $pangenome_oid );
        my $taxon_str = join(',', @$aref);
        $taxonClause = qq{
            and t.taxon_oid in ($taxon_str)
        };

        $virusClause = "";
        $plasmidClause = "";
        $gFragmentClause = "";
    }

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    # taxon oid => line of domain info
    my %taxon_domain;

    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name, t.seq_status,
            t.domain, t.phylum, t.ir_class, t.ir_order, t.family, t.genus
        from taxon t
        where 1 = 1
        $virusClause
        $plasmidClause
        $gFragmentClause
        $taxonClause
        $rclause
        $imgClause
        order by t.taxon_oid
    };
    #print "getTaxonDomain() sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my (
             $taxon_oid, $taxon_display_name, $seq_status,
             $domain, $phylum, $ir_class, $ir_order, $family, $genus
          )
          = $cur->fetchrow();
        last if !$taxon_oid;

        $taxon_domain{$taxon_oid} =
            "$taxon_display_name\t$seq_status\t$domain\t$phylum\t$ir_class\t"
          . "$ir_order\t$family\t$genus";
    }
    $cur->finish();

    return ( %taxon_domain );
}


############################################################################
# getMetagenomeCategoryGeneCount
############################################################################
sub getMetagenomeCategoryGeneCount {
    my ($dbh, $metaTaxons_ref, $id2cat_href, $results_href, $func_type) = @_;

    if (scalar(@$metaTaxons_ref) > 0) {

        # get all the func_ids
        my $taxon_str = OracleUtil::getNumberIdsInClause( $dbh, @$metaTaxons_ref );
        my $taxonClause = qq{
            and g.taxon_oid in ($taxon_str)
        };

        my $sql;
        if ( $func_type =~ /cog/i ) {
            $sql = qq{
                select distinct g.taxon_oid, g.func_id
                from TAXON_COG_COUNT g
                where g.gene_count > 0
                $taxonClause
            };
        }
        elsif ( $func_type =~ /pfam/i ) {
            $sql = qq{
                select distinct g.taxon_oid, g.func_id
                from TAXON_PFAM_COUNT g
                where g.gene_count > 0
                $taxonClause
            };
        }
        elsif ( $func_type =~ /tigr/i ) {
            $sql = qq{
                select distinct g.taxon_oid, g.func_id
                from TAXON_TIGR_COUNT g
                where g.gene_count > 0
                $taxonClause
            };
        }
        #print "getMetagenomeCategoryGeneCount() func_id sql: $sql<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose );
        webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

        my %taxon2func;
        my %func_ids_h;
        for ( ; ; ) {
            my ( $taxon_oid, $func_id ) = $cur->fetchrow();
            last if !$taxon_oid;

            my $func_ids_ref = $taxon2func{$taxon_oid};
            if ( $func_ids_ref eq '' ) {
                my @func_ids = ($func_id);
                $taxon2func{$taxon_oid} = \@func_ids;
            } else {
                push(@$func_ids_ref, $func_id);
                #$taxon2func{$taxon_oid} = $func_ids_ref;
            }
            $func_ids_h{$func_id} = 1;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) if ( $taxon_str =~ /gtt_num_id/i );
        #print Dumper(\%taxon2func);
        #print "<br/>\n";

        # get all the categories
        my @func_ids = keys %func_ids_h;
        if ( scalar(@func_ids) <= 0 ) {
            return;
        }

        my $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @func_ids );

        my $sql;
        if ( $func_type =~ /cog/i ) {
            $sql = qq{
                select distinct cfs.cog_id, cf.function_code, cf.definition
                from cog_functions cfs, cog_function cf
                where cfs.functions = cf.function_code
                and cfs.cog_id in ($func_ids_str)
            };
        }
        elsif ( $func_type =~ /pfam/i ) {
            $sql = qq{
                select distinct pfc.ext_accession, cf.function_code, cf.definition
                from pfam_family_cogs pfc, cog_function cf
                where pfc.functions = cf.function_code
                and pfc.ext_accession in ($func_ids_str)
            };
        }
        elsif ( $func_type =~ /tigr/i ) {
            $sql = qq{
                select distinct trs.ext_accession, tr.main_role
                from tigrfam_roles trs, tigr_role tr
                where trs.roles = tr.role_id
                and trs.ext_accession in ($func_ids_str)
            };
        }
        #print "getMetagenomeCategoryGeneCount() category sql: $sql<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose );

        if ( $func_type =~ /cog/i || $func_type =~ /pfam/i ) {
            for ( ; ; ) {
                my ($id, $function_code, $definition) = $cur->fetchrow();
                last if !$id;
                my $cat = $definition . "\t" . $function_code;

                my $cats_ref = $id2cat_href->{$id};
                if ( $cats_ref ) {
                    push(@$cats_ref, $cat);
                    #$id2cat_href->{$id} = $cats_ref;
                }
                else {
                    my @cats = ($cat);
                    $id2cat_href->{$id} = \@cats;
                }
            }
        }
        elsif ( $func_type =~ /tigr/i ) {
            for ( ; ; ) {
                my ($id, $cat) = $cur->fetchrow();
                last if !$id;

                my $cats_ref = $id2cat_href->{$id};
                if ( $cats_ref ) {
                    push(@$cats_ref, $cat);
                    #$id2cat_href->{$id} = $cats_ref;
                }
                else {
                    my @cats = ($cat);
                    $id2cat_href->{$id} = \@cats;
                }
            }
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $func_ids_str =~ /gtt_func_id/i );
        #print Dumper($id2cat_href);
        #print "<br/>\n";

        # get the genes for each func id, and put them into each category
        for my $t_oid (@$metaTaxons_ref) {
            my %cat2genes;

            my $func_ids_ref = $taxon2func{$t_oid};
            for my $func_id (@$func_ids_ref) {
                my %func_genes = MetaUtil::getTaxonFuncGenes( $t_oid, '', $func_id );
                my @funcGenes = keys %func_genes;

                my $cats_ref = $id2cat_href->{$func_id};
                for my $cat (@$cats_ref) {
                    #print "getMetagenomeCategoryGeneCount() $func_id, cat: $cat, funcGenes size: " . scalar(@funcGenes) . "<br/>\n";
                    # remove duplicate genes for each cat
                    my $href = $cat2genes{$cat};
                    if ( $href eq '' ) {
                        my %hash;
                        for my $f_gene (@funcGenes) {
                            $hash{$f_gene} = 1;
                        }
                        $cat2genes{$cat} = \%hash;
                    } else {
                        for my $f_gene (@funcGenes) {
                            $href->{$f_gene} = 1;
                        }
                    }
                }
            }
            #print Dumper(\%cat2genes);
            #print "<br/>\n";

            for my $cat (keys %cat2genes) {
                my $genes_href = $cat2genes{$cat};
                my @genes = keys %$genes_href;
                my $gene_count = scalar(@genes);

                my $href = $results_href->{$t_oid};
                if ( $href eq '' ) {
                    my %hash;
                    $hash{$cat} = $gene_count;
                    $results_href->{$t_oid} = \%hash;
                } else {
                    my $cnt = $href->{$cat};
                    if ( $cnt ) {
                        $href->{$cat} = $gene_count + $cnt;
                    }
                    else {
                        $href->{$cat} = $gene_count;
                    }
                }
                #print "getMetagenomeCategoryGeneCount() added $gene_count to cat: $cat<br/>\n";
            }
        }
    }
    #print Dumper($results_href);
    #print "<br/>\n";

}


############################################################################
# getMetagenomeKeggCategoryGeneCount
############################################################################
sub getMetagenomeKeggCategoryGeneCount {
    my ($dbh, $metaTaxons_ref, $id2cat_href, $results_href) = @_;

    if (scalar(@$metaTaxons_ref) > 0) {

        # get all the categories
        my $sql = qq{
            select distinct pw.pathway_oid, pw.category
            from kegg_pathway pw
        };
        #print "getMetagenomeKeggCategoryGeneCount() sql: $sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($id, $cat) = $cur->fetchrow();
            last if !$id;

            my $cats_ref = $id2cat_href->{$id};
            if ( $cats_ref ) {
                push(@$cats_ref, $cat);
                #$id2cat_href->{$id} = $cats_ref;
            }
            else {
                my @cats = ($cat);
                $id2cat_href->{$id} = \@cats;
            }

        }
        $cur->finish();
        #print Dumper($id2cat_href);
        #print "<br/>\n";

        for my $t_oid (@$metaTaxons_ref) {
            my %funcs = MetaUtil::getTaxonFuncCount($t_oid, '', 'kegg_pathway');
            for my $pathway_oid (keys %funcs) {
                my $gene_count = $funcs{$pathway_oid};
                my $cats_ref = $id2cat_href->{$pathway_oid};

                for my $cat (@$cats_ref) {
                    my $href = $results_href->{$t_oid};
                    if ( $href eq "" ) {
                        my %hash;
                        $hash{$cat}      = $gene_count;
                        $results_href->{$t_oid} = \%hash;
                    } else {
                        #Todo: in-accurate with below addition of gene_count
                        $href->{$cat} += $gene_count;
                    }
                    #if ($cat eq 'Amino acid metabolism') {
                    #    print "getMetagenomeKeggCategoryGeneCount() t_oid: $t_oid, pathway_oid: $pathway_oid, cat: $cat, gene_count: $gene_count<br/>\n";
                    #}
                }
            }
        }
    }
    #print Dumper($results_href);
    #print "<br/>\n";

}


sub printTaxonBreakdownPfamStats {
    my ($mode, $pangenome_oid) = @_;

    my $dbh = dbLogin();

    my $taxon_oids_ref = GenomeCart::getAllGenomeOids();
    my ( $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid, $metaNumOfSelection )
        = validNumOfSelection( $dbh, $taxon_oids_ref );

    if ( $mode eq "display" || $mode eq "" ) {
        printStatusLine( "Loading ...", 1 );
        printMainForm();

        printStatisticsDisplayTitle($dbh, $pangenome_oid, 'pfam',
            $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);

        use TabHTML;
        TabHTML::printTabAPILinks("pfamcatTab");
        my @tabIndex = ();
        my @tabNames = ();

        my $idx = 1;
        #if ( $pangenome_oid ne "" || $isDbNumOfSelectionValid ) {
            push @tabIndex, "pfamcattab".$idx;
            push @tabNames, "Statistics for Genomes by specific Pfam category";
            $idx++;
        #}

        TabHTML::printTabDiv("pfamcatTab", \@tabIndex, \@tabNames);

    }

    my ($cat2geneCnt_href, $results_href, $id2cat_href, $taxon_domain_href)
        = getCategoryGeneCount($dbh, $pangenome_oid, 'pfam',
        $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);

    print "<div id='pfamcattab1'>";
    print "<h2>Statistics for Genomes by specific Pfam Category</h2>";
    printAllPfamTable($dbh, $pangenome_oid, $cat2geneCnt_href);
    print "</div>";
    TabHTML::printTabDivEnd();

    if ( $mode eq "" || $mode eq "display" ) {
        printStatusLine( "Loaded.", 2 );
        print end_form();
    }
}


############################################################################
# printAllPfamTable - Prints Pfam categories as links for selected genomes
############################################################################
sub printAllPfamTable {
    my ($dbh, $pangenome_oid, $cat2geneCnt_href) = @_;

    my $pangenome_url_frag = "";
    if ($pangenome_oid ne "") {
        $pangenome_url_frag = "&pangenome_oid=$pangenome_oid";
    }
    my $url2 = "xml.cgi?section=BarChartImage&page=comparePfamStats";
    $url2 .= $pangenome_url_frag;

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME("function_code");
    my @chartseries;
    my @chartcategories;
    my @functioncodes;
    my @chartdata;
    #################################

    my $total = 0;
    my $unclassified_count = 0;
    my @sortedCat = sort(keys %$cat2geneCnt_href);
    for my $cat ( @sortedCat ) {
        my $gene_count = $cat2geneCnt_href->{$cat};
        $total = $total + $gene_count;
        my ( $definition, $function_code ) = split( /\t/, $cat );

        if ( $definition eq "Unclassified" ) {
            $unclassified_count = $gene_count;
            next;
        }

        push(@chartcategories, $definition);
        push(@functioncodes,   $function_code);
        push(@chartdata,       $gene_count);
    }

    #print "printAllPfamTable() chartcategories: @chartcategories<br/>\n";
    #print "printAllPfamTable() functioncodes: @functioncodes<br/>\n";
    #print "printAllPfamTable() chartdata: @chartdata<br/>\n";
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@functioncodes );
    $chart->IMAGEMAP_ONCLICK('showImage');

    #$chart->IMAGEMAP_HREF_ONCLICK('specificPfamStats');
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<script src='$base_url/chart.js'></script>\n";
    print qq{
        <link rel="stylesheet" type="text/css"
          href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript"
          src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript"
          src="$YUI/build/container/container-min.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js"></script>
        <script src="$YUI/build/event/event-min.js"></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
    };

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    my $it = new InnerTable(1, "allpfamcats$$", "allpfamcats", 0);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "<span id='anchor'>Pfam Categories</span>", "", "left" );
    $it->addColSpec( "Gene Count", "", "right" );
    $it->addColSpec( "Percent", "", "right", "", "Total genes = $total" );
    $it->hideAll();

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;

        my $url = "xml.cgi?section=BarChartImage&page=comparePfamStats";
	    $url .= $pangenome_url_frag;
        $url .= "&function_code=$functioncodes[$idx]";

        my $percent = ( ( $chartdata[$idx] ) / $total ) * 100;
	    my $row;
        if ( $st == 0 ) {
	    $row .= escHtml($category1).$sd;
            $row .= "<a href='#${chartdata[$idx]}' "
		  . "onclick=javascript:showImage('$url')>";
            $row .= "<img src='$tmp_url/" . $chart->FILE_PREFIX
		  . "-color-" . $idx . ".png' border=0>";
            $row .= "</a>";
            $row .= "&nbsp;&nbsp;";
        }

        $row .= escHtml($category1)."\t";

	    # Gene Count
        $row .= $chartdata[$idx].$sd
	     . "<a href='#${chartdata[$idx]}' "
	     . "onclick=javascript:showImage('$url')>";
        $row .= $chartdata[$idx]."\t";

	    # Percent
        $row .= sprintf( "%.0f%%", $percent )."\t";
	    $it->addRow($row);
	    $idx++;
    }

    # add the unclassified row:
    my $row;
    $row .= "Unclassified".$sd."&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "Unclassified";
    $row .= "\t";

    $row .= $unclassified_count."\t";
    my $unclassified_percent;
    if ( $total ) {
        $unclassified_percent = $unclassified_count / $total * 100;
    }
    $row .= sprintf( "%.0f%%", $unclassified_percent )."\t";
    $it->addRow($row);

    $it->printOuterTable("nopage");
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "printPfams", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    print "</td></tr>\n";
    print "</table>\n";

    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{
        <script type='text/javascript'>
	YAHOO.namespace("example.container");
        YAHOO.util.Event.addListener(window, "load", initPanel("container"));
        </script>
    };
    print "</div>\n";
}


sub printTaxonBreakdownTIGRfamStats {
    my ($mode, $pangenome_oid) = @_;

    my $dbh = dbLogin();

    my $taxon_oids_ref = GenomeCart::getAllGenomeOids();
    my ( $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid, $metaNumOfSelection )
        = validNumOfSelection( $dbh, $taxon_oids_ref );

    if ( $mode eq "display" || $mode eq "" ) {
        printStatusLine( "Loading ...", 1 );
        printMainForm();

        printStatisticsDisplayTitle($dbh, $pangenome_oid, 'tigr',
            $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);

        use TabHTML;
        TabHTML::printTabAPILinks("tigrfamcatTab");
        my @tabIndex = ();
        my @tabNames = ();

        my $idx = 1;
        #if ( $pangenome_oid ne "" || $isDbNumOfSelectionValid ) {
            push @tabIndex, "tigrfamcattab".$idx;
            push @tabNames, "Statistics for Genomes by specific TIGRfam category";
            $idx++;
        #}

        TabHTML::printTabDiv("tigrfamcatTab", \@tabIndex, \@tabNames);

    }


    my ($cat2geneCnt_href, $results_href, $id2cat_href, $taxon_domain_href)
        = getCategoryGeneCount($dbh, $pangenome_oid, 'tigr',
        $nSelectedTaxons, $isDbNumOfSelectionValid, $isMetaNumOfSelectionValid);

    print "<div id='tigrfamcattab1'>";
    print "<h2>Statistics for Genomes by specific TIGRfam Role</h2>";
    printAllTIGRfamTable($dbh, $pangenome_oid, $cat2geneCnt_href);
    print "</div>";
    TabHTML::printTabDivEnd();

    if ( $mode eq "" || $mode eq "display" ) {
        printStatusLine( "Loaded.", 2 );
        print end_form();
    }
}


############################################################################
# printAllTIGRfamTable - Prints TIGRfam categories as links
#                        for selected genomes
############################################################################
sub printAllTIGRfamTable {
    my ($dbh, $pangenome_oid, $cat2geneCnt_href) = @_;

    my $pangenome_url_frag = "";
    if ($pangenome_oid ne "") {
        $pangenome_url_frag = "&pangenome_oid=$pangenome_oid";
    }
    my $url2 = "xml.cgi?section=BarChartImage&page=compareTIGRfamStats";
    $url2 .= $pangenome_url_frag;

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME("role");
    my @chartseries;
    my @chartcategories;
    my @roles;
    my @chartdata;
    #################################

    my $total = 0;
    my $unclassified_count = 0;
    my @sortedCat = sort(keys %$cat2geneCnt_href);
    for my $cat ( @sortedCat ) {
        my $gene_count = $cat2geneCnt_href->{$cat};
        $total = $total + $gene_count;

        if ( $cat eq "Unclassified" ) {
            $unclassified_count = $gene_count;
            next;
        }

        push(@chartcategories, $cat);
        push(@roles,           $cat);
        push(@chartdata,       $gene_count);
    }

    #print "printAllTIGRfamTable() chartcategories: @chartcategories<br/>\n";
    #print "printAllTIGRfamTable() roles: @roles<br/>\n";
    #print "printAllTIGRfamTable() chartdata: @chartdata<br/>\n";
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@roles );
    $chart->IMAGEMAP_ONCLICK('showImage');

    #$chart->IMAGEMAP_HREF_ONCLICK('');
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<script src='$base_url/chart.js'></script>\n";
    print qq{
        <link rel="stylesheet" type="text/css"
          href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript"
          src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript"
          src="$YUI/build/container/container-min.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js"></script>
        <script src="$YUI/build/event/event-min.js"></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
      };

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    my $it = new InnerTable(1, "alltigrfamroles$$", "alltigrfamroles", 0);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "<span id='anchor'>TIGRfam Roles</span>", "", "left" );
    $it->addColSpec( "Gene Count", "", "right" );
    $it->addColSpec( "Percent", "", "right", "", "Total genes = $total" );
    $it->hideAll();

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;

        my $url = "xml.cgi?section=BarChartImage&page=compareTIGRfamStats";
	    $url .= $pangenome_url_frag;
        $url .= "&role=" . massageToUrl( $roles[$idx] );

        my $percent = ( ( $chartdata[$idx] ) / $total ) * 100;
	    my $row;

	    # Roles
        if ( $st == 0 ) {
            $row .= escHtml($category1).$sd
		  . "<a href='#${chartdata[$idx]}' "
		  . "onclick=javascript:showImage('$url')>";
            $row .= "<img src='$tmp_url/" . $chart->FILE_PREFIX
		  . "-color-" . $idx . ".png' border=0>";
            $row .= "</a>";
            $row .= "&nbsp;&nbsp;";
        }

        $row .= escHtml($category1)."\t";

	    # Gene Count
        $row .= $chartdata[$idx].$sd
	      . "<a href='#${chartdata[$idx]}' "
	      . "onclick=javascript:showImage('$url')>";
        $row .= $chartdata[$idx]."\t";

	     # Percent
        $row .= sprintf( "%.0f%%", $percent )."\t";
	    $it->addRow($row);
        $idx++;
    }

    # add the unclassified row:
    my $row;
    $row .= "Unclassified".$sd."&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "Unclassified";
    $row .= "\t";

    $row .= $unclassified_count."\t";
    my $unclassified_percent;
    if ( $total ) {
        $unclassified_percent = $unclassified_count / $total * 100;
    }
    $row .= sprintf( "%.0f%%", $unclassified_percent )."\t";
    $it->addRow($row);

    $it->printOuterTable("nopage");
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "printTIGRfams", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
		. $chart->FILE_PREFIX . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    print "</td></tr>\n";
    print "</table>\n";

    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{
        <script type='text/javascript'>
	YAHOO.namespace("example.container");
        YAHOO.util.Event.addListener(window, "load", initPanel("container"));
        </script>
    };
    print "</div>\n";
}

############################################################################
# printAllCogTable - Prints COG/KOG categories as links for selected genomes
############################################################################
sub printAllCogTable {
    my ($dbh, $pangenome_oid, $cat2geneCnt_href, $og, $blockDatatableCss ) = @_;

    my $OG = uc($og); # text for COG/KOG

    my $pangenome_url_frag = "";
    if ($pangenome_oid ne "") {
    	$pangenome_url_frag = "&pangenome_oid=$pangenome_oid";
    }
    my $url2 = "xml.cgi?section=BarChartImage&page=compare${OG}Stats";
    $url2 .= $pangenome_url_frag;

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->URL_SECTION_NAME("function_code");
    my @chartseries;
    my @chartcategories;
    my @functioncodes;
    my @chartdata;
    #################################

    my $total = 0;
    my $unclassified_count = 0;
    my @sortedCat = sort(keys %$cat2geneCnt_href);
    for my $cat ( @sortedCat ) {
        my $gene_count = $cat2geneCnt_href->{$cat};
        $total = $total + $gene_count;
        my ( $definition, $function_code ) = split( /\t/, $cat );

        if ( $definition eq "Unclassified" ) {
            $unclassified_count = $gene_count;
            next;
        }

        push(@chartcategories, $definition);
        push(@functioncodes,   $function_code);
        push(@chartdata,       $gene_count);
    }

    #print "printAllCogTable() chartcategories: @chartcategories<br/>\n";
    #print "printAllCogTable() functioncodes: @functioncodes<br/>\n";
    #print "printAllCogTable() chartdata: @chartdata<br/>\n";
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@functioncodes );
    $chart->IMAGEMAP_ONCLICK('showImage');
    $chart->IMAGEMAP_HREF_ONCLICK('specificCogStats');
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<script src='$base_url/chart.js'></script>\n";
    print qq{
        <link rel="stylesheet" type="text/css"
          href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript"
          src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript"
          src="$YUI/build/container/container-min.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js"></script>
        <script src="$YUI/build/event/event-min.js"></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
    };

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    my $it = new InnerTable(1, "all$og"."cats$$", "all$og"."cats", 0);
    my $sd = $it->getSdDelim();
    $it->{ blockDatatableCss } = $blockDatatableCss;

    $it->addColSpec( "<span id='anchor'>$OG Categories</span>", "", "left" );
    $it->addColSpec( "Gene Count", "", "right" );
    $it->addColSpec( "Percent", "", "right", "", "Total genes = $total" );
    $it->hideAll();

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;

        my $url = "xml.cgi?section=BarChartImage&page=compare${OG}Stats";
    	$url .= $pangenome_url_frag;
        $url .= "&function_code=$functioncodes[$idx]";

        my $percent = ( ( $chartdata[$idx] ) / $total ) * 100;
    	my $row;

    	# Categories
        if ( $st == 0 ) {
            $row .= escHtml($category1).$sd;
            $row .= "<a href='#${chartdata[$idx]}' "
                 . "onclick=javascript:showImage('$url')>";
            $row .= "<img src='$tmp_url/" . $chart->FILE_PREFIX
		         . "-color-" . $idx . ".png' border=0>";
            $row .= "</a>";
            $row .= "&nbsp;&nbsp;";
        }

        $row .= escHtml($category1)."\t";

        # Gene Count
        $row .= $chartdata[$idx].$sd
	      . "<a href='#${chartdata[$idx]}' "
	      . "onclick=javascript:showImage('$url')>";
        $row .= $chartdata[$idx]."\t";

        # Percent
        $row .= sprintf( "%.0f%%", $percent )."\t";
        $it->addRow($row);
        $idx++;
    }

    # add the unclassified row:
    my $row;
    $row .= "Unclassified".$sd."&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "&nbsp;&nbsp;";
    $row .= "Unclassified";
    $row .= "\t";

    $row .= $unclassified_count."\t";
    my $unclassified_percent;
    if ( $total ) {
        $unclassified_percent = $unclassified_count / $total * 100;
    }
    $row .= sprintf( "%.0f%%", $unclassified_percent )."\t";
    $it->addRow($row);

    $it->printOuterTable("nopage");
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "print${OG}s", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
		. $chart->FILE_PREFIX . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    # print "<p>\n";
    print "</td></tr>\n";
    print "</table>\n";

    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{
        <script type='text/javascript'>
        YAHOO.namespace("example.container");
        YAHOO.util.Event.addListener(window, "load", initPanel("container"));
        </script>
    };
    print "</div>\n";
}

############################################################################
# printStats - Show the actual statistics display.
#   For one taxon, there is link out to group of genes. More than one,
#   there are no link outs (since the gene list can overwhelm a browser).
#   Also Pfam and ortholog clusters are not shown in cumulative statistics
#   since a fast way of implementing this on the fly is not available,
#   unlike simply adding up counts for genes.
############################################################################
sub printStats {
    my ( $dbh, $taxon_oids_ref, $from ) = @_;

    my @remapped_taxon_oids = WebUtil::remapTaxonOids( $dbh, $taxon_oids_ref );
    $taxon_oids_ref = \@remapped_taxon_oids;

    my $contact_oid = getContactOid();

    my %stats;
    my $nTaxons = @$taxon_oids_ref;
    accumulateStats( $dbh, $taxon_oids_ref, \%stats );

    my $taxon_oid = $taxon_oids_ref->[0];
    my $oneTaxonBaseUrl;
    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    if ( $isTaxonInFile ) {
        $oneTaxonBaseUrl = "$main_cgi?section=MetaDetail";
    }
    else {
        $oneTaxonBaseUrl = "$main_cgi?section=TaxonDetail";
    }

    my $total_gene_count = $stats{total_gene_count};
    my $total_bases      = $stats{total_bases};
    my $indent           = nbsp(4);
    my $rowHiliteColor   = "bisque";

    #print "printStats() " . $stats{total_gc} . "<br/>\n";
    #print "printStats() " . $stats{total_gatc} . "<br/>\n";

    print "<table class='img'  border='0' cellspacing='3' cellpadding='0' >\n";
    print "<th class='img' ></th>\n";

    #print "<th class='subhead'>Number</th>\n";
    #print "<th class='subhead'>% of Total</th>\n";
    print "<th class='img' >Number</th>\n";
    print "<th class='img' >% of Total</th>\n";

    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'><b>DNA, total number of bases</b></th>\n");
    ## --es 04/10/2006 use %s instead of %d to deal with overflow.
    printf( "<td class='img'   align='right'>%s</td>\n", $stats{total_bases} );
    printf( "<td class='img'   align='right'>%.2f%%</td>\n", 100 );
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%sDNA coding number of bases</td>\n", $indent );
    printf( "<td class='img'  align='right'>%s</td>\n",
            $stats{total_coding_bases} );
    printf( "<td class='img'   align='right'>%s</td>\n",
            $stats{total_coding_bases_pc} );
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%sDNA G+C number of bases</td>\n", $indent );
    printf( "<td class='img'   align='right'>%s</td>\n", $stats{total_gc} );

    #my $note1 = "<sup><a href='#ref1'>1</a></sup>";
    my $note1 = "<sup>1</sup>";
    if ( $stats{total_gatc} > 0 ) {
        printf( "<td class='img'   align='right'>%.2f%% $note1</td>\n",
                $stats{total_gc} / $stats{total_bases} * 100 );
    } else {
        printf( "<td class='img'   align='right'>%.2f%% $note1</td>\n", 0 );
    }
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf("</tr>\n");

    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'>DNA scaffolds</th>\n");
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=scaffolds&taxon_oid=$taxon_oid";
    }
    printf( "<td class='img'   align='right'>%s</td>\n",
            taxonLink( $nTaxons, $url, $stats{n_scaffolds} ) );
    printf( "<td class='img'   align='right'>%.2f%%</td>\n", 100 );
    printf("</tr>\n");

    # crispr count
    if ( $nTaxons == 1 ) {
        my $crisprcnt = $stats{crispr_count}; #getCRISPRCount( $dbh, $taxon_oid );
        $crisprcnt = 0 if ( $crisprcnt eq "" );
        my $url = $crisprcnt;

        if (($hideZeroStats eq "No" ) ||
	    ($hideZeroStats eq "Yes" && $crisprcnt > 0)) {
            $url = "$oneTaxonBaseUrl&page=crisprdetails&taxon_oid=$taxon_oid";
            $url = alink( $url, $crisprcnt );
    	    print qq{
    		<tr class='img' >
    		    <td class='img' >&nbsp; &nbsp; &nbsp; &nbsp; CRISPR Count</td>
    		    <td class='img'   align='right'> $url </td>
    		    <td class='img'   align='right'>&nbsp; </td>
    		</tr>
    	    };
        }

    }

    # plasmid count
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        my $pcnt = getPlasmidCount( $dbh, $taxon_oid );
        if ( $pcnt > 0 ) {
            my $url = "$oneTaxonBaseUrl&page=plasmiddetails&taxon_oid=$taxon_oid";
            $url = alink( $url, $pcnt );
            print qq{
        		<tr class='img' >
        		<td class='img' >&nbsp; &nbsp; &nbsp; &nbsp; Plasmid Count</td>
        		<td class='img'   align='right'> $url </td>
        		<td class='img'   align='right'>&nbsp; </td>
        		</tr>
    	    };
        }
    }

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf("</tr>\n");

    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'>Genes total number</th>\n");
    printf( "<td class='img'   align='right'>%d</td>\n",
            $stats{total_gene_count} );
    printf( "<td class='img'   align='right'>%.2f%%</td>\n", 100 );
    printf("</tr>\n");

    my $title = "Protein coding genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url ="$oneTaxonBaseUrl&page=proteinCodingGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "cds_genes", $nTaxons );

    # pseudo genes
    my $title = "Pseudo Genes";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url ="$oneTaxonBaseUrl&page=pseudoGenes&taxon_oid=$taxon_oid";
    }
    #printCountPercRow( 1, $title, $url, \%stats, "pseudo_genes", $nTaxons );

    #
    # Hide rows with zero count based on MyIMG pref
    # -- per Natalia for IMG 3.3 +BSJ 10/15/10
    #
    my $cnt              = $stats{pseudo_genes};
    if (( $hideZeroStats eq "No" ) ||
	( $hideZeroStats eq "Yes" && $cnt > 0 )) {
    	printf("<tr class='img' >\n");
    	printf( "<td class='img' >%s%s</td>\n", $indent, $title );
    	my $total_gene_count = $stats{total_gene_count};
    	#if ( $cnt == 0 || $total_gene_count == 0 ) {
    	#    printf("<td class='img' align='right'>0</td>\n");
    	#    printf("<td class='img' align='right'>0.00%%</td>\n");
    	#} else {
    	    my $link = taxonLink( $nTaxons, $url, $stats{pseudo_genes} );
    	    print "<td class='img' align='right'>$link</td>\n";
    	    my $perc = $stats{pseudo_genes_pc};
    	    printf( "<td class='img' align='right'>%s<sup>2</sup></td>\n", $perc );
    	#}
    	print "</tr>\n";
    }

    my $title = "Uncharacterized Genes";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=uncharGenes&taxon_oid=$taxon_oid";
    }
    my $uncharCnt = $stats{uncharacterized_genes};
    if ( $uncharCnt > 0 ) {
        printf("<tr class='img' >\n");
        printf( "<td class='img' >%s%s</td>\n", $indent, $title );
        my $link = taxonLink( $nTaxons, $url, $stats{uncharacterized_genes} );
        printf("<td class='img' align='right'>$link</td>\n");
        my $perc = $stats{uncharacterized_genes_pc};
        printf( "<td class='img' align='right'>%s<sup>4</sup></td>\n", $perc );
        printf "</tr>\n";
    }

    my $title = "RNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "rna_genes", $nTaxons );

    my $title = "rRNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA";
    }
    printCountPercRow( 2, $title, $url, \%stats, "rrna_genes", $nTaxons );

    my $title = "5S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=5S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna5s_genes", $nTaxons );

    my $title = "16S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=16S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna16s_genes", $nTaxons );

    my $title = "18S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=18S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna18s_genes", $nTaxons );

    my $title = "23S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=23S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna23s_genes", $nTaxons );

    my $title = "28S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=28S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna28s_genes", $nTaxons );

    my $title = "tRNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=tRNA";
    }
    printCountPercRow( 2, $title, $url, \%stats, "trna_genes", $nTaxons );

    my $title = "Other RNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=rnas&taxon_oid=$taxon_oid&locus_type=xRNA";
    }
    printCountPercRow( 2, $title, $url, \%stats, "other_rna_genes", $nTaxons );

    my $title = "Protein coding genes with function prediction";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=withFunc&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_w_func_pred",
                       $nTaxons );

#    if ($img_lite) {

    my $noFunc     = $stats{cds_genes} - $stats{genes_w_func_pred};
	if (($hideZeroStats eq "No") ||
	    ($hideZeroStats eq "Yes" && $noFunc > 0)) {
	    printf("<tr class='img' >\n");
	    my $indent2 = nbsp(8);
	    printf( "<td class='img' >%swithout function prediction</td>\n",
		    $indent2 );
	    my $noFunc     = $stats{cds_genes} - $stats{genes_w_func_pred};
	    my $noFuncPerc = 0;
	    $noFuncPerc = 100 * $noFunc / $stats{total_gene_count}
	      if $stats{total_gene_count} > 0;

        my $link;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            my $url = "$oneTaxonBaseUrl&page=withoutFunc&taxon_oid=$taxon_oid";
            $link = alink( $url, $noFunc );
        }
        else {
            $link = $noFunc;
        }
	    $link = 0  if $noFunc == 0;
	    printf( "<td class='img' align='right'>" . $link . "</td>\n" );
	    printf( "<td class='img' align='right'>%.2f%%</td>\n", $noFuncPerc );
	    printf("</tr>\n");
	}


    if ( !$img_lite ) {


        if ($img_internal || $include_ht_stats > 1 ) {
          my $title = "Genes horizontally transferred";
          my $url;
          if ( $nTaxons == 1 && !$isTaxonInFile ) {
              $url = "$oneTaxonBaseUrl&page=horTransferred&taxon_oid=$taxon_oid";
          }
          printCountPercRow( 1, $title, $url, \%stats, "genes_hor_transfer",
              $nTaxons );
        }
    }

    # swissprot
    my $title = "Protein coding genes connected to SwissProt Protein Product";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=swissprot&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_sp", $nTaxons );

    # no swissprot
    my $title = "not connected to SwissProt Protein Product";
    my $url;
    $url = "$oneTaxonBaseUrl&page=noswissprot&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 && !$isTaxonInFile );
    printCountPercRow( 2, $title, $url, \%stats, "genes_not_in_sp", $nTaxons );


    # enzymes
    my $title = "Protein coding genes with enzymes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=enzymes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_enzymes", $nTaxons );


    # genes w/o enzymes, w/ ko
    my $title = "w/o enzymes but with candidate KO based enzymes";
    my $url;
    $url   =
        "$main_cgi?section=MissingGenes"
        . "&page=taxonGenesWithKO&taxon_oid=$taxon_oid"
        if ( $nTaxons == 1 && !$isTaxonInFile );
    printCountPercRow( 1, $title, $url, \%stats,
        "genes_wo_ez_w_ko", $nTaxons, 0 );

    # tc
    my $title = "Protein coding genes connected to Transporter Classification";
    my $url;
    $url = "$oneTaxonBaseUrl&page=tc&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 && !$isTaxonInFile );
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_tc", $nTaxons );

    # kegg
    my $title = "Protein coding genes connected to KEGG pathways";
    $title .= "<sup>3</sup>" if ($chart_exe);

    #$title .= "<sup>3</sup>"  if ( $nTaxons == 1 && $chart_exe);

    my $url;
    if ( $nTaxons == 1 && $from ne "compareGenomes" ) {
        $url = "$oneTaxonBaseUrl&page=kegg&cat=cat&taxon_oid=$taxon_oid";
    } else {
        $url =
            "$main_cgi?section=CompareGenomes"
          . "&page=taxonBreakdownStats"
          . "&statTableName=dt_kegg_stats&initial=1";
    }
    printCountPercRow( 1, $title, $url, \%stats,
		       "genes_in_kegg", $nTaxons, 0 );

    # not in kegg
    my $title = "not connected to KEGG pathways";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=noKegg&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_not_in_kegg",
                       $nTaxons );

    # ko for 2.8
    my $title = "Protein coding genes connected to KEGG Orthology (KO)";
    my $url;
    $url = "$oneTaxonBaseUrl&page=ko&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 );
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_ko", $nTaxons );

    # ko not in
    my $title = "not connected to KEGG Orthology (KO)";
    my $url;
    $url = "$oneTaxonBaseUrl&page=noKo&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 && !$isTaxonInFile );
    printCountPercRow( 2, $title, $url, \%stats, "genes_not_in_ko", $nTaxons );

    # metacyc for 2.7
    my $title = "Protein coding genes connected to MetaCyc pathways";
    my $url;
    $url = "$oneTaxonBaseUrl&page=metacyc&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 );
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_metacyc", $nTaxons );

    # metacyc not in
    my $title = "not connected to MetaCyc pathways";
    my $url;
    $url = "$oneTaxonBaseUrl&page=noMetacyc&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 && ! $isTaxonInFile );
    printCountPercRow( 2, $title, $url, \%stats, "genes_not_in_metacyc",
                       $nTaxons );

    # genes with cogs
    my $title = "Protein coding genes with COGs";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 && $from ne "compareGenomes" ) {
        $url = "$oneTaxonBaseUrl&page=cogs&cat=cat&taxon_oid=$taxon_oid";
    } else {
        $url =
            "$main_cgi?section=CompareGenomes"
	    . "&page=taxonBreakdownStats"
	    . "&statTableName=dt_cog_stats&initial=1";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_cog", $nTaxons, 0 );

    # genes with kogs
    my $title = "with KOGs";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 && $from ne "compareGenomes" ) {
        $url = "$oneTaxonBaseUrl&page=kogs&cat=cat&taxon_oid=$taxon_oid";
    } else {
        $url =
            "$main_cgi?section=CompareGenomes"
	    . "&page=taxonBreakdownStats"
	    . "&statTableName=dt_kog_stats&initial=1";
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_in_kog", $nTaxons, 0 );

    my $title = "with Pfam";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=pfam&cat=cat&taxon_oid=$taxon_oid";
    } else {
    	GenomeCart::insertToGtt($dbh);
        my $sql = "select count(id) from gtt_taxon_oid";
        my $cur = execSql( $dbh, $sql, $verbose );
        my $sessionCount = $cur->fetchrow();
        $cur->finish();

        my $max = 80;
        if ( $sessionCount <= $max && $sessionCount > 0 ) {
            $url =
                "$main_cgi?section=CompareGenomes"
              . "&page=taxonBreakdownStats"
              . "&statTableName=dt_pfam_stats&initial=1";
        }
    }
    printCountPercRow( 2, $title, $url, \%stats,
		       "genes_in_pfam", $nTaxons, 0 );

    my $title = "with TIGRfam";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$oneTaxonBaseUrl&page=tigrfam&cat=cat&taxon_oid=$taxon_oid";
    } else {
    	GenomeCart::insertToGtt($dbh);
        my $sql = "select count(id) from gtt_taxon_oid";
        my $cur = execSql( $dbh, $sql, $verbose );
        my $sessionCount = $cur->fetchrow();
        $cur->finish();

        my $max = 80;
        if ( $sessionCount <= $max && $sessionCount > 0 ) {
            $url =
                "$main_cgi?section=CompareGenomes"
              . "&page=taxonBreakdownStats"
              . "&statTableName=dt_tigrfam_stats&initial=1";
        }
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_in_tigrfam",
                       $nTaxons, 0 );

    if ($img_internal) {
        my $title = "with Genome Property";
        my $url;
        if ( $nTaxons == 1 ) {
            $url = "$oneTaxonBaseUrl&page=genomeProp&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_genome_prop",
                           $nTaxons );
    }

    if ($enable_interpro && $stats{"genes_in_ipr"} > 0 ) {

        my $title = "with InterPro";
        my $url;
        if ( $nTaxons == 1 ) {
            $url = "$oneTaxonBaseUrl&page=ipr&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_ipr", $nTaxons );
    }

    if ($img_internal) {
        # eggnog
        my $title = "with EggNOG";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            $url =
              "$main_cgi?section=EggNog&page=genelist&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_eggnog", $nTaxons );
    }


    if ($include_img_terms) {
        my $title = "with IMG Terms";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            $url = "$oneTaxonBaseUrl&page=imgTerms&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_img_terms",
                           $nTaxons );

        # add new row here for er - ken
        if ( $img_er && $img_lite && $img_internal && !$include_metagenomes ) {
            my $count = getSimilarityCount( $dbh, $taxon_oid );
            if ( $count > 0 ) {
                my $total = $stats{total_gene_count};

                my $title = "Genes w/o IMG Terms w/ Similarity";
                my $url = "$oneTaxonBaseUrl&page=imgTermsSimilarity&taxon_oid=$taxon_oid";
                my $indent = nbsp(4);
                print "<tr class='img' >\n";
                print "<td class='img' >$indent" . escHtml($title) . "</td>\n";
                print "<td class='img'   align='right'> "
                  . alink( $url, $count )
                  . " </td>\n";
                my $pc = ( $count / $total ) * 100;
                $pc = sprintf( "%.2f", $pc );
                print "<td class='img'   align='right'> $pc%</td>\n";
                print "</tr>\n";
            }
        }

        my $title = "with IMG Pathways";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            $url = "$oneTaxonBaseUrl&page=imgPways&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_img_pways",
                           $nTaxons );

        my $title = "with IMG Parts List";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            $url = "$oneTaxonBaseUrl&page=imgPlist&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_parts_list",
                           $nTaxons );
    }

    if ($show_myimg_login) {
        my $title = "with MyIMG Annotation";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            my $val = $stats{"genes_in_myimg"};
            $url = "$oneTaxonBaseUrl&page=myIMGGenes&taxon_oid=$taxon_oid&gcnt=$val";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_myimg",
                           $nTaxons );
    }

    if ( !$img_lite ) {
        my $title = "Protein coding genes in ortholog clusters";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            $url = "$oneTaxonBaseUrl&page=orthologGroups&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 1, $title, $url, \%stats, "genes_in_orthologs",
                           $nTaxons );
    }
    if ( $img_internal ) {
        my $title = "Protein coding genes in IMG clusters";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            $url = "$oneTaxonBaseUrl&page=imgClusters&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 1, $title, $url, \%stats, "genes_in_img_clusters",
                           $nTaxons );
    }

    my $title;
    if ($include_metagenomes) {
        $title = "in internal clusters";
    } else {
        $title = "in paralog clusters";
    }
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=paralogGroups&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_in_paralogs",
                       $nTaxons );


    if ( $nTaxons == 1 ) {
        # TODO Cassette stats here
        if ( $enable_cassette ) {
            my $total   = $stats{total_gene_count};
            my $cgcount =
              $stats{genes_in_cassettes}; #getCassetteGeneCount( $dbh, $taxon_oid );

            my $pc = ( $cgcount / $total ) * 100 if ( $total != 0 );
            $pc = 0 if ( $total == 0 );
            $pc = sprintf( "%.2f", $pc );

            my $ccount = $stats{total_cassettes};

    	    #
    	    # Hide rows with zero count based on MyIMG pref
    	    # -- per Natalia for IMG 3.3 +BSJ 10/15/10
    	    #

    	    if (($hideZeroStats eq "No") ||
    		($hideZeroStats eq "Yes" && $cgcount > 0)) {
        		my $indent = nbsp(8);

        		print "<tr class='img'>\n";
        		print "<td class='img'> $indent in Chromosomal Cassette</th>\n";
        		my $url = "$oneTaxonBaseUrl&page=geneCassette&taxon_oid=$taxon_oid";
        		$url = alink( $url, $cgcount );
        		$url = 0 if $cgcount < 1;
        		print "<td class='img'   align='right'> $url </td>\n";
        		print "<td class='img'   align='right'> $pc% </td>\n";
        		print "</tr>\n";
    	    }

    	    #
    	    # Hide rows with zero count based on MyIMG pref
    	    # -- per Natalia for IMG 3.3 +BSJ 10/15/10
    	    #

    	    if (($hideZeroStats eq "No")
    	    || ($hideZeroStats eq "Yes" && $ccount > 0)) {
        		my $indent = nbsp(4);

        		print "<tr class='img'>\n";
        		print "<td class='img'> $indent Chromosomal Cassettes</th>\n";
        		my $url = "$main_cgi?section=GeneCassette"
        		        . "&page=occurrence&taxon_oid=$taxon_oid";
        		$url = alink( $url, $ccount );
        		$url = 0 if $ccount < 1;
        		print "<td class='img'   align='right'> $url </td>\n";
        		print "<td class='img'   align='right'>-</td>\n";
        		print "</tr>\n";
    	    }
        }

        if ( $enable_biocluster) {
            my $total    = $stats{total_biosynthetic};
            my $gbcnt    = $stats{genes_in_biosynthetic};
            my $gbcnt_pc = $stats{genes_in_biosynthetic_pc};

            if ( ($hideZeroStats eq "No")
            || ($hideZeroStats eq "Yes" && $total > 0) ) {
                my $indent = nbsp(4);
                print "<tr class='img'>\n";
                print "<td class='img'> $indent Biosynthetic Clusters</th>\n";
                my $url = "$main_cgi?section=BiosyntheticDetail"
                        . "&page=biosynthetic_clusters&taxon_oid=$taxon_oid";
                $url = alink( $url, $total );
                $url = 0 if $total < 1;
                print "<td class='img' align='right'> $url </td>\n";
                print "<td class='img' align='right'>-</td>\n";
                print "</tr>\n";

                my $indent = nbsp(8);
                print "<tr class='img'>\n";
                print "<td class='img'> $indent Genes in Biosynthetic Clusters</th>\n";
                my $url = "$main_cgi?section=BiosyntheticDetail"
                        . "&page=biosynthetic_genes&taxon_oid=$taxon_oid";
                $url = alink( $url, $gbcnt );
                $url = 0 if $gbcnt < 1;
                print "<td class='img' align='right'> $url </td>\n";
                print "<td class='img' align='right'> ${gbcnt_pc}% </td>\n";
                print "</tr>\n";
            }
        }
    }

    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    if ($show_myimg_login) {
        ### My Missing Genes
        my %mygene_stats;
        my $sql2 = qq{
            select count(*)
            from mygene g
            where g.taxon = ?
            and g.modified_by = ?
            $imgClause
        };
        my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid, $contact_oid );
        my ($cnt2) = $cur2->fetchrow();
        $cur2->finish();

	#
	# Hide rows with zero count based on MyIMG pref
	# -- per Natalia for IMG 3.3 +BSJ 10/15/10
	#

	if (($hideZeroStats eq "No") ||
	    ($hideZeroStats eq "Yes" && $cnt2 > 0)) {
	    $title = "My Missing Genes";
	    my $url =
		"$main_cgi?section=MyIMG"
		. "&page=viewMyTaxonMissingGenes&taxon_oid=$taxon_oid";
	    printf("<tr class='img' bgcolor='lightgray'>\n");
	    printf( "<td class='img' >%s$title</td>\n", nbsp(4) );
	    my $link = alink( $url, $cnt2 );
	    $link = 0     if $cnt2 == 0;
	    $link = $cnt2 if $nTaxons > 1;
	    print "<td class='img'  align='right'>" . $link . "</td>\n";
	    printf("<td class='img'   align='right'>-</td>\n");
	    printf("</tr>\n");
	}
    }

    ## public missing genes should be visible in all IMG systems per Nikos
    my $sql2 = qq{
            select count(*)
            from mygene g
            where g.taxon = ?
            and g.is_public = 'Yes'
            $imgClause
        };
    my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid );
    my ($cnt3) = $cur2->fetchrow();
    $cur2->finish();

    if (($hideZeroStats eq "No") ||
	($hideZeroStats eq "Yes" && $cnt3 > 0)) {
	$title = "All Public Missing Genes";
	my $url =
	    "$main_cgi?section=MyIMG"
	    . "&page=viewPublicTaxonMissingGenes&taxon_oid=$taxon_oid";
	printf("<tr class='img' bgcolor='lightgray'>\n");
	printf( "<td class='img' >%s$title</td>\n", nbsp(4) );
	my $link = alink( $url, $cnt3 );
	$link = 0     if $cnt3 == 0;
	$link = $cnt3 if $nTaxons > 1;
	print "<td class='img'  align='right'>" . $link . "</td>\n";
	printf("<td class='img'   align='right'>-</td>\n");
	printf("</tr>\n");
    }

    my $title = "Fused Protein coding genes";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=fusedGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "fused_genes", $nTaxons );

    if ( !$img_lite ) {
        my $title = "as fusion components";
        my $url;
        if ( $nTaxons == 1 && !$isTaxonInFile ) {
            $url = "$oneTaxonBaseUrl&page=fusionComponents&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "fusion_components",
                           $nTaxons );
    }

    my $title = "Protein coding genes coding signal peptides";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=signalpGeneList&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_signalp", $nTaxons );

    my $title = "Protein coding genes coding transmembrane proteins";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=transmembraneGeneList&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_transmembrane",
                       $nTaxons );

    my $title = "Obsolete Protein coding genes";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=obsoleteGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_obsolete", $nTaxons );

    my $title = "Revised Genes";
    my $url;
    if ( $nTaxons == 1 && !$isTaxonInFile ) {
        $url = "$oneTaxonBaseUrl&page=revisedGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_revised", $nTaxons );

    ##### proteomic data
    my $proteomics_data = $env->{proteomics};
    if ( $nTaxons == 1 && $proteomics_data && !$isTaxonInFile ) {
        my $title = "Genes with Proteomic data";
        my $imgClause = WebUtil::imgClauseNoTaxon('pig.genome');
        my $sql = qq{
            select count( distinct pig.gene )
            from ms_protein_img_genes pig
            where pig.genome = ?
            $imgClause
        };

        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my $count = $cur->fetchrow();
        $cur->finish();

    	#
    	# Hide rows with zero count based on MyIMG pref
    	# -- per Natalia for IMG 3.3 +BSJ 10/15/10
    	#

    	if (($hideZeroStats eq "No") ||
    	    ($hideZeroStats eq "Yes" && $count > 0)) {
    	    my $url = "$oneTaxonBaseUrl&page=genomeProteomics&taxon_oid=$taxon_oid";

    	    my $indent = nbsp(4);
    	    print "<tr class='img'>\n";
    	    print "<td class='img'> $indent $title</td>\n";
    	    if ($count == 0) {
        		$url = 0;
    	    } else {
        		$url = alink( $url, $count );
    	    }
    	    print "<td class='img' align='right'> $url </td>\n";
    	    print "<td class='img' align='right'> &nbsp; </td>\n";
    	    print "</tr>\n";
    	}
    }
    ##### end of proteomic data

    # rnaseq data:
    my $rnaseq_data = $env->{rnaseq};
    if ( $nTaxons == 1 && $rnaseq_data && !$isTaxonInFile ) {
	use RNAStudies;
        my $title = "Genes with RNASeq data";
        my $imgClause = WebUtil::imgClauseNoTaxon('dts.reference_taxon_oid');
	my $datasetClause = RNAStudies::datasetClause("dts");
        my $sql = qq{
            select count( distinct es.IMG_gene_oid )
            from rnaseq_expression es, rnaseq_dataset dts
            where dts.reference_taxon_oid = ?
            and dts.dataset_oid = es.dataset_oid
            $imgClause
            $datasetClause
        };

        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my $count = $cur->fetchrow();
        $cur->finish();

        if (  $hideZeroStats eq "No" ||
	     ($hideZeroStats eq "Yes" && $count > 0) ) {
            my $url = "$oneTaxonBaseUrl&page=genomeRNASeq&taxon_oid=$taxon_oid";

            my $indent = nbsp(4);
            print "<tr class='img'>\n";
            print "<td class='img'> $indent $title</td>\n";
            if ($count == 0) {
                $url = 0;
            } else {
                $url = alink( $url, $count );
            }
            print "<td class='img' align='right'> $url </td>\n";
            print "<td class='img' align='right'> &nbsp; </td>\n";
            print "</tr>\n";
        }
    }
    ##### end of rnaseq data

    #### SNP
    if ( $nTaxons == 1 && $snp_enabled && !$isTaxonInFile ) {
        my $title = "Genes with SNP";

    	my $contact_oid = getContactOid();
    	my $super_user = 'No';
    	if ( $contact_oid ) {
    	    $super_user  = getSuperUser();
    	}
        my $imgClause = WebUtil::imgClauseNoTaxon('snp.taxon');
        my $sql = qq{
            select count( distinct snp.gene_oid )
            from gene_snp snp
            where snp.taxon = $taxon_oid
            $imgClause
    	};

    	if ( ! $contact_oid ) {
    	    $sql .= " and snp.experiment in (select exp_oid from snp_experiment where is_public = 'Yes')";
    	}
    	elsif ( $super_user ne 'Yes' ) {
    	    $sql .= " and (snp.experiment in (select exp_oid from snp_experiment where is_public = 'Yes') or snp.experiment in (select snp_exp_permissions from contact_snp_exp_permissions where contact_oid = $contact_oid))";
    	}

        my $cur = execSql( $dbh, $sql, $verbose );
        my $snp_count = $cur->fetchrow();
        $cur->finish();

    	my $total   = $stats{total_gene_count};
    	my $pc = ( $snp_count / $total ) * 100 if ( $total != 0 );
    	$pc = 0 if ( $total == 0 );
    	$pc = sprintf( "%.2f", $pc );

    	#
    	# Hide rows with zero count based on MyIMG pref
    	# -- per Natalia for IMG 3.3 +BSJ 10/15/10
    	#

    	if (($hideZeroStats eq "No") ||
    	    ($hideZeroStats eq "Yes" && $snp_count > 0)) {
    	    my $url = "$oneTaxonBaseUrl&page=snpGenes&taxon_oid=$taxon_oid";

    	    my $indent = nbsp(4);
    	    print "<tr class='img'>\n";
    	    print "<td class='img'> $indent $title</td>\n";
    	    if ($snp_count == 0) {
        		$url = 0;
    	    } else {
        		$url = alink( $url, $snp_count );
    	    }
    	    print "<td class='img' align='right'> $url </td>\n";
    	    print "<td class='img' align='right'> $pc% </td>\n";
    	    print "</tr>\n";
    	}
    }
    ##### end of SNP


    ## Can only do single taxon at a time for now.
    if ( $nTaxons == 1 && !$isTaxonInFile ) {

    	# essential gene?
    	my $total   = $stats{total_gene_count};
    	if ( $essential_gene ) {
    	    require EssentialGene;
    	    EssentialGene::printTaxonEssentialGeneCount($taxon_oid, $total);
    	}

        #
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>COG clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
            $stats{cog_clusters} );
        if ( $stats{cog_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{cog_clusters} / $stats{cog_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("</tr>\n");

        #
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>KOG clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
                $stats{kog_clusters} );
        if ( $stats{kog_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{kog_clusters} / $stats{kog_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("</tr>\n");

        #
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>Pfam clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
                $stats{pfam_clusters} );
        if ( $stats{pfam_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{pfam_clusters} / $stats{pfam_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("</tr>\n");

        #
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>TIGRfam clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
                $stats{tigrfam_clusters} );
        if ( $stats{tigrfam_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{tigrfam_clusters} / $stats{tigrfam_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("</tr>\n");
        if ( !$img_lite ) {
            printf("<tr class='highlight'>\n");
            printf("<th class='subhead'>Paralogous groups</th>\n");
            printf( "<td class='img'   align='right'>%s</td>\n",
                    $stats{paralog_groups} );
            printf("<td class='img'   align='right'>100.00%%</td>\n");
            printf("</tr>\n");
        }

        #
        if ( !$img_lite ) {
            printf("<tr class='highlight'>\n");
            printf("<th class='subhead'>Orthologous groups</th>\n");
            my $url;
            if ( $nTaxons == 1 ) {
                $url = "$oneTaxonBaseUrl&page=orthologGroups&taxon_oid=$taxon_oid";
            }
            printf( "<td class='img'   align='right'>%s</td>\n",
                    $stats{ortholog_groups} );

            #taxonLink( $nTaxons, $url, $stats{  ortholog_groups } ) );
            if ( $stats{ortholog_groups_total} > 0 ) {
                printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                        $stats{ortholog_groups} /
                          $stats{ortholog_groups_total} * 100 );
            } else {
                printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
            }
            printf("</tr>\n");
        }

        # ANI
#        if($enable_ani && $nTaxons == 1) {
#            require ANI;
#            my $specisCnt = ANI::getGenomesInSpeciesCnt($dbh, $taxon_oid);
#            my $anicnt = ANI::getPresentInCliquesCnt($dbh, $taxon_oid);
#
#            print qq{
#                <tr class='highlight'>
#                <th class='subhead'>Average Nucleotide Identity (ANI)</th>
#                <th class='subhead'></th>
#                <th class='subhead'></th>
#                </tr>
#            };
#
#            my $indent = nbsp(4);
#            print "<tr class='img'>\n";
#            print "<td class='img'> $indent Genomes of this Species</th>\n";
#            print "<td class='img' align='right'>$specisCnt</td>\n";
#            print "<td class='img' align='right'>-</td>\n";
#            print "</tr>\n";
#
#            print "<tr class='img'>\n";
#            print "<td class='img'> $indent Present in Cliques</th>\n";
#            print "<td class='img' align='right'>$anicnt</td>\n";
#            print "<td class='img' align='right'>-</td>\n";
#            print "</tr>\n";
#
#        }
    }

    print "</table>\n";

    print "<br/>\n";
    print "<b>Notes</b>:<br/>\n";
    print "<p>\n";
    print "<a name='ref1' id='ref1'></a>1</sup> - ";
    print "GC percentage shown as count of G's and C's divided ";
    print "by the total number of bases.<br/> ";
    print nbsp(3);
    print "The total number of bases is not necessarily synonymous ";
    print "with a total number of G's, C's, A's, and T's.";
    print "<br/>\n";
    print "<a name='ref2' id='ref2'></a>2</sup> - ";
    print "Pseudogenes may also be counted as protein coding "
      . "or RNA genes, so is not additive under total gene count.";
    print "<br/>\n";

    if ($chart_exe) {
        print "<a name='ref3' id='ref3'></a>3</sup> - ";
        print "Graphical view available." . "<br/>\n";
    }

    if ( $uncharCnt > 0 ) {
        print "<a name='ref4' id='ref4'></a>4</sup> - ";
        print "Uncharacterized genes are genes that are not classified ";
        print "as CDS, a type of RNA, or pseudogene,<br/>\n";
        print nbsp(3);
        print "but as 'unkonwn' or ";
        print "'other' by the source provider.<br/>\n";
    }
    print "</p>\n";

    # request recomputation with missing gene
    my $super_user  = getSuperUser();
    if ( $super_user eq 'Yes' && $cnt3 > 0 ) {
    	print "<h3>Request to Add Public Missing Genes to Genome</h3>\n";
    	print hiddenVar("taxon_oid", $taxon_oid);

    	my $sql = "select tur.taxon_oid, c.name, tur.request_date, " .
    	    "tur.refresh_date from taxon_update_request tur, contact c " .
    	    "where tur.taxon_oid = ? and tur.requested_by = c.contact_oid";
            my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
            my ($t_oid2, $c_name, $request_date, $refresh_date)
    	    = $cur->fetchrow();
        $cur->finish();
    	if ( $t_oid2 && $request_date ) {
    	    if ( $refresh_date ) {
        		print "<p>Last update request by $c_name (" . $request_date . ").\n";
        		print "<p>Last modification: $refresh_date\n";
    	    }
    	    else {
        		print "<p>Pending update request by $c_name (" . $request_date . ").\n";
    	    }
    	    print "<br/>\n";
    	}
    	else {
    	    print "<p>No pending request.<br/>\n";
    	}

    	print "<p>\n";
        my $name = "_section_CompareGenomes_requestTaxonRefresh";
        print "<input type='submit' class='lgdefbutton' "
        	. "name='_section_CompareGenomes_requestTaxonRefresh' "
        	. "value='Submit Request' />";

#        print main::submit(
#                        -name  => $name,
#                        -value => "Submit Request",
#                        -class => 'lgdefbutton'
#                       );
    }
}

sub addTaxonRefreshRequest {
    printMainForm();
    my $taxon_oid = param('taxon_oid');
    if ( ! $taxon_oid ) {
	webError("No genome is selected.");
	return;
    }

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    if ( ! $contact_oid || $super_user ne 'Yes' ) {
	webError("You cannot request update to this genome.");
	return;
    }

    my $dbh = dbLogin();
    my $sql = "select tur.taxon_oid, c.username, tur.request_date, " .
	"tur.refresh_date from taxon_update_request tur, contact c " .
	"where tur.taxon_oid = ? and tur.requested_by = c.contact_oid";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($t_oid2, $c_name, $request_date, $refresh_date)
	= $cur->fetchrow();
    $cur->finish();
    #$dbh->disconnect();

    if ( $t_oid2 ) {
	$sql = "update taxon_update_request set requested_by = $contact_oid, " .
	    "request_date = sysdate where taxon_oid = $taxon_oid";
    }
    else {
	$sql = "insert into taxon_update_request (taxon_oid, requested_by, " .
	    "request_date) values ($taxon_oid, $contact_oid, sysdate)";
    }
    my @sqlList = ( $sql );

    my $err = DataEntryUtil::db_sqlTrans( \@sqlList );
    if ( $err ) {
	webError($err);
    }
    else {
	print "<h3>Update request has been submitted.</h3>\n";
	my $url =
	    "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
	print "<p>" . alink( $url, "Return to genome detail page." );
	print end_form();
    }
}


############################################################################
# printCountPercRow - Print out stats row with counts and percentage.
#   Inputs:
#     indentSize - indentation size
#     title - title / label of attribute
#     url - link out url
#     stats_ref - stats reference data
#     key - key to stats_ref
#     nTaxons - no. of taxons
#     $escHTML - default is 1, but if 0 the title is not escaped! - ken
############################################################################
sub printCountPercRow {
    my (
         $indentSize, $title,     $url,
         $stats_ref,  $key,       $nTaxons,
         $escHTML,    $reads_key, $reads_stats_ref
      )
      = @_;

    #
    # Hide rows with zero count based on MyIMG pref
    # -- per Natalia for IMG 3.3 +BSJ 10/15/10
    #

    return if ($stats_ref->{$key} < 1 && $hideZeroStats eq "Yes");

    my $indent = nbsp(4);
    printf("<tr class='img' >\n");

    if ( $escHTML == 0 ) {
        printf(
                "<td class='img' >%s" . $title . "</td>\n",
                $indent x $indentSize
        );
    } else {
        printf(
                "<td class='img' >%s" . escHtml($title) . "</td>\n",
                $indent x $indentSize
        );
    }
    printf( "<td class='img'   align='right'>%s</td>\n",
            taxonLink( $nTaxons, $url, $stats_ref->{$key} ) );
    my $pc = $stats_ref->{"${key}_pc"};
    $pc = "0.00%" if $pc eq "";
    printf( "<td class='img'   align='right'>%s</td>\n", $pc );
    if ( $nTaxons == 1 && $reads_stats_ref ) {
        my $reads_pc = $reads_stats_ref->{"${reads_key}_pc"};
        $reads_pc = "0.00%" if $reads_pc eq "";
        printf( "<td class='img' align='right'>%s</td>\n",
                $reads_stats_ref->{$reads_key} );
        printf( "<td class='img' align='right'>%s</td>\n", $reads_pc );
    }
    printf("</tr>\n");
}

############################################################################
# accumulateStats - Add up counts for genes for cumulative statistics.
#   Inputs:
#      dbh - database handle
#      taxon_oids_ref - selected taxons
#   Outputs:
#      stats_ref - stats reference, to be filled with numbers
############################################################################
sub accumulateStats {
    my ( $dbh, $taxon_oids_ref, $stats_ref ) = @_;

    my $taxon_oid_str = join( ',', @$taxon_oids_ref );
    my $rclause       = urClause("dts.taxon_oid");
    my $selClause     = txsClause("dts.taxon_oid", $dbh);
    my $imgClause = WebUtil::imgClauseNoTaxon('dts.taxon_oid');
    my @binds = ();
    if ( scalar(@$taxon_oids_ref) == 1 ) {
        $rclause   = "";
        $selClause = "and dts.taxon_oid = ? " ;
        push(@binds, $taxon_oids_ref->[0]);
    }

    my $cassetteCol = "0,0,0,";
    if ( $enable_cassette ) {
        $cassetteCol = qq{
              sum( genes_in_cassettes ),
              sum( genes_in_cassettes_pc ),
              sum( total_cassettes ),
        }
    }

    my $bioCol = qq{
              sum( genes_in_biosynthetic ),
              sum( genes_in_biosynthetic_pc ),
              sum( total_biosynthetic ),
    };

    my $metacycCol = qq{
              sum( genes_in_metacyc ),
              sum( genes_not_in_metacyc ),
    };

    my $sql = qq{
       select sum( total_gene_count ),
              sum( cds_genes ),
              sum( rna_genes ),
              sum( rrna_genes ),
              sum( rrna5s_genes ),
              sum( rrna16s_genes ),
              sum( rrna18s_genes ),
              sum( rrna23s_genes ),
              sum( rrna28s_genes ),
              sum( trna_genes ),
              sum( other_rna_genes ),
              sum( genes_w_func_pred ),
              sum( genes_wo_func_pred_sim ),
              sum( genes_wo_func_pred_no_sim ),
              sum( genes_hor_transfer ),
              sum( pseudo_genes ),
              sum( uncharacterized_genes ),
              sum( dubious_genes ),

              sum( genes_in_enzymes ),
              sum( genes_in_tc ),
              sum( genes_in_kegg ),
              sum( genes_not_in_kegg ),
              sum( genes_in_ko ),
              sum( genes_not_in_ko ),
              sum( genes_wo_ez_w_ko ),
              sum( genes_in_orthologs ),
              sum( genes_in_img_clusters ),
              sum( genes_in_paralogs ),
              sum( fused_genes ),
              sum( fusion_components ),

              $cassetteCol
              $bioCol
              $metacycCol

              sum( genes_in_sp ),
              sum( genes_not_in_sp ),



              sum( genes_in_cog ),
              sum( genes_in_kog ),
              sum( genes_in_pfam ),
              sum( genes_in_tigrfam ),
              sum( genes_in_genome_prop ),
              sum( genes_signalp ),
              sum( genes_transmembrane ),
              sum(genes_in_ipr),
              sum( genes_in_pos_cluster ),
              sum( pfam_clusters ),
              sum( cog_clusters ),
              sum( kog_clusters ),
              sum( tigrfam_clusters ),
              sum( ortholog_groups ),
              sum( paralog_groups ),
              sum( n_scaffolds ),
              sum( crispr_count ),
              sum( total_gc ),
              sum( total_gatc ),
              sum( total_bases ),
              sum( total_coding_bases ),
              sum( genes_in_img_terms ),
              sum( genes_in_img_pways ),
              sum( genes_in_parts_list ),
              sum( genes_in_myimg ),
              sum( genes_obsolete ),
              sum( genes_revised ),
              sum( genes_in_eggnog )
       from taxon_stats dts
       where 1 = 1
       $selClause
       $rclause
       $imgClause
    };
    #print "accumulateStats() sql: $sql<br/>\n";
    #print "accumulateStats() binds: @binds<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    (
       $stats_ref->{total_gene_count},
       $stats_ref->{cds_genes},
       $stats_ref->{rna_genes},
       $stats_ref->{rrna_genes},
       $stats_ref->{rrna5s_genes},
       $stats_ref->{rrna16s_genes},
       $stats_ref->{rrna18s_genes},
       $stats_ref->{rrna23s_genes},
       $stats_ref->{rrna28s_genes},
       $stats_ref->{trna_genes},
       $stats_ref->{other_rna_genes},
       $stats_ref->{genes_w_func_pred},
       $stats_ref->{genes_wo_func_pred_sim},
       $stats_ref->{genes_wo_func_pred_no_sim},
       $stats_ref->{genes_hor_transfer},
       $stats_ref->{pseudo_genes},
       $stats_ref->{uncharacterized_genes},
       $stats_ref->{dubious_genes},

       $stats_ref->{genes_in_enzymes},
       $stats_ref->{genes_in_tc},
       $stats_ref->{genes_in_kegg},
       $stats_ref->{genes_not_in_kegg},
       $stats_ref->{genes_in_ko},
       $stats_ref->{genes_not_in_ko},
       $stats_ref->{genes_wo_ez_w_ko},
       $stats_ref->{genes_in_orthologs},
       $stats_ref->{genes_in_img_clusters},
       $stats_ref->{genes_in_paralogs},
       $stats_ref->{fused_genes},
       $stats_ref->{fusion_components},

       # TODO - cassette - ken
       $stats_ref->{genes_in_cassettes},
       $stats_ref->{genes_in_cassettes_pc},
       $stats_ref->{total_cassettes},

       $stats_ref->{genes_in_biosynthetic},
       $stats_ref->{genes_in_biosynthetic_pc},
       $stats_ref->{total_biosynthetic},

       # metagcyc
       $stats_ref->{genes_in_metacyc},
       $stats_ref->{genes_not_in_metacyc},

       $stats_ref->{genes_in_sp},
       $stats_ref->{genes_not_in_sp},

#       $stats_ref->{genes_in_seed},
#       $stats_ref->{genes_not_in_seed},

       $stats_ref->{genes_in_cog},
       $stats_ref->{genes_in_kog},
       $stats_ref->{genes_in_pfam},
       $stats_ref->{genes_in_tigrfam},
       $stats_ref->{genes_in_genome_prop},
       $stats_ref->{genes_signalp},
       $stats_ref->{genes_transmembrane},
       $stats_ref->{genes_in_ipr},
       $stats_ref->{genes_in_pos_cluster},
       $stats_ref->{pfam_clusters},
       $stats_ref->{cog_clusters},
       $stats_ref->{kog_clusters},
       $stats_ref->{tigrfam_clusters},
       $stats_ref->{ortholog_groups},
       $stats_ref->{paralog_groups},
       $stats_ref->{n_scaffolds},
       $stats_ref->{crispr_count},
       $stats_ref->{total_gc},
       $stats_ref->{total_gatc},
       $stats_ref->{total_bases},
       $stats_ref->{total_coding_bases},
       $stats_ref->{genes_in_img_terms},
       $stats_ref->{genes_in_img_pways},
       $stats_ref->{genes_in_parts_list},
       $stats_ref->{genes_in_myimg},
       $stats_ref->{genes_obsolete},
       $stats_ref->{genes_revised},
       $stats_ref->{genes_in_eggnog},
      )
      = $cur->fetchrow();
    $cur->finish();
    $stats_ref->{gc_percent} = sprintf(
            "%d%%",
            100 * (
                    $stats_ref->{total_gc} /
                      $stats_ref->{total_bases}
            )
      )
      if $stats_ref->{total_bases} > 0;

    # Kludge for GcPerc; should only be used for single genome.
    my ($tmpc, $tmpp, $tmpt, $tmpb) = getFunctionTotals($dbh, $taxon_oids_ref );
    $stats_ref->{pfam_total}            = $tmpp;
    $stats_ref->{cog_total}             = $tmpc;
    $stats_ref->{kog_total}             = $tmpc;
    $stats_ref->{tigrfam_total}         = $tmpt;
    $stats_ref->{ortholog_groups_total} = $tmpb;

#    $stats_ref->{pfam_total}            = getPfamTotal($dbh);
#    $stats_ref->{cog_total}             = getCogTotal($dbh);
#    $stats_ref->{tigrfam_total}         = getTigrfamTotal($dbh);
#    $stats_ref->{ortholog_groups_total} = getOrthologGroupsTotal($dbh);

    if ( $stats_ref->{total_gene_count} > 0 ) {
        my $mul = ( 1 / $stats_ref->{total_gene_count} ) * 100;
        $stats_ref->{cds_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{cds_genes} * $mul );
        $stats_ref->{rna_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{rna_genes} * $mul );
        $stats_ref->{rrna_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{rrna_genes} * $mul );
        $stats_ref->{rrna5s_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{rrna5s_genes} * $mul );
        $stats_ref->{rrna16s_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{rrna16s_genes} * $mul );
        $stats_ref->{rrna18s_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{rrna18s_genes} * $mul );
        $stats_ref->{rrna23s_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{rrna23s_genes} * $mul );
        $stats_ref->{rrna28s_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{rrna28s_genes} * $mul );
        $stats_ref->{trna_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{trna_genes} * $mul );
        $stats_ref->{other_rna_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{other_rna_genes} * $mul );
        $stats_ref->{genes_w_func_pred_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_w_func_pred} * $mul );
        $stats_ref->{genes_wo_func_pred_sim_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_wo_func_pred_sim} * $mul );
        $stats_ref->{genes_wo_func_pred_no_sim_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_wo_func_pred_no_sim} * $mul );
        $stats_ref->{genes_hor_transfer_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_hor_transfer} * $mul );
        $stats_ref->{pseudo_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{pseudo_genes} * $mul );
        $stats_ref->{uncharacterized_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{uncharacterized_genes} * $mul );
        $stats_ref->{dubious_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{dubious_genes} * $mul );
        $stats_ref->{genes_in_enzymes_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_enzymes} * $mul );
        $stats_ref->{genes_in_tc_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_tc} * $mul );
        $stats_ref->{genes_in_kegg_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_kegg} * $mul );
        $stats_ref->{genes_not_in_kegg_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_not_in_kegg} * $mul );
        $stats_ref->{genes_in_ko_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_ko} * $mul );
        $stats_ref->{genes_not_in_ko_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_not_in_ko} * $mul );
        $stats_ref->{genes_wo_ez_w_ko_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_wo_ez_w_ko} * $mul );
        $stats_ref->{genes_in_orthologs_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_orthologs} * $mul );
        $stats_ref->{genes_in_img_clusters_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_img_clusters} * $mul );
        $stats_ref->{genes_in_paralogs_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_paralogs} * $mul );
        $stats_ref->{fused_genes_pc} =
          sprintf( "%.2f%%", $stats_ref->{fused_genes} * $mul );
        $stats_ref->{fusion_components_pc} =
          sprintf( "%.2f%%", $stats_ref->{fusion_components} * $mul );

        # TODO cassette pc - ken
        #$stats_ref->{genes_in_cassettes_pc} =
        #  sprintf( "%.2f%%", $stats_ref->{genes_in_cassettes_pc}  );
        $stats_ref->{genes_in_metacyc_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_metacyc} * $mul );
        $stats_ref->{genes_not_in_metacyc_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_not_in_metacyc} * $mul );

        $stats_ref->{genes_in_sp_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_sp} * $mul );
        $stats_ref->{genes_not_in_sp_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_not_in_sp} * $mul );

#        $stats_ref->{genes_in_seed_pc} =
#          sprintf( "%.2f%%", $stats_ref->{genes_in_seed} * $mul );
#        $stats_ref->{genes_not_in_seed_pc} =
#          sprintf( "%.2f%%", $stats_ref->{genes_not_in_seed} * $mul );

        $stats_ref->{genes_in_cog_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_cog} * $mul );
        $stats_ref->{genes_in_kog_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_kog} * $mul );
        $stats_ref->{genes_in_pfam_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_pfam} * $mul );
        $stats_ref->{genes_in_tigrfam_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_tigrfam} * $mul );
        $stats_ref->{genes_in_genome_prop_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_genome_prop} * $mul );
        $stats_ref->{genes_signalp_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_signalp} * $mul );
        $stats_ref->{genes_transmembrane_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_transmembrane} * $mul );
        $stats_ref->{genes_in_ipr_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_ipr} * $mul );
        $stats_ref->{genes_in_pos_cluster_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_pos_cluster} * $mul );
        $stats_ref->{genes_in_img_terms_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_img_terms} * $mul );
        $stats_ref->{genes_in_img_pways_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_img_pways} * $mul );
        $stats_ref->{genes_in_parts_list_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_parts_list} * $mul );
        $stats_ref->{genes_in_myimg_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_myimg} * $mul );
        $stats_ref->{genes_obsolete_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_obsolete} * $mul );
        $stats_ref->{genes_revised_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_revised} * $mul );
        $stats_ref->{genes_in_eggnog_pc} =
          sprintf( "%.2f%%", $stats_ref->{genes_in_eggnog} * $mul );
    }
    if ( $stats_ref->{total_bases} > 0 ) {
        my $mul = ( 1 / $stats_ref->{total_bases} ) * 100;
        $stats_ref->{total_coding_bases_pc} =
          sprintf( "%.2f%%", $stats_ref->{total_coding_bases} * $mul );
    }
}


############################################################################
# taxonLink - Optional taxon link, if there is one taxon.
#   More than one, no link out.  Also no link out if the value is 0.
#   Wrapper utility function.
############################################################################
sub taxonLink {
    my ( $nTaxons, $url, $val ) = @_;
    return "0" if $val eq "";
    return $val if !$url || $val <= 0;
    return alink( $url, $val );
}

############################################################################
# getPfamTotal - Get total pfam count.
############################################################################
sub getPfamTotal {
    my ($dbh) = @_;
    my $sql = qq{
       select count(*)
       from pfam_family
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getCogTotal - Get total COG count.
############################################################################
sub getCogTotal {
    my ($dbh) = @_;
    my $sql = qq{
       select count(*)
       from cog
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getKogTotal - Get total KOG count.
############################################################################
sub getKogTotal {
    my ($dbh) = @_;
    my $sql = qq{
       select count(*)
       from kog
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getTigrfamTotal - Get total TIGRfam count.
############################################################################
sub getTigrfamTotal {
    my ($dbh) = @_;
    my $sql = qq{
       select count(*)
       from tigrfam
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getOrthologGroupsTotal - Get ortholog groups total.
############################################################################
sub getOrthologGroupsTotal {
    my ($dbh) = @_;
    my $sql = qq{
       select count(*)
       from bbh_cluster
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

#
# get cog, pfam tigrfam, and bbh totals from dt_img_Stats_Table
#
sub getFunctionTotals {
    my($dbh, $taxon_oids_ref) = @_;

    my $rclause       = urClause("t.taxon_oid");
    my $selClause     = txsClause("t.taxon_oid", $dbh);
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my @binds = ();
    if ( scalar(@$taxon_oids_ref) == 1 ) {
        $rclause   = "";
        $selClause = "and t.taxon_oid = ? " ;
        push(@binds, $taxon_oids_ref->[0]);
    }

    my $imgclause = WebUtil::imgClause('t');

    #my %hash;
    my $sql = qq{
        select name, total_count
        from dt_img_stats
        where name in ('COG', 'Pfam', 'TIGRfam', 'bbh')
    };

    $sql = qq{
        select sum(genes_in_cog), sum(genes_in_pfam), sum(genes_in_tigrfam), sum(img_clusters)
        from taxon_stats ts, taxon t
        where ts.taxon_oid = t.taxon_oid
        $imgclause
        $rclause
        $selClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my ($c, $p, $t, $b) = $cur->fetchrow();
    #for(;;) {
        #my ($name, $cnt) = $cur->fetchrow();
        #last if(!$name);
        #$hash{$name}= $cnt;
    #}
    $cur->finish();
    #return($hash{'COG'}, $hash{'Pfam'}, $hash{'TIGRfam'}, $hash{'bbh'});
    return ($c, $p, $t, $b);
}

#
# Gets similarity count.
# Remember that gene can initial have no img terms with similarity
# But when the user updates a gene with a img term I have to
# remove it from my count - that why I minus some genes
#
#
sub getSimilarityCount {
    my ( $dbh, $taxon ) = @_;

    my $imgClause1 = WebUtil::imgClauseNoTaxon('gs.taxon');
    my $imgClause2 = WebUtil::imgClauseNoTaxon('gs2.taxon');
    my $sql = qq{
       select count(*)
       from (
           select distinct gs.gene_oid
           from gene_with_similarity gs
           where gs.taxon = ?
           $imgClause1
           minus
           select gf2.gene_oid
           from gene_img_functions gf2, gene_with_similarity gs2
           where gf2.gene_oid = gs2.gene_oid
           and gs2.taxon = ?
           $imgClause2
       )
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon, $taxon);
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

# a good way to compare the taxon_stats and the actual dynamic count for
# taxon detail page - ken
#
sub getCassetteGeneCount {
    my ( $dbh, $taxon_oid ) = @_;
    my $imgClause = WebUtil::imgClauseNoTaxon('gc.taxon');
    my $sql = qq{
        select count(distinct gcg.gene)
        from gene_cassette gc, gene_cassette_genes gcg
        where gc.cassette_oid = gcg.cassette_oid
        and gc.taxon = ?
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid);
    my ($count) = $cur->fetchrow();
    $cur->finish();
    return $count;
}

sub getCassettesCount {
    my ( $dbh, $taxon_oid ) = @_;
    my $imgClause = WebUtil::imgClauseNoTaxon('gc.taxon');
    my $sql = qq{
        select  count(*)
        from gene_cassette gc
        where gc.taxon = ?
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($count) = $cur->fetchrow();
    $cur->finish();
    return $count;
}


############################################################################
# printStatsWithReads - Show the actual statistics display.
#   For one taxon, there is link out to group of genes. More than one,
#   there are no link outs (since the gene list can overwhelm a browser).
#   Also Pfam and ortholog clusters are not shown in cumulative statistics
#   since a fast way of implementing this on the fly is not available,
#   unlike simply adding up counts for genes.
############################################################################
sub printStatsWithReads {
    my ( $dbh, $taxon_oids_ref ) = @_;

    my @remapped_taxon_oids = WebUtil::remapTaxonOids( $dbh, $taxon_oids_ref );
    $taxon_oids_ref = \@remapped_taxon_oids;

    my $contact_oid = getContactOid();

    my %stats;
    my %reads_stats;
    my $nTaxons = @$taxon_oids_ref;
    accumulateStats( $dbh, $taxon_oids_ref, \%stats );
    my $taxon_oid = $taxon_oids_ref->[0];
    #accumulateReadsStats( $dbh, $taxon_oid, \%reads_stats );

    my $total_gene_count = $stats{total_gene_count};
    my $total_bases      = $stats{total_bases};
    my $indent           = nbsp(4);
    my $rowHiliteColor   = "bisque";

    print "<table class='img'  border='0' cellspacing='3' cellpadding='0' >\n";
    print "<th class='img' ></th>\n";

    print "<th class='img' >Number<br/>in Contigs</th>\n";
    print "<th class='img' >% of<br/>Total</th>\n";

    # --es 10/31/08 Add two extra column for reads.
    #  Problems:
    #  1. Earlier DNA stats a little bit confusing since
    #     it represents assembled data stats, not raw reads.
    #  2. Pfam/COG/Tigrfam clusters only need one row of numbers.
    #  (How to resolve?)
    if ( $nTaxons == 1 ) {
        print "<th class='img' >Number<br/>in Reads</th>\n";
        print "<th class='img' >% of<br/>Total</th>\n";
    }
    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'><b>DNA, total number of bases</b></th>\n");
    ## --es 04/10/2006 use %s instead of %d to deal with overflow.
    printf( "<td class='img'   align='right'>%s</td>\n", $stats{total_bases} );
    printf( "<td class='img'   align='right'>%.2f%%</td>\n", 100 );
    if ( $nTaxons == 1 ) {
        printf( "<td class='img' align='right'>%s</td>\n",
                $reads_stats{total_bases} );
        printf("<td class='img' align='right'></td>\n");
    }
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    printf( "<td class='img' >%sDNA coding number of bases</td>\n", $indent );
    printf( "<td class='img'  align='right'>%s</td>\n",
            $stats{total_coding_bases} );
    printf( "<td class='img'   align='right'>%s</td>\n",
            $stats{total_coding_bases_pc} );
    if ( $nTaxons == 1 ) {
        printf( "<td class='img' align='right'>%s</td>\n",
                $reads_stats{total_coding_bases} );
        printf( "<td class='img' align='right'>%.2f%%</td>\n",
                $reads_stats{total_coding_bases} / $reads_stats{total_bases} *
                  100 );
    }
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%sDNA G+C number of bases</td>\n", $indent );
    printf( "<td class='img' valign='bottom'  align='right'>%s</td>\n",
            $stats{total_gc} );

    my $note1 = "<sup>1</sup>";
    if ( $stats{total_gatc} > 0 ) {
        printf( "<td class='img'   align='right'>%.2f%% $note1</td>\n",
                $stats{total_gc} / $stats{total_gatc} * 100 );
    } else {
        printf( "<td class='img'   align='right'>%.2f%% $note1</td>\n", 0 );
    }
    if ( $nTaxons == 1 ) {
        printf( "<td class='img' valign='bottom' align='right'>%s</td>\n",
                $reads_stats{total_gc} );
        if ( $reads_stats{total_gatc} > 0 ) {
            printf( "<td class='img' align='right'>%.2f%% $note1</td>\n",
                    $reads_stats{total_gc} / $reads_stats{total_gatc} * 100 );
        }
    }
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    if ( $nTaxons == 1 ) {
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
    }
    printf("</tr>\n");

    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'>All Reads</th>\n");
    printf( "<td class='img'   align='right'>%s</td>\n", nbsp(1) );
    printf( "<td class='img'   align='right'>%s</td>\n", nbsp(1) );
    printf( "<td class='img' align='right'>%d</td>\n",
            $reads_stats{total_raw_reads_count} );
    printf( "<td class='img' align='right'>%.2f%%</td>\n", 100 );
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%s%s</td>\n",
            $indent, "Unmapped reads to proxy genes" );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    if ( $nTaxons == 1 ) {
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
    }
    printf("</tr>\n");

    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'>DNA scaffolds with gene calls</th>\n");
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=scaffolds&taxon_oid=$taxon_oid";
    }
    printf( "<td class='img'   align='right'>%s</td>\n",
            taxonLink( $nTaxons, $url, $stats{n_scaffolds} ) );
    printf( "<td class='img'   align='right'>%.2f%%</td>\n", 100 );
    if ( $nTaxons == 1 ) {
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
    }
    printf("</tr>\n");

    # crispr count
    if ( $nTaxons == 1 ) {
         my $crisprcnt = $stats{crispr_count}; #getCRISPRCount( $dbh, $taxon_oid );
        $crisprcnt = 0 if ( $crisprcnt eq "" );

        my $url = $crisprcnt;
        if ( $crisprcnt > 0 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=crisprdetails&taxon_oid=$taxon_oid";
            $url = alink( $url, $crisprcnt );
        }

        print qq{
	    <tr class='img' >
		<td class='img' >&nbsp; &nbsp; &nbsp; &nbsp; CRISPR Count</td>
		<td class='img'   align='right'> $url </td>
		<td class='img'   align='right'>&nbsp; </td>
	    </tr>
        };
    }

    printf("<tr class='img' >\n");
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    printf( "<td class='img' >%s</td>\n", $indent );
    if ( $nTaxons == 1 ) {
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
    }
    printf("</tr>\n");

    printf("<tr class='img' >\n");
    print "<th class='subhead' ></th>\n";
    print "<th class='subhead' >Number<br/>of Genes</th>\n";
    print "<th class='subhead' >% of<br/>Total</th>\n";
    if ( $nTaxons == 1 ) {
        print "<th class='subhead' >Number of<br/>Mapped<br/>Reads</th>\n";
        print "<th class='subhead' >% of Total<br/>Mapped<br/>Reads</th>\n";
    }
    printf("</tr>\n");

    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'>Genes total number</th>\n");
    printf( "<td class='img'   align='right'>%d</td>\n",
            $stats{total_gene_count} );
    printf( "<td class='img'   align='right'>%.2f%%</td>\n", 100 );
    if ( $nTaxons == 1 ) {
        printf( "<td class='img' align='right'>%d</td>\n",
                $reads_stats{total_reads_count} );
        printf( "<td class='img' align='right'>%.2f%%</td>\n", 100 );
    }
    printf("</tr>\n");

    my $title = "Protein coding genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=proteinCodingGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow(
                       1,           $title,   $url, \%stats,
                       "cds_genes", $nTaxons, 0,    "cds_reads",
                       \%reads_stats
    );

    # pseudo genes
    my $title = "Pseudo Genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=pseudoGenes&taxon_oid=$taxon_oid";
    }

    #printCountPercRow( 1, $title, $url, \%stats, "pseudo_genes", $nTaxons,
    #                   0, "pseudo_reads", \%reads_stats );
    printf("<tr class='img' >\n");
    printf( "<td class='img' >%s%s</td>\n", $indent, $title );
    my $cnt              = $stats{pseudo_genes};
    my $total_gene_count = $stats{total_gene_count};
    if ( $cnt == 0 || $total_gene_count == 0 ) {
        printf("<td class='img' align='right'>0</td>\n");
        printf("<td class='img' align='right'>0.00%%</td>\n");
    } else {
        my $link = taxonLink( $nTaxons, $url, $stats{pseudo_genes} );
        printf("<td class='img' align='right'>$link</td>\n");
        my $perc = $stats{pseudo_genes_pc};
        printf( "<td class='img' align='right'>%s<sup>2</sup></td>\n", $perc );
    }
    if ( $nTaxons == 1 ) {
        printf( "<td class='img' align='right'>%s</td>\n",
                $reads_stats{pseudo_reads} );
        printf( "<td class='img' align='right'>%s</td>\n",
                $reads_stats{pseudo_reads_pc} );
    }
    print "</tr>\n";

    my $title = "Uncharacterized Genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=uncharGenes&taxon_oid=$taxon_oid";
    }
    my $uncharCnt = $stats{uncharacterized_genes};
    if ( $uncharCnt > 0 ) {
        printf("<tr class='img' >\n");
        printf( "<td class='img' >%s%s</td>\n", $indent, $title );
        my $link = taxonLink( $nTaxons, $url, $stats{uncharacterized_genes} );
        printf("<td class='img' align='right'>$link</td>\n");
        my $perc = $stats{uncharacterized_genes_pc};
        printf( "<td class='img' align='right'>%s<sup>4</sup></td>\n", $perc );
        if ( $nTaxons == 1 ) {
            printf( "<td class='img' align='right'>%s</td>\n",
                    $reads_stats{uncharacterized_reads} );
            printf( "<td class='img' align='right'>%s</td>\n",
                    $reads_stats{uncharacterized_reads} );
        }
        print "</tr>\n";
    }

    my $title = "RNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
          "$main_cgi?section=TaxonDetail" . "&page=rnas&taxon_oid=$taxon_oid";
    }
    printCountPercRow(
                       1,           $title,   $url, \%stats,
                       "rna_genes", $nTaxons, 0,    "rna_reads",
                       \%reads_stats
    );

    my $title = "rRNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA";
    }
    printCountPercRow(
                       2,            $title,
                       $url,         \%stats,
                       "rrna_genes", $nTaxons,
                       0,            "rrna_reads",
                       \%reads_stats
    );

    my $title = "5S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=5S";
    }
    printCountPercRow(
                       3,              $title,
                       $url,           \%stats,
                       "rrna5s_genes", $nTaxons,
                       0,              "rrna5s_reads",
                       \%reads_stats
    );

    my $title = "16S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=16S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna16s_genes", $nTaxons, 0,
                       "rrna16s_reads", \%reads_stats );

    my $title = "18S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=18S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna18s_genes", $nTaxons, 0,
                       "rrna18s_reads", \%reads_stats );

    my $title = "23S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=23S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna23s_genes", $nTaxons, 0,
                       "rrna23s_reads", \%reads_stats );

    my $title = "28S rRNA";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=rRNA"
          . "&gene_symbol=28S";
    }
    printCountPercRow( 3, $title, $url, \%stats, "rrna28s_genes", $nTaxons, 0,
                       "rrna28s_reads", \%reads_stats );

    my $title = "tRNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=tRNA";
    }
    printCountPercRow(
                       2,            $title,
                       $url,         \%stats,
                       "trna_genes", $nTaxons,
                       0,            "trna_reads",
                       \%reads_stats
    );

    my $title = "Other RNA genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=rnas&taxon_oid=$taxon_oid&locus_type=xRNA";
    }
    printCountPercRow( 2, $title, $url, \%stats, "other_rna_genes",
		       $nTaxons, 0, "other_rna_reads", \%reads_stats );

    my $title = "Genes with Predicted Protein Product";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=withFunc&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_w_func_pred",
		       $nTaxons, 0, "reads_w_func_pred", \%reads_stats );

    if ($img_lite) {
        my $title = "Genes without Predicted Protein Product";
        my $url   =
            "$main_cgi?section=TaxonDetail"
          . "&page=withoutFunc&taxon_oid=$taxon_oid";
        printf("<tr class='img' >\n");
        printf("<td class='img' >%sGenes without Predicted Protein Product</td>\n", $indent );
        my $noFunc     = $stats{cds_genes} - $stats{genes_w_func_pred};
        my $noFuncPerc = 0;
        $noFuncPerc = 100 * $noFunc / $stats{total_gene_count}
          if $stats{total_gene_count} > 0;
        my $link = alink( $url, $noFunc );
        $link = 0       if $noFunc == 0;
        $link = $noFunc if $nTaxons > 1;
        printf( "<td class='img'  align='right'>" . $link . "</td>\n" );
        printf( "<td class='img'  align='right'>%.2f%%</td>\n", $noFuncPerc );

        if ( $nTaxons == 1 ) {
            my $noFunc =
              $reads_stats{cds_reads} - $reads_stats{reads_w_func_pred};
            my $noFuncPerc = 0;
            $noFuncPerc = 100 * $noFunc / $reads_stats{total_reads_count}
              if $reads_stats{total_reads_count} > 0;
            printf( "<td class='img' align='right'>" . $noFunc . "</td>\n" );
            printf( "<td class='img' align='right'>%.2f%%</td>\n",
                    $noFuncPerc );
        }
        printf("</tr>\n");
    } else {
        printf("<tr class='img' >\n");
        printf("<td class='img' >%sGenes without Predicted Protein Product</td>\n", $indent );
        printf( "<td class='img'   align='right'>%d</td>\n",
                $stats{genes_wo_func_pred_sim} +
		$stats{genes_wo_func_pred_no_sim} );
        printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                (
		 $stats{genes_wo_func_pred_sim_pc} +
		 $stats{genes_wo_func_pred_no_sim_pc}
                )
        );

        if ( $nTaxons == 1 ) {
            printf( "<td class='img' align='right'>%d</td>\n",
                    $reads_stats{reads_wo_func_pred_sim} +
		    $reads_stats{reads_wo_func_pred_no_sim} );
            printf( "<td class='img' align='right'>%.2f%%</td>\n",
                    (
		     $reads_stats{reads_wo_func_pred_sim_pc} +
		     $reads_stats{reads_wo_func_pred_no_sim_pc}
                    )
            );
        }
        printf("</tr>\n");
    }

    if ( !$img_lite ) {
        printf("<tr class='img' >\n");
        my $title = "Genes w/o function with similarity";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=noFuncHomo&taxon_oid=$taxon_oid";
        }
        printCountPercRow(
                           2,                        $title,
                           $url,                     \%stats,
                           "genes_wo_func_pred_sim", $nTaxons,
                           0,                        "reads_wo_func_pred_sim",
                           \%reads_stats
        );
	if($img_internal) {
	    my $title = "Genes horizontally transferred";
	    printCountPercRow( 2, $title, $url, \%stats,
			       "genes_wo_func_pred_sim",
			       $nTaxons, 0, "reads_wo_func_pred_sim",
			       \%reads_stats );
        }
    }

    if ( !$img_lite ) {
        my $title = "Genes w/o function w/o similarity";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=noFuncNoHomo&taxon_oid=$taxon_oid";
        }
        printCountPercRow(
                           2,
                           $title,
                           $url,
                           \%stats,
                           "genes_wo_func_pred_no_sim",
                           $nTaxons,
                           0,
                           "reads_wo_func_pred_no_sim",
                           \%reads_stats
        );
    }

    my $title = "Genes connected to KEGG pathways";
    $title .= "<sup>3</sup>" if ($chart_exe);

    my $url;
    if ( $nTaxons == 1 ) {
        $url =
          "$main_cgi?section=TaxonDetail"
	  . "&page=kegg&cat=cat&taxon_oid=$taxon_oid";
    } else {
        $url =
            "$main_cgi?section=CompareGenomes"
          . "&page=taxonBreakdownStats"
          . "&statTableName=dt_kegg_stats&initial=1";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_kegg", $nTaxons, 0,
                       "reads_in_kegg", \%reads_stats );

    my $title = "not connected to KEGG pathways";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
          "$main_cgi?section=TaxonDetail"
	  . "&page=noKegg&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_not_in_kegg", $nTaxons,
                       0, "reads_not_in_kegg", \%reads_stats );

    # ko for 2.8
    my $title = "Protein coding genes connected to KEGG Orthology (KO)";
    my $url;
    $url = "$main_cgi?section=TaxonDetail" . "&page=ko&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 );
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_ko", $nTaxons,
       0, "reads_in_ko", \%reads_stats );

    # ko not in
    my $title = "not connected to KEGG Orthology (KO)";
    my $url;
    $url = "$main_cgi?section=TaxonDetail" . "&page=noKo&taxon_oid=$taxon_oid"
      if ( $nTaxons == 1 );
    printCountPercRow( 2, $title, $url, \%stats, "genes_not_in_ko", $nTaxons,
       0, "reads_not_in_ko", \%reads_stats);

    # enzymes
    my $title = "Genes with enzymes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=enzymes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_in_enzymes", $nTaxons,
                       0, "reads_in_enzymes", \%reads_stats );

    # genes w/o enzymes, w/ ko
    my $title = "w/o enzymes but with candidate KO based enzymes";
    my $url   =
        "$main_cgi?section=MissingGenes"
        . "&page=taxonGenesWithKO&taxon_oid=$taxon_oid";
    printCountPercRow( 1, $title, $url, \%stats,
        "genes_wo_ez_w_ko", $nTaxons, 0, "reads_wo_ez_w_ko", \%reads_stats );

    my $title = "Genes with COGs";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
	    "$main_cgi?section=TaxonDetail"
	    . "&page=cogs&cat=cat&taxon_oid=$taxon_oid";
    } else {
        $url =
            "$main_cgi?section=CompareGenomes"
	    . "&page=taxonBreakdownStats"
	    . "&statTableName=dt_cog_stats&initial=1";
    }
    printCountPercRow(
                       1,              $title,
                       $url,           \%stats,
                       "genes_in_cog", $nTaxons,
                       0,              "reads_in_cog",
                       \%reads_stats
    );

    my $title = "with KOGs";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
	    "$main_cgi?section=TaxonDetail"
	    . "&page=kogs&cat=cat&taxon_oid=$taxon_oid";
    } else {
        $url =
            "$main_cgi?section=CompareGenomes"
	    . "&page=taxonBreakdownStats"
	    . "&statTableName=dt_kog_stats&initial=1";
    }
    printCountPercRow(
                       1,              $title,
                       $url,           \%stats,
                       "genes_in_kog", $nTaxons,
                       0,              "reads_in_kog",
                       \%reads_stats
    );

    my $title = "with Pfam";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=pfam&cat=cat&taxon_oid=$taxon_oid";
    } else {
    	GenomeCart::insertToGtt($dbh);
        my $sql = "select count(id) from gtt_taxon_oid";
        my $cur = execSql( $dbh, $sql, $verbose );
        my $sessionCount = $cur->fetchrow();
        $cur->finish();

        my $max = 80;
        if ( $sessionCount <= $max && $sessionCount > 0 ) {
            $url =
                "$main_cgi?section=CompareGenomes"
              . "&page=taxonBreakdownStats"
              . "&statTableName=dt_pfam_stats&initial=1";
        }
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_in_pfam", $nTaxons, 0,
                       "reads_in_pfam", \%reads_stats );

    my $title = "with TIGRfam";
    $title .= "<sup>3</sup>" if ($chart_exe);
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=tigrfam&cat=cat&taxon_oid=$taxon_oid";
    } else {
    	GenomeCart::insertToGtt($dbh);
        my $sql = "select count(id) from gtt_taxon_oid";
        my $cur = execSql( $dbh, $sql, $verbose );
        my $sessionCount = $cur->fetchrow();
        $cur->finish();

        my $max = 80;
        if ( $sessionCount <= $max && $sessionCount > 0 ) {
            $url =
                "$main_cgi?section=CompareGenomes"
              . "&page=taxonBreakdownStats"
              . "&statTableName=dt_tigrfam_stats&initial=1";
        }
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_in_tigrfam",
                       $nTaxons, 0, "reads_in_tigrfam", \%reads_stats );

    if ($img_internal) {
        my $title = "with Genome Property";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=genomeProp&taxon_oid=$taxon_oid";
        }
        printCountPercRow(
                           2,                      $title,
                           $url,                   \%stats,
                           "genes_in_genome_prop", $nTaxons,
                           0,                      "reads_in_genome_prop",
                           \%reads_stats
        );
    }

    if($enable_interpro) {
    my $title = "with InterPro";
    my $url;
    if ( $nTaxons == 1 ) {
        $url = "$main_cgi?section=TaxonDetail&page=ipr&taxon_oid=$taxon_oid";
    }
    printCountPercRow(
                       2,              $title,
                       $url,           \%stats,
                       "genes_in_ipr", $nTaxons,
                       0,              "reads_in_ipr",
                       \%reads_stats
    );
    }

    if ($include_img_terms) {
        my $title = "with IMG Terms";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=imgTerms&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_img_terms",
                           $nTaxons, 0, "reads_in_img_terms", \%reads_stats );

        # add new row here for er - ken
        if ( $img_er && $img_lite && $img_internal && !$include_metagenomes ) {
            my $count = getSimilarityCount( $dbh, $taxon_oid );
            if ( $count > 0 ) {
                my $total = $stats{total_gene_count};

                my $title = "Genes w/o IMG Terms w/ Similarity";
                my $url   =
                    "$main_cgi?section=TaxonDetail"
                  . "&page=imgTermsSimilarity&taxon_oid=$taxon_oid";
                my $indent = nbsp(4);
                print "<tr class='img' >\n";
                print "<td class='img' >$indent" . escHtml($title) . "</td>\n";
                print "<td class='img'   align='right'> "
                  . alink( $url, $count )
                  . " </td>\n";
                my $pc = ( $count / $total ) * 100;
                $pc = sprintf( "%.2f", $pc );
                print "<td class='img'   align='right'> $pc%</td>\n";
                print "</tr>\n";
            }
        }

        my $title = "with IMG Pathways";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=imgPways&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_img_pways",
                           $nTaxons, 0, "reads_in_img_pways", \%reads_stats );

        my $title = "with IMG Parts List";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=imgPlist&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "genes_in_parts_list",
                           $nTaxons, 0, "reads_in_parts_list", \%reads_stats );
    }
    if ($show_myimg_login) {
        my $title = "with MyIMG Annotation";
        my $url;
        if ( $nTaxons == 1 ) {
            my $val = $stats{"genes_in_myimg"};
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=myIMGGenes&taxon_oid=$taxon_oid&gcnt=$val";
        }
        printCountPercRow( 2, $title, $url, \%stats,
			   "genes_in_myimg", $nTaxons,
                           0, "reads_in_myimg", \%reads_stats );
    }

    if ( !$img_lite ) {
        my $title = "Genes in ortholog clusters";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=orthologGroups&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 1, $title, $url, \%stats, "genes_in_orthologs",
                           $nTaxons, 0, "reads_in_orthologs", \%reads_stats );
    }

    my $title;
    if ($include_metagenomes) {
        $title = "in internal clusters";
    } else {
        $title = "in paralog clusters";
    }
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=paralogGroups&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 2, $title, $url, \%stats, "genes_in_paralogs", $nTaxons,
                       0, "reads_in_paralogs", \%reads_stats );


    if ( $nTaxons == 1 ) {
        if ( $enable_cassette ) {
            my $total   = $stats{total_gene_count};
            my $cgcount = $stats{genes_in_cassettes};

            my $pc = ( $cgcount / $total ) * 100 if ( $total != 0 );
            $pc = 0 if ( $total == 0 );
            $pc = sprintf( "%.2f", $pc );

            my $ccount = $stats{total_cassettes};

            my $indent = nbsp(8);

            print "<tr class='img'>\n";
            print "<td class='img'> $indent in Chromosomal Cassette</th>\n";
            my $url = "$main_cgi?section=TaxonDetail"
		    . "&page=geneCassette&taxon_oid=$taxon_oid";
            $url = alink( $url, $cgcount );
            print "<td class='img' align='right'> $url </td>\n";
            print "<td class='img' align='right'> $pc% </td>\n";
            print "</tr>\n";

            my $indent = nbsp(4);

            print "<tr class='img'>\n";
            print "<td class='img'> $indent Chromosomal Cassettes";
	    print "</th>\n";
            my $url = "$main_cgi?section=GeneCassette"
		    . "&page=occurrence&taxon_oid=$taxon_oid";
            $url = alink( $url, $ccount );
            print "<td class='img' align='right'> $url </td>\n";
            print "<td class='img' align='right'> &nbsp; </td>\n";
            print "</tr>\n";
        }

        my $total    = $stats{total_biosynthetic};
        my $gbcnt    = $stats{genes_in_biosynthetic};
        my $gbcnt_pc = $stats{genes_in_biosynthetic_pc};

        if (($hideZeroStats eq "No") ||
        ($hideZeroStats eq "Yes" && $total > 0)) {
            my $indent = nbsp(4);
            print "<tr class='img'>\n";
            print "<td class='img'> $indent Biosynthetic Clusters</th>\n";
            my $url = "$main_cgi?section=BiosyntheticDetail"
                    . "&page=biosynthetic_clusters&taxon_oid=$taxon_oid";
            $url = alink( $url, $total );
            $url = 0 if $total < 1;
            print "<td class='img' align='right'> $url </td>\n";
            print "<td class='img' align='right'>-</td>\n";
            print "</tr>\n";

            my $indent = nbsp(8);
            print "<tr class='img'>\n";
            print "<td class='img'> $indent Genes in Biosynthetic Clusters</th>\n";
            my $url = "$main_cgi?section=BiosyntheticDetail"
                    . "&page=biosynthetic_genes&taxon_oid=$taxon_oid";
            $url = alink( $url, $gbcnt );
            $url = 0 if $gbcnt < 1;
            print "<td class='img' align='right'> $url </td>\n";
            print "<td class='img' align='right'> ${gbcnt_pc}% </td>\n";
            print "</tr>\n";
        }
    }

    if ($show_myimg_login) {
        ### MyMissing Genes
        my %mygene_stats;
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql2 = qq{
            select count(*)
            from mygene g
            where taxon = ?
            and modified_by = ?
            $imgClause
            };
        my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid, $contact_oid);
        my ($cnt2) = $cur2->fetchrow();
        $cur2->finish();

        $title = "MyMissing Genes";
        my $url =
            "$main_cgi?section=MyIMG"
          . "&page=viewMyTaxonMissingGenes&taxon_oid=$taxon_oid";
        printf("<tr class='img' >\n");
        printf( "<td class='img' >%s$title</td>\n", nbsp(4) );
        my $link = alink( $url, $cnt2 );
        $link = 0     if $cnt2 == 0;
        $link = $cnt2 if $nTaxons > 1;
        print "<td class='img'  align='right'>" . $link . "</td>\n";
        printf("<td class='img'   align='right'>-</td>\n");
        printf("</tr>\n");
    }

    my $title = "Fused Genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=fusedGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow(
                       1,             $title,
                       $url,          \%stats,
                       "fused_genes", $nTaxons,
                       0,             "fused_reads",
                       \%reads_stats
    );

    if ( !$img_lite ) {
        my $title = "as fusion components";
        my $url;
        if ( $nTaxons == 1 ) {
            $url =
                "$main_cgi?section=TaxonDetail"
              . "&page=fusionComponents&taxon_oid=$taxon_oid";
        }
        printCountPercRow( 2, $title, $url, \%stats, "fusion_components",
                           $nTaxons, 0, "fusion_components", \%reads_stats );
    }

    my $title = "Genes coding signal peptides";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=signalpGeneList&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_signalp", $nTaxons, 0,
                       "reads_signalp", \%reads_stats );

    my $title = "Genes coding transmembrane proteins";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=transmembraneGeneList&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_transmembrane",
                       $nTaxons, 0, "reads_transmembrane", \%reads_stats );

    #if( $img_lite ) {
    #   my $title = "Genes in Residual Orthologous Groups";
    #   my $url;
    #   if ($nTaxons == 1) {
    #       $url = "$main_cgi?section=TaxonDetail" .
    #              "&page=rogs&taxon_oid=$taxon_oid";
    #   }
    #   printCountPercRow( 1, $title, $url, \%stats,
    #   "genes_in_rog", $nTaxons );
    #}

    my $title = "Obsolete Genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=obsoleteGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_obsolete", $nTaxons, 0,
                       "reads_obsolete", \%reads_stats );

    my $title = "Revised Genes";
    my $url;
    if ( $nTaxons == 1 ) {
        $url =
            "$main_cgi?section=TaxonDetail"
          . "&page=revisedGenes&taxon_oid=$taxon_oid";
    }
    printCountPercRow( 1, $title, $url, \%stats, "genes_revised", $nTaxons, 0,
                       "reads_revised", \%reads_stats );


    ## Can only do single taxon at a time for now.
    if ( $nTaxons == 1 ) {
        printf("<tr class='img' >\n");
        print "<th class='subhead' ></th>\n";
        print "<th class='subhead' >Number<br/>of Clusters</th>\n";
        print "<th class='subhead' >% of<br/>Total</th>\n";
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
        printf("</tr>\n");

	# COG Clusters
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>COG clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
                $stats{cog_clusters} );
        if ( $stats{cog_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{cog_clusters} / $stats{cog_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
        printf("</tr>\n");

	# KOG Clusters
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>KOG clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
                $stats{kog_clusters} );
        if ( $stats{kog_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{kog_clusters} / $stats{kog_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
        printf("</tr>\n");

        #
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>Pfam clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
                $stats{pfam_clusters} );
        if ( $stats{pfam_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{pfam_clusters} / $stats{pfam_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
        printf("</tr>\n");

        #
        printf("<tr class='highlight'>\n");
        printf("<th class='subhead'>TIGRfam clusters</th>\n");
        printf( "<td class='img'   align='right'>%s</td>\n",
                $stats{tigrfam_clusters} );
        if ( $stats{tigrfam_total} > 0 ) {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                    $stats{tigrfam_clusters} / $stats{tigrfam_total} * 100 );
        } else {
            printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
        }
        printf("<td class='img' align='right'></td>\n");
        printf("<td class='img' align='right'></td>\n");
        printf("</tr>\n");

        if ( !$img_lite ) {
            printf("<tr class='highlight'>\n");
            printf("<th class='subhead'>Paralogous groups</th>\n");
            printf( "<td class='img'   align='right'>%s</td>\n",
                    $stats{paralog_groups} );
            printf("<td class='img'   align='right'>100.00%%</td>\n");
            printf("<td class='img' align='right'></td>\n");
            printf("<td class='img' align='right'></td>\n");
            printf("</tr>\n");
        }

        #
        if ( !$img_lite ) {
            printf("<tr class='highlight'>\n");
            printf("<th class='subhead'>Orthologous groups</th>\n");
            my $url;
            if ( $nTaxons == 1 ) {
                $url =
                    "$main_cgi?section=TaxonDetail"
                  . "&page=orthologGroups&taxon_oid=$taxon_oid";
            }
            printf( "<td class='img'   align='right'>%s</td>\n",
                    $stats{ortholog_groups} );

            #taxonLink( $nTaxons, $url, $stats{  ortholog_groups } ) );
            if ( $stats{ortholog_groups_total} > 0 ) {
                printf( "<td class='img'   align='right'>%.2f%%</td>\n",
                        $stats{ortholog_groups} /
                          $stats{ortholog_groups_total} * 100 );
            } else {
                printf( "<td class='img'   align='right'>%.2f%%</td>\n", 0 );
            }
            printf("<td class='img' align='right'></td>\n");
            printf("<td class='img' align='right'></td>\n");
            printf("</tr>\n");
        }
    }

    print "</table>\n";
    print "<br/>\n";
    print "<b>Notes</b>:<br/>\n";
    print "<p>\n";
    print "<a name='ref1' id='ref1'></a>1</sup> - ";
    print "GC percentage shown as count of G's and C's divided ";
    print "by a total number of G's, C's, A's, and T's.<br/> ";
    print nbsp(3);
    print "This is not necessarily ";
    print "synonymous with the total number of bases.\n";
    print "<br/>\n";
    print "<a name='ref2' id='ref2'></a>2</sup> - ";
    print "Pseudogenes may also be counted as protein coding "
      . "or RNA genes,<br/>\n";
    print nbsp(3);
    print "so is not additive under total gene count.<br/>\n";

    if ($chart_exe) {
        print "<a name='ref3' id='ref3'></a>3</sup> - ";
        print "Graphical view available." . "<br/>\n";
    }

    if ( $uncharCnt > 0 ) {
        print "<a name='ref4' id='ref4'></a>4</sup> - ";
        print "Uncharacterized genes are genes that are not classified ";
        print "as CDS, a type of RNA, or pseudogene,<br/>\n";
        print nbsp(3);
        print "but as 'unkonwn' or ";
        print "'other' by the source provider.<br/>\n";
    }
    print "</p>\n";
}

#
# get crispr count for a genome
#
sub getCRISPRCount {
    my ( $dbh, $taxon_oid ) = @_;
#    my $imgClause = WebUtil::imgClauseNoTaxon('ss.taxon');
#    my $sql = qq{
#        select ss.taxon, count(*)
#        from scaffold_stats ss
#        where ss.taxon = ?
#        $imgClause
#        and exists (select 1 from scaffold_repeats sr
#                    where sr.scaffold_oid = ss.scaffold_oid
#                    and sr.type = ?)
#        group by ss.taxon
#    };
#

    my $sql = qq{
      select CRISPR_COUNT
from taxon_stats
where taxon_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid);
    my ($count ) = $cur->fetchrow();
    $cur->finish();
    return $count;
}

#
# get plasmid count
#
sub getPlasmidCount {
    my ( $dbh, $taxon_oid ) = @_;
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    my $sql = qq{
	select count(distinct s.scaffold_oid)
	from scaffold s
	where s.mol_type = ?
	and s.taxon  = ?
	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, 'plasmid', $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}


1;
