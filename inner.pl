############################################################################
# inner.pl - Inner HTML CGI for AJAX frame presentation.
#   Note, this is an HTML server, not a data server.
#     --es 08/30/2005
#
# $Id: inner.pl 30841 2014-05-08 04:32:57Z klchu $
############################################################################
use strict;
use CGI qw( :standard );
use CGI::Session qw/-ip-match/;    # for security - ken
use Data::Dumper;
use Digest::MD5 qw( md5_base64 );
use perl5lib;
use WebConfig;
use WebUtil;
use TaxonSearch;

$| = 1;
my $verbose = 1;

my $env = getEnv();

blockRobots();

############################################################################
# main
############################################################################

my $cgi = WebUtil::getCgi();
print header( -type => "text/html" );
my $linkTarget = param("linkTarget");
webLog "inner.cgi linkTarget='$linkTarget'\n" if $verbose >= 1;
setLinkTarget($linkTarget);
my $section = param("section");
$section = getSection() if $section eq "";
my $iframe = param("iframe");
if ( $section eq "GeneCartDataEntry" ) {
    require GeneCartDataEntry;
    GeneCartDataEntry::dispatch();
} elsif ( $section eq "ImgTermCartDataEntry" ) {
    require ImgTermCartDataEntry;
    ImgTermCartDataEntry::dispatch();
} elsif ( $section eq "ImgPwayCartDataEntry" ) {
    require ImgPwayCartDataEntry;
    ImgPwayCartDataEntry::dispatch();
} elsif ( $iframe eq "innerTable" ) {
    require InnerTable;
    my $id      = param("id");
    my $sortIdx = param("sortIdx");
    my $it      = new InnerTable( 0, $id, $sortIdx );
    $it->printInnerTable();
} elsif ( $section eq "MetagenomeHits" ) {

    # ken tree testing code hook
    require MetagenomeHits;

    # for download add if paramMatch( "noHeader" ) eq "";
    MetagenomeHits::dispatch();

} elsif ( $section eq "TaxonDetail" ) {

    # ken tab pages
    require TaxonDetail;
    TaxonDetail::dispatch();
} elsif ( $section eq "GeneCartStor" ) {

    # ken tab pages
    require GeneCartStor;
    GeneCartStor::dispatch();
} elsif ( $section eq "FuncCartStor" ) {

    # ken tab pages
    require FuncCartStor;
    FuncCartStor::dispatch();
} elsif ( $section eq "CompareGenomes" ) {

    # ken tab pages
    require CompareGenomes;
    CompareGenomes::dispatch();
} elsif ( $section eq "GeneDetail" ) {

    # ken tab pages
    require GeneDetail;
    GeneDetail::dispatch();
} elsif ( $section eq "ImgTermAndPathTab" ) {
    require ImgTermAndPathTab;
    ImgTermAndPathTab::dispatch();

} else {
    print "Unknown iframe='$iframe'\n";
}
WebUtil::webExit(0);

############################################################################
# printStyle
############################################################################
sub printStyle {
    print "<style type='text/css'>\n";
    print "\@import url('img.css');\n";
    print "\@import url('imgApp.css');\n";
    print "</style>\n";
}

############################################################################
# getSection - Get section from other mappings, such as from submit().
############################################################################
sub getSection {
    my $section = param("section");
    if ( param("sectionGeneCartDataEntry") ne "" ) {
        $section = "GeneCartDataEntry";
        param( "page", "index" );
    } elsif ( param("sectionGeneCartDataEntryUpload") ne "" ) {
        $section = "GeneCartDataEntry";
        param( "page", "fileUpload" );
    } elsif ( param("sectionImgTermCartDataEntry") ne "" ) {
        $section = "ImgTermCartDataEntry";
        param( "page", "index" );
    } elsif ( param("sectionImgPwayCartDataEntry") ne "" ) {
        $section = "ImgPwayCartDataEntry";
        param( "page", "index" );
    } elsif ( param("sectionGeneCartChrViewer") ne "" ) {
        $section = "GeneCartChrViewer";
        param( "page", "index" );
    }
    param( "section", $section );
    return $section;
}

