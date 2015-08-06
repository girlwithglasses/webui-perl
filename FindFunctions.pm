############################################################################
# FindFunctions.pm - Formerly geneSearch.pl
#  Some abbreviations for functions:
#  "Ffg" - "Find Function Genes" - Shows functions with gene count.
#  "Ffo" - "Find Function Genomes" - Shows functions with genome count.
#  These were used in the days before this code was placed in Perl modules.
#    --es 07/07/2005
#
# $Id: FindFunctions.pm 33902 2015-08-05 01:24:06Z jinghuahuang $
############################################################################
package FindFunctions;
my $section = "FindFunctions";

use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use ScaffoldPanel;
use CachedTable;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use GeneDetail;
use InnerTable;
use MetaUtil;
use MerFsUtil;
use Data::Dumper;
use FuncUtil;
use WorkspaceUtil;
use GenomeListJSON;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $base_url              = $env->{base_url};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $base_dir              = $env->{base_dir};
my $img_internal          = $env->{img_internal};
my $show_private          = $env->{show_private};
my $tmp_dir               = $env->{tmp_dir};
my $web_data_dir          = $env->{web_data_dir};
my $taxon_faa_dir         = "$web_data_dir/taxon.faa";
my $swiss_prot_base_url   = $env->{swiss_prot_base_url};
my $user_restricted_site  = $env->{user_restricted_site};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $include_metagenomes   = $env->{include_metagenomes};
my $include_img_terms     = $env->{include_img_terms};
my $go_base_url           = $env->{go_base_url};
my $cog_base_url          = $env->{cog_base_url};
my $kog_base_url          = $env->{kog_base_url};
my $pfam_base_url         = $env->{pfam_base_url};
my $pfam_clan_base_url    = $env->{pfam_clan_base_url};
my $enzyme_base_url       = $env->{enzyme_base_url};
my $search_dir            = ''; # use search_dir "$web_data_dir/search" too slow;
my $tc_base_url           = "http://www.tcdb.org/search/result.php?tc=";
my $flank_length          = 25000;
my $max_gene_batch        = 100;
my $max_rows              = 1000;
my $max_seq_display       = 30;
my $grep_bin              = $env->{grep_bin};
my $rdbms                 = getRdbms();
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $cgi_url               = $env->{cgi_url};
my $max_prod_name         = 50;
my $max_genome_selection  = 50;
my $max_metagenome_selection = 50;
my $mer_data_dir          = $env->{mer_data_dir};
my $in_file               = $env->{in_file};
my $new_func_count        = $env->{new_func_count};
my $enable_biocluster     = $env->{enable_biocluster};
my $enable_interpro       = $env->{enable_interpro};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

# new for 2.8
my $kegg_tree_file       = $env->{kegg_tree_file};
my $kegg_brite_tree_file = $env->{kegg_brite_tree_file};
my $kegg_orthology_url   = $env->{kegg_orthology_url};
my $kegg_module_url      = $env->{kegg_module_url};

my %function2Name = (
      geneProduct           => "Gene Product Name",
      seedProduct           => "SEED Product Name/Subsystem",
      swissProduct          => "SwissProt Product Name",
      go                    => "GO",
      cog                   => "COG",
      kog                   => "KOG",
      pfam                  => "Pfam",
      tigrfam               => "TIGRfam",
      ipr                   => "InterPro",
      ec                    => "Enzyme",
      ec_ex                 => "EC Number",
      ec_iex                => "Enzyme",
      tc                    => "Transporter Classification",
      keggEnzymes           => "KEGG Pathway Enzymes",
      koid                  => "KEGG Orthology ID",
      koname                => "KEGG Orthology Name",
      kodefn                => "KEGG Orthology Definition",
      bc                    => "Biosynthetic Cluster",
      np                    => "Secondary Metabolite",
      metacyc               => "MetaCyc",
      img_cpd               => "IMG Compound",
      img_term_iex          => "IMG Term and Synonyms",
      img_term_synonyms_iex => "IMG Term Synonyms",
      img_pway_iex          => "IMG Pathway",
      img_plist_iex         => "IMG Parts List",
      all                   => "All Function"
);

$| = 1;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;    # number of saved genomes
    $numTaxon = 0 if ( $numTaxon eq "" );

    my $page = param("page");

    if ( $page eq "findFunctions" ) {
        printFunctionSearchForm($numTaxon);
    } elsif ( $page eq "EnzymeGenomeList" ) {
        printEnzymeGenomeList();
    } elsif ( $page eq "EnzymeGenomeGeneList" ) {
        printEnzymeGenomeGeneList();
    } elsif ( $page eq "ffoAllCogCategories" ) {
        printFfoAllCogCategories();
    } elsif ( $page eq "ffoAllKogCategories" ) {
        printFfoAllCogCategories("kog");
    } elsif (    paramMatch("ffoSearchKeggForGenomes") ne ""
              || paramMatch("keggGenomeSearchTerm") ne "" )
    {
        printFfoGenomeKeggPathways();
    } elsif ( $page eq "ffoKeggPathwayOrgs" ) {
        printFfoKeggPathwayOrgs();
    } elsif ( $page eq "ffoKeggPathwayOrgGenes" ) {
        printFfoKeggPathwayOrgGenes();
    } elsif ( $page eq "ffoAllKeggPathways" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;

        my $view = param("view");
        if ( $kegg_tree_file ne "" && -e $kegg_tree_file && $view eq "ko" ) {
            # new tree list
            printFfoAllKeggPathways2();
        } elsif (    $kegg_tree_file ne ""
                  && -e $kegg_tree_file
                  && $view eq "ko_test" )
        {
            # new tree list
            printFfoAllKeggPathways2_test();
        } elsif (    $kegg_brite_tree_file ne ""
                  && -e $kegg_brite_tree_file
                  && $view eq "brite" )
        {
            # new tree list
            printFfoAllKeggPathways3();
        } else {
            printFfoAllKeggPathways3();
        }

        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "ffoAllSeed" ) {
        my $time = 3600 * 24;    # 24 hour cache
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid, "", $time );
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printFfoAllSeed();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "ffoAllTc" ) {
        my $time = 3600 * 24;    # 24 hour cache
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printFfoAllTc();
        HtmlUtil::cgiCacheStop();
    } elsif (    paramMatch("ffgFindFunctions") ne ""
              || paramMatch("ffgSearchTerm") ne "" )
    {
        timeout( 60 * 40 );      # timeout in 40 minutes

        my $searchFilter = param("searchFilter");
        my $searchTerm   = param("ffgSearchTerm");

        if ( $searchFilter eq "geneProduct" ) {
            printGeneDisplayNames($numTaxon);
        } elsif ( $searchFilter eq "keggGenes" ) {
            printFfgKeggPathways();
        } elsif ( $searchFilter eq "keggEnzymes" ) {
            printFfgKeggPathwayEnzymes();
        } elsif (    $searchFilter eq "koid"
                  || $searchFilter eq "koname"
                  || $searchFilter eq "kodefn" )
        {
            printFindKo();
        } elsif ( $searchFilter eq "img_term_iex" ) {
            printImgTermTree();
        } elsif ( $searchFilter eq "img_rxn_iex" ) {
            require ImgReaction;
            ImgReaction::printSearchResults($searchTerm);
        } elsif ( $searchFilter eq "img_cpd_iex" ) {
            require ImgCompound;
            ImgCompound::printSearchResults($searchTerm);
        } elsif ( $searchFilter eq "all" ) {
            searchAllFunctions();
        } else {
            printFfgFunctionList();
        }
    } elsif ( $page eq "geneDisplayNameGenes" ) {
        printGeneDisplayNameGenes();
    } elsif ( paramMatch("addToGeneCartGrouped") ne "" ) {
        addGeneDisplayNameGenesToCart();
    } elsif ( $page eq "geneDisplayNameGenomes" ) {
        printGeneDisplayNameGenomes();
    } elsif ( $page eq "ffgFindFunctionsGeneList" ) {
        printFfgFindFunctionsGeneList();
    } elsif ( $page eq "ffgFindFunctionsGenomeList" ) {
        printFfgFindFunctionsGenomeList();
    } elsif ( $page eq "ffgCogSearchGeneList" ) {
        printFfgCogSearchGeneList();
    } elsif ( $page eq "ffgKogSearchGeneList" ) {
        printFfgCogSearchGeneList("kog");
    } elsif (    paramMatch("ffoSearchCogForGenomes") ne ""
              || paramMatch("cogSearchTerm") ne "" )
    {
        printFfoGenomeSearchCogs();
    } elsif (    paramMatch("ffoSearchKogForGenomes") ne ""
              || paramMatch("kogSearchTerm") ne "" )
    {
        printFfoGenomeSearchCogs("kog");
    } elsif ( $page eq "ffoCOGOrgs" ) {
        printFfoCogOrgs();
    } elsif ( $page eq "ffoKOGOrgs" ) {
        printFfoCogOrgs("kog");
    } elsif ( $page eq "ffoCOGOrgGenes" ) {
        printFfoCogOrgGenes();
    } elsif ( $page eq "ffoKOGOrgGenes" ) {
        printFfoCogOrgGenes("kog");
    } elsif ( $page eq "findkogenelist" ) {
        printFindKoGeneList();
    } elsif ( $page eq "findkogenomelist" ) {
        printFindKoGenomeList();
    } elsif ( $page eq "imgTermGenes" ) {
        #channel into printFfgFindFunctionsGeneList
        param( -name => "searchFilter", -value => "img_term_iex" );
        printFfgFindFunctionsGeneList();
    } elsif ( $page eq "cogList" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printCogList2();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "kogList" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printKogList();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "pfamCategories" ) {
        printPfamCategories();
    } elsif ( $page eq "pfamList" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printPfamList();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "pfamListClans" ) {
        printPfamListClans();
    } elsif ( $page eq "enzymeList" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printEnzymeList();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "seedList" ) {
        timeout( 60 * 20 );    # timeout in 20 minutes

        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printSeedList();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "tcList" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printTcList();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "viewProdNameProfile"
              || paramMatch("viewProdNameProfile") ne "" )
    {
        printProdNameProfile();
    } elsif ( $page eq "tcFuncDetails" ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;
        printTcFuncDetails();
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "cogid2cat" ) {
        printCog2Cat();
    } else {
        printFunctionSearchForm($numTaxon);
    }
}

sub printCog2Cat {
    print qq{
      <h1> COG Id Mapping to Categories</h1>   
    };
    my $rfh = newReadFileHandle( "$base_dir/cogid_and_cat.html" );
    
    my $it = new InnerTable( 0, "cog2cat$$", 'cog2cat', 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "COG Id", "asc", "left" );
    $it->addColSpec( "Catergory Code", "asc", "left" );
    $it->addColSpec( "Catergory", "asc", "left" );
    
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        next if($s =~ /^COG_ID/);
        my($id, $code, $name) = split(/\t/, $s);
        
        my $r;
        $r .= $id . $sd . "$id\t";
        $r .= $code . $sd . "$code\t";
        $r .= $name . $sd . "$name\t";
        $it->addRow($r);
    }    
    close $rfh;
    $it->printOuterTable(1);
}

############################################################################
# printFunctionSearchForm - Show basic gene search form.
#   Read from template file and replace some template components.
############################################################################
sub printFunctionSearchForm {
    my ($numTaxon) = @_;

    my $session = getSession();
    $session->clear( [ "getSearchTaxonFilter", "genomeFilterSelections" ] );

    my $templateFile = "$base_dir/findFunctions.html";
    my $rfh = newReadFileHandle( $templateFile, "printFunctionSearchForm" );

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$section_cgi/g;
        if ( $s =~ /__searchFilterOptions__/ ) {
            printSearchFilterOptions();
        } elsif ( $s =~ /__genomeListFilter__/ ) {
	    printForm($numTaxon);

	    my $name = "_section_FindGenes_ffgFindFunctions";
	    GenomeListJSON::printHiddenInputType( $section, 'ffgFindFunctions' );
	    my $button = GenomeListJSON::printMySubmitButtonXDiv
		( 'go', $name, 'Go', '', $section, 'ffgFindFunctions',
		  'smdefbutton', 'selectedGenome1', 1 );
	    print $button;
	    print nbsp( 1 );
	    print reset( -class => "smbutton" );
	    
        } elsif ( $s =~ /__hint__/ ) {
            printPageHint();
        } elsif ( $img_internal && $s =~ /keggGenomes/ ) {
            print "$s\n";
        } elsif ( $s =~ /__mer_fs_note__/ ) {
            if ($include_metagenomes) {
                printHint("Search term marked by <b>*</b> indicates that it supports metagenomes. <br/>You must add your selections into <b>Selected Genomes</b>.");
            }
        } elsif ( $s =~ /__javascript__/ ) {
            printJavaScript();
        } else {
            print "$s\n";
        }
    }
    close $rfh;
}

sub printForm {
    my ($numTaxon, $maxSelected, $noMetagenome) = @_;
    $maxSelected = -1 if $maxSelected eq "";

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new
        ( filename => "$base_dir/genomeJsonOneDiv.html" );

    $template->param( isolate      => 1 );
    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( isolate      => 1 );
    $template->param( all          => 1 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => $maxSelected );

    if ( $include_metagenomes && !$noMetagenome ) {
        #$template->param( selectedGenome1Title => '' );
        $template->param( include_metagenomes => 1 );
        $template->param( selectedAssembled1  => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    GenomeListJSON::showGenomeCart($numTaxon);
}

############################################################################
# printSearchFilterOptions - Print options for search filter.
############################################################################
sub printSearchFilterOptions {    
    my ( $img_term, $img_term_synonyms, $img_pway, $img_plist, $img_reaction, $img_compound );
    
    if ($include_img_terms) {
        $img_term          = "<option value='img_term_iex'>IMG Term and Synonyms</option>";
        $img_term_synonyms = "<option value='img_term_synonyms_iex'>IMG Term and Synonyms</option>";
        $img_pway          = "<option value='img_pway_iex'>IMG Pathways</option>";
        $img_plist         = "<option value='img_plist_iex'>IMG Parts List</option>";
    }

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    my $isEditor    = isImgEditor( $dbh, $contact_oid );
    if ( $isEditor && !$show_private ) {
        $img_reaction = "<option value='img_rxn_iex'>IMG Reactions for Editor</option>";
        $img_compound = "<option value='img_cpd_iex'>IMG Compounds for Editor</option>";
    }

    my $super;
    if ($include_metagenomes) {
        $super = '*';
    }

    my ( $img_cpd_option );
    if ( $enable_biocluster )  {
        $img_cpd_option = "<option value='img_cpd'>IMG Compound (list) </option>";
    }    

    #<option value='seedProduct'>SEED Product Name/Subsystem</option>
    my $interProText = qq{
        <option value='ipr'>InterPro (list)</option>
    };

    print qq{
       <option value='geneProduct'>Gene Product Name (inexact) $super </option>
       <!-- <option value='go'>GO (list)</option> -->
       <option value='cog'>COG (list) $super </option>
       <option value='kog'>KOG (list) </option>
       <option value='pfam'>Pfam (list) $super </option>
       <option value='tigrfam'>TIGRfam (list) $super </option>
       <option value='ec'>Enzyme (list) $super </option>
       <option value='tc'>Transporter Classification (list)</option>
       <option value='keggEnzymes'>KEGG Pathway Enzymes </option>
       <option value='koid'>KEGG Orthology ID (list) $super </option>
       <option value='koname'>KEGG Orthology Name $super </option>
       <option value='kodefn'>KEGG Orthology Definition $super </option>
       $interProText
       <option value='metacyc'>MetaCyc (list)</option>
       $img_cpd_option
       $img_term
       $img_pway
       $img_plist
       $img_reaction
       $img_compound
       <option value='all' title='SwissProt, GO, COG, KOG, Pfam, TIGRfam, InterPro, Enzyme, Transporter Classification, KEGG, MetaCyc, IMG Term and Synonyms, IMG Pathways, IMG Parts List'>
       All function names (slow, Gene Product Name not included)</option>
    };
    
}

sub printJavaScript {
    print qq{
        <script type="text/javascript" >
            for (var i=0; i <showOrHideArray.length; i++) {
                showOrHideArray[i]=new Array(2);
            }
            showOrHideArray[0][0] = "geneProduct"; // options that permit hiding
            showOrHideArray[0][1] = "swissProduct";
            showOrHideArray[0][2] = "go";
            showOrHideArray[0][3] = "ec";
            showOrHideArray[0][4] = "tc";
            showOrHideArray[0][5] = "keggEnzymes";                        
            showOrHideArray[0][6] = "koid";
            showOrHideArray[0][7] = "koname";
            showOrHideArray[0][8] = "kodefn";
            showOrHideArray[0][9] = "metacyc";
            showOrHideArray[0][10] = "img_cpd";
            showOrHideArray[0][11] = "img_term_iex";
            showOrHideArray[0][12] = "img_term_synonyms_iex";
            showOrHideArray[0][13] = "img_pway_iex";
            showOrHideArray[0][14] = "img_plist_iex";
            showOrHideArray[0][15] = "img_rxn_iex";
            showOrHideArray[0][16] = "img_cpd_iex";
            showOrHideArray[0][17] = "all";

            var hideArea = 'restrictResultsArea';
            
            YAHOO.util.Event.on("toHide", "change", function(e) {
                if ( hideArea != undefined && hideArea != null && hideArea != '' ) {
                    determineHideDisplayType('toHide', hideArea);
                }
            });

            window.onload = function() {
                //window.alert("window.onload");
                if ( hideArea != undefined && hideArea != null && hideArea != '' ) {
                    determineHideDisplayType('toHide', hideArea);
                }
                if (document.getElementById("selectType1") != null) {
                    document.getElementById("selectType1").checked = true;
                }
            }

            for (var i=0; i <termLengthArray.length; i++) {
                termLengthArray[i]=new Array(2);
            }
            //select options that need to length validation
            termLengthArray[0][0] = "geneProduct"; 
            termLengthArray[0][1] = "img_term_iex";
            termLengthArray[0][2] = "img_term_synonyms_iex";
            
        </script>
    };
}

############################################################################
# printFfgFunctionList - Show list of functions.  The gene count is
#   show in parenteheses.
#      searchTerm - Search term / expression
#      searcFilter - Search filter or field
############################################################################
sub printFfgFunctionList {
    my $searchFilter = param("searchFilter");
    my $searchTerm   = param("ffgSearchTerm");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    if ( $searchFilter eq "img_term_iex" || 
	 $searchFilter eq "img_term_synonyms_iex" ) {
        if ( $searchTerm && length($searchTerm) < 4 ) {
            webError("Please enter a search term at least 4 characters long.");
        }
    }

    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");
    my $seq_status             = param("seqstatus");
    my $domainfilter           = param("domainfilter");
    my $taxonChoice            = param("taxonChoice");
    my $data_type              = param("q_data_type");
    if ( ! $data_type ) {
        $data_type = param("data_type");
    }

    # allow searching by selected domain or by all isolates:
    my $selectionType = param("selectType");
    if ($selectionType eq "selDomain") {
	$seq_status = param("seqstatus0");
	$domainfilter = param("domainfilter0");
    } elsif ($selectionType eq "allIsolates") {
	$seq_status = param("seqstatus0");
	$domainfilter = "isolates";
    }

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");
    if ( $#genomeFilterSelections < 0 &&
	 $selectionType eq "selGenomes" ) {
        webError("Please select at least one genome.");
    }
    setSessionParam( "geneSearchTaxonFilter",  $geneSearchTaxonFilter );
    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    my $dbh = dbLogin();

    my @dbTaxons   = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) 
                = MerFsUtil::findTaxonsInFile($dbh, @genomeFilterSelections);
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }

    } elsif ($selectionType eq "selDomain" || 
	     $selectionType eq "allIsolates") {
	# no need to get taxons
    } else {
        if ( $include_metagenomes && isMetaSupported($searchFilter) ) {
            my ( $taxonClause, @bindList_txs ) 
                = OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile
		( $dbh, $taxonClause, \@bindList_txs );
            @metaTaxons = keys %taxon_in_file;
        }
    }

    my $restrictType;
    my $restrictText;
    if ( $searchFilter eq "cog" || $searchFilter eq "kog" || 
	 $searchFilter eq "pfam" || $searchFilter eq "tigrfam") {
        my $restrictResult = param("restrictResult");
        if ( $restrictResult ) {
            $restrictType = param("restrictType");   
            if ( $restrictType eq 'bio_cluster' ) {
                $restrictText = "(Restrict to Genes in Biosynthetic Cluster)";
            }
            elsif ( $restrictType eq 'chrom_cassette' ) {
                $restrictText = "(Restrict to Genes in Chromosomal Cassette)";
            }
        }        
    }

    printMainForm();
    my $title = $function2Name{$searchFilter};
    print "<h1>$title Search Results $restrictText</h1>\n";
    print "<p>\n";
    print "<u>Keyword</u>: " . $searchTerm;
    if ( isMetaSupported($searchFilter) && scalar(@metaTaxons) > 0 ) {
        HtmlUtil::printMetaDataTypeSelection($data_type, 1);
    }
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my @recs;
    my $count = 0;

    # cache file
    my $file      = param("file");
    my $cacheFile = getCacheFile($file);
    if ( $file ne "" && -e $cacheFile ) {
        ( $count, @recs ) = readCacheFile( $cacheFile, $count, @recs );

    } else {
        my ( $merfs_genecnt_href, $merfs_genomecnt_href, $func_id2Name_href );
        if ( $include_metagenomes && scalar(@metaTaxons) > 0 
	     && isMetaSupported($searchFilter) ) {
            if ( $new_func_count || $enable_biocluster ) {
                my $sql;
                my @bindList = ();

                my ( $taxonClause, @bindList_txs ) =
                  OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon_oid", \@metaTaxons );
                my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon_oid");
                my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

                if ( $new_func_count ) {
                    my $datatypeClause;
                    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                        $datatypeClause = " and g.data_type = '$data_type' ";
                    }              

                    ( $sql, @bindList ) =
                      getCogSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                      if $searchFilter eq "cog";
    
                    ( $sql, @bindList ) =
                      getPfamSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                      if $searchFilter eq "pfam";
    
                    ( $sql, @bindList ) =
                      getTigrfamSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                      if $searchFilter eq "tigrfam";
    
                    ( $sql, @bindList ) =
                      getEnzymeSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                      if $searchFilter eq "ec";
                
                }
                    
                if ( $enable_biocluster && $data_type ne 'unassembled' )  {
                    my ( $taxonClause2, @bindList_txs2 ) =
                      OracleUtil::getTaxonSelectionClauseBind
		      ( $dbh, "g.taxon", \@metaTaxons );
                    my ( $rclause2, @bindList_ur2 ) = 
			WebUtil::urClauseBind("g.taxon");
                    my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');

                    ( $sql, @bindList ) =
                      getBcSql_merfs( $searchTermLc, $taxonClause2, $rclause2, $imgClause2, \@bindList_txs2, \@bindList_ur2 )
                      if $searchFilter eq "bc";
    
                    #( $sql, @bindList ) =
                    #  getNpSql_merfs( $searchTermLc, $taxonClause2, $rclause2, $imgClause2, \@bindList_txs2, \@bindList_ur2 )
                    #  if $searchFilter eq "np";                    
                }

                #print "printFfgFunctionList() merfs sql: $sql<br/>";
                #print "printFfgFunctionList() merfs bindList: @bindList<br/>";

                if ( blankStr($sql) && $searchFilter ne "bc" ) {
                    webDie( "printFunctionsList: Unknown search filter '$searchFilter'\n" );
                }

                if ( $sql ) {
                    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                    for ( ; ; ) {
                        my ( $id, $name, $gcnt, $tcnt ) = $cur->fetchrow();
                        last if ( !$id );
    
                        $func_id2Name_href->{$id}    = $name;
                        $merfs_genecnt_href->{$id}   = $gcnt;
                        $merfs_genomecnt_href->{$id} = $tcnt;
    
                        #print "printFfgFunctionList() merfs added id: $id<br/>";
                    }
                    $cur->finish();
                }

                OracleUtil::truncTable( $dbh, "gtt_num_id" )
                  if ( $taxonClause =~ /gtt_num_id/i );

            } else {
                # TODO mer fs
                if ( $searchFilter eq "cog" ) {
                } elsif ( $searchFilter eq "pfam" )    {
                } elsif ( $searchFilter eq "tigrfam" ) {
                } elsif (    $searchFilter eq "ec"
                          || $searchFilter eq "ec_ex"
                          || $searchFilter eq "ec_iex" )
                {
                }
            }
        }

        if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
            # no need to fetch things from database
        } else {
            my ( $taxonClause, @bindList_txs );
            if ( scalar(@dbTaxons) > 0 ) {
                ( $taxonClause, @bindList_txs ) = 
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon", \@dbTaxons );
	    } elsif ($selectionType eq "selDomain" || 
		     $selectionType eq "allIsolates") { 
		# no need to get taxons
            } else {
                ( $taxonClause, @bindList_txs ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon", \@genomeFilterSelections );
            }
            my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
            my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

            my ( $taxonClause1, @bindList_txs1 );
	    my $bydomain = 0;
            if ( scalar(@dbTaxons) > 0 ) {
                ( $taxonClause1, @bindList_txs1 ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@dbTaxons );
	    } elsif ($selectionType eq "selDomain") {
		$bydomain = $domainfilter;
            } elsif ($selectionType eq "allIsolates") {
                $bydomain = $domainfilter;
            } else {
                ( $taxonClause1, @bindList_txs1 ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@genomeFilterSelections );
            }

            my ( $rclause1, @bindList_ur1 ) = WebUtil::urClauseBind("g.taxon_oid");
            my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon_oid');

            my $sql;
            my @bindList = ();

            ( $sql, @bindList ) =
              getSeedSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "seedProduct";
            ( $sql, @bindList ) =
              getSwissProtSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "swissProduct";
            ( $sql, @bindList ) =
              getGoSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "go";
            ( $sql, @bindList ) =
              getCogSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "cog";
            ( $sql, @bindList ) =
              getKogSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "kog";
            ( $sql, @bindList ) =
              getPfamSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "pfam";
            ( $sql, @bindList ) =
              getTigrfamSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "tigrfam";
            ( $sql, @bindList ) =
              getInterproSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
              if $searchFilter eq "ipr";
            ( $sql, @bindList ) =
              getEnzymeSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
              if $searchFilter eq "ec";
            ( $sql, @bindList ) =
              getEnzymeNumberSql( $searchTerm, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "ec_ex";
            ( $sql, @bindList ) =
              getEnzymeInexactSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "ec_iex";
            ( $sql, @bindList ) =
              getTcSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
              if $searchFilter eq "tc";
            ( $sql, @bindList ) =
              getMetaCycSql( $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
              if $searchFilter eq "metacyc";
            ( $sql, @bindList ) =
              getImgTermSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "img_term_iex";
            ( $sql, @bindList ) =
              getImgTermSynonymsSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "img_term_synonyms_iex";
            ( $sql, @bindList ) =
              getImgPathwaySql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter eq "img_pway_iex";
            ( $sql, @bindList ) =
              getImgPartsListSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if $searchFilter =~ /^img_plist/;

            if ( $enable_biocluster )  {
                ( $sql, @bindList ) =
                  getBcSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
                  if $searchFilter eq "bc";
                ( $sql, @bindList ) =
                  getNpSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
                  if $searchFilter eq "np";
                ( $sql, @bindList ) =
                  getImgCompoundSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
                  if $searchFilter eq "img_cpd";
            }

            #print "printFfgFunctionList() sql: $sql<br/>";
            #print "printFfgFunctionList() bindList: @bindList<br/>";

            if ( blankStr($sql) ) {
                webDie( "printFunctionsList: Unknown search filter '$searchFilter'\n" );
            }

            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $id, $name, $gcnt, $tcnt ) = $cur->fetchrow();
                last if ( !$id );

                my $rec = "$id\t";
                $rec .= "$name\t";

                #print "printFfgFunctionList rec: $rec $gcnt $tcnt <br/>\n";

                if ( $include_metagenomes && scalar(@metaTaxons) > 0 
		     && isMetaSupported($searchFilter) ) {
                    if ( exists $merfs_genecnt_href->{$id} ) {
                        my $gcnt2 = $merfs_genecnt_href->{$id};
                        my $tcnt2 = $merfs_genomecnt_href->{$id};
                        $gcnt += $gcnt2;
                        $tcnt += $tcnt2;
                        delete $merfs_genecnt_href->{$id};
                        delete $merfs_genomecnt_href->{$id};
                    }
                }
                $rec .= "$gcnt\t";
                $rec .= "$tcnt\t";

                push( @recs, $rec );
                $count++;
            }
            $cur->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $taxonClause =~ /gtt_num_id/i );
        }

        foreach my $key ( keys %$merfs_genecnt_href ) {
            my $name  = $func_id2Name_href->{$key};
            my $gcnt2 = $merfs_genecnt_href->{$key};
            my $tcnt2 = $merfs_genomecnt_href->{$key};
            my $rec   = "$key\t";
            $rec .= "$name\t";
            $rec .= "$gcnt2\t";
            $rec .= "$tcnt2\t";
            push( @recs, $rec );
            $count++;
        }
    }

    #print "printFfgFunctionList recs: @recs<br/>\n";
    #webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
        printStatusLine( "0 functions retrieved.", 2 );
        print end_form();
        return;
    }

    if ( $count > 10 ) {
        if (    $searchFilter eq "seedProduct"
             || $searchFilter eq "swissProduct" )
        {
            WebUtil::printButtonFooter();
        } else {
            WebUtil::printFuncCartFooter();
        }
    }

    if ( $domainfilter eq 'cart' ) {
        $domainfilter = '';
    }
    my $cnt = printHtmlTable( $searchTerm, $searchFilter, $seq_status, 
        $domainfilter, $taxonChoice, $data_type, \@recs, $restrictType );

    if ( $searchFilter eq "seedProduct" || $searchFilter eq "swissProduct" ) {
        WebUtil::printButtonFooter();
    } else {
        WebUtil::printFuncCartFooter();
    }

    printStatusLine( "$cnt functions retrieved.", 2 );
    print end_form();

    printHint("The function cart allows for phylogenetic profile comparisons.");

 #print "<br/>printFfgFunctionList: $count results retrieved from data, $cnt produced from table<br/>\n" if ($count != $cnt);

}

sub getSeedSql { # no longer in IMG
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $sql = qq{
        select g.product_name, g.subsystem, 
               count( distinct g.gene_oid ), count( distinct g.taxon )
        from gene_seed_names g
        where (lower( g.product_name ) like ? or lower( g.subsystem ) like ? )
        $taxonClause
        $rclause
        $imgClause
        group by g.product_name, g.subsystem
    };
    my @bindList_sql = ( "%$searchTermLc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getSwissProtSql { # no longer in IMG
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $sql = qq{
        select gs.product_name, NULL, 
               count( distinct gs.gene_oid ), count( distinct g.taxon )
        from gene_swissprot_names gs, gene g
        where ( contains(gs.product_name, ?) > 0 )
        and gs.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
        group by gs.product_name
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getGoSql { # no longer in IMG
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $attr1  = "gt.go_id";
    my $lattr2 = "gt.go_term";
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause
	( 'GO:', 1, $searchTermLc, $attr1, $lattr2, '', 1 );

    my $sql = qq{
        select gt.go_id, gt.go_term, 
               count(distinct g.gene_oid), count(distinct g.taxon)
        from go_term gt, gene_go_terms ggt, gene g
        where ( $containWhereClause )
        and gt.go_id = ggt.go_id
        and ggt.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
        group by gt.go_id, gt.go_term
    };

    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getCogSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, 
	 $restrictType, $taxonClause1, $rclause1, $imgClause1,
	 $bindList_txs_ref_type, $bindList_ur_ref_type, 
	 $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) { 
	$addfrom = ", taxon tx ";
	$dmClause = " and tx.domain = '$bydomain' ";
	$dmClause = " and tx.genome_type = 'isolate' "
	    if $bydomain eq "isolates";
	$dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
	$taxonClause1 = " and tx.taxon_oid = g.taxon ";
	$taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $attr1  = "cog.cog_id";
    my $lattr2 = "cog.cog_name";
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause
	( 'COG', 1, $searchTermLc, $attr1, $lattr2, '', 1 );

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select cog.cog_id, cog.cog_name, 
                   count(distinct g.gene_oid), count(distinct g.taxon)
            from cog cog, gene_cog_groups g, 
                 bio_cluster_features_new bcg $addfrom
            where ( $containWhereClause )
            and cog.cog_id = g.cog
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by cog.cog_id, cog.cog_name
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select cog.cog_id, cog.cog_name, 
                   count(distinct g.gene_oid), count(distinct g.taxon)
            from cog cog, gene_cog_groups g,
                 gene_cassette_genes gc $addfrom
            where ( $containWhereClause )
            and cog.cog_id = g.cog
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by cog.cog_id, cog.cog_name
        };
    }
    else {
        $sql = qq{
            select cog.cog_id, cog.cog_name, sum(g.gene_count), 
                   count(distinct g.taxon_oid)
            from cog cog, mv_taxon_cog_stat g $addfrom
            where ( $containWhereClause )
            and cog.cog_id = g.cog
            $dmClause
            $taxonClause
            $rclause
            $imgClause
            group by cog.cog_id, cog.cog_name
        };
    }

    my @bindList = ();
    if ( $restrictType eq 'bio_cluster' || 
	 $restrictType eq 'chrom_cassette' ) {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref_type, $bindList_ur_ref_type );
    }
    else {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref, $bindList_ur_ref );        
    }

    return ( $sql, @bindList );
}

sub getCogSql_merfs {
    my ( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $attr1  = "cog.cog_id";
    my $lattr2 = "cog.cog_name";
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause( 'COG', 1, $searchTermLc, $attr1, $lattr2, '', 1 );

    #    my $lattr1 = lowerAttr("cog.cog_id");
    #    my $lattr2 = lowerAttr("cog.cog_name");
    #    my ( $containWhereClause, @bindList_sql ) =
    #      OracleUtil::addMoreWhereClause( 'cog', 1, $searchTermLc, $lattr1,
    #        $lattr2, '', 0 );

    my $sql = qq{
        select cog.cog_id, cog.cog_name, sum(g.gene_count),
               count(distinct g.taxon_oid)
        from cog cog, TAXON_COG_COUNT g
        where ( $containWhereClause )
        and cog.cog_id = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by cog.cog_id, cog.cog_name
    };

    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKogSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, 
	 $restrictType, $taxonClause1, $rclause1, $imgClause1,
	 $bindList_txs_ref1, $bindList_ur_ref1, 
	 $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause1 = " and tx.taxon_oid = g.taxon ";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $attr1  = "kog.kog_id";
    my $lattr2 = "kog.kog_name";
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause
	( 'KOG', 1, $searchTermLc, $attr1, $lattr2, '', 1 );
    
    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select kog.kog_id, kog.kog_name,
                   count(distinct g.gene_oid), count(distinct g.taxon)
            from kog kog, gene_kog_groups g, 
                 bio_cluster_features_new bcg $addfrom
            where ( $containWhereClause )
            and kog.kog_id = g.kog
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by kog.kog_id, kog.kog_name
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select kog.kog_id, kog.kog_name, 
                   count(distinct g.gene_oid), count(distinct g.taxon)
            from kog kog, gene_kog_groups g, gene_cassette_genes gc $addfrom
            where ( $containWhereClause )
            and kog.kog_id = g.kog
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by kog.kog_id, kog.kog_name
        };
    }
    else {
        $sql = qq{
            select kog.kog_id, kog.kog_name,
                   sum(g.gene_count), count(distinct g.taxon_oid)
            from kog kog, mv_taxon_kog_stat g $addfrom
            where ( $containWhereClause )
            and kog.kog_id = g.kog
            $dmClause
            $taxonClause
            $rclause
            $imgClause
            group by kog.kog_id, kog.kog_name
        };
    }

    my @bindList = ();
    if ($restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette') {
        processBindList( \@bindList, \@bindList_sql, 
			 $bindList_txs_ref1, $bindList_ur_ref1 );
    }
    else {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref, $bindList_ur_ref );        
    }

    return ( $sql, @bindList );
}

sub getPfamSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, 
	 $restrictType, $taxonClause1, $rclause1, $imgClause1,
	 $bindList_txs_ref1, $bindList_ur_ref1, $bydomain, $seq_status ) = @_;




    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause1 = " and tx.taxon_oid = g.taxon ";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $attr1  = "pf.ext_accession";
    my $lattr2 = "pf.name";
    my $lattr3 = "pf.description";

    my $dbh = WebUtil::dbLogin();
    my @terms = WebUtil::splitTerm($searchTermLc, 0, 0);
    my $containWhereClause = OracleUtil::getFuncIdsInClause3($dbh, @terms);

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select pf.ext_accession, pf.name||' - '||pf.description,
                 count(distinct g.gene_oid ), count(distinct g.taxon )
            from pfam_family pf, gene_pfam_families g,
                 bio_cluster_features_new bcg $addfrom
            where pf.ext_accession in ( $containWhereClause )
            and pf.ext_accession = g.pfam_family
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by pf.ext_accession, pf.name, pf.description
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select pf.ext_accession, pf.name||' - '||pf.description,
                 count(distinct g.gene_oid ), count(distinct g.taxon )
            from pfam_family pf, gene_pfam_families g,
                 gene_cassette_genes gc $addfrom
            where pf.ext_accession in ( $containWhereClause )
            and pf.ext_accession = g.pfam_family
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by pf.ext_accession, pf.name, pf.description
        };
    }
    else {
        $sql = qq{
            select pf.ext_accession, pf.name||' - '||pf.description,
                 count(distinct g.gene_oid ), count(distinct g.taxon )
            from pfam_family pf, gene_pfam_families g $addfrom
            where pf.ext_accession in ( $containWhereClause )
            and pf.ext_accession = g.pfam_family
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by pf.ext_accession, pf.name, pf.description
        };
    }

    my @bindList = ();
#if ( $restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette' ) {
#processBindList( \@bindList, \@bindList_sql, 
#$bindList_txs_ref1, $bindList_ur_ref1 );
#} else {
#processBindList( \@bindList, \@bindList_sql, 
#$bindList_txs_ref, $bindList_ur_ref );
#}
    if($taxonClause1 ne '' && $#$bindList_txs_ref1 > -1) {
        push(@bindList, @$bindList_txs_ref1);
    }

    if($#$bindList_ur_ref1 > -1) {
        push(@bindList, @$bindList_ur_ref1);
    }

    return ( $sql, @bindList );
}

sub getPfamSql_merfs {
    my ( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $attr1  = "pf.ext_accession";
    my $lattr2 = "pf.name";
    my $lattr3 = "pf.description";
    my ( $containWhereClause, @bindList_sql ) =
      OracleUtil::addContainWhereClause( 'pfam', 1, $searchTermLc, $attr1, $lattr2, $lattr3 );

    my $sql = qq{
        select pf.ext_accession, pf.name||' - '||pf.description, 
            sum(g.gene_count), count(distinct g.taxon_oid )
        from pfam_family pf, TAXON_PFAM_COUNT g
        where ( $containWhereClause )
        and pf.ext_accession = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by pf.ext_accession, pf.name, pf.description
    };

    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getTigrfamSql_old {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $attr1  = "tf.ext_accession";
    my $lattr2 = "tf.expanded_name";

    #my $lattr3 = "tf.abbr_name"; #abbr_name=ext_accession
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause
	( 'TIGR', 1, $searchTermLc, $attr1, $lattr2, '', 1 );

    my $sql = qq{
        select tf.ext_accession, tf.expanded_name, 
               sum(g.gene_count), count(distinct g.taxon_oid)
        from tigrfam tf, mv_taxon_tfam_stat g
        where ( $containWhereClause )
        and tf.ext_accession = g.ext_accession
        $taxonClause
        $rclause
        $imgClause
        group by tf.ext_accession, tf.expanded_name
    };

    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getTigrfamSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, 
	 $restrictType, $taxonClause1, $rclause1, $imgClause1,
	 $bindList_txs_ref1, $bindList_ur_ref1, 
	 $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause1 = " and tx.taxon_oid = g.taxon ";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $attr1  = "tf.ext_accession";
    my $lattr2 = "tf.expanded_name";
    #my $lattr3 = "tf.abbr_name"; #abbr_name=ext_accession
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause
	( 'TIGR', 1, $searchTermLc, $attr1, $lattr2, '', 1 );
    
    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select tf.ext_accession, tf.expanded_name,
                   count(distinct g.gene_oid ), count(distinct g.taxon )
            from tigrfam tf, gene_tigrfams g, 
                 bio_cluster_features_new bcg $addfrom
            where ( $containWhereClause )
            and tf.ext_accession = g.ext_accession
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by tf.ext_accession, tf.expanded_name
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select tf.ext_accession, tf.expanded_name,
                   count(distinct g.gene_oid ), count(distinct g.taxon )
            from tigrfam tf, gene_tigrfams g, 
                 gene_cassette_genes gc $addfrom
            where ( $containWhereClause )
            and tf.ext_accession = g.ext_accession
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
            group by tf.ext_accession, tf.expanded_name
        };
    }
    else {
        $sql = qq{
            select tf.ext_accession, tf.expanded_name, 
                   sum(g.gene_count), count(distinct g.taxon_oid)
            from tigrfam tf, mv_taxon_tfam_stat g $addfrom
            where ( $containWhereClause )
            and tf.ext_accession = g.ext_accession
            $dmClause
            $taxonClause
            $rclause
            $imgClause
            group by tf.ext_accession, tf.expanded_name
        };
    }

    my @bindList = ();
    if ($restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette') {
        processBindList( \@bindList, \@bindList_sql, 
			 $bindList_txs_ref1, $bindList_ur_ref1 );
    }
    else {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref, $bindList_ur_ref );
    }

    return ( $sql, @bindList );
}


sub getTigrfamSql_merfs {
    my ( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $attr1  = "tf.ext_accession";
    my $lattr2 = "tf.expanded_name";

    #my $lattr3 = "tf.abbr_name"; #abbr_name=ext_accession
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause
	( 'TIGR', 1, $searchTermLc, $attr1, $lattr2, '', 1 );

    my $sql = qq{
        select tf.ext_accession, tf.expanded_name,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from tigrfam tf, TAXON_TIGR_COUNT g
        where ( $containWhereClause )
        and tf.ext_accession = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by tf.ext_accession, tf.expanded_name
    };

    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getInterproSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $attr1  = "ipr.ext_accession";
    my $lattr2 = "ipr.name";
    my ( $containWhereClause, @bindList_sql ) =
	OracleUtil::addContainWhereClause
	( 'IPR', 1, $searchTermLc, $attr1, $lattr2, '', 1 );

    my $sql = qq{
        select ipr.ext_accession, ipr.name,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from interpro ipr, mv_taxon_ipr_stat g $addfrom
        where ( $containWhereClause )
        and ipr.ext_accession = g.iprid
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by ipr.ext_accession, ipr.name
    };

    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getEnzymeNumberSql {
    my ( $searchTerm, $taxonClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause( 'EC:', '', $searchTerm );
    my $sql = qq{
        select ez.ec_number, ez.enzyme_name, 
            count( distinct g.gene_oid ), count( distinct g.taxon )
        from enzyme ez, gene_ko_enzymes g
        where ez.ec_number in ( $idWhereClause )
        and ez.ec_number = g.enzymes
        $taxonClause
        $rclause
        $imgClause
        group by ez.ec_number, ez.enzyme_name
    };

    my @bindList = ();
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getEnzymeInexactSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $searchTermUc = $searchTermLc;
    $searchTermUc =~ tr/a-z/A-Z/;

    my $prefixedIdTerm;
    if ( $searchTermLc !~ /^EC:/i ) {
        $prefixedIdTerm = 'EC:' . $searchTermUc;
    } else {
        $prefixedIdTerm = $searchTermUc;
    }

    my $sql = qq{
        WITH
        with_enzyme AS
        (
            select distinct ez.ec_number, ez.enzyme_name
            from enzyme ez
            where (
                ez.ec_number = ? or
                ez.ec_number like ? or
                contains(ez.enzyme_name, ?) > 0
            )
        )
        select we.ec_number, we.enzyme_name,
               count(distinct g.gene_oid), count(distinct g.taxon)
        from gene_ko_enzymes g, with_enzyme we
        where g.enzymes = we.ec_number
        $taxonClause
        $rclause
        $imgClause
        group by we.ec_number, we.enzyme_name
    };

    my @bindList_sql = ( "$prefixedIdTerm", "%$searchTermUc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getTcSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $searchTermUc = $searchTermLc;
    $searchTermUc =~ tr/a-z/A-Z/;
    my $idWhereClause = OracleUtil::addIdWhereClause( '', '', $searchTermUc );

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
        select tf.tc_family_num, tf.tc_family_name,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from tc_family tf, mv_taxon_tc_stat g $addfrom
        where (
            tf.tc_family_num in ( $idWhereClause ) or
            tf.tc_family_num like ? or
            lower(tf.tc_family_name) like ?  
        )
        and tf.tc_family_num = g.tc_family
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by tf.tc_family_num, tf.tc_family_name
    };

    my @bindList_sql = ( "%$searchTermUc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getBcSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $idWhereClause = OracleUtil::addIdWhereClause
	( 'BC:', '', $searchTermLc, '', '', 1 );

    my $sql = qq{
        select bcg.cluster_id, NULL, 
               count( distinct g.gene_oid ), count( distinct g.taxon )
        from bio_cluster_features_new bcg, gene g $addfrom
        where bcg.cluster_id in ( $idWhereClause )
        and bcg.gene_oid = g.gene_oid
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by bcg.cluster_id
    };

    my @bindList_sql = ();
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getBcSql_merfs {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause
	( 'BC:', '', $searchTermLc, '', '', 1 );

    my $sql = qq{
        select bcg.cluster_id, NULL, 
            count( distinct bcg.feature_id ), count( distinct g.taxon )
        from bio_cluster_features_new bcg, bio_cluster_new g
        where bcg.cluster_id in ( $idWhereClause )
        and bcg.cluster_id = g.cluster_id
        $taxonClause
        $rclause
        $imgClause
        group by bcg.cluster_id
    };

    my @bindList_sql = ();
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getNpSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $idWhereClause = OracleUtil::addIdWhereClause
	( '', '', $searchTermLc, 1, 1 );
    my $idClause;
    if ( !WebUtil::blankStr($idWhereClause) ) {
        $idClause = " np.np_id in ( $idWhereClause ) or "; 
    }
    $idClause .= " lower(np.np_product_name) like ? ";

    my $sql = qq{
        select np.np_id, np.np_product_name, 
               count( distinct g.gene_oid ), count( distinct g.taxon )
        from natural_product np, bio_cluster_features_new bcg, gene g $addfrom
        where ( $idClause )
        and np.cluster_id = bcg.cluster_id
        and bcg.gene_oid = g.gene_oid
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by np.np_id, np.np_product_name
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getNpSql_merfs {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause
	( '', '', $searchTermLc, 1, 1 );
    my $idClause;
    if ( !WebUtil::blankStr($idWhereClause) ) {
        $idClause = " np.np_id in ( $idWhereClause ) or "; 
    }
    $idClause .= " lower(np.np_product_name) like ? ";

    my $sql = qq{
        select np.np_id, np.np_product_name, 
               count( distinct bcg.feature_id ), count( distinct g.taxon )
        from natural_product np, bio_cluster_features_new bcg,
             bio_cluster_new g
        where ( $idClause )
        and np.cluster_id = bcg.cluster_id
        and bcg.cluster_id = g.cluster_id
        $taxonClause
        $rclause
        $imgClause
        group by np.np_id, np.np_product_name
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getMetaCycSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $searchTermUc = $searchTermLc;
    $searchTermUc =~ tr/a-z/A-Z/;
    my $idWhereClause = OracleUtil::addIdWhereClause( '', '', $searchTermUc );

    my $sql = qq{
        select bp.unique_id, bp.common_name, 
            sum(g.gene_count), count(distinct g.taxon_oid)
        from biocyc_pathway bp, mv_taxon_metacyc_stat g $addfrom
        where (
            bp.unique_id in ( $idWhereClause ) or
            bp.unique_id like ? or
            contains(bp.common_name, ?) > 0
        )
        and bp.unique_id = g.pwy_id
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by bp.unique_id, bp.common_name
    };

    my @bindList_sql = ( "%$searchTermUc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgCompoundSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause( '', '', $searchTermLc, 1, 1 );
    my $idClause;
    if ( !WebUtil::blankStr($idWhereClause) ) {
        $idClause = " ic.compound_oid in ( $idWhereClause ) or "; 
    }
    $idClause .= " lower(ic.compound_name) like ? ";

    my $sql = qq{
        select ic.compound_oid, ic.compound_name, 
               count( distinct g.gene_oid ), count( distinct g.taxon )
        from natural_product np, img_compound ic, 
             bio_cluster_features_new bcg, gene g
        where np.compound_oid = ic.compound_oid
        and ( $idClause )
        and np.cluster_id = bcg.cluster_id
        and bcg.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
        group by ic.compound_oid, ic.compound_name
    }; 

    my @bindList_sql = ("%$searchTermLc%" );
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}


sub getImgTermSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $oid_search;
    $oid_search = "or it.term_oid = ? " if isInt($searchTermLc);

    my $sql = qq{
        select it.term_oid, it.term, count(distinct g.gene_oid),
               count(distinct g.taxon)
        from img_term it, gene_img_functions g $addfrom
        where ( lower( it.term ) like ? $oid_search )
        and it.term_oid = g.function
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by it.term_oid, it.term
    };

    my @bindList_sql = ();
    push( @bindList_sql, "%$searchTermLc%" );
    push( @bindList_sql, "$searchTermLc" ) if isInt($searchTermLc);

    #push( @bindList_sql, 'No' );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgTermSynonymsSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select ws.term_oid, ws.synonyms, 
               count(distinct g.gene_oid), count(distinct g.taxon)
        from img_term_synonyms ws, gene_img_functions g $addfrom
        where lower( ws.synonyms ) like ?
        and ws.term_oid = g.function
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by ws.term_oid, ws.synonyms
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgPathwaySql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $oid_search;
    $oid_search = "or ipw.pathway_oid = ?" if isInt($searchTermLc);

    #my $sql = qq{
    #    select new.pathway_oid, new.pathway_name, count( distinct new.gene_oid ), count( distinct new.taxon )
    #    from (
    #        select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name, g.gene_oid gene_oid, g.taxon taxon
    #        from img_pathway ipw, img_pathway_reactions ipr, img_reaction_catalysts irc,
    #            dt_img_term_path dtp, gene_img_functions g
    #        where ( lower( ipw.pathway_name ) like ? $oid_search )
    #        and ipw.pathway_oid = ipr.pathway_oid
    #        and ipr.rxn = irc.rxn_oid
    #        and irc.catalysts = dtp.term_oid
    #        and dtp.map_term = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #          union
    #        select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name, g.gene_oid gene_oid, g.taxon taxon
    #        from img_pathway ipw, img_pathway_reactions ipr, img_reaction_t_components itc,
    #            dt_img_term_path dtp, gene_img_functions g
    #        where ( lower( ipw.pathway_name ) like ? $oid_search )
    #        and ipw.pathway_oid = ipr.pathway_oid
    #        and ipr.rxn = itc.rxn_oid
    #        and itc.term = dtp.term_oid
    #        and dtp.map_term = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #    ) new
    #    group by new.pathway_oid, new.pathway_name
    #};
    #my $sql = qq{
    #    select new.pathway_oid, new.pathway_name, count( distinct new.gene_oid ), count( distinct new.taxon )
    #    from (
    #        select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name, g.gene_oid gene_oid, g.taxon taxon
    #        from img_pathway ipw, img_pathway_reactions ipr, img_reaction_catalysts irc,
    #            gene_img_functions g
    #        where ( lower( ipw.pathway_name ) like ? $oid_search )
    #        and ipw.pathway_oid = ipr.pathway_oid 
    #        and ipr.rxn = irc.rxn_oid
    #        and irc.catalysts = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #          union
    #        select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name, g.gene_oid gene_oid, g.taxon taxon
    #        from img_pathway ipw, img_pathway_reactions ipr, img_reaction_t_components itc, 
    #            gene_img_functions g
    #        where ( lower( ipw.pathway_name ) like ? $oid_search )
    #        and ipw.pathway_oid = ipr.pathway_oid 
    #        and ipr.rxn = itc.rxn_oid
    #        and itc.term = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #    ) new
    #    group by new.pathway_oid, new.pathway_name
    #};
    my $sql = qq{
        WITH
        with_new AS
        (
            select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name, g.gene_oid gene_oid, g.taxon taxon
            from img_pathway ipw, img_pathway_reactions ipr, img_reaction_catalysts irc,
                gene_img_functions g
            where ( lower( ipw.pathway_name ) like ? $oid_search )
            and ipw.pathway_oid = ipr.pathway_oid 
            and ipr.rxn = irc.rxn_oid
            and irc.catalysts = g.function
            $taxonClause
            $rclause
            $imgClause
              union
            select ipw.pathway_oid pathway_oid, ipw.pathway_name pathway_name, g.gene_oid gene_oid, g.taxon taxon
            from img_pathway ipw, img_pathway_reactions ipr, img_reaction_t_components itc, 
                gene_img_functions g
            where ( lower( ipw.pathway_name ) like ? $oid_search )
            and ipw.pathway_oid = ipr.pathway_oid 
            and ipr.rxn = itc.rxn_oid
            and itc.term = g.function
            $taxonClause
            $rclause
            $imgClause
        )
        select new.pathway_oid, new.pathway_name, count( distinct new.gene_oid ), count( distinct new.taxon )
        from with_new new
        group by new.pathway_oid, new.pathway_name
    };

    my @bindList_sql = ("%$searchTermLc%");
    push( @bindList_sql, "$searchTermLc" ) if isInt($searchTermLc);
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getImgPartsListSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $oid_search;
    $oid_search = "or ipl.parts_list_oid = ?" if isInt($searchTermLc);

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select ipl.parts_list_oid, ipl.parts_list_name, 
               count(distinct g.gene_oid), count(distinct g.taxon)
        from img_parts_list ipl, img_parts_list_img_terms pt, 
             gene_img_functions g $addfrom
        where ( lower( ipl.parts_list_name ) like ? $oid_search )
        and ipl.parts_list_oid = pt.parts_list_oid
        and pt.term = g.function
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by ipl.parts_list_oid, ipl.parts_list_name
    };

    my @bindList_sql = ("%$searchTermLc%");
    push( @bindList_sql, "$searchTermLc" ) if isInt($searchTermLc);
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub printHtmlTable {
    my ( $searchTerm, $searchFilter, $seq_status, $domainfilter, $taxonChoice, 
        $data_type, $recs_aref, $restrictType ) = @_;

    my $it = new InnerTable( 1, "function$$", "function", 1 );
    $it->addColSpec("Select");
    if ( $searchFilter eq 'seedProduct' ) {
        $it->addColSpec( "SEED Product Name", "asc", "left" );
        $it->addColSpec( "SEED Subsystem",    "asc", "left" );
    } elsif ( $searchFilter eq 'swissProduct' ) {
        $it->addColSpec( "SwissProt Name", "asc", "left" );
    } elsif ( $searchFilter eq 'tc' ) {
        $it->addColSpec( "TC Family Number", "asc", "left" );
        $it->addColSpec( "TC Family Name",   "asc", "left" );
    } elsif ( $searchFilter eq 'bc' ) {
        $it->addColSpec( "Biosynthetic Cluster", "asc", "left" );
    } elsif ( $searchFilter eq 'np' ) {
        $it->addColSpec( "Secondary Metabolite ID", "asc", "left" );
        $it->addColSpec( "Secondary Metabolite Name", "asc", "left" );
    } elsif ( $searchFilter eq 'img_cpd' ) {
        $it->addColSpec( "IMG Compound", "asc", "left" );
        $it->addColSpec( "Compound Name", "asc", "left" );
    } else {
        $it->addColSpec( "Function", "asc", "left" );
        $it->addColSpec( "Name",     "asc", "left" );
    }
    $it->addColSpec( "Gene Count",   "desc", "right" );
    $it->addColSpec( "Genome Count", "desc", "right" );

    my $sd = $it->getSdDelim();    # sort delimit

    my %done;
    my $count = 0;
    for my $rec (@$recs_aref) {
        my ( $id, $name, $gcnt, $tcnt, $metagGcnt, $metagTcnt ) =
          split( /\t/, $rec );
        next
          if (    $done{$id} ne ""
               && $searchFilter ne "seedProduct"
               && $searchFilter ne "swissProduct" );
        $count++;

        my $r;

        # select column
        my $tmp;
        $tmp = "<input type='checkbox' name='seed' value='$id' />\n"
          if $searchFilter eq "seedProduct";
        $tmp = "<input type='checkbox' name='swiss' value='$id' />\n"
          if $searchFilter eq "swissProduct";
        $tmp = "<input type='checkbox' name='go_id' value='$id' />\n"
          if $searchFilter eq "go";
        $tmp = "<input type='checkbox' name='cog_id' value='$id' />\n"
          if $searchFilter eq "cog";
        $tmp = "<input type='checkbox' name='kog_id' value='$id' />\n"
          if $searchFilter eq "kog";
        $tmp = "<input type='checkbox' name='pfam_id' value='$id' />\n"
          if $searchFilter eq "pfam";
        $tmp = "<input type='checkbox' name='tigrfam_id' value='$id' />\n"
          if $searchFilter eq "tigrfam";
        $tmp = "<input type='checkbox' name='ipr_id' value='$id' />\n"
          if $searchFilter eq "ipr";
        $tmp = "<input type='checkbox' name='ec_number' value='$id' />\n"
          if $searchFilter eq "ec" || $searchFilter eq "ec_ex" || $searchFilter eq "ec_iex";
        $tmp = "<input type='checkbox' name='tc_fam_num' value='$id' />\n"
          if $searchFilter eq "tc";
        $tmp = "<input type='checkbox' name='func_id' value='BC:$id' />\n"
          if $searchFilter eq "bc";
        $tmp = "<input type='checkbox' name='func_id' value='NP:$id' />\n"
          if $searchFilter eq "np";
        $tmp = "<input type='checkbox' name='func_id' value='MetaCyc:$id' />\n"
          if $searchFilter eq "metacyc";
        $tmp = "<input type='checkbox' name='func_id' value='ICMPD:$id' />\n"
          if $searchFilter eq "img_cpd";
        my $term_oid = FuncUtil::termOidPadded($id);
        $tmp = "<input type='checkbox' name='term_oid' value='$term_oid' />\n"
          if $searchFilter eq "img_term_iex"
          || $searchFilter eq "img_term_synonyms_iex";
        my $pway_oid = FuncUtil::pwayOidPadded($id);
        $tmp = "<input type='checkbox' name='pway_oid' value='$pway_oid' />\n"
          if $searchFilter eq "img_pway_iex";
        $tmp = "<input type='checkbox' name='parts_list_oid' value='$id' />\n"
          if $searchFilter =~ /^img_plist/;

        $r .= $sd . $tmp . "\t";

        # function id
        $id = $term_oid if $searchFilter eq "img_term_iex";
        $id = $pway_oid if $searchFilter eq "img_pway_iex";

        if (    $searchFilter eq "img_term_iex"
             || $searchFilter eq "img_term_synonyms_iex" )
        {
            $id = FuncUtil::termOidPadded($id);
            my $url = "$main_cgi?section=ImgTermBrowser" 
                . "&page=imgTermDetail&term_oid=$id";
            $r .= $id . $sd . alink( $url, $id ) . "\t";
        } elsif ( $searchFilter eq "img_pway_iex" ) {
            $id = FuncUtil::pwayOidPadded($id);
            my $url = "$main_cgi?section=ImgPwayBrowser" 
                . "&page=imgPwayDetail&pway_oid=$id";
            $r .= $id . $sd . alink( $url, $id ) . "\t";
        } elsif ( $searchFilter =~ /^img_plist/ ) {
            $id = FuncUtil::partsListOidPadded($id);
            my $url = "$main_cgi?section=ImgPartsListBrowser" 
                . "&page=partsListDetail&parts_list_oid=$id";
            $r .= $id . $sd . alink( $url, $id ) . "\t";
        } else {
            my $id2;
            if (    $searchFilter eq "cog"
                 || $searchFilter eq "kog"
                 || $searchFilter eq "go"
                 || $searchFilter eq "pfam"
                 || $searchFilter eq "tigrfam"
                 || $searchFilter eq "ipr"
                 || $searchFilter eq "ec"
                 || $searchFilter eq "ec_ex"
                 || $searchFilter eq "tc"
                 || $searchFilter eq "metacyc" )
            {
                $id2 = highlightMatchHTML3( $id, $searchTerm );
            } else {
                $id2 = highlightMatchHTML2( $id, $searchTerm );
            }
            $r .= $id2 . $sd . $id2 . "\t";
        }

        # function name
        if ( $searchFilter ne "swissProduct" && $searchFilter ne "bc") {
            my $s = $name;
            my $matchText;
            if (    $searchFilter eq "go"
                 || $searchFilter eq "cog"
                 || $searchFilter eq "kog"
                 || $searchFilter eq "pfam"
                 || $searchFilter eq "tigrfam"
                 || $searchFilter eq "ipr" )
            {
                $matchText = highlightMatchHTML3( $s, $searchTerm );
            } elsif ( $searchFilter eq "tc" ) {
                $matchText = highlightMatchHTML2( $s, $searchTerm, 1 );
            } else {
                $matchText = highlightMatchHTML2( $s, $searchTerm );
            }
            $r .= $s . $sd . $matchText . "\t";
        }

        # gene count
        my $g_url = "$section_cgi&page=ffgFindFunctionsGeneList";
        $g_url .= "&searchFilter=$searchFilter";
        if ( $searchFilter eq "seedProduct" ) {
            $g_url .= "&id=" . WebUtil::massageToUrl($id);
            $g_url .= "&sub=" . WebUtil::massageToUrl($name);
        } elsif ( $searchFilter eq "swissProduct" ) {
            $g_url .= "&id=" . WebUtil::massageToUrl($id);
        } else {
            $g_url .= "&id=$id";
        }
        $g_url .= "&cnt=$gcnt";
        $g_url .= "&seqstatus=$seq_status";
        $g_url .= "&domainfilter=$domainfilter" if ( $domainfilter );
        $g_url .= "&taxonChoice=$taxonChoice" if ( $taxonChoice );
        if ( $include_metagenomes && isMetaSupported($searchFilter) ) {
            $g_url .= "&data_type=$data_type";
        }
        if ( $searchFilter eq "cog" || $searchFilter eq "kog" || $searchFilter eq "pfam" || $searchFilter eq "tigrfam" ) {
            if ( $restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette' ) {
                $g_url .= "&restrictType=$restrictType";
            }
        }

        if ( $gcnt > 0 ) {
            $r .= $gcnt . $sd . alink( $g_url, $gcnt ) . "\t";
        } else {
            $r .= $gcnt . $sd . "0" . "\t";
        }

        # genome count
        my $t_url = "$section_cgi&page=ffgFindFunctionsGenomeList";
        $t_url .= "&searchFilter=$searchFilter";
        if ( $searchFilter eq "seedProduct" ) {
            $t_url .= "&id=" . massageToUrl($id);
            $t_url .= "&sub=" . massageToUrl($name);
        } elsif ( $searchFilter eq "swissProduct" ) {
            $t_url .= "&id=" . massageToUrl($id);
        } else {
            $t_url .= "&id=$id";
        }
        $t_url .= "&cnt=$tcnt";
        $t_url .= "&seqstatus=$seq_status";
        $t_url .= "&domainfilter=$domainfilter" if ( $domainfilter );
        $t_url .= "&taxonChoice=$taxonChoice" if ( $taxonChoice );
        if ( $include_metagenomes && isMetaSupported($searchFilter) ) {
            $t_url .= "&data_type=$data_type";
        }
        if ( $searchFilter eq "cog" || $searchFilter eq "kog" || $searchFilter eq "pfam" || $searchFilter eq "tigrfam" ) {
            if ( $restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette' ) {
                $t_url .= "&restrictType=$restrictType";
            }
        }

        if ( $tcnt > 0 ) {
            $r .= $tcnt . $sd . alink( $t_url, $tcnt ) . "\t";
        } else {
            $r .= $tcnt . $sd . "0" . "\t";
        }

        $done{$id} = $id;
        $it->addRow($r);
    }

    $it->printOuterTable(1);
    return $count;
}

############################################################################
# printFfgFindFunctionsGeneList - Show gene list of individual counts.
############################################################################
sub printFfgFindFunctionsGeneList {
    my $searchFilter = param("searchFilter");
    my $data_type    = param("data_type");
    my $id           = param("id");
    my $subs         = param("sub");
    my $cnt          = param("cnt");
    my $restrictType = param("restrictType");
    my $domainfilter = param("domainfilter");
    my $seq_status   = param("seqstatus");

    # bug fix some list we should ignore genome cart filter list - ken
    my $ignoreFilter = param("ignoreFilter");
    $ignoreFilter = 0 if ( $ignoreFilter eq "" );

    printStatusLine( "Loading ...", 1 );

    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections     = ();
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }
    if ($ignoreFilter) {
        @genomeFilterSelections = ();
    }

    my $dbh = dbLogin();

    my @dbTaxons   = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) = 
		MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }
    } elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
    } else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) =
              OracleUtil::getTaxonSelectionClauseBind
	      ( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile
		( $dbh, $taxonClause, \@bindList_txs );
            @metaTaxons = keys %taxon_in_file;
        }
    }

    my $gene_cnt = 0;
    my $trunc    = 0;

    my @gene_oids = ();
    if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
        # no need to fetch things from database
    } else {
        my ( $taxonClause, @bindList_txs );
        my $bydomain = 0;
        if ( scalar(@dbTaxons) > 0 ) {
            ( $taxonClause, @bindList_txs ) =
                OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon", \@dbTaxons );
	} elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
            $bydomain = $domainfilter;
        } else {
            ( $taxonClause, @bindList_txs ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon", \@genomeFilterSelections );
        }

        my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

        if ($ignoreFilter) {
            $taxonClause  = "";
            @bindList_txs = ();
        }

        my $sql;
        my @bindList = ();
        ( $sql, @bindList ) =
	    getSeedGeneListSql( $id, $subs, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if ( $searchFilter eq "seedProduct" );
        ( $sql, @bindList ) =
	    getSwissProtGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "swissProduct";
        ( $sql, @bindList ) = getGoGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "go";
        ( $sql, @bindList ) = getCogGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $restrictType, $bydomain, $seq_status )
	    if $searchFilter eq "cog";
        ( $sql, @bindList ) = getKogGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $restrictType, $bydomain, $seq_status )
	    if $searchFilter eq "kog";
        ( $sql, @bindList ) = getPfamGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $restrictType, $bydomain, $seq_status )
	    if $searchFilter eq "pfam";
        ( $sql, @bindList ) = getTigrfamGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $restrictType, $bydomain, $seq_status )
	    if $searchFilter eq "tigrfam";
        ( $sql, @bindList ) = getInterproGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "ipr";
        ( $sql, @bindList ) = getEnzymeGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "ec_iex" || $searchFilter eq "ec_ex" || $searchFilter eq "ec";
        ( $sql, @bindList ) = getTcGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "tc";

        if ( $searchFilter eq "keggEnzymes" ) {
            my $pathway_oid = param("pathway_oid");
            my $ec_number   = param("ec_number");
            $id = $ec_number;
            ( $sql, @bindList ) = getKeggPathEzGeneListSql( $pathway_oid, $ec_number, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status );
        }

        ( $sql, @bindList ) = getMetaCycGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "metacyc";

        if (    $searchFilter eq "img_term_iex"
             || $searchFilter eq "img_term_synonyms_iex" )
        {
            if ( $searchFilter eq "img_term_iex" ) {
                my $term_oid = param("term_oid");
                $term_oid = FuncUtil::termOidPadded($term_oid) 
		    if ( $term_oid ne '' );
                $id = $term_oid if ( $term_oid ne '' );
            }
            ( $sql, @bindList ) =
		getImgTermGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status );
        }

        ( $sql, @bindList ) =
	    getImgPathwayGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "img_pway_iex";
        ( $sql, @bindList ) = getImgPartsListGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter =~ /^img_plist/;

        if ( $enable_biocluster )  {
            ( $sql, @bindList ) = getBcGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
		if $searchFilter eq "bc";
            ( $sql, @bindList ) = getNpGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
		if $searchFilter eq "np";
            ( $sql, @bindList ) = getImgCompoundGeneListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
		if $searchFilter eq "img_cpd";
        }

        #print "printFfgFindFunctionsGeneList() sql: $sql<br/>";
        #print "printFfgFindFunctionsGeneList() bindList: @bindList<br/>";

        if ( blankStr($sql) ) {
            webDie( "printFfgFunctionsGeneList: Unknown search filter '$searchFilter'\n" );
        }

        @gene_oids = HtmlUtil::fetchGeneList($dbh, $sql, $verbose, @bindList);
        $gene_cnt = scalar(@gene_oids);
        if ( $gene_cnt >= $maxGeneListResults ) {
            $trunc = 1;
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $taxonClause =~ /gtt_num_id/i );
    }

    my @meta_genes = ();
    if ( $include_metagenomes && scalar(@metaTaxons) > 0 
	 && isMetaSupported($searchFilter) ) {
        if ( $searchFilter eq "bc" ) {            
            if ( $enable_biocluster )  {
                my @func_ids = ( $id );
                my %workspaceIds_href = MetaUtil::getMetaTaxonsBcFuncGenes
		    ( $dbh, \@metaTaxons, '', \@func_ids );
                my @workspaceIds = keys %workspaceIds_href;
                if ( scalar(@workspaceIds) > 0 ) {
                    push( @meta_genes, @workspaceIds );                    
    
                    $gene_cnt += scalar(@workspaceIds);
                    if ( $gene_cnt >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
            }

        }
        else {
            foreach my $toid (@metaTaxons) {
                if ( $searchFilter eq "keggEnzymes" ) {
                    my $pathway_oid = param("pathway_oid");
                    my $ec_number   = param("ec_number");
                    $id = $ec_number;
                    my %genes_ec = MetaUtil::getTaxonFuncGenes( $toid, '', $id );
    
                    my @type_list = MetaUtil::getDataTypeList( $data_type );
                    for my $t2 (@type_list) {
                        my %h = MetaUtil::getTaxonFuncsGenes( $toid, $t2, "ko" );
                        if ( scalar( keys %h ) > 0 ) {
                            for my $key ( keys %h ) {
                                my @gene_list = split( /\t/, $h{$key} );
                                for my $gene_oid (@gene_list) {
                                    if ( $genes_ec{$gene_oid} ) {
                                        push( @meta_genes, $genes_ec{$gene_oid} );
                                    }
                                }
                            }
                        }
                    }
    
                } else {
                    my @type_list = MetaUtil::getDataTypeList( $data_type );
                    for my $t2 (@type_list) {
                        my %genes = MetaUtil::getTaxonFuncGenes( $toid, $t2, $id );
                        my @worksapceIds = values %genes;
                        if ( scalar(@worksapceIds) > 0 ) {
                            push( @meta_genes, @worksapceIds );
        
                            $gene_cnt += scalar(@worksapceIds);
                            if ( $gene_cnt >= $maxGeneListResults ) {
                                $trunc = 1;
                                last;
                            }
                        }
                    }
                }
    
            }
        }

    }

    if ( scalar(@gene_oids) == 1 && scalar(@meta_genes) == 0 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    #print "\@gene_oids: @gene_oids<br/>\n";

    my $restrictText;
    if ( $searchFilter eq "cog" || $searchFilter eq "kog" || 
	 $searchFilter eq "pfam" || $searchFilter eq "tigrfam" ) {
        if ( $restrictType eq 'bio_cluster' ) {
            $restrictText = "(Restrict to Genes in Biosynthetic Cluster)";
        }
        elsif ( $restrictType eq 'chrom_cassette' ) {
            $restrictText = "(Restrict to Genes in Chromosomal Cassette)";
        }
    }

    my $name = $function2Name{$searchFilter};
    $name = "IMG Term" if ( $searchFilter eq "img_term_iex" );
    my $title    = "Genes In $name $restrictText";
    my $subtitle = "$name ID: " . $id;

    if ( $searchFilter eq "tc" ) {
        my $tcnum = $id;
        $tcnum =~ s/TC://;
        my $url = $tc_base_url . $tcnum;
        $subtitle = "TC ID: " . alink( $url, $id );
    } elsif ( $searchFilter eq "img_pway_iex" ) {
        my $psql = "select pathway_name from img_pathway where pathway_oid = ?";
        my $cur    = execSql( $dbh, $psql, $verbose, $id );
        my ($name) = $cur->fetchrow();

        my $url = "$main_cgi?section=ImgPwayBrowser"
	        . "&page=imgPwayDetail&pway_oid=$id";
        $subtitle = "IMG Pathway ID: " . alink( $url, $name );
    } elsif ( $searchFilter eq "np" ) {
        my $url = "$main_cgi?section=NaturalProd&page=naturalProd&np_id=$id";
        $subtitle = "SM ID: " . alink( $url, $id );
    } elsif ( $searchFilter eq "img_cpd" ) {
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$id";
        $subtitle = "IMG Compound ID: " . alink( $url, $id );
    }

    if ( $searchFilter eq "seedProduct" ) {
    	my @subs = split(';<br/>', $subs);
    	my $substr = join("; ", @subs);
    	my $subtitle = "<u>Product Name</u>: $id<br/>"
          	     . "<u>Subsystem(s)</u>: $substr";

        my $taxonClause = WebUtil::txsClause( "g.taxon", $dbh ) 
	    if !$ignoreFilter;
        $subtitle .= "<p>*Showing genes for genomes in genome cart only</p>"
            if $taxonClause ne "";
        HtmlUtil::printGeneListHtmlTable( $title, $subtitle, $dbh, \@gene_oids, \@meta_genes );
    } elsif ( $searchFilter eq "cog" || $searchFilter eq "kog" || $searchFilter eq "pfam" || $searchFilter eq "tigrfam" 
            || $searchFilter eq "ec" || $searchFilter eq "bc" ) {

        if ( $searchFilter eq "cog" ) {
            my $url = "http://www.ncbi.nlm.nih.gov/COG/grace/wiew.cgi?$id";
            $subtitle = "COG ID: " . alink( $url, $id );
        } elsif ( $searchFilter eq "kog" ) {
            my $url = "http://www.ncbi.nlm.nih.gov/COG/grace/shokog.cgi?$id";
            $subtitle = "KOG ID: " . alink( $url, $id );
        } elsif ( $searchFilter eq "pfam" ) {
            my $url = "http://pfam.sanger.ac.uk/family/PF" . substr( $id, 4 );
            $subtitle = "Pfam ID: " . alink( $url, $id );
        } elsif ( $searchFilter eq "tigrfam" ) {
            my $url = "http://cmr.jcvi.org/tigr-scripts/CMR/HmmReport.cgi?hmm_acc=$id";
            $subtitle = "Tigrfam ID: " . alink( $url, $id );
        }

        if ( $include_metagenomes && isMetaSupported($searchFilter) &&
	     scalar(@meta_genes) > 0 ) {
            $subtitle .= "<br/>\nMER-FS Metagenome: " . $data_type;
        }

        if ( $restrictType eq 'bio_cluster' ) {
            my ($extracolumn_href, $extracollink_href) = 
		fetchGene2BiosyntheticClusterMapping( $dbh, \@gene_oids );
            #print Dumper($extracolumn_href);
            #print "<br/>\n";
            #print Dumper($extracollink_href);
            #print "<br/>\n";
            HtmlUtil::printGeneListHtmlTable
            ( $title, $subtitle, $dbh, \@gene_oids, \@meta_genes, '', 'Biosynthetic Cluster', $extracolumn_href, $extracollink_href );
        }
        elsif ( $restrictType eq 'chrom_cassette' ) {
            my ($extracolumn_href, $extracollink_href) = fetchGene2ChromoCassetteMapping( $dbh, \@gene_oids, $searchFilter );
            #print Dumper($extracolumn_href);
            #print "<br/>\n";
            #print Dumper($extracollink_href);
            #print "<br/>\n";
            HtmlUtil::printGeneListHtmlTable
            ( $title, $subtitle, $dbh, \@gene_oids, \@meta_genes, '', 'Chromosomal Cassette', $extracolumn_href, $extracollink_href );
        }
        else {
            HtmlUtil::printGeneListHtmlTable
            ( $title, $subtitle, $dbh, \@gene_oids, \@meta_genes );                
        }
    } else {
        HtmlUtil::printGeneListHtmlTable
	    ( $title, $subtitle, $dbh, \@gene_oids, \@meta_genes );
    }
}

sub getSeedGeneListSql {
    my ( $id, $subs, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my @subs = split(';<br/>', $subs);
    my $nsubs = scalar @subs;

    my $subWhereClause;
    if ( $subs eq '' ) {
        #$subWhereClause = "and g.subsystem is null ";
    } elsif ( $nsubs == 1) { 
        $subWhereClause = "and g.subsystem = ? ";
    } else {
	my $substr = WebUtil::joinSqlQuoted(",", @subs);
        #$subWhereClause = "and g.subsystem in ($substr) ";
    }

    #ANNA: todo: if one of many subsystems is null, need to add it in...
    my $sql = qq{
        select distinct g.gene_oid
        from gene_seed_names g
        where g.product_name = ?
        $subWhereClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    push( @bindList_sql, $subs ) if ( $subs ne '' && $nsubs == 1);
    my @bindList = ();
    processBindList
	( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getSwissProtGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $sql = qq{
        select distinct g.gene_oid
        from gene_swissprot_names gs, gene g
        where gs.product_name = ?
        and gs.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGoGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $sql = qq{
        select distinct g.gene_oid
        from gene_go_terms ggt, gene g
        where ggt.go_id = ?
        and ggt.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getCogGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $restrictType, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_cog_groups g, bio_cluster_features_new bcg $addfrom
            where g.cog = ? 
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_cog_groups g, gene_cassette_genes gc $addfrom
            where g.cog = ? 
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    else {
        $sql = qq{
            select distinct g.gene_oid
            from gene_cog_groups g $addfrom
            where g.cog = ? 
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKogGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $restrictType, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_kog_groups g, bio_cluster_features_new bcg $addfrom
            where g.kog = ? 
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_kog_groups g, gene_cassette_genes gc $addfrom
            where g.kog = ? 
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    else {
        $sql = qq{
            select distinct g.gene_oid
            from gene_kog_groups g $addfrom
            where g.kog = ? 
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getPfamGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $restrictType, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_pfam_families g, bio_cluster_features_new bcg $addfrom
            where g.pfam_family = ?
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_pfam_families g, gene_cassette_genes gc $addfrom
            where g.pfam_family = ?
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    else {
        $sql = qq{
            select distinct g.gene_oid
            from gene_pfam_families g $addfrom
            where g.pfam_family = ?
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getTigrfamGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $restrictType, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tigrfams g, bio_cluster_features_new bcg $addfrom
            where g.ext_accession = ? 
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.gene_oid
            from gene_tigrfams g, gene_cassette_genes gc $addfrom
            where g.ext_accession = ? 
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }
    else {
        $sql = qq{
           select distinct g.gene_oid
           from gene_tigrfams g $addfrom
           where g.ext_accession = ? 
           $dmClause
           $taxonClause
           $rclause
           $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getInterproGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
       select distinct g.gene_oid
       from gene_xref_families g $addfrom
       where g.db_name = 'InterPro'
       and g.id = ? 
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getEnzymeGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
       select distinct g.gene_oid
       from gene_ko_enzymes g $addfrom
       where g.enzymes = ?
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getTcGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
       select distinct g.gene_oid
       from gene_tc_families gtf, gene g $addfrom
       where gtf.tc_family = ?
       and gtf.gene_oid = g.gene_oid
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKeggPathEzGeneListSql {
    my ( $pathway_oid, $ec_number, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.gene_oid
        from image_roi roi, image_roi_ko_terms rk, ko_term_enzymes kt,
             gene_ko_enzymes g $addfrom
        where roi.pathway = ? 
        and roi.roi_id = rk.roi_id
        and rk.ko_terms = kt.ko_id 
        and kt.enzymes = g.enzymes
        and g.enzymes = ?
        $dmClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ( "$pathway_oid", "$ec_number" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getBcGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.gene_oid
        from bio_cluster_features_new bcg, gene g
        where bcg.cluster_id = ?
        and bcg.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getNpGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.gene_oid
        from natural_product np, bio_cluster_features_new bcg, gene g
        where np.np_id = ?
        and np.cluster_id = bcg.cluster_id
        and bcg.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getMetaCycGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
       select distinct g.gene_oid
       from biocyc_reaction_in_pwys brp, biocyc_reaction br,
            gene_biocyc_rxns g $addfrom
       where brp.in_pwys = ?
       and brp.unique_id = br.unique_id
       and br.unique_id = g.biocyc_rxn
       and br.ec_number = g.ec_number
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgCompoundGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.gene_oid
        from natural_product np, bio_cluster_features_new bcg, gene g $addfrom
        where np.compound_oid = ?
        and np.cluster_id = bcg.cluster_id
        and bcg.gene_oid = g.gene_oid
        $dmClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgTermGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.gene_oid
        from gene_img_functions g $addfrom
        where g.function = ?
        $dmClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgPathwayGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    #    my $sql = qq{
    #        select distinct g.gene_oid
    #        from img_pathway_reactions ipr, img_reaction_catalysts irc,
    #            dt_img_term_path dtp, gene_img_functions g
    #        where ipr.pathway_oid = ?
    #        and ipr.rxn = irc.rxn_oid
    #        and irc.catalysts = dtp.term_oid
    #        and dtp.map_term = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #        union
    #        select distinct g.gene_oid
    #        from img_pathway_reactions ipr, img_reaction_t_components itc,
    #            dt_img_term_path dtp, gene_img_functions g
    #        where ipr.pathway_oid = ?
    #        and ipr.rxn = itc.rxn_oid
    #        and itc.term = dtp.term_oid
    #        and dtp.map_term = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #    };
    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.gene_oid
        from img_pathway_reactions ipr, img_reaction_catalysts irc, 
            gene_img_functions g
        where ipr.pathway_oid = ?
        and ipr.rxn = irc.rxn_oid
        and irc.catalysts = g.function
        $taxonClause
        $rclause
        $imgClause
        union
        select distinct g.gene_oid
        from img_pathway_reactions ipr, img_reaction_t_components itc, 
            gene_img_functions g
        where ipr.pathway_oid = ?
        and ipr.rxn = itc.rxn_oid
        and itc.term = g.function
        $taxonClause   
        $rclause   
        $imgClause   
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getImgPartsListGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
       select distinct g.gene_oid
       from img_parts_list_img_terms pt, gene_img_functions g $addfrom
       where pt.parts_list_oid = ?
       and pt.term = g.function
       $dmClause
       $taxonClause
       $rclause
       $imgClause
       order by g.gene_oid
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub fetchGene2BiosyntheticClusterMapping {
    my ( $dbh, $gene_oids_ref ) = @_;

    my $geneInnerClause = 
	OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );
    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

    my $sql = qq{
        select distinct g.gene_oid, g.taxon, bcg.cluster_id
        from gene g, bio_cluster_features_new bcg
        where g.gene_oid in ( $geneInnerClause )
        and g.gene_oid = bcg.gene_oid
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);

    my $extraurl_base = "$main_cgi?section=BiosyntheticDetail&page=cluster_detail";

    my %extracolumn;
    my %extracollink;
    for ( ;; ) {
        my ($gene_oid, $taxon, $cluster_id) = $cur->fetchrow();
        last if(!$gene_oid);

        my $extraurl = $extraurl_base . "&taxon_oid=$taxon&cluster_id=$cluster_id";
        my $link = alink($extraurl, $cluster_id);
        if ( exists $extracollink{$gene_oid} ) {
            $link = $extracollink{$gene_oid} . "<br/>" . $link;
        }
        $extracollink{$gene_oid} = $link;

        if ( exists $extracolumn{$gene_oid} ) {
            $cluster_id = $extracolumn{$gene_oid} . " <br/> " . $cluster_id;
        }
        $extracolumn{$gene_oid} = $cluster_id;
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $geneInnerClause =~ /gtt_num_id/i );

    return (\%extracolumn, \%extracollink);
}

sub fetchGene2ChromoCassetteMapping {
    my ( $dbh, $gene_oids_ref, $searchFilter ) = @_;

    my $geneInnerClause = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_ref );

    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

    my $sql = qq{
        select distinct g.gene_oid, g.taxon, gc.cassette_oid
        from gene g, gene_cassette_genes gc
        where g.gene_oid in ( $geneInnerClause )
        and g.gene_oid = gc.gene
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);

    my $extraurl_base = "$main_cgi?section=GeneCassette&page=cassetteBox&type=$searchFilter";

    my %extracolumn;
    my %extracollink;
    for ( ;; ) {
        my ($gene_oid, $taxon, $cassette_id) = $cur->fetchrow();
        last if(!$gene_oid);

        if ( $searchFilter eq 'cog' || $searchFilter eq 'pfam' ) {
            my $extraurl = $extraurl_base . "&gene_oid=$gene_oid&cassette_oid==$cassette_id";
            my $link = alink($extraurl, $cassette_id);
            if ( exists $extracollink{$gene_oid} ) {
                $link = $extracollink{$gene_oid} . "<br/>" . $link;
            }
            $extracollink{$gene_oid} = $link;
        }

        if ( exists $extracolumn{$gene_oid} ) {
            $cassette_id = $extracolumn{$gene_oid} . " <br/> " . $cassette_id;
        }
        $extracolumn{$gene_oid} = $cassette_id;            
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $geneInnerClause =~ /gtt_num_id/i );

    return (\%extracolumn, \%extracollink);
}

############################################################################
# printFfgFindFunctionsGenomeList - Show genome list of individual counts.
############################################################################
sub printFfgFindFunctionsGenomeList {
    my $searchFilter = param("searchFilter");
    my $data_type    = param("data_type");
    my $id           = param("id");
    my $subs         = param("sub");
    my $cnt          = param("cnt");
    my $restrictType = param("restrictType");
    my $domainfilter = param("domainfilter");
    my $seq_status   = param("seqstatus");

    # bug fix some list we should ignore genome cart filter list - ken
    my $ignoreFilter = param("ignoreFilter");
    $ignoreFilter = 0 if ( $ignoreFilter eq "" );

    printStatusLine( "Loading ...", 1 );

    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections     = ();
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }
    if ($ignoreFilter) {
        # bug fix
        @genomeFilterSelections = ();
    }

    my $dbh = dbLogin();

    my @dbTaxons   = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) = 
		MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }
    } elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
    } else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) =
              OracleUtil::getTaxonSelectionClauseBind
	      ( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile
		( $dbh, $taxonClause, \@bindList_txs );
            @metaTaxons = keys %taxon_in_file;
        }
    }

    #print "printFfgFunctionGenomeList dbTaxons: @dbTaxons<br/>\n";
    #print "printFfgFunctionGenomeList metaTaxons: @metaTaxons<br/>\n";

    my @taxon_oids;
    if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
        #no need to fetch things from database
    } else {
        my ( $taxonClause, @bindList_txs );
        my $bydomain = 0;
        if ( scalar(@dbTaxons) > 0 ) {
            ( $taxonClause, @bindList_txs ) = 
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon", \@dbTaxons );
        } elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
            $bydomain = $domainfilter;
        } else {
            ( $taxonClause, @bindList_txs ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon", \@genomeFilterSelections );
        }
        my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my ( $taxonClause1, @bindList_txs1 );
        if ( scalar(@dbTaxons) > 0 ) {
            ( $taxonClause1, @bindList_txs1 ) = 
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon_oid", \@dbTaxons );
        } elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
        } else {
            ( $taxonClause1, @bindList_txs1 ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon_oid", \@genomeFilterSelections );
        }
        my ( $rclause1, @bindList_ur1 ) = WebUtil::urClauseBind("g.taxon_oid");
        my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon_oid');

        if ($ignoreFilter) {
            # bug fix
            $taxonClause  = "";
            @bindList_txs = ();

            $taxonClause1  = "";
            @bindList_txs1 = ();
        }

        my $sql;
        my @bindList = ();
        ( $sql, @bindList ) =
	    getSeedGenomeListSql( $id, $subs, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if ( $searchFilter eq "seedProduct" );
        ( $sql, @bindList ) =
	    getSwissProtGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "swissProduct";
        ( $sql, @bindList ) = getGoGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "go";
        ( $sql, @bindList ) =
	    getCogGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "cog";
        ( $sql, @bindList ) =
	    getKogGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "kog";
        ( $sql, @bindList ) =
	    getPfamGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "pfam";
        ( $sql, @bindList ) =
	    getTigrfamGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $restrictType, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "tigrfam";
        ( $sql, @bindList ) =
	    getInterproGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
	    if $searchFilter eq "ipr";
        ( $sql, @bindList ) =
	    getEnzymeGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
	    if $searchFilter eq "ec_iex" || $searchFilter eq "ec_ex" || $searchFilter eq "ec";
        ( $sql, @bindList ) =
	    getTcGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
	    if $searchFilter eq "tc";
	
        if ( $searchFilter eq "keggEnzymes" ) {
            my $pathway_oid = param("pathway_oid");
            my $ec_number   = param("ec_number");
            $id = $ec_number;
            ( $sql, @bindList ) = getKeggPathEzGenomeListSql( $pathway_oid, $ec_number, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status );
        }
	
        ( $sql, @bindList ) =
	    getMetaCycGenomeListSql( $id, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, $bydomain, $seq_status )
	    if $searchFilter eq "metacyc";

        if (    $searchFilter eq "img_term_iex"
             || $searchFilter eq "img_term_synonyms_iex" )
        {
            if ( $searchFilter eq "img_term_iex" ) {
                my $term_oid = param("term_oid");
                $term_oid = FuncUtil::termOidPadded($term_oid) 
		    if ( $term_oid ne '' );
                $id = $term_oid if ( $term_oid ne '' );
            }
            ( $sql, @bindList ) =
		getImgTermGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status );
        }
        ( $sql, @bindList ) =
	    getImgPathwayGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter eq "img_pway_iex";
        ( $sql, @bindList ) =
	    getImgPartsListGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
	    if $searchFilter =~ /^img_plist/;
	
        if ( $enable_biocluster )  {
            ( $sql, @bindList ) =
		getBcGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
		if $searchFilter eq "bc";
            ( $sql, @bindList ) =
		getNpGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
		if $searchFilter eq "np";
            ( $sql, @bindList ) =
		getImgCompoundGenomeListSql( $id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
		if $searchFilter eq "img_cpd";
        }

        #print "printFfgFindFunctionsGenomeList sql: $sql<br/>";
        #print "printFfgFindFunctionsGenomeList bindList: @bindList<br/>";

        if ( blankStr($sql) ) {
            webDie( "printFfgFunctionsGenomeList: Unknown search filter '$searchFilter'\n" );
        }

        @taxon_oids = HtmlUtil::fetchGenomeList( $dbh, $sql, $verbose, @bindList );

        #print "printFfgFindFunctionsGenomeList taxon_oids size: " . @taxon_oids . "<br/>";

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
	    if ( $taxonClause =~ /gtt_num_id/i );
    }

    if ( $include_metagenomes && scalar(@metaTaxons) > 0 && 
	 isMetaSupported($searchFilter) ) {
        if ( $new_func_count || $enable_biocluster ) {
            my ( $taxonClause, @bindList_txs ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon_oid", \@metaTaxons );
            my ($rclause, @bindList_ur) = WebUtil::urClauseBind("g.taxon_oid");
            my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

            my $sql;
            my @bindList = ();

            if ( $new_func_count ) {
                my $datatypeClause;
                if ($data_type eq 'assembled' || $data_type eq 'unassembled') {
                    $datatypeClause = " and g.data_type = '$data_type' ";
                }              

                ( $sql, @bindList ) =
                  getCogGenomeListSql_merfs( $id, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                  if $searchFilter eq "cog";
    
                ( $sql, @bindList ) =
                  getPfamGenomeListSql_merfs( $id, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                  if $searchFilter eq "pfam";
    
                ( $sql, @bindList ) =
                  getTigrfamGenomeListSql_merfs( $id, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                  if $searchFilter eq "tigrfam";
    
                ( $sql, @bindList ) =
                  getEnzymeGenomeListSql_merfs( $id, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                  if $searchFilter eq "ec_iex" || $searchFilter eq "ec_ex" || $searchFilter eq "ec";
    
                if ( $searchFilter eq "keggEnzymes" ) {
                    my $pathway_oid = param("pathway_oid");
                    my $ec_number   = param("ec_number");
                    $id = $ec_number;
                    ( $sql, @bindList ) = getKeggPathEzGenomeListSql_merfs( $pathway_oid, $ec_number, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );
                }
            }


            if ( $enable_biocluster )  {
                my ( $taxonClause2, @bindList_txs2 ) = OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@metaTaxons );
                my ( $rclause2, @bindList_ur2 ) = urClauseBind("g.taxon");
                my $imgClause2 = WebUtil::imgClauseNoTaxon('g.taxon');

                ( $sql, @bindList ) =
                  getBcGenomeListSql_merfs( $id, $taxonClause2, $rclause2, $imgClause2, \@bindList_txs2, \@bindList_ur2 )
                  if $searchFilter eq "bc";
                ( $sql, @bindList ) =
                  getNpGenomeListSql_merfs( $id, $taxonClause2, $rclause2, $imgClause2, \@bindList_txs2, \@bindList_ur2 )
                  if $searchFilter eq "np";
            }

            #print "printFfgFunctionGenomeList() merfs sql: $sql<br/>";
            #print "printFfgFunctionGenomeList() merfs bindList: @bindList<br/>";

            if ( blankStr($sql) ) {
                webDie( "printFfgFindFunctionsGenomeList: Unknown search filter '$searchFilter'\n" );
            }

            my @meta_taxons = HtmlUtil::fetchGenomeList
		( $dbh, $sql, $verbose, @bindList );
            push( @taxon_oids, @meta_taxons );

            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $taxonClause =~ /gtt_num_id/i );

        } else {

            foreach my $toid (@metaTaxons) {
                my %genes = MetaUtil::getTaxonFuncGenes( $toid, '', $id );
                if ( scalar( keys %genes ) > 0 ) {
                    push( @taxon_oids, $toid );
                }
            }

        }
    }

    #print "printFfgFindFunctionsGenomeList() taxon_oids size: " . @taxon_oids . "<br/>\n";
    #print "printFfgFindFunctionsGenomeList() taxon_oids: @taxon_oids<br/>\n";

    my $restrictText;
    if ( $searchFilter eq "cog" || $searchFilter eq "kog" || 
	 $searchFilter eq "pfam" || $searchFilter eq "tigrfam" ) {
        if ( $restrictType eq 'bio_cluster' ) {
            $restrictText = "(Restrict to Genes in Biosynthetic Cluster)";
        }
        elsif ( $restrictType eq 'chrom_cassette' ) {
            $restrictText = "(Restrict to Genes in Chromosomal Cassette)";
        }
    }

    my $name = $function2Name{$searchFilter};
    $name = "IMG Term" if ( $searchFilter eq "img_term_iex" );
    my $title    = "Genomes In $name $restrictText";
    my $subtitle = "$name ID: " . $id;

    if ( $searchFilter eq "tc" ) {
        my $tcnum = $id;
        $tcnum =~ s/TC://;
        my $url = $tc_base_url . $tcnum;
        $subtitle = "TC ID: " . alink( $url, $id );
    } elsif ( $searchFilter eq "img_pway_iex" ) {
        my $psql   =
	    "select pathway_name from img_pathway where pathway_oid = ?";
        my $cur    = execSql( $dbh, $psql, $verbose, $id );
        my ($name) = $cur->fetchrow();

        my $url = "$main_cgi?section=ImgPwayBrowser"
	    . "&page=imgPwayDetail&pway_oid=$id";
        $subtitle = "IMG Pathway ID: " . alink( $url, $name );
    } elsif ( $searchFilter eq "np" ) {
        my $url = "$main_cgi?section=NaturalProd&page=naturalProd&np_id=$id";
        $subtitle = "SM ID: " . alink( $url, $id );
    } elsif ( $searchFilter eq "img_cpd" ) {
        my $url = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$id";
        $subtitle = "IMG Compound ID: " . alink( $url, $id );
    }

    if ( $searchFilter eq "seedProduct" ) {
        my @subs = split(';<br/>', $subs);
        my $substr = join("; ", @subs);
        my $subtitle = "<u>Product Name</u>: $id<br/>"
                     . "<u>Subsystem(s)</u>: $substr";

        my $taxonClause = WebUtil::txsClause( "g.taxon", $dbh )
            if !$ignoreFilter;
        $subtitle .= "<p>*Showing genomes found in genome cart only</p>"
            if $taxonClause ne "";
        HtmlUtil::printGenomeListHtmlTable
	    ( $title, $subtitle, $dbh, \@taxon_oids );
	    
    } elsif ( $searchFilter eq "cog" || $searchFilter eq "kog" || 
	      $searchFilter eq "pfam" || $searchFilter eq "tigrfam" ||
	      $searchFilter eq "ec" || $searchFilter eq "bc" ) {
        my $sec;
        my $pg;
        if ( $searchFilter eq "cog" ) {
            my $url = "http://www.ncbi.nlm.nih.gov/COG/grace/wiew.cgi?$id";
            $subtitle = "COG ID: " . alink( $url, $id );
            $sec      = 'CogCategoryDetail';
            $pg       = 'ccdCOGPhyloDist';
        } elsif ( $searchFilter eq "kog" ) {
            my $url = "http://www.ncbi.nlm.nih.gov/COG/grace/shokog.cgi?$id";
            $subtitle = "KOG ID: " . alink( $url, $id );
            $sec      = 'CogCategoryDetail';
            $pg       = 'ccdKOGPhyloDist';
        } elsif ( $searchFilter eq "pfam" ) {
            my $url = "http://pfam.sanger.ac.uk/family/PF" . substr( $id, 4 );
            $subtitle = "Pfam ID: " . alink( $url, $id );
            $sec = 'PfamCategoryDetail';
            $pg  = 'pcdPhyloDist';
        } elsif ( $searchFilter eq "tigrfam" ) {
            my $url = "http://cmr.jcvi.org/tigr-scripts/CMR/HmmReport.cgi?hmm_acc=$id";
            $subtitle = "Tigrfam ID: " . alink( $url, $id );
        } elsif ( $searchFilter eq "ec" ) {
            $subtitle = "Enzyme: " . $id;
        }

        if ( $include_metagenomes && isMetaSupported($searchFilter) && 
	     scalar(@metaTaxons) > 0 ) {
            $subtitle .= "<br/>\nMER-FS Metagenome: " . $data_type;
        }
            
        if ( $searchFilter eq "cog" || $searchFilter eq "kog" || 
	     $searchFilter eq "pfam" ) {

            printMainForm();
            print "<h1>$title</h1>";
            print "<p>$subtitle</p>";
            WebUtil::buttonMySubmit( "Phylogenetic Distribution",
                                     "medbutton", 'setTaxonFilter', 
				     'setTaxonFilter', $sec, $pg );
            print "<br/>";

            if ( $restrictType eq 'bio_cluster' ) {
                my ($extracolumn_href, $extracollink_href) = 
		    fetchGenome2BiosyntheticClusterMapping($dbh, \@taxon_oids);
                #print Dumper($extracolumn_href);
                #print "<br/>\n";
                #print Dumper($extracollink_href);
                #print "<br/>\n";
                HtmlUtil::printGenomeListHtmlTable
		    ( '', '', $dbh, \@taxon_oids, '', 1, 
		      'Biosynthetic Cluster', $extracolumn_href,
		      $extracollink_href );
            }
            else {
                HtmlUtil::printGenomeListHtmlTable
		    ( '', '', $dbh, \@taxon_oids, '', 1 );
            }
                
            print hiddenVar( "cog_id",  $id ) if ( $searchFilter eq "cog" );
            print hiddenVar( "kog_id",  $id ) if ( $searchFilter eq "kog" );
            print hiddenVar( "pfam_id", $id ) if ( $searchFilter eq "pfam" );
            print hiddenVar( "nocat", 'yes' );
            print end_form;
        } else {
            if ( $restrictType eq 'bio_cluster' ) {
                my ($extracolumn_href, $extracollink_href) = 
		    fetchGenome2BiosyntheticClusterMapping($dbh, \@taxon_oids);
                #print Dumper($extracolumn_href);
                #print "<br/>\n";
                #print Dumper($extracollink_href);
                #print "<br/>\n";
                HtmlUtil::printGenomeListHtmlTable
		    ( $title, $subtitle, $dbh, \@taxon_oids, '', '',
		      'Biosynthetic Cluster', $extracolumn_href,
		      $extracollink_href );
            }
            else {
                HtmlUtil::printGenomeListHtmlTable
		    ( $title, $subtitle, $dbh, \@taxon_oids );
            }
        }

    } else {
        HtmlUtil::printGenomeListHtmlTable
	    ( $title, $subtitle, $dbh, \@taxon_oids );
    }
}

sub getSeedGenomeListSql {
    my ( $id, $subs, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my @subs = split(';<br/>', $subs);
    my $nsubs = scalar @subs;

    my $subWhereClause;
    if ( $subs eq '' ) {
        #$subWhereClause = "and g.subsystem is null ";
    } elsif ( $nsubs == 1) {
        $subWhereClause = "and g.subsystem = ? ";
    } else {
        my $substr = WebUtil::joinSqlQuoted(",", @subs);
        #$subWhereClause = "and g.subsystem in ($substr) ";
    }

    #ANNA: todo: if one of many subsystems is null, need to add it in...
    my $sql = qq{
        select distinct g.taxon
        from gene_seed_names g
        where g.product_name = ?
        $subWhereClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    push( @bindList_sql, $subs ) if ( $subs ne '' && $nsubs == 1 );
    my @bindList = ();
    processBindList
	( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getSwissProtGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon
        from gene_swissprot_names gs, gene g
        where gs.product_name = ?
        and gs.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGoGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon
        from gene_go_terms ggt, gene g
        where ggt.go_id = ?
        and ggt.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getCogGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $restrictType, $taxonClause1, $rclause1,
	 $imgClause1, $bindList_txs_ref1, $bindList_ur_ref1,
	 $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
	$addfrom = ", taxon tx ";
	$dmClause = " and tx.domain = '$bydomain' ";
	$dmClause = " and tx.genome_type = 'isolate' "
	    if $bydomain eq "isolates";
	$dmClause .= " and tx.seq_status = '$seq_status'"
	    if $seq_status ne "";
	$taxonClause1 = " and tx.taxon_oid = g.taxon ";
	$taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }
    
    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_cog_groups g, bio_cluster_features_new bcg $addfrom
            where g.cog = ?
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_cog_groups g, gene_cassette_genes gc $addfrom
            where g.cog = ?
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    else {
        $sql = qq{
            select /*+ result_cache */ distinct g.taxon_oid
            from mv_taxon_cog_stat g $addfrom
            where g.cog = ? 
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    if ($restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette') {
        processBindList( \@bindList, \@bindList_sql, 
			 $bindList_txs_ref1, $bindList_ur_ref1 );
    }
    else {
        processBindList( \@bindList, \@bindList_sql, 
			 $bindList_txs_ref, $bindList_ur_ref );
    }

    return ( $sql, @bindList );
}

sub getCogGenomeListSql_merfs {
    my ( $id, $taxonClause, $datatypeClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon_oid
        from TAXON_COG_COUNT g
        where g.func_id = ?
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getKogGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $restrictType, $taxonClause1, $rclause1,
	 $imgClause1, $bindList_txs_ref1, $bindList_ur_ref1,
	 $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause1 = " and tx.taxon_oid = g.taxon ";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_kog_groups g, bio_cluster_features_new bcg $addfrom
            where g.kog = ?
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_kog_groups g, gene_cassette_genes gc $addfrom
            where g.kog = ?
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    else {
        $sql = qq{
            select /*+ result_cache */ distinct g.taxon_oid
            from mv_taxon_kog_stat g $addfrom
            where g.kog = ? 
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    if ($restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette') {
        processBindList( \@bindList, \@bindList_sql, 
			 $bindList_txs_ref1, $bindList_ur_ref1 );
    }
    else {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref, $bindList_ur_ref );
    }

    return ( $sql, @bindList );
}

sub getPfamGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $restrictType, $taxonClause1, $rclause1,
	 $imgClause1, $bindList_txs_ref1, $bindList_ur_ref1,
	 $bydomain, $seq_status ) = @_;
    
    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause1 = " and tx.taxon_oid = g.taxon ";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_pfam_families g, bio_cluster_features_new bcg $addfrom
            where g.pfam_family = ?
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_pfam_families g, gene_cassette_genes gc $addfrom
            where g.pfam_family = ?
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    else {
        $sql = qq{
            select /*+ result_cache */ distinct g.taxon_oid
            from mv_taxon_pfam_stat g $addfrom
            where g.pfam_family = ?
            $dmClause
            $taxonClause
            $rclause
            $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    if ($restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette') {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref1, $bindList_ur_ref1 );
    }
    else {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref, $bindList_ur_ref );
    }

    return ( $sql, @bindList );
}

sub getPfamGenomeListSql_merfs {
    my ( $id, $taxonClause, $datatypeClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon_oid
        from TAXON_PFAM_COUNT g
        where g.func_id = ?
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getTigrfamGenomeListSql_old {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    #    my $sql = qq{
    #       select distinct g.taxon
    #       from gene_tigrfams g
    #       where g.ext_accession = ?
    #       $taxonClause
    #       $rclause
    #       $imgClause
    #    };
    my $sql = qq{
       select /*+ result_cache */ distinct g.taxon_oid
       from mv_taxon_tfam_stat g
       where g.ext_accession = ?
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getTigrfamGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $restrictType, $taxonClause1, $rclause1,
	 $imgClause1, $bindList_txs_ref1, $bindList_ur_ref1,
	 $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause1 = " and tx.taxon_oid = g.taxon ";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql;
    if ( $restrictType eq 'bio_cluster' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_tigrfams g, bio_cluster_features_new bcg $addfrom
            where g.ext_accession = ?
            and g.gene_oid = bcg.gene_oid
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    elsif ( $restrictType eq 'chrom_cassette' ) {
        $sql = qq{
            select distinct g.taxon
            from gene_tigrfams g, gene_cassette_genes gc $addfrom
            where g.ext_accession = ?
            and g.gene_oid = gc.gene
            $dmClause
            $taxonClause1
            $rclause1
            $imgClause1
        };
    }
    else {
        $sql = qq{
           select /*+ result_cache */ distinct g.taxon_oid
           from mv_taxon_tfam_stat g $addfrom
           where g.ext_accession = ?
           $dmClause
           $taxonClause
           $rclause
           $imgClause
        };
    }

    my @bindList_sql = ("$id");
    my @bindList     = ();
    if ($restrictType eq 'bio_cluster' || $restrictType eq 'chrom_cassette') {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref1, $bindList_ur_ref1 );
    }
    else {
        processBindList( \@bindList, \@bindList_sql,
			 $bindList_txs_ref, $bindList_ur_ref );
    }

    return ( $sql, @bindList );
}

sub getTigrfamGenomeListSql_merfs {
    my ( $id, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $sql = qq{
       select distinct g.taxon_oid
       from TAXON_TIGR_COUNT g
       where g.func_id = ? 
       $taxonClause
       $datatypeClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getInterproGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
       select /*+ result_cache */ distinct g.taxon_oid
       from mv_taxon_ipr_stat g $addfrom
       where g.iprid = ? 
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };
    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getEnzymeGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
       select /*+ result_cache */ distinct g.taxon_oid
       from mv_taxon_ec_stat g $addfrom
       where g.enzyme = ?
       $dmClause
       $taxonClause
       $rclause
       $imgClause
   };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getEnzymeGenomeListSql_merfs {
    my ( $id, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
       select distinct g.taxon_oid
       from TAXON_EC_COUNT g
       where g.func_id = ?
       $taxonClause
       $datatypeClause
       $rclause
       $imgClause
   };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getTcGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
       select /*+ result_cache */ distinct g.taxon_oid
       from mv_taxon_tc_stat g $addfrom
       where g.tc_family = ?
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKeggPathEzGenomeListSql {
    my ( $pathway_oid, $ec_number, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
       select distinct g.taxon_oid
       from image_roi roi, image_roi_ko_terms rk, 
            ko_term_enzymes kt, mv_taxon_ec_stat g $addfrom
       where roi.pathway = ? 
       and roi.roi_id = rk.roi_id
       and rk.ko_terms = kt.ko_id
       and kt.enzymes = g.enzyme
       and g.enzyme = ?
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ( "$pathway_oid", "$ec_number" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKeggPathEzGenomeListSql_merfs {
    my ( $pathway_oid, $ec_number, $taxonClause, $datatypeClause, 
	 $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon_oid
        from image_roi roi, image_roi_ko_terms rk, 
             ko_term_enzymes kt, TAXON_EC_COUNT g
        where roi.pathway = ? 
        and roi.roi_id = rk.roi_id
        and rk.ko_terms = kt.ko_id
        and kt.enzymes = g.func_id
        and g.func_id = ?
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
   };

    my @bindList_sql = ( "$pathway_oid", "$ec_number" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getBcGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $sql = qq{
        select distinct g.taxon
        from bio_cluster_features_new bcg, gene g
        where bcg.cluster_id = ?
        and bcg.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getBcGenomeListSql_merfs {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon
        from bio_cluster_new g
        where g.cluster_id = ?
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getNpGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon
        from natural_product np, bio_cluster_features_new bcg, gene g
        where np.np_id = ?
        and np.cluster_id = bcg.cluster_id
        and bcg.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getMetaCycGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
	$dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
       select distinct g.taxon_oid
       from biocyc_pathway bp, mv_taxon_metacyc_stat g $addfrom
       where bp.unique_id = ?
       and bp.unique_id = g.pwy_id
       $dmClause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgCompoundGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.taxon
        from natural_product np, bio_cluster_features_new bcg, 
             gene g $addfrom
        where np.compound_oid = ?
        and np.cluster_id = bcg.cluster_id
        and bcg.gene_oid = g.gene_oid
        $dmClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgTermGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql = qq{
        select distinct g.taxon
        from gene_img_functions g $addfrom
        where g.function = ?
        $dmClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getImgPathwayGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    #    my $sql = qq{
    #        select distinct g.taxon
    #        from img_pathway_reactions ipr, img_reaction_catalysts irc,
    #            dt_img_term_path dtp, gene_img_functions g
    #        where ipr.pathway_oid = ?
    #        and ipr.rxn = irc.rxn_oid
    #        and irc.catalysts = dtp.term_oid
    #        and dtp.map_term = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #        union
    #        select distinct g.taxon
    #        from img_pathway_reactions ipr, img_reaction_t_components itc,
    #            dt_img_term_path dtp, gene_img_functions g
    #        where ipr.pathway_oid = ?
    #        and ipr.rxn = itc.rxn_oid
    #        and itc.term = dtp.term_oid
    #        and dtp.map_term = g.function
    #        $taxonClause
    #        $rclause
    #        $imgClause
    #    };
    my $sql = qq{
        select distinct g.taxon
        from img_pathway_reactions ipr, img_reaction_catalysts irc, 
            gene_img_functions g
        where ipr.pathway_oid = ?
        and ipr.rxn = irc.rxn_oid
        and irc.catalysts = g.function
        $taxonClause
        $rclause
        $imgClause
        union
        select distinct g.taxon
        from img_pathway_reactions ipr, img_reaction_t_components itc, 
            gene_img_functions g
        where ipr.pathway_oid = ?
        and ipr.rxn = itc.rxn_oid
        and itc.term = g.function
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getImgPartsListGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    #    my $sql = qq{
    #       select distinct g.taxon
    #       from img_parts_list_img_terms pt, dt_img_term_path dtp, gene_img_functions g
    #       where pt.parts_list_oid = ?
    #       and pt.term = dtp.term_oid
    #       and dtp.map_term = g.function
    #       $taxonClause
    #       $rclause
    #       $imgClause
    #    };
    my $sql = qq{
       select distinct g.taxon
       from img_parts_list_img_terms pt, gene_img_functions g
       where pt.parts_list_oid = ?
       and pt.term = g.function
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$id");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub fetchGenome2BiosyntheticClusterMapping {
    my ( $dbh, $taxon_oids_ref ) = @_;

    my $taxonInnerClause = OracleUtil::getNumberIdsInClause( $dbh, @$taxon_oids_ref );

    my $rclause = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

    my $sql = qq{
        select distinct g.taxon, g.cluster_id
        from bio_cluster_new g
        where g.taxon in ( $taxonInnerClause )
        $rclause
        $imgClause
    };
    my $cur = execSql($dbh, $sql, $verbose);

    my $extraurl_base = "$main_cgi?section=BiosyntheticDetail&page=cluster_detail";

    my %extracolumn;
    my %extracollink;
    for ( ;; ) {
        my ($taxon, $cluster_id) = $cur->fetchrow();
        last if(!$taxon);

        my $extraurl = $extraurl_base . "&taxon_oid=$taxon&cluster_id=$cluster_id";
        my $link = alink($extraurl, $cluster_id);
        if ( exists $extracollink{$taxon} ) {
            $link = $extracollink{$taxon} . " " . $link;
        }
        $extracollink{$taxon} = $link;

        if ( exists $extracolumn{$taxon} ) {
            $cluster_id = $extracolumn{$taxon} . " " . $cluster_id;
        }
        $extracolumn{$taxon} = $cluster_id;
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonInnerClause =~ /gtt_num_id/i );

    return (\%extracolumn, \%extracollink);
}


############################################################################
# printFfoGenomeSearchCogs - Print top level cog/kog categories and cogs
#   from genome search.
############################################################################
sub printFfoGenomeSearchCogs {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $searchTerm = param("${og}SearchTerm");

    WebUtil::printSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLiteral = $searchTerm;
    $searchTerm =~ tr/A-Z/a-z/;

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
      select cf.function_code, cf.definition,  
         c.${og}_id, c.${og}_name, count( distinct g.taxon )
      from ${og}_function cf, ${og}_functions cfs, ${og} c,
         gene_${og}_groups gcg, gene g
      where cf.function_code = cfs.functions
      and cfs.${og}_id = c.${og}_id
      and c.${og}_id = gcg.${og}
      and gcg.gene_oid = g.gene_oid
      and( lower( cf.definition ) like ? or
           lower( c.${og}_name ) like ? or
           lower( c.${og}_id ) like ? 
      )
      $taxonClause
      $rclause
      $imgClause
      group by cf.definition, cf.function_code, c.${og}_name, c.${og}_id
   };
    my @bindList = ( "%$searchTerm%", "%$searchTerm%", "%$searchTerm%" );
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $count = 0;
    printMainForm();
    print "<h1>${OG} Search Results</h1>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    my $old_function_code;
    my %cogIdCount;
    my $count = 0;
    for ( ; ; ) {
        my ( $function_code, $definition, $cog_id, $cog_name, $org_count ) = $cur->fetchrow();
        last if !$function_code;
        $count++;
        if ( $count == 1 ) {
            print "The number of genomes in a ${OG} is shown in parentheses.\n";
            print "<br/>\n";
        }
        if ( $old_function_code ne $function_code ) {
            my $url = "$main_cgi?section=CogCategoryDetail" . "&page=${og}CategoryDetail";
            $url .= "&function_code=$function_code";
            print "<br/>\n";
            print "<b>\n";
            print "<a href='$url'>\n";
            print highlightMatchHTML2( $definition, $searchTermLiteral );
            print "</a>\n";
            print "</b>\n";
            print "<br/>\n";
        }
        print nbsp(4);
        print highlightMatchHTML2( "$cog_id - $cog_name", $searchTermLiteral );
        my $url = "$section_cgi&page=ffo${OG}Orgs";
        $url .= "&${og}_id=$cog_id";
        print " (" . alink( $url, $org_count ) . ")<br/>\n";
        $cogIdCount{$cog_id} = 1;
        $old_function_code = $function_code;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    #$dbh->disconnect();

    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
    }
    print "</p>\n";

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    my $cogCount = keys(%cogIdCount);
    printStatusLine( "$cogCount ${OG} assignments retrieved.", 2 );
    print end_form();

}

############################################################################
# printFfoCogOrgs - Print genomes under a COG/KOG.
############################################################################
sub printFfoCogOrgs {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_id = param("${og}_id");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
      select tx.taxon_oid, tx.taxon_display_name, count( distinct g.gene_oid )
      from ${og}_function cf, ${og}_functions cfs, ${og} c,
         gene_${og}_groups gcg, gene g, taxon tx
      where cf.function_code = cfs.functions
      and cfs.${og}_id = c.${og}_id
      and c.${og}_id = gcg.${og}
      and c.${og}_id = ? 
      and gcg.gene_oid = g.gene_oid
      and g.taxon = tx.taxon_oid
      $taxonClause
      $rclause
      $imgClause
      group by tx.taxon_display_name, tx.taxon_oid
    };
    my @bindList = ("$cog_id");
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    printMainForm();
    print "<h1>Genomes with $cog_id</h1>\n";
    print "<p>\n";
    my $name = cogName( $dbh, $cog_id, $og );
    print "Genomes with <i>" . escHtml($name) . "</i>.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my $baseUrl = "$section_cgi&page=ffo${OG}Orgs";
    $baseUrl .= "&${og}_id=$cog_id";
    my $cachedTable = new CachedTable( "ffo${OG}Orgs", $baseUrl );
    $cachedTable->addColSpec( "Genome",     "asc",  "left" );
    $cachedTable->addColSpec( "Gene Count", "desc", "right" );
    my $sdDelim = CachedTable::getSdDelim();
    my $count   = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $gene_count ) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";
        my $r = $taxon_display_name . $sdDelim . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=ffo${OG}OrgGenes";
        $url .= "&${og}_id=$cog_id";
        $url .= "&taxon_oid=$taxon_oid";

        $r .= $gene_count . $sdDelim . alink( $url, $gene_count ) . "\t";
        $cachedTable->addRow($r);
    }
    $cachedTable->printTable();
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();

}

############################################################################
# printFfoCogOrgGenes - Print genomes under a COG/KOG.
############################################################################
sub printFfoCogOrgGenes {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_id    = param("${og}_id");
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
      select distinct g.gene_oid, g.gene_display_name
      from ${og}_function cf, ${og}_functions cfs, ${og} c,
         gene_${og}_groups gcg, gene g, taxon tx
      where cf.function_code = cfs.functions
      and cfs.${og}_id = c.${og}_id
      and c.${og}_id = gcg.${og}
      and c.${og}_id = ? 
      and gcg.gene_oid = g.gene_oid
      and g.taxon = tx.taxon_oid
      and g.taxon = ? 
      $taxonClause
      $rclause
      $imgClause
    };
    my @bindList = ( "$cog_id", "$taxon_oid" );
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    my @gene_oids;
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Genes for $cog_id</h1>\n";
    printGeneCartFooter() if ( $count > 10 );
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    printStatusLine( "$count genes(s) retrieved.", 2 );
    print end_form();

}

############################################################################
# printFfgCogSearchGeneList - Print gene list of a specific COG/KOG from search.
############################################################################
sub printFfgCogSearchGeneList {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_id = param("${og}_id");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $geneSearchTaxonFilter      = getSessionParam("geneSearchTaxonFilter");
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections     = ();
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
    	select distinct g.gene_oid, g.gene_display_name
    	from ${og}_function cf, ${og}_functions cfs, ${og} c,
    	     gene_${og}_groups gcg, gene g
    	where cf.function_code = cfs.functions
    	and cfs.${og}_id = c.${og}_id
    	and c.${og}_id = gcg.${og}
    	and c.${og}_id = ? 
    	and gcg.gene_oid = g.gene_oid
    	$taxonClause
    	$rclause
    	$imgClause
    };
    my @bindList = ("$cog_id");
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    #print "\@bindList: @bindList<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @gene_oids = ();
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Genes for $cog_id</h1>\n";
    printGeneCartFooter() if ( $count > 10 );
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

sub printFindKo {
    my $searchFilter = param("searchFilter");
    my $searchTerm   = param("ffgSearchTerm");
    my $seq_status   = param("seqstatus");
    my $domainfilter = param("domainfilter");
    my $taxonChoice  = param("taxonChoice");
    my $data_type    = param("q_data_type");
    if ( ! $data_type ) {
        $data_type = param("data_type");
    }

    # allow searching by selected domain or by all isolates:
    my $selectionType = param("selectType");
    if ($selectionType eq "selDomain") {
        $seq_status = param("seqstatus0");
        $domainfilter = param("domainfilter0");
    } elsif ($selectionType eq "allIsolates") {
        $seq_status = param("seqstatus0");
        $domainfilter = "isolates";
    }

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");
    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    my $dbh = dbLogin();

    my @dbTaxons   = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) 
                = MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }
    } elsif ($selectionType eq "selDomain" || 
	     $selectionType eq "allIsolates") {
        # no need to get taxons
    } else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) 
                = OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile
		( $dbh, $taxonClause, \@bindList_txs );
            @metaTaxons = keys %taxon_in_file;
        }
    }
    #print "printFindKo() dbTaxons: @dbTaxons<br/>\n";
    #print "printFindKo() metaTaxons: @metaTaxons<br/>\n";

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    printMainForm();
    my $title = $function2Name{$searchFilter};
    print "<h1>$title Search Results</h1>\n";
    print "<p>\n";
    print "<u>Keyword</u>: " . $searchTerm;
    if ( scalar(@metaTaxons) > 0 ) {
        HtmlUtil::printMetaDataTypeSelection($data_type, 1);
    }
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $count = 0;
    my @recs;

    # cache file
    my $file      = param("file");
    my $cacheFile = getCacheFile($file);
    if ( $file ne "" && -e $cacheFile ) {
        #print "cache file version $file <br/>";
        ( $count, @recs ) = readCacheFile( $cacheFile, $count, @recs );
    } else {
        my ( $merfs_genecnt_href, $merfs_genomecnt_href, $func_id2Name_href, $func_id2Defn_href );
        if ( $include_metagenomes && scalar(@metaTaxons) > 0 &&
	     isMetaSupported($searchFilter) ) {
            if ($new_func_count) {
                my ( $taxonClause, @bindList_txs ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@metaTaxons );
                my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon_oid");
                my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

                my $datatypeClause;
                if ($data_type eq 'assembled' || $data_type eq 'unassembled') {
                    $datatypeClause = " and g.data_type = '$data_type' ";
                }              

                my $sql;
                my @bindList = ();
                ( $sql, @bindList ) =
                  getKoIdSql_merfs( $searchTerm, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                  if ( $searchFilter eq "koid" );

                ( $sql, @bindList ) =
                  getKoNameSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                  if ( $searchFilter eq "koname" );

                ( $sql, @bindList ) =
                  getKoDefnSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur )
                  if ( $searchFilter eq "kodefn" );

                #print "printFindKo() merfs sql: $sql<br/>";
                #print "printFindKo() merfs bindList: @bindList<br/>";

                if ( blankStr($sql) ) {
                    webDie( "printFindKo: Unknown search filter '$searchFilter'\n" );
                }

                my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                for ( ; ; ) {
                    my ( $id, $name, $defn, $gcnt, $tcnt ) = $cur->fetchrow();
                    last if ( !$id );

                    $func_id2Name_href->{$id}    = $name;
                    $func_id2Defn_href->{$id}    = $defn;
                    $merfs_genecnt_href->{$id}   = $gcnt;
                    $merfs_genomecnt_href->{$id} = $tcnt;

                    #print "printFindKo() merfs added id: $id<br/>";
                }
                $cur->finish();
                OracleUtil::truncTable( $dbh, "gtt_num_id" )
                  if ( $taxonClause =~ /gtt_num_id/i );

            } else {
                # TODO mer-fs using file
            }
        }

        if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
            # no need to fetch things from database
        } else {
            my ( $taxonClause, @bindList_txs );
            my $bydomain = 0;
            if ( scalar(@dbTaxons) > 0 ) {
                ( $taxonClause, @bindList_txs ) = 
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@dbTaxons );
            } elsif ($selectionType eq "selDomain" || 
		     $selectionType eq "allIsolates") {
                # no need to get taxons
                $bydomain = $domainfilter;
            } else {
                ( $taxonClause, @bindList_txs ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@genomeFilterSelections );
            }

            my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon_oid");
            my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

            my $sql;
            my @bindList = ();
            ( $sql, @bindList ) =
              getKoIdSql( $searchTerm, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if ( $searchFilter eq "koid" );
            ( $sql, @bindList ) =
              getKoNameSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if ( $searchFilter eq "koname" );
            ( $sql, @bindList ) =
              getKoDefnSql( $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur, $bydomain, $seq_status )
              if ( $searchFilter eq "kodefn" );

            #print "printFindKo() sql: $sql<br/>";
            #print "printFindKo() bindList: @bindList<br/>";

            if ( blankStr($sql) ) {
                webDie("printFindKo: Unknown search filter '$searchFilter'\n");
            }

            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $ko_id, $ko_name, $ko_defn, $gcnt, $tcnt ) 
		    = $cur->fetchrow();
                last if !$ko_id;

                $count++;
                my $r = "$ko_id\t";
                $r .= "$ko_name\t";
                $r .= "$ko_defn\t";

                if ( $include_metagenomes && scalar(@metaTaxons) > 0 &&
		     isMetaSupported($searchFilter) ) {
                    if ( exists $merfs_genecnt_href->{$ko_id} ) {
                        my $gcnt2 = $merfs_genecnt_href->{$ko_id};
                        my $tcnt2 = $merfs_genomecnt_href->{$ko_id};
                        $gcnt += $gcnt2;
                        $tcnt += $tcnt2;
                        delete $merfs_genecnt_href->{$ko_id};
                        delete $merfs_genomecnt_href->{$ko_id};
                    }
                }
                $r .= "$gcnt\t";
                $r .= "$tcnt\t";
                push( @recs, $r );
            }
            $cur->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $taxonClause =~ /gtt_num_id/i );
        }

        foreach my $key ( keys %$merfs_genecnt_href ) {
            my $name    = $func_id2Name_href->{$key};
            my $ko_defn = $func_id2Defn_href->{$key};
            my $gcnt2   = $merfs_genecnt_href->{$key};
            my $tcnt2   = $merfs_genomecnt_href->{$key};
            my $rec     = "$key\t";
            $rec .= "$name\t";
            $rec .= "$ko_defn\t";
            $rec .= "$gcnt2\t";
            $rec .= "$tcnt2\t";
            push( @recs, $rec );
            $count++;
        }
    }

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
        printStatusLine( "$count loaded.", 2 );
        print end_form();
        return;
    }

    my $it = new InnerTable( 1, "keggFunction$$", "keggFunction", 1 );
    my $sd = $it->getSdDelim();    # sort delimit
    $it->addColSpec("Select");
    $it->addColSpec( "KO ID",         "asc",  "left" );
    $it->addColSpec( "KO Name",       "asc",  "left" );
    $it->addColSpec( "KO Definition", "asc",  "left" );
    $it->addColSpec( "Gene Count",    "desc", "right" );
    $it->addColSpec( "Genome Count",  "desc", "right" );

    foreach my $r (@recs) {
        my ( $ko_id, $ko_name, $ko_defn, $gcnt, $tcnt ) = split( /\t/, $r );

        my $row;

        my $tmp = "<input type='checkbox' name='func_id'  value='$ko_id' />";
        $row .= $sd . $tmp . "\t";

        my $matchText;
        $matchText = $ko_id;
        $matchText = highlightMatchHTML3( $ko_id, $searchTerm )
          if ( $searchFilter eq "koid" );
        $row .= $ko_id . $sd . $matchText . "\t";

        $matchText = $ko_name;
        $matchText = highlightMatchHTML2( $ko_name, $searchTerm )
          if ( $searchFilter eq "koname" );
        $row .= $ko_name . $sd . $matchText . "\t";

        $matchText = $ko_defn;
        $matchText = highlightMatchHTML2( $ko_defn, $searchTerm )
          if ( $searchFilter eq "kodefn" );
        $row .= $ko_defn . $sd . $matchText . "\t";

        # gene count
        my $g_url = "$section_cgi&page=findkogenelist&ko_id=$ko_id";
        $g_url .= "&seqstatus=$seq_status";
        $g_url .= "&domainfilter=$domainfilter";
        $g_url .= "&taxonChoice=$taxonChoice";
        if ( $include_metagenomes ) {
            $g_url .= "&data_type=$data_type";
        }
        if ( $gcnt > 0 ) {
            $row .= $gcnt . $sd . alink( $g_url, $gcnt ) . "\t";
        } else {
            $row .= $gcnt . $sd . "0" . "\t";
        }

        # genome count
        my $t_url = "$section_cgi&page=findkogenomelist&ko_id=$ko_id";
        $t_url .= "&seqstatus=$seq_status";
        $t_url .= "&domainfilter=$domainfilter";
        $t_url .= "&taxonChoice=$taxonChoice";
        if ( $include_metagenomes ) {
            $t_url .= "&data_type=$data_type";
        }
        if ( $tcnt > 0 ) {
            $row .= $tcnt . $sd . alink( $t_url, $tcnt ) . "\t";
        } else {
            $row .= $tcnt . $sd . "0" . "\t";
        }

        $it->addRow($row);
    }

    WebUtil::printFuncCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    printStatusLine( "$count loaded.", 2 );
    print end_form();
}


sub getKoIdSql {
    my ( $searchTerm, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause
	( 'KO:', 'KO:K', $searchTerm );

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }
    #my $sql = qq{
    #    WITH
    #    with_ko_term AS
    #    (
    #        select distinct kt.ko_id, kt.ko_name, kt.definition
    #        from ko_term kt
    #        where kt.ko_id in ( $idWhereClause )
    #    )
    #    select wt.ko_id, wt.ko_name, wt.definition, 
    #           count(distinct g.gene_oid), count(distinct g.taxon)
    #    from with_ko_term wt, gene_ko_terms g
    #    where wt.ko_id = g.ko_terms
    #    $taxonClause
    #    $rclause
    #    $imgClause
    #    group by wt.ko_id, wt.ko_name, wt.definition
    #};
    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from ko_term kt, mv_taxon_ko_stat g $addfrom
        where kt.ko_id in ( $idWhereClause )
        and kt.ko_id = g.ko_term
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by kt.ko_id, kt.ko_name, kt.definition
    };

    my @bindList = ();
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKoIdSql_merfs {
    my ( $searchTerm, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $idWhereClause = OracleUtil::addIdWhereClause( 'KO:', 'KO:K', $searchTerm );

    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from ko_term kt, TAXON_KO_COUNT g
        where kt.ko_id in ( $idWhereClause )
        and kt.ko_id = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by kt.ko_id, kt.ko_name, kt.definition
    };

    my @bindList = ();
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getKoNameSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }
    #my $sql = qq{
    #    WITH
    #    with_ko_term AS
    #    (
    #        select distinct kt.ko_id, kt.ko_name, kt.definition
    #        from ko_term kt
    #        where lower(kt.ko_name) like ?
    #    )
    #    select wt.ko_id, wt.ko_name, wt.definition,
    #           count(distinct g.gene_oid), count(distinct g.taxon)
    #    from with_ko_term wt, gene_ko_terms g
    #    where wt.ko_id = g.ko_terms
    #    $taxonClause
    #    $rclause
    #    $imgClause
    #    group by wt.ko_id, wt.ko_name, wt.definition
    #};
    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from ko_term kt, mv_taxon_ko_stat g $addfrom
        where lower(kt.ko_name) like ?
        and kt.ko_id = g.ko_term
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by kt.ko_id, kt.ko_name, kt.definition
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKoNameSql_merfs {
    my ( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition, sum(g.gene_count), count(distinct g.taxon_oid)
        from ko_term kt, TAXON_KO_COUNT g
        where lower(kt.ko_name) like ?
        and kt.ko_id = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by kt.ko_id, kt.ko_name, kt.definition
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getKoDefnSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }
    #my $sql = qq{
    #    WITH
    #    with_ko_term AS
    #    (
    #        select distinct kt.ko_id, kt.ko_name, kt.definition
    #        from ko_term kt
    #        where lower(kt.definition) like ?
    #    )
    #    select wt.ko_id, wt.ko_name, wt.definition, 
    #           count(distinct g.gene_oid), count(distinct g.taxon)
    #    from with_ko_term wt, gene_ko_terms g
    #    where wt.ko_id = g.ko_terms
    #    $taxonClause
    #    $rclause
    #    $imgClause
    #    group by wt.ko_id, wt.ko_name, wt.definition
    #};
    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from ko_term kt, mv_taxon_ko_stat g $addfrom
        where lower(kt.definition) like ?
        and kt.ko_id = g.ko_term
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by kt.ko_id, kt.ko_name, kt.definition
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql,
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKoDefnSql_merfs {
    my ( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition, sum(g.gene_count), count(distinct g.taxon_oid)
        from ko_term kt, TAXON_KO_COUNT g
        where lower(kt.definition) like ?
        and kt.ko_id = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by kt.ko_id, kt.ko_name, kt.definition
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

# no pathway id given
sub printFindKoGeneList {
    my $ko_id                      = param("ko_id");
    my $data_type                  = param("data_type");
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections     = ();
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my @dbTaxons = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) 
                = MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        }
        else {
            @dbTaxons = @genomeFilterSelections;
        }            
    }
    else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) 
                = OracleUtil::getTaxonSelectionClauseBind( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh, $taxonClause, \@bindList_txs);
            @metaTaxons = keys %taxon_in_file;
        }            
    }

    my $gene_cnt = 0;
    my $trunc = 0;

    my @gene_oids = ();
    if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
        #no need to fetch things from database
    }
    else {

        my ( $taxonClause, @bindList_txs );
        if (scalar(@dbTaxons) > 0) {
            ( $taxonClause, @bindList_txs ) =
              OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@dbTaxons );
        }
        else {
            ( $taxonClause, @bindList_txs ) =
              OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );            
        }
        my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");

        my ( $sql, @bindList ) = getKoIdGeneListSql( $ko_id, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );
    
        @gene_oids = HtmlUtil::fetchGeneList( $dbh, $sql, $verbose, @bindList );
        $gene_cnt = scalar(@gene_oids);
        if ( $gene_cnt >= $maxGeneListResults ) {
            $trunc = 1;
        }

        # bug fix - we ned to remove the taxon oids in the temp table - ken
        OracleUtil::truncTable( $dbh, "gtt_num_id" );    
    }

    my @meta_genes = ();
    if ( $include_metagenomes && scalar(@metaTaxons) > 0 && !$trunc) {
        my @type_list = MetaUtil::getDataTypeList( $data_type );
                
        foreach my $toid (@metaTaxons) {
            for my $t2 (@type_list) {
                my %genes = MetaUtil::getTaxonFuncGenes( $toid, $t2, $ko_id );
                my @worksapceIds = values %genes;
                if ( scalar(@worksapceIds ) > 0) {
                    push (@meta_genes, @worksapceIds); 
    
                    $gene_cnt += scalar(@worksapceIds);
                    if ( $gene_cnt >= $maxGeneListResults ) {
                        $trunc = 1;
                        last;
                    }
                }
            }
        }
    }

    if ( scalar(@gene_oids) == 1 && scalar(@meta_genes) == 0 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        #$dbh->disconnect();
        return;
    }

    my $title = "Genes In KEGG Orthology (KO) Term";
    my $subtitle = "KO ID: $ko_id";
    if ( $include_metagenomes && scalar(@meta_genes) > 0 ) {
        $subtitle .= "<br/>\nMER-FS Metagenome: " . $data_type;
    }
    HtmlUtil::printGeneListHtmlTable
    ( $title, $subtitle, $dbh, \@gene_oids, \@meta_genes );
}

sub getKoIdGeneListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.gene_oid
        from gene_ko_terms gk, gene g
        where gk.ko_terms  = ?
        and gk.gene_oid = g.gene_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList = ($id);
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}


# no pathway id given
sub printFindKoGenomeList {
    my $ko_id        = param("ko_id");
    my $data_type    = param("data_type");
    my $domainfilter = param("domainfilter");
    my $seq_status   = param("seqstatus");

    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections     = ();
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my @dbTaxons = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) 
                = MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        }
        else {
            @dbTaxons = @genomeFilterSelections;
        }            
    } elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
    } else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) 
                = OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile
		($dbh, $taxonClause, \@bindList_txs);
            @metaTaxons = keys %taxon_in_file;
        }            
    }

    my @taxon_oids = ();
    if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
        # no need to fetch things from database
    } else {  
        my ( $taxonClause, @bindList_txs );
        my $bydomain = 0;
        if (scalar(@dbTaxons) > 0) {
            ( $taxonClause, @bindList_txs ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon_oid", \@dbTaxons );
        } elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
            $bydomain = $domainfilter;
        } else {
            ( $taxonClause, @bindList_txs ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon_oid", \@genomeFilterSelections );            
        }
        my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon_oid");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

        my ( $sql, @bindList ) = getKoIdGenomeListSql
	    ( $ko_id, $taxonClause, $rclause, $imgClause,
	      \@bindList_txs, \@bindList_ur, $bydomain, $seq_status );
	
        @taxon_oids = HtmlUtil::fetchGenomeList( $dbh, $sql, $verbose, @bindList );
    
        # bug fix - we ned to remove the taxon oids in the temp table - ken
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
	    if ( $taxonClause =~ /gtt_num_id/i )   
    }

    if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
        if ( $new_func_count ) {
            my ( $taxonClause, @bindList_txs ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon_oid", \@metaTaxons );
            my ($rclause, @bindList_ur) = WebUtil::urClauseBind("g.taxon_oid");
            my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

            my $datatypeClause;
            if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                $datatypeClause = " and g.data_type = '$data_type' ";
            }              

            my ( $sql, @bindList ) = getKoIdGenomeListSql_merfs
		( $ko_id, $taxonClause, $datatypeClause, $rclause, $imgClause,
		  \@bindList_txs, \@bindList_ur );
                
            my @meta_taxons =
		HtmlUtil::fetchGenomeList( $dbh, $sql, $verbose, @bindList );
            push( @taxon_oids, @meta_taxons );
        
            # bug fix - we ned to remove the taxon oids in the temp table - ken
            OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
              if ( $taxonClause =~ /gtt_num_id/i )   
        }
        else {
            #todo mer-fs
        }
    }

    my $title = "Genomes In KEGG Orthology (KO) Term";
    my $subtitle = "KO ID: $ko_id";
    if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
        $subtitle .= "<br/>\nMER-FS Metagenome: " . $data_type;
    }
    HtmlUtil::printGenomeListHtmlTable($title, $subtitle, $dbh, \@taxon_oids);
}

sub getKoIdGenomeListSql {
    my ( $id, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, 
	 $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    #my $sql = qq{
    #    select distinct g.taxon
    #    from gene_ko_terms gk, gene g
    #    where gk.ko_terms  = ?
    #    and gk.gene_oid = g.gene_oid
    #    $taxonClause
    #    $rclause
    #    $imgClause
    #};
    my $sql = qq{
        select /*+ result_cache */ distinct g.taxon_oid
        from mv_taxon_ko_stat g $addfrom
        where g.ko_term  = ?
        $dmClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList = ($id);
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getKoIdGenomeListSql_merfs {
    my ( $id, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct g.taxon_oid
        from TAXON_KO_COUNT g
        where g.func_id = ?
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
    };

    my @bindList = ($id);
    processBindList( \@bindList, undef, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

############################################################################
# printFfgKeggPathways - Print top level pathways from gene search.
############################################################################
sub printFfgKeggPathways {
    my $searchTerm = param("ffgSearchTerm");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLiteral = $searchTerm;
    $searchTerm =~ tr/A-Z/a-z/;

    printMainForm();
    print "<h1>KEGG Pathways</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "tx.taxon_oid", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');

    #my $sql = qq{
    #   select pw.category, pw.pathway_name, pw.pathway_oid,
    #      tx.taxon_display_name, tx.taxon_oid, count(distinct g.gene_oid)
    #   from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
    #      gene_ko_enzymes g, taxon tx
    #   where pw.pathway_oid = roi.pathway
    #   and roi.roi_id = rk.roi_id
    #   and rk.ko_terms = g.ko_id
    #   and g.taxon = tx.taxon_oid
    #   and ( lower( pw.category ) like ? or
    #         lower( pw.pathway_name ) like ? )
    #   $taxonClause
    #   $rclause
    #   $imgClause
    #   group by pw.category, pw.pathway_name, pw.pathway_oid,
    #      tx.taxon_display_name, tx.taxon_oid
    #   order by pw.category, pw.pathway_name, pw.pathway_oid,
    #      tx.taxon_display_name, tx.taxon_oid
    #};
    my $sql = qq{
       select pw.category, pw.pathway_name, pw.pathway_oid, 
          sum(g.gene_count), tx.taxon_oid, tx.taxon_display_name
       from kegg_pathway pw, mv_taxon_kegg_stat g, taxon tx
       where pw.pathway_oid = g.pathway_oid
       and g.taxon_oid = tx.taxon_oid
       and ( lower( pw.category ) like ? or
             lower( pw.pathway_name ) like ? )
       $taxonClause
       $rclause
       $imgClause
       group by pw.category, pw.pathway_name, pw.pathway_oid, 
          tx.taxon_display_name, tx.taxon_oid
       order by pw.category, pw.pathway_name, pw.pathway_oid, 
          tx.taxon_display_name, tx.taxon_oid
    };
    my @bindList = ( "%$searchTerm%", "%$searchTerm%" );
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    #print "printFfgKeggPathways() sql: $sql<br/>";
    #print "printFfgKeggPathways() bindList: @bindList<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    print "<p>\n";
    my $count = 0;
    my $old_category;
    my $old_pathway_name;
    my %pathwayNameCount;

    for ( ; ; ) {
        my ( $category, $pathway_name, $pathway_oid, $gene_count, $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$category;
        $count++;
        if ( $count == 1 ) {
            print "The number of genes in each genome's " . "pathway is shown in parentheses.\n";
            print "<br/>\n";
        }
        $pathwayNameCount{$pathway_name}++;
        my $url = "$main_cgi?section=TaxonDetail" . "&page=keggPathwayGenes&pathway_oid=$pathway_oid";
        $url .= "&taxon_oid=$taxon_oid";
        if ( $old_category ne $category ) {
            print "<br/>\n";
            print "<b>\n";

            #print escHtml( $category );
            print highlightMatchHTML2( $category, $searchTermLiteral );
            print "</b>\n";
            print "<br/>\n";
        }
        if ( $old_pathway_name ne $pathway_name ) {
            print nbsp(4);
            my $url = "$main_cgi?section=KeggPathwayDetail" . "&page=keggPathwayDetail";
            $url .= "&pathway_oid=$pathway_oid";
            print "<a href='$url'>\n";
            print highlightMatchHTML2( $pathway_name, $searchTermLiteral );
            print "</a>\n";
            print "<br/>\n";
        }
        print nbsp(6);
        print escHtml("[$taxon_display_name]");
        print " (" . alink( $url, $gene_count ) . ")<br/>\n";
        $old_category     = $category;
        $old_pathway_name = $pathway_name;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    #$dbh->disconnect();

    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
    }

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    print "<p>\n";
    print "</p>\n";
    my $pw_name_count = keys(%pathwayNameCount);
    printStatusLine( "$pw_name_count KEGG pathway assignments retrieved.", 2 );
    print end_form();

}

############################################################################
# printFfgKeggPathwayEnzymes - Print top level pathways from enzyme
#   search.
############################################################################
sub printFfgKeggPathwayEnzymes {
    my $searchFilter = param("searchFilter");
    my $searchTerm   = param("ffgSearchTerm");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;
    my $searchTermLiteral = $searchTerm;

    my $seq_status             = param("seqstatus");
    my $domainfilter           = param("domainfilter");
    my $taxonChoice            = param("taxonChoice");
    my $data_type              = param("q_data_type");
    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");

    # allow searching by selected domain or by all isolates:
    my $selectionType = param("selectType");
    if ($selectionType eq "selDomain") {
        $seq_status = param("seqstatus0");
        $domainfilter = param("domainfilter0");
    } elsif ($selectionType eq "allIsolates") {
	$seq_status = param("seqstatus0");
	$domainfilter = "isolates";
    }

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    printMainForm();
    my $title = $function2Name{$searchFilter};
    print "<h1>$title Search Results</h1>\n";
    printStatusLine( "Loading ...", 1 );

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $old_category;
    my $old_pathway_name;
    my %pathwayNameCount;
    my %enzymes;
    my @recs;
    my $count = 0;

    # cache file
    my $file      = param("file");
    my $cacheFile = getCacheFile($file);
    if ( $file ne "" && -e $cacheFile ) {
        ( $count, @recs ) = readCacheFile( $cacheFile, $count, @recs );

    } else {
        my $dbh = dbLogin();
        my @dbTaxons   = ();
        my @metaTaxons = ();
        if ( scalar(@genomeFilterSelections) > 0 ) {
            if ($include_metagenomes) {
                my ( $dbTaxons_ref, $metaTaxons_ref ) = 
		MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
                @dbTaxons   = @$dbTaxons_ref;
                @metaTaxons = @$metaTaxons_ref;
            } else {
                @dbTaxons = @genomeFilterSelections;
            }
	} elsif ($selectionType eq "selDomain" || 
		 $selectionType eq "allIsolates") { 
	    # no need to get taxons
        } else {
            if ($include_metagenomes) {
                my ( $taxonClause, @bindList_txs ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "t.taxon_oid", \@genomeFilterSelections );
                my %taxon_in_file = MerFsUtil::getTaxonsInFile
		    ( $dbh, $taxonClause, \@bindList_txs );
                @metaTaxons = keys %taxon_in_file;
            }
        }

        my ( $merfs_genecnt_href, $merfs_genomecnt_href );
        if ( $include_metagenomes && scalar(@metaTaxons) > 0 
	     && isMetaSupported($searchFilter) ) {

            if ($new_func_count) {
                my ( $taxonClause, @bindList_txs ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@metaTaxons );
                my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon_oid");
                my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

                my $datatypeClause;
                if ($data_type eq 'assembled' || $data_type eq 'unassembled') {
                    $datatypeClause = " and g.data_type = '$data_type' ";
                }

                my $sql;
                my @bindList = ();

                my ( $sql, @bindList ) =
		    getKeggPathEzSql_merfs
		    ( $searchTermLc, $taxonClause, $datatypeClause,
		      $rclause, $imgClause, \@bindList_txs, \@bindList_ur );

                if ( blankStr($sql) ) {
                    webDie( "printFfgKeggPathwayEnzymes: Unknown search filter '$searchFilter'\n" );
                }

                my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
                for ( ; ; ) {
                    my ( $category, $pathway_name, $pathway_oid, $ec_number,
			 $enzyme_name, $gene_count, $taxon_count ) =
			     $cur->fetchrow();
                    last if !$category;

                    my $id = "$category\t$pathway_name\t$pathway_oid\t"
			   . "$ec_number\t$enzyme_name";
                    $merfs_genecnt_href->{$id}   = $gene_count;
                    $merfs_genomecnt_href->{$id} = $taxon_count;
                }
                $cur->finish();
                OracleUtil::truncTable( $dbh, "gtt_num_id" )
		    if ( $taxonClause =~ /gtt_num_id/i );

            } else {
                # TODO mer fs
            }

        }

        if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
            # no need to fetch things from database
        } else {
            my ( $taxonClause, @bindList_txs );
	    my $bydomain = 0;
            if ( scalar(@dbTaxons) > 0 ) {
                ( $taxonClause, @bindList_txs ) = 
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@dbTaxons );
	    } elsif ($selectionType eq "selDomain" || 
		     $selectionType eq "allIsolates") { 
                $bydomain = $domainfilter;
            } else {
                ( $taxonClause, @bindList_txs ) =
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon_oid", \@genomeFilterSelections );
            }
            my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon_oid");
            my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

            my ( $sql, @bindList ) =
		getKeggPathEzSql( $searchTermLc, $taxonClause, $rclause,
				  $imgClause, \@bindList_txs, \@bindList_ur,
				  $bydomain, $seq_status );

            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $category, $pathway_name, $pathway_oid, $ec_number,
		     $enzyme_name, $gene_count, $taxon_count ) =
			 $cur->fetchrow();
                last if !$category;

                if ( $include_metagenomes && scalar(@metaTaxons) > 0 
		     && isMetaSupported($searchFilter) ) {
                    my $id = "$category\t$pathway_name\t$pathway_oid\t"
			   . "$ec_number\t$enzyme_name";
                    if ( exists $merfs_genecnt_href->{$id} ) {
                        my $gcnt2 = $merfs_genecnt_href->{$id};
                        my $tcnt2 = $merfs_genomecnt_href->{$id};
                        $gene_count  += $gcnt2;
                        $taxon_count += $tcnt2;
                        delete $merfs_genecnt_href->{$id};
                        delete $merfs_genomecnt_href->{$id};
                    }
                }

                push( @recs,
                      "$category\t$pathway_name\t$pathway_oid\t" .
		      "$ec_number\t$enzyme_name\t$gene_count\t$taxon_count" );
            }
            $cur->finish();
            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $taxonClause =~ /gtt_num_id/i );
        }

        foreach my $key ( keys %$merfs_genecnt_href ) {
            my $gcnt2 = $merfs_genecnt_href->{$key};
            my $tcnt2 = $merfs_genomecnt_href->{$key};

            my $rec = "$key\t";
            $rec .= "$gcnt2\t";
            $rec .= "$tcnt2\t";
            push( @recs, $rec );
        }
    }

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    my $count = 0;
    foreach my $line (@recs) {
        my ( $category, $pathway_name, $pathway_oid, $ec_number, 
	     $enzyme_name, $gene_count, $taxon_count ) = split( /\t/, $line );

        $count++;
        if ( $count == 1 ) {
            print "<p>\n";
            print "<u>Keyword</u>: " . $searchTerm. "<br/>\n";
            print "The number of genes and genomes are shown in parentheses.<br/>\n";
            print "</p>\n";
            WebUtil::printFuncCartFooter();
            print "<p>\n";
        }
        $pathwayNameCount{$pathway_name}++;
        if ( $old_category ne $category ) {
            print "<br/>\n";
            print "<b>\n";
            #print escHtml( $category );
            print highlightMatchHTML2( $category, $searchTermLiteral );
            print "</b>\n";
            print "<br/>\n";
        }
        if ( $old_pathway_name ne $pathway_name ) {
            print nbsp(4);
            my $url = "$main_cgi?section=KeggPathwayDetail" 
		    . "&page=keggPathwayDetail";
            $url .= "&pathway_oid=$pathway_oid";
            print "<a href='$url'>\n";
            print highlightMatchHTML2( $pathway_name, $searchTermLiteral );
            print "</a>\n";
            print "<br/>\n";
        }
        print nbsp(6);
        print "<input type='checkbox' name='ec_number' value='$ec_number'/>\n";
        print highlightMatchHTML2( $ec_number,   $searchTermLiteral ).nbsp(1);
        print highlightMatchHTML2( $enzyme_name, $searchTermLiteral );
        my $url = "$section_cgi&page=ffgFindFunctionsGeneList";
        $url .= "&searchFilter=$searchFilter";
        $url .= "&pathway_oid=$pathway_oid";
        $url .= "&ec_number=$ec_number";
        $url .= "&seqstatus=$seq_status";
        $url .= "&domainfilter=$domainfilter";
        $url .= "&taxonChoice=$taxonChoice";
        print nbsp(1);
        print "(" . alink( $url, $gene_count ) . ")";
        my $url = "$section_cgi&page=ffgFindFunctionsGenomeList";
        $url .= "&searchFilter=$searchFilter";
        $url .= "&pathway_oid=$pathway_oid";
        $url .= "&ec_number=$ec_number";
        $url .= "&seqstatus=$seq_status";
        $url .= "&domainfilter=$domainfilter";
        $url .= "&taxonChoice=$taxonChoice";
        print "  (" . alink( $url, $taxon_count ) . ")";
        print "<br/>\n";
        $old_category        = $category;
        $old_pathway_name    = $pathway_name;
        $enzymes{$ec_number} = 1;
    }
    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
    }
    print "<br/>\n";
    WebUtil::printFuncCartFooter() if $count > 10;
    printHint("The enzyme cart allows for phylogenetic profile comparisons.");

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    my $count = keys(%enzymes);
    printStatusLine( "$count enzyme(s) retrieved.", 2 );
    print end_form();
}

sub getKeggPathEzSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
	$addfrom = ", taxon tx ";
	$dmClause = " and tx.domain = '$bydomain' ";
	$dmClause = " and tx.genome_type = 'isolate' "
	    if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
	$taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
        WITH
        with_pathway_enzyme AS
        (
            select distinct pw.category, pw.pathway_name, pw.pathway_oid, 
                   ez.ec_number, ez.enzyme_name
            from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
                 ko_term_enzymes kt, enzyme ez
            where ( lower( pw.category ) like ?
                    or lower( pw.pathway_name ) like ?
                    or lower( ez.ec_number ) like ?
                    or contains(ez.enzyme_name, ?) > 0 )
            and pw.pathway_oid = roi.pathway
            and roi.roi_id = rk.roi_id
            and rk.ko_terms = kt.ko_id
            and kt.enzymes = ez.ec_number
        )
        select pe.category, pe.pathway_name, pe.pathway_oid, 
               pe.ec_number, pe.enzyme_name,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from with_pathway_enzyme pe, mv_taxon_ec_stat g $addfrom
        where pe.ec_number = g.enzyme
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by pe.category, pe.pathway_name, pe.pathway_oid, 
                 pe.ec_number, pe.enzyme_name
        order by pe.category, pe.pathway_name, pe.pathway_oid, 
                 pe.ec_number, pe.enzyme_name
    };

    my @bindList_sql = ( "%$searchTermLc%", "%$searchTermLc%", 
			 "%$searchTermLc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getKeggPathEzSql_merfs {
    my ( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select pw.category, pw.pathway_name, pw.pathway_oid,
               ez.ec_number, ez.enzyme_name,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
             ko_term_enzymes kt, enzyme ez, 
             TAXON_EC_COUNT g
        where ( lower( pw.category ) like ? 
                or lower( pw.pathway_name ) like ?
                or lower( ez.ec_number ) like ? 
                or contains(ez.enzyme_name, ?) > 0 )
        and pw.pathway_oid = roi.pathway
        and roi.roi_id = rk.roi_id
        and rk.ko_terms = kt.ko_id
        and kt.enzymes = ez.ec_number
        and ez.ec_number = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by pw.category, pw.pathway_name, pw.pathway_oid, ez.ec_number, ez.enzyme_name
        order by pw.category, pw.pathway_name, pw.pathway_oid, ez.ec_number, ez.enzyme_name
    };

    my @bindList_sql = ( "%$searchTermLc%", "%$searchTermLc%", "%$searchTermLc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

############################################################################
# printFfoGenomeKeggPathways - Print top level pathways for genome
#    search.
############################################################################
sub printFfoGenomeKeggPathways {
    my $searchTerm = param("keggGenomeSearchTerm");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLiteral = $searchTerm;
    $searchTerm =~ tr/A-Z/a-z/;

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");
    #my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    print hiddenVar( "geneSearchTaxonFilter", $geneSearchTaxonFilter );
    for my $r (@genomeFilterSelections) {
        print hiddenVar( "genomeFilterSelections", $r );
    }

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon_oid", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');

    #my $sql = qq{
    #   select pw.category, pw.pathway_name, pw.pathway_oid, count( distinct g.taxon )
    #   from kegg_pathway pw, image_roi roi, image_roi_ko_terms rk,
    #      gene_ko_enzymes g
    #   where pw.pathway_oid = roi.pathway
    #   and roi.roi_id = rk.roi_id
    #   and rk.ko_terms = g.ko_id
    #   and ( lower( pw.category ) like ? or
    #         lower( pw.pathway_name ) like ? )
    #   $taxonClause
    #   $rclause
    #   $imgClause
    #   group by pw.category, pw.pathway_name, pw.pathway_oid
    #   order by pw.category, lower( pw.pathway_name ), pw.pathway_oid
    #};
    my $sql = qq{
       select pw.category, pw.pathway_name, pw.pathway_oid, count( distinct g.taxon_oid )
       from kegg_pathway pw, mv_taxon_kegg_stat g
       where ( lower( pw.category ) like ? or
             lower( pw.pathway_name ) like ? )
       and pw.pathway_oid = g.pathway_oid
       $taxonClause
       $rclause
       $imgClause
       group by pw.category, pw.pathway_name, pw.pathway_oid
       order by pw.category, lower( pw.pathway_name ), pw.pathway_oid
    };

    my @bindList = ( "%$searchTerm%", "%$searchTerm%" );
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    #print "\@bindList: @bindList<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    printMainForm();
    print "<h1>KEGG Pathways</h1>\n";

    #print "<p>\n";
    #print "The number of of genomes in each " .
    #   "pathway is shown in parentheses.\n";
    #print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";

    my $count = 0;
    my $old_category;
    my $old_pathway_name;
    my %pathwayNameCount;
    for ( ; ; ) {
        my ( $category, $pathway_name, $pathway_oid, $taxon_count ) = $cur->fetchrow();
        last if !$category;
        $count++;
        if ( $count == 1 ) {
            print "The number of of genome's in each " . "pathway is shown in parentheses.\n";
            print "<br/>\n";
        }
        $pathwayNameCount{$pathway_name}++;
        if ( $old_category ne $category ) {
            print "<br/>\n";
            print "<b>\n";

            #print escHtml( $category );
            print highlightMatchHTML2( $category, $searchTermLiteral );
            print "</b>\n";
            print "<br/>\n";
        }
        if ( $old_pathway_name ne $pathway_name ) {
            print nbsp(4);
            my $url = "$main_cgi?section=KeggPathwayDetail" . "&page=keggPathwayDetail&pathway_oid=$pathway_oid";
            print "<a href='$url'>\n";
            print highlightMatchHTML2( $pathway_name, $searchTermLiteral );
            print "</a>\n";
        }
        print nbsp(1);
        my $url = "$section_cgi&page=ffoKeggPathwayOrgs&pathway_oid=$pathway_oid";
        print " (" . alink( $url, $taxon_count ) . ")<br/>\n";
        $old_category     = $category;
        $old_pathway_name = $pathway_name;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    #$dbh->disconnect();

    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
    }
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    print "</p>\n";
    my $pw_name_count = keys(%pathwayNameCount);
    printStatusLine( "$pw_name_count KEGG pathway assignments retrieved.", 2 );
    print end_form();

}

############################################################################
# printFfoKeggPathwayOrgs - Print pathway genomes.
############################################################################
sub printFfoKeggPathwayOrgs {
    my $pathway_oid = param("pathway_oid");

    printMainForm();
    print "<h1>KEGG Pathway Genomes</h1>\n";
    print "<p>\n";
    my $dbh = dbLogin();
    my $pathway_name = keggPathwayName( $dbh, $pathway_oid );
    print "Genomes with at least one gene in <i>$pathway_name</i>.";
    print "<br/>\n";

    #print "The number of genes is shown in parentheses.\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    #my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "tx.taxon_oid", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');

    #my $sql = qq{
    #  select tx.taxon_oid, tx.taxon_display_name, count( distinct g.gene_oid )
    #  from gene_ko_enzymes g, image_roi_ko_terms rk, image_roi roi, taxon tx
    #  where g.ko_id = rk.ko_terms
    #  and rk.roi_id = roi.roi_id
    #  and roi.pathway = ?
    #  and g.taxon = tx.taxon_oid
    #  $taxonClause
    #  $rclause
    #  $imgClause
    #  group by tx.taxon_display_name, tx.taxon_oid
    #  order by tx.taxon_display_name, tx.taxon_oid
    #};
    my $sql = qq{
      select tx.taxon_oid, tx.taxon_display_name, sum(g.gene_count )
      from kegg_pathway pw, mv_taxon_kegg_stat g, taxon tx
      where pw.pathway_oid = ? 
      and pw.pathway_oid = g.pathway_oid
      and g.taxon_oid = tx.taxon_oid
      $taxonClause
      $rclause
      $imgClause
      group by tx.taxon_display_name, tx.taxon_oid
      order by tx.taxon_display_name, tx.taxon_oid
    };
    my @bindList = ("$pathway_oid");
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    #print "\@bindList: @bindList<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    #print "<p>\n";
    my $count   = 0;
    my $baseUrl = "$section_cgi&page=ffoKeggPathwayOrgs";
    $baseUrl .= "&pathway_oid=$pathway_oid";
    my $cachedTable = new CachedTable( "ffoKegg", $baseUrl );
    $cachedTable->addColSpec( "Genome",     "asc",  "left" );
    $cachedTable->addColSpec( "Gene Count", "desc", "right" );
    my $sdDelim = CachedTable::getSdDelim();
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;
        my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $r   = $taxon_display_name . $sdDelim . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=ffoKeggPathwayOrgGenes";
        $url .= "&pathway_oid=$pathway_oid";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&count=$cnt";

        #print "(" . alink( $url, $cnt ) . ")<br/>\n";
        $r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
        $cachedTable->addRow($r);
    }
    $cachedTable->printTable();

    #print "</p>\n";
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    #$dbh->disconnect();

    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printFfoKeggPathwayOrgGenes - Show genes in genomes.
############################################################################
sub printFfoKeggPathwayOrgGenes {
    my $pathway_oid = param("pathway_oid");
    my $taxon_oid   = param("taxon_oid");

    my $dbh = dbLogin();

    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");
    #my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    print hiddenVar( "geneSearchTaxonFilter", $geneSearchTaxonFilter );
    for my $r (@genomeFilterSelections) {
        print hiddenVar( "genomeFilterSelections", $r );
    }

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select distinct g.gene_oid
        from gene_ko_enzymes g, image_roi_ko_terms rk, image_roi roi
        where g.ko_id = rk.ko_terms
        and rk.roi_id = roi.roi_id
        and roi.pathway = ? 
        and g.taxon = ? 
        $taxonClause
        $rclause
        $imgClause
    };
    my @bindList = ( "$pathway_oid", "$taxon_oid" );
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );

    #print "printFfoKeggPathwayOrgGenes() sql: $sql<br/>";
    #print "printFfoKeggPathwayOrgGenes() bindList: @bindList<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @gene_oids = ();
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();

    print "<h1>KEGG Pathway Genome Genes</h1>";
    print "<p>\n";
    my $taxon_display_name = genomeName( $dbh,      $taxon_oid );
    my $pathway_name       = keggPathwayName( $dbh, $pathway_oid );
    print escHtml($taxon_display_name) . " with at least one gene in " 
	. "<i>" . escHtml($pathway_name) . "</i>.";
    print "</p>\n";

    printGeneCartFooter() if ( $count > 10 );
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printFfoAllKeggPathways - Show all kegg pathways.
############################################################################
sub printFfoAllKeggPathways {
    print "<h1>KEGG Orthology (KO) Terms and Pathways</h1>\n";

    printKeggContent();

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $sql = qq{
       select distinct pw.category, pw.pathway_name, pw.pathway_oid
       from KEGG_PATHWAY pw
       order by pw.category, pw.pathway_name
    };

    my $cur = execSql( $dbh, $sql, $verbose );

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    printMainForm();
    print "<h2>KEGG Pathways via EC Numbers</h2>\n";
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    my $count     = 0;
    my $cat_count = 0;    # count num of kegg cat
    my $old_category;
    my %pathwayNameCount;

    for ( ; ; ) {
        my ( $category, $pathway_name, $pathway_oid ) = $cur->fetchrow();
        last if !$pathway_oid;
        $count++;
        if ( $old_category ne $category ) {
            print "<br/>\n" if $count > 1;
            print "<b>\n";
            print escHtml($category);
            print "</b>\n";
            print "<br/>\n";
            $cat_count++;
        }
        print nbsp(4);
        my $url = "$main_cgi?section=KeggPathwayDetail"
	        . "&page=keggPathwayDetail&pathway_oid=$pathway_oid";
        print alink( $url, $pathway_name ) . "<br/>\n";
        $old_category = $category;
    }
    $cur->finish();

    #$dbh->disconnect();

    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    $cat_count += $count;    # add cat to count
    printStatusLine( "$count ($cat_count) KEGG pathways retrieved.", 2 );
    print end_form();

}

sub printKeggContent {
    my $url1 = $section_cgi . "&page=ffoAllKeggPathways&view=ko";
    $url1 = alink( $url1, "KEGG Pathways via KO Terms" );

    #my $url2 = $section_cgi . "&page=ffoAllKeggPathways&view=ec";
    #$url2 = alink( $url2, "KEGG Pathways via EC Numbers" );

    my $url3 = $section_cgi . "&page=ffoAllKeggPathways&view=brite";
    $url3 = alink( $url3, "KEGG Orthology (KO) Terms" );

    my $url4 = alink( "http://www.genome.jp/kegg/brite.html", "BRITE Hierarchy" );

    print qq{
      <p>
      $url3 Based on $url4<br/>
      $url1
      </p>  
    };
}

sub printKoStatsLinks {
    print "<b>KO Term Distribution</b>";
    my $url1 = "main.cgi?section=KoTermStats&page=combo";
    $url1 = alink( $url1, "KO Term Distribution across " . "Protein Families in IMG" );

    my $url2 = "main.cgi?section=KoTermStats&page=paralog";
    $url2 = alink( $url2, "KO Term Distribution across " . "Genomes and Paralog Clusters in IMG" );

    print qq{
	<p>
	$url1<br/>
	$url2<br/>
	</p>
    };
}

sub printFfoAllKeggPathways2 {
    print "<h1>KEGG Orthology (KO) Terms and Pathways</h1>\n";

    printKeggContent();

    print "<h2>KEGG Pathways via KO Terms</h2>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select pathway_oid, pathway_name, kegg_id
        from kegg_pathway
   };

    # kegg_id => $path_id \t $pathway_name
    my %mapping;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $path_id, $pathway_name, $kegg_id ) = $cur->fetchrow();
        last if !$path_id;
        $mapping{$kegg_id} = "$path_id\t$pathway_name";
    }
    $cur->finish();

    #$dbh->disconnect();

    my $count = 0;

    print "<p>\n";

    print qq{
      <table border=0>
      <tr>
      <td nowrap>  
    };

    # now read tree file
    # branch level (A,B,C)
    # A name
    # B name
    # C kegg_id name
    # D module
    my $fh = newReadFileHandle($kegg_tree_file);
    my ( $pathway_oid, $pathway_name );
    my $last_kegg_id;    # parent kegg id for modules
    while ( my $line = $fh->getline() ) {
        chomp $line;
        my @a = split( /\t/, $line );
        if ( $a[0] =~ /^A/ ) {
            print "<b> 01";
            print nbsp(1);
            print escHtml( $a[1] );
            print "</b><br/>\n";
        } elsif ( $a[0] =~ /^B/ ) {
            print nbsp(4);
            print "<b> 02";
            print nbsp(1);
            print escHtml( $a[1] );
            print "</b><br/>\n";
        } elsif ( $a[0] =~ /^C/ ) {
            # C
            $last_kegg_id = $a[1];    # let it have the kegg id
            my $text = $mapping{ $a[1] };
            ( $pathway_oid, $pathway_name ) = split( /\t/, $text );
            print nbsp(8);

            if ( $pathway_oid eq "" || $a[3] eq "(0)" ) {
                print "03 ";
                print nbsp(1);
                print "$a[2]";
                print "<br/>";
                $last_kegg_id = "0";
            } else {
                print "03 ";
                print nbsp(1);
                my $url = "$main_cgi?section=KeggPathwayDetail" . "&page=koterm&kegg_id=$a[1]&pathway_id=$pathway_oid";
                print alink( $url, $pathway_name ) . " $a[3] <br/>\n";
            }
            $count++;
        } elsif ( $a[0] =~ /^D/ ) {
            print nbsp(12);
            print "04 ";

            if ( $last_kegg_id eq "0" ) {
                # no link
                print nbsp(1);
                print "$a[2]";
            } else {
                my $url = "$main_cgi?section=KeggPathwayDetail"
		    . "&page=komodule&pathway_id=$pathway_oid" 
		    . "&module_id=$a[1]";
                print nbsp(1);
                print alink( $url, $a[2] );
            }

            print "<br/>\n";
        }

    }
    close $fh;

    print qq{
        </td>
        </tr>
        </table>
        </p>
    };

    printStatusLine( "$count loaded.", 2 );
}

sub printFfoAllKeggPathways2_test {
    my $open  = param("open");     # list of open nodes
    my $close = param("close");    # a node was close
    $open =~ s/$close//;
    my $all = param("all");

    #.arrowimg {
    #border:0 none;
    #}
    my $open_url = "$base_url/images/open.png";
    $open_url = "<img class='arrowimg' src='$open_url' width='10' height='10'>";
    my $close_url = "$base_url/images/close.png";
    $close_url = "<img class='arrowimg' src='$close_url' width='10' height='10'>";

    print "<h1>KEGG Pathways via KO Terms test</h1>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select pathway_oid, pathway_name, kegg_id
        from kegg_pathway
   };

    # kegg_id => $path_id \t $pathway_name
    my %mapping;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $path_id, $pathway_name, $kegg_id ) = $cur->fetchrow();
        last if !$path_id;
        $mapping{$kegg_id} = "$path_id\t$pathway_name";
    }
    $cur->finish();

    #$dbh->disconnect();

    my $count = 0;

    #print "<p>\n";

    print qq{
      <p>
      <a href='$section_cgi&page=ffoAllKeggPathways&view=ko_test&all=all'>Open All</a> &nbsp;
      <a href='$section_cgi&page=ffoAllKeggPathways&view=ko_test'>Close All</a>
      <p/>  
      
      <p>  
      <table border=0>
      <tr>
      <td nowrap>  
    };

    # now read tree file
    # branch level (A,B,C)
    # A name
    # B name
    # C kegg_id name
    # D module

    my $inB = 0;
    my $inC = 0;

    my $fh = newReadFileHandle($kegg_tree_file);
    my ( $pathway_oid, $pathway_name );
    my $last_kegg_id;    # parent kegg id for modules
    while ( my $line = $fh->getline() ) {
        chomp $line;
        my @a = split( /\t/, $line );
        my $url = "<a style='text-decoration:none' href='$section_cgi&page=ffoAllKeggPathways&view=ko_test";
        if ( $a[0] =~ /^A/ ) {
            print "<a name='" . $a[0] . "'></a>";
            print "<b> 01";
            print nbsp(1);
            print escHtml( $a[1] );
            print "</b><br/>\n";
        } elsif ( $a[0] =~ /^B/ ) {
            ;
            print nbsp(4);
            print "<a name='" . $a[0] . "'></a>";

            if ( $all ne "" ) {
                $inB = 1;
                $url .= "&open=$open&close=$a[0]#$a[0]'>02 $open_url</a>";
            } elsif ( $open =~ /$a[0]/ ) {

                # open a node put url on how to close it
                $inB = 1;
                $url .= "&open=$open&close=$a[0]#$a[0]'>02 $open_url</a>";
            } else {

                # closed node
                $inB = 0;
                $inC = 0;
                $url .= "&open=$open$a[0]#$a[0]'>02 $close_url</a>";
            }

            print "<b>$url";
            print nbsp(1);
            print escHtml( $a[1] );
            print "</b><br/>\n";
        } elsif ( $a[0] =~ /^C/ && $inB ) {

            $last_kegg_id = $a[1];    # let it have the kegg id
            my $text = $mapping{ $a[1] };
            ( $pathway_oid, $pathway_name ) = split( /\t/, $text );
            print nbsp(8);
            print "<a name='" . $a[0] . "'></a>";

            if ( $pathway_oid eq "" || $a[3] eq "(0)" ) {
                print "03";
                print nbsp(1);
                print "$a[2]";
                print "<br/>";
                $last_kegg_id = "0";
            } else {

                if ( $all ne "" ) {
                    $inC = 1;
                    $url .= "&open=$open&close=$a[0]#$a[0]'>03 $open_url</a>";
                } elsif ( $open =~ /$a[0]/ ) {
                    $inC = 1;
                    $url .= "&open=$open&close=$a[0]#$a[0]'>03 $open_url</a>";
                } else {

                    # close node
                    $inC = 0;
                    $url .= "&open=$open$a[0]#$a[0]'>03 $close_url</a>";
                }

                print " $url ";
                print nbsp(1);
                my $url = "$main_cgi?section=KeggPathwayDetail" . "&page=koterm&kegg_id=$a[1]&pathway_id=$pathway_oid";
                print alink( $url, $pathway_name ) . " $a[3] <br/>\n";
            }

            $count++;

        } elsif ( $a[0] =~ /^D/ && $inC ) {
            print nbsp(12);
            print "04 ";

            if ( $last_kegg_id eq "0" ) {

                # no link
                print nbsp(1);
                print "$a[2]";
            } else {
                my $url =
                  "$main_cgi?section=KeggPathwayDetail" . "&page=komodule&pathway_id=$pathway_oid" . "&module_id=$a[1]";
                print nbsp(1);
                print alink( $url, $a[2] );
            }

            print "<br/>\n";
        }
    }
    close $fh;

    print qq{
        </td>
        </tr>
        </table>
        </p>
    };

    printStatusLine( "$count loaded.", 2 );

}

# kegg brite
sub printFfoAllKeggPathways3 {
    print "<h1>KEGG Orthology (KO) Terms and Pathways</h1>\n";

    printKeggContent();
    printKoStatsLinks() if ( !$include_metagenomes );

    print "<h2>KEGG Orthology (KO) Terms </h2>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select pathway_oid, pathway_name, kegg_id
        from kegg_pathway
   };

    # kegg_id => $path_id \t $pathway_name
    my %mapping;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $path_id, $pathway_name, $kegg_id ) = $cur->fetchrow();
        last if !$path_id;
        $mapping{$kegg_id} = "$path_id\t$pathway_name";
    }
    $cur->finish();

    #$dbh->disconnect();

    my $count = 0;

    print "<p>\n";

    print qq{
      <table border=0>
      <tr>
      <td nowrap>  
    };

    # now read tree file
    # branch level (A,B,C, D)
    # A kegg_id name
    # B kegg_id name
    # C kegg_id name
    # D ko_id   name
    my $fh = newReadFileHandle($kegg_brite_tree_file);
    my ( $pathway_oid, $pathway_name );
    while ( my $line = $fh->getline() ) {
        chomp $line;
        my @a = split( /\t/, $line );
        if ( $a[0] eq "A" ) {
            print "<b> 01";
            print nbsp(1);
            print "$a[2]";
            print "</b><br/>\n";
        } elsif ( $a[0] eq "B" ) {
            print nbsp(4);
            print "<b> 02";
            print nbsp(1);
            print "$a[2]";
            print "</b><br/>\n";
        } elsif ( $a[0] eq "C" ) {

            # C
            my $text = $mapping{ $a[1] };
            ( $pathway_oid, $pathway_name ) = split( /\t/, $text );

            print nbsp(8);
            print "03 ";
            print nbsp(1);
            if ( $pathway_oid eq "" ) {

                #  make this a url to list of ko to add to cart with  no genes
                print "$a[2]";

                #
                #                my $url =
                #                    "$main_cgi?section=KeggPathwayDetail"
                #                  . "&page=koterm&kegg_id=$a[1]";
                #                print alink( $url, $a[2] );

            } else {
                my $url = "$main_cgi?section=KeggPathwayDetail" . "&page=koterm&kegg_id=$a[1]&pathway_id=$pathway_oid";
                print alink( $url, $pathway_name );
            }
            print "<br/>\n";
        } elsif ( $a[0] eq "D" ) {

            my $koid_short = $a[1];
            $koid_short =~ s/KO://;
            my $url1 = $kegg_orthology_url . $koid_short;
            $url1 = alink( $url1, $a[1] );

            my $koid_full = addIdPrefix( $a[1], 1 );

            #            my $url2 = "main.cgi?section=KeggPathwayDetail&page=kogenelist" .
            my $url2 = "main.cgi?section=KeggPathwayDetail&page=kogenomelist" . "&ko_id=$koid_full&pathway_id=$pathway_oid";
            $url2 = alink( $url2, $a[2] );

            print nbsp(12);
            print "04 ";
            print nbsp(1);

            #print "$a[1] &nbsp; $a[2]";
            if ( $pathway_oid eq "" ) {
                print "$url1 &nbsp; $a[2]";
            } else {

                print "$url1 &nbsp; $url2";
            }
            print "<br/>\n";
        }

    }
    close $fh;

    print qq{
        </td>
        </tr>
        </table>
        </p>
    };

    printStatusLine( "Loaded.", 2 );

}

############################################################################
# printFfoAllCogCategories - Show all COG/KOG categories.
############################################################################
sub printFfoAllCogCategories {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    print "<h1>${OG} Browser</h1>\n";
    print "<p>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
      select cf.function_code, cf.function_group,
        cf.definition, cp.cog_pathway_oid,
        cp.cog_pathway_name
      from cog_function cf
      left join cog_pathway cp
         on cf.function_code = cp.function
      order by cf.definition, cp.cog_pathway_name
   };

    $sql = qq{
       select kf.function_code, kf.function_group, kf.definition
       from kog_function kf
       order by kf.function_group, kf.definition
    } if ($isKOG);

    my $cur = execSql( $dbh, $sql, $verbose );
    my $old_function_code;
    print "<p>\n";

    my $url = "$section_cgi&page=${og}List";
    print alink( $url, "${OG} list" );
    print "<br/>\n";
    print "<br/>\n";

    my $count = 0;
    my $last_function_group;

    # count cog/kog path and cog/kog func as cog/kog path
    my $count2 = 0;
    my $count3 = 0;
    for ( ; ; ) {
        my ( $function_code, $function_group, $definition, $cog_pathway_oid, $cog_pathway_name ) = $cur->fetchrow();
        last if !$function_code;
        $count++;

        if ($isKOG) {
            if ( $last_function_group ne $function_group ) {
                print "<br/>\n" if ( $count > 1 );
                my $url = "$main_cgi?section=CogCategoryDetail" . "&page=kogGroupList&function_group=$function_group";
                print alink( $url, $function_group ) . " <br/>\n";
            }

            # print defn
            my $url = "$main_cgi?section=CogCategoryDetail" . "&page=${og}CategoryDetail";
            $url .= "&function_code=$function_code";
            print nbsp(4);
            print alink( $url, $definition ) . " [$function_code] <br/>\n";
            $last_function_group = $function_group;
            printStatusLine( "$count loaded.", 2 );

        } else {
            if ( $old_function_code ne $function_code ) {
                print "<br/>\n" if $count > 1;
                my $url = "$main_cgi?section=CogCategoryDetail" . "&page=${og}CategoryDetail";
                $url .= "&function_code=$function_code";
                print alink( $url, $definition ) . " [$function_code]<br/>\n";
                $count2++;
            }
            if ( $cog_pathway_oid ne "" ) {
                my $url = "$main_cgi?section=CogCategoryDetail" . "&page=${og}PathwayDetail";
                $url .= "&${og}_pathway_oid=$cog_pathway_oid";
                print nbsp(4);
                print alink( $url, $cog_pathway_name ) . "<br/>\n";
                $count2++;
                $count3++;
            }
            $old_function_code = $function_code;
            printStatusLine( "$count3 ($count2) loaded.", 2 );
        }
    }
    print "</p>\n";
    $cur->finish();

    #$dbh->disconnect();
}

############################################################################
# printPfamCategories - Show all Pfam categories from COG.
#   --es 10/05/2007
############################################################################
sub printPfamCategories {

    printMainForm();
    print "<h1>Pfam Browser</h1>\n";
    print "<p>\n";
    print "(Pfam Categories are formed from COG categories.)<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
      select distinct cf.function_code, cf.definition, cp.cog_pathway_oid,
        cp.cog_pathway_name
      from pfam_family_cogs pfc, cog_function cf
      left join cog_pathway cp
         on cf.function_code = cp.function
      where pfc.functions = cf.function_code
      order by cf.definition, cp.cog_pathway_name
   };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $old_function_code;
    print "<p>\n";
    my $url = "$section_cgi&page=pfamList";
    print alink( $url, "Pfam list" );
    print "<br/>\n";
    my $url = "$section_cgi&page=pfamListClans";
    print alink( $url, "Pfam clans" );
    print "<br/>\n";
    print "<br/>\n";

    my $count = 0;
    for ( ; ; ) {
        my ( $function_code, $definition, $cog_pathway_oid, $cog_pathway_name ) = $cur->fetchrow();
        last if !$function_code;
        $count++;
        if ( $old_function_code ne $function_code ) {
            print "<br/>\n" if $count > 1;
            my $url = "$main_cgi?section=PfamCategoryDetail" . "&page=pfamCategoryDetail";
            $url .= "&function_code=$function_code";
            print alink( $url, $definition ) . " [$function_code]<br/>\n";
        }
        if ( $cog_pathway_oid ne "" ) {
            my $url = "$main_cgi?section=PfamCategoryDetail" . "&page=pfamPathwayDetail";
            $url .= "&cog_pathway_oid=$cog_pathway_oid";
            print nbsp(4);
            print alink( $url, $cog_pathway_name ) . "<br/>\n";
        }
        $old_function_code = $function_code;
    }
    $cur->finish();

    #$dbh->disconnect();
    print "</p>\n";
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printPageHint - Show this page's hint.
############################################################################
sub printPageHint {
    printHint(
        qq{
            All searches treat the keyword as a substring 
            (a word or part of a word).  <br />
            The search should contain some alphanumeric characters.<br/>
            Inexact searches may use matching metacharacters.<br/>
            Use an underscore (_) as a single-character wildcard. <br />
            Use % to match zero or more characters.  <br />
            All matches are case insensitive except indicated. <br />
            Very general searches may be slow.<br/>
            Hold down control key (or command key in the case
            of the Mac) to select multiple genomes.
        }
    );
}

############################################################################
# printImgTermTree - Print term tree for img_term_iex search.
#   "iex" = "inexact" match search.
############################################################################
sub printImgTermTree {
    my $searchTerm   = param("ffgSearchTerm");
    my $searchFilter = param("searchFilter");
    my $seq_status   = param("seqstatus");
    my $domainfilter = param("domainfilter");
    my $taxonChoice  = param("taxonChoice");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    if ( $searchFilter eq "img_term_iex" ||
	 $searchFilter eq "img_term_synonyms_iex" ) {
        if ( $searchTerm && length($searchTerm) < 4 ) {
            webError("Please enter a search term at least 4 characters long.");
        }
    }

    printMainForm();
    my $title = $function2Name{$searchFilter};
    print "<h1>$title Search Results</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my ( $sql, @bindList_sql0 ) = getImgTermTreeSql($searchTermLc);

    #print "printImgTermTree (Gene Product, Modified Product, Protein Complex, Parts List) \$sql: <br/>$sql<br/>";
    my $cur = execSqlBind( $dbh, $sql, \@bindList_sql0, $verbose );

    my @gp_term_oids;
    my @mp_term_oids;
    my @pc_term_oids;
    my @pl_term_oids;
    for ( ; ; ) {
        my ( $term_type, $term_oid, $term ) = $cur->fetchrow();
        last if !$term_oid;
        if ( $term_type eq "GENE PRODUCT" ) {
            push( @gp_term_oids, $term_oid );
        } elsif ( $term_type eq "MODIFIED PROTEIN" ) {
            push( @mp_term_oids, $term_oid );
        } elsif ( $term_type eq "PROTEIN COMPLEX" ) {
            push( @pc_term_oids, $term_oid );
        } elsif ( $term_type eq "PARTS LIST" ) {
            push( @pl_term_oids, $term_oid );
        } else {
            webLog("printImgTermTree: unrecognized term_type='$term_type'\n");
        }
    }
    $cur->finish();

    print "<p>\n";
    print "Search 'IMG Term Hierarchy' with '" 
	. escHtml($searchTerm) . "'.<br/>\n";
    print "Results may be displayed as various points in the ";
    print "hierarchy.<br/>\n";
    print "Only the lowest levels (with no subterms) ";
    print "link to genes through the gene count in parentheses<br/>\n";
    print "if the term has genes associated with it.<br/>\n";
    print "</p>\n";

    webLog "Run IMG Term SQL " . currDateTime() . "\n" if $verbose >= 1;

    my ( $taxonClause, @bindList_txs ) =
	OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $tmpTableFlag = 0;

    my $cashedTermOid2Html_ref = 0;
    my $count_term             = 0;
    my @recs_term;

    my $fileNames = param("file");
    my @files     = split( /\|\|\|/, $fileNames );

    #print "FindFunctions::printImgTermTree() files: @files<br/>";

    my $file_term      = $files[0];
    my $cacheFile_term = getCacheFile($file_term);

    if ( $file_term ne "" && -e $cacheFile_term ) {
        #print "cache file version $file_term <br/>";
        ( $count_term, @recs_term ) = readCacheFile
	    ( $cacheFile_term, $count_term, @recs_term );
    } else {

        #$tmpTableFlag =
        #  prepareTmpTable( $dbh, $taxonClause1, $rclause1, $imgClause1,
        #    \@bindList_txs1, \@bindList_ur1 )
        #  if ( !$tmpTableFlag );
        my ( $sql, @bindList ) =
	    determineImgTermSql( $dbh, $searchTermLc, $taxonClause, $rclause,
				 $imgClause, \@bindList_txs, \@bindList_ur,
				 $tmpTableFlag );

        #print "FindFunctions::printImgTermTree() (Term) \$sql: $sql<br/>";
        #print "FindFunctions::printImgTermTree() bindList: @bindList<br/>";

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $term_oid, $term_name, $gcnt, $tcnt ) = $cur->fetchrow();
            last if !$term_oid;
            $count_term++;
            my $r = "$term_oid\t";
            $r .= "$term_name\t";
            $r .= "$gcnt\t";
            $r .= "$tcnt\t";
            push( @recs_term, $r );
        }
        $cur->finish();
    }

    if ( scalar(@recs_term) > 0 ) {
        my %cashedTermOid2Html = {};

        foreach my $r (@recs_term) {
            my ( $term_oid, $term_name, $gcnt, $tcnt ) = split( /\t/, $r );
            my $s = getTermOidGeneCntLink
		( $term_oid, $searchFilter, $seq_status,
		  $domainfilter, $taxonChoice, $gcnt );
            $cashedTermOid2Html{$term_oid} = $s;
        }

        if ( scalar( keys %cashedTermOid2Html ) > 0 ) {
            $cashedTermOid2Html_ref = \%cashedTermOid2Html;
        }
    }

    require ImgTermNode;
    require ImgTermNodeMgr;
    my $mgr   = new ImgTermNodeMgr();
    my $root  = $mgr->loadTree($dbh);
    my $count = 0;
    $count += printTermType(
	$dbh,           $taxonClause,   $rclause,        $imgClause,
	\@bindList_txs, \@bindList_ur,  $searchFilter,   $seq_status,
	$domainfilter,  $taxonChoice,   "Gene Products", $root,
	$searchTermLc,  \@gp_term_oids, $cashedTermOid2Html_ref
	);
    $count += printTermType(
	$dbh,           $taxonClause,   $rclause,            $imgClause,
	\@bindList_txs, \@bindList_ur,  $searchFilter,       $seq_status,
	$domainfilter,  $taxonChoice,   "Modified Proteins", $root,
	$searchTermLc,  \@mp_term_oids, $cashedTermOid2Html_ref
	);
    $count += printTermType(
	$dbh,           $taxonClause,   $rclause,            $imgClause,
	\@bindList_txs, \@bindList_ur,  $searchFilter,       $seq_status,
	$domainfilter,  $taxonChoice,   "Protein Complexes", $root,
	$searchTermLc,  \@pc_term_oids, $cashedTermOid2Html_ref
	);
    $count += printTermType(
	$dbh,           $taxonClause,   $rclause,      $imgClause,
	\@bindList_txs, \@bindList_ur,  $searchFilter, $seq_status,
	$domainfilter,  $taxonChoice,   "Parts List",  $root,
	$searchTermLc,  \@pl_term_oids, $cashedTermOid2Html_ref
	);
    
    webLog "Run IMG Term Synonyms SQL " . currDateTime() . "\n"
      if $verbose >= 1;

    WebUtil::printFuncCartFooterForEditor() if $count > 0;
    my $count_synonyms = 0;
    my @recs;

    my $file_synonyms      = $files[1];
    my $cacheFile_synonyms = getCacheFile($file_synonyms);
    if ( $file_synonyms ne "" && -e $cacheFile_synonyms ) {
        #print "cache file version $file_synonyms <br/>";
        ( $count_synonyms, @recs ) = readCacheFile
	    ( $cacheFile_synonyms, $count_synonyms, @recs );
    } else {
        #$tmpTableFlag =
        #  prepareTmpTable( $dbh, $taxonClause, $rclause, $imgClause,
        #    \@bindList_txs, \@bindList_ur )
        #  if ( !$tmpTableFlag );
        my ( $sql, @bindList ) =
	    determineImgTermSynonymsSql
	    ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause,
	      \@bindList_txs, \@bindList_ur, $tmpTableFlag );

        #print "printImgTermTree (Term Synonyms) \$sql: $sql<br/>";
        #print "\@bindList: @bindList<br/>";

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $term_oid, $synonyms, $gcnt, $tcnt ) = $cur->fetchrow();
            last if !$term_oid;
            $count_synonyms++;
            my $r = "$term_oid\t";
            $r .= "$synonyms\t";
            $r .= "$gcnt\t";
            $r .= "$tcnt\t";
            push( @recs, $r );
        }
        $cur->finish();
    }

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    webLog "Done IMG Term Synonyms SQL " . currDateTime() . "\n"
	if $verbose >= 1;

    if ( scalar(@recs) > 0 ) {
        print "<h2>Term Synonyms</h2>\n";
        print "<p>\n";

        my $it = new InnerTable( 1, "termsynonym$$", "termsynonym", 2 );
        my $sd = $it->getSdDelim();
        $it->addColSpec( "Select" );
        $it->addColSpec( "Term ID",      "asc",  "right" );
        $it->addColSpec( "Synonyms",     "asc",  "left" );
        $it->addColSpec( "Gene Count",   "asc",  "right" );
        $it->addColSpec( "Genome Count", "desc", "right" );

        my $searchFilter = "img_term_synonyms_iex";
        foreach my $r (@recs) {
            my ( $term_oid, $synonyms, $gcnt, $tcnt ) = split( /\t/, $r );

            my $r;
            $r .= $sd . "<input type='checkbox' name='term_oid' value='$term_oid' />\n" . "\t";

            $term_oid = FuncUtil::termOidPadded($term_oid);
            my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
            $url .= "&term_oid=$term_oid";
            $r   .= $term_oid . $sd . alink( $url, $term_oid ) . "\t";

            my $s = $synonyms;
            my $matchText = highlightMatchHTML2( $s, $searchTerm );
            $r .= $matchText . $sd . $matchText . "\t";

            # gene count
            my $g_url = "$section_cgi&page=ffgFindFunctionsGeneList";
            $g_url .= "&searchFilter=$searchFilter";
            $g_url .= "&id=$term_oid";
            $g_url .= "&cnt=$gcnt";
            $g_url .= "&seqstatus=$seq_status";
            $g_url .= "&domainfilter=$domainfilter";
            $g_url .= "&taxonChoice=$taxonChoice";
            if ( $gcnt > 0 ) {
                $r .= $gcnt . $sd . alink( $g_url, $gcnt ) . "\t";
            } else {
                $r .= $gcnt . $sd . "0" . "\t";
            }

            # genome count
            my $t_url = "$section_cgi&page=ffgFindFunctionsGenomeList";
            $t_url .= "&searchFilter=$searchFilter";
            $t_url .= "&id=$term_oid";
            $t_url .= "&cnt=$tcnt";
            $t_url .= "&seqstatus=$seq_status";
            $t_url .= "&domainfilter=$domainfilter";
            $t_url .= "&taxonChoice=$taxonChoice";
            if ( $tcnt > 0 ) {
                $r .= $tcnt . $sd . alink( $t_url, $tcnt ) . "\t";
            } else {
                $r .= $tcnt . $sd . "0" . "\t";
            }

            $it->addRow($r);
        }

        print "</p>\n";

        $it->printOuterTable(1);
    }

    WebUtil::printFuncCartFooterForEditor() if $count_synonyms > 0;
    printStatusLine( "$count terms loaded.", 2 );
}

sub getImgTermTreeSql {
    my ($searchTermLc) = @_;

    my $xtra = "or it.term_oid = ? " if ( isInt($searchTermLc) );
    my $sql  = qq{
        select distinct it.term_type, it.term_oid, it.term
        from img_term it
        where (lower( it.term ) like ? $xtra)
        order by it.term_type, it.term
    };

    my @bindList = ();
    push( @bindList, "%$searchTermLc%" );
    push( @bindList, "$searchTermLc" ) if ( isInt($searchTermLc) );

    return ( $sql, @bindList );
}

############################################################################
# prinTermType - Print one term type.
############################################################################
sub printTermType {
    my (
	$dbh, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
	$bindList_ur_ref, $searchFilter, $seq_status, $domainfilter,
	$taxonChoice, $term_type, $root, $searchTermLc, $term_oids_ref,
	$cashedTermOid2Html_ref
      )
      = @_;

    my $nTerms = @$term_oids_ref;
    return if $nTerms == 0;

    print "<h2>" . escHtml($term_type) . "</h2>\n";
    print "<p>\n";
    my %done;
    my $count = 0;
    for my $term_oid (@$term_oids_ref) {
        next if $done{$term_oid};
        $count++;
        print "Result " . sprintf( "%03d:", $count ) . nbsp(1);
        my $n = $root->ImgTermNode::findNode($term_oid);
        if ( !defined($n) ) {
            webLog("FindFunctions::printTermType() cannot find term_oid='$term_oid'\n");
            next;
        }
        my $children  = $n->{children};
        my $nChildren = @$children;
        my @n_term_oids;
        $n->ImgTermNode::loadAllChildTermOids( \@n_term_oids );
        for my $i (@n_term_oids) {
            $done{$i} = 1;
        }
        my %termOid2Html;
        loadSearchTermOid2Html(
	    $dbh,              $taxonClause,     $rclause,      $imgClause,
	    $bindList_txs_ref, $bindList_ur_ref, $searchFilter, $seq_status,
	    $domainfilter,     $taxonChoice,     $n,            $searchTermLc,
	    \%termOid2Html,    $cashedTermOid2Html_ref
        );
        $n->printSearchHtml( $searchTermLc, \%termOid2Html );
        if ( $nChildren > 0 ) {
            print "<br/>\n";
        }
    }
    print "</p>\n";

    return $count;
}

############################################################################
# loadSeachTermOid2Html - Load code to generate HTML tail code for leafs.
############################################################################
sub loadSearchTermOid2Html {
    my (
	$dbh, $taxonClause,  $rclause, $imgClause, $bindList_txs_ref,
	$bindList_ur_ref, $searchFilter, $seq_status, $domainfilter, 
	$taxonChoice, $n, $searchTermLc, $termOid2Html_ref,
	$cashedTermOid2Html_ref
      )
      = @_;

    my @term_oids;
    $n->loadLeafTermOids( \@term_oids );
    my $nTerms   = @term_oids;
    my $term_oid = $n->{term_oid};
    if ( $nTerms > 1000 ) {
        webDie("loadSearchTermOid2Html: term_oid=$term_oid nTerms=$nTerms\n");
    }

    if ( $cashedTermOid2Html_ref > 0 ) {
        for my $oid (@term_oids) {
            my $s = $cashedTermOid2Html_ref->{$oid};
            if ( $s ne "" ) {
                $termOid2Html_ref->{$oid} = $s;

                #print "loadSearchTermOid2Html: $oid $s<br/>\n";
            }
        }
    } else {
        my ( $sql, @bindList ) =
	    getTermOidGeneCntSql
	    ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	      $bindList_txs_ref, $bindList_ur_ref, @term_oids );

        #print "loadSearchTermOid2Html sql: $sql<br/>\n";
        #print "loadSearchTermOid2Html bindList: @bindList<br/>\n";

        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $function, $cnt ) = $cur->fetchrow();
            last if !$function;
            my $s = getTermOidGeneCntLink
		( $function, $searchFilter, $seq_status, $domainfilter,
		  $taxonChoice, $cnt );
            $termOid2Html_ref->{$function} = $s;
        }
        $cur->finish();
    }
}

sub getTermOidGeneCntSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref, @term_oids ) = @_;

    my $xtra = "or it.term_oid = ? " if ( isInt($searchTermLc) );
    my $term_oid_str = join( ',', @term_oids );

    #my $sql = qq{
    #    select it.term_oid, count( distinct g.gene_oid )
    #    from img_term it, dt_img_term_path dtp, gene_img_functions g
    #    where (lower( it.term ) like ? $xtra)
    #    and it.term_oid in( $term_oid_str )
    #    and it.term_oid = dtp.term_oid
    #    and dtp.map_term = g.function
    #    $taxonClause
    #    $rclause
    #    $imgClause
    #    group by it.term_oid
    #    order by it.term_oid
    #};
    my $sql = qq{
        select it.term_oid, count( distinct g.gene_oid )
        from img_term it, gene_img_functions g
        where (lower( it.term ) like ? $xtra)
        and it.term_oid in( $term_oid_str )
        and it.term_oid = g.function
        $taxonClause
        $rclause
        $imgClause
        group by it.term_oid
        order by it.term_oid
    };

    #print "getTermOidGeneCntSql sql: $sql<br/>\n";

    my @bindList_sql = ();
    push( @bindList_sql, "%$searchTermLc%" );
    push( @bindList_sql, "$searchTermLc" ) if ( isInt($searchTermLc) );

    #push( @bindList_sql, 'No' );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    #print "getTermOidGeneCntSql bindList: ".@bindList."<br/>\n";

    return ( $sql, @bindList );
}

sub getTermOidGeneCntLink {
    my ( $term_oid, $searchFilter, $seq_status, $domainfilter, $taxonChoice, $cnt ) = @_;

    $term_oid = FuncUtil::termOidPadded($term_oid);

    my $url = "$section_cgi&page=ffgFindFunctionsGeneList";
    $url .= "&searchFilter=$searchFilter";
    $url .= "&id=$term_oid";
    $url .= "&cnt=$cnt";
    $url .= "&seqstatus=$seq_status";
    $url .= "&domainfilter=$domainfilter";
    $url .= "&taxonChoice=$taxonChoice";
    my $link = 0;
    $link = alink( $url, $cnt ) if $cnt > 0;
    my $s = nbsp(1);
    $s .= "(" . $link . ")";

    return $s;
}

sub getTmpTable {
    my $tableName = "gtt_function_gene";

    my $sql = qq{
        T_ID      NUMBER(16),
        GENE      NUMBER(16),
        TAXON     NUMBER(16)
    };

    return ( $tableName, $sql );
}

sub prepareTmpTable {
    my ( $dbh, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $tableName, $createSql ) = getTmpTable();
    OracleUtil::createTempTableReady( $dbh, $tableName, $createSql );
    my ( $insertSql, @bindList ) =
      getTmpTableInsertSql( $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
    OracleUtil::setTempTableReady( $dbh, $tableName, $insertSql, \@bindList );

    return 1;
}

sub getTmpTableInsertSql {
    my ( $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    #my $sql = qq{
    #    select gif.function,
    #       count(distinct g.gene_oid) gene_cnt,
    #       count(distinct g.taxon) taxon_cnt
    #    from gene_img_functions gif, gene g
    #    where gif.gene_oid = g.gene_oid
    #    and g.obsolete_flag = ?
    #    $taxonClause
    #    $rclause
    #    $imgClause
    #    group by gif.function
    #};
    my $sql = qq{
        select g.function, count(distinct g.gene_oid), count(distinct g.taxon) 
        from gene_img_functions g
        where 1 = 1 
        $taxonClause
        $rclause
        $imgClause
        group by g.function
    };

    my @bindList_sql = ();
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getImgTerm_tmpTableSql {
    my ($searchTermLc) = @_;

    my $oid_search;
    $oid_search = "or it.term_oid = ? " if isInt($searchTermLc);

    my $sql = qq{
        select it.term_oid, it.term, wg.gene, wg.taxon
        from img_term it, gtt_function_gene wg
        where ( lower( it.term ) like ? $oid_search )
        and it.term_oid = wg.t_id
        order by it.term_oid, it.term
    };

    my @bindList = ();
    push( @bindList, "%$searchTermLc%" );
    push( @bindList, "$searchTermLc" ) if isInt($searchTermLc);

    return ( $sql, @bindList );
}

sub getImgTermSynonyms_tmpTableSql {
    my ($searchTermLc) = @_;

    my $sql = qq{
        select ws.term_oid, ws.synonyms, wg.gene, wg.taxon
        from img_term_synonyms ws, gtt_function_gene wg
        where lower( ws.synonyms ) like ?
        and ws.term_oid = wg.t_id
        order by ws.term_oid, ws.synonyms
    };

    my @bindList = ("%$searchTermLc%");

    return ( $sql, @bindList );
}

sub determineImgTermSql {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref, $tmpTableFlag ) = @_;

    my $sql;
    my @bindList = ();
    if ($tmpTableFlag) {
        ( $sql, @bindList ) = getImgTerm_tmpTableSql($searchTermLc);
    } else {
        ( $sql, @bindList ) =
          getImgTermSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
    }

    return ( $sql, @bindList );
}

sub determineImgTermSynonymsSql {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref, $tmpTableFlag ) = @_;

    my $sql;
    my @bindList = ();
    if ($tmpTableFlag) {
        ( $sql, @bindList ) = getImgTermSynonyms_tmpTableSql($searchTermLc);
    } else {
        ( $sql, @bindList ) =
          getImgTermSynonymsSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
    }

    return ( $sql, @bindList );
}

############################################################################
# printCogList - Show list of all KOGs.
############################################################################
sub printKogList {

    my $stats = param('stats');

    my $og = "kog";
    my $OG = "KOG";

    # right now KOG not supported for metagenomes 2012-05-22- ken
    $include_metagenomes = 0;

    print "<h1>Characterized KOGs</h1>\n";

    print "<p>\n";
    print "Note: uncharacterized KOGs are not included in this list.\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my %kog_tcnts;
    my %m_kog_tcnts;

    my $dbh = dbLogin();

    if($stats) {
    printStartWorkingDiv();

    print "<p>Counting isolate genomes ...\n";

    my $rclause   = urClause("g.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon( 'g.taxon_oid', 1 );
    my $sql       = qq{
        select /*+ result_cache */ g.kog, count(distinct g.taxon_oid)
        from mv_taxon_kog_stat g
        where 1 = 1
        $rclause
        $imgClause
        group by g.kog
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $kog_id, $tcnt ) = $cur->fetchrow();
        last if !$kog_id;
        $kog_tcnts{$kog_id} = $tcnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";
    }

    printEndWorkingDiv();
    }

    my $sql = "select kog_id, kog_name from kog";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "koglist$$", "koglist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KOG ID",   "char asc", "left" );
    $it->addColSpec( "KOG Name", "char asc", "left" );
    if($stats) {
    if ($include_metagenomes) {
        $it->addColSpec( "Isolate<br/>Genome Count", "number asc", "right" );
        $it->addColSpec( "Metagenome<br/>Count",     "number asc", "right" );
    } else {
        $it->addColSpec( "Genome Count", "number asc", "right" );
    }
    }

    my $select_id_name = "func_id";

    my $count = 0;
    for ( ; ; ) {
        my ( $kog_id, $kog_name ) = $cur->fetchrow();
        last if !$kog_id;
        next if ( $kog_name =~ /^Uncharacterized/ );
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$kog_id' />" . "\t";

        my $url = "$kog_base_url$kog_id";

        $r .= $kog_id . $sd . alink( $url, $kog_id ) . "\t";
        $r .= $kog_name . $sd . $kog_name . "\t";

        if($stats) {
        my $tcnt = $kog_tcnts{$kog_id};
        if ($tcnt) {
            my $url = "main.cgi?section=CogCategoryDetail&page=ccdKOGGenomeList" . "&gtype=isolate&kog_id=" . $kog_id;
            $r .= $tcnt . $sd . alink( $url, $tcnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        if ($include_metagenomes) {
            my $m_tcnt = $m_kog_tcnts{$kog_id};
            if ($m_tcnt) {
                my $m_url =
                  "main.cgi?section=CogCategoryDetail&page=ccdKOGGenomeList" . "&gtype=metagenome&kog_id=" . $kog_id;
                $r .= $m_tcnt . $sd . alink( $m_url, $m_tcnt ) . "\t";
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
        }
        }
        $it->addRow($r);
    }
    $cur->finish();


    
    if ( $count > 10 ) {
        WebUtil::printFuncCartFooter();
    }
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    ## save to workspace
    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count KOGs retrieved", 2 );
    print end_form();
}

##################################################################################
# printCogList2: COG List
##################################################################################
sub printCogList2 {

    my $stats = param('stats');

    print "<h1>Characterized COGs</h1>\n";

    print "<p>\n";
    print "Note: uncharacterized COGs are not included in this list.\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }

    my %cog_cnts;
    my %m_cog_cnts;

    my $dbh = dbLogin();
    if ($stats) {
        printStartWorkingDiv();

        print "<p>Counting isolate genomes ...\n";

        my $rclause   = urClause("gt.taxon_oid");
        my $imgClause = WebUtil::imgClauseNoTaxon( 'gt.taxon_oid', 1 );
        my $sql       = qq{
        select /*+ result_cache */  gt.cog, count(distinct gt.taxon_oid)
        from mv_taxon_cog_stat gt
        where 1 = 1 
        $rclause
        $imgClause
        group by gt.cog
    };

        #print "FindFunctions::printCogList2() 1 sql: $sql<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $cog_id, $cnt ) = $cur->fetchrow();
            last if !$cog_id;
            $cog_cnts{$cog_id} = $cnt;
        }
        $cur->finish();

        if ($include_metagenomes) {

            print "<p>Counting metagenomes ...\n";

            my $imgClause = WebUtil::imgClauseNoTaxon( 'gt.taxon_oid', 2 );
            $sql = qq{
                select /*+ result_cache */ gt.cog, count(distinct gt.taxon_oid)
                from mv_taxon_cog_stat gt
                where 1 = 1
                $rclause
                $imgClause
                group by gt.cog
            };

            #print "FindFunctions::printCogList2() 2 sql: $sql<br/>\n";

            $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $cog_id, $cnt ) = $cur->fetchrow();
                last if !$cog_id;
                $m_cog_cnts{$cog_id} = $cnt;
            }
            $cur->finish();

            print "<p>Counting MER-FS metagenomes ...\n";

            if ($new_func_count) {
                my $rclause2   = WebUtil::urClause('f.taxon_oid');
                my $imgClause2 = WebUtil::imgClauseNoTaxon( 'f.taxon_oid', 2 );

                $sql = qq{
                    select f.func_id, count(distinct f.taxon_oid)
                    from taxon_cog_count f
                    where f.gene_count > 0
                    $rclause2
                    $imgClause2
                    group by f.func_id
                };
                #print "FindFunctions::printCogList2() 3 sql: $sql<br/>\n";

                $cur = execSql( $dbh, $sql, $verbose );
                for ( ; ; ) {
                    my ( $cog_id, $t_cnt ) = $cur->fetchrow();
                    last if !$cog_id;

                    if ( $m_cog_cnts{$cog_id} ) {
                        $m_cog_cnts{$cog_id} += $t_cnt;
                    } else {
                        $m_cog_cnts{$cog_id} = $t_cnt;
                    }
                }
                $cur->finish();
                print "<br/>\n";
            } else {
                $sql = MerFsUtil::getTaxonsInFileSql();
                $cur = execSql( $dbh, $sql, $verbose );
                for ( ; ; ) {
                    my ($t_oid) = $cur->fetchrow();
                    last if !$t_oid;

                    print ".";
                    my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'cog' );
                    for my $cog_id ( keys %funcs ) {
                        if ( $m_cog_cnts{$cog_id} ) {
                            $m_cog_cnts{$cog_id} += 1;
                        } else {
                            $m_cog_cnts{$cog_id} = 1;
                        }

                        #print "FindFunctions::printCogList2() $cog_id added 1 into m_cog_cnts from file system<br/>\n";
                    }
                }
                $cur->finish();
                print "<br/>\n";
            }
        }
            printEndWorkingDiv();
    }
    my $sql = "select cog_id, cog_name from cog";
    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "coglist$$", "coglist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "COG ID",   "char asc", "left" );
    $it->addColSpec( "COG Name", "char asc", "left" );
    if ($stats) {
        if ($include_metagenomes) {
            $it->addColSpec( "Isolate<br/>Genome Count", "number asc", "right" );
            $it->addColSpec( "Metagenome<br/>Count",     "number asc", "right" );
        } else {
            $it->addColSpec( "Genome Count", "number asc", "right" );
        }
    }
    my $select_id_name = "cog_id";

    my $count = 0;
    for ( ; ; ) {
        my ( $cog_id, $cog_name ) = $cur->fetchrow();
        last if !$cog_id;
        next if ( $cog_name =~ /^Uncharacterized/ );
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$cog_id' />" . "\t";

        my $og_url = $cog_base_url;
##        my $url    = "$og_url$cog_id";
	my $url = "main.cgi?section=CogDetail&page=cogDetail" . 
	    "&cog_id=" . $cog_id;

        $r .= $cog_id . $sd . alink( $url, $cog_id ) . "\t";
        $r .= $cog_name . $sd . $cog_name . "\t";

        if($stats) {
        my $cnt = $cog_cnts{$cog_id};
        if ($cnt) {
            my $url = "main.cgi?section=CogCategoryDetail&page=ccdCOGGenomeList" . "&gtype=isolate&cog_id=" . $cog_id;
            $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        if ($include_metagenomes) {
            my $m_cnt = $m_cog_cnts{$cog_id};
            if ($m_cnt) {
                my $m_url =
                  "main.cgi?section=CogCategoryDetail&page=ccdCOGGenomeList" . "&gtype=metagenome&cog_id=" . $cog_id;
                $r .= $m_cnt . $sd . alink( $m_url, $m_cnt ) . "\t";
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
        }
        }
        $it->addRow($r);
    }
    $cur->finish();

    if ( $sid == 312 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    WebUtil::printFuncCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    ## save to workspace
    if ( $count > 0 ) {
        print hiddenVar( 'save_func_id_name', 'cog_id' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count COGs retrieved", 2 );
    print end_form();
}

############################################################################
# printPfamList - Show list of Pfams.
############################################################################
sub printPfamList {
    
    my $stats = param('stats');
    
    print "<h1>Pfam Families</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();
    my %pfam_cnts;
    my %m_pfam_cnts;

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }

    if($stats) {
    printStartWorkingDiv();

    print "<p>Counting isolate genomes ...\n";

    my $rclause   = urClause("g.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon( 'g.taxon_oid', 1 );
    my $sql       = qq{
        select /*+ result_cache */ g.pfam_family, count(distinct g.taxon_oid)
        from mv_taxon_pfam_stat g
        where 1 = 1
        $rclause
        $imgClause 
        group by g.pfam_family
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $ext_accession, $cnt ) = $cur->fetchrow();
        last if !$ext_accession;
        $pfam_cnts{$ext_accession} = $cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( 'g.taxon_oid', 2 );
        $sql = qq{
            select /*+ result_cache */ g.pfam_family, count(distinct g.taxon_oid)
            from mv_taxon_pfam_stat g
            where 1 = 1
            $rclause
            $imgClause 
            group by g.pfam_family
        };
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $ext_accession, $cnt ) = $cur->fetchrow();
            last if !$ext_accession;
            $m_pfam_cnts{$ext_accession} = $cnt;
        }
        $cur->finish();

        print "<p>Counting MER-FS metagenomes ...\n";

        if ($new_func_count) {
            my $rclause2   = WebUtil::urClause('f.taxon_oid');
            my $imgClause2 = WebUtil::imgClauseNoTaxon( 'f.taxon_oid', 2 );

            $sql = qq{
               select f.func_id, count(distinct f.taxon_oid)
               from taxon_pfam_count f
               where f.gene_count > 0
               $rclause2
               $imgClause2
               group by f.func_id
            };

            $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $pfam_id, $t_cnt ) = $cur->fetchrow();
                last if !$pfam_id;

                if ( $m_pfam_cnts{$pfam_id} ) {
                    $m_pfam_cnts{$pfam_id} += $t_cnt;
                } else {
                    $m_pfam_cnts{$pfam_id} = $t_cnt;
                }
            }
            $cur->finish();
            print "<br/>\n";
        } else {
            $sql = MerFsUtil::getTaxonsInFileSql();
            $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ($t_oid) = $cur->fetchrow();
                last if !$t_oid;

                print ".";
                my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'pfam' );
                for my $pfam_id ( keys %funcs ) {
                    if ( $m_pfam_cnts{$pfam_id} ) {
                        $m_pfam_cnts{$pfam_id} += 1;
                    } else {
                        $m_pfam_cnts{$pfam_id} += 1;
                    }
                }
            }
            $cur->finish();
            print "<br/>\n";
        }
    }
    printEndWorkingDiv();
    }
    my $sql = qq{
        select pf.ext_accession, pf.name, pf.description, pf.db_source
 	    from pfam_family pf
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "pfamlist$$", "pfamlist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Pfam ID",   "asc", "left" );
    $it->addColSpec( "Pfam Name", "asc", "left" );
    if($stats) {
    if ($include_metagenomes) {
        $it->addColSpec( "Isolate<br/>Genome Count", "asc", "right" );
        $it->addColSpec( "Metagenome<br/>Count",     "asc", "right" );
    } else {
        $it->addColSpec( "Genome<br/>Count", "asc", "right" );
    }
    }
    my $select_id_name = "pfam_id";

    my $count = 0;
    for ( ; ; ) {
        my ( $ext_accession, $name, $description, $db_source ) = $cur->fetchrow();
        last if !$ext_accession;
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$ext_accession' />" . "\t";

        my $ext_accession2 = $ext_accession;
        $ext_accession2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$ext_accession2";
        $r .= $ext_accession . $sd . alink( $url, $ext_accession ) . "\t";

        my $x;
        $x = " - $description" if $db_source =~ /HMM/;
        $r .= "$name$x" . $sd . "$name$x" . "\t";

        if($stats) {
        my $cnt = $pfam_cnts{$ext_accession};
        my $url =
            "main.cgi?section=PfamCategoryDetail&page=pcdPfamGenomeList&"
          . "nocat=yes&gtype=isolate&pfam_id="
          . $ext_accession;
        if ($cnt) {
            $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        if ($include_metagenomes) {
            my $m_cnt = $m_pfam_cnts{$ext_accession};
            my $m_url =
              "main.cgi?section=PfamCategoryDetail&page=pcdPfamGenomeList&nocat=yes&gtype=metagenome&pfam_id="
              . $ext_accession;
            if ($m_cnt) {
                $r .= $m_cnt . $sd . alink( $m_url, $m_cnt ) . "\t";
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
        }
        }
        $it->addRow($r);
    }
    $cur->finish();



    if ( $sid == 312 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    print "</p>\n";

    WebUtil::printFuncCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    ## save to workspace
    if ( $count > 0 ) {
        print hiddenVar( 'save_func_id_name', 'pfam_id' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count Pfams retrieved", 2 );
    print end_form();
}

############################################################################
# printPfamListClans - Show list of Pfams under clans.
############################################################################
sub printPfamListClans {
    print "<h1>Pfam Clans</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();
    my $sql = qq{
        select pc.ext_accession, pc.name,
	       pc.description, 
	       pf.ext_accession, pf.name, pf.description, pf.db_source
	    from pfam_clan pc, pfam_clan_pfam_families pcpf, pfam_family pf
	    where  pc.ext_accession = pcpf.ext_accession
	    and pcpf.pfam_families = pf.ext_accession
	    order by lower( pc.description ), lower( pf.name )
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    WebUtil::printFuncCartFooter();

    my $select_id_name = "func_id";

    my $currClan;
    my $countClans = 0;
    for ( ; ; ) {
        my ( $pc_ext_accession, $pc_name, $pc_description, $pf_ext_accession, $pf_name, $pf_description ) = $cur->fetchrow();
        last if !$pc_ext_accession;

        if ( $currClan ne $pc_description ) {
            if ( $countClans > 0 ) {
                print "<br/>\n";
            }
            $countClans++;
            my $url = "$pfam_clan_base_url$pc_ext_accession";
            print alink( $url, $pc_description );
            print "<br/>\n";
        }
        print nbsp(4);
        print "<input type='checkbox' name='$select_id_name' " . "value='$pf_ext_accession' />";
        my $ext_accession2 = $pf_ext_accession;
        $ext_accession2 =~ s/pfam/PF/;
        my $url = "$pfam_base_url$ext_accession2";
        print alink( $url, $pf_ext_accession ) . " - ";
        print escHtml($pf_description) . "<br/>\n";
        $currClan = $pc_description;
    }
    $cur->finish();

    if ( $countClans == 0 ) {
        print "(Clans have not been loaded in this database.)<br/>\n";
    }

    WebUtil::printFuncCartFooter();

    WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);

    printStatusLine( "$countClans clans  retrieved", 2 );

    print end_form();
}

############################################################################
# printEnzymeList - Show list of all enzymes.
############################################################################
sub printEnzymeList {
    print "<h1>Enzymes</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my %ec_cnts;
    my %m_ec_cnts;

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }

    printStartWorkingDiv();

    print "<p>Counting isolate genomes ...\n";

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('g.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon( 'g.taxon_oid', 1 );
    my $sql       = qq{
        select /*+ result_cache */ g.enzyme, count(distinct g.taxon_oid)
        from mv_taxon_ec_stat g 
        where 1 = 1
        $rclause
        $imgClause
        group by g.enzyme
    };
    #print "<p>SQL: $sql\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $ec_num, $cnt ) = $cur->fetchrow();
        last if !$ec_num;

        $ec_cnts{$ec_num} = $cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";
        my $imgClause = WebUtil::imgClauseNoTaxon( 'g.taxon_oid', 2 );
        my $sql       = qq{
            select /*+ result_cache */ g.enzyme, count(distinct g.taxon_oid)
            from mv_taxon_ec_stat g 
            where 1 = 1
            $rclause
            $imgClause
            group by g.enzyme
        };

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $ec_num, $cnt ) = $cur->fetchrow();
            last if !$ec_num;
            $m_ec_cnts{$ec_num} = $cnt;
        }
        $cur->finish();

        print "<p>Counting metagenome genes ...\n";
        if ($new_func_count) {
            my $rclause2   = WebUtil::urClause('f.taxon_oid');
            my $imgClause2 = WebUtil::imgClauseNoTaxon( 'f.taxon_oid', 2 );

            $sql = qq{
               select f.func_id, count(distinct f.taxon_oid)
               from taxon_ec_count f
               where f.gene_count > 0
               $rclause2
               $imgClause2
               group by f.func_id
            };

            $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $ec_id, $t_cnt ) = $cur->fetchrow();
                last if !$ec_id;

                if ( $m_ec_cnts{$ec_id} ) {
                    $m_ec_cnts{$ec_id} += $t_cnt;
                } else {
                    $m_ec_cnts{$ec_id} = $t_cnt;
                }
            }
            $cur->finish();
            print "<br/>\n";
        } else {
            $sql = MerFsUtil::getTaxonsInFileSql();
            $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ($t_oid) = $cur->fetchrow();
                last if !$t_oid;

                print ".";
                my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'ec' );
                for my $k ( keys %funcs ) {
                    if ( $m_ec_cnts{$k} ) {
                        $m_ec_cnts{$k} += 1;
                    } else {
                        $m_ec_cnts{$k} = 1;
                    }
                }
            }
            $cur->finish();
            print "<br/>\n";
        }
    }

    $sql = "select ec_number, enzyme_name from enzyme";
    $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "enzylist$$", "enzylist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "ID",   "asc", "left" );
    $it->addColSpec( "Name", "asc", "left" );
    if ($include_metagenomes) {
        $it->addColSpec( "Isolate<br/>Genome Count", "number asc", "right" );
        $it->addColSpec( "Metagenome<br/>Count",     "number asc", "right" );
    } else {
        $it->addColSpec( "Genome<br/>Count", "number asc", "right" );
    }

    my $select_id_name = "ec_number";

    my $count = 0;
    for ( ; ; ) {
        my ( $ec_number, $enzyme_name ) = $cur->fetchrow();
        last if !$ec_number;
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$ec_number' />" . "\t";

        my $url = "$enzyme_base_url$ec_number";

        $r .= $ec_number . $sd . alink( $url, $ec_number ) . "\t";
        $r .= $enzyme_name . $sd . $enzyme_name . "\t";

        my $cnt = $ec_cnts{$ec_number};
        if ($cnt) {
            my $url = $section_cgi . "&page=EnzymeGenomeList" . "&gtype=isolate&ec_number=" . $ec_number;
            $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }

        if ($include_metagenomes) {
            my $m_cnt = $m_ec_cnts{$ec_number};
            if ($m_cnt) {
                my $m_url = $section_cgi . "&page=EnzymeGenomeList" . "&gtype=metagenome&ec_number=" . $ec_number;
                $r .= $m_cnt . $sd . alink( $m_url, $m_cnt ) . "\t";
            } else {
                $r .= "0" . $sd . "0" . "\t";
            }
        }

        $it->addRow($r);
    }
    $cur->finish();

    #$dbh->disconnect();

    printEndWorkingDiv();

    if ( $sid == 312 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    WebUtil::printFuncCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    ## save to workspace
    if ( $count > 0 ) {
        print hiddenVar( 'save_func_id_name', 'ec_number' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count enzymes retrieved", 2 );
    print end_form();
}

###############################################################################
# printEnzymeGenomeList: list all genomes with ec_number
###############################################################################
sub printEnzymeGenomeList {
    my $ec_number = param('ec_number');
    my $gtype     = param('gtype');
    if ( !$gtype ) {
        $gtype = 'isolate';
    }

    my $dbh = dbLogin();
    my $name = enzymeName( $dbh, $ec_number );
    if ( $gtype eq 'metagenome' ) {
        print "<h1>Metagenomes with $ec_number</h1>\n";
    } else {
        print "<h1>Isolate Genomes with $ec_number</h1>\n";
    }
    print "<p>\n";
    print "Genomes with <i>" . escHtml($name) . "</i>.<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    printStartWorkingDiv();
    print "Retrieving genome information from database ... <br/>\n";
    my %taxon_info;
    my $rclause1   = urClause("t.taxon_oid");
    my $imgClause1 = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql        = "select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name " . " from taxon t ";
    if ( $gtype eq 'metagenome' ) {
        $sql .= " where genome_type = 'metagenome'";
    } else {
        $sql .= " where genome_type = 'isolate'";
    }
    $sql .= $rclause1 . $imgClause1 . " and t.obsolete_flag = 'No' ";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $domain, $seq_status, $taxon_name ) = $cur->fetchrow();
        last if !$taxon_oid;

        $taxon_info{$taxon_oid} = substr( $domain, 0, 1 ) . "\t" . substr( $seq_status, 0, 1 ) . "\t" . $taxon_name;
    }
    $cur->finish();

    #my $rclause   = urClause("g.taxon");
    #my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    #$sql = qq{
    #   select g.taxon, count(distinct g.gene_oid)
    #   from gene_ko_enzymes gke, gene g
    #   where gke.enzymes = ?
    #   and gke.gene_oid = g.gene_oid
    #   and g.locus_type = 'CDS'
    #   and g.obsolete_flag = 'No'
    #   $rclause
    #   $imgClause
    #   group by g.taxon
    #};
    #if ($include_metagenomes) {
    #    $sql = qq{
    #       select g.taxon, count(distinct g.gene_oid)
    #       from gene_ko_enzymes g
    #       where g.enzymes = ?
    #       $rclause
    #       $imgClause
    #       group by g.taxon
    #    };
    #}

    my $rclause   = urClause("g.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');
    $sql = qq{
       select /*+ result_cache */ g.taxon_oid, g.gene_count
       from mv_taxon_ec_stat g
       where g.enzyme = ?
       $rclause
       $imgClause
    };

    $cur = execSql( $dbh, $sql, $verbose, $ec_number );

    my $cachedTable = new CachedTable( "genomelist", "genomelist$$" );
    $cachedTable->addColSpec("Select");
    $cachedTable->addColSpec( "Domain", "char asc", "center", "",
                              "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $cachedTable->addColSpec( "Status", "char asc", "center", "",
                              "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $cachedTable->addColSpec( "Genome",     "char asc",    "left" );
    $cachedTable->addColSpec( "Gene Count", "number desc", "right" );
    my $sdDelim = CachedTable::getSdDelim();

    my $select_id_name = "taxon_filter_oid";

    my $baseUrl          = "";
    my $count            = 0;
    my $total_gene_count = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( !$taxon_info{$taxon_oid} ) {
            next;
        }
        my ( $domain, $seq_status, $taxon_display_name ) =
          split( /\t/, $taxon_info{$taxon_oid} );
        $count++;

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";

        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $taxon_display_name . $sdDelim . alink( $url, $taxon_display_name ) . "\t";
        my $url = "$section_cgi&page=EnzymeGenomeGeneList";
        $url .= "&ec_number=$ec_number";
        $url .= "&taxon_oid=$taxon_oid";

        $r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
        $total_gene_count += $cnt;
        $cachedTable->addRow($r);
    }
    $cur->finish();

    my $m_count = 0;
    if ( $gtype eq 'metagenome' ) {

        # count MER-FS
        print "<p>Retriving metagenome gene counts ...<br/>\n";

        my %gene_func_count;
        if ($new_func_count) {
            my $sql3 = "select taxon_oid, gene_count from taxon_ec_count where func_id = ? ";
            my $cur3 = execSql( $dbh, $sql3, $verbose, $ec_number );
            for ( ; ; ) {
                my ( $tid3, $cnt3 ) = $cur3->fetchrow();
                last if !$tid3;

                if ( $gene_func_count{$tid3} ) {
                    $gene_func_count{$tid3} += $cnt3;
                } else {
                    $gene_func_count{$tid3} = $cnt3;
                }
            }
            $cur3->finish();
        }

        my $rclause2   = urClause("t");
        my $imgClause2 = WebUtil::imgClause('t');
        my $sql2       = qq{
            select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name
            from taxon t
            where t.in_file = 'Yes'
            and t.genome_type = 'metagenome'
            and t.obsolete_flag = 'No'
            $rclause2
            $imgClause2
        };

        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ( $t_oid, $domain, $seq_status, $taxon_display_name ) = $cur2->fetchrow();
            last if !$t_oid;

            $m_count++;
            print ".";
            if ( ( $m_count % 180 ) == 0 ) {
                print "<br/>\n";
            }

            my $g_cnt = 0;
            if ($new_func_count) {
                $g_cnt = $gene_func_count{$t_oid};
            } else {
                $g_cnt = MetaUtil::getTaxonOneFuncCnt( $t_oid, "", $ec_number );
            }

            if ( $g_cnt > 0 ) {
                $domain     = substr( $domain,     0, 1 );
                $seq_status = substr( $seq_status, 0, 1 );
                my $url = "$main_cgi?section=MetaDetail&page=metaDetail";
                $url .= "&taxon_oid=$t_oid";
                my $r;
                $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$t_oid' /> \t";
                $r .= "$domain\t";
                $r .= "$seq_status\t";
                $r .= $taxon_display_name . $sdDelim . alink( $url, $taxon_display_name ) . "\t";

                $url = "$section_cgi&page=EnzymeGenomeGeneList";
                $url .= "&ec_number=$ec_number";
                $url .= "&taxon_oid=$t_oid";
                $r   .= $g_cnt . $sdDelim . alink( $url, $g_cnt ) . "\t";
                $cachedTable->addRow($r);
                $total_gene_count += $g_cnt;
                $count++;
            }
        }
        $cur2->finish();
    }

    #$dbh->disconnect();

    printEndWorkingDiv();

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    if ( $count > 10 ) {
        WebUtil::printGenomeCartFooter();
    }
    $cachedTable->printTable();
    WebUtil::printGenomeCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();
}

##########################################################################
# printEnzymeGenomeGeneList: List all genes taxon_oid with ec_number
##########################################################################
sub printEnzymeGenomeGeneList {
    my $ec_number = param("ec_number");
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( 'taxon_oid', $taxon_oid );
    print hiddenVar( 'func_id',   $ec_number );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = MerFsUtil::getFsTaxonsInfoSql();
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $id2, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();
    if ( !$id2 ) {

        #$dbh->disconnect();
        return;
    }

    require InnerTable;
    my $it = new InnerTable( 1, "cogGenes$$", "cogGenes", 1 );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    my $gene_count     = 0;
    my $show_gene_name = 1;
    my $trunc          = 0;
    if ( $in_file eq 'Yes' ) {

        # MER-FS
        printStartWorkingDiv();
        print "<p>Retrieving gene information ...<br/>\n";
        my %genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, '', $ec_number );
        my @gene_oids = ( keys %genes );

        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID", "char asc", "left" );
        if ($show_gene_name) {
            $it->addColSpec( "Gene Product Name", "char asc", "left" );
        }
        $it->addColSpec( "Genome Name", "char asc", "left" );

        for my $key (@gene_oids) {
            my $workspace_id = $genes{$key};
            my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

            my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
            $row .=
                $workspace_id . $sd
              . "<a href='main.cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$tid"
              . "&data_type=$dt&gene_oid=$key'>$key</a></td>\t";

            if ($show_gene_name) {
                my ( $value, $source ) = MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
                if ( !$value ) {
                    $value = 'hypothetical protein';
                }
                $row .= $value . $sd . $value . "\t";
            }
            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$tid'>$taxon_name</a></td>\t";

            $it->addRow($row);
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
    } else {
        my $rclause   = urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        #    my $taxonClause = txsClause( "g.taxon", $dbh );
        my $sql = qq{
            select distinct g.gene_oid, g.gene_display_name, g.locus_tag
            from gene_ko_enzymes gke, gene g
            where gke.taxon = ?
            and gke.enzymes = ?
            and gke.gene_oid = g.gene_oid
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            $rclause
            $imgClause
        };

        #print "printEnzymeGenomeGeneList \$sql: $sql<br/>";
        #print "taxon_oid: $taxon_oid, ec_number: $ec_number<br/>";
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $ec_number );
        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID",           "char asc", "left" );
        $it->addColSpec( "Locus Tag",         "char asc", "left" );
        $it->addColSpec( "Gene Product Name", "char asc", "left" );
        $it->addColSpec( "Genome Name",       "char asc", "left" );

        for ( ; ; ) {
            my ( $gene_oid, $gene_name, $locus_tag ) = $cur->fetchrow();
            last if !$gene_oid;
            my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\t";
            $row .=
                $gene_oid . $sd
              . "<a href='main.cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid'>"
              . "$gene_oid</a>\t";
            $row .= $locus_tag . $sd . $locus_tag . "\t";
            $row .= $gene_name . $sd . $gene_name . "\t";
            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid'>$taxon_name</a>\t";

            $it->addRow($row);
            $gene_count++;

            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        $cur->finish();
    }

    #$dbh->disconnect();

    my $msg = '';
    if ( !$show_gene_name ) {
        $msg = "Gene names are not displayed. Use 'Exapnd Gene Table Display' option to view detailed gene information.";
        printHint($msg);
    }
    printGeneCartFooter() if ( $gene_count > 10 );
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ( !$show_gene_name ) {
        printHint($msg);
    }

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();

        print hiddenVar ( 'data_type', 'both' );
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

############################################################################
# printTigrfamList - Show list of all TIRGfams.
############################################################################
sub printTigrfamList {
    print "<h1>TIGRfams</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh = dbLogin();
    my $sql = qq{
       select tf.ext_accession, tf.expanded_name
	   from tigrfam tf
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    WebUtil::printFuncCartFooter();

    my $count = 0;
    for ( ; ; ) {
        my ( $ext_accession, $expanded_name ) = $cur->fetchrow();
        last if !$ext_accession;

        $count++;
        print "<input type='checkbox' name='tigrfam_id' ";
        print "value='$ext_accession' />$ext_accession";
        print nbsp(1);
        print escHtml($expanded_name);
        print "<br/>\n";
    }
    $cur->finish();
    
    WebUtil::printFuncCartFooter();

    print end_form();
    printStatusLine( "$count TIGRfams retrieved", 2 );
}

############################################################################
# printGeneDisplayNames - Show matching gene_display_name from query
############################################################################
sub printGeneDisplayNames {
    my ($numTaxon) = @_;
    my $searchFilter = param("searchFilter");
    my $searchTerm   = param("ffgSearchTerm");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;
    my ( $searchTermPartLc, undef ) = split( /[\%_]/, $searchTermLc );

    if ( $searchTerm && length($searchTerm) < 4 ) {
        webError("Please enter a search term at least 4 characters long.");
    }

    my $seq_status   = param("seqstatus");
    my $domainfilter = param("domainfilter");
    my $taxonChoice  = param("taxonChoice");
    my $data_type    = param("q_data_type");

    my $selectionType = param("selectType");
    if ($selectionType eq "selDomain") {
        $seq_status = param("seqstatus0");
        $domainfilter = param("domainfilter0");
    } elsif ($selectionType eq "allIsolates") {
	$seq_status = param("seqstatus0");
	$domainfilter = "isolates";
    }

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");
    if ( $include_metagenomes && scalar(@genomeFilterSelections) < 1 &&
	 $selectionType eq "selGenomes" ) {
        webError("Please select at least one genome or one metagenome.");
    }
    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    my $dbh = dbLogin();

    my @dbTaxons   = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) 
                = MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }

    } elsif ($selectionType eq "selDomain" ||
	     $selectionType eq "allIsolates") { 
	# no need to get taxons
    } else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) 
                = OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile( $dbh, $taxonClause, \@bindList_txs );
            @metaTaxons = keys %taxon_in_file;
        }
    }
    #print "printGeneDisplayNames() dbTaxons: @dbTaxons<br/>\n";
    #print "printGeneDisplayNames() metaTaxons: @metaTaxons<br/>\n";
    if ( $include_metagenomes && isMetaSupported($searchFilter)
        && scalar(@metaTaxons) > $max_metagenome_selection ) {
        webError("Please select no more than $max_metagenome_selection metagenomes.");
    }

    # get user product name preference
    my $contact_oid = getContactOid();
    my $userPref = WebUtil::getMyIMGPref( $dbh, 'MYIMG_PROD_NAME' );
    if ( blankStr($userPref) ) {
        # default is yes
        $userPref = 'Yes';
    }

    printMainForm();
    print hiddenVar( "seqstatus_alt",    $seq_status );
    print hiddenVar( "domainfilter_alt", $domainfilter );
    print hiddenVar( "taxonChoice_alt",  $taxonChoice );
    print hiddenVar( "data_type",  $data_type );

    my $title = $function2Name{$searchFilter};
    print "<h1>$title Search Results</h1>\n";
    print "<p>";
    print "<u>Keyword</u>: " . $searchTerm;
    if ( scalar(@metaTaxons) > 0 ) {
        HtmlUtil::printMetaDataTypeSelection($data_type, 1);
    }
    printGeneDisplayNameMsg($userPref, 1);
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    if ( $maxGeneListResults ne "" ) {
        $max_rows = $maxGeneListResults;
    }

    my $count = 0;
    my $trunc = 0;
    my @recs;

    # cache file
    my $file      = param("file");
    my $cacheFile = getCacheFile($file);
    $file = "";    # traceTest

    # --es 07/05/13
    if ( $search_dir ne '' ) {
        my ( $nOra, $nFs ) = countGenomeSelections($dbh);
        my $allOra = 0;
        $allOra = 1 if $nOra > 0 && $nFs == 0;
        if ( $nOra > 0 && $nFs > 0 ) {
            printStatusLine( "Error", 2 );
            webError("Cannot mix MER-FS genomes with regular genomes. "
		   . "Please select one set or the the other, but not both.");
            $dbh->disconnect();
            return;
        }
        webLog("nOra=$nOra nFs=$nFs allOra=$allOra\n");
        my $productSdb = "$search_dir/gene_product_genes.sdb";

        #print "printGeneDisplayNames() productSdb: $productSdb<br/>\n";
        if ( ( !$include_metagenomes || $allOra ) && -e $productSdb ) {
            $file      = $$;
            $cacheFile = getCacheFile($file);
            searchProductSdb( $dbh, $productSdb, $searchTermLc, $cacheFile );
        }
    }

    if ( $file ne "" && -e $cacheFile ) {
        #print "printGeneDisplayNames() use cacheFile=$cacheFile<br/>\n";
        ( $count, @recs ) = readCacheFile( $cacheFile, $count, @recs );
    } else {
        printStartWorkingDiv();

        my %merfs_genecnt;
        my %merfs_genomecnt;
        if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
            my @type_list = MetaUtil::getDataTypeList( $data_type );
            my $tag       = "gene_product";

            foreach my $toid (@metaTaxons) {
                $toid = sanitizeInt($toid);
                my %productName2genomeAdded;

                for my $data_type (@type_list) {
                    print "Check metagenome $toid $data_type ...<br/>\n";

                    my %gene_name_h;
                    MetaUtil::doGeneProdNameSearch( 1, 1, $toid, $data_type, $tag, $searchTermLc, \%gene_name_h );

                    for my $key ( keys %gene_name_h ) {
                        my $product_name = $gene_name_h{$key};
                        $merfs_genecnt{$product_name} = $merfs_genecnt{$product_name} + 1;

                        if ( !exists $merfs_genomecnt{$product_name} ) {
                            $merfs_genomecnt{$product_name}         = 1;
                            $productName2genomeAdded{$product_name} = 1;

                            #print "Check metagenome  0 $toid $data_type added $product_name ...<br/>\n";
                        } else {
                            if ( !exists $productName2genomeAdded{$product_name} ) {
                                $merfs_genomecnt{$product_name} = $merfs_genomecnt{$product_name} + 1;
                                $productName2genomeAdded{$product_name} = 1;

                                #print "Check metagenome 1 $toid $data_type added $product_name ...<br/>\n";
                            }
                        }
                    }
                }

            }
        }

        if ( $contact_oid == 100546 ) {
            print "<p>*** db start time: " . currDateTime() . "<br/>\n";
        }

        if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
            #no need to fetch things from database
        } else {
            print "Check db ...<br/>\n";

            ##try UI screening stratefy, the performance is the same as before
            #my %name2genes;
            #my %name2genomes;
            #
            #my %validTaxons;
            #if ( scalar(@dbTaxons) > 0 ) {
            #     %validTaxons = QueryUtil::fetchValidTaxonOidHash( $dbh, @dbTaxons );
            #} else {
            #     %validTaxons = QueryUtil::fetchValidTaxonOidHash( $dbh, @genomeFilterSelections );
            #}
            #print "printGeneDisplayNames() valid taxons: " . keys(%validTaxons). "<br/>\n";
            #
            ## change query to use MyIMG annotated product names
            #my ( $tclause1, @bindList_txs1 );
            #if ( scalar(@dbTaxons) > 0 ) {
            #    ( $tclause1, @bindList_txs1 ) = OracleUtil::getTaxonSelectionClauseBind( $dbh, "g1.taxon", \@dbTaxons );
            #} else {
            #    ( $tclause1, @bindList_txs1 ) =
            #      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g1.taxon", \@genomeFilterSelections );
            #}
            #my ( $rclause1, @bindList_ur1 ) = urClauseBind("g1.taxon");
            #my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');
            #
            #my ( $sql, @bindList ) = getGeneDisplayNameGeneGenomeUserPrefSql(
            #     $searchTermLc, $userPref, $contact_oid, 
            #     $tclause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1
            #);
            #print "printGeneDisplayNames() UserPrefSql sql: $sql<br/>\n";
            #print "printGeneDisplayNames() UserPrefSql bindList: @bindList<br/>\n";
            #($count, $trunc) = processGeneDisplayNames( $dbh, 
            #    \%validTaxons, \%name2genes, \%name2genomes,
            #    $sql, \@bindList, $count, $trunc, $max_rows );
            #
            #if ( !$trunc ) {
            #    my ( $tclause, @bindList_txs );
            #    if ( scalar(@dbTaxons) > 0 ) {
            #        ( $tclause, @bindList_txs ) = OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@dbTaxons );
            #    } else {
            #        ( $tclause, @bindList_txs ) =
            #          OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections );
            #    }
            #    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
            #    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
            #
            #    my ( $sql, @bindList ) = getGeneDisplayNameGeneGenomeSql(
            #         $searchTermLc, $tclause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur);
            #    print "printGeneDisplayNames() sql: $sql<br/>\n";
            #    print "printGeneDisplayNames() bindList: @bindList<br/>\n";
            #    ($count, $trunc) = processGeneDisplayNames( $dbh, 
            #        \%validTaxons, \%name2genes, \%name2genomes,
            #        $sql, \@bindList, $count, $trunc, $max_rows );                
            #}
            #
            #for my $name ( keys %name2genes ) {
            #    my $gids_href = $name2genes{$name};
            #    my $gcnt = scalar(keys %$gids_href) if ($gids_href);
            #    my $tids_href = $name2genomes{$name};
            #    my $tcnt = scalar(keys %$tids_href) if ($tids_href);
            #
            #    if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
            #        if ( exists $merfs_genecnt{ lc($name) } ) {
            #            my $gcnt2 = $merfs_genecnt{ lc($name) };
            #            my $tcnt2 = $merfs_genomecnt{ lc($name) };
            #            $gcnt += $gcnt2;
            #            $tcnt += $tcnt2;
            #            delete $merfs_genecnt{ lc($name) };
            #            delete $merfs_genomecnt{ lc($name) };
            #        }
            #    }
            #    push( @recs, "$name\t$gcnt\t$tcnt" );
            #}

            my ( $tclause, @bindList_txs );
            if ( scalar(@dbTaxons) > 0 ) {
                ( $tclause, @bindList_txs ) = 
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g.taxon", \@dbTaxons );

	    } elsif ($selectionType eq "selDomain" || 
		     $selectionType eq "allIsolates") { 
		# no need to get taxons
            } else {
                ( $tclause, @bindList_txs ) =
                  OracleUtil::getTaxonSelectionClauseBind
		  ( $dbh, "g.taxon", \@genomeFilterSelections );
            }
            my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
            my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

            # change query to use MyIMG annotated product names
            my ( $tclause1, @bindList_txs1 );
	    my $bydomain = 0;
            if ( scalar(@dbTaxons) > 0 ) {
                ( $tclause1, @bindList_txs1 ) = 
		    OracleUtil::getTaxonSelectionClauseBind
		    ( $dbh, "g1.taxon", \@dbTaxons );

	    } elsif ($selectionType eq "selDomain" || 
		     $selectionType eq "allIsolates") { 
		$bydomain = $domainfilter;
            } else {
                ( $tclause1, @bindList_txs1 ) =
                  OracleUtil::getTaxonSelectionClauseBind
		  ( $dbh, "g1.taxon", \@genomeFilterSelections );
            }

            my ( $rclause1, @bindList_ur1 ) = urClauseBind("g1.taxon");
            my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');

            my ( $sql, @bindList ) = getGeneDisplayNameSql
		($searchTermLc, $userPref, $contact_oid, $tclause, $rclause,
                 $imgClause, \@bindList_txs, \@bindList_ur, $tclause1, 
		 $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1, 
		 $bydomain, $seq_status);
            #print "printGeneDisplayNames() sql: $sql<br/>\n";
            #print "printGeneDisplayNames() bindList: @bindList<br/>\n";

            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
            for ( ; ; ) {
                my ( $gene_display_name, $gcnt, $tcnt ) = $cur->fetchrow();
                last if !$gcnt;

                if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
                    if ( exists $merfs_genecnt{ lc($gene_display_name) } ) {
                        my $gcnt2 = $merfs_genecnt{ lc($gene_display_name) };
                        my $tcnt2 = $merfs_genomecnt{ lc($gene_display_name) };
                        $gcnt += $gcnt2;
                        $tcnt += $tcnt2;
                        delete $merfs_genecnt{ lc($gene_display_name) };
                        delete $merfs_genomecnt{ lc($gene_display_name) };
                    }
                }

                push( @recs, "$gene_display_name\t$gcnt\t$tcnt" );
                $count++;

                if ( $count > $max_rows ) {
                    $trunc = 1;
                    last;
                }
            }
            $cur->finish();

            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $tclause =~ /gtt_num_id/i );
        }
        if ( $contact_oid == 100546 ) {
            print "<p>*** db end time: " . currDateTime() . "<br/>\n";
        }

        printEndWorkingDiv();

        if ( $count <= $max_rows ) {
            foreach my $key ( keys %merfs_genecnt ) {
                my $gcnt2 = $merfs_genecnt{$key};
                my $tcnt2 = $merfs_genomecnt{$key};
                my $rec   = "$key\t";
                $rec .= "$gcnt2\t";
                $rec .= "$tcnt2\t";
                push( @recs, $rec );
                $count++;

                if ( $count > $max_rows ) {
                    $trunc = 1;
                    last;
                }
            }
        }
    }

    if ( $count == 0 ) {
        print "<p>No entries found.</p>\n";
        return;
    }

    use TabHTML;
    TabHTML::printTabAPILinks("findfnsTab");
    my @tabIndex = ( "#findfnstab1", "#findfnstab2" );
    my @tabNames = ( "$title", "$title Profile" );

    TabHTML::printTabDiv("findfnsTab", \@tabIndex, \@tabNames);
    print "<div id='findfnstab1'>";

    my $it = new InnerTable( 1, "function$$", "function", 1 );
    my $sd = $it->getSdDelim();    
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene Product Name", "asc",  "left" );
    $it->addColSpec( "Gene Count",        "desc", "right" );
    $it->addColSpec( "Genome Count",      "desc", "right" );

    my $count = 0;
    foreach my $line (@recs) {
        my ( $gene_display_name, $gcnt, $tcnt, $product_oid )
	    = split( /\t/, $line );

        $count++;
        if ( $count > $max_rows ) {
            $trunc = 1;
            last;
        }
        my $r;

        #  add checkbox
        my $gene_display_name_escaped =
	    WebUtil::massageToUrl2($gene_display_name) 
	    if ( $gene_display_name ne '' );
        my $tmp =
            "<input type='checkbox' name='gene_display_name' "
          . "value='$gene_display_name_escaped' product_oid='$product_oid' />\n";
        $r .= $sd . $tmp . "\t";

        # name
        my $nameLc = $gene_display_name;
        $nameLc =~ tr/A-Z/a-z/;
        my $idx = index( $nameLc, $searchTermPartLc );
        if ( $idx >= 0 ) {
            my $matchText = highlightMatchHTML2($gene_display_name, $searchTerm);
            $r .= $gene_display_name . $sd . $matchText . "\t";
        } else {
            $r .= $gene_display_name . $sd . $gene_display_name . "\t";
        }

        # gene count
        my $g_url = "$section_cgi&page=geneDisplayNameGenes";
        $g_url .= "&searchFilter=$searchFilter";
        $g_url .= "&gene_display_name=" . massageToUrl($gene_display_name);
        $g_url .= "&seqstatus=$seq_status";
        $g_url .= "&domainfilter=$domainfilter";
        $g_url .= "&taxonChoice=$taxonChoice" if ($taxonChoice);
        if ( $include_metagenomes ) {
            $g_url .= "&data_type=$data_type" if ($data_type);
        }
        if ( $product_oid ) {
            $g_url .= "&product_oid=$product_oid";
        }
        if ( $gcnt > 0 ) {
            $r .= $gcnt . $sd . "~ " . alink( $g_url, $gcnt ) . "\t";
        } else {
            $r .= $gcnt . $sd . "0" . "\t";
        }

        # genome count
        my $t_url = "$section_cgi&page=geneDisplayNameGenomes";
        $t_url .= "&searchFilter=$searchFilter";
        $t_url .= "&gene_display_name=" . massageToUrl($gene_display_name);
        $t_url .= "&seqstatus=$seq_status";
        $t_url .= "&domainfilter=$domainfilter";
        $t_url .= "&taxonChoice=$taxonChoice" if ($taxonChoice);
        if ( $include_metagenomes ) {
            $t_url .= "&data_type=$data_type" if ($data_type);
        }
        if ( $product_oid ) {
            $t_url .= "&product_oid=$product_oid";
        }
        if ( $tcnt > 0 ) {
            $r .= $tcnt . $sd . "~ " . alink( $t_url, $tcnt ) . "\t";
        } else {
            $r .= $tcnt . $sd . "0" . "\t";
        }

        $it->addRow($r);
    }

    printGeneCartFooterGrouped() if ( $count > 10 );
    $it->printOuterTable(1);
    printGeneCartFooterGrouped();

    if ($trunc) {
        printTruncatedStatus($max_rows);
    } else {
        printStatusLine( "$count row(s) retrieved.", 2 );
    }

    print "</div>"; # end findfnstab1

    print "<div id='findfnstab2'>";
    print "<p>";
    print "You may select 1 to $max_prod_name product name(s) and "
    	. "1 to $max_genome_selection genome(s) to see whether the "
    	. "selected product name(s) appear in the selected genome(s).";
    if ( $include_metagenomes ) {
        print "<br/>(MER-FS metegenomes are not supported)";
    }
    print "</p>\n";
    printForm($numTaxon, $max_prod_name, 1);

    my $name = "_section_${section}_viewProdNameProfile";
    GenomeListJSON::printHiddenInputType( $section, 'viewProdNameProfile' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
	( 'go', $name, 'View Profile', '', $section, 
	  'viewProdNameProfile', 'smdefbutton', 'selectedGenome1', 1 );
    print $button;
    print nbsp( 1 );
    print reset( -class => "smbutton" );

    print "</div>"; # end findfnstab2

    TabHTML::printTabDivEnd();
    print end_form();
}

sub processGeneDisplayNames {
    my ( $dbh, $validTaxons_href, $name2genes_href, $name2genomes_href, 
        $sql, $bindList_ref, $count, $trunc, $max_rows ) = @_;

    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );
    for ( ; ; ) {
        my ( $name, $gid, $tid ) = $cur->fetchrow();
        last if !$gid;
        next if !$validTaxons_href->{$tid};

        my $gids_href = $name2genes_href->{$name};
        if ( $gids_href ) {
            $gids_href->{$gid} = 1;
        }
        else {
            my %gids_h;
            $gids_h{$gid} = 1;
            $name2genes_href->{$name} = \%gids_h;
        }

        my $tids_href = $name2genomes_href->{$name};
        if ( $tids_href ) {
            $tids_href->{$tid} = 1;
        }
        else {
            $count++;
            if ( $count > $max_rows ) {
                $trunc = 1;
                last;
            }

            my %tids_h;
            $tids_h{$tid} = 1;
            $name2genomes_href->{$name} = \%tids_h;
        }
    }
    $cur->finish();

    return ($count, $trunc);
}

############################################################################
# printGeneCartFooterGrouped - add genes to gene cart from a table where genes are grouped by gene_display_names
############################################################################
sub printGeneCartFooterGrouped {
    my $id          = "_section_${section}_addToGeneCartGrouped";
    my $buttonLabel = "Add Selected to Gene Cart";
    my $buttonClass = "meddefbutton";
    print submit(
                  -name  => $id,
                  -value => $buttonLabel,
                  -class => $buttonClass
    );
    print nbsp(1);
    WebUtil::printButtonFooter();
}

############################################################################
# getGeneDisplayNameSql
############################################################################
sub getGeneDisplayNameSql {
    my ( $searchTermLc, $userPref, $contact_oid, $tclause, $rclause,
         $imgClause, $bindList_txs_ref, $bindList_ur_ref, 
	 $tclause1, $rclause1, $imgClause1,
	 $bindList_txs1_ref, $bindList_ur1_ref, $bydomain, $seq_status ) = @_;

    my $sql;
    my @bindList = ();

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
	$addfrom = ", taxon tx ";
	$dmClause = " and tx.domain = '$bydomain' ";
	$dmClause = " and tx.genome_type = 'isolate' "
	    if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
	$tclause = " and tx.taxon_oid = g.taxon ";
	$tclause1 = " and tx.taxon_oid = g1.taxon ";
    }

    if ( lc($userPref) eq 'yes' ) {
        $sql = qq{
            WITH
            with_new AS
            (
                select g2.product_name gene_display_name,
                       g2.gene_oid gene_oid, g1.taxon taxon
                from gene_myimg_functions g2, gene g1 $addfrom
                where lower( g2.product_name ) like ?
                and g2.product_name is not null
                and g2.modified_by = ? 
                and g2.gene_oid = g1.gene_oid    
                $dmClause
                $tclause1
                $rclause1
                $imgClause1
                union
                select g.gene_display_name gene_display_name,
                       g.gene_oid gene_oid, g.taxon taxon 
                from gene g $addfrom
                where contains(g.gene_display_name, ?) > 0 
                and g.gene_display_name is not null
                $dmClause
                $tclause
                $rclause
                $imgClause
            )
            select lower(new.gene_display_name), 
               count( distinct new.gene_oid ), count( distinct new.taxon )
            from with_new new
            group by lower(new.gene_display_name)
        };
        push( @bindList, "%$searchTermLc%" );
        push( @bindList, "$contact_oid" );
        push( @bindList, @$bindList_txs1_ref );
        push( @bindList, @$bindList_ur1_ref );
        push( @bindList, "%$searchTermLc%" );
        push( @bindList, @$bindList_txs_ref );
        push( @bindList, @$bindList_ur_ref );
    } else {
        $sql = qq{
    	    select lower(g.gene_display_name), 
    	        count( distinct g.gene_oid ), count( distinct g.taxon )
	        from gene g $addfrom
	        where contains(g.gene_display_name, ?) > 0
	        and g.gene_display_name is not null
                $dmClause
	        $tclause
		--$rclause
		--$imgClause
	        group by lower(g.gene_display_name)
	    };
        push( @bindList, "%$searchTermLc%" );
        push( @bindList, @$bindList_txs_ref );
        push( @bindList, @$bindList_ur_ref );
    }

    return ( $sql, @bindList );
}

############################################################################
# getGeneDisplayNameGeneGenomeUserPrefSql
############################################################################
sub getGeneDisplayNameGeneGenomeUserPrefSql {
    my (
         $searchTermLc, $userPref, $contact_oid,     
         $tclause1, $rclause1, $imgClause1,   
         $bindList_txs1_ref, $bindList_ur1_ref
      )
      = @_;

    my $sql;
    my @bindList;
    if ( lc($userPref) eq 'yes' ) {
        $sql = qq{
            select lower(g2.product_name), g2.gene_oid, g1.taxon
            from gene_myimg_functions g2, gene g1 
            where lower( g2.product_name ) like ?
            and g2.product_name is not null
            and g2.modified_by = ? 
            and g2.gene_oid = g1.gene_oid    
            $tclause1
            $rclause1
            $imgClause1
            order by lower(g2.product_name)
        };
        push( @bindList, "%$searchTermLc%" );
        push( @bindList, "$contact_oid" );
        push( @bindList, @$bindList_txs1_ref );
        push( @bindList, @$bindList_ur1_ref );
    } 

    return ( $sql, @bindList );
}

############################################################################
# getGeneDisplayNameGeneGenomeSql
############################################################################
sub getGeneDisplayNameGeneGenomeSql {
    my ( $searchTermLc, $tclause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select g.gene_display_name, g.gene_oid, g.taxon
        from gene g
        where contains(g.gene_display_name, ?) > 0
        and g.gene_display_name is not null
        $tclause
        $rclause
        $imgClause
    };
    my @bindList;
    push( @bindList, "%$searchTermLc%" );
    push( @bindList, @$bindList_txs_ref );
    push( @bindList, @$bindList_ur_ref );

    return ( $sql, @bindList );
}

############################################################################
# printGeneDisplayNameGenes - Show genes for one gene_display_name.
############################################################################
sub printGeneDisplayNameGenes {
    my $searchFilter      = param("searchFilter");
    my $gene_display_name = param("gene_display_name");
    #if CGI::unescape used, ferredoxin-nadp(+) reductase => ferredoxin-nadp() reductase
    #$gene_display_name = CGI::unescape($gene_display_name);
    $gene_display_name = lc($gene_display_name);

    my $data_type          = param("data_type");
    #print "printGeneDisplayNameGenes() data_type=$data_type<br/>\n";
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections;
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }
    #print "printGeneDisplayNameGenes() genomeFilterSelections=@genomeFilterSelections<br/>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    # get user product name preference
    my $contact_oid = getContactOid();
    my $userPref = WebUtil::getMyIMGPref( $dbh, 'MYIMG_PROD_NAME' );
    if ( blankStr($userPref) ) {
        # default is yes
        $userPref = 'Yes';
    }

    printStartWorkingDiv();

    my ( $gene_oids_ref, $meta_genes_ref );

    # --es 07/09/13
    if ( $search_dir ne '' ) {
        my ( $nOra, $nFs ) = countGenomeSelections($dbh);
        if ( $include_metagenomes && $nFs > 0 ) {
            ( $gene_oids_ref, $meta_genes_ref ) =
		fetchGeneOidsByGeneDisplayName
		( $dbh, $contact_oid, $userPref, $gene_display_name,
		  \@genomeFilterSelections, $data_type );
        } else {
            ( $gene_oids_ref, $meta_genes_ref ) =
		fetchGeneOidsByGeneDisplayNameSdb
		( $dbh, $contact_oid, $userPref, $gene_display_name,
		  \@genomeFilterSelections, $data_type );
        }
    } else {
        ( $gene_oids_ref, $meta_genes_ref ) =
	    fetchGeneOidsByGeneDisplayName
	    ( $dbh, $contact_oid, $userPref, $gene_display_name,
	      \@genomeFilterSelections, $data_type );
    }
    my @gene_oids  = @$gene_oids_ref;
    my @meta_genes = @$meta_genes_ref;

    printEndWorkingDiv();

    if ( scalar(@gene_oids) == 1 && scalar(@meta_genes) == 0 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    my $name  = $function2Name{$searchFilter};
    print "<h1>Genes In $name</h1>";
    print "<p>";
    print "<u>$name</u>: " . $gene_display_name;
    if ( $include_metagenomes && scalar(@meta_genes) > 0 ) {
        print "<br/>MER-FS Metagenome: " . $data_type;
    }
    printGeneDisplayNameMsg($userPref, 1);
    print "</p>\n";

    HtmlUtil::printGeneListHtmlTable( "", "", $dbh, \@gene_oids, \@meta_genes );
}

sub addGeneDisplayNameGenesToCart {
    my @gene_display_names = param("gene_display_name");
    my $data_type = param("data_type");

    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections     = ();
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    # get user product name preference
    my $contact_oid = getContactOid();
    my $userPref = WebUtil::getMyIMGPref( $dbh, 'MYIMG_PROD_NAME' );
    if ( blankStr($userPref) ) {
        # default is yes
        $userPref = 'Yes';
    }

    WebUtil::printStartWorkingDiv();

    my @gene_oids = ();
    foreach my $gene_display_name (@gene_display_names) {
        $gene_display_name = CGI::unescape($gene_display_name);
        my ( $more_gene_oids_ref, $more_meta_gene_oids_ref );

        # --es 07/09/13
        if ( $search_dir ne '' ) {
            my ( $nOra, $nFs ) = countGenomeSelections($dbh);
            if ( $include_metagenomes || $nFs > 0 ) {
                ( $more_gene_oids_ref, $more_meta_gene_oids_ref ) =
                  fetchGeneOidsByGeneDisplayName( $dbh, $contact_oid, $userPref, $gene_display_name,
                                                  \@genomeFilterSelections, $data_type, 1 );
            } else {
                ( $more_gene_oids_ref, $more_meta_gene_oids_ref ) =
                  fetchGeneOidsByGeneDisplayNameSdb( $dbh, $contact_oid, $userPref, $gene_display_name,
                                                     \@genomeFilterSelections, $data_type, 1 );
            }
        } else {
            ( $more_gene_oids_ref, $more_meta_gene_oids_ref ) =
              fetchGeneOidsByGeneDisplayName( $dbh, $contact_oid, $userPref, $gene_display_name, \@genomeFilterSelections,
                                              $data_type, 1 );
        }
        @gene_oids = ( @gene_oids, @$more_gene_oids_ref, @$more_meta_gene_oids_ref );
    }

    #$dbh->disconnect();

    require CartUtil;
    CartUtil::callGeneCartToAdd( \@gene_oids, 1 );
}

############################################################################
# fetchGeneOidsByGeneDisplayName
############################################################################
sub fetchGeneOidsByGeneDisplayName {
    my ( $dbh, $contact_oid, $userPref, $gene_display_name, $genomeFilterSelections_ref, $data_type, $useAlt ) = @_;

    $gene_display_name = lc($gene_display_name);
    my @genomeFilterSelections = @$genomeFilterSelections_ref;

    my @dbTaxons;
    my @metaTaxons;
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }
    } else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) =
              OracleUtil::getTaxonSelectionClauseBind( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile( $dbh, $taxonClause, \@bindList_txs );
            @metaTaxons = keys %taxon_in_file;
        }
    }

    my @meta_genes;
    if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
        my @type_list = MetaUtil::getDataTypeList( $data_type );
        my $tag       = "gene_product";

        foreach my $toid (@metaTaxons) {
            $toid = sanitizeInt($toid);

            for my $data_type (@type_list) {
                #print "Check metagenome $toid $data_type ...<br/>\n";
                my %gene_name_h;
                MetaUtil::doGeneProdNameSearch( 1, 1, $toid, $data_type, $tag, $gene_display_name, \%gene_name_h );
                my @m_genes = keys %gene_name_h;
                push( @meta_genes, @m_genes );
            }
        }

    }

    my @gene_oids;
    if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
        #no need to fetch things from database
    } else {
        my ( $tclause, @bindList_txs );
        if ( scalar(@dbTaxons) > 0 ) {
            ( $tclause, @bindList_txs ) = OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@dbTaxons, $useAlt );
        } else {
            ( $tclause, @bindList_txs ) =
              OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@genomeFilterSelections, $useAlt );
        }
        my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        # change query to use MyIMG annotated product names
        my ( $tclause1, @bindList_txs1 );
        if ( scalar(@dbTaxons) > 0 ) {
            ( $tclause1, @bindList_txs1 ) = OracleUtil::getTaxonSelectionClauseBind( $dbh, "g1.taxon", \@dbTaxons, $useAlt );
        } else {
            ( $tclause1, @bindList_txs1 ) =
              OracleUtil::getTaxonSelectionClauseBind( $dbh, "g1.taxon", \@genomeFilterSelections, $useAlt );
        }
        my ( $rclause1, @bindList_ur1 ) = WebUtil::urClauseBind("g1.taxon");
        my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');

        my ( $sql, @bindList ) = getGeneDisplayNameGeneListSql(
             $gene_display_name, $userPref,  $contact_oid,   $tclause,
             $rclause,           $imgClause, \@bindList_txs, \@bindList_ur,
             $tclause1,          $rclause1,  $imgClause1,    \@bindList_txs1,
             \@bindList_ur1
        );
        #print "FindFunctions::fetchGeneOidsByGeneDisplayName() sql: $sql<br/>\n";
        #print "FindFunctions::fetchGeneOidsByGeneDisplayName() bindList size: ".scalar(@bindList)."<br/>\n";
        #print "FindFunctions::fetchGeneOidsByGeneDisplayName() bindList: @bindList<br/>\n";

        my $cur = execSql( $dbh, $sql, $verbose, @bindList );
        my %done;
        for ( ; ; ) {
            my ( $gene_oid, $gene_name, @junk ) = $cur->fetchrow();
            last if !$gene_oid;
            next if $done{$gene_oid} ne '';

            if ( lc($gene_name) eq $gene_display_name || $gene_name =~ /$gene_display_name/i ) {
                push( @gene_oids, $gene_oid );
                $done{$gene_oid} = 1;
            }
            #else {
            #    print "FindFunctions::printGeneDisplayNameGenes() '$gene_display_name' " . length($gene_display_name). " not matching retrieved '$gene_name' " . length($gene_name). " <br/>\n";
            #}
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $tclause =~ /gtt_num_id/i );
    }

    #print "FindFunctions::fetchGeneOidsByGeneDisplayName() gene_oids: @gene_oids<br/>\n";
    return ( \@gene_oids, \@meta_genes );
}

sub getGeneDisplayNameGeneListSql {
    my (
         $gene_display_name, $userPref,          $contact_oid,     $tclause,  $rclause,
         $imgClause,         $bindList_txs_ref,  $bindList_ur_ref, $tclause1, $rclause1,
         $imgClause1,        $bindList_txs1_ref, $bindList_ur1_ref
      )
      = @_;

    #my $containsClause;
    #my @bindList_contains;
    #my @name_chunks = split(/[-,\[\]\{\}()]+/, $gene_display_name);
    #print "getGeneDisplayNameGeneListSql() name_chunks=@name_chunks<br/>\n";
    #for my $chunk ( @name_chunks ) {
    #    $chunk = WebUtil::strTrim($chunk);
    #    if ( ! $chunk ) {
    #        next;
    #    }
    #    if ( $containsClause ) {
    #        $containsClause .= ' and ';
    #    }
    #    $containsClause .= ' contains(g.gene_display_name, ?) > 0 ';
    #    push( @bindList_contains, $chunk );
    #}
    
    my $sql;
    my @bindList;
    if ( lc($userPref) eq 'yes' ) {
        $sql = qq{
            select g2.gene_oid gene_oid, g2.product_name
            from gene_myimg_functions g2, gene g1 
            where lower(g2.product_name) = ?
            and g2.modified_by = ?
            and g2.gene_oid = g1.gene_oid
            $tclause1
            $rclause1
            $imgClause1
            union 
            select g.gene_oid gene_oid, g.gene_display_name
            from gene g
            where lower(g.gene_display_name) = ?
            $tclause
            $rclause
            $imgClause
        };
            #union 
            #select g.gene_oid gene_oid, g.gene_display_name
            #from gene g
            #where ( $containsClause )
            #$tclause
            #$rclause
            #$imgClause
        push( @bindList, "$gene_display_name" );
        push( @bindList, "$contact_oid" );
        push( @bindList, @$bindList_txs1_ref );
        push( @bindList, @$bindList_ur1_ref );
        push( @bindList, "$gene_display_name" );
        push( @bindList, @$bindList_txs_ref );
        push( @bindList, @$bindList_ur_ref );
        #push( @bindList, @bindList_contains ) if ( scalar(@bindList_contains) > 0 );
        #push( @bindList, @$bindList_txs_ref );
        #push( @bindList, @$bindList_ur_ref );

    } else {
        $sql = qq{
            select g.gene_oid gene_oid, g.gene_display_name
            from gene g
            where lower(g.gene_display_name) = ?
            $tclause
            $rclause
            $imgClause
        };
            #union 
            #select g.gene_oid gene_oid, g.gene_display_name
            #from gene g
            #where ( $containsClause )
            #$tclause
            #$rclause
            #$imgClause
        push( @bindList, "$gene_display_name" );
        push( @bindList, @$bindList_txs_ref );
        push( @bindList, @$bindList_ur_ref );
        #push( @bindList, @bindList_contains ) if ( scalar(@bindList_contains) > 0 );
        #push( @bindList, @$bindList_txs_ref );
        #push( @bindList, @$bindList_ur_ref );
    }

    return ( $sql, @bindList );
}
############################################################################
# fetchGeneOidsByGeneDisplayNameSdb - Sdb version
#   --es 07/09/13
############################################################################
sub fetchGeneOidsByGeneDisplayNameSdb {
    my ( $dbh, $contact_oid, $userPref, $gene_display_name, $genomeFilterSelections_aref, $data_type, $useAlt ) = @_;

    #$gene_display_name = lc($gene_display_name);
    my $product_oid = param("product_oid");

    #print "FindFunctions::printGeneDisplayNameGenes() product_oid=$product_oid<br/>\n";

    my $sdbFile = "$search_dir/gene_product_genes.sdb";

    #if( !-e $sdbFile || $include_metagenomes ) {
    #    return fetchGeneOidsByGeneDisplayName( $dbh, $contact_oid, $userPref,
    #	   $gene_display_name, $genomeFilterSelections_aref, $useAlt );
    #}
    my %validTaxons = getAllTaxonsHashedSelections($dbh);
    my $sdbh        = WebUtil::sdbLogin($sdbFile);

    #my $sql = "select genes from product where gene_display_name = ?";
    #my $cur = execSql( $sdbh, $sql, $verbose, $gene_display_name );
    my $sql     = "select genes from product where product_oid = ?";
    my $cur     = execSql( $sdbh, $sql, $verbose, $product_oid );
    my $genes   = $cur->fetchrow();
    my @genes_a = split( /\s+/, $genes );
    my @iso_genes;
    my $contact_oid = getContactOid();
    for my $g (@genes_a) {
        my ( $taxon_oid, $gene_oid, $locus_tag, $enzyme, $modified_by ) = split( /\|/, $g );
        next if !$validTaxons{$taxon_oid};

        # Handle MyIMG gene data also.
        next
          if $modified_by > 0
          && $contact_oid > 0
          && $modified_by != $contact_oid;
        push( @iso_genes, $gene_oid );
    }
    $cur->finish();
    $sdbh->disconnect();

    my @meta_genes;
    return ( \@iso_genes, \@meta_genes );

    ## This is crap. The product_oid's are not compatible.
    my %allMerfsTaxons;
    my $sql = qq{
       select taxon_oid
       from taxon
       where in_file = 'Yes'
       and obsolete_flag = 'No'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $allMerfsTaxons{$taxon_oid} = 1;
    }
    $cur->finish();
    my $taxonSelections_aref = getSessionParam("genomeFilterSelections");
    my %merFsTaxons;
    for my $taxon_oid (@$taxonSelections_aref) {
        next if !$allMerfsTaxons{$taxon_oid};
        $merFsTaxons{$taxon_oid} = 1;
    }
    my @merfs_taxon_oids = sort( keys(%merFsTaxons) );
    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $merfs_taxon_oid (@merfs_taxon_oids) {
        for my $type (@type_list) {
            my $txd     = "$mer_data_dir/$type/$merfs_taxon_oid";
            my $sdbFile = "$txd/gene_product_genes.sdb";
            next if !-e $sdbFile;
            my $sdbh    = WebUtil::sdbLogin($sdbFile);
            my $sql     = "select genes from product where product_oid = ?";
            my $cur     = execSql( $sdbh, $sql, $verbose, $product_oid );
            my $genes   = $cur->fetchrow();
            my @genes_a = split( /\s+/, $genes );

            for my $g (@genes_a) {
                push( @meta_genes, $g );
            }
            $cur->finish();
            $sdbh->disconnect();
        }
    }

    return ( \@iso_genes, \@meta_genes );
}

############################################################################
# printGeneDisplayNameGenomes - Show genomes for one gene_display_name.
############################################################################
sub printGeneDisplayNameGenomes {
    my $searchFilter      = param("searchFilter");
    my $gene_display_name = param("gene_display_name");
    #if CGI::unescape used, ferredoxin-nadp(+) reductase => ferredoxin-nadp() reductase
    #$gene_display_name = CGI::unescape($gene_display_name);
    $gene_display_name = lc($gene_display_name);

    my $domainfilter = param("domainfilter");
    my $seq_status   = param("seqstatus");
    my $taxonChoice  = param("taxonChoice");
    my $data_type    = param("data_type");
    my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my @genomeFilterSelections;
    if ( $genomeFilterSelections_ref ne ""
         && scalar(@$genomeFilterSelections_ref) > 0 )
    {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }
    #print "printGeneDisplayNameGenomes() genomeFilterSelections=@genomeFilterSelections<br/>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my @dbTaxons   = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) 
                = MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
            @dbTaxons   = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }
    } elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
    } else {
        if ($include_metagenomes) {
            my ( $taxonClause, @bindList_txs ) 
                = OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "t.taxon_oid", \@genomeFilterSelections );
            my %taxon_in_file = MerFsUtil::getTaxonsInFile
		( $dbh, $taxonClause, \@bindList_txs );
            @metaTaxons = keys %taxon_in_file;
        }
    }

    my @taxon_oids;
    if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
        # no need to fetch things from database
    } else {
        my ( $taxonClause, @bindList_txs );
	my $bydomain = 0;
        if ( scalar(@dbTaxons) > 0 ) {
            ( $taxonClause, @bindList_txs ) = 
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon", \@dbTaxons );
	} elsif ($domainfilter ne "" || $domainfilter eq "isolates") {
	    $bydomain = $domainfilter;
        } else {
            ( $taxonClause, @bindList_txs ) =
		OracleUtil::getTaxonSelectionClauseBind
		( $dbh, "g.taxon", \@genomeFilterSelections );
        }

        my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my ( $sql, @bindList ) =
	    getGeneDisplayNameGenomeListSql
	    ( $gene_display_name, $taxonClause, $rclause, $imgClause,
	      \@bindList_txs, \@bindList_ur, $bydomain, $seq_status );

        #print "printGeneDisplayNameGenomes() sql: $sql<br/>\n";
        #print "printGeneDisplayNameGenomes() bindList: @bindList<br/>\n";

        # --es 07/09/13
        my $sdbFile     = "$search_dir/gene_product_genes.sdb";
        my $product_oid = param("product_oid");
        webLog("sdbFile='$sdbFile'\n");
        webLog("product_oid='$product_oid'\n");
        if ( -e $sdbFile && $product_oid > 0 ) {
            @taxon_oids = fetchGenomeListSdb( $dbh, $sdbFile, $product_oid );
        } else {
            @taxon_oids = HtmlUtil::fetchGenomeList
		( $dbh, $sql, $verbose, @bindList );
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $taxonClause =~ /gtt_num_id/i );
    }

    if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
        my @type_list = MetaUtil::getDataTypeList( $data_type );
        my $tag       = "gene_product";

        printStartWorkingDiv();

        foreach my $toid (@metaTaxons) {
            $toid = sanitizeInt($toid);

            for my $data_type (@type_list) {
                #print "Check metagenome $toid $data_type ...<br/>\n";
                my %gene_name_h;
                MetaUtil::doGeneProdNameSearch
		    ( 1, 1, $toid, $data_type, $tag, $gene_display_name, \%gene_name_h );

                if ( scalar( keys %gene_name_h ) > 0 ) {
                    push( @taxon_oids, $toid );
                    next;
                }
            }
        }
        printEndWorkingDiv();
    }

    #print "printGeneDisplayNameGenomes() taxon_oids: @taxon_oids<br/>\n";

    my $name  = $function2Name{$searchFilter};
    my $title = "Genomes In $name";
    my $subtitle = "$name: $gene_display_name";
    if ( $include_metagenomes && scalar(@metaTaxons) > 0 ) {
        $subtitle .= "<br/>\nMER-FS Metagenome: " . $data_type;
    }
    HtmlUtil::printGenomeListHtmlTable($title, $subtitle, $dbh, \@taxon_oids);
}

sub getGeneDisplayNameGenomeListSql {
    my ( $gene_display_name, $tclause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $dt_gene_name_exists = 1;    # 1; # Force table exists

    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
	$addfrom = ", taxon tx ";
	$dmClause = " and tx.domain = '$bydomain' ";
	$dmClause = " and tx.genome_type = 'isolate' "
	    if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
	$tclause = " and tx.taxon_oid = g.taxon ";
    }

    my $sql_orig = qq{
        select distinct g.taxon
        from gene g $addfrom
        where lower(g.gene_display_name) = ? 
        and g.obsolete_flag = ? 
        $dmClause
        $tclause
        $rclause
        $imgClause
    };
    my @bindList_orig = ();
    push( @bindList_orig, "$gene_display_name" );
    push( @bindList_orig, 'No' );
    push( @bindList_orig, @$bindList_txs_ref );
    push( @bindList_orig, @$bindList_ur_ref );

    my $sql_cache = qq{
        select distinct g.taxon
        from gene g $addfrom
        where lower(g.gene_display_name) = ? 
        $dmClause
        $tclause
        $rclause
        $imgClause
    };
    my @bindList_cache = ();
    push( @bindList_cache, "$gene_display_name" );
    push( @bindList_cache, @$bindList_txs_ref );
    push( @bindList_cache, @$bindList_ur_ref );

    my $sql;
    my @bindList = ();
    if ($dt_gene_name_exists) {
        $sql      = $sql_cache;
        @bindList = @bindList_cache;
    } else {
        $sql      = $sql_orig;
        @bindList = @bindList_orig;
    }

    return ( $sql, @bindList );
}

############################################################################
# fetchGenomeListSdb - Fetch genome list from sdb file.
#    --es 07/09/13
############################################################################
sub fetchGenomeListSdb {
    my ( $dbh, $sdbFile, $product_oid ) = @_;

    my $sdbh        = WebUtil::sdbLogin($sdbFile);
    my $sql         = "select genes from product where product_oid = ?";
    my $cur         = execSql( $sdbh, $sql, $verbose, $product_oid );
    my $genes       = $cur->fetchrow();
    my @genes_a     = split( /\s+/, $genes );
    my %validTaxons = getAllTaxonsHashedSelections($dbh);
    my %taxons;
    for my $g (@genes_a) {
        my ( $taxon_oid, undef ) = split( /\|/, $g );
        next if !$validTaxons{$taxon_oid};
        $taxons{$taxon_oid} = 1;
    }
    $cur->finish();
    $sdbh->disconnect();
    return sort( keys(%taxons) );
}

############################################################################
# printProdNameProfile
############################################################################
sub printProdNameProfile {
    my ( $self, $type, $procId, $sortIdx, $minPercIdent, $maxEvalue ) = @_;

    my $baseUrl = $self->{baseUrl};

    $type     = param("type")    if $type    eq "";
    $procId   = param("procId")  if $procId  eq "";
    $sortIdx  = param("sortIdx") if $sortIdx eq "";
    my $znorm = param("znorm");

    print "<h1>Gene Product Name Profile</h1>\n";
    require PhyloProfile;

    if ( $procId ne "" ) {
        my $pp = new PhyloProfile( $type, $procId );
        $pp->printProfile();

        # require FuncCartStor;
        # FuncCartStor::printAllGenesLink( "PhyloProfile", $type, $procId );
        print "<br/>\n";
        print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
        return;
    }

    my @prodNames = param('gene_display_name');
    if (    scalar(@prodNames) == 0
         || scalar(@prodNames) > $max_prod_name )
    {
        webError("Please select 1 to $max_prod_name product names.");
    }

    #my @taxon_oids = 
    #OracleUtil::processTaxonSelectionParam('genomeFilterSelections');

    # get the genomes in the selected box:
    my @taxon_oids = param("selectedGenome1");

    my @bin_oids    = ();
    my $nSelections = scalar(@taxon_oids) + scalar(@bin_oids);
    if ( $nSelections == 0 || $nSelections > $max_genome_selection ) {
        webError("Please select 1 to $max_genome_selection genome(s).");
    }

    my $tclause = "";
    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $tclause1  = "";
    my ( $rclause1, @bindList_ur1 ) = urClauseBind("g1.taxon");
    my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');

    if ( scalar(@taxon_oids) > 0 ) {
        my $taxon_filter_oid_str = join( ',', @taxon_oids );
        $tclause  = "and g.taxon in( $taxon_filter_oid_str )";
        $tclause1 = "and g1.taxon in( $taxon_filter_oid_str )";
    }

    printStatusLine( "Loading ...", 1 );

    my $cond  = "";
    my $count = 0;
    foreach my $n1 (@prodNames) {
    	my $n = CGI::unescape($n1);
    	$n = lc($n);
        $n =~ s/'/''/g;    # replace ' with ''
                           # $n =~ tr/A-Z/a-z/;    # change to lower case

        if ( length($cond) == 0 ) {
            $cond = " ('" . $n . "'";
        } else {
            $cond .= ", '" . $n . "'";
        }

        $count++;
        if ( $count >= $max_prod_name ) {
            last;
        }
    }
    $cond .= ") " if $cond ne "";

    my $dbh = dbLogin();

    # get user product name preference
    my $contact_oid = getContactOid();

    #my $userPref = WebUtil::getMyIMGPref( $dbh, 'MYIMG_PROD_NAME' );
    #if ( blankStr($userPref) ) {
    #    # default is yes
    #    $userPref = 'Yes';
    #}

    #my $sql = qq{
    #	 select lower(new.gene_display_name), new.taxon, 
    #           count( distinct new.gene_oid )
    #     from (
    #	     select g2.product_name gene_display_name,
    #	     g1.taxon taxon, g2.gene_oid gene_oid
    #	     from gene_myimg_functions g2, gene g1 
    #	     where g2.gene_oid = g1.gene_oid 	
    #	     and lower(g2.product_name) in $cond
    #         and g2.modified_by = ? 
    #	     $tclause1
    #	     $rclause1
    #	     $imgClause1
    #	     union 
    #	     select g.gene_display_name gene_display_name,
    #	     g.taxon taxon, g.gene_oid gene_oid 
    #	     from gene g
    #	     where lower(g.gene_display_name) in $cond
    #	     $tclause
    #	     $rclause
    #	     $imgClause
    #     ) new
    #     group by lower(new.gene_display_name), new.taxon
    #     order by lower(new.gene_display_name), new.taxon
    #};
    my $sql = qq{
        WITH
        with_new AS
        (
             select g2.product_name gene_display_name,
             g1.taxon taxon, g2.gene_oid gene_oid
             from gene_myimg_functions g2, gene g1 
             where g2.gene_oid = g1.gene_oid    
             and lower(g2.product_name) in $cond
             and g2.modified_by = ? 
             $tclause1
             $rclause1
             $imgClause1
             union 
             select g.gene_display_name gene_display_name,
             g.taxon taxon, g.gene_oid gene_oid 
             from gene g
             where lower(g.gene_display_name) in $cond
             $tclause
             $rclause
             $imgClause
        )
        select lower(new.gene_display_name), new.taxon, 
            count( distinct new.gene_oid )
        from with_new new
        group by lower(new.gene_display_name), new.taxon
        order by lower(new.gene_display_name), new.taxon
    };

    my @bindList = ();
    push( @bindList, "$contact_oid" );
    push( @bindList, @bindList_ur1 );
    push( @bindList, @bindList_ur );
    #print "PrintProdNameProfile() sql: $sql<br/>\n";
    #print "PrintProdNameProfile() bindList: @bindList<br/>\n";

    #    my $sql = qq{
    #        select g.gene_display_name, g.taxon, count(*)
    #	from gene g
    #	$cond
    #	$rclause
    #	$tclause
    #	group by g.gene_display_name, g.taxon
    #	order by lower( g.gene_display_name ), g.taxon
    #    };

    my %funcId2Name;
    my @products;
    foreach my $n (@prodNames) {
    	$n = CGI::unescape($n);
    	push (@products, $n);
        $funcId2Name{$n} = $n;
    }

    #    for ( ; ; ) {
    #        my ( $func_id, $func_name ) = $cur->fetchrow();
    #        last if !$func_id;
    #        $funcId2Name{$func_id} = $func_name;
    #    }
    #    $cur->finish();

    ##
    #  z-norm set up
    #
    my %taxonOid2GeneCount;
    my %binOid2GeneCount;
    my %clusterScaleMeanStdDev;

    #    if ($znorm) {
    #        WebUtil::arrayRef2HashRef( \@taxon_oids, \%taxonOid2GeneCount,     0 );
    #        WebUtil::arrayRef2HashRef( \@bin_oids,   \%binOid2GeneCount,       0 );
    #        WebUtil::arrayRef2HashRef( \@func_ids,   \%clusterScaleMeanStdDev, "" );
    #        getTaxonGeneCount( $dbh, \%taxonOid2GeneCount );
    #        getBinGeneCount( $dbh, \%binOid2GeneCount );
    #        getClusterScaleMeanStdDev( $dbh,      "dt_func_abundance",
    #                                   "func_id", \%clusterScaleMeanStdDev );
    #    }

    ## Taxon selection
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my $cnt0 = 0;
    for ( ; ; ) {
        my ( $id, $taxon_oid, $gene_count ) = $cur->fetchrow();
        last if !$id;
        last if !$taxon_oid;

        my $name = $id;
        my $r    = "$id\t";
        $r .= "$name\t";
        $r .= "$taxon_oid\t";
        $r .= "\t";              # null bin_oid
        $r .= "$gene_count\t";
        push( @recs, $r );

        $cnt0++;
        if ( $cnt0 > 100 ) {
            last;
        }
    }
    $cur->finish();

    #$dbh->disconnect();

    # sql template
    #    my $taxon_cell_sql_template = qq{
    #        select distinct g.gene_oid
    #        from gene g
    #	where g.gene_display_name in $cond
    #        and g.taxon = __taxon_oid__
    #        order by g.gene_oid
    #    };

    #temporarily use rclause without binding
    #should be changed when applying binding to PhyloProfile
    $rclause    = urClause("g.taxon");
    $imgClause  = WebUtil::imgClauseNoTaxon('g.taxon');
    $rclause1   = urClause("g1.taxon");
    $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');
    my $taxon_cell_sql_template = qq{
	    select g2.gene_oid gene_oid
	    from gene_myimg_functions g2, gene g1 
	    where g2.gene_oid = g1.gene_oid 	
	    and lower(g2.product_name) = '__id__'
	    $tclause1
	    $rclause1
	    $imgClause1
	    and g1.taxon = __taxon_oid__
	    and g2.modified_by = $contact_oid
	    union 
	    select g.gene_oid gene_oid
	    from gene g
	    where lower(g.gene_display_name) = '__id__'
	    $tclause
	    $rclause
	    $imgClause
	    and g.taxon = __taxon_oid__
	    and g.gene_oid not in 
	    (select g4.gene_oid from gene_myimg_functions g4 
	     where modified_by = $contact_oid) 
	    order by gene_oid
	};

    my $bin_cell_sql_template = "";

    my $url         = "$main_cgi?section=PhyloProfile&page=phyloProfile";
    my @colorMap_gc = ( "1:5:bisque", "5:100000:#FFFF66", );
    my @colorMap_zn = ( "0.01:1:bisque", "1:100000:#FFFF66", );
    my @colorMap    = @colorMap_gc;
    @colorMap = @colorMap_zn if $znorm;

    my $sortUrl = "$section_cgi&showFuncCartProfile_s";
    my $pp      =
      new PhyloProfile("func", $$, "Gene Product Name", "NONAME", $url, $sortUrl,
		       \@products, \%funcId2Name, 
		       \@taxon_oids, \@bin_oids, '', \@recs, \@colorMap, 
		       $taxon_cell_sql_template, $bin_cell_sql_template, 
		       $znorm);

    $pp->printProfile();

    # require FuncCartStor;
    # FuncCartStor::printAllGenesLink( "PhyloProfile", $type, $procId );

    #$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print "<br/>\n";
    print buttonUrl( $baseUrl, "Start Over Again", "medbutton" );
}

sub searchAllFunctions {
    my $searchTerm   = param("ffgSearchTerm");
    my $searchFilter = param("searchFilter");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;

    #my $searchTermLiteral = $searchTerm;
    #if ( $searchFilter eq "ec_ex" && $searchTerm =~ /^[1-9]+/ ) {
    #    $searchTerm = "EC:$searchTerm";
    #}
    #if ( $searchFilter eq "Pfam" && $searchTerm =~ /^PF[0-9]+$/ ) {
    #    my $x = $searchTerm;
    #    $x =~ s/PF//;
    #    $searchTerm = sprintf( "pfam%05d", $x );
    #    $searchTermLiteral = $searchTerm;
    #}
    #$searchTerm =~ s/'/''/g;

    my $seq_status             = param("seqstatus");
    my $domainfilter           = param("domainfilter");
    my $taxonChoice            = param("taxonChoice");
    my $data_type              = param("q_data_type");
    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");

    # allow searching by selected domain or by all isolates:
    my $selectionType = param("selectType");
    if ($selectionType eq "selDomain") {
        $seq_status = param("seqstatus0");
        $domainfilter = param("domainfilter0");
    } elsif ($selectionType eq "allIsolates") {
        $seq_status = param("seqstatus0");
        $domainfilter = "isolates";
    }

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");
    if ( scalar(@genomeFilterSelections) < 1 &&
	 $selectionType eq "selGenomes" ) {
        webError("Please select at least one genome.");
    }
    setSessionParam( "geneSearchTaxonFilter",  $geneSearchTaxonFilter );
    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    my $dbh = dbLogin();

    my @dbTaxons   = ();
    my @metaTaxons = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        if ($include_metagenomes) {
            my ( $dbTaxons_ref, $metaTaxons_ref ) 
                = MerFsUtil::findTaxonsInFile($dbh, @genomeFilterSelections);
            @dbTaxons = @$dbTaxons_ref;
            @metaTaxons = @$metaTaxons_ref;
        } else {
            @dbTaxons = @genomeFilterSelections;
        }
    } 

    my $title = $function2Name{$searchFilter};
    print "<h1>$title Search Results</h1>\n";
    printStatusLine( "Loading ...", 1 );

    print qq{
        <p>
        <u>Keyword</u>: $searchTerm
    };
    if ( scalar(@metaTaxons) > 0 ) {
        HtmlUtil::printMetaDataTypeSelection($data_type, 1);
    }
    print qq{
        </p> 
    };

    my $dbh = dbLogin();
    my ( $taxonClause, @bindList_txs ) =
	OracleUtil::getTaxonSelectionClauseBind
	( $dbh, "g.taxon", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my ( $taxonClause1, @bindList_txs1 ) =
	OracleUtil::getTaxonSelectionClauseBind
	( $dbh, "g.taxon_oid", \@genomeFilterSelections );
    my ( $rclause1, @bindList_ur1 ) = WebUtil::urClauseBind("g.taxon_oid");
    my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon_oid');

    my $datatypeClause1;
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        $datatypeClause1 = " and g.data_type = '$data_type' ";
    }              

    printStartWorkingDiv();

    #webLog "Searching Gene Product Name " . currDateTime() . "\n"
    #  if $verbose >= 1;
    #print "Searching Gene Product Name<br/>\n";
    #my ( $productHits, $productGeneCnt, $genomefile ) =
    #  getSearchAllGeneName( $dbh, $searchTermLc, $taxonClause, $rclause,
    #    $imgClause, \@bindList_txs, \@bindList_ur );

    #webLog "Searching Seed Product Name/Subsystem " . currDateTime() . "\n"
    #  if $verbose >= 1;
    #print "Searching Seed Product Name/Subsystem<br/>\n";
    #my ( $seedHits, $seedGeneCnt, $seedfile ) =
    #  getSearchAllSeedName( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );

    webLog "Searching SwissProt Product Name " . currDateTime() . "\n"
      if $verbose >= 1;
    print "Searching SwissProt Product Name<br/>\n";
    my ( $swissHits, $swissGeneCnt, $swissfile ) =
      getSearchAllSwissProtName( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );

    webLog "Searching GO " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching GO<br/>\n";
    my ( $goHits, $goGeneCnt, $gofile ) =
      getSearchAllGo( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );

    webLog "Searching COG " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching COG<br/>\n";
    my ( $cogHits, $cogGeneCnt, $cogfile ) =
      getSearchAllCog( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching KOG " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching KOG<br/>\n";
    my ( $kogHits, $kogGeneCnt, $kogfile ) =
      getSearchAllKog( $dbh, $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching Pfam " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching Pfam<br/>\n";
    my ( $pfamHits, $pfamGeneCnt, $pfamfile ) =
      getSearchAllPfam( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching TIGRfam " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching TIGRfam<br/>\n";
    my ( $tigrfamHits, $tigrfamGeneCnt, $tigrfamfile ) =
      getSearchAllTigrfam( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    if ($enable_interpro) {
    webLog "Searching InterPro " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching InterPro<br/>\n";
    my ( $interproHits, $interproGeneCnt, $interprofile ) =
      getSearchAllInterpro( $dbh, $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );
    }
    
    webLog "Searching Enzyme " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching Enzyme<br/>\n";
    my ( $enzymeHits, $enzymeGeneCnt, $enzymefile ) =
      getSearchAllEnzyme( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching Transporter Classification " . currDateTime() . "\n"
      if $verbose >= 1;
    print "Searching Transporter Classification<br/>\n";
    my ( $tcHits, $tcGeneCnt, $tcfile ) =
      getSearchAllTc( $dbh, $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching KEGG Pathway Enzymes " . currDateTime() . "\n"
      if $verbose >= 1;
    print "Searching KEGG Pathway Enzymes<br/>\n";
    my ( $keggPathHits, $keggPathGeneCnt, $keggfile ) =
      getSearchAllKeggPath( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching KEGG Orthology ID " . currDateTime() . "\n"
      if $verbose >= 1;
    print "Searching KEGG Orthology ID<br/>\n";
    my ( $koidHits, $koidGeneCnt, $koidfile ) =
      getSearchAllKoId( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching KEGG Orthology Name " . currDateTime() . "\n"
      if $verbose >= 1;
    print "Searching KEGG Orthology Name<br/>\n";
    my ( $konameHits, $konameGeneCnt, $konamefile ) =
      getSearchAllKoName( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching KEGG Orthology Definition " . currDateTime() . "\n"
      if $verbose >= 1;
    print "Searching KEGG Orthology Definition<br/>\n";
    my ( $kodefnHits, $kodefnGeneCnt, $kodefnfile ) =
      getSearchAllKoDefn( $dbh, $searchTermLc, $taxonClause1, $datatypeClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching MetaCyc " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching MetaCyc<br/>\n";
    my ( $metacycHits, $metacycGeneCnt, $metacycfile ) =
      getSearchAllMetaCyc( $dbh, $searchTermLc, $taxonClause1, $rclause1, $imgClause1, \@bindList_txs1, \@bindList_ur1 );

    webLog "Searching IMG Term and Synonyms " . currDateTime() . "\n"
      if $verbose >= 1;
    print "Searching IMG Term and Synonyms<br/>\n";
    my ( $imgTermHits, $imgtermfiles ) =
      getSearchAllImgTerm( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );

    webLog "Searching IMG Pathways " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching IMG Pathways<br/>\n";
    my ( $imgPathHits, $tmp, $imgpathfile ) =
      getSearchAllImgPathway( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );

    # tmp not used
    webLog "Searching IMG Parts List " . currDateTime() . "\n" if $verbose >= 1;
    print "Searching IMG Parts List<br/>\n";
    my ( $imgPartsHits, $tmp, $imgpartfile ) =
      getSearchAllImgParts( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur );

    webLog "Done searching all " . currDateTime() . "\n" if $verbose >= 1;
    printEndWorkingDiv();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxonClause =~ /gtt_num_id/i );

    #$dbh->disconnect();

    # js setup
    print qq{
        <script language="JavaScript" type="text/javascript">
        <!--
        function mySubmit (value, filename) {
            document.mainForm.searchFilter.value = value;
            document.mainForm.file.value = filename;
            document.mainForm.submit();
        }
        -->
        </script>    
    };

    printMainForm();
    print hiddenVar( "section", $section );
    print "\n";
    print hiddenVar( "page", "ffgFindFunctions" );
    print "\n";
    print hiddenVar( "file", "" );
    print "\n";
    print hiddenVar( "ffgSearchTerm", $searchTerm );
    print "\n";
    print hiddenVar( "searchFilter", $searchFilter );
    print "\n";
    print hiddenVar( "geneSearchTaxonFilter", $geneSearchTaxonFilter );
    print "\n";
    print hiddenVar( "seqstatus", $seq_status );
    print "\n";
    print hiddenVar( "domainfilter", $domainfilter );
    print "\n";
    print hiddenVar( "taxonChoice", $taxonChoice );
    print "\n";
    print hiddenVar( "data_type", $data_type );
    print "\n";

    foreach my $x (@genomeFilterSelections) {
        print hiddenVar( "selectedGenome1", $x );
        print "\n";
    }

    #foreach my $x (@genomeFilterSelections) {
    #    print hiddenVar( "genomeFilterSelections", $x );
    #    print "\n";
    #}

    my $it = new InnerTable( 1, "searchall$$", "searchall", 1 );
    $it->addColSpec( "Function", "asc",  "left" );
    $it->addColSpec( "Hits",     "desc", "right" );

    #$it->addColSpec( "Gene Count", "desc", "right" );

    #my $url = qq{
    #    <a href="javascript:mySubmit('geneProduct', '$genomefile')"> $productHits </a>
    #};
    #printAllRow( $it, "Gene Product Name", $productHits, $productGeneCnt, $url );

    #my $url = qq{
    #    <a href="javascript:mySubmit('seedProduct', '$seedfile')"> $seedHits </a>
    #};
    #printAllRow( $it, "Seed Product Name/Subsystem", $seedHits, $seedGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('swissProduct', '$swissfile')"> $swissHits </a>        
    };
    printAllRow( $it, "SwissProt Product Name", $swissHits, $swissGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('go','$gofile')"> $goHits </a>        
    };
    printAllRow( $it, "GO", $goHits, $goGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('cog', '$cogfile')"> $cogHits </a>        
    };
    printAllRow( $it, "COG", $cogHits, $cogGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('kog', '$kogfile')"> $kogHits </a>        
    };
    printAllRow( $it, "KOG", $cogHits, $cogGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('pfam','$pfamfile')"> $pfamHits </a>        
    };
    printAllRow( $it, "Pfam", $pfamHits, $pfamGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('tigrfam','$tigrfamfile')"> $tigrfamHits </a>        
    };
    printAllRow( $it, "TIGRfam", $tigrfamHits, $tigrfamGeneCnt, $url );

    #my $url = qq{
    #    <a href="javascript:mySubmit('ipr','$interprofile')"> $interproHits </a>        
    #};
    #printAllRow( $it, "InterPro", $interproHits, $interproGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('ec','$enzymefile')"> $enzymeHits </a>        
    };
    printAllRow( $it, "Enzyme", $enzymeHits, $enzymeGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('tc','$tcfile')"> $tcHits </a>        
    };
    printAllRow( $it, "Transporter Classification", $tcHits, $tcGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('keggEnzymes','$keggfile')"> $keggPathHits </a>
    };
    printAllRow( $it, "KEGG Pathway Enzymes", $keggPathHits, $keggPathGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('koid','$koidfile')"> $koidHits </a>
    };
    printAllRow( $it, "KEGG Orthology ID", $koidHits, $koidGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('koname','$konamefile')"> $konameHits </a>        
    };
    printAllRow( $it, "KEGG Orthology Name", $konameHits, $konameGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('kodefn','$kodefnfile')"> $kodefnHits </a>
    };
    printAllRow( $it, "KEGG Orthology Definition", $kodefnHits, $kodefnGeneCnt, $url );

    my $url = qq{
        <a href="javascript:mySubmit('metacyc','$metacycfile')"> $metacycHits </a>        
    };
    printAllRow( $it, "MetaCyc", $metacycHits, $metacycGeneCnt, $url );

    # img_term_iex
    my $url = qq{
        <a href="javascript:mySubmit('img_term_iex', '$imgtermfiles')"> $imgTermHits </a>
    };
    printAllRow( $it, "IMG Term and Synonyms", $imgTermHits, -1, $url );

    # img_pway
    my $url = qq{
        <a href="javascript:mySubmit('img_pway_iex', '$imgpathfile')"> $imgPathHits </a>        
    };
    printAllRow( $it, "IMG Pathways", $imgPathHits, -1, $url );

    # img part list
    my $url = qq{
        <a href="javascript:mySubmit('img_plist_iex', '$imgpartfile')"> $imgPartsHits </a>        
    };
    printAllRow( $it, "IMG Parts List", $imgPartsHits, -1, $url );

    $it->printOuterTable(1);

    print end_form();

    printStatusLine( "Loaded.", 2 );
}

# $url1 - hit count url
# $url2 - gene count url
sub printAllRow {
    my ( $it, $rowname, $hits, $genecount, $url1 ) = @_;
    my $sd = $it->getSdDelim();    # sort delimiter
    my $r;
    $r .= $rowname . $sd . $rowname . "\t";

    if ( $url1 ne "" && $hits != 0 ) {

        #my $url = alink( $url1, $hits );
        $r .= "$hits" . $sd . "$url1" . "\t";
    } else {
        $r .= "$hits" . $sd . "$hits" . "\t";
    }

    #    if($genecount > -1 ) {
    #
    #        $r .= $genecount . $sd . $genecount . "\t";
    #    } else {
    #        $r .= $genecount . $sd . " &nbsp; " . "\t";
    #    }
    $it->addRow($r);
}

# fixed for public only
# see printGeneDisplayNames
sub getSearchAllGeneName {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    # get user product name preference
    my $contact_oid = getContactOid();
    my $userPref = WebUtil::getMyIMGPref( $dbh, 'MYIMG_PROD_NAME' );
    if ( blankStr($userPref) ) {
        # default is yes
        $userPref = 'Yes';
    }

    #my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    my ( $taxonClause1, @bindList_txs1 ) =
      OracleUtil::getTaxonSelectionClauseBind( $dbh, "g1.taxon", \@genomeFilterSelections );
    my ( $rclause1, @bindList_ur1 ) = urClauseBind("g1.taxon");
    my $imgClause1 = WebUtil::imgClauseNoTaxon('g1.taxon');

    my $cacheFile = "genome$$";
    my $cachePath = "$cgi_tmp_dir/$cacheFile";

    #webLog("==== $cachePath\n");
    my $res = newWriteFileHandle( $cachePath, "runJob" );

    my ( $sql, @bindList ) = getGeneDisplayNameSql(
        $searchTermLc, $userPref,         $contact_oid,     $taxonClause,  $rclause,
        $imgClause,    $bindList_txs_ref, $bindList_ur_ref, $taxonClause1, $rclause1,
        $imgClause1,   \@bindList_txs1,   \@bindList_ur1
    );

    #print "getSearchAllGeneName() sql: @bindList<br/>";
    #print "getSearchAllGeneName() bindList: @bindList<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my $rowcount  = 0;
    my $genecount = 0;
    for ( ; ; ) {
        my ( $name, $gcnt, $tcnt ) = $cur->fetchrow();
        last if !$name;
        print $res "$name\t";
        print $res "$gcnt\t";
        print $res "$tcnt\n";
        $rowcount++;
        $genecount = $genecount + $gcnt;
    }
    $cur->finish();
    close $res;

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllSeedName {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getSeedSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "seed$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllSwissProtName {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getSwissProtSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "swissprot$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllGo {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getGoSql( $searchTermLc, $taxonClause, $imgClause, $rclause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "go$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllCog {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my ( $sql,               @bindList );

    if ($include_metagenomes) {
        ( $sql, @bindList ) =
          getCogSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
        ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href ) =
          searchAllSqlExec_merfs( $dbh, $sql, \@bindList );
    }

    ( $sql, @bindList ) =
      getCogSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "cog$$";
    my ( $rowcount, $genecount ) =
      searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile, $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllKog {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getKogSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "kog$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllPfam {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my ( $sql,               @bindList );

    if ($include_metagenomes) {
        ( $sql, @bindList ) =
          getPfamSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
        ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href ) =
          searchAllSqlExec_merfs( $dbh, $sql, \@bindList );

        #print "searchAllSqlExec_merfs() merfs added: " . (keys %$merfs_genecnt_href) . "<br/>";
    }

    ( $sql, @bindList ) =
      getPfamSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "getSearchAllPfam \$sql: $sql<br/>";
    #print "getSearchAllPfam \@bindList: @bindList<br/>";

    my $cacheFile = "pfam$$";
    my ( $rowcount, $genecount ) =
      searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile, $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllTigrfam {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my ( $sql,               @bindList );

    if ($include_metagenomes) {
        ( $sql, @bindList ) =
          getTigrfamSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
        ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href ) =
          searchAllSqlExec_merfs( $dbh, $sql, \@bindList );
    }

    ( $sql, @bindList ) =
      getTigrfamSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "getSearchAllTigrfam \$sql: $sql<br/>";
    #print "getSearchAllTigrfam \@bindList: @bindList<br/>";

    my $cacheFile = "tigrfam$$";
    my ( $rowcount, $genecount ) =
      searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile, $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllInterpro {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getInterproSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "getSearchAllInterpro \$sql: $sql<br/>";
    #print "getSearchAllInterpro \@bindList: @bindList<br/>";

    my $cacheFile = "interpro$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllEnzyme {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my ( $sql,               @bindList );

    if ($include_metagenomes) {
        ( $sql, @bindList ) =
          getEnzymeSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
        ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href ) =
          searchAllSqlExec_merfs( $dbh, $sql, \@bindList );
    }

    ( $sql, @bindList ) =
      getEnzymeSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "getSearchAllEnzyme \$sql: $sql<br/>";
    #print "getSearchAllEnzyme \@bindList: @bindList<br/>";

    my $cacheFile = "enyzme$$";
    my ( $rowcount, $genecount ) =
      searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile, $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getEnzymeSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, 
	 $bindList_txs_ref, $bindList_ur_ref, $bydomain, $seq_status ) = @_;

    my $searchTermUc = $searchTermLc;
    $searchTermUc =~ tr/a-z/A-Z/;

    my $prefixedIdTerm;
    if ( $searchTermLc !~ /^EC:/i ) {
        $prefixedIdTerm = 'EC:' . $searchTermUc;
    } else {
        $prefixedIdTerm = $searchTermUc;
    }

    my ($idWhereClause) = OracleUtil::addIdWhereClause
	( 'EC:', '', $searchTermUc );

    my ( $idLikeClause, @bindList_like ) = OracleUtil::addIdLikeWhereClause
	( 'EC:', '', $searchTermUc, 'ez.ec_number' );

    #please do not remove below blocked query
    #my $sql = qq{
    #    WITH
    #    with_enzyme AS
    #    (
    #        select distinct ez.ec_number, ez.enzyme_name
    #        from enzyme ez
    #        where (
    #            ez.ec_number in ( $idWhereClause ) or
    #            $idLikeClause or
    #            ez.ec_number = ? or
    #            ez.ec_number like ? or
    #            contains(ez.enzyme_name, ?) > 0
    #        )
    #    )
    #    select we.ec_number, we.enzyme_name, 
    #           count(distinct g.gene_oid), count(distinct g.taxon)
    #    from gene_ko_enzymes g, with_enzyme we
    #    where g.enzymes = we.ec_number
    #    $taxonClause
    #    $rclause
    #    $imgClause
    #    group by we.ec_number, we.enzyme_name
    #};
        
    #contains not working on contains(ez.enzyme_name, '%EC:1.-, EC:1.1.1.100%') > 0
    #        contains(ez.enzyme_name, ?) > 0
    #have to use lower(ez.enzyme_name) like ?
    my $addfrom = "";
    my $dmClause = "";
    $bydomain = 0 if $bydomain eq "";
    $seq_status = "" if $seq_status eq "both";

    if ($bydomain) {
        $addfrom = ", taxon tx ";
        $dmClause = " and tx.domain = '$bydomain' ";
        $dmClause = " and tx.genome_type = 'isolate' "
            if $bydomain eq "isolates";
        $dmClause .= " and tx.seq_status = '$seq_status'" if $seq_status ne "";
        $taxonClause = " and tx.taxon_oid = g.taxon_oid ";
    }

    my $sql = qq{
        select ez.ec_number, ez.enzyme_name,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from enzyme ez, mv_taxon_ec_stat g $addfrom
        where (
            ez.ec_number in ( $idWhereClause ) or
            $idLikeClause or
            ez.ec_number = ? or
            ez.ec_number like ? or
            lower(ez.enzyme_name) like ? 
        )
        and ez.ec_number = g.enzyme
        $dmClause
        $taxonClause
        $rclause
        $imgClause
        group by ez.ec_number, ez.enzyme_name
    };

    my @bindList_sql = ();
    push( @bindList_sql, @bindList_like, 
	  "$prefixedIdTerm", "%$searchTermUc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, 
		     $bindList_txs_ref, $bindList_ur_ref );
    return ( $sql, @bindList );
}

sub getEnzymeSql_merfs {
    my ( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause,
	 $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $searchTermUc = $searchTermLc;
    $searchTermUc =~ tr/a-z/A-Z/;

    my $prefixedIdTerm;
    if ( $searchTermLc !~ /^EC:/i ) {
        $prefixedIdTerm = 'EC:' . $searchTermUc;
    } else {
        $prefixedIdTerm = $searchTermUc;
    }

    my ($idWhereClause) = OracleUtil::addIdWhereClause
	( 'EC:', '', $searchTermUc );

    my ( $idLikeClause, @bindList_like ) = OracleUtil::addIdLikeWhereClause
	( 'EC:', '', $searchTermUc, 'ez.ec_number' );

    #contains not working on contains(ez.enzyme_name, '%EC:1.-, EC:1.1.1.100%') > 0
    #        contains(ez.enzyme_name, ?) > 0
    #have to use lower(ez.enzyme_name) like ?
    my $sql = qq{
        select ez.ec_number, ez.enzyme_name,
               sum(g.gene_count), count(distinct g.taxon_oid)
        from enzyme ez, TAXON_EC_COUNT g
        where (
            ez.ec_number in ( $idWhereClause ) or
            $idLikeClause or
            ez.ec_number = ? or
            ez.ec_number like ? or
            lower(ez.enzyme_name) like ? 
        )
        and ez.ec_number = g.func_id
        $taxonClause
        $datatypeClause
        $rclause
        $imgClause
        group by ez.ec_number, ez.enzyme_name
    };

    my @bindList_sql = ();
    push( @bindList_sql, @bindList_like, "$prefixedIdTerm", "%$searchTermUc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getSearchAllTc {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getTcSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "getSearchAllTc() sql: $sql<br/>";
    #print "getSearchAllTc() bindList: @bindList<br/>";

    my $cacheFile = "tc$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllKeggPath {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, 
	 $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $cacheFile = "kegg$$";
    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $res       = newWriteFileHandle( $cachePath, "runJob" );

    my ( $sql, @bindList ) =
      getKeggPathEzSql( $searchTermLc, $taxonClause, $rclause, $imgClause,
			$bindList_txs_ref, $bindList_ur_ref );

    #print "getSearchAllKeggPath() sql: $sql<br/>";
    #print "getSearchAllKeggPath() bindList: @bindList<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my $genecount = 0;
    my %enzymes;
    for ( ; ; ) {
        my ( $cat, $path, $poid, $ec, $ecname, $gcnt, $tcnt ) = $cur->fetchrow();
        last if !$cat;

        print $res "$cat\t";
        print $res "$path\t";
        print $res "$poid\t";
        print $res "$ec\t";
        print $res "$ecname\t";
        print $res "$gcnt\t";
        print $res "$tcnt\n";
        $enzymes{$ec} = 1;
        $genecount = $genecount + $gcnt;
    }
    $cur->finish();

    close $res;

    my $count = keys(%enzymes);
    return ( $count, $genecount, $cacheFile );
}

sub getSearchAllKoId {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my ( $sql,               @bindList );

    if ($include_metagenomes) {
        ( $sql, @bindList ) =
          getKoIdSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
        ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href ) =
          searchAllKoSqlExec_merfs( $dbh, $sql, \@bindList );
    }

    ( $sql, @bindList ) =
      getKoIdSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "\$sql: $sql<br/>";
    #print "\@bindList: @bindList<br/>";

    my $cacheFile = "koid$$";
    my ( $rowcount, $genecount ) =
      searchAllKoSqlExec( $dbh, $sql, \@bindList, $cacheFile, $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href,
                          $merfs_genomecnt_href );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllKoName {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my ( $sql,               @bindList );

    if ($include_metagenomes) {
        ( $sql, @bindList ) =
          getKoNameSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
        ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href ) =
          searchAllKoSqlExec_merfs( $dbh, $sql, \@bindList );
    }

    ( $sql, @bindList ) =
      getKoNameSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "\$sql: $sql<br/>";
    #print "\@bindList: @bindList<br/>";

    my $cacheFile = "koname$$";
    my ( $rowcount, $genecount ) =
      searchAllKoSqlExec( $dbh, $sql, \@bindList, $cacheFile, $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href,
                          $merfs_genomecnt_href );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllKoDefn {
    my ( $dbh, $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my ( $sql,               @bindList );

    if ($include_metagenomes) {
        ( $sql, @bindList ) =
          getKoDefnSql_merfs( $searchTermLc, $taxonClause, $datatypeClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
        ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href ) =
          searchAllKoSqlExec_merfs( $dbh, $sql, \@bindList );
    }

    my ( $sql, @bindList ) =
      getKoDefnSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    #print "\$sql: $sql<br/>";
    #print "\@bindList: @bindList<br/>";

    my $cacheFile = "kodefn$$";
    my ( $rowcount, $genecount ) =
      searchAllKoSqlExec( $dbh, $sql, \@bindList, $cacheFile, $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href,
                          $merfs_genomecnt_href );

    return ( $rowcount, $genecount, $cacheFile );
}

sub searchAllKoSqlExec_merfs {
    my ( $dbh, $sql, $bindList_ref ) = @_;

    my ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );
    for ( ; ; ) {
        my ( $id, $name, $defn, $gcnt, $tcnt ) = $cur->fetchrow();
        last if ( !$id );

        $func_id2Name_href->{$id}    = $name;
        $func_id2Defn_href->{$id}    = $defn;
        $merfs_genecnt_href->{$id}   = $gcnt;
        $merfs_genomecnt_href->{$id} = $tcnt;

        #print "searchAllKoSqlExec_merfs() merfs added id: $id<br/>";
    }
    $cur->finish();

    return ( $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href, $merfs_genomecnt_href );
}

sub searchAllKoSqlExec {
    my ( $dbh, $sql, $bindList_ref, $cacheFile, $func_id2Name_href, $func_id2Defn_href, $merfs_genecnt_href,
         $merfs_genomecnt_href )
      = @_;

    my $cachePath = "$cgi_tmp_dir/$cacheFile";

    #webLog("==== $cachePath\n");
    my $res = newWriteFileHandle( $cachePath, "runJob" );

    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );

    my $rowcount  = 0;
    my $genecount = 0;
    for ( ; ; ) {
        my ( $id, $name, $defn, $gcnt, $tcnt ) = $cur->fetchrow();
        last if !$id;
        print $res "$id\t";
        print $res "$name\t";
        print $res "$defn\t";

        if ( $merfs_genecnt_href ne '' && $merfs_genomecnt_href ne '' ) {
            if ( exists $merfs_genecnt_href->{$id} ) {
                my $gcnt2 = $merfs_genecnt_href->{$id};
                my $tcnt2 = $merfs_genomecnt_href->{$id};
                $gcnt += $gcnt2;
                $tcnt += $tcnt2;
                delete $merfs_genecnt_href->{$id};
                delete $merfs_genomecnt_href->{$id};
            }
        }

        print $res "$gcnt\t";
        print $res "$tcnt\n";
        $rowcount++;
        $genecount = $genecount + $gcnt;
    }
    $cur->finish();

    if (    $func_id2Name_href ne ''
         && $func_id2Defn_href    ne ''
         && $merfs_genecnt_href   ne ''
         && $merfs_genomecnt_href ne '' )
    {
        foreach my $key ( keys %$merfs_genecnt_href ) {
            my $name  = $func_id2Name_href->{$key};
            my $defn  = $func_id2Defn_href->{$key};
            my $gcnt2 = $merfs_genecnt_href->{$key};
            my $tcnt2 = $merfs_genomecnt_href->{$key};
            print $res "$key\t";
            print $res "$name\t";
            print $res "$defn\t";
            print $res "$gcnt2\t";
            print $res "$tcnt2\n";
            $rowcount++;
            $genecount = $genecount + $gcnt2;
        }
    }

    close $res;

    return ( $rowcount, $genecount );
}

sub getSearchAllMetaCyc {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getMetaCycSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "metacyc$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllImgTerm {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $tmpTableFlag = 0;

    #no need to use temp table now
    #$tmpTableFlag =
    #  prepareTmpTable( $dbh, $taxonClause, $rclause, $imgClause,
    #    $bindList_txs_ref, $bindList_ur_ref )
    #  if ( !$tmpTableFlag );

    print "&nbsp;&nbsp; Searching IMG Terms<br/>\n";
    my ( $sql, @bindList ) =
      determineImgTermSql( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref,
                           $tmpTableFlag );

    my $cacheFile_term = "imgterm$$";
    my ( $termCnt, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile_term );

    print "&nbsp;&nbsp; Searching Synonyms<br/>\n";
    my ( $sql, @bindList ) =
      determineImgTermSynonymsSql( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref,
                                   $bindList_ur_ref, $tmpTableFlag );

    my $cacheFile_synonyms = "imgsynonyms$$";
    my ( $synonymsCnt, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile_synonyms );

    my $cacheFile;
    $cacheFile = $cacheFile_term . "|||" . $cacheFile_synonyms;
    return ( $termCnt + $synonymsCnt, $cacheFile );
}

sub getSearchAllImgPathway {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getImgPathwaySql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "imgpath$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub getSearchAllImgParts {
    my ( $dbh, $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my ( $sql, @bindList ) =
      getImgPartsListSql( $searchTermLc, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );

    my $cacheFile = "imgpart$$";
    my ( $rowcount, $genecount ) = searchAllSqlExec( $dbh, $sql, \@bindList, $cacheFile );

    return ( $rowcount, $genecount, $cacheFile );
}

sub searchAllSqlExec_merfs {
    my ( $dbh, $sql, $bindList_ref ) = @_;

    #print "searchAllSqlExec_merfs() merfs sql: $sql, bindList: @$bindList_ref<br/>\n";
    my ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );
    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );
    for ( ; ; ) {
        my ( $id, $name, $gcnt, $tcnt ) = $cur->fetchrow();
        last if ( !$id );

        $func_id2Name_href->{$id}    = $name;
        $merfs_genecnt_href->{$id}   = $gcnt;
        $merfs_genomecnt_href->{$id} = $tcnt;
        #print "searchAllSqlExec_merfs() merfs added id=$id name=$name gcnt=$gcnt tcnt=$tcnt<br/>\n";
    }
    $cur->finish();

    return ( $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href );
}

sub searchAllSqlExec {
    my ( $dbh, $sql, $bindList_ref, $cacheFile, $func_id2Name_href, $merfs_genecnt_href, $merfs_genomecnt_href )
      = @_;

    #print "searchAllSqlExec() merfs_genecnt_href:<br/>\n";
    #print Dumper($merfs_genecnt_href);
    #print "<br/>\n";
    #print "searchAllSqlExec() merfs_genomecnt_href:<br/>\n";
    #print Dumper($merfs_genomecnt_href);
    #print "<br/>\n";

    my $cachePath = "$cgi_tmp_dir/$cacheFile";

    #webLog("==== $cachePath\n");
    my $res = newWriteFileHandle( $cachePath, "runJob" );

    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );

    my $rowcount  = 0;
    my $genecount = 0;
    for ( ; ; ) {
        my ( $id, $name, $gcnt, $tcnt ) = $cur->fetchrow();
        last if !$id;
        print $res "$id\t";
        print $res "$name\t";

        if ( $merfs_genecnt_href ne '' && $merfs_genomecnt_href ne '' ) {
            if ( exists $merfs_genecnt_href->{$id} ) {
                my $gcnt2 = $merfs_genecnt_href->{$id};
                my $tcnt2 = $merfs_genomecnt_href->{$id};
                $gcnt += $gcnt2;
                $tcnt += $tcnt2;
                delete $merfs_genecnt_href->{$id};
                delete $merfs_genomecnt_href->{$id};
                #print "searchAllSqlExec() mer in db $id $name $gcnt2 $tcnt2<br/>\n";
            }
        }
        print $res "$gcnt\t";
        print $res "$tcnt\n";
        $rowcount++;
        $genecount = $genecount + $gcnt;
        #print "searchAllSqlExec() db $id $name $gcnt $tcnt $genecount<br/>\n";
    }
    $cur->finish();

    if (    $func_id2Name_href ne ''
         && $merfs_genecnt_href   ne ''
         && $merfs_genomecnt_href ne '' )
    {
        foreach my $key ( keys %$merfs_genecnt_href ) {
            my $name  = $func_id2Name_href->{$key};
            my $gcnt2 = $merfs_genecnt_href->{$key};
            my $tcnt2 = $merfs_genomecnt_href->{$key};
            print $res "$key\t";
            print $res "$name\t";
            print $res "$gcnt2\t";
            print $res "$tcnt2\n";
            $rowcount++;
            $genecount = $genecount + $gcnt2;
            #print "searchAllSqlExec() mer leftover $key $name $gcnt2 $tcnt2 $genecount<br/>\n";
        }
    }

    close $res;

    return ( $rowcount, $genecount );
}

sub readCacheFile {
    my ( $cacheFile, $count, @recs ) = @_;

    my $res = newReadFileHandle( $cacheFile, "runJob" );
    while ( my $line = $res->getline() ) {
        chomp $line;
        push( @recs, $line );
        $count++;
    }
    close $res;

    return ( $count, @recs );
}

sub getCacheFile {
    my ($file) = @_;

    $file = WebUtil::checkFileName($file);
    return "$cgi_tmp_dir/$file";
}

sub printGeneDisplayNameMsg {
    my ($userPref, $dohint) = @_;

    my $search;
    my $goto;

    if ( lc($userPref) eq 'yes' ) {
	$search =  "MyIMG annotated product names will replace "
	    . "database gene product names when applicable.";
	$goto = "<br/>(Go to "
	    . alink( $preferences_url, "Preferences" )
	    . " to select using database gene product names only.)";
    } else {
	$search = "Search is only based on database gene product name.";
        $goto = "<br/>(Go to "
	    . alink( $preferences_url, "Preferences" )
	    . " to select using MyIMG annotated product names.)\n";
    }

    if ($dohint && $dohint ne "") {
	printHint($search); # preferences do not have this! -anna
    } else {
	print "<p>";
	print $search;
	print $goto;
	print "</p>";
    }
}

############################################################################
# printFfoAllSeed - Show all SEED.
############################################################################
sub printFfoAllSeed {
    my $link   = "<a href=http://www.theseed.org/>SEED</a>";
    my $fflink = "<a href=http://www.nmpdr.org/FIG/wiki/view.cgi/FIG/FigFam/>FIGfams</a>";
    my $text   = "The $link project performs curation of genomic data which is then used for extraction of protein families ($fflink). ";

    if ($include_metagenomes) {
        WebUtil::printHeaderWithInfo( "SEED Browser", $text, "show description for this tool", "SEED Info", 1 );
    } else {
        WebUtil::printHeaderWithInfo( "SEED Browser", $text, "show description for this tool", "SEED Info" );
    }

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $sql = qq{
        select level_1, level_2, subsystem, role_name
        from seed_functional_role
        order by level_1, level_2, subsystem, role_name
    };

    my $dbh = dbLogin();
    # ANNA: display only those roles that can be linked to genes
    my $rclause = urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $taxonClause = WebUtil::txsClause( "g.taxon", $dbh );
    if ($taxonClause ne "") {
	$sql = qq{
            select distinct sfr.level_1, sfr.level_2,
                   sfr.subsystem, sfr.role_name
            from seed_functional_role sfr, gene_seed_names g
            where sfr.role_name = g.product_name
            and sfr.subsystem = g.subsystem
            $rclause
            $imgClause
            $taxonClause
            order by sfr.level_1, sfr.level_2, sfr.subsystem, sfr.role_name
        };
    }

    print "<p>$text";
    print "<br/>*Showing SEED for genomes in genome cart only<br/>"
	if $taxonClause ne "";
    print "</p>";

    print "<p>\n";
    my $url = "$section_cgi&page=seedList";
    print alink( $url, "FIGfams" );
    print "<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );

    my $count1        = 0;
    my $count2        = 0;
    my $old_level1    = '';
    my $old_level2    = '';
    my $old_subsystem = '';
    for ( ; ; ) {
        my ( $level1, $level2, $subsystem, $role_name ) = $cur->fetchrow();
        last if !$level1;

        if ( $level1 ne $old_level1 ) {
            print "<br/><b>01  $level1</b><br/>\n";
            $old_level2    = '';
            $old_subsystem = '';
        }
        if ( $level2 ne $old_level2 ) {
            print nbsp(4);
            print "<b>02  $level2</b><br/>\n";
        }
        if ( $subsystem ne $old_subsystem ) {
            print nbsp(8);
            print "$subsystem<br/>\n";
            $count2++;
        }
        if ( $role_name ne '' ) {
            print nbsp(12);
            my $url = "$section_cgi&page=seedList";
            $url .= "&id=" . massageToUrl($role_name);
            $url .= "&sub=" . massageToUrl($subsystem);
#	    $url .= "&ignoreFilter=1";
            print alink( $url, $role_name );
            print "<br/>\n";
            $count1++;
        }
        $old_subsystem = $subsystem;
        $old_level2    = $level2;
        $old_level1    = $level1;
    }
    $cur->finish();

    #$dbh->disconnect();

    print "</p>\n";
    printStatusLine( "$count1 SEED products ($count2 subsystems) loaded.", 2 );
    print end_form();
}

############################################################################
# printSeedList - Show list of SEEDs, all if not specified.
############################################################################
sub printSeedList {
    my $fflink = "<a href=http://www.nmpdr.org/FIG/wiki/view.cgi/FIG/FigFam/>FIGfams</a>";
    my $text1  = "$fflink are sets of Protein Sequences that are similar along their full length. ";
    my $text2  = "All of the proteins within a single FIGfam are believed to implement the same function.";
    my $text   = $text1 . $text2;

    if ($include_metagenomes) {
        WebUtil::printHeaderWithInfo( "FIGfams", $text, "show description for this tool", "FIGfam Info", 1 );
    } else {
        WebUtil::printHeaderWithInfo( "FIGfams", $text, "show description for this tool", "FIGfam Info" );
    }

    print "<p>$text1<br/>$text2</p>\n";

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $id   = param("id");
    my $subs = param("sub");
    my $ignoreFilter = param("ignoreFilter");
    $ignoreFilter = 0 if $ignoreFilter eq "";

    if ($id ne "") {
	print "<p><u>Product Name</u>: $id";
	print "<br/><u>Subsystem</u>: $subs" if $subs ne "";
	print "</p>";
    }

    my $figfams_data_file = '';
    if ( $id eq '' && !$include_metagenomes ) {
        $figfams_data_file = $env->{figfams_data_file};
        if ( !-e $figfams_data_file ) {
            $figfams_data_file = '';
        }
    }

    my $it = new InnerTable( 1, "seedlist$$", "seedlist", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "SEED Product Name", "asc",  "left", "", "", "wrap" );
    $it->addColSpec( "SEED Subsystem",    "asc",  "left", "", "", "wrap" );
    $it->addColSpec( "Gene Count",        "desc", "right" );
    $it->addColSpec( "Genome Count",      "desc", "right" );

    #print "FindFunctions::printSeedList() 0 " . currDateTime() . "<br/>\n";

    my $last_role_name;
    my $subsystem_str;
    my $gcnt_total;
    my $tcnt_total;

    my @recs;
    my $count = 0;

    if ( $figfams_data_file eq "" ) {
        my $dbh = dbLogin();

        my $whereClause = '';
        my @bindList    = ();
        if ( $id ne '' ) {
            $whereClause = "where g.product_name = ? ";
            push( @bindList, $id );
            if ( $subs ne '' ) {
                $whereClause .= "and g.subsystem = ? ";
                push( @bindList, $subs );
            }
        } else {
            $whereClause = 'where 1 = 1 ';
        }

        my $rclause = urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
	my $taxonClause = WebUtil::txsClause( "g.taxon", $dbh );
	print "<p>*Showing counts for genomes in genome cart only</p>"
	    if $taxonClause ne "";

        my $sql = qq{
            select g.product_name, g.subsystem, 
                   count( distinct g.gene_oid ), 
                   count( distinct g.taxon )
            from gene_seed_names g 
            $whereClause
            $rclause
            $imgClause
            $taxonClause
            group by g.product_name, g.subsystem
        };

        #print "printSeedList sql: $sql<br/>\n";
        #print "\@bindList: @bindList<br/>";

        my $cur = '';
        if ( scalar(@bindList) > 0 ) {
            $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        } else {
            $cur = execSql( $dbh, $sql, $verbose );
        }

        for ( ;; ) {
            my ( $role_name, $subsystem, $gcnt, $tcnt ) = $cur->fetchrow();
            last if !$role_name;
            $count++;

	    # test use
	    #if ($count < 10) {
	    #print "<br/>printSeedList: $role_name, $subsystem, $gcnt, $tcnt";
	    #}

            if ( $last_role_name ne $role_name ) {
                push( @recs, "$last_role_name\t$subsystem_str\t$gcnt_total\t$tcnt_total" )
                  if $last_role_name ne "";

                if ($subsystem eq "") {
                    $subsystem_str = "";
                } else {
                    $subsystem_str = $subsystem;
                }
                $gcnt_total    = $gcnt;
                $tcnt_total    = $tcnt;
            } else {
                if ($subsystem ne "") {
                    my $ss = "";
                    $ss = $subsystem_str.";<br/>" if $subsystem_str ne "";
                    $subsystem_str = $ss.$subsystem;
                }
                $gcnt_total += $gcnt;
                $tcnt_total += $tcnt;
            }

            $last_role_name = $role_name;
        }

        #$dbh->disconnect();

    } else {
        #print "printSeedList figfams_data_file: $figfams_data_file<br/>\n";
        my $rfh = newReadFileHandle($figfams_data_file);
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            my ( $role_name, $subsystem, $gcnt, $tcnt ) = split( /\t/, $s );
            $count++;

	    # test use
	    #if ($count == 1) {
	    #print "<br/>printSeedList $role_name, $subsystem, $gcnt, $tcnt";
	    #}

            if ( $last_role_name ne $role_name ) {
                push( @recs, "$last_role_name\t$subsystem_str\t$gcnt_total\t$tcnt_total" )
                  if $last_role_name ne "";

		if ($subsystem eq "") {
		    $subsystem_str = "";
		} else {
                    $subsystem_str = $subsystem;
		}
                $gcnt_total    = $gcnt;
                $tcnt_total    = $tcnt;
            } else {
		if ($subsystem ne "") {
                    my $ss = "";
                    $ss = $subsystem_str.";<br/>" if $subsystem_str ne "";
                    $subsystem_str = $ss.$subsystem;
		}
		$gcnt_total += $gcnt;
		$tcnt_total += $tcnt;
            }

            $last_role_name = $role_name;
        }
        close $rfh;
    }

    #print "FindFunctions::printSeedList() 1 " . currDateTime() . "<br/>\n";

    # lets not forget the last record - ken
    push( @recs, "$last_role_name\t$subsystem_str\t$gcnt_total\t$tcnt_total" )
      if $last_role_name ne "";

    foreach my $rec (@recs) {
        my ( $role_name, $subsystem, $gcnt, $tcnt ) = split( /\t/, $rec );

        my $r;
        $r .= $role_name . $sd . $role_name . "\t";
        $r .= $subsystem . $sd . $subsystem . "\t";

        # gene count
        my $g_url = "$section_cgi&page=ffgFindFunctionsGeneList";
        $g_url .= "&searchFilter=seedProduct";
        $g_url .= "&id=" . massageToUrl($role_name);
        $g_url .= "&sub=" . massageToUrl($subsystem);
        $g_url .= "&cnt=$gcnt";
	$g_url .= "&ignoreFilter=$ignoreFilter";
        if ( $gcnt > 0 ) {
            $r .= $gcnt . $sd . alink( $g_url, $gcnt ) . "\t";
        } else {
            $r .= $gcnt . $sd . "0" . "\t";
        }

        # genome count
        my $t_url = "$section_cgi&page=ffgFindFunctionsGenomeList";
        $t_url .= "&searchFilter=seedProduct";
        $t_url .= "&id=" . massageToUrl($role_name);
        $t_url .= "&sub=" . massageToUrl($subsystem);
        $t_url .= "&cnt=$tcnt";
	$t_url .= "&ignoreFilter=$ignoreFilter";
        if ( $tcnt > 0 ) {
            $r .= $tcnt . $sd . alink( $t_url, $tcnt ) . "\t";
        } else {
            $r .= $tcnt . $sd . "0" . "\t";
        }

        $it->addRow($r);
    }

    if ($count > 0) {
	$it->printOuterTable(1);
    } else {
	print "<p><font color='red'>No SEEDs found</font></p>";
    }

    printStatusLine( "$count SEEDs retrieved", 2 );
    print end_form();
}

############################################################################
# printFfoAllTc - Show all TC.
############################################################################
sub printFfoAllTc {
    printMainForm();

    my $tclink = "<a href=http://www.tcdb.org/>" . "Transporter Classification (TC) Database</a>";

    my $text =
"The $tclink is an IUBMS approved classification system for membrane transport proteins, including ion channels. The <b>TC</b> system is analogous to the <b>EC</b> (Enzyme Commission) system for classifying enzymes, except that it incorporates both functional and phylogenetic information.";

    my $text2 =
"Transport systems are classified on the basis of five criteria, and each of these criteria corresponds to one of the five numbers or letters within the TC# for a particular type of transporter. Thus a TC # normally has five components as follows: V.W.X.Y.Z. V (a number) corresponds to the transporter class (i.e., channel, carrier (porter), primary active transporter, group translocator or transmembrane electron flow carrier); W (a lettter) corresponds to the transporter subclass which in the case of primary active transporters refers to the energy source used to drive transport; X (a number) corresponds to the transporter family (sometimes actually a superfamily); Y (a number) corresponds to the subfamily in which a transporter is found, and Z corresponds to a specific transporter with a particular substrate or range of substrates transported.";

    my $description = "$text<br/><br/>$text2";
    if ($include_metagenomes) {
        WebUtil::printHeaderWithInfo( "Transporter Classification Browser",
                                      $description, "show description for this tool",
                                      "TC Info", 1 );
    } else {
        WebUtil::printHeaderWithInfo( "Transporter Classification Browser",
                                      $description, "show description for this tool",
                                      "TC Info" );
    }

    print "<p>$text</p>";
    printStatusLine( "Loading ...", 1 );

    print "<p>\n";
    my $url = "$section_cgi&page=tcList";
    print alink( $url, "Transporter Classification List" );
    print "<br/><br/>\n";

    my $sql = qq{
        select distinct tf.tc_family_num, tf.tc_family_name
        from tc_family tf
    };

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );

    my $count      = 0;
    my $lastprefix = "1";
    for ( ; ; ) {
        my ( $tc_family_num, $tc_family_name ) = $cur->fetchrow();
        last if !$tc_family_num;

        my $tcnum = $tc_family_num;
        $tcnum =~ s/TC://;

        my $url_num  = $tc_base_url . $tcnum;
        my $url_name = "$section_cgi&page=tcList";
        $url_name .= "&id=" . WebUtil::massageToUrl2($tc_family_num);

        # extra closing </font> tag as a workaround for
        # entry in db with an unclosed <font> tag
        $tc_family_name .= "</font>";

        my @tmpnum = split( /\./, $tc_family_num );
        if ( $lastprefix != $tmpnum[0] ) {
            if ( $count > 0 ) { print "<br/>\n" }
            $lastprefix = $tmpnum[0];
        }

        print "<b>"
          . alink( $url_num, $tc_family_num )
          . "  -  </b> "
          . alink( $url_name, $tc_family_name, '', 1 )
          . "<br/>\n";
        $count++;
    }
    $cur->finish();

    #$dbh->disconnect();

    print "</p>\n";
    printStatusLine( "$count families loaded.", 2 );
    print end_form();
}

############################################################################
# printTcList - Show list of Tc, all if not specified.
############################################################################
sub printTcList {
    my $tclink = "<a href=http://www.tcdb.org/>" . "Transporter Classification (TC) Database</a>";

    my $text =
"The $tclink is an IUBMS approved classification system for membrane transport proteins, including ion channels. The <b>TC</b> system is analogous to the <b>EC</b> (Enzyme Commission) system for classifying enzymes, except that it incorporates both functional and phylogenetic information. Functionally distinct types of transporters are classified by classes and subclasses, while phylogenetically distinct types are classified using families and superfamilies.";

    if ($include_metagenomes) {
        WebUtil::printHeaderWithInfo( "Transporter Classification Families",
                                      $text, "show description for this tool",
                                      "TC Info", 1 );
    } else {
        WebUtil::printHeaderWithInfo( "Transporter Classification Families",
                                      $text, "show description for this tool",
                                      "TC Info" );
    }
    print "<p>$text</p>";

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $id           = param("id");
    my $tc_data_file = '';

    #my $tc_data_file = $env->{tc_data_file};
    if ( !-e $tc_data_file ) {
        $tc_data_file = "";
    }

    my $dbh = dbLogin();

    my $whereClause_func = '';
    my @bindList         = ();
    if ( $id ne '' ) {
        $whereClause_func = "where f.tc_family_num = ? ";
        push( @bindList, $id );
        $tc_data_file = "";    # it is not the List page
    } else {
        $whereClause_func = "where 1=1 ";
    }

    # get go_ids for tc_family_num
    my $sql = qq{
        select f.tc_family_num, count(distinct f.go_id)
        from tc_family_go_terms f
        $whereClause_func
        group by f.tc_family_num
    };

    #print "printTcList() go sql: $sql<br/>\n";

    my $cur = '';
    if ( scalar(@bindList) > 0 ) {
        $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    my %tcFamNum2go = {};
    for ( ; ; ) {
        my ( $tc_family_num, $go_id ) = $cur->fetchrow();
        last if !$tc_family_num;

        $tcFamNum2go{$tc_family_num} = $go_id;
    }
    $cur->finish();

    # get cog_ids for tc_family_num
    my $sql = qq{
        select f.tc_family_num, count(distinct f.cogs)
        from tc_family_cogs f
        $whereClause_func
        group by f.tc_family_num
    };

    #print "printTcList() cog sql: $sql<br/>\n";

    my $cur = '';
    if ( scalar(@bindList) > 0 ) {
        $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    my %tcFamNum2cog = {};
    for ( ; ; ) {
        my ( $tc_family_num, $cog ) = $cur->fetchrow();
        last if !$tc_family_num;
        $tcFamNum2cog{$tc_family_num} = $cog;
    }
    $cur->finish();

    # get pfam_ids for tc_family_num
    my $sql = qq{
        select f.tc_family_num, count(distinct f.pfam)
        from tc_family_pfams f
        $whereClause_func
        group by f.tc_family_num
    };

    #print "printTcList() pfam sql: $sql<br/>\n";

    my $cur = '';
    if ( scalar(@bindList) > 0 ) {
        $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    my %tcFamNum2pfam = {};
    for ( ; ; ) {
        my ( $tc_family_num, $pfam ) = $cur->fetchrow();
        last if !$tc_family_num;

        $tcFamNum2pfam{$tc_family_num} = $pfam;
    }
    $cur->finish();

    # get img_terms_ids for tc_family_num
    my $sql = qq{
        select f.tc_family_num, count(distinct f.img_terms)
        from tc_family_img_terms f
        $whereClause_func
        group by f.tc_family_num
    };

    #print "printTcList() tc sql: $sql<br/>\n";

    my $cur = '';
    if ( scalar(@bindList) > 0 ) {
        $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    } else {
        $cur = execSql( $dbh, $sql, $verbose );
    }

    my %tcFamNum2img = {};
    for ( ; ; ) {
        my ( $tc_family_num, $img_terms ) = $cur->fetchrow();
        last if !$tc_family_num;

        $tcFamNum2img{$tc_family_num} = $img_terms;
    }
    $cur->finish();

    # tc_family_num main
    #my $rclause   = urClause("g.taxon");
    #my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    #my $sql = qq{
    #    select f.tc_family_num, f.tc_family_name, count( distinct g.gene_oid ), count( distinct g.taxon )
    #    from tc_family f
    #    left join gene_tc_families gtf on f.tc_family_num = gtf.tc_family
    #    left join gene g on gtf.gene_oid = g.gene_oid
    #    $whereClause_func
    #    $rclause
    #    $imgClause
    #    group by f.tc_family_num, f.tc_family_name
    #};

    my $rclause   = urClause("g.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');
    my $sql       = qq{
        select f.tc_family_num, f.tc_family_name,
               sum( g.gene_count ), count( distinct g.taxon_oid )
        from tc_family f, mv_taxon_tc_stat g 
        $whereClause_func
        and f.tc_family_num = g.tc_family
        $rclause
        $imgClause
        group by f.tc_family_num, f.tc_family_name
    };

    #print "printTcList() sql: $sql<br/>\n";

    # query times out for metagenomes, so don't show counts:
    #if ($include_metagenomes) {
    #}

    my $cur = '';
    if ( $tc_data_file eq "" ) {
        if ( scalar(@bindList) > 0 ) {
            $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        } else {
            $cur = execSql( $dbh, $sql, $verbose );
        }
    }

    my $it = new InnerTable( 1, "tclist$$", "tclist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "TC Family Number", "asc",  "left" );
    $it->addColSpec( "TC Family Name",   "asc",  "left" );
    $it->addColSpec( "GO Count",         "desc", "right" );
    $it->addColSpec( "COG Count",        "desc", "right" );
    $it->addColSpec( "Pfam Count",       "desc", "right" );
    $it->addColSpec( "IMG Terms Count",  "desc", "right" );

    $it->addColSpec( "Gene Count",   "desc", "right" );
    $it->addColSpec( "Genome Count", "desc", "right" );

    my $select_id_name = "func_id";

    my $count = 0;
    my $rfh = newReadFileHandle($tc_data_file) if ( $tc_data_file ne "" );
    for ( ; ; ) {
        my ( $tc_family_num, $tc_family_name, $gcnt, $tcnt );
        if ( $tc_data_file ne "" ) {
            my $s = $rfh->getline();
            last if !$s;
            chomp $s;
            ( $tc_family_num, $tc_family_name, $gcnt, $tcnt ) =
              split( /\t/, $s );

            #print "fetched from $tc_data_file: $s<br/>\n";
        } else {
            ( $tc_family_num, $tc_family_name, $gcnt, $tcnt ) = $cur->fetchrow();

            #print "fetched from database: $tc_family_num, $gcnt, $tcnt<br/>\n";
            last if !$tc_family_num;
        }
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$tc_family_num' />\t";

        my $tcnum = $tc_family_num;
        $tcnum =~ s/TC://;

        my $url_num = $tc_base_url . $tcnum;
        $r .= $tc_family_num . $sd . alink( $url_num, $tc_family_num ) . "\t";
        $r .= $tc_family_name . $sd . $tc_family_name . "\t";

        # go
        my $goIds_str1 = $tcFamNum2go{$tc_family_num};
        my $url = alink( "$section_cgi&page=tcFuncDetails&func=go&id=$tc_family_num", $goIds_str1 );
        if ( $goIds_str1 eq "" ) {
            $r .= "0" . $sd . "0" . "\t";
        } else {
            $r .= $goIds_str1 . $sd . $url . "\t";
        }

        # cog
        my $cogIds_str1 = $tcFamNum2cog{$tc_family_num};
        my $url = alink( "$section_cgi&page=tcFuncDetails&func=cog&id=$tc_family_num", $cogIds_str1 );
        if ( $cogIds_str1 eq "" ) {
            $r .= "0" . $sd . "0" . "\t";
        } else {
            $r .= $cogIds_str1 . $sd . $url . "\t";
        }

        # pfam
        my $pfamIds_str1 = $tcFamNum2pfam{$tc_family_num};
        my $url = alink( "$section_cgi&page=tcFuncDetails&func=pfam&id=$tc_family_num", $pfamIds_str1 );
        if ( $pfamIds_str1 eq "" ) {
            $r .= "0" . $sd . "0" . "\t";
        } else {
            $r .= $pfamIds_str1 . $sd . $url . "\t";
        }

        # img terms
        my $imgIds_str1 = $tcFamNum2img{$tc_family_num};
        my $url = alink( "$section_cgi&page=tcFuncDetails&func=imgterm&id=$tc_family_num", $imgIds_str1 );
        if ( $imgIds_str1 eq "" ) {
            $r .= "0" . $sd . "0" . "\t";
        } else {
            $r .= $imgIds_str1 . $sd . $url . "\t";
        }

        # gene count
        my $g_url = "$section_cgi&page=ffgFindFunctionsGeneList";
        $g_url .= "&searchFilter=tc";
        $g_url .= "&id=" . massageToUrl($tc_family_num);
        $g_url .= "&cnt=$gcnt&ignoreFilter=1";
        if ( $gcnt > 0 ) {
            $r .= $gcnt . $sd . alink( $g_url, $gcnt ) . "\t";
        } else {
            $r .= $gcnt . $sd . "0" . "\t";
        }

        # genome count
        my $t_url = "$section_cgi&page=ffgFindFunctionsGenomeList";
        $t_url .= "&searchFilter=tc";
        $t_url .= "&id=" . massageToUrl($tc_family_num);
        $t_url .= "&cnt=$tcnt&ignoreFilter=1";
        if ( $tcnt > 0 ) {
            $r .= $tcnt . $sd . alink( $t_url, $tcnt ) . "\t";
        } else {
            $r .= $tcnt . $sd . "0" . "\t";
        }

        $it->addRow($r);
    }

    close $rfh if ( $tc_data_file ne "" );

    #$dbh->disconnect();

    WebUtil::printFuncCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count TC families retrieved", 2 );
    print end_form();
}

#
# TC function counts function detail list
# - ken
sub printTcFuncDetails {
    my $func = param("func");
    my $id   = param("id");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select tf.tc_family_num, tf.tc_family_name
        from tc_family tf
        where tf.tc_family_num = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $id );
    my ( $tc_family_num, $tc_family_name ) = $cur->fetchrow();
    $cur->finish();

    my $func_name;        # function name for table header
    my $func_url;         # function url
    my $func_id_label;    # function checkbox name
    if ( $func eq "go" ) {
        $func_url      = $go_base_url;
        $func_name     = "GO";
        $func_id_label = "go_id";
        $sql           = qq{
            select distinct f.go_id, g.go_term 
            from tc_family_go_terms f
            left join go_term g on f.go_id = g.go_id
            where f.tc_family_num = ?
        };
    } elsif ( $func eq "cog" ) {
        $func_url      = $cog_base_url;
        $func_name     = "COG";
        $func_id_label = "cog_id";
        $sql           = qq{
            select distinct f.cogs, c.cog_name
            from tc_family_cogs f
            left join cog c on f.cogs = c.cog_id
            where f.tc_family_num = ?
        };
    } elsif ( $func eq "pfam" ) {
        $func_url = $pfam_base_url;

        #$pfamId_sym =~ s/pfam/PF/;
        $func_name     = "Pfam";
        $func_id_label = "pfam_id";
        $sql           = qq{
            select distinct f.pfam, p.name
            from tc_family_pfams f
            left join pfam_family p on f.pfam = p.ext_accession
            where f.tc_family_num = ?
        };
    } elsif ( $func eq "imgterm" ) {
        $func_url      = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail&term_oid=";
        $func_name     = "IMG Terms";
        $func_id_label = "term_oid";
        $sql           = qq{
            select distinct f.img_terms, t.term
            from tc_family_img_terms f
            left join img_term t on f.img_terms = t.term_oid
            where f.tc_family_num = ?
        };
    } else {

        #$dbh->disconnect();
        printStatusLine( "0 loaded", 2 );
        return;
    }

    my $tcnum = $tc_family_num;
    $tcnum =~ s/TC://;
    my $link = alink( $tc_base_url . WebUtil::massageToUrl2($tcnum), $tc_family_name, '', 1 );
    print qq{
        <h1>Transporter Classification - $func_name List</h1>
        <p>$link</p> 
    };

    my $it = new InnerTable( 1, "tclist$$", "tclist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "$func_name ID",   "desc", "right" );
    $it->addColSpec( "$func_name Name", "asc",  "left" );

    my $select_id_name = "func_id";

    my $count = 0;
    my $cur = execSql( $dbh, $sql, $verbose, $id );
    for ( ; ; ) {
        my ( $func_id, $func_name ) = $cur->fetchrow();
        last if !$func_id;
        $count++;
        my $r;
        my $func_id_value = $func_id;
        if ( $func_id_label eq "term_oid" ) {
            $func_id_value = "ITERM:" . $func_id;
        }
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$func_id_value' />\t";

        # pfam ids needs to be prefix with PF for external sites
        my $tmpfunc_id = $func_id;
        $tmpfunc_id =~ s/pfam/PF/;
        my $url = alink( $func_url . $tmpfunc_id, $func_id );
        $r .= $func_id . $sd . $url . "\t";
        $r .= $func_name . $sd . $func_name . "\t";
        $it->addRow($r);
    }
    $cur->finish();

    #$dbh->disconnect();

    WebUtil::printFuncCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count loaded", 2 );
    print end_form();
}

sub isMetaSupported {
    my ($searchFilter) = @_;

    if (    $searchFilter eq "geneProduct"
         || $searchFilter eq "cog"
         || $searchFilter eq "pfam"
         || $searchFilter eq "tigrfam"
         || $searchFilter eq "ec"
         #|| $searchFilter eq "keggEnzymes"
         || $searchFilter eq "koid"
         || $searchFilter eq "koname"
         || $searchFilter eq "kodefn"
         || $searchFilter eq "bc" 
    ) {
        return 1;
    }

    return 0;
}

############################################################################
# searchProductSdb - Search gene_product_genes.sdb
#   and return same data.
#    --es 07/05/13
############################################################################
sub searchProductSdb {
    my ( $dbh, $sdbFile, $searchTerm, $outFile ) = @_;

    my $wfh         = newWriteFileHandle( $outFile, "searchProductSdb" );
    my %validTaxons = getAllTaxonsHashedSelections($dbh);

    my $sdbh = WebUtil::sdbLogin($sdbFile);
    my $sql  = qq{
        select product_oid, gene_display_name, genes
    	from product
    	where lower( gene_display_name ) like ?
    };
    my $cur = execSql( $sdbh, $sql, $verbose, "%$searchTerm%" );
    my $count = 0;
    for ( ; ; ) {
        my ( $product_oid, $gene_display_name, $genes ) = $cur->fetchrow();
        last if $gene_display_name eq "";
        $count++;
        my @genes_a = split( /\s+/, $genes );
        my %genes;
        my %genomes;
        for my $g (@genes_a) {
            my ( $taxon_oid, $gene_oid, $locus_tag, $enzyme ) =
              split( /\|/, $g );
            next if !$validTaxons{$taxon_oid};
            $genes{$gene_oid}    = 1;
            $genomes{$taxon_oid} = 1;
        }
        my $nGenes   = keys(%genes);
        my $nGenomes = keys(%genomes);
        next if $nGenes == 0;
        next if $nGenomes == 0;
        my $r = "$gene_display_name\t";
        $r .= "$nGenes\t";
        $r .= "$nGenomes\t";
        $r .= "$product_oid\t";

        #push( @$recs_aref, $r );
        print $wfh "$r\n";
    }
    $sdbh->disconnect();
    close $wfh;
    webLog("$count hits loaded from '$sdbFile'\n");
}

############################################################################
# getAllTaxonsHashedSelections - Get all valid taxons or just
#    selections.
#    --es 07/09/13
############################################################################
sub getAllTaxonsHashedSelections {
    my ($dbh) = @_;

    my $selections_aref = getSessionParam("genomeFilterSelections");
    my $nSelections     = @$selections_aref;
    my %h;
    for my $s (@$selections_aref) {
        webLog("taxon selection '$s'\n");
        $h{$s} = $s;
    }
    return %h if $nSelections > 0;

    return WebUtil::getAllTaxonsHashed($dbh);
}

############################################################################
# countGenomeSelections - Count the number of genome seletions
#   which are in_file = 'Yes' and which are in_file = 'No'
############################################################################
sub countGenomeSelections {
    my ($dbh) = @_;

    my %merfsTaxons;
    my $sql = qq{
      select taxon_oid
      from taxon
      where obsolete_flag = 'No'
      and in_file = 'Yes'
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;
        $merfsTaxons{$taxon_oid} = 1;
    }
    $cur->finish();
    webLog("$count MER-FS taxons found\n");

    my $selections_aref = getSessionParam("genomeFilterSelections");
    my ( $nNo, $nYes ) = ( 0, 0 );
    for my $taxon_oid (@$selections_aref) {
        if ( $merfsTaxons{$taxon_oid} ) {
            $nYes++;
        } else {
            $nNo++;
        }
    }
    webLog("countGenomeSelections: nNo=$nNo nYes=$nYes\n");
    return ( $nNo, $nYes );
}

1;
