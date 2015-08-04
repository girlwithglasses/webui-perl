############################################################################
#
# tab the img networks, terms, pathways, and part list
# I'm trying to wrap the 4 pages into tabs
#
# $Id: ImgTermAndPathTab.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package ImgTermAndPathTab;

use strict;
use Data::Dumper;
use Storable;
use CGI qw( :standard );
use DBI;
use WebUtil;
use WebConfig;
use TabHTML;

use ImgNetworkBrowser;
use ImgTermBrowser;
use ImgPwayBrowser;
use ImgPartsListBrowser;

my $section     = "ImgTermAndPathTab";
my $env         = getEnv();
my $main_cgi    = $env->{main_cgi};
my $section_cgi = "$main_cgi?section=$section";
my $inner_cgi   = $env->{inner_cgi};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};
my $verbose     = $env->{verbose};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "tab1" ) {
        printMainForm();
    } elsif ( $page eq "tab2" ) {
        printTab2();
    } elsif ( $page eq "tab3" ) {
        printTab3();
    } elsif ( $page eq "tab4" ) {
        printTab4();
    } else {
        printMainForm();
    }
}

sub printMainForm {
    printStatusLine( "Loading ...", 1 );

    # yui tabview
    TabHTML::printTabAPILinks("imgTab");
    my @tabIndex = ( "#tab1", "#tab2", "#tab3", "#tab4" );
    my @tabNames =
      ( "IMG Networks", "IMG Terms", "IMG Pathways", "IMG Parts List" );
    TabHTML::printTabDiv( "imgTab", \@tabIndex, \@tabNames );

    print "<div id='tab1'><p>\n";
    printTab1();

    # end of tab 1
    print "</p></div>\n";

    # tab 2

    print "<div id='tab2'><p>\n";
    print "<font color='red'><blink>Loading ...</blink></font>\n";
    #printTab2();
    print "</p></div>\n";

    print "<div id='tab3'><p>\n";
    print "<font color='red'><blink>Loading ...</blink></font>\n";
    #printTab3();
    print "</p></div>\n";

    print "<div id='tab4'><p>\n";
    print "<font color='red'><blink>Loading ...</blink></font>\n";
    #printTab4();
    print "</p></div>\n";

    TabHTML::printTabDivEnd();

    print "<script>\n";
    my $url = "$inner_cgi?section=$section&page=tab2";
    print "load(\"$url\", \"tab2\", 3, 'Loaded.');\n";
    $url = "$inner_cgi?section=$section&page=tab3";
    print "load(\"$url\", \"tab3\", 3, 'Loaded.');\n";
    $url = "$inner_cgi?section=$section&page=tab4";
    print "load(\"$url\", \"tab4\", 3, 'Loaded.');\n";
    print "</script>\n";
    
    
    ImgTermBrowser::printJavaScript();
    ImgPwayBrowser::printJavaScript();
    ImgPartsListBrowser::printJavaScript();
}

sub printTab1 {
    ImgNetworkBrowser::printImgNetworkBrowser( );
}

sub printTab2 {
print "<p>\n";
    ImgTermBrowser::printImgTermBrowser();
}

sub printTab3 {
print "<p>\n";    
    ImgPwayBrowser::printAlphaList();
}

sub printTab4 {
    print "<p>\n";
    ImgPartsListBrowser::printPartsList();
}

1;
