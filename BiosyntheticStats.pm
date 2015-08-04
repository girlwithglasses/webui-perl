############################################################################
# BiosyntheticStats - detail page for biosynthetic clusters
# $Id: BiosyntheticStats.pm 30385 2014-03-11 05:05:12Z aratner $
############################################################################
package BiosyntheticStats;
my $section = "BiosyntheticStats";

use strict;
use CGI qw( :standard );
use Data::Dumper;
use POSIX qw(ceil floor);
use Array::Utils qw(:all);
use BiosyntheticDetail;
use ChartUtil;
use DataEntryUtil;
#use FuncUtil;
use HtmlUtil;
use ImgTermNode; 
use ImgTermNodeMgr; 
use ImgPwayBrowser;
use ImgCompound;
use MerFsUtil;
use MetaUtil;
use MetaGeneTable;
use NaturalProd;
use OracleUtil;
use Storable;
use TaxonDetailUtil;
use WebConfig;
use WebUtil;
use WorkspaceUtil;


my $env           = getEnv();
my $main_cgi      = $env->{main_cgi};
my $section_cgi   = "$main_cgi?section=$section";
my $inner_cgi     = $env->{inner_cgi};
my $tmp_url       = $env->{tmp_url};
my $tmp_dir       = $env->{tmp_dir};
my $verbose       = $env->{verbose};
my $base_dir      = $env->{base_dir};
my $base_url      = $env->{base_url};

my $ncbi_base_url = $env->{ncbi_entrez_base_url};
my $pfam_base_url = $env->{pfam_base_url};
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";
#my $webfs_data_dir  = $env->{webfs_data_dir};
#my $bc_sdb_name     = $webfs_data_dir . "/ui/bc_stats.sdb";

my $YUI           = $env->{yui_dir_28};
my $nvl           = getNvl();

my $enable_biocluster = $env->{enable_biocluster};
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $unknown = 'Unknown';
my $precomputed = 1;
my $UPPER_LIMIT = 5000;

sub dispatch {
    my $sid = getContactOid();
    my $page = param("page");    

    if ( $page eq "stats" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;        
        printOverview(); # stats in tabs
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "summaryStats" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;        
	printStats(1);
        HtmlUtil::cgiCacheStop();

    } elsif ( $page eq "breakdownByDomain" ) {
	printBreakdownBy("domain", 1);
    } elsif ( $page eq "breakdownByPhylum" ) {
	printBreakdownBy("phylum", 1);
    } elsif ( $page eq "breakdownByBCType" ) {
	printBreakdownBy("bc_type", 1);
    } elsif ( $page eq "breakdownBySMType" ) {
	printBreakdownBy("np_type", 1);
    } elsif ( $page eq "breakdownByLength" ) {

	my $title = titleForType("length");
        print "<h1>Biosynthetic Clusters - $title</h1>";

	my $url = "xml.cgi?section=$section&page=displayStats&type=length";
	my $func = "javascript:displayStats('$url', 'lengthtab', 'bylength_genomes')";
	print qq{
        <select id='bylength_genomes' name='bylength_genomes' onchange="$func">
          <option value='both' selected>Isolates and Metagenomes</option>
          <option value='isolate'>Isolates Only</option>
          <option value='metagenome'>Metagenomes Only</option>
        </select>
        };
	print "<span id='lengthtab'>";
	if ($precomputed) {
	    printBreakdownBy("length", 0);
	} else {
	    print "<p>Please click <font color='blue'><u>Display</u></font> "
		. "to load the distribution of Biosynthetic Clusters by Length.</p>";
	    print "<input type='button' class='medbutton' "
		. "value='Display' onclick=\"$func\" />";
	}
	print "</span>";

    } elsif ( $page eq "breakdownByGeneCount" ) {

	my $title = titleForType("gene_count");
        print "<h1>Biosynthetic Clusters - $title</h1>";

	my $url = "xml.cgi?section=$section&page=displayStats&type=gene_count";
	my $func = "javascript:displayStats('$url', 'genecounttab', 'bygenecount_genomes')";
	print qq{
        <select id='bygenecount_genomes' name= 'bygenecount_genomes'
                onchange="$func">
          <option value='both' selected>Isolates and Metagenomes</option>
          <option value='isolate'>Isolates Only</option>
          <option value='metagenome'>Metagenomes Only</option>
        </select>
        };
	print "<br/>";
	print "<span id='genecounttab'>";
	if ($precomputed) {
	    printBreakdownBy("gene_count", 0);
	} else {
	    print "<p>Please click <font color='blue'><u>Display</u></font> "
		. "to load the distribution of Biosynthetic Clusters by Gene Count.</p>";
	    print "<input type='button' class='medbutton' "
		. "value='Display' onclick=\"$func\" />";
	}
	print "</span>";

    } elsif ( $page eq "breakdownByECType" ) {
	printBreakdownBy("ec_type", 1);
    } elsif ( $page eq "breakdownByPfam" ) {
	printBreakdownBy("pfam", 1);

    } elsif ( $page eq "byGenome" ) {
        printStatsByGenome();
    } elsif ( $page eq "byProbability" ||
              paramMatch("byProbability") ne "" ) {
        printStatsByProbability();
    } elsif ( $page eq "byGeneCount" ||
              paramMatch("byGeneCount") ne "" ) {
        printStatsByGeneCount();
    } elsif ( $page eq "byPhylum" ||
              paramMatch("byPhylum") ne "" ) {
        printStatsByPhylum();
    } elsif ( $page eq "withGenbankID" ) {
        printClustersWithGenbankID();
    } elsif ( $page eq "byBCType" ) {
        printStatsByBCType(1);
    } elsif ( $page eq "clustersByBCType" ) {
        printClustersByBCType();
    } elsif ( $page eq "clustersByProbability" ) {
        printClustersByProbability();
    } elsif ( $page eq "clustersByGeneCount" ) {
        printClustersByGeneCount();
    } elsif ( $page eq "clustersByDomain" ) {
        printClustersByDomain();
    } elsif ( $page eq "clustersByPhylum" ) {
        printClustersByPhylum();
    } elsif ( $page eq "clustersByPhylo" ) {
        printClustersByPhylo();
    } elsif ( $page eq "clustersByLength" ) {
        printClustersByLength();
    } elsif ( $page eq "byNpId" ) {
        printStatsByNp(0);
    } elsif ( $page eq "clustersByNpId" ) {
        printClustersByNp(0);
    } elsif ( $page eq "clustersByPfam" ) {
        printClustersByPfam();
    } elsif ( $page eq "clustersByPfamIds" ||
              paramMatch("clustersByPfamIds") ne "" ) {
        printClustersByPfamIds();
    } elsif ( $page eq "pfamlist" ) {
	printPfamList();
    } elsif ( $page eq "byNpType" ) {
        printStatsByNp(1);
    } elsif ( $page eq "clustersByNpType" ) {
        printClustersByNp(1);
    } elsif ( $page eq "displayStats" ) {
	loadStats();
    }
}

sub printOverview {
    print "<h1>Biosynthetic Cluster (BC) Statistics</h1>";
    my $search_url = "$main_cgi?section=BcSearch&page=bcSearch";
    my $link = alink($search_url, "Search for Biosynthetic Clusters");
    print "<p>$link";
    my $portal_url = "$main_cgi?section=np";
    my $link = alink($portal_url, "ABC Portal");
    print "<br/>$link</p>";

    printStatsJS(); #if !$precomputed;
    printMainForm();    

    require TabHTML;
    TabHTML::printTabAPILinks("bioStatsTab");
    my @tabIndex = ("#biostatstab1", "#biostatstab2",
		    "#biostatstab3", "#biostatstab4",
		    "#biostatstab5", "#biostatstab6",
		    "#biostatstab7", "#biostatstab8",
		    "#biostatstab9");
    
    my @tabNames = ("Overview", "by Domain", "by Phylum", 
		    "by BC type", "by SM type", 
		    "by Length", "by Gene Count", 
		    "by EC type", "by Pfam");
		    #"by KEGG");

    TabHTML::printTabDiv("bioStatsTab", \@tabIndex, \@tabNames);

    print "<div id='biostatstab1'>";
    print "<br/>";
    webLog( dateTimeStr() . " start stats\n" );
    printStats();
    webLog( dateTimeStr() . " end stats\n" );
    print "</div>"; # end biostatstab1

    print "<div id='biostatstab2'>";
    webLog( dateTimeStr() . " start domain\n" );
    printBreakdownBy("domain");
    webLog( dateTimeStr() . " end domain\n" );
    print "</div>"; # end biostatstab2

    print "<div id='biostatstab3'>";
    webLog( dateTimeStr() . " start phylum\n" );    
    printBreakdownBy("phylum");
    webLog( dateTimeStr() . " end phylum\n" );
    print "</div>"; # end biostatstab3

    print "<div id='biostatstab4'>";
    webLog( dateTimeStr() . " start bc type\n" );
    printBreakdownBy("bc_type");
    webLog( dateTimeStr() . " end bc type\n" );
    print "</div>"; # end biostatstab4

    print "<div id='biostatstab5'>";
    webLog( dateTimeStr() . " start sm type\n" );
    printBreakdownBy("np_type");
    webLog( dateTimeStr() . " end sm type\n" );
    print "</div>"; # end biostatstab5

    print "<div id='biostatstab6'>";
    webLog( dateTimeStr() . " BCs - start length\n" );
    my $url = "xml.cgi?section=$section&page=displayStats&type=length";
    my $func = "javascript:displayStats('$url', 'lengthtab', 'bylength_genomes')";
    print qq{
        <br>
        <select id='bylength_genomes' name='bylength_genomes' onchange="$func">
          <option value='both' selected>Isolates and Metagenomes</option>
          <option value='isolate'>Isolates Only</option>
          <option value='metagenome'>Metagenomes Only</option>
        </select>
    };
    print "<span id='lengthtab'>";
    if ($precomputed) {
	printBreakdownBy("length");
    } else {
    print "<p>Please click <font color='blue'><u>Display</u></font> to load the distribution of Biosynthetic Clusters by Length.</p>";
    print "<input type='button' class='medbutton' "
	. "value='Display' onclick=\"$func\" />";
    }
    print "</span>";
    webLog( dateTimeStr() . " BCs - end length\n" );
    print "</div>"; # end biostatstab6

    print "<div id='biostatstab7'>";
    webLog( dateTimeStr() . " BCs - start gene_count\n" );
    my $url = "xml.cgi?section=$section&page=displayStats&type=gene_count";
    my $func = "javascript:displayStats('$url', 'genecounttab', 'bygenecount_genomes')";
    print qq{
        <br>
        <select id='bygenecount_genomes' name= 'bygenecount_genomes'
                onchange="$func">
          <option value='both' selected>Isolates and Metagenomes</option>
          <option value='isolate'>Isolates Only</option>
          <option value='metagenome'>Metagenomes Only</option>
        </select>
    };
    print "<br/>";
    print "<span id='genecounttab'>";
    if ($precomputed) {
	printBreakdownBy("gene_count");
    } else {
    print "<p>Please click <font color='blue'><u>Display</u></font> to load the distribution of Biosynthetic Clusters by Gene Count.</p>";
    print "<input type='button' class='medbutton' "
        . "value='Display' onclick=\"$func\" />";
    }
    print "</span>";
    webLog( dateTimeStr() . " BCs - end gene_count\n" );
    print "</div>"; # end biostatstab7

    print "<div id='biostatstab8'>";
    webLog( dateTimeStr() . " start ec type\n" );
    printBreakdownBy("ec_type");
    webLog( dateTimeStr() . " end ec type\n" );
    print "</div>"; # end biostatstab8

    print "<div id='biostatstab9'>";
    webLog( dateTimeStr() . " start pfam\n" );
    printBreakdownBy("pfam");
    webLog( dateTimeStr() . " end pfam\n" );
    print "</div>"; # end biostatstab9

    #print "<div id='biostatstab10'>";
    #printBreakdownBy("kegg");
    #print "</div>"; # end biostatstab10

    TabHTML::printTabDivEnd();
    print end_form();
}

######################################################################
# printStats - overall statistics for biosynthetic clusters
######################################################################
sub printStats {
    my ($show_title) = @_;
    if ($show_title) {
        print "<h1>Biosynthetic Clusters - Summary Stats</h1>";
    }
    if ( !$enable_biocluster ) {
        webError("Biosynthetic Cluster not supported!");
    }

    printMainForm();    

    my $dbh = dbLogin();
    my $indent = nbsp(4);

    print "<table class='img' border='0' cellspacing='3' cellpadding='0'>\n";
    printf("<tr class='highlight'>\n");
    printf("<th class='subhead'><b>Biosynthetic Cluster (BC) Statistics</b></th>\n");
    printf("<th class='subhead' align='right'><b>Number</b></th>\n");
    printf("</tr>\n");

    my ( $totalCnt, %domain2cnt ) = getStatsByDomain( $dbh );

    printf("<tr class='img'>\n");
    printf("<td class='img'>%sTotal</td>\n", $indent);
    printf("<td class='img' align='right'>%s</td>\n", $totalCnt);
    printf("</tr>\n");

    my $withGB = getBCwithGenbankID( $dbh );
    my $withGBcnt = scalar(@$withGB);
    if ($withGBcnt > 0) {
	my $url = "$section_cgi&page=withGenbankID";
	printf("<tr class='img'>\n");
	printf("<td class='img'>%swith Genbank ID</td>\n", $indent . $indent);
	printf("<td class='img' align='right'>%s</td>\n", 
	       alink($url, $withGBcnt));
	printf("</tr>\n");
    }

    printf("<tr class='img'>\n");
    my $url_byBCType = "$section_cgi&page=byBCType";
    my $byBCType = alink($url_byBCType, "by BC Type");
    printf("<td class='img'>%s$byBCType</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    printf("<td class='img'>%sby Domain</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    foreach my $domain (sort(keys %domain2cnt)) {
        my $cluster_cnt = $domain2cnt{$domain};
        my $url;
        if ($cluster_cnt > 0) {
            $url = "$section_cgi&page=byGenome&domain=$domain";
        }
        printf("<tr class='img'>\n");
        my $domain_name = $domain;
        if ($domain eq '*Microbiome') {
            $domain_name = "metagenomes";
        }
        printf("<td class='img'>%sin $domain_name</td>\n", $indent . $indent . $indent);
        printf("<td class='img' align='right'>%s</td>\n", alink($url, $cluster_cnt));
        printf("</tr>\n");        
    }

    printf("<tr class='img'>\n");
    my $byPhylum = alink("$section_cgi&page=byPhylum", "by Phylum");
    printf("<td class='img'>%s$byPhylum</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    my $byGenome = alink("$section_cgi&page=byGenome", "by Genome");
    printf("<td class='img'>%s$byGenome</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    my $byGeneCount = alink( "$section_cgi&page=byGeneCount", "by Gene Count");
    printf("<td class='img'>%s$byGeneCount</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    my $byProbability = alink("$section_cgi&page=byProbability", "by Probability");
    printf("<td class='img'>%s$byProbability</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    my ($npTypeExpCnt, $npTypePredCnt, $npTypeUnknownCnt, $npIdExpCnt,
	$npIdPredCnt, $npIdUnknownCnt) = getStatsByNp( $dbh );
                
    printf("<tr class='img'>\n");
    my $url_byNpId = "$section_cgi&page=byNpId";
    my $byNaturalProduct = alink( $url_byNpId, "by Secondary Metabolite");
    printf("<td class='img'>%s$byNaturalProduct</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    printf("<td class='img'>%swith Experimentally Verified Secondary Metabolite</td>\n", $indent . $indent . $indent );
    printf("<td class='img' align='right'>%s</td>\n", alink( "$url_byNpId&evidence=Experimental", $npIdExpCnt));
    printf("</tr>\n");

    if ($npIdPredCnt) {
	printf("<tr class='img'>\n");
	printf("<td class='img'>%swith Predicted Secondary Metabolite</td>\n", $indent . $indent . $indent);
	printf("<td class='img' align='right'>%s</td>\n", alink( "$url_byNpId&evidence=Predicted", $npIdPredCnt));
	printf("</tr>\n");
    }

    printf("<tr class='img'>\n");
    printf("<td class='img'>%swith No Secondary Metabolite</td>\n", $indent . $indent . $indent);
    if ($npIdUnknownCnt) {
        printf("<td class='img' align='right'>%s</td>\n", alink( "$url_byNpId&np=$unknown", $npIdUnknownCnt));
    } else {
        printf("<td class='img' align='right'>%s</td>\n", $npIdUnknownCnt);
    }
    printf("</tr>\n");

    printf("<tr class='img'>\n");
    my $url_byNpType = "$section_cgi&page=byNpType";
    my $byNaturalProductType = alink($url_byNpType, "by Secondary Metabolite Type");
    printf("<td class='img'>%s$byNaturalProductType</td>\n", $indent . $indent);
    printf("<td class='img' align='right'>%s</td>\n", $indent);
    printf("</tr>\n");

    print "</table>\n";

    print end_form();
}

sub getBCwithGenbankID {
    my ( $dbh ) = @_;
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
    my @cluster_ids;

    my $sql = qq{
        select distinct bcd.cluster_id
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bc.cluster_id = bcd.cluster_id
        and bcd.genbank_acc is not null
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($bc_id) = $cur->fetchrow();
        last if !$bc_id;
	push @cluster_ids, $bc_id;
    }
    $cur->finish();

    my $clusterClause;
    if (scalar(@cluster_ids) > 0) {
        my $cluster_ids_str = 
	    OracleUtil::getFuncIdsInClause($dbh, @cluster_ids);
        $clusterClause = " and cluster_id in ($cluster_ids_str) ";
    }

    my $sql = qq{
        select distinct cluster_id
        from bio_cluster_data_new
        where evidence = 'Experimental'
        $clusterClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    my @clusters;
    for ( ;; ) {
        my ($bc_id) = $cur->fetchrow();
        last if !$bc_id;
	push @clusters, $bc_id;
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
	if ( $clusterClause =~ /gtt_func_id/i );

    return \@clusters;
}

sub printClustersWithGenbankID {
    print "<h1>Biosynthetic Clusters (BC) with Genbank ID</h1>";
    print "<p>Evidence: Experimental</p>";

    my $dbh = dbLogin();
    my $clusters_aref = getBCwithGenbankID($dbh);
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    my $clusterClause;
    if (scalar(@$clusters_aref) > 0) {
        my $cluster_ids_str =
	    OracleUtil::getFuncIdsInClause($dbh, @$clusters_aref);
        $clusterClause = " and bcd.cluster_id in ($cluster_ids_str) ";
    }

    my $sql = qq{
        select distinct bcd.cluster_id, bcd.genbank_acc,
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_data_new bcd, bio_cluster_new bc, taxon tx
        where bcd.genbank_acc is not null
        and bc.cluster_id = bcd.cluster_id
        and bc.taxon = tx.taxon_oid
        $clusterClause
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);

    my $it = new InnerTable( 1, "withgenbankid$$", "withgenbankid", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc", "right" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    $it->addColSpec( "Genbank ID",  "asc", "left" );

    print start_form(-id     => "bcwgenbank_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $cnt = 0;
    for ( ;; ) {
        my ($bc_id, $genbank_id, $taxon_oid, $taxon_name) = $cur->fetchrow();
        last if !$bc_id;

        my $url = "$main_cgi?section=BiosyntheticDetail"
                . "&page=cluster_detail&cluster_id=$bc_id";
	my $txurl = "$main_cgi?section=TaxonDetail"
	          . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
        $row .= $sd . "<input type='checkbox' name='bc_id' value='$bc_id' />\t";
        $row .= $bc_id . $sd . alink($url, $bc_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
        $row .= $genbank_id . $sd . 
	        alink("${ncbi_base_url}$genbank_id", $genbank_id) . "\t";
        $it->addRow($row);
        $cnt++;
    }
    $cur->finish();

    $it->hideAll() if $cnt < 50;
    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bcwgenbank_frm") if $cnt > 10;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bcwgenbank_frm");

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
	if ( $clusterClause =~ /gtt_func_id/i );

    printStatusLine("$cnt clusters with genbank id. ", 2);
    print end_form();
}

sub getBC2Evidence {
    my ($dbh, $rclause, $imgClause, $clusterClause) = @_;

    my $sql = qq{
        select distinct bcd.cluster_id, bcd.evidence
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bcd.evidence is not null
        and bc.cluster_id = bcd.cluster_id
        $rclause
        $imgClause
        $clusterClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    my %bc2evidence;
    my %bc2tx;
    for ( ;; ) {
        my ($bc_id, $attr_val) = $cur->fetchrow();
        last if !$bc_id;
        $bc2evidence{ $bc_id } = $attr_val;
    }
    $cur->finish();
    return \%bc2evidence;
}

sub getStatsByDomain {
    my ( $dbh ) = @_;

    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClauseNoTaxon("tx");

    my $sql = qq{
        select tx.domain, count(distinct g.cluster_id)
        from bio_cluster_new g, taxon tx
        where g.taxon = tx.taxon_oid
        $rclause
        $imgClause
        group by tx.domain
    };
    my $cur = execSql($dbh, $sql, $verbose);
    
    my $totalCnt;
    my %domain2cnt;
    for ( ;; ) {
        my ($domain, $cluster_cnt) = $cur->fetchrow();
        last if(!$domain && !$cluster_cnt);
        $domain2cnt{$domain} = $cluster_cnt if($domain);
        $totalCnt += $cluster_cnt;
    }
    $cur->finish();
    
    return ($totalCnt, %domain2cnt);
}

sub getStatsByNp {
    my ( $dbh ) = @_;
        
    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

    my $sql = qq{
        select np.np_type, np.np_id, np.evidence, count(distinct g.cluster_id)
        from bio_cluster_new g
        left join 
             (select c.np_class np_type, c.compound_oid np_id,
                     npbs.cluster_id cluster_id, bcd.evidence evidence
              from np_biosynthesis_source npbs, img_compound c,
                   bio_cluster_data_new bcd
              where npbs.compound_oid = c.compound_oid
              and npbs.cluster_id = bcd.cluster_id
              and bcd.evidence is not null ) np 
        on g.cluster_id = np.cluster_id
        where 1 = 1
        $rclause
        $imgClause
        group by np.np_type, np.np_id, np.evidence
    };
    my $cur = execSql($dbh, $sql, $verbose);
    
    my $npTypeExpCnt;
    my $npTypePredCnt;
    my $npTypeUnknownCnt;    
    my $npIdExpCnt;
    my $npIdPredCnt;
    my $npIdUnknownCnt;
    for ( ;; ) {
        my ( $np_type, $np_id, $evidence, $cluster_cnt ) = $cur->fetchrow();
        last if (! $np_type && ! $np_id && ! $evidence && !$cluster_cnt);
        $np_type = $unknown if (! $np_type);
        $np_id = $unknown if (! $np_id);

        if ( $evidence eq 'Experimental' ) {
            $npTypeExpCnt += $cluster_cnt;                
            if ( $np_type eq $unknown ) {
                $npTypeUnknownCnt += $cluster_cnt;
            }

            $npIdExpCnt += $cluster_cnt;
            if ( $np_id eq $unknown ) {
                $npIdUnknownCnt += $cluster_cnt;
            }
        }
        elsif ( $evidence eq 'Predicted' ) {
            $npTypePredCnt += $cluster_cnt;                
            if ( $np_type eq $unknown ) {
                $npTypeUnknownCnt += $cluster_cnt;
            }

            $npIdPredCnt += $cluster_cnt;
            if ( $np_id eq $unknown ) {
                $npIdUnknownCnt += $cluster_cnt;
            }
        }
        else {
            if ( $np_type eq $unknown ) {
                $npTypeUnknownCnt += $cluster_cnt;
            }
            if ( $np_id eq $unknown ) {
                $npIdUnknownCnt += $cluster_cnt;
            }
        }
    }
    $cur->finish();

    return ($npTypeExpCnt, $npTypePredCnt, $npTypeUnknownCnt,
	    $npIdExpCnt, $npIdPredCnt, $npIdUnknownCnt);
}

######################################################################
# printStatsByGenome
######################################################################
sub printStatsByGenome {
    if ( !$enable_biocluster ) {
        webError("Biosynthetic Cluster not supported!");
    }
    my $domain = param("domain");
    my $phylum = param("phylum");
    my $dbh = dbLogin();

    my ($extracolumn_href, $extracollink_href) = 
	fetchGenome2BioClusterCountMapping( $dbh, $domain );
    my @taxon_oids = keys %$extracolumn_href;
    
    my $title;
    if ($domain) {
        $title = "Biosynthetic Clusters (BC) in $domain";
    } else {
        $title = "Biosynthetic Clusters (BC) by Genome";
    }

    HtmlUtil::printGenomeListHtmlTable
    ( $title, '', $dbh, \@taxon_oids, '', '', 
      'Biosynthetic Clusters', $extracolumn_href,
      $extracollink_href, "right" );
}

sub fetchGenome2BioClusterCountMapping {
    my ( $dbh, $domain, $taxon_oids_ref ) = @_;

    my $phylum = 0;
    my ($dm, $ph) = split(":", $domain);
    if ($dm eq "*Microbiome") {
	# metagenomes are passed one level deeper
	$domain = $dm;
	$phylum = $ph;
    }

    my $taxonClause;
    my $sql;
    my $cur;
    if ( $domain ) {
        $taxonClause = " and tx.domain = ? ";        
	$taxonClause .= " and tx.phylum = ? " if $phylum; 
        my $rclause = WebUtil::urClause("tx");
        my $imgClause = WebUtil::imgClause("tx");

        $sql = qq{
            select g.taxon, count(distinct g.cluster_id)
            from bio_cluster_new g, taxon tx
            where g.taxon = tx.taxon_oid
            $taxonClause
            $rclause
            $imgClause
            group by g.taxon
        };

	if ($phylum) {
	    $cur = execSql($dbh, $sql, $verbose, $domain, $phylum);
	} else {
	    $cur = execSql($dbh, $sql, $verbose, $domain);
	}

    } else {
        if ( $taxon_oids_ref ne '' && scalar(@$taxon_oids_ref) > 0 ) {
            my $taxonInnerClause = 
            OracleUtil::getNumberIdsInClause( $dbh, @$taxon_oids_ref );
            $taxonClause = " and g.taxon in ( $taxonInnerClause ) ";
        }
        my $rclause = WebUtil::urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

        $sql = qq{
            select g.taxon, count(distinct g.cluster_id)
            from bio_cluster_new g
            where 1 = 1
            $taxonClause
            $rclause
            $imgClause
            group by g.taxon
        };
        $cur = execSql($dbh, $sql, $verbose);     
    }

    my $extraurl_base = "$main_cgi?section=BiosyntheticDetail&page=biosynthetic_clusters";

    my %extracolumn;
    my %extracollink;
    for ( ;; ) {
        my ($taxon, $cluster_cnt) = $cur->fetchrow();
        last if(!$taxon);

        my $extraurl = $extraurl_base . "&taxon_oid=$taxon";
        my $link = alink($extraurl, $cluster_cnt);
        $extracollink{$taxon} = $link;

        if ( exists $extracolumn{$taxon} ) {
            $cluster_cnt = $extracolumn{$taxon} . " <br/> " . $cluster_cnt;
        }
        $extracolumn{$taxon} = $cluster_cnt;
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
    if ( $taxonClause =~ /gtt_num_id/i );

    return (\%extracolumn, \%extracollink);
}

######################################################################
# printStatsByBCType
######################################################################
sub printStatsByBCType {
    my ($show_title) = @_;
    if ($show_title) {
	print "<h1>Biosynthetic Clusters by BC Type</h1>";
    }
    my $dbh = dbLogin();

    # get all human-readable BC type terms
    my %bc_typ_h;
    my $sql2 = "select bc_code, bc_desc from bc_type";
    my $cur2 = execSql($dbh, $sql2, $verbose);
    for ( ;; ) {
        my ($bc_code, $bc_desc) = $cur2->fetchrow();
        last if !$bc_code;
	$bc_typ_h{$bc_code} = $bc_desc;
    }
    $cur2->finish();

    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    my @ecluster_ids;
    my $sql = qq{
        select distinct bcd.cluster_id
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bcd.evidence = 'Experimental'
        and bc.cluster_id = bcd.cluster_id
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($bc_id) = $cur->fetchrow();
        last if !$bc_id;
        push @ecluster_ids, $bc_id;
    }
    $cur->finish();

    my $clusterClause;
    if (scalar(@ecluster_ids) > 0) {
        my $cluster_ids_str =
	    OracleUtil::getFuncIdsInClause($dbh, @ecluster_ids);
        $clusterClause = " and bc.cluster_id in ($cluster_ids_str) ";
    }

    # get the bc_type count for Experimental clusters:
    my $sql = qq{
        select bcd.bc_type, count (distinct bcd.cluster_id)
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bcd.bc_type is not null
        and bc.cluster_id = bcd.cluster_id
        $rclause
        $imgClause
        $clusterClause
        group by bcd.bc_type
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %bctype2expcnt;
    for ( ;; ) {
        my ($bctype, $expcnt) = $cur->fetchrow();
        last if !$expcnt;
	$bctype2expcnt{ $bctype } = $expcnt;
    }

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
	if ( $clusterClause =~ /gtt_func_id/i );

    my $sql = qq{
        select bcd.bc_type, count (distinct bcd.cluster_id) 
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bcd.bc_type is not null
        and bc.cluster_id = bcd.cluster_id
        $rclause
        $imgClause
        group by bcd.bc_type
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    printMainForm();

    my $it = new InnerTable(1, "statsbybctype$$", "statsbybctype", 0);
    my $sd = $it->getSdDelim();
    $it->hideAll() if !$show_title;

    $it->addColSpec( "BC Type",  "asc",  "left" );
    $it->addColSpec( "Total Clusters", "desc", "right" );
    $it->addColSpec( "Experimental BC", "desc", "right" );
    $it->addColSpec( "Predicted BC", "desc", "right" );

    my $cnt = 0;
    my $url_section = "$section_cgi&page=clustersByBCType";
    for ( ;; ) {
        my ($bctype, $total_clusters) = $cur->fetchrow();
        last if !$total_clusters;

	my $trans_bctype = translateBcType($bctype, \%bc_typ_h);
	my $row = $trans_bctype . "\t";  # display human readable type
	my $link = $total_clusters;
	my $bct = WebUtil::massageToUrl2($bctype);
	if ($total_clusters) {
	    $link = alink($url_section."&bc_type=$bct",
			  $total_clusters, "_blank");
	}
        $row .= $total_clusters . $sd . $link . "\t";

	my $expcnt = $bctype2expcnt{ $bctype };
	$expcnt = 0 if $expcnt eq "";
	$link = $expcnt;
        if ($expcnt) {
            $link = alink($url_section."&bc_type=$bct&evidence=Experimental",
                          $expcnt, "_blank");
        }
	$row .= $expcnt . $sd . $link . "\t";

	my $pcnt = $total_clusters - $expcnt;
	$link = $pcnt;
        if ($pcnt) {
            $link = alink($url_section."&bc_type=$bct&evidence=Predicted",
                          $pcnt, "_blank");
        }
	$row .= $pcnt . $sd . $link . "\t";

        $it->addRow($row);
	$cnt++;
    }
    $cur->finish();

    if ($cnt > 0) {
	$it->printOuterTable(1);
    } else {
	print "<img src='$base_url/images/error.gif' "
	    . "width='46' height='46' alt='Error' />";
	print "<p>Could not find BC Types.";
    }

    print end_form;
    printStatusLine("$cnt bc types. ", 2) if $show_title;
}

sub translateBcType {
    my ($bc_type, $href) = @_;

    my $str = "";
    for my $t2 ( split(/\;/, $bc_type) ) {
	my $res2 = $t2;
	if ( $href->{$t2} ) {
	    $res2 = $href->{$t2};
	}

	if ( $str ) {
	    $str .= ";" . $res2;
	}
	else {
	    $str = $res2;
	}
    }

    return $str;
}
	
######################################################################
# printStatsByNp
######################################################################
sub printStatsByNp {
    my ( $isType, $evidence0 ) = @_;
    
    if ( !$enable_biocluster ) {
        webError("Biosynthetic Cluster not supported!");
    }

    my $affix;
    if ( $isType ) {
        $affix = "Type";
    }
    else {
        $affix = "ID";        
    }

    printMainForm();    
    print "<h1>Biosynthetic Clusters (BC) by Secondary Metabolite (SM) $affix</h1>" 
	if $evidence0 eq "";

    my $np = param("np");
    my $evidence = param("evidence");
    $evidence = $evidence0 if !$evidence;

    if ( $np || $evidence ) {
        print "<p>";
        print "<u>Secondary Metabolite $affix</u>: $np<br/>" if ( $np );
        print "<u>Evidence</u>: $evidence" if ( $evidence );
        print "</p>";        
    }

    if ($isType) {
	require MeshTree;
        MeshTree::printTreeBcDiv();
	return;
    }

    my %np_name_h;
    my $dbh = dbLogin();
    if ( ! $isType ) {
	my $sql = "select compound_oid, compound_name from img_compound";
	my $cur = execSql($dbh, $sql, $verbose);
	for ( ;; ) {
	    my ($cpd_id, $cpd_name) = $cur->fetchrow();
	    last if ! $cpd_id;
	    $np_name_h{$cpd_id} = $cpd_name;
	}
	$cur->finish();
    }

    my ($sql, @binds)  = getStatsSqlByNp( $isType, $np, $evidence );
    my $cur = execSql($dbh, $sql, $verbose, @binds);

    my %np2predCnt;
    my %np2expCnt;
    my %np2noEvidenceCnt;
    my %done;    
    for ( ;; ) {
        my ( $np, $evidence, $cluster_cnt ) = $cur->fetchrow();
        last if (! $np && ! $evidence && ! $cluster_cnt);
        $np = $unknown if (! $np);
        $evidence = $unknown if (! $evidence);

        if ( $evidence eq 'Experimental' ) {
            $np2expCnt{$np} += $cluster_cnt;
            $done{$np} = 1;
        }
        elsif ( $evidence eq 'Predicted' ) {
            $np2predCnt{$np} += $cluster_cnt;            
            $done{$np} = 1;
        }
        elsif ( $evidence eq $unknown ) {
            $np2noEvidenceCnt{$np} += $cluster_cnt;            
            $done{$np} = 1;
        }
    }
    $cur->finish();
    
    my $st = -1;
    my $chart;

    if ($evidence eq 'Experimental' && $isType) {
	my $url2 = "$section_cgi&page=clustersByNpType&evidence=Experimental";
	#### PREPARE THE PIECHART ######
	$chart = newPieChart();
	$chart->WIDTH(300);
	$chart->HEIGHT(300);
	$chart->INCLUDE_LEGEND("no");
	$chart->INCLUDE_TOOLTIPS("yes");
	$chart->INCLUDE_URLS("yes");
	$chart->ITEM_URL($url2);
	$chart->INCLUDE_SECTION_URLS("yes");
	$chart->URL_SECTION_NAME("np");
	my @chartseries;
	my @chartcategories;
	my @chartdata;

	foreach $np (keys %np2expCnt) {
	    my $expCnt = $np2expCnt{$np};
	    push @chartcategories, $np;
	    push @chartdata, $expCnt;
	}

	push @chartseries, "count";
	$chart->SERIES_NAME( \@chartseries );
	$chart->CATEGORY_NAME( \@chartcategories );
	$chart->URL_SECTION( \@chartcategories );
	my $datastr = join( ",", @chartdata );
	my @datas = ($datastr);
	$chart->DATA( \@datas );

	$st = -1;
	if ( $env->{chart_exe} ne "" ) {
	    $st = generateChart($chart);
	}
    }

    my $charOrNum;
    my $leftOrRight;
    if ( $isType ) {
        $charOrNum = "asc";
        $leftOrRight = "left";
    }
    else {
        $charOrNum = "asc";
        $leftOrRight = "right";
    }

    my $it = new InnerTable(1, "bynplist$$", "bynplist", 0); 
    $it->addColSpec( "SM $affix", $charOrNum, $leftOrRight );
    if ( ! $isType ) {
	$it->addColSpec( "Secondary Metabolite (SM)<br/>Name", "asc", "left" );
    }
    if ( $evidence eq 'Experimental' || ! $evidence ) {
        $it->addColSpec( "Experimentally Verified<br/> Biosynthetic Clusters", "asc", "right" ); 
    }
    if ( $evidence eq 'Predicted' || ! $evidence ) {
        $it->addColSpec( "Predicted<br/> Biosynthetic Clusters", "asc", "right" );         
    }
    if ( $evidence eq $unknown || ! $evidence ) {
        $it->addColSpec( "No Evidence<br/> Biosynthetic Clusters", "asc", "right" );
    }
    my $sd = $it->getSdDelim();

    my $clustersBy;
    if ( $isType ) {
        $clustersBy = "clustersByNpType";
    } else {
        $clustersBy = "clustersByNpId";
    }

    my $url = "$section_cgi&page=$clustersBy";
    my $cnt = 0;
    foreach my $np (keys %done) {
        my $r;

        if ( $st == 0 ) { # add colored link -anna
            my $imageref = "<img src='$tmp_url/" 
		. $chart->FILE_PREFIX . "-color-" . $cnt . ".png' border=0>";
            $r = escHtml($np) . $sd 
	       . alink("$url&np=$np&evidence=Experimental", $imageref, "", 1);
            $r .= "&nbsp;&nbsp;";
        }
        if ( ! $isType && WebUtil::isInt($np) ) {
            my $npid_url = "main.cgi?section=ImgCompound" .
		           "&page=imgCpdDetail&compound_oid=$np";
            $r .= $np . $sd . alink($npid_url, $np) . "\t";
	    my $np_name = $np_name_h{$np};
            $r .= $np_name . $sd . $np_name . "\t";
        } else {
            $r .= $np . $sd . $np . "\t";
        }
        
        if ( $evidence eq 'Experimental' || ! $evidence ) {
            my $expCnt = $np2expCnt{$np};
            if ( $expCnt > 0 ) {
                $r .= $expCnt . $sd . alink("$url&np=$np&evidence=Experimental", $expCnt) . "\t";
            } else {
                $r .= $sd . "\t";
            }    
        }

        if ( $evidence eq 'Predicted' || ! $evidence ) {
            my $predCnt = $np2predCnt{$np};
            if ( $predCnt > 0 ) {
                $r .= $predCnt . $sd . alink("$url&np=$np&evidence=Predicted", $predCnt) . "\t";
            } else {
                $r .= $sd . "\t";
            }
        }

        if ( $evidence eq $unknown || ! $evidence ) {
            my $noEvidenceCnt = $np2noEvidenceCnt{$np};
            if ( $noEvidenceCnt > 0 ) {
                $r .= $noEvidenceCnt . $sd . $noEvidenceCnt . "\t";
            } else {
                $r .= $sd . "\t";
            }
        }

        $it->addRow($r);
        $cnt++;
    }

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    $it->hideAll() if $cnt < 50;
    $it->printOuterTable(1);

    # add pie chart
    print "<td valign=top align=left>\n";
    if ( $env->{chart_exe} ne "" && $chart ne "" ) {
        if ( $st == 0) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "statsByNpType", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/" . $chart->FILE_PREFIX . ".png' BORDER=0";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    print "</td></tr>\n";
    print "</table>\n";

    print end_form();
    printStatusLine("$cnt Secondary Metabolite $affix loaded.", 2);    
}

sub getStatsSqlByNp {
    my ( $isType, $np, $evidence ) = @_;

    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

    my @binds;

    my $field;
    if ( $isType ) {
        $field = "np.np_type";
    }
    else {
        $field = "np.np_id";
    }

    my $npClause;
    if ( $np ) {
        if ( $np eq $unknown ) {
            $npClause = " and $field is null ";
        }
        else {
            $npClause = " and $field = ? ";
            push(@binds, $np);
        }        
    }
    
    my $evidenceClause;
    if ( $evidence ) {
        if ( $evidence eq $unknown ) {
            $evidenceClause = " and np.evidence is null ";
        }
        else {
            $evidenceClause = " and np.evidence = ? ";
            push(@binds, $evidence);
        }        
    }
    
    my $sql = qq{
        select $field, np.evidence, count(distinct g.cluster_id)
        from bio_cluster_new g
        left join 
            (select c.np_class np_type, c.compound_oid np_id,
                    npbs.cluster_id cluster_id, bcd.evidence evidence
             from np_biosynthesis_source npbs, img_compound c,
                  bio_cluster_data_new bcd
             where npbs.compound_oid = c.compound_oid
             and npbs.cluster_id = bcd.cluster_id
             and bcd.evidence is not null ) np
             on g.cluster_id = np.cluster_id
        where 1 = 1
        $npClause
        $evidenceClause
        $rclause
        $imgClause
        group by $field, np.evidence
    };
    #print "getStatsSqlByNp() sql=$sql, binds=@binds<br/>\n";
    
    return ($sql, @binds);
}

######################################################################
# printClustersByNp
######################################################################
sub printClustersByNp {
    my ( $isType ) = @_;
    if ( !$enable_biocluster ) {
        webError("Biosynthetic Cluster not supported!");
    }
    
    my $np = param("np");
    my $evidence = param("evidence");

    my ($sql, @binds) = getClustersSqlByNp($np, $evidence, $isType);
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my @clusters;
    for ( ;; ) {
        my ( $cluster_id, $taxon, $cnt ) = $cur->fetchrow();
        last if !$cluster_id;
        push(@clusters, $cluster_id);
    }
    $cur->finish();

    my $affix;
    if ( $isType ) {
        $affix = "Type";
    } else {
        $affix = "ID";        
    }

    my $title = "Biosynthetic Clusters (BC) for Secondary Metabolite (SM) $affix";
    my $nplink = $np;
    if ( ! $isType && WebUtil::isInt($np) ) {
        my $npid_url = "main.cgi?section=ImgCompound" .
	               "&page=imgCpdDetail&compound_oid=$np";
        $nplink = alink($npid_url, $np);            
    }
    my $subTitle = qq{
        <u>Secondary Metabolite $affix</u>: $nplink<br/>
        <u>Evidence</u>: $evidence
    };

    BiosyntheticDetail::processBiosyntheticClusters
	( $dbh, '', \@clusters, '', $title, $subTitle );
}

sub getClustersSqlByNp {
    my ( $np, $evidence, $isType ) = @_;

    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

    my @binds;

    my $field;
    if ( $isType ) {
        $field = "np.np_type";
    } else {
        $field = "np.np_id";
    }

    my $npClause;
    if ( $np ) {
        if ( $np eq $unknown ) {
            $npClause = " and $field is null ";
        }
        else {
            $npClause = " and $field = ? ";
            push(@binds, $np);
        }
    }
    
    my $evidenceClause;
    if ( $evidence ) {
        if ( $evidence eq $unknown ) {
            $evidenceClause = " and np.evidence is null ";
        }
        else {
            $evidenceClause = " and np.evidence = ? ";
            push(@binds, $evidence);
        }        
    }
        
    my $sql = qq{
        select g.cluster_id, g.taxon, count(bcf.feature_id)
        from bio_cluster_new g
        left join 
            (select c.np_class np_type, c.compound_oid np_id,
                    npbs.cluster_id cluster_id, bcd.evidence evidence
             from np_biosynthesis_source npbs, img_compound c,
                   bio_cluster_data_new bcd
             where npbs.compound_oid = c.compound_oid
             and npbs.cluster_id = bcd.cluster_id
             and bcd.evidence is not null ) np
             on g.cluster_id = np.cluster_id
        left join bio_cluster_features_new bcf on g.cluster_id = bcf.cluster_id 
        where 1 = 1
        $npClause
        $evidenceClause
        $rclause
        $imgClause
        group by g.cluster_id, g.taxon
    };
    #print "getClustersSqlByNp() sql=$sql, binds=@binds<br/>\n";
    
    return ($sql, @binds);
}

######################################################################
# printStatsByProbability - shows the count of clusters that have the
#                           given probability score
######################################################################
sub printStatsByProbability {
    my ($gene_count, $phylum, $title) = @_;
    # by Probability (e.g. 1.0 - 0.9) - Clusters
    $gene_count = param("gene_count") if $gene_count eq "";
    $phylum = param("phylum") if $phylum eq "";
    $title = 1 if $title eq "";

    if ($title) {
	print "<h1>Biosynthetic Clusters (BC) by Probability</h1>";
	my ($dm, $ph, $irc) = split("#", $phylum);
	my $phylumStr = $phylum;
	if ($dm eq "*Microbiome") {
	    $phylumStr = $dm.":".$ph.":".$irc;
	}
	if ($gene_count ne "" && $phylum ne "") {
	    print "<p><u>Gene Count</u>: $gene_count";
	    print "<br/><u>Phylum</u>: $phylumStr";
	    print "</p>";
	} elsif ($gene_count ne "") {
	    print "<p><u>Gene Count</u>: $gene_count</p>";
	} elsif ($phylum ne "") {
	    print "<p><u>Phylum</u>: $phylumStr</p>";
	}
    }

    my $dofilter;
    $dofilter = "gene count" if $gene_count eq "";
    $dofilter = "phylum" if $phylum eq "";
    $dofilter = "gene count or phylum" if $gene_count eq "" && $phylum eq "";
    print "<p>You may select a probability score to filter the clusters further by $dofilter</p>" if $dofilter ne "";

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
    my $clusterClause = getClusterClause("", $gene_count, $phylum);

    my $sql = qq{
        select round(bcd.probability, 1),
               count(distinct bcd.cluster_id)
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bcd.probability is not null
        and bc.cluster_id = bcd.cluster_id
        $rclause
        $imgClause
        $clusterClause
        group by round(bcd.probability, 1)
        order by round(bcd.probability, 1)
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    printMainForm();

    my $it = new InnerTable(1, "statsbyprob$$", "statsbyprob", 1);
    my $sd = $it->getSdDelim();
    $it->hideAll();

    $it->addColSpec( "Choose" ) if $dofilter ne "";
    $it->addColSpec( "Probability", "asc", "right" );
    $it->addColSpec( "Clusters", "", "right" );

    # probability score is rounded using floor
    my $url_section = "$section_cgi&page=clustersByProbability"
                    . "&gene_count=$gene_count&phylum="
		    . WebUtil::massageToUrl2($phylum);
    for ( ;; ) {
	my ($probability, $total_clusters) = $cur->fetchrow();
	last if !$total_clusters;

	my $prb = sprintf("%.1f", $probability);
	my $row;
	$row = $sd .
	    "<input type='radio' name='probability' value='$prb'/>\t"
	    if $dofilter ne "";
	$row .= $prb . "\t";

        my $link = $total_clusters;
        if ($total_clusters && $total_clusters < $UPPER_LIMIT) {
            $link = alink($url_section."&probability=$prb",
                          $total_clusters, "_blank");
        }
        $row .= $total_clusters . $sd . $link . "\t";

	$it->addRow($row);
    }

    $it->printOuterTable(1);

    if ($gene_count eq "") {
        print hiddenVar('phylum', $phylum);
        my $name = "_section_${section}_byGeneCount";
        my $title = "Filter by Gene Count";
        print submit(
            -name  => $name,
            -value => $title,
            -class => "meddefbutton"
	);
	print nbsp(1);
    }

    if ($phylum eq "") {
	print hiddenVar('gene_count', $gene_count);
        my $name = "_section_${section}_byPhylum";
        my $title = "Filter by Phylum";
        print submit(
            -name  => $name,
            -value => $title,
            -class => "meddefbutton"
	);
    }

    print end_form();
}

######################################################################
# printStatsByGeneCount - shows the count of clusters that have
#                         a given gene count range
######################################################################
sub printStatsByGeneCount {
    my ($probability, $phylum, $title) = @_;
    # by Gene Count (e.g. 1 to 10) - Predicted Clusters - Exp verified Clusters
    $probability = param("probability") if $probability eq "";
    $phylum = param("phylum") if $phylum eq "";
    $title = 1 if $title eq "";

    my $phylumStr = $phylum;
    my ($dm, $ph, $irc) = split("#", $phylum);
    if ($dm eq "*Microbiome") {
	$phylumStr = $dm.":".$ph.":".$irc;
    }
    my $sort = 2;
    if ($title) {
	print "<h1>Biosynthetic Clusters (BC) by Gene Count</h1>";
	if ($probability ne "" && $phylum ne "") {
	    $sort = 1;
	    print "<p><u>Probability</u>: $probability";
	    print "<br/><u>Phylum</u>: $phylumStr";
	    print "</p>";
	} elsif ($probability ne "") {
	    print "<p><u>Probability</u>: $probability</p>";
	} elsif ($phylum ne "") {
	    print "<p><u>Phylum</u>: $phylumStr</p>";
	}
    }

    my $dofilter = "";
    $dofilter = "probability" if $probability eq "";
    $dofilter = "phylum" if $phylum eq "";
    $dofilter = "probability or phylum" if $probability eq "" && $phylum eq "";
    print "<p>You may select a gene count range to filter the clusters further by $dofilter</p>" if $dofilter ne "";

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
    my $clusterClause = getClusterClause($probability, "", $phylum);

    my $sql = qq{
        select mstat.cluster_id, mstat.gene_count
        from mv_bio_cluster_stat mstat
        where mstat.cluster_id is not null
    };
    my $cur = execSql($dbh, $sql, $verbose);
    my %cluster2count;
    for ( ;; ) {
        my ($cluster_id, $gene_count) = $cur->fetchrow();
        last if !$cluster_id;
	$cluster2count{ $cluster_id } = $gene_count;
    }

    webError("No gene count data found.") if scalar keys %cluster2count == 0;

    my $sql = qq{
        select bcd.cluster_id, bcd.evidence
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bc.cluster_id = bcd.cluster_id
        and bcd.evidence is not null
        $rclause
        $imgClause
        $clusterClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    # get genecounts, bin by ranges
    my %e_clust2cnt;
    my %p_clust2cnt;
    my $hi = 0; my $lo = 0; my $idx = 0;

    for ( ;; ) {
	my ($cluster_id, $attribute) = $cur->fetchrow();
	last if !$cluster_id;
	my $gene_count = $cluster2count{ $cluster_id };
	next if (!$gene_count || $gene_count eq "");

	$lo = $gene_count if $idx == 0;
	$lo = $gene_count if $gene_count < $lo;
	$hi = $gene_count if $gene_count > $hi;

	if ($attribute eq "Experimental") {
	    $e_clust2cnt{ $cluster_id } = $gene_count;
	} elsif ($attribute eq "Predicted") {
	    $p_clust2cnt{ $cluster_id } = $gene_count;
	}

	$idx++;
    }

    my $numbins = ceil($hi/20);
    $numbins = 25 if $hi > 25000;

    my ($items_aref, $data_aref);
    my $exp_cnt = scalar keys %e_clust2cnt;
    if ($exp_cnt > 0) {
	($items_aref, $data_aref)
	    = binIt($numbins, $lo, $hi, \%e_clust2cnt, 0);
    }
    my @e_items = @$items_aref if $items_aref ne "";
    my @e_data = @$data_aref if $data_aref ne "";

    my $pred_cnt = scalar keys %p_clust2cnt;
    if ($pred_cnt > 0) {
	($items_aref, $data_aref)
	    = binIt($numbins, $lo, $hi, \%p_clust2cnt, 0);
    }
    my @p_items = @$items_aref if $items_aref ne "";
    my @p_data = @$data_aref if $data_aref ne "";

    my $str = "for ";
    $str .= $phylumStr if $phylum ne "";
    $str .= " and " if $phylum ne "" && $probability ne "";
    $str .= $probability if $probability ne "";

    webError("No data found $str.") if $exp_cnt == 0 && $pred_cnt == 0;

    printMainForm();

    my $it = new InnerTable(1, "statsbygenecnt$$", "statsbygenecnt", $sort);
    my $sd = $it->getSdDelim();
    $it->hideAll();

    $it->addColSpec( "Choose" ) if $dofilter ne "";
    $it->addColSpec( "Gene Count", "asc", "right" );
    $it->addColSpec( "Predicted Clusters", "desc", "right" )
	if $pred_cnt > 0;
    $it->addColSpec( "Experimentally Verified Clusters", "desc", "right" )
	if $exp_cnt > 0;

    my $url_section = "$section_cgi&page=clustersByGeneCount"
	            . "&probability=$probability&phylum="
		    . WebUtil::massageToUrl2($phylum);

    my $size = scalar @p_items;
    for (my $i=0; $i<$size; $i++) {
	my $key = $e_items[$i];
	my $pcnt = $p_data[$i];
	my $ecnt = $e_data[$i];
	next if $pcnt == 0 && $ecnt == 0;

	my $row;
	$row = $sd .
	    "<input type='radio' name='gene_count' value='$key'/>\t" 
	    if $dofilter ne "";

	$row .= $key . $sd . $key . "\t";

	if ($pred_cnt > 0) {
	    my $cnt = $p_data[$i];
	    $cnt = 0 if $cnt eq "";
	    my $link = $cnt;
	    if ($cnt && $cnt < $UPPER_LIMIT) {
		$link = alink($url_section."&attr=Predicted&gene_count=$key",
			      $cnt, "_blank");
	    }
	    $row .= $cnt . $sd . $link . "\t";
	}

	if ($exp_cnt > 0) {
	    my $cnt = $e_data[$i];
	    $cnt = 0 if $cnt eq "";
	    my $link = $cnt;
	    if ($cnt && $cnt < $UPPER_LIMIT) {
		$link = alink($url_section .
			      "&attr=Experimental&gene_count=$key",
			      $cnt, "_blank");
	    }
	    $row .= $cnt . $sd . $link . "\t";
	}

	$it->addRow($row);
    }

    $it->printOuterTable(1);

    if ($probability eq "") {
        print hiddenVar('phylum', $phylum);
        my $name = "_section_${section}_byProbability";
        my $title = "Filter by Probability";
        print submit(
            -name  => $name,
            -value => $title,
            -class => "meddefbutton"
        );
	print nbsp(1);
    }

    if ($phylum eq "") {
        print hiddenVar('probability', $probability);
        my $name = "_section_${section}_byPhylum";
        my $title = "Filter by Phylum";
        print submit(
            -name  => $name,
            -value => $title,
            -class => "meddefbutton"
        );
    }

    print end_form();
}

sub printStatsJS {
    print "<script src='$base_url/chart.js'></script>\n";
    print qq {
    <script type="text/javascript">
    function displayStats(url, div, id) {
        var e = document.getElementById(id);
        var val;
        if (e != null && e != undefined && e.type == 'select-one') {
            val = e.options[e.selectedIndex].value;
            url = url + '&genome_type=' + val;
        }

        YAHOO.namespace("example.container");
        if (!YAHOO.example.container.wait) {
            initializeWaitPanel();
        }
        //alert("calling displayStats: "+url);
        var callback = {
            success: statSuccess,
            argument: [div],
            failure: function(req) {
                YAHOO.example.container.wait.hide();
            }
        };

        if (url != null && url != "") {
            YAHOO.example.container.wait.show();
            var request = YAHOO.util.Connect.asyncRequest
                ('GET', url, callback);
        }
    }
    function statSuccess(req) {
        var bodyText;
        try {
            div = req.argument[0];
            //alert("statSuccess div: "+div);
            response = req.responseXML.documentElement;
            var maptext = response.getElementsByTagName
              ("maptext")[0].firstChild.data;

            //alert("Success!!! "+maptext);
            bodyText = maptext;
        } catch(e) {
        }
        var el = document.getElementById(div);
        el.innerHTML = bodyText;

        YAHOO.example.container.wait.hide();
    }
    </script>
    };
}

sub loadStats {
    my $type = param("type");
    my $genome_type = param("genome_type");

    print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    print qq{
        <response>
            <maptext><![CDATA[
    };

    printBreakdownBy($type, 0, $genome_type);

    print qq{
            ]]></maptext>
            <imagemap></imagemap>
        </response>
    };
}

sub printMyChart {
    my ($items_aref, $data_aref, $title, $yaxis, $url, $series, 
	$name, $param, $use_log, $orientation, $log_scale, $is_table) = @_;

    my @items = @$items_aref;
    my @data = @$data_aref;
    my $datastr = join(",", @data);
    my @datas = ($datastr);
    my @sections = @items;

    if (@items ne "" && @datas ne "" &&
	scalar @items > 0 && scalar @datas > 0) {
	print "<td padding=0 valign=top align=left>" if $is_table;
	print "$title<br/>";
	ChartUtil::printBarChart($name, $param, $yaxis,
				 $url, \@items, \@sections, \@datas,
				 $series, $use_log, $orientation,
				 $log_scale);
	print "</td>" if $is_table;
	print "<br/>" if !$is_table;
    }
}

sub titleForType {
    my ($type) = @_;
    if ($type eq "domain") {
	return "By Domain";
    } elsif ($type eq "phylum") {
	return "By Phylum";
    } elsif ($type eq "bc_type") {
	return "By BC Type";
    } elsif ($type eq "np_type") {
	return "By SM Type";
    } elsif ($type eq "length") {
	return "By Length";
    } elsif ($type eq "gene_count") {
	return "By Gene Count";
    } elsif ($type eq "ec_type") {
	return "By EC Type";
    } elsif ($type eq "pfam") {
	return "By Pfam";
    } else {
	return "";
    }
}

######################################################################
# printBreakdownBy - sets up data for bar charts for stats
######################################################################
sub printBreakdownBy {
    my ($type, $show_title, $genome_type) = @_;
    $show_title = 0 if $show_title eq "";
    if ($show_title) {
	my $title = titleForType($type);
        print "<h1>Biosynthetic Clusters - $title</h1>";
    }

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    my @series = ( "BC count" );
    my @items;
    my @sections;
    my @datas;
    my $url;
    my $name; 
    my $param;
    my $use_log = 0;
    my $log_scale = 0;
    my $orientation = "VERTICAL";

    my $cacheDir = "/webfs/scratch/img/bcNp/";
    if ($type eq "length" && $precomputed) {
	my $filename = "bcStats_byLength.stor";
	$filename = "bcStats_byLength_m.stor" if $genome_type eq "metagenome";
	$filename = "bcStats_byLength_i.stor" if $genome_type eq "isolate";
	my $file = $cacheDir . $filename;
	last if (!( -e $file ));

	my $state = retrieve($file);
	last if ( !defined($state) );

	my $items_aref = $state->{items};
	my $e_items_aref = $state->{items_e};
	my $p_items_aref = $state->{items_p};
	my $data_aref = $state->{data};
        my $e_data_aref = $state->{data_e};
        my $p_data_aref = $state->{data_p};

        $name = "Seq Length (bps)";
        $param = "range";
        $url = "$section_cgi&page=clustersByLength&genome_type=$genome_type";
        $log_scale = 0;
	my $yaxis = "Number of BCs";

	print "<p>";
	my $title = "Total Clusters";
	printMyChart($items_aref, $data_aref, $title, $yaxis, $url, \@series, 
		     $name, $param, $use_log, $orientation, $log_scale, 0);

	$title = "Experimentally verified Clusters";
	printMyChart($e_items_aref, $e_data_aref, $title, $yaxis,
		     $url."&attr=Experimental", \@series, 
		     $name, $param, $use_log, $orientation, $log_scale, 0);

	my $title = "Predicted Clusters";
	printMyChart($p_items_aref, $p_data_aref, $title, $yaxis,
		     $url."&attr=Predicted", \@series, 
		     $name, $param, $use_log, $orientation, $log_scale, 0);
        print "</p>";
	return;

    } elsif ($type eq "gene_count" && $precomputed) {
        my $filename = "bcStats_byGeneCount.stor";
	$filename = "bcStats_byGeneCount_m.stor" if $genome_type eq "metagenome";
	$filename = "bcStats_byGeneCount_i.stor" if $genome_type eq "isolate";
        my $file = $cacheDir . $filename;
        last if (!( -e $file ));

        my $state = retrieve($file);
        last if ( !defined($state) );

	my $items_aref = $state->{items};
	my $e_items_aref = $state->{items_e};
	my $p_items_aref = $state->{items_p};
	my $data_aref = $state->{data};
        my $e_data_aref = $state->{data_e};
        my $p_data_aref = $state->{data_p};

        $name = "Gene Count";
        $param = "gene_count";
        $url = "$section_cgi&page=clustersByGeneCount&genome_type=$genome_type";
        $log_scale = 1;
        my $yaxis = "Number of BCs";

        print "<table border=0>";
        print "<tr>";

        my $title = "Total Clusters";
        printMyChart($items_aref, $data_aref, $title, $yaxis, $url, \@series,
                     $name, $param, $use_log, $orientation, $log_scale, 1);

        $title = "Experimentally verified Clusters";
        printMyChart($e_items_aref, $e_data_aref, $title, $yaxis,
                     $url."&attr=Experimental", \@series,
                     $name, $param, $use_log, $orientation, $log_scale, 1);

        my $title = "Predicted Clusters";
        printMyChart($p_items_aref, $p_data_aref, $title, $yaxis,
                     $url."&attr=Predicted", \@series,
                     $name, $param, $use_log, $orientation, $log_scale, 1);

        print "</tr>";
        print "</table>";
        return;


    } elsif ($type eq "pfam" && $precomputed) {
        my $filename = "bcStats_byPfam.stor";
        my $file = $cacheDir . $filename;
        last if (!( -e $file ));

        my $state = retrieve($file);
        last if ( !defined($state) );

        my $items_aref = $state->{items};
        my $e_items_aref = $state->{items_e};
        my $sections_aref = $state->{sections};
        my $e_sections_aref = $state->{sections_e};
        my $data_aref = $state->{data};
        my $e_data_aref = $state->{data_e};

        print "<p>";
        print "<u>Evidence</u>: Experimental";
        print "<br/>";
        my $purl = "$section_cgi&page=pfamlist&evidence=Experimental";
        print alink( $purl, "View as Pfam List", "_blank" );
        print "</p>";

        my $url = "$section_cgi&page=clustersByPfam&evidence=Experimental";
	ChartUtil::printPieChart("Pfam", "func_code",
				 $url, $e_items_aref, $e_sections_aref,
				 $e_data_aref, \@series, 1,
				 $UPPER_LIMIT, "ebc");

        print "<br/>";
        print "<p>";
        print "<u>Evidence</u>: Predicted";
        print "</p>";
	
        $url = "$section_cgi&page=clustersByPfam&evidence=Predicted";
	ChartUtil::printPieChart("Pfam", "func_code",
                                 $url, $items_aref, $sections_aref,
                                 $data_aref, \@series, 1,
				 $UPPER_LIMIT, "pbc", 0);
        return;
    }

    if ($type eq "domain") {
        $name = "Domain";
	$param = "domain";
	$url = "$section_cgi&page=byGenome";

	webLog( dateTimeStr() . " start sql $type\n" );

        my $sql = qq{
            select tx.domain, tx.phylum, count(distinct bc.cluster_id)
            from taxon tx, bio_cluster_new bc
            where bc.taxon = tx.taxon_oid
            and tx.genome_type = 'metagenome'
            $rclause
            $imgClause
            group by tx.domain, tx.phylum
            order by tx.domain, tx.phylum
        };
        my $cur = execSql($dbh, $sql, $verbose);
        my @data;
        $log_scale = 1;
        for ( ;; ) {
            my ($domain, $phylum, $total_clusters) = $cur->fetchrow();
            last if !$total_clusters;
            if ($total_clusters > 0) {
                push @items, $domain.":".$phylum;
                if ($use_log) {
                    push @data, log($total_clusters)/log(2);
                } else {
                    push @data, $total_clusters;
                }
            }
        }

        my $sql = qq{
            select tx.domain, count(distinct bc.cluster_id)
            from taxon tx, bio_cluster_new bc
            where bc.taxon = tx.taxon_oid
            and tx.genome_type != 'metagenome'
            $rclause
            $imgClause
            group by tx.domain
            order by tx.domain
        };
	my $cur = execSql($dbh, $sql, $verbose);
        for ( ;; ) {
            my ($domain, $total_clusters) = $cur->fetchrow();
            last if !$total_clusters;
	    if ($total_clusters > 0) {
		push @items, $domain;
		if ($use_log) {
		    push @data, log($total_clusters)/log(2); 
		} else {
		    push @data, $total_clusters;
		}
	    }
        }
        
	webLog( dateTimeStr() . " end sql $type\n" );        
        
	my $datastr = join(",", @data);
	@datas = ($datastr);
	@sections = @items;

    } elsif ($type eq "phylum") {
	print "<p>\n";
	print domainLetterNote();
	print "</p>\n";

	$name = "Phylum";
	$param = "phylum";
	$url = "$section_cgi&page=clustersByPhylum";
	$orientation = "HORIZONTAL";

	webLog( dateTimeStr() . " start sql $type\n" );

        my $sql = qq{
            select tx.domain, tx.phylum, tx.ir_class, 
                   count(distinct bc.cluster_id)
            from taxon tx, bio_cluster_new bc
            where bc.taxon = tx.taxon_oid
            and tx.genome_type = 'metagenome'
            $rclause
            $imgClause
            group by tx.domain, tx.phylum, tx.ir_class
            order by tx.domain, tx.phylum, tx.ir_class
        };
        my $cur = execSql($dbh, $sql, $verbose);
        my @data;
        $log_scale = 1;
        for ( ;; ) {
            my ($domain, $phylum, $ir_class, $total_clusters) 
		= $cur->fetchrow();
            last if !$total_clusters;
            my $item = $phylum . " [".substr($domain, 0, 1)."] " . $ir_class;
            if ($total_clusters > 0) {
                push @items, $item;
                push @sections, $domain."#".$phylum."#".$ir_class;
                if ($use_log) {
                    push @data, log($total_clusters)/log(2);
                } else {
                    push @data, $total_clusters;
                }
            }
        }

	my $sql = qq{
            select tx.domain, tx.phylum, count(distinct bc.cluster_id)
            from taxon tx, bio_cluster_new bc
            where bc.taxon = tx.taxon_oid
            and tx.genome_type != 'metagenome'
            $rclause
            $imgClause
            group by tx.domain, tx.phylum
            order by tx.domain, tx.phylum
        };
	my $cur = execSql($dbh, $sql, $verbose);
	for ( ;; ) {
	    my ($domain, $phylum, $total_clusters) = $cur->fetchrow();
	    last if !$total_clusters;
	    my $item = $phylum . " [".substr($domain, 0, 1)."]";
	    if ($total_clusters > 0) {
		push @items, $item;
		push @sections, $phylum;
                if ($use_log) {
                    push @data, log($total_clusters)/log(2);
                } else {
                    push @data, $total_clusters;
                }
	    }
	}

	webLog( dateTimeStr() . " end sql $type\n" );	
	
	my $datastr = join(",", @data);
	@datas = ($datastr);

    } elsif ($type eq "length") {
	$name = "Seq Length (bps)";
	$param = "range";
	$url = "$section_cgi&page=clustersByLength&genome_type=$genome_type";
	$log_scale = 0;

	webLog( dateTimeStr() . " BCs - start sql $type\n" );
	print "<p>";

	my $sql = qq{
            select bc.cluster_id, (bc.end_coord - bc.start_coord + 1) seqlen
            from bio_cluster_new bc
            where bc.end_coord is not null
            and bc.start_coord is not null
            $rclause
            $imgClause
        };
        $genome_type = "both" if $genome_type eq "";
        $sql = qq{
            select bc.cluster_id, (bc.end_coord - bc.start_coord + 1) seqlen
            from bio_cluster_new bc, taxon tx
            where bc.end_coord is not null
            and bc.start_coord is not null
            and bc.taxon = tx.taxon_oid
            and tx.genome_type = '$genome_type'
            $rclause
            $imgClause
        } if $genome_type ne "both";
	my $cur = execSql($dbh, $sql, $verbose);

	# calculate stdev to take only relevant values:
        my %clust2len;
	my $n = 0;
	my @values; my $lo_val = 0; my $hi_val = 0; my $sum = 0;
        for ( ;; ) {
            my ($cluster_id, $len) = $cur->fetchrow();
            last if !$cluster_id;
	    $sum += $len;
            $clust2len{$cluster_id} = $len;
	    push @values, $len;

	    $lo_val = $len if $n == 0;
            $lo_val = $len if $len < $lo_val;
            $hi_val = $len if $len > $hi_val;
	    $n++;
        }

	my $mean = ceil($sum / $n);
	my $sqsum = 0;
	foreach my $val (@values) {
	    $sqsum += (($val - $mean) ** 2);
	}

	my $sigma = ceil(sqrt($sqsum / $n));
	my $hi = ceil($mean + $sigma);
	my $lo = ceil($mean - $sigma);
	$lo = $lo_val if $lo < $lo_val;
	$hi = $hi_val if $hi > $hi_val;

	my %clust2len_part;
	my $idx = 0;
	foreach my $key (keys %clust2len) {
	    my $val = $clust2len{ $key };
	    if ($val >= $lo && $val <= $hi) {
		$clust2len_part{ $key } = $val;
		$idx++;
	    }
	}

	webLog( dateTimeStr() . " BCs - end sql $type\n" );

	my ($items_aref, $data_aref) = 
	    binIt(25, $lo, $hi, \%clust2len_part, $use_log);

	webLog( dateTimeStr() . " BCs - end binning $type\n" );

	@items = @$items_aref;
	my @data = @$data_aref;
	my $datastr = join(",", @data);
	@datas = ($datastr);
	@sections = @items;

        if (@items ne "" && @datas ne "" &&
            scalar @items > 0 && scalar @datas > 0) {
            print "Total Clusters<br/>";
	    ChartUtil::printBarChart($name, $param, "Number of BCs",
				     $url, \@items, \@sections, \@datas,
				     \@series, $use_log, $orientation,
				     $log_scale);
	    print "<br/>";
        }

	# split by experimental and predicted and recalculate:
        my $sql = qq{
            select bcd.cluster_id, bcd.evidence
            from bio_cluster_data_new bcd, bio_cluster_new bc
            where bc.cluster_id = bcd.cluster_id
            and bcd.evidence is not null
            $rclause
            $imgClause
        };
        my $cur = execSql($dbh, $sql, $verbose);
        my %e_clust2len;
        my %p_clust2len;
        my $e_hi = 0; my $e_lo = 0; my $e_idx = 0; my @e_values; my $e_sum = 0;
        my $p_hi = 0; my $p_lo = 0; my $p_idx = 0; my @p_values; my $p_sum = 0;

        for ( ;; ) {
            my ($cluster_id, $attribute) = $cur->fetchrow();
            last if !$cluster_id;
            my $len = $clust2len{ $cluster_id };
	    next if (!$len || $len eq "");
 
            if ($attribute eq "Experimental") {
		$e_sum += $len;
		push @e_values, $len;

                $e_clust2len{ $cluster_id } = $len;
                $e_lo = $len if $e_idx == 0;
                $e_lo = $len if $len < $e_lo;
                $e_hi = $len if $len > $e_hi;
                $e_idx++;

            } elsif ($attribute eq "Predicted") {
		$p_sum += $len;
		push @p_values, $len;

                $p_clust2len{ $cluster_id } = $len;
                $p_lo = $len if $p_idx == 0;
                $p_lo = $len if $len < $p_lo;
                $p_hi = $len if $len > $p_hi;
                $p_idx++;
            }
        }

	# Experimental - show all, no sdev spread:
	my ($items_aref, $data_aref) = 
	    binIt(25, $e_lo, $e_hi, \%e_clust2len, $use_log);

	webLog( dateTimeStr() . " BCs - end binning e $type\n" );

	@items = @$items_aref;
	my @data = @$data_aref;
	my $datastr = join(",", @data);
	@datas = ($datastr);
	@sections = @items;

        if (@items ne "" && @datas ne "" &&
            scalar @items > 0 && scalar @datas > 0) {
            print "Experimentally verified Clusters<br/>";
	    ChartUtil::printBarChart($name, $param, "Number of BCs",
				     $url."&attr=Experimental",
				     \@items, \@sections, \@datas,
				     \@series, $use_log, $orientation,
				     $log_scale);
	    print "<br/>";
        }

        # Predicted:
        my $mean = ceil($p_sum / $p_idx);
        my $sqsum = 0;
        foreach my $val (@p_values) {
            $sqsum += (($val - $mean) ** 2);
        }

        my $sigma = ceil(sqrt($sqsum / $p_idx));
        my $hi = ceil($mean + $sigma);
        my $lo = ceil($mean - $sigma);
        $lo = $p_lo if $lo < $p_lo;
        $hi = $p_hi if $hi > $p_hi;

        my %p_clust2len_part;
        my $idx = 0;
        foreach my $key (keys %p_clust2len) {
            my $val = $p_clust2len{ $key };
            if ($val >= $lo && $val <= $hi) {
                $p_clust2len_part{ $key } = $val;
                $idx++;
            }
        }

        my ($items_aref, $data_aref) =
            binIt(25, $lo, $hi, \%p_clust2len_part, $use_log);

	webLog( dateTimeStr() . " BCs - end binning p $type\n" );

        @items = @$items_aref;
        my @data = @$data_aref;
        my $datastr = join(",", @data);
        @datas = ($datastr);
        @sections = @items;

        if (@items ne "" && @datas ne "" &&
            scalar @items > 0 && scalar @datas > 0) {
            print "Predicted Clusters<br/>";
            ChartUtil::printBarChart($name, $param, "Number of BCs",
                                     $url."&attr=Predicted",
				     \@items, \@sections, \@datas,
                                     \@series, $use_log, $orientation,
                                     $log_scale);
	    print "<br/>";
        }

	print "</p>";
	return;

    } elsif ($type eq "np_type") {
	require MeshTree;
        MeshTree::printTreeBcDiv();
	return;

    } elsif ($type eq "ec_type") {
	require MeshTree;
        MeshTree::printTreeEcDiv();
	return;

    } elsif ($type eq "bc_type") {
	printStatsByBCType(0);
	return;

    } elsif ($type eq "gene_count") {
	$name = "Gene Count";
	$param = "gene_count";
	$url = "$section_cgi&page=clustersByGeneCount&genome_type=$genome_type";
	$log_scale = 1;

	webLog( dateTimeStr() . " BCs - start sql 1 $type\n" );

        my $sql = qq{
            select mstat.cluster_id, mstat.gene_count
            from mv_bio_cluster_stat mstat
            where mstat.cluster_id is not null
        };
        my $cur = execSql($dbh, $sql, $verbose);
        my %cluster2count;
        for ( ;; ) {
            my ($cluster_id, $gene_count) = $cur->fetchrow();
            last if !$cluster_id;
            $cluster2count{ $cluster_id } = $gene_count;
        }

	webLog( dateTimeStr() . " BCs - end sql 1 $type\n" );
	webLog( dateTimeStr() . " BCs - start sql 2 $type\n" );

        my $sql = qq{
            select bcd.cluster_id, bcd.evidence
            from bio_cluster_data_new bcd, bio_cluster_new bc
            where bc.cluster_id = bcd.cluster_id
            and bcd.evidence is not null
            $rclause
            $imgClause
        };
	$genome_type = "both" if $genome_type eq "";
        $sql = qq{
            select bcd.cluster_id, bcd.evidence
            from bio_cluster_data_new bcd, bio_cluster_new bc, taxon tx
            where bc.cluster_id = bcd.cluster_id
            and bc.taxon = tx.taxon_oid
            and tx.genome_type = '$genome_type'
            and bcd.evidence is not null
            $rclause
            $imgClause
        } if $genome_type ne "both";

	my $cur = execSql($dbh, $sql, $verbose);

	my %e_clust2cnt;
	my %p_clust2cnt;
        my $e_hi = 0; my $e_lo = 0;
        my $p_hi = 0; my $p_lo = 0;
        my $e_idx = 0; my $p_idx = 0;

	my %clust2cnt;
	my $hi = 0; my $lo = 0; my $idx = 0;

	for ( ;; ) {
            my ($cluster_id, $attribute) = $cur->fetchrow();
            last if !$cluster_id;
            my $gene_count = $cluster2count{ $cluster_id };
	    next if (!$gene_count || $gene_count eq "");
	    
	    $lo = $gene_count if $idx == 0;
	    $lo = $gene_count if $gene_count < $lo;
	    $hi = $gene_count if $gene_count > $hi;

	    if ($attribute eq "Experimental") {
		$e_clust2cnt{ $cluster_id } = $gene_count;
		$e_lo = $gene_count if $e_idx == 0;
		$e_lo = $gene_count if $gene_count < $e_lo;
		$e_hi = $gene_count if $gene_count > $e_hi;
		$e_idx++;

	    } elsif ($attribute eq "Predicted") {
		$p_clust2cnt{ $cluster_id } = $gene_count;
		$p_lo = $gene_count if $p_idx == 0;
		$p_lo = $gene_count if $gene_count < $p_lo;
		$p_hi = $gene_count if $gene_count > $p_hi;
		$p_idx++;
	    }

	    $clust2cnt{ $cluster_id } = $gene_count;
	    $idx++;
	}

	webLog( dateTimeStr() . " BCs - end sql 2 $type\n" );

	print "<table border=0>";
	print "<tr>";

        my $numbins = 10;
        $numbins = 25 if $hi > 25000;
        my ($items_aref, $data_aref)
            = binIt($numbins, $lo, $hi, \%clust2cnt, $use_log);

	webLog( dateTimeStr() . " BCs - end binning $type\n" );

        @items = @$items_aref;
        my @data = @$data_aref;
        my $datastr = join(",", @data);
        my @datas;
        push @datas, $datastr;

        if (@items ne "" && @datas ne "" &&
            scalar @items > 0 && scalar @datas > 0) {
            print "<td padding=0 valign=top align=left>";
            print "Total Clusters<br/>";
            ChartUtil::printBarChart($name, $param, "Number of BCs",
                                     $url, \@items, \@items, \@datas,
                                     \@series, $use_log,
                                     $orientation, $log_scale);
            print "</td>";
        }

	my $numbins = 10;
	$numbins = 25 if $e_hi > 25000;
	my ($items_aref, $data_aref) 
	    = binIt($numbins, $e_lo, $e_hi, \%e_clust2cnt, $use_log);

	webLog( dateTimeStr() . " BCs - end binning e $type\n" );

	@items = @$items_aref;
	my @data = @$data_aref;
	my $datastr = join(",", @data);
	my @datas;
	#my $itemstr = join(",", @items);

	push @datas, $datastr;

	if (@items ne "" && @datas ne "" && 
	    scalar @items > 0 && scalar @datas > 0) {
	    print "<td padding=0 valign=top align=left>";
	    print "Experimentally verified clusters<br/>";
	    ChartUtil::printBarChart($name, $param, "Number of BCs", 
				     $url."&attr=Experimental",
				     \@items, \@items, \@datas,
				     \@series, $use_log, 
				     $orientation, $log_scale);
	    print "</td>\n";
	}

	my $numbins = 10;
	$numbins = 25 if $p_hi > 25000;
	my ($items_aref, $data_aref) 
	    = binIt($numbins, $p_lo, $p_hi, \%p_clust2cnt, $use_log);

	webLog( dateTimeStr() . " BCs - end binning p $type\n" );

	@items = @$items_aref;
	my @data = @$data_aref;
	my $datastr = join(",", @data);
	my @datas;
	push @datas, $datastr;

	if (@items ne "" && @datas ne "" && 
	    scalar @items > 0 && scalar @datas > 0) {
	    print "<td padding=0 valign=top align=left>";
	    print "Predicted Clusters<br/>";
	    ChartUtil::printBarChart($name, $param, "Number of BCs",
				     $url."&attr=Predicted",
				     \@items, \@items, \@datas, 
				     \@series, $use_log, 
				     $orientation, $log_scale);
	    print "</td>";
	}
	print "</tr>";
	print "</table>"; 
	return;

    } elsif ($type eq "pfam") {
	print "<p>";
 	print "<u>Evidence</u>: Experimental";
	print "<br/>";
	my $purl = "$section_cgi&page=pfamlist&evidence=Experimental";
	print alink( $purl, "View as Pfam List", "_blank" );
	print "</p>";

	my $url = "$section_cgi&page=clustersByPfam&evidence=Experimental";
	my $sql = qq{
        select $nvl(cf.function_code, '_'),
               $nvl(cf.definition, '_'),
               count(distinct bcf.cluster_id)
        from bio_cluster_features_new bcf, bio_cluster_data_new bcd,
             bio_cluster_new bc, gene_pfam_families gpf
        left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession
        left join cog_function cf on pfc.functions = cf.function_code
        where bcd.evidence = 'Experimental'
        and bcd.cluster_id = bcf.cluster_id
        and bcf.feature_type = 'gene'
        and bcf.gene_oid = gpf.gene_oid
        and bcf.cluster_id = bc.cluster_id
        and cf.function_code is not null
        $rclause
        $imgClause
        group by cf.function_code, cf.definition
        order by cf.definition
        };

	webLog( dateTimeStr() . " start sql $type\n" );        
        
	my $cur = execSql( $dbh, $sql, $verbose );

        my @data;
	my @sections;
	my @items;
        for ( ;; ) {
            my ( $sec, $item, $bc_count ) = $cur->fetchrow();
            last if !$item;
	    next if $item eq "_" ;
            push @items, $item;
	    push @sections, $sec;
            push @data, $bc_count;
        }
        $cur->finish();
	webLog( dateTimeStr() . " end sql $type\n" );

	ChartUtil::printPieChart("Pfam", "func_code", 
				 $url, \@items, \@sections,
				 \@data, \@series, 1,
				 $UPPER_LIMIT, "ebc"); 

	# This is very slow:
	print "<br/>";
	print "<p>";
 	print "<u>Evidence</u>: Predicted";
	#print "<br/>";
	#my $purl = "$section_cgi&page=pfamlist&evidence=Predicted";
	#print alink( $purl, "View as Pfam List", "_blank" );
	print "</p>";

        $url = "$section_cgi&page=clustersByPfam&evidence=Predicted";

        my $sql = qq{
        select $nvl(cf.function_code, '_'),
               $nvl(cf.definition, '_'),
               count(distinct bcf.cluster_id)
        from bio_cluster_features bcf,
             bio_cluster bc, gene_pfam_families gpf
        left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession
        left join cog_function cf on pfc.functions = cf.function_code
        where bcf.feature_type = 'gene'
        and bcf.gene_oid = gpf.gene_oid
        and bcf.cluster_id = bc.cluster_id
        and cf.function_code is not null
        $rclause
        $imgClause
        group by cf.function_code, cf.definition
        order by cf.definition
        };

	webLog( dateTimeStr() . " start sql $type\n" );

        my $cur = execSql( $dbh, $sql, $verbose );

        my @data;
        my @sections;
	my @items;
        for ( ;; ) {
            my ( $sec, $item, $bc_count ) = $cur->fetchrow();
            last if !$item;
            next if $item eq "_" ;
            push @items, $item;
            push @sections, $sec;
            push @data, $bc_count;
        }
        $cur->finish();
	webLog( dateTimeStr() . " end sql $type\n" );

	# counts are too high, so do not add hyperlinks to sections for now
	ChartUtil::printPieChart("Pfam", "func_code",
                                 $url, \@items, \@sections,
                                 \@data, \@series, 1,
				 $UPPER_LIMIT, "pbc", 0);
        return;

    } elsif ($type eq "kegg") {
	print "<p><u>Evidence</u>: Experimental</p>";
	$url = "$section_cgi&page=clustersByKEGG";
	my $sql = qq{
        select $nvl(pw.category, 'Unknown'), 
               count(distinct bcf.cluster_id)
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
             gene_ko_terms gk, bio_cluster_features_new bcf,
             bio_cluster_data_new bcd, bio_cluster_new bc
        where pw.pathway_oid = roi.pathway
        and roi.roi_id = rk.roi_id
        and rk.ko_terms = gk.ko_terms
        and gk.gene_oid = bcf.gene_oid
        and bcf.feature_type = 'gene'
        and bcd.evidence = 'Experimental'
        and bcd.cluster_id = bcf.cluster_id
        and bcf.cluster_id = bc.cluster_id
        $rclause
        $imgClause
        group by pw.category
        order by pw.category
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	
        my @data;
	for ( ;; ) {
	    my ( $item, $bc_count ) = $cur->fetchrow();
	    last if !$item;
	    push @items, $item;
	    push @data, $bc_count;
	}
	$cur->finish();

	ChartUtil::printPieChart("KEGG", "category", 
				 $url, \@items, \@items,
				 \@data, \@series, 0,
				 $UPPER_LIMIT, "bc"); 
	return;
    }

    return if @items eq "" || @datas eq "";
    return if scalar @items < 1 || scalar @datas < 1;
    ChartUtil::printBarChart($name, $param, "Number of BCs",
			     $url, \@items, \@sections, \@datas, 
			     \@series, $use_log, $orientation, $log_scale);
}

######################################################################
# binIt - bins items
######################################################################
sub binIt {
    my ($numbins, $lo, $hi, $item2num_href, $use_log) = @_;
    $use_log = 0 if $use_log eq "";
    $numbins = 25 if $numbins == 0 || $numbins eq "";

    my $range = $hi - $lo + 1;
    my $binsize = ceil($range/$numbins);
    my %item2num = %$item2num_href;

    my %bins;
    for (my $i = 1 ; $i <= $numbins ; $i++) {
	my $key = $lo + $binsize * $i;
	if ($hi < $key) {
	    $key = $hi;
	}
	$bins{$key} = 0;
    }

   OUTER: foreach my $item (keys %item2num) {
	my $val = $item2num{ $item };
	for (my $i = 1 ; $i <= $numbins ; $i++) {
	    my $bin = $lo + $binsize * $i;
	    if ($hi < $bin) {
		$bin = $hi;
	    }
	    if ($val <= $bin) {
		$bins{$bin}++;
		next OUTER;
	    }
	}
    }
    
    my $low = $lo;
    my @items;
    my @data;

    for (my $i = 1; $i <= $numbins; $i++) {
	my $bin = $lo + $binsize * $i;

	if ($hi < $bin) {
	    $bin = $hi;
	}
	my $bincount = $bins{$bin};

	if ($use_log) {
	    if ($bincount > 0) {
		push @items, "$low to $bin";
		push @data, log($bincount)/log(2); 
	    }
	} else {
	    push @items, "$low to $bin";
	    push @data, $bincount;
	}

	$low = $bin + 1;
	last if $bin == $hi;
    }

    return (\@items, \@data);
}

######################################################################
# printStatsByPhylum - shows the count of clusters that have
#                         a given phylum
######################################################################
sub printStatsByPhylum {
    my ($gene_count, $probability, $title) = @_;
    $gene_count = param("gene_count") if $gene_count eq "";
    $probability = param("probability") if $probability eq "";
    $title = 1 if $title eq "";

    if ($title) {
	print "<h1>Biosynthetic Clusters (BC) by Phylum</h1>";
	if ($probability ne "" && $gene_count ne "") {
	    print "<p><u>Gene Count</u>: $gene_count";
	    print "<br/><u>Probability</u>: $probability";
	    print "</p>";
	} elsif ($probability ne "") {
	    print "<p><u>Probability</u>: $probability</p>";
	} elsif ($gene_count ne "") {
	    print "<p><u>Gene Count</u>: $gene_count</p>";
	}
    }

    my $dofilter;
    $dofilter = "gene count" if $gene_count eq "";
    $dofilter = "probability" if $probability eq "";
    $dofilter = "probability or gene count" 
	if $gene_count eq "" && $probability eq "";
    print "<p>You may select a phylum to filter the clusters further by $dofilter</p>" if $dofilter ne "";

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $clusterClause = getClusterClause($probability, $gene_count);

    my $sql = qq{
        select tx.domain, tx.phylum, count(distinct bc.cluster_id)
        from taxon tx, bio_cluster_new bc
        where bc.taxon = tx.taxon_oid
        $rclause
        $imgClause
        $clusterClause
        group by tx.domain, tx.phylum
        order by tx.domain, tx.phylum
    };
    my $cur = execSql($dbh, $sql, $verbose);

    printMainForm();

    my $it = new InnerTable(1, "statsbyphylum$$", "statsbyphylum", 0);
    my $sd = $it->getSdDelim();

    $it->addColSpec( "Choose" ) if $dofilter ne "";
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, " .
		     "E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Phylum",   "asc",  "left" );
    $it->addColSpec( "Clusters", "desc", "right" );

    #print "<p>\n";
    #print domainLetterNote();
    #print "</p>\n";

    my $url_section = "$section_cgi&page=clustersByPhylum"
                    . "&gene_count=$gene_count&probability=$probability";
    my $cnt = 0;
    my $name = "Phylum";
    my $param = "phylum";
    my @series = ("count");
    my @data;
    my @items;
    my @sections;
    for ( ;; ) {
	my ($domain, $phylum, $total_clusters) = $cur->fetchrow();
        last if !$total_clusters;

        my $d = substr( $domain, 0, 1 );
        my $row;
	$row = $sd .
            "<input type='radio' name='phylum' value='$phylum'/>\t"
	    if $dofilter ne "";

	$row .= $domain . $sd . substr( $domain, 0, 1 ) . "\t";
        $row .= $phylum . $sd . $phylum . "\t";

        my $link = $total_clusters;
        if ($total_clusters && $total_clusters < $UPPER_LIMIT) {
            $link = alink($url_section . "&phylum=" .
			  WebUtil::massageToUrl2($phylum),
                          $total_clusters, "_blank");
        }
        $row .= $total_clusters . $sd . $link . "\t";

        $it->addRow($row);

	my $item = $phylum . " [$d]";
	push @items, $item;
	push @sections, $phylum;
	push @data, $total_clusters;

	$cnt++;
    }
    my $datastr = join(",", @data);
    my @datas = ($datastr);

    print "<table border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";
    $it->hideAll() if $cnt < 50;
    $it->{pageSize} = 25;
    $it->printOuterTable(1);

    if ($probability eq "") {
	print hiddenVar('gene_count', $gene_count);
	my $name = "_section_${section}_byProbability";
	my $title = "Filter by Probability";
	print submit(
	    -name  => $name,
	    -value => $title,
	    -class => "meddefbutton"
	);
	print nbsp(1);
    }

    if ($gene_count eq "") {
	print hiddenVar('probability', $probability);
	my $name = "_section_${section}_byGeneCount";
	my $title = "Filter by Gene Count";
	print submit(
	    -name  => $name,
	    -value => $title,
	    -class => "meddefbutton"
	);
    }

    print "<td style='vertical-align:bottom;text-align:left'>\n";
    if (@items ne "" && @data ne "" &&
	scalar @items > 5 && scalar @data > 5) {
	print "<p>\n";
	print domainLetterNote();
	print "</p>\n";

	my $use_log = 0;
	my $orientation = "VERTICAL";
	my $log_scale = 1;
	ChartUtil::printBarChart($name, $param, "Number of BCs",
				 $url_section, \@items, \@sections, 
				 \@datas, \@series, $use_log,
				 $orientation, $log_scale);
    }
    print "</td></tr>\n";
    print "</table>\n";
    print end_form();
}

######################################################################
# printClustersByBCType - shows a list of clusters that have
#                         the given BC TYPE
######################################################################
sub printClustersByBCType {
    my $bc_type = param("bc_type");
    my $evidence = param("evidence");
    print "<h1>Biosynthetic Clusters for BC Type</h1>";
    return if ($bc_type eq "");

    my $dbh = dbLogin();

    # get all human-readable BC type terms
    my %bc_typ_h;
    my $sql2 = "select bc_code, bc_desc from bc_type";
    my $cur2 = execSql($dbh, $sql2, $verbose);
    for ( ;; ) {
        my ($bc_code, $bc_desc) = $cur2->fetchrow();
        last if !$bc_code;
	$bc_typ_h{$bc_code} = $bc_desc;
    }
    $cur2->finish();

    my $trans_bctype = translateBcType($bc_type, \%bc_typ_h);
    print "<p><u>BC Type</u>: $trans_bctype";
    print "<br/><u>Evidence</u>: $evidence" if $evidence ne "";
    print "</p>";

    print start_form(-id     => "bctype_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    my @cluster_ids;
    my $sql = qq{
        select distinct bcd.cluster_id
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bc.cluster_id = bcd.cluster_id
        and bcd.bc_type = ?
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose, $bc_type);
    for ( ;; ) {
        my ($bc_id) = $cur->fetchrow();
        last if !$bc_id;
        push @cluster_ids, $bc_id;
    }
    $cur->finish();

    my $clusterClause;
    if (scalar(@cluster_ids) > 0) {
        my $cluster_ids_str =
            OracleUtil::getFuncIdsInClause($dbh, @cluster_ids);
        $clusterClause = " and bc.cluster_id in ($cluster_ids_str) ";
    }

    my $attrClause;
    $attrClause = " and bcd.evidence = '$evidence' " if $evidence ne "";
    my $sql = qq{
        select distinct bcd.cluster_id, bcd.evidence,
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_data_new bcd, bio_cluster_new bc, taxon tx
        where bcd.evidence is not null
        $attrClause
        and bc.cluster_id = bcd.cluster_id
        and bc.taxon = tx.taxon_oid
        $rclause
        $imgClause
        $clusterClause
    };

    my $it = new InnerTable( 1, "bybctype$$", "bybctype", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc", "right" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    $it->addColSpec( "Evidence",    "asc", "left" ) if $evidence eq "";

    my $cnt = 0;
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ( $cluster_id, $attr_val, $taxon_oid, $taxon_name )
	    = $cur->fetchrow();
        last if !$cluster_id;
	if ($evidence ne "") {
	    next if $attr_val ne $evidence;
	}

        my $url = "$main_cgi?section=BiosyntheticDetail"
                . "&page=cluster_detail&cluster_id=$cluster_id";
        my $txurl = "$main_cgi?section=TaxonDetail"
                  . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
        $row .= $sd . "<input type='checkbox' name='bc_id' value='$cluster_id' />\t";
        $row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";

	if ($evidence eq "") {
	    $row .= $attr_val . $sd . $attr_val . "\t";
	}

        $it->addRow($row);
        $cnt++;
    }

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
	if ( $clusterClause =~ /gtt_func_id/i );

    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bctype_frm") if $cnt > 10;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bctype_frm");

    printStatusLine("$cnt clusters for BC TYPE: $bc_type. ", 2);
}

######################################################################
# printClustersByProbability - shows a list of clusters that have
#                         the given probability score
######################################################################
sub printClustersByProbability {
    my $probability = param("probability");
    my $range = param("gene_count");
    my $phylum = param("phylum");

    my ($dm, $ph, $irc) = split("#", $phylum);
    my $phylumStr = $phylum;
    if ($dm eq "*Microbiome") {
        $phylumStr = $dm.":".$ph.":".$irc;
    }

    print "<h1>Biosynthetic Clusters for Probability</h1>";
    return if ($probability eq "");
    print "<p><u>Probability</u>: $probability";
    print "<br/><u>Gene Count</u>: $range" if $range ne "";
    print "<br/><u>Phylum</u>: $phylumStr" if $phylum ne "";
    print "</p>";

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
    my $clusterClause = getClusterClause("", $range, $phylum);

    # ANNA: if count is too high, present filters byPhylum
    # and byGeneCount as 2 tabs - call statsByPhylum,
    # and statsByGeneCount using param probability $probability
    my $sql = qq{
        select count(distinct bcd.cluster_id)
        from bio_cluster_data_new bcd, bio_cluster_new bc
        where bcd.probability is not null
        and round(bcd.probability, 1) = ?
        and bc.cluster_id = bcd.cluster_id
        $rclause
        $imgClause
        $clusterClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $probability );
    my ($count) = $cur->fetchrow();
    if ($count > $UPPER_LIMIT) {
	if ($range eq "" && $phylum eq "") {
	    require TabHTML;
	    TabHTML::printTabAPILinks("bcStatsTab");
	    my @tabIndex = ("#bcstatstab1", "#bcstatstab2");
	    my @tabNames = ("By Gene Count", "by Phylum");
	    TabHTML::printTabDiv("bcStatsTab", \@tabIndex, \@tabNames);

	    print "<div id='bcstatstab1'>";
	    printStatsByGeneCount($probability, $phylum, 0);
	    print "</div>";	# end biostatstab1

	    print "<div id='bcstatstab2'>";
	    printStatsByPhylum($range, $probability, 0);
	    print "</div>";	# end biostatstab2

	    TabHTML::printTabDivEnd();
	} elsif ($range ne "") {
	    printStatsByPhylum($range, $probability, 0);
	} elsif ($phylum ne "") {
	    printStatsByGeneCount($probability, $phylum, 0);
	}

        OracleUtil::truncTable($dbh, "gtt_func_id")
            if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table
        return;
    }

    my $sql = qq{
        select distinct bcd.cluster_id, 
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_data_new bcd, bio_cluster_new bc, taxon tx
        where bcd.probability is not null
        and bc.cluster_id = bcd.cluster_id
        and round(bcd.probability, 1) = ?
        and bc.taxon = tx.taxon_oid
        $clusterClause
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $probability );

    print start_form(-id     => "bcbyprobability_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $it = new InnerTable( 1, "byprobability$$", "byprobability", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc", "right" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    my $cnt = 0;
    for ( ;; ) {
        my ( $cluster_id, $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$cluster_id;

	my $url = "$main_cgi?section=BiosyntheticDetail"
	        . "&page=cluster_detail&cluster_id=$cluster_id";
        my $txurl = "$main_cgi?section=TaxonDetail"
                  . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
	$row .= $sd . "<input type='checkbox' name='bc_id' value='$cluster_id' />\t";
        $row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
        $it->addRow($row);
	$cnt++;
    }

    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bcbyprobability_frm") if $cnt > 10;
    $it->hideAll() if $cnt < 50;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bcbyprobability_frm");

    OracleUtil::truncTable($dbh, "gtt_func_id")
        if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table
    printStatusLine("$cnt clusters for $probability. ", 2);

    print end_form();
}

######################################################################
# printClustersByDomain - shows a list of clusters that have
#                         the given domain
######################################################################
sub printClustersByDomain {
    my $domain = param("domain");
    $domain = param("category") if $domain eq "";

    print "<h1>Biosynthetic Clusters for Domain</h1>";
    print "<p><u>Domain</u>: $domain";
    print "</p>";

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
}

sub printClustersByPfamIds {
    my $evidence = param("evidence");
    my @pfam_ids = param("ext_accession");
    if (scalar(@pfam_ids) <= 0) {
        @pfam_ids = param("func_id");
    }
    if (scalar(@pfam_ids) == 0) {
        webError("No Pfam has been selected.");
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchPfamId2NameHash
	( $dbh, \@pfam_ids, \%funcId2Name, 1 );

    print "<h1>Biosynthetic Clusters for Pfam </h1>";
    print "<p>";
    print "<u>Evidence</u>: $evidence";
    print "<br/><br/>";
    for my $pfam_id (@pfam_ids) {
        my $funcName = $funcId2Name{$pfam_id};
        print $pfam_id . " - <i>" . $funcName . "</i><br/>";
    }
    print "</p>";

    my $sql = qq{
        select distinct bc.cluster_id,
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_new bc, taxon tx,
             bio_cluster_features_new bcf, bio_cluster_data_new bcd,
             gene_pfam_families gpf
        where bcd.evidence = ?
        and bcd.cluster_id = bcf.cluster_id
        and bcf.feature_type = 'gene'
        and bcf.gene_oid = gpf.gene_oid
        and gpf.pfam_family in ($funcIdsInClause)
        and bcf.cluster_id = bc.cluster_id
        and bc.taxon = tx.taxon_oid
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $evidence );

    print start_form(-id     => "bcbypfamid_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $it = new InnerTable( 1, "bcbypfamid$$", "bcbypfamid", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc",  "right" );
    $it->addColSpec( "Genome Name", "asc",  "left" );

    my $cnt = 0;
    for ( ;; ) {
        my ( $cluster_id, $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$cluster_id;

        my $url = "$main_cgi?section=BiosyntheticDetail"
	    . "&page=cluster_detail&cluster_id=$cluster_id";
        my $txurl = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
        $row .= $sd . "<input type='checkbox' name='bc_id' value='$cluster_id' />\t";
        $row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
        $it->addRow($row);
        $cnt++;
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
	if ( $funcIdsInClause =~ /gtt_func_id/i );


    $it->hideAll() if $cnt < 50;
    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bcbypfamid_frm") if $cnt > 10;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bcbypfamid_frm");

    printStatusLine("$cnt clusters. ", 2);
    print end_form();
}

######################################################################
# printClustersByPfam - shows a list of clusters that have
#                       the given pfam
######################################################################
sub printClustersByPfam {
    my $func_code = param("func_code");
    my $evidence = param("evidence");
    my @pfam_ids = param("ext_accession");
    if ($func_code eq "" && scalar(@pfam_ids) <= 0) {
        @pfam_ids = param("func_id");
    }

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    my $sql = qq{
        select definition
        from cog_function
        where function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $func_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    print "<h1>Biosynthetic Clusters for Pfam </h1>";
    print "<p><u>Pfam</u>: $definition";
    print "<br/><u>Evidence</u>: $evidence</p>";
    print "</p>";

    my $sql = qq{
        select distinct bc.cluster_id,
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_new bc, taxon tx,
             bio_cluster_features_new bcf, bio_cluster_data_new bcd,
             gene_pfam_families gpf
        left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession
        left join cog_function cf on pfc.functions = cf.function_code
        where bcd.evidence = ?
        and bcd.cluster_id = bcf.cluster_id
        and bcf.feature_type = 'gene'
        and bcf.gene_oid = gpf.gene_oid
        and cf.function_code = ?
        and bcf.cluster_id = bc.cluster_id
        and bc.taxon = tx.taxon_oid
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $evidence, $func_code );

    print start_form(-id     => "bcbypfam_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $it = new InnerTable( 1, "bcbypfam$$", "bcbypfam", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc",  "right" );
    $it->addColSpec( "Genome Name", "asc",  "left" );

    my $cnt = 0;
    for ( ;; ) {
        my ( $cluster_id, $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$cluster_id;

        my $url = "$main_cgi?section=BiosyntheticDetail"
                . "&page=cluster_detail&cluster_id=$cluster_id";
        my $txurl = "$main_cgi?section=TaxonDetail"
	          . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
	$row .= $sd . "<input type='checkbox' name='bc_id' value='$cluster_id' />\t";
        $row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
        $it->addRow($row);
        $cnt++;
    }
    $cur->finish();

    $it->hideAll() if $cnt < 50;
    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bcbypfam_frm") if $cnt > 10;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bcbypfam_frm");

    printStatusLine("$cnt clusters for $definition. ", 2);
    print end_form();
}

######################################################################
# printClustersByPhylum - shows a list of clusters that have
#                         the given phylum
######################################################################
sub printClustersByPhylum {
    my $phylum = param("phylum");
    my $probability = param("probability");
    my $gene_count = param("gene_count");
    $phylum = param("category") if $phylum eq "";

    my ($dm, $ph, $irc) = split("#", $phylum);
    my $taxonClause = " and tx.phylum = ? ";
    my $phylumStr = $phylum;
    my $phy_eco = "Phylum";
    if ($dm eq "*Microbiome") {
        # metagenomes are passed one level deeper
	$taxonClause = 
	    " and tx.domain = ? and tx.phylum = ? and tx.ir_class = ? ";
	$phylumStr = $dm.":".$ph.":".$irc;
	$phy_eco = "Ecosystem Category";
    } 

    print "<h1>Biosynthetic Clusters for $phy_eco</h1>";
    print "<p><u>$phy_eco</u>: $phylumStr";
    print "<br/><u>Gene Count</u>: $gene_count" if $gene_count ne "";
    print "<br/><u>Probability</u>: $probability" if $probability ne "";
    print "</p>";

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
    my $clusterClause = getClusterClause($probability, $gene_count);

    # ANNA: if count is too high, present filters byProbability
    # and byGeneCount as 2 tabs - call statsByProbability,
    # and statsByGeneCount using param phylum $phylum
    my $sql = qq{
        select count(distinct bc.cluster_id)
        from taxon tx, bio_cluster_new bc
        where bc.taxon = tx.taxon_oid
        $taxonClause
        $rclause
        $imgClause
        $clusterClause
    };

    my $cur;
    if ($dm eq "*Microbiome") {
	$cur = execSql($dbh, $sql, $verbose, $dm, $ph, $irc);
    } else {
	$cur = execSql($dbh, $sql, $verbose, $phylum);
    }

    my ($count) = $cur->fetchrow();
    if ($count > $UPPER_LIMIT) {
	if ($probability eq "" && $gene_count eq "") {
	    require TabHTML;
	    TabHTML::printTabAPILinks("bcStatsTab");
	    my @tabIndex = ("#bcstatstab1", "#bcstatstab2");
	    my @tabNames = ("By Probability", "by Gene Count");
	    TabHTML::printTabDiv("bcStatsTab", \@tabIndex, \@tabNames);

	    print "<div id='bcstatstab1'>";
	    printStatsByProbability($gene_count, $phylum, 0);
	    print "</div>";	# end biostatstab1

	    print "<div id='bcstatstab2'>";
	    printStatsByGeneCount($probability, $phylum, 0);
	    print "</div>";	# end biostatstab2

	    TabHTML::printTabDivEnd();
	} elsif ($probability ne "") {
	    printStatsByGeneCount($probability, $phylum, 0);
	} elsif ($gene_count ne "") {
	    printStatsByProbability($gene_count, $phylum, 0);
	}

        OracleUtil::truncTable($dbh, "gtt_func_id")
            if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table
	return;
    }

    print start_form(-id     => "bcbyphylum_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $bc2evidence_href = getBC2Evidence
	($dbh, $rclause, $imgClause, $clusterClause);

    my $sql = qq{
        select distinct bc.cluster_id,
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_new bc, taxon tx
        where bc.taxon = tx.taxon_oid
        $taxonClause
        $clusterClause
        $rclause
        $imgClause
    };

    my $cur;
    if ($dm eq "*Microbiome") {
	$cur = execSql($dbh, $sql, $verbose, $dm, $ph, $irc);
    } else {
	$cur = execSql($dbh, $sql, $verbose, $phylum);
    }

    my $it = new InnerTable( 1, "byphylum$$", "byphylum", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc", "right" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    $it->addColSpec( "Evidence",    "asc", "left" );

    my $cnt = 0;
    for ( ;; ) {
        my ( $cluster_id, $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$cluster_id;

        my $url = "$main_cgi?section=BiosyntheticDetail"
                . "&page=cluster_detail&cluster_id=$cluster_id";
        my $txurl = "$main_cgi?section=TaxonDetail"
                  . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
        $row .= $sd . "<input type='checkbox' name='bc_id' value='$cluster_id' />\t";
        $row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";

        my $attr_val = $bc2evidence_href->{ $cluster_id };
        $row .= $attr_val . $sd . $attr_val . "\t";

        $it->addRow($row);
	$cnt++;
    }

    $it->hideAll() if $cnt < 50;
    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bcbyphylum_frm") if $cnt > 10;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bcbyphylum_frm");

    OracleUtil::truncTable($dbh, "gtt_func_id")
        if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table

    printStatusLine("$cnt clusters for $phylum. ", 2);
    print end_form();
}

######################################################################
# printClustersByPhylo - shows a list of clusters that have
#                         the given phylo
######################################################################
sub printClustersByPhylo {
    my $Unassigned = 'Unassigned';
    
    my $domain = param("domain");
    my $phylum = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family = param("family");
    my $genus = param("genus");
    my $species = param("species");

    print "<h1>Biosynthetic Clusters for Phylogentic Rank</h1>";
    require PhyloUtil;
    PhyloUtil::printPhyloTitle
	( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");

    my $phyloClause;
    my @binds;
    if ($domain && $domain ne $Unassigned) {
        $phyloClause .= "and tx.domain = ? ";
        push(@binds, $domain);
    }
    if ($phylum && $phylum ne $Unassigned) {
        $phyloClause .= "and tx.phylum = ? ";
        push(@binds, $phylum);
    }
    if ($ir_class && $ir_class ne $Unassigned) {
        $phyloClause .= "and tx.ir_class = ? ";
        push(@binds, $ir_class);
    }
    if ($ir_order && $ir_order ne $Unassigned) {
        $phyloClause .= "and tx.ir_order = ? ";
        push(@binds, $ir_order);
    }
    if ($family && $family ne $Unassigned) {
        $phyloClause .= "and tx.family = ? ";
        push(@binds, $family);
    }
    if ($genus && $genus ne $Unassigned) {
        $phyloClause .= "and tx.genus = ? ";
        push(@binds, $genus);
    }
    if ($species && $species ne $Unassigned) {
        $phyloClause .= "and tx.species = ? ";
        push(@binds, $species);
    }

    my $sql = qq{
        select distinct bc.cluster_id,
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_new bc, taxon tx
        where bc.taxon = tx.taxon_oid
        $phyloClause
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $it = new InnerTable( 1, "byphylo$$", "byphylo", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Cluster ID",  "asc",  "right" );
    $it->addColSpec( "Genome Name", "asc",  "left" );

    my $cnt = 0;
    for ( ;; ) {
        my ( $cluster_id, $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$cluster_id;

        my $url = "$main_cgi?section=BiosyntheticDetail"
                . "&page=cluster_detail&taxon_oid=$taxon_oid"
                . "&cluster_id=$cluster_id";
        my $txurl = "$main_cgi?section=TaxonDetail"
                  . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
        $row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
        $it->addRow($row);
        $cnt++;
    }

    $it->printOuterTable(1);

    printStatusLine("$cnt clusters for Phylogentic Rank. ", 2);
}


######################################################################
# printClustersByLength - shows a list of clusters that have
#                         the given domain
######################################################################
sub printClustersByLength {
    my $range = param("range");
    $range = param("category") if $range eq "";
    my ($min, $max) = split(" to ", $range) if $range ne "";
    my $attr = param("attr");
    my $genome_type = param("genome_type");
    $genome_type = "both" if $genome_type eq "";

    print "<h1>Biosynthetic Clusters for Seq Length</h1>";
    print "<p><u>Length Range</u>: $range bps";
    print "<br/><u>Evidence</u>: $attr</p>" if $attr ne "";
    print "</p>";

    my $attrClause = "";
    if ($attr ne "") {
        $attrClause = "and bcd.evidence = '$attr'";
    }

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    # ANNA: if count is too high, re-bin by length
    my $sql = qq{
        select bc.cluster_id, (bc.end_coord - bc.start_coord + 1) seqlen
        from bio_cluster_new bc
        where bc.end_coord is not null
        and bc.start_coord is not null
        and (bc.end_coord - bc.start_coord + 1) between ? and ?
        $rclause
        $imgClause
    };
    my $sql = qq{
        select bc.cluster_id, (bc.end_coord - bc.start_coord + 1) seqlen
        from bio_cluster_new bc, taxon tx
        where bc.end_coord is not null
        and bc.start_coord is not null
        and (bc.end_coord - bc.start_coord + 1) between ? and ?
        and bc.taxon = tx.taxon_oid
        and tx.genome_type = '$genome_type'
        $rclause
        $imgClause
    } if $genome_type ne "both";

    my $cur = execSql($dbh, $sql, $verbose, $min, $max);
    my %clust2len0;
    my $count = 0;
    for ( ;; ) {
	my ($cluster_id, $len) = $cur->fetchrow();
	last if !$cluster_id;
	$clust2len0{$cluster_id} = $len;
	$count++;
    }

    my @clusters0 = keys %clust2len0;
    my $clusterClause = getClusterClause("", "", "", \@clusters0);

    my @clusters;
    my %clust2len;
    if ($attr ne "") {
        # check for clusters that have the specified EVIDENCE:
        my $sql = qq{
            select distinct bc.cluster_id
            from bio_cluster_data_new bcd, bio_cluster_new bc
            where bc.cluster_id = bcd.cluster_id
            and bcd.evidence is not null
            $attrClause
            $rclause
            $imgClause
            $clusterClause
        };
        my $cur = execSql($dbh, $sql, $verbose);
	for ( ;; ) {
	    my ($cluster_id) = $cur->fetchrow();
	    last if !$cluster_id;
	    push @clusters, $cluster_id;
	    $clust2len{$cluster_id} = $clust2len0{$cluster_id};
	}
	$count = scalar @clusters;
    } else {
	%clust2len = %clust2len0;
    }

    if ($count > $UPPER_LIMIT) {
	my @series = ( "BC count" );
	my $use_log = 0;
	my $log_scale = 0;
	my $orientation = "VERTICAL";

        my ($items_aref, $data_aref) =
            binIt(25, $min, $max, \%clust2len, $use_log);
        my @items = @$items_aref;
        my @data = @$data_aref;
        my $datastr = join(",", @data);
        my @datas = ($datastr);
        my @sections = @items;

        my $name = "Seq Length (bps)";
        my $param = "range";
        my $url = "$section_cgi&page=clustersByLength&attr=$attr";

	OracleUtil::truncTable($dbh, "gtt_func_id")
	    if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table

	return if @items eq "" || @datas eq "";
	return if scalar @items < 1 || scalar @datas < 1;
	ChartUtil::printBarChart($name, $param, "Number of BCs",
				 $url, \@items, \@sections, \@datas,
				 \@series, $use_log, $orientation, $log_scale);
	return;
    }

    my $sql = qq{
        select bc.cluster_id, (bc.end_coord - bc.start_coord + 1) seqlen,
               tx.taxon_oid, tx.taxon_display_name
        from bio_cluster_new bc, 
             bio_cluster_data_new bcd, taxon tx
        where bc.taxon = tx.taxon_oid
        and bc.start_coord is not null
        and bc.end_coord is not null
        and bc.cluster_id = bcd.cluster_id
        and (bc.end_coord - bc.start_coord + 1) between ? and ?
        $attrClause
        $clusterClause
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose, $min, $max);

    print start_form(-id     => "bcbylength_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $it = new InnerTable( 1, "bygenecnt$$", "bygenecnt", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",   "asc",  "right" );
    $it->addColSpec( "Genome Name",  "asc",  "left" );
    $it->addColSpec( "Length (bps)", "desc", "right" );

    my $count = 0;
    for ( ;; ) {
        my ( $cluster_id, $len, $taxon_oid, $taxon_name ) = $cur->fetchrow();
        last if !$cluster_id;

        my $url = "$main_cgi?section=BiosyntheticDetail"
                . "&page=cluster_detail&cluster_id=$cluster_id";
        my $txurl = "$main_cgi?section=TaxonDetail"
                  . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row;
	$row .= $sd . "<input type='checkbox' name='bc_id' value='$cluster_id' />\t";
        $row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
        $row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
        $row .= $len;
        $it->addRow($row);
        $count++;
    }

    $it->hideAll() if $count < 50;
    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bcbylength_frm") if $count > 10;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bcbylength_frm");

    OracleUtil::truncTable($dbh, "gtt_func_id")
	if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table

    printStatusLine("$count clusters for seq length. ", 2);
    print end_form();
}

######################################################################
# printClustersByGeneCount - shows a list of clusters that have
#                            the given gene count range
######################################################################
sub printClustersByGeneCount {
    my $probability = param("probability");
    my $attr = param("attr");
    my $range = param("gene_count");
    my ($min, $max) = split(" to ", $range) if $range ne "";
    my $phylum = param("phylum");
    my $genome_type = param("genome_type");
    $genome_type = "both" if $genome_type eq "";

    print "<h1>Biosynthetic Clusters for Gene Count</h1>";
    print "<p><u>Gene Count</u>: $range";
    print "<br/><u>Probability</u>: $probability" if $probability ne "";
    print "<br/><u>Phylum</u>: $phylum" if $phylum ne "";
    print "<br/><u>Evidence</u>: $attr</p>" if $attr ne "";

    my $attrClause = "";
    if ($attr ne "") {
	$attrClause = "and bcd.evidence = '$attr'";
    }

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");

    # get clusters for given range:
    my ($min, $max) = split(" to ", $range) if $range ne "";
    my $cntClause = "and mstat.gene_count >= $min and mstat.gene_count <= $max";
    $cntClause = "and mstat.gene_count = $min" if $max eq "";
    my @clusters;
    my $sql = qq{
        select mstat.cluster_id
        from mv_bio_cluster_stat mstat
        where mstat.cluster_id is not null
        $cntClause
    };
    my $sql = qq{
        select mstat.cluster_id
        from mv_bio_cluster_stat mstat, bio_cluster_new bc, taxon tx
        where mstat.cluster_id is not null
        and bc.cluster_id = mstat.cluster_id
        and bc.taxon = tx.taxon_oid
        and tx.genome_type = '$genome_type'
        $cntClause
    } if $genome_type ne "both";
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($cluster_id) = $cur->fetchrow();
        last if !$cluster_id;
	push @clusters, $cluster_id;
    }

    my $clusterClause = getClusterClause
	($probability, "", $phylum, \@clusters);

    my $count = scalar @clusters;
    if ($attr ne "") {
	# check for clusters that have the specified EVIDENCE:
	my $sql = qq{
            select count (distinct bc.cluster_id)
            from bio_cluster_data_new bcd, bio_cluster_new bc
            where bc.cluster_id = bcd.cluster_id
            and bcd.evidence is not null
            $attrClause
            $rclause
            $imgClause
            $clusterClause
        };
	my $cur = execSql($dbh, $sql, $verbose);
	($count) = $cur->fetchrow();
    }

    if ($count > $UPPER_LIMIT) {
	if ($probability eq "" & $phylum eq "") {
	    require TabHTML;
	    TabHTML::printTabAPILinks("bcStatsTab");
	    my @tabIndex = ("#bcstatstab1", "#bcstatstab2");
	    my @tabNames = ("By Probability", "by Phylum");
	    TabHTML::printTabDiv("bcStatsTab", \@tabIndex, \@tabNames);

	    print "<div id='bcstatstab1'>";
	    printStatsByProbability($range, $phylum, 0);
	    print "</div>";	# end biostatstab1

	    print "<div id='bcstatstab2'>";
	    printStatsByPhylum($range, $probability, 0);
	    print "</div>";	# end biostatstab2

	    TabHTML::printTabDivEnd();
	} elsif ($probability ne "") {
	    printStatsByPhylum($range, $probability, 0);
	} elsif ($phylum ne "") {
	    printStatsByProbability($range, $phylum, 0);
	}

	OracleUtil::truncTable($dbh, "gtt_func_id")
	    if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table
        return;
    }

    my $whereClause = "where my_count >= $min and my_count <= $max";
    $whereClause = "where my_count = $min" if $max eq "";
    my $sql = qq{
        select cls, tid, t, my_count from (
            select bc.cluster_id as cls, bc.taxon as tid, 
                   tx.taxon_display_name as t,
                   count(distinct bcf.feature_id) as my_count
            from bio_cluster_new bc, bio_cluster_features_new bcf, 
                 bio_cluster_data_new bcd, taxon tx
            where bc.cluster_id = bcf.cluster_id
            and bc.cluster_id = bcd.cluster_id
            and bcd.evidence is not null
            $attrClause
            $clusterClause
            and bcf.feature_type = 'gene'
            and bc.taxon = tx.taxon_oid
            $rclause
            $imgClause
            group by bc.cluster_id, bc.taxon, tx.taxon_display_name )
        $whereClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    print start_form(-id     => "bcbygcnt_frm",
                     -name   => "mainForm",
                     -action => "$main_cgi");

    my $it = new InnerTable( 1, "bygenecnt$$", "bygenecnt", 1 );
    my $sd = $it->getSdDelim();

    $it->addColSpec( "Select" );
    $it->addColSpec( "Cluster ID",  "asc",  "right" );
    $it->addColSpec( "Genome Name", "asc",  "left" );
    $it->addColSpec( "Gene Count",  "desc", "right" );

    my $count = 0;
    for ( ;; ) {
        my ( $cluster_id, $taxon_oid, $taxon_name, $cnt ) = $cur->fetchrow();
        last if !$cluster_id;
	next if $cnt < $min;
	next if $cnt > $max && $max ne "";
	
	my $url = "$main_cgi?section=BiosyntheticDetail"
	        . "&page=cluster_detail&cluster_id=$cluster_id";
	my $txurl = "$main_cgi?section=TaxonDetail"
	          . "&page=taxonDetail&taxon_oid=$taxon_oid";
	
	my $row;
	$row .= $sd . "<input type='checkbox' name='bc_id' value='$cluster_id' />\t";
	$row .= $cluster_id . $sd . alink($url, $cluster_id) . "\t";
	$row .= $taxon_name . $sd . alink($txurl, $taxon_name) . "\t";
	$row .= $cnt;
        $it->addRow($row);
	$count++;
    }

    $it->hideAll() if $count < 50;
    print "<script src='$base_url/checkSelection.js'></script>\n";
    BiosyntheticDetail::printPfamFooter("bcbygcnt_frm") if $count > 10;
    $it->printOuterTable(1);
    BiosyntheticDetail::printPfamFooter("bcbygcnt_frm");

    OracleUtil::truncTable($dbh, "gtt_func_id")
	if ($clusterClause =~ /gtt_func_id/i ); # clean up temp table

    printStatusLine("$count clusters for gene count: $range. ", 2);
    print end_form();
}

sub getClusterClause {
    my ($probability, $gene_count, $phylum, $cluster_aref) = @_;

    my $dbh = dbLogin();
    if ($probability eq "" && $gene_count eq "" && $phylum eq "") {
	if ($cluster_aref ne "") {
	    my @clusters = @$cluster_aref;
	    my $funcIdsInClause =
		OracleUtil::getFuncIdsInClause( $dbh, @clusters );
	    return " and bc.cluster_id in ($funcIdsInClause) ";
	}
	return "";
    }

    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
    my $clusterClause = "";

    my $sql1;
    if ($probability ne "") {
        $sql1 = qq{
            select distinct bcd.cluster_id
            from bio_cluster_data_new bcd, bio_cluster_new bc
            where bcd.probability is not null
            and bc.cluster_id = bcd.cluster_id
            and round(bcd.probability, 1) = $probability
            $rclause

            $imgClause
        };
    }

    my $sql2;
    if ($gene_count ne "") {
	my ($min, $max) = split(" to ", $gene_count);
        my $whereClause = "where my_count >= $min and my_count <= $max";
        $whereClause = "where my_count = $min" if $max eq "";

        $sql2 = qq{
        select cls from (
            select bc.cluster_id as cls,
                   count(distinct bcf.feature_id) as my_count
            from bio_cluster_new bc, bio_cluster_features_new bcf
            where bc.cluster_id = bcf.cluster_id
            and bc.cluster_id = bcf.cluster_id
            and bcf.feature_type = 'gene'
            $rclause
            $imgClause
            group by bc.cluster_id )
        $whereClause
        };
    }

    my $sql3;
    if ($phylum ne "") {
	my $taxonClause = " and tx.phylum = '$phylum' ";

	my $domain = 0;
	my $ir_class = 0;
	my ($dm, $ph, $irc) = split("#", $phylum);
	if ($dm eq "*Microbiome") {
	    # metagenomes are passed one level deeper
	    $taxonClause = " and tx.domain = '$dm'"
		         . " and tx.phylum = '$ph'"
			 . " and tx.ir_class = '$irc' ";
	}

	$sql3 = qq{
            select distinct bc.cluster_id
            from bio_cluster_new bc, taxon tx
            where bc.taxon = tx.taxon_oid
            $taxonClause
            $rclause
            $imgClause
        };
    }

    my $sql = $sql1;
    if ($sql1 eq "" && $sql3 eq "") {
	$sql = $sql2;
    } elsif ($sql1 eq "" && $sql2 eq "") {
	$sql = $sql3;
    } elsif ($sql1 ne "" && $sql2 ne "" && $sql3 ne "") {
	$sql = $sql1 . " INTERSECT " . $sql2 . " INTERSECT " . $sql3;
    } elsif ($sql1 ne "" && $sql2 ne "") {
	$sql = $sql1 . " INTERSECT " . $sql2;
    } elsif ($sql1 ne "" && $sql3 ne "") {
	$sql = $sql1 . " INTERSECT " . $sql3;
    } elsif ($sql2 ne "" && $sql3 ne "") {
	$sql = $sql2 . " INTERSECT " . $sql3;
    }

    my $cur = execSql( $dbh, $sql, $verbose );
    my @ids;
    for ( ;; ) {
        my ( $cluster_id ) = $cur->fetchrow();
        last if !$cluster_id;
        push @ids, $cluster_id;
    }

    if (scalar(@ids) > 0 || $cluster_aref ne "") {
	if ($cluster_aref ne "") {
	    my @clusters = @$cluster_aref;
	    @ids = Array::Utils::intersect(@ids, @clusters);
	}
        my $funcIdsInClause =
	    OracleUtil::getFuncIdsInClause( $dbh, @ids );
        $clusterClause = " and bc.cluster_id in ($funcIdsInClause) ";
    }

    return $clusterClause;
}

sub printPfamList {
    my $evidence = param("evidence");

    printMainForm();
    print hiddenVar( "evidence", $evidence );

    print "<h1>Pfam Families</h1>\n";
    print "<p>";
    print "<u>Evidence</u>: $evidence";
    print "</p>";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $rclause = WebUtil::urClause("bc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("bc.taxon");
    my $sql = qq{
        select pf.name, pf.ext_accession, pf.description,
               pf.db_source, count( distinct bcf.cluster_id )
        from bio_cluster_features_new bcf, bio_cluster_data_new bcd,
             bio_cluster_new bc, gene_pfam_families gpf,
             pfam_family pf
        where bcd.evidence = ?
        and bcd.cluster_id = bcf.cluster_id
        and bcf.feature_type = 'gene'
        and bcf.gene_oid = gpf.gene_oid
        and bcf.cluster_id = bc.cluster_id
        and gpf.pfam_family = pf.ext_accession
        $rclause
        $imgClause
        group by pf.name, pf.ext_accession, pf.description, pf.db_source
        having count(distinct bcf.cluster_id) > 0
        order by lower( pf.name ), pf.ext_accession, 
              pf.description, pf.db_source
    };
    my $cur = execSql( $dbh, $sql, $verbose, $evidence );

    my $count = 0;
    my $it = new InnerTable(1, "bcbypfamlist$$", "bcbypfamlist", 0);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Pfam ID",   "asc",  "left" );
    $it->addColSpec( "Pfam Name", "asc",  "left" );
    $it->addColSpec( "BC count",  "desc", "right" );

    for ( ;; ) {
        my ( $name, $ext_accession, $description, $db_source, $cluster_cnt )
	    = $cur->fetchrow();
        last if !$name;

        my $r;
        $r .= $sd . 
	    "<input type='checkbox' name='func_id' value='$ext_accession'/>\t";
        $r .= "$ext_accession\t";

        my $x;
        $x = " - $description" if $db_source =~ /HMM/;
        $r .= "$name$x\t";

        my $url = "$section_cgi&page=clustersByPfamIds&evidence=$evidence";
        $url .= "&ext_accession=$ext_accession";
        $r .= $cluster_cnt . $sd . alink( $url, $cluster_cnt ) . "\t";

	$it->addRow($r);
	$count++;
    }
    $cur->finish();

    my $name = "_section_${section}_clustersByPfamIds";
    if ($count > 10) {
	print submit(
	    -name  => $name,
	    -value => "List BCs",
	    -class => "smdefbutton"
	);
	print nbsp(1);
	WebUtil::printButtonFooter();
    }
    $it->printOuterTable(1);

    print submit(
	-name  => $name,
	-value => "List BCs",
	-class => "smdefbutton"
    );
    print nbsp(1);
    WebUtil::printButtonFooter();
    WorkspaceUtil::printSaveFunctionToWorkspace("func_id") if $count > 10;

    printStatusLine("$count Pfam retrieved.", 2);
    print end_form();
}



1;

