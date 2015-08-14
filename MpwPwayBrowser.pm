########################################################################### 
# MpwPwayBrowser.pm - MPW Pathway Browser module. 
#   Includes MPW pathway details. 
# 
############################################################################ 
package MpwPwayBrowser; 
my $section = "MpwPwayBrowser"; 
use strict; 
use CGI qw( :standard ); 
use GD;
use Data::Dumper; 

use InnerTable; 
use GeneDetail; 
use PhyloTreeMgr; 
use WebConfig; 
use WebUtil; 
use HtmlUtil; 
use DataEntryUtil;
use FuncUtil; 
use TaxonList; 
use TaxonDetailUtil;
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
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $show_private         = $env->{show_private};
my $tab_panel            = $env->{tab_panel};
my $content_list         = $env->{content_list};
my $mpw_pathway          = $env->{mpw_pathway};
my $tmp_dir          = $env->{tmp_dir}; 
my $tmp_url          = $env->{tmp_url}; 
my $enzyme_base_url      = $env->{enzyme_base_url};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000; 
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
} 

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) {
    $merfs_timeout_mins = 60;
} 
 
# /global/projectb/projectdirs/microbial/img/grechkin
my $mpw_file_path = "/global/projectb/projectdirs/microbial/img/grechkin/Taxonomy/MPW_GRAPH";
my $use_cache = 0;


 
############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch { 
    my $page = param("page");
 
    if ( $page eq "mpwPwayBrowser" ) {
        my $sid = 0;
	if ( $use_cache ) {
	   HtmlUtil::cgiCacheInitialize( $section);
	      HtmlUtil::cgiCacheStart() or return;
	  }

        printMpwAlphaList(); 

	if ( $use_cache ) {
	    HtmlUtil::cgiCacheStop();
	  }
    } elsif ( $page eq "mpwPwayDetail" ) {
        printMpwPwayDetail(); 
    } elsif ( $page eq "mpwRxnDetail" ) {
        printMpwRxnDetail(); 
    } elsif ( $page eq "mpwEcGenes" ) {
        printMpwEcGenes(); 
    } elsif ( $page eq "mpwEcGenomes" ) {
        printMpwEcGenomes(); 
    } elsif ( $page eq "mpwSymbolGenes" ) {
        printMpwSymbolGenes(); 
    } elsif ( $page eq "mpwSymbolGenomes" ) {
        printMpwSymbolGenomes(); 
    } elsif ( $page eq "alphaList" ) {
        printMpwAlphaList(); 
    } elsif ( $page eq "cpdList" ) {
        printMpwCpdList();
    } elsif ( $page eq "compound" ) {
        printMpwCompound();
    } else { 
        my $sid = 0; 
	if ( $use_cache ) {
	   HtmlUtil::cgiCacheInitialize( $section); 
	      HtmlUtil::cgiCacheStart() or return; 
	  }

        printMpwAlphaList(); 

	if ( $use_cache ) {
	    HtmlUtil::cgiCacheStop();
	  }
    } 
} 


sub printJavaScript { 
    print qq{ 
    <script> 
	function selectAllCheckBoxes3( x ) { 
	    var f = document.mainForm3; 
	    for( var i = 0; i < f.length; i++ ) { 
		var e = f.elements[ i ]; 
               if( e.name == "mviewFilter" ) 
                   continue; 
		if( e.type == "checkbox" ) { 
		    e.checked = ( x == 0 ? false : true );
		} 
	    } 
	} 
    </script> 
    }; 
} 


###################################################################### 
# connect to img_pg_v280
#
# MPW pathway data is only in img_pg_v280 at this moment.
# Therefore we need to connect to this database instead.
###################################################################### 
sub Connect_IMG_PG
{ 
    # use the test database img_pg_v280
    my $user2 = "img_pg_v280"; 
    my $pw2 = "img_pg_v280123";
    my $service2 = "IMGDEV";
 
    my $ora_host = "clockwork.jgi-psf.org"; 
    my $ora_port = "1521"; 
    my $ora_sid = "imgdev"; 
 
    # my $dsn2 = "dbi:Oracle:host=$service2"; 
    my $dsn2 = "dbi:Oracle:host=$ora_host;port=$ora_port;sid=$ora_sid"; 
    my $dbh2 = DBI->connect( $dsn2, $user2, $pw2 ); 
    if( !defined( $dbh2 ) ) { 
        webDie( "cannot login to IMG PG\n" ); 
    } 
    $dbh2->{ LongReadLen } = 50000; 
    $dbh2->{ LongTruncOk } = 1; 
    return $dbh2; 
} 


############################################################################ 
# printMpwAlphaList - Print alphabetical listing of pathways. 
############################################################################ 
sub printMpwAlphaList { 
    printStatusLine( "Loading ...", 1 ); 

    my $dbh = dbLogin(); 
#    my $dbh = Connect_IMG_PG();
    my $sql = qq{ 
       select p.pathway_oid, p.pathway_name, p.mpw_id, p.file_name
       from mpw_pgl_pathway p
       order by 1
   }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my @recs; 
    for ( ; ; ) { 
        my ( $pathway_oid, $pathway_name, $mpw_id, $file_name ) =
	    $cur->fetchrow(); 
        last if !$pathway_oid; 
        my $r = "$pathway_oid\t"; 
        $r .= "$pathway_name\t"; 
#        $r .= "$mpw_id\t"; 
#        $r .= "$file_name"; 
        push( @recs, $r ); 
    } 
    $cur->finish(); 

    printMainForm();
    print "<h1>MPW Pathways (Alphabetical)</h1>\n"; 

    my $nRecs = @recs; 
    if ( $nRecs == 0 ) { 
        print "<p>\n"; 
        print "No MPW pathways are found in this database.<br/>\n"; 
        print "</p>\n"; 
	printStatusLine( "Loaded.", 2 );
        return; 
    } 

    my $it = new InnerTable( 1, "mpwpathwaylist$$", "mpwpathwaylist", 2 );
    $it->addColSpec("Select");
    $it->addColSpec( "Pathway OID",   "number asc", "right" );
    $it->addColSpec( "Pathway Name", "char asc",   "left" );
#    $it->addColSpec( "MPW ID", "char asc",   "left" );
#    $it->addColSpec( "File Name", "char asc",   "left" );
    my $sd = $it->getSdDelim();
 
    my $count = 0; 
    for my $r (@recs) {
	my ( $pathway_oid, $pathway_name, $mpw_id, $file_name ) =
	    split( /\t/, $r );
	my $pway_oid = FuncUtil::pwayOidPadded($pathway_oid); 
	$count++;
	my $r; 
        $r .= $sd
	    . "<input type='checkbox' name='pway_oid' value='$pway_oid' />"
	    . "\t";
	my $url = "$section_cgi&page=mpwPwayDetail&pway_oid=$pway_oid";
	$r .= $pway_oid . $sd . alink( $url, $pway_oid ) . "\t";
	$r .= $pathway_name . $sd . escHtml($pathway_name) . "\t";
	$it->addRow($r);
    } 

    WebUtil::printButtonFooter();

    $it->printOuterTable(1); 

    WebUtil::printButtonFooter() if ( $count > 10 );

    print end_form();
    #$dbh->disconnect();
 
    printJavaScript(); 
    printStatusLine( "$count Loaded.", 2 );
}

############################################################################ 
# printMpwPwayDetail
############################################################################ 
sub printMpwPwayDetail {
    my $pway_oid = param("pway_oid");
 
    my $pway_oid_orig = $pway_oid;
 
    print "<h1>MPW Pathway Details</h1>\n";
    printStatusLine( "Loading ...", 1 ); 

    printMainForm(); 
    my $dbh = dbLogin(); 

    my %mer_fs_taxons;
    if ( $include_metagenomes ) {
        my $rclause   = WebUtil::urClause('t');
        my $imgClause = WebUtil::imgClause('t');
	my $sql = qq{
            select t.taxon_oid, t.taxon_display_name, t.in_file
            from taxon t 
            where 1 = 1 
                $rclause
                $imgClause
        }; 
	my $cur = execSql( $dbh, $sql, $verbose );
	for ( ; ; ) {
	    my ($t_id, $taxon_name, $in_file) = $cur->fetchrow();
	    last if !$t_id;
	    if ( $in_file eq 'Yes' ) {
		$mer_fs_taxons{$t_id} = $taxon_name;
	    }
	}
	$cur->finish(); 
    }

    my $pathway_oid = FuncUtil::pwayOidPadded($pway_oid);
 
    print "<table class='img' border='1'>\n"; 
    printAttrRow( "Pathway OID", $pathway_oid ); 

    my $sql = qq{ 
        select p.pathway_oid, p.pathway_name, p.mpw_id, p.add_date,
	p.file_name
        from mpw_pgl_pathway p
        where p.pathway_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $pway_oid );
    my ( $pway_oid, $pway_name, $mpw_id, $add_date, $file_name) =
	$cur->fetchrow(); 
    $cur->finish();

    printAttrRow( "Pathway Name", $pway_name);
    printAttrRow( "MPW ID", $mpw_id);
    printAttrRow( "Add Date", $add_date);
    print "</table>\n";

    # reactions
    $sql = qq{ 
       select pr.pathway_oid, pr.reaction_order, pr.reaction_oid,
       r.condition, gg.gene, pg.protein, r.ec
       from mpw_pgl_pathway_reaction pr, mpw_pgl_reaction r,
	   mpw_pgl_protein_group pg, mpw_pgl_gene_group gg
       where pr.pathway_oid = $pway_oid
       and pr.reaction_oid = r.reaction_oid
       and pr.protein_group = pg.group_oid (+)
       and pr.gene_group = gg.group_oid (+)
       order by 1, 3
   }; 
    $cur = execSql( $dbh, $sql, $verbose ); 
    my @recs; 
    my $count = 0; 
    my @ecs = ();
    my $ec_list = "";
    my @symbols = ();
    my $symbol_list = "";

    for ( ; ; ) { 
        my ( $p_id, $r_order, $r_id, $r_cond, $r_gene, 
	     $r_protein, $r_ec, $gene_count ) =
	    $cur->fetchrow(); 
        last if !$p_id; 

	$count++;

	if ( $count > 10000 ) {
	    last;
	}

        my $r = "$r_order\t"; 
        $r .= "$r_id\t"; 
        $r .= "$r_cond\t"; 
        $r .= "$r_gene\t"; 
        $r .= "$r_protein\t"; 
        $r .= "$r_ec"; 

        push( @recs, $r ); 

	# EC
	if ( ! blankStr($r_ec) && ! WebUtil::inArray($r_ec, @ecs) ) {
	    push @ecs, ( $r_ec );
	    if ( blankStr($ec_list) ) {
		$ec_list = "'$r_ec'";
	    }
	    else {
		$ec_list .= ", '$r_ec'";
	    }
	}

	# gene symbol
	if ( ! blankStr($r_gene) && ! WebUtil::inArray($r_gene, @symbols) ) {
	    push @symbols, ( $r_gene );
	    if ( blankStr($symbol_list) ) {
		$symbol_list = "'$r_gene'";
	    }
	    else {
		$symbol_list .= ", '$r_gene'";
	    }
	}
    } 
    $cur->finish(); 

    print "<h2>Reactions</h2>\n"; 

    my $nRecs = @recs; 
    if ( $nRecs == 0 ) { 
        print "<p>\n"; 
        print "No Reactions for this pathway.<br/>\n"; 
        print "</p>\n"; 

	printStatusLine( "Loaded.", 2 ); 

	print end_form(); 
	#$dbh->disconnect(); 
        return; 
    }

    printStartWorkingDiv();
    print "Retrieving information from database ...<br/>\n";
    # EC gene count and genome count
    my %ec_genecount;
    my %ec_genomecount;
    if ( ! blankStr($ec_list) ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    	$sql = qq{
    	    select gke.enzymes, count(distinct gke.gene_oid) gene_count,
    	    count(distinct g.taxon) genome_count
    		from gene_ko_enzymes gke, gene g
    		where gke.gene_oid = g.gene_oid
    		and gke.enzymes in ( $ec_list )
    		and g.locus_type = 'CDS'
    		and g.obsolete_flag = 'No'
            $rclause
            $imgClause
    		group by gke.enzymes
    	};

    	if ( $include_metagenomes ) {
    	    $sql  = qq{
        	    select g.enzymes, count(distinct g.gene_oid), 
        	    count(distinct g.taxon)
        		from gene_ko_enzymes g
        		where g.enzymes in ( $ec_list )
                $rclause
                $imgClause
        		group by g.enzymes
    	    }; 
    	}
    
    	$cur = execSql( $dbh, $sql, $verbose ); 
    	for ( ; ; ) { 
    	    my ( $ec, $gene_count, $genome_count ) = $cur->fetchrow(); 
    	    last if !$ec; 
    
    	    $ec_genecount{$ec} = $gene_count;
    	    $ec_genomecount{$ec} = $genome_count;
    	}
    	$cur->finish();
    }

    my $merfs_cnt = 0;
    if ( scalar(keys %mer_fs_taxons) > 0 ) {
	print "Checking MER-FS metagenomes ...<br/>\n";

        my $rclause   = WebUtil::urClause('g.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid', 2);
	for my $ec_num ( sort @ecs ) {
	    my $sql2 = "select g.func_id, count(distinct g.taxon_oid), sum(g.gene_count) " .
		"from taxon_ec_count g where g.func_id = ? " .
		$rclause . " " . $imgClause . " group by g.func_id ";
	    my $cur2 = execSql( $dbh, $sql2, $verbose, $ec_num ); 
	    my ($id2, $t_cnt, $g_cnt) = $cur2->fetchrow();
	    $cur2->finish();
	    if ( ! $id2 ) {
		next;
	    }

	    $ec_genecount{$ec_num} += $g_cnt;
	    $ec_genomecount{$ec_num} += $t_cnt;
	}
    }

    # gene symbol
    my %symbol_genecount;
    my %symbol_genomecount;
    if ( ! blankStr($symbol_list) ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $x = lc($symbol_list);
	$sql = qq{
	    select g.gene_symbol, count(distinct g.gene_oid) gene_count,
	    count(distinct g.taxon) genome_count
		from gene g
		where g.gene_symbol is not null
		and lower(g.gene_symbol) in ( $x )
		and g.locus_type = 'CDS'
		and g.obsolete_flag = 'No'
                $rclause
		$imgClause
		group by g.gene_symbol
	    };

	$cur = execSql( $dbh, $sql, $verbose ); 
	for ( ; ; ) { 
	    my ( $symbol, $gene_count, $genome_count ) = $cur->fetchrow(); 
	    last if !$symbol; 

	    $symbol_genecount{$symbol} = $gene_count;
	    $symbol_genomecount{$symbol} = $genome_count;
	}
	$cur->finish();
    }

    printEndWorkingDiv();

#    WebUtil::printMainFormName("3");
#    WebUtil::printFuncCartFooterForEditor("3");
    print "<p>\n"; 

    my $it = new InnerTable( 1, "mpwpathwaylist$$", "mpwpathwaylist", 2 );
#    $it->addColSpec("Select");
    $it->addColSpec( "Raction Order", "number asc",   "right" );
    $it->addColSpec( "Reaction ID",   "number asc", "right" );
    $it->addColSpec("Condition");
    $it->addColSpec("Gene Group");
    $it->addColSpec("Protein Group");
    $it->addColSpec("Enzyme");
    $it->addColSpec("Gene Count", "number asc", "right");
    $it->addColSpec("Genome Count", "number asc", "right");
    my $sd = $it->getSdDelim();
 
    $count = 0; 
    for my $r (@recs) {
	my ( $r_order, $r_id, $r_cond, $r_gene, $r_protein, 
	     $r_ec ) = split( /\t/, $r );
	$count++;

	if ( $count > 10000 ) {
	    last;
	}

	my $r; 
#        $r .= $sd
#	    . "<input type='checkbox' name='pway_oid' value='$pway_oid' />"
#	    . "\t";

	$r .= $r_order . $sd . escHtml($r_order) . "\t";
	my $url = "$section_cgi&page=mpwRxnDetail&rxn_oid=$r_id";
	$r .= $r_id . $sd . alink( $url, $r_id ) . "\t";
	$r .= $r_cond . $sd . escHtml($r_cond) . "\t";
	$r .= $r_gene . $sd . escHtml($r_gene) . "\t";
	$r .= $r_protein . $sd . escHtml($r_protein) . "\t";

	if ( $r_ec ) {
	    # has EC. use EC to get gene count
	    my $ec_url = "$enzyme_base_url$r_ec";
 
	    $r .= $r_ec . $sd . alink( $ec_url, $r_ec ) . "\t";

	    my $gene_count = 0;
	    if ( $ec_genecount{$r_ec} ) {
		my $gene_count = $ec_genecount{$r_ec};
		my $genome_count = $ec_genomecount{$r_ec};
		my $url2 = "$section_cgi&page=mpwEcGenes&rxn_oid=$r_id&ec=$r_ec";
		$r .= $gene_count . $sd . alink( $url2, $gene_count ) . "\t";
		my $url3 = "$section_cgi&page=mpwEcGenomes&rxn_oid=$r_id&ec=$r_ec";
		$r .= $genome_count . $sd . alink( $url3, $genome_count ) . "\t";
	    }
	    else {
		$r .= "0" . $sd . "0" . "\t";
		$r .= "0" . $sd . "0" . "\t";
	    }
	}
	else {
	    # use gene symbol to get gene count
	    $r .= $r_ec . $sd . escHtml($r_ec) . "\t";

	    my $gene_count = 0;
	    if ( $r_gene && $symbol_genecount{$r_gene} ) {
		my $gene_count = $symbol_genecount{$r_gene};
		my $genome_count = $symbol_genecount{$r_gene};
		my $url2 = "$section_cgi&page=mpwSymbolGenes&rxn_oid=$r_id&symbol=$r_gene";
		$r .= $gene_count . $sd . alink( $url2, $gene_count ) . "\t";
		my $url3 = "$section_cgi&page=mpwSymbolGenomes&rxn_oid=$r_id&symbol=$r_gene";
		$r .= $genome_count . $sd . alink( $url3, $genome_count ) . "\t";
	    }
	    else {
		$r .= "0" . $sd . "0" . "\t";
		$r .= "0" . $sd . "0" . "\t";
	    }
	}


	$it->addRow($r);
    }
    $it->printOuterTable(1); 

    printStatusLine( "Loaded.", 2 ); 

    #$dbh->disconnect(); 
    print "<hr>\n";

    if ( ! blankStr($file_name) ) {
	my $path = $mpw_file_path . "/" . $file_name;
	my $image_file = $path;
	$image_file =~ s/\.html/\.png/;
	print "<h3>MPW Pathway Image</h3>\n";

	my $im = new GD::Image($image_file);

	if ( $im ) {
	    my $tmpPngFile = "$tmp_dir/mpw.$pathway_oid.png";
	    my $tmpPngUrl  = "$tmp_url/mpw.$pathway_oid.png";
	    my $wfh        = newWriteFileHandle( $tmpPngFile, "printKeggByGeneOid" );
	    binmode $wfh; 
	    print $wfh $im->png; 
	    close $wfh; 

	    print '<image src="' . $tmpPngUrl . '"' . "/>\n";
	}
	else {
	    print "<p>Cannot create file from " . $image_file . "</p>\n";
	}

	print "<hr>\n";
	print "<h3>HTML: $path</h3>\n";

	my $rfh = newReadFileHandle( $path , "MpwFile" );
	while( my $s = $rfh->getline( ) ) {
	    chomp $s;
	    print "$s\n";
	} 
	close $rfh; 
    }

    print end_form(); 
    WebUtil::webExit(0);
} 


############################################################################ 
# printMpwRxnDetail
############################################################################ 
sub printMpwRxnDetail {
    my $rxn_oid = param("rxn_oid");
 
    print "<h1>MPW Reaction Details</h1>\n";
    printStatusLine( "Loading ...", 1 ); 

    printMainForm(); 
    my $dbh = dbLogin(); 

    print "<h2>Reaction Detail</h2>\n"; 

    my $sql = qq{ 
       select r.reaction_oid, r.condition, r.equation, r.ec
       from mpw_pgl_reaction r
       where r.reaction_oid = $rxn_oid
   }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my ( $r_oid, $r_cond, $r_eqn, $r_ec ) = $cur->fetchrow(); 
    $cur->finish(); 

    # replace compound name in equation
    my $cpd_id = "";
    my $new_eqn = "";
    if ( $r_eqn ) {
	$new_eqn = rewriteEqn($dbh, $r_eqn);

	if ( $new_eqn ) {
	    $r_eqn = $new_eqn;
	}
    }
    #$dbh->disconnect(); 

    print "<p>\n"; 

    print "<table class='img' border='1'>\n"; 
    printAttrRow( "Reaction OID", $r_oid);
    printAttrRow( "Condition", $r_cond);
    printAttrRow( "Equation", $r_eqn);

    if ( $r_ec ) {
	my $ec_url = "$enzyme_base_url$r_ec";
	printAttrRowRaw( "Enzyme", alink( $ec_url, $r_ec ));
    }
    else {
	printAttrRow( "Enzyme", $r_ec);
    }

    print "</table>\n";

    print "<h2>In Pathway(s)</h2>\n"; 

    my $it = new InnerTable( 1, "reaction$$", "reaction", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Pathway ID",     "char asc", "left" ); 
    $it->addColSpec( "Reaction Order",  "number asc", "right" ); 
    $it->addColSpec( "Reaction Label",   "char asc",   "left" ); 
    $it->addColSpec( "Condition", "char asc",   "left" ); 
    $it->addColSpec( "Gene Group", "char asc",   "left" ); 
    $it->addColSpec( "Protein Group", "char asc",   "left" ); 

    $sql = qq{
        select distinct m.pathway_oid, m.reaction_order, m.reaction_label,
               m.requaired_condition, p.protein, g.gene
        from mpw_pgl_pathway_reaction m, mpw_pgl_protein_group p, 
             mpw_pgl_gene_group g
        where m.reaction_oid = ?
        and m.protein_group = p.group_oid (+)
        and m.gene_group = g.group_oid (+)
        };
    $cur = execSql( $dbh, $sql, $verbose, $rxn_oid ); 
    for (;;) {
	my ( $p_oid, $r_order, $r_label, $r_cond,
	    $r_protein, $r_gene) = $cur->fetchrow(); 
	last if ! $p_oid;

	my $r = "";
	my $url = "$section_cgi&page=mpwPwayDetail&pway_oid=$p_oid";
	$r .= $p_oid . $sd . alink( $url, $p_oid ) . "\t";
	$r .= $r_order . $sd . $r_order . "\t";
	$r .= $r_label . $sd . $r_label . "\t";
	$r .= $r_cond . $sd . $r_cond . "\t";
	$r .= $r_gene . $sd . escHtml($r_gene) . "\t";
	$r .= $r_protein . $sd . escHtml($r_protein) . "\t";

	$it->addRow($r);
    }
    $cur->finish(); 

    $it->printOuterTable(1);

    printStatusLine( "Loaded.", 2 ); 

    print end_form(); 
} 


############################################################################
# rewriteEqn
############################################################################
sub rewriteEqn {
    my ($dbh, $r_eqn) = @_;

    my $new_eqn = "";
    my $cpd_id = "";
    if ( $r_eqn ) {
	my $len = length($r_eqn);
	my $j = 0;
	while ( $j < $len ) {
	    my $s1 = substr($r_eqn, $j, 1);
	    if ( isNumber($s1) ) {
		# compound oid
		$cpd_id .= $s1;
	    }
	    else {
		if ( $cpd_id ) {
		    # replace with compound name
		    my $compound_name = db_findVal($dbh, 'mpw_pgl_compound',
						   'compound_oid', $cpd_id,
						   'compound_name', '');
		    $new_eqn .= $compound_name;
		    $cpd_id = "";
		}

		$new_eqn .= $s1;
	    }

	    # next
	    $j++;
	}   # end while j

	# last one
	if ( $cpd_id ) {
	    # replace with compound name
	    my $compound_name = db_findVal($dbh, 'mpw_pgl_compound',
					   'compound_oid', $cpd_id,
					   'compound_name', '');
	    $new_eqn .= $compound_name;
	    $cpd_id = "";
	}
    }

    return $new_eqn;
}

############################################################################ 
# printMpwEcGenes -- using EC
############################################################################ 
sub printMpwEcGenes {
    my $rxn_oid = param("rxn_oid");
    my $ec_number = param("ec");
    my $taxon_oid = param("taxon_oid");

    print "<h1>MPW Reaction Genes (Reaction $rxn_oid)</h1>\n";
    printStatusLine( "Loading ...", 1 ); 

    printMainForm(); 

    print "<h3>Genes with enzyme: $ec_number</h3>\n";

    my $dbh = dbLogin();
    my %taxon_name_h;
    my %mer_fs_taxons;
    my $taxon_cond = " 1 = 1 ";
    if ( $taxon_oid ) {
	if ( ! isInt($taxon_oid) ) {
	    webError("Incorrect Taxon OID: $taxon_oid");
	    return;
	}
	$taxon_cond = " t.taxon_oid = $taxon_oid "
    }

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file
        from taxon t 
        where $taxon_cond
            $rclause
            $imgClause
    }; 
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
	my ($t_id, $taxon_name, $in_file) = $cur->fetchrow();
	last if !$t_id;
	$taxon_name_h{$t_id} = $taxon_name;
	if ( $in_file eq 'Yes' ) {
	    $mer_fs_taxons{$t_id} = 1;
	}
    }
    $cur->finish(); 

    if ( $taxon_oid ) {
	print "<h5>" . $taxon_name_h{$taxon_oid} . "</h5>\n";
    }
    print "<p>\n"; 

    my $gene_count = 0; 
    my $show_gene_name = 1; 
    my $trunc = 0;
    require InnerTable; 
    my $it = new InnerTable( 1, "ecGenes$$", "ecGenes", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec("Select"); 
    $it->addColSpec( "Gene ID",     "char asc", "left" ); 
    $it->addColSpec( "Gene Product Name",   "char asc",   "left" ); 
    $it->addColSpec( "Genome Name", "char asc",   "left" ); 

    my $select_id_name = "gene_oid";

    printStartWorkingDiv();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    $sql = qq{ 
          select distinct gke.gene_oid, g.gene_display_name, g.taxon
          from gene_ko_enzymes gke, gene g
	  where gke.enzymes = ?
          and gke.gene_oid = g.gene_oid
          and g.locus_type = 'CDS'
          and g.obsolete_flag = 'No'
          $rclause
          $imgClause
          };
    if ( $taxon_oid ) {
	if ( $mer_fs_taxons{$taxon_oid} ) {
	    # no need to query database
	    $sql = "";
	}
	else {
	    $sql .= " and g.taxon = $taxon_oid ";
	}
    }

    if ( $sql ) {
	print "Retrieving gene information from database ...<br/>\n";
	$cur = execSql( $dbh, $sql, $verbose, $ec_number );
 
	for ( ; ; ) { 
	    my ($gene_oid, $gene_name, $t_oid) = $cur->fetchrow();
	    last if !$gene_oid;

	    my $taxon_name = $taxon_name_h{$t_oid};
	    my $row = $sd 
		. "<input type='checkbox' name='$select_id_name' value='$gene_oid' />\t";
	    $row .= $gene_oid . $sd . "<a href='main.cgi?section=GeneDetail" .
		"&page=geneDetail&gene_oid=$gene_oid'>" .
		"$gene_oid</a>\t";
	    $row .= $gene_name . $sd . $gene_name . "\t";
	    $row .= $taxon_name . $sd . "<a href='main.cgi?section=TaxonDetail"
		. "&page=taxonDetail&taxon_oid=$t_oid'>$taxon_name</a>\t";
 
	    $it->addRow($row);
	    $gene_count++;
 
	    if ( $gene_count >= $maxGeneListResults ) {
		$trunc = 1;
		last; 
	    }
	}
	$cur->finish();
    }

    my %taxon_h;
    if ( scalar(keys %mer_fs_taxons) > 0 ) {
	my $sql2 = "select g.taxon_oid from taxon_ec_count g where g.func_id = ? " .
	    "and g.gene_count > 0 ";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $ec_number ); 
	for (;;) {
	    my ($id2) = $cur2->fetchrow();
	    last if ! $id2;
	    $taxon_h{$id2} = 1;
	}
	$cur2->finish();

	timeout( 60 * $merfs_timeout_mins ); 
    }

    for my $t_oid (keys %mer_fs_taxons) {
	if ( $trunc ) {
	    last;
	}

	if ( ! $taxon_h{$t_oid} ) {
	    next;
	}
	my $taxon_name = $taxon_name_h{$t_oid};
	print "Retrieving gene information for " . $taxon_name . " ...<br/>\n";
	if ( $mer_fs_taxons{$t_oid} ) {
	    # MER-FS
	    my %genes = MetaUtil::getTaxonFuncGenes($t_oid, '', $ec_number); 
	    my @gene_oids = (keys %genes); 
 
	    if ( scalar(@gene_oids) > 100 ) { 
		$show_gene_name = 0; 
	    } 
 
	    for my $key (@gene_oids) { 
		my $workspace_id = $genes{$key}; 
		my ($tid, $dt, $id2) = split(/ /, $workspace_id);
 
		my $row = $sd 
		    . "<input type='checkbox' name='$select_id_name' value='$workspace_id' />\t";
		$row .= $workspace_id . $sd . "<a href='main.cgi?section=MetaGeneDetail"
		    . "&page=metaGeneDetail&taxon_oid=$tid" .
		    "&data_type=$dt&gene_oid=$key'>$key</a></td>\t";
 
		if ( $show_gene_name ) {
		    my ($value, $source) = MetaUtil::getGeneProdNameSource($key, $tid, $dt);
		    $row .= $value . $sd . $value . "\t";
		} 
		else {
		    $row .= "-" . $sd . "-" . "\t";
		}
		$row .= $taxon_name . $sd . "<a href='main.cgi?section=MetaDetail"
		    . "&page=metaDetail&t_oid=$tid'>$taxon_name</a></td>\t";
 
		$it->addRow($row);
		$gene_count++;
		print "."; 
		if ( ($gene_count % 180) == 0 ) {
		    print "<br/>\n";
		} 
		if ( $gene_count >= $maxGeneListResults ) { 
		    $trunc = 1; 
		    last; 
		} 
	    } 
	}
    }
    printEndWorkingDiv();
    #$dbh->disconnect();

    if ($trunc) { 
        my $s = "Results limited to $maxGeneListResults genes.\n"; 
        $s .= 
            "( Go to " 
            . alink( $preferences_url, "Preferences" ) 
            . " to change \"Max. Gene List Results\". )\n"; 
        printStatusLine( $s, 2 ); 
    } 
    else  { 
        printStatusLine( "$gene_count gene(s) retrieved.", 2 ); 
    } 
 
    my $msg_display = "Gene names are not displayed. ";
    $msg_display   .= "Use 'Expand Gene Table Display' option to view detailed gene information.";

    printHint( $msg_display ) if ( ! $show_gene_name ); 

    WebUtil::printGeneCartFooter() if ($gene_count > 10);
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    printHint( $msg_display ) if ( ! $show_gene_name ); 
 
    if ( $gene_count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();

        print hiddenVar ('data_type', 'both');
        WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes($select_id_name);
    }

    print end_form();
} 


############################################################################ 
# printMpwEcGenomes -- using EC
############################################################################ 
sub printMpwEcGenomes {
    my $rxn_oid = param("rxn_oid");
    my $ec = param("ec");
 
    print "<h1>MPW Reaction Genomes (Reaction $rxn_oid)</h1>\n";
    printStatusLine( "Loading ...", 1 ); 

    printMainForm(); 

    print "<h3>Genomes with enzyme: $ec</h3>\n";

    print "<p>\n"; 

    printStartWorkingDiv();
    print "Retriving genome information from database ...<br/>\n";

    my $dbh = dbLogin(); 
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my %taxon_info; 
    my %mer_fs_taxons;
    my $sql = qq{
        select t.taxon_oid, t.domain, t.seq_status, 
            t.taxon_display_name, t.in_file 
        from taxon t 
        where 1 = 1 
            $rclause 
            $imgClause
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    for (;;) { 
        my ($taxon_oid, $domain, $seq_status, $taxon_name, $in_file) = 
            $cur->fetchrow(); 
        last if !$taxon_oid; 
 
        $taxon_info{$taxon_oid} = substr($domain, 0, 1) . "\t" . 
            substr($seq_status, 0, 1) . "\t" . $taxon_name; 
    	if ( $in_file eq 'Yes' ) {
    	    $mer_fs_taxons{$taxon_oid} = 1;
    	}
    } 
    $cur->finish(); 

    my $rclause   = WebUtil::urClause('g.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid');
    $sql = qq{ 
	    select g.taxon_oid, g.gene_count
	    from mv_taxon_ec_stat g
	    where g.enzyme = ?
        $rclause
        $imgClause
	};

    my $it = new InnerTable( "genomelist", "genomelist$$" ); 
    $it->addColSpec( "Domain", "char asc", "center", "", 
		     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" ); 
    $it->addColSpec( "Status", "char asc", "center", "", 
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" ); 
    $it->addColSpec( "Genome",     "char asc",    "left" ); 
    $it->addColSpec( "Gene Count", "number desc", "right" ); 
    my $sdDelim = $it->getSdDelim(); 
    my $count   = 0; 
    my $total_gene_count = 0; 

    my @taxons;
    $cur = execSql( $dbh, $sql, $verbose, $ec ); 
    for ( ; ; ) { 
	my ( $taxon_oid, $cnt ) = $cur->fetchrow(); 
	last if !$taxon_oid;

        if ( ! $taxon_info{$taxon_oid} ) { 
            next; 
        } 
        my ($domain, $seq_status, $taxon_display_name) = 
            split(/\t/, $taxon_info{$taxon_oid}); 
        $count++;
 
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid"; 
 
        my $r; 
        $r .= "$domain\t"; 
        $r .= "$seq_status\t"; 
        $r .= $taxon_display_name . $sdDelim . alink( $url, $taxon_display_name ) . "\t"; 

	my $url2 = "$section_cgi&page=mpwEcGenes&rxn_oid=$rxn_oid&ec=$ec&taxon_oid=$taxon_oid";
	$r .= $cnt . $sdDelim . alink( $url2, $cnt ) . "\t";
        $total_gene_count += $cnt;
        $it->addRow($r); 
    }
    $cur->finish();

    if ( scalar(keys %mer_fs_taxons) > 0 ) {
        my $rclause   = WebUtil::urClause('g.taxon_oid');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon_oid', 2);
	my $sql2 = "select g.taxon_oid, sum(g.gene_count) " .
	    "from taxon_ec_count g where g.func_id = ? " .
	    $rclause . " " . $imgClause . " group by g.taxon_oid ";
	my $cur2 = execSql( $dbh, $sql2, $verbose, $ec ); 
	for (;;) {
	    my ($taxon_oid, $cnt) = $cur2->fetchrow();
	    last if ! $taxon_oid;

	    if ( $cnt ) {
		if ( ! $taxon_info{$taxon_oid} ) { 
		    next; 
		} 

		my ($domain, $seq_status, $taxon_display_name) = 
		    split(/\t/, $taxon_info{$taxon_oid}); 
		$count++;
 
		my $url = "$main_cgi?section=MetaDetail&page=metaDetail";
		$url .= "&taxon_oid=$taxon_oid"; 
 
		my $r; 
		$r .= "$domain\t"; 
		$r .= "$seq_status\t"; 
		$r .= $taxon_display_name . $sdDelim . alink( $url, $taxon_display_name ) . "\t"; 

		my $url2 = "$section_cgi&page=mpwEcGenes&rxn_oid=$rxn_oid&ec=$ec&taxon_oid=$taxon_oid";
		$r .= $cnt . $sdDelim . alink( $url2, $cnt ) . "\t";
		$total_gene_count += $cnt;
		$it->addRow($r); 
	    }
	}
	$cur2->finish();
    }
    #$dbh->disconnect();

    printEndWorkingDiv();

    print "<p>\n"; 
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n"; 
    $it->printTable(1);
    printStatusLine( "$count genome(s), $total_gene_count gene(s) retrieved.", 2 );

    print end_form(); 
} 


############################################################################ 
# printMpwSymbolGenes -- using gene symbol
############################################################################ 
sub printMpwSymbolGenes {
    my $rxn_oid = param("rxn_oid");
    my $gene_symbol = param("symbol");
 
    print "<h1>MPW Reaction Genes (Reaction $rxn_oid)</h1>\n";
    printStatusLine( "Loading ...", 1 ); 

    printMainForm(); 

    print "<h3>Genes with gene symbol: $gene_symbol</h3>\n";

    print "<p>\n"; 

    my $rclause  = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{ 
	select g.gene_oid, g.gene_display_name
	    from gene g
	    where lower(g.gene_symbol) = ?
	    and g.locus_type = 'CDS'
	    and g.obsolete_flag = 'No'
            $rclause
            $imgClause
	};

  TaxonDetailUtil::printGeneListSectionSorting( $sql, "", "", lc($gene_symbol) ); 

} 


############################################################################ 
# printMpwSymbolGenomes -- using gene symbol
############################################################################ 
sub printMpwSymbolGenomes {
    my $rxn_oid = param("rxn_oid");
    my $gene_symbol = param("symbol");
 
    print "<h1>MPW Reaction Genomes (Reaction $rxn_oid)</h1>\n";
    printStatusLine( "Loading ...", 1 ); 

    printMainForm(); 

    print "<h3>Genes with gene symbol: $gene_symbol</h3>\n";

    print "<p>\n"; 

    my $dbh = dbLogin(); 
    my $rclause  = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{ 
	select distinct g.taxon
	    from gene g
	    where lower(g.gene_symbol) = ?
	    and g.locus_type = 'CDS'
	    and g.obsolete_flag = 'No'
            $rclause
            $imgClause
	};

    my @taxons;
    my $cur = execSql( $dbh, $sql, $verbose, lc($gene_symbol) ); 
    for ( ; ; ) { 
	my ( $taxon_oid ) = $cur->fetchrow(); 
	last if !$taxon_oid;

	push @taxons, ( $taxon_oid );
    }
    $cur->finish();

    HtmlUtil::printGenomeListHtmlTable( "", "", $dbh, \@taxons, 0);
    #$dbh->disconnect();

    print end_form(); 
} 

#######################################################################
# printMpwCpdList
#######################################################################
sub printMpwCpdList {
 
    print "<h1>MPW Compound List</h1>\n";
 
    printStatusLine( "loading ...", 1 );
 
    my $dbh   = dbLogin();

    my $sql = "select compound_oid, compound_name " .
	"from mpw_pgl_compound";
    my $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;
 
    my $it = new InnerTable( 1, "mpw_cpd$$", "mpw", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter

    $it->addColSpec( "Compound ID",   "char asc", "left" );
    $it->addColSpec( "Compound Name", "char asc", "left" );
 
    for (;;) { 
        my ( $id2, $name, $type )
            = $cur->fetchrow();
        last if ( ! $id2 );

        my $r = ""; 
        my $url = "main.cgi?section=MpwPwayBrowser&page=compound&compound_oid=$id2";
        $r .= $id2 . $sd . alink($url, $id2) . "\t";
        $r .= $name . $sd . $name . "\t";

        $it->addRow($r); 
 
        $count++; 
    } 
 
    $it->printOuterTable(1); 
    $cur->finish();
 
    printStatusLine( "$count Loaded.", 2 );
 
    print end_form(); 
} 
 

#########################################################################
# printMpwCompound
#########################################################################
sub printMpwCompound { 
    my $compound_id = param("compound_oid");
 
    if ( ! $compound_id ) { 
        return;
    } 
 
    print "<h1>MPW Compound Detail</h1>\n";
    my $taxon_oid = param('taxon_oid');
 
    my $dbh   = dbLogin();
    my $sql = "select compound_oid, compound_name from mpw_pgl_compound " .
        "where compound_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $compound_id);
    my ( $id2, $name )
        = $cur->fetchrow();
    $cur->finish();
 
    print "<table class='img' border='1'>\n";
    printAttrRowRaw( "Compound ID", $compound_id );
    if ( $name ) {
        printAttrRowRaw( "Compound Name", $name );
    } 

    # in reactions and pathways
    my %eqn_h;
    my %pwy_h;
    my %mpw_h;
    my $in_rxn = ""; 
    $sql = qq{
        select rc.reaction_oid, rc.type, r.condition, r.equation, r.ec,
               pr.reaction_order, pr.reaction_label, pr.cofactor,
               pr.requaired_condition, pr.protein_group, pr.gene_group,
               p.pathway_oid, p.pathway_name, p.mpw_id
        from mpw_pgl_pathway p, mpw_pgl_pathway_reaction pr,
             mpw_pgl_reaction_compounds rc, mpw_pgl_reaction r
        where rc.compound_oid = ?
        and rc.reaction_oid = r.reaction_oid
        and r.reaction_oid = pr.reaction_oid
        and pr.pathway_oid = p.pathway_oid
        }; 
    $cur = execSql( $dbh, $sql, $verbose, $compound_id );
    for (;;) {
        my ( $id2, $rc_type, $condition, $equation, $ec, $rxn_order, 
	     $rxn_label, $cofactor, $required_cond, $protein_group,
	     $gene_group, $pwy_id, $pwy_name, $mpw_id ) =
            $cur->fetchrow(); 
        last if ! $id2;
 
	if ( $eqn_h{$id2} ) {
	    next;
	}
	$eqn_h{$id2} = $rc_type;

        my $url2 = "main.cgi?section=MpwPwayBrowser&page=mpwRxnDetail&rxn_oid=$id2";
        if ( $taxon_oid ) {
            $url2 .= "&taxon_oid=$taxon_oid"; 
        }
        my $rxn = alink($url2, $id2);

	if ( $equation ) {
	    my $new_eqn = rewriteEqn($dbh, $equation);
	    $rxn .= " " . $new_eqn;
	}

	if ( $rc_type ) {
	    $rxn .= " (type: $rc_type)";
	}

        if ( $in_rxn ) {
            $in_rxn .= "<br/>" . $rxn;
        } 
        else { 
            $in_rxn = $rxn; 
        } 
 
        if ( $pwy_id ) { 
            if ( $pwy_name ) { 
                $pwy_h{$pwy_id} = $pwy_name; 
            } 
            else { 
                $pwy_h{$pwy_id} = $pwy_id;
            } 

	    if ( $mpw_id ) {
		$mpw_h{$pwy_id} = $mpw_id;
	    }
        } 
    } 
    $cur->finish(); 

    if ( $in_rxn ) { 
        printAttrRowRaw( "In Reaction(s)", $in_rxn );
    } 
 
    if ( scalar(keys %pwy_h) > 0 ) { 
        my $in_pwy = "";
        for my $pid (keys %pwy_h) { 
            my $url3 = "main.cgi?section=MpwPwayBrowser&page=mpwPwayDetail&pway_oid=$pid";
            if ( $taxon_oid ) {
                $url3 .= "&taxon_oid=$taxon_oid";
            }
 
            if ( $in_pwy ) {
                $in_pwy .= "<br/>" . alink($url3, $pid);
            } 
            else { 
                $in_pwy = alink($url3, $pid);
            }
            $in_pwy .= " (" . $pwy_h{$pid} . ")";
        } 
        printAttrRowRaw( "In Pathway(s)", $in_pwy );
    } 
 
    my %img_compound_oids = matchImgCompound($dbh, $name);
    for my $id3 ( keys %img_compound_oids ) {
        my $name3 = $img_compound_oids{$id3}; 
        my $url3 = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$id3";
        if ( $name3 ) { 
            printAttrRowRaw( "IMG Compound", alink($url3, $id3) . " " . $name3);
        }
        else { 
            printAttrRowRaw( "IMG Compound", alink($url3, $id3) ); 
        } 
    }
 
    print "</table>\n";
 
    print end_form(); 
}


sub matchImgCompound { 
    my ($dbh, $name) = @_;
 
    my %img_compound_h; 
    if ( ! $name ) {
	return %img_compound_h;
    }

    $name = lc($name);

    my $sql = "select c.compound_oid, c.compound_name from img_compound c ";
    $sql .= "where lower(c.compound_name) = ? ";
    $sql .= "or lower(c.common_name) = ? ";
    $sql .= "or c.compound_oid in (select a.compound_oid from img_compound_aliases a ";
    $sql .= " where lower(a.aliases) = ? ) ";
 
    my $cur = execSql( $dbh, $sql, $verbose, $name, $name, $name );
    for (;;) { 
	my ( $id3, $name3 ) = $cur->fetchrow();
	last if ! $id3;
 
	$img_compound_h{$id3} = $name3; 
    } 
    $cur->finish(); 
 
    return %img_compound_h;
} 
 




1;
