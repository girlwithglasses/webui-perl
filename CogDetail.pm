############################################################################
# CogDetail.pm - Show category detail for a COG.
############################################################################
package CogDetail;

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use CachedTable;
use WebConfig;
use WebUtil;
use HtmlUtil;
use PhyloTreeMgr;
use TabHTML;
## use MetaUtil;
## use MetaGeneTable;
## use MerFsUtil;
use WorkspaceUtil;
use TreeFile;

my $section              = "CogDetail";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $img_internal         = $env->{img_internal};
my $tmp_dir              = $env->{tmp_dir};
my $max_gene_batch       = 100;
my $max_taxon_batch      = 20;
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $cog_base_url         = $env->{cog_base_url};
my $kog_base_url         = $env->{kog_base_url};
my $show_private         = $env->{show_private};
my $new_func_count       = $env->{new_func_count};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( !$merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
}

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
##    timeout( 60 * $merfs_timeout_mins );

    my $page = param("page");
    HtmlUtil::cgiCacheInitialize( $section );
    HtmlUtil::cgiCacheStart() or return;

    if ( $page eq "cogDetail" ) {
        printCogDetail();
    }
    elsif ( $page eq "showCogTaxonTable" ) {
        printCogTaxonTable();
    }
    elsif ( $page eq "showCogTaxonTree" ) {
        printCogTaxonTree();
    }
#    else {
#        printCogCategoryDetail();
#    }

    HtmlUtil::cgiCacheStop();
}


############################################################################
# printCogDetail - Show detail page for COG
############################################################################
sub printCogDetail {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $id_name = $og . "_id";
    my $func_id = param($id_name);

    printMainForm();
    print "<h1>${OG} Detail</h1>\n";

    my $dbh = dbLogin();

    my %allCogs;
    my $sql = qq{
        select c.${og}_id, c.${og}_name, c.description,
               c.db_source, c.add_date, c.seq_length
        from ${og} c
        where c.${og}_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $func_id );
    my ($cog_id, $cog_name, $desc, $db_source, $add_date, $seq_length) 
	= $cur->fetchrow();
    $cur->finish();

    print "<h3>$cog_id: " . WebUtil::escHtml($cog_name) . "</h3>\n";

    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "DB Source", WebUtil::escHtml($db_source) );
    printAttrRowRaw( "Add Date", $add_date );
    printAttrRowRaw( "Seq Length", $seq_length );

    $sql = qq{
        select cfs.${og}_id, cf.function_code, cf.definition,
               cf.function_group
        from ${og}_function cf, ${og}_functions cfs
        where cfs.${og}_id = ?
        and cfs.functions = cf.function_code
    };
    $cur = execSql( $dbh, $sql, $verbose, $func_id );
    for (;;) {
	my ($c_id, $func_code, $def, $func_grp)
	    = $cur->fetchrow();
	last if ! $c_id;

	if ( $func_code ) {
	    printAttrRowRaw( "Function Code", $func_code );
	}
	if ( $def ) {
	    printAttrRowRaw( "Definition", $def );
	}
	if ( $func_grp ) {
	    printAttrRowRaw( "Function Group", $func_grp );
	}
    }
    $cur->finish();

    print "</table>\n";

    my @bind = ( $func_id );
    my $level = 0;
    my @phylo_label = ( 'Domain', 'Phylum', 'Class', 'Order', 
			'Family', 'Genus', 'Species');
    my @eco_label = ( 'Domain', 'Ecosystem', 'Ecosystem Category', 
		      'Ecosystem Type', 'Ecosystem Subtype', 
		      'Specific Ecosystem', 'Species');
    my @phylo_level = ( 'domain', 'phylum', 'ir_class', 'ir_order', 'family', 'genus', 'species');

    my $level = 0;
    my $additional_cond = "";
    my $url_cond = "";
    my $phylo_str = "";
    my $curr_domain = "";
    for my $x ( @phylo_level ) {
	my $str = param($x);
	if ( ! $str ) {
	    last;
	}
	if ( $x eq 'domain' ) {
	    $curr_domain = $str;
	}

	if ( $phylo_str ) {
	    $phylo_str .= ";" . $str;
	}
	else {
	    $phylo_str = $str;
	}

	$url_cond .= "&$x=$str";

	if ( lc($str) eq 'unclassified' ) {
	    $additional_cond .= " and (t.$x = ? or t.$x is null)";
	}
	else {
	    $additional_cond .= " and t.$x = ?";
	}
	push @bind, ( $str );
	$level++;
    }

    print "<h2>$phylo_str</h2>\n";
    my $next_level = $phylo_level[$level];
    my $next_label = $phylo_label[$level];
    if ( $curr_domain eq '*Microbiome' ) {
	$next_label = $eco_label[$level];
    }
    my $next_label_lc = lc($next_label);

    my %taxon_cnts;
    my %gene_cnts;
    printStartWorkingDiv();

    print "<p>Counting isolate genomes ...\n";

    my $taxonClause = WebUtil::txsClause( "t.taxon_oid", $dbh );
    my $rclause = WebUtil::urClause( "t.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "t.taxon_oid", 1 );
    $sql = qq{
        select nvl(t.$next_level, 'unclassified'),
               count(distinct t.taxon_oid), 
               sum(g.gene_count)
        from taxon t, 
             mv_taxon_${og}_stat g
        where g.${og} = ?
        and t.taxon_oid = g.taxon_oid
        $additional_cond
        $taxonClause
        $rclause
        $imgClause
        group by nvl(t.$next_level, 'unclassified')
    };
    $cur = execSql( $dbh, $sql, $verbose, @bind );
    for ( ; ; ) {
        my ( $t_domain, $t_cnt, $g_cnt ) = 
	    $cur->fetchrow();
        last if ! $t_domain;
        $taxon_cnts{$t_domain} = $t_cnt;
        $gene_cnts{$t_domain} = $g_cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $sql = qq{
            select nvl(t.$next_level, 'unclassified'),
                   count(distinct t.taxon_oid),
                   sum(g.gene_count)
            from taxon t, 
                 mv_taxon_${og}_stat g
            where g.${og} = ?
            and t.taxon_oid = g.taxon_oid
            $additional_cond
            $taxonClause
            $rclause
            $imgClause
            group by nvl(t.$next_level, 'unclassified')
        };

        $cur = execSql( $dbh, $sql, $verbose, @bind );
        for ( ; ; ) {
            my ( $t_domain, $t_cnt, $g_cnt ) = 
		$cur->fetchrow();
            last if !$t_domain; 
	    if ( $taxon_cnts{$t_domain} ) {
		$taxon_cnts{$t_domain} += $t_cnt;
	    }
	    else {
		$taxon_cnts{$t_domain} = $t_cnt;
	    }
	    if ( $gene_cnts{$t_domain} ) {
		$gene_cnts{$t_domain} += $g_cnt;
	    }
	    else {
		$gene_cnts{$t_domain} = $g_cnt;
	    }
	}
        $cur->finish();

        if ( $og eq 'cog' ) {
            print "<p>Counting metagenome genes ...\n";

	    my $rclause2 = WebUtil::urClause('f.taxon_oid'); 
	    my $imgClause2 = WebUtil::imgClauseNoTaxon('f.taxon_oid', 2); 
	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );
 
	    $sql = qq{
                        select nvl(t.$next_level, 'unclassified'),
                               count(distinct t.taxon_oid),
                               sum(f.gene_count)
                        from taxon t, taxon_cog_count f
                        where f.gene_count > 0
                        and f.func_id = ?
                        $additional_cond
                        and t.taxon_oid = f.taxon_oid
                        $rclause2
                        $imgClause2
                        $taxonClause2
                        group by nvl(t.$next_level, 'unclassified')
                    }; 
 
	    $cur = execSql( $dbh, $sql, $verbose, @bind ); 
	    for (;;) {
		my ( $t_domain, $t_cnt, $g_cnt ) = 
		    $cur->fetchrow();
		last if ! $t_domain;

		if ( $taxon_cnts{$t_domain} ) {
		    $taxon_cnts{$t_domain} += $t_cnt;
		}
		else {
		    $taxon_cnts{$t_domain} = $t_cnt;
		}
		if ( $gene_cnts{$t_domain} ) {
		    $gene_cnts{$t_domain} += $g_cnt;
		}
		else {
		    $gene_cnts{$t_domain} = $g_cnt;
		}
	    }
	    $cur->finish(); 
	    print "<br/>\n"; 
	}
    }

    printEndWorkingDiv();

    my $tbl_img_link = "<img src=$base_url/images/application-table.png width=11 height=11 border=0 alt=table</img>"; 
 
    my $text2 = "";
    if ( $next_label_lc && $next_label_lc ne 'species' &&
	$next_label_lc ne 'specific ecosystem' ) {
	$text2 = "Click on $next_label_lc to see function distribution of selected $next_label_lc. ";
    }
    $text2 .= "Follow the link provided by <b>Genome Count</b> to genomes having genes associated with this function. Click on the number to view the results in phylo tree display, or click on the rectangular table symbol to view the results in table display. (Note: Phylo Tree display option is limited to certain domains only.)"; 
#    print "<p>$text2\n";
    printHint($text2);

    my $baseUrl = "$section_cgi&page=cogDetail";
    $baseUrl .= "&func_id=$func_id";

    printMainForm(); 
    my $it = new InnerTable( 1, "cogdomaincount$$", "cogdomaincount", 0 );
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( $next_label,           "asc", "left" );
    $it->addColSpec( "Genome Count",    "asc", "right" );
    $it->addColSpec( "Gene Count", "asc", "right" ); 

    my @keys = keys(%taxon_cnts);
    for my $key ( @keys ) {
	my $t_cnt = $taxon_cnts{$key};
	my $g_cnt = $gene_cnts{$key};

	my $url2 = $key;
	if ( $next_level ne 'species' &&
	     $next_label_lc ne 'specific ecosystem' ) {
	    $url2 = 
		"$main_cgi?section=CogDetail"
		. "&page=cogDetail"
		. "&cog_id=$func_id"
		. $url_cond
		. "&$next_level=$key";
	    $url2 = alink( $url2, $key );
	}
        my $r = $key . $sd . $url2 . "\t";
	if ( $t_cnt ) {
	    ## count and phylo tree link
	    my $url3 = 
		"$main_cgi?section=CogDetail"
		. "&page=showCogTaxonTree"
		. "&cog_id=$func_id"
		. $url_cond
		. "&$next_level=$key";
	    $url3 = alink( $url3, $t_cnt );

	    my $y = $curr_domain;
	    if ( ! $y ) {
		$y = $key;
	    }
	    if ( $y eq 'Archaea' ||
		 $y eq 'Bacteria' ||
		 $y eq 'Eukaryota' ||
		 $y eq '*Microbiome' ) {
		$r .= $t_cnt . $sd . $url3;
	    }
	    else {
		$r .= $t_cnt . $sd . $t_cnt;
	    }

	    ## image for table display
	    my $tbl_link .= "<a href='" . url() .
		"?section=CogDetail&page=showCogTaxonTable" .
		"&cog_id=$func_id" . $url_cond .
		"&$next_level=$key" .
		"' >";
	    $tbl_link .= "<img src='$base_url/images/application-table.png' width='11' height='11' border='0' alt='table' /> ";
	    $tbl_link .= "</a>";
	    $r .= " " . $tbl_link; 
	    $r .= "\t";
	}
	else {
	    $r .= "0" . $sd . "0\t";
	}
	$r .= $g_cnt . $sd . "$g_cnt\t";

#        $url = "$main_cgi?section=CogCategoryDetail" 
#            . "&page=ccdCOGGenomeGeneList&cog_id=$func_id&taxon_oid=$taxon_oid";
#	$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";

        $it->addRow($r);
    }
    $cur->finish();
    
    $it->printTable();

    print end_form();
}


############################################################################
# printCogDetail_old - Show detail page for COG
############################################################################
sub printCogDetail_old {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $id_name = $og . "_id";
    my $func_id = param($id_name);

    printMainForm();
    print "<h1>${OG} Detail</h1>\n";

    my $dbh = dbLogin();

    my %allCogs;
    my $sql = qq{
        select c.${og}_id, c.${og}_name, c.description,
               c.db_source, c.add_date, c.seq_length
        from ${og} c
        where c.${og}_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $func_id );
    my ($cog_id, $cog_name, $desc, $db_source, $add_date, $seq_length) 
	= $cur->fetchrow();
    $cur->finish();

    print "<h3>$cog_id: " . WebUtil::escHtml($cog_name) . "</h3>\n";

    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "DB Source", WebUtil::escHtml($db_source) );
    printAttrRowRaw( "Add Date", $add_date );
    printAttrRowRaw( "Seq Length", $seq_length );

    $sql = qq{
        select cfs.${og}_id, cf.function_code, cf.definition,
               cf.function_group
        from ${og}_function cf, ${og}_functions cfs
        where cfs.${og}_id = ?
        and cfs.functions = cf.function_code
    };
    $cur = execSql( $dbh, $sql, $verbose, $func_id );
    for (;;) {
	my ($c_id, $func_code, $def, $func_grp)
	    = $cur->fetchrow();
	last if ! $c_id;

	if ( $func_code ) {
	    printAttrRowRaw( "Function Code", $func_code );
	}
	if ( $def ) {
	    printAttrRowRaw( "Definition", $def );
	}
	if ( $func_grp ) {
	    printAttrRowRaw( "Function Group", $func_grp );
	}
    }
    $cur->finish();

    print "</table>\n";

    my %cog_cnts;
    my %m_cog_cnts;
    my %taxon_name_h;

    printStartWorkingDiv();

    print "<p>Counting isolate genomes ...\n";

    my $taxonClause = WebUtil::txsClause( "t.taxon_oid", $dbh );
    my $rclause = WebUtil::urClause( "t.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "t.taxon_oid", 1 );
    $sql = qq{
        select t.taxon_oid, t.domain, t.seq_status,
               t.taxon_display_name, g.gene_count
        from taxon t, 
             mv_taxon_${og}_stat g
        where g.${og} = ?
        and t.taxon_oid = g.taxon_oid
        $taxonClause
        $rclause
        $imgClause
    };
    $cur = execSql( $dbh, $sql, $verbose, $func_id );
    for ( ; ; ) {
        my ( $t_id, $t_domain, $seq_status, $t_name, $cnt ) = 
	    $cur->fetchrow();
        last if ! $t_id;
        $cog_cnts{$t_id} = $cnt;
	$taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $sql = qq{
            select t.taxon_oid, t.domain, t.seq_status,
                   t.taxon_display_name, g.gene_count
            from taxon t, 
                 mv_taxon_${og}_stat g
            where g.${og} = ?
            and t.taxon_oid = g.taxon_oid
            $taxonClause
            $rclause
            $imgClause
        };

        $cur = execSql( $dbh, $sql, $verbose, $func_id );
        for ( ; ; ) {
            my ( $t_id, $t_domain, $seq_status, $t_name, $cnt ) = 
		$cur->fetchrow();
            last if !$t_id;
            $m_cog_cnts{$cog_id} = $cnt;
	    $taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
        }
        $cur->finish();

        if ( $og eq 'cog' ) {
            print "<p>Counting metagenome genes ...\n";

	    my $rclause2 = WebUtil::urClause('f.taxon_oid'); 
	    my $imgClause2 = WebUtil::imgClauseNoTaxon('f.taxon_oid', 2); 
	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );
 
	    $sql = qq{
                        select t.taxon_oid, t.domain, t.seq_status,
                               t.taxon_display_name,
                               f.data_type, f.gene_count
                        from taxon t, taxon_cog_count f
                        where f.gene_count > 0
                        and f.func_id = ?
                        and t.taxon_oid = f.taxon_oid
                        $rclause2
                        $imgClause2
                        $taxonClause2
                    }; 
 
	    $cur = execSql( $dbh, $sql, $verbose, $cog_id ); 
	    for (;;) {
		my ( $t_id, $t_domain, $seq_status, $t_name, $d_type, $cnt ) = 
		    $cur->fetchrow();
		last if ! $t_id;

		if ( $m_cog_cnts{$t_id} ) {
		    $m_cog_cnts{$t_id} += $cnt; 
		} 
		else { 
		    $m_cog_cnts{$t_id} = $cnt;
		} 
		$taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
	    }
	    $cur->finish(); 
	    print "<br/>\n"; 
	}
    }

    printEndWorkingDiv();

    my $baseUrl = "$section_cgi&page=cogDetail";
    $baseUrl .= "&func_id=$func_id";

    my $hasIsolates = scalar (keys %cog_cnts) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_cog_cnts) > 0 ? 1 : 0;

    my $cachedTable =
	new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 1 );
    my $sdDelim = $cachedTable->getSdDelim();
    $cachedTable->addColSpec( "Select" );
    $cachedTable->addColSpec( "Domain",   "asc", "left" );
    $cachedTable->addColSpec( "Status",   "asc", "left" );
    $cachedTable->addColSpec( "Taxon Name", "asc", "left" );
    $cachedTable->addColSpec("Gene Count", "desc", "right");

##    my $select_id_name = "taxon_oid";
    my $select_id_name = "taxon_filter_oid";
    my $count = 0;
    foreach my $taxon_oid ( keys %taxon_name_h ) {
        my $cnt = $cog_cnts{$taxon_oid};
        if ($include_metagenomes && $m_cog_cnts{$taxon_oid} ) {
	    $cnt = $m_cog_cnts{$taxon_oid};
	}
	if ( ! $cnt ) {
	    next;
	}

        my ($domain, $seq_status, $taxon_name) = 
	    split (/\t/, $taxon_name_h{$taxon_oid});
	$domain = substr($domain, 0, 1);
	$seq_status = substr($seq_status, 0, 1);
        $count++;

        my $r = $sdDelim
	. "<input type='checkbox' name='$select_id_name' value='$taxon_oid' />\t";
        my $url = "$main_cgi?section=TaxonDetail" 
            . "&page=taxonDetail&taxon_oid=$taxon_oid";

        $r .= "$domain\t";
	$r .= "$seq_status\t";
        $r .= "$taxon_name" . $sdDelim . alink( $url, $taxon_name ) . "\t";


        $url = "$main_cgi?section=CogCategoryDetail" 
            . "&page=ccdCOGGenomeGeneList&cog_id=$func_id&taxon_oid=$taxon_oid";
	$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";

        $cachedTable->addRow($r);
    }
    $cur->finish();
    
    if ( $count == 0 ) {
        #$dbh->disconnect();
        print "<div id='message'>\n";
        print "<p>\n";
        print "No ${OG}s found for current genome selections.\n";
        print "</p>\n";
        print "</div>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    #$dbh->disconnect();

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n"; 

    TabHTML::printTabAPILinks("cogDetailTab"); 
    my @tabIndex = ( "#cogtab1", "#cogtab2" );
    my @tabNames = ( "Genomes", "Phylo Tree" );
 
    TabHTML::printTabDiv("cogDetailTab", \@tabIndex, \@tabNames);
 
    for my $t ( @tabIndex ) { 
        my $tab = substr($t, 1, length($t) - 1); 
        print "<div id='$tab'>"; 
        if ( $tab eq 'cogtab1' ) {
	    WebUtil::printGenomeCartFooter() if $count > 10;
	    $cachedTable->printTable();
	    WebUtil::printGenomeCartFooter();
        } 
        else {
	    my $mgr = new PhyloTreeMgr();
	    my %taxon_filter;
	    my $taxon_filter_cnt = 0;
	    foreach my $taxon_oid ( keys %taxon_name_h ) {
		my $cnt = $cog_cnts{$taxon_oid};
		if ($include_metagenomes && $m_cog_cnts{$taxon_oid} ) {
		    $cnt = $m_cog_cnts{$taxon_oid};
		}
		if ( ! $cnt ) {
		    next;
		}
		$taxon_filter{$taxon_oid} = $cnt;
		$taxon_filter_cnt++;
	    }

	    my $url3 = "$main_cgi?section=CogCategoryDetail" 
		. "&page=ccdCOGGenomeGeneList&cog_id=";

	    $mgr->loadFuncTree( $dbh, \%taxon_filter, 0 );
	    WebUtil::printTaxonButtons ();
	    $mgr->printFuncTree( \%taxon_filter, $taxon_filter_cnt, $url3, 0);

	    if ($taxon_filter_cnt > 0) { 
		WebUtil::printTaxonButtons ();
	    } 
	}
        print "</div>\n"; 
    } 

##    printHint("The function cart allows for phylogenetic profile comparisons.");

    if ($count > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}


############################################################################
# printCogTaxonTable
############################################################################
sub printCogTaxonTable {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $id_name = $og . "_id";
    my $func_id = param($id_name);

    printMainForm();
    print "<h1>${OG} Detail</h1>\n";

    my $dbh = dbLogin();

    my %allCogs;
    my $sql = qq{
        select c.${og}_id, c.${og}_name, c.description,
               c.db_source, c.add_date, c.seq_length
        from ${og} c
        where c.${og}_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $func_id );
    my ($cog_id, $cog_name, $desc, $db_source, $add_date, $seq_length) 
	= $cur->fetchrow();
    $cur->finish();

    print "<h3>$cog_id: " . WebUtil::escHtml($cog_name) . "</h3>\n";

    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "DB Source", WebUtil::escHtml($db_source) );
    printAttrRowRaw( "Add Date", $add_date );
    printAttrRowRaw( "Seq Length", $seq_length );

    $sql = qq{
        select cfs.${og}_id, cf.function_code, cf.definition,
               cf.function_group
        from ${og}_function cf, ${og}_functions cfs
        where cfs.${og}_id = ?
        and cfs.functions = cf.function_code
    };
    $cur = execSql( $dbh, $sql, $verbose, $func_id );
    for (;;) {
	my ($c_id, $func_code, $def, $func_grp)
	    = $cur->fetchrow();
	last if ! $c_id;

	if ( $func_code ) {
	    printAttrRowRaw( "Function Code", $func_code );
	}
	if ( $def ) {
	    printAttrRowRaw( "Definition", $def );
	}
	if ( $func_grp ) {
	    printAttrRowRaw( "Function Group", $func_grp );
	}
    }
    $cur->finish();

    print "</table>\n";

    my $domain = param('domain');
    my $phylo_cond = "and t.domain = ?";
    my @bind = ($func_id, $domain);
    my @phylo_flds = ('phylum', 'ir_class', 'ir_order', 
		      'family', 'genus', 'species');
    my $phylo_str = $domain;
    for my $x  ( @phylo_flds ) {
	my $val = param($x);
	if ( $val ) {
	    if ( lc($val) eq 'unclassified' ) {
		$phylo_cond .= " and (t.$x = ? or t.$x is null)";
	    }
	    else {
		$phylo_cond .= " and t.$x = ?";
	    }
	    push @bind, ( $val );
	    $phylo_str .= "; " . $val;
	}
    }

    print "<h2>$phylo_str</h2>\n";

    my %cog_cnts;
    my %taxon_name_h;

    printStartWorkingDiv();

    print "<p>Counting genomes ...\n";

    my $taxonClause = WebUtil::txsClause( "t.taxon_oid", $dbh );
    my $rclause = WebUtil::urClause( "t.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "t.taxon_oid", 1 );
    if ( $domain ne '*Microbiome' ) {
	$sql = qq{
            select t.taxon_oid, t.domain, t.seq_status,
                   t.taxon_display_name, g.gene_count
            from taxon t, 
                 mv_taxon_${og}_stat g
            where g.${og} = ?
            and t.taxon_oid = g.taxon_oid
            $phylo_cond
            $taxonClause
            $rclause
            $imgClause
        };
	$cur = execSql( $dbh, $sql, $verbose, @bind );
	for ( ; ; ) {
	    my ( $t_id, $t_domain, $seq_status, $t_name, $cnt ) = 
		$cur->fetchrow();
	    last if ! $t_id;
	    $cog_cnts{$t_id} = $cnt;
	    $taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
	}
	$cur->finish();
    }

    if ($include_metagenomes && $domain eq '*Microbiome' ) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $sql = qq{
            select t.taxon_oid, t.domain, t.seq_status,
                   t.taxon_display_name, g.gene_count
            from taxon t, 
                 mv_taxon_${og}_stat g
            where g.${og} = ?
            and t.taxon_oid = g.taxon_oid
            $phylo_cond
            $taxonClause
            $rclause
            $imgClause
        };
        $cur = execSql( $dbh, $sql, $verbose, @bind );

        for ( ; ; ) {
            my ( $t_id, $t_domain, $seq_status, $t_name, $cnt ) = 
		$cur->fetchrow();
            last if !$t_id;
            $cog_cnts{$t_id} = $cnt;
	    $taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
	}
        $cur->finish();

        if ( $og eq 'cog' ) {
            print "<p>Counting metagenome genes ...\n";

	    my $rclause2 = WebUtil::urClause('f.taxon_oid'); 
	    my $imgClause2 = WebUtil::imgClauseNoTaxon('f.taxon_oid', 2); 
	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );
 
	    $sql = qq{
                        select t.taxon_oid, t.domain, t.seq_status,
                               t.taxon_display_name,
                               f.data_type, f.gene_count
                        from taxon t, taxon_cog_count f
                        where f.gene_count > 0
                        and f.func_id = ?
                        and t.taxon_oid = f.taxon_oid
                        $phylo_cond
                        $rclause2
                        $imgClause2
                        $taxonClause2
                    }; 
	    $cur = execSql( $dbh, $sql, $verbose, @bind ); 
	    for (;;) {
		my ( $t_id, $t_domain, $seq_status, $t_name, 
		     $d_type, $cnt ) = 
			 $cur->fetchrow();
		last if ! $t_id;

		if ( $cog_cnts{$t_id} ) {
		    $cog_cnts{$t_id} += $cnt; 
		} 
		else { 
		    $cog_cnts{$t_id} = $cnt;
		} 
		$taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
	    }
	    $cur->finish(); 
	    print "<br/>\n"; 
	}
    }

    printEndWorkingDiv();

    my $baseUrl = "$section_cgi&page=cogDetail";
    $baseUrl .= "&func_id=$func_id";

    my $cachedTable =
	new InnerTable( 1, "allmetagphylodist$$", "allmetagphylodist", 1 );
    my $sdDelim = $cachedTable->getSdDelim();
    $cachedTable->addColSpec( "Select" );
    $cachedTable->addColSpec( "Domain",   "asc", "left" );
    $cachedTable->addColSpec( "Status",   "asc", "left" );
    $cachedTable->addColSpec( "Taxon Name", "asc", "left" );
    $cachedTable->addColSpec("Gene Count", "desc", "right");

    my $select_id_name = "taxon_oid";
    my $count = 0;
    foreach my $taxon_oid ( keys %taxon_name_h ) {
        my $cnt = $cog_cnts{$taxon_oid};
	if ( ! $cnt ) {
	    next;
	}

        my ($t_domain, $seq_status, $taxon_name) = 
	    split (/\t/, $taxon_name_h{$taxon_oid});
	$t_domain = substr($t_domain, 0, 1);
	$seq_status = substr($seq_status, 0, 1);
        $count++;

        my $r = $sdDelim
	. "<input type='checkbox' name='$select_id_name' value='$taxon_oid' />\t";
        my $url = "$main_cgi?section=TaxonDetail" 
            . "&page=taxonDetail&taxon_oid=$taxon_oid";

        $r .= "$t_domain\t";
	$r .= "$seq_status\t";
        $r .= "$taxon_name" . $sdDelim . alink( $url, $taxon_name ) . "\t";


        $url = "$main_cgi?section=CogCategoryDetail" 
            . "&page=ccdCOGGenomeGeneList&cog_id=$func_id&taxon_oid=$taxon_oid";
	$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";

        $cachedTable->addRow($r);
    }
    $cur->finish();
    
    if ( $count == 0 ) {
        #$dbh->disconnect();
        print "<div id='message'>\n";
        print "<p>\n";
        print "No ${OG}s found for current genome selections.\n";
        print "</p>\n";
        print "</div>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    #$dbh->disconnect();

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n"; 

    WebUtil::printGenomeCartFooter() if $count > 10;
    $cachedTable->printTable();
    WebUtil::printGenomeCartFooter();

    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}


############################################################################
# printCogTaxonTree
############################################################################
sub printCogTaxonTree {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }
    my $id_name = $og . "_id";
    my $func_id = param($id_name);

    printMainForm();
    print "<h1>${OG} Detail</h1>\n";

    my $dbh = dbLogin();

    my %allCogs;
    my $sql = qq{
        select c.${og}_id, c.${og}_name, c.description,
               c.db_source, c.add_date, c.seq_length
        from ${og} c
        where c.${og}_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $func_id );
    my ($cog_id, $cog_name, $desc, $db_source, $add_date, $seq_length) 
	= $cur->fetchrow();
    $cur->finish();

    print "<h3>$cog_id: " . WebUtil::escHtml($cog_name) . "</h3>\n";

    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "DB Source", WebUtil::escHtml($db_source) );
    printAttrRowRaw( "Add Date", $add_date );
    printAttrRowRaw( "Seq Length", $seq_length );

    $sql = qq{
        select cfs.${og}_id, cf.function_code, cf.definition,
               cf.function_group
        from ${og}_function cf, ${og}_functions cfs
        where cfs.${og}_id = ?
        and cfs.functions = cf.function_code
    };
    $cur = execSql( $dbh, $sql, $verbose, $func_id );
    for (;;) {
	my ($c_id, $func_code, $def, $func_grp)
	    = $cur->fetchrow();
	last if ! $c_id;

	if ( $func_code ) {
	    printAttrRowRaw( "Function Code", $func_code );
	}
	if ( $def ) {
	    printAttrRowRaw( "Definition", $def );
	}
	if ( $func_grp ) {
	    printAttrRowRaw( "Function Group", $func_grp );
	}
    }
    $cur->finish();

    print "</table>\n";

    my $domain = param('domain');
    my $phylo_cond = "and t.domain = ?";
    my @bind = ($func_id, $domain);
    my @phylo_flds = ('phylum', 'ir_class', 'ir_order', 
		      'family', 'genus', 'species');
    my $phylo_str = $domain;
    for my $x  ( @phylo_flds ) {
	my $val = param($x);
	if ( $val ) {
	    if ( lc($val) eq 'unclassified' ) {
		$phylo_cond .= " and (t.$x = ? or t.$x is null)";
	    }
	    else {
		$phylo_cond .= " and t.$x = ?";
	    }
	    push @bind, ( $val );
	    $phylo_str .= "; " . $val;
	}
    }

    print "<h2>$phylo_str</h2>\n";

    my %cog_cnts;
    my %taxon_name_h;

    printStartWorkingDiv();

    print "<p>Counting genomes ...\n";

    my $taxonClause = WebUtil::txsClause( "t.taxon_oid", $dbh );
    my $rclause = WebUtil::urClause( "t.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "t.taxon_oid", 1 );
    if ( $domain ne '*Microbiome' ) {
	$sql = qq{
            select t.taxon_oid, t.domain, t.seq_status,
                   t.taxon_display_name, g.gene_count
            from taxon t, 
                 mv_taxon_${og}_stat g
            where g.${og} = ?
            and t.taxon_oid = g.taxon_oid
            $phylo_cond
            $taxonClause
            $rclause
            $imgClause
        };
	$cur = execSql( $dbh, $sql, $verbose, @bind );
	for ( ; ; ) {
	    my ( $t_id, $t_domain, $seq_status, $t_name, $cnt ) = 
		$cur->fetchrow();
	    last if ! $t_id;
	    $cog_cnts{$t_id} = $cnt;
	    $taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
	}
	$cur->finish();
    }

    if ($include_metagenomes && $domain eq '*Microbiome' ) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $sql = qq{
            select t.taxon_oid, t.domain, t.seq_status,
                   t.taxon_display_name, g.gene_count
            from taxon t, 
                 mv_taxon_${og}_stat g
            where g.${og} = ?
            and t.taxon_oid = g.taxon_oid
            and t.in_file = 'No'
            $phylo_cond
            $taxonClause
            $rclause
            $imgClause
        };
        $cur = execSql( $dbh, $sql, $verbose, @bind );

        for ( ; ; ) {
            my ( $t_id, $t_domain, $seq_status, $t_name, $cnt ) = 
		$cur->fetchrow();
            last if !$t_id;
            $cog_cnts{$t_id} = $cnt;
	    $taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
	}
        $cur->finish();

        if ( $og eq 'cog' ) {
            print "<p>Counting metagenome genes ...\n";

	    my $rclause2 = WebUtil::urClause('f.taxon_oid'); 
	    my $imgClause2 = WebUtil::imgClauseNoTaxon('f.taxon_oid', 2); 
	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );
 
	    $sql = qq{
                        select t.taxon_oid, t.domain, t.seq_status,
                               t.taxon_display_name,
                               f.data_type, f.gene_count
                        from taxon t, taxon_cog_count f
                        where f.gene_count > 0
                        and f.func_id = ?
                        and t.taxon_oid = f.taxon_oid
                        and t.in_file = 'Yes'
                        $phylo_cond
                        $rclause2
                        $imgClause2
                        $taxonClause2
                    }; 
 
	    $cur = execSql( $dbh, $sql, $verbose, @bind ); 
	    for (;;) {
		my ( $t_id, $t_domain, $seq_status, $t_name, 
		     $d_type, $cnt ) = 
			 $cur->fetchrow();
		last if ! $t_id;

		if ( $cog_cnts{$t_id} ) {
		    $cog_cnts{$t_id} += $cnt; 
		} 
		else { 
		    $cog_cnts{$t_id} = $cnt;
		} 
		$taxon_name_h{$t_id} = $t_domain . "\t" . $seq_status . "\t" . $t_name;
	    }
	    $cur->finish(); 
	    print "<br/>\n"; 
	}
    }

    printEndWorkingDiv();

    my $baseUrl = "$section_cgi&page=cogDetail";
    $baseUrl .= "&func_id=$func_id";

    my $mgr = new PhyloTreeMgr();
    my %taxon_filter;
    my %taxon_gene_cnt;
    my $taxon_filter_cnt = 0;
    foreach my $taxon_oid ( keys %taxon_name_h ) {
	my $cnt = $cog_cnts{$taxon_oid};
	if ( ! $cnt ) {
	    next;
	}
	$taxon_filter{$taxon_oid} = $func_id;
	$taxon_gene_cnt{$taxon_oid} = $cnt;
	$taxon_filter_cnt++;
    }

    my $url3 = "$main_cgi?section=CogCategoryDetail" 
	. "&page=ccdCOGGenomeGeneList&cog_id=";

    $mgr->loadFuncTree( $dbh, \%taxon_filter, 0 );
    WebUtil::printTaxonButtons ();
    $mgr->printFuncTree( \%taxon_filter, $taxon_filter_cnt, $url3, 0,
	\%taxon_gene_cnt);

    if ($taxon_filter_cnt > 0) { 
	WebUtil::printTaxonButtons ();
    }

    printStatusLine( "$taxon_filter_cnt Loaded.", 2 );
    print end_form();
}


############################################################################
# printCcdCogGenomeGeneList - Show COG genome gene listing for genome
#   selection.
############################################################################
sub printCcdCogGenomeGeneList {
    my ($isKOG) = @_;
    my $og      = "cog";    # orthogonal group: cog|kog
    my $OG      = "COG";    # orthogonal group text: COG|KOG

    if ($isKOG) {
        $og = "kog";
        $OG = "KOG";
    }

    my $cog_id    = param("${og}_id");
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print hiddenVar( 'taxon_oid', $taxon_oid );
    print hiddenVar( 'func_id',   $cog_id );

    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClause("t");

    my $sql = 
        "select t.taxon_oid, t.taxon_display_name, t.in_file "
      . "from taxon t where taxon_oid = ? $rclause $imgClause";

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $id2, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();
    if ( !$id2 ) {
        #$dbh->disconnect();
        return;
    }

    print "<h1>Genes with $cog_id</h1>\n";
    my $url =
        "$main_cgi?section=TaxonDetail&page=taxonDetail"
      . "&taxon_oid=$taxon_oid";
    print "<p>" . alink( $url, $taxon_name ) . "</p>";

    my $it = new InnerTable( 1, "cogGenes$$", "cogGenes", 1 );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    my $gene_count     = 0;
    my $show_gene_name = 1;
    my $trunc          = 0;

    if ( $in_file eq 'Yes' ) {
        # MER-FS
        printStartWorkingDiv();
        print "<p>Retrieving gene information ...<br/>\n";

        my %genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, '', $cog_id );
        my @gene_oids = ( keys %genes );
#        if ( scalar(@gene_oids) > 100 ) {
#            $show_gene_name = 0;
#        }

        $it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID", "asc", "left" );
        if ($show_gene_name) {
            $it->addColSpec( "Gene Product Name", "asc", "left" );
        }
        $it->addColSpec( "Genome Name", "asc", "left" );

        foreach my $key (@gene_oids) {
            my $workspace_id = $genes{$key};
            my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

            my $row = $sd
              . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
            $row .=
                $workspace_id . $sd
              . "<a href='main.cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$tid"
              . "&data_type=$dt&gene_oid=$key'>$key</a>\t";

            if ($show_gene_name) {
                my ( $value, $source ) =
                  MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
                $row .= $value . $sd . $value . "\t";
            }

            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$tid'>$taxon_name</a>\t";

            $it->addRow($row);
            $gene_count++;
            print ". ";
            if ( ( $gene_count % 180 ) == 0 ) {
                print "<br/>\n";
            }

            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }

        printEndWorkingDiv();
    }

    else {
        # Oracle DB
        my $rclause   = WebUtil::urClause("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
        my $sql       = qq{
             select distinct g.gene_oid, g.gene_display_name, g.locus_tag
             from ${og}_function cf, ${og}_functions cfs, ${og} c,
                  gene_${og}_groups gcg, gene g
             where cf.function_code = cfs.functions
             and c.${og}_id = '$cog_id'
             and cfs.${og}_id = c.${og}_id
             and c.${og}_id = gcg.${og}
             and gcg.gene_oid = g.gene_oid
             and g.taxon = ?
             and g.locus_type = 'CDS'
             and g.obsolete_flag = 'No'
             $rclause
             $imgClause
        };

        if ( $og eq 'cog' ) {
            $sql = qq{
                 select distinct g.gene_oid, g.gene_display_name, g.locus_tag
                 from gene_cog_groups gcg, gene g
                 where gcg.cog = '$cog_id'
                 and gcg.gene_oid = g.gene_oid
                 and g.taxon = ?
                 and g.locus_type = 'CDS'
                 and g.obsolete_flag = 'No'
                 $rclause
                 $imgClause
            };
        }

        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID",           "asc", "left" );
        $it->addColSpec( "Locus Tag",         "asc", "left" );
        $it->addColSpec( "Gene Product Name", "asc", "left" );
        $it->addColSpec( "Genome Name",       "asc", "left" );

        for ( ; ; ) {
            my ( $gene_oid, $gene_name, $locus_tag ) = $cur->fetchrow();
            last if !$gene_oid;
            my $row = $sd
              . "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\t";
            $row .=
                $gene_oid . $sd
              . "<a href='main.cgi?section=GeneDetail"
              . "&page=geneDetail&gene_oid=$gene_oid'>"
              . "$gene_oid</a>\t";
            $row .= $locus_tag . $sd . $locus_tag . "\t";
            $row .= $gene_name . $sd . $gene_name . "\t";
            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=TaxonDetail"
              . "&page=taxonDetail&taxon_oid=$taxon_oid'>$taxon_name</a>\t";

            $it->addRow($row);
            $gene_count++;

            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        $cur->finish();
    }
    #$dbh->disconnect();

    my $msg = '';
    if ( !$show_gene_name ) {
        $msg .= " Gene names are not displayed. Use 'Expand Gene "
              . "Table Display' option to view detailed gene information.";
        printHint($msg);
    }

    if ($gene_count > 10) {
        printGeneCartFooter();
    }
    $it->printOuterTable(1);
    printGeneCartFooter();
    
    if ( !$show_gene_name ) {
        printHint($msg);
    }

    if ($gene_count > 0) {
        MetaGeneTable::printMetaGeneTableSelect();
	if ( $og eq 'cog' ) {
            print hiddenVar ( 'data_type', 'both' );
            WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
        }
        else {
            WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
        }
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    }
    else {
        printStatusLine( "$gene_count gene(s) retrieved.", 2 );
    }

    print end_form();
}


1;
