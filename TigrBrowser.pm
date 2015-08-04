############################################################################
# TigrBrowser.pm - TIGRfam browser.
#   --es 03/22/2006
#
# $Id: TigrBrowser.pm 33689 2015-07-06 07:49:51Z jinghuahuang $
############################################################################
package TigrBrowser;
my $section = "TigrBrowser";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use CachedTable;
use GeneDetail;
use PhyloTreeMgr;
use WebConfig;
use WebUtil;
use HtmlUtil;
use InnerTable;
use MetaUtil;
use MetaGeneTable;
use MerFsUtil;
use WorkspaceUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $tmp_dir              = $env->{tmp_dir};
my $max_gene_batch       = 100;
my $max_taxon_batch      = 20;
my $max_scaffold_batch   = 20;
my $tigrfam_base_url     = $env->{tigrfam_base_url};
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $show_private         = $env->{show_private};

my $new_func_count       = $env->{new_func_count};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "tigrBrowser" ) {
        printTigrBrowser();
    }
    elsif ( $page eq "tigrRoleDetail" ) {
        my $show_counts = param('show_counts');
	printTigrRoleDetail();
    }
    elsif ( $page eq "tigrRoleGenomeList" ) {
        printTigrRoleGenomeList();
    }
    elsif ( $page eq "tigrRolePhyloDist" ) {
        printTigrRolePhyloDist();
    }
    elsif ( $page eq "tigrRoleGenomeGeneList" ) {
        printTigrRoleGenomeGeneList();
    }
    elsif ( $page eq "tigrfamList" ) {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        my $show_counts = param('show_counts');
	printTigrfamList();

        HtmlUtil::cgiCacheStop();
    }
    else {
        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;
        printTigrBrowser();
        HtmlUtil::cgiCacheStop();
    }
}

############################################################################
# printTigrBrowser - Print TIGRfam browser list.
############################################################################
sub printTigrBrowser {
    printStatusLine( "Loading ...", 1 );

    print "<h1>TIGRfam Roles</h1>\n";

    my $dbh = dbLogin();
    my $sql = qq{
        select count(*)
        from gene_tigrfams gtf
        where rownum < 2
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $cnt = $cur->fetchrow();
    $cur->finish();
    if ( $cnt == 0 ) {
        print "<div id='message'>\n";
        print "<p>\n";
        print "This database has no TIGRfam annotations.\n";
        print "</p>\n";
        print "</div>\n";
        #$dbh->disconnect();
        return;
    }
    my $sql = qq{
	select tr.role_id, tr.main_role, tr.sub_role
        from tigr_role tr
        order by tr.main_role, tr.sub_role
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $last_main_role;
    print "<p>\n";

    print "<b>All TIGRfams</b><br/>\n";
    my $url = "$section_cgi&page=tigrfamList";
    print nbsp(4);
    print alink( $url, "TIGRfam List" );
    print "<br/>\n";
    print "<br/>\n";

    my %sub_role_set;
    my $count = 0;
    for ( ; ; ) {
        my ( $role_id, $main_role, $sub_role ) = $cur->fetchrow();
        last if !$role_id;
        next if $sub_role eq "";

        $sub_role_set{$sub_role} = "";
        $count++;
        if ( $last_main_role ne $main_role ) {
            print "<br/>\n" if $count > 1;
            print "<b>\n";
            print escHtml($main_role);
            print "</b>\n";
            print "<br/>\n";
        }
        my $url = "$section_cgi&page=tigrRoleDetail&role_id=$role_id";
        print nbsp(4);
        print alink( $url, $sub_role );
        print "<br/>\n";
        $last_main_role = $main_role;
    }
    print "</p>\n";
    $cur->finish();

    #$dbh->disconnect();
    my $tmpcnt = keys %sub_role_set;
    printStatusLine( "$tmpcnt Loaded.", 2 );
}

############################################################################
# printTigrRoleDetail - Print details for given role.
############################################################################
sub printTigrRoleDetail {
    my $role_id = param("role_id");

    print "<h1>TIGRfam Role</h1>";
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $sql = qq{
       select tr.sub_role
       from tigr_role tr
       where tr.role_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $role_id );
    my $sub_role = $cur->fetchrow();
    $cur->finish();

    my $taxonClause = WebUtil::txsClause( "gt.taxon_oid", $dbh );

    print "<p>\n";
    print "Details for role <i>" . escHtml($sub_role) . "</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause ne "";
    print "</p>\n";

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }

    my %tigr_cnts;
    my %m_tigr_cnts;
    my %tigrfam_h;

    printStartWorkingDiv();

    print "<p>Counting isolate genomes ...<br/>\n";

    my $sql = qq{
        select tf.ext_accession, tf.expanded_name 
        from tigrfam_roles tr, tigrfam tf 
        where tr.roles = ? 
        and tr.ext_accession = tf.ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $role_id );
    for ( ; ; ) {
        my ( $id2, $name2 ) = $cur->fetchrow();
        last if !$id2;
        $tigrfam_h{$id2} = $name2;
    }
    $cur->finish();

    my $rclause = WebUtil::urClause( "gt.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "gt.taxon_oid", 1 );

    my $sql = qq{
        select tr.ext_accession, count(distinct gt.taxon_oid)
        from mv_taxon_tfam_stat gt, tigrfam_roles tr
        where tr.roles = ?
        and tr.ext_accession = gt.ext_accession
        $taxonClause
        $rclause
        $imgClause
        group by tr.ext_accession
    };
    $cur = execSql( $dbh, $sql, $verbose, $role_id );
    for ( ; ; ) {
	my ( $ext_accession, $cnt ) = $cur->fetchrow();
	last if !$ext_accession;
	$tigr_cnts{$ext_accession} = $cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...<br/>\n";

        my $imgClause = WebUtil::imgClauseNoTaxon( "gt.taxon_oid", 2 );
	my $sql = qq{
            select tr.ext_accession, count(distinct gt.taxon_oid)
            from mv_taxon_tfam_stat gt, tigrfam_roles tr
            where tr.roles = ?
            and tr.ext_accession = gt.ext_accession
            $taxonClause
            $rclause
            $imgClause
            group by tr.ext_accession
        };
        $cur = execSql( $dbh, $sql, $verbose, $role_id );
        for ( ; ; ) {
            my ( $ext_accession, $cnt ) = $cur->fetchrow();
            last if !$ext_accession;
            $m_tigr_cnts{$ext_accession} = $cnt;
        }
        $cur->finish();

        print "<p>Counting MER-FS metagenomes ...<br/>\n";
	if ( $new_func_count ) {
	    ## use the new taxon func count table
	    my $rclause2 = WebUtil::urClause( "f.taxon_oid" );
	    my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
	    my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

	    foreach my $tigr_id ( sort ( keys %tigrfam_h ) ) {
		print "Retrieving gene count for $tigr_id ...<br/>\n";
 
		$sql = qq{ 
                    select count(distinct f.taxon_oid)
                    from taxon_tigr_count f
                    where f.gene_count > 0
                    and f.func_id = ? 
                    $rclause2 
                    $imgClause2
                    $taxonClause2
                }; 

		$cur  = execSql( $dbh, $sql, $verbose, $tigr_id );
		my ( $t_cnt ) = $cur->fetchrow();
		next if !$t_cnt;
 
		if ( $m_tigr_cnts{$tigr_id} ) { 
		    $m_tigr_cnts{$tigr_id} += $t_cnt;
		} 
		else { 
		    $m_tigr_cnts{$tigr_id} = $t_cnt;
		} 
	    }
	    $cur->finish();
	    print "<br/>\n";
	
	} else {
	    ## use files
	    $sql  = MerFsUtil::getTaxonsInFileSql();
	    $sql .= " and t.genome_type = 'metagenome' ";
	    $cur  = execSql( $dbh, $sql, $verbose ); 
	    for ( ;; ) { 
		my ($t_oid) = $cur->fetchrow(); 
		last if !$t_oid; 
 
		print ". "; 
		my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'tigr' ); 
		foreach my $tigr_id ( keys %funcs ) { 
		    if ( $tigrfam_h{$tigr_id} ) { 
			if ( $m_tigr_cnts{$tigr_id} ) { 
			    $m_tigr_cnts{$tigr_id} += 1; 
			} 
			else { 
			    $m_tigr_cnts{$tigr_id} = 1; 
			} 
		    } 
		} 
	    } 
	    $cur->finish(); 
	    print "<br/>\n";
	}
    }

    printEndWorkingDiv();
    #$dbh->disconnect();

    if ( $sid == 312 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    my $baseUrl = "$section_cgi&page=tigrRoleDetail&role_id=$role_id";

    my $hasIsolates = scalar (keys %tigr_cnts) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_tigr_cnts) > 0 ? 1 : 0;

    my $ct = new CachedTable( "tigrfam$role_id", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $ct->addColSpec( "Select" );
    $ct->addColSpec( "TIGRfam ID",    "asc", "left" );
    $ct->addColSpec( "Expanded Name", "asc", "left" );
    if ($include_metagenomes) {
        $ct->addColSpec( "Isolate<br/>Genome Count", "desc", "right" )
	    if $hasIsolates;
        $ct->addColSpec( "Metagenome<br/>Count", "asc",  "right" )
	    if $hasMetagenomes;
    } else {
        $ct->addColSpec( "Genome<br/>Count", "desc", "right" )
	    if $hasIsolates;
    }

    my $select_id_name = "tigrfam_id";
    my $count   = 0;
    foreach my $ext_accession ( keys %tigrfam_h ) {
        my $expanded_name = $tigrfam_h{$ext_accession};
        $count++;
        my $r = $sdDelim
          . "<input type='checkbox' "
          . "name='$select_id_name', value='$ext_accession' />\t";
        my $url = "$tigrfam_base_url$ext_accession";
        $r .=
          "$ext_accession" . $sdDelim . alink( $url, $ext_accession ) . "\t";
        $r .= "$expanded_name\t";

        my $cnt = $tigr_cnts{$ext_accession};
	if ($hasIsolates) {
	    if ($cnt) {
		my $url = "$section_cgi&page=tigrRoleGenomeList"
		    . "&role_id=$role_id&tigrfam_id=$ext_accession"
		    . "&gtype=isolate";
		$r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
	    } else {
		$r .= "0" . $sdDelim . "0" . "\t";
	    }
	}

        if ($include_metagenomes) {
            my $m_cnt = $m_tigr_cnts{$ext_accession};
	    if ($hasMetagenomes) {
		if ($m_cnt) {
		    my $m_url = "$section_cgi&page=tigrRoleGenomeList"
			. "&role_id=$role_id&tigrfam_id=$ext_accession"
			. "&gtype=metagenome";
		    $r .= $m_cnt . $sdDelim . alink( $m_url, $m_cnt ) . "\t";
                } else {
                    $r .= "0" . $sdDelim . "0" . "\t";
		}
	    }
        }

        $ct->addRow($r);
    }

    if ( $count == 0 ) {
        print "<div id='message'>\n";
        print "<p>\n";
        print "No annotations were found for this role.\n";
        print "</p>\n";
        print "</div>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }
        
    WebUtil::printFuncCartFooter();
    $ct->printTable();
    WebUtil::printFuncCartFooter();

    printHint( "The TIGRfam cart allows for " 
	     . "phylogenetic profile comparisons." );

    if ( $count > 0 ) {
        print hiddenVar( 'save_func_id_name', 'tigrfam_id' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printTigrRoleDetail2 - Print details for given role.
# (don't show counts)
############################################################################
sub printTigrRoleDetail2 {
    my $role_id = param("role_id");

    print "<h1>TIGRfam Role</h1>";
    printMainForm();

    printHint("Genome and gene counts are not displayed for IMG/M. Click 'view' to see genome or gene list for each individual TIGRfam ID. Click the 'Display TIGRfam Role with genome and gene counts' link to show counts. (slow)");

    my $show_cnt_url =
        "main.cgi?section=TigrBrowser&page=tigrRoleDetail"
      . "&show_counts=1&role_id=$role_id";
    print "<p>"
      . alink( $show_cnt_url,
        "Display TIGRfam Role with genome and gene counts" )
      . " (slow)<br/>\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    my $sql = qq{
       select tr.sub_role
       from tigr_role tr
       where tr.role_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $role_id );
    my $sub_role = $cur->fetchrow();
    $cur->finish();

    print "<p>\n";
    print "Details for role <i>" . escHtml($sub_role) . "</i><br/>";
    print "</p>\n";

    my %tigr_cnts;
    my %m_tigr_cnts;
    my %tigrfam_h;

    my $sql = qq{
        select tf.ext_accession, tf.expanded_name 
        from tigrfam_roles tr, tigrfam tf 
        where tr.roles = ? 
        and tr.ext_accession = tf.ext_accession"
    };
    my $cur = execSql( $dbh, $sql, $verbose, $role_id );
    for ( ; ; ) {
        my ( $id2, $name2 ) = $cur->fetchrow();
        last if !$id2;
        $tigrfam_h{$id2} = $name2;
    }
    $cur->finish();
    #$dbh->disconnect();

    my $baseUrl = "$section_cgi&page=tigrRoleDetail&role_id=$role_id";

    my $ct = new CachedTable( "tigrfam$role_id", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $ct->addColSpec( "Select" );
    $ct->addColSpec( "TIGRfam ID",    "asc", "left" );
    $ct->addColSpec( "Expanded Name", "asc", "left" );
    if ($include_metagenomes) {
        $ct->addColSpec( "Isolate<br/>Genome Count", "desc", "right" );
        $ct->addColSpec( "Metagenome<br/>Count",     "asc",  "right" );
    } else {
        $ct->addColSpec( "Genome<br/>Count", "desc", "right" );
    }

    my $select_id_name = "tigrfam_id";
    my $count = 0;
    foreach my $ext_accession ( keys %tigrfam_h ) {
        my $expanded_name = $tigrfam_h{$ext_accession};
        $count++;
        my $r = $sdDelim
          . "<input type='checkbox' "
          . "name='$select_id_name', value='$ext_accession' />\t";
        my $url = "$tigrfam_base_url$ext_accession";
        $r .=
          "$ext_accession" . $sdDelim . alink( $url, $ext_accession ) . "\t";
        $r .= "$expanded_name\t";

        my $cnt = "view";
        my $url = "$section_cgi&page=tigrRoleGenomeList";
        $url .= "&role_id=$role_id&tigrfam_id=$ext_accession&gtype=isolate";
        $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";

        if ($include_metagenomes) {
            my $m_cnt = "view";
            my $m_url = "$section_cgi&page=tigrRoleGenomeList";
            $m_url .=
              "&role_id=$role_id&tigrfam_id=$ext_accession&gtype=metagenome";
            $r .= $m_cnt . $sdDelim . alink( $m_url, $m_cnt ) . "\t";
        }

        $ct->addRow($r);
    }

    if ( $count == 0 ) {
        print "<div id='message'>\n";
        print "<p>\n";
        print "No annotations were found for this role.\n";
        print "</p>\n";
        print "</div>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }

    WebUtil::printFuncCartFooter();
    $ct->printTable();
    WebUtil::printFuncCartFooter();

    printHint("The TIGRfam cart allows for "
	    . "phylogenetic profile comparisons." );

    ## save to workspace
    if ( $count > 0 ) {
        print hiddenVar( 'save_func_id_name', 'tigrfam_id' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printTigrRoleGenomeList - Print genome list for selected tigrfam.
############################################################################
sub printTigrRoleGenomeList {
    my $role_id    = param("role_id");
    my $tigrfam_id = param("tigrfam_id");
    my $gtype      = param('gtype');
    if ( !$gtype ) {
        $gtype = 'isolate';
    }

    if ( $gtype eq 'metagenome' ) {
        print "<h1>Metagenomes with $tigrfam_id</h1>\n";
    } else {
        print "<h1>Isolate Genomes with $tigrfam_id</h1>\n";
    }

    my $dbh = dbLogin();
    my $sql = qq{
        select tf.expanded_name
    	from tigrfam tf
    	where tf.ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );
    my $expanded_name = $cur->fetchrow();
    $cur->finish();

    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $taxonClause = WebUtil::txsClause("tx", $dbh);

    print "<p>\n";
    print "Genomes with <i>" . escHtml($expanded_name) . "</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause ne "";
    print "</p>\n";

    printMainForm();

    my $url = "$section_cgi&page=tigrRolePhyloDist";
    $url .= "&role_id=$role_id" if ( $role_id ne '' );
    $url .= "&tigrfam_id=$tigrfam_id"
	  . "&gtype=$gtype";
    print buttonUrl( $url, "Phylogenetic Distribution", "medbutton" );

    my $domain_clause = "";
    my $andClause = "";
    if ( $gtype eq 'metagenome' ) {
        $domain_clause = " and tx.genome_type = 'metagenome'";
        $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 2 );
        $andClause = " where tx.genome_type = 'metagenome'";
    } else {
        $domain_clause = " and tx.genome_type = 'isolate'";
        $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 1 );
        $andClause = " where tx.genome_type = 'isolate'";
    }

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start time: " . currDateTime() . "\n";
    }

    printStartWorkingDiv();
    print "Retrieving genome information from database ... <br/>\n";

    my $sql = qq{
        select tx.domain, tx.seq_status, tx.taxon_oid,
               tx.taxon_display_name, g.gene_count
        from mv_taxon_tfam_stat g, taxon tx
        where g.ext_accession = ?
        and g.taxon_oid = tx.taxon_oid
        and obsolete_flag = 'No'
        $domain_clause
        $rclause
        $imgClause
        $taxonClause
    };

    $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );

    my $baseUrl = "$section_cgi&page=tigrRoleGenomeList";
    $baseUrl .= "&role_id=$role_id";
    $baseUrl .= "&tigrfam_id=$tigrfam_id";

    my $ct = new CachedTable( "tigrGenomes$tigrfam_id", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $ct->addColSpec( "Select" );
    $ct->addColSpec( "Domain", "asc", "center", "",
"*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses"
    );
    $ct->addColSpec( "Status", "asc", "center", "",
        "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $ct->addColSpec( "Genome",     "asc",  "left" );
    $ct->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "taxon_filter_oid";
    my $count = 0;
    for ( ; ; ) {
        my ( $domain, $seq_status, $taxon_oid, $taxon_display_name, $cnt )
            = $cur->fetchrow();
        last if !$taxon_oid;

        $count++;

        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";

        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $taxon_display_name . $sdDelim
	    . alink( $url, $taxon_display_name ) . "\t";

        $url = "$section_cgi&page=tigrRoleGenomeGeneList";
        $url .= "&tigrfam_id=$tigrfam_id";
        $url .= "&taxon_oid=$taxon_oid";
        $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";

        $ct->addRow($r);
    }
    $cur->finish();

    my $m_count = 0;
    if ( $gtype eq 'metagenome' ) {
        # count MER-FS
        print "<p>Retrieving gene counts from ...<br/>\n";

	my %gene_func_count;
	if ( $new_func_count ) {
            my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
            my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
            my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

            my $sql3 = qq{
                select f.taxon_oid, f.gene_count
                from taxon_tigr_count f, taxon tx
                where f.func_id = ?
                and f.taxon_oid = tx.taxon_oid
                $rclause2 $imgClause2 $taxonClause2 $domain_clause
            };

	    my $cur3 = execSql( $dbh, $sql3, $verbose, $tigrfam_id );
	    for ( ;; ) {
		my ( $tid3, $cnt3 ) = $cur3->fetchrow();
		last if ! $tid3;

		if ( $gene_func_count{$tid3} ) {
		    $gene_func_count{$tid3} += $cnt3;
		}
		else {
		    $gene_func_count{$tid3} = $cnt3;
		}
	    }
	    $cur3->finish();
	}

        my $rclause2   = WebUtil::urClause("t");
        my $imgClause2 = WebUtil::imgClause("t");
        my $taxonClause2 = WebUtil::txsClause( "t", $dbh );
        my $sql2       = qq{
            select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name
            from taxon t
            where t.in_file = 'Yes'
            and t.genome_type = 'metagenome'
            $rclause2
            $imgClause2
            $taxonClause2
        };

        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ( $t_oid, $domain, $seq_status, $taxon_display_name ) =
              $cur2->fetchrow();
            last if !$t_oid;

	    print ". ";

    	    my $cnt = 0;
    	    if ( $new_func_count ) {
		$cnt = $gene_func_count{$t_oid};
    	    } else {
		$cnt = MetaUtil::getTaxonOneFuncCnt( $t_oid, "", $tigrfam_id );
    	    }

            if ($cnt) {
                $domain     = substr( $domain,     0, 1 );
                $seq_status = substr( $seq_status, 0, 1 );
                my $url = "$main_cgi?section=MetaDetail&page=metaDetail";
                $url .= "&taxon_oid=$t_oid";
                my $r;
                $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$t_oid' /> \t";
                $r .= "$domain\t";
                $r .= "$seq_status\t";
                $r .= $taxon_display_name . $sdDelim
		    . alink( $url, $taxon_display_name ) . "\t";

                my $url = "$section_cgi&page=tigrRoleGenomeGeneList";
                $url .= "&tigrfam_id=$tigrfam_id";
                $url .= "&taxon_oid=$t_oid";
                $r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";

                $ct->addRow($r);
                $count++;
            }
        }
        $cur2->finish();
    }
    #$dbh->disconnect();

    printEndWorkingDiv();

    if ( $sid == 312 ) {
	print "<p>*** end time: " . currDateTime() . "\n";
    }

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";

    if ($count > 10) {
        WebUtil::printGenomeCartFooter();
    }
    $ct->printTable();
    WebUtil::printGenomeCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }
    
    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printTigrRoleGenomeGeneList -  Print genes for genome with TIGRfam.
############################################################################
sub printTigrRoleGenomeGeneList {
    my $tigrfam_id = param("tigrfam_id");
    my $taxon_oid  = param("taxon_oid");

    printMainForm();
    print "<h1>Genes with $tigrfam_id</h1>\n";

    print hiddenVar( 'taxon_oid', $taxon_oid );
    print hiddenVar( 'func_id',   $tigrfam_id );

    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    my $sql =
        "select t.taxon_oid, t.taxon_display_name, t.in_file from taxon t "
      . "where t.taxon_oid = ? "
      . $rclause
      . $imgClause;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $tid, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();

    if ( !$tid ) {
	webError("Cannot find genome $taxon_oid");
        #$dbh->disconnect();
        return;
    }

    my $gene_count     = 0;
    my $show_gene_name = 1;
    my $trunc          = 0;

    require InnerTable;
    my $it = new InnerTable( 1, "tigrGenes$$", "tigrGenes", 1 );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    if ( $in_file eq 'Yes' ) {
        # MER-FS genome
        my %genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, '', $tigrfam_id );
        my @gene_oids      = ( keys %genes );

        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID", "char asc", "left" );
        if ($show_gene_name) {
            $it->addColSpec( "Gene Product Name", "char asc", "left" );
        }
        $it->addColSpec( "Genome ID", "number asc", "right" );
        $it->addColSpec( "Genome Name", "char asc", "left" );

        printStartWorkingDiv();
        print "<p>Retrieving gene information ...<br/>\n";
        foreach my $key (@gene_oids) {
            my $workspace_id = $genes{$key};
            my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

            my $row = $sd
              . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
            $row .=
                $key . $sd
              . "<a href='main.cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$tid"
              . "&data_type=$dt&gene_oid=$key'>$key</a></td>\t";

            if ($show_gene_name) {
                my ( $value, $source ) =
                  MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
                $row .= $value . $sd . $value . "\t";
            }

            $row .= $tid . $sd . $tid . "\t";
            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$tid'>$taxon_name</a></td>\t";

            $it->addRow($row);

            print ". ";
            $gene_count++;
            if ( $gene_count >= $maxGeneListResults ) {
                $trunc = 1;
                last;
            }
        }
        printEndWorkingDiv();
    }
    else {
        my $rclause1   = WebUtil::urClause('g.taxon');
        my $imgClause1 = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql        = qq{
            select  distinct g.gene_oid, g.gene_display_name, g.locus_tag
    		from gene_tigrfams gtf, gene g
    		where gtf.ext_accession = ?
    		and gtf.gene_oid = g.gene_oid
    		and g.taxon = ?
    		and g.locus_type = 'CDS'
    		and g.obsolete_flag = 'No'
    		$rclause1
            $imgClause1
        };

        $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id, $taxon_oid );
        $it->addColSpec("Select");
        $it->addColSpec( "Gene ID",           "char asc", "left" );
        $it->addColSpec( "Locus Tag",         "char asc", "left" );
        $it->addColSpec( "Gene Product Name", "char asc", "left" );
        $it->addColSpec( "Genome ID",         "number asc", "right" );
        $it->addColSpec( "Genome Name",       "char asc", "left" );

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
            $row .= $taxon_oid . $sd . $taxon_oid . "\t";
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

    if ( !$gene_count ) {
        return;
    }

    my $msg = '';
    if ( !$show_gene_name ) {
        $msg = "Gene names are not displayed. Use 'Exapnd Gene Table Display' option below to view detailed gene information.";
        printHint($msg);
    }

    printGeneCartFooter() if ($gene_count > 10);
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ( !$show_gene_name ) {
        printHint($msg);
    }

    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();

        print hiddenVar ( 'data_type', 'both' );
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
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

############################################################################
# printTigrRolePhyloDist - Print phylogenetic distribution for TIGR role.
############################################################################
sub printTigrRolePhyloDist {
    my $role_id    = param("role_id");
    my $tigrfam_id = param("tigrfam_id");
    my $gtype      = param("gtype");
    if ( !$gtype || $gtype eq "") {
        $gtype = 'isolate';
    }

    my $dbh = dbLogin();
    my $sql = qq{
        select tf.expanded_name
    	from tigrfam tf
    	where tf.ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );
    my $name = $cur->fetchrow();
    $cur->finish();

    printMainForm();
    print "<h1>Phylogenetic Distribution for $tigrfam_id</h1>\n";

    my $domain_clause = "";
    my $taxonClause = WebUtil::txsClause("tx", $dbh);

    print "<p>TIGRfam: \n";
    print "<i>".escHtml($name)."</i>";
    if ( $gtype eq 'metagenome' ) {
        $domain_clause = " and tx.genome_type = 'metagenome'";
        print "<br/>*Showing counts for metagenomes in genome cart only"
            if $taxonClause ne "";
        print "<br/>*Showing counts for all metagenomes"
            if $taxonClause eq "";
    } else {
        print "<br/>*Showing counts for genomes in genome cart only"
            if $taxonClause ne "";
        print "<br/>*Showing counts for all genomes"
            if $taxonClause eq "";
        $domain_clause = " and tx.genome_type = 'isolate'";
    }
    if ($taxonClause ne "") {
        print "<br/>(User selected genomes with hits are shown in "
            . "<font color=red>red</font>)<br/>\n";
    } else {
        print "<br/>(Hits are shown in <font color=red>red</font>)<br/>\n";
    }
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    my $taxonClause = WebUtil::txsClause("tx.taxon_oid", $dbh);
    my $rclause     = WebUtil::urClause("tx.taxon_oid");
    my $imgClause   = WebUtil::imgClauseNoTaxon("tx.taxon_oid");

    print "<p>Retrieving information from database ...<br/>\n";

    my $sql = qq{
        select tx.taxon_oid, gt.gene_count
        from mv_taxon_tfam_stat gt, taxon tx
        where gt.ext_accession = ?
        and gt.taxon_oid = tx.taxon_oid
        and tx.obsolete_flag = 'No'
        $taxonClause
        $rclause
        $imgClause
        $domain_clause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tigrfam_id );

    my @taxon_oids;
    my %tx2cnt_href;

    for ( ;; ) {
        my ( $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;

	$tx2cnt_href{ $taxon_oid } = $cnt;
        push( @taxon_oids, $taxon_oid );
    }
    $cur->finish();

    if ($gtype eq "metagenome") {
	my $check_merfs = 1;
	if ( !$include_metagenomes ) {
	    $check_merfs = 0;
	}
	
	if ($check_merfs) {
	    print "<p>Checking MER-FS metagenomes ...<br/>\n";

            my %gene_func_count;
            if ( $new_func_count ) {
                my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
                my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
                my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );

                my $sql3 = qq{
                    select f.taxon_oid, f.gene_count
                    from taxon_tigr_count f, taxon tx
                    where f.func_id = ?
                    and f.taxon_oid = tx.taxon_oid
                    $rclause2 $imgClause2 $taxonClause2 $domain_clause
                };

                my $cur3 = execSql( $dbh, $sql3, $verbose, $tigrfam_id );
                for ( ;; ) {
                    my ( $tid3, $cnt3 ) = $cur3->fetchrow();
                    last if ! $tid3;

                    if ( $gene_func_count{$tid3} ) {
                        $gene_func_count{$tid3} += $cnt3;
                    } else {
                        $gene_func_count{$tid3} = $cnt3;
                    }
                }
                $cur3->finish();
            }

            my $tclause = WebUtil::txsClause("t", $dbh);
            my $sql = MerFsUtil::getTaxonsInFileSql($tclause);
            $sql .= " and t.genome_type = 'metagenome' ";
            $cur = execSql( $dbh, $sql, $verbose );

	    for ( ;; ) {
		my ($t_oid) = $cur->fetchrow();
		last if !$t_oid;
		
		print ". ";
		my $cnt = 0;
                if ( $new_func_count ) {
                    $cnt = $gene_func_count{$t_oid};
                } else {
                    $cnt = MetaUtil::getTaxonOneFuncCnt
			( $t_oid, "", $tigrfam_id );
                }

		if ($cnt) {
		    $tx2cnt_href{ $t_oid } = $cnt;
		    push( @taxon_oids, $t_oid );
		}
	    }
	    $cur->finish();
	    print "<br/>\n";
	}
    }

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("taxonSelections", \%tx2cnt_href);
    foreach my $tx (@taxon_oids) {
        my $cnt = $tx2cnt_href{ $tx };
        $mgr->setCount($tx, $cnt);
    }

    printEndWorkingDiv();

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    $mgr->aggCount();
    print "<p>\n";
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";
    print "</p>\n";

    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printTigrfamList - Show list of all TIRGfams.
############################################################################
sub printTigrfamList {
    print "<h1>TIGRfams</h1>\n";

    my $stats = param('stats');
    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $sid = getContactOid();
    if ( $sid == 312 ) {
        print "<p>*** start time: " . currDateTime() . "<br/>\n";
    }

    my %tigr_cnts;
    my %m_tigr_cnts;

    my $dbh  = dbLogin();

    if ($stats) {
	printStartWorkingDiv();
	print "<p>Counting isolate genomes ...\n";

	my $rclause   = WebUtil::urClause('gt.taxon_oid');
	my $imgClause = WebUtil::imgClauseNoTaxon( 'gt.taxon_oid', 1 );

	my $sql = qq{
        select /*+ result_cache */ gt.ext_accession, 
        count(distinct gt.taxon_oid)
        from mv_taxon_tfam_stat gt
        where 1 = 1 
        $rclause
        $imgClause
        group by gt.ext_accession
        };


	my $cur = execSql( $dbh, $sql, $verbose );
	for ( ; ; ) {
	    my ( $ext_accession, $genome_cnt ) = $cur->fetchrow();
	    last if !$ext_accession;
	    $tigr_cnts{$ext_accession} = $genome_cnt;
	}
	$cur->finish();

	if ($include_metagenomes) {
	    print "<p>Counting metagenomes ...\n";

	    my $rclause3   = WebUtil::urClause('gt.taxon_oid');
	    my $imgClause3 = WebUtil::imgClauseNoTaxon( 'gt.taxon_oid', 2 );
	    my $sql       = qq{
            select /*+ result_cache */ gt.ext_accession, 
            count(distinct gt.taxon_oid)
            from mv_taxon_tfam_stat gt
            where 1 = 1
            $rclause3
            $imgClause3
            group by gt.ext_accession
        };

	    #print "printTigrfamList metagenome \$sql: $sql<br/>\n";

	    my $cur = execSql( $dbh, $sql, $verbose );
	    for ( ; ; ) {
		my ( $ext_accession, $genome_cnt ) = $cur->fetchrow();
		last if !$ext_accession;
		$m_tigr_cnts{$ext_accession} = $genome_cnt;
	    }
	    $cur->finish();

	    print "<p>Counting MER-FS metagenomes ...\n";
	    if ( $new_func_count ) {
		my $rclause2 = WebUtil::urClause('f.taxon_oid');
		my $imgClause2 = WebUtil::imgClauseNoTaxon('f.taxon_oid', 2);

		$sql = qq{ 
                select f.func_id, count(distinct f.taxon_oid)
                from taxon_tigr_count f
                where f.gene_count > 0
                $rclause2 
                $imgClause2
                group by f.func_id 
                }; 
		
		$cur = execSql( $dbh, $sql, $verbose );
		for ( ; ; ) {
		    my ( $tigr_id, $t_cnt ) = $cur->fetchrow();
		    last if ! $tigr_id; 

		    if ( $m_tigr_cnts{$tigr_id} ) { 
			$m_tigr_cnts{$tigr_id} += $t_cnt;
		    } 
		    else { 
			$m_tigr_cnts{$tigr_id} = $t_cnt;
		    } 
		}
		$cur->finish();
		print "<br/>\n";
	    
	    } else {
		$sql  = MerFsUtil::getTaxonsInFileSql();
		$sql .= " and t.genome_type = 'metagenome' ";
		$cur  = execSql( $dbh, $sql, $verbose );

		for ( ; ; ) { 
		    my ($t_oid) = $cur->fetchrow(); 
		    last if !$t_oid;

		    print ". ";

		    my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'tigr' );
		    foreach my $tigr_id ( keys %funcs ) {
			if ( $m_tigr_cnts{$tigr_id} ) {
			    $m_tigr_cnts{$tigr_id} += 1;
			} 
			else {
			    $m_tigr_cnts{$tigr_id} = 1;
			}
		    }
		}
		$cur->finish();
		print "<br/>\n";
	    }
	}

	printEndWorkingDiv();
    }
    
    if ( $sid == 312 ) {
        print "<p>*** end time: " . currDateTime() . "<br/>\n";
    }

    WebUtil::printFuncCartFooter();

    my $it = new InnerTable( 1, "tigrlist$$", "tigrlist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "ID",   "asc", "left" );
    $it->addColSpec( "Name", "asc", "left" );
    if($stats) {
    if ($include_metagenomes) {
        $it->addColSpec( "Isolate<br/>Genome Count", "asc", "right" );
        $it->addColSpec( "Metagenome<br/>Count",     "asc", "right" );
    } else {
        $it->addColSpec( "Genome<br/>Count", "asc", "right" );
    }
    }

    my $sql   = "select tf.ext_accession, tf.expanded_name from tigrfam tf";
    my $cur   = execSql( $dbh, $sql, $verbose );
    my $count = 0;
    for ( ; ; ) {
        my ( $ext_accession, $expanded_name ) = $cur->fetchrow();
        last if !$ext_accession;
        $count++;

        my $r;
        $r .= $sd
          . "<input type='checkbox' name='tigrfam_id' "
          . "value='$ext_accession' />" . "\t";

        my $url  = "$tigrfam_base_url$ext_accession";
        my $link = alink( $url, $ext_accession );

        $r .= $ext_accession . $sd . $link . "\t";
        $r .= $expanded_name . $sd . $expanded_name . "\t";

	if ($stats) {
        my $cnt = $tigr_cnts{$ext_accession};
        if ($cnt) {
            my $url =
                "main.cgi?section=TigrBrowser&page=tigrRoleGenomeList"
              . "&gtype=isolate&tigrfam_id="
              . $ext_accession;
            $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";
        }
        else {
            $r .= "0" . $sd . "0" . "\t";
        }

        if ($include_metagenomes) {
            my $m_cnt = $m_tigr_cnts{$ext_accession};
            if ($m_cnt) {
                my $m_url =
                    "main.cgi?section=TigrBrowser&page=tigrRoleGenomeList"
                  . "&gtype=metagenome&tigrfam_id="
                  . $ext_accession;
                $r .= $m_cnt . $sd . alink( $m_url, $m_cnt ) . "\t";
            }
            else {
                $r .= "0" . $sd . "0" . "\t";
            }
        }
	}
        $it->addRow($r);
    }
    $cur->finish();

    $it->printOuterTable(1);

    WebUtil::printFuncCartFooter();
    print end_form();
    printStatusLine( "$count TIGRfams retrieved", 2 );
    #$dbh->disconnect();
}

############################################################################
# printTigrfamList2 - Show list of all TIRGfams.
# (not showing counts)
############################################################################
sub printTigrfamList2 {
    print "<h1>TIGRfams</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    printHint("Genome and gene counts are not displayed for IMG/M. Click 'view' to see genome or gene list for each individual TIGRfam ID. Click the 'Display TIGRfams with genome and gene counts' link to show counts. (slow)");

    my $show_cnt_url =
	"main.cgi?section=TigrBrowser&page=tigrfamList" . "&show_counts=1";
    print "<p>"
	. alink($show_cnt_url, "Display TIGRfams with genome and gene counts")
	. " (slow)<br/>\n";

    my $dbh = dbLogin();
    WebUtil::printFuncCartFooter();
    my $count = 0;

    my $it = new InnerTable( 1, "tigrlist$$", "tigrlist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "ID",   "asc", "left" );
    $it->addColSpec( "Name", "asc", "left" );
    if ($include_metagenomes) {
        $it->addColSpec( "Isolate<br/>Genome Count", "asc", "right" );
        $it->addColSpec( "Metagenome<br/>Count",     "asc", "right" );
    }
    else {
        $it->addColSpec( "Genome<br/>Count", "asc", "right" );
    }

    my $select_id_name = "tigrfam_id";

    my $sql = "select tf.ext_accession, tf.expanded_name from tigrfam tf";
    my $cur = execSql( $dbh, $sql, $verbose );

    for ( ; ; ) {
        my ( $ext_accession, $expanded_name ) = $cur->fetchrow();
        last if !$ext_accession;
        $count++;

        my $r;
        $r .= $sd
          . "<input type='checkbox' name='$select_id_name' "
          . "value='$ext_accession' />" . "\t";

        my $url  = "$tigrfam_base_url$ext_accession";
        my $link = alink( $url, $ext_accession );

        $r .= $ext_accession . $sd . $link . "\t";
        $r .= $expanded_name . $sd . $expanded_name . "\t";

        my $cnt = "view";
        my $url =
            "main.cgi?section=TigrBrowser&page=tigrRoleGenomeList"
          . "&gtype=isolate&tigrfam_id="
          . $ext_accession;
        $r .= $cnt . $sd . alink( $url, $cnt ) . "\t";

        if ($include_metagenomes) {
            my $m_cnt = "view";
            my $m_url =
                "main.cgi?section=TigrBrowser&page=tigrRoleGenomeList"
              . "&gtype=metagenome&tigrfam_id="
              . $ext_accession;
            $r .= $m_cnt . $sd . alink( $m_url, $m_cnt ) . "\t";
        }

        $it->addRow($r);
    }
    $cur->finish();
    #$dbh->disconnect();

    WebUtil::printFuncCartFooter() if ( $count > 10 );
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    ## save to workspace
    if ( $count > 0 ) {
        print hiddenVar( 'save_func_id_name', 'tigrfam_id' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count TIGRfams retrieved", 2 );
    print end_form();
}

1;
