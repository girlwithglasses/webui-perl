############################################################################
# TaxonDetail.pm - Show taxon detail page.
#  Now shows some taxon
#  information, but mainly calls the taxon statistics page.
#  Also has the link outs to groups of genes by various categories
#  from the statistics page.
#      --es 09/17/2004
#
# $Id: TaxonDetail.pm 33900 2015-08-04 23:34:19Z klchu $
############################################################################
package TaxonDetail;
my $section = "TaxonDetail";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use HtmlUtil;
use CompareGenomes;
use KeggMap;
use Metagenome;
use TermNodeMgr;
use InnerTable;
use ChartUtil;
use ImgTermNodeMgr;
use TaxonList;
use OracleUtil;
use DataEntryUtil;
use FuncUtil;
use GenerateArtemisFile;
use IMGProteins;
use RNAStudies;
use QueryUtil;
use MerFsUtil;
use TaxonDetailUtil;
use WorkspaceUtil;
use AnalysisProject;

use D3ChartUtil;

$| = 1;

my $env                               = getEnv();
my $cgi_dir                           = $env->{cgi_dir};
my $tmp_url                           = $env->{tmp_url};
my $tmp_dir                           = $env->{tmp_dir};
my $main_cgi                          = $env->{main_cgi};
my $section_cgi                       = "$main_cgi?section=$section";
my $verbose                           = $env->{verbose};
my $scaffold_page_size                = $env->{scaffold_page_size};
my $base_url                          = $env->{base_url};
my $base_dir                          = $env->{base_dir};
my $taxonomy_base_url                 = $env->{taxonomy_base_url};
my $include_metagenomes               = $env->{include_metagenomes};
my $include_img_terms                 = $env->{include_img_terms};
my $img_er                            = $env->{img_er};
my $web_data_dir                      = $env->{web_data_dir};
my $ncbi_entrez_base_url              = $env->{ncbi_entrez_base_url};
my $pubmed_base_url                   = $env->{pubmed_base_url};
my $ncbi_project_id_base_url          = $env->{ncbi_project_id_base_url};
my $img_mer_submit_url                = $env->{img_mer_submit_url};
my $img_er_submit_url                 = $env->{img_er_submit_url};
my $cmr_jcvi_ncbi_project_id_base_url = $env->{cmr_jcvi_ncbi_project_id_base_url};
my $aclame_base_url                   = $env->{aclame_base_url};
my $gcat_base_url                     = $env->{gcat_base_url};
my $greengenes_base_url               = $env->{greengenes_base_url};
my $img_internal                      = $env->{img_internal};
my $img_lite                          = $env->{img_lite};
my $user_restricted_site              = $env->{user_restricted_site};
my $no_restricted_message             = $env->{no_restricted_message};
my $cgi_tmp_dir                       = $env->{cgi_tmp_dir};
my $mgtrees_dir                       = $env->{mgtrees_dir};
my $show_mgdist_v2                    = $env->{show_mgdist_v2};
my $show_private                      = $env->{show_private};
my $img_geba                          = $env->{img_geba};
my $img_edu                           = $env->{img_edu};
my $use_img_gold                      = $env->{use_img_gold};
my $img_pheno_rule                    = $env->{img_pheno_rule};
my $img_pheno_rule_saved              = $env->{img_pheno_rule_saved};
my $snp_enabled                       = $env->{snp_enabled};
my $kegg_cat_file                     = $env->{kegg_cat_file};
my $include_taxon_phyloProfiler       = $env->{include_taxon_phyloProfiler};
my $include_ht_stats                  = $env->{include_ht_stats};
my $YUI                               = $env->{yui_dir_28};
my $include_kog                       = $env->{include_kog};
my $scaffold_cart                     = $env->{scaffold_cart};
my $in_file                           = $env->{in_file};
my $in_file                           = $env->{in_file};
my $img_edu                           = $env->{img_edu};
my $enable_genbank                    = 1;

# Inner table sort delimiter
my $sortDelim = InnerTable::getSdDelim();
my $nvl       = getNvl();

my $content_list = $env->{content_list};

my $maxOrthologGroups  = 10;
my $maxParalogGroups   = 100;
my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $pageSize           = $scaffold_page_size;
my $max_gene_batch     = 900;
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $taxon_stats_dir          = $env->{taxon_stats_dir};
my $taxon_faa_dir            = $env->{taxon_faa_dir};
my $taxon_alt_faa_dir        = $env->{taxon_alt_faa_dir};
my $taxon_fna_dir            = $env->{taxon_fna_dir};
my $taxon_reads_fna_dir      = $env->{taxon_reads_fna_dir};
my $taxon_genes_fna_dir      = $env->{taxon_genes_fna_dir};
my $taxon_intergenic_fna_dir = $env->{taxon_intergenic_fna_dir};
my $genes_dir                = $env->{genes_dir};
my $all_fna_files_dir        = $env->{all_fna_files_dir};
my $avagz_batch_dir          = $env->{avagz_batch_dir};

my $enable_ani    = $env->{enable_ani};

# Alex Chang - stuff
my $max_scaffold_list = 10000;

# Initial list.
my $max_scaffold_list2 = 10000;

# For 2nd order list.
my $max_scaffold_results = 20000;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $sid  = getContactOid();
    my $page = param("page");

    #print "dispatch page: $page, paramMatch: " . paramMatch("pfamGeneList"). "<br/>\n";

    if ( paramMatch("downloadTaxonFnaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonFnaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonReadsFnaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonReadsFnaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonGenesFnaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonGenesFnaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonIntergenicFnaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonIntergenicFnaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("viewArtemisFile") ne "" ) {
        my $st = downloadArtemisFile(0);
        if ( !$st ) {
            webError("Session for viewing expired.  Please try again.");
        }
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadArtemisFile") ne "" ) {
        my $st = downloadArtemisFile(1);
        if ( !$st ) {
            webError("Session for download expired.  Please try again.");
        }
    } elsif ( paramMatch("downloadTaxonFaaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonFaaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonAltFaaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonAltFaaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonAnnotFile") ne "" ) {

        checkAccess();
        downloadTaxonAnnotFile();
        WebUtil::webExit(0);

    } elsif ( $img_edu && paramMatch("downloadTaxonGenesFile") ne "" ) {

        checkAccess();
        downloadTaxonGenesFile();
        WebUtil::webExit(0);

    } elsif ( paramMatch("downloadTaxonInfoFile") ne "" ) {

      # from gneome detail page
      # eg
      # https://img-stage.jgi-psf.org/cgi-bin/er/main.cgi?section=GeneInfoPager&page=viewGeneInformation&taxon_oid=2547132422
        checkAccess();
        downloadTaxonInfoFile();
        WebUtil::webExit(0);
    } elsif ( $page eq "taxonDetail" ) {

        HtmlUtil::cgiCacheInitialize($section);

        # cgi cache
        HtmlUtil::cgiCacheStart() or return;

        if ($use_img_gold) {
            printTaxonDetail_ImgGold();
        } else {                 # always use GOLD metadata +BSJ 09/18/12
            printTaxonDetail_ImgGold();
        }

        HtmlUtil::cgiCacheStop();

    } elsif ( paramMatch("searchScaffolds") ne ""
        || defined( param("scaffoldSearchTerm") ) )
    {
        printScaffoldSearchResults();
    } elsif ( $page eq "scaffolds" || paramMatch("scaffolds") ne "" ) {
        printScaffolds();
    } elsif ( $page eq "taxonArtemisForm" ) {
        printArtemisForm();
    } elsif ( paramMatch("processArtemisFile") ne "" ) {
        GenerateArtemisFile::processArtemisFile();
    } elsif ( $page eq "deletedGeneList" ) {
        printDeletedGeneList();
    } elsif ( $page eq "obsoleteGenes" ) {
        printObsoleteGenes();
    } elsif ( $page eq "genomeProteomics" ) {
        printGenomeProteomics();
    } elsif ( $page eq "genomeRNASeq" ) {
        printGenomeRNASeq();
    } elsif ( $page eq "snpGenes" ) {
        printSnpGenes();
    } elsif ( $page eq "revisedGenes" ) {
        printImgOrfTypes();
    } elsif ( $page eq "imgOrfTypeGenes" ) {
        printImgOrfTypeGenes();
    } elsif ( $page eq "scaffoldsByGeneCount" ) {
        printScaffoldsByGeneCount();
    } elsif ( $page eq "scaffoldsByLengthCount" ) {
        printScaffoldsByLengthCount();
    } elsif ( $page eq "dbScaffoldGenes"
        || paramMatch("dbScaffoldGenes") ne "" ) {
        printDbScaffoldGenes();
    } elsif ( $page eq "orthologGroups" ) {
        printOrthologClusters();
    } elsif ( $page eq "imgClusters" ) {
        printImgClusters();
    } elsif ( $page eq "orthologClusterGeneList" ) {
        printOrthologClusterGeneList();
    } elsif ( $page eq "imgClusterGeneList" ) {
        printImgClusterGeneList();

        #    } elsif ( $page eq "homologClusterGeneList" ) {
        #        printHomologClusterGeneList();
    } elsif ( $page eq "superClusterGeneList" ) {
        printSuperClusterGeneList();

        #    } elsif ( $page eq "mclClusters" ) {
        #        printMclClusters();
        #    } elsif ( $page eq "mclClusterGeneList" ) {
        #        printMclClusterGeneList();
    } elsif ( $page eq "paralogGroups" ) {
        printParalogClusters();
    } elsif ( $page eq "paralogClusterGeneList" ) {
        printParalogClusterGeneList();
    } elsif ( $page eq "uniqueGenes" ) {
        printUniqueGenes();
    } elsif ( $page eq "rnas" ) {
        printRnas();
    } elsif ( $page eq "cogs"
        || paramMatch("cogs") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printCogCategories();
        } else {
            printTaxonCKog();
        }
    } elsif ( $page eq "kogs"
        || paramMatch("kogs") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printCogCategories("kog");
        } else {
            printTaxonCKog("kog");
        }
    } elsif ( $page eq "catecogList" ) {
        printCateCogList();
    } elsif ( $page eq "cogGeneList"
        || paramMatch("cogGeneList") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printCKogCatGeneList();
        } else {
            printCKogGeneList();
        }
    } elsif ( $page eq "catekogList" ) {
        printCateCogList(1);
    } elsif ( $page eq "kogGeneList"
        || paramMatch("kogGeneList") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printCKogCatGeneList("kog");
        } else {
            printCKogGeneList("kog");
        }
    } elsif ( $page eq "enzymeGeneList"
        || paramMatch("enzymeGeneList") ne "" )
    {
        printEnzymeGeneList();
    } elsif ( $page eq "enzymes" ) {
        printTaxonEnzymes();
    } elsif ( $page eq "imgTermGeneList"
        || paramMatch("imgTermGeneList") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printImgTermCatGeneList();
        } else {
            printImgTermGeneList();
        }
    } elsif ( $page eq "imgTerms" ) {
        my $cat  = param("cat");
        my $tree = param("tree");
        if ( $cat ) {
            printImgTermsCat();
        } elsif ( $tree ) {
            printImgTermsTree();
        } else {
            printImgTerms();
        }
    } elsif ( $page eq "imgPwayGeneList"
        || paramMatch("imgPwayGeneList") ne "" )
    {
        printImgPwayGeneList();
    } elsif ( $page eq "imgPways" ) {
        printImgPways();
    } elsif ( $page eq "imgPlistGenes"
        || paramMatch("imgPlistGenes") ne "" )
    {
        printImgPlistGenes();
    } elsif ( $page eq "imgPlist" ) {
        printImgPlist();
    } elsif ( $page eq "catePfamList" ) {
        printCatePfamList();
    } elsif ( $page eq "pfamGeneList"
        || paramMatch("pfamGeneList") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printPfamCatGeneList();
        } else {
            printPfamGeneList();
        }
    } elsif ( $page eq "pfam"
        || paramMatch("pfam") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printTaxonPfamCat();
        } else {
            printTaxonPfam();
        }
    } elsif ( $page eq "cateTigrfamList" ) {
        printCateTIGRfamList();
    } elsif ( $page eq "tigrfamGeneList"
        || paramMatch("tigrfamGeneList") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printTIGRfamCatGeneList();
        } else {
            printTIGRfamGeneList();
        }
    } elsif ( $page eq "tigrfam"
        || paramMatch("tigrfam") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printTaxonTIGRfamCat();
        } else {
            printTaxonTIGRfam();
        }
    }

    # --es 10/18/2007
    elsif ( $page eq "genomeProp" ) {
        printTaxonGenomeProp();
    }

    # --es 10/18/2007
    elsif ( $page eq "genomePropGeneList" ) {
        printGenomePropGeneList();
    } elsif ( $page eq "signalpGeneList" ) {
        printSignalpGeneList();
    } elsif ( $page eq "transmembraneGeneList" ) {
        printTransmembraneGeneList();
    } elsif ( $page eq "iprGeneList"
        || paramMatch("iprGeneList") ne "" )
    {
        printInterProGeneList();
    } elsif ( $page eq "ipr" ) {
        printInterPro();
    } elsif ( $page eq "kegg"
        || paramMatch("kegg") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ) {
            printKeggCategories();
        } else {
            printKegg();
        }
    } elsif ( $page eq "noKegg" ) {
        printNoKegg();
    } elsif ( $page eq "metaCycGenes"
        || paramMatch("metaCycGenes") ne "" )
    {
        printMetacycGenes();
    } elsif ( $page eq "metacyc" ) {
        printMetacyc();
    } elsif ( $page eq "noMetacyc" ) {
        printNoMetacyc();
    } elsif ( $page eq "swissprot" ) {
        printSwissProt();
    } elsif ( $page eq "noswissprot" ) {
        printNoSwissProt();
    } elsif ( $page eq "seed" ) {
        printSeed();
    } elsif ( $page eq "noseed" ) {
        printNoSeed();
    } elsif ( $page eq "tcGenes"
        || paramMatch("tcGenes") ne "" )
    {
        printTcGenes();
    } elsif ( $page eq "tc" ) {
        printTc();
    } elsif ( $page eq "koGenes"
        || paramMatch("koGenes") ne "" )
    {
        printKoGenes();
    } elsif ( $page eq "ko" ) {
        printKo();
    } elsif ( $page eq "noKo" ) {
        printNoKo();
    } elsif ( $page eq "proteinCodingGenes" ) {
        printProteinCodingGenes();
    } elsif ( $page eq "withFunc" ) {
        printGenesWithFunc();
    } elsif ( $page eq "withoutFunc" ) {
        printGenesWithoutFunc();

        #    } elsif ( $page eq "noFuncHomo" ) {
        #        printNoFuncHomo();
        #    } elsif ( $page eq "noFuncNoHomo" ) {
        #        printNoFuncNoHomo();
    } elsif ( $page eq "pseudoGenes" ) {
        printPseudoGenes();
    } elsif ( $page eq "uncharGenes" ) {
        printUncharGenes();
    } elsif ( $page eq "dubiousGenes" ) {
        printDubiousGenes();
    } elsif ( $page eq "keggCategoryGenes" ) {
        printKeggCategoryGenes();
    } elsif ( $page eq "keggPathwayGenes" ) {
        printKeggPathwayGenes();
    } elsif ( $page eq "myIMGGenes" ) {
        printMyIMGGenes();
    } elsif ( $page eq "fusedGenes" ) {
        printFusedGenes();
    } elsif ( $page eq "fusionComponents" ) {
        printFusionComponents();
    } elsif ( $page eq "geneCassette" ) {
        printCassetteGenes();
    } elsif ( $page eq "horTransferred" ) {
#        if ( $user_restricted_site && HtmlUtil::isCgiCacheEnable() ) {
#            my $dbh       = dbLogin();
#            my $taxon_oid = param("taxon_oid");
#            my $x         = WebUtil::isTaxonPublic( $dbh, $taxon_oid );
#
#            #$dbh->disconnect();
#            $sid = 0 if ($x);    # public cache
#        }
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;

        printHorTransferred();

        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "horTransferredLevel" ) {
        printHorTransferredLevel();
    } elsif ( $page eq "horTransferredLevelVal" ) {
        printHorTransferredLevelVal();
    } elsif ( $page eq "imgTermsSimilarity"
        && $img_er
        && $img_lite
        && $img_internal
        && !$include_metagenomes )
    {
        printImgTermsSimilarity();
    } elsif ( $page eq "crisprdetails" ) {
        printCrisprDetails();
    } elsif ( $page eq "plasmiddetails" ) {
        printPlasmidDetails();
    } elsif ( $page eq "plasmidgenelist" ) {
        printPlasmidGeneList();
    } elsif ( $page eq "taxonPhenoRuleDetail" ) {
        printTaxonPhenoRuleDetail();
    } elsif ( $page eq "addGeneCart"
        || paramMatch("addGeneCart") ne "" )
    {
        require CartUtil;
        CartUtil::addFuncGenesToGeneCart();
    } else {
#        if ( $user_restricted_site && HtmlUtil::isCgiCacheEnable() ) {
#            my $dbh       = dbLogin();
#            my $taxon_oid = param("taxon_oid");
#            my $x         = WebUtil::isTaxonPublic( $dbh, $taxon_oid );
#
#            #$dbh->disconnect();
#            $sid = 0 if ($x);    # public cache
#        }

        HtmlUtil::cgiCacheInitialize($section);

        # cgi cache
        HtmlUtil::cgiCacheStart() or return;

        if ($use_img_gold) {
            printTaxonDetail_ImgGold();
        } else {                 # always use GOLD metadata +BSJ 09/18/12
            printTaxonDetail_ImgGold();
        }
        HtmlUtil::cgiCacheStop();
    }
}

#
# plasmid list
#
sub printPlasmidDetails {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName( $dbh, $taxon_oid );

    print "<h1>Plasmid Gene Counts</h1>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
    	select s.scaffold_oid, s.scaffold_name, count(distinct g.gene_oid)
    	from gene g, scaffold s
    	where g.scaffold = s.scaffold_oid
    	and s.mol_type = 'plasmid'
    	and g.taxon = s.taxon
    	and g.obsolete_flag = 'No'
    	and s.taxon  = ?
        $rclause
        $imgClause
    	group by s.scaffold_oid, s.scaffold_name
    };

    my $cur   = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    my $it    = new InnerTable( 1, "Plasmid$$", "Plasmid", 0 );
    my $sd    = $it->getSdDelim();                                # sort delimiter
    $it->addColSpec( "Scaffold Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",    "number desc", "right" );
    my $url = $section_cgi . "&page=plasmidgenelist&taxon_oid=$taxon_oid&scaffold_oid=";

    for ( ; ; ) {
        my ( $scaffold_oid, $name, $gcnt ) = $cur->fetchrow();
        last if !$scaffold_oid;
        my $tmp = alink( $url . $scaffold_oid, $gcnt );
        my $r;
        $r .= $name . $sd . $name . "\t";
        $r .= $gcnt . $sd . $tmp . "\t";
        $it->addRow($r);
        $count++;
    }
    $cur->finish();
    $it->printOuterTable(1);

    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

#
# plasmid list
#
sub printPlasmidGeneList {
    my $taxon_oid    = param("taxon_oid");
    my $scaffold_oid = param("scaffold_oid");

    my $dbh = dbLogin();
    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName( $dbh, $taxon_oid );

    #$dbh->disconnect();

    print "<h1>Plasmid Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
    	select g.gene_oid
    	from gene g, scaffold s
    	where g.scaffold = s.scaffold_oid
    	and s.mol_type = 'plasmid'
    	and g.taxon = s.taxon
    	and g.taxon = $taxon_oid
    	and s.scaffold_oid = $scaffold_oid
    	and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    my $extrasql = qq{
    	select g.gene_oid, scaffold_name
    	from gene g, scaffold s
    	where g.scaffold = s.scaffold_oid
    	and s.mol_type = 'plasmid'
    	and g.taxon = s.taxon
    	and g.taxon = $taxon_oid
    	and s.scaffold_oid = $scaffold_oid
    	and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    TaxonDetailUtil::printGeneListSectionSorting2( '', $sql, "", 1, "Scaffold Name", $extrasql );

}

#
#  genomes Crispr list
#
sub printCrisprDetails {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print qq{
      <h1>
      Genome CRISPR list
      </h1>
    };
    my $dbh        = dbLogin();
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    my $sql       = qq{
    	select s.scaffold_oid, s.scaffold_name ,sr.start_coord, sr.end_coord
    	from scaffold_repeats sr, scaffold_stats ss, scaffold s
    	where sr.scaffold_oid = ss.scaffold_oid
    	and ss.taxon = ?
    	and sr.type = 'CRISPR'
    	and s.scaffold_oid = sr.scaffold_oid
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable( 1, "Crispr$$", "Crispr", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Scaffold Name", "asc", "left" );
    $it->addColSpec( "Start Coord",   "asc", "right" );
    $it->addColSpec( "End Coord",     "asc", "right" );

    my $select_id_name = "scaffold_oid";

    my $count = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $name, $start, $end ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;

        # find a nice starting point - ken
        my $tmp = $start - 25000;
        $tmp = 1 if ( $tmp < 1 );

        my $tmp_end = $end + 25000;

        my $url = $main_cgi
          . "?section=ScaffoldGraph&page=scaffoldGraph"
          . "&scaffold_oid=$scaffold_oid"
          . "&start_coord=$tmp"
          . "&end_coord=$tmp_end";
        $url = alink( $url, $name );

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$scaffold_oid' />\t";

        $r .= $name . $sd . $url . "\t";
        $r .= $start . $sd . $start . "\t";
        $r .= $end . $sd . $end . "\t";
        $it->addRow($r);
    }
    $cur->finish();

    WebUtil::printScaffoldCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printScaffoldCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}

############################################################################
# printPhenotypeInfo - Show phenotype info based on pathway
#                      assertion
############################################################################
sub printPhenotypeInfo {
    my ($taxon_oid) = @_;

    print "<tr class='highlight'>\n";
    print "<th class='subhead'>" . "Phenotypes/Metabolism from Pathway Assertion" . "</th> <th class='subhead'> &nbsp; </th> \n";

    my $dbh = dbLogin();
    my $sql;
    my $cur;
    my $cnt = 0;

    if ($img_pheno_rule_saved) {

        # use saved result
        my $rclause   = WebUtil::urClause('rt.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('rt.taxon');
        $sql = qq{
    	    select distinct r.rule_id, r.cv_type, r.cv_value, r.name,
    	    c.username, to_char(rt.mod_date, 'yyyy-mm-dd')
    		from phenotype_rule r, phenotype_rule_taxons rt, contact c
    		where rt.taxon = ?
    		and rt.rule_id = r.rule_id
    		and rt.modified_by = c.contact_oid (+)
            $rclause
            $imgClause
    		order by 1
	    };
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

        for ( ; ; ) {
            my ( $rule_id, $cv_type, $cv_value, $name, $c_name, $mod_date ) = $cur->fetchrow();
            last if !$rule_id;

            $cnt++;
            if ( $cnt > 10000 ) {
                last;
            }

            my $rule_disp_label = DataEntryUtil::getGoldAttrDisplayName($cv_type);
            my $str             = $cv_value;
            if ( !blankStr($name) ) {
                $str .= " (" . $name . ")";
            }

            #	    $str .= " ($c_name; $mod_date)";

            my $url =
              "$main_cgi?section=TaxonDetail" . "&page=taxonPhenoRuleDetail" . "&taxon_oid=$taxon_oid&rule_id=$rule_id";
            printAttrRowRaw( $rule_disp_label, alink( $url, $str ) . " ($c_name; $mod_date)" );
        }
        $cur->finish();
    } else {
        $sql = qq{
	    select rule_id, cv_type, cv_value, name
		from phenotype_rule
		order by 1
	    };
        $cur = execSql( $dbh, $sql, $verbose );

        for ( ; ; ) {
            my ( $rule_id, $cv_type, $cv_value, $name ) = $cur->fetchrow();
            last if !$rule_id;

            $cnt++;
            if ( $cnt > 10000 ) {
                last;
            }

            if ( evalPhenotypeRule( $taxon_oid, $rule_id ) ) {
                my $rule_disp_label = DataEntryUtil::getGoldAttrDisplayName($cv_type);
                my $str             = $cv_value;
                if ( !blankStr($name) ) {
                    $str .= " (" . $name . ")";
                }

                my $url =
                  "$main_cgi?section=TaxonDetail" . "&page=taxonPhenoRuleDetail" . "&taxon_oid=$taxon_oid&rule_id=$rule_id";
                printAttrRowRaw( $rule_disp_label, alink( $url, $str ) );
            }
        }
        $cur->finish();
    }

    #$dbh->disconnect();

    print "</tr>\n";
}

############################################################################
# printTaxonPhenoRuleDetail - Show phenotype rule detail for a taxon
#
# true: 1
# false: 0
# unknown: -1
############################################################################
sub printTaxonPhenoRuleDetail {
    my $taxon_oid = param('taxon_oid');
    my $rule_id   = param('rule_id');

    # ??????
    printMainForm();
    print "<h1>Genome Phenotype Rule Inference Detail</h1>\n";
    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    print "<h2>Genome $taxon_name</h2>\n";

    my $sql = qq{
	select cv_type, cv_value, name, rule_type, rule
	    from phenotype_rule
	    where rule_id = ?
	};
    my $cur = execSql( $dbh, $sql, $verbose, $rule_id );
    my ( $cv_type, $cv_value, $name, $rule_type, $rule ) = $cur->fetchrow();
    $cur->finish();
    print "<h3>Rule " . FuncUtil::oidPadded( 'PHENOTYPE_RULE', $rule_id ) . ": " . escapeHTML($name) . "</h3>\n";

    if ( blankStr($rule) ) {

        #$dbh->disconnect();
        return;
    }

    #    print "<p>Under Implementation\n";

    my $conn1  = "AND";
    my $conn2  = "or";
    my $r_type = 0;

    if ( $rule_type =~ /OR/ ) {
        $conn1  = "OR";
        $conn2  = "and";
        $r_type = 1;
    }

    print "<table class='img'>\n";
    print "<th class='subhead'>" . $conn1 . "</th>\n";
    print "<th class='subhead'>" . "Pathways" . "</th>\n";
    print "<th class='subhead'>" . "Asserted?" . "</th>\n";
    print "<th class='subhead'>" . "True/False" . "</th>\n";
    print "</tr>\n";

    my @rules = split( /\,/, $rule );
    if ($r_type) {
        @rules = split( /\|/, $rule );
    }

    my $res = 1;
    if ( scalar(@rules) == 0 ) {
        $res = 0;
    }

    if ($r_type) {

        # set result to false for OR-rule
        $res = 0;
    }

    my $rclause   = WebUtil::urClause('p.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('p.taxon');

    my $i = 0;
    for my $r2 (@rules) {
        my $r_res = 0;
        if ($r_type) {

            # OR rule
            $r_res = 1;
        }

        if ( blankStr($r2) ) {
            next;
        }

        $r2 =~ s/\(//;
        $r2 =~ s/\)//;
        my @components = split( /\|/, $r2 );
        if ($r_type) {
            @components = split( /\,/, $r2 );
        }

        my $c_res = 0;
        my $first = 1;
        for my $c2 (@components) {
            if ( $i % 2 ) {
                print "<tr class='img' bgcolor='lightblue'>\n";
            } else {
                print "<tr class='img'>\n";
            }

            if ($first) {
                print "<td class='img'>$conn1</td>\n";
            } else {
                print "<td></td>\n";
            }

            my $not_flag    = 0;
            my $pathway_oid = 0;
            if ( $c2 =~ /\!(\d+)/ ) {
                $pathway_oid = $1;
                $not_flag    = 1;
            } elsif ( $c2 =~ /(\d+)/ ) {
                $pathway_oid = $1;
            }

            if ( !WebUtil::isInt($pathway_oid) ) {
                next;
            }

            # check pathway certification
            $sql = qq{
                select p.status
                from img_pathway_assertions p
                where p.pathway_oid = ?
                and p.taxon = ?
                $rclause
                $imgClause
                order by p.mod_date desc
            };
            $cur = execSql( $dbh, $sql, $verbose, $pathway_oid, $taxon_oid );
            my ($st) = $cur->fetchrow();
            if ( blankStr($st) ) {
                $st = "unknown";
            }

            $cur->finish();
            if (   $st eq 'asserted'
                || $st eq 'MANDATORY'
                || $st =~ /FULL/ )
            {
                $c_res = 1;
            } elsif ( $st eq 'not asserted' ) {
                $c_res = 0;
            } else {
                $c_res = -1;
            }

            if ($not_flag) {

                # switch true and false
                if ( $c_res == 1 ) {
                    $c_res = 0;
                } elsif ( $c_res == 0 ) {
                    $c_res = 1;
                }
            }

            if ($r_type) {

                # OR rule with and-component
                if ( $c_res == 0 ) {
                    $r_res = 0;
                } elsif ( $c_res == -1 ) {
                    $r_res = -1;
                }

                if ( $r_res != 0 ) {
                    if ( $c_res == -1 ) {
                        $r_res = -1;
                    }
                }
            } else {

                # AND rule with or-component
                if ( $c_res == 1 ) {
                    $r_res = 1;
                }

                if ( $r_res != 1 ) {
                    if ( $c_res == -1 ) {
                        $r_res = -1;
                    }
                }
            }

            # pathway info
            my $pathway_name = db_findVal( $dbh, 'img_pathway', 'pathway_oid', $pathway_oid, 'pathway_name', '' );
            my $pway_oid     = FuncUtil::pwayOidPadded($pathway_oid);
            my $pway_url     = "$main_cgi?section=ImgPwayBrowser" . "&page=imgPwayDetail";
            $pway_url .= "&pway_oid=$pway_oid";
            print "<td class='img'>";
            if ( !$first ) {
                print " " . $conn2 . " ";
            }
            if ($not_flag) {
                print " NOT ";
            }
            print alink( $pway_url, $pway_oid ) . ": " . escapeHTML($pathway_name) . "</td>\n";

            # assertion
            my $assert_url =
              "$main_cgi?section=ImgPwayBrowser" . "&page=pwayTaxonDetail" . "&pway_oid=$pathway_oid&taxon_oid=$taxon_oid";
            print "<td class='img'>" . alink( $assert_url, $st ) . "</td>\n";

            if ( $c_res == 1 ) {
                print "<td class='img'>True</td>\n";
            } elsif ( $c_res == 0 ) {
                print "<td class='img'>False</td>\n";
            } else {
                print "<td class='img'>Unknown</td>\n";
            }

            print "</tr>\n";

            $first = 0;
        }    # end for c2

        if ($r_type) {

            # OR rule
            if ( $r_res == 1 ) {
                $res = 1;
            }

            if ( $res != 1 ) {
                if ( $r_res == -1 ) {
                    $res = -1;
                }
            }
        } else {

            # AND rule
            if ( $r_res == 0 ) {
                $res = 0;
            }

            if ( $res != 0 ) {
                if ( $r_res == -1 ) {
                    $res = -1;
                }
            }
        }

        $i++;
    }    # end for r2
    print "</table>\n";

    if ( $res == 1 ) {
        print "<p>Evaluation Result: True\n";
    } elsif ( $res == 0 ) {
        print "<p>Evaluation Result: False\n";
    } else {
        print "<p>Evaluation Result: Unknown\n";
    }

    # check stored-result
    $sql = qq{
	select p.rule_id, p.taxon, c.username, p.mod_date
	    from phenotype_rule_taxons p, contact c
	    where p.rule_id = ?
	    and p.taxon = ?
	    and p.modified_by = c.contact_oid
        $rclause
        $imgClause
	};
    $cur = execSql( $dbh, $sql, $verbose, $rule_id, $taxon_oid );
    my ( $r2, $t2, $m2, $d2 ) = $cur->fetchrow();
    $cur->finish();
    if ( $r2 && $t2 && $m2 ) {
        print "<p>Genome was predicted to have this phenotype by " . escHtml($m2);
        if ($d2) {
            print " ($d2)";
        }
        print ".\n";
    } else {
        print "<p>Genome was not predicted to have this phenotype based on previously stored result.\n";
    }

    #$dbh->disconnect();
    print end_form();
}

sub printNCBIProjectId {
    my ( $title, $ncbi_pid ) = @_;

    my $url  = "$ncbi_project_id_base_url$ncbi_pid";
    my $link = nbsp(1);
    $link = alink( $url, $ncbi_pid ) if $ncbi_pid ne "";
    my $link2 = "";
    if ( $ncbi_pid ne "" ) {
        $link2 = urlGet("$cmr_jcvi_ncbi_project_id_base_url$ncbi_pid");
        $link2 = alink( $link2, "JCVI CMR" ) if $link2 ne "";
    }
    printAttrRowRaw( $title, "$link &nbsp;&nbsp; $link2 " )
      if $ncbi_pid > 0;

}

############################################################################
# printTaxonDetail_ImgGold - Show the detail page.
############################################################################
sub printTaxonDetail_ImgGold {
    my $taxon_oid      = param("taxon_oid");
    my $taxon_oid_orig = $taxon_oid;
    if ( $taxon_oid eq "" ) {
        webDie("taxon_oid not set");
    }
    my $dbh = dbLogin();

    if ($in_file) {
        if ( MerFsUtil::isTaxonInFile( $dbh, $taxon_oid ) ) {

            #$dbh->disconnect();
            require MetaDetail;
            MetaDetail::printTaxonDetail_ImgGold();
            return;
        }
    }

    printStatusLine( "Loading ...", 1 );

    ## See if there's any mapping from old taxon_oids to new ones.
    my $sql            = WebUtil::getTaxonReplacementSql();
    my $cur            = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $alt_taxon_oid  = $cur->fetchrow();
    my $next_taxon_oid = $cur->fetchrow() if $alt_taxon_oid;
    if ( $next_taxon_oid ne "" && $verbose >= 1 ) {
        webLog "printTaxonDetail: two taxon_oid's found for\n";
        webLog "  in alt_identifiers query: " . "$alt_taxon_oid, $next_taxon_oid\n";
        webLog "  for original query taxon_oid=$taxon_oid\n";
    }
    $cur->finish();
    $taxon_oid = $alt_taxon_oid if $alt_taxon_oid;

    checkTaxonPerm( $dbh, $taxon_oid );

    # this check is not needed - Ken 2010-05-08
    #    if ( !checkTaxonAvail( $dbh, $taxon_oid ) ) {
    #        printMessage("Genome is currently not available. ");
    #        #$dbh->disconnect();
    #        return;
    #    }

    ## Now retrieve body of data for the real taxon_oid.
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select distinct tx.taxon_oid,
         tx.ncbi_taxon_id, tx.host_ncbi_taxon_id,
         tx.taxon_display_name,
         tx.is_public, tx.funding_agency, tx.seq_status, tx.seq_center,
         tx.comments, tx.genome_type,
         tx.domain, tx.phylum, tx.ir_class, tx.ir_order,
         tx.family, tx.genus, tx.species, tx.strain, tx.jgi_species_code,
         tx.img_version,  tx.is_pangenome, tx.jgi_project_id,
         tx.refseq_project_id, tx.gbk_project_id, tx.gold_id, tx.env_sample,
         tx.is_big_euk, tx.is_proxygene_set,
         to_char(tx.release_date, 'yyyy-mm-dd'),
         to_char(tx.add_date, 'yyyy-mm-dd'),
         to_char(tx.mod_date, 'yyyy-mm-dd'), tx.obsolete_flag,
    	 tx.submission_id, tx.img_product_flag, tx.proposal_name,
    	 tx.sample_gold_id, tx.in_file, to_char(tx.distmatrix_date, 'yyyy-mm-dd'),
    	 tx.high_quality_flag, tx.analysis_project_id, tx.study_gold_id, tx.sequencing_gold_id,
    	 tx.genome_completion
        from taxon tx
        where tx.taxon_oid = ?
        $rclause
        $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my (
        $taxon_oid0,     $ncbi_taxon_id,  $host_ncbi_taxon_id, $taxon_display_name, $is_public,
        $funding_agency, $seq_status,     $seq_center,         $comments,           $genome_type,
        $domain,         $phylum,         $ir_class,           $ir_order,           $family,
        $genus,          $species,        $strain,             $jgi_species_code,   $img_version,
        $is_pangenome,   $jgi_project_id, $refseq_project_id,  $gbk_project_id,     $gold_id,
        $env_sample,     $is_big_euk,     $is_proxygene_set,   $release_date,       $add_date,
        $mod_date,       $obsolete_flag,  $submission_id,      $img_product_flag,   $proposal_name,
        $sample_gold_id, $in_file, $distmatrix_date, $high_quality_flag, $analysis_project_id,
        $study_gold_id, $sequencing_gold_id, $genome_completion
      )
      = $cur->fetchrow();
    $cur->finish();

    if ( $taxon_oid0 eq "" ) {
        printStatusLine( "Error.", 2 );

        #$dbh->disconnect();
        webError("Taxon object identifier $taxon_oid not found\n");
    }

    printMainForm();

    # html bookmark
    print "<h1>\n$taxon_display_name\n</h1>\n";

    my ( $jgi_portal_url_str, $jgi_portal_url, $strrow ) = printTaxonExtLinks( $dbh, $taxon_oid );

    print hiddenVar( "taxon_filter_oid", $taxon_oid );
    print qq{
          <input type="submit" class="smdefbutton" style="vertical-align:top;margin-top:0;padding-top:8px;
           padding-bottom:6px;" value="Add to Genome Cart" name="setTaxonFilter">
    };
    print nbsp(4);

    # Taxon Detail buttons
    print qq{
        <a class="genome-btn browse-btn" href="#browse" title="Browse Genome">
            <span>Browse Genome</span>
        </a>
    };
    print nbsp(4);
    print qq{
        <a class="genome-btn blast-btn" href="$main_cgi?section=FindGenesBlast&page=geneSearchBlast&taxon_oid=$taxon_oid&domain=$domain"
        title="BLAST Genome"><span>BLAST Genome</span></a>
    };
    print nbsp(4);
    if ( $jgi_portal_url ne "" ) {
        print qq{
        <a class="genome-btn download-btn" href="$jgi_portal_url"
        onClick="_gaq.push(['_trackEvent', 'Download Data', 'JGI Portal', '$taxon_oid']);"
        title="Download Data"><span>Download Data</span></a>
    };
    }

    my $nbsp4 = "&nbsp;" x 4;

    my $exportGenomeDataStr = qq{
	<br>
	$nbsp4<a href="#export">Export Genome Data</a>
    };
    if ( !hasNucleotideData( $dbh, $taxon_oid ) ) {
        $exportGenomeDataStr = "";
    }

    my $ht;
    $ht = qq{
	$nbsp4<a href='#hort'>Putative Horizontally Transferred Genes</a>
        <br>
    } if ( $include_ht_stats && $genome_type eq 'isolate' );

    my $x_taxon_phyloProfiler;
    if ( $include_taxon_phyloProfiler
        && -e "$avagz_batch_dir/$taxon_oid0" )
    {
        $x_taxon_phyloProfiler = qq{
            $nbsp4<a href="#phyloProfiler">Phylogenetic Profiler</a>
            <br/>
	};
    }

    # see if there is any proteomic data:
    my $proteincount    = 0;
    my $proteomics_data = $env->{proteomics};
    if ($proteomics_data) {
        $proteincount = 1;
    }
    if ( $proteincount > 0 ) {
        my $rclause1   = WebUtil::urClause('pig.genome');
        my $imgClause1 = WebUtil::imgClauseNoTaxon('pig.genome');
        my $sql        = qq{
	    select count( distinct pig.gene )
            from ms_protein_img_genes pig
            where pig.genome = ?
            $rclause1
            $imgClause1
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        $proteincount = $cur->fetchrow();
        $cur->finish();
    }

    # see if there is any rnaseq data:
    my $rnaseqcount = 0;
    my $rnaseq_data = $env->{rnaseq};
    if ($rnaseq_data) {
        $rnaseqcount = 1;
    }
    if ( $rnaseqcount > 0 ) {
	my $datasetClause = RNAStudies::datasetClause('dts');
        my $sql = qq{
            select count( distinct dts.dataset_oid )
            from rnaseq_dataset dts
            where dts.reference_taxon_oid = ?
            $datasetClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        $rnaseqcount = $cur->fetchrow();
        $cur->finish();
    }

    # see if there is any methylomics data:
    my $methylomicscount = 0;
    my $methylomics_data = $env->{methylomics};
    if ($methylomics_data) {
        $methylomicscount = 1;
    }
    if ( $methylomicscount > 0 ) {
        my $sql = qq{
            select count( distinct m.modification_oid )
            from meth_modification m, meth_sample s
            where s.IMG_taxon_oid = ?
            and s.sample_oid = m.sample
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        $methylomicscount = $cur->fetchrow();
        $cur->finish();
    }

    # show a table of content list
    # html bookmark - ken
    if ($content_list) {
        print qq{
            <p>
            <span class="boldTitle">About Genome</span>
            <ul style="padding-left:1.2em;list-style-type:circle">
            <li><a href="#overview">Overview</a></li>
            <li><a href="#statistics">Statistics</a></li>
	};

        if ( lc($is_pangenome) eq "yes" ) {
            print qq{
                </ul>
                </p>
            };

        } else {
            if ( $proteincount > 0 || $rnaseqcount > 0 ) {
                print qq{
		    <li><a href="#expression">Expression Studies</a></li>
		}
            }
            if ( $methylomicscount > 0 ) {
                print qq{
		    <li><a href="#methylomics">Methylomics Experiments</a></li>
		}
            }
            print qq{
		<li><a href="#genes">Genes</a></li>
		</ul>
		</p>
            };
        }
    }

    if ( !$taxon_oid ) {
        printStatusLine( "Error.", 2 );
        webError("Genome for taxon_oid='$taxon_oid_orig' not found\n");
    }

    my $lineage;
    $lineage .= lineageLink( "domain",   $domain ) . "; ";
    $lineage .= lineageLink( "phylum",   $phylum ) . "; ";
    $lineage .= lineageLink( "ir_class", $ir_class ) . "; ";
    $lineage .= lineageLink( "ir_order", $ir_order ) . "; ";
    $lineage .= lineageLink( "family",   $family ) . "; ";
    $lineage .= lineageLink( "genus",    $genus ) . "; ";

    #$lineage .= "$species; " if !blankStr( $species );
    if ( !blankStr($species) ) {
        $lineage .= lineageLink( "species", $species ) . "; ";
    }

    chop $lineage;
    chop $lineage;

    ### begin overview bookmark
    print WebUtil::getHtmlBookmark( "overview", "<h2>Overview</h2>" );
    print "\n";

    print "<table class='img'  border='1' >\n";
    printAttrRow( "Study Name (Proposal Name)", $proposal_name );
    if ( $genome_type eq "metagenome" ) {
        printAttrRow( "Sample Name", $taxon_display_name );
    } elsif ( lc($is_pangenome) eq "yes" ) {
        printAttrRow( "Pangenome Name", $taxon_display_name );
    } else {
        printAttrRow( "Organism Name", $taxon_display_name );
    }
    printAttrRow( "Taxon ID", $taxon_oid );

    if ( $submission_id > 0 ) {
        my $url = $img_er_submit_url;
        $url = $img_mer_submit_url if ( $genome_type eq "metagenome" );
        $url = $url . $submission_id;
        printAttrRow( "IMG Submission ID", $submission_id, $url );
    }

    if ( $ncbi_taxon_id > 0 ) {
        my $url = "$taxonomy_base_url$ncbi_taxon_id";
        printAttrRowRaw( "NCBI Taxon ID", alink( $url, $ncbi_taxon_id ) );
    }
    if ( $host_ncbi_taxon_id > 0 && $host_ncbi_taxon_id != $ncbi_taxon_id ) {
        my $url = "$taxonomy_base_url$host_ncbi_taxon_id";
        printAttrRowRaw( "Host NCBI Taxon ID", alink( $url, $host_ncbi_taxon_id ) );
    }

    #    printNCBIProjectId("RefSeq Project ID", $refseq_project_id);
    #    printNCBIProjectId("GenBank Project ID", $gbk_project_id);

    if ( !blankStr($study_gold_id) || !blankStr($sequencing_gold_id)  )
    {
        print "<tr class='img'>\n";
        print "<th class='subhead'>\n";
        print "GOLD ID in IMG Database";
        print "</th>\n";
        print "</td>\n";
        print "<td class='img'>\n";
        if ( !blankStr($study_gold_id) ) {
            my $url = HtmlUtil::getGoldUrl($study_gold_id);

            if($study_gold_id =~ /^Gs/) {
                print alink( $url, "Study ID: $study_gold_id" );
            } else {
                print alink( $url, "Project ID: $sequencing_gold_id" );
            }
            print "&nbsp;&nbsp;";
        }
        if(!blankStr($sequencing_gold_id)) {
            my $url = HtmlUtil::getGoldUrl($sequencing_gold_id);
            print alink( $url, "Project ID: $sequencing_gold_id" );
        }
        print "</td>\n";
        print "</tr>\n";
    }

    if ($analysis_project_id) {
        my $url = HtmlUtil::getGoldUrl($analysis_project_id);

        print "<tr class='img'>\n";
        print "<th class='subhead'>\n";
        print "GOLD Analysis Project Id";
        print "</th>\n";
        print "</td>\n";
        print "<td class='img'>\n";
        print alink($url, $analysis_project_id);
        print "</td>\n";
        print "</tr>\n";

        my($projectType, $submissionType) = TaxonDetailUtil::getSubmissionType($dbh, $analysis_project_id);
        printAttrRow( "GOLD Analysis Project Type",  $projectType);
        printAttrRow( "Submission Type",  $submissionType);
    }

    print $strrow;

    if ( lc($is_pangenome) eq "yes" ) {
        printAttrRow( "Genome Type", "Pangenome" );
    } else {
        #printAttrRow( "Genome Type", $genome_type );
    }

    if ( $genome_type ne "metagenome" ) {
        print "<tr class='img' >\n";
        print "<th class='subhead' align='right'>" . "Lineage" . "</th>\n";
        print "<td class='img' >$lineage</td>\n";
        print "</tr>\n";
    }

    my @pangenome_ids = ();
    my @ncbi_pids     = ();
    if ( lc($is_pangenome) eq "yes" ) {
        my $url = "$main_cgi?section=Pangenome&taxon_oid=$taxon_oid";
        $url = "$main_cgi?section=TaxonList&page=pangenome&taxon_oid=$taxon_oid";
        my $count = genomesInPangenome( $dbh, $taxon_oid );
        printAttrRowRaw( "Number of Genomes", alink( $url, $count ) );

        my $sql = qq{
            select distinct tp.pangenome_composition, tx.seq_status,
	           tx.gbk_project_id
            from taxon_pangenome_composition tp, taxon tx
            where tp.taxon_oid = ?
            and tx.taxon_oid = tp.pangenome_composition
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my %statusCnt;
        for ( ; ; ) {
            my ( $id, $seq_status, $gbk_project_id ) = $cur->fetchrow();
            last if !$id;
            $statusCnt{$seq_status}++;
            push( @pangenome_ids, $id );

            # bug fix - ken
            push( @ncbi_pids, $gbk_project_id ) if ( $gbk_project_id ne "" );
        }
        $cur->finish();
        my @keys = sort( keys(%statusCnt) );
        my $text;
        for my $k (@keys) {
            if ( $text ne "" ) {
                $text .= "; ";
            }
            my $count = $statusCnt{$k};
            $text .= $k . ": " . $count . " genomes";
        }
        printAttrRow( "Sequencing Status", $text );
    } else {
        printAttrRow( "Sequencing Status", $seq_status );
    }

    printAttrRow( "Sequencing Center", $seq_center );

    # TODO gene calling for ncbi
    if($submission_id ne '' && $analysis_project_id ne '') {
        # I know its a new submission with new gold id
        my $geneCalling = getGeneCalling($dbh, $submission_id);
        if($geneCalling ne 'No') {
            printAttrRow( "JGI Sequencing Annotation", 'This NCBI acquired genome has been re-annotated by JGI\'s gene calling methods',
            'http://jgi.doe.gov/ncbi-genomes-processed-img-pipeline-inclusion-img/' );
        }
    }


    printAttrRow( "IMG Release", $img_version );

    #printAttrRow( "Comment", $comments );
    print "<tr class='img' >\n";
    print "<th class='subhead'>Comment</th>\n";
    my $commentsHtml = escHtml($comments);
    print "<td class='img' >\n";
    print "$commentsHtml\n";
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead'> Release Date </th>\n";
    print "<td class='img' >\n";
    print $release_date;
    print "</td></tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead'> Add Date </th>\n";
    print "<td class='img' >\n";
    print $add_date;
    print "</td></tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead'> Modified Date </th>\n";
    print "<td class='img' >\n";
    print $mod_date;
    print "</td></tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead'> Distance Matrix Calc. Date </th>\n";
    print "<td class='img' >\n";
    print $distmatrix_date;
    print "</td></tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead'> High Quality </th>\n";
    print "<td class='img' >\n";
    print $high_quality_flag;
    print "</td></tr>\n";


    if ( $img_product_flag ne "" ) {
        print "<tr class='img' >\n";
        print "<th class='subhead'>IMG Product Flag </th>\n";
        print "<td class='img' >\n";
        print $img_product_flag;
        print "</td></tr>\n";
    }

    printAttrRow( "Is Public", $is_public );

    # $genome_completion
    printAttrRow( "Genome Completeness %", $genome_completion );

    if ( taxonHasBins( $dbh, $taxon_oid ) ) {
        print "<tr class='img' >\n";
        print "<th class='subhead' align='right' valign='top'>" . "Bins (of Scaffolds)</th>\n";
        print "<td class='img'>\n";
        printBinList( $dbh, $taxon_oid );
        print "</td>\n";
    }

    # replace this section to get meta data from gold env_sample table
    # show sample information for metagenome
    #
    # metagenome section should be remove once all metagenomes have been converted to file system
    my $sample_show_map = 0;

    my $ncbi_project_id = $gbk_project_id;
    my %metadata;
    if ( lc($is_pangenome) eq "yes" && scalar(@pangenome_ids) > 0 ) {
        my $tx_oid_str    = join( ",", @pangenome_ids );
        my $ncbi_pids_str = join( ",", @ncbi_pids );
        #pangenome has no gold_id and sample_gold_id in taxon table
        %metadata = DataEntryUtil::getAllMetadataFromGold( $submission_id, $tx_oid_str, $ncbi_pids_str, $gold_id, $sample_gold_id, $analysis_project_id );
    }


    # pangenome get metadata old way
    if ( scalar(keys %metadata) > 0 && lc($is_pangenome) eq "yes" && scalar(@pangenome_ids) > 0 ) {
        my @sections = ( 'Project Information', 'Metadata' );

        # display attribute values by section
        foreach my $s1 (@sections) {
	    print "<tr class='highlight'>\n";
	    print "<th class='subhead'>" . escapeHTML($s1) . "</th>  <th class='subhead'> &nbsp; </th></tr>\n";

            # single valued
            my @attrs1 = DataEntryUtil::getGoldSingleAttr();
            foreach my $attr1 (@attrs1) {
		# not in this section, skip
                next if ( DataEntryUtil::getGoldAttrSection($attr1) ne $s1 );

                if ( $metadata{$attr1} ) {
                    if ( $attr1 eq 'gold_stamp_id' ) {
                        my $gold_id = $metadata{$attr1};
                        my @ids     = split( /\; /, $gold_id );

                        my $text;
                        my $idx = 0;
                        foreach my $gid (@ids) {
                            last if !$gid;
                            my $url = HtmlUtil::getGoldUrl($gid);
                            if ( $text ne "" ) {
                                $text .= "; ";
                            }
                            $text .= alink( $url, $gid );
                            $idx++;
                        }

                        print "<tr class='img' >\n";
                        print "<th class='subhead'>\n";
                        print DataEntryUtil::getGoldAttrDisplayName($attr1);
                        print "</th>\n";

                        #print "</td>\n";
                        print "<td class='img'>\n";
                        print $text;
                        print "</td></tr>\n";

                    } elsif ( $attr1 eq 'ncbi_project_id' ) {
                        my $attr_val = $metadata{$attr1};
                        my @attrs    = split( /\; /, $attr_val );

                        my $text;
                        my $idx = 0;
                        foreach my $pid (@attrs) {
                            last if !$pid;
                            my $url = "$ncbi_project_id_base_url$pid";
                            if ( $text ne "" ) {
                                $text .= "; ";
                            }
                            $text .= alink( $url, $pid );
                            $idx++;
                        }

                        print "<tr class='img' >\n";
                        print "<th class='subhead'>\n";
                        print DataEntryUtil::getGoldAttrDisplayName($attr1);
                        print "</th>\n";

                        #print "</td>\n";
                        print "<td class='img'>\n";
                        print $text;
                        print "</td></tr>\n";
                    } elsif ( $attr1 eq 'pub_journal' ) {
                        my $attr_val = $metadata{$attr1};
                        my $pub_vol  = $metadata{'pub_vol'};
                        my $pub_link = $metadata{'pub_link'};

                        my @attrs = split( /\; /, $attr_val );
                        my @vols  = split( /\; /, $pub_vol );
                        my @links = split( /\; /, $pub_link );

                        my $text;
                        my $idx = 0;
                        foreach my $journal (@attrs) {
                            last if !$journal;
                            if ( $vols[$idx] ) {
                                $journal .= " (" . $vols[$idx] . ")";
                            }
                            if ( $text ne "" ) {
                                $text .= "; ";
                            }
                            if ( $pub_link && $links[$idx] ) {
                                $text .= alink( $links[$idx], $journal );
                            } else {
                                $text .= $journal;
                            }
                            $idx++;
                        }
                        if ( $metadata{'pub_link'} ) {
                            print "<tr class='img' >\n";
                            print "<th class='subhead'>\n";
                            print DataEntryUtil::getGoldAttrDisplayName($attr1);
                            print "</th>\n";

                            #print "</td>\n";
                            print "<td class='img'>\n";
                            print $text;
                            print "</td></tr>\n";
                        } else {
                            printAttrRow( DataEntryUtil::getGoldAttrDisplayName($attr1), $attr_val );
                        }
                    } elsif ( $attr1 eq 'pub_vol'
                        || $attr1 eq 'pub_link' )
                    {
                        next;
                    } else {
                        printAttrRow( DataEntryUtil::getGoldAttrDisplayName($attr1), $metadata{$attr1} );
                    }
                }
            }

            # show project location on google map
            if (   $sample_show_map == 0
                && $s1 eq 'Project Information'
                && defined( $metadata{'latitude'} )
                && defined( $metadata{'longitude'} ) )
            {
                my $latitude     = $metadata{'latitude'};
                my $longitude    = $metadata{'longitude'};
                my $altitude     = $metadata{'altitude'};
                my $geo_location = $metadata{'geo_location'};

                $geo_location = escHtml($geo_location);
                my $clat    = convertLatLong($latitude);
                my $clong   = convertLatLong($longitude);
                my $gmapkey = getGoogleMapsKey();

                if (   $clong ne ""
                    && $clat    ne ""
                    && $gmapkey ne "" )
                {
                    my $_map = <<END_MAP;
		    <link href="https://code.google.com/apis/maps/documentation/javascript/examples/default.css" rel="stylesheet" type="text/css" />
		    <script type="text/javascript" src="https://maps.google.com/maps/api/js?sensor=false"></script>
		    <script type="text/javascript" src="$base_url/googlemap.js"></script>
		    <div id="map_canvas" style="width: 500px; height: 300px; position: relative;"></div>
		    <script type="text/javascript">
		    var map = createMap(10, $clat, $clong);
		    var contentString = "<div><p>$geo_location<br>$latitude<br>$longitude<br>$altitude</p></div>";
		    addMarker(map, $clat, $clong, '$geo_location', contentString);
		    </script>
END_MAP
                    printAttrRowRaw( "Project Geographical Map", $_map );
                }
            }

            # set valued
            my @attrs2 = DataEntryUtil::getGoldSetAttr();
            foreach my $attr2 (@attrs2) {
		# not in this section, skip
                next if ( DataEntryUtil::getGoldAttrSection($attr2) ne $s1 );

                if ( $metadata{$attr2} ) {
                    printAttrRow( DataEntryUtil::getGoldAttrDisplayName($attr2), $metadata{$attr2} );
                }
            }

            printf "</tr>\n";
        }    # end for my $s1 (@sections)

    } elsif ($sequencing_gold_id) {
        # new gold project metadata - 2015-03-23 ken
        require GenomeList;
        my %h = ('gold_id' => $sequencing_gold_id);
        my %taxon = ($taxon_oid => \%h);
        my %h2 = ( $taxon_oid => 1 );
        my %goldId = ($sequencing_gold_id => \%h2);
        GenomeList::getProjectMetadata(\%taxon, \%goldId);
#        print "<br>\n";
#        print Dumper \%taxon;
#        print "<br>\n";

        print "<tr class='highlight'>\n";
        print "<th class='subhead'>Project Information</th>  <th class='subhead'> &nbsp; </th></tr>\n";


        my %projectMetadataColumns = GenomeList::getProjectMetadataColumns();
        foreach my $colName (sort { $projectMetadataColumns{$a} cmp $projectMetadataColumns{$b} } keys %projectMetadataColumns ){
            next if (lc($colName) =~ /email/);
            next if ($colName eq 'p.PI_NAME');
            next if ($colName eq 'p.name');
            next if ($colName eq 'p.DISPLAY_NAME');
            next if ($colName eq 'p.ITS_SPID');
            next if ($colName eq 'p.PMO_PROJECT_ID');
            if (exists $h{$colName}) {
                my $name = $projectMetadataColumns{$colName};
                my $value = $h{$colName};
                printAttrRowRaw( $name, $value );
            }

        }

        # map
        my $latitude     = $h{'p.LATITUDE'};
        my $longitude    = $h{'p.LONGITUDE'};
        my $altitude     = $h{'p.ALTITUDE'};
        my $geo_location = $h{'p.GEO_LOCATION'};
        $geo_location = escHtml($geo_location);
        my $clat    = convertLatLong($latitude);
        my $clong   = convertLatLong($longitude);
        my $gmapkey = getGoogleMapsKey();
        if (   $clong ne ""
                    && $clat    ne ""
                    && $gmapkey ne "" )
                {
                    my $_map = <<END_MAP;
            <link href="https://code.google.com/apis/maps/documentation/javascript/examples/default.css" rel="stylesheet" type="text/css" />
            <script type="text/javascript" src="https://maps.google.com/maps/api/js?sensor=false"></script>
            <script type="text/javascript" src="$base_url/googlemap.js"></script>
            <div id="map_canvas" style="width: 500px; height: 300px; position: relative;"></div>
            <script type="text/javascript">
            var map = createMap(10, $clat, $clong);
            var contentString = "<div><p>$geo_location<br>$latitude<br>$longitude<br>$altitude</p></div>";
            addMarker(map, $clat, $clong, '$geo_location', contentString);
            </script>
END_MAP
            printAttrRowRaw( "Project Geographical Map", $_map );
        }
        printf "</tr>\n";

    }

    # publications
    TaxonDetailUtil::printTaxonPublications($dbh, $taxon_oid,
			    "Genome Publication",
			    "gold_sp_genome_publications\@imgsg_dev");

    # inferred phenotypes
    my $d1 = substr( $domain, 0, 1 );
    if ( $img_pheno_rule && ( $d1 eq 'A' || $d1 eq 'B' || $d1 eq 'E' ) ) {
        printPhenotypeInfo($taxon_oid);
    }

    if ( ! $img_edu ) {
        if ( $d1 eq 'G' || $d1 eq 'A' || $d1 eq 'B' || $d1 eq 'E' ) {
            ## genome fragment
            require NaturalProd;
            #my $np_id = NaturalProd::getNPID( $dbh, $taxon_oid );
            my %nps;
            my $np_id = 0;
            my $sql2 = qq{
                select c.compound_oid, c.compound_name
                from img_compound c, np_biosynthesis_source np
                where np.taxon_oid = ?
                and np.compound_oid = c.compound_oid
            };
            my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid );
            for ( ; ; ) {
                my ( $c_id, $c_name ) = $cur2->fetchrow();
                last if !$c_id;
                $nps{$c_id} = $c_name;
                $np_id++;
            }
            $cur2->finish();

            if ($np_id) {
                print "<tr class='img' >\n";
                print "<th class='subhead'>\n";
                if ( $np_id > 1 ) {
                    print "Secondary Metabolites";
                }
                else {
                    print "Secondary Metabolite";
                }
                print "</th>\n";
                print "<td class='img'>\n";
                #my $url3 = "$main_cgi?section=NaturalProd&page=naturalProd&np_id=$np_id";
                #print alink( $url3, $np_id );
                #NaturalProd::printExperimentalNP( $dbh, $np_id );

                for my $compound_oid (keys %nps) {
                    my $url2 = "$main_cgi?section=ImgCompound"
                        . "&page=imgCpdDetail&compound_oid=$compound_oid";
                    print alink($url2, $compound_oid) . ": " .
                        $nps{$compound_oid} . "<br/>\n";
                }

                print "</td>\n";
                print "</tr>\n";
            }
        }
    }
    print "</table>\n";

    # end of Organism Information section
    ### end overview bookmark

    ### begin statistics bookmark
    if ( $genome_type eq "metagenome" ) {
        print WebUtil::getHtmlBookmark( "statistics", "<h2>Metagenome Statistics</h2>" );
        showZeroHint();
        print "\n<br />";
        CompareGenomes::printStatsForOneTaxon($taxon_oid);
    } elsif ( lc($is_pangenome) eq "yes" ) {
        print WebUtil::getHtmlBookmark( "statistics", "<h2>Pangenome Statistics</h2>" );
        showZeroHint();
        print "\n<br />";
        CompareGenomes::printStatsForPangenome($taxon_oid);
    } else {
        print WebUtil::getHtmlBookmark( "statistics", "<h2>Genome Statistics</h2>" );
        showZeroHint();
        print "\n<br />";

        print qq{
        <div id='ani_parent' style='width:1200px'>
        <div id='ani_left'>
        } if ($enable_ani);

        CompareGenomes::printStatsForOneTaxon($taxon_oid);

        if ($enable_ani) {
            require ANI;
            print qq{
            </div>
            <div id='ani_right'>
            };
	    ANI::printCliqueInfoForGenome($taxon_oid);
            print qq{
            </div>
            <div id="myclear"></div>
            </div>
            };
        } # end if $enable_ani
    }
    print "\n";
    ### end statistics bookmark

    ### begin browse genome button bookmark
    print WebUtil::getHtmlBookmark( "browse", "" );

    my $nScaffolds = scaffoldCount( $dbh, $taxon_oid );
    if ( $nScaffolds > 0 ) {
        #Changed for IMG 3.4 per Nikos -BSJ 06/21/11
        #print "$nbsp4<a href='#tools'>Genome Viewers</a></p>";
        print WebUtil::getHtmlBookmark( "", "<h2>Browse Genome</h2>" );
        print "\n";

        if ( lc($is_pangenome) eq "yes" ) {
            my $url = "$main_cgi?section=TaxonList&page=pangenome";
            $url .= "&taxon_oid=$taxon_oid";
            print buttonUrl( $url, "Pangenome Details", "lgbutton" );
            print "<br>\n";

            my $url = "$main_cgi?section=Pangenome&taxon_oid=$taxon_oid";
            print buttonUrl( $url, "Pangene Details", "lgbutton" );
            print "<br>\n";

            if ( $domain ne "Eukaryota" ) {
                my $url = "$main_cgi?section=TaxonCircMaps"
		        . "&page=circMaps&taxon_oid=$taxon_oid";
                print buttonUrl( $url, "Pangenome Maps", "lgbutton" );
                print "<br/>\n";
            }

            printStatusLine( "Loaded.", 2 );

            #$dbh->disconnect();
            print end_form();
            return;
        }

        my $url = "$section_cgi&page=scaffolds&taxon_oid=$taxon_oid";

        if ( $proteincount > 0 || $rnaseqcount > 0 || $methylomicscount > 0 ) {
            my @studies;
            push @studies, "proteomics"  if ( $proteincount > 0 );
            push @studies, "rnaseq"      if ( $rnaseqcount > 0 );
            push @studies, "methylomics" if ( $methylomicscount > 0 );
            my $studies_str = join( ",", @studies );
            $url .= "&sample=0&study=$studies_str";
        }
        print buttonUrl( $url, "Scaffolds and Contigs", "lgbutton" );

        if ( $domain ne "Eukaryota" ) {
            print "<br/>\n";
            my $url = "$main_cgi?section=TaxonCircMaps"
		    . "&page=circMaps&taxon_oid=$taxon_oid";
            print buttonUrl( $url, "Chromosome Maps", "lgbutton" );
        }
        print "<br/>\n";

        my $url = "$main_cgi?section=Artemis"
	        . "&page=form&taxon_oid=$taxon_oid";
        print buttonUrl( $url, "Web Artemis", "lgbutton" );
    }

    my $prodege = WebUtil::hasProdege($taxon_oid);
    if($prodege) {
        print "<p>\n";
        print  WebUtil::buttonUrlNewWindow( $prodege, "ProDeGe 3D Viewer", "lgbutton" );
        print "&nbsp;&nbsp;Best viewed using Chrome. For FireFox please see <a href='https://get.webgl.org/'>WebGL for support</a></p>";
    }

    if ( $methylomicscount > 0 ) {
        print WebUtil::getHtmlBookmark
	    ( "methylomics", "<h2>Methylomics Experiments</h2>" );
        print "\n";

        # see if there is any methylomics data:
        my $url = "$main_cgi?section=Methylomics"
	        . "&page=genomestudies&taxon_oid=$taxon_oid";
        print buttonUrl( $url, "List of Methylomics Experiments", "lgbutton" );
    }

    if ( $proteincount > 0 || $rnaseqcount > 0 ) {
        print WebUtil::getHtmlBookmark
	    ( "expression", "<h2>Expression Studies</h2>" );
        print "\n";
    }

    # see if there is any proteomic data:
    if ( $proteincount > 0 ) {
        my $url = "$main_cgi?section=IMGProteins"
	        . "&page=genomestudies&taxon_oid=$taxon_oid";
        print buttonUrl( $url, "List of Protein Studies", "lgbutton" );
    }
    if ( $proteincount > 0 && $rnaseqcount > 0 ) {
        print "<br/>";
    }

    # see if there is any rnaseq data:
    if ( $rnaseqcount > 0 ) {
        my $url = "$main_cgi?section=RNAStudies"
	        . "&page=genomestudies&taxon_oid=$taxon_oid";
        print buttonUrl( $url, "List of RNASeq Studies", "lgbutton" );
        print "<br/>";
        my $url = "$main_cgi?section=RNAStudies"
            . "&page=differenitalExpression&taxon_oid=$taxon_oid";
        print buttonUrl( $url, "RNASeq Differenital Expression Data", "lgbutton" );
    }
    ### end browse genome bookmark

    ### begin genes bookmark
    print WebUtil::getHtmlBookmark( "genes", "" );

    my $showPhyloDist = hasPhylumDistGenes( $dbh, $taxon_oid );
    if ($showPhyloDist) {
        print WebUtil::getHtmlBookmark
	    ( "bin", "<h2>Phylogenetic Distribution of Genes</h2>" );
        print "<p>\n";
        my $url = "$main_cgi?section=MetagenomeHits&page=metagenomeStats";
        $url .= "&taxon_oid=$taxon_oid";
        print qq{
            <input type='button' class='lgbutton'
            value='Distribution by BLAST percent identities'
            onclick="window.location.href='$url'"
            title='Distribution of genes binned by BLAST percent identities'
            />
        };
        print "</p>\n";
    }

    else {
        my $phylo_dir_name = MetaUtil::getPhyloDistTaxonDir($taxon_oid);
        if ( -e $phylo_dir_name ) {
            print WebUtil::getHtmlBookmark ( "bin", "<h2>Phylogenetic Distribution of Genes</h2>" );
            print "<p>\n";
            my $url = "$main_cgi?section=MetagenomeHits&page=metagenomeStats";
            $url .= "&taxon_oid=$taxon_oid";

            print qq{
                <input type='button' class='lgbutton'
                value='Distribution by BLAST percent identities'
                onclick="window.location.href='$url'"
                title='Distribution of genes binned by BLAST percent identities'
                />
            };

            my $has_16s_dist = 0;

            my $file_name_16s = $phylo_dir_name . "/16s_assembled.profile.txt";
            if ( -e $file_name_16s ) {
                $has_16s_dist = 1;
                last;
            }
            if ($has_16s_dist) {
                print "<br/>";
                my $url2 = "$main_cgi?section=MetagenomeHits&page=metagenomeStats";
                $url2 .= "&taxon_oid=$taxon_oid&rna16s=1";
                print qq{
                    <input type='button' class='lgbutton'
                    value='16S rRNA Distribution by BLAST'
                    onclick="window.location.href='$url2'"
                    title='Distribution of 16S rRNA genes binned by BLAST percent identities'
                    />
                };
            }
            print "</p>\n";
        }
    }

    if ( $include_taxon_phyloProfiler
        && -e "$avagz_batch_dir/$taxon_oid" )
    {
        print WebUtil::getHtmlBookmark( "phyloProfiler", "<h2>Phylogenetic Profiler</h2>" );
        print "<p>\n";

        my $url = "$main_cgi?section=PhylogenProfiler";
        $url .= "&taxon_oid=$taxon_oid";
        print qq{
            <input type='button' class='lgbutton'
            value='Phylogenetic Profiler'
            onclick="window.location.href='$url'"
            title='Phylogenetic Profiler'
            />
        };
        print "</p>\n";
    }

    # Putative Horizontally Transferred Genes
    if ( $include_ht_stats && $genome_type eq 'isolate' ) {
        print WebUtil::getHtmlBookmark ( "hort", "<h2>Putative Horizontally Transferred Genes</h2>" );
        my $url = "main.cgi?section=TaxonDetail" . "&page=horTransferred&taxon_oid=$taxon_oid";
        print qq{
            <p>
            <input type='button' class='lgbutton'
            value='Putative Horizontally Transferred'
            onclick="window.location.href='$url'"
            />
            </p>
       };
    }

    if ( $genome_type eq 'isolate' ) {
        print WebUtil::getHtmlBookmark ( "compare", "<h2>Compare Gene Annotations</h2>" );
        print "\n";

        my $url = "$main_cgi?section=GeneAnnotPager" . "&page=viewGeneAnnotations&taxon_oid=$taxon_oid";

        print "<div class='lgbutton'>\n";
        print alink( $url, "Compare Gene Annotations" );
        print "</div>\n";
        print "<p>\n";
        print "Gene annotation values are precomputed and stored ";
        print "in a tab delimited file<br/>";
        print "also viewable in Excel.<br/>\n";
        print "</p>\n";
    }

    if ($enable_ani) {
	# ANI
	print WebUtil::getHtmlBookmark
	    ("ani", "<h2>Average Nucleotide Identity</h2>");
	my $url = "$main_cgi?section=ANI&page=infoForGenome&taxon_oid=$taxon_oid";
	print "<div class='lgbutton'>\n";
	print alink( $url, "Average Nucleotide Identity" );
	print "</div>\n";
    }

    # Kmer Tool
    if ( $genome_type eq 'isolate' ) {
        print WebUtil::getHtmlBookmark ( "kmer", "<h2>Scaffold Consistency Check</h2>" );
        print "\n";
        my $url = "$main_cgi?section=Kmer&page=plot&taxon_oid=$taxon_oid";
        print "<div class='lgbutton'>\n";
        print alink( $url, "Kmer Frequency Analysis" );
        print "</div>\n";
    }

    if ( $genome_type eq 'isolate' ) {
        print WebUtil::getHtmlBookmark ( "geneInfo", "<h2>Export Gene Information</h2>" );
        print "\n";

        my $url = "$main_cgi?section=GeneInfoPager" . "&page=viewGeneInformation&taxon_oid=$taxon_oid";

        print "<div class='lgbutton'>\n";
        my $contact_oid = WebUtil::getContactOid();
        print alink( $url, "Export Gene Information", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button Gene Information']);" );
        print "</div>\n";
        print "<p>\n";
        print "Gene information is precomputed and stored ";
        print "in a tab delimited file<br/>";
        print "also viewable in Excel.<br/>\n";
        print "</p>\n";
    }
    ### end gene bookmark

    ### begin download data/export bookmark

    # Show links and search only for genomes that have scaffold/DNA data.
    # Do not show for proxy gene (protein) data only.
    # --es 07/05/08
    if ( hasNucleotideData( $dbh, $taxon_oid ) ) {

        # html bookmark 4 - export section
        if ( $genome_type eq 'isolate' && $enable_genbank ) {
            print WebUtil::getHtmlBookmark ( "export", "<h2>Export Genome Data</h2>" );
            printExportLinks( $taxon_oid, $is_big_euk, $jgi_portal_url_str );
        }

        #if ($include_metagenomes) {
        printScaffoldSearchForm($taxon_oid);

        #}
    }

    # else {
    #        # html bookmark 4 - export section
    #        print WebUtil::getHtmlBookmark( "export", "<h2>Export Genome Data</h2>" );
    #        #print "\n";
    #        printProxyGeneExportLinks( $taxon_oid, $is_big_euk );
##        printHint(   "Right click on link to see menu for "
##                   . "saving link contents to target file.<br/>\n"
##                   . "Please be patient during download.<br/>" );
    #    }
    ### end download data/export bookmark

    printStatusLine( "Loaded.", 2 );

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# showZeroHint - display a hint under the genome statistics subheading
############################################################################
sub showZeroHint() {
    printHint(
        "To view rows that are zero,
              go to <a href='main.cgi?section=MyIMG&page=preferences'>
              MyIMG preferences</a> <br/>and set
              <b>\"Hide Zeroes in Genome Statistics\"</b>
              to <b>\"No\"</b>."
    );
}

############################################################################
# isGebaGenome
############################################################################
sub isGebaGenome {
    my ( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');

    # use c2.username = 'GEBA' causing invalid username/password
    # use c1.contact_oid = c2.contact_oid = 3031 instead
    my $sql = qq{
        select count(*)
        from taxon tx, contact_taxon_permissions c1
        where c1.contact_oid = 3031
        and c1.taxon_permissions = tx.taxon_oid
        and tx.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printExportLinks - Show links for export.
############################################################################
sub printExportLinks {
    my ( $taxon_oid, $is_big_euk, $jgi_portal_url_str ) = @_;

    if ( $is_big_euk ne "Yes" ) {
        my $url = "$section_cgi&page=taxonArtemisForm&taxon_oid=$taxon_oid";
        print buttonUrl( $url, "Generate Genbank File", "lgbutton" );
    }
    print "</p>\n";
}

############################################################################
# printExportLinksJS - Print JS for appending download option in URL.
############################################################################
sub printExportLinksJS {
    print <<EOF;

<script type="text/javascript">
function appendOption(o) {
    var btn = document.getElementsByName('exportformat');
    var url = o.href;

    for (var i = 0, length = btn.length; i < length; i++) {
	if (btn[i].checked) {
	    url = url + "&type=" + btn[i].value;
	}
    }
    window.location = url;
    return false;
}

</script>

EOF

}

############################################################################
# printProxyGeneExportLinks - Show links for protein only export.
############################################################################
sub printProxyGeneExportLinks {
    my ( $taxon_oid, $is_big_euk ) = @_;

}

############################################################################
# taxonHasBins - Taxon has bins
############################################################################
sub taxonHasBins {
    my ( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
    my $sql       = qq{
        select scf.taxon
        from scaffold scf
        where scf.taxon = ?
        and exists (select 1
                   from bin_scaffolds bs
                   where bs.scaffold = scf.scaffold_oid
                   and rownum < 2)
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

############################################################################
# printScaffoldSearchForm - Show scaffold search form.
############################################################################
sub printScaffoldSearchForm {
    my ($taxon_oid) = @_;

    print start_form(
        -action => "$section_cgi&searchScaffolds=1",
        -method => "post",
        -name   => "searchScaffoldForm"
    );

    print WebUtil::getHtmlBookmark ( "information", "<h2>Scaffold Search</h2>" );
    print "<p>\n";
    print "Scaffold search allows for seaching for all scaffolds ";
    print "within an organism or microbiome.<br/>\n";
    print "Please enter a search term or matching substring ";
    print "for scaffold name or read ID.<br/>\n";
    print "</p>\n";

    print "<select name='scaffoldSearchType'>\n";
    print "<option value='scaffold_name'>Scaffold Name</option>\n";
    print "<option value='read_id'>Read ID";
    print "<option value='scaffold_oid'>Scaffold ID"
      if $img_internal;
    print nbsp(10);
    print "</option>\n";
    print "</select>\n";
    print "<input type='text' name='scaffoldSearchTerm' size='40' />\n";
    print "<br/>\n";

    print "<p>\n";
    print "or enter low and high range for<br/>\n";
    print "</p>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );
    print "<select name='rangeType'>\n";
    my $x = nbsp(10);
    print "<option value='seq_length'>Sequence Length$x</option>\n";
    print "<option value='gc_percent'>GC (0.00-1.00)</option>\n";
    print "<option value='read_depth'>Read Depth</option>\n";
    print "</select>\n";
    print "<input type='text' name='loRange' size='10' /> -";
    print "<input type='text' name='hiRange' size='10' />\n";
    print "<br/>\n";
    my $name = "_section_${section}_searchScaffolds";
    print submit(
        -name  => $name,
        -value => "Go",
        -class => "smdefbutton"
    );
    print nbsp(1);
    print reset( -class => "smbutton" );
    print end_form();
}

############################################################################
# lineageLink - Gererate linearge link for getting other microbes
#   with same lineage.
############################################################################
sub lineageLink {
    my ( $field, $value ) = @_;
    if ( blankStr($value) || $value eq "unclassified" ) {
        return $value;
    }
    my $url = "$main_cgi?section=TaxonList&page=lineageMicrobes&$field=" . massageToUrl($value);
    return alink( $url, $value );
}

############################################################################
# printEnvSampleDetails - Show details of environmental sample.
############################################################################
sub printEnvSampleDetails {
    my ( $dbh, $sample_oid ) = @_;

    my $sql = qq{
        select es.sample_oid, es.sample_display_name,
           es.sample_site, es.date_collected,
           es.geo_location, es.latitude, es.longitude, es.altitude,
           es.sampling_strategy, es.sample_isolation, es.sample_volume,
           es.est_biomass, es.est_diversity,
           es.energy_source, es.oxygen_req,
           es.temp, es.ph,
           es.host_ncbi_taxid,
           es.host_name, es.host_gender, es.host_age, es.host_health_condition,
           es.seq_method, es.library_method,
           es.est_size, es.binning_method,
           es.contig_count, es.singlet_count, es.gene_count,
           es.comments, es.project, to_char(es.add_date, 'yyyy-mm-dd')
        from env_sample_gold es
        where es.sample_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
    my (
        $sample_oid,     $sample_display_name,   $sample_site,     $date_collected,    $geo_location,
        $latitude,       $longitude,             $altitude,        $sampling_strategy, $sample_isolation,
        $sample_volume,  $est_biomass,           $est_diversity,   $energy_source,     $oxygen_req,
        $temp,           $ph,                    $host_ncbi_taxid, $host_name,         $host_gender,
        $host_age,       $host_health_condition, $seq_method,      $library_method,    $est_size,
        $binning_method, $contig_count,          $singlet_count,   $gene_count,        $comments,
        $project,        $add_date
      )
      = $cur->fetchrow();
    $cur->finish();
    my $sql = qq{
        select project_oid, project_name, description, project_type,
           status, ncbi_project_id, gold_id, gcat_id, classification
        from project_info pi
        where pi.project_oid = $project
    };
    my $cur = execSql( $dbh, $sql, $verbose ) if $project ne "";
    my (
        $pi_project_oid,     $pi_project_name, $pi_description, $pi_project_type, $pi_status,
        $pi_ncbi_project_id, $pi_gold_id,      $pi_gcat_id,     $pi_classification
      )
      = $cur->fetchrow()
      if $project ne "";
    $cur->finish() if $project ne "";
    printOptAttrRow( "Metagenome Project Name",   $pi_project_name );
    printOptAttrRow( "Metagenome Classification", $pi_classification );
    printOptAttrRow( "Sample Site",               $sample_site );

    #printHabitat( $dbh, $sample_oid );
    printOptAttrRow( "Date Collected",        $date_collected );
    printOptAttrRow( "Geographical Location", $geo_location );
    printOptAttrRow( "Latitude",              $latitude );
    printOptAttrRow( "Longitude",             $longitude );
    printOptAttrRow( "Altitude",              $altitude );

    my $show_map = 1;
    $show_map = 0 if ($use_img_gold);
    my $clat    = convertLatLong($latitude);
    my $clong   = convertLatLong($longitude);
    my $gmapkey = getGoogleMapsKey();
    $geo_location = escHtml($geo_location);

    if ( $show_map && $clong ne "" && $clat ne "" && $gmapkey ne "" ) {
        my $_map = <<END_MAP;
	<link href="https://code.google.com/apis/maps/documentation/javascript/examples/default.css" rel="stylesheet" type="text/css" />
	<script type="text/javascript" src="https://maps.google.com/maps/api/js?sensor=false"></script>
	<script type="text/javascript" src="$base_url/googlemap.js"></script>
	<div id="map_canvas" style="width: 500px; height: 300px; position: relative;"></div>
	<script type="text/javascript">
	var map = createMap(10, $clat, $clong);
	var contentString = "<div><p>$geo_location<br>$latitude<br>$longitude<br>$altitude</p></div>";
	addMarker(map, $clat, $clong, '$geo_location', contentString);
	</script>
END_MAP
        printAttrRowRaw( "Geographical Map", $_map );
    }

    printOptAttrRow( "Sampling Strategy",     $sampling_strategy );
    printOptAttrRow( "Sample Isolation",      $sample_isolation );
    printOptAttrRow( "Sample Volume",         $sample_volume );
    printOptAttrRow( "Est. Biomass",          $est_biomass );
    printOptAttrRow( "Est. Diversity",        $est_diversity );
    printOptAttrRow( "Energy Source",         $energy_source );
    printOptAttrRow( "Oxygen Requirement",    $oxygen_req );
    printOptAttrRow( "Temperature",           $temp );
    printOptAttrRow( "pH",                    $ph );
    printOptAttrRow( "NCBI Host taxon ID",    $host_ncbi_taxid );
    printOptAttrRow( "Host name",             $host_name );
    printOptAttrRow( "Host gender",           $host_gender );
    printOptAttrRow( "Host age",              $host_age );
    printOptAttrRow( "Host health condition", $host_health_condition );
    printOptAttrRow( "Sequencing Method",     $seq_method );
    printOptAttrRow( "Library Method",        $library_method );
    printOptAttrRow( "Est. Size",             $est_size );
    printOptAttrRow( "Binning Method",        $binning_method );
    printOptAttrRow( "Contig count",          $contig_count );
    printOptAttrRow( "Singlet count",         $singlet_count );
    printOptAttrRow( "Sample Comments",       $comments );
    printMetaAttributes( $dbh, $sample_oid );
}

# test code to parse geo location for lat/long
sub parseGeoLocation {
    my ($str) = @_;

    $str = uc($str);
    $str =~ s/,/./g;
    $str =~ s/\s+/ /g;
    $str =~ s/://g;

    my $lat  = "";
    my $long = "";

    if ( $str =~ /^(.*)(LAT).? ?(-?\d+.?\d+) ?(.*)$/ ) {

        # eel river basin (dive t201. lat. 40.785 lon -124.596)
        $lat = $3;
    }

    if ( $str =~ /^(.*)(LON|LONG).? ?(-?\d+.?\d+) ?(.*)$/ ) {

        # eel river basin (dive t201. lat. 40.785 lon -124.596)
        $long = $3;
    }

    if ( $lat eq "" || $long eq "" ) {

        if ( $str =~ /^(.*)([NS] ?-?\d+.?\d+) ?([WE] ?-?\d+.?\d+)(.*)$/ ) {

            # Pacific Ocean, Santa Cruz Basin, USA (N33.30 W119.22)
            $lat  = $2;
            $long = $3;
        }
    }

    return ( $lat, $long );
}

###########################################################################
# printHabitat - Print habitat information.
#   This may already be duplicated by taxon.ecotype, so may be
#   redundant.
############################################################################
#sub printHabitat {
#    my ( $dbh, $sample_oid ) = @_;
#
#    my $sql = qq{
#        select esht.sample_oid, cv.ecotype_term
#        from env_sample_habitat_type esht, ecotypecv cv
#        where esht.sample_oid = ?
#        and esht.habitat_type = cv.ecotype_oid
#        order by cv.ecotype_term
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
#    my $val;
#    for ( ; ; ) {
#        my ( $sample_oid, $ecotype_term ) = $cur->fetchrow();
#        last if !$sample_oid;
#        $val .= escHtml($ecotype_term) . "<br/>";
#    }
#    chop $val;
#    chop $val;
#    chop $val;
#    chop $val;
#    chop $val;
#    $cur->finish();
#
#    print "<tr class='img'>\n";
#    print "<th class='subhead'>Habitat</th>\n";
#    print "<td class='img'>$val</td>\n";
#    print "</tr>\n";
#}

###########################################################################
# printMetaAttributes - Print other metadata attributes.
############################################################################
sub printMetaAttributes {
    my ( $dbh, $sample_oid ) = @_;

    #    return if $sample_oid eq "";
    #
    #    my $sql = qq{
    #        select md.meta_tag, md.meta_value
    #        from env_sample_misc_meta_data md
    #        where md.sample_oid = ?
    #        order by md.meta_tag, md.meta_value
    #    };
    #    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
    #    my $val;
    #    for ( ; ; ) {
    #        my ( $meta_tag, $meta_value ) = $cur->fetchrow();
    #        last if !$meta_tag;
    #        printAttrRow( $meta_tag, $meta_value );
    #    }
}

############################################################################
# printBinList - Print a list of the bins.
############################################################################
sub printBinList {
    my ( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
    my $sql       = qq{
       select bm.method_name, b.bin_oid, b.display_name, count( bs.scaffold )
       from scaffold scf, bin b, bin_scaffolds bs, bin_method bm
       where scf.taxon = ?
       and scf.scaffold_oid = bs.scaffold
       and b.bin_oid = bs.bin_oid
       and b.bin_method = bm.bin_method_oid
       and b.is_default = 'Yes'
       $rclause
       $imgClause
       group by bm.method_name, b.bin_oid, b.display_name
       order by bm.method_name, b.bin_oid, b.display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $old_method_name;
    for ( ; ; ) {
        my ( $method_name, $bin_oid, $display_name, $cnt ) = $cur->fetchrow();
        last if !$bin_oid;
        if ( $old_method_name ne $method_name ) {
            if ( $old_method_name ne "" ) {
                print "<br/>\n";
            }
            print "<i>Method</i>: ";
            print escHtml($method_name) . "<br/>\n";
        }
        print nbsp(4);
        print escHtml($display_name);
        print nbsp(1);
        my $url = "$main_cgi?section=Metagenome" . "&page=binDetail&bin_oid=$bin_oid";
        print "(" . alink( $url, $cnt ) . ")<br/>\n";
        $old_method_name = $method_name;
    }
    $cur->finish();
}

############################################################################
# printLinkedExternalAccessions - Print external accession with URL
#   links to NCBI.
############################################################################
sub printLinkedExternalAccessions {
    my ($s) = @_;
    $s =~ s/;/ /g;
    $s =~ s/,/ /g;
    $s =~ s/\s+/ /g;
    my @ids = split( / /, $s );
    for my $i (@ids) {
        my $i0 = $i;
        $i =~ s/_GR$//;
        my $url = "$ncbi_entrez_base_url$i";
        $i0 =~ s/_/ /g;
        print alink( $url, $i0 );
        print nbsp(1);
    }
}

############################################################################
# scaffoldCount - Get number of scaffolds in the genome which have genes.
############################################################################
sub scaffoldCount {
    my ( $dbh, $taxon_oid, $scaffold_oid ) = @_;

    my $rclause   = WebUtil::urClause('ts.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('ts.taxon_oid');

    my $sclause1;
    $sclause1 = "and g.scaffold = $scaffold_oid" if $scaffold_oid > 0;
    my $sql = qq{
        select ts.n_scaffolds
        from taxon_stats ts, gene g, scaffold_stats ss
        where ts.taxon_oid = ?
        and g.taxon = ts.taxon_oid
        and g.scaffold = ss.scaffold_oid
        and ss.seq_length > 0
        $sclause1
   };

    # 2.8 query performance - if no scaffold oid - ken
    if ( $scaffold_oid eq "" ) {
        $sql = qq{
            select ts.n_scaffolds
            from taxon_stats ts
            where ts.taxon_oid = ?
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printScaffoldSearchResults - Show search results.
############################################################################
sub printScaffoldSearchResults {
    my $taxon_oid  = param("taxon_oid");
    my $searchType = param("scaffoldSearchType");
    my $searchTerm = param("scaffoldSearchTerm");
    my $rangeType  = param("rangeType");
    my $loRange    = param("loRange");
    my $hiRange    = param("hiRange");

    if (   blankStr($searchTerm)
        && blankStr($loRange)
        && blankStr($hiRange) )
    {
        webError("Please enter a search term or substring or ranges.");
    }
    if ( !WebUtil::isInt($searchTerm) && $searchType eq "scaffold_oid" ) {
        webError("Please enter a positive integer for scaffold_oid.\n");
    }
    if ( !blankStr($loRange) || !blankStr($hiRange) ) {
        if ( $loRange < 0 ) {
            webError("Invalid low range.  Enter a number greater than zero.");
        }
        if ( $hiRange < 0 ) {
            webError("Invalid high range. Enter a number greater than zero.");
        }
        if ( $loRange > $hiRange ) {
            webError( "Low range greater than high range. " . "Reverse this order." );
        }
        if ( $rangeType eq "gc_percent" ) {
            if ( $loRange > 1.00 || $hiRange > 1.00 ) {
                webError("Enter number between 0.00 and 1.00.");
            }
        }
        if ( $rangeType eq "seq_length" ) {
            if ( !WebUtil::isInt($loRange) || !WebUtil::isInt($hiRange) ) {
                webError("Enter integers for low and high range.");
            }
        } else {
            if ( !isNumber($loRange) || !isNumber($hiRange) ) {
                webError("Enter decimal numbers for low and high range.");
            }
            $loRange = sprintf( "%.2f", $loRange );
            $hiRange = sprintf( "%.2f", $hiRange );
        }
    }

    #    if ( !blankStr($searchTerm)
    #         && ( $searchTerm =~ /%/ || $searchTerm =~ /_/ ) )
    #    {
    #        webError("Search term has illegal characters '%' or '_'.\n");
    #    }

    my $searchTermLower = $searchTerm;
    $searchTermLower =~ tr/A-Z/a-z/;

    printMainForm();
    print "<h1>Scaffold Search Results</h1>\n";

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');

    my $whereClause_scaffold_name;
    my $whereClause_scaffold_oid;
    my $whereClause_read_id;
    my $whereClause_range;
    my $rangeField;
    if ( $rangeType eq "gc_percent" ) {
        $rangeField = "ss.gc_percent";
    } elsif ( $rangeType eq "read_depth" ) {
        $rangeField = "scf.read_depth";
    } else {
        $rangeField = "ss.seq_length";
    }

    my @binds = ($taxon_oid);

    if ( $searchTerm ne "" ) {
        $whereClause_scaffold_name = "and lower( scf.ext_accession ) like '%' || ? || '%' ";
        $whereClause_scaffold_oid  = "and scf.scaffold_oid = ? ";

        #push(@binds, $searchTermLower);
        #push(@binds, $searchTerm);
    }
    if ( $searchTerm ne "" ) {
        $whereClause_read_id =
            "and( lower( scf.ext_accession ) like '%' || ? || '%' or "
          . "     lower( rs.ext_accession ) like '%' || ? || '%' ) ";

        #push(@binds, $searchTermLower);
        #push(@binds, $searchTermLower);

    }
    if ( $loRange ne "" && $hiRange ne "" ) {
        $whereClause_range = "and $rangeField >= $loRange and $rangeField <= $hiRange";
    }
    my $orderClause = "order by ss.seq_length desc";
    if ( $loRange ne "" ) {
        $orderClause = "order by $rangeField desc";
    }
    my $whereClause;

    if ( $searchTerm ne "" && $searchType eq "scaffold_name" ) {
        $whereClause = $whereClause_scaffold_name;
        push( @binds, $searchTermLower );
    }

    if ( $searchTerm ne "" && $searchType eq "scaffold_oid" ) {
        $whereClause = $whereClause_scaffold_oid;
        push( @binds, $searchTerm );
    }

    if ( $searchTerm ne "" && $searchType eq "read_id" ) {
        $whereClause = $whereClause_read_id;
        push( @binds, $searchTermLower );
        push( @binds, $searchTermLower );
    }

    if ( $loRange ne "" && $hiRange ne "" ) {
        $whereClause = $whereClause_range;
        @binds       = ($taxon_oid);
    }

    my $sql_scaffold_name = qq{
        select distinct scf.scaffold_oid, scf.scaffold_name, ss.seq_length,
         ss.gc_percent, scf.read_depth, ''
        from scaffold scf, scaffold_stats ss
        where scf.taxon = ?
        and scf.taxon = ss.taxon
        and scf.scaffold_oid = ss.scaffold_oid
        $whereClause
        $rclause
        $imgClause
        $orderClause
    };
    my $sql_scaffold_oid = qq{
        select distinct scf.scaffold_oid, scf.scaffold_name, ss.seq_length,
         ss.gc_percent, scf.read_depth, ''
        from scaffold scf, scaffold_stats ss
        where scf.taxon = ?
        and scf.taxon = ss.taxon
        and scf.scaffold_oid = ss.scaffold_oid
        $whereClause
        $rclause
        $imgClause
        $orderClause
   };

    #    my $sql_read_id = qq{
    #      select distinct scf.scaffold_oid, scf.scaffold_name, ss.seq_length,
    #         ss.gc_percent, scf.read_depth, rs.ext_accession
    #      from scaffold_stats ss, scaffold scf
    #      left join read_sequence rs
    #          on scf.scaffold_oid = rs.scaffold
    #      where scf.taxon = ?
    #      and scf.scaffold_oid = ss.scaffold_oid
    #      $whereClause
    #      $orderClause
    #   };
    my $sql = $sql_scaffold_name;

    #    $sql = $sql_read_id      if $searchType eq "read_id";
    $sql = $sql_scaffold_oid if $searchType eq "scaffold_oid";

    my $cur;

    #if ( $#binds > -1 ) {
    #    $cur = WebUtil::execSqlBind( $dbh, $sql, \@binds, $verbose );
    #} else {
    $cur = execSql( $dbh, $sql, $verbose, @binds );

    #}

    my $count = 0;
    my @recs;
    my $count = 0;
    my %scaffold2Bin;

    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name, $seq_length, $gc_percent, $read_depth, $read_id ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        my $r = "$scaffold_oid\t";
        $r .= "$scaffold_name\t";
        $r .= "$seq_length\t";
        $r .= "$gc_percent\t";
        $r .= "$read_depth\t";
        $r .= "$read_id\t";
        push( @recs, $r );
        $scaffold2Bin{$scaffold_oid} = "";
    }
    $cur->finish();

    # --es 12/15/2005 too slow
    #getScaffolds2Bins( $dbh, \%scaffold2Bin );
    if ( $count == 0 ) {
        print "No results found.<br/>\n";
        printStatusLine( "$count scaffold(s) retrieved.", 2 );

        #$dbh->disconnect();
        print end_form();
        return;
    }

    # order by scf.scaffold_oid, b.display_name
    my $sql = qq{
        select distinct scf.scaffold_oid, b.bin_oid, b.display_name
        from scaffold scf, bin_scaffolds bs, bin b, scaffold_stats ss
        where scf.taxon = ?
        and scf.scaffold_oid = bs.scaffold
        and scf.scaffold_oid = ss.scaffold_oid
        and bs.bin_oid = b.bin_oid
        and b.is_default = 'Yes'
        $whereClause_scaffold_name
        $rclause
        $imgClause
   };

    my $cur;
    if ( $whereClause_scaffold_name ne "" ) {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $searchTermLower );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    }

    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $scaffold2Bin{$scaffold_oid} = " $bin_display_name;";
    }
    $cur->finish();
    my $origCount = $count;
    my $count     = 0;

    my $itID = "ScaffoldSearch";
    my $it   = new InnerTable( 1, "$itID$$", $itID, 0 );
    my $sd   = $it->getSdDelim();                          # sort delimiter

    if ($scaffold_cart) {
        $it->addColSpec("Select");
    }
    $it->addColSpec( "Matching Scaffold",        "asc",  "left" );
    $it->addColSpec( "Sequence<br/>Length (bp)", "desc", "right" );
    $it->addColSpec( "GC",                       "desc", "right" );
    $it->addColSpec( "Read<br/>Depth",           "desc", "right" );
    my $trunc = 0;

    for my $r (@recs) {
        my ( $scaffold_oid, $scaffold_name, $seq_length, $gc_percent, $read_depth, $read_id ) = split( /\t/, $r );
        $count++;
        if ( $count >= $max_scaffold_results ) {
            $trunc = 1;
            last;
        }

        $gc_percent = sprintf( "%.2f", $gc_percent );
        $read_depth = sprintf( "%.2f", $read_depth );
        $read_depth = "-" if $read_depth == 0;
        $scaffold_name .= " ($read_id)" if $read_id ne "";

        my $row;
        if ($scaffold_cart) {
            $row .= $sd . "<input type='checkbox' name='scaffold_oid' " . "value='$scaffold_oid' />\t";
        }

        my $url = "$section_cgi&page=scaffolds";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&scaffold_oid=$scaffold_oid";

        #print alink( $url, $scaffold_name );
        my $x = highlightMatchHTML2( $scaffold_name, $searchTerm );
        $x = escHtml($scaffold_name) if blankStr($searchTerm);
        my $bin_display_names = $scaffold2Bin{$scaffold_oid};
        chop $bin_display_names;
        my $x2 = nbsp(1) . escHtml("(bin(s):$bin_display_names)")
          if $bin_display_names ne "";
        $row .= $x . $x2 . $sd . "<a href='$url'>$x</a>$x2" . "\t";
        $row .= ${seq_length} . $sd . ${seq_length} . "\t";
        $row .= ${gc_percent} . $sd . ${gc_percent} . "\t";
        $row .= ${read_depth} . $sd . ${read_depth} . "\t";
        $it->addRow($row);
    }

    printScaffoldCartButtons($itID) if ( $scaffold_cart && $count > 10 );
    $it->printOuterTable(1);

    if ($scaffold_cart) {
        print hiddenVar( "page",    "userScaffoldGraph" );
        print hiddenVar( "section", "ScaffoldGraph" );
        printScaffoldCartButtons($itID);

    }

    printStatusLine( "$count scaffold(s) retrieved.", 2 );

    #$dbh->disconnect();
    if ($trunc) {
        print "<p>\n";
        print "$count of $origCount result rows are shown.\n";
        print "Please enter narrow query conditions.\n";
        print "</p>\n";
    }
    print end_form();
}

############################################################################
# printScaffolds - Show list of scaffold on chromosome page.
############################################################################
sub printScaffolds {
    my $taxon_oid    = param("taxon_oid");
    my $scaffold_oid = param("scaffold_oid");
    my $sample       = param("sample");

    my $studies_str = param("study");
    my @studies     = split( ",", $studies_str );

    my $study = $studies_str;
    if ( $sample eq "" ) {
        $sample = param("exp_samples");
    }

    if ( $pageSize == 0 ) {
        webDie("printScaffolds: invalid pageSize='$pageSize'\n");
    }
    my $dbh = dbLogin();

    printMainForm();
    print "<h1>Chromosome Viewer</h1>\n";
    printStatusLine( "Loading ...", 1 );

    if ( $taxon_oid eq "" && $sample ne "" ) {
        my $in_file;
        my $sql;
        if ( $study eq "rnaseq" ) {
            $sql = qq{
                select dts.reference_taxon_oid, tx.in_file
                from rnaseq_dataset dts, taxon tx
                where dts.dataset_oid = ?
                and tx.taxon_oid = dts.reference_taxon_oid
            };
        } elsif ( $study eq "proteomics" ) {
            $sql = qq{
                select s.IMG_taxon_oid, tx.in_file
                from ms_sample s, taxon tx
                where s.sample_oid = ?
                and tx.taxon_oid = s.IMG_taxon_oid
            };
        } elsif ( $study eq "methylomics" ) {
            $sql = qq{
                select s.IMG_taxon_oid, tx.in_file
                from meth_sample s, taxon tx
                where s.sample_oid = ?
                and tx.taxon_oid = s.IMG_taxon_oid
            };
        }
        my $cur = execSql( $dbh, $sql, $verbose, $sample );
        ( $taxon_oid, $in_file ) = $cur->fetchrow();
        $cur->finish();

        if ( $in_file eq "Yes" ) {
            require MetaDetail;
            MetaDetail::printScaffolds();
            return;
        }
    }
    if ( $taxon_oid eq "" ) {
        webDie("printScaffolds: taxon_oid not specified");
    }

    my $scaffold_count = scaffoldCount( $dbh, $taxon_oid, $scaffold_oid );
    if ( $scaffold_count == 0 ) {
        print "<p>\n";
        if ( $scaffold_oid > 0 ) {
            print "This scaffold has no genes to display.\n";
        } else {
            print "This genome has no genes on scaffolds to display.\n";
        }
        print "</p>\n";
        return;
    }
    if ( $scaffold_count > $max_scaffold_list && $scaffold_oid eq "" ) {
        printScaffoldDistribution( $dbh, $taxon_oid );
        printScaffoldLengthDistribution( $dbh, $taxon_oid );
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $taxon_display_name = QueryUtil::fetchSingleTaxonName($dbh, $taxon_oid);

    print "<p>\n";
    print "Scaffolds and contigs for ";
    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_display_name );
    print "</p>\n";

    if ( $sample ne "" && $sample eq '0' && scalar @studies > 0 ) {
        print qq{
	    <script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
	    </script>

	    <script language='JavaScript' type='text/javascript'>
            function setStudy(study) {
            if (study) {
                for (var i=0; i<document.mainForm.elements.length; i++) {
                    var el = document.mainForm.elements[i];
                    if (el.type == "hidden") {
                        if (el.name == "study") {
                            el.value = study;
                        }
                    }
                }
            }
            }

	    function showView(type, study) {
            if (type == 'slim') {
                var els = document.getElementsByName('showsamples');
                for (var i=0; i<els.length; i++) {
                    var el = els[i];
                    if (!study || el.id == study) {
                        el.style.display = 'none';
                    }
                }
                var els = document.getElementsByName('hidesamples');
                for (var i=0; i<els.length; i++) {
                    var el = els[i];
                    if (!study || el.id == study) {
                        el.style.display = 'block';
                    }
                }
            } else {
                var els = document.getElementsByName('showsamples');
                for (var i=0; i<els.length; i++) {
                    var el = els[i];
                    if (!study || el.id == study) {
                        el.style.display = 'block';
                    }
                }
                var els = document.getElementsByName('hidesamples');
                for (var i=0; i<els.length; i++) {
                    var el = els[i];
                    if (!study || el.id == study) {
                        el.style.display = 'none';
                    }
                }
            }
            }

	    YAHOO.util.Event.onDOMReady(function () {
		showView('slim');
	    });
	    </script>
        };

        foreach my $study (@studies) {
            my $val = "Protein";
            if ( $study eq "rnaseq" ) {
                $val = "RNASeq";
            } elsif ( $study eq "methylomics" ) {
                $val = "Methylomics";
            }

            print "<div id='$study' name='hidesamples' style='display: block;'>";
            print "<input type='button' class='medbutton' name='view'"
		. " value='Select $val Samples'"
		. " onclick='showView(\"full\", \"$study\")' />";
            print "</div>\n";

            print "<div id='$study' name='showsamples' style='display: block;'>";
            print "<input type='button' class='medbutton' name='view'"
              . " value='Hide $val Samples'"
              . " onclick='showView(\"slim\", \"$study\")' />";

            print "<h2>$val Samples for Selected Genome</h2>\n";
            if ( $study eq "methylomics" ) {
                print "<p>Select a sample to mark the chromosome "
		    . "with methylation positions for that sample</p>";
            } else {
                print "<p>Select a sample to color the chromosome "
		    . "by expression values for that sample</p>";
            }

            if ( $study eq "rnaseq" ) {
                use RNAStudies;
                RNAStudies::printSelectOneSample($taxon_oid);
            } elsif ( $study eq "proteomics" ) {
                use IMGProteins;
                IMGProteins::printSelectOneSample($taxon_oid);
            } elsif ( $study eq "methylomics" ) {
                use Methylomics;
                Methylomics::printSelectOneSample($taxon_oid);
            }
            print "</div>\n";
        }
    }

    print "<h2>User Selectable Coordinates</h2>\n";
    printStatusLine( "Loading ...", 1 );

    my $taxon_rescale = getTaxonRescale( $dbh, $taxon_oid );
    webLog "$taxon_rescale=$taxon_rescale\n" if $verbose >= 2;
    $pageSize *= $taxon_rescale;

    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

    my $sql = qq{
        select count(*)
        from scaffold s
        where s.taxon = ?
        and s.ext_accession is not null
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $scaffoldCount0 = $cur->fetchrow();
    $cur->finish();

    ## Est. orfs
    my $sql = qq{
        select s.scaffold_oid, $nvl(s.count_total_gene, 0)
        from scaffold_stats s, gene g
        where g.scaffold = s.scaffold_oid
        and g.taxon = ?
        and g.obsolete_flag = 'No'
        and s.taxon = g.taxon
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my %scaffold2NoGenes;
    my %scaffold2Bin;
    my $count = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        $scaffold2NoGenes{$scaffold_oid} = $cnt;
        $scaffold2Bin{$scaffold_oid}     = "";
    }
    $cur->finish();
    if ( $count == 0 ) {
        print "<p>\n";
        print "This scaffold has no genes to view.\n";
        print "</p>\n";

        #$dbh->disconnect();
        return;
    }

    # --es too slow
    #getScaffolds2Bins( $dbh, \%scaffold2Bin );
    my $sql = qq{
        select s.scaffold_oid, b.bin_oid, b.display_name
        from scaffold s, bin_scaffolds bs, bin b
        where bs.scaffold = s.scaffold_oid
        and b.bin_oid = bs.bin_oid
        and s.taxon = ?
        and b.is_default = 'Yes'
        and s.ext_accession is not null
        $rclause
        $imgClause
        order by s.scaffold_oid, b.display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $scaffold2Bin{$scaffold_oid} = " $bin_display_name;";
    }
    $cur->finish();
    my $scaffoldCount1 = keys(%scaffold2NoGenes);
    webLog "scaffoldCount0=$scaffoldCount0\n" if $verbose >= 1;
    webLog "scaffoldCount1=$scaffoldCount1\n" if $verbose >= 1;

    ## clicking on the links for each scaffold calls this
    ## script to set the hidden vars before calling submit
    print qq{
        <script language="JavaScript" type="text/javascript">
        function dosubmit(scaffold_oid, start_coord, end_coord,
			  seq_length, sample, user) {
	    for (var i=0; i<document.mainForm.elements.length; i++) {
		var el = document.mainForm.elements[i];
		if (el.type == "hidden") {
		    if (el.name == "link_scaffold_oid") {
			el.value = scaffold_oid;
		    } else if (el.name == "start_coord") {
			el.value = start_coord;
		    } else if (el.name == "end_coord") {
			el.value = end_coord;
		    } else if (el.name == "seq_length") {
			el.value = seq_length;
		    } else if (el.name == "userEntered") {
			el.value = user;
		    } else if (el.name == "sample") {
			el.value = sample;
		    }
		    //alert("dosubmit: "+scaffold_oid+" "+sample+"  "+
		    //document.mainForm.elements[i].name+
		    //"="+document.mainForm.elements[i].value);
		}
	    }
            document.mainForm.submit();
        }
        </script>
    };

    if ( $sample ne "" ) {
        print hiddenVar( "sample", $sample );
        print hiddenVar( "study",  $studies_str );
    }

    # this is needed for "color by expression" (samples)
    # empty link_scaffold_oid is set by dosubmit function!
    print hiddenVar( "link_scaffold_oid", $scaffold_oid );
    print hiddenVar( "start_coord",       1 );
    print hiddenVar( "end_coord",         1 );
    print hiddenVar( "seq_length",        1 );
    print hiddenVar( "userEntered",       1 );

    my $scfClause;
    $scfClause = "and s.scaffold_oid = $scaffold_oid" if $scaffold_oid ne "";
    my $sql = qq{
    	select distinct s.scaffold_name, ss.seq_length,
    	       $nvl(ss.count_total_gene, 0),
               ss.gc_percent, s.read_depth,
       	       s.scaffold_oid, tx.taxon_display_name,
               s.mol_type, s.mol_topology
        from scaffold s, scaffold_stats ss, taxon tx
        where s.taxon = ?
        and s.taxon = ss.taxon
        and s.scaffold_oid = ss.scaffold_oid
        and s.taxon = tx.taxon_oid
  	and s.ext_accession is not null
    	$scfClause
        $rclause
        $imgClause
    	order by ss.seq_length desc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $itID = "scaffold";
    my $it   = new InnerTable( 1, "$itID$$", $itID, 1 );
    my $sd   = $it->getSdDelim();
    if ($scaffold_cart) {
        $it->addColSpec( "Select" );
    }
    $it->addColSpec( "Scaffold",    "asc",  "left" );
    $it->addColSpec( "Length (bp)", "desc", "right" );
    $it->addColSpec( "GC",          "desc", "right" );
    $it->addColSpec( "Type",        "asc",  "left" );
    $it->addColSpec( "Topology",    "asc",  "left" );
    $it->addColSpec( "Read Depth",  "desc", "right" ) if $include_metagenomes;
    $it->addColSpec( "No. Genes",   "desc", "right" );
    $it->addColSpec( "Coordinate Range" );

    my @scaffoldRecs;
    my $count;
    for ( ; ; ) {
        my ( $scaffold_name, $seq_length, $total_gene_count, $gc_percent,
	     $read_depth, $scaffold_oid, $taxon_display_name, $mol_type,
	     $mol_topology, undef ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $gc_percent = sprintf( "%.2f", $gc_percent );
        $read_depth = sprintf( "%.2f", $read_depth );
        $read_depth = "-" if $read_depth == 0;

        substr( $scaffold_name, length($taxon_display_name) );
        my $scaffold_name2    = WebUtil::getChromosomeName($scaffold_name);
        my $bin_display_names = $scaffold2Bin{$scaffold_oid};
        chop $bin_display_names;
        $scaffold_name2 .= " (bin(s):$bin_display_names)"
          if $bin_display_names ne "";
        my $rec = "$scaffold_oid\t";
        $rec .= "$scaffold_name2\t";
        $rec .= "$seq_length";
        push( @scaffoldRecs, $rec ) if $seq_length > 0;

        # select to add to scaffold cart
        my $r;
        if ($scaffold_cart) {
            $r .= $sd . "<input type='checkbox' name='scaffold_oid' " . "value='$scaffold_oid' />" . "\t";
        }

        $r .= $scaffold_name2 . $sd . attrLabel($scaffold_name2) . "\t";
        $r .= ${seq_length} . $sd . ${seq_length} . "\t";
        $r .= ${gc_percent} . $sd . ${gc_percent} . "\t";
        $r .= $mol_type . $sd . $mol_type . "\t";
        $r .= $mol_topology . $sd . $mol_topology . "\t";
        $r .= ${read_depth} . $sd . ${read_depth} . "\t"
          if $include_metagenomes;

        # gene count
        my $tmp = $scaffold2NoGenes{$scaffold_oid};
        if ( $tmp eq "" ) {
            $r .= "0" . $sd . "0" . "\t";
        } else {
            $r .= $tmp . $sd . $tmp . "\t";
        }

        if ( $seq_length < $pageSize ) {
            my $range = "1\.\.$seq_length";
            my $url   = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
            $url .= "&scaffold_oid=$scaffold_oid";
            $url .= "&start_coord=1&end_coord=$seq_length";
            if ( $sample ne "" ) {
                $url .= "&sample=$sample";
                $url .= "&study=$study";
            }
            if ( $seq_length > 0 ) {
                my $ss = $sample;
                $ss = -1 if ( $sample eq "" );
                if ( $study eq "rnaseq" ) {
                    $ss = "\'" . $sample . "\'";
                }
                my $func = "javascript:dosubmit($scaffold_oid, "
		         . "1, $seq_length, $seq_length, $ss, 0);";
                my $test = "<a href=\"$func\">$range</a>";
                $r .= $range . $sd . $test . "\t";
            } else {
                $r .= "" . $sd . nbsp(1) . "\t";
            }
        } else {
            my $tmp;
            my $last = 1;
            my $full_range;
            for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
                my $curr  = $i;
                my $range = "$last\.\.$curr";
                $full_range .= $range . " ";
                my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                $url .= "&scaffold_oid=$scaffold_oid";
                if ( $sample ne "" ) {
                    $url .= "&sample=$sample";
                    $url .= "&study=$study";
                }

                $url .= "&start_coord=$last&end_coord=$curr";
                $url .= "&seq_length=$seq_length";
                if ( $seq_length > 0 ) {
                    my $ss = $sample;
                    $ss = -1 if ( $sample eq "" );
                    if ( $study eq "rnaseq" ) {
                        $ss = "\'" . $sample . "\'";
                    }
                    my $func = "javascript:dosubmit($scaffold_oid, "
			     . "$last, $curr, $seq_length, $ss, 0);";
                    $tmp .= "<a href=\"$func\">$range</a><br/> ";
                } else {
                    $tmp .= nbsp(1);
                }
                $last = $curr + 1;
            }
            if ( $last < $seq_length ) {
                my $range = "$last\.\.$seq_length";
                $full_range .= $range;
                my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                $url .= "&scaffold_oid=$scaffold_oid";
                if ( $sample ne "" ) {
                    $url .= "&sample=$sample";
                    $url .= "&study=$study";
                }
                $url .= "&start_coord=$last&end_coord=$seq_length";
                if ( $seq_length > 0 ) {
                    my $ss = $sample;
                    $ss = -1 if ( $sample eq "" );
                    if ( $study eq "rnaseq" ) {
                        $ss = "\'" . $sample . "\'";
                    }
                    my $func = "javascript:dosubmit($scaffold_oid, "
			     . "$last, $seq_length, $seq_length, $ss, 0);";
                    $tmp .= "<a href=\"$func\">$range</a> ";
                } else {
                    $tmp .= nbsp(1);
                }
            }
            $r .= $full_range . $sd . $tmp . "\t";
        }
        $count++;
        $it->addRow($r);
    }

    printScaffoldCartButtons($itID) if ( $scaffold_cart && $count > 10 );
    $it->printOuterTable(1);

    printStatusLine( "Loaded.", 2 );
    $cur->finish();

    #$dbh->disconnect();
    if ( $scaffoldCount0 > $scaffoldCount1 ) {
        print "<p>\n";
        print "Only scaffolds with at least one ORF are shown here.\n";
        print "</p>\n";
    }

    if ($scaffold_cart) {
        print hiddenVar( "page",    "userScaffoldGraph" );
        print hiddenVar( "section", "ScaffoldGraph" );
        printScaffoldCartButtons($itID);
    }

    print "<br/>\n";
    print "<h2>User Enterable Coordinates</h2>\n";
    print "<p>\n";
    print "<select name='scaffold_oid_len' length='30'>\n";
    for my $r (@scaffoldRecs) {
        my ( $scaffold_oid, $scaffold_name, $seq_length ) = split( /\t/, $r );
        print "<option value='$scaffold_oid:$seq_length'>";
        print escHtml($scaffold_name) . nbsp(3);
        print "</option>\n";
    }
    print "</select>\n";
    print "Start ";
    print "<input type='text' name='start' size='10' />\n";
    print "End ";
    print "<input type='text' name='end' size='10' />\n";
    print "</p>\n";

    if ($img_internal) {
        print "<p>\n";
        print "Mark phantom gene coordinates in red (optional): ";
        print "Start ";
        print "<input type='text' name='phantom_start_coord' size='10' />\n";
        print "End ";
        print "<input type='text' name='phantom_end_coord' size='10' />\n";
        print "Strand ";
        print popup_menu(
            -name   => "phantom_strand",
            -values => [ "pos", "neg" ]
        );
        print " (experimental)";
        print "<br/>\n";
        print "</p>\n";
    }
    my $name = "_section_ScaffoldGraph_viewerScaffoldGraph";
    print submit(
        -name  => $name,
        -value => "Go",
        -class => "smdefbutton"
    );
    print nbsp(1);
    print "<input type='button' class='smbutton' value='Reset' "
	. "onclick='checkAll(0, oIMGTable_scaffold); reset();'>";

    printHint("WARNING: Some browsers may be overwhelmed by a large coordinate range.");
    print end_form();
}

############################################################################
# printScaffoldDistribution - Show distribution of scaffolds from
#   scaffolds with most genes to least.  Used as alternate presentation
#   if there are too many scaffolds.
############################################################################
sub printScaffoldDistribution {
    my ( $dbh, $taxon_oid ) = @_;
    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
    my $sql       = qq{
        select distinct ss.scaffold_oid, $nvl(ss.count_total_gene, 0)
        from scaffold_stats ss, scaffold scf
        where ss.taxon = ?
        and scf.taxon = ss.taxon
        and ss.scaffold_oid = scf.scaffold_oid
        and scf.ext_accession is not null
        and ss.seq_length > 0
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @recs;
    for ( ; ; ) {
        my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$scaffold_oid;
        my $r = "$cnt\t";
        $r .= "$scaffold_oid";
        push( @recs, $r );
    }
    $cur->finish();
    my %binCount;
    for my $r (@recs) {
        my ( $geneCountStr, $scaffold_oid ) = split( /\t/, $r );
        $binCount{$geneCountStr}++;
    }
    printMainForm();

    my $url = "$section_cgi&page=scaffoldsByGeneCount&taxon_oid=$taxon_oid";

    # PREPARE THE BAR CHART
    my $chart = newBarChart();
    $chart->WIDTH(450);
    $chart->HEIGHT(300);
    $chart->DOMAIN_AXIS_LABEL("Scaffolds having n genes");
    $chart->RANGE_AXIS_LABEL("Number of scaffolds");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL( $url . "&chart=y" );

    #$chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->COLOR_THEME("ORANGE");
    my @chartseries;
    my @chartcategories;
    my @chartdata;

    print "<h2>Scaffolds by Gene Count</h2>\n";
    print "<table width=780 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";
    print "The number of scaffolds is shown in parenthesis.\n";
    print "<p>\n";
    my @binKeys = reverse( sort { $a <=> $b } ( keys(%binCount) ) );
    for my $k (@binKeys) {
        my $nGenes = sprintf( "%d", $k );
        my $url2   = "$url&gene_count=$nGenes";
        my $binCnt = $binCount{$k};
        my $genes  = "genes";
        $genes = "gene" if $nGenes == 1;
        print "Scaffolds having $nGenes $genes ";
        print "(" . alink( $url2, $binCnt ) . ")<br/>\n";
        push @chartcategories, "$nGenes";
        push @chartdata,       $binCnt;
    }
    print "</td><td valign=top align=right>\n";

    # display the bar chart
    push @chartseries, "num scaffolds";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );
    print "<td align=right valign=center>\n";

    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html",
		  "printScaffoldDistribution", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/".$chart->FILE_PREFIX.".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    print "</td></tr>\n";
    print "</table>\n";

    printStatusLine( "Loaded", 2 );
    print end_form();
}

############################################################################
# printScaffoldLengthDistribution - Show distribution of scaffolds from
#   scaffolds with most genes to least.  Used as alternate presentation
#   if there are too many scaffolds.
############################################################################
sub printScaffoldLengthDistribution {
    my ( $dbh, $taxon_oid ) = @_;
    printStatusLine( "Loading ...", 1 );

    #         and ss.count_total_gene > 0
    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');
    my $sql       = qq{
        select distinct ss.scaffold_oid, ss.seq_length
        from scaffold_stats ss, scaffold scf
        where ss.taxon = ?
        and scf.taxon = ss.taxon
        and ss.scaffold_oid = scf.scaffold_oid
        and scf.ext_accession is not null
        and ss.seq_length > 0
        $rclause
        $imgClause
        order by ss.seq_length asc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @recs;
    my $minlength = -1;
    my $maxlength = 0;

    for ( ; ; ) {
        my ( $scaffold_oid, $seqlength ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $minlength = $seqlength if ( $minlength == -1 );
        $maxlength = $seqlength;
        push( @recs, $seqlength );
    }
    $cur->finish();

    my $url = "$section_cgi&page=scaffoldsByLengthCount&taxon_oid=$taxon_oid";

    printMainForm();
    print "<h2>Scaffolds by Sequence Length</h2>\n";
    print "<table width=780 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";
    print "The number of scaffolds having genes is shown in parenthesis.\n";
    print "<p>\n";
    my $url2 = "$url&scf_length=$minlength-$maxlength";

    # PREPARE THE BAR CHART
    my $chart = newBarChart();
    $chart->WIDTH(450);
    $chart->HEIGHT(300);
    $chart->DOMAIN_AXIS_LABEL("Scaffold length");
    $chart->RANGE_AXIS_LABEL("Number of scaffolds");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL( $url . "&chart=y" );
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->COLOR_THEME("ORANGE");
    my @chartseries;
    my @chartcategories;
    my @chartdata;

    # EQUAL WIDTH BINS
    my $numbins   = 10;
    my $width     = $maxlength - $minlength + 1;
    my $binsize   = $width / $numbins;
    my $idx       = 0;
    my $lastupper = -1;
    for ( my $i = 0 ; $i < $numbins ; $i++ ) {
        my $lower = $minlength + ( $binsize * $i );
        $lower = floor($lower);
        my $upper = $lower + $binsize;
        $upper = floor($upper);
        if ( $lastupper == $lower ) {
            $lower++;
        }
        $lastupper = $upper;
        my $bincount = 0;
        for ( ; ; ) {
            my $rec = $recs[$idx];
            if ( $lower <= $rec && $rec <= $upper ) {
                $bincount++;
                $idx++;
            } else {
                last;
            }
        }
        my $url2 = "$url&scf_length=$lower-$upper";
        push @chartcategories, "$lower..$upper";
        push @chartdata,       $bincount;
        if ( $bincount == 0 ) {
            print "Scaffold length between $lower .. $upper (0)\n<br>";
        } else {
            print "Scaffold length between $lower .. $upper (" . alink( $url2, $bincount ) . ")\n<br>";
        }
    }
    print "</td>\n";

    # display the bar chart
    push @chartseries, "num scaffolds";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );
    print "<td align=right valign=top>\n";

    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html",
		  "printScaffoldLengthDistribution", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/".$chart->FILE_PREFIX.".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    print "</td>\n";
    print "</tr>\n";
    print "</table>\n";

    printStatusLine( "Loaded", 2 );
    print end_form();
}

############################################################################
# printScaffoldsByGeneCount - Show scaffolds with one value of gene count.
#   Drill down from above distribution of scaffolds.
############################################################################
sub printScaffoldsByLengthCount {
    my $taxon_oid  = param("taxon_oid");
    my $scf_length = param("scf_length");
    my $chart      = param("chart");

    # if this is invoked by the bar chart, then pre-process URL
    if ( $chart eq "y" ) {
        my $category = param("category");
        $category =~ s/\.\./-/g;
        $scf_length = $category;
    }

    my $dbh                = dbLogin();
    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h1>\n";
    print "Chromosome Viewer";
    print "</h1>\n";
    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_display_name );
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my ( $minlength, $maxlength ) = split( "-", $scf_length );

    my $rclause   = WebUtil::urClause('scf.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('scf.taxon');

    # updated query 2009-12-4 ken as printScaffoldLengthDistribution()
    #         and ss.count_total_gene > 0
    #        order by ss.scaffold_oid
    my $sql = qq{
        select distinct ss.scaffold_oid, ss.seq_length
        from scaffold_stats ss, scaffold scf
        where ss.taxon = ?
        and ss.seq_length >= ?
        and ss.seq_length <= ?
        and scf.taxon = ss.taxon
        and ss.scaffold_oid = scf.scaffold_oid
        and scf.ext_accession is not null
        and ss.seq_length > 0
        $rclause
        $imgClause
   };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $minlength, $maxlength );
    my @scaffold_oids;

    my %scaffold2Bin;
    for ( ; ; ) {
        my ( $scaffold_oid, $scf_length ) = $cur->fetchrow();
        last if !$scaffold_oid;

        push( @scaffold_oids, $scaffold_oid );
        $scaffold2Bin{$scaffold_oid} = "";
    }
    $cur->finish();

    # oracle util temp table
    my $scaffold_list_str;
    my $scaffold_clause;
    my %scaffold_oids_hash;
    my $found = 0;
    if ( OracleUtil::useTempTable( scalar(@scaffold_oids) ) ) {

        #OracleUtil::insertDataArray( $dbh, "gtt_num_id",
        #                             \@scaffold_oids );
        #$scaffold_clause = "and s.scaffold_oid in( select id from  gtt_num_id)";
        $scaffold_clause = "";
        foreach my $id (@scaffold_oids) {
            $scaffold_oids_hash{$id} = "";
        }
        $found = 1;
    } else {
        $scaffold_list_str = join( ',', @scaffold_oids );
        $scaffold_clause   = "and s.scaffold_oid in( $scaffold_list_str ) ";
        $found             = 1;
    }

    if ( !$found ) {

        #$dbh->disconnect();
        print "<p>\n";
        print "No scaffolds found.<br/>\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    ## --es too slow
    #         order by scf.scaffold_oid, b.display_name
    my $sql = qq{
        select scf.scaffold_oid, b.bin_oid, b.display_name
        from scaffold scf, bin_scaffolds bs, bin b
        where scf.taxon = ?
        and bs.scaffold = scf.scaffold_oid
        and bs.bin_oid = b.bin_oid
        and b.is_default = 'Yes'
        $rclause
        $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $scaffold2Bin{$scaffold_oid} = " $bin_display_name;";
    }
    $cur->finish();

    my $subtitle = "Scaffolds having genes with length between $scf_length\n";

    my $scaffold_count = $#scaffold_oids + 1;
    _printScaffoldsByCount( $dbh, $subtitle, $scaffold_clause, \%scaffold2Bin, $scaffold_count, \%scaffold_oids_hash );

    #$dbh->disconnect();
}

############################################################################
# printScaffoldsByGeneCount - Show scaffolds with one value of gene count.
#   Drill down from above distribution of scaffolds.
############################################################################
sub printScaffoldsByGeneCount {
    my $taxon_oid  = param("taxon_oid");
    my $gene_count = param("gene_count");
    my $chart      = param("chart");

    # if this is invoked by the bar chart, then pre-process URL
    if ( $chart eq "y" ) {
        my $category = param("category");
        $gene_count = $category;
    }

    if ( $pageSize == 0 ) {
        webDie("printScaffoldsByGeneCount: invalid pageSize='$pageSize'\n");
    }
    my $dbh = dbLogin();

    my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );

    print "<h1>\n";
    print "Chromosome Viewer";
    print "</h1>\n";
    print "<p>\n";
    print escHtml($taxon_display_name);
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

    # update query to get new data
    #        order by ss.scaffold_oid
    my $sql = qq{
        select s.scaffold_oid, $nvl(s.count_total_gene, 0)
        from scaffold_stats s
        where s.taxon = ?
        and $nvl(s.count_total_gene, 0) = ?
        and s.seq_length > 0
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $gene_count );
    my @scaffold_oids;

    #my $count = 0;
    my %scaffold2Bin;

    #my $trunc = 0;
    for ( ; ; ) {
        my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$scaffold_oid;
        next if $cnt != $gene_count;

        #        $count++;
        if ( $cnt != $gene_count ) {
            webLog "printScaffoldsByGeneCount: count mismatch " . "$cnt / $gene_count\n";
        }

        #        if ( $count > $max_scaffold_list2 ) {
        #            webLog "printScaffoldsByGeneCount: too many scaffolds: "
        #              . "max. set to $max_scaffold_list2\n";
        #            $trunc = 1;
        #            last;
        #        }
        push( @scaffold_oids, $scaffold_oid );
        $scaffold2Bin{$scaffold_oid} = "";
    }
    $cur->finish();
    ## --es too slow
    #         order by scf.scaffold_oid, b.display_name
    my $sql = qq{
        select s.scaffold_oid, b.bin_oid, b.display_name
        from scaffold s, bin_scaffolds bs, bin b
        where s.taxon = ?
        and bs.scaffold = s.scaffold_oid
        and bs.bin_oid = b.bin_oid
        and b.is_default = 'Yes'
        $rclause
        $imgClause
   };

    # --es too slow
    #getScaffolds2Bins( $dbh, \%scaffold2Bin );
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $scaffold_oid, $bin_oid, $bin_display_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $scaffold2Bin{$scaffold_oid} = " $bin_display_name;";
    }
    $cur->finish();

    # oracle util temp table
    my $scaffold_list_str = OracleUtil::getNumberIdsInClause( $dbh, @scaffold_oids );
    my $scaffold_clause   = "and s.scaffold_oid in( $scaffold_list_str ) ";

    if ( blankStr($scaffold_clause) ) {

        #$dbh->disconnect();
        print "<p>\n";
        print "No scaffolds found.<br/>\n";
        print "</p>\n";

        #printStatusLine( "Loaded.", 2 );  # this is followed by the LengthCount, so don't display this
        return;
    }

    my $subtitle       = "Scaffolds having $gene_count genes\n";
    my $scaffold_count = $#scaffold_oids + 1;

    _printScaffoldsByCount( $dbh, $subtitle, $scaffold_clause, \%scaffold2Bin, $scaffold_count );

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $scaffold_list_str =~ /gtt_num_id/i );

    #$dbh->disconnect();
}
############################################################################
# printScaffoldsByCount - to be invoked by the GeneCount or LengthCount sub
############################################################################
sub _printScaffoldsByCount {
    my ( $dbh, $subtitle, $scaffold_clause, $scaffold2Bin_href, $max_scaffold_count, $scaffold_oids_href ) = @_;
    my $trunc     = 0;
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h2>User Selectable Coordinates</h2>\n";
    print "<p>\n";
    print "$subtitle\n";
    print "</p>\n";

    my $itID = "scaffold";
    my $it   = new InnerTable( 1, "itID$$", $itID, 1 );
    my $sd   = $it->getSdDelim();                         # sort delimiter
    if ($scaffold_cart) {
        $it->addColSpec("Select");
    }
    $it->addColSpec( "Scaffold",    "char asc",    "left" );
    $it->addColSpec( "Length (bp)", "number desc", "right" );
    $it->addColSpec( "GC",          "number desc", "right" );
    $it->addColSpec( "Type",        "char asc",    "left" );
    $it->addColSpec( "Topology",    "char asc",    "left" );
    $it->addColSpec( "Read Depth",  "number desc", "right" )
      if $include_metagenomes;
    $it->addColSpec( "No. Genes", "number desc", "right" );
    $it->addColSpec("Coordinate Range");

    my @scaffoldRecs;

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select distinct s.scaffold_name, ss.seq_length, ss.count_total_gene,
        ss.gc_percent, s.read_depth, s.scaffold_oid, tx.taxon_display_name,
        s.mol_type, s.mol_topology
        from scaffold s,  scaffold_stats ss, taxon tx
        where s.taxon = ?
        and s.taxon = ss.taxon
        and s.scaffold_oid = ss.scaffold_oid
        and s.taxon = tx.taxon_oid
        $scaffold_clause
        $rclause
        $imgClause
        order by ss.seq_length desc
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    for ( ; ; ) {
        my (
            $scaffold_name, $seq_length,         $total_gene_count, $gc_percent,   $read_depth,
            $scaffold_oid,  $taxon_display_name, $mol_type,         $mol_topology, undef
          )
          = $cur->fetchrow();
        last if !$scaffold_oid;

        if ( $scaffold_oids_href ne "" ) {
            my $size = keys %$scaffold_oids_href;
            next
              if ( $size > 0 && !exists $scaffold_oids_href->{$scaffold_oid} );
        }

        $count++;

        #  how to fix the 10000 limit
        #        if ( $count > $max_scaffold_list2 ) {
        #            webLog "printScaffoldsByGeneCount: too many scaffolds: "
        #              . "max. set to $max_scaffold_list2\n";
        #            $trunc = 1;
        #            last;
        #        }

        $gc_percent = sprintf( "%.2f", $gc_percent );
        $read_depth = sprintf( "%.2f", $read_depth );
        $read_depth = "-" if $read_depth == 0;
        my $scaffold_name2    = WebUtil::getChromosomeName($scaffold_name);
        my $bin_display_names = $scaffold2Bin_href->{$scaffold_oid};
        chop $bin_display_names;
        $scaffold_name2 .= " (bin(s):$bin_display_names)"
          if $bin_display_names ne "";
        my $rec = "$scaffold_oid\t";
        $rec .= "$scaffold_name2\t";
        $rec .= "$seq_length\t";
        push( @scaffoldRecs, $rec );

        # select to add to scaffold cart?
        my $r;
        if ($scaffold_cart) {
            $r .= $sd . "<input type='checkbox' name='scaffold_oid' " . "value='$scaffold_oid' />" . "\t";
        }

        $r .= $scaffold_name2 . $sd . attrLabel($scaffold_name2) . "\t";
        $r .= ${seq_length} . $sd . ${seq_length} . "\t";
        $r .= ${gc_percent} . $sd . ${gc_percent} . "\t";
        $r .= $mol_type . $sd . $mol_type . "\t";
        $r .= $mol_topology . $sd . $mol_topology . "\t";
        $r .= ${read_depth} . $sd . ${read_depth} . "\t"
          if $include_metagenomes;

        $total_gene_count = 0 if ( $total_gene_count eq "" );
        $r .= $total_gene_count . $sd . $total_gene_count . "\t";

        if ( $seq_length < $pageSize ) {
            my $range = "1\.\.$seq_length";
            my $url   = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
            $url .= "&scaffold_oid=$scaffold_oid";
            $url .= "&start_coord=1&end_coord=$seq_length";
            $r   .= $range . $sd . alink( $url, $range ) . "\t";

        } else {
            my $tmp;
            my $last = 1;
            for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
                my $curr  = $i;
                my $range = "$last\.\.$curr";
                my $url   = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                $url .= "&scaffold_oid=$scaffold_oid";
                $url .= "&start_coord=$last&end_coord=$curr";
                $url .= "&seq_length=$seq_length";

                $tmp .= alink( $url, $range ) . "<br/> ";
                $last = $curr + 1;
            }
            if ( $last < $seq_length ) {
                my $range = "$last\.\.$seq_length";
                my $url   = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
                $url .= "&scaffold_oid=$scaffold_oid";
                $url .= "&start_coord=$last&end_coord=$seq_length";

                $tmp .= alink( $url, $range ) . " ";
            }
            $r .= $sd . $tmp . "\t";
        }

        $it->addRow($r);
    }

    printScaffoldCartButtons($itID) if ( $scaffold_cart && $count > 10 );
    $it->printOuterTable(1);
    printScaffoldCartButtons($itID) if $scaffold_cart;

    print "<br/>\n";
    print "<h2>User Enterable Coordinates</h2>\n";
    print "<p>";
    print "<select name='scaffold_oid_len' length='30'>\n";
    for my $r (@scaffoldRecs) {
        my ( $scaffold_oid, $scaffold_name, $seq_length ) = split( /\t/, $r );
        print "<option value='$scaffold_oid:$seq_length'>";
        print escHtml($scaffold_name) . nbsp(3);
        print "</option>\n";
    }
    print "</select>\n";
    print "Start ";
    print "<input type='text' name='start_coord' size='10' />\n";
    print "End ";
    print "<input type='text' name='end_coord' size='10' />\n";
    print "</p>\n";
    my $name = "_section_ScaffoldGraph_userScaffoldGraph";
    print submit(
        -name  => $name,
        -value => "Go",
        -class => "smdefbutton"
    );
    print nbsp(1);
    print "<input type='button' class='smbutton' value='Reset' " . "onclick='checkAll(0, oIMGTable_scaffold); reset();'>";
    printHint( "WARNING: Some browsers may be overwhelmed by a large " . "coordinate range." );

    $cur->finish();

    print end_form();
    if ($trunc) {
        print "<p>\n";
        print "<font color='red'>\n";
        print escHtml(
            "Scaffold list truncated to $max_scaffold_list2 " . "scaffolds to keep from overwhelming the browser." );
        print "</font>\n";
        print "</p>\n";
        printStatusLine( "$max_scaffold_list2 of $max_scaffold_count Loaded.", 2 );
    } else {
        printStatusLine( "$count Loaded.", 2 );
    }
}

###########################################################################
# printScaffoldCartButtons - Print Add to Scaffold Cart and
#                            Select All, Clear All buttons
###########################################################################
sub printScaffoldCartButtons {
    require ScaffoldCart;
    ScaffoldCart::printValidationJS();

    my $name = "_section_ScaffoldCart_addToScaffoldCart";
    print submit(
        -name    => $name,
        -value   => "Add to Scaffold Cart",
        -class   => "meddefbutton",
        -onClick => "return validateSelection(1);"
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
}

############################################################################
# printDbScaffoldGenes: scaffold genes (from database)
#   Inputs:
#     scaffold_oid - scaffold object identifier
############################################################################
sub printDbScaffoldGenes {
    my $scaffold_oid = param("scaffold_oid");
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>Genes in Scaffold</h1>\n";
    print hiddenVar( "scaffold_oid", $scaffold_oid );

    my $dbh = dbLogin();

    if ( ! $taxon_oid ) {
        my $sql = QueryUtil::getSingleScaffoldTaxonSql();
        my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
        my $scf_ext_accession;
        ( $taxon_oid, $scf_ext_accession ) = $cur->fetchrow();
        $cur->finish();
    }
    print hiddenVar( "taxon_oid", $taxon_oid );

    # get taxon name from database
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    my $scf_url = "$main_cgi?section=ScaffoldCart"
          . "&page=scaffoldDetail&scaffold_oid=$scaffold_oid";
    print "<p>Scaffold: " . alink($scf_url, $scaffold_oid) . "</p>\n";

    my $sql = qq{
        select g.gene_oid, g.locus_type, g.locus_tag, g.gene_display_name,
        g.start_coord, g.end_coord, g.strand
        from gene g
        where g.scaffold = ?
        and g.obsolete_flag = 'No'
        order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "left"  );
    $it->addColSpec( "Locus Type",        "asc", "left"  );
    $it->addColSpec( "Locus Tag",         "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "Start Coord",       "asc", "right" );
    $it->addColSpec( "End Coord",         "asc", "right" );
    $it->addColSpec( "Strand",            "asc", "left"  );

    my $select_id_name = "gene_oid";

    my $gene_count = 0;
    my $trunc      = 0;
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $locus_type, $gene_name, $start_coord, $end_coord, $strand ) = $cur->fetchrow();
        last if !$gene_oid;

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$gene_oid' />" . "\t";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= $locus_type . $sd . $locus_type . "\t";
        $r .= $locus_tag . $sd . $locus_tag . "\t";
        $r .= $gene_name . $sd . $gene_name . "\t";
        $r .= $start_coord . $sd . $start_coord . "\t";
        $r .= $end_coord . $sd . $end_coord . "\t";
        $r .= $strand . $sd . $strand . "\t";

        $it->addRow($r);
        $gene_count++;
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( $gene_count == 0 ) {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
        print end_form();
        return;
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllDbScafGenes($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
    }

    print end_form();
}


############################################################################
# printOrthologClusters - Show ortholog clusters.
############################################################################
sub printOrthologClusters {
    my $taxon_oid = param("taxon_oid");

    print "<h1>Genes in Ortholog Clusters</h1>\n";
    printMainForm();
    print "<p>\n";
    print "Cluster names are assigned tentatively from most frequently occurring gene name.<br/>\n";
    print "The number of genes in each cluster is shown.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('tc.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('tc.taxon_oid');
    my $sql       = qq{
        select count(*)
        from dt_taxon_bbh_cluster tc
        where tc.taxon_oid = ?
        $rclause
        $imgClause
   };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();

    if ( $cnt == 0 ) {

        my $rclause1   = WebUtil::urClause('g.taxon');
        my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql        = qq{
            select distinct mg.member_genes
            from bbh_cluster_member_genes mg, gene g
            where mg.member_genes = g.gene_oid
            and g.taxon = $taxon_oid
            and g.obsolete_flag = 'No'
            $rclause1
            $imgClause1
        };

        HtmlUtil::printGeneListSection( $sql, "Genes as Orthologs" );
        return;
    }

    my $sql = qq{
        select tc.cluster_id, tc.cluster_name,
            count( distinct bbhg.member_genes )
        from dt_taxon_bbh_cluster tc, bbh_cluster_member_genes bbhg
        where tc.taxon_oid =  ?
            and tc.cluster_id = bbhg.cluster_id
            $rclause
            $imgClause
        group by tc.cluster_id, tc.cluster_name
        having count( distinct bbhg.member_genes ) > 1
        order by tc.cluster_id, tc.cluster_name
   };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    my @recs;

    for ( ; ; ) {
        my ( $cluster_id, $cluster_name, $gene_count ) = $cur->fetchrow();
        last if !$cluster_id;
        my $r = sprintf( "%06d", $gene_count ) . "\t";
        $r .= "$cluster_id\t";
        $r .= "$cluster_name";
        push( @recs, $r );
    }
    $cur->finish();

    my $it = new InnerTable( 1, "clusterlist$$", "clusterlist", 2 );
    $it->addColSpec( "Cluster ID",   "number asc",  "right" );
    $it->addColSpec( "Cluster Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );
    my $sd = $it->getSdDelim();

    my @recs2 = reverse( sort(@recs) );
    for my $r (@recs2) {
        my ( $gene_count, $cluster_id, $cluster_name ) = split( /\t/, $r );
        my $gene_count2 = sprintf( "%d", $gene_count );
        $count++;
        my $url = "$section_cgi&page=orthologClusterGeneList" . "&cluster_id=$cluster_id";
        my $r;
        $r .= $cluster_id . $sd . $cluster_id . "\t";
        $r .= $cluster_name . $sd . escHtml($cluster_name) . "\t";
        $r .= $gene_count2 . $sd . alink( $url, $gene_count2 ) . "\t";
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    print "</p>\n";

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    printStatusLine( "$count ortholog clusters retrieved.", 2 );
    print end_form();
}

############################################################################
# printOrthologClusterGeneList - Show genes under one cluster.
############################################################################
sub printOrthologClusterGeneList {
    my $cluster_id = param("cluster_id");

    print "<h1>\n";
    print "IMG Ortholog Cluster Genes\n";
    print "</h1>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from bbh_cluster_member_genes bbhg, gene g
        where bbhg.cluster_id = ?
        and bbhg.member_genes = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
    my $count = 0;
    my @gene_oids;

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "Genome ID",         "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left"  );

    print "<p>\n";
    my $count = 0;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it, 1 );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    #print "<div id='status'>\n";
    #print "$count gene(s) retrieved.\n";
    #print "</div>\n";
    print "</p>\n";

    #$dbh->disconnect();
    printStatusLine( "$count gene(s) retrieved.", 2 );

    if ( $user_restricted_site && !$no_restricted_message ) {
        print "<p>\n";
        print "<font color='red'>\n";
        print "Orthologs cluster genes listed here are restricted by\n";
        print "genomes access.<br/>\n";
        print "</font>\n";
        print "</p>\n";
    }
    print end_form();

}

############################################################################
# printImgClusters - Show IMG clusters.
############################################################################
sub printImgClusters {
    my $taxon_oid = param("taxon_oid");

    print "<h1>Genes in IMG Clusters</h1>\n";
    printMainForm();
    print "<p>\n";
    print "Cluster names are assigned tentatively from most frequently occurring gene name.<br/>\n";
    print "The number of genes in each cluster is shown.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select count( distinct gic.gene_oid )
        from gene g, gene_img_clusters gic
        where g.taxon = ?
        and g.gene_oid = gic.gene_oid
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();

    if ( $cnt == 0 ) {
        my $sql = qq{
            select distinct g.gene_oid
            from gene_img_clusters gic, gene g
            where gic.gene_oid = g.gene_oid
            and g.taxon = $taxon_oid
            and g.obsolete_flag = 'No'
            $rclause
            $imgClause
        };
        HtmlUtil::printGeneListSection( $sql, "Genes as IMG Clusters" );
        return;
    }
    my $sql = qq{
        select ic.cluster_id, ic.cluster_name,
          count( distinct gic.gene_oid )
        from img_cluster ic, gene_img_clusters gic, gene g
        where g.taxon =  ?
        and g.gene_oid = gic.gene_oid
        and gic.cluster_id = ic.cluster_id
        $rclause
        $imgClause
        group by ic.cluster_id, ic.cluster_name
        having count( distinct gic.gene_oid ) > 1
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    my @recs;
    for ( ; ; ) {
        my ( $cluster_id, $cluster_name, $gene_count ) = $cur->fetchrow();
        last if !$cluster_id;
        my $r = sprintf( "%06d", $gene_count ) . "\t";
        $r .= "$cluster_id\t";
        $r .= "$cluster_name";
        push( @recs, $r );
    }
    $cur->finish();

    my $it = new InnerTable( 1, "clusterlist$$", "clusterlist", 2 );
    $it->addColSpec( "Cluster ID",   "number asc",  "right" );
    $it->addColSpec( "Cluster Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );
    my $sd    = $it->getSdDelim();
    my @recs2 = reverse( sort(@recs) );
    for my $r (@recs2) {
        my ( $gene_count, $cluster_id, $cluster_name ) = split( /\t/, $r );
        my $gene_count2 = sprintf( "%d", $gene_count );
        $count++;
        my $url = "$section_cgi&page=imgClusterGeneList" . "&cluster_id=$cluster_id&taxon_oid=$taxon_oid";
        my $r;
        $r .= $cluster_id . $sd . $cluster_id . "\t";
        $r .= $cluster_name . $sd . escHtml($cluster_name) . "\t";
        $r .= $gene_count2 . $sd . alink( $url, $gene_count2 ) . "\t";
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    print "</p>\n";

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    printStatusLine( "$count ortholog clusters retrieved.", 2 );
    print end_form();
}

############################################################################
# printImgClusterGeneList - Show genes under one cluster.
############################################################################
sub printImgClusterGeneList {
    my $cluster_id = param("cluster_id");
    my $taxon_oid  = param("taxon_oid");

    print "<h1>\n";
    print "IMG Cluster Genes ($cluster_id)\n";
    print "</h1>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene_img_clusters gic, gene g
        where gic.cluster_id = ?
        and gic.gene_oid = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        $rclause
        $imgClause
        order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id, $taxon_oid );
    my $count = 0;
    my @gene_oids;

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "Genome ID",         "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left"  );

    print "<p>\n";
    my $count = 0;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it, 1 );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    #print "<div id='status'>\n";
    #print "$count gene(s) retrieved.\n";
    #print "</div>\n";
    print "</p>\n";

    #$dbh->disconnect();
    printStatusLine( "$count gene(s) retrieved.", 2 );

    if ( $user_restricted_site && !$no_restricted_message ) {
        print "<p>\n";
        print "<font color='red'>\n";
        print "IMG cluster genes listed here are restricted by\n";
        print "genomes access.<br/>\n";
        print "</font>\n";
        print "</p>\n";
    }
    print end_form();

}

############################################################################
# printHomologClusterGeneList - Show genes under one cluster.
############################################################################
#sub printHomologClusterGeneList {
#    my $cluster_id = param("cluster_id");
#
#    my $dbh = dbLogin();
#    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
#    my $rclause = urClause("g.taxon");
#    my $sql     = qq{
#       select distinct g.gene_oid
#       from dt_homolog_group hg,  dt_homolog_group_genes hgg, gene g
#       where hg.cluster_id = hgg.cluster_id
#       and hgg.gene_oid = g.gene_oid
#       and hg.cluster_id = ?
#       and g.locus_type = 'CDS'
#       and g.obsolete_flag = 'No'
#       $rclause
#   };
#    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
#    my $count = 0;
#    my @gene_oids;
#    printMainForm();
#    print "<h1>\n";
#    print "Homolog Cluster Genes\n";
#    print "</h1>\n";
#    WebUtil::printGeneCartFooter();
#
#    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
#    $it->addColSpec("Select");
#    $it->addColSpec( "Gene ID",    "number asc", "right" );
#    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
#    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
#    $it->addColSpec( "Genome ID",    "number asc", "right" );
#    $it->addColSpec( "Genome Name",       "char asc",   "left" );
#    print "<p>\n";
#    my $count = 0;
#    for ( ; ; ) {
#        my ($gene_oid) = $cur->fetchrow();
#        last if !$gene_oid;
#        $count++;
#        push( @gene_oids, $gene_oid );
#    }
#    $cur->finish();
#    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it, 1 );
#    $it->printOuterTable(1);
#    print "<br/>\n";
#
#    #print "<div id='status'>\n";
#    #print "$count gene(s) retrieved.\n";
#    #print "</div>\n";
#    print "</p>\n";
#    #$dbh->disconnect();
#    printStatusLine( "$count gene(s) retrieved.", 2 );
#
#    WebUtil::printGeneCartFooter() if $count > 10;
#    if ( $user_restricted_site && !$no_restricted_message ) {
#        print "<p>\n";
#        print "<font color='red'>\n";
#        print "Homolog cluster genes listed here are restricted by\n";
#        print "genomes access.<br/>\n";
#        print "</font>\n";
#        print "</p>\n";
#    }
#    print end_form();
#}

############################################################################
# printSuperClusterGeneList - Show genes under one cluster.
############################################################################
sub printSuperClusterGeneList {
    my $cluster_id = param("cluster_id");

    return;

    #    my $dbh = dbLogin();
    #    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    #    my $rclause = urClause("g.taxon");
    #    my $sql     = qq{
    #       select distinct g.gene_oid
    #       from dt_super_cluster_genes scg, gene g
    #       where scg.cluster_id = ?
    #       and scg.gene_oid = g.gene_oid
    #       and g.locus_type = 'CDS'
    #       and g.obsolete_flag = 'No'
    #       $rclause
    #   };
    #    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
    #    my $count = 0;
    #    my @gene_oids;
    #    printMainForm();
    #    print "<h1>\n";
    #    print "Native Cluster Genes\n";
    #    print "</h1>\n";
    #    print "<p>\n";
    #    print "Native clusters combine ortholog groups, based on bidirectional ";
    #    print "best hits, and paralog groups into super clusters.<br/>\n";
    #    print "</p>\n";
    #    WebUtil::printGeneCartFooter();
    #    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    #    $it->addColSpec("Select");
    #    $it->addColSpec( "Gene ID",    "number asc", "right" );
    #    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    #    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    #    $it->addColSpec( "Genome ID",    "number asc", "right" );
    #    $it->addColSpec( "Genome Name",       "char asc",   "left" );
    #    print "<p>\n";
    #    my $count = 0;
    #
    #    for ( ; ; ) {
    #        my ($gene_oid) = $cur->fetchrow();
    #        last if !$gene_oid;
    #        $count++;
    #        push( @gene_oids, $gene_oid );
    #    }
    #    $cur->finish();
    #    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it, 1 );
    #    $it->printOuterTable(1);
    #    print "<br/>\n";
    #
    #    #print "<div id='status'>\n";
    #    #print "$count gene(s) retrieved.\n";
    #    #print "</div>\n";
    #    print "</p>\n";
    #    #$dbh->disconnect();
    #    printStatusLine( "$count gene(s) retrieved.", 2 );
    #    WebUtil::printGeneCartFooter() if $count > 10;
    #    if ( $user_restricted_site && !$no_restricted_message ) {
    #        print "<p>\n";
    #        print "<font color='red'>\n";
    #        print "Super cluster genes listed here are restricted by\n";
    #        print "genomes access.<br/>\n";
    #        print "</font>\n";
    #        print "</p>\n";
    #    }
    #    print end_form();
}

############################################################################
# printMclClusters - Show ortholog clusters.
############################################################################
#sub printMclClusters {
#    my $taxon_oid = param("taxon_oid");
#
#    my $dbh = dbLogin();
#    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
#    my $sql = qq{
#       select mc.cluster_id, mc.cluster_name,
#          count( distinct g.gene_oid )
#       from mcl_cluster mc, gene_mcl_clusters gmc, gene g
#       where mc.cluster_id = gmc.mcl_cluster
#       and gmc.gene_oid = g.gene_oid
#       and g.gene_oid = g.taxon
#       and g.taxon = ?
#       and g.locus_type = 'CDS'
#       and g.obsolete_flag = 'No'
#       group by mc.cluster_id, mc.cluster_name
#       order by mc.cluster_id, mc.cluster_name
#   };
#    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
#    my $count = 0;
#    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
#    printMainForm();
#    print "<h1>Curated MCL Clusters</h1>\n";
#    print "<p>\n";
#    print "The number of genes in each cluster is shown in parentheses.<br/>\n";
#    print "</p>\n";
#    printStatusLine( "Loading ...", 1 );
#    print "<p>\n";
#    my @recs;
#
#    for ( ; ; ) {
#        my ( $cluster_id, $cluster_name, $gene_count ) = $cur->fetchrow();
#        last if !$cluster_id;
#        my $r = sprintf( "%06d", $gene_count ) . "\t";
#        $r .= "$cluster_id\t";
#        $r .= "$cluster_name";
#        push( @recs, $r );
#    }
#    my @recs2 = reverse( sort(@recs) );
#    for my $r (@recs2) {
#        my ( $gene_count, $cluster_id, $cluster_name ) = split( /\t/, $r );
#        my $gene_count2 = sprintf( "%d", $gene_count );
#        $count++;
#        my $url = "$section_cgi&page=mclClusterGeneList&cluster_id=$cluster_id";
#        print "cluster_id $cluster_id - " . escHtml($cluster_name);
#        print " (" . alink( $url, $gene_count2 ) . ")<br/>\n";
#    }
#    print "</p>\n";
#    $cur->finish();
#    #$dbh->disconnect();
#    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
#    printStatusLine( "$count MCL clusters retrieved.", 2 );
#    print end_form();
#}
#
#############################################################################
## printMclClusterGeneList - Show genes under one cluster.
#############################################################################
#sub printMclClusterGeneList {
#    my $cluster_id = param("cluster_id");
#
#    my $dbh = dbLogin();
#    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
#    my $rclause = urClause("g.taxon");
#    my $sql     = qq{
#       select distinct g.gene_oid
#       from mcl_cluster mc, gene_mcl_clusters gmc, gene g
#       where mc.cluster_id = gmc.mcl_cluster
#       and mc.cluster_id = ?
#       and gmc.gene_oid = g.gene_oid
#       and g.locus_type = 'CDS'
#       and g.obsolete_flag = 'No'
#       $rclause
#       order by g.gene_oid
#   };
#    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
#    my $count = 0;
#    my @gene_oids;
#    printMainForm();
#    print "<h1>\n";
#    print "MCL Cluster Genes\n";
#    print "</h1>\n";
#    WebUtil::printGeneCartFooter();
#
#    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
#    $it->addColSpec("Select");
#    $it->addColSpec( "Gene ID",    "number asc", "right" );
#    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
#    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
#    $it->addColSpec( "Genome ID",    "number asc", "right" );
#    $it->addColSpec( "Genome Name",       "char asc",   "left" );
#    print "<p>\n";
#    my $count = 0;
#    for ( ; ; ) {
#        my ($gene_oid) = $cur->fetchrow();
#        last if !$gene_oid;
#        $count++;
#        push( @gene_oids, $gene_oid );
#    }
#    $cur->finish();
#    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it, 1 );
#    $it->printOuterTable(1);
#    print "<br/>\n";
#
#    print "</p>\n";
#    #$dbh->disconnect();
#    printStatusLine( "$count gene(s) retrieved.", 2 );
#
#    if ( $user_restricted_site && !$no_restricted_message ) {
#        print "<p>\n";
#        print "<font color='red'>\n";
#        print "MCL cluster genes listed here are restricted by\n";
#        print "genomes access.<br/>\n";
#        print "</font>\n";
#        print "</p>\n";
#    }
#    print end_form();
#}

############################################################################
# printParalogGroups - Show paralog groups.
############################################################################
sub printParalogGroups {
    my $taxon_oid = param("taxon_oid");

    $maxParalogGroups = getSessionParam("maxParalogGroups")
      if getSessionParam("maxParalogGroups") ne "";

    printStatusLine( "Loading ...", 1 );
    print "<h1>Genes in Paralog Clusters</h1>\n";
    printMainForm();

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select
          pg.group_oid, g.locus_tag, g.gene_display_name, g.gene_oid
        from paralog_group pg, paralog_group_genes pgp, gene g
        where pg.taxon = ?
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and pg.group_oid = pgp.group_oid
        and pgp.genes = g.gene_oid
        $rclause
        $imgClause
        order by pg.group_oid, g.gene_display_name, g.gene_oid
    };
    my @binds = ( $taxon_oid, $taxon_oid );
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $old_group_oid;
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    WebUtil::printGeneCartFooter();
    print "<p>\n";
    my %uniqueGenes;
    for ( ; ; ) {
        my ( $group_oid, $locus_tag, $gene_display_name, $gene_oid ) = $cur->fetchrow();
        last if !$group_oid;

        $uniqueGenes{$gene_oid} = 1;
        if (   $old_group_oid ne $group_oid
            && $old_group_oid ne "" )
        {
            print "<br/>\n";
            $count++;
            if ( $count >= $maxParalogGroups ) {
                my $s = "Results limited to $maxParalogGroups groups.\n";
                $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Paralog Groups\". )\n";
                printStatusLine( $s, 2 );
                return;
            }
        }
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' />\n";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print alink( $url, $gene_oid ) . " <i>$locus_tag</i> $gene_display_name<br/>\n";
        $old_group_oid = $group_oid;
    }
    $cur->finish();

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    print "</p>\n";
    my $nGenes = keys(%uniqueGenes);
    printStatusLine( "$nGenes genes in paralog clusters retrieved.", 2 );

    print end_form();
}

############################################################################
# printParalogClusters - Show paralog clusters.
############################################################################
sub printParalogClusters {
    my $taxon_oid = param("taxon_oid");

    if ($include_metagenomes) {
        print "<h1>Genes in Internal Clusters</h1>\n";
    } else {
        print "<h1>Genes in Paralog Clusters</h1>\n";
    }
    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('pg.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('pg.taxon');

    my %clusterHasCogs;
    if ( $img_lite && $include_metagenomes ) {
        my $sql = qq{
            select pg.group_oid
            from paralog_group pg, paralog_group_genes pgg,
               gene_cog_groups gcg
            where pg.group_oid = pgg.group_oid
            and pg.taxon = ?
            and pgg.genes = gcg.gene_oid
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ($group_oid) = $cur->fetchrow();
            last if !$group_oid;
            $clusterHasCogs{$group_oid} = 1;
        }
        $cur->finish();
    }
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    # We assume protein_oid = gene_oid here for efficiency.
    my $sql = qq{
        select pg.group_oid, pg.group_name, count( distinct pgg.genes )
        from paralog_group pg, paralog_group_genes pgg
        where pg.group_oid = pgg.group_oid
        and pg.taxon = ?
        $rclause
        $imgClause
        group by pg.group_oid, pg.group_name
        having count( distinct pgg.genes ) > 1
        order by pg.group_oid, pg.group_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    printMainForm();
    print "<p>\n";
    print "Cluster names are assigned tentatively from most frequently ";
    print "occurring gene name.<br/>\n";
    print "The number of genes in each cluster is shown.<br/>\n";

=Removed per Natalia's request for IMG 3.3 +BSJ 10/15/10
    print "((n)) - Cluster has no COG hits.<br/>\n"
      if $img_lite && $include_metagenomes;
=cut

    print "</p>\n";

    my @recs;
    for ( ; ; ) {
        my ( $cluster_id, $cluster_name, $gene_count ) = $cur->fetchrow();
        last if !$cluster_id;
        my $r = sprintf( "%06d", $gene_count ) . "\t";
        $r .= "$cluster_id\t";
        $r .= "$cluster_name";
        push( @recs, $r );
    }
    $cur->finish();

    my $it = new InnerTable( 1, "clusterlist$$", "clusterlist", 2 );
    $it->addColSpec( "Cluster ID",   "number asc",  "right" );
    $it->addColSpec( "Cluster Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",   "number desc", "right" );

    # Added yes/no column per Natalia's request for IMG 3.3 +BSJ 10/15/10
    $it->addColSpec( "Has COG Hits", "number desc", "center", "", "", "wrap" )
      if $img_lite && $include_metagenomes;

    my $sd = $it->getSdDelim();

    my @recs2 = reverse( sort(@recs) );
    for my $r (@recs2) {
        my ( $gene_count, $cluster_id, $cluster_name ) = split( /\t/, $r );
        my $gene_count2 = sprintf( "%d", $gene_count );
        $count++;
        my $url = "$section_cgi&page=paralogClusterGeneList" . "&cluster_id=$cluster_id";

        # Parentheses around gene count removed
        # per Natalia's request for IMG 3.3 +BSJ 10/15/10

=removed leading and trailing parenthesis
        my ( $x1, $x2 );
        $x1 = '('
          if !$clusterHasCogs{$cluster_id}
          && $img_lite
          && $include_metagenomes;
        $x2 = ')'
          if !$clusterHasCogs{$cluster_id}
          && $img_lite
          && $include_metagenomes;
=cut

        my $r;
        $r .= $cluster_id . $sd . $cluster_id . "\t";
        $r .= $cluster_name . $sd . escHtml($cluster_name) . "\t";
        $r .= $gene_count2 . $sd . alink( $url, $gene_count2 ) . "\t";

        # Parentheses removed per Natalia's request for IMG 3.3 +BSJ 10/15/10
        #$r .= $gene_count2 . $sd . "$x1"
        #    . alink( $url, $gene_count2 ) . "$x2" . "\t";

        # Instead added Has COG Hits (yes/no) column
        # per Natalia's request for IMG 3.3 +BSJ 10/15/10
        if ( $img_lite && $include_metagenomes ) {
            my $hasCogHits =
              ( $clusterHasCogs{$cluster_id} )
              ? "<span style='color:green'>Yes</span>"
              : "<span style='color:red'>No</span>";
            $r .= $hasCogHits . $sd . $hasCogHits . "\t";
        }
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    printStatusLine( "$count paralog clusters retrieved.", 2 );
    print end_form();
}

############################################################################
# printParalogClusterGeneList - Show genes under one cluster.
############################################################################
sub printParalogClusterGeneList {
    my @cluster_ids = param("cluster_id");

    if ( scalar(@cluster_ids) == 0 ) {
        webError("No Cluster has been selected.");
    }

    printMainForm();
    for my $cluster_id ( @cluster_ids ) {
        print hiddenVar( "cluster_id", $cluster_id );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    if ($include_metagenomes) {
        print "<h1>Internal Cluster Genes</h1>\n";
    } else {
        print "<h1>Paralog Cluster Genes</h1>\n";
    }

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchClusterId2NameHash( $dbh, \@cluster_ids, \%funcId2Name, 1 );

    print "<p style='width: 650px;'>";
    for my $id (@cluster_ids) {
        my $funcName = $funcId2Name{$id};
        print $id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $sql = QueryUtil::getClusterGenesSql($funcIdsInClause);
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql );

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $funcIdsInClause =~ /gtt_num_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllClusterGenes('gene_oid');
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printUniqueGenes - Show unique genes as all genes minus orthologs
#   and parlogs.  (Not used.)
############################################################################
sub printUniqueGenes {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    webLog "Get queries " . currDateTime() . "\n" if $verbose >= 1;

    ## Paralogs
    my $rclause     = WebUtil::urClause('g.taxon');
    my $imgClause   = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql_paralog = qq{
        select distinct g.gene_oid
        from gene_paralogs gp, gene g
        where g.gene_oid = gp.gene_oid
        and g.taxon = ?
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql_paralog, $verbose, $taxon_oid );
    my $count_p = 0;
    my %paralogs;

    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count_p++;
        $paralogs{$gene_oid} = 1;
    }
    $cur->finish();

    WebUtil::printGeneCartFooter();
    print "<p>\n";

    ## Ortholog
    my $count_o = 0;

    #    my $sql     = qq{
    #       select distinct g.gene_oid
    #       from gene_orthologs go, gene g
    #       where go.gene_oid = g.gene_oid
    #       and g.taxon = ?
    #       and g.obsolete_flag = 'No'
    #    };
    my $sql = qq{
        select distinct mg.member_genes
        from bbh_cluster_member_genes mg, gene g
        where mg.member_genes = g.gene_oid
        and g.taxon = ?
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my %orthologs;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count_o++;
        $orthologs{$gene_oid} = 1;
    }
    $cur->finish();

    ## All genes
    my $count_u = 0;
    my $sql     = qq{
        select g.gene_oid, g.locus_tag, g.gene_display_name
        from gene g, taxon tx
        where g.taxon = ?
        and g.taxon = tx.taxon_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my @binds = ($taxon_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $orthologs{$gene_oid} ne "";
        next if $paralogs{$gene_oid}  ne "";
        $count_u++;
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' />\n";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print alink( $url, $gene_oid ) . " <i>$locus_tag</i> $gene_display_name<br/>\n";
    }
    $cur->finish();
    print "</p>\n";

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    #$dbh->disconnect();

}

############################################################################
# printRnas - Show RNA genes.
############################################################################
sub printRnas {
    my $taxon_oid   = param("taxon_oid");
    my $locus_type  = param("locus_type");
    my $gene_symbol = param("gene_symbol");
    #print "locus_type=$locus_type gene_symbol=$gene_symbol<br/>\n";

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "locus_type", $locus_type ) if ( $locus_type );
    print hiddenVar( "gene_symbol", $gene_symbol ) if ( $gene_symbol );
    print "<h1>RNA Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my @gene_oids = QueryUtil::fetchSingleTaxonRnaGenes( $dbh, $taxon_oid, $locus_type, $gene_symbol);
    my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @gene_oids );

    my $sql = qq{
        select g.gene_oid, g.locus_type, g.locus_tag, g.gene_symbol,
          g.gene_display_name, g.start_coord, g.end_coord, g.strand,
          g.dna_seq_length, tx.seq_status,
          scf.ext_accession, ss.seq_length, ss.gc_percent, scf.read_depth
        from gene g, taxon tx, scaffold scf, scaffold_stats ss
        where g.taxon = tx.taxon_oid
        and g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
        and g.gene_oid in ($oids_str)
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $count         = 0;
    my $trnaCount     = 0;
    my $rrnaCount     = 0;
    my $rrna5SCount   = 0;
    my $rrna16SCount  = 0;
    my $rrna18SCount  = 0;
    my $rrna23SCount  = 0;
    my $rrna28SCount  = 0;
    my $otherRnaCount = 0;

    my $old_locus_type;
    my $old_gene_symbol;

    my $it = new InnerTable( 1, "RNAGenes$$", "RNAGenes", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Locus Type",        "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Gene Symbol",       "asc", "left" );
    $it->addColSpec( "Coordinates" );
    $it->addColSpec( "Length (bp)",            "desc", "right" );

    if ($include_metagenomes) {
        $it->addColSpec( "Scaffold ID",           "asc",  "left" );
        $it->addColSpec( "Contig Length",         "desc", "right" );
        $it->addColSpec( "Contig GC",             "desc", "right" );
        $it->addColSpec( "Contig<br/>Read Depth", "desc", "right" );
    }

    my $select_id_name = "gene_oid";

    for ( ; ; ) {
        my (
            $gene_oid,          $locus_type,     $locus_tag,      $gene_symbol,    $gene_display_name,
            $start_coord,       $end_coord,      $strand,         $dna_seq_length, $seq_status,
            $scf_ext_accession, $scf_seq_length, $scf_gc_percent, $scf_read_depth
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        $scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
        $scf_read_depth = sprintf( "%.2f", $scf_read_depth );
        $scf_read_depth = "-" if $scf_read_depth == 0;
        $dna_seq_length = 0   if $dna_seq_length eq "";

        my $len = $end_coord - $start_coord + 1;
        $count++;
        my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\t";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $row .= $locus_type . $sd . escHtml($locus_type) . "\t";
        $row .= $gene_display_name . $sd . escHtml($gene_display_name) . "\t";
        $row .= $gene_symbol . $sd . escHtml($gene_symbol) . "\t";

        if ( $end_coord == 0 ) {
            $row .= " " . $sd . nbsp(1) . "\t";
        } else {
            $row .= "$start_coord..$end_coord($strand)" . $sd . "$start_coord..$end_coord($strand)\t";
        }
        $row .= $dna_seq_length . $sd . "${dna_seq_length}\t";

        if ($include_metagenomes) {
            $row .= $scf_ext_accession . $sd . $scf_ext_accession . "\t";
            $row .= $scf_seq_length . $sd . "${scf_seq_length}\t";
            $row .= $scf_gc_percent . $sd . $scf_gc_percent . "\t";
            $row .= $scf_read_depth . $sd . $scf_read_depth . "\t";
        }
        $rrnaCount++ if ( $locus_type =~ /rRNA/ );
        $rrna5SCount++  if ( $gene_symbol eq "5S" );
        $rrna16SCount++ if ( $gene_symbol eq "16S" );
        $rrna18SCount++ if ( $gene_symbol eq "18S" );
        $rrna23SCount++ if ( $gene_symbol eq "23S" );
        $rrna28SCount++ if ( $gene_symbol eq "28S" );
        $trnaCount++ if ( $locus_type =~ /tRNA/ );
        $otherRnaCount++ if ( $locus_type !~ /rRNA/ && $locus_type !~ /tRNA/ );
        $old_locus_type  = $locus_type;
        $old_gene_symbol = $gene_symbol;
        $it->addRow($row);
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
        if ( $oids_str =~ /gtt_num_id/i );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    my $totalRnaCount = $rrnaCount + $trnaCount + $otherRnaCount;
    if ( $totalRnaCount > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllRnaGeneList($select_id_name);
    }
    printStatusLine( "$rrnaCount rRNA's, $trnaCount tRNA's, " . "$otherRnaCount ncRNA's retrieved.", 2 );
    my $unknownRrnaCount = $rrnaCount - $rrna5SCount - $rrna16SCount - $rrna18SCount - $rrna23SCount - $rrna28SCount;

    print end_form();
}

############################################################################
# printStatRow  - Utility function to print on statistics row.
############################################################################
sub printStatRow {
    my ( $title, $count, $total ) = @_;
    print "<tr class='img' >\n";
    print "<td class='img' >" . nbsp(2) . escHtml($title) . "</td>\n";
    print "<td class='img'  align='right'>$count</td>\n";
    my $s = sprintf( "%.2f%%", ( $count / $total ) * 100 );
    print "<td class='img'  align='right'>$s</td>\n";
    print "</tr>\n";
}

############################################################################
# printStatsPerSample - print the gene counts for each cog, kegg, etc.
#     category per proteomics sample for the given genome.
############################################################################
sub printStatsPerSample {
    my (
        $type,               $taxon_oid,         $total,
	$sampleIds_aref,     $sampleNames_aref,  $columns_aref,
	$sampleCogHash_href, $categoryHash_href, $chartcategories_aref,
	$functioncodes_aref
      )
      = @_;

    my $og = $type;
    my $OG = uc($type);

    print "<div id='sampleView' style='display: block;'>";
    print "<input type='button' class='medbutton' name='view'"
      . " value='Hide ${OG}s in Protein Samples'"
      . " onclick='showView(\"slim\")' />";

    my $it = new InnerTable( 1, "${og}samples$$", "${og}samples", 0 );
    my $sd = $it->getSdDelim();
    $it->hideAll();
    $it->addColSpec( "Sample ID",   "asc", "right" );
    $it->addColSpec( "Sample Name", "asc", "left" );

    foreach my $col (@$columns_aref) {
        my $index = 0;
        my $i     = 0;
        my $found = 0;
        my $tmp   = $col;
        if ( $col =~ /percentage$/ ) {
            $tmp =~ s/ percentage//;
        }
        if ( $categoryHash_href->{$tmp} ) {
            for my $item (@$chartcategories_aref) {
                if ( $item eq $tmp ) {
                    $i     = $index;
                    $found = 1;
                    last;
                }
                $index++;
            }
            my $url = "$section_cgi&page=${og}GeneList&cat=cat";
            $url .= "&function_code=$functioncodes_aref->[$i]";
            $url .= "&taxon_oid=$taxon_oid";

            my $colName = $col;
            $it->addColSpec( $colName, "desc", "right", "", $col );
        }
    }

    my $idx = 0;
    foreach my $sid (@$sampleIds_aref) {
        my $url = "$main_cgi?section=IMGProteins&page=sampledata&sample=$sid";
        my $row;
        $row .= $sid . "\t";
        $row .= $sampleNames_aref->[$idx] . $sd . alink( $url, $sampleNames_aref->[$idx] ) . "\t";

        foreach my $col (@$columns_aref) {
            my $index = 0;
            my $i     = 0;
            my $found = 0;
            my $tmp   = $col;
            if ( $col =~ /percentage$/ ) {
                $tmp =~ s/ percentage//;
            }
            if ( $categoryHash_href->{$tmp} ) {
                for my $item (@$chartcategories_aref) {
                    if ( $item eq $tmp ) {
                        $i     = $index;
                        $found = 1;
                        last;
                    }
                    $index++;
                }
                if ($found) {
                    my $val = $sampleCogHash_href->{ $sid . "" . $functioncodes_aref->[$i] };
                    $val = 0 if ( !$val );
                    if ( $col =~ /percentage$/ ) {
                        if ( $total == 0 ) {
                            $row .= "0\t";
                        } else {
                            $val = $val * 100 / $total;
                            my $pc = sprintf( "%.2f%%", $val );
                            $row .= $pc . "\t";
                        }
                    } else {
                        $row .= $val . "\t";
                    }
                } else {
                    $row .= "\t";
                }
            }
        }
        $idx++;
        $it->addRow($row);
    }
    $it->printOuterTable(1);
    print "</div>\n";
}

############################################################################
# printCogCategories - Show COG/KOG categories and count of genes.
#      When calling, set first argument to 1 for KOGs  +BSJ 05/27/11
############################################################################
sub printCogCategories {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $taxon_oid = param("taxon_oid");
    my $url2 = "$section_cgi&page=${og}GeneList&cat=cat&taxon_oid=$taxon_oid";

    #### PREPARE THE PIECHART ######
    my @chartcategories;
    my @functioncodes;
    my @chartdata;
    #################################

    my $dbh = dbLogin();
    my $rclause   = WebUtil::urClause('s.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon_oid');

    # get the total
    my $sql = qq{
        select s.genes_in_${og}
        from taxon_stats s
    	where s.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $total_gene_count = $cur->fetchrow();
    $cur->finish();

    my ( $taxon_name, $is_pangenome ) = QueryUtil::fetchSingleTaxonNameAndPangenome( $dbh, $taxon_oid );

    print "<h1>$OG Categories</h1>\n";
    print "<p style='width: 650px;'>\n";
    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "<br/><br/>\n";

    my $url = "$section_cgi&page=${og}s&taxon_oid=$taxon_oid";
    print alink( $url, "View as $OG List" );
    print "</p>\n";

    use TabHTML;
    TabHTML::printTabAPILinks( "ogcatTab", 1 );
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("ogcatTab");
        </script>
    };

    my @tabIndex = ( "#ogcattab1",     "#ogcattab2" );
    my @tabNames = ( "$OG Categories", "Statistics by $OG categories" );

    if ( lc($is_pangenome) eq "yes" ) {
        push @tabIndex, "#ogcattab3";
        push @tabNames, "Pangenome Composition";
    }
    TabHTML::printTabDiv( "ogcatTab", \@tabIndex, \@tabNames );

    print "<div id='ogcattab1'>";
    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
        select cf.definition, cf.function_code, count(distinct gcg.gene_oid)
        from gene_${og}_groups gcg, $og c, gene g, ${og}_function cf,
             ${og}_functions cfs
    	where gcg.$og = c.${og}_id
    	and gcg.gene_oid = g.gene_oid
    	and g.taxon = gcg.taxon
    	and g.taxon = ?
    	and g.locus_type = 'CDS'
    	and g.obsolete_flag = 'No'
    	and cfs.functions = cf.function_code
    	and cfs.${og}_id = c.${og}_id
        $rclause
        $imgClause
    	group by cf.definition, cf.function_code
    	having count(distinct gcg.gene_oid) > 0
    	order by cf.definition, cf.function_code
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my %categoryHash;
    my $gene_count_total = 0;
    for ( ;; ) {
        my ( $definition, $function_code, $gene_count ) = $cur->fetchrow();
        last if !$definition;
        last if !$function_code;
        $count++;

        push @chartcategories, "$definition";
        push @functioncodes,   "$function_code";
        push @chartdata,       $gene_count;
        $categoryHash{$definition} = $gene_count;
        $gene_count_total += $gene_count;
    }
    $cur->finish();

    ### ANNA: add Stats by COG/KOG per proteomics sample ###
    my $proteomics_data = $env->{proteomics};
    my $proteindata;
    if ($proteomics_data) {
        my $sql = qq{
            select count( distinct dt.gene_oid )
            from dt_img_gene_prot_pep_sample dt
            where dt.taxon = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        $proteindata = $cur->fetchrow();
        $cur->finish();
    }

    my %sampleCogHash;
    my @sampleIds;
    my @sampleNames;
    my $genes_with_peptides = 0;
    if ( $proteindata > 0 ) {
        my $sql = qq{
    	    select distinct g.gene_oid, count(g.peptide_oid)
    	    from dt_img_gene_prot_pep_sample g
    	    where g.taxon = ?
            $rclause
            $imgClause
    	    group by g.gene_oid
    	    order by g.gene_oid
	};

        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ( $geneid, $pepCount ) = $cur->fetchrow();
            last if !$geneid;
            if ( $pepCount > 0 ) {
                $genes_with_peptides++;
            }
        }
        $cur->finish();

        print qq{
    	    <script type='text/javascript'
    	    src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
    	    </script>

    	    <script language='JavaScript' type='text/javascript'>
    	    function showView(type) {
    	    if (type == 'slim') {
    		document.getElementById('sampleView').style.display = 'none';
    		document.getElementById('statView').style.display = 'block';
    	    } else {
    		document.getElementById('sampleView').style.display = 'block';
    		document.getElementById('statView').style.display = 'none';
    	    }
    	    }

    	    YAHOO.util.Event.onDOMReady(function () {
    		showView('slim');
    	    });
    	    </script>
	    };

        my $sql = qq{
	    select distinct dt.sample_oid, dt.sample_desc
	    from gene g, dt_img_gene_prot_pep_sample dt
            where dt.sample_oid > 0
	    and dt.gene_oid = g.gene_oid
	    and g.taxon = ?
            and g.locus_type = 'CDS'
	    and g.obsolete_flag = 'No'
            $rclause
            $imgClause
	    order by dt.sample_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ( $sid, $sname ) = $cur->fetchrow();
            last if !$sid;
            push @sampleIds,   $sid;
            push @sampleNames, $sname;
        }
        $cur->finish();

        foreach my $sid (@sampleIds) {
            my $sql = qq{
                select cf.function_code, cf.definition,
        	       count(distinct gcg.gene_oid)
              	from gene g, gene_${og}_groups gcg, $og c,
        	     ${og}_functions cfs, ${og}_function cf,
        	     dt_img_gene_prot_pep_sample dt
        	where dt.sample_oid = ?
        	and dt.gene_oid = g.gene_oid
        	and g.taxon = ?
        	and g.locus_type = 'CDS'
                and g.obsolete_flag = 'No'
        	and g.gene_oid = gcg.gene_oid
        	and gcg.$og = c.${og}_id
        	and c.${og}_id = cfs.${og}_id
        	and cfs.functions = cf.function_code
                $rclause
                $imgClause
        	group by cf.function_code, cf.definition
        	having count(distinct gcg.gene_oid) > 0
        	order by cf.function_code, cf.definition
	    };
            my $cur = execSql( $dbh, $sql, $verbose, $sid, $taxon_oid );
            for ( ; ; ) {
                my ( $code, $cog, $count ) = $cur->fetchrow();
                last if !$code;
                $sampleCogHash{ $sid . "" . $code } = $count;
            }
            $cur->finish();
        }
    }

    printHint("Click on an <u>icon</u> for a given category to view genes by individual $OG IDs for that category. <br/>Click on the <u>gene count</u> for a given category or on a pie slice to view all the genes for that category.");

    # COG/KOG categories table next to pie chart:
    my $idx = 0;
    my $d3data = "";
    foreach my $category1 (@chartcategories) {
        last if !$category1;

        my $percent = 100 * $chartdata[$idx] / $gene_count_total;
        $percent = sprintf( "%.2f", $percent );

    	if ($d3data) {
    	    $d3data .= ",";
    	} else {
    	    $d3data = "[";
    	}
    	$d3data .= "{" .
    	    "\"id\": \"" . escHtml($category1) .
    	    "\", \"count\": " . $chartdata[$idx] .
    	    ", \"name\": \"" . escHtml($category1) .
    	    "\", \"urlfragm\": \"" . $functioncodes[$idx] .
    	    "\", \"percent\": " .
    	    sprintf("%.2f", $percent) . "}";

        $idx++;
    }

    if ( $d3data ) {
    	my ( $nocogcount, $total_genome_gene_count )
    	    = getNoCogCounts( $dbh, $taxon_oid, $isKOG );
    	my $nocogcount_pc = 100 * $nocogcount / $total_genome_gene_count;
    	$nocogcount_pc = sprintf( "%.2f", $nocogcount_pc );

    	$d3data .= ",";
    	$d3data .= "{" .
    	    "\"id\": \"" . "Not in $OG" .
    	    "\", \"count\": " . $nocogcount .
    	    ", \"name\": \"" . "Not in $OG" .
    	    "\", \"urlfragm\": \"" . "" .
    	    "\", \"percent\": " . $nocogcount_pc .
    	    "}";

        $d3data .= "]";

        my $url1 = "$section_cgi&page=cate${og}List&cat=cat&taxon_oid=$taxon_oid";
    	my $url2 = "$section_cgi&page=${og}GeneList&cat=cat&taxon_oid=$taxon_oid";

    	require D3ChartUtil;
    	D3ChartUtil::printPieChart
            ($d3data, $url1."&function_code=", $url2."&function_code=", "", 0, 1,
             "[\"color\", \"name\", \"count\", \"percent\"]", 500, 400);
    }

    printStatusLine( "$count $OG retrieved.", 2 );
    print "</div>";    # end ogcattab1

    print "<div id='ogcattab2'>";
    my $txTableName = "taxonCogCategories";
    print start_form(
        -id     => $txTableName . "_frm",
        -name   => "mainForm",
        -action => "$main_cgi"
    );

    my @columns = param("outputCol");
    if ( $#columns < 0 ) {
        push( @columns, "Total $OG Genes" );
    }

    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
      QueryUtil::fetchSingleTaxonRank( $dbh, $taxon_oid );

    print "<h2>Statistics by $OG Categories</h2>\n";
    print "<p>";
    print "You may add or remove columns from the statistics table "
	. "using the configuration table below.";
    print "</p>";

    print "<div id='statView' style='display: block;'>\n";
    if ( $proteindata > 0 ) {
        print "<input type='button' class='medbutton' name='view'"
          . " value='Show ${OG}s in Protein Samples'"
          . " onclick='showView(\"full\")' />\n";
    }

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec("D");
    $it->addColSpec("C");
    $it->addColSpec( "Genome Name", "asc", "left", "", "", "wrap" );

    my $row;
    $row .= substr( $domain,     0, 1 ) . "\t";
    $row .= substr( $seq_status, 0, 1 ) . "\t";

    my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
    $row .= alink( $url, $taxon_name ) . "\t";

    foreach my $cat (@columns) {
        if (   $cat eq "Phylum"
            || $cat eq "Class"
            || $cat eq "Order"
            || $cat eq "Family"
            || $cat eq "Genus" )
        {
            $it->addColSpec( $cat, "asc", "left", "", "", "wrap" );
        } else {
            $it->addColSpec( $cat, "asc", "right", "", "", "wrap" );
        }

        if ( $cat eq "Phylum" ) {
            $row .= $phylum . "\t";
        } elsif ( $cat eq "Class" ) {
            $row .= $ir_class . "\t";
        } elsif ( $cat eq "Order" ) {
            $row .= $ir_order . "\t";
        } elsif ( $cat eq "Family" ) {
            $row .= $family . "\t";
        } elsif ( $cat eq "Genus" ) {
            $row .= $genus . "\t";
        } elsif ( $cat eq "Total $OG Genes" ) {
            my $cnt = $total_gene_count;
            $row .= $cnt . "\t";
        } else {
            if ( $cat =~ /percentage$/ ) {
                my $tmp = $cat;
                $tmp =~ s/ percentage//;
                my $cnt = $categoryHash{$tmp};
                if ( $total_gene_count == 0 ) {
                    $row .= "0" . "\t";
                } else {
                    $cnt = $cnt * 100 / $total_gene_count;
                    my $pc = sprintf( "%.2f%%", $cnt );
                    $row .= $pc . "\t";
                }
            } else {
                my $cnt = $categoryHash{$cat};
                $row .= $cnt . "\t";
            }
        }
    }
    $it->addRow($row);

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    print "</div>";    # statView div

    if ( $proteindata > 0 ) {
        printStatsPerSample( "$og", $taxon_oid, $genes_with_peptides, \@sampleIds,
			     \@sampleNames, \@columns, \%sampleCogHash,
			     \%categoryHash, \@chartcategories, \@functioncodes );
    }

    # add some initial categories to be selected
    my @category_list;
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total $OG Genes" );
    foreach my $category1 (@chartcategories) {
        last if !$category1;
        push( @category_list, $category1 );
        push( @category_list, "$category1 percentage" );
    }

    print "<h2>Configuration</h2>";
    printConfigTable( \@category_list, \@columns, $taxon_oid, "${og}s", $blockDatatableCss );

    print end_form();
    print "</div>";    # end ogcattab2

    print "<div id='ogcattab3'>";
    if ( lc($is_pangenome) eq "yes" ) {
        TaxonList::printPangenomeTable($taxon_oid);
    }
    print "</div>";    # end ogcattab3
    TabHTML::printTabDivEnd();
}

sub createTabFile {
    my ($aref) = @_;
    my $sid    = getSessionId();
    my $file   = "cog$$" . "_" . $sid . ".xls";
    my $path   = "$tmp_dir/$file";
    my $fh     = newWriteFileHandle($path);

    foreach my $line (@$aref) {
        print $fh $line . "\n";
    }

    close $fh;
    return $file;
}

sub getNoCogCounts {
    my ( $dbh, $taxon_oid, $isKOG ) = @_;
    my $og = "cog";    # orthogonal group: cog|kog
    $og = "kog" if ($isKOG);

    my $rclause   = WebUtil::urClause('s.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon_oid');

    my $sql = qq{
        select s.total_gene_count, s.genes_in_${og}
        from taxon_stats s
        where s.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $gene_count, $cog_gcount ) = $cur->fetchrow();
    $cur->finish();

    my $tmp = $gene_count - $cog_gcount;
    return ( $tmp, $gene_count );
}

############################################################################
# printTaxonCKog - Show cog list and count of genes per cog or kog
############################################################################
sub printTaxonCKog {
    my ($isKOG) = @_;

    my $og = "cog";    # orthogonal group: cog|kog
    my $OG = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<h1>Characterized ${OG}s</h1>\n";
    print "<p>\n";
    my $url = "$section_cgi&page=${og}s&cat=cat&taxon_oid=$taxon_oid";
    print alink( $url, "View as $OG Categories" );
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $sql = qq{
        select c.${og}_name, c.${og}_id, count(distinct g.gene_oid)
        from ${og} c, gene g, ${og}_function cf, gene_${og}_groups gcg
        where c.${og}_id = gcg.${og}
        and gcg.gene_oid = g.gene_oid
        and g.taxon = gcg.taxon
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and c.${og}_name not like ?
        $rclause
        $imgClause
        group by c.${og}_name, c.${og}_id
        having count(distinct gcg.gene_oid) > 0
        order by lower( c.${og}_name ), c.${og}_id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 'Uncharacterized%' );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my @rows;
    for ( ; ; ) {
        my ( $name, $id, $gene_count ) = $cur->fetchrow();
        last if !$name;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='$id' /> \t";

        $r .= "$id\t";
        $r .= "$name\t";

        my $url = "$section_cgi&page=${og}GeneList&${og}_id=$id";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    my $name = "_section_${section}_${og}GeneList";
    TaxonDetailUtil::print3ColGeneCountTable( "$og", \@rows, "${OG} ID", "${OG} Name", $section, $name, "List Genes" );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count ${OG}s retrieved.", 2 );
    print end_form();
}

############################################################################
# printCateCogList - print category Cog list
############################################################################
sub printCateCogList {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $taxon_oid     = param("taxon_oid");
    my $function_code = param("function_code");

    printMainForm();
    print hidden( 'taxon_oid', $taxon_oid );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select definition
        from ${og}_function
        where function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    print "<h1>${OG} Category: " . escapeHTML($definition) . "</h1>\n";

    checkTaxonPerm( $dbh, $taxon_oid );
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select c.${og}_id, c.${og}_name, count(distinct gcg.gene_oid)
        from gene_${og}_groups gcg, $og c, ${og}_function cf,
           ${og}_functions cfs, gene g
        where gcg.taxon = ?
        and gcg.$og = c.${og}_id
        and c.${og}_id = cfs.${og}_id
        and cfs.functions = cf.function_code
        and cf.function_code = ?
        and gcg.gene_oid = g.gene_oid
        and g.taxon = gcg.taxon
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        group by c.${og}_id, c.${og}_name
        order by c.${og}_id, c.${og}_name
    };

    #print "printCateCogList sql: $sql<br/>\n";
    #print "printCateCogList taxon_oid: $taxon_oid, function_code: $function_code<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $function_code );

    my @recs = ();
    for ( ; ; ) {
        my ( $id, $name, $cnt ) = $cur->fetchrow();
        last if !$id;

        my $rec = "$id\t";
        $rec .= "$name\t";
        $rec .= "$cnt";
        push( @recs, $rec );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "${OG} ID",   "asc",  "left" );
    $it->addColSpec( "${OG} Name", "asc",  "left" );
    $it->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "func_id";

    my $count = 0;
    for my $rec (@recs) {

        #print "printCateCogList rec: $rec<br/>\n";
        my ( $id, $name, $cnt ) = split( /\t/, $rec );
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        $r .= $id . $sd . $id . "\t";
        $r .= $name . $sd . $name . "\t";
        my $url2 = "$section_cgi&page=${og}GeneList&${og}_id=$id&taxon_oid=$taxon_oid";
        $r .= $cnt . $sd . alink( $url2, $cnt ) . "\t";
        $it->addRow($r);
    }

    my $name = "_section_${section}_${og}GeneList";
    if ( $count > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count ${og}(s) retrieved.", 2 );

    print end_form();
}

############################################################################
# printCKogCatGeneList - Show genes under one COG or KOG category
############################################################################
sub printCKogCatGeneList {
    my ($isKOG) = @_;

    my $og = "cog";    # orthogonal group: cog|kog
    my $OG = "COG";    # orthogonal group text: COG|KOG

    if ( $isKOG ) {
        $og = "kog";
        $OG = "KOG";
    }

    my $taxon_oid     = param("taxon_oid");
    my $function_code = param("function_code");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "function_code", $function_code ) if ( $function_code );
    print hiddenVar( "og", $og );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $definition = QueryUtil::getCKogCateDefinition($dbh, $function_code, $og);
    print "<h1>$OG Genes</h1>\n";
    print "<p>\n";
    print "Only ${OG}s associated with <i><u>" . escHtml($definition) . "</u></i> are shown with genes.";
    print "</p>\n";

    my ($sql, @binds) = QueryUtil::getSingleTaxonCKogCatGenesSql($taxon_oid, $function_code, $og);
    my $count = TaxonDetailUtil::printCatGeneListTable( $dbh, $sql, @binds );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllCKogCatGenes('gene_oid');
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printCKogGeneList - Show genes under one COG or KOG.
############################################################################
sub printCKogGeneList {
    my ($isKOG) = @_;

    my $og = "cog";    # orthogonal group: cog|kog
    my $OG = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $taxon_oid = param("taxon_oid");
    my @ckog_ids   = param("${og}_id");
    if ( scalar(@ckog_ids) <= 0 ) {
        @ckog_ids = param("func_id");
    }
    if ( scalar(@ckog_ids) == 0 ) {
        webError("No $OG has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $ckog_id ( @ckog_ids ) {
        print hiddenVar( "func_id", $ckog_id );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchCogId2NameHash( $dbh, $og, \@ckog_ids, \%funcId2Name, 1 );

    print "<h1>$OG Genes</h1>";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    foreach my $ckog_id (@ckog_ids) {
        my $funcName = $funcId2Name{$ckog_id};
        print $ckog_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct gcg.gene_oid
        from gene_${og}_groups gcg, gene g
        where gcg.taxon = ?
        and gcg.$og in ($funcIdsInClause)
        and gcg.gene_oid = g.gene_oid
        and g.taxon = gcg.taxon
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $funcIdsInClause =~ /gtt_func_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

############################################################################
# printTaxonEnzymes - Print enzymes list.
############################################################################
sub printTaxonEnzymes {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<h1>Enzymes</h1>\n";
    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
    print alink( $url, $taxon_name );
    print "</p>";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select ez.enzyme_name, ez.ec_number, count( distinct g.gene_oid )
        from gene g, gene_ko_enzymes ge, enzyme ez
        where g.gene_oid = ge.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and ge.enzymes = ez.ec_number
        and g.taxon = ?
        $rclause
        $imgClause
        group by ez.enzyme_name, ez.ec_number
        order by ez.enzyme_name, ez.ec_number
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $count = 0;
    my @rows;
    for ( ; ; ) {
        my ( $enzyme_name, $ec_number, $gene_count ) = $cur->fetchrow();
        last if !$ec_number;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='$ec_number' /> \t";

        $r .= "$ec_number\t";
        $r .= "$enzyme_name\t";

        my $url = "$section_cgi&page=enzymeGeneList&ec_number=$ec_number";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    my $name = "_section_${section}_enzymeGeneList";
    TaxonDetailUtil::print3ColGeneCountTable( "enzyme", \@rows, "Enzyme ID", "Enzyme Name", $section, $name, "List Genes" );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count enzyme retrieved.", 2 );
    print end_form();
}

############################################################################
# printEnzymeGeneList - Show genes under one enzyme.
############################################################################
sub printEnzymeGeneList {
    my $taxon_oid = param("taxon_oid");

    my @ec_ids = param("ec_number");
    if ( scalar(@ec_ids) <= 0 ) {
        @ec_ids = param("func_id");
    }
    if ( scalar(@ec_ids) == 0 ) {
        webError("No enzyme has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $ec_id ( @ec_ids ) {
        print hiddenVar( "func_id", $ec_id );
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchEnzymeId2NameHash( $dbh, \@ec_ids, \%funcId2Name, 1 );

    print "<h1>Enzyme (EC) Genes</h1>\n";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $ec_id (@ec_ids) {
        my $funcName = $funcId2Name{$ec_id};
        print $ec_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid, g.gene_display_name, ge.enzymes
        from gene g, gene_ko_enzymes ge
        where ge.taxon = ?
        and ge.enzymes in ($funcIdsInClause)
        and g.gene_oid = ge.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    if ( $count > 0 ) {
        my $select_id_name = "gene_oid";
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printImgTerms - Print IMG Terms.
############################################################################
sub printImgTerms {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>IMG Terms</h1>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );

    my $dbh = dbLogin();

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    if ($img_internal) {
        print "<p>\n";
        print alink( "$section_cgi&page=imgTerms&taxon_oid=$taxon_oid&cat=cat", "View as IMG Term Categories" );
        print "</p>\n";
    }

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    #    my $sql = qq{
    #        select it.term_oid, it.term, count( distinct g.gene_oid )
    #        from gene g, gene_img_functions gif, dt_img_term_path dtp, img_term it
    #        where g.taxon = ?
    #        and g.locus_type = 'CDS'
    #        and g.gene_oid = gif.gene_oid
    #        and gif.function = dtp.map_term
    #        and dtp.term_oid = it.term_oid
    #        $rclause
    #        $imgClause
    #        group by it.term, it.term_oid
    #        order by it.term, it.term_oid
    #    };
    my $sql = qq{
        select it.term_oid, it.term, count( distinct g.gene_oid )
        from gene g, gene_img_functions gif, img_term it
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.gene_oid = gif.gene_oid
        and gif.function = it.term_oid
        $rclause
        $imgClause
        group by it.term, it.term_oid
        order by it.term, it.term_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $count = 0;
    my @rows;
    for ( ; ; ) {
        my ( $term_oid, $term, $gene_count ) = $cur->fetchrow();
        last if !$term_oid;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='ITERM:$term_oid' /> \t";

        $r .= "$term_oid\t";
        $r .= "$term\t";

        my $url = "$section_cgi&page=imgTermGeneList&term_oid=$term_oid";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $name = "_section_${section}_imgTermGeneList";
    TaxonDetailUtil::print3ColGeneCountTable( "imgTerm", \@rows, "Term ID", "Term Name", $section, $name, "List Genes" );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count term retrieved.", 2 );
    print end_form();
}

# does not work - i'll have to do my own tree
# ken
#
sub printImgTermsTree {
    my $taxon_oid = param("taxon_oid");
    my $dbh       = dbLogin();
    print "<p>\n";
    my $mgr = new ImgTermNodeMgr();
    my $root = $mgr->loadTree( $dbh, $taxon_oid );
    $root->sortNodes();
    $root->printHtml();
    print "</p>\n";

    #$dbh->disconnect();
}

sub printImgTermsCat {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>IMG Terms Categories</h1>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<p>\n";
    print alink( "$section_cgi&page=imgTerms&taxon_oid=$taxon_oid", "View as IMG Term list" );
    print "</p>\n";

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    #    my $sql = qq{
    #    	select $nvl(itc.term_oid, -1),
    #    	$nvl(it2.term, '_'), count(distinct g.gene_oid)
    #    	from gene g, gene_img_functions gif,
    #    	    dt_img_term_path dtp, img_term it
    #        left join img_term_children itc on itc.child = it.term_oid
    #        left join img_term it2 on  itc.term_oid = it2.term_oid
    #        where g.taxon = ?
    #        and g.locus_type = 'CDS'
    #        and g.gene_oid = gif.gene_oid
    #        and gif.function = dtp.map_term
    #        and it.term_oid = dtp.term_oid
    #        $rclause
    #        $imgClause
    #    	group by itc.term_oid, it2.term
    #    	order by it2.term
    #    };
    my $sql = qq{
        select $nvl(itc.term_oid, -1),
        $nvl(it2.term, '_'), count(distinct g.gene_oid)
        from gene g, gene_img_functions gif, img_term it
        left join img_term_children itc on itc.child = it.term_oid
        left join img_term it2 on itc.term_oid = it2.term_oid
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.gene_oid = gif.gene_oid
        and gif.function = it.term_oid
        $rclause
        $imgClause
        group by itc.term_oid, it2.term
        order by it2.term
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $count = 0;
    my @rows;
    for ( ; ; ) {
        my ( $term_oid, $term, $gene_count ) = $cur->fetchrow();
        last if !$term_oid;
        $count++;

        my $r;
        $r .= uc($term) . $sortDelim . "$term\t";

        my $url = "$section_cgi&page=imgTermGeneList&term_oid=$term_oid";
        $url .= "&cat=cat";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    #$dbh->disconnect();

    TaxonDetailUtil::print2ColGeneCountTable( "imgTermCat", \@rows, "Term Name" );

    printStatusLine( "$count retrieved.", 2 );
    print end_form();
}

############################################################################
# printImgTermGeneList - Show genes under one IMG term.
############################################################################
sub printImgTermGeneList {
    my $taxon_oid = param("taxon_oid");

    my @term_oids = param("term_oid");
    if ( scalar(@term_oids) <= 0 ) {
        my @func_ids = param("func_id");
        foreach my $id (@func_ids) {
            if ( $id =~ /^ITERM:/ ) {
                $id =~ s/ITERM://;
                push( @term_oids, $id );
            }
        }
    }
    if ( scalar(@term_oids) == 0 ) {
        webError("No IMG Term has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $term_id ( @term_oids ) {
        print hiddenVar( "func_id", "ITERM:$term_id" );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchImgTermId2NameHash( $dbh, \@term_oids, \%funcId2Name, 1 );

    print "<h1>Genes Assigned to IMG Term</h1>";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $id (@term_oids) {
        my $funcName = $funcId2Name{$id};
        print $id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    #my $sql = qq{
    #    select distinct g.gene_oid, g.gene_display_name
    #    from gene g, gene_img_functions gif, dt_img_term_path dtp, img_term it
    #    where g.taxon = ?
    #    and g.locus_type = 'CDS'
    #    and g.gene_oid = gif.gene_oid
    #    and gif.function = dtp.map_term
    #    and it.term_oid = dtp.term_oid
    #    and it.term_oid in ($funcIdsInClause)
    #    $rclause
    #    $imgClause
    #    order by g.gene_display_name
    #};
    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene g, gene_img_functions gif, img_term it
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.gene_oid = gif.gene_oid
        and gif.function = it.term_oid
        and it.term_oid in ($funcIdsInClause)
        $rclause
        $imgClause
        order by g.gene_display_name
    };
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $funcIdsInClause =~ /gtt_num_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

sub printImgTermCatGeneList {
    my $taxon_oid = param("taxon_oid");
    my $term_oid  = param("term_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "term_oid", $term_oid ) if ( $term_oid );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<h1>Genes Assigned to a IMG Term Category</h1>\n";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/>";
    if ( $term_oid && $term_oid ne '-1') {
        print "Only IMG Term associated with <i><u>$term_oid</u></i> are shown with genes.";
    }
    else {
        print "Only genes with no IMG Term association are shown.";
    }
    print "</p>\n";

    my ( $sql, @binds ) = QueryUtil::getSingleTaxonImgTermCatGenesSql($taxon_oid, $term_oid);
    my $count = TaxonDetailUtil::printCatGeneListTable( $dbh, $sql, @binds );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllImgTermCatGenes('gene_oid');
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();

}

############################################################################
# printImgPways - Print IMG pathways.
############################################################################
sub printImgPways {
    my $taxon_oid = param("taxon_oid");

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my %assert;
    my $sql = qq{
	select g.pathway_oid, g.status, g.evidence
	    from img_pathway_assertions g
	    where g.taxon = ?
        $rclause
        $imgClause
	};
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $pathway_oid, $status, $evid ) = $cur->fetchrow();
        last if !$pathway_oid;

        #	$assert{$pathway_oid} = $status . " (" . $evid . ")";
        $assert{$pathway_oid} = $status;
    }
    $cur->finish();

    $sql = qq{
        select new.pathway_oid, new.pathway_name, count( distinct new.gene_oid )
        from (
	        select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name, g.gene_oid gene_oid
	        from gene g, gene_img_functions gif, img_reaction_catalysts irc,
	           img_pathway_reactions ipr, img_pathway ipw
	        where g.gene_oid = gif.gene_oid
	        and g.taxon = ?
	        and g.locus_type = ?
	        and gif.function = irc.catalysts
	        and irc.rxn_oid = ipr.rxn
	        and ipr.pathway_oid = ipw.pathway_oid
            $rclause
            $imgClause
	            union
	        select ipw.pathway_oid pathway_oid,
	            ipw.pathway_name pathway_name, g.gene_oid gene_oid
	        from gene g, gene_img_functions gif, img_reaction_t_components itc,
	            img_pathway_reactions ipr, img_pathway ipw
	        where g.gene_oid = gif.gene_oid
	        and g.taxon = ?
	        and g.locus_type = ?
	        and gif.function = itc.term
	        and itc.rxn_oid = ipr.rxn
	        and ipr.pathway_oid = ipw.pathway_oid
            $rclause
            $imgClause
        ) new
        group by new.pathway_oid, new.pathway_name
        order by new.pathway_oid, new.pathway_name
    };
    my @bindList = ( $taxon_oid, 'CDS', $taxon_oid, 'CDS' );

    $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    printMainForm();
    print "<h1>IMG Pathways</h1>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    printStatusLine( "Loading ...", 1 );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    #    my @rows;
    my $it = new InnerTable( 0, "taxonPathway$$", "taxonPathway", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Pathway OID",  "asc",  "right" );
    $it->addColSpec( "Pathway Name", "asc",  "left" );
    $it->addColSpec( "Assertion",    "asc",  "left" );
    $it->addColSpec( "Gene Count",   "desc", "right" );
    my $sd = $it->getSdDelim();

    my $select_id_name = "func_id";

    my $count = 0;
    for ( ; ; ) {
        my ( $pathway_oid, $pathway_name, $gene_count ) = $cur->fetchrow();
        last if !$pathway_oid;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='$select_id_name' value='IPWAY:$pathway_oid' /> \t";

        # pathway ID and name
        my $pway_oid = FuncUtil::pwayOidPadded($pathway_oid);
        my $pway_url = "$main_cgi?section=ImgPwayBrowser&page=imgPwayDetail";
        $pway_url .= "&pway_oid=$pway_oid";

        $r .= $pathway_oid . $sortDelim . alink( $pway_url, $pway_oid ) . "\t";
        $r .= "$pathway_name\t";

        # assertion
        if ( $assert{$pathway_oid} ) {
            my $assert_url =
              "$main_cgi?section=ImgPwayBrowser" . "&page=pwayTaxonDetail" . "&pway_oid=$pathway_oid&taxon_oid=$taxon_oid";
            $r .= $assert{$pathway_oid} . $sortDelim . alink( $assert_url, $assert{$pathway_oid} ) . "\t";
        } else {
            $r .= "\t";
        }

        # gene count
        my $url = "$section_cgi&page=imgPwayGeneList&pathway_oid=$pathway_oid";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        # push( @rows, $r );
        $it->addRow($r);
    }
    $cur->finish();

    #$dbh->disconnect();

    my $name = "_section_${section}_imgPwayGeneList";
    if ( $count > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count IMG pathway retrieved.", 2 );
    print end_form();
}

############################################################################
# printImgPwayGeneList - Show genes under one IMG pathway.
############################################################################
sub printImgPwayGeneList {
    my $taxon_oid = param("taxon_oid");

    my @pathway_oids = param("pathway_oid");
    if ( scalar(@pathway_oids) <= 0 ) {
        my @func_ids = param("func_id");
        foreach my $id (@func_ids) {
            if ( $id =~ /^IPWAY:/ ) {
                $id =~ s/IPWAY://;
                push( @pathway_oids, $id );
            }
        }
    }
    if ( scalar(@pathway_oids) == 0 ) {
        webError("No IMG Pathway has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $pathway_id ( @pathway_oids ) {
        print hiddenVar( "func_id", "IPWAY:$pathway_id" );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchImgPathwayId2NameHash( $dbh, \@pathway_oids, \%funcId2Name, 1 );

    print "<h1>Genes in IMG Pathway</h1>";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $id (@pathway_oids) {
        my $funcName = $funcId2Name{$id};
        print $id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene g, gene_img_functions gif,
          img_reaction_catalysts irc, img_pathway_reactions ipr
        where g.gene_oid = gif.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and gif.function = irc.catalysts
        and irc.rxn_oid = ipr.rxn
        and ipr.pathway_oid in ($funcIdsInClause)
        $rclause
        $imgClause
        order by g.gene_oid
   };
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $funcIdsInClause =~ /gtt_num_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

############################################################################
# printImgPlist - Print IMG parts list.
############################################################################
sub printImgPlist {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>IMG Parts List</h1>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
    print alink( $url, $taxon_name );
    print "</p>";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    #    my $sql = qq{
    #        select ipl.parts_list_oid, ipl.parts_list_name,
    #          count( distinct g.gene_oid )
    #        from img_parts_list ipl, img_parts_list_img_terms plt,
    #          dt_img_term_path tp, gene_img_functions g
    #        where ipl.parts_list_oid = plt.parts_list_oid
    #        and plt.term = tp.term_oid
    #        and tp.map_term = g.function
    #        and g.taxon = $taxon_oid
    #        $rclause
    #        $imgClause
    #        group by ipl.parts_list_name, ipl.parts_list_oid
    #        order by ipl.parts_list_name, ipl.parts_list_oid
    #    };
    my $sql = qq{
        select ipl.parts_list_oid, ipl.parts_list_name,
          count( distinct g.gene_oid )
        from img_parts_list ipl, img_parts_list_img_terms plt,
          gene_img_functions g
        where ipl.parts_list_oid = plt.parts_list_oid
        and plt.term = g.function
        and g.taxon = $taxon_oid
        $rclause
        $imgClause
        group by ipl.parts_list_name, ipl.parts_list_oid
        order by ipl.parts_list_name, ipl.parts_list_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $count = 0;
    my @rows;

    for ( ; ; ) {
        my ( $parts_list_oid, $parts_list_name, $gene_count ) = $cur->fetchrow();
        last if !$parts_list_oid;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='PLIST:$parts_list_oid' /> \t";

        $r .= "$parts_list_oid\t";
        $r .= "$parts_list_name\t";

        my $url = "$section_cgi&page=imgPlistGenes";
        $url .= "&parts_list_oid=$parts_list_oid";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    my $name = "_section_${section}_imgPlistGenes";
    TaxonDetailUtil::print3ColGeneCountTable(
        "partsList", \@rows,
        "Parts List ID",
        "Parts List Name",
        $section, $name, "List Genes"
    );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count IMG Parts List retrieved.", 2 );
    print end_form();
}

############################################################################
# printImgPlistGenes - Show genes under one parts list.
############################################################################
sub printImgPlistGenes {
    my $taxon_oid = param("taxon_oid");

    my @parts_list_oids = param("parts_list_oid");
    if ( scalar(@parts_list_oids) <= 0 ) {
        my @func_ids = param("func_id");
        foreach my $id (@func_ids) {
            if ( $id =~ /^PLIST:/ ) {
                $id =~ s/PLIST://;
                push( @parts_list_oids, $id );
            }
        }
    }
    if ( scalar(@parts_list_oids) == 0 ) {
        webError("No IMG Parts List has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $parts_list_id ( @parts_list_oids ) {
        print hiddenVar( "func_id", "PLIST:$parts_list_id" );
    }

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchImgPartsListId2NameHash( $dbh, \@parts_list_oids, \%funcId2Name, 1 );

    print "<h1>Genes in IMG Parts List</h1>";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $id (@parts_list_oids) {
        my $funcName = $funcId2Name{$id};
        print $id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    #my $sql = qq{
    #    select distinct g.gene_oid, g.gene_display_name
    #    from img_parts_list ipl, img_parts_list_img_terms plt,
    #      dt_img_term_path tp, gene_img_functions gif, gene g
    #    where ipl.parts_list_oid = plt.parts_list_oid
    #    and plt.term = tp.term_oid
    #    and tp.map_term = gif.function
    #    and gif.gene_oid = g.gene_oid
    #    and g.taxon = ?
    #    and ipl.parts_list_oid in ($funcIdsInClause)
    #    $rclause
    #    $imgClause
    #    order by g.gene_oid
    #};
    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from img_parts_list ipl, img_parts_list_img_terms plt,
          gene_img_functions gif, gene g
        where ipl.parts_list_oid = plt.parts_list_oid
        and plt.term = gif.function
        and gif.gene_oid = g.gene_oid
        and g.taxon = ?
        and ipl.parts_list_oid in ($funcIdsInClause)
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $funcIdsInClause =~ /gtt_num_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

############################################################################
# printTaxonPfam - Show protein famlies and count of genes.
############################################################################
sub printTaxonPfam {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<h1>Pfam Families</h1>\n";
    print "<p>\n";
    my $url = "$section_cgi&page=pfam&taxon_oid=$taxon_oid&cat=cat";
    print alink( $url, "View as Pfam Categories" );
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select pf.name, pf.ext_accession, pf.description,
          pf.db_source, count( distinct g.gene_oid )
        from gene_pfam_families gpf, pfam_family pf, gene g
        where gpf.gene_oid = g.gene_oid
        and gpf.pfam_family = pf.ext_accession
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        group by pf.name, pf.ext_accession, pf.description, pf.db_source
        having count(distinct g.gene_oid) > 0
        order by lower( pf.name ), pf.ext_accession, pf.description, pf.db_source
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $count = 0;
    my @rows;
    for ( ; ; ) {
        my ( $name, $ext_accession, $description, $db_source, $gene_count ) = $cur->fetchrow();
        last if !$name;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='$ext_accession' /> \t";

        $r .= "$ext_accession\t";

        my $x;
        $x = " - $description" if $db_source =~ /HMM/;
        $r .= "$name$x\t";

        my $url = "$section_cgi&page=pfamGeneList&ext_accession=$ext_accession";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $name = "_section_${section}_pfamGeneList";
    TaxonDetailUtil::print3ColGeneCountTable
	( 'pfam', \@rows, 'Pfam ID', 'Pfam Name', $section, $name, "List Genes" );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count Pfam retrieved.", 2 );
    print end_form();
}

############################################################################
# printTaxonPfamCat - show pfam categories for the specified genome
############################################################################
sub printTaxonPfamCat {
    my $taxon_oid = param("taxon_oid");
    my $url2 = "$section_cgi&page=pfamGeneList&taxon_oid=$taxon_oid&cat=cat";

    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    my $dbh = dbLogin();
    my $rclause   = WebUtil::urClause('s.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon_oid');
    my $sql = qq{
        select s.genes_in_pfam
        from taxon_stats s
        where s.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $total_gene_count = $cur->fetchrow();
    $cur->finish();

    my ( $taxon_name, $is_pangenome ) =
	QueryUtil::fetchSingleTaxonNameAndPangenome( $dbh, $taxon_oid );

    print "<h1>Pfam Categories</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>\n";
    print alink( $url, $taxon_name );
    print "<br/><br/>\n";
    my $purl = "$section_cgi&page=pfam&taxon_oid=$taxon_oid";
    print alink( $purl, "View as Pfam List" );
    print "</p>\n";

    use TabHTML;
    TabHTML::printTabAPILinks( "pfamcatTab", 1 );

    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("pfamcatTab");
        </script>
    };

    my @tabIndex = ( "#pfamcattab1",    "#pfamcattab2" );
    my @tabNames = ( "Pfam Categories", "Statistics by Pfam categories" );
    TabHTML::printTabDiv( "pfamcatTab", \@tabIndex, \@tabNames );

    print "<div id='pfamcattab1'>";
    my $rclause1   = WebUtil::urClause('g.taxon');
    my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql        = qq{
        select $nvl(cf.function_code, '_'),
               $nvl(cf.definition, '_'),
               count( distinct g.gene_oid )
        from gene g, gene_pfam_families gpf
        left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession
        left join cog_function cf on pfc.functions = cf.function_code
        where g.gene_oid = gpf.gene_oid
        and g.taxon = gpf.taxon
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause1
        $imgClause1
        group by cf.function_code, cf.definition
        order by cf.definition
    };

    #### PREPARE THE PIECHART #####
    my @chartcategories;
    my @functioncodes;
    my @chartdata;
    ###############################

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    my $unclassified_count = 0;
    my $unclassified_url;

    my %categoryHash;
    my $gene_count_total = 0;
    for ( ;; ) {
	my ( $function_code, $name, $gene_count ) = $cur->fetchrow();
	last if !$function_code;
	last if !$name;
	$count++;

	if ( $name eq "_" ) {
	    $name               = "unclassified";
	    $unclassified_count = $gene_count;
	    $unclassified_url   = "$section_cgi&page=pfamGeneList"
		. "&taxon_oid=$taxon_oid"
		. "&cat=cat&func_code=$function_code";
	    next;

	} else {
	    $gene_count_total += $gene_count;
	}

	push @chartcategories, "$name";
	push @functioncodes,   "$function_code";
	push @chartdata,       $gene_count;
	$categoryHash{$name} = $gene_count;
    }
    $cur->finish();

    printHint("Click on an <u>icon</u> for a given category to view genes by individual pfam IDs for that category. <br/>Click on the <u>gene count</u> for a given category or on a pie slice to view all the genes for that category.");

    my $idx = 0;
    my $d3data = "";
    foreach my $category1 (@chartcategories) {
	my $percent = 100 * $chartdata[$idx] / $gene_count_total;
	$percent = sprintf( "%.2f", $percent );

	if ($d3data) {
	    $d3data .= ",";
	} else {
	    $d3data = "[";
	}
	$d3data .= "{" .
	    "\"id\": \"" . escHtml($category1) .
	    "\", \"name\": \"" . escHtml($category1) .
	    "\", \"urlfragm\": \"" . $functioncodes[$idx] .
	    "\", \"count\": " . $chartdata[$idx] .
	    ", \"percent\": " . $percent .
	    "}";

	$idx++;
    }

    if ($d3data) {
	my $include_unclassified = 0;
	if ( $unclassified_count && $include_unclassified ) {
	    my $u_id = '_';
	    my $u_name = 'unclassified';
	    if ( $d3data ) {
		$d3data .= ',';
	    }
	    else {
		$d3data = '[';
	    }
	    $d3data .= "{\"id\": \"" . $u_id .
		"\", \"name\": \"" . $u_name .
		"\", \"urlfragm\": \"" . "" .
		"\", \"count\": " . $unclassified_count .
		"}";
	}

	$d3data .= "]";

	my $url1 = "$section_cgi&page=catePfamList&cat=cat&taxon_oid=$taxon_oid";
	my $url2 = "$section_cgi&page=pfamGeneList&cat=cat&taxon_oid=$taxon_oid";

	require D3ChartUtil;
	D3ChartUtil::printPieChart
	    ($d3data, $url1."&func_code=", $url2."&func_code=", "", 0, 1,
	     "[\"color\", \"name\", \"count\", \"percent\"]", 500, 400);
    }

    printStatusLine( "$count Pfam categories retrieved.", 2 );

    print "</div>";    # end pfamcattab1

    print "<div id='pfamcattab2'>";
    my $txTableName = "taxonPfamCategories";
    print start_form(
        -id     => $txTableName . "_frm",
        -name   => "mainForm",
        -action => "$main_cgi"
    );

    my @columns = param("outputCol");
    if ( $#columns < 0 ) {

        # add default columns
        push( @columns, "Total Pfam Genes" );
    }

    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
      QueryUtil::fetchSingleTaxonRank( $dbh, $taxon_oid );

    #$dbh->disconnect();

    print "<h2>Statistics by Pfam Categories</h2>\n";
    print "<p>";
    print "You may add or remove columns from the statistics table " . "using the configuration table below.";
    print "</p>";

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec("D");
    $it->addColSpec("C");
    $it->addColSpec( "Genome Name", "asc", "left", "", "", "wrap" );

    my $row;
    $row .= substr( $domain,     0, 1 ) . "\t";
    $row .= substr( $seq_status, 0, 1 ) . "\t";

    my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
    $row .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

    foreach my $cat (@columns) {
        if (   $cat eq "Phylum"
            || $cat eq "Class"
            || $cat eq "Order"
            || $cat eq "Family"
            || $cat eq "Genus" )
        {
            $it->addColSpec( $cat, "asc", "left", "", "", "wrap" );
        } else {
            $it->addColSpec( $cat, "asc", "right", "", "", "wrap" );
        }

        if ( $cat eq "Phylum" ) {
            $row .= $phylum . "\t";
        } elsif ( $cat eq "Class" ) {
            $row .= $ir_class . "\t";
        } elsif ( $cat eq "Order" ) {
            $row .= $ir_order . "\t";
        } elsif ( $cat eq "Family" ) {
            $row .= $family . "\t";
        } elsif ( $cat eq "Genus" ) {
            $row .= $genus . "\t";
        } elsif ( $cat eq "Total Pfam Genes" ) {
            my $cnt = $total_gene_count;
            $row .= $cnt . "\t";
        } else {
            if ( $cat =~ /percentage$/ ) {
                my $tmp = $cat;
                $tmp =~ s/ percentage//;
                my $cnt = $categoryHash{$tmp};
                if ( $total_gene_count == 0 ) {
                    $row .= "0" . "\t";
                } else {
                    $cnt = $cnt * 100 / $total_gene_count;
                    my $pc = sprintf( "%.2f%%", $cnt );
                    $row .= $pc . "\t";
                }
            } else {
                my $cnt = $categoryHash{$cat};
                $row .= $cnt . "\t";
            }
        }
    }
    $it->addRow($row);

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    # add some initial categories to be selected
    my @category_list;
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total Pfam Genes" );
    foreach my $category1 (@chartcategories) {
        last if !$category1;
        push( @category_list, $category1 );
        push( @category_list, "$category1 percentage" );
    }

    print "<h2>Configuration</h2>";

    printConfigTable( \@category_list, \@columns, $taxon_oid, "pfam", $blockDatatableCss );

    print end_form();
    print "</div>";    # end pfamcattab2
    TabHTML::printTabDivEnd();
}

############################################################################
# printPfamGeneList - Show genes under one protein family.
############################################################################
sub printPfamGeneList {

    my $taxon_oid = param("taxon_oid");
    my @pfam_ids  = param("ext_accession");
    if ( scalar(@pfam_ids) <= 0 ) {
        @pfam_ids = param("func_id");
    }

    if ( scalar(@pfam_ids) == 0 ) {
        webError("No Pfam has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $pfam_id ( @pfam_ids ) {
        print hiddenVar( "func_id", $pfam_id );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchPfamId2NameHash( $dbh, \@pfam_ids, \%funcId2Name, 1 );

    print "<h1>Pfam Genes</h1>\n";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $pfam_id (@pfam_ids) {
        my $funcName = $funcId2Name{$pfam_id};
        print $pfam_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene_pfam_families gpf, gene g
        where gpf.taxon = ?
        and gpf.pfam_family in ($funcIdsInClause)
        and gpf.gene_oid = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

############################################################################
# printCatePfamList - print category Pfam list
############################################################################
sub printCatePfamList {
    my $taxon_oid     = param("taxon_oid");
    my $function_code = param("func_code");

    printMainForm();
    print hidden( 'taxon_oid', $taxon_oid );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select cf.definition
        from cog_function cf
        where cf.function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    print "<h1>Pfam Category: " . escapeHTML($definition) . "</h1>\n";

    checkTaxonPerm( $dbh, $taxon_oid );
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    my %id_names;
    $sql = qq{
        select pf.ext_accession, pf.description
        from pfam_family pf, pfam_family_cogs pfc
        where pf.ext_accession = pfc.ext_accession
        and pfc.functions = ?
        order by 1
    };
    $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;

        $id_names{$id} = $name;
    }
    $cur->finish();

    my $clause = "and cf.function_code is null";
    if ( $function_code ne "" && $function_code ne "_" ) {
        $clause = "and cf.function_code = ? ";
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select gpf.pfam_family, count(distinct gpf.gene_oid)
        from gene g, gene_pfam_families gpf
        left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession
        left join cog_function cf on pfc.functions = cf.function_code
        where g.gene_oid = gpf.gene_oid
        and g.taxon = gpf.taxon
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $clause
        $rclause
        $imgClause
        group by gpf.pfam_family
        order by gpf.pfam_family
    };

    my @binds = ($taxon_oid);
    if ( $function_code ne "" && $function_code ne "_" ) {
        push( @binds, $function_code );
    }
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@binds, $verbose );

    my %id_counts;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $id_counts{$id} = $cnt;
    }
    $cur->finish();

    my $it = new InnerTable( 1, "catePfam$$", "catePfam", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Pfam ID",    "asc",  "left" );
    $it->addColSpec( "Pfam Name",  "asc",  "left" );
    $it->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "func_id";

    my $count = 0;
    for my $id ( sort ( keys %id_names ) ) {
        next if ( !$id_counts{$id} );

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        $r .= $id . $sd . $id . "\t";
        $r .= $id_names{$id} . $sd . $id_names{$id} . "\t";
        my $url2 = "$section_cgi&page=pfamGeneList&func_id=$id&taxon_oid=$taxon_oid";
        $r .= $id_counts{$id} . $sd . alink( $url2, $id_counts{$id} ) . "\t";
        $it->addRow($r);

        $count++;
    }

    printStatusLine( "$count pfam(s) retrieved.", 2 );

    my $name = "_section_${section}_pfamGeneList";
    if ( $count > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    print end_form();
}

############################################################################
# printPfamCatGeneList - print gene list from one pfam category
############################################################################
sub printPfamCatGeneList {
    my $taxon_oid = param("taxon_oid");
    my $func_code = param("func_code");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "func_code", $func_code ) if ( $func_code );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $definition = QueryUtil::getCKogCateDefinition($dbh, $func_code, 'cog');

    print "<h1>Pfam Genes</h1>\n";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "<br/>";
    print "Only Pfam associated with <i><u>" . escHtml($definition) . "</u></i> are shown with genes.";
    print "</p>\n";

    my ($sql, @binds) = QueryUtil::getSingleTaxonPfamCatGenesSql($taxon_oid, $func_code);
    my $count = TaxonDetailUtil::printCatGeneListTable( $dbh, $sql, @binds );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllPfamCatGenes('gene_oid');
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printTaxonTIGRfam - Show protein famlies and count of genes.
############################################################################
sub printTaxonTIGRfam {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<h1>TIGRfam Families</h1>\n";
    print "<p>\n";
    print alink( "$section_cgi&page=tigrfam&taxon_oid=$taxon_oid&cat=cat", "View as TIGRfam Categories" );
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select tf.expanded_name, tf.ext_accession,
        count( distinct gtf.gene_oid )
        from tigrfam tf, gene_tigrfams gtf, gene g
        where tf.ext_accession = gtf.ext_accession
        and gtf.gene_oid = g.gene_oid
        and g.taxon = ?
        $rclause
        $imgClause
        group by tf.expanded_name, tf.ext_accession
        having count( distinct gtf.gene_oid ) > 0
        order by lower( tf.expanded_name ), tf.ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    my @rows;

    for ( ; ; ) {
        my ( $name, $ext_accession, $gene_count ) = $cur->fetchrow();
        last if !$name;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='$ext_accession' /> \t";

        $r .= "$ext_accession\t";
        $r .= "$name\t";

        my $url = "$section_cgi&page=tigrfamGeneList" . "&ext_accession=$ext_accession" . "&taxon_oid=$taxon_oid";
        $r .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $name = "_section_${section}_tigrfamGeneList";
    TaxonDetailUtil::print3ColGeneCountTable( "tigrfam", \@rows, "TIGRfam ID", "TIGRfam Name", $section, $name,
        "List Genes" );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count TIGRfam retrieved.", 2 );
    print end_form();
}

############################################################################
# printCateTIGRfamList - print category TIGRfam list
############################################################################
sub printCateTIGRfamList {
    my $taxon_oid = param("taxon_oid");
    my $role      = param("role");

    printMainForm();
    print hidden( 'taxon_oid', $taxon_oid );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    print "<h1>TIGRfam Role: " . escapeHTML($role) . "</h1>\n";

    checkTaxonPerm( $dbh, $taxon_oid );
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    my %id_names;
    my $sql = qq{
        select tf.ext_accession, tf.expanded_name
        from tigrfam tf, tigrfam_roles trs, tigr_role t
        where tf.ext_accession = trs.ext_accession
        and trs.roles = t.role_id
        and t.main_role = ?
        order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose, $role );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $id_names{$id} = $name;
    }
    $cur->finish();

    my $clause = "and tr.main_role is null";
    if ( $role ne "" && $role ne "_" ) {
        $clause = "and tr.main_role = ? ";
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select gtf.ext_accession, count(distinct gtf.gene_oid)
        from gene g, gene_tigrfams gtf
        left join tigrfam_roles trs on gtf.ext_accession = trs.ext_accession
        left join tigr_role tr on trs.roles = tr.role_id
        where g.gene_oid = gtf.gene_oid
        and g.taxon = gtf.taxon
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $clause
        $rclause
        $imgClause
        group by gtf.ext_accession
        order by gtf.ext_accession
    };

    my @binds = ($taxon_oid);
    if ( $role ne "" && $role ne "_" ) {
        push( @binds, $role );
    }
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@binds, $verbose );

    my %id_counts;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $id_counts{$id} = $cnt;
    }
    $cur->finish();

    #$dbh->disconnect();

    my $it = new InnerTable( 1, "catePfam$$", "catePfam", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "TIGRfam ID",   "asc",  "left" );
    $it->addColSpec( "TIGRfam Name", "asc",  "left" );
    $it->addColSpec( "Gene Count",   "desc", "right" );

    my $select_id_name = "func_id";

    my $count = 0;
    for my $id ( sort ( keys %id_names ) ) {
        next if ( !$id_counts{$id} );

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        $r .= $id . $sd . $id . "\t";
        $r .= $id_names{$id} . $sd . $id_names{$id} . "\t";
        my $url2 = "$section_cgi&page=tigrfamGeneList&func_id=$id&taxon_oid=$taxon_oid";
        $r .= $id_counts{$id} . $sd . alink( $url2, $id_counts{$id} ) . "\t";
        $it->addRow($r);

        $count++;
    }

    printStatusLine( "$count TIGRfam(s) retrieved.", 2 );

    my $name = "_section_${section}_tigrfamGeneList";
    if ( $count > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    print end_form();
}

############################################################################
# printTaxonTIGRfamCat - show TIGRfam categories for the specified genome
############################################################################
sub printTaxonTIGRfamCat {
    my $taxon_oid = param("taxon_oid");
    my $url2      = "$section_cgi&page=tigrfamGeneList&cat=cat&taxon_oid=$taxon_oid";

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('s.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon_oid');

    my $sql = qq{
        select s.genes_in_tigrfam
        from taxon_stats s
        where s.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $total_gene_count = $cur->fetchrow();
    $cur->finish();

    my ( $taxon_name, $is_pangenome ) = QueryUtil::fetchSingleTaxonNameAndPangenome( $dbh, $taxon_oid );

    print "<h1>TIGRfam Roles</h1>\n";
    printStatusLine( "Loading ...", 1 );

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

    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>\n";
    print alink( $url, $taxon_name );
    print "<br/><br/>\n";
    print alink( "$section_cgi&page=tigrfam&taxon_oid=$taxon_oid", "View as TIGRfam list" );
    print "</p>\n";

    use TabHTML;
    TabHTML::printTabAPILinks( "tigrfamcatTab", 1 );
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("tigrfamcatTab");
        </script>
    };

    my @tabIndex = ( "#tigrfamcattab1", "#tigrfamcattab2" );
    my @tabNames = ( "TIGRfam Roles",   "Statistics by TIGRfam Roles" );
    TabHTML::printTabDiv( "tigrfamcatTab", \@tabIndex, \@tabNames );

    print "<div id='tigrfamcattab1'>";
    my $rclause1   = WebUtil::urClause('g.taxon');
    my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql        = qq{
        select $nvl(tr.main_role, '_'),
              count(distinct gtf.gene_oid)
        from gene g, gene_tigrfams gtf
        left join tigrfam_roles trs on gtf.ext_accession = trs.ext_accession
        left join tigr_role tr on trs.roles = tr.role_id
        where g.gene_oid = gtf.gene_oid
        and g.taxon = gtf.taxon
        and g.taxon = ?
        $rclause1
        $imgClause1
        group by tr.main_role
    };

    my $cur                = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count              = 0;
    my $unclassified_count = 0;
    my $unclassified_url;

    my %categoryHash;
    for ( ; ; ) {
        my ( $name, $gene_count ) = $cur->fetchrow();
        last if !$name;
        $count++;

        if ( $name eq "_" ) {
            $name               = "unclassified";
            $unclassified_count = $gene_count;
            $unclassified_url   = "$section_cgi&page=tigrfamGeneList"
		                . "&taxon_oid=$taxon_oid"
				. "&cat=cat" . "&role=_";
            next;
        }

        push @roles,           "$name";
        push @chartcategories, "$name";
        push @chartdata,       $gene_count;
        $categoryHash{$name} = $gene_count;
    }
    $cur->finish();

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@roles );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    printHint("Click on an <u>icon</u> for a given role to view genes by individual TIGRfam IDs for that role. <br/>Click on the <u>gene count</u> for a given role or on a pie slice to view all the genes for that role.");

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    # TIGRfam Roles table next to pie chart:
    my $it = new InnerTable( 1, "tigrfamcategories$$", "tigrfamcategories", 0 );
    my $sd = $it->getSdDelim();
    $it->hideAll();
    $it->addColSpec( "TIGRfam Roles", "asc",  "left",  "", "", "wrap" );
    $it->addColSpec( "Gene Count",    "desc", "right", "", "", "wrap" );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    foreach my $category1 (@chartcategories) {
        last if !$category1;

        my $url1 = "$section_cgi&page=cateTigrfamList";
	$url1 .= "&taxon_oid=$taxon_oid";
	$url1 .= "&cat=cat&role=$roles[$idx]";

	my $url2 = "$section_cgi&page=tigrfamGeneList";
	$url2 .= "&taxon_oid=$taxon_oid";
	$url2 .= "&cat=cat&role=$roles[$idx]";

        my $row;
        if ( $st == 0 ) {
            my $imageref = "<img src='$tmp_url/" . $chart->FILE_PREFIX
		. "-color-" . $idx . ".png' border=0>";
            $row = escHtml($category1) . $sd . alink($url1, $imageref, "", 1);
            $row .= "&nbsp;&nbsp;";
        }
        $row .= escHtml($category1) . "\t";
        $row .= $chartdata[$idx] . $sd . alink($url2, $chartdata[$idx]) . "\t";
        $it->addRow($row);
        $idx++;
    }

    # add the unclassified row:
    my $row = "xunclassified" . $sd . "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;unclassified\t";
    $row .= $unclassified_count . $sd . alink( $unclassified_url, $unclassified_count ) . "\t";
    $it->addRow($row);

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    print "<td valign=top align=left>\n";
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "printTIGRfam", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/".$chart->FILE_PREFIX.".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    print "</td></tr>\n";
    print "</table>\n";
    printStatusLine( "$count TIGRfam roles retrieved.", 2 );
    print "</div>";    # end tigrfamcattab1

    print "<div id='tigrfamcattab2'>";
    my $txTableName = "taxonTIGRfamCategories";
    print start_form(
        -id     => $txTableName . "_frm",
        -name   => "mainForm",
        -action => "$main_cgi"
    );

    my @columns = param("outputCol");
    if ( $#columns < 0 ) {

        # add default columns
        push( @columns, "Total TIGRfam Genes" );
    }

    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
      QueryUtil::fetchSingleTaxonRank( $dbh, $taxon_oid );

    #$dbh->disconnect();

    print "<h2>Statistics by TIGRfam Roles</h2>\n";
    print "<p>";
    print "You may add or remove columns from the statistics table " . "using the configuration table below.";
    print "</p>";

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec("D");
    $it->addColSpec("C");
    $it->addColSpec( "Genome Name", "asc", "left", "", "", "wrap" );

    my $row;
    $row .= substr( $domain,     0, 1 ) . "\t";
    $row .= substr( $seq_status, 0, 1 ) . "\t";

    my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
    $row .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

    foreach my $cat (@columns) {
        if (   $cat eq "Phylum"
            || $cat eq "Class"
            || $cat eq "Order"
            || $cat eq "Family"
            || $cat eq "Genus" )
        {
            $it->addColSpec( $cat, "asc", "left", "", "", "wrap" );
        } else {
            $it->addColSpec( $cat, "asc", "right", "", "", "wrap" );
        }

        if ( $cat eq "Phylum" ) {
            $row .= $phylum . "\t";
        } elsif ( $cat eq "Class" ) {
            $row .= $ir_class . "\t";
        } elsif ( $cat eq "Order" ) {
            $row .= $ir_order . "\t";
        } elsif ( $cat eq "Family" ) {
            $row .= $family . "\t";
        } elsif ( $cat eq "Genus" ) {
            $row .= $genus . "\t";
        } elsif ( $cat eq "Total TIGRfam Genes" ) {
            my $cnt = $total_gene_count;
            $row .= $cnt . "\t";
        } else {
            if ( $cat =~ /percentage$/ ) {
                my $tmp = $cat;
                $tmp =~ s/ percentage//;
                my $cnt = $categoryHash{$tmp};
                if ( $total_gene_count == 0 ) {
                    $row .= "0" . "\t";
                } else {
                    $cnt = $cnt * 100 / $total_gene_count;
                    my $pc = sprintf( "%.2f%%", $cnt );
                    $row .= $pc . "\t";
                }
            } else {
                my $cnt = $categoryHash{$cat};
                $row .= $cnt . "\t";
            }
        }
    }
    $it->addRow($row);

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    # add some initial categories to be selected
    my @category_list;
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total TIGRfam Genes" );
    foreach my $category1 (@chartcategories) {
        last if !$category1;
        push( @category_list, $category1 );
        push( @category_list, "$category1 percentage" );
    }

    print "<h2>Configuration</h2>";
    printConfigTable( \@category_list, \@columns, $taxon_oid, "tigrfam", $blockDatatableCss );

    print end_form();
    print "</div>";    # end tigrfamcattab2
    TabHTML::printTabDivEnd();
}

############################################################################
# printTIGRfamGeneList - Show genes under one protein family.
############################################################################
sub printTIGRfamGeneList {
    my $taxon_oid   = param("taxon_oid");
    my @tigrfam_ids = param("ext_accession");
    if ( scalar(@tigrfam_ids) <= 0 ) {
        @tigrfam_ids = param("func_id");
    }

    if ( scalar(@tigrfam_ids) == 0 ) {
        webError("No TIGRfam has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $tigrfam_id ( @tigrfam_ids ) {
        print hiddenVar( "func_id", $tigrfam_id );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchTIGRfamId2NameHash( $dbh, \@tigrfam_ids, \%funcId2Name, 1 );

    print "<h1>TIGRfam Genes</h1>\n";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $tigrfam_id (@tigrfam_ids) {
        my $funcName = $funcId2Name{$tigrfam_id};
        print $tigrfam_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select distinct g.gene_oid
        from gene_tigrfams gtf, gene g
        where gtf.taxon = ?
        and gtf.ext_accession in ($funcIdsInClause)
        and gtf.gene_oid = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $funcIdsInClause =~ /gtt_func_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

############################################################################
# printTIGRfamCatGeneList - print gene list for one TIGRfam category
############################################################################
sub printTIGRfamCatGeneList {
    my $taxon_oid = param("taxon_oid");
    my $role      = param("role");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "role", $role ) if ( $role );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<h1>TIGRfam Genes</h1>\n";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/>";
    print "Only TIGRfam associated with <i><u>" . escHtml($role) . "</u></i> are shown with genes.";
    print "</p>\n";

    my ($sql, @binds) = QueryUtil::getSingleTaxonTIGRfamCatGenesSql($taxon_oid, $role);
    my $count = TaxonDetailUtil::printCatGeneListTable( $dbh, $sql, @binds );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTIGRfamCatGenes('gene_oid');
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printInterPro - Show InterPro groups and count of genes in them.
############################################################################
sub printInterPro {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    print "<h1>InterPro Domains</h1>\n";
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid, 0 );
    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select giih.description, giih.id, count( distinct g.gene_oid )
        from gene_xref_families giih, gene g
        where giih.db_name = 'InterPro'
        and giih.gene_oid = g.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        group by giih.description, giih.id
        having count(distinct g.gene_oid) > 0
        order by giih.description, giih.id
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $count = 0;
    my @rows;
    for ( ; ; ) {
        my ( $name, $ext_accession, $gene_count ) = $cur->fetchrow();
        last if !$name;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='$ext_accession' /> \t";

        $r .= "$ext_accession\t";
        $r .= "$name\t";

        my $url = "$section_cgi&page=iprGeneList&ext_accession=$ext_accession";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $name = "_section_${section}_iprGeneList";
    TaxonDetailUtil::print3ColGeneCountTable( "interpro", \@rows, "InterPro ID", "InterPro Name",
        $section, $name, "List Genes" );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count InterPro retrieved.", 2 );
    print end_form();
}

############################################################################
# printInterProGeneList - Show genes under one InterPro family.
############################################################################
sub printInterProGeneList {
    my $taxon_oid = param("taxon_oid");

    my @ipr_ids = param("ext_accession");
    if ( scalar(@ipr_ids) <= 0 ) {
        @ipr_ids = param("func_id");
    }
    if ( scalar(@ipr_ids) == 0 ) {
        webError("No InterPro has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $ipr_id ( @ipr_ids ) {
        print hiddenVar( "func_id", $ipr_id );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchIprId2NameHash( $dbh, \@ipr_ids, \%funcId2Name, 1 );

    print "<h1>InterPro Genes</h1>\n";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $ipr_id (@ipr_ids) {
        my $funcName = $funcId2Name{$ipr_id};
        print $ipr_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct giih.gene_oid
        from gene_xref_families giih, gene g
        where giih.taxon = ?
        and giih.id in ($funcIdsInClause)
        and giih.db_name = 'InterPro'
        and giih.gene_oid = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $funcIdsInClause =~ /gtt_func_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

############################################################################
# printUncharGenes - Print uncharacterized genes.
############################################################################
sub printUncharGenes {
    my $taxon_oid = param("taxon_oid");

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g
        where g.locus_type not like '%RNA'
        and g.locus_type != 'CDS'
        and g.locus_type != 'pseudo'
        and g.taxon = ?
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my @gene_oids;
    my $count = 0;
    my $trunc = 0;
    my $cur   = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    if ( $count == 1 ) {
        my $gene_oid = $gene_oids[0];
        use GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }
    printMainForm();
    print "<h1>\n";
    print "Uncharacterized Genes\n";
    print "</h1>\n";
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";
    print "An <i>uncharacterized</i> gene is a gene that is not ";
    print "labeled as a protein coding 'CDS' gene,<br/>\n";
    print "a type of RNA, or a pseudogene.<br/>\n";
    print "</p>\n";

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome ID",         "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left" );
    print "<p>\n";

    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();
    print "</p>\n";

    if ( !$trunc ) {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    } else {
        printTruncatedStatus($maxGeneListResults);
    }
    print end_form();
}

############################################################################
# printKegg - Show KEGG cageories, pathways, and count of genes.
############################################################################
sub printKegg {
    my $taxon_oid = param("taxon_oid");

    print "<h1>KEGG Pathways</h1>\n";
    print "<p>\n";
    my $url = "$section_cgi&page=kegg&cat=cat&taxon_oid=$taxon_oid";
    print alink( $url, "View as KEGG Categories" );
    print "</p>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select pw.category, pw.pathway_name,
               pw.pathway_oid, count( distinct g.gene_oid )
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
             gene_ko_terms gk, gene g
        where pw.pathway_oid = roi.pathway
        and roi.roi_id = rk.roi_id
        and rk.ko_terms = gk.ko_terms
        and gk.gene_oid = g.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        group by pw.category, pw.pathway_name, pw.pathway_oid
        order by pw.category, lower( pw.pathway_name ), pw.pathway_oid
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    print "The number of genes in each KEGG pathway is shown in parentheses.";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    my $old_category;
    for ( ; ; ) {
        my ( $category, $pathway_name, $pathway_oid, $gene_count ) = $cur->fetchrow();
        last if !$category;
        $count++;
        my $url = "$section_cgi&page=keggPathwayGenes";
        $url .= "&pathway_oid=$pathway_oid";
        $url .= "&taxon_oid=$taxon_oid";
        if ( $old_category ne $category ) {
            if ( $old_category ne "" ) {
                print "<br/>\n";
            }
            print "<b>\n";
            print escHtml($category);
            print "</b>\n";
            print "<br/>\n";
        }
        print nbsp(4);
        print escHtml($pathway_name);
        print " (" . alink( $url, $gene_count ) . ")<br/>\n";
        $old_category = $category;
    }
    $cur->finish();

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "</p>\n";
    printStatusLine( "$count KEGG pathway retrieved.", 2 );
    print end_form();
}

############################################################################
# printKeggPathwayGenes - Show genes under one KEGG map.
############################################################################
sub printKeggPathwayGenes {
    my $taxon_oid   = param("taxon_oid");
    my $pathway_oid = param("pathway_oid");

    if ( $pathway_oid eq '' ) {
        webError("No KEGG has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "pathway_oid", $pathway_oid ) if ( $pathway_oid );

    print "<h1>KEGG Pathway Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = QueryUtil::getSingleTaxonKeggPathwayGenesSql();
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid, $pathway_oid );
    if ($count > 0) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllKeggPathwayGeneList('gene_oid');
    }
    printStatusLine( $s, 2 );
    print end_form();
}

# kegg cat kegg_id => cat name
# not used right now
sub getKeggCat {
    my $fh = newReadFileHandle($kegg_cat_file);
    my %hash;

    while ( my $line = $fh->getline() ) {
        my ( $kegg_id, $cat ) = split( /\t/, $line );
        $hash{$kegg_id} = $cat;
    }
    close $fh;
    return \%hash;
}

sub isColumnSelected {
    my ( $cat, $columns_aref ) = @_;
    foreach my $name (@$columns_aref) {
        if ( lc($cat) eq lc($name) ) {
            return "checked";
        }
    }
    return "";
}

############################################################################
# printConfigTable - additional columns to add for the tables
############################################################################
sub printConfigTable {
    my ( $category_list_aref, $columns_aref, $taxon_oid, $param, $blockDatatableCss ) = @_;

    my $it = new StaticInnerTable();
    $it->{blockDatatableCss} = $blockDatatableCss;

    my $sd = $it->getSdDelim();
    $it->addColSpec("Select");
    $it->addColSpec( "Column Name", "asc", "left" );

    my $checked = "";
    foreach my $cat (@$category_list_aref) {
        $checked = isColumnSelected( $cat, $columns_aref );
        my $row;
        my $row = $sd . "<input type='checkbox' $checked " . "name='outputCol' value='$cat'/>\t";
        $row .= $cat . "\t";
        $it->addRow($row);
    }

    $it->printOuterTable(1);

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "cat",       "cat" );

    my $name = "_section_${section}_$param";

#    main::submit(
#        -name  => $name,
#        -value => "Display Again",
#        -class => "meddefbutton"
#    );
    print "<input type='submit' class='meddefbutton' name='$name' value='Display again' />\n"
      . "<input id='sel' type=button name='selectAll' value='Select All' "
      . "onClick='selectAllOutputCol(1)' class='smbutton' />\n"
      . "<input id='clr' type=button name='clearAll' value='Clear All' "
      . "onClick='selectAllOutputCol(0)' class='smbutton' />\n";
}

############################################################################
# printKeggCategories - Show KEGG groups and count of genes.
############################################################################
sub printKeggCategories {
    my $taxon_oid = param("taxon_oid");
    my $url2      = "$section_cgi&page=keggCategoryGenes&taxon_oid=$taxon_oid";

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(300);
    $chart->HEIGHT(300);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url2);
    $chart->INCLUDE_SECTION_URLS("no");
    $chart->URL_SECTION_NAME("category");
    my @chartseries;
    my @chartcategories;
    my @chartdata;
    #################################

    my $dbh = dbLogin();

    # get the total
    my $rclause   = WebUtil::urClause('s.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon_oid');
    my $sql       = qq{
        select s.genes_in_kegg
        from taxon_stats s
        where s.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $total_gene_count = $cur->fetchrow();
    $cur->finish();

    my ( $taxon_name, $is_pangenome ) = QueryUtil::fetchSingleTaxonNameAndPangenome( $dbh, $taxon_oid );

    print "<h1>KEGG Categories</h1>\n";
    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "<br/><br/>\n";
    my $url = "$section_cgi&page=kegg&taxon_oid=$taxon_oid";
    print alink( $url, "View as KEGG List" );
    print "</p>\n";

    use TabHTML;
    TabHTML::printTabAPILinks( "keggcatTab", 1 );
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("keggcatTab");
        </script>
    };

    my @tabIndex = ( "#keggcattab1",    "#keggcattab2" );
    my @tabNames = ( "KEGG Categories", "Statistics by KEGG categories" );

    if ( lc($is_pangenome) eq "yes" ) {
        push @tabIndex, "#keggcattab3";
        push @tabNames, "Pangenome Composition";
    }
    TabHTML::printTabDiv( "keggcatTab", \@tabIndex, \@tabNames );

    print "<div id='keggcattab1'>";
    printStatusLine( "Loading ...", 1 );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause1   = WebUtil::urClause('g.taxon');
    my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql        = qq{
        select $nvl(pw.category, 'Unknown'), count( distinct g.gene_oid )
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
             gene_ko_terms gk, gene g
    	where pw.pathway_oid = roi.pathway
    	and roi.roi_id = rk.roi_id
    	and rk.ko_terms = gk.ko_terms
    	and gk.gene_oid = g.gene_oid
    	and g.taxon = ?
    	and g.locus_type = 'CDS'
    	and g.obsolete_flag = 'No'
        $rclause1
        $imgClause1
    	group by pw.category
    	order by pw.category
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    # KEGG categories table next to pie chart:
    my $it = new InnerTable( 1, "keggcategories$$", "keggcategories", 0 );
    my $sd = $it->getSdDelim();
    $it->hideAll();
    $it->addColSpec( "KEGG Categories", "asc",  "left",  "", "", "wrap" );
    $it->addColSpec( "Gene Count",      "desc", "right", "", "", "wrap" );

    my %categoryHash;
    for ( ; ; ) {
        my ( $category, $gene_count ) = $cur->fetchrow();
        last if !$category;
        $count++;

        push @chartcategories, "$category";
        push @chartdata,       $gene_count;
        $categoryHash{$category} = $gene_count;
    }
    $cur->finish();

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    foreach my $category1 (@chartcategories) {
        last if !$category1;

        my $catUrl = massageToUrl($category1);
        my $url    = "$section_cgi&page=keggCategoryGenes";
        $url .= "&category=$catUrl";
        $url .= "&taxon_oid=$taxon_oid";

        my $row;
        if ( $st == 0 ) {
            my $imageref = "<img src='$tmp_url/" . $chart->FILE_PREFIX
		. "-color-" . $idx . ".png' border=0>";
            if ( lc($category1) eq "unknown" ) {
                $row = "xunknown";
            } else {
                $row = escHtml($category1);
            }
            $row .= $sd . alink( $url, $imageref, "", 1 );
            $row .= "&nbsp;&nbsp;";
        }
        $row .= escHtml($category1) . "\t";
        $row .= $chartdata[$idx] . $sd . alink($url, $chartdata[$idx]) . "\t";
        $it->addRow($row);
        $idx++;
    }

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    print "<td valign=top align=left>\n";
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		($chart->FILEPATH_PREFIX . ".html", "printKeggCategories", 1);
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/".$chart->FILE_PREFIX.".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    print "</td></tr>\n";
    print "</table>\n";
    printStatusLine( "$count KEGG category retrieved.", 2 );
    print "</div>";    # end keggcattab1

    print "<div id='keggcattab2'>";
    my $txTableName = "taxonKeggCategories";
    print start_form(
        -id     => $txTableName . "_frm",
        -name   => "mainForm",
        -action => "$main_cgi"
    );

    my @columns = param("outputCol");
    if ( $#columns < 0 ) {

        # add default columns
        push( @columns, "Total KEGG Genes" );
        push( @columns, "Amino Acid Metabolism" );
        push( @columns, "Amino Acid Metabolism percentage" );
        push( @columns, "Carbohydrate Metabolism" );
        push( @columns, "Carbohydrate Metabolism percentage" );
    }

    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species ) =
      QueryUtil::fetchSingleTaxonRank( $dbh, $taxon_oid );

    #$dbh->disconnect();

    # print pangenome selection table
    #if ( lc($is_pangenome) eq "yes" ) {
    #TaxonList::printPangenomeTable($taxon_oid);
    #}

    print "<h2>Statistics by KEGG Categories</h2>";
    print "<p>";
    print "You may add or remove columns from the statistics table " . "using the configuration table below.";
    print "</p>";

    my $it = new StaticInnerTable();
    my $sd = $it->getSdDelim();
    $it->addColSpec("D");
    $it->addColSpec("C");
    $it->addColSpec( "Genome Name", "asc", "left", "", "", "wrap" );

    my $row;
    $row .= substr( $domain,     0, 1 ) . "\t";
    $row .= substr( $seq_status, 0, 1 ) . "\t";

    my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
    $row .= $taxon_name . $sd . alink( $url, $taxon_name ) . "\t";

    foreach my $cat (@columns) {
        if (   $cat eq "Phylum"
            || $cat eq "Class"
            || $cat eq "Order"
            || $cat eq "Family"
            || $cat eq "Genus" )
        {
            $it->addColSpec( $cat, "asc", "left", "", "", "wrap" );
        } else {
            $it->addColSpec( $cat, "asc", "right", "", "", "wrap" );
        }

        if ( $cat eq "Phylum" ) {
            $row .= $phylum . "\t";
        } elsif ( $cat eq "Class" ) {
            $row .= $ir_class . "\t";
        } elsif ( $cat eq "Order" ) {
            $row .= $ir_order . "\t";
        } elsif ( $cat eq "Family" ) {
            $row .= $family . "\t";
        } elsif ( $cat eq "Genus" ) {
            $row .= $genus . "\t";
        } elsif ( $cat eq "Total KEGG Genes" ) {
            my $cnt = $total_gene_count;
            $row .= $cnt . "\t";
        } else {
            if ( $cat =~ /percentage$/ ) {
                my $tmp = $cat;
                $tmp =~ s/ percentage//;
                my $cnt = $categoryHash{$tmp};
                if ( $total_gene_count == 0 ) {
                    $row .= "0" . "\t";
                } else {
                    $cnt = $cnt * 100 / $total_gene_count;
                    my $pc = sprintf( "%.2f%%", $cnt );
                    $row .= $pc . "\t";
                }
            } else {
                my $cnt = $categoryHash{$cat};
                $row .= $cnt . "\t";
            }
        }
    }
    $it->addRow($row);

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    # add some initial categories to be selected
    my @category_list;
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total KEGG Genes" );
    foreach my $category1 (@chartcategories) {
        last if !$category1;
        push( @category_list, $category1 );
        push( @category_list, "$category1 percentage" );
    }

    print "<h2>Configuration</h2>";
    printConfigTable( \@category_list, \@columns, $taxon_oid, "kegg", $blockDatatableCss );

    print end_form();
    print "</div>";    # end keggcattab2

    print "<div id='keggcattab3'>";
    if ( lc($is_pangenome) eq "yes" ) {
        TaxonList::printPangenomeTable($taxon_oid);
    }
    print "</div>";    # end keggcattab3
    TabHTML::printTabDivEnd();
}

############################################################################
# printKeggCategoryGenes - Show genes under one KEGG category.
############################################################################
sub printKeggCategoryGenes {

    my $taxon_oid  = param("taxon_oid");
    my $category   = param("category");
    my $cluster_id = param("cluster_id");    # biosynthetic cluster

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "category", $category ) if ( $category );
    print hiddenVar( "cluster_id", $cluster_id ) if ( $cluster_id );

    print "<h1>KEGG Category Genes</h1>\n";
    print "<h2>" . escHtml($category) . "</h2>\n";
    if ( $cluster_id ) {
        my $url = "main.cgi?section=BiosyntheticDetail&page=cluster_detail" .
            "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";
        print "<h5>" . alink($url, "Cluster $cluster_id") . "</h5>\n";
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my ($sql, @binds) = QueryUtil::getSingleTaxonKeggCategoryGenesSql($taxon_oid, $category, $cluster_id);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $count = 0;
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $image_id, $pathway_name ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;

        my $rec;
        $rec .= "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$image_id\t";
        $rec .= "$pathway_name";
        push( @recs, $rec );
    }
    $cur->finish();

    my $select_id_name = "gene_oid";

    WebUtil::printGeneCartFooter() if $count > 10;
    print "<p>\n";

    my %done;
    my $old_pathway_name;
    my %genes;
    my %done;
    for my $r (@recs) {
        my ( $gene_oid, $gene_display_name, $image_id, $pathway_name ) =
          split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        my $catGene = "$pathway_name\t$gene_oid";
        next if $done{$catGene} ne "";
        $done{$catGene} = 1;

        if ( $old_pathway_name ne $pathway_name ) {
            if ( $old_pathway_name ne "" ) {
                print "<br/>\n";
            }
            print "<b>\n";
            my $url = "$main_cgi?section=KeggMap&page=keggMapRelated";
            $url .= "&map_id=$image_id";
            $url .= "&taxon_oid=$taxon_oid";
            $url .= "&cluster_id=$cluster_id" if $cluster_id ne "";
            print alink( $url, $pathway_name );
            print "</b>\n";
            print "<br/>\n";
        }
        print nbsp(2);
        print "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\n";
        my $url    = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print alink( $url, $gene_oid ) . " " . escHtml("$gene_display_name");
        print "<br/>\n";

        $genes{$gene_oid} = $gene_oid;
        $old_pathway_name = $pathway_name;
    }
    print "</p>\n";
    WebUtil::printGeneCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllKeggCategoryGeneList($select_id_name);
    }

    my $count = keys(%genes);
    printStatusLine( "$count gene(s) retrieved.", 2 );

    print end_form();
}

############################################################################
# printNoKegg - Show genes that do not have KEGG mapping.
############################################################################
sub printNoKegg {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = QueryUtil::getSingleTaxonNonKeggGenesSql();
    my $title = TaxonDetailUtil::getNonKeggGenesTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid, $taxon_oid );
}

# genes connected to metacyc
sub printMetacyc {
    my $taxon_oid = param("taxon_oid");

    #### PREPARE THE PIECHART ######
    my @chartseries;
    my @chartcategories;
    my @chartdata;
    #################################

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<h1>MetaCyc Pathways</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName( $dbh, $taxon_oid );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select bp.unique_id, bp.common_name, count(distinct g.gene_oid)
        from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
        biocyc_reaction br, gene_biocyc_rxns gb, gene g
        where bp.unique_id = brp.in_pwys
        and brp.unique_id = br.unique_id
        and br.unique_id = gb.biocyc_rxn
        and br.ec_number = gb.ec_number
        and gb.gene_oid = g.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        group by bp.unique_id, bp.common_name
        order by bp.common_name
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $it = new InnerTable( 1, "MetaCycPathways$$", "MetaCycPathways", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "MetaCyc Pathway ID", "asc",  "left" );
    $it->addColSpec( "MetaCyc Pathway",    "asc",  "left" );
    $it->addColSpec( "Gene Count",         "desc", "right" );

    my $select_id_name = "func_id";

    my $count = 0;
    my @uniqueIds;
    for ( ; ; ) {
        my ( $uid, $category, $gene_count ) = $cur->fetchrow();
        last if !$category;
        $count++;

        push( @uniqueIds, $uid );
        push @chartcategories, "$category";
        push @chartdata,       $gene_count;
    }
    $cur->finish();

    #$dbh->disconnect();

    push @chartseries, "count";

    my $datastr = join( ",", @chartdata );
    my @datas   = ($datastr);

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {

    }

    my $idx = 0;
    foreach my $category1 (@chartcategories) {
        last if !$category1;
        my $catUrl = massageToUrl($category1);

        my $unique_id = $uniqueIds[$idx];
        my $url       = "$section_cgi&page=metaCycGenes";
        $url .= "&unique_id=$unique_id";
        $url .= "&taxon_oid=$taxon_oid";

        my $row;
        $row .= $sd . "<input type='checkbox' name='$select_id_name' value='MetaCyc:$unique_id' /> \t";

        my $pway_url = "$main_cgi?section=MetaCyc" . "&page=detail&pathway_id=$unique_id&taxon_oid=$taxon_oid";
        $row .= $unique_id . $sd . alink( $pway_url,  $unique_id ) . "\t";
        $row .= $category1 . $sd . $category1 . "\t";
        $row .= $chartdata[$idx] . $sd . alink( $url, $chartdata[$idx] );
        $idx++;

        $it->addRow($row);
    }

    my $name = "_section_${section}_metaCycGenes";
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" ) if $count > 10;
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    ###########################
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    printStatusLine( "$count MetaCyc retrieved.", 2 );
    print end_form();
}

# genes not connected to metacyc
sub printNoMetacyc {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = QueryUtil::getSingleTaxonNonMetacycGenesSql();
    my $title = TaxonDetailUtil::getNonMetaCycGenesTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid, $taxon_oid );

}

sub printMetacycGenes {
    my $taxon_oid  = param("taxon_oid");
    my $cluster_id = param("cluster_id");

    my @metacyc_ids = param("unique_id");
    if ( scalar(@metacyc_ids) <= 0 ) {
        my @func_ids = param("func_id");
        foreach my $id (@func_ids) {
            if ( $id =~ /^MetaCyc:/ ) {
                $id =~ s/MetaCyc://;
                push( @metacyc_ids, $id );
            }
        }
    }
    if ( scalar(@metacyc_ids) == 0 ) {
        webError("No MetaCyc Pathway has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $metacyc_id ( @metacyc_ids ) {
        print hiddenVar( "func_id", "MetaCyc:$metacyc_id" );
    }
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchMetacycId2NameHash( $dbh, \@metacyc_ids, \%funcId2Name, 1 );

    print "<h1>MetaCyc Pathway Genes</h1>";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $metacyc_id (@metacyc_ids) {
        my $funcName = $funcId2Name{$metacyc_id};
        print $metacyc_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    if ( $cluster_id ) {
        my $url = "main.cgi?section=BiosyntheticDetail&page=cluster_detail" .
            "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";
        print "<h5>" . alink($url, "Cluster $cluster_id") . "</h5>\n";
        print hiddenVar( "cluster_id", $cluster_id );
    }

    my $rclause   = WebUtil::urClause('gb.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('gb.taxon');

    my $sql;
    if ( $cluster_id ne "" ) {
        #$sql = qq{
        #    select distinct gb.gene_oid
        #    from gene_biocyc_rxns gb
        #    where gb.taxon = ?
        #    and exists (
        #        select 1 from gene g, biosynth_cluster_features bcf
        #        where g.gene_oid = gb.gene_oid
        #        and g.gene_oid = bcf.feature_oid
        #        and bcf.feature_type = 'gene'
        #        and bcf.biosynthetic_oid = $cluster_id
        #        and g.locus_type = ?
        #        and g.obsolete_flag = ?
        #    )
        #    and exists (
        #        select 1 from biocyc_reaction_in_pwys brp
        #        where brp.unique_id = gb.biocyc_rxn
        #        and brp.in_pwys in ($funcIdsInClause)
        #    )
        #    $rclause
        #    $imgClause
        #};

        $sql = qq{
            select distinct gb.gene_oid
            from gene_biocyc_rxns gb
            where gb.taxon = ?
            and exists (
                select 1 from gene g, bio_cluster_features_new bcf
                where g.gene_oid = gb.gene_oid
                and g.gene_oid = bcf.gene_oid
                and bcf.feature_type = 'gene'
                and bcf.cluster_id = $cluster_id
                and g.locus_type = ?
                and g.obsolete_flag = ?
            )
            and exists (
                select 1 from biocyc_reaction_in_pwys brp
                where brp.unique_id = gb.biocyc_rxn
                and brp.in_pwys in ($funcIdsInClause)
            )
            $rclause
            $imgClause
        };
    }
    else {
        $sql = qq{
            select distinct gb.gene_oid
            from gene_biocyc_rxns gb
            where gb.taxon = ?
            and exists (
                select 1 from gene g
                where g.gene_oid = gb.gene_oid
                and g.locus_type = ?
                and g.obsolete_flag = ?
            )
            and exists (
                select 1 from biocyc_reaction_in_pwys brp
                where brp.unique_id = gb.biocyc_rxn
                and brp.in_pwys in ($funcIdsInClause)
            )
            $rclause
            $imgClause
        };
    }

    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid, 'CDS', 'No' );

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $funcIdsInClause =~ /gtt_func_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();
}

sub printKo {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<h1>KEGG Orthology (KO)</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName( $dbh, $taxon_oid );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select kt.ko_id, kt.ko_name, kt.definition, count(distinct g.gene_oid)
        from gene g, gene_ko_terms gkt, ko_term kt
        where g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        and g.gene_oid = gkt.gene_oid
        and kt.ko_id = gkt.ko_terms
        $rclause
        $imgClause
        group by kt.ko_id, kt.ko_name, kt.definition
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable( 1, "ko$$", "ko", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "KO ID",      "asc",  "left" );
    $it->addColSpec( "Name",       "asc",  "left" );
    $it->addColSpec( "Definition", "asc",  "left" );
    $it->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "func_id";

    my $count = 0;
    for ( ; ; ) {
        my ( $id, $name, $defn, $gene_count ) = $cur->fetchrow();
        last if !$id;
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";

        my $url = "$section_cgi&page=koGenes";
        $url .= "&koid=$id";
        $url .= "&taxon_oid=$taxon_oid";

        $r .= $id . $sd . $id . "\t";
        $r .= $name . $sd . $name . "\t";
        $r .= $defn . $sd . $defn . "\t";
        $r .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";
        $it->addRow($r);
    }

    $cur->finish();

    my $name = "_section_${section}_koGenes";
    if ( $count > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count KO retrieved.", 2 );

    print end_form();
}

# genes not connected to metacyc
sub printNoKo {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = QueryUtil::getSingleTaxonNonKoGenesSql();
    my $title = TaxonDetailUtil::getNonKoGenesTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid, $taxon_oid );

}

sub printKoGenes {
    my $taxon_oid = param("taxon_oid");

    my @ko_ids = param("koid");
    if ( scalar(@ko_ids) <= 0 ) {
        @ko_ids = param("func_id");
    }

    if ( scalar(@ko_ids) == 0 ) {
        webError("No KO has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $ko_id ( @ko_ids ) {
        print hiddenVar( "func_id", $ko_id );
    }
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my %funcId2Name;
    my %funcId2Def;
    my $funcIdsInClause = TaxonDetailUtil::fetchKoid2NameDefHash( $dbh, \@ko_ids, \%funcId2Name, \%funcId2Def, 1 );

    print "<h1>KEGG Orthology (KO) Genes</h1>\n";
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=MetaDetail"
        . "&page=metaDetail&taxon_oid=$taxon_oid";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $ko_id (@ko_ids) {
        my $funcName = $funcId2Name{$ko_id};
        my $defn     = $funcId2Def{$ko_id};
        print $ko_id . ", <i><u>$funcName ($defn)</u></i><br/>\n";
    }
    print "</p>\n";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g, gene_ko_terms gkt
        where gkt.taxon = ?
        and gkt.ko_terms in ($funcIdsInClause)
        and g.gene_oid = gkt.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $funcIdsInClause =~ /gtt_func_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();

}

sub printTc {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<h1>Transport Classification</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName( $dbh, $taxon_oid );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select tf.tc_family_num, tf.tc_family_name, count(distinct g.gene_oid)
        from tc_family tf, gene_tc_families gtf, gene g
        where g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        and g.gene_oid = gtf.gene_oid
        and gtf.tc_family = tf.tc_family_num
        $rclause
        $imgClause
        group by tf.tc_family_num, tf.tc_family_name
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $count = 0;
    my @rows;
    for ( ; ; ) {
        my ( $id, $name, $gene_count ) = $cur->fetchrow();
        last if !$id;
        $count++;

        my $r;
        $r .= $sortDelim . "<input type='checkbox' name='func_id' value='$id' /> \t";

        $r .= $id . $sortDelim . $id . "\t";
        $r .= $name . $sortDelim . $name . "\t";

        my $url = "$section_cgi&page=tcGenes";
        $url .= "&tcfamid=$id";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";

        push( @rows, $r );
    }
    $cur->finish();

    #$dbh->disconnect();

    my $name = "_section_${section}_tcGenes";
    TaxonDetailUtil::print3ColGeneCountTable(
        'tc', \@rows,
        'Transporter Classification Family Number',
        'Transporter Classification Family Name',
        $section, $name, "List Genes"
    );

    printStatusLine( "$count Transporter Classification retrieved.", 2 );
    print end_form();
}

sub printTcGenes {
    my $taxon_oid = param("taxon_oid");
    my @tc_ids    = param("tcfamid");
    if ( scalar(@tc_ids) <= 0 ) {
        @tc_ids = param("func_id");
    }
    if ( scalar(@tc_ids) == 0 ) {
        webError("No Transport Classification has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $tc_id ( @tc_ids ) {
        print hiddenVar( "func_id", $tc_id );
    }
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchTcId2NameHash( $dbh, \@tc_ids, \%funcId2Name, 1 );

    print "<h1>Transport Classification Genes</h1>\n";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    print "<p style='width: 650px;'>";
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "<br/><br/>";
    for my $tc_id (@tc_ids) {
        my $funcName = $funcId2Name{$tc_id};
        print $tc_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene_tc_families gtf, gene g
        where gtf.taxon = ?
        and gtf.tc_family in ($funcIdsInClause)
        and g.gene_oid = gtf.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, $taxon_oid );

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $funcIdsInClause =~ /gtt_func_id/i );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes('gene_oid');
    }

    printStatusLine( $s, 2 );
    print end_form();

}

sub printSwissProt {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName( $dbh, $taxon_oid );

    print "<h1>SwissProt Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
    	select distinct g.gene_oid
    	from gene_swissprot_names gs, gene g
    	where gs.gene_oid = g.gene_oid
    	and g.taxon = $taxon_oid
    	and g.locus_type = 'CDS'
    	and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    my $extrasql = qq{
    	select distinct g.gene_oid, gs.product_name
    	from gene_swissprot_names gs, gene g
    	where gs.gene_oid = g.gene_oid
    	and g.taxon = $taxon_oid
    	and g.locus_type = 'CDS'
    	and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    	__replace__
    	order by g.gene_oid, gs.product_name
    };

    TaxonDetailUtil::printGeneListSectionSorting2( '', $sql, "", 1, "SwissProt Product Name", $extrasql );

}

sub printNoSwissProt {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g0.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g0.taxon');
    my $sql       = qq{
        select distinct g0.gene_oid
        from gene g0
        where g0.taxon = ?
        and g0.locus_type = 'CDS'
        and g0.obsolete_flag = 'No'
        and g0.gene_oid not in(
          select distinct g.gene_oid
    	  from gene_swissprot_names gs, gene g
    	  where gs.gene_oid = g.gene_oid
    	  and g.taxon = ?
    	  and g.locus_type = 'CDS'
    	  and g.obsolete_flag = 'No'
        )
        $rclause
        $imgClause
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Non-SwissProt Genes", "", $taxon_oid, $taxon_oid );
}

sub printSeed {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    my ($taxon_name) = QueryUtil::fetchSingleTaxonNvlName( $dbh, $taxon_oid );

    #$dbh->disconnect();
    print "<h1>SEED Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print alink( $url, $taxon_name );
    print "</p>";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
    	select distinct g.gene_oid
    	from gene_seed_names gs, gene g
    	where gs.gene_oid = g.gene_oid
    	and g.taxon = $taxon_oid
    	and g.locus_type = 'CDS'
    	and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    };

    my $extrasql = qq{
    	select distinct g.gene_oid, gs.product_name
    	from gene_seed_names gs, gene g
    	where gs.gene_oid = g.gene_oid
    	and g.taxon = $taxon_oid
    	and g.locus_type = 'CDS'
    	and g.obsolete_flag = 'No'
        $rclause
        $imgClause
    	__replace__
    	order by g.gene_oid, gs.product_name
    };

    TaxonDetailUtil::printGeneListSectionSorting2( '', $sql, "", 1, "SEED Product Name", $extrasql );
}

sub printNoSeed {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g0.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g0.taxon');
    my $sql       = qq{
        select distinct g0.gene_oid
        from gene g0
        where g0.taxon = ?
        and g0.locus_type = ?
        and g0.obsolete_flag = ?
        and g0.gene_oid not in(
          select distinct g.gene_oid
    	  from gene_seed_names gs, gene g
    	  where gs.gene_oid = g.gene_oid
    	  and g.taxon = ?
    	  and g.locus_type = ?
    	  and g.obsolete_flag = ?
        )
        $rclause
        $imgClause
    };

    my @bindList = ( $taxon_oid, 'CDS', 'No', $taxon_oid, 'CDS', 'No' );
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Non-SEED Genes", "", @bindList );
}

############################################################################
# printProteinCodingGenes - Show list of protein coding genes.
############################################################################
sub printProteinCodingGenes {
    my $taxon_oid = param("taxon_oid");
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = QueryUtil::getSingleTaxonCDSGenesSql();
    my $title = TaxonDetailUtil::getProteinCodingGenesTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid );
}

############################################################################
# printPseudoGenes - Show list of pseudo genes.
############################################################################
sub printPseudoGenes {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g0.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g0.taxon');
    my $sql       = qq{
        select distinct g0.gene_oid, g0.gene_display_name
        from gene g0
        where g0.taxon = ?
        and( g0.is_pseudogene = 'Yes'
            or g0.img_orf_type like '%pseudo%'
            or g0.locus_type = 'pseudo' )
        and g0.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Pseudo Genes", "", $taxon_oid );
}

############################################################################
# printDubiousGenes - Show list of dubious orfs.
############################################################################
sub printDubiousGenes {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $rclause   = WebUtil::urClause('g0.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g0.taxon');
    my $sql       = qq{
        select distinct g0.gene_oid, g0.gene_display_name
        from gene g0
        where g0.taxon = ?
        and g0.is_dubious_orf = 'Yes'
        and g0.obsolete_flag = 'No'
        $rclause
        $imgClause
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Dubious ORF's", "", $taxon_oid );
}

############################################################################
# printGenesWithFunc - Show genes with function.
############################################################################
sub printGenesWithFunc {
    my $taxon_oid = param("taxon_oid");
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = QueryUtil::getSingleTaxonGenesWithFuncSql();
    my $title = TaxonDetailUtil::getGeneswithFunctionPredictionTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid );
}

############################################################################
# printGenesWithoutFunc - Show genes with function.
############################################################################
sub printGenesWithoutFunc {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = QueryUtil::getSingleTaxonGenesWithoutFuncSql();
    my $title = TaxonDetailUtil::getGeneswithoutFunctionPredictionTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid );
}

############################################################################
# printMyIMGGenes - Print MyIMG annotated genes.
############################################################################
sub printMyIMGGenes {
    my $taxon_oid = param("taxon_oid");
    my $gcnt      = param("gcnt");

    printMainForm();
    print "<h1>MyIMG Annotated Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    ## --es 01/31/2007 CDS and RNA genes included.
    ## Amy: MyIMG annotation is now stored in Gene_MyIMG_functions

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    my $cclause;
    $cclause =
"and (c.contact_oid = ? or (c.img_group is not null and c.img_group = (select c2.img_group from contact c2 where c2.contact_oid = ?)))"
      if $contact_oid > 0 && $super_user ne "Yes";
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select g.gene_oid, ann.product_name, c.username
        from gene g, gene_myimg_functions ann, contact c
        where g.gene_oid = ann.gene_oid
        and g.obsolete_flag = ?
        and g.taxon = ?
        and ann.modified_by = c.contact_oid
        $cclause
        $rclause
        $imgClause
        order by g.gene_oid
    };

    #print "printMyIMGGenes \$sql: $sql<br/>\n";

    my @bindList = ( 'No', $taxon_oid );
    if ( $contact_oid > 0 && $super_user ne "Yes" ) {
        push( @bindList, $contact_oid );
        push( @bindList, $contact_oid );
    }

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my $count              = 0;
    my $trunc              = 0;
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $prev_gene_oid = 0;
    for ( ; ; ) {
        my ( $gene_oid, $annotation_text, $username ) = $cur->fetchrow();
        last if !$gene_oid;

        if ( $gene_oid != $prev_gene_oid ) {
            $count++;
        }
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }

        my $r = "$gene_oid\t";
        $r .= "$annotation_text\t";
        $r .= "$username\t";
        push( @recs, $r );

        $prev_gene_oid = $gene_oid;
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( $count == 0 ) {
        my $s    = "$count gene(s) retrieved.";
        my $diff = $gcnt - $count;
        if ( $diff > 0 ) {
            $s .= " (You do not have permission on $diff genes.)";
        }
        printStatusLine( $s, 2 );
        printMessage("You do not have permission on these genes.");
        return;
    }

    my $it = new InnerTable( 1, "MyIMGAnnotated$$", "MyIMGAnnotated", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",         "asc", "left" );
    $it->addColSpec( "Annotation Text", "asc", "left" );
    $it->addColSpec( "MyIMG User",      "asc", "left" );

    $count         = 0;
    $prev_gene_oid = 0;
    for my $r (@recs) {
        my ( $gene_oid, $annotation_text, $username ) = split( /\t/, $r );
        $count++ if ( $gene_oid != $prev_gene_oid );

        my $row = $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' ";
        if ( $gene_oid == $prev_gene_oid ) {
            $row .= "disabled='disabled' ";
        }
        $row .= "/>\t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $row .= $annotation_text . $sd . $annotation_text . "\t";
        $row .= $username . $sd . $username . "\t";

        $prev_gene_oid = $gene_oid;
        $it->addRow($row);
    }
    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( !$trunc ) {
        my $s    = "$count gene(s) retrieved.";
        my $diff = $gcnt - $count;
        if ( $diff > 0 ) {
            $s .= " (You do not have permission on $diff genes.)";
        }
        printStatusLine( $s, 2 );
    } else {
        printTruncatedStatus($maxGeneListResults);
    }
}

############################################################################
# printNoFuncGenes  - Genes w/o function and w/o homologs.
############################################################################
sub printNoFuncGenes {
    my ($taxon_oid) = @_;
    my @gene_oids = getAllNoFuncGenes($taxon_oid);
    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes w/o Function, w/o Similarity" );
}

############################################################################
# printNoFuncNoHomo  - Genes w/o function and w/o homologs.
############################################################################
#sub printNoFuncNoHomo {
#    my $taxon_oid = param("taxon_oid");
#    my @gene_oids = getNoFuncGenes( $taxon_oid, 0 );
#    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes w/o Function, w/o Similarity" );
#}

############################################################################
# printNoFuncHomo  - Genes w/o function and w/ homologs.
############################################################################
#sub printNoFuncHomo {
#    my $taxon_oid = param("taxon_oid");
#    my @gene_oids = getNoFuncGenes( $taxon_oid, 1 );
#    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes w/o Function, w/ Similarity." );
#}

############################################################################
# getNoFuncGenes - Get genes w/o function.
############################################################################
#sub getNoFuncGenes {
#    my ( $taxon_oid, $similarity ) = @_;
#    my $dbh = dbLogin();
#    my $sql = qq{
#       select distinct dt.gene_oid
#       from dt_genes_wo_func dt
#       where dt.taxon = ?
#       and dt.similarity = $similarity
#       order by dt.gene_oid
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
#    my @gene_oids;
#    for ( ; ; ) {
#        my ($gene_oid) = $cur->fetchrow();
#        last if !$gene_oid;
#        push( @gene_oids, $gene_oid );
#    }
#    $cur->finish();
#    #$dbh->disconnect();
#    return @gene_oids;
#}

############################################################################
# printObsoleteGenes - Print genes that are obsolete.
############################################################################
sub printObsoleteGenes {
    my $taxon_oid = param("taxon_oid");

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g
        where g.obsolete_flag = 'Yes'
        and g.taxon = ?
        $rclause
        $imgClause
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Obsolete Genes", "", $taxon_oid );
}

############################################################################
# printGenomeProteomics - Print genes that have associated proteomic data
############################################################################
sub printGenomeProteomics {
    my $taxon_oid = param("taxon_oid");

    my $rclause   = WebUtil::urClause('pig.genome');
    my $imgClause = WebUtil::imgClauseNoTaxon('pig.genome');
    my $sql       = qq{
        select distinct pig.gene
        from ms_protein_img_genes pig
        where pig.protein_oid > 0
        and pig.genome = ?
        $rclause
        $imgClause
    };
    TaxonDetailUtil::printGeneListSectionSorting
	( $sql, "Genes with Proteomics Data", "", $taxon_oid );
}

############################################################################
# printGenomeRNASeq - Print genes that have associated rnaseq data
############################################################################
sub printGenomeRNASeq {
    my $taxon_oid = param("taxon_oid");

    my $rclause   = WebUtil::urClause('dts.reference_taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('dts.reference_taxon_oid');
    my $datasetClause = RNAStudies::datasetClause('dts');

    my $sql       = qq{
	select distinct es.IMG_gene_oid
        from rnaseq_expression es, rnaseq_dataset dts
	where dts.reference_taxon_oid = ?
	and dts.dataset_oid = es.dataset_oid
        $datasetClause
        $rclause
        $imgClause
    };

    TaxonDetailUtil::printGeneListSectionSorting
	( $sql, "Genes with RNASeq Data", "", $taxon_oid );
}

############################################################################
# printSnpGenes - Print genes that have SNP
############################################################################
sub printSnpGenes {
    if ( !$snp_enabled ) {
        return;
    }

    my $contact_oid = getContactOid();
    my $super_user  = 'No';
    if ($contact_oid) {
        $super_user = getSuperUser();
    }

    my $taxon_oid = param("taxon_oid");

    my $rclause   = WebUtil::urClause('snp.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('snp.taxon');
    my $sql       = qq{
        select distinct snp.gene_oid
        from gene_snp snp
        where snp.taxon = ?
        $rclause
        $imgClause
    };

    if ( !$contact_oid ) {
        $sql .= " and snp.experiment in (select exp_oid from snp_experiment where is_public = 'Yes')";
    } elsif ( $super_user ne 'Yes' ) {
        $sql .=
            " and (snp.experiment in (select exp_oid from snp_experiment "
          . " where is_public = 'Yes') or snp.experiment in "
          . " (select snp_exp_permissions from contact_snp_exp_permissions "
          . " where contact_oid = $contact_oid))";
    }

    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Genes with SNP", "", $taxon_oid );
}

############################################################################
# printImgOrfTypes - Print IMG ORF types with gene counts.
############################################################################
sub printImgOrfTypes {
    my $taxon_oid = param("taxon_oid");

    print "<h1>Revised Genes</h1>\n";
    print "<p>\n";
    print "Revised genes are grouped by IMG ORF type.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.img_orf_type, iot.definition, count( distinct g.gene_oid )
        from gene g, img_orf_type iot
        where g.taxon = ?
        and g.img_orf_type is not null
        and g.img_orf_type = iot.orf_type
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        group by g.img_orf_type, iot.definition
        order by g.img_orf_type, iot.definition
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    print "<table class='img' border='1'>\n";
    print "<th class='img'>IMG<br/>ORF<br/>Type</th>\n";
    print "<th class='img'>Definition</th>\n";
    print "<th class='img'>Gene<br/>Count</th>\n";

    for ( ; ; ) {
        my ( $img_orf_type, $defintion, $gene_count ) = $cur->fetchrow();
        last if !$img_orf_type;
        print "<tr class='img'>\n";
        print "<td class='img'>" . escHtml($img_orf_type) . "</td>\n";
        print "<td class='img'>" . escHtml($defintion) . "</td>\n";
        my $url = "$section_cgi&page=imgOrfTypeGenes";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&img_orf_type=$img_orf_type";
        my $link = alink( $url, $gene_count );
        print "<td class='img' align='right'>$link</td>";
        print "</tr>\n";
    }
    print "</table>\n";
    $cur->finish();

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printSignalpGeneList - Show genes for signal peptides.
############################################################################
sub printSignalpGeneList {
    my $taxon_oid = param("taxon_oid");

    my $sql = QueryUtil::getSingleTaxonSignalGenesSql();
    my $title = TaxonDetailUtil::getSignalGenesTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid );
}

############################################################################
# printTransmembraneGeneList - Show genes for signal peptides.
############################################################################
sub printTransmembraneGeneList {
    my $taxon_oid = param("taxon_oid");

    my $sql = QueryUtil::getSingleTaxonTransmembraneGenesSql();
    my $title = TaxonDetailUtil::getTransmembraneGenesTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid );
}

############################################################################
# printImgOrfTypeGenes - Show genes belonging to an IMG ORF type.
############################################################################
sub printImgOrfTypeGenes {
    my $taxon_oid    = param("taxon_oid");
    my $img_orf_type = param("img_orf_type");

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g, img_orf_type iot
        where g.taxon = ?
        and g.obsolete_flag = 'No'
        and g.img_orf_type = ?
        and g.img_orf_type = iot.orf_type
        $rclause
        $imgClause
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Revised Genes ($img_orf_type)", "", $taxon_oid, $img_orf_type );
}

############################################################################
# printFusedGenes - Show fused genes list.
############################################################################
sub printFusedGenes {
    my $taxon_oid = param("taxon_oid");
    my @gene_oids = param("gene_oid");
    my %geneOids  = WebUtil::array2Hash(@gene_oids);

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    for my $gene_oid ( @gene_oids ) {
        print hiddenVar( "gene_oid", $gene_oid );
    }

    print "<h1>Fused Genes</h1>\n";
    print "<p>\n";
    print "The number of exemplar components (nComps) is shown.<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = QueryUtil::getSingleTaxonFusedGenesSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;

        my $r = "$cnt\t";
        $r .= "$gene_oid\t";
        $r .= "$gene_display_name\t";
        push( @recs, $r );
    }
    $cur->finish();
    my @recs2 = sort { $a <=> $b } @recs;

    my $it = new InnerTable( 1, "genelist$$", "genlist", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "nComps",            "asc", "right" );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    my $count = 0;
    for my $r (@recs2) {
        my ( $cnt, $gene_oid, $gene_display_name ) = split( /\t/, $r );
        $count++;
        my $ck = "checked" if $geneOids{$gene_oid} ne "";
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$gene_oid' " . " $ck /> \t";
        my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . "<a href='" . $url . "'>  $gene_oid </a>" . "\t";
        $r .= $gene_display_name . $sd . escHtml($gene_display_name) . "\t";
        $r .= $cnt . $sd . $cnt . "\t";
        $it->addRow($r);
    }

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace_withAllFusedGenes($select_id_name);
    }

    printStatusLine( "$count genes loaded.", 2 );
    print end_form();
}

############################################################################
# printFusionComponents - Print genes involved as fusion components.
############################################################################
sub printFusionComponents {
    my $taxon_oid = param("taxon_oid");
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g, gene_all_fusion_components gfc
        where g.gene_oid = gfc.component
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        $rclause
        $imgClause
        order by g.gene_oid
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Fusion Components", "", $taxon_oid );
}

#
# prints taxon's list of all cassette genes
#
sub printCassetteGenes {
    my $taxon_oid = param("taxon_oid");

    my $sql = QueryUtil::getSingleTaxonCassetteGenesSql();
    my $title = TaxonDetailUtil::getCassetteGenesTitle();
    TaxonDetailUtil::printGeneListSectionSorting1( $taxon_oid, $sql, $title, "", $taxon_oid );
}

############################################################################
# printRevisedGenes - Print genes that have been revised.
############################################################################
sub printRevisedGenes {
    my ($taxon_oid) = @_;

    my $maxGeneListResults0 = getSessionParam("maxGeneListResults");
    $maxGeneListResults = $maxGeneListResults0 if $maxGeneListResults0 > 0;

    print "<h1>Revised Genes</h1>\n";
    print "<p>\n";
    print "Revised genes have IMG ORF type annotation shown in bold.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );
    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    #my $sql       = qq{
    #    select g.gene_oid, ge.enzymes
    #    from gene g, gene_ko_enzymes ge
    #    where g.obsolete_flag = 'No'
    #    and g.img_orf_type is not null
    #    and g.gene_oid = ge.gene_oid
    #    and g.taxon = ?
    #    $rclause
    #    $imgClause
    #};
    #my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    #my %geneEnzymes;
    #for ( ; ; ) {
    #    my ( $gene_oid, $enzyme ) = $cur->fetchrow();
    #    last if !$gene_oid;
    #    $geneEnzymes{$gene_oid} .= "$enzyme,";
    #}
    #$cur->finish();

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.img_orf_type
        from gene g
        where  g.obsolete_flag = 'No'
        and g.img_orf_type is not null
        and g.taxon = ?
        order by g.gene_oid
    };
    my @binds = ($taxon_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    printMainForm();
    print "<p>\n";
    WebUtil::printGeneCartFooter();
    my $count = 0;
    my $trunc = 0;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $img_orf_type ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' />\n";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print alink( $url, $gene_oid );
        print nbsp(1);
        print escHtml($gene_display_name);
        print nbsp(1);
        print "<b>\n";
        print escHtml("($img_orf_type)");
        print "</b>\n";
        print "<br/>\n";
    }
    print "</p>\n";
    WebUtil::printGeneCartFooter() if $count > 10;
    print end_form();

    #$dbh->disconnect();
    if ($trunc) {
        printTruncatedStatus($maxGeneListResults);
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
}

############################################################################
# downloadFastaFile - Download FASTA file.
############################################################################
sub downloadFastaFile {
    my ( $taxon_oid, $dir, $fileExt ) = @_;
    my $displayType = param("type");
    my $fileSuffix  = lastPathTok($dir);

    timeout( 60 * 180 );    # 3 hours

    $taxon_oid = sanitizeInt($taxon_oid);
    my $downloadExt = "txt";

    my $dbh = dbLogin();
    my %scaffold_oids;
    if ( $fileExt eq "fna" && $dir eq $taxon_fna_dir ) {
        my $rclause   = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
        my $sql       = qq{
            select s.scaffold_oid, s.ext_accession
            from scaffold s
            where s.taxon = ?
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ; ; ) {
            my ( $scaffold_oid, $ext_accession ) = $cur->fetchrow();
            last if ( !$scaffold_oid );
            $scaffold_oids{$ext_accession} = $scaffold_oid;
        }
        $cur->finish();
    }

    checkTaxonPermHeader( $dbh, $taxon_oid );

    #$dbh->disconnect();
    my $path = "$dir/$taxon_oid.$fileExt";
    if ( !-e $path ) {
        webErrorHeader("File does not exist for download.");
    }
    my $sz = fileSize($path);

    # lets account for the oids bytes to be printed inthe files
    #
    my $plus_size;
    foreach my $key ( keys %scaffold_oids ) {
        my $sid = $scaffold_oids{$key};
        $plus_size .= "$sid ";
    }
    use bytes;
    $plus_size = bytes::length($plus_size);
    $sz        = $sz + $plus_size;

    # Download as file or view in browser radio
    print "Content-type: text/plain\n";
    print "Content-Disposition: attachment; filename=$taxon_oid-$fileSuffix.$downloadExt\n"
      if ( $displayType eq "file" );
    print "Content-length: $sz\n";
    print "\n";

    my $rfh = newReadFileHandle( $path, "downloadFastaFile" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        if ( $fileExt eq "fna" && $dir eq $taxon_fna_dir && $s =~ "^>" ) {
            $s =~ s/>//;
            my @tmp = split( /\s/, $s );
            my $x   = $tmp[0];              # should be ext_acces
            my $sid = $scaffold_oids{$x};
            print ">$sid $s\n";
        } else {
            print "$s\n";
        }
    }
    close $rfh;
}

sub downloadTaxonFaaFile {
    my $taxon_oid = param("taxon_oid");
    downloadFastaFile( $taxon_oid, $taxon_faa_dir, "faa" );
}

sub downloadTaxonAltFaaFile {
    my $taxon_oid = param("taxon_oid");
    downloadFastaFile( $taxon_oid, $taxon_alt_faa_dir, "alt.faa" );
}

sub downloadTaxonFnaFile {
    my $taxon_oid = param("taxon_oid");
    downloadFastaFile( $taxon_oid, $taxon_fna_dir, "fna" );
}

sub downloadTaxonReadsFnaFile {
    my $taxon_oid = param("taxon_oid");
    downloadFastaFile( $taxon_oid, $taxon_reads_fna_dir, "reads.fna" );
}

sub downloadTaxonGenesFnaFile {
    my $taxon_oid = param("taxon_oid");
    downloadFastaFile( $taxon_oid, $taxon_genes_fna_dir, "fna" );
}

sub downloadTaxonIntergenicFnaFile {
    my $taxon_oid = param("taxon_oid");
    downloadFastaFile( $taxon_oid, $taxon_intergenic_fna_dir, "fna" );
}

############################################################################
# downloadTaxonGenesFile - Download genes file for all orfs of this genome.
# no longer used
############################################################################
sub downloadTaxonGenesFile {
    my $taxon_oid = param("taxon_oid");
    $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();
    checkTaxonPermHeader( $dbh, $taxon_oid );

    my $in_file = 0;
    if ($include_metagenomes) {
        $in_file = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
        timeout( 60 * 20 );    # timeout in 20 minutes
    }

    if ( $in_file && !-e "$cgi_tmp_dir/$taxon_oid.genes.xls" ) {
        use bytes;
        my %geneInfo;
        my $mer_data_dir = $env->{mer_data_dir} . "/$taxon_oid/assembled";

#gene_oid Start Coord End Coord Strand GC Locus Tag Gene Symbol Description Scaffold Name MyIMG_Annotation
#2004233015 179 922 - 0.39 U_BL_aaa16b08.b1 Uncharacterized conserved protein Mouse Gut Community lean1 : mgutLn1_U_BL_aaa16b08_b1
        my $rfh = newReadFileHandle("$mer_data_dir/gene.tbl");
        while ( my $line = $rfh->getline() ) {
            chomp $line;
            my @data = split( /\t/, $line );

            #0 integer (I don't know what that is)
            #1 gene_oid
            #2 locus_tag
            #3 locus_type (e.g., CDS)
            #4 locus_tag again
            #5 rna symbol
            #6 start_coord
            #7 end_coord
            #8 strand
            #9 scaffold_oid
            #10 text (I don't know what that is)
            my %tmp = (
                locus_tag    => $data[2],
                start_coord  => $data[6],
                end_coord    => $data[7],
                strand       => $data[8],
                scaffold_oid => $data[9],
                symbol       => $data[5],
            );
            $geneInfo{ $data[1] } = \%tmp;

            # $sizeInBytes += bytes::length($data[1]);
            # $sizeInBytes += bytes::length($data[2]);
            # $sizeInBytes += bytes::length($data[6]);
            # $sizeInBytes += bytes::length($data[7]);
            # $sizeInBytes += bytes::length($data[8]);
            # $sizeInBytes += bytes::length($data[9]);
            # $sizeInBytes += bytes::length($data[5]);
            # $sizeInBytes = $sizeInBytes + 9 * bytes::length("\t");
            # $sizeInBytes = $sizeInBytes + bytes::length("\n");
        }
        close $rfh;

        my (%names) = MetaUtil::getGeneProdNamesForTaxon( $taxon_oid, 'assembled' );
        for my $gene_oid ( keys %names ) {
            my $tmp_href = $geneInfo{$gene_oid};
            $tmp_href->{name} = $names{$gene_oid};

            #$sizeInBytes += bytes::length($names{$gene_oid});
        }

        my $wfh = newWriteFileHandle("$cgi_tmp_dir/$taxon_oid.genes.xls");

        # print "Content-type: application/vnd.ms-excel\n";
        # print "Content-Disposition: inline; filename=$taxon_oid.genes.xls\n";
        # print "Content-length: $sizeInBytes\n";
        # print "\n";
        print $wfh "gene_oid\t"
          . "Start Coord\t"
          . "End Coord\t"
          . "Strand\t" . "GC\t"
          . "Locus Tag\t"
          . "Gene Symbol\t"
          . "Description\t"
          . "Scaffold Name\t"
          . "MyIMG_Annotation\n";
        foreach my $geneOid ( sort keys %geneInfo ) {
            my $tmp_href = $geneInfo{$geneOid};
            print $wfh $geneOid . "\t";
            print $wfh $tmp_href->{start_coord} . "\t";
            print $wfh $tmp_href->{end_coord} . "\t";
            print $wfh $tmp_href->{strand} . "\t";
            print $wfh "" . "\t";
            print $wfh $tmp_href->{locus_tag} . "\t";
            print $wfh $tmp_href->{symbol} . "\t";
            print $wfh $tmp_href->{name} . "\t";
            print $wfh $tmp_href->{scaffold_oid} . "\t";
            print $wfh "" . "\n";
        }
        close $wfh;
    }
    my $path = "$genes_dir/$taxon_oid.genes.xls";
    if ($in_file) {
        $path = "$cgi_tmp_dir/$taxon_oid.genes.xls";
    }
    my $sz = fileSize($path);

    #print "Content-type: text/plain\n";
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: inline; filename=$taxon_oid.genes.xls\n";
    print "Content-length: $sz\n";
    print "\n";
    my $rfh = newReadFileHandle( $path, "downloadTaxonGenes" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}

############################################################################
# downloadTaxonAnnotFile - Download annotations file for all orfs of this
#   genome.
############################################################################
sub downloadTaxonAnnotFile {
    my $taxon_oid = param("taxon_oid");
    $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();
    checkTaxonPermHeader( $dbh, $taxon_oid );

    #$dbh->disconnect();
    my $sid  = getSessionId();
    my $path = "$cgi_tmp_dir/$taxon_oid.$sid.annot.xls";
    if ( !( -e $path ) ) {
        webErrorHeader( "Session of annotation download has expired. " . "Please start again." );
    }
    my $sz = fileSize($path);

    #print "Content-type: text/plain\n";
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: inline; filename=$taxon_oid.annot.xls\n";
    print "Content-length: $sz\n";
    print "\n";
    my $rfh = newReadFileHandle( $path, "downloadTaxonAnnotFile" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}
############################################################################
# downloadTaxonInfoFile - Download information file for all orfs of this
#   genome.
############################################################################
sub downloadTaxonInfoFile {
    my $taxon_oid = param("taxon_oid");
    $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();
    checkTaxonPermHeader( $dbh, $taxon_oid );

    #$dbh->disconnect();
    my $sid  = getSessionId();
    my $path = "$cgi_tmp_dir/$taxon_oid.$sid.info.xls";
    if ( !( -e $path ) ) {
        webErrorHeader( "Session of information download has expired. " . "Please start again." );
    }
    my $sz = fileSize($path);

    #print "Content-type: text/plain\n";
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: inline; filename=$taxon_oid.info.xls\n";
    print "Content-length: $sz\n";
    print "\n";
    my $rfh = newReadFileHandle( $path, "downloadTaxonInfoFile" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}

############################################################################
# downloadArtemisFile - Download artemis file.
#   Return status:
#    0 - file does not exist, session expired.
#    1 - processed ok.
############################################################################
sub downloadArtemisFile {
    my ($download) = @_;
    my $pid        = param("pid");
    my $type       = param("type");

    sleep(1);    # to avoid clash in rendering from previous page?

    $pid = sanitizeInt($pid);

    my $ext;
    $ext = "gbk"  if $type eq "gbk";
    $ext = "embl" if $type eq "embl";

    my $dir  = WebUtil::getGenerateDir();
    my $path = "$dir/$pid.$ext";
    webLog("downloadArtemisFile: '$path'\n")
      if $verbose >= 1;
    if ( !( -e $path ) ) {
        return 0;
    }
    my $sz = fileSize($path);
    if ($download) {
        my $fileName = "$pid.$ext";
        my $sz       = fileSize($path);
        print "Content-type: application/artemis\n";
        print "Content-Disposition: inline; filename=$fileName\n";
        print "Content-length: $sz\n";
    } else {
        print "Content-type: text/plain\n";
    }
    print "\n";
    my $rfh = newReadFileHandle( $path, "downloadTaxonAnnotFile" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
    return 1;
}

############################################################################
# printArtemisForm - Print form for generating GenBank file.
############################################################################
sub printArtemisForm {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

    my $sql = qq{
        select count(*)
        from scaffold s
        where s.taxon = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($scaffold_count) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
        select s.scaffold_oid, s.ext_accession, s.scaffold_name, ss.seq_length
        from scaffold s, scaffold_stats ss
        where s.taxon = ?
        and s.taxon = ss.taxon
        and s.scaffold_oid = ss.scaffold_oid
        $rclause
        $imgClause
        order by ss.seq_length desc, s.ext_accession
    };

    GenerateArtemisFile::printGenerateForm( $dbh, $sql, $taxon_oid, '', '', $scaffold_count );

}

############################################################################
# printTaxonExtLinks - Print external links information.
############################################################################
sub printTaxonExtLinks {
    my ( $dbh, $taxon_oid ) = @_;

    my $s;

    $s .= "<tr class='img'>\n";
    $s .= "<th class='subhead'>External Links</th>\n";

    my $rclause   = WebUtil::urClause('t.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');

    # contact oid 400 - no download button - special user sets
    my $sql1 = qq{
select s.contact
from taxon t, submission s
where t.SUBMISSION_ID = s.submission_id
and t.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql1, $verbose, $taxon_oid );
    my ( $gbpContactId ) = $cur->fetchrow();


    my $sql = qq{
        select distinct t.db_name, t.id, t.custom_url
        from taxon_ext_links t
        where t.taxon_oid = ?
        $rclause
        $imgClause
        order by t.db_name, t.id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    $s .= "<td class='img'>\n";
    my $count = 0;

    my $ncbi_link_count     = 0;
    my $ncbi_link_count_max = 5;
    my $pubmed_link_count   = 0;

    my $jgi_portal_url_str;
    my $jgi_portal_url;
    for ( ; ; ) {
        my ( $db_name, $id, $custom_url ) = $cur->fetchrow();
        last if !$id;
        my $dbId = "$db_name:$id";
        if ( $db_name eq "PUBMED" && $pubmed_base_url ne "" ) {
            next if ( $pubmed_link_count > $ncbi_link_count_max );
            my $url = "$pubmed_base_url$id";
            $s .= alink( $url, "$dbId" );
            $pubmed_link_count++;
        } elsif ( ( $db_name =~ /NCBI/ || $db_name =~ /RefSeq/ )
            && $ncbi_entrez_base_url ne "" )
        {
            next if ( $ncbi_link_count > $ncbi_link_count_max );
            my $url = "$ncbi_entrez_base_url$id";
            $s .= alink( $url, "$dbId" );
            $ncbi_link_count++;
        } elsif ( $db_name eq "JGI Portal" && $custom_url ne '' && $gbpContactId ne '400' ) {

            # icon
            my $icon_url = qq{
               <img style='border:none; vertical-align:text-top;'
                 src='$base_url/images/genomeProjects_icon.gif' />
            };
            my $url = "$custom_url";
            $jgi_portal_url     = $url;
            $jgi_portal_url_str = alink( $url, "$icon_url JGI Portal", "", 1 );

            # add onClick="_gaq.push(['_trackEvent', 'Download Data', 'JGI Portal']);"
            $s .=
qq{<a href="$url" onClick="_gaq.push(['_trackEvent', 'Download Data', 'JGI Portal', '$taxon_oid']);" > $icon_url JGI Portal </a>};

        } elsif ( $db_name eq "ACLAME" ) {
            my $url = "$aclame_base_url$id";
            $s .= alink( $url, "$dbId" );
        } elsif ( $db_name eq "GCAT" ) {
            my $url = "$gcat_base_url$id";
            $s .= alink( $url, "$dbId" );
        } elsif ( $db_name eq "GreenGenes" ) {
            my $url = "$greengenes_base_url$id";
            $s .= alink( $url, "$dbId" );
        }
        ## db_name serves as URL for free form URL's, while ID's display
        #  the link.
        elsif ( $custom_url =~ /^http/ ) {
            $s .= alink( $custom_url, $id );
        }

        $s .= "; ";
    }
    chop $s;
    chop $s;

    $cur->finish();
    $s .= nbsp(1) if $count == 0;
    $s .= "</td>\n";
    $s .= "</tr>\n";

    # return the html code to jgi portal
    return ( $jgi_portal_url_str, $jgi_portal_url, $s );
}

############################################################################
# printDeletedGeneList - Show list of deleted genes from previous version.
############################################################################
sub printDeletedGeneList {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();

    printMainForm();
    print "<h1>Deleted Genes</h1>\n";
    print "<p>\n";
    print "Genes deleted from an earlier version of IMG\n";
    print "due to lack of mapping.\n";
    print "</p>\n";
    if ( !WebUtil::tableExists( $dbh, "unmapped_genes_archive" ) ) {
        webLog( "printDeletedGeneList: table 'unmapped_genes_archive' " . "does not exist\n" );
        printStatusLine( "0 gene(s) retrieved", 2 );
        return;
    }
    my $sql = qq{
        select uga.old_gene_oid, uga.locus_tag, uga.gene_display_name, uga.taxon_name
        from unmapped_genes_archive uga
        where uga.old_taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    print "<p>\n";
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_name, $taxon_name ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;

        my $url = "$section_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print alink( $url, $gene_oid );

        print nbsp(1);
        print escHtml("$locus_tag $gene_name [$taxon_name]");
        print "<br/>\n";
    }
    print "</p>\n";
    $cur->finish();
    printStatusLine( "$count gene(s) retrieved", 2 );

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# printTaxonGenomeProp - Show genome properties for taxon.
#     --es 10/18/2007
############################################################################
sub printTaxonGenomeProp {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my %asserted;
    getAssertedGenomeProperties( $dbh, $taxon_oid, \%asserted );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select gp.prop_accession, gp.name prop_name, count( gxf.gene_oid ) gcount
        from gene_xref_families gxf, genome_property gp,
          property_step ps, property_step_evidences pse, gene g
        where gxf.gene_oid = g.gene_oid
        and g.taxon = ?
        and gxf.id = pse.query
        and pse.step_accession = ps.step_accession
        and ps.genome_property = gp.prop_accession
        $rclause
        $imgClause
        group by gp.prop_accession, gp.name
           union
        select gp.prop_accession, gp.name prop_name, count( gpf.gene_oid ) gcount
        from gene_pfam_families gpf, genome_property gp,
          property_step ps, property_step_evidences pse, gene g
        where gpf.gene_oid = g.gene_oid
        and g.taxon = ?
        and gpf.pfam_family = pse.query
        and pse.step_accession = ps.step_accession
        and ps.genome_property = gp.prop_accession
        $rclause
        $imgClause
        group by gp.prop_accession, gp.name
        order by prop_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    my $count = 0;
    printMainForm();
    print "<h1>Genome Property (Experimental)</h1>\n";
    printStatusLine( "Loading ...", 1 );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    print "The number of genes of each property is shown in parentheses.<br/>\n";
    print "Asserted properties have all required steps ";
    print "evidenced by genes in the current genome.<br/>\n";
    print "Asserted properties are shown in red.<br/>\n";
    print "</p>\n";
    print "<p>\n";

    for ( ; ; ) {
        my ( $prop_accession, $prop_name, $gene_count ) = $cur->fetchrow();
        last if !$prop_accession;
        $count++;
        my $url = "$section_cgi&page=genomePropGeneList";
        $url .= "&prop_accession=$prop_accession";
        $url .= "&taxon_oid=$taxon_oid";
        print "<font color='red'>" if $asserted{$prop_accession};
        print escHtml($prop_name);
        print "</font>" if $asserted{$prop_accession};
        print " (" . alink( $url, $gene_count ) . ")<br/>\n";
    }
    print "</p>\n";
    $cur->finish();

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    printStatusLine( "$count genome properties retrieved.", 2 );
    print end_form();
}

############################################################################
# printGenomePropGeneList - Show genes under one IMG pathway.
############################################################################
sub printGenomePropGeneList {
    my $taxon_oid      = param("taxon_oid");
    my $prop_accession = param("prop_accession");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene_xref_families gxf, genome_property gp,
          property_step ps, property_step_evidences pse, gene g
        where gxf.gene_oid = g.gene_oid
        and g.taxon = ?
        and gxf.id = pse.query
        and pse.step_accession = ps.step_accession
        and ps.genome_property = gp.prop_accession
        and gp.prop_accession = ?
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $prop_accession );
    my @gene_oids;
    my %done;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid};
        push( @gene_oids, $gene_oid );
        $done{$gene_oid} = 1;
    }
    $cur->finish();

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene_pfam_families gpf, genome_property gp,
          property_step ps, property_step_evidences pse, gene g
        where gpf.gene_oid = g.gene_oid
        and g.taxon = ?
        and gpf.pfam_family = pse.query
        and pse.step_accession = ps.step_accession
        and ps.genome_property = gp.prop_accession
        and gp.prop_accession = ?
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $prop_accession );
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid};
        push( @gene_oids, $gene_oid );
        $done{$gene_oid} = 1;
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( scalar(@gene_oids) == 1 ) {
        my $gene_oid = $gene_oids[0];
        require GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }

    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes in Genome Property" );
}

############################################################################
# printHorTransferred - Show levels of horizontal transfer
############################################################################
sub printHorTransferred {
    my $taxon_oid = param("taxon_oid");

    print "<h1>Putative Horizontally Transferred Genes</h1>";

    my $dbh        = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );

    printStatusLine( "Loading ...", 1 );
    my ( $seq_status, $domain, $phylum, $class, $order, $family, $genus, $species ) =
      QueryUtil::fetchSingleTaxonRank( $dbh, $taxon_oid );

    my $url   = "$section_cgi&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link  = alink( $url, "<i>$taxon_name</i>", "", 1 );
    my $link2 = alink( $url, "$taxon_name", "", 1 );

    print "<p>";
    print "<b>Query Genome: $link2 </b><br/>\n";
    print "<b>Lineage:</b> $domain, $phylum, " . "$class, $order, $family, $genus $species";
    print "</p>";
    printHint( "Only the origin of horizontal transfer "
          . "is shown below for each external gene "
          . "related to the query gene. "
          . "The gene counts in $link for each level "
          . "are not additive." );
    print "<br/>";

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select hth.phylo_level, hth.phylo_val, g.gene_oid
        from gene g, dt_ht_hits hth
        where g.gene_oid = hth.gene_oid
        and g.taxon = ?
        and hth.rev_gene_oid is not null
        $rclause
        $imgClause
        order by hth.phylo_level, hth.phylo_val
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my %phyloVal2Level;
    my %level2PhyloVals;
    my %phyloVal2Genes;
    $level2PhyloVals{domain} = {};
    $level2PhyloVals{phylum} = {};
    $level2PhyloVals{class}  = {};
    $level2PhyloVals{order}  = {};
    $level2PhyloVals{family} = {};
    $level2PhyloVals{genus}  = {};
    $phyloVal2Genes{domain}  = {};
    $phyloVal2Genes{phylum}  = {};
    $phyloVal2Genes{class}   = {};
    $phyloVal2Genes{order}   = {};
    $phyloVal2Genes{family}  = {};
    $phyloVal2Genes{genus}   = {};

    for ( ; ; ) {
        my ( $phylo_level, $phylo_val, $gene_oid ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $phylo_val eq "unclassified";
        $phyloVal2Level{$phylo_val}                    = $phylo_level;
        $level2PhyloVals{$phylo_level}->{"$phylo_val"} = 1;
        $phyloVal2Genes{$phylo_val}->{$gene_oid}       = 1;
    }
    $cur->finish();

    # get outisde count, genes that are HT in more than one phyla
    # phyla_level_phlya_val => outside count
    my %outside_hash;
    my $sql = qq{
        select hth.phylo_level, hth.phylo_val as inside,
            count(distinct g.gene_oid) as outside_cnt
        from gene g, dt_ht_hits hth
        where g.gene_oid = hth.gene_oid
        and g.taxon = ?
        and hth.rev_gene_oid is null
        $rclause
        $imgClause
        group by hth.phylo_level, hth.phylo_val

    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $phylo_level_in, $phylo_val_in, $outside_cnt ) = $cur->fetchrow();
        last if !$phylo_level_in;
        $outside_hash{ $phylo_level_in . "_" . $phylo_val_in } = $outside_cnt;
    }
    $cur->finish();

    #$dbh->disconnect();

    print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
        <style type="text/css">
	.img-hor-bgColor {
	    background-color: #DBEAFF;
	}
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Likely Origin of Horizontal Transfer</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span title='Query genomes genes with best hits to genes of genomes within'>
		    Based on best hits
		 </span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span title='Query genomes genes with no hits to genes of other genomes in the phylogenetic group of query genome'>
		   Based on all hits
		</span>
	    </div>
	</th>
YUI

    printPhyloLevelVals( $taxon_oid, "domain", \%level2PhyloVals, \%phyloVal2Genes, $domain, \%outside_hash );
    printPhyloLevelVals( $taxon_oid, "phylum", \%level2PhyloVals, \%phyloVal2Genes, $phylum, \%outside_hash );
    printPhyloLevelVals( $taxon_oid, "class",  \%level2PhyloVals, \%phyloVal2Genes, $class,  \%outside_hash );
    printPhyloLevelVals( $taxon_oid, "order",  \%level2PhyloVals, \%phyloVal2Genes, $order,  \%outside_hash );
    if ($img_internal) {
        printPhyloLevelVals( $taxon_oid, "family", \%level2PhyloVals, \%phyloVal2Genes, $family, \%outside_hash );
        printPhyloLevelVals( $taxon_oid, "genus",  \%level2PhyloVals, \%phyloVal2Genes, $genus,  \%outside_hash );
    }
    print "</table>\n";
    print "</div>\n";
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printHtRow - Print horizontal transfer row.,
############################################################################
sub printHtRow {
    my ( $taxon_oid, $level2Cnt_href, $level ) = @_;

    print "<tr class='img'>\n";
    my $link = "0";
    my $cnt  = $level2Cnt_href->{$level};
    my $url  = "$section_cgi&page=horTransferredLevel";
    $url .= "&taxon_oid=$taxon_oid&phylo_level=$level";
    $link = alink( $url, $cnt ) if $cnt > 0;
    print "<td class='img'>$level</td>\n";
    print "<td class='img' align='right'>$link</td>\n";
    print "</tr>\n";
}

############################################################################
# printPhyloLevelVals - Print phylogenetic level and it's values.
############################################################################
sub printPhyloLevelVals {
    my ( $taxon_oid, $level, $level2PhyloVals_href, $phyloVal2Genes_href, $querylabel,, $outside_href ) = @_;

    my $label = substr( $level, 0, 1 );
    $label =~ tr/a-z/A-Z/;
    $label .= substr( $level, 1 );

    my $idx      = 0;
    my $classStr = "yui-dt-first img-hor-bgColor";

    print "<tr class='$classStr'>\n";
    print "<td class='$classStr' colspan=3>";
    print "<div class='yui-dt-liner'>";
    if ( $querylabel ne "" ) {
        print "<b>$label ($querylabel)</b>\n";
    } else {
        print "<b>$label </b>\n";
    }
    print "</div>\n";
    print "</td>\n";

    my $vals_href = $level2PhyloVals_href->{$level};
    my @vals      = sort( keys(%$vals_href) );
    for my $val (@vals) {
        $classStr = !$idx ? "yui-dt-first " : "";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";

        print "<tr class='$classStr'>\n";
        my $val2 = massageToUrl($val);

        print "<td class='$classStr'>";
        print "<div class='yui-dt-liner'>";
        if ( $level eq "domain" ) {
            my $url =
                "$main_cgi?section=HorizontalTransfer&page=$level"
              . "&taxon_oid=$taxon_oid"
              . "&phylo_level=$level"
              . "&phylo_val=$val";
            $url = alink( $url, $val );
            print nbsp(2) . "$url\n";
        } elsif ( $level eq "phylum"
            || $level eq "class"
            || $level eq "order"
            || $level eq "family"
            || $level eq "genus" )
        {

            # HT table listing to a url
            my $url =
                "$main_cgi?section=HorizontalTransfer&page=$level"
              . "&taxon_oid=$taxon_oid"
              . "&phylo_level=$level"
              . "&phylo_val=$val";
            $url = alink( $url, $val );
            print nbsp(2) . "$url\n";
        } else {
            print nbsp(2) . "$val\n";
        }
        print "</div>\n";
        print "</td>\n";

        my $link       = "0";
        my $genes_href = $phyloVal2Genes_href->{$val};
        my $cnt        = keys(%$genes_href);
        my $url        = "$section_cgi&page=horTransferredLevelVal";
        $url .= "&taxon_oid=$taxon_oid&phylo_level=$level";
        $url .= "&phylo_val=$val2";
        $link = alink( $url, $cnt ) if $cnt > 0;
        print "<td class='$classStr' style='text-align:right;'>\n";
        print "<div class='yui-dt-liner'>";
        print $link;
        print "</div>\n";
        print "</td>\n";

        my $out_cnt = $outside_href->{ $level . "_" . $val };
        print "<td class='$classStr' style='text-align:right;'>\n";
        print "<div class='yui-dt-liner'>";
        if ( $out_cnt ne "" ) {

            # IE bug fix &not == &not;
            # change to &nnot
            my $url = "$main_cgi?section=HorizontalTransfer";
            $url .= "&page=outsidegenelist";
            $url .= "&taxon_oid=$taxon_oid";
            $url .= "&phylo_level=$level";
            $url .= "&phylo_val=$val2";
            $url .= "&nnot_phylo_val=$querylabel";
            $url = alink( $url, $out_cnt );
            print $url;
        } else {
            print nbsp(1);
        }
        print "</div>\n";
        print "</td>\n";
        $idx++;
        print "</tr>\n";
    }

    # do not print blank row if at least row was already printed
    return if ($idx);
    $classStr = "yui-dt-first yui-dt-even";

    print "<tr class='$classStr'>\n";
    for ( my $i = 0 ; $i < 3 ; $i++ ) {
        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>";
        print nbsp(1);
        print "</div>\n";
        print "</td>\n";
    }
    print "<tr/>\n";
}

############################################################################
# printHorTransferredLevel - Print horizontally transferred gene list.
############################################################################
sub printHorTransferredLevel {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_level = param("phylo_level");

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g, dt_ht_hits hth
        where g.gene_oid = hth.gene_oid
        and g.taxon = ?
        and g.obsolete_flag = 'No'
        and hth.phylo_level = ?
        and hth.rev_gene_oid is not null
        $rclause
        $imgClause
        order by g.gene_oid
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Putative Horizontally Transferred Genes",
        "", $taxon_oid, $phylo_level );
}

############################################################################
# printHorTransferredLevelVal - Print horizontally transferred gene list.
############################################################################
sub printHorTransferredLevelVal {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_level = param("phylo_level");
    my $phylo_val   = param("phylo_val");
    printStatusLine( "Loading ...", 1 );

    my $dbh        = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );

    print qq{
        <h1>
        Genes in $taxon_name<br/>
        with Best Hits to Genes from $phylo_val </h1>
    };

    printMainForm();

    my $clobberCache = 1;
    my $it = new InnerTable( $clobberCache, "ht_hits$$", "ht_hits", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene<br/>Object<br/>Identifier", "asc", "left" );
    $it->addColSpec( "Product Name",                   "asc", "left" );
    $it->addColSpec( "From<br/>Gene",                  "asc", "left" );
    $it->addColSpec( "From<br/>Product",               "asc", "left" );
    $it->addColSpec( "From<br/>Genome",                "asc", "left" );
    my $sd = $it->getSdDelim();

    my $rclause   = WebUtil::urClause('tx2');
    my $imgClause = WebUtil::imgClause('tx2');

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name,
           g2.gene_oid, g2.gene_display_name,
           tx2.taxon_oid, tx2.taxon_display_name
        from gene g, dt_ht_hits hth, gene g2, taxon tx2
        where g.gene_oid = hth.gene_oid
        and g.taxon = ?
        and g.obsolete_flag = 'No'
        and hth.phylo_level = ?
        and hth.phylo_val = ?
        and hth.rev_gene_oid is not null
        and hth.homolog = g2.gene_oid
        and g2.taxon = tx2.taxon_oid
        $rclause
        $imgClause
        order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $phylo_level, $phylo_val );
    my %genes;
    my $count = 0;

    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $homolog, $gene_display_name2, $taxon_oid, $taxon_display_name ) =
          $cur->fetchrow();
        last if !$gene_oid;
        $count++;

        my $r;

        $r .= $sd . "<input type='checkbox' name='gene_oid' " . "value='$gene_oid' />\t";

        my $url = "$main_cgi?section=GeneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= "$gene_display_name\t";

        my $url = "$main_cgi?section=GeneDetail&gene_oid=$homolog";
        $r .= $homolog . $sd . alink( $url, $homolog ) . "\t";
        $r .= "$gene_display_name2\t";

        my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        $it->addRow($r);
        $genes{$gene_oid} = $gene_oid;
    }
    $cur->finish();

    #$dbh->disconnect();

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    my $nGenes = keys(%genes);
    printStatusLine( "$nGenes genes loaded.", 2 );
    print end_form();
}

############################################################################
# getAssertedGenomeProperties - Get asserted genome properties.
#    A property is asserted if all the required steps are evidenced.
############################################################################
sub getAssertedGenomeProperties {
    my ( $dbh, $taxon_oid, $asserted_ref ) = @_;

    my $sql = qq{
        select ps.genome_property, count( step_accession )
        from property_step ps
        where ps.is_required = 1
        group by ps.genome_property
        order by ps.genome_property
    };
    my %requiredCount;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $genome_property, $cnt ) = $cur->fetchrow();
        last if !$genome_property;
        $requiredCount{$genome_property} = $cnt;
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select gp.prop_accession prop_accession,
          count( distinct ps.step_accession ) cnt
        from gene_xref_families gxf, genome_property gp,
          property_step ps, property_step_evidences pse, gene g
        where gxf.gene_oid = g.gene_oid
        and g.taxon = ?
        and gxf.id = pse.query
        and pse.step_accession = ps.step_accession
        and ps.genome_property = gp.prop_accession
        and ps.is_required = 1
        $rclause
        $imgClause
        group by gp.prop_accession
           union
        select gp.prop_accession prop_accession,
          count( distinct ps.step_accession ) cnt
        from gene_pfam_families gpf, genome_property gp,
          property_step ps, property_step_evidences pse, gene g
        where gpf.gene_oid = g.gene_oid
        and g.taxon = ?
        and gpf.pfam_family = pse.query
        and pse.step_accession = ps.step_accession
        and ps.genome_property = gp.prop_accession
        and ps.is_required = 1
        $rclause
        $imgClause
        group by gp.prop_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    my %propCount;
    for ( ; ; ) {
        my ( $prop_accession, $cnt ) = $cur->fetchrow();
        last if !$prop_accession;
        my $rcnt = $requiredCount{$prop_accession};
        $asserted_ref->{$prop_accession} = 1 if $cnt >= $rcnt && $rcnt > 0;
    }
    $cur->finish();
}

# NEW for ER - ken
### This subroutine is likely to be OBSOLETE, as the table "gene_with_similarity"does not exist.
sub printImgTermsSimilarity() {
    my $taxon_oid = param("taxon_oid");
    my $dbh       = dbLogin();
    printStatusLine( "Loading ...", 1 );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    # see CompareGenomes::getSimilarityCount();
    # on why i use minus
    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene g
        where g.taxon = ?
        and g.gene_oid in (
            select gs.gene_oid
            from gene_with_similarity gs
            where gs.taxon = ?
            minus
            select gf2.gene_oid
            from gene_img_functions gf2, gene_with_similarity gs2
            where gf2.gene_oid = gs2.gene_oid
            and gs2.taxon = ?
        )
        $rclause
        $imgClause
        order by 1
    };

    printImgTermsSimilarityGeneList( $sql, "Genes without IMG Terms with Similarity",
        "", $taxon_oid, $taxon_oid, $taxon_oid );

    #$dbh->disconnect();
}

#
# prints gene list for genes without img terms
# with similarity
#
### This subroutine is likely OBSOLETE
sub printImgTermsSimilarityGeneList {
    my ( $sql, $title, $notitlehtmlesc, @binds ) = @_;

    printMainForm();
    print "<h1>\n";
    if ( defined $notitlehtmlesc ) {
        print $title . "\n";
    } else {
        print escHtml($title) . "\n";
    }
    print "</h1>\n";
    print nbsp(1);

    my $id          = "_section_MissingGenes_similarity";
    my $buttonLabel = "Search Similarity *";
    my $buttonClass = "meddefbutton";
    print submit(
        -name  => $id,
        -value => $buttonLabel,
        -class => $buttonClass
    );

    print nbsp(1);

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "Genome ID",           "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left"  );

    printStatusLine( "Loading ...", 1 );
    print "<p>\n";
    print "&nbsp;&nbsp;&nbsp;&nbsp; " . "* Search Similarity only searches <b>first</b> selected gene.<br><br>\n";

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my @gene_oids;
    my $count = 0;
    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }
    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        push( @gene_oids, $gene_oid );
    }
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    print "</p>\n";
    $cur->finish();

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# hasNuclotideData - Has DNA sequence data.  This is to avoid showing
#   the download links for proxy gene data.
############################################################################
sub hasNucleotideData {
    my ( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('s.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon_oid');
    my $sql       = qq{
        select s.total_gatc
        from taxon_stats s
        where s.taxon_oid = ?
    };
#        $rclause
#        $imgClause
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# genomesInPangenome
############################################################################
sub genomesInPangenome {
    my ( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('t.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql       = qq{
    	select count(distinct t.pangenome_composition)
    	from taxon_pangenome_composition t
    	where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getPangenomeIds - returns the taxon_oids making up this pangenome
############################################################################
sub getPangenomeIds {
    my ( $dbh, $taxon_oid ) = @_;

    my $rclause   = WebUtil::urClause('t.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql       = qq{
        select distinct t.pangenome_composition
        from taxon_pangenome_composition t
        where t.taxon_oid = ?
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @taxon_oids;
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        push( @taxon_oids, $id );
    }
    $cur->finish();
    return \@taxon_oids;
}

############################################################################
# hasPhylumDistGenes - See if there's phylum distribution of genes.
############################################################################
sub hasPhylumDistGenes {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select t.taxon_oid
        from dt_phylum_dist_genes t
        where t.taxon_oid = ?
        and rownum < 2
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

############################################################################
# getShortDomain
# Domains(D):
# *=Microbiome, B=Bacteria, A=Archaea, E=Eukarya,
# P=Plasmids, G=GFragment, V=Viruses.
# Also for seq_status
# F=Finished, P=Permanent Draft, D=Draft.

############################################################################
sub getShortDomain {
    my ($value) = @_;
    $value =~ s/^\s+|\s+$//g;

    return '*' if ( $value eq 'Microbiome' );

    my $strlen = length($value);
    if ( $strlen eq 0 ) {
        return '';
    } elsif ( $strlen eq 1 ) {
        return $value;
    } else {
        return substr $value, 0, 1;
    }

}

#
#
# for ncbi only submission use / add: and s.contact = 361
#
sub getGeneCalling {
    my($dbh, $submission_id) = @_;
    my $sql = qq{
select s.gene_calling_flag
from submission s
where s.submission_id = ?
and s.contact = 361
    };

    my $cur = execSql( $dbh, $sql, $verbose, $submission_id );
    my ($geneCalling) = $cur->fetchrow();

    if($geneCalling =~ /^No/ || $geneCalling eq '') {
        $geneCalling = 'No';
    }

    return $geneCalling;
}

1;

