package OldDispatch;

use strict;
use warnings;

#   All CGI called run this section and dispatch is made to relevant
#   for displaying appropriate CGI pages.
#      --es 09/19/2004
#
# $Id: main.pl 33935 2015-08-07 18:26:22Z klchu $
##########################################################################
use strict;
use warnings;
use feature ':5.16';
# use Carp::Always;

use CGI qw( :standard  );
#use CGI::Cookie;
#use CGI::Session qw/-ip-match/;    # for security - ken
#use CGI::Carp qw( carpout set_message fatalsToBrowser );
#use perl5lib;
#use HTML::Template;
#use File::Path qw(remove_tree);
#use Number::Format;
#use WebConfig;
#use WebUtil qw();
#use Template;
use Module::Load;


sub run_dispatch {

	my $args = shift;
	my $env = $args->{env};
	my $homePage = $args->{homePage};
	my $oldLogin = $args->{oldLogin};
	my $pageTitle = $args->{pageTitle};
	my $sso_enabled = $args->{sso_enabled};
	my $taxon_filter_oid_str = $args->{taxon_filter_oid_str};
	my $YUI = $args->{YUI};


#	my $cgi = shift;
#	my $session = shift;
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

	$default_timeout_mins = 5 if $default_timeout_mins eq "";

	############################################################
	# main viewer dispatch
	############################################################
	if ( param() ) {




		my $page = param('page');
		my $section = param('section');

		# TODO - for generic section loading new a section checker to ensure no one
		# tries to enter a bad section name :) - ken
		my %validSections = (
			WorkspaceBcSet => 'WorkspaceBcSet',
			AbundanceProfileSearch => 'AbundanceProfileSearch',
			GenomeList => 'GenomeList',
			ImgStatsOverview => 'ImgStatsOverview',
		);

		if ( param("setTaxonFilter") ne "" && !blankStr($taxon_filter_oid_str) ) {
			# this must before  the "} elsif (exists $validSections{ $section}) { "
			# s.t. the genome cart is display after the usr presses add to genome cart
			#
			# add to genome cart - ken
			require GenomeList;
			GenomeList::clearCache();

			require GenomeCart;
			$pageTitle = "Genome Cart";
			setSessionParam( "lastCart", "genomeCart" );
			printAppHeader("AnaCart");
			GenomeCart::dispatch();

		} elsif (exists $validSections{ $section}) {

			# TODO a better section loader  - ken
			$section = $validSections{$section}; # we need to untaint the $section..so get it from valid hash
			load $section;
			$pageTitle = $section->getPageTitle();
			my @appArgs = $section->getAppHeaderData();
			my $numTaxons = printAppHeader(@appArgs) if $#appArgs > -1;
			$section->dispatch($numTaxons);

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

			my $page = param('page');
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
			timeout( 60 * 20 );    # timeout in 20 minutes
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
			timeout( 60 * 20 );    # timeout in 20 minutes
			require AbundanceTest;
			$pageTitle = "Abundance Test";
			printAppHeader("CompareGenomes")
			  if param("noHeader") eq "";
			AbundanceTest::dispatch();
		} elsif ( $section eq "AbundanceComparisons" ) {
			timeout( 60 * 20 );    # timeout in 20 minutes
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
				  if param("noHeader") eq "";
			} else {
				$numTaxon = printAppHeader( "CompareGenomes", '', '', $js ) if param("noHeader") eq "";
			}
			AbundanceComparisons::dispatch($numTaxon);
		} elsif ( $section eq "AbundanceComparisonsSub" ) {
			timeout( 60 * 20 );    # timeout in 20 minutes
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
				  if param("noHeader") eq "";
			} else {
				$numTaxon = printAppHeader( "CompareGenomes", '', '', $js )
				  if param("noHeader") eq "";
			}
			AbundanceComparisonsSub::dispatch($numTaxon);
		} elsif ( $section eq "AbundanceToolkit" ) {
			timeout( 60 * 20 );    # timeout in 20 minutes
			require AbundanceToolkit;
			$pageTitle = "Abundance Toolkit";
			printAppHeader("CompareGenomes")
			  if param("noHeader") eq "";
			AbundanceToolkit::dispatch();
		} elsif ( $section eq "Artemis" ) {
			timeout( 60 * 20 );    # timeout in 20 minutes
			require Artemis;
			$pageTitle = "Artemis";

			require GenomeListJSON;
			my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
			$template->param( base_url => $base_url );
			$template->param( YUI      => $YUI );
			my $js = $template->output;

			my $from = param("from");
			my $numTaxon;
			if ( $from eq "ACT" || $page =~ /^ACT/ || $page =~ /ACT$/ ) {
				$numTaxon = printAppHeader( "CompareGenomes", '', '', $js );
			} else {
				$numTaxon = printAppHeader( "FindGenomes", '', '', $js )
				  if param("noHeader") eq "";
			}
			Artemis::dispatch($numTaxon);
		} elsif ( $section eq "ClustalW" ) {
			timeout( 60 * 40 );    # timeout in 40 minutes
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
			if ( paramMatch("_excel") ) {
				printExcelHeader("stats_export$$.xls");
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

			if ( paramMatch("_excel") ) {
				printExcelHeader("stats_export$$.xls");
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
			setSessionParam( "lastCart", "curaCart" );
			printAppHeader("AnaCart")
			  if !paramMatch("noHeader");
			CuraCartStor::dispatch();
		} elsif ( $section eq "CuraCartDataEntry" ) {
			require CuraCartDataEntry;
			$pageTitle = "Curation Cart Data Entry";
			setSessionParam( "lastCart", "curaCart" );
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
			timeout( 60 * 30 );    # timeout in 30 minutes
			require EgtCluster;
			$pageTitle = "Genome Clustering";
			require GenomeListJSON;
			my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
			$template->param( base_url => $base_url );
			$template->param( YUI      => $YUI );
			my $js = $template->output;

			my $numTaxon;
			if ( param("method") eq "hier" ) {
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
				|| ( $page ne 'geneSearchForm' && paramMatch("fgFindGenes") eq '' ) )
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
			if ( paramMatch("AssertionProfile") ne "" ) {
				$pageTitle = "Assertion Profile";
			}
			setSessionParam( "lastCart", "funcCart" );

			#if ( $page eq 'funcCart' || paramMatch("addFunctionCart") ne "" || paramMatch('addToFuncCart') ne "") {
			if ( $page eq 'funcCart' || !paramMatch("noHeader") ) {
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
			#    printAppHeader("AnaCart") if !paramMatch("noHeader");
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
			timeout( 60 * 40 );    # timeout in 40 minutes
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
			timeout( 60 * 20 );    # timeout in 20 minutes
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
			timeout( 60 * 20 );    # timeout in 20 minutes
			require RadialPhyloTree;
			$pageTitle = "Radial Phylogenetic Tree";
			require GenomeListJSON;
			my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
			$template->param( base_url => $base_url );
			$template->param( YUI      => $YUI );
			my $js = $template->output;
			my $numTaxon = printAppHeader( "CompareGenomes", '', '', $js )
			  if !paramMatch("export");
			RadialPhyloTree::dispatch($numTaxon);
		} elsif ( $section eq "Kmer" ) {
			timeout( 60 * 20 );    # timeout in 20 minutes
			require Kmer;
			$pageTitle = "Kmer Frequency Analysis";
			printAppHeader("FindGenomes")
			  if !paramMatch("export");
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
			timeout( 60 * 60 );    # timeout in 20 minutes
			require GeneInfoPager;
			$pageTitle = "Download Gene Information";
			printAppHeader("FindGenomes");
			GeneInfoPager::dispatch();
		} elsif ( $section eq "GeneCartChrViewer" ) {
			require GeneCartChrViewer;
			$pageTitle = "Circular Chromosome Viewer";
			setSessionParam( "lastCart", "geneCart" );
			printAppHeader("AnaCart");
			GeneCartChrViewer::dispatch();
		} elsif ( $section eq "GeneCartDataEntry" ) {
			require GeneCartDataEntry;
			$pageTitle = "Gene Cart Data Entry";
			setSessionParam( "lastCart", "geneCart" );
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
			if ( paramMatch("addFunctionCart") ne "" ) {
				setSessionParam( "lastCart", "funcCart" );
			} else {
				setSessionParam( "lastCart", "geneCart" );
			}
			if ( $page eq 'geneCart' || !paramMatch("noHeader") ) {
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
			timeout( 60 * 20 );    # timeout in 20 minutes
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
			timeout( 60 * 20 );    # timeout in 20 minutes
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
			timeout( 60 * 20 );    # timeout in 20 minutes
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
			if ( paramMatch("_excel") ) {
				printExcelHeader("genome_export$$.xls");
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
			timeout( 60 * 20 );    # timeout in 20 minutes
			require GeneCassetteProfiler;
			$pageTitle = "Phylogenetic Profiler";

			require GenomeListJSON;
			my $template = HTML::Template->new( filename => "$base_dir/genomeHeaderJson.html" );
			$template->param( base_url => $base_url );
			$template->param( YUI      => $YUI );
			my $js = $template->output;
			my $numTaxon = printAppHeader( "FindGenes", '', '', $js );
			GeneCassetteProfiler::dispatch($numTaxon);
	#    } elsif ( $section eq "ImgStatsOverview" ) {
	#        require ImgStatsOverview;
	#        if ( param('excel') eq 'yes' ) {
	#            printExcelHeader("stats_export$$.xls");
	#            ImgStatsOverview::dispatch();
	#        } else {
	#            $pageTitle = "IMG Stats Overview";
	#            printAppHeader("ImgStatsOverview");
	#            ImgStatsOverview::dispatch();
	#        }
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
			setSessionParam( "lastCart", "geneCart" );
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
			setSessionParam( "lastCart", "imgCpdCart" );
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
			setSessionParam( "lastCart", "imgPartsListCart" );
			printAppHeader("AnaCart");
			ImgPartsListCartStor::dispatch();
		} elsif ( $section eq "ImgPartsListDataEntry" ) {
			require ImgPartsListDataEntry;
			$pageTitle = "IMG Parts List Data Entry";
			setSessionParam( "lastCart", "imgPartsListCart" );
			printAppHeader("AnaCart");
			ImgPartsListDataEntry::dispatch();
		} elsif ( $section eq "ImgPwayCartDataEntry" ) {
			require ImgPwayCartDataEntry;
			$pageTitle = "IMG Pathway Cart Data Entry";
			setSessionParam( "lastCart", "imgPwayCart" );
			printAppHeader("AnaCart");
			ImgPwayCartDataEntry::dispatch();
		} elsif ( $section eq "ImgPwayCartStor" ) {
			require ImgPwayCartStor;
			$pageTitle = "IMG Pathway Cart";
			setSessionParam( "lastCart", "imgPwayCart" );
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
			setSessionParam( "lastCart", "imgRxnCart" );
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
			setSessionParam( "lastCart", "imgTermCart" );
			printAppHeader("AnaCart");
			ImgTermCartDataEntry::dispatch();
		} elsif ( $section eq "ImgTermCartStor" ) {
			require ImgTermCartStor;
			$pageTitle = "IMG Term Cart";
			setSessionParam( "lastCart", "imgTermCart" );
			printAppHeader("AnaCart");
			ImgTermCartStor::dispatch();
		} elsif ( $section eq "KeggMap" ) {
			timeout( 60 * 20 );    # timeout in 20 minutes
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
			timeout( 60 * 20 );    # timeout in 20 minutes
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
			timeout( 60 * 20 );    # timeout in 20 minutes
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

			# for download add if paramMatch( "noHeader" ) eq "";
			printAppHeader("AnaCart")
			  if paramMatch("noHeader") eq "";
			ScaffoldHits::dispatch();
		} elsif ( $section eq "ScaffoldCart" ) {
			require ScaffoldCart;
			$pageTitle = "Scaffold Cart";
			if (   paramMatch("exportScaffoldCart") ne ""
				|| paramMatch("exportFasta") ne "" )
			{

				# export excel
				setSessionParam( "lastCart", "scaffoldCart" );
			} elsif ( paramMatch("addSelectedToGeneCart") ne "" ) {
			} else {
				setSessionParam( "lastCart", "scaffoldCart" );
				printAppHeader("AnaCart");
			}
			ScaffoldCart::dispatch();
		} elsif ( $section eq "GenomeCart" ) {
			require GenomeCart;
			$pageTitle = "Genome Cart";
			setSessionParam( "lastCart", "genomeCart" );
			printAppHeader("AnaCart")
			  if paramMatch("noHeader") eq "";
			GenomeCart::dispatch();
	#    } elsif ( param("setTaxonFilter") ne "" && !blankStr($taxon_filter_oid_str) ) {
	#
	#        # add to genome cart - ken
	#        require GenomeList;
	#        GenomeList::clearCache();
	#
	#        require GenomeCart;
	#        $pageTitle = "Genome Cart";
	#        setSessionParam( "lastCart", "genomeCart" );
	#        printAppHeader("AnaCart");
	#        GenomeCart::dispatch();
		} elsif ( $section eq "MetagenomeHits" ) {
			require MetagenomeHits;
			$pageTitle = "Genome Hits";

			# for download add if paramMatch( "noHeader" ) eq "";
			printAppHeader("FindGenomes") if paramMatch("noHeader") eq "";
			MetagenomeHits::dispatch();
		} elsif ( $section eq "MetaFileHits" ) {
			require MetaFileHits;
			$pageTitle = "Metagenome Hits";

			# for download add if paramMatch( "noHeader" ) eq "";
			printAppHeader("FindGenomes") if ( param('noHeader') eq '' && paramMatch("noHeader") eq "" );
			MetaFileHits::dispatch();
		} elsif ( $section eq "MetagenomeGraph" ) {
			timeout( 60 * 40 );
			require MetagenomeGraph;
			$pageTitle = "Genome Graph";

			# for download add if paramMatch( "noHeader" ) eq "";
			printAppHeader("FindGenomes")
			  if paramMatch("noHeader") eq "";
			MetagenomeGraph::dispatch();
		} elsif ( $section eq "MetaFileGraph" ) {
			require MetaFileGraph;
			$pageTitle = "Metagenome Graph";

			# for download add if paramMatch( "noHeader" ) eq "";
			printAppHeader("FindGenomes")
			  if paramMatch("noHeader") eq "";
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
				printAppHeader( "MyIMG", '', '', '', '', 'MyIMG4.pdf' ) if paramMatch("noHeader") eq "";
			}
			MyIMG::dispatch();
		} elsif ( $section eq "ImgGroup" ) {
			require ImgGroup;
			$pageTitle = "MyIMG";
			printAppHeader("MyIMG") if paramMatch("noHeader") eq "";
			ImgGroup::dispatch();
		} elsif ( $section eq "Workspace" ) {
			require Workspace;
			my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
			$pageTitle = "Workspace";
			my $header = param("header");
			if ( paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
													   # no header
			} elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
				printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
			}
			Workspace::dispatch();
		} elsif ( $section eq "WorkspaceGeneSet" ) {
			require WorkspaceGeneSet;
			my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
			$pageTitle = "Workspace Gene Sets";
			my $header = param("header");
			if ( paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
													   # no header
			} elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
				printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
			}
			WorkspaceGeneSet::dispatch();
		} elsif ( $section eq "WorkspaceFuncSet" ) {
			require WorkspaceFuncSet;
			my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
			$pageTitle = "Workspace Function Sets";
			my $header = param("header");
			if ( paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
													   # no header
			} elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
				printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
			}
			WorkspaceFuncSet::dispatch();
		} elsif ( $section eq "WorkspaceGenomeSet" ) {
			require WorkspaceGenomeSet;
			my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
			$pageTitle = "Workspace Genome Sets";
			my $header = param("header");
			if ( paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
													   # no header
			} elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
				printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
			}
			WorkspaceGenomeSet::dispatch();
		} elsif ( $section eq "WorkspaceScafSet" ) {
			require WorkspaceScafSet;
			my $ws_yui_js = Workspace::getStyles();    # Workspace related YUI JS and styles
			$pageTitle = "Workspace Scaffold Sets";
			my $header = param("header");
			if ( paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
													   # no header
			} elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
				printAppHeader( "MyIMG", "", "", $ws_yui_js, '', 'IMGWorkspaceUserGuide.pdf' );
			}
			WorkspaceScafSet::dispatch();
		} elsif ( $section eq "WorkspaceRuleSet" ) {
			require WorkspaceRuleSet;
			$pageTitle = "Workspace";
			my $header = param("header");
			if ( paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
													   # no header
			} elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
				printAppHeader("MyIMG", '', '', '', '', 'IMGWorkspaceUserGuide.pdf' );
			}
			WorkspaceRuleSet::dispatch();
		} elsif ( $section eq "WorkspaceJob" ) {
			require WorkspaceJob;
			$pageTitle = "Workspace";
			my $header = param("header");
			if ( paramMatch("wpload") ) {              ##use 'wpload' since param 'uploadFile' interferes 'load'
													   # no header
			} elsif ( $header eq "" && paramMatch("noHeader") eq "" ) {
				printAppHeader("MyIMG", '', '', '', '', 'IMGWorkspaceUserGuide.pdf' );
			}
			WorkspaceJob::dispatch();

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

		} elsif ( $section eq "TaxonDetail" || $page eq "taxonDetail" ) {
			require TaxonDetail;
			$pageTitle = "Taxon Details";
			if ( $page eq 'taxonArtemisForm' ) {
				printAppHeader( "FindGenomes", '', '', '', '', 'GenerateGenBankFile.pdf' );
			} else {
				printAppHeader("FindGenomes") if paramMatch("noHeader") eq "";
			}
			TaxonDetail::dispatch();
		} elsif ( $section eq "TaxonDeleted" ) {
			require TaxonDeleted;
			$pageTitle = "Taxon Deleted";
			printAppHeader("FindGenomes");
			TaxonDeleted::dispatch();
		} elsif ( paramMatch("taxon_oid") && scalar( param() ) < 2 ) {

			# if only taxon_oid is specified assume taxon detail page
			setSessionParam( "section", "TaxonDetail" );
			setSessionParam( "page",    "taxonDetail" );
			require TaxonDetail;
			$pageTitle = "Taxon Details";
			if ( $page eq 'taxonArtemisForm' ) {
				printAppHeader( "FindGenomes", '', '', '', '', 'GenerateGenBankFile.pdf' );
			} else {
				printAppHeader("FindGenomes") if paramMatch("noHeader") eq "";
			}
			TaxonDetail::dispatch();
		} elsif ( $section eq "MetaDetail" || $page eq "metaDetail" ) {
			require MetaDetail;
			$pageTitle = "Microbiome Details";
			if ( $page eq 'taxonArtemisForm' ) {
				printAppHeader( "FindGenomes", '', '', '', '', 'GenerateGenBankFile.pdf' );
			} else {
				printAppHeader("FindGenomes");    # if paramMatch("noHeader") eq "";
			}
			MetaDetail::dispatch();
		} elsif ( $section eq "TaxonList" ) {
			require TaxonList;
			$pageTitle = "Taxon Browser";
			if ( $page eq 'categoryBrowser' ) {
				$pageTitle = "Category Browser";
			}
			if ( paramMatch("_excel") ) {
				printExcelHeader("genome_export$$.xls");
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
			my $page = param("page");
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
			timeout( 60 * 20 );    # timeout in 20 minutes
			require RNAStudies;
			$pageTitle = "RNASeq Expression Studies";
			if ( paramMatch("samplePathways") ne "" ) {
				$pageTitle = "RNASeq Studies: Pathways";
			} elsif ( paramMatch("describeSamples") ne "" ) {
				$pageTitle = "RNASeq Studies: Describe";
			}
			printAppHeader( "RNAStudies", '', '', '', '', "RNAStudies.pdf" )
			  if param("noHeader") eq "";
			RNAStudies::dispatch();
		} elsif ( $page eq "znormNote" ) {
			## Non-section related dispatch
			$pageTitle = "Z-normalization";
			printAppHeader("FindGenes");
			printZnormNote();
		} elsif ( param("setTaxonFilter") ne "" && blankStr($taxon_filter_oid_str) ) {
			$pageTitle = "Genome Selection Message";
			printAppHeader("FindGenomes");
			printMessage( "Saving 'no selections' is the same as selecting " . "all genomes. Genome filtering is disabled.\n" );

		} elsif ( param("exportGenes") ne "" && param("exportType") eq "excel" ) {
			my @gene_oid = param("gene_oid");
			if ( scalar(@gene_oid) == 0 ) {
				printAppHeader();
				webError("You must select at least one gene to export.");
			}
			printExcelHeader("gene_export$$.xls");

			# --es 03/17/08 Use larger version with more columns.
			#printGenesToExcel( \@gene_oid );
			require GeneCartStor;
			GeneCartStor::printGenesToExcelLarge( \@gene_oid );
			WebUtil::webExit(0);
		} elsif ( param("exportGenes") ne ""
			&& param("exportType") eq "nucleic" )
		{
			require GenerateArtemisFile;
			$pageTitle = "Gene Export";
			printAppHeader("");
			GenerateArtemisFile::prepareProcessGeneFastaFile();
		} elsif ( param("exportGenes") ne "" && param("exportType") eq "amino" ) {
			require GenerateArtemisFile;
			$pageTitle = "Gene Export";
			printAppHeader("");
			GenerateArtemisFile::prepareProcessGeneFastaFile(1);
		} elsif ( param("exportGenes") ne "" && param("exportType") eq "tab" ) {
			$pageTitle = "Gene Export";
			printAppHeader("");
			print "<h1>Gene Export</h1>\n";
			my @gene_oid = param("gene_oid");
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
		} elsif ( ( $public_login || $user_restricted_site ) && param("logout") ne "" ) {

			#        if ( !$oldLogin && $sso_enabled ) {
			#
			#            # do no login log here
			#        } else {
			#            WebUtil::loginLog( 'logout main.pl', 'img' );
			#        }

			setSessionParam( "blank_taxon_filter_oid_str", "1" );
			setSessionParam( "oldLogin",                   0 );
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

				#            setSessionParam( "contact_oid", "" );
				#            my $session = WebUtil::getSession();
				#            $session->delete();
				#            $session->flush();    # Recommended practice says use flush() after delete().
			}
		} elsif ( $page eq "message" ) {
			$pageTitle = "Message";
			my $message       = param("message");
			my $menuSelection = param("menuSelection");
			printAppHeader($menuSelection);
			print "<div id='message'>\n";
			print "<p>\n";
			print escapeHTML($message);
			print "</p>\n";
			print "</div>\n";
		} elsif ( $section eq "Questions" || $page eq "questions" ) {
			$pageTitle = "Questions / Comments";
			printAppHeader("about") if param("noHeader") eq "";
			require Questions;
			Questions::dispatch();
			if ( param("noHeader") eq "true" ) {

				# form redirect submit to jira - ken
				WebUtil::webExit(0);
			}
		} elsif ( paramMatch("uploadTaxonSelections") ne "" ) {
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
			my $rurl = param("redirect");

			# redirect on login
			if ( ( $public_login || $user_restricted_site ) && $rurl ne "" ) {
				redirecturl($rurl);
			} else {
				$homePage = 1;
				printAppHeader("Home");
			}
		}
	} else {
		my $rurl = param("redirect");
		if ( ( $public_login || $user_restricted_site ) && $rurl ne "" ) {
			redirecturl($rurl);
		} else {
			$homePage = 1;
			printAppHeader("Home");
		}
	}
}

sub printAppHeader {

	my @args = @_;




}

sub paramMatch {

	my $self = shift;
	my $p = shift;

	carp "running paramMatch: p: $p";

	for my $k (keys %{$self->cgi_params}) {
		return $k if $k =~ /$p/;
	}
	return undef;

}




1;
