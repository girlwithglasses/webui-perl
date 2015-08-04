###########################################################################
# RadialPhyloTree.pm - draws a radial phylogenetic tree as seen on MG-RAST
# $Id: RadialPhyloTree.pm 33566 2015-06-11 10:47:36Z jinghuahuang $
############################################################################
package RadialPhyloTree;
my $section = "RadialPhyloTree";
my $page;

use strict;
use CGI qw( :standard);
use Data::Dumper;
use WebConfig;
use WebUtil;
use RadialTree;    # module that creates the tree graphic
use Storable;
use MetaUtil;
use HtmlUtil;
use JSON;
use GenomeListJSON;

$| = 1;

my $env                 = getEnv();
my $cgi_dir             = $env->{cgi_dir};
my $cgi_url             = $env->{cgi_url};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};
my $tmp_url             = $env->{tmp_url};
my $tmp_dir             = $env->{tmp_dir};
my $main_cgi            = $env->{main_cgi};
my $verbose             = $env->{verbose};
my $base_url            = $env->{base_url};
my $base_dir            = $env->{base_dir};
my $YUI                 = $env->{yui_dir_28};
my $include_metagenomes = $env->{include_metagenomes};
my $web_data_dir        = $env->{web_data_dir};

my $hideViruses   = getSessionParam("hideViruses");
my $hidePlasmids  = getSessionParam("hidePlasmids");
my $hideGFragment = getSessionParam("hideGFragment");
$hideViruses   = "Yes" if !$hideViruses;
$hidePlasmids  = "Yes" if !$hidePlasmids;
$hideGFragment = "Yes" if $hideGFragment eq "";

my $mer_data_dir = $env->{mer_data_dir};
my $in_file      = $env->{in_file};

my $tree_htmlfile = "RadialPhyloTree.html";    # must be prepended with $base_dir

# Tree default settings in Customize button
my $TREE_TITLE_WIDTH   = 150;
my $TREE_DIAMETER      = 800;
my $TREE_GRAPH_SIZE    = 20;
my $TREE_NODE_DIA      = 6;
my $TREE_RADIAL_LENGTH = 20;

# Tree setting bounds and message text
my %treeParam = (
    titleWidth => {
        text => "Title space (outer colored ring) width",
        min  => 80,
        max  => 300,
        val  => $TREE_TITLE_WIDTH
    },
    treeDia => {
        text => "Diameter of the tree",
        min  => 600,
        max  => 2000,
        val  => $TREE_DIAMETER
    },
    graphSize => {
        text => "Stacked/Bar graph size",
        min  => 10,
        max  => 100,
        val  => $TREE_GRAPH_SIZE
    },
    nodeDia => {
        text => "Node junction diameter",
        min  => 4,
        max  => 30,
        val  => $TREE_NODE_DIA
    }
);

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    my $sid = getContactOid();

    if ( paramMatch("runTree") || paramMatch("viewBy") ) {
        HtmlUtil::cgiCacheInitialize($section);
        HtmlUtil::cgiCacheStart() or return;

        runTree();

        HtmlUtil::cgiCacheStop();

    } elsif ( paramMatch("exportTreeData") ne "" ) {
        exportTreeData();
    } elsif ( paramMatch("exportTree") ne "" ) {
        exportTree();
    } else {
        printForm($numTaxon);
    }
}

sub printForm {
    my ($numTaxon) = @_;

    #printStatusLine( "Loading ...", 1 );

    printHeader();
    printMainForm();
    print "<p>\n";

=temporary, wait until genome vs metagenome radial tree is in place -- yjlin
    if ($include_metagenomes) {
        print "Distribution type: ";
        print qq{
    <select name="type" style="width:16em">
    <option value="genome">Metagenomes vs All Genomes</option>
    <option value="metagenome">Genomes vs All Metagenomes</option>
    </select>
    <br/><br/>
        };
    }
=cut

    if ($include_metagenomes) {
        print "Please select up to 5 samples or genomes for distribution:<br/>";
    } else {
        print "Please select up to 5 genomes for distribution:<br/>";
    }

    printMainJS();

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ( $hideViruses eq "" || $hideViruses eq "Yes" ) ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ( $hidePlasmids eq "" || $hidePlasmids eq "Yes" ) ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ( $hideGFragment eq "" || $hideGFragment eq "Yes" ) ? 0 : 1;

    my $cgi_url = $env->{cgi_url};
    my $xml_cgi = $cgi_url . '/xml.cgi';

    my $template = HTML::Template->new( filename => "$base_dir/genomeJsonOneDiv.html" );
    $template->param( isolate      => 1 );
    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( all          => 1 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => 5 );

    if ($include_metagenomes) {
        $template->param( include_metagenomes => 1 );
        $template->param( selectedAssembled1  => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;

    my $name = "_section_RadialPhyloTree_runTree";
    GenomeListJSON::printHiddenInputType( $section, 'runTree' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
    ( 'go', $name, 'Generate Tree',
      '', $section, 'runTree', 'meddefbutton', 'selectedGenome1', 1 );
    print $button;
    print nbsp(1);
    print end_form();
    GenomeListJSON::showGenomeCart($numTaxon);

}

sub printHeader {
    print "<script src='$base_url/overlib.js'></script>\n";
    my $header = "Radial Tree Distribution";
    my $curl   = "http://www.biomedcentral.com/1471-2105/9/386";
    my $text   =
        "The <b>Radial Phylogenetic Tree</b> is supplied "
      . "with the help of: <br/>"
      . "Meyer F, Paarmann D, DSouza M, Olson R, Glass EM, "
      . "Kubal M, Paczian T, Rodriguez A, Stevens R, Wilke A, "
      . "Wilkening J, Edwards RA: <br/>"
      . "<u>The Metagenomics RAST server</u> - A public resource "
      . "for the automatic phylogenetic and functional analysis "
      . "of metagenomes.<br/>"
      . "<i>BMC Bioinformatics 2008, 9:386.</i><br/>"
      . "<a href=$curl target=_blank>$curl</a>";

    WebUtil::printHeaderWithInfo( $header, $text, "show citation for this tool", "Citation", 0 );
}

############################################################################
# runTree - creates the circular phylogenetic tree for selected genomes
############################################################################
sub runTree {
    my @oids = param("selectedGenome1");
    my %tree_hash_ref;

    my $data_type = param("q_data_type");    # assembled or unassembled or both
    my $viewBy    = param("viewBy");
    my $graphType = param("graph");

    my $do_bodysites   = param("bodysites");
    my $do_meth_motifs = param("meth_motifs");
    my $domain         = param("domain");

    if ($do_bodysites) {
        @oids = ( "Airways", "Oral", "Gastrointestinal tract", 
		  "Skin", "Urogenital tract" );
        $viewBy    = "phylum" if !$viewBy;
        $graphType = "bar"    if !$graphType;

    } elsif ($do_meth_motifs) {
        @oids      = param("motifs_txm");
        $viewBy    = "family" if !$viewBy;
        $graphType = "bar" if !$graphType;
    }

    my $colorBy       = param("colorBy");
    my $titleWidth    = param("titleWidth");
    my $treeDia       = param("treeDia");
    my $graphSize     = param("graphSize");
    my $nodeDia       = param("nodeDia");
    my $statsId       = param("id");
    my $type          = param("type");
    my $exportSection = $section;

    $viewBy = "family" if !$viewBy;
    $colorBy    = $type eq "metagenome" ? "class" : "phylum" if !$colorBy;
    $graphType  = "stack"                                    if !$graphType;
    $titleWidth = $treeParam{titleWidth}{val}                if !$titleWidth;
    $treeDia    = $treeParam{treeDia}{val}                   if !$treeDia;
    $graphSize  = $treeParam{graphSize}{val}                 if !$graphSize;
    $nodeDia    = $treeParam{nodeDia}{val}                   if !$nodeDia;

    $type    = "genome"         if !$type;
    $section = param("section") if paramMatch("section");
    $page    = param("page")    if paramMatch("page");

    # show a bar (instead of stack) when only one genome is analyzed
    $graphType = "bar" if ( scalar @oids == 1 );
    my %level = (
        domain => 1,
        phylum => 2,
        order  => 3,
        family => 4
    );

    # Include ir_class for microbiomes
    %level = (
        domain => 1,
        phylum => 2,
        class  => 3,
        order  => 4,
        family => 5
      )
      if ( $type eq "metagenome" );

    if ( scalar(@oids) <= 0 ) {
        webError("Please select at least 1 item");
    }

    printHeader();
    my $hint =
        "To include <b>Viruses</b>, <b>Plasmids</b>, "
      . "or <b>GFragment</b>, go to "
      . "<a href=$main_cgi?section=MyIMG&page=preferences>"
      . "IMG Preferences</a>.";

    if (
        !$do_meth_motifs
        && (   $hideViruses eq "Yes"
            || $hidePlasmids  eq "Yes"
            || $hideGFragment eq "Yes" )
      )
    {
        printHint($hint);
        print "<br/>";
    }

    # If cached do not make db call
    my $file = "$cgi_tmp_dir/$statsId." . getSessionId() . ".treestats";
    my @names;
    if ( $statsId && -e $file ) {
        my $geneStats = retrieve($file);
        %tree_hash_ref = %{ $geneStats->{stats_ref} };
        @names         = @{ $geneStats->{names} };
    } else {
        if ($do_bodysites) {
            @names = @oids;
            readAllBodySiteCounts( \%tree_hash_ref );
        } elsif ($do_meth_motifs) {
            @names = @oids;
            $statsId = getMethylationMotifCounts( \@oids, \%tree_hash_ref, $type, $domain );
        } else {
            $statsId = getGeneCounts( \@oids, \%tree_hash_ref, \@names, $type, $data_type );
        }
    }

    #print "runTree() type: $type, names: @names<br/>\n";

    my @lineage   = sort( keys(%tree_hash_ref) );
    my @phyloData = ();
    my $i         = 0;

    while ( $i < @lineage ) {
        my @phylogeny = split( /\t/, $lineage[$i] );

        # use unpadded values to create keys,
        # do not put this after the pad functions
        my ( $domain, $phylum, $class, $order, $family, $taxon_oid ) = @phylogeny;
        my $tree_hash_key_lineage = "$domain\t$phylum\t$class\t$order\t$family";

        # Last array element (taxon_oid) should remain untouched
        # So send array slice of all but last element to the pad functions
        if ( $type eq "metagenome" ) {
            padLineage( @phylogeny[ 0 .. $#phylogeny - 1 ] );
        } else {
            padUnclassifieds( @phylogeny[ 0 .. $#phylogeny - 1 ] );
        }

        # use padded values for display,
        # do not put this before the pad functions
        my ( $domain, $phylum, $class, $order, $family, $taxon_oid_junk ) = @phylogeny;

        # If non-microbiome, use non-blank ir_class for phylum
        if ( $type ne "metagenome" ) {
            $phylum = $class if ( $class ne "" );
        }

        # Prefix for plasmids
        my $p = "Plasmid:" if ( $domain =~ /plasmid/i );
        my @cur_dpc = ( $domain, $p . $phylum, $p . $order, $p . $family );

        # Microbiome needs ir_class but not plasmid prefix
        @cur_dpc = ( $domain, $phylum, $class, $order, $family )
          if ( $type eq "metagenome" );
        my @hits = ();
        foreach my $id (@oids) {
            my $key = "$tree_hash_key_lineage\t$id";
            my $cnt = $tree_hash_ref{$key} * 1;
            push @hits, $cnt;
        }
        $i = $i + scalar(@oids);
        push @cur_dpc,   [@hits];
        push @phyloData, [@cur_dpc];
    }

    my $leaf_cnt      = scalar(@phyloData);
    my $newTitleWidth = int( $leaf_cnt / 3 * 2 );
    my $newTreeDia    = int( $newTitleWidth * 5 );

    unless ( paramMatch("treeDia") ) {
        $titleWidth = $newTitleWidth if ( $newTitleWidth >= $TREE_TITLE_WIDTH );
        $treeDia    = $newTreeDia    if ( $newTreeDia >= $TREE_DIAMETER );
    }

    # Limit calculated titleWidth, and treeDia to maximums
    $titleWidth = $treeParam{titleWidth}{max}
      if ( $titleWidth > $treeParam{titleWidth}{max} );
    $treeDia = $treeParam{treeDia}{max}
      if ( $treeDia > $treeParam{treeDia}{max} );

    $treeDia = $titleWidth * 4
      if ( $treeDia < $titleWidth * 4 );

    # Set a reasonable radial line length
    my $totPhyloLevel = scalar keys %level;    # depth of phylogeny
    my $curPhyloLevel = $level{$viewBy};       # depth of phylogeny

    my $radialLength = int( ( $treeDia / 2 - $titleWidth - $graphSize ) / $curPhyloLevel - $nodeDia );
    $radialLength = $TREE_RADIAL_LENGTH
      if ( $radialLength < $TREE_RADIAL_LENGTH );

    # dump treestats data into a text file for user download.
    my $dataFile = "$cgi_tmp_dir/$statsId." . getSessionId() . ".treestats.text";
    $Data::Dumper::Terse = 1;
    my $wfh = newWriteFileHandle( $dataFile, "runTree" );
    print $wfh "Taxon Names: @names \n\n";
    for my $line (@phyloData) {
        print $wfh ( Dumper $line );
    }
    close $wfh;
    webLog("Write treestats data file in text format to file ($dataFile).\n");

    $treeParam{titleWidth}{val} = $titleWidth;
    $treeParam{treeDia}{val}    = $treeDia;
    $treeParam{graphSize}{val}  = $graphSize;
    $treeParam{nodeDia}{val}    = $nodeDia;

    my @treeSettings = ( $viewBy, $colorBy, $graphType, $radialLength );
    printTreeHTML( \@oids, \@treeSettings, $statsId, $type, $domain );

    use TabHTML;
    TabHTML::printTabAPILinks("phylotreeTab");
    my @tabIndex = ( "#treetab1",   "#treetab2" );
    my @tabNames = ( "Radial Tree", "Export" );
    TabHTML::printTabDiv( "phylotreeTab", \@tabIndex, \@tabNames );

    my $viewByText;
    my $colorByText;

    if ( $type eq "metagenome" ) {

        # Different drop down menu options in "Customize" button for microbiome
        my %metagLabel = (
            domain => "Ecosystem",
            phylum => "Ecosystem Category",
            class  => "Ecosystem Type",
            order  => "Ecosystem Subtype",
            family => "Specific Ecosystem"
        );
        $viewByText  = $metagLabel{$viewBy};
        $colorByText = $metagLabel{$colorBy};
    } else {
        $viewByText  = $viewBy;
        $colorByText = $colorBy;
    }

    print "<div id='treetab1'>";

    my $numHits    = @phyloData;
    my $domain_str = "";
    $domain_str = "*Showing stats for $domain only" if $domain ne "";
    if ($numHits) {
        print qq{
        <div style='width:577px'>
        <p>
        In the current view, the tree is rendered by <b>$viewByText</b> and
        colored by <b>$colorByText</b>. To change these settings, click on
        the <i>\"Customize Tree\"</i> button. Clicking on a node in the tree
        brings up the details for that node on the right of the tree. 
        $domain_str
        </p>
        </div>
        };
    } else {
        print "<p>";
    }

    # Get the same colors that the tree chooses for samples
    my $triplets = [ @{ WebColors::get_palette('excel') } ];

    print "<div style='border:2px solid #99ccff;
           padding:1px 5px;margin-left:1px;width:563px'>\n";
    print "<table width='100%'><tr><td>\n";
    print "<ol style='padding-left:15px;margin:0px;'>\n";
    foreach my $i ( 0 .. $#names ) {
        my $R = $triplets->[$i]->[0];
        my $G = $triplets->[$i]->[1];
        my $B = $triplets->[$i]->[2];
        print "<li style='padding-bottom:2px'>";    #if (@names > 1);
        print "<span id='tx$oids[$i]' style='border-left:10px ";
        print "solid rgb($R,$G,$B);";               #if (@names > 1);
        print "margin-right:5px;'></span>";
        print $names[$i];
        print "</li>";                              #if (@names > 1);
        print "\n";
    }
    print "\n</ol></td><td style='text-align:right'>";

    if ($numHits) {
        print button(
            -id    => "show",
            -value => "Customize Tree",
            -class => "smbutton",
        );
    }
    print "</td></tr></table></div>";

    # if no hits, print error message
    if ( !$numHits ) {
        printStatusLine("No hits");
        printMessage("No hits in this sample to draw a radial tree.");
        return;
    }

    print "<br/>";

    # Instantiate Phylogenetic Tree
    my $pt = RadialTree->new();
    $pt->data( [@phyloData] );

    # $pt->ttf('/soft/packages/fonts/Verdana.ttf');
    $pt->ttf('/usr/share/fonts/truetype/ttf-dejavu/DejaVuSans.ttf');
    $pt->sample_names( [@names] );
    $pt->leaf_weight_type($graphType);  # (bar-samples side by side | stack-samples stacked on each other)
    $pt->coloring_method('split');      # (abundance | split-one color for sample | difference | domain-one color per domain)
    $pt->show_leaf_weight(1);           # show or hide the stack or bar
    $pt->show_titles(1);                # show or hide text titles
    $pt->shade_titles( $level{$colorBy} );       # level of groups by which to color the outer ring
    $pt->enable_click(1);                        # show details upon clicking each junction
    $pt->title_space( $titleWidth * 2 );         # width of the outermost colored ring
    $pt->size($treeDia);                         # size of entire image
    $pt->depth( $level{$viewBy} );               # level to show: text in ring
    $pt->level_distance($radialLength);          # distance between each junction circle in radial line
    $pt->leaf_weight_space( $graphSize * 2 );    # size of the stacked/bar leaf
    $pt->color_leafs_only(1);                    # if 0, color radial lines as well
    $pt->node_size( $nodeDia * 2 );              # diameter of the junction circles in radial lines

    print $pt->output();

    ## write newick string into text files for user download.
    my $newickDir = "$cgi_tmp_dir/$statsId." . getSessionId() . ".newick";
    if ( $newickDir =~ /^(.*)$/ ) { $newickDir = $1; }    # bug fix untaint - ken
    my $newickFile1      = "newick_without_counts.txt";
    my $newickFile2      = "newick_with_counts.txt";
    my $newickFile1_path = "$newickDir/$newickFile1";
    my $newickFile2_path = "$newickDir/$newickFile2";
    my $newickZip        = "$newickDir/newick.zip";
    mkdir $newickDir;

    my $readme1;
    for my $n ( 1 .. @names ) {
        $readme1 .= "## TAXON No.$n - " . @names[ $n - 1 ] . "\n";
    }
    $readme1 .= "##\n";

    my $readme2 =
        "## The name of a Newick tree node consists of taxonomic rank and taxonomic\n"
      . "## name, joined by a dash ('-'). For example, 'family-Acidilobaceae' means\n"
      . "## that this is a 'family' node, and the family name is 'Acidilobaceae'.\n" . "##\n";

    my $readme3 =
        "## The string 'n1_n2_n3' following each Newick tree node indicates the number\n"
      . "## of hits from each of the user-chosen taxa. For example,\n"
      . "## 'family-Acidilobaceae:1_0_2' means that, 1 gene in the first taxon has\n"
      . "## hit(s) found in the Acidilobaceae family; 2 genes in the third taxon have\n"
      . "## hit(s) found in this family; No gene in the second taxon has any hit found\n"
      . "## in this family.\n" . "##\n";

    my $readme4 =
        "## Below is a string in Newick format. The string is broken into multiple\n"
      . "## lines to avoid having a very long line.\n" . "##\n";

    my $newick = $pt->getNewickString(0);                           # without counts
    my $wfh = newWriteFileHandle( $newickFile1_path, "runTree" );
    print $wfh $readme1 . $readme2 . $readme4;
    print $wfh $newick . "\n";
    close $wfh;
    webLog("Write newick string in text format to file ($newickFile1_path).\n");

    my $newick = $pt->getNewickString(1);                           # with counts
    my $wfh = newWriteFileHandle( $newickFile2_path, "runTree" );
    print $wfh $readme1 . $readme2 . $readme3 . $readme4;
    print $wfh $newick . "\n";
    close $wfh;
    webLog("Write newick string with counts in text format to file ($newickFile2_path).\n");

    use Archive::Zip;
    my $zip = Archive::Zip->new;
    $zip->addFile( $newickFile1_path, $newickFile1 );
    $zip->addFile( $newickFile2_path, $newickFile2 );
    $zip->writeToFileNamed($newickZip);
    webLog("Zip created ($newickZip).\n");

    ## Finish writing newick files

    printStatusLine( @oids . " sample(s) analyzed" );

    print "</div>";    # end treetab1

    # Print Export Tree section
    print "<div id='treetab2'>";
    print "<h2>Export Tree</h2>";

    # Form action xml.cgi since we'll be sending binary files to the browser
    print start_form( -name => "mainForm", -action => "xml.cgi" );
    print qq{
     <p>
     You may download the Radial Phylogenetic Tree in the image format of your choice:
     <select name="format" onMouseOver="updateToolTip(this)">
     <option value="png" title="Portable Network Graphics (.png)">PNG</option>
     <option value="gif" title="Graphics Interchange Format (.gif)">GIF</option>
     <option value="jpg" title="Joint Photographic Experts Group (.jpg)">JPEG</option>
     <option value="pdf" title="Portable Document Format (.pdf)">PDF</option>
     <option value="ps"  title="PostScript document (.ps)">PostScript</option>
     <option value="tif" title="Tagged Image File Format (.tif)">TIFF</option>
     </select>
     </p>
    };

    my $name = "_section_RadialPhyloTree_exportTree";
    my $contact_oid = WebUtil::getContactOid();
    print submit(
        -name  => $name,
        -value => "Export Tree Image",
        -class => "smbutton",
        -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button Export Tree Image']);"
    );

    # Save the tree for use by the export routine.
    # The tree object is saved to the file:
    #      "$cgi_tmp_dir/$$.$sessionId.radtree"
    # $pt->save() returns $$ which is saved as a hidden HTML form variable.
    # exportTree() builds the file path from this saved variable

    my $objTree = $pt->save();

    print hiddenVar( "section", $exportSection );
    print hiddenVar( "treeId",  $objTree );
    print hiddenVar( "id",      $statsId );

    print "<p>You may also download the data for this tree.</p>";
    my $name = "_section_RadialPhyloTree_exportTreeData";
    print submit(
        -name  => $name,
        -value => "Export Tree Data",
        -class => "smbutton",
        -onClick => "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img button Export Tree Data']);"
    );

    print end_form();

    print "</div>";    # end treetab2
    TabHTML::printTabDivEnd();
}

############################################################################
# padUnclassifieds - Append the label of immediate parent to levels
#                    labeled "unclassified" - for clarity and uniqueness.
#                                                           +BSJ 03/01/12
############################################################################
sub padUnclassifieds {
    my $curName;
    for my $rank (@_) {
        if ( lc($rank) eq "unclassified" ) {
            $rank = strTrim( "Unclassified " . $curName );
        } else {
            $rank = ucfirst($rank);
            $curName = $rank if $rank;
            $curName =~ s/unclassified//gi;
        }
    }
}

############################################################################
# padLineage - Append a hyphenated lineage using the first 3 characters
#              of each parent level. The circular tree requires unique
#              leaves at every level.
#                                                           +BSJ 03/01/12
############################################################################
sub padLineage {
    for ( my $i = 1 ; $i < @_ ; $i++ ) {
        $_[$i] .= " (";
        for ( my $j = 0 ; $j < $i ; $j++ ) {
            $_[$i] .= substr( $_[$j], 0, 3 ) . "-";
        }
        chop $_[$i];
        $_[$i] .= ")";
    }
}

sub readAllBodySiteCounts {
    my ($stats_ref)       = @_;
    my $web_data_dir      = $env->{webfs_data_dir};
    my $file              = $env->{all_bodysite_counts_file};
    my $all_bodysite_file = $web_data_dir . "hmp/$file";
    my $rfh               = newReadFileHandle($all_bodysite_file);
    while ( my $line = $rfh->getline() ) {
        next if $line =~ /^#/;
        my @a = split( /#/, $line );
        $stats_ref->{ @a[0] } = @a[1];
    }
}

sub getAllBodySiteGeneCounts {
    my ( $stats_ref, $body_sites ) = @_;
    my $dbh = dbLogin();

    my $virusClause = "and dt.domain not like 'Vir%'"
      if $hideViruses eq "Yes";
    my $plasmidClause = "and dt.domain not like 'Plasmid%'"
      if $hidePlasmids eq "Yes";
    my $gFragmentClause;
    $gFragmentClause = "and dt.domain not like 'GFragment%' "
      if $hideGFragment eq "Yes";

    @$body_sites = ( "Airways", "Oral", "Gastrointestinal tract", "Skin", "Urogenital tract" );

    my %lineage_hash;
    my %geneCounts;

    printStartWorkingDiv();
    for my $body_site (@$body_sites) {
        print "Querying for $body_site...<br/>";
        my $sub_sql = qq{
            select distinct t2.taxon_oid
            from env_sample_gold esg, taxon t2
            where t2.sample_gold_id = esg.gold_id
            and esg.host_name = 'Homo sapiens'
            and esg.body_site in ('$body_site')
        };

        my $rclause   = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');
        my $sql       = qq{  
            select dt.domain, dt.phylum, dt.ir_class, t.ir_order, t.family,
                   dt.taxon_oid, count (dt.taxon_oid)
 	    from dt_phylum_dist_genes dt, taxon t
	    where dt.homolog_taxon = t.taxon_oid
            and dt.taxon_oid in ($sub_sql)
            $rclause
            $imgClause
            $virusClause
            $plasmidClause
            $gFragmentClause
	    group by dt.domain, dt.phylum, dt.ir_class,
	    t.ir_order, t.family, dt.taxon_oid
        };

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $domain, $phylum, $ir_class, $ir_order, $family, $taxon, $cnt ) = $cur->fetchrow();
            last if !$domain;
            $ir_class = "";

            my $key = "$domain\t$phylum\t$ir_class\t$ir_order\t$family";
            $geneCounts{"$key\t$body_site"} = $cnt;
            $lineage_hash{$key} = 1;
        }
    }

    #$dbh->disconnect();
    printEndWorkingDiv();

    my @lineages = keys %lineage_hash;
    foreach my $site (@$body_sites) {
        foreach my $lineage (@lineages) {
            my $gCnt = $geneCounts{ $lineage . "\t" . $site };
            $gCnt = 0 if !$gCnt;
            $stats_ref->{ $lineage . "\t" . $site } = $gCnt;
        }
    }

    # Cache the gene count data and genome names to file
    my $geneStats = {};
    my $file      = "$cgi_tmp_dir/$$." . getSessionId() . ".treestats";
    $geneStats->{stats_ref} = $stats_ref;
    $geneStats->{names}     = $body_sites;
    store( $geneStats, $file );
    return $$;
}

############################################################################
# getMethylationMotifCounts
############################################################################
sub getMethylationMotifCounts {
    my ( $motifs_aref, $stats_ref, $type, $d ) = @_;

    my @motifs     = @$motifs_aref;
    my $motifs_str = WebUtil::joinSqlQuoted( ",", @motifs );

    my $dbh = dbLogin();

    my $domainClause = "";
    $domainClause = " and tx.domain = '$d' " if $d ne "";

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select m.motif_summ_oid, m.motif_string,
               m.n_detected, m.modification_type,
               tx.domain, tx.phylum, tx.ir_class,
               tx.ir_order, tx.family, tx.taxon_oid
        from meth_sample s, meth_motif_summary m, taxon tx
        where s.experiment = m.experiment
        and m.motif_string in ($motifs_str)
        and m.IMG_taxon_oid = tx.taxon_oid
        $rclause
        $imgClause
        $domainClause
        order by m.motif_summ_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my %lineage_hash;
    my %motifCounts;
    for ( ; ; ) {
        my ( $motif_oid, $motif_string, $n_detected, $m_type, $domain, $phylum, $ir_class, $ir_order, $family, $taxon_oid ) =
          $cur->fetchrow();
        last if !$motif_oid;
        $ir_class = "";

        my $key = "$domain\t$phylum\t$ir_class\t$ir_order\t$family";
        $motifCounts{"$key\t$motif_string"} = $n_detected;
        $lineage_hash{$key} = 1;
    }

    my @lineages = keys %lineage_hash;
    foreach my $m (@motifs) {
        foreach my $lineage (@lineages) {
            my $mCnt = $motifCounts{ $lineage . "\t" . $m };
            $mCnt = 0 if !$mCnt;
            $stats_ref->{ $lineage . "\t" . $m } = $mCnt;
        }
    }

    # Cache the count data and motifs (names) to file
    my $methStats = {};
    my $file      = "$cgi_tmp_dir/$$." . getSessionId() . ".treestats";
    $methStats->{stats_ref} = $stats_ref;
    $methStats->{names}     = $motifs_aref;
    store( $methStats, $file );
    return $$;
}

############################################################################
# getGeneCounts - get gene counts for selected genomes
############################################################################
sub getGeneCounts {
    my ( $taxon_oid_ref, $stats_ref, $taxon_names, $type, $data_type ) = @_;

    my $rclause;
    my $dbh = dbLogin();

    printStatusLine( "<font color='red'>This may take several minutes. "
          . "Please wait ... </font>\n<img src="
          . "'$base_url/images/ajax-loader.gif'>" )
      if ( $type eq "metagenome" );

    my ($taxon2name_href, $merfs_taxons_href, $taxon_db_href, $taxon_oid_str) 
        = QueryUtil::fetchTaxonsOidAndNameFile($dbh, $taxon_oid_ref);
    my @mer_fs_taxons = keys %$merfs_taxons_href;

    for my $taxon_oid (@$taxon_oid_ref) {
        my $taxon_display_name = $taxon2name_href->{$taxon_oid};
        if ( $merfs_taxons_href->{$taxon_oid} ) {
            $taxon_display_name .= " (MER-FS)";
            if ( $data_type =~ /assembled/i || $data_type =~ /unassembled/i ) {
                $taxon_display_name .= " ($data_type)";
            }
        }
        push( @$taxon_names, $taxon_display_name );
    }

    my $virusClause = "and dt.domain not like 'Vir%'"
      if $hideViruses eq "Yes";
    my $plasmidClause = "and dt.domain not like 'Plasmid%'"
      if $hidePlasmids eq "Yes";
    my $gFragmentClause;
    $gFragmentClause = "and dt.domain not like 'GFragment%' "
      if $hideGFragment eq "Yes";

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql;
    if ( $type eq "metagenome" ) {
        # Microbiome query
        $sql = qq{
            select t.phylum, t.ir_class, t.ir_order, t.family, t.genus,
                dt.homolog_taxon, count (dt.taxon_oid)
            from dt_phylum_dist_genes dt, gene g, taxon t, gene mg, taxon mt
            where  dt.gene_oid = mg.gene_oid 
            and dt.taxon_oid = mg.taxon
            and mg.taxon = mt.taxon_oid
            and dt.taxon_oid = mt.taxon_oid
            and mt.genome_type = 'metagenome'
            and dt.homolog = g.gene_oid
            and t.taxon_oid  = dt.taxon_oid
            and dt.homolog_taxon = g.taxon
            and g.taxon in ($taxon_oid_str)
            and dt.homolog_taxon in ($taxon_oid_str)
            $rclause
            $imgClause
            $virusClause
            $plasmidClause
            $gFragmentClause
            group by t.phylum, t.ir_class, t.ir_order, 
                t.family, t.genus, dt.homolog_taxon, dt.taxon_oid
        };
    } else {
        $sql = qq{
            select dt.domain, dt.phylum, dt.ir_class, t.ir_order, 
                t.family, dt.taxon_oid, count (dt.taxon_oid)
            from dt_phylum_dist_genes dt, taxon t
            where dt.taxon_oid in ($taxon_oid_str)
            and dt.homolog_taxon = t.taxon_oid
            $rclause
            $imgClause
            $virusClause
            $plasmidClause
            $gFragmentClause
            group by dt.domain, dt.phylum, dt.ir_class, 
                 t.ir_order, t.family, dt.taxon_oid
        };
    }
    my $cur = execSql( $dbh, $sql, $verbose );

    my %lineage_hash;
    my %geneCounts;
    for ( ; ; ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$domain;
        my $key1 = "$domain\t$phylum\t$ir_class\t$ir_order\t$family";
        my $key2 = "$key1\t$taxon_oid";
        if ( $type eq "metagenome" ) {
            $family = "Unclassified" if !strTrim($family);
            $family = ucfirst($family);

            # accumulate stats; no precomputed stats for microbiome
            $geneCounts{$key2} += $cnt;
        } else {
            $ir_class = "";    # needed only for non-microbiome phylogeny
            $geneCounts{$key2} = $cnt;
        }
        $lineage_hash{$key1} = 1;
    }
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $taxon_oid_str =~ /gtt_num_id/i );

    #print "geneCounts 1<br/>\n";
    #print Dumper \%geneCounts;
    #print "<br/>\n";

    # get gene counts for MER-FS taxons
    if ( scalar(@mer_fs_taxons) > 0 ) {
        $sql = qq{
    	    select distinct t.domain, t.phylum, t.ir_class,
    	    t.ir_order, t.family
    	    from taxon t
    	    where t.domain in ('Archaea', 'Bacteria', 'Eukaryota', 'Viruses')
    	    $rclause
    	    $imgClause
    	    order by 1, 2, 3, 5
	   };
        $cur = execSql( $dbh, $sql, $verbose );

        #print currDateTime() . "<br/>";
        WebUtil::printStartWorkingDiv();
        print "This may take a few minutes ...<br/><br/>\n";

        my @phylogeny;
        for ( ; ; ) {
            my ( $domain, $phylum, $ir_class, $ir_order, $family ) = $cur->fetchrow();
            last if !$domain;
            $ir_class = "";
            my $p = join( "\t", $domain, $phylum, $ir_class, $ir_order, $family );
            push( @phylogeny, $p );
        }

        for my $key (@mer_fs_taxons) {
            for my $p (@phylogeny) {
                print "&nbsp;&nbsp;processing $key and $p ...<br/>\n";
                my ( $domain, $phylum, $ir_class, $ir_order, $family ) = split( "\t", $p );
                my $p2 = "$p\t$key";
                my $cnt = MetaUtil::getPhyloGeneCounts( $key, $data_type, $domain, $phylum, $ir_class, $family );
                next if ( !$cnt );
                $geneCounts{$p2}  = $cnt;
                $lineage_hash{$p} = 1;
            }
        }

        WebUtil::printEndWorkingDiv();

        #print currDateTime() . "<br>";

        #print "geneCounts 2<br/>\n";
        #print Dumper \%geneCounts;
        #print "<br/>\n";
    }

    #$dbh->disconnect();

    my @lineage_list = keys %lineage_hash;
    for my $cur_taxon (@$taxon_oid_ref) {
        for my $cur_lineage (@lineage_list) {
            my $k    = "$cur_lineage\t$cur_taxon";
            my $gCnt = $geneCounts{$k};
            $gCnt = 0 if !$gCnt;
            $stats_ref->{$k} = $gCnt;
        }
    }

    # Cache the gene count data and genome names to file
    my $geneStats = {};
    my $file      = "$cgi_tmp_dir/$$." . getSessionId() . ".treestats";
    $geneStats->{stats_ref} = $stats_ref;
    $geneStats->{names}     = $taxon_names;
    store( $geneStats, $file );

    return $$;
}

############################################################################
# printMainJS - Prints required JavaScript for the form
############################################################################
sub printMainJS {
    print qq {
    <script type="text/javascript">
    function countSelections(maxFind) {
	var els = document.getElementsByTagName('input');
	var count = 0;
	for (var i = 0; i < els.length; i++) {
	    var e = els[i];
	    var name = e.name;

	    if (e.type == "radio" && e.checked == true
                && e.value == "find" && name.indexOf("profile") > -1) {
		count++;
		if (count > maxFind) {
		   alert("Please select no more than " + maxFind + " genomes");
		   return false;
		}
	    }
	}

        if (count < 1) {
           alert("Please select at least one genome");
           return false;
        }

        return true;
    }
    </script>
    };
}

############################################################################
# printTreeHTML - Prints required HTML & JavaScript for the Radial Tree
############################################################################
sub printTreeHTML {
    my ( $oids_ref, $curSettings, $statsId, $type, $domain ) = @_;
    my $do_bodysites   = param("bodysites");
    my $do_meth_motifs = param("meth_motifs");
    my $htmlTemplate   = "$base_dir/$tree_htmlfile";
    my $htmlStr        = file2Str($htmlTemplate);

    # Get current tree settings from settings array
    my ( $curViewBy, $curColorBy, $curGraphType, $curRadialLength ) = @$curSettings;

    my @customizeText;
    my @customizeValues;

    my $viewByName  = "viewBy";
    my $colorByName = "colorBy";

    my $dpc = qq{
	  <select id="__param__-id" name="__param__" onChange='setDropDowns("$viewByName", "$colorByName");'>
          <option value="domain">Domain</option>
          <option value="phylum">Phylum</option>
	  <option value="order">Order</option>
	  <option value="family">Family</option>
	  </select>
	  };

    $dpc = qq{
	  <select id="__param__-id" name="__param__" onChange='setDropDowns("$viewByName", "$colorByName");'>
          <option value="domain">Ecosystem</option>
          <option value="phylum">Ecosystem Category</option>
          <option value="class">Ecosystem Type</option>
	  <option value="order">Ecosystem Subtype</option>
	  <option value="family">Specific Ecosystem</option>
	  </select>
	  } if ( $type eq "metagenome" );

    # View by
    my $viewBy = $dpc;
    $viewBy =~ s/__param__/$viewByName/g;
    push @customizeText,   "Taxonomic rank to view by";
    push @customizeValues, $viewBy;

    # Color by
    my $colorBy = $dpc;
    $colorBy =~ s/__param__/$colorByName/g;
    push @customizeText,   "Color groups by";
    push @customizeValues, $colorBy;

    # Genome graph type
    # Stacked graph makes sense only with more than 1 genome
    if ( @$oids_ref > 1 && !$do_bodysites ) {
        push @customizeText,   "Sample weight graph type";
        push @customizeValues, qq{
	  <select name="graph">
          <option value="stack">Stacked</option>
          <option value="bar">Bar</option>
	  </select>
        };
    }

    # Get %treeParam values in the required order
    my @treeKeys = ( "titleWidth", "treeDia", "graphSize", "nodeDia" );

    for my $key (@treeKeys) {
        my $text = $treeParam{$key}{text};
        my $min  = $treeParam{$key}{min};
        my $max  = $treeParam{$key}{max};
        my $val  = $treeParam{$key}{val};
        push @customizeText,   "$text ($min - $max)";
        push @customizeValues, qq{
    <input type="textbox" name="$key" value="$val" maxLength="4" /> px
        };
    }

    # Use YUI css
    my $options = qq{
        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Parameter</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Setting</span>
	    </div>
	</th>
    };

    my $classStr;
    for ( my $idx = 0 ; $idx < @customizeText ; $idx++ ) {
        $classStr = $idx ? "" : "yui-dt-first ";
        $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";

        $options .= qq{
            <tr class='$classStr'>
	    <td class='$classStr' style='white-space:nowrap'>
	    <div class='yui-dt-liner'>
	    $customizeText[$idx]
	    </div></td>
	    <td class='$classStr'>
	    <div class='yui-dt-liner'>
	    $customizeValues[$idx]
	    </div></td></tr>
        };
    }
    $options .= "</table>\n</div>\n";

    # Add hidden variables to form
    $options .= hiddenVar( "section",     $section );
    $options .= hiddenVar( "page",        $page ) if $page;
    $options .= hiddenVar( "fromviewer",  "TreeFileMgr" );
    $options .= hiddenVar( "id",          $statsId );
    $options .= hiddenVar( "type",        $type );
    $options .= hiddenVar( "bodysites",   1 ) if $do_bodysites;
    $options .= hiddenVar( "meth_motifs", 1 ) if $do_meth_motifs;
    $options .= hiddenVar( "domain",      $domain ) if $do_meth_motifs;

    if ($do_meth_motifs) {
        for my $m (@$oids_ref) {
            $options .= hiddenVar( "motifs_txm", $m );
        }
    } else {
        for my $tx (@$oids_ref) {
            $options .= hiddenVar( "taxon_filter_oid", $tx );
            $options .= hiddenVar( "selectedGenome1", $tx );
            
        }
    }

    # Wider dropdown menu for metagenome
    my $dropDownWidth = ( $type eq "metagenome" ) ? "11em" : "8em";

    my $json = new JSON;
    $json->pretty;
    my $treeParamJSON = $json->encode( \%treeParam );

    # replace markers in HTML template
    $htmlStr =~ s/__base_url__/$base_url/g;
    $htmlStr =~ s/__main_cgi__/$main_cgi/g;
    $htmlStr =~ s/__section__/$section/g;
    $htmlStr =~ s/__yui_url__/$YUI/g;
    $htmlStr =~ s/__popup_content__/$options/g;
    $htmlStr =~ s/__viewBy_selection__/$curViewBy/g;
    $htmlStr =~ s/__colorBy_selection__/$curColorBy/g;
    $htmlStr =~ s/__graph__/$curGraphType/g;
    $htmlStr =~ s/__tree_param_json__/$treeParamJSON/g;
    $htmlStr =~ s/__dropdown_width__/$dropDownWidth/g;

    print $htmlStr;
}

############################################################################
# exportTree - get gene counts for selected genomes
############################################################################
sub exportTree {
    require Image::Magick;

    my $format    = param("format");
    my $id        = param("treeId");
    my $sessionId = getSessionId;
    my $objFile   = "$cgi_tmp_dir/$id.$sessionId.radtree";
    my $filename  = "Radialtree${id}.${format}";

    # Load the previously saved GD image object from file
    my $tree = retrieve($objFile);

    # Create a new PerlMagick object
    my $imObj = Image::Magick->new;
    my $mime  = $imObj->MagickToMime($format);

    # Print MIME type for this file
    print header(
        -type       => $mime,
        -attachment => $filename
    );

    # Use GD to output PNG, GIF and JPEG
    print $tree->png(0)    if ( $format eq "png" );
    print $tree->gif()     if ( $format eq "gif" );
    print $tree->jpeg(100) if ( $format eq "jpg" );

    # Use PerlMagick to convert PNG to
    #     PDF, TIFF, and PostScript
    if ( $format =~ /(pdf|tif|ps)/ ) {
        $imObj->Set( magick => 'png' );
        $imObj->BlobToImage( $tree->png(0) );
        binmode STDOUT;
        $imObj->Write(
            filename    => $format . ':-',
            compression => 'None',
            antialias   => 'True',
            density     => '300'
        );
    }
}

############################################################################
# exportTree - get gene counts for selected genomes
############################################################################
sub exportTreeData {
    my $id      = param("treeId");
    my $statsId = param("id");

    my $newickDir  = "$cgi_tmp_dir/$statsId." . getSessionId() . ".newick";
    my $newickZip  = "$newickDir/newick.zip";
    my $exportFile = "Radialtree${id}_newick.zip";

    my $rfh = newReadFileHandle($newickZip);
    binmode $rfh;
    my ( $n, $data, $buf );
    while ( ( $n = read $rfh, $data, 4 ) != 0 ) {
        $buf .= $data;
    }
    close $rfh;

    print "Content-type: application/text\n";
    print "Content-Disposition: attachment;filename=$exportFile\n\n";

    # use Archive::Zip;
    # my $zip = Archive::Zip->new;
    # $zip->addFile( $newickFile1, $newickFile2 );
    # $zip->writeToFileNamed($newickZip);
    binmode STDOUT;
    print $buf;
}

1;
