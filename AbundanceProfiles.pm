###########################################################################
# AbundanceProfiles.pm - Generate abundance heatmap profiles.
#   This shows a high density display of functions (COG, Pfam, etc.)
#   in terms of their abundance in terms of gene count by heat map color.
#   The table allows for sorting by column, highest value to lowest.
#   The values can be raw gene counts, gene counts scaled by the size
#   of genome, or gene counts z-normalized in terms of other counts
#   of functions in the same genome.  (The latter probably should be
#   revised to do it in the other other direction, precomptued, for
#   all genomes in IMG.  This feature is experimental.  The rankings
#   are still pretty much the same, after sorting.)
#    --es 10/10/2005
#
# $Id: AbundanceProfiles.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package AbundanceProfiles;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);
use strict;
use CGI qw( :standard );
use Storable;
use Data::Dumper;
use WebUtil;
use WebConfig;
use ProfileHeatMap;
use AbundanceToolkit;
use TableUtil;
use ScaffoldCart;
use HtmlUtil;
use MetaUtil;
use WorkspaceUtil;
use GenomeListJSON;

$| = 1;
my $section = "AbundanceProfiles";
my $env                 = getEnv();
my $main_cgi            = $env->{main_cgi};
my $section_cgi         = "$main_cgi?section=$section";
my $cluster_bin         = $env->{cluster_bin};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $tmp_dir             = $env->{tmp_dir};
my $include_metagenomes = $env->{include_metagenomes};
my $img_internal        = $env->{img_internal};
my $img_lite            = $env->{img_lite};
my $user_restricted_site  = $env->{user_restricted_site};
my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

my $scaffold_cart = $env->{scaffold_cart};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $in_file = $env->{in_file};
my $mer_data_dir   = $env->{mer_data_dir};

my $max_taxon_selection        = 100;     # for heap map
my $max_taxon_selection_matrix = 1000;    # for matrix
my $max_row_batch_size         = 100;
my $max_gene_batch             = 500;

my $taxonOid2EstOrfs_ref;
my $avgEstOrfs = 0;

my $verbose = $env->{verbose};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 minutes (from main.pl)

    if ( $page eq "topPage" ) {
        printTopPage();

    } elsif ( $page eq "mergedForm" ) {
        printMergeForm3();
    } elsif ( $page eq "mergeResults" ) {
        printMergeResults();
    } elsif ( $page eq "abundanceProfiles" ) {
        printAbundanceProfilesForm();
    } elsif ( $page eq "abundanceProfileResults" ) {
        printAbundanceProfileResults();
    }

    # Not needed in this case; but kept by way of example.
    elsif ( paramMatch("viewAbundanceProfiles") ne "" ) {
        printAbundanceProfileResults();
    } elsif ( $page eq "abundanceProfileSort" ) {
        printAbundanceProfileSort();
    }
    ## abundance profile gene list
    #  (need to keep the tags short because there are so many of them)
    elsif ( $page eq "abGl" ) {
        printAbundanceCellGeneList();
    } elsif ( $page eq "abundanceProfileNormalizationNote" ) {
        printAbundanceProfileNormalizationNote();
    } elsif ( $page eq "superClusterNote" ) {
        printSuperClusterNote();
    } else {
        printAbundanceProfilesForm();
    }
}

############################################################################
# printTopPage - Print top page for abundance profiles.
############################################################################
sub printTopPage {

    print "<h1>Abundance Profiles Tools</h1>\n";
    print "<p>\n";
    print "The following tools operate on ";
    print "functional profiles of multiple genomes.<br/>\n";
    print "<p>\n";

    print "<p>\n";

    my $sit = new StaticInnerTable();
    $sit->addColSpec("Tool"       );
    $sit->addColSpec("Description");

    # Row 1
    my $url = "$section_cgi&page=abundanceProfiles";
    my $url = "$section_cgi&page=mergedForm";
    my $row = alink( $url, "Abundance Profile Overview(All Functions)" );
    $row .= "\tView abundance for all functions across selected genomes.\t";
    $sit->addRow($row);

    # Row 2
    my $url = "$main_cgi?section=AbundanceProfileSearch";
    my $row = alink( $url, "Abundance Profile Search" );
    $row .= "\tSearch for functions based on over or under abundance "
	. "in other genomes.\t";
    $sit->addRow($row);

    if ($include_metagenomes) {
	# Row 3
        my $url = "$main_cgi?section=AbundanceComparisons";
        my $row = alink( $url, "Function Comparisons" );
        $row .= "\tMultiple genome pairwise abundance comparisons.\t";
	$sit->addRow($row);
    }

    # this should be last tool in the list - ken
    if ($include_metagenomes) {
	# Row 4
        my $url = "$main_cgi?section=AbundanceComparisonsSub";
        my $row = alink( $url, "Function Category Comparisons" );
	$row .= "\tPairwise functional category abundance comparisons.\t";
	$sit->addRow($row);
    }

    $sit->printTable();
    print "</p>\n";
}

#
# Form for AbundanceToolkit and AbundanceProfiles
# - ken
sub printMergeForm {

    my $domain = param("domain");
    print "<h1>Abundance Profile Overview</h1>\n";

    print qq{
        <script language='JavaScript' type='text/javascript'>

        function myEnable(type) {
            var e0 = document.getElementById( "max_genome" );

            if (type == 'heap') {
                document.mainForm.doNormalization[0].disabled = false;
                document.mainForm.doNormalization[1].disabled = false;

                document.mainForm.xcopy[0].disabled = true;
                document.mainForm.xcopy[1].disabled = true;
                document.mainForm.allRows.disabled = true;
                document.mainForm.funcsPerPage.disabled = true;

                e0.innerHTML = "<p>Please select 1 to $max_taxon_selection genomes.</p>";

            } else {
                document.mainForm.doNormalization[0].disabled = true;
                document.mainForm.doNormalization[1].disabled = true;

                document.mainForm.xcopy[0].disabled = false;
                document.mainForm.xcopy[1].disabled = false;
                document.mainForm.allRows.disabled = false;
                document.mainForm.funcsPerPage.disabled = false;

                e0.innerHTML = "<p>Please select 1 to $max_taxon_selection_matrix genomes.</p>";

            }
        }
        </script>
    };

    print qq{
        <form method="post" action="main.cgi" onreset="myEnable('heap')"
        enctype="multipart/form-data" name="mainForm">
    };

    print "<p>";
    AbundanceToolkit::printOptionLabel("Display Options");
    print qq{
        <table>\n
          <th align='left'> <p>Output Type</p></th>\n
          <th width='20px'></th>
          <th colspan='2'  align='left'><p>\n
          Normalization Method\n
          <sup><a href='#hint3'>3</a></sup>\n
          </p></th>\n
    };

    # 1st row
    print "<tr>";
    print "<td valign='top'>";
    print "<input type='radio' name='display' value='heap' "
	. "onclick=\"myEnable('heap')\" checked='checked'/> Heat Map";
    print nbsp(2);
    print "</td>";

    # 2nd, 3rd, 4th cols
    print qq{
        <td></td>
        <td>
        <input type='radio' name='doNormalization'
	    value='0' checked='checked' />\n
        None<br/>\n
        <input type='radio' name='doNormalization'
            value='genomeSize' />
        Scale for genome size<br/>\n
        </td>
        <td></td>
        </tr>
    };

    # 2nd row - empty
    print "<tr><td> &nbsp;&nbsp; OR</td><td colspan='3'><hr/></td></tr>\n";

    # 3rd row
    print qq{
        <tr>\n
          <td valign='top'>\n
            <input type='radio' name='display' value='matrix'
              onclick="myEnable('matrix')"/>\n
            Matrix\n
          </td>\n
          <td></td>\n
          <td>\n
            <input type='radio' name='xcopy'
              value='gene_count' checked='checked' disabled/>\n
            Gene count<br/>\n
            <input type='radio' name='xcopy' value='est_copy' disabled/>\n
            Estimated gene copies
            <sup><a href='#hint2'>2</a></sup><br/>\n
            &nbsp;&nbsp;&nbsp;&nbsp;\n
            <i>(Slower)</i>\n
          </td>\n
          <td>\n
            <input type='checkbox' name='allRows' value='1' disabled/>\n
            &nbsp; Include all rows, including those without hits\n
            <br>&nbsp;\n
            <select name="funcsPerPage" tabindex="1" disabled>\n
              <option value="100">100</option>\n
              <option value="200">200</option>\n
              <option value="300">300</option>\n
              <option value="400">400</option>\n
              <option selected="selected" value="500">500</option>\n
              <option value="600">600</option>\n
              <option value="700">700</option>\n
              <option value="800">800</option>\n
              <option value="900">900</option>\n
              <option value="1000">1000</option>\n
            </select>\n
            &nbsp; functions per page\n
            <br/><br/>\n
          </td>\n
        </tr>\n
    };

    print qq{
        </table>\n
        </p>
        <p>\n
          Enter matching text for highlighting clusters/rows
          (E.g., "kinase")<br/>\n
          <input type='text' name='clusterMatchText' size='60' />\n
        </p>\n
    };

    print "<p>";
    AbundanceToolkit::printOptionLabel("Function");
    print "</p>";

    print qq{
      <p>\n
        <input type='radio' name='cluster' value='cog' checked='checked' />\n
        COG<br/>\n
        <input type='radio' name='cluster' value='enzyme' />\n
        Enzyme<br/>\n
        <input type='radio' name='cluster' value='ko' />\n
        KO<br/>\n
        <input type='radio' name='cluster' value='pfam' />\n
        Pfam<br/>\n
        <input type='radio' name='cluster' value='tigrfam' />\n
        TIGRfam<br/>\n
      </p>\n
    };

    # scaffold cart
    printScaffoldCartSelection() if ($scaffold_cart);

    print "<p>\n";
    AbundanceToolkit::printOptionLabel( "Genomes ", "<a href='#hint1'>1</a>" );
    HtmlUtil::printMetaDataTypeChoice();
    print "</p>";

    print qq{
        <div id='max_genome'>
          <p>Please select 1 to $max_taxon_selection genomes.</p>
        </div>
    };

    my $name = "_section_${section}";
    print submit( -name => $name, -value => "Go", -class => "smdefbutton" );
    print nbsp(1);
    print reset( -class => "smbutton" );

    # TODO test tree view
    if ($img_internal) {
        if ( $domain eq "all" ) {
            print "<p>";
            print "Switch to "
              . alink( "main.cgi?section=AbundanceProfiles&page=mergedForm",
                       "Table View" );
            print "</p>";
            printTreeView();
        } else {
            print "<p>";
            print "Switch to "
              . alink(
                "main.cgi?section=AbundanceProfiles&page=mergedForm&domain=all",
                "Tree View"
              );
            print "</p>";
            TableUtil::printGenomeTable("", "", 1);
        }
    } else {
        TableUtil::printGenomeTable("", "", 1);
    }

    print hiddenVar( "page", "mergeResults" );
    $name = "_section_${section}";
    print submit( -name => $name, -value => "Go", -class => "smdefbutton" );
    print nbsp(1);
    print reset( -class => "smbutton" );

    print "\n</form>\n";


    my $hint1a = domainLetterNoteParen();
    my $hint1b = completionLetterNoteParen();
    my $hint2 = "Estimated by multiplying by read depth when available. "
        . "Generally slower than Gene Count.";
    my $hint3 = normalizationHint();
    my $hint =  qq{
         <a name='hint1' href='#'></a>
         <b>1</b> - $hint1a<br/>\n$hint1b<br/>\n
         <a name='hint2' href='#'></a>
         <b>2</b> - $hint2<br/>\n
         <a name='hint3' href='#'></a>
         <b>3</b> - $hint3<br/>\n
    };
    printHint($hint);
    print "<p><a href='#'>Back to Top</a></p>";

}




sub printMergeForm3 {

    my $domain = param("domain");
    print "<h1>Abundance Profile Overview</h1>\n";

    print qq{
        <script language='JavaScript' type='text/javascript'>

        function myEnable(type) {
            var e0 = document.getElementById( "max_genome" );

            if (type == 'heap') {
                document.mainForm.doNormalization[0].disabled = false;
                document.mainForm.doNormalization[1].disabled = false;

                document.mainForm.xcopy[0].disabled = true;
                document.mainForm.xcopy[1].disabled = true;
                document.mainForm.allRows.disabled = true;
                document.mainForm.funcsPerPage.disabled = true;

                e0.innerHTML = "<p>Please select 1 to $max_taxon_selection genomes.</p>";

            } else {
                document.mainForm.doNormalization[0].disabled = true;
                document.mainForm.doNormalization[1].disabled = true;

                document.mainForm.xcopy[0].disabled = false;
                document.mainForm.xcopy[1].disabled = false;
                document.mainForm.allRows.disabled = false;
                document.mainForm.funcsPerPage.disabled = false;

                e0.innerHTML = "<p>Please select 1 to $max_taxon_selection_matrix genomes.</p>";

            }
        }
        </script>
    };

    print qq{
        <form method="post" action="main.cgi" onreset="myEnable('heap')"
        enctype="multipart/form-data" name="mainForm">
    };

    print "<p>";
    AbundanceToolkit::printOptionLabel("Display Options");
    print qq{
        <table>\n
          <th align='left'> <p>Output Type</p></th>\n
          <th width='20px'></th>
          <th colspan='2'  align='left'><p>\n
          Normalization Method\n
          <sup><a href='#hint3'>3</a></sup>\n
          </p></th>\n
    };

    # 1st row
    print "<tr>";
    print "<td valign='top'>";
    print "<input type='radio' name='display' value='heap' "
    . "onclick=\"myEnable('heap')\" checked='checked'/> Heat Map";
    print nbsp(2);
    print "</td>";

    # 2nd, 3rd, 4th cols
    print qq{
        <td></td>
        <td>
        <input type='radio' name='doNormalization'
        value='0' checked='checked' />\n
        None<br/>\n
        <input type='radio' name='doNormalization'
            value='genomeSize' />
        Scale for genome size<br/>\n
        </td>
        <td></td>
        </tr>
    };

    # 2nd row - empty
    print "<tr><td> &nbsp;&nbsp; OR</td><td colspan='3'><hr/></td></tr>\n";

    # 3rd row
    print qq{
        <tr>\n
          <td valign='top'>\n
            <input type='radio' name='display' value='matrix'
              onclick="myEnable('matrix')"/>\n
            Matrix\n
          </td>\n
          <td></td>\n
          <td>\n
            <input type='radio' name='xcopy'
              value='gene_count' checked='checked' disabled/>\n
            Gene count<br/>\n
            <input type='radio' name='xcopy' value='est_copy' disabled/>\n
            Estimated gene copies
            <sup><a href='#hint2'>2</a></sup><br/>\n
            &nbsp;&nbsp;&nbsp;&nbsp;\n
            <i>(Slower)</i>\n
          </td>\n
          <td>\n
            <input type='checkbox' name='allRows' value='1' disabled/>\n
            &nbsp; Include all rows, including those without hits\n
            <br>&nbsp;\n
            <select name="funcsPerPage" tabindex="1" disabled>\n
              <option value="100">100</option>\n
              <option value="200">200</option>\n
              <option value="300">300</option>\n
              <option value="400">400</option>\n
              <option selected="selected" value="500">500</option>\n
              <option value="600">600</option>\n
              <option value="700">700</option>\n
              <option value="800">800</option>\n
              <option value="900">900</option>\n
              <option value="1000">1000</option>\n
            </select>\n
            &nbsp; functions per page\n
            <br/><br/>\n
          </td>\n
        </tr>\n
    };

    print qq{
        </table>\n
        </p>
        <p>\n
          Enter matching text for highlighting clusters/rows
          (E.g., "kinase")<br/>\n
          <input type='text' name='clusterMatchText' size='60' />\n
        </p>\n
    };

    print "<p>";
    AbundanceToolkit::printOptionLabel("Function");
    print "</p>";

    print qq{
      <p>\n
        <input type='radio' name='cluster' value='cog' checked='checked' />\n
        COG<br/>\n
        <input type='radio' name='cluster' value='enzyme' />\n
        Enzyme<br/>\n
        <input type='radio' name='cluster' value='ko' />\n
        KO<br/>\n
        <input type='radio' name='cluster' value='pfam' />\n
        Pfam<br/>\n
        <input type='radio' name='cluster' value='tigrfam' />\n
        TIGRfam<br/>\n
      </p>\n
    };

    # scaffold cart
    printScaffoldCartSelection() if ($scaffold_cart);

    print "<p>\n";
    AbundanceToolkit::printOptionLabel( "Genomes ", "<a href='#hint1'>1</a>" );
    HtmlUtil::printMetaDataTypeChoice();
    print "</p>";

    print qq{
        <div id='max_genome'>
          <p>Please select 1 to $max_taxon_selection genomes.</p>
        </div>
    };


    GenomeListJSON::printHiddenInputType($section, 'mergeResults');
    GenomeListJSON::printGenomeListJsonDiv();

    GenomeListJSON::printMySubmitButton( "", 'Go', "Go",
                                         '', $section, 'mergeResults', 'meddefbutton' );


    print "\n</form>\n";
    my $hint1a = domainLetterNoteParen();
    my $hint1b = completionLetterNoteParen();
    my $hint2 = "Estimated by multiplying by read depth when available. "
        . "Generally slower than Gene Count.";
    my $hint3 = normalizationHint();
    my $hint =  qq{
         <a name='hint1' href='#'></a>
         <b>1</b> - $hint1a<br/>\n$hint1b<br/>\n
         <a name='hint2' href='#'></a>
         <b>2</b> - $hint2<br/>\n
         <a name='hint3' href='#'></a>
         <b>3</b> - $hint3<br/>\n
    };
    printHint($hint);
    print "<p><a href='#'>Back to Top</a></p>";

}




















sub printScaffoldCartSelection {
    my $scaffold_cart_names_href = ScaffoldCart::getCartNames();
    my $count                    = keys %$scaffold_cart_names_href;
    return if ( $count < 1 );

    print "<p>\n";
    AbundanceToolkit::printOptionLabel("Scaffold Cart Selection");
    print qq{
        A Scaffold Cart Name should be limited to 1000 linked scaffolds.
    };
    print "</p>\n";
    print qq{
            <table class='img'>
            <th class='img'> Select </th>
            <th class='img'> Scaffold Cart Name </th>
        };

    # print scaffold selection
    foreach my $name ( sort keys %$scaffold_cart_names_href ) {
        print qq{
                <tr class='img'>
                <td class='img'>
                  <input type='checkbox' name='scaffold_cart_name' value='$name'/>
                </td>
                <td class='img'> $name </td>
                </tr>
            };
    }
    print "</table>\n";
}

sub printTreeView {
    print hiddenVar( "fromviewer", "TreeFileMgr" );

    require TreeFileMgr;
    TreeFileMgr::printJS();
    print "<p> <div id='treeviewer'>\n";

    # tells TableUtil::getSelectedTaxons which form to used

    my ( $root, $open, $domain, $openfile, $selectedfile, $domainfile ) =
      TreeFileMgr::printTreeView();

# whole page is refreshed
#TreeFileMgr::printTree($root, $open, $domain, $openfile, $selectedfile, $domainfile,
#"section=AbundanceProfiles&page=mergedForm");

    # ajax update page
    TreeFileMgr::printTreeDiv(
                               $root,
                               $open,
                               $domain,
                               $openfile,
                               $selectedfile,
                               $domainfile,
                               "section=TreeFileMgr&page=treediv"
    );

    print "</div></p>\n";
}

#
# new results page for AbundanceToolkit and AbundanceProfiles
#
sub printMergeResults {
    my $display         = param("display");           # heap or matrix
    my $doNormalization = param("doNormalization");
    my $xcopy           = param("xcopy");
    my $allRows         = param("allRows");
    my $funcsPerPage    = param("funcsPerPage");
    $funcsPerPage = 500 if ($funcsPerPage == 0);

    my $xcopy_text = "(Gene Count)";
    if ( $xcopy eq 'est_copy' ) {
        $xcopy_text = '(Estimated Copies)';
    }
    print "<h1>Abundance Profile Overview Results $xcopy_text</h1>\n";

    $allRows = 0 if ( $allRows eq "" );

    my $clusterMatchText = param("clusterMatchText");
    my $cluster          = param("cluster");

    my @selectGenomes = param('genomeFilterSelections');
    my $find_toi_ref = \@selectGenomes; #getSelectedTaxons();
    my @taxon_oids   = @$find_toi_ref;
    my $nTaxons      = @taxon_oids;

    # --es 12/17/08 bug fix for abundance toolkit
    param( "profileTaxonOid", @taxon_oids );

    my $vir_count = 0;
    if ($scaffold_cart) {
        my @scaffold_cart_names = param("scaffold_cart_name");
        $vir_count = $#scaffold_cart_names + 1;
    }

    if ( $display eq "matrix" ) {
        if (    $nTaxons < 1 && $vir_count == 0
             || $nTaxons > $max_taxon_selection_matrix )
        {
            webError( "Please select 1 to $max_taxon_selection_matrix genomes." )
              ;
        }

    } else {
        if (    $nTaxons < 1 && $vir_count == 0
             || $nTaxons > $max_taxon_selection )
        {
            webError( "Please select 1 to $max_taxon_selection genomes." );
        }
    }

    if ( hasMerFsTaxons(\@taxon_oids) ) {
	   timeout( 60 * $merfs_timeout_mins );
    }

    if ( $display eq "heap" ) {
        printAbundanceProfileResults();
    } elsif ( $display eq "matrix" ) {
        AbundanceToolkit::printAbundanceResults();
    }
}

############################################################################
# printAbundanceProfilesForm - Print query form for abundance profiles.
############################################################################
sub printAbundanceProfilesForm {
    printMainForm();
    print qq{
       <h1>Abundance Profile Viewer</h1>\n
       <p>\n
        The Abundance Profile Viewer displays the relative abundance of
        protein / functional families in selected
        genomes using a heat map.\n
       </p>\n

       <p>\n
        <input type='radio' name='cluster' value='cog' checked />\n
        COG<br/>\n
        <input type='radio' name='cluster' value='enzyme' />\n
        Enzyme<br/>\n
        <input type='radio' name='cluster' value='pfam' />\n
        Pfam<br/>\n
        <input type='radio' name='cluster' value='tigrfam' />\n
        TIGRfam<br/>\n
       </p>\n

       <p>\n
        Normalization Method\n
        <sup><a href='#hint2'>2</a></sup><br>\n
        <input type='radio' name='doNormalization' value='0' checked />\n
        None<br/>\n
        <input type='radio' name='doNormalization' value='genomeSize' />\n
        Scale for genome size<br/>\n
        <br/>\n
        Enter matching text for highlighting clusters/rows
        (E.g., "kinase")<br/>\n
        <input type='text' name='clusterMatchText' size='60' />\n
       </p>\n

       <h2>Genome List</h2>\n
       <p>\n
         <font color='#003366'>
         Please select 1 to $max_taxon_selection genomes.
         </font>\n
        <sup><a href='#hint1'>1</a></sup><br>\n
       </p>\n

    };

    TableUtil::printGenomeTable();

    print hiddenVar( "page", "abundanceProfileResults" );
    my $name = "_section_${section}_viewAbundanceProfiles";
    print submit( -name => $name, -value => "Go", -class => "smdefbutton" );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );
    print end_form();

    my $hint1a = domainLetterNoteParen();
    my $hint1b = completionLetterNoteParen();
    my $hint2 = normalizationHint();
    my $hint =  qq{
         <a name='hint1' href='#'></a>
         <b>1</b> - $hint1a<br/>\n$hint1b<br/>\n
         <a name='hint2' href='#'></a>
         <b>2</b> - $hint2<br/>\n
    };
    printHint($hint);
    print "<p><a href='#'>Back to Top</a></p>";

}

############################################################################
# loadTaxonOid2EstOrfs - Load size mapping table.  We map
#   taxons to the "size" in terms of est. number of ORF's (genes).
############################################################################
sub loadTaxonOid2EstOrfs {
    my ($taxonOids_ref) = @_;

    my $nTaxons = @$taxonOids_ref;
    if ( $nTaxons == 0 ) {
        webLog(   "loadTaxonOid2EstOrfs: no taxon selected. "
                . "Should not get here.\n" );
        webError("Please select at least one genome.");
    }

    my $taxon_oid_str = join( ',', @$taxonOids_ref );
    checkBlankVar($taxon_oid_str);

    my $dbh = dbLogin();
    my $sql = qq{
        select tx.taxon_oid, ts.total_gene_count
	from taxon tx, taxon_stats ts
	where tx.taxon_oid in( $taxon_oid_str )
	and tx.taxon_oid = ts.taxon_oid
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    $avgEstOrfs = 0;

    for ( ; ; ) {
        my ( $taxon_oid, $total_gene_count ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonOid2EstOrfs_ref->{$taxon_oid} = $total_gene_count;
        $avgEstOrfs += ($total_gene_count) / $nTaxons;
    }
    $cur->finish();

    # TODO scaffold cart - 1000 limit
    if ($scaffold_cart) {
        my @scaffold_cart_names = param("scaffold_cart_name");
        foreach my $sname (@scaffold_cart_names) {
            my $scaffold_oids_aref =
              ScaffoldCart::getScaffoldByCartName($sname);
            my $virtual_taxon_oid =
              ScaffoldCart::getVirtualTaxonIdForName($sname);
            my $str = join( ",", @$scaffold_oids_aref );
            my $sql = qq{
            select count(*)
            from gene g
            where g.scaffold in($str)
            };
            my $cur = execSql( $dbh, $sql, $verbose );
            my ($total_gene_count) = $cur->fetchrow();
            $cur->finish();

            $taxonOid2EstOrfs_ref->{$virtual_taxon_oid} = $total_gene_count;
            $avgEstOrfs += ($total_gene_count) / $nTaxons;
        }
    }

    #$dbh->disconnect();
}

############################################################################
# printResultHeader - Show common header for results.
############################################################################
sub printResultHeader {

    my $display = param("display");

    print "<h1>Abundance Profile</h1>\n" if ( $display eq "" );
    print qq{
        <p>\n
         Mouse over labels to see additional information.<br/>\n
         Clicking on the column number will sort rows for that
         column in descending gene count order.<br/>\n
         Clicking on row cluster ID will add the cluster to
         the appropriate analysis cart (if cart is supported).<br/>\n
         Mouse over heat map to see gene counts. \n
         Clicking in the heat map will take you to the gene list.<br/>\n
        </p>\n
    };
}

############################################################################
# printAbundanceProfileResults - Show results from query form.
#   This is a top level routine to show the battery of heat maps.
############################################################################
sub printAbundanceProfileResults {
    my $cluster          = param("cluster");
    my $doNormalization  = param("doNormalization");
    my $clusterMatchText = param("clusterMatchText");
    my $data_type        = param("data_type");

    printResultHeader();

    my @selectGenomes = param('genomeFilterSelections');
    my $find_toi_ref = \@selectGenomes; #getSelectedTaxons();
    my @taxon_oids   = @$find_toi_ref;

    if ($scaffold_cart) {
        my @scaffold_cart_names = param("scaffold_cart_name");
        foreach my $sname (@scaffold_cart_names) {
            my $virtual_taxon_oid =
              ScaffoldCart::getVirtualTaxonIdForName($sname);
            push( @taxon_oids, $virtual_taxon_oid );
        }
    }

    my $nTaxons = @taxon_oids;
    if ( $nTaxons < 1 || $nTaxons > $max_taxon_selection ) {
        webError( "Please select 1 to $max_taxon_selection " . "genomes." );
    }
    printStatusLine( "Loading ...", 1 );

    loadTaxonOid2EstOrfs( \@taxon_oids );

    my $count = printHeatMapFiles( $cluster, \@taxon_oids, $doNormalization,
                                   $clusterMatchText, $data_type );

    printStatusLine( "$count clusters retrieved.", 2 );
    printResultFooter($doNormalization);
}

############################################################################
# printResultFooter - Common footer code.
############################################################################
sub printResultFooter {
    my ($doNormalization) = @_;
    my $s = "- Mouse over heat map to see gene counts.<br/>\n";
    if ( $doNormalization eq "z" ) {
        $s .=
            "- Gene counts may not correspond exactly to heat map colors "
          . "in z-score normalization.  The z-score normalization "
          . "measures *relative* abundance with regards to the "
          . "distribution of values within one genome.<br/>";
        $s .=
            "- Other anomalies may result from large values "
          . "saturating the highest heat map color.<br/>";
    }
    printHint($s);
}

############################################################################
# printAbundanceProfileSort - After user clicks a column for sorting,
#   show the sorted values again.
############################################################################
sub printAbundanceProfileSort {
    my $stateFile = param("stateFile");
    my $sortIdx   = param("sortIdx");

    printResultHeader();
    print " " x 10000;
    my $path = "$cgi_tmp_dir/$stateFile";
    if ( !( -e $path ) ) {
        webError("Your session has expired.  Please start over again.");
    }
    webLog "retrieve '$path' " . currDateTime() . "\n"
      if $verbose >= 1;
    my $state = retrieve($path);
    if ( !defined($state) ) {
        webLog("printAbundanceProfileSort: bad state from '$stateFile'\n");
        webError("Your session has expired.  Please start over again.");
    }
    my $orderedRowIds_ref = $state->{orderedRowIds};
    my $func_type         = $state->{func_type};
    my $table_ref         = $state->{table};
    my $tableOrig_ref     = $state->{tableOrig};
    my $taxonOids_ref     = $state->{taxonOids};
    my $doNorm            = $state->{doNorm};
    my $rowDict_ref       = $state->{rowDict};
    my $colDict_ref       = $state->{colDict};
    my $clusterMatchText  = $state->{clusterMatchText};
    my $stateFile2        = $state->{stateFile};

    if ( $stateFile2 ne $stateFile ) {
        webLog(   "printAbundanceProfileSort: stateFile mismatch "
                . "'$stateFile2' vs. '$stateFile'\n" );
        WebUtil::webExit(-1);
    }
    webLog "retrieved done " . currDateTime() . "\n"
      if $verbose >= 1;
    printStatusLine( "Loading ...", 1 );

    loadTaxonOid2EstOrfs($taxonOids_ref);

    my $dbh = dbLogin();
    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile($dbh, @$taxonOids_ref);

    print "<p>\n";
    my $count = 0;
    for my $taxon_oid (@$taxonOids_ref) {
        $count++;
        my $taxon_display_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
    	if ( $mer_fs_taxons{$taxon_oid} ) {
    	    $taxon_display_name .= " (MER-FS)";
    	    $url = "$main_cgi?section=MetaDetail&page=metaDetail";
    	}
        $url .= "&taxon_oid=$taxon_oid";
        print "$count - " . alink( $url, $taxon_display_name ) . "<br/>\n";
    }
    print "</p>\n";
    #$dbh->disconnect();

    my @sortedRowIds;

    # Note gene count order is same as normalized value order.
    sortTable( $sortIdx, $tableOrig_ref, $taxonOids_ref, \@sortedRowIds );

    #sortTable( $sortIdx, $table_ref, $taxonOids_ref, \@sortedRowIds );
    $state->{orderedRowIds} = \@sortedRowIds;

    printHeatMapColumns($state);
    printResultFooter($doNorm);
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# sortTable - Sort table and return result re-ordered rowId list.
############################################################################
sub sortTable {
    my ( $sortIdx, $table_ref, $taxonOids_ref, $outRowIds_ref ) = @_;

    my $nTaxons = @$taxonOids_ref;
    if ( $sortIdx < 0 || $sortIdx >= $nTaxons ) {
        webLog("sortTable: bad sortIdx='$sortIdx'\n");
        WebUtil::webExit(-1);
    }
    my @recs;
    my @keys = keys(%$table_ref);
    for my $k (@keys) {
        my $row       = $table_ref->{$k};
        my @fieldVals = split( /\t/, $row );
        my $val       = $fieldVals[$sortIdx];
        my $r         = "$val\t";
        $r .= "$k";
        push( @recs, $r );
    }

    # Number sorting works for tab delimted string also.
    my @recsSorted = reverse( sort { $a <=> $b } (@recs) );
    for my $r (@recsSorted) {
        my ( $cnt, $rowId ) = split( /\t/, $r );
        push( @$outRowIds_ref, $rowId );
    }
}

############################################################################
# printAbundanceProfileNormalizationNote - Note text reaarding
#   normalization options.
############################################################################
sub printAbundanceProfileNormalizationNote {
    print qq{
        <h1>Normalization</h1>\n
        <p>\n
          Single organism genomes can be compared using raw gene counts.<br/>\n
          Communities should be normalized taking into account genome size.<br/>\n
        </p>\n
        <p>\n
          Normalization does not affect the ordering of rows,
          only the coloring in the heat map.
        </p>\n
    };
}

sub normalizationHint {
    return qq{
      <u>Normalization Method:</u><br/>\n
      Single organism genomes can be compared
      using raw gene counts.<br/>\n
      Communities should be normalized by taking
      the size of the genome into account.<br/>\n
      Normalization does not affect the ordering of rows,
      only the coloring in the heat map.
    };
}

############################################################################
# getTaxonDict - Get taxon_oid -> taxon_display_name dictionary mapping.
############################################################################
sub getTaxonDict {
    my ($dict_ref) = @_;

    my $dbh        = dbLogin();
    my $sql        = qq{
       select taxon_oid, taxon_display_name, 'No'
       from taxon
    };
    if ( $in_file ) {
    	$sql = "select taxon_oid, taxon_display_name, $in_file from taxon";
    }
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name, $in_file ) = $cur->fetchrow();
        last if !$id;

	if ( $in_file eq 'Yes' ) {
	    $name .= " (MER-FS)";
	}
        $dict_ref->{$id} = $name;
    }
    #$dbh->disconnect();

    if ($scaffold_cart) {
        my @scaffold_cart_names = param("scaffold_cart_name");
        foreach my $sname (@scaffold_cart_names) {
            my $virtual_taxon_oid =
              ScaffoldCart::getVirtualTaxonIdForName($sname);
            $dict_ref->{$virtual_taxon_oid} = $sname;
        }
    }
}


############################################################################
# getOrthologDict - Map cluster_id -> cluster_name
############################################################################
sub getOrthologDict {
    my ($dict_ref) = @_;

    my $dbh        = dbLogin();
    my $sql        = qq{
       select cluster_id, cluster_name
       from bbh_cluster
       where cluster_name is not null
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $dict_ref->{"oclust$id"} = $name;
    }
    #$dbh->disconnect();
}

############################################################################
# loadMapDb - Load into map format. 2nd version using the database.
#   Args:
#      dbh - Database handle.
#      func_type - Type of function.
#      taxonOids_ref - array of taxon_oids
#      outTable_ref - hash of table rows; hash id is cluster_id
#      outTableOrig_ref - hash of table rows; hash id is cluster_id
#        oringal values (gene counts).
#      doNorm - Do normalization.
############################################################################
sub loadMapDb {
    my ( $dbh, $func_type, $taxonOids_ref, $outTable_ref, $outTableOrig_ref,
         $doNorm, $data_type ) = @_;

    printStartWorkingDiv();

    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile($dbh, @$taxonOids_ref);

    my %uniqueRowIds;
    my @columns;
    my @columnsOrig;
    for my $taxon_oid (@$taxonOids_ref) {
        print "Finding profile for $taxon_oid <br/>";

        my %rowId2Val;
        my %rowId2ValOrig;
        push( @columns,     \%rowId2Val );
        push( @columnsOrig, \%rowId2ValOrig );

    	if ( $mer_fs_taxons{$taxon_oid} ) {
    	    # MER-FS
    	    $taxon_oid = sanitizeInt($taxon_oid);

    	    my $file_name = "";
    	    if ( $func_type eq "cog" ) {
        		$file_name = 'cog_count.txt';
    	    }
            elsif ( $func_type eq 'enzyme' ) {
                $file_name = 'ec_count.txt';
            }
            elsif ( $func_type eq 'ko' ) {
                $file_name = 'ko_count.txt';
            }
    	    elsif ( $func_type eq 'pfam' ) {
        		$file_name = 'pfam_count.txt';
    	    }
    	    elsif ( $func_type eq 'tigrfam' ) {
        		$file_name = 'tigr_count.txt';
    	    }

    	    if ( $file_name ) {
                my @type_list = MetaUtil::getDataTypeList( $data_type );
                for my $t2 ( @type_list ) {
                    my $file = $mer_data_dir . "/" . $taxon_oid .
                        "/" . $t2 . "/" . $file_name;
                    if ( -e $file ) {
                        my $fh = newReadFileHandle($file);
                        if ( ! $fh ) {
                            next;
                        }

                        while ( my $line = $fh->getline() ) {
                            chomp $line;
                            my ($id, $cnt) = split(/\t/, $line);
            			    $rowId2Val{$id}     = $cnt;
            			    $rowId2ValOrig{$id} = $cnt;
            			    $uniqueRowIds{$id}  = 1;
                        }   # end while line
            			close $fh;
                    }
                }   # end for data_type
    	    }
    	}
    	else {
    	    # DB
    	    my $scaffold_cart_name;
            if ( $scaffold_cart && $taxon_oid < 0 ) {
                $scaffold_cart_name = ScaffoldCart::getCartNameForTaxonOid($taxon_oid);
            }
            my ( $cur, $scaffold_oids_str) = AbundanceToolkit::getFuncProfileCur(
                $dbh, 'gene_count', $func_type, $taxon_oid, $scaffold_cart_name );
    	    for ( ; ; ) {
        		my ( $id, $cnt ) = $cur->fetchrow();
        		last if !$id;
        		$rowId2Val{$id}     = $cnt;
        		$rowId2ValOrig{$id} = $cnt;
        		$uniqueRowIds{$id}  = 1;
    	    }
    	    $cur->finish();

            OracleUtil::truncTable( $dbh, "gtt_num_id" )
                if ( $scaffold_oids_str =~ /gtt_num_id/i );
    	}
    }

    if ( $doNorm eq "z" || $doNorm eq "genomeSize" ) {
        my $nColumns = @columns;
        for ( my $i = 0 ; $i < $nColumns ; $i++ ) {
            my $taxon_oid     = $taxonOids_ref->[$i];
            my $rowId2Val_ref = $columns[$i];
            my @keys          = keys(%uniqueRowIds);
            for my $rowId (@keys) {
                my $val = $rowId2Val_ref->{$rowId};
                if ( $val eq "" ) {
                    $rowId2Val_ref->{$rowId} = 0;
                }
            }
            z_normalize($rowId2Val_ref) if $doNorm eq "z";
            genomeSizeNormalize( $taxon_oid, $rowId2Val_ref )
              if $doNorm eq "genomeSize";
        }
    }
    my $nColumns = @columns;
    my %cell;
    my %cellOrig;
    for ( my $i = 0 ; $i < $nColumns ; $i++ ) {
        my $taxon_oid         = $taxonOids_ref->[$i];
        my $rowId2Val_ref     = $columns[$i];
        my $rowId2ValOrig_ref = $columnsOrig[$i];
        my @keys2             = keys(%$rowId2Val_ref);
        for my $k2 (@keys2) {
            my $cellKey = "$k2:$taxon_oid";
            my $val     = $rowId2Val_ref->{$k2};
            my $valOrig = $rowId2ValOrig_ref->{$k2};
            $cell{$cellKey}     = $val;
            $cellOrig{$cellKey} = $valOrig;
        }
    }
    my @keys1 = sort( keys(%uniqueRowIds) );
    for my $k1 (@keys1) {
        my $rowId = $k1;
        my $s;
        my $s_orig;
        for my $taxon_oid (@$taxonOids_ref) {
            my $cellKey = "$k1:$taxon_oid";
            my $val     = $cell{$cellKey};
            my $valOrig = $cellOrig{$cellKey};
            $s      .= "$val\t";
            $s_orig .= "$valOrig\t";
        }
        chop $s;
        chop $s_orig;
        $outTable_ref->{$rowId}     = $s;
        $outTableOrig_ref->{$rowId} = $s_orig;
    }

    printEndWorkingDiv();
}

############################################################################
# genomeSizeNormalize - Normalize based on genome size.
############################################################################
sub genomeSizeNormalize {
    my ( $taxon_oid, $rowId2Val_ref ) = @_;

    my $total_gene_count = $taxonOid2EstOrfs_ref->{$taxon_oid};
    if ( $total_gene_count == 0 ) {
        webLog(   "genomeSizeNormalize: total_gene_count=0 "
                . "for taxon_oid=$taxon_oid\n" );
        WebUtil::webExit(-1);
    }
    my $scale = $avgEstOrfs / $total_gene_count;
    webLog "genomeSizeNormalize: scale=$scale\n" if $verbose >= 1;

    my @keys = keys(%$rowId2Val_ref);
    for my $k (@keys) {
        my $val  = $rowId2Val_ref->{$k};
        my $val2 = $scale * $val;
        $rowId2Val_ref->{$k} = $val2;
    }
}

############################################################################
# z_normalize - Do z-score normalization.
#   (Debating whether to use mean or median.)
############################################################################
sub z_normalize {
    my ($rowId2Val_ref) = @_;
    z_normalize_mean($rowId2Val_ref);
}

sub z_normalize_mean {
    my ($rowId2Val_ref) = @_;

    my @keys = keys(%$rowId2Val_ref);
    my $n    = @keys;
    return if $n == 0;

    my $sum_xx = 0;
    my $sum_x  = 0;
    for my $k (@keys) {
        my $val = $rowId2Val_ref->{$k};
        $sum_xx += ( $val * $val );
        $sum_x  += $val;
    }
    my $mn  = $sum_x / $n;
    my $var = ( $sum_xx - ( $sum_x / $n ) ) / $n;
    my $sd  = sqrt($var);
    for my $k (@keys) {
        my $val  = $rowId2Val_ref->{$k};
        my $diff = $val - $mn;
        my $z    = 0;
        $z = $diff / $sd if $sd > 0;
        $rowId2Val_ref->{$k} = $z;
    }
}

sub z_normalize_median {
    my ($rowId2Val_ref) = @_;

    my @keys = keys(%$rowId2Val_ref);
    my $n    = @keys;
    return if $n == 0;

    my $sum_xx = 0;
    my $sum_x  = 0;
    my @a;
    for my $k (@keys) {
        my $val = $rowId2Val_ref->{$k};
        $sum_xx += ( $val * $val );
        $sum_x  += $val;
        push( @a, $val );
    }
    my @a_sorted = sort(@a);
    my $n2       = @a_sorted;
    my $mn       = $sum_x / $n;
    if ( $n % 2 == 0 ) {
        my $idx2 = int( $n / 2 );
        my $idx1 = $idx2 - 1;
        $idx1 = 0 if $idx1 < 0;
        my $v1 = $a_sorted[$idx1];
        my $v2 = $a_sorted[$idx2];
        $mn = ( $v1 + $v2 ) / 2;
    } else {
        my $idx = int( $n / 2 );
        $mn = $a_sorted[$idx];
    }
    my $var = ( $sum_xx - ( $sum_x / $n ) ) / $n;
    my $sd = sqrt($var);
    for my $k (@keys) {
        my $val  = $rowId2Val_ref->{$k};
        my $diff = $val - $mn;
        my $z    = $diff / $sd;
        $rowId2Val_ref->{$k} = $z;
    }
}

############################################################################
# orderRows - Order rows by hierarchical clustering of row correlations.
#  Experimental.  See if one can get more efficient results compared
#  to clustering.
############################################################################
sub orderRows {
    my ( $inTable_ref, $taxonOids_ref, $outRowIds_ref ) = @_;

    #orderRowsCluster( $inTable_ref, $taxonOids_ref, $outRowIds_ref );
    orderRowsSort( $inTable_ref, $taxonOids_ref, $outRowIds_ref );
}

## Use sort method.
sub orderRowsSort {
    my ( $inTable_ref, $taxonOids_ref, $outRowIds_ref ) = @_;

    my @keys   = keys(%$inTable_ref);
    my $k0     = $keys[0];
    my $row    = $inTable_ref->{$k0};
    my @vals   = join( /\t/, $row );
    my $hasDot = 0;
    for my $v (@vals) {
        if ( $v =~ /\./, ) {
            $hasDot = 1;
            last;
        }
    }
    ## If values have a ".", they are z-scores, not gene counts.
    my @recs;
    for my $k (@keys) {
        my $row = $inTable_ref->{$k};
        my @vals = join( /\t/, $row );
        my $r;
        for my $v (@vals) {
            ## Do concatenated string sorting, so need to format numbers.
            if ($hasDot) {
                ## Make number positive and shift decimal places for sorting.
                my $v2 = ( $v + 10 ) * 100;
                $r .= sprintf( "%09d", $v2 ) . "\t";
            } else {
                $r .= sprintf( "%09d", $v ) . "\t";
            }
        }
        $r .= "$k";
        push( @recs, $r );
    }
    my @recs2 = reverse( sort(@recs) );
    for my $r (@recs2) {
        my (@vals) = split( /\t/, $r );
        my $nVals = @vals;
        my $lastVal = $vals[ $nVals - 1 ];    # rowId
        push( @$outRowIds_ref, $lastVal );
    }
}

###
# compressRows - Sort rows first.  Merge adjacent rows with same
#   value signature into one row with a groupId.  Map groupId to
#   original rowIds.  Return new table.
sub compressRows {
    my ( $inTable_ref, $groupId2RowIds_ref ) = @_;

    my @keys = keys(%$inTable_ref);
    my $k0   = $keys[0];
    my $row  = $inTable_ref->{$k0};
    my @recs;
    for my $k (@keys) {
        my $row = $inTable_ref->{$k};
        my @vals = join( /\t/, $row );
        my $r;
        for my $v (@vals) {
            $r .= "$v\t";
        }
        $r .= "$k";
        push( @recs, $r );
    }
    my $count1       = @recs;
    my @recs2        = sort(@recs);
    my $outTable_ref = {};
    my $oldRowSig;
    my $groupNo = 0;
    for my $r (@recs2) {
        my (@vals) = split( /\t/, $r );
        my $nVals = @vals;
        my $rowSig;
        for ( my $i = 0 ; $i < $nVals - 1 ; $i++ ) {
            my $v = $vals[$i];
            $rowSig .= "$v\t";
        }
        my $rowId = $vals[ $nVals - 1 ];
        if ( $rowSig ne $oldRowSig ) {
            $groupNo++;
            my @a;
            $groupId2RowIds_ref->{$groupNo} = \@a;
        }
        my $a_ref = $groupId2RowIds_ref->{$groupNo};
        push( @$a_ref, $rowId );
        my $row;
        for ( my $i = 0 ; $i < $nVals - 1 ; $i++ ) {
            my $v = $vals[$i];
            $row .= "$v\t";
        }
        chop $row;
        $outTable_ref->{$groupNo} = $row;
        $oldRowSig = $rowSig;
    }
    webLog "compressRows: $count1 -> $groupNo\n" if $verbose >= 1;
    return $outTable_ref;
}

## Use cluster method
sub orderRowsCluster {
    my ( $inTable_ref, $taxonOids_ref, $outRowIds_ref ) = @_;

    my $doCompression = 1;

    my @keys  = keys(%$inTable_ref);
    my $nRows = @keys;
    if ( $nRows < 2 ) {
        printStatusLine( "Error.", 2 );
        webError("Insufficient number of rows ($nRows) for clustering.");
    }
    my $tmpFile1    = "$cgi_tmp_dir/in.matrix$$.tab.txt";
    my $tmpOutRoot2 = "$cgi_tmp_dir/out.matrix$$";

    my $inTable2_ref = $inTable_ref;

    ## Compress rows before clustering.
    my %groupId2RowIds;
    $inTable2_ref = compressRows( $inTable_ref, \%groupId2RowIds )
      if $doCompression;

    ## Write input temp file.
    my $wfh   = newWriteFileHandle( $tmpFile1, "orderRowsCluster" );
    my @keys  = sort( keys(%$inTable2_ref) );
    my $count = 0;
    for my $k (@keys) {
        $count++;
        my $row = $inTable2_ref->{$k};
        if ( $count == 1 ) {
            my $s = "cluster_id\t";
            for my $taxon_oid (@$taxonOids_ref) {
                $s .= "$taxon_oid\t";
            }
            chop $s;
            print $wfh "$s\n";
        }
        print $wfh "$k\t$row\n";
    }
    close $wfh;

    ## Run cluster
    runCmd("$cluster_bin -f $tmpFile1 -u $tmpOutRoot2 -g 1 -m s");

    ## Read in row order
    my $cdtFile = "$tmpOutRoot2.cdt";
    my $rfh = newReadFileHandle( $cdtFile, "orderRowsCluster" );
    ## Skip first two headers.
    my $s = $rfh->getline();
    my $s = $rfh->getline();
    while ( my $s = $rfh->getline() ) {
        chomp $s;

        # --es use uncompression
        if ( !$doCompression ) {
            my ( $gid, $rowId, undef ) = split( /\t/, $s );
            push( @$outRowIds_ref, $rowId );
        } else {
            my ( $gid, $groupId, undef ) = split( /\t/, $s );
            my $rowIds_ref = $groupId2RowIds{$groupId};
            for my $rowId (@$rowIds_ref) {
                push( @$outRowIds_ref, $rowId );
            }
        }
    }
    close $rfh;
    ## Reverse sort to improve appearence.
    if ($doCompression) {
        my @a = reverse(@$outRowIds_ref);
        @$outRowIds_ref = @a;
    }

    wunlink($tmpFile1);
    wunlink("$tmpOutRoot2.atr");
    wunlink("$tmpOutRoot2.cdt");
    wunlink("$tmpOutRoot2.gtr");
}

############################################################################
# printHeatMapFiles  - Generate heat map file.
############################################################################
sub printHeatMapFiles {
    my ( $func_type, $taxonOids_ref, $doNorm, $clusterMatchText, $data_type ) = @_;

    my %colDict;
    getTaxonDict( \%colDict );

    my $dbh = dbLogin();

    my $rowDict_ref = AbundanceToolkit::getFuncDict($dbh, $func_type);

    my %table;
    my %tableOrig;

    webLog "loadMapDb func_type='$func_type' doNorm='$doNorm' " . currDateTime() . "\n"
      if $verbose >= 1;
    loadMapDb( $dbh, $func_type, $taxonOids_ref, \%table, \%tableOrig, $doNorm, $data_type );

    my @keys  = keys(%table);
    my $nRows = @keys;
    webLog "orderRows nRows=$nRows " . currDateTime() . "\n" if $verbose >= 1;
    my @orderedRowIds;
    orderRows( \%table, $taxonOids_ref, \@orderedRowIds );
    my $nClusters = @orderedRowIds;

    print "<p>\n";

    ## get MER-FS taxons
    my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile($dbh, @$taxonOids_ref);

    my $count = 0;
    for my $taxon_oid (@$taxonOids_ref) {
        $count++;
        my $taxon_display_name = WebUtil::taxonOid2Name( $dbh, $taxon_oid );
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";

    	if ( $mer_fs_taxons{$taxon_oid} ) {
    	    $taxon_display_name .= " (MER-FS)";
    	    if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $taxon_display_name .= " ($data_type)";
    	    }
    	    $url = "$main_cgi?section=MetaDetail&page=metaDetail";
    	}

        $url .= "&taxon_oid=$taxon_oid";
        print "$count - " . alink( $url, $taxon_display_name ) . "<br/>\n";
    }
    print "</p>\n";
    #$dbh->disconnect();

    my $stateFile = "${func_type}_heatMap$$";
    #print "printHeatMapFiles() stateFile: $stateFile<br/>\n";
    my $state = {
          orderedRowIds    => \@orderedRowIds,
          func_type        => $func_type,
          table            => \%table,
          tableOrig        => \%tableOrig,
          taxonOids        => $taxonOids_ref,
          doNorm           => $doNorm,
          rowDict          => $rowDict_ref,
          colDict          => \%colDict,
          clusterMatchText => $clusterMatchText,
          data_type        => $data_type,
          stateFile        => $stateFile,
    };
    store( $state, checkTmpPath("$cgi_tmp_dir/$stateFile") );

    printHeatMapColumns($state);

    return $nClusters;
}

############################################################################
# printHeatMapColumns - Print multiple heat map columns for one
#   table output.
############################################################################
sub printHeatMapColumns {
    my ($state) = @_;

    my $orderedRowIds_ref = $state->{orderedRowIds};
    my $func_type         = $state->{func_type};
    my $table_ref         = $state->{table};
    my $tableOrig_ref     = $state->{tableOrig};
    my $taxonOids_ref     = $state->{taxonOids};
    my $doNorm            = $state->{doNorm};
    my $rowDict_ref       = $state->{rowDict};
    my $colDict_ref       = $state->{colDict};
    my $clusterMatchText  = $state->{clusterMatchText};
    my $data_type         = $state->{data_type};
    my $stateFile         = $state->{stateFile};

    my @batch;
    my $count = 0;
    print "<table border='0'>\n";
    print "<tr>\n";
    for my $rowId (@$orderedRowIds_ref) {
        if ( scalar(@batch) > $max_row_batch_size ) {
            $count++;
            print "<td valign='top'>\n";
            my ( $imageFile, $html ) = genOneHeatMapFile(
                  $func_type,     $count,
                  $table_ref,     \@batch,
                  $taxonOids_ref, $doNorm,
                  $rowDict_ref,   $colDict_ref,
                  $tableOrig_ref, $clusterMatchText,
                  $data_type,     $stateFile
            );
            print "$html\n";
            @batch = ();
            print "</td>\n";
        }
        push( @batch, $rowId );
    }
    if ( scalar(@batch) > 0 ) {
        $count++;
        print "<td valign='top'>\n";
        my ( $imageFile, $html ) = genOneHeatMapFile(
                  $func_type,     $count,
                  $table_ref,     \@batch,
                  $taxonOids_ref, $doNorm,
                  $rowDict_ref,   $colDict_ref,
                  $tableOrig_ref, $clusterMatchText,
                  $data_type,     $stateFile
        );
        print "$html\n";
        print "</td>\n";
    }
    print "</tr>\n";
    print "</table>\n";
}

############################################################################
# genOneHeatMapFile - Generate one heat map column.
############################################################################
sub genOneHeatMapFile {
    my (
         $func_type,         $cntId,         $table_ref,
         $orderedRowIds_ref, $taxonOids_ref, $doNorm,
         $rowDict_ref,       $colDict_ref,   $tableOrig_ref,
         $clusterMatchText,  $data_type,     $stateFile
      )
      = @_;

    my $id      = "${func_type}_${cntId}_heatMap$$";
    my $outFile = "$tmp_dir/$id.png";
    webLog "make heat map $outFile " . currDateTime() . "\n" if $verbose >= 1;
    my $n_rows = @$orderedRowIds_ref;
    my $n_cols = @$taxonOids_ref;
    my $args = {
                 id         => $id,
                 n_rows     => $n_rows,
                 n_cols     => $n_cols,
                 image_file => $outFile,
                 taxon_aref => $taxonOids_ref
    };
    my $hm = new ProfileHeatMap($args);
    my @a;

    for my $rowId (@$orderedRowIds_ref) {
        my $row = $table_ref->{$rowId};
        my @rowVals = split( /\t/, $row );
        if ( $doNorm eq "z" ) {
            ## Use z-score.
            for ( my $j = 0 ; $j < $n_cols ; $j++ ) {
                my $val  = $rowVals[$j];
                my $val2 = zscoreToBound($val);
                push( @a, $val2 );
            }
        } elsif ( $doNorm eq "rowPerc" ) {
            my $sum = 0;
            for ( my $j = 0 ; $j < $n_cols ; $j++ ) {
                my $val = $rowVals[$j];
                $sum += $val;
            }
            for ( my $j = 0 ; $j < $n_cols ; $j++ ) {
                my $val  = $rowVals[$j];
                my $val2 = 0;
                $val2 = $val / $sum if $sum > 0;
                push( @a, $val2 );
            }
        } else {
            for ( my $j = 0 ; $j < $n_cols ; $j++ ) {
                my $val  = $rowVals[$j];
                my $val2 = countToBound($val);
                push( @a, $val2 );
            }
        }
    }
    my $html =
      $hm->draw( \@a, $orderedRowIds_ref, $taxonOids_ref, $rowDict_ref,
                 $colDict_ref, $tableOrig_ref, $clusterMatchText, $stateFile,
                 $func_type, $data_type );
    $hm->printToFile();
    return ( $outFile, $html );
}

############################################################################
# zscoreToBound - Convert z-score to 0 - 1 bounded value.
############################################################################
sub zscoreToBound {
    my ($val) = @_;
    my $val2 = ( $val + 2 ) / 4;
    $val2 = 0 if $val2 < 0 || $val eq "";
    $val2 = 1 if $val2 > 1;
    return $val2;
}

############################################################################
# countToBound - Convert bound to 0 - 1 bounds.
############################################################################
sub countToBound {
    my ($val) = @_;
    my $val2 = $val;
    $val2 = 20 if $val2 > 20;
    $val2 /= 20;
    $val2 = 1 if $val2 > 1;
    return $val2;
}

############################################################################
# printAbundanceCellGeneList - Show genes from abundance cell selection.
############################################################################
sub printAbundanceCellGeneList {
    ## We need to keep tags short here.
    my $rowId     = param("id");
    my $func_type = param("function");
    my $taxon_oid = param("tid");
    my $data_type = param("data_type");

    printMainForm();
    print "<h1>Abundance Profile Overview Cell Gene List</h1>\n";

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    my $isTaxonInFile = AbundanceToolkit::printAbundanceGeneListSubHeader(
        $dbh, $func_type, $rowId, $taxon_oid, $data_type);

    if ( $isTaxonInFile ) {
        AbundanceToolkit::printMetaGeneList( $rowId, $taxon_oid, $data_type );
    }
    else {

        my $sql;
        if ( $rowId =~ /^COG/ ) {
            $sql = qq{
               select distinct g.gene_oid
               from gene_cog_groups gcg, gene g
               where gcg.gene_oid = g.gene_oid
               and gcg.cog = ?
               and g.taxon = ?
               and g.locus_type = ?
               and g.obsolete_flag = ?
          };
        } elsif ( $rowId =~ /^EC:/ ) {
            $sql = qq{
               select distinct g.gene_oid
               from gene_ko_enzymes ge, gene g
               where ge.gene_oid = g.gene_oid
               and ge.enzymes = ?
               and g.taxon = ?
               and g.locus_type = ?
               and g.obsolete_flag = ?
           };
        } elsif ( $rowId =~ /^KO:/ ) {
            $sql = qq{
               select distinct g.gene_oid
               from gene_ko_terms gk, gene g
               where gk.gene_oid = g.gene_oid
               and gk.ko_terms = ?
               and g.taxon = ?
               and g.locus_type = ?
               and g.obsolete_flag = ?
           };
        } elsif ( $rowId =~ /^pfam/ ) {
            $sql = qq{
               select distinct g.gene_oid
               from gene_pfam_families gpf, gene g
               where g.gene_oid = gpf.gene_oid
               and gpf.pfam_family = ?
               and g.taxon = ?
               and g.locus_type = ?
               and g.obsolete_flag = ?
           };
        } elsif ( $rowId =~ /^TIGR/ ) {
            $sql = qq{
               select distinct g.gene_oid
               from gene_tigrfams gtf, gene g
               where gtf.gene_oid = g.gene_oid
               and gtf.ext_accession = ?
               and g.taxon = ?
               and g.locus_type = ?
               and g.obsolete_flag = ?
           };
        } else {
            webLog("printAbundanceCellGeneList: invalid rowId='$rowId'\n");
            WebUtil::webExit(-1);
        }

        my @binds = ( $rowId, $taxon_oid, 'CDS', 'No' );
        AbundanceToolkit::printDbGeneList(  $dbh, $sql, \@binds );
    }

    print end_form();
}

############################################################################
# printSuperClusterNote - Show note about super clusters.
############################################################################
sub printSuperClusterNote {
    print qq{
       <p>
       Super cluster combine IMG's ortholog groups (based on bidiretional
       best hits) and paralog groups to descrease the granularity
       of the clusters for puropses of cross comparisons.
       Larger and more common groups allow for more cross comparisons.
       (The comparisons are also more coarse grained.)
       </p>
       <p>
       The results should be taken cautiously.  They are provided
       as an alternative view to COG, de novo clustering,
       taken from clustering genes in the native data set.
       </p>
    };
}

1;
