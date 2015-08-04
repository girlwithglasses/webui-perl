############################################################################
# $Id: AbundanceProfileSearch.pm 32375 2014-12-03 20:49:53Z jinghuahuang $
# Abundance Profile search / Conditional Function Profile
############################################################################
package AbundanceProfileSearch;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  printAbundanceProfileForm
  fillLineRange
  printAbundanceProfileRun
);

use strict;
use CGI qw( :standard );
use DBI;
use ScaffoldPanel;
use Data::Dumper;
use Time::localtime;
use WebConfig;
use WebUtil;
use InnerTable;
use MetaUtil;
use QueryUtil;
use WorkspaceUtil;
use AbundanceToolkit;
use GenomeListJSON;

$| = 1;

my $section     = "AbundanceProfileSearch";
my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $verbose     = $env->{verbose};
my $cgi_url     = $env->{cgi_url};
my $base_dir    = $env->{base_dir};
my $base_url    = $env->{base_url};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};

my $cog_base_url       = $env->{cog_base_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_orthology_url = $env->{kegg_orthology_url};
my $pfam_base_url      = $env->{pfam_base_url};
my $tigrfam_base_url   = $env->{tigrfam_base_url};
my $in_file            = $env->{in_file};

my $include_metagenomes     = $env->{include_metagenomes};
my $phyloProfiler_sets_file = $env->{phyloProfiler_sets_file};
my $user_restricted_site    = $env->{user_restricted_site};

# max selection for in and over, oracle limit is 1000
my $maxselection         = 999;
my $max_taxon_candidates = 300;

# processing messages newline
my $message_cnt_wrap = 1000;
my $dot_cnt_wrap     = 160;

my $nvl = getNvl();

############################################################################
# dispatch - Dispatch to pages for this section.
#
# this is the hook into main.pl, I use section=abundanceProfileSearch
# to get here, then I use section=??? to go the correct page after
############################################################################
sub dispatch {
    my ($numTaxon) = @_;        # number of saved genomes
    my $page = param("page");
    if ( $page eq "abundanceProfileSearchRun" ) {
        printAbundanceProfileRun();
    } elsif ( $page eq "abundanceProfileSearchPage" ) {

        # page - Result page 'more' button
        my $cacheFile = param("cf");
        printAbundanceProfileResultsPage($cacheFile);
    } elsif ( $page eq "abundanceGeneListPage" ) {

        # for bin prefix t or b for taxonid
        printAbundanceFuncGeneListPage();
    } elsif ( $page eq "abundanceNormalizationNote" ) {
        printAbundanceNormalizationNote();
    } else {
        printAbundanceProfileForm($numTaxon);
    }
}

#############################################################################
# printAbundanceProfileForm
# Show initial query form for Abundance profiler.
############################################################################
sub printAbundanceProfileForm {
    my ($numTaxon) = @_;
    my $set = param("set");
    my $setClause;
    if ( $set ne "" ) {
        my @set_taxon_oids = loadSetTaxonOids($set);
        my $set_taxon_oid_str = join( ',', @set_taxon_oids );
        if ( !blankStr($set_taxon_oid_str) ) {
            $setClause = "and tx.taxon_oid in( $set_taxon_oid_str )";
        }
    }

    # Print mainForm with onreset event
    # We need to disable "Show Results As" buttons upon reset
    print start_form(
        -name    => "mainForm",
        -action  => "$main_cgi",
        -onreset => "normTypeAction(true)"
    );

    print "<h1>Abundance Profile Search</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print "<p>\n";
    print "Find genes in genome (bin) of interest "
      . "based on similarity to sequences in other genomes <br/>\n"
      . "(BLASTP alignments). Only user-selected genomes "
      . "appear in the profiler. <br/>\n";
    print "</p>\n";

    printHint( "* You must select exactly one genome (bin) of "
          . "interest into \"Find Functions In\" list.<br/>"
          . "To check for the absence of a gene in "
          . "the genome (bin) of interest, select an alternate "
          . "genome (bin) of interest." );
    print "<br/>";

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ( $hideViruses eq "" || $hideViruses eq "Yes" ) ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ( $hidePlasmids eq "" || $hidePlasmids eq "Yes" ) ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ( $hideGFragment eq "" || $hideGFragment eq "Yes" ) ? 0 : 1;

    my $cgi_url = $env->{cgi_url};
    my $xml_cgi = $cgi_url . '/xml.cgi';

    my $template = HTML::Template->new( filename => "$base_dir/genomeJsonThreeDiv.html" );
    $template->param( isolate              => 1 );
    $template->param( gfr                  => $hideGFragment );
    $template->param( pla                  => $hidePlasmids );
    $template->param( vir                  => $hideViruses );
    $template->param( all                  => 1 );
    $template->param( cart                 => 1 );
    $template->param( xml_cgi              => $xml_cgi );
    $template->param( prefix               => '' );
    $template->param( selectedGenome1Title => 'Find Functions In*' );
    $template->param( selectedGenome2Title => 'More Abundant Than In' );
    $template->param( selectedGenome3Title => 'Less Abundant Than In' );
    $template->param( maxSelected2         => -1 );
    $template->param( maxSelected3         => -1 );

    if ($include_metagenomes) {
        $template->param( include_metagenomes => 1 );
        $template->param( selectedAssembled1  => 1 );
        $template->param( selectedAssembled2  => 1 );
        $template->param( selectedAssembled3  => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    # function radio buttons
    print "<div style='width:300px; float:left;'>";
    print qq{
        <p>
        <b>Functional Classification</b>:<br>
        <input type='radio' name='cluster' value='cog' checked />COG<br/>
        <input type='radio' name='cluster' value='enzyme' />Enzyme<br/>\n
        <input type='radio' name='cluster' value='ko' />KO<br/>
        <input type='radio' name='cluster' value='pfam' />Pfam<br/>
        <input type='radio' name='cluster' value='tigrfam' />Tigrfam
        </p>
    };

    printJavaScript();

    # normalization
    print qq{
        <p>
        <b>Normalization Method</b>:<br>
        <input type='radio' name='doNormalization'
         onclick='normTypeAction(true)' value='c' checked />None<br/>
        <input type='radio' name='doNormalization'
         onclick='normTypeAction(false)' value='f' />Frequency<br/>
        </p>
    };

    print qq{
        <p>
        <b>Show Results As</b>:<br>
        <input type='checkbox' name='counttype' disabled='disabled'
         checked='checked' onclick='countStatus(this)' />Count<br/>

         &nbsp;&nbsp;&nbsp;&nbsp;
         <input type='radio' name='showresult' value='gcnt'
          disabled='disabled' checked='checked' />Gene count<br/>
         &nbsp;&nbsp;&nbsp;&nbsp;
         <input type='radio' name='showresult' value='est'
          disabled='disabled' />Estimated gene copies<br/>

        <input type='checkbox' name='norm' disabled='disabled'
         checked='checked' onclick='countStatus(this)' />Normalized value<br/>
        </p>
    };

    my $hint1 = normalizationHint();
    my $hint  = qq{
        <a name='hint1' href='#'></a>\n
        $hint1
    };
    printHint($hint);
    print "</div>";

    print "<div style='width:500px; float:left;'>";
    print "<br/>";
    print "<br/>";
    print qq{
    	<p>
    	More Abundant Cut-Off &nbsp;&nbsp;
    	<SELECT name="overabundant">
    	<OPTION value="1">1</OPTION>
    	<OPTION value="2">2</OPTION>
    	<OPTION value="3">3</OPTION>
    	<OPTION value="4">4</OPTION>
    	<OPTION value="5">5</OPTION>
    	<OPTION value="6">6</OPTION>
    	<OPTION value="7">7</OPTION>
    	<OPTION value="8">8</OPTION>
    	<OPTION value="9">9</OPTION>
    	<OPTION value="10">10</OPTION>
    	</SELECT>
    	&nbsp;&nbsp; Less Abundant Cut-Off &nbsp;&nbsp;
    	<SELECT name="underabundant">
    	<OPTION value="1">1</OPTION>
    	<OPTION value="2">2</OPTION>
    	<OPTION value="3">3</OPTION>
    	<OPTION value="4">4</OPTION>
    	<OPTION value="5">5</OPTION>
    	<OPTION value="6">6</OPTION>
    	<OPTION value="7">7</OPTION>
    	<OPTION value="8">8</OPTION>
    	<OPTION value="9">9</OPTION>
    	<OPTION value="10">10</OPTION>
    	</SELECT>
    	<p>
    };

    #HtmlUtil::printMetaDataTypeChoice();

    print "<p>\n";
    print "Enter matching text for highlighting clusters/rows. ";
    print "(E.g., \"kinase\".)<br/>\n";
    print "<input type='text' name='clusterMatchText' size='60' />\n";
    print "</p>\n";

    # rename variable for submit button
    # submit button will call main.pl with
    # page var set to abundanceProfileSearchRun
    # which will call
    # 1. printAbundanceProfileRun() which calls
    # 2. runJob()
    # with dispath method use abundanceProfileSearch
    print hiddenVar( "section", $section );

    # add another hidden var
    print hiddenVar( "page", "abundanceProfileSearchRun" );

    my $name = "_section_${section}_abundanceProfileSearchRun";
    GenomeListJSON::printHiddenInputType( $section, 'abundanceResults' );
    my $button =
      GenomeListJSON::printMySubmitButtonXDiv( 'go', $name, 'Go', '', $section, 'abundanceProfileSearchRun', 'smdefbutton' );
    print $button;

    print nbsp(1);
    print reset( -class => 'smbutton' );
    print "<p>\n";

    GenomeListJSON::showGenomeCart($numTaxon);
    printStatusLine( "Loaded.", 2 );
    print end_form();

    print "</div>";
}

############################################################################
# Gets Over cut off value from  param("overabundant"), default is 1
# return integer
############################################################################
sub getOverCutOff {
    my $over = param("overabundant");
    if ( !defined($over) || $over eq "" ) {
        $over = 1;
    }
    return $over;
}

############################################################################
# Gets Under cut off value from param("underabundant"), default is 1
# return integer
############################################################################
sub getUnderCutOff {
    my $under = param("underabundant");
    if ( !defined($under) || $under eq "" ) {
        $under = 1;
    }
    return $under;
}

############################################################################
# printAbundanceProfileRun
# Run the form selection and show results.
#
# when the user presses the go button main.cgi will call this method
# to start the processing
############################################################################
sub printAbundanceProfileRun {
    my @queryGenome       = param("selectedGenome1");
    my @referenceGenomes2 = param("selectedGenome2");
    my @referenceGenomes3 = param("selectedGenome3");

    my $q_data_type  = param("q_data_type");
    my $r_data_type2 = param("r_data_type2");
    my $r_data_type3 = param("r_data_type3");

    # these should be numbers or blank / null
    my $over             = getOverCutOff();
    my $under            = getUnderCutOff();
    my $func_type        = param("cluster");
    my $data_type        = param("data_type");
    my $clusterMatchText = param("clusterMatchText");

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my %taxon_in_file;
    if ($in_file) {
        %taxon_in_file = MerFsUtil::getTaxonsInFile($dbh);
    }

    # list of user selected in taxon ids
    my @intoi = @queryGenome;
    my @intoiBin;

    # list of user selected over taxon ids
    my @posProfileTaxonOids = @referenceGenomes2;
    my @posProfileBinOids;

    # list of user selected under taxon ids
    my @negProfileTaxonOids = @referenceGenomes3;
    my @negProfileBinOids;

    # check to see if user selected in taxons
    if (   ( !(@intoi) || $#intoi < 0 )
        && ( !(@intoiBin) || $#intoiBin < 0 ) )
    {
        webError( "Please select a genome " . "in the \"Find Functions In\" column." );
        return;
    }

    # first column table header
    my $idColHeader = AbundanceToolkit::getFuncHeader($func_type);

    print "<h1>Abundance Profile Search Results</h1>\n";
    print "<p>\n";
    print "Functional classification: " . $idColHeader;

    printStartWorkingDiv();

    # result hash ref
    # hash of hashes
    # cog or pfam id => taxon hash => gene count
    #
    # update query 1 for bins
    # this has 'b' or 't' for bin oid or taxon oid
    my $results_ref = runJobFunc(
        $dbh,                \@intoi,             \@posProfileTaxonOids, \@negProfileTaxonOids, \@intoiBin,
        \@posProfileBinOids, \@negProfileBinOids, $func_type,            $data_type
    );

    # hash ref of either cog names or pfam names
    # cog id or pfam id => name
    my $x_names_ref = AbundanceToolkit::getFuncDict( $dbh, $func_type );

    # get hash ref of taxon names
    # update to get bin names
    # these name's ids havea prefix of t or b
    my $taxon_names_ref =
      getTaxonNames( $dbh, \@intoi, \@posProfileTaxonOids, \@negProfileTaxonOids, \@intoiBin, \@posProfileBinOids,
        \@negProfileBinOids );

    print "Caching... <br>\n";
    printEndWorkingDiv();

    #
    # CACHE data to tmp file with name abundanceResults<process id>
    #
    my $cacheResultsFile = "abundanceResults$$";
    my $cacheResultsPath = "$cgi_tmp_dir/$cacheResultsFile";
    my $res              = newWriteFileHandle( $cacheResultsPath, "runJob" );

    webLog("===========\n");
    webLog("${section}: cache file path = $cacheResultsPath \n");
    webLog("===========\n");

    # number of data rows
    my $rowId = 0;

    #
    # lets save table column header too
    #

    # column 1
    print $res "$idColHeader ID";

    # column 2
    print $res "\t$idColHeader Name";

    # in taxon names
    foreach my $tid (@intoi) {

        # I used the In<br> as a tag for font color
        # I use : to separate taxon id and taxon name
        if ( defined($taxon_names_ref)
            && exists( $taxon_names_ref->{ 't' . $tid } ) )
        {
            my $taxonname = $taxon_names_ref->{ 't' . $tid };
            if ( $taxon_in_file{$tid} ) {
                $taxonname .= " (MER-FS)";
                if (   $data_type =~ /assembled/i
                    || $data_type =~ /unassembled/i )
                {
                    $taxonname .= " ($data_type)";
                }
            }
            print $res "\tIn<br>t$tid:$taxonname";
        } else {
            print $res "\tIn<br>t$tid:";
        }
    }
    foreach my $tid (@intoiBin) {

        # I used the In<br> as a tag for font color
        # I use : to separate taxon id and taxon name
        if ( defined($taxon_names_ref)
            && exists( $taxon_names_ref->{ 'b' . $tid } ) )
        {
            my $taxonname = $taxon_names_ref->{ 'b' . $tid };
            print $res "\tIn<br>b$tid:$taxonname";
        } else {
            print $res "\tIn<br>b$tid:";
        }
    }

    # over taxon names
    foreach my $tid (@posProfileTaxonOids) {

        # I used the Over<br> as a tag for font color
        if ( defined($taxon_names_ref)
            && exists( $taxon_names_ref->{ 't' . $tid } ) )
        {
            my $taxonname = $taxon_names_ref->{ 't' . $tid };
            if ( $taxon_in_file{$tid} ) {
                $taxonname .= " (MER-FS)";
                if (   $data_type =~ /assembled/i
                    || $data_type =~ /unassembled/i )
                {
                    $taxonname .= " ($data_type)";
                }
            }
            print $res "\tOver<br>t$tid:$taxonname";
        } else {
            print $res "\tOver<br>t$tid:";
        }
    }

    foreach my $tid (@posProfileBinOids) {

        # I used the Over<br> as a tag for font color
        if ( defined($taxon_names_ref)
            && exists( $taxon_names_ref->{ 'b' . $tid } ) )
        {
            my $taxonname = $taxon_names_ref->{ 'b' . $tid };
            print $res "\tOver<br>b$tid:$taxonname";
        } else {
            print $res "\tOver<br>b$tid:";
        }
    }

    # under
    foreach my $tid (@negProfileTaxonOids) {

        # I used the Under<br> as a tag for font color
        if ( defined($taxon_names_ref)
            && exists( $taxon_names_ref->{ 't' . $tid } ) )
        {
            my $taxonname = $taxon_names_ref->{ 't' . $tid };
            if ( $taxon_in_file{$tid} ) {
                $taxonname .= " (MER-FS)";
                if (   $data_type =~ /assembled/i
                    || $data_type =~ /unassembled/i )
                {
                    $taxonname .= " ($data_type)";
                }
            }
            print $res "\tUnder<br>t$tid:$taxonname";
        } else {
            print $res "\tUnder<br>t$tid:";
        }
    }

    foreach my $tid (@negProfileBinOids) {

        # I used the Under<br> as a tag for font color
        if ( defined($taxon_names_ref)
            && exists( $taxon_names_ref->{ 'b' . $tid } ) )
        {
            my $taxonname = $taxon_names_ref->{ 'b' . $tid };
            print $res "\tUnder<br>b$tid:$taxonname";
        } else {
            print $res "\tUnder<br>b$tid:";
        }
    }

    # new line - end of table column header
    print $res "\n";

    # variables used to pass form values to myformatByshowresult()
    my $norm      = paramMatch("norm");
    my $counttype = paramMatch("counttype");

    #
    # table data rows
    #
    # the $results_ref has the t or b for taxon or bin ids
    foreach my $func_id ( sort keys %$results_ref ) {
        $rowId++;
        my $xname = $x_names_ref->{$func_id};

        #print "printAbundanceProfileRun() $func_id name: $xname<br/>\n";

        # see if the text matches if so append * to the id
        if (   defined($clusterMatchText)
            && $clusterMatchText ne ""
            && $xname =~ /$clusterMatchText/i )
        {

            # highlight the matching text
            print $res "$func_id*\t";
        } else {
            print $res "$func_id\t";
        }
        print $res "$xname";

        # in taxon cogs or pfam gene counts
        foreach my $tid (@intoi) {
            my $gcount;
            if ( !exists $results_ref->{$func_id}->{ 't' . $tid } ) {
                $gcount = 0;
                $gcount = "$func_id, $tid";
            } else {
                $gcount = myformatByshowresult( $results_ref->{$func_id}->{ 't' . $tid }, $norm, $counttype );
            }
            print $res "\t$gcount";
        }

        # bin
        foreach my $tid (@intoiBin) {
            my $gcount;
            if ( !exists $results_ref->{$func_id}->{ 'b' . $tid } ) {
                $gcount = 0;
            } else {
                $gcount = myformatByshowresult( $results_ref->{$func_id}->{ 'b' . $tid }, $norm, $counttype );
            }
            print $res "\t$gcount";
        }

        # over taxon cogs or pfam gene counts
        foreach my $tid (@posProfileTaxonOids) {
            my $gcount;
            if ( !exists $results_ref->{$func_id}->{ 't' . $tid } ) {
                $gcount = 0;
            } else {
                $gcount = myformatByshowresult( $results_ref->{$func_id}->{ 't' . $tid }, $norm, $counttype );
            }
            print $res "\t$gcount";
        }

        # pos bin
        foreach my $tid (@posProfileBinOids) {
            my $gcount;
            if ( !exists $results_ref->{$func_id}->{ 'b' . $tid } ) {
                $gcount = 0;
            } else {
                $gcount = myformatByshowresult( $results_ref->{$func_id}->{ 'b' . $tid }, $norm, $counttype );
            }
            print $res "\t$gcount";
        }

        # under taxon func gene counts
        foreach my $tid (@negProfileTaxonOids) {
            my $gcount;
            if ( !exists $results_ref->{$func_id}->{ 't' . $tid } ) {
                $gcount = 0;
            } else {
                $gcount = myformatByshowresult( $results_ref->{$func_id}->{ 't' . $tid }, $norm, $counttype );
            }
            print $res "\t$gcount";
        }

        # neg bin
        foreach my $tid (@negProfileBinOids) {
            my $gcount;
            if ( !exists $results_ref->{$func_id}->{ 'b' . $tid } ) {
                $gcount = 0;
            } else {
                $gcount = myformatByshowresult( $results_ref->{$func_id}->{ 'b' . $tid }, $norm, $counttype );
            }
            print $res "\t$gcount";
        }

        print $res "\n";
    }

    # close cache tmp file
    close $res;

    if ($rowId) {
        ## Print out table with button for more results.
        printAbundanceProfileResultsPage($cacheResultsFile);
    } else {
        printStatusLine( "No rows loaded.", 2 );
        printMessage("There are no results that match your search criteria.");
    }
}

############################################################################
# param $dbh database handler
# param $toi_ref array list of in taxon ids
# param $posProfileTaxonBinOids_ref array list of over taxon ids
# param $negProfileTaxonBinOids_ref array list of under taxon ids
#
# param $intoiBin_ref
# param $posProfileBinOids_ref
# param $negProfileBinOids_ref
#
# return filter results hash ref. Its hashes of hashes
# func  id => t or b .  taxon hash => gene count
############################################################################
sub runJobFunc {
    my (
        $dbh,                     $toi_ref,      $posProfileTaxonOids_ref,
        $negProfileTaxonOids_ref, $intoiBin_ref, $posProfileBinOids_ref,
        $negProfileBinOids_ref,   $func_type,    $data_type
      )
      = @_;

    my $showresult = param("showresult");

    # Use estimated gene copy or gene count based on user selection
    my $aggFunc;
    if ( $showresult eq "gcnt" ) {
        $aggFunc = "count( distinct g.gene_oid )";
    } else {
        $aggFunc = "sum( g.est_copy )";
    }

    # func id taxon count
    # hash of hashes
    # func id => type (t or b) + hash taxon id or bin id => count
    my %funcsTaxonGcount;

    # it can be either taxon or bin query, depends what the user selected
    # in the 'in' column

    # 1st get all funcs for selected 'in' taxons
    print "Processing selected genomes<br>\n";

    my $sql;
    my $oids_str;

    if ( scalar(@$intoiBin_ref) > 0 ) {
        $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @$intoiBin_ref );
        $sql = getFuncBinSql( $func_type, $aggFunc, $oids_str );

    } else {

        # add taxon
        my ( $dbTaxons_ref, $fs_taxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @$toi_ref );

        if ( scalar(@$dbTaxons_ref) > 0 ) {
            $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @$dbTaxons_ref );
            $sql = getFuncDbTaxonSql( $func_type, $aggFunc, $oids_str );
        }

        for my $t2 (@$fs_taxons_ref) {
            if ( $showresult eq "gcnt" ) {
                my %funcs = MetaUtil::getTaxonFuncCount( $t2, $data_type, $func_type );
                $t2 = 't' . $t2;
                for my $id ( keys %funcs ) {
                    my $g_cnt = $funcs{$id};
                    if ( !exists $funcsTaxonGcount{$id} ) {
                        my %tmp;
                        $tmp{$t2}              = $g_cnt;
                        $funcsTaxonGcount{$id} = \%tmp;
                    } else {
                        $funcsTaxonGcount{$id}{$t2} = $g_cnt;
                    }
                }
            } else {

                #est
                my ( $profile_href, $last_id ) =
                  AbundanceToolkit::getMetaTaxonFuncEstCopies( $dbh, $t2, $func_type, $data_type );
                $t2 = 't' . $t2;
                for my $id ( keys %$profile_href ) {
                    my $g_cnt = $profile_href->{$id};
                    if ( !exists $funcsTaxonGcount{$id} ) {
                        my %tmp;
                        $tmp{$t2}              = $g_cnt;
                        $funcsTaxonGcount{$id} = \%tmp;
                    } else {
                        $funcsTaxonGcount{$id}{$t2} = $g_cnt;
                    }
                }
            }
        }
    }

    if ($sql) {
        my $cur = execSql( $dbh, $sql, 1 );
        for ( ; ; ) {
            my ( $id, $taxonoid, $genecount ) = $cur->fetchrow();
            last if !$id;
            if ( !exists $funcsTaxonGcount{$id} ) {
                my %tmp;
                $tmp{$taxonoid} = $genecount;

                # now here if needed add the 'over' and 'under'
                # hashes such that each hash is the same size

                # this might be done during normalizing
                #foreach my $xid (@$posProfileTaxonBinOids_ref) {

                # default count is 0 it maybe updated by the 2nd query
                #   $tmp{$xid} = 0;
                #}

                #foreach my $xid (@$negProfileTaxonBinOids_ref) {

                # default count is 0 it maybe updated by the 3rd query
                #   $tmp{$xid} = 0;
                #}

                $funcsTaxonGcount{$id} = \%tmp;

            } else {
                $funcsTaxonGcount{$id}{$taxonoid} = $genecount;
            }
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $oids_str =~ /gtt_num_id/i );

    }

    # 2nd get all funcs for select over taxons
    # but ignore funcs if not in the 'in' list above
    if (   scalar(@$posProfileTaxonOids_ref) > 0
        || scalar(@$posProfileBinOids_ref) > 0 )
    {
        print "Processing less abundant (2nd column) selected genomes<br>\n";
        my $count    = 0;
        my $innercnt = 0;

        my $sql;
        my $oids_str1;
        if ( scalar(@$posProfileTaxonOids_ref) > 0 ) {
            my ( $dbTaxons_ref, $fs_taxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @$posProfileTaxonOids_ref );

            if ( scalar(@$dbTaxons_ref) > 0 ) {
                $oids_str1 = OracleUtil::getNumberIdsInClause( $dbh, @$dbTaxons_ref );
                $sql = getFuncDbTaxonSql( $func_type, $aggFunc, $oids_str1 );
            }

            for my $t2 (@$fs_taxons_ref) {
                if ( $showresult eq "gcnt" ) {
                    my %funcs = MetaUtil::getTaxonFuncCount( $t2, $data_type, $func_type );
                    $t2 = 't' . $t2;
                    for my $id ( keys %funcs ) {
                        if ( !exists $funcsTaxonGcount{$id} ) {

                            # this func was not in the 'in' list so skip it
                            next;
                        } else {
                            my $g_cnt = $funcs{$id};
                            $funcsTaxonGcount{$id}{$t2} = $g_cnt;
                        }

                        $count++;
                        if ( $count % $message_cnt_wrap == 0 ) {
                            print ".";
                            $innercnt++;
                            print "<br>\n" if ( $innercnt % $dot_cnt_wrap == 0 );
                        }
                    }
                } else {

                    #est
                    my ( $profile_href, $last_id ) =
                      AbundanceToolkit::getMetaTaxonFuncEstCopies( $dbh, $t2, $func_type, $data_type );
                    $t2 = 't' . $t2;
                    for my $id ( keys %$profile_href ) {
                        if ( !exists $funcsTaxonGcount{$id} ) {

                            # this func was not in the 'in' list so skip it
                            next;
                        } else {
                            my $g_cnt = $profile_href->{$id};
                            $funcsTaxonGcount{$id}{$t2} = $g_cnt;
                        }

                        $count++;
                        if ( $count % $message_cnt_wrap == 0 ) {
                            print ".";
                            $innercnt++;
                            print "<br>\n" if ( $innercnt % $dot_cnt_wrap == 0 );
                        }
                    }
                }
            }
        }

        # add bins
        my $oids_str2;
        if ( scalar(@$posProfileBinOids_ref) > 0 ) {
            $oids_str2 = OracleUtil::getNumberIdsInClause1( $dbh, @$posProfileBinOids_ref );
            my $sql2 = getFuncBinSql( $func_type, $aggFunc, $oids_str2 );

            if ( $sql ne "" ) {
                $sql = $sql . " union all " . $sql2;
            } else {
                $sql = $sql2;
            }
        }

        if ($sql) {
            my $cur = execSql( $dbh, $sql, 1 );

            for ( ; ; ) {
                my ( $id, $taxonoid, $genecount ) = $cur->fetchrow();
                last if !$id;
                if ( !exists $funcsTaxonGcount{$id} ) {

                    # this func was not in the 'in' list so skip it
                    next;
                } else {
                    $funcsTaxonGcount{$id}{$taxonoid} = $genecount;
                }
                $count++;
                if ( $count % $message_cnt_wrap == 0 ) {
                    print ".";
                    $innercnt++;
                    print "<br>\n" if ( $innercnt % $dot_cnt_wrap == 0 );
                }
            }
            $cur->finish();

            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $oids_str1 =~ /gtt_num_id/i );

            OracleUtil::truncTable( $dbh, "gtt_num_id1" )
              if ( $oids_str2 =~ /gtt_num_id1/i );
        }

        print "\n<br>$count records processed<br>\n";
    }

    # 3rd get all cogs for select under taxons
    # but ignore cogs if not in the 'in' list above
    if (   scalar(@$negProfileTaxonOids_ref) > 0
        || scalar(@$negProfileBinOids_ref) > 0 )
    {

        print "Processing more abundant (3rd column) selected genomes<br>\n";
        my $count    = 0;
        my $innercnt = 0;

        my $sql;
        my $oids_str1;
        if ( scalar(@$negProfileTaxonOids_ref) > 0 ) {
            my ( $dbTaxons_ref, $fs_taxons_ref ) = MerFsUtil::findTaxonsInFile( $dbh, @$negProfileTaxonOids_ref );

            if ( scalar(@$dbTaxons_ref) > 0 ) {
                $oids_str1 = OracleUtil::getNumberIdsInClause( $dbh, @$dbTaxons_ref );
                $sql = getFuncDbTaxonSql( $func_type, $aggFunc, $oids_str1 );
            }

            for my $t2 (@$fs_taxons_ref) {
                if ( $showresult eq "gcnt" ) {
                    my %funcs = MetaUtil::getTaxonFuncCount( $t2, $data_type, $func_type );
                    $t2 = 't' . $t2;
                    for my $id ( keys %funcs ) {
                        if ( !exists $funcsTaxonGcount{$id} ) {

                            # this func was not in the 'in' list so skip it
                            next;
                        } else {
                            my $g_cnt = $funcs{$id};
                            $funcsTaxonGcount{$id}{$t2} = $g_cnt;
                        }

                        $count++;
                        if ( $count % $message_cnt_wrap == 0 ) {
                            print ".";
                            $innercnt++;
                            print "<br>\n" if ( $innercnt % $dot_cnt_wrap == 0 );
                        }
                    }
                } else {

                    #est
                    my ( $profile_href, $last_id ) =
                      AbundanceToolkit::getMetaTaxonFuncEstCopies( $dbh, $t2, $func_type, $data_type );
                    $t2 = 't' . $t2;
                    for my $id ( keys %$profile_href ) {
                        if ( !exists $funcsTaxonGcount{$id} ) {

                            # this func was not in the 'in' list so skip it
                            next;
                        } else {
                            my $g_cnt = $profile_href->{$id};
                            $funcsTaxonGcount{$id}{$t2} = $g_cnt;
                        }

                        $count++;
                        if ( $count % $message_cnt_wrap == 0 ) {
                            print ".";
                            $innercnt++;
                            print "<br>\n" if ( $innercnt % $dot_cnt_wrap == 0 );
                        }
                    }
                }

            }

        }

        # add bins
        my $oids_str2;
        if ( scalar(@$negProfileBinOids_ref) > 0 ) {
            $oids_str2 = OracleUtil::getNumberIdsInClause1( $dbh, @$negProfileBinOids_ref );
            my $sql2 = getFuncBinSql( $func_type, $aggFunc, $oids_str2 );

            if ( $sql ne "" ) {
                $sql = $sql . " union all " . $sql2;
            } else {
                $sql = $sql2;
            }
        }

        if ($sql) {
            my $cur = execSql( $dbh, $sql, 1 );
            for ( ; ; ) {
                my ( $id, $taxonoid, $genecount ) = $cur->fetchrow();
                last if !$id;
                if ( !exists $funcsTaxonGcount{$id} ) {

                    # this func was not in the 'in' list so skip it
                    next;
                } else {
                    $funcsTaxonGcount{$id}{$taxonoid} = $genecount;
                }
                $count++;
                if ( $count % $message_cnt_wrap == 0 ) {
                    print ".";
                    $innercnt++;
                    print "<br>\n" if ( $innercnt % $dot_cnt_wrap == 0 );
                }
            }
            $cur->finish();

            OracleUtil::truncTable( $dbh, "gtt_num_id" )
              if ( $oids_str1 =~ /gtt_num_id/i );

            OracleUtil::truncTable( $dbh, "gtt_num_id1" )
              if ( $oids_str2 =~ /gtt_num_id1/i );

        }

        print "\n<br>$count records processed<br>\n";
    }

    # over and under amounts, else should be numbers
    my $over  = getOverCutOff();
    my $under = getUnderCutOff();

    # norm type is c f or z
    print "Normalizing... <br>\n";
    if ( param("doNormalization") eq 'z' ) {

        # z -score
        # add bins
        #if ( $func_type eq "cog" ) {
        #    zNormalizeCog(
        #        $dbh,                     $toi_ref,
        #        $posProfileTaxonOids_ref, $negProfileTaxonOids_ref,
        #        \%funcsTaxonGcount,        $intoiBin_ref,
        #        $posProfileBinOids_ref,   $negProfileBinOids_ref
        #    );
        #} elsif ( $func_type eq "enzyme" ) {
        #    zNormalizeEnzyme(
        #        $dbh,                     $toi_ref,
        #        $posProfileTaxonOids_ref, $negProfileTaxonOids_ref,
        #        \%funcsTaxonGcount,        $intoiBin_ref,
        #        $posProfileBinOids_ref,   $negProfileBinOids_ref
        #    );
        #} elsif ( $func_type eq "ko" ) {
        #
        #} elsif ( $func_type eq "pfam" ) {
        #    zNormalizePfam(
        #        $dbh,                     $toi_ref,
        #        $posProfileTaxonOids_ref, $negProfileTaxonOids_ref,
        #        \%funcsTaxonGcount,       $intoiBin_ref,
        #        $posProfileBinOids_ref,   $negProfileBinOids_ref
        #    );
        #} elsif ( $func_type eq "tigrfam" ) {
        #    zNormalizePfam(
        #        $dbh,                     $toi_ref,
        #        $posProfileTaxonOids_ref, $negProfileTaxonOids_ref,
        #        \%funcsTaxonGcount,       $intoiBin_ref,
        #        $posProfileBinOids_ref,   $negProfileBinOids_ref
        #    );
        #}
    } elsif ( param("doNormalization") eq 'f' ) {

        # freq normalization
        # add bins
        freqNormalize( $dbh, $toi_ref, $posProfileTaxonOids_ref, $negProfileTaxonOids_ref, \%funcsTaxonGcount, $intoiBin_ref,
            $posProfileBinOids_ref, $negProfileBinOids_ref );
    }

    # else counts or none - no normalization

    # add bins

    # this filter hash of '%funcsTaxonGcount' and data is:
    # func id => type (t or b)+ hash taxon id  or bin oid => count
    #
    print "Filtering... <br>\n";
    my $filtered = getOverUnderAbundanceList(
        $toi_ref,               $posProfileTaxonOids_ref, $negProfileTaxonOids_ref, \%funcsTaxonGcount,
        $over,                  $under,                   param("doNormalization"), $intoiBin_ref,
        $posProfileBinOids_ref, $negProfileBinOids_ref
    );

    return $filtered;
}

sub getFuncBinSql {
    my ( $func_type, $aggFunc, $bin_oids_str ) = @_;

    my $sql;

    if ( $func_type eq "cog" ) {

        # add bins
        $sql = qq{
            select gcg.cog, 'b' || b.bin_oid, $aggFunc
            from bin b, bin_scaffolds bs, gene_cog_groups gcg, gene g
            where b.bin_oid in ($bin_oids_str)
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gcg.scaffold
            and gcg.gene_oid = g.gene_oid
            group by gcg.cog, b.bin_oid
        };

    } elsif ( $func_type eq "enzyme" ) {

        # add bins
        $sql = qq{
            select gf.enzymes, 'b' || b.bin_oid, $aggFunc
            from bin b, bin_scaffolds bs, gene_ko_enzymes gf, gene g
            where b.bin_oid in ($bin_oids_str)
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gf.scaffold
            and gf.gene_oid = g.gene_oid
            group by gf.enzymes, b.bin_oid
        };

    } elsif ( $func_type eq "ko" ) {

        # add bins
        $sql = qq{
            select gk.ko_terms, 'b' || b.bin_oid, $aggFunc
            from bin b, bin_scaffolds bs, gene_ko_terms gk, gene g
            where b.bin_oid in ($bin_oids_str)
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gk.scaffold
            and gk.gene_oid = g.gene_oid
            group by gk.ko_terms, b.bin_oid
        };

    } elsif ( $func_type eq "pfam" ) {

        # add bins
        $sql = qq{
            select gf.pfam_family, 'b' || b.bin_oid, $aggFunc
            from bin b, bin_scaffolds bs, gene_pfam_families gf, gene g
            where b.bin_oid in ($bin_oids_str)
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gf.scaffold
            and gf.gene_oid = g.gene_oid
            group by gf.pfam_family, b.bin_oid
        };

    } elsif ( $func_type eq "tigrfam" ) {

        # add bins
        $sql = qq{
            select gf.ext_accession, 'b' || b.bin_oid, $aggFunc
            from bin b, bin_scaffolds bs, gene g, gene_tigrfams gf
            where b.bin_oid in ($bin_oids_str)
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gf.scaffold
            and gf.gene_oid = g.gene_oid
            group by gf.ext_accession, b.bin_oid
        };
    }

    #print "getFuncBinSql() sql: $sql<br/>\n";

    return ($sql);

}

sub getFuncDbTaxonSql {
    my ( $func_type, $aggFunc, $db_oids_str ) = @_;

    my $sql;

    if ( $func_type eq "cog" ) {
        $sql = qq{
            select gcg.cog, 't' || g.taxon, $aggFunc
            from gene_cog_groups gcg, gene g
            where gcg.gene_oid = g.gene_oid
            and g.taxon in ($db_oids_str)
            group by gcg.cog, g.taxon
        };

    } elsif ( $func_type eq "enzyme" ) {
        $sql = qq{
            select gf.enzymes, 't' || g.taxon, $aggFunc
            from gene_ko_enzymes gf, gene g
            where gf.gene_oid = g.gene_oid
            and g.taxon in ($db_oids_str)
            group by gf.enzymes, g.taxon
        };

    } elsif ( $func_type eq "ko" ) {
        $sql = qq{
            select gk.ko_terms, 't' || g.taxon, $aggFunc
            from gene_ko_terms gk, gene g
            where gk.gene_oid = g.gene_oid
            and g.taxon in ($db_oids_str)
            group by gk.ko_terms, g.taxon
        };

    } elsif ( $func_type eq "pfam" ) {
        $sql = qq{
            select gf.pfam_family, 't' || g.taxon, $aggFunc
            from gene_pfam_families gf, gene g
            where gf.gene_oid = g.gene_oid
            and g.taxon in ($db_oids_str)
            group by gf.pfam_family, g.taxon
        };

    } elsif ( $func_type eq "tigrfam" ) {
        $sql = qq{
            select gf.ext_accession, 't' || g.taxon, $aggFunc
            from gene_tigrfams gf, gene g
            where gf.gene_oid = g.gene_oid
            and g.taxon in ($db_oids_str)
            group by gf.ext_accession, g.taxon
        };
    }

    #print "getFuncDbTaxonSql() sql: $sql<br/>\n";

    return ($sql);

}

############################################################################
# Gets scale factor using in dt_cog_abundance, dt_enzyme_abundance,
# dt_pfam_abundance table, dt_tigrfam_abundance table
# But for now I'll hard code it for speed
# param $dbh database handler - not used right now
# return scale factor number
############################################################################
sub getScaleFactor {
    my ($dbh) = @_;

    # this should be query but for now it return the value

    return 1000000;
}

############################################################################
# gets taxon names
# param $dbh database handler
# param $toi_ref array list of in taxon ids
# param $posProfileTaxonBinOids_ref array list of over taxon ids
# param $negProfileTaxonBinOids_ref array list of under taxon ids
# return hash ref: id => name
############################################################################
sub getTaxonNames {
    my ( $dbh, $toi_ref, $posProfileTaxonOids_ref, $negProfileTaxonOids_ref, $binoi_ref, $posbinOids_ref, $negbinOids_ref ) =
      @_;

    my %taxon_in_file;

    if ($in_file) {
        my $sql2 = "select t.taxon_oid from taxon t where t.$in_file = 'Yes'";
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ($t2) = $cur2->fetchrow();
            last if !$t2;

            $taxon_in_file{$t2} = 1;
        }
        $cur2->finish();
    }

    my $taxonoids = join( ',', @$toi_ref );
    my $posids    = join( ',', @$posProfileTaxonOids_ref );
    my $negids    = join( ',', @$negProfileTaxonOids_ref );

    my $binnoids  = join( ',', @$binoi_ref );
    my $binposids = join( ',', @$posbinOids_ref );
    my $binnegids = join( ',', @$negbinOids_ref );

    my $allids = "$taxonoids";
    if ( defined($posids) && $posids ne "" ) {
        if ( $allids ne "" ) {
            $allids .= ",";
        }
        $allids .= "$posids";
    }
    if ( defined($negids) && $negids ne "" ) {
        if ( $allids ne "" ) {
            $allids .= ",";
        }
        $allids .= " $negids";
    }

    my $sql = "";
    if ( defined($allids) && $allids ne "" ) {
        $sql = qq{select 't' || taxon_oid, taxon_name 
		from taxon
		where taxon_oid in ($allids)};
    }

    my $allbinids = $binnoids;
    if ( defined($binposids) && $binposids ne "" ) {

        if ( $allbinids ne "" ) {
            $allbinids .= ",";
        }
        $allbinids .= " $binposids";
    }
    if ( defined($binnegids) && $binnegids ne "" ) {
        if ( $allbinids ne "" ) {
            $allbinids .= ",";
        }
        $allbinids .= " $binnegids";
    }

    if ( defined($allbinids) && $allbinids ne "" ) {
        if ( $sql ne "" ) {
            $sql .= " union all ";
        }

        $sql .= qq{
			select 'b' || bin_oid, display_name
			from bin
			where bin_oid in ($allbinids)
			};
    }

    my %results;
    my $cur = execSql( $dbh, $sql, 1 );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;

        if ( $taxon_in_file{$id} ) {
            $name .= " (MER-FS)";
        }
        $results{$id} = $name;
    }
    $cur->finish();
    return \%results;
}

############################################################################
# gets all taxon id => total gene count
# param $dbh database handler
# param $taxonoids a comma delimited list
# param $posids a comma delimited list
# param $negids a comma delimited list
# return hash ref 't' || taxon id => total gen count
############################################################################
sub getTaxonOid2GeneCount {
    my ( $dbh, $taxonoids, $posids, $negids ) = @_;

    # hash of taxon id => total gene count
    my %taxonOid2GeneCount;

    if ( $taxonoids eq "" && $posids eq "" && $negids eq "" ) {
        return \%taxonOid2GeneCount;
    }

    # Get no. of genes per taxon (used for normalization).
    my $sql = qq{
    	select 't' || tx.taxon_oid, dt.total_gene_count, tx.taxon_name
    	from taxon tx, taxon_stats dt
    	where tx.domain not like 'Vir%'
    	and tx.taxon_oid = dt.taxon_oid
    	and tx.taxon_oid in ($taxonoids};

    if ( defined($posids) && $posids ne "" ) {

        if ( $taxonoids ne "" ) {
            $sql = $sql . ",";
        }

        $sql = $sql . " $posids ";
    }
    if ( defined($negids) && $negids ne "" ) {
        if ( $taxonoids ne "" || $posids ne "" ) {
            $sql = $sql . ",";
        }
        $sql = $sql . " $negids";
    }
    $sql = $sql . ")";

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $taxon_oid, $total_gene_count ) = $cur->fetchrow();
        last if !$taxon_oid;

        $taxonOid2GeneCount{$taxon_oid} = $total_gene_count;
    }
    $cur->finish();

    return \%taxonOid2GeneCount;
}

############################################################################
# gets all bin id => total gene count
# param $dbh database handler
# param $binoids a comma delimited list
# param $posids a comma delimited list
# param $negids a comma delimited list
# return hash ref 'b' || bin id => total gen count
############################################################################
sub getBinOid2GeneCount {
    my ( $dbh, $binoids, $posids, $negids ) = @_;

    # hash of taxon id => total gene count
    my %binOid2GeneCount;

    if ( $binoids eq "" && $posids eq "" && $negids eq "" ) {
        return \%binOid2GeneCount;
    }

    # Get no. of genes per taxon (used for normalization).
    my $sql = qq{
		select 'b' || bin_oid, $nvl(genes_in_enzymes,0) + $nvl(genes_in_cog,0)  + 
		$nvl(genes_in_pfam,0) + $nvl(genes_in_tigrfam, 0)
		from bin_stats
    	        where bin_oid in ($binoids};

    if ( defined($posids) && $posids ne "" ) {

        if ( $binoids ne "" ) {
            $sql = $sql . ",";
        }

        $sql = $sql . " $posids ";
    }
    if ( defined($negids) && $negids ne "" ) {
        if ( $binoids ne "" || $posids ne "" ) {
            $sql = $sql . ",";
        }
        $sql = $sql . " $negids";
    }
    $sql = $sql . ")";

    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $taxon_oid, $total_gene_count ) = $cur->fetchrow();
        last if !$taxon_oid;

        $binOid2GeneCount{$taxon_oid} = $total_gene_count;
    }
    $cur->finish();

    return \%binOid2GeneCount;
}

############################################################################
# do frequency normalization for cog, enzyme, pfam, tigrfam
# param $dbh database handler
# param $toi_ref array ref to 'in' taxon ids
# param $posTaxonOids_ref array ref to 'over' taxon ids
# param $negTaxonOids_ref array ref to 'under' taxon ids
# param $funcidTaxonGcount_ref has ref of:
#       pfam => hash (t or b)taxon id => count
#       this hash ref will be updated
#
# param $intoiBin_ref bin ids
# param $posBinOids_ref bin ids
# param $negBinOids_ref bin ids
############################################################################
sub freqNormalize {
    my ( $dbh, $toi_ref, $posTaxonOids_ref, $negTaxonOids_ref, $funcidTaxonGcount_ref, $intoiBin_ref, $posBinOids_ref,
        $negBinOids_ref )
      = @_;

    # get scale factor
    my $scale = getScaleFactor();

    # get all taxon id to total gene count
    my $taxonoids = join( ',', @$toi_ref );
    my $posids    = join( ',', @$posTaxonOids_ref );
    my $negids    = join( ',', @$negTaxonOids_ref );

    my $binoids   = join( ',', @$intoiBin_ref );
    my $binposids = join( ',', @$posBinOids_ref );
    my $binnegids = join( ',', @$negBinOids_ref );

    # taxon id has a 't' prefix
    my $taxonOid2GeneCount = getTaxonOid2GeneCount( $dbh, $taxonoids, $posids, $negids );

    # bin id has a 'b' prefix
    my $binOid2GeneCount = getBinOid2GeneCount( $dbh, $binoids, $binposids, $binnegids );

    # $funcidTaxonGcount remember t or b prefix
    # now normalize all data - k is func id
    foreach my $k ( keys %$funcidTaxonGcount_ref ) {

        # hash ref to taxon id to gene count
        my $href = $funcidTaxonGcount_ref->{$k};

        # 'in' taxons
        foreach my $taxonid (@$toi_ref) {
            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
            my $gene_count       = 0;
            my $val              = 0;
            if ( exists( $href->{ 't' . $taxonid } ) ) {
                $val        = ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
                $gene_count = $href->{ 't' . $taxonid };
            }
            $href->{ 't' . $taxonid } = myformat( $gene_count, $val );
        }

        # 'over' taxons
        # if the taxon is not in hash, set it to 0
        foreach my $taxonid (@$posTaxonOids_ref) {
            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
            my $gene_count       = 0;
            my $val              = 0;
            if ( exists( $href->{ 't' . $taxonid } ) ) {
                $val        = ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
                $gene_count = $href->{ 't' . $taxonid };
            }
            $href->{ 't' . $taxonid } = myformat( $gene_count, $val );
        }

        # 'under' taxons
        # if the taxon is not in hash, set it to 0
        foreach my $taxonid (@$negTaxonOids_ref) {
            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
            my $gene_count       = 0;
            my $val              = 0;
            if ( exists( $href->{ 't' . $taxonid } ) ) {
                $val        = ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
                $gene_count = $href->{ 't' . $taxonid };
            }
            $href->{ 't' . $taxonid } = myformat( $gene_count, $val );
        }

        # now do the bin list
        # this $taxonid DOES NOT have b prefix, really bin id
        foreach my $taxonid (@$intoiBin_ref) {
            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
            my $gene_count       = 0;
            my $val              = 0;
            if ( exists( $href->{ 'b' . $taxonid } ) ) {
                $val        = ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
                $gene_count = $href->{ 'b' . $taxonid };
            }
            $href->{ 'b' . $taxonid } = myformat( $gene_count, $val );
        }

        foreach my $taxonid (@$posBinOids_ref) {
            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
            my $gene_count       = 0;
            my $val              = 0;
            if ( exists( $href->{ 'b' . $taxonid } ) ) {
                $val        = ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
                $gene_count = $href->{ 'b' . $taxonid };
            }
            $href->{ 'b' . $taxonid } = myformat( $gene_count, $val );
        }

        foreach my $taxonid (@$negBinOids_ref) {
            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
            my $gene_count       = 0;
            my $val              = 0;
            if ( exists( $href->{ 'b' . $taxonid } ) ) {
                $val        = ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
                $gene_count = $href->{ 'b' . $taxonid };
            }
            $href->{ 'b' . $taxonid } = myformat( $gene_count, $val );
        }

    }
}

############################################################################
# do z normalization for pfam
# param $dbh database handler
# param $toi_ref array ref to 'in' taxon ids
# param $posTaxonOids_ref array ref to 'over' taxon ids
# param $negTaxonOids_ref array ref to 'under' taxon ids
# param $pfamTaxonGcount_ref has ref of:
#		cog => hash (t or b ) taxon id => count
#       this hash ref will be updated
#       format is of value: "$gene_count ($z)";
#
# param $intoiBin_ref bin ids
# param $posBinOids_ref bin ids
# param $negBinOids_ref bin ids
############################################################################
#sub zNormalizePfam {
#    my ( $dbh, $toi_ref, $posTaxonOids_ref, $negTaxonOids_ref,
#        $pfamTaxonGcount_ref, $intoiBin_ref, $posBinOids_ref, $negBinOids_ref )
#      = @_;
#
#    my $scale = getScaleFactorPfam();
#
#    my $taxonoids = join( ',', @$toi_ref );
#    my $posids    = join( ',', @$posTaxonOids_ref );
#    my $negids    = join( ',', @$negTaxonOids_ref );
#
#    # bin ids
#    my $binoids   = join( ',', @$intoiBin_ref );
#    my $binposids = join( ',', @$posBinOids_ref );
#    my $binnegids = join( ',', @$negBinOids_ref );
#
#    # taxon id has a 't' prefix
#    my $taxonOid2GeneCount =
#      getTaxonOid2GeneCount( $dbh, $taxonoids, $posids, $negids );
#
#    # bin id has a 'b' prefix
#    my $binOid2GeneCount =
#      getBinOid2GeneCount( $dbh, $binoids, $binposids, $binnegids );
#
#    # hash of array: cog id => [mean, std_dev ]
#    my %dtPfamAbundance;
#
#    my $sql = "";
#
#    if ( $taxonoids ne "" ) {
#        $sql = qq{select dca.pfam_id, dca.mean, dca.std_dev
#				from dt_pfam_abundance dca, gene_pfam_families gcg, gene g
#				where dca.pfam_id = gcg.pfam_family
#				and gcg.gene_oid = g.gene_oid
#				and g.taxon in ($taxonoids)};
#    } else {
#
#        # bin in query
#        $sql = qq{
#		select dca.pfam_id, dca.mean, dca.std_dev
#		from dt_pfam_abundance dca, gene_pfam_families gcg
#		where dca.pfam_id = gcg.pfam_family
#		and gcg.gene_oid in(
#		select g.gene_oid
#		from bin b, bin_scaffolds bs, scaffold s, gene g
#		where b.bin_oid = bs.bin_oid
#		and bs.scaffold = s.scaffold_oid
#		and s.scaffold_oid = g.scaffold
#		and b.bin_oid in( $binoids))
#		};
#
#    }
#
#    if ( defined($posids) && $posids ne "" ) {
#        $sql = $sql . qq{union
#				select dca.pfam_id, dca.mean, dca.std_dev
#				from dt_pfam_abundance dca, gene_pfam_families gcg, gene g
#				where dca.pfam_id = gcg.pfam_family
#				and gcg.gene_oid = g.gene_oid
#				and g.taxon in ($posids)
#				};
#    }
#
#    if ( defined($negids) && $negids ne "" ) {
#        $sql = $sql . qq{union
#				select dca.pfam_id, dca.mean, dca.std_dev
#				from dt_pfam_abundance dca, gene_pfam_families gcg, gene g
#				where dca.pfam_id = gcg.pfam_family
#				and gcg.gene_oid = g.gene_oid
#				and g.taxon in ($negids)
#				};
#    }
#
#    # pos bins
#    if ( $binposids ne "" ) {
#        $sql .= qq{union
#		select dca.pfam_id, dca.mean, dca.std_dev
#		from dt_pfam_abundance dca, gene_pfam_families gcg
#		where dca.pfam_id = gcg.pfam_family
#		and gcg.gene_oid in(
#		select g.gene_oid
#		from bin b, bin_scaffolds bs, scaffold s, gene g
#		where b.bin_oid = bs.bin_oid
#		and bs.scaffold = s.scaffold_oid
#		and s.scaffold_oid = g.scaffold
#		and b.bin_oid in($binposids))
#		};
#    }
#
#    # neg bins
#    if ( $binnegids ne "" ) {
#        $sql .= qq{union
#		select dca.pfam_id, dca.mean, dca.std_dev
#		from dt_pfam_abundance dca, gene_pfam_families gcg
#		where dca.pfam_id = gcg.pfam_family
#		and gcg.gene_oid in(
#		select g.gene_oid
#		from bin b, bin_scaffolds bs, scaffold s, gene g
#		where b.bin_oid = bs.bin_oid
#		and bs.scaffold = s.scaffold_oid
#		and s.scaffold_oid = g.scaffold
#		and b.bin_oid in($binnegids))
#		};
#    }
#
#    my $cur = execSql( $dbh, $sql, 1 );
#    for ( ; ; ) {
#        my ( $pfamid, $mean, $stddev ) = $cur->fetchrow();
#        last if !$pfamid;
#        if ( !exists( $dtPfamAbundance{$pfamid} ) ) {
#            my @tmp;
#            push( @tmp, $mean );
#            push( @tmp, $stddev );
#            $dtPfamAbundance{$pfamid} = \@tmp;
#        }
#    }
#    $cur->finish();
#
#    # $pfamTaxonGcount_ref remember t or b prefix
#    # k is pfam id
#    foreach my $k ( keys %$pfamTaxonGcount_ref ) {
#        my $mn = $dtPfamAbundance{$k}[0];
#        my $sd = $dtPfamAbundance{$k}[1];
#
#        # hash ref to 't' . taxon id to gene count
#        my $href = $pfamTaxonGcount_ref->{$k};
#
#        # this $taxonid DOES NOT have t prefix
#        foreach my $taxonid (@$toi_ref) {
#            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 't' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 't' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 't' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$posTaxonOids_ref) {
#            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 't' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 't' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 't' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$negTaxonOids_ref) {
#            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 't' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 't' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 't' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        # now do the bin list
#        # this $taxonid DOES NOT have b prefix
#        foreach my $taxonid (@$intoiBin_ref) {
#            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 'b' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 'b' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 'b' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$posBinOids_ref) {
#            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 'b' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 'b' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 'b' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$negBinOids_ref) {
#            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 'b' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 'b' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 'b' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#    }
#
#}

############################################################################
# do frequency normalization for cog
# param $dbh database handler
# param $toi_ref array ref to 'in' taxon ids
# param $posTaxonOids_ref array ref to 'over' taxon ids
# param $negTaxonOids_ref array ref to 'under' taxon ids
# param $cogsTaxonGcount_ref has ref of:
#      cog => hash (t or b) taxon id  or bin id => count
#       this hash ref will be updated
#       format is of value: "$gene_count ($z)";
# param $intoiBin_ref bin ids
# param $posBinOids_ref bin ids
# param $negBinOids_ref bin ids
#
#
#
############################################################################
#sub zNormalizeCog {
#    my ( $dbh, $toi_ref, $posTaxonOids_ref, $negTaxonOids_ref,
#        $cogsTaxonGcount_ref, $intoiBin_ref, $posBinOids_ref, $negBinOids_ref )
#      = @_;
#    my $scale = getScaleFactorCog();
#
#    my $taxonoids = join( ',', @$toi_ref );
#    my $posids    = join( ',', @$posTaxonOids_ref );
#    my $negids    = join( ',', @$negTaxonOids_ref );
#
#    # bin ids
#    my $binoids   = join( ',', @$intoiBin_ref );
#    my $binposids = join( ',', @$posBinOids_ref );
#    my $binnegids = join( ',', @$negBinOids_ref );
#
#    # taxon id has a 't' prefix
#    my $taxonOid2GeneCount =
#      getTaxonOid2GeneCount( $dbh, $taxonoids, $posids, $negids );
#
#    # bin id has a 'b' prefix
#    my $binOid2GeneCount =
#      getBinOid2GeneCount( $dbh, $binoids, $binposids, $binnegids );
#
#    # hash of array: cog id => [mean, std_dev ]
#    my %dtCogAbundance;
#
#    my $sql = "";
#
#    if ( $taxonoids ne "" ) {
#        $sql = qq{select dca.cog_id, dca.mean, dca.std_dev
#				from dt_cog_abundance dca, gene_cog_groups gcg, gene g
#				where dca.cog_id = gcg.cog
#				and gcg.gene_oid = g.gene_oid
#				and g.taxon in ($taxonoids)
#		};
#    } else {
#
#        # bin in query
#        $sql = qq{
#		select dca.cog_id, dca.mean, dca.std_dev
#		from dt_cog_abundance dca, gene_cog_groups gcg
#		where dca.cog_id = gcg.cog
#		and gcg.gene_oid in(
#		select g.gene_oid
#		from bin b, bin_scaffolds bs, scaffold s, gene g
#		where b.bin_oid = bs.bin_oid
#		and bs.scaffold = s.scaffold_oid
#		and s.scaffold_oid = g.scaffold
#		and b.bin_oid in( $binoids))
#		};
#    }
#
#    if ( defined($posids) && $posids ne "" ) {
#        $sql = $sql . qq{union
#				select dca.cog_id, dca.mean, dca.std_dev
#				from dt_cog_abundance dca, gene_cog_groups gcg, gene g
#				where dca.cog_id = gcg.cog
#				and gcg.gene_oid = g.gene_oid
#				and g.taxon in ($posids)
#				};
#    }
#
#    if ( defined($negids) && $negids ne "" ) {
#        $sql = $sql . qq{union
#				select dca.cog_id, dca.mean, dca.std_dev
#				from dt_cog_abundance dca, gene_cog_groups gcg, gene g
#				where dca.cog_id = gcg.cog
#				and gcg.gene_oid = g.gene_oid
#				and g.taxon in ($negids)
#				};
#    }
#
#    # pos bins
#    if ( $binposids ne "" ) {
#        $sql .= qq{union
#		select dca.cog_id, dca.mean, dca.std_dev
#		from dt_cog_abundance dca, gene_cog_groups gcg
#		where dca.cog_id = gcg.cog
#		and gcg.gene_oid in(
#		select g.gene_oid
#		from bin b, bin_scaffolds bs, scaffold s, gene g
#		where b.bin_oid = bs.bin_oid
#		and bs.scaffold = s.scaffold_oid
#		and s.scaffold_oid = g.scaffold
#		and b.bin_oid in($binposids))
#		};
#    }
#
#    # neg bins
#    if ( $binnegids ne "" ) {
#        $sql .= qq{union
#		select dca.cog_id, dca.mean, dca.std_dev
#		from dt_cog_abundance dca, gene_cog_groups gcg
#		where dca.cog_id = gcg.cog
#		and gcg.gene_oid in(
#		select g.gene_oid
#		from bin b, bin_scaffolds bs, scaffold s, gene g
#		where b.bin_oid = bs.bin_oid
#		and bs.scaffold = s.scaffold_oid
#		and s.scaffold_oid = g.scaffold
#		and b.bin_oid in($binnegids))
#		};
#    }
#
#    my $cur = execSql( $dbh, $sql, 1 );
#    for ( ; ; ) {
#        my ( $cogid, $mean, $stddev ) = $cur->fetchrow();
#        last if !$cogid;
#        if ( !exists( $dtCogAbundance{$cogid} ) ) {
#            my @tmp;
#            push( @tmp, $mean );
#            push( @tmp, $stddev );
#            $dtCogAbundance{$cogid} = \@tmp;
#        }
#    }
#    $cur->finish();
#
#    # $cogsTaxonGcount_ref remember t or b prefix
#    # k is cog id
#    foreach my $k ( keys %$cogsTaxonGcount_ref ) {
#        my $mn = $dtCogAbundance{$k}[0];
#        my $sd = $dtCogAbundance{$k}[1];
#
#        # hash ref to 't' . taxon id to gene count
#        my $href = $cogsTaxonGcount_ref->{$k};
#
#        # this $taxonid DOES NOT have t prefix
#        foreach my $taxonid (@$toi_ref) {
#            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 't' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 't' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 't' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$posTaxonOids_ref) {
#            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 't' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 't' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 't' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$negTaxonOids_ref) {
#            my $total_gene_count = $taxonOid2GeneCount->{ 't' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 't' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 't' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 't' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 't' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        # now do the bin list
#        # this $taxonid DOES NOT have b prefix
#        foreach my $taxonid (@$intoiBin_ref) {
#            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 'b' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 'b' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 'b' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$posBinOids_ref) {
#            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 'b' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 'b' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 'b' . $taxonid } = myformat( $gene_count, $z );
#        }
#
#        foreach my $taxonid (@$negBinOids_ref) {
#            my $total_gene_count = $binOid2GeneCount->{ 'b' . $taxonid };
#            my $gene_count       = 0;
#            my $val              = 0;
#            if ( exists( $href->{ 'b' . $taxonid } ) ) {
#                $val =
#                  ( $href->{ 'b' . $taxonid } / $total_gene_count ) * $scale;
#                $gene_count = $href->{ 'b' . $taxonid };
#            }
#            my $diff = $val - $mn;
#            my $z    = 0;
#            $z = $diff / $sd if $sd > 0;
#            $href->{ 'b' . $taxonid } = myformat( $gene_count, $z );
#        }
#    }
#}

############################################################################
# new filter, where x_in> y_over and x_in < z_under
#
# find rows of matrix that match the over and under value
# param $toi_ref array ref to 'in' taxon ids
# param $posProfileTaxonBinOids_ref array ref to 'over' taxon ids
# param $negProfileTaxonBinOids_ref array ref to 'under' taxon ids
# param $xTaxonGcount_ref - hash of hashes
#       func id => type (t or b)+ hash taxon id  or bin oid => count
# param $overvalue
# param $undervalue
# param $normType normalization type , c, f, z
# param $intoiBin_ref - 'in' bin id
# param $posProfileBinOids_ref - list of over bin ids
# param $negProfileBinOids_ref - list of under bin ids
#
# return hash ref of filter list of $xTaxonGcount_ref
# 		 NOTE it has the type prefixed on the id
#        func id => type (t or b)+ hash taxon id  or bin oid => count
############################################################################
sub getOverUnderAbundanceList {
    my (
        $toi_ref,               $posProfileTaxonOids_ref, $negProfileTaxonOids_ref, $xTaxonGcount_ref,
        $overvalue,             $undervalue,              $normType,                $intoiBin_ref,
        $posProfileBinOids_ref, $negProfileBinOids_ref
      )
      = @_;

    # this is the filter results
    # do a copy first
    my %xTaxonGcount = %$xTaxonGcount_ref;

    # find only funcs that match over criteria
    foreach my $id ( keys %xTaxonGcount ) {
        my $x_in = "";

        # the user can only select one in element
        # thus there is only 1 element in the 'in' column
        if ( $#$intoiBin_ref > -1 ) {

            # I should use count $#$intoiBin_ref not defined
            $x_in = mystrip( $xTaxonGcount{$id}->{ 'b' . $intoiBin_ref->[0] } );
        } else {

            $x_in = mystrip( $xTaxonGcount{$id}->{ 't' . $toi_ref->[0] } );
        }

        # the taxonid to gene count hash ref
        my $h_taxon_ref = $xTaxonGcount_ref->{$id};
        foreach my $taxonid (@$posProfileTaxonOids_ref) {

            # remember taxon ids have a t in front
            my $overcount =
              ( exists $h_taxon_ref->{ 't' . $taxonid } )
              ? $h_taxon_ref->{ 't' . $taxonid }
              : 0;
            $overcount = mystrip($overcount);

            # y < x_in
            if ( $normType eq 'z' ) {

                # z -score
                if ( ( $overcount * $overvalue ) < $x_in ) {
                    next;
                } else {
                    delete $xTaxonGcount{$id};
                }
            } elsif ( $normType eq 'f' ) {

                # freq how to calc
                if ( ( $overcount * $overvalue ) < $x_in ) {
                    next;
                } else {
                    delete $xTaxonGcount{$id};
                }
            } else {

                # remove the = sign = is for testing only!!!
                if ( ( $overcount * $overvalue ) < $x_in ) {
                    next;
                } else {
                    delete $xTaxonGcount{$id};
                }
            }
        }

        # now do the bins
        foreach my $binid (@$posProfileBinOids_ref) {

            # remember bin ids have a b in front
            my $overcount =
              ( exists $h_taxon_ref->{ 'b' . $binid } )
              ? $h_taxon_ref->{ 'b' . $binid }
              : 0;
            $overcount = mystrip($overcount);

            # y < x_in
            if ( $normType eq 'z' ) {

                # z -score
                if ( ( $overcount * $overvalue ) < $x_in ) {
                    next;
                } else {
                    delete $xTaxonGcount{$id};
                }
            } elsif ( $normType eq 'f' ) {

                # freq how to calc
                if ( ( $overcount * $overvalue ) < $x_in ) {
                    next;
                } else {
                    delete $xTaxonGcount{$id};
                }
            } else {

                # remove the = sign = is for etsting only!!!
                if ( ( $overcount * $overvalue ) < $x_in ) {
                    next;
                } else {
                    delete $xTaxonGcount{$id};
                }
            }
        }

    }

    # find only funcs that match under criteria
    foreach my $xid ( keys %xTaxonGcount ) {

        #my $x_in = mystrip( $xTaxonGcount{$xid}->{ $toi_ref->[0] } );
        my $x_in = "";

        # the user can only select one in element
        # thus there is only 1 element in the 'in' column
        if ( $#$intoiBin_ref > -1 ) {

            # I should use count $#$intoiBin_ref not defined
            $x_in = mystrip( $xTaxonGcount{$xid}->{ 'b' . $intoiBin_ref->[0] } );
        } else {
            $x_in = mystrip( $xTaxonGcount{$xid}->{ 't' . $toi_ref->[0] } );
        }

        # the taxonid to gene count hash ref
        my $h_taxon_ref = $xTaxonGcount{$xid};
        foreach my $taxonid (@$negProfileTaxonOids_ref) {

            # remember taxon ids have a t in front
            my $undercount =
              ( exists $h_taxon_ref->{ 't' . $taxonid } )
              ? $h_taxon_ref->{ 't' . $taxonid }
              : 0;

            $undercount = mystrip($undercount);

            # z > x_in
            if ( $normType eq 'z' ) {

                # z-score
                if ( $undercount > ( $x_in * $undervalue ) ) {
                    next;
                } else {
                    delete $xTaxonGcount{$xid};
                }
            } elsif ( $normType eq 'f' ) {

                # freq how to calc
                if ( $undercount > ( $x_in * $undervalue ) ) {
                    next;
                } else {
                    delete $xTaxonGcount{$xid};
                }
            } else {
                if ( $undercount > ( $x_in * $undervalue ) ) {

                    # include this record, it matches over criteria
                    # $cogsTaxonGcount{$cogid} = $h_taxon_ref;
                    # leave it as is
                    next;
                } else {
                    delete $xTaxonGcount{$xid};
                }
            }
        }

        # now the bins
        foreach my $binid (@$negProfileBinOids_ref) {

            # remember bin ids have a b in front
            my $undercount =
              ( exists $h_taxon_ref->{ 'b' . $binid } )
              ? $h_taxon_ref->{ 'b' . $binid }
              : 0;

            $undercount = mystrip($undercount);

            # z > x_in
            if ( $normType eq 'z' ) {

                # z-score
                if ( $undercount > ( $x_in * $undervalue ) ) {
                    next;
                } else {
                    delete $xTaxonGcount{$xid};
                }
            } elsif ( $normType eq 'f' ) {

                # freq how to calc
                if ( $undercount > ( $x_in * $undervalue ) ) {
                    next;
                } else {
                    delete $xTaxonGcount{$xid};
                }
            } else {

                if ( $undercount > ( $x_in * $undervalue ) ) {

                    # include this record, it matches over criteria
                    # $cogsTaxonGcount{$cogid} = $h_taxon_ref;
                    # leave it as is
                    next;
                } else {
                    delete $xTaxonGcount{$xid};
                }
            }
        }
    }
    return \%xTaxonGcount;
}

############################################################################
# prints gene list page from a func gene count
#
# param $id - func id
# param $taxonid - taxon oid it can have b or t as a prefix
############################################################################
sub printAbundanceFuncGeneListPage {

    # for bin prefix t or b for taxonid
    my $func_type = param("cluster");
    my $id        = param("funcid");
    my $taxonid   = param("taxonid");
    my $data_type = param("data_type");
    my $est_copy  = param("est");

    printMainForm();
    print "<h1>Abundance Profile Search Gene List</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    # make page
    my $func_header = AbundanceToolkit::getFuncHeader($func_type);
    my $func_name   = AbundanceToolkit::getFuncName( $dbh, $func_type, $id );

    print "<p>\n";
    print "$func_header ID: $id\n";
    print "<br>$func_header Name: $func_name\n";
    print "</p>\n";

    my $taxon_name;

    # is it a bin id?
    my $isbin = 0;
    if ( isBinId($taxonid) == 1 ) {
        $isbin      = 1;
        $taxonid    = mystripTorB($taxonid);
        $taxon_name = QueryUtil::getBinName( $dbh, $taxonid );
    } else {
        $taxonid = mystripTorB($taxonid);
        $taxon_name = QueryUtil::fetchTaxonName( $dbh, $taxonid );
    }

    my $isTaxonInFile;
    if ( $in_file && isInt($taxonid) ) {
        $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxonid );
        if ($isTaxonInFile) {
            $taxon_name .= " (MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $taxon_name .= " ($data_type)";
            }
        }
    }

    print "<p>\n";
    if ($isbin) {
        print "Bin ID: <a href='main.cgi?section=Metagenome" . "&page=binDetail&bin_oid=$taxonid'>" . "$taxonid</a>\n";
        print "<br>Bin Name: $taxon_name\n";
    } else {
        print "Taxon ID: <a href='main.cgi?section=TaxonDetail"
          . "&page=taxonDetail&taxon_oid=$taxonid'>"
          . "$taxonid</a>\n";
        print "<br>Taxon Name: $taxon_name\n";
    }
    print "</p>\n";

    if ($isTaxonInFile) {

        # MER-FS
        AbundanceToolkit::printMetaGeneList( $id, $taxonid, $data_type, $est_copy );
    } else {

        # DB
        my $sql = "";
        if ($isbin) {
            $sql = getFuncIdBinGeneListSql($func_type);
        } else {
            $sql = getFuncIdDbTaxonGeneListSql($func_type);
        }
        my @binds = ( $taxonid, $id );
        AbundanceToolkit::printDbGeneList( $dbh, $sql, \@binds, $est_copy );
    }

    #$dbh->disconnect();
    print end_form();
}

sub getFuncIdBinGeneListSql {
    my ($func_type) = @_;

    my $sql;

    if ( $func_type eq "cog" ) {
        $sql = qq{
            select distinct gcg.gene_oid
            from bin b, bin_scaffolds bs, gene_cog_groups gcg
            where b.bin_oid = ?
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gcg.scaffold
            and gcg.cog = ?
            order by gcg.gene_oid
        };

    } elsif ( $func_type eq "enzyme" ) {
        $sql = qq{
            select distinct gf.gene_oid
            from bin b, bin_scaffolds bs, gene_ko_enzymes gf
            where b.bin_oid = ?
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gf.scaffold
            and gf.enzymes = ?
            order by gf.gene_oid
        };

    } elsif ( $func_type eq "ko" ) {
        $sql = qq{
            select distinct gk.gene_oid
            from bin b, bin_scaffolds bs, gene_ko_terms gk
            where b.bin_oid = ?
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gk.scaffold
            and gk.ko_terms = ?
            order by gk.gene_oid
        };

    } elsif ( $func_type eq "pfam" ) {
        $sql = qq{
            select distinct gpf.gene_oid
            from bin b, bin_scaffolds bs, gene_pfam_families gpf
            where b.bin_oid = ?
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gpf.scaffold
            and gpf.pfam_family = ?
            order by gpf.gene_oid
        };

    } elsif ( $func_type eq "tigrfam" ) {
        $sql = qq{
            select distinct gf.gene_oid
            from bin b, bin_scaffolds bs, gene_tigrfams gf
            where b.bin_oid = ?
            and b.bin_oid = bs.bin_oid
            and bs.scaffold = gf.scaffold
            and gf.ext_accession = ?
            order by gf.gene_oid
        };
    }

    #print "getFuncIdBinGeneListSql() sql: $sql<br/>\n";

    return ($sql);

}

sub getFuncIdDbTaxonGeneListSql {
    my ($func_type) = @_;

    my $sql;

    if ( $func_type eq "cog" ) {
        $sql = qq{
            select distinct gcg.gene_oid
            from gene_cog_groups gcg
            where gcg.taxon = ?
            and gcg.cog = ?
            order by gcg.gene_oid
        };

    } elsif ( $func_type eq "enzyme" ) {
        $sql = qq{
            select distinct gf.gene_oid
            from gene_ko_enzymes gf
            where gf.taxon = ?
            and gf.enzymes = ?
            order by gf.gene_oid
        };

    } elsif ( $func_type eq "ko" ) {
        $sql = qq{
            select distinct gk.gene_oid
            from gene_ko_terms gk
            where gk.taxon = ?
            and gk.ko_terms = ?
            order by gk.gene_oid
        };

    } elsif ( $func_type eq "pfam" ) {
        $sql = qq{ 
            select distinct gpf.gene_oid
            from gene_pfam_families gpf
            where gpf.taxon  = ?
            and gpf.pfam_family = ?
            order by gpf.gene_oid 
        };

    } elsif ( $func_type eq "tigrfam" ) {
        $sql = qq{ 
            select distinct gf.gene_oid
            from gene_tigrfams gf
            where gf.taxon  = ?
            and gf.ext_accession = ?
            order by gf.gene_oid 
        };
    }

    #print "getFuncIdDbTaxonGeneListSql() sql: $sql<br/>\n";

    return ($sql);
}

############################################################################
# sortDataFile
# param $cacheFile - original cached data results
# param $sort - sort column number
# return name of new cache data file
#
# ******** Deprecated in YUI tables -BSJ 02/07/12 ***************
############################################################################
sub sortDataFile {
    my ( $cacheFile, $sort ) = @_;

    # as is - no sort
    if ( !defined($sort) || $sort < 0 || $sort eq "" ) {
        return $cacheFile;
    }
    my $path = "$cgi_tmp_dir/$cacheFile";

    $path = checkTmpPath($path);
    if ( !( -e $path ) ) {
        webError("Cannot find data file to sort.");
        return;
    }

    # read orig cache data file
    my $rfh = newReadFileHandle( $path, "sortDataFile" );
    my $header = $rfh->getline();
    chomp $header;

    # array of arrays
    my @origdata;
    while ( my $line = $rfh->getline() ) {
        chomp $line;
        my @tmp = split( /\t/, $line );
        push( @origdata, \@tmp );
    }
    close $rfh;

    # sort data
    #
    # numerical columns start at column 2
    #
    my @sortdata;
    if ( $sort > 1 ) {

        # numeric high to low
        # mysort
        @sortdata =
          sort { mystrip( $b->[$sort] ) <=> mystrip( $a->[$sort] ) } @origdata;
    } elsif ( $sort == 0 ) {

        @sortdata =
          sort { mystripstar( $a->[$sort] ) cmp mystripstar( $b->[$sort] ) } @origdata;
    } else {

        # alphanumeric, ignore case
        @sortdata = sort { lc( $a->[$sort] ) cmp lc( $b->[$sort] ) } @origdata;
    }

    # re-save cached file
    my $ofh = newWriteFileHandle( $path, "sortDataFile" );
    print $ofh "$header\n";
    foreach my $aref (@sortdata) {
        my $line = join( "\t", @$aref );
        print $ofh "$line\n";
    }

    close $ofh;
    return "$cacheFile";
}

############################################################################
# Given a data value either a number or a number (score)
# Return the score if it exist, otherwise gene count
#
# Ex input 2 or 5 (0.03)
# return 2 or  0.03 resp.
#
# param $val value
# return parsed value
#
# see zNormalizeCog, zNormalizePfam, freqNormalize myformat
############################################################################
sub mystrip {
    my ($val) = @_;
    my @tmp = split( / /, $val );
    my $res = ( $#tmp == 0 ) ? $tmp[0] : $tmp[1];
    $res =~ s/\(|\)//g;
    return $res;
}

############################################################################
# mystripstar - remove the * on the cog id or pfam id
############################################################################
sub mystripstar {
    my ($val) = @_;
    $val =~ s/\*//;
    return $val;
}

############################################################################
# isBinId - is it a bin id?
# bin id havea b prefix while taxon have a t
############################################################################
sub isBinId {
    my ($val) = @_;
    if ( $val =~ /^b/ ) {
        return 1;
    } else {
        return 0;
    }
}

############################################################################
# mystripTorB - remove the t or b prefix and return the id
############################################################################
sub mystripTorB {
    my ($val) = @_;
    $val =~ s/t|b//;
    return $val;
}

############################################################################
# format to values to be "$gcount ($score)"
#
# also sprintf( "%.3f", $score );
# param $gcount gene count
# param $score either z-score or freq
# return formated value "$gcount ($score)"
#
# see zNormalizeCog, zNormalizePfam, freqNormalize
############################################################################
sub myformat {
    my ( $gcount, $score ) = @_;
    $score = sprintf( "%.3f", $score );

    #webLog("$score\n");

    return "$gcount ($score)";
}

############################################################################
# used when writing out to cache file
# format the results output
# param $value it can be '2' or '2 (score)'
# return formatted output of $value
############################################################################
sub myformatByshowresult {
    my ( $value, $norm, $counttype ) = @_;

    my @tmp = split( / /, $value );
    if ( $#tmp > 0 ) {
        if ( $norm && !$counttype ) {
            $tmp[1] =~ s/\(|\)//g;
            return $tmp[1];
        } elsif ( $counttype && !$norm ) {
            return $tmp[0];
        } else {
            return $value;
        }
    } else {
        return $value;
    }
}

############################################################################
#
#   Print one page till reach end of file, or max no. of
#   rows.  If max no. of rows reached, show "more" button with file
#   name and next start position (in characters).
#
# param $cacheFile - cached data results
# param $startPos - file index postion   <--- deprecated with YUI tables
# param $totalRows - number of data rows <--- deprecated with YUI tables
# param $cluster - either 'cog' or 'pfam'
# param $sort - col to sort on -1 or null as is,
#       0 - col 0, 1 - col 1 etc         <--- deprecated with YUI tables
#
# CACHE file format
# 1st row is the column header tab delimited
# format: id name In<br>txname:txid Over<br>txname:txid_i Under<br>txname:txid_i
#
# over rows are data
# id or id* where * means highlight row
# for result value either display:
#	1. value
#	2. gene_count (norm_value)
#
############################################################################
sub printAbundanceProfileResultsPage {
    my ($cacheFile) = @_;

    my $cluster    = param("cluster");
    my $showresult = param("showresult");
    my $data_type  = param("data_type");

    my $path = "$cgi_tmp_dir/$cacheFile";
    $path = checkTmpPath($path);
    if ( !( -e $path ) ) {
        webError("Session has expired. Please start over.");
        return;
    }

    my $rfh = newReadFileHandle( $path, "printResultsPage" );

    # first line is the column header
    my $headerline = $rfh->getline();
    my @header = split( /\t/, $headerline );
    my $est_copy;

    # list of taxon ids, order should be 'in', 'over' and 'under' ids
    my @taxonidslist;

    # where the over and under column start
    my $overcolumn  = -1;
    my $undercolumn = -1;
    my $col_count   = 0;

    # now print table column header
    # column header when clicked sorts table
    # checkbox column header

    my $it = new InnerTable( 1, "AbundanceResults$$", "AbundanceResults", 0 );
    my $sd = $it->getSdDelim();                                                  # sort delimiter

    $it->addColSpec( "Selection", "", "center" );

    foreach my $colname (@header) {
        chomp $colname;
        if ( $colname =~ /^Over/ ) {
            $colname =~ s/Over<br>//;
            my @tid_tname = split( /:/, $colname );

            $it->addColSpec( $tid_tname[1], "desc", "", "#FFD5D5", "More Abundant function", "wrap" );

            push( @taxonidslist, $tid_tname[0] );
            if ( $overcolumn == -1 ) {
                $overcolumn = $col_count;
            }
        } elsif ( $colname =~ /^Under/ ) {
            $colname =~ s/Under<br>//;
            my @tid_tname = split( /:/, $colname );
            $it->addColSpec( $tid_tname[1], "desc", "", "#D5FFD5", "Less Abundant function", "wrap" );

            push( @taxonidslist, $tid_tname[0] );
            if ( $undercolumn == -1 ) {
                $undercolumn = $col_count;
            }

        } elsif ( $colname =~ /^In/ ) {
            $colname =~ s/In<br>//;
            my @tid_tname = split( /:/, $colname );
            $it->addColSpec( $tid_tname[1], "desc", "", "", "In function", "wrap" );

            push( @taxonidslist, $tid_tname[0] );
        } else {
            $it->addColSpec( $colname, "asc" );
        }
        $col_count++;
    }

    ## --es 01/27/2007 Changed terms.
    print "<p>";

    print qq{
	<span style='background-color:#FFD5D5;border:1px outset white;
              padding-right:5em;margin-right:1em'>&nbsp;</span> Less abundant
        <br style='margin:3px'/>
	<span style='background-color:#D5FFD5;border:1px outset white;
              padding-right:5em;margin-right:1em'>&nbsp;</span> More abundant
        <br/><br/>
    } if ( $undercolumn > -1 || $overcolumn > -1 );

    # Setup choices text to display as info
    my $legendStr = "Normalization Method: ";
    if ( param("doNormalization") eq "f" ) {
        $legendStr .= "<b>Frequency</b>";
        if ( paramMatch("counttype") ) {
            $legendStr .= "; Count: ";
            if ( $showresult eq "gcnt" ) {
                $legendStr .= "<b>Gene count</b>";
            } else {
                $legendStr .= "<b>Estimated gene copies</b>";
                $est_copy = 1;
            }
        }
        if ( paramMatch("norm") ) {
            my $addStr = $legendStr ne "" ? " (" : "";
            $addStr    .= "Normalized value";
            $addStr    .= $legendStr ne "" ? ")" : "";
            $legendStr .= $addStr;
        }
    } else {
        $legendStr .= "<b>None</b>";
    }
    print $legendStr;
    print "</p>";

    printMainForm();

    # data records
    my $count     = 0;
    my $matchText = param("clusterMatchText");
    $matchText = strTrim($matchText) if $matchText;

    while ( my $s = $rfh->getline() ) {

        #print "printAbundanceProfileResultsPage() s: $s<br/>\n";
        my @rowarray = split( /\t/, $s );
        $count++;
        my $row;

        # column count
        my $i = 0;

        # current cog id or pfam id
        my $xoid    = 0;
        my $taxonid = 0;

        # boolean color it red
        my $color = 0;
        foreach my $data (@rowarray) {
            if ( $cluster eq 'cog' && $data =~ /^COG/ ) {
                $row .= $sd . "<input type='checkbox' name='cog_id' value='$data' />\t";

                # cog id column
                if ( $data =~ /\*/ ) {
                    $data = mystripstar($data);

                    # checkbox
                    my $url = "$cog_base_url$data";
                    $row .= $data . $sd . "<a style='color:#FF0000' href='$url'>$data</a>\t";
                    $color = 1;
                } else {
                    my $url = "$cog_base_url$data";
                    $row .= $data . $sd . alink( $url, $data ) . "\t";
                }
                $xoid = $data;
            } elsif ( $cluster eq 'enzyme' && $data =~ /^EC/ ) {
                $row .= $sd . "<input type='checkbox' name='ec_number' value='$data' />\t";

                # enzyme id column
                if ( $data =~ /\*/ ) {
                    $data = mystripstar($data);
                    my $url = "$enzyme_base_url$data";
                    $row .= $data . $sd . "<a style='color:#FF0000' href='$url'>$data</a>\t";
                    $color = 1;
                } else {
                    my $url = "$enzyme_base_url$data";
                    $row .= $data . $sd . alink( $url, $data ) . "\t";
                }
                $xoid = $data;
            } elsif ( $cluster eq 'ko' && $data =~ /^KO/ ) {
                $row .= $sd . "<input type='checkbox' name='ko_id' value='$data' />\t";

                # enzyme id column
                if ( $data =~ /\*/ ) {
                    $data = mystripstar($data);
                    my $koid_short = $data;
                    $koid_short =~ s/KO://;
                    my $url = $kegg_orthology_url . $koid_short;
                    $row .= $data . $sd . "<a style='color:#FF0000' href='$url'>$data</a>\t";
                    $color = 1;
                } else {
                    my $koid_short = $data;
                    $koid_short =~ s/KO://;
                    my $url = $kegg_orthology_url . $koid_short;
                    $row .= $data . $sd . alink( $url, $data ) . "\t";
                }
                $xoid = $data;
            } elsif ( $cluster eq 'pfam' && $data =~ /^pfam/ ) {
                $row .= $sd . "<input type='checkbox' name='pfam_id' value='$data' />\t";

                # pfam id column
                if ( $data =~ /\*/ ) {
                    $data = mystripstar($data);
                    my $url = "$pfam_base_url$data";
                    $row .= $data . $sd . "<a style='color:#FF0000' href='$url'>$data</a>\t";
                    $color = 1;
                } else {
                    my $url = "$pfam_base_url$data";
                    $row .= $data . $sd . alink( $url, $data ) . "\t";
                }
                $xoid = $data;
            } elsif ( $cluster eq 'tigrfam' && $data =~ /^TIGR/ ) {
                $row .= $sd . "<input type='checkbox' name='tigrfam_id' value='$data' />\t";

                # pfam id column
                if ( $data =~ /\*/ ) {
                    $data = mystripstar($data);
                    my $url = "$tigrfam_base_url$data";
                    $row .= $data . $sd . "<a style='color:#FF0000' href='$url'>$data</a>\t";
                    $color = 1;
                } else {
                    my $url = "$tigrfam_base_url$data";
                    $row .= $data . $sd . alink( $url, $data ) . "\t";
                }
                $xoid = $data;
            } elsif (
                $i > 1
                && (   $cluster eq 'cog'
                    || $cluster eq 'enzyme'
                    || $cluster eq 'ko'
                    || $cluster eq 'pfam'
                    || $cluster eq 'tigrfam' )
              )
            {

                # NOTE the 1 is func name column
                # gene count data for cog for a given taxon

                $taxonid = $taxonidslist[ $i - 2 ];

                my $url =
                    "main.cgi?section=$section&page=abundanceGeneListPage"
                  . "&funcid=$xoid&taxonid=$taxonid&cluster=$cluster&data_type=$data_type";

                my $geneCount = strTrim($data);
                $geneCount =~ s/\s*\(.*\)\s*//g;    # Remove normalized value in ()

                if ($est_copy) {
                    $url .= "&est=$geneCount";
                }

                if ($geneCount) {
                    $row .= $data . $sd . alink( $url, $data ) . "\t";
                } else {
                    $row .= "0" . $sd . "0\t";
                }
            } else {

                # name data
                if ( $color == 1 ) {

                    # highlight name in red and show match text in bold green
                    my $matchFormat = $data;
                    $matchFormat =~ s/$matchText/<b>$&<\/b>/gi
                      if $matchText;
                    $row .= $data . $sd . "<span style='color:#FF0000'>$matchFormat</span>\t";
                } else {
                    $row .= $data . $sd . $data . "\t";
                }
            }
            $i++;
        }
        $it->addRow($row);
    }
    close $rfh;

    WebUtil::printFuncCartFooter();
    $it->printOuterTable(1);

    # add to cart
    if ( $count > 10 ) {
        WebUtil::printFuncCartFooter();
    }

    printStatusLine( "$count rows loaded.", 2 );
    print end_form();
}

############################################################################
# loadSetTaxonOids - Load taxon_oid's belonging to a set.
############################################################################
sub loadSetTaxonOids {
    my ($setName) = @_;

    my @taxon_oids;
    my $rfh = newReadFileHandle( $phyloProfiler_sets_file, "loadSetTaxonOids" );
    my $inSet = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/^\s+//;
        $s =~ s/\s+$//;
        $s =~ s/\s+/ /g;
        next if $s =~ /^#/;
        if ( $s =~ /^\.set / ) {
            my ( $set, $id, undef ) = split( / /, $s );
            if ( $id eq $setName ) {
                while ( $s = $rfh->getline() ) {
                    chomp $s;
                    next if $s =~ /^#/;
                    $s =~ s/^\s+//;
                    $s =~ s/\s+$//;
                    $s =~ s/\s+/ /g;
                    last if $s =~ /^\.setEnd/;
                    my ( $taxon_oid, undef ) = split( / /, $s );
                    next if !isInt($taxon_oid);
                    push( @taxon_oids, $taxon_oid );
                }
            }
        }
    }
    close $rfh;
    return @taxon_oids;
}

############################################################################
# Normalization Note
############################################################################
sub printAbundanceNormalizationNote {
    print qq{
	<h1>Normalization</h1>
	<p>
	Single organism genomes can
	be compared using raw gene counts.<br/>
	Communities should be normalized taking into account genome size.
	<br/>
	</p>
	<!--
	<p>
	<b>Z-score</b> normalization, a z-score is computed for all values
	for all clusters in a given genome.
	<br/>
	&nbsp;&nbsp;
	<i>z<sub>x</sub> = ( x - mean<sub>x</sub> ) / standard.deviation
	<sub>x</sub></i>
	<br/>
	</p>
	-->
	<p>
	<b>Frequency</b> normalization is computed for all values
	for all clusters in a given genome.
	<br>
	&nbsp;&nbsp;
	<i>
	freq = (gene_count / total_gene_count) * scale_factor
	</i>
	</p>
	<p>
	Where  scale factor is 1000000.
	</p> 
    };
}

############################################################################
# Normalization Hint
############################################################################
sub normalizationHint {
    return qq{
          <u>Normalization Method:</u><br/>\n
          Single organism genomes can be compared 
          using raw gene counts.<br/>\n
          Communities should be normalized by taking 
          the size of the genome into account.<br/>\n
          <b>Frequency</b> normalization is computed for all values 
          for all clusters in a given genome.<br>\n
          &nbsp;&nbsp;&nbsp;&nbsp;\n
          <font color='blue'>freq = 
          (gene_count / total_gene_count) * scale_factor</font><br/>\n
          Where the scale factor is 1000000.
    };
}

############################################################################
# printJavaScript - Print module level JavaScript
############################################################################
sub printJavaScript {
    print qq{
    <script language='JavaScript' type='text/javascript'>

    /*
     * disable or enable the show results buttons based on
     * the selected normalization
     */
    function setDisableShowResult(enable) {
        document.mainForm.counttype.disabled = enable;
        document.mainForm.showresult[0].disabled = enable;
        document.mainForm.showresult[1].disabled = enable;
        document.mainForm.norm.disabled = enable;
    }

    function countStatus(obj) {
        var state = obj.checked;

        if (obj.name == "counttype") {
	    if (!state && !document.mainForm.norm.checked) {
	        document.mainForm.norm.checked = true;
	    }
        }
        if (obj.name == "norm") {
	    if (!state && !document.mainForm.counttype.checked) {
	        document.mainForm.counttype.checked = true;
	    }
        }

        var counttypeState = document.mainForm.counttype.checked;
        document.mainForm.showresult[0].disabled = !counttypeState;
        document.mainForm.showresult[1].disabled = !counttypeState;
    }

    /*
     * when the users select a norm type the onclick will call this method
     * to enable or disable some field in the form.
     * Note: in perl cgi disabled components return undefined values
     */
    function normTypeAction(enable) {
        // sets show results value
        setDisableShowResult(enable);

        // sets cut off boxes
        if (document.mainForm.doNormalization[0].checked ||
            document.mainForm.doNormalization[1].checked) {
            document.mainForm.overabundant.disabled = false;
            document.mainForm.underabundant.disabled = false;
        } else {
            document.mainForm.overabundant.value = 1;
            document.mainForm.underabundant.value = 1;
            document.mainForm.overabundant.disabled = true;
            document.mainForm.underabundant.disabled = true;
        }
    }
    </script>
    };
}

1;
