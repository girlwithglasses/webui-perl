###########################################################################
#
#
# $Id: GeneCassetteSearch.pm 30629 2014-04-14 21:26:04Z klchu $

package GeneCassetteSearch;
my $section = "GeneCassetteSearch";
use strict;
use CGI qw( :standard );
use DBI;

use Data::Dumper;
use WebConfig;
use WebUtil;
use OracleUtil;
use InnerTable;
use MetagenomeGraph;
use GeneCassette;
use GenomeListFilter;
use HtmlUtil;
use GenomeListJSON;
use HTML::Template;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $cgi_url             = $env->{cgi_url};
my $tmp_url               = $env->{tmp_url};
my $tmp_dir               = $env->{tmp_dir};
my $verbose               = $env->{verbose};
my $web_data_dir          = $env->{web_data_dir};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $img_lite              = $env->{img_lite};
my $img_internal          = $env->{img_internal};
my $img_ken               = $env->{img_ken};
my $YUI                   = $env->{yui_dir_28};
my $yui_tables            = $env->{yui_tables};
my $include_cassette_bbh  = $env->{include_cassette_bbh};
my $include_cassette_pfam = $env->{include_cassette_pfam};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $public_nologin_site   = $env->{public_nologin_site};
my $include_metagenomes   = $env->{include_metagenomes};
my $user_restricted_site  = $env->{user_restricted_site};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $enable_cassette       = $env->{enable_cassette};
my $MIN_GENES = 2;
my $nvl       = getNvl();

# batch query that have in stmt with more than 1000 items
my $BATCH_SIZE = 999;

sub dispatch {
    my ($numTaxon) = @_;    # number of saved genomes
    
    return if(!$enable_cassette);
    
    $numTaxon = 0 if ( $numTaxon eq "" );
    my $sid  = getContactOid();
    my $page = param("page");
    if ( $page eq "runSearch" ) {

        my $file1 = param("file1"); # test to see to see if paging cached exists
        my $ans   = 1;
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {
                HtmlUtil::cgiCacheInitialize( $section );
                HtmlUtil::cgiCacheStart() or return;
            }
        }
        printRunSearch();

        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );

    } elsif ( $page eq "form" ) {
        my $ans = 1;    # do not use cache pages if $ans
        if ( HtmlUtil::isCgiCacheEnable() ) {
            $ans = $numTaxon;
            if ( !$ans ) {

                # start cached page - all genomes
                HtmlUtil::cgiCacheInitialize( $section );
                HtmlUtil::cgiCacheStart() or return;
            }
        }
        printSearchForm3();
        HtmlUtil::cgiCacheStop() if ( HtmlUtil::isCgiCacheEnable() && !$ans );
    } else {
        printTopPage();
    }
}

sub printTopPage {
    print qq{
        <a href='$section_cgi&page=form2&cluster=cog'> COG </a>
        <br/>
        <a href='$section_cgi&page=form2&cluster=pfam'> Pfam </a>
        <br/>
        <a href='$section_cgi&page=form2&cluster=bbh'> bbh </a>
        <br/>
        <a href='$section_cgi&page=form'> text search </a>
        <br/>
        
    };
}

#
# text base search - run method after the user presses submit
#
sub printRunSearch {
    my $cluster    = param("cluster");
    my $field      = param("field");
    my $logical    = param("logical");
    my $searchtext = param("searchtext");
    my $sort       = param("sort");
    my $file1 = param("file1");    # test to see to see if paging cached exists
    my $file2 = param("file2");
    my $file3 = param("file3");
    my $page_num = param("page_num");

    $page_num = 1 if ( $page_num eq "" );

    print "<h1>Cassette Search Results </h1>\n";
    print qq{
        $cluster <br/>
        $field <br/>
        $logical <br/>
    } if ($img_ken);

    $searchtext =~ s/\r//g;
    if ( blankStr($searchtext) ) {
        webError("No search term specified. Please go back and enter a term.");
    }
    if ( $searchtext !~ /[a-zA-Z0-9]+/ ) {
        webError("Search term should have some alphanumeric characters.");
    }

    my @searchTerms = WebUtil::splitTerm( $searchtext, 0, 0 );
    my %searchTermsHash;
    print "<p>Search Terms <br/>\n";
    foreach my $x (@searchTerms) {
        my $tmp = strTrim($x);
        print "$tmp<br/>\n";
        $searchTermsHash{$tmp} = 1;
    }
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    printStartWorkingDiv();

    my $foundIds_href;
    $file1 = WebUtil::checkFileName($file1);
    my $cachePath = "$cgi_tmp_dir/$file1";
    if ( $file1 ne "" && -e $cachePath ) {
        $foundIds_href = readFoundFuncIds($file1);
    } else {

        # do  sql
        $foundIds_href = searchCluster( $dbh, $cluster, $field, \@searchTerms );
        $file1 = cacheFoundFuncIds($foundIds_href);
    }
    my $found_size = keys %$foundIds_href;
    print "Function ids found: $found_size <br/>\n";

    #print Dumper $foundIds_href;

    if ( $found_size == 0 ) {
        print "Nothing found<br/>";
        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        return;
    }

    # logical filter  done in search cassette method
    print "Searching for Cassette IDs <br/>";

    # hash of hashes cassette id => hash of func ids found
    my $cassettes_href;
    $file2 = WebUtil::checkFileName($file2);
    my $cachePath = "$cgi_tmp_dir/$file2";

    # hash cassette id => gene count
    my $cassette_gene_cnt_href;

    if ( $file2 ne "" && -e $cachePath ) {
        $cassettes_href = readFoundCassette($file2);
    } else {

        # TODO add taxon selection here

        # do sql
        $cassettes_href =
          searchCassette( $dbh, $cluster, $foundIds_href, \@searchTerms, $field,
                          $logical );
        $file2 = cacheFoundCassette($cassettes_href);
    }
    my $size = keys %$cassettes_href;
    print "Found $size Cassette IDs <br/>\n";
    if ( $size == 0 ) {
        print "Nothing found<br/>";
        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        return;
    }

    # get cassette gene counts
    $cassette_gene_cnt_href = getCassetteGeneCnt( $dbh, $cassettes_href );

    # now $cassettes_href may be in gtt

    # get cassette genome name
    my $cassette_genomename_href = getCassetteGenome( $dbh, $cassettes_href );

    # calc the number of funcs in each cassette id
    # number of function matches
    my %cassettes_size;
    foreach my $id ( keys %$cassettes_href ) {
        my $href = $cassettes_href->{$id};
        my $size = keys %$href;
        $cassettes_size{$id} = $size;
    }

    # store the sort array of cassette ids
    my @sort_cassette_ids;
    $file3 = WebUtil::checkFileName($file3);
    my $cachePath = "$cgi_tmp_dir/$file3";
    if ( $file3 ne "" && -e $cachePath ) {
        print "reading cache $cachePath <br/>";
        my $aref = readArray($file3);
        @sort_cassette_ids = @$aref;
    } else {
        if ( $sort eq "genecount" ) {

            # sort by cassette gene count
            foreach my $id (
                sort {
                    $cassette_gene_cnt_href->{$b} <=>
                      $cassette_gene_cnt_href->{$a}
                }
                keys %$cassette_gene_cnt_href
              )
            {
                push( @sort_cassette_ids, $id );
            }
        } else {

            # sort by function matches
            foreach my $id (
                sort {
                    $cassettes_size{$b} <=> $cassettes_size{$a}
                }
                keys %cassettes_size
              )
            {
                push( @sort_cassette_ids, $id );
            }
        }
        $file3 = cacheArray( \@sort_cassette_ids );
    }

printEndWorkingDiv();

    print qq{
        <p>
        Page $page_num - 100 shown per page
        <br/>
    };

    if ( $sort eq "genecount" ) {
        print qq{
        Sorted by the number of Cassette gene count
        </p>            
        };

    } else {
        print qq{
        Sorted by the number of matches 
        </p>            
        };
    }

    my $count           = 0;
    my $calc_page_end   = $page_num * 100;         # initial 100
    my $calc_page_start = $calc_page_end - 100;    # initial 0

    # Use YUI css
    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
        <style type="text/css">
	.img-match-bgColor {
	    background-color: #DBEAFF;
	}
	</style>

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Cassette ID</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Cassette Gene Count</span>
	    </div>
	</th>
	<th>
 	    <div class='yui-dt-liner'>
	        <span>Function ID</span>
	    </div>
	</th>
	<th>
 	    <div class='yui-dt-liner'>
	        <span>Function Name</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Gene ID</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Genome Name</span>
	    </div>
	</th>
YUI
    } else {
        print qq{
            <table class='img'>
            <th class='img'>Cassette ID</th>
            <th class='img'>Cassette Gene Count</th>
            <th class='img'>Function ID</th>
            <th class='img'>Function Name</th>
            <th class='img'>Gene ID</th>
            <th class='img'>Genome Name</th>
        };
    }

    foreach my $id (@sort_cassette_ids) {
        $count++;
        last if ( $count > $calc_page_end );
        next if ( $count <= $calc_page_start );

        my $size = $cassettes_size{$id};
        my $classStr;

        if ($yui_tables) {
            $classStr = "yui-dt-first img-match-bgColor";
        } else {
            $classStr = "img";
        }

        print "<tr class='$classStr'>\n";
        print "<td class='img' colspan='6'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;
        print "Number of function matches: " . $cassettes_size{$id};
        print "</div>\n" if $yui_tables;
        print "</td></tr>\n";
        my $aref = getCassetteGenes( $dbh, $cluster, $id );
        printCassetteRows( $aref, \%searchTermsHash, $field, $cluster,
                           $cassette_gene_cnt_href, $cassette_genomename_href );
    }
    print "</table>\n";
    print "</div>\n" if $yui_tables;

    # print next and prev url
    printMainForm();
    $page_num++;
    print qq{
        <script language="javascript" type="text/javascript">
        function mySubmit() {          
            document.mainForm.submit();
        }
        </script>
    };
    print hiddenVar( "section",    $section );
    print hiddenVar( "page",       "runSearch" );
    print hiddenVar( "cluster",    "$cluster" );
    print hiddenVar( "field",      "$field" );
    print hiddenVar( "logical",    "$logical" );
    print hiddenVar( "cluster",    "$cluster" );
    print hiddenVar( "sort",       "$sort" );
    print hiddenVar( "file1",      "file1" );
    print hiddenVar( "file2",      "$file2" );
    print hiddenVar( "file3",      "$file3" );
    print hiddenVar( "page_num",   "$page_num" );
    print hiddenVar( "searchtext", "$searchtext" );

    my $size = $#sort_cassette_ids + 1;
    print "<p>\n";
    if ( $page_num > 2 ) {
        print qq{
        <input type="button" 
        name="prev" 
        value="&lt; Prev" 
        class="meddefbutton"
        onClick='javascript:history.back()' />      
        &nbsp;  
        };

    }
    if ( $count < $size ) {
        print qq{
        <input type="button" 
        name="_section_GeneCassetteSearch_runSearch" 
        value="Next &gt;" 
        class="meddefbutton"
        onClick='mySubmit()' />        
        };
    }
    print "</p>\n";
    print end_form();

    #$dbh->disconnect();
    printStatusLine( "$size results", 2 );
}

# prints search results for a cassette
sub printCassetteRows {
    my ( $list_aref, $terms_href, $field, $cluster, $cassette_gene_cnt_href,
         $cassette_genomename_href )
      = @_;
    my $count    = 0;
    my $cass_url =
        "main.cgi?section=GeneCassette&page=cassetteBox"
      . "&type=$cluster"
      . "&cassette_oid=";
    my $gene_url = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    foreach my $line (@$list_aref) {
        my ( $cid, $funcid, $gid, $funcname ) = split( /\t/, $line );
        my $gene_cnt = $cassette_gene_cnt_href->{$cid};
        my $classStr;

        if ($yui_tables) {
            $classStr = !$count ? "yui-dt-first " : "";
            $classStr .= ( $count % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        print "<tr class='$classStr'>\n";
        if ( $field eq "name" ) {
            my $x = isMatch( $funcname, $terms_href );
            next if ( !$x );    # ignore no mathcing rows?
            $count++;

            if ( $count == 1 ) {
                my $url = alink( $cass_url . $cid, $cid );
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $url;
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $gene_cnt;
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            } else {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $funcid;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ($x) {
                print $x;
            } else {
                print $funcname;
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            my $url = alink( $gene_url . $gid, $gid );

            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $url;
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        } elsif ( $field eq "id" ) {
            my $y = isMatchId( $funcid, $terms_href );
            next if ( !$y );    # ignore no mathcing rows?
            $count++;
            if ( $count == 1 ) {
                my $url = alink( $cass_url . $cid, $cid );
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $url;
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $gene_cnt;
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            } else {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            if ($y) {
                print $y;
            } else {
                print $funcid;
            }
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $funcname;
            print "</div>\n" if $yui_tables;
            print "</td>\n";

            my $url = alink( $gene_url . $gid, $gid );
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $url;
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        } else {
            my $x = isMatch( $funcname, $terms_href );
            my $y = isMatchId( $funcid, $terms_href );

            next if ( !$x && !$y );    # ignore no mathcing rows?
            $count++;

            if ( $count == 1 ) {
                my $url = alink( $cass_url . $cid, $cid );
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $url;
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $gene_cnt;
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            } else {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print nbsp(1);
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }

            if ( $x && $y ) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $y;
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $x;
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            } elsif ($y) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $y;
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $funcname;
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            } elsif ($x) {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $funcid;
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $x;
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            } else {
                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $funcid;
                print "</div>\n" if $yui_tables;
                print "</td>\n";

                print "<td class='$classStr'>\n";
                print "<div class='yui-dt-liner'>" if $yui_tables;
                print $funcname;
                print "</div>\n" if $yui_tables;
                print "</td>\n";
            }
            my $url = alink( $gene_url . $gid, $gid );
            print "<td class='$classStr'>\n";
            print "<div class='yui-dt-liner'>" if $yui_tables;
            print $url;
            print "</div>\n" if $yui_tables;
            print "</td>\n";
        }

        print "<td class='$classStr'>\n";
        print "<div class='yui-dt-liner'>" if $yui_tables;

        if ( $count == 1 ) {
            my $line = $cassette_genomename_href->{$cid};
            my ( $name, $taxon_oid ) = split( /\t/, $line );
            my $url =
"main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
            $url = alink( $url, $name );
            print $url;
        } else {
            print nbsp(1);
        }
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";

    }    # end for loop

}

# match function name
# return the section matched otherwise 0
sub isMatch {
    my ( $text, $terms_href ) = @_;
    foreach my $x ( keys %$terms_href ) {
        if ( $text =~ /$x/i ) {
            $text =~ s/($x)/<font color='green'><b>\1<\/b><\/font>/i;
            return $text;
        }
    }
    return 0;
}

# match function id
# return the section matched otherwise 0
sub isMatchId {
    my ( $text, $terms_href ) = @_;
    foreach my $x ( keys %$terms_href ) {
        if ( $text =~ /($x)$/i ) {

            $text =~ s/($x)$/<font color='green'><b>\1<\/b><\/font>/i;
            return $text;
        }
    }
    return 0;
}

sub getCassetteGenes {
    my ( $dbh, $cluster, $cid ) = @_;

    my $sql;
    if ( $cluster eq "pfam" ) {
        $sql = qq{
        select distinct gcg.cassette_oid, gc.pfam_family, gc.gene_oid, c.description
        from gene_cassette_genes gcg, gene_pfam_families gc, pfam_family c
        where gcg.gene = gc.gene_oid
        and gc.pfam_family = c.ext_accession
        and gcg.cassette_oid = ?
        order by 2            
        };
    } elsif ( $cluster eq "bbh" ) {
        $sql = qq{
        select distinct gcg.cassette_oid, gc.cluster_id, gc.member_genes, c.cluster_name
        from gene_cassette_genes gcg, bbh_cluster_member_genes gc, bbh_cluster c
        where gcg.gene = gc.member_genes
        and gc.cluster_id = c.cluster_id
        and gcg.cassette_oid = ?
        order by 2
        };
    } else {
        $sql = qq{
        select distinct gcg.cassette_oid, gc.cog, gc.gene_oid, c.cog_name 
        from gene_cassette_genes gcg, gene_cog_groups gc, cog c
        where gcg.gene = gc.gene_oid
        and gc.cog = c.cog_id
        and gcg.cassette_oid = ?
        order by gc.cog
        };
    }
    my @list;
    my $cur = execSql( $dbh, $sql, 1, $cid );
    for ( ; ; ) {
        my ( $id, $cog, $gene_oid, $cname ) = $cur->fetchrow();
        last if ( !$id );

        push( @list, "$id\t$cog\t$gene_oid\t$cname" );
    }

    #$cur->finish();

    return \@list;
}

#
# JavaScript validation to check for blank text
# Used by printSearchForm ()
#

sub printSearchFormJS {
    print q{
       <script language='javascript' type='text/javascript'>
          function blankText () {
            var sTerm = document.mainForm.searchtext.value;
            sTerm = sTerm.replace(/^\s\s*/, '').replace(/\s\s*$/, '');
            if (sTerm == "") {
               alert ("Please enter a search term.");
               document.mainForm.searchtext.value = "";
               document.mainForm.searchtext.focus();
               return false;
            }
          }
       </script>
     }
}

# text search version
sub printSearchForm {
    printSearchFormJS();
    print qq{
        <h1>
        Cassette Search
        </h1>
    };

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<p>\n";

    # Use YUI css
    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
	    href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Select Protein Cluster</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Function Search Field</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Logical Operator</span>
	    </div>
	</th>
        <th>
 	    <div class='yui-dt-liner'>
	        <span>Sort Results</span>
	    </div>
	</th>

YUI
    } else {
        print qq{
          <table class='img' border=1>
          <th class='img'>Select Protein Cluster</th>
          <th class='img'>Function Search Field</th>
          <th class='img'>Logical Operator</th>
          <th class='img'>Sort Results</th>
        };
    }

    my $classStr;

    if ($yui_tables) {
        $classStr = "yui-dt-first yui-dt-odd";
    } else {
        $classStr = "img";
    }

    # radio buttons
    my $xml_url = "xml.cgi?section=$section&page=table&cluster=";

    # Select Protein Cluster
    print "<tr class='$classStr' valign='top'>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<input type='radio' name='cluster' value='cog' checked='checked' />";
    print "COG<br/>\n";
    if ($include_cassette_pfam) {
        print "<input type='radio' name='cluster' value='pfam' " . "/>";
        print "Pfam<br/>\n";
    }
    if ($include_cassette_bbh) {
        print "<input type='radio' name='cluster' value='bbh'" . "/>";
        print "IMG Ortholog Cluster\n";
    }
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Function Search Field
    print "<td class='$classStr' valign='top' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{
        <input type='radio' name='field' value='id' 
        title='regex search % id' checked /> Function ID<br/>
        <input type='radio' name='field' value='name' 
        title='regex search % name %' /> Function Name <br/>
        <input type='radio' name='field' value='both' /> Both (Id and Name)
    };
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Logical Operator
    print "<td class='$classStr' valign='top' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{
        <input type='radio' name='logical' value='and' checked /> And (intersection)<br/>
        <input type='radio' name='logical' value='or'  /> Or (union)
    };
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Sort Results
    print "<td class='$classStr' valign='top' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{        
        <input type='radio' name='sort' value='match' checked /> Function matches <br/>
        <input type='radio' name='sort' value='genecount'  /> Cassette gene count
    };

    print "</div>\n" if $yui_tables;
    print "</td></tr>\n";
    print "</table>\n";
    print "</div>\n" if $yui_tables;
    print "</p>\n";

    # search text delimiter is a comma?
    print qq{
        <table border='0'> <tr> <td>
        <p><b>Search Text</b> <br/>
        Use commas to separate search terms.<br/>
	<textarea name='searchtext' rows='3' cols='60' style='background-color: #FFFFFF'></textarea>
	</p>
    };

    my $dbh = dbLogin();
    GenomeListFilter::appendGenomeListFilter($dbh);
    #$dbh->disconnect();

    print qq{
	    <br/> 
    };

    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "runSearch" );

    print submit(
                  -id      => 'go',
                  -class   => 'smdefbutton',
                  -name    => 'submit',
                  -value   => 'Search',
                  -onClick => 'return blankText();',
    );
    print nbsp(1);
    print reset( -id    => 'reset',
                 -class => 'smbutton' );

    print qq{
</td>
<td valign='top'>
<h3> Examples </h3>
<p>
- "COG0331, COG0300, COG0335" as search text will find cassettes with all 3 COG terms
<br/>
- Prefixes for cog and pfam are assumed, above can be shorten to "0331, 0300, 0335".
<br/>
- ID searches use RegExp *<i>id</i>
<br/>
- "S-malonyltransferase, COG0300" as search text and in <i>Function Search Field</i>
select <i>Both (ID and Name)</i> will return cassette with COG Term and COG ID.
<br/>
- Name searches use RegExp *<i>name</i>*
</p>
</td>
</tr> </table>
};

    print end_form();

    #printGenomeListFilterJS();
    printStatusLine( "Loaded.", 2 );
}


sub printSearchForm3 {
    print qq{
        <h1>
        Cassette Search
        </h1>
    };

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<p>\n";

    # Use YUI css
    if ($yui_tables) {
        print <<YUI;

        <link rel="stylesheet" type="text/css"
        href="$YUI/build/datatable/assets/skins/sam/datatable.css" />

        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
        <div class='yui-dt-liner'>
            <span>Select Protein Cluster</span>
        </div>
    </th>
        <th>
        <div class='yui-dt-liner'>
            <span>Function Search Field</span>
        </div>
    </th>
        <th>
        <div class='yui-dt-liner'>
            <span>Logical Operator</span>
        </div>
    </th>
        <th>
        <div class='yui-dt-liner'>
            <span>Sort Results</span>
        </div>
    </th>

YUI
    } else {
        print qq{
          <table class='img' border=1>
          <th class='img'>Select Protein Cluster</th>
          <th class='img'>Function Search Field</th>
          <th class='img'>Logical Operator</th>
          <th class='img'>Sort Results</th>
        };
    }

    my $classStr;

    if ($yui_tables) {
        $classStr = "yui-dt-first yui-dt-odd";
    } else {
        $classStr = "img";
    }

    # radio buttons
    my $xml_url = "xml.cgi?section=$section&page=table&cluster=";

    # Select Protein Cluster
    print "<tr class='$classStr' valign='top'>\n";
    print "<td class='$classStr' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print "<input type='radio' name='cluster' value='cog' checked='checked' />";
    print "COG<br/>\n";
    if ($include_cassette_pfam) {
        print "<input type='radio' name='cluster' value='pfam' " . "/>";
        print "Pfam<br/>\n";
    }
    if ($include_cassette_bbh) {
        print "<input type='radio' name='cluster' value='bbh'" . "/>";
        print "IMG Ortholog Cluster\n";
    }
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Function Search Field
    print "<td class='$classStr' valign='top' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{
        <input type='radio' name='field' value='id' 
        title='regex search % id' checked /> Function ID<br/>
        <input type='radio' name='field' value='name' 
        title='regex search % name %' /> Function Name <br/>
        <input type='radio' name='field' value='both' /> Both (Id and Name)
    };
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Logical Operator
    print "<td class='$classStr' valign='top' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{
        <input type='radio' name='logical' value='and' checked /> And (intersection)<br/>
        <input type='radio' name='logical' value='or'  /> Or (union)
    };
    print "</div>\n" if $yui_tables;
    print "</td>\n";

    # Sort Results
    print "<td class='$classStr' valign='top' >\n";
    print "<div class='yui-dt-liner'>" if $yui_tables;
    print qq{        
        <input type='radio' name='sort' value='match' checked /> Function matches <br/>
        <input type='radio' name='sort' value='genecount'  /> Cassette gene count
    };

    print "</div>\n" if $yui_tables;
    print "</td></tr>\n";
    print "</table>\n";
    print "</div>\n" if $yui_tables;
    print "</p>\n";

    # search text delimiter is a comma?
    print qq{
        <table border='0'> <tr> <td>
        <p><b>Search Text</b> <br/>
        Use commas to separate search terms.<br/>
    <textarea name='searchtext' rows='3' cols='60' style='background-color: #FFFFFF'></textarea>
    </p>
    };


    GenomeListJSON::printHiddenInputType($section, 'runSearch');
    my $xml_cgi = $cgi_url . '/xml.cgi';
    $include_metagenomes = 0 if ( $include_metagenomes eq "" );
    my $template = HTML::Template->new( filename => "$base_dir/genomeJson.html" );
    $template->param( isolate             => 1 );
    $template->param( include_metagenomes => 0 );
    $template->param( gfr                 => 0 );
    $template->param( pla                 => 0 );
    $template->param( vir                 => 0 );
    $template->param( all                 => 1 );
    $template->param( cart                => 1 );
    $template->param( xml_cgi             => $xml_cgi );

    # TODO - for some forms show only metagenome or show only islates
    $template->param( from => $section );

    # prefix
    $template->param( prefix => '' );
    print $template->output;



        GenomeListJSON::printMySubmitButton( "", '', "Search",
                                             '', $section, 'runSearch', 'meddefbutton' );  
    print qq{
        <br/> 
    };

    print qq{
</td>
<td valign='top'>
<h3> Examples </h3>
<p>
- "COG0331, COG0300, COG0335" as search text will find cassettes with all 3 COG terms
<br/>
- Prefixes for cog and pfam are assumed, above can be shorten to "0331, 0300, 0335".
<br/>
- ID searches use RegExp *<i>id</i>
<br/>
- "S-malonyltransferase, COG0300" as search text and in <i>Function Search Field</i>
select <i>Both (ID and Name)</i> will return cassette with COG Term and COG ID.
<br/>
- Name searches use RegExp *<i>name</i>*
</p>
</td>
</tr> </table>
};

    print end_form();
    printStatusLine( "Loaded.", 2 );
}


#sub printTable {
#    my $cluster = param("cluster");
#    my $dbh     = dbLogin();
#    my $list_aref;
#
#    if ( $cluster eq "pfam" ) {
#        $list_aref = getPfamList($dbh);
#    } else {
#        $list_aref = getCogList($dbh);
#    }
#
#    #$dbh->disconnect();
#
#    printClusterTable($list_aref);
#}

sub printClusterTable {
    my ($list_aref) = @_;

    print qq{
       
        <table class='img'>
        <th class='img'>Select</th>
        <th class='img'>Id</th>
        <th class='img'>Name</th>
    };

    foreach my $line (@$list_aref) {
        my ( $id, $name ) = split( /\t/, $line );
        print "<tr class='img'>\n";

        print qq{
            <td class='img'>
            <input type='checkbox' name='func_id' value='$id' />    
            </td>
            <td class='img'>$id </td>
            <td class='img'>$name </td>
        };
        print "</tr>\n";
    }

    print "</table>\n";
}

sub searchCluster {
    my ( $dbh, $cluster, $field, $text_aref ) = @_;

    # hash of func ids found
    my %foundIds;

    # search ids
    my $sql;

    # search func names
    if ( $field eq "name" || $field eq "both" ) {
        print "Searching function names...<br/>\n";
        if ( $cluster eq "pfam" ) {
            $sql = qq{
            select ext_accession
            from pfam_family
            where lower(description) like '%' || ? || '%' escape '\\'          
            }
        } elsif ( $cluster eq "bbh" ) {
            $sql = qq{
            select cluster_id
            from bbh_cluster
            where lower(cluster_name) like '%' || ? || '%' escape '\\'   
            }
        } else {
            $sql = qq{
            select cog_id
            from cog
            where lower(cog_name) like '%' || ? || '%' escape '\\'
            };
        }
        my $cur = $dbh->prepare($sql)
          || webDie("execSqlBind: cannot preparse statement: $DBI::errstr\n");

        foreach my $x (@$text_aref) {
            my $tmp = strTrim($x);
            $tmp = lc($tmp);

            # user added special chars. % _ or \
            $tmp =~ s/\\/\\\\/g;    # replace \ with \\
            $tmp =~ s/%/\\%/g;      # replace % with \%
            $tmp =~ s/_/\\_/g;      # replace _ with \_

            $cur->bind_param( 1, $tmp )
              || webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
            $cur->execute()
              || webDie("execSqlBind: cannot execute: $DBI::errstr\n");
            for ( ; ; ) {
                my ($id) = $cur->fetchrow();
                last if ( !$id );
                $foundIds{$id} = $id;
            }

        }
        $cur->finish();
    }

    # search func ids
    if ( $field eq "id" || $field eq "both" ) {
        print "Searching function ids...<br/>\n";
        if ( $cluster eq "pfam" ) {
            $sql = qq{
            select ext_accession
            from pfam_family
            where ext_accession like '%' || ? escape '\\'            
            };
        } elsif ( $cluster eq "bbh" ) {
            $sql = qq{
            select cluster_id
            from bbh_cluster
            where cluster_id like '%' ||  ?  escape '\\'
            };
        } else {
            $sql = qq{
            select cog_id
            from cog
            where cog_id like '%' || ?  escape '\\'
            };
        }
        my $cur = $dbh->prepare($sql)
          || webDie("execSqlBind: cannot preparse statement: $DBI::errstr\n");

        webLog("$sql \n");

        foreach my $x (@$text_aref) {
            my $tmp = strTrim($x);
            $tmp = uc($tmp) if ( $cluster eq "cog" );
            $tmp = lc($tmp) if ( $cluster eq "pfam" );

            # user added special chars. % _ or \
            $tmp =~ s/\\/\\\\/g;    # replace \ with \\
            $tmp =~ s/%/\\%/g;      # replace % with \%
            $tmp =~ s/_/\\_/g;      # replace _ with \_

            $cur->bind_param( 1, $tmp )
              || webDie("execSqlBind: cannot bind param: $DBI::errstr\n");

            webLog("bind $tmp \n");

            $cur->execute()
              || webDie("execSqlBind: cannot execute: $DBI::errstr\n");
            for ( ; ; ) {
                my ($id) = $cur->fetchrow();
                last if ( !$id );
                $foundIds{$id} = $id;
            }
        }
        $cur->finish();
    }

    return \%foundIds;
}

# TODO - slow todo the filtering here - find a better way to do filtering
# find all the cassettes with the found functions
sub searchCassette {
    my ( $dbh, $cluster, $funcsIds_href, $searchTerms_aref, $field, $logical ) =
      @_;

    my @taxonSelections = param('genomeFilterSelections'); #OracleUtil::processTaxonSelectionParam("genomeFilterSelections");

    #print "searchCassette \@taxonSelections: @taxonSelections\n";
    my $taxon_filter_oid_str = '';
    my $taxonClause = '';
    my $taxonFrom   = '';
    if ( scalar(@taxonSelections) > 0 ) {
        $taxonFrom   = "  ";
        $taxonClause = "  ";

        $taxon_filter_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @taxonSelections );
        $taxonClause .= " and gc.taxon in( $taxon_filter_oid_str )  ";

    } else {
        $taxonFrom   = "  ";
        $taxonClause = "  ";
        my $insql = OracleUtil::getTaxonInClause();
        if ( $insql ne "" ) {
            $taxonClause .= " and gc.taxon in ($insql) ";
        }
        my $taxonChoice = param("taxonChoice");

        #print "$taxonChoice<br/>\n";
        if ( $taxonChoice ne "All" ) {
            my $txsClause = txsClause( "gc.taxon", $dbh );
            $taxonClause .= " $txsClause ";
        }

    }

    my $urClause = urClause("gc.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('gc.taxon');

    #print "<h5>searchCassette \$taxonClause: $taxonClause</h5>";

    # create batch
    # array of array ids max size 1000
    #my @batch;
    #my $count = 0;
    my @idlist;
    foreach my $id ( keys %$funcsIds_href ) {

        #        if ( $count >= $BATCH_SIZE ) {
        #            $count = 0;
        #            my @tmp = @idlist;    # we need store a new array
        #            push( @batch, \@tmp );
        #            @idlist = ();
        #        }
        push( @idlist, $id );

        #$count++;
    }

    #push( @batch, \@idlist );
    
    my $sqlFunc = qq{
select cog_id, cog_name from cog
    };
    if($cluster eq "pfam") {
$sqlFunc = qq{
select ext_accession, description from pfam_family
    };        
    }
    my %funcIdToName;
    my $cur = execSql( $dbh, $sqlFunc, 1 );
    for ( ; ; ) {
        my ( $id, $funcname ) = $cur->fetchrow();
        last if ( !$id );
        $funcIdToName{$id} = $funcname;
    }
    

    # search cassettes
    my $sql_base;
    if ( $cluster eq "pfam" ) {
        $sql_base = qq{
        select distinct gcg.cassette_oid, gc.pfam_family
        from gene_cassette_genes gcg, gene_pfam_families gc
        $taxonFrom
        where gcg.gene = gc.gene_oid
        $taxonClause
        $urClause
        and gc.pfam_family in (            
        };
#    } elsif ( $cluster eq "bbh" ) {
#        $sql_base = qq{
#        select distinct gcg.cassette_oid, gc.cluster_id, c.cluster_name
#        from gene_cassette_genes gcg, bbh_cluster_member_genes gc, bbh_cluster c
#        $taxonFrom
#        where gcg.gene = gc.member_genes
#        and gc.cluster_id = c.cluster_id
#        $taxonClause
#        $urClause
#        and gc.cluster_id in (
#        };
    } else {
        $sql_base = qq{
        select distinct gcg.cassette_oid, gc.cog
        from gene_cassette_genes gcg, gene_cog_groups gc
        $taxonFrom
        where gcg.gene = gc.gene_oid
        $taxonClause
        $urClause
        and gc.cog in (
        };
    }

    #print "<h5>searchCassette \$sql_base: $sql_base</h5>";

    # hash of hashes cassette id => hash of func ids found
    my %foundIds;

    # go thru the batch
    #    foreach my $aref (@batch) {
    print "Searching for Cassette IDs...<br/>\n";

    #my $size = $#$aref + 1;
    my $sql = $sql_base;

    #        for ( my $i = 0 ; $i < $size ; $i++ ) {
    #            $sql .= "'" . $aref->[$i] . "'";
    #            if ( $i < ( $size - 1 ) ) {
    #                $sql .= ",";
    #            }
    #        }

    my $str = OracleUtil::getFuncIdsInClause( $dbh, @idlist );
    $sql .= " $str ) ";
    #print "<h5>searchCassette \$sql: $sql</h5>";
    #webLog("searchCassette \$sql: $sql");

    my $cur = execSql( $dbh, $sql, 1 );
    for ( ; ; ) {
        my ( $cid, $funcid ) = $cur->fetchrow();
        last if ( !$cid );
        
        my $funcname = $funcIdToName{$funcid};
        
        if ( exists $foundIds{$cid} ) {
            my $href = $foundIds{$cid};
            $href->{$funcid} = $funcname;
        } else {
            my %hash = ( $funcid => $funcname );
            $foundIds{$cid} = \%hash;
        }
    }
    $cur->finish();

    #    }

    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $taxon_filter_oid_str =~ /gtt_num_id/i );
    OracleUtil::truncTable( $dbh, "gtt_func_id" )
        if ( $str =~ /gtt_func_id/i );

    # TODO logical AND filter
    if ( $logical eq "and" ) {

        foreach my $cid ( keys %foundIds ) {
            my $func_href = $foundIds{$cid};

            # for OR we do nothing, since its a union
            # but here for AND intersectio, id, or name
            # if both, then ither id or name match in one row is good
            if ( $field eq "id" ) {

                my $key_str;
                foreach my $key ( keys %$func_href ) {
                    $key_str .= lc($key) . " ";
                }

                foreach my $term (@$searchTerms_aref) {
                    my $tmp = strTrim($term);
                    $tmp = lc($tmp);
                    if ( $key_str !~ /$tmp/ ) {

                        # no match
                        # set to  ""
                        $foundIds{$cid} = "";
                        last;
                    }
                }
            } elsif ( $field eq "name" ) {

                my $name_str;
                foreach my $key ( keys %$func_href ) {
                    my $name = $func_href->{$key};
                    $name = lc($name);
                    $name_str .= lc($name) . " ";
                }

                foreach my $term (@$searchTerms_aref) {
                    my $tmp = strTrim($term);
                    $tmp = lc($tmp);
                    if ( $name_str !~ /$tmp/ ) {

                        # no match
                        # set to  ""
                        $foundIds{$cid} = "";
                        last;
                    }
                }

            } else {

                # both either the name or id matches for this row is ok
                # but if not found in either id or name eject
                my $key_str;
                my $name_str;
                foreach my $key ( keys %$func_href ) {
                    $key_str .= lc($key) . " ";
                    my $name = $func_href->{$key};
                    $name = lc($name);
                    $name_str .= lc($name) . " ";
                }

                foreach my $term (@$searchTerms_aref) {
                    my $tmp = strTrim($term);
                    $tmp = lc($tmp);
                    if ( $name_str !~ /$tmp/ && $key_str !~ /$tmp/ ) {

                        # no match
                        # set to  ""
                        $foundIds{$cid} = "";
                        last;
                    }
                }
            }
        }

    }

    # hash of hashes cassette id => hash of func ids found
    my %result;
    foreach my $cid ( keys %foundIds ) {
        if ( $foundIds{$cid} ne "" ) {
            $result{$cid} = $foundIds{$cid};
        }
    }

    return \%result;
}

sub getCassetteGeneCnt {
    my ( $dbh, $cassetteIds_href ) = @_;

    # create batch
    # array of array ids max size 1000
    #my @batch;
    #my $count = 0;
    my @idlist;
    foreach my $id ( keys %$cassetteIds_href ) {

        #        if ( $count >= $BATCH_SIZE ) {
        #            $count = 0;
        #            my @tmp = @idlist;    # we need store a new array
        #            push( @batch, \@tmp );
        #            @idlist = ();
        #        }
        push( @idlist, $id );

        #        $count++;
    }

    #push( @batch, \@idlist );

    # search cassettes
    my $sql_base;
    $sql_base = qq{
        select gcg.cassette_oid, count(gcg.gene)
        from gene_cassette_genes gcg
        where gcg.cassette_oid in (            
        };
    my $sql_end = "group by gcg.cassette_oid";

    # hash cassette id => gene count
    my %foundIds;

    # go thru the batch
    #    foreach my $aref (@batch) {
    print "Getting gene count ...<br/>\n";

    #my $size = $#$aref + 1;
    my $sql = $sql_base;

    #        for ( my $i = 0 ; $i < $size ; $i++ ) {
    #            $sql .= $aref->[$i];
    #            if ( $i < ( $size - 1 ) ) {
    #                $sql .= ",";
    #            }
    #        }

    my $str = OracleUtil::getNumberIdsInClause( $dbh, @idlist );
    $sql .= " $str ) $sql_end";

    my $cur = execSql( $dbh, $sql, 1 );
    for ( ; ; ) {
        my ( $cid, $count ) = $cur->fetchrow();
        last if ( !$cid );
        $foundIds{$cid} = $count;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) if ( $str =~ /gtt_num_id/i );

    #    }
    return \%foundIds;
}

sub getCassetteGenome {
    my ( $dbh, $cassetteIds_href ) = @_;

    # create batch
    # array of array ids max size 1000
    #    my @batch;
    #    my $count = 0;
    my @idlist;
    foreach my $id ( keys %$cassetteIds_href ) {

        #        if ( $count >= $BATCH_SIZE ) {
        #            $count = 0;
        #            my @tmp = @idlist;    # we need store a new array
        #            push( @batch, \@tmp );
        #            @idlist = ();
        #        }
        push( @idlist, $id );

        #        $count++;
    }

    #    push( @batch, \@idlist );

    # search cassettes
    my $sql_base;
    $sql_base = qq{
        select gc.cassette_oid, t.taxon_display_name, t.taxon_oid
        from gene_cassette gc, taxon t
        where gc.taxon = t.taxon_oid
        and gc.cassette_oid in (            
        };

    # hash cassette id => taxon name
    my %foundIds;

    # go thru the batch
    #    foreach my $aref (@batch) {
    print "Getting genome names ...<br/>\n";

    #my $size = $#$aref + 1;
    my $sql = $sql_base;

    #        for ( my $i = 0 ; $i < $size ; $i++ ) {
    #            $sql .= $aref->[$i];
    #            if ( $i < ( $size - 1 ) ) {
    #                $sql .= ",";
    #            }
    #        }

    my $str = OracleUtil::getNumberIdsInClause( $dbh, @idlist );
    $sql .= " $str ) ";

    my $cur = execSql( $dbh, $sql, 1 );
    for ( ; ; ) {
        my ( $cid, $name, $oid ) = $cur->fetchrow();
        last if ( !$cid );
        $foundIds{$cid} = "$name\t$oid";
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) if ( $str =~ /gtt_num_id/i );

    #    }
    return \%foundIds;
}

#sub getCogList {
#    my ($dbh) = @_;
#
#    my $sql = qq{
#    select cog_id, cog_name
#    from cog
#    where cog_name not like 'Uncharacterized%'
#    };
#
#    # list of cog id \t cog name
#    my @list;
#    my $cur = execSql( $dbh, $sql, 1 );
#    for ( ; ; ) {
#        my ( $id, $name ) = $cur->fetchrow();
#        last if ( !$id );
#
#        push( @list, "$id\t$name" );
#    }
#    $cur->finish();
#
#    return \@list;
#}
#
#sub getPfamList {
#    my ($dbh) = @_;
#
#    my $sql = qq{
#    select ext_accession, description
#    from pfam_family
#    };
#
#    # list of cog id \t cog name
#    my @list;
#    my $cur = execSql( $dbh, $sql, 1 );
#    for ( ; ; ) {
#        my ( $id, $name ) = $cur->fetchrow();
#        last if ( !$id );
#
#        push( @list, "$id\t$name" );
#    }
#    $cur->finish();
#
#    return \@list;
#}

# cache found ids
# hash of func ids found
# func id => func id
#
sub cacheFoundFuncIds {
    my ($href) = @_;

    # add session id
    my $sid       = getSessionId();
    my $cacheFile = "cassettesearch1" . $sid . "$$";
    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $res       = newWriteFileHandle( $cachePath, "cassettesearch" );

    foreach my $key ( keys %$href ) {
        my $value = $href->{$key};
        print $res $key;
        print $res "\t";
        print $res $value;
        print $res "\n";
    }
    close $res;
    return $cacheFile;
}

# hash of hashes cassette id => hash of func ids found
#
sub cacheFoundCassette {
    my ($href) = @_;

    # add session id
    my $sid       = getSessionId();
    my $cacheFile = "cassettesearch2" . $sid . "$$";
    my $cachePath = "$cgi_tmp_dir/$cacheFile";

    my $res = newWriteFileHandle( $cachePath, "cassettesearch" );

    foreach my $key ( keys %$href ) {
        my $func_href = $href->{$key};
        foreach my $id ( keys %$func_href ) {
            my $value = $func_href->{$id};
            print $res $key;
            print $res "\t";
            print $res $id;
            print $res "\t";
            print $res $value;
            print $res "\n";
        }
    }
    close $res;
    return $cacheFile;
}

sub cacheArray {
    my ($aref) = @_;

    # add session id
    my $sid       = getSessionId();
    my $cacheFile = "cassettesearch3" . $sid . "$$";
    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    my $res       = newWriteFileHandle( $cachePath, "cassettesearch" );

    foreach my $line (@$aref) {
        print $res $line;
        print $res "\n";
    }
    close $res;
    return $cacheFile;
}

# reads founf function ids
# return hash func id => func id
sub readFoundFuncIds {
    my ($cacheFile) = @_;
    my %hash;
    $cacheFile = WebUtil::checkFileName($cacheFile);
    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    WebUtil::fileTouch($cachePath);
    my $res = newReadFileHandle( $cachePath, "runJob" );

    while ( my $line = $res->getline() ) {
        chomp $line;
        my @tmp = split( /\t/, $line );
        $hash{ $tmp[0] } = $tmp[1];
    }
    close $res;
    return \%hash;
}

sub readFoundCassette {
    my ($cacheFile) = @_;
    my %hash;
    $cacheFile = WebUtil::checkFileName($cacheFile);
    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    WebUtil::fileTouch($cachePath);
    my $res = newReadFileHandle( $cachePath, "runJob" );

    while ( my $line = $res->getline() ) {
        chomp $line;
        my ( $cid, $funcid, $value ) = split( /\t/, $line );
        if ( exists $hash{$cid} ) {
            my $href = $hash{$cid};
            $href->{$funcid} = $value;
        } else {
            my %fhash = ( $funcid => $value );
            $hash{$cid} = \%fhash;
        }
    }
    close $res;
    return \%hash;
}

sub readArray {
    my ($cacheFile) = @_;
    my @a;
    $cacheFile = WebUtil::checkFileName($cacheFile);
    my $cachePath = "$cgi_tmp_dir/$cacheFile";
    WebUtil::fileTouch($cachePath);
    my $res = newReadFileHandle( $cachePath, "runJob" );

    while ( my $line = $res->getline() ) {
        chomp $line;
        push( @a, $line );
    }
    close $res;
    return \@a;
}

sub printJS {

    print qq{
        <script type="text/javascript" src="$base_url/treeFile.js" ></script>
<script type="text/javascript" src="$YUI/build/yahoo/yahoo-min.js"></script>
<script type="text/javascript" src="$YUI/build/event/event-min.js"></script>
<script type="text/javascript" src="$YUI/build/connection/connection-min.js"></script>
    };

}
1;
