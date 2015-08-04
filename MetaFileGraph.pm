############################################################################
#
# MetaFileGraph: metagenome phylo distribution (file version)
#
# package to draw 2 recur plots and scatter plot
# $Id: MetaFileGraph.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
############################################################################
package MetaFileGraph;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw( 
);

use strict;

use CGI qw( :standard );
use DBI;
use MetagGraphPanel;
use ScaffoldPanel;
use Data::Dumper;
use WebConfig;
use WebUtil;
use POSIX qw(ceil floor);

use MetagJavaScript;
use HtmlUtil;
use QueryUtil;
use PhyloUtil;
use GraphUtil;

my $section              = "MetaFileGraph";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $tmp_url              = $env->{tmp_url};
my $tmp_dir              = $env->{tmp_dir};
my $verbose              = $env->{verbose};
my $web_data_dir         = $env->{web_data_dir};
my $base_url             = $env->{base_url};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $user_restricted_site = $env->{user_restricted_site};
my $YUI                  = $env->{yui_dir_28};
my $yui_tables           = $env->{yui_tables};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    my $dbh  = dbLogin();

    my $sid       = getContactOid();
    my $taxon_oid = param("taxon_oid");

    HtmlUtil::cgiCacheInitialize( $section);
    HtmlUtil::cgiCacheStart() or return;

    if ( $page eq "fragRecView1" ) {
        GraphUtil::printFragment($dbh, $section);
    } elsif ( $page eq "fragRecView2" ) {

        # future button
        GraphUtil::printProtein($dbh, $section);
    } elsif ( $page eq "fragRecView3" ) {

        # can be 'all', 'pos' or 'neg'
        my $strand = param("strand");
        printScatter( $dbh, $strand );
    } elsif ( $page eq "binscatter" ) {
        GraphUtil::printBinScatterPlot($dbh, $section);
    } elsif ( $page eq "binfragRecView1" ) {
        GraphUtil::printBinFragment($dbh, $section);
    } elsif ( $page eq "binfragRecView2" ) {
        GraphUtil::printBinProtein($dbh, $section);
    } else {
        my $family = param("family");
        print "family $family\n";
    }

    #$dbh->disconnect();
    HtmlUtil::cgiCacheStop();
}




#
# creates scatter plot page
#
# param $dbh datbase handler
# param others see url
#
# $strand - all, pos or neg
#
sub printScatter {
    my ( $dbh, $strand ) = @_;

    # this is te query taxon id
    my $taxon_oid = param("taxon_oid");
    my $domain    = param("domain");
    my $phylum    = param("phylum");
    my $ir_class  = param("ir_class");
    my $ir_order  = param("ir_order");
    my $family    = param("family");
    my $species   = param("species");
    my $genus     = param("genus");
    my $range     = param("range");

    my $tname = QueryUtil::fetchTaxonName( $dbh, $taxon_oid );

    print "<h1>Protein Recruitment Plot<br>$tname</h1>\n";

    print "<p>\n";
    print "$family $genus $species\n";
    print "<font size=1>";
    print "<br><font color='red'>Red 90%</font>\n";
    print "<br><font color='green'>Green 60%</font>\n";
    print "<br><font color='blue'>Blue 30%</font>\n";
    print "</font>";
    print "<p>\n";

    printMainForm();
    printStatusLine("Loading ...");

    my @records;
    my $geneoids_href;    # =
        #getPhylumGeneOids( $dbh, $taxon_oid, $domain, $phylum, $ir_class );

    my $min1;
    my $max1;

    if ( $range eq "" ) {

        # gets min max of start and end coord of metag on ref genome
        ( $min1, $max1 ) = GraphUtil::getPhylumGenePercentInfoMinMax(
              $dbh,    $taxon_oid, 
              $domain, $phylum, $ir_class, $ir_order, 
              $family, $genus, $species, "" );
    } else {
        ( $min1, $max1 ) = split( /-/, $range );
    }

    GraphUtil::getPhylumGenePercentInfo(
          $dbh,    $taxon_oid, 
          $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species,
          \@records, $min1,      $max1,   ""
    );

    my $seq_length = $max1 - $min1 + 1;

    $seq_length = $max1 if ( $range eq "" );

    my $xincr = ceil( $seq_length / 10 );

    if ( $strand eq "pos" ) {
        print "<p>Positive Strands Plot<p>\n";
        if ( $range eq "" ) {
            GraphUtil::drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr,
                              "+" );
        } else {
            GraphUtil::drawScatterPanel( $min1, $max1, \@records, $geneoids_href, $xincr,
                              "+" );
        }
    } elsif ( $strand eq "neg" ) {
        print "<p>Negative Strands Plot<p>\n";
        if ( $range eq "" ) {
            GraphUtil::drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr,
                              "-" );
        } else {
            GraphUtil::drawScatterPanel( $min1, $max1, \@records, $geneoids_href, $xincr,
                              "-" );
        }
    } else {
        print "<p>All Strands Plot<p>\n";
        if ( $range eq "" ) {
            GraphUtil::drawScatterPanel( 0, $seq_length, \@records, $geneoids_href, $xincr,
                              "+-" );
        } else {

            #  test zoom selection
            GraphUtil::drawScatterPanel( $min1, $max1, \@records, $geneoids_href, $xincr,
                              "+-" );
        }
    }

    print toolTipCode();

    # zoom for nomral plots and xincr must be greater than 5000
    if ( $xincr > 5000 && param("size") eq "" ) {
        print "<p>View Range &nbsp;&nbsp;";
        print "<SELECT name='zoom_select" . "' "
          . "onChange='plotZoom(\"$main_cgi\")'>\n";

        print "<OPTION value='-' selected='true'>-</option>";
        for ( my $i = $min1 ; $i <= $max1 ; $i = $i + $xincr ) {
            my $tmp = $i + $xincr;
            print "<OPTION value='$i-$tmp'>$i .. $tmp</option>";
        }

        #print "<OPTION value='$i,$tmp'>"
        #."$i .. $metag_end_coord</option>";
        print "</SELECT>";

        MetagJavaScript::printMetagSpeciesPlotJS();

        print hiddenVar( "family",    $family );
        print hiddenVar( "taxon_oid", $taxon_oid );
        print hiddenVar( "domain",    $domain );
        print hiddenVar( "phylum",    $phylum );
        print hiddenVar( "ir_class",  $ir_class );
        print hiddenVar( "genus",     $genus );
        print hiddenVar( "species",   $species );
        print hiddenVar( "range",     $range );
        print hiddenVar( "strand",    $strand );
    }
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

1;
