############################################################################
# FindGenes.pm - Formerly geneSearch.pl.
#  Module to handle the "Find Genes" menu tab option.
#    --es 07/07/2005
#
# $Id: FindGenes.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package FindGenes;
my $section = "FindGenes";

use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use Data::Dumper;
use ScaffoldPanel;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use InnerTable;
use TreeViewFrame;
use GeneTableConfiguration;
use MerFsUtil;
use MetaUtil;
use GenomeListJSON;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $cgi_url               = $env->{cgi_url};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $img_internal          = $env->{img_internal};
my $tmp_dir               = $env->{tmp_dir};
my $web_data_dir          = $env->{web_data_dir};
my $taxon_faa_dir         = "$web_data_dir/taxon.faa";
my $kegg_orthology_url    = $env->{kegg_orthology_url};
my $swiss_prot_base_url   = $env->{swiss_prot_base_url};
my $user_restricted_site  = $env->{user_restricted_site};
my $no_restricted_message = $env->{no_restricted_message};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $include_metagenomes   = $env->{include_metagenomes};
my $include_img_terms     = $env->{include_img_terms};
my $show_myimg_login      = $env->{show_myimg_login};
my $mer_data_dir          = $env->{mer_data_dir};
my $search_dir            = $env->{search_dir};
my $flank_length          = 25000;
my $max_batch             = 100;
my $max_rows              = 1000;
my $max_seq_display       = 30;
my $max_metagenome_selection = 50;
my $grep_bin              = $env->{grep_bin};
my $rdbms                 = getRdbms();
my $in_file               = $env->{in_file};
my $http_solr_url         = $env->{ http_solr_url };

### optional genome field columns to configuration and display
my @optCols = GeneTableConfiguration::getGeneFieldAttrs();
push( @optCols, 'scaffold' );

#push(@optCols, 'ko_id,ko_name,definition');

my %searchFilterName = (
    gene_display_name_iex => "Gene Product Name",
    myImgAnnotation_iex   => "MyIMG Annotation",
    gene_symbol_list      => "Gene Symbol",
    locus_tag_list        => "Locus Tag",
    locus_tag_merfs       => "Locus Tag",
    genbank_list          => "GenBank Accession",
    giNo_list             => "NCBI GI Number",
    gene_oid_list         => "Gene ID",
    gene_oid_merfs        => "Gene ID",
    img_orf_type_ex       => "IMG ORF Type",
    img_term_iex          => "IMG Term",
    img_term_synonyms_iex => "IMG Term and Synonyms",
    obsolete_flag_ex      => "Is Obsolete Gene",
    is_pseudogene_ex      => "Is Pseudo Gene",
    seed_iex              => "Seed Product Name/Subsystem",
);

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}


############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;    # number of saved genomes
    $numTaxon = 0 if ( $numTaxon eq "" );

    timeout( 60 * $merfs_timeout_mins );

    if ( paramMatch("fgFindGenes") ne '' || param("page") eq "geneSearchForm" )
    {
        my $searchFilter = param("searchFilter");
        if ( $searchFilter eq "protein_regex" ) {
            printProteinRegExResults();
        }
        elsif ( $searchFilter eq "domain_list" ) {
            printDomainSearchResults();
        }
        else {
            printFindGeneResults();
        }
    } 
    elsif ( param("page") eq 'domainList' ) {
        # from find genes pfam list
        printDomainList();
    }
    else {
        my $ans = 1;    # do not use cache pages if $ans
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                # start cached page - all genomes
                HtmlUtil::cgiCacheInitialize( $section );
                HtmlUtil::cgiCacheStart() or return;
            }
        }
        printGeneSearchForm($numTaxon);
        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    }
}

############################################################################
# printGeneSearchForm - Show basic gene search form.
#   Read from template file and replace some template components.
############################################################################
sub printGeneSearchForm {
    my ($numTaxon) = @_;
    #printTreeViewMarkup();

    my $templateFile = "$base_dir/geneSearch.html";
    my $rfh = newReadFileHandle( $templateFile, "printGeneSearchForm" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$section_cgi/g;
        if ( $s =~ /__searchFilterOptions__/ ) {
            printSearchFilterOptionList();
        }
        elsif ( $s =~ /__genomeListFilter__/ ) {
            printForm($numTaxon);
        }
        #elsif ( $s =~ /__optionColumn__/ ) {
        #    printOptionColumn();
        #}
        elsif ( $s =~ /__hint__/ ) {
            printPageHint();
        }
        elsif ( $s =~ /__mer_fs_note__/ ) {
            if ($include_metagenomes) {
                print qq{
                    <br/>
                    <b>*</b>MER-FS Metagenome supported search filters.
                };
            }
        }
        elsif ( $s =~ /__javascript__/ ) {
            printJavaScript();
        }
        else {
            print "$s\n";
        }
    }
    close $rfh;
}

sub printForm {
    my ($numTaxon) = @_;

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
    $template->param( maxSelected1 => -1 );

    if ( $include_metagenomes ) {
        #$template->param( selectedGenome1Title => '' );
        $template->param( include_metagenomes => 1 );
        $template->param( selectedAssembled1  => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    my $name = "_section_FindGenes_fgFindGenes";
    GenomeListJSON::printHiddenInputType( $section, 'fgFindGenes' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
        ( 'go', $name, 'Go', '', $section, 'fgFindGenes', 'smdefbutton', 'selectedGenome1', 1 );
    print $button;
    print nbsp( 1 );
    print reset( -class => "smbutton" );

    GenomeListJSON::showGenomeCart($numTaxon);
}

sub printTreeViewMarkup {
    printTreeMarkup();
    print qq{
        <script language='JavaScript' type='text/javascript' src='$base_url/findGenesTree.js'>
        </script>
    };
}

sub printJavaScript {
    print qq{
        <script type="text/javascript" >
            for (var i=0; i <showOrHideArray.length; i++) {
                showOrHideArray[i]=new Array(2);
            }
            //select options that permit hiding
            showOrHideArray[0][0] = "gene_symbol_list";
            showOrHideArray[0][1] = "genbank_list";
            showOrHideArray[0][2] = "locus_tag_list"; 
            showOrHideArray[0][3] = "giNo_list";
            showOrHideArray[0][4] = "gene_oid_list";

            var hideArea = 'genomeFilterArea';

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
            }

            for (var i=0; i <termLengthArray.length; i++) {
                termLengthArray[i]=new Array(2);
            }
            //select options that need to length validation
            termLengthArray[0][0] = "gene_display_name_iex"; 
            termLengthArray[0][1] = "img_term_synonyms_iex";
            
        </script>
    };
}

############################################################################
# printOptionColumn - Show option of extra display columns
############################################################################
sub printOptionColumn {
    my $treeId = "optionColumns";
    print "<div id='$treeId' class='ygtv-checkbox'>\n";
    print "</div>\n";

    my $jsObject = "{label:'<b>Additional Output Columns</b>', children: [";
    for ( my $i = 0 ; $i < scalar(@optCols) ; $i++ ) {
        my $key = $optCols[$i];
        next if ( $key eq 'gene_oid' || $key eq 'taxon' );

        if ( $i != 0 ) {
            $jsObject .= ", ";
        }
        my $val = GeneTableConfiguration::getColLabel($key);
        $jsObject .= "{id:\"$key\", label:\"$val\"}";
    }
    $jsObject .= "]}";

    my $categoriesObj =
      "{category:[{name:'$treeId', value:[" . $jsObject . "]}]}";

    print qq{
        <script type="text/javascript">
           setMoreJSObjects($categoriesObj);
           moreTreeInit();
        </script>
        <span><font color='red'>(not applied to 'Pfam Domain', 'Protein Regular Expression Pattern' searches)</font></span>
    };

}

############################################################################
# printUserRestrictedBlastMessage - Print warning message.
############################################################################
sub printUserRestrictedBlastMessage {
    print "<p>\n";
    print "<font color='red'>\n";
    print "\"All IMG Genes, one large BLAST database\" ";
    print "is restricted to public genomes for users\n";
    print "with restricted access to selected genomes.<br/>\n";
    print "However, users may BLAST against currently selected genomes\n";
    print "to find similarities in the genomes where they\n";
    print "have private access.<br/>\n";
    print "</font>\n";
    print "</p>\n";
}

############################################################################
# printSearchFilterOptionList - Print options for search filter.
############################################################################
sub printSearchFilterOptionList {
    my $contact_oid = getContactOid();
    my $myImgAnnotations;
    $myImgAnnotations = qq{
        <option value='myImgAnnotation_iex'>MyIMG Annotation (inexact)</option>
    } if $contact_oid > 0 && $show_myimg_login;
    my $img_term_synonyms;
    $img_term_synonyms =
"<option value='img_term_synonyms_iex'>IMG Term and Synonyms (inexact)</option>"
      if $include_img_terms;

    my $super;
    my $caseNote;
    my $noMerFsNote;
    my $onlyMerFsNote;
    if ($include_metagenomes) {
        $super    = ' *';
        $caseNote = ', case-sensitive for MER-FS Metagenome';
        $noMerFsNote = ', no MER-FS Metagenome';
    }

    print qq{
        <option value="gene_display_name_iex">Gene Product Name (inexact)$super</option>
        $myImgAnnotations
        <option value="gene_symbol_list" title='delimited by commas'>Gene Symbol (list)</option>
        <option value="genbank_list" title='delimited by commas'>GenBank Accession (list)</option>
        <option value="giNo_list" title='delimited by commas'>NCBI GI Number (list)</option>
        <option value="locus_tag_list" title='delimited by commas'>Locus Tag (list$noMerFsNote)</option>
    };
    if ($include_metagenomes) {
        print qq{
            <option value="locus_tag_merfs" title='delimited by commas'>Locus Tag (list$caseNote)$super</option>
        };
    }
    print qq{
        <option value="gene_oid_list" title='delimited by commas'>IMG Gene ID (list$noMerFsNote)</option>
    };
    if ($include_metagenomes) {
        print qq{
            <option value="gene_oid_merfs" title='delimited by commas'>IMG Gene ID (list$caseNote)$super</option>
        };
    }
    print qq{
        $img_term_synonyms
        <option value="seed_iex">SEED Product Name/Subsystem (inexact)</option>
    };
    if ($img_internal) {
        print qq{
            <option value="obsolete_flag_ex">Is Obsolete Gene ("Yes" or "No")</option>
        };        
    }
    print qq{
        <option value="is_pseudogene_ex">Is Pseudo Gene ("Yes" or "No")</option>
        <option value='domain_list' title='delimited by commas'>Pfam Domain Search (list) $super </option>
        <option value="protein_regex">Protein Regular Expression Pattern (inexact)</option>
    };

}

############################################################################
# printFindGeneResults - Show resulting gene list with highliting match
#   regions from keyword search on various fields.   Process results.
#    Inputs:
#      searchTerm - Search term / expression
#      searcFilter - Search filter or field
# SQL type indicators.
#  "ex" = "exact" match indicator.
#  "iex" = "inexact" or substring match.
############################################################################
sub printFindGeneResults {
    my $searchFilter           = param("searchFilter");
    my $searchTerm             = param("searchTerm");
    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");
    my $data_type              = param("q_data_type");

    #my @genomeFilterSelections =
    #OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");
    #print "printFindGeneResults() genomeFilterSelections: @genomeFilterSelections<br/>\n";
    if ( $#genomeFilterSelections < 0 ) {
        if ( $searchFilter ne "gene_symbol_list" && $searchFilter ne "genbank_list" 
          && $searchFilter ne "locus_tag_list" && $searchFilter ne "giNo_list" && $searchFilter ne "gene_oid_list" ) {
            webError("Please select at least one genome.");
        }
    }
    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    my $dbh = dbLogin();

    my @dbTaxons;
    my @metaTaxons;
    if ( $include_metagenomes && scalar(@genomeFilterSelections) > 0 ) {
        my ( $dbTaxons_ref, $metaTaxons_ref ) =
          MerFsUtil::findTaxonsInFile( $dbh, @genomeFilterSelections );
        @dbTaxons   = @$dbTaxons_ref;
        @metaTaxons = @$metaTaxons_ref;
    }
    else {
        @dbTaxons = @genomeFilterSelections;
    }
    #print "printFindGeneResults() dbTaxons: @dbTaxons<br/>\n";
    #print "printFindGeneResults() metaTaxons: @metaTaxons<br/>\n";
    if ( $include_metagenomes && isMetaSupported($searchFilter)
        && scalar(@metaTaxons) > $max_metagenome_selection ) {
        webError("Please select no more than $max_metagenome_selection metagenomes.");
    }

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;
    my $searchTermLiteral = $searchTerm;

    # get search terms
    my @term_list;
    my $term_str;
    my @db_term_list;
    my $db_term_str;
    my @meta_term_list;
    
    webLog("============== $searchFilter \n");
    if ( $searchFilter eq "gene_oid_list" ) {
        if ($include_metagenomes) {
            @term_list = WebUtil::splitTerm( $searchTermLc, 0, 0 );
            my ( $dbOids_ref, $metaOids_ref ) =
              MerFsUtil::splitDbAndMetaOids(@term_list);
            @db_term_list   = @$dbOids_ref;
            @meta_term_list = @$metaOids_ref;
            $term_str       = join( ',', @db_term_list );
        }
        else {
            @term_list = WebUtil::splitTerm( $searchTermLc, 1, 0 );
            $term_str = join( ',', @term_list );
        }
        if ( blankStr($term_str) && scalar(@meta_term_list) == 0 ) {
            webError("Please enter a comma separated list of valid ID's.");
        }
        if ( scalar(@meta_term_list) > 0 ) {
            webError(
                "You have entered ID(s) that are not integers.  If they are Gene IDs for metagenome, please select 'IMG Gene ID (list, only MER-FS Metagenome)' filter to search!"
            );
        }
    }
    elsif ($searchFilter eq "locus_tag_list"
        || $searchFilter eq "locus_tag_merfs"
        || $searchFilter eq "gene_oid_merfs"
        || $searchFilter eq "gene_symbol_list"
        || $searchFilter eq "genbank_list" )
    {
        @term_list = WebUtil::splitTerm( $searchTermLc, 0, 0 );
        $term_str = WebUtil::joinSqlQuoted( ',', @term_list );
        if ( blankStr($term_str) ) {
            webError("Please enter a comma separated list of valid ID's.");
        }

        if ( $searchFilter eq "gene_oid_merfs" ) {
            @db_term_list = WebUtil::splitTerm( $searchTermLc, 1, 1 );
            if ( scalar(@db_term_list) > 0 ) {
                
                # check for old metagenome gene oids
                my $mapping_href = MetaUtil::isOldMetagenomeGeneIds($dbh, \@db_term_list);
                foreach my $old_gene_oid (keys %$mapping_href) {
                    my $new_id = $mapping_href->{$old_gene_oid};
                    $term_str = $term_str . ", '$new_id'";
                    push(@term_list, $new_id);
                    $searchTerm = $searchTerm . ", $new_id";
                    $searchTermLc = $searchTermLc . ", $new_id";
                    $searchTermLiteral = $searchTermLiteral  . ", $new_id";
                }
                
                $db_term_str = join( ',', @db_term_list );
            }
        }
        
        webLog("=============== $term_str \n");      
        webLog("=============== $db_term_str \n");
        webLog("=============== $searchTerm \n");
        webLog("=============== $searchTermLc \n");

    }
    elsif ( $searchFilter eq "giNo_list" ) {
        @term_list = WebUtil::splitTerm( $searchTerm, 1, 0 );
        $term_str = join( ',', @term_list );
        if ( blankStr($term_str) ) {
            webError("Please enter a comma separated list of valid ID's.");
        }
    }

    #gene_display_name_iex: take too long to search 'ase'
    #img_term_synonyms_iex: union query takes too long if result set too large
    if ( $searchFilter eq "gene_display_name_iex" || $searchFilter eq "img_term_synonyms_iex" ) {
        if ( $searchTerm && length($searchTerm) < 4 ) {
            webError("Please enter a search term at least 4 characters long.");
        }
    }

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    if ( $maxGeneListResults ne "" ) {
        $max_rows = $maxGeneListResults;
    }

    printStatusLine( "Loading ...", 1 );

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind
      ( $dbh, "tx.taxon_oid", \@genomeFilterSelections );
    my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');

    my $outputColStr = param("outputCol");
    if ( $searchFilter eq "gene_symbol_list" ) {
        $outputColStr =~ s/gene_symbol\,?//i;
    }
    elsif ( $searchFilter eq "genbank_list" ) {
        $outputColStr =~ s/protein_seq_accid\,?//i;
    }
    elsif ( $searchFilter eq "obsolete_flag_ex" ) {
        $outputColStr =~ s/obsolete_flag\,?//i;
    }
    elsif ( $searchFilter eq "is_pseudogene_ex" ) {
        $outputColStr =~ s/is_pseudogene\,?//i;
    }
    my @outputCol      = processParamValue($outputColStr);
    my $outColClause   = '';
    my $keggJoinClause = '';
    for my $c (@outputCol) {
        if ( $c =~ /add_date/i ) {
            # its a date column
            # use iso format yyyy-mm-dd s.t. its ascii sortable - ken
            $outColClause .= ", to_char(g.$c, 'yyyy-mm-dd') ";
        }
        elsif ( $c =~ /ko_id/i || $c =~ /ko_name/i || $c =~ /definition/i ) {
            $outColClause .= ", kt.$c ";
            $keggJoinClause = qq{
                left join gene_ko_terms gkt on g.gene_oid = gkt.gene_oid
                left join ko_term kt on gkt.ko_terms = kt.ko_id             
            } if ( $keggJoinClause eq '' );
        }
        else {
            $outColClause .= ", g.$c ";
        }
    }

    my $sql;
    my @bindList;

    if ( scalar(@genomeFilterSelections) > 0 && scalar(@dbTaxons) == 0 ) {
        #no need to fetch things from database
    } else {

        if ( $searchFilter eq "gene_display_name_iex" ) {
            #in() is slow for many taxons, apply global temp table strategy to improve performance
            my $switchNum = 200;
            if ( $taxonClause !~ /gtt_num_id/i && scalar(@dbTaxons) > $switchNum ) {
                $taxonClause = OracleUtil::getTaxonOidClause($dbh, "tx.taxon_oid", \@dbTaxons, $switchNum);
                @bindList_txs = ();
            }
            ( $sql, @bindList ) = getGeneDisplayNameSql(
                $searchTermLc, $taxonClause,    $rclause,   $imgClause,
                $outColClause, $keggJoinClause, \@bindList_txs, \@bindList_ur
              );
        }

        ( $sql, @bindList ) = getImgAnnotationSql(
            $searchTermLc, $taxonClause,    $rclause,       $imgClause,
            $outColClause, $keggJoinClause, \@bindList_txs, \@bindList_ur
          )
          if ( $searchFilter eq "myImgAnnotation_iex" );

        ( $sql, @bindList ) =
          getGeneSymbolListSql( $term_str, $rclause, $imgClause,
            $outColClause, $keggJoinClause, \@bindList_ur )
          if $searchFilter eq "gene_symbol_list";

        ( $sql, @bindList ) =
          getLocusTagListSql( $term_str, $rclause, $imgClause,
            $outColClause, $keggJoinClause, \@bindList_ur )
          if $searchFilter eq "locus_tag_list";

        ( $sql, @bindList ) =
          getLocusTagListSql( $term_str, $rclause, $imgClause,
            $outColClause, $keggJoinClause, \@bindList_ur )
          if $searchFilter eq "locus_tag_merfs";

        ( $sql, @bindList ) =
          getGeneBankListSql( $term_str, $rclause, $imgClause,
            $outColClause, $keggJoinClause, \@bindList_ur )
          if $searchFilter eq "genbank_list";

        ( $sql, @bindList ) =
          getGINumberSql( $term_str, $rclause, $imgClause, 
            $outColClause, $keggJoinClause, \@bindList_ur )
          if $searchFilter eq "giNo_list";

        ( $sql, @bindList ) =
          getGeneOidListSql( $dbh, $term_str, $rclause, $imgClause, 
            $outColClause, $keggJoinClause, \@bindList_ur )
          if ( $searchFilter eq "gene_oid_list" && !blankStr($term_str) );

        ( $sql, @bindList ) =
          getGeneOidListSql( $dbh, $db_term_str, $rclause, $imgClause, 
            $outColClause, $keggJoinClause, \@bindList_ur )
          if ( $searchFilter eq "gene_oid_merfs" && !blankStr($db_term_str) );

        ( $sql, @bindList ) = getImgSynonymsInexactSql(
            $searchTermLc, $taxonClause,    $rclause,       $imgClause,
            $outColClause, $keggJoinClause, \@bindList_txs, \@bindList_ur
          )
          if ( $searchFilter eq "img_term_synonyms_iex" );

        ( $sql, @bindList ) = getObsoleteExactSql(
            $searchTermLc, $taxonClause,    $rclause,       $imgClause,
            $outColClause, $keggJoinClause, \@bindList_txs, \@bindList_ur
          )
          if ( $searchFilter eq "obsolete_flag_ex" );

        ( $sql, @bindList ) = getPseudogeneExactSql(
            $searchTermLc, $taxonClause,    $rclause,       $imgClause,
            $outColClause, $keggJoinClause, \@bindList_txs, \@bindList_ur
          )
          if ( $searchFilter eq "is_pseudogene_ex" );

        ( $sql, @bindList ) = getGeneSeedSql(
            $searchTermLc, $taxonClause,    $rclause,       $imgClause,
            $outColClause, $keggJoinClause, \@bindList_txs, \@bindList_ur
          )
          if ( $searchFilter eq "seed_iex" );
    
        #print "FindGenes::printFindGeneResults() sql: $sql<br/>\n";
        #print "FindGenes::printFindGeneResults() bindList: @bindList<br/>\n";
    }

    #my $searchTermLiteral_u = $searchTermLiteral;
    #$searchTermLiteral_u =~ tr/a-z/A-Z/;

    my $contact_oid = getContactOid();
    if ( $contact_oid == 100546 ) {
        print "<p>*** db start time: " . currDateTime() . "<br/>\n";
    }

    my $count = 0;
    my $trunc = 0;
    my @recs;
    my $last_gene_oid;
    my $termsLength = 0;
    my %termFoundHash;

    # --es 07/05/13
    my $productSdb = "$search_dir/gene_product_genes.sdb";
    if ( -e $productSdb && !$include_metagenomes && 
           $searchFilter eq "gene_display_name_iex" ) {
        ($count, $trunc) = 
           searchProductSdb( $dbh, $productSdb, $searchTermLc, $max_rows, \@recs );
            $sql = "";
            $count = @recs;
    }

    if ($sql) {
        my %validTaxons;
        if ($searchFilter eq "gene_symbol_list"
        || $searchFilter eq "genbank_list"
        || $searchFilter eq "locus_tag_list"
        || $searchFilter eq "locus_tag_merfs"
        || $searchFilter eq "giNo_list"
        || $searchFilter eq "gene_oid_list"
        || $searchFilter eq "gene_oid_merfs") {
            %validTaxons = WebUtil::getAllTaxonsHashed($dbh);
        }
        else {
            %validTaxons = getValidTaxons($dbh, 
                $taxonClause, $rclause, $imgClause, \@bindList_txs, \@bindList_ur);
        }
        #print "printFindGeneResults() valid taxons: " . keys(%validTaxons). "<br/>\n";

        webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

        my $useSolr = 0;
        if ( $http_solr_url && $searchFilter eq "gene_display_name_iex" ) {
            require WebService::Solr;
            my $solr_imgdb_url = $http_solr_url . '/imgdb';
            #print "solr_imgdb_url: $solr_imgdb_url<br/>\n";
            my $solr = WebService::Solr->new( $solr_imgdb_url );
            if ( $solr->ping() ) {
                $useSolr = 1;

                my %done;
                my $count_old = $count;
                ($count, $trunc) = searchWebserviceSolr( $solr, $searchTermLc, 
                    $max_rows, $count, $trunc, \@recs, \%done, \%validTaxons, \@genomeFilterSelections, 1 );
                #no results from search 1
                if ( !$trunc && $count < $max_rows && $count == $count_old ) {
                    ($count, $trunc) = searchWebserviceSolr( $solr, $searchTermLc, 
                        $max_rows, $count, $trunc, \@recs, \%done, \%validTaxons, \@genomeFilterSelections, 2 );
                }
            }
            else {
                print "Can not ping Solr<br/>\n";                
            }                        
        }
        
        if ( !$useSolr ) {
            my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    
            for ( ; ; ) {
                my ( $gene_oid, $locus_tag, $gene_display_name, $taxon_oid,
                    $taxon_display_name, @terms )
                  = $cur->fetchrow();
                last if !$gene_oid;
                next if !$validTaxons{$taxon_oid};
                $termsLength = scalar(@terms);
    
                #if ( $gene_oid == $last_gene_oid ) {
                #    my $r = pop(@recs);
                #    my (
                #        $gene_oid_last,          $locus_tag_last,
                #        $gene_display_name_last, 
                #        $taxon_oid_last,         $taxon_display_name_last,
                #        @terms_last
                #      )
                #      = split( /\t/, $r );
                #    if (   $enzyme ne $enzyme_last
                #        && $locus_tag         eq $locus_tag_last
                #        && $gene_display_name eq $gene_display_name_last
                #        && $taxon_oid == $taxon_oid_last
                #        && $taxon_display_name
                #        && $taxon_display_name_last
                #        && GeneTableConfiguration::compareTwoArrays( \@terms, \@terms_last ) )
                #    {
                #        $enzyme_last .= ", $enzyme" if ( $enzyme ne '' );
                #        my $r = "$gene_oid_last\t";
                #        $r .= "$locus_tag_last\t";
                #        $r .= "$gene_display_name_last\t";
                #        $r .= "$enzyme_last\t";
                #        $r .= "$taxon_oid_last\t";
                #        $r .= "$taxon_display_name_last\t";
                #        $r .= join( "\t", @terms_last );
                #        push( @recs, $r );
                #        next;
                #    }
                #    else {
                #        push( @recs, $r );
                #    }
                #}
    
                if ( $include_metagenomes 
                && ($searchFilter eq "locus_tag_merfs" || $searchFilter eq "gene_oid_merfs") ) {
                    my $locus_tag_lc = lc($locus_tag);
                    foreach my $t (@term_list) {
                        if ( $locus_tag_lc eq ($t) ) {
    
                            #print "FindGenes::printFindGeneResults() $t matching $locus_tag<br/>\n";
                            $termFoundHash{$locus_tag_lc} = 1;
                            last;
                        }
                    }
                }
    
                my $rec = "$gene_oid\t";
                $rec .= "$locus_tag\t";
                $rec .= "$gene_display_name\t";
                #$rec .= "$enzyme\t";
                $rec .= "$taxon_oid\t";
                $rec .= "$taxon_display_name\t";
                $rec .= join( "\t", @terms );
                push( @recs, $rec );
                $last_gene_oid = $gene_oid;
    
                $count++;
                if ( $count >= $max_rows ) {
                    $trunc = 1;
                    last;
                }
        }
            $cur->finish();            
        }
    }
    if ( $contact_oid == 100546 ) {
        print "<p>*** db end time: " . currDateTime() . "<br/>\n";
    }

    ## Gene product name is special.  It is used both under
    #  "Find Genes" and "Find Functions", so we need a special label.
    my $metagFoundCnt = 0;
    if ( $include_metagenomes && !$trunc ) {
        #print "FindGenes::printFindGeneResults() include_metagenomes " . currDateTime() . "<br/>\n";

        if ( 
            $searchFilter eq "gene_display_name_iex"
            || ( $searchFilter eq 'gene_oid_merfs' && scalar(@term_list) > scalar( keys(%termFoundHash) ) )
            || ( $searchFilter eq 'locus_tag_merfs' && scalar(@term_list) > scalar( keys(%termFoundHash) ) )
          )
        {
            my %taxon_name_h;
            if ( scalar(@metaTaxons) > 0 ) {
                %taxon_name_h =
                  QueryUtil::fetchTaxonOid2NameHash( $dbh, \@metaTaxons );
            }

            my @type_list = MetaUtil::getDataTypeList( $data_type );

            if ( $searchFilter eq "gene_display_name_iex" ) {
                my $tag       = "gene_product";

                printStartWorkingDiv();

              OUTER: foreach my $toid (@metaTaxons) {
                    $toid = sanitizeInt($toid);

                    for my $data_type (@type_list) {
                        my %gene_name_h;
                        ( $count, $trunc ) =
                          MetaUtil::doGeneProdNameSearch( 1, 1, $toid,
                            $data_type, $tag, $searchTermLc, \%gene_name_h,
                            $count, $trunc, $max_rows );

                        my %genes_h;
                        foreach my $workspace_id ( keys(%gene_name_h) ) {
                            $genes_h{$workspace_id} = 1;
                        }
                        my %gene_info_h;
                        MetaUtil::getAllMetaGeneInfo( \%genes_h, '', \%gene_info_h,
                            '', '', 1 );

                        foreach my $workspace_id ( keys(%gene_name_h) ) {
                            my $r = formMetaRecord(
                                $toid,          $data_type,    $workspace_id,
                                \%taxon_name_h, \%gene_name_h, \%gene_info_h,
                                \@outputCol
                            );
                            push( @recs, $r );

                            $metagFoundCnt++;
                        }

                        if ( $count >= $max_rows ) {
                            $trunc = 1;
                            last OUTER;
                        }

                    }
                }

                printEndWorkingDiv();
            }
            elsif ( $searchFilter eq 'gene_oid_merfs' || $searchFilter eq 'locus_tag_merfs' ) {

                #due to case-sensitive
                my @term_list_norm = WebUtil::splitTerm( $searchTerm, 0, 0 );

                printStartWorkingDiv();

                if ( !$trunc
                    && scalar(@term_list) > scalar( keys(%termFoundHash) ) )
                {

                  OUTER: foreach my $toid (@metaTaxons) {
                        $toid = sanitizeInt($toid);

                        for my $data_type (@type_list) {
                            my $taxonDirFile =
                              $mer_data_dir . '/' . $toid . '/' . $data_type;
                            if ( -e $taxonDirFile ) {
                                print "Check metagenome $toid $data_type directory ...<br/>\n";

                                my ($termNotFoundArray_ref) =
                                  MerFsUtil::getTermNotFound(
                                    \@term_list_norm, \%termFoundHash );
                                my %gene_info_h;
                                MetaUtil::doGeneIdSearch( 1, $toid, $data_type, 
                                    $termNotFoundArray_ref, \%gene_info_h );

                                my %genes_h;
                                foreach my $workspace_id ( keys(%gene_info_h) )
                                {
                                    $genes_h{$workspace_id} = 1;
                                }
                                my %gene_name_h;
                                MetaUtil::getAllGeneNames( \%genes_h,
                                    \%gene_name_h, 1 );
                                #print "FindGenes::printFindGeneResults() finish MetaUtil::getAllGeneNames()<br/>\n";

                                foreach my $workspace_id ( keys(%gene_info_h) )
                                {
                                    my $r = formMetaRecord(
                                        $toid,         $data_type,
                                        $workspace_id, \%taxon_name_h,
                                        \%gene_name_h, \%gene_info_h,
                                        \@outputCol
                                    );
                                    push( @recs, $r );
                                    #print "FindGenes::printFindGeneResults() 0 pushed to recs: $r<br/>\n";

                                    my ( $t2, $d2, $oid ) =
                                      split( / /, $workspace_id );
                                    $termFoundHash{ lc($oid) } = 1;
                                    #print "FindGenes::printFindGeneResults() ".lc($oid)." added to termFoundHash<br/>\n";

                                    $metagFoundCnt++;
                                    $count++;
                                    if ( $count >= $max_rows ) {
                                        $trunc = 1;
                                        last OUTER;
                                    }
                                }
                            }
                        }
                    }
                }

                #to minimize case-sensitive issue
                #print "FindGenes::printFindGeneResults() trunc: $trunc, term_list size: ". scalar(@term_list) ."<br/>\n";
                #print "FindGenes::printFindGeneResults() trunc: $trunc, termFoundHash size: ". scalar( keys(%termFoundHash) ) ."<br/>\n";
                if ( !$trunc
                    && scalar(@term_list) > scalar( keys(%termFoundHash) ) )
                {

                    my $tag       = "gene";
                    my %gene_cnt_hash =
                      QueryUtil::fetchTaxonOid2GeneCntHash( $dbh,
                        \@metaTaxons );

                  OUTER: foreach my $toid (@metaTaxons) {
                        $toid = sanitizeInt($toid);

                        for my $data_type (@type_list) {

                            my ($termNotFoundArray_ref) =
                              MerFsUtil::getTermNotFound(
                                \@term_list_norm, \%termFoundHash );
                            
                            my $total_gene_cnt = $gene_cnt_hash{$toid};
                            my %gene_name_h;
                            ($count, $trunc) = MetaUtil::doGeneIdSearchInProdFile(
                                1,                   1,
                                $toid,               $data_type,
                                $total_gene_cnt,     $tag,                
                                $termNotFoundArray_ref,    \%termFoundHash, 
                                \%gene_name_h,       $count,              
                                $trunc,              $max_rows
                              );

                            my %genes_h;
                            foreach my $workspace_id ( keys(%gene_name_h) )
                            {
                                $genes_h{$workspace_id} = 1;
                            }
                            my %gene_info_h;
                            MetaUtil::getAllMetaGeneInfo( \%genes_h, '',
                                \%gene_info_h, '', '', 1 );

                            foreach my $workspace_id ( keys(%gene_name_h) ) {
                                my $r = formMetaRecord(
                                    $toid,         $data_type,
                                    $workspace_id, \%taxon_name_h,
                                    \%gene_name_h, \%gene_info_h,
                                    \@outputCol
                                );
                                push( @recs, $r );
                                #print "FindGenes::printFindGeneResults() 1 pushed to recs: $r<br/>\n";

                                $metagFoundCnt++;
                            }

                            if (
                                scalar(@term_list) <= scalar( keys(%termFoundHash) ) )
                            {
                                last OUTER;
                            }

                            if ( $count >= $max_rows ) {
                                $trunc = 1;
                                last OUTER;
                            }

                        }
                    }
                }

                printEndWorkingDiv();
            }
        }
        elsif ( $searchFilter eq 'gene_oid_list'
            && scalar(@meta_term_list) > 0 )
        {

            #no selection of @genomeFilterSelections for 'gene_oid_list'
            #and searching every file takes too long,
            #so such function not supported currently
        }

        #print "FindGenes::printFindGeneResults() include_metagenomes done " . currDateTime() . "<br/>\n";
    }

    if ( $metagFoundCnt == 0 && $count == 1 && scalar(@outputCol) == 0 ) {
        require GeneDetail;
        GeneDetail::printGeneDetail($last_gene_oid);
        return;
    }

    #move here to avoid "Gene Search Results" title showing on top of "Gene Detail" title
    printMainForm();
    my $title = $searchFilterName{$searchFilter};
    print "<h1>$title Search Results</h1>\n";
    print "<p>\n";
    print "Keyword: " . $searchTerm;
    if ( scalar(@metaTaxons) > 0
        && ($searchFilter eq "gene_display_name_iex" || $searchFilter eq "locus_tag_merfs" || $searchFilter eq "gene_oid_merf") ) {
        HtmlUtil::printMetaDataTypeSelection($data_type, 1);
    }
    print "</p>\n";

    if ( $count == 0 ) {
        WebUtil::printNoHitMessage();
        printStatusLine( "0 genes retrieved.", 2 );
        print end_form();
        return;
    }

    my $tm                = time();
    my $geneTaxonListFile = "geneTaxonList.$tm.$$.tab.txt";
    my $geneTaxonListPath = "$tmp_dir/$geneTaxonListFile";
    my $wfh = newWriteFileHandle( $geneTaxonListPath, "printFindGeneResults" );

    my $termIndex         = -1;
    my $scaffoldTermIndex = -1;
    my $koidIndex         = -1;

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();                                 # sort delimiter

    $it->addColSpec( "Selection", "",           "center" );
    $it->addColSpec( "Gene ID",   "number asc", "center" );
    $it->addColSpec( "Locus Tag", "asc",        "center" );
    $it->addColSpec( "Gene Product Name", "asc" );
    if ( $searchFilter eq "seed_iex" ) {
        $it->addColSpec( "SEED Product Name",   "asc" );
        $it->addColSpec( "SEED Subsystem",      "asc" );
        $it->addColSpec( "SEED Subsystem Flag", "number asc", "center" );
        $termIndex = 2;
    }
    elsif ($searchFilter ne 'gene_display_name_iex'
        && $searchFilter ne 'locus_tag_list'
        && $searchFilter ne 'locus_tag_merfs'
        && $searchFilter ne 'gene_oid_list'
        && $searchFilter ne 'gene_oid_merfs' )
    {
        my $colName = $searchFilterName{$searchFilter};
        $it->addColSpec( $colName, "asc" );
        $termIndex = 0;
    }
    if ( scalar(@outputCol) > 0 ) {
        for my $col (@outputCol) {
            $termIndex++;
            $scaffoldTermIndex = $termIndex if ( $col eq 'scaffold' );
            $koidIndex         = $termIndex if ( $col eq 'ko_id' );
            next if ( $col eq 'ko_name' );

            my $colName = GeneTableConfiguration::getColLabelSpecial($col);
            $colName = GeneTableConfiguration::getColLabel($col) if ( $colName eq '' );
            my $colAlign = GeneTableConfiguration::getColAlign($col);
            if ( $colAlign eq "num asc right" ) {
                $it->addColSpec( "$colName", "number asc", "right" );
            }
            elsif ( $colAlign eq "num desc right" ) {
                $it->addColSpec( "$colName", "number desc", "right" );
            }
            elsif ( $colAlign eq "num desc left" ) {
                $it->addColSpec( "$colName", "number desc", "left" );
            }
            elsif ( $colAlign eq "char asc left" ) {
                $it->addColSpec( "$colName", "char asc", "left" );
            }
            elsif ( $colAlign eq "char desc left" ) {
                $it->addColSpec( "$colName", "char desc", "left" );
            }
            elsif ( $colAlign eq "char asc center" ) {
                $it->addColSpec( "$colName", "char asc", "center" );
            }
            else {
                $it->addColSpec("$colName");
            }
        }
    }
    $it->addColSpec( "Genome", "asc" );

    for my $r (@recs) {
        #print "FindGenes::printFindGeneResults() r: $r<br/>\n";
        my ( $workspace_id, $locus_tag, $gene_display_name, $taxon_oid,
            $taxon_display_name, @terms )
          = split( /\t/, $r );
        if ( scalar(@terms) < $termsLength ) {
            my $diff = $termsLength - scalar(@terms);
            for ( my $i = 0 ; $i < $diff ; $i++ ) {
                push( @terms, '' );
            }
        }

        my $row;
        $row .=
          $sd . "<input type='checkbox' name='gene_oid' value='$workspace_id' />\t";

        my $data_type;
        my $gene_oid;
        if ( $workspace_id && isInt($workspace_id) ) {
            $data_type = 'database';
            $gene_oid = $workspace_id;
        }
        else {
            my @vals = split( / /, $workspace_id );
            $data_type = $vals[1];
            $gene_oid  = $vals[2];
        }

        my $gene_url;
        if ( $data_type eq 'database' ) {
            $gene_url =
                "$main_cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid";
        }
        else {
            $gene_url =
                "$main_cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&data_type=$data_type"
              . "&taxon_oid=$taxon_oid&gene_oid=$gene_oid";
        }
        $row .= $workspace_id . $sd . "<a href='$gene_url'>$gene_oid</a>\t";

        my $locusMatchText = $locus_tag;
        if ( $searchFilter eq 'locus_tag_list' || $searchFilter eq 'locus_tag_merfs') {
            $locusMatchText = hiliteWord($locus_tag);
        }
        $row .= $locus_tag . $sd . "$locusMatchText\t";

        my $geneName = $gene_display_name;
        my $nameMatchText = $geneName;
        if ( $searchFilter eq 'gene_display_name_iex' ) {
            $nameMatchText = highlightMatchHTML2( $geneName, $searchTerm );
        }
        $row .= $geneName . $sd . "$nameMatchText\t";

        my $searchTermPart_u = $searchTermLiteral;
        if (   $searchFilter ne "gene_symbol_list"
            && $searchFilter ne "genbank_list"
            && $searchFilter ne "giNo_list"
            && $searchFilter ne "obsolete_flag_ex"
            && $searchFilter ne "is_pseudogene_ex" )
        {

            #gene symbol, locus tag, Genebank accession IDs contains '_'
            my ( $searchTermPartTemp, @junk ) =
              split( /[%_]/, $searchTermLiteral );
            $searchTermPart_u = $searchTermPartTemp;
        }
        $searchTermPart_u =~ tr/a-z/A-Z/;

        my $cnt     = 0;
        my $matched = 0;
        if (   $searchFilter eq 'gene_display_name_iex'
            || $searchFilter eq 'locus_tag_list'
            || $searchFilter eq 'locus_tag_merfs'
            || $searchFilter eq 'gene_oid_list'
            || $searchFilter eq 'gene_oid_merfs' )
        {
            $matched = 1;
        }
        for my $t (@terms) {
            if ( $koidIndex >= 0 && $cnt == $koidIndex + 1 ) {   #bypass ko_name
                $cnt++;
                next;
            }
            elsif ( !( $koidIndex >= 0 && $cnt == $koidIndex + 2 ) )
            {    #bypass ko definition for reason of additional special care
                if ( $t eq '' ) {
                    $row .= $sd . "\t";
                    $cnt++;
                    next;
                }
            }

            #print "FindGenes::printFindGeneResults \$scaffoldTermIndex: $scaffoldTermIndex, \$cnt: $cnt, \$t: $t<br/>\n";
            if ( $koidIndex >= 0 && $koidIndex == $cnt ) {
                my $koid_url = $kegg_orthology_url . $t;
                $koid_url = alink( $koid_url, $t );
                $row .= $t . $sd . $koid_url . "\t";
            }
            elsif ( $koidIndex >= 0 && $cnt == $koidIndex + 2 )
            {    #do something at ko definition
                my $ko_name     = $terms[ $koidIndex + 1 ];
                my $ko_name_def = $ko_name . "; " . $t;
                if ( $ko_name eq '' && $t eq '' )
                {    #special care at ko definition
                    $row .= $sd . "\t";
                }
                else {
                    my $koid   = $terms[$koidIndex];
                    my $ko_url =
                        "main.cgi?section=KeggPathwayDetail&page=keggModulePathway&ko_id=$koid&ko_name=$ko_name&ko_def=$t&gene_oid=$gene_oid&taxon_oid=$taxon_oid";
                    $ko_url = alink( $ko_url, $ko_name_def );
                    $row .= $ko_name_def . $sd . $ko_url . "\t";
                }
            }
            elsif ($scaffoldTermIndex >= 0
                && $scaffoldTermIndex == $cnt
                && $t ne '' )
            {
                my $scaffold_url;
                if ( $data_type eq 'database' && isInt($t) ) {
                    $scaffold_url =
                        "$main_cgi?section=ScaffoldGraph&page=preScaffoldGraph&scaffold_oid=$t&marker_gene=$gene_oid";
                }
                else {
                    $scaffold_url =
                        "$main_cgi?section=MetaDetail"
                      . "&page=metaScaffoldDetail&scaffold_oid=$t"
                      . "&taxon_oid=$taxon_oid&data_type=$data_type";
                }
                $scaffold_url = alink( $scaffold_url, $t );
                $row .= $t . $sd . $scaffold_url . "\t";
            }
            else {
                my $matchText = $t;
                if ( $matched == 0 ) {
                    my $t_up = $t;
                    $t_up =~ tr/a-z/A-Z/;
                    my $idx = index( $t_up, $searchTermPart_u );

                    if (
                        $idx >= 0
                        || (   $searchFilter eq "gene_symbol_list"
                            && $searchTermPart_u =~ /$t_up/ )
                        || (   $searchFilter eq "genbank_list"
                            && $searchTermPart_u =~ /$t_up/ )
                        || (   $searchFilter eq "giNo_list"
                            && $searchTermPart_u =~ /$t_up/ )
                        || (   $searchFilter eq "obsolete_flag_ex"
                            && $searchTermPart_u =~ /$t_up/ )
                        || (   $searchFilter eq "is_pseudogene_ex"
                            && $searchTermPart_u =~ /$t_up/ )
                      )
                    {

                        if (   $searchFilter eq "gene_symbol_list"
                            || $searchFilter eq "genbank_list"
                            || $searchFilter eq "giNo_list"
                            || $searchFilter eq "obsolete_flag_ex"
                            || $searchFilter eq "is_pseudogene_ex" )
                        {
                            $matchText = hiliteWord($t_up);
                        }
                        else {
                            $matchText =
                              highlightMatchHTML2( $t, $searchTermLiteral );
                        }
                        $matched = 1;
                    }
                }
                $row .= "$t" . $sd . "$matchText\t";
            }
            $cnt++;
        }

        my $taxon_url;
        if ( $data_type eq 'database' ) {
            $taxon_url =
                "$main_cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        else {
            $taxon_url =
                "$main_cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$taxon_oid";
        }
        $row .=
            $taxon_display_name . $sd
          . "<a href='$taxon_url'>"
          . escHtml($taxon_display_name)
          . "</a>\t";

        $it->addRow($row);

        print $wfh "$gene_oid\t";
        print $wfh "$taxon_oid\n";
    }
    close $wfh;
    
    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    print "</p>\n";
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    if ( $count <= $max_rows && !$trunc ) {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    else {
        printTruncatedStatus($max_rows);
    }
    print hiddenVar( "currentNavHilite", "GeneSearch" );

    print end_form();
}

sub getValidTaxons {
    my ( $dbh, $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref ) = @_;
    
    my ( $sql, @bindList ) = getTaxonSql( $taxonClause, 
        $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref );
    #print "FindGenes::getValidTaxons() sql: $sql<br/>\n";
    #print "FindGenes::getValidTaxons() bindList: @bindList<br/>\n";
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my %validTaxons;
    for ( ; ; ) {
        my ( $taxon_oid )
          = $cur->fetchrow();
        last if !$taxon_oid;
        
        $validTaxons{ $taxon_oid } = $taxon_oid;
    }
    $cur->finish();            

    return %validTaxons;
}

sub searchWebserviceSolr {
    my ( $solr, $searchTermLc, $max_rows, $count, $trunc, $recs_ref, 
     $done_href, $validTaxons_href, $genomeFilterSelections_ref,
     $searchType ) = @_;

    require WebService::Solr::Query;
    
    my $query;
    my $max_rows_used = $max_rows + 1000;
    if ( $searchType == 1 ) {
        my @termToks = split( / /, $searchTermLc );
        if ( scalar(@termToks) > 1 ) {
            my $word;
            for my $tok (@termToks) {
                my $word_len = length($word); 
                my $tok_len = length($tok); 
                if ( $word_len < $tok_len ) {
                    $word = $tok;
                }
            }
            $query = "*$word*";
            $max_rows_used = $max_rows * 5;
        }
        else {
            $query = "*$searchTermLc*";
        }
    }
    elsif ( $searchType == 2 ) {
        $query = WebService::Solr::Query->new( { gene_display_name => $searchTermLc } );
    }
    
    #my $query = "*$searchTermLc*";
    #my $domainChoice = OracleUtil::getDomainChoice();
    #print "domainChoice: $domainChoice<br/>\n";
    #if ( $domainChoice ne "All" && $domainChoice ne "" ) {
    #    $query = WebService::Solr::Query->new( { gene_display_name => $searchTermLc, domain => $domainChoice } );
    #    #$query = WebService::Solr::Query->new( { '*' => \'*', domain => $domainChoice } );
    #}
    #else {
    #    $query = "*$searchTermLc*";
    #    #$query = WebService::Solr::Query->new( { gene_display_name => $searchTermLc } );
    #}
    
    #below code not working
    #my %options = {
    #   fl => 'gene_oid,locus_tag,gene_display_name,taxon,taxon_display_name,domain',
    #   df => 'gene_display_name',
    #   rows => $max_rows,
    #};            
    my %options = {};
    if ( $searchType == 1 ) {
        $options{df} = 'gene_display_name';
    }
    $options{start} = 0;
    $options{rows} = $max_rows_used;

    my @taxons_valid = keys %$validTaxons_href;
    if ( scalar(@$genomeFilterSelections_ref) > 0 && 
     scalar(@taxons_valid) <= 1000) {
        $options{fq} = [
        WebService::Solr::Query->new( { taxon => \@taxons_valid } ),
            ];
    }
    else {
        my $domainChoice = OracleUtil::getDomainChoice();
        #print "domainChoice: $domainChoice<br/>\n";
        if ( $domainChoice ne "All" && $domainChoice ne "" ) {
            if ( !$user_restricted_site ) {
                if ( !$include_metagenomes ) {
                    $options{fq} = [
            WebService::Solr::Query->new( {obsolete_flag => 'No'} ),
            WebService::Solr::Query->new( {is_public => 'Yes'} ),
            WebService::Solr::Query->new( {genome_type => 'isolate'} ),
            WebService::Solr::Query->new( {domain => $domainChoice} ),
                    ];
                }
                else {
                    $options{fq} = [
            WebService::Solr::Query->new( {obsolete_flag => 'No'} ),
            WebService::Solr::Query->new( {is_public => 'Yes'} ),
            WebService::Solr::Query->new( {domain => $domainChoice} ),
                    ];            
                }
            }
            else {
                if ( !$include_metagenomes ) {
                    $options{fq} = [
            WebService::Solr::Query->new( { obsolete_flag => 'No' } ),
            WebService::Solr::Query->new( { genome_type => 'isolate' } ),
            WebService::Solr::Query->new( { domain => $domainChoice } ),
                        ];
                }
                else {
                    $options{fq} = [
            WebService::Solr::Query->new( { obsolete_flag => 'No' } ),
            WebService::Solr::Query->new( { domain => $domainChoice } ),
                        ];            
                }
            }
        }
        else {
            if ( !$user_restricted_site ) {
                if ( !$include_metagenomes ) {
                    $options{fq} = [
            WebService::Solr::Query->new( { obsolete_flag => 'No' } ),
            WebService::Solr::Query->new( { is_public => 'Yes' } ),
            WebService::Solr::Query->new( { genome_type => 'isolate' } ),
                        ];
                }
                else {
                    $options{fq} = [
            WebService::Solr::Query->new( { obsolete_flag => 'No' } ),
            WebService::Solr::Query->new( { is_public => 'Yes' } ),
                        ];            
                }
            }
            else {
                if ( !$include_metagenomes ) {
                    $options{fq} = [
            WebService::Solr::Query->new( { obsolete_flag => 'No' } ),
            WebService::Solr::Query->new( { genome_type => 'isolate' } ),
                        ];
                }
                else {
                    $options{fq} = [
            WebService::Solr::Query->new( { obsolete_flag => 'No' } ),
                        ];
                }
            }
        } 
    }
    #print Dumper(\%options)."<br/>\n";

    my $response = $solr->search( $query, \%options );
    my $numfound = $response->content->{response}->{numFound};
    #print "Your search ($query) found " . $numfound . " results.<br/>\n";

    ( $count, $trunc ) = processWebserviceSolrResults( $response, $searchTermLc,
        $max_rows, $count, $trunc, $recs_ref, $done_href, $validTaxons_href );

    if ( $count < $max_rows && !$trunc ) {
        my $page = $response->pager;
        #print "Total entries:", $page->total_entries, "<br/>\n";
        #print "Entries per page:", $page->entries_per_page, "<br/>\n";
        #print "First page: ", $page->first_page, "<br/>\n";
        #print "Last page: ", $page->last_page, "<br/>\n";
        #print "Current page number: ", $page->current_page, "<br/>\n";
        #print "First entry on page: ", $page->first, "<br/>\n";
        #print "Last entry on page: ", $page->last, "<br/>\n";

        my $firstEntryOnFirstPage = $page->first;
        my $entriesPerPage = $page->entries_per_page;
        while ( $count < $max_rows && !$trunc && $page->next_page ) {
            my $nextPageNumber = $page->next_page;
            #print "Next page number: $nextPageNumber<br/>\n";
            
            $options{start} = $entriesPerPage * ($nextPageNumber - 1);
            $response = $solr->search( $query, \%options );
            ( $count, $trunc ) = processWebserviceSolrResults( $response, $searchTermLc,
                $max_rows, $count, $trunc, $recs_ref, $done_href, $validTaxons_href );
            $page = $response->pager;
        }
    }
             
    return ( $count, $trunc );
}

sub processWebserviceSolrResults {
    my ( $response, $searchTermLc, $max_rows, $count, $trunc, $recs_ref, $done_href, $validTaxons_href ) = @_;

    my @hits = $response->docs;              
    #print "Your search found " . ( $#hits + 1 ) . " document(s).<br/>\n";
            
    foreach my $doc ( @hits ) {
        my $gene_oid = $doc->value_for( 'gene_oid' );
        if ( !$gene_oid || $done_href->{$gene_oid} ) {
            next;
        }

        my $taxon_oid = $doc->value_for( 'taxon' );
        if ( !$taxon_oid || !$validTaxons_href->{$taxon_oid} ) {
            next;
        }

        my $locus_tag = $doc->value_for( 'locus_tag' );
        my $gene_display_name = $doc->value_for( 'gene_display_name' );
        my $taxon_display_name = $doc->value_for( 'taxon_display_name' );
        my $domain = $doc->value_for( 'domain' );

        if ( $gene_display_name =~ /$searchTermLc/i ) {
            $done_href->{$gene_oid} = 1;
            
            my $r = "$gene_oid\t";
            $r .= "$locus_tag\t";
            $r .= "$gene_display_name\t";
            $r .= "\t";
            $r .= "$taxon_oid\t";
            $r .= "$taxon_display_name\t";
            #not implemented
            #$r .= join( "\t", @terms_last );
            #print "r: $r<br/>\n";
            push( @$recs_ref, $r );
                
            $count++;
            if ( $count >= $max_rows ) {
                $trunc = 1;
                last;
            }                    
        }
                
    }            

    return ( $count, $trunc );

}

sub hasMetaDataInField {
    my (@outputCol) = @_;

    foreach my $c (@outputCol) {
        if (   $c =~ /locus_type/i
            || $c =~ /start_coord/i
            || $c =~ /end_coord/i
            || $c =~ /strand/i
            || $c =~ /dna_seq_length/i
            || $c =~ /aa_seq_length/i
            || $c =~ /scaffold/i
            || $c =~ /scaffold_oid/i )
        {
            return 1;
        }
    }
    return 0;
}

sub formMetaRecord {
    my ( $toid, $data_type, $workspace_id, $taxon_name_href,
        $gene_product_info_href, $gene_info_href, $outputCol_aref )
      = @_;

    my $taxon_display_name = $taxon_name_href->{$toid};
    my ( $gene_product_name, $prod_src ) =
      split( /\t/, $gene_product_info_href->{$workspace_id} );
    if (!$gene_product_name) {
        $gene_product_name = 'hypothetical protein';
    }
    my ( $tid2, $dType2, $goid ) = split( / /, $workspace_id );

    my (
        $locus_type,   $locus_tag, $gene_display_name,
        $start_coord,  $end_coord, $strand,
        $scaffold_oid, $tid2,      $dtype2
      )
      = split( /\t/, $gene_info_href->{$workspace_id} );

    my $r = "$workspace_id\t";
    $r .= "$locus_tag\t";
    $r .= "$gene_product_name\t";
    #$r .= "\t";
    $r .= "$toid\t";
    my $taxon_name = HtmlUtil::appendMetaTaxonNameWithDataType( $taxon_display_name, $data_type );
    $r .= "$taxon_name\t";
    if (   defined($outputCol_aref)
        && $outputCol_aref ne ''
        && scalar(@$outputCol_aref) > 0 )
    {
        foreach my $c (@$outputCol_aref) {
            if ( $c =~ /locus_type/i ) {
                $r .= "$locus_type\t";
            }
            elsif ( $c =~ /start_coord/i ) {
                $r .= "$start_coord\t";
            }
            elsif ( $c =~ /end_coord/i ) {
                $r .= "$end_coord\t";
            }
            elsif ( $c =~ /strand/i ) {
                $r .= "$strand\t";
            }
            elsif ( $c =~ /dna_seq_length/i ) {
                my $dna_seq_length = $end_coord - $start_coord + 1;
                $r .= "$dna_seq_length\t";
            }
            elsif ( $c =~ /aa_seq_length/i ) {
                my $dna_seq_length = $end_coord - $start_coord + 1;
                my $aa_seq_length  = $dna_seq_length / 3;
                $r .= "$aa_seq_length\t";
            }
            elsif ( $c =~ /scaffold/i || $c =~ /scaffold_oid/i ) {
                $r .= "$scaffold_oid\t";
            }
            else {
                $r .= "\t";
            }
        }
    }

    return $r;
}

sub getGeneDisplayNameSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_txs_ref, $bindList_ur_ref )
      = @_;

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name
           $outColClause
       from gene g
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where contains(g.gene_display_name, ?) > 0
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("%$searchTermLc%");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref,
        $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getTaxonSql {
    my ( $taxonClause, $rclause, $imgClause, $bindList_txs_ref, $bindList_ur_ref )
      = @_;

    my $sql = qq{
       select tx.taxon_oid
       from taxon tx
       where 1 = 1
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ();
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref,
        $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getImgAnnotationSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_txs_ref, $bindList_ur_ref )
      = @_;

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    my $sclause;
    if ( $contact_oid > 0 && $super_user ne "Yes" ) {
        $sclause = "and c.contact_oid = ?";
    }

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name, 
           gmf.product_name||' '||gmf.prot_desc||' (MyIMG:'||c.username||')' $outColClause
       from gene_myimg_functions gmf
       left join contact c 
           on gmf.modified_by = c.contact_oid
       left join gene g 
           on gmf.gene_oid = g.gene_oid
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where ( lower( gmf.product_name ) like ?
            or lower( gmf.ec_number ) like ?
            or lower( gmf.prot_desc ) like ?
       )
       $sclause
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql =
      ( "%$searchTermLc%", "%$searchTermLc%", "%$searchTermLc%" );
    if ( $contact_oid > 0 && $super_user ne "Yes" ) {
        push( @bindList_sql, "$contact_oid" );
    }
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref,
        $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGeneSymbolListSql {
    my ( $term_str, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_ur_ref )
      = @_;

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name, 
           g.gene_symbol $outColClause
       from gene g
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where lower(g.gene_symbol) in ($term_str)
       $rclause
       $imgClause
    };

    my @bindList = ();
    processBindList( \@bindList, undef, undef, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getLocusTagListSql {
    my ( $term_str, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_ur_ref )
      = @_;

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name
           $outColClause
       from gene g
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where lower(g.locus_tag) in ($term_str)
       $rclause
       $imgClause
    };

    my @bindList = ();
    processBindList( \@bindList, undef, undef, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGeneBankListSql {
    my ( $term_str, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_ur_ref )
      = @_;

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name, 
           g.protein_seq_accid $outColClause
       from gene g
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where g.dt_protein_seq_accid_lc in ($term_str)
       $rclause
       $imgClause
    };

    my @bindList = ();
    processBindList( \@bindList, undef, undef, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGINumberSql {
    my ( $term_str, $rclause, $imgClause, $outColClause, $keggJoinClause,
        $bindList_ur_ref )
      = @_;

    my $sql = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name, 
            tx.taxon_oid, tx.taxon_display_name,
            gel.id $outColClause
        from gene_ext_links gel
        left join gene g 
            on gel.gene_oid = g.gene_oid
        join taxon tx
           on g.taxon = tx.taxon_oid
        $keggJoinClause
        where gel.id in ( $term_str )
        and gel.db_name = ?
        $rclause
        $imgClause
    };

    my @bindList = ('GI');
    processBindList( \@bindList, undef, undef, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGeneOidListSql {
    my ( $dbh, $term_str, $rclause, $imgClause, $outColClause, $keggJoinClause,
        $bindList_ur_ref )
      = @_;

    $term_str = validateGeneOids( $dbh, $term_str );

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name
           $outColClause
       from gene g
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where g.gene_oid in ( $term_str )
       $rclause
       $imgClause
    };

    my @bindList = ();
    processBindList( \@bindList, undef, undef, $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub validateGeneOids {
    my ( $dbh, $term_str ) = @_;

    my $sql = getGeneReplacementSql($term_str);
    my $cur = execSql( $dbh, $sql, $verbose );

    my @gene_oids = ();
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    my @term_list = WebUtil::splitTerm( $term_str, 1, 0 );
    if ( scalar(@gene_oids) ) {
        push( @term_list, @gene_oids );
    }
    $term_str = join( ',', @term_list );

    return ($term_str);
}

sub getImgSynonymsInexactSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_txs_ref, $bindList_ur_ref )
      = @_;

#    my $sql = qq{
#        WITH
#        with_term_synonym AS
#        (
#            select gif.gene_oid, it.term ts
#            from img_term it, dt_img_term_path dtp, gene_img_functions gif
#            where (lower( it.term ) like ?)
#            and it.term_oid = dtp.term_oid
#            and dtp.map_term = gif.function
#            union
#            select gif.gene_oid, '(Synonym: '||its.synonyms||')' ts
#            from img_term_synonyms its, dt_img_term_path dtp, gene_img_functions gif
#            where (lower( its.synonyms ) like ?)
#            and its.term_oid = dtp.term_oid
#            and dtp.map_term = gif.function
#        )
#        select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
#           tx.taxon_oid, tx.taxon_display_name, 
#           wts.ts $outColClause
#        from with_term_synonym wts, gene g, taxon tx
#        $keggJoinClause
#        where wts.gene_oid = g.gene_oid
#        and g.taxon = tx.taxon_oid
#        $taxonClause
#        $rclause
#        $imgClause
#    };
    my $sql = qq{
        WITH
        with_term_synonym AS
        (
            select gif.gene_oid, it.term ts
            from img_term it, gene_img_functions gif
            where (lower( it.term ) like ?)
            and it.term_oid = gif.function
            union
            select gif.gene_oid, '(Synonym: '||its.synonyms||')' ts
            from img_term_synonyms its, gene_img_functions gif
            where (lower( its.synonyms ) like ?)
            and its.term_oid = gif.function
        )
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name, 
           wts.ts $outColClause
        from with_term_synonym wts, gene g, taxon tx
        $keggJoinClause
        where wts.gene_oid = g.gene_oid
        and g.taxon = tx.taxon_oid
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ( "%$searchTermLc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref,
        $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getGeneSeedSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_txs_ref, $bindList_ur_ref )
      = @_;

    my $sql = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
            tx.taxon_oid, tx.taxon_display_name, 
            gs.product_name, gs.subsystem, gs.subsystem_flag
            $outColClause
        from gene_seed_names gs
        left join gene g 
            on gs.gene_oid = g.gene_oid
        join taxon tx
            on g.taxon = tx.taxon_oid
        $keggJoinClause
        where (lower( gs.product_name ) like ? or lower( gs.subsystem ) like ? )
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList_sql = ( "%$searchTermLc%", "%$searchTermLc%" );
    my @bindList = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref,
        $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getObsoleteExactSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_txs_ref, $bindList_ur_ref )
      = @_;

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name, 
           g.obsolete_flag $outColClause
       from gene g
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where lower(g.obsolete_flag) = ?
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$searchTermLc");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref,
        $bindList_ur_ref );

    return ( $sql, @bindList );
}

sub getPseudogeneExactSql {
    my ( $searchTermLc, $taxonClause, $rclause, $imgClause, $outColClause,
        $keggJoinClause, $bindList_txs_ref, $bindList_ur_ref )
      = @_;

    my $sql = qq{
       select distinct g.gene_oid, g.locus_tag, g.gene_display_name,
           tx.taxon_oid, tx.taxon_display_name, 
           g.is_pseudogene $outColClause
       from gene g
       join taxon tx
           on g.taxon = tx.taxon_oid
       $keggJoinClause
       where lower(g.is_pseudogene) = ?
       $taxonClause
       $rclause
       $imgClause
    };

    my @bindList_sql = ("$searchTermLc");
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_txs_ref,
        $bindList_ur_ref );

    return ( $sql, @bindList );
}

############################################################################
# printProteinRegExResults - Print protein regular expression search
#    results for amino acid matches.
############################################################################
sub printProteinRegExResults {
    my $searchTerm             = param("searchTerm");
    #my @genomeFilterSelections =
    #  OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");

    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm( $searchTerm, 1 );
    $searchTerm =~ tr/a-z/A-Z/;
    if ( $searchTerm =~ /"/ || $searchTerm =~ /'/ ) {
        webError("Quote character is not allowed in expression.");
        return;
    }

    # check regex syntax
    my $regex = eval { qr/$searchTerm/ };
    if ($@) {
        webError("Invalid regular expression <br> $searchTerm <br>\n");
        return;           
    }


    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    if ( !blankStr($maxGeneListResults) ) {
        $max_rows = $maxGeneListResults;
    }

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind
      ( $dbh, "tx.taxon_oid", \@genomeFilterSelections );

    my ( $rclause, @bindList_ur ) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');

    my $sql = qq{
       select tx.taxon_oid, tx.taxon_display_name
       from taxon tx,  taxon_stats ts
       where tx.taxon_oid = ts.taxon_oid
       and ts.cds_genes > 0
       $taxonClause
       $rclause
       $imgClause
       order by tx.taxon_display_name
    };

    my @bindList = ();
    processBindList( \@bindList, undef, \@bindList_txs, \@bindList_ur );
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @taxon_oids = ();
    my %taxonOid2Name;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @taxon_oids, $taxon_oid );
        $taxonOid2Name{$taxon_oid} = $taxon_display_name;
        if ( $taxon_display_name eq "" ) {
            warn(
                "printProteinRegExResults $taxon_oid has empty display_name\n");
        }
    }
    $cur->finish();

    printMainForm();
    print "<h1>Protein Pattern Search Results</h1>\n";

    my $count          = 0;
    my $truncated      = 0;
    my $anyMissingFile = 0;
    my @resultRows;

    printStartWorkingDiv();
    for my $taxon_oid (@taxon_oids) {
        webLog "Regex on proteins for taxon_oid=$taxon_oid\n"
          if $verbose >= 1;
        my $old_count = scalar(@resultRows);

        # --es 05/17/08 Use perl regular expressions.
        $truncated =
          printProteinPerlRegExResultsForTaxon( $dbh, $taxon_oid, $searchTerm,
            $max_rows, \@resultRows );
        if ( $truncated == 2 ) {
            $anyMissingFile = 2;
            $truncated      = 0;
        }
        my $new_count = scalar(@resultRows);
        my $count     = $new_count - $old_count;
        if ( $count > 0 ) {
            my $taxon_display_name = $taxonOid2Name{$taxon_oid};
            print "$count genes retrieved for "
              . escHtml($taxon_display_name)
              . "<br/>\n";
        }
        last if $truncated;
    }
    printEndWorkingDiv();
    #$dbh->disconnect();

    if ( scalar(@resultRows) == 0 ) {
        WebUtil::printNoHitMessage();
        printStatusLine( "0 genes retrieved", 2 );
        print end_form();
        return;
    }
    print hiddenVar( "currentNavHilite", "GeneSearch" );
    my $tm                = time();
    my $geneTaxonListFile = "geneTaxonList.$tm.$$.tab.txt";
    my $geneTaxonListPath = "$tmp_dir/$geneTaxonListFile";

    my $wfh =
      newWriteFileHandle( $geneTaxonListPath, "printProteinRegExResults" );

    my $it = new InnerTable( 1, "ProteinPattern$$", "ProteinPattern", 3 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec("Selection");
    $it->addColSpec( "Gene ID",      "number asc",  "left" );
    $it->addColSpec( "Product Name", "char asc",    "left" );
    $it->addColSpec( "Genome",       "char asc",    "left" );
    $it->addColSpec( "Start",        "number desc", "right" );
    $it->addColSpec( "End",          "number desc", "right" );
    $it->addColSpec( "Total<br/>Sequence<br/>Length<br/>(aa)",
        "number desc", "right" );
    $it->addColSpec( "Amino Acid Match", "char asc", "left" );
    $it->addColSpec("Match On Sequence");

    my $count = 0;
    for my $rr (@resultRows) {
        my ( $gene_oid, $match, $gene_display_name, $taxon_oid, $genome,
            $start_idx, $end_idx, $seq_length )
          = split( /\t/, $rr );
        my $row;
        $count++;
        $row .=
          $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' />\t";
        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        $row .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $row .= $gene_display_name . $sd . escHtml($gene_display_name) . "\t";
        $row .= $genome . $sd . escHtml($genome) . "\t";
        $row .= $start_idx . $sd . $start_idx . "\t";
        $row .= $end_idx . $sd . $end_idx . "\t";
        $row .= $seq_length . $sd . $seq_length . "\t";
        $row .=
          $match . $sd . "<span style='color:green;'>$match</span>" . "\t";
        $row .=
          "_____" . $sd
          . alignImage( $start_idx, $end_idx, $seq_length ) . "\t";

        $it->addRow($row);
        print $wfh "$gene_oid\t";
        print $wfh "$taxon_oid\n";
    }
    close $wfh;

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ( !$truncated ) {
        printStatusLine( "$count genes retrieved", 2 );
    }
    else {
        printTruncatedStatus($max_rows);
    }
    webLog "Some data file(s) missing.  See error log.\n"
      if $anyMissingFile && $verbose >= 1;
    print "<br/>\n";
    WebUtil::printHint("Only first hit on the sequence is shown.");
    print end_form();

}

############################################################################
# printProteinRegExResultsForTaxon - Print results for one taxon.
#   Return and accumulate count of matches.
# Below function is not used - 08/08/2012
############################################################################
sub printProteinRegExResultsForTaxon {
    my ( $dbh, $taxon_oid, $searchTerm, $max_rows, $resultRows_ref ) = @_;

    ## Read in ID's.
    my $inIdPath = "$taxon_faa_dir/$taxon_oid.faa.id.txt";
    my $rfh      =
      newReadFileHandle( $inIdPath, "printProteinRegExResultsForTaxon" );
    my @all_gene_oids;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @all_gene_oids, $s );
    }
    close $rfh;

    ## Grep sequence
    my $inSeqPath = "$taxon_faa_dir/$taxon_oid.faa.seq.txt";
    if ( !-e $inSeqPath ) {
        warn("printProteinRegExResultsForTaxon: cannot find '$inSeqPath'\n");
        return 0;
    }
    $inSeqPath = checkPath($inSeqPath);
    ## Untaint
    $searchTerm =~ tr/a-z/A-Z/;
    $searchTerm =~ /([A-Z\.\^\$,\*\\\(\)\[\]]+)/;
    $searchTerm = $1;
    WebUtil::unsetEnvPath();
    my $cmd = "$grep_bin -n -o -h '$searchTerm' $inSeqPath";
    webLog "+ $cmd\n" if $verbose >= 1;
    my $cfh = newCmdFileHandle( $cmd, "printProteingRegExResultsForTaxon" );
    my @recs;
    my $truncated = 0;

    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( scalar(@$resultRows_ref) > $max_rows ) {
            $truncated = 1;
            last;
        }
        if ( scalar(@recs) > $max_batch ) {
            flushRegExBatch( $dbh, $taxon_oid, \@recs, $resultRows_ref );
            @recs = ();
        }
        my ( $lineNo, $matchx ) = split( /:/, $s );
        next if blankStr($matchx);
        my $gene_oid = $all_gene_oids[ $lineNo - 1 ];
        if ( blankStr($gene_oid) ) {
            webLog "printProteingRegExResultsForTaxon: "
              . "no gene_oid for lineNo=$lineNo\n";
        }
        my $r = "$gene_oid\t";
        $r .= "$matchx";
        push( @recs, $r );
    }
    close $cfh;
    WebUtil::unsetEnvPath();
    flushRegExBatch( $dbh, $taxon_oid, \@recs, $resultRows_ref )
      if scalar(@recs) > 0;
    return $truncated;
}

############################################################################
# printProteinPerlRegExResultsForTaxon - Print results for one taxon.
#   Return and accumulate count of matches.  This uses perl regex's.
############################################################################
sub printProteinPerlRegExResultsForTaxon {
    my ( $dbh, $taxon_oid, $searchTerm, $max_rows, $resultRows_ref ) = @_;

    ## Read in ID's.
    my $inIdPath = "$taxon_faa_dir/$taxon_oid.faa.id.txt";
    if ( !-e $inIdPath ) {
        warn("printProteinPerlRegExResultForTaxon: cannot find '$inIdPath'\n");
        return 2;
    }
    my $rfh =
      newReadFileHandle( $inIdPath, "printProteinPerlRegExResultsForTaxon" );
    my @all_gene_oids;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @all_gene_oids, $s );
    }
    close $rfh;

    ## Grep sequence
    my $inSeqPath = "$taxon_faa_dir/$taxon_oid.faa.seq.txt";
    $inSeqPath = checkPath($inSeqPath);
    my $rfh =
      newReadFileHandle( $inSeqPath, "printProteinPerlRegExResultsForTaxon" );
    my $idx = 0;
    my @recs;
    my $truncated = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        if ( scalar(@$resultRows_ref) > $max_rows ) {
            $truncated = 1;
            last;
        }
        $s =~ /($searchTerm)/;
        my $matchx    = $1;
        my $matchxLen = length($matchx);
        my $matchxIdx = index( $s, $matchx );
        if ( $matchx ne "" && $matchxIdx >= 0 ) {
            my $gene_oid = $all_gene_oids[$idx];
            my $r        = "$gene_oid\t";
            $r .= "$matchx";
            push( @recs, $r );
        }
        $idx++;
    }
    close $rfh;
    my @batch;
    for my $r (@recs) {
        if ( scalar(@batch) > 500 ) {
            flushRegExBatch( $dbh, $taxon_oid, \@batch, $resultRows_ref );
            @batch = ();
        }
        push( @batch, $r );
    }
    flushRegExBatch( $dbh, $taxon_oid, \@batch, $resultRows_ref )
      if scalar(@batch) > 0;
    return $truncated;
}

############################################################################
# flushRegExBatch - Flush regular expression output batch.
############################################################################
sub flushRegExBatch {
    my ( $dbh, $taxon_oid, $recs_ref, $resultRows_ref ) = @_;
    my @gene_oids;
    my %geneOid2Match;
    for my $r (@$recs_ref) {
        my ( $gene_oid, $match ) = split( /\t/, $r );
        push( @gene_oids, $gene_oid );
        $geneOid2Match{$gene_oid} = $match;
    }
    my $gene_oid_str = join( ',', @gene_oids );
    my $sql          = qq{
       select g.gene_oid, g.gene_display_name, 
          tx.taxon_oid, tx.taxon_display_name, g.aa_residue
       from taxon tx, gene g
       where g.gene_oid in( $gene_oid_str )
       and g.taxon = tx.taxon_oid
       and tx.taxon_oid = ?  
    };
    my @bindList = ("$taxon_oid");

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my %geneOid2Seq;
    for ( ; ; ) {
        my (
            $gene_oid,           $gene_display_name, $taxon_oid,
            $taxon_display_name, $aa_residue
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        
        my $r = "$gene_oid\t";
        $r .= "$gene_display_name\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        push( @recs, $r );
        $geneOid2Seq{$gene_oid} = $aa_residue;
    }
    $cur->finish();
    my %geneDone;
    my $pr;
    for my $r (@recs) {
        my ( $gene_oid, $gene_display_name, $taxon_oid, $taxon_display_name ) =
          split( /\t/, $r );
        next if $geneDone{$gene_oid} ne "";
        my $r = "$gene_oid\t";

        my $match      = $geneOid2Match{$gene_oid};
        my $seq        = $geneOid2Seq{$gene_oid};
        my $seq_length = length($seq);
        my $start_idx  = index( $seq, $match ) + 1;
        my $end_idx    = $start_idx + length($match) - 1;
        if ( length($match) > $max_seq_display ) {
            $match = substr( $match, 0, $max_seq_display - 3 ) . "...";
        }
        $r .= "$match\t";
        $r .= "$gene_display_name\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$start_idx\t";
        $r .= "$end_idx\t";
        $r .= "$seq_length";

        push( @$resultRows_ref, $r );
        $geneDone{$gene_oid} = 1;
    }
}

############################################################################
# printPageHint - Show hint text for this page.
############################################################################
sub printPageHint {
    WebUtil::printHint(
        qq{
          All searches treat the keyword as a substring (a word or part of a word).
          <br />
          The search should contain some alphanumeric characters.<br/>
          Inexact searches may use matching metacharacters.<br/>
          Use an underscore (_) as a single-character wildcard. <br />
          Use % to match zero or more characters.  <br />
          All matches are case insensitive except indicated. <br />
          Very general searches may be slow.<br/>
          Hold down control key (or command key in the case
          of the Mac) to select multiple genomes.<br/>
          Protein patterns are specified
          <a href='http://en.wikipedia.org/wiki/Regular_expression'>Perl
          regular expressions</a>.<br/>
        }
    );

    # Old
    #<a href='http://perldoc.perl.org/perlre.html'>Perl
    # regular expressions</a>.<br/>
}

############################################################################
# printDomainSearchResults - Show domain search results.
############################################################################
sub printDomainSearchResults {
    my $searchTerm             = param("searchTerm");
    my $geneSearchTaxonFilter  = param("geneSearchTaxonFilter");
    my $data_type              = param("q_data_type");

    #my @genomeFilterSelections =
    #  OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    # get the genomes in the selected box:
    my @genomeFilterSelections = param("selectedGenome1");
    if ( $#genomeFilterSelections < 0 ) {
        webError("Please select at least one genome.");
    }
    setSessionParam( "genomeFilterSelections", \@genomeFilterSelections );

    WebUtil::processSearchTermCheck($searchTerm);

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Pfam Domain Search Results</h1>\n";
    print "<p>\n";
    print "Keyword: " . $searchTerm;
    my $dbh = dbLogin();
    my %taxon_in_file;
    if ( $include_metagenomes ) {
        %taxon_in_file = MerFsUtil::fetchTaxonsInFile($dbh, @genomeFilterSelections);
        if ( scalar(keys %taxon_in_file) > 0 ) {
            HtmlUtil::printMetaDataTypeSelection( $data_type, 1 );
        }
    }
    print "</p>\n";

    my @toks = split( /,/, $searchTerm );
    my @pfamIds;
    my @pfamNames;
    my @notPfamIds;
    my @notPfamNames;

    for my $tok (@toks) {
        $tok =~ s/^\s+//;
        $tok =~ s/\s+$//;
        $tok =~ tr/A-Z/a-z/;
        my $not = 0;
        if ( $tok =~ /^\!/ ) {
            $not = 1;
            $tok =~ s/\!//;
            $tok =~ s/^\s+//;
        }
        if ( $tok =~ /^Pfam/ || $tok =~ /^pfam/ ) {
            push( @pfamIds,    lc($tok) ) if !$not;
            push( @notPfamIds, lc($tok) ) if $not;
        }
        else {
            push( @pfamNames,    $tok ) if !$not;
            push( @notPfamNames, $tok ) if $not;
        }
    }

    setSessionParam( "pfamIds",    \@pfamIds );
    setSessionParam( "notPfamIds", \@notPfamIds );

    my $maxGeneListResults = getSessionParam("maxGeneListResults");
    if ( $maxGeneListResults ne "" ) {
        $max_rows = $maxGeneListResults;
    }

    if ($include_metagenomes) {
        # TODO mer fs
        # pfam ids so far
        printStartWorkingDiv();

        my %pfamIdsHash    = WebUtil::array2Hash(@pfamIds);
        my %notPfamIdsHash = WebUtil::array2Hash(@notPfamIds);
        my %foundTaxons;    # hash taxon_oid => count
        print "Check FS...<br/>\n";
        my @type_list = MetaUtil::getDataTypeList( $data_type );
        
        foreach my $toid (@genomeFilterSelections) {
            my $cnt = 0;
            next if ( !exists $taxon_in_file{$toid} );

            my %foundGenes;     # hash of hashes gene oid => 1
            my @removeGenes;    # list of gene oids to be removed
            for my $t2 (@type_list) {
                print "Check metagenome $toid ...<br/>\n";
                my %h = MetaUtil::getTaxonFuncsGenes($toid, $t2, "pfam");
                if (scalar(keys %h) > 0) {
                    for my $pfamId (keys %h) {
                        my @gene_list = split( /\t/, $h{$pfamId} );
                        for my $geneOid (@gene_list) {
                            if ( exists $pfamIdsHash{$pfamId} ) {
                                $foundGenes{$geneOid} = 1;
                            }
                            if ( exists $notPfamIdsHash{$pfamId} ) {
                                push( @removeGenes, $geneOid );
                            }
                        }
                    }
                    
                    # remove not in genes
                    foreach my $gid (@removeGenes) {
                        if ( exists $foundGenes{$gid} ) {
                            delete $foundGenes{$gid};
                        }
                    }
                }        
            }

            my $cnt = keys %foundGenes;
            $foundTaxons{$toid} = $cnt;
        }

        printEndWorkingDiv();

        my @metag = keys %foundTaxons;
        if (@metag) {
            my %taxon_name_h =
              QueryUtil::fetchTaxonOid2NameHash( $dbh, \@metag );

            print qq{
              <p>
              <b>Metagenome Results:</b><br/>
            };

            my $sit = new StaticInnerTable();
            $sit->addColSpec( "Gene Count", "", "right" );
            $sit->addColSpec("Metagenome Name");
            $sit->{colSpec}[1]->{wrap} = "nowrap";

            foreach my $toid ( keys %foundTaxons ) {
                my $count = $foundTaxons{$toid};
                my $name  = $taxon_name_h{$toid};
                my $aurl = 0;
                if ( $count ) {
                    my $url = "main.cgi?section=FindGenes&page=domainList&searchFilter=domain_list"
                      . "&mtaxon_oid=$toid&data_type=$data_type"
                      . "&searchTerm=$searchTerm";
                    $aurl = alink( $url, $count );                    
                }
                my $row = $aurl . "\t";
                my $taxon_name = HtmlUtil::appendMetaTaxonNameWithDataType( $name, $data_type );
                my $taxon_url = "$main_cgi?section=MetaDetail&page=metaDetail&taxon_oid=$toid";
                $row .= alink( $taxon_url, $taxon_name ) . "\t";
                $sit->addRow($row);
            }
            $sit->printTable();
            print qq{
              </p>
            };
        }

        # are there any genomes the user selected that was not a metagenome.
        my $foundNonMetagenome = 0;
        foreach my $gid (@genomeFilterSelections) {
            if ( !exists $taxon_in_file{$gid} ) {
                $foundNonMetagenome = 1;
                last;
            }
        }
        if ( !$foundNonMetagenome ) {
            #$dbh->disconnect();
            return;
        }
    }

    my $pfamClause;
    my @bindList_pfam = ();

    if (@pfamIds) {
        $pfamClause .= "and (";
        for my $i (@pfamIds) {
            $pfamClause .= "gpf.pfam_family = ?";
            push( @bindList_pfam, "$i" );
            $pfamClause .= " or " if ( $i ne $pfamIds[$#pfamIds] );
        }
        $pfamClause .= ")";
    }

    if (@notPfamIds) {
        $pfamClause .= " and (";
        for my $i (@notPfamIds) {
            $pfamClause .= "gpf.pfam_family <> ?";
            push( @bindList_pfam, "$i" );
            $pfamClause .= " and " if ( $i ne $notPfamIds[$#notPfamIds] );
        }
        $pfamClause .= ")";
    }

    if (@pfamNames) {
        $pfamClause .= " and (";
        for my $i (@pfamNames) {
            $pfamClause .= "lower(pf.name) like ?";
            push( @bindList_pfam, "%$i%" );
            $pfamClause .= " or " if ( $i ne $pfamNames[$#pfamNames] );
        }
        $pfamClause .= ")";
    }

    if (@notPfamNames) {
        $pfamClause .= "and (";
        for my $i (@notPfamNames) {
            $pfamClause .= "lower(pf.name) not like ?";
            push( @bindList_pfam, "%$i%" );
            $pfamClause .= " and " if ( $i ne $notPfamNames[$#notPfamNames] );
        }
        $pfamClause .= ")";
    }

    my ( $taxonClause, @bindList_txs ) =
      OracleUtil::getTaxonSelectionClauseBind
      ( $dbh, "gpf.taxon", \@genomeFilterSelections );

    my ( $rclause, @bindList_ur ) = urClauseBind("gpf.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('gpf.taxon');
    my @bindList  = ();

    #print "<p>\n";
    #print "Retrieving transmembrane helices ...<br/>\n";

    my $sql = qq{
        select gpf.gene_oid, count( distinct gth.start_coord )
        from gene_pfam_families gpf, gene_tmhmm_hits gth, pfam_family pf
        where gpf.gene_oid = gth.gene_oid
        and gth.feature_type = ?
        and pf.ext_accession = gpf.pfam_family
        $pfamClause
        $taxonClause
        $rclause
        $imgClause
        group by gpf.gene_oid
    };
    #print "printDomainSearchResults helices \$sql: $sql<br/>";

    push( @bindList, 'TMhelix' );
    processBindList( \@bindList, \@bindList_pfam, \@bindList_txs,
        \@bindList_ur );
    #print "\@bindList size: ".scalar(@bindList)."<br/>\n";
    #print "\@bindList: @bindList<br/>";     

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
    my %geneOid2HelixCount;
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $geneOid2HelixCount{$gene_oid} = $cnt;
    }
    $cur->finish();

    #print "Retrieving domains ...<br/>\n";

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name,
        gpf.pfam_family, pf.name, tx.taxon_oid, tx.taxon_display_name
        from gene g, gene_pfam_families gpf,
        pfam_family pf, taxon tx
        where g.gene_oid = gpf.gene_oid
        and g.taxon      = tx.taxon_oid
        and gpf.pfam_family = pf.ext_accession
        and g.taxon = gpf.taxon
        $pfamClause
        $taxonClause
        $rclause
        $imgClause
    };
    #print "printDomainSearchResults domains \$sql: $sql<br/>";

    @bindList = ();
    processBindList( \@bindList, \@bindList_pfam, \@bindList_txs,
        \@bindList_ur );
    #print "\@bindList size: ".scalar(@bindList)."<br/>\n";
    #print "\@bindList: @bindList<br/>";     

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           "number asc",  "right" );
    $it->addColSpec( "Gene Product Name", "char asc",    "left" );
    $it->addColSpec( "Genome",            "char asc",    "left" );
    $it->addColSpec( "TMhelix(es)",       "number desc", "right" );
    $it->addColSpec( "Domains",           "char asc",    "left" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $trunc = 0;
    my $count = 0;
    my %done;
    for ( ; ; ) {
        my (
            $gene_oid,    $gene_display_name, $dummy_id,
            $dummy_names, $taxon_oid,         $taxon_display_name
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $helixCount = $geneOid2HelixCount{$gene_oid};

        my $pfam_ids_str;
        my $pfam_names_str;

        my $sql = qq{
            select distinct gpf.pfam_family, pf.name
            from  gene_pfam_families gpf,
            pfam_family pf
            where gpf.gene_oid = ?
            and gpf.pfam_family = pf.ext_accession
        };

        @bindList = ();
        push( @bindList, $gene_oid );

        my $pfCur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ( $pfam_id, $pfam_name ) = $pfCur->fetchrow();
            last if !$pfam_id;
            $pfam_ids_str   .= $pfam_id . "|";
            $pfam_names_str .= $pfam_name . "|";
        }
        $pfCur->finish();

        # Skip line if a notPfamId is present
        my $nextLine;
        for my $notPfIds (@notPfamIds) {
            if ( $pfam_ids_str =~ /$notPfIds/i ) {
                $nextLine = 1;
                last;
            }
        }
        next if $nextLine;

        # Skip line if a notPfamName is present
        $nextLine = 0;
        for my $notPfNames (@notPfamNames) {
            if ( $pfam_names_str =~ /$notPfNames/i ) {
                $nextLine = 1;
                last;
            }
        }
        next if $nextLine;

        my @pfam_ids   = split( /\|/, $pfam_ids_str );
        my @pfam_names = split( /\|/, $pfam_names_str );
        my $nIds       = @pfam_ids;
        my $nNames     = @pfam_names;
        if ( $nIds != $nNames ) {
            warn(   "printDomainSearchResults: nIds=$nIds nNames=$nNames "
                  . "mismatch" );
            @pfam_ids = ();
            $nIds     = 0;
        }
        my $pfams_html;
        for ( my $i = 0 ; $i < $nNames ; $i++ ) {
            my $pfam_id   = $pfam_ids[$i];
            my $pfam_name = $pfam_names[$i];

            # Search and highlight all matches
            for my $curSearch (@pfamNames) {
                if ( $pfam_name =~ /($curSearch)/i ) {
                    my $retVal = $1;
                    my $hilite = hiliteWord( escHtml($retVal) );
                    $pfam_name =~ s/$retVal/$hilite/i;
                }
            }
            $pfams_html .= $pfam_name . "";

            if ( $nIds > 0 ) {
                if ( matchSearchTerm( $pfam_id, \@pfamIds ) ) {
                    $pfams_html .= "(" . hiliteWord($pfam_id) . ")";
                }
                else {
                    $pfams_html .= "($pfam_id)";
                }
            }
            $pfams_html .= ", ";
        }

        chop $pfams_html;    # remove the last comma
        chop $pfams_html;    # remove the last space

        my $record = "$gene_oid\t$taxon_oid\t$helixCount\t$pfams_html";
        if ($done{$record}) {
            #print "printDomainSearchResults() duplicate $record<br/>\n";
            next;
        }
        else {
            $done{$record} = 1;
            #print "printDomainSearchResults() added $record<br/>\n";
        }

        $count++;
        if ( $count > $max_rows ) {
            $trunc = 1;
            last;
        }
        
        my $r;
        $r .= $sd
          . "<input type='checkbox' name='gene_oid' value='$gene_oid' />"
          . "\t";

        my $url =
          "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= $gene_display_name . $sd . escHtml($gene_display_name) . "\t";

        my $taxon_url = "$main_cgi?section=TaxonDetail"
            . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink($taxon_url, $taxon_display_name) . "\t";
        $r .= $helixCount . $sd;
        $r .= "<font color='red'><b>" if $helixCount > 2;
        $r .= $helixCount;
        $r .= "</b></font>" if $helixCount > 2;
        $r .= "\t";

        $r .= $pfams_html . $sd . $pfams_html . "\t";
        $it->addRow($r);
    }
    $cur->finish();

    if ( $count == 0 ) {
        print "No results returned from search.\n";
    }
    else {
        print qq{
          <p>
        };
        if ($include_metagenomes) {
            print qq{
              <b>Isolate Genome Results:</b><br/>
            };
        }
        printGeneCartFooter() if $count > 10;
        $it->printOuterTable(1);
        printGeneCartFooter();
        print "</p>\n";
    }

    print end_form();
    if ($trunc) {
        printTruncatedStatus($max_rows);
    }
    else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
}

sub printDomainList {
    my $searchFilter = param('searchFilter');
    my $searchTerm   = param('searchTerm');

    #my $genomeFilterSelections_ref = getSessionParam("genomeFilterSelections");
    my $mtaxon_oid      = param('mtaxon_oid');
    my $data_type       = param('data_type');
    my $pfamIds_aref    = getSessionParam("pfamIds");
    my $notPfamIds_aref = getSessionParam("notPfamIds");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Pfam Domain Search Results</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = WebUtil::taxonOid2Name( $dbh, $mtaxon_oid, 1 );
    $taxon_name = HtmlUtil::printMetaTaxonName( $mtaxon_oid, $taxon_name, $data_type );

    print "<p>";
    print "Keyword: " . $searchTerm;
    HtmlUtil::printMetaDataTypeSelection( $data_type, 1 );
    print "</p>\n";
    
    printStartWorkingDiv();

    my %pfamIds    = WebUtil::array2Hash(@$pfamIds_aref);
    my %notPfamIds = WebUtil::array2Hash(@$notPfamIds_aref);

    my %foundGenes;    # hash of hashes gene oid => 1
    my %genesName;

    my @type_list = MetaUtil::getDataTypeList( $data_type );
    for my $t2 (@type_list) {
        my %h = MetaUtil::getTaxonFuncsGenes($mtaxon_oid, $t2, "pfam");
        if (scalar(keys %h) > 0) {
            my %foundGenesInTaxon;    # list of gene oids found in this taxon
            my @removeGenes;    # list of gene oids to be removed
            for my $pfamId (keys %h) {
                my @gene_list = split( /\t/, $h{$pfamId} );
                for my $geneOid (@gene_list) {
                    my $workspace_id = "$mtaxon_oid $t2 $geneOid";
                    if ( exists $pfamIds{$pfamId} ) {
                        $foundGenes{$geneOid} = $workspace_id;
                        $foundGenesInTaxon{$geneOid} = 1;
                    }
                    if ( exists $notPfamIds{$pfamId} ) {
                        push( @removeGenes, $geneOid );
                    }
                }
            }

            my @genesInTaxon = keys %foundGenesInTaxon;
            if (scalar(@genesInTaxon) > 0) {
                # remove not in genes
                foreach my $gid (@removeGenes) {
                    if ( exists $foundGenes{$gid} ) {
                        delete $foundGenes{$gid};
                        delete $foundGenesInTaxon{$gid};
                    }
                }
                
                @genesInTaxon = keys %foundGenesInTaxon;
                my (%names) = MetaUtil::getGeneProdNamesForTaxonGenes($mtaxon_oid, $t2, \@genesInTaxon);
                for my $key (keys %names) {
                    $genesName{$key} = $names{$key};
                }
                
            }
            
        }

    }

    #my $taxons_href = getAllMetagenomeNames($dbh);
    #$dbh->disconnect();
    printEndWorkingDiv();

    my $count = printMetaGeneList( \%foundGenes, \%genesName );
    printStatusLine( "$count loaded", 2 );
    
    print end_form();
}

#
# print FS metagenomes' gene list
#
# $genelist_href: gene_oid => workspace_id a space delimited values of: taxon_oid type gene_oid
#   where type is: assembled or unassembled
# $genesName_href:
# $highlightterms_aref: search terms to highlight green <font color="green"> <b> term </b> </font>
#
sub printMetaGeneList {
    my ( $genelist_href, $genesName_href, $highlightterms_aref ) = @_;

    my $maxGeneListResults = 1000;
    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $gene_count     = 0;
    my $show_gene_name = 1;
    my $trunc          = 0;
    require InnerTable;
    my $it = new InnerTable( 1, "printMetaGeneList$$", "printMetaGeneList", 1 );
    my $sd = $it->getSdDelim();

    my @gene_oids = ( keys %$genelist_href );
    if ( scalar(@gene_oids) > 100 ) {
        $show_gene_name = 0;
    }

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID", "char asc", "left" );
    if ( $show_gene_name || $genesName_href ne '' ) {
        $it->addColSpec( "Gene Product Name", "char asc", "left" );
    }

    my $select_id_name = "gene_oid";

    my $count = 0;
    for my $key (@gene_oids) {
        my $workspace_id = $genelist_href->{$key};
        my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

        my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";

        my $text = isMatch( $key, $highlightterms_aref );
        $row .=
            $workspace_id . $sd
          . "<a href='main.cgi?section=MetaGeneDetail"
          . "&page=metaGeneDetail&taxon_oid=$tid"
          . "&data_type=$dt&gene_oid=$key'> $text </a>\t";

        if ($show_gene_name) {
            my ( $value, $source ) = MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
            my $text = isMatch( $value, $highlightterms_aref );
            $row .= $value . $sd . $text . "\t";
        } elsif ( exists $genesName_href->{$key} ) {
            my $value = $genesName_href->{$key};
            my $text = isMatch( $value, $highlightterms_aref );
            $row .= $value . $sd . $text . "\t";
        }

        $it->addRow($row);
        $gene_count++;

        if ( $gene_count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
        $count++;
    }

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    return $count;
}

#
# search term found, if yes highlight
#
sub isMatch {
    my ( $text, $terms_aref ) = @_;
    return $text if $terms_aref eq '';

    foreach my $x (@$terms_aref) {
        if ( $text =~ /$x/i ) {
            my $h = "<font color='green'><b>$x</b></font>";
            $text =~ s/$x/$h/i;
            return $text;
        }
    }
    return $text;
}


############################################################################
# matchSearchTerm - Case insensitive search of one of the search terms.
############################################################################
sub matchSearchTerm {
    my ( $term, $terms_ref ) = @_;
    $term =~ tr/A-Z/a-z/;
    for my $t (@$terms_ref) {
        $t =~ tr/A-Z/a-z/;
        return 1 if $t eq $term;
    }
    return 0;
}

############################################################################
# hiliteWord - Highlight word.
############################################################################
sub hiliteWord {
    my ($s)   = @_;
    my $style = "color:green; font-weight:bold";
    my $s2    = "<span style='$style'>";
    $s2 .= $s;
    $s2 .= "</span>";
    return $s2;
}

############################################################################
# getHelixCount - Get it in real time to see if it's faster.
# not used currently
############################################################################
sub getHelixCount {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
      select gth.gene_oid, count( gth.start_coord )
      from gene_tmhmm_hits gth
      where gth.gene_oid = ?
      and gth.feature_type = ?
      group by gth.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, 'TMhelix' );
    my ( $gene_oid, $cnt ) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# searchProductSdb - Search gene_product_genes.sdb
#   and return same data.
#    --es 07/05/13
############################################################################
sub searchProductSdb {
    my( $dbh, $sdbFile, $searchTerm, $max_rows, $recs_aref ) = @_;

    my %taxonNames;
    my $sql = qq{
        select taxon_oid, taxon_display_name
    from taxon
    where in_file = 'No'
    and obsolete_flag = 'No'
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
       my( $taxon_oid, $taxon_display_name ) = $cur->fetchrow( );
       last if !$taxon_oid;
       $taxonNames{ $taxon_oid } = $taxon_display_name;
    }
    $cur->finish( );

    my %validTaxons;
    #my @selectedTaxons = 
    #   OracleUtil::processTaxonSelectionParam( "genomeFilterSelections" );

    # get the genomes in the selected box:
    my @selectedTaxons = param("selectedGenome1");

    if ( scalar(@selectedTaxons) > 0 ) {
       for my $taxon_oid( @selectedTaxons ) {
          $validTaxons{ $taxon_oid } = $taxon_oid;
       }
    }
    else {
       %validTaxons = WebUtil::getAllTaxonsHashed( $dbh );
    }
    my $nTaxons = keys( %validTaxons );
    webLog( "Using $nTaxons taxons\n" );

    my $sdbh = WebUtil::sdbLogin( $sdbFile );
    my $sql = qq{
        select gene_display_name, genes
        from product
        where lower( gene_display_name ) like ?
    };
    my $cur = execSql( $sdbh, $sql, $verbose, "%$searchTerm%" );
    my $count = 0;
    my $trunc = 0;
    for( ;; ) {
        my( $gene_display_name, $genes ) = $cur->fetchrow( );
    last if $gene_display_name eq "";
    my @genes_a = split( /\s+/, $genes );
    for my $g( @genes_a ) {
        my( $taxon_oid, $gene_oid, $locus_tag, $enzyme ) =
           split( /\|/, $g );
        next if !$validTaxons{ $taxon_oid };
        $count++;
        my $taxon_display_name = $taxonNames{ $taxon_oid };
        my $r = "$gene_oid\t";
        $r .= "$locus_tag\t";
        $r .= "$gene_display_name\t";
        #$r .= "$enzyme\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        push( @$recs_aref, $r );
        if( $count >= $max_rows ) {
           $trunc = 1;
        }
    }
    }
    $sdbh->disconnect( );
    webLog( "$count genes loaded from '$sdbFile'\n" );
    return( $count, $trunc );
}

sub isMetaSupported {
    my ($searchFilter) = @_;

    if (    $searchFilter eq "gene_display_name_iex"
         || $searchFilter eq "locus_tag_merfs"
         || $searchFilter eq "gene_oid_merfs"
         || $searchFilter eq "domain_list"
     ) {
        return 1;
    }

    return 0;
}

1;
