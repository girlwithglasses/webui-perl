###########################################################################
# Phylogenetic Distribution of Genes from taxon detail
# (file version)
#
# $Id: MetaFileHits.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
###########################################################################
package MetaFileHits;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use POSIX qw(ceil floor);
use CGI qw( :standard );
use CGI::Session;
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use MetagJavaScript;
use MetaFileGraph;
use PhylumTree;
use BarChartImage;
use ChartUtil;
use InnerTable;
use OracleUtil;
use HtmlUtil;
use ScaffoldCart;
use MyIMG;
use MetaUtil;
use MetaGeneTable;
use WorkspaceUtil;
use QueryUtil;
use MerFsUtil;

$| = 1;

my $env                      = getEnv();
my $cgi_dir                  = $env->{cgi_dir};
my $cgi_url                  = $env->{cgi_url};
my $main_cgi                 = $env->{main_cgi};
my $inner_cgi                = $env->{inner_cgi};
my $tmp_url                  = $env->{tmp_url};
my $verbose                  = $env->{verbose};
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
my $myimg_job                = $env->{myimg_job};
my $mer_data_dir             = $env->{mer_data_dir};
my $contact_oid = WebUtil::getContactOid();
#my $maxOrthologGroups = 10;
#my $maxParalogGroups  = 100;

#MyIMG&page=preferences
my $preferences_url    = "$main_cgi?section=MyIMG&page=preferences";
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

# also see MetaJavaSscript for this value too
# method checkSelect()
my $max_scaffold_list = 20;

# Initial list.
my $max_scaffold_list2 = 1000;

# For 2nd order list.
my $max_export_scaffold_list = 100000;

my $max_scaffold_results = 20000;

my $base_url = $env->{base_url};

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my $YUI        = $env->{yui_dir_28};
my $yui_tables = $env->{yui_tables};

my $section = "MetaFileHits";
my $unknown      = "Unknown";
my $unclassified = 'unclassified';

# make sure its last in sorting
my $zzzUnknown = "zzzUnknown";
my $mynull     = "mynull";

my $nvl = getNvl();

# my not sure about this, I think it should be 1
# 0 - all orthologs for the genome
# 1 - only orthologs with query gene of phylum's gene oids
# see MetaFileGraph.pm
#my $GENE_OID_CLAUSE = 1;
#my $GENE_OID_SCAFFLOD_CLAUSE = 1;

my $debug = 0;

#
# dispatch - Dispatch to pages for this section.
#
# this is the hook into main.pl
# to get here, then I use section=??? to go the correct page after
#
sub dispatch {
    my $sid       = getContactOid();
    my $page      = param("page");
    my $taxon_oid = param("taxon_oid");

    # check access permission
    my $dbh = dbLogin();
    # non super users cannot download
    WebUtil::checkTaxonPerm( $dbh, $taxon_oid ) if($taxon_oid ne '');

    if ( $page eq "showProfile"
        || paramMatch("showProfile") ne "" )
    {
        printMetagCateFunc();
        return;
    }

    if ( $page eq "metagenomeHits" ) {
        
        my $view  = param("view");
        if ( $view eq "cogfuncpath" ) {
            printMetagCogFuncPath();
        }
        else {
            # test to see if cached file exists to turn off cgi caching
            my $file1 = param("cf1");

            if ( $file1 eq "" ) {
                HtmlUtil::cgiCacheInitialize( $section);
                HtmlUtil::cgiCacheStart() or return;
            }
            printMetagenomeHits();
            HtmlUtil::cgiCacheStop() if ( $file1 eq "" );
        }

    }
    elsif ( $page eq "cogfunclist" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #  new for 2.7
        printMetagCogFunc();
        HtmlUtil::cgiCacheStop();

    }
    elsif ( $page eq "catefuncgenes" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagCateFuncGenes();
        HtmlUtil::cgiCacheStop();

    }
    elsif ( $page eq "catefuncstatsgenes" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagCateFuncGenes($page);
        HtmlUtil::cgiCacheStop();

    }
    elsif ( $page eq "cogfunclistgenes" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #  new for 2.7 - fix for unknown
        printMetagCogFuncGene();
        HtmlUtil::cgiCacheStop();

    }
    elsif ( $page eq "cogpath" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        # new for 2.7
        printMetagCogPath();
        HtmlUtil::cgiCacheStop();
    }
    elsif ( $page eq "cogpathgenes" ) {

        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #  new for 2.7 - fix for unknown
        printMetagCogPathGene();
        HtmlUtil::cgiCacheStop();
    }
    elsif ( $page eq "unassigned" ) {

        # test to see if cached file exists to turn off cgi caching
        my $file1 = param("cf1");
        if ( $file1 eq "" ) {
            HtmlUtil::cgiCacheInitialize( $section);
            HtmlUtil::cgiCacheStart() or return;
        }
        printMetagenomeHits();
        HtmlUtil::cgiCacheStop() if ( $file1 eq "" );
    }
    elsif ( $page eq "cogFuncStats" ) {     
         HtmlUtil::cgiCacheInitialize( $section);    
         HtmlUtil::cgiCacheStart() or return;    
     
         printMetagenomeCogFuncStats();   
         HtmlUtil::cgiCacheStop();   
    }
    elsif ( $page eq "cogStatsMetagenome" ) {
        BarChartImage::dispatch();
    } 
    elsif ( $page eq "cogPathStatsMetagenome" ) {
        BarChartImage::dispatch();
    } 
    elsif ( $page eq "cogPathStats" ) {
       HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagenomeCogPathStats();
        HtmlUtil::cgiCacheStop();
    } 
    elsif ( $page eq "download" ) {
        checkAccess();
        PhyloUtil::download();
        WebUtil::webExit(0);

    } 
    elsif ( $page eq "ir_class" || $page eq "ir_class_file"
        || $page eq "ir_order" || $page eq "ir_order_file"
        || $page eq "family" || $page eq "family_file"
        || $page eq "genus"  || $page eq "genus_file"
        || $page eq "species" || $page eq "species_file"
        ) {
        my ($taxonomy, $junk) = split( /_file/, $page );
        PhyloUtil::printFileTaxonomyPhyloDist( $section, $taxonomy );

    }
    elsif ( $page eq "taxonomyMetagHits" ) {

        # test to see if cached file exists to turn off cgi caching
        my $file1 = param("cf1");

        # on any family page when you click on the counts to go to
        # the cog functional break down page
        my $dbh = dbLogin();

        if ( $file1 eq "" ) {
            HtmlUtil::cgiCacheInitialize( $section);
            HtmlUtil::cgiCacheStart() or return;
        }

        printTaxonomyMetagHits();

        HtmlUtil::cgiCacheStop() if ( $file1 eq "" );

    }
    elsif ( $page eq "speciesForm" ) {

        # form to select metag scaffold and ref gene scaffold
        if ( ScaffoldCart::isCartEmpty() ) {

            # using caching iff scaffold cart if empty

            HtmlUtil::cgiCacheInitialize($section);
            HtmlUtil::cgiCacheStart() or return;

            PhyloUtil::printSpeciesStatsForm($section);

            HtmlUtil::cgiCacheStop();
        }
        else {

            # no caching if scaffold is being used
            PhyloUtil::printSpeciesStatsForm($section);
        }

    }
    elsif ( $page eq "tree" ) {
        PhylumTree::dispatch();
    } 
    elsif ( $page eq "radialtree" ) {
        require RadialPhyloTree;
        RadialPhyloTree::runTree();
    }
    elsif ( $page eq "metagtable" ) {
        printMetagenomeStatsResults();
    }
    else {

        # stats page by default
        # page = "metagenomeStats"
        my $dbh = dbLogin();


        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printMetagenomeStats( $dbh, $taxon_oid );

        HtmlUtil::cgiCacheStop();

        #$dbh->disconnect();
    }
}

######################################################################
# get file number
######################################################################
sub getFno {
    my ( $gene_id, $total_gene_cnt ) = @_;

    my $genes_per_zip = 2000000;
    my $no_files      = ceil( $total_gene_cnt * 1.0 / $genes_per_zip );

    my $new_id = $gene_id;
    $new_id =~ s/\:/\_/g;

    my $len  = length($new_id);
    my $code = 0;
    my $j    = 0;
    while ( $j < $len ) {
        $code += ( substr( $new_id, $j, 1 ) - '0' );
        $j++;
    }
    return ( $code % $no_files ) + 1;
}


sub printForm {
    my ( $dbh, $taxon_oid ) = @_;

    WebUtil::checkTaxonPerm( $dbh, $taxon_oid );
    my $taxon_name     = QueryUtil::fetchTaxonName( $dbh,     $taxon_oid );
    my $phyloDist_date = PhyloUtil::getPhyloDistDate( $dbh, $taxon_oid );

    my $rna16s  = param('rna16s');
    if ( $rna16s ) {
    	print "<h1>Phylogenetic Distribution of 16S rRNA Genes</h1>";
    	$taxon_oid = sanitizeInt($taxon_oid);
    	for my $dtype2 ( 'assembled', 'unassembled' ) {
            my $file_name_16s = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
                 . "/16s_" . $dtype2 . ".profile.txt"; 
    	    if ( -e $file_name_16s ) {
        		my $mod_date = (stat $file_name_16s)[9];
        		if ( $mod_date ) {
        		    $phyloDist_date = localtime($mod_date);
        		}
    	    }
    	}
    }
    else {
    	print "<h1>Phylogenetic Distribution of Genes in Metagenome</h1>";
    }

    PhyloUtil::printTaxonNameAndPhyloDistDate( $dbh, $taxon_oid, $phyloDist_date );
    PhyloUtil::printPhyloDistMessage_GenesInGenome( $rna16s );

    printStatusLine( "Loading ...", 1 );

    use TabHTML;
    TabHTML::printTabAPILinks("metahitsTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("metahitsTab");
        </script>
    }; 
 
    my @tabIndex;
    my @tabNames;
    if ( $rna16s ) {
        @tabIndex = ( "#metahitstab1" );
        @tabNames = ( "Table View" );
    }
    else {
        @tabIndex = ( "#metahitstab1", "#metahitstab2" );        
        @tabNames = ( "Table View", "Tree View" );
    }
    TabHTML::printTabDiv("metahitsTab", \@tabIndex, \@tabNames);

    print "<div id='metahitstab1'>";

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    my $has_assembled   = 0;
    my $has_unassembled = 0;

    my $file = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) 
	     . "/assembled.profile.txt";
    if ( $rna16s ) {
	   $file = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) 
	      . "/16s_assembled.profile.txt";
    }
    if ( -e $file ) {
        $has_assembled = 1;
    }
    #print "printForm() has_assembled=$has_assembled file=$file<br/>\n";

    my $file2 = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) 
	      . "/unassembled.profile.txt";
    if ( $rna16s ) {
	   $file2 = MetaUtil::getPhyloDistTaxonDir( $taxon_oid ) 
	       . "/16s_unassembled.profile.txt";
    }
    if ( -e $file2 ) {
        $has_unassembled = 1;
    }
    #print "printForm() has_unassembled=$has_unassembled file2=$file2<br/>\n";

    if ( !$has_assembled && !$has_unassembled ) {
        print "<p>No phylogenetic distribution data.\n";
        return;
    }

    print "<p>\n";

    print "<b>Data Type</b><br/>";
    print "<select name='data_type' class='img' size='1'>\n";
    if ($has_assembled) {
        print "<option value='assembled'>assembled</option>\n";
    }
    if ($has_unassembled) {
        print "<option value='unassembled'>unassembled</option>\n";
    }
    if ( $has_assembled && $has_unassembled ) {
        print
            "<option value='both'>both (assembled and unassembled)</option>\n";
    }
    print "</select>\n";
    print "<p>\n";

    print qq{
        <b>Percent Identity</b><br />
        <input type='radio' name="percentage" value='suc' checked='checked' onClick='enableHits("suc")' />
        Successive (30% to 59%, 60% to 89%, 90%+)<br />
        <input type='radio' name="percentage" value='cum' onClick='enableHits("cum")' />
        Cumulative (30%+, 60%+, 90%+)
        <span style='padding-left:5em'><input id='hitChk' type='checkbox' name='show_hits' disabled='disabled' />
        <label for='hitChk'>Display hit genome count</label></span><br/>
    };

    print qq{
        <br/><b>Distribution By</b><br/> 
        <input type='radio' name='xcopy' value='gene_count' checked='checked' />
        Gene count <br/>
        <input type='radio' name='xcopy' value='est_copy' />
        Estimated gene copies <br/>
    };

    print qq{
        <br/>
        <b>Display Options</b><br/>
        <input type='checkbox' name='show_percentage' checked='checked' /> &nbsp; Show percentage column
        (only for gene count)<br/>
        <input type='checkbox' name='show_hist' checked='checked' /> &nbsp; Show histogram column
    };

    print "</p>\n";

    print hiddenVar( "section",    $section );
    print hiddenVar( "page",       "metagtable" );
    print hiddenVar( "taxon_oid",  $taxon_oid );
    print hiddenVar( "fromviewer", "MetagPhyloDist" );
    print hiddenVar( "metag",      "1" );

    if ( $rna16s ) {
    	print hiddenVar( "rna16s", "1");
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
    
    print "</div>"; # end metahitstab1
 
    if ( !$rna16s ) {
        print "<div id='metahitstab2'>"; 
    
        print start_form( -name => "treeForm", -action => $main_cgi );
        print "<p>View the phylogenetic distribution of genes in a "
        . "radial tree format.</p>";
    
        print hiddenVar( "section",          $section );
        print hiddenVar( "page",             "radialtree" );
        print hiddenVar( "selectedGenome1",  $taxon_oid );
        print hiddenVar( "fromviewer",       "TreeFileMgr" );
    
        print submit(
              -name  => "",
              -value => "Draw Tree",
              -class => "smdefbutton"
        );
        print end_form();
    
        print "</div>"; # end metahitstab2        
    }
    TabHTML::printTabDivEnd(); 

    printStatusLine( "Loaded.", 2 );    
}

# main page
#
# print start stats page
#
# param $dbh database handler
# param $taxon_oid taxon oid
#
sub printMetagenomeStats {
    my ( $dbh, $taxon_oid ) = @_;

    MetagJavaScript::printFormJS();

    # Split subroutine to accept user input such as percent identity - Biju
    printForm( $dbh, $taxon_oid );
}

###############################################################################
# printMetagenomeStatsResults: this is the subroutine that prints out
#     the phylo distribution result
###############################################################################
sub printMetagenomeStatsResults {

    #print "MetaFileHits::printMetagenomeStatsResults()<br/>\n";
    my $taxon_oid          = param("taxon_oid");
    my $data_type          = param("data_type");
    my $rna16s             = param("rna16s");

    my $gene_count_file    = param("gene_count_file");
    my $homolog_count_file = param("homolog_count_file");
    my $genome_count_file  = param("genome_count_file");
    my $show_percentage    = param("show_percentage");
    my $show_hist          = param("show_hist");
    my $show_hits          = param("show_hits");
    my $percentage         = param("percentage");        # "suc"=30-59,60-89,90+
                                                         # "cum"=30+,60+,90+
    my $xcopy              = param("xcopy");             # gene_count, est_copy
    
    my @filters = param("filter");    # filter on selected phyla
    #print "printMetagenomeStatsResults() filters: @filters<br/>\n";

    # check access permission
    printStatusLine( "Loading ...", 1 );

    $taxon_oid = sanitizeInt($taxon_oid);

    my $totalGeneCount = PhyloUtil::getFileTotalGeneCount( $taxon_oid, $data_type, $rna16s );
    if ( $totalGeneCount == 0 ) {
        print "<p>No phylogenetic distribution data\n";
        return;
    }

    my $dbh = dbLogin();

    # read "$taxon_stats_dir/$taxon_oid.phylumDist.$perc_identity.tab.txt"
    # to get the stats - ken

    $show_hits = "on"
      if $percentage eq "suc";    # always show genome hit counts if successive
    my $plus = ( $percentage eq "cum" ) ? "+" : "";  # display "+" if cumulative

    printStartWorkingDiv();

    my ( $totalCopyCount, $found_href, $total_href,
    $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
    $depth30_href, $depth60_href, $depth90_href ) 
        = PhyloUtil::loadFileBestBlastHits( $dbh, $taxon_oid, $data_type, $rna16s, $xcopy, $totalGeneCount );

    printEndWorkingDiv();

    #print "printMetagenomeStatsResults()<br/>\n";
    #print Dumper($found_href);
    #print "<br/>\n";

    if ( scalar( keys %$found_href ) == 0 ) {
        printMessage("No phylogenetic distribution has been computed here.");
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $use_phylo_file = 1;
    PhyloUtil::printMetagenomeStatsResultsCore( $dbh, $use_phylo_file, $section, 
        $taxon_oid, $data_type, $rna16s, $xcopy, $show_hist, $show_hits, $show_percentage, 
        $gene_count_file, $homolog_count_file, $genome_count_file, \@filters,
        $plus, $totalGeneCount, $totalCopyCount, $found_href, $total_href,
        $cnt30_href, $cnt60_href, $cnt90_href, $genome30_href, $genome60_href, $genome90_href,
        $depth30_href, $depth60_href, $depth90_href );

}

sub printMetagCogPathGene {
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $plus             = param("plus");
    my $rna16s           = param('rna16s');
    my $cogpath          = param("cogpath");

    my $domain  = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    $taxon_oid = sanitizeInt($taxon_oid);
    my $rna16s = param('rna16s');

    PhyloUtil::printCogViewTitle( $dbh, $taxon_oid, $percent_identity, $plus, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
        
    print "<h3>COG Pathway Gene List</h3>";
    PhyloUtil::printCogFuncTitle( $cogpath, 1 );

    if ( !isInt($cogpath) ) {
        print "<p>No genes found.\n";
        print end_form();
        return;
    }

    printStartWorkingDiv();

    # get COG pathway
    my $dbh = dbLogin();
    my $sql = qq{
        select distinct cpcm.cog_members
        from cog_pathway_cog_members cpcm
        where cpcm.cog_pathway_oid = ?
   };

    # pathway => array of genes
    my @cogs = ();
    my $cur = execSql( $dbh, $sql, $verbose, $cogpath );
    for ( ; ; ) {
        my ($cog_id) = $cur->fetchrow();
        last if !$cog_id;

        push @cogs, ($cog_id);
    }
    $cur->finish();
    #$dbh->disconnect();

    # print table of pathway and gene count
    my $it = new InnerTable( 1, "cogpathgene$$", "cogpathgene", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "char asc",    "left" );
    $it->addColSpec( "Percent",           "number desc", "right" );
    $it->addColSpec( "COG ID",            "char asc",    "left" );
    $it->addColSpec( "Gene Product Name", "char asc",    "left" );

    my $select_id_name = "gene_oid";

    # get all genes of selected phylo
    my %pathways;
    my $gene_cnt = 0;
    my $trunc    = 0;

    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        print "Retrieving gene-COG info ...<br/>\n";
        my %cog_gene_h;
        for my $cog_id (@cogs) {
            my %c_genes =
              MetaUtil::getTaxonFuncGenes( $taxon_oid, $t2, $cog_id );
            for my $g ( keys %c_genes ) {
                if ( $cog_gene_h{$g} ) {
                    $cog_gene_h{$g} .= "," . $cog_id;
                }
                else {
                    $cog_gene_h{$g} = $cog_id;
                }
            }
        }

        print "Retrieving Phylo dist genes for $taxon_oid $t2 ...<br/>\n";
        my @workspace_ids_data;
        PhyloUtil::getFilePhyloGeneList( $taxon_oid, $t2, $percent_identity,
            $plus, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
            $rna16s, 0, 0, \@workspace_ids_data );

        for my $gene_info (@workspace_ids_data) {
            my ( $workspace_id, $perc_identity, @rest ) = split( /\t/, $gene_info );
	        my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);

            if ( !$cog_gene_h{$gene_oid} ) {
                next;
            }

            my $row          = $sd
              . "<input type='checkbox' name='$select_id_name' value='$workspace_id' checked />\t";
            my $url =
                "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
              . "&taxon_oid=$taxon_oid&data_type=$data_type4"
              . "&gene_oid=$gene_oid";
            $row .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
            $row .= $perc_identity . $sd . $perc_identity . "\t";
            $row .=
              $cog_gene_h{$gene_oid} . $sd . $cog_gene_h{$gene_oid} . "\t";
            my $gene_name = "-";
            my @str = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type4 );

            if ( scalar(@str) > 1 ) {
                $gene_name = $str[0];
            }
            $row .= $gene_name . $sd . $gene_name . "\t";

            $it->addRow($row);
            $gene_cnt++;
            if ( $gene_cnt >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }    # end for gene_info
    }    # end for t2

    printEndWorkingDiv();

    if ($gene_cnt) {
        WebUtil::printGeneCartFooter() if ( $gene_cnt > 10 );
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }
    
    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_cnt gene(s) retrieved", 2 );
    }

    
}

###############################################################################
# sub printMetagCateFuncGenes
###############################################################################
sub printMetagCateFuncGenes {
    my ( $page ) = @_;

    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $rna16s           = param('rna16s');
    my $plus             = param("plus");

    my $domain  = param("domain");
    my $phylum  = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");

    my $cogfunc = param("cogfunc");

    $taxon_oid = sanitizeInt($taxon_oid);

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    if ( $page ne "catefuncstatsgenes" ) {
        PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, $data_type, $percent_identity, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus );        
    }
    else {
        my @taxon_array = ( $taxon_oid );
        PhyloUtil::printGenomeListSubHeader( $dbh, \@taxon_array );        
    }

    my $profileType = param('profileType');
    my $category_display_type = PhyloUtil::getFuncTextVal($profileType);
    if ( !$category_display_type ) {
        webError("Unknown function type: $profileType\n"); 
    }
    print "<h3>\n";
    print "$category_display_type Gene List";
    print "</h3>\n";

    my $cate_id = param('cate_id');    
    if ( !$cate_id ) {
        webError("No function is selected.\n");
    }

    my ($category_name) = PhyloUtil::getCategoryName( $dbh, $profileType, $cate_id );    
    print "<p>\n";
    print "$category_name";
    print "</p>\n";

    # print table of function and gene count
    my $it = new InnerTable( 1, "catefuncgene$$", "catefuncgene", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "char asc",    "left" );
    $it->addColSpec( "Percent Identity",  "number desc", "right" );
    $it->addColSpec( "Function ID",       "char asc",    "left" );
    $it->addColSpec( "Gene Product Name", "char asc",    "left" );

    my $select_id_name = "gene_oid";

    my @funcs = PhyloUtil::getFuncsFromCategoryId( $dbh, $profileType, $cate_id );
        
    printStartWorkingDiv();

    # get all genes of selected phylo
    my $gene_cnt = 0;
    my $trunc    = 0;
    my $func_type = PhyloUtil::getFuncTypeFromProfileType( $profileType );
        
    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        print "Retrieving gene-function info ...<br/>\n";
        my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_type, \@funcs );
        #print "printMetagCateFuncGenes() func_genes:<br/>\n";
        #print Dumper(\%func_genes);
        #print "<br/>\n";

        my %gene2func_h;
        for my $func_id ( keys %func_genes ) {
            my @funcGenes = split( /\t/, $func_genes{$func_id} );
            for my $gene (@funcGenes) {
                my $funcs_href = $gene2func_h{$gene};
                if ( $funcs_href ) {
                    $funcs_href->{$func_id} = 1;
                }
                else {
                    my %funcs_h;
                    $funcs_h{$func_id} = 1;
                    $gene2func_h{$gene} = \%funcs_h;
                }
            }
        }
        #print "printMetagCateFuncGenes() genes2func_h:<br/>\n";
        #print Dumper(\%genes2func_h);
        #print "<br/>\n";

        print "<p>Retrieving Phylo dist genes for $taxon_oid $t2 ...<br/>\n";
        my @workspace_ids_data;
        PhyloUtil::getFilePhyloGeneList( $taxon_oid, $t2, $percent_identity,
              $plus, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
              $rna16s, 0, 0, \@workspace_ids_data );

        for my $gene_info (@workspace_ids_data) {
            my ( $workspace_id, $perc_identity, @rest ) = split( /\t/, $gene_info );
	        my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
            if ( !$gene2func_h{$gene_oid} ) {
                next;
            }

            my $row = $sd
              . "<input type='checkbox' name='$select_id_name' value='$workspace_id' checked />\t";
            my $url =
                "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
              . "&taxon_oid=$taxon_oid&data_type=$data_type4"
              . "&gene_oid=$gene_oid";
            $row .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
            $row .= $perc_identity . $sd . $perc_identity . "\t";
            
            my $funcs_href = $gene2func_h{$gene_oid};
            my @func_ids = keys %$funcs_href;
            my $funcs_str = join(',', @func_ids);
            $row .= $funcs_str . $sd . $funcs_str . "\t";

            my $gene_name = "-";
            my @str = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type4 );
            if ( scalar(@str) > 1 ) {
                $gene_name = $str[0];
            }
            $row .= $gene_name . $sd . $gene_name . "\t";

            $it->addRow($row);
            $gene_cnt++;
            if ( $gene_cnt >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }    # end for gene_info
    }    # end for t2

    printEndWorkingDiv();

    if ($gene_cnt) {
        WebUtil::printGeneCartFooter() if ( $gene_cnt > 10 );
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_cnt gene(s) retrieved", 2 );
    }
}

#
#
#
sub printMetagCogFuncGene {
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $plus             = param("plus");
    my $rna16s           = param('rna16s');
    my $cogfunc          = param("cogfunc");

    my $domain  = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    $taxon_oid = sanitizeInt($taxon_oid);

    PhyloUtil::printCogViewTitle( $dbh, $taxon_oid, $percent_identity, $plus, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
        
    print "<h3>Cog Functional Category Gene List</h3>";
    PhyloUtil::printCogFuncTitle( $cogfunc );

    printStartWorkingDiv();

    # get COG pathway
    my $sql = qq{
        select distinct cog_id
        from cog_functions
        where functions = ?
   };

    # pathway => array of genes
    my @cogs = ();
    my $cur = execSql( $dbh, $sql, $verbose, $cogfunc );
    for ( ; ; ) {
        my ($cog_id) = $cur->fetchrow();
        last if !$cog_id;

        push @cogs, ($cog_id);
    }
    $cur->finish();

    # print table of function and gene count
    my $it = new InnerTable( 1, "cogfuncgene$$", "cogfuncgene", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "char asc",    "left" );
    $it->addColSpec( "Percent",           "number desc", "right" );
    $it->addColSpec( "COG ID",            "char asc",    "left" );
    $it->addColSpec( "Gene Product Name", "char asc",    "left" );

    my $select_id_name = "gene_oid";

    # get all genes of selected phylo
    my $gene_cnt = 0;
    my $trunc    = 0;
    
    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        print "Retrieving gene-COG info ...<br/>\n";
        my %cog_gene_h;
        for my $cog_id (@cogs) {
            my %c_genes =
              MetaUtil::getTaxonFuncGenes( $taxon_oid, $t2, $cog_id );
            for my $g ( keys %c_genes ) {
                if ( $cog_gene_h{$g} ) {
                    $cog_gene_h{$g} .= "," . $cog_id;
                }
                else {
                    $cog_gene_h{$g} = $cog_id;
                }
            }
        }

        print "Retrieving Phylo dist genes for $taxon_oid $t2 ...<br/>\n";
        my @workspace_ids_data;
        PhyloUtil::getFilePhyloGeneList( $taxon_oid, $t2, $percent_identity,
              $plus, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
              $rna16s, 0, 0, \@workspace_ids_data );

        for my $gene_info (@workspace_ids_data) {
            my ( $workspace_id, $perc_identity, @rest ) = split( /\t/, $gene_info );
	        my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
            if ( !$cog_gene_h{$gene_oid} ) {
                next;
            }

            my $row          = $sd
              . "<input type='checkbox' name='$select_id_name' value='$workspace_id' checked />\t";
            my $url =
                "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
              . "&taxon_oid=$taxon_oid&data_type=$data_type4"
              . "&gene_oid=$gene_oid";
            $row .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
            $row .= $perc_identity . $sd . $perc_identity . "\t";
            $row .=
              $cog_gene_h{$gene_oid} . $sd . $cog_gene_h{$gene_oid} . "\t";
            my $gene_name = "-";
            my @str = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type4 );

            if ( scalar(@str) > 1 ) {
                $gene_name = $str[0];
            }
            $row .= $gene_name . $sd . $gene_name . "\t";

            $it->addRow($row);
            $gene_cnt++;
            if ( $gene_cnt >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }    # end for gene_info
    }    # end for t2

    printEndWorkingDiv();

    if ($gene_cnt) {
        WebUtil::printGeneCartFooter() if ( $gene_cnt > 10 );
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_cnt gene(s) retrieved", 2 );
    }

}

#########################################################################
# printMetagCateFunc
#########################################################################
sub printMetagCateFunc {

    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $rna16s           = param('rna16s');
    my $plus             = param("plus");

    # add domain
    my $domain   = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family   = param("family");
    my $genus    = param("genus");
    my $species  = param("species");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, $data_type, $percent_identity, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus );

    my $profileType = param('profileType');
    my $category_display_type = PhyloUtil::getFuncTextVal($profileType);
    if ( !$category_display_type ) {
        webError("Unknown function type: $profileType\n"); 
    }
    print "<h3>$category_display_type View</h3>\n";

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    # get category
    my ( $cateId2cateName_href, $cateName2cateId_href, $cateId2funcs_href, $func2cateId_href )
        = PhyloUtil::getAllCategoryInfo( $dbh, $profileType );

    $taxon_oid = sanitizeInt($taxon_oid);

    # get all genes of selected phylo
    my %category2gcnt;
    my $unknownCount = 0;
    my $trunc = 0;
    my $func_type = PhyloUtil::getFuncTypeFromProfileType( $profileType );
    
    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        print "Retrieving gene-function info ...<br/>\n";
        my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_type );
        #print "printMetagCateFunc() func_genes:<br/>\n";
        #print Dumper(\%func_genes);
        #print "<br/>\n";

        my %gene2func_h;
        for my $func_id ( keys %func_genes ) {
            my @funcGenes = split( /\t/, $func_genes{$func_id} );
            for my $gene (@funcGenes) {
                my $funcs_href = $gene2func_h{$gene};
                if ( $funcs_href ) {
                    $funcs_href->{$func_id} = 1;
                }
                else {
                    my %funcs_h;
                    $funcs_h{$func_id} = 1;
                    $gene2func_h{$gene} = \%funcs_h;
                }
            }
        }
        #print "printMetagCateFunc() genes2func_h:<br/>\n";
        #print Dumper(\%genes2func_h);
        #print "<br/>\n";

        print "Retrieving Phylo dist genes for $taxon_oid $t2 ...<br/>\n";
        my @workspace_ids;
        $trunc = PhyloUtil::getFilePhyloGeneList( 
            $taxon_oid, $t2, $percent_identity, $plus, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
            $rna16s, 1, 0, \@workspace_ids );

        print "Process gene info ...<br/>\n";
        foreach my $workspace_id (@workspace_ids) {
            my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);

            # get funcs for this gene
            my $funcs_href = $gene2func_h{$gene_oid};
            my @funcs = keys %$funcs_href;

            my %gene_category;
            for my $func_id (@funcs) {
                if ( $func2cateId_href->{$func_id} ) {
                    my @p_list = split( /\t/, $func2cateId_href->{$func_id} );
                    for my $p (@p_list) {
                        $gene_category{$p} = 1;
                    }
                }
            }    # end for func_id

            for my $p2 ( keys %gene_category ) {
                if ( $category2gcnt{$p2} ) {
                    $category2gcnt{$p2} += 1;
                }
                else {
                    $category2gcnt{$p2} = 1;
                }
            }    # end for p2

            if ( scalar( keys %gene_category ) == 0 ) {
                $unknownCount++;
            }

            undef %gene_category;
        }    # end for gene_oid
 
    }

    printEndWorkingDiv();

    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }

    my $gene_count_total = PhyloUtil::printCateChart( $section,
        $taxon_oid, $data_type, $percent_identity, $plus,
        $domain,    $phylum,    $ir_class,         $ir_order, 
        $family,    $genus,     $species,          $rna16s,
        $profileType, $category_display_type,
        $cateId2cateName_href, $cateName2cateId_href, \%category2gcnt, $unknownCount
    );

    printStatusLine( "$gene_count_total (duplicates*) Loaded.", 2 );
}

############################################################################
sub printMetagCogPath {
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $rna16s           = param('rna16s');

    # add domain
    my $domain  = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");
    my $plus    = param("plus");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    $taxon_oid = sanitizeInt($taxon_oid);

    PhyloUtil::printCogViewTitle( $dbh, $taxon_oid, $percent_identity, $plus, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    print "<h3>COG Pathway View</h3>\n";

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    # get COG pathway
    my $sql = qq{
        select distinct cp.cog_pathway_oid, cp.cog_pathway_name, cpcm.cog_members
        from cog_pathway cp, cog_pathway_cog_members cpcm
        where cp.cog_pathway_oid = cpcm.cog_pathway_oid
        order by 1, 2, 3
   };

    # pathway => array of genes
    my %pathway_names;
    my %cog_pathways;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cog_pathway_oid, $cog_pathway_name, $cog_id ) = $cur->fetchrow();
        last if !$cog_pathway_oid;

        if ( !$pathway_names{$cog_pathway_oid} ) {
            $pathway_names{$cog_pathway_oid} = $cog_pathway_name;
        }

        if ( $cog_pathways{$cog_id} ) {
            $cog_pathways{$cog_id} .= "\t" . $cog_pathway_oid;
        }
        else {
            $cog_pathways{$cog_id} = $cog_pathway_oid;
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    # get all genes of selected phylo
    my %pathways;
    my $unknownCount = 0;
    my $trunc = 0;
    
    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        my @workspace_ids;
        print "Retrieving Phylo dist genes for $taxon_oid $t2 ...<br/>\n";

        $trunc = PhyloUtil::getFilePhyloGeneList( 
            $taxon_oid, $data_type, $percent_identity, $plus, 
            $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
            $rna16s, 1, 0, \@workspace_ids );

        if ( scalar(@workspace_ids) > 200 ) {

            # pathway -> cog -> gene
            print "Retrieving COG Pathway info ...<br/>\n";
            my %cog_gene_h;
            my $dbh = dbLogin();
            my $sql = "select cog_pathway_oid from cog_pathway order by 1";
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                print ".";
                my ($pid) = $cur->fetchrow();
                last if !$pid;

                my $sql2 = qq{
                           select distinct cpcm.cog_members
                           from cog_pathway_cog_members cpcm
                           where cpcm.cog_pathway_oid = ?
          		   };
                my $cur2 = execSql( $dbh, $sql2, $verbose, $pid );
                for ( ; ; ) {
                    my ($cog_id) = $cur2->fetchrow();
                    last if !$cog_id;

                    my %c_genes =
                      MetaUtil::getTaxonFuncGenes( $taxon_oid, $t2, $cog_id );
                    for my $g ( keys %c_genes ) {
                        if ( $cog_gene_h{$g} ) {
                            $cog_gene_h{$g} .= "\t" . $cog_id;
                        }
                        else {
                            $cog_gene_h{$g} = $cog_id;
                        }
                    }
                    undef %c_genes;
                }
                $cur2->finish();
            }
            $cur->finish();
            #$dbh->disconnect();
            print "<br/>\n";

            print "Retrieving gene info ...<br/>\n";
            my $cnt = 0;
            for my $workspace_id (@workspace_ids) {
		my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
                $cnt++;
                if ( ( $cnt % 5 ) == 0 ) {
                    print ".";
                }
                if ( ( $cnt % 900 ) == 0 ) {
                    print "\n<br/>\n";
                }

                # get cog for this gene
                my @cogs = split( /\t/, $cog_gene_h{$gene_oid} );
                my %gene_pathway;
                for my $cog_id (@cogs) {
                    if ( $cog_pathways{$cog_id} ) {
                        my @p_list = split( /\t/, $cog_pathways{$cog_id} );
                        for my $p (@p_list) {
                            $gene_pathway{$p} = 1;
                        }
                    }
                }    # end for cog_id

                for my $p2 ( keys %gene_pathway ) {
                    if ( $pathways{$p2} ) {
                        $pathways{$p2} += 1;
                    }
                    else {
                        $pathways{$p2} = 1;
                    }
                }    # end for p2

                if ( scalar( keys %gene_pathway ) == 0 ) {
                    $unknownCount++;
                }

                undef %gene_pathway;
            }    # end for gene_oid
        }
        else {

            # gene -> cog -> pathway
            print "Retrieving gene-COG info ...<br/>\n";
            my $cnt = 0;
            for my $workspace_id (@workspace_ids) {
		my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
                $cnt++;
                if ( ( $cnt % 5 ) == 0 ) {
                    print ".";
                }
                if ( ( $cnt % 900 ) == 0 ) {
                    print "\n<br/>\n";
                }

                # get cog for this gene
                my @cogs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type4 );

                my %gene_pathway;
                for my $cog_id (@cogs) {
                    if ( $cog_pathways{$cog_id} ) {
                        my @p_list = split( /\t/, $cog_pathways{$cog_id} );
                        for my $p (@p_list) {
                            $gene_pathway{$p} = 1;
                        }
                    }

                    for my $p2 ( keys %gene_pathway ) {
                        if ( $pathways{$p2} ) {
                            $pathways{$p2} += 1;
                        }
                        else {
                            $pathways{$p2} = 1;
                        }
                    }
                }

                if ( scalar( keys %gene_pathway ) == 0 ) {
                    $unknownCount++;
                }
            }
        }
    }

    printEndWorkingDiv();

    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }

    # print table of pathway and gene count
    my $it = new InnerTable( 1, "metacyc$$", "metacyc", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "COG Pathway", "char asc",    "left" );
    $it->addColSpec( "Gene Count",  "number desc", "right" );

    my $p_count = 0;
    foreach my $pathway_oid ( keys %pathways ) {
        my $pname  = $pathway_names{$pathway_oid};
        my $gcount = $pathways{$pathway_oid};

        my $r;

        $r .= $pname . $sd . $pname . "\t";

        my $url =
            "$main_cgi?section=MetaFileHits"
          . "&page=cogpathgenes&taxon_oid=$taxon_oid"
          . "&percent_identity=$percent_identity"
          . "&phylum="
          . WebUtil::massageToUrl2($phylum)
          . "&cogpath=$pathway_oid"
          . "&domain="
          . WebUtil::massageToUrl2($domain);
        $url .= "&family=$family"     if ( $family   ne "" );
        $url .= "&genus=$genus"       if ( $genus    ne "" );
        $url .= "&species=$species"   if ( $species  ne "" );
        $url .= "&ir_class=$ir_class" if ( $ir_class ne "" );

        if ($data_type) {
            $url .= "&data_type=$data_type";
        }

        $url = alink( $url, $gcount );

        $r .= "$gcount" . $sd . "$url" . "\t";

        $it->addRow($r);
        $p_count++;
    }

    if ($p_count) {
        $it->printOuterTable(1);
    }

    print "<p>Genes not belong to any COG Pathway: $unknownCount\n";

    printStatusLine( "Loaded.", 2 );
}

##### ??????
sub printMetagCogFunc {
    my $taxon_oid        = param("taxon_oid");
    my $data_type        = param("data_type");
    my $percent_identity = param("percent_identity");
    my $rna16s           = param('rna16s');

    # add domain
    my $domain  = param("domain");
    my $phylum   = param("phylum");
    my $ir_class = param("ir_class");
    my $ir_order = param("ir_order");
    my $family  = param("family");
    my $genus   = param("genus");
    my $species = param("species");
    my $plus    = param("plus");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    $taxon_oid = sanitizeInt($taxon_oid);

    PhyloUtil::printCogViewTitle( $dbh, $taxon_oid, $percent_identity, $plus, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );
    print "<h3>COG Category View</h3>\n";    

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    # get COG category
    my $sql = qq{
        select distinct cf.function_code, cf.definition, cfs.cog_id
        from cog_function cf, cog_functions cfs
        where cf.function_code = cfs.functions
        order by 1, 2, 3
   };

    # category => array of genes
    my %category_names;
    my %cog_categories;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $func_code, $func_name, $cog_id ) = $cur->fetchrow();
        last if !$func_code;

        if ( !$category_names{$func_code} ) {
            $category_names{$func_code} = $func_name;
        }

        if ( $cog_categories{$cog_id} ) {
            $cog_categories{$cog_id} .= "\t" . $func_code;
        }
        else {
            $cog_categories{$cog_id} = $func_code;
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    # get all genes of selected phylo
    my %category2gcnt;
    my $unknownCount = 0;
    my $trunc = 0;
    
    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        my @workspace_ids;
        print "Retrieving Phylo dist genes for $taxon_oid $t2 ...<br/>\n";

        $trunc = PhyloUtil::getFilePhyloGeneList( 
           $taxon_oid, $t2, $percent_identity, $plus, 
           $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
           $rna16s, 1, 0, \@workspace_ids );

        if ( scalar(@workspace_ids) > 200 ) {

            # category -> cog -> gene
            print "Retrieving COG Category info ...<br/>\n";
            my %cog_gene_h;
            my $dbh = dbLogin();
            my $sql = "select function_code from cog_function order by 1";
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                print ".";
                my ($pid) = $cur->fetchrow();
                last if !$pid;

                my $sql2 = qq{
                           select distinct cfs.cog_id
                           from cog_functions cfs
                           where cfs.functions = ?
          		   };
                my $cur2 = execSql( $dbh, $sql2, $verbose, $pid );
                for ( ; ; ) {
                    my ($cog_id) = $cur2->fetchrow();
                    last if !$cog_id;

                    print ".";
                    my %c_genes =
                      MetaUtil::getTaxonFuncGenes( $taxon_oid, $t2, $cog_id );
                    for my $g ( keys %c_genes ) {
                        if ( $cog_gene_h{$g} ) {
                            $cog_gene_h{$g} .= "\t" . $cog_id;
                        }
                        else {
                            $cog_gene_h{$g} = $cog_id;
                        }
                    }
                    undef %c_genes;
                }
                $cur2->finish();
                print "<br/>\n";
            }
            $cur->finish();
            #$dbh->disconnect();
            print "<br/>\n";

            print "Retrieving gene info ...<br/>\n";
            my $cnt = 0;
            for my $workspace_id (@workspace_ids) {
		my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
                $cnt++;
                if ( ( $cnt % 5 ) == 0 ) {
                    print ".";
                }
                if ( ( $cnt % 900 ) == 0 ) {
                    print "\n<br/>\n";
                }

                # get cog for this gene
                my @cogs = split( /\t/, $cog_gene_h{$gene_oid} );
                my %gene_category;
                for my $cog_id (@cogs) {
                    if ( $cog_categories{$cog_id} ) {
                        my @p_list = split( /\t/, $cog_categories{$cog_id} );
                        for my $p (@p_list) {
                            $gene_category{$p} = 1;
                        }
                    }
                }    # end for cog_id

                for my $p2 ( keys %gene_category ) {
                    if ( $category2gcnt{$p2} ) {
                        $category2gcnt{$p2} += 1;
                    }
                    else {
                        $category2gcnt{$p2} = 1;
                    }
                }    # end for p2

                if ( scalar( keys %gene_category ) == 0 ) {
                    $unknownCount++;
                }

                undef %gene_category;
            }    # end for gene_oid
        }
        else {

            # gene -> cog -> category
            print "Retrieving gene-COG info ...<br/>\n";
            my $cnt = 0;
            for my $workspace_id (@workspace_ids) {
		my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
                $cnt++;
                if ( ( $cnt % 5 ) == 0 ) {
                    print ".";
                }
                if ( ( $cnt % 900 ) == 0 ) {
                    print "\n<br/>\n";
                }

                # get cog for this gene
                my @cogs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type4 );

                my %gene_category;
                for my $cog_id (@cogs) {
                    if ( $cog_categories{$cog_id} ) {
                        my @p_list = split( /\t/, $cog_categories{$cog_id} );
                        for my $p (@p_list) {
                            $gene_category{$p} = 1;
                        }
                    }

                    for my $p2 ( keys %gene_category ) {
                        if ( $category2gcnt{$p2} ) {
                            $category2gcnt{$p2} += 1;
                        }
                        else {
                            $category2gcnt{$p2} = 1;
                        }
                    }
                }

                if ( scalar( keys %gene_category ) == 0 ) {
                    $unknownCount++;
                }
            }
        }
    }

    printEndWorkingDiv();

    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "\n";
    }

    # print table of pathway and gene count
    my $it = new InnerTable( 1, "metacyc$$", "metacyc", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "COG Functional Category", "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );

    my $c_count = 0;
    foreach my $cate_oid ( keys %category2gcnt ) {
        my $cname  = $category_names{$cate_oid};
        my $gcount = $category2gcnt{$cate_oid};

        my $r;

        $r .= $cname . $sd . $cname . "\t";

        my $url =
            "$main_cgi?section=MetaFileHits"
          . "&page=cogfunclistgenes&taxon_oid=$taxon_oid"
          . "&percent_identity=$percent_identity"
          . "&phylum="
          . WebUtil::massageToUrl2($phylum)
          . "&cogfunc=$cate_oid"
          . "&domain="
          . WebUtil::massageToUrl2($domain);
        $url .= "&family=$family"     if ( $family   ne "" );
        $url .= "&genus=$genus"       if ( $genus    ne "" );
        $url .= "&species=$species"   if ( $species  ne "" );
        $url .= "&ir_class=$ir_class" if ( $ir_class ne "" );

        if ($data_type) {
            $url .= "&data_type=$data_type";
        }

        $url = alink( $url, $gcount );

        $r .= "$gcount" . $sd . "$url" . "\t";

        $it->addRow($r);
        $c_count++;
    }

    if ($c_count) {
        $it->printOuterTable(1);
    }

    print "<p>Genes not belong to any COG Category: $unknownCount\n";

    printStatusLine( "Loaded.", 2 );
}

#
# print metag cog func pathways detail
#
sub printMetagCogFuncPath {
    printMainForm();
    printStatusLine( "Loading ...", 1 );
    PhyloUtil::printCartFooter2( "_section_GeneCartStor_addToGeneCart",
        "Add Selected to Gene Cart" );

    # cache files
    my ( $file1, $file2, $file4 );
    $file1 = param("cf1");
    $file2 = param("cf2");
    $file4 = param("cf4");

    my ( $r_ref, $h_ref, $p_ref ) =
      PhyloUtil::readCacheData( $file1, $file2, $file4 );

    #print "<script language='JavaScript' type='text/javascript'\n";
    #print "src='$base_url/taxonDetails.js'></script>\n";

    MetagJavaScript::printMetagJS();

    # this is a html esc function name
    my $functionname = param("function");

    PhyloUtil::flushGeneBatch3path( $r_ref, $h_ref, $p_ref, $functionname );

    printStatusLine( "gene(s) retrieved", 2 );
    print end_form();
}

############################################################################
# printMetagenomeHits - Show the gene list from the counts in
#   the histogram for metagenome hits.
#
# database version
#
# param $taxon_oid taxon oid
# param $percent_identity percent
# param $phylum
# param $ir_class can be null or blank
#
############################################################################
sub printMetagenomeHits {
    my ( $taxon_oid, $data_type, $percent_identity, $domain, $phylum, $plus )
      = @_;

    $taxon_oid = param("taxon_oid")        if !$taxon_oid;
    $data_type = param("data_type")        if !$data_type;
    $percent_identity = param("percent_identity") if !$percent_identity;
    $percent_identity = param("percent")   if !$percent_identity;
    $percent_identity = param("perc")      if !$percent_identity;
    $plus      = param("plus")             if !$plus;

    $domain    = param("domain")           if !$domain;
    $phylum    = param("phylum")           if !$phylum;

    my $xcopy = param("xcopy");
    my $rna16s = param('rna16s');

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    WebUtil::checkTaxonPerm( $dbh, $taxon_oid );

    $taxon_oid = sanitizeInt($taxon_oid);

    PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, $data_type, $percent_identity, 
        $domain, $phylum, '', '', '', '', '', $rna16s, $plus );
    
    print hiddenVar( "taxon_oid",        $taxon_oid );
    print hiddenVar( "data_type",        $data_type );
    print hiddenVar( "domain",           $domain );
    print hiddenVar( "phylum",           $phylum );
    print hiddenVar( "percent_identity", $percent_identity );
    print hiddenVar( "plus",             1 ) if $plus;
    print hiddenVar( "xcopy",            $xcopy ) if $xcopy;
	print hiddenVar( "rna16s", $rna16s ) if ( $rna16s );

    my $page = param("page");

    timeout( 60 * $merfs_timeout_mins );

    my $timeout_msg = "";
    my $start_time  = time();

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();
    print "<p>Retrieving Phylogenetic Distribution data ...\n";

    my @workspace_ids_data;
    my $trunc = PhyloUtil::getFilePhyloGeneList( 
        $taxon_oid, $data_type, $percent_identity, $plus, 
        $domain, $phylum, '', '', '', '', '',
        $rna16s, 0, $maxGeneListResults, \@workspace_ids_data );

    if ( $trunc > 1 ) {
        $timeout_msg =
            "Process takes too long to run -- "
          . "Only partial result is displayed. (count: "
          . scalar(@workspace_ids_data) . ")";
    }

    # get cogs for genes
    my %gene_cog_h;
    my %cog_name_h;
    my %cog_func_h;
    my $cnt2 = 0;
    if ( ! $rna16s ) {
    	print "<p>Retrieving Gene COG functions ...\n";
    	for my $g2 (@workspace_ids_data) {
    	    my ( $workspace_id, @rest ) = split( /\t/, $g2 );
    	    my ($taxon4, $data_type4, $g2_id) = split(/ /, $workspace_id);
    	    my $cog_list =
        		join( ",", MetaUtil::getGeneCogId( $g2_id, $taxon_oid, $data_type4 ) );
    	    $gene_cog_h{$g2_id} = $cog_list;
    	    $cnt2++;
    	    print ".";
    	    if ( ( $cnt2 % 180 ) == 0 ) {
        		print "\n<br/>\n";
    	    }
    	}
    	if ( scalar( keys %gene_cog_h ) > 0 ) {
    	    print "<p>Retrieving COG definitions ...\n";
    	    my $dbh = dbLogin();
    	    my $sql = "select cog_id, cog_name from cog";
    	    my $cur = execSql( $dbh, $sql, $verbose );
    	    for ( ; ; ) {
        		my ( $cog_id, $cog_name ) = $cur->fetchrow();
        		last if !$cog_id;
        		$cog_name_h{$cog_id} = $cog_name;
    	    }
    	    $sql = qq{
                select cf.cog_id, cp.cog_pathway_name
                from cog_functions cf, cog_pathway cp
                where cf.functions = cp.function
            };
    	    $cur = execSql( $dbh, $sql, $verbose );
    	    for ( ; ; ) {
        		my ( $cog_id, $func_name ) = $cur->fetchrow();
        		last if !$cog_id;
        		if ( $cog_func_h{$cog_id} ) {
        		    $cog_func_h{$cog_id} .= ", " . $func_name;
        		}
        		else {
        		    $cog_func_h{$cog_id} = $func_name;
        		}
    	    }
    	    #$dbh->disconnect();
    	}
    }
    printEndWorkingDiv();

    if ( $sid == 312 ) {
        print "<p>*** end: " . currDateTime() . "\n";
    }

    if ( ! $rna16s ) {
        PhyloUtil::printProfileSelection( $section );
    }
    print "<p>\n";

    my $it = new InnerTable( 1, "MetagHits$$", "MetagHits", 1 );
    my $sd = $it->getSdDelim();                                 # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",          "char asc",   "left" );
    $it->addColSpec( "Percent Identity", "number asc", "right" );

    if ( ! $rna16s ) {
    	$it->addColSpec( "COG ID",       "char desc", "left" );
    	$it->addColSpec( "COG Name",     "char desc", "left" );
    	$it->addColSpec( "COG Function", "char desc", "left" );
    }

    $it->addColSpec( "Homolog Gene",       "number desc", "right" );
    $it->addColSpec( "Homolog Genome", "char desc",   "left" );
    $it->addColSpec( "Homolog Class",   "char asc",    "left" );
    $it->addColSpec( "Homolog Order",   "char asc",    "left" );
    $it->addColSpec( "Homolog Family",  "char asc",    "left" );
    $it->addColSpec( "Homolog Genus",      "char desc",   "left" );
    $it->addColSpec( "Homolog Species",    "char desc",   "left" );
    $it->addColSpec( "Estimated Copies", "number desc", "right" );

    my $select_id_name = "gene_oid";

    my $count = scalar(@workspace_ids_data);
    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$count gene(s) retrieved", 2 );
    }

    my $sd = $it->getSdDelim();    # sort delimiter

    for my $r (@workspace_ids_data) {

        my ( 
            $workspace_id, $perc_identity, $homolog_gene,
            $homo_taxon,  $copies, 
            $domain2, $phylum2, $ir_class2, $ir_order2, 
            $family2, $genus2, $species2, $homo_taxon_name
          )
          = split( /\t/, $r );

    	my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
        my $row          = $sd
          . "<input type='checkbox' name='$select_id_name' value='$workspace_id' checked />\t";
        my $url =
            "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
          . "&taxon_oid=$taxon_oid&data_type=$data_type4"
          . "&gene_oid=$gene_oid";

        $row .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
        $row .= $perc_identity . $sd . $perc_identity . "\t";

    	if ( ! $rna16s ) {
    	    my $cog_list = $gene_cog_h{$gene_oid};
    	    if ($cog_list) {
        		$row .= $cog_list . $sd . $cog_list . "\t";
        		my @cog_ids  = split( /\,/, $cog_list );
        		my $cog_name = "";
        		my $cog_func = "";
        		for my $cog_id (@cog_ids) {
        		    if ($cog_name) {
            			$cog_name .= ", " . $cog_name_h{$cog_id};
        		    }
        		    else {
            			$cog_name = $cog_name_h{$cog_id};
        		    }
        		    if ($cog_func) {
            			$cog_func .= ", " . $cog_func_h{$cog_id};
        		    }
        		    else {
            			$cog_func = $cog_func_h{$cog_id};
        		    }
        		}
        		if ( !$cog_func ) {
        		    $cog_func = $cog_name;
        		}
        		$row .= $cog_name . $sd . $cog_name . "\t";
        		$row .= $cog_func . $sd . $cog_func . "\t";
    	    }
    	    else {
        		$row .= "-" . $sd . "-" . "\t";
        		$row .= "-" . $sd . "-" . "\t";
        		$row .= "-" . $sd . "-" . "\t";
    	    }
    	}

        my $url2 =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$homolog_gene";
        $row .= $homolog_gene . $sd . alink( $url2, $homolog_gene ) . "\t";

        #$row .= $homo_family . $sd . $homo_family . "\t";
        my $url3 = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$homo_taxon";
        $row .= $homo_taxon_name . $sd . alink( $url3, $homo_taxon_name) . "\t";

        $row .= $ir_class2 . $sd . $ir_class2 . "\t";
        $row .= $ir_order2 . $sd . $ir_order2 . "\t";
        $row .= $family2 . $sd . $family2 . "\t";
        $row .= $genus2 . $sd . $genus2 . "\t";
        $row .= $species2 . $sd . $species2 . "\t";

        if ( !$copies ) {
            $copies = 1;
        }
        $row .= $copies . $sd . $copies . "\t";

        $it->addRow($row);
    }

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ($timeout_msg) {
        my $s = "<font color='red'>$timeout_msg</font>\n";
        printStatusLine( $s, 2 );
    }

    if ( $count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        ## save to workspace
        WorkspaceUtil::printSaveGeneToWorkspace_withAllMetaHits($select_id_name);
    }

    print end_form();

}



###############################################################################
# This is the file version
###############################################################################
sub loadFilePhylumOrgCount {
    my ( $taxon_oid, $data_type, $orgCount_ref ) = @_;

    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        my $taxonCntFile =
          $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/dpcOrgCount.txt";
        if ( !( -e $taxonCntFile ) ) {
            next;
        }
        my $fh = newReadFileHandle($taxonCntFile);
        if ( !$fh ) {
            next;
        }

        while ( my $line = $fh->getline() ) {
            chomp($line);
            my ( $name, $cnt ) = split( /\t/, $line );
            my ( $domain, $phylum, $ir_class ) = split( /\,/, $name );
            $phylum =~ s/\s+//g;
            if ( blankStr($phylum) ) {
                $phylum = 'unclassified';
            }

            #	    if ( $domain =~ /Virus/ ) {
            #		$ir_class = '';
            #	    }
            #	    else {
            $ir_class =~ s/\s+//g;

            #	    }
            my $k = "$domain\t$phylum\t$ir_class";
            $orgCount_ref->{$k} += $cnt;
        }

        close $fh;
    }
}

#############################################################################
# loadFileGenomeHitStats: This is the file version of loading
#                     genome hit stats
#############################################################################
sub loadFileGenomeHitStats {
    my ( $taxon_oid, $data_type, $stats_ref ) = @_;

    my %count;

    #    my $fname = "phyloStatsAll.txt";
    my $fname = "phyloStatsPlus.txt";

    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        my $taxonCntFile =
          $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname;
        if ( !( -e $taxonCntFile ) ) {
            next;
        }
        my $fh = newReadFileHandle($taxonCntFile);
        if ( !$fh ) {
            next;
        }

        while ( my $line = $fh->getline() ) {
            chomp($line);
            my ( $name, $cnt, $cnt2, $cnt3 ) = split( /\t/, $line );
            my ( $domain, $phylum, $ir_class ) = split( /\,/, $name );
            if ( blankStr($phylum) ) {
                $phylum = 'unclassified';
            }
            my $k = "$domain\t$phylum\t$ir_class";

            if ( $count{$k} ) {
                $count{$k} += $cnt;
            }
            else {
                $count{$k} = $cnt;
            }
        }

        close $fh;
    }    # end for my t2

    my @keys = sort ( keys %count );
    for my $k (@keys) {
        my $cnt = $count{$k};
        my ( $domain, $phylum, $ir_class ) = split( /\,/, $k );
        if ( blankStr($phylum) ) {
            $phylum = 'unclassified';
        }

        my $r = "$taxon_oid,";
        $r .= "$domain,";
        $r .= "$phylum,";
        $r .= "$ir_class,";
        $r .= "$cnt";

        $stats_ref->{$k} = $r;
    }
}

sub printTaxonomyMetagHits {
    my (
        $taxon_oid, $data_type, $domain, $phylum,
        $ir_class,  $ir_order,  $family, $genus,
        $species,   $percent,   $plus
      )
      = @_;

    $taxon_oid = param("taxon_oid")        if !$taxon_oid;
    $data_type = param("data_type")        if !$data_type;
    $percent   = param("percent")          if !$percent;
    $percent   = param("percent_identity") if !$percent;
    $percent   = param("perc")             if !$percent;
    $plus      = param("plus")             if !$plus;

    $domain    = param("domain")           if !$domain;
    $phylum    = param("phylum")           if !$phylum;
    $ir_class  = param("ir_class")         if !$ir_class;
    $ir_order  = param("ir_order")         if !$ir_order;
    $family    = param("family")           if !$family;
    $genus     = param("genus")            if !$genus;
    $species   = param("species")          if !$species;

    my $xcopy = param("xcopy");
    my $rna16s = param("rna16s");

    my $phylo_prefix = "";
    if ( $rna16s ) {
        $phylo_prefix = "16s_";
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    WebUtil::checkTaxonPerm( $dbh, $taxon_oid );
    
    $taxon_oid = sanitizeInt($taxon_oid);

    # subject genome - taxon oid
    my $genome = param("genome");

    my $dbh = dbLogin();
    PhyloUtil::printTaxonomyMetagHitTitle( $dbh, $taxon_oid, $data_type, $percent, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, $rna16s, $plus );

    print hiddenVar( "taxon_oid",        $taxon_oid );
    print hiddenVar( "data_type",        $data_type );
    print hiddenVar( "domain",           $domain );
    print hiddenVar( "phylum",           $phylum );
    print hiddenVar( "ir_class",         $ir_class );
    print hiddenVar( "ir_order",         $ir_order );
    print hiddenVar( "family",           $family );
    print hiddenVar( "genus",            $genus );
    print hiddenVar( "species",          $species );
    print hiddenVar( "percent_identity", $percent );
    print hiddenVar( "percent",          $percent );
    print hiddenVar( "plus",             1 ) if $plus;
    print hiddenVar( "xcopy",            $xcopy ) if $xcopy;
    print hiddenVar( "rna16s", $rna16s ) if ($rna16s);

    timeout( 60 * $merfs_timeout_mins );

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

    #print "<script language='JavaScript' type='text/javascript'\n";
    #print "src='$base_url/taxonDetails.js'></script>\n";

    MetagJavaScript::printMetagJS();

    # Return values to blanks for use with urls
    $family  = "" if ( $family  eq "*" );
    $genus   = "" if ( $genus   eq "*" );
    $species = "" if ( $species eq "*" );
    #print "<p>class: $ir_class, order: $ir_order, family: $family\n";

    my %cog_name_h;
    my %cog_func_h;

    if ( ! $rna16s ) {
        PhyloUtil::printProfileSelection( $section );
    }

    my $it = new InnerTable( 1, "MetagTaxnomyHits$$", "MetagTaxnomyHits", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",          "char asc",    "left" );
    $it->addColSpec( "Percent Identity", "number desc", "right" );

    if ( ! $rna16s ) {
        $it->addColSpec( "COG ID",       "char desc", "left" );
        $it->addColSpec( "COG Name",     "char desc", "left" );
        $it->addColSpec( "COG Function", "char desc", "left" );
    }

    $it->addColSpec( "Homolog Gene",    "number desc", "right" );
    $it->addColSpec( "Homolog Genome",  "char desc",   "left" );
    $it->addColSpec( "Homolog Class",   "char asc",    "left" );
    $it->addColSpec( "Homolog Order",   "char asc",    "left" );
    $it->addColSpec( "Homolog Family",  "char asc",    "left" );
    $it->addColSpec( "Homolog Genus",   "char desc",   "left" );
    $it->addColSpec( "Homolog Species", "char desc",   "left" );
    $it->addColSpec( "Estimated Copies", "number desc", "right" );

    my $select_id_name = "gene_oid";

    timeout( 60 * $merfs_timeout_mins );

    my $timeout_msg = "";
    my $start_time  = time();

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();

    # for performance let get all the cog info now
    my %cogToName;
    my %cogToPathwayName;
    my %taxonsNames;

    if ( ! $rna16s ) {
        my $sql;
        my $cur;

        print "Getting cog<br/>\n";
        $sql = qq{
            select cog_id, cog_name from cog
        };
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $cog_id, $cog_name ) = $cur->fetchrow();
            last if ( !$cog_id );
            $cogToName{$cog_id} = $cog_name;
        }
        $cur->finish();
        
        print "Getting cog pathways<br/>\n";
        $sql = qq{
            select cf.cog_id, cp.cog_pathway_name
            from cog_functions cf, cog_pathway cp
            where cf.functions = cp.function
            and cp.cog_pathway_name is not null
        };
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id, $func_name ) = $cur->fetchrow();
            last if !$id;
            if ( exists $cogToPathwayName{$id} ) {
                $cogToPathwayName{$id} = $cogToPathwayName{$id} . ", " . $func_name;
            }
            else {
                $cogToPathwayName{$id} = $func_name;
            }
        }
        $cur->finish();
    }

    print "Rerieving taxon phylogeny ...<br/>\n";
    my $taxon_href = PhyloUtil::getTaxonTaxonomy( $dbh, 
        $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species );

    my @type_list = MetaUtil::getDataTypeList( $data_type );

    $percent = sanitizeInt($percent);
    my @percent_list = ($percent);
    if ($plus) {
        if ( $percent == 30 ) {
            @percent_list = ( 30, 60, 90 );
        }
        if ( $percent == 60 ) {
            @percent_list = ( 60, 90 );
        }
    }

    $taxon_oid = sanitizeInt($taxon_oid);
    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        print "<p>Retrieving $t2 data ...\n";
        my $full_dir_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
            . "/" . $phylo_prefix . $t2 . "." . $percent . ".sdb";

        if ( -e $full_dir_name ) {
            
            # use SQLite
            my $max_count = $maxGeneListResults + 1;
            for my $p3 (@percent_list) {
                if ($trunc) {
                    last;
                }

                my $sdb_name = MetaUtil::getPhyloDistTaxonDir( $taxon_oid )
                    . "/" . $phylo_prefix . $t2 . "." . $p3 . ".sdb";
                if ( !( -e $sdb_name ) ) {
                    next;
                }

                my $dbh2 = WebUtil::sdbLogin($sdb_name)
                  or next;

                my @toid_list = keys %$taxon_href;
                my $sql = MetaUtil::getPhyloDistHomoTaxonsSql( @toid_list );
                if ($max_count) {
                    $sql .= "LIMIT $max_count ";
                }
                my $sth = $dbh2->prepare($sql);
                $sth->execute();

                my (
                    $gene_oid, $perc_identity, $homo_gene, $homo_taxon, $copies
                );
                while (
                    (
                      $gene_oid, $perc_identity, $homo_gene, $homo_taxon, $copies
                    )
                    = $sth->fetchrow_array()
                  )
                {
                    if ( !$gene_oid ) {
                        last;
                    }

                    if ( !$taxon_href->{$homo_taxon} ) {
                        # no access to genome
                        next;
                    }

                    my ( $domain2, $phylum2, $ir_class2, $ir_order2, $family2, $genus2, $species2, $homo_taxon_name ) =
                      split( /\t/, $taxon_href->{$homo_taxon} );

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    my $row          = $sd
                      . "<input type='checkbox' name='$select_id_name' value='$workspace_id' checked />\t";
                    my $url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
                      . "&taxon_oid=$taxon_oid&data_type=$t2"
                      . "&gene_oid=$gene_oid";

                    $row .=
                      $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $row .= $perc_identity . $sd . $perc_identity . "\t";

                    if ( ! $rna16s ) {
                        my @cogs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $t2 );
                        my $cog_list = join( ",", @cogs );
                        my $cog_name = "";
                        my $cog_func = "";
                        for my $cog2 (@cogs) {
                            if ( !$cog_name_h{$cog2} ) {
                                $cog_name_h{$cog2} = $cogToName{$cog2};
                            }
                            if ($cog_name) {
                                $cog_name .= "," . $cog_name_h{$cog2};
                            }
                            else {
                                $cog_name = $cog_name_h{$cog2};
                            }
        
                            if ( !$cog_func_h{$cog2} ) {
                                $cog_func_h{$cog2} =
                                    $cogToPathwayName{$cog2};
                            }
                            if ($cog_func) {
                                $cog_func .= "," . $cog_func_h{$cog2};
                            }
                            else {
                                $cog_func = $cog_func_h{$cog2};
                            }
                        }    # end for cog2
                        $row .= $cog_list . $sd . $cog_list . "\t";
                        $row .= $cog_name . $sd . $cog_name . "\t";
                        $row .= $cog_func . $sd . $cog_func . "\t";
                    }

                    my $url2 =
                        "$main_cgi?section=GeneDetail"
                      . "&page=geneDetail&gene_oid=$homo_gene";
                    $row .=
                      $homo_gene . $sd
                      . alink( $url2, $homo_gene ) . "\t";

                    my $url2 =
                        "$main_cgi?section=TaxonDetail"
                      . "&page=taxonDetail&taxon_oid=$homo_taxon";
                    $row .= $homo_taxon_name . $sd . alink( $url2, $homo_taxon_name ) . "\t";

                    $row .= $ir_class2 . $sd . $ir_class2 . "\t";
                    $row .= $ir_order2 . $sd . $ir_order2 . "\t";
                    $row .= $family2 . $sd . $family2 . "\t";
                    $row .= $genus2 . $sd . $genus2 . "\t";
                    $row .= $species2 . $sd . $species2 . "\t";

                    if ( !$copies ) {
                        $copies = 1;
                    }
                    $row .= $copies . $sd . $copies . "\t";

                    $it->addRow($row);

                    $count++;
                    if ( ( $count % 100 ) == 0 ) {
                        print "<p>$count rows retrieved ...<br/>\n";
                    }

                    if ( $max_count && $count > $max_count ) {
                        $trunc = 1;
                        last;
                    }

                    # check timeout
                    if (
                        (
                            ( $merfs_timeout_mins * 60 ) -
                            ( time() - $start_time )
                        ) < 200
                      )
                    {
                        $timeout_msg =
                            "Process takes too long to run -- "
                            . "Only partial result is displayed. (count: $count)";
                        $trunc = 2;
                        last;
                    }
                }

                $sth->finish();
                $dbh2->disconnect();
            }    # end for my p3
        }

    }    # end for t2

    printEndWorkingDiv();

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** end: " . currDateTime() . "<br/>\n";
    }

    print "<p>\n";
    if ( $count > 0 ) {
        WebUtil::printGeneCartFooter() if $count > 10;    
        $it->printOuterTable(1);    
        WebUtil::printGeneCartFooter();

        MetaGeneTable::printMetaGeneTableSelect();
        ## save to workspace
        WorkspaceUtil::printSaveGeneToWorkspace_withAllMetaHits($select_id_name);
    }

    if ($timeout_msg) {
        my $s = "<font color='red'>$timeout_msg</font>\n";
        printStatusLine( $s, 2 );
    }
    elsif ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$count gene(s) retrieved", 2 );
    }

    print end_form();
}

# Print cog function stats page
#
# param $taxon_oid taxon oid
# param $percent percent, 30, 60 or 90
#
sub printMetagenomeCogFuncStats {

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $percent  = param("perc");
    my $plus  = param("plus");
    my $rna16s  = param('rna16s');
    my $xcopy = param("xcopy");

    my $chart = param("chart");

    my $dbh = dbLogin();
    my $cogId2definition_href = QueryUtil::getCogId2Definition($dbh);
    #my $cogId2definition_href = QueryUtil::getCogId2DefinitionMapping();
    #print "printMetagenomeCogFuncStats() cogId2definition_href:<br/>\n";
    #print Dumper($cogId2definition_href);
    #print "<br/>\n";

    my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $data_type, 'COG' );
    #print "printMetagenomeCogFuncStats() func_genes:<br/>\n";
    #print Dumper(\%func_genes);
    #print "<br/>\n";

    my %genes2cogId_h;
    for my $func_id ( keys %func_genes ) {
        my @funcGenes = split( /\t/, $func_genes{$func_id} );
        for my $gene (@funcGenes) {
            my $cogIds_href = $genes2cogId_h{$gene};
            if ( $cogIds_href ) {
                $cogIds_href->{$func_id} = 1;
            }
            else {
                my %cogIds_h;
                $cogIds_h{$func_id} = 1;
                $genes2cogId_h{$gene} = \%cogIds_h;
            }
        }
    }
    #print "printMetagenomeCogFuncStats() genes2cogId_h:<br/>\n";
    #print Dumper(\%genes2cogId_h);
    #print "<br/>\n";

    my $dpc = "unassigned\tunassigned";
    my %cogFunctions;

    my %phylum2geneVal = PhyloUtil::getFilePhylumArray( $dbh, $taxon_oid, $data_type, $percent, $plus, $rna16s, $xcopy );
    for my $key ( keys %phylum2geneVal ) {
        my ( $domain, $phylum ) = split( /\t/, $key );
        
        my @workspace_ids;
        PhyloUtil::getFilePhyloGeneList( $taxon_oid, $data_type, $percent,
              $plus, $domain, $phylum, '', '', '', '', '',
              $rna16s, 1, 0, \@workspace_ids );
    
        for my $workspace_id (@workspace_ids) {
            my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
            my $cogIds_href = $genes2cogId_h{$gene_oid};
            if ( ! $cogIds_href ) {
                next;
            }

            for my $cog_id (keys %$cogIds_href ) {
                my $defs_ref = $cogId2definition_href->{$cog_id};
                for my $defn ( @$defs_ref ) {
                    if ( exists( $cogFunctions{$defn} ) ) {
                        my $href_tmp = $cogFunctions{$defn};
                        $href_tmp->{"$domain\t$phylum"} += 1;
                    } else {
                        my %tmp;
                        $tmp{"$domain\t$phylum"} = 1;
                        $cogFunctions{$defn} = \%tmp;
                    }
                }
            }    
        }    # end for $workspace_id
        
    }    

    my $totalGeneCounts_href = \%phylum2geneVal;
    my @phylum_array = keys %phylum2geneVal;

    my $plusSign;
    if ( $plus ) {
        $plusSign = '+';
    }

    my $title;
    if ($rna16s) {
        $title = '16S rRNA Gene ';
    }
    $title .= "Summary Statistics of COG Functional Categories $percent%$plusSign";    
    print "<h1>$title</h1>\n";

    if ( $chart && ( $chart eq "yes" ) ) {
        PhyloUtil::printCogStatChart( $section, $taxon_oid, $data_type, $percent, $plus, \%cogFunctions, "func" );
    } else {
        PhyloUtil::printCogFuncStatTable( $section, $taxon_oid, $data_type, \@phylum_array, \%cogFunctions, 0, $totalGeneCounts_href );
    }
}

# Print cog pathway stats page
#
# param $taxon_oid taxon oid
# param $percent percent, 30, 60 or 90
#
sub printMetagenomeCogPathStats {

    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $percent  = param("perc");
    my $plus  = param("plus");
    my $rna16s  = param('rna16s');
    my $xcopy = param("xcopy");

    my $chart = param("chart");

    my $dbh = dbLogin();
    my $cogId2pathway_href = QueryUtil::getCogId2Pathway($dbh);
    #print "printMetagenomeCogFuncStats() cogId2pathway_href:<br/>\n";
    #print Dumper($cogId2pathway_href);
    #print "<br/>\n";

    my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $data_type, 'COG' );
    #print "printMetagenomeCogFuncStats() func_genes:<br/>\n";
    #print Dumper(\%func_genes);
    #print "<br/>\n";

    my %genes2cogId_h;
    for my $func_id ( keys %func_genes ) {
        my @funcGenes = split( /\t/, $func_genes{$func_id} );
        for my $gene (@funcGenes) {
            my $cogIds_href = $genes2cogId_h{$gene};
            if ( $cogIds_href ) {
                $cogIds_href->{$func_id} = 1;
            }
            else {
                my %cogIds_h;
                $cogIds_h{$func_id} = 1;
                $genes2cogId_h{$gene} = \%cogIds_h;
            }
        }
    }
    #print "printMetagenomeCogFuncStats() genes2cogId_h:<br/>\n";
    #print Dumper(\%genes2cogId_h);
    #print "<br/>\n";

    my $dpc = "unassigned\tunassigned";
    my %cogFunctions;

    my %phylum2geneVal = PhyloUtil::getFilePhylumArray( $dbh, $taxon_oid, $data_type, $percent, $plus, $rna16s, $xcopy );
    for my $key ( keys %phylum2geneVal ) {
        my ( $domain, $phylum ) = split( /\t/, $key );
        
        my @workspace_ids;
        PhyloUtil::getFilePhyloGeneList( $taxon_oid, $data_type, $percent,
              $plus, $domain, $phylum, '', '', '', '', '',
              $rna16s, 1, 0, \@workspace_ids );
    
        for my $workspace_id (@workspace_ids) {
            my ($taxon4, $data_type4, $gene_oid) = split(/ /, $workspace_id);
            my $cogIds_href = $genes2cogId_h{$gene_oid};
            if ( ! $cogIds_href ) {
                next;
            }

            for my $cog_id (keys %$cogIds_href ) {
                my $defs_ref = $cogId2pathway_href->{$cog_id};
                for my $defn ( @$defs_ref ) {
                    if ( exists( $cogFunctions{$defn} ) ) {
                        my $href_tmp = $cogFunctions{$defn};
                        $href_tmp->{"$domain\t$phylum"} += 1;
                    } else {
                        my %tmp;
                        $tmp{"$domain\t$phylum"} = 1;
                        $cogFunctions{$defn} = \%tmp;
                    }
                }
            }    
        }    # end for $workspace_id
        
    }    

    my $totalGeneCounts_href = \%phylum2geneVal;
    my @phylum_array = keys %phylum2geneVal;

    my $plusSign;
    if ( $plus ) {
        $plusSign = '+';
    }
    my $title;
    if ($rna16s) {
        $title = '16S rRNA Gene ';
    }
    $title .= "Summary Statistics of COG Pathways $percent%$plusSign";    
    print "<h1>$title</h1>\n";

    if ( $chart && ( $chart eq "yes" ) ) {
        PhyloUtil::printCogStatChart( $section, $taxon_oid, $data_type, $percent, $plus, \%cogFunctions, "path" );
    } else {
        PhyloUtil::printCogPathStatTable( $section, $taxon_oid, $data_type, \@phylum_array, \%cogFunctions, 0 );
    }

}

######################################################################
# connect to img_mer_v330
# temporary usage
######################################################################
sub Connect_IMG_MER_v330 {

    # use the test database img_mer_v330
    my $user2    = "img_mer_v330";
    my $pw2      = "img_mer_v330123";
    my $service2 = "imgmer01";

    my $ora_host = "data.jgi-psf.org";
    my $ora_port = "1521";
    my $ora_sid  = "imgmer01";

    # my $dsn2 = "dbi:Oracle:host=$service2";
    my $dsn2 = "dbi:Oracle:host=$ora_host;port=$ora_port;sid=$ora_sid";
    my $dbh2 = DBI->connect( $dsn2, $user2, $pw2 );
    if ( !defined($dbh2) ) {
        webDie("cannot login to IMG MER V330\n");
    }
    $dbh2->{LongReadLen} = 50000;
    $dbh2->{LongTruncOk} = 1;
    return $dbh2;
}

1;
