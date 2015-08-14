############################################################################
# Similar to gene Ortholog Neighborhood viewer, but instead of coloring via
# cog's we color genes within the same cassette box
#
# $Id: GeneCassette.pm 33981 2015-08-13 01:12:00Z aireland $
#
# When I say "query gene or query cassette" - I mean the initial gene from
# gene detail page.
#
#
# GeneDetails uses some of methods located here!
# - getPfamFunctions
# - getBBHFunctions
# - getCassetteOidViaGene
# - getProteinSelection
#
############################################################################
package GeneCassette;
my $section = "GeneCassette";
use strict;
use CGI qw( :standard );
use DBI;
use GeneCassettePanel;
use GeneCassettePanel2;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use PhyloTreeMgr;
use MetagenomeGraph;
use TaxonDetailUtil;
use GeneUtil;
use HtmlUtil;
use OracleUtil;
use QueryUtil;
use GraphUtil;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $tmp_url               = $env->{tmp_url};
my $tmp_dir               = $env->{tmp_dir};
my $verbose               = $env->{verbose};
my $web_data_dir          = $env->{web_data_dir};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $img_lite              = $env->{img_lite};
my $include_cassette_bbh  = $env->{include_cassette_bbh};
my $include_cassette_pfam = $env->{include_cassette_pfam};
my $user_restricted_site  = $env->{user_restricted_site};
my $img_ken               = $env->{img_ken};
my $img_edu                 = $env->{img_edu};
my $enable_biocluster       = $env->{enable_biocluster};

my $base_dir = $env->{base_dir};
my $base_url = $env->{base_url};

my $cog_base_url  = $env->{cog_base_url};
my $pfam_base_url = $env->{pfam_base_url};

my $flank_length     = 20000;
my $maxNeighborhoods = 15;
my $maxColors        = 246;

# find fusion  = 1, set to 0 to not search for fusion gene
# when 0 it will do find duplicate functions for a given gene
# see getFusionGenes()
# see printPlotViewer2()
# WE DO NOT NEED TO FIND FUSION - ALL CLUSTER IS IN bbh gene memeber table now
# should be set to 0 - 2008-04-09 - ken
my $FIND_FUSION = 0;

# this is the max number of genes to plot within a box
# there is a box with a big range only 17 cassette genes
# and there are 2000+ other genes within that range
# circular genes
my $MAX_BOX_GENES = 200;

# min number of genes in a cassette
# if set to 0 or less, its ignored
my $MIN_GENES = 1;

# when the gene has no function, make it "na$gene_oid"
# see getCogFunctions(),  getPfamFunctions(),
#  getBBHFunctions() and getGeneCassette()
my $NA = "na";

my $nvl = WebUtil::getNvl();

my $numTaxon;

############################################################################
# dispatch - Dispatch loop.
#
# My coding style - starting now param() is only called in the
# dispatch() method or the first method called from the dispatch()
# such that other methods are reusable.
# -Ken
sub dispatch {
    ($numTaxon) = @_;    # number of saved genomes
    my $sid  = getContactOid();
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 mins (from main.pl)

    if ( $page eq "geneCassette" ) {
        # plot the gene cassette's chromosomal viewer
        printNeighborhoods();
    } elsif ( $page eq "cassetteBox" ) {
        HtmlUtil::cgiCacheInitialize( $section );
        HtmlUtil::cgiCacheStart() or return;

        # user clicks cassette box
        printCassetteBoxDetails();

        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "viewer2" ) {
        printViewer2(0);
    } elsif ( $page eq "viewer3" ) {
        printViewer2(1);
    } elsif ( $page eq "phylo" ) {
        # phylo distribution
        printPhylogeneticDistribution();

        #} elsif ( $page eq "fusion" ) {

        # testing
        # http://localhost/~ken/cgi-bin/web25m.htd/
        # main.cgi?section=GeneCassette&page=fusion&gene_oid=640155307
        # 637982023
        # 640155307
        #        my $gene_oid = param("gene_oid");
        #        my $dbh      = dbLogin();
        #        my @genes;
        #        getFusionGenes( $dbh, $gene_oid, \@genes );
        #
        #        print Dumper \@genes;
        #        print "<br><br>\n";
        #        my $href = getBBHClusterId( $dbh, \@genes );
        #        print Dumper $href;
        #
        #        #$dbh->disconnect();
    } elsif ( $page eq "pathGeneList" ) {
        printPathwayGeneList();
    } elsif ( $page eq "cassetteList" ) {
        # used to print cassette list when there are more than $MAX_BOX_GENES
        # dump the cassette genes list
        printCassetteList();
    } elsif ( $page eq "occurrence" ) {
        printCassetteOccurrence();
    } elsif ( $page eq "occurrenceGeneList" ) {
        printOccurrenceGeneList();
    } else {
        # selection page instead of having 6 links in the gene detail page
        printCassetteMainPage();
    }
}

sub getNA {
    return $NA;
}

sub getMinGenes {
    return $MIN_GENES;
}

#
# Prints cassette list- used when cassette genes defined a very big region
# that inculdes more than X number of genes ($MAX_BOX_GENES)
#
sub printCassetteList {
    my $cassette_oid = param("cassette_oid");
    my $dbh          = dbLogin();
    my $type         = param("type");
    print "<h1>";
    print "Cassette Gene List";
    print "</h1>\n";

    print "<p>";
    print qq{
    Why am I here?<br>
    The cassette&#39;s genes defined a cassette box that included over $MAX_BOX_GENES
    genes.
    <br>This might be a &quot;circular genome&quot;.
    };
    print "</p>";

    printStatusLine("Loading ...");

    printMainForm();
    # return array ref - tab delimited arary of records
    # "$gene_oid\t$start_coord\t$end_coord\t$cog\t$scaffold\t$strand\t
    # $scaffold_name"
    my ( $data_aref, $min, $max ) = getCassetteData( $dbh, $cassette_oid, $type );

    WebUtil::printGeneCartFooter();
    my $it = new InnerTable( 1, "cassette$$", "cassette", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",     "number asc", "right" );
    $it->addColSpec( "Start Coord", "number asc", "right" );
    $it->addColSpec( "End Coord",   "number asc", "right" );
    $it->addColSpec( "Func. ID",    "number asc", "right" );
    $it->addColSpec( "Scaffold ID" );
    $it->addColSpec( "Strand" );
    $it->addColSpec( "Scaffold Name" );
    my $sd = $it->getSdDelim();    # sort delimit

    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    my $count = 0;
    my %distinctGenes;
    foreach my $line (@$data_aref) {
        my ( $gene_oid, $start_coord, $end_coord, $cog, $scaffold, $strand, $scaffold_name ) =
          split( /\t/, $line );
        my $r;

        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' />\t";
        $r .= $gene_oid . $sd . "<a href='" . $url . $gene_oid . "'> $gene_oid</a>" . "\t";

        $r .= $start_coord . $sd . "\t";
        $r .= $end_coord . $sd . "\t";
        $r .= $cog . $sd . "\t";
        $r .= $sd . $scaffold . "\t";
        $r .= $sd . $strand . "\t";
        $r .= $sd . $scaffold_name . "\t";

        $it->addRow($r);
        $count++;
        $distinctGenes{$gene_oid} = 1;
    }

    $it->printOuterTable(1);

    WebUtil::printGeneCartFooter();

    print end_form();
    my $size = keys %distinctGenes;
    printStatusLine( "$count Rows $size Genes Loaded", 2 );
    #$dbh->disconnect();
}

# print list of genes
# from a given cassette and pathway
#
sub printPathwayGeneList {
    my $cassette_oid = param("cassette_oid");
    my $pathway_oid  = param("pathway_oid");

    my $dbh = dbLogin();

    print "<h1>";
    print "Gene List";
    print "</h1>\n";

    printStatusLine("Loading ...");

    my $gene_list_aref = getCogPathwayGeneList( $dbh, $cassette_oid, $pathway_oid );

    my $url = "<a href='$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";
    my $it  = new InnerTable( 1, "pathwaylist$$", "pathwaylist", 1 );
    my $sd  = $it->getSdDelim(); # sort delimiter
    $it->addColSpec( "Gene ID",           "number asc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );

    my $ctr = 0;
    foreach my $line (@$gene_list_aref) {
        my ( $id, $name ) = split( /\t/, $line );
        my $r .= $id . $sd . $url . $id . "'>$id</a>\t";
        $r    .= $name;
        $it->addRow($r);
        $ctr++;
    }

    # only show page controls if mode that 20 (arbitrary) rows
    my $tblMode = ( $ctr > 20 ) ? 1 : "nopage";

    $it->printOuterTable($tblMode);

    my $cnt = $#$gene_list_aref + 1;
    printStatusLine( "$cnt Loaded", 2 );
    #$dbh->disconnect();
}

sub printCassetteMainPage {
    my $gene_oid = param("gene_oid");

    my $dbh = dbLogin();

    # see method getGeneViaCassetteOid() from my comments
    my $cassette_oid = param("cassette_oid");
    if ( $cassette_oid ne "" ) {
        $gene_oid = getGeneViaCassetteOid( $dbh, $cassette_oid, $gene_oid );
    }
    if ( $cassette_oid eq "" ) {
        $cassette_oid = getCassetteOidViaGene( $dbh, $gene_oid );
    }

    checkGenePerm( $dbh, $gene_oid );

    print "<h1>";
    print "Gene Chromosomal Cassette";
    print "</h1>\n";

    printStatusLine("Loading ...");

    my @gene_oid_list = ($gene_oid);
    my %fusion_hash;

    my $bbh_func_href = getBBHFunctions( $dbh, \@gene_oid_list, \%fusion_hash );
    my $pfam_func_href = getPfamFunctions( $dbh, \@gene_oid_list );
    my $cog_func_href  = getCogFunctions( $dbh,  \@gene_oid_list );

    my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    print "<table class='img'>\n";
    print "<tr class='img'>\n";
    print "<td class='img'>";
    print "Gene Cassette ID";
    print "</td>\n";
    print "<td class='img'>";
    print "$cassette_oid";
    print "</td>\n";
    print "<td class='img'>";
    print "&nbsp;";
    print "</td>\n";
    print "</tr>\n";

    my $cnt = 0;
    foreach my $funcId ( keys %$cog_func_href ) {
        next if ( $funcId =~ /^$NA/ );
        my $aref = $cog_func_href->{$funcId};
        foreach my $line (@$aref) {
            my ( $gene_oid, $name, $gene_name ) = split( /\t/, $line );

            if ( $cnt == 0 ) {
                print "<tr class='img'>\n";
                print "<td class='img'>";
                print "Gene ID";
                print "</td>\n";
                print "<td class='img'>";

                print "<a href='" . $gurl . $gene_oid . "'>  $gene_oid </a>";
                print "</td>\n";
                print "<td class='img'>";
                print "$gene_name";
                print "</td>\n";
                print "</tr>\n";
                $cnt = 1;
            }
            print "<tr class='img'>\n";
            print "<td class='img'>";
            print "COG ID";
            print "</td>\n";
            print "<td class='img'>";

            print "<a href='" . $cog_base_url . $funcId . "'>  $funcId </a>";
            print "</td>\n";
            print "<td class='img'>";
            print "$name";
            print "</td>\n";
            print "</tr>\n";
        }
    }

    foreach my $funcId ( keys %$pfam_func_href ) {
        next if ( $funcId =~ /^$NA/ );
        my $aref = $pfam_func_href->{$funcId};
        foreach my $line (@$aref) {
            my ( $gene_oid, $name, $gene_name ) = split( /\t/, $line );
            print "<tr class='img'>\n";
            print "<td class='img'>";
            print "Pfam ID";
            print "</td>\n";
            print "<td class='img'>";

            my $func_id2 = $funcId;
            $func_id2 =~ s/pfam/PF/;
            print "<a href='" . $pfam_base_url . $func_id2 . "'>  $funcId </a>";
            print "</td>\n";
            print "<td class='img'>";
            print "$name";
            print "</td>\n";
            print "</tr>\n";
        }
    }

    foreach my $funcId ( keys %$bbh_func_href ) {
        next if ( $funcId =~ /^$NA/ );
        my $aref = $bbh_func_href->{$funcId};
        foreach my $line (@$aref) {
            my ( $gene_oid, $name, $gene_name ) = split( /\t/, $line );
            print "<tr class='img'>\n";
            print "<td class='img'>";
            print "BBH ID";
            print "</td>\n";
            print "<td class='img'>";
            print "$funcId";
            print "</td>\n";
            print "<td class='img'>";
            print "$name";
            print "</td>\n";
            print "</tr>\n";
        }
    }

    print "</table>\n";

    print "<p>\n";
    print "<b>Gene Chromosome Viewer</b><br>\n";
    print "&nbsp;&nbsp;&nbsp;&nbsp;";
    print "<a href='main.cgi?section=GeneCassette&page=geneCassette"
	. "&gene_oid=$gene_oid&type=cog'>Cassette by <b>COG</b></a>";
    print "<br>\n";
    print "&nbsp;&nbsp;&nbsp;&nbsp;";
    print "<a href='main.cgi?section=GeneCassette&page=geneCassette"
	. "&gene_oid=$gene_oid&type=pfam'>Cassette by <b>PFam</b></a>";
    print "<br>\n";
    print "&nbsp;&nbsp;&nbsp;&nbsp;";
    print "<a href='main.cgi?section=GeneCassette&page=geneCassette"
	. "&gene_oid=$gene_oid&type=bbh'>Cassette by <b>BBH</b></a>";
    print "<br><br>\n";

    print "<b>Gene Cassette Details</b><br>\n";
    print "&nbsp;&nbsp;&nbsp;&nbsp;";
    print "<a href='main.cgi?section=GeneCassette&page=cassetteBox"
	. "&gene_oid=$gene_oid&type=cog'>Cassette Details by <b>COG</b></a>";
    print "<br>\n";
    print "&nbsp;&nbsp;&nbsp;&nbsp;";
    print "<a href='main.cgi?section=GeneCassette&page=cassetteBox"
	. "&gene_oid=$gene_oid&type=pfam'>Cassette Details by <b>PFam</b></a>";
    print "<br>\n";
    print "&nbsp;&nbsp;&nbsp;&nbsp;";
    print "<a href='main.cgi?section=GeneCassette&page=cassetteBox"
	. "&gene_oid=$gene_oid&type=bbh'>Cassette Details by <b>BBH</b></a>";
    print "<br>\n";
    print "</p>\n";

    printStatusLine( "Loaded", 2 );
    #$dbh->disconnect();
}

# Get a gene oid from a cassette oid
# Lets get any gene oid from a cassette box, such that my code
# works - isnce I'm using a gene centric view of things
# BUT is a gene_oid in the url will use that one
#
# param $dbh
# param $cassette_oid
# param $gene_oid
# return gene oid
sub getGeneViaCassetteOid {
    my ( $dbh, $cassette_oid, $gene_oid ) = @_;
    if ( $gene_oid ne "" ) {
        # now gene oid is given so just use it as the query gene
        return $gene_oid;
    }

    my $sql = qq{
      select gene
      from gene_cassette_genes
      where cassette_oid = ?
      order by 1
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cassette_oid );
    my ($a_gene_oid) = $cur->fetchrow();
    return $a_gene_oid;
}

# Gets cassette oid from a gene oid
# param $dbh
# param $gene_oid
# return cassette oid
sub getCassetteOidViaGene {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
      select cassette_oid
      from gene_cassette_genes
      where gene = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($oid) = $cur->fetchrow();
    $cur->finish();
    return $oid;
}

#
# gets type title or display name
#
sub getTypeTitle {
    my ($type) = @_;
    my $title = uc($type);

    if ( $type eq "bbh" ) {
        $title = "IMG Ortholog Cluster";
    } elsif ( $type eq 'bio' ) {
        $title = "Biosynthetic Cluster";
    }

    return $title;
}

# Print plots of cluster cluster count hits. It ONLY shows the ones
# with exactly those presents function ids to query cassette
# similar to printNeighborhoods()
# but only show the box genes
# view based on the absent and present table
#
# NOTE sometimes $cnt is bigger than number of plots eg if less than 20
# becuz some cassette have no scaffold
#
# IMPORTANT !!!!
# SORT here is important since its how I do the next page !!!!
# I also single quote the difference list of function ids
#
# param
#   $at_least 0 - show only present functions
#             1 - show at least those functions present
sub printViewer2 {
    my ($at_least) = @_;

    my $center_func_id = param("func_id");
    my $box_oid        = param("box_oid");
    my $type           = param("type");
    my $max            = param("max");
    my $page_index     = param("page_index");
    $page_index = 1 if $page_index eq "";

    # query cassette
    my $cassette_oid = param("cassette_oid");

    my $dbh = dbLogin();

    printMainForm();

    my $title = getTypeTitle($type);

    print "<h1>\n";
    print "Chromosomal Cassette By " . $title . "\n";
    print "</h1>\n";

    my $args = {
        id                 => "$$",
        start_coord        => 1,
        end_coord          => 10,
        coord_incr         => 1,
        title              => "a",
        strand             => "+",
        has_frame          => 1,
        gene_page_base_url => "",
        color_array_file   => $env->{large_color_array_file},
        tmp_dir            => $tmp_dir,
        tmp_url            => $tmp_url,
    };

    my $sp          = new GeneCassettePanel2($args);
    my @color_array = GraphUtil::loadColorArrayFile( $env->{large_color_array_file} );
    my $kcolor;    # is not a html color code
    if ( $type eq "pfam" ) {
        $kcolor = getPfamColorIndex( $sp, $center_func_id );
    } elsif ( $type eq "bbh" ) {
        $kcolor = getBBHColorIndex( $sp, $center_func_id );
    } else {
        $kcolor = getCogColorIndex( $sp, $center_func_id );
    }
    my $color2;
    if ( $kcolor < 0 ) {
        # -2 means its blues
        $color2 = sprintf( "#%02x%02x%02x", 0, 0, 255 );
    } else {
        my $color = $color_array[$kcolor];
        my ( $r, $g, $b ) = split( /,/, $color );
        $color2 = sprintf( "#%02x%02x%02x", $r, $g, $b );
    }
    print qq{
        <p>
        <table  border=0>
        <tr  border=0>
        <td  style='border-left:1em solid $color2'> &nbsp;
        Strand orientation by function <b>$center_func_id</b>
        </td>
        </tr>
        </table>
        </p>
    };
    $sp = "";

    if ( $type eq "bbh" ) {
        printHint( "Mouse over a gene to see details (once page has loaded).<br>"
                 . "Mouse over red box for fusion gene details.<br>"
                 . "Only genes with present $title are colored.<br>" );
        print "<br/>\n";
    } elsif ( $type eq "pfam" ) {
        printHint( "Mouse over a gene to see details (once page has loaded).<br>"
                 . "Mouse over red box for gene with multiple pfam details.<br>"
                 . "Only genes with present $title are colored." );
        print "<br/>\n";
    } else {
        printHint( "Mouse over a gene to see details (once page has loaded).<br>"
		 . "Only genes with present $title are colored." );
        print "<br/>\n";
    }

    printStatusLine( "Loading ...", 1 );

    print "<div id='working'>\n";
    print "<p>\n";

    # get all the func ids for query cassette
    # func id => ""
    print "Getting cassette $cassette_oid functions...<br>\n";
    my $all_functions_href = getClusterAllIds( $dbh, $cassette_oid, $type );

    # get all the func ids for a box
    # func id => ""
    print "Getting cassette box $box_oid functions...<br>\n";
    my $functions_href = getClusterIds( $dbh, $box_oid, $type );

    # now find the func ids diff = all func - box func ids
    # now i have a list of func ids to skip
    # can be empty
    my @diff_func_ids = ();
    foreach my $id ( keys %$all_functions_href ) {
        next if ( exists $functions_href->{$id} );

        # lets quote the data
        push( @diff_func_ids, $id );
    }

    # get all the cassettes for given box
    # the query cassette is not in the list
    print "Getting all cassettes with exact cluster count...<br>\n";
    my $cassettes_href;
    if ($at_least) {
        $cassettes_href = getCassettesViaBoxFunc2( $dbh, $box_oid, $type, $cassette_oid );
    } else {
        $cassettes_href = getCassettesViaBoxFunc( $dbh, $box_oid, $type, \@diff_func_ids, $cassette_oid );
    }

    # I should cache or out this value in the url for next page
    # since it take a long time to large data sets
    # get max cassette max length
    print "Getting max cassette size.<br>\n";
    my $maxCassetteSize;
    if ( $max eq "" ) {
        $maxCassetteSize = getMaxCassetteSize( $dbh, $cassettes_href, $cassette_oid );
    } else {
        $maxCassetteSize = $max;
    }

    print "Max size found $maxCassetteSize <br>\n";

    # query cassette data
    print "Getting cassette $cassette_oid genes...<br>\n";
    my ( $cassette_data_aref, $min_start, $max_end ) = getCassetteData( $dbh, $cassette_oid, $type );

    # I still have to find genes within the cassette range and were
    # not found in gene_cassette table by using the scaffold and min and max
    # list - query cassette
    getOtherScaffoldGenes( $dbh, $cassette_oid, $min_start, $max_end, $type, $cassette_data_aref );

    # end of working div
    print "</p></div>\n";
    WebUtil::clearWorkingDiv();

    # this error is for the first scaffold to plot - query cassette
    # I should never reach this case, since I catch it in the
    # cassette details page - but its here just case - ken
    if ( $#$cassette_data_aref >= $MAX_BOX_GENES ) {
        printStatusLine( "Loaded.", 2 );
        my $url = "$section_cgi&page=cassetteList&cassette_oid=$cassette_oid" . "&type=$type";
        print "<p>";
        print alink( $url, "View cassette gene list" );
        print "</p>";
        #$dbh->disconnect();
        my $count = $#$cassette_data_aref + 1;
        webError( "Query cassette plot $cassette_oid has more than " . "$MAX_BOX_GENES genes ($count)." );
    }

    # do plot
    # print Dumper $cassette_data_aref;
    printPlotViewer2( $dbh, $cassette_data_aref, $min_start, $max_end, $all_functions_href, $type, $maxCassetteSize,
        $center_func_id );

    # -------------------------------------------------------------------
    #
    #
    # do the same for other cassettes
    # Limit to 20 plots because of performance
    # fix the number of plots - use more button?
    #
    # IMPORTANT !!!!
    # TODO SORT here is important since its how I do the next page !!!!
    #
    # --------------------------------------------------------------------
    my $max_plots  = 10;
    my $count      = 0;
    my $page_count = 0;
    foreach my $cid ( sort keys %$cassettes_href ) {
        # page loop
        if ( $page_index > 1 ) {
            if ( $max_plots * ( $page_index - 1 ) > $page_count ) {
                $page_count++;
                next;
            }
        }

        my ( $cassette_data_aref, $min_start, $max_end ) = getCassetteData( $dbh, $cid, $type );
        getOtherScaffoldGenes( $dbh, $cid, $min_start, $max_end, $type, $cassette_data_aref );

        # given cassette has no scaffold ?
        next if ( $min_start < 0 || $max_end < 0 );

        # case where cassette genes are very wide apart - entire scaffold
        # so i just put a link instead of a plot - ken
        if ( $#$cassette_data_aref >= $MAX_BOX_GENES ) {
            my ( $gene_oid, $start_coord, $end_coord, $func_id, $scaffold, $strand, $scaffold_name ) =
              split( /\t/, $cassette_data_aref->[0] );
            my $url   = "$section_cgi&page=cassetteList&cassette_oid=$cid" . "&type=$type";
            my $count = $#$cassette_data_aref + 1;
            print "<p>";
            print "<a href='$url'>";
            print "<font size=-1>Cannot plot ";
            print "<font color='#ff0000'>$scaffold_name</font> cassette box.";
            print "</a><br>";
            print "It has too many genes ($count)!";
            print "</font><br><br><br></p>";
            next;
        }

        # do plot
        #print Dumper $cassette_data_aref;
        if ($at_least) {
            printPlotViewer2( $dbh, $cassette_data_aref, $min_start, $max_end, $all_functions_href, $type, $maxCassetteSize,
                $center_func_id );

        } else {
            printPlotViewer2( $dbh, $cassette_data_aref, $min_start, $max_end, $functions_href, $type, $maxCassetteSize,
                $center_func_id );
        }
        $count++;
        last if ( $count >= $max_plots );
    }

    my $cnt = keys %$cassettes_href;

    # sometimes $cnt is bigger than number of plots if less than 20
    # becuz some cassette have no scaffold

    my $a = $max_plots * $page_index;
    my $b = $a - $max_plots + 1;
    $a = $cnt if ( $cnt < $a );
    printStatusLine( "Loaded $b to $a of $cnt query cassettes.", 2 );

    #$dbh->disconnect();

    if ( ( $max_plots * $page_index ) < $cnt ) {
        $page_index++;
        print "<p>\n";

        #print "<a href='$section_cgi&page=viewer2&page_index=$page_index"
        #  . "&box_oid=$box_oid&type=$type&cassette_oid=$cassette_oid'>"
        #  . "Next...</a>";

        my $url =
            "$section_cgi&page=viewer2&page_index=$page_index"
          . "&box_oid=$box_oid&type=$type&cassette_oid=$cassette_oid"
          . "&max=$maxCassetteSize"
          . "&func_id=$center_func_id";

        if ($at_least) {
            $url =
                "$section_cgi&page=viewer3&page_index=$page_index"
              . "&box_oid=$box_oid&type=$type&cassette_oid=$cassette_oid"
              . "&max=$maxCassetteSize"
              . "&func_id=$center_func_id";

        }
        $url = escapeHTML($url);

        print "<input type='button' name='next' value='Next...' "
	    . "onClick='window.open(\"$url\", \"_self\");' "
	    . "class='smbutton' />\n";
    }
}

#
# Creates plots for printViewer2
#
# FUSION genes is gotten here for bbh !!!
#
# param $cassette_data_aref - array ref of tab delimited data
#   "$gene_oid\t$start_coord\t$end_coord\t$cog\t$scaffold\t$strand\t$scaffold_name"
# param $min_start - start coord
# param $max_end - end coord
# param $func_id_href - hash ref of func id => ""
# param $type - bbh, pfam or cog
# $center_func_id - center function id to center the strand on
sub printPlotViewer2 {
    my ( $dbh, $cassette_data_aref, $min_start, $max_end, $func_id_href, $type, $maxCassetteSize, $center_func_id ) = @_;

    if ( $maxCassetteSize > ( ( $max_end - $min_start ) * 2 ) ) {
        my $tmp = ( $max_end - $min_start ) * 2;
        webLog("Max size too big $maxCassetteSize using $tmp instead\n");
        $maxCassetteSize = $tmp;
    }

    my $left_flank  = $min_start;
    my $right_flank = $min_start + $maxCassetteSize + 1;
    my $coord_incr  = int( ( $right_flank - $left_flank ) / 4 );

    # use 1st arrray record's data
    my ( $gene_oid, $start_coord, $end_coord, $func_id, $scaffold, $strand, $scaffold_name );

    foreach my $line (@$cassette_data_aref) {
        ( $gene_oid, $start_coord, $end_coord, $func_id, $scaffold, $strand, $scaffold_name ) =
          split( /\t/, $line );
        if ( $func_id eq $center_func_id ) {
            last;
        }
    }

    if ( $strand eq "-" ) {
        $left_flank  = $max_end - $maxCassetteSize - 1;
        $right_flank = $max_end + 1;
        $coord_incr  = int( ( $right_flank - $left_flank ) / 4 );
    }

    #webLog("$gene_oid strand is $strand ");

    # TODO - fixe strand if possible
    my $id   = "gc.$type.$scaffold.$$";
    my $args = {
        id                 => $id,
        start_coord        => $left_flank,
        end_coord          => $right_flank,
        coord_incr         => $coord_incr,
        title              => $scaffold_name,
        strand             => $strand,
        has_frame          => 1,
        gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
        color_array_file   => $env->{large_color_array_file},
        tmp_dir            => $tmp_dir,
        tmp_url            => $tmp_url,
    };

    my $sp          = new GeneCassettePanel2($args);
    my $color_array = $sp->{color_array};

    # duplicate func ids
    # some genes have duplicate function ids
    # what to do?

    # find duplicate functions for pfam
    # hash start-end => count
    my %duplicate;

    # pfam
    # cog
    # select distinct g.gene_oid, g.start_coord, g.end_coord, gc.cog,
    # g.scaffold, g.strand, scf.scaffold_name
    # from gene g left join gene_cog_groups gc on g.gene_oid = gc.gene_oid,
    # gene_cassette_genes gcg, scaffold scf
    # where g.gene_oid = gcg.gene
    # and g.scaffold = scf.scaffold_oid
    # and gcg.cassette_oid = 100638363409
    #
    #
    # test bbh if duplicates???
    # remove me duplicate bug
    # 640739580, 2454894, 2455469, , 637000349, +,
    # Xanthomonas oryzae pv. oryzae KACC10331: NC_006834
    #

    # hash start-end => count drawn so far
    my %duplicate2;

    # hash $gene_oid => string list of all the function ids
    my %duplicate_label;

    if (   $type eq "pfam"
        || $type eq "cog"
        || ( $type eq "bbh" && $FIND_FUSION == 0 ) )
    {
        foreach my $line (@$cassette_data_aref) {
            my ( $gene_oid, $start_coord, $end_coord, $func_id, $scaffold, $strand, $scaffold_name ) = split( /\t/, $line );
            if ( exists $duplicate{"$start_coord-$end_coord"} ) {
                $duplicate{"$start_coord-$end_coord"} = $duplicate{"$start_coord-$end_coord"} + 1;
                $duplicate_label{$gene_oid} = "$duplicate_label{$gene_oid}, $func_id";
            } else {
                $duplicate{"$start_coord-$end_coord"}  = 1;
                $duplicate2{"$start_coord-$end_coord"} = 0;
                $duplicate_label{$gene_oid}            = $func_id;
            }
        }
    }

    foreach my $line (@$cassette_data_aref) {
        my ( $gene_oid, $start_coord, $end_coord, $func_id, $scaffold, $strand, $scaffold_name ) =
          split( /\t/, $line );

        # base on type call the corect coloring method
        my $color = $sp->{color_yellow};

        # color only the matching functions to query
        if ( $func_id ne "" && exists( $func_id_href->{$func_id} ) ) {
            if ( $type eq "pfam" ) {
                $color = getPfamColor( $sp, $func_id );
            } elsif ( $type eq "bbh" && $FIND_FUSION == 0 ) {
                $color = getBBHColor( $sp, $func_id );
            } else {
                $color = getCogColor( $sp, $func_id );
            }
        }

        if ( $type eq "bbh" && $FIND_FUSION ) {

            # FUSION - do fusion genes here
            # I'm doing fusion here for the 2nd viewer during the ploting of
            # of the genes.
            # Since, I know each gene - find if its a fusion,
            # if a fusion gene then plot the fusion gene instead
            webLog("Getting fusion gene for $gene_oid\n");
            my @fusion_genes;
            my %cycle;
            $cycle{$gene_oid} = "";
            getFusionGenes( $dbh, $gene_oid, \@fusion_genes, \%cycle );

            # Its a fusion gene
            # gene oid => func id
            # DEPRICATED method!!! getBBHClusterId();
            my $bbh_cluster_href = getBBHClusterId( $dbh, \@fusion_genes );

            my $fcount = $#fusion_genes + 1;
            my $fincr  = int( ( $end_coord - $start_coord ) / $fcount );
            my $fstart = $start_coord;
            my $fend   = $start_coord + $fincr;

            foreach my $fgene_oid (@fusion_genes) {
                my $tmp_func_id = $bbh_cluster_href->{$fgene_oid};
                if ( exists( $func_id_href->{$tmp_func_id} ) ) {
                    $color = getBBHColor( $sp, $tmp_func_id );
                } else {
                    $color = $sp->{color_yellow};

                }

                my $label = "gene $fgene_oid, $fstart, $fend, $tmp_func_id";
                if ( $gene_oid ne $fusion_genes[0] ) {
                    $label = "gene $fgene_oid, -, -, $tmp_func_id";
                }

                $sp->addGene( $fgene_oid, $fstart, $fend, $strand, $color, $label );
                $fstart = $fstart + $fincr;
                $fend   = $fend + $fincr;
            }

            if ( $gene_oid ne $fusion_genes[0] ) {

                # its a fusion gene and draw a box
                my $label = "Fusion gene $gene_oid, $start_coord, $end_coord, $func_id";
                $sp->addFusedGeneBox( $start_coord, $end_coord, $gene_oid, $label, $type );
            }
        } elsif ( $type eq "pfam"
            || $type eq "cog"
            || ( $type eq "bbh" && $FIND_FUSION == 0 ) )
        {
            my $label = "gene $gene_oid, $start_coord, $end_coord, $func_id";
            if ( $duplicate{"$start_coord-$end_coord"} > 1 ) {
                my $length = $end_coord - $start_coord;
                my $incr   = int( $length / $duplicate{"$start_coord-$end_coord"} );

                my $tmp_start = $start_coord + $incr * $duplicate2{"$start_coord-$end_coord"};
                my $tmp_end   = $tmp_start + $incr;

                if (   $strand eq "-"
                    && $duplicate2{"$start_coord-$end_coord"} > 0 )
                {
                    $sp->addGene2( $gene_oid, $tmp_start, $tmp_end, $strand, $color, $label )

                } elsif ( $strand eq "+"
                    && $duplicate2{"$start_coord-$end_coord"} < ( $duplicate{"$start_coord-$end_coord"} - 1 ) )
                {
                    $sp->addGene2( $gene_oid, $tmp_start, $tmp_end, $strand, $color, $label )

                } else {

                    # have not drawn the 1st one yet for neg strang
                    # for positive draw this one until last one
                    $sp->addGene( $gene_oid, $tmp_start, $tmp_end, $strand, $color, $label );
                }

                # drawn another duplicate
                $duplicate2{"$start_coord-$end_coord"} = $duplicate2{"$start_coord-$end_coord"} + 1;

                #                $sp->addGene(
                #                    $gene_oid, $tmp_start, $tmp_end,
                #                    $strand,   $color,     $label
                #                );

                #print "$label $tmp_start $tmp_end <br>\n";

                if ( $duplicate{"$start_coord-$end_coord"} == $duplicate2{"$start_coord-$end_coord"} ) {

                    #print "draw box<br>\n";
                    my $label = "Gene with multiple PFAMs $gene_oid, " . "$start_coord, $end_coord";
                    if ( $type eq "cog" ) {
                        $label = "Gene with multiple COGs $gene_oid, " . "$start_coord, $end_coord";
                    } elsif ( $type eq "bbh" ) {
                        $label = "Gene with multiple BBHs $gene_oid, " . "$start_coord, $end_coord";
                    }

                    #$sp->addFusedGeneBox( $start_coord, $end_coord, $gene_oid,
                    #    $label, $type );

                    my $tmp = $duplicate_label{$gene_oid};
                    $sp->addBox( $start_coord, $end_coord, $color = $sp->{color_red}, $strand, "$label ($tmp)", $gene_oid );
                }

            } else {
                $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $color, $label );
            }

        } else {
            my $label = "gene $gene_oid, $start_coord, $end_coord, $func_id";
            $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $color, $label );
        }
    }

    my $s = $sp->getMapHtml("overlib");
    print "$s\n";
    print "<script src='$base_url/overlib.js'></script>\n";
}

#
# Gets other genes on scaffold within cassette box,
# BUT not in the cassette tables
#
# see getCassetteData()
#
# param $dbh
# param $cassette_oid
# param $min - start coord
# param $max - end coord
# param $type
# param $results_aref - return array from getCassetteData()
#    "$gene_oid\t$start_coord\t$end_coord\t$cog\t$scaffold\t$strand\t$scaffold_name"
sub getOtherScaffoldGenes {
    my ( $dbh, $cassette_oid, $min, $max, $type, $results_aref ) = @_;

    my $sql;
    $sql = qq{
        select g.scaffold
        from gene g, gene_cassette_genes gcg
        where g.gene_oid = gcg.gene
        and gcg.cassette_oid = ?
        and rownum < 2
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cassette_oid );
    my ($scaffold) = $cur->fetchrow();
    $cur->finish();

    if ( $scaffold eq "" ) {
        webLog("No scaffold found for cassette $cassette_oid\n");
        return;
    }

    my @binds = ( $scaffold, $min, $max, $cassette_oid );
    if ( $type eq "bbh" ) {
        # what about fusion genes - done dring the plot see printPlotViewer2()
        $sql = qq{
        select distinct g.gene_oid, g.start_coord, g.end_coord, gc.cluster_id,
        g.scaffold, g.strand, scf.scaffold_name
        from gene g
        left join bbh_cluster_member_genes gc on g.gene_oid = gc.member_genes,
        scaffold scf
        where g.scaffold = ?
        and g.scaffold = scf.scaffold_oid
        and g.start_coord >= ?
        and g.end_coord <= ?
        and g.gene_oid not in (
            select gcg.gene
            from gene_cassette_genes gcg
            where gcg.cassette_oid = ?
        )
        };

    } elsif ( $type eq "pfam" ) {
        # query for pfam ids
        $sql = qq{
        select distinct g.gene_oid, g.start_coord, g.end_coord, gc.pfam_family,
        g.scaffold, g.strand, scf.scaffold_name
        from gene g
        left join gene_pfam_families gc on g.gene_oid = gc.gene_oid,
        scaffold scf
        where g.scaffold = ?
        and g.scaffold = scf.scaffold_oid
        and g.start_coord >= ?
        and g.end_coord <= ?
        and g.gene_oid not in (
            select gcg.gene
            from gene_cassette_genes gcg
            where gcg.cassette_oid = ?
        )
        };

    } else {
        $sql = qq{
        select distinct g.gene_oid, g.start_coord, g.end_coord, gc.cog,
        g.scaffold, g.strand, scf.scaffold_name
        from gene g
        left join gene_cog_groups gc on g.gene_oid = gc.gene_oid,
        scaffold scf
        where g.scaffold = ?
        and g.scaffold = scf.scaffold_oid
        and g.start_coord >= ?
        and g.end_coord <= ?
        and g.gene_oid not in (
            select gcg.gene
            from gene_cassette_genes gcg
            where gcg.cassette_oid = ?
        )
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $gene_oid, $start_coord, $end_coord, $cog,
	     $scaffold, $strand, $scaffold_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @$results_aref, "$gene_oid\t$start_coord\t$end_coord\t$cog\t"
	                    . "$scaffold\t$strand\t$scaffold_name" );
        #print "found $gene_oid $cog <br>\n";
    }
    $cur->finish();
}

# Gets cassette genes
#
# see getOtherScaffoldGenes()
#
# param $dbh
# param $cassette_oid
# param $type
#
# return array ref - tab delimited arary of records
#   "$gene_oid\t$start_coord\t$end_coord\t$cog\t$scaffold\t$strand\t$scaffold_name"
# return min coord
# return max coord
sub getCassetteData {
    my ( $dbh, $cassette_oid, $type ) = @_;

    my $sql;
    if ( $type eq "bbh" ) {
        # what about fusion genes - done during the plot see printPlotViewer2()
        #
        $sql = qq{
        select distinct g.gene_oid, g.start_coord, g.end_coord, gc.cluster_id,
        g.scaffold, g.strand, scf.scaffold_name
        from gene g left join bbh_cluster_member_genes gc on g.gene_oid = gc.member_genes,
        gene_cassette_genes gcg, scaffold scf
        where g.gene_oid = gcg.gene
        and g.scaffold = scf.scaffold_oid
        and gcg.cassette_oid = ?
        };

    } elsif ( $type eq "pfam" ) {
        # query for pfam ids
        $sql = qq{
        select distinct g.gene_oid, g.start_coord, g.end_coord, gc.pfam_family,
        g.scaffold, g.strand, scf.scaffold_name
        from gene g left join gene_pfam_families gc on g.gene_oid = gc.gene_oid,
        gene_cassette_genes gcg, scaffold scf
        where g.gene_oid = gcg.gene
        and g.scaffold = scf.scaffold_oid
        and gcg.cassette_oid = ?
        };

    } else {
        $sql = qq{
        select distinct g.gene_oid, g.start_coord, g.end_coord, gc.cog,
        g.scaffold, g.strand, scf.scaffold_name
        from gene g left join gene_cog_groups gc on g.gene_oid = gc.gene_oid,
        gene_cassette_genes gcg, scaffold scf
        where g.gene_oid = gcg.gene
        and g.scaffold = scf.scaffold_oid
        and gcg.cassette_oid = ?
        };
    }

    my @result;

    my $min = -1;
    my $max = -1;
    my $cur = execSql( $dbh, $sql, $verbose, $cassette_oid );
    for ( ; ; ) {
        my ( $gene_oid, $start_coord, $end_coord, $cog, $scaffold, $strand, $scaffold_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @result, "$gene_oid\t$start_coord\t$end_coord\t$cog\t"
	             . "$scaffold\t$strand\t$scaffold_name" );

        $max = $end_coord   if ( $end_coord > $max );
        $min = $start_coord if ( $min == -1 || $start_coord < $min );

    }
    $cur->finish();

    return ( \@result, $min, $max );

}

#
# Gets max cassette size
# given list of cassette ids
#
# param
#   $dbh
#   $cassette_href - other cassette ids
#   $cassette_oid - query cassette
# return max length cassette
sub getMaxCassetteSize {
    my ( $dbh, $cassette_href, $cassette_oid ) = @_;

    my @cassette_oids;
    push( @cassette_oids, $cassette_oid );
    foreach my $id ( keys %$cassette_href ) {
        push( @cassette_oids, $id );
    }

    my $str;
    if ( OracleUtil::useTempTable( scalar(@cassette_oids) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@cassette_oids );
        $str = " select id from gtt_num_id ";
    } else {
        $str = join( ",", @cassette_oids );
    }

    my $sql = qq{
        select cassette_oid, min(g.start_coord), max(g.end_coord)
        from gene g, gene_cassette_genes gcg
        where g.gene_oid = gcg.gene
        and gcg.cassette_oid in ( $str )
        group by cassette_oid
    };

    my $size = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $coid, $start_coord, $end_coord ) = $cur->fetchrow();
        last if !$coid;
        my $len = $end_coord - $start_coord;
        $size = $len if ( $len > $size );
    }
    $cur->finish();

    return $size;
}

# Gets list of cassettes given box oid and present functions
# and absent functions
# lets get all the cassettes that have AT LEAST the correct cluster
# count
#
# param $dbh
# param $box_oid
# param $type
# param $cassette_oid - query cassette oid to ignore
sub getCassettesViaBoxFunc2 {
    my ( $dbh, $box_oid, $type, $cassette_oid ) = @_;

    my $urclause  = urClause("cb.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('cb.taxon');

    my $sql;
    if ( $type eq "bbh" ) {
        $sql = qq{
        select cb.cassettes
        from cassette_box_cassettes_bbh cb
        where cb.box_oid = ?
        $urclause
        $imgClause
        };
    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select cb.cassettes
        from cassette_box_cassettes_pfam cb
        where cb.box_oid = ?
        $urclause
        $imgClause
        };
    } else {
        $sql = qq{
        select cb.cassettes
        from cassette_box_cassettes_cog cb
        where cb.box_oid = ?
        $urclause
        $imgClause
        };
    }

    my %result;

    my $cur = execSql( $dbh, $sql, $verbose, $box_oid );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;

        # ignore the query cassette since I plot it first
        next if ( $cassette_oid eq $id );
        $result{$id} = "";
    }
    $cur->finish();

    return \%result;
}

# Gets list of cassettes given box oid and present functions
# and absent functions
# lets get all the cassettes that only have the correct cluster
# count
#
# param $dbh
# param $box_oid
# param $type
# param $diff_func_ids_aref - array ref of absent function ids
# param $cassette_oid - query cassette oid to ignore
sub getCassettesViaBoxFunc {
    my ( $dbh, $box_oid, $type, $diff_func_ids_aref, $cassette_oid ) = @_;

    my $size = $#$diff_func_ids_aref + 1;

    my $str;
    if ( $size > 0 ) {
        if ( OracleUtil::useTempTable( scalar(@$diff_func_ids_aref) ) ) {
            OracleUtil::insertDataArray( $dbh, "gtt_func_id", $diff_func_ids_aref );
            $str = " select id from gtt_func_id ";
        } else {

            # need to quote data
            my $tmp = join( "','", @$diff_func_ids_aref );
            $str = "'$tmp'";
        }
    }

    my $urclause  = urClause("cbc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('cbc.taxon');
    my $sql;
    my @binds = ($box_oid);

    if ( $type eq "bbh" ) {
        $sql = qq{
        select cbc.cassettes
        from cassette_box_cassettes_bbh cbc
        where cbc.box_oid = ?
        $urclause
        $imgClause
        };
        if ( $size > 0 ) {
            my $tmpsql = qq{
            select distinct cbc2.cassettes
            from cassette_box_bbh_xlogs cx2, cassette_box_cassettes_bbh cbc2,
            cassette_box_cassettes_bbh cbc
            where cx2.box_oid = cbc2.box_oid
            and cx2.bbh_cluster in ( $str )
            and cbc2.cassettes = cbc.cassettes
            and cbc.box_oid = ?
            };
            push( @binds, $box_oid );
            $sql = $sql . qq{
                minus
                ($tmpsql)
            };
        }

    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select cbc.cassettes
        from cassette_box_cassettes_pfam cbc
        where cbc.box_oid = ?
        $urclause
        $imgClause
        };
        if ( $size > 0 ) {
            my $tmpsql = qq{
            select distinct cbc2.cassettes
            from cassette_box_pfam_xlogs cx2, cassette_box_cassettes_pfam cbc2,
            cassette_box_cassettes_pfam cbc
            where cx2.box_oid = cbc2.box_oid
            and cx2.pfam_cluster in ( $str )
            and cbc2.cassettes = cbc.cassettes
            and cbc.box_oid = ?
            };
            push( @binds, $box_oid );
            $sql = $sql . qq{
                minus
                ($tmpsql)
            };
        }

    } else {
        $sql = qq{
        select cassettes
        from cassette_box_cassettes_cog cbc
        where cbc.box_oid = ?
        $urclause
        $imgClause
        };
        if ( $size > 0 ) {
            my $tmpsql = qq{
            select distinct cbc2.cassettes
            from cassette_box_cog_xlogs cx2, cassette_box_cassettes_cog cbc2,
            cassette_box_cassettes_cog cbc
            where cx2.box_oid = cbc2.box_oid
            and cx2.cog_cluster in ( $str )
            and cbc2.cassettes = cbc.cassettes
            and cbc.box_oid = ?
            };
            push( @binds, $box_oid );
            $sql = $sql . qq{
                minus
                ($tmpsql)
            };
        }
    }

    my %result;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;

        # ignore the query cassette since I plot it first
        next if ( $cassette_oid eq $id );
        $result{$id} = "";
    }
    $cur->finish();

    return \%result;
}

# Gets cluster ids or function ids for a given box
#
# param
# $dbh
# $box_oid
# $type
#
# return a hash list of functions id => ""
sub getClusterIds {
    my ( $dbh, $box_oid, $type ) = @_;

    my $sql;
    if ( $type eq "bbh" ) {
        $sql = qq{
        select cx.bbh_cluster
        from cassette_box_bbh_xlogs cx
        where cx.box_oid = ?
        };
    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select cx.pfam_cluster
        from cassette_box_pfam_xlogs cx
        where cx.box_oid = ?
        };
    } else {
        $sql = qq{
        select cx.cog_cluster
        from cassette_box_cog_xlogs cx
        where cx.box_oid = ?
        };
    }

    my %result;

    my $cur = execSql( $dbh, $sql, $verbose, $box_oid );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        $result{$id} = "";
    }
    $cur->finish();

    return \%result;
}

# get cluster ids or function ids within a cassette
#
# param
# $dbh
# $cassette_oid
# $type
#
# return a hash list of functions id => ""
sub getClusterAllIds {
    my ( $dbh, $cassette_oid, $type ) = @_;

    my $urclause  = urClause("cbc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('cbc.taxon');
    my $sql;

    if ( $type eq "bbh" ) {
        $sql = qq{
        select distinct cx.bbh_cluster
        from cassette_box_cassettes_bbh cbc, cassette_box_bbh_xlogs cx
        where cbc.box_oid = cx.box_oid
        and cbc.cassettes = ?
        $urclause
        $imgClause
        };

    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select distinct cx.pfam_cluster
        from cassette_box_cassettes_pfam cbc, cassette_box_pfam_xlogs cx
        where cbc.box_oid = cx.box_oid
        and cbc.cassettes = ?
        $urclause
        $imgClause
        };

    } else {
        $sql = qq{
        select distinct cx.cog_cluster
        from cassette_box_cassettes_cog cbc, cassette_box_cog_xlogs cx
        where cbc.box_oid = cx.box_oid
        and cbc.cassettes = ?
        $urclause
        $imgClause
        };
    }

    my %result;

    my $cur = execSql( $dbh, $sql, $verbose, $cassette_oid );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        $result{$id} = "";
    }
    $cur->finish();

    return \%result;
}

# Print phylo distr. tree
sub printPhylogeneticDistribution {
    my $type    = param("type");
    my $box_oid = param("box_oid");

    printStatusLine( "Loading ...", 1 );
    print "<h1>Phylogenetic Distribution</h1>\n";
    print "<p>\n";
    print "Organisms are shown in red.\n";
    print "<br/>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";

    my $dbh = dbLogin();

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree();

    my $urclause  = urClause("cbc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('cbc.taxon');

    # find taxon oids
    my $sql;
    if ( $type eq "bbh" ) {
        # what about fusion gene taxon here - nothing for now 2008-04-09 - ken
        $sql = qq{
        select distinct gc.taxon
        from cassette_box_cassettes_bbh cbc, gene_cassette gc
        where cbc.box_oid = ?
        and cbc.cassettes = gc.cassette_oid
        $urclause
        $imgClause
        };

    } elsif ( $type eq "pfam" ) {
        $sql = qq{
        select distinct gc.taxon
        from cassette_box_cassettes_pfam cbc, gene_cassette gc
        where cbc.box_oid = ?
        and cbc.cassettes = gc.cassette_oid
        $urclause
        $imgClause
        };

    } else {
        # cog
        $sql = qq{
        select distinct gc.taxon
        from cassette_box_cassettes_cog cbc, gene_cassette gc
        where cbc.box_oid = ?
        and cbc.cassettes = gc.cassette_oid
        $urclause
        $imgClause
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, $box_oid );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $mgr->incrCount($taxon_oid);
    }
    $cur->finish();

    $mgr->aggCount();
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";

    #print end_form( );
    printStatusLine( "Loaded.", 2 );

    #$dbh->disconnect();
}

#
# Print cassette details page
#
sub printCassetteBoxDetails {
    my $gene_oid = param("gene_oid");
    my $type     = param("type");
    my $sort     = param("sort");
    my $biosynthetic_id = param("biosynthetic_id");

    $type = "cog" if ( $type eq "" );
    $sort = 1     if ( $sort eq "" );

    my $dbh = dbLogin();

    # see method getGeneViaCassetteOid() from my comments
    my $cassette_oid = param("cassette_oid");
    if ( $cassette_oid ne "" ) {
        # lets get any gene in the cassette since I need any gene from a
        # cassette to do most of my queries
        $gene_oid = getGeneViaCassetteOid($dbh, $cassette_oid, $gene_oid);
    } elsif ($type ne 'bio') {
        # lets just get the cassette oid - I just might need it later
        $cassette_oid = getCassetteOidViaGene($dbh, $gene_oid);
    }

    #checkGenePerm( $dbh, $gene_oid );

    printMainForm();

    printJavaScript();

    my $title = getTypeTitle($type);
    if ($type eq "bio") {
	print "<h1>Biosynthetic Cluster Functions</h1>";
    } else {
	print "<h1>Chromosomal Cassette " . $title . "</h1>\n";
    }

    print qq{
        <script language='javascript' type='text/javascript'>
        function selectCassetteDetail() {
            var e =  document.mainForm.cassetteDetail;
            if(e.value == 'label') {
                return;
            }
            var url = "main.cgi?section=GeneCassette&page=cassetteBox&gene_oid=$gene_oid&type=";
            url +=  e.value;
            window.open( url, '_self' );
        }
        </script>

    };

    if ($type ne "bio") {
	print "<p>";
	printProteinSelection( "Switch Protein Cluster", "cassetteDetail",
			       "selectCassetteDetail()", $dbh, $gene_oid );
	print "</p>";
    }

    printStatusLine("Loading ...");

    # find all the gene cassettes
    # find cassette box left and right
    my ( $scaffold_oid, $min_start, $max_end )
	= getGeneCassetteMinMax( $dbh, $gene_oid, $type, $biosynthetic_id );

    # find all the genes within the cassette box, even those not
    # in the cassette but are within the box
    my @gene_oid_list;

    my $sql = qq{
       select distinct dt.gene_oid
       from gene dt
       where dt.scaffold = ?
       and dt.start_coord > 0
       and dt.end_coord > 0
       and (
          ( dt.start_coord >= ? and dt.end_coord <= ? ) or
      ( ( dt.end_coord + dt.start_coord ) / 2 >= ? and
        ( dt.end_coord + dt.start_coord ) / 2 <= ? )
       )
   };

    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid,
		       $min_start, $max_end, $min_start, $max_end );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        push( @gene_oid_list, $id );
    }
    $cur->finish();

    # error no genes return for gene
    if ( $#gene_oid_list < 0 ) {
        printStatusLine( "Loaded.", 2 );
        #$dbh->disconnect();
        webError("Gene $gene_oid has no cassette data for $title");
    } elsif ( $#gene_oid_list >= $MAX_BOX_GENES ) {
        printStatusLine( "Loaded.", 2 );
        #$dbh->disconnect();
        my $count = $#gene_oid_list + 1;
        my $url   = "$section_cgi&page=cassetteList&cassette_oid=$cassette_oid" . "&type=$type";
        print "<p>";
        print alink( $url, "View cassette gene list" );
        print "</p>";
        webError( "Cassette $cassette_oid has more than $MAX_BOX_GENES " . "genes ($count)." );
    }

    # hash of cog id => array list of geneoid \t functions
    my $func_href;
    my $cog_path_max_aref;

    my %fusion_hash;
    if ( $type eq "bbh" ) {
        # this return has the fused genes, not the resulting fusion gene
        $func_href = getBBHFunctions( $dbh, \@gene_oid_list, \%fusion_hash );
    } elsif ( $type eq "pfam" ) {
        $func_href = getPfamFunctions( $dbh, \@gene_oid_list );
    } elsif ( $type eq "bio" ) {
        $func_href = getPfamFunctions( $dbh, \@gene_oid_list );
    } else {
        $func_href = getCogFunctions( $dbh, \@gene_oid_list );
        $cog_path_max_aref = getCogPathwayMax( $dbh, \@gene_oid_list, 1 );
    }

    if ( $type eq "bbh" ) {
        printFusionGeneList( \%fusion_hash );
    }

    if ( $type eq "cog" ) {
        printCogPathwayMax( $cassette_oid, $cog_path_max_aref );
    }

    printFuncTable( $func_href, $gene_oid, $type );

    #
    # disable for now 2012-10-31 - ken
    # no more box data in oracle
    #printChromCassetteTable_yui( $dbh, $gene_oid, $type, $sort );

    if ($img_ken) {
        #printPresent_fastbit($dbh, $cassette_oid, $gene_oid, $type, $func_href);
    }

    printStatusLine( "Loaded", 2 );
    #$dbh->disconnect();
    print end_form();
}

# prints table of max cog path counts
#
# param
#   $cassette_oid - cassette oid
#   $cog_path_max_aref - array ref list of "$id\t$name\t$cnt"
sub printCogPathwayMax {
    my ( $cassette_oid, $cog_path_max_aref ) = @_;

    return if ( $#$cog_path_max_aref < 0 );

    my $url = "<a href='$section_cgi&page=pathGeneList"
	    . "&cassette_oid=$cassette_oid&pathway_oid=";

    print "<h2>Preferred COG Pathways</h2>\n";

    my $it = new InnerTable( 1, "CogPathway$$", "CogPathway", 1 );
    my $sd = $it->getSdDelim(); # sort delimiter

    $it->addColSpec( "COG Pathway ID", "number asc",  "right" );
    $it->addColSpec( "Pathway Name",   "char asc",    "left" );
    $it->addColSpec( "Gene Count",     "number desc", "right" );

    my $ctr = 0;
    foreach my $line (@$cog_path_max_aref) {
        my ( $id, $name, $cnt ) = split( /\t/, $line );
        my $r .= $id . $sd . $id . "\t";
        $r    .= $name . $sd . $name . "\t";
        $r    .= $id . $sd . $url . $id . "'>$cnt</a>\t";
        $it->addRow($r);

        $ctr++;
    }

    #only show page controls if mode that 20 (arbitrary) rows
    my $tblMode = ( $ctr > 20 ) ? 1 : "nopage";

    $it->printOuterTable($tblMode);
}

# prints a table of fusion genes and the gene parts
#
# param $fusion_href hash of gene to list of fused genes
#   if the list is gene itself, ie hash key gene, then its not a fusion gene
sub printFusionGeneList {
    my ($fusion_href) = @_;

    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    # hash of only fusion genes
    my %hash;

    # search for only fusion genes
    foreach my $fgid ( keys %$fusion_href ) {
        my $isfusion = 0;
        my $aref     = $fusion_href->{$fgid};
        foreach my $gid (@$aref) {
            last if ( $fgid == $gid );
            $isfusion = 1;
            last;
        }
        if ($isfusion) {
            $hash{$fgid} = $aref;
        }
    }

    if ( ( keys %hash ) > 0 ) {

        print "<h2>Fusion Gene List</h2>\n";

        print "<table class='img'>\n";
        print "<th class='img'>Gene ID</th>\n";
        print "<th class='img'>Fusion Gene IDs</th>\n";
        foreach my $fgid ( keys %hash ) {
            my $aref = $fusion_href->{$fgid};
            print "<tr class='img'>";
            print "<td class='img'>" . "<a href='" . $url . $fgid . "'> $fgid</a> &nbsp;" . "</td>\n";
            print "<td class='img'>";
            foreach my $gid (@$aref) {
                last if ( $fgid == $gid );

                #print "$gid &nbsp;";
                print "<a href='" . $url . $gid . "'> $gid</a> &nbsp;";
            }
            print "</td>\n";
            print "</tr>\n";
        }

        print "</table>\n";
    }
}

# Gets Cassette Cog Stat given a gene oid for cassette detail page
#
# param
# $dbh
# $gene_oid
# $sort - sort col
#
# return a sorted array list of tab delimited data
#   "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t$cassette_oid"
sub getCassetteCogStat {
    my ( $dbh, $gene_oid, $sort ) = @_;

    my $orderby;
    if ( $sort == 2 ) {
        $orderby = "order by c.cass_count desc, c.cluster_count, c.taxon_count";
    } elsif ( $sort == 3 ) {
        $orderby = "order by c.taxon_count desc, c.cluster_count, c.cass_count";
    } else {
        $orderby = "order by c.cluster_count desc, c.cass_count, c.taxon_count";
    }

    my $urclause  = urClause("cbc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('cbc.taxon');
    my $sql       = qq{
        select c.box_oid, c.cluster_count, c.cass_count, c.taxon_count, gcg.cassette_oid
        from gene_cassette_genes gcg, cassette_box_cassettes_cog cbc,
        cassette_box_cog c
        where gcg.gene = ?
        and gcg.cassette_oid = cbc.cassettes
        and c.box_oid = cbc.box_oid
        $urclause
        $imgClause
        $orderby
    };

    my @result;

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) = $cur->fetchrow();
        last if !$box_oid;
        push( @result, "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t" . "$cassette_oid" );
    }
    $cur->finish();

    return \@result;
}

# Gets Cassette pfam Stat given a gene oid for cassette detail page
#
# param
# $dbh
# $gene_oid
#
# return a sorted array list of tab delimited data
#   "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t$cassette_oid"
sub getCassettePfamStat {
    my ( $dbh, $gene_oid, $sort ) = @_;

    my $orderby;
    if ( $sort == 2 ) {
        $orderby = "order by c.cass_count desc, c.cluster_count, c.taxon_count";
    } elsif ( $sort == 3 ) {
        $orderby = "order by c.taxon_count desc, c.cluster_count, c.cass_count";
    } else {
        $orderby = "order by c.cluster_count desc, c.cass_count, c.taxon_count";
    }

    my $urclause = urClause("cbc.taxon");
    my $sql      = qq{
        select c.box_oid, c.cluster_count, c.cass_count, c.taxon_count, gcg.cassette_oid
        from gene_cassette_genes gcg, cassette_box_cassettes_pfam cbc,
        cassette_box_pfam c
        where gcg.gene = ?
        and gcg.cassette_oid = cbc.cassettes
        and c.box_oid = cbc.box_oid
        $urclause
        $orderby
    };

    my @result;

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) = $cur->fetchrow();
        last if !$box_oid;
        push( @result, "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t" . "$cassette_oid" );
    }
    $cur->finish();

    return \@result;
}

# Gets Cassette bbh Stat given a gene oid for cassette detail page
#
# param
# $dbh
# $gene_oid
#
# return a sorted array list of tab delimited data
#   "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t$cassette_oid"
sub getCassetteBBHStat {
    my ( $dbh, $gene_oid, $sort ) = @_;

    my $orderby;
    if ( $sort == 2 ) {
        $orderby = "order by c.cass_count desc, c.cluster_count, c.taxon_count";
    } elsif ( $sort == 3 ) {
        $orderby = "order by c.taxon_count desc, c.cluster_count, c.cass_count";
    } else {
        $orderby = "order by c.cluster_count desc, c.cass_count, c.taxon_count";
    }

    my $urclause  = urClause("cbc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('cbc.taxon');
    my $sql       = qq{
        select c.box_oid, c.cluster_count, c.cass_count, c.taxon_count, gcg.cassette_oid
        from gene_cassette_genes gcg, cassette_box_cassettes_bbh cbc,
        cassette_box_bbh c
        where gcg.gene = ?
        and gcg.cassette_oid = cbc.cassettes
        and c.box_oid = cbc.box_oid
        $urclause
        $imgClause
        $orderby
    };

    my @result;

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) = $cur->fetchrow();
        last if !$box_oid;
        push( @result, "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t" . "$cassette_oid" );
    }
    $cur->finish();

    return \@result;
}

# Get present cog ids for cassette detail page
#
# param
# $dbh
# $cassette_stat_aref - a sorted array list of tab delimited data
#   "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t$cassette_oid"
#
# return hash of box oid => array list of cog oids
sub getPresentCog {
    my ( $dbh, $cassette_stat_aref ) = @_;

    my @box_oids;

    foreach my $line (@$cassette_stat_aref) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) =
          split( /\t/, $line );
        push( @box_oids, $box_oid );
    }

    my $str;
    if ( OracleUtil::useTempTable( scalar(@box_oids) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@box_oids );
        $str = "select id from gtt_num_id";
    } else {
        $str = join( ",", @box_oids );
    }

    my $sql = qq{
        select box_oid, cog_cluster
        from cassette_box_cog_xlogs
        where box_oid in ( $str )
    };

    # hash of box oid => array list of cog oids
    my %result;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $box, $cog ) = $cur->fetchrow();
        last if !$box;

        if ( exists $result{$box} ) {
            my $aref = $result{$box};
            push( @$aref, $cog );
        } else {

            # dose not exist
            my @a = ($cog);
            $result{$box} = \@a;
        }
    }
    $cur->finish();

    return \%result;
}

# Get present pfam ids for cassette detail page
#
# param
# $dbh
# $cassette_stat_aref - a sorted array list of tab delimited data
#   "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t$cassette_oid"
#
# return hash of box oid => array list of pfam oids
sub getPresentPfam {
    my ( $dbh, $cassette_stat_aref ) = @_;

    my @box_oids;

    foreach my $line (@$cassette_stat_aref) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) =
          split( /\t/, $line );
        push( @box_oids, $box_oid );
    }

    my $str;
    if ( OracleUtil::useTempTable( scalar(@box_oids) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@box_oids );
        $str = "select id from gtt_num_id";
    } else {
        $str = join( ",", @box_oids );
    }

    my $sql = qq{
        select box_oid, pfam_cluster
        from cassette_box_pfam_xlogs
        where box_oid in ( $str )
    };

    # hash of box oid => array list of cog oids
    my %result;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $box, $cog ) = $cur->fetchrow();
        last if !$box;

        if ( exists $result{$box} ) {
            my $aref = $result{$box};
            push( @$aref, $cog );
        } else {

            # dose not exist
            my @a = ($cog);
            $result{$box} = \@a;
        }
    }
    $cur->finish();

    return \%result;
}

# find gene fusions first? - no cassette_box_bbh_xlogs table already uses
# fusion genes' cluster id, even though the gene oid is the fused gene not
# linked directly to the bbh cluster id
# you have to search gene_fusion_component table to
# find the fusion genes see getFusionGenes()
#
# Get present bbh ids for cassette detail page
#
# param
# $dbh
# $cassette_stat_aref - a sorted array list of tab delimited data
#   "$box_oid\t$cluster_count\t$cass_count\t$taxon_count\t$cassette_oid"
#
# return hash of box oid => array list of bbh oids
sub getPresentBBH {
    my ( $dbh, $cassette_stat_aref ) = @_;

    my @box_oids;

    foreach my $line (@$cassette_stat_aref) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) =
          split( /\t/, $line );
        push( @box_oids, $box_oid );
    }

    my $str;
    if ( OracleUtil::useTempTable( scalar(@box_oids) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@box_oids );
        $str = "select id from gtt_num_id";
    } else {
        $str = join( ",", @box_oids );
    }

    my $sql = qq{
        select box_oid, bbh_cluster
        from cassette_box_bbh_xlogs
        where box_oid in ( $str )
    };

    # hash of box oid => array list of cog oids
    my %result;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $box, $cog ) = $cur->fetchrow();
        last if !$box;

        if ( exists $result{$box} ) {
            my $aref = $result{$box};
            push( @$aref, $cog );
        } else {

            # dose not exist
            my @a = ($cog);
            $result{$box} = \@a;
        }
    }
    $cur->finish();

    return \%result;
}

sub printPresent_fastbit {
    my ( $dbh, $cassette_oid, $gene_oid, $type, $func_href ) = @_;

    my $funcStr;
    foreach my $f ( sort keys %$func_href ) {
        next if ( $f =~ /^$NA/ );
        $funcStr .= "$f ";
    }

    # TODO
    # get cassette id from the gene_oid
    # get all the pfam or cog from fastbit

    WebUtil::unsetEnvPath();
    $ENV{LD_LIBRARY_PATH} = $ENV{LD_LIBRARY_PATH} . $env->{fastbit_LD_LIBRARY_PATH};
    my $cassetteDir = $env->{fastbit_dir};
    my $command     = $cassetteDir . "findCassettes db " . $funcStr;

    if ($img_ken) {
        print "<br/>$command<br/>\n";
    }

    # you must go to the genome dir to access 'db' directory
    chdir $cassetteDir;
    my $cfh = newCmdFileHandle($command);
    while ( my $s = $cfh->getline() ) {
        chomp $s;

        if ( $s =~ /^\d+/ ) {
            print $s . "<br/>\n";
        }
    }

    close $cfh;
    WebUtil::resetEnvPath();

}

# Print cassette cluster details on cassette detail page
#
#
sub printChromCassetteTable_yui {
    my ( $dbh, $gene_oid, $type, $sort ) = @_;
    my $title = getTypeTitle($type);
    my $cassette_stat_aref;
    my $box_func_href;

    #print "<h2>Chromosomal Cassette " . uc($type) . " Present</h2>\n";
    my $tmp = "<h2>Chromosomal Cassette " . $title . " Present</h2>\n";
    print WebUtil::getHtmlBookmark( "present", "$tmp" );

    my $noData = "No cassette <b>box</b> data found for this cassette.";

    if ( $type eq "bbh" ) {

        # fusion genes - not done here see comments in getPresentBBH()
        $cassette_stat_aref = getCassetteBBHStat( $dbh, $gene_oid, $sort );
        if ( $cassette_stat_aref eq "" || $#$cassette_stat_aref < 0 ) {
            print "<p> $noData</p>\n";
            return;
        }
        $box_func_href = getPresentBBH( $dbh, $cassette_stat_aref );
    } elsif ( $type eq "pfam" ) {
        $cassette_stat_aref = getCassettePfamStat( $dbh, $gene_oid, $sort );
        if ( $cassette_stat_aref eq "" || $#$cassette_stat_aref < 0 ) {
            print "<p> $noData</p>\n";
            return;
        }
        $box_func_href = getPresentPfam( $dbh, $cassette_stat_aref );
    } else {
        $cassette_stat_aref = getCassetteCogStat( $dbh, $gene_oid, $sort );
        if ( $cassette_stat_aref eq "" || $#$cassette_stat_aref < 0 ) {
            print "<p> $noData</p>\n";
            return;
        }
        $box_func_href = getPresentCog( $dbh, $cassette_stat_aref );
    }

    # now the first rec in $cassette_stat_aref should have the most function
    # ids / its the super set of fucntion ids
    # this is not always true see cassette id 6710640069344
    # where there are 5 pfams in query cassette, but 4 after has more not in
    # the 5 because its lies somewhere else
    #my $line = $cassette_stat_aref->[0];
    #my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) =
    #  split( /\t/, $line );
    #my $func_oid_aref = $box_func_href->{$box_oid};
    my %distinct_func_id;
    foreach my $key ( keys %$box_func_href ) {
        my $aref = $box_func_href->{$key};
        foreach my $x (@$aref) {
            $distinct_func_id{$x} = "";
        }
    }

    print "<p>";
    print "1 - Click <i>Number of Gene Clusters</i> "
      . "counts to view cassette plots with <b>only</b>"
      . " + functions present<br>\n";
    print "2 - Click <i>Number of Cassettes</i> "
      . "counts to view cassette plots with <b>at least</b>"
      . " + functions present<br>\n";
    print "3 - Click <i>Number of Organisms</i> " . "counts to view Phylogenetic Distribution<br>\n";
    print "</p>\n";

    print "<div id='cassetteStat'>\n";

    require InnerTable_yui;
    my $it = new InnerTable( 1, "cassettepresent$$", "cassettepresent", 0 );
    my $sd = $it->getSdDelim();                                                # sort delimiter

    $it->addColSpec( "Number of Gene Clusters<sup>1</sup>", "number desc", "right" );
    $it->addColSpec( "Number of Cassettes<sup>2</sup>",     "number desc", "right" );
    $it->addColSpec( "Number of Organisms<sup>3</sup>",     "number desc", "right" );

    foreach my $func_id ( sort ( keys %distinct_func_id ) ) {
        $it->addColSpec("$func_id");
    }

    foreach my $line (@$cassette_stat_aref) {
        my ( $box_oid, $cluster_count, $cass_count, $taxon_count, $cassette_oid ) =
          split( /\t/, $line );

        my $r;

        # plot of cassettes that have the same cluster count
        my $tmp_func_oid_aref = $box_func_href->{$box_oid};

        # randpmly pick a func to center graph on
        my $tmp_func_oid = $tmp_func_oid_aref->[0]
          if ( $#$tmp_func_oid_aref > -1 );
        my $url =
            "<a href='$section_cgi&page=viewer2"
          . "&box_oid=$box_oid&type=$type&cassette_oid=$cassette_oid"
          . "&func_id=$tmp_func_oid'>"
          . "$cluster_count</a>";

        $r .= $cluster_count . $sd . $url . "\t";

        # cassettte count
        $url =
            "<a href='$section_cgi&page=viewer3"
          . "&box_oid=$box_oid&type=$type&cassette_oid=$cassette_oid"
          . "&func_id=$tmp_func_oid'>"
          . "$cass_count</a>";
        $r .= $cass_count . $sd . $url . "\t";

        # taxon count is a link to phylo distr
        # color the taxons in count
        my $url = "<a href='$section_cgi&page=phylo" . "&box_oid=$box_oid&type=$type'>" . "$taxon_count</a>";

        $r .= $taxon_count . $sd . $url . "\t";

        my $tmp_func_oid_aref = $box_func_href->{$box_oid};
        my %tmp_func_hash;
        foreach my $x (@$tmp_func_oid_aref) {
            $tmp_func_hash{$x} = "";
        }
        foreach my $func_id ( sort ( keys %distinct_func_id ) ) {

            if ( exists $tmp_func_hash{$func_id} ) {
                $r .= $sd . "+" . "\t";
            } else {

                # leave it blank for now and not - since
                # - means absent - ken 2008-02-01
                $r .= $sd . "&nbsp;" . "\t";
            }
        }

        $it->addRow($r);
    }

    $it->printOuterTable(1);

    # stats
    print "<p>\n";
    print $title . " count: " . keys(%distinct_func_id);
    my $cnt = $#$cassette_stat_aref + 1;
    print "&nbsp;&nbsp; Row count: $cnt";
    print "</p>\n";

    print "</div>\n";
}

# IMPORTANT!!!
# NOTE - now this table shows ALL the genes in a cassette
#
#
# print function table on cassette detail page
#
# param
# $func_href -  hash of func id => array list of "geneoid \t functions name"
sub printFuncTable {
    my ( $func_href, $gene_oid0, $type ) = @_;
    my $title = getTypeTitle($type);

    # at see getProteinSelection for types that are ok
    # e.value != 'cog' && e.value != 'pfam' && e.value != 'bbh'
    print qq{
        <script language='javascript' type='text/javascript'>

        function selectCassetteNeigh(name, goid) {
        var f = document.mainForm;
        var e = "";
        for( var i = 0; i < f.length; i++ ) {
            e = f.elements[ i ];

            if( e.name == name ) {
                break;
            }
         }

        if(e.value == 'label' ) {
            return;
        }

        if(e.value != 'cog' && e.value != 'pfam' && e.value != 'bbh') {
            return;
        }

        var url = "main.cgi?section=GeneCassette&page=geneCassette&gene_oid="
        + goid + "&type=";
        url +=  e.value;
        window.open( url, '_self' );
        }
        </script>

    };

    my $tmp = "<h2>" . $title . " Functions</h2>\n";
    print $tmp if $type ne "bio";

    # hash of id to array list of gene id \t and defn

    #    my $selectStr = getProteinSelection(
    #        "View Conserved Neigbhorhood",
    #        "sbox$gene_oid0",
    #        "selectCassetteNeigh(\"sbox$gene_oid0\", $gene_oid0)"
    #    );
    #
    #    print qq{
    #        <p>
    #        $selectStr
    #        <p/>
    #    };

    $type = "pfam" if $type eq "bio"; #anna

    my $tableId = "cassette";    # also used by Select All and Clear All below
    my $sortcol = 1;
    $sortcol= 2 if $type eq "bio" || $type eq "bbh";
    my $it = new InnerTable( 1, $tableId . $$, $tableId, $sortcol );

    if ( $type eq "bbh" || $type eq 'bio' ) {
        # do nothing for now
    } else {
        $it->addColSpec("Select");
    }

    # function id column header
    if ( $type eq "bbh" ) {
        $it->addColSpec( "$title ID", "number asc", "right" );
    } elsif ( $type eq "pfam" ) {
        $it->addColSpec( "Pfam ID", "char asc", "left" );
    } elsif ( $type eq "bio" ) {
        $it->addColSpec( "Pfam ID", "char asc", "left" );
    } else {
        $it->addColSpec( "COG ID", "char asc", "left" );
    }

    # function name column header
    if ( $type eq "bbh" ) {
        $it->addColSpec( "$title Name", "char asc", "left" );
    } elsif ( $type eq "pfam" ) {
        $it->addColSpec( "Pfam Name", "char asc", "left" );
    } elsif ( $type eq "bio" ) {
        $it->addColSpec( "Pfam Name", "char asc", "left" );
    } else {
        $it->addColSpec( "COG Name", "char asc", "left" );
    }

    $it->addColSpec( "Gene ID", "number asc", "right" );
    $it->addColSpec( "Conserved Neighborhood Viewer<br/>Centered on this Gene" );
    $it->addColSpec( "Gene Product Name", "char asc", "left" );

    my $sd = $it->getSdDelim();    # sort delimiter

    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";
    my $url2;
    if ( $type eq "pfam" ) {
        $url2 = "$pfam_base_url";
    } elsif ( $type eq "cog" ) {
        $url2 = "$cog_base_url";
    }

    # I must now ignore the function's that start with $NA
    my $func_count = 0;
    my $row_count  = 0;

    my %distinct_genes;
    foreach my $funcId ( keys %$func_href ) {
        $func_count += 1 if ( $funcId !~ /^$NA/ );

        my $aref = $func_href->{$funcId};
        foreach my $line (@$aref) {
            $row_count++;
            my ( $gene_oid, $name, $gene_name, $locus_tag ) =
              split( /\t/, $line );

            $distinct_genes{$gene_oid} = "";

            my $r;

            # see FuncCartStor.pm method webAddFuncs can be cog_id or func_id
            # for html code $sd first
            if ( $type eq "bbh" || $type eq 'bio' ) {
                # do nothing for now
            } elsif ( $funcId =~ /^$NA/ ) {
                # no selection box
                $r .= $sd . "&nbsp;" . "\t";
            } else {
                $r .= $sd . "<input type='checkbox' name='cog_id' " . "value='$funcId' />" . "\t";
            }

            # function id
            if ( $funcId =~ /^$NA/ ) {
                if ( $type eq "bbh" ) {
                    $r .= "99999999" . $sd . "_" . "\t";
                } else {
                    $r .= "zzzzzzzz" . $sd . "_" . "\t";
                }
            } elsif ( $type eq "bbh" || $type eq 'bio' ) {
                $r .= $funcId . $sd . $funcId . "\t";
            } elsif ( $type eq "pfam" ) {
                my $func_id2 = $funcId;
                $func_id2 =~ s/pfam/PF/;
                $r .= $funcId . $sd . "<a href='" . $url2 . $func_id2 . "'>  $funcId </a>" . "\t";
            } else {
                $r .= $funcId . $sd . "<a href='" . $url2 . $funcId . "'>  $funcId </a>" . "\t";
            }

            # function name
            if ( $funcId =~ /^$NA/ ) {
                $r .= "zzzzzzzz" . $sd . "_" . "\t";
            } else {
                $r .= $name . $sd . $name . "\t";
            }

            # gene id
            $r .= $gene_oid . $sd . "<a href='" . $url . $gene_oid . "'> $gene_oid</a>" . "\t";

            # selection box
            if ( $funcId =~ /^$NA/ ) {
                $r .= $sd . "&nbsp; \t";
            } else {
                # $r .= $sd
                # . getProteinSelection( "", "sbox$gene_oid",
                #  "selectCassetteNeigh(\"sbox$gene_oid\", $gene_oid)" )
                # . "\t";
                $locus_tag = "view" if ( $locus_tag eq "" );
                my $url = "main.cgi?section=GeneCassette" . "&page=geneCassette&gene_oid=$gene_oid&type=$type";
                $r .= $sd . "<a href='" . $url . "'>  $locus_tag </a>" . "\t";

            }

            # gene name
            $r .= $gene_name . $sd . "\t";
            $it->addRow($r);
        }
    }

    $it->printOuterTable(1);

    if ($type ne "bio") {
	# stats
	print "<p>\n";
	print $title . " count: " . $func_count;
	print "&nbsp;&nbsp; Gene count: " . keys(%distinct_genes);
	print "&nbsp;&nbsp; Row count: " . $row_count;
	print "</p>\n";
    }

    if ( $type eq "bbh" || $type eq 'bio' ) {
        # right now bbh cannot be added to function cart
    } else {
        #  printFuncCartFooter( 0, "Cog" );
        ##### ^--- removed in lieu of code below  -BSJ 04/14/10

        # multiple YUI tables on this page; so Select All and Clear All
        # buttons require specific ids to match table name
        # followed by 1 for Select and 0 for Clear
        print submit(
            -name  => "_section_FuncCartStor_addToFuncCart",
            -value => "Add Selected to Function Cart",
            -class => "meddefbutton"
        );
        print nbsp(1);
        print "<input id='" . $tableId
          . "1' type='button' name='selectAll' value='Select All' "
          . "onClick='selectAllCheckBoxesCog(1)' class='smbutton' /> ";
        print nbsp(1);
        print "<input id='" . $tableId
          . "0' type='button' name='clearAll' value='Clear All' "
          . "onClick='selectAllCheckBoxesCog(0)' class='smbutton' /> ";
        print "<br/>\n";
    }
}

# Gets cog pathway with highest gene count
#
# param
#   $dbh
#   $gene_oids_ref - array list of gene oids
# return - array list of strings "$id\t$name\t$cnt"
sub getCogPathwayMax {
    my ( $dbh, $gene_oids_ref, $delete ) = @_;

    my $str;
    if ( OracleUtil::useTempTable( scalar(@$gene_oids_ref) ) ) {

        # it should have inserted already - ken
        #OracleUtil::insertDataArray($dbh, "gtt_num_id", $gene_oids_ref);
        $str = "select id from gtt_num_id";
    } else {
        $str = join( ",", @$gene_oids_ref );
    }

    my $sql = qq{
        select cpm.cog_pathway_oid, cp.cog_pathway_name, count(*)
        from gene_cog_groups gcg, cog_pathway_cog_members cpm, cog_pathway cp
        where gcg.cog = cpm.cog_members
        and cpm.cog_pathway_oid = cp.cog_pathway_oid
        and gcg.gene_oid in ( $str )
        group by cpm.cog_pathway_oid, cp.cog_pathway_name
    };

    # what about equal gene counts?
    # should I return a array list
    my @result = ();
    my $max    = 0;
    my $cur    = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name, $cnt ) = $cur->fetchrow();
        last if !$id;
        if ( $cnt > $max ) {
            $max    = $cnt;
            @result = ();
        }

        if ( $cnt == $max ) {
            push( @result, "$id\t$name\t$cnt" );
        }
    }

    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $delete && OracleUtil::useTempTable( scalar(@$gene_oids_ref) ) );
    return \@result;
}

# Gets gene list given cassette and pathway oid
#
# param
#   $dbh
#   $cassette_oid
#   $pathway_oid
# return array ref of "$gid\t$gname"
sub getCogPathwayGeneList {
    my ( $dbh, $cassette_oid, $pathway_oid ) = @_;

    my $sql = qq{
        select g.gene_oid, g.gene_display_name
        from gene g, gene_cassette_genes gc,
        gene_cog_groups gcg, cog_pathway_cog_members cpm
        where g.gene_oid = gc.gene
        and gc.gene = gcg.gene_oid
        and gcg.cog = cpm.cog_members
        and cpm.cog_pathway_oid = ?
        and gc.cassette_oid = ?
        order by 1
    };

    my @result = ();
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid, $cassette_oid );
    for ( ; ; ) {
        my ( $gid, $gname ) = $cur->fetchrow();
        last if !$gid;
        push( @result, "$gid\t$gname" );
    }

    $cur->finish();

    return \@result;
}

# Gets cog functions given gene ids
#
# see global variable $NA
#
# param
# $dbh
# $gene_oids_ref - array list of gene oids
#
# return hash of cog id => array list of "geneoid \t functions"
sub getCogFunctions {
    my ( $dbh, $gene_oids_ref, $delete ) = @_;

    my $str;
    if ( OracleUtil::useTempTable( scalar(@$gene_oids_ref) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", $gene_oids_ref );
        $str = "select id from gtt_num_id";
    } else {
        $str = join( ",", @$gene_oids_ref );
    }

    my $sql = qq{
        select distinct $nvl(c.cog_id, '$NA' || g.gene_oid ),
        $nvl(c.cog_name, '$NA'), g.gene_oid, g.gene_display_name, g.locus_tag
        from gene g
        left join gene_cog_groups gcg on g.gene_oid = gcg.gene_oid
        left join cog c on gcg.cog = c.cog_id
        where g.gene_oid in ( $str )
    };

    my %cog_hash;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cog_id, $cog_name, $gene_oid, $gene_name, $locus_tag )
	    = $cur->fetchrow();
        last if !$cog_id;

        if ( exists( $cog_hash{$cog_id} ) ) {
            my $aref = $cog_hash{$cog_id};
            push( @$aref, "$gene_oid\t$cog_name\t$gene_name\t$locus_tag" );
        } else {
            my @a = ("$gene_oid\t$cog_name\t$gene_name\t$locus_tag");
            $cog_hash{$cog_id} = \@a;
        }
    }

    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $delete && OracleUtil::useTempTable( scalar(@$gene_oids_ref) ) );
    return \%cog_hash;
}

# Gets Pfam functions given gene ids
#
# see global variable $NA
#
# param
# $dbh
# $gene_oids_ref - aray list of genbe oids
#
# return hash of pfam id => array list of "geneoid \t functions \t gene name"
sub getPfamFunctions {
    my ( $dbh, $gene_oids_ref ) = @_;

    my @binds = ();
    my $size  = $#$gene_oids_ref + 1;
    my $str;
    if ( OracleUtil::useTempTable( scalar(@$gene_oids_ref) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", $gene_oids_ref );
        $str = "where g.gene_oid in ( select id from gtt_num_id )";
    } elsif ( $size == 1 ) {
        $str = "where g.gene_oid = ? ";
        push( @binds, $gene_oids_ref->[0] );
    } else {
        $str = join( ",", @$gene_oids_ref );
        $str = "where g.gene_oid in ( $str )";
    }

    my $sql = qq{
        select distinct $nvl(pf.ext_accession, '$NA' || g.gene_oid),
               $nvl(pf.name, '$NA' || g.gene_oid ),
               g.gene_oid, g.gene_display_name, g.locus_tag
        from gene g
        left join gene_pfam_families gpf on g.gene_oid = gpf.gene_oid
        left join pfam_family pf on gpf.pfam_family = pf.ext_accession
        $str
    };

    my %pfam_hash;

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $pfam_id, $defn, $gene_oid, $gene_name, $locus_tag )
	    = $cur->fetchrow();
        last if !$pfam_id;

        if ( exists( $pfam_hash{$pfam_id} ) ) {
            my $aref = $pfam_hash{$pfam_id};
            push( @$aref, "$gene_oid\t$defn\t$gene_name\t$locus_tag" );
        } else {
            my @a = ("$gene_oid\t$defn\t$gene_name\t$locus_tag");
            $pfam_hash{$pfam_id} = \@a;
        }
    }

    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( OracleUtil::useTempTable( scalar(@$gene_oids_ref) ) );
    return \%pfam_hash;
}

# Gets BBH functions given gene ids
#
# see global variable $NA
#
# param
# $dbh
# $gene_oids_ref - aray list of genbe oids
# $fusion_href - return hash of fusion gene to array of fused genes
#   - list can be the gene itself - which is not fusion gene in this case
# $include - optional flag - when set to 1, include the gene itself in the
# list of gene of bbh ids to find, not just the fused genes
# see GeneDetail::printProteinBBH()
#
# return
#   hash of id => array list of "geneoid \t functions \t gene name"
#
sub getBBHFunctions {
    my ( $dbh, $gene_oids_ref, $fusion_href, $include ) = @_;

    # this is my true list of genes - fusion genes not the child genes created
    # from the fused genes
    my @genes_list;

    printStartWorkingDiv();

    # find if gene is a fusion
    foreach my $gene_oid (@$gene_oids_ref) {
        print "Checking $gene_oid fusion status.<br>\n";
        my @fusion_genes;
        my %cycle;
        $cycle{$gene_oid} = "";

        getFusionGenes( $dbh, $gene_oid, \@fusion_genes, \%cycle );
        push( @genes_list, @fusion_genes );

        $fusion_href->{$gene_oid} = \@fusion_genes;

        # include gene itself - there can be duplicate gene ids
        # when the its not a fusion gene it will have
        # 2 duplicate genes if $include is set
        if ( $include ne "" && $include == 1 ) {
            push( @genes_list, $gene_oid );
        }
    }
    printEndWorkingDiv();

    my $str;
    if (OracleUtil::useTempTable( scalar(@genes_list) )) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@genes_list );
        $str = "select id from gtt_num_id";
    } else {
        $str = join( ",", @genes_list );
    }

    # find query
    my $sql = qq{
    select distinct $nvl(bc.cluster_id, '$NA' || g.gene_oid),
    $nvl(bc.cluster_name, '$NA' || g.gene_oid),
    g.gene_oid, g.gene_display_name, g.locus_tag
    from gene g
    left join bbh_cluster_member_genes bg on g.gene_oid = bg.member_genes
    left join bbh_cluster bc on bg.cluster_id = bc.cluster_id
    where g.gene_oid in ( $str )
    };

    my %cog_hash;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cog_id, $defn, $gene_oid, $gene_name, $locus_tag )
	    = $cur->fetchrow();
        last if !$cog_id;

        if ( exists( $cog_hash{$cog_id} ) ) {
            my $aref = $cog_hash{$cog_id};
            push( @$aref, "$gene_oid\t$defn\t$gene_name\t$locus_tag" );
        } else {
            my @a = ("$gene_oid\t$defn\t$gene_name\t$locus_tag");
            $cog_hash{$cog_id} = \@a;
        }
    }

    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
	if ( OracleUtil::useTempTable( scalar(@genes_list) ) );
    return \%cog_hash;
}

#
# Gets gene's orthologs - max list size my user preferences
# - ($maxNeighborhoods * 10) -  I do this because cassette with 1 gene should
# be ignored? see $MIN_GENES
#
# param
# $dbh
# $gene_oid
#
# return $count - count orthologs
# return \@recs - list of "$ortholog\t$panelStrand" with the query gene
#   as the first record
sub getOrthologs {
    my ( $dbh, $gene_oid, $type ) = @_;

    my $genomeCartFilter = param('genomeCartFilter');
    $maxNeighborhoods = getSessionParam("maxNeighborhoods")
	if getSessionParam("maxNeighborhoods") ne "";

    # replace ortholog table
    my $rclause   = urClause("tx");
    my $tclause   = txsClause( "tx", $dbh ) if($genomeCartFilter);
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select tx.taxon_oid
       from taxon tx
       where 1 = 1
       $rclause
       $tclause
       $imgClause
    };
    my %validTaxons;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $validTaxons{$taxon_oid} = 1;
    }

    webLog ">>> geneNeighborhood start\n";
    my @recs;
    my $count = 0;

    my @bbhRows = getBBHLiteRows( $gene_oid, \%validTaxons );
    my $i = -1;
    for my $r (@bbhRows) {
	$i++;
	my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend,
	     $sstart, $send, $evalue, $bitScore ) = split( /\t/, $r );
	my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
	my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
	my $gene_oid = $qgene_oid;
	my $ortholog = $sgene_oid;
	next if $slen > 1.3 * $qlen;
	next if $slen < 0.7 * $qlen;
	my $strand1 = getStrand( $dbh, $qgene_oid );
	my $strand2 = getStrand( $dbh, $sgene_oid );
	last if $count > $maxNeighborhoods;

	# find all cassette genes - do matching on function type later
	# NOTE - the neighborhood plot which only red box genes associated
	# to a function!
	if ( $MIN_GENES > 0 && $type ne 'bio') {
	    my $gcount = getGeneCassetteCount( $dbh, $ortholog, $type );

	    # min genes in a cassette check
	    #webLog("$i cassette gene count is $gcount record count $count\n");
	    next if ( $gcount < $MIN_GENES );
	}
	$count++;

	# push the user's selected gene id
	if ( $count == 1 ) {
	    my $rec = "$gene_oid\t+";
	    push( @recs, $rec );
	}
	my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
	my $rec = "$ortholog\t$panelStrand";
	push( @recs, $rec );
    }
    $cur->finish();

    if ( $count == 0 ) {
        printStatusLine( "Loaded.", 2 );
        #$dbh->disconnect();
        webError( "No orthologs for other gene neighborhoods found "
		. "for roughly the same sized gene." );
        return;
    }

    return ( $count, \@recs );
}

# Gets cassettes sorted for neighborhood plots
# Its sorted with most hits to query gene first
#
# param
# $dbh
# $gene_oid
#
# return ( $count, \@sort_recs, \%gene_cassette, \%gene_cassette_cnt )
# $count - count from getOrthologs();
# \@sort_recs - sorted array of tab delimited records "gene_oid\tstrand"
# \%gene_cassette - gene oid => array of records tab delimited
#   "$gene_oid\t$start_coord\t$end_coord\t$cog"
#
sub getSortedCassettes {
    my ( $dbh, $gene_oid, $type, $biosynthetic_id ) = @_;

    # get gene's Orthologs
    # array ref of "orthologs \t panel strand"
    # query gene is included in array too
    my ( $count, $recs_ref ) = getOrthologs( $dbh, $gene_oid, $type );

    # get cassette data and sort the records - not the 1st one since its the
    # query gene oid

    # gene oid => array of records tab delimited
    my %gene_cassette;

    # gene oid to gene cassette count
    my %gene_cassette_cnt;

    # hash list of all the cog ids in all cassettes
    # cog id => ""
    # NOTE this does not include those genes in the cassette box but not in
    # cassette table
    #my %cog_list;

    print "<div id='working'>\n";
    print "<p><font size=1>\n";

    # find all the gene cassettes
    foreach my $r (@$recs_ref) {
        my ( $tmp_gene_oid, $panelStrand ) = split( /\t/, $r );
        print "Getting cassette for $tmp_gene_oid...<br>\n";
        getGeneCassette( $dbh, $tmp_gene_oid, \%gene_cassette,
			 \%gene_cassette_cnt, $type, $biosynthetic_id );

        # rule 1. if no cassette on query gene - do not plot
        if (   $gene_oid == $tmp_gene_oid
            && $gene_cassette_cnt{$gene_oid} == 0 )
        {
            #$dbh->disconnect();
            print "</font></p></div>\n";
            printStatusLine( "Loaded.", 2 );
            webError( "Query gene $gene_oid cassette's genes have no $type association." );
        }
    }

    # end of working div
    print "</font></p></div>\n";
    WebUtil::clearWorkingDiv();

    my $query_gene_aref = $gene_cassette{$gene_oid};

    # hash list of query gene's cassette cog/func => ""
    # the query gene's cog/func itself is in the list too!
    my %query_gene_cassette_cog;
    foreach my $line (@$query_gene_aref) {
        my ( $tmp_gene_oid, $tmp_start_coord, $tmp_end_coord, $tmp_cog ) =
          split( /\t/, $line );

        # check the match for null func is ignored
        next if ( $tmp_cog eq "" );
        $query_gene_cassette_cog{$tmp_cog} = "";
    }

    # now change count to cog/func matches for sorting
    # where key is the gene oid or ortholog ids
    my %gene_cassette_cnt = ();
    foreach my $key ( keys %gene_cassette ) {
        #next if ( $key == $gene_oid );
        my $aref  = $gene_cassette{$key};
        my $count = 0;
        foreach my $line (@$aref) {
            my ( $tmp_gene_oid, $tmp_start_coord, $tmp_end_coord, $tmp_cog ) =
              split( /\t/, $line );
            # check the match for null func is ignored
            next if ( $tmp_cog eq "" );

            if ( exists( $query_gene_cassette_cog{$tmp_cog} ) ) {
                $count++;
            }
        }
        $gene_cassette_cnt{$key} = $count;
    }

    if ($type eq 'bio') { #anna
	return ( $count, $recs_ref, \%gene_cassette, \%gene_cassette_cnt );
    }

    # sort the hash gene cassette count by value desc.
    # Note the query gene is in the list
    my @sorted =
      sort { $gene_cassette_cnt{$b} <=> $gene_cassette_cnt{$a} }
      keys %gene_cassette_cnt;

    # now sort the @recs array, but leave the query gene 1st
    # first create a hash index
    # gene oid => array index location
    my %array_index;
    my $i = 0;
    foreach my $s (@sorted) {
        # skip the query gene oid
        next if ( $s == $gene_oid );
        $array_index{$s} = $i++;
    }

    my @sort_recs = @$recs_ref;
    foreach my $r (@$recs_ref) {
        my ( $tmp_gene_oid, $tmp_panelStrand ) = split( /\t/, $r );
        if ( $tmp_gene_oid == $gene_oid ) {
            next;
        }

        # remember query gene oid is index 0
        my $i = $array_index{$tmp_gene_oid} + 1;
        $sort_recs[$i] = $r;
    }

    return ( $count, \@sort_recs, \%gene_cassette, \%gene_cassette_cnt );
}

# print Neighborhoods page
#
#
# The coloring be functions type select not just COG!!!
#
#
#
sub printNeighborhoods {
    my($gene_oid1, $type1, $cluster_id, $noTitle) = @_;
    $noTitle = 0 if ($noTitle eq "");

    my $gene_oid = param("gene_oid");
    my $type = param("type");
    my $genomeCartFilter = param('genomeCartFilter');
    my $biosynthetic_id = param("biosynthetic_id");
    my $cassette_oid = param("cassette_oid");

    $gene_oid = $gene_oid1 if ($gene_oid1 ne '');
    $type = $type1 if ($type1 ne '');
    $biosynthetic_id = $cluster_id if $cluster_id ne '';
    $type = 'bio' if ($biosynthetic_id ne '');

    my $dbh = dbLogin();

    $type = "cog" if ($type eq "");

    checkGenePerm($dbh, $gene_oid);

    printMainForm();

    my $title = getTypeTitle($type);
    if (!$noTitle) {
	print "<h1>\n";
	print "Chromosomal Cassette By " . $title . "\n";
	print "</h1>\n";
    }

    if ($numTaxon) {
        if ($genomeCartFilter) {
	    my $url = "main.cgi?section=GeneCassette&page=geneCassette"
	            . "&gene_oid=$gene_oid&type=$type";
	    print qq{
            <p><a href='$url'>Remove Genome Cart Filter</a></p>
            };
        } else {
	    my $url = "main.cgi?section=GeneCassette&page=geneCassette"
		    . "&gene_oid=$gene_oid&type=$type&genomeCartFilter=1";
	    print qq{
            <p><a href='$url'>Filter by Genome Cart</a></p>
            };
        }
    }

    printStatusLine("Loading ...");

    if ( $gene_oid eq "" && $cassette_oid ne "" ) {
        # lets get any gene in the cassette since I need any gene from a
        # cassette to do most of my queries
        $gene_oid = getGeneViaCassetteOid( $dbh, $cassette_oid, $gene_oid );
    } elsif( $gene_oid eq "" && $biosynthetic_id ne "") {
        $gene_oid = getGeneViaBiosyntheticId
	    ( $dbh, $biosynthetic_id, $gene_oid );
    }

    my ( $count, $sort_recs_ref, $gene_cassette_ref, $gene_cassette_cnt_ref )
	= getSortedCassettes( $dbh, $gene_oid, $type, $biosynthetic_id );

    my $box = "cassette";
    $box = "cluster" if $type eq "bio";
    my $hint =
	 "Mouse over a gene to see details (once page has loaded).<br>"
       . "Click red dashed box <font color='red'>- - -</font> for "
       . "functions associated with this $box.<br>"
       . "Genes are colored by <u>$title</u> association.<br>"
       . "Yellow colored genes have <b>no</b> $title association";
    $hint .= " or an outside cassette box" if $type ne "bio";
    $hint .=
         ".<br/>Small <font color='red'>red</font> box indicates query gene"
       . "<br/>Sequence range is limited to $flank_length bps and centered "
       . "on query gene.<br>"
       . "Organisms are ordered by number of $title matches with query organism.";

    printHint($hint);
    print "<br/>\n";

    printNeighborhoodPanels
	( $dbh, "orth", $sort_recs_ref, $count, $gene_cassette_ref,
	  $type, $gene_cassette_cnt_ref, $biosynthetic_id );

    #$dbh->disconnect();
    print end_form();
}

# Gets scaffold oid, start and end
#
# param
# $dbh
# $gene_oid
#
# return ( $scaffold_oid, $start_coord, $end_coord )
sub getScaffold {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select g.scaffold, g.start_coord, g.end_coord
      from gene g
      where g.gene_oid = $gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $scaffold_oid, $start_coord, $end_coord ) = $cur->fetchrow();
    $cur->finish();

    return ( $scaffold_oid, $start_coord, $end_coord );
}

#
# Gets cassette's functions for a gene and cassette type
# get all genes in a cassette
#
# USED in neighborhood plots!
#
# NOTE cog id/func id can be NULL
#
# param $dbh - database handler
# param $gene_oid - query gene id
# param $gene_cassette_href - hash of array
#       gene oid => array of records tab delimited
#       Note one of the  cassette gene oid is the "gene oid" too
# param $gene_cassette_cnt_href - gene oid to gene cassette count, included in
#       the count is the query gene too, so real count is = count - 1
# param $type
sub getGeneCassette {
    my ( $dbh, $gene_oid, $gene_cassette_href, $gene_cassette_cnt_href,
	 $type, $biosynthetic_oid ) = @_;

    # first find the scaffold and the range that is plotted
    my $sql;
    my ( $scaffold_oid, $start_coord, $end_coord )
	= getScaffold( $dbh, $gene_oid );

    my $mid_coord = int(($end_coord - $start_coord) / 2) + $start_coord + 1;
    my $left_flank = $mid_coord - $flank_length + 1;
    my $right_flank = $mid_coord + $flank_length + 1;

    my $genes_href; # for bio

    # find the gene cassette
    if ( $type eq "pfam" ) {
        $sql = qq{
        select g.gene_oid, g.start_coord, g.end_coord, gp.pfam_family
        from gene g left join gene_pfam_families gp on g.gene_oid = gp.gene_oid
        where g.scaffold = ?
        and g.start_coord >= ?
        and g.end_coord <= ?
        and g.gene_oid in
            (select gcg2.gene
             from gene_cassette_genes gcg1, gene_cassette_genes gcg2
             where gcg1.cassette_oid = gcg2.cassette_oid
             and gcg1.gene = ?)
        };

    } elsif ( $type eq "bbh" ) {
        $sql = qq{
        select g.gene_oid, g.start_coord, g.end_coord, gb.cluster_id
        from gene g left join bbh_cluster_member_genes gb
                    on g.gene_oid = gb.member_genes
        where g.scaffold = ?
        and g.start_coord >= ?
        and g.end_coord <= ?
        and g.gene_oid in
            (select gcg2.gene
             from gene_cassette_genes gcg1, gene_cassette_genes gcg2
             where gcg1.cassette_oid = gcg2.cassette_oid
             and gcg1.gene = ?)
        };

    } else {
        $sql = qq{
        select g.gene_oid, g.start_coord, g.end_coord, dt.cog
        from gene g left join gene_cog_groups dt on g.gene_oid = dt.gene_oid
        where g.scaffold = ?
        and g.start_coord >= ?
        and g.end_coord <= ?
        and g.gene_oid in
            (select gcg2.gene
            from gene_cassette_genes gcg1, gene_cassette_genes gcg2
            where gcg1.cassette_oid = gcg2.cassette_oid
            and gcg1.gene = ?)
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid,
		       $left_flank, $right_flank, $gene_oid );

    my $count = 0;
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $start_coord, $end_coord, $cog ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        push( @recs, "$gene_oid\t$start_coord\t$end_coord\t$cog" );
    }
    $cur->finish();

    $gene_cassette_href->{$gene_oid}     = \@recs;
    $gene_cassette_cnt_href->{$gene_oid} = $count;
}

#
# Gets min and max of a cassette box
# return ( $scaffold_oid, $min, $max )
sub getGeneCassetteMinMax {
    my ( $dbh, $gene_oid, $type, $biosynthetic_id ) = @_;
    my ( $scaffold_oid, $start_coord, $end_coord )
	= getScaffold( $dbh, $gene_oid );

    my $sql = qq{
        select min(dt.start_coord), max(dt.end_coord)
        from gene dt
        where dt.scaffold = ?
        and dt.gene_oid in
            (select gcg2.gene
            from gene_cassette_genes gcg1, gene_cassette_genes gcg2
            where gcg1.cassette_oid = gcg2.cassette_oid
            and gcg1.gene = ?)
        };

    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid, $gene_oid );
    my ( $min, $max ) = $cur->fetchrow();
    return ( $scaffold_oid, $min, $max );
}

# gets number of genes in a cassette
#
# $type is NOT used
#
sub getGeneCassetteCount {
    my ( $dbh, $gene_oid, $type ) = @_;

    # let first find the scaffold and the range that is ploted
    my $sql = qq{
        select count(distinct gcg2.gene)
        from gene_cassette_genes gcg1, gene_cassette_genes gcg2
        where gcg1.cassette_oid = gcg2.cassette_oid
        and gcg1.gene = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($count) = $cur->fetchrow();
    return $count;
}

# Gets gene count defined by a cassette given a gene
# It counts gene defined by a cassette genes min max and counts
# genes not in cassette table
#
# I used this to test of $MAX_BOX_GENES
#
# $dbh
# $gene_oid
sub getGeneCounts {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
        select g.taxon, g.scaffold, min(g.start_coord), max(g.end_coord)
        from gene g, gene_cassette_genes gcg1, gene_cassette_genes gcg2
        where g.gene_oid = gcg2.gene
        and gcg1.cassette_oid = gcg2.cassette_oid
        and gcg1.gene = ?
        group by g.taxon, g.scaffold
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $taxon, $scaffold, $start, $end ) = $cur->fetchrow();
    $cur->finish();

    $sql = qq{
        select count(*)
        from gene g2
        where g2.taxon = ?
        and g2.scaffold = ?
        and g2.start_coord >= ?
        and g2.end_coord <= ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon, $scaffold, $start, $end );
    my ($count) = $cur->fetchrow();
    $cur->finish();
    return $count;
}

############################################################################
# printNeighborhoodPanels - Print the ScaffoldPanel's.
#   Print out the neighborhoods.
#   Inputs:
#     dbh - Database handle.
#     tag - Tag for temp files
#     recs_ref - Reference to information about records on genes.
#     count -  Current count of neighborhoods to be printed.
############################################################################
sub printNeighborhoodPanels {
    my ( $dbh, $tag, $recs_ref, $count, $gene_cassette_href,
	 $type, $gene_cassette_cnt_ref, $cluster_id ) = @_;

    ## Print neighborhoods
    foreach my $r (@$recs_ref) {
        my ( $gene_oid, $panelStrand ) = split( /\t/, $r );

        webLog "print gene_oid='$gene_oid' " . currDateTime() . "\n"
	    if $verbose >= 1;
        printOneNeighborhood( $dbh, $tag, $gene_oid, $panelStrand,
			      $gene_cassette_href, $type,
			      $gene_cassette_cnt_ref,
			      $cluster_id );
        print "<br/>\n";
    }

    #my $count2 = @$recs_ref;
    print "<br/>\n";
    if ( $count > $maxNeighborhoods ) {
        print "<p>\n";
        my $s = "Results limited to $maxNeighborhoods neighborhoods.\n";
        $s .=
          "( Go to " . alink( $preferences_url, "Preferences" )
	. " to change \"Max. Taxon Gene Neighborhoods\" limit. )";
        printStatusLine( $s, 2 );
    }
    #$dbh->disconnect();
    if ( $count <= $maxNeighborhoods ) {
        printStatusLine( "Loaded", 2 );
    }

    print "<script src='$base_url/overlib.js'></script>\n";
}

############################################################################
# printOneNeighborhood - Print one neighborhood for one ScaffoldPanel.
#   Inputs:
#      dbh - Database handle.
#      tag - Tag for temp files.
#      gene_oid0 - Original gene object identifier
#      panelStrand - Orientation of panel ( "+" or "-" )
#      groupColors_ref - Reference to mapping of COG to group colors.
############################################################################
sub printOneNeighborhood {
    my ( $dbh, $tag, $gene_oid0, $panelStrand, $gene_cassette_href,
	 $type, $gene_cassette_cnt_ref, $biosynthetic_oid ) = @_;

    my $sql = qq{
        select scf.scaffold_oid, scf.scaffold_name, ss.seq_length,
               g.start_coord, g.end_coord, g.strand,
               tx.taxon_oid, tx.taxon_display_name
        from gene g, scaffold scf, scaffold_stats ss, taxon tx
        where g.taxon = tx.taxon_oid
        and g.gene_oid = ?
        and g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
        and g.obsolete_flag = 'No'
        and g.start_coord > 0
        and g.end_coord > 0
        and scf.ext_accession is not null
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid0 );
    my ( $scaffold_oid, $scaffold_name, $scf_seq_length,
	 $start_coord0, $end_coord0, $strand0, $taxon_oid,
	 $taxon_display_name ) = $cur->fetchrow();
    return if !$scaffold_oid;

    my $scaffold_name2 = $scaffold_name;

    webLog "printOneNeighborhood: "
	 . "gene_oid=$gene_oid0 $start_coord0..$end_coord0 ($strand0) "
	 . "scaffold=$scaffold_oid\n";

    # how to center / anchor on gene for each plot
    my $mid_coord = int(($end_coord0 - $start_coord0) / 2) + $start_coord0 + 1;
    my $left_flank = $mid_coord - $flank_length + 1;
    my $right_flank = $mid_coord + $flank_length + 1;

    my $myOrder = "";
    if ( $strand0 eq "-" ) {
        $myOrder = "desc";
    }

    # TODO - fix pseudogene frag

    # query based on function type
    my $sql;
    if ( $type eq "pfam" ) {
        $sql = qq{
        select distinct g.gene_oid, g.gene_symbol, g.gene_display_name,
        g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
        g.aa_seq_length, gp.pfam_family, g.scaffold, g.is_pseudogene,
        g.cds_frag_coord
        from gene g left join gene_pfam_families gp on g.gene_oid = gp.gene_oid
        where g.scaffold = ?
        and (( g.start_coord >= ? and g.end_coord <= ? )
           or (( g.end_coord + g.start_coord ) / 2 >= ?
           and ( g.end_coord + g.start_coord ) / 2 <= ? ))
        order by g.start_coord, g.end_coord, gp.pfam_family $myOrder
        };

    } elsif ( $type eq "bbh" ) {
        $sql = qq{
        select distinct g.gene_oid, g.gene_symbol, g.gene_display_name,
        g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
        g.aa_seq_length, gb.cluster_id, g.scaffold, g.is_pseudogene,
        g.cds_frag_coord
        from gene g left join bbh_cluster_member_genes gb
        on g.gene_oid = gb.member_genes
        where g.scaffold = ?
        and (( g.start_coord >= ? and g.end_coord <= ? )
           or (( g.end_coord + g.start_coord ) / 2 >= ?
           and ( g.end_coord + g.start_coord ) / 2 <= ? ))
        order by g.start_coord, g.end_coord, gb.cluster_id $myOrder
        };

    } else {
        $sql = qq{
        select distinct g.gene_oid, g.gene_symbol, g.gene_display_name,
        g.locus_type, g.locus_tag, g.start_coord, g.end_coord, g.strand,
        g.aa_seq_length, dt.cog, g.scaffold, g.is_pseudogene, g.cds_frag_coord
        from gene g left join gene_cog_groups dt on g.gene_oid = dt.gene_oid
        where g.scaffold = ?
        and g.start_coord > 0
        and g.end_coord > 0
        and (( g.start_coord >= ? and g.end_coord <= ? )
           or (( g.end_coord + g.start_coord ) / 2 >= ?
           and ( g.end_coord + g.start_coord ) / 2 <= ? ))
        order by g.start_coord, g.end_coord, dt.cog $myOrder
        };
    }

    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid,
		       $left_flank, $right_flank, $left_flank, $right_flank );

    # duplicate pfam and bbh ids ???
    my %duplicate;        # function label too gene id => label
    my %duplicate_cnt;    # $start_coord-$end-$coord => count of func id
    my %cluster_genes;

    # genes i have drawn so far $start_coord-$end_coord=> count drawn so far
    my %drawn_genes;

    # IMPORTANT data should be shorted by start, end for box genes to work!
    my @all_genes;
    for ( ; ; ) {
        my (
            $gene_oid, $gene_symbol, $gene_display_name, $locus_type, $locus_tag,
            $start_coord, $end_coord, $strand, $aa_seq_length, $cluster_id,
            $scaffold, $is_pseudogene, $cds_frag_coord
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        push( @all_genes,
                "$gene_oid\t$gene_symbol\t$gene_display_name\t"
              . "$locus_type\t$locus_tag\t$start_coord\t"
              . "$end_coord\t$strand\t$aa_seq_length\t"
              . "$cluster_id\t$scaffold\t$is_pseudogene\t$cds_frag_coord" );

        if ( exists $duplicate{$gene_oid}) {
            # for the label to show all protein
            $duplicate{$gene_oid} = $duplicate{$gene_oid} . ", $cluster_id";
	    if ($type ne "bio") {
		$duplicate_cnt{"$start_coord-$end_coord"}
	        = $duplicate_cnt{"$start_coord-$end_coord"} + 1;
	    }
        } else {
            $duplicate{$gene_oid}                     = "$cluster_id";
            $duplicate_cnt{"$start_coord-$end_coord"} = 1;
            $drawn_genes{"$start_coord-$end_coord"}   = 0;
        }
    }
    $cur->finish();

    # lets see if the number of genes has more than $MAX_BOX_GENES
    my $gene_count = getGeneCounts( $dbh, $gene_oid0 );
    if ( $gene_count > $MAX_BOX_GENES ) {
        # put link on why circular
        #print "<p>Circular genome</p>";
        my $cid = getCassetteOidViaGene( $dbh, $gene_oid0 );
        my $url = "$section_cgi&page=cassetteList&cassette_oid=$cid" . "&type=$type";
        print "<p><font size=-1>";
        print "<a href='$url'>";
        print "<b>$scaffold_name</b> cassette has too many genes ($gene_count)!";
        print "</a><br>\n";
        print "Plot's length has been truncated to $flank_length.</font>";
        print "</p>";
    }

    my $tmp_recs_aref = $gene_cassette_href->{$gene_oid0};

    # find cassette min and max start and end
    my $min_cassette_start = -1;
    my $max_cassette_end   = -1;
    foreach my $line (@$tmp_recs_aref) {
        my ( $tmp_gene_oid, $tmp_start_coord, $tmp_end_coord, $tmp_cog ) =
          split( /\t/, $line );

        if ( $min_cassette_start == -1 ) {
            $min_cassette_start = $tmp_start_coord;
        }
        $min_cassette_start = $tmp_start_coord
          if ( $tmp_start_coord < $min_cassette_start );
        $max_cassette_end = $tmp_end_coord
          if ( $tmp_end_coord > $max_cassette_end );
    }

    # match count
    my $match_count = $gene_cassette_cnt_ref->{$gene_oid0};

    # panel strand defined by the centering genes direction
    # I did this here even though its pass in as a parameter, but
    # the query gene is always positive as i harded it in getOrthologs()
    # so i really need the query gene true direction
    # for others its correct - the $panelStrand
    $panelStrand = $strand0;

    # create a plot - one scaffold / taxon per plot
    my $args = {
        id => "gn.$type.$tag.$scaffold_oid.$start_coord0.x.$end_coord0.$$",
        start_coord        => $left_flank,
        end_coord          => $right_flank,
        coord_incr         => 5000,
        strand             => $panelStrand,
        title              => "$scaffold_name2 MATCHES $match_count",
        has_frame          => 1,
        gene_page_base_url => "$main_cgi?section=GeneDetail&page=geneDetail",
        color_array_file   => $env->{large_color_array_file},
        tmp_dir            => $tmp_dir,
        tmp_url            => $tmp_url,
        tx_url => "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid"
    };

    my $sp          = new GeneCassettePanel($args);
    my $color_array = $sp->{color_array};

    #print "<p>";
    foreach my $line (@all_genes) {
        my (
            $gene_oid, $gene_symbol, $gene_display_name, $locus_type, $locus_tag,
            $start_coord, $end_coord, $strand, $aa_seq_length, $cluster_id,
            $scaffold, $is_pseudogene, $cds_frag_coord
          )
          = split( /\t/, $line );

        # if drawn and outside cassette box just skip it
        if ( $drawn_genes{"$start_coord-$end_coord"} > 0
            && !( $start_coord >= $min_cassette_start
		  && $end_coord <= $max_cassette_end ) ) {
            next;
        }

	    next if ($type eq "bio" && $cluster_genes{$gene_oid}
		 && $cluster_id ne $biosynthetic_oid);

        my $label = $gene_symbol;
        $label = $locus_tag         if $label eq "";
        $label = " gene $gene_oid " if $label eq "";
        $label .= " : $gene_display_name ";
        $label .= " $start_coord..$end_coord ";

        if ( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length} aa)";
        } else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len} bp)";
        }

        my $color = $sp->{color_yellow};

        # genes in cassette box but not in cassette table
        if (   $start_coord >= $min_cassette_start
            && $end_coord <= $max_cassette_end )
        {
            if ( $cluster_id eq "" ) {
                $color = $sp->{color_yellow};
            } else {
                # get color based on function type
                if ( $type eq "pfam" ) {
                    $color = getPfamColor( $sp, $cluster_id );
                } elsif ( $type eq "bbh"  ) {
                    $color = getBBHColor( $sp, $cluster_id );
                } else {
                    $color = getCogColor( $sp, $cluster_id );
                }
            }
        }

        # All pseudo gene should be white - 2008-04-10 ken
        if ( uc($is_pseudogene) eq "YES" ) {
            $color = $sp->{color_white};
        }

        my $cog;
        # labels for outside box
	    my $item = $duplicate{$gene_oid};
        $cog = "($item)" if $item ne "";

        if ( $gene_oid eq $gene_oid0 &&
	     !(exists $cluster_genes{ $gene_oid }) ) {
           my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
           if ( scalar(@coordLines) > 1 ) {
                foreach my $line (@coordLines) {
                    my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                    my $tmp_label = $label . " $frag_start..$frag_end ${cog} ";
                    $sp->addBox( $frag_start, $frag_end, $sp->{color_red},
				    $strand, $gene_oid, $tmp_label );

                }
            } else {
                my $tmp_label = $label . " ${cog} ";

                # only draw the red box under the centering gene
                # only if the func id exist
                # - i removed above criteria - ken 2009-05-15
                $sp->addBox( $start_coord, $end_coord, $sp->{color_red},
			     $strand, $gene_oid, $tmp_label );

            }
        }

        # genes in cassette box
        if (   $start_coord >= $min_cassette_start
            && $end_coord <= $max_cassette_end
            && $duplicate_cnt{"$start_coord-$end_coord"} > 1 )
        {

            my $length = $end_coord - $start_coord;
            my $incr = int($length/$duplicate_cnt{"$start_coord-$end_coord"});
            my $tmp_start = $start_coord + $incr * $drawn_genes{"$start_coord-$end_coord"};
            my $tmp_end = $tmp_start + $incr;

            if ($strand eq "-" && $drawn_genes{"$start_coord-$end_coord"} > 0) {
                $cog = "($cluster_id)" if ( $cluster_id ne "" );
                $label .= " ${cog} ";

                my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
                if ( scalar(@coordLines) > 1 ) {
                    foreach my $line (@coordLines) {
                        my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                        my $tmp_label = $label . " $frag_start..$frag_end ";
                        $sp->addGene2( $gene_oid, $frag_start, $frag_end, $strand, $color, $tmp_label );
                    }
                } else {
                    $sp->addGene2( $gene_oid, $tmp_start, $tmp_end, $strand, $color, $label );

                }

            } elsif ( $strand eq "+"
                && $drawn_genes{"$start_coord-$end_coord"} < ( $duplicate_cnt{"$start_coord-$end_coord"} - 1 ) )
            {

                $cog = "($cluster_id)" if ( $cluster_id ne "" );
                $label .= " ${cog} ";

                my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
                if ( scalar(@coordLines) > 1 ) {
                    foreach my $line (@coordLines) {
                        my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                        my $tmp_label = $label . " $frag_start..$frag_end ";
                        $sp->addGene2( $gene_oid, $frag_start, $frag_end, $strand, $color, $tmp_label );

                    }
                } else {
                    $sp->addGene2( $gene_oid, $tmp_start, $tmp_end, $strand, $color, $label );
                }

            } else {
                if ( $gene_oid ne $gene_oid0 ) {
                    my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
                    if ( scalar(@coordLines) > 1 ) {
                        foreach my $line (@coordLines) {
                            my ( $frag_start, $frag_end ) =
                              split( /\.\./, $line );
                            my $tmp_label = $label . " $frag_start..$frag_end ${cog} ";
                            $sp->addBox( $frag_start, $frag_end, $sp->{color_white}, $strand, $gene_oid, $tmp_label );
                        }
                    } else {
                        my $tmp_label = $label . " ${cog} ";
                        $sp->addBox( $start_coord, $end_coord, $sp->{color_white}, $strand, $gene_oid, $tmp_label );
                    }
                }

                $cog = "($cluster_id)" if ( $cluster_id ne "" );
                $label .= " ${cog} ";

                my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
                if ( scalar(@coordLines) > 1 ) {
                    foreach my $line (@coordLines) {
                        my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                        my $tmp_label = $label . " $frag_start..$frag_end ";
                        $sp->addGene( $gene_oid, $frag_start, $frag_end, $strand, $color, $tmp_label );
                    }
                } else {
                    # have not drawn the 1st one yet for neg strang
                    # for positive draw this one until last one
                    $sp->addGene( $gene_oid, $tmp_start, $tmp_end, $strand, $color, $label );
                }
            }

        } else {
            # draw the end arrow head
            $label .= " ${cog} ";

            my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
            if ( scalar(@coordLines) > 1 ) {
                foreach my $line (@coordLines) {
                    my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                    my $tmp_label = $label . " $frag_start..$frag_end ";
                    $sp->addGene( $gene_oid, $frag_start, $frag_end, $strand, $color, $tmp_label );
                }
            } else {
                $sp->addGene( $gene_oid, $start_coord, $end_coord, $strand, $color, $label );
            }
        }

        $drawn_genes{"$start_coord-$end_coord"} = $drawn_genes{"$start_coord-$end_coord"} + 1;
    }

    my $bracketType1 = "left";
    my $bracketType2 = "right";
    if ( $panelStrand eq "-" ) {
        $bracketType1 = "right";
        $bracketType2 = "left";
    }
    if ( $left_flank <= 1 ) {
        $sp->addBracket( 1, $bracketType1 );
    }
    if ( $left_flank <= $scf_seq_length && $scf_seq_length <= $right_flank ) {
        $sp->addBracket( $scf_seq_length, $bracketType2 );
    }

    if ( $min_cassette_start != -1 && $max_cassette_end != -1 ) {
	my $box = "cassette box";
	$box = "cluster box" if $type eq "bio";
        $sp->addCassetteBox($min_cassette_start, $max_cassette_end, $gene_oid0,
			    "$gene_oid0 $box $min_cassette_start..$max_cassette_end ",
			    $type, $biosynthetic_oid);
    }

    #    print "<p><font size=-1>";
    #    print "$scaffold_name2 MATCHES $match_count";
    #    print "</font></p>";

    my $s = $sp->getMapHtml("overlib");
    print "$s\n";
}

#
# Gets cog color
# Now there are 4000+ cog but only 246 colors less yellow and red
# So, lets map the cog num to a color
# param
# $sp - perl object GeneCassettePanel2 or GeneCassettePanel
# $cog = fucntion id
sub getCogColor {
    my ( $sp, $cog ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    if ( $cog eq "" || $cog !~ /^COG/ || $cog =~ /^$NA/ ) {

        #webLog("No cog color is yellow\n");
        return $sp->{color_yellow};
    }

    # remove COG from COG1234
    #
    # max number
    # 9 * 2 ^ 3 + 9 * 2 ^ 2  +9 * 2 ^ 1 + 9 * 2 ^ 0 = 135
    my $cog_num = substr( $cog, 3 );
    my @a = split( / */, $cog_num );
    @a = reverse(@a);

    #print Dumper \@a;
    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];

    if ( $color == $sp->{color_yellow} ) {
        $color = $color_array->[ $sum % 100 + 136 ];
    } elsif ( $color == $sp->{color_red} ) {
        $color = $color_array->[ $sum % 100 + 136 ];
    }

    return $color;
}

sub getCogColorIndex {
    my ( $sp, $cog ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    # remove COG from COG1234
    # 9 * 2 ^ 3 + 9 * 2 ^ 2  +9 * 2 ^ 1 + 9 * 2 ^ 0 = 135
    my $cog_num = substr( $cog, 3 );
    my @a = split( / */, $cog_num );
    @a = reverse(@a);

    #print Dumper \@a;
    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];

    if ( $color == $sp->{color_yellow} ) {
        $sum = $sum % 100 + 136;
    } elsif ( $color == $sp->{color_red} ) {
        $sum = $sum % 100 + 136;
    }

    return $sum;
}

#
# Gets pfam color
#
sub getPfamColor {
    my ( $sp, $pfam ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    if ( $pfam eq "" || $pfam =~ /^$NA/ ) {
        return $sp->{color_yellow};
    }

    # remove pfam from pfam00923
    # there may be more than one pfam, comma-separated; use first one
    my $pfam_num = substr( $pfam, 4, 5 );
    my @a = split( / */, $pfam_num );
    @a = reverse(@a);

    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];
    if ( $color == $sp->{color_yellow} ) {
        $color = $sp->{color_blue};
    } elsif ( $color == $sp->{color_red} ) {
        $color = $sp->{color_blue};
    }

    return $color;
}

sub getPfamColorIndex {
    my ( $sp, $pfam ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    my $pfam_num = substr( $pfam, 4 );
    my @a = split( / */, $pfam_num );
    @a = reverse(@a);

    #print Dumper \@a;
    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];
    if ( $color == $sp->{color_yellow} ) {
        $sum = -2;
    } elsif ( $color == $sp->{color_red} ) {
        $sum = -2;
    }

    return $sum;
}

sub getBBHColor {
    my ( $sp, $bbh ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    if ( $bbh eq "" || $bbh =~ /^$NA/ ) {
        return $sp->{color_yellow};
    }

    my @a = split( / */, $bbh );
    @a = reverse(@a);

    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];
    if ( $color == $sp->{color_yellow} ) {
        $color = $sp->{color_blue};
    } elsif ( $color == $sp->{color_red} ) {
        $color = $sp->{color_blue};
    }

    return $color;
}

sub getBBHColorIndex {
    my ( $sp, $bbh ) = @_;
    my $color_array = $sp->{color_array};
    my $color;

    my @a = split( / */, $bbh );
    @a = reverse(@a);

    #print Dumper \@a;
    my $sum = 0;
    my $i   = 0;
    foreach my $x (@a) {
        $sum = $sum + ( $x * ( 2**$i ) );
        $i++;
    }
    $color = $color_array->[$sum];
    if ( $color == $sp->{color_yellow} ) {
        $sum = -2;
    } elsif ( $color == $sp->{color_red} ) {
        $sum = -2;
    }

    return $sum;
}

sub printJavaScript {
    print qq{
    <script language='JavaScript' type="text/javascript">
    function selectAllCheckBoxesCog( x ) {
        var f = document.mainForm;
        for( var i = 0; i < f.length; i++ ) {
            var e = f.elements[ i ];
            if( e.type == "checkbox" ) {
                e.checked = ( x == 0 ? false : true );
            }
        }
    }
    </script>
    };
}

# Gets genes fused to make the given gene_oid
#
# param
# $dbh
# $gene_oid - this might be a fusion gene
# $gene_aref - return list of genes, if gene_oid is in the list
#   then it was not a fusion gene
#
# $cycle_href - list of genes already checked for fusion status
#   used to avoid recursvie cycle calls
#   when initially called, you should add initial $gene_oid to $cycle_hrefgetFusionGenes
#
# depricated - 2008-04-09 - we do not need to find fusion - ken
sub getFusionGenes {
    my ( $dbh, $gene_oid, $gene_aref, $cycle_href ) = @_;

    # find fusion flag
    # 1 to find fusion
    # 0 to not find fusion
    # return the gene oid itself in the array
    if ( $FIND_FUSION == 0 ) {
        push( @$gene_aref, $gene_oid );
        return;
    }

    my @list;
    my $sql = qq{
        select gene_oid, component
        from gene_fusion_components
        where gene_oid = ?
        order by query_start
    };

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ( $gene, $component ) = $cur->fetchrow();
        last if !$gene;

        next if ( exists $cycle_href->{$component} );
        $cycle_href->{$component} = "";
        push( @list, $component );
    }
    $cur->finish();

    if ( $#list < 0 ) {
        # not a fusion gene
        push( @$gene_aref, $gene_oid );
    } else {
        foreach my $id (@list) {
            getFusionGenes( $dbh, $id, $gene_aref, $cycle_href );
        }
    }
}

# Gets all bbh cluster id from a list of genes
#
# param
# $dbh
# $gene_aref - list of gene oids
# return hash of gene oid => cluster id
#
# DEPRICATED - we do not need to find fusion - 2008-04-09 - ken
sub getBBHClusterId {
    my ( $dbh, $gene_aref ) = @_;

    my $ORACLEMAX = WebUtil::getORACLEMAX();

    my %hash;
    my $sql;

    # must check query, this might return gene id to mulitple cluster ids
    # when fusion addded
    if ( $#$gene_aref < $ORACLEMAX ) {
        my $str = join( ",", @$gene_aref );
        $sql = qq{
        select cluster_id, member_genes
        from bbh_cluster_member_genes
        where member_genes in ($str)
        };
    } else {
        my $tmpsql = qq{
        select cluster_id, member_genes
        from bbh_cluster_member_genes
        where member_genes in (_XXX_)
        };

        $sql = WebUtil::bigInQuery( $tmpsql, "_XXX_", $gene_aref );
    }

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cluster_id, $member_genes ) = $cur->fetchrow();
        last if !$cluster_id;
        $hash{$member_genes} = $cluster_id;
    }
    $cur->finish();

    return \%hash;
}

# Gets all bbh cluster info from a list of genes
#
# param
# $dbh
# $gene_aref - list of gene oids
# return array of gene oid \t cluster id \t func name
#
# see GeneDetails - its using it to get bbh list
sub getBBHClusterInfo {
    my ( $dbh, $gene_aref ) = @_;

    my @binds = ();
    my $size  = $#$gene_aref + 1;
    my @array;

    # this might return gene id to mulitple cluster ids
    # when fusion addded

    my $str;
    if ( OracleUtil::useTempTable( scalar(@$gene_aref) ) ) {
        OracleUtil::insertDataArray( $dbh, "gtt_num_id", $gene_aref );
        $str = "and bg.member_genes in ( select id from gtt_num_id )";
    } elsif ( $size == 1 ) {
        $str = "and bg.member_genes in = ? ";
        push( @binds, $gene_aref->[0] );
    } else {
        $str = join( ",", @$gene_aref );
        $str = "and bg.member_genes in ( $str )";
    }

    my $sql = qq{
    select distinct bg.member_genes, bc.cluster_id, bc.cluster_name
    from bbh_cluster_member_genes bg, bbh_cluster bc
    where bg.cluster_id = bc.cluster_id
    $str
    order by bg.member_genes, bc.cluster_id
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ( $gid, $cid, $name ) = $cur->fetchrow();
        last if !$gid;
        push( @array, "$gid\t$cid\t$name" );
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) if ( OracleUtil::useTempTable( scalar(@$gene_aref) ) );

    return \@array;
}

#
# prints cassette's or operon's selection box
#
# $label - text before selection bos - can be null
# $name - html selection name
# $jsFunction - onchange javascript to call
# see GeneCassette
sub printProteinSelection {
    my ( $label, $name, $jsFunction, $dbh, $gene_oid ) = @_;

    print "$label &nbsp;\n" if ( $label ne "" );

    print qq{
        <select name='$name' onChange='$jsFunction'>
        <option value="label" selected>-- Select Protein Cluster
        --&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>
        <option value="cog">COG</option>
    };

    if ($include_cassette_bbh) {
        print qq{
        <option value="bbh" title="Bidirectional Best hits (MCL)">IMG Ortholog Cluster</option>
        };
    }

    if ($include_cassette_pfam) {
        print qq{
        <option value="pfam">Pfam</option>
        };
    }

    if($enable_biocluster) {
    my $include_cassette_bioSyn = isBioSynGene($dbh, $gene_oid);
    if ($include_cassette_bioSyn) {
        print qq{
        <option value="bio">Biosynthetic Cluster</option>
        };
    }
    }

    print qq{
        </select>
    };

    # <option value="bbh">Bidirectional Best hits (MCL)</option>
}

sub isBioSynGene {
    my ($dbh, $gene_oid) = @_;
    return 0  if ($dbh eq '' || $gene_oid eq '');

    my $sql = qq{
        select bcg.gene_oid
        from bio_cluster_features_new bcg
        where bcg.feature_type = 'gene'
        and bcg.gene_oid = ?
        and rownum = 1
    };


    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $cid ) = $cur->fetchrow();
    $cur->finish();
    if($cid ne '') {
        return 1;
    } else {
        return 0;
    }
}

# same as printProteinSelection but instead of printing it returns the string
sub getProteinSelection {
    my ( $label, $name, $jsFunction ) = @_;

    my $str = "";
    $str = "$label &nbsp;" if ( $label ne "" );

    $str .= qq{
        <select name='$name' onChange='$jsFunction'>
        <option value="label" selected>-- Select Protein Cluster
        --&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</option>
        <option value="cog">COG</option>
    };

    if ($include_cassette_bbh) {
        $str .= qq{
        <option value="bbh" title="Bidirectional Best hits (MCL)">IMG Ortholog Cluster</option>
    };
    }

    if ($include_cassette_pfam) {
        $str .= qq{
        <option value="pfam">Pfam</option>
    };
    }
    $str .= qq{
        </select>
    };

    return $str;
}

# get gene count Occurrence for a taxon
sub getGeneCountOccurrence {
    my ( $dbh, $taxon_oid ) = @_;

    #  slow query
    my $sql = qq{
    select a.cnt as gene_count, count(*) as occurrence
    from (
        select gcg.cassette_oid, count(gcg.gene) as cnt
        from gene_cassette_genes gcg, gene g
        where g.gene_oid = gcg.gene
        and g.taxon = ?
        group by gcg.cassette_oid
        ) a
    group by a.cnt
    order by 1 desc
    };

    my @recs;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ; ; ) {
        my ( $gene_count, $occurrence ) = $cur->fetchrow();
        last if !$gene_count;
        push( @recs, "$gene_count\t$occurrence" );
    }
    $cur->finish();

    return \@recs;
}

sub printCassetteOccurrence {
    my $taxon_oid = param("taxon_oid");

    my $dbh       = dbLogin();
    my $taxonName = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    print "<h1>\n";
    print "IMG Chromosomal Cassette Occurrence for<br/>\n";
    print "$taxonName";
    print "</h1>\n";

    printStatusLine("Loading ...");

    my $rec_aref = getGeneCountOccurrence( $dbh, $taxon_oid );
    #$dbh->disconnect();

    my $it = new InnerTable( 1, "cassetteOccur$$", "cassetteOccur", 1 );
    $it->addColSpec( "Gene Count", "number desc", "right" );
    $it->addColSpec( "Occurrence", "number asc",  "right" );
    my $sd = $it->getSdDelim();    # sort delimiter

    my $total_gene = 0;
    foreach my $line (@$rec_aref) {
        my ( $gene_count, $occurrence ) = split( /\t/, $line );
        $total_gene += ( $gene_count * $occurrence );

        my $url =
            "<a href='$section_cgi&page=occurrenceGeneList"
          . "&taxon_oid=$taxon_oid"
          . "&genecount=$gene_count"
          . "'> $gene_count </a>";

        my $r;
        $r .= $gene_count . $sd . $url . "\t";
        $r .= $occurrence . $sd . "\t";
        $it->addRow($r);
    }

    $it->printOuterTable(1);

    print qq{
        <p>
        Gene count: $total_gene
        </p>
    };

    my $count = $#$rec_aref + 1;
    printStatusLine( "$count Loaded", 2 );
}

sub printOccurrenceGeneList {
    my $taxon_oid  = param("taxon_oid");
    my $genecount = param("genecount");

    printMainForm();
    print hiddenVar( "taxon_oid", $taxon_oid ) if ( $taxon_oid );
    print hiddenVar( "genecount", $genecount ) if ( $genecount );

    print "<h1>\n";
    print "Chromosomal Cassette Gene List\n";
    print "</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my ($sql, @binds) = QueryUtil::getSingleTaxonCassetteOccurrenceGenesSql($taxon_oid, $genecount);
    #TaxonDetailUtil::printGeneListSectionSorting( $sql, "Gene Cassette List", "", @binds );
    my ( $count, $s ) = TaxonDetailUtil::printGeneListSectionSortingCore( $sql, @binds );

    if ($count > 0) {
        my $select_id_name = 'gene_oid';
        WorkspaceUtil::printSaveGeneToWorkspace_withAllCassetteOccurrenceGenes($select_id_name);
    }

    printStatusLine( $s, 2 );
    print end_form();

}

sub getStrand {
    my ( $dbh, $gene_oid ) = @_;

    my $sql = qq{
       select strand
       from gene
       where gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($strand) = $cur->fetchrow();
    $cur->finish();
    return $strand;
}


1;


