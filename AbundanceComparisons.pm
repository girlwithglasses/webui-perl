############################################################################
# AbundanceComparisons.pm - Tool to allow for multiple pairwise
#   genome abundance comparisons.
#        --es 06/11/2007
# $Id: AbundanceComparisons.pm 33284 2015-04-29 00:28:32Z aratner $
############################################################################
package AbundanceComparisons;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use WebConfig;
use WebUtil;
use OracleUtil;
use HtmlUtil;
use MetaUtil;
use MerFsUtil;
use WorkspaceUtil;
use AbundanceToolkit;
use GenomeListJSON;

my $section             = "AbundanceComparisons";
my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $section_cgi         = "$main_cgi?section=$section";
my $inner_cgi           = $env->{inner_cgi};
my $verbose             = $env->{verbose};
my $base_dir            = $env->{base_dir};
my $base_url            = $env->{base_url};
my $img_internal        = $env->{img_internal};
my $include_img_terms   = $env->{include_img_terms};
my $include_metagenomes = $env->{include_metagenomes};
my $show_myimg_login    = $env->{show_myimg_login};
my $img_lite            = $env->{img_lite};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $img_ken         = $env->{img_ken};
my $top_n_abundances     = 10000;  # make a very large number
my $max_query_taxons     = 20;
my $max_reference_taxons = 200;
my $r_bin                = $env->{r_bin};
my $skellam_bin          = $env->{skellam_bin};
my $user_restricted_site = $env->{user_restricted_site};
my $in_file              = $env->{in_file};
my $mer_data_dir         = $env->{mer_data_dir};
my $default_timeout_mins = $env->{default_timeout_mins};
my $merfs_timeout_mins   = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 30;
}

my $fdr       = 0.05;    # false discovery rate
my $max_batch = 500;

my %function2IdType = (
    cog     => "cog_id",
    enzyme  => "ec_number",
    ko      => "ko_id",
    pfam    => "pfam_id",
    tigrfam => "tigrfam_id",
);

my $contact_oid = WebUtil::getContactOid();

############################################################################
# dispatch - Dispatch events.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    my $page = param("page");

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
    } elsif ( $page eq "zlorNote" ) {
        printZlorNote();
    } elsif ( $page eq "skellamNote" ) {
        printSkellamNote();
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

    print "<h1>Function Comparisons</h1>\n";

    print "<p style='width: 800px;'>\n";
    print qq{
        The <b>Function Comparison</b> tool displays pairwise 
        comparisons between <u>one query</u> (meta)genome and 
        <u>multiple reference</u> (meta)genomes, 
        including estimates of the statistical significance
        of the observed differences.
    };
    print "</p>\n";

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    printJavaScript();

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

    print "<div style='width:300px; float:left;'>";
    print "<p>";
    print "<b>Function</b>:<br/>";
    print "<input type='radio' name='function' value='cog' checked />\n";
    print "COG<br/>\n";
    print "<input type='radio' name='function' value='enzyme' />\n";
    print "Enzyme<br/>\n";
    print "<input type='radio' name='function' value='ko' />\n";
    print "KO<br/>\n";
    print "<input type='radio' name='function' value='pfam' />\n";
    print "Pfam<br/>\n";
    print "<input type='radio' name='function' value='tigrfam' />\n";
    print "TIGRfam<br/>\n";
    print "</p>";


    my $url1 = "$section_cgi&page=dscoreNote";
    my $url2 = "$section_cgi&page=zlorNote";

    print "<p>";
    print "<b>Measurement</b>:<br/>";
    print "<input type='radio' name='xcopy' value='gene_count' checked />\n";
    print "Gene count<br/>\n";
    print "<input type='radio' name='xcopy' value='est_copy' />\n";
    WebUtil::printInfoTipLink
	("Estimated by multiplying by read depth when available.",
	 "Estimated Gene Copies","Estimated Gene Copies", 
	 "Estimated Gene Copies");
    print "</p>\n";

    print "<p>";
    print "<b>Output Type</b>:<br/>\n";
    print "<input type='radio' name='outType' value='dscore' checked />\n"
	. "Two-proportion Z-Test with pooled variance ("
	. alink($url1, "Z-Test", "_blank").")<br/>\n";
    print "<input type='radio' name='outType' value='zlor' />\n";
    print "Z normalized Log Odds Ratio ("
	. alink($url2, "Z-LOR", "_blank").")<br/><br/>\n";
    print "</p>";
    print "</div>";

    print "<div style='width:500px; float:left;'>";
    print "<p>";
    print "<b>Display</b>:<br/>";
    print "<input type='radio' name='rowType' value='allRows' checked />\n";
    print "Show all rows<br/>\n";
    print "<input type='radio' name='rowType' value='nonZeroRows' />\n";
    print "Show only rows with at least one non-zero gene count<br/>\n";
    print "<input type='radio' name='rowType' value='significantRows' />\n";
    print "Show only rows with significant hits<br/><br/>\n";
    print "</p>\n";

    print "<p>\n";
    #print "Minimum function gene count to calculate "
    #	. alink($url1, "D-score", "_blank");
    print "Minimum function gene count ("
	. alink($url1, "Z-Test", "_blank") . ")";
    print nbsp(1);
    print popup_menu(
            -name    => "mincount",
            -values  => [ '1', '2', '3', '4', '5', '6', '7', '8', '9', '10' ],
            -default => '5'
    );

    print "<br/><br/>";
    print "Functions per page:\n";
    print nbsp(1);
    print popup_menu(
           -name    => "funcsPerPage",
           -values  => [ 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000 ],
           -default => 500
    );
    print "</p>\n";

    print "<p>\n";
    my $name = "_section_${section}_abundanceResults";
    GenomeListJSON::printHiddenInputType( $section, 'abundanceResults' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
       ( 'go', $name, 'Go', '', $section, 'abundanceResults', 
	 'smdefbutton', 'selectedGenome1', 1, 'selectedGenome2', 1 );
    print $button;

    print nbsp(1);
    print reset( -id => "reset", -class => "smbutton" );
    print "</p>\n";
    print "</div>";

    print "<div style='clear:both;'>";
    my $hint = qq{
        <u>Genome selection</u>:
        <b>Hold down control key</b> (or command key in the case of the Mac)
        to select multiple genomes.
        <b>Hold mouse down and drag in the list</b> to select all genomes.
        <br/>The more genomes and functions are selected, the slower the query.
    };
    printHint($hint);
    #print qq{
    #    <p><a href="#">Back to Top</a></p>\n
    #};
    print "</div>";

    GenomeListJSON::showGenomeCart($numTaxon);

    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

sub printJavaScript {
    print qq{
    <script type="text/javascript" >
    var showTriggerArray = new Array(2);
    showTriggerArray[0] = "q_data_type";
    showTriggerArray[1] = "r_data_type";

    for (var i=0; i <showOrHideArray.length; i++) {
        showOrHideArray[i]=new Array(2);
    }
    //select options that permit showing
    showOrHideArray[0][0] = "unassembled";
    showOrHideArray[0][1] = "both";

    var showArea = 'estNormalizationArea';

    YAHOO.util.Event.on("q_data_type", "change", function(e) {
        //alert("q_data_type changed");
        if ( showArea != undefined && showArea != null && showArea != '' ) {
            determineShowDisplayTypeAtMultiTriggers(showTriggerArray, showArea);
        }
    });

    YAHOO.util.Event.on("r_data_type", "change", function(e) {
        //alert("r_data_type changed");
        if ( showArea != undefined && showArea != null && showArea != '' ) {
            determineShowDisplayTypeAtMultiTriggers(showTriggerArray, showArea);
        }
    });

    window.onload = function() {
        //window.alert("window.onload");
        if ( showArea != undefined && showArea != null && showArea != '' ) {
            determineShowDisplayTypeAtMultiTriggers(showTriggerArray, showArea);
        }
    }

    </script>
    };
}


############################################################################
# printAbundanceResults - Show results from query form.
############################################################################
sub printAbundanceResults {
    my $q_data_type      = param("q_data_type");
    my $r_data_type      = param("r_data_type");

    my @queryGenomes     = param("selectedGenome1");
    my @referenceGenomes = param("selectedGenome2");

    my $function         = param("function");
    my $xcopy            = param("xcopy");
    my $estNormalization = param("estNormalization");
    my $outType          = param("outType");
    my $normalization    = param("normalization");
    my $funcsPerPage     = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $outTypeTxt;
    if ( $outType eq "skellam" ) {
        $outTypeTxt = "Skellam";
    } elsif ( $outType eq "zlor" ) {
        $outTypeTxt = "Z-LOR";
    } else {
        $outTypeTxt = "D-score";
    }
    
    print "<h1>Function Comparisons ($outTypeTxt)</h1>\n";

    print "<p>\n";
    if ( $outType eq "dscore" ) {
        my $url = "$section_cgi&page=dscoreNote";
        my $link = alink( $url, "D-score" );
        print "Output type: $link<br/>\n";

    } elsif ( $outType eq "dscoreAbs" ) {
        my $url = "$section_cgi&page=dscoreNote";
        my $link = alink( $url, "D-score unsigned" );
        print "Output type: $link<br/>\n";
        
    } elsif ( $outType eq "zlor" ) {
        my $url = "$section_cgi&page=zlorNote";
        my $link = alink( $url, "Z-LOR" );
        print "Output type: $link<br/>\n";

    } elsif ( $outType eq "zlorAbs" ) {
        my $url = "$section_cgi&page=zlorNote";
        my $link = alink( $url, "Z-LOR unsigned" );
        print "Output type: $link<br/>\n";

    } elsif ( $outType eq "skellam" ) {
        my $url = "$section_cgi&page=skellamNote";
        my $link = alink( $url, "Skellam" );
        print "Output type: $link<br/>\n";
            
    } elsif ( $outType eq "pvalue" ) {
        print "Output P-value.<br/>\n";
    } elsif ( $outType eq "rfreq" ) {
        print "Output relative frequency.<br/>\n";
    } elsif ( $outType eq "urfreq" ) {
        print "Output relative frequency (unsigned).<br/>\n";
    }
    print "</p>\n";

    my $nQueryGenomes     = @queryGenomes;
    my $nReferenceGenomes = @referenceGenomes;
    if ( $nQueryGenomes == 0 ) {
        webError("Please select one query genome.<br/>\n");
    }
    if ( $nReferenceGenomes == 0 ) {
        webError( "Please select 1 to $max_reference_taxons " . "reference genomes.<br/>\n" );
    }

    my $dbh = dbLogin();

    # check if there is data for selected metagenomes:
    my %merfs_qtaxons = MerFsUtil::fetchTaxonsInFile( $dbh, @queryGenomes );
    my $returnval = 0;
    my @validGenomes;
    foreach my $qTaxon (@queryGenomes) {
    	if ( $merfs_qtaxons{$qTaxon} ) {
    	    my $val = 0;
    	    if ($q_data_type eq "assembled") {
        		$val = MetaUtil::hasAssembled($qTaxon);
    	    } elsif ($q_data_type eq "unassembled") {
        		$val = MetaUtil::hasUnassembled($qTaxon);
    	    }
    	    if ($val) {
        		push @validGenomes, $qTaxon;
        		$returnval = $val;
    	    }
    	} else {
    	    # in db
    	    push @validGenomes, $qTaxon;
    	    $returnval = 1;
    	}
    }

    @queryGenomes = @validGenomes;
    webError("Selected query genome does not have any $q_data_type data.")
	if !$returnval;

    my %merfs_rtaxons = MerFsUtil::fetchTaxonsInFile($dbh, @referenceGenomes);
    my $returnval = 0;
    my @validGenomes;
    foreach my $refTaxon (@referenceGenomes) {
        if ( $merfs_rtaxons{$refTaxon} ) {
    	    my $val = 0;
            if ($r_data_type eq "assembled") {
                $val = MetaUtil::hasAssembled($refTaxon);
            } elsif ($r_data_type eq "unassembled") {
                $val = MetaUtil::hasUnassembled($refTaxon);
            }
    	    if ($val) {
		push @validGenomes, $refTaxon;
		$returnval = $val;
    	    }
    	} else {
    	    # in db
    	    push @validGenomes, $refTaxon;
    	    $returnval = 1;
        }
    }

    @referenceGenomes = @validGenomes;
    webError("Selected reference genome(s) do not have any $r_data_type data.")
	if !$returnval;

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    #print "Set $funcsPerPage functions per page ...<br/>\n";

    my $funcId2Name_href = AbundanceToolkit::getFuncDict($dbh, $function);
    #print Dumper($funcId2Name_href);
    #print "<br/>\n";

    #print "<p>*** time1: " . currDateTime() . "\n";
    printStartWorkingDiv();

    my %queryTaxonProfiles;
    AbundanceToolkit::getProfileVectors( $dbh, "query", \@queryGenomes, $function, $xcopy, $estNormalization, \%queryTaxonProfiles, $q_data_type, 1 );
    #print "printAbundanceResults() queryTaxonProfiles:<br/>\n";
    #print Dumper(\%queryTaxonProfiles);
    #print "<br/>\n";
    my @keys             = keys(%queryTaxonProfiles);
    my $query_taxon_oid  = $keys[0];
    my $queryProfile_ref = $queryTaxonProfiles{$query_taxon_oid};

    my %referenceTaxonProfiles;
    AbundanceToolkit::getProfileVectors( $dbh, "reference", \@referenceGenomes, $function, $xcopy, $estNormalization, \%referenceTaxonProfiles, $r_data_type, 1 );
    #print "printAbundanceResults() referenceTaxonProfiles:<br/>\n";
    #print Dumper(\%referenceTaxonProfiles);
    #print "<br/>\n";

    my %refTaxonResults;
    #my %refTaxonLors;
        
    my %refTaxonRfreqs;
    my %refTaxonFlags;

    foreach my $refTaxon (@referenceGenomes) {
        my $referenceProfile_ref = $referenceTaxonProfiles{$refTaxon};

        my %results;
        my %rfreqs;
        my %flags;

    	my $n1;
    	my $n2;
        if ( $outType eq "skellam" ) {
            # use %rfreqs as \%pvalues
            ($n1, $n2) = getSkellamVals( $queryProfile_ref, $referenceProfile_ref, \%results, \%rfreqs, \%flags ); 
        } elsif ( $outType eq "zlor" ) {
            my %lors;
            ($n1, $n2) = getZlors( $outType, $queryProfile_ref, $referenceProfile_ref, \%lors, \%results, \%rfreqs, \%flags );
            #$refTaxonLors{$refTaxon}   = \%lors;
        } else {
            ($n1, $n2) = getDScores( $outType, $queryProfile_ref, $referenceProfile_ref, \%results, \%rfreqs, \%flags );
        }
    	next if ( $n1 < 1 || $n2 < 1 );

        $refTaxonResults{$refTaxon}  = \%results; #diffs, zlors, dscores;
        $refTaxonRfreqs{$refTaxon} = \%rfreqs;
        $refTaxonFlags{$refTaxon} = \%flags;
    }
    #print "printAbundanceResults() refTaxonResults:<br/>\n";
    #print Dumper(\%refTaxonResults);
    #print "<br/>\n";
    #print "printAbundanceResults() refTaxonRfreqs:<br/>\n";
    #print Dumper(\%refTaxonRfreqs);
    #print "<br/>\n";
    #print "printAbundanceResults() flags:<br/>\n";
    #print Dumper(\%flags);
    #print "<br/>\n";

    if (scalar keys %refTaxonResults == 0) {
    	printEndWorkingDiv();
    	webError("Could not find scores for selected genomes.");
    }

    my %refTaxonPvalues;
    my %refTaxonPvalueCutoffs;
    
    if ( $outType eq "skellam" ) {
        %refTaxonPvalues = %refTaxonRfreqs;
    }
    else {
        # Add dummy values to keep code from breaking.
        foreach my $taxon_oid (@referenceGenomes) {
            my %h;
            $refTaxonPvalues{$taxon_oid} = \%h;
        }
    
        # ken - get p-value all the time
        #if( $outType eq "pvalue" ) {
        print "Get p-values for d-scores or Z-LOR's ...\n";
        getPvalues( \%refTaxonResults, \%refTaxonFlags, \%refTaxonPvalues, \%refTaxonPvalueCutoffs );
        #}
    }

    if($img_ken) {
        printEndWorkingDiv('',1);    
    } else {
        printEndWorkingDiv();
    }
    

    #print "<p>*** time2: " . currDateTime() . "\n";

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $estNormalization, $normalization, $outType );
    webLog("pagerFileRoot $pagerFileRoot'\n");
    
    my $nFuncs = writePagerFiles(
        $dbh,                 $pagerFileRoot,           $funcId2Name_href,
        \%queryTaxonProfiles, \%referenceTaxonProfiles, \%refTaxonResults,
        \%refTaxonRfreqs,     \%refTaxonPvalues,        \%refTaxonFlags,
        \%refTaxonPvalueCutoffs
    );
    
    printOnePage(1);

    printStatusLine( "$nFuncs functions loaded.", 2 );
    print end_form();
}

############################################################################
# writePagerFiles - Write files for pager.
#   It writes to a file with 2 data columns for each
#   cell value.  One is for sorting.  The other is for display.
#   Third is flag for invalid indicator.
#   (Usually, they are the same, but sometimes not.)
############################################################################
sub writePagerFiles {
    my (
    	$dbh, $pagerFileRoot, $funcId2Name_ref, $queryTaxonProfiles_ref,
    	$referenceTaxonProfiles_ref, $taxonDscores_ref, $taxonRfreqs_ref,
    	$taxonPvalues_ref, $taxonFlags_ref, $taxonPvalueCutoffs_ref
      )
      = @_;
      
    my $funcsPerPage  = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);
    
    my $function      = param("function");
    my $xcopy         = param("xcopy");
    my $estNormalization = param("estNormalization");
    my $normalization = param("normalization");
    my $outType       = param("outType");
    my $q_data_type   = param("q_data_type");
    my $r_data_type   = param("r_data_type");

    #my $allRows       = param("allRows");
    my $rowType = param("rowType");

    my $allRows = 0;
    $allRows = 1 if $rowType eq "allRows";

    # significant - ken
    #my $significant = param("significant");
    my $significant = 0;
    $significant = 1 if $rowType eq "significantRows";

    my %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);

    my $idType                = $function2IdType{$function};
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
    print $Fmeta ".allRows $allRows\n";

    print $Fmeta ".significant $significant\n";

    # Pvalue cutoffs per taxon
    print $Fmeta ".pvalueCutoffsStart\n";
    for my $taxon_oid (@reference_taxon_oids) {
        my $pvalue_cutoff = $taxonPvalueCutoffs_ref->{$taxon_oid};
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        if ( $taxon_in_file{$taxon_oid} ) {
            $name .= " (MER-FS)";
            if ( $r_data_type =~ /assembled/i || $r_data_type =~ /unassembled/i ) {
                $name .= "<br/>($r_data_type)";
            }
        }
        print $Fmeta "$taxon_oid $pvalue_cutoff $name\n";
    }
    print $Fmeta ".pvalueCutoffsEnd\n";

    print $Fmeta ".attrNameStart\n";

    my $xcopy      = param('xcopy');
    my $xcopy_text = "Gene Count";
    if ( $xcopy eq 'est_copy' ) {
        $xcopy_text = "Estimated Gene Copies";
        if ( $estNormalization ) {
            $xcopy_text .= "(" + AbundanceToolkit::getEstNormalizationText() + ")";
        }
    }

    ## Column header for pager
    my $colIdx = 0;
    print $Fmeta "$colIdx :  Select\n";
    $colIdx++;
    print $Fmeta "$colIdx :  Row<br/>No. : AN: right\n";
    $colIdx++;
    print $Fmeta "$colIdx :  ID : AS : left\n";
    $colIdx++;
    print $Fmeta "$colIdx :  Name : AS : left\n";
    $colIdx++;

    for my $taxon_oid (@query_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $abbrName = largeAbbrColName( $taxon_oid, $name, 1 );

        if ( $taxon_in_file{$taxon_oid} ) {
            $abbrName .= " (MER-FS)";
            if ( $q_data_type =~ /assembled/i || $q_data_type =~ /unassembled/i ) {
                $abbrName .= "<br/>($q_data_type)";
            }
        }

        print $Fmeta "$colIdx : $abbrName<br/>$xcopy_text<br/>(Q) : " 
	    . "DN : right : $name ($taxon_oid) $xcopy_text\n";
        $colIdx++;
    }
    for my $taxon_oid (@reference_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $abbrName = largeAbbrColName( $taxon_oid, $name, 1 );

        if ( $taxon_in_file{$taxon_oid} ) {
            $abbrName .= " (MER-FS)";
            if ( $r_data_type =~ /assembled/i || $r_data_type =~ /unassembled/i ) {
                $abbrName .= "<br/>($r_data_type)";
            }
        }

        #my $dir = "DN";
        #$dir = "AN" if $outType eq "pvalue";

        # d-score or freq column
        print $Fmeta "$colIdx : $abbrName<br/>(R) : "
	    . "DN : right : $name ($taxon_oid)\n";
        $colIdx++;

        # pvalue column
        print $Fmeta "$colIdx : $abbrName<br/>p-value<br/>(R) : "
	    . "AN : right : $name ($taxon_oid) p-value\n";
        $colIdx++;

        # gene count column
        print $Fmeta "$colIdx : $abbrName<br/>$xcopy_text<br/>(R) : " 
	    . "DN : right : $name ($taxon_oid) $xcopy_text\n";
        $colIdx++;
    }
    print $Fmeta ".attrNameEnd\n";

    ## Excel export header
    print $Fxls "Func_id\t";
    print $Fxls "Func_name\t";
    my $s;
    for my $taxon_oid (@query_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        $name = excelHeaderName($name);
        $s .= "$name\t";
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        $name = excelHeaderName($name) . "_geneCount";
        $s .= "$name\t";
    }
    for my $taxon_oid (@reference_taxon_oids) {
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        $name = excelHeaderName($name);
        $s .= "$name\t";
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        $name = excelHeaderName($name) . "_geneCount";
        $s .= "$name\t";

        # pvalue column
        my $name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        $name = excelHeaderName($name) . "_pvalue";
        $s .= "$name\t";
    }
    chop $s;
    print $Fxls "$s\n";

    my $count = 0;
    for my $funcId (@funcIds) {
        ## --es 07/18/2007
        my $allZeros      = 1;
        my $allBlankFlags = 1;
        my $anySignificant = 0;
        for my $taxon_oid (@reference_taxon_oids) {
            my $profile_ref = $referenceTaxonProfiles_ref->{$taxon_oid};
            if ( !defined($profile_ref) ) {
                warn("writePagerFiles: cannot find r.profile for $taxon_oid\n");
                next;
            }
            my $cnt = $profile_ref->{$funcId};
            $allZeros = 0 if $cnt > 0;

            # TODO any flag or all flags "" ???
            my $flags_ref = $taxonFlags_ref->{$taxon_oid};
            my $flag      = $flags_ref->{$funcId};
            $allBlankFlags = 0 if ( $flag eq "" );

            my $dscores_ref = $taxonDscores_ref->{$taxon_oid};
            my $dscore = $dscores_ref->{$funcId};
            my $flag = $flags_ref->{$funcId};
            if(abs($dscore) > 1 &&  blankStr($flag) ) {
                $anySignificant = 1;
            }
        }
        next if $allZeros && !$allRows;
        next if (!$anySignificant && $significant );

        $count++;
        my $funcName = $funcId2Name_ref->{$funcId};
        my $r;
        my $xls;

        # select
        $r .= "\t";
        $r .= "<input type='checkbox' name='$idType' value='$funcId' />\t";
        $r .= "\t";

        # row number
        $r .= "$count\t";
        $r .= "$count\t";
        $r .= "\t";

        # function id
        $r   .= "$funcId\t";
        $r   .= "$funcId\t";
        $r   .= "\t";
        $xls .= "$funcId\t";

        # function name
        $r   .= "$funcName\t";
        $r   .= "$funcName\t";
        $r   .= "\t";
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
            my $url = "$section_cgi&page=geneList&function=$function";
            $url .= "&funcId=$funcId&taxon_oid=$taxon_oid&data_type=$q_data_type";
            if ( $xcopy eq 'est_copy' ) {
                $url .= "&est=$cnt";
                if ( $estNormalization ) {
                    $url .= "&estNormalization=$estNormalization";
                }
            }
            my $link = alink( $url, $cnt );
            $link = 0 if $cnt == 0;

            # display only gene count for query genome
            $r   .= "$cnt\t";
            $r   .= "$link\t";
            $r   .= "invalid\t";
            $xls .= "0\t";
            $xls .= "$cnt\t";
        }
        for my $taxon_oid (@reference_taxon_oids) {
            next if !isInt($taxon_oid);
            my $profile_ref = $referenceTaxonProfiles_ref->{$taxon_oid};
            if ( !defined($profile_ref) ) {
                warn("writePagerFiles: cannot find r.profile for $taxon_oid\n");
                next;
            }
            my $dscores_ref = $taxonDscores_ref->{$taxon_oid};
            if ( !defined($dscores_ref) ) {
                warn( "writePagerFiles: cannot find dscores_ref for $taxon_oid\n" );
                next;
            }
            my $rfreqs_ref = $taxonRfreqs_ref->{$taxon_oid};
            if ( !defined($rfreqs_ref) ) {
                warn("writePagerFiles: cannot find rfreqs_ref for $taxon_oid\n");
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
            my $dscore = $dscores_ref->{$funcId};
            $dscore = sprintf( "%.2f", $dscore );
            my $rfreq         = $rfreqs_ref->{$funcId};
            my $rfreq_display = sprintf( "%.5f", $rfreq );

            my $pvalue = $pvalues_ref->{$funcId};
            $pvalue = sprintf( "%.2e", $pvalue );
            my $pvalue_display = $pvalue;

            #$pvalue = "" if $outType ne "pvalue";

            my $val         = $dscore;
            my $val_display = $dscore;

            if ( $outType eq "skellam" ) {
                $val         = sprintf( "%d", $val );
                $val_display = sprintf( "%d", $val_display );
            }

            #$val = $pvalue if $outType eq "pvalue";
            #$val_display = $pvalue_display if $outType eq "pvalue";

            $val         = $rfreq         if $outType =~ /rfreq/;
            $val_display = $rfreq_display if $outType =~ /rfreq/;
            my $flag = $flags_ref->{$funcId};

            my $cnt = $profile_ref->{$funcId};
            $cnt = 0 if $cnt eq "";
            my $url = "$section_cgi&page=geneList&function=$function";
            $url .= "&funcId=$funcId&taxon_oid=$taxon_oid&data_type=$r_data_type";
            if ( $xcopy eq 'est_copy' ) {
                $url .= "&est=$cnt";
                if ( $estNormalization ) {
                    $url .= "&estNormalization=$estNormalization";
                }
            }
            my $link = alink( $url, $cnt );
            $link = 0 if $cnt == 0;

            # normalization dscore (or differenc eif Skellam)
            $r .= "$val\t";
            $r .= "$val_display\t";
            $r .= "$flag\t";

            # normalization pvalue
            $r .= " $pvalue\t";
            $r .= "$pvalue_display\t";
            $r .= "$flag\t";

            # gene count
            $r .= "$cnt\t";
            $r .= "$link\t";
            $r .= "$flag\t";

            my $mycolor;
            $mycolor = getDScoreColor($val) if ( blankStr($flag) );
            $mycolor = "" if ( $mycolor eq "white" );
            $xls .= "$val $mycolor\t";

            # excel export
            # bug fix d score and pvalue cell the same color said kristin 2012-02-02 - ken
            #$mycolor = "";
            #$mycolor = getPvalueColor($pvalue) if (blankStr($flag));
            $mycolor = "" if ( $mycolor eq "white" );
            $xls .= "$pvalue $mycolor\t";
            $xls .= "$cnt\t";
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
    return $count;
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
    my $estNormalization = param("estNormalization");
    my $normalization = param("normalization");
    my $funcsPerPage  = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $outType       = param("outType");
    my $sortType      = param("sortType");

    print "<h1>Function Comparisons</h1>\n";
    printMainForm();
    printStatusLine( "Loading ...", 1 );
    if ( $sortType ne "" ) {
        sortAbundanceFile( $function, $xcopy, $estNormalization, $normalization, $outType, $sortType, $colIdx, $funcsPerPage );
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
    my ( $function, $xcopy, $estNormalization, $normalization, $outType, $sortType, $colIdx, $funcsPerPage ) = @_;

    #print "<p>\n";
    #print "Resorting ...<br/>\n";
    #print "</p>\n";
    webLog("resorting sortType='$sortType' colIdx='$colIdx'\n");
    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $estNormalization, $normalization, $outType );
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
    if ( $sortType =~ /N/ ) {
        if ( $sortType =~ /D/ ) {
            @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
        } else {
            @sortRecs2 = sort { $a <=> $b } (@sortRecs);
        }
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
    my ( $function, $xcopy, $estNormalization, $normalization, $outType ) = @_;
    my $sessionId    = getSessionId();
    my $tmpPagerFile = "$cgi_tmp_dir/abundanceComparisons.$function" . ".$xcopy.$estNormalization.$normalization.$outType.$sessionId";
}

############################################################################
# printOnePage - Print one page for pager.
############################################################################
sub printOnePage {
    my ($pageNo)              = @_;

    my $outType               = param("outType");
    my $colIdx                = param("colIdx");
    my $function              = param("function");
    my $xcopy                 = param("xcopy");
    my $estNormalization      = param("estNormalization");
    my $normalization         = param("normalization");
    my $outType               = param("outType");
    my $funcsPerPage          = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);
    
    my $doGenomeNormalization = 0;
    $doGenomeNormalization = 1               if $normalization eq "genomeSize";
    $pageNo                = param("pageNo") if $pageNo        eq "";
    $pageNo                = 1               if $pageNo        eq "";

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $estNormalization, $normalization, $outType );
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
    my $nAttrSpecs3   = $nAttrSpecs * 3;

    printMainForm();
    my $colorLegend1 = getDScoreColorLegend();
    my $colorLegend2 = getPvalueColorLegend();
    my $colorLegend3 = getRfreqColorLegend();
    my $colorLegend4 = getSkellamColorLegend();
    my $colorLegend5 = getZlorColorLegend();
    my $colorLegend  = $colorLegend1;

    #$colorLegend = $colorLegend2 if $outType eq "pvalue";
    $colorLegend = $colorLegend3 if $outType =~ /rfreq/;
    $colorLegend = $colorLegend4 if $outType eq "skellam";
    $colorLegend = $colorLegend5 if $outType eq "zlor";
    my $pvalueCutoffMsg = getPvalueCutoffMsg($pagerFileMeta);

    my $notcomputed = "<font color='red'>Please note that 'Estimated Gene Copies' may not be computed yet for some metagenomes.</font>";
    printHint(   "<b>Q</b>: (Q)uery genome, <b>R</b>: (R)eference genome(s)"
               . "<br/>Mouse over genome abbreviation to see genome name "
               . "and taxon identifier.<br/>"
               . "$colorLegend<br/>"
               . "Invalid tests are not highlighted regardless of the "
               . "strength of the score.<br/><br/>"
               . "$pvalueCutoffMsg <br/>$notcomputed", 800 );
    printPageHeader( $function, $xcopy, $estNormalization, $normalization, $outType, $pageNo );

    printFuncCartFooter();
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
            if ( $estNormalization ) {
                $url .= "&estNormalization=$estNormalization";
            }
            $url .= "&normalization=$normalization";
            $url .= "&outType=$outType";
            $url .= "&colIdx=$colIdx";
            $url .= "&pageNo=1";
            $url .= "&funcsPerPage=$funcsPerPage";
            my $x;
            $x = "title='$mouseover'" if $mouseover ne "";
            my $link = "<a href='$url' $x>$attrName</a>";

            if ( $idx > 3 && ( ( $idx - 4 ) % 3 == 0 ) ) {
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
        my (@vals) = split( /\t/, $s );
        my $nVals = @vals;
        $count++;
        if ( $count > $funcsPerPage ) {
            last;
        }
        print "<tr class='img'>\n";

        # bug fix d score and pvalue cell the same color said kristin 2012-02-02 - ken
        my $lastDscoreColor;
        for ( my $i = 0 ; $i < $nAttrSpecs ; $i++ ) {
            my $right = $rightAlign{$i};
            my $alignSpec;
            $alignSpec = "align='right'" if $right;
            my $val         = $vals[ $i * 3 ];
            my $val_display = $vals[ ( $i * 3 ) + 1 ];
            my $flag        = $vals[ ( $i * 3 ) + 2 ];
            $flag =~ s/\s+//g;
            my $colorSpec;
            my $color;

            my $gene_column = 0;
            if ( $i > 3 && ( ( $i - 4 ) % 3 == 0 ) ) {

                # color gene count column
                $color       = "";
                $colorSpec   = "bgcolor=#D2E6FF";
                $gene_column = 1;
            }

            if ( $i > 4 && ( ( $i - 5 ) % 3 == 0 ) ) {

                #webLog("$flag \n");

                if ( blankStr($flag) ) {
                    $color = getDScoreColor($val) if $outType =~ /dscore/;
                    $color = getZlorColor($val)   if $outType =~ /zlor/;
                    $lastDscoreColor = $color;

                    #$color = getPvalueColor( $val ) if $outType eq "pvalue";
                }
                $color = getRfreqColor($val) if $outType =~ /rfreq/;
            }
            if ( $i > 5 && ( ( $i - 6 ) % 3 == 0 ) ) {
                if ( blankStr($flag) ) {
                    # $color = getPvalueColor($val);
                    $color = $lastDscoreColor;
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
    printFuncCartFooter();
    printPageHeader( $function, $xcopy, $estNormalization, $normalization, $outType, $pageNo );
    my $url = "$section_cgi&page=queryForm";
    print buttonUrl( $url, "Start Over", "medbutton" );
    print end_form();
}

############################################################################
# getPvalueCutoffMsg - Get pvalue cutoff message.
############################################################################
sub getPvalueCutoffMsg {
    my ($inMetaFile) = @_;

    my $msg = "<u>P-value cutoffs for False Discovery Rate ($fdr)</u>:<br/>";
    my $rfh = newReadFileHandle( $inMetaFile, "getPvalueCutoffs" );
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

	    $name =~ s/\R/ /g;
	    my @items = split("<br/>", $name);
	    $name = join(" ", @items);
            $msg .= "- $name (P-value &le; $pvalue_cutoff)<br/>\n";
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
    my ( $function, $xcopy, $estNormalization, $normalization, $outType, $currPageNo ) = @_;

    my $filePagerRoot = getPagerFileRoot( $function, $xcopy, $estNormalization, $normalization, $outType );
    my $idxFile       = "$filePagerRoot.idx";
    my $rfh           = newReadFileHandle( $idxFile, "printPageHeader" );
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
        if ( $estNormalization ) {
            $url .= "&estNormalization=$estNormalization";
        }
        $url .= "&normalization=$normalization";
        $url .= "&outType=$outType";
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
        if ( $estNormalization ) {
            $url .= "&estNormalization=$estNormalization";
        }
        $url .= "&normalization=$normalization";
        $url .= "&outType=$outType";
        $url .= "&pageNo=$nextPageNo";
        print "[" . alink( $url, "Next Page" ) . "]";
    }
    close $rfh;
    print "<br/>\n";
    my $url = "$section_cgi&page=abundanceDownload";
    $url .= "&function=$function";
    $url .= "&xcopy=$xcopy";
    if ( $estNormalization ) {
        $url .= "&estNormalization=$estNormalization";
    }
    $url .= "&normalization=$normalization";
    $url .= "&outType=$outType";
    $url .= "&noHeader=1";
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

############################################################################
# genomeNormalizeProfileVectors - Normalize value by genome size.
############################################################################
sub genomeNormalizeProfileVectors {
    my ( $dbh, $taxonProfiles_ref, $type ) = @_;

    print "Normalizing $type profiles by genome size ...<br/>\n";
    my @taxon_oids = keys(%$taxonProfiles_ref);
    for my $taxon_oid (@taxon_oids) {
        my $profile_ref = $taxonProfiles_ref->{$taxon_oid};
        genomeNormalizeTaxonProfile( $dbh, $taxon_oid, $profile_ref );
    }
}

############################################################################
# genomeNormalizeTaxonProfile - Normalize profile for one taxon.
############################################################################
sub genomeNormalizeTaxonProfile {
    my ( $dbh, $taxon_oid, $profile_ref ) = @_;

    my $sql = qq{
       select sum( g.est_copy )
       from gene g
       where g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($total_gene_count) = $cur->fetchrow();
    $cur->finish();
    if ( $total_gene_count == 0 ) {
        webLog("genomeNormalizeTaxonProfile: WARNING: total_gene_count=0\n");
        warn("genomeNormalizeTaxonProfile: WARNING: total_gene_count=0\n");
        return;
    }
    my @keys = sort( keys(%$profile_ref) );
    for my $k (@keys) {
        my $cnt = $profile_ref->{$k};
        my $v   = ( $cnt / $total_gene_count ) * 1000;
        $profile_ref->{$k} = $v;
    }
}

############################################################################
# pooledNormalizeProfileVectors - Normalize value by group size.
############################################################################
sub pooledNormalizeProfileVectors {
    my ( $dbh, $taxonProfiles_ref, $type ) = @_;

    print "Normalizing $type profiles by pooled size ...<br/>\n";
    my @taxon_oids = keys(%$taxonProfiles_ref);
    my ($pooled_gene_count) = getCumGeneCount( $dbh, \@taxon_oids );
    for my $taxon_oid (@taxon_oids) {
        my $profile_ref = $taxonProfiles_ref->{$taxon_oid};
        pooledNormalizeTaxonProfile( $dbh, $taxon_oid, $profile_ref, $pooled_gene_count );
    }
}

############################################################################
# pooledNormalizeTaxonProfile - Normalize profile for group size.
############################################################################
sub pooledNormalizeTaxonProfile {
    my ( $dbh, $taxon_oid, $profile_ref, $pooled_gene_count ) = @_;

    my @keys = sort( keys(%$profile_ref) );
    for my $k (@keys) {
        my $cnt = $profile_ref->{$k};
        my $v   = ( $cnt / $pooled_gene_count ) * 1000;
        $profile_ref->{$k} = $v;
    }
}

############################################################################
# getCumGeneCount - Get cumulative gene count
############################################################################
sub getCumGeneCount {
    my ( $dbh, $taxon_oid, $taxonOids_ref ) = @_;

    my $taxon_oid_str = join( ',', @$taxonOids_ref );
    if ( blankStr($taxon_oid_str) ) {
        warn("getCumGeneCount: no genes found for '$taxon_oid_str'\n");
        return 0;
    }
    my $sql = qq{
        select sum( g.est_copy )
	from gene g
	where g.taxon in( ? )
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid_str );
    my ($pooled_gene_count) = $cur->fetchrow();
    $cur->finish();
    return $pooled_gene_count;
}

############################################################################
# printGeneList  - User clicked on link to select genes for
#    funcId / taxon_oid.
############################################################################
sub printGeneList {
    
    my $func_type = param("function");
    my $funcId    = param("funcId");
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");
    my $est_copy  = param("est");

    printMainForm();
    print "<h1>Function Comparison Genes</h1>\n";

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    my $isTaxonInFile = AbundanceToolkit::printAbundanceGeneListSubHeader( 
        $dbh, $func_type, $funcId, $taxon_oid, $data_type);
    
    if ( $isTaxonInFile ) {
        AbundanceToolkit::printMetaGeneList( $funcId, $taxon_oid, $data_type, $est_copy );
    }
    else {
        
        require FuncCartStor;
        my $sql = FuncCartStor::getDtGeneFuncQuery1($funcId);
        my @binds = ( $taxon_oid, $funcId);
        AbundanceToolkit::printDbGeneList(  $dbh, $sql, \@binds, $est_copy );
    }
    
    print end_form();
}

############################################################################
# printAbundanceDownload - Downloads abundance data to Excel.
############################################################################
sub printAbundanceDownload {
    my $function      = param("function");
    my $xcopy         = param("xcopy");
    my $estNormalization = param("estNormalization");
    my $normalization = param("normalization");
    my $outType       = param("outType");

    my $pagerFileRoot = getPagerFileRoot( $function, $xcopy, $estNormalization, $normalization, $outType );
    my $path = "$pagerFileRoot.xls";
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
# getRfreqColor - Get color for relative frequencies.
############################################################################
sub getRfreqColor {
    my ($val) = @_;

    #return "white" if !isNumber( $val );

    $val = abs($val);
    if ( $val > 0.00010 && $val <= 0.00050 ) {
        return "bisque";
    } elsif ( $val > 0.00050 && $val <= 0.00100 ) {
        return "pink";
    } elsif ( $val > 0.00100 ) {
        return "yellow";
    } else {
        return "white";
    }
}

############################################################################
# getRfreqColorLegend - Get legend string.
############################################################################
sub getRfreqColorLegend {
    my $s;
    $s .= "Relative frequencies (positive or negative) for cell coloring: ";
    $s .= "white < 0.00010, bisque = 0.00010-0.00050, ";
    $s .= "pink = 0.00050-00100, yellow > 0.00100.";
    return $s;
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
# getZlorColor - Same z distribution as D-score.
############################################################################
sub getZlorColor {
    my ($val) = @_;

    return getDScoreColor($val);
}

############################################################################
# getDScoreColorLegend - Get legend string.
############################################################################
sub getDScoreColorLegend {
    my $s;
    $s .= "Cell coloring is based on the absolute value of D-score: ";
    $s .= "white < 1.00,
           <span style='background-color:bisque'>bisque</span> = 1.00-1.96,
           <span style='background-color:pink'>pink</span> = 1.96-2.33,
           <span style='background-color:yellow'>yellow</span> > 2.33. ";
    $s .= "<br/>The corresponding P-value is colored the same. ";
    $s .= "P-value is adjusted by false discovery rate of $fdr. ";
    return $s;
}
############################################################################
# getZlorLegend - Get legend string.
############################################################################
sub getZlorColorLegend {
    my $s;
    $s .= "Cell coloring is based on the absolute value of Z-LOR: ";
    $s .= "white < 1.00,
           <span style='background-color:bisque'>bisque</span> = 1.00-1.96,
           <span style='background-color:pink'>pink</span> = 1.96-2.33,
           <span style='background-color:yellow'>yellow</span> > 2.33. ";
    $s .= "<br/>The corresponding P-value is colored the same. ";
    $s .= "P-value is adjusted by false discovery rate of $fdr. ";
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
    $s .= "white > 0.15, bisque = 0.25-0.15, pink = 0.15-0.009, yellow < 0.009.";
    return $s;
}
############################################################################
# getSkellamColorLegend - Get legend string.
############################################################################
sub getSkellamColorLegend {
    my $s;
    $s .= "Skellam distribution P-value for cell coloring: ";
    $s .= "white > 0.15, bisque = 0.25-0.15, pink = 0.15-0.009, yellow < 0.009.";
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
#    @param rfreqs_ref - Relative frequencies
#    @param flags_ref - Output hash for flags with invalid test.
#
############################################################################
sub getDScores {
    my ( $outType, $q_ref, $r_ref, $dscores_ref, $rfreqs_ref, $flags_ref ) = @_;

    my $doAbs;
    if ( $outType eq "dscoreAbs" || $outType eq "urfreq" ) {
        $doAbs = 1;
    }

    ## n1
    my @keys   = sort( keys(%$q_ref) );
    my $nKeys1 = @keys;
    my $n1     = 0;
    for my $k (@keys) {
        my $cnt = $q_ref->{$k};
        $n1 += $cnt;
    }

    ## n2
    my @keys   = sort( keys(%$r_ref) );
    my $nKeys2 = @keys;
    my $n2     = 0;
    for my $k (@keys) {
        my $cnt = $r_ref->{$k};
        $n2 += $cnt;
    }
    if ( $nKeys1 != $nKeys2 ) {
        webLog("Warning: getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match\n ");
        #print "Warning: getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match<br/>\n";
    }
    if ( $n1 < 1 || $n2 < 1 ) {
        webLog("getDScores: n1=$n1 n2=$n2: no hits to calculate\n");
        return ( $n1, $n2 );
    }
    webLog("getDScores: n1=$n1 n2=$n2<br/>\n");
    #print "getDScores: n1=$n1 n2=$n2<br/>\n";

    my @keys       = sort( keys(%$q_ref) );
    my $undersized = 0;
    for my $id (@keys) {
        my $x1    = $q_ref->{$id};
        my $x2    = $r_ref->{$id};
        $x2 = 0 if ($x2 eq '');
        
        my $p1    = $x1 / $n1;
        my $p2    = $x2 / $n2;
        my $rfreq = $p1 - $p2;
        $rfreq = abs($rfreq) if $doAbs;
        #print "getDScores: id=$id x1=$x1 n1=$n1 p1=x1/n1=$p1; id=$id x2=$x2 n2=$n2 p2=x2/n2=$p2; rfreq=p1-p2=$rfreq<br/>\n";
        my $p   = ( $x1 + $x2 ) / ( $n1 + $n2 );
        my $q   = 1 - $p;
        my $num = $p1 - $p2;
        my $den = sqrt( $p * $q * ( ( 1 / $n1 ) + ( 1 / $n2 ) ) );
        my $d   = 0;
        $d = ( $num / $den ) if $den > 0;
        $d = abs($d)         if $doAbs;
        $dscores_ref->{$id} = $d;
        $rfreqs_ref->{$id}  = $rfreq;

        if ( !isValidTest( $n1, $n2, $x1, $x2 ) ) {
            $flags_ref->{$id} = "undersized";
            $undersized++;
        }
        
        if($img_ken && $id eq 'pfam00015') {
            print "<b>id=$id x1=$x1 x2=$x2 n1=$n1 n2=$n2 p1=$p1 p2=$p2 p=$p q=$q num=$num den=$den d=$d</b><br>\n";
            
        }
    }
    webLog("$undersized / $nKeys2 undersized\n");
    return ( $n1, $n2 );
}
############################################################################
# getZlors - Get Z normalized log odds ratio.
#
# Input:
#    @param outType - output type
#    @param q_ref - query profile
#    @param r_ref - reference profile
# Output:
#    @param zlors_ref - Output hash of function to d-score
#    @param rfreqs_ref - Relative frequencies
#    @param flags_ref - Output hash for flags with invalid test.
#
############################################################################
sub getZlors {
    my ( $outType, $q_ref, $r_ref, $lors_ref, $zlors_ref, $rfreqs_ref, $flags_ref ) = @_;

    my $doAbs;
    if ( $outType eq "Abs" || $outType eq "urfreq" ) {
        $doAbs = 1;
    }

    ## n1
    my @keys   = sort( keys(%$q_ref) );
    my $nKeys1 = @keys;
    my $n1     = 0;
    for my $k (@keys) {
        my $cnt = $q_ref->{$k};
        $n1 += $cnt;
    }

    ## n2
    my @keys   = sort( keys(%$r_ref) );
    my $nKeys2 = @keys;
    my $n2     = 0;
    for my $k (@keys) {
        my $cnt = $r_ref->{$k};
        $n2 += $cnt;
    }
    if ( $nKeys1 != $nKeys2 ) {
        #webDie("getZlors - getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match\n");
        webLog("Warning: getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match\n ");
        print "Warning: getDScores: nKeys1=$nKeys1 nKeys2=$nKeys2 do not match<br/>\n";        
    }
    if ( $n1 < 1 || $n2 < 1 ) {
        webLog("getZlors: n1=$n1 n2=$n2: no hits to calculate\n");
        return ( $n1, $n2 );
    }
    webLog("getZlors: n1=$n1 n2=$n2\n");

    my @keys       = sort( keys(%$q_ref) );
    my $undersized = 0;
    for my $id (@keys) {
        my $x1    = $q_ref->{$id};
        my $x2    = $r_ref->{$id};
        $x2 = 0 if ($x2 eq '');
                
        my $p1    = $x1 / $n1;
        my $p2    = $x2 / $n2;
        my $rfreq = $p1 - $p2;
        $rfreq = abs($rfreq) if $doAbs;
        my ( $lor, $zlor ) = getZlor( $n1, $n2, $x1, $x2 );

        $lor  = abs($lor)  if $doAbs;
        $zlor = abs($zlor) if $doAbs;
        $lors_ref->{$id}   = $lor;
        $zlors_ref->{$id}  = $zlor;
        $rfreqs_ref->{$id} = $rfreq;

    }
    return ( $n1, $n2 );
}

############################################################################
# getZlor - Return log odds ratio and
#   it's z-score equivalent (lor divided by standard error).
############################################################################
sub getZlor {
    my ( $n1, $n2, $x1, $x2 ) = @_;

    my $not_x1 = $n1 - $x1;
    my $not_x2 = $n2 - $x2;

    # avoid 0's
    my $offset = 0.0000001;
    $n1     += $offset;
    $n2     += $offset;
    $x1     += $offset;
    $x2     += $offset;
    $not_x1 += $offset;
    $not_x2 += $offset;

    my $lor   = log($x1) - log($x2) + log($not_x2) - log($not_x1);
    my $se    = sqrt( ( 1 / $x1 ) + ( 1 / $not_x1 ) + ( 1 / $x2 ) + ( 1 / $not_x2 ) );
    my $z_lor = $lor / $se;
    return ( $lor, $z_lor );
}

############################################################################
# getSkellamVals - Get skellam distribution values.
#
# Input:
#    @param outType - output type
#    @param q_ref - query profile
#    @param r_ref - reference profile
# Output:
#    @param diffs_ref - Output hash of function for differences.
#    @param pvalues_ref - Output p-values.
#    @param flags_ref - Output hash for flags with invalid test.
#
############################################################################
sub getSkellamVals {
    my ( $q_ref, $r_ref, $diffs_ref, $pvalues_ref, $flags_ref ) = @_;

    ## n1
    my @keys   = sort( keys(%$q_ref) );
    my $nKeys1 = @keys;
    my $n1     = 0;
    for my $k (@keys) {
        my $cnt = $q_ref->{$k};
        $n1 += $cnt;
    }

    ## n2
    my @keys   = sort( keys(%$r_ref) );
    my $nKeys2 = @keys;
    my $n2     = 0;
    for my $k (@keys) {
        my $cnt = $r_ref->{$k};
        $n2 += $cnt;
    }

    if ( $n1 < 1 || $n2 < 1 ) {
        webLog("getSkellamVals: n1=$n1 n2=$n2: no hits to calculate\n");
        return ( $n1, $n2 );
    }

    my $tmpFile1 = "$cgi_tmp_dir/skellam$$.in.tab.txt";
    my $tmpFile2 = "$cgi_tmp_dir/skellam$$.out.tab.txt";
    my $wfh      = newWriteFileHandle( $tmpFile1, "getSkellamVals" );
    my @keys     = sort( keys(%$q_ref) );
    for my $id (@keys) {
        my $x1   = $q_ref->{$id};
        my $x2   = $r_ref->{$id};
        my $p1   = $x1 / $n1;
        my $p2   = $x2 / $n2;
        my $mu1  = $n1 * $p1;       # i.e., x1
        my $mu2  = $n2 * $p2;       # i.e., x2
        my $diff = $x1 - $x2;
        $diffs_ref->{$id} = $diff;

        if ( !isValidPoisson( $n1, $n2, $x1, $x2 ) ) {
            $flags_ref->{$id} = "invalid-poisson";
        }
        print $wfh "$id\t";
        print $wfh "$diff\t";
        print $wfh "$mu1\t";
        print $wfh "$mu2\n";
    }
    close $wfh;
    runCmd("$skellam_bin -i $tmpFile1 -o $tmpFile2");
    my $rfh = newReadFileHandle( $tmpFile2, "getSkellamVals" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $id, $prob, $pvalue ) = split( /\t/, $s );
        $pvalue =~ tr/A-Z/a-z/;
        if ( $pvalue eq "nan" ) {
            $flags_ref->{$id} = "nan";
            $pvalue = 1.0;
        }
        $pvalues_ref->{$id} = $pvalue;
    }
    close $rfh;
    wunlink($tmpFile1);
    wunlink($tmpFile2);

    return ( $n1, $n2 );
}

############################################################################
# isValidTest - Heursitics to see if test is sufficent size to be valid.
############################################################################
sub isValidTest {
    my ( $n1, $n2, $x1, $x2 ) = @_;

    my $mincount = param("mincount");

    return 1 if $x1 >= $mincount && $x2 >= $mincount;

    ##--es 10/18/2007
    #return 1 if $x1 + $x2 >= 10 && $x1 > $x2 && $n2 >= $n1;
    #return 1 if $x1 + $x2 >= 10 && $x2 > $x1 && $n1 >= $n2;

    return 0;
}

############################################################################
# isValidPoisson - Invalid poision or other assumptions.
############################################################################
sub isValidPoisson {
    my ( $n1, $n2, $x1, $x2 ) = @_;

    my $diff = abs( $x1 - $x2 );
    my $p1   = $x1 / $n1;
    my $p2   = $x2 / $n2;
    if (    ( $n1 >= 20 && $p1 <= 0.05 || $n1 >= 100 && $n1 * $p1 <= 10 )
         && ( $n2 >= 20 && $p2 <= 0.05 || $n2 >= 100 && $n2 * $p2 <= 10 )
         && $diff >= 2 )
    {
        return 1;
    }
    return 0;
}

############################################################################
# getPvalues - Get pvalues given z (or d-score in this case).
#
#  Input:
#    @param taxonDscores_ref - Hash of taxon_oid -> d-score hash
#    @param taxonFlags_ref - Has of taxon_oid -> flag vector invalid test.
#  Output:
#    @param taxonPvalues_ref - Hash of taxon_oid -> hash p-values.
#    @param taxonPvalueCutoffs_ref - taxon_oid -> pvalue-cutoff
############################################################################
sub getPvalues {
    my ( $taxonDscores_ref, $taxonFlags_ref, $taxonPvalues_ref, $taxonPvalueCutoffs_ref ) = @_;

    my $tmpDscoreFile = "$cgi_tmp_dir/xdscores$$.txt";
    my $tmpRcmdFile   = "$cgi_tmp_dir/xrcmd$$.r";
    my $tmpRoutFile   = "$cgi_tmp_dir/xrout$$.txt";
    my $wfh           = newWriteFileHandle( $tmpDscoreFile, "getPvalues" );
    my $nFuncs        = 0;
    my @funcIds;
    my @taxon_oids = sort( keys(%$taxonDscores_ref) );

    foreach my $taxon_oid (@taxon_oids) {
        my $dscores_ref = $taxonDscores_ref->{$taxon_oid};
        my @keys        = sort( keys(%$dscores_ref) );
        my $nFuncs2     = @keys;
        if ( $nFuncs > 0 && $nFuncs != $nFuncs2 ) {
            webDie( "getPvalues: taxon_oid=$taxon_oid " . "nFuncs=$nFuncs nFuncs2=$nFuncs2\n" );
        }

	#print "<br/>getPvalues ($taxon_oid) ".$nFuncs2."<br/>";
	next if $nFuncs2 == 0;

        ## Store order of funcIds
        foreach my $k (@keys) {
            push( @funcIds, $k );
        }
        $nFuncs = $nFuncs2;
        my $s;
        foreach my $k (@keys) {
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
    print "<h1>Two-proportion Z-Test with pooled variance</h1>\n";
    print "<p>\n";

    my $url = "$section_cgi&page=zlorNote";
    my $zlor_link = alink($url, "Z-LOR", "_blank");

    print qq{
       A <b>Z-Test</b> is a statistical test for which the distribution of
       independent data measurements can be approximated by a normal distribution.<br/>
       A <b>Z-Score</b> is used to indicate how many standard deviations
       away from the mean is a particular data measurement.
       <br/><br/>
       z-score = (raw score - mean) / standardDeviation
       <br/><br/>

       <b>Data:</b><br/>
       <br/>
       <i>x1</i> = count of a given function in query group<br/>
       <i>x2</i> = count of a given function in reference group<br/>
       <i>n1</i> = total counts of all function occurrences in query group<br/>
       <i>n2</i> = total counts of all function occurrences in reference group<br/>
       <br/>

       <b>Computations:</b><br/>
       <br/>
       <i>f1</i> = <i>x1/n1</i> = frequency of functional occurrence in query group<br/>
       <i>f2</i> = <i>x2/n2</i> = frequency of functional occurrence in reference group<br/>
       <i>p = (x1 + x2) / (n1 + n2)</i> = probability of occurrence<br/>
       <i>q = 1 - p</i> = probability of non-occurrence<br/>
       <i>z-score = (f1 - f2) / sqrt( p*q * (1/n1 + 1/n2) )</i><br/>
       <br/>
       <i>pnorm()</i> = probability distribution function for <i>N(0,1)</i><br/>
       <i>p_value = 1.00 - pnorm( abs(z-score) )</i><br/>
       <br/>
       <b>Qualifications:</b><br/><br/>
       A test is valid if it is of sufficient size for a normal distribution:<br/><br/>
       <i>x1 >= 5 and x2 >= 5</i><br/><br/>
       It is assumed that the gene to function assignments are independent. 
       Alternatively, the $zlor_link test is available.<br/><br/>

       <b>Z-Rank:</b><br/>
       <br/>The sum of independent random variables that are normally distributed 
            is also normally distributed.<br/><br/>
       Z-Rank = (sum of z-scores of selected genomes) / sqrt(N)<br/>
       where N is the number of protein families including those without hits.
       <br/><br/>
       When summing in Z-Rank, the z-score is set to zero if the test is not valid due to insufficient size.<br/><br/>
       <img src="$base_url/images/zrank.jpg" width="105" height="120"
        border="0" alt="Z-Rank" title="Z-Rank"/>
    };
    print "</p>\n";
}
############################################################################
# printZlorNote - Print note about Z-LOR calculation.
############################################################################
sub printZlorNote {
    print "<h1>Z-LOR</h1>\n";

    print qq{
       <p>
       The Odds Ratio measures the relative odds
       between two samples.  We take the natural logartihm of this ratio.
       We divide it by the
       standard error to get a Z normalized value
       from which to compute the P-value.
       <br/>
       <br/>
       <b>Input Data:</b><br/>
       <br/>
       <i>x1</i> = count of a given function in query group.<br/>
       <i>x2</i> = count of a given function
           in reference group.<br/>
       <i>n1</i> = total counts of all function occurrences in query group.<br/>
       <i>n2</i> = total counts of all function occurrences
          in reference group.<br/>

       <br/>
       <b>Log Odds Ratio (conceptual):</b>
       </p>

       <table border=1' class='img'>
       <th class='img'>&nbsp;</th>
       <th class='img'>x1</th>
       <th class='img'>x2</th>
       <tr clas='img'>
          <td class='img'>Present</td>
          <td class='img'>p1</td>
          <td class='img'>p2</td>
       </tr>
       <tr clas='img'>
          <td class='img'>Absent</td>
          <td class='img'>q1</td>
          <td class='img'>q2</td>
       </tr>
       </table>

     
       <p>
       (This shows how counts are converted to probabilities,
        "odds" as probability of occurring over not probability of not
	occurring, the ratio of the odds between two samples,
	and finally the log ratio.)<br/>
       <br/>
       <i>p1 = x1/n1</i><br/>
       <i>p2 = x2/n2</i><br/>
       <i>q1 = (n1-x1)/n1 # i.e., 1-p1</i><br/>
       <i>q2 = (n2-x2)/n2 # i.e., 1-p2</i><br/>
       <i>odds1 = p1/q1</i><br/>
       <i>odds2 = p2/q2</i><br/>
       <i>lor = log( odds1/odds2 )</i><br/>

       <br/>
       <b>Computations:</b><br/>
       <br/>
       <i>not_x1 = n1 - x1</i><br/>
       <i>not_x2 = n2 - x2</i><br/>
       <i>lor = log(x1) - log(x2) + log(not_x2) - log(not_x1)</i><br/>
       <br/>
       <i>(An offset of +0.0000001 is made to n1, n2, x1, x2,
        not_x1, and not_x2 to avoid zero counts in the divisor.)</i><br/>
       <br/>
       <i>se = sqrt( 1/x1 + 1/not_x1 + 1/x2 + 1/not_x2 ) # standard error</i>
       <br/>
       <i>z_lor = lor / se</i><br/>
       <br/>
       <i>pnorm()</i> - probability distribution function for <i>N(0,1)</i><br/>
       <i>p_value = 1.00 - pnorm( abs( z_lor ) )</i><br/>
       </p>
    };
}

############################################################################
# printSkellamNote - Print note about D-score calculation.
############################################################################
sub printSkellamNote {
    print "<h1>Skellam Distribution</h1>\n";
    print "<p>\n";
    print qq{
       A Skellam distribution is a discrete probability distribution
       of the difference between  two random variables having a 
       Poisson distribution.  The variables, in this case, is
       the count of genes between two groups for a given function.
       These variables are binomially distributed, but when certain
       qualifications are met, a Poisson approximation may be used.
       <br/>
       <br/>
       <b>Data:</b><br/>
       <i>x1</i> = estimated gene count of a given function in query group.<br/>
       <i>x2</i> = estimated gene count of a given function
           in reference group.<br/>
       <i>diff</i> = <i>x1 - x2</i> difference.<br/>
       <i>n1</i> = total counts of all function occurrences in query group.<br/>
       <i>n2</i> = total counts of all function occurrences
          in reference group.<br/>
       <i>lambda1</i> = <i>n1 * p1</i>, Poisson approximation.<br/>
       <i>lambda2</i> = <i>n2 * p2</i>, Poisson approximation.<br/>
       <i>mu1</i> = <i>lambda1</i>, mean1 for Skellam distribution 
           (<i>x1</i>).<br/>
       <i>mu2</i> = <i>lambda2</i>, mean2 for Skellam distribution 
           (<i>x2</i>).<br/>
       <br/>
       <b>Computations:</b><br/>
       <i>p_value = pskellam( diff, mu1, mu2 )</i>, P-value function.<br/>
       <br/>
       <br/>
       <b>Qualifications:</b><br/>
       For valid Poisson approximation,<br/>
       <i>(n1 >= 20 and p1 <= 0.05) or (n1 >= 100 and n1*p1 <= 10)</i> and<br/>
       <i>(n2 >= 20 and p2 <= 0.05) or (n2 >= 100 and n2*p2 <= 10)</i>.<br/>
       <br/>
       Other numerical limitations:<br/>
       <i>abs( diff ) >= 2</i> and<br/>
       <i>p_value</i> is not NaN, i.e, numerically computable.<br/>.
       (<i>mu1</i> and <i>mu2</i> should not be too large.)<br/>
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
    my $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $taxon_display_name2 = escHtml($taxon_display_name);
    my $link = "<a href='$url' title='$taxon_display_name2'>$s</a>";
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

1;

