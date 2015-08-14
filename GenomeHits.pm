###########################################################################
# New Phylogenetic Distribution of Genes from taxon detail page
#
# $Id: GenomeHits.pm 33981 2015-08-13 01:12:00Z aireland $
###########################################################################
package GenomeHits;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use OracleUtil;
use InnerTable;
use MetagGraphScatterPanel;
use POSIX qw(ceil floor);
use GenomeListFilter;
use TaxonTarDir;
use MerFsUtil;
use MetaUtil;
use QueryUtil;
use GenomeListJSON;

$| = 1;

my $env                  = getEnv();
my $cgi_dir              = $env->{cgi_dir};
my $cgi_url              = $env->{cgi_url};
my $main_cgi             = $env->{main_cgi};
my $inner_cgi            = $env->{inner_cgi};
my $tmp_url              = $env->{tmp_url};
my $verbose              = $env->{verbose};
my $include_metagenomes  = $env->{include_metagenomes};
my $web_data_dir         = $env->{web_data_dir};
my $img_internal         = $env->{img_internal};
my $user_restricted_site = $env->{user_restricted_site};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $base_url             = $env->{base_url};
my $base_dir             = $env->{base_dir};
my $YUI                  = $env->{yui_dir_28};
my $section              = "GenomeHits";
my $section_cgi          = "$main_cgi?section=$section";
my $tmp_dir              = $env->{tmp_dir};
my $img_ken              = $env->{img_ken};
my $in_file              = $env->{in_file};

my $gtt_single_cells = "gtt_single_cells";

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

# make sure its last in sorting
my $zzzUnknown = "zzzUnknown";
my $unknown    = "Unknown";
my $mynull     = "mynull";
my $nvl        = WebUtil::getNvl();

# Max number of metagenomes that can be selected
# in the metagenome list for Genome vs Metagenome
my $MAX_METAGENOMES = 5000;

sub dispatch {
    my ($numTaxon) = @_;        # number of saved genomes
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 mins (from main.pl)
    if ( $page eq "plot1" ) {
        printPlot1();
    } elsif ( $page eq "plot2" ) {
        print "todo 2";
    } elsif ( $page eq "genelist" ) {
        printGeneList();
    } elsif ( $page eq "summary" ) {

        # not use right now - ken
        # show hit summary on phylum and ir_class
        printSummary();
    } elsif ( $page eq "hits" ) {
        my $outputType = param("outputtype");
        if ( $outputType eq 'phylum' ) {
            printIsolateGenomeDistribution();
        } elsif ( $outputType eq 'metagenome' ) {
            printHits();
        } elsif ( $outputType eq 'radialtree' ) {

            #printPhyloTree(); # TODO not implemented yet - yjlin 07/11/2013
        } else {
            printForm3($numTaxon);
        }
    } else {

        # form page to select a single isolate genome
        printForm3($numTaxon);
    }
}

sub printForm3 {
    my ($numTaxon) = @_;    # number of saved genomes

    printStatusLine( "Loading ...", 1 );

    printMainForm();

    print qq{
        <h1>Single Genome vs. Metagenomes</h1>
        <p>
        View the phylogenetic distribution of genes for an
        isolate genome run against a <b>limited</b> set of metagenomes<sup>1</sup>.
        <br/>
        Please select <b>ONE</b> isolate genome.
        </p>
    };

    print "<p>\n";
    print qq{
        <script language="javascript" type="text/javascript">
        function controlHistAndPerc(mode) {
            if ( mode==1 ) { // 1 for enable
              document.getElementById('show_hist').checked = 1;
              document.getElementById('show_hist').disabled = 0;
              document.getElementById('show_perc').checked = 1;
              document.getElementById('show_perc').disabled = 0;
            } else { // 0 and all else for disable
              document.getElementById('show_hist').checked = 0;
              document.getElementById('show_hist').disabled = 1;
              document.getElementById('show_perc').checked = 0;
              document.getElementById('show_perc').disabled = 1;
            }
        }
        </script>

        <b>Output Type </b><br/>
        <input type="radio" checked="checked" value="phylum" name="outputtype" onclick="controlHistAndPerc(0);">
        Group hits by phylum<br/>
        <input type="radio" value="metagenome" name="outputtype" onclick="controlHistAndPerc(1);">
        Group hits by metagenome<br/>
    };

    print qq{
        &nbsp; &nbsp; &nbsp; &nbsp; <input type='checkbox' id='show_hist' name='show_hist' disabled/>
        &nbsp; Show histogram column
        <br/>
        &nbsp; &nbsp; &nbsp; &nbsp; <input type='checkbox' id='show_perc' name='show_perc' disabled/>
        &nbsp; Show percentage column
    };
    print "</p>\n";

    print "<p>\n";
    print qq{
        <b>Percent Identity</b><br/>
        <input type="radio" checked="checked" value="suc" name="percentage_count"> Successive (30% to 59%, 60% to 89%, 90%+)<br/>
        <input type="radio" value="cum" name="percentage_count"> Cumulative (30%+, 60%+, 90%+)<br/>
    };
    print "</p>\n";

    my $dbh = dbLogin();

    #HtmlUtil::printMetaDataTypeChoice();

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new( filename => "$base_dir/genomeJsonTwoDiv.html" );
    $template->param( isolate              => 1 );
    $template->param( include_metagenomes  => 1 );
    $template->param( gfr                  => 1 ) if ( $hideGFragment eq 'No' );
    $template->param( pla                  => 1 ) if ( $hidePlasmids eq 'No' );
    $template->param( vir                  => 1 ) if ( $hideViruses eq 'No' );
    $template->param( all                  => 1 );
    $template->param( cart                 => 1 );
    $template->param( xml_cgi              => $xml_cgi );
    $template->param( prefix               => '' );
    $template->param( selectedGenome1Title => 'Isolate Genome (max 1 selection)' );
    $template->param( selectedGenome2Title => "Metagenome (max $MAX_METAGENOMES)" );
    $template->param( from                 => '' );
    $template->param( maxSelected2         => $MAX_METAGENOMES );
    $template->param( domainType1          => 'isolate' );
    $template->param( domainType2          => 'metagenome' );
    $template->param( selectedAssembled2   => 1 );

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    GenomeListJSON::printHiddenInputType( $section, 'hits' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
        ( '', 'Submit', 'Submit', '', $section, 'hits' );
    print $button;

    print end_form();

    GenomeListJSON::showGenomeCart($numTaxon);

    printStatusLine( "Loaded.", 2 );

    print qq{
        <p>
        1 - Large metagenomes cannot be processed at this time due to computation limits. We are currently
        working on a solution to handle large metagenomes.
        </p>
    };
}

sub printForm {
    printStatusLine( "Loading ...", 1 );
    printFormJS();
    printMainForm();

    print qq{
        <h1>Single Genome vs. Metagenomes</h1>
        <p>
        View the phylogenetic distribution of genes for an
        isolate genome run against a <b>limited</b> set of metagenomes<sup>1</sup>.
        <br/>
        Please select <b>ONE</b> isolate genome.
        </p>
    };

    print "<p>\n";
    print qq{
        <script language="javascript" type="text/javascript">
        function controlHistAndPerc(mode) {
            if ( mode==1 ) { // 1 for enable
              document.getElementById('show_hist').checked = 1;
              document.getElementById('show_hist').disabled = 0;
              document.getElementById('show_perc').checked = 1;
              document.getElementById('show_perc').disabled = 0;
            } else { // 0 and all else for disable
              document.getElementById('show_hist').checked = 0;
              document.getElementById('show_hist').disabled = 1;
              document.getElementById('show_perc').checked = 0;
              document.getElementById('show_perc').disabled = 1;
            }
        }
        </script>

        <b>Output Type </b><br/>
        <input type="radio" checked="checked" value="phylum" name="outputtype" onclick="controlHistAndPerc(0);">
        Group hits by phylum<br/>
        <input type="radio" value="metagenome" name="outputtype" onclick="controlHistAndPerc(1);">
        Group hits by metagenome<br/>
    };

    #<input type="radio" value="radialtree" name="outputtype" onclick="controlHistAndPerc(0);">
    #Draw radial tree<br/>

    print qq{
        &nbsp; &nbsp; &nbsp; &nbsp; <input type='checkbox' id='show_hist' name='show_hist' disabled/>
        &nbsp; Show histogram column
        <br/>
        &nbsp; &nbsp; &nbsp; &nbsp; <input type='checkbox' id='show_perc' name='show_perc' disabled/>
        &nbsp; Show percentage column
    };
    print "</p>\n";

    print "<p>\n";
    print qq{
        <b>Percent Identity</b><br/>
        <input type="radio" checked="checked" value="suc" name="percentage_count"> Successive (30% to 59%, 60% to 89%, 90%+)<br/>
        <input type="radio" value="cum" name="percentage_count"> Cumulative (30%+, 60%+, 90%+)<br/>
    };
    print "</p>\n";

    my $dbh = dbLogin();
    GenomeListFilter::appendGenomeListFilter( $dbh, 'Yes', '', '', '', '', '', '', '', 1 );

    print qq{
        <p>
        <span class="boldTitle">Metagenome List</span><br>
        Please select between 1 and $MAX_METAGENOMES metagenomes.
        <span id="metaglist-counter"></span>
        </p>
    };

    HtmlUtil::printMetaDataTypeChoice();

    #    printMetagenomeList($dbh, 1);
    printMetagenomeList( $dbh, 0 );

    print "<br/>\n";
    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "hits" );
    print submit(
        -name    => "",
        -value   => "Go",
        -onClick => "return checkMetagList();",
        -class   => "smdefbutton"
    );

    print end_form();
    printStatusLine( "Loaded.", 2 );

    print qq{
        <p>
        1 - Large metagenomes cannot be processed at this time due to computation limits. We are currently
        working on a solution to handle large metagenomes.
        </p>
    };
}

sub printFormJS {
    print <<END_JS;

    <script language="javascript" type="text/javascript">

    function checkMetagList() {
	if (document.mainForm.genomeFilterSelections.selectedIndex < 0) {
	    alert("Please select ONE isolate genome.");
	    return false;
	}

	if (document.mainForm.metagSelection.selectedIndex < 0) {
	    alert("Please select at least ONE metagenome.");
	    return false;
	} else {
	    return countSelected(true);
	}
    }

    function countSelected(showAlert) {
	var cnt = 0;
	var el = document.mainForm.metagSelection;
	var oList = document.getElementById("metaglist-counter");
	for (var i = 0; i < el.options.length; i++) {
	    if (el.options[i].selected) {
		cnt++;
	    }
	}
	if (cnt > $MAX_METAGENOMES) {
	    if (showAlert) {
		alert("You have selected " + cnt + " metagenomes. " +
		      "Please select $MAX_METAGENOMES metagenomes or less.");
		return false;
	    } else {
		oList.style.color = "red";
		oList.style.fontWeight = "bold";
	    }
	} else {
	    oList.style.color = "";
	    oList.style.fontWeight = "bold";
	}
	if (cnt > 0)
	    oList.innerHTML = "(Metagenomes selected: " + cnt + ")";
	else
	    oList.innerHTML = "";

    }

    </script>
END_JS
}

sub printMetagenomeList {
    my ( $dbh, $not_in_file ) = @_;

    my $urclause  = urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');

    my $not_in_file_clause;
    if ($not_in_file) {
        $not_in_file_clause = "and t.in_file = 'No'";
    }

    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name
        from taxon t
        where t.genome_type = 'metagenome'
        $not_in_file_clause
        $urclause
        $imgClause
        order by 2
    };

    print qq{
        <div style="resize:horizontal; overflow: auto; width: 500px;">
            <select size="10" name="metagSelection" multiple="multiple" onChange="return countSelected();">
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        print qq{
            <option value='$taxon_oid'> $taxon_display_name </option>
        };
        $cnt++;
    }

    print qq{
        </select>
        </div>
    };

}

sub printGeneList {
    my $taxon_oid = param("taxon_oid");    # ref genome id
    my $metag_oid = param("metag_oid");
    my $data_type = param("data_type");    # assembled or unassembled or both
    $data_type = param("r_data_type") if ( $data_type eq '' );

    my $percent          = param("percent");             # 30, 60, 90
    my $percentage_count = param("percentage_count");    # suc or cum

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printIsolateGenomeTitle( $dbh, $taxon_oid, $data_type, 'gene' );
    printHomologMetagenomeTitle( $dbh, $metag_oid, $data_type );

    my $taxon_in_file = MerFsUtil::isTaxonInFile( $dbh, $metag_oid );

    my $it = new InnerTable( 1, "genelist$$", "genelist$$", 0 );
    $it->addColSpec("Select");
    $it->addColSpec( "Homolog Gene ID",   "number desc", "right" );
    $it->addColSpec( "Homolog Gene Name", "char asc",    "left" );
    $it->addColSpec( "Gene ID",           "number desc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",    "left" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $metagene_url = "main.cgi?section=MetaGeneDetail&page=metaGeneDetail&gene_oid=";
    my $gene_url     = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    my $count = 0;
    my %distinctMgenes;
    my %distinctGenes;

    # Array of arrays ($metag_gene_oid, $metag_gene_name, $gene_oid, $gene_name)
    my $geneAoA;
    $metag_oid = sanitizeInt($metag_oid);
    my $phylo_dir = MetaUtil::getPhyloDistTaxonDir($metag_oid);
    if ( -e $phylo_dir ) {

        # use sqlite
        $geneAoA = getMetaPhyloGenes( $dbh, $taxon_oid, $metag_oid, $percent, $percentage_count );
    } elsif ( QueryUtil::isSingleCell( $dbh, $taxon_oid ) ) {

        # Get list of hits for single cell genomes
        $geneAoA = getSingleCellGenes( $dbh, $taxon_oid, $metag_oid, $percent, $percentage_count );
    } else {

        my $plus;
        $plus = 1 if ($percentage_count eq 'cum');
        my $rclause = PhyloUtil::getPercentClause( $percent, $plus );

        my $sql = qq{
            select dt.gene_oid, mg.gene_display_name, dt.homolog, g.gene_display_name
            from gene mg, dt_phylum_dist_genes dt, gene g
            where mg.gene_oid = dt.gene_oid
            and dt.taxon_oid = mg.taxon
            and dt.homolog = g.gene_oid
            and dt.taxon_oid = ?
            and dt.homolog_taxon = g.taxon
            and g.taxon = ?
            and dt.homolog_taxon = ?
            $rclause
        };

        my $cur = execSql( $dbh, $sql, $verbose, $metag_oid, $taxon_oid, $taxon_oid );
        $geneAoA = $cur->fetchall_arrayref();
        $cur->finish();
    }

    my $trunc = 0;
    for my $geneRow (@$geneAoA) {
        my ( $metag_gene_oid, $metag_gene_name, $gene_oid, $gene_name ) = @$geneRow;
        if ( $count >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }

        $count++;
        $distinctMgenes{$metag_gene_oid} = 1;
        $distinctGenes{$gene_oid}        = 1;

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$metag_gene_oid' >\t";

        if ( !$taxon_in_file ) {

            # taxon in database
            my $mg_oid = 0;
            if ( isInt($metag_gene_oid) ) {
                my $tmp = alink( $gene_url . $metag_gene_oid, $metag_gene_oid );
                $r .= $metag_gene_oid . $sd . $tmp . "\t";
                $mg_oid = $metag_gene_oid;
            } else {
                my ( $meta_t2, $meta_d2, $meta_g2 ) = split( / /, $metag_gene_oid );
                my $tmp = alink( $gene_url . $meta_g2, $meta_g2 );
                $r .= $meta_g2 . $sd . $tmp . "\t";
                $mg_oid = $meta_g2;
            }
            if ( !$metag_gene_name ) {
                $metag_gene_name = WebUtil::geneOid2Name( $dbh, $mg_oid );
            }
        } else {

            # taxon in file
            if ( isInt($metag_gene_oid) ) {
                my $tmp = alink( $gene_url . $metag_gene_oid, $metag_gene_oid );
                $r .= $metag_gene_oid . $sd . $tmp . "\t";
            } else {
                my ( $meta_t2, $meta_d2, $meta_g2 ) = split( / /, $metag_gene_oid );
                my $tmp = alink( $metagene_url . $metag_gene_oid . "&taxon_oid=$meta_t2&data_type=$meta_d2", $meta_g2 );
                $r .= $meta_g2 . $sd . $tmp . "\t";
            }
        }
        if ( !$metag_gene_name ) {
            $metag_gene_name = "hypothetical protein";
        }
        $r .= $metag_gene_name . $sd . $metag_gene_name . "\t";

        my $tmp = alink( $gene_url . $gene_oid, $gene_oid );
        $r .= $gene_oid . $sd . $tmp . "\t";
        $r .= $gene_name . $sd . $gene_name . "\t";
        $it->addRow($r);
    }

    printMainForm();

    WebUtil::printGeneCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    my $mgcnt = keys %distinctMgenes;
    my $gcnt  = keys %distinctGenes;

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "Rows: $count mgenes: $mgcnt genes: $gcnt", 2 );
    }
}

# first  viewer
# show all hit genes 30, 60, 90 on neighborhood like viewer
sub printPlot1 {
    my $taxon_oid = param("taxon_oid");    # ref genome id
    my @metag_oid = param("metag_oid");
    my $tooltip   = param("tooltip");
    my $size      = param("size");
    $tooltip = "false" if ( $tooltip eq "" );
    my $zoom_select = param("zoom_select");
    my ( $zoom_start, $zoom_end ) = split( /-/, $zoom_select )
      if ( $zoom_select ne "" );

    printStatusLine("Loading ...");
    my $dbh = dbLogin();

    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    print qq{
        <h1>
        Protein Recruitment Plot
        <br/>
        $taxon_name <br/>
        vs. <br/>
        Selected Metagenomes
        </h1>
    };

    if ( $#metag_oid > 60 ) {
        printStatusLine( "Loaded.", 2 );

        #$dbh->disconnect();
        webError("Please select only 60 metagenomes.");
    } elsif ( $#metag_oid < 0 ) {
        printStatusLine( "Loaded.", 2 );

        #$dbh->disconnect();
        webError("Please select at least 1 metagenome.");
    }

    # get ref  min and max size for plots
    my ( $ref_start_coord, $ref_end_coord );
    my ( $plot_start,      $plot_end );
    if ( $zoom_select ne "" ) {
        $ref_start_coord = $zoom_start;
        $ref_end_coord   = $zoom_end;
        $plot_start      = $ref_start_coord;
        $plot_end        = $ref_end_coord;
    } else {
        ( $ref_start_coord, $ref_end_coord ) = getTaxonRange( $dbh, $taxon_oid );
        $plot_start = 0;
        $plot_end   = $ref_end_coord;
    }

    #  initial plot now
    my $seq_length = $ref_end_coord - $ref_start_coord + 1;
    my $xincr      = ceil( $seq_length / 10 );
    my $args       = {
        id                 => "plot1.$$",
        start_coord        => $plot_start,
        end_coord          => $plot_end,
        coord_incr         => $xincr,
        strand             => "+",
        title              => "$ref_start_coord .. $ref_end_coord",
        has_frame          => 1,
        gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
        color_array_file   => $env->{dark_color_array_file},
        tmp_dir            => $tmp_dir,
        tmp_url            => $tmp_url,
        size               => $size,
        tooltip            => $tooltip
    };
    my $sp = new MetagGraphScatterPanel($args);

    # get color array
    my $color_aref = $sp->getColorArray();
    my $im         = $sp->getGDImage();

    #  ith color for each metag
    # for each metag  id get all the hits
    #    plot hits using ith color
    # end loop
    my %scaffold_name;
    getScaffoldName( $dbh, $taxon_oid, \%scaffold_name );

    # taxon oid => taxon name
    my %taxon_name_hash;

    my $metag_cnt = 0;

    printStartWorkingDiv();
    foreach my $meta_taxon_oid (@metag_oid) {
        my $taxon_name = taxonOid2Name( $dbh, $meta_taxon_oid );
        $taxon_name_hash{$meta_taxon_oid} = $taxon_name;

        print "Getting data for $taxon_name <br/>\n";
        my $aref = getHits( $dbh, $taxon_oid, $meta_taxon_oid, $zoom_start, $zoom_end );
        my $color = $color_aref->[$metag_cnt];
        foreach my $line (@$aref) {
            my (
                $mgene_oid, $mname,          $mstart,   $mend, $mscaffold_oid,
                $mstrand,   $mscaffold_name, $gene_oid, $name, $start,
                $end,       $scaffold_oid,   $strand,   $percent
              )
              = split( /\t/, $line );

            my $ref_scaffold_name = $scaffold_name{$scaffold_oid};

            my $label =
                "$mgene_oid $mscaffold_name $mstart..$mend $mstrand "
              . " $percent%  $gene_oid $ref_scaffold_name $start..$end $strand";

            $sp->addLine( $start, $end, $percent, $color, $gene_oid, $label );
        }
        $metag_cnt++;
    }

    printEndWorkingDiv();

    my $s = $sp->getMapHtml($tooltip);
    print "$s\n";

    print toolTipCode();

    printMainForm();

    # zoom for normal plots and xincr must be greater than 5000
    if ( $xincr > 5000 && param("size") eq "" ) {
        print qq{
        <script language="javascript" type="text/javascript">
        function plotZoom(main_cgi) {
            var f = document.mainForm;
            var range = f.elements['zoom_select'].value;
            if(range == '-') {
                return;
            }
            document.mainForm.submit();
        }
        </script>

        };

        print "<p>View Range &nbsp;&nbsp;";
        print "<SELECT name='zoom_select" . "' " . "onChange='plotZoom()'>\n";

        print "<OPTION value='-' selected='true'>-</option>";
        for ( my $i = $ref_start_coord ; $i <= $ref_end_coord ; $i = $i + $xincr ) {
            my $tmp = $i + $xincr;
            print "<OPTION value='$i-$tmp'>$i .. $tmp</option>";
        }
        print "</SELECT>";

        print hiddenVar( "section",   $section );
        print hiddenVar( "page",      "plot1" );
        print hiddenVar( "taxon_oid", $taxon_oid );
        print hiddenVar( "tooltip",   $tooltip );
        print hiddenVar( "size",      $size );
        foreach my $mid (@metag_oid) {
            print hiddenVar( "metag_oid", $mid );
        }
    }

    ### BEGIN static YUI table ###
    my $sit = new StaticInnerTable();

    $sit->addColSpec( "Color", "", "center" );
    $sit->addColSpec("Metagenome");

    for ( my $i = 0 ; $i <= $#metag_oid ; $i++ ) {
        my ( $r, $g, $b ) = $im->rgb( $color_aref->[$i] );
        my $kcolor = sprintf( "#%02x%02x%02x", $r, $g, $b );
        my $name   = $taxon_name_hash{ $metag_oid[$i] };
        my $url    = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=" . $metag_oid[$i];
        $url = alink( $url, $name );

        my $row = "<span style='border-left:1em solid $kcolor'>\t";
        $row .= $url . "\t";

        $sit->addRow($row);
    }
    $sit->printTable();
    ### END static YUI table ###

    my $size = $#metag_oid + 1;
    printStatusLine( "$size Metagenomes.", 2 );
    print end_form();
}

sub getScaffoldName {
    my ( $dbh, $taxon_oid, $href ) = @_;
    my $sql = qq{
    select s.scaffold_oid, s.scaffold_name
    from scaffold s
    where s.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    for ( ; ; ) {
        my ( $scaffold_oid, $name ) = $cur->fetchrow();
        last if ( !$scaffold_oid );
        $href->{$scaffold_oid} = $name;
    }
    $cur->finish();
}

sub getHits {
    my ( $dbh, $taxon_oid, $meta_taxon_oid, $zoom_start, $zoom_end ) = @_;

    # Array of arrays ($metag_gene_oid, $metag_gene_name, $gene_oid, $gene_name)
    my $geneAoA;
    my $cur;
    if ( QueryUtil::isSingleCell( $dbh, $taxon_oid ) ) {
        insertSingleCellGtt( $dbh, $taxon_oid, $meta_taxon_oid );

        my $sql = qq{
            select mg.gene_oid, mg.gene_display_name, mg.start_coord, mg.end_coord, mg.scaffold,
     	    mg.strand, ms.scaffold_name,
    	    g.gene_oid, g.gene_display_name, g.start_coord, g.end_coord, g.scaffold,
    	    g.strand, dt.percent
    	    from gtt_single_cells dt, gene mg, gene g, scaffold ms
    	    where dt.gene = mg.gene_oid
    	    and mg.scaffold = ms.scaffold_oid
    	    and dt.metagene = g.gene_oid
        };
        $cur = execSql( $dbh, $sql, $verbose );
    } else {
        my $sql = qq{
    	    select mg.gene_oid, mg.gene_display_name, mg.start_coord, mg.end_coord, mg.scaffold,
    	    mg.strand, ms.scaffold_name,
    	    g.gene_oid, g.gene_display_name, g.start_coord, g.end_coord, g.scaffold,
    	    g.strand,
    	    dt.percent_identity
    	    from dt_phylum_dist_genes dt, gene mg, gene g, scaffold ms
    	    where dt.gene_oid = mg.gene_oid
    	    and dt.taxon_oid = mg.taxon
    	    and mg.scaffold = ms.scaffold_oid
    	    and dt.homolog = g.gene_oid
    	    and dt.homolog_taxon = g.taxon
    	    and g.taxon = ?
    	    and dt.homolog_taxon = ?
    	    and dt.taxon_oid = ?
        };
        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid, $meta_taxon_oid );
    }
    $geneAoA = $cur->fetchall_arrayref();

    my @r;
    for my $geneRow (@$geneAoA) {
        my (
            $mgene_oid, $mname,          $mstart,   $mend, $mscaffold_oid,
            $mstrand,   $mscaffold_name, $gene_oid, $name, $start,
            $end,       $scaffold_oid,   $strand,   $percent
          )
          = @$geneRow;

        if ( $zoom_start ne "" ) {
            if (   ( $start >= $zoom_start && $start <= $zoom_end )
                || ( $end <= $zoom_end && $end >= $zoom_start ) )
            {

                # do nothing
            } else {

                # skip
                next;
            }
        }

        push( @r,
                "$mgene_oid\t$mname\t$mstart\t$mend\t$mscaffold_oid\t$mstrand\t$mscaffold_name\t"
              . "$gene_oid\t$name\t$start\t$end\t$scaffold_oid\t$strand\t$percent" );
    }
    $cur->finish();
    return \@r;
}

#
# For single cells, insert usearch values into a temp table
#
sub insertSingleCellGtt {
    my ( $dbh, $taxon1, $taxon2 ) = @_;

    my @rows;
    TaxonTarDir::getGenomePairData( $taxon1, $taxon2, \@rows, 1 );
    my $nRows = @rows;

    # Try reversal if no rows found.
    my $rev = 0;
    if ( $nRows == 0 ) {
        webLog("Try reversal with $taxon2 vs $taxon1\n");
        TaxonTarDir::getGenomePairData( $taxon2, $taxon1, \@rows, 1 );
        $rev = 1;
    }

    # Create global temp table if necessary
    my $colSql = "gene number(16,0), metagene number(16,0), percent number(6,2)";
    OracleUtil::createTempTableReady( $dbh, $gtt_single_cells, $colSql );

    # Delete existing rows in global temp table
    OracleUtil::truncTable( $dbh, $gtt_single_cells );

    my $asValues = "(gene, metagene, percent) values (?, ?, ?)";
    for my $s (@rows) {
        my ( $geneOid, $mGeneOid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore )
          = split( /\t/, $s );

        # Swap query and subject if using reverse file.
        if ($rev) {
            my $tmp = $geneOid;
            $geneOid  = $mGeneOid;
            $mGeneOid = $tmp;
        }
        my @binds_ref = ( $geneOid, $mGeneOid, $percIdent );
        OracleUtil::insertIntoTable( $dbh, $gtt_single_cells, $asValues, \@binds_ref );
    }
}

# gets the the min and max of all the gene seq.
sub getTaxonRange {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
    select min(g.start_coord), max(g.end_coord)
    from gene g
    where g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $start, $end ) = $cur->fetchrow();
    $cur->finish();
    return ( $start, $end );
}

# print summary table
# showing metag phylum and ir_class
sub printSummary {
    my $taxon_oid = param("taxon_oid");    # ref genome id
    my $domain    = "*Microbiome";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    print qq{
        <h1>
        $taxon_name <br/>
        Genome hits to Metagenomes Phylum
        </h1>
    };

    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();
    my $sql = qq{
        select ts.cds_genes
        from taxon_stats ts
        where ts.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($totalGeneCount) = $cur->fetchrow();
    $cur->finish();

    print "Getting all metagenomes<br/>\n";

    my $metag_list_aref = getMetaGenomesSummary( $dbh, $taxon_oid );
    print "Getting 30%<br/>\n";
    my $stats_30_href = loadMetagenomeStatsSummary( $dbh, $taxon_oid, 30 );
    print "Getting 60%<br/>\n";
    my $stats_60_href = loadMetagenomeStatsSummary( $dbh, $taxon_oid, 60 );
    print "Getting 90%<br/>\n";
    my $stats_90_href = loadMetagenomeStatsSummary( $dbh, $taxon_oid, 90 );

    printEndWorkingDiv();

    print qq{
        <p>
        <a href='main.cgi?section=GenomeHits&page=hits&taxon_oid=$taxon_oid'/> View all Metagenomes </a>
        </p>
        <table class='img'>
        <th class='img'> Phylum IR Class </th>
        <th class='img'> Metagenome Count </th>
        <th class='img' align='right'> Metagenome Hit Scaffold Count</th>
        <th class='img' align='right'> Ref. Genome Hit Scaffold Count</th>
        <th class='img' title='30% to 59%' align='right'> No. Of Hits 30 %  </th>
        <th class='img'> Histogram 30%</th>
        <th class='img' title='60% to 89%' align='right'> No. Of Hits 60 %  </th>
        <th class='img'> Histogram 60%</th>
        <th class='img' align='right'> No. Of Hits 90 %  </th>
        <th class='img'> Histogram 90%</th>
    };

    my $genelist_url = "#";
    my $hit_url      = "main.cgi?section=GenomeHits&page=hits&taxon_oid=$taxon_oid";
    foreach my $line (@$metag_list_aref) {
        my ( $phylum, $ir_class, $scaffold_cnt, $metag_scaffold_cnt, $metag_taxon_cnt ) =
          split( /\t/, $line );
        print "<tr class='img'>\n";

        my $tmp_url = $hit_url;
        if ( $phylum ne "" ) {
            $tmp_url .= "&phylum=$phylum";
        }
        if ( $ir_class ne "" ) {
            $tmp_url .= "&ir_class=$ir_class";
        }
        $tmp_url = alink( $tmp_url, "$phylum $ir_class" );

        print "<td class='img'>  $tmp_url </td>\n";

        print "<td class='img' align='right'> $metag_taxon_cnt </td>\n";
        print "<td class='img' align='right'> $metag_scaffold_cnt </td>\n";
        print "<td class='img' align='right'> $scaffold_cnt </td>\n";

        my $cnt = $stats_30_href->{"$phylum\t$ir_class"};
        if ( $cnt ne "" ) {
            print "<td class='img' align='right'> $cnt </td>\n";
        } else {
            print "<td class='img' align='right'> &nbsp; </td>\n";
        }
        print "<td class='img'>";
        print histogramBar( $cnt / $totalGeneCount, 100 );
        print "</td>\n";

        my $cnt = $stats_60_href->{"$phylum\t$ir_class"};
        if ( $cnt ne "" ) {
            print "<td class='img' align='right'> $cnt </td>\n";
        } else {
            print "<td class='img' align='right'> &nbsp; </td>\n";
        }
        print "<td class='img'>";
        print histogramBar( $cnt / $totalGeneCount, 100 );
        print "</td>\n";

        my $cnt = $stats_90_href->{"$phylum\t$ir_class"};
        if ( $cnt ne "" ) {
            print "<td class='img' align='right'> $cnt </td>\n";
        } else {
            print "<td class='img' align='right'> &nbsp; </td>\n";
        }
        print "<td class='img'>";
        print histogramBar( $cnt / $totalGeneCount, 100 );
        print "</td>\n";

        print "</tr>\n";
    }

    print "</table>\n";

    #$dbh->disconnect();
    my $size = $#$metag_list_aref + 1;
    printStatusLine( "$size Loaded.", 2 );

}

############################################################################################
# printHits
# (new one using dt_phylo_taxon_stats)
############################################################################################
sub printHits {
    my $taxon_oid        = param('selectedGenome1');
    my $phylum           = param("phylum");             # metag phylum
    my $ir_class         = param("ir_class");           # metag ir_class
    my $percentage_count = param("percentage_count");
    my $show_hist        = param("show_hist");
    my $show_perc        = param("show_perc");
    my @metagenome_oids  = param('selectedGenome2');
    my $data_type        = param("data_type");          # assembled or unassembled or both
    $data_type = param("r_data_type") if ( $data_type eq '' );
    my $domain = "*Microbiome";

    #print "taxon_oid:[$taxon_oid]<br>";
    #print "metagSelection:[ @metagenome_oids ]<br>";

    # TODO example
    # $VAR1 = [ 'all', '2044078004', '2012932009', '2012932011', '2014613000',
    # '2012932008', '2012932007' ];

    if ( $taxon_oid eq "" ) {
        webError("Please select one genome.");
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    printIsolateGenomeTitle( $dbh, $taxon_oid, $data_type );
    if ( $phylum || $ir_class ) {
        print "<p> $phylum $ir_class </p>";
    }

    printStartWorkingDiv();
    print "Getting metagenomes ...<br/>\n";

    #  order by name: taxon oid \t name \t hit scaffold counts
    # TODO restrict metag to public ones or based on user
    # the taxon genome_type = 'metagenome'
    # user restriction is done in getMetaGenomes( $dbh, $taxon_oid );
    my $metag_list_aref;
    my $stats_30_href;
    my $stats_60_href;
    my $stats_90_href;

    if ( QueryUtil::isSingleCell( $dbh, $taxon_oid ) ) {
        %$stats_30_href   = {};
        %$stats_60_href   = {};
        %$stats_90_href   = {};
        @$metag_list_aref = ();
        getSingleCellStats( $dbh, $taxon_oid, $stats_30_href, $stats_60_href, $stats_90_href, $percentage_count,
            \@metagenome_oids, $metag_list_aref );
    } else {
        %$stats_30_href   = {};
        %$stats_60_href   = {};
        %$stats_90_href   = {};
        @$metag_list_aref = ();

        # user's metagenome selection
        my $metagenomeClause;
        my $size = $#metagenome_oids + 1;
        if ( $metagenome_oids[0] eq 'all' || $size <= 0 ) {
            @metagenome_oids = ();
        } else {
            my $tmp = OracleUtil::getNumberIdsInClause( $dbh, @metagenome_oids );
            $metagenomeClause = " and dt.taxon_oid in ($tmp) ";
        }

        my $urclause  = urClause("t.taxon_oid");
        my $imgClause = WebUtil::imgClause('t');
        my $sql2      = qq{
            select dt.taxon_oid, t.taxon_display_name,
                  dt.gene_count_30, dt.gene_count_60, dt.gene_count_90
            from taxon t, dt_phylo_taxon_stats dt
            where dt.homolog_taxon = ?
            and dt.taxon_oid = t.taxon_oid
            $urclause
            $imgClause
            $metagenomeClause
        };
        print "GenomeHits::printHits() $sql2<br/>\n";

        my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid );
        my %taxon_h;
        for ( ; ; ) {
            my ( $tid2, $t_name, $c30, $c60, $c90 ) = $cur2->fetchrow();
            last if ( !$tid2 );

            if ( $taxon_h{$tid2} ) {

                # already there
                $stats_30_href->{$tid2} += $c30;
                $stats_60_href->{$tid2} += $c60;
                $stats_90_href->{$tid2} += $c90;
            } else {

                # new
                push @$metag_list_aref, ("$tid2\t$t_name\t1\t1");
                $stats_30_href->{$tid2} = $c30;
                $stats_60_href->{$tid2} = $c60;
                $stats_90_href->{$tid2} = $c90;
            }
        }
        $cur2->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $metagenomeClause =~ /gtt_num_id/i );
    }

    printEndWorkingDiv();

    if ( scalar(@$metag_list_aref) == 0 ) {
        webError("No metagenome hits are found.");
        return;
    }

    my $tableId = "genomehits";
    my $it = new InnerTable( 1, $tableId, $tableId . $$, 0 );
    $it->hidePagination();
    $it->hideFilterLine();
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Metagenome Name", "asc", "left" );

    $it->addColSpec( "Num. Of Hits 30 %", "desc", "right" );
    $it->addColSpec( "% Hits 30%", "desc", "right" ) if ($show_perc);
    $it->addColSpec("Histogram 30%") if ($show_hist);

    $it->addColSpec( "Num. Of Hits 60 %", "desc", "right" );
    $it->addColSpec( "% Hits 60%", "desc", "right" ) if ($show_perc);
    $it->addColSpec("Histogram 60%") if ($show_hist);

    $it->addColSpec( "Num. Of Hits 90 %", "desc", "right" );
    $it->addColSpec( "% Hits 90%", "desc", "right" ) if ($show_perc);
    $it->addColSpec("Histogram 90%") if ($show_hist);

    my $taxon_url    = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";
    my $genelist_url = "$section_cgi&page=genelist&taxon_oid=$taxon_oid" . "&data_type=$data_type&metag_oid=";

    my $row_cnt = 0;
    foreach my $line (@$metag_list_aref) {
        my ( $metag_oid, $name, $scaffold_cnt, $metag_scaffold_cnt ) =
          split( /\t/, $line );

        my $sql2 = qq{
           select ts.cds_genes
           from taxon_stats ts
           where ts.taxon_oid = ?
        };
        my $cur2 = execSql( $dbh, $sql2, $verbose, $metag_oid );
        my ($totalGeneCount) = $cur2->fetchrow();
        $cur2->finish();

        my $r;
        $r .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$metag_oid' />\t";
        my $tmp = alink( $taxon_url . $metag_oid, $name );
        $r .= $name . $sd . $tmp . "\t";

        # 30
        my $cnt = $stats_30_href->{$metag_oid};
        if ( $percentage_count eq 'cum' ) {
            $cnt += $stats_60_href->{$metag_oid} + $stats_90_href->{$metag_oid};
        }
        if ( $cnt ne "" && $cnt > 0 ) {
            my $tmp = $genelist_url . $metag_oid . "&percent=30&percentage_count=$percentage_count";
            $tmp = alink( $tmp, $cnt );
            $r .= $cnt . $sd . $tmp . "\t";
        } else {
            print "<td class='img' align='right'> &nbsp; </td>\n";
            $r .= "0" . $sd . "0" . "\t";
        }
        if ($show_perc) {
            my $x = $cnt * 100 / $totalGeneCount;
            $x = sprintf "%.2f%", $x;
            $r .= $x . $sd . $x . "\t";
        }
        if ( $show_hist ne "" ) {
            $r .= $sd . histogramBar( $cnt / $totalGeneCount, 100 ) . "\t";
        }

        # 60
        my $cnt = $stats_60_href->{$metag_oid};
        if ( $percentage_count eq 'cum' ) {
            $cnt += $stats_90_href->{$metag_oid};
        }
        if ( $cnt ne "" && $cnt > 0 ) {
            my $tmp = $genelist_url . $metag_oid . "&percent=60&percentage_count=$percentage_count";
            $tmp = alink( $tmp, $cnt );
            $r .= $cnt . $sd . $tmp . "\t";
        } else {
            print "<td class='img' align='right'> &nbsp; </td>\n";
            $r .= "0" . $sd . "0" . "\t";
        }
        if ($show_perc) {
            my $x = $cnt * 100 / $totalGeneCount;
            $x = sprintf "%.2f%", $x;
            $r .= $x . $sd . $x . "\t";
        }
        if ( $show_hist ne "" ) {
            $r .= $sd . histogramBar( $cnt / $totalGeneCount, 100 ) . "\t";
        }

        # 90
        my $cnt = $stats_90_href->{$metag_oid};
        if ( $cnt ne "" && $cnt > 0 ) {
            my $tmp = $genelist_url . $metag_oid . "&percent=90&percentage_count=$percentage_count";
            $tmp = alink( $tmp, $cnt );
            $r .= $cnt . $sd . $tmp . "\t";
        } else {
            print "<td class='img' align='right'> &nbsp; </td>\n";
            $r .= "0" . $sd . "0" . "\t";
        }
        if ($show_perc) {
            my $x = $cnt * 100 / $totalGeneCount;
            $x = sprintf "%.2f%", $x;
            $r .= $x . $sd . $x . "\t";
        }
        if ( $show_hist ne "" ) {
            $r .= $sd . histogramBar( $cnt / $totalGeneCount, 100 ) . "\t";
        }

        $it->addRow($r);
        $row_cnt++;
    }

    WebUtil::printGenomeCartFooter() if ( $row_cnt > 10 );
    $it->printOuterTable(1);
    WebUtil::printGenomeCartFooter();

    print <<EOF;
    <script language="javascript" type="text/javascript">
        function mySubmit(page) {
	    var ret = isChecked();
	    if (!ret)
		return false;
            document.mainForm.page.value = page;
            document.mainForm.submit();
    }

    function clearAll( ) {
	var f = document.mainForm.metag_oid;

	for( var i = 0; i < f.length; i++ ) {
	    var e = f[ i ];
	    if(e.name == "metag_oid" && e.type == "checkbox" ) {
		e.checked = false;
	    }
	}
    }

    function isChecked() {
	var oIMG = oIMGTable_$tableId$$;
	var chks;

	if (oIMG) { //YUI tables
	    chks = oIMG.rows;
	} else {
	    return true;
	}

	if (chks < 1) {
	    alert ("Please select one or more metagenomes.");
	    return false;
	} else {
	    return true;
	}
    }

        </script>
EOF

    #    print hiddenVar( "section",   $section );
    #    print hiddenVar( "page",      "" );
    #    print hiddenVar( "taxon_oid", $taxon_oid );

    # temporary disable this option
    #    print qq{
    #        <p>
    #        <b> Plot Options </b>
    #        <br/><br/>
    #        <input type='checkbox'
    #        name='tooltip'
    #        value='true'
    #        checked />
    #        &nbsp; Show tooltips
    #        <br/>
    #        <input type='checkbox'
    #        name='size'
    #        value='large'/>
    #        &nbsp; Display larger plot (4096x2048)
    #        </p>
    #
    #        <input type="button"
    #        name="runplot1"
    #        value="Protein Recruitment Plot"
    #        class="meddefbutton"
    #        onClick='return mySubmit("plot1");' />
    #    };

    print end_form();

    #$dbh->disconnect();
    my $size = $#$metag_list_aref + 1;
    printStatusLine( "$size Loaded.", 2 );
}

# gets all distinct metag hits taxon_oid from a given ref genome
sub getMetaGenomes {
    my ( $dbh, $taxon_oid, $phylum, $ir_class, $metagenomeClause ) = @_;

    my $urclause  = urClause("mg.taxon");
    my $imgClause = WebUtil::imgClause('t');

    my @binds = ( $taxon_oid, $taxon_oid );

    my $pclause = "";
    if ( $phylum ne "" ) {
        $pclause = " and t.phylum = ? ";
        push( @binds, $phylum );
    }
    if ( $ir_class ne "" ) {
        $pclause .= " and t.ir_class = ? ";
        push( @binds, $ir_class );
    }

    if ( $pclause eq "" ) {

        # faster queries
        my $ids_aref = getMetaGenomes2( $dbh, $taxon_oid, $metagenomeClause );
        return $ids_aref;
    }

    my $sql = qq{
        select dt.taxon_oid, t.taxon_display_name, count(distinct g.scaffold), count(distinct mg.scaffold)
        from dt_phylum_dist_genes dt,  gene g, taxon t,  gene mg, taxon mt
        where  dt.gene_oid = mg.gene_oid
        and dt.taxon_oid = mg.taxon
        and mg.taxon = mt.taxon_oid
        and dt.taxon_oid = mt.taxon_oid
        and mt.genome_type = 'metagenome'
        and dt.homolog = g.gene_oid
        and t.taxon_oid  = dt.taxon_oid
        and dt.homolog_taxon = g.taxon
        and g.taxon = ?
        and dt.homolog_taxon = ?
        $urclause
        $imgClause
        $pclause
        $metagenomeClause
        group by dt.taxon_oid, t.taxon_display_name
        order by t.taxon_display_name
    };

    my @ids;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $metag_id, $name, $scnt, $mg_scnt ) = $cur->fetchrow();
        last if !$metag_id;
        push( @ids, "$metag_id\t$name\t$scnt\t$mg_scnt" );
    }
    $cur->finish();
    return \@ids;
}

#
# break getMetaGenomes sql into 3 sqls
#
sub getMetaGenomes2 {
    my ( $dbh, $taxon_oid, $metagenomeClause ) = @_;

    my $urclause  = urClause("dt.taxon_oid");
    my $imgClause = WebUtil::imgClause('dt');

    print "Getting Metagenome data<br/>\n";
    my $sql = qq{
        select dt.taxon_oid, dt.taxon_display_name
        from taxon dt
        where 1 = 1
        $urclause
        $imgClause
        $metagenomeClause
    };

    # taxon_oid => display name
    my %genome_names;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $genome_names{$id} = $name;
    }

    # get scaffold count
    print "Getting homolog scaffold count<br/>\n";
    my %scaffold_counts;

    $imgClause = WebUtil::imgClause('mt');
    my $sql = qq{
        select dt.taxon_oid, g.scaffold
        from dt_phylum_dist_genes dt,  gene g, taxon mt
        where  dt.homolog = g.gene_oid
        and dt.taxon_oid = mt.taxon_oid
        and mt.genome_type = 'metagenome'
        and dt.homolog_taxon = g.taxon
        and g.taxon = ?
        and dt.homolog_taxon = ?
        $urclause
        $imgClause
        $metagenomeClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $taxon_oid );
    my %hashOfHash;    # taxon => hash of scaffold ids
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if !$id;

        #$scaffold_counts{$id} = $count;
        if ( exists $hashOfHash{$id} ) {
            my $href = $hashOfHash{$id};
            $href->{$count} = '';
        } else {
            print ".";
            my %tmp = ($count);
            $hashOfHash{$id} = \%tmp;
        }
    }
    print "<br>\n";

    foreach my $id ( keys %hashOfHash ) {
        my $href = $hashOfHash{$id};
        my $size = keys(%$href);
        $scaffold_counts{$id} = $size;
    }

    # get metagenome scaffold count
    print "Getting metagenome scaffold count ... this may take some time.<br/>\n";
    my %metag_scaffold_counts;

    my $sql = qq{
        select dt.taxon_oid, mg.scaffold
        from dt_phylum_dist_genes dt, gene mg, taxon mt
        where  dt.gene_oid = mg.gene_oid
        and dt.taxon_oid = mg.taxon
        and dt.taxon_oid = mt.taxon_oid
        and mg.taxon = mt.taxon_oid
        and mt.genome_type = 'metagenome'
        and dt.homolog_taxon = ?
        $urclause
        $imgClause
        $metagenomeClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my %hashOfHash;    # taxon => hash of scaffold ids
    for ( ; ; ) {
        my ( $id, $count ) = $cur->fetchrow();
        last if !$id;

        if ( exists $hashOfHash{$id} ) {
            my $href = $hashOfHash{$id};
            $href->{$count} = '';
        } else {
            print ".";
            my %tmp = ($count);
            $hashOfHash{$id} = \%tmp;
        }
    }

    foreach my $id ( keys %hashOfHash ) {
        my $href = $hashOfHash{$id};
        my $size = keys(%$href);
        $metag_scaffold_counts{$id} = $size;
    }

    my @results;
    foreach my $taxon_oid (
        sort { $genome_names{$a} cmp $genome_names{$b} }
        keys %genome_names
      )
    {
        my $taxon_name = $genome_names{$taxon_oid};
        next if ( !exists $metag_scaffold_counts{$taxon_oid} );

        my $s_cnt    = $scaffold_counts{$taxon_oid};
        my $mg_s_cnt = $metag_scaffold_counts{$taxon_oid};
        push( @results, "$taxon_oid\t$taxon_name\t$s_cnt\t$mg_s_cnt" );
    }
    return \@results;
}

# gets all distinct metag hits taxon_oid from a given ref genome
# no used right now - ken
sub getMetaGenomesSummary {
    my ( $dbh, $taxon_oid ) = @_;

    my $urclause  = urClause("mg.taxon");
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select t.phylum, t.ir_class, count(distinct g.scaffold), count(distinct mg.scaffold),
        count(distinct dt.taxon_oid)
        from dt_phylum_dist_genes dt,  gene g, taxon t,  gene mg, taxon mt
        where  dt.gene_oid = mg.gene_oid
        and dt.taxon_oid = mg.taxon
        and dt.taxon_oid = mt.taxon_oid
        and mt.genome_type = 'metagenome'
        and dt.homolog = g.gene_oid
        and dt.homolog_taxon = g.taxon
        and t.taxon_oid  = dt.taxon_oid
        and g.taxon = ?
        $urclause
        $imgClause
        group by t.phylum, t.ir_class
        order by t.phylum, t.ir_class
    };

    my @ids;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $phylum, $ir_class, $scnt, $mg_scnt, $mtaxon_cnt ) = $cur->fetchrow();
        last if !$phylum;
        push( @ids, "$phylum\t$ir_class\t$scnt\t$mg_scnt\t$mtaxon_cnt" );
    }
    $cur->finish();
    return \@ids;
}

# gets metag hits stats for the given ref genome
sub loadMetagenomeStatsSummary {
    my ( $dbh, $taxon_oid, $percent_identity ) = @_;

    my $rclause = PhyloUtil::getPercentClause( $percent_identity );

    my $urclause  = WebUtil::urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');

    my $sql = qq{
        select t.phylum, t.ir_class, count( dt.gene_oid)
        from dt_phylum_dist_genes dt, gene g, taxon t
        where dt.homolog = g.gene_oid
        and dt.homolog_taxon = g.taxon
        and g.taxon = ?
        and dt.taxon_oid = t.taxon_oid
        $rclause
        $urclause
        $imgClause
        group by t.phylum, t.ir_class
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $phylum, $ir_class, $cnt ) = $cur->fetchrow();
        last if !$phylum;
        $hash{"$phylum\t$ir_class"} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub getSingleCellStats {
    my ( $dbh, $taxon1, $stats_30_href, $stats_60_href, $stats_90_href, $percIdentType, $metagenome_oids, $metag_list_aref )
      = @_;

    for my $taxon2 (@$metagenome_oids) {
        my @rows;
        my $metagName = taxonOid2Name( $dbh, $taxon2 );

        TaxonTarDir::getGenomePairData( $taxon1, $taxon2, \@rows );
        my $nRows = @rows;

        # Try reversal if no rows found.
        my $rev = 0;
        if ( $nRows == 0 ) {
            webLog("Try reversal with $taxon2 vs $taxon1\n");
            TaxonTarDir::getGenomePairData( $taxon2, $taxon1, \@rows );
            $rev = 1;
        }
        my $metagList = "$taxon2\t$metagName\t1\t$nRows";
        push @$metag_list_aref, $metagList;

        my $hits30 = 0;
        my $hits60 = 0;
        my $hits90 = 0;
        for my $s (@rows) {
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );
            if ( $percIdentType eq "cum" ) {    # 30%+, 60%+, 90%+
                if ( $percIdent >= 30 ) {
                    $hits30++;
                } elsif ( $percIdent >= 60 ) {
                    $hits60++;
                } elsif ( $percIdent >= 90 ) {
                    $hits90++;
                }
            } else {                            # suc: 30%-59%, 60%-89%, 90%+
                if ( $percIdent >= 30 && $percIdent < 60 ) {
                    $hits30++;
                } elsif ( $percIdent >= 60 && $percIdent < 90 ) {
                    $hits60++;
                } elsif ( $percIdent >= 90 ) {
                    $hits90++;
                }
            }
        }
        $stats_30_href->{$taxon2} = $hits30 if $hits30;
        $stats_60_href->{$taxon2} = $hits60 if $hits60;
        $stats_90_href->{$taxon2} = $hits90 if $hits90;
    }
}

sub getSingleCellGenes {
    my ( $dbh, $taxon1, $taxon2, $percIdent_filter, $percIdentType ) = @_;
    my @rows;

    TaxonTarDir::getGenomePairData( $taxon1, $taxon2, \@rows, 1 );
    my $nRows = @rows;

    # Try reversal if no rows found.
    my $rev = 0;
    if ( $nRows == 0 ) {
        webLog("Try reversal with $taxon2 vs $taxon1\n");
        TaxonTarDir::getGenomePairData( $taxon2, $taxon1, \@rows, 1 );
        $rev = 1;
    }

    my @geneArray;
    for my $s (@rows) {
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );

        # Swap query and subject if using reverse file.
        if ($rev) {
            my $tmp = $qid;
            $qid = $sid;
            $sid = $tmp;

        }
        my $mGeneOid  = $sid;                              # metagenome gene_oid
        my $geneOid   = $qid;                              # isolate genome gene_oid
        my $mGeneName = geneOid2Name( $dbh, $mGeneOid );
        my $geneName  = geneOid2Name( $dbh, $geneOid );

        my @geneRow;
        if ( $percIdentType eq "cum" ) {                   # 30%+, 60%+, 90%+
            if ( $percIdent >= $percIdent_filter ) {
                push( @geneRow, $mGeneOid, $mGeneName, $geneOid, $geneName );
            }
        } else {                                           # suc: 30%-59%, 60%-89%, 90%+
            if ( $percIdent_filter == 30 ) {
                push( @geneRow, $mGeneOid, $mGeneName, $geneOid, $geneName )
                  if ( $percIdent >= 30 && $percIdent < 60 );
            } elsif ( $percIdent_filter == 60 ) {
                push( @geneRow, $mGeneOid, $mGeneName, $geneOid, $geneName )
                  if ( $percIdent >= 60 && $percIdent < 90 );
            } else {
                push( @geneRow, $mGeneOid, $mGeneName, $geneOid, $geneName )
                  if ( $percIdent >= 90 );
            }
        }
        push( @geneArray, \@geneRow ) if @geneRow;
    }
    return \@geneArray;
}

sub getMetaPhyloGenes {
    my ( $dbh, $taxon_oid, $metag_oid, $percent, $percentage_count ) = @_;

    my @plist = ($percent);
    if ( $percentage_count eq 'cum' ) {
        if ( $percent == 30 ) {
            @plist = ( 30, 60, 90 );
        } elsif ( $percent == 60 ) {
            @plist = ( 60, 90 );
        }
    }

    $metag_oid = sanitizeInt($metag_oid);
    my $phylo_dir = MetaUtil::getPhyloDistTaxonDir($metag_oid);

    my @geneArray;
    for my $p2 (@plist) {
        for my $data_type ( 'assembled', 'unassembled' ) {
            my $sdb_name = $phylo_dir . "/" . $data_type . "." . $p2 . ".sdb";

            if ( !( -e $sdb_name ) ) {
                next;
            }

            my $dbh2 = WebUtil::sdbLogin($sdb_name)
              or next;

            my $max_count = $maxGeneListResults + 1;
            my $sql = MetaUtil::getPhyloDistSingleHomoTaxonSql();
            if ($max_count) {
                $sql .= " LIMIT $max_count ";
            }
            my $sth = $dbh2->prepare($sql);
            $sth->execute($taxon_oid);

            my ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon, $copies );
            while ( ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon, $copies ) = $sth->fetchrow_array() ) {
                if ( !$gene_oid ) {
                    last;
                }

                my $mGeneOid  = "$metag_oid $data_type $gene_oid";                                # metagenome gene_oid
                my $mGeneName = MetaUtil::getGeneProdName( $gene_oid, $metag_oid, $data_type );
                my $geneName  = geneOid2Name( $dbh, $homolog_gene );

                my @geneRow = ($mGeneOid, $mGeneName, $homolog_gene, $geneName);
                push( @geneArray, \@geneRow );
            }
            $sth->finish();
            $dbh2->disconnect();
        }    # end for data type
    }    # end for p2
    return \@geneArray;
}
###############################################################################
# printIsolateGenomeDistribution
## one single isolate genome, a number of metagenome,
###############################################################################
sub printIsolateGenomeDistribution {
    my $list_type        = param("listtype");
    my $percent_identity = param("percent_identity");
    my $data_type        = param("data_type");          # assembled or unassembled or both
    $data_type = param("r_data_type") if ( $data_type eq '' );

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    my $isolate_taxon_oid =
      param('selectedGenome1');   #OracleUtil::processTaxonSelectionSingleParam("genomeFilterSelections");    # ref genome id
    if ( $isolate_taxon_oid eq "" ) {
        $isolate_taxon_oid = param("taxon_oid");
    }
    $isolate_taxon_oid = WebUtil::sanitizeInt($isolate_taxon_oid);

    printIsolateGenomeTitle($dbh, $isolate_taxon_oid, $data_type, $list_type);

    my @filter_levels =
	( "phylum", "ir_class", "ir_order", "family", "genus", "species" );
    my %itemLevel_h = (
        default  => "Phylum",
        phylum   => "Class",
        ir_class => "Order",
        ir_order => "Family",
        family   => "Genus",
        genus    => "Species",
        species  => "Metagenomes"
    );

    my $filter_clause;
    if ( $list_type ne "gene" ) {
        my $filterLevel = "default";
        my %filter_h;
        my $filter_desc;
        for my $l (@filter_levels) {
            $filter_h{$l} = param( $l . "filter" );
            last if !( $filter_h{$l} );
            $filterLevel = $l;
            $filter_desc .= " -> " if ( $filter_desc ne "" );
            $filter_desc   .= $filter_h{$l};
            $filter_clause .= " and t.$filterLevel = '" . $filter_h{$l} . "' ";
        }

        print "<p style='width: 900px;'>";

        # always print this message
        print qq{
            This analysis shows how genes in this single genome are matched
            by BLAST to genes in different metagenomes or
            metagenomic categories.<br>
        };

        # print this message only for category view, not for metagenome view
        print qq{
            Click on a category name (<i>e.g. engineered, environmental</i>)
            to view results in each category.<br>\n
            The numbers not in brackets ( ) are hit metagenome counts.
            The numbers in brackets ( ) are hit gene counts
            in those metagenomes.<br>
        } if ( $itemLevel_h{$filterLevel} ne "Metagenomes"
            && $percent_identity eq "" );

        # print this message only for "per genome" view, i.e. when a list of
        # genes are printed, and there are no counts
        print qq{
            Please note that hit gene counts do not exclude duplicates
            and therefore can only be used as rough estimates.<br>
        } if ( $itemLevel_h{$filterLevel} ne "Metagenomes" );

        # print this message when hits are filtered by phylum, order ...
        print qq{
            The statistics below only include BLAST hits in
            <b><i>$filter_desc</i></b>.
        } if ($filter_desc);

        print "</p>";

    }

    if ( $list_type eq "gene" ) {
        printIsolateGenomeDistribution_gene( $dbh, $isolate_taxon_oid, $filter_clause );
    } elsif ( $list_type eq "group" or $list_type eq "" ) {
        printIsolateGenomeDistribution_groups( $dbh, $isolate_taxon_oid, $filter_clause, \@filter_levels, \%itemLevel_h );
    }
    return;
}

sub printIsolateGenomeTitle {
    my ( $dbh, $isolate_taxon_oid, $data_type, $list_type ) = @_;

    print "<h1>Single Genome vs. Metagenomes</h1>\n";
    my $taxon_name = QueryUtil::fetchTaxonName( $dbh, $isolate_taxon_oid );
    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$isolate_taxon_oid";
    print "<p style='width: 650px;'>";
    print "<u>Single genome</u>: " . alink( $url, $taxon_name, "_blank" );
    if ( $list_type eq "group" or $list_type eq "" ) {
        if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
            print "<br/><u>Homolog Metagenome</u>: ($data_type)";
        }
    }

    print "</p>";
}

###############################################################################
# printIsolateGenomeDistribution_gene
## one single isolate genome, against one metagenome
## print a list of hit genes
###############################################################################
sub printIsolateGenomeDistribution_gene {
    my ( $dbh, $isolate_taxon_oid, $filter_clause ) = @_;

    my $percent_identity = param("percent_identity");
    my $percentage_count = param("percentage_count");    # "suc" or "cum"
    my $metag_taxon_oid  = param("metag_taxon_oid");
    my $data_type        = param("data_type");           # assembled or unassembled or both
    $data_type = param("r_data_type") if ( $data_type eq '' );
    my $plus = ( $percentage_count eq "cum" ) ? "+" : "";

    printHomologMetagenomeTitle( $dbh, $metag_taxon_oid, $data_type );

    printStartWorkingDiv();

    ## successive or cumulative percent identities
    my @percent_identities = ($percent_identity);
    if ( $percentage_count eq "cum" ) {
        if ( $percent_identity eq "30" ) {
            @percent_identities = qw/30 60 90/;
        } elsif ( $percent_identity eq "60" ) {
            @percent_identities = qw/60 90/;
        }
    }

    ## get detailed hit info from sdb files
    print "<p>Get homolog gene information ...\n";

    # isolate is homolog for metagenome
    my %phylo_genes_h =
      MetaUtil::getPhyloGenesForHomoTaxon( $metag_taxon_oid, $data_type, $isolate_taxon_oid, @percent_identities );

    my %isolate_hit_genes_h;
    for my $workspace_id ( keys %phylo_genes_h ) {
        my ( $gene_oid, $gene_perc, $homolog_gene, $copies ) = split( /\t/, $phylo_genes_h{$workspace_id} );
        $isolate_hit_genes_h{$homolog_gene} = $workspace_id;
    }

    ## get hit gene names and locus tags
    my @hit_gene_oids = keys %isolate_hit_genes_h;
    my $oid_str       = OracleUtil::getNumberIdsInClause( $dbh, @hit_gene_oids );
    my $sql           = qq{
        select g.gene_oid, g.locus_tag, g.gene_display_name
        from gene g
        where g.gene_oid in ($oid_str)
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my %hit_gene_names_h;
    my %hit_gene_locus_tag_h;
    for ( ; ; ) {
        my ( $hit_gene_oid, $hit_gene_locus_tag, $hit_gene_display_name ) = $cur->fetchrow();
        last if ( !$hit_gene_oid );
        $hit_gene_names_h{$hit_gene_oid}     = $hit_gene_display_name;
        $hit_gene_locus_tag_h{$hit_gene_oid} = $hit_gene_locus_tag;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $oid_str =~ /gtt_num_id/i );

    ## write YUI table
    my $it = new InnerTable( 1, "Homologs$$", "Homologs", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",           'num asc',  'left',  '', '' );
    $it->addColSpec( "Gene Name",         'char asc', 'left',  '', '' );
    $it->addColSpec( "Locus Tag",         'char asc', 'left',  '', '' );
    $it->addColSpec( "Percent Identity",  'num desc', 'right', '', '' );
    $it->addColSpec( "Homolog Gene ID",   'char asc', 'right', '', '' );
    $it->addColSpec( "Homolog Gene Name", 'char asc', 'left',  '', '' );

    my $cnt = 0;
    for my $hit_gene_oid (@hit_gene_oids) {

        # metagenome is homolog for isolate
        my $meta_homolog_workspace_id = $isolate_hit_genes_h{$hit_gene_oid};
        my ( $meta_homolog_taxon, $t2, $meta_homolog_gene ) = split( / /, $meta_homolog_workspace_id );

        my ( $hit_gene_oid2, $gene_perc, $meta_homolog_gene2, $copies ) =
          split( /\t/, $phylo_genes_h{$meta_homolog_workspace_id} );

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$hit_gene_oid' >\t";

        my $hit_gene_url = $main_cgi . "?section=GeneDetail" . "&page=geneDetail&gene_oid=$hit_gene_oid";
        $r .= $hit_gene_oid . $sd . alink( $hit_gene_url, $hit_gene_oid ) . "\t";

        my $gname = $hit_gene_names_h{$hit_gene_oid};
        $r .= $gname . $sd . WebUtil::escHtml($gname) . "\t";

        my $glocus = $hit_gene_locus_tag_h{$hit_gene_oid};
        $r .= $glocus . $sd . $glocus . "\t";

        $r .= $gene_perc . $sd . $gene_perc . "\t";

        my $homolog_gene_url = $main_cgi
          . "?section=MetaGeneDetail"
          . "&page=metaGeneDetail&gene_oid=$meta_homolog_gene"
          . "&taxon_oid=$meta_homolog_taxon&data_type=$t2";
        $r .= $meta_homolog_gene . $sd . alink( $homolog_gene_url, $meta_homolog_gene ) . "\t";

        my ( $homolog_gene_name, $source ) = MetaUtil::getGeneProdNameSource( $meta_homolog_gene, $meta_homolog_taxon, $t2 );
        $r .= $homolog_gene_name . $sd . WebUtil::escHtml($homolog_gene_name) . "\t";

        $it->addRow($r);
        $cnt++;
    }
    printEndWorkingDiv();

    printMainForm();

    WebUtil::printGeneCartFooter() if ( $cnt > 10 );
    $it->printOuterTable();
    WebUtil::printGeneCartFooter();

    printStatusLine( "Loaded.", 2 );
    print end_form();

}

sub printHomologMetagenomeTitle {
    my ( $dbh, $metag_taxon_oid, $data_type ) = @_;

    my $url = "$main_cgi?section=MetaDetail"
	    . "&page=metaDetail&taxon_oid=$metag_taxon_oid";
    print "<p style='width: 650px;'>";
    my $taxon_name    = QueryUtil::fetchTaxonName( $dbh, $metag_taxon_oid );
    my $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh,  $metag_taxon_oid );
    if ($isTaxonInFile) {
        $taxon_name .= " (MER-FS)";
        if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
            $taxon_name .= " ($data_type)";
        }
    }
    print "<u>Homolog Metagenome</u>: " . alink( $url, $taxon_name, "_blank" );
    print "</p>";

}

###############################################################################
# printIsolateGenomeDistribution_groups
## one single isolate genome, a number of metagenome,
###############################################################################
sub printIsolateGenomeDistribution_groups {
    my ( $dbh, $isolate_taxon_oid, $filter_clause, $filter_levels_aref, $itemLevel_href ) = @_;

    my $data_type = param("data_type");    # assembled or unassembled or both
    $data_type = param("r_data_type") if ( $data_type eq '' );
    my @metag_oids     = param('selectedGenome2');    # param("metagSelection");
    my $metag_filename = param("metag_filename");
    my ( $genomeHitsDir, $sessionId ) = WebUtil::getGenomeHitsDir();

    my $percent_identity = param("percent_identity");    # 30 or 60 or 90
    my $percentage_count = param("percentage_count");    # "suc" or "cum"
                                                         # "suc" means successive, 30-59,60-89,90+
                                                         # "cum" means cumulative, 30+,60+,90+

    my $plus = ( $percentage_count eq "cum" ) ? "+" : "";

    # display "+" if cumulative

    ## metagenome oids
    my $metag_filename_full;
    if ( @metag_oids ne 0 ) {                            # primary, write metag_oids to file
        $metag_filename      = "metag_oids_$sessionId";
        $metag_filename_full = "$genomeHitsDir/$metag_filename";
        my $wfh = newWriteFileHandle($metag_filename_full);
        print $wfh join( ",", @metag_oids );
        close $wfh;
    } elsif ($metag_filename) {                          # secondary, read metag_oids from file
        $metag_filename_full = "$genomeHitsDir/$metag_filename";
        unless ( -e $metag_filename_full ) {
            my $msg = "Data cannot be displayed. This page " . "must be viewed in the original brower session.";
            printMessage($msg);
            printStatusLine( "Loaded.", 2 );
            return;
        }
        my $rfh = newReadFileHandle($metag_filename_full);
        my $tmp = $rfh->getline();
        @metag_oids = split( /,/, $tmp );
        close $rfh;
    }

    my $filterLevel = "default";
    my %filter_h;
    my @filter_levels = @$filter_levels_aref;
    my %itemLevel_h   = %$itemLevel_href;
    for my $l (@filter_levels) {
        $filter_h{$l} = param( $l . "filter" );
        last if !( $filter_h{$l} );
        $filterLevel = $l;
    }
    #print "printIsolateGenomeDistribution_groups() filterLevel=$filterLevel<br/>\n";

    my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @metag_oids );

    my @binds_datatype;
    my $data_type_clause;
    if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
        $data_type_clause = " and dt.data_type = ? ";
        push( @binds_datatype, $data_type );
    }

    my $urclause  = urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
        select dt.taxon_oid, t.phylum, t.ir_class, t.ir_order, t.family, t.genus, t.species,
           sum(dt.gene_count_30), sum(dt.gene_count_60), sum(dt.gene_count_90)
        from taxon t, dt_phylo_taxon_stats dt
        where dt.homolog_taxon = ?
        and dt.taxon_oid in ($oid_str)
        and dt.taxon_oid = t.taxon_oid
        $data_type_clause
        $filter_clause
        $urclause
        $imgClause
        group by dt.taxon_oid, t.phylum, t.ir_class, t.ir_order, t.family, t.genus, t.species
    };

    #print "printIsolateGenomeDistribution_groups() sql: $sql<br/>\n";

    # NOTE: dt.gene_count_30 is the count of hit genes in the metagenome,
    # not the count of hit genes in the homolog (isolate) genome

    my %lines_h;
    my %found_h;
    my %cnt30;
    my %cnt60;
    my %cnt90;
    my %genome30;
    my %genome60;
    my %genome90;

    my $cur = execSql( $dbh, $sql, $verbose, $isolate_taxon_oid, @binds_datatype );
    for ( ; ; ) {
        my ( $mtoid, $phylum, $ir_class, $ir_order, $family, $genus, $species, $c30, $c60, $c90 ) = $cur->fetchrow();
        last if ( !$mtoid );
        next if ( $c30 + $c60 + $c90 eq 0 );

        $lines_h{$mtoid} = "$c30\t$c60\t$c90";

        my $key = $phylum;
        for my $l (@filter_levels) {
            last if !( $filter_h{$l} );
            if ( $l eq "phylum" ) {
                $key .= "\t" . $ir_class;
            } elsif ( $l eq "ir_class" ) {
                $key .= "\t" . $ir_order;
            } elsif ( $l eq "ir_order" ) {
                $key .= "\t" . $family;
            } elsif ( $l eq "family" ) {
                $key .= "\t" . $genus;
            } elsif ( $l eq "genus" ) {
                $key .= "\t" . $species;
            }
        }

        # initialize
        $found_h{$key}  = 0 unless ( $found_h{$key} );
        $cnt30{$key}    = 0 unless ( $cnt30{$key} );
        $cnt60{$key}    = 0 unless ( $cnt60{$key} );
        $cnt90{$key}    = 0 unless ( $cnt90{$key} );
        $genome30{$key} = 0 unless ( $genome30{$key} );
        $genome60{$key} = 0 unless ( $genome60{$key} );
        $genome90{$key} = 0 unless ( $genome90{$key} );

        # count hit genes
        if ($c30) {
            $cnt30{$key} += $c30;
        }
        if ($c60) {
            $cnt60{$key} += $c60;
            if ( $percentage_count eq "cum" ) {
                $cnt30{$key} += $c60;
            }
        }
        if ($c90) {
            $cnt90{$key} += $c90;
            if ( $percentage_count eq "cum" ) {
                $cnt30{$key} += $c90;
                $cnt60{$key} += $c90;
            }
        }

        # count hit metagenomes
        $genome90{$key} += 1 if ($c90);
        if ( $percentage_count eq "suc" ) {
            $genome60{$key} += 1 if ($c60);
            $genome30{$key} += 1 if ($c30);
        } else {
            $genome60{$key} += 1 if ( $c60 or $c90 );
            $genome30{$key} += 1 if ( $c30 or $c60 or $c90 );
        }

        ## count total number of metagenomes in each category in the db
        ## taxon table that have at least 1 hit to the isolate taxon
        $found_h{$key} += 1 if ( $c30 or $c60 or $c90 );

    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $oid_str =~ /gtt_num_id/i );

    if ( scalar( keys %found_h ) == 0 ) {
        printMessage("No hits found.");
        printStatusLine( "Loaded.", 2 );
        return;
    }

    my $isMetagenomeList = "No";
    if (   $itemLevel_h{$filterLevel} eq "Metagenomes"
        || $percent_identity ne "" )
    {
        $isMetagenomeList = "Yes";
    }

    my $it;
    if ( $isMetagenomeList eq "Yes" ) {
        $it = new InnerTable( 1, "hitMetagenomes$$", "hitMetagenomes$$", 0 );
        $it->addColSpec("Select");
        $it->addColSpec( "Homolog Metagenome ID",              'num assc', 'left',  '', '' );
        $it->addColSpec( "Metagenome Name",                    'char asc', 'left',  '', '' );
        $it->addColSpec( "Number of 30%$plus hits<br> (est.)", 'num desc', 'right', '', '' );
        $it->addColSpec( "Number of 60%$plus hits<br> (est.)", 'num desc', 'right', '', '' );
        $it->addColSpec( "Number of 90%$plus hits<br> (est.)", 'num desc', 'right', '', '' );
    } else {
        $it = new StaticInnerTable();
        my $toolTip30 = $plus ? '30% and above' : '30% to 59%';
        my $toolTip60 = $plus ? '60% and above' : '60% to 89%';
        my $toolTip90 = $plus ? '90% and above' : '90% to 99%';
        my $toolTipAll = "Total number of metagenomes, including those " . "having no hits to this single genome.";
        $it->addColSpec( $itemLevel_h{$filterLevel},                     '', 'left',  '', '' );
        $it->addColSpec( "No. Of Metagenomes<br>(Hits 30%$plus)",        '', 'right', '', $toolTip30 );
        $it->addColSpec( "No. Of Metagenomes<br>(Hits 60%$plus)",        '', 'right', '', $toolTip60 );
        $it->addColSpec( "No. Of Metagenomes<br>(Hits 90%$plus)",        '', 'right', '', $toolTip90 );
        $it->addColSpec( "No. Of Metagenomes<br>(with or without hits)", '', 'right', '', $toolTipAll );
    }

    my $sd = $it->getSdDelim();    # sort delimiter

    # URL
    my $outputType = param("outputtype");
    my $baseUrl    =
        "$main_cgi?section=$section&page=hits"
      . "&outputtype=$outputType"
      . "&taxon_oid=$isolate_taxon_oid"
      . "&data_type=$data_type"
      . "&percentage_count=$percentage_count";

    my $cnt = 0;
    if ( $isMetagenomeList eq "Yes" ) {
        my @mtoids = keys %lines_h;
        my %taxon_name_h = QueryUtil::fetchTaxonOid2NameHash( $dbh, \@mtoids );
        for my $mtoid (@mtoids) {
            my $taxon_display_name = $taxon_name_h{$mtoid};
            my ( $c30, $c60, $c90 ) = split( /\t/, $lines_h{$mtoid} );

            # decide if this row should be printed or discarded
            my $keepThis = 0;
            if ( $percent_identity eq "" ) {
                $keepThis = 1;
            } elsif ( $percentage_count eq "suc" ) {
                $keepThis = 1
                  if ( ( $percent_identity eq "30" && $c30 > 0 )
                    || ( $percent_identity eq "60" && $c60 > 0 )
                    || ( $percent_identity eq "90" && $c90 > 0 ) );
            } elsif ( $percentage_count eq "cum" ) {
                my $c30p = $c30 + $c60 + $c90;
                my $c60p = $c60 + $c90;
                $keepThis = 1
                  if ( ( $percent_identity eq "30" && $c30p > 0 )
                    || ( $percent_identity eq "60" && $c60p > 0 )
                    || ( $percent_identity eq "90" && $c90 > 0 ) );
            }

            if ( $keepThis eq 1 ) {
                my $url  = $main_cgi . "?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=" . $mtoid;
                my $url2 = $baseUrl . "&metag_taxon_oid=$mtoid" . "&listtype=gene";

                my $r;
                $r .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$mtoid' />\t";
                $r .= $mtoid . $sd . alink( $url, $mtoid ) . "\t";
                $r .= $taxon_display_name . $sd . WebUtil::escHtml($taxon_display_name) . "\t";
                $r .= $c30 . $sd . alink( $url2 . "&percent_identity=30", $c30 ) if ( $c30 > 0 );
                $r .= "\t";
                $r .= $c30 . $sd . alink( $url2 . "&percent_identity=60", $c60 ) if ( $c60 > 0 );
                $r .= "\t";
                $r .= $c30 . $sd . alink( $url2 . "&percent_identity=90", $c90 ) if ( $c90 > 0 );
                $r .= "\t";

                $it->addRow($r);
                $cnt++;
            }
        }
    } else {
        $baseUrl .= "&metag_filename=$metag_filename";

        my @taxonomies = sort( keys(%found_h) );
        for my $key (@taxonomies) {
            my ( $phylum, $ir_class, $ir_order, $family, $genus, $species ) = split( /\t/, $key );
            my $baseUrl2 = $baseUrl;
            for my $l (@filter_levels) {
                $baseUrl2 .= "&" . $l . "filter=";
                if ( $l eq "phylum" ) {
                    $baseUrl2 .= WebUtil::massageToUrl2($phylum);
                } elsif ( $l eq "ir_class" ) {
                    $baseUrl2 .= WebUtil::massageToUrl2($ir_class);
                } elsif ( $l eq "ir_order" ) {
                    $baseUrl2 .= WebUtil::massageToUrl2($ir_order);
                } elsif ( $l eq "family" ) {
                    $baseUrl2 .= WebUtil::massageToUrl2($family);
                } elsif ( $l eq "genus" ) {
                    $baseUrl2 .= WebUtil::massageToUrl2($genus);
                } elsif ( $l eq "species" ) {
                    $baseUrl2 .= WebUtil::massageToUrl2($species);
                }
            }
            my $groupUrl = "$baseUrl2&listtype=group";

            my $r;
            my $category_name;
            if ( $filterLevel eq "default" ) {
                $category_name = $phylum;
            } elsif ( $filterLevel eq "phylum" ) {
                $category_name = $ir_class;
            } elsif ( $filterLevel eq "ir_class" ) {
                $category_name = $ir_order;
            } elsif ( $filterLevel eq "ir_order" ) {
                $category_name = $family;
            } elsif ( $filterLevel eq "family" ) {
                $category_name = $genus;
            } elsif ( $filterLevel eq "genus" ) {
                $category_name = $species;
            }
            $r .= alink( $groupUrl, $category_name ) . "\t";

            ## 30
            if ( $cnt30{$key} ) {
                $r .= alink( "$groupUrl&percent_identity=30", $genome30{$key} );
                $r .= " (" . $cnt30{$key} . ")";
            } else {
                $r .= "&nbsp;";
            }
            $r .= "\t";

            ## 60
            if ( $cnt60{$key} ) {
                $r .= alink( "$groupUrl&percent_identity=60", $genome60{$key} );
                $r .= " (" . $cnt60{$key} . ")";
            } else {
                $r .= "&nbsp;";
            }
            $r .= "\t";

            ## 90
            if ( $cnt90{$key} ) {
                $r .= alink( "$groupUrl&percent_identity=90", $genome90{$key} );
                $r .= " (" . $cnt90{$key} . ")";
            } else {
                $r .= "&nbsp;";
            }
            $r .= "\t";

            ## no of total genomes
            $r .= getPhyloMetagenomeTotalCount( $dbh, $filter_clause, $urclause, $imgClause, $key );
            $r .= "\t";

            $it->addRow($r);
        }
    }

    printMainForm();

    if ( $isMetagenomeList eq "Yes" ) {
        WebUtil::printGenomeCartFooter() if ( $cnt > 10 );
        $it->printOuterTable();
        WebUtil::printGenomeCartFooter();
    } else {
        $it->printOuterTable();
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

sub getPhyloMetagenomeTotalCount {
    my ( $dbh, $filter_clause, $urclause, $imgClause, $key ) = @_;

    my ( $phylum, $ir_class, $ir_order, $family, $genus, $species ) = split( /\t/, $key );

    my $phylo_clause;
    my @binds;
    if ($phylum) {
        $phylo_clause .= " and t.phylum = ? ";
        push( @binds, $phylum );

        if ($ir_class) {
            $phylo_clause .= " and t.ir_class = ? ";
            push( @binds, $ir_class );

            if ($ir_order) {
                $phylo_clause .= " and t.ir_order = ? ";
                push( @binds, $ir_order );

                if ($family) {
                    $phylo_clause .= " and t.family = ? ";
                    push( @binds, $family );

                    if ($genus) {
                        $phylo_clause .= " and t.genus = ? ";
                        push( @binds, $genus );

                        if ($species) {
                            $phylo_clause .= " and t.species = ? ";
                            push( @binds, $species );
                        }
                    }
                }
            }
        }
    }

    my $sql = qq{
       select count(distinct t.taxon_oid)
       from taxon t
       where t.genome_type = ?
       $phylo_clause
       $filter_clause
       $urclause
       $imgClause
    };

    #print "getPhyloMetagenomeTotalCount() key: $key<br/>\n";
    #print "getPhyloMetagenomeTotalCount() sql: $sql<br/>\n";
    #print "getPhyloMetagenomeTotalCount() binds: @binds<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, 'metagenome', @binds );
    my ($count) = $cur->fetchrow();
    $cur->finish();

    return $count;
}

###########################################################################

1;
