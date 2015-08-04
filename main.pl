#   All CGI called run this section and dispatch is made to relevant
#   for displaying appropriate CGI pages.
#      --es 09/19/2004
#
# $Id: main.pl 33838 2015-07-29 19:24:06Z aireland $
##########################################################################
use strict;
use warnings;
use feature ':5.16';

use lib qw(
	/global/homes/a/aireland/perl5/lib/perl5
	/global/homes/a/aireland/webUI/webui.cgi
	/global/homes/a/aireland/webUI/proportal/lib
);

use Data::Dumper;
# use Carp::Always;
use CGI qw( :standard  );
use CGI::Cookie;
use CGI::Session qw/-ip-match/;    # for security - ken
use CGI::Carp qw( carpout set_message fatalsToBrowser warningsToBrowser );
# use perl5lib;
use HTML::Template;
use File::Path qw(remove_tree);
use Number::Format;
use WebConfig;
use WebUtil qw();
use Template;
use GenomeCart;

use IMG::Views::ViewMaker;

#use IMG::Dispatcher;

$| = 1;

my $env                      = getEnv();
my $abc                      = $env->{abc};                        # BC & SM home
my $base_dir                 = $env->{base_dir};
my $base_url                 = $env->{base_url};
my $cgi_dir                  = $env->{cgi_dir};
my $cgi_tmp_dir              = $env->{cgi_tmp_dir};
my $cgi_url                  = $env->{cgi_url};
my $dblock_file              = $env->{dblock_file};
my $default_timeout_mins     = $env->{default_timeout_mins};
my $domain_name              = $env->{domain_name};
my $enable_ani               = $env->{enable_ani};
my $enable_biocluster        = $env->{enable_biocluster};
my $enable_cassette          = $env->{enable_cassette};
my $enable_genomelistJson    = $env->{enable_genomelistJson};
my $enable_mybin             = $env->{enable_mybin};
my $enable_workspace         = $env->{enable_workspace};
my $full_phylo_profiler      = $env->{full_phylo_profiler};
my $http                     = $env->{http};
my $ignore_dblock            = $env->{ignore_dblock};
my $img_edu                  = $env->{img_edu};
my $img_er                   = $env->{img_er};
my $img_geba                 = $env->{img_geba};
my $img_hmp                  = $env->{img_hmp};
my $img_internal             = $env->{img_internal};
my $img_ken                  = $env->{img_ken};
my $img_lite                 = $env->{img_lite};
my $img_pheno_rule           = $env->{img_pheno_rule};
my $img_proportal            = $env->{img_proportal};
my $img_submit_url           = $env->{img_submit_url};
my $img_version              = $env->{img_version};
my $include_img_terms        = $env->{include_img_terms};
my $include_kog              = $env->{include_kog};
my $include_metagenomes      = $env->{include_metagenomes};
my $include_tigrfams         = $env->{include_tigrfams};
my $main_cgi                 = $env->{main_cgi};
my $MESSAGE                  = $env->{message};
my $myimg_job                = $env->{myimg_job};
my $no_phyloProfiler         = $env->{no_phyloProfiler};
my $phyloProfiler_sets_file  = $env->{phyloProfiler_sets_file};
my $public_login             = $env->{public_login};
my $scaffold_cart            = $env->{scaffold_cart};
my $show_myimg_login         = $env->{show_myimg_login};
my $show_private             = $env->{show_private};
my $show_sql_verbosity_level = $env->{show_sql_verbosity_level};
my $tmp_dir                  = $env->{tmp_dir};
my $top_base_url             = $env->{top_base_url};
my $use_img_clusters         = $env->{use_img_clusters};
my $use_img_gold             = $env->{use_img_gold};
my $user_restricted_site     = $env->{user_restricted_site};
my $user_restricted_site_url = $env->{user_restricted_site_url};
my $verbose                  = $env->{verbose};
my $web_data_dir             = $env->{web_data_dir};
my $webfs_data_dir           = $env->{webfs_data_dir};

$default_timeout_mins = 5 unless $default_timeout_mins;
my $use_func_cart = 1;

my $imgAppTerm = "IMG";
$imgAppTerm = "IMG/ER"   if ($img_er);
$imgAppTerm = "IMG"    if $include_metagenomes;
$imgAppTerm = "IMG/ER" if ( $include_metagenomes && $user_restricted_site );
$imgAppTerm = "IMG/ABC"  if ($abc);

my $YUI = $env->{yui_dir_28};
my $taxon_filter_oid_str;

# sso Caliban
# cookie name: jgi_return, value: url, domain: jgi.doe.gov
my $sso_enabled     = $env->{sso_enabled};
my $sso_url         = $env->{sso_url};
my $sso_domain      = $env->{sso_domain};
my $sso_cookie_name = $env->{sso_cookie_name};    # jgi_return cookie name

my $jgi_return_url = "";
my $homePage       = 0;
my $pageTitle      = "IMG";

WebUtil::timeout( 60 * $default_timeout_mins );

# check the number of cgi processes
#WebUtil::maxCgiProcCheck();
WebUtil::blockRobots();

# key the AppHeader where $current used
# value display
my %breadcrumbs = (
    login            => "Login",
    logout           => "Logout",
    Home             => "Home",
    FindGenomes      => "Find Genomes",
    FindGenes        => "Find Genes",
    FindFunctions    => "Find Functions",
    CompareGenomes   => "Compare Genomes",
    AnaCart          => "Analysis Cart",
    MyIMG            => "My $imgAppTerm",
    about            => "Using $imgAppTerm",
    ImgStatsOverview => "IMG Stats Overview",
    IMGContent       => "IMG Content",
    RNAStudies       => "RNASeq Studies",
    Methylomics      => "Methylomics Experiments",
    Proteomics       => "Protein Expression Studies",
);

############################################################################
# main
############################################################################

# new for 3.3
# is db locked
# if file not empty dump html from it
if ( -e $dblock_file && !$img_ken ) {
    my $s = WebUtil::file2Str( $dblock_file, 1 );
    if ( ! WebUtil::blankStr($s) ) {
        print header( -type => "text/html", -status => '503' );
        print $s;
    } else {
        printAppHeader("exit");
        printMessage( "Database is currently being serviced.<br/>"
              . "Sorry for the inconvenience.<br/>"
              . "Please try again later.<br/>" );
        printContentEnd();
        printMainFooter($homePage);
    }
    WebUtil::webExit(0);
}

## Check and purge temp directory for files "too old".
# for v40 I have a cronjob to purge
# the default is to do purge as part of teh main.pl
# only the production code will it be disable and the cronjob to do the purge
#
# we still need to purge the htdocs/<site>/tmp directory files - ken
# web farm also has purge to clean up setup by Jeremy
#
#if($enable_purge) {
#my ( $nPurged, $nFiles ) = purgeTmpDir();
#}

#
# check for https for login sites
#

my $cgi   = WebUtil::getCgi();

IMG::Views::ViewMaker::init(env => $env, cgi => $cgi, imgAppTerm => $imgAppTerm);


my $https = $cgi->https();       # if on its not null
if ( ( $public_login || $user_restricted_site ) && $https eq '' && $env->{ssl_enabled} ) {
#    my $REQUEST_METHOD = uc( $ENV{REQUEST_METHOD} );
    if ( 'GET' eq uc( $ENV{REQUEST_METHOD} ) ) {
        my $seconds = 30;
        my $url     = $cgi_url . "/" . $main_cgi . redirectform(1);
        print header( -type => "text/html", -status => '497 HTTP to HTTPS (Nginx)' );
        my $template = HTML::Template->new( filename => "$base_dir/Nginx.html" );
        $template->param( seconds    => $seconds );
        $template->param( url => $url );
        print $template->output;
        WebUtil::webExit(0);
    }

    # POST - do nothing so far
}

## Set up session management.
#
# session and cookie expire after 90m
#
my $session = WebUtil::getSession();

# +90m expire after 90 minutes
# +24h - 24 hour cookie
# +1d - one day
# +6M   6 months from now
# +1y   1 year from now
#$session->expire("+1d");
#
# TODO Can this be the problem with NAtalia always getting logged out - ken June 1, 2015 ???
#resetContactOid();

my $session_id  = $session->id();
my $contact_oid = WebUtil::getContactOid();

# see WebUtil.pm line CGI::Session->name($cookie_name); is called - ken
my $cookie_name = WebUtil::getCookieName();
my $cookie      = cookie( $cookie_name => $session_id );

my $oldLogin = $session->param('oldLogin');
$oldLogin = 0 if $cgi->param('oldLogin') eq 'false';
if ( $cgi->param('oldLogin') eq 'true' || $oldLogin ) {
    $session->param( "oldLogin", 1 );
    $oldLogin = 1;
} else {
    $session->param( "oldLogin", 0 );
    $oldLogin = 0;
}

if ( !$oldLogin && $sso_enabled ) {
    require Caliban;
    if ( !$contact_oid ) {
        my $dbh_main = WebUtil::dbLogin();
        my $ans      = Caliban::validateUser($dbh_main);

        if ( !$ans ) {
            printAppHeader("login");
            Caliban::printSsoForm();
            printContentEnd();
            printMainFooter(1);
            WebUtil::webExit(0);
        }
        WebUtil::loginLog( 'login', 'sso' );
        require MyIMG;
        MyIMG::loadUserPreferences();
    }

    # logout in genome portal i still have contact oid
    # I have to fix and relogin
    my $ans = Caliban::isValidSession();
    if ( !$ans ) {
        Caliban::logout( 0, 1 );
        printAppHeader("login");
        Caliban::printSsoForm();
        printContentEnd();
        printMainFooter(1);
        WebUtil::webExit(0);
    }
} elsif ( ( $public_login || $user_restricted_site ) && !$contact_oid ) {
    require Caliban;
    my $username = $cgi->param("username");
    $username = $cgi->param("login") if ( blankStr($username) );    # single login form for sso or img
    my $password = $cgi->param("password");
    if ( blankStr($username) ) {
        printAppHeader("login");
        Caliban::printSsoForm();
        printContentEnd();
        printMainFooter(1);
        WebUtil::webExit(0);
    } else {
        my $redirecturl = "";
        if ($sso_enabled) {

            # do redirect via cookie
            # return cookie name
            my %cookies = CGI::Cookie->fetch;
            if ( exists $cookies{$sso_cookie_name} ) {
                $redirecturl = $cookies{$sso_cookie_name}->value;
                $redirecturl = "" if ( $redirecturl =~ /main.cgi$/ );

                #$redirecturl = "" if ( $redirecturl =~ /forceimg/ );
            }
        }

        require MyIMG;
        my $b = MyIMG::validateUserPassword( $username, $password );
        if ( !$b ) {
            Caliban::logout();
            printAppHeader( "login", '', '', '', '', '', $redirecturl );
            print qq{
<p>
    <span style="color:red; font-size: 14px;">
    Invalid Username or Password. Try again. <br>
    For JGI SSO accounts please use the login form on the right side
    <span style="color:#336699; font-weight:bold;"> "JGI Single Sign On (JGI SSO)"</span></span>
</p>
            };
            Caliban::printSsoForm();
            printContentEnd();
            printMainFooter(1);
            WebUtil::webExit(0);
        }
        Caliban::checkBannedUsers( $username, $username, $username );
        WebUtil::loginLog( 'login', 'img' );
        MyIMG::loadUserPreferences();
        $session->param( "oldLogin", 1 );

        #if($img_ken) {
            Caliban::migrateImg2JgiSso($redirecturl);
        #}

        if ( $sso_enabled && $redirecturl ne "" ) {
            print header( -type => "text/html", -cookie => $cookie );
            print qq{
                    <p>
                    Redirecting to: <a href='$redirecturl'> $redirecturl </a>
                    <script language='JavaScript' type="text/javascript">
                     window.open("$redirecturl", "_self");
                    </script>
            };
            WebUtil::webExit(0);
        }
    }
}

# for adding to genome cart from browser list
if ( $cgi->param("setTaxonFilter") ) {

    my @taxon_filter_oid = $cgi->multi_param('taxon_filter_oid');
    if (! @taxon_filter_oid) {
    	@taxon_filter_oid = $cgi->multi_param('taxon_oid');
    }
#	say "got params: " . Dumper \@taxon_filter_oid;

    if ( scalar @taxon_filter_oid > 0 ) {
		# get unique taxon_oids and set the session param
		my %uniq;
		undef @uniq{ @taxon_filter_oid };
		$taxon_filter_oid_str = join ",", sort keys %uniq;
		$session->param( "blank_taxon_filter_oid_str", "0" );

		# add to the genome cart
		GenomeCart::addToGenomeCart([ keys %uniq ]);
	}
}

if ( $cgi->param("deleteAllCartGenes") ) {
    $session->param( "gene_cart_oid_str", "" );
}

#
# touch user's chart files
#
touchCartFiles();

# for w and m use the public autocomplete file
if ( $user_restricted_site && $enable_workspace ) {

    #WebUtil::createTmpIndex();

    # php files like the autocompleteAll.php
    require GenomeListJSON;
    my $myGenomesFile = GenomeListJSON::getMyAutoCompleteFile();

    #webLog(GenomeListJSON::getMyAutoCompleteFile());
    #webLog("\n");
    #webLog(GenomeListJSON::getMyAutoCompleteUrl());
    #webLog("\n");

    if ( !-e $myGenomesFile ) {
        GenomeListJSON::myAutoCompleteGenomeList($myGenomesFile);
    }
}

# remap the section param if required
coerce_section();

=cut

$env->{oldLogin} = $oldLogin;
$env->{taxon_filter_oid_str} = $taxon_filter_oid_str;
dispatch_page({
	env => $env,
	cgi => $cgi,
	cookie => $cookie
});
=cut

############################################################
# main viewer dispatch
############################################################
if ( $cgi->param() ) {

    my $page = $cgi->param('page');
    my $section = $cgi->param('section');

    if ( $section eq "AbundanceProfileSearch" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require AbundanceProfileSearch;
        $pageTitle = "Abundance Profile Search";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon;
        if ($include_metagenomes) {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js, '', "userGuide_m.pdf#page=19" );
        } else {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js, '', "userGuide.pdf#page=51" );
        }
        AbundanceProfileSearch::dispatch($numTaxon);

    } elsif ( $section eq 'StudyViewer' ) {
        my $yuijs = qq{
<link rel="stylesheet" type="text/css" href="$YUI/build/treeview/assets/skins/sam/treeview.css" />
<script type="text/javascript" src="$YUI/build/treeview/treeview-min.js"></script>

<style type="text/css">

.ygtvcheck0 { background: url($YUI/examples/treeview/assets/img/check/check0.gif) 0 0 no-repeat; width:16px; height:20px; float:left; cursor:pointer; }
.ygtvcheck1 { background: url($YUI/examples/treeview/assets/img/check/check1.gif) 0 0 no-repeat; width:16px; height:20px; float:left; cursor:pointer; }
.ygtvcheck2 { background: url($YUI/examples/treeview/assets/img/check/check2.gif) 0 0 no-repeat; width:16px; height:20px; float:left; cursor:pointer; }

.ygtv-edit-TaskNode  {  width: 190px;}
.ygtv-edit-TaskNode .ygtvcancel, .ygtv-edit-TextNode .ygtvok  { border:none;}
.ygtv-edit-TaskNode .ygtv-button-container { float: right;}
.ygtv-edit-TaskNode .ygtv-input  input{ width: 140px;}
.whitebg {
    background-color:white;
}
</style>
};

        require StudyViewer;
        $pageTitle = "Metagenome Study Viewer";
        printAppHeader( "FindGenomes", '', '', $yuijs );
        StudyViewer::dispatch();

    } elsif ( $section eq 'ANI' ) {
        require ANI;
        $pageTitle = "ANI";

        my $js = '';
        if ( $page eq "pairwise" ) {
            require GenomeListJSON;
            my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
            $template->param( base_url => $base_url );
            $template->param( YUI      => $YUI );
            $js = $template->output;
        } elsif ( $page eq "overview" ) {
            my $template = HTML::Template->new( filename => "$base_dir/meshTreeHeader.html" );
            $template->param( base_url => $base_url );
            $template->param( YUI      => $YUI );
            $js = $template->output;
        }
        my $numTaxon = printAppHeader( "CompareGenomes", '', '', $js );
        ANI::dispatch($numTaxon);

    } elsif ( $section eq 'Caliban' ) {
        require Caliban;
        printAppHeader("");
        Caliban::dispatch();


    } elsif ( $section eq 'ProPortal' ) {
        require ProPortal;

        my $page = $cgi->param('page');
        if($page =~ /^kentest/) {
            printAppHeader("Find Genomes");
        } else {
            printAppHeader("Home");
        }

        ProPortal::dispatch();

    } elsif ( $section eq 'Portal' ) {
        require Portal;
        printAppHeader("Find Genomes");
        Portal::dispatch();

    } elsif ( $section eq 'ProjectId' ) {
        require ProjectId;
        $pageTitle = "Project ID List";
        printAppHeader("FindGenomes");
        ProjectId::dispatch();

    } elsif ( $section eq 'ScaffoldSearch' ) {
        $pageTitle = "Scaffold Search";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon = printAppHeader( "FindGenomes", '', '', $js );

        require ScaffoldSearch;
        ScaffoldSearch::dispatch($numTaxon);

    } elsif ( $section eq 'MeshTree' ) {
        require MeshTree;
        $pageTitle = "Mesh Tree";

        my $template = HTML::Template->new( filename => "$base_dir/meshTreeHeader.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        printAppHeader( "FindFunctions", '', '', $js );
        MeshTree::dispatch();

    } elsif ( $section eq "AbundanceProfiles" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require AbundanceProfiles;
        $pageTitle = "Abundance Profiles";

        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        if ($include_metagenomes) {
            printAppHeader( "CompareGenomes", '', '', $js, '', "userGuide_m.pdf#page=18" );
        } else {
            printAppHeader( "CompareGenomes", '', '', $js, '', "userGuide.pdf#page=49" );
        }
        AbundanceProfiles::dispatch();
    } elsif ( $section eq "AbundanceTest" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require AbundanceTest;
        $pageTitle = "Abundance Test";
        printAppHeader("CompareGenomes")
          if $cgi->param("noHeader") eq "";
        AbundanceTest::dispatch();
    } elsif ( $section eq "AbundanceComparisons" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require AbundanceComparisons;
        $pageTitle = "Abundance Comparisons";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon;
        if ($include_metagenomes) {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js, '', "userGuide_m.pdf#page=20" )
              if $cgi->param("noHeader") eq "";
        } else {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js ) if $cgi->param("noHeader") eq "";
        }
        AbundanceComparisons::dispatch($numTaxon);
    } elsif ( $section eq "AbundanceComparisonsSub" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require AbundanceComparisonsSub;
        $pageTitle = "Function Category Comparisons";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon;
        if ($include_metagenomes) {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js, '', "userGuide_m.pdf#page=23" )
              if $cgi->param("noHeader") eq "";
        } else {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js )
              if $cgi->param("noHeader") eq "";
        }
        AbundanceComparisonsSub::dispatch($numTaxon);
    } elsif ( $section eq "AbundanceToolkit" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require AbundanceToolkit;
        $pageTitle = "Abundance Toolkit";
        printAppHeader("CompareGenomes")
          if $cgi->param("noHeader") eq "";
        AbundanceToolkit::dispatch();
    } elsif ( $section eq "Artemis" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require Artemis;
        $pageTitle = "Artemis";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $from = $cgi->param("from");
        my $numTaxon;
        if ( $from eq "ACT" || $page =~ /^ACT/ || $page =~ /ACT$/ ) {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js );
        } else {
            $numTaxon = printAppHeader( "FindGenomes", '', '', $js )
              if $cgi->param("noHeader") eq "";
        }
        Artemis::dispatch($numTaxon);
    } elsif ( $section eq "ClustalW" ) {
        WebUtil::timeout( 60 * 40 );    # WebUtil::timeout in 40 minutes
        require ClustalW;
        $pageTitle = "Clustal - Multiple Sequence Alignment";
        printAppHeader( "AnaCart", '', '', '', '', "DistanceTree.pdf#page=6" );
        ClustalW::dispatch();
    } elsif ( $section eq "CogCategoryDetail" ) {
        require CogCategoryDetail;
        $pageTitle = "COG";
        $pageTitle = "KOG" if ( $page =~ /kog/i );
        printAppHeader("FindFunctions");
        CogCategoryDetail::dispatch();
    } elsif ( $section eq "CompTaxonStats" ) {
        require CompTaxonStats;
        $pageTitle = "Genome Statistics";
        printAppHeader("CompareGenomes");
        CompTaxonStats::dispatch();
    } elsif ( $section eq "CompareGenomes" || $section eq "CompareGenomesTab" ) {
        require CompareGenomes;
        $pageTitle = "Compare Genomes";
        if ( WebUtil::paramMatch("_excel") ) {
#            printExcelHeader("stats_export$$.xls");
            IMG::Views::ViewMaker::print_excel_header("stats_export$$.xls");
        } else {
            printAppHeader("CompareGenomes");
        }
        CompareGenomes::dispatch();
    } elsif ( $section eq "GenomeGeneOrtholog" ) {
        require GenomeGeneOrtholog;
        $pageTitle = "Genome Gene Ortholog";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js       = $template->output;
        my $numTaxon = printAppHeader( "CompareGenomes", '', '', $js );

        #printAppHeader("CompareGenomes");
        GenomeGeneOrtholog::dispatch($numTaxon);

    } elsif ( $section eq "Pangenome" ) {
        require Pangenome;
        $pageTitle = "Pangenome";

        if ( WebUtil::paramMatch("_excel") ) {
#            printExcelHeader("stats_export$$.xls");
            IMG::Views::ViewMaker::print_excel_header("stats_export$$.xls");
        } else {
            printAppHeader("Pangenome");
        }
        Pangenome::dispatch();

    } elsif ( $section eq "CompareGeneModelNeighborhood" ) {
        require CompareGeneModelNeighborhood;
        $pageTitle = "Compare Gene Models";
        printAppHeader("CompareGenomes");
        CompareGeneModelNeighborhood::dispatch();
    } elsif ( $section eq "CuraCartStor" ) {
        require CuraCartStor;
        $pageTitle = "Curation Cart";
        $session->param( "lastCart", "curaCart" );
        printAppHeader("AnaCart") if ! $cgi->param("noHeader");
        CuraCartStor::dispatch();
    } elsif ( $section eq "CuraCartDataEntry" ) {
        require CuraCartDataEntry;
        $pageTitle = "Curation Cart Data Entry";
        $session->param( "lastCart", "curaCart" );
        printAppHeader("AnaCart");
        CuraCartDataEntry::dispatch();
    } elsif ( $section eq "DataEvolution" ) {
        require DataEvolution;
        $pageTitle = "Data Evolution";
        printAppHeader("news");
        DataEvolution::dispatch();
    } elsif ( $section eq "EbiIprScan" ) {
        require EbiIprScan;
        $pageTitle = "EBI InterPro Scan";
        print header( -header => "text/html" );
        EbiIprScan::dispatch();
    } elsif ( $section eq "EgtCluster" ) {
        WebUtil::timeout( 60 * 30 );    # WebUtil::timeout in 30 minutes
        require EgtCluster;
        $pageTitle = "Genome Clustering";
        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon;
        if ( $cgi->param("method") eq "hier" ) {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js, '', "DistanceTree.pdf#page=5" );
        } else {
            $numTaxon = printAppHeader( "CompareGenomes", '', '', $js );
        }
        EgtCluster::dispatch($numTaxon);
    } elsif ( $section eq "EmblFile" ) {
        require EmblFile;
        $pageTitle = "EMBL File Export";
        printAppHeader("FindGenomes");
        EmblFile::dispatch();

    } elsif ( $section eq 'BcSearch' ) {
        require BcSearch;
        $pageTitle = "Biosynthetic Cluster Search" if $page eq "bcSearch"   || $page eq "bcSearchResult";
        $pageTitle = "Secondary Metabolite Search" if $page eq "npSearches" || $page eq "npSearchResult";

        my $template = HTML::Template->new( filename => "$base_dir/meshTreeHeader.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        printAppHeader( "getsme", '', '', $js );
        BcSearch::dispatch();
    } elsif ( $section eq 'BiosyntheticStats' ) {
        require BiosyntheticStats;
        $pageTitle = "Biosynthetic Cluster Statistics";
        my $template = HTML::Template->new( filename => "$base_dir/meshTreeHeader.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        printAppHeader( "getsme", '', '', $js );
        BiosyntheticStats::dispatch();
    } elsif ( $section eq 'BiosyntheticDetail' ) {
        require BiosyntheticDetail;
        $pageTitle = "Biosynthetic Cluster";
        printAppHeader("getsme");
        BiosyntheticDetail::dispatch();
    } elsif ( $section eq 'np' ) {
        $pageTitle = "Biosynthetic Clusters & Secondary Metabolites";
        printAppHeader( "getsme", '', '', '', '', 'GetSMe_intro.pdf' );
        require NaturalProd;
        NaturalProd::printLandingPage();

    } elsif ( $section eq 'NaturalProd' ) {
        require NaturalProd;
        $pageTitle = "Secondary Metabolite Statistics";

        my $template = HTML::Template->new( filename => "$base_dir/meshTreeHeader.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        printAppHeader( "getsme", '', '', $js );
        NaturalProd::dispatch();
    } elsif ( $section eq "BcNpIDSearch" ) {
        require BcNpIDSearch;
        $pageTitle = "Biosynthetic Cluster / Secondary Metabolite Search by ID";
        printAppHeader("getsme");
        BcNpIDSearch::dispatch();
    } elsif ( $section eq "FindFunctions" ) {
        require FindFunctions;
        $pageTitle = "Find Functions";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon;
        if ( $page eq 'findFunctions' ) {
            $numTaxon = printAppHeader( "FindFunctions", '', '', $js, '', 'FunctionSearch.pdf' );
        } elsif ( $page eq 'ffoAllSeed' ) {
            $numTaxon = printAppHeader( "FindFunctions", '', '', $js, '', 'SEED.pdf' );
        } elsif ( $page eq 'ffoAllTc' ) {
            $numTaxon = printAppHeader( "FindFunctions", '', '', $js, '', 'TransporterClassification.pdf' );
        } else {
            $numTaxon = printAppHeader( "FindFunctions", '', '', $js );
        }
        FindFunctions::dispatch($numTaxon);
    } elsif ( $section eq "FindFunctionMERFS" ) {
        require FindFunctionMERFS;
        $pageTitle = "Find Functions";
        printAppHeader("FindFunctions");
        FindFunctionMERFS::dispatch();
    } elsif ( $section eq "FindGenes" ) {
        require FindGenes;
        $pageTitle = "Find Genes";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon;
        if (   $page eq 'findGenes'
            || $page eq 'geneSearch'
            || ( $page ne 'geneSearchForm' && WebUtil::paramMatch("fgFindGenes") eq '' ) )
        {
            $numTaxon = printAppHeader( "FindGenes", '', '', $js, '', 'GeneSearch.pdf' );
        } else {
            $numTaxon = printAppHeader( "FindGenes", '', '', $js );
        }
        FindGenes::dispatch($numTaxon);
    } elsif ( $section eq "FindGenesLucy" ) {
        require FindGenesLucy;
        $pageTitle = "Find Genes by Keyword";
        printAppHeader( "FindGenesLucy", '', '', '', '', 'GeneSearch.pdf' );
        FindGenesLucy::dispatch();
    } elsif ( $section eq "FindGenesBlast" ) {
        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        require FindGenesBlast;
        $pageTitle = "Find Genes - BLAST";
        my $numTaxon = printAppHeader( "FindGenes", '', '', $js, '', 'Blast.pdf' );
        FindGenesBlast::dispatch($numTaxon);
    } elsif ( $section eq "FindGenomes" ) {
        require FindGenomes;
        $pageTitle = "Find Genomes";
        if ( $page eq 'findGenomes' ) {
            printAppHeader( "FindGenomes", '', '', '', '', 'GenomeBrowser.pdf' );
        } elsif ( $page eq 'genomeSearch' ) {
            printAppHeader( "FindGenomes", '', '', '', '', 'GenomeSearch.pdf' );
        } else {
            printAppHeader("FindGenomes");
        }
        FindGenomes::dispatch();
    } elsif ( $section eq "FunctionAlignment" ) {
        require FunctionAlignment;
        $pageTitle = "Function Alignment";
        printAppHeader( "FindFunctions", '', '', '', '', 'FunctionAlignment.pdf' );
        FunctionAlignment::dispatch();
    } elsif ( $section eq "FuncCartStor" || $section eq "FuncCartStorTab" ) {
        require FuncCartStor;
        $pageTitle = "Function Cart";
        if ( WebUtil::paramMatch("AssertionProfile") ne "" ) {
            $pageTitle = "Assertion Profile";
        }
        $session->param( "lastCart", "funcCart" );

        #if ( $page eq 'funcCart' || WebUtil::paramMatch("addFunctionCart") ne "" || WebUtil::paramMatch('addToFuncCart') ne "") {
        if ( $page eq 'funcCart' || !WebUtil::paramMatch("noHeader") ) {
            if ($enable_genomelistJson) {
                my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
                $template->param( base_url => $base_url );
                $template->param( YUI      => $YUI );
                my $js = $template->output;
                printAppHeader( "AnaCart", '', '', $js, '', 'FunctionCart.pdf' );
            } else {
                printAppHeader( "AnaCart", '', '', '', '', 'FunctionCart.pdf' );
            }
        }

        # else {
        #    printAppHeader("AnaCart") if !WebUtil::paramMatch("noHeader");
        #}
        FuncCartStor::dispatch();
    } elsif ( $section eq "FuncProfile" ) {
        require FuncProfile;
        $pageTitle = "Function Profile";
        printAppHeader("AnaCart");
        FuncProfile::dispatch();
    } elsif ( $section eq "FunctionProfiler" ) {
        require FunctionProfiler;
        $pageTitle = "Function Profile";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon = printAppHeader( "CompareGenomes", "", "", $js );
        FunctionProfiler::dispatch($numTaxon);
    } elsif ( $section eq "DotPlot" ) {
        WebUtil::timeout( 60 * 40 );    # WebUtil::timeout in 40 minutes
        require DotPlot;
        $pageTitle = "Dotplot";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        my $numTaxon = printAppHeader( "CompareGenomes", "Synteny Viewers", '', $js, '', 'Dotplot.pdf' );
        DotPlot::dispatch($numTaxon);
    } elsif ( $section eq "DistanceTree" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require DistanceTree;
        $pageTitle = "Distance Tree";
        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        my $numTaxon = printAppHeader( "CompareGenomes", '', '', $js, '', 'DistanceTree.pdf' );
        DistanceTree::dispatch($numTaxon);
    } elsif ( $section eq "RadialPhyloTree" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require RadialPhyloTree;
        $pageTitle = "Radial Phylogenetic Tree";
        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        my $numTaxon = printAppHeader( "CompareGenomes", '', '', $js )
          if !WebUtil::paramMatch("export");
        RadialPhyloTree::dispatch($numTaxon);
    } elsif ( $section eq "Kmer" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require Kmer;
        $pageTitle = "Kmer Frequency Analysis";
        printAppHeader("FindGenomes")
          if !WebUtil::paramMatch("export");
        Kmer::dispatch();
    } elsif ( $section eq "GenBankFile" ) {
        require GenBankFile;
        $pageTitle = "GenBank File Export";
        printAppHeader("FindGenomes");
        GenBankFile::dispatch();
    } elsif ( $section eq "GeneAnnotPager" ) {
        require GeneAnnotPager;
        $pageTitle = "Comparative Annotations";
        printAppHeader("FindGenomes");
        GeneAnnotPager::dispatch();
    } elsif ( $section eq "GeneInfoPager" ) {
        WebUtil::timeout( 60 * 60 );    # WebUtil::timeout in 20 minutes
        require GeneInfoPager;
        $pageTitle = "Download Gene Information";
        printAppHeader("FindGenomes");
        GeneInfoPager::dispatch();
    } elsif ( $section eq "GeneCartChrViewer" ) {
        require GeneCartChrViewer;
        $pageTitle = "Circular Chromosome Viewer";
        $session->param( "lastCart", "geneCart" );
        printAppHeader("AnaCart");
        GeneCartChrViewer::dispatch();
    } elsif ( $section eq "GeneCartDataEntry" ) {
        require GeneCartDataEntry;
        $pageTitle = "Gene Cart Data Entry";
        $session->param( "lastCart", "geneCart" );
        printAppHeader("AnaCart");
        GeneCartDataEntry::dispatch();

    } elsif ( $section eq 'GenomeListJSON' ) {

        # TODO testing forms
        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        printAppHeader( "AnaCart", '', '', $js );

        GenomeListJSON::test();

    } elsif ( $section eq "GeneCartStor" || $section eq "GeneCartStorTab" ) {
        require GeneCartStor;
        $pageTitle = "Gene Cart";
        if ( WebUtil::paramMatch("addFunctionCart") ne "" ) {
            $session->param( "lastCart", "funcCart" );
        } else {
            $session->param( "lastCart", "geneCart" );
        }
        if ( $page eq 'geneCart' || !WebUtil::paramMatch("noHeader") ) {
            if ($enable_genomelistJson) {
                my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
                $template->param( base_url => $base_url );
                $template->param( YUI      => $YUI );
                my $js = $template->output;

                printAppHeader( "AnaCart", '', '', $js, '', 'GeneCart.pdf' );
            } else {
                printAppHeader( "AnaCart", '', '', '', '', 'GeneCart.pdf' );
            }
        } else {
            printAppHeader("AnaCart");
        }
        GeneCartStor::dispatch();
    } elsif ( $section eq "MyGeneDetail" ) {
        require MyGeneDetail;
        $pageTitle = "My Gene Detail";
        printAppHeader("FindGenes");
        MyGeneDetail::dispatch();
    } elsif ( $section eq "Help" ) {
        $pageTitle = "Help";
        printAppHeader("about");
        require Help;
        Help::dispatch();
    } elsif ( $section eq "GeneDetail" || $page eq "geneDetail" ) {
        require GeneDetail;
        $pageTitle = "Gene Details";
        printAppHeader("FindGenes");
        GeneDetail::dispatch();
    } elsif ( $section eq "MetaGeneDetail" ) {
        require MetaGeneDetail;
        $pageTitle = "Metagenome Gene Details";
        printAppHeader("FindGenes");
        MetaGeneDetail::dispatch();
    } elsif ( $section eq "MetaGeneTable" ) {
        require MetaGeneTable;
        $pageTitle = "Gene List";
        printAppHeader("FindGenes");
        MetaGeneTable::dispatch();
    } elsif ( $section eq "GeneNeighborhood" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require GeneNeighborhood;
        $pageTitle = "Gene Neighborhood";
        printAppHeader("FindGenes");
        GeneNeighborhood::dispatch();
    } elsif ( $section eq "FindClosure" ) {
        require FindClosure;
        $pageTitle = "Functional Closure";
        printAppHeader("AnaCart");
        FindClosure::dispatch();
    } elsif ( $section eq "GeneCassette" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
                               # new for img v2.5 - ken
        require GeneCassette;
        $pageTitle = "IMG Cassette";
        my $numTaxon = printAppHeader("CompareGenomes");
        GeneCassette::dispatch($numTaxon);
    } elsif ( $section eq "MetagPhyloDist" ) {
        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        require MetagPhyloDist;
        $pageTitle = "Phylogenetic Distribution";
        my $numTaxon = printAppHeader( "CompareGenomes", '', '', $js );
        MetagPhyloDist::dispatch($numTaxon);
    } elsif ( $section eq "Cart" ) {
        require Cart;
        $pageTitle = "My Cart";
        printAppHeader("AnaCart");
        Cart::dispatch();
    } elsif ( $section eq "GeneCassetteSearch" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
                               # new for img v2.9 - ken

        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        require GeneCassetteSearch;
        $pageTitle = "IMG Cassette Search";
        my $numTaxon = printAppHeader( "FindGenes", '', '', $js );
        GeneCassetteSearch::dispatch($numTaxon);
    } elsif ( $section eq "TreeFile" ) {
        require TreeFile;
        $pageTitle = "IMG Tree";
        printAppHeader("FindGenomes");
        TreeFile::dispatch();
    } elsif ( $section eq "HorizontalTransfer" ) {
        require HorizontalTransfer;
        $pageTitle = "Horizontal Transfer";
        printAppHeader("FindGenomes");
        HorizontalTransfer::dispatch();
    } elsif ( $section eq "ImgTermStats" ) {
        require ImgTermStats;
        $pageTitle = "IMG Term";
        printAppHeader("FindFunctions");
        ImgTermStats::dispatch();
    } elsif ( $section eq "KoTermStats" ) {
        require KoTermStats;
        $pageTitle = "KO Stats";
        printAppHeader("FindFunctions");
        KoTermStats::dispatch();
    } elsif ( $section eq "HmpTaxonList" ) {
        require HmpTaxonList;
        $pageTitle = "Hmp Genome List";
        if ( WebUtil::paramMatch("_excel") ) {
#            printExcelHeader("genome_export$$.xls");
            IMG::Views::ViewMaker::print_excel_header("genome_export$$.xls");
        } else {
            printAppHeader("FindGenomes");
        }
        HmpTaxonList::dispatch();
    } elsif ( $section eq "EggNog" ) {
        require EggNog;
        $pageTitle = "EggNOG";
        printAppHeader("FindFunctions");
        EggNog::dispatch();
    } elsif ( $section eq "Interpro" ) {
        require Interpro;
        $pageTitle = "Interpro";
        printAppHeader("FindFunctions");
        Interpro::dispatch();
    } elsif ( $section eq "MetaCyc" ) {
        require MetaCyc;
        $pageTitle = "MetaCyc";
        printAppHeader("FindFunctions");
        MetaCyc::dispatch();

    } elsif ( $section eq "Fastbit" ) {
        $pageTitle = "Fastbit Test";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js       = $template->output;
        my $numTaxon = printAppHeader( "FindFunctions", '', '', $js );

        require Fastbit;
        Fastbit::dispatch($numTaxon);
    } elsif ( $section eq 'AnalysisProject' ) {
        $pageTitle = "Analysis Project";
        printAppHeader("FindGenomes");
        require AnalysisProject;
        AnalysisProject::dispatch();
    } elsif ( $section eq "GeneCassetteProfiler" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require GeneCassetteProfiler;
        $pageTitle = "Phylogenetic Profiler";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        my $numTaxon = printAppHeader( "FindGenes", '', '', $js );
        GeneCassetteProfiler::dispatch($numTaxon);
    } elsif ( $section eq "ImgStatsOverview" ) {
        require ImgStatsOverview;
        if ( $cgi->param('excel') eq 'yes' ) {
#            printExcelHeader("stats_export$$.xls");
            IMG::Views::ViewMaker::print_excel_header("stats_export$$.xls");
            ImgStatsOverview::dispatch();
        } else {
            $pageTitle = "IMG Stats Overview";
            printAppHeader("ImgStatsOverview");
            ImgStatsOverview::dispatch();
        }
    } elsif ( $section eq "TaxonEdit" ) {
        require TaxonEdit;
        $pageTitle = "Taxon Edit";
        printAppHeader("Taxon Edit");
        TaxonEdit::dispatch();
    } elsif ( $section eq "GenePageEnvBlast" ) {
        require GenePageEnvBlast;
        $pageTitle = "SNP BLAST";
        printAppHeader("");
        GenePageEnvBlast::dispatch();
    } elsif ( $section eq "GeneProfilerStor" ) {
        require GeneProfilerStor;
        $pageTitle = "Gene Profiler";
        $session->param( "lastCart", "geneCart" );
        printAppHeader("AnaCart");
        GeneProfilerStor::dispatch();
    } elsif ( $section eq "GenomeProperty" ) {

        # --es 10/17/2007
        require GenomeProperty;
        $pageTitle = "GenomeProperty";
        printAppHeader("");
        GenomeProperty::dispatch();
    } elsif ( $section eq "GreenGenesBlast" ) {
        require GreenGenesBlast;
        $pageTitle = "Green Genes BLAST";
        print header( -header => "text/html" );
        GreenGenesBlast::dispatch();
    } elsif ( $section eq "HomologToolkit" ) {
        require HomologToolkit;
        $pageTitle = "Homolog Toolkit";
        printAppHeader("FindGenes");
        HomologToolkit::dispatch();
    } elsif ( $section eq "ImgCompound" ) {
        require ImgCompound;
        $pageTitle = "IMG Compound";

        my $template = HTML::Template->new( filename => "$base_dir/meshTreeHeader.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;
        printAppHeader( "FindFunctions", '', '', $js );

        ImgCompound::dispatch();
    } elsif ( $section eq "ImgCpdCartStor" ) {
        require ImgCpdCartStor;
        $pageTitle = "IMG Compound Cart";
        $session->param( "lastCart", "imgCpdCart" );
        printAppHeader("AnaCart");
        ImgCpdCartStor::dispatch();
    } elsif ( $section eq "ImgTermAndPathTab" ) {
        require ImgTermAndPathTab;
        $pageTitle = "IMG Terms & Pathways";
        printAppHeader("FindFunctions");
        ImgTermAndPathTab::dispatch();
    } elsif ( $section eq "ImgNetworkBrowser" ) {
        require ImgNetworkBrowser;
        $pageTitle = "IMG Network Browser";
        printAppHeader( "FindFunctions", '', '', '', '', 'imgterms.html' );
        ImgNetworkBrowser::dispatch();
    } elsif ( $section eq "ImgPwayBrowser" ) {
        require ImgPwayBrowser;
        $pageTitle = "IMG Pathway Browser";
        printAppHeader("FindFunctions");
        ImgPwayBrowser::dispatch();
    } elsif ( $section eq "ImgPartsListBrowser" ) {
        require ImgPartsListBrowser;
        $pageTitle = "IMG Parts List Browser";
        printAppHeader("FindFunctions");
        ImgPartsListBrowser::dispatch();
    } elsif ( $section eq "ImgPartsListCartStor" ) {
        require ImgPartsListCartStor;
        $pageTitle = "IMG Parts List Cart";
        $session->param( "lastCart", "imgPartsListCart" );
        printAppHeader("AnaCart");
        ImgPartsListCartStor::dispatch();
    } elsif ( $section eq "ImgPartsListDataEntry" ) {
        require ImgPartsListDataEntry;
        $pageTitle = "IMG Parts List Data Entry";
        $session->param( "lastCart", "imgPartsListCart" );
        printAppHeader("AnaCart");
        ImgPartsListDataEntry::dispatch();
    } elsif ( $section eq "ImgPwayCartDataEntry" ) {
        require ImgPwayCartDataEntry;
        $pageTitle = "IMG Pathway Cart Data Entry";
        $session->param( "lastCart", "imgPwayCart" );
        printAppHeader("AnaCart");
        ImgPwayCartDataEntry::dispatch();
    } elsif ( $section eq "ImgPwayCartStor" ) {
        require ImgPwayCartStor;
        $pageTitle = "IMG Pathway Cart";
        $session->param( "lastCart", "imgPwayCart" );
        printAppHeader("AnaCart");
        ImgPwayCartStor::dispatch();
    } elsif ( $section eq "ImgReaction" ) {
        require ImgReaction;
        $pageTitle = "IMG Reaction";
        printAppHeader("FindFunctions");
        ImgReaction::dispatch();
    } elsif ( $section eq "ImgRxnCartStor" ) {
        require ImgRxnCartStor;
        $pageTitle = "IMG Reaction Cart";
        $session->param( "lastCart", "imgRxnCart" );
        printAppHeader("AnaCart");
        ImgRxnCartStor::dispatch();
    } elsif ( $section eq "ImgTermBrowser" ) {
        require ImgTermBrowser;
        $pageTitle = "IMG Term Browser";
        printAppHeader("FindFunctions");
        ImgTermBrowser::dispatch();
    } elsif ( $section eq "ImgTermCartDataEntry" ) {
        require ImgTermCartDataEntry;
        $pageTitle = "IMG Term Cart Data Entry";
        $session->param( "lastCart", "imgTermCart" );
        printAppHeader("AnaCart");
        ImgTermCartDataEntry::dispatch();
    } elsif ( $section eq "ImgTermCartStor" ) {
        require ImgTermCartStor;
        $pageTitle = "IMG Term Cart";
        $session->param( "lastCart", "imgTermCart" );
        printAppHeader("AnaCart");
        ImgTermCartStor::dispatch();
    } elsif ( $section eq "KeggMap" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require KeggMap;
        $pageTitle = "KEGG Map";
        printAppHeader("FindFunctions");
        KeggMap::dispatch();
    } elsif ( $section eq "KeggPathwayDetail" ) {
        require KeggPathwayDetail;
        $pageTitle = "KEGG Pathway Detail";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        my $numTaxon = printAppHeader( "FindFunctions", '', '', $js );
        KeggPathwayDetail::dispatch($numTaxon);
    } elsif ( $section eq "PathwayMaps" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require PathwayMaps;
        $pageTitle = "Pathway Maps";
        printAppHeader("PathwayMaps");
        PathwayMaps::dispatch();
    } elsif ( $section eq "Metagenome" ) {
        require Metagenome;
        $pageTitle = "Metagenome";
        printAppHeader("FindGenomes");
        Metagenome::dispatch();
    } elsif ( $section eq "AllPwayBrowser" ) {
        require AllPwayBrowser;
        $pageTitle = "All Pathways";
        printAppHeader("FindFunctions");
        AllPwayBrowser::dispatch();
    } elsif ( $section eq "MpwPwayBrowser" ) {
        require MpwPwayBrowser;
        $pageTitle = "Mpw Pathway Browser";
        printAppHeader("FindFunctions");
        MpwPwayBrowser::dispatch();
    } elsif ( $section eq "GenomeHits" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require GenomeHits;
        $pageTitle = "Genome Hits";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js       = $template->output;
        my $numTaxon = printAppHeader( "CompareGenomes", '', '', $js );

        GenomeHits::dispatch($numTaxon);
    } elsif ( $section eq "ScaffoldHits" ) {
        require ScaffoldHits;
        $pageTitle = "Scaffold Hits";

        # for download add if WebUtil::paramMatch( "noHeader" ) eq "";
        printAppHeader("AnaCart")
          if WebUtil::paramMatch("noHeader") eq "";
        ScaffoldHits::dispatch();
    } elsif ( $section eq "ScaffoldCart" ) {
        require ScaffoldCart;
        $pageTitle = "Scaffold Cart";
        if (   WebUtil::paramMatch("exportScaffoldCart") ne ""
            || WebUtil::paramMatch("exportFasta") ne "" )
        {

            # export excel
            $session->param( "lastCart", "scaffoldCart" );
        } elsif ( WebUtil::paramMatch("addSelectedToGeneCart") ne "" ) {
        } else {
            $session->param( "lastCart", "scaffoldCart" );
            printAppHeader("AnaCart");
        }
        ScaffoldCart::dispatch();
    } elsif ( $section eq "GenomeCart" ) {
        require GenomeCart;
        $pageTitle = "Genome Cart";
        $session->param( "lastCart", "genomeCart" );
        printAppHeader("AnaCart")
          if WebUtil::paramMatch("noHeader") eq "";
        GenomeCart::dispatch();
    } elsif ( $cgi->param("setTaxonFilter") ne "" && !blankStr($taxon_filter_oid_str) ) {

        # add to genome cart - ken
        require GenomeList;
        GenomeList::clearCache();

        require GenomeCart;
        $pageTitle = "Genome Cart";
        $session->param( "lastCart", "genomeCart" );
        printAppHeader("AnaCart");
        GenomeCart::dispatch();
    } elsif ( $section eq "MetagenomeHits" ) {
        require MetagenomeHits;
        $pageTitle = "Genome Hits";

        # for download add if WebUtil::paramMatch( "noHeader" ) eq "";
        printAppHeader("FindGenomes")
          if WebUtil::paramMatch("noHeader") eq "";
        MetagenomeHits::dispatch();
    } elsif ( $section eq "MetaFileHits" ) {
        require MetaFileHits;
        $pageTitle = "Metagenome Hits";

        # for download add if WebUtil::paramMatch( "noHeader" ) eq "";
        printAppHeader("FindGenomes")
          if ( $cgi->param('noHeader') eq '' && WebUtil::paramMatch("noHeader") eq "" );
        MetaFileHits::dispatch();
    } elsif ( $section eq "MetagenomeGraph" ) {
        WebUtil::timeout( 60 * 40 );
        require MetagenomeGraph;
        $pageTitle = "Genome Graph";

        # for download add if WebUtil::paramMatch( "noHeader" ) eq "";
        printAppHeader("FindGenomes")
          if WebUtil::paramMatch("noHeader") eq "";
        MetagenomeGraph::dispatch();
    } elsif ( $section eq "MetaFileGraph" ) {
        require MetaFileGraph;
        $pageTitle = "Metagenome Graph";

        # for download add if WebUtil::paramMatch( "noHeader" ) eq "";
        printAppHeader("FindGenomes")
          if WebUtil::paramMatch("noHeader") eq "";
        MetaFileGraph::dispatch();
    } elsif ( $section eq "MissingGenes" ) {
        require MissingGenes;
        $pageTitle = "MissingGenes";
        printAppHeader("AnaCart");
        MissingGenes::dispatch();
    } elsif ( $section eq "MyFuncCat" ) {
        require MyFuncCat;
        $pageTitle = "My Functional Categories";
        printAppHeader("AnaCart");
        MyFuncCat::dispatch();
    } elsif ( $section eq "MyIMG" ) {
        require MyIMG;
        $pageTitle = "MyIMG";
        if ( $page eq "taxonUploadForm" ) {
            printAppHeader("AnaCart");
        } else {
            printAppHeader( "MyIMG", '', '', '', '', 'MyIMG4.pdf' ) if WebUtil::paramMatch("noHeader") eq "";
        }
        MyIMG::dispatch();
    } elsif ( $section eq "ImgGroup" ) {
        require ImgGroup;
        $pageTitle = "MyIMG";
        printAppHeader("MyIMG") if WebUtil::paramMatch("noHeader") eq "";
        ImgGroup::dispatch();
    } elsif ( $section eq "Workspace" ) {
        require Workspace;
        my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
        $pageTitle = "Workspace";
        my $header = $cgi->param("header");
        if ( WebUtil::paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
                                                   # no header
        } elsif ( $header eq "" && WebUtil::paramMatch("noHeader") eq "" ) {
            printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
        }
        Workspace::dispatch();
    } elsif ( $section eq "WorkspaceGeneSet" ) {
        require WorkspaceGeneSet;
        my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
        $pageTitle = "Workspace Gene Sets";
        my $header = $cgi->param("header");
        if ( WebUtil::paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
                                                   # no header
        } elsif ( $header eq "" && WebUtil::paramMatch("noHeader") eq "" ) {
            printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
        }
        WorkspaceGeneSet::dispatch();
    } elsif ( $section eq "WorkspaceFuncSet" ) {
        require WorkspaceFuncSet;
        my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
        $pageTitle = "Workspace Function Sets";
        my $header = $cgi->param("header");
        if ( WebUtil::paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
                                                   # no header
        } elsif ( $header eq "" && WebUtil::paramMatch("noHeader") eq "" ) {
            printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
        }
        WorkspaceFuncSet::dispatch();
    } elsif ( $section eq "WorkspaceGenomeSet" ) {
        require WorkspaceGenomeSet;
        my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
        $pageTitle = "Workspace Genome Sets";
        my $header = $cgi->param("header");
        if ( WebUtil::paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
                                                   # no header
        } elsif ( $header eq "" && WebUtil::paramMatch("noHeader") eq "" ) {
            printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
        }
        WorkspaceGenomeSet::dispatch();
    } elsif ( $section eq "WorkspaceScafSet" ) {
        require WorkspaceScafSet;
        my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
        $pageTitle = "Workspace Scaffold Sets";
        my $header = $cgi->param("header");
        if ( WebUtil::paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
                                                   # no header
        } elsif ( $header eq "" && WebUtil::paramMatch("noHeader") eq "" ) {
            printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
        }
        WorkspaceScafSet::dispatch();
    } elsif ( $section eq "WorkspaceRuleSet" ) {
        require WorkspaceRuleSet;
        $pageTitle = "Workspace";
        my $header = $cgi->param("header");
        if ( WebUtil::paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
                                                   # no header
        } elsif ( $header eq "" && WebUtil::paramMatch("noHeader") eq "" ) {
            printAppHeader("MyIMG", '', '', '', '', 'IMGWorkspaceUserGuide.pdf' );
        }
        WorkspaceRuleSet::dispatch();
    } elsif ( $section eq "WorkspaceJob" ) {
        require WorkspaceJob;
        $pageTitle = "Workspace";
        my $header = $cgi->param("header");
        if ( WebUtil::paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
                                                   # no header
        } elsif ( $header eq "" && WebUtil::paramMatch("noHeader") eq "" ) {
            printAppHeader("MyIMG", '', '', '', '', 'IMGWorkspaceUserGuide.pdf' );
        }
        WorkspaceJob::dispatch();

    } elsif ( $section eq "WorkspaceBcSet" ) {
        require WorkspaceBcSet;
        $pageTitle = "Workspace";
        printAppHeader("MyIMG") if WebUtil::paramMatch("noHeader") eq "";
        WorkspaceBcSet::dispatch();
    } elsif ( $section eq "MyBins" ) {
        require MyBins;
        $pageTitle = "My Bins";
        printAppHeader("MyIMG");
        MyBins::dispatch();
    } elsif ( $section eq "About" ) {
        require About;
        $pageTitle = "About";
        printAppHeader("about");
        About::dispatch();
    } elsif ( $section eq "NcbiBlast" ) {
        require NcbiBlast;
        $pageTitle = "NCBI BLAST";

        #print header( -header => "text/html" );
        printAppHeader("FindGenes");
        NcbiBlast::dispatch();
    } elsif ( $section eq "NrHits" ) {
        require NrHits;
        $pageTitle = "Gene Details";
        printAppHeader("");
        NrHits::dispatch();
    } elsif ( $section eq "Operon" ) {
        require Operon;
        $pageTitle = "Operons";
        printAppHeader("FindGenes");
        Operon::dispatch();
    } elsif ( $section eq "OtfBlast" ) {
        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js = $template->output;

        require OtfBlast;
        $pageTitle = "Gene Details";

        #printAppHeader("FindGenes");
        my $numTaxon = printAppHeader( "FindGenes", '', '', $js );

        OtfBlast::dispatch($numTaxon);
    } elsif ( $section eq "PepStats" ) {
        require PepStats;
        $pageTitle = "Peptide Stats";
        printAppHeader("FindGenes");
        PepStats::dispatch();
    } elsif ( $section eq "PfamCategoryDetail" ) {
        require PfamCategoryDetail;
        $pageTitle = "Pfam Category";
        printAppHeader("FindFunctions");
        PfamCategoryDetail::dispatch();
    } elsif ( $section eq "PhyloCogs" ) {
        require PhyloCogs;
        $pageTitle = "Phylogenetic Marker COGs";
        my $numTaxon = printAppHeader("CompareGenomes");
        PhyloCogs::dispatch($numTaxon);
    } elsif ( $section eq "PhyloDist" ) {
        require PhyloDist;
        $pageTitle = "Phylogenetic Distribution";
        printAppHeader("FindGenes");
        PhyloDist::dispatch();
    } elsif ( $section eq "PhyloOccur" ) {
        require PhyloOccur;
        $pageTitle = "Phylogenetic Occurrence Profile";
        printAppHeader("AnaCart");
        PhyloOccur::dispatch();
    } elsif ( $section eq "PhyloProfile" ) {
        require PhyloProfile;
        $pageTitle = "Phylogenetic Profile";
        printAppHeader("AnaCart");
        PhyloProfile::dispatch();
    } elsif ( $section eq "PhyloSim" ) {
        require PhyloSim;
        $pageTitle = "Phylogenetic Similarity Search";
        printAppHeader("FindGenes");
        PhyloSim::dispatch();
    } elsif ( $section eq "PhyloClusterProfiler" ) {
        require PhyloClusterProfiler;
        $pageTitle = "Phylogenetic Profiler using Clusters";
        my $numTaxon = printAppHeader("FindGenes");
        PhyloClusterProfiler::dispatch($numTaxon);
    } elsif ( $section eq "PhylogenProfiler" ) {
        require PhylogenProfiler;
        $pageTitle = "Phylogenetic Profiler";

        require GenomeListJSON;
        my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
        $template->param( base_url => $base_url );
        $template->param( YUI      => $YUI );
        my $js       = $template->output;
        my $numTaxon = printAppHeader( "FindGenes", '', '', $js );

        PhylogenProfiler::dispatch($numTaxon);
    } elsif ( $section eq "ProteinCluster" ) {
        require ProteinCluster;
        $pageTitle = "Protein Cluster";
        printAppHeader("FindGenes");
        ProteinCluster::dispatch();
    } elsif ( $section eq "ProfileQuery" ) {
        require ProfileQuery;
        $pageTitle = "Profile Query";
        printAppHeader("FindFunctions");
        ProfileQuery::dispatch();
    } elsif ( $section eq "PdbBlast" ) {
        ## --es 06/19/2007
        require PdbBlast;
        $pageTitle = "Protein Data Bank BLAST";
        print header( -header => "text/html" );
        PdbBlast::dispatch();
    } elsif ( $section eq "Registration" ) {
        require Registration;
        $pageTitle = "Registration";
        printAppHeader("MyIMG");
        Registration::dispatch();
    } elsif ( $section eq "SixPack" ) {
        require SixPack;
        $pageTitle = "Six Frame Translation";
        printAppHeader("FindGenes");
        SixPack::dispatch();
    } elsif ( $section eq "Sequence" ) {
        require Sequence;
        $pageTitle = "Six Frame Translation";
        printAppHeader("FindGenes");
        Sequence::dispatch();
    } elsif ( $section eq "ScaffoldGraph" ) {
        require ScaffoldGraph;
        $pageTitle = "Chromosome Viewer";
        printAppHeader("FindGenomes");
        ScaffoldGraph::dispatch();
    } elsif ( $section eq "MetaScaffoldGraph" ) {
        require MetaScaffoldGraph;
        $pageTitle = "Chromosome Viewer";
        printAppHeader("FindGenomes");
        MetaScaffoldGraph::dispatch();
    } elsif ( $section eq "TaxonCircMaps" ) {
        require TaxonCircMaps;
        $pageTitle = "Circular Map";
        printAppHeader("FindGenomes");
        TaxonCircMaps::dispatch();
    } elsif ( $section eq 'GenerateArtemisFile' ) {
        require GenerateArtemisFile;
        printAppHeader("FindGenomes");
        GenerateArtemisFile::dispatch();
    } elsif ( $section eq "GenomeList" ) {
        require GenomeList;
        $pageTitle = "Genome List";
        printAppHeader("FindGenomes");
        GenomeList::dispatch();
    } elsif ( $section eq "TaxonDetail" || $page eq "taxonDetail" ) {
        require TaxonDetail;
        $pageTitle = "Taxon Details";
        if ( $page eq 'taxonArtemisForm' ) {
            printAppHeader( "FindGenomes", '', '', '', '', 'GenerateGenBankFile.pdf' );
        } else {
            printAppHeader("FindGenomes") if WebUtil::paramMatch("noHeader") eq "";
        }
        TaxonDetail::dispatch();
    } elsif ( $section eq "TaxonDeleted" ) {
        require TaxonDeleted;
        $pageTitle = "Taxon Deleted";
        printAppHeader("FindGenomes");
        TaxonDeleted::dispatch();
    } elsif ( WebUtil::paramMatch("taxon_oid") && scalar( $cgi->param() ) < 2 ) {

        # if only taxon_oid is specified assume taxon detail page
        $session->param( "section", "TaxonDetail" );
        $session->param( "page",    "taxonDetail" );
        require TaxonDetail;
        $pageTitle = "Taxon Details";
        if ( $page eq 'taxonArtemisForm' ) {
            printAppHeader( "FindGenomes", '', '', '', '', 'GenerateGenBankFile.pdf' );
        } else {
            printAppHeader("FindGenomes") if WebUtil::paramMatch("noHeader") eq "";
        }
        TaxonDetail::dispatch();
    } elsif ( $section eq "MetaDetail" || $page eq "metaDetail" ) {
        require MetaDetail;
        $pageTitle = "Microbiome Details";
        if ( $page eq 'taxonArtemisForm' ) {
            printAppHeader( "FindGenomes", '', '', '', '', 'GenerateGenBankFile.pdf' );
        } else {
            printAppHeader("FindGenomes");    # if WebUtil::paramMatch("noHeader") eq "";
        }
        MetaDetail::dispatch();
    } elsif ( $section eq "TaxonList" ) {
        require TaxonList;
        $pageTitle = "Taxon Browser";
        if ( $page eq 'categoryBrowser' ) {
            $pageTitle = "Category Browser";
        }
        if ( WebUtil::paramMatch("_excel") ) {
#            printExcelHeader("genome_export$$.xls");
            IMG::Views::ViewMaker::print_excel_header("genome_export$$.xls");
        } else {
            if (   $page eq 'taxonListAlpha'
                || $page eq 'gebaList'
                || $page eq 'selected' )
            {
                printAppHeader( "FindGenomes", '', '', '', '', 'GenomeBrowser.pdf' );
            } else {
                printAppHeader("FindGenomes");
            }
        }
        TaxonList::dispatch();
    } elsif ( $section eq "TaxonSearch" ) {
        require TaxonSearch;
        $pageTitle = "Taxon Search";
        printAppHeader("FindGenomes");
        TaxonSearch::dispatch();
    } elsif ( $section eq "TigrBrowser" ) {
        require TigrBrowser;
        $pageTitle = "TIGRfam Browser";
        printAppHeader("FindFunctions");
        TigrBrowser::dispatch();
    } elsif ( $section eq "TreeQ" ) {
        require TreeQ;
        $pageTitle = "Dynamic Tree View";
        printAppHeader("");
        TreeQ::dispatch();
    } elsif ( $section eq "Vista" ) {
        require Vista;
        $pageTitle = "VISTA";
        my $page = $cgi->param("page");
        if ( $page eq "toppage" ) {
            $pageTitle = "Synteny Viewers";
        }
        printAppHeader("CompareGenomes");
        Vista::dispatch();
    } elsif ( $section eq "IMGContent" ) {
        require IMGContent;
        $pageTitle = "IMG Content";
        printAppHeader("IMGContent");
        IMGContent::dispatch();
    } elsif ( $section eq "IMGProteins" ) {
        require IMGProteins;
        $pageTitle = "Proteomics";
        printAppHeader( "Proteomics", '', '', '', '', "Proteomics.pdf" );
        IMGProteins::dispatch();
    } elsif ( $section eq "Methylomics" ) {
        require Methylomics;
        $pageTitle = "Methylomics Experiments";
        printAppHeader( "Methylomics", '', '', '', '', "Methylomics.pdf" );
        Methylomics::dispatch();
    } elsif ( $section eq "RNAStudies" ) {
        WebUtil::timeout( 60 * 20 );    # WebUtil::timeout in 20 minutes
        require RNAStudies;
        $pageTitle = "RNASeq Expression Studies";
        if ( WebUtil::paramMatch("samplePathways") ne "" ) {
            $pageTitle = "RNASeq Studies: Pathways";
        } elsif ( WebUtil::paramMatch("describeSamples") ne "" ) {
            $pageTitle = "RNASeq Studies: Describe";
        }
        printAppHeader( "RNAStudies", '', '', '', '', "RNAStudies.pdf" )
          if $cgi->param("noHeader") eq "";
        RNAStudies::dispatch();
    } elsif ( $page eq "znormNote" ) {
        ## Non-section related dispatch
        $pageTitle = "Z-normalization";
        printAppHeader("FindGenes");
        printZnormNote();
    } elsif ( $cgi->param("setTaxonFilter") ne "" && blankStr($taxon_filter_oid_str) ) {
        $pageTitle = "Genome Selection Message";
        printAppHeader("FindGenomes");
        printMessage( "Saving 'no selections' is the same as selecting " . "all genomes. Genome filtering is disabled.\n" );

    } elsif ( $cgi->param("exportGenes") ne "" && $cgi->param("exportType") eq "excel" ) {
        my @gene_oid = $cgi->param("gene_oid");
        #if ( scalar(@gene_oid) == 0 ) {
        #    printAppHeader();
        #    webError("You must select at least one gene to export.");
        #}
        printExcelHeader("gene_export$$.xls");
        # --es 03/17/08 Use larger version with more columns.
        #printGenesToExcel( \@gene_oid );
        require GeneCartStor;
        GeneCartStor::printGenesToExcelLarge( \@gene_oid );
        WebUtil::webExit(0);
    } elsif ( $cgi->param("exportGenes") ne ""
        && $cgi->param("exportType") eq "nucleic" )
    {
        require GenerateArtemisFile;
        $pageTitle = "Gene Export";
        printAppHeader("");
        GenerateArtemisFile::prepareProcessGeneFastaFile();
    } elsif ( $cgi->param("exportGenes") ne "" && $cgi->param("exportType") eq "amino" ) {
        require GenerateArtemisFile;
        $pageTitle = "Gene Export";
        printAppHeader("");
        GenerateArtemisFile::prepareProcessGeneFastaFile(1);
    } elsif ( $cgi->param("exportGenes") ne "" && $cgi->param("exportType") eq "tab" ) {
        $pageTitle = "Gene Export";
        printAppHeader("");
        print "<h1>Gene Export</h1>\n";
        my @gene_oid = $cgi->param("gene_oid");
        my $nGenes   = @gene_oid;
        if ( $nGenes == 0 ) {
            print "<p>\n";
            webErrorNoFooter("Select genes to export first.");
        }
        print "</font>\n";
        print "<p>\n";
        print "Export in tab-delimited format for copying and pasting.\n";
        print "</p>\n";
        print "<pre>\n";

        printGeneTableExport( \@gene_oid );
        print "</pre>\n";
    } elsif ( ( $public_login || $user_restricted_site ) && $cgi->param("logout") ne "" ) {

        #        if ( !$oldLogin && $sso_enabled ) {
        #
        #            # do no login log here
        #        } else {
        #            WebUtil::loginLog( 'logout main.pl', 'img' );
        #        }

        $session->param( "blank_taxon_filter_oid_str", "1" );
        $session->param( "oldLogin",                   0 );
        setTaxonSelections("");
        printAppHeader("logout");

        print "<div id='message'>\n";
        print "<p>\n";
        print "Logged out.\n";
        print "</p>\n";
        print "</div>\n";
        print qq{
            <p>
            <a href='main.cgi'>Sign in</a>
            </p>
        };

        # sso
        if ( !$oldLogin && $sso_enabled ) {
            require Caliban;
            Caliban::logout(1);
        } else {
            require Caliban;
            Caliban::logout();

            #            $session->param( "contact_oid", "" );
            #            my $session = WebUtil::getSession();
            #            $session->delete();
            #            $session->flush();    # Recommended practice says use flush() after delete().
        }
    } elsif ( $page eq "message" ) {
        $pageTitle = "Message";
        my $message       = $cgi->param("message");
        my $menuSelection = $cgi->param("menuSelection");
        printAppHeader($menuSelection);
        print "<div id='message'>\n";
        print "<p>\n";
        print escapeHTML($message);
        print "</p>\n";
        print "</div>\n";
    } elsif ( $section eq "Questions" || $page eq "questions" ) {
        $pageTitle = "Questions / Comments";
        printAppHeader("about") if $cgi->param("noHeader") eq "";
        require Questions;
        Questions::dispatch();
        if ( $cgi->param("noHeader") eq "true" ) {

            # form redirect submit to jira - ken
            WebUtil::webExit(0);
        }
    } elsif ( WebUtil::paramMatch("uploadTaxonSelections") ne "" ) {
        $pageTitle = "Genome Browser";
        require TaxonList;
        $taxon_filter_oid_str = TaxonList::uploadTaxonSelections();
        setTaxonSelections($taxon_filter_oid_str);
        printAppHeader( "FindGenomes", '', '', '', '', 'GenomeBrowser.pdf' );
        TaxonList::printTaxonTable();
    } elsif ( $page eq "Imas" ) {
        ## Test GWT javascript incorporation.
        $pageTitle = "Imas";
        require Imas;
        printAppHeader( "", "", "Imas" );
        Imas::printForm();
    } elsif ( $page eq "Home" ) {
        $homePage = 1;
        printAppHeader("Home");
    } else {
        my $rurl = $cgi->param("redirect");

        # redirect on login
        if ( ( $public_login || $user_restricted_site ) && $rurl ne "" ) {
            redirecturl($rurl);
        } else {
            $homePage = 1;
            printAppHeader("Home");
        }
    }
} else {
    my $rurl = $cgi->param("redirect");
    if ( ( $public_login || $user_restricted_site ) && $rurl ne "" ) {
        redirecturl($rurl);
    } else {
        $homePage = 1;
        printAppHeader("Home");
    }
}

printContentEnd();

# catch all if loading still showing
printMainFooter($homePage);
WebUtil::webExit(0);

#
# html header to print 1st div in new layout v3.3
# - Ken
#
# $current - current menu
# $title - page title
# $gwt - google
# $content_js - misc javascript
# $yahoo_js - yahoo js
# $numTaxons - num of taxons saved
#
sub printHTMLHead {
    my ( $current, $title, $gwt, $content_js, $yahoo_js, $numTaxons ) = @_;

    my $str = qq{<font style="color: blue;"> ALL </font>  <br/> Genomes };
    if ( $numTaxons eq "" ) {

    } else {

        my $url = "$main_cgi?section=GenomeCart&page=genomeCart";
        $url = WebUtil::alink( $url, $numTaxons );
        my $plural = ( $numTaxons > 1 ) ? "s" : "";    # plural if 2 or more +BSJ 3/16/10
        $str = "$url <br/>  Genome$plural";
    }

    if ( $current eq "logout" || $current eq "login" ) {
        $str = "";
    }

    my $enable_google_analytics = $env->{enable_google_analytics};
    my $googleStr;
    if ($enable_google_analytics) {
        my ( $server, $google_key ) = WebUtil::getGoogleAnalyticsKey();
        $googleStr = googleAnalyticsJavaScript2( $server, $google_key );
        $googleStr = "" if ( $google_key eq "" );
    }

    my $template = HTML::Template->new( filename => "$base_dir/header-v40.html" );
    $template->param( title        => $title );
    $template->param( gwt          => $gwt );
    $template->param( base_url     => $base_url );
    $template->param( YUI          => $YUI );
    $template->param( content_js   => $content_js );
    $template->param( yahoo_js     => $yahoo_js );
    $template->param( googleStr    => $googleStr );
    $template->param( top_base_url => $top_base_url );
    print $template->output;

    if ( $current eq "logout" || $current eq "login" ) {
        my $logofile;
        if ($img_edu) {
            $logofile = 'logo-JGI-IMG-EDU.png';
        } elsif ($img_hmp) {
            $logofile = 'logo-JGI-IMG-HMP.png';
        } elsif ($abc) {
            $logofile = 'logo-JGI-IMG-ABC.png';
        } elsif ($img_proportal) {
            $logofile = 'logo-JGI-IMG-ProPortal.png';
        } elsif ( $img_er && $user_restricted_site && !$include_metagenomes ) {
            $logofile = 'logo-JGI-IMG-ER.png';
        } elsif ( $include_metagenomes && $user_restricted_site ) {
            #$logofile = 'logo-JGI-IMG-MER.png';
            $logofile = 'logo-JGI-IMG-ER.png';
        } elsif ($include_metagenomes) {
            #$logofile = 'logo-JGI-IMG-M.png';
$logofile = 'logo-JGI-IMG.png';
        } else {
            $logofile = 'logo-JGI-IMG.png';
        }

        print qq{
<header id="jgi-header">
<div id="jgi-logo">
<a href="http://jgi.doe.gov/" title="DOE Joint Genome Institute - $imgAppTerm">
<img width="480" height="70" src="$top_base_url/images/$logofile" alt="DOE Joint Genome Institute's $imgAppTerm logo"/>
</a>
</div>
<nav class="jgi-nav">
    <ul>
    <li><a href="http://jgi.doe.gov">JGI Home</a></li>
    <li><a href="https://sites.google.com/a/lbl.gov/img-form/contact-us">Contact Us</a></li>
    </ul>
</nav>
</header>

};

    } else {
        my $logofile;
        if ($img_edu) {
            $logofile = 'logo-JGI-IMG-EDU.png';
        } elsif ($img_hmp) {
            $logofile = 'logo-JGI-IMG-HMP.png';
        } elsif ($abc) {
            $logofile = 'logo-JGI-IMG-ABC.png';
        } elsif ($img_proportal) {
            $logofile = 'logo-JGI-IMG-ProPortal.png';
        } elsif ( $img_er && $user_restricted_site && !$include_metagenomes ) {
            $logofile = 'logo-JGI-IMG-ER.png';
        } elsif ( $include_metagenomes && $user_restricted_site ) {
            #$logofile = 'logo-JGI-IMG-MER.png';
            $logofile = 'logo-JGI-IMG-ER.png';
        } elsif ( $img_proportal || $include_metagenomes ) {
            #$logofile = 'logo-JGI-IMG-M.png';
            $logofile = 'logo-JGI-IMG.png';
        } else {
            $logofile = 'logo-JGI-IMG.png';
        }

        print qq{
<header id="jgi-header">
<div id="jgi-logo">
<a href="http://jgi.doe.gov/" title="DOE Joint Genome Institute - $imgAppTerm">
<img width="480" height="70" src="$top_base_url/images/$logofile" alt="DOE Joint Genome Institute's $imgAppTerm logo"/>
</a>
</div>
<div id="genome_cart" class="shadow"> $str </div>
};

       # if ( $current ne "logout" && $current ne "login" ) {
            my $enable_autocomplete = $env->{enable_autocomplete};
            if ($enable_autocomplete) {
                print qq{
        <div id="quicksearch">
        <form name="taxonSearchForm" enctype="application/x-www-form-urlencoded" action="main.cgi" method="post">
            <input type="hidden" value="orgsearch" name="page">
            <input type="hidden" value="TaxonSearch" name="section">

            <a style="color: black;" href="$base_url/doc/orgsearch.html">
            <font style="color: black;"> Quick Genome Search: </font>
            </a><br/>
            <div id="myAutoComplete" >
            <input id="myInput" type="text" style="width: 110px; height: 20px;" name="taxonTerm" size="12" maxlength="256">
            <input type="submit" alt="Go" value='Go' name="_section_TaxonSearch_x" style="vertical-align: middle; margin-left: 125px;">
            <div id="myContainer"></div>
            </div>
        </form>
        </div>
            };

                # https://localhost/~kchu/preComputedData/autocompleteAll.php
                my $autocomplete_url = "$top_base_url" . "api/";

                #my $autocomplete_url = "https://localhost/~kchu/api/";

                if ($include_metagenomes) {
                    $autocomplete_url .= 'autocompleteAll.php';
                } else {
                    $autocomplete_url .= 'autocompleteIsolate.php';
                }

                print <<EOF;
<script type="text/javascript">
YAHOO.example.BasicRemote = function() {
    // Use an XHRDataSource
    var oDS = new YAHOO.util.XHRDataSource("$autocomplete_url");
    // Set the responseType
    oDS.responseType = YAHOO.util.XHRDataSource.TYPE_TEXT;
    // Define the schema of the delimited results
    oDS.responseSchema = {
        recordDelim: "\\n",
        fieldDelim: "\\t"
    };
    // Enable caching
    oDS.maxCacheEntries = 5;

    // Instantiate the AutoComplete
    var oAC = new YAHOO.widget.AutoComplete("myInput", "myContainer", oDS);

    return {
        oDS: oDS,
        oAC: oAC
    };
}();
</script>

EOF
            }
        #}

        if ( $current ne "login" ) {
            printLogout();
        }

        if ($img_proportal) {
            print qq{
        <a href="http://proportal.mit.edu/">
        <img id='mit_logo' src="$base_url/images/MIT_logo.gif" alt="MIT ProPortal logo" title="MIT ProPortal"/>
        </a>
            };
        } elsif ($img_hmp) {
            print qq{
<a href="http://www.hmpdacc.org">
<img id="hmp_logo" src="https://img.jgi.doe.gov/imgm_hmp/images/hmp_logo.png" alt="hmp"/>
</a>
            };
        }

        print qq{
</header>
        };
    }

    print qq{
    <div id="myclear"></div>
    };
}

# menu
# 2nd div
#
# $current - which top level menu to highlight
sub printMenuDiv {
    my ( $current, $dbh ) = @_;

    my $template = HTML::Template->new( filename => "$base_dir/menu-template.html" );

    my $contact_oid = WebUtil::getContactOid();
    my $isEditor    = 0;
    if ($user_restricted_site) {
        $isEditor = WebUtil::isImgEditor( $dbh, $contact_oid );
    }
    my $super_user = WebUtil::getSuperUser();

    $img_internal        = 0 if ( $img_internal        eq "" );
    $include_metagenomes = 0 if ( $include_metagenomes eq "" );
    my $not_include_metagenomes = !$include_metagenomes;
    $enable_cassette   = 0 if ( $enable_cassette   eq "" );
    $enable_workspace  = 0 if ( $enable_workspace  eq "" );
    $include_img_terms = 0 if ( $include_img_terms eq "" );
    $img_pheno_rule    = 0 if ( $img_pheno_rule    eq "" );
    $enable_biocluster = 0 if ( $enable_biocluster eq "" );
    $img_edu           = 0 if ( $img_edu           eq "" );
    $scaffold_cart     = 0 if ( $scaffold_cart     eq "" );

    $template->param( img_internal            => $img_internal );
    $template->param( include_metagenomes     => $include_metagenomes );
    $template->param( not_include_metagenomes => $not_include_metagenomes );
    $template->param( enable_cassette         => $enable_cassette );
    $template->param( enable_workspace        => $enable_workspace );

    my $enable_interpro = $env->{enable_interpro};
    $template->param( enable_interpro => $enable_interpro );

    #$template->param( img_edu           => $img_edu );
    $template->param( not_img_edu       => !$img_edu );
    $template->param( scaffold_cart     => $scaffold_cart );
    $template->param( img_submit_url    => $img_submit_url );
    $template->param( base_url          => $base_url );
    #$template->param( domain_name       => $domain_name );
    $template->param( main_cgi_url      => "$cgi_url/$main_cgi" );
    $template->param( img_er            => $img_er );
    $template->param( isEditor          => $isEditor );
    $template->param( imgAppTerm        => $imgAppTerm );
    $template->param( include_img_terms => $include_img_terms );
    $template->param( img_pheno_rule    => $img_pheno_rule );
    $template->param( enable_biocluster => $enable_biocluster );
    $template->param( top_base_url      => $top_base_url );
    $template->param( enable_ani        => $enable_ani );

    #if ( $super_user eq 'Yes' ) {
    $template->param( enable_omics => 1 );

    #}

    if ( $enable_mybin && canEditBin( $dbh, $contact_oid ) ) {
        $template->param( enable_mybins => 1 );
    }

    if (   $current eq "Home"
        || $current eq ""
        || $current eq "ImgStatsOverview"
        || $current eq "IMGContent" )
    {
        $template->param( highlight_1 => 'class="highlight"' );
    }

    # find genomes
    if ( $current eq "FindGenomes" ) {
        $template->param( highlight_2 => 'class="highlight"' );
    }

    # Find genes
    if ( $current eq "FindGenes" ) {
        $template->param( highlight_3 => 'class="highlight"' );
    }

    if ($enable_cassette) {
        $template->param( find_gene_1 => '1' );
    }

    # FindFunctions
    if ( $current eq "FindFunctions" ) {
        $template->param( highlight_4 => 'class="highlight"' );
    }

    # compare genomes
    if ( $current eq "CompareGenomes" ) {
        $template->param( highlight_5 => 'class="highlight"' );
    }

    # Analysis Carts
    if ( $current eq "AnaCart" ) {
        $template->param( highlight_6 => 'class="highlight"' );
    }

    # omics
    if ( $current eq "Omics" ) {
        $template->param( highlight_9 => 'class="highlight"' );
    }

    # getsme
    if ( $current eq "getsme" && !$abc ) {
        $template->param( highlight_10 => 'class="highlight"' );
    }

    # My IMG
    if ( $current eq "MyIMG" ) {
        $template->param( highlight_7 => 'class="highlight"' );
    }
    if ( $contact_oid > 0 && $show_myimg_login ) {
        $template->param( my_img_1 => '1' );
    }
    if (   $contact_oid > 0
        && $show_myimg_login
        && $myimg_job )
    {
        $template->param( my_img_2 => '1' );
    }
    if ( ( $public_login || $user_restricted_site ) ) {
        $template->param( my_img_3 => '1' );
    }

    # using img
    if ( $current eq "about" ) {
        $template->param( highlight_8 => 'class="rightmenu righthighlight"' );
    } else {
        $template->param( highlight_8 => 'class="rightmenu"' );
    }

    print $template->output;
}

# bread crumbs frame
# - bread crumbs
# - loading message
# - help
#
# 3rd div - for other pages - not home page
#
# TODO - loading and help
#
# $current - menu
# $help - help links - if blank do not display
#
sub printBreadcrumbsDiv {
    my ( $current, $help, $dbh ) = @_;
    if ( $current eq "logout" || $current eq "login" ) {
        return;
    }

    my $contact_oid = WebUtil::getContactOid();
    my $isEditor    = 0;
    if ($user_restricted_site) {
        $isEditor = WebUtil::isImgEditor( $dbh, $contact_oid );
    }

    # find last cart if any
    my $lastCart = $session->param("lastCart");
    $lastCart = "geneCart" if $lastCart eq "";
    if (
        !$isEditor
        && (   $lastCart eq "imgTermCart"
            || $lastCart eq "imgPwayCart"
            || $lastCart eq "imgRxnCart"
            || $lastCart eq "imgCpdCart"
            || $lastCart eq "imgPartsListCart"
            || $lastCart eq "curaCart" )
      )
    {
        $lastCart = "funcCart";
    }

    my $str = "";
    $str = WebUtil::alink( $main_cgi, "Home" );

    if ( $current ne "" ) {
        my $section = $cgi->param("section");
        my $page    = $cgi->param("page");

        my $compare_url   = WebUtil::alink( "$main_cgi?section=CompareGenomes&page=compareGenomes", "Compare Genomes" );
        my $synteny_url   = WebUtil::alink( "$main_cgi?section=Vista&page=toppage",                 "Synteny Viewers" );
        my $abundance_url = WebUtil::alink( "$main_cgi?section=AbundanceProfiles&page=topPage",     "Abundance Profiles Tools" );
        if ( $section eq "Vista" && $page ne "toppage" ) {
            $str .= " &gt; $compare_url &gt; $synteny_url ";
        } elsif ( $section eq "DotPlot" ) {
            $str .= " &gt; $compare_url &gt; $synteny_url ";
        } elsif ( $section eq "Artemis" ) {
            $str .= " &gt; $compare_url &gt; $synteny_url ";
        } elsif ( $section eq "AbundanceProfiles" && $page ne "topPage" ) {
            $str .= " &gt; $compare_url &gt; $abundance_url ";
        } elsif ( $section eq "AbundanceProfileSearch" && $page ne "topPage" ) {
            $str .= " &gt; $compare_url &gt; $abundance_url ";
        } elsif ( $section eq "MyBins" ) {
            my $display = $breadcrumbs{$current};
            $display = WebUtil::alink( "main.cgi?section=MyIMG", $display );
            my $tmp = WebUtil::alink( "main.cgi?section=MyBins", "MyBins" );
            $str .= " &gt; $display &gt; $tmp ";

        } elsif ( $section eq "WorkspaceGeneSet" ) {

            # this should be MyING
            my $display = $breadcrumbs{$current};
            $display = WebUtil::alink( "main.cgi?section=MyIMG", $display );
            my $tmp          = WebUtil::alink( "main.cgi?section=Workspace",        "Workspace" );
            my $gene_set_url = WebUtil::alink( "main.cgi?section=WorkspaceGeneSet", "Gene Sets" );
            $str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
            if ( $page ne "" ) {
                my $folder = $cgi->param("folder");
                if ( $page eq "view" || $page eq "delete" ) {
                    my $tmp = WebUtil::alink( "main.cgi?section=WorkspaceGeneSet", $folder );
                    $str .= " &gt; $tmp ";
                }
                $str .= " &gt; $page ";
            }

        } elsif ( $section eq "WorkspaceFuncSet" ) {

            # this should be MyING
            my $display = $breadcrumbs{$current};
            $display = WebUtil::alink( "main.cgi?section=MyIMG", $display );
            my $tmp          = WebUtil::alink( "main.cgi?section=Workspace",        "Workspace" );
            my $gene_set_url = WebUtil::alink( "main.cgi?section=WorkspaceFuncSet", "Function Sets" );
            $str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
            if ( $page ne "" ) {
                my $folder = $cgi->param("folder");
                if ( $page eq "view" || $page eq "delete" ) {
                    my $tmp = WebUtil::alink( "main.cgi?section=WorkspaceFuncSet", $folder );
                    $str .= " &gt; $tmp ";
                }
                $str .= " &gt; $page ";
            }

        } elsif ( $section eq "WorkspaceGenomeSet" ) {

            # this should be MyING
            my $display = $breadcrumbs{$current};
            $display = WebUtil::alink( "main.cgi?section=MyIMG", $display );
            my $tmp          = WebUtil::alink( "main.cgi?section=Workspace",          "Workspace" );
            my $gene_set_url = WebUtil::alink( "main.cgi?section=WorkspaceGenomeSet", "Genome Sets" );
            $str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
            if ( $page ne "" ) {
                my $folder = $cgi->param("folder");
                if ( $page eq "view" || $page eq "delete" ) {
                    my $tmp = WebUtil::alink( "main.cgi?section=WorkspaceGenomeSet", $folder );
                    $str .= " &gt; $tmp ";
                }
                $str .= " &gt; $page ";
            }

        } elsif ( $section eq "WorkspaceScafSet" ) {

            # this should be MyING
            my $display = $breadcrumbs{$current};
            $display = WebUtil::alink( "main.cgi?section=MyIMG", $display );
            my $tmp          = WebUtil::alink( "main.cgi?section=Workspace",        "Workspace" );
            my $gene_set_url = WebUtil::alink( "main.cgi?section=WorkspaceScafSet", "Scaffold Sets" );
            $str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
            if ( $page ne "" ) {
                my $folder = $cgi->param("folder");
                if ( $page eq "view" || $page eq "delete" ) {
                    my $tmp = WebUtil::alink( "main.cgi?section=WorkspaceScafSet", $folder );
                    $str .= " &gt; $tmp ";
                }
                $str .= " &gt; $page ";
            }

        } elsif ( $section eq "WorkspaceRuleSet" ) {

            # this should be MyING
            my $display = $breadcrumbs{$current};
            $display = WebUtil::alink( "main.cgi?section=MyIMG", $display );
            my $tmp          = WebUtil::alink( "main.cgi?section=Workspace",        "Workspace" );
            my $rule_set_url = WebUtil::alink( "main.cgi?section=WorkspaceRuleSet", "Rule Sets" );
            $str .= " &gt; $display &gt; $tmp &gt; $rule_set_url ";
            if ( $page ne "" ) {
                my $folder = $cgi->param("folder");
                if ( $page eq "view" || $page eq "delete" ) {
                    my $tmp = WebUtil::alink( "main.cgi?section=WorkspaceRuleSet", $folder );
                    $str .= " &gt; $tmp ";
                }
                $str .= " &gt; $page ";
            }

        } elsif ( $section eq "Workspace" ) {

            # this should be MyING
            my $display = $breadcrumbs{$current};
            $display = WebUtil::alink( "main.cgi?section=MyIMG", $display );
            my $tmp = WebUtil::alink( "main.cgi?section=Workspace", "Workspace" );
            $str .= " &gt; $display &gt; $tmp ";
            if ( $page ne "" ) {
                my $folder = $cgi->param("folder");
                if ( $page eq "view" || $page eq "delete" ) {
                    my $tmp = WebUtil::alink( "main.cgi?section=Workspace&page=$folder", $folder );
                    $str .= " &gt; $tmp ";
                }
                $str .= " &gt; $page ";
            }

        } else {
            my $display = $breadcrumbs{$current};
            $str .= " &gt; $display";
        }
    }

    print qq{
	<div id="breadcrumbs_frame">
	<div id="breadcrumbs"> $str </div>
	<div id="loading">  <font color='red'> Loading... </font> <img src='$base_url/images/ajax-loader.gif'/> </div>
    };

    # when to print help icon
    print qq{
	<div id="page_help">
    };

    if ( $help ne "" ) {
        print qq{
	    <a href='$base_url/doc/$help' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'printBreadcrumbsDiv', '$help']);">
	    <img width="40" height="27" border="0" style="margin-left: 35px;" src="$base_url/images/help.gif"/>
	    </a>
        };
    } else {
        print qq{
	    &nbsp;
        };
    }

    print qq{
	</div>
	<div id="myclear"></div>
	</div>
    };
}

# error frame - test to see if js enabled
# if enabled you can use div's id "error_content" innerHtml to display an error message
# and
# error frame - hidden by default but to display set an in-line style:
#  style="display: block" to override the default css
# 4th div
sub printErrorDiv {
    my $section = $cgi->param('section');

    my $template = HTML::Template->new( filename => "$base_dir/error-message-tmpl.html" );
    $template->param( base_url => $base_url );

    if (   $section eq 'Artemis'
        || $section eq 'DistanceTree'
        || $section eq 'Vista'
        || $section eq 'ClustalW'
        || $section eq 'Kmer'
        || $section eq 'EgtCluster'
        || $section eq 'RNAStudies'
        || $section eq 'IMGProteins' ) {

        my $text = <<EOF;
<script src="https://www.java.com/js/deployJava.js"></script>
<script type="text/javascript">
var d=document.getElementById("error_content");if(navigator.javaEnabled()){var x=deployJava.versionCheck("1.6+");x||(d.style.display="block",d.innerHTML="Please <a href='http://java.com/'>update your Java.</a>")}else d.style.display="block",d.innerHTML="Please <a href='http://java.com/en/download/help/enable_browser.xml'>enable Java in your browser.</a>";
</script>
EOF
        $template->param( java_test => $text );
    } else {
        $template->param( java_test => '' );
    }

    print $template->output;

    my $str = WebUtil::webDataTest();

    # message from the web config file - ken
    if ( $MESSAGE ne "" || $str ne "" ) {
        print qq{
	    <div id="message_content" class="message_frame shadow" style="display: block" >
	    <img src='$base_url/images/announcementsIcon.gif'/>
	    $MESSAGE
	    $str
	    </div>
	};
    }
}

# home page stats table - left side
# 6th div for home page
#
sub printStatsTableDiv {
    my ( $maxAddDate, $maxErDate ) = @_;
    my ( $s, $hmp );
    require MainPageStats;
    ( $s, $hmp ) = MainPageStats::replaceStatTableRows();

    print qq{
	<div id="left" class="shadow">
    };

    if ( $hmp ne "" ) {

        print qq{
		<h2>HMP Genomes &amp;<br/> Samples </h2>
		<table cellspacing="0" cellpadding="0">
		<th align='left' valign='bottom'>Category</th>
		<th align='right' valign='bottom' style="padding-right: 5px;"
		title='Funded by HMP: Genomes sequenced as part of the NIH HMP Project'>
		Genome </th>
		<th align='right' valign='bottom'>Sample</th>
		$hmp
		</table>
		<br/>
	       };

    } elsif ($abc) {
        my $dbh = WebUtil::dbLogin();
        require BiosyntheticStats;
        my ( $totalCnt, %domain2cnt ) = BiosyntheticStats::getStatsByDomain($dbh);
        print qq{
<h2>Biosynthetic Clusters &amp;<br>Secondary Metabolites</h2>
    <table cellspacing="0" cellpadding="0">
        <th align='left' valign='bottom'>Domain</th>
        <th align='right' valign='bottom'>Biosynthetic Clusters</th>
            };

        foreach my $domain ( sort( keys %domain2cnt ) ) {
            my $cluster_cnt = $domain2cnt{$domain};
            my $url;
            if ( $cluster_cnt > 0 ) {
                $url = "main.cgi?section=BiosyntheticStats&page=byGenome&domain=$domain";
            }
            print "<tr>\n";
            my $domain_name = $domain;
            if ( $domain eq '*Microbiome' ) {
                $domain_name = "Metagenomes";
            }
            print "<td style='line-height: 1.25em; width: 90px;'>$domain_name</td>\n";
            print "<td style='line-height: 1.25em;' align='right'>" . WebUtil::alink( $url, $cluster_cnt ) . "</td>\n";
            print "</tr>\n";
        }

        print qq{
    </table>
            };

        require NaturalProd;
        my $href = NaturalProd::getNpPhylum($dbh);
        print qq{
    <table cellspacing="0" cellpadding="0">
        <th align='left' valign='bottom'>Phylum</th>
        <th align='right' valign='bottom'>Secondary Metabolites</th>
            };
        foreach my $name ( sort( keys %$href ) ) {
            my $cnt = $href->{$name};
            my $tmp = WebUtil::massageToUrl2($name);
            my $url = "main.cgi?section=NaturalProd&page=subCategory&stat_type=Phylum&stat_val=" . $tmp;
            print "<tr>\n";
            print "<td style='line-height: 1.25em; width: 90px;'>$name</td>\n";
            print "<td style='line-height: 1.25em;' align='right'>" . WebUtil::alink( $url, $cnt ) . "</td>\n";
            print "</tr>\n";
        }

        print qq{
    </table>
    <br>
            };
    }

    if ($img_hmp) {
        print qq{
        <h2>All Genomes &amp;</br> Samples</h2>
        <table cellspacing="0" cellpadding="0">
        <tr>
        <th align="right" colspan="2" > &nbsp; </th>
        <th align="right">Total</th>
        </tr>
       };
        print $s;
        print qq{
        </table>
        };
    } elsif ( !$abc ) {
        print qq{
         <h2>$imgAppTerm Content</h2>
         <table cellspacing="0" cellpadding="0">
         <tr>
             <th align="right" colspan="2" > &nbsp; </th>
             <th align="right">Datasets</th>
         </tr>
        };
        print $s;
        print qq{
        </table>
        };
    }

    # latest genomes added
    my $tmp;
    if ($img_er) {
        $tmp = qq{
           <span style="font-family: Arial; font-size: 12px; color: black;">
           &nbsp;&nbsp;&nbsp; Last updated: <a href='main.cgi?section=TaxonList&page=lastupdated'> $maxErDate </a> <br/>
           </span>
       };
    } elsif ( $include_metagenomes && ( $public_login || $user_restricted_site ) ) {
        $tmp = qq{
<table>
<tr>
    <td style="font-size:10px">
    Last Genome updated:
    </td>
    <td style="font-size:10px">
    <a href='main.cgi?section=TaxonList&page=lastupdated&erDate=true'>$maxErDate</a>
    </td>
</tr>
<tr>
    <td style="font-size:10px">
    Last Sample updated:
    </td>
    <td style="font-size:10px">
    <a href='main.cgi?section=TaxonList&page=lastupdated'>$maxAddDate</a>
    </td>
</tr>
</table>
       };
    } else {
        $tmp = qq{
           <span style="font-family: Arial; font-size: 12px; color: black;">
           &nbsp;&nbsp;&nbsp; Last updated: <a href='main.cgi?section=TaxonList&page=lastupdated'> $maxAddDate </a> <br/>
           </span>
       };
    }

    print qq{
 $tmp
	<div id="training" style="padding-top: 2px;">
    };

    print "<p>\n";
    if ( $use_img_gold && !$include_metagenomes ) {
        print qq{
        <a href="main.cgi?section=TaxonList&page=genomeCategories">Genome by Metadata</a> <br/>
        };
    }

    # google map link
    if ($include_metagenomes) {
        print qq{
        <a href="main.cgi?section=ImgStatsOverview&page=googlemap">Metagenome Projects Map</a><br/>
        };
    } elsif ($use_img_gold) {
        print qq{
        <a href="main.cgi?section=ImgStatsOverview&page=googlemap">Project Map</a><br/>
        };
    }

    print qq{
<a href="$base_url/doc/systemreqs.html">System Requirements</a>  <br/>
    };

    print qq{
<p style="width: 175px;">
        <img width="80" height="50"  style="float:left; padding-right: 5px;" src="$base_url/images/imguser.jpg"/>
            Hands on training available at the
            <p>
            <a href="http://www.jgi.doe.gov/meetings/mgm">Microbial Genomics &amp;
            Metagenomics Workshop</a>

    };

    if ( $homePage && !$img_hmp && !$img_edu && !$abc && !$img_proportal ) {

        # news section on the home for all data marts except hmp, edu and proportal
        print "</p>\n";
        printNewsDiv();
    }

    print "</div>\n";    # end of training

    print "</div>\n";    # <!-- end of left div -->
}

# home page content div
sub printContentHome {
    print qq{
	<div id="content">
    };
}

# other pages content div
sub printContentOther {
    print qq{
	<div id="content_other">
    };
}

# end content div
sub printContentEnd {
    print qq{
	</div> <!-- end of content div  -->
        <div id="myclear"></div>
	</div> <!-- end of container div  -->
    };
}

############################################################################
# printAppHeader - Show top menu and other web UI framework header code.
#
# $current - which menu to highlight
# $noMenu - no longer used
# $gwtModule - google text to replace $gwt in html header
# $yuijs - yahoo text to replace $yahoo_js in html header
# $content_js - misc. js to load in header replaced $content_js in html header
# $help - html link code for breadcrumb div
# $redirecturl - for old login page redirect url on failed login
#
# return number if save genomes if any. otherwise return "" blank
# - ken 2010-03-08
#
############################################################################
sub printAppHeader {
    my ( $current, $noMenu, $gwtModule, $yuijs, $content_js, $help, $redirecturl ) = @_;

    require HtmlUtil;

    # sso
    my $cookie_return;
    if ( $sso_enabled && $current eq "login" && $sso_url ne "" ) {
        my $url = $cgi_url . "/" . $main_cgi . redirectform(1);
        $url = $redirecturl if ( $redirecturl ne "" );
        $cookie_return = CGI::Cookie->new(
            -name   => $sso_cookie_name,
            -value  => $url,
            -domain => $sso_domain
        );
    } elsif ($sso_enabled) {
        my $url = $cgi_url . "/" . $main_cgi;
        $cookie_return = CGI::Cookie->new(
            -name   => $sso_cookie_name,
            -value  => $url,
            -domain => $sso_domain
        );
    }

    if ( $cookie_return ne "" ) {
        print header( -type => "text/html", -cookie => [ $cookie, $cookie_return ] );
    } else {
        print header( -type => "text/html", -cookie => $cookie );
    }

    return if ( $current eq "exit" );

    my $dbh = WebUtil::dbLogin();

    # genome cart
    my $numTaxons = printTaxonFilterStatus();    # if ( $current ne "Home" );
    $numTaxons = "" if ( $numTaxons == 0 );

    if ( $current eq "Home" && $abc ) {

        # caching home page
        my $sid  = WebUtil::getContactOid();
        my $time = 3600 * 24;                    # 24 hour cache

        printHTMLHead( $current, "JGI IMG Home", $gwtModule, "", "", $numTaxons );
        printMenuDiv( $current, $dbh );
        printErrorDiv();

        HtmlUtil::cgiCacheInitialize("homepage");
        HtmlUtil::cgiCacheStart() or return;

        my ( $maxAddDate, $maxErDate ) = getMaxAddDate($dbh);

        printAbcNavBar();
        printContentHome();

        require NaturalProd;
        my $bcp_cnt = NaturalProd::getPredictedBc($dbh);
        my $np_cnt  = NaturalProd::getSmStructures($dbh);
        $bcp_cnt = Number::Format::format_number($bcp_cnt);
        $np_cnt  = Number::Format::format_number($np_cnt);

        my $templateFile = "$base_dir/home-v33.html";
        my $template = HTML::Template->new( filename => $templateFile );
        $template->param( base_url     => $base_url );
        $template->param( bc_predicted => $bcp_cnt );
        $template->param( np_items     => $np_cnt );
        print $template->output;

        HtmlUtil::cgiCacheStop();

    } elsif ( $img_proportal && $current eq "Home" ) {
        printHTMLHead( $current, "JGI IMG Home", $gwtModule, "", "", $numTaxons );
        printMenuDiv( $current, $dbh );
        printErrorDiv();
        printContentHome();
        my $section = $cgi->param("section");
        if ( $section eq '' ) {

            # home page url
            my $class = $cgi->param("class");
            if ( !$class ) {
                $class = 'datamart';
            }
            my $new_url = $main_cgi . "?section=Home";
            HtmlUtil::cgiCacheInitialize( "homepage_" . $class );
            HtmlUtil::cgiCacheStart() or return;
            require ProPortal;
            ProPortal::googleMap_new( $class, $new_url );
            HtmlUtil::cgiCacheStop();
        }

    } elsif ( $current eq "Home" ) {

        # caching home page
        my $sid  = WebUtil::getContactOid();
        my $time = 3600 * 24;         # 24 hour cache

        printHTMLHead( $current, "JGI IMG Home", $gwtModule, "", "", $numTaxons );
        printMenuDiv( $current, $dbh );
        printErrorDiv();

        HtmlUtil::cgiCacheInitialize("homepage");
        HtmlUtil::cgiCacheStart() or return;

        my ( $maxAddDate, $maxErDate ) = getMaxAddDate($dbh);

        printStatsTableDiv( $maxAddDate, $maxErDate );
        printContentHome();
        my $templateFile = "$base_dir/home-v33.html";
        my $hmpGoogleJs;
        if ( $img_hmp && $include_metagenomes ) {
            $templateFile = "$base_dir/home-hmpm-v33.html";
            my $f = $env->{'hmp_home_page_file'};
            $hmpGoogleJs = WebUtil::file2Str( $f, 1 );
        }

        my ( $sampleCnt, $proposalCnt, $newSampleCnt, $newStudies );
        my $piechar_str;
        my $piechar2_str;
        my $table_str;
        if ($include_metagenomes) {

            # mer / m
            my $file = $webfs_data_dir . "/hmp/img_m_home_page_v400.txt";
            if ( $env->{home_page} ) {
                $file = $webfs_data_dir . "/hmp/" . $env->{home_page};
            }

            $table_str = WebUtil::file2Str( $file, 1 );
            $table_str =~ s/__IMG__/$imgAppTerm/;
        } elsif ($img_edu) {

            # edu
            my $file = $webfs_data_dir . "/hmp/img_edu_home_page_v400.txt";
            $table_str = WebUtil::file2Str( $file, 1 );
        } elsif ( !$user_restricted_site && !$include_metagenomes && !$img_hmp && !$img_edu ) {

            # w
            my $file = $webfs_data_dir . "/hmp/img_w_home_page_v400.txt";
            $table_str = WebUtil::file2Str( $file, 1 );
        }

        my $rfh = newReadFileHandle($templateFile);
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            if ( $s =~ /__table__/ ) {
                $s =~ s/__table__/$table_str/;
                print "$s\n";
            } elsif ( $s =~ /__news__/ ) {
                my $news = qq{
<p>
For details, see <a href='$base_url/doc/releaseNotes.pdf' onClick="_gaq.push(['_trackEvent', 'Document', 'main', 'release notes']);">IMG Release Notes</a> (Dec. 12, 2012),
in particular, the workspace and background computation capabilities  available to IMG registered users.
</p>
};

                #$s =~ s/__news__/$news/;
                $s =~ s/__news__//;
                print "$s\n";
            } elsif ( $img_hmp && $s =~ /__hmp_google_js__/ ) {
                $s =~ s/__hmp_google_js__/$hmpGoogleJs/;
                print "$s\n";
            } elsif ( $img_geba && $s =~ /__pie_chart_geba1__/ ) {
                $s =~ s/__pie_chart_geba1__/$piechar_str/;
                print "$s\n";
            } elsif ( $img_geba && $s =~ /__pie_chart_geba2__/ ) {
                $s =~ s/__pie_chart_geba2__/$piechar2_str/;
                print "$s\n";
            } elsif ( $include_metagenomes && $s =~ /__pie_chart__/ ) {
                $s =~ s/__pie_chart__/$piechar_str/;
                print "$s\n";
            } elsif ( $include_metagenomes && $s =~ /__samples__/ ) {
                $s =~ s/__samples__/$sampleCnt/;
                print "$s\n";
            } elsif ( $include_metagenomes && $s =~ /__proposal__/ ) {
                $s =~ s/__proposal__/$proposalCnt/;
                print "$s\n";
            } elsif ( $include_metagenomes && $s =~ /__newSample__/ ) {
                $s =~ s/__newSample__/$newSampleCnt/;
                print "$s\n";
            } elsif ( $include_metagenomes && $s =~ /__study__/ ) {
                $s =~ s/__study__/$newStudies/;
                print "$s\n";
            } elsif ( $s =~ /__base_url__/ ) {
                $s =~ s/__base_url__/$base_url/;
                print "$s\n";
            } elsif ( $s =~ /__max_add_date__/ ) {
                $s =~ s/__max_add_date__/$maxAddDate/;
                print "$s\n";
            } elsif ( $s =~ /__yui__/ ) {
                $s =~ s/__yui__/$YUI/;
                print "$s\n";

                # $imgAppTerm
            } elsif ( $s =~ /__IMG__/ ) {
                $s =~ s/__IMG__/$imgAppTerm/;
                print "$s\n";
            } else {
                print "$s\n";
            }
        }
        close $rfh;

        HtmlUtil::cgiCacheStop();
    } else {
        printHTMLHead( $current, $pageTitle, $gwtModule, $content_js, $yuijs, $numTaxons );
        printMenuDiv( $current, $dbh );
        printBreadcrumbsDiv( $current, $help, $dbh );
        printErrorDiv();

        printAbcNavBar() if $abc;
        printContentOther();

        #cookieTest();
    }

    return $numTaxons;
}

sub printNewsDiv {

    # read news  file
    my $file = '/webfs/scratch/img/news.html';
    if ( -e $file  ) {
        print qq{
            <span id='news2'>News</span>
            <div id='news'>
        };
        my $line;
        my $rfh = WebUtil::newReadFileHandle($file);
        my $i = 0;
        while (my $line = $rfh->getline()) {
            last if ($i > 3);
            if($line =~ /^<b id='subject'>/) {
                print $line;
                $i++;
            }
        }
        close $rfh;
        print qq{
            <a href='main.cgi?section=Help&page=news'>Read more...</a>
            </div>
        };
    }
}
=cut
sub cookieTest {

    # cookie test - ken 2013-12-23
    # lets see if I can read the cookie that I just wrote
    return if ($img_edu);

    if ( !$user_restricted_site && !$public_login ) {

    	my $session = WebUtil::getSession();

        # only test cookie for public sites
        my $cookie_test = cookie( -name => $cookie_name );
        if ( defined $cookie_test ) {

            # do nothing
            # cookie was set
            # print "===>$cookie_test<===  $cookie_name $cookie <br/>\n";
        } else {

            #print "===>$cookie_test<===  $cookie_name $cookie <br/>\n";
            WebUtil::clearSession();
            WebUtil::webError("Your browser is not accepting cookies. Please enabled cookies to view IMG.");
        }
    }
}
=cut
#
# gets genome's max add date
#
sub getMaxAddDate {
    my ($dbh) = @_;

    my $imgclause = WebUtil::imgClause('t');

    my $sql = qq{
	select to_char(max(t.add_date),'yyyy-mm-dd')
    from taxon t
    where 1 = 1
    $imgclause
    };

    my $cur = WebUtil::execSql( $dbh, $sql, $verbose );
    my ($max) = $cur->fetchrow();

    # this the acutal db ui release date not the genome add_date - ken
    my $maxErDate;
    my $sql2 = qq{
select to_char(release_date, 'yyyy-mm-dd') from img_build
        };
    $cur = WebUtil::execSql( $dbh, $sql2, $verbose );
    ($maxErDate) = $cur->fetchrow();

    return ( $max, $maxErDate );
}

# logout in header under quick search - ken
sub printLogout {

    # in the img.css set the z-index to show the logout link - ken
    if ( $public_login || $user_restricted_site ) {
        my $contact_oid = WebUtil::getContactOid();
        return if !$contact_oid;
        return if $cgi->param("logout");

        my $name = WebUtil::getUserName2();
        if ( $name eq '' ) {
            $name = WebUtil::getUserName();
        }

        my $tmp = "<br/> (JGI SSO)";
        if ($oldLogin) {
            $tmp = "";
        }

        print qq{
	    <div id="login">
            Hi $name &nbsp; | &nbsp; <a href="main.cgi?logout=1"> Logout </a>
            $tmp
	    </div>
        };
    }
}

############################################################################
# printMainFooter - Show main footer information.  Reads from footer
#   template file.
############################################################################
sub printMainFooter {
    my ( $homeVersion, $postJavascript ) = @_;

    my $remote_addr = $ENV{REMOTE_ADDR};

    # try to get true hostname
    # can't use back ticks with -T
    # - ken
    my $servername = $ENV{SERVER_NAME};

    my $hostname = WebUtil::getHostname();

    $servername = $hostname . ' ' . $ENV{ORA_SERVICE} . ' ' . $];

    my $copyright_year = $env->{copyright_year};
    my $version_year   = $env->{version_year};
    my $img            = $cgi->param("img");

    # no exit read
    my $buildDate    = WebUtil::file2Str( "$base_dir/buildDate", 1 );
    my $templateFile = "$base_dir/footer-v33.html";

    #$templateFile = "$base_dir/footer-v33.html" if ($homeVersion);
    my $s = WebUtil::file2Str( $templateFile, 1 );
    $s =~ s/__main_cgi__/$main_cgi/g;
    $s =~ s/__base_url__/$base_url/g;
    $s =~ s/__copyright_year__/$copyright_year/;
    $s =~ s/__version_year__/$version_year/;
    $s =~ s/__server_name__/$servername/;
    $s =~ s/__build_date__/$buildDate $remote_addr/;
    $s =~ s/__google_analytics__//;
    $s =~ s/__post_javascript__/$postJavascript/;
    $s =~ s/__top_base_url__/$top_base_url/g;
    print "$s\n";
}

sub googleAnalyticsJavaScript {
    my ( $server, $google_key ) = @_;

    my $str = WebUtil::file2Str( "$base_dir/google.js", 1 );
    $str =~ s/__google_key__/$google_key/g;
    $str =~ s/__server__/$server/g;

    return $str;
}

# newer version using async
sub googleAnalyticsJavaScript2 {
    my ( $server, $google_key ) = @_;

    my $str = WebUtil::file2Str( "$base_dir/google2.js", 1 );
    $str =~ s/__google_key__/$google_key/g;
    $str =~ s/__server__/$server/g;

    return $str;
}

############################################################################
# printTaxonFilterStatus - Show current selected number of genomes.
#  WARNING: very convoluted code.
############################################################################

sub printTaxonFilterStatus {

    require GenomeCart;
	my $taxon_oids = GenomeCart::getAllGenomeOids();
	return scalar @$taxon_oids || 0;

#    if ( $taxon_oids ne '' ) {
#        my $size = $#$taxon_oids + 1;
#        return $size;
#    }
#    return 0;
}

############################################################################
#	coerce_section
#
#	set the 'section' param when the submit button naming convention is used
############################################################################

sub coerce_section {

	# From submit button naming convention
	#  section_<sectionName>_<action>, not URL link.
	my $p = WebUtil::paramMatch("^_section");
	if ( $p ) {
		my @arr = split /_/, $p;
		## Force setting.
		$cgi->param("section", $arr[2]);
	}
}

sub redirectform {
    my ($noprint) = @_;

    # get url redirect param
    my @names = $cgi->param();

    my $url;
    my $count = 0;
    for ( my $i = 0 ; $i <= $#names ; $i++ ) {

        # username  password
        next if ( $names[$i] eq "username" );
        next if ( $names[$i] eq "password" );
        next if ( $names[$i] eq "userRestrictedLogin" );
        next if ( $names[$i] eq "oldLogin" );
        next if ( $names[$i] eq "logout" );
        next if ( $names[$i] eq "login" );
        next if ( $names[$i] eq "jgi_sso" );

        #next if ( $names[$i] eq "forceimg" );
        my $value = $cgi->param( $names[$i] );

        if ( $names[$i] eq "redirect" ) {

            # case when user login fails and logins in again
            $url = $url . $value;
        } elsif ( $count == 0 ) {
            $url = $url . "?" . $names[$i] . "=" . $value;
        } else {
            $url = $url . "&" . $names[$i] . "=" . $value;
        }
        $count++;
    }

    if ( !$noprint ) {
        print qq{
      <input type="hidden" name='redirect' value='$url' />
    };
    }

    return $url;
}

#
# redirect url - for login systems
# when users need to login before viewing a link
#
sub redirecturl {
    my ($url) = @_;

    printAppHeader("Home");
    print qq{
            <script language='JavaScript' type="text/javascript">
             window.open("main.cgi$url", "_self");
             </script>
    };
}

############################################################################
# getRequestAcctAttr
############################################################################
sub getRequestAcctAttr {
    my @attrs = (
        "name\tYour Name\tchar\t80\tY",                "title\tTitle\tchar\t80\tN",
        "department\tDepartment\tchar\t255\tN",        "email\tYour Email\tchar\t255\tY",
        "phone\tPhone Number\tchar\t80\tN",            "organization\tOrganization\tchar\t255\tY",
        "address\tAddress\tchar\t255\tN",              "city\tCity\tchar\t80\tY",
        "state\tState\tchar\t80\tN",                   "country\tCountry\tchar\t80\tY",
        "username\tPreferred Login Name\tchar\t20\tY", "group_name\tGroup (if known)\tchar\t80\tN",
        "comments\tReason(s) for Request\ttext\t60\tY"
    );

    return @attrs;
}

# touch user's cart files if any
# why?
# because user cart file can be over 90 mins old
# but the user is still using img
# after the 90 mins the user's charts are purged.
# -ken
sub touchCartFiles {
    require GeneCartStor;
    my $c    = new GeneCartStor();
    my $file = $c->getStateFile();
	WebUtil::fileTouch($file) if -e $file;

    require FuncCartStor;
    $c    = new FuncCartStor();
    $file = $c->getStateFile();
    WebUtil::fileTouch($file) if -e $file;

    if ($user_restricted_site) {
        require CuraCartStor;
        $c    = new CuraCartStor();
        $file = $c->getStateFile();
        WebUtil::fileTouch($file) if -e $file;
    }

    require ScaffoldCart;
    $file = ScaffoldCart::getStateFile();
    WebUtil::fileTouch($file) if -e $file;

    require GenomeCart;
    $file = GenomeCart::getStateFile();
    WebUtil::fileTouch($file) if -e $file;
    $file = GenomeCart::getColIdFile();
    WebUtil::fileTouch($file) if -e $file;

    # touch cart directory s.t. it does not get purge
    my ( $cartDir, $sessionId ) = WebUtil::getCartDir();
    WebUtil::fileTouch($cartDir);
}

#
# print the ABC nav bar / menu on the left side
#
sub printAbcNavBar {
    if ($abc) {
        my $templateFile = "$base_dir/abc-nav-bar.html";
        my $template = HTML::Template->new( filename => $templateFile );
        print $template->output;
    }
}
