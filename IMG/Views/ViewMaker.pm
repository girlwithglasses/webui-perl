package IMG::Views::ViewMaker;

use IMG::Util::Base;

use Template;
use HTML::Template;

my $env;
my $imgAppTerm;
my $cgi;

sub init {
	my %args = @_;
	$env = $args{env};
	$imgAppTerm = $args{imgAppTerm};
	$cgi = $args{cgi};

}

=pod

=encoding UTF-8

=head1 NAME

IMG::Views::ViewMaker

=head2 SYNOPSIS

	use strict;
	use warnings;
	use IMG::Views::ViewMaker;

=cut

sub render_template {

	my $tmpl_name = shift || die "No template name specified!";
	my $data = shift // {};

	my $tt = Template->new({
		INCLUDE_PATH =>  [
			$env->{base_dir} . "/views",
			$env->{base_dir} . "/views/pages",
			$env->{base_dir} . "/views/layouts",
			$env->{base_dir} . "/views/inc"
		],
	}) || die "Template error: $Template::ERROR\n";

	$data->{env} = $env;
	$tt->process($tmpl_name, $data) || die $tt->error() . "\n";

}

=head3 printAppHeader

Convert printAppHeader positional params to hash args

Provides support for legacy use

=cut

sub printAppHeader {
#	my (
#		$current, $noMenu, $gwtModule, $yuijs, $content_js, $help, $redirecturl
#	) = @_;

	my @input = @_;
	my @params = qw( current no_menu gwt_module yui_js content_js help redirect_url );
	my %args;


	for ( my $p = 0; $p < scalar @input; $p++ ) {
		$args{ $params[$p] } = $input[$p] if $input[$p];
	}

	return print_app_header( %args );

}


sub genomeHeaderJson {

	my $template = HTML::Template->new( filename => $env->{base_dir} . "/genomeHeaderJson.html" );
	$template->param( base_url => $env->{base_url} );
	$template->param( YUI      => $env->{yui_dir_28} );
	return $template->output;
}

sub meshTreeHeader {

	my $template = HTML::Template->new( filename => $env->{base_dir} . "/meshTreeHeader.html" );
	$template->param( base_url => $env->{base_url} );
	$template->param( YUI      => $env->{yui_dir_28} );
	return $template->output;

}

sub genome_header_json {



}

sub mesh_tree_header {



}

=cut
my $imgAppTerm = "IMG";
$imgAppTerm = "IMG/ER"  if $env->{img_er};
$imgAppTerm = "IMG"     if $env->{include_metagenomes};
$imgAppTerm = "IMG/ER"  if $env->{include_metagenomes} && $env->{user_restricted_site};
$imgAppTerm = "IMG/ABC" if $env->{abc};

# key the AppHeader where $current used
# value display
my %breadcrumbs = (
    login            => "Login",
    logout           => "Logout",
    Home             => "Home",
    about            => "Using $imgAppTerm",
    AnaCart          => "Analysis Cart",
    CompareGenomes   => "Compare Genomes",
    FindFunctions    => "Find Functions",
    FindGenes        => "Find Genes",
    FindGenomes      => "Find Genomes",
    IMGContent       => "IMG Content",
    ImgStatsOverview => "IMG Stats Overview",
    Methylomics      => "Methylomics Experiments",
    MyIMG            => "My $imgAppTerm",
    Proteomics       => "Protein Expression Studies",
    RNAStudies       => "RNASeq Studies",
);
=cut

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

=head3 print_app_header

@param %args - hash with keys:

	current 	- current menu
	gwt_module	-
	yui_js
	content_js
	help
	redirect_url
	cookie

sub print_app_header {
	my $env = shift;
	my %args = @_;

	require HtmlUtil;

	# sso
	my $cookie_return;
	if ( $env->{sso_enabled} && $args{current} eq "login" && $env->{sso_url} ne "" )
	{
		my $url = $args{redirecturl} || $env->{cgi_url} . "/" . $env->{main_cgi} . redirectform(1);
#		$url =  if ( $redirecturl ne "" );
		$cookie_return = CGI::Cookie->new(
			-name   => $env->{sso_cookie_name},
			-value  => $url,
			-domain => $env->{sso_domain}
		);
	}
	elsif ( $env->{sso_enabled} ) {
		my $url = $env->{cgi_url} . "/" . $env->{main_cgi};
		$cookie_return = CGI::Cookie->new(
			-name   => $env->{sso_cookie_name},
			-value  => $url,
			-domain => $env->{sso_domain}
		);
	}

	if ( $cookie_return ) {
		print header(
			-type   => "text/html",
			-cookie => [ $args{cookie}, $cookie_return ]
		);
	}
	else {
		print header(
			-type => "text/html",
			-cookie => $args{cookie}
		);
	}

	return if $args{current} eq "exit";

	my $dbh = WebUtil::dbLogin();

	if ( $args{current} eq "Home" && $env->{abc} ) {

		# caching home page
		my $time = 3600 * 24;                   # 24 hour cache

		printHTMLHead( $args{current}, "JGI IMG Home", $args{gwt_module}, "", "", $args{numTaxons} );
		printMenuDiv( $args{current}, $dbh );
		printErrorDiv();

		HtmlUtil::cgiCacheInitialize("homepage");
		HtmlUtil::cgiCacheStart() or return;

		my ( $maxAddDate, $maxErDate ) = getMaxAddDate($dbh);

		printAbcNavBar();
		printContentHome();

		require NaturalProd;
#		$module = 'NaturalProd';
		my $bcp_cnt = NaturalProd::getPredictedBc($dbh);
		my $np_cnt  = NaturalProd::getSmStructures($dbh);
		$bcp_cnt = Number::Format::format_number($bcp_cnt);
		$np_cnt  = Number::Format::format_number($np_cnt);

		my $templateFile = $env->{base_dir} . "/home-v33.html";
		my $template = HTML::Template->new( filename => $templateFile );
		$template->param( base_url     => $env->{base_url} );
		$template->param( bc_predicted => $bcp_cnt );
		$template->param( np_items     => $np_cnt );
		print $template->output;

		HtmlUtil::cgiCacheStop();

	}
	elsif ( $env->{img_proportal} && $args{current} eq "Home" ) {
		printHTMLHead( $args{current}, "JGI IMG Home", $args{gwt_module}, "", "", $args{numTaxons} );
		printMenuDiv( $args{current}, $dbh );
		printErrorDiv();
		printContentHome();
		my $section = $cgi->param("section");
		if ( ! $section ) {

			# home page url
			my $class = $cgi->param("class") || 'datamart';
			my $new_url = $env->{main_cgi} . "?section=Home";
			HtmlUtil::cgiCacheInitialize( "homepage_" . $class );
			HtmlUtil::cgiCacheStart() or return;
			require ProPortal;
#			$module = 'ProPortal';
			ProPortal::googleMap_new( $class, $new_url );
			HtmlUtil::cgiCacheStop();
		}

	}
	elsif ( $args{current} eq "Home" ) {

		# caching home page
		my $time = 3600 * 24;         # 24 hour cache

		printHTMLHead( $args{current}, "JGI IMG Home", $args{gwt_module}, "", "", $numTaxons );
		printMenuDiv( $args{current}, $dbh );
		printErrorDiv();

		HtmlUtil::cgiCacheInitialize("homepage");
		HtmlUtil::cgiCacheStart() or return;

		my ( $maxAddDate, $maxErDate ) = getMaxAddDate($dbh);

		printStatsTableDiv( $maxAddDate, $maxErDate );
		printContentHome();
		my $templateFile = $env->{base_dir} . "/home-v33.html";
		my $hmpGoogleJs;
		if ( $env->{img_hmp} && $env->{include_metagenomes} ) {
			$templateFile = $env->{base_dir} . "/home-hmpm-v33.html";
			my $f = $env->{'hmp_home_page_file'};
			$hmpGoogleJs = file2Str( $f, 1 );
		}

		my ( $sampleCnt, $proposalCnt, $newSampleCnt, $newStudies );
		my $piechar_str;
		my $piechar2_str;
		my $table_str;
		if ( $env->{include_metagenomes} ) {

			# mer / m
			my $file =
			  $env->{webfs_data_dir} . "/hmp/img_m_home_page_v400.txt";
			if ( $env->{home_page} ) {
				$file = $env->{webfs_data_dir} . "/hmp/" . $env->{home_page};
			}

			$table_str = file2Str( $file, 1 );
			$table_str =~ s/__IMG__/$imgAppTerm/;
		}
		elsif ( $env->{img_edu} ) {

			# edu
			my $file = $env->{webfs_data_dir} . "/hmp/img_edu_home_page_v400.txt";
			$table_str = file2Str( $file, 1 );
		}
		elsif (!$env->{user_restricted_site}
			&& !$env->{include_metagenomes}
			&& !$env->{img_hmp}
			&& !$env->{img_edu} ) {

			# w
			my $file =
			  $env->{webfs_data_dir} . "/hmp/img_w_home_page_v400.txt";
			$table_str = file2Str( $file, 1 );
		}

		my $rfh = newReadFileHandle($templateFile);
		while ( my $s = $rfh->getline() ) {
			chomp $s;
			if ( $s =~ /__table__/ ) {
				$s =~ s/__table__/$table_str/;
				print "$s\n";
			}
			elsif ( $s =~ /__news__/ ) {
				my $news = qq{
<p>
For details, see <a href='$env->{base_url}/doc/releaseNotes.pdf' onClick="_gaq.push(['_trackEvent', 'Document', 'main', 'release notes']);">IMG Release Notes</a> (Dec. 12, 2012),
in particular, the workspace and background computation capabilities  available to IMG registered users.
</p>
};

				#$s =~ s/__news__/$news/;
				$s =~ s/__news__//;
				print "$s\n";
			}
			elsif ( $env->{img_hmp} && $s =~ /__hmp_google_js__/ ) {
				$s =~ s/__hmp_google_js__/$hmpGoogleJs/;
				print "$s\n";
			}
			elsif ( $env->{img_geba} && $s =~ /__pie_chart_geba1__/ ) {
				$s =~ s/__pie_chart_geba1__/$piechar_str/;
				print "$s\n";
			}
			elsif ( $env->{img_geba} && $s =~ /__pie_chart_geba2__/ ) {
				$s =~ s/__pie_chart_geba2__/$piechar2_str/;
				print "$s\n";
			}
			elsif ( $env->{include_metagenomes} && $s =~ /__pie_chart__/ ) {
				$s =~ s/__pie_chart__/$piechar_str/;
				print "$s\n";
			}
			elsif ( $env->{include_metagenomes} && $s =~ /__samples__/ ) {
				$s =~ s/__samples__/$sampleCnt/;
				print "$s\n";
			}
			elsif ( $env->{include_metagenomes} && $s =~ /__proposal__/ ) {
				$s =~ s/__proposal__/$proposalCnt/;
				print "$s\n";
			}
			elsif ( $env->{include_metagenomes} && $s =~ /__newSample__/ ) {
				$s =~ s/__newSample__/$newSampleCnt/;
				print "$s\n";
			}
			elsif ( $env->{include_metagenomes} && $s =~ /__study__/ ) {
				$s =~ s/__study__/$newStudies/;
				print "$s\n";
			}
			elsif ( $s =~ /__base_url__/ ) {
				$s =~ s/__base_url__/$env->{base_url}/;
				print "$s\n";
			}
			elsif ( $s =~ /__max_add_date__/ ) {
				$s =~ s/__max_add_date__/$maxAddDate/;
				print "$s\n";
			}
			elsif ( $s =~ /__yui__/ ) {
				$s =~ s/__yui__/$env->{yui_dir_28}/;
				print "$s\n";

				# $imgAppTerm
			}
			elsif ( $s =~ /__IMG__/ ) {
				$s =~ s/__IMG__/$imgAppTerm/;
				print "$s\n";
			}
			else {
				print "$s\n";
			}
		}
		close $rfh;

		HtmlUtil::cgiCacheStop();
	}
	else {
		print_html_head( %args );
		printMenuDiv( $args{current}, $dbh );
		printBreadcrumbsDiv( $args{current}, $args{help}, $dbh );
		printErrorDiv();

		printAbcNavBar() if $env->{abc};
		printContentOther();

		#cookieTest();
	}

	return $numTaxons;
}

=cut


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
#    my ( $current, $title, $gwt, $content_js, $yahoo_js, $numTaxons ) = @_;

	my @input = @_;
	my @params = qw( current title gwt_module content_js yui_js n_taxa );
	my %args;

	for ( my $p = 0; $p < scalar @input; $p++ ) {
		$args{ $params[$p] } = $input[$p] if $input[$p];
	}

	return print_html_head( %args );

}

sub print_html_head {

	my ( %args ) = @_;

    my $googleStr = "";
    if ( $env->{enable_google_analytics} ) {
        my ( $server, $google_key ) = WebUtil::getGoogleAnalyticsKey();
        $googleStr = googleAnalyticsJavaScript2( $server, $google_key );
    }

    my $template =
      HTML::Template->new( filename => $env->{base_dir} . "/header-v40.html" );
    $template->param( title        => $args{title} );
    $template->param( gwt          => $args{gwt_module} );
    $template->param( content_js   => $args{content_js} );
    $template->param( yahoo_js     => $args{yui_js} );
    $template->param( base_url     => $env->{base_url} );
    $template->param( YUI          => $env->{yui_dir_28} );
    $template->param( top_base_url => $env->{top_base_url} );
    $template->param( googleStr    => $googleStr );
    print $template->output;

    my $logofile = 'logo-JGI-IMG.png';
    if ( $env->{img_edu} ) {
        $logofile = 'logo-JGI-IMG-EDU.png';
    }
    elsif ( $env->{img_hmp} ) {
        $logofile = 'logo-JGI-IMG-HMP.png';
    }
    elsif ( $env->{abc} ) {
        $logofile = 'logo-JGI-IMG-ABC.png';
    }
    elsif ( $env->{img_proportal} ) {
        $logofile = 'logo-JGI-IMG-ProPortal.png';
    }
    elsif ($env->{img_er}
        && $env->{user_restricted_site}
        && !$env->{include_metagenomes} )
    {
        $logofile = 'logo-JGI-IMG-ER.png';
    }
    elsif ( $env->{include_metagenomes} && $env->{user_restricted_site} ) {
        $logofile = 'logo-JGI-IMG-ER.png';
    }
    print qq{
<header id="jgi-header">
<div id="jgi-logo">
<a href="http://jgi.doe.gov/" title="DOE Joint Genome Institute - $imgAppTerm">
<img width="480" height="70" src="$env->{top_base_url}/images/$logofile" alt="DOE Joint Genome Institute's $imgAppTerm logo"/>
</a>
</div>
};

    if ( $args{current} eq "logout" || $args{current} eq "login" ) {
        print qq{
		<nav class="jgi-nav">
			<ul>
			<li><a href="http://jgi.doe.gov">JGI Home</a></li>
			<li><a href="https://sites.google.com/a/lbl.gov/img-form/contact-us">Contact Us</a></li>
			</ul>
		</nav>
		</header>
		};

    }
    else {
        my $str = qq{<font style="color: blue;"> ALL </font>  <br/> genomes };
        if ( $args{numTaxons} eq "" ) {

        }
        else {

            my $url = "$env->{main_cgi}?section=GenomeCart&page=genomeCart";
            $url = alink( $url, $args{numTaxons} );
            my $plural = ( $args{numTaxons} > 1 ) ? "s" : "";  # plural if 2 or more +BSJ 3/16/10
            $str = "$url <br/>  genome$plural";

            print qq{
<div id="genome_cart" class="shadow"> $str </div>
};
            if ( $env->{enable_autocomplete} ) {
=cut
                print qq{
        <div id="quicksearch">
        <form name="taxonSearchForm" enctype="application/x-www-form-urlencoded" action="main.cgi" method="post">
            <input type="hidden" value="orgsearch" name="page">
            <input type="hidden" value="TaxonSearch" name="section">

            <a style="color: black;" href="$env->{base_url}/doc/orgsearch.html">
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
=cut
                # https://localhost/~kchu/preComputedData/autocompleteAll.php
                my $autocomplete_url = "$env->{top_base_url}" . "api/";

                if ( $env->{include_metagenomes} ) {
                    $autocomplete_url .= 'autocompleteAll.php';
                }
                else {
                    $autocomplete_url .= 'autocompleteIsolate.php';
                }

                # scripts/autocomplete.tt, param autocomplete_url

=cut
			print <<EOF;
<script type="text/javascript">
YAHOO.example.BasicRemote = function() {
    // Use an XHRDataSource
    var oDS = new YAHOO.util.XHRDataSource("[% autocomplete_url %]");
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
=cut

            }

            if ( $args{current} ne "login" ) {
                printLogout();
            }

            if ( $env->{img_proportal} ) {
                print qq{
        <a href="http://proportal.mit.edu/">
        <img id='mit_logo' src="$env->{base_url}/images/MIT_logo.gif" alt="MIT ProPortal logo" title="MIT ProPortal"/>
        </a>
            };
            }
            elsif ( $env->{img_hmp} ) {
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
}

############################################################################
# printExcelHeader - Print HTTP header for outputting to Excel.
############################################################################
sub printExcelHeader {
    my ($filename) = @_;
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: inline;filename=$filename\n";
    print "\n";
}

sub print_excel_header {
	my $filename = shift;
    print "Content-type: application/vnd.ms-excel\n";
    print "Content-Disposition: inline;filename=$filename\n";
    print "\n";
}


# menu
# 2nd div
#
# $current - which top level menu to highlight
sub printMenuDiv {
	my ( $current, $dbh ) = @_;

	my $template =
	  HTML::Template->new(
		filename => $env->{base_dir} . "/menu-template.html" );

	my $contact_oid = getContactOid();
	my $isEditor    = 0;
	if ( $env->{user_restricted_site} ) {
		$isEditor = isImgEditor( $dbh, $contact_oid );
	}
	my $super_user = getSuperUser();

	$env->{img_internal} = 0 if ( $env->{img_internal} eq "" );
	$env->{include_metagenomes} = 0 if ( $env->{include_metagenomes} eq "" );
	my $not_include_metagenomes = !$env->{include_metagenomes};
	$env->{enable_cassette}   = 0 if ( $env->{enable_cassette} eq "" );
	$env->{enable_workspace}  = 0 if ( $env->{enable_workspace} eq "" );
	$env->{include_img_terms} = 0 if ( $env->{include_img_terms} eq "" );
	$env->{img_pheno_rule}    = 0 if ( $env->{img_pheno_rule} eq "" );
	$env->{enable_biocluster} = 0 if ( $env->{enable_biocluster} eq "" );
	$env->{img_edu}           = 0 if ( $env->{img_edu} eq "" );
	$env->{scaffold_cart}     = 0 if ( $env->{scaffold_cart} eq "" );

	$template->param( img_internal        => $env->{img_internal} );
	$template->param( include_metagenomes => $env->{include_metagenomes} );
	$template->param( not_include_metagenomes => $not_include_metagenomes );
	$template->param( enable_cassette         => $env->{enable_cassette} );
	$template->param( enable_workspace        => $env->{enable_workspace} );

	my $enable_interpro = $env->{enable_interpro};
	$template->param( enable_interpro => $enable_interpro );

	#$template->param( img_edu           => $env->{img_edu} );
	$template->param( not_img_edu    => !$env->{img_edu} );
	$template->param( scaffold_cart  => $env->{scaffold_cart} );
	$template->param( img_submit_url => $env->{img_submit_url} );
	$template->param( base_url       => $env->{base_url} );

	#$template->param( domain_name       => $domain_name );
	$template->param( main_cgi_url => "$env->{cgi_url}/$env->{main_cgi}" );
	$template->param( img_er       => $env->{img_er} );
	$template->param( isEditor     => $isEditor );
	$template->param( imgAppTerm   => $imgAppTerm );
	$template->param( include_img_terms => $env->{include_img_terms} );
	$template->param( img_pheno_rule    => $env->{img_pheno_rule} );
	$template->param( enable_biocluster => $env->{enable_biocluster} );
	$template->param( top_base_url      => $env->{top_base_url} );
	$template->param( enable_ani        => $env->{enable_ani} );

	#if ( $super_user eq 'Yes' ) {
	$template->param( enable_omics => 1 );

	#}

	if ( $env->{enable_mybin} && canEditBin( $dbh, $contact_oid ) ) {
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

	if ( $env->{enable_cassette} ) {
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
	if ( $current eq "getsme" && !$env->{abc} ) {
		$template->param( highlight_10 => 'class="highlight"' );
	}

	# My IMG
	if ( $current eq "MyIMG" ) {
		$template->param( highlight_7 => 'class="highlight"' );
	}
	if ( $contact_oid > 0 && $env->{show_myimg_login} ) {
		$template->param( my_img_1 => '1' );
	}
	if (   $contact_oid > 0
		&& $env->{show_myimg_login}
		&& $env->{myimg_job} )
	{
		$template->param( my_img_2 => '1' );
	}
	if ( ( $env->{public_login} || $env->{user_restricted_site} ) ) {
		$template->param( my_img_3 => '1' );
	}

	# using img
	if ( $current eq "about" ) {
		$template->param(
			highlight_8 => 'class="rightmenu righthighlight"' );
	}
	else {
		$template->param( highlight_8 => 'class="rightmenu"' );
	}

	print $template->output;
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

#	my $copyright_year = };
#	my $version_year   = $env->{version_year};
#	my $img            = $cgi->param("img");

	# no exit read
	my $buildDate = file2Str( $env->{base_dir} . "/buildDate", 1 );
	my $templateFile = $env->{base_dir} . "/footer-v33.html";

   #$templateFile = $env->{base_dir} . "/footer-v33.html" if ($homeVersion);
	my $s = file2Str( $templateFile, 1 );
	$s =~ s/__main_cgi__/$env->{main_cgi}/g;
	$s =~ s/__base_url__/$env->{base_url}/g;
	$s =~ s/__copyright_year__/$env->{copyright_year/;
	$s =~ s/__version_year__/$env->{version_year}/;
	$s =~ s/__server_name__/$servername/;
	$s =~ s/__build_date__/$buildDate $remote_addr/;
	$s =~ s/__google_analytics__//;
	$s =~ s/__post_javascript__/$postJavascript/;
	$s =~ s/__top_base_url__/$env->{top_base_url}/g;
	print "$s\n";

}

sub print_main_footer {

	my $homeVersion = shift;
	my $postJavascript = shift;










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


	my $contact_oid = getContactOid();
	my $isEditor    = 0;
	if ( $env->{user_restricted_site} ) {
		$isEditor = isImgEditor( $dbh, $contact_oid );
	}

	# find last cart if any
	my $lastCart = $env->{session}->param("lastCart") || 'geneCart';
	if (
		!$isEditor
		&& (   $lastCart eq "imgTermCart"
			|| $lastCart eq "imgPwayCart"
			|| $lastCart eq "imgRxnCart"
			|| $lastCart eq "imgCpdCart"
			|| $lastCart eq "imgPartsListCart"
			|| $lastCart eq "curaCart" )
	  ) {
		$lastCart = "funcCart";
	}

	my @breadcrumbs = ( [ $env->{main_cgi}, "Home" ] );
#	my $str = alink( $env->{main_cgi}, "Home" );

	if ( $current ne "" ) {
		my $section = $cgi->param("section");
		my $page    = $cgi->param("page");

		my $urls = {
			'compare' => [ $env->{main_cgi} ."?section=CompareGenomes&page=compareGenomes", "Compare Genomes" ],
			'synteny' => [ $env->{main_cgi} . "?section=Vista&page=toppage", "Synteny Viewers" ],
			'abundance' => [ $env->{main_cgi} .
	"?section=AbundanceProfiles&page=topPage", "Abundance Profiles Tools" ],
			'myImg' => [ $env->{main_cgi} . '?section=MyIMG', 'My IMG' ],
			'workspace' => [ $env->{main_cgi} . '?section=Workspace', 'Workspace' ],
		};


		if ( ( $section eq 'Vista' && $page ne "toppage" )
			|| $section eq 'DotPlot'
			|| $section eq 'Artemis' ) {

			push @breadcrumbs, ( $urls->{compare}, $urls->{synteny} );
#			$str .= " &gt; $compare_url &gt; $synteny_url ";
		}
		elsif ( $section eq 'AbundanceProfiles' && $page ne "topPage" ) {
			push @breadcrumbs, ( $urls->{compare}, $urls->{abundance} );
		}
		elsif ( $section eq 'AbundanceProfileSearch' && $page ne "topPage" ) {
			push @breadcrumbs, ( $urls->{compare}, $urls->{abundance} );
		}
		elsif ( $section eq 'MyBins' ) {
			push @breadcrumbs, (
				[ $env->{main_cgi} . "?section=MyIMG", $breadcrumbs{$current} ],
				[ $env->{main_cgi} . "?section=MyBins", 'My Bins' ]
			);

#			my $display = $breadcrumbs{$current};
#			$display = alink( "main.cgi?section=MyIMG", $display );
#			my $tmp = alink( "main.cgi?section=MyBins", "MyBins" );
#			$str .= " &gt; $display &gt; $tmp ";

		}
		elsif ( $section =~ /^Workspace(.*?)/ ) {

			# TO DO: finish this!!

			push @breadcrumbs, ( $urls->{myImg}, $urls->{workspace} );

			if ( $1 ) {
				my $link_data = get_link( decamelize( $section ) );
				$link_data->{label} =~ s/Workspace //;
				push @breadcrumbs, decamelize( $link_data );
			}
			# this should be MyING
#			my $display = $breadcrumbs{$current};
#			$display = alink( "main.cgi?section=MyIMG", $display );
#			my $tmp = alink( "main.cgi?section=Workspace", "Workspace" );
#			$str .= " &gt; $display &gt; $tmp ";

#			if ( $page ne "" ) {
#				my $folder = param("folder");
#				if ( $page eq 'view' || $page eq 'delete' ) {
#					my $tmp = alink( "main.cgi?section=Workspace&page=$folder", $folder );
#					$str .= " &gt; $tmp ";
#				}
#				$str .= " &gt; $page ";
#			}

			if ( $page ) {
				my $folder = $cgi->param('folder');
				push @breadcrumbs, [ $env->{main_cgi} . "?section=${section}&amp;page=$folder", $folder ];
				if ( $page eq 'view' || $page eq 'delete' ) {
					push @breadcrumbs, [ $env->{main_cgi} . '?section=${section}&amp;page=$page', $folder ];
				}
			}

=cut

			# this should be MyING
			my $display = $breadcrumbs{$current};
			$display = alink( "main.cgi?section=MyIMG", $display );
			my $tmp = alink( "main.cgi?section=Workspace", "Workspace" );
			my $gene_set_url = alink( "main.cgi?section=WorkspaceGeneSet", "Gene Sets" );
			$str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
			if ( $page ne "" ) {
				my $folder = param("folder");
				if ( $page eq 'view' || $page eq 'delete' ) {
					my $tmp =
					  alink( "main.cgi?section=WorkspaceGeneSet", $folder );
					$str .= " &gt; $tmp ";
				}
				$str .= " &gt; $page ";
			}

		}
		elsif ( $section eq 'WorkspaceFuncSet' ) {

			# this should be MyING
			my $display = $breadcrumbs{$current};
			$display = alink( "main.cgi?section=MyIMG", $display );
			my $tmp = alink( "main.cgi?section=Workspace", "Workspace" );
			my $gene_set_url = alink( "main.cgi?section=WorkspaceFuncSet", "Function Sets" );
			$str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
			if ( $page ne "" ) {
				my $folder = param("folder");
				if ( $page eq 'view' || $page eq 'delete' ) {
					my $tmp =
					  alink( "main.cgi?section=WorkspaceFuncSet", $folder );
					$str .= " &gt; $tmp ";
				}
				$str .= " &gt; $page ";
			}

		}
		elsif ( $section eq 'WorkspaceGenomeSet' ) {

			# this should be MyING
			my $display = $breadcrumbs{$current};
			$display = alink( "main.cgi?section=MyIMG", $display );
			my $tmp = alink( "main.cgi?section=Workspace", "Workspace" );
			my $gene_set_url = alink( "main.cgi?section=WorkspaceGenomeSet", "Genome Sets" );
			$str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
			if ( $page ne "" ) {
				my $folder = param("folder");
				if ( $page eq 'view' || $page eq 'delete' ) {
					my $tmp = alink( "main.cgi?section=WorkspaceGenomeSet", $folder );
					$str .= " &gt; $tmp ";
				}
				$str .= " &gt; $page ";
			}

		}
		elsif ( $section eq 'WorkspaceScafSet' ) {

			# this should be MyING
			my $display = $breadcrumbs{$current};
			$display = alink( "main.cgi?section=MyIMG", $display );
			my $tmp = alink( "main.cgi?section=Workspace", "Workspace" );
			my $gene_set_url = alink( "main.cgi?section=WorkspaceScafSet", "Scaffold Sets" );
			$str .= " &gt; $display &gt; $tmp &gt; $gene_set_url ";
			if ( $page ne "" ) {
				my $folder = param("folder");
				if ( $page eq 'view' || $page eq 'delete' ) {
					my $tmp =
					  alink( "main.cgi?section=WorkspaceScafSet", $folder );
					$str .= " &gt; $tmp ";
				}
				$str .= " &gt; $page ";
			}

		}
		elsif ( $section eq 'WorkspaceRuleSet' ) {

			# this should be MyING
			my $display = $breadcrumbs{$current};
			$display = alink( "main.cgi?section=MyIMG", $display );
			my $tmp = alink( "main.cgi?section=Workspace", "Workspace" );
			my $rule_set_url = alink( "main.cgi?section=WorkspaceRuleSet", "Rule Sets" );
			$str .= " &gt; $display &gt; $tmp &gt; $rule_set_url ";
			if ( $page ne "" ) {
				my $folder = param("folder");
				if ( $page eq 'view' || $page eq 'delete' ) {
					my $tmp = alink( "main.cgi?section=WorkspaceRuleSet", $folder );
					$str .= " &gt; $tmp ";
				}
				$str .= " &gt; $page ";
			}

		}
		elsif ( $section eq 'Workspace' ) {

			# this should be MyING
			my $display = $breadcrumbs{$current};
			$display = alink( "main.cgi?section=MyIMG", $display );
			my $tmp = alink( "main.cgi?section=Workspace", "Workspace" );
			$str .= " &gt; $display &gt; $tmp ";
			if ( $page ne "" ) {
				my $folder = param("folder");
				if ( $page eq 'view' || $page eq 'delete' ) {
					my $tmp = alink( "main.cgi?section=Workspace&page=$folder", $folder );
					$str .= " &gt; $tmp ";
				}
				$str .= " &gt; $page ";
			}
=cut
		}
		else {
			push @breadcrumbs, $breadcrumbs{$current};
		#	my $display = $breadcrumbs{$current};
#			$str .= " &gt; $display";
		}
	}

	my $data = {
		breadcrumbs => [ @breadcrumbs ],
	};
	if ( $help ) {
		$data->{help_link} = $env->{base_url} . "/doc/$help";
	}

	return $data;
=cut
	print qq{
<div id="breadcrumbs_frame">
<div id="breadcrumbs"> $str </div>
<div id="loading">  <font color='red'> Loading... </font> <img src='$env->{base_url}/images/ajax-loader.gif' /> </div>
};

	# when to print help icon
	print qq{
<div id="page_help">
};

	if ( $help ne "" ) {
		print qq{
	<a href='$env->{base_url}/doc/$help' target='_help' onClick="_gaq.push(['_trackEvent', 'Document', 'printBreadcrumbsDiv', '$help']);">
	<img width="40" height="27" border="0" style="margin-left: 35px;" src="$env->{base_url}/images/help.gif"/>
	</a>
	};
	}
	else {
		print qq{
	&nbsp;
	};
	}

	print qq{
</div>
<div id="myclear"></div>
</div>
};

=cut
}

# error frame - test to see if js enabled
# if enabled you can use div's id "error_content" innerHtml to display an error message
# and
# error frame - hidden by default but to display set an in-line style:
#  style="display: block" to override the default css
# 4th div
sub printErrorDiv {
	my $section = $cgi->param('section');

	my $template = HTML::Template->new( filename => $env->{base_dir} . "/error-message-tmpl.html" );
	$template->param( base_url => $env->{base_url} );

	if (   $section eq 'Artemis'
		|| $section eq 'DistanceTree'
		|| $section eq 'Vista'
		|| $section eq 'ClustalW'
		|| $section eq 'Kmer'
		|| $section eq 'EgtCluster'
		|| $section eq 'RNAStudies'
		|| $section eq 'IMGProteins' )
	{

		my $text = <<EOF;
<script src="https://www.java.com/js/deployJava.js"></script>
<script type="text/javascript">
var d = document.getElementById('error_content');
if(! navigator.javaEnabled()) {
	d.style.display='block'; d.innerHTML = "Please <a href='http://java.com/en/download/help/enable_browser.xml'>enable Java in your browser.</a>";
} else {
	var x = deployJava.versionCheck('1.6+');
	if (!x) {
		d.style.display='block';d.innerHTML="Please <a href='http://java.com/'>update your Java.</a>";
	}
}
</script>
EOF
		$template->param( java_test => $text );
	}
	else {
		$template->param( java_test => '' );
	}

	print $template->output;

	my $str = WebUtil::webDataTest();

	# message from the web config file - ken
	if ( $env->{message} ne "" || $str ne "" ) {
		print qq{
	<div id="message_content" class="message_frame shadow" style="display: block" >
	<img src='$env->{base_url}/images/announcementsIcon.gif'/>
	$env->{message}
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
#	$module = 'MainPageStats';
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

	}
	elsif ( $env->{abc} ) {
		my $dbh = dbLogin();
		require BiosyntheticStats;
#		$module = 'BiosyntheticStats';
		my ( $totalCnt, %domain2cnt ) =
		  BiosyntheticStats::getStatsByDomain($dbh);
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
				$url =
"main.cgi?section=BiosyntheticStats&page=byGenome&domain=$domain";
			}
			print "<tr>\n";
			my $domain_name = $domain;
			if ( $domain eq '*Microbiome' ) {
				$domain_name = "Metagenomes";
			}
			print
"<td style='line-height: 1.25em; width: 90px;'>$domain_name</td>\n";
			print "<td style='line-height: 1.25em;' align='right'>"
			  . alink( $url, $cluster_cnt )
			  . "</td>\n";
			print "</tr>\n";
		}

		print qq{
</table>
		};
		require NaturalProd;
#		$module = 'NaturalProd';
		my $href = NaturalProd::getNpPhylum($dbh);
		print qq{
<table cellspacing="0" cellpadding="0">
	<th align='left' valign='bottom'>Phylum</th>
	<th align='right' valign='bottom'>Secondary Metabolites</th>
		};
		foreach my $name ( sort( keys %$href ) ) {
			my $cnt = $href->{$name};
			my $tmp = WebUtil::massageToUrl2($name);
			my $url =
"main.cgi?section=NaturalProd&page=subCategory&stat_type=Phylum&stat_val="
			  . $tmp;
			print "<tr>\n";
			print
			  "<td style='line-height: 1.25em; width: 90px;'>$name</td>\n";
			print "<td style='line-height: 1.25em;' align='right'>"
			  . alink( $url, $cnt )
			  . "</td>\n";
			print "</tr>\n";
		}

		print qq{
</table>
<br>
		};
	}

	if ( $env->{img_hmp} ) {
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
	}
	elsif ( !$env->{abc} ) {
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
	if ( $env->{img_er} ) {
		$tmp = qq{
	   <span style="font-family: Arial; font-size: 12px; color: black;">
	   &nbsp;&nbsp;&nbsp; Last updated: <a href='main.cgi?section=TaxonList&page=lastupdated'> $maxErDate </a> <br/>
	   </span>
   };
	}
	elsif ( $env->{include_metagenomes}
		&& ( $env->{public_login} || $env->{user_restricted_site} ) )
	{
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
	}
	else {
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
	if ( $env->{use_img_gold} && !$env->{include_metagenomes} ) {
		print qq{
	<a href="main.cgi?section=TaxonList&page=genomeCategories">Genome by Metadata</a> <br/>
	};
	}

	# google map link
	if ( $env->{include_metagenomes} ) {
		print qq{
	<a href="main.cgi?section=ImgStatsOverview&page=googlemap">Metagenome Projects Map</a><br/>
	};
	}
	elsif ( $env->{use_img_gold} ) {
		print qq{
	<a href="main.cgi?section=ImgStatsOverview&page=googlemap">Project Map</a><br/>
	};
	}

	print qq{
<a href="$env->{base_url}/doc/systemreqs.html">System Requirements</a>  <br/>
};

	print qq{
<p style="width: 175px;">
	<img width="80" height="50"  style="float:left; padding-right: 5px;" src="$env->{base_url}/images/imguser.jpg"/>
		Hands on training available at the
		<p>
		<a href="http://www.jgi.doe.gov/meetings/mgm">Microbial Genomics &amp;
		Metagenomics Workshop</a>

};

	if ( $env->{homePage}
		&& !$env->{img_hmp}
		&& !$env->{img_edu}
		&& !$env->{abc}
		&& !$env->{img_proportal} ) {

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




sub printNewsDiv {

	# read news  file
	my $file = '/webfs/scratch/img/news.html';
	if ( -e $file ) {
		print qq{
		<span id='news2'>News</span>
		<div id='news'>
	};
		my $line;
		my $rfh = newReadFileHandle($file);
		my $i   = 0;
		while ( my $line = $rfh->getline() ) {
			last if ( $i > 3 );
			if ( $line =~ /^<b id='subject'>/ ) {
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
	return if ( $env->{img_edu} );

	if ( !$env->{user_restricted_site} && !$env->{public_login} ) {

		my $session = getSession();

		# only test cookie for public sites
		my $cookie_test = cookie( -name => $cookie_name );
		if ( defined $cookie_test ) {

			# do nothing
			# cookie was set
			# print "===>$cookie_test<===  $cookie_name $cookie <br/>\n";
		}
		else {

			#print "===>$cookie_test<===  $cookie_name $cookie <br/>\n";
			WebUtil::clearSession();
			WebUtil::webError(
"Your browser is not accepting cookies. Please enabled cookies to view IMG."
			);
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

	my $cur = execSql( $dbh, $sql, $env->{verbose} );
	my ($max) = $cur->fetchrow();

	# this the acutal db ui release date not the genome add_date - ken
	my $maxErDate;
	my $sql2 = qq{
select to_char(release_date, 'yyyy-mm-dd') from img_build
	};
	$cur = execSql( $dbh, $sql2, $env->{verbose} );
	($maxErDate) = $cur->fetchrow();

	return ( $max, $maxErDate );
}

# logout in header under quick search - ken
sub printLogout {

	# in the img.css set the z-index to show the logout link - ken
	if ( $env->{public_login} || $env->{user_restricted_site} ) {
		my $contact_oid = getContactOid();
		return if ! $contact_oid || $cgi->param("logout") ne "";

		my $name = WebUtil::getUserName2() || WebUtil::getUserName();

		my $tmp = "<br/> (JGI SSO)";
		if ( $env->{oldLogin} ) {
			$tmp = "";
		}

		return { name => $name };

#		print qq{
#	<div id="login">
#		Hi $name &nbsp; | &nbsp; <a href="main.cgi?logout=1"> Logout </a>
#		$tmp
#	</div>
#	};
	}
}


sub googleAnalyticsJavaScript {
	my ( $server, $google_key ) = @_;

	my $str = file2Str( $env->{base_dir} . "/google.js", 1 );
	$str =~ s/__google_key__/$google_key/g;
	$str =~ s/__server__/$server/g;

	return $str;
}

# newer version using async
sub googleAnalyticsJavaScript2 {
	my ( $server, $google_key ) = @_;

	my $str = file2Str( $env->{base_dir} . "/google2.js", 1 );
	$str =~ s/__google_key__/$google_key/g;
	$str =~ s/__server__/$server/g;

	return $str;
}

############################################################################
# printTaxonFilterStatus - Show current selected number of genomes.
#  WARNING: very convoluted code.
############################################################################
sub get_n_taxa {

	my $taxon_oids = GenomeCart::getAllGenomeOids();
	return scalar @$taxon_oids || 0;

}

sub redirectform {
	my ($noprint) = @_;

	# get url redirect param
	my @names = param();

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
		}
		elsif ( $count == 0 ) {
			$url = $url . "?" . $names[$i] . "=" . $value;
		}
		else {
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

	my $q = CGI->new();
	print $q->redirect("main.cgi$url");

	print_app_header( current => "Home" );
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
		"name\tYour Name\tchar\t80\tY", "title\tTitle\tchar\t80\tN", "department\tDepartment\tchar\t255\tN", "email\tYour Email\tchar\t255\tY", "phone\tPhone Number\tchar\t80\tN", "organization\tOrganization\tchar\t255\tY", "address\tAddress\tchar\t255\tN", "city\tCity\tchar\t80\tY", "state\tState\tchar\t80\tN", "country\tCountry\tchar\t80\tY", "username\tPreferred Login Name\tchar\t20\tY", "group_name\tGroup (if known)\tchar\t80\tN", "comments\tReason(s) for Request\ttext\t60\tY"
	);

	return @attrs;
}


#
# print the ABC nav bar / menu on the left side
#
sub printAbcNavBar {
	if ( $env->{abc} ) {
		my $templateFile = $env->{base_dir} . "/abc-nav-bar.html";
		my $template = HTML::Template->new( filename => $templateFile );
		print $template->output;
	}
}

############################################################################
# webError - Show error message.
############################################################################
sub webError {
    my ( $txt, $exitcode, $noHtmlEsc ) = @_;

    my $copyright_year = $env->{copyright_year};
    my $version_year   = $env->{version_year};

    my $remote_addr = $ENV{REMOTE_ADDR};
    my $servername;
    my $s = getHostname();
    $servername = $s . ' ' . ( $ENV{ORA_SERVICE} || "" ) . ' ' . $];
    my $buildDate = file2Str( $env->{base_dir} . "/buildDate", 1 );

    print "<div id='error'>\n";
    print "<img src='" . $env->{base_url} . "/images/error.gif' " . "width='46' height='46' alt='Error' />\n";
    print "<p>\n";
    if ( ! $noHtmlEsc ) {
        print escHtml($txt);
    } else {
        print $txt;
    }
    print "</p>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
    my $templateFile = $env->{base_dir} . "/footer.html";
    my $str            = file2Str($templateFile);
    my $main_cgi = $env->{main_cgi};
    $str =~ s/__main_cgi__/$main_cgi/g;
    $str =~ s/__google_analytics__//g;

    $str =~ s/__copyright_year__/$copyright_year/;
    $str =~ s/__version_year__/$version_year/;

    $str =~ s/__server_name__/$servername/;
    $str =~ s/__build_date__/$buildDate $remote_addr/;
    $str =~ s/__post_javascript__//;

    print "$str\n";

    printStatusLine( "Error", 2 );
    webExit($exitcode);
}


sub web_error {



}

############################################################################
# webErrorHeader - Show error with header.
############################################################################
sub webErrorHeader {
    my ( $msg, $noHtmlEsc, $exitcode ) = @_;

    print header( -type => "text/html" );
    print "<br>\n";
    webError( $msg, $exitcode, $noHtmlEsc );

    #    if ($noHtmlEsc) {
    #        print $msg;
    #    } else {
    #        print escHtml($msg);
    #    }
    #    webExit($exitcode);
}

############################################################################
# printMessage - Print boxed message.
############################################################################
sub printMessage {
    my ($html) = @_;
    print "<div id='message'>\n";
    print "<p>\n";
    print "$html\n";
    print "</p>\n";
    print "</div>\n";
}

############################################################################
# webDie - Code dies a serious death.   Show on web.
############################################################################
sub webDie {
    my ($s) = @_;

    #webError($s);
    print "Content-type: text/html\n\n";
    print header( -status => '404 Not Found' );
    print "<html>\n";
    print "<p>\n";
    print "SCRIPT ERROR:\n";
    print "<p>\n";
    print "<font color='red'>\n";
    print "<b>$s</b>\n";
    print "</font>\n";

    webExit(0);
}

# printHint - Print hint box with message.
############################################################################
sub printHint2 {
    my ($txt) = @_;
    my $base_url = $env->{base_url};
    print "<div id='hint'>\n";
    print "<img src='$base_url/images/hint.gif' " . "width='67' height='32' alt='Hint' />";
    print "<div>\n";
    print "<table cellpadding=0 border=0>";
    print $txt;
    print "</table>";
    print "</div>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
}

############################################################################
# printHint - Print hint box with message.
############################################################################
sub printHint {
    my ( $txt, $maxwidth ) = @_;
    my $base_url = $env->{base_url};
    if ( $maxwidth ne '' ) {
        print "<div id='hint' style='width:" . $maxwidth . "px;'>\n";
    } else {
        print "<div id='hint'>\n";
    }
    print "<img src='$base_url/images/hint.gif' " . "width='67' height='32' alt='Hint' />";
    print "<p>\n";
    print $txt;
    print "</p>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
}

############################################################################
# printWideHint - Print hint box with message.
############################################################################
sub printWideHint {
    my ($txt) = @_;
    my $base_url = $env->{base_url};
    print "<div id='hint' style='width: 400px;'>\n";
    print "<img src='$base_url/images/hint.gif' " . "width='67' height='32' alt='Hint' />";
    print "<p>\n";
    print $txt;
    print "</p>\n";
    print "</div>\n";
    print "<div class='clear'></div>\n";
}


1;
