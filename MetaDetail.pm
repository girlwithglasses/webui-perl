############################################################################
# MetaDetail.pm - Show taxon detail page. (use files)
# $Id: MetaDetail.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
# *** THIS CODE needs to be merged into TaxonDetail ***
############################################################################
package MetaDetail;
my $section = "MetaDetail";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use Archive::Zip;
use WebConfig;
use JgiMicrobesConfig;
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
use MetaUtil;
use FileHandle;
use HashUtil;
use MetaGeneTable;
use TaxonDetailUtil;
use WorkspaceUtil;
use CombinedSample;
use PhyloUtil;
use AnalysisProject;

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
my $cmr_jcvi_ncbi_project_id_base_url = $env->{cmr_jcvi_ncbi_project_id_base_url};

my $aclame_base_url       = $env->{aclame_base_url};
my $gcat_base_url         = $env->{gcat_base_url};
my $greengenes_base_url   = $env->{greengenes_base_url};
my $img_internal          = $env->{img_internal};
my $img_lite              = $env->{img_lite};
my $user_restricted_site  = $env->{user_restricted_site};
my $public_nologin_site  = $env->{public_nologin_site};
my $enable_workspace = $env->{enable_workspace};
my $no_restricted_message = $env->{no_restricted_message};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $mgtrees_dir           = $env->{mgtrees_dir};
my $show_mgdist_v2        = $env->{show_mgdist_v2};
my $show_private          = $env->{show_private};
my $img_geba              = $env->{img_geba};
my $img_edu               = $env->{img_edu};
my $use_img_gold          = $env->{use_img_gold};
my $img_pheno_rule        = $env->{img_pheno_rule};
my $img_pheno_rule_saved  = $env->{img_pheno_rule_saved};
my $snp_enabled           = $env->{snp_enabled};
my $enable_biocluster     = $env->{enable_biocluster};

my $kegg_cat_file               = $env->{kegg_cat_file};
my $include_taxon_phyloProfiler = $env->{include_taxon_phyloProfiler};
my $include_ht_stats            = $env->{include_ht_stats};
my $YUI                         = $env->{yui_dir_28};
my $img_mer_submit_url          = $env->{img_mer_submit_url};
my $img_er_submit_url           = $env->{img_er_submit_url};

my $mer_data_dir = $env->{mer_data_dir};

my $scaffold_cart = $env->{scaffold_cart};

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

my $MIN_FILE_SIZE = 100; # in bytes - ken

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

# Alex Chang - stuff
my $max_scaffold_list = 10000;

# For 2nd order list.
my $max_scaffold_results = 20000;

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    timeout( 60 * $merfs_timeout_mins );

    my $sid = getContactOid();

    my $page = param("page");

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

        #        my $st = downloadArtemisFile(0);
        #        if ( !$st ) {
        #            webError("Session for viewing expired.  Please try again.");
        #        }
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadArtemisFile") ne "" ) {

        #        my $st = downloadArtemisFile(1);
        #        if ( !$st ) {
        #            webError("Session for download expired.  Please try again.");
        #        }
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonFaaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonFaaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonAltFaaFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonAltFaaFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonGenesFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonGenesFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonAnnotFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonAnnotFile();
        WebUtil::webExit(0);
    } elsif ( paramMatch("downloadTaxonInfoFile") ne "" ) {

        #        checkAccess();
        #        downloadTaxonInfoFile();
        WebUtil::webExit(0);
    } elsif ( $page eq "metaDetail" ) {

        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printTaxonDetail_ImgGold();
        HtmlUtil::cgiCacheStop();

    } elsif ( paramMatch("searchScaffolds") ne ""
        || defined( param("scaffoldSearchTerm") ) )
    {
        printScaffoldSearchResults();
    } elsif ( paramMatch("addToScaffoldCart") ne "" ) {
        addToScaffoldCart();
    } elsif ( $page eq "metaScaffoldDetail"
        || paramMatch("metaScaffoldDetail") ne "" )
    {
        printMetaScaffoldDetail();
    } elsif ( $page eq "metaScaffoldGenes"
        || paramMatch("metaScaffoldGenes") ne "" )
    {
        printMetaScaffoldGenes();
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
    } elsif ( $page eq "scaffoldsLengthBreakDown" ) {
        scaffoldsLengthBreakDown();
    } elsif ( $page eq "geneCountScaffoldDist" ) {
        printScaffolds('gene_count');
    } elsif ( $page eq "seqLengthScaffoldDist" ) {
        printScaffolds('seq_length');
    } elsif ( $page eq "scaffoldsByReadDepth" ) {
        printScaffoldReadDistribution();
    } elsif ( $page eq "readDepthScaffoldDist" ) {
        printScaffolds('read_depth');
    } elsif ( $page eq "scaffolds" || paramMatch("scaffolds") ne "" ) {
        printScaffolds();
    } elsif ( $page eq "listScaffolds" ) {
        listScaffolds();
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
    } elsif ( $page eq "uniqueGenes" ) {
        printUniqueGenes();
    } elsif ( $page eq "rnas" ) {
        printRnas();
    } elsif ( $page eq "cogs"
        || paramMatch("cogs") ne "" )
    {
        my $cat = param("cat");
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        if ( $cat ne "" ) {
            printCogCategories();
        } else {
            printTaxonCog();
        }
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "cogGeneList" ) {
        my $cat = param("cat");
        if ( $cat ne "" ) {
            printCogGeneListCat();
        } else {
            printCogGeneList();
        }
    } elsif ( $page eq "cateCogList" ) {
        printCateCogList();
    } elsif ( paramMatch("cogGeneList") ne "" ) {
        printCogGeneList();
    } elsif ( $page eq "enzymeGeneList"
        || paramMatch("enzymeGeneList") ne "" )
    {
        printEnzymeGeneList();
    } elsif ( $page eq "enzymes" ) {
        printTaxonEnzymes();
    } elsif ( $page eq "imgTerms" ) {
        my $cat  = param("cat");
        my $tree = param("tree");
        if ( $cat ne "" ) {
            printImgTermsCat();
        } elsif ( $tree ne "" ) {
            printImgTermsTree();
        } else {
            printImgTerms();
        }
    } elsif ( $page eq "imgTermGeneList" ) {
        my $cat = param("cat");
        if ( $cat ne "" ) {
            printImgTermCatGeneList();
        } else {
            printImgTermGeneList();
        }
    } elsif ( $page eq "imgPways" ) {
        printImgPways();
    } elsif ( $page eq "imgPwayGeneList" ) {
        printImgPwayGeneList();
    } elsif ( $page eq "imgPlist" ) {
        printImgPlist();
    } elsif ( $page eq "imgPlistGenes" ) {
        printImgPlistGenes();
    } elsif ( $page eq "genomeProp" ) {
        printTaxonGenomeProp();
    } elsif ( $page eq "catePfamList" ) {
        printCatePfamList();
    } elsif ( $page eq "pfamGeneList"
        || paramMatch("pfamGeneList") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ne "" ) {
            printPfamCatGeneList();
        } else {
            printPfamGeneList();
        }
    } elsif ( $page eq "cateTigrfamList" ) {
        printCateTigrfamList();
    } elsif ( $page eq "tigrfamGeneList"
        || paramMatch("tigrfamGeneList") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ne "" ) {
            printTIGRfamCatGeneList();
        } else {
            printTIGRfamGeneList();
        }
    } elsif ( $page eq "pfam"
        || paramMatch("pfam") ne "" )
    {
        my $cat = param("cat");
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        if ( $cat ne "" ) {
            printTaxonPfamCat();
        } else {
            printTaxonPfam();
        }
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "tigrfam"
        || paramMatch("tigrfam") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ne "" ) {
            printTaxonTIGRfamCat();
        } else {
            printTaxonTIGRfam();
        }
    } elsif ( $page eq "genomePropGeneList" ) {
        printGenomePropGeneList();
    } elsif ( $page eq "ipr" ) {
        printInterPro();
    } elsif ( $page eq "iprGeneList" ) {
        printInterProGeneList();
    } elsif ( $page eq "kegg"
        || paramMatch("kegg") ne "" )
    {
        my $cat = param("cat");
        if ( $cat ne "" ) {
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
    } elsif ( $page eq "tc" ) {
        printTc();
    } elsif ( $page eq "tcGenes" ) {
        printTcGenes();
    } elsif ( $page eq "noKo" ) {
        printNoKo();
    } elsif ( $page eq "koGenes"
        || paramMatch("koGenes") ne "" )
    {
        printKoGenes();
    } elsif ( $page eq "ko" ) {
        printKo();
    } elsif ( $page eq "proteinCodingGenes" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printProteinCodingGenes();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "withFunc" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printGenesWithFunc();
        HtmlUtil::cgiCacheStop();
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
    } elsif ( $page eq "fusionComponents" ) {
        printFusionComponents();
    } elsif ( $page eq "horTransferred" ) {
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
    } elsif ( $page eq "statsProfile" ) {
        printTaxonStatsProfile();
    } elsif ( $page eq "geneFuncStatsList" ) {
        printGeneFuncStatsList();
    } elsif ( $page eq "addGeneCart"
        || paramMatch("addGeneCart") ne "" )
    {
        require CartUtil;
        CartUtil::addFuncGenesToGeneCart();
    } else {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printTaxonDetail_ImgGold();
        HtmlUtil::cgiCacheStop();

    }
}

#
# plasmid list
#
sub printPlasmidDetails {
    my $taxon_oid = param("taxon_oid");

    print "<h1>Plasmid Gene Counts</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    my $sql = qq{
        select s.scaffold_oid, s.scaffold_name, count(distinct g.gene_oid)
        from gene g, scaffold s
        where g.scaffold = s.scaffold_oid
        and s.mol_type = 'plasmid'
        and g.taxon = s.taxon
        and g.obsolete_flag = 'No'
        and s.taxon  = ?
        group by s.scaffold_oid, s.scaffold_name
    };

    my $cur   = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    my $it    = new InnerTable( 1, "Plasmid$$", "Plasmid", 0 );
    my $sd    = $it->getSdDelim();                                # sort delimiter
    $it->addColSpec( "Scaffold Name", "char asc",   "left" );
    $it->addColSpec( "Gene Count",    "number asc", "right" );
    my $url = "$section_cgi&page=plasmidgenelist&taxon_oid=$taxon_oid&scaffold_oid=";

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

    print "<h1>Plasmid Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    my $sql = qq{
        select g.gene_oid
        from gene g, scaffold s
        where g.scaffold = s.scaffold_oid
        and s.mol_type = 'plasmid'
        and g.taxon = s.taxon
        and g.taxon = $taxon_oid
        and s.scaffold_oid = $scaffold_oid
        and g.obsolete_flag = 'No'
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
    };
    TaxonDetailUtil::printGeneListSectionSorting2( '', $sql, "", 1, "Scaffold Name", $extrasql );
}

#
#  genomes Crispr list
#
sub printCrisprDetails {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    if ( !$isTaxonInFile ) {
        TaxonDetail::printCrisprDetails();
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print qq{
        <h1>Genome CRISPR list</h1>
    };
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name );

    my @recs = QueryUtil::getTaxonCrisprList( $dbh, $taxon_oid );

    my $it = new InnerTable( 1, "Crispr$$", "Crispr", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Scaffold Name", "asc", "left" );
    $it->addColSpec( "Start Coord",   "asc", "right" );
    $it->addColSpec( "End Coord",     "asc", "right" );

    # MER-FS
    my $select_id_name = "scaffold_oid";

    my $count = 0;
    for my $rec (@recs) {
        my ( $contig_id, $start, $end, $crispr_no ) = split( /\t/, $rec );

        # find a nice starting point - ken
        my $tmp = $start - 25000;
        $tmp = 1 if ( $tmp < 1 );

        my $tmp_end = $end + 25000;

        my $url =
            "$main_cgi?section=MetaScaffoldGraph"
          . "&page=metaScaffoldGraph"
          . "&taxon_oid=$taxon_oid&scaffold_oid=$contig_id"
          . "&start_coord=$tmp"
          . "&end_coord=$tmp_end";
        $url = alink( $url, $contig_id );

        my $r;
        my $workspace_id = "$taxon_oid assembled $contig_id";
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$workspace_id' />\t";

        $r .= $contig_id . $sd . $url . "\t";
        $r .= $start . $sd . $start . "\t";
        $r .= $end . $sd . $end . "\t";
        $it->addRow($r);

        $count++;
    }

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
# printPhenotypeInfo - Show phenotype info based on pathway assertion
############################################################################
sub printPhenotypeInfo {
    my ($taxon_oid) = @_;

    print "<tr class='highlight'>\n";
    print "<th class='subhead'>" . "Phenotypes/Metabolism from Pathway Assertion" . "</th>\n";

    my $dbh = dbLogin();
    my $sql;
    my $cur;
    my $cnt = 0;

    if ($img_pheno_rule_saved) {

        # use saved result
        $sql = qq{
        select distinct r.rule_id, r.cv_type, r.cv_value, r.name,
        c.username, to_char(rt.mod_date, 'yyyy-mm-dd')
        from phenotype_rule r, phenotype_rule_taxons rt, contact c
        where rt.taxon = ?
        and rt.rule_id = r.rule_id
        and rt.modified_by = c.contact_oid (+)
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

            #       $str .= " ($c_name; $mod_date)";

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

    printMainForm();
    print "<h1>Genome Phenotype Rule Inference Detail</h1>\n";
    my $dbh = dbLogin();
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
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
                select status from img_pathway_assertions
                    where pathway_oid = $pathway_oid
                    and taxon = $taxon_oid
                    order by mod_date desc
                };
            $cur = execSql( $dbh, $sql, $verbose );
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
        where p.rule_id = $rule_id
        and p.taxon = $taxon_oid
        and p.modified_by = c.contact_oid
    };
    $cur = execSql( $dbh, $sql, $verbose );
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

############################################################################
# printTaxonStatsProfile
############################################################################
sub printTaxonStatsProfile {
    my $taxon_oid = param('taxon_oid');
    my $data_type = param('data_type');

    printMainForm();
    print "<h1>Gene Statistics Profile</h1>\n";

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    $taxon_oid = sanitizeInt($taxon_oid);
    my $stats_file = $mer_data_dir . "/$taxon_oid/";
    if ( $data_type eq 'assembled' ) {
        $stats_file .= "assembled/stats_profile.txt";
    } elsif ( $data_type eq 'unassembled' ) {
        $stats_file .= "unassembled/stats_profile.txt";
    } else {
        webError("No data -- incorrect data type $data_type.");
    }

    if ( !( -e $stats_file ) ) {
        webError("No data -- missing file $stats_file");
    }

    # check whether there are gene stats file for each function type
    my %has_gene_stats_file;
    for my $functype2 ( 'cog', 'pfam', 'tigr', 'ec', 'ko', 'phylo' ) {
        my $fname2 = $mer_data_dir . "/$taxon_oid/";
        if ( $data_type eq 'assembled' ) {
            $fname2 .= "assembled/gene_" . $functype2 . "_stats.zip";
        } elsif ( $data_type eq 'unassembled' ) {
            $fname2 .= "unassembled/gene_" . $functype2 . "_stats.zip";
        }

        if ( -e $fname2 ) {
            $has_gene_stats_file{$functype2} = 1;
        }
    }

    # read data from file
    my $fh = newReadFileHandle($stats_file);
    if ( !$fh ) {
        return;
    }
    my $line_no = 0;
    my $line    = "";
    my $bucket  = 0;
    my @fields  = ();
    my %total_h;
    print "<table class='img'  border='1' >\n";
    while ( $line = $fh->getline() ) {
        chomp $line;
        if ( $line_no == 0 ) {

            # header
            print "<tr class='img' bgcolor='lightgray'>\n";
            @fields = split( /\t/, $line );
            for my $fld (@fields) {
                print "<th class='subhead'>$fld</th>\n";
                $total_h{$fld} = 0;
            }
            print "</tr>\n";
        } else {
            my (@vals) = split( /\t/, $line );
            if ( ( $line_no % 2 ) == 0 ) {
                print "<tr class='img' bgcolor='lightblue'>\n";
            } else {
                print "<tr class='img'>\n";
            }
            my $j = 0;
            for my $v2 (@vals) {
                if ( $j == 0 ) {
                    my (@str) = split( / /, $v2 );
                    if ( scalar(@str) > 0 && WebUtil::isInt( $str[0] ) ) {
                        $bucket = floor( $str[0] / 10 ) + 1;
                    }
                }

                if ( WebUtil::isInt($v2) && $j > 0 && $j < scalar(@fields) ) {
                    my $fld_name = $fields[$j];
                    $total_h{$fld_name} += $v2;

                    my $link_type = "";
                    if ( $v2 > 0 ) {
                        if (   $fld_name =~ /COG/
                            && $has_gene_stats_file{'cog'} )
                        {
                            $link_type = "cog";
                        } elsif ( $fld_name =~ /Pfam/
                            && $has_gene_stats_file{'pfam'} )
                        {
                            $link_type = "pfam";
                        } elsif ( ( $fld_name =~ /TIGR/ || $fld_name =~ /Tigr/ )
                            && $has_gene_stats_file{'tigr'} )
                        {
                            $link_type = "tigr";
                        } elsif ( $fld_name =~ /Enzyme/
                            && $has_gene_stats_file{'ec'} )
                        {
                            $link_type = "ec";
                        } elsif ( $fld_name =~ /KO/
                            && $has_gene_stats_file{'ko'} )
                        {
                            $link_type = "ko";
                        } elsif ( $fld_name =~ /dist/
                            && $has_gene_stats_file{'phylo'} )
                        {
                            $link_type = "phylo";
                        }

                        if ($link_type) {

                            # add hyperlink
                            my $url =
                                "$main_cgi?section=MetaDetail"
                              . "&page=geneFuncStatsList"
                              . "&taxon_oid=$taxon_oid&data_type=$data_type"
                              . "&func_type="
                              . $link_type
                              . "&bucket=$bucket";
                            if ( $fld_name =~ /Phylo/ ) {
                                $url .= "&filter_type=2";
                            } elsif ( $fld_name =~ /only/ ) {
                                $url .= "&filter_type=3";
                            }
                            print "<td class='img' align='right'>" . alink( $url, $v2 ) . "</td>\n";
                        } else {
                            print "<td class='img' align='right'>$v2</td>\n";
                        }
                    } else {
                        print "<td class='img' align='right'>$v2</td>\n";
                    }
                } else {
                    print "<td class='img' align='right'>$v2</td>\n";
                }
                $j++;
            }
            print "</tr>\n";
        }

        $line_no++;
    }

    print "<tr class='img' bgcolor='lightgray'>\n";
    my $j = 0;
    for my $fld (@fields) {
        if ( $j == 0 ) {
            print "<td class='img'>Total</td>\n";
        } else {
            if ( $total_h{$fld} ) {
                print "<td class='img' align='right'>" . $total_h{$fld} . "</td>\n";
            } else {
                print "<td class='img' align='right'>-</td>\n";
            }
        }
        $j++;
    }
    print "</tr>\n";
    print "</table>\n";

    close $fh;
    print end_form();
}

############################################################################
# printGeneFuncStatsList
############################################################################
sub printGeneFuncStatsList {
    my $taxon_oid   = param('taxon_oid');
    my $data_type   = param('data_type');
    my $func_type   = param('func_type');
    my $filter_type = param('filter_type');
    my $bucket      = param('bucket');

    printMainForm();
    print hiddenVar( "taxon_oid",   $taxon_oid );
    print hiddenVar( "data_type",   $data_type );
    print hiddenVar( "func_type",   $func_type );
    print hiddenVar( "filter_type", $filter_type );
    print hiddenVar( "bucket",      $bucket );

    print "<h1>Gene Function List</h1>\n";

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    $taxon_oid = sanitizeInt($taxon_oid);
    my $zip_name = $mer_data_dir . "/$taxon_oid/";
    if ( $data_type eq 'assembled' ) {
        $zip_name .= "assembled/gene_";
    } elsif ( $data_type eq 'unassembled' ) {
        $zip_name .= "unassembled/gene_";
    } else {
        print end_form();
        webError("No data.");
    }

    my $i2 = "";
    if ( $func_type eq 'cog' ) {
        $zip_name .= "cog_stats.zip";
        $i2 = "cog_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'pfam' ) {
        $zip_name .= "pfam_stats.zip";
        $i2 = "pfam_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'tigr' ) {
        $zip_name .= "tigr_stats.zip";
        $i2 = "tigr_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'ec' ) {
        $zip_name .= "ec_stats.zip";
        $i2 = "ec_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'ko' ) {
        $zip_name .= "ko_stats.zip";
        $i2 = "ko_" . sanitizeInt($bucket);
    } elsif ( $func_type eq 'phylo' ) {
        $zip_name .= "phylo_stats.zip";
        $i2 = "phylo_" . sanitizeInt($bucket);
    } else {
        print end_form();
        webError("No data.");
    }

    printStatusLine( "Loading ...", 1 );

    my %func_names = getFuncNames($func_type);

    my $it = new InnerTable( 1, "geneFuncStatsList$$", "geneFuncStatsList", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",     "asc", "left" );
    $it->addColSpec( "Gene Length", "asc", "right" );

    if ( $func_type eq 'phylo' ) {
        $it->addColSpec( "Percent Identity", "asc", "right" );
    } else {
        $it->addColSpec( "Functions", "asc", "left" );
    }

    my $select_id_name = "gene_oid";

    WebUtil::unsetEnvPath();
    my $fh         = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", "geneFuncStatsList" );
    my $gene_count = 0;
    my $trunc      = 0;
    while ( my $line = $fh->getline() ) {
        chomp($line);
        my ( $gene_oid, $gene_length, $type2, $func_str ) =
          split( /\t/, $line );
        if ( $filter_type && $filter_type != $type2 ) {

            # skip
            next;
        }

        my $url =
            "$main_cgi?section=MetaGeneDetail"
          . "&page=metaGeneDetail&data_type=$data_type"
          . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
        my $workspace_id = "$taxon_oid $data_type $gene_oid";
        my $r            = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
        $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= $gene_length . $sd . $gene_length . "\t";
        if ( $func_type ne 'phylo' ) {
            my @funcs = split( /\,/, $func_str );
            $func_str = "";
            for my $func_id (@funcs) {
                if ($func_str) {
                    $func_str .= "; ";
                }
                $func_str .= "($func_id) " . $func_names{$func_id};
            }
        }
        $r .= $func_str . $sd . $func_str . "\t";
        $it->addRow($r);

        $gene_count++;
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }
    close $fh;
    WebUtil::resetEnvPath();

    if ( $gene_count == 0 ) {
        print end_form();
        webError("No data.");
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();

        ## save to workspace
        WorkspaceUtil::printSaveGeneToWorkspace_withAllGeneFuncList($select_id_name);
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
# printNCBIProjectId
############################################################################
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
    $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();

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

    ## Now retrieve body of data for the real taxon_oid.
    my $sql = qq{
      select distinct tx.taxon_oid,
         tx.ncbi_taxon_id, tx.host_ncbi_taxon_id,
         tx.taxon_display_name,
         tx.is_public, tx.funding_agency, tx.seq_status, tx.seq_center,
         tx.comments, tx.genome_type,
         tx.domain, tx.phylum, tx.ir_class, tx.ir_order,
         tx.family, tx.genus, tx.species, tx.strain, tx.jgi_species_code,
         tx.img_version,  tx.is_pangenome, tx.jgi_project_id,
         tx.refseq_project_id, tx.gbk_project_id, tx.gold_id, tx.sample_gold_id,
         tx.env_sample,
         tx.is_big_euk, tx.is_proxygene_set,
         to_char(tx.release_date, 'yyyy-mm-dd'),
         to_char(tx.add_date, 'yyyy-mm-dd'),
         to_char(tx.mod_date, 'yyyy-mm-dd'), tx.obsolete_flag,
     tx.submission_id, tx.proposal_name, tx.img_product_flag, tx.in_file, tx.combined_sample_flag,
     to_char(tx.distmatrix_date, 'yyyy-mm-dd'), tx.high_quality_flag,  tx.analysis_project_id,
     tx.study_gold_id, tx.sequencing_gold_id, tx.genome_completion
      from taxon tx
      where tx.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my (
        $taxon_oid0,       $ncbi_taxon_id,  $host_ncbi_taxon_id,   $taxon_display_name, $is_public,
        $funding_agency,   $seq_status,     $seq_center,           $comments,           $genome_type,
        $domain,           $phylum,         $ir_class,             $ir_order,           $family,
        $genus,            $species,        $strain,               $jgi_species_code,   $img_version,
        $is_pangenome,     $jgi_project_id, $refseq_project_id,    $gbk_project_id,     $gold_id,
        $sample_gold_id,   $env_sample,     $is_big_euk,           $is_proxygene_set,   $release_date,
        $add_date,         $mod_date,       $obsolete_flag,        $submission_id,      $proposal_name,
        $img_product_flag, $in_file,        $combined_sample_flag, $distmatrix_date,    $high_quality_flag,
        $analysis_project_id, $study_gold_id, $sequencing_gold_id, $genome_completion
      )
      = $cur->fetchrow();
    $cur->finish();
    if ( $taxon_oid0 eq "" ) {
        printStatusLine( "Error.", 2 );

        #$dbh->disconnect();
        webError("Taxon object identifier $taxon_oid not found\n");
    }

    printMainForm();

    print hiddenVar( 'taxon_oid', $taxon_oid );

    my $has_assembled   = 0;
    my $has_unassembled = 0;

    my $file = $mer_data_dir . "/" . $taxon_oid . "/assembled/taxon_stats.txt";
    if ( -e $file ) {
        $has_assembled = 1;
    }

    $file = $mer_data_dir . "/" . $taxon_oid . "/unassembled/taxon_stats.txt";
    if ( -e $file ) {
        $has_unassembled = 1;
    }

    # html bookmark
    print "<h1>\n";
    if ( $genome_type eq "metagenome" ) {
        print "Microbiome Details";
        if ($has_assembled) {
            if ($has_unassembled) {
                print " (Assembled and Unassembled Data)\n";
            } else {
                print " (Assembled Data)\n";
            }
        } elsif ($has_unassembled) {
            print " (Unassembled Data)\n";
        } else {
            print "\n";
        }
    } elsif ( lc($is_pangenome) eq "yes" ) {
        print "Pangenome Details\n";
    } else {
        print "Organism Details\n";
    }
    print "</h1>\n";

    print hiddenVar( "taxon_filter_oid", $taxon_oid );

    # button: add to genome cart
    print qq {
          <input type="submit" class="smdefbutton" style="vertical-align:top;margin-top:0;padding-top:8px;
           padding-bottom:6px;" value="Add to Genome Cart" name="setTaxonFilter">
    };
    print nbsp(4);

    # button: browse genome
    print qq {
         <a class="genome-btn browse-btn" href="#browse" title="Browse Genome"><span>Browse Genome</span></a>
    };
    print nbsp(4);

    # button: blast genome
    print qq{
         <a class="genome-btn blast-btn" href="$main_cgi?section=FindGenesBlast&page=geneSearchBlast&taxon_oid=$taxon_oid&domain=$domain"
         title="BLAST Genome"><span>BLAST Genome</span></a>
    };
    print nbsp(4);

    # button: download data
    my ( $jgi_portal_url_str, $jgi_portal_url, $strrow ) = TaxonDetail::printTaxonExtLinks( $dbh, $taxon_oid );

    if ( $jgi_portal_url ne "" ) {
        print qq{
            <a class="genome-btn download-btn" href="$jgi_portal_url"
            title="Download Data" onClick="_gaq.push(['_trackEvent', 'JGI Portal', '$taxon_oid', 'img link']);">
            <span>Download Data</span></a>
        };
    } else {

        #        print qq {
        #            <a class="genome-btn download-btn" href="#export"
        #            title="Download Data"><span>Download Data</span></a>
        #        };
    }

    #my $showPhyloDist = hasPhylumDistGenes( $dbh, $taxon_oid );
    my $nbsp4 = "&nbsp;" x 4;

    my $ht;
    $ht = qq{
        $nbsp4<a href='#hort'>Putative Horizontally Transferred Genes</a>
        <br>
    } if $include_ht_stats;

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
        my $sql = qq{
        select count( distinct pig.gene )
            from ms_protein_img_genes pig
            where pig.genome = ?
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
        my $sql           = qq{
            select count( distinct dts.dataset_oid )
            from rnaseq_dataset dts
            where dts.reference_taxon_oid = ?
            $datasetClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        $rnaseqcount = $cur->fetchrow();
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

    my $jgiUrl = getJgiMicrobeUrl( $domain, $seq_status, $jgi_species_code, $seq_center );
    if ( !blankStr($jgiUrl) ) {
        webLog "jgi_species_code='$jgi_species_code' url='$jgiUrl'\n"
          if $verbose >= 1;
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

    # html bookmark 1
    print WebUtil::getHtmlBookmark( "overview", "<h2>Overview</h2>" );
    print "\n";

    print "<table class='img'  border='1' >\n";
    if ( $genome_type eq "metagenome" ) {
        printAttrRow( "Study Name (Proposal Name)",   $proposal_name );
        printAttrRow( "Sample Name",     $taxon_display_name );
        printAttrRow( "Taxon Object ID", $taxon_oid );
    } elsif ( lc($is_pangenome) eq "yes" ) {
        printAttrRow( "Study Name (Proposal Name)",   $proposal_name );
        printAttrRow( "Pangenome Name",  $taxon_display_name );
        printAttrRow( "Taxon Object ID", $taxon_oid );
    } else {
        printAttrRow( "Study Name (Proposal Name)",   $proposal_name );
        printAttrRow( "Organism Name",   $taxon_display_name );
        printAttrRow( "Taxon Object ID", $taxon_oid );
    }
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

    printNCBIProjectId( "RefSeq Project ID",  $refseq_project_id );
    printNCBIProjectId( "GenBank Project ID", $gbk_project_id );

    my $db_gold;
    if ( !blankStr($study_gold_id) || !blankStr($sequencing_gold_id)  ) {
        print "<tr class='img'>\n";
        print "<th class='subhead'>\n";
        print "GOLD ID in IMG Database";
        print "</th>\n";
        print "</td>\n";
        print "<td class='img'>\n";
        if ( !blankStr($gold_id) ) {
            my $url = HtmlUtil::getGoldUrl($study_gold_id);

            if($gold_id =~ /^Gs/) {
                print alink( $url, "Study ID: $study_gold_id" );
            } else {
                print alink( $url, "Project ID: $sequencing_gold_id" );
            }


            print "&nbsp;&nbsp;";
        }

        if ( $combined_sample_flag eq 'Yes' ) {
            if (!blankStr($sample_gold_id)) {
                my $url = HtmlUtil::getGoldUrl($sample_gold_id);

                print "Project ID: ";
                print alink( $url, "$sample_gold_id" );
            }

            # TODO - Ken
            # get all sample ids
            # list all sample goold sample ids
            $db_gold = WebUtil::dbGoldLogin();
            my $ids_aref = CombinedSample::getGoldIds( $db_gold, $submission_id );
            foreach my $id (@$ids_aref) {
                next if ( $id eq $sample_gold_id );
                print " ";
                my $url = HtmlUtil::getGoldUrl($id);
                print alink( $url, $id );
            }
        } elsif (!blankStr($sample_gold_id)) {
            my $url = HtmlUtil::getGoldUrl($sample_gold_id);
            print alink( $url, "Project ID: $sample_gold_id" );
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
        print alink( $url, $analysis_project_id );
        print "</td>\n";
        print "</tr>\n";

        my($projectType, $submissionType) = TaxonDetailUtil::getSubmissionType($dbh, $analysis_project_id);
        printAttrRow( "GOLD Analysis Project Type",  $projectType);
        printAttrRow( "Submission Type",  $submissionType);
    }

    if ( $combined_sample_flag eq 'Yes' ) {
        $db_gold = WebUtil::dbGoldLogin() if ( $db_gold eq '' );
        my $taxon_href = CombinedSample::getTaxonNames( $dbh, $db_gold, $submission_id );
        my $size = keys %$taxon_href;
        print "<tr class='img'>\n";
        print "<th class='subhead'>\n";
        print "Combined Samples ($size)";
        print "</th>\n";
        print "</td>\n";
        print "<td class='img'>\n";

        foreach my $tid ( sort keys %$taxon_href ) {
            my $name = $taxon_href->{$tid};
            print alink( "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$tid", "$name" );
            print "<br/>\n";
        }
        print "</td>\n";
        print "</tr>\n";

        #$db_gold->disconnect();
    }

    my $jgi_portal_url_str = printTaxonExtLinks( $dbh, $taxon_oid );
    if ( lc($is_pangenome) eq "yes" ) {
        printAttrRow( "Genome Type", "Pangenome" );
    } else {

        # printAttrRow( "Genome type", $genome_type );
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


    printAttrRow( "IMG Release", $img_version );

    print "<tr class='img' >\n";
    print "<th class='subhead'>Comment</th>\n";
    my $commentsHtml = escHtml($comments);
    print "<td class='img' >\n";
    print "$commentsHtml\n";
    if (   !blankStr($jgiUrl)
        && $seq_center =~ /JGI/
        && $genome_type ne "metagenome" )
    {
        print nbsp(1) if !blankStr($comments);
        print "JGI's ";
        print "<a href='$jgiUrl'>";
        print "Genome Portal";
        print "</a>\n";
        print "provides sequence files and annotation.\n";
    }
    print "</td>\n";
    print "</tr>\n";

    # er add date, mod date
    # $release_date, $add_date, $mod_date, $obsolete_flag
    #if ($img_er) {
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

    # show sample information for metagenome
    my $sample_show_map = 0;

    my $ncbi_project_id = $gbk_project_id;
    my %metadata;
    if ( lc($is_pangenome) eq "yes"
        && scalar(@pangenome_ids) > 0 )
    {
        my $tx_oid_str    = join( ",", @pangenome_ids );
        my $ncbi_pids_str = join( ",", @ncbi_pids );

        #pangenome has no gold_id and sample_gold_id in taxon table
        %metadata =
          DataEntryUtil::getAllMetadataFromGold( $submission_id, $tx_oid_str, $ncbi_pids_str, $gold_id, $sample_gold_id, $analysis_project_id );
    } else {
        #%metadata =
         # DataEntryUtil::getAllMetadataFromGold( $submission_id, $taxon_oid, $ncbi_project_id, $gold_id, $sample_gold_id, $analysis_project_id );
    }

    # pangenome metadata
    if ( lc($is_pangenome) eq "yes"  && scalar(@pangenome_ids) > 0 && scalar( keys %metadata ) > 0 ) {
        my @sections = ( 'Project Information', 'Metadata' );

        # display attribute values by section
        for my $s1 (@sections) {
            print "<tr class='highlight'>\n";
            print "<th class='subhead'>" . escapeHTML($s1) . "</th> <th class='subhead'> &nbsp; </th>\n";

            # single valued
            my @attrs1 = DataEntryUtil::getGoldSingleAttr();
            for my $attr1 (@attrs1) {
                if ( DataEntryUtil::getGoldAttrSection($attr1) ne $s1 ) {

                    # not in this section, skip
                    next;
                }

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
                        print "</td>\n";
                        print "<td class='img'>\n";
                        print $text;
                        print "</td>\n";
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
                        print "</td>\n";
                        print "<td class='img'>\n";
                        print $text;
                        print "</td>\n";
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
                            print "</td>\n";
                            print "<td class='img'>\n";
                            print $text;
                            print "</td>\n";
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
            for my $attr2 (@attrs2) {
                if ( DataEntryUtil::getGoldAttrSection($attr2) ne $s1 ) {

                    # not in this section, skip
                    next;
                }

                if ( $metadata{$attr2} ) {
                    printAttrRow( DataEntryUtil::getGoldAttrDisplayName($attr2), $metadata{$attr2} );
                }
            }

            printf "</tr>\n";
        }

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
        print "<th class='subhead'>Sample Information</th>  <th class='subhead'> &nbsp; </th></tr>\n";


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
            printAttrRowRaw( "Geographical Map", $_map );
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

    print "</table>\n";

    # end of Organism Information section

    # html bookmark 2
    if ( $genome_type eq "metagenome" ) {
        print WebUtil::getHtmlBookmark( "statistics", "<h2>Metagenome Statistics</h2>" );
        printStatsForOneTaxon($taxon_oid);
    } elsif ( lc($is_pangenome) eq "yes" ) {
        print WebUtil::getHtmlBookmark( "statistics", "<h2>Pangenome Statistics</h2>" );
    } else {
        print WebUtil::getHtmlBookmark( "statistics", "<h2>Genome Statistics</h2>" );
        printStatsForOneTaxon($taxon_oid);
    }
    print "\n";

    ### begin genes bookmark
    print WebUtil::getHtmlBookmark( "genes", "" );

    # gene search
    MetaGeneTable::printMetaGeneSearchSelect();

    # tools html bookmark 3
    print WebUtil::getHtmlBookmark( "tools", "" );

    my $scaffold_stats_file = $mer_data_dir . "/$taxon_oid/assembled/scaffold_stats.txt";
    if ( -e $scaffold_stats_file ) {
        print WebUtil::getHtmlBookmark( "browse", "<h2>Browse Genome</h2>" );
        print "<p>(For assembled data only)\n";
        print "<p>\n";

        if ( lc($is_pangenome) eq "yes" ) {
            my $url = "$main_cgi?section=TaxonList&page=pangenome";
            $url .= "&taxon_oid=$taxon_oid";
            print buttonUrl( $url, "Pangenome Details", "lgbutton" );
            print "<br>\n";

            my $url = "$main_cgi?section=Pangenome&taxon_oid=$taxon_oid";
            print buttonUrl( $url, "Pangene Details", "lgbutton" );
            print "<br>\n";

            if ( $domain ne "Eukaryota" ) {
                my $url = "$main_cgi?section=TaxonCircMaps" . "&page=circMaps&taxon_oid=$taxon_oid";
                print buttonUrl( $url, "Pangenome Maps", "lgbutton" );
                print "<br/>\n";
            }

            printStatusLine( "Loaded.", 2 );

            #$dbh->disconnect();
            print end_form();
            return;
        }

        #       my $url = "$section_cgi&page=scaffolds&taxon_oid=$taxon_oid";
        #   $url .= "&sample=0&study=proteomics" if $proteincount > 0;
        #   $url .= "&sample=0&study=rnaseq" if $rnaseqcount > 0;
        #       print buttonUrl( $url, "Scaffolds and Contigs", "lgbutton" );
        my $url1 = "$section_cgi&page=geneCountScaffoldDist" . "&taxon_oid=$taxon_oid";
        $url1 .= "&sample=0&study=proteomics" if $proteincount > 0;
        $url1 .= "&sample=0&study=rnaseq"     if $rnaseqcount > 0;
        print buttonUrl( $url1, "Scaffolds by Gene Count", "lgbutton" );

        print "<br/>\n";

        my $url2 = "$section_cgi&page=seqLengthScaffoldDist" . "&taxon_oid=$taxon_oid";
        $url2 .= "&sample=0&study=proteomics" if $proteincount > 0;
        $url2 .= "&sample=0&study=rnaseq"     if $rnaseqcount > 0;
        print buttonUrl( $url2, "Scaffolds by Sequence Length", "lgbutton" );

        my $scaffold_depth_file = $mer_data_dir . "/$taxon_oid/assembled/scaffold_depth.zip";
        if ( -e $scaffold_depth_file ) {
            print "<br/>\n";
            my $url2 = "$section_cgi&page=readDepthScaffoldDist" . "&taxon_oid=$taxon_oid";
            $url2 .= "&sample=0&study=proteomics" if $proteincount > 0;
            $url2 .= "&sample=0&study=rnaseq"     if $rnaseqcount > 0;
            print buttonUrl( $url2, "Scaffolds by Read Depth", "lgbutton" );
        }

        if ( $has_assembled && $domain ne "Eukaryota" ) {
            print "<br/>\n";
            my $url = "$main_cgi?section=TaxonCircMaps" . "&page=circMaps&taxon_oid=$taxon_oid";
            print buttonUrl( $url, "Chromosome Maps", "lgbutton" );
        }

        print "<br/>\n";
    }

    print WebUtil::getHtmlBookmark ( "bin", "<h2>Phylogenetic Distribution of Genes</h2>" );
    print "<p>\n";
    my $url = "$main_cgi?section=MetaFileHits&page=metagenomeStats";
    $url .= "&taxon_oid=$taxon_oid";
    print qq{
            <input type='button' class='lgbutton'
            value='Distribution by BLAST percent identities'
            onclick="window.location.href='$url'"
            title='Distribution of genes binned by BLAST percent identities'
            />
        };

    my $has_16s_dist = 0;
    for my $dtype2 ( 'assembled', 'unassembled' ) {
        my $file_name_16s = MetaUtil::getPhyloDistTaxonDir($taxon_oid) . "/16s_" . $dtype2 . ".profile.txt";
        if ( -e $file_name_16s ) {
            $has_16s_dist = 1;
            last;
        }
    }
    if ($has_16s_dist) {
        print "<br/>";
        my $url2 = "$main_cgi?section=MetaFileHits&page=metagenomeStats";
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


    if($jgi_project_id ne '' && $jgi_project_id > 0) {
        my $hasElviz = MerFsUtil::hasElviz($jgi_project_id);
        if($hasElviz) {
            print WebUtil::getHtmlBookmark ( "viewer", "<h2>Elviz Viewer</h2>" );
        print qq{
            <p>
            Elviz is an interactive tool for exploring metagenomic assemblies. <br>
            Only a limited set of JGI metagenomes have Elviz data. <br>
            Check out the <a href='http://genome.jgi.doe.gov/viz/projectSelection'>list of JGI metagenomes</a>
            accessible with Elviz.
            <br>
        };

        my $url = "http://genome.jgi.doe.gov/viz/plot?jgiProjectId=" . $jgi_project_id;
        print qq{
            <input type='button' class='lgbutton'
            value='Elviz'
            onclick="window.location.href='$url'"
            />
        };
        print "</p>\n";
        }
    }

    # gene stats profiles
    my @d_types = ();
    for my $t2 ( 'assembled', 'unassembled' ) {
        my $stats_file = $mer_data_dir . "/$taxon_oid/$t2/stats_profile.txt";
        if ( -e $stats_file ) {
            push @d_types, ($t2);
        }
    }

    if ( scalar(@d_types) > 0 ) {
        print WebUtil::getHtmlBookmark ( "statsProfile", "<h2>Gene Statistics Profile</h2>" );
        my $cnt = 0;
        for my $t2 (@d_types) {
            print "<br/>" if ( $cnt > 0 );
            my $url = "$main_cgi?section=MetaDetail" . "&page=statsProfile&taxon_oid=$taxon_oid&data_type=$t2";
            print buttonUrl( $url, "Gene Statistics Profile ($t2)", "lgbutton" );
            $cnt++;
        }
    }

    #    if ( -e $scaffold_stats_file ) {
    #        # html bookmark 4 - export section
    #        print WebUtil::getHtmlBookmark( "export",
    #            "<h2>Export Genome Data</h2>" );
    #        print "\n";
    #        printExportLinks( $taxon_oid, $is_big_euk, $jgi_portal_url_str );
    #        printHint( "Right click on link to see menu for "
    #              . "saving link contents to target file.<br/>\n"
    #              . "Please be patient during download.<br/>" );
    #    }

    if ( $proteincount > 0 || $rnaseqcount > 0 ) {
        print WebUtil::getHtmlBookmark ( "expression", "<h2>Expression Studies</h2>" );
        print "\n";
    }

    # see if there is any proteomic data:
    if ( $proteincount > 0 ) {
        my $url = "$main_cgi?section=IMGProteins" . "&page=genomestudies&taxon_oid=$taxon_oid";
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

    #print end_form();
    #return;

    #    print WebUtil::getHtmlBookmark ( "compare",
    #        "<h2>Compare Gene Annotations</h2>" );
    #    print "\n";
    #
    #    my $url =
    #        "$main_cgi?section=GeneAnnotPager"
    #      . "&page=viewGeneAnnotations&taxon_oid=$taxon_oid";
    #    print "<div class='lgbutton'>\n";
    #    print alink( $url, "Compare Gene Annotations" );
    #    print "</div>\n";
    #    print "<p>\n";
    #    print "Gene annotation values are precomputed and stored ";
    #    print "in a tab delimited file<br/>";
    #    print "also viewable in Excel.<br/>\n";
    #    print "</p>\n";

    #    print WebUtil::getHtmlBookmark( "geneInfo",
    #        "<h2>Download Gene Information</h2>" );
    #    print "\n";
    #
    #    my $url =
    #        "$main_cgi?section=GeneInfoPager"
    #      . "&page=viewGeneInformation&taxon_oid=$taxon_oid";
    #    print "<div class='lgbutton'>\n";
    #    print alink( $url, "Download Gene Information" );
    #    print "</div>\n";
    #    print "<p>\n";
    #    print "Gene information is precomputed and stored ";
    #    print "in a tab delimited file<br/>";
    #    print "also viewable in Excel.<br/>\n";
    #    print "</p>\n";

    # Show links and search only for genomes that have scaffold/DNA data.
    # Do not show for proxy gene (protein) data only.
    # --es 07/05/08
    #    if ( hasNucleotideData( $dbh, $taxon_oid ) ) {
    #        # html bookmark 4 - export section
    #        print WebUtil::getHtmlBookmark( "export",
    #            "<h2>Export Genome Data</h2>" );
    #        print "\n";
    #        printExportLinks( $taxon_oid, $is_big_euk, $jgi_portal_url_str );
##        printHint( "Right click on link to see menu for "
##              . "saving link contents to target file.<br/>\n"
##              . "Please be patient during download.<br/>" );
    #        if ($include_metagenomes) {
    #            printScaffoldSearchForm($taxon_oid);
    #        }
    #    }
    #    else {
    #        # html bookmark 4 - export section
    #        print WebUtil::getHtmlBookmark( "export",
    #            "<h2>Export Genome Data</h2>" );
    #        print "\n";
    #        printProxyGeneExportLinks( $taxon_oid, $is_big_euk );
##        printHint( "Right click on link to see menu for "
##              . "saving link contents to target file.<br/>\n"
##              . "Please be patient during download.<br/>" );
    #    }

    if ( $genome_type eq "metagenome" && $has_unassembled && !$has_assembled ) {

        #unassembled only, no scaffold search
    } else {
        printScaffoldSearchForm($taxon_oid);
    }

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
# printStatsForOneTaxon
############################################################################
sub printStatsForOneTaxon {
    my ($taxon_oid) = @_;

    $taxon_oid = sanitizeInt($taxon_oid);

    my %func_total;
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    my $sql = "select count(*) from cog";
    my $cur = execSql( $dbh, $sql, $verbose );
    ( $func_total{"COG clusters"} ) = $cur->fetchrow();
    $func_total{"COG Clusters"} = $func_total{"COG clusters"};
    $cur->finish();

    $sql = "select count(*) from pfam_family";
    $cur = execSql( $dbh, $sql, $verbose );
    ( $func_total{"Pfam clusters"} ) = $cur->fetchrow();
    $func_total{"Pfam Clusters"} = $func_total{"Pfam clusters"};
    $cur->finish();

    $sql = "select count(*) from tigrfam";
    $cur = execSql( $dbh, $sql, $verbose );
    ( $func_total{"TIGRfam clusters"} ) = $cur->fetchrow();
    $func_total{"TIGRfam Clusters"} = $func_total{"TIGRfam clusters"};
    $cur->finish();

    #$dbh->disconnect();

    my $file = $mer_data_dir . "/" . $taxon_oid . "/assembled/taxon_stats.txt";

    my $has_assembled   = 0;
    my $has_unassembled = 0;

    my $line   = "";
    my @fields = ('Number of sequences', 'Number of bases',
		  ':GC count',  'CRISPR Count', 'Genes',
		  ':RNA genes', '::rRNA genes',
		  ':::5S rRNA', ':::16S rRNA', ':::18S rRNA',
		  ':::23S rRNA', ':::28S rRNA', '::tRNA genes',
		  ':Protein coding genes', '::with Product Name',
		  '::with COG', '::with Pfam', '::with TIGRfam',
		  '::with KO', '::with Enzyme', '::with MetaCyc',
		  '::with KEGG', 'COG Clusters', 'Pfam Clusters',
		  'TIGRfam Clusters');

    my %assembled;

#    if ( -e $file ) {
#        $has_assembled = 1;
#
#        my $fh = newReadFileHandle($file);
#        if ( !$fh ) {
#            return;
#        }
#        while ( $line = $fh->getline() ) {
#            chomp $line;
#            my ( $tag, $val ) = split( /\t/, $line );
#            push @fields, ($tag);
#            $assembled{$tag} = $val;
#        }
#        close $fh;
#    } else {
#        # print "<p>Cannot find file: $file\n";
#    }

    ## Amy (10/13/2014): use the new taxon_stats_merfs table
    $has_assembled = getMerfsStats($taxon_oid, 'assembled', \%assembled);

    my $file2 = $mer_data_dir . "/" . $taxon_oid . "/unassembled/taxon_stats.txt";
    my %unassembled;
#    if ( -e $file2 ) {
#        $has_unassembled = 1;
#
#        my $fh2 = newReadFileHandle($file2);
#        if ( !$fh2 ) {
#            return;
#        }
#        while ( $line = $fh2->getline() ) {
#            chomp $line;
#            my ( $tag, $val ) = split( /\t/, $line );
#            if ( !WebUtil::inArray( $tag, @fields ) ) {
#                push @fields, ($tag);
#            }
#            $unassembled{$tag} = $val;
#        }
#        close $fh2;
#    }

    ## Amy (10/13/2014): use the new taxon_stats_merfs table
    $has_unassembled = getMerfsStats($taxon_oid, 'unassembled', \%unassembled);

    if ( !$has_assembled && !$has_unassembled ) {
        return;
    }

    my %both;
    if ( $has_assembled && $has_unassembled ) {
#        my $file3 = $mer_data_dir . "/" . $taxon_oid . "/taxon_stats_both.txt";
#
#        if ( -e $file3 ) {
#            my $fh3 = newReadFileHandle($file3);
#            if ($fh3) {
#                while ( $line = $fh3->getline() ) {
#                    chomp $line;
#                    my ( $tag, $val ) = split( /\t/, $line );
#                    $both{$tag} = $val;
#                }
#                close $fh3;
#            }
#        }

	## Amy (10/13/2014): get from TAXON_STATS table
	my $sql2 = "select cog_clusters, pfam_clusters, tigrfam_clusters " .
	    "from taxon_stats where taxon_oid = ?";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid );
	( $both{'COG Clusters'}, $both{'Pfam Clusters'},
	  $both{'TIGRfam Clusters'} ) = $cur2->fetchrow();
	$cur2->finish();
    }

    print "<table class='img'  border='0' cellspacing='3' cellpadding='0' >\n";
    print "<tr>\n";
    print "<th class='img' ></th>\n";
    if ($has_assembled) {
        print "<th class='img' colspan=2>Assembled</th>\n";
    }
    if ($has_unassembled) {
        print "<th class='img' colspan=2>Unassembled</th>\n";
    }
    if ( $has_assembled && $has_unassembled ) {
        print "<th class='img' colspan=2>Total</th>\n";
    }
    print "</tr>\n";

    print "<tr>\n";
    print "<th class='img' ></th>\n";
    if ($has_assembled) {
        print "<th class='img' >Number</th>\n";
        print "<th class='img' >% of Assembled</th>\n";
    }
    if ($has_unassembled) {
        print "<th class='img' >Number</th>\n";
        print "<th class='img' >% of Unassembled</th>\n";
    }
    if ( $has_assembled && $has_unassembled ) {
        print "<th class='img' >Number</th>\n";
        print "<th class='img' >% of Total</th>\n";
    }
    print "</tr>\n";

    my $total_assembled = $assembled{"Genes total number"};
    if ( !$total_assembled ) {
        $total_assembled = $assembled{":Protein coding genes"} + $assembled{":RNA genes"};
    }
    my $total_unassembled = $unassembled{"Genes total number"};
    if ( !$total_unassembled ) {
        $total_unassembled = $unassembled{":Protein coding genes"} + $unassembled{":RNA genes"};
    }
    my $total = $total_assembled + $total_unassembled;

    my $total_number_sequences = $assembled{'Number of sequences'} + $unassembled{'Number of sequences'};
    my $total_number_bases     = $assembled{'Number of bases'} + $unassembled{'Number of bases'};

    for my $fld (@fields) {
        if ( !$assembled{$fld} && !$unassembled{$fld} ) {
            if ( $fld ne "Genes" ) {

                # skip zeros
                next;
            }
        }

        print "<tr>\n";
        my @tags = split( /\:/, $fld );

        if ( scalar(@tags) == 1 ) {
            my $tag1 = $tags[0];
            print "<tr class='highlight'>\n";
            print "<th class='subhead'><b>$tag1</b></th>\n";
        } elsif ( scalar(@tags) > 1 ) {
            print "<td class='img'>";
            for my $t2 (@tags) {
                if ( blankStr($t2) ) {
                    print "&nbsp; &nbsp; &nbsp; &nbsp; ";
                } else {
                    print $t2;
                }
            }
            print "</td>\n";
        }

        my $url = "";
        if ( $fld =~ /Number of sequences/ ) {
            $url = "$main_cgi?section=MetaDetail" . "&page=scaffolds" . "&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /CRISPR Count/ ) {
            $url = "$main_cgi?section=MetaDetail" . "&page=crisprdetails" . "&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /Protein coding genes/ ) {
            $url = "$main_cgi?section=MetaDetail" . "&page=proteinCodingGenes" . "&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /rRNA genes/ ) {

            # rRNA
            $url = "$main_cgi?section=MetaDetail" . "&page=rnas&locus_type=rRNA" . "&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /rRNA/ ) {

            # 5S, 16S or 23S rRNA
            my $gene_symbol = "";
            my $tag3        = $tags[-1];
            if ( $tag3 =~ /5S/ ) {
                $gene_symbol = "5S";
            } elsif ( $tag3 =~ /16S/ ) {
                $gene_symbol = "16S";
            } elsif ( $tag3 =~ /23S/ ) {
                $gene_symbol = "23S";
            } elsif ( $tag3 =~ /18S/ ) {
                $gene_symbol = "18S";
            } elsif ( $tag3 =~ /28S/ ) {
                $gene_symbol = "28S";
            } elsif ( lc($tag3) =~ /other/ ) {
                $gene_symbol = "other";
            }

            $url = "$main_cgi?section=MetaDetail" . "&page=rnas&locus_type=rRNA" . "&taxon_oid=$taxon_oid";

            if ($gene_symbol) {
                $url .= "&gene_symbol=$gene_symbol";
            }
        } elsif ( $fld =~ /tRNA genes/ ) {

            # tRNA
            $url = "$main_cgi?section=MetaDetail" . "&page=rnas&locus_type=tRNA" . "&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /RNA genes/ ) {

            # RNA
            $url = "$main_cgi?section=MetaDetail" . "&page=rnas&locus_type=RNA" . "&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with COG/ ) {

            # genes with COGs
            $url = "$main_cgi?section=MetaDetail" . "&page=cogs&cat=cat&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with Pfam/ ) {

            # genes with Pfam
            $url = "$main_cgi?section=MetaDetail" . "&page=pfam&cat=cat&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with TIGRfam/ ) {

            # genes with TIGRfam
            $url = "$main_cgi?section=MetaDetail" . "&page=tigrfam&cat=cat&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with KO/ ) {

            # genes with KO
            $url = "$main_cgi?section=MetaDetail" . "&page=ko&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with Enzyme/ ) {

            # genes with enzyme
            $url = "$main_cgi?section=MetaDetail" . "&page=enzymes&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with Product Name/ ) {

            # genes with product name
            $url = "$main_cgi?section=MetaDetail" . "&page=withFunc&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with KEGG/ ) {

            # genes with KEGG pathways
            $url = "$main_cgi?section=MetaDetail" . "&page=kegg&cat=cat&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /with MetaCyc/ ) {

            # genes with MetaCyc pathways
            $url = "$main_cgi?section=MetaDetail" . "&page=metacyc&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /COG clusters/ || $fld =~ /COG Clusters/ ) {

            # COG clusters
            $url = "$main_cgi?section=MetaDetail" . "&page=cogs&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /Pfam clusters/ || $fld =~ /Pfam Clusters/ ) {

            # Pfam clusters
            $url = "$main_cgi?section=MetaDetail" . "&page=pfam&taxon_oid=$taxon_oid";
        } elsif ( $fld =~ /TIGRfam clusters/ || $fld =~ /TIGRfam Clusters/ ) {

            # genes with TIGRfam
            $url = "$main_cgi?section=MetaDetail" . "&page=tigrfam&taxon_oid=$taxon_oid";
        } else {

            #print "<td class='img' align='right'>$val</td>\n";
        }

        # assembled
        my $val1 = 0;
        if ($has_assembled) {
            if ( $assembled{$fld} ) {
                $val1 = $assembled{$fld};
                if ( $url && $val1 ) {
                    my $url1 = $url
                      . "&data_type=assembled"
                      . "&total_genome_gene_count=$total_assembled"
                      . "&total_gene_count=$val1";

                    if ( $fld eq 'Number of sequences' ) {
                        if ( $val1 > 10000 ) {
                            $url1 = $url . "&data_type=assembled";
                        } else {
                            $url1 =
                                "$main_cgi?section=MetaDetail"
                              . "&page=listScaffolds"
                              . "&taxon_oid=$taxon_oid"
                              . "&data_type=assembled";
                        }
                    }

                    my $link = alink( $url1, $val1 );
                    print "<td class='img' align='right'>$link</td>\n";
                } else {
                    print "<td class='img' align='right'>$val1</td>\n";
                }
            } else {
                if ( scalar(@tags) == 1 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    print "<td class='img' align='right'>$val1</td>\n";
                }
            }

            if ( $fld eq 'Number of sequences' ) {
                if ($total_number_sequences) {
                    my $pc = $val1 * 100 / $total_number_sequences;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( $fld =~ 'CRISPR Count' ) {
                print "<td class='img' align='right'>-</td>\n";
            } elsif ( $fld eq 'Number of bases' ) {
                if ($total_number_bases) {
                    my $pc = $val1 * 100 / $total_number_bases;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( $fld =~ /GC count/ ) {
                if ( $assembled{'Number of bases'} ) {
                    my $pc = $val1 * 100 / $assembled{'Number of bases'};
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( lc($fld) eq 'cog clusters'
                || lc($fld) eq 'pfam clusters'
                || lc($fld) eq 'tigrfam clusters' )
            {
                if ( $func_total{$fld} ) {
                    my $pc = $val1 * 100 / $func_total{$fld};
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ($total_assembled) {
                if ( scalar(@tags) == 1 && !$val1 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    my $pc = $val1 * 100 / $total_assembled;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                }
            } else {
                if ( scalar(@tags) == 1 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            }
        }

        # unassembled
        my $val2 = 0;
        if ($has_unassembled) {
            if ( $unassembled{$fld} ) {
                $val2 = $unassembled{$fld};
                if ( $url && $val2 ) {
                    if ( $fld eq 'Number of sequences' ) {
                        print "<td class='img' align='right'>$val2</td>\n";
                    } else {
                        my $url2 = $url
                          . "&data_type=unassembled"
                          . "&total_genome_gene_count=$total_unassembled"
                          . "&total_gene_count=$val2";
                        my $link = alink( $url2, $val2 );
                        print "<td class='img' align='right'>$link</td>\n";
                    }
                } else {
                    if ( scalar(@tags) == 1 && !$val2 ) {
                        print "<td class='img' align='right'></td>\n";
                    } else {
                        print "<td class='img' align='right'>$val2</td>\n";
                    }
                }
            } else {
                if ( scalar(@tags) == 1 && !$val2 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    print "<td class='img' align='right'>$val2</td>\n";
                }
            }

            if ( $fld eq 'Number of sequences' ) {
                if ($total_number_sequences) {
                    my $pc = $val2 * 100 / $total_number_sequences;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( $fld eq 'Number of bases' ) {
                if ($total_number_bases) {
                    my $pc = $val2 * 100 / $total_number_bases;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( $fld =~ /GC count/ ) {
                if ( $unassembled{'Number of bases'} ) {
                    my $pc = $val2 * 100 / $unassembled{'Number of bases'};
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( lc($fld) eq 'cog clusters'
                || lc($fld) eq 'pfam clusters'
                || lc($fld) eq 'tigrfam clusters' )
            {
                if ( $func_total{$fld} ) {
                    my $pc = $val2 * 100 / $func_total{$fld};
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ($total_unassembled) {
                if ( scalar(@tags) == 1 && !$val2 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    my $pc = $val2 * 100 / $total_unassembled;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                }
            } else {
                if ( scalar(@tags) == 1 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            }
        }

        # total
        my $val3 = $val1 + $val2;
        if ( $has_assembled && $has_unassembled ) {
            if (   lc($fld) eq 'cog clusters'
                || lc($fld) eq 'pfam clusters'
                || lc($fld) eq 'tigrfam clusters' )
            {
                if ( $both{$fld} ) {
                    my $url3 = $url . "&data_type=both" . "&total_genome_gene_count=$total";
                    my $link = alink( $url3, $both{$fld} );
                    print "<td class='img' align='right'>$link</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( $url && $val3 ) {
                if ( $fld eq 'Number of sequences' ) {
                    print "<td class='img' align='right'>$val3</td>\n";
                } else {
                    my $url3 = $url . "&data_type=both" . "&total_genome_gene_count=$total" . "&total_gene_count=$val3";
                    my $link = alink( $url3, $val3 );
                    print "<td class='img' align='right'>$link</td>\n";
                }
            } else {
                if ( scalar(@tags) == 1 && !$val3 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    print "<td class='img' align='right'>$val3</td>\n";
                }
            }

            if ( $fld eq 'Number of sequences' ) {
                if ($total_number_sequences) {
                    my $pc = $val3 * 100 / $total_number_sequences;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( $fld eq 'Number of bases' ) {
                if ($total_number_bases) {
                    my $pc = $val3 * 100 / $total_number_bases;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( $fld =~ /GC count/ ) {
                my $n1 = 0;
                my $n2 = 0;
                if ( $assembled{'Number of bases'} ) {
                    $n1 = $assembled{'Number of bases'};
                }
                if ( $unassembled{'Number of bases'} ) {
                    $n2 = $unassembled{'Number of bases'};
                }
                if ( ( $n1 + $n2 ) > 0 ) {
                    my $pc = $val3 * 100 / ( $n1 + $n2 );
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ( lc($fld) eq 'cog clusters'
                || lc($fld) eq 'pfam clusters'
                || lc($fld) eq 'tigrfam clusters' )
            {
                if ( $both{$fld} && $func_total{$fld} ) {
                    my $pc = $both{$fld} * 100 / $func_total{$fld};
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            } elsif ($total) {
                if ( scalar(@tags) == 1 && !$val3 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    my $pc = $val3 * 100 / $total;
                    print "<td class='img' align='right'>" . sprintf( "%.2f%%", $pc ) . "</td>\n";
                }
            } else {
                if ( scalar(@tags) == 1 ) {
                    print "<td class='img' align='right'></td>\n";
                } else {
                    print "<td class='img' align='right'>-</td>\n";
                }
            }
        }

        print "</tr>\n";
    }

    if ( $has_assembled && $enable_biocluster ) {
        my $sql      = "select count(*) from bio_cluster_new where taxon = ?";
        my $cur      = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my ($bc_cnt) = $cur->fetchrow();
        $cur->finish();

        if ( $bc_cnt > 0 ) {
            print "<tr class='highlight'>\n";
            print "<th class='subhead'><b>Biosynthetic Clusters</b></th>\n";
            my $bc_url = "$main_cgi?section=BiosyntheticDetail" . "&page=biosynthetic_clusters&taxon_oid=$taxon_oid";
            print "<td class='img' align='right'>" . alink( $bc_url, $bc_cnt ) . "</td>\n";
            print "</tr>\n";

            $sql =
                "select count(distinct bcf.feature_id) "
              . "from bio_cluster_new bc, bio_cluster_features_new bcf "
              . "where bc.taxon = ? and bc.cluster_id = bcf.cluster_id";
            $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
            my ($bc_gene_cnt) = $cur->fetchrow();
            $cur->finish();

            print "<tr class='img'>\n";
            print "<td class='img'>" . nbsp(3) . "Genes in Biosynthetic Clusters</td>\n";
            my $bcg_url = "$main_cgi?section=BiosyntheticDetail" . "&page=biosynthetic_genes&taxon_oid=$taxon_oid";
            print "<td class='img' align='right'>" . alink( $bcg_url, $bc_gene_cnt ) . "</td>\n";
            print "</tr>\n";
        }
    }

    print "</table>\n";
}

######################################################################
# getMerfsStats: Get stats from TAXON_STATS_MERFS table
######################################################################
sub getMerfsStats {
    my ($taxon_oid, $data_type, $stats_h) = @_;

    my $dbh = dbLogin();
    my $sql = qq{
       select taxon_oid, n_scaffolds,
              total_bases, total_gc,
              rna_genes, rrna_genes,
              rrna5s_genes, rrna16s_genes,
              rrna18s_genes, rrna23s_genes,
              rrna28s_genes, trna_genes,
              cds_genes, genes_w_func_pred,
              genes_in_cog, genes_in_pfam,
              genes_in_tigrfam, genes_in_ko,
              genes_in_enzymes, genes_in_metacyc,
              genes_in_kegg, total_gene_count,
              cog_clusters, pfam_clusters, tigrfam_clusters, CRISPR_COUNT
       from taxon_stats_merfs
       where taxon_oid = ? and datatype = ?
       };

    my $id2;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $data_type );
    ( $id2, $stats_h->{'Number of sequences'},
      $stats_h->{'Number of bases'}, $stats_h->{':GC count'},
      $stats_h->{':RNA genes'}, $stats_h->{'::rRNA genes'},
      $stats_h->{':::5S rRNA'}, $stats_h->{':::16S rRNA'},
      $stats_h->{':::18S rRNA'}, $stats_h->{':::23S rRNA'},
      $stats_h->{':::28S rRNA'}, $stats_h->{'::tRNA genes'},
      $stats_h->{':Protein coding genes'}, $stats_h->{'::with Product Name'},
      $stats_h->{'::with COG'}, $stats_h->{'::with Pfam'},
      $stats_h->{'::with TIGRfam'}, $stats_h->{'::with KO'},
      $stats_h->{'::with Enzyme'}, $stats_h->{'::with MetaCyc'},
      $stats_h->{'::with KEGG'}, $stats_h->{'Genes total number'},
      $stats_h->{'COG Clusters'}, $stats_h->{'Pfam Clusters'},
      $stats_h->{'TIGRfam Clusters'}, $stats_h->{'CRISPR Count'} ) = $cur->fetchrow();
    $cur->finish();

    return $id2;
}


############################################################################
# isGebaGenome
############################################################################
sub isGebaGenome {
    my ( $dbh, $taxon_oid ) = @_;

    # use c2.username = 'GEBA' causing invalid username/password
    # use c1.contact_oid = c2.contact_oid = 3031 instead
    my $sql = qq{
        select count(*)
        from taxon t, contact_taxon_permissions c1
        where c1.contact_oid = 3031
        and c1.taxon_permissions = t.taxon_oid
        and t.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printExportLinks - Show links for export.
############################################################################
sub printExportLinks {
    my ( $taxon_oid, $is_big_euk, $jgi_portal_url_str ) = @_;

    #    print "<p>\n";
    #    print "Download sequences and gene information for this genome.\n";
    #    print "</p>\n";
    #
    #    print "<p>\n";
    #
    #    if ( $jgi_portal_url_str ne "" ) {
    #        print "$jgi_portal_url_str <br/>\n";
    #    }
    #
    #    my $path = "$taxon_reads_fna_dir/$taxon_oid.reads.fna";
    #    my $url  = "$section_cgi&downloadTaxonReadsFnaFile=1&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #    if ( -e $path ) {
    #        print alink( $url, "FASTA nucleic acid file for unassembled reads" );
    #        print "<br/>\n";
    #    }
    #    my $url = "$section_cgi&downloadTaxonFnaFile=1&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #    print alink( $url,
    #        "FASTA nucleic acid file for all scaffolds (assembled data only)" );
    #    print "<br/>\n";
    #
    #    return;
    #
    #    my $url2 = "$section_cgi&downloadTaxonGenesFile=1&taxon_oid=$taxon_oid";
    #    my $file = $mer_data_dir . "/" . $taxon_oid . "/assembled/taxon_stats.txt";
    #    if ( -e $file ) {
    #
    #        # has assembled data
    #        my $url3 = $url2 . "&data_type=assembled&noHeader=1";
    #        print alink( $url3,
    #            "Tab delimited file for Excel with gene information (assembled)" );
    #        $file =
    #          $mer_data_dir . "/" . $taxon_oid . "/unassembled/taxon_stats.txt";
    #        if ( -e $file ) {
    #            $url3 = $url2 . "&data_type=unassembled&noHeader=1";
    #            print nbsp(1);
    #            print alink( $url3, "(unassembled)" );
    #            $url3 = $url2 . "&data_type=both&noHeader=1";
    #            print nbsp(1);
    #            print alink( $url3, "(all)" );
    #        }
    #    }
    #    else {
    #        my $file =
    #          $mer_data_dir . "/" . $taxon_oid . "/unassembled/taxon_stats.txt";
    #        if ( -e $file ) {
    #
    #            # has unassembled data
    #            my $url3 = $url2 . "&data_type='unassembled'&noHeader=1";
    #            print alink( $url3,
    #"Tab delimited file for Excel with gene information (unassembled)"
    #            );
    #        }
    #        else {
    #            print " *** ERROR: no data\n";
    #        }
    #    }
    #    print "<br/>\n";
    #
    #    return;
    #
    #    my $alt_path = "$taxon_alt_faa_dir/$taxon_oid.alt.faa";
    #    $url = "$section_cgi&downloadTaxonFaaFile=1&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #
    #  #    if ( -e $alt_path ) {
    #  #        print alink( $url, "FASTA amino acid file for primary transcripts" );
    #  #    } else {
    #    print alink( $url,
    #        "FASTA amino acid file for all proteins (assembled data only)" );
    #
    #    #    }
    #    print "<br/>\n";
    #
    #    return;
    #
    #    if ( -e $alt_path ) {
    #        my $url = "$section_cgi&downloadTaxonAltFaaFile=1&taxon_oid=$taxon_oid";
    #        $url .= "&noHeader=1";
    #        print alink( $url, "FASTA amino acid file for secondary transcripts" );
    #        print "<br/>\n";
    #    }
    #
    #    my $url = "$section_cgi&downloadTaxonGenesFnaFile=1&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #    print alink( $url, "FASTA nucleic acid file for all genes" );
    #    print "<br/>\n";
    #
    #    my $url =
    #      "$section_cgi&downloadTaxonIntergenicFnaFile=1" . "&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #    print alink( $url, "FASTA intergenic sequences" );
    #    print "<br/>\n";

    # its is now unsupported - removed 2013-02-01 - ken
    #    if ( $is_big_euk ne "Yes" ) {
    #        my $url = "$section_cgi&page=taxonArtemisForm&taxon_oid=$taxon_oid";
    #        print buttonUrl( $url, "Generate Genbank File", "lgbutton" );
    #    }
    #    print "</p>\n";
}

############################################################################
# printProxyGeneExportLinks - Show links for protein only export.
############################################################################
sub printProxyGeneExportLinks {
    my ( $taxon_oid, $is_big_euk ) = @_;

    #    print "<p>\n";
    #    print "Download sequences and gene information for this genome.\n";
    #    print "</p>\n";
    #
    #    print "<p>\n";
    #
    #    my $path = "$taxon_reads_fna_dir/$taxon_oid.reads.fna";
    #    my $url  = "$section_cgi&downloadTaxonReadsFnaFile=1&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #    if ( -e $path ) {
    #        print alink( $url, "FASTA nucleic acid file for unassembled reads" );
    #        print "<br/>\n";
    #    }
    #
    #    my $alt_path = "$taxon_alt_faa_dir/$taxon_oid.alt.faa";
    #    my $url      = "$section_cgi&downloadTaxonFaaFile=1&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #    if ( -e $alt_path ) {
    #        print alink( $url, "FASTA amino acid file for primary transcripts" );
    #    }
    #    else {
    #        print alink( $url, "FASTA amino acid file for all proteins" );
    #    }
    #    print "<br/>\n";
    #
    #    if ( -e $alt_path ) {
    #        my $url = "$section_cgi&downloadTaxonAltFaaFile=1&taxon_oid=$taxon_oid";
    #        $url .= "&noHeader=1";
    #        print alink( $url, "FASTA amino acid file for secondary transcripts" );
    #        print "<br/>\n";
    #    }
    #
    #    my $url = "$section_cgi&downloadTaxonGenesFile=1&taxon_oid=$taxon_oid";
    #    $url .= "&noHeader=1";
    #    print alink( $url, "Tab delimited file for Excel with gene information" );
    #    print "<br/>\n";

    # its is now unsupported - removed 2013-02-01 - ken
    #    if ( $is_big_euk ne "Yes" ) {
    #        my $url = "$section_cgi&page=taxonArtemisForm&taxon_oid=$taxon_oid";
    #   print buttonUrl( $url, "Generate Genbank File", "lgbutton" );
    #    }
    #    print "</p>\n";
}

############################################################################
# taxonHasBins - Taxon has bins
############################################################################
sub taxonHasBins {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select taxon
        from scaffold scf
        where scf.taxon = ?
        and exists (select 1
                   from bin_scaffolds bs
                   where bs.scaffold = scf.scaffold_oid
                   and rownum < 2)
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

    print WebUtil::getHtmlBookmark ( "information", "<h2>Scaffold Search (assembled)</h2>" );
    print "<p>\n";
    print "Scaffold search allows for seaching for all scaffolds ";
    print "within an organism or microbiome.<br/>\n";
    print "Please enter a search term or matching substring ";
    print "for scaffold name or read ID.<br/>\n";
    print "</p>\n";

    print hiddenVar( "dataType", "assembled" );

    #    print qq{
    #        <p>
    #        <input type="radio" name="dataType" value="assembled" checked> Assembled <br/>
    #        <input type="radio" name="dataType" value="unassembled"> Unassembled
    #        </p>
    #    };

    print "<select name='scaffoldSearchType'>\n";
    print "<option value='scaffold_name'>Scaffold Name / ID </option>\n";

    #print "<option value='read_id'>Read ID";
    #print nbsp(10);
    #print "</option>\n";
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
    if ( $show_map && $clong ne "" && $clat ne "" && $gmapkey ne "" ) {
        my $tmp_geo_location = escHtml($geo_location);
        my $_map             = <<END_MAP;
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
sub printHabitat {
    my ( $dbh, $sample_oid ) = @_;

    my $sql = qq{
        select esht.sample_oid, cv.ecotype_term
        from env_sample_habitat_type esht, ecotypecv cv
        where esht.sample_oid = ?
        and esht.habitat_type = cv.ecotype_oid
        order by cv.ecotype_term
    };
    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
    my $val;
    for ( ; ; ) {
        my ( $sample_oid, $ecotype_term ) = $cur->fetchrow();
        last if !$sample_oid;
        $val .= escHtml($ecotype_term) . "<br/>";
    }
    chop $val;
    chop $val;
    chop $val;
    chop $val;
    chop $val;
    $cur->finish();

    print "<tr class='img'>\n";
    print "<th class='subhead'>Habitat</th>\n";
    print "<td class='img'>$val</td>\n";
    print "</tr>\n";
}

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
    #    for ( ;; ) {
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

    my $sql = qq{
       select bm.method_name, b.bin_oid, b.display_name, count( bs.scaffold )
       from scaffold scf, bin b, bin_scaffolds bs, bin_method bm
       where scf.taxon = ?
       and scf.scaffold_oid = bs.scaffold
       and b.bin_oid = bs.bin_oid
       and b.bin_method = bm.bin_method_oid
       and b.is_default = 'Yes'
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
    my $searchType = param("scaffoldSearchType");    # scaffold_name, read_id
    my $searchTerm = param("scaffoldSearchTerm");    # user text
    my $rangeType  = param("rangeType");             # seq_length, gc_percent, read_depth
    my $loRange    = param("loRange");               # user input
    my $hiRange    = param("hiRange");               # user input
    my $dataType   = param('dataType');              # assembled, unassembled

    if (   blankStr($searchTerm)
        && blankStr($loRange)
        && blankStr($hiRange) )
    {
        webError("Please enter a search term or substring or ranges.");
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

    # data files /global/dna/projectdirs/microbial/img_web_data_merfs/3300000146/assembled
    # scaffold_depth.sdb and scaffold_stats.sdb
    #
    # scaffold_depth.sdb file is optional - file is only created if the user submits the data.
    #
    # - ken

    my $searchTermLower = lc($searchTerm);

    my $scaffold_stats_sdb = $web_data_dir . '/mer.fs/' . $taxon_oid . '/' . $dataType . '/scaffold_stats.sdb';
    my $scaffold_depth_sdb = $web_data_dir . '/mer.fs/' . $taxon_oid . '/' . $dataType . '/scaffold_depth.sdb';

    if ( !-e $scaffold_stats_sdb ) {
        webError( "Cannot finds scaffold data files: $web_data_dir/"
              . $taxon_oid . '/'
              . $dataType
              . '/scaffold_stats.sdb' );
    }

    printMainForm();
    print "<h1>Scaffold Search Results</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $sdbh1 = WebUtil::sdbLogin( $scaffold_stats_sdb, '', 1 );
    my $sdbh2 = WebUtil::sdbLogin( $scaffold_depth_sdb, '', 1 ) if(-e $scaffold_depth_sdb && -s $scaffold_depth_sdb > $MIN_FILE_SIZE);

    my $clause1;
    my $clause2;

    if ( !blankStr($searchTerm) ) {
        if ( $searchType eq 'scaffold_name' ) {
            $clause1 = "where lower(scaffold_oid) like '%" . $searchTermLower . "%' ";
        } else {

            # no read id in merfs
        }
    }

    if ( !blankStr($loRange) && !blankStr($hiRange) ) {
        if ( $rangeType eq 'seq_length' ) {
            if ( $clause1 ne '' ) {
                $clause1 .= " and length between $loRange and $hiRange";
            } else {
                $clause1 = " where length between $loRange and $hiRange";
            }
        } elsif ( $rangeType eq 'gc_percent' ) {
            if ( $clause1 ne '' ) {
                $clause1 .= " and gc between $loRange and $hiRange";
            } else {
                $clause1 = " where gc between $loRange and $hiRange";
            }
        } else {

            # read_depth
            $clause2 = "where depth between $loRange and $hiRange";
        }
    }

    my $sql1 = qq{
        select scaffold_oid, length, gc
        from scaffold_stats
        $clause1
    };

    my $sql2 = qq{
        select scaffold_oid, depth
        from scaffold_depth
        $clause2
    };

    my %data1;
    if ( $clause1 ne '' ) {
        webLog("$sql1\n");
        my $sth1 = $sdbh1->prepare($sql1);
        $sth1->execute();
        for ( ; ; ) {
            my ( $oid, $length, $gc ) = $sth1->fetchrow_array();
            last if !$oid;
            $data1{$oid} = "$length\t$gc";
        }
        $sth1->finish();

        # add depth data
        webLog("select scaffold_oid, depth from scaffold_depth\n");
        if(-e $scaffold_depth_sdb && -s $scaffold_depth_sdb > $MIN_FILE_SIZE) {
        my $sth2 = $sdbh2->prepare('select scaffold_oid, depth from scaffold_depth');
        $sth2->execute();
        for ( ; ; ) {
            my ( $oid, $depth ) = $sth2->fetchrow_array();
            last if !$oid;
            if ( exists $data1{$oid} ) {
                $data1{$oid} = $data1{$oid} . "\t$depth";
            }
        }
        $sth2->finish();
        }
    }

    my %data2;
    if ((-e $scaffold_depth_sdb && -s $scaffold_depth_sdb > $MIN_FILE_SIZE) && ($clause2 ne '') ) {
        webLog("$sql2\n");
        my $sth2 = $sdbh2->prepare($sql2);
        $sth2->execute();
        for ( ; ; ) {
            my ( $oid, $depth ) = $sth2->fetchrow_array();
            last if !$oid;
            if ( !exists $data1{$oid} ) {
                $data2{$oid} = "$depth";
            }
        }
        $sth2->finish();

        # get other scaffold info
        my $size = keys %data2;
        if ( $size > 0 ) {
            webLog("select scaffold_oid, length, gc from scaffold_stats\n");
            my $sth1 = $sdbh1->prepare('select scaffold_oid, length, gc from scaffold_stats');
            $sth1->execute();
            for ( ; ; ) {
                my ( $oid, $length, $gc ) = $sth1->fetchrow_array();
                last if !$oid;
                if ( exists $data2{$oid} ) {
                    $data1{$oid} = "$length\t$gc\t" . $data2{$oid};
                }
            }
            $sth1->finish();
        }
    }

    $sdbh1->disconnect();
    $sdbh2->disconnect() if(-e $scaffold_depth_sdb && -s $scaffold_depth_sdb > $MIN_FILE_SIZE);

    my $itID  = "ScaffoldSearch";
    my $it    = new InnerTable( 1, "$itID$$", $itID, 0 );
    my $sd    = $it->getSdDelim();                          # sort delimiter
    my $count = 0;
    if ($scaffold_cart) {
        $it->addColSpec( "Select" );
    }
    $it->addColSpec( "Scaffold",                 "asc",  "left" );
    $it->addColSpec( "Sequence Length<br/>(bp)", "desc", "right" );
    $it->addColSpec( "GC Content",               "desc", "right" );
    $it->addColSpec( "Read Depth",               "desc", "right" );
    my $trunc = 0;

    for my $oid ( keys %data1 ) {
        my $scaffold_oid  = $oid;
        my $scaffold_name = $oid;
        my $line          = $data1{$oid};
        my ( $seq_length, $gc_percent, $read_depth ) = split( /\t/, $line );

        $count++;
        if ( $count >= $max_scaffold_results ) {
            $trunc = 1;
            last;
        }

        $gc_percent = sprintf( "%.2f", $gc_percent );
        $read_depth = sprintf( "%.2f", $read_depth ) if($read_depth ne '');
        $read_depth = "-" if ($read_depth == 0 || $read_depth eq '');

        #$scaffold_name .= " ($read_id)" if $read_id ne "";

        my $row;
        if ($scaffold_cart) {

            # 3300000547 assembled PR_CR_10_Liq_2_inCRDRAFT_1000001
            my $workspace_id = "$taxon_oid $dataType $scaffold_oid";
            $row .= $sd . "<input type='checkbox' name='scaffold_oid' value='$workspace_id' />\t";
        }

# main.cgi?section=MetaDetail&page=metaScaffoldDetail&taxon_oid=3300000547&scaffold_oid=PR_CR_10_Liq_2_inCRDRAFT_1000001&data_type=$dataType
        my $url =
"main.cgi?section=MetaDetail&page=metaScaffoldDetail&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid&data_type=$dataType";

        #print alink( $url, $scaffold_name );
        my $x = highlightMatchHTML2( $scaffold_name, $searchTerm );
        $x = escHtml($scaffold_name) if blankStr($searchTerm);
        $row .= $x . $sd . "<a href='$url'>$x</a>" . "\t";
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

    if ($trunc) {
        print "<p>\n";
        print "$count result rows are shown.\n";
        print "Please enter narrow query conditions.\n";
        print "</p>\n";
    }
    print end_form();
}

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
# printScaffolds - Show list of scaffold on chromosome page.
############################################################################
sub printScaffolds {
    my ($dist_type) = @_;

    my $taxon_oid    = param("taxon_oid");
    my $scaffold_oid = param("scaffold_oid");

    my $study  = param("study");
    my $sample = param("sample");
    if ( $sample eq "" ) {
        $sample = param("exp_samples");
    }

    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }
    if ( $data_type eq 'unassembled' ) {
        webError("Unassembled data not supported!");
    }

    if ( $pageSize == 0 ) {
        webDie("printScaffolds: invalid pageSize='$pageSize'\n");
    }

    printStatusLine( "Loading ...", 1 );

    printHint("Only assembled data supported.");
    print "<br/>";

    print "<h1>Scaffold Distribution</h1>\n";

    my $dbh = dbLogin();
    if ( $taxon_oid eq "" && $sample ne "" ) {
        my $sql;
        if ( $study eq "rnaseq" ) {
            $sql = qq{
                select dts.reference_taxon_oid
                from rnaseq_dataset dts
                where dts.dataset_oid = ?
            };
        } elsif ( $study eq "proteomics" ) {
            $sql = qq{
                select s.IMG_taxon_oid
                from ms_sample s
                where s.sample_oid = ?
            };
        } elsif ( $study eq "methylomics" ) {
            $sql = qq{
                select s.IMG_taxon_oid
                from meth_sample s
                where s.sample_oid = ?
            };
        }
        my $cur = execSql( $dbh, $sql, $verbose, $sample );
        ($taxon_oid) = $cur->fetchrow();
        $cur->finish();
    }

    if ( $taxon_oid eq "" ) {
        webDie("printScaffolds: taxon_oid not specified");
    }

    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my $file = $mer_data_dir . "/" . $taxon_oid . "/assembled/scaffold_stats.txt";

    my $scaffold_count = 0;
    my %scaffold_gene_count;
    my $min_len = 0;
    my $max_len = 0;
    my %scaffold_length;
    my @len_keys  = ();
    my $line      = "";
    my $start_tag = "";

    if ( -e $file ) {
        my $fh = newReadFileHandle($file);
        if ( !$fh ) {
            print "This genome has no genes on scaffolds to display.\n";
            return;
        }
        while ( $line = $fh->getline() ) {
            chomp $line;
            my ( $tag, $val ) = split( /[\t\s ]+/, $line );

            if ( $tag eq '.total_nScaffolds' ) {
                $scaffold_count = $val;
            } elsif ( $tag eq '.min_len' ) {
                $min_len = $val;
            } elsif ( $tag eq '.max_len' ) {
                $max_len = $val;
            } elsif ( $tag eq '.table_start' || $tag eq '.histogram_start' ) {
                $start_tag = $tag;
            } elsif ( $tag eq '.table_end' || $tag eq '.histogram_end' ) {
                $start_tag = "";
            } else {
                if ( $start_tag eq '.table_start' ) {
                    if ( WebUtil::isInt($tag) ) {
                        $scaffold_gene_count{$tag} = $val;
                    }
                } elsif ( $start_tag eq '.histogram_start' ) {
                    my ( $start2, $end2, $count2 ) = split( /\t/, $line );
                    $tag = $start2 . "_" . $end2;
                    push @len_keys, ($tag);
                    $scaffold_length{$tag} = $count2;
                }
            }
        }
        close $fh;
    } else {
        print "This genome has no genes on scaffolds to display.\n";
        return;
    }

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

    printMainForm();

    print hiddenVar( "taxon_oid", $taxon_oid );
    if ($dist_type) {
        print hiddenVar( 'dist_type', $dist_type );
    }

    if ( $dist_type eq 'gene_count' ) {
        printScaffoldDistribution( $taxon_oid, \%scaffold_gene_count, $dist_type, $study, $sample );
    } elsif ( $dist_type eq 'seq_length' ) {
        printScaffoldLengthDistribution( $taxon_oid, $min_len, $max_len, \@len_keys, \%scaffold_length, $dist_type, $study,
            $sample );
    } elsif ( $dist_type eq 'read_depth' ) {
        printScaffoldReadDistribution( $taxon_oid, $dist_type, $study, $sample );
    } else {
        #include Workspace.js on sites not done
        #through call to WorkspaceUtil::printSaveScaffoldDistToWorkspace()
        if ( ! ($enable_workspace && $user_restricted_site && !$public_nologin_site) )
        {
            print qq{
                <script type="text/javascript" src="$base_url/Workspace.js" >
                </script>
            };
        }

        TabHTML::printTabAPILinks("scafDistTab");
        my @tabIndex = ( "#scafdisttab1", "#scafdisttab2" );
        my @tabNames = ( "Gene Count",    "Sequence Length" );
        TabHTML::printTabDiv( "scafDistTab", \@tabIndex, \@tabNames );

        print "<div id='scafdisttab1'>";
        printScaffoldDistribution( $taxon_oid, \%scaffold_gene_count, 'gene_count', $study, $sample );
        print submit(
            -name    => "_section_ScaffoldCart_saveScaffoldDistToCart",
            -value   => "Add Selected to Scaffold Cart",
            -class   => "medbutton",
            -onClick => "return setParamAndCheck('dist_type', 'gene_count', 'Please make one or more selections.');"
        );
        print nbsp(1);
        print "\n";
        WebUtil::printButtonFooter();
        WorkspaceUtil::printSaveScaffoldDistToWorkspace( 'gene_count', 'dist_type' );
        print "</div>";

        print "<div id='scafdisttab2'>";
        printScaffoldLengthDistribution( $taxon_oid, $min_len, $max_len, \@len_keys, \%scaffold_length, 'seq_length', $study,
            $sample );
        print submit(
            -name    => "_section_ScaffoldCart_saveScaffoldDistToCart",
            -value   => "Add Selected to Scaffold Cart",
            -class   => "medbutton",
            -onClick => "return setParamAndCheck('dist_type', 'seq_length', 'Please make one or more selections.');"
        );
        print nbsp(1);
        print "\n";
        WebUtil::printButtonFooter();
        WorkspaceUtil::printSaveScaffoldDistToWorkspace( 'seq_length', 'dist_type' );
        print "</div>";

        TabHTML::printTabDivEnd();
    }

    if ( $dist_type eq 'gene_count' || $dist_type eq 'seq_length' ) {

        #|| $dist_type eq 'read_depth' ) {   # TO DO
        print submit(
            -name    => "_section_ScaffoldCart_saveScaffoldDistToCart",
            -value   => "Add Selected to Scaffold Cart",
            -class   => "medbutton",
            -onClick => "return isChecked('$dist_type', 'Please make one or more selections.');"
        );
        print nbsp(1);
        print "\n";
        WebUtil::printButtonFooter();

        WorkspaceUtil::printSaveScaffoldDistToWorkspace($dist_type);
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
    return;
}

sub printStudySampleSelect {
    my ( $taxon_oid, $study, $sample ) = @_;
    if ( $sample ne "" && $sample eq '0' ) {
        print qq{
            <script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
            </script>

            <script language='JavaScript' type='text/javascript'>
            function showView(type) {
            if (type == 'slim') {
                document.getElementById('showsamples').style.display = 'none';
                document.getElementById('hidesamples').style.display = 'block';
            } else {
                document.getElementById('showsamples').style.display = 'block';
                document.getElementById('hidesamples').style.display = 'none';
            }
            }

            YAHOO.util.Event.onDOMReady(function () {
                showView('slim');
            });
            </script>
        };

        my $val = "Protein";
        if ( $study eq "rnaseq" ) {
            $val = "RNASeq";
        }
        if ( $sample ne "" ) {
            print hiddenVar( "sample", $sample );
            print hiddenVar( "study",  $study );
        }

        print "<div id='hidesamples' style='display: block;'>";
        print "<input type='button' class='medbutton' name='view'"
          . " value='Select "
          . $val
          . " Samples'"
          . " onclick='showView(\"full\")' />";
        print "</div>\n";

        print "<div id='showsamples' style='display: block;'>";
        print "<input type='button' class='medbutton' name='view'"
          . " value='Hide "
          . $val
          . " Samples'"
          . " onclick='showView(\"slim\")' />";

        print "<h2>Samples for Selected Genome</h2>\n";
        print "<p>Select a sample to color the chromosome " . "by expression values for that sample</p>";

        if ( $study eq "rnaseq" ) {
            RNAStudies::printSelectOneSample($taxon_oid);
        } else {
            IMGProteins::printSelectOneSample($taxon_oid);
        }
        print "</div>\n";

        # this is needed for "color by expression" (samples)
        # empty link_scaffold_oid is set by dosubmit function!
        print hiddenVar( "link_scaffold_oid", 1 );
        print hiddenVar( "taxon_oid",         1 );
        print hiddenVar( "start_coord",       1 );
        print hiddenVar( "end_coord",         1 );
        print hiddenVar( "seq_length",        1 );
        print hiddenVar( "userEntered",       1 );

        ## clicking on the links for each scaffold calls this
        ## script to set the selected sample in the url
        print qq{
        <script language="JavaScript" type="text/javascript">
        function dosubmit(taxon_oid, scaffold_oid, start_coord, end_coord,
                          seq_length, sample, user) {
            for (var i=0; i<document.mainForm.elements.length; i++) {
                var el = document.mainForm.elements[i];
                if (el.type == "hidden") {
                    if (el.name == "link_scaffold_oid") {
                        el.value = scaffold_oid;
                    } else if (el.name == "taxon_oid") {
                        el.value = taxon_oid;
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
                }
            }
            document.mainForm.submit();
        }
        </script>
        };

        # this is for clicking on range and "submitting" the selected sample
        my $name = "_section_MetaScaffoldGraph_viewerScaffoldGraph";
        print "<input type='hidden' name='$name' value='Submit' >";
    }
}

############################################################################
# printScaffoldDistribution - Show distribution of scaffolds from
#   scaffolds with most genes to least.  Used as alternate presentation
#   if there are too many scaffolds.
############################################################################
sub printScaffoldDistribution {
    my ( $taxon_oid, $h_count, $dist_type, $study, $sample ) = @_;

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $url = "$section_cgi&page=scaffoldsByGeneCount&taxon_oid=$taxon_oid";
    if ( $study && $study ne "" ) {
        $url .= "&study=$study&sample=$sample";
    }

    my @chartseries;
    my @chartcategories;
    my @chartdata;

    print "<h2>Scaffolds by Gene Count</h2>\n";

    my @binKeys = reverse( sort { $a <=> $b } ( keys(%$h_count) ) );
    my $chart_width = ( scalar @binKeys ) * 30;
    $chart_width = 300 if $chart_width < 300;
    my $table_width = $chart_width + 400;

    print "<table width=$table_width border=0>\n";
    print "<tr>";
    print "<td align=left valign=top>\n";

    print "The number of scaffolds is shown in parenthesis.\n";
    print "<p>\n";

    for my $k (@binKeys) {
        my $nGenes = sprintf( "%d", $k );
        my $url2   = "$url&gene_count=$nGenes";
        my $binCnt = $h_count->{$k};
        my $genes  = "genes";
        $genes = "gene" if $nGenes == 1;

        if ($dist_type) {
            print "<input type='checkbox' name='$dist_type' " . "value='$nGenes' />" . "\t";
        }
        print "Scaffolds having $nGenes $genes ";
        print "(" . alink( $url2, $binCnt ) . ")<br/>\n";

        push @chartcategories, "$nGenes";
        push @chartdata,       $binCnt;
    }
    print "</td><td valign=top align=right>\n";

    # display the bar chart
    push @chartseries, "num scaffolds";
    my $datastr = join( ",", @chartdata );
    my @datas   = ($datastr);

    # PREPARE THE BAR CHART
    my $chart = ChartUtil::newBarChart();

    #my $chart = ChartUtil::newBarChart3D();
    $chart->WIDTH($chart_width);
    $chart->HEIGHT(700);
    $chart->DOMAIN_AXIS_LABEL("Scaffolds having n genes");
    $chart->RANGE_AXIS_LABEL("Number of scaffolds");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("no");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_URLS("no");
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->DATA( \@datas );
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL( $url . "&chart=y" );

    print "<td valign=top>\n";
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
}

############################################################################
# addToScaffoldCart
############################################################################
sub addToScaffoldCart {
    my $taxon_oid  = param("taxon_oid");
    my $gene_count = param("gene_count");

    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }

    if ( $pageSize == 0 ) {
        webDie("printScaffoldsByGeneCount: invalid pageSize='$pageSize'\n");
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    #my $taxon_display_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );

    #$dbh->disconnect();

    # get scaffold detail from file
    my @scaffold_oids;

    if ( $data_type ne 'unassembled' ) {
        my $t2 = 'assembled';
        my ( $trunc, $rows_ref, $scafs_ref ) =
          MetaUtil::getScaffoldStatsWithFixedGeneCnt( $taxon_oid, $t2, $gene_count, $maxGeneListResults );

        for my $scaf_oid (@$scafs_ref) {
            my $workspace_id = "$taxon_oid $t2 $scaf_oid";
            push @scaffold_oids, $workspace_id;
        }
    }

    require ScaffoldCart;
    ScaffoldCart::addToScaffoldCart( \@scaffold_oids );
    ScaffoldCart::printIndex();
}

sub printScaffoldReadDistribution {
    my ( $taxon_oid, $dist_type, $study, $sample ) = @_;

    my ( $lo2, $hi2, $totalscfs );
    if ( $taxon_oid eq "" ) {
        $taxon_oid = param("taxon_oid");
        $dist_type = "read_depth";
        $study     = param("study");
        $sample    = param("sample");
        $lo2       = param("lo");
        $hi2       = param("hi");
        $totalscfs = param("total_scfs");
    }
    $taxon_oid = sanitizeInt($taxon_oid);

    printStatusLine( "Loading ...", 1 );

    if ( $lo2 ne "" && $hi2 ne "" ) {
        print "<h2>Scaffolds by Read Depth $lo2..$hi2</h2>";

        my $dbh = dbLogin();
        checkTaxonPerm( $dbh, $taxon_oid );
        my $sql = qq{
            select taxon_display_name
            from taxon
            where taxon_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my $taxon_display_name = $cur->fetchrow();
        $cur->finish();

        #$dbh->disconnect();

        print "<p style='width: 650px;'>\n";
        $taxon_display_name = escapeHTML($taxon_display_name);
        my $url = "$main_cgi?section=MetaDetail" . "&page=metaDetail&taxon_oid=$taxon_oid";
        print alink( $url, $taxon_display_name, "_blank" );
        print "</p>\n";

    } else {
        print "<h2>Scaffolds by Read Depth</h2>\n";
    }

    WebUtil::unsetEnvPath();
    my $zip_file = $mer_data_dir . "/$taxon_oid/assembled/scaffold_depth.zip";
    my %scaffold_read_depth;
    my $hi;
    my $lo;
    my $idx = 0;
    if ( -e $zip_file ) {
        my $fh = newCmdFileHandle("/usr/bin/unzip -p $zip_file");
        if ( !$fh ) {
            print "This genome has no genes on scaffolds to display.\n";
            return;
        }

        while ( my $line = $fh->getline() ) {
            chomp $line;
            my ( $tag, $val ) = split( /[\t\s ]+/, $line );
            if ( $val && isNumber($val) ) {
                my $depth = floor( $val + 0.5 );

                if ( $lo2 ne "" && $hi2 ne "" && $totalscfs ne "" ) {
                    if ( $depth >= $lo2 && $depth <= $hi2 ) {
                        $scaffold_read_depth{$tag} = $depth;
                    }
                } else {
                    $scaffold_read_depth{$tag} = $depth;
                    if ( $idx == 0 ) {
                        $lo = $depth;
                        $hi = $depth;
                    } else {
                        $lo = $depth if ( $depth < $lo );
                        $hi = $depth if ( $depth > $hi );
                    }
                }
            }
            $idx++;
        }
        close $fh;
    } else {
        print "This genome has no read depth data.\n";
        return;
    }
    WebUtil::resetEnvPath();

    my $numbins = 10;
    my $width   = $hi - $lo + 1;
    my $binsize = ceil( $width / $numbins );

    if ( $lo2 ne "" && $hi2 ne "" && $totalscfs ne "" ) {
        if ( $totalscfs <= 1000 || $hi2 - $lo2 == 0 ) {

            # print list of scaffolds
            printMainForm();

            my $it = new InnerTable( 1, "scfsbydpth$$", "scfsbydepth", 1 );
            my $sd = $it->getSdDelim();
            if ($scaffold_cart) {
                $it->addColSpec( "Select" );
            }
            $it->addColSpec( "Scaffold",                 "asc",  "left" );
            $it->addColSpec( "Sequence Length<br/>(bp)", "desc", "right" );
            $it->addColSpec( "GC Content",               "desc", "right" );
            $it->addColSpec( "Gene Count",               "desc", "right" );
            $it->addColSpec( "Read Depth",               "desc", "right" );

            my $count             = 0;
            my @scaffolds         = keys %scaffold_read_depth;
            my $statsForScaffolds = MetaUtil::getScaffoldStatsForTaxonScaffolds2( $taxon_oid, "assembled", \@scaffolds );

            foreach my $scf ( sort keys %scaffold_read_depth ) {
                my %stats = %$statsForScaffolds;
                my ( $s, $seq_length, $gc, $gcount ) = split( '\t', $stats{$scf} );

                my $r;
                my $workspace_id = "$taxon_oid assembled $scf";
                $r .= $sd . "<input type='checkbox' name='scaffold_oid' " . "value='$workspace_id' />" . "\t";

                my $s_url =
                    "$main_cgi?section=MetaDetail&page=metaScaffoldDetail"
                  . "&taxon_oid=$taxon_oid&scaffold_oid=$scf&data_type=assembled";
                $r .= $workspace_id . $sd . alink( $s_url, $scf ) . "\t";
                $r .= $seq_length . $sd . $seq_length . "\t";
                my $gc_percent = sprintf( "%.2f", $gc );
                $r .= $gc_percent . $sd . $gc_percent . "\t";

                my $g_url =
                  "$main_cgi?section=MetaDetail" . "&page=metaScaffoldGenes" . "&taxon_oid=$taxon_oid&scaffold_oid=$scf";
                if ($gcount) {
                    $r .= $gcount . $sd . alink( $g_url, $gcount ) . "\t";
                } else {
                    $r .= $gcount . $sd . $gcount . "\t";
                }
                my $depth = $scaffold_read_depth{$scf};
                $r .= $depth . $sd . $depth . "\t";
                $it->addRow($r);
                $count++;
            }

            WebUtil::printScaffoldCartFooter()
              if ( $scaffold_cart && $count > 10 );
            $it->printOuterTable(1);
            WebUtil::printScaffoldCartFooter() if $scaffold_cart;
            print end_form();

            printStatusLine( "Loaded $count scaffolds", 2 );
            return;
        }

        $lo = $lo2;
        $hi = $hi2;
        if ( $numbins > $totalscfs ) {
            $numbins = $totalscfs;
        }
        $width   = $hi2 - $lo2 + 1;
        $binsize = ceil( $width / $numbins );
    }

    my %bins;
    for ( my $i = 1 ; $i <= $numbins ; $i++ ) {
        my $key = $lo + $binsize * $i;
        if ( $hi < $key ) {
            $key = $hi;
        }
        $bins{$key} = 0;
    }
  OUTER: foreach my $key ( keys %scaffold_read_depth ) {
        my $val = $scaffold_read_depth{$key};
        for ( my $i = 1 ; $i <= $numbins ; $i++ ) {
            my $bin = $lo + $binsize * $i;
            if ( $hi < $bin ) {
                $bin = $hi;
            }
            if ( $val <= $bin ) {
                $bins{$bin}++;
                next OUTER;
            }
        }
    }

    my @chartseries;
    my @chartcategories;
    my @chartdata;

    my $chart_width = 800;
    $chart_width = (10) * 30;
    my $table_width = $chart_width + 400;

    print "<table width=$table_width border=0>\n";
    print "<tr>";
    print "<td align=left valign=top>\n";
    print "The number of scaffolds having read depth in the " . "specified range is shown in parenthesis.\n";
    print "<p>\n";

    my $url = "$section_cgi&page=scaffoldsByReadDepth&taxon_oid=$taxon_oid";
    if ( $study && $study ne "" ) {
        $url .= "&study=$study&sample=$sample";
    }

    my $low = $lo;
    for ( my $i = 1 ; $i <= $numbins ; $i++ ) {
        my $bin = $lo + $binsize * $i;

        if ( $hi < $bin ) {
            $bin = $hi;
        }
        my $bincount = $bins{$bin};

        push @chartcategories, "$low..$bin";
        push @chartdata,       $bincount;

        if ($dist_type) {
            print "<input type='checkbox' name='$dist_type' " . "value='$low:$bin' />" . "\t";
        }

        if ( $bincount == 0 ) {
            print "Read depth between $low .. $bin (0)\n<br>";
        } else {
            print "Read depth between $low .. $bin ("
              . alink( $url . "&lo=$low&hi=$bin&total_scfs=$bincount", $bincount )
              . ")\n<br>";
        }
        $low = $bin + 1;
        last if $bin == $hi;
    }

    print "</td>\n";

    # display the bar chart
    push @chartseries, "num scaffolds";
    my $datastr = join( ",", @chartdata );
    my @datas   = ($datastr);

    # PREPARE THE BAR CHART
    my $chart = ChartUtil::newBarChart();

    $chart->WIDTH($chart_width);
    $chart->HEIGHT(700);
    $chart->DOMAIN_AXIS_LABEL("Read depth");
    $chart->RANGE_AXIS_LABEL("Number of scaffolds");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("no");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_URLS("no");
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->DATA( \@datas );

    print "<td valign=top>\n";
    if ( $env->{chart_exe} ne "" ) {
        my $st = generateChart($chart);
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html",
		  "printScaffoldReadDistribution", 1 );
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
}

############################################################################
# printScaffoldLengthDistribution - Show distribution of scaffolds from
#   scaffolds with most genes to least.  Used as alternate presentation
#   if there are too many scaffolds.
############################################################################
sub printScaffoldLengthDistribution {
    my ( $taxon_oid, $minlength, $maxlength, $keys, $h_length, $dist_type, $study, $sample ) = @_;

    printStatusLine( "Loading ...", 1 );

    print "<h2>Scaffolds by Sequence Length</h2>\n";

    my @chartseries;
    my @chartcategories;
    my @chartdata;

    my $chart_width = ( scalar @$keys ) * 30;
    $chart_width = 300 if $chart_width < 300;
    my $table_width = $chart_width + 400;

    print "<table width=$table_width border=0>\n";
    print "<tr>";
    print "<td align=left valign=top>\n";

    print "The number of scaffolds having genes is shown in parenthesis.\n";
    print "<p>\n";

    my $url = "$section_cgi&page=scaffoldsByLengthCount&taxon_oid=$taxon_oid";
    if ( $study && $study ne "" ) {
        $url .= "&study=$study&sample=$sample";
    }

    # EQUAL WIDTH BINS
    my $numbins   = 10;
    my $width     = $maxlength - $minlength + 1;
    my $binsize   = $width / $numbins;
    my $idx       = 0;
    my $lastupper = -1;
    for my $i (@$keys) {
        my ( $lower, $upper ) = split( /\_/, $i );
        $lastupper = $upper;
        my $bincount = $h_length->{$i};

        my $url2 = "$url&scf_length=$lower-$upper";
        if ( $bincount > 1000 ) {
            $url2 = "$section_cgi&page=scaffoldsLengthBreakDown" . "&taxon_oid=$taxon_oid" . "&scf_length=$lower-$upper";
            if ( $study && $study ne "" ) {
                $url2 .= "&study=$study&sample=$sample";
            }
        }
        push @chartcategories, "$lower..$upper";
        push @chartdata,       $bincount;

        if ($dist_type) {
            print "<input type='checkbox' name='$dist_type' " . "value='$lower:$upper' />" . "\t";
        }

        if ( $bincount == 0 ) {
            print "Scaffold length between $lower .. $upper (0)\n<br>";
        } else {
            print "Scaffold length between $lower .. $upper (" . alink( $url2, $bincount ) . ")\n<br>";
        }
    }
    print "</td>\n";

    # display the bar chart
    push @chartseries, "num scaffolds";
    my $datastr = join( ",", @chartdata );
    my @datas   = ($datastr);

    # PREPARE THE BAR CHART
    my $chart = ChartUtil::newBarChart();

    #my $chart = ChartUtil::newBarChart3D();
    $chart->WIDTH($chart_width);
    $chart->HEIGHT(700);
    $chart->DOMAIN_AXIS_LABEL("Scaffold length");
    $chart->RANGE_AXIS_LABEL("Number of scaffolds");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("no");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_URLS("no");
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->DATA( \@datas );

    print "<td valign=top>\n";
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
}

############################################################################
# printScaffoldsByLengthCount - Show scaffolds with one value of length.
#   Drill down from above distribution of scaffolds.
############################################################################
sub printScaffoldsByLengthCount {
    my $taxon_oid  = param("taxon_oid");
    my $scf_length = param("scf_length");
    my $chart      = param("chart");
    my $study      = param("study");
    my $sample     = param("sample");

    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }
    if ( $data_type eq 'unassembled' ) {
        webError("Unassembled data not supported!");
    }

    # if this is invoked by the bar chart, then pre-process URL
    if ( $chart eq "y" ) {
        my $category = param("category");
        $category =~ s/\.\./-/g;
        $scf_length = $category;
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my ( $minlength, $maxlength ) = split( "-", $scf_length );
    my $lower = param('lower');
    my $upper = param('upper');
    if ( !WebUtil::isInt($minlength) || !WebUtil::isInt($maxlength) ) {
        webError("Incorrect scaffold length: $scf_length.");
        return;
    }
    if ( !$lower || !WebUtil::isInt($lower) ) {
        $lower = $minlength;
    }
    if ( !$upper || !WebUtil::isInt($upper) ) {
        $upper = $maxlength;
    }
    if ( $lower < $minlength || $upper > $maxlength ) {
        webError("Incorrect range: $lower .. $upper.");
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    printHint("Only assembled data supported.");
    print "<br/>";

    my $subtitle = "Scaffolds with length between $lower-$upper\n";
    if ( $lower == $upper ) {
        $subtitle = "Scaffolds with length = $lower\n";
    }
    print "<h1>$subtitle</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    if ( $sample ne "" && $sample eq '0' ) {
        printStudySampleSelect( $taxon_oid, $study, $sample );
    }

    # get scaffold detail from file
    $taxon_oid = sanitizeInt($taxon_oid);
    $minlength = sanitizeInt($minlength);
    $maxlength = sanitizeInt($maxlength);

    # get scaffold detail from file
    my $t2 = 'assembled';
    my ( $trunc, $rows_ref, $scafs_ref ) =
      MetaUtil::getScaffoldStatsInLengthRange( $taxon_oid, $t2, $lower, $upper, $maxGeneListResults );

    my %scaffold_depth_h;
    my %scaffold_lineage_h;
    if ($include_metagenomes) {
        %scaffold_depth_h = MetaUtil::getScaffoldDepthForTaxonScaffolds( $taxon_oid, $t2, $scafs_ref );

        #print Dumper(\%scaffold_depth_h);

        %scaffold_lineage_h = MetaUtil::getScaffoldLineageForTaxonScaffolds( $taxon_oid, $t2, $scafs_ref );

        #print Dumper(\%scaffold_lineage_h);
    }

    my $it = new InnerTable( 1, "scaffold$$", "scaffold", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    if ($scaffold_cart) {
        $it->addColSpec( "Select" );
    }
    $it->addColSpec( "Scaffold",                 "asc",  "left" );
    $it->addColSpec( "Topology",                 "asc",  "left" );
    $it->addColSpec( "Sequence Length<br/>(bp)", "desc", "right" );
    $it->addColSpec( "GC Content",               "desc", "right" );
    if ($include_metagenomes) {
        $it->addColSpec( "Read Depth",         "asc", "right" );
        $it->addColSpec( "Lineage",            "asc", "left" );
        $it->addColSpec( "Lineage Percentage", "asc", "right" );
    }
    $it->addColSpec( "Gene Count", "desc", "right" );
    $it->addColSpec( "Coordinate Range" );

    my $select_id_name = "scaffold_oid";
    my $mol_topology   = "linear";

    my $count = 0;
    for my $line (@$rows_ref) {
        my ( $scaffold_oid, $seq_length, $gc_percent, $gene_cnt ) =
          split( /\t/, $line );

        my $r;
        my $workspace_id = "$taxon_oid $t2 $scaffold_oid";
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$workspace_id' />" . "\t";

        my $s_url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail";
        $s_url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid&data_type=$t2";
        $r     .= $workspace_id . $sd . alink( $s_url, $scaffold_oid ) . "\t";

        $r .= $mol_topology . $sd . $mol_topology . "\t";
        $r .= $seq_length . $sd . $seq_length . "\t";
        $gc_percent = sprintf( "%.2f", $gc_percent );
        $r .= $gc_percent . $sd . $gc_percent . "\t";

        if ($include_metagenomes) {
            my $scaf_depth = $scaffold_depth_h{$workspace_id};
            if ( !$scaf_depth ) {
                $scaf_depth = 1;
            }
            $r .= $scaf_depth . $sd . "$scaf_depth\t";

            my $scaf_lineage = $scaffold_lineage_h{$workspace_id};
            my ( $lineage, $lineage_perc, $rank ) = split( /\t/, $scaf_lineage );
            $r .= $lineage . $sd . "$lineage\t";
            $r .= $lineage_perc . $sd . "$lineage_perc\t";
        }

        my $g_url = "$main_cgi?section=MetaDetail&page=metaScaffoldGenes";
        $g_url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
        if ($gene_cnt) {
            $r .= $gene_cnt . $sd . alink( $g_url, $gene_cnt ) . "\t";
        } else {
            $r .= $gene_cnt . $sd . $gene_cnt . "\t";
        }

        my $url = "$main_cgi?section=MetaScaffoldGraph&page=metaScaffoldGraph";
        $url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
        if ( $study && $study ne "" ) {
            $url .= "&study=$study&sample=$sample";
        }

        if ( $seq_length < $pageSize ) {
            my $range = "1\.\.$seq_length";
            my $xurl  = $url . "&start_coord=1&end_coord=$seq_length";
            if ( $sample ne "" && $sample eq '0' ) {
                my $func =
                  "javascript:dosubmit($taxon_oid, '$scaffold_oid', " . "1, $seq_length, $seq_length, '$sample', 0);";
                my $tmp = "<a href=\"$func\">$range</a><br/> ";
                $r .= $range . $sd . $tmp . "\t";
            } else {
                $r .= $range . $sd . alink( $xurl, $range ) . "\t";
            }
        } else {
            my $tmp;
            my $last = 1;
            for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
                my $curr  = $i;
                my $range = "$last\.\.$curr";
                my $xurl  = $url . "&start_coord=$last&end_coord=$curr" . "&seq_length=$seq_length";
                if ( $sample ne "" && $sample eq '0' ) {
                    my $func =
                        "javascript:dosubmit"
                      . "($taxon_oid, '$scaffold_oid', '$last', "
                      . "'$curr', '$seq_length', '$sample', '0');";
                    $tmp .= "<a href=\"$func\">$range</a><br/> ";
                } else {
                    $tmp .= alink( $xurl, $range ) . "<br/> ";
                }
                $last = $curr + 1;
            }
            if ( $last < $seq_length ) {
                my $range = "$last\.\.$seq_length";
                my $xurl  = $url . "&start_coord=$last&end_coord=$seq_length";
                if ( $sample ne "" && $sample eq '0' ) {
                    my $func =
                        "javascript:dosubmit"
                      . "($taxon_oid, '$scaffold_oid', '$last', "
                      . "'$seq_length', '$seq_length', '$sample', '0');";
                    $tmp .= "<a href=\"$func\">$range</a><br/> ";
                } else {
                    $tmp .= alink( $xurl, $range ) . " ";
                }
            }
            $r .= $sd . $tmp . "\t";
        }

        $it->addRow($r);

        $count++;
        if ( $count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }    # end while

    WebUtil::printScaffoldCartFooter() if ( $scaffold_cart && $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printScaffoldCartFooter() if $scaffold_cart;

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    }

    if ($trunc) {
        printStatusLine( "Results limited to $maxGeneListResults scaffolds.", 2 );
    } else {
        printStatusLine( "$count Loaded.", 2 );
    }

    print end_form();
    return;
}

############################################################################
# printScaffoldsByGeneCount - Show scaffolds with one value of gene count.
#   Drill down from above distribution of scaffolds.
############################################################################
sub printScaffoldsByGeneCount {
    my $taxon_oid  = param("taxon_oid");
    my $gene_count = param("gene_count");
    my $chart      = param("chart");
    my $study      = param("study");
    my $sample     = param("sample");

    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }
    if ( $data_type eq 'unassembled' ) {
        webError("Unassembled data not supported!");
    }

    # if this is invoked by the bar chart, then pre-process URL
    if ( $chart eq "y" ) {
        my $category = param("category");
        $gene_count = $category;
    }

    if ( $pageSize == 0 ) {
        webDie("printScaffoldsByGeneCount: invalid pageSize='$pageSize'\n");
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    printHint("Only assembled data supported.");
    print "<br/>";

    my $subtitle = "Scaffolds having $gene_count gene(s)\n";
    print "<h1>$subtitle</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    if ( $sample ne "" && $sample eq '0' ) {
        printStudySampleSelect( $taxon_oid, $study, $sample );
    }

    # get scaffold detail from file
    my $t2 = 'assembled';
    my ( $trunc, $rows_ref, $scafs_ref ) =
      MetaUtil::getScaffoldStatsWithFixedGeneCnt( $taxon_oid, $t2, $gene_count, $maxGeneListResults );

    my %scaffold_depth_h;
    my %scaffold_lineage_h;
    if ($include_metagenomes) {
        %scaffold_depth_h = MetaUtil::getScaffoldDepthForTaxonScaffolds( $taxon_oid, $t2, $scafs_ref );

        #print Dumper(\%scaffold_depth_h);

        %scaffold_lineage_h = MetaUtil::getScaffoldLineageForTaxonScaffolds( $taxon_oid, $t2, $scafs_ref );

        #print Dumper(\%scaffold_lineage_h);
    }

    my $it = new InnerTable( 1, "scaffold$$", "scaffold", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    if ($scaffold_cart) {
        $it->addColSpec( "Select" );
    }
    $it->addColSpec( "Scaffold",                 "asc",  "left" );
    $it->addColSpec( "Topology",                 "asc",  "left" );
    $it->addColSpec( "Sequence Length<br/>(bp)", "desc", "right" );
    $it->addColSpec( "GC Content",               "desc", "right" );
    if ($include_metagenomes) {
        $it->addColSpec( "Read Depth",         "asc", "right" );
        $it->addColSpec( "Lineage",            "asc", "left" );
        $it->addColSpec( "Lineage Percentage", "asc", "right" );
    }
    $it->addColSpec( "Gene Count", "desc", "right" );
    $it->addColSpec( "Coordinate Range" );

    my $select_id_name = "scaffold_oid";
    my $mol_topology   = "linear";

    my $count = 0;
    for my $line (@$rows_ref) {
        my ( $scaffold_oid, $seq_length, $gc_percent, $cnt ) =
          split( /\t/, $line );

        my $r;
        my $workspace_id = "$taxon_oid $t2 $scaffold_oid";
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$workspace_id' />" . "\t";

        my $s_url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail";
        $s_url .= "&taxon_oid=$taxon_oid&data_type=$t2&scaffold_oid=$scaffold_oid";
        $r     .= $workspace_id . $sd . alink( $s_url, $scaffold_oid ) . "\t";

        $r .= $mol_topology . $sd . $mol_topology . "\t";
        $r .= $seq_length . $sd . $seq_length . "\t";
        $gc_percent = sprintf( "%.2f", $gc_percent );
        $r .= $gc_percent . $sd . $gc_percent . "\t";

        if ($include_metagenomes) {
            my $scaf_depth = $scaffold_depth_h{$workspace_id};
            if ( !$scaf_depth ) {
                $scaf_depth = 1;
            }
            $r .= $scaf_depth . $sd . "$scaf_depth\t";

            my $scaf_lineage = $scaffold_lineage_h{$workspace_id};
            my ( $lineage, $lineage_perc, $rank ) = split( /\t/, $scaf_lineage );
            $r .= $lineage . $sd . "$lineage\t";
            $r .= $lineage_perc . $sd . "$lineage_perc\t";
        }

        my $g_url = "$main_cgi?section=MetaDetail&page=metaScaffoldGenes";
        $g_url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid&data_type=assembled";
        $r     .= $gene_count . $sd . alink( $g_url, $gene_count ) . "\t";

        my $url = "$main_cgi?section=MetaScaffoldGraph&page=metaScaffoldGraph";
        $url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
        if ( $study && $study ne "" ) {
            $url .= "&study=$study&sample=$sample";
        }

        if ( $seq_length < $pageSize ) {
            my $range = "1\.\.$seq_length";
            my $xurl  = $url . "&start_coord=1&end_coord=$seq_length";
            if ( $sample ne "" && $sample eq '0' ) {
                my $func =
                  "javascript:dosubmit($taxon_oid, '$scaffold_oid', " . "1, $seq_length, $seq_length, '$sample', 0);";
                my $tmp = "<a href=\"$func\">$range</a><br/> ";
                $r .= $range . $sd . $tmp . "\t";
            } else {
                $r .= $range . $sd . alink( $xurl, $range ) . "\t";
            }
        } else {
            my $tmp;
            my $last = 1;
            for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
                my $curr  = $i;
                my $range = "$last\.\.$curr";
                my $xurl  = $url . "&start_coord=$last&end_coord=$curr" . "&seq_length=$seq_length";

                if ( $sample ne "" && $sample eq '0' ) {
                    my $func =
                        "javascript:dosubmit"
                      . "($taxon_oid, '$scaffold_oid', '$last', "
                      . "'$curr', '$seq_length', '$sample', '0');";
                    $tmp .= "<a href=\"$func\">$range</a><br/> ";
                } else {
                    $tmp .= alink( $xurl, $range ) . "<br/> ";
                }
                $last = $curr + 1;
            }
            if ( $last < $seq_length ) {
                my $range = "$last\.\.$seq_length";
                my $xurl  = $url . "&start_coord=$last&end_coord=$seq_length";
                if ( $sample ne "" && $sample eq '0' ) {
                    my $func =
                        "javascript:dosubmit"
                      . "($taxon_oid, '$scaffold_oid', '$last', "
                      . "'$seq_length', '$seq_length', '$sample', '0');";
                    $tmp .= "<a href=\"$func\">$range</a><br/> ";
                } else {
                    $tmp .= alink( $xurl, $range ) . " ";
                }
            }
            $r .= $sd . $tmp . "\t";
        }

        $it->addRow($r);

        $count++;
        if ( $count > $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }    # end while

    WebUtil::printScaffoldCartFooter() if ( $count > 10 && $scaffold_cart );
    $it->printOuterTable(1);
    if ($scaffold_cart) {
        my $name   = "_section_ScaffoldCart_addToScaffoldCart";
        my $errMsg = "Please make one or more selections.";
        print submit(
            -name    => $name,
            -value   => "Add Selected to Scaffold Cart",
            -class   => "meddefbutton",
            -onClick => "return isChecked ('scaffold_oid', '$errMsg');"
        );
    }
    print nbsp(1);
    print "\n";
    WebUtil::printButtonFooterInLine();
    print "<br>\n";

    if ( $count > 0 && $scaffold_cart ) {
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    }

    if ($trunc) {
        printStatusLine( "Results limited to $maxGeneListResults scaffolds.", 2 );
    } else {
        printStatusLine( "$count Loaded.", 2 );
    }

    print end_form();
}

############################################################################
# listScaffolds
############################################################################
sub listScaffolds {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $subtitle = "Scaffold List";
    print "<h1>$subtitle</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    # get scaffold detail from file

    printStartWorkingDiv();
    print "<p>Retrieving scaffold information ...<br/>\n";

    my $it = new InnerTable( 1, "scaffold$$", "scaffold", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    if ($scaffold_cart) {
        $it->addColSpec( "Select" );
    }
    $it->addColSpec( "Scaffold",                 "asc",  "left" );
    $it->addColSpec( "Sequence Length<br/>(bp)", "desc", "right" );
    $it->addColSpec( "GC Content",               "desc", "right" );
    $it->addColSpec( "Topology",                 "asc",  "left" );
    $it->addColSpec( "Gene Count",               "desc", "right" );
    $it->addColSpec( "Coordinate Range" );

    my $select_id_name = "scaffold_oid";

    my ( $trunc, @lines ) = MetaUtil::getScaffoldStatsForTaxon( $taxon_oid, $data_type );

    my $count = 0;
    my $trunc = 0;
    for my $line (@lines) {

        my ( $scaffold_oid, $seq_length, $gc_percent, $gene_cnt ) =
          split( /\t/, $line );
        my $start_coord = 1;
        my $end_coord   = $start_coord + $seq_length - 1;

        my $r;
        my $workspace_id = "$taxon_oid $data_type $scaffold_oid";
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$workspace_id' />" . "\t";

        my $s_url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail";
        $s_url .= "&taxon_oid=$taxon_oid&data_type=$data_type&scaffold_oid=$scaffold_oid";
        $r     .= $workspace_id . $sd . alink( $s_url, $scaffold_oid ) . "\t";

        $r .= $seq_length . $sd . $seq_length . "\t";

        if ( !$gc_percent ) {
            $gc_percent = MetaUtil::getScaffoldGc( $taxon_oid, $data_type, $scaffold_oid );
        }
        $gc_percent = sprintf( "%.2f", $gc_percent );
        $r .= $gc_percent . $sd . $gc_percent . "\t";

        my $mol_topology = "linear";
        $r .= $mol_topology . $sd . $mol_topology . "\t";

        my $g_url = "$main_cgi?section=MetaDetail&page=metaScaffoldGenes";
        $g_url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
        if ($gene_cnt) {
            $r .= $gene_cnt . $sd . alink( $g_url, $gene_cnt ) . "\t";
        } else {
            $r .= $gene_cnt . $sd . $gene_cnt . "\t";
        }

        my $url = "$main_cgi?section=MetaScaffoldGraph&page=metaScaffoldGraph";
        $url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
        if ( $seq_length < $pageSize ) {
            my $range = "1\.\.$seq_length";
            my $xurl  = $url . "&start_coord=1&end_coord=$seq_length";
            $r .= $range . $sd . alink( $xurl, $range ) . "\t";

        } else {
            my $tmp;
            my $last = 1;
            for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
                my $curr  = $i;
                my $range = "$last\.\.$curr";
                my $xurl  = $url . "&start_coord=$last&end_coord=$curr";
                $xurl .= "&seq_length=$seq_length";

                $tmp .= alink( $xurl, $range ) . "<br/> ";
                $last = $curr + 1;
            }
            if ( $last < $seq_length ) {
                my $range = "$last\.\.$seq_length";
                my $xurl  = $url . "&start_coord=$last&end_coord=$seq_length";

                $tmp .= alink( $xurl, $range ) . " ";
            }
            $r .= $sd . $tmp . "\t";
        }

        $it->addRow($r);

        $count++;
        if ( ( $count % 10 ) == 0 ) {
            print ".";
        }
        if ( ( $count % 1800 ) == 0 ) {
            print "<br/>\n";
        }

        if ( $count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }    # end while

    printEndWorkingDiv();

    WebUtil::printScaffoldCartFooter() if ( $scaffold_cart && $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printScaffoldCartFooter() if $scaffold_cart;

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveScaffoldToWorkspace($select_id_name);
    }

    if ($trunc) {
        printStatusLine( "Results limited to $maxGeneListResults scaffolds.", 2 );
    } else {
        printStatusLine( "$count Loaded.", 2 );
    }

    print end_form();
    return;
}

############################################################################
# printScaffoldsByCount - to be invoked by the GeneCount or LengthCount sub
############################################################################
sub _printScaffoldsByCount {
    my ( $dbh, $subtitle, $scaffold_clause, $scaffold2Bin_href, $max_scaffold_count, $scaffold_oids_href ) = @_;
    my $trunc     = 0;
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    checkTaxonPerm( $dbh, $taxon_oid );
    print "<h2>User Selectable Coordinates</h2>\n";
    print "<p>\n";
    print "$subtitle\n";
    print "</p>\n";

    my $it = new InnerTable( 1, "scaffold$$", "scaffold", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    if ($scaffold_cart) {
        $it->addColSpec( "Select" );
    }
    $it->addColSpec( "Scaffold",                 "asc",  "left" );
    $it->addColSpec( "Sequence Length<br/>(bp)", "desc", "right" );
    $it->addColSpec( "GC Content",               "desc", "right" );
    $it->addColSpec( "Type",                     "asc",  "left" );
    $it->addColSpec( "Topology",                 "asc",  "left" );
    $it->addColSpec( "Read Depth",               "desc", "right" )
      if $include_metagenomes;
    $it->addColSpec( "Gene Count", "desc", "right" );
    $it->addColSpec( "Coordinate Range" );

    my @scaffoldRecs;

    my $sql = qq{
        select distinct s.scaffold_name, ss.seq_length, ss.count_total_gene,
        ss.gc_percent, s.read_depth, s.scaffold_oid, tx.taxon_display_name,
        s.mol_type, s.mol_topology
        from scaffold s,  scaffold_stats ss, taxon tx
        where s.taxon = ?
        and s.taxon = ss.taxon
        and s.scaffold_oid = ss.scaffold_oid
        and s.taxon = tx.taxon_oid
        $scaffold_clause
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
            my $url   = "$main_cgi?section=MetaScaffoldGraph&page=metaScaffoldGraph";
            $url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
            $url .= "&start_coord=1&end_coord=$seq_length";
            $r   .= $range . $sd . alink( $url, $range ) . "\t";

        } else {
            my $tmp;
            my $last = 1;
            for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
                my $curr  = $i;
                my $range = "$last\.\.$curr";
                my $url   = "$main_cgi?section=MetaScaffoldGraph&page=metaScaffoldGraph";
                $url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
                $url .= "&start_coord=$last&end_coord=$curr";
                $url .= "&seq_length=$seq_length";

                $tmp .= alink( $url, $range ) . "<br/> ";
                $last = $curr + 1;
            }
            if ( $last < $seq_length ) {
                my $range = "$last\.\.$seq_length";
                my $url   = "$main_cgi?section=MetaScaffoldGraph&page=metaScaffoldGraph";
                $url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
                $url .= "&start_coord=$last&end_coord=$seq_length";

                $tmp .= alink( $url, $range ) . " ";
            }
            $r .= $sd . $tmp . "\t";
        }

        $it->addRow($r);
    }

    WebUtil::printScaffoldCartFooter() if $scaffold_cart;
    $it->printOuterTable(1);
    WebUtil::printScaffoldCartFooter() if ( $scaffold_cart && $count > 10 );

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
        printStatusLine( "Limited to $maxGeneListResults scaffolds.", 2 );
    } else {
        printStatusLine( "$count Loaded.", 2 );
    }
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
    my $sql = qq{
       select count(*)
       from dt_taxon_bbh_cluster tc
       where tc.taxon_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    if ( $cnt == 0 ) {
        my $sql = qq{
           select distinct g.gene_oid
           from gene_orthologs go, gene g
           where go.gene_oid = g.gene_oid
           and g.taxon = $taxon_oid
           and g.obsolete_flag = 'No'
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
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Cluster ID",   "asc",  "right" );
    $it->addColSpec( "Cluster Name", "asc",    "left" );
    $it->addColSpec( "Gene Count",   "desc", "right" );

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
    my $rclause = urClause("g.taxon");
    my $sql     = qq{
       select distinct g.gene_oid
       from bbh_cluster_member_genes bbhg, gene g
       where bbhg.cluster_id = ?
       and bbhg.member_genes = g.gene_oid
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       $rclause
       order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome ID",           "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left" );

    print "<p>\n";
    my @gene_oids;
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
    my $sql = qq{
       select count( distinct gic.gene_oid )
       from gene g, gene_img_clusters gic
       where g.taxon = ?
       and g.gene_oid = gic.gene_oid
       and g.obsolete_flag = 'No'
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
       group by ic.cluster_id, ic.cluster_name
       having count( distinct gic.gene_oid ) > 1
       order by ic.cluster_id, ic.cluster_name
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
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Cluster ID",   "asc",  "right" );
    $it->addColSpec( "Cluster Name", "asc",    "left" );
    $it->addColSpec( "Gene Count",   "desc", "right" );

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
    my $rclause = urClause("g.taxon");
    my $sql     = qq{
       select distinct g.gene_oid
       from gene_img_clusters gic, gene g
       where gic.cluster_id = ?
       and gic.gene_oid = g.gene_oid
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and g.taxon = ?
       $rclause
       order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id, $taxon_oid );

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome ID",           "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left" );

    print "<p>\n";
    my @gene_oids;
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
#    $it->addColSpec( "Select" );
#    $it->addColSpec( "Gene ID",     "asc", "right" );
#    $it->addColSpec( "Locus Tag", "asc", "left" );
#    $it->addColSpec( "Gene Product Name", "asc",   "left" );
#    $it->addColSpec( "Genome ID",   "asc", "right" );
#    $it->addColSpec( "Genome Name", "asc",   "left" );
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
    #    $it->addColSpec( "Select" );
    #    $it->addColSpec( "Gene ID",     "asc", "right" );
    #    $it->addColSpec( "Locus Tag", "asc", "left" );
    #    $it->addColSpec( "Gene Product Name", "asc",   "left" );
    #    $it->addColSpec( "Genome ID", "asc",   "right" );
    #    $it->addColSpec( "Genome Name", "asc",   "left" );
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
#    $it->addColSpec( "Select" );
#    $it->addColSpec( "Gene ID",     "asc", "right" );
#    $it->addColSpec( "Locus Tag", "asc", "left" );
#    $it->addColSpec( "Gene Product Name", "asc",   "left" );
#    $it->addColSpec( "Genome ID",   "asc", "right" );
#    $it->addColSpec( "Genome Name", "asc",   "left" );
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
    my $sql = qq{
       select
          pg.group_oid, g.locus_tag, g.gene_display_name, g.gene_oid
       from paralog_group pg, paralog_group_genes pgp, gene g
       where pg.taxon = ?
       and g.taxon = ?
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and pg.group_oid = pgp.group_oid
       and pgp.genes = g.gene_oid
       order by pg.group_oid, g.gene_display_name, g.gene_oid
    };
    my @binds = ( $taxon_oid, $taxon_oid );
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $old_group_oid;
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    printGeneCartFooter();
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

    my $dbh = dbLogin();
    my %clusterHasCogs;
    if ( $img_lite && $include_metagenomes ) {
        my $sql = qq{
           select pg.group_oid
           from paralog_group pg, paralog_group_genes pgg,
               gene_cog_groups gcg
           where pg.group_oid = pgg.group_oid
           and pg.taxon = ?
           and pgg.genes = gcg.gene_oid
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
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Cluster ID",   "asc",  "right" );
    $it->addColSpec( "Cluster Name", "asc",    "left" );
    $it->addColSpec( "Gene Count",   "desc", "right" );

    # Added yes/no column per Natalia's request for IMG 3.3 +BSJ 10/15/10
    $it->addColSpec( "Has COG Hits", "desc", "center", "", "", "wrap" )
      if $img_lite && $include_metagenomes;

    my @recs2 = reverse( sort(@recs) );
    for my $r (@recs2) {
        my ( $gene_count, $cluster_id, $cluster_name ) = split( /\t/, $r );
        my $gene_count2 = sprintf( "%d", $gene_count );
        $count++;
        my $url = "$section_cgi&page=paralogClusterGeneList" . "&cluster_id=$cluster_id";

        my $r;
        $r .= $cluster_id . $sd . $cluster_id . "\t";
        $r .= $cluster_name . $sd . escHtml($cluster_name) . "\t";
        $r .= $gene_count2 . $sd . alink( $url, $gene_count2 ) . "\t";

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
# printUniqueGenes - Show unique genes as all genes minus orthologs
#   and parlogs.  (Not used.)
############################################################################
sub printUniqueGenes {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    webLog "Get queries " . currDateTime() . "\n" if $verbose >= 1;

    ## Paralogs
    my $sql_paralog = qq{
       select distinct g.gene_oid
       from gene_paralogs gp, gene g
       where g.gene_oid = gp.gene_oid
       and g.taxon = ?
       and g.obsolete_flag = 'No'
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

    printGeneCartFooter();
    print "<p>\n";

    ## Ortholog
    my $count_o = 0;
    my $sql     = qq{
       select distinct g.gene_oid
       from gene_orthologs go, gene g
       where go.gene_oid = g.gene_oid
       and g.taxon = ?
       and g.obsolete_flag = 'No'
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
    my $data_type   = param("data_type");

    printMainForm();
    print hiddenVar( "taxon_oid",   $taxon_oid );
    print hiddenVar( "locus_type",  $locus_type );
    print hiddenVar( "data_type",   $data_type );
    print hiddenVar( "gene_symbol", $gene_symbol );

    printStatusLine( "Loading ...", 1 );

    # check taxon permission
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    $taxon_oid = sanitizeInt($taxon_oid);

    my $data_type_text = getDatatypeText($data_type);
    if ( $gene_symbol || $locus_type ) {
        print "<h1>$gene_symbol $locus_type Genes $data_type_text</h1>\n";
    } else {
        print "<h1>RNA Genes $data_type_text</h1>\n";
    }

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my $count         = 0;
    my $trnaCount     = 0;
    my $rrnaCount     = 0;
    my $rrna5SCount   = 0;
    my $rrna16SCount  = 0;
    my $rrna18SCount  = 0;
    my $rrna23SCount  = 0;
    my $rrna28SCount  = 0;
    my $otherRnaCount = 0;

    my $trunc              = 0;
    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $old_locus_type;
    my $old_gene_symbol;

    $include_metagenomes = 1;

    my $it = new InnerTable( 1, "RNAGenes$$", "RNAGenes", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Locus Type",        "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Gene Symbol",       "asc", "left" );
    $it->addColSpec( "Coordinates" );
    $it->addColSpec( "Length", "desc", "right" );

    if ($include_metagenomes) {
        $it->addColSpec( "Scaffold ID",       "asc",  "left" );
        $it->addColSpec( "Scaffold Length",     "desc", "right" );
        $it->addColSpec( "Scaffold GC Content", "desc", "right" );
        $it->addColSpec( "Scaffold Read Depth", "desc", "right" );
    }

    my $select_id_name = "gene_oid";

    my @rna_type = ();
    if ( $locus_type eq 'tRNA' ) {
        @rna_type = ('tRNA');
    } elsif ( $locus_type eq 'rRNA' ) {
        @rna_type = ('rRNA');
    } else {
        @rna_type = ( 'tRNA', 'rRNA' );
    }

    printStartWorkingDiv();

    my %scaffold_info;
    my %scaffold_depth;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {

        #my $total_gene_cnt = MetaUtil::getGenomeStats($taxon_oid, $t2, "Genes total number");
        #if ( ! $total_gene_cnt ) {
        #    $total_gene_cnt = MetaUtil::getGenomeStats($taxon_oid, $t2, "Protein coding genes") +
        #        MetaUtil::getGenomeStats($taxon_oid, $t2, "rRNA genes") +
        #        MetaUtil::getGenomeStats($taxon_oid, $t2, "tRNA genes");
        #}

        for my $t3 (@rna_type) {
            my @names = ();
            if ( $t3 eq 'tRNA' ) {
                @names = ('tRNA');
            } elsif ( $t3 eq 'rRNA' ) {
                if ($gene_symbol) {

                    # 5S, 16S, 23S etc
                    my $name2 = "rRNA_" . $gene_symbol;
                    @names = ($name2);
                } else {

                    # all rRNAs
                    @names = ( 'rRNA_5S', 'rRNA_16S', 'rRNA_18S', 'rRNA_23S', 'rRNA_28S', 'rRNA_other' );
                }
            }

            my @rows;
            for my $n2 (@names) {
                print "Retrieving $n2 data ...<br/>\n";

                my $sdb_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $n2 . ".sdb";
                if ( -e $sdb_name ) {
                    my $dbh3 = WebUtil::sdbLogin($sdb_name)
                      or next;

                    my $sql3 =
                        "select gene_oid, locus_type, locus_tag, product_name, "
                      . "start_coord, end_coord, strand, scaffold_oid "
                      . "from gene ";
                    my $sth = $dbh3->prepare($sql3);
                    $sth->execute();
                    my $cnt = 0;
                    for ( ; ; ) {
                        my ( $id3, @rest ) = $sth->fetchrow_array();
                        last if !$id3;

                        my $line = $id3 . "\t" . join( "\t", @rest );
                        push @rows, ($line);
                    }
                    $sth->finish();
                    $dbh3->disconnect();
                    next;
                }

                my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $n2 . ".zip";
                if ( !-e $file ) {

                    # no data file
                    next;
                }

                my $zip = Archive::Zip->new();
                $zip->read($file);

                my @members = $zip->members();

                for my $m (@members) {
                    my $line = $m->contents();
                    chomp($line);

                    push @rows, ($line);
                }
            }    # end for n2

            for my $line (@rows) {
                my ( $gene_oid, $locus_type, $locus_tag, $gene_prod_name, $start_coord, $end_coord, $strand,
                    $scaffold_oid )
                  = split( /\t/, $line );

                my $len = $end_coord - $start_coord + 1;
                $count++;
                if ( $count >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }

                my $workspace_id = "$taxon_oid $t2 $gene_oid";
                my $row          = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
                my $url          =
                    "$main_cgi?section=MetaGeneDetail"
                  . "&page=metaGeneDetail&data_type=$t2"
                  . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid"
                  . "&locus_type=$t3";

                $row .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                $row .= $t3 . $sd . escHtml($t3) . "\t";

                $row .= $gene_prod_name . $sd . escHtml($gene_prod_name) . "\t";

                my $gene_symbol = "";
                for my $s2 ( '5S', '16S', '18S', '23S', '28S' ) {
                    if ( $gene_prod_name =~ /$s2/ ) {
                        $gene_symbol = $s2;
                    }
                }
                $row .= $gene_symbol . $sd . escHtml($gene_symbol) . "\t";

                if ( $end_coord == 0 ) {
                    $row .= " " . $sd . nbsp(1) . "\t";
                } else {
                    $row .= "$start_coord..$end_coord($strand)" . $sd . "$start_coord..$end_coord($strand)\t";
                }

                my $dna_seq_length = $len;
                $row .= $dna_seq_length . $sd . "${dna_seq_length}bp\t";

                if ($include_metagenomes) {
                    $row .= $scaffold_oid . $sd . $scaffold_oid . "\t";

                    my $sc_id = "$taxon_oid $data_type $scaffold_oid";
                    my $scf_seq_length = "";
                    my $scf_gc_percent = "";
                    my $scf_g_cnt      = 0;
                    if ( $scaffold_info{$sc_id} ) {
                        ( $scf_seq_length, $scf_gc_percent, $scf_g_cnt ) =
                          split( /\t/, $scaffold_info{$sc_id} );
                    } else {
                        if ( $t2 eq 'assembled' ) {
                            ( $scf_seq_length, $scf_gc_percent, $scf_g_cnt ) =
                              MetaUtil::getScaffoldStats( $taxon_oid, $t2, $scaffold_oid );
                        } else {

                            # unassembled
                            $scf_seq_length = $dna_seq_length;
                            $scf_gc_percent = "-";
                        }

                        $scaffold_info{$sc_id} = "$scf_seq_length\t$scf_gc_percent\t$scf_g_cnt";
                    }

                    my $scf_read_depth = $scaffold_depth{$sc_id};
                    if ( ! $scaffold_depth{$sc_id} ) {
                        $scf_read_depth = MetaUtil::getScaffoldDepth( $taxon_oid, $t2, $scaffold_oid );
                        $scaffold_depth{$sc_id} = $scf_read_depth;
                    }

                    $row .= $scf_seq_length . $sd . "${scf_seq_length}bp\t";
                    $row .= $scf_gc_percent . $sd . $scf_gc_percent . "\t";
                    $row .= $scf_read_depth . $sd . $scf_read_depth . "\t";
                }
                $rrnaCount++ if ( $t3 =~ /rRNA/ );
                $rrna5SCount++  if ( $gene_symbol eq "5S" );
                $rrna16SCount++ if ( $gene_symbol eq "16S" );
                $rrna18SCount++ if ( $gene_symbol eq "18S" );
                $rrna23SCount++ if ( $gene_symbol eq "23S" );
                $rrna28SCount++ if ( $gene_symbol eq "28S" );
                $trnaCount++ if ( $t3 =~ /tRNA/ );
                $otherRnaCount++ if ( $t3 !~ /rRNA/ && $t3 !~ /tRNA/ );
                $old_locus_type  = $locus_type;
                $old_gene_symbol = $gene_symbol;
                $it->addRow($row);
            }    # end for my line
        }    # end for my t3
    }    # end for my t2

    printEndWorkingDiv();

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        my $totalRnaCount = $rrnaCount + $trnaCount + $otherRnaCount;
        printStatusLine( "$rrnaCount rRNA's, $trnaCount tRNA's, " . "$otherRnaCount ncRNA's retrieved.", 2 );
    }

    my $unknownRrnaCount = $rrnaCount - $rrna5SCount - $rrna16SCount - $rrna18SCount - $rrna23SCount - $rrna28SCount;

    if ($count) {
        WebUtil::printGeneCartFooter() if $count > 10;
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        ## save to workspace
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonRnaGenes($select_id_name);
    } else {
        printMessage("There are no RNA genes.");
    }

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
        $type,               $taxon_oid,         $total,                $sampleIds_aref,
        $sampleNames_aref,   $columns_aref,      $st,                   $chart,
        $sampleCogHash_href, $categoryHash_href, $chartcategories_aref, $functioncodes_aref
      )
      = @_;

    print "<div id='sampleView' style='display: block;'>";
    print "<input type='button' class='medbutton' name='view'"
      . " value='Hide COGs in Protein Samples'"
      . " onclick='showView(\"slim\")' />";

    my $it = new InnerTable( 1, "cogsamples$$", "cogsamples", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Sample ID",   "asc", "right" );
    $it->addColSpec( "Sample Name", "asc", "left" );
    foreach my $col (@$columns_aref) {
        my $index = 0;
        my $i     = 0;
        my $found = 0;
        my $tmp   = $col;
        if ( $col =~ /percentage$/ ) {
            $tmp =~ s/ percentage//;

            #$it->addColSpec( $col, "desc", "right" );
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
            my $url = "$section_cgi&page=cogGeneList&cat=cat";
            $url .= "&function_code=$functioncodes_aref->[$i]";
            $url .= "&taxon_oid=$taxon_oid";
            my $colName;
            if ( $st == 0 ) {
                my $imageref =
                    "<img alt='"
                  . escHtml($col)
                  . "' src='$tmp_url/"
                  . $chart->FILE_PREFIX
                  . "-color-"
                  . $i
                  . ".png' border=0>";
                $colName = $imageref;    # alink($url, $imageref, "", 1);
                $colName .= "&nbsp;&nbsp;";
                if ( $col =~ /percentage$/ ) {
                    $colName .= "%";
                }
            }
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
# printCogCategories - Show COG categories and count of genes.
############################################################################
sub printCogCategories {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    my $url2 = "$section_cgi&page=cateCogList&taxon_oid=$taxon_oid" . "&data_type=$data_type";

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

    my $total_genome_gene_count =
    MetaUtil::getGenomeStats($taxon_oid, $data_type, "Protein coding genes") +
    MetaUtil::getGenomeStats($taxon_oid, $data_type, "RNA genes");
    my $total_gene_count =
    MetaUtil::getGenomeStats($taxon_oid, $data_type, "with COG");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $data_type_text = getDatatypeText($data_type);
    print "<h1>COG Categories $data_type_text</h1>\n";

    # get taxon name
    my $sql = qq{
        select taxon_display_name, is_pangenome
        from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_name, $is_pangenome ) = $cur->fetchrow();
    $cur->finish();
    $taxon_name = HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    my $url = "$section_cgi&page=cogs&taxon_oid=$taxon_oid" . "&data_type=$data_type";
    print alink( $url, "View as COG List" );
    print "</p>\n";

    use TabHTML;
    TabHTML::printTabAPILinks( "cogcatTab", 1 );
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("cogcatTab");
        </script>
    };

    my @tabIndex = ( "#cogcattab1",    "#cogcattab2" );
    my @tabNames = ( "COG Categories", "Statistics by COG categories" );

    #if ( lc($is_pangenome) eq "yes" ) {
    #    push @tabIndex, "#cogcattab3";
    #    push @tabNames, "Pangenome Composition";
    #}
    TabHTML::printTabDiv( "cogcatTab", \@tabIndex, \@tabNames );

    print "<div id='cogcattab1'>";
    printStatusLine( "Loading ...", 1 );

    $taxon_oid = sanitizeInt($taxon_oid);
    my %code2cnt = MetaUtil::getTaxonCate( $taxon_oid, $data_type, 'cog' );

    $sql = qq{
        select cf.function_code, cf.definition
        from cog_function cf
    order by 1
    };

    my $cur   = execSql( $dbh, $sql, $verbose );
    my $count = 0;

    my %categoryHash;
    my $gene_count_total = 0;
    for ( ; ; ) {
        my ( $function_code, $definition ) = $cur->fetchrow();
        last if !$definition;
        last if !$function_code;

        my $gene_count = $code2cnt{$function_code};
        next if ( !$gene_count );

        push @chartcategories, "$definition";
        push @functioncodes,   "$function_code";
        push @chartdata,       $gene_count;
        $categoryHash{$definition} = $gene_count;
        $gene_count_total += $gene_count;

        $count++;
    }
    $cur->finish();

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@functioncodes );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $proteindata = 0;
    my %sampleCogHash;
    my @sampleIds;
    my @sampleNames;
    my $genes_with_peptides = 0;    # same number as $proteindata ???
    if ( $proteindata > 0 ) {
        my $sql = qq{
        select distinct dt.gene_oid, count(dt.peptide_oid)
        from dt_img_gene_prot_pep_sample dt
        where dt.taxon = ?
        group by dt.gene_oid
        order by dt.gene_oid
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
          from gene g, gene_cog_groups gcg, cog c,
               cog_functions cfs, cog_function cf,
               dt_img_gene_prot_pep_sample dt
         where dt.sample_oid = ?
           and dt.gene_oid = g.gene_oid
           and g.taxon = ?
           and g.locus_type = 'CDS'
           and g.obsolete_flag = 'No'
           and g.gene_oid = gcg.gene_oid
           and gcg.cog = c.cog_id
           and c.cog_id = cfs.cog_id
           and cfs.functions = cf.function_code
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

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    # Cog categories table next to pie chart:
    my $it = new InnerTable( 1, "cogcategories$$", "cogcategories", 0 );
    my $sd = $it->getSdDelim();
    $it->hideAll();
    $it->addColSpec( "COG Categories",                     "asc",  "left" );
    $it->addColSpec( "Gene Count",                         "char desc", "right" );
    $it->addColSpec( "% of Total<br/>($gene_count_total)", "desc",      "right" );

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;
        my $url = "$section_cgi&page=cateCogList&data_type=$data_type";
        $url .= "&function_code=$functioncodes[$idx]";
        $url .= "&taxon_oid=$taxon_oid";

        my $row;
        if ( $st == 0 ) {
            my $imageref = "<img src='$tmp_url/" . $chart->FILE_PREFIX . "-color-" . $idx . ".png' border=0>";
            $row = escHtml($category1) . $sd . alink( $url, $imageref, "", 1 );
            $row .= "&nbsp;&nbsp;";
        }

        $row .= escHtml($category1) . "\t";
        $row .= $chartdata[$idx] . $sd . alink( $url, $chartdata[$idx] ) . "\t";
        my $percent = 0;
        if ( $gene_count_total > 0 ) {
            $percent = 100 * $chartdata[$idx] / $gene_count_total;
        }
        $percent = sprintf( "%.2f", $percent );
        $row .= $percent . "\t";
        $it->addRow($row);
        $idx++;
    }

    my $nocogcount    = $total_genome_gene_count - $total_gene_count;
    my $nocogcount_pc = 0;
    if ( $total_genome_gene_count > 0 ) {
        $nocogcount_pc = 100 * $nocogcount / $total_genome_gene_count;
        $nocogcount_pc = sprintf( "%.2f", $nocogcount_pc );
    }
    my $row = "xNot in COG" . $sd . "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Not in COGs\t";
    $row .= $nocogcount . "\t";
    $row .= $nocogcount_pc;
    $it->addRow($row);

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    print "<td valign=top align=left>\n";
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "printCogCategories", 1 );
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
    printStatusLine( "$count COG retrieved.", 2 );
    print "</div>";    # end cogcattab1

    print "<div id='cogcattab2'>";
    my $sql = qq{
        select t.seq_status, t.domain,
               t.phylum, t.ir_class, t.ir_order, t.family, t.genus
        from taxon t
        where t.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    my $txTableName = "taxonCogCategories";
    print start_form(
        -id     => $txTableName . "_frm",
        -name   => "mainForm",
        -action => "$main_cgi"
    );

    my @columns = param("outputCol");
    if ( $#columns < 0 ) {

        # add default columns
        push( @columns, "Total COG Genes" );
    }

    print "<h2>Statistics by COG Categories</h2>\n";
    print "<p>";
    print "You may add or remove columns from the statistics table " . "using the configuration table below.";
    print "</p>";

    print "<div id='statView' style='display: block;'>\n";
    if ( $proteindata > 0 ) {
        print "<input type='button' class='medbutton' name='view'"
          . " value='Show COGs in Protein Samples'"
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
        } elsif ( $cat eq "Total COG Genes" ) {
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

    #if ( $proteindata > 0 ) {
    #printStatsPerSample('cog', $taxon_oid, $genes_with_peptides,
    #            \@sampleIds, \@sampleNames, \@columns,
    #            $st, $chart, \%sampleCogHash, \%categoryHash,
    #            \@chartcategories, \@functioncodes);
    #}

    # add some initial categories to be selected
    my @category_list;
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total COG Genes" );
    for my $category1 (@chartcategories) {
        last if !$category1;
        push( @category_list, $category1 );
        push( @category_list, "$category1 percentage" );
    }

    print hiddenVar( "data_type", $data_type );

    print "<h2>Configuration</h2>";
    printConfigTable( \@category_list, \@columns, $taxon_oid, "cogs", $blockDatatableCss );
    print end_form();
    print "</div>";    # end cogcattab2

    #print "<div id='cogcattab3'>";
    #if ( lc($is_pangenome) eq "yes" ) {
    #   TaxonList::printPangenomeTable($taxon_oid);
    #}
    #print "</div>"; # end cogcattab3
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
    my ( $dbh, $taxon_oid ) = @_;
    my $sql = qq{
        select total_gene_count, genes_in_cog
        from taxon_stats
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $gene_count, $cog_gcount ) = $cur->fetchrow();
    $cur->finish();

    my $tmp = $gene_count - $cog_gcount;
    return ( $tmp, $gene_count );
}

############################################################################
# printTaxonCog - Show cog list and count of genes per cog
############################################################################
sub printTaxonCog {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    printMainForm();
    my $data_type_text = getDatatypeText($data_type);
    print "<h1>Characterized COGs $data_type_text</h1>\n";

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my %cog_names;
    my $total_cogs = 0;
    my $sql        = qq{
        select c.cog_id, c.cog_name
        from cog c, cog_functions cf
        where c.cog_id = cf.cog_id
        order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;

        $cog_names{$cog_id} = $cog_name;
        $total_cogs++;
    }
    $cur->finish();

    #$dbh->disconnect();

    $taxon_oid = sanitizeInt($taxon_oid);
    my %a_cog_count;
    my %u_cog_count;
    my $total_gene_count = 0;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/cog_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $cog2, $cnt ) = split( /\t/, $line );

                if ( $t2 eq 'assembled' ) {
                    $a_cog_count{$cog2} = $cnt;
                } else {
                    $u_cog_count{$cog2} = $cnt;
                }

                $total_gene_count += $cnt;
            }
            close $fh;
        }
    }

    print "<p>\n";
    my $url = "$section_cgi&page=cogs&cat=cat&taxon_oid=$taxon_oid" . "&data_type=$data_type";
    print alink( $url, "View as COG Categories" );
    print "</p>\n";

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "COG ID",   "asc", "left" );
    $it->addColSpec( "COG Name", "asc", "left" );

    if ( $data_type eq 'both' ) {
        $it->addColSpec( "Gene Count<br/> (assembled)",   "asc", "right" );
        $it->addColSpec( "Gene Count<br/> (unassembled)", "asc", "right" );
        $it->addColSpec( "Gene Count<br/> (both)",        "asc", "right" );
    } else {
        $it->addColSpec( "Gene Count ($data_type)", "asc", "right" );
    }

    my $select_id_name = "func_id";

    my @keys  = sort ( keys %cog_names );
    my $c_cnt = 0;
    for my $k (@keys) {
        if ( !$a_cog_count{$k} && !$u_cog_count{$k} ) {

            # skip zero count
            next;
        }

        $c_cnt++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$k' /> \t";
        $r .= $k . $sd . $k . "\t";
        $r .= $cog_names{$k} . $sd . $cog_names{$k} . "\t";

        # count
        if ( $data_type eq 'both' ) {
            my $url2      = "$section_cgi&page=cogGeneList&taxon_oid=$taxon_oid" . "&cog_id=$k";
            my $total_cnt = 0;
            if ( $a_cog_count{$k} ) {
                my $cnt = $a_cog_count{$k};
                $r .= $cnt . $sd . alink( $url2 . "&data_type=assembled", $cnt ) . "\t";
                $total_cnt += $cnt;
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
            if ( $u_cog_count{$k} ) {
                my $cnt = $u_cog_count{$k};
                $r .= $cnt . $sd . alink( $url2 . "&data_type=unassembled", $cnt ) . "\t";
                $total_cnt += $cnt;
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
            if ($total_cnt) {
                $r .= $total_cnt . $sd . alink( $url2 . "&data_type=both", $total_cnt ) . "\t";
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
        } else {
            my $cnt = $a_cog_count{$k};
            if ( $data_type eq 'unassembled' ) {
                $cnt = $u_cog_count{$k};
            }
            my $url2 = "$section_cgi&page=cogGeneList&taxon_oid=$taxon_oid" . "&data_type=$data_type&cog_id=$k";
            if ($cnt) {
                $r .= $cnt . $sd . alink( $url2, $cnt ) . "\t";
            } else {
                $r .= $cnt . $sd . $cnt . "\t";
            }
        }

        $it->addRow($r);
    }

    my $name = "_section_${section}_cogGeneList";
    if ( $c_cnt > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $c_cnt > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( $c_cnt . " cog(s) retrieved.", 2 );

    print end_form();
}

############################################################################
# printCogGeneListCat - Show genes under one COG category
############################################################################
sub printCogGeneListCat {
    my $taxon_oid     = param("taxon_oid");
    my $function_code = param("function_code");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    print "<h1>COG Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
        select definition
        from cog_function
        where function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
       select c.cog_name, c.cog_id, g.gene_oid, g.gene_display_name
       from gene_cog_groups gcg, cog c, cog_function cf,
        cog_functions cfs, gene g
       where gcg.cog = c.cog_id
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and gcg.gene_oid = g.gene_oid
       and g.taxon = ?
       and cfs.functions = cf.function_code
       and cfs.cog_id = c.cog_id
       and g.taxon = ?
       and cf.function_code = ?
       order by c.cog_name
    };
    my @binds = ( $taxon_oid, $taxon_oid, $function_code );

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $count = 0;
    my @gene_oids;
    my %done;

    printMainForm();
    print "<p>\n";
    print "(Only COGs associated with <i><u>" . escHtml($definition) . "</u></i> are shown with genes.)\n";
    print "</p>\n";

    WebUtil::printGeneCartFooter();
    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Name",    "asc", "left" );

    my $count = 0;
    my @recs;
    my %gene2Cog;
    my %geneCogDone;
    for ( ; ; ) {
        my ( $cog_name, $cog_id, $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$cog_name;
        last if !$gene_oid;
        my $rec = "$cog_name\t";
        $rec .= "$cog_id\t";
        $rec .= "$gene_oid\t";
        $rec .= "$gene_display_name";
        push( @recs, $rec );
        my $gcKey = "$gene_oid:$cog_id";
        $gene2Cog{$gene_oid} .= "$cog_id,"
          if !blankStr($cog_id) && !$geneCogDone{$gcKey};
        $geneCogDone{$gcKey} = 1;
    }
    $cur->finish();

    my %done;
    my $count = 0;
    for my $r (@recs) {
        my ( $cog_name, $cog_id, $gene_oid, $gene_display_name ) =
          split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' " . "  /> \t";
        my $url    = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        my $cgList = "";
        my $cog    = $gene2Cog{$gene_oid};
        chop $cog;
        $cgList = "( $cog )" if $cog ne "";

        $r .= $gene_oid . $sd . "<a href='" . $url . "'>  $gene_oid </a>" . "\t";

        my $tmpname;
        if ( $gene_display_name ne "" ) {
            $tmpname = escHtml("$gene_display_name $cgList") . $tmpname;
        }
        $r .= $tmpname . $sd . "\t";
        $it->addRow($r);
        $done{$gene_oid} = 1;
    }
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter() if $count > 10;

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# sanitizeCogId - Sanitize COG ID
############################################################################
sub sanitizeCogId {
    my ($s) = @_;
    if ( $s !~ /^COG[0-9]+$/ ) {
        webDie("sanitizeCogId: invalid integer '$s'\n");
    }
    $s =~ /(COG[0-9]+)/;
    $s = $1;
    return $s;
}

############################################################################
# sanitizeDataType
############################################################################
sub sanitizeDataType {
    my ($s) = @_;
    if ( $s !~ /^[a-zA-Z]+$/ ) {
        webDie("sanitizeDataType: invalid data type '$s'\n");
    }
    $s =~ /([a-zA-Z]+)/;
    $s = $1;
    return $s;
}

############################################################################
# printCogGeneList - Show genes under one COG.
############################################################################
sub printCogGeneList {
    my $taxon_oid   = param("taxon_oid");
    my $data_type   = param("data_type");
    my $xcopy       = param("xcopy");
    my $single_copy = param("single_copy");

    my @cog_ids = param("cog_id");
    if ( scalar(@cog_ids) <= 0 ) {
        @cog_ids = param("func_id");
    }
    if ( scalar(@cog_ids) == 0 ) {
        webError("No COG has been selected.");
    }

    printMainForm();

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );
    for my $func_id (@cog_ids) {
        print hiddenVar( "func_id", $func_id );
    }
    printStatusLine( "Loading ...", 1 );

    # get cog names
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my %cog_names;
    my %cog_seqlength;
    TaxonDetailUtil::fetchCogId2NameAndSeqLengthHash( $dbh, \@cog_ids, \%cog_names, \%cog_seqlength );

    print "<h1>COG Genes</h1>";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    for my $cog_id (@cog_ids) {
        my $funcName = $cog_names{$cog_id};
        print $cog_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    #$dbh->disconnect();

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $trunc = 0;

    my %gene_copies;
    $taxon_oid = sanitizeInt($taxon_oid);

    my $has_sdb = 1;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        if ( !MetaUtil::hasSdbGeneProductFile( $taxon_oid, $t2 ) ) {
            $has_sdb = 0;
        }
    }

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",    "asc", "left" );
    $it->addColSpec( "Assembled?", "asc", "left" );
    if ($has_sdb) {
        $it->addColSpec( "Gene Name", "asc", "left" );
    }
    if ( $xcopy eq 'est_copy' ) {
        $it->addColSpec( "Estimated Copies", "asc", "left" );
        if (   $data_type eq 'assembled'
            || $data_type eq 'both'
            || blankStr($data_type) )
        {
            MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled', \%gene_copies );
        }
    }
    if ( scalar @cog_ids > 1 ) {
        $it->addColSpec( "COG ID",   "asc", "left" );
        $it->addColSpec( "COG Name", "asc", "left" );
    }

    my $select_id_name = "gene_oid";

    my $line       = "";
    my $gene_count = 0;
    my %distinct_gene_h;

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** time1: " . currDateTime() . "\n";
    }

    printStartWorkingDiv("genesforcog");
    if ( $single_copy ne "" ) {
        print "<p>this may take time - please be patient.";
    }

    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        $t2 = sanitizeDataType($t2);

        my %h = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, "cog", \@cog_ids );

        if ( scalar( keys %h ) > 0 ) {
            for my $cog_id (@cog_ids) {
                print "<p>processing $cog_id ...\n";
                if ($trunc) {
                    last;
                }

                my @gene_list = split( /\t/, $h{$cog_id} );
              GENE: for my $gene_oid (@gene_list) {
                    ### check for single-copy criteria:
                    if ( $single_copy ne "" ) {
                        next if $t2 eq "unassembled";
                        next GENE
                          if ( !passesSingleCopyCriteria( $taxon_oid, $gene_oid, $t2, $cog_id, $cog_seqlength{$cog_id} ) );
                    }

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ( $distinct_gene_h{$workspace_id} ) {

                        # already included
                        next;
                    } else {
                        $distinct_gene_h{$workspace_id} = 1;
                    }

                    my $r;
                    $r .= $sd . "<input type='checkbox' " . "name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" . "&data_type=$t2&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";

                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }

                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }
                    if ( scalar @cog_ids > 1 ) {
                        $r .= $cog_id . $sd . $cog_id . "\t";
                        $r .= $cog_names{$cog_id} . $sd . $cog_names{$cog_id} . "\t";
                    }

                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
            }

            if ( tied(%h) ) {
                untie %h;
            }
        } else {
            my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/cog_genes.zip";
            if ( !( -e $file_name ) ) {
                next;
            }

            print "<p>reading cog-gene information ...\n";
            WebUtil::unsetEnvPath();

            for my $cog_id (@cog_ids) {
                print "<p>processing $cog_id ...\n";
                if ($trunc) {
                    last;
                }

                $cog_id = sanitizeCogId($cog_id);

                # my $total_gene_cnt = MetaUtil::getGenomeStats
                #    ($taxon_oid, $t2, "Genes total number");

                my $fh;
                $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name $cog_id ", 'CogGenes' );
                if ( !$fh ) {
                    next;
                }

                while ( $line = $fh->getline() ) {
                    chomp($line);
                    my ( $cog_id2, $gene_oid ) = split( /\t/, $line );
                    if ( !$gene_oid ) {
                        $gene_oid = $cog_id2;
                    }

                    ### check for single-copy criteria:
                    if ( $single_copy ne "" ) {
                        next if $t2 eq "unassembled";
                        next
                          if ( !passesSingleCopyCriteria( $taxon_oid, $gene_oid, $t2, $cog_id, $cog_seqlength{$cog_id} ) );
                    }

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ( $distinct_gene_h{$workspace_id} ) {

                        # already included
                        next;
                    } else {
                        $distinct_gene_h{$workspace_id} = 1;
                    }

                    my $r;
                    $r .= $sd . "<input type='checkbox' " . "name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" . "&data_type=$t2&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";

                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }

                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }

                    if ( scalar @cog_ids > 1 ) {
                        $r .= $cog_id . $sd . $cog_id . "\t";
                        $r .= $cog_names{$cog_id} . $sd . $cog_names{$cog_id} . "\t";
                    }
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
                close $fh;

            }    # end for cog_id

            WebUtil::resetEnvPath();
        }
    }    # end for t2

    printEndWorkingDiv("genesforcog");

    if ( $sid == 312 ) {
        print "<p>*** time2: " . currDateTime() . "<br/>\n";
    }

    if ( $gene_count == 0 ) {
        my $scopy = "";
        if ( $single_copy ne "" ) {
            $scopy = "single copy ";
        }
        print "<p><font color='red'>" . "Could not find $scopy" . "genes for cog @cog_ids </font></p>";
        print end_form();
        return;
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    MetaGeneTable::printMetaGeneTableSelect();

    WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) retrieved", 2 );
    }

    print end_form();
}

############################################################################
# checks if a gene passes the necessary criteria for single copy cog
############################################################################
sub passesSingleCopyCriteria {
    my ( $taxon_oid, $gene_oid, $t2, $cog_id, $cog_seqlength ) = @_;
    my $minAlignFrac        = 0.60;    # minimum alignment length on both seqs
    my $minPercIdent        = 30;      # minimum percent AA identity
    my $singleCopyTaxonFrac = 0.40;    # single copy COG fraction percentage
    my $consensusFrac       = 0.20;

    print ". ";
    return 0 if $cog_seqlength <= 0;

    my @geneInfo = MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $t2 );
    my $gene_name;
    my $start_coord;
    my $end_coord;
    if ( scalar(@geneInfo) > 0 && scalar(@geneInfo) <= 7 ) {
        $gene_name   = $geneInfo[2];
        $start_coord = $geneInfo[3];
        $end_coord   = $geneInfo[4];
    } elsif ( scalar(@geneInfo) > 7 ) {
        $gene_name   = $geneInfo[3];
        $start_coord = $geneInfo[4];
        $end_coord   = $geneInfo[5];
    }
    my $aa_seqlength = ( $end_coord - $start_coord + 1 ) / 3;
    return 0 if $aa_seqlength <= 0;

    print "* ";

    # Gene length needs to be += 20% of the COG length:
    return 0 if $aa_seqlength < ( ( 1.00 - $consensusFrac ) * $cog_seqlength );
    return 0 if $aa_seqlength > ( ( 1.00 + $consensusFrac ) * $cog_seqlength );

    print "x ";
    my ($cogs_ref, $sdbFileExist) = MetaUtil::getGeneCogInfo( $gene_oid, $taxon_oid, $t2 );
    my $returnval = "$gene_name\t$aa_seqlength\t";
    for my $line (@$cogs_ref) {
        my ( $gid2, $cog2, $perc_identity, $align_length, $q_start, $q_end, $s_start, $s_end, @other ) =
          split( /\t/, $line );
        next if ( $cog2 ne $cog_id );
        $returnval .= $line;

        # 30% or better (percent_identity) on query gene:
        # Alignment fraction >= 60% of query gene and COG length:
        return 0 if ( $perc_identity < $minPercIdent );
        return 0 if ( $s_end - $s_start + 1 ) / $cog_seqlength < $minAlignFrac;
        return 0 if ( $q_end - $q_start + 1 ) / $aa_seqlength < $minAlignFrac;
    }
    return $returnval;
}

############################################################################
# sanitizeGeneId2 - Sanitize to integer and _ for security purposes.
############################################################################
sub sanitizeGeneId2 {
    my ($s) = @_;
    if ( $s !~ /^[0-9\_]+$/ ) {
        webDie("sanitizeInt: invalid id '$s'\n");
    }
    $s =~ /([0-9\_]+)/;
    $s = $1;
    return $s;
}

############################################################################
# printCateCogList - print category COG list
############################################################################
sub printCateCogList {
    my $function_code = param("function_code");
    my $taxon_oid     = param("taxon_oid");
    my $data_type     = param("data_type");
    $taxon_oid = sanitizeInt($taxon_oid);

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select definition
        from cog_function
        where function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    print "<h1>COG Category: " . escapeHTML($definition) . "</h1>\n";
    my $data_type_text = getDatatypeText($data_type);
    print "<h2>COG List $data_type_text</h2>\n";

    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my %cog_names;
    my $total_cogs = 0;
    $sql = qq{
        select c.cog_id, c.cog_name
        from cog c, cog_functions cf
        where c.cog_id = cf.cog_id
        and cf.functions = ?
        order by 1
    };
    $cur = execSql( $dbh, $sql, $verbose, $function_code );
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;

        $cog_names{$cog_id} = $cog_name;
    }
    $cur->finish();

    #$dbh->disconnect();

    my %cog_counts;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/cog_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $cog2, $cnt ) = split( /\t/, $line );
                if ( $cog_names{$cog2} ) {

                    # included
                    if ( $cog_counts{$cog2} ) {
                        $cog_counts{$cog2} += $cnt;
                    } else {
                        $cog_counts{$cog2} = $cnt;
                    }
                }
            }
            close($fh);
        }
    }    # for my $t2

    my $it = new InnerTable( 1, "cateCog$$", "cateCog", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "COG ID",     "asc", "left" );
    $it->addColSpec( "COG Name",   "asc", "left" );
    $it->addColSpec( "Gene Count", "asc", "right" );

    my $select_id_name = "func_id";

    my $i = 0;
    for my $cog2 ( sort ( keys %cog_names ) ) {
        if ( !$cog_counts{$cog2} ) {

            # skip zero count
            next;
        }

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$cog2' /> \t";
        $r .= $cog2 . $sd . $cog2 . "\t";
        $r .= $cog_names{$cog2} . $sd . $cog_names{$cog2} . "\t";

        my $url2 = "$section_cgi&page=cogGeneList&taxon_oid=$taxon_oid" . "&data_type=$data_type&cog_id=$cog2";
        $r .= $cog_counts{$cog2} . $sd . alink( $url2, $cog_counts{$cog2} ) . "\t";
        $it->addRow($r);
        $i++;

        $total_cogs++;
    }

    my $name = "_section_${section}_cogGeneList";
    if ( $total_cogs > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $total_cogs > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    print end_form();
    printStatusLine( "$total_cogs cog(s) retrieved.", 2 );
}

############################################################################
# printCatePfamList - print category Pfam list
############################################################################
sub printCatePfamList {
    my $function_code = param("function_code");
    my $taxon_oid     = param("taxon_oid");
    my $data_type     = param("data_type");

    $taxon_oid = sanitizeInt($taxon_oid);

    printMainForm();
    print hidden( 'taxon_oid', $taxon_oid );
    print hidden( 'data_type', $data_type );

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
    my $data_type_text = getDatatypeText($data_type);
    print "<h2>Pfam List $data_type_text</h2>\n";

    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

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

    #$dbh->disconnect();

    my %id_counts;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/pfam_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );

                if ( $id_names{$id} ) {

                    # included
                    if ( $id_counts{$id} ) {
                        $id_counts{$id} += $cnt;
                    } else {
                        $id_counts{$id} = $cnt;
                    }
                }
            }
            close($fh);
        }
    }    # end for my t2

    my $it = new InnerTable( 1, "catePfam$$", "catePfam", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Pfam ID",    "asc", "left" );
    $it->addColSpec( "Pfam Name",  "asc", "left" );
    $it->addColSpec( "Gene Count", "asc", "left" );

    my $select_id_name = "func_id";

    my $count = 0;
    for my $id ( sort ( keys %id_names ) ) {
        next if ( !$id_counts{$id} );

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        $r .= $id . $sd . $id . "\t";
        $r .= $id_names{$id} . $sd . $id_names{$id} . "\t";
        my $url2 = "$section_cgi&page=pfamGeneList&func_id=$id";
        $url2 .= "&taxon_oid=$taxon_oid&data_type=$data_type";
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
# printCateTigrfamList - print category TIGRfam list
############################################################################
sub printCateTigrfamList {
    my $role      = param("role");
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    $taxon_oid = sanitizeInt($taxon_oid);

    printMainForm();
    print hidden( 'taxon_oid', $taxon_oid );
    print hidden( 'data_type', $data_type );

    printStatusLine( "Loading ...", 1 );

    print "<h1>TIGRfam Role: " . escapeHTML($role) . "</h1>\n";
    my $data_type_text = getDatatypeText($data_type);
    print "<h2>TIGRfam List $data_type_text</h2>\n";

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

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
        my ( $tigrfam_id, $tigrfam_name ) = $cur->fetchrow();
        last if !$tigrfam_id;
        $id_names{$tigrfam_id} = $tigrfam_name;
    }
    $cur->finish();

    #$dbh->disconnect();

    my %id_counts;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/tigr_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            next if ( !$fh );
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );

                if ( $id_names{$id} ) {

                    # included
                    if ( $id_counts{$id} ) {
                        $id_counts{$id} += $cnt;
                    } else {
                        $id_counts{$id} = $cnt;
                    }
                }
            }
            close $fh;
        }
    }    # end for t2

    my $it = new InnerTable( 1, "cateTigrfam$$", "cateTigrfam", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "TIGRfam ID",   "asc", "left" );
    $it->addColSpec( "TIGRfam Name", "asc", "left" );
    $it->addColSpec( "Gene Count",   "asc", "left" );

    my $select_id_name = "func_id";

    my $count = 0;
    for my $id ( sort ( keys %id_names ) ) {
        next if ( !$id_counts{$id} );

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        $r .= $id . $sd . $id . "\t";
        $r .= $id_names{$id} . $sd . $id_names{$id} . "\t";
        my $url2 = "$section_cgi&page=tigrfamGeneList&func_id=$id";
        $url2 .= "&taxon_oid=$taxon_oid&data_type=$data_type";
        $r .= $id_counts{$id} . $sd . alink( $url2, $id_counts{$id} ) . "\t";
        $it->addRow($r);

        $count++;
    }

    my $name = "_section_${section}_tigrfamGeneList";
    if ( $count > 10 ) {
        TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );
    }
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count tigrfam(s) retrieved.", 2 );

    print end_form();
}

############################################################################
# printTaxonEnzymes - Print enzymes list.
############################################################################
sub printTaxonEnzymes {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    $taxon_oid = sanitizeInt($taxon_oid);

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    printMainForm();
    my $data_type_text = getDatatypeText($data_type);
    print "<h1>Enzymes $data_type_text</h1>\n";

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    printStatusLine( "Loading ...", 1 );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my %ec_counts;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/ec_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            my $i = 0;
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $ec2, $cnt ) = split( /\t/, $line );

                if ( $ec_counts{$ec2} ) {
                    $ec_counts{$ec2} += $cnt;
                } else {
                    $ec_counts{$ec2} = $cnt;
                }
            }
            close $fh;
        }
    }

    my $sql = qq{
        select ec.ec_number, ec.enzyme_name
        from enzyme ec
        order by 1
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "enzyme$$", "enzyme", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Enzyme ID",   "asc",  "left" );
    $it->addColSpec( "Enzyme Name", "asc",  "left" );
    $it->addColSpec( "Gene Count",  "desc", "right" );

    my $select_id_name = "func_id";

    my $count       = 0;
    my $total_count = 0;
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;

        if ( !$ec_counts{$id} ) {
            next;
        }
        my $gene_count = $ec_counts{$id};
        $total_count += $gene_count;

        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        my $url = "$section_cgi&page=enzymeGeneList";
        $url .= "&ec_number=$id";
        $url .= "&taxon_oid=$taxon_oid&data_type=$data_type";

        $r .= $id . $sd . $id . "\t";
        $r .= $name . $sd . $name . "\t";
        $r .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";
        $it->addRow($r);
    }

    $cur->finish();

    #$dbh->disconnect();

    my $name = "_section_${section}_enzymeGeneList";
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" ) if $count > 10;
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count enzyme retrieved.", 2 );

    print end_form();
}

############################################################################
# sanitizeEcId - Sanitize EC ID
############################################################################
sub sanitizeEcId {
    my ($s) = @_;
    if ( $s !~ /^EC\:[0-9_\.\-]+$/ ) {
        webDie("sanitizeEcId: invalid EC number '$s'\n");
    }
    $s =~ /(EC\:[0-9_\.\-]+)/;
    $s = $1;
    return $s;
}

############################################################################
# printEnzymeGeneList - Show genes under one enzyme.
############################################################################
sub printEnzymeGeneList {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $xcopy     = param("xcopy");
    $taxon_oid = sanitizeInt($taxon_oid);

    my @ec_ids = param("ec_number");
    if ( scalar(@ec_ids) <= 0 ) {
        @ec_ids = param("func_id");
    }
    if ( scalar(@ec_ids) == 0 ) {
        webError("No enzyme has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    for my $id2 (@ec_ids) {
        print hiddenVar( "func_id", $id2 );
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my %funcId2Name;
    TaxonDetailUtil::fetchEnzymeId2NameHash( $dbh, \@ec_ids, \%funcId2Name );

    print "<h1>Enzyme (EC) Genes</h1>\n";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    for my $ec_id (@ec_ids) {
        my $funcName = $funcId2Name{$ec_id};
        print $ec_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    #$dbh->disconnect();

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $trunc = 0;

    my %gene_copies;

    my $has_sdb   = 1;
    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        if ( !MetaUtil::hasSdbGeneProductFile( $taxon_oid, $t2 ) ) {
            $has_sdb = 0;
        }
    }

    my $it = new InnerTable( 1, "ecGene$$", "ecGene", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",    "asc", "left" );
    $it->addColSpec( "Assembled?", "asc", "left" );
    if ($has_sdb) {
        $it->addColSpec( "Gene Name", "asc", "left" );
    }
    if ( $xcopy eq 'est_copy' ) {
        $it->addColSpec( "Estimated Copies", "asc", "left" );
        if (   $data_type eq 'assembled'
            || $data_type eq 'both'
            || blankStr($data_type) )
        {
            MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled', \%gene_copies );
        }
    }

    $it->addColSpec( "EC Number",   "asc", "left" );
    $it->addColSpec( "Enzyme Name", "asc", "left" );

    my $select_id_name = "gene_oid";
    my $line       = "";
    my $gene_count = 0;

    for my $ec_id (@ec_ids) {
        if ($trunc) {
            last;
        }

        my $ec_name = $funcId2Name{$ec_id};

        my ( $i1, $i2 ) = split( /\:/, $ec_id );
        $i2 = sanitizeEcId2($i2);

        for my $t2 (@type_list) {
            if ($trunc) {
                last;
            }

            my @ec_list2 = ($ec_id);
            my %h = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, "ec", \@ec_list2 );

            if ( scalar( keys %h ) > 0 ) {
                my @gene_list = split( /\t/, $h{$ec_id} );

                for my $gene_oid (@gene_list) {
                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&data_type=$t2" . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";
                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }
                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }
                    $r .= $ec_id . $sd . $ec_id . "\t";
                    $r .= $ec_name . $sd . $ec_name . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }

                if ( tied(%h) ) {
                    untie %h;
                }

            } else {
                my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/ec_genes.zip";
                if ( !( -e $file_name ) ) {
                    next;
                }

                WebUtil::unsetEnvPath();

                # $ec_id = sanitizeEcId($ec_id);
                my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name EC:$i2 ", 'EcGenes' );

                if ( !$fh ) {
                    next;
                }

                while ( $line = $fh->getline() ) {
                    chomp($line);
                    my ( $ec2, $gene_oid ) = split( /\t/, $line );
                    if ( !$gene_oid ) {
                        $gene_oid = $ec2;
                    }

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" . "&data_type=$data_type&gene_oid=$gene_oid";
                    $r   .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";
                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }
                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }
                    $r .= $ec_id . $sd . $ec_id . "\t";
                    $r .= $ec_name . $sd . $ec_name . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
                close $fh;
                WebUtil::resetEnvPath();
            }
        }
    }    # end for my $ec_id

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    MetaGeneTable::printMetaGeneTableSelect();

    WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) retrieved.", 2 );
    }

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

    if ($img_internal) {
        print "<p>\n";
        print alink( "$section_cgi&page=imgTerms&taxon_oid=$taxon_oid&cat=cat", "View as IMG Term Categories" );
        print "</p>\n";
    }

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #    my $sql = qq{
    #       select it.term_oid, it.term, count( distinct g.gene_oid )
    #       from gene g, gene_img_functions gif, dt_img_term_path dtp, img_term it
    #       where g.taxon = ?
    #       and g.locus_type = 'CDS'
    #       and g.gene_oid = gif.gene_oid
    #       and gif.function = dtp.map_term
    #       and it.term_oid = dtp.term_oid
    #       group by it.term, it.term_oid
    #       order by it.term, it.term_oid
    #    };
    my $sql = qq{
       select it.term_oid, it.term, count( distinct g.gene_oid )
       from gene g, gene_img_functions gif, img_term it
       where g.taxon = ?
       and g.locus_type = 'CDS'
       and g.gene_oid = gif.gene_oid
       and gif.function = it.term_oid
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

    TaxonDetailUtil::print3ColGeneCountTable( "imgTerm", \@rows, "Term ID", "Term Name", $section );

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

    my $dbh = dbLogin();

    #    my $sql = qq{
    #       select $nvl(itc.term_oid, -1),
    #          $nvl(it2.term, '_'), count(distinct g.gene_oid)
    #       from gene g, gene_img_functions gif,
    #          dt_img_term_path dtp, img_term it
    #        left join img_term_children itc on itc.child = it.term_oid
    #        left join img_term it2 on  itc.term_oid = it2.term_oid
    #        where g.taxon = ?
    #        and g.locus_type = 'CDS'
    #        and g.gene_oid = gif.gene_oid
    #        and gif.function = dtp.map_term
    #        and it.term_oid = dtp.term_oid
    #       group by itc.term_oid, it2.term
    #       order by it2.term
    #    };
    my $sql = qq{
        select $nvl(itc.term_oid, -1),
           $nvl(it2.term, '_'), count(distinct g.gene_oid)
        from gene g, gene_img_functions gif, img_term it
        left join img_term_children itc on itc.child = it.term_oid
        left join img_term it2 on  itc.term_oid = it2.term_oid
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.gene_oid = gif.gene_oid
        and gif.function = it.term_oid
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
    my $term_oid  = param("term_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #    my $sql = qq{
    #       select distinct g.gene_oid, g.gene_display_name
    #       from gene g, gene_img_functions gif, dt_img_term_path dtp, img_term it
    #       where g.taxon = ?
    #       and it.term_oid = ?
    #       and g.locus_type = 'CDS'
    #       and g.gene_oid = gif.gene_oid
    #       and gif.function = dtp.map_term
    #       and it.term_oid = dtp.term_oid
    #       order by g.gene_display_name
    #   };
    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name
       from gene g, gene_img_functions gif, img_term it
       where g.taxon = ?
       and it.term_oid = ?
       and g.locus_type = 'CDS'
       and g.gene_oid = gif.gene_oid
       and gif.function = it.term_oid
       order by g.gene_display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $term_oid );
    my @gene_oids;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( scalar(@gene_oids) == 1 ) {
        my $gene_oid = $gene_oids[0];
        require GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }

    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes Assigned to IMG Term" );
}

sub printImgTermCatGeneList {
    my $taxon_oid = param("taxon_oid");
    my $term_oid  = param("term_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    my $clause = "and itc.term_oid = $term_oid";
    if ( $term_oid eq "-1" ) {
        $clause = "and itc.term_oid is null";
    }

    #    my $sql = qq{
    #        select distinct g.gene_oid, g.gene_display_name
    #        from gene g, gene_img_functions gif,
    #            dt_img_term_path dtp, img_term it
    #        left join img_term_children itc on itc.child = it.term_oid
    #        left join img_term it2 on itc.term_oid = it2.term_oid
    #        where g.taxon = ?
    #        and g.locus_type = 'CDS'
    #        and g.gene_oid = gif.gene_oid
    #        and gif.function = dtp.map_term
    #        and it.term_oid = dtp.term_oid
    #        $clause
    #        order by g.gene_display_name
    #   };
    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene g, gene_img_functions gif, img_term it
        left join img_term_children itc on itc.child = it.term_oid
        left join img_term it2 on itc.term_oid = it2.term_oid
        where g.taxon = ?
        and g.locus_type = 'CDS'
        and g.gene_oid = gif.gene_oid
        and gif.function = it.term_oid
        $clause
        order by g.gene_display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @gene_oids;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( scalar(@gene_oids) == 1 ) {
        my $gene_oid = $gene_oids[0];
        require GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }

    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes Assigned to a IMG Term Category" );
}

############################################################################
# printImgPways - Print IMG pathways.
############################################################################
sub printImgPways {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>IMG Pathways</h1>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    print "<h2>Genome: $taxon_name</h2>\n";

    printStatusLine( "Loading ...", 1 );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my %assert;
    my $sql = qq{
    select ipa.pathway_oid, ipa.status, ipa.evidence
        from img_pathway_assertions ipa
        where ipa.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $pathway_oid, $status, $evid ) = $cur->fetchrow();
        last if !$pathway_oid;

        #$assert{$pathway_oid} = $status . " (" . $evid . ")";
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
        ) new
        group by new.pathway_oid, new.pathway_name
        order by new.pathway_oid, new.pathway_name
    };
    my @bindList = ( $taxon_oid, 'CDS', $taxon_oid, 'CDS' );

    $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    #    my @rows;
    my $it = new InnerTable( 0, "taxonPathway$$", "taxonPathway", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Pathway OID",  "asc", "left" );
    $it->addColSpec( "Pathway Name", "asc", "left" );
    $it->addColSpec( "Assertion",    "asc", "left" );
    $it->addColSpec( "Gene Count",   "asc", "left" );

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

    # TaxonDetailUtil::print2ColGeneCountTable( "imgPway", \@rows );

    TaxonDetailUtil::printCartButtons($section) if $count > 10;
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons($section);

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
    my $taxon_oid   = param("taxon_oid");
    my $pathway_oid = param("pathway_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name
       from gene g, gene_img_functions gif,
         img_reaction_catalysts irc, img_pathway_reactions ipr
       where g.gene_oid = gif.gene_oid
       and g.taxon = ?
       and g.locus_type = 'CDS'
       and gif.function = irc.catalysts
       and irc.rxn_oid = ipr.rxn
       and ipr.pathway_oid = ?
       order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $pathway_oid );
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
       from gene g, gene_img_functions gif,
         img_reaction_t_components itc, img_pathway_reactions ipr
       where g.gene_oid = gif.gene_oid
       and g.taxon = ?
       and g.locus_type = 'CDS'
       and gif.function = itc.term
       and itc.rxn_oid = ipr.rxn
       and ipr.pathway_oid = ?
       order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $pathway_oid );
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

    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes in IMG Pathway" );
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
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #    my $sql = qq{
    #       select ipl.parts_list_oid, ipl.parts_list_name,
    #          count( distinct g.gene_oid )
    #       from img_parts_list ipl, img_parts_list_img_terms plt,
    #          dt_img_term_path tp, gene_img_functions g
    #       where ipl.parts_list_oid = plt.parts_list_oid
    #       and plt.term = tp.term_oid
    #       and tp.map_term = g.function
    #       and g.taxon = ?
    #       group by ipl.parts_list_name, ipl.parts_list_oid
    #       order by ipl.parts_list_name, ipl.parts_list_oid
    #    };
    my $sql = qq{
       select ipl.parts_list_oid, ipl.parts_list_name,
          count( distinct g.gene_oid )
       from img_parts_list ipl, img_parts_list_img_terms plt,
          gene_img_functions g
       where ipl.parts_list_oid = plt.parts_list_oid
       and plt.term = g.function
       and g.taxon = ?
       group by ipl.parts_list_name, ipl.parts_list_oid
       order by ipl.parts_list_name, ipl.parts_list_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
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

    #$dbh->disconnect();

    TaxonDetailUtil::print3ColGeneCountTable( "partsList", \@rows, "Parts List ID", "Parts List Name", $section );

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count IMG Parts List retrieved.", 2 );
    print end_form();
}

############################################################################
# printImgPlistGenes - Show genes under one parts list.
############################################################################
sub printImgPlistGenes {
    my $taxon_oid      = param("taxon_oid");
    my $parts_list_oid = param("parts_list_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #    my $sql = qq{
    #       select distinct g.gene_oid, g.gene_display_name
    #       from img_parts_list ipl, img_parts_list_img_terms plt,
    #          dt_img_term_path tp, gene_img_functions gif, gene g
    #       where ipl.parts_list_oid = plt.parts_list_oid
    #       and plt.term = tp.term_oid
    #       and tp.map_term = gif.function
    #       and gif.gene_oid = g.gene_oid
    #       and g.taxon = ?
    #       and ipl.parts_list_oid = $parts_list_oid
    #       order by g.gene_oid
    #    };
    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name
       from img_parts_list ipl, img_parts_list_img_terms plt,
          gene_img_functions gif, gene g
       where ipl.parts_list_oid = plt.parts_list_oid
       and plt.term = gif.function
       and gif.gene_oid = g.gene_oid
       and g.taxon = ?
       and ipl.parts_list_oid = $parts_list_oid
       order by g.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @gene_oids;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    #$dbh->disconnect();

    if ( scalar(@gene_oids) == 1 ) {
        my $gene_oid = $gene_oids[0];
        require GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }

    TaxonDetailUtil::printFromGeneOids( \@gene_oids, "Genes in IMG Parts List" );
}

############################################################################
# printTaxonPfam - Show protein famlies and count of genes.
############################################################################
sub printTaxonPfam {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    printStatusLine( "Loading ...", 1 );

    $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $data_type_text = getDatatypeText($data_type);
    print "<h1>Pfam Families $data_type_text</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my %id_names;
    my $sql = qq{
       select pf.ext_accession, pf.description
       from pfam_family pf
       order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $ext_accession, $description ) = $cur->fetchrow();
        last if !$ext_accession;

        $id_names{$ext_accession} = $description;
    }
    $cur->finish();

    #$dbh->disconnect();

    my %a_pfam_count;
    my %u_pfam_count;
    my $total_gene_count = 0;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/pfam_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );

                if ( $t2 eq 'assembled' ) {
                    $a_pfam_count{$id} = $cnt;
                } else {
                    $u_pfam_count{$id} = $cnt;
                }

                $total_gene_count += $cnt;
            }
            close $fh;
        }
    }    # for t2

    print "<p>\n";
    my $url = "$section_cgi&page=pfam&taxon_oid=$taxon_oid&cat=cat" . "&data_type=$data_type";
    print alink( $url, "View as Pfam Categories" );
    print "</p>\n";

    my $it = new InnerTable( 1, "pfamCount$$", "pfamCount", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Pfam ID",   "asc", "left" );
    $it->addColSpec( "Pfam Name", "asc", "left" );

    if ( $data_type eq 'both' ) {
        $it->addColSpec( "Gene Count<br/> (assembled)",   "asc", "right" );
        $it->addColSpec( "Gene Count<br/> (unassembled)", "asc", "right" );
        $it->addColSpec( "Gene Count<br/> (both)",        "asc", "right" );
    } else {
        $it->addColSpec( "Gene Count ($data_type)", "asc", "right" );
    }

    my $select_id_name = "func_id";

    my $count = 0;
    my @keys  = sort ( keys %id_names );
    for my $id (@keys) {
        if ( !$a_pfam_count{$id} && !$u_pfam_count{$id} ) {
            # skip zero count
            next;
        }

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        $r .= $id . $sd . $id . "\t";
        $r .= $id_names{$id} . $sd . $id_names{$id} . "\t";

        # count
        if ( $data_type eq 'both' ) {
            my $url2 = "$section_cgi&page=pfamGeneList&func_id=$id";
            $url2 .= "&taxon_oid=$taxon_oid";

            my $total_cnt = 0;
            if ( $a_pfam_count{$id} ) {
                my $cnt = $a_pfam_count{$id};
                $r .= $cnt . $sd . alink( $url2 . "&data_type=assembled", $cnt ) . "\t";
                $total_cnt += $cnt;
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
            if ( $u_pfam_count{$id} ) {
                my $cnt = $u_pfam_count{$id};
                $r .= $cnt . $sd . alink( $url2 . "&data_type=unassembled", $cnt ) . "\t";
                $total_cnt += $cnt;
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
            if ($total_cnt) {
                $r .= $total_cnt . $sd . alink( $url2 . "&data_type=both", $total_cnt ) . "\t";
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
        } else {
            my $cnt = $a_pfam_count{$id};
            if ( $data_type eq 'unassembled' ) {
                $cnt = $u_pfam_count{$id};
            }
            my $url2 = "$section_cgi&page=pfamGeneList&func_id=$id";
            $url2 .= "&taxon_oid=$taxon_oid&data_type=$data_type";

            if ($cnt) {
                $r .= $cnt . $sd . alink( $url2, $cnt ) . "\t";
            } else {
                $r .= $cnt . $sd . $cnt . "\t";
            }
        }

        $it->addRow($r);

        $count++;
    }

    my $name = "_section_${section}_pfamGeneList";
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" ) if $count > 10;
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons( $section, $name, "List Genes" );

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count Pfam(s) retrieved.", 2 );

    print end_form();
}

############################################################################
# printTaxonPfamCat - show pfam categories for the specified genome
############################################################################
sub printTaxonPfamCat {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    $taxon_oid = sanitizeInt($taxon_oid);

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    my $url2 = "$section_cgi&page=catePfamList&taxon_oid=$taxon_oid" . "&cat=cat&data_type=$data_type";

    my $total_genome_gene_count =
      MetaUtil::getGenomeStats( $taxon_oid, $data_type, "Protein coding genes" ) +
      MetaUtil::getGenomeStats( $taxon_oid, $data_type, "RNA genes" );
    my $total_gene_count = MetaUtil::getGenomeStats( $taxon_oid, $data_type, "with Pfam" );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

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

    my $data_type_text = getDatatypeText($data_type);
    print "<h1>Pfam Categories $data_type_text</h1>\n";

    # taxon name
    my $sql = qq{
        select taxon_display_name, is_pangenome
        from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_name, $is_pangenome ) = $cur->fetchrow();
    $cur->finish();
    $taxon_name = HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>\n";
    print alink( "$section_cgi&page=pfam&taxon_oid=$taxon_oid&data_type=$data_type", "View as Pfam list" );
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
    printStatusLine( "Loading ...", 1 );

    my %code2cnt = MetaUtil::getTaxonCate( $taxon_oid, $data_type, 'pfam' );
    $sql = qq{
        select cf.function_code, cf.definition
        from cog_function cf
        order by 2
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    my %categoryHash;
    my $gene_count_total = 0;
    for ( ; ; ) {
        my ( $function_code, $definition ) = $cur->fetchrow();
        last if !$definition;
        last if !$function_code;

        my $gene_count = $code2cnt{$function_code};
        next if ( !$gene_count );

        push @chartcategories, "$definition";
        push @functioncodes,   "$function_code";
        push @chartdata,       $gene_count;
        $categoryHash{$definition} = $gene_count;
        $gene_count_total += $gene_count;

        $count++;
    }
    $cur->finish();

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@functioncodes );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    # Pfam categories table next to pie chart:
    my $it = new InnerTable( 1, "pfamcategories$$", "pfamcategories", 0 );
    my $sd = $it->getSdDelim();
    $it->hideAll();
    $it->addColSpec( "Pfam Categories", "asc",  "left",  "", "", "wrap" );
    $it->addColSpec( "Gene Count",      "desc", "right", "", "", "wrap" );
    $it->addColSpec( "% of Total<br/>($gene_count_total)", "desc", "right" );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;

        my $url = "$section_cgi&page=catePfamList";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&cat=cat&data_type=$data_type";
        $url .= "&function_code=$functioncodes[$idx]";

        my $row;
        if ( $st == 0 ) {
            my $imageref = "<img src='$tmp_url/" . $chart->FILE_PREFIX . "-color-" . $idx . ".png' border=0>";
            $row = escHtml($category1) . $sd . alink( $url, $imageref, "", 1 );
            $row .= "&nbsp;&nbsp;";
        }
        $row .= escHtml($category1) . "\t";
        $row .= $chartdata[$idx] . $sd . alink( $url, $chartdata[$idx] ) . "\t";
        my $percent = 0;
        if ( $gene_count_total > 0 ) {
            $percent = 100 * $chartdata[$idx] / $gene_count_total;
        }
        $percent = sprintf( "%.2f", $percent );
        $row .= $percent . "\t";
        $it->addRow($row);

        $idx++;
    }

    # add the unclassified row:
    my $unclassified_count = $total_gene_count - $gene_count_total;
    my $percent            = 0;
    if ( $gene_count_total > 0 ) {
        $percent = 100 * $unclassified_count / $total_gene_count;
    }
    $percent = sprintf( "%.2f", $percent );

    my $row = "xunclassified" . $sd . "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" . "Not in Pfams\t";
    $row .= $unclassified_count . "\t";
    $row .= $percent . "\t";
    $it->addRow($row);

    $it->{blockDatatableCss} = $blockDatatableCss;
    $it->printOuterTable(1);

    print "<td valign=top align=left>\n";
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
		( $chart->FILEPATH_PREFIX . ".html", "printTaxonPfamCat", 1 );
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
    printStatusLine( "$count Pfam categories retrieved.", 2 );
    print "</div>";    # end pfamcattab1

    print "<div id='pfamcattab2'>";
    my $sql = qq{
        select t.seq_status, t.domain, t.phylum,
               t.ir_class, t.ir_order, t.family, t.genus
        from taxon t
        where t.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

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
    for my $category1 (@chartcategories) {
        last if !$category1;
        push( @category_list, $category1 );
        push( @category_list, "$category1 percentage" );
    }

    print hiddenVar( "data_type", $data_type );

    print "<h2>Configuration</h2>";
    printConfigTable( \@category_list, \@columns, $taxon_oid, "pfam", $blockDatatableCss );
    print end_form();

    print "</div>";    # end pfamcattab2
    TabHTML::printTabDivEnd();
}

############################################################################
# sanitizePfamId - Sanitize Pfam ID
############################################################################
sub sanitizePfamId {
    my ($s) = @_;
    if ( $s !~ /^pfam[0-9]+$/ ) {
        webDie("sanitizePfamId: invalid integer '$s'\n");
    }
    $s =~ /(pfam[0-9]+)/;
    $s = $1;
    return $s;
}

############################################################################
# printPfamGeneList - Show genes under one protein family.
############################################################################
sub printPfamGeneList {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $xcopy     = param("xcopy");
    $taxon_oid = sanitizeInt($taxon_oid);

    my @pfam_ids = param("func_id");
    if ( scalar(@pfam_ids) == 0 ) {
        @pfam_ids = param("ext_accession");
    }
    if ( scalar(@pfam_ids) == 0 ) {
        webError("No Pfam has been selected.");
    }

    printMainForm();
    my $data_type_text = getDatatypeText($data_type);
    print "<h1>Pfam Genes $data_type_text</h1>\n";

    print hidden( 'taxon_oid', $taxon_oid );
    print hidden( 'data_type', $data_type );

    for my $pfam_id2 (@pfam_ids) {
        print hidden( 'func_id', $pfam_id2 );
    }

    printStatusLine( "Loading ...", 1 );

    # get pfam names
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my %funcId2Name;
    TaxonDetailUtil::fetchPfamId2NameHash( $dbh, \@pfam_ids, \%funcId2Name );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    for my $pfam_id (@pfam_ids) {
        my $funcName = $funcId2Name{$pfam_id};
        print $pfam_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>";

    my %id_names;
    my $sql = "select ext_accession, description from pfam_family";
    if ( scalar(@pfam_ids) <= 1000 ) {
        $sql .= " where ext_accession in ('" . join( "','", @pfam_ids ) . "')";
    }
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id2, $name2 ) = $cur->fetchrow();
        last if !$id2;
        $id_names{$id2} = $name2;
    }
    $cur->finish();

    #$dbh->disconnect();

    printStartWorkingDiv("genesforpfam");

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $trunc = 0;

    my $has_sdb   = 1;
    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        if ( !MetaUtil::hasSdbGeneProductFile( $taxon_oid, $t2 ) ) {
            $has_sdb = 0;
        }
    }

    my %gene_copies;

    my $it = new InnerTable( 1, "pfamGene$$", "pfamGene", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",    "asc", "left" );
    $it->addColSpec( "Assembled?", "asc", "left" );
    if ( $xcopy eq 'est_copy' ) {
        $it->addColSpec( "Estimated Copies", "asc", "left" );
        if (   $data_type eq 'assembled'
            || $data_type eq 'both'
            || blankStr($data_type) )
        {
            MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled', \%gene_copies );
        }
    }
    if ($has_sdb) {
        $it->addColSpec( "Gene Name", "asc", "left" );
    }
    $it->addColSpec( "Pfam ID",   "asc", "left" );
    $it->addColSpec( "Pfam Name", "asc", "left" );

    my $select_id_name = "gene_oid";

    my $line       = "";
    my $gene_count = 0;
    my %distinct_gene_h;

    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        $t2 = sanitizeDataType($t2);

        my %h = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, "pfam", \@pfam_ids );

        if ( scalar( keys %h ) > 0 ) {
            for my $pfam_id (@pfam_ids) {
                print "<p>processing $pfam_id ...\n";
                if ($trunc) {
                    last;
                }

                my @gene_list = split( /\t/, $h{$pfam_id} );
                for my $gene_oid (@gene_list) {
                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ( $distinct_gene_h{$workspace_id} ) {

                        # already included
                        next;
                    } else {
                        $distinct_gene_h{$workspace_id} = 1;
                    }

                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" . "&data_type=$t2&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";
                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }

                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }
                    $r .= $pfam_id . $sd . $pfam_id . "\t";
                    $r .= $id_names{$pfam_id} . $sd . $id_names{$pfam_id} . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
            }

            if ( tied(%h) ) {
                untie %h;
            }
        } else {
            my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/pfam_genes.zip";
            if ( !( -e $file_name ) ) {
                next;
            }

            for my $pfam_id (@pfam_ids) {
                print "<p>processing $pfam_id ...\n";
                if ($trunc) {
                    last;
                }

                WebUtil::unsetEnvPath();

                $pfam_id = sanitizePfamId($pfam_id);

                my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name $pfam_id ", 'PfamGenes' );

                if ( !$fh ) {
                    next;
                }

                while ( $line = $fh->getline() ) {
                    chomp($line);
                    my ( $id2, $gene_oid ) = split( /\t/, $line );

                    if ( !$gene_oid ) {
                        $gene_oid = $id2;
                    }

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ( $distinct_gene_h{$workspace_id} ) {

                        # already included
                        next;
                    } else {
                        $distinct_gene_h{$workspace_id} = 1;
                    }

                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&data_type=$t2" . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";
                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }
                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }
                    $r .= $pfam_id . $sd . $pfam_id . "\t";
                    $r .= $id_names{$pfam_id} . $sd . $id_names{$pfam_id} . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
                close $fh;
                WebUtil::resetEnvPath();
            }
        }    # for my pfam_id

    }    # end for my t2

    printEndWorkingDiv("genesforpfam");

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    MetaGeneTable::printMetaGeneTableSelect();

    WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) retrieved", 2 );
    }

    print end_form();
}

############################################################################
# printPfamCatGeneList - print gene list from one pfam category
############################################################################
sub printPfamCatGeneList {
    my $taxon_oid = param("taxon_oid");
    my $func_code = param("func_code");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
        select definition
        from cog_function
        where function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $func_code );
    my ($definition) = $cur->fetchrow();
    $cur->finish();

    my $clause = "and cf.function_code is null";
    if ( $func_code ne "_" ) {
        $clause = "and cf.function_code = '$func_code'";
    }

    my $sql = qq{
        select distinct g.gene_oid
        from gene g, gene_pfam_families gpf
        left join pfam_family_cogs pfc on gpf.pfam_family = pfc.ext_accession
        left join cog_function cf on pfc.functions = cf.function_code
        where g.gene_oid = gpf.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $clause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my $count = 0;
    my @gene_oids;
    my %done;

    my $count = 0;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid} ne "";
        $count++;
        push( @gene_oids, $gene_oid );
        $done{$gene_oid} = 1;
    }
    $cur->finish();
    if ( $count == 1 ) {

        #$dbh->disconnect();
        my $gene_oid = $gene_oids[0];
        use GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }
    print "<h1>Pfam Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<p>\n";
    print "(Only Pfam associated with <i><u>" . escHtml($definition) . "</u></i> are shown with genes.)\n";
    print "</p>\n";

    my $it = new InnerTable( 1, "PfamGenes$$", "PfamGenes", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome ID",         "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left" );

    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    #$dbh->disconnect();
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printTaxonTIGRfam - Show protein famlies and count of genes.
############################################################################
sub printTaxonTIGRfam {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    printMainForm();

    print hidden( 'taxon_oid', $taxon_oid );
    print hidden( 'data_type', $data_type );

    printStatusLine( "Loading ...", 1 );

    $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $data_type_text = getDatatypeText($data_type);
    print "<h1>TIGRfam Families $data_type_text</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my %id_names;
    my $sql = qq{
       select tf.ext_accession, tf.expanded_name
       from tigrfam tf
       order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $ext_accession, $name ) = $cur->fetchrow();
        last if !$ext_accession;

        $id_names{$ext_accession} = $name;
    }
    $cur->finish();

    #$dbh->disconnect();

    my %a_tigr_count;
    my %u_tigr_count;
    my $total_gene_count = 0;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/tigr_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );

                if ( $t2 eq 'assembled' ) {
                    $a_tigr_count{$id} = $cnt;
                } else {
                    $u_tigr_count{$id} = $cnt;
                }

                $total_gene_count += $cnt;
            }
            close $fh;
        }
    }

    print "<p>\n";
    my $total_genome_gene_count = param("total_genome_gene_count");
    my $url                     = "$section_cgi&page=tigrfam&taxon_oid=$taxon_oid" . "&cat=cat&data_type=$data_type";
    print alink( $url, "View as TIGRfam Categories" );
    print "</p>\n";

    my $it = new InnerTable( 1, "tigrfamCount$$", "tigrfamCount", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "TIGRfam ID",   "asc", "left" );
    $it->addColSpec( "TIGRfam Name", "asc", "left" );

    if ( $data_type eq 'both' ) {
        $it->addColSpec( "Gene Count<br/> (assembled)",   "asc", "right" );
        $it->addColSpec( "Gene Count<br/> (unassembled)", "asc", "right" );
        $it->addColSpec( "Gene Count<br/> (both)",        "asc", "right" );
    } else {
        $it->addColSpec( "Gene Count ($data_type)", "asc", "right" );
    }

    my $select_id_name = "func_id";

    my $count = 0;
    my @keys  = sort( keys %id_names );
    for my $id (@keys) {
        if ( !$a_tigr_count{$id} && !$u_tigr_count{$id} ) {

            # skip zero count
            next;
        }

        my $r;

        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";
        $r .= $id . $sd . $id . "\t";
        $r .= $id_names{$id} . $sd . $id_names{$id} . "\t";

        # count
        if ( $data_type eq 'both' ) {
            my $url2 = "$section_cgi&page=tigrfamGeneList";
            $url2 .= "&func_id=$id";
            $url2 .= "&taxon_oid=$taxon_oid";

            my $total_cnt = 0;
            if ( $a_tigr_count{$id} ) {
                my $cnt = $a_tigr_count{$id};
                $r .= $cnt . $sd . alink( $url2 . "&data_type=assembled", $cnt ) . "\t";
                $total_cnt += $cnt;
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
            if ( $u_tigr_count{$id} ) {
                my $cnt = $u_tigr_count{$id};
                $r .= $cnt . $sd . alink( $url2 . "&data_type=unassembled", $cnt ) . "\t";
                $total_cnt += $cnt;
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
            if ($total_cnt) {
                $r .= $total_cnt . $sd . alink( $url2 . "&data_type=both", $total_cnt ) . "\t";
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
        } else {
            my $cnt = $a_tigr_count{$id};
            if ( $data_type eq 'unassembled' ) {
                $cnt = $u_tigr_count{$id};
            }
            my $url2 = "$section_cgi&page=tigrfamGeneList";
            $url2 .= "&func_id=$id";
            $url2 .= "&taxon_oid=$taxon_oid&data_type=$data_type";

            if ($cnt) {
                $r .= $cnt . $sd . alink( $url2, $cnt ) . "\t";
            } else {
                $r .= $cnt . $sd . $cnt . "\t";
            }
        }

        $it->addRow($r);

        $count++;
    }

    TaxonDetailUtil::printCartButtons($section) if $count > 10;
    $it->printOuterTable(1);
    TaxonDetailUtil::printCartButtons($section);

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count TIGRfam(s) retrieved.", 2 );

    print end_form();
}

############################################################################
# printTaxonTIGRfamCat - show TIGRfam categories for the specified genome
############################################################################
sub printTaxonTIGRfamCat {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    $taxon_oid = sanitizeInt($taxon_oid);

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    my $url2 = "$section_cgi&page=cateTigrfamList&cat=cat" . "&taxon_oid=$taxon_oid&data_type=$data_type";

    my $total_genome_gene_count =
      MetaUtil::getGenomeStats( $taxon_oid, $data_type, "Protein coding genes" ) +
      MetaUtil::getGenomeStats( $taxon_oid, $data_type, "RNA genes" );
    my $total_gene_count = MetaUtil::getGenomeStats( $taxon_oid, $data_type, "with TIGRfam" );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

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

    my $data_type_text = getDatatypeText($data_type);
    print "<h1>TIGRfam Roles $data_type_text</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    $taxon_name = HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    print alink( "$section_cgi&page=tigrfam&taxon_oid=$taxon_oid&data_type=$data_type", "View as TIGRfam list" );
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
    my %code2cnt = MetaUtil::getTaxonCate( $taxon_oid, $data_type, 'tigr' );

    my $sql = qq{
        select distinct tr.main_role
        from tigr_role tr
        where tr.main_role is not null
        order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $count            = 0;
    my $gene_count_total = 0;
    my %categoryHash;
    for ( ; ; ) {
        my ($name) = $cur->fetchrow();
        last if !$name;

        my $gene_count = $code2cnt{$name};
        next if ( !$gene_count );

        push @roles,           "$name";
        push @chartcategories, "$name";
        push @chartdata,       $gene_count;
        $categoryHash{$name} = $gene_count;

        $gene_count_total += $gene_count;
        $count++;
    }
    $cur->finish();

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@chartcategories );
    $chart->URL_SECTION( \@roles );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    # TIGRfam Roles table next to pie chart:
    my $it = new InnerTable( 1, "tigrfamcategories$$", "tigrfamcategories", 0 );
    my $sd = $it->getSdDelim();
    $it->hideAll();
    $it->addColSpec( "TIGRfam Roles", "asc",  "left",  "", "", "wrap" );
    $it->addColSpec( "Gene Count",    "desc", "right", "", "", "wrap" );
    $it->addColSpec( "% of Total<br/>($gene_count_total)", "desc", "right" );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;

        my $url = "$section_cgi&page=cateTigrfamList";
        $url .= "&taxon_oid=$taxon_oid&data_type=$data_type";
        $url .= "&cat=cat";
        $url .= "&role=$roles[$idx]";

        my $row;
        if ( $st == 0 ) {
            my $imageref = "<img src='$tmp_url/" . $chart->FILE_PREFIX . "-color-" . $idx . ".png' border=0>";
            $row = escHtml($category1) . $sd . alink( $url, $imageref, "", 1 );
            $row .= "&nbsp;&nbsp;";
        }

        # TIGRfam Roles
        $row .= escHtml($category1) . "\t";

        # Gene Count
        $row .= $chartdata[$idx] . $sd . alink( $url, $chartdata[$idx] ) . "\t";

        # Percentage
        my $percent = 0;
        if ( $gene_count_total > 0 ) {
            $percent = 100 * $chartdata[$idx] / $gene_count_total;
        }
        $percent = sprintf( "%.2f", $percent );
        $row .= $percent . "\t";

        $it->addRow($row);

        $idx++;
    }

    # add the unclassified row:
    my $unclassified_count = $total_gene_count - $gene_count_total;
    my $row                = "xunclassified" . $sd . "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;" . "Not in TIGRfams\t";

    my $percent = 0;
    if ( $total_gene_count > 0 ) {
        $percent = 100 * $unclassified_count / $total_gene_count;
    }
    $percent = sprintf( "%.2f", $percent );

    $row .= $unclassified_count . "\t";
    $row .= $percent . "\t";
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

    my $sql = qq{
        select t.seq_status, t.domain, t.phylum,
               t.ir_class, t.ir_order, t.family, t.genus
        from taxon t
        where t.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = $cur->fetchrow();
    $cur->finish();

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
    for my $category1 (@chartcategories) {
        last if !$category1;
        push( @category_list, $category1 );
        push( @category_list, "$category1 percentage" );
    }

    print hiddenVar( "data_type", $data_type );

    print "<h2>Configuration</h2>";
    printConfigTable( \@category_list, \@columns, $taxon_oid, "tigrfam", $blockDatatableCss );

    print end_form();

    print "</div>";    # end tigrfamcattab2
    TabHTML::printTabDivEnd();
}

############################################################################
# sanitizeTigrfamId - Sanitize Tigrfam ID
############################################################################
sub sanitizeTigrfamId {
    my ($s) = @_;
    if ( $s !~ /^TIGR[0-9]+$/ ) {
        webDie("sanitizeTIGRfamId: invalid integer '$s'\n");
    }
    $s =~ /(TIGR[0-9]+)/;
    $s = $1;
    return $s;
}

############################################################################
# printTIGRfamGeneList - Show genes under one protein family.
############################################################################
sub printTIGRfamGeneList {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $xcopy     = param("xcopy");
    $taxon_oid = sanitizeInt($taxon_oid);

    my @tigrfam_ids = param("func_id");
    if ( scalar(@tigrfam_ids) == 0 ) {
        @tigrfam_ids = param("ext_accession");
    }
    if ( scalar(@tigrfam_ids) == 0 ) {
        webError("No TIGRfam has been selected.");
    }

    printMainForm();
    print hidden( 'taxon_oid', $taxon_oid );
    print hidden( 'data_type', $data_type );

    for my $tigr_id2 (@tigrfam_ids) {
        print hidden( 'func_id', $tigr_id2 );
    }

    printStatusLine( "Loading ...", 1 );

    # get tigrfam names
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $data_type_text = getDatatypeText($data_type);
    print "<h1>TIGRfam Genes $data_type_text</h1>\n";

    my %funcId2Name;
    TaxonDetailUtil::fetchTIGRfamId2NameHash( $dbh, \@tigrfam_ids, \%funcId2Name );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    for my $tigrfam_id (@tigrfam_ids) {
        my $funcName = $funcId2Name{$tigrfam_id};
        print $tigrfam_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>";

    my %tigr_names;
    my $sql = "select ext_accession, expanded_name from tigrfam";
    if ( scalar(@tigrfam_ids) <= 1000 ) {
        $sql .= " where ext_accession in ('" . join( "','", @tigrfam_ids ) . "')";
    }
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id2, $name2 ) = $cur->fetchrow();
        last if !$id2;
        $tigr_names{$id2} = $name2;
    }
    $cur->finish();

    #$dbh->disconnect();

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";

    my $trunc = 0;

    my $has_sdb   = 1;
    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        if ( !MetaUtil::hasSdbGeneProductFile( $taxon_oid, $t2 ) ) {
            $has_sdb = 0;
        }
    }

    my %gene_copies;

    my $it = new InnerTable( 1, "tigrfamGene$$", "tigrfamGene", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",    "asc", "left" );
    $it->addColSpec( "Assembled?", "asc", "left" );
    if ($has_sdb) {
        $it->addColSpec( "Gene Name", "asc", "left" );
    }
    if ( $xcopy eq 'est_copy' ) {
        $it->addColSpec( "Estimated Copies", "asc", "left" );
        if (   $data_type eq 'assembled'
            || $data_type eq 'both'
            || blankStr($data_type) )
        {
            MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled', \%gene_copies );
        }
    }

    $it->addColSpec( "TIGRfam ID",   "asc", "left" );
    $it->addColSpec( "TIGRfam Name", "asc", "left" );

    my $select_id_name = "gene_oid";

    my $line       = "";
    my $gene_count = 0;
    my %distinct_gene_h;

    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        $t2 = sanitizeDataType($t2);

        my %h = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, "tigr", \@tigrfam_ids );

        if ( scalar( keys %h ) > 0 ) {
            for my $tigrfam_id (@tigrfam_ids) {
                if ($trunc) {
                    last;
                }

                my @gene_list = split( /\t/, $h{$tigrfam_id} );
                for my $gene_oid (@gene_list) {
                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ( $distinct_gene_h{$workspace_id} ) {

                        # already included
                        next;
                    } else {
                        $distinct_gene_h{$workspace_id} = 1;
                    }

                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&taxon_oid=$taxon_oid" . "&data_type=$t2&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";
                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }
                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }
                    $r .= $tigrfam_id . $sd . $tigrfam_id . "\t";
                    $r .= $tigr_names{$tigrfam_id} . $sd . $tigr_names{$tigrfam_id} . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
            }

            if ( tied(%h) ) {
                untie %h;
            }
        } else {
            my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/tigr_genes.zip";
            if ( !( -e $file_name ) ) {
                next;
            }

            for my $tigrfam_id (@tigrfam_ids) {
                if ($trunc) {
                    last;
                }

                WebUtil::unsetEnvPath();

                $tigrfam_id = sanitizeTigrfamId($tigrfam_id);

                my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name $tigrfam_id ", 'TigrfamGenes' );

                if ( !$fh ) {
                    next;
                }

                while ( $line = $fh->getline() ) {
                    chomp($line);
                    my ( $id2, $gene_oid ) = split( /\t/, $line );
                    if ( !$gene_oid ) {
                        $gene_oid = $id2;
                    }

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    if ( $distinct_gene_h{$workspace_id} ) {

                        # already included
                        next;
                    } else {
                        $distinct_gene_h{$workspace_id} = 1;
                    }

                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&data_type=$t2" . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";
                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }
                    my $g_copy = 1;
                    if ( $xcopy eq 'est_copy' ) {
                        if ( $t2 eq 'assembled' ) {
                            if ( $gene_copies{$gene_oid} ) {
                                $g_copy = $gene_copies{$gene_oid};
                            }
                        }
                        $r .= $g_copy . $sd . $g_copy . "\t";
                    }
                    $r .= $tigrfam_id . $sd . $tigrfam_id . "\t";
                    $r .= $tigr_names{$tigrfam_id} . $sd . $tigr_names{$tigrfam_id} . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
                close $fh;
                WebUtil::resetEnvPath();
            }
        }

    }    # end for t2

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    MetaGeneTable::printMetaGeneTableSelect();

    WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) retrieved.", 2 );
    }

    print end_form();
}

############################################################################
# printTIGRfamCatGeneList - print gene list for one TIGRfam category
############################################################################
sub printTIGRfamCatGeneList {
    my $taxon_oid = param("taxon_oid");
    my $role      = param("role");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $clause = "and tr.main_role = ?";
    if ( $role eq "_" ) {
        $clause = "and tr.main_role is null";
    }

    my $sql = qq{
        select distinct gtf.gene_oid
        from gene g, gene_tigrfams gtf
        left join tigrfam_roles trs on gtf.ext_accession = trs.ext_accession
        left join tigr_role tr on trs.roles = tr.role_id
        where g.gene_oid = gtf.gene_oid
        and g.taxon = ?
        $clause
    };

    my @array = ($taxon_oid);
    if ( $role ne "_" ) {
        push( @array, $role );
    }

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@array, $verbose );

    my $count = 0;
    my @gene_oids;
    my %done;

    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid} ne "";
        $count++;
        push( @gene_oids, $gene_oid );
        $done{$gene_oid} = 1;
    }
    $cur->finish();
    if ( $count == 1 ) {

        #$dbh->disconnect();
        my $gene_oid = $gene_oids[0];
        use GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }

    print "<h1>TIGRfam Genes</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<p>\n";
    print "(Only TIGRfam associated with <i><u>" . escHtml($role) . "</u></i> are shown with genes.)\n";
    print "</p>\n";

    my $it = new InnerTable( 1, "TIGRfamGenes$$", "TIGRfamGenes", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc",   "left" );
    $it->addColSpec( "Gene Product Name", "asc",   "left" );
    $it->addColSpec( "Genome ID",           "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc",   "left" );

    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    print end_form();

    #$dbh->disconnect();
    printStatusLine( "$count gene(s) retrieved.", 2 );
}

############################################################################
# printInterPro - Show InterPro groups and count of genes in them.
############################################################################
sub printInterPro {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>InterPro Domains</h1>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select giih.description, giih.id, count( distinct g.gene_oid )
       from gene_xref_families giih, gene g
       where giih.db_name = 'InterPro'
       and giih.gene_oid = g.gene_oid
       and g.taxon = ?
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
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
        $r .= $gene_count . $sortDelim . alink( $url, $gene_count ) . "\t";
        push( @rows, $r );
    }
    TaxonDetailUtil::print3ColGeneCountTable( "interpro", \@rows, "Interpro ID", "Interpro Name", $section );
    $cur->finish();

    #$dbh->disconnect();

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count InterPro retrieved.", 2 );
    print end_form();
}

############################################################################
# printInterProGeneList - Show genes under one InterPro family.
############################################################################
sub printInterProGeneList {
    my $taxon_oid     = param("taxon_oid");
    my $ext_accession = param("ext_accession");

    if ( $ext_accession eq '' ) {
        webError("No Interpro has been selected.");
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    print "<h1>\n";
    print "InterPro Genes\n";
    print "</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
       select distinct giih.description, giih.id, g.gene_oid
       from gene_xref_families giih, gene g
       where giih.db_name = 'InterPro'
       and giih.gene_oid = g.gene_oid
       and g.taxon = ?
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and giih.id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $ext_accession );
    my $count = 0;
    my @gene_oids;
    my %done;
    my $count = 0;
    for ( ; ; ) {
        my ( $name, $ext_accession, $gene_oid ) = $cur->fetchrow();
        last if !$name;
        next if $done{$gene_oid} ne "";
        $count++;
        push( @gene_oids, $gene_oid );
        $done{$gene_oid} = 1;
    }
    $cur->finish();
    if ( $count == 1 ) {

        #$dbh->disconnect();
        my $gene_oid = $gene_oids[0];
        use GeneDetail;
        GeneDetail::printGeneDetail($gene_oid);
        return 0;
    }
    printMainForm();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome ID",         "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left" );

    print "<p>\n";
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );
    print "</p>\n";

    #$dbh->disconnect();

    WebUtil::printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace('gene_oid');
    }

    printStatusLine( "$count gene(s) retrieved.", 2 );
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
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select distinct g.gene_oid
       from gene g
       where g.locus_type not like '%RNA'
       and g.locus_type != 'CDS'
       and g.locus_type != 'pseudo'
       and g.taxon = ?
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

        #$dbh->disconnect();
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
    my $data_type = param('data_type');

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    printMainForm();
    print "<h1>KEGG Pathways</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>\n";
    my $url = "$section_cgi&page=kegg&cat=cat&taxon_oid=$taxon_oid";
    if ($data_type) {
        $url .= "&data_type=$data_type";
    }
    print alink( $url, "View as KEGG Categories" );
    print "</p>\n";

    my $count = 0;
    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    if ($isTaxonInFile) {

        # FS
        my %funcs = MetaUtil::getTaxonFuncCount( $taxon_oid, $data_type, 'kegg_pathway' );

        my $sql = qq{
            select nvl(pw.category, 'Unknown'),
                   pw.pathway_name, pw.pathway_oid
            from kegg_pathway pw
            order by pw.category, lower( pw.pathway_name ), pw.pathway_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        print "<p>\n";
        print "The number of genes in each KEGG pathway is shown in parentheses.\n";
        print "</p>\n";
        printStatusLine( "Loading ...", 1 );
        print "<p>\n";
        my $old_category = "";

        for ( ; ; ) {
            my ( $category, $pathway_name, $pathway_oid ) = $cur->fetchrow();
            last if !$category;

            if ( !$funcs{$pathway_oid} ) {
                next;
            }

            # print out the previous one
            if ( $old_category ne $category ) {

                # print category
                print "<b>\n";
                print escHtml($category);
                print "</b>\n";
                print "<br/>\n";
                $old_category = $category;
            }

            $count++;

            # print pathway
            my $url = "$section_cgi&page=keggPathwayGenes";
            $url .= "&pathway_oid=$pathway_oid";
            $url .= "&taxon_oid=$taxon_oid";
            print nbsp(4);
            print escHtml($pathway_name);
            my $gene_count = $funcs{$pathway_oid};
            print " (" . alink( $url, $gene_count ) . ")<br/>\n";
        }
        $cur->finish();

    } else {

        # DB
        my $sql = qq{
             select pw.category, pw.pathway_name,
                pw.pathway_oid, count( distinct g.gene_oid )
             from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk, ko_term_enzymes kt,
                gene_ko_enzymes ge, gene g
             where pw.pathway_oid = roi.pathway
             and roi.roi_id = rk.roi_id
             and rk.ko_terms = kt.ko_id
             and kt.enzymes = ge.enzymes
             and ge.gene_oid = g.gene_oid
             and g.taxon = ?
             and g.locus_type = 'CDS'
             and g.obsolete_flag = 'No'
             group by pw.category, pw.pathway_name, pw.pathway_oid
             order by pw.category, lower( pw.pathway_name ), pw.pathway_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
        print "<p>\n";
        print "The number of genes in each KEGG pathway is shown in parentheses.\n";
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
    }

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
    my $data_type   = param('data_type');
    my $pathway_oid = param("pathway_oid");

    if ( $pathway_oid eq '' ) {
        webError("No KEGG has been selected.");
    }

    my $dbh     = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql     = "select t.taxon_oid, t.taxon_display_name, t.in_file " . "from taxon t where taxon_oid = ? " . $rclause;
    my $cur     = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $tid2, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();

    if ( !$tid2 ) {
        return;
    }

    my %funcs = MetaUtil::getTaxonFuncCount( $taxon_oid, $data_type, 'kegg_pathway' );

    print "<h1>KEGG Pathway Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $count = 0;
    my $trunc = 0;
    if ( $in_file eq 'Yes' ) {

        # FS
        $sql = qq{
             select pw.pathway_oid, pw.pathway_name,
                roi.roi_id, rk.ko_terms
             from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk
             where pw.pathway_oid = roi.pathway
             and roi.roi_id = rk.roi_id
             and pw.pathway_oid = ?
             };
        $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
        my %gene_h;
        undef %gene_h;
        my $pathway_name = "";

        printMainForm();
        my $it = new InnerTable( 1, "pathwaygene$$", "pathwaygene", 1 );
        $it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID",           "asc", "left" );
        $it->addColSpec( "Gene Product Name", "asc", "left" );
        $it->addColSpec( "Genome Name",       "asc", "left" );
        my $sd = $it->getSdDelim();

        my $select_id_name = "gene_oid";

        for ( ; ; ) {
            my ( $pathway_oid, $name, $roi_id, $ko_id ) = $cur->fetchrow();
            last if !$pathway_oid;

            if ($trunc) {
                last;
            }

            $pathway_name = $name;

            my %ko_genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, $data_type, $ko_id );
            for my $gene_oid ( keys %ko_genes ) {
                if ($trunc) {
                    last;
                }
                if ( $count >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }

                my $workspace_id = $ko_genes{$gene_oid};
                if ( $gene_h{$workspace_id} ) {

                    # duplicate
                    next;
                } else {
                    $gene_h{$workspace_id} = 1;
                }

                my ( $t2, $d2, $g2 ) = split( / /, $workspace_id );
                my $r;
                $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$workspace_id' />" . "\t";
                my $url =
                    "$main_cgi?section=MetaGeneDetail"
                  . "&page=metaGeneDetail&gene_oid=$gene_oid"
                  . "&taxon_oid=$t2&data_type=$d2";
                $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                my ( $gene_name, $source ) = MetaUtil::getGeneProdNameSource( $g2, $t2, $d2 );
                $r .= $gene_name . $sd . $gene_name . "\t";
                my $taxon_url = "$main_cgi?section=MetaDetail" . "&page=metaDetail&taxon_oid=$taxon_oid";
                $r .= $taxon_name . $sd . alink( $taxon_url, $taxon_name ) . "\t";

                $it->addRow($r);
                $count++;
            }
        }
        $cur->finish();

        if ($trunc) {
            my $s = "Results limited to $maxGeneListResults genes.\n";
            $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
            printStatusLine( $s, 2 );
        } else {
            my $prev_cnt = $funcs{$pathway_oid};
            my $s        = "$count gene(s) loaded.";
            if ( $count != $prev_cnt ) {
                $s .= " <font color='red'>(Gene count is different due to recent KEGG refresh in IMG.)</font>";
            }
            printStatusLine( $s, 2 );
        }

        print "<h2>" . escHtml($pathway_name) . "</h2>\n";

        if ($count) {
            WebUtil::printScaffoldCartFooter() if $count > 10;
            $it->printOuterTable(1);
            WebUtil::printScaffoldCartFooter();

            MetaGeneTable::printMetaGeneTableSelect();

            WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
        }

    } else {

        # DB
        $sql = qq{
           select distinct pw.pathway_name, pw.pathway_oid, g.gene_oid
           from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk, ko_term_enzymes kt,
                gene_ko_enzymes ge, gene g
           where pw.pathway_oid = ?
           and pw.pathway_oid = roi.pathway
           and roi.roi_id = rk.roi_id
           and rk.ko_terms = kt.ko_id
           and kt.enzymes = ge.enzymes
           and ge.gene_oid = g.gene_oid
           and g.taxon = ?
           and g.locus_type = 'CDS'
           and g.obsolete_flag = 'No'
          };
        my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid, $taxon_oid );
        my @gene_oids;
        my %done;
        my $pathway_name;

        for ( ; ; ) {
            my ( $name, $ext_accession, $gene_oid ) = $cur->fetchrow();
            last if !$name;
            next if $done{$gene_oid} ne "";
            $count++;
            $pathway_name = $name;
            push( @gene_oids, $gene_oid );
            $done{$gene_oid} = 1;
        }
        $cur->finish();

        print "<h2>" . escHtml($pathway_name) . "</h2>\n";

        if ( $count == 1 ) {
            my $gene_oid = $gene_oids[0];
            use GeneDetail;
            GeneDetail::printGeneDetail($gene_oid);
            return 0;
        }
        printMainForm();

        my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
        $it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID",           "asc", "right" );
        $it->addColSpec( "Locus Tag",         "asc", "left" );
        $it->addColSpec( "Gene Product Name", "asc", "left" );
        $it->addColSpec( "Genome ID",         "asc", "right" );
        $it->addColSpec( "Genome Name",       "asc", "left" );

        HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

        WebUtil::printGeneCartFooter() if $count > 10;
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        if ( $count > 0 ) {
            WorkspaceUtil::printSaveGeneToWorkspace('gene_oid');
        }
    }

    #printStatusLine( "$count gene(s) retrieved.", 2 );
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
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Column Name", "asc", "left" );

    $it->{blockDatatableCss} = $blockDatatableCss;

    my $checked = "";
    my $idx     = 0;
    foreach my $cat (@$category_list_aref) {
        $checked = isColumnSelected( $cat, $columns_aref );
        my $row;
        my $row = $sd . "<input type='checkbox' $checked " . "name='outputCol' value='$cat'/>\t";
        $row .= $cat . "\t";
        $it->addRow($row);
        $idx++;
    }

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "cat",       "cat" );

    if ( $idx > 10 ) {
        my $name = "_section_${section}_$param";
        print "<input type='submit' name='$name' value='Display Again' class='meddefbutton' />"
          . "&nbsp;"
        # Can not be replaced by WebUtil::printButtonFooter();
          . "<input id='sel' type='button' name='selectAll' value='Select All' "
          . "onClick='selectAllOutputCol(1)' class='smbutton' />\n"
		  . "&nbsp;"
          . "<input id='clr' type='button' name='clearAll' value='Clear All' "
          . "onClick='selectAllOutputCol(0)' class='smbutton' />\n";
    }

    $it->printOuterTable(1);

    my $name = "_section_${section}_$param";
    print "<input type='submit' name='$name' value='Display Again' class='meddefbutton' />"
      . "&nbsp;"
    # Can not be replaced by WebUtil::printButtonFooter();
      . "<input id='sel' type=button name='selectAll' value='Select All' "
      . "onClick='selectAllOutputCol(1)' class='smbutton' />\n"
	  . "&nbsp;"
	  . "<input id='clr' type=button name='clearAll' value='Clear All' "
      . "onClick='selectAllOutputCol(0)' class='smbutton' />\n";
}

############################################################################
# printKeggCategories - Show KEGG groups and count of genes.
############################################################################
sub printKeggCategories {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    InnerTable::loadDatatableCss();
    my $blockDatatableCss = 1;    # datatable.css should be loaded for the first table on page

    my $url2 = "$section_cgi&page=keggCategoryGenes&taxon_oid=$taxon_oid" . "&data_type=$data_type";

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    #$dbh->disconnect();

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
    my $total_gene_count = MetaUtil::getGenomeStats( $taxon_oid, $data_type, "with KEGG" );
    my $total_genome_gene_count =
      MetaUtil::getGenomeStats( $taxon_oid, $data_type, "Protein coding genes" ) +
      MetaUtil::getGenomeStats( $taxon_oid, $data_type, "RNA genes" );

    print "<h1>KEGG Categories</h1>\n";

    my $sql = qq{
        select taxon_display_name, is_pangenome
        from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_name, $is_pangenome ) = $cur->fetchrow();
    $cur->finish();
    $taxon_name = HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    my $url = "$section_cgi&page=kegg&taxon_oid=$taxon_oid" . "&data_type=$data_type";
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

    my %funcs = MetaUtil::getTaxonFuncCount( $taxon_oid, $data_type, 'kegg' );
    my $sql =
      "select distinct pw.category from kegg_pathway pw " . "where pw.category is not null " . "order by pw.category";

    #print "printKeggCategories() sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );

    print "<table width=800 border=0>\n";
    print "<tr>";
    print "<td valign=top>\n";

    my %categoryHash;
    my $count = 0;
    for ( ; ; ) {
        my ($category) = $cur->fetchrow();
        last if !$category;
        my $gene_count = $funcs{$category};
        next if ( !$gene_count );

        $count++;

        push @chartcategories, "$category";
        push @chartdata,       $gene_count;
        $categoryHash{$category} = $gene_count;
    }
    $cur->finish();
    $categoryHash{'Total KEGG Genes'} = $total_gene_count;

    #print Dumper(\%categoryHash);
    #print "<br/>\n";

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

    # KEGG categories table next to pie chart:
    my $it = new InnerTable( 1, "keggcategories$$", "keggcategories", 0 );
    my $sd = $it->getSdDelim();
    $it->hideAll();
    $it->addColSpec( "KEGG Categories", "asc",  "left",  "", "", "wrap" );
    $it->addColSpec( "Gene Count",      "desc", "right", "", "", "wrap" );

    my $idx = 0;
    for my $category1 (@chartcategories) {
        last if !$category1;

        my $catUrl = massageToUrl($category1);
        my $url    = "$section_cgi&page=keggCategoryGenes";
        $url .= "&category=$catUrl";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&data_type=$data_type";

        my $row;
        if ( $st == 0 ) {
            my $imageref = "<img src='$tmp_url/" . $chart->FILE_PREFIX . "-color-" . $idx . ".png' border=0>";
            if ( lc($category1) eq "unknown" ) {
                $row = "xunknown";
            } else {
                $row = escHtml($category1);
            }
            $row .= $sd . alink( $url, $imageref, "", 1 );
            $row .= "&nbsp;&nbsp;";
        }
        $row .= escHtml($category1) . "\t";
        $row .= $chartdata[$idx] . $sd . alink( $url, $chartdata[$idx] ) . "\t";

        $it->addRow($row);
        $idx++;
    }

    $it->printOuterTable(1);

    print "<td valign=top align=left>\n";
    ## print the chart:
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
    my $sql = qq{
        select t.seq_status, t.domain,
               t.phylum, t.ir_class, t.ir_order, t.family, t.genus
        from taxon t
        where t.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $seq_status, $domain, $phylum, $ir_class, $ir_order, $family, $genus ) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    # print pangenome selection table
    #if (lc($is_pangenome) eq "yes") {
    #    TaxonList::printPangenomeTable($taxon_oid);
    #}

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

    # add some initial categoies to be selected
    my @category_list;
    push( @category_list, "Phylum" );
    push( @category_list, "Family" );
    push( @category_list, "Class" );
    push( @category_list, "Order" );
    push( @category_list, "Genus" );
    push( @category_list, "Total KEGG Genes" );
    for my $category1 (@chartcategories) {
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
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $category  = param("category");

    print "<h1>\n";
    print "KEGG Category Genes\n";
    print "</h1>\n";
    printStatusLine( "Loading ...", 1 );
    print "<h2>\n";
    print escHtml($category);
    print "</h2>\n";

    my $db_category = $category;
    $db_category =~ s/'/''/g;    # replace ' with '', if any
    my $catClause = "and pw.category = '$db_category' ";
    if ( $category eq "" || $category eq "Unknown" ) {
        $catClause = "and pw.category is null ";
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $cluster_id = param('cluster_id');
    my %cluster_gene_h;
    if ($cluster_id) {
        my $url = "main.cgi?section=BiosyntheticDetail&page=cluster_detail"
	    . "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";
        print "<p>Cluster: " . alink( $url, $cluster_id ) . "</p>\n";

        print hiddenVar( "cluster_id", $cluster_id );

        my $sql = "select feature_id from bio_cluster_features_new "
	    . "where cluster_id = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
        for ( ; ; ) {
            my ($id2) = $cur->fetchrow();
            last if !$id2;
            $cluster_gene_h{$id2} = 1;
        }
        $cur->finish();
    }

    my %funcs = MetaUtil::getTaxonFuncCount( $taxon_oid, $data_type, 'kegg' );

    printMainForm();
    WebUtil::printGeneCartFooter();

    print "<p>\n";

    my $sql = qq{
       select distinct pw.image_id, pw.pathway_name, rk.ko_terms
       from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk
       where pw.pathway_oid = roi.pathway
       and roi.roi_id = rk.roi_id
       $catClause
       order by 1, 2, 3
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $select_id_name = "gene_oid";

    my $gene_count  = 0;
    my $prev_map_id = "";
    my %gene_h;
    my %all_genes;
    undef %gene_h;
    my $display_pathway_name = 0;

    for ( ; ; ) {
        my ( $image_id, $pathway_name, $ko_id ) = $cur->fetchrow();
        last if !$image_id;

        if ( $image_id ne $prev_map_id ) {
            # a new pathway
            undef %gene_h;
            $display_pathway_name = 1;
        }

        # print all genes
        my %ko_genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, $data_type, $ko_id );
        for my $gene_oid ( keys %ko_genes ) {
            my $workspace_id = $ko_genes{$gene_oid};
            my ( $t2, $d2, $g2 ) = split( / /, $workspace_id );

            if ($cluster_id) {
                # only genes in cluster
                if ( $d2 ne 'assembled' ) {
                    next;
                }
                if ( !$cluster_gene_h{$g2} ) {
                    next;
                }
            }

            if ($display_pathway_name) {
                print "<b>\n";
                my $url = "$main_cgi?section=KeggMap&page=keggMapRelated";
                $url .= "&map_id=$image_id";
                $url .= "&taxon_oid=$taxon_oid";
                if ($cluster_id) {
                    $url .= "&cluster_id=$cluster_id";
                }
                print alink( $url, $pathway_name );
                print "</b>\n";
                print "<br/>\n";
                $display_pathway_name = 0;
            }

            $all_genes{$workspace_id} = 1;
            if ( $gene_h{$workspace_id} ) {
                # duplicate
                next;
            }
            $gene_h{$workspace_id} = 1;

            print nbsp(2);
            print "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\n";
            my $url =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&gene_oid=$gene_oid"
              . "&taxon_oid=$t2&data_type=$d2";
            my ( $gene_display_name, $source ) =
		MetaUtil::getGeneProdNameSource( $gene_oid, $t2, $d2 );
            print alink( $url, $gene_oid ) . " " . escHtml("$gene_display_name");
            my @gene_ecs = MetaUtil::getGeneEc( $gene_oid, $t2, $d2 );

            if ( scalar(@gene_ecs) > 0 ) {
                print " (" . join( ", ", @gene_ecs ) . ") ";
            }
            print "<br/>\n";
        }

        $prev_map_id = $image_id;
    }
    $cur->finish();

    print "</p>\n";

    #$dbh->disconnect();
    $gene_count = scalar( keys %all_genes );

    my $prev_cnt = $funcs{$category};
    my $s        = "$gene_count gene(s) retrieved.";
    if ( $gene_count != $prev_cnt ) {
        $s .= " <font color='red'>(Gene count is different due to recent KEGG refresh in IMG.)</font>";
    }
    printStatusLine( $s, 2 );

    if ( !$gene_count ) {
        print end_form();
        return;
    }

    print "<p>\n";
    WebUtil::printGeneCartFooter();

    ## save to workspace
    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace_withAllGeneFuncList($select_id_name);
    }

    print end_form();
}

############################################################################
# printNoKegg - Show genes that do not have KEGG mapping.
############################################################################
sub printNoKegg {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
      select distinct g0.gene_oid
      from gene g0
      where g0.taxon = ?
      and g0.locus_type = 'CDS'
      and g0.obsolete_flag = 'No'
      and g0.gene_oid not in(
          select distinct g.gene_oid
          from kegg_pathway pw, image_roi roi,
            image_roi_ko_terms rk, ko_term_enzymes kt,
            gene_ko_enzymes ge, gene g
          where pw.pathway_oid = roi.pathway
          and roi.roi_id = rk.roi_id
          and rk.ko_terms = kt.ko_id
          and kt.enzymes = ge.enzymes
          and ge.gene_oid = g.gene_oid
          and g.taxon = ?
          and g.locus_type = 'CDS'
          and g.obsolete_flag = 'No'
      )
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Non-KEGG Genes", "", $taxon_oid, $taxon_oid );
}

# genes not connected to metacyc
sub printMetacyc {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    #### PREPARE THE PIECHART ######
    my @chartseries;
    my @chartcategories;
    my @chartdata;
    #################################

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    print "<h1>MetaCyc Pathways</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my %funcs = MetaUtil::getTaxonCate( $taxon_oid, $data_type, 'metacyc' );
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
        select bp.unique_id, bp.common_name
        from biocyc_pathway bp
        order by bp.common_name
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $it = new InnerTable( 1, "MetaCycPathways$$", "MetaCycPathways", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "MetaCyc Pathway ID", "asc",  "left" );
    $it->addColSpec( "MetaCyc Pathway",    "asc",  "left" );
    $it->addColSpec( "Gene Count",         "desc", "right" );

    my $select_id_name = "func_id";

    my @uniqueIds;
    for ( ; ; ) {
        my ( $uid, $category ) = $cur->fetchrow();
        last if !$category;
        my $gene_count = $funcs{$uid};
        next if !$gene_count;

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
    for my $category1 (@chartcategories) {
        last if !$category1;
        my $catUrl = massageToUrl($category1);

        my $unique_id = $uniqueIds[$idx];
        my $url       = "$section_cgi&page=metaCycGenes";
        $url .= "&unique_id=$unique_id";
        $url .= "&taxon_oid=$taxon_oid&data_type=$data_type";

        if ( $st == 0 ) {

        }

        my $row;
        $row .= $sd . "<input type='checkbox' name='$select_id_name' value='MetaCyc:$unique_id' /> \t";

        $row .= $unique_id . $sd . $unique_id . "\t";
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
    if ( $env->{chart_exe} ne "" ) {

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
    my $sql = qq{
        select distinct g0.gene_oid
        from gene g0
        where g0.taxon = ?
            and g0.locus_type = 'CDS'
            and g0.obsolete_flag = 'No'
        minus
        select distinct g.gene_oid
        from gene_biocyc_rxns g
        where g.taxon =  ?
    };

    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Non-MetaCyc Genes", "", $taxon_oid, $taxon_oid );
}

sub printMetacycGenes {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

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
    printStatusLine( "Loading ...", 1 );

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );
    for my $func_id (@metacyc_ids) {
        print hiddenVar( "func_id", $func_id );
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my %cluster_gene_h;
    my $cluster_id = param("cluster_id");
    if ($cluster_id) {
        print hiddenVar( "cluster_id", $cluster_id );

        my $sql = "select feature_id from bio_cluster_features_new " . "where cluster_id = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
        for ( ; ; ) {
            my ($id2) = $cur->fetchrow();
            last if !$id2;
            $cluster_gene_h{$id2} = 1;
        }
        $cur->finish();
    }

    my %funcs = MetaUtil::getTaxonCate( $taxon_oid, $data_type, 'metacyc' );

    my %funcId2Name;
    my $funcIdsInClause = TaxonDetailUtil::fetchMetacycId2NameHash
	( $dbh, \@metacyc_ids, \%funcId2Name, 1 );

    print "<h1>MetaCyc Pathway Genes</h1>";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    $taxon_name = HtmlUtil::printMetaTaxonName
	( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    for my $metacyc_id (@metacyc_ids) {
        my $funcName = $funcId2Name{$metacyc_id};
        print $metacyc_id . ", <i><u>" . $funcName . "</u></i><br/>\n";
    }
    print "</p>\n";

    if ($cluster_id) {
        my $url = "main.cgi?section=BiosyntheticDetail&page=cluster_detail"
	    . "&taxon_oid=$taxon_oid&cluster_id=$cluster_id";
        print "<p>Cluster: " . alink( $url, $cluster_id ) . "</p>\n";

        print hiddenVar( "cluster_id", $cluster_id );
    }

    # get MetaCyc enzymes
    my $sql = qq{
        select distinct br.ec_number
        from biocyc_reaction_in_pwys brp, biocyc_reaction br
        where brp.in_pwys in ($funcIdsInClause)
        and brp.unique_id = br.unique_id
        and br.ec_number is not null
    };

    #print "printMetacycGenes() sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );

    my @enzymes = ();
    for ( ; ; ) {
        my ($ec) = $cur->fetchrow();
        last if !$ec;
        push @enzymes, ($ec);
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_func_id" )
      if ( $funcIdsInClause =~ /gtt_func_id/i );

    #$dbh->disconnect();

    my %gene_h;
    for my $ec (@enzymes) {
        my %ec_genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, $data_type, $ec );
        for my $g2 ( keys %ec_genes ) {
            $gene_h{$g2} = $ec_genes{$g2};
        }
    }

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",   "asc", "left" );
    $it->addColSpec( "Gene Name", "asc", "left" );

    my $select_id_name = "gene_oid";

    my $gene_count = 0;
    my $trunc      = 0;
    for my $gene_oid ( keys %gene_h ) {
        my $workspace_id = $gene_h{$gene_oid};
        my ( $t2, $d2, $g2 ) = split( / /, $workspace_id );

        if ($cluster_id) {

            # only genes in cluster
            if ( $d2 ne 'assembled' ) {
                next;
            }
            if ( !$cluster_gene_h{$g2} ) {
                next;
            }
        }

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$workspace_id' />" . "\t";
        my $url =
          "$main_cgi?section=MetaGeneDetail" . "&page=metaGeneDetail&gene_oid=$gene_oid" . "&taxon_oid=$t2&data_type=$d2";
        $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
        my ( $gene_name, $source ) = MetaUtil::getGeneProdNameSource( $g2, $t2, $d2 );
        $r .= $gene_name . $sd . $gene_name . "\t";

        $it->addRow($r);
        $gene_count++;
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }

    if ( $gene_count == 0 ) {
        print "<p><font color='red'>"
          . "Could not find genes for MetaCyc @metacyc_ids "
          . "(MetaCyc data has changed due to recent IMG refresh.)"
          . "</font></p>";
        print end_form();
        return;
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    #WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);

    my $prev_cnt = 0;
    for my $id2 (@metacyc_ids) {
        $prev_cnt += $funcs{$id2};
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        my $s = "$gene_count gene(s) loaded";
        if ( scalar(@metacyc_ids) == 1 && $gene_count != $prev_cnt ) {
            $s .= " <font color='red'>" . "(Gene count is different due to recent MetaCyc refresh in IMG.)" . "</font>";
        }
        printStatusLine( $s, 2 );
    }

    print end_form();
}

###############################################################################
# printKo: print KO and gene counts in a table
###############################################################################
sub printKo {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    $taxon_oid = sanitizeInt($taxon_oid);

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $data_type_text = getDatatypeText($data_type);
    print "<h1>KEGG Orthology (KO) $data_type_text</h1>\n";

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    my %ko_counts;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/ko_count.txt";
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $ko2, $cnt ) = split( /\t/, $line );

                if ( $ko_counts{$ko2} ) {
                    $ko_counts{$ko2} += $cnt;
                } else {
                    $ko_counts{$ko2} = $cnt;
                }
            }
            close $fh;
        }
    }

    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition
        from ko_term kt
        order by 1
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "ko$$", "ko", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "KO ID",      "asc",  "left" );
    $it->addColSpec( "Name",       "asc",  "left" );
    $it->addColSpec( "Definition", "asc",  "left" );
    $it->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "func_id";

    my $count       = 0;
    my $total_count = 0;
    for ( ; ; ) {
        my ( $id, $name, $defn ) = $cur->fetchrow();
        last if !$id;

        if ( !$ko_counts{$id} ) {
            next;
        }
        my $gene_count = $ko_counts{$id};
        $total_count += $gene_count;
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$id' /> \t";

        my $url = "$section_cgi&page=koGenes";
        $url .= "&koid=$id";
        $url .= "&taxon_oid=$taxon_oid&data_type=$data_type";

        $r .= $id . $sd . $id . "\t";
        $r .= $name . $sd . $name . "\t";
        $r .= $defn . $sd . $defn . "\t";
        $r .= $gene_count . $sd . alink( $url, $gene_count ) . "\t";
        $it->addRow($r);
    }

    $cur->finish();

    #$dbh->disconnect();

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
    my $sql = qq{
      select distinct g0.gene_oid
      from gene g0
      where g0.taxon = ?
      and g0.locus_type = 'CDS'
      and g0.obsolete_flag = 'No'
      and g0.gene_oid not in(
        select g.gene_oid
        from gene g, gene_ko_terms gkt
        where g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        and g.gene_oid = gkt.gene_oid
      )
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Non-KEGG Orthology (KO) Genes", "", $taxon_oid, $taxon_oid );
}

############################################################################
# sanitizeKoId - Sanitize KO ID
############################################################################
sub sanitizeKoId {
    my ($s) = @_;
    my ( $s1, $s2 ) = split( /\:/, $s );
    if ($s2) {
        $s = $s2;
    }
    if ( $s !~ /^K[0-9]+$/ ) {
        webDie("sanitizeKoId: invalid integer '$s'\n");
    }
    $s =~ /(K[0-9]+)/;
    $s = $1;
    return $s;
}

###############################################################################
# printKoGenes: list all genes with koid
###############################################################################
sub printKoGenes {
    my $taxon_oid = param("taxon_oid");
    $taxon_oid = sanitizeInt($taxon_oid);

    my $data_type = param("data_type");

    my @ko_ids = param("koid");
    if ( scalar(@ko_ids) <= 0 ) {
        @ko_ids = param("func_id");
    }
    if ( scalar(@ko_ids) == 0 ) {
        webError("No KO has been selected.");
    }

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    for my $id2 (@ko_ids) {
        print hiddenVar( "func_id", $id2 );
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my %funcId2Name;
    my %funcId2Def;
    TaxonDetailUtil::fetchKoid2NameDefHash( $dbh, \@ko_ids, \%funcId2Name, \%funcId2Def );

    print "<h1>KEGG Orthology (KO) Genes</h1>\n";
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    print "<p>";
    for my $ko_id (@ko_ids) {
        my $funcName = $funcId2Name{$ko_id};
        my $defn     = $funcId2Def{$ko_id};
        print $ko_id . ", <i><u>$funcName ($defn)</u></i><br/>\n";
    }
    print "</p>\n";

    #$dbh->disconnect();

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    $maxGeneListResults = 1000 if $maxGeneListResults eq "";
    my $trunc = 0;

    my $has_sdb   = 1;
    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        if ( !MetaUtil::hasSdbGeneProductFile( $taxon_oid, $t2 ) ) {
            $has_sdb = 0;
        }
    }

    my $it = new InnerTable( 1, "koGene$$", "koGene", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",    "asc", "left" );
    $it->addColSpec( "Assembled?", "asc", "left" );
    if ($has_sdb) {
        $it->addColSpec( "Gene Name", "asc", "left" );
    }
    $it->addColSpec( "KO ID",      "asc", "left" );
    $it->addColSpec( "Definition", "asc", "left" );

    my $select_id_name = "gene_oid";

    my $line       = "";
    my $gene_count = 0;

    for my $ko_id (@ko_ids) {
        if ($trunc) {
            last;
        }
        my $ko_def = $funcId2Def{$ko_id};

        for my $t2 (@type_list) {
            if ($trunc) {
                last;
            }

            # my $total_gene_cnt = MetaUtil::getGenomeStats($taxon_oid, $t2, "Genes total number");
            # if ( ! $total_gene_cnt ) {
            #     $total_gene_cnt = MetaUtil::getGenomeStats($taxon_oid, $t2, "Protein coding genes") +
            #         MetaUtil::getGenomeStats($taxon_oid, $t2, "rRNA genes") +
            #         MetaUtil::getGenomeStats($taxon_oid, $t2, "tRNA genes");
            # }

            my ( $ko_id1, $ko_id2 ) = split( /\:/, $ko_id );
            $ko_id2 = sanitizeKoId($ko_id2);

            my %h = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, "ko", \@ko_ids );
            if ( scalar( keys %h ) > 0 ) {
                my @gene_list = split( /\t/, $h{$ko_id} );
                for my $gene_oid (@gene_list) {
                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&data_type=$t2" . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";
                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }
                    $r .= $ko_id . $sd . $ko_id . "\t";
                    $r .= $ko_def . $sd . $ko_def . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }

                if ( tied(%h) ) {
                    untie %h;
                }
            } else {
                my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/ko_genes.zip";
                if ( !( -e $file_name ) ) {
                    next;
                }

                WebUtil::unsetEnvPath();

                my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name KO:$ko_id2 ", 'KoGenes' );

                if ( !$fh ) {
                    next;
                }

                while ( $line = $fh->getline() ) {
                    chomp($line);
                    my ( $id2, $gene_oid ) = split( /\t/, $line );
                    if ( !$gene_oid ) {
                        $gene_oid = $id2;
                    }

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    my $r;
                    $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' " . "  /> \t";
                    my $url = "$main_cgi?section=MetaGeneDetail";
                    $url .= "&page=metaGeneDetail&data_type=$t2" . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
                    $r   .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r   .= $t2 . $sd . $t2 . "\t";

                    if ($has_sdb) {
                        my $gene_name = MetaUtil::getGeneProdName( $gene_oid, $taxon_oid, $t2 );
                        $r .= $gene_name . $sd . $gene_name . "\t";
                    }
                    $r .= $ko_id . $sd . $ko_id . "\t";
                    $r .= $ko_def . $sd . $ko_def . "\t";
                    $it->addRow($r);

                    $gene_count++;
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
                close $fh;
                WebUtil::resetEnvPath();
            }
        }    # end for t2
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();

        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_count gene(s) retrieved.", 2 );
    }

    print end_form();
}

sub printTc {
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid );

    print "<h1>Transport Classification</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
        select tf.tc_family_num, tf.tc_family_name, count(distinct g.gene_oid)
        from tc_family tf, gene_tc_families gtf, gene g
        where g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        and g.gene_oid = gtf.gene_oid
        and gtf.tc_family = tf.tc_family_num
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

    TaxonDetailUtil::print3ColGeneCountTable(
        'tc', \@rows,
        'Transporter Classification Family Number',
        'Transporter Classification Family Name', $section
    );

    printStatusLine( "$count Transporter Classification retrieved.", 2 );
    print end_form();
}

sub printTcGenes {
    my $taxon_oid  = param("taxon_oid");
    my $tc_fam_num = param("tcfamid");

    my $dbh = dbLogin();
    my $sql = qq{
        select tc_family_name
        from tc_family
        where tc_family_num = ?
    };
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );
    my $cur = execSql( $dbh, $sql, $verbose, $tc_fam_num );
    my ($name) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
        select distinct g.gene_oid
        from gene_tc_families gtf, gene g
        where g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        and g.gene_oid = gtf.gene_oid
        and gtf.tc_family = ?
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Transport Classification Genes<br/>$tc_fam_num - $name",
        1, $taxon_oid, $tc_fam_num );
}

sub printSwissProt {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    print "<h1>SwissProt Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    my $sql = qq{
        select distinct g.gene_oid
        from gene_swissprot_names gs, gene g
        where gs.gene_oid = g.gene_oid
        and g.taxon = $taxon_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
    };

    my $extrasql = qq{
        select distinct g.gene_oid, gs.product_name
        from gene_swissprot_names gs, gene g
        where gs.gene_oid = g.gene_oid
        and g.taxon = $taxon_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        __replace__
        order by g.gene_oid, gs.product_name
    };

    TaxonDetailUtil::printGeneListSectionSorting2( '', $sql, "", 1, "SwissProt Product Name", $extrasql );
}

sub printNoSwissProt {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
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
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Non-SwissProt Genes", "", $taxon_oid, $taxon_oid );
}

sub printSeed {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    print "<h1>SEED Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printTaxonName( $taxon_oid, $taxon_name );

    my $sql = qq{
        select distinct g.gene_oid
        from gene_seed_names gs, gene g
        where gs.gene_oid = g.gene_oid
        and g.taxon = $taxon_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
    };

    my $extrasql = qq{
        select distinct g.gene_oid, gs.product_name
        from gene_seed_names gs, gene g
        where gs.gene_oid = g.gene_oid
        and g.taxon = $taxon_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        __replace__
        order by g.gene_oid, gs.product_name
    };

    TaxonDetailUtil::printGeneListSectionSorting2( '', $sql, "", 1, "SEED Product Name", $extrasql );
}

sub printNoSeed {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
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
    };

    my @bindList = ( $taxon_oid, 'CDS', 'No', $taxon_oid, 'CDS', 'No' );
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Non-SEED Genes", "", @bindList );
}

############################################################################
# printProteinCodingGenes - Show list of protein coding genes.
############################################################################
sub printProteinCodingGenes {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    printMainForm();
    my $data_type_text = getDatatypeText($data_type);
    print "<h1>Protein Coding Genes $data_type_text</h1>\n";

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    $taxon_oid = sanitizeInt($taxon_oid);

    printStartWorkingDiv();
    print "<p>Retrieving gene information ...\n";

    my $it = new InnerTable( 1, "geneProdList$$", "geneProdList", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Lotus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Start Coord",       "asc", "right" );
    $it->addColSpec( "End Coord",         "asc", "right" );
    $it->addColSpec( "Strand",            "asc", "left" );
    $it->addColSpec( "Scaffold",          "asc", "left" );

    my $select_id_name = "gene_oid";
    my $gene_count     = 0;
    my $trunc          = 0;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        # read all gene prod names
        my %names = MetaUtil::getGeneProdNamesForTaxon( $taxon_oid, $t2 );

        my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
        my $max_cnt   = 0;
        if ( -e $hash_file ) {
            my $fh2 = newReadFileHandle($hash_file);
            if ( !$fh2 ) {
                next;
            }
            while ( my $line1 = $fh2->getline() ) {
                chomp($line1);

                my ( $a0, $a1, $a2, @a3 ) = split( /\,/, $line1 );
                if ( $a0 eq 'gene' && WebUtil::isInt($a2) ) {
                    $max_cnt = $a2;
                    last;
                }
            }
            close $fh2;
        }

        $max_cnt = sanitizeInt($max_cnt);

        for ( my $j = 1 ; $j <= $max_cnt ; $j++ ) {
            if ($trunc) {
                last;
            }

            my $zip_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/gene/gene_" . $j . ".zip";
            my $sdb_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/gene/gene_" . $j . ".sdb";

            if ( -e $sdb_name ) {
                my $dbh3 = WebUtil::sdbLogin($sdb_name)
                  or next;

                my $sql3 =
                    "select gene_oid, locus_type, locus_tag, product_name, "
                  . "start_coord, end_coord, strand, scaffold_oid "
                  . "from gene where locus_type = 'CDS'";
                my $sth = $dbh3->prepare($sql3);
                $sth->execute();
                for ( ; ; ) {
                    my ( $gene_oid, $locus_type, $locus_tag, $gene_name, $start_coord, $end_coord, $strand, $scaffold ) =
                      $sth->fetchrow();
                    last if !$gene_oid;

                    my $prod_name = $names{$gene_oid};
                    if ($prod_name) {
                        $gene_name = $prod_name;
                    }

                    # default to hypothetical protein
                    if ( !$gene_name ) {
                        $gene_name = "hypothetical protein";
                    }

                    my $url =
                        "$main_cgi?section=MetaGeneDetail"
                      . "&page=metaGeneDetail&data_type=$t2"
                      . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    my $r            = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
                    $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                    $r .= $locus_tag . $sd . $locus_tag . "\t";
                    $r .= $gene_name . $sd . $gene_name . "\t";
                    $r .= $start_coord . $sd . $start_coord . "\t";
                    $r .= $end_coord . $sd . $end_coord . "\t";
                    $r .= $strand . $sd . $strand . "\t";

                    my $s_url =
                        "$main_cgi?section=MetaDetail"
                      . "&page=metaScaffoldDetail&scaffold_oid=$scaffold"
                      . "&taxon_oid=$taxon_oid&data_type=$t2";
                    $r .= $scaffold . $sd . alink( $s_url, $scaffold ) . "\t";

                    $it->addRow($r);

                    $gene_count++;
                    if ( ( $gene_count % 10 ) == 0 ) {
                        print ".";
                    }
                    if ( ( $gene_count % 1800 ) == 0 ) {
                        print "<br/>";
                    }
                    if ( $gene_count >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }    # end for
                $sth->finish();
                $dbh3->disconnect();

                next;
            }

            if ( !( -e $zip_name ) ) {
                next;
            }

            WebUtil::unsetEnvPath();

            my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name ", 'geneInfo' );
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                if ($trunc) {
                    last;
                }
                chomp($line);
                my ( $gene_oid, $locus_type, $locus_tag, $gene_name, $start_coord, $end_coord, $strand, $scaffold ) =
                  split( /\t/, $line );
                if ( $locus_type ne 'CDS' ) {
                    next;
                }

                my $prod_name = $names{$gene_oid};
                if ($prod_name) {
                    $gene_name = $prod_name;
                }

                # default to hypothetical protein
                if ( !$gene_name ) {
                    $gene_name = "hypothetical protein";
                }

                my $url =
                    "$main_cgi?section=MetaGeneDetail"
                  . "&page=metaGeneDetail&data_type=$t2"
                  . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
                my $workspace_id = "$taxon_oid $t2 $gene_oid";
                my $r            = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
                $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
                $r .= $locus_tag . $sd . $locus_tag . "\t";
                $r .= $gene_name . $sd . $gene_name . "\t";
                $r .= $start_coord . $sd . $start_coord . "\t";
                $r .= $end_coord . $sd . $end_coord . "\t";
                $r .= $strand . $sd . $strand . "\t";

                my $s_url =
                    "$main_cgi?section=MetaDetail"
                  . "&page=metaScaffoldDetail&scaffold_oid=$scaffold"
                  . "&taxon_oid=$taxon_oid&data_type=$t2";
                $r .= $scaffold . $sd . alink( $s_url, $scaffold ) . "\t";

                $it->addRow($r);

                $gene_count++;
                if ( ( $gene_count % 10 ) == 0 ) {
                    print ".";
                }
                if ( ( $gene_count % 1800 ) == 0 ) {
                    print "<br/>";
                }
                if ( $gene_count >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }
            }
            close $fh;
            WebUtil::resetEnvPath();
        }    # end for j

    }    # end for t2

    printEndWorkingDiv();

    if ( $gene_count == 0 ) {
        print end_form();
        webError("No genes.");
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace_withAllCDSGeneList($select_id_name);
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
# printPseudoGenes - Show list of pseudo genes.
############################################################################
sub printPseudoGenes {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
      select distinct g0.gene_oid, g0.gene_display_name
      from gene g0
      where g0.taxon = ?
      and( g0.is_pseudogene = 'Yes'
         or g0.img_orf_type like '%pseudo%'
         or g0.locus_type = 'pseudo' )
      and g0.obsolete_flag = 'No'
      order by g0.gene_display_name
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Pseudo Genes", "", $taxon_oid );
}

############################################################################
# printDubiousGenes - Show list of dubious orfs.
############################################################################
sub printDubiousGenes {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
      select distinct g0.gene_oid, g0.gene_display_name
      from gene g0
      where g0.taxon = ?
      and g0.is_dubious_orf = 'Yes'
      and g0.obsolete_flag = 'No'
      order by g0.gene_display_name
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Dubious ORF's", "", $taxon_oid );
}

############################################################################
# printGenesWithFunc - Show genes with function.
############################################################################
sub printGenesWithFunc {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    printMainForm();
    my $data_type_text = getDatatypeText($data_type);
    print "<h1>Genes with Function Prediction $data_type_text</h1>\n";

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    $taxon_oid = sanitizeInt($taxon_oid);

    my $it = new InnerTable( 1, "geneProdList$$", "geneProdList", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );

    my $select_id_name = "gene_oid";

    my $gene_count = 0;
    my $trunc      = 0;
    my $max_count  = $maxGeneListResults + 1;

    my @type_list = MetaUtil::getDataTypeList($data_type);
    for my $t2 (@type_list) {
        if ($trunc) {
            last;
        }

        # read all gene prod names
        my %names = MetaUtil::getGeneProdNamesForTaxon( $taxon_oid, $t2, $max_count );
        foreach my $gene_oid ( keys %names ) {
            if ($trunc) {
                last;
            }

            my $gene_name = $names{$gene_oid};
            my $url       =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&data_type=$t2"
              . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
            my $workspace_id = "$taxon_oid $t2 $gene_oid";
            my $r            = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
            $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
            $r .= $gene_name . $sd . $gene_name . "\t";

            $it->addRow($r);

            $gene_count++;
            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
    }    # end for t2

    if ( $gene_count == 0 ) {
        print end_form();
        webError("No genes.");
    }

    WebUtil::printGeneCartFooter() if $gene_count > 10;
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace_withAllGeneProdList($select_id_name);
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
# printGenesWithoutFunc - Show genes with function.
############################################################################
sub printGenesWithoutFunc {
    my $taxon_oid = param("taxon_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
      select distinct g0.gene_oid, g0.gene_display_name
      from gene g0
      where g0.taxon = ?
      and g0.locus_type = 'CDS'
      and g0.obsolete_flag = 'No'
      and ( lower( g0.gene_display_name ) like '%hypothetical%' or
          lower( g0.gene_display_name ) like '%unknown%' or
          lower( g0.gene_display_name ) like '%unnamed%' or
          lower( g0.gene_display_name ) like '%predicted protein%' or
          g0.gene_display_name is null )
      order by g0.gene_display_name
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Genes without Function Prediction", "", $taxon_oid );
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
    checkTaxonPerm( $dbh, $taxon_oid );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    ## --es 01/31/2007 CDS and RNA genes included.
    ## Amy: MyIMG annotation is now stored in Gene_MyIMG_functions

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    my $cclause;
    $cclause =
"and (c.contact_oid = ? or (c.img_group is not null and c.img_group = (select c2.img_group from contact c2 where c2.contact_oid = ?)))"
      if $contact_oid > 0 && $super_user ne "Yes";
    my $sql = qq{
       select g.gene_oid, ann.product_name, c.username
           from gene g, gene_myimg_functions ann, contact c
           where g.gene_oid = ann.gene_oid
           and g.obsolete_flag = ?
           and g.taxon = ?
           and ann.modified_by = c.contact_oid
           $cclause
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
#    printFromGeneOids( \@gene_oids, "Genes w/o Function, w/ Similarity." );
#}

############################################################################
# getNoFuncGenes - Get genes w/o function.
############################################################################
#sub getNoFuncGenes {
#    my ( $taxon_oid, $similarity ) = @_;
#    my $dbh = dbLogin();
#    checkTaxonPerm( $dbh, $taxon_oid );
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

    my $sql = qq{
        select distinct g.gene_oid
        from gene g
        where g.obsolete_flag = 'Yes'
        and g.taxon = ?
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Obsolete Genes", "", $taxon_oid );
}

############################################################################
# printGenomeProteomics - Print genes that have associated proteomic data
############################################################################
sub printGenomeProteomics {
    my $taxon_oid = param("taxon_oid");

    my $sql = qq{
        select distinct pig.gene
        from ms_protein_img_genes pig
        where pig.protein_oid > 0
        and pig.genome = ?
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Genes with Proteomics Data", "", $taxon_oid );
}

############################################################################
# printSnpGenes - Print genes that have SNP
############################################################################
sub printSnpGenes {
    my $has_snp = $snp_enabled;
    if ( !$has_snp ) {
        return;
    }

    my $contact_oid = getContactOid();
    my $super_user  = 'No';
    if ($contact_oid) {
        $super_user = getSuperUser();
    }

    my $taxon_oid = param("taxon_oid");

    my $sql = qq{
        select distinct snp.gene_oid
        from gene_snp snp
        where snp.taxon = ?
    };

    if ( !$contact_oid ) {
        $sql .= " and snp.experiment in (select exp_oid from snp_experiment " . " where is_public = 'Yes')";
    } elsif ( $super_user ne 'Yes' ) {
        $sql .=
            " and (snp.experiment in (select exp_oid from snp_experiment "
          . " where is_public = 'Yes') or snp.experiment in "
          . " (select snp_exp_permissions from contact_snp_exp_permissions "
          . "where contact_oid = $contact_oid))";
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

    my $dbh = dbLogin();
    my $sql = qq{
        select g.img_orf_type, iot.definition, count( distinct g.gene_oid )
        from gene g, img_orf_type iot
        where g.taxon = ?
        and g.img_orf_type is not null
        and g.img_orf_type = iot.orf_type
        and g.obsolete_flag = 'No'
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
# printImgOrfTypeGenes - Show genes belonging to an IMG ORF type.
############################################################################
sub printImgOrfTypeGenes {
    my $taxon_oid    = param("taxon_oid");
    my $img_orf_type = param("img_orf_type");

    my $sql = qq{
       select distinct g.gene_oid
       from gene g, img_orf_type iot
       where g.taxon = ?
       and g.obsolete_flag = 'No'
       and g.img_orf_type = ?
       and g.img_orf_type = iot.orf_type
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Revised Genes ($img_orf_type)", "", $taxon_oid, $img_orf_type );
}

############################################################################
# printFusionComponents - Print genes involved as fusion components.
############################################################################
sub printFusionComponents {
    my $taxon_oid = param("taxon_oid");
    my $sql       = qq{
        select distinct g.gene_oid
        from gene g, gene_all_fusion_components gfc
        where g.gene_oid = gfc.component
        and g.obsolete_flag = 'No'
        and g.taxon = ?
        order by g.gene_oid
    };
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "Fusion Components", "", $taxon_oid );
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
    my $dbh = dbLogin();

    #my %geneEnzymes;
    #my $sql = qq{
    #    select g.gene_oid, ge.enzymes
    #    from gene g, gene_ko_enzymes ge
    #    where g.obsolete_flag = 'No'
    #    and g.img_orf_type is not null
    #    and g.gene_oid = ge.gene_oid
    #    and g.taxon = ?
    #};
    #my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    #for ( ; ; ) {
    #    my ( $gene_oid, $enzyme ) = $cur->fetchrow();
    #    last if !$gene_oid;
    #    $geneEnzymes{$gene_oid} .= "$enzyme,";
    #}
    #$cur->finish();

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.img_orf_type
        from gene g
        where g.obsolete_flag = 'No'
        and g.img_orf_type is not null
        and g.taxon = ?
        order by g.gene_oid
    };
    my @binds = ($taxon_oid);

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    printMainForm();
    print "<p>\n";
    printGeneCartFooter();

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
    printGeneCartFooter();
    print end_form();

    #$dbh->disconnect();
    if ($trunc) {
        printTruncatedStatus($maxGeneListResults);
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
}

############################################################################
# downloadFastaFile - Download FASTA file.  ??????
############################################################################
sub downloadFastaFile {
    my ( $taxon_oid, $dir, $fileExt ) = @_;

    timeout( 60 * 180 );    # 3 hours

    my $dbh = dbLogin();
    checkTaxonPermHeader( $dbh, $taxon_oid );

    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    print "Content-type: text/plain\n";
    print "Content-Disposition: inline; filename=$taxon_oid.$fileExt\n";

    #    print "Content-length: 10000000\n";
    print "\n";

    my $t2 = 'assembled';

    my @keys = ();
    my ( $trunc, @lines ) = MetaUtil::getScaffoldStatsForTaxon( $taxon_oid, $t2 );
    for my $line (@lines) {
        my ( $scaf_oid, $seq_len, $gc_percent, $gene_cnt ) = split( /\t/, $line );
        if ( $seq_len > 0 ) {
            push( @keys, $scaf_oid );
        }
    }

    my $i = 0;
    for my $s2 ( sort @keys ) {
        print ">$taxon_oid $s2 $taxon_name : $s2\n";

        my $seq = MetaUtil::getScaffoldFna( $taxon_oid, $t2, $s2 );
        my $seq2 = wrapSeq($seq);
        print "$seq2\n";
    }
}

sub downloadTaxonFaaFile {
    my $taxon_oid = param("taxon_oid");

    timeout( 60 * 180 );    # 3 hours

    my $dbh = dbLogin();
    checkTaxonPermHeader( $dbh, $taxon_oid );

    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    my $fileExt = "faa";

    print "Content-type: text/plain\n";
    print "Content-Disposition: inline; filename=$taxon_oid.$fileExt\n";

    #    print "Content-length: 10000000\n";
    print "\n";

    $taxon_oid = sanitizeInt($taxon_oid);

}

sub downloadTaxonAltFaaFile {
    my $taxon_oid = param("taxon_oid");
    downloadFastaFile( $taxon_oid, $taxon_alt_faa_dir, "alt.faa" );
}

sub downloadTaxonFnaFile {
    my $taxon_oid = param("taxon_oid");

    ### ???
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
# downloadTaxonGenesFile - Download genes file for all orfs of this
#   genome.
############################################################################
sub downloadTaxonGenesFile {
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    timeout( 60 * 180 );    # 3 hours

    $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();
    checkTaxonPermHeader( $dbh, $taxon_oid );

    #$dbh->disconnect();
    my $path = "$genes_dir/$taxon_oid.genes.xls";
    my $sz   = fileSize($path);

    #print "Content-type: text/plain\n";
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: inline; filename=$taxon_oid.genes.xls\n";
    print "\n";

    print "gene_oid\tStart Coord\tEnd Coord\tStrand\tLocus Tag\tDescription\tScaffold\n";

    if ( $data_type eq 'assembled' || $data_type eq 'both' ) {

        # download assembled
        my @keys = ();
        my ( $trunc, @lines ) = MetaUtil::getScaffoldStatsForTaxon( $taxon_oid, 'assembled' );
        for my $line (@lines) {
            my ( $scaf_oid, $seq_len, $gc_percent, $gene_cnt ) = split( /\t/, $line );
            if ( $seq_len > 0 ) {
                push( @keys, $scaf_oid );
            }
        }

        for my $s2 ( sort @keys ) {
            my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, 'assembled', $s2 );
            for my $g (@genes_on_s) {
                my (
                    $gene_oid,  $locus_type, $locus_tag, $gene_display_name, $start_coord,
                    $end_coord, $strand,     $seq_id,    $source
                  )
                  = split( /\t/, $g );
                print "$gene_oid\t$start_coord\t$end_coord\t$strand\t$locus_tag\t$gene_display_name\t$s2\n";
            }    # end for g
        }    # end for s2

    }

    if ( $data_type eq 'unassembled' || $data_type eq 'both' ) {

        # download unassembled
    }

    WebUtil::webExit(0);
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
        webErrorHeader( "Session of information download has expired. Please start again." );
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

    my $sql = qq{
        select count(*)
        from scaffold
        where taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($scaffold_count) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
       select scf.scaffold_oid, scf.ext_accession,
              scf.scaffold_name, ss.seq_length
       from scaffold scf, scaffold_stats ss
       where scf.taxon = ?
       and scf.scaffold_oid = ss.scaffold_oid
       order by ss.seq_length desc, scf.ext_accession
    };

    GenerateArtemisFile::printGenerateForm( $dbh, $sql, $taxon_oid, '', '', $scaffold_count );

}

############################################################################
# printTaxonExtLinks - Print external links information.
############################################################################
sub printTaxonExtLinks {
    my ( $dbh, $taxon_oid ) = @_;

    print "<tr class='img'>\n";
    print "<th class='subhead'>External Links</th>\n";

    my $sql = qq{
        select distinct db_name, id, custom_url
        from taxon_ext_links
        where taxon_oid = ?
        order by db_name, id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    print "<td class='img'>\n";
    my $count = 0;
    my $s;
    my $jgi_portal_url_str;
    for ( ; ; ) {
        my ( $db_name, $id, $custom_url ) = $cur->fetchrow();
        last if !$id;
        my $dbId = "$db_name:$id";
        if ( $db_name eq "PUBMED" && $pubmed_base_url ne "" ) {
            my $url = "$pubmed_base_url$id";
            $s .= alink( $url, "$dbId" );
        } elsif ( ( $db_name =~ /NCBI/ || $db_name =~ /RefSeq/ )
            && $ncbi_entrez_base_url ne "" )
        {
            my $url = "$ncbi_entrez_base_url$id";
            $s .= alink( $url, "$dbId" );
        } elsif ( $db_name eq "JGI Portal" && $custom_url ne '' ) {

            # icon
            my $icon_url =
              "<img style='border:none; vertical-align:text-top;' src='$base_url/images/genomeProjects_icon.gif' />";
            my $url = "$custom_url";
            $jgi_portal_url_str = alink( $url, "$icon_url JGI Portal", "", 1 );
            $s .= $jgi_portal_url_str;

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
    print "$s\n";
    $cur->finish();
    print nbsp(1) if $count == 0;
    print "</td>\n";
    print "</tr>\n";

    # return the html code to jgi portal
    return $jgi_portal_url_str;
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
        select uga.old_gene_oid, uga.locus_tag, uga.gene_display_name,
           uga.taxon_name
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
# printMetaScaffoldDetail: scaffold detail (from file)
#   Inputs:
#     scaffold_oid - scaffold object identifier
############################################################################
sub printMetaScaffoldDetail {
    my $scaffold_oid = param("scaffold_oid");
    my $taxon_oid    = param("taxon_oid");
    my $data_type    = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Scaffold Detail</h1>\n";
    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    my $workspace_id = "$taxon_oid $data_type $scaffold_oid";
    print hiddenVar( "scaffold_oid", $workspace_id );

    my ( $scf_seq_len, $scf_gc, $scf_gene_cnt ) = MetaUtil::getScaffoldStats( $taxon_oid, $data_type, $scaffold_oid );

    print "<p>\n";    # paragraph section puts text in proper font.
    print "<table class='img' border='1'>\n";
    printAttrRow( "Scaffold ID", $scaffold_oid );

    # taxon
    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    $taxon_name = HtmlUtil::appendMetaTaxonNameWithDataType( $taxon_name, $data_type );
    my $url = "$main_cgi?section=MetaDetail" . "&page=metaDetail&taxon_oid=$taxon_oid";
    printAttrRowRaw( "Genome", alink( $url, $taxon_name ) );

    printAttrRow( "Topology",             "linear" );
    printAttrRow( "Sequence Length (bp)", $scf_seq_len );

    #printAttrRow( "GC Content", sprintf( "%.2f%%", $scf_gc ) );
    printAttrRow( "GC Content", $scf_gc );

    if ( $data_type ne 'unassembled' ) {
        my ($scaf_depth) = MetaUtil::getScaffoldDepth( $taxon_oid, $data_type, $scaffold_oid );
        printAttrRow( "Read Depth", "$scaf_depth" );

        my ( $lineage, $percentage, $rank ) = MetaUtil::getScaffoldLineage( $taxon_oid, $data_type, $scaffold_oid );
        if ($lineage) {
            printAttrRow( "Lineage",            "$lineage" );
            printAttrRow( "Lineage Percentage", "$percentage" );
        }
    }

    if ($scf_gene_cnt) {
        my $g_url = "$main_cgi?section=MetaDetail&page=metaScaffoldGenes";
        $g_url .= "&taxon_oid=$taxon_oid&scaffold_oid=$scaffold_oid";
        printAttrRowRaw( "Gene Count", alink( $g_url, $scf_gene_cnt ) );
    } else {
        printAttrRowRaw( "Gene Count", $scf_gene_cnt );
    }
    print "</table>\n";

    if ( $data_type ne 'unassembled' ) {
        my $name = "_section_ScaffoldCart_addToScaffoldCart";
        print submit(
            -name  => $name,
            -value => "Add to Scaffold Cart",
            -class => "meddefbutton",
        );
    }
    print "</p>\n";

    if ( $scf_seq_len > 0 ) {
        print "<h2>User Selectable Coordinate Ranges</h2>\n";

        my $range = "1\.\.$scf_seq_len";
        my $url3  = "$main_cgi?section=MetaScaffoldGraph&page=metaScaffoldGraph";
        $url3 .= "&taxon_oid=$taxon_oid&data_type=$data_type&scaffold_oid=$scaffold_oid";
        $url3 .= "&start_coord=1&end_coord=$scf_seq_len";
        print alink( $url3, $range ) . "<br/>\n";
    }

    if ($scf_gene_cnt) {
        print hiddenVar( "scaffold_oid", "$taxon_oid $data_type $scaffold_oid" );
        PhyloUtil::printPhylogeneticDistributionSection( 0, 1 );
    } else {
        print hiddenVar( "scaffold_oid", $scaffold_oid );
    }

    print end_form();
}

############################################################################
# printMetaScaffoldGenes: scaffold genes (from file)
#   Inputs:
#     scaffold_oid - scaffold object identifier
############################################################################
sub printMetaScaffoldGenes {
    my $scaffold_oid = param("scaffold_oid");
    my $taxon_oid    = param("taxon_oid");
    my $data_type    = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    print "<h1>Genes in Scaffold</h1>\n";
    print hiddenVar( "scaffold_oid", $scaffold_oid );
    print hiddenVar( "taxon_oid",    $taxon_oid );
    print hiddenVar( "data_type",    $data_type );

    # get taxon name from database
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid, 1 );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type, 1 );

    my $scf_url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail"
	. "&scaffold_oid=$scaffold_oid&taxon_oid=$taxon_oid&data_type=$data_type";
    print "<br/>Scaffold: " . alink( $scf_url, $scaffold_oid ) . "</p>\n";

    printStartWorkingDiv();
    print "<p>Retrieving gene information ...<br/>\n";

    my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "left" );
    $it->addColSpec( "Locus Type",        "asc", "left" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Start Coord",       "asc", "right" );
    $it->addColSpec( "End Coord",         "asc", "right" );
    $it->addColSpec( "Strand",            "asc", "left" );

    my $select_id_name = "gene_oid";

    my $gene_count = 0;
    my $trunc      = 0;
    for my $g (@genes_on_s) {
        my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
          split( /\t/, $g );

        my $workspace_id = "$taxon_oid assembled $gene_oid";
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$workspace_id' />" . "\t";
        my $url =
            "$main_cgi?section=MetaGeneDetail"
          . "&page=metaGeneDetail&taxon_oid=$taxon_oid"
          . "&data_type=assembled&gene_oid=$gene_oid";
        $r .= $workspace_id . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= $locus_type . $sd . $locus_type . "\t";
        $r .= $locus_tag . $sd . $locus_tag . "\t";

        if ( !$gene_display_name ) {
            my ( $gene_prod_name, $prod_src ) = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
            $gene_display_name = $gene_prod_name;
        }
        $r .= $gene_display_name . $sd . $gene_display_name . "\t";
        $r .= $start_coord . $sd . $start_coord . "\t";
        $r .= $end_coord . $sd . $end_coord . "\t";
        $r .= $strand . $sd . $strand . "\t";

        $it->addRow($r);
        $gene_count++;
        print ".";
        if ( ( $gene_count % 180 ) == 0 ) {
            print "<br/>\n";
        }
        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }

    printEndWorkingDiv();

    if ( $gene_count == 0 ) {
        printStatusLine( "$gene_count gene(s) loaded", 2 );
        print end_form();
        return;
    }

    if ($gene_count) {
        WebUtil::printGeneCartFooter() if $gene_count > 10;
        $it->printOuterTable(1);
        WebUtil::printGeneCartFooter();

        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace_withAllMetaScafGenes($select_id_name);
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
# printTaxonGenomeProp - Show genome properties for taxon.
#     --es 10/18/2007
############################################################################
sub printTaxonGenomeProp {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my %asserted;
    getAssertedGenomeProperties( $dbh, $taxon_oid, \%asserted );

    my $sql = qq{
       select gp.prop_accession, gp.name prop_name, count( gxf.gene_oid ) gcount
       from gene_xref_families gxf, genome_property gp,
          property_step ps, property_step_evidences pse, gene g
       where gxf.gene_oid = g.gene_oid
       and g.taxon = ?
       and gxf.id = pse.query
       and pse.step_accession = ps.step_accession
       and ps.genome_property = gp.prop_accession
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
# getFuncNames
############################################################################
sub getFuncNames {
    my ($func_type) = @_;

    my %func_names;
    my $sql = "";

    if ( $func_type eq 'cog' ) {
        $sql = "select cog_id, cog_name from cog";
    } elsif ( $func_type eq 'pfam' ) {
        $sql = "select ext_accession, description from pfam_family";
    } elsif ( $func_type eq 'tigr' || $func_type eq 'tigrfam' ) {
        $sql = "select ext_accession, expanded_name from tigrfam";
    } elsif ( $func_type eq 'ec' || $func_type eq 'enzyme' ) {
        $sql = "select ec_number, enzyme_name from enzyme";
    } elsif ( $func_type eq 'ko' ) {
        $sql = "select ko_id, definition, ko_name from ko_term";
    } else {
        return %func_names;
    }

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name, $other_name ) = $cur->fetchrow();
        if ($name) {
            $func_names{$id} = $name;
        } elsif ($other_name) {
            $func_names{$id} = $other_name;
        } else {
            $func_names{$id} = $id;
        }
        last if !$id;
    }
    $cur->finish();

    #$dbh->disconnect();

    return %func_names;
}

############################################################################
# printGenomePropGeneList - Show genes under one IMG pathway.
############################################################################
sub printGenomePropGeneList {
    my $taxon_oid      = param("taxon_oid");
    my $prop_accession = param("prop_accession");

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

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
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );

    printStatusLine( "Loading ...", 1 );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) = getTaxonPhylaInfo( $dbh, $taxon_oid );

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

    my $sql = qq{
        select hth.phylo_level, hth.phylo_val, g.gene_oid
        from gene g, dt_ht_hits hth
        where g.gene_oid = hth.gene_oid
        and g.taxon = ?
        and hth.rev_gene_oid is not null
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

sub getTaxonPhylaInfo {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select t.domain, t.phylum, t.ir_class, t.ir_order, t.family,
        t.genus, t.species
        from taxon t
        where t.taxon_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) = $cur->fetchrow();

    $cur->finish();

    return ( $domain, $phylum, $class, $order, $family, $genus, $species );
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
    print "<td class='$classStr'>";
    print "<div class='yui-dt-liner'>";
    if ( $querylabel ne "" ) {
        print "<b>$label ($querylabel)</b>\n";
    } else {
        print "<b>$label </b>\n";
    }
    print "</div>\n";
    print "</td>\n";

    print "<td class='$classStr'>";
    print "<div class='yui-dt-liner'>";
    print nbsp(1);
    print "</div>\n";
    print "</td>\n";

    print "<td class='$classStr'>";
    print "<div class='yui-dt-liner'>";
    print nbsp(1);
    print "</div>\n";
    print "</td>\n";
    print "</tr>\n";

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

    my $sql = qq{
        select distinct g.gene_oid
        from gene g, dt_ht_hits hth
        where g.gene_oid = hth.gene_oid
        and g.taxon = ?
        and g.obsolete_flag = 'No'
        and hth.phylo_level = ?
        and hth.rev_gene_oid is not null
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
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );

    print qq{
     <h1>
     Genes in $taxon_name<br/>
     with Best Hits to Genes from $phylo_val </h1>
    };

    printMainForm();

    my $clobberCache = 1;
    my $it           = new InnerTable( $clobberCache, "ht_hits$$", "ht_hits", 1 );
    my $sd           = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",          "asc", "left" );
    $it->addColSpec( "Product Name",     "asc", "left" );
    $it->addColSpec( "From<br/>Gene",    "asc", "left" );
    $it->addColSpec( "From<br/>Product", "asc", "left" );
    $it->addColSpec( "From<br/>Genome",  "asc", "left" );

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

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

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
### This subroutine is likely OBSOLETE, as the table "gene_with_similarity"does not exist.
sub printImgTermsSimilarity() {
    my $taxon_oid = param("taxon_oid");
    my $dbh       = dbLogin();
    printStatusLine( "Loading ...", 1 );

    # see CompareGenomes::getSimilarityCount();
    # on why i use minus
    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene g
        where g.taxon = ?
        and g.gene_oid in(
            select gs.gene_oid
            from gene_with_similarity gs
            where gs.taxon = ?
            minus
            select gf2.gene_oid
            from gmv_ene_img_functions gf2, gene_with_similarity gs2
            where gf2.gene_oid = gs2.gene_oid
            and gs2.taxon = ?)
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
    WebUtil::printGeneCartFooter();

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome ID",         "asc", "right" );
    $it->addColSpec( "Genome Name",       "asc", "left" );
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
    $it->printOuterTable(1);
    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    WebUtil::printGeneCartFooter() if $count > 10;

    print "</p>\n";
    $cur->finish();

    print end_form();
}

############################################################################
# hasNuclotideData - Has DNA sequence data.  This is to avoid showing
#   the download links for proxy gene data.
############################################################################
sub hasNucleotideData {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select total_gatc
        from taxon_stats
        where taxon_oid = ?
    };
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
    my $sql = qq{
    select count(distinct pangenome_composition)
    from taxon_pangenome_composition
    where taxon_oid = ?
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
    my $sql = qq{
        select distinct pangenome_composition
        from taxon_pangenome_composition
        where taxon_oid = ?
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

    checkTaxonPerm( $dbh, $taxon_oid );

    my $sql = qq{
       select taxon_oid
       from dt_phylum_dist_genes
       where taxon_oid = ?
       and rownum < 2
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

############################################################################
# scaffoldsLengthBreakDown - Show scaffolds with one value of length.
#   Drill down from above distribution of scaffolds.
############################################################################
sub scaffoldsLengthBreakDown {
    my $taxon_oid  = param("taxon_oid");
    my $scf_length = param("scf_length");
    my $chart      = param("chart");
    my $study      = param("study");
    my $sample     = param("sample");
    my $data_type  = param("data_type");
    if ( !$data_type ) {
        $data_type = 'assembled';
    }

    # if this is invoked by the bar chart, then pre-process URL
    if ( $chart eq "y" ) {
        my $category = param("category");
        $category =~ s/\.\./-/g;
        $scf_length = $category;
    }

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    printMainForm();

    my $lower = param('lower');
    my $upper = param('upper');
    my ( $minlength, $maxlength ) = split( "-", $scf_length );
    if ( !WebUtil::isInt($minlength) || !WebUtil::isInt($maxlength) ) {
        webError("Incorrect scaffold length: $scf_length.");
        return;
    }
    if ( !$lower || !WebUtil::isInt($lower) ) {
        $lower = $minlength;
    }
    if ( !$upper || !WebUtil::isInt($upper) ) {
        $upper = $maxlength;
    }
    if ( $lower < $minlength || $upper > $maxlength ) {
        webError("Incorrect range: $lower .. $upper.");
        return;
    }

    # decide break down range
    my $range = param('range');
    if ( !$range ) {
        $range = 1000;
    }
    if ( !WebUtil::isInt($range) ) {
        webError("Incorrect scaffold display range: $range.");
        return;
    }
    if ( $range > ( $upper - $lower ) ) {
        $range /= 10;
    }
    if ( !$range || $range < 1 ) {
        $range = 1;
    }

    my $subtitle = "Scaffolds having genes with length between $lower-$upper";
    print "<h1>$subtitle</h1>\n";

    print hiddenVar( 'taxon_oid',  $taxon_oid );
    print hiddenVar( 'data_type',  $data_type );
    print hiddenVar( 'dist_type',  'seq_length' );
    print hiddenVar( 'scf_length', $scf_length );

    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
    HtmlUtil::printMetaTaxonName( $taxon_oid, $taxon_name, $data_type );

    printStatusLine( "Loading ...", 1 );

    # get scaffold detail from file
    my ( $trunc, $rows_ref, $scafs_ref ) =
      MetaUtil::getScaffoldStatsInLengthRange( $taxon_oid, 'assembled', $minlength, $maxlength );

    my $count = 0;
    my %scf_len_h;
    for my $line (@$rows_ref) {
        my ( $scaffold_oid, $seq_length, $gc, $gene_cnt ) =
          split( /\t/, $line );
        if ( $seq_length < $lower || $seq_length > $upper ) {
            next;
        }

        my $bucket = ceil( $seq_length / $range );
        if ( $scf_len_h{$bucket} ) {
            $scf_len_h{$bucket} += 1;
        } else {
            $scf_len_h{$bucket} = 1;
        }

        $count++;
    }    # end while

    printStatusLine( "$count Loaded.", 2 );

    print "<p>\n";
    for my $key ( sort { $a <=> $b } ( keys %scf_len_h ) ) {
        my $n1 = $range * ( $key - 1 ) + 1;
        if ( $n1 < $lower ) {
            $n1 = $lower;
        }
        my $n2 = $range * $key;
        if ( $n2 > $upper ) {
            $n2 = $upper;
        }

        my $urlfrag = "";
        if ( $study && $study ne "" ) {
            $urlfrag = "&sample=$sample&study=$study";
        }
        my $url2 =
            "$section_cgi&page=scaffoldsByLengthCount"
          . "&taxon_oid=$taxon_oid&scf_length=$minlength-$maxlength"
          . "&lower=$n1&upper=$n2"
          . $urlfrag;
        if ( $n2 > $n1 && $scf_len_h{$key} > 1000 ) {
            my $range2 = $range / 10;
            if ( $range2 < 1 ) {
                $range2 = 1;
            }
            $url2 =
                "$section_cgi&page=scaffoldsLengthBreakDown"
              . "&taxon_oid=$taxon_oid"
              . "&scf_length=$minlength-$maxlength"
              . "&lower=$n1&upper=$n2&range=$range2"
              . $urlfrag;
        }

        print "<input type='checkbox' name='seq_length' " . "value='$n1:$n2' />" . "\t";
        if ( $n1 == $n2 ) {
            print "Scaffold length = $n1 (";
        } else {
            print "Scaffold length between $n1 .. $n2 (";
        }
        print alink( $url2, $scf_len_h{$key} ) . ")<br/>\n";
    }

    print "<p>\n";

    #  This doesn't work properly here.
    # A new subroutine for adding a group of scaffolds is needed.
    #WebUtil::printScaffoldCartrFooter();
    WebUtil::printButtonFooter();

    WorkspaceUtil::printSaveScaffoldLengthRangeToWorkspace('seq_length');

    print end_form();
}

sub getDatatypeText {
    my ($data_type) = @_;

    my $data_type_text;
    if ($data_type) {
        $data_type_text = "($data_type)";
    }
    return $data_type_text;
}

1;

