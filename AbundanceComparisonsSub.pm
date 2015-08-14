############################################################################
# AbundanceComparisons.pm - Tool to allow for multiple pairwise
#   genome abundance comparisons.
#        --es 06/11/2007
# $Id: AbundanceComparisonsSub.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package AbundanceComparisonsSub;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use AbundanceComparisons;
use OracleUtil;
use HtmlUtil;
use MetaUtil;
use MerFsUtil;
use FileHandle;
use WorkspaceUtil;
use AbundanceToolkit;
use GenomeListJSON;

my $section             = "AbundanceComparisonsSub";
my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $section_cgi         = "$main_cgi?section=$section";
my $inner_cgi           = $env->{inner_cgi};
my $verbose             = $env->{verbose};
my $base_dir            = $env->{base_dir};
my $img_internal        = $env->{img_internal};
my $include_img_terms   = $env->{include_img_terms};
my $include_metagenomes = $env->{include_metagenomes};
my $show_myimg_login    = $env->{show_myimg_login};
my $img_lite            = $env->{img_lite};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $show_myimg_login    = $env->{show_myimg_login};

my $top_n_abundances     = 10000; # make a very large number
my $max_query_taxons     = 20;
my $max_reference_taxons = 200;
my $r_bin                = $env->{r_bin};
my $in_file              = $env->{in_file};
my $mer_data_dir         = $env->{mer_data_dir};
my $default_timeout_mins = $env->{default_timeout_mins};
my $merfs_timeout_mins   = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";

my $fdr       = 0.05;
my $max_batch = 500;


my %function2IdType = (
    cog     => "cog_id",
    pfam    => "pfam_id",
    enzyme  => "ec_number",
    tigrfam => "tigrfam_id"
);

my %func_text = (
    'cogc'     => 'COG Category',
    'cogp'     => 'COG Pathway',
    'keggp'    => 'Kegg Pathway via EC',
    'keggc'    => 'Kegg Pathway Category via EC',
    'keggp_ko' => 'Kegg Pathway via KO',
    'keggc_ko' => 'Kegg Pathway Category via KO',
    'pfam'     => 'Pfam Category (formed from COG category / pathway)',
    'tigrfam'  => 'TIGRfam Category Role',
);

############################################################################
# dispatch - Dispatch events.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 minutes (from main.pl)

    if ( paramMatch("abundanceResults") ne "" ) {
        printAbundanceResults();
    } elsif ( $page eq "abundancePager" ) {
        printAbundancePager();
    } elsif ( $page eq "abundanceDownload" ) {
        printAbundanceDownload();
    } elsif ( $page eq "geneList" ) {
        printGeneList();
    } elsif ( $page eq "dscoreNote" ) {
        printDScoreNote();
    } else {
        printQueryForm($numTaxon);
    }
}

############################################################################
# printQueryForm - Show query form for abundances.
############################################################################
sub printQueryForm {
    my ($numTaxon) = @_;
    my $dbh = dbLogin();

    print "<h1>Function Category Comparisons</h1>\n";

    print "<p style='width: 800px;'>\n";
    print qq{
        The <b>Function Category Comparison</b> tool allows you to
        compare <u>a query</u> (meta)genome to <u>multiple reference</u>
        (meta)genomes in terms of the abundance of pre-defined groups of
        protein families as represented by different types of functional
        classifications such as COG Pathways, KEGG Pathways and
        KEGG Pathway Categories.
    };
    print "</p>\n";

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $cgi_url = $env->{cgi_url};
    my $xml_cgi = $cgi_url . '/xml.cgi';

    my $template = HTML::Template->new
	( filename => "$base_dir/genomeJsonTwoDiv.html" );
    $template->param( isolate              => 1 );
    $template->param( gfr                  => $hideGFragment );
    $template->param( pla                  => $hidePlasmids );
    $template->param( vir                  => $hideViruses );
    $template->param( all                  => 1 );
    $template->param( cart                 => 1 );
    $template->param( xml_cgi              => $xml_cgi );
    $template->param( prefix               => '' );
    $template->param( selectedGenome1Title => 'Query Genome' );
    $template->param( selectedGenome2Title => 'Reference Genomes' );
    $template->param( maxSelected2         => -1 );

    if ( $include_metagenomes ) {
	$template->param( include_metagenomes  => 1 );
	$template->param( selectedAssembled1   => 1 );
	$template->param( selectedAssembled2   => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    my $function = param('function');
    if ( !$function ) {
        $function = 'cogp';
    }

    print "<p>";
    print "<b>Function Category</b>:<br/>";
    for my $func2 ( 'cogc', 'cogp', 'keggc', 'keggc_ko', 'keggp', 'keggp_ko', 'pfam', 'tigrfam' ) {
        print "<input type='radio' name='function' value='$func2' ";
        print " checked " if ( $func2 eq $function );
        print " />" . $func_text{$func2} . "<br/>\n";
    }
    print "</p>";

    print "<p>";
    print "<b>Measurement</b>:<br/>";
    my $xcopy = param('xcopy');
    $xcopy = 'gene_count' if ( !$xcopy );
    print "<input type='radio' name='xcopy' value='gene_count' ";
    print "checked" if ( $xcopy eq 'gene_count' );
    print " />Gene count<br/>\n";
    print "<input type='radio' name='xcopy' value='est_copy' ";
    print "checked" if ( $xcopy eq 'est_copy' );
    print qq{
         />Estimated gene copies\n
         <sup><a href="#hint1">1</a></sup><br/>\n
         <br>\n
         Minimum function gene count to calculate d-score\n
         <sup><a href="#hint2">2</a></sup>&nbsp;\n
         <SELECT name="mincount">\n
        	<OPTION value="-">-</option>
        	<OPTION value="1">1</option>
        	<OPTION value="2">2</option>
        	<OPTION value="3">3</option>
        	<OPTION value="4">4</option>
        	<OPTION value="5" selected="true">5</option>
        	<OPTION value="6">6</option>
        	<OPTION value="7">7</option>
        	<OPTION value="8">8</option>
        	<OPTION value="9">9</option>
        	<OPTION value="10">10</option>\n
         </SELECT>\n

         </p>\n

         <p>\n
            <b>Output</b>:<br/>\n
            <input type='radio' name='outType' value='dscore' checked />\n
            D-rank\n
            <sup><a href="#hint3">3</a></sup><br/>\n
            <input type='radio' name='outType' value='dscoreAbs' />\n
            D-rank (unsigned)\n
            <sup><a href="#hint4">4</a></sup><br/>\n
            <br/>\n
    };

    # filter fcn's with all zero gene count rows
    print <<EOF;
    <SCRIPT TYPE="text/javascript">
    function checkzero() {
        if (document.mainForm.zerofilter.checked) {
    	    document.mainForm.zerofilter.value = 'yes';
	} else {
	    document.mainForm.zerofilter.value = 'no';
	}
        //alert(document.mainForm.zerofilter.value);
    }
    </SCRIPT>
EOF
    print qq{
        <input type='checkbox' name='zerofilter' value='no'
            onclick='checkzero()'" . " />\n
        Include all rows, including those without hits<br/>\n
        <br/>\n
        Functions per page:\n
    };
    print nbsp(1);
    print popup_menu(
            -name    => "funcsPerPage",
            -values  => [ 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 ],
            -default => 500
    );
    print "</p>";

    my $name = "_section_${section}_abundanceResults";
    GenomeListJSON::printHiddenInputType( $section, 'abundanceResults' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
       ( 'go', $name, 'Go', '', $section, 'abundanceResults',
	 'smdefbutton', 'selectedGenome1', 1, 'selectedGenome2', 1 );
    print $button;

    print nbsp(1);
    print reset( -id => "reset", -class => "smbutton" );

    my $url = "$section_cgi&page=dscoreNote";
    my $link_str = alink($url, "detail");
    print qq{
      <br/>\n
      <p>\n
        <b>Notes:</b><br/>\n
        <a name="hint1" href="#"></a>\n
        1 - Estimated by multiplying by read depth when available.<br/>\n
        <a name="hint2" href="#"></a>\n
        2 - Gene count less than min. will have a d-score set to zero.<br/>\n
        <a name="hint3" href="#"></a>\n
        3 - A normalization ranking abundance d-scores.
        ( $link_str )<br/>\n
        <a name="hint4" href="#"></a>\n
        4 - abs( D-rank )<br/>\n
      </p>\n
    };

    GenomeListJSON::showGenomeCart($numTaxon);
    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printAbundanceResults - Show results from query form.
############################################################################
sub printAbundanceResults {
    my $q_data_type      = param("q_data_type");

    my @queryGenomes     = param("selectedGenome1");
    my @referenceGenomes = param("selectedGenome2");

    my $r_data_type      = param("r_data_type");
    my $function         = param("function");
    my $xcopy            = param("xcopy");
    my $outType          = param("outType");
    my $normalization    = param("normalization");
    my $funcsPerPage     = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $hidezero = param("zerofilter");
    if ( $hidezero eq "" ) {
        # do not include zeros
        $hidezero = "no";
    }

    print "<h1>Function Category Comparisons</h1>\n";
    print "<p>\n";
    print "Function: " . $func_text{$function} . "<br/>\n";
    if ( $outType eq "dscore" ) {
        print "Output type: D-rank.<br/>\n";
    } elsif ( $outType eq "dscoreAbs" ) {
        print "Output type: D-rank unsigned.<br/>\n";
    } elsif ( $outType eq "pvalue" ) {
        print "Output type: P-value.<br/>\n";
    }
    if ( $xcopy eq "gene_count" ) {
        print "Measurement: Gene Count<br/>";
    } else {
        print "Measurement: Estimated gene copies<br/>";
    }

    my $nQueryGenomes     = @queryGenomes;
    my $nReferenceGenomes = @referenceGenomes;
    if ( $nQueryGenomes == 0 ) {
        webError("Please select one query genome.<br/>\n");
    }
    if ( $nReferenceGenomes == 0 ) {
        webError( "Please select 1 to $max_reference_taxons reference genomes.<br/>\n" );
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    if ( hasMerFsTaxons( \@queryGenomes )
        || hasMerFsTaxons( \@referenceGenomes ) )
    {
        timeout( 60 * $merfs_timeout_mins );
    }

    my $contact_oid = getContactOid();
    if ( $contact_oid == 312 ) {
	   print "<p>*** time1: " . currDateTime() . "\n";
    }

    print "<p>\n";

    #print "Set $funcsPerPage functions per page ...<br/>\n";

    my $dbh = dbLogin();
    my $funcId2Name_href = getFuncCatDict($dbh, $function);
    #print Dumper($funcId2Name_href);
    #print "<br/>\n";

    printStartWorkingDiv();

    #hash of hashes: taxon oid => cat => gene count
    my %queryTaxonProfiles;
    #getProfileVectors( $dbh, "query", \@queryGenomes, $function, $xcopy, \%queryTaxonProfiles, $q_data_type );

    #hash of hashes: taxon oid => cat => func id => gene count
    my %queryTaxon_h;
    #getProfileVectors2( $dbh, "query", \@queryGenomes, $function, $xcopy, \%queryTaxon_h, $q_data_type );

    getCombinedProfileVectors( $dbh, "query", \@queryGenomes, $function, $xcopy, \%queryTaxonProfiles, \%queryTaxon_h, $q_data_type );
    #print Dumper(\%queryTaxonProfiles);
    #print "<br/>\n";

    # there can be only one query taxon selected
    my $query_taxon_oid = $queryGenomes[0];
    my $queryProfile_ref = $queryTaxonProfiles{$query_taxon_oid};

    my %referenceTaxonProfiles;
    #getProfileVectors( $dbh, "reference", \@referenceGenomes, $function, $xcopy, \%referenceTaxonProfiles, $r_data_type );
    my %referenceTaxon_h;
    #getProfileVectors2( $dbh, "reference", \@referenceGenomes, $function, $xcopy, \%referenceTaxon_h, $r_data_type );

    getCombinedProfileVectors( $dbh, "reference", \@referenceGenomes, $function, $xcopy, \%referenceTaxonProfiles, \%referenceTaxon_h, $r_data_type );
    #print Dumper(\%referenceTaxonProfiles);
    #print "<br/>\n";

    # above we got the counts
    # now we normalize the value - ken

    # hash of hashes: taxon oid => hash of dscores: query function ids => d score
    my %refTaxonDscores;

    # hash of hashes: taxon oid => hash of flags
    my %refTaxonFlags;

    print "Calculating d-score<br>\n";
    my $query_href = $queryTaxon_h{$query_taxon_oid};
    for my $refTaxon (@referenceGenomes) {
        my $reference_href = $referenceTaxon_h{$refTaxon};

        # path id = > cog id => d score
        my %flags;
        my $dscores_href = getDScores2( $outType, $query_href, $reference_href, \%flags );

        $refTaxonDscores{$refTaxon} = $dscores_href;
        $refTaxonFlags{$refTaxon}   = \%flags;
    }

    # Now get counts of sub func to parent func
    # sub func = > func count
    # e.g. cog pathway id => cog count
    my $func_cnt_href = getFunctionCounts( $dbh, $function );

    print "Calculating D-rank<br>\n";

    # now the dscore is done get DD score for the set
    # taxon id =>  path id = > cog id => d score
    # return taxon id => path id => D rank
    my $ddscores_href = getDDScore( $outType, \%refTaxonDscores, $func_cnt_href );

    print "Calculating p-values<br>\n";
    my %refTaxonPvalues;

    # Add dummy values to keep code from breaking.
    for my $taxon_oid (@referenceGenomes) {
        my %h;
        $refTaxonPvalues{$taxon_oid} = \%h;
    }
    my %refTaxonPvalueCutoffs;
    getPvalues( $ddscores_href, \%refTaxonPvalues, \%refTaxonPvalueCutoffs, \%refTaxonFlags );

    printEndWorkingDiv();

    if ( $contact_oid == 312 ) {
    	print "<p>*** time2: " . currDateTime() . "\n";
    }

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    webLog("pagerFileRoot $pagerFileRoot'\n");
    my $hidecount = writePagerFiles(
         $dbh,                     $pagerFileRoot,    $funcId2Name_href, \%queryTaxonProfiles,
         \%referenceTaxonProfiles, \%refTaxonDscores, \%refTaxonPvalues, \%refTaxonFlags,
         \%refTaxonPvalueCutoffs,  $function,         $hidezero,         $ddscores_href
    );
    print "</p>\n";

    #$dbh->disconnect();

    printOnePage(1);
    my $nFuncs = keys(%$funcId2Name_href);

    # hidden zeros
    $nFuncs -= $hidecount;
    printStatusLine( "$nFuncs functions loaded.", 2 );
    print end_form();
}

#
# I need a name for this calculation
#
# NOTE, I include the zero hit rows for N!
#
# (sum of dscores  i = 1 to N ) / sqrt(N)
#
# e.g. for cog pathways
# cog pathway,     cog id,    gene count,     d-score
# 1                5           5
# 1                8           6
# 2                3           8
# 2                4           1
# 2                6           2
# thus the d-score is on the sub-system gene counts
#
# taxon id =>  path id = > cog id => d score
# $func_cnt_href is hash of path id => cog count
# return taxon id => path id => D rank
sub getDDScore {
    my ( $outType, $taxon_href, $func_cnt_href ) = @_;

    my $doAbs = 0;
    if ( $outType eq "dscoreAbs" ) {
        $doAbs = 1;
    }

    my %results;

    foreach my $tid ( keys %$taxon_href ) {
        my $path_href = $taxon_href->{$tid};

        my %subResults;

        foreach my $pid ( keys %$path_href ) {
            my $cog_href = $path_href->{$pid};

            # update N here with all counts - ken 2/04/08
            my $N   = $func_cnt_href->{$pid};
            my $sum = 0;

            foreach my $cid ( keys %$cog_href ) {
                my $d = $cog_href->{$cid};
                $sum += $d;
            }

            if ( $N eq "" || $N == 0 ) {
                $subResults{$pid} = 0;
            } else {
                $subResults{$pid} = $sum / sqrt($N);
                if ( $doAbs == 1 ) {
                    $subResults{$pid} = abs( $subResults{$pid} );
                }
            }

        }
        $results{$tid} = \%subResults;
    }
    return \%results;
}

############################################################################
# writePagerFiles - Write files for pager.
#   It writes to a file with 2 data columns for each
#   cell value.  One is for sorting.  The other is for display.
#   Third is flag for invalid indicator.
#   (Usually, they are the same, but sometimes not.)
#
# param $function - is the function id type
#		cog pathway - cogp
#		cog category - cogc
#		kegg pathway - keggp
#		kegg category - keggc
#
#
#  $Drank_href - taxon id => path id => D rank
#
############################################################################
sub writePagerFiles {
    my (
         $dbh,                        $pagerFileRoot,    $funcId2Name_ref,  $queryTaxonProfiles_ref,
         $referenceTaxonProfiles_ref, $taxonDscores_ref, $taxonPvalues_ref, $taxonFlags_ref,
         $taxonPvalueCutoffs_ref,     $function,         $hidezero,         $Drank_href
      )
      = @_;

    my $funcsPerPage  = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $function      = param("function");
    my $normalization = param("normalization");
    my $outType       = param("outType");
    my $xcopy         = param("xcopy");
    my $q_data_type   = param("q_data_type");
    my $r_data_type   = param("r_data_type");

    my $doGenomeNormalization = 0;
    $doGenomeNormalization = 1 if $normalization eq "genomeSize";

    my $metaFile = "$pagerFileRoot.meta";    # metadata
    my $rowsFile = "$pagerFileRoot.rows";    # tab delimted rows for pager
    my $idxFile  = "$pagerFileRoot.idx";     # index file
    my $xlsFile  = "$pagerFileRoot.xls";     # Excel export file

    my $Fmeta = newWriteFileHandle( $metaFile, "writePagerFiles" );
    my $Frows = newWriteFileHandle( $rowsFile, "writePagerFiles" );
    my $Fxls  = newWriteFileHandle( $xlsFile,  "writePagerFiles" );

    my @taxon_oids = keys(%$queryTaxonProfiles_ref);

    my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);

    my @query_taxon_oids = sortByTaxonName( $dbh, \@taxon_oids );

    my @taxon_oids           = keys(%$referenceTaxonProfiles_ref);
    my @reference_taxon_oids = sortByTaxonName( $dbh, \@taxon_oids );

    my @funcIds = sort( keys(%$funcId2Name_ref) );
    my $nFuncs  = @funcIds;
    my $nPages  = int( $nFuncs / $funcsPerPage ) + 1;

    ## Output rows data

    ## Metadata for pager
    print $Fmeta ".funcsPerPage $funcsPerPage\n";
    print $Fmeta ".nPages $nPages\n";
    print $Fmeta ".outType $outType\n";

    # Pvalue cutoffs per taxon
    print $Fmeta ".pvalueCutoffsStart\n";
    for my $taxon_oid (@reference_taxon_oids) {
        my $pvalue_cutoff = $taxonPvalueCutoffs_ref->{$taxon_oid};
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        print $Fmeta "$taxon_oid $pvalue_cutoff $name\n";
    }
    print $Fmeta ".pvalueCutoffsEnd\n";

    ## Column header for pager
    print $Fmeta ".attrNameStart\n";
    my $colIdx = 0;

    print $Fmeta "$colIdx :  Row<br/>No. : AN: right\n";
    $colIdx++;

    # sorting i've updated to number from AS to AN - ken
    if ( $function eq 'keggc' || $function eq 'keggc_ko' ) {
        print $Fmeta "$colIdx :  ID : AS : left\n";
    } else {
        print $Fmeta "$colIdx :  ID : AN : right\n";
    }

    $colIdx++;
    print $Fmeta "$colIdx :  Name : AS : left\n";
    $colIdx++;

    my $xcopy_text = "Gene Count";
    if ( $xcopy eq 'est_copy' ) {
        $xcopy_text = "Estimated Gene Copies";
    }

    # meta data for cache file
    for my $taxon_oid (@query_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $abbrName = largeAbbrColName( $taxon_oid, $name, 1 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $name     .= " (MER-FS)";
            $abbrName .= " (MER-FS)";
            if ( $q_data_type =~ /assembled/i || $q_data_type =~ /unassembled/i ) {
                $name .= "<br/>($q_data_type)";
                $abbrName .= "<br/>($q_data_type)";
            }
        }
        print $Fmeta "$colIdx : $abbrName<br/>$xcopy_text<br/>(Q) : " . "DN : right : $name ($taxon_oid) $xcopy_text\n";
        $colIdx++;
    }
    for my $taxon_oid (@reference_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $abbrName = largeAbbrColName( $taxon_oid, $name, 1 );
        if ( $taxon_in_file{$taxon_oid} ) {
            $name     .= " (MER-FS)";
            $abbrName .= " (MER-FS)";
            if ( $r_data_type =~ /assembled/i || $r_data_type =~ /unassembled/i ) {
                $name .= "<br/>($r_data_type)";
                $abbrName .= "<br/>($r_data_type)";
            }
        }

        #my $dir = "DN";
        #$dir = "AN" if $outType eq "pvalue";

        # drank
        print $Fmeta "$colIdx : $abbrName<br/>(R) : " . "DN : right : $name ($taxon_oid)\n";
        $colIdx++;

        # pvalue
        print $Fmeta "$colIdx : $abbrName<br/>p-value<br/>(R) : " . "AN : right : $name ($taxon_oid) p-value\n";
        $colIdx++;

        # gene count
        print $Fmeta "$colIdx : $abbrName<br/>$xcopy_text<br/>(R) : " . "DN : right : $name ($taxon_oid) $xcopy_text\n";
        $colIdx++;

    }

    print $Fmeta ".attrNameEnd\n";

    ## Excel export header
    print $Fxls "Func_id\t";
    print $Fxls "Func_name\t";
    my $s;

    for my $taxon_oid (@query_taxon_oids) {
        my $nameX = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $name = excelHeaderName($nameX);
        $name = $name . "_geneCount";
        $s .= "$name\t";
    }

    for my $taxon_oid (@reference_taxon_oids) {
        my $nameX = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $name = excelHeaderName($nameX);
        $s .= "$name\t";

        # pvalue column
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        $name = excelHeaderName($name) . "_pvalue";
        $s .= "$name\t";

        $name = excelHeaderName($nameX) . "_geneCount";
        $s .= "$name\t";
    }

    chop $s;
    print $Fxls "$s\n";

    my $hidecount = 0;
    my $count     = 0;
    for my $funcId (@funcIds) {
        $count++;
        my $funcName = $funcId2Name_ref->{$funcId};
        my $r;
        my $xls;

        # sum the counts to see if they are all zeros - ken
        my $zeros = 0;

        # row number
        $r .= "$count\t";
        $r .= "$count\t";
        $r .= "\t";

        #$r .= "\t";

        # function id
        $r .= "$funcId\t";
        $r .= "$funcId\t";
        $r .= "\t";

        #$r   .= "\t";
        $xls .= "$funcId\t";

        # function name
        $r .= "$funcName\t";
        $r .= "$funcName\t";
        $r .= "\t";

        #$r   .= "\t";
        $xls .= "$funcName\t";

        for my $taxon_oid (@query_taxon_oids) {
            next if !isInt($taxon_oid);
            my $profile_ref = $queryTaxonProfiles_ref->{$taxon_oid};
            if ( !defined($profile_ref) ) {
                warn("writePagerFiles: cannot find q.profile for $taxon_oid\n");
                next;
            }
            my $cnt = $profile_ref->{$funcId};
            $cnt = 0 if $cnt eq "";

            # I added the function type for gene list page - ken
            #  escape the url func id may be text
            my $url = "$section_cgi&page=geneList&xcopy=$xcopy";
            $url .= "&funcId=$funcId&function=$function&taxon_oid=$taxon_oid&data_type=$q_data_type";
            $url = escapeHTML($url);
            my $link = alink( $url, $cnt );
            $link = 0 if $cnt == 0;
            $r .= "$cnt\t";
            $r .= "$link\t";

            #$r .= "invalid\t";
            $r .= "\t";

            #$r .= "\t";

            $xls .= "$cnt\t";

            $zeros = $zeros + $cnt;
        }

        for my $taxon_oid (@reference_taxon_oids) {
            next if !isInt($taxon_oid);
            my $profile_ref = $referenceTaxonProfiles_ref->{$taxon_oid};
            if ( !defined($profile_ref) ) {
                warn("writePagerFiles: cannot find r.profile for $taxon_oid\n");
                next;
            }

            my $pvalues_ref = $taxonPvalues_ref->{$taxon_oid};
            if ( !defined($pvalues_ref) ) {
                warn( "writePagerFiles: cannot find pvalues_ref for $taxon_oid\n" );
                next;
            }
            my $flags_ref = $taxonFlags_ref->{$taxon_oid};
            if ( !defined($flags_ref) ) {
                warn("writePagerFiles: cannot find flags_ref for $taxon_oid\n");
                next;
            }

            my $drank = $Drank_href->{$taxon_oid}->{$funcId};
            $drank = sprintf( "%.2f", $drank );

            my $pvalue = $pvalues_ref->{$funcId};
            $pvalue = sprintf( "%.2e", $pvalue );
            my $pvalue_display = $pvalue;

            my $val         = $drank;
            my $val_display = $drank;

            #$val         = $pvalue         if $outType eq "pvalue";
            #$val_display = $pvalue_display if $outType eq "pvalue";
            #my $flag = "";                        #$flags_ref->{$funcId};
            my $flag = $flags_ref->{$funcId};
            my $cnt  = $profile_ref->{$funcId};
            $cnt = 0 if $cnt eq "";

            # I added the function type for gene list page - ken

            my $url = "$section_cgi&page=geneList";
            $url .= "&funcId=$funcId&function=$function&taxon_oid=$taxon_oid&data_type=$r_data_type";
            $url = escapeHTML($url);
            my $link = alink( $url, $cnt );
            $link = 0 if $cnt == 0;

            # d-rank
            $r .= "$val\t";
            $r .= "$val_display\t";
            $r .= "$flag\t";

            #$r .= "\t";

            # Kludge to not highlight p-value
            if ( $drank == 0 || $drank eq "" ) {
                $pvalue         = 0.5;
                $pvalue         = sprintf( "%.2e", $pvalue );
                $pvalue_display = $pvalue;
            }

            # p-value
            $r .= "$pvalue\t";
            $r .= "$pvalue_display\t";
            $r .= "$flag\t";

            # gene count
            $r .= "$cnt\t";
            $r .= "$link\t";
            $r .= "$flag\t";

            #$r .= "\t";
            my $mycolor;
            $mycolor = getDScoreColor($val) if ( blankStr($flag) );
            $mycolor = "" if ( $mycolor eq "white" );
            $xls .= "$val $mycolor\t";
            $mycolor = "";
            $mycolor = getPvalueColor($pvalue) if ( blankStr($flag) );
            $mycolor = "" if ( $mycolor eq "white" );
            $xls .= "$pvalue $mycolor\t";
            $xls .= "$cnt\t";

            $zeros = $zeros + $cnt;
        }

        if ( $zeros == 0 && $hidezero eq "no" ) {

            #webLog("$funcId hiding zero\n");
            $count--;
            $hidecount++;
            next;
        }

        chop $r;
        chop $xls;
        print $Frows "$r\n";
        print $Fxls "$xls\n";
    }
    webLog("$count $function rows written\n");

    close $Fmeta;
    close $Frows;
    close $Fxls;

    indexRows( $rowsFile, $idxFile, $funcsPerPage );

    return $hidecount;
}

############################################################################
# indexRows - Index rows in file.
############################################################################
sub indexRows {
    my ( $inFile, $outFile, $funcsPerPage, $nPages ) = @_;

    my $rfh = newReadFileHandle( $inFile,   "indexRows" );
    my $wfh = newWriteFileHandle( $outFile, "indexRows" );
    my $count  = 0;
    my $fpos   = tell($rfh);
    my $pageNo = 1;
    print $wfh "$pageNo $fpos\n";
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $count++;
        if ( $count > $funcsPerPage ) {
            $pageNo++;
            print $wfh "$pageNo $fpos\n";
            $count = 1;
        }
        $fpos = tell($rfh);
    }
    close $rfh;
    close $wfh;
}

############################################################################
# printAbundancePager - Show pages in pager.
############################################################################
sub printAbundancePager {
    my $pageNo        = param("pageNo");
    my $colIdx        = param("colIdx");
    my $function      = param("function");
    my $xcopy         = param("xcopy");
    my $normalization = param("normalization");
    my $funcsPerPage  = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $sortType      = param("sortType");

    print "<h1>Function Category Comparisons</h1>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );
    if ( $sortType ne "" ) {
        sortAbundanceFile( $function, $xcopy, $normalization, $sortType, $colIdx, $funcsPerPage );
        $pageNo = 1;
    }
    printOnePage($pageNo);
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# sortAbundanceFile - Resort abundance file.
############################################################################
sub sortAbundanceFile {
    my ( $function, $xcopy, $normalization, $sortType, $colIdx, $funcsPerPage ) = @_;

    #print "<p>\n";
    #print "Resorting ...<br/>\n";
    #print "</p>\n";
    webLog("resorting sortType='$sortType' colIdx='$colIdx'\n");
    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $pagerFileRows = "$pagerFileRoot.rows";
    my $pagerFileIdx  = "$pagerFileRoot.idx";
    if ( !( -e $pagerFileRows ) || !( -e $pagerFileIdx ) ) {
        webLog("Expired session file '$pagerFileRows' or '$pagerFileIdx'\n");
        webError("Session file expired.<br/>Please start your 'Function Comparison' study from the beginning.\n");
    }

    my $rfh = newReadFileHandle( $pagerFileRows, "sortAbudanceFile" );
    my @recs;
    my $rowIdx = 0;
    my @sortRecs;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        push( @recs, $s );
        my (@vals) = split( /\t/, $s );

        my $idx = $colIdx * 3;

        my $sortVal = $vals[$idx];
        my $sortRec = "$sortVal\t";
        $sortRec .= "$rowIdx";
        push( @sortRecs, $sortRec );
        $rowIdx++;
    }
    close $rfh;
    my @sortRecs2;

    # A - asc sort
    # D - desc sort

    # S - string
    # N - number
    if ( $sortType =~ /N/ ) {

        #if ( $sortRecs[0] =~ /^\d+\.\d+e[\+-]\d+/ ) {
        # number has a format of 1.79e-02 or 0.00e+00
        #} else {
        if ( $sortType =~ /D/ ) {
            @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
        } else {
            @sortRecs2 = sort { $a <=> $b } (@sortRecs);
        }

        #}
    } else {
        if ( $sortType =~ /D/ ) {
            @sortRecs2 = reverse( sort(@sortRecs) );
        } else {
            @sortRecs2 = sort(@sortRecs);
        }
    }
    my $wfh = newWriteFileHandle( $pagerFileRows, "sortAbundanceFile" );
    for my $r2 (@sortRecs2) {
        my ( $sortVal, $rowIdx ) = split( /\t/, $r2 );
        my $r = $recs[$rowIdx];
        print $wfh "$r\n";
    }
    close $wfh;
    indexRows( $pagerFileRows, $pagerFileIdx, $funcsPerPage );
}

############################################################################
# getPagerFileRoot - Convention for getting the pager file.
############################################################################
sub getPagerFileRoot {
    my ( $function, $xcopy, $normalization ) = @_;
    my $sessionId    = getSessionId();
    my $tmpPagerFile = "$cgi_tmp_dir/subsystemComparisons.$function" . ".$xcopy.$normalization.$sessionId";
}

############################################################################
# printOnePage - Print one page for pager.
############################################################################
sub printOnePage {
    my ($pageNo)              = @_;
    my $colIdx                = param("colIdx");
    my $function              = param("function");
    my $xcopy                 = param("xcopy");
    my $normalization         = param("normalization");
    my $funcsPerPage          = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $doGenomeNormalization = 0;
    $doGenomeNormalization = 1               if $normalization eq "genomeSize";
    $pageNo                = param("pageNo") if $pageNo        eq "";
    $pageNo                = 1               if $pageNo        eq "";

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $pagerFileIdx  = "$pagerFileRoot.idx";
    my $pagerFileRows = "$pagerFileRoot.rows";
    my $pagerFileMeta = "$pagerFileRoot.meta";
    my $pagerFileXls  = "$pagerFileRoot.xls";
    if ( !-e ($pagerFileIdx) ) {
        warn("$pagerFileIdx not found\n");
        webError("Session expired for this page.  Please start again.");
    }
    if ( !-e ($pagerFileRows) ) {
        warn("$pagerFileRows not found\n");
        webError("Session expired for this page.  Please start again.");
    }
    if ( !-e ($pagerFileMeta) ) {
        warn("$pagerFileMeta not found\n");
        webError("Session expired for this page.  Please start again.");
    }
    if ( !-e ($pagerFileXls) ) {
        warn("$pagerFileXls not found\n");
        webError("Session expired for this page.  Please start again.");
    }

    my %metaData      = loadMetaData($pagerFileMeta);
    my $funcsPerPage  = $metaData{funcsPerPage};
    my $attrSpecs_ref = $metaData{attrSpecs};
    my $outType       = $metaData{outType};
    my $nAttrSpecs    = @$attrSpecs_ref;

    #my $nAttrSpecs3   = $nAttrSpecs * 3;

    printMainForm();
    my $colorLegend1 = getDScoreColorLegend();
    my $colorLegend2 = getPvalueColorLegend();
    my $colorLegend  = $colorLegend1;
    $colorLegend .= "<br/> - " . $colorLegend2;    #if $outType eq "pvalue";
    my $pvalueCutoffMsg = getPvalueCutoffMsg($pagerFileMeta);

    my $url = "$section_cgi&page=dscoreNote";

    printHint(   "- Gene count is shown in parentheses.<br/>\n"
               . "- Click on gene count see constituent genes.<br/>\n"
               . "- <u>Codes</u>: (Q)uery, (R)eference.<br/>\n"
               . "- Mouse over genome abbreviation to see genome name "
               . "and taxon object identifier.<br/>\n"
               . "- $colorLegend<br/>"
               . "$pvalueCutoffMsg\n" );
    printPageHeader( $function, $xcopy, $normalization, $pageNo );

    #printFuncCartFooter();
    my %rightAlign;
    my $idx = 0;
    print "<table class='img' border='1'>\n";
    for my $attrSpec (@$attrSpecs_ref) {
        my ( $colIdx, $attrName, $sortType, $align, $mouseover ) =
          split( /:/, $attrSpec );
        $colIdx    =~ s/\s//g;
        $attrName  =~ s/^\s+//;
        $attrName  =~ s/\s+$//;
        $mouseover =~ s/^\s+//;
        $mouseover =~ s/\s+$//;
        $sortType  =~ s/\s+//g;
        if ( $sortType eq "" ) {
            print "<th class='img'>$attrName</th>\n";
        } else {
            my $url = "$section_cgi&page=abundancePager";
            $url .= "&sortType=$sortType";
            $url .= "&function=$function";
            $url .= "&xcopy=$xcopy";
            $url .= "&normalization=$normalization";
            $url .= "&colIdx=$colIdx";
            $url .= "&pageNo=1";
            $url .= "&funcsPerPage=$funcsPerPage";
            my $x;
            $x = "title='$mouseover'" if $mouseover ne "";
            my $link = "<a href='$url' $x>$attrName</a>";

            #print "<th class='img'>$link</th>\n";
            if ( $idx > 2 && ( ( $idx - 3 ) % 3 == 0 ) ) {

                # color gene count column
                print "<th class='img' bgcolor=#D2E6FF>$link</th>\n";

                # print a column spacer
                if ( $idx < $#$attrSpecs_ref ) {
                    print "<th class='img'> &nbsp; </th>\n";
                }
            } else {
                print "<th class='img'>$link</th>\n";
            }
        }
        if ( $align =~ /right/ ) {
            $rightAlign{$idx} = 1;
        }
        $idx++;
    }
    my $fpos = getFilePosition( $pagerFileIdx,    $pageNo );
    my $rfh  = newReadFileHandle( $pagerFileRows, "printOnePage" );
    seek( $rfh, $fpos, 0 );
    my $count = 0;
    while ( my $s = $rfh->getline() ) {

        #webLog("\n$s\n");
        my (@vals) = split( /\t/, $s );

        my $nVals = @vals;
        $count++;
        if ( $count > $funcsPerPage ) {
            last;
        }
        print "<tr class='img'>\n";

        # 0 to 5 number of nAttrSpec, but its
        # 0 to 4 with out select checkbox
        for ( my $i = 0 ; $i < $nAttrSpecs ; $i++ ) {
            my $right = $rightAlign{$i};
            my $alignSpec;
            $alignSpec = "align='right'" if $right;

            # data file
            # from 0 to 17, but without select checkbox
            # its from 0 to  14
            # still in groups of 3
            my $val         = $vals[ $i * 3 ];
            my $val_display = $vals[ ( $i * 3 ) + 1 ];
            my $flag        = $vals[ ( $i * 3 ) + 2 ];

            #my $tmp        = $vals[ ( $i * 4 ) + 3 ];

            $flag =~ s/\s+//g;
            my $colorSpec;
            my $color;

            my $gene_column = 0;
            if ( $i > 2 && ( ( $i - 3 ) % 3 == 0 ) ) {

                # color gene count column
                $color       = "";
                $colorSpec   = "bgcolor=#D2E6FF";
                $gene_column = 1;
            }

            if ( $i > 3 && ( ( $i - 4 ) % 3 == 0 ) ) {
                if ( blankStr($flag) ) {
                    $color = getDScoreColor($val);
                }
            }
            if ( $i > 4 && ( ( $i - 5 ) % 3 == 0 ) ) {
                if ( blankStr($flag) ) {
                    $color = getPvalueColor($val);
                }
            }

            $colorSpec = "bgcolor='$color'" if $color ne "";
            print "<td class='img' $colorSpec $alignSpec>$val_display</td>\n";

            # print a column spacer
            if ( $gene_column == 1 && $i < ( $nAttrSpecs - 1 ) ) {
                print "<td class='img'> &nbsp; </td>\n";
            }
        }
        print "</tr>\n";
    }
    close $rfh;
    print "</table>\n";

    #printFuncCartFooter();
    printPageHeader( $function, $xcopy, $normalization, $pageNo );
    my $url = "$section_cgi&page=queryForm";
    print buttonUrl( $url, "Start Over", "medbutton" );
    print end_form();
}

############################################################################
# getPvalueCutoffMsg - Get pvalue cutoff message.
############################################################################
sub getPvalueCutoffMsg {
    my ($inMetaFile) = @_;

    my $msg       = "<br/>" . "- <i>P-value</i> cutoffs for False Discovery Rate ($fdr).<br/>\n";
    my $rfh       = newReadFileHandle( $inMetaFile, "getPvalueCutoffs" );
    my $inSection = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        if ( $s =~ /^\.pvalueCutoffsStart/ ) {
            $inSection = 1;
        } elsif ( $s =~ /^\.pvalueCutoffsEnd/ ) {
            $inSection = 0;
            last;
        } elsif ($inSection) {
            my ( $taxon_oid, $pvalue_cutoff, @toks ) = split( / /, $s );
            my $name = join( ' ', @toks );
            $msg .= "-- <i>$name (P-value</i> &le; $pvalue_cutoff)<br/>\n";
        }
    }
    close $rfh;
    return $msg;
}
############################################################################
# loadMetaData - Load metadata about the pager.
############################################################################
sub loadMetaData {
    my ($inFile) = @_;

    my %meta;
    my $rfh = newReadFileHandle( $inFile, "loadMetaData" );
    my $inAttrs = 0;
    my @attrSpecs;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        if ( $s =~ /^\.attrNameStart/ ) {
            $inAttrs = 1;
        } elsif ( $s =~ /^\.attrNameEnd/ ) {
            $meta{attrSpecs} = \@attrSpecs;
            $inAttrs = 0;
        } elsif ($inAttrs) {
            push( @attrSpecs, $s );
        } elsif ( $s =~ /^\./ ) {
            my ( $tag, @toks ) = split( / /, $s );
            $tag =~ s/^\.//;
            my $val = join( ' ', @toks );
            $meta{$tag} = $val;
        }
    }
    close $rfh;
    return %meta;
}

############################################################################
# printPageHeader - Print header with all the pages.
############################################################################
sub printPageHeader {
    my ( $function, $xcopy, $normalization, $currPageNo ) = @_;

    my $filePagerRoot = getPagerFileRoot( $function, $xcopy, $normalization );

    #print "filePagerRoot: $filePagerRoot<br/>\n";
    my $idxFile = "$filePagerRoot.idx";
    my $rfh = newReadFileHandle( $idxFile, "printPageHeader" );
    print "<p>\n";
    print "Pages:";
    my $lastPageNo = 1;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $pageNo, $fpos ) = split( / /, $s );
        print nbsp(1);
        if ( $pageNo eq $currPageNo ) {
            print "[";
        }
        my $url = "$section_cgi&page=abundancePager";
        $url .= "&function=$function";
        $url .= "&xcopy=$xcopy";
        $url .= "&normalization=$normalization";
        $url .= "&pageNo=$pageNo";
        print alink( $url, $pageNo );
        if ( $pageNo eq $currPageNo ) {
            print "]";
        }
        $lastPageNo = $pageNo;
    }
    if ( $currPageNo < $lastPageNo ) {
        print nbsp(1);
        my $nextPageNo = $currPageNo + 1;
        my $url        = "$section_cgi&page=abundancePager";
        $url .= "&function=$function";
        $url .= "&xcopy=$xcopy";
        $url .= "&normalization=$normalization";
        $url .= "&pageNo=$nextPageNo";
        print "[" . alink( $url, "Next Page" ) . "]";
    }
    close $rfh;
    print "<br/>\n";
    my $url = "$section_cgi&page=abundanceDownload";
    $url .= "&function=$function";
    $url .= "&xcopy=$xcopy";
    $url .= "&normalization=$normalization";
    $url .= "&noHeader=1";
    my $contact_oid = WebUtil::getContactOid();
    print alink( $url, "Download tab-delimited file for Excel", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link abundanceDownload']);" );
    print "</p>\n";
}

############################################################################
# getFilePosition - Get file positino given page no.
############################################################################
sub getFilePosition {
    my ( $idxFile, $currPageNo ) = @_;

    my $rfh = newReadFileHandle( $idxFile, "getFilePosition" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $pageNo, $fpos ) = split( / /, $s );
        if ( $pageNo eq $currPageNo ) {
            close $rfh;
            return $fpos;
        }
    }
    close $rfh;
    return 0;
}

#
# Get sub function counts
#
# cog path => cog
#
sub getFunctionCounts {
    my ( $dbh, $func ) = @_;

    my $sql;
    if ( $func eq "cogp" ) {
        $sql = qq{
            select cog_pathway_oid, count(distinct cog_members)
            from cog_pathway_cog_members
            group by cog_pathway_oid
        };

    } elsif ( $func eq "cogc" ) {
        $sql = qq{
            select cfs.functions, count( distinct cfs.cog_id )
            from cog_functions cfs
            group by cfs.functions
        };

    } elsif ( $func eq "keggp" ) {
        $sql = qq{
            select kp.pathway_oid, count(distinct kt.enzymes)
            from ko_term_enzymes kt, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.pathway_oid
        };

    } elsif ( $func eq "keggc" ) {
        $sql = qq{
            select kp.category, count(distinct kt.enzymes)
            from ko_term_enzymes kt, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.category
        };

    } elsif ( $func eq "keggp_ko" ) {

        # ko version
        $sql = qq{
            select kp.pathway_oid, count(distinct rk.ko_terms)
            from image_roi_ko_terms rk,
            image_roi ir, kegg_pathway kp
            where rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.pathway_oid
        };

    } elsif ( $func eq "keggc_ko" ) {

        # ko version
        $sql = qq{
            select kp.category, count(distinct rk.ko_terms)
            from image_roi_ko_terms rk,
            image_roi ir, kegg_pathway kp
            where rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.category
        };

    } elsif ( $func eq "pfam" ) {
        $sql = qq{
            select cp.cog_pathway_oid, count(distinct pfc.ext_accession)
            from pfam_family_cogs pfc, cog_function cf, cog_pathway cp
            where pfc.functions = cf.function_code
            and cf.function_code = cp.function
            group by cp.cog_pathway_oid
        };

    } elsif ( $func eq "tigrfam" ) {
        $sql = qq{
            select tr.sub_role, count(distinct trs.ext_accession)
            from tigr_role tr, tigrfam_roles trs
            where tr.role_id = trs.roles
            and tr.sub_role != 'Other'
            group by tr.sub_role
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose );

    my %hash;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();


    return \%hash;
}

############################################################################
# getCombinedProfileVectors
############################################################################
sub getCombinedProfileVectors {
    my ( $dbh, $type, $taxonOids_ref, $func, $xcopy, $taxonProfiles1_ref, $taxonProfiles2_ref, $data_type ) = @_;

    #$taxonProfiles1_ref: taxonid => cat => gene count
    #$taxonProfiles2_ref: taxonid => cat => func id => gene count

    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile( $dbh, @$taxonOids_ref );
    my $func_type = getFuncCateFuncType($func);

    for my $taxon_oid (@$taxonOids_ref) {
        print "Finding $type $func $xcopy profile for <i>$taxon_oid</i> ...<br/>\n";
        if ( $mer_fs_taxons{$taxon_oid} ) {

            my $cat2funcIds_href = getCat2FuncIds( $dbh, $func );
            #print "cat2funcIds: <br/>\n";
            #print Dumper($cat2funcIds_href);
            #print "<br/>\n";

            my %gene_est_copy;
            if ( $xcopy ne 'gene_count' && $data_type ne 'unassembled' ) {
                print "Computing $taxon_oid assembled $func_type gene est copies ...<br/>\n";
                MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled', \%gene_est_copy );
            }

            #print "Computing $taxon_oid $data_type $func_type genes ...<br/>\n";
            #my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $data_type, $func_type );
            #print Dumper(\%func_genes);
            #print "<br/>\n";

            my %profile1;
            my %profile2;
            my @type_list = MetaUtil::getDataTypeList( $data_type );
            foreach my $t2 (@type_list) {
                print "Computing $taxon_oid $t2 $func_type genes ...<br/>\n";
                my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_type );
                #print Dumper(\%func_genes);
                #print "<br/>\n";

                for my $cat (keys %$cat2funcIds_href) {
                    my $func_ids_ref = $cat2funcIds_href->{$cat};
                    #my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $data_type, $func_type, $func_ids_ref );
                    #print "getFuncVector() $cat func_genes for @$func_ids_ref: <br/>\n";
                    #print Dumper(\%func_genes);
                    #print "<br/>\n";

                    if ( !exists $profile2{$cat} ) {
                        my %funcHash;
                        $profile2{$cat} = \%funcHash;
                    }
                    my $func2cnt_href = $profile2{$cat};

                    my %genes_h;
                    for my $func_id ( @$func_ids_ref ) {
                        my @funcGenes = split( /\t/, $func_genes{$func_id} );

                        my $cnt = 0;
                        for my $gene (@funcGenes) {
                            $genes_h{$gene} = 1;

                            if ( $xcopy eq 'gene_count' ) {
                                $cnt++;
                            }
                            else {
                                my $copies = 1;
                                if ( $gene_est_copy{$gene} ) {
                                    $copies = $gene_est_copy{$gene};
                                }
                                $cnt += $copies;
                            }
                        }
                        $func2cnt_href->{$func_id} += $cnt;
                    }

                    my $cnt;
                    if ( $xcopy eq 'gene_count' ) {
                        $cnt = scalar(keys %genes_h);
                    }
                    else {
                        for my $gene ( keys %genes_h ) {
                            my $copies = 1;
                            if ( $gene_est_copy{$gene} ) {
                                $copies = $gene_est_copy{$gene};
                            }
                            $cnt += $copies;
                        }
                    }
                    $profile1{$cat} += $cnt;
                }

            }

            $taxonProfiles1_ref->{$taxon_oid} = \%profile1;
            $taxonProfiles2_ref->{$taxon_oid} = \%profile2;

        }
        else {

            # DB
            my ( $cur ) = getFuncCatProfileCur( $dbh, $xcopy, $func, $taxon_oid );
            my %profile1;
            for ( ; ; ) {
                my ( $id, $cnt ) = $cur->fetchrow();
                last if !$id;
                $profile1{$id} = $cnt;
            }
            $taxonProfiles1_ref->{$taxon_oid} = \%profile1;
            $cur->finish();

            my ( $cur ) = getFuncCatFuncIdProfileCur( $dbh, $xcopy, $func, $taxon_oid );
            my %profile2;
            for ( ; ; ) {
                my ( $cat, $func_id, $cnt ) = $cur->fetchrow();
                last if !$cat;

                if ( exists $profile2{$cat} ) {
                    my $func_href = $profile2{$cat};
                    $func_href->{$func_id} = $cnt;
                } else {
                    my %funcHash;
                    $funcHash{$func_id} = $cnt;
                    $profile2{$cat} = \%funcHash;
                }
            }
            $taxonProfiles2_ref->{$taxon_oid} = \%profile2;
            $cur->finish();
        }
    }

}

############################################################################
# getProfileVectors
# not used
############################################################################
sub getProfileVectors {
    my ( $dbh, $type, $taxonOids_ref, $func, $xcopy, $taxonProfiles_ref, $data_type ) = @_;

    #$taxonProfiles_ref: taxonid => cat => gene count

    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile( $dbh, @$taxonOids_ref );
    my $func_type = getFuncCateFuncType($func);

    for my $taxon_oid (@$taxonOids_ref) {
        print "Finding $type $func profile for <i>$taxon_oid</i> ...<br/>\n";
        if ( $mer_fs_taxons{$taxon_oid} ) {

            print "Computing $taxon_oid $data_type $func_type genes ...<br/>\n";
            my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $data_type, $func_type );
            #print Dumper(\%func_genes);
            #print "<br/>\n";

            my %gene_est_copy;
            if ( $xcopy eq 'gene_count' ) {
                print "Computing $taxon_oid $data_type $func gene count ...<br/>\n";
            }
            else {
                print "Computing $taxon_oid $data_type $func est copy ...<br/>\n";
                if ( $data_type ne 'unassembled' ) {
                    MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled', \%gene_est_copy );
                }
            }

            my $cat2funcIds_href = getCat2FuncIds( $dbh, $func );
            #print "cat2funcIds: <br/>\n";
            #print Dumper($cat2funcIds_href);
            #print "<br/>\n";

            my %profile;
            for my $cat (keys %$cat2funcIds_href) {
                my $func_ids_ref = $cat2funcIds_href->{$cat};
                #my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $data_type, $func_type, $func_ids_ref );
                #print "getFuncVector() $cat func_genes for @$func_ids_ref: <br/>\n";
                #print Dumper(\%func_genes);
                #print "<br/>\n";

                my %genes_h;
                for my $func_id ( @$func_ids_ref ) {
                    my @funcGenes = split( /\t/, $func_genes{$func_id} );
                    for my $gene (@funcGenes) {
                        $genes_h{$gene} = 1;
                    }
                }

                my $cnt;
                if ( $xcopy eq 'gene_count' ) {
                    $cnt = scalar(keys %genes_h);
                }
                else {
                    for my $gene ( keys %genes_h ) {
                        my $copies = 1;
                        if ( $gene_est_copy{$gene} ) {
                            $copies = $gene_est_copy{$gene};
                        }
                        $cnt += $copies;
                    }
                }
                if ( $profile{$cat} ) {
                    $profile{$cat} += $cnt;
                } else {
                    $profile{$cat} = $cnt;
                }

            }

            $taxonProfiles_ref->{$taxon_oid} = \%profile;

        }
        else {

            # DB
            my ( $cur ) = getFuncCatProfileCur( $dbh, $xcopy, $func, $taxon_oid );

            my %profile;
            for ( ; ; ) {
                my ( $id, $cnt ) = $cur->fetchrow();
                last if !$id;
                $profile{$id} = $cnt;
            }
            $taxonProfiles_ref->{$taxon_oid} = \%profile;
            $cur->finish();
        }
    }

}

############################################################################
# getProfileVectors2
# not used
############################################################################
sub getProfileVectors2 {
    my ( $dbh, $type, $taxonOids_ref, $func, $xcopy, $taxonProfiles_ref, $data_type ) = @_;

    #$taxonProfiles_ref: taxonid => cat => func id => gene count

    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile( $dbh, @$taxonOids_ref );
    my $func_type = getFuncCateFuncType($func);

    # taxonid => cat => func id => gene count

    for my $taxon_oid (@$taxonOids_ref) {
        print "Finding $type $func profile for <i>$taxon_oid</i> ...<br/>\n";
        if ( $mer_fs_taxons{$taxon_oid} ) {

            my %func_cnt;
            if ( $xcopy eq 'gene_count' ) {
                print "Computing $taxon_oid $data_type $func gene count ...<br/>\n";
                %func_cnt = MetaUtil::getTaxonFuncCount( $taxon_oid, $data_type, $func_type );
            }
            else {
                print "Computing $taxon_oid $data_type $func est copy ...<br/>\n";
                my ($func_cnt_href, $last_id1) = AbundanceToolkit::getMetaTaxonFuncEstCopies(
                    $dbh, $taxon_oid, $func_type, $data_type );
                %func_cnt = %$func_cnt_href;
            }

            my $cat2funcIds_href = getCat2FuncIds( $dbh, $func );
            #print "cat2funcIds: <br/>\n";
            #print Dumper($cat2funcIds_href);
            #print "<br/>\n";

            my %profile;
            for my $cat (keys %$cat2funcIds_href) {
                my $func_ids_ref = $cat2funcIds_href->{$cat};

                if ( exists $profile{$cat} ) {
                    my $func_href = $profile{$cat};
                    for my $func_id ( @$func_ids_ref ) {
                        my $cnt = $func_cnt{$func_id};
                        $func_href->{$func_id} = $cnt;
                    }
                } else {
                    my %funcHash;
                    for my $func_id ( @$func_ids_ref ) {
                        my $cnt = $func_cnt{$func_id};
                        $funcHash{$func_id} = $cnt;
                    }
                    $profile{$cat} = \%funcHash;
                }
            }
            $taxonProfiles_ref->{$taxon_oid} = \%profile;

        }
        else {

            # DB
            my ( $cur ) = getFuncCatFuncIdProfileCur( $dbh, $xcopy, $func, $taxon_oid );

            my %profile;
            for ( ; ; ) {
                my ( $cat, $func_id, $cnt ) = $cur->fetchrow();
                last if !$cat;

                if ( exists $profile{$cat} ) {
                    my $func_href = $profile{$cat};
                    $func_href->{$func_id} = $cnt;
                } else {
                    my %funcHash;
                    $funcHash{$func_id} = $cnt;
                    $profile{$cat} = \%funcHash;
                }
            }
            $taxonProfiles_ref->{$taxon_oid} = \%profile;
            $cur->finish();
        }
    }

}

############################################################################
# getFuncCateFuncType - Get MER-FS func type from function category
############################################################################
sub getFuncCateFuncType {
    my ($func) = @_;

    my $func_type;
    if ( $func eq 'cogp' || $func eq 'cogc' ) {
        $func_type = 'cog';
    } elsif ( $func eq 'keggp' || $func eq 'keggc' ) {
        $func_type = 'enzyme';
    } elsif ( $func eq 'keggp_ko' || $func eq 'keggc_ko' ) {
        $func_type = 'ko';
    } elsif ( $func eq 'pfam' ) {
        $func_type = 'pfam';
    } elsif ( $func eq 'tigrfam' ) {
        $func_type = 'tigrfam';
    }

    return $func_type;
}

############################################################################
# getFuncCatProfileCur - Get function category profile cur for a taxon.
############################################################################
sub getFuncCatProfileCur {
    my ( $dbh, $xcopy, $func_type, $taxon_oid ) = @_;

    my $aggFunc;
    if ( $xcopy eq "est_copy" ) {
        $aggFunc = "sum( g.est_copy )";
    }
    else {
        $aggFunc = "count( distinct g.gene_oid )";
    }

    my $sql;

    if ( $func_type eq "cogp" ) {
        $sql = qq{
            select cpcm.cog_pathway_oid, $aggFunc
            from gene g, gene_cog_groups gcg, cog_pathway_cog_members cpcm
            where g.taxon = ?
            and g.gene_oid = gcg.gene_oid
            and gcg.cog = cpcm.cog_members
            group by cpcm.cog_pathway_oid
        };
    } elsif ( $func_type eq "cogc" ) {
        $sql = qq{
            select cf.function_code, $aggFunc
            from gene g, gene_cog_groups gcg,
                cog_functions cfs, cog_function cf
            where g.taxon = ?
            and g.gene_oid = gcg.gene_oid
            and gcg.cog = cfs.cog_id
            and cfs.functions = cf.function_code
            group by cf.function_code
        };
    } elsif ( $func_type eq "keggp" ) {
        $sql = qq{
            select kp.pathway_oid, $aggFunc
            from gene g, gene_ko_enzymes ge,
                ko_term_enzymes kt, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = ge.gene_oid
            and ge.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.pathway_oid
        };
    } elsif ( $func_type eq "keggc" ) {
        $sql = qq{
            select kp.category, $aggFunc
            from gene g, gene_ko_enzymes ge,
                ko_term_enzymes kt, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = ge.gene_oid
            and ge.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.category
        };
    } elsif ( $func_type eq "keggp_ko" ) {
        $sql = qq{
            select kp.pathway_oid, $aggFunc
            from gene g, gene_ko_terms gk, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = gk.gene_oid
            and gk.ko_terms = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.pathway_oid
        };
    } elsif ( $func_type eq "keggc_ko" ) {
        $sql = qq{
            select kp.category, $aggFunc
            from gene g, gene_ko_terms gk, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = gk.gene_oid
            and gk.ko_terms = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.category
        };
    } elsif ( $func_type eq "pfam" ) {
        $sql = qq{
            select cp.cog_pathway_oid, $aggFunc
            from gene g, gene_pfam_families gpf, pfam_family_cogs pfc,
                cog_function cf, cog_pathway cp
            where g.taxon = ?
            and g.gene_oid = gpf.gene_oid
            and gpf.pfam_family = pfc.ext_accession
            and pfc.functions = cf.function_code
            and cf.function_code = cp.function
            group by cp.cog_pathway_oid
        };
    } elsif ( $func_type eq "tigrfam" ) {
        $sql = qq{
            select tr.sub_role, $aggFunc
            from gene_tigrfams gtf, gene g, tigr_role tr, tigrfam_roles trs
            where g.taxon = ?
            and g.gene_oid = gtf.gene_oid
            and gtf.ext_accession = trs.ext_accession
            and trs.roles = tr.role_id
            and tr.sub_role != ?
            group by tr.sub_role
        };
    }
    #print "getFuncCatProfileCur() sql: $sql<br/>\n";

    my $cur;
    if ( $func_type eq "tigrfam" ) {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 'Other'  );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    }

    return ( $cur );
}


############################################################################
# getFuncCatFuncIdProfileCur - Get function category func_id profile cur for a taxon.
############################################################################
sub getFuncCatFuncIdProfileCur {
    my ( $dbh, $xcopy, $func_type, $taxon_oid ) = @_;

    my $aggFunc;
    if ( $xcopy eq "est_copy" ) {
        $aggFunc = "sum( g.est_copy )";
    }
    else {
        $aggFunc = "count( distinct g.gene_oid )";
    }

    my $sql;

    if ( $func_type eq "cogp" ) {
        $sql = qq{
            select cpcm.cog_pathway_oid, gcg.cog, $aggFunc
            from gene g, gene_cog_groups gcg, cog_pathway_cog_members cpcm
            where g.taxon = ?
            and g.gene_oid = gcg.gene_oid
            and cpcm.cog_members = gcg.cog
            group by cpcm.cog_pathway_oid, gcg.cog
        };
    } elsif ( $func_type eq "cogc" ) {
        $sql = qq{
            select cf.function_code, gcg.cog, $aggFunc
            from gene g, gene_cog_groups gcg,
                cog_function cf, cog_functions cfs
            where g.gene_oid = gcg.gene_oid
            and g.taxon = ?
            and cf.function_code = cfs.functions
            and cfs.cog_id = gcg.cog
            group by cf.function_code, gcg.cog
        };
    } elsif ( $func_type eq "keggp" ) {
        $sql = qq{
            select kp.pathway_oid, ge.enzymes, $aggFunc
            from gene g, gene_ko_enzymes ge,
                ko_term_enzymes kt, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = ge.gene_oid
            and ge.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.pathway_oid, ge.enzymes
        };
    } elsif ( $func_type eq "keggc" ) {
        $sql = qq{
            select kp.category, ge.enzymes, $aggFunc
            from gene g, gene_ko_enzymes ge,
                ko_term_enzymes kt, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = ge.gene_oid
            and ge.enzymes = kt.enzymes
            and kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.category, ge.enzymes
        };
    } elsif ( $func_type eq "keggp_ko" ) {
        $sql = qq{
            select kp.pathway_oid, gk.ko_terms, $aggFunc
            from gene g, gene_ko_terms gk, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = gk.gene_oid
            and gk.ko_terms = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.pathway_oid, gk.ko_terms
        };
    } elsif ( $func_type eq "keggc_ko" ) {
        $sql = qq{
            select kp.category, gk.ko_terms, $aggFunc
            from gene g, gene_ko_terms gk, image_roi_ko_terms rk,
                image_roi ir, kegg_pathway kp
            where g.taxon = ?
            and g.gene_oid = gk.gene_oid
            and gk.ko_terms = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
            group by kp.category, gk.ko_terms
        };
    } elsif ( $func_type eq "pfam" ) {
        $sql = qq{
            select cp.cog_pathway_oid, pfc.ext_accession, $aggFunc
            from gene g, gene_pfam_families gpf, pfam_family_cogs pfc,
                cog_function cf, cog_pathway cp
            where g.gene_oid = gpf.gene_oid
            and g.taxon = ?
            and gpf.pfam_family = pfc.ext_accession
            and pfc.functions = cf.function_code
            and cf.function_code = cp.function
            group by cp.cog_pathway_oid, pfc.ext_accession
        };
    } elsif ( $func_type eq "tigrfam" ) {
        $sql = qq{
            select tr.sub_role, gtf.ext_accession, $aggFunc
            from gene_tigrfams gtf,  gene g,
            tigr_role tr, tigrfam_roles trs
            where g.taxon = ?
            and gtf.gene_oid = g.gene_oid
            and tr.role_id = trs.roles
            and trs.ext_accession = gtf.ext_accession
            and tr.sub_role != ?
            group by tr.sub_role, gtf.ext_accession
            order by tr.sub_role
        };
    }
    #print "getFuncCatProfileCur() sql: $sql<br/>\n";

    my $cur;
    if ( $func_type eq "tigrfam" ) {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, 'Other'  );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    }

    return ( $cur );
}


sub getCat2FuncIds {
    my ( $dbh, $func_type, $cat ) = @_;

    my $sql = "";
    my @binds;
    if ( $func_type eq 'cogp' ) {
        $sql = qq{
            select distinct cog_pathway_oid, cog_members
            from cog_pathway_cog_members
        };
        if ( $cat ) {
           $sql .= " where cog_pathway_oid = ? ";
           @binds = ( $cat );
        }
    } elsif ( $func_type eq 'cogc' ) {
        $sql = qq{
            select distinct functions, cog_id
            from cog_functions
        };
        if ( $cat ) {
           $sql .= " where functions = ? ";
           @binds = ( $cat );
        }
    } elsif ( $func_type eq 'keggp' ) {
        $sql = qq{
            select distinct ir.pathway, kt.enzymes
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
        };
        if ( $cat ) {
           $sql .= " and ir.pathway = ? ";
           @binds = ( $cat );
        }
    } elsif ( $func_type eq 'keggc' ) {
        $sql = qq{
            select distinct kp.category, kt.enzymes
            from ko_term_enzymes kt, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
            where kt.ko_id = rk.ko_terms
            and rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
        };
        if ( $cat ) {
           $sql .= " and kp.category = ? ";
           @binds = ( $cat );
        }
    } elsif ( $func_type eq 'keggp_ko' ) {
        $sql = qq{
            select distinct ir.pathway, rk.ko_terms
            from image_roi_ko_terms rk, image_roi ir
            where rk.roi_id = ir.roi_id
        };
        if ( $cat ) {
           $sql .= " and ir.pathway = ? ";
           @binds = ( $cat );
        }
    } elsif ( $func_type eq "keggc_ko" ) {
        $sql = qq{
            select distinct kp.category, rk.ko_terms
            from image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
            where rk.roi_id = ir.roi_id
            and ir.pathway = kp.pathway_oid
        };
        if ( $cat ) {
           $sql .= " and kp.category = ? ";
           @binds = ( $cat );
        }
    } elsif ( $func_type eq 'pfam' ) {
        $sql = qq{
            select distinct cp.cog_pathway_oid, pfc.ext_accession
            from pfam_family_cogs pfc, cog_function cf, cog_pathway cp
            where pfc.functions = cf.function_code
            and cf.function_code = cp.function
        };
        if ( $cat ) {
           $sql .= " and cp.cog_pathway_oid = ? ";
           @binds = ( $cat );
        }
    } elsif ( $func_type eq 'tigrfam' ) {
        $sql = qq{
            select distinct tr.sub_role, trs.ext_accession
            from tigr_role tr, tigrfam_roles trs
            where tr.role_id = trs.roles
            and tr.sub_role != ?
        };
        @binds = ( 'Other' );
        if ( $cat ) {
           $sql .= " and tr.sub_role = ? ";
           push( @binds, $cat );
        }
    }
    #print "getCat2FuncIds() sql: $sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my %cat2funcIds;
    for ( ; ; ) {
        my ( $cat, $func_id ) = $cur->fetchrow();
        last if !$cat;

        my $funcs_ref = $cat2funcIds{$cat};
        if ( $funcs_ref ) {
            push(@$funcs_ref, $func_id);
        }
        else {
            my @funcs = ($func_id);
            $cat2funcIds{$cat} = \@funcs;
        }
    }
    $cur->finish();

    return \%cat2funcIds;
}

############################################################################
# printGeneList  - User clicked on link to select genes for
#    funcId / taxon_oid.
############################################################################
sub printGeneList {

    my $cat       = param("funcId");
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $function  = param("function");
    my $xcopy     = param("xcopy");

    printMainForm();
    print "<h1>Function Comparison Genes</h1>\n";

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "data_type", $data_type );

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    my $isTaxonInFile = printAbundanceCategoryGeneListSubHeader(
        $dbh, $function, $cat, $taxon_oid, $data_type);

    # get gene oids
    my @gene_oids = ();
    if ( $isTaxonInFile ) {

        my $cat2funcIds_href = getCat2FuncIds( $dbh, $function, $cat );
        my $func_ids_ref = $cat2funcIds_href->{$cat};
        #print "printGeneList() func ids for $cat: @$func_ids_ref<br/>\n";

        my %gene_h;
        my $func_type = getFuncCateFuncType($function);

        my @type_list = MetaUtil::getDataTypeList( $data_type );
        foreach my $t2 (@type_list) {
            my %func_genes = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $func_type, $func_ids_ref );
            #print "printGeneList() $cat func_genes for @$func_ids_ref: <br/>\n";
            #print Dumper(\%func_genes);
            #print "<br/>\n";

            for my $func_id2 ( @$func_ids_ref ) {
                my @funcGenes = split( /\t/, $func_genes{$func_id2} );

                for my $g2 (@funcGenes) {
                    my $workspace_id = "$taxon_oid $t2 $g2";
                    $gene_h{$workspace_id} = $workspace_id;
                }
            }
        }

        @gene_oids = ( keys %gene_h );

    } else {

        my $sql;
        if ( $function eq "cogp" ) {

            # fix cog_functions query
            $sql = qq{
                select distinct g.gene_oid
                from gene_cog_groups g, cog_pathway_cog_members cpcm
                where g.taxon = ?
                and g.cog = cpcm.cog_members
                and cpcm.cog_pathway_oid = ?
                order by g.gene_oid
            };


        } elsif ( $function eq "cogc" ) {

            # fix cog_functions query
            $sql = qq{
                select distinct g.gene_oid
                from gene_cog_groups g, cog_functions cfs
                where g.taxon = ?
                and g.cog = cfs.cog_id
                and cfs.functions = ?
                order by g.gene_oid
            };


        } elsif ( $function eq "keggp" ) {

            #  keggp - ken
            $sql = qq{
                select distinct g.gene_oid
                from gene_ko_enzymes g, ko_term_enzymes kt,
                    image_roi_ko_terms rk, image_roi ir
                where g.taxon = ?
                and g.enzymes = kt.enzymes
                and kt.ko_id = rk.ko_terms
                and rk.roi_id = ir.roi_id
                and ir.pathway = ?
                order by g.gene_oid
            };

        } elsif ( $function eq "keggc" ) {

            #  fix query
            # keggc - ken
            $sql = qq{
                select distinct g.gene_oid
                from gene_ko_enzymes g, ko_term_enzymes kt,
                    image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
                where g.taxon = ?
                and g.enzymes = kt.enzymes
                and kt.ko_id = rk.ko_terms
                and rk.roi_id = ir.roi_id
                and ir.pathway = kp.pathway_oid
                and kp.category = ?
                order by g.gene_oid
            };


        } elsif ( $function eq "keggp_ko" ) {

            #  ko version
            $sql = qq{
                select distinct g.gene_oid
                from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir
                where g.taxon = ?
                and g.ko_terms = rk.ko_terms
                and rk.roi_id = ir.roi_id
                and ir.pathway = ?
                order by g.gene_oid
            };


        } elsif ( $function eq "keggc_ko" ) {

            # ko version
            $sql = qq{
                select distinct g.gene_oid
                from gene_ko_terms g, image_roi_ko_terms rk, image_roi ir, kegg_pathway kp
                where g.taxon = ?
                and g.ko_terms = rk.ko_terms
                and rk.roi_id = ir.roi_id
                and ir.pathway = kp.pathway_oid
                and kp.category = ?
                order by g.gene_oid
            };


        } elsif ( $function eq "pfam" ) {
            $sql = qq{
                select distinct g.gene_oid
                from gene_pfam_families g, pfam_family_cogs pfc, cog_function cf, cog_pathway cp
                where g.taxon = ?
                and g.pfam_family = pfc.ext_accession
                and pfc.functions = cf.function_code
                and cf.function_code = cp.function
                and cp.cog_pathway_oid = ?
                order by g.gene_oid
            };

        } elsif ( $function eq "tigrfam" ) {
            $sql = qq{
                select distinct g.gene_oid
                from gene_tigrfams g, tigr_role tr, tigrfam_roles trs
                where g.taxon = ?
                and g.ext_accession = trs.ext_accession
                and trs.roles = tr.role_id
                and tr.sub_role = ?
                order by g.gene_oid
            };

        }
        #'$cat'
        my @bindList = ($taxon_oid, $cat);

        my $cur = WebUtil::execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ($gene_oid) = $cur->fetchrow();
            last if !$gene_oid;
            push( @gene_oids, $gene_oid );
        }
        $cur->finish();

    }

    require InnerTable;
    my $it = new InnerTable( 1, "AbundanceFuncCateGenes$$", "AbundanceFuncCateGenes", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    if ( !$isTaxonInFile ) {
        $it->addColSpec( "Locus Tag",     "char asc",   "left" );
    }
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );

    my $select_id_name = "gene_oid";

    my $trunc = 0;
    my $count = 0;
    if ( $isTaxonInFile ) {

        # MER-FS
        my %gene_copies;
        if ( $xcopy eq 'est_copy' && $data_type ne 'unassembled' ) {
            MetaUtil::getTaxonGeneEstCopy( $taxon_oid, 'assembled', \%gene_copies );
        }

        my $sd = $it->getSdDelim();
        for my $workspace_id (@gene_oids) {
            my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );
            $count++;
            if ( $count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }

            my $row = $sd . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
            $row .=
                $workspace_id . $sd
              . "<a href='main.cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$tid"
              . "&data_type=$dt&gene_oid=$id2'>$id2</a></td>\t";

	        my ( $value, $source ) = MetaUtil::getGeneProdNameSource( $id2, $tid, $dt );

            if ( $xcopy eq 'est_copy' ) {
                if ( $gene_copies{$id2} ) {
                    $value .= " (est_copy = " . $gene_copies{$id2} . ")";
                } else {
                    $value .= " (est_copy = 1)";
                }
            }
            $row .= $value . $sd . $value . "\t";

            $it->addRow($row);
        }

        if ( tied(%gene_copies) ) {
            untie %gene_copies;
        }

    } else {

        my @batch;
        for my $gene_oid (@gene_oids) {
            push( @batch, $gene_oid );
            $count++;
            if ( $count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        HtmlUtil::flushGeneBatchSorting( $dbh, \@batch, $it, '', 1 );
    }

    WebUtil::printGeneCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ( $count > 0 ) {
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }

    print end_form();
}

############################################################################
# printAbundanceDownload - Downloads abundance data to Excel.
############################################################################
sub printAbundanceDownload {
    my $function      = param("function");
    my $xcopy         = param("xcopy");
    my $normalization = param("normalization");

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $normalization );
    my $path          = "$pagerFileRoot.xls";

    #webLog("printAbundanceDownload path: $path\n");
    if ( !( -e $path ) ) {
        webErrorHeader( "Session of download has expired. " . "Please start again." );
    }
    my $sz = fileSize($path);

    #print "Content-type: text/plain\n";
    print "Content-type: application/vnd.ms-excel\n";
    my $filename = "abundComp_${function}_$$.tab.xls";
    print "Content-Disposition: inline; filename=$filename\n";
    print "Content-length: $sz\n";
    print "\n";
    my $rfh = newReadFileHandle( $path, "printAbundanceDownload" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}

############################################################################
# getDScoreColor - Get color for absolute values.
############################################################################
sub getDScoreColor {
    my ($val) = @_;

    return "white" if !isNumber($val);

    $val = abs($val);
    if ( $val >= 1.00 && $val <= 1.96 ) {
        return "bisque";
    } elsif ( $val > 1.96 && $val <= 2.33 ) {
        return "pink";
    } elsif ( $val > 2.33 ) {
        return "yellow";
    } else {
        return "white";
    }
}

############################################################################
# getDScoreColorLegend - Get legend string.
############################################################################
sub getDScoreColorLegend {

    my $url = "$section_cgi&page=dscoreNote";

    #print alink( $url, "D-score" ) . nbsp(1);

    my $s = alink( $url, "D-rank" ) . nbsp(1);
    $s .= " (positive or negative) for cell coloring: ";
    $s .= "white < 1.00,
           <span style='background-color:bisque'>bisque</span> = 1.00-1.96,
           <span style='background-color:pink'>pink</span> = 1.96-2.33,
           <span style='background-color:yellow'>yellow</span> > 2.33.";
    return $s;
}

############################################################################
# getPvalueColor - Get color for pvalues.
############################################################################
sub getPvalueColor {
    my ($val) = @_;

    if ( $val >= 0.15 && $val <= 0.25 ) {
        return "bisque";
    } elsif ( $val >= 0.009 && $val < 0.15 ) {
        return "pink";
    } elsif ( $val < 0.009 ) {
        return "yellow";
    } else {
        return "white";
    }
}

############################################################################
# getPvalueColorLegend - Get legend string.
############################################################################
sub getPvalueColorLegend {
    my $s;
    $s .= "P-value for cell coloring: ";
    $s .= "white > 0.15,
      <span style='background-color:bisque'>bisque</span> = 0.25-0.15,
      <span style='background-color:pink'>pink</span> = 0.15-0.009,
      <span style='background-color:yellow'>yellow</span> < 0.009.";
    return $s;
}

############################################################################
# getDScores - Get Daniel's binomial assumption d-score.
#
# Input:
#    @param outType - output type
#    @param q_ref - query profile
#    @param r_ref - reference profile
# Output:
#    @param dscores_ref - Output hash of function to d-score
#    @param flags_ref - Output hash for flags with invalid test.
#
############################################################################
sub getDScores_old {
    my ( $outType, $q_ref, $r_ref, $dscores_ref, $flags_ref ) = @_;

    my $doAbs;
    if ( $outType eq "dscoreAbs" ) {
        $doAbs = 1;
    }

    # sum up all the query cnts - ken
    ## n1
    my @keys   = sort( keys(%$q_ref) );
    my $nKeys1 = @keys;
    my $n1     = 0;
    for my $k (@keys) {
        my $cnt = $q_ref->{$k};
        $n1 += $cnt;
    }

    # sum up a ref genome cnts - ken
    ## n2
    my @keys   = sort( keys(%$r_ref) );
    my $nKeys2 = @keys;
    my $n2     = 0;
    for my $k (@keys) {
        my $cnt = $r_ref->{$k};
        $n2 += $cnt;
    }
    if ( $nKeys1 != $nKeys2 ) {
        webDie("getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match\n");
    }
    if ( $n1 < 1 || $n2 < 1 ) {
        webLog("getDScores: n1=$n1 n2=$n2: no hits to calculate\n");
        return ( $n1, $n2 );
    }
    webLog("getDScores: n1=$n1 n2=$n2\n");

    my @keys       = sort( keys(%$q_ref) );
    my $undersized = 0;
    for my $id (@keys) {
        my $x1  = $q_ref->{$id};
        my $x2  = $r_ref->{$id};
        my $p1  = $x1 / $n1;
        my $p2  = $x2 / $n2;
        my $p   = ( $x1 + $x2 ) / ( $n1 + $n2 );
        my $q   = 1 - $p;
        my $num = $p1 - $p2;
        my $den = sqrt( $p * $q * ( ( 1 / $n1 ) + ( 1 / $n2 ) ) );
        my $d   = 0;
        $d = ( $num / $den ) if $den > 0;
        $d = abs($d)         if $doAbs;
        $dscores_ref->{$id} = $d;

        if ( !isValidTest( $n1, $n2, $x1, $x2 ) ) {
            $flags_ref->{$id} = "undersized";
            $undersized++;
        }
    }
    webLog("$undersized / $nKeys2 undersized\n");
    return ( $n1, $n2 );
}

# d-score is on the sub-system gene counts
# e.g. cog pathway, cog id, gene count
#
# $q_ref - query metag pathid => cog id => cnt
# $r_ref - ref   metag pathid => cog id => cnt
sub getDScores2 {
    my ( $outType, $q_ref, $r_ref, $dscores_ref, $flags_ref ) = @_;

    # to be implemented
    my $mincount = param("mincount");
    webLog("======== min count => $mincount\n");
    if ( $mincount eq '-' ) {
        $mincount = 0;
    }

    #    my $doAbs;
    #    if ( $outType eq "dscoreAbs" ) {
    #        $doAbs = 1;
    #    }

    # sum up all the query cnts - ken
    ## n1
    my $n1 = 0;
    foreach my $pid ( sort( keys(%$q_ref) ) ) {
        my $href = $q_ref->{$pid};
        foreach my $cid ( keys %$href ) {
            my $cnt = $href->{$cid};
            $n1 += $cnt;
        }
    }

    # sum up a ref genome cnts - ken
    ## n2
    my $n2 = 0;
    foreach my $pid ( sort( keys(%$r_ref) ) ) {
        my $href = $r_ref->{$pid};
        foreach my $cid ( keys %$href ) {
            my $cnt = $href->{$cid};
            $n2 += $cnt;
        }
    }

    webLog("getDScores: n1=$n1 n2=$n2\n");

    # path id = > cog id => d score
    my %results;

    my $undersized = 0;
    foreach my $id ( sort keys(%$q_ref) ) {
        my $href = $q_ref->{$id};

        my %subResults;
        my $undersized = 0;
        foreach my $cid ( keys %$href ) {
            my $x1 = $href->{$cid};
            my $x2 = $r_ref->{$id}->{$cid};
            $x2 = 0 if ( $x2 eq "" );

            # add the "5" in the query form
            if ( $x1 >= $mincount && $x2 >= $mincount ) {
                my $p1  = $x1 / $n1;
                my $p2  = $x2 / $n2;
                my $p   = ( $x1 + $x2 ) / ( $n1 + $n2 );
                my $q   = 1 - $p;
                my $num = $p1 - $p2;
                my $den = sqrt( $p * $q * ( ( 1 / $n1 ) + ( 1 / $n2 ) ) );
                my $d   = 0;
                $d = ( $num / $den ) if $den > 0;

                #$d = abs($d)         if $doAbs;

                $subResults{$cid} = $d;
            } else {
                $subResults{$cid} = 0;
                $undersized++;
            }
        }
        $flags_ref->{$id} = "undersized" if $undersized > 0;
        $results{$id} = \%subResults;

        #if ( !isValidTest( $n1, $n2, $x1, $x2 ) ) {
        #     $flags_ref->{$id} = "undersized";
        #     $undersized++;
        #}
    }

    return \%results;
}

############################################################################
# isValidTest - Heursitics to see if test is sufficent size to be valid.
############################################################################
sub isValidTest {
    my ( $n1, $n2, $x1, $x2 ) = @_;

    my $mincount = param("mincount");

    return 1 if $x1 >= $mincount && $x2 >= $mincount;

    ##--es 10/18/2007
    return 1 if $x1 + $x2 >= 10 && $x1 > $x2 && $n2 >= $n1;
    return 1 if $x1 + $x2 >= 10 && $x2 > $x1 && $n1 >= $n2;

    return 0;
}

############################################################################
# getPvalues - Get pvalues given z (or d-score in this case).
#
#  Input:
#    @param taxonDscores_ref - Hash of taxon_oid -> dd-score hash
#
#  Output:
#    @param taxonPvalues_ref - Hash of taxon_oid -> hash p-values.
############################################################################
sub getPvalues {
    my ( $taxonDscores_ref, $taxonPvalues_ref, $taxonPvalueCutoffs_ref, $taxonFlags_ref ) = @_;

    my $tmpDscoreFile = "$cgi_tmp_dir/xdscores$$.txt";
    my $tmpRcmdFile   = "$cgi_tmp_dir/xrcmd$$.r";
    my $tmpRoutFile   = "$cgi_tmp_dir/xrout$$.txt";
    my $wfh           = newWriteFileHandle( $tmpDscoreFile, "getPvalues" );
    my $nFuncs        = 0;
    my @funcIds;
    my @taxon_oids = sort( keys(%$taxonDscores_ref) );
    for my $taxon_oid (@taxon_oids) {
        my $dscores_ref = $taxonDscores_ref->{$taxon_oid};
        my @keys        = sort( keys(%$dscores_ref) );
        my $nFuncs2     = @keys;
        if ( $nFuncs > 0 && $nFuncs != $nFuncs2 ) {
            webDie( "getPvalues: taxon_oid=$taxon_oid " . "nFuncs=$nFuncs nFuncs2=$nFuncs2\n" );
        }

        ## Store order of funcIds
        for my $k (@keys) {
            push( @funcIds, $k );
        }
        $nFuncs = $nFuncs2;
        my $s;
        for my $k (@keys) {
            my $v = abs( $dscores_ref->{$k} );
            $s .= "$v\t";
        }
        chop $s;
        print $wfh "$s\n";
    }
    close $wfh;

    my $wfh = newWriteFileHandle( $tmpRcmdFile, "getPvalues" );
    print $wfh "t1 <- read.table( '$tmpDscoreFile', sep='\\t', header=F )\n";
    print $wfh "m1 <- as.matrix( t1 )\n";
    print $wfh "m2 <- 1 - pnorm( abs( m1 ) )\n";
    print $wfh "write.table( m2, file='$tmpRoutFile', ";
    print $wfh "row.names=F, col.names=F )\n";
    close $wfh;
    WebUtil::unsetEnvPath();

    webLog("Running R pnorm( )\n");
    my $env = "PATH='/bin:/usr/bin'; export PATH";
    my $cmd = "$env; $r_bin --slave < $tmpRcmdFile > /dev/null";
    webLog("+ $cmd\n");
    my $st = system($cmd );
    WebUtil::resetEnvPath();

    if ( !( -e $tmpRoutFile ) ) {
        print "<p>Cannot find $tmpRoutFile\n";
        wunlink($tmpDscoreFile);
        wunlink($tmpRcmdFile);
        return;
    }

    my $rfh = newReadFileHandle( $tmpRoutFile, "getPvalues" );
    my @pvalues;
    my $taxon_idx = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my @pvalues = split( / /, $s );
        my $nPvalues = @pvalues;
        if ( $nPvalues != $nFuncs ) {
            webDie("getPvalues: nPvalues=$nPvalues nFuncs=$nFuncs\n");
        }
        my %funcPvalues;
        for ( my $i = 0 ; $i < $nPvalues ; $i++ ) {
            my $funcId = $funcIds[$i];
            my $pvalue = $pvalues[$i];
            $funcPvalues{$funcId} = $pvalue;
        }
        my $taxon_oid = $taxon_oids[$taxon_idx];
        $taxonPvalues_ref->{$taxon_oid} = \%funcPvalues;
        $taxon_idx++;
    }
    close $rfh;

    # Set false discovery rate cutoffs.
    setFdrCutoffs( $taxonPvalues_ref, $taxonFlags_ref, $taxonPvalueCutoffs_ref );

    wunlink($tmpDscoreFile);
    wunlink($tmpRcmdFile);
    wunlink($tmpRoutFile);
}

############################################################################
# printDScoreNote - Print note about D-score calculation.
############################################################################
sub printDScoreNote {
    print "<h1>D-score</h1>\n";
    print "<p>\n";
    print qq{
       D-score uses a binomial distribution
       whereby the "difference" measurement is approximately normally
       distributed with mean 0 and unit variance, <i>N(0,1)</i>.<br/>
       <br/>
       <b>Data:</b><br/>
       <br/>
       <i>x1</i> = count of a given function in query group.<br/>
       <i>x2</i> = count of a given function
           in reference group.<br/>
       <i>n1</i> = total counts of all function occurrences in query group.<br/>
       <i>n2</i> = total counts of all function occurrences
          in reference group.<br/>
       <br/>
       <b>Computations:</b><br/>
       <br/>
       <i>f1</i> = <i>x1/n1</i> = frequency of functional occurrence
          in query group.<br/>
       <i>f2</i> = <i>x2/n2</i> = frequency of functional occurrence
          in reference group.<br/>
       <i>p = (x1 + x2) / (n1 + n2)</i> = probability of occurrence.<br/>
       <i>q = 1 - p</i> = probability of non-occurrence.<br/>
       <i>d_score = ( f1 - f2 ) / sqrt( p*q * ( 1/n1 + 1/n2 ) )</i><br/>
       <br/>
       <i>pnorm()</i> - probability distribution function for <i>N(0,1)</i><br/>
       <i>p_value = 1.00 - pnorm( abs( d_score ) )</i><br/>
       <br/>
       <b>Qualifications:</b><br/>
       <br/>
       A test is valid if sufficient size for a normal distribution:<br/>
       <br/>
       <i>(Assuming the miniumum count is 5.)</i><br/>
       <i>x1 >= 5 and x2 >= 5</i>.<br/>
       <i>The d_score is set to zero when summing in D-rank
          if not a valid test</i>.</br>
       <br><br>
       <b>D-Rank:</b><br><br>
       A normalization of d-scores.
       <br><br>
       <i>
       D-rank = (sum of selected genome's d-scores) / sqrt(N)
       <br>
       where N is the number of protein families including those without hits.
       </i>
	   <br>
	          <table cellpadding=0 cellspacing=0>
<tr>
	<td align="center">
		<small>N</small><br>
		<big><big><big>&#8721;</big></big></big>
		<small><br>i<small> </small>=<small> </small>1</small>
	</td>
	<td>
		d_score<sub>i</sub><sup>&nbsp;</sup>
	</td>
</tr>
<tr>
	<td>
		<hr>
	</td>
</tr>
<tr>
	<td>
		 &#8730;<span style="text-decoration: overline">N</span>
	</td>
</tr>
</table>

    };
    print "</p>\n";
}

############################################################################
# largeAbbrColName - Abbreviate column name by breaking to 3 lines, first
#  5 letters for genome name to save space.  Link out to genome
#  and allow for mouseover.
############################################################################
sub largeAbbrColName {
    my ( $taxon_oid, $taxon_display_name, $noLink ) = @_;
    $taxon_display_name =~ s/\s+/ /g;
    $taxon_display_name =~ s/[\(\)]+/ /g;
    my @toks = split( / /, $taxon_display_name );
    my $tok0 = substr( $toks[0], 0, 7 );
    my $tok1 = substr( $toks[1], 0, 7 );
    my $nToks = @toks;
    my $tok2  = substr( $toks[ $nToks - 1 ], 0, 7 );
    my $s     = escHtml($tok0) . "<br/>";
    $s .= escHtml($tok1) . "<br/>" if $tok1 ne "";
    $s .= escHtml($tok2)           if $tok2 ne "";
    my $url                 = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_display_name2 = escHtml($taxon_display_name);
    my $link                = "<a href='$url' title='$taxon_display_name2'>$s</a>";
    $link = $s if $noLink;
    return $link;
}
############################################################################
# getPvalueCutoff - Get false discovery rate cutoffs.  Set flags that
#   don't meet the cutoffs.
############################################################################
sub getPvalueCutoff {
    my ($pvalues_href) = @_;

    my @funcIds = keys(%$pvalues_href);
    my $n       = @funcIds;
    my @a;
    for my $funcId (@funcIds) {
        my $pvalue = $pvalues_href->{$funcId};
        push( @a, $pvalue );
    }
    my @b = sort { $a <=> $b } (@a);
    my $last_pvalue = 0;
    for ( my $i = 1 ; $i <= $n ; $i++ ) {
        my $pvalue = $b[$i];
        my $pfdr   = ( $i * $fdr ) / $n;
        if ( $pvalue > $pfdr ) {
            last;
        }
        $last_pvalue = $pvalue;
    }
    return $last_pvalue;
}

############################################################################
# setCutoffFlag - Set cutoff flag for values that exceed false
#   discovery rate (FDR).
############################################################################
sub setCutoffFlag {
    my ( $pvalue_cutoff, $pvalues_href, $flags_href ) = @_;

    my @funcIds = keys(%$pvalues_href);
    for my $funcId (@funcIds) {
        my $pvalue = $pvalues_href->{$funcId};
        if ( $pvalue > $pvalue_cutoff ) {
            $flags_href->{$funcId} = "fdr_cutoff";
        }
    }
}

############################################################################
# setFdrCutoffs - Set flags for false discovery rate.
############################################################################
sub setFdrCutoffs {
    my ( $taxonPvalues_ref, $taxonFlags_ref, $taxonPvalueCutoffs_ref ) = @_;

    my @taxon_oids = sort( keys(%$taxonPvalues_ref) );
    for my $taxon_oid (@taxon_oids) {
        my $pvalues_ref       = $taxonPvalues_ref->{$taxon_oid};
        my $flags_ref         = $taxonFlags_ref->{$taxon_oid};
        my $pvalue_cutoff     = getPvalueCutoff($pvalues_ref);
        my $pvalue_cutoff_fmt = sprintf( "%.2e", $pvalue_cutoff );
        $taxonPvalueCutoffs_ref->{$taxon_oid} = "$pvalue_cutoff_fmt";
        setCutoffFlag( $pvalue_cutoff, $pvalues_ref, $flags_ref );
    }
}


############################################################################
# getFuncCatDict
############################################################################
sub getFuncCatDict {
    my ($dbh, $func, $id) = @_;

    #print "getFuncCatDict(): func type '$func'<br/>\n";

    my $sql;
    my @binds;
    if ( $func eq "cogp" || $func eq "pfam" ) {
        $sql = qq{
            select distinct cog_pathway_oid, cog_pathway_name
            from cog_pathway
        };
        if ( $id ) {
            $sql .= " where cog_pathway_oid = ? ";
            @binds = ( $id );
        }
    } elsif ( $func eq "cogc" ) {
        $sql = qq{
            select distinct function_code, definition
            from cog_function
        };
        if ( $id ) {
            $sql .= " where function_code = ? ";
            @binds = ( $id );
        }
    } elsif ( $func eq "keggp" || $func eq "keggp_ko" ) {
        $sql = qq{
            select distinct pathway_oid, pathway_name
            from kegg_pathway
        };
        if ( $id ) {
            $sql .= " where pathway_oid = ? ";
            @binds = ( $id );
        }
    } elsif ( $func eq "keggc" || $func eq "keggc_ko" ) {
        $sql = qq{
            select distinct category, category
            from kegg_pathway
        };
        if ( $id ) {
            $sql .= " where category = ? ";
            @binds = ( $id );
        }
    } elsif ( $func eq "tigrfam" ) {
        $sql = qq{
            select distinct sub_role, main_role
            from tigr_role
            where sub_role != ?
        };
        @binds = ( 'Other' );
        if ( $id ) {
            $sql .= " and sub_role = ? ";
            push( @binds, $id );
        }
    } else {
        webLog("getFuncCatDict(): unknown func type '$func'\n");
        #WebUtil::webExit(-1);
    }
    #print("getFuncCatDict() sql: $sql<br/>\n");

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my %funcId2Name;
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $funcId2Name{$id} = $name;
    }
    $cur->finish();

    return \%funcId2Name;
}

############################################################################
# getFuncCateName - Get func_id -> func_name.
############################################################################
sub getFuncCateName {
    my ($dbh, $func_type, $func_id) = @_;

    my $id2name_href = getFuncCatDict($dbh, $func_type, $func_id);
    my $func_name = $id2name_href->{$func_id};

    return $func_name;
}

############################################################################
# printAbundanceCategoryGeneListSubHeader
############################################################################
sub printAbundanceCategoryGeneListSubHeader {
    my ( $dbh, $func_type, $func_id, $taxon_oid, $data_type) = @_;

    # make page
    my $func_header = $func_text{$func_type};
    my $func_name = getFuncCateName($dbh, $func_type, $func_id);

    print "<p>\n";
    print "$func_header ID: $func_id\n";
    print "<br>$func_header Name: $func_name\n";
    print "</p>\n";

    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    my $isTaxonInFile;
    if ( $in_file && isInt($taxon_oid) ) {
        $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
        if ( $isTaxonInFile ) {
            $taxon_name .= " (MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $taxon_name .= " ($data_type)";
            }
        }
    }

    print "<p>\n";
    print "Taxon ID: <a href='main.cgi?section=TaxonDetail"
      . "&page=taxonDetail&taxon_oid=$taxon_oid'>"
      . "$taxon_oid</a>\n";
    print "<br>Taxon Name: $taxon_name\n";
    print "</p>\n";

    return $isTaxonInFile;
}


1;

