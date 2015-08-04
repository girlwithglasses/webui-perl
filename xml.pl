############################################################################
# This is used to get XML data objects from server.
# It follows the same logic as main.pl and inner.pl
# see xml.cgi
#
# $Id: xml.pl 33401 2015-05-22 17:59:24Z klchu $
############################################################################
use strict;
use CGI qw( :standard );
use CGI::Session qw/-ip-match/;    # for security - ken
use perl5lib;
use Data::Dumper;
use FileHandle;
use WebConfig;
use WebUtil;

$| = 1;

my $env                  = getEnv();
my $base_dir             = $env->{base_dir};
my $default_timeout_mins = $env->{default_timeout_mins};
$default_timeout_mins = 5 if $default_timeout_mins eq "";

blockRobots();

timeout( 60 * $default_timeout_mins );

############################################################################
# main
############################################################################

my $cgi     = WebUtil::getCgi();
my $section = param("section");

if ( $section eq "tooltip" ) {
    my $filename = param('filename');
    print header( -type => "text/html" );

    my $file = $base_dir . '/doc/tooltips/' . $filename;
    if ( -e $file ) {
        my $str = file2Str($file);
        print $str;
    }

} elsif ( $section eq "yuitracker" ) {
    print header( -type => "text/html" );
    my $file = $env->{yui_export_tracker_log};
    my $afh = newAppendFileHandle( $file, "yui", 1 );

    my $text = param('text');
    my $s = dateTimeStr() . ' ' . getContactOid() . " $text\n";
    print $afh $s;
    close $afh;

} elsif ( $section eq "config" ) {

    #   sort keys
    $Data::Dumper::Sortkeys = 1;

    #print Dumper($obj);

    # sort keys in reverse order - use either one
    #$Data::Dumper::Sortkeys = sub { [reverse sort keys %{$_[0]}] };
    #$Data::Dumper::Sortkeys = sub { [sort {$b cmp $a} keys %{$_[0]}] };
    #print Dumper($obj);

    print header( -type => "text/plain" );
    print Dumper $env;

} elsif ($section eq 'ProPortal') {
    # text/html
    print header( -type => "text/html" );  
    
    require ProPortal;
    ProPortal::dispatch();
    
} elsif($section eq 'MeshTree') {
    
    require MeshTree;
    MeshTree::dispatch();    
    
} elsif($section eq 'ANI') {

    my $page = param('page');
    if ($page eq "selectFiles" ) {
    # xml header
    print header( -type => "text/xml" );
    } else {
    print header( -type => "application/json", -expires=>'-1d' );
    }
    require ANI;
    ANI::dispatch();    
    
} elsif($section eq 'GenomeListJSON') {
    
    my $page = param('page');
    if ( $page eq 'json' ) {
        # Stop IE ajax caching
        print header( -type => "application/json", -expires=>'-1d' );
    } else {
        print header( -type => "text/plain" );
    }
        
    require GenomeListJSON;
    GenomeListJSON::dispatch();
    
} elsif ( $section eq "PhylumTree" ) {

    # xml header
    print header( -type => "text/xml" );
    require PhylumTree;
    PhylumTree::dispatch();

} elsif ( $section eq "BinTree" ) {

    # xml header
    print header( -type => "text/xml" );
    require BinTree;
    BinTree::dispatch();

} elsif ( $section eq "TestTree" ) {

    # xml header
    print header( -type => "text/xml" );

    # FOR TESTING
    require TestTree;
    TestTree::dispatch();

} elsif ( $section eq "BarChartImage" ) {

    # xml header
    print header( -type => "text/xml" );
    require BarChartImage;
    BarChartImage::dispatch();

} elsif ( $section eq "TaxonList" ) {

    # xml header
    print header( -type => "text/xml" );
    require TaxonList;
    TaxonList::dispatch();

} elsif ( $section eq "IMGProteins" ) {

    # xml header
    print header( -type => "text/xml" );
    require IMGProteins;
    IMGProteins::dispatch();

} elsif ( $section eq "RNAStudies" ) {

    # xml header
    print header( -type => "text/xml" );
    require RNAStudies;
    RNAStudies::dispatch();

} elsif ( $section eq "PathwayMaps" ) {

    # xml header
    print header( -type => "text/xml" );
    require PathwayMaps;
    PathwayMaps::dispatch();

} elsif ( $section eq "TableUtil" ) {

    # xml header
    print header( -type => "text/xml" );
    require TableUtil;
    TableUtil::dispatch();

} elsif ( $section eq "Methylomics" ) {

    print header( -type => "text/xml" );
    require Methylomics;
    Methylomics::dispatch();

} elsif ( $section eq "BiosyntheticDetail" ) {

    print header( -type => "text/xml" );
    require BiosyntheticDetail;
    BiosyntheticDetail::dispatch();

} elsif ( $section eq "BiosyntheticStats" ) {

    print header( -type => "text/xml" );
    require BiosyntheticStats;
    BiosyntheticStats::dispatch();

} elsif ( $section eq "GenomeListFilter" ) {

    # xml header
    print header( -type => "text/xml" );
    require GenomeListFilter;
    GenomeListFilter::dispatch();

} elsif ( $section eq "FindGenomesByMetadata" ) {

    # xml header
    print header( -type => "text/xml" );
    require FindGenomesByMetadata;
    FindGenomesByMetadata::dispatch();

} elsif ( $section eq "FunctionAlignment" ) {

    # xml header
    print header( -type => "text/xml" );
    require FunctionAlignment;
    FunctionAlignment::dispatch();

} elsif ( $section eq "Artemis" ) {

    # xml header
    #print header( -type => "text/xml" );
    require Artemis;
    Artemis::dispatch();

} elsif ( $section eq "ACT" ) {

    require ACT;
    ACT::dispatch();

} elsif ( $section eq "TreeFile" ) {

    # text/html
    print header( -type => "text/html" );
    require TreeFile;
    TreeFile::dispatch();

} elsif ( $section eq "Selection" ) {

    # text/html
    require Selection;
    Selection::dispatch();

} elsif ( $section eq "TreeFileMgr" ) {

    # text/html
    print header( -type => "text/html" );
    require TreeFileMgr;
    TreeFileMgr::dispatch();

} elsif ( $section eq "GeneCassetteSearch" ) {

    # text/html
    print header( -type => "text/html" );
    require GeneCassetteSearch;
    GeneCassetteSearch::dispatch();

} elsif ( $section eq "GeneDetail" ) {

    # xml header
    print header( -type => "text/xml" );
    require GeneDetail;
    GeneDetail::dispatch();

} elsif ( $section eq "Cart" ) {

    require Cart;
    Cart::dispatch();

} elsif ( $section eq "Check" || $section eq "check" ) {

    require Check;
    Check::dispatch();

} elsif ( $section eq "RadialPhyloTree" ) {

    require RadialPhyloTree;
    RadialPhyloTree::dispatch();

} elsif ( $section eq "Workspace" ) {

    # text header
    print header( -type => "text/html" );
    require Workspace;
    Workspace::dispatch();

} elsif ( $section eq "MessageFile" ) {

    # ajax general message check - see header.js and main.pl footer section
    print header( -type => "text/html" );
    my $message_file = $env->{message_file};
    if ( $message_file ne "" && -e $message_file ) {

        my $str = file2Str($message_file);
        print $str;
    }

} elsif ( $section eq "NewsFile" ) {

    # ajax general message check - see header.js and main.pl footer section
    print header( -type => "text/html" );
    my $message_file = "/webfs/scratch/img/proPortal/news.txt";
    if ( $message_file ne "" && -e $message_file ) {
        my $str = file2Str($message_file);
        print $str;
    }

} elsif ( $section eq 'scriptEnv' ) {
    print header( -type => "text/plain" );

    # test
    unsetEnvPath();
    print $ENV{PATH} . "\n";

    #delete @ENV{ 'IFS', 'CDPATH', 'ENV', 'BASH_ENV' };
    my $scriptEnv = $env->{scriptEnv_script};
    if ( $scriptEnv ne '' ) {
        my $cmd1 = "java -version";
        print "$cmd1\n";
        # $cfh = new FileHandle("PATH=/bin:/usr/bin:/usr/local/bin; IFS=''; CDPATH=''; ENV=''; BASH_ENV=''; $cmd 2>\&1 |");
        #my $fh = newCmdFileHandle( $cmd1, '', 1 );
        my $fh =  new FileHandle("$cmd1 2>\&1 |");
        if ($fh) {
            while ( my $line = $fh->getline() ) {
                chomp $line;
                print "Status: $line\n";
            }
            close $fh;
        }

        my $cmd2 = "$scriptEnv java -version";
        print "\n\n$cmd2\n";
        #my $fh = newCmdFileHandle($cmd2);
        my $fh = new FileHandle("$cmd2 2>\&1 |");
        while ( my $line = $fh->getline() ) {
            chomp $line;
            print "Status: $line\n";
        }
        close $fh;
    } else {
        print "hello world\n";
    }
    print "\n\nTest Done\n";

} else {
    print header( -type => "text/plain" );
    print "Unknown section='$section'\n";
}

WebUtil::webExit(0);

