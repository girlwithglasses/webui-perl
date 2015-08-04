###########################################################################
# ScaffoldHits -- adopted from MetagenomeHits
# change from taxon_oid to a set of scaffold oids
#
# $Id: ScaffoldHits.pm 33704 2015-07-08 04:26:39Z jinghuahuang $
###########################################################################
package ScaffoldHits;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use MetagJavaScript;
use MetagenomeGraph;
use BinTree;
use BarChartImage;
use ChartUtil;
use InnerTable;
use TaxonDetail;
use DataEntryUtil;
use ScaffoldCart;
use HtmlUtil;
use PhyloUtil;

$| = 1;

my $env                      = getEnv();
my $cgi_dir                  = $env->{cgi_dir};
my $cgi_url                  = $env->{cgi_url};
my $main_cgi                 = $env->{main_cgi};
my $inner_cgi                = $env->{inner_cgi};
my $tmp_url                  = $env->{tmp_url};
my $verbose                  = $env->{verbose};
my $scaffold_page_size       = $env->{scaffold_page_size};
my $taxonomy_base_url        = $env->{taxonomy_base_url};
my $include_metagenomes      = $env->{include_metagenomes};
my $include_img_terms        = $env->{include_img_terms};
my $web_data_dir             = $env->{web_data_dir};
my $ncbi_entrez_base_url     = $env->{ncbi_entrez_base_url};
my $pubmed_base_url          = $env->{pubmed_base_url};
my $ncbi_project_id_base_url = $env->{ncbi_project_id_base_url};
my $img_internal             = $env->{img_internal};
my $img_lite                 = $env->{img_lite};
my $user_restricted_site     = $env->{user_restricted_site};
my $no_restricted_message    = $env->{no_restricted_message};
my $cgi_tmp_dir              = $env->{cgi_tmp_dir};
my $artemis_url              = $env->{artemis_url};
my $artemis_link             = alink( $artemis_url, "Artemis" );
my $mgtrees_dir              = $env->{mgtrees_dir};
my $show_mgdist_v2           = $env->{show_mgdist_v2};

#my $maxOrthologGroups = 10;
#my $maxParalogGroups  = 100;

#MyIMG&page=preferences
my $preferences_url    = "$main_cgi?section=MyIMG&page=preferences";
my $pageSize           = $scaffold_page_size;
my $max_gene_batch     = 900;
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $taxon_stats_dir          = $env->{taxon_stats_dir};
my $taxon_faa_dir            = $env->{taxon_faa_dir};
my $taxon_fna_dir            = $env->{taxon_fna_dir};
my $taxon_genes_fna_dir      = $env->{taxon_genes_fna_dir};
my $taxon_intergenic_fna_dir = $env->{taxon_intergenic_fna_dir};
my $genes_dir                = $env->{genes_dir};
my $all_fna_files_dir        = $env->{all_fna_files_dir};
my $max_scaffold_list        = 1000;

# also see MetaJavaSscript for this value too
# method checkSelect()
my $max_scaffold_list = 20;

# Initial list.
my $max_scaffold_list2 = 1000;

# For 2nd order list.
my $max_export_scaffold_list = 100000;

my $max_scaffold_results = 20000;

my $base_url = $env->{base_url};

my $YUI        = $env->{yui_dir_28};
my $yui_tables = $env->{yui_tables};

my $section = "ScaffoldHits";

my $unknown = "Unknown";

# make sure its last in sorting
my $zzzUnknown = "zzzUnknown";
my $mynull     = "mynull";

my $nvl = getNvl();

# my not sure about this, I think it should be 1
# 0 - all orthologs for the genome
# 1 - only orthologs with query gene of phylum's gene oids
# see MetagenomeGraph.pm
#my $GENE_OID_CLAUSE = 1;
#my $GENE_OID_SCAFFLOD_CLAUSE = 1;

#
# dispatch - Dispatch to pages for this section.
#
# this is the hook into main.pl
# to get here, then I use section=??? to go the correct page after
#
sub dispatch {
    my $page = param("page");

    if ( $page eq "metagenomeHits" || $page eq "unassigned" ) {
        printMetagenomeHits();

    } elsif ( $page eq "family" ) {
        # 1st page of the family stats - after you click the phylum name on
        # metag phylum page stats - main one
        printFamilyStats();

    } elsif ( $page eq "taxonomyMetagHits" ) {
        # on any family page when you click on the counts to go to
        # the cog functional break down page
        printTaxonomyMetagHits();

    } elsif ( $page eq "species" ) {
        # 2nd page when you click the family name
        printSpeciesStats();

    } elsif ( $page eq "metagtable" ) {
        printMetagenomeStatsResults();

    } elsif ( $page eq "download" ) {
        checkAccess();
        PhyloUtil::download();
        WebUtil::webExit(0);
    } else {
        printMetagenomeStats();
    }

}

# main page
#
# print start stats page
#
#
sub printMetagenomeStats {

    my $contact_oid = getContactOid();
    if ( blankStr($contact_oid) ) {
        webError("Your login has expired.");
        return;
    }

    my $oids_aref     = ScaffoldCart::getSelectedCartOids();
    my @scaffold_oids = @$oids_aref;

    if ( scalar(@scaffold_oids) == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }
    printStatusLine( "Loading ...", 1 );

    MetagJavaScript::printFormJS();

    # Split subroutine to accept user input such as percent identity
    # Similar to MetagenomHits +BSJ 09/01/11
    printForm();

}

#
#
# printForm - Print the form for accepting options for phylodist table
#
#

sub printForm {
    print "<h2>Phylogenetic Distribution of Genes in Selected Scaffolds</h2>\n";
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    print "<p>\n";

    print qq{
    <b>Percent Identity</b><br />
    <input type='radio' name="percentage" value='suc' checked='checked' onClick='enableHits("suc")' />
    Successive (30% to 59%, 60% to 89%, 90%+)<br />
    <input type='radio' name="percentage" value='cum' onClick='enableHits("cum")' />
    Cumulative (30%+, 60%+, 90%+)
    <br /><br />
    };

    print qq{
    <input type='radio' name='xcopy' value='gene_count' checked='checked' />
    Gene count <br/>
    <input type='radio' name='xcopy' value='est_copy' />
    Estimated gene copies <br/>
    };

    print qq{
        <br/>
        <b>Display Options </b>
        <br/><br/>
        <input type='checkbox' name='show_percentage' checked='checked' /> &nbsp; Show percentage column.
        <br/>
        <input type='checkbox' name='show_hist' checked='checked' /> &nbsp; Show histogram column.
    };

    print "</p>\n";

    print hiddenVar( "section",       $section );
    print hiddenVar( "page",          "metagtable" );
    print hiddenVar( "fromviewer",    "MetagPhyloDist" );
    print hiddenVar( "metag",         "1" );

    my @scaffold_oids = param('scaffold_oid');
    for my $oid (@scaffold_oids) {
        print hiddenVar( "scaffold_oid", $oid );
    }

    print submit(
                  -name  => "",
                  -value => "Go",
                  -class => "smdefbutton"
    );

    print nbsp(3);
    print reset(
                 -name  => "",
                 -value => "Reset",
                 -class => "smbutton"
    );
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

#
#
# Print the phylo distribution table
#
#

sub printMetagenomeStatsResults {

    my $percentage         = param("percentage");           # "suc"=30-59,60-89,90+; "cum"=30+,60+,90+
    my $xcopy              = param("xcopy");                # gene_count, est_copy
    my $gene_count_file    = param("gene_count_file");
    my $homolog_count_file = param("homolog_count_file");
    my $genome_count_file  = param("genome_count_file");
    my $show_percentage    = param("show_percentage");
    my $show_hist          = param("show_hist");
    my @filters            = param("filter");               # filter on selected phyla

    my $oids_aref     = ScaffoldCart::getSelectedCartOids();
    my @scaffold_oids = @$oids_aref;

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@scaffold_oids );

    my $sql = qq{ 
        select sum(ss.count_cds), sum(ss.count_total_gene)
            from scaffold_stats ss 
            where ss.scaffold_oid in (select id from gtt_num_id) 
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $totalGeneCount, $total2 ) = $cur->fetchrow();

    if ( !$totalGeneCount ) {
        $totalGeneCount = $total2;
    }

    if ( !$totalGeneCount ) {
        printMessage("There are no genes in the selected scaffolds.");
        return;
    }

    printStartWorkingDiv();
    my $plus = ( $percentage eq "cum" ) ? "+" : "";    # display "+" if cumulative

    print "Loading 30%$plus bin stats ...<br/>\n";
    my %stats30;
    my $totalCount30 = loadMetagenomeStats( $dbh, \@scaffold_oids, 30, \%stats30, $plus, $xcopy );

    print "Loading 60%$plus bin stats ...<br/>\n";
    my %stats60;
    my $totalCount60 = loadMetagenomeStats( $dbh, \@scaffold_oids, 60, \%stats60, $plus, $xcopy );

    print "Loading 90%$plus bin stats ...<br/>\n";
    my %stats90;
    my $totalCount90 = loadMetagenomeStats( $dbh, \@scaffold_oids, 90, \%stats90, $plus, $xcopy );

    print "Loading genome hits ...<br/>\n";
    my %genoemeHitStats;
    loadGenomeHitStats( $dbh, \@scaffold_oids, \%genoemeHitStats );

    if ( $totalCount30 + $totalCount60 + $totalCount90 == 0 ) {
        printEndWorkingDiv();
        printMessage("No phylogenetic distribution has been computed here.");
        printStatusLine( "Loaded.", 2 );
        return;
    }

    # how to get genome count like before???
    my %orgCount;
    PhyloUtil::loadPhylumOrgCount( $dbh, \%orgCount );

    print "Loading unassigned 30% hits ...<br/>\n";
    my %hash_all_genes;    #
    my $remainCount30 = getUnassignedCount( $dbh, \@scaffold_oids, 30, \%hash_all_genes );
    print "Loading unassigned 60% hits ...<br/>\n";
    my $remainCount60 = getUnassignedCount( $dbh, \@scaffold_oids, 60, \%hash_all_genes );
    print "Loading unassigned 90% hits ...<br/>\n";
    my $remainCount90 = getUnassignedCount( $dbh, \@scaffold_oids, 90, \%hash_all_genes );

    printEndWorkingDiv();

    printMainForm();

    printJS();

    print "<h2>Phylogenetic Distribution of Genes in Selected Scaffolds</h2>\n";

    # fix url if too many scaffold oids
    #
    my $scaffold_str = join( ",", @scaffold_oids );
    my $url3         = "javascript:mySubmit2('ScaffoldCart', 'selectedScaffolds')";
    my $tmpcnt       = scalar(@scaffold_oids);
    my $link3        = qq{
        <p>Number of selected scaffolds: <a href="$url3"> $tmpcnt </a>
        </p>
    };

    print "<p style='width: 950px;'>\n";
    PhyloUtil::printPhyloDistMessage();
    print "</p>\n";

    my $xcopyText = PhyloUtil::getXcopyText( $xcopy );
    print WebUtil::getHtmlBookmark( "blasthits", "<h2>Distribution of Best Blast Hits ($xcopyText)</h2>" );

    print "<p>\n";
    print domainLetterNote();
    print qq{
        <br/>
        Hit genomes count in brackets ( ).
    };
    print "</p>\n";

    # create export file
    my $sessionId  = getSessionId();
    my $exportfile = "Phylodist$$";
    my $exportPath = "$cgi_tmp_dir/$exportfile";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # export headers
    print $res "Domain\t";
    print $res "Phylum\t";
    print $res "No. Of Genomes\t";
    print $res "No. Of Hits 30%\t";
    print $res "% Hits 30%\t" if $show_percentage;
    print $res "No. Of Hits 60%\t";
    print $res "% Hits 60%\t" if $show_percentage;
    print $res "No. Of Hits 90%";
    print $res "\t% Hits 90%" if $show_percentage;
    print $res "\n";

    my $scaffold_oid_str = join( ",", @scaffold_oids );
    print hiddenVar( "section",          $section );
    print hiddenVar( "page",             "metagtable" );
    print hiddenVar( "domain",           "" );
    print hiddenVar( "phylum",           "" );
    print hiddenVar( "ir_class",         "" );
    print hiddenVar( "family",           "" );
    print hiddenVar( "genus",            "" );
    print hiddenVar( "species",          "" );
    print hiddenVar( "percent_identity", "" );             # perc
    print hiddenVar( "perc",             "" );
    print hiddenVar( "percent",          "" );

    print hiddenVar( "fromviewer",         "MetagPhyloDist" );
    print hiddenVar( "xcopy",              $xcopy );
    print hiddenVar( "gene_count_file",    $gene_count_file );
    print hiddenVar( "homolog_count_file", $homolog_count_file );
    print hiddenVar( "genome_count_file",  $genome_count_file );
    print hiddenVar( "show_percentage",    $show_percentage );
    print hiddenVar( "show_hist",          $show_hist );
    print hiddenVar( "scaffold_oids",      $scaffold_oid_str );
    my $plusVar = ( $plus ) ? "1" : "";
    print hiddenVar( "plus",               $plusVar );

    print qq{
        <input class='smdefbutton' type='submit' value='Filter'
        onClick="document.mainForm.page.value='metagtable';"/>
        &nbsp;
        <input class='smbutton' type='button' value='Select All'
        onClick="javascript:selectAllCheckBoxes(1)" />
        &nbsp;
        <input class='smbutton' type='button' value='Clear All'
        onClick="javascript:selectAllCheckBoxes(0)" />
        &nbsp;
        <input class='smbutton' type='button' value='Show All Phyla'
        onClick="document.mainForm.page.value='metagtable'; 
                 selectAllCheckBoxes(0); document.mainForm.submit();" />
        <br/>
    };

    # Use YUI css
    my $tableAttr;
    my $thAttr;

    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
	.yui-skin-sam .yui-dt th .yui-dt-liner {
	    white-space:normal;
	}
	</style>

        <div class='yui-dt'>
YUI

        $tableAttr = "style='font-size:12px'";
        $thAttr    = "";
    } else {
        $tableAttr = "class='img' border='1'";
        $thAttr    = "class='img'";
    }

    my $toolTip;

    # Select
    print "<table $tableAttr>\n";
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Select\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # Domain
    print "<th $thAttr title='Domain'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "D\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # Phylum
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Phylum\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # No. of Genomes
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Genomes\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # No. Of Hits 30%
    $toolTip = $plus ? "30% and above" : "30% to 59%";
    print "<th $thAttr title='$toolTip'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 30%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # 30% hits percentage
    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total genome gene count $totalGeneCount'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 30%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 30%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 30%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # No. Of Hits 60%
    $toolTip = $plus ? "60% and above" : "60% to 89%";
    print "<th $thAttr title='$toolTip'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 60%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # 60% hits percentage
    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total genome gene count $totalGeneCount'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 60%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 60%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 60%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # No. Of Hits 90%
    print "<th $thAttr title='90% and above'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 90%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # 90% hits percentage
    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total genome gene count $totalGeneCount'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 90%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 90%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 90%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # add missing keys to 30% list if any
    # the 30 percent is the driver for displaying the table, but
    # with 30-59 % the list may be different since 60 and 90 % ones
    # are not counted in as before when the lisst was >30%
    #
    foreach my $k ( keys %stats60 ) {
        if ( !exists( $stats30{$k} ) ) {
            webLog("WARNING: 60% $k does not exist in 30% list\n");
            $stats30{$k} = "";
        }
    }

    foreach my $k ( keys %stats90 ) {
        if ( !exists( $stats30{$k} ) ) {
            webLog("WARNING: 90% $k does not exist in 30% list\n");
            $stats30{$k} = "";
        }
    }

    my $idx = 0;
    my $classStr;
    my $showUnassigned;
    my @domainPhylum;

    for my $class (@filters) {
        my $unEscClass = CGI::unescape($class);
        if ( $unEscClass ne "unassigned\tunassigned" ) {
            push( @domainPhylum, $unEscClass );
        } else {
            $showUnassigned = 1;
        }
    }

    # if no selections show all phyla/classes
    @domainPhylum = sort( keys(%stats30) ) if ( @filters < 1 );
    $showUnassigned = 1 if ( @filters < 1 );

    for my $dpc (@domainPhylum) {
        my $orgcnt = $orgCount{$dpc};

        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        # see loadMetagenomeStats() for key separator
        my ( $domain, $phylum ) = split( /\t/, $dpc );
        my $r = $stats30{$dpc};
        my ( $domain30, $phylum30, $noHits30, $genomCnt30 ) =
          split( /\t/, $r );

        my $rec60 = $stats60{$dpc};
        my ( $domain60, $phylum60, $noHits60, $genomCnt60 ) =
          split( /\t/, $rec60 );

        my $rec90 = $stats90{$dpc};
        my ( $domain90, $phylum90, $noHits90, $genomCnt90 ) =
          split( /\t/, $rec90 );

        # total number if distinct genomes hits 30, 60 90
        my $lineHit = $genoemeHitStats{$dpc};
        my ( $domainHit, $phylumHit, $genomCntHit ) =
          split( /\t/, $lineHit );

        my $noHits30Url =
          "javascript:mySubmit('$section', 'metagenomeHits', " . "'$domain', '$phylum30', '', '', '', '', '30')";
        my $noHits30Link = qq{<a href="$noHits30Url">  $noHits30 </a> };

        my $noHits60Url =
          "javascript:mySubmit('$section', 'metagenomeHits', " . "'$domain', '$phylum60', '', '', '', '', '60')";
        my $noHits60Link = qq{<a href="$noHits60Url">  $noHits60 </a> };

        my $noHits90Url =
          "javascript:mySubmit('$section', 'metagenomeHits', " . "'$domain', '$phylum90', '', '', '', '', '90')";
        my $noHits90Link = qq{<a href="$noHits90Url">  $noHits90 </a> };

        print "<tr class='$classStr' >\n";

        # check box
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        my $tmp  = CGI::escape("compare_$dpc");
        my $tmp2 = CGI::escape("$dpc");
        print "<input type='checkbox' name='filter' value='$tmp2' checked='checked' />";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # domain
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print substr( $domain, 0, 1 );
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export
        print $res "$domain\t";

        # phylum column
        my $phylum_esc = $phylum;
        $phylum_esc = escHtml($phylum_esc);

        # make url for family page
        my $tmpurl = "javascript:mySubmit('$section', 'family', '$domain', " . "'$phylum', '', '', '', '', '')";

        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print qq{<a href="$tmpurl">$phylum_esc</a> };
        print "</div>\n" if $yui_tables;
        print "</td>\n";


        # export
        print $res "$phylum_esc\t";

        # no. of genomes
        # check whether taxon data is missing by some off chance
        # (see IMG ticket IMGSUPP-457 for background +BSJ 01/17/11)
        $orgcnt = "<span style='color:red'" . "title='Taxon data unavailable'>N/A</span>" if ( !$orgcnt );

        print "<td class='$classStr' style='text-align:right; white-space:nowrap'>";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "$orgcnt ($genomCntHit)";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export
        print $res "$orgcnt ($genomCntHit)\t";

        # 30%
        if ( $genomCnt30 > 0 ) {
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $noHits30Link;
            print " ($genomCnt30)";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res "$noHits30 ($genomCnt30)\t";
        } else {
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print nbsp(1);
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res " \t";
        }

        if ($show_percentage) {
            my $percentHits;
            $percentHits = $noHits30 * 100 / $totalGeneCount;
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ( $percentHits > 0 ) {
                printf "%.2f%", $percentHits;
            } else {
                print nbsp(1);
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res "$percentHits%\t";
        }

        if ($show_hist) {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print histogramBar( $noHits30 / $totalGeneCount, 300 );
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        }

        # 60%
        if ( $genomCnt60 > 0 ) {
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $noHits60Link;
            print " ($genomCnt60)";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res "$noHits60 ($genomCnt60)\t";
        } else {
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print nbsp(1);
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res " \t";
        }

        if ($show_percentage) {
            my $percentHits;
            $percentHits = $noHits60 * 100 / $totalGeneCount;
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ( $percentHits > 0 ) {
                printf "%.2f%", $percentHits;
            } else {
                print nbsp(1);
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res "$percentHits%\t";
        }

        if ($show_hist) {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print histogramBar( $noHits60 / $totalGeneCount, 200 );
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        }

        # 90%
        if ( $genomCnt90 > 0 ) {
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $noHits90Link;
            print " ($genomCnt90)";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res "$noHits90 ($genomCnt90)\t";
        } else {
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print nbsp(1);
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res " \t";
        }

        if ($show_percentage) {
            my $percentHits;
            $percentHits = $noHits90 * 100 / $totalGeneCount;
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ( $percentHits > 0 ) {
                printf "%.2f%", $percentHits;
            } else {
                print nbsp(1);
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export
            print $res "$percentHits%";
        }

        if ($show_hist) {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print histogramBar( $noHits90 / $totalGeneCount, 100 );
            print "</div>\n" if $yui_tables;
            print "</td>\n";
            print "</tr>\n";
        }
        print $res "\n";

        $idx++;
    }

    if ($yui_tables) {
        $classStr = ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
    } else {
        $classStr = "img";
    }

    # Unassigned
    if ($showUnassigned) {
        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        my $dpc = "unassigned\tunassigned";
        print "<input type='checkbox' name='filter' value='$dpc' checked='checked' />";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        print "<td class='$classStr' style='text-align:right; white-space:nowrap' >";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "-";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        print "<td class='$classStr' >";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "Unassigned";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        print "<td class='$classStr' style='text-align:right; white-space:nowrap'>";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "-";
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export unassigned
        print $res "-\t";

        # export unassigned
        print $res "Unassigned\t";

        # export unassigned genome hits
        print $res "-\t";

        my $url  = "javascript:mySubmit('$section', 'unassigned', '', '', '', '', '', '', '30')";
        my $link = alink( $url, $remainCount30 );

        print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $link;
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export unassigned 30
        print $res "$remainCount30\t";

        if ($show_percentage) {
            my $percentHits;
            $percentHits = $remainCount30 * 100 / $totalGeneCount;
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ( $percentHits > 0 ) {
                printf "%.2f%", $percentHits;
            } else {
                print nbsp(1);
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export percent unassigned 30
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print histogramBar( $remainCount30 / $totalGeneCount, 300 );
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        }

        my $url  = "javascript:mySubmit('$section', 'unassigned', '', '', '', '', '', '', '60')";
        my $link = alink( $url, $remainCount60 );

        print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $link;
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export unassigned 60
        print $res "$remainCount60\t";

        if ($show_percentage) {
            my $percentHits;
            $percentHits = $remainCount60 * 100 / $totalGeneCount;
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ( $percentHits > 0 ) {
                printf "%.2f%", $percentHits;
            } else {
                print nbsp(1);
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export percent unassigned 60
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print histogramBar( $remainCount60 / $totalGeneCount, 200 );
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        }

        my $url  = "javascript:mySubmit('$section', 'unassigned', '', '', '', '', '', '', '90')";
        my $link = alink( $url, $remainCount90 );

        print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $link;
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        # export unassigned 90
        print $res "$remainCount90\t";

        if ($show_percentage) {
            my $percentHits;
            $percentHits = $remainCount90 * 100 / $totalGeneCount;
            print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ( $percentHits > 0 ) {
                printf "%.2f%", $percentHits;
            } else {
                print nbsp(1);
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            # export percent unassigned 90
            print $res "$percentHits\t";
        }

        if ($show_hist) {
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print histogramBar( $remainCount90 / $totalGeneCount, 100 );
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        }

        # export end of unassigned
        print $res "\n";
        print "</tr>\n";
    }
    print "</table>\n";
    print "</div>\n" if $yui_tables;

    # export link
    my $contact_oid = WebUtil::getContactOid();
    print qq{
        <p>
        <a href='main.cgi?section=ScaffoldHits&page=download&file=$exportfile&noHeader=1' onclick="_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link ScaffoldHits download']);">
        Export tab delimited Excel file.</a>
        </p>
    };

    print qq{
        <input class='smdefbutton' type='submit' value='Filter'
        onClick="document.mainForm.page.value='metagtable';"/>
        &nbsp;
        <input class='smbutton' type='button' value='Select All'
        onClick="javascript:selectAllCheckBoxes(1)" />
        &nbsp;
        <input class='smbutton' type='button' value='Clear All'
        onClick="javascript:selectAllCheckBoxes(0)" />
        &nbsp;
        <input class='smbutton' type='button' value='Show All Phyla'
        onClick="document.mainForm.page.value='metagtable'; 
                 selectAllCheckBoxes(0); document.mainForm.submit();" />
        <br/>
    };

    print "<p>\n";
    if ($show_hist) {
        print "Histogram is a count of best hits\n";
        print "within the phylum at 30%, 60%, and 90% BLAST identities.\n";
        print "<br/>\n";
    }
    print "<i>Unassigned</i> are the remainder of genes less than ";
    print "the percent identity cutoff, or ";
    print "that are not best hits at the cutoff, or have no hits.\n";
    print "</p>\n";

    print end_form();
    printStatusLine( "Loaded.", 2 );

}

###########################################################################
# listScaffolds
###########################################################################
sub listScaffolds {
    my ($scaffold_ref) = @_;

    my $dbh = dbLogin();
    my $cnt = 0;
    print "<p>Selected Scaffolds: ";
    my $sql = qq{
            select scaffold_name 
            from scaffold
            where scaffold_oid = ?
    };
    my $cur = prepSql( $dbh, $sql, $verbose );
    for my $scaffold_oid (@$scaffold_ref) {
        execStmt( $cur, $scaffold_oid );
        my ($scaffold_name) = $cur->fetchrow();

        my $url2 = "$main_cgi?section=ScaffoldCart" . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
        print nbsp(1);
        print alink( $url2, $scaffold_name );

        $cnt++;
        if ( $cnt > 20 ) {
            print nbsp(1) . "......";
            last;
        }
    }
    print "</p>\n";
    #$dbh->disconnect();
}

#
# Gets unassigned gene count.
# I used minus instead of not in becuz its faster in this case
#
#
# data should be in (select id from gtt_num_id)
#
sub getUnassignedCount {
    my ( $dbh, $scaffold_ref, $perc, $hash_all_genes_href ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return 0;
    }

    my $clause = PhyloUtil::getPercentClause( $perc, 1 );

    my $size = keys %$hash_all_genes_href;
    if ( $size < 1 ) {
        my $sql = qq{
            select distinct g.gene_oid 
            from gene g
            where g.scaffold in (select id from gtt_num_id)
            and g.obsolete_flag = 'No' 
            and g.locus_type = 'CDS' 
        };
        my $cur = execSql( $dbh, $sql, $verbose );

        for ( ; ; ) {
            my ($gene) = $cur->fetchrow();
            last if ( !$gene );
            $hash_all_genes_href->{$gene} = "";
        }
        $cur->finish();
    }

    my %copy_genes = %$hash_all_genes_href;

    my $sql = qq{
        select dt.gene_oid 
        from dt_phylum_dist_genes dt
        where dt.taxon_oid in (select s.taxon
                               from scaffold s
                               where s.scaffold_oid in (select id from gtt_num_id))
        $clause
        and dt.perc_ident_bin = 30
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($gene) = $cur->fetchrow();
        last if ( !$gene );
        delete $copy_genes{$gene};
    }
    $cur->finish();

    my $count = keys %copy_genes;
    return $count;
}

############################################################################
# printMetagenomeHits - Show the gene list from the counts in
#   the histogram for metagenome hits.
#
# database version
#
# param $scaffold_str scaffold_oids
# param $percent_identity percent
# param $phylum
# param $ir_class can be null or blank
# param $cumulative: '+' if cumulative; '' if successive
############################################################################
sub printMetagenomeHits {

    my $scaffold_str = param('scaffold_oids');
    my $percent_identity = param("percent_identity");
    $percent_identity    = param("perc") if ( $percent_identity eq "" );
    my $cumulative = param("plus");    # cumulative selected

    my $domain       = param("domain");
    my $phylum       = param("phylum");
    my $ir_class     = param("ir_class");

    my @scaffold_oids = split( /\,/, $scaffold_str );
    if ( scalar(@scaffold_oids) == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }

    printMainForm();
    printJS();
    print "<h1>\n";
    print "Best Hits at $percent_identity% Identity (Selected Scaffolds)\n";
    print "</h1>\n";
    my $s = "$phylum";
    $s .= " / $ir_class" if $ir_class ne "";
    print "<h2>\n";
    print escHtml($s);
    print "</h2>\n";
    printStatusLine( "Loading ...", 1 );

    print hiddenVar( "section",       "" );
    print hiddenVar( "page",          "" );
    print hiddenVar( "scaffold_oids", "$scaffold_str" );

    my $url3   = "javascript:mySubmit2('ScaffoldCart', 'selectedScaffolds')";
    my $tmpcnt = scalar(@scaffold_oids);
    my $link3  = qq{
        <a href="$url3"> $tmpcnt </a>
    };

    print "<p>Number of selected scaffolds: " . $link3 . "</p>\n";

    WebUtil::printCartFooter( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart" );

    # query
    my $rclause = "";
    if ( $percent_identity == 30 ) {
        $rclause = "and percent_identity < 60" if !$cumulative;
    } elsif ( $percent_identity == 60 ) {
        $rclause = "and percent_identity < 90" if !$cumulative;
    }

    my @binds = ( $phylum, $domain );

    # about ir_class - its blank sometimes
    if ( !defined($ir_class) || $ir_class eq "" ) {
        $rclause .= " and ir_class is null";
    } else {
        $rclause .= " and ir_class = ? ";
        push( @binds, $ir_class );
    }

    my $dbh = dbLogin();
    OracleUtil::insertDataArray( $dbh, "gtt_num_id2", \@scaffold_oids );

    # NOTE I'm using gtt_num_id2 and not gtt_num_id why - because
    # sub queries are using gtt_num_id

    my $imgClause = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql       = qq{ 
       select dt.taxon_oid, dt.domain, dt.phylum, dt.ir_class, dt.gene_oid,
       dt.percent_identity, dt.homolog
       from dt_phylum_dist_genes dt, gene dtg
       where dt.gene_oid = dtg.gene_oid
       and dtg.scaffold in (select id from gtt_num_id2)
       and dt.homolog in (select g2.gene_oid from gene g2 where g2.obsolete_flag = 'No' $imgClause)
       and dt.phylum = ?
       and dt.domain = ?
       and percent_identity >= $percent_identity
       $rclause
   };

    #  unassigned
    # I'm using minus instead of not in because
    # the minus query seems to run faster.
    my $page = param("page");
    if ( $page eq "unassigned" ) {

        #my $g_in_clause = getOraInClause( "g.scaffold", \@scaffold_oids );
        my $clause = PhyloUtil::getPercentClause( $percent_identity, 1 );
        $sql = qq{ 
                select distinct g.taxon, 'd', 'p', 'i', g.gene_oid
                from gene g
                where g.scaffold in (select id from gtt_num_id2 )
                and g.obsolete_flag = 'No' 
                and g.locus_type = 'CDS'
                minus 
                select dt.taxon_oid, 'd', 'p', 'i', dt.gene_oid
                from dt_phylum_dist_genes dt
                where dt.taxon_oid in (select s.taxon
                                       from scaffold s
                                       where s.scaffold_oid in (select id from gtt_num_id2))
                $clause
                and dt.perc_ident_bin = 30
        };

        @binds = ();
    }

    my $contact_oid = getContactOid();
    my @gene_oids;

    # hash of gene oid => to percent
    my %percentHits;
    my $count              = 0;
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    print "<p>\n";
    my $trunc = 0;

    my $sort = param("sort");
    if ( !defined($sort) || $sort eq "" ) {

        # default is col 2, Gene Id
        $sort = 2;
    }

    # array of arrays rec data
    my @recs;

    # hash of arrays cog_id => rec data
    my %hash_cog_func;

    # hash of gene_oid => enzyme
    my %gene2Enzyme;

    # hash of gene oid => cog path ways
    my %hash_cog_pathway;

    my $cur;
    $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $last_gene_oid = "";

    for ( ; ; ) {
        my ( $taxon_oid2, $domain2, $phylum2, $ir_class2, $gene_oid2, $per_cent ) = $cur->fetchrow();
        last if !$taxon_oid2;

        # do not count duplicate gene_oid, with different percentage
        if ( $last_gene_oid ne $gene_oid2 ) {
            $count++;
        }
        $last_gene_oid = $gene_oid2;

        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        if ( scalar(@gene_oids) > $max_gene_batch ) {
            PhyloUtil::getFlushGeneBatch2( $dbh, \@gene_oids, \%percentHits, \@recs, \%gene2Enzyme );

            PhyloUtil::getCogGeneFunction( $dbh, \@gene_oids, \%hash_cog_func );

            PhyloUtil::getCogGenePathway( $dbh, \@gene_oids, \%hash_cog_pathway );

            @gene_oids = ();
        }
        push( @gene_oids, $gene_oid2 );
        $percentHits{$gene_oid2} = $per_cent;
    }

    $cur->finish();

    # query database for data
    PhyloUtil::getFlushGeneBatch2( $dbh, \@gene_oids, \%percentHits, \@recs, \%gene2Enzyme );
    PhyloUtil::getCogGeneFunction( $dbh, \@gene_oids, \%hash_cog_func );

    PhyloUtil::getCogGenePathway( $dbh, \@gene_oids, \%hash_cog_pathway );

    # remove duplicates from the AoA by unique 1st element of each sub array
    @recs = HtmlUtil::uniqAoA( 0, @recs );

    my $it = new InnerTable( 1, "scaffoldhits$$", "scaffoldhits", 1 );
    my $sd = $it->getSdDelim();     # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID", "number asc",  "right" );
    $it->addColSpec( "Precent",        "number desc", "right" );
    $it->addColSpec( "Name",           "char asc",    "left" );
    $it->addColSpec( "COG ID",         "char asc",    "left" );
    $it->addColSpec( "COG Name",       "char asc",    "left" );
    $it->addColSpec( "COG Function",   "char asc",    "left" );
    $it->addColSpec( "COG Gene Count", "number desc", "right" );
    $it->addColSpec( "Estimated Copies", "number desc", "right" );

    foreach my $str (@recs) {
        my (
             $gene_oid,   $percent,       $gene_name,  $gene_symbol, $locus_type, $taxon_oid,
             $taxon_id,   $abbr_name,     $genus,      $species,     $enzyme,     $aa_seq_length,
             $seq_status, $ext_accession, $seq_length, $cog_id,      $copies
          )
          = @$str;

        my $r;

        # col 1
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' />" . "\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_name .= " ( $locus_type $gene_symbol ) ";
        }
        my $genus2     = escHtml($genus);
        my $species2   = escHtml($species);
        my $abbr_name2 = escHtml($abbr_name);
        my $orthStr;
        my $scfInfo = "";
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }

        # col 2
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        # col 3 - percent hits
        $r .= $percent . $sd . $percent . "\t";

        # col 4 - name
        my $tmp = escHtml($gene_name) . " [$abbr_name2]$scfInfo" . " $enzyme";
        $r .= $tmp . $sd . $tmp . "\t";

        # col 5 - cog id
        if ( $cog_id ne "" ) {
            $r .= $cog_id . $sd . $cog_id . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        my $arr_ref = $hash_cog_func{$cog_id};

        # col 6 cog name
        if ( defined($arr_ref) ) {
            $r .= $arr_ref->[0] . $sd . $arr_ref->[0] . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        # col 7 cog function
        if ( defined($arr_ref) ) {
            my $tmp = PhyloUtil::cogfunc( $cog_id, \%hash_cog_func );
            $r .= $tmp . $sd . $tmp . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        # col 8 cog to gene count
        if ( defined($arr_ref) ) {
            my $tmp = $arr_ref->[$#$arr_ref];
            $r .= $tmp . $sd . $tmp . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        if ( !$copies ) {
            $copies = 1;
        }
        $r .= $copies . $sd . $copies . "\t";
        $it->addRow($r);
    }
    $it->printOuterTable(1);

    print "<br/>\n";

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved", 2 );
    }
    #$dbh->disconnect();
    print end_form();

}


############################################################################
# loadMetagenomeStats
#
# data in (select id from gtt_num_id)
############################################################################
sub loadMetagenomeStats {
    my ( $dbh, $scaffold_ref, $percent_identity, $stats_ref, $cumulative, $xcopy ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return 0;
    }

    my $rclause = "";
    if ( $percent_identity == 30 ) {
        $rclause = "and percent_identity < 60" if !$cumulative;
    } elsif ( $percent_identity == 60 ) {
        $rclause = "and percent_identity < 90" if !$cumulative;
    }

    my $test = qq{
            and exists (select 1
                          from gene dtg
                          where dtg.scaffold in (select gtt2.id from gtt_num_id gtt2) 
                          and dtg.taxon = dt.taxon_oid
                          and dtg.gene_oid = dt.gene_oid )    
    };

    my $totalCount = 0;
    
    my $urclause = urClause("dt.homolog_taxon");
    my $imgClause  = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');
    
    my $sql;
    if ( $xcopy eq "gene_count" ) {
        $sql = qq{
            select dt.domain, dt.phylum, 
    	        count(distinct dt.gene_oid ), count(distinct dt.homolog_taxon)
            from dt_phylum_dist_genes dt
            where 1 = 1
            $urclause
            $imgClause
            $test
    	    and percent_identity >= ?
            $rclause
            group by dt.domain, dt.phylum
        };
    } else {
        $sql = qq{
            select dt.domain, dt.phylum
    	        sum(g.est_copy), count(distinct dt.homolog_taxon)
            from dt_phylum_dist_genes dt, gene g
            where 1 = 1
            $urclause
            $imgClause
            $test
    	    and percent_identity >= ?
            $rclause
            and dt.gene_oid = g.gene_oid
            group by dt.domain, dt.phylum
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, $percent_identity );

    for ( ; ; ) {
        my ( $domain, $phylum, $cnt, $cnt_taxon ) = $cur->fetchrow();
        last if !$domain;
        $totalCount += $cnt;
        my $r = "";
        $r .= "$domain\t";
        $r .= "$phylum\t";
        $r .= "$cnt\t";
        $r .= "$cnt_taxon";

        $stats_ref->{"$domain\t$phylum"} = $r;
    }
    $cur->finish();
    return $totalCount;
}

############################################################################
# loadGenomeHitStats
#
# (select id from gtt_num_id)
############################################################################
sub loadGenomeHitStats {
    my ( $dbh, $scaffold_ref, $stats_ref ) = @_;

    if ( scalar(@$scaffold_ref) == 0 ) {
        return;
    }

    my $test = qq{
            and  exists  (select 1
                          from gene dtg
                          where dtg.scaffold in (select gtt2.id from gtt_num_id gtt2) 
                          and dtg.taxon = dt.taxon_oid
                          and dtg.gene_oid = dt.gene_oid )    
    };
    my $imgClause = WebUtil::imgClauseNoTaxon('dt.homolog_taxon');
    my $sql       = qq{ 
        select dt.domain, dt.phylum
            count(distinct dt.homolog_taxon) 
        from dt_phylum_dist_genes dt
        where 1 = 1
        $imgClause
        $test
        and dt.perc_ident_bin = 30
        group by dt.domain, dt.phylum
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $domain, $phylum, $cnt_taxon ) = $cur->fetchrow();
        last if !$domain;
        my $r = "";
        $r .= "$domain\t";
        $r .= "$phylum\t";
        $r .= "$cnt_taxon";
        $stats_ref->{"$domain\t$phylum"} = $r;
    }
    $cur->finish();
}

############################################################################
# printFamilyStats
############################################################################
sub printFamilyStats {

    my $scaffold_str = param('scaffold_oids');
    my @scaffold_oids = split( /\,/, $scaffold_str );
    if ( scalar(@scaffold_oids) == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }

    my $domain          = param("domain");
    my $phylum          = param("phylum");
    my $ir_class        = param("ir_class");
    my $ir_order        = param("ir_order");
    my $show_percentage = param("show_percentage");
    my $show_hist       = param("show_hist");
    my $plus            = param("plus");

    printMainForm();
    printJS();

    print hiddenVar( "section",          $section );
    print hiddenVar( "page",             "" );
    print hiddenVar( "domain",           "" );
    print hiddenVar( "phylum",           "" );
    print hiddenVar( "ir_class",         "" );
    print hiddenVar( "ir_order",         "" );
    print hiddenVar( "family",           "" );
    print hiddenVar( "genus",            "" );
    print hiddenVar( "species",          "" );
    print hiddenVar( "percent_identity", "" );                 # perc
    print hiddenVar( "perc",             "" );
    print hiddenVar( "percent",          "" );
    print hiddenVar( "scaffold_oids",    "$scaffold_str" );
    print hiddenVar( "show_percentage",  $show_percentage );
    print hiddenVar( "show_hist",        $show_hist );
    my $plusVar = ( $plus ) ? "1" : "";
    print hiddenVar( "plus",             $plusVar );

    printStatusLine( "Loading ...", 1 );

    print "<h1>Family Statistics (Selected Scaffolds)</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order );

    my $url3   = "javascript:mySubmit2('ScaffoldCart', 'selectedScaffolds')";
    my $tmpcnt = scalar(@scaffold_oids);
    my $link3  = qq{
        <a href="$url3"> $tmpcnt </a>
    };
    print "<p>Number of selected scaffolds: " . $link3 . "</p>\n";

    # get orignal taxon data
    # for title page
    # now get gene orthologs to get family break down

    my @binds = ( $domain, $phylum );
    my $irclause = " and dt.ir_class = ? ";
    if ( !defined($ir_class) || $ir_class eq "" ) {
        $irclause = " and dt.ir_class is null ";
    } else {
        push( @binds, $ir_class );
    }

    my $dbh          = dbLogin();
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@scaffold_oids );

    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{ 
        select dt.gene_oid, dt.taxon_oid, dt.percent_identity, 
                $nvl(t.family, '$unknown')
                from dt_phylum_dist_genes dt, gene dtg, taxon t
                where dt.homolog_taxon = t.taxon_oid 
                and dt.gene_oid = dtg.gene_oid 
                and dtg.scaffold in (select id from gtt_num_id)
                and dt.domain = ?
                and dt.phylum = ?
                $irclause
                $imgClause
            };

    # hash of distinct family
    # key family name
    # value ""
    my %distinctFamily;

    # hash of arrays
    # key "$family"
    # value array of strings "$taxon\t$gene_oid\t$percent"
    my %stats30;
    my %stats60;
    my %stats90;

    # total gene count
    my $count30 = 0;
    my $count60 = 0;
    my $count90 = 0;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    for ( ; ; ) {
        my ( $gene_oid, $taxon, $percent, $family ) = $cur->fetchrow();
        last if !$gene_oid;

        my $key   = "$family";
        my $value = "$taxon\t$gene_oid\t$percent";

        if ( !exists( $distinctFamily{$key} ) ) {
            $distinctFamily{$key} = "";
        }

        if (    ( $plus && $percent >= 30 )
             || ( !$plus && $percent < 60 ) )
        {
            $count30++;
            if ( exists( $stats30{$key} ) ) {
                my $aref = $stats30{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats30{$key} = \@a;
            }
        }

        if (    ( $plus && $percent >= 60 )
             || ( !$plus && ( $percent >= 60 && $percent < 90 ) ) )
        {
            $count60++;
            if ( exists( $stats60{$key} ) ) {
                my $aref = $stats60{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats60{$key} = \@a;
            }

        }

        if ( $percent >= 90 ) {
            $count90++;
            if ( exists( $stats90{$key} ) ) {
                my $aref = $stats90{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats90{$key} = \@a;
            }
        }
    }
    $cur->finish();

    # table headers
    # Use YUI css
    my $tableAttr;
    my $thAttr;

    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
	.yui-skin-sam .yui-dt th .yui-dt-liner {
	    white-space:normal;
	}
	</style>

        <div class='yui-dt'>
YUI

        $tableAttr = "style='font-size:12px'";
        $thAttr    = "";
    } else {
        $tableAttr = "class='img' border='1'";
        $thAttr    = "class='img'";
    }

    # Family
    print "<table $tableAttr>\n";
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Family\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # No. Of Hits 30%
    print "<th $thAttr title='Unique taxons genes count from 30% to 59%'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 30%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # 30% hits percentage
    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total gene count 30% $count30'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 30%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 30%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 30%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # No. Of Hits 60%
    print "<th $thAttr title='Unique taxons genes count from 60% to 89%'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 60%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total gene count 60% $count60'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 60%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 60%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 60%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # No. Of Hits 90%
    print "<th $thAttr title='Unique taxons genes count'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 90%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # 90% hits percentage
    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total gene count 90% $count90'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 90%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 90%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 90%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    my $idx = 0;
    my $classStr;

    foreach my $key ( sort keys %distinctFamily ) {
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        my $family = $key;
        print "<tr class='$classStr'>\n";
        my $url =
          "javascript:mySubmit('$section', 'species', " . "'$domain', '$phylum', '$ir_class', '$family', '', '', '')";
        $url = qq{<a href="$url">  $family </a> };

        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $url;
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        my $aref30 = $stats30{$key};
        my $aref60 = $stats60{$key};
        my $aref90 = $stats90{$key};

        # 30%
        if ( defined($aref30) ) {
            my $cnt = $#$aref30 + 1;

            # count here should be link to page taxonomyMetagHits
            my $tmpurl =
                "javascript:mySubmit('$section', 'taxonomyMetagHits', "
              . "'$domain', '$phylum', '$ir_class', '$family', '', '', '30')";
            $tmpurl = qq{<a href="$tmpurl">$cnt</a> };

            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $tmpurl;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                my $percentHits;
                $percentHits = $cnt * 100 / $count30;
                print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                if ( $percentHits > 0 ) {
                    printf "%.2f%", $percentHits;
                } else {
                    print nbsp(1);
                }
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print histogramBar( $cnt / $count30, 300 );
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        } else {
            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_percentage) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        }

        # 60%
        if ( defined($aref60) ) {
            my $cnt    = $#$aref60 + 1;
            my $tmpurl =
                "javascript:mySubmit('$section', 'taxonomyMetagHits', "
              . "'$domain', '$phylum', '$ir_class', '$family', '', '', '60')";
            $tmpurl = qq{<a href="$tmpurl">$cnt</a> };

            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $tmpurl;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                my $percentHits;
                $percentHits = $cnt * 100 / $count60;
                print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                if ( $percentHits > 0 ) {
                    printf "%.2f%", $percentHits;
                } else {
                    print nbsp(1);
                }
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print histogramBar( $cnt / $count60, 200 );
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        } else {
            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        }

        # 90%
        if ( defined($aref90) ) {
            my $cnt    = $#$aref90 + 1;
            my $tmpurl =
                "javascript:mySubmit('$section', 'taxonomyMetagHits', "
              . "'$domain', '$phylum', '$ir_class', '$family', '', '', '90')";
            $tmpurl = qq{<a href="$tmpurl">$cnt</a> };

            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $tmpurl;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                my $percentHits;
                $percentHits = $cnt * 100 / $count90;
                print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                if ( $percentHits > 0 ) {
                    printf "%.2f%", $percentHits;
                } else {
                    print nbsp(1);
                }
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print histogramBar( $cnt / $count90, 100 );
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        } else {
            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

        }
        $idx++;
        print "</tr>\n";
    }

    print "</table>\n";
    print "</div>\n" if $yui_tables;
    printStatusLine( "Loaded.", 2 );

    print end_form();
}

#
# print species stats using gene homologs
#
# other param are from the url
#
# param $dbh database handler
#
#
sub printSpeciesStats {

    my $scaffold_str = param('scaffold_oids');
    my @scaffold_oids = split( /\,/, $scaffold_str );
    if ( scalar(@scaffold_oids) == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }

    my $family          = param("family");
    my $taxon_oid       = param("taxon_oid");
    my $domain          = param("domain");
    my $phylum          = param("phylum");
    my $ir_class        = param("ir_class");
    my $ir_order        = param("ir_order");
    my $show_percentage = param("show_percentage");
    my $show_hist       = param("show_hist");
    my $plus            = param("plus");

    printMainForm();
    printJS();

    # mySubmit(page, domain, phylum, irclass, family, genus, species, percent)
    print hiddenVar( "section",          $section );
    print hiddenVar( "page",             "" );
    print hiddenVar( "domain",           "" );
    print hiddenVar( "phylum",           "" );
    print hiddenVar( "ir_class",         "" );
    print hiddenVar( "family",           "" );
    print hiddenVar( "genus",            "" );
    print hiddenVar( "species",          "" );
    print hiddenVar( "percent_identity", "" );                # perc
    print hiddenVar( "perc",             "" );
    print hiddenVar( "percent",          "" );
    print hiddenVar( "scaffold_oids",    "$scaffold_str" );
    my $plusVar = ( $plus ) ? "1" : "";
    print hiddenVar( "plus",             $plusVar );

    printStatusLine( "Loading ...", 1 );

    print "<h1>Species Statistics (Selected Scaffolds)</h1>\n";
    PhyloUtil::printPhyloTitle( $domain, $phylum, $ir_class, $ir_order, $family );

    my $url3   = "javascript:mySubmit2('ScaffoldCart', 'selectedScaffolds')";
    my $tmpcnt = scalar(@scaffold_oids);
    my $link3  = qq{
        <a href="$url3"> $tmpcnt </a>
    };

    print "<p>Number of selected scaffolds: " . $link3 . "</p>\n";

    # no species and genome info
    my $gUrl .= "&taxon_oid=$taxon_oid";
    $gUrl    .= "&domain=$domain";
    $gUrl    .= "&phylum=$phylum";
    $gUrl .= "&ir_class=$ir_class" if ( $ir_class ne "" );
    $gUrl .= "&family=$family"     if ( $family   ne "" );

    print "<p>\n";

    my @binds = ( $domain, $phylum, $family );
    my $irclause = " and dt.ir_class = ? ";
    if ( !defined($ir_class) || $ir_class eq "" ) {
        $irclause = " and dt.ir_class is null ";
    } else {
        push( @binds, $ir_class );
    }

    my $dbh          = dbLogin();
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@scaffold_oids );
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select  dt.gene_oid, dt.taxon_oid, dt.percent_identity,
                $nvl(t.genus, '$unknown'), $nvl(t.species, '$unknown')
                from dt_phylum_dist_genes dt, gene dtg, taxon t
                where dt.homolog_taxon = t.taxon_oid
                and dt.gene_oid = dtg.gene_oid
		        and dtg.scaffold in (select id from gtt_num_id)
                and dt.domain = ?
                and dt.phylum = ?
                and t.family = ?
                $irclause
                and dt.perc_ident_bin = 30
                $imgClause
        };

    # hash of distinct family
    # key family name
    # value ""
    my %distinctFamily;

    # hash of arrays
    # key "$family"
    # value array of strings "$taxon\t$gene_oid\t$percent"
    my %stats30;
    my %stats60;
    my %stats90;

    # total gene count
    my $count30 = 0;
    my $count60 = 0;
    my $count90 = 0;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    for ( ; ; ) {
        my ( $gene_oid, $taxon, $percent, $genus, $species ) = $cur->fetchrow();
        last if !$gene_oid;

        my $key   = "$genus\t$species";
        my $value = "$taxon\t$gene_oid\t$percent";

        if ( !exists( $distinctFamily{$key} ) ) {
            $distinctFamily{$key} = "";
        }

        if (    ( $plus && $percent >= 30 )
             || ( !$plus && $percent < 60 ) )
        {
            $count30++;
            if ( exists( $stats30{$key} ) ) {
                my $aref = $stats30{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats30{$key} = \@a;
            }
        }

        if (    ( $plus && $percent >= 60 )
             || ( !$plus && ( $percent >= 60 && $percent < 90 ) ) )
        {
            $count60++;
            if ( exists( $stats60{$key} ) ) {
                my $aref = $stats60{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats60{$key} = \@a;
            }

        }

        if ( $percent >= 90 ) {
            $count90++;
            if ( exists( $stats90{$key} ) ) {
                my $aref = $stats90{$key};
                push( @$aref, $value );
            } else {
                my @a = ("$value");
                $stats90{$key} = \@a;
            }
        }
    }
    $cur->finish();

    # Use YUI css
    my $tableAttr;
    my $thAttr;

    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <style type="text/css">
	.yui-skin-sam .yui-dt th .yui-dt-liner {
	    white-space:normal;
	}
	</style>

        <div class='yui-dt'>
YUI

        $tableAttr = "style='font-size:12px'";
        $thAttr    = "";
    } else {
        $tableAttr = "class='img' border='1'";
        $thAttr    = "class='img'";
    }

    # Genus Species
    print "<table $tableAttr>\n";
    print "<th $thAttr >\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "Genus Species\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # No. Of Hits 30%
    print "<th $thAttr title='Unique taxons genes count from 30% to 59%'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 30%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # 30% hits percentage
    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total gene count 30% $count30'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 30%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 30%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 30%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # No. Of Hits 60%
    print "<th $thAttr title='Unique taxons genes count from 60% to 89%'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 60%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total gene count 60% $count60'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 60%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 60%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 60%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # No. Of Hits 90%
    print "<th $thAttr title='Unique taxons genes count'>\n";
    print "<div class='yui-dt-liner'><span>" if $yui_tables;
    print "No. Of Hits 90%$plus\n";
    print "</span></div>\n" if $yui_tables;
    print "</th>\n";

    # 90% hits percentage
    if ($show_percentage) {
        print "<th $thAttr title='Hit count / Total gene count 90% $count90'>\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "% Hits 90%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    # Histogram 90%
    if ($show_hist) {
        print "<th $thAttr >\n";
        print "<div class='yui-dt-liner'><span>" if $yui_tables;
        print "Histogram 90%$plus\n";
        print "</span></div>\n" if $yui_tables;
        print "</th>\n";
    }

    my $idx = 0;
    my $classStr;

    foreach my $key ( sort keys %distinctFamily ) {
        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        my ( $genus, $species ) = split( /\t/, $key );
        print "<tr class='$classStr'>\n";

        my $speciesUrl = "<a href='$main_cgi?section=MetagenomeHits";
        $speciesUrl .= "&page=speciesForm";
        $speciesUrl .= "&domain=$domain";
        $speciesUrl .= "&phylum=$phylum";
        $speciesUrl .= "&ir_class=$ir_class" if ( $ir_class ne "" );
        $speciesUrl .= "&family=$family" if ( $family ne "" );
        $speciesUrl .= "&species=$species" if ( $species ne "" );
        $speciesUrl .= "&genus=$genus" if ( $genus ne "" );
        $speciesUrl .= "'>$genus $species</a>\n";

        # genus species column

        my $speciesCell;
        if ($include_metagenomes) {
            $speciesCell = $speciesUrl;
        } else {
            $speciesCell = "$genus $species";
        }

        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print $speciesCell;
        print "</div>\n" if $yui_tables;
        print "</td>\n";

        my $aref30 = $stats30{$key};
        my $aref60 = $stats60{$key};
        my $aref90 = $stats90{$key};

        # 30%
        if ( defined($aref30) ) {
            my $cnt = $#$aref30 + 1;

            my $tmpurl =
                "javascript:mySubmit('$section', 'taxonomyMetagHits', "
              . "'$domain', '$phylum', '$ir_class', '$family', '$genus', '$species', '30')";
            $tmpurl = qq{<a href="$tmpurl">$cnt</a> };

            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $tmpurl;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                my $percentHits;
                $percentHits = $cnt * 100 / $count30;
                print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                if ( $percentHits > 0 ) {
                    printf "%.2f%", $percentHits;
                } else {
                    print nbsp(1);
                }
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print histogramBar( $cnt / $count30, 300 );
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        } else {
            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_percentage) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        }

        # 60%
        if ( defined($aref60) ) {
            my $cnt = $#$aref60 + 1;

            my $tmpurl =
                "javascript:mySubmit('$section', 'taxonomyMetagHits', "
              . "'$domain', '$phylum', '$ir_class', '$family', '$genus', '$species', '60')";
            $tmpurl = qq{<a href="$tmpurl">  $cnt </a> };

            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $tmpurl;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                my $percentHits;
                $percentHits = $cnt * 100 / $count60;
                print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                if ( $percentHits > 0 ) {
                    printf "%.2f%", $percentHits;
                } else {
                    print nbsp(1);
                }
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print histogramBar( $cnt / $count60, 200 );
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        } else {
            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        }

        # 90%
        if ( defined($aref90) ) {
            my $cnt = $#$aref90 + 1;

            my $tmpurl =
                "javascript:mySubmit('$section', 'taxonomyMetagHits', "
              . "'$domain', '$phylum', '$ir_class', '$family', '$genus', '$species', '90')";
            $tmpurl = qq{<a href="$tmpurl">$cnt</a> };

            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $tmpurl;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                my $percentHits;
                $percentHits = $cnt * 100 / $count90;
                print "<td class='$classStr' style='text-align:right; white-space:nowrap'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                if ( $percentHits > 0 ) {
                    printf "%.2f%", $percentHits;
                } else {
                    print nbsp(1);
                }
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print histogramBar( $cnt / $count90, 100 );
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
        } else {
            print "<td class='$classStr' style='text-align:right'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print " - ";
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            if ($show_percentage) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ($show_hist) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

        }
        $idx++;
        print "</tr>\n";
    }
    print "</table>\n";
    print "</div>\n" if $yui_tables;

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

#
# for family stats get list of gene oids
#
# other params from url
#
# param $dbh database handler
#
# return hash ref geneoid to avg percentage
sub getFamilyGeneOids {
    my ( $dbh, $scaffold_str ) = @_;

    my $cumulative = param("plus");    # cumulative selected

    my @scaffold_oids = split( /\,/, $scaffold_str );
    if ( scalar(@scaffold_oids) == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }

    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $family   = param("family");
    my $percent  = param("percent");
    my $species  = param("species");
    my $genus    = param("genus");

    my $percClauseDt;
    if ( $percent == 30 ) {
        $percClauseDt = "and dt.percent_identity < 60" if !$cumulative;
    } elsif ( $percent == 60 ) {
        $percClauseDt = "and dt.percent_identity < 90" if !$cumulative;
    }

    my @binds = ( $domain, $phylum );
    my $familyClause;
    if ( $family ne "" ) {
        $familyClause = "and t.family = ? ";
        push( @binds, $family );
    } else {
        $familyClause = "and t.family is null";
    }

    if ( $species ne "" ) {
        if ( $species eq $unknown ) {
            $familyClause .= " and t.species is null";
        } else {
            $familyClause .= " and t.species = ? ";
            push( @binds, $species );
        }
    }

    if ( $genus ne "" ) {
        if ( $genus eq $unknown ) {
            $familyClause .= " and t.genus is null";
        } else {
            $familyClause .= " and t.genus = ? ";
            push( @binds, $genus );
        }
    }

    my $irclause = " and dt.ir_class = ? ";
    if ( !defined($ir_class) || $ir_class eq "" ) {
        $irclause = " and dt.ir_class is null ";
    } else {
        push( @binds, $ir_class );
    }

    # get list of gene oid and avg percentage
    # query updated using homolog column
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@scaffold_oids );
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select  dt.gene_oid, dt.percent_identity
                from dt_phylum_dist_genes dt, gene dtg, taxon t
                where dt.homolog_taxon = t.taxon_oid
                and dt.gene_oid = dtg.gene_oid
		        and dtg.scaffold in (select id from gtt_num_id)
                and dt.domain = ?
                and dt.phylum = ?
                and percent_identity >= $percent
                $percClauseDt
                $familyClause
                $irclause
                $imgClause
        };

    # hash
    # key gene_oid
    # value avg percent
    my %gene_oids_list;
    my $count = 0;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        $count++;
        my ( $gene_oid, $perc_avg ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_oids_list{$gene_oid} = sprintf( "%.2f", $perc_avg );
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" );
    return \%gene_oids_list;
}

#
# print cog func summary table like printMetagenomeHits()
# and should replace printFamilyStatsDetails()
# this is similar to printMetagenomeHits()
#
# other params from url
#
# param $dbh
sub printTaxonomyMetagHits {

    my $scaffold_str = param('scaffold_oids');
    my @scaffold_oids = split( /\,/, $scaffold_str );
    if ( scalar(@scaffold_oids) == 0 ) {
        webError("No scaffolds have been selected.");
        return;
    }

    my $taxon_oid = param("taxon_oid");
    my $domain    = param("domain");
    my $phylum    = param("phylum");
    my $ir_class  = param("ir_class");
    my $family    = param("family");
    my $percent   = param("percent");
    my $species   = param("species");
    my $genus     = param("genus");

    # subject genome - taxon oid
    my $genome = param("genome");

    printMainForm();
    printJS();

    # mySubmit(page, domain, phylum, irclass, family, genus, species, percent)
    print hiddenVar( "section",          $section );
    print hiddenVar( "page",             "" );
    print hiddenVar( "domain",           "" );
    print hiddenVar( "phylum",           "" );
    print hiddenVar( "ir_class",         "" );
    print hiddenVar( "family",           "" );
    print hiddenVar( "genus",            "" );
    print hiddenVar( "species",          "" );
    print hiddenVar( "percent_identity", "" );                # perc
    print hiddenVar( "perc",             "" );
    print hiddenVar( "percent",          "" );
    print hiddenVar( "scaffold_oids",    "$scaffold_str" );

    print "<h1>\n";
    print "Best Hits at $percent% Identity (Selected Scaffolds)\n";
    print "</h1>\n";
    my $s = "$phylum";
    $s .= " / $ir_class" if $ir_class ne "";
    print "<h2>\n";
    print escHtml($s);
    print "</h2>\n";
    printStatusLine( "Loading ...", 1 );

    my $url3   = "javascript:mySubmit2('ScaffoldCart', 'selectedScaffolds')";
    my $tmpcnt = scalar(@scaffold_oids);
    my $link3  = qq{
        <a href="$url3"> $tmpcnt </a>
    };

    print "<p>Number of selected scaffolds: " . $link3 . "</p>\n";

    WebUtil::printCartFooter( "_section_GeneCartStor_addToGeneCart", "Add Selected to Gene Cart" );

    my $count              = 0;
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $trunc = 0;

    # array of arrays rec data
    my @recs;

    # hash of arrays cog_id => rec data
    my %hash_cog_func;

    # hash of gene_oid => enzyme
    my %gene2Enzyme;

    # hash of gene oid => cog path ways
    my %hash_cog_pathway;

    my $dbh          = dbLogin();
    my $geneOids_href = getFamilyGeneOids( $dbh, $scaffold_str );

    my @gene_oids;
    foreach my $key ( keys(%$geneOids_href) ) {
        $count++;
        push( @gene_oids, $key );

        if ( scalar(@gene_oids) > $max_gene_batch ) {
            PhyloUtil::getFlushGeneBatch2( $dbh, \@gene_oids, $geneOids_href, \@recs, \%gene2Enzyme );

            PhyloUtil::getCogGeneFunction( $dbh, \@gene_oids, \%hash_cog_func );

            PhyloUtil::getCogGenePathway( $dbh, \@gene_oids, \%hash_cog_pathway );

            @gene_oids = ();
        }
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }

    PhyloUtil::getFlushGeneBatch2( $dbh, \@gene_oids, $geneOids_href, \@recs, \%gene2Enzyme );

    PhyloUtil::getCogGeneFunction( $dbh, \@gene_oids, \%hash_cog_func );

    PhyloUtil::getCogGenePathway( $dbh, \@gene_oids, \%hash_cog_pathway );

    # remove duplicates from the AoA by unique 1st element of each sub array
    @recs = HtmlUtil::uniqAoA( 0, @recs );

    # default display - table view
    my $it = new InnerTable( 1, "scaffoldhits$$", "scaffoldhits", 1 );
    my $sd = $it->getSdDelim();     # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID", "number asc",  "right" );
    $it->addColSpec( "Precent",        "number desc", "right" );
    $it->addColSpec( "Name",           "char asc",    "left" );
    $it->addColSpec( "COG ID",         "char asc",    "left" );
    $it->addColSpec( "COG Name",       "char asc",    "left" );
    $it->addColSpec( "COG Function",   "char asc",    "left" );
    $it->addColSpec( "COG Gene Count", "number desc", "right" );
    $it->addColSpec( "Estimated Copies", "number desc", "right" );

    foreach my $str (@recs) {
        my (
             $gene_oid,   $percent,       $gene_name,  $gene_symbol, $locus_type, $taxon_oid,
             $taxon_id,   $abbr_name,     $genus,      $species,     $enzyme,     $aa_seq_length,
             $seq_status, $ext_accession, $seq_length, $cog_id,      $copies
          )
          = @$str;

        my $r;

        # col 1
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' />" . "\t";

        my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_name .= " ( $locus_type $gene_symbol ) ";
        }
        my $genus2     = escHtml($genus);
        my $species2   = escHtml($species);
        my $abbr_name2 = escHtml($abbr_name);
        my $orthStr;
        my $scfInfo = "";
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }

        # col 2
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";

        # col 3 - percent hits
        $r .= $percent . $sd . $percent . "\t";

        # col 4 - name
        my $tmp = escHtml($gene_name) . " [$abbr_name2]$scfInfo" . " $enzyme";
        $r .= $tmp . $sd . $tmp . "\t";

        # col 5 - cog id
        if ( $cog_id ne "" ) {
            $r .= $cog_id . $sd . $cog_id . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        my $arr_ref = $hash_cog_func{$cog_id};

        # col 6 cog name
        if ( defined($arr_ref) ) {
            $r .= $arr_ref->[0] . $sd . $arr_ref->[0] . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        # col 7 cog function
        if ( defined($arr_ref) ) {
            my $tmp = PhyloUtil::cogfunc( $cog_id, \%hash_cog_func );
            $r .= $tmp . $sd . $tmp . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        # col 8 cog to gene count
        if ( defined($arr_ref) ) {
            my $tmp = $arr_ref->[$#$arr_ref];
            $r .= $tmp . $sd . $tmp . "\t";
        } else {
            $r .= "zzz" . $sd . "&nbsp;" . "\t";
        }

        if ( !$copies ) {
            $copies = 1;
        }
        $r .= $copies . $sd . $copies . "\t";

        $it->addRow($r);
    }
    $it->printOuterTable(1);

    print "<br/>\n";

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved", 2 );
    }

    print end_form();

}

sub printJS {
    print qq{
        <script language="javascript" type="text/javascript">

        function mySubmit(section, page, domain, phylum, irclass, family, genus, species, percent) {
            document.mainForm.section.value = section;
            document.mainForm.page.value = page;
            document.mainForm.domain.value = domain;
            document.mainForm.phylum.value = phylum;
            document.mainForm.ir_class.value = irclass;
            document.mainForm.family.value = family;
            document.mainForm.genus.value = genus;
            document.mainForm.species.value = species;
            document.mainForm.percent_identity.value = percent;
            document.mainForm.perc.value = percent;
            document.mainForm.percent.value = percent;
            document.mainForm.submit();
        }        

        function mySubmit2(section, page) {
            document.mainForm.section.value = section;
            document.mainForm.page.value = page;
            document.mainForm.submit();
        }        

        </script>
    };
}
1;
