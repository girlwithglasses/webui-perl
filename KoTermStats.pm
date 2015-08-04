############################################################################
#
# $Id: KoTermStats.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
############################################################################
package KoTermStats;
my $section = "KoTermStats";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;
use POSIX qw(ceil floor);
use HtmlUtil;
use OracleUtil;
use QueryUtil;
use TaxonDetailUtil;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $verbose               = $env->{verbose};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $img_internal          = $env->{img_internal};
my $tmp_dir               = $env->{tmp_dir};
my $user_restricted_site  = $env->{user_restricted_site};
my $include_metagenomes   = $env->{include_metagenomes};
my $show_private          = $env->{show_private};
my $content_list          = $env->{content_list};
my $pfam_base_url         = $env->{pfam_base_url};
my $cog_base_url          = $env->{cog_base_url};
my $tigrfam_base_url      = $env->{tigrfam_base_url};
my $include_img_term_bbh  = $env->{include_img_term_bbh};
my $cgi_tmp_dir           = $env->{cgi_tmp_dir};
my $ko_stats_paralog_file = $env->{ko_stats_paralog_file};
my $ko_stats_combo_file   = $env->{ko_stats_combo_file};
my $img_ken   = $env->{img_ken};

my $max_gene_batch     = 500;
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

timeout( 60 * 20 );

    if ( $page eq "paralog" ) {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;        
        
        my $view = param("view");
        if ( $view eq "slow" ) {

            # dynamic version slow
            printParalogTable();
        } elsif ( $ko_stats_paralog_file ne "" && -e $ko_stats_paralog_file ) {
            printParalogTableFile();
        } else {

            # using dt table version
            printParalogTable_dt();
        }
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "paralogindex" ) {

        # testing version to do paging of results
        printParalogTableIndex();

    } elsif ( $page eq "paraloggenelist" ) {
        printTermsGeneParalogGeneList();
    } elsif ( $page eq "paralogsamegenelist" ) {
        printTermsGeneParalogSameTermGeneList();
    } elsif ( $page eq "genomelist" ) {
        printTermGenomeList();
    } elsif ( $page eq "combo" ) {

        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        my $view = param("view");
        if ( $view eq "slow" ) {

            # dynamic version slow
            printComboTable();
        } elsif ( $ko_stats_combo_file ne "" && -e $ko_stats_combo_file ) {
            printComboTableFile();
        } else {

            # using dt table version
            printComboTable_dt();
        }

        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "combodetail" ) {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        printComboDetail();
        
        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "combogenelist" ) {
        #my $sid = 0;
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid );
        #HtmlUtil::cgiCacheStart() or return;

        printComboGeneList();
        #HtmlUtil::cgiCacheStop();        
    } elsif ( $page eq "combogenelistfusion" ) {
        #my $sid = 0;
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid );
        #HtmlUtil::cgiCacheStart() or return;

        printComboGeneListFusion();
        #HtmlUtil::cgiCacheStop();        
    } elsif ( $page eq "combogenelistother" ) {
        #my $sid = 0;
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid );
        #HtmlUtil::cgiCacheStart() or return;

        printComboGeneListOther();
        #HtmlUtil::cgiCacheStop();        
    } elsif ( $page eq "combogenelistother2" ) {
        #my $sid = 0;
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid );
        #HtmlUtil::cgiCacheStart() or return;

        printComboGeneListOther2();
        #HtmlUtil::cgiCacheStop();        
    } elsif ( $page eq "combogenelistno" ) {
        #my $sid = 0;
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid );
        #HtmlUtil::cgiCacheStart() or return;

        printComboGeneListNoTerm();
        #HtmlUtil::cgiCacheStop();        
    } elsif ( $page eq "kogenelist" ) {
        #my $sid = 0;
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid );
        #HtmlUtil::cgiCacheStart() or return;

        printKoGeneList();
        #HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "kotermlist" ) {
        #my $sid = 0;
        #HtmlUtil::cgiCacheInitialize( "$section" . "_" . $sid );
        #HtmlUtil::cgiCacheStart() or return;

        printKoTermList();
        #HtmlUtil::cgiCacheStop();
    } else {
        print "TODO page=$page<br/>\n";
    }
}

# convert all hash keys to string separate by a space
sub hashKey2String {
    my ($href) = @_;
    my $str;
    foreach my $key ( keys %$href ) {
        $str = $str . " " . $key;
    }
    return $str;
}

# convert array list of objects to hash keys
sub addList2Hash {
    my ( $aref, $href ) = @_;
    foreach my $x (@$aref) {
        $href->{$x} = "";
    }
}

sub array2String {
    my ($aref) = @_;
    my $str = "";
    foreach my $id ( sort @$aref ) {
        if ( $str eq "" ) {
            $str = $id;
        } else {
            $str = $str . " " . $id;
        }
    }
    return $str;
}

# gets term name
sub getTermName {
    my ( $dbh, $term_oid ) = @_;
    my $sql = qq{
    select ko_name, definition
    from ko_term
    where ko_id = ?
    };

    my @a = ($term_oid);
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ( $name, $defn ) = $cur->fetchrow();
    $cur->finish();
    return ( $name, $defn );
}

# gets all ko terms
sub getKoTerms {
    my ($dbh) = @_;

    my %hash;

    my $cachefile = param("kotermfile");

    if ( $cachefile ne "" && -e "$cgi_tmp_dir/$cachefile" ) {
        $cachefile = WebUtil::checkFileName($cachefile);

        print "Reading file terms cached file $cachefile <br/>\n";
        webLog("read cache file $cgi_tmp_dir/$cachefile\n");

        my $res = newReadFileHandle("$cgi_tmp_dir/$cachefile");

        while ( my $line = $res->getline() ) {
            chomp $line;
            my ( $id, $term, $defn ) = split( /\t/, $line );
            $hash{$id} = "$term\t$defn";
        }
        close $res;

    } else {

        my $sql = qq{
        select ko_id, ko_name, definition
        from ko_term
        };

        $cachefile = "kotermfile$$";

        my $res = newWriteFileHandle("$cgi_tmp_dir/$cachefile");
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id, $term, $defn ) = $cur->fetchrow();
            last if !$id;
            $hash{$id} = "$term\t$defn";
            print $res "$id\t$term\t$defn\n";
        }
        $cur->finish();
        close $res;
    }
    return ( \%hash, $cachefile );
}

sub getKoTerms_nocache {
    my ($dbh) = @_;

    my %hash;

    my $sql = qq{
        select ko_id, ko_name, definition
        from ko_term
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $term, $defn ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = "$term\t$defn";
    }
    $cur->finish();

    return \%hash;
}

sub getTermsDtParalogData {
    my ($dbh) = @_;
    my $sql = qq{
      select ko_id, gene_count, genome_count, avg_gene_genome, 
      gene_cnt_paralog, gene_paralog_same, avg_percent_ident
      from  dt_ko_term_paralog_stats 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %hash;
    for ( ; ; ) {
        my ( $ko_id, $gene_count, $genome_count, $avg_gene_genome,
             $gene_cnt_paralog, $gene_paralog_same, $avg_percent_ident )
          = $cur->fetchrow();
        last if !$ko_id;
        $hash{$ko_id} =
            "$gene_count\t$genome_count\t$avg_gene_genome\t"
          . "$gene_cnt_paralog\t$gene_paralog_same\t$avg_percent_ident";
    }
    $cur->finish();

    return \%hash;
}

sub getKoTermsCount {
    my ($dbh) = @_;
    my $sql = qq{
    select count(*)
    from ko_term
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

sub getKoTermsCombo_dt {
    my ($dbh) = @_;
    my $sql = qq{
      select ko_id, cog_count, pfam_count, tigrfam_count, unique_combo_count
      from  dt_ko_term_combo_stats 
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %hash;
    for ( ; ; ) {
        my ( $ko_id, $cog_count, $pfam_count, $tigrfam_count,
             $unique_combo_count )
          = $cur->fetchrow();
        last if !$ko_id;
        $hash{$ko_id} =
          "$cog_count\t$pfam_count\t$tigrfam_count\t$unique_combo_count";
    }
    $cur->finish();

    return \%hash;
}

# get all terms combo
sub getKoTermsCombo {
    my ($dbh)  = @_;

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql;
#    if ( $rclause eq "" ) {
#        $sql = qq{
#			select distinct gif.ko_terms, dtc.combo_oid, dtc.cog_ids, dtc.pfam_ids, 
#			dtc.tigrfam_ids
#			from gene_ko_terms gif, dt_func_combo_genes_4ko dtg, dt_func_combo_4ko dtc
#			where gif.gene_oid = dtg.gene_oid
#			and dtg.combo_oid = dtc.combo_oid
#			order by 1 
#        };
#    }
#    else {
	    $sql = qq{
	        select distinct gif.ko_terms, dtc.combo_oid, dtc.cog_ids, dtc.pfam_ids, 
	        dtc.tigrfam_ids
	        from gene_ko_terms gif, dt_func_combo_genes_4ko dtg, dt_func_combo_4ko dtc, gene g
	        where gif.gene_oid = dtg.gene_oid
	        and dtg.combo_oid = dtc.combo_oid
	        and g.gene_oid = gif.gene_oid
	        $rclause
	        $imgClause
	        order by 1 
	    };
#    }

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    my @a;
    for ( ; ; ) {
        my ( $term_oid, $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids ) =
          $cur->fetchrow();
        last if !$term_oid;
        push( @a, "$term_oid\t$combo_oid\t$cog_ids\t$pfam_ids\t$tigrfam_ids" );
    }
    $cur->finish();
    return \@a;
}

# gets all terms
sub getTermsGenomeCnt {
    my ( $dbh, $str ) = @_;

    my $idclause;
    if ( $str ne "" ) {
        $idclause = "and gif.ko_terms in ($str)";
    }

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
		select gif.ko_terms, count(distinct g.taxon)
		from  gene_ko_terms gif, gene g
		where g.gene_oid = gif.gene_oid
		$rclause
		$idclause
		$imgClause
		group by gif.ko_terms
    };
    #print "getTermsGenomeCnt \$sql: $sql<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    my %hash;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# gets terms gene count
# for use in calc (this - getTermsKoGenes)
#   number of genes with this ko term and no ko term
sub getTermsGeneCnt {
    my ( $dbh, $str ) = @_;

    my $idclause;
    if ( $str ne "" ) {
        $idclause = "and g.ko_terms in ($str)";
    }

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select g.ko_terms, count(distinct g.gene_oid)
		from gene_ko_terms g
		where 1 = 1
		$idclause
		$rclause
		$imgClause
		group by g.ko_terms
    };
    #print "getTermsGeneCnt \$sql: $sql<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    my %hash;
    for ( ; ; ) {
        my ( $term_oid, $cnt ) = $cur->fetchrow();
        last if !$term_oid;
        $hash{$term_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# average number of genes with term per genome
sub getTermsAvgGenome {
    my ( $dbh, $str ) = @_;

    my $idclause;
    if ( $str ne "" ) {
        $idclause = "and gif.ko_terms in ($str)";
    }

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
		select a.ko_terms, avg(a.gcnt)
		from (
		select gif.ko_terms, g.taxon, count(g.gene_oid) as gcnt
		from gene_ko_terms gif, gene g
		where gif.gene_oid = g.gene_oid
		$rclause
		$idclause
		$imgClause
		group by gif.ko_terms, g.taxon
		) a
		group by a.ko_terms
    };
    #print "getTermsAvgGenome \$sql: $sql<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    # hash of hashes, child id => hash of parent ids
    my %hash;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# number of genes with term in paralog cluster
sub getTermsGeneParalog {
    my ( $dbh, $str ) = @_;

    my $idclause;
    if ( $str ne "" ) {
        $idclause = "and g.ko_terms in ($str)";
    }

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
		select g.ko_terms, count(distinct g.gene_oid)
		from gene_ko_terms g, gene_paralogs gp
		where g.gene_oid = gp.gene_oid
		$idclause
		$rclause
		$imgClause
		group by g.ko_terms
    };
    #print "getTermsGeneParalog \$sql: $sql<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    # hash of hashes, child id => hash of parent ids
    my %hash;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# number of genes with term whose
# paralog is annotated with the same term
sub getTermsGeneParalogSameTerm {
    my ( $dbh, $str ) = @_;

    my $idclause;
    if ( $str ne "" ) {
        $idclause = "and g.ko_terms in ($str)";
    }

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
		select g.ko_terms, count(distinct g.gene_oid)
		from gene_ko_terms g, gene_paralogs gp, gene_ko_terms gif2
		where g.gene_oid = gp.gene_oid
		and gp.paralog = gif2.gene_oid
		and g.ko_terms = gif2.ko_terms
		$rclause
		$idclause
		$imgClause
		group by g.ko_terms
    };
    #print "getTermsGeneParalogSameTerm \$sql: $sql<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    # hash of hashes, child id => hash of parent ids
    my %hash;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# average % identtity between paralogs annotated with the
# same ko term
sub getTermsParalogPercent {
    my ( $dbh, $str ) = @_;

    my $idclause;
    if ( $str ne "" ) {
        $idclause = "and gif.ko_terms in ($str)";
    }

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
		select gif.ko_terms, avg(gp.percent_identity)
		from gene_ko_terms gif, gene_paralogs gp, gene g
		where gif.gene_oid = gp.gene_oid
		and g.gene_oid = gp.gene_oid
		$rclause
		$idclause
		$imgClause
		group by gif.ko_terms
    };
    #print "getTermsParalogPercent \$sql: $sql<br/>";

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    # hash of hashes, child id => hash of parent ids
    my %hash;
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# gets all combo for a given term
sub getCombo {
    my ( $dbh, $term_oid ) = @_;

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
		select  distinct dtc.combo_oid, dtc.cog_ids, dtc.pfam_ids, dtc.tigrfam_ids
		from gene_ko_terms gif, dt_func_combo_genes_4ko dtg, dt_func_combo_4ko dtc, gene g
		where gif.gene_oid = dtg.gene_oid
		and dtg.combo_oid = dtc.combo_oid
		and gif.ko_terms = ?
		and g.gene_oid = gif.gene_oid
		$rclause
		$imgClause
    };
    #print "getComo \$sql: $sql<br/>";
    my @a = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
    	push(@a, @bindList_ur);
    }

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my @res;
    my %distinct_cog;
    my %distinct_pfam;
    my %distinct_tigrfam;
    for ( ; ; ) {
        my ( $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids ) = $cur->fetchrow();
        last if !$combo_oid;

        # sort function ids alph not by position as stored in db
        my @tmp = split( /\s/, $cog_ids );
        $cog_ids     = array2String( \@tmp );
        @tmp         = split( /\s/, $pfam_ids );
        $pfam_ids    = array2String( \@tmp );
        @tmp         = split( /\s/, $tigrfam_ids );
        $tigrfam_ids = array2String( \@tmp );

        push( @res, "$combo_oid\t$cog_ids\t$pfam_ids\t$tigrfam_ids" );

        my @tmp = split( /\s/, $cog_ids );
        addList2Hash( \@tmp, \%distinct_cog );
        my @tmp = split( /\s/, $pfam_ids );
        addList2Hash( \@tmp, \%distinct_pfam );
        my @tmp = split( /\s/, $tigrfam_ids );
        addList2Hash( \@tmp, \%distinct_tigrfam );

    }
    $cur->finish();
    return ( \@res, \%distinct_cog, \%distinct_pfam, \%distinct_tigrfam );
}

# return a set of ko terms to be using the sql in statement
sub getKoTermSet {
    my ( $terms_href, $index ) = @_;
    my $rowsperpage = 100;
    my @set;

    my $row = 0;
    my $min = ( $index - 1 ) * $rowsperpage;
    my $max = $min + $rowsperpage;

    foreach my $id ( sort keys %$terms_href ) {

        if ( $row < $min ) {
            $row++;
            next;
        }
        last if ( $row >= $max );

        push( @set, "'$id'" );

        $row++;
    }

    return \@set;
}

sub printParalogTableIndex {
    my $index       = param("index");
    my $rowsperpage = 100;

    if ( $index eq "" ) {
        webError("Page index cannot be blank!");
    }

    print qq{
      <h1>KO Terms Paralog </h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    printStartWorkingDiv();

    print "i Getting terms.<br/>\n";
    my ( $terms_href, $file ) = getKoTerms($dbh);
    my $set_aref = getKoTermSet( $terms_href, $index );
    my $str = join( ",", @$set_aref );

    if ( $str eq "" ) {
        webError("Str index cannot be blank!");
    }

    print "i Getting terms genome count.<br/>\n";
    my $terms_genome_cnt_href = getTermsGenomeCnt( $dbh, $str );
    print "i Getting terms gene count.<br/>\n";
    my $terms_gene_cnt_href = getTermsGeneCnt( $dbh, $str );
    print "i Getting avg.<br/>\n";
    my $avgGenome_href = getTermsAvgGenome( $dbh, $str );
    print "i Getting paralog.<br/>\n";
    my $geneParalog_href = getTermsGeneParalog( $dbh, $str );
    print "i Getting paralog same term.<br/>\n";
    my $sameterm_href = getTermsGeneParalogSameTerm( $dbh, $str );
    print "i Getting percent.<br/>\n";
    my $percentIdent_href = getTermsParalogPercent( $dbh, $str );

    printEndWorkingDiv();

    my $termscnt = keys %$terms_href;
    print "<p> \n page: &nbsp;";

    for ( my $i = 0 ; $i <= ceil( $termscnt / $rowsperpage ) ; $i++ ) {
        my $x   = $i + 1;
        my $url =
            "main.cgi?section=KoTermStats&page=paralogindex&index=$x"
          . "&kotermfile=$file";
        $url = alink( $url, $x );

        if ( $index == $x ) {
            print "[$x] &nbsp;";
        } else {
            print "$url &nbsp;";
        }
        if ( $x % 20 == 0 ) {

      #            $x++;
      #            my $url =
      #                "main.cgi?section=KoTermStats&page=paralogindex&index=$x"
      #              . "&kotermfile=$file";
      #            $url = alink( $url, "Next" );
      #            print "$url \n";
      #            last;
            print "<br/>\n";
        }
    }
    print "\n</p>\n";

    printMainForm();
    printFuncCartFooter();
    my $count = 0;
    my $it = new InnerTable( 1, "kotermparalog$$", "kotermparalog", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",         "char asc",    "left" );
    $it->addColSpec( "KO Term Name",       "char asc",    "left" );
    $it->addColSpec( "KO Term Definition", "char asc",    "left" );
    $it->addColSpec( "Num of Genes",       "number desc", "right" );
    $it->addColSpec( "Num of Genomes",     "number desc", "right" );
    my $title = "Avg num of genes with this KO term per taxon id";
    $it->addColSpec(
                     "Avg # Genes per Genome", "number desc",
                     "right",                  "",
                     "title='$title'"
    );
    $title = "Num of genes with term in paralog cluster";
    $it->addColSpec(
                     "Num of Genes in Paralog", "number desc",
                     "right",                   "",
                     "title='$title'"
    );
    $title =
      "Num of genes with term whose paralog is annotated witht same term";
    $it->addColSpec( "Num of Genes whose Paralog has Same Term",
                     "number desc", "right", "", "title='$title'" );
    $title =
      "Avg percent indentity between paralogs annotated with the same KO term";
    $it->addColSpec(
                     "Avg % indentity", "number desc",
                     "right",           "",
                     "title='$title'"
    );

    foreach my $term_oid (@$set_aref) {
        $term_oid =~ s/'//g;
        my $line = $terms_href->{$term_oid};
        my ( $term, $defn ) = split( /\t/, $line );
        my $avg = sprintf( "%.2f", $avgGenome_href->{$term_oid} );
        $avg = 0 if ( $avg eq "" || $avg == 0 );
        my $para = $geneParalog_href->{$term_oid};
        $para = 0 if ( $para eq "" );
        my $same = $sameterm_href->{$term_oid};
        $same = 0 if ( $same eq "" );
        my $perc = sprintf( "%.2f", $percentIdent_href->{$term_oid} );
        $perc = 0 if ( $perc eq "" || $perc == 0 );
        $count++;
        my $r;

        #my $padded_term_oid = $term_oid;
        $r .= $sd
          . "<input type='checkbox' name='func_id' "
          . "value='$term_oid' />" . "\t";
        $r .= $term_oid . $sd . $term_oid . "\t";
        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        # gene count
        my $tmpcnt = $terms_gene_cnt_href->{$term_oid};
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        my $url = "$section_cgi&page=kogenelist&term_oid=$term_oid";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        # genome count
        my $tmpcnt = $terms_genome_cnt_href->{$term_oid};
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        my $url = "$section_cgi&page=genomelist&term_oid=$term_oid";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        $r .= $avg . $sd . $avg . "\t";

        if ( $para > 0 ) {
            my $url = "$section_cgi&page=paraloggenelist&term_oid=$term_oid";
            $url = alink( $url, $para );
            $r .= $para . $sd . $url . "\t";
        } else {
            $r .= $para . $sd . $para . "\t";
        }

        # paralogsamegenelist
        # paralogsamegenelist
        if ( $same > 0 ) {
            my $url =
              "$section_cgi&page=paralogsamegenelist&term_oid=$term_oid";
            $url = alink( $url, $same );
            $r .= $same . $sd . $url . "\t";
        } else {
            $r .= $same . $sd . $same . "\t";
        }

        $r .= $perc . $sd . $perc . "\t";

        $it->addRow($r);
    }

    $it->printOuterTable(1);

    print end_form();
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

sub printParalogTable {
    print qq{
      <h1>KO Terms Paralog </h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $terms_href = getKoTerms_nocache($dbh);
    print "Getting terms genome count.<br/>\n";
    my $terms_genome_cnt_href = getTermsGenomeCnt($dbh);
    print "Getting terms gene count.<br/>\n";
    my $terms_gene_cnt_href = getTermsGeneCnt($dbh);
    print "Getting avg.<br/>\n";
    my $avgGenome_href = getTermsAvgGenome($dbh);
    print "Getting paralog.<br/>\n";
    my $geneParalog_href = getTermsGeneParalog($dbh);
    print "Getting paralog same term.<br/>\n";
    my $sameterm_href = getTermsGeneParalogSameTerm($dbh);
    print "Getting percent.<br/>\n";
    my $percentIdent_href = getTermsParalogPercent($dbh);
    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();
    my $count = 0;
    my $it = new InnerTable( 1, "kotermparalog$$", "kotermparalog", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",         "char asc",    "left" );
    $it->addColSpec( "KO Term Name",       "char asc",    "left" );
    $it->addColSpec( "KO Term Definition", "char asc",    "left" );
    $it->addColSpec( "Num of Genes",       "number desc", "right" );
    $it->addColSpec( "Num of Genomes",     "number desc", "right" );
    my $title = "Avg num of genes with this KO term per taxon id";
    $it->addColSpec(
                     "Avg # Genes per Genome", "number desc",
                     "right",                  "",
                     "title='$title'"
    );
    $title = "Num of genes with term in paralog cluster";
    $it->addColSpec(
                     "Num of Genes in Paralog", "number desc",
                     "right",                   "",
                     "title='$title'"
    );
    $title =
      "Num of genes with term whose paralog is annotated witht same term";
    $it->addColSpec( "Num of Genes whose Paralog has Same Term",
                     "number desc", "right", "", "title='$title'" );
    $title =
      "Avg percent indentity between paralogs annotated with the same KO term";
    $it->addColSpec(
                     "Avg % indentity", "number desc",
                     "right",           "",
                     "title='$title'"
    );

    foreach my $term_oid ( keys %$terms_href ) {
        my $line = $terms_href->{$term_oid};
        my ( $term, $defn ) = split( /\t/, $line );
        my $avg = sprintf( "%.2f", $avgGenome_href->{$term_oid} );
        $avg = 0 if ( $avg eq "" || $avg == 0 );
        my $para = $geneParalog_href->{$term_oid};
        $para = 0 if ( $para eq "" );
        my $same = $sameterm_href->{$term_oid};
        $same = 0 if ( $same eq "" );
        my $perc = sprintf( "%.2f", $percentIdent_href->{$term_oid} );
        $perc = 0 if ( $perc eq "" || $perc == 0 );
        $count++;
        my $r;

        #my $padded_term_oid = $term_oid;
        $r .= $sd
          . "<input type='checkbox' name='func_id' "
          . "value='$term_oid' />" . "\t";
        $r .= $term_oid . $sd . $term_oid . "\t";
        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        # gene count
        my $tmpcnt = $terms_gene_cnt_href->{$term_oid};
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        my $url = "$section_cgi&page=kogenelist&term_oid=$term_oid";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        # genome count
        my $tmpcnt = $terms_genome_cnt_href->{$term_oid};
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        my $url = "$section_cgi&page=genomelist&term_oid=$term_oid";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        $r .= $avg . $sd . $avg . "\t";

        if ( $para > 0 ) {
            my $url = "$section_cgi&page=paraloggenelist&term_oid=$term_oid";
            $url = alink( $url, $para );
            $r .= $para . $sd . $url . "\t";
        } else {
            $r .= $para . $sd . $para . "\t";
        }

        # paralogsamegenelist
        # paralogsamegenelist
        if ( $same > 0 ) {
            my $url =
              "$section_cgi&page=paralogsamegenelist&term_oid=$term_oid";
            $url = alink( $url, $same );
            $r .= $same . $sd . $url . "\t";
        } else {
            $r .= $same . $sd . $same . "\t";
        }

        $r .= $perc . $sd . $perc . "\t";

        $it->addRow($r);
    }

    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();

    printStatusLine( "$count Loaded.", 2 );
}

# used teh dt tables
sub printParalogTable_dt {
    print qq{
      <h1>KO Term Distribution across Genomes <br/>and Paralog Clusters in IMG </h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $terms_href = getKoTerms_nocache($dbh);
    print "Getting terms genome count.<br/>\n";
    my $terms_data_href = getTermsDtParalogData($dbh);

    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();
    my $count = 0;
    my $it = new InnerTable( 1, "kotermparalog$$", "kotermparalog", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",         "char asc",    "left" );
    $it->addColSpec( "KO Term Name",       "char asc",    "left" );
    $it->addColSpec( "KO Term Definition", "char asc",    "left" );
    $it->addColSpec( "Num of Genes",       "number desc", "right" );
    $it->addColSpec( "Num of Genomes",     "number desc", "right" );
    my $title = "Avg num of genes with this KO term per taxon id";
    $it->addColSpec(
                     "Avg # Genes per Genome", "number desc",
                     "right",                  "",
                     "title='$title'"
    );
    $title = "Num of genes with term in paralog clusters";
    $it->addColSpec(
                     "Num of Genes in Paralog Clusters", "number desc",
                     "right",                            "",
                     "title='$title'"
    );
    $title =
      "Num of genes with term whose paralog is annotated witht same term";
    $it->addColSpec( "Num of Genes whose Paralog has Same Term",
                     "number desc", "right", "", "title='$title'" );
    $title =
      "Avg percent indentity between paralogs annotated with the same KO term";
    $it->addColSpec(
                     "Avg % indentity", "number desc",
                     "right",           "",
                     "title='$title'"
    );

    foreach my $term_oid ( keys %$terms_href ) {
        my $line = $terms_href->{$term_oid};
        my ( $term, $defn ) = split( /\t/, $line );

        # dt tables
        my $line = $terms_data_href->{$term_oid};
        next if ( $line eq "" );
        my ( $gene_cnt, $genome_cnt, $avg, $para, $same, $perc ) =
          split( /\t/, $line );

        $count++;
        my $r;

        #my $padded_term_oid = $term_oid;
        $r .= $sd
          . "<input type='checkbox' name='func_id' "
          . "value='$term_oid' />" . "\t";
        $r .= $term_oid . $sd . $term_oid . "\t";
        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        # gene count
        my $tmpcnt = $gene_cnt;
        my $url    = "$section_cgi&page=kogenelist&term_oid=$term_oid&gcnt=$gene_cnt";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        # genome count
        my $tmpcnt = $genome_cnt;
        my $url    = "$section_cgi&page=genomelist&term_oid=$term_oid&tcnt=$genome_cnt";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        $r .= $avg . $sd . $avg . "\t";

        if ( $para > 0 ) {
            my $url = "$section_cgi&page=paraloggenelist&term_oid=$term_oid";
            $url = alink( $url, $para );
            $r .= $para . $sd . $url . "\t";
        } else {
            $r .= $para . $sd . $para . "\t";
        }

        # paralogsamegenelist
        if ( $same > 0 ) {
            my $url =
              "$section_cgi&page=paralogsamegenelist&term_oid=$term_oid";
            $url = alink( $url, $same );
            $r .= $same . $sd . $url . "\t";
        } else {
            $r .= $same . $sd . $same . "\t";
        }

        $r .= $perc . $sd . $perc . "\t";

        $it->addRow($r);
    }

    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();

    printStatusLine( "$count Loaded.", 2 );
}

# file version of printParalogTable
sub printParalogTableFile {
    print qq{
      <h1>KO Terms Paralog </h1>  
    };

    printStatusLine( "Loading ...", 1 );

    printMainForm();
    printFuncCartFooter();
    my $count = 0;
    my $it = new InnerTable( 1, "kotermparalog$$", "kotermparalog", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",         "char asc",    "left" );
    $it->addColSpec( "KO Term Name",       "char asc",    "left" );
    $it->addColSpec( "KO Term Definition", "char asc",    "left" );
    $it->addColSpec( "Num of Genes",       "number desc", "right" );
    $it->addColSpec( "Num of Genomes",     "number desc", "right" );
    my $title = "Avg num of genes with this KO term per taxon id";
    $it->addColSpec(
                     "Avg # Genes per Genome", "number desc",
                     "right",                  "",
                     "title='$title'"
    );
    $title = "Num of genes with term in paralog cluster";
    $it->addColSpec(
                     "Num of Genes in Paralog", "number desc",
                     "right",                   "",
                     "title='$title'"
    );
    $title =
      "Num of genes with term whose paralog is annotated witht same term";
    $it->addColSpec( "Num of Genes whose Paralog has Same Term",
                     "number desc", "right", "", "title='$title'" );
    $title =
      "Avg percent indentity between paralogs annotated with the same KO term";
    $it->addColSpec(
                     "Avg % indentity", "number desc",
                     "right",           "",
                     "title='$title'"
    );

    my $res = newReadFileHandle($ko_stats_paralog_file);
    while ( my $line = $res->getline() ) {
        chomp $line;
        my (
             $term_oid, $term, $defn, $genecnt, $genomecnt,
             $avg,      $para, $same, $perc
          )
          = split( /\t/, $line );

        $count++;
        my $r;

        #my $padded_term_oid = $term_oid;
        $r .= $sd
          . "<input type='checkbox' name='func_id' "
          . "value='$term_oid' />" . "\t";
        $r .= $term_oid . $sd . $term_oid . "\t";
        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        # gene count
        my $tmpcnt = $genecnt;
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        my $url = "$section_cgi&page=kogenelist&term_oid=$term_oid";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        # genome count
        my $tmpcnt = $genomecnt;
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        my $url = "$section_cgi&page=genomelist&term_oid=$term_oid";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        $r .= $avg . $sd . $avg . "\t";

        if ( $para > 0 ) {
            my $url = "$section_cgi&page=paraloggenelist&term_oid=$term_oid";
            $url = alink( $url, $para );
            $r .= $para . $sd . $url . "\t";
        } else {
            $r .= $para . $sd . $para . "\t";
        }

        # paralogsamegenelist
        # paralogsamegenelist
        if ( $same > 0 ) {
            my $url =
              "$section_cgi&page=paralogsamegenelist&term_oid=$term_oid";
            $url = alink( $url, $same );
            $r .= $same . $sd . $url . "\t";
        } else {
            $r .= $same . $sd . $same . "\t";
        }

        $r .= $perc . $sd . $perc . "\t";

        $it->addRow($r);
    }

    close $res;

    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$count Loaded.", 2 );
}

sub printTermGenomeList {
    my $term_oid = param("term_oid");
    my $tcnt = param("tcnt");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my ( $name, $defn ) = getTermName( $dbh, $term_oid );

    print qq{
      <h1>
      KO Term Genome List
      </h1>
      <p>
      <b>
      $name<br/>
      $defn<br/>
      </b>
      </p>
        
    };

    printMainForm();
    
    my ($rclause, @bindList_ur) = urClauseBind("t");
    my $imgClause = WebUtil::imgClause('t');
    
    my $sql = qq{
		select distinct t.taxon_oid, t.taxon_display_name, t.domain, t.seq_status
		from  gene_ko_terms gif, gene g, vw_taxon t
		where g.gene_oid = gif.gene_oid
		and g.taxon = t.taxon_oid
		and gif.ko_terms = ?
		$rclause
		$imgClause
    };
    #print "printTermGenomeList \$sql: $sql<br/>";    
    my @a = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
    	push(@a, @bindList_ur);
    }
    #print "\@bindList: @a<br/>";

    my $count = 0;
    my $txTableName = "kotermgenome";  # name of current instance of taxon table
    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Domain",      "char asc",   "center", "",
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status",      "char asc",   "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome ID",   "number asc", "right" );
    $it->addColSpec( "Genome Name", "char asc",   "left" );

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $domain, $seq_status ) =
          $cur->fetchrow();
        last if !$taxon_oid;
        $count++;
        my $r;

        my $tmp =
            "<input type='checkbox' "
          . "name='taxon_filter_oid' value='$taxon_oid' checked />";
        $r .= $sd . $tmp . "\t";
        $tmp = substr( $domain, 0, 1 );
        $r .= $tmp . $sd . $tmp . "\t";
        $tmp = substr( $seq_status, 0, 1 );
        $r .= $tmp . $sd . $tmp . "\t";
        my $url =
            "$main_cgi?section=TaxonDetail&page=taxonDetail"
          . "&taxon_oid=$taxon_oid";
        $url = alink( $url, $taxon_oid );
        $r .= $taxon_oid . $sd . $url . "\t";
        $r .= $taxon_display_name . $sd . $taxon_display_name . "\t";

        $it->addRow($r);

    }
    $cur->finish();
    #$dbh->disconnect();

    print hiddenVar( "page",          "message" );
    print hiddenVar( "message",       "Genome selection saved and enabled." );
    print hiddenVar( "menuSelection", "Genomes" );

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "Click on column name to sort.<br/>\n";
    print "</p>\n";

    printTaxonButtons ($txTableName);
    $it->printOuterTable(1);
    printTaxonButtons ($txTableName);
    print end_form();

    my $msg = "$count Loaded.";
    my $diff = $tcnt - $count;
    if ($diff > 0) {
        $msg .= " (You do not have permission on $diff genomes.)";
    }
    printStatusLine( $msg, 2 );
}

# number of genes with term in paralog cluster gene list
sub printTermsGeneParalogGeneList {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    #$term_oid =~ s/'/''/g;
    my ( $name, $defn ) = getTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      KO Term Paralog Gene List
      </h1>  
      <p>
      <b>
      $name 
      <br/>
      $defn
      </b>
      </p>
    };

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct gif.gene_oid, g.gene_display_name
		from gene_ko_terms gif, gene_paralogs gp, gene g
		where gif.gene_oid = gp.gene_oid
		and g.gene_oid = gif.gene_oid 
		and gif.ko_terms = ?
		$rclause
		$imgClause
    };
    #print "printTermsGeneParalogGeneList \$sql: $sql<br/>";    
    my @bindList = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }

    printGeneListSectionSorting( $sql, "", "", @bindList );
}

# number of genes with term whose
# paralog is annotated with the same term
# gene list
sub printTermsGeneParalogSameTermGeneList {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();
    #$term_oid =~ s/'/''/g;
    my ( $name, $defn ) = getTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      KO Term Paralog Gene List (Same Term)
      </h1>  
      <p>
      <b>
      $name 
      <br/>
      $defn
      </b>
      </p>
    };

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct gif.gene_oid, g.gene_display_name
		from gene_ko_terms gif, gene_paralogs gp, gene_ko_terms gif2,
		gene g
		where gif.gene_oid = gp.gene_oid
		and gp.paralog = gif2.gene_oid
		and gif.gene_oid = g.gene_oid
		and gif.ko_terms = gif2.ko_terms
		and gif.ko_terms = ?
		$rclause
		$imgClause
    };
    #print "printTermsGeneParalogSameTermGeneList \$sql: $sql<br/>";    
    my @bindList = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }

    printGeneListSectionSorting( $sql, "", "", @bindList );
}

sub printComboTable {

    print qq{
      <h1> KO Term Combinations</h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    printStartWorkingDiv();

    print "Getting terms.<br/>\n";
    my $terms_href = getKoTerms_nocache($dbh);

    print "Getting combos.<br/>\n";
    my $terms_aref = getKoTermsCombo($dbh);
    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "kotermcombo$$", "kotermcombo", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",           "char asc",    "left" );
    $it->addColSpec( "KO Term",              "char asc",    "left" );
    $it->addColSpec( "KO Definition",        "char asc",    "left" );
    $it->addColSpec( "COG Count",            "number desc", "left" );
    $it->addColSpec( "Pfam Count",           "number desc", "left" );
    $it->addColSpec( "TIGRfam Count",        "number desc", "left" );
    $it->addColSpec( "Num of Unique Combos", "number desc", "right" );

    my $row_cnt      = 0;
    my $last_term_id = "";
    my $term_count   = 0;
    my %cog_hash;
    my %pfam_hash;
    my %tigr_hash;
    my %term_printed;

    foreach my $line (@$terms_aref) {
        my ( $term_oid, $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids ) =
          split( /\t/, $line );

        next if ( !exists $terms_href->{$term_oid} );

        $term_printed{$term_oid} = 1;

        if ( $last_term_id eq "" ) {
            $last_term_id = $term_oid;
        }

        if ( $term_oid eq $last_term_id ) {
            my @cogline = split( / /, $cog_ids );
            addList2Hash( \@cogline, \%cog_hash );
            my @pfamline = split( / /, $pfam_ids );
            addList2Hash( \@pfamline, \%pfam_hash );
            my @tigrfamline = split( / /, $tigrfam_ids );
            addList2Hash( \@tigrfamline, \%tigr_hash );
            $term_count++;
        } else {
            my ( $term_name, $term_defn ) =
              split( /\t/, $terms_href->{$last_term_id} );
            my $r;

            my $padded_term_oid = $last_term_id;

            $r .= $sd
              . "<input type='checkbox' name='func_id' "
              . "value='$padded_term_oid' />" . "\t";

            $r .= $padded_term_oid . $sd . $padded_term_oid . "\t";

            $r .= $term_name . $sd . $term_name . "\t";
            $r .= $term_defn . $sd . $term_defn . "\t";

            # comboproteinlist
            my $str = keys %cog_hash;
            $r .= $str . $sd . $str . "\t";
            my $str = keys %pfam_hash;
            $r .= $str . $sd . $str . "\t";
            my $str = keys %tigr_hash;
            $r .= $str . $sd . $str . "\t";

            if ( $term_count != 0 ) {
                my $url =
                    $section_cgi
                  . "&page=combodetail"
                  . "&term_oid=$last_term_id";
                $url = alink( $url, $term_count );
                $r .= $term_count . $sd . $url . "\t";
            } else {
                $r .= $term_count . $sd . $term_count . "\t";
            }

            $it->addRow($r);
            $row_cnt++;
            %cog_hash   = ();
            %pfam_hash  = ();
            %tigr_hash  = ();
            $term_count = 1;
            my @cogline = split( / /, $cog_ids );
            addList2Hash( \@cogline, \%cog_hash );
            my @pfamline = split( / /, $pfam_ids );
            addList2Hash( \@pfamline, \%pfam_hash );
            my @tigrfamline = split( / /, $tigrfam_ids );
            addList2Hash( \@tigrfamline, \%tigr_hash );
        }

        $last_term_id = $term_oid;
    }

    # last record
    #my $term_name = $terms_href->{$last_term_id};
    my ( $term_name, $term_defn ) = split( /\t/, $terms_href->{$last_term_id} );
    $term_printed{$last_term_id} = 1;

    my $r;
    my $padded_term_oid = $last_term_id;
    $r .= $sd
      . "<input type='checkbox' name='term_oid' "
      . "value='$padded_term_oid' />" . "\t";

    $r .= $padded_term_oid . $sd . $padded_term_oid . "\t";

    $r .= $term_name . $sd . $term_name . "\t";
    $r .= $term_defn . $sd . $term_defn . "\t";
    my $str = keys %cog_hash;
    $r .= $str . $sd . $str . "\t";
    my $str = keys %pfam_hash;
    $r .= $str . $sd . $str . "\t";
    my $str = keys %tigr_hash;
    $r .= $str . $sd . $str . "\t";

    if ( $term_count != 0 ) {
        my $url =
            $section_cgi
          . "&page=combodetail"
          . "&term_oid=$last_term_id";    # . "&combo_oid=$last_combo_id";
        $url = alink( $url, $term_count );
        $r .= $term_count . $sd . $url . "\t";
    } else {
        $r .= $term_count . $sd . $term_count . "\t";
    }
    $it->addRow($r);
    $row_cnt;
    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

# print ko term list as is
sub printKoTermList {
    print qq{
      <h1> KO Term List </h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh        = dbLogin();
    my $terms_href = getKoTerms_nocache($dbh);
    #$dbh->disconnect();

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "kotermcombo$$", "kotermcombo", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",    "char asc", "left" );
    $it->addColSpec( "KO Term",       "char asc", "left" );
    $it->addColSpec( "KO Definition", "char asc", "left" );

    my $row_cnt = 0;

    foreach my $term_oid ( keys %$terms_href ) {
        my $line = $terms_href->{$term_oid};
        next if ( $line eq "" );
        my ( $term, $defn ) = split( /\t/, $line );

        my $r;

        $r .= $sd
          . "<input type='checkbox' name='func_id' "
          . "value='$term_oid' />" . "\t";

        $r .= $term_oid . $sd . $term_oid . "\t";

        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        $it->addRow($r);
        $row_cnt++;
    }

    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

# dt table version
sub printComboTable_dt {

    print qq{
      <h1> KO Term Distribution across Protein Families in IMG </h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    printStartWorkingDiv();

    print "Getting terms.<br/>\n";
    my $terms_href = getKoTerms_nocache($dbh);

    print "Getting combos.<br/>\n";
    my $terms_combo_href = getKoTermsCombo_dt($dbh);
    printEndWorkingDiv();

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "kotermcombo$$", "kotermcombo", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",           "char asc",    "left" );
    $it->addColSpec( "KO Term",              "char asc",    "left" );
    $it->addColSpec( "KO Definition",        "char asc",    "left" );
    $it->addColSpec( "COG Count",            "number desc", "left" );
    $it->addColSpec( "Pfam Count",           "number desc", "left" );
    $it->addColSpec( "TIGRfam Count",        "number desc", "left" );
    $it->addColSpec( "Num of Unique Combos", "number desc", "right" );

    my $row_cnt = 0;

    foreach my $term_oid ( keys %$terms_href ) {
        my $line = $terms_href->{$term_oid};
        next if ( $line eq "" );
        my ( $term, $defn ) = split( /\t/, $line );

        my $line = $terms_combo_href->{$term_oid};
        my ( $cog_count, $pfam_count, $tigrfam_count, $unique_combo_count ) =
          split( /\t/, $line );

        my $r;

        $r .= $sd
          . "<input type='checkbox' name='func_id' "
          . "value='$term_oid' />" . "\t";

        $r .= $term_oid . $sd . $term_oid . "\t";

        $r .= $term . $sd . $term . "\t";
        $r .= $defn . $sd . $defn . "\t";

        # comboproteinlist
        my $str = $cog_count;
        $r .= $str . $sd . $str . "\t";
        my $str = $pfam_count;
        $r .= $str . $sd . $str . "\t";
        my $str = $tigrfam_count;
        $r .= $str . $sd . $str . "\t";

        if ( $unique_combo_count != 0 ) {
            my $url =
              $section_cgi . "&page=combodetail" . "&term_oid=$term_oid";
            $url = alink( $url, $unique_combo_count );
            $r .= $unique_combo_count . $sd . $url . "\t";
        } else {
            $r .= $unique_combo_count . $sd . $unique_combo_count . "\t";
        }

        $it->addRow($r);
        $row_cnt++;

    }

    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();

    printStatusLine( "$row_cnt Rows Loaded.", 2 );
}

sub printComboTableFile {

    print qq{
      <h1> KO Term Combinations</h1>  
    };

    printStatusLine( "Loading ...", 1 );

    printMainForm();
    printFuncCartFooter();

    # 0 sort col
    my $it = new InnerTable( 1, "kotermcombo$$", "kotermcombo", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KO Term ID",           "char asc",    "left" );
    $it->addColSpec( "KO Term",              "char asc",    "left" );
    $it->addColSpec( "KO Definition",        "char asc",    "left" );
    $it->addColSpec( "COG Count",            "number desc", "left" );
    $it->addColSpec( "Pfam Count",           "number desc", "left" );
    $it->addColSpec( "TIGRfam Count",        "number desc", "left" );
    $it->addColSpec( "Num of Unique Combos", "number desc", "right" );

    my $count = 0;

    my $res = newReadFileHandle($ko_stats_combo_file);
    while ( my $line = $res->getline() ) {
        chomp $line;
        my ( $term_oid, $term_name, $term_defn, $cog, $pfam, $tigr,
             $term_count ) = split( /\t/, $line );

        $count++;

        my $r;

        $r .= $sd
          . "<input type='checkbox' name='func_id' "
          . "value='$term_oid' />" . "\t";

        $r .= $term_oid . $sd . $term_oid . "\t";

        $r .= $term_name . $sd . $term_name . "\t";
        $r .= $term_defn . $sd . $term_defn . "\t";

        # comboproteinlist
        $r .= $cog . $sd . $cog . "\t";
        $r .= $pfam . $sd . $pfam . "\t";
        $r .= $tigr . $sd . $tigr . "\t";

        if ( $term_count != 0 ) {
            my $url =
              $section_cgi . "&page=combodetail" . "&term_oid=$term_oid";
            $url = alink( $url, $term_count );
            $r .= $term_count . $sd . $url . "\t";
        } else {
            $r .= $term_count . $sd . $term_count . "\t";
        }

        $it->addRow($r);

    }
    close $res;
    $it->printOuterTable(1);
    print end_form();

    printStatusLine( "$count Rows Loaded.", 2 );
}

# gets number of genes with combination and ko term
sub getComboGeneCnt {
    my ( $dbh, $term_oid ) = @_;

    my ($rclause, @bindList_ur) = urClauseBind("gif.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('gif.taxon');
    my $sql    = qq{
		select dtg.combo_oid, count(gif.gene_oid)
		from gene_ko_terms gif, dt_func_combo_genes_4ko dtg
		where gif.gene_oid = dtg.gene_oid
		and gif.ko_terms = ?
		$rclause
		$imgClause
		group by dtg.combo_oid
    };
    #print "getComboGeneCnt \$sql: $sql<br/>";
    my @a = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@a, @bindList_ur);
    }

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my %hash;
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# gets number of genes with combination and different ko term
sub getComboGeneCntOther {
    my ( $dbh, $term_oid ) = @_;

    my ($rclause, @bindList_ur) = urClauseBind("gif2.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('gif2.taxon');
    my $sql    = qq{
		select  dtg2.combo_oid, count(distinct gif2.gene_oid)
		from gene_ko_terms gif2, dt_func_combo_genes_4ko dtg2
		where gif2.gene_oid = dtg2.gene_oid
		and gif2.ko_terms != ?
		$rclause
		$imgClause
		and dtg2.combo_oid in (select id from gtt_num_id)
		group by dtg2.combo_oid
    };
    #print "getComboGeneCntOther \$sql: $sql<br/>";    
    my @a = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@a, @bindList_ur);
    }
    #push(@a, $term_oid);

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my %hash;
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# gets number of genes with combination and different ko term
# ignore genes already counted in "in"
sub getComboGeneCntOther2 {
    my ( $dbh, $term_oid ) = @_;

    #my ($rclause, @bindList_ur) = urClauseBind("dtg2.taxon");
    
    my $imgClause = WebUtil::imgClauseNoTaxon('gif2.taxon');
    
    # get distinct list of genes
    print "&nbsp;&nbsp;&nbsp;&nbsp;Getting genes without ko term $term_oid (it can be very slow)<br/>\n";
    my $urClause = urClause('gif2.taxon');
    my $sql = qq{
        select gif2.gene_oid
        from gene_ko_terms gif2
        where gif2.ko_terms != ?
        $urClause
        $imgClause
    };
    my %genelist;
    my $cur = execSql( $dbh, $sql,  $verbose, $term_oid );
    my $cnt = 0;
    for ( ; ; ) {
        my ( $gene_oid ) = $cur->fetchrow();
        last if !$gene_oid;
        $genelist{$gene_oid} = $gene_oid;
        $cnt++;
        print "." if($cnt % 100000 == 0);
    }
    print "$cnt<br/>\n";
    my $total1 = keys %genelist;
    print "&nbsp;&nbsp;&nbsp;&nbsp;Getting genes with ko term $term_oid<br/>\n";
    my $imgClause = WebUtil::imgClauseNoTaxon('gif3.taxon');
    my $urClause = urClause('gif3.taxon');
    my $sql = qq{
        select gif3.gene_oid 
        from gene_ko_terms gif3 
        where gif3.ko_terms = ?
        $urClause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql,  $verbose, $term_oid );
    my $cnt = 0;
    for ( ; ; ) {
        my ( $gene_oid ) = $cur->fetchrow();
        last if !$gene_oid;
        delete $genelist{$gene_oid};
        print "." if($cnt % 1000 == 0);
        $cnt++;
    }
    print "$cnt<br/>\n";
    my $total2 = keys %genelist;
    print "&nbsp;&nbsp;&nbsp;&nbsp;Getting difference in genes $total1 - $cnt = $total2 <br/>\n";
    #OracleUtil::insertDataHash($dbh, 'gtt_num_id2', \%genelist);

    print "&nbsp;&nbsp;&nbsp;&nbsp;Grouping genes into combo (it can be very slow)<br/>\n";
#    my $sql    = qq{
#		select  dtg2.combo_oid, dtg2.gene_oid
#		from dt_func_combo_genes_4ko dtg2
#		where dtg2.gene_oid in (select id from gtt_num_id2)
#		and dtg2.combo_oid in ( select id from gtt_num_id )
#    };
    my $sql    = qq{
        select  dtg2.combo_oid, dtg2.gene_oid
        from dt_func_combo_genes_4ko dtg2
        where dtg2.combo_oid in ( select id from gtt_num_id )
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %counthash; # combo id to hash of gene oid
    my $cnt = 0;
    for ( ; ; ) {
        my ( $combo_oid, $gene_oid ) = $cur->fetchrow();
        last if !$combo_oid;
        
        if(!exists $genelist{$gene_oid}) {
            next;
        }
        
        
        if(exists $counthash{$combo_oid}) {
            my $ghref = $counthash{$combo_oid};
            $ghref->{$gene_oid} = $gene_oid;
        } else {
            my %g = ($gene_oid => $gene_oid);
            $counthash{$combo_oid} = \%g;
        }
        $cnt++;
        print "." if($cnt % 1000 == 0);
    }
    print "&nbsp;&nbsp;&nbsp;&nbsp;Found: $cnt rows<br/>\n";
    
    my %hash;
    foreach my $combo_oid (keys %counthash) {
        my $ghref = $counthash{$combo_oid};
        my $size = keys %$ghref;
        $hash{$combo_oid} = $size;
    }

    return \%hash;
}

sub getComboGeneCntNoTerm {
    my ( $dbh, $term_oid ) = @_;

    my ($rclause, @bindList) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select dtg4.combo_oid, count(distinct dtg4.gene_oid)
		from dt_func_combo_genes_4ko dtg4, gene g
		where g.gene_oid = dtg4.gene_oid
		$rclause 
		$imgClause
		and dtg4.gene_oid in (
		select dtg.gene_oid
		from dt_func_combo_genes_4ko dtg
		where dtg.combo_oid in(select id from gtt_num_id)
		minus        
		select gif2.gene_oid
		from gene_ko_terms gif2, dt_func_combo_genes_4ko dtg2
		where gif2.gene_oid = dtg2.gene_oid
		and dtg2.combo_oid in(select id from gtt_num_id))
		group by dtg4.combo_oid
    };
    #print "getComboGeneCntNoTerm \$sql: $sql<br/>";    
    #push(@bindList, $term_oid);
    #push(@bindList, $term_oid);

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my %hash;
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub getComboDetailFusionCnt {
    my ( $dbh, $term_oid ) = @_;

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
	    select dtg.combo_oid, count(distinct g.gene_oid)
		from gene_ko_terms g, dt_func_combo_genes_4ko dtg, gene_fusion_components gfc
		where g.gene_oid = dtg.gene_oid
		and g.ko_terms = ?
		and gfc.gene_oid = g.gene_oid
		$rclause
		$imgClause
		group by dtg.combo_oid
    };
    #print "getComboDetailFusionCnt \$sql: $sql<br/>";    
    my @a = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@a, @bindList_ur);
    }

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my %hash;
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# print comdo detail table
sub printComboDetail {
    my $term_oid = param("term_oid");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my ( $name, $defn ) = getTermName( $dbh, $term_oid );
    print qq{
      <h1> Details of KO Term Distribution across Protein Families</h1>
      <p>
      <b>
      $term_oid <br/>
      $name <br/>
      $defn <br/>
      </b>
      </p>
    };

    printStartWorkingDiv();
    print "Getting combos.<br/>\n";

    # (\@res, \%distinct_cog, \%distinct_pfam, \%distinct_tigrfam);
    my (
         $terms_aref,         $distinct_cog_href,
         $distinct_pfam_href, $distinct_tigrfam_href
      )
      = getCombo( $dbh, $term_oid );

    print "Getting function names.<br/>\n";

    # cog
    my $cog_name_href = QueryUtil::getCogNames( $dbh, $distinct_cog_href );

    # pfam
    my $pfam_name_href = QueryUtil::getPfamNames( $dbh, $distinct_pfam_href );

    # tigrfam
    my $tigrfam_name_href = QueryUtil::getTigrfamNames( $dbh, $distinct_tigrfam_href );

    print "Getting combos counts.<br/>\n";
    my $gene_cnt_href = getComboGeneCnt( $dbh, $term_oid );
    
    # get list of combo ids
    my @comboIds = keys %$gene_cnt_href;

    # insert combo ids 
    OracleUtil::insertDataArray($dbh, 'gtt_num_id', \@comboIds);
    
    print "Getting combos other gene counts.<br/>\n";
    my $other_gene_cnt_href = getComboGeneCntOther( $dbh, $term_oid );

    print "Getting combos other gene counts ignore in genes.<br/>\n";
    my $other_gene_cnt_href2 = getComboGeneCntOther2( $dbh, $term_oid );

    #print "Getting combos total gene counts.<br/>\n";
    #my $total_gene_cnt_href = getComboTotalGeneCnt( $dbh, $term_oid );
    print "Getting combos gene counts with no ko terms.<br/>\n";
    my $noterm_gene_cnt_href = getComboGeneCntNoTerm( $dbh, $term_oid );

    print "Getting fusion count.<br/>\n";
    my $fusion_cnt_href = getComboDetailFusionCnt( $dbh, $term_oid );
    if($img_ken) {
        printEndWorkingDiv('', 1);
    } else {
        printEndWorkingDiv();
    }

    # get filters
    my @filter_cog = param("cog");
    my %filter_cog_h;
    my @filter_pfam = param("pfam");
    my %filter_pfam_h;
    my @filter_tigrfam = param("tigrfam");
    my %filter_tigrfam_h;
    foreach my $id (@filter_cog) {
        $filter_cog_h{$id} = 1;
    }
    foreach my $id (@filter_pfam) {
        $filter_pfam_h{$id} = 1;
    }
    foreach my $id (@filter_tigrfam) {
        $filter_tigrfam_h{$id} = 1;
    }

    my $it = new InnerTable( 1, "kotermcombo$$", "kotermcombo", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Combo ID",    "number asc", "right" );
    $it->addColSpec( "COG IDs",     "char asc",   "left" );
    $it->addColSpec( "Pfam IDs",    "char asc",   "left" );
    $it->addColSpec( "TIGRfam IDs", "char asc",   "left" );
    $it->addColSpec(
               "Number of Genes<br/>with Protein Family Combo<br/> and KO Term",
               "number desc", "right" );
    $it->addColSpec( "Num of Fusion Genes", "number desc", "right" );
    $it->addColSpec(
"Number of Genes<br/> with Protein Family Combo<br/> and Different KO Term",
        "number desc",
        "right"
    );
    $it->addColSpec(
"Number of Genes <br/>with Protein Family Combo<br/> Without Query KO Term <br/> and With Different KO Term",
        "number desc",
        "right"
    );
    $it->addColSpec(
           "Number of Genes <br/>with Protein Family Combo<br/> and no KO Term",
           "number desc", "right" );

    my $count = 0;
    foreach my $line (@$terms_aref) {
        my ( $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids ) =
          split( /\t/, $line );

        if (    keys %filter_cog_h > 0
             || keys %filter_pfam_h > 0
             || %filter_tigrfam_h > 0 )
        {
            my $match_filter = 0;

            # check cog filter
            foreach my $id ( keys %filter_cog_h ) {
                if ( $cog_ids =~ $id ) {
                    $match_filter = 1;
                    my $hlight = "<font color='red'> $id </font>";
                    $cog_ids =~ s/$id/$hlight/;
                }
            }

            # check pfam filter
            foreach my $id ( keys %filter_pfam_h ) {
                if ( $pfam_ids =~ $id ) {
                    $match_filter = 1;
                    my $hlight = "<font color='red'> $id </font>";
                    $pfam_ids =~ s/$id/$hlight/;
                }
            }

            # check tigrfam
            foreach my $id ( keys %filter_tigrfam_h ) {
                if ( $tigrfam_ids =~ $id ) {
                    $match_filter = 1;
                    my $hlight = "<font color='red'> $id </font>";
                    $tigrfam_ids =~ s/$id/$hlight/;
                }
            }

            next if ( $match_filter == 0 );
        }

        my $gene_count       = $gene_cnt_href->{$combo_oid};
        my $other_gene_count = $other_gene_cnt_href->{$combo_oid};
        $other_gene_count = 0 if ( $other_gene_count eq "" );

        my $other_gene_count2 = $other_gene_cnt_href2->{$combo_oid};
        $other_gene_count2 = 0 if ( $other_gene_count2 eq "" );

        #my $total = $total_gene_cnt_href->{$combo_oid};
        #$total = 0 if ( $total eq "" );
        #my $total_no_term = $total - $gene_count - $other_gene_count;
        #$total_no_term = "$total - $gene_count - $other_gene_count"
        #  if ( $total_no_term < 0 );
        my $total_no_term = $noterm_gene_cnt_href->{$combo_oid};
        $total_no_term = 0 if ( $total_no_term eq "" );

        my $fusion_cnt = $fusion_cnt_href->{$combo_oid};
        $fusion_cnt = 0 if ( $fusion_cnt eq "" );

        my $r;
        $r .= $combo_oid . $sd . $combo_oid . "\t";
        $r .= $cog_ids . $sd . $cog_ids . "\t";
        $r .= $pfam_ids . $sd . $pfam_ids . "\t";
        $r .= $tigrfam_ids . $sd . $tigrfam_ids . "\t";

        #combogenelist
        if ( $gene_count > 0 ) {
            my $url =
                $section_cgi
              . "&page=combogenelist"
              . "&term_oid=$term_oid"
              . "&combo_oid=$combo_oid";
            $url = alink( $url, $gene_count );
            $r .= $gene_count . $sd . $url . "\t";
        } else {
            $r .= $gene_count . $sd . $gene_count . "\t";
        }

        # fusion count
        if ( $fusion_cnt > 0 ) {
            my $url =
                $section_cgi
              . "&page=combogenelistfusion"
              . "&term_oid=$term_oid"
              . "&combo_oid=$combo_oid";
            $url = alink( $url, $fusion_cnt );
            $r .= $fusion_cnt . $sd . $url . "\t";
        } else {
            $r .= $fusion_cnt . $sd . $fusion_cnt . "\t";
        }

        #combogenelistother
        if ( $other_gene_count > 0 ) {
            my $url =
                $section_cgi
              . "&page=combogenelistother"
              . "&term_oid=$term_oid"
              . "&combo_oid=$combo_oid";
            $url = alink( $url, $other_gene_count );
            $r .= $other_gene_count . $sd . $url . "\t";
        } else {
            $r .= $other_gene_count . $sd . $other_gene_count . "\t";
        }

        #combogenelistother2
        if ( $other_gene_count2 > 0 ) {
            my $url =
                $section_cgi
              . "&page=combogenelistother2"
              . "&term_oid=$term_oid"
              . "&combo_oid=$combo_oid";
            $url = alink( $url, $other_gene_count2 );
            $r .= $other_gene_count2 . $sd . $url . "\t";
        } else {
            $r .= $other_gene_count2 . $sd . $other_gene_count2 . "\t";
        }

        #combogenelistno
        if ( $total_no_term > 0 ) {
            my $url =
                $section_cgi
              . "&page=combogenelistno"
              . "&term_oid=$term_oid"
              . "&combo_oid=$combo_oid";
            $url = alink( $url, $total_no_term );
            $r .= $total_no_term . $sd . $url . "\t";
        } else {
            $r .= $total_no_term . $sd . $total_no_term . "\t";
        }

        $it->addRow($r);
        $count++;
    }

    $it->printOuterTable(1);
    #$dbh->disconnect();

    print "<h2>Protein List</h2>\n";
    printMainForm();

    print <<EOF;
    <script language="javascript" type="text/javascript">

function checkBoxes(name, x ) {
   var f = document.mainForm;
   for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];

        if( e.name == name && e.type == "checkbox" ) {
           e.checked = ( x == 0 ? false : true );
        }
   }
}
    </script>
    
EOF

    # section=ImgTermStats&page=combodetail&term_oid=5777
    print hiddenVar( "page",     "combodetail" );
    print hiddenVar( "section",  "KoTermStats" );
    print hiddenVar( "term_oid", $term_oid );

    print "<p>\n";

    #    print qq{
    #        <div STYLE=" height: 200px;  overflow: auto;">
    #        <p>
    #    };
    my $linebreak = 5;
    my $itemcnt   = 0;
    if ( keys %$distinct_cog_href > 0 ) {
        my $cnt = keys %$distinct_cog_href;
        print "<b>COG ($cnt) </b>\n";

        print nbsp(1);
        print "<input type='button' name='checkAll' value='Select All'  "
          . "onClick=\"checkBoxes('cog',1)\" class='tinybutton' />\n";
        print nbsp(1);
        print "<input type='button' name='uncheckAll' value='Clear All'  "
          . "onClick=\"checkBoxes('cog',0)\" class='tinybutton' />\n";
        print "<br/>\n";
        foreach my $id ( sort keys %$distinct_cog_href ) {
            my $title = "title='" . $cog_name_href->{$id} . "'";
            my $url   = "$cog_base_url$id";
            $url = "<a href='$url' $title> $id </a>";
            if ( $itemcnt >= $linebreak ) {
                print "<br/>\n";
                $itemcnt = 0;
            }

            my $ck = "checked" if ( exists $filter_cog_h{$id} );
            print "<input type='checkbox' name='cog' "
              . "value='$id' $ck $title/> &nbsp; $url &nbsp;&nbsp;\n";
            $itemcnt++;
        }
    }

    print "<br/>\n";

    $itemcnt = 0;
    if ( keys %$distinct_pfam_href > 0 ) {
        my $cnt = keys %$distinct_pfam_href;
        print "<br/><b>Pfam ($cnt) </b>\n";

        print nbsp(1);
        print "<input type='button' name='checkAll' value='Select All'  "
          . "onClick=\"checkBoxes('pfam',1)\" class='tinybutton' />\n";
        print nbsp(1);
        print "<input type='button' name='uncheckAll' value='Clear All'  "
          . "onClick=\"checkBoxes('pfam',0)\" class='tinybutton' />\n";
        print "<br/>\n";
        foreach my $id ( sort keys %$distinct_pfam_href ) {
            my $title = "title='" . $pfam_name_href->{$id} . "'";
            my $id2   = $id;
            $id2 =~ s/pfam/PF/;
            my $url = "$pfam_base_url$id2";
            $url = "<a href='$url' $title> $id </a>";
            if ( $itemcnt >= $linebreak ) {
                print "<br/>\n";
                $itemcnt = 0;
            }

            my $ck = "checked" if ( exists $filter_pfam_h{$id} );
            print "<input type='checkbox' name='pfam' "
              . "value='$id' $ck $title/> &nbsp; $url &nbsp;&nbsp;\n";
            $itemcnt++;
        }
    }

    print "<br/>\n";

    $itemcnt = 0;
    if ( keys %$distinct_tigrfam_href > 0 ) {
        my $cnt = keys %$distinct_tigrfam_href;
        print "<br/><b>TIGRfam ($cnt) </b>\n";

        print nbsp(1);
        print "<input type='button' name='checkAll' value='Select All'  "
          . "onClick=\"checkBoxes('tigrfam',1)\" class='tinybutton' />\n";
        print nbsp(1);
        print "<input type='button' name='uncheckAll' value='Clear All'  "
          . "onClick=\"checkBoxes('tigrfam',0)\" class='tinybutton' />\n";
        print "<br/>\n";
        foreach my $id ( sort keys %$distinct_tigrfam_href ) {
            my $title = "title='" . $tigrfam_name_href->{$id} . "'";
            my $url   = "$tigrfam_base_url$id";
            $url = "<a href='$url' $title> $id </a>";
            if ( $itemcnt >= $linebreak ) {
                print "<br/>\n";
                $itemcnt = 0;
            }

            my $ck = "checked" if ( exists $filter_tigrfam_h{$id} );
            print "<input type='checkbox' name='tigrfam' "
              . "value='$id' $ck $title/> &nbsp; $url &nbsp;&nbsp;\n";
            $itemcnt++;
        }

    }

    #print "</p></div>\n";
    print "</p>\n";

    print submit(
                  -name  => "_section_KoTermStats_combodetail",
                  -value => "Filter",
                  -class => "meddefbutton"
    );
    print end_form();

    printStatusLine( "$count Loaded.", 2 );
}

sub printComboGeneList {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();
    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    my ( $name, $defn ) = getTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      KO Term Combination Gene List
      </h1>  
      <p>
      <b>
      $name 
      <br/>
      $defn
      </b>
      </p>
    };

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct gif.gene_oid, g.gene_display_name
		from gene_ko_terms gif, dt_func_combo_genes_4ko dtg, gene g
		where gif.gene_oid = dtg.gene_oid
		and dtg.combo_oid = ?
		and gif.ko_terms = ?
		and g.gene_oid = gif.gene_oid
		$rclause
		$imgClause
    };
    #print "printComboGeneList \$sql: $sql<br/>";    
    my @bindList = ($combo_oid, $term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }

    printGeneListSectionSorting( $sql, "", "", @bindList );
}

sub printComboGeneListFusion {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();
    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    my ( $name, $defn ) = getTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      KO Term Combination Gene List
      </h1>  
      <p>
      <b>
      $name 
      <br/>
      $defn
      </b>
      </p>
    };

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct gif.gene_oid, g.gene_display_name
		from gene_ko_terms gif, dt_func_combo_genes_4ko dtg, gene g,
		gene_fusion_components gfc
		where gif.gene_oid = dtg.gene_oid
		and dtg.combo_oid = ?
		and gif.ko_terms = ?
		and g.gene_oid = gif.gene_oid
		and gfc.gene_oid = gif.gene_oid
		$rclause
		$imgClause
    };
    #print "printComboGeneListFusion \$sql: $sql<br/>";    
    my @bindList = ($combo_oid, $term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }

    printGeneListSectionSorting( $sql, "", "", @bindList );
}

sub printComboGeneListOther {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    print qq{
      <h1>
      KO Term Combo Gene List<br/>
      with other KO Terms
      </h1>  
    };
    
    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct gif2.gene_oid, g.gene_display_name
		from gene_ko_terms gif2, dt_func_combo_genes_4ko dtg2, gene g
		where gif2.gene_oid = dtg2.gene_oid
		and dtg2.combo_oid = ? 
		and gif2.ko_terms != ?
		and gif2.gene_oid = g.gene_oid
		$rclause
		$imgClause
    };
    #print "printComboGeneListOther \$sql: $sql<br/>";    
    my @bindList = ($combo_oid, $term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }

    printGeneListSectionSorting( $sql, "", "", @bindList );
}

sub printComboGeneListOther2 {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();
    my ( $name, $defn ) = getTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    print qq{
      <h1>
      Number of Genes with Protein Family Combo<br/>
      Without Query KO Term<br/>
      and With Different KO Term
      </h1>
       <p>
       $term_oid <br/>
       $name <br/> 
       $defn
       </p>
    };

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct gif2.gene_oid, g.gene_display_name
		from gene_ko_terms gif2, dt_func_combo_genes_4ko dtg2, gene g
		where gif2.gene_oid = dtg2.gene_oid
		and dtg2.combo_oid = ? 
		and gif2.ko_terms != ?
		and gif2.gene_oid = g.gene_oid
		$rclause
		$imgClause
		minus
		select gif3.gene_oid, g3.gene_display_name
		from gene_ko_terms gif3, dt_func_combo_genes_4ko dtg3, gene g3
		where gif3.gene_oid = dtg3.gene_oid
		and dtg3.combo_oid = ? 
		and gif3.ko_terms = ?
		and gif3.gene_oid = g3.gene_oid
    };
    #print "printComboGeneListOther2 \$sql: $sql<br/>";    
    my @bindList = ($combo_oid, $term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }
    push(@bindList, $combo_oid);
    push(@bindList, $term_oid);

    printGeneListSectionSorting( $sql, "", "", @bindList );
}

sub printComboGeneListNoTerm {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    print qq{
      <h1>
      Combination Gene List<br/>
      with No KO Terms
      </h1>  
    };
    
    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct g.gene_oid, g.gene_display_name
		from dt_func_combo_genes_4ko dtg, gene g
		where dtg.gene_oid = g.gene_oid
		and dtg.combo_oid = ? 
		$rclause
		$imgClause
		minus        
		select gif2.gene_oid, g2.gene_display_name
		from gene_ko_terms gif2, dt_func_combo_genes_4ko dtg2, gene g2
		where gif2.gene_oid = dtg2.gene_oid
		and dtg2.combo_oid = ? 
		and gif2.gene_oid = g2.gene_oid
    };
    #print "printComboGeneListNoTerm \$sql: $sql<br/>";    
    my @bindList = ($combo_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }
    push(@bindList, $combo_oid);

    printGeneListSectionSorting( $sql, "", "", @bindList );
}

sub printKoGeneList {
    my $term_oid = param("term_oid");
    my $gcnt = param("gcnt");

    my $dbh = dbLogin();
    #$term_oid =~ s/'/''/g;

    my ( $name, $defn ) = getTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      KO Term Gene List
      </h1>  
      <p>
      <b>
      $name 
      <br/>
      $defn
      </b>
      </p>
    };

    my ($rclause, @bindList_ur) = urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
		select distinct gif.gene_oid
		from gene_ko_terms gif, gene g
		where gif.gene_oid = g.gene_oid
		and gif.ko_terms = ?
		$rclause
		$imgClause
    };
    #print "printKoGeneList \$sql: $sql<br/>";    
    my @bindList = ($term_oid);
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);
    }
    #print "\@bindList: @bindList<br/>";

    my ($count, $s) = TaxonDetailUtil::printGeneListSectionSorting($sql, "", "", @bindList);
    my $diff = $gcnt - $count;
    if ($diff > 0 && $s =~ /^[0-9]*/) {
        $s .= " (You do not have permission on $diff genes.)";
    }
    printStatusLine( $s, 2 );
}

#
# prints gene list with sorting
#
sub printGeneListSectionSorting {
    my ( $sql, $title, $notitlehtmlesc, @binds ) = @_;

    printMainForm();
    if ( $title ne "" ) {
        print "<h1> \n";
        if ( defined $notitlehtmlesc ) {
            print $title . "\n";
        } else {
            print escHtml($title) . "\n";
        }
        print "</h1>\n";
    }
    printGeneCartFooter();
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my @gene_oids;
    my $count = 0;
    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",       "number asc",  "right" );
    $it->addColSpec( "Locus Tag", "char asc", "left" );
    $it->addColSpec( "Gene Product Name",     "char asc",    "left" );
    $it->addColSpec( "Genome Name",   "char asc",    "left" );
    $it->addColSpec( "COG Count",     "number desc", "right" );
    $it->addColSpec( "Pfam Count",    "number desc", "right" );
    $it->addColSpec( "TIGRfam Count", "number desc", "right" );
    $it->addColSpec( "Fusion",        "char asc",    "left" );

    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        if ( scalar(@gene_oids) > $max_gene_batch ) {
            flushGeneBatchSortingLocal( $dbh, \@gene_oids, $it );
            @gene_oids = ();
        }
        push( @gene_oids, $gene_oid );
    }
    flushGeneBatchSortingLocal( $dbh, \@gene_oids, $it );

    $it->printOuterTable(1);
    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();
    print end_form();

}

#
# a html table with sorting
#
sub flushGeneBatchSortingLocal {
    my ( $dbh, $gene_oids_ref, $it ) = @_;
    my @gene_oids    = param("gene_oid");
    my %geneOids     = WebUtil::array2Hash(@gene_oids);
    my $gene_oid_str = join( ",", @$gene_oids_ref );
    return if blankStr($gene_oid_str);

    my $term_oid = param("term_oid");

    # cog count
    my %gene_cog;
    my $sql = qq{
       select gene_oid, count(*)
       from gene_cog_groups
       where gene_oid in ( $gene_oid_str )
       group by gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_cog{$gene_oid} = $cnt;
    }
    $cur->finish();

    # pfam count
    my %gene_pfam;
    my $sql = qq{
       select gene_oid, count(*)
       from gene_pfam_families
       where gene_oid in ( $gene_oid_str )
       group by gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_pfam{$gene_oid} = $cnt;
    }
    $cur->finish();

    # tigrfam count
    my %gene_tigrfam;
    my $sql = qq{
       select gene_oid, count(*)
       from gene_tigrfams
       where gene_oid in ( $gene_oid_str )
       group by gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_tigrfam{$gene_oid} = $cnt;
    }
    $cur->finish();

    # fusion gene list
    my %gene_fusion;
    my $sql = qq{
       select gfc.gene_oid
       from gene_fusion_components gfc
       where gfc.gene_oid in ( $gene_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_fusion{$gene_oid} = 1;
    }
    $cur->finish();

    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_tag, g.locus_type, 
           tx.taxon_oid, tx.ncbi_taxon_id, 
           tx.taxon_display_name, tx.genus, tx.species, 
           g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
       from taxon tx, scaffold scf, scaffold_stats ss, gene g
       where g.taxon = tx.taxon_oid
       and g.gene_oid in ( $gene_oid_str )
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       
   };
    # order by tx.taxon_display_name, g.gene_oid
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
             $gene_oid,           $gene_display_name, $gene_symbol,
             $locus_tag,          $locus_type,         
             $taxon_oid,          $ncbi_taxon_id,
             $taxon_display_name, $genus,             $species,
             $aa_seq_length,      $seq_status,
             $ext_accession,      $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_tag\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }

    # now print soriing html
    my $sd = $it->getSdDelim();

    my %done;
    for my $r (@recs) {
        my (
             $gene_oid,           $gene_display_name, $gene_symbol,
             $locus_tag,          $locus_type,        
             $taxon_oid,          $ncbi_taxon_id,
             $taxon_display_name, $genus,             $species,
             $aa_seq_length,      $seq_status,
             $ext_accession,      $seq_length
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        my $ck = "checked" if $geneOids{$gene_oid} ne "";

        my $r;
        $r .= $sd
          . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck /> \t";

        my $url =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        $r .=
          $gene_oid . $sd . "<a href='" . $url . "'>  $gene_oid </a>" . "\t";

        $r .= $locus_tag . $sd . "$locus_tag\t";
          
        my $seqLen;

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }

        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }

        my $tmpname = " ${seqLen} $scfInfo";
        if ( $gene_display_name ne "" ) {
            $tmpname = $gene_display_name . $tmpname;
        }
        $r .= $tmpname . $sd . "\t";

        my $url =
          "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $url = alink( $url, "$taxon_display_name" );
        $r .= $taxon_display_name . $sd . $url . "\t";

        # function counts
        if ( exists $gene_cog{$gene_oid} ) {
            $r .= $gene_cog{$gene_oid} . $sd . $gene_cog{$gene_oid} . "\t";
        } else {
            $r .= 0 . $sd . 0 . "\t";
        }
        if ( exists $gene_pfam{$gene_oid} ) {
            $r .= $gene_pfam{$gene_oid} . $sd . $gene_pfam{$gene_oid} . "\t";
        } else {
            $r .= 0 . $sd . 0 . "\t";
        }
        if ( exists $gene_tigrfam{$gene_oid} ) {
            $r .=
              $gene_tigrfam{$gene_oid} . $sd . $gene_tigrfam{$gene_oid} . "\t";
        } else {
            $r .= 0 . $sd . 0 . "\t";
        }

        if ( exists $gene_fusion{$gene_oid} ) {
            $r .= "Yes" . $sd . "Yes" . "\t";
        } else {
            $r .= "No" . $sd . "No" . "\t";
        }

        $it->addRow($r);

        $done{$gene_oid} = 1;
    }
    $cur->finish();

}

1;

