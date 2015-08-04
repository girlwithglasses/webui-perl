############################################################################
# Metagenome - Handle metagenome specific constructs for the IMG/M
#   configuration of the Web UI.
#    --es 12/15/2005
#
# $Id: Metagenome.pm 33689 2015-07-06 07:49:51Z jinghuahuang $
############################################################################
package Metagenome;
my $section = "Metagenome";
use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use GenerateArtemisFile;
use TaxonDetail;
use HtmlUtil;

$| = 1;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_url             = $env->{base_url};
my $scaffold_page_size   = $env->{scaffold_page_size};
my $taxonomy_base_url    = $env->{taxonomy_base_url};
my $include_metagenomes  = $env->{include_metagenomes};
my $web_data_dir         = $env->{web_data_dir};
my $ncbi_entrez_base_url = $env->{ncbi_entrez_base_url};
my $img_internal         = $env->{img_internal};
my $user_restricted_site = $env->{user_restricted_site};
my $taxon_stats_dir      = $env->{taxon_stats_dir};
my $taxon_faa_dir        = $env->{taxon_faa_dir};
my $taxon_fna_dir        = $env->{taxon_fna_dir};
my $genes_dir            = $env->{genes_dir};
my $scaffold_cart        = $env->{scaffold_cart};

my $max_gene_batch     = 100;
my $pageSize           = $scaffold_page_size;
my $max_scaffold_list  = 1000;
my $max_scaffold_list2 = 500;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "binDetail" ) {
	printBinDetail();
    }
    elsif ( $page eq "binRnaGenes" ) {
	printBinRnaGenes();
    }
    elsif ( $page eq "binCdsGenes" ) {
	printBinCdsGenes();
    }
    elsif ( $page eq "binCogs" ) {
	printBinCogs();
    }
    elsif ( $page eq "binCogGeneList" ) {
	printBinCogGeneList();
    }
    elsif ( $page eq "binPfams" ) {
	printBinPfams();
    }
    elsif ( $page eq "binPfamGeneList" ) {
	printBinPfamGeneList();
    }
    elsif ( $page eq "binTIGRfams" ) {
	printBinTIGRfams();
    }
    elsif ( $page eq "binTIGRfamGeneList" ) {
	printBinTIGRfamGeneList();
    }
    elsif ( $page eq "binEnzymes" ) {
	printBinEnzymes();
    }
    elsif ( $page eq "binEnzymeGeneList" ) {
	printBinEnzymeGeneList();
    }
    elsif ( $page eq "binScaffolds" ) {
	printBinScaffolds();
    }
    elsif ( $page eq "binArtemisForm" ) {
	printArtemisForm();
    }
    elsif ( $page eq "binScaffoldsByGeneCount" ) {
	printBinScaffoldsByGeneCount();
    }
    else {
	webLog("Metagenome::dispatch: unknonw page='$page'\n");
	warn("Metagenome::dispatch: unknonw page='$page'\n");
    }
}

############################################################################
# printBinDetail - Show details for one bin.
############################################################################
sub printBinDetail {
    my $bin_oid = param("bin_oid");

    my $dbh = dbLogin();
    my $sql = qq{
        select b.bin_oid, b.display_name, b.description, 
               b.confidence, bm.method_name
        from bin b
        left join bin_method bm
        on b.bin_method = bm.bin_method_oid
        where b.bin_oid =  ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ( $bin_oid, $display_name, $description, $confidence, $method_name ) =
	$cur->fetchrow();
    $cur->finish();

    printStatusLine( "Loading ...", 1 );

    print "<h1>Bin Details</h1>\n";
    print "<p>\n";
    print "Details for bin <i>" . escHtml($display_name) . "</i>.<br/>\n";
    print "</p>\n";
    print "<h2>Bin Information</h2>\n";
    print "<table class='img' border='1' >\n";
    printAttrRow( "Bin Name",              $display_name );
    printAttrRow( "Bin Object Identifier", $bin_oid );
    printAttrRow( "Description",           $description );

    #print "<tr class='img'>\n";
    #print "<th class='subhead'>Related IMG Genome</th>\n";
    #print "<td class='img'>";
    #if( $img_taxon ne "" ) {
    #    my $url = "$main_cgi?section=TaxonDetail" .
    #       "&page=taxonDetail&taxon_oid=$img_taxon";
    #    my $taxon_display_name = taxonOid2Name( $dbh, $img_taxon );
    #    print alink( $url, $taxon_display_name );
    #}
    #else {
    #    print "-";
    #}
    print "</td>\n";
    printAttrRow( "Binning Confidence", $confidence );
    printAttrRow( "Binning Method",     $method_name );

    my $scaffoldCount = binScaffoldCount( $dbh, $bin_oid );
    printStatRow( "Number of Scaffolds", $scaffoldCount );
    my $nBases = getBinSize( $dbh, $bin_oid );

    #printStatRow( "Total number of bases (bp)", $nBases );
    print "<tr class='img'>\n";
    print "<th class='subhead'>Total number of bases</th>\n";
    print "<td class='img'>${nBases}bp</td>\n";
    print "</tr>\n";
    my $gc = getBinScaffoldGc( $dbh, $bin_oid );
    $gc = sprintf( "%.2f", $gc );
    printFloatStatRow( "GC", $gc );

    my ( $rnaCount, $cdsCount ) = getRnaCdsCounts( $dbh, $bin_oid );
    my $totalGeneCount = $rnaCount + $cdsCount;
    printStatRow( "Total Number of Genes", $totalGeneCount, $totalGeneCount );
    my $url = "$section_cgi&page=binRnaGenes&bin_oid=$bin_oid";
    printStatRow( "RNA Genes", $rnaCount, $totalGeneCount, $url );
    my ( $rna5sCount, $rna16sCount, $rna23sCount, $trnaCount ) =
	getRnaCounts( $dbh, $bin_oid );
    my $url = "$section_cgi&page=binRnaGenes&bin_oid=$bin_oid"
	. "&locus_type=rRNA&gene_symbol=5S";
    printStatRow( "... 5S", $rna5sCount, $totalGeneCount, $url );
    my $url = "$section_cgi&page=binRnaGenes&bin_oid=$bin_oid"
	. "&locus_type=rRNA&gene_symbol=16S";
    printStatRow( ".. 16S", $rna16sCount, $totalGeneCount, $url );
    my $url = "$section_cgi&page=binRnaGenes&bin_oid=$bin_oid"
	. "&locus_type=rRNA&gene_symbol=23S";
    printStatRow( ".. 23S", $rna23sCount, $totalGeneCount, $url );
    my $url = "$section_cgi&page=binRnaGenes&bin_oid=$bin_oid&locus_type=tRNA";
    printStatRow( "tRNA's", $trnaCount, $totalGeneCount, $url );
    my $url = "$section_cgi&page=binCdsGenes&bin_oid=$bin_oid";
    printStatRow( "Protein Coding Genes", $cdsCount, $totalGeneCount, $url );

    #my $useDt = WebUtil::tableExists( $dbh, "dt_bin_stats" );
    my $useDt = WebUtil::tableExists( $dbh, "bin_stats" );

    my $cogCount = getCogCount( $dbh, $bin_oid, $useDt );
    my $url = "$section_cgi&page=binCogs&bin_oid=$bin_oid";
    printStatRow( "Genes in COGs", $cogCount, $totalGeneCount, $url );

    my $pfamCount = getPfamCount( $dbh, $bin_oid, $useDt );
    my $url = "$section_cgi&page=binPfams&bin_oid=$bin_oid";
    printStatRow( "Genes in Pfam", $pfamCount, $totalGeneCount, $url );

    my $tigrfamCount = getTIGRfamCount( $dbh, $bin_oid, $useDt );
    my $url = "$section_cgi&page=binTIGRfams&bin_oid=$bin_oid";
    printStatRow( "Genes in TIGRfam", $tigrfamCount, $totalGeneCount, $url );

    my $enzymeCount = getEnzymeCount( $dbh, $bin_oid, $useDt );
    my $url = "$section_cgi&page=binEnzymes&bin_oid=$bin_oid";
    printStatRow( "Genes assigned to Enzymes",
		  $enzymeCount, $totalGeneCount, $url );

    print "</table>\n";

    print "<h2>Scaffold List</h2>\n";
    printBinScaffolds($bin_oid);

    my $taxon_oid = binOid2TaxonOid( $dbh, $bin_oid );
    TaxonDetail::printScaffoldSearchForm($taxon_oid);

    printStatusLine( "Loaded.", 2 );

    print "<h2>Export Genome Data</h2>\n";
    my $url =
	"$section_cgi&page=binArtemisForm&bin_oid=$bin_oid&scaffold_count=$scaffoldCount";
    print nbsp(1);
    print "<div class='medbutton'>\n";
    print alink( $url, "Generate Genbank/EMBL File" );
    print "</div>\n";

    #$dbh->disconnect();

}

############################################################################
# printStatRow - Print statistics row.
############################################################################
sub printStatRow {
    my ( $label, $count, $total, $url ) = @_;
    print "<tr class='img'>\n";
    print "<th class='subhead'>" . escHtml($label) . "</th>\n";
    ## Percentage
    my $pc = 0;
    $pc = sprintf( "%.2f", ( $count / $total ) * 100 ) if $total > 0;
    print "<td class='img' align='left'>\n";
    my $len = length($count);
    my $sp  = 6 - $len;
    $sp = 1 if $sp < 1;
    print nbsp($sp);

    if ( $count == 0 || $url eq "" ) {
	printf $count;
    }
    else {
	print alink( $url, $count );
    }
    if ( $total > 0 ) {
	print nbsp(1);
	print "($pc%)";
    }
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# printFloatStatRow - Print statistics row.
############################################################################
sub printFloatStatRow {
    my ( $label, $fval ) = @_;
    print "<tr class='img'>\n";
    print "<th class='subhead'>" . escHtml($label) . "</th>\n";
    print "<td class='img' align='left'>\n";
    my $len = length($fval);
    my $sp  = 7 - $len;
    $sp = 1 if $sp < 1;
    print nbsp($sp);
    print "$fval";
    print "</td>\n";
    print "</tr>\n";
}

############################################################################
# getRnaCdsCounts - Get RNA and CDS counts.
############################################################################
sub getRnaCdsCounts {
    my ( $dbh, $bin_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.locus_type, count( g.gene_oid )
        from bin b, bin_scaffolds bs, gene g
        where b.bin_oid = bs.bin_oid
        and bs.scaffold = g.scaffold
        and g.locus_type in(  'CDS', 'rRNA', 'tRNA' )
        and b.bin_oid = ?
        and g.obsolete_flag = 'No'
	$rclause
	$imgClause
        group by g.locus_type
        order by g.locus_type
    };
    my $cur      = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $rnaCount = 0;
    my $cdsCount = 0;
    for ( ; ; ) {
	my ( $locus_type, $cnt ) = $cur->fetchrow();
	last if !$locus_type;
	if ( $locus_type =~ /RNA/ ) {
	    $rnaCount = $cnt;
	}
	if ( $locus_type eq "CDS" ) {
	    $cdsCount = $cnt;
	}
    }
    $cur->finish();
    return ( $rnaCount, $cdsCount );
}

############################################################################
# getRnaCounts - Get RNA counts for specific types.
############################################################################
sub getRnaCounts {
    my ( $dbh, $bin_oid ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select g.gene_oid, g.locus_type, g.gene_symbol
        from bin b, bin_scaffolds bs, gene g
        where b.bin_oid = bs.bin_oid
        and bs.scaffold = g.scaffold
        and g.locus_type in( 'rRNA', 'tRNA' )
        and b.bin_oid = ?
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        order by g.locus_type, g.gene_symbol
    };
    my $cur         = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $rna5sCount  = 0;
    my $rna16sCount = 0;
    my $rna23sCount = 0;
    my $trnaCount   = 0;
    for ( ; ; ) {
	my ( $gene_oid, $locus_type, $gene_symbol ) = $cur->fetchrow();
	last if !$gene_oid;
	if ( $locus_type eq "rRNA" ) {
	    if ( $gene_symbol eq "5S" ) {
		$rna5sCount++;
	    }
	    elsif ( $gene_symbol eq "16S" ) {
		$rna16sCount++;
	    }
	    elsif ( $gene_symbol eq "23S" ) {
		$rna23sCount++;
	    }
	}
	if ( $locus_type eq "tRNA" ) {
	    $trnaCount++;
	}
    }
    $cur->finish();
    return ( $rna5sCount, $rna16sCount, $rna23sCount, $trnaCount );
}

############################################################################
# getCogCount - Get genes in COG.
############################################################################
sub getCogCount {
    my ( $dbh, $bin_oid, $useDt ) = @_;
    my $sql_full = qq{
	select count( distinct g.gene_oid )
	from bin b, bin_scaffolds bs, gene g, gene_cog_groups gcg
	where b.bin_oid = bs.bin_oid
	and bs.scaffold = g.scaffold
	and g.gene_oid = gcg.gene_oid
	and b.bin_oid = ?
        and g.obsolete_flag = 'No'
    };
    my $sql_dt = qq{
	select dt.genes_in_cog
	from bin_stats dt
	where dt.bin_oid = ?
    };
    my $sql = $sql_full;
    $sql = $sql_dt if $useDt;
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getEnzymeCount - Get genes in enzymes.
############################################################################
sub getEnzymeCount {
    my ( $dbh, $bin_oid, $useDt ) = @_;
    my $sql_full = qq{
	select count( distinct g.gene_oid )
	from bin b, bin_scaffolds bs, gene g, gene_ko_enzymes ge
	where b.bin_oid = bs.bin_oid
	and bs.scaffold = g.scaffold
	and g.gene_oid = ge.gene_oid
	and b.bin_oid = ?
        and g.obsolete_flag = 'No'
    };
    my $sql_dt = qq{
       select dt.genes_in_enzymes
       from bin_stats dt
       where dt.bin_oid = ?
    };
    my $sql = $sql_full;
    $sql = $sql_dt if $useDt;
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getPfamCount - Get genes in Pfam.
############################################################################
sub getPfamCount {
    my ( $dbh, $bin_oid, $useDt ) = @_;
    my $sql_full = qq{
	select count( distinct g.gene_oid )
	from bin b, bin_scaffolds bs, gene g, gene_pfam_families gpf
	where b.bin_oid = bs.bin_oid
	and bs.scaffold = g.scaffold
	and g.gene_oid = gpf.gene_oid
	and b.bin_oid = ?
        and g.obsolete_flag = 'No'
    };
    my $sql_dt = qq{
	select dt.genes_in_pfam
	from bin_stats dt
	where dt.bin_oid = ?
    };
    my $sql = $sql_full;
    $sql = $sql_dt if $useDt;
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getTIGRfamCount - Get genes in TIGRfam.
############################################################################
sub getTIGRfamCount {
    my ( $dbh, $bin_oid, $useDt ) = @_;
    my $sql_full = qq{
	select count( distinct dt.gene_oid )
	from bin b, bin_scaffolds bs, gene g, gene_tigrfams gtf
	where b.bin_oid = bs.bin_oid
	and bs.scaffold = g.scaffold
	and g.gene_oid = gtf.gene_oid
	and b.bin_oid = ?
        and g.obsolete_flag = 'No'
    };
    my $sql_dt = qq{
	select dt.genes_in_tigrfam
	from bin_stats dt
	where dt.bin_oid = ?
    };
    my $sql = $sql_full;
    $sql = $sql_dt if $useDt;
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printBinScaffolds - Show list of scaffold on chromosome page.
############################################################################
sub printBinScaffolds {
    my $bin_oid      = param("bin_oid");
    my $scaffold_oid = param("scaffold_oid");

    if ( $pageSize == 0 ) {
	webDie("printBinScaffolds: invalid pageSize='$pageSize'\n");
    }
    my $dbh = dbLogin();

    printMainForm();

    my $scaffold_count = binScaffoldCount( $dbh, $bin_oid );
    if ( $scaffold_count == 0 ) {
	print "<p>\n";
	print "This genome has no genes on scaffolds to display.\n";
	print "</p>\n";
	#$dbh->disconnect();
	return;
    }
    if ( $scaffold_count > $max_scaffold_list && $scaffold_oid eq "" ) {
	printBinScaffoldDistribution( $dbh, $bin_oid );
	#$dbh->disconnect();
	return;
    }
    print "<h3>User Selectable Coordinates</h3>\n";

    my $sql = qq{
        select count(*)
        from bin_scaffolds
        where bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $scaffoldCount0 = $cur->fetchrow();
    $cur->finish();

    ## Est. orfs
    my $sql = qq{
      select scf.scaffold_oid, bs.confidence, count( distinct g.gene_oid )
      from scaffold scf, gene g, bin_scaffolds bs
      where g.scaffold = scf.scaffold_oid
      and bs.bin_oid = ?
      and bs.scaffold = g.scaffold
      and scf.scaffold_oid = bs.scaffold
      and g.obsolete_flag = 'No'
      group by scf.scaffold_oid, bs.confidence
      order by scf.scaffold_oid, bs.confidence
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my %scaffold2NoGenes;
    my %scaffoldBinConfidence;
    for ( ; ; ) {
	my ( $scaffold_oid, $confidence, $cnt ) = $cur->fetchrow();
	last if !$scaffold_oid;
	$scaffold2NoGenes{$scaffold_oid}      = $cnt;
	$scaffoldBinConfidence{$scaffold_oid} = $confidence;
    }
    $cur->finish();
    my $scaffoldCount1 = keys(%scaffold2NoGenes);
    webLog "scaffoldCount0=$scaffoldCount0\n" if $verbose >= 1;
    webLog "scaffoldCount1=$scaffoldCount1\n" if $verbose >= 1;

    my $scfClause;
    $scfClause = "and s.scaffold_oid = $scaffold_oid" if $scaffold_oid ne "";
    my $sql = qq{
        select distinct s.scaffold_name, ss.seq_length, ss.count_total_gene,
          ss.gc_percent, s.read_depth, s.scaffold_oid, b.display_name
        from scaffold s, bin_scaffolds bs, bin b, scaffold_stats ss
        where s.scaffold_oid = bs.scaffold
        and s.scaffold_oid = ss.scaffold_oid
        and bs.bin_oid = ?
        and bs.bin_oid = b.bin_oid
        $scfClause
        order by ss.seq_length desc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );

    print qq{
           <input type='button' name='Add to Scaffold Cart'
        value='Add to Scaffold Cart' 
            onClick='mySubmit("ScaffoldCart", "addToScaffoldCart")' 
        class='meddefbutton' />
        };

    print nbsp(1);
    print "<input type='button' id='scaffold1' "
	. "name='selectAll' value='Select All' "
	. "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' id='scaffold0' "
	. "name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    my $it = new InnerTable( 1, "scaffold$$", "scaffold", 1 );
    my $sd = $it->getSdDelim();	# sort delimiter
    if ($scaffold_cart) {
	$it->addColSpec("Select");
    }
    $it->addColSpec( "Scaffold",        "char asc",    "left" );
    $it->addColSpec( "Bin Probability", "number desc", "right" );
    $it->addColSpec( "Length (bp)",     "number desc", "right" );
    $it->addColSpec( "GC",              "number desc", "right" );
    $it->addColSpec( "Read Depth",      "number desc", "right" );
    $it->addColSpec( "No. Genes",       "number desc", "right" );
    $it->addColSpec("Coordinate Range");

    my @scaffoldRecs;
    for ( ; ; ) {
	my ( $scaffold_name, $seq_length, $total_gene_count, $gc_percent,
	     $read_depth, $scaffold_oid, $taxon_display_name, @junk )
	    = $cur->fetchrow();
	last if !$scaffold_oid;		
	#print "$scaffold_oid<br/>\n";

	substr( $scaffold_name, length($taxon_display_name) );
	my $scaffold_name2 = WebUtil::getChromosomeName($scaffold_name);
	my $rec            = "$scaffold_oid\t";
	$rec .= "$scaffold_name2\t";
	$rec .= "$seq_length";
	push( @scaffoldRecs, $rec ) if $seq_length > 0;

	# select to add to scaffold cart
	my $r;
	if ($scaffold_cart) {
	    $r .=
		$sd
		. "<input type='checkbox' name='scaffold_oid' "
		. "value='$scaffold_oid' />" . "\t";
	}

	$r .= $scaffold_name2 . $sd . attrLabel($scaffold_name2) . "\t";

	my $confidence = $scaffoldBinConfidence{$scaffold_oid};
	$confidence = 0 if $confidence eq "";
	my $tmpconfidence = $confidence; 		

	if ( $tmpconfidence == 0 ) {
	    $r .= "-" . $sd . "-" . "\t";
	} else {
	    $confidence = sprintf( "%.2f", $confidence );
	    $r .= $confidence . $sd . $confidence . "\t";
	}

	$r .= ${seq_length} . $sd . ${seq_length} . "\t";

	$gc_percent = sprintf( "%.2f", $gc_percent );
	$r .= ${gc_percent} . $sd . ${gc_percent} . "\t";


	if ( $tmpconfidence == 0 ) {
	    $r .= "-" . $sd . "-" . "\t";
	} else {
	    $read_depth = sprintf( "%.2f", $read_depth );
	    $r .= $read_depth . $sd . $read_depth . "\t";
	}

	# gene count
	my $tmp = $scaffold2NoGenes{$scaffold_oid};
	if ( $tmp eq "" ) {
	    $r .= "0" . $sd . "0" . "\t";
	}
	else {
	    $r .= $tmp . $sd . $tmp . "\t";
	}

	if ( $seq_length < $pageSize ) {
	    my $range = "1\.\.$seq_length";
	    my $url   = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
	    $url .= "&scaffold_oid=$scaffold_oid";
	    $url .= "&start_coord=1&end_coord=$seq_length";

	    if ( $seq_length > 0 ) {
		$r .= $range . $sd . alink( $url, $range ) . "\t";
	    }
	    else {
		$r .= "" . $sd . nbsp(1) . "\t";
	    }
	}
	else {
	    my $last = 1;
	    for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
		my $curr  = $i;
		my $range = "$last\.\.$curr";
		my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
		$url .= "&scaffold_oid=$scaffold_oid";
		$url .= "&start_coord=$last&end_coord=$curr";
		$url .= "&seq_length=$seq_length";

		if ( $seq_length > 0 ) {
		    $r .= $range . $sd . alink( $url, $range ) . "\t";
		}
		else {
		    $r .= "" . $sd . nbsp(1) . "\t";
		}
		$last = $curr + 1;
	    }
	    if ( $last < $seq_length ) {
		my $range = "$last\.\.$seq_length";
		my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
		$url .= "&scaffold_oid=$scaffold_oid";
		$url .= "&start_coord=$last&end_coord=$seq_length";

		if ( $seq_length > 0 ) {
		    $r .= $range . $sd . alink( $url, $range ) . "\t";
		}
		else {
		    $r .= "" . $sd . nbsp(1) . "\t";
		}
	    }
	}

        #print "$r<br/>\n";
	$it->addRow($r);
    }
    $it->printOuterTable(1);

    printStatusLine( "Loaded.", 2 );
    $cur->finish();
    #$dbh->disconnect();
    if ( $scaffoldCount0 > $scaffoldCount1 ) {
	print "<p>\n";
	print "Only scaffolds with at least one ORF are shown here.\n";
	print "</p>\n";
    }

    if ($scaffold_cart) {
	print "<p>\n";
	print hiddenVar( "page",    "userScaffoldGraph" );
	print hiddenVar( "section", "ScaffoldGraph" );

	print qq{
        <script language="javascript" type="text/javascript">
            function mySubmit(section, page) {
                document.mainForm.section.value = section;
        document.mainForm.page.value = page;
        document.mainForm.submit();
        }
        </script>
        };
	print qq{
           <input type='button' name='Add to Scaffold Cart'
        value='Add to Scaffold Cart' 
            onClick='mySubmit("ScaffoldCart", "addToScaffoldCart")' 
        class='meddefbutton' />
        };

	print nbsp(1);
	print "<input type='button' id='scaffold1' "
	    . "name='selectAll' value='Select All' "
	    . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	print nbsp(1);
	print "<input type='button' id='scaffold0' "
	    . "name='clearAll' value='Clear All' "
	    . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    }

    print "<br/>\n";
    print "<h3>User Enterable Coordinates</h3>\n";
    print "<select name='scaffold_oid_len' length='30'>\n";
    for my $r (@scaffoldRecs) {
	my ( $scaffold_oid, $scaffold_name, $seq_length ) = split( /\t/, $r );
	print "<option value='$scaffold_oid:$seq_length'>";
	print escHtml($scaffold_name) . nbsp(3);
	print "</option>\n";
    }
    print "</select>\n";
    print "Start ";
    print "<input type='text' name='start_coord' size='10' />\n";
    print "End ";
    print "<input type='text' name='end_coord' size='10' />\n";
    print "<br/>\n";
    print "<br/>\n";
    my $name = "_section_ScaffoldGraph_userScaffoldGraph";
    print submit(
	-name  => $name,
	-value => "Go",
	-class => "smdefbutton"
	);
    print nbsp(1);
    print reset( -class => "smbutton" );

    printHint( "WARNING: Some browsers may be overwhelmed by a large "
	       . "coordinate range." );
    print end_form();
}

############################################################################
# printBinScaffoldDistribution - Show distribution of scaffolds from
#   scaffolds with most genes to least.  Used as alternate presentation
#   if there are too many scaffolds.
############################################################################
sub printBinScaffoldDistribution {
    my ( $dbh, $bin_oid ) = @_;
    my $sql = qq{
        select scf.scaffold_oid, count( distinct g.gene_oid )
        from scaffold scf, gene g, bin_scaffolds bs
        where scf.scaffold_oid = bs.scaffold
	and bs.bin_oid = ?
        and g.scaffold = scf.scaffold_oid
        and g.obsolete_flag = 'No'
        group by scf.scaffold_oid
        order by scf.scaffold_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my @recs;
    for ( ; ; ) {
	my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
	last if !$scaffold_oid;
	my $r = "$cnt\t";
	$r .= "$scaffold_oid";
	push( @recs, $r );
    }
    $cur->finish();
    my %binCount;
    for my $r (@recs) {
	my ( $geneCountStr, $scaffold_oid ) = split( /\t/, $r );
	$binCount{$geneCountStr}++;
    }
    printMainForm();
    print "<h2>Scaffolds by Gene Count</h2>\n";
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";
    print "The number of scaffolds is shown in parenthesis.\n";
    print "</p>\n";
    print "<p>\n";
    my @binKeys = reverse( sort { $a <=> $b } ( keys(%binCount) ) );
    my $url = "$section_cgi&page=binScaffoldsByGeneCount&bin_oid=$bin_oid";

    for my $k (@binKeys) {
	my $nGenes = sprintf( "%d", $k );
	my $url2   = "$url&gene_count=$nGenes";
	my $binCnt = $binCount{$k};
	my $genes  = "genes";
	$genes = "gene" if $nGenes == 1;
	print "Scaffolds having $nGenes $genes ";
	print "(" . alink( $url2, $binCnt ) . ")<br/>\n";
    }
    print "</p>\n";
    printStatusLine( "Loaded", 2 );
    print end_form();
}

############################################################################
# printBinScaffoldsByGeneCount - Show scaffolds with one value of gene count.
#   Drill down from above distribution of scaffolds.
############################################################################
sub printBinScaffoldsByGeneCount {
    my $bin_oid    = param("bin_oid");
    my $gene_count = param("gene_count");

    print "<h1>\n";
    print "Chromosome Viewer";
    print "</h1>\n";

    if ( $pageSize == 0 ) {
	webDie("printBinScaffoldsByGeneCount: invalid pageSize='$pageSize'\n");
    }

    printStatusLine( "Loading", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
        select scf.scaffold_oid, count( distinct g.gene_oid )
        from scaffold scf, gene g, bin_scaffolds bs
        where scf.scaffold_oid = bs.scaffold
	and bs.bin_oid = ?
        and g.scaffold = scf.scaffold_oid
        and g.obsolete_flag = 'No'
        group by scf.scaffold_oid
	having count( distinct g.gene_oid ) = ?
        order by scf.scaffold_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid, $gene_count );
    my @scaffold_oids;
    my $count = 0;
    for ( ; ; ) {
	my ( $scaffold_oid, $cnt ) = $cur->fetchrow();
	last if !$scaffold_oid;
	next if $cnt != $gene_count;
	$count++;
	if ( $cnt != $gene_count ) {
	    webLog "printBinScaffoldsByGeneCount: count mismatch "
		. "$cnt / $gene_count\n";
	}

	#       if( $count > $max_scaffold_list2 ) {
	#	   webLog "printBinScaffoldsByGeneCount: too many scaffolds: " .
	#	     "max. set to $max_scaffold_list2\n";
	#           last;
	#       }
	push( @scaffold_oids, $scaffold_oid );
    }
    $cur->finish();

    # oracle limit
    my $scaffold_list_str = join( ',', @scaffold_oids );
    if ( blankStr($scaffold_list_str) ) {
	#$dbh->disconnect();
	webError("No scaffolds found.");
    }
    my $scaffold_clause;
    if ( OracleUtil::useTempTable($#scaffold_oids) ) {
	OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@scaffold_oids );

	$scaffold_clause =
	    "and scf.scaffold_oid in( select id from gtt_num_id ) ";
    }
    else {
	$scaffold_clause = "and scf.scaffold_oid in( $scaffold_list_str ) ";
    }

    my $sql = qq{
       select display_name
       from bin 
       where bin_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $display_name = $cur->fetchrow();
    $cur->finish();
    printMainForm();

    print "<p>\n";
    print "Bin: ";
    print "<b>\n";
    print escHtml($display_name);
    print "</b>\n";
    print "</p>\n";

    print "<h2>User Selectable Coordinates</h2>\n";

    my $sql = qq{
      select distinct scf.scaffold_name, ss.seq_length, ss.count_total_gene,
        scf.scaffold_oid, b.display_name
      from scaffold scf, bin_scaffolds bs, bin b, scaffold_stats ss
      where scf.scaffold_oid = bs.scaffold
      and ss.scaffold_oid = scf.scaffold_oid
      and bs.bin_oid = ?
      and bs.bin_oid = b.bin_oid
      $scaffold_clause
      order by scf.scaffold_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    print "<p>\n";
    print "Scaffolds with $gene_count gene(s)\n";
    print "</p>\n";
    print "<table class='img'   border='1'>\n";

    my $contact_oid = getContactOid();

    if ($scaffold_cart) {
	print "<th class='subhead'>Select</th>\n";
    }

    print "<th class='subhead'>Scaffold</th>\n";
    print "<th class='subhead'>Length (bp)</th>\n";
    print "<th class='subhead'>Coordinate Range</th>\n";
    my @scaffoldRecs;
    my $cnt = 0;
    for ( ; ; ) {
	my ( $scaffold_name, $seq_length, $total_gene_count, $scaffold_oid,
	     $display_name, @junk )
	    = $cur->fetchrow();
	last if !$scaffold_oid;
	$cnt++;
	print "<tr class='img' >\n";

	# select to add to scaffold cart?
	if ($scaffold_cart) {
	    print "<td class='img'>\n";
	    print
		"<input type='checkbox' name='scaffold_oid' value='$scaffold_oid' />\n";
	    print "</td>\n";
	}

	my $scaffold_name2 = WebUtil::getChromosomeName($scaffold_name);
	my $rec            = "$scaffold_oid\t";
	$rec .= "$scaffold_name2\t";
	$rec .= "$seq_length";
	push( @scaffoldRecs, $rec );
	print "<td class='img' valign='top'>"
	    . attrLabel($scaffold_name2)
	    . "</td>\n";
	print "<td class='img' valign='top' align='right'>${seq_length}</td>\n";
	print "<td class='img' >\n";

	if ( $seq_length < $pageSize ) {
	    my $range = "1\.\.$seq_length";
	    my $url   = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
	    $url .= "&scaffold_oid=$scaffold_oid";
	    $url .= "&start_coord=1&end_coord=$seq_length";
	    print alink( $url, $range ) . "<br/>\n";
	}
	else {
	    my $last = 1;
	    for ( my $i = $pageSize ; $i < $seq_length ; $i += $pageSize ) {
		my $curr  = $i;
		my $range = "$last\.\.$curr";
		my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
		$url .= "&scaffold_oid=$scaffold_oid";
		$url .= "&start_coord=$last&end_coord=$curr";
		$url .= "&seq_length=$seq_length";
		print alink( $url, $range ) . "<br/>\n";
		$last = $curr + 1;
	    }
	    if ( $last < $seq_length ) {
		my $range = "$last\.\.$seq_length";
		my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
		$url .= "&scaffold_oid=$scaffold_oid";
		$url .= "&start_coord=$last&end_coord=$seq_length";
		print alink( $url, $range ) . "<br/>\n";
	    }
	}
	print "</td>\n";
	print "</tr>\n";
    }
    print "</table>\n";

    if ($scaffold_cart) {
	print "<p>\n";
	my $name = "_section_ScaffoldCart_addToScaffoldCart";
	print submit(
	    -name  => $name,
	    -value => "Add to Scaffold Cart",
	    -class => "meddefbutton"
	    );
	print nbsp(1);
	print "<input type='button' name='selectAll' value='Select All' "
	    . "onClick='selectAllCheckBoxes(1)' class='smbutton' />\n";
	print nbsp(1);
	print "<input type='button' name='clearAll' value='Clear All' "
	    . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    }

    print "<br/>\n";
    print "<h2>User Enterable Coordinates</h2>\n";
    print "<select name='scaffold_oid_len' length='30'>\n";
    for my $r (@scaffoldRecs) {
	my ( $scaffold_oid, $scaffold_name, $seq_length ) = split( /\t/, $r );
	print "<option value='$scaffold_oid:$seq_length'>";
	print escHtml($scaffold_name) . nbsp(3);
	print "</option>\n";
    }
    print "</select>\n";
    print "Start ";
    print "<input type='text' name='start_coord' size='10' />\n";
    print "End ";
    print "<input type='text' name='end_coord' size='10' />\n";
    print "<br/>\n";
    print "<br/>\n";
    my $name = "_section_ScaffoldGraph_userScaffoldGraph";
    print submit(
	-name  => $name,
	-value => "Go",
	-class => "smdefbutton"
	);
    print nbsp(1);
    print reset( -class => "smbutton" );
    printHint( "WARNING: Some browsers may be overwhelmed by a large "
	       . "coordinate range." );

    $cur->finish();
    #$dbh->disconnect();
    print end_form();

    printStatusLine( "$cnt scaffolds", 2 );
}

############################################################################
# binScaffoldCount - Get number of scaffolds in the genome.
############################################################################
sub binScaffoldCount {
    my ( $dbh, $bin_oid ) = @_;
    my $sql = qq{
        select count(*)
        from bin_scaffolds bs
        where bs.bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# getBinSize - Get bin size as total number of bases.
############################################################################
sub getBinSize {
    my ( $dbh, $bin_oid ) = @_;
    my $sql = qq{
      select sum( ss.seq_length )
      from bin_scaffolds bs, scaffold_stats ss
      where bs.scaffold = ss.scaffold_oid
      and bs.bin_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my ($seq_length_sum) = $cur->fetchrow();
    $cur->finish();
    return $seq_length_sum;
}

############################################################################
# getBinScafffoldGc - Use weighted average for bin GC from scaffolds.
############################################################################
sub getBinScaffoldGc {
    my ( $dbh, $bin_oid ) = @_;
    my $sql = qq{
      select scf.scaffold_oid, ss.seq_length, ss.gc_percent
      from bin_scaffolds bs, scaffold scf, scaffold_stats ss
      where bs.scaffold = scf.scaffold_oid
      and scf.scaffold_oid = ss.scaffold_oid
      and bs.bin_oid = ?
    };
    my $cur            = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $gc_percent_sum = 0;
    my $seq_length_sum = 0;
    my @recs;
    for ( ; ; ) {
	my ( $scaffold_oid, $seq_length, $gc_percent ) = $cur->fetchrow();
	last if !$scaffold_oid;
	$seq_length_sum += $seq_length;
	my $r = "$seq_length\t";
	$r .= "$gc_percent\t";
	push( @recs, $r );
    }
    $cur->finish();
    my $gc = 0;
    for my $r (@recs) {
	my ( $seq_length, $gc_percent ) = split( /\t/, $r );
	$gc += ( $seq_length / $seq_length_sum ) * $gc_percent;
    }
    return $gc;
}

############################################################################
# printBinRnaGenes - Show RNA genes.
############################################################################
sub printBinRnaGenes {
    my $bin_oid     = param("bin_oid");
    my $locus_type  = param("locus_type");
    my $gene_symbol = param("gene_symbol");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    my @binds           = ($bin_oid);
    my $locusTypeClause = "and g.locus_type like '%RNA' ";
    if ( $locus_type ne "" ) {
	$locusTypeClause = " and g.locus_type = ? ";
	push( @binds, $locus_type );
    }

    my $geneSymbolClause;
    if ( $gene_symbol ne "" ) {
	$geneSymbolClause = " and lower(g.gene_symbol) = ? ";
	push( @binds, lc($gene_symbol) );
    }

    my $sql = qq{
       select g.gene_oid, g.locus_type, g.locus_tag, g.gene_symbol, 
          g.gene_display_name, g.start_coord, g.end_coord, g.strand, 
	  g.dna_seq_length, tx.seq_status, 
	  scf.ext_accession, ss.seq_length, ss.gc_percent,
	  scf.read_depth
       from gene g, taxon tx, scaffold scf, bin_scaffolds bs,
         scaffold_stats ss
       where 1 = 1
       and g.taxon = tx.taxon_oid
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       and bs.scaffold = g.scaffold
       and bs.bin_oid = ?
       $locusTypeClause
       $geneSymbolClause
       and g.obsolete_flag = 'No'
       order by g.locus_type, g.gene_symbol, scf.ext_accession, g.start_coord
    };

    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    my $trnaCount     = 0;
    my $rrnaCount     = 0;
    my $rrna5SCount   = 0;
    my $rrna16SCount  = 0;
    my $rrna23SCount  = 0;
    my $otherRnaCount = 0;
    printMainForm();
    print "<h1>RNA Genes</h1>\n";
    printStatusLine( "Loading ...", 1 );

    printGeneCartFooter();
    print "<p>\n";
    my $old_locus_type;
    my $old_gene_symbol;
    print "<table class='img'  border='1'>\n";
    print "<th class='img' >Select</th>\n";
    print "<th class='img' >Gene ID</th>\n";
    print "<th class='img' >Locus Type</th>\n";
    print "<th class='img' >Gene Symbol</th>\n";
    print "<th class='img' >Coordinates</th>\n";
    print "<th class='img' >Length</th>\n";

    if ($include_metagenomes) {
	print "<th class='img' >Scaffold ID</th>\n";
	print "<th class='img' >Contig Length</th>\n";
	print "<th class='img' >Contig GC</th>\n";
	print "<th class='img' >Contig<br/>Read Depth</th>\n";
    }
    for ( ; ; ) {
	my (
	    $gene_oid,       $locus_type,        $locus_tag,
	    $gene_symbol,    $gene_display_name, $start_coord,
	    $end_coord,      $strand,            $dna_seq_length,
	    $seq_status,     $scf_ext_accession, $scf_seq_length,
	    $scf_gc_percent, $scf_read_depth
	    ) = $cur->fetchrow();
	last if !$gene_oid;

	$scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
	$scf_read_depth = sprintf( "%.2f", $scf_read_depth );
	$scf_read_depth = "-" if $scf_read_depth == 0;
	print "<tr class='img' >\n";

	if (   ( $old_locus_type ne "" && $old_locus_type ne $locus_type )
	    || ( $old_gene_symbol ne "" && $old_gene_symbol ne $gene_symbol ) )
	{
	    #print "<br/>\n";
	    print "<td class='img' >&nbsp;</td>\n";
	    print "<td class='img' >&nbsp;</td>\n";
	    print "<td class='img' >&nbsp;</td>\n";
	    print "<td class='img' >&nbsp;</td>\n";
	    print "<td class='img' >&nbsp;</td>\n";
	    print "<td class='img' >&nbsp;</td>\n";
	    if ($include_metagenomes) {
		print "<td class='img' >&nbsp;</td>\n";
		print "<td class='img' >&nbsp;</td>\n";
		print "<td class='img' >&nbsp;</td>\n";
		print "<td class='img' >&nbsp;</td>\n";
	    }
	    print "</tr>\n";
	    print "<tr class='img' >\n";
	}
	my $len = $end_coord - $start_coord + 1;
	$count++;
	print "<td class='checkbox'>\n";
	print "<input type='checkbox' name='gene_oid' value='$gene_oid' />\n";
	print "</td>\n";
	my $url = "$main_cgi?section=GeneDetail"
	    . "&page=geneDetail&gene_oid=$gene_oid";
	print "<td class='img' >" . alink( $url, $gene_oid ) . "</td>\n";
	print "<td class='img' >" . escHtml($locus_type) . "</td>\n";
	print "<td class='img' >" . escHtml($gene_symbol) . "</td>\n";
	print "<td class='img' >"
	    . escHtml("$start_coord..$end_coord($strand)")
	    . "</td>\n";
	print "<td class='img'  align='right'>"
	    . escHtml("${dna_seq_length}bp")
	    . "</td>\n";

	if ($include_metagenomes) {
	    print "<td class='img' >" . escHtml($scf_ext_accession) . "</td>\n";
	    print "<td class='img'  align='right'>"
		. escHtml("${scf_seq_length}bp")
		. "</td>\n";
	    print "<td class='img' align='right'>$scf_gc_percent</td>\n";
	    print "<td class='img' align='right'>$scf_read_depth</td>\n";
	}
	$rrnaCount++ if ( $locus_type =~ /rRNA/ );
	$rrna5SCount++  if ( $gene_symbol eq "5S" );
	$rrna16SCount++ if ( $gene_symbol eq "16S" );
	$rrna23SCount++ if ( $gene_symbol eq "23S" );
	$trnaCount++ if ( $locus_type =~ /tRNA/ );
	$otherRnaCount++ if ( $locus_type !~ /rRNA/ && $locus_type !~ /tRNA/ );
	$old_locus_type  = $locus_type;
	$old_gene_symbol = $gene_symbol;
	print "</tr>\n";
    }
    print "</table>\n";
    $cur->finish();
    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    my $totalRnaCount = $rrnaCount + $trnaCount + $otherRnaCount;
    printStatusLine(
	"$rrnaCount rRNA's, $trnaCount tRNA's, "
	. "$otherRnaCount ncRNA's retrieved.",
	2
	);
    my $unknownRrnaCount =
	$rrnaCount - $rrna5SCount - $rrna16SCount - $rrna23SCount;

    print end_form();
}

############################################################################
# printBinCdsGenes - Show list of protein coding genes.
############################################################################
sub printBinCdsGenes {
    my $bin_oid = param("bin_oid");

    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
      select distinct g.gene_oid, g.gene_display_name
      from gene g, bin_scaffolds bs
      where g.locus_type = 'CDS'
      and g.obsolete_flag = 'No'
      and bs.scaffold = g.scaffold
      and bs.bin_oid = ?
      order by g.gene_display_name
    };

    HtmlUtil::printMetagGeneListSection( $sql, "Protein Coding Genes", 0, $bin_oid );
}

############################################################################
# printBinCogs - Show COG groups and count of genes.
############################################################################
sub printBinCogs {
    my $bin_oid = param("bin_oid");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select cf.definition, cf.function_code, count(distinct gcg.gene_oid)
       from gene_cog_groups gcg, cog c, gene g, cog_function cf,
         cog_functions cfs, bin_scaffolds bs
       where gcg.cog = c.cog_id
       and gcg.gene_oid = g.gene_oid
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and cfs.functions = cf.function_code
       and cfs.cog_id = c.cog_id
       and g.scaffold = bs.scaffold
       and bs.bin_oid = ?
       group by cf.definition, cf.function_code
       having count(distinct gcg.gene_oid) > 0
       order by cf.definition, cf.function_code
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    printMainForm();
    print "<h1>COG Functions</h1>\n";
    print "<table class='img'  border='1'>\n";
    print "<th class='img' >COG Functions</th>\n";
    print "<th class='img' >Gene Count</th>\n";

    for ( ; ; ) {
	my ( $definition, $function_code, $gene_count ) = $cur->fetchrow();
	last if !$definition;
	last if !$function_code;
	$count++;
	my $url =
	    "$section_cgi&page=binCogGeneList&function_code=$function_code";
	$url .= "&bin_oid=$bin_oid";
	print "<tr class='img' >\n";
	print "<td class='img' >\n";
	print escHtml($definition);
	print "</td>\n";
	print "<td class='img'  align='right'>\n";
	print alink( $url, $gene_count );
	print "</td>\n";
	print "</tr>\n";
    }
    print "</table>\n";
    $cur->finish();
    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    printStatusLine( "$count COG assignments retrieved.", 2 );
    print end_form();
}

############################################################################
# printBinCogGeneList - Show genes under one COG.
############################################################################
sub printBinCogGeneList {
    my $bin_oid       = param("bin_oid");
    my $function_code = param("function_code");

    printMainForm();
    print "<h1>\n";
    print "COG Genes\n";
    print "</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;

    #my %gene2Enzyme;
    #my $sql = qq{
    #   select distinct g.gene_oid, ge.enzymes
    #   from gene_cog_groups gcg, cog c, cog_function cf,
    #     cog_functions cfs, bin_scaffolds bs, scaffold scf, gene g
    #   left join gene_ko_enzymes ge
    #      on g.gene_oid = ge.gene_oid
    #   where gcg.cog = c.cog_id
    #   and g.locus_type = 'CDS'
    #   and g.obsolete_flag = 'No'
    #   and gcg.gene_oid = g.gene_oid
    #   and cfs.functions = cf.function_code
    #   and cfs.cog_id = c.cog_id
    #   and g.scaffold = bs.scaffold
    #   and g.scaffold = scf.scaffold_oid
    #   and bs.bin_oid = ?
    #   and cf.function_code = ?
    #};
    #my $cur = execSql( $dbh, $sql, $verbose, $bin_oid, $function_code );
    #for ( ; ; ) {
    #	my ( $gene_oid, $enzyme ) = $cur->fetchrow();
    #	last if !$gene_oid;
    #	$gene2Enzyme{$gene_oid} .= "$enzyme,";
    #}
    #$cur->finish();

    printGeneCartFooter();
    print "<p>\n";
    my $sql = qq{
    	select c.cog_name, c.cog_id, g.gene_oid, 
    	g.gene_display_name,
    	scf.ext_accession, ss.seq_length, ss.gc_percent, scf.read_depth
	    from gene_cog_groups gcg, cog c, cog_function cf, 
	    scaffold_stats ss,  
	    cog_functions cfs, bin_scaffolds bs, scaffold scf, gene g
	    on g.gene_oid = ge.gene_oid
	    where gcg.cog = c.cog_id
	    and g.locus_type = 'CDS'
	    and g.obsolete_flag = 'No'
	    and gcg.gene_oid = g.gene_oid
	    and cfs.functions = cf.function_code
	    and cfs.cog_id = c.cog_id
	    and g.scaffold = bs.scaffold
	    and g.scaffold = scf.scaffold_oid
	    and scf.scaffold_oid = ss.scaffold_oid
	    and bs.bin_oid = ?
	    and cf.function_code = ?
	    order by c.cog_name
    };
    my @binds = ( $bin_oid, $function_code );
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid, $function_code );
    my $count = 0;
    my @gene_oids;
    my %done;
    my $count = 0;

    for ( ; ; ) {
	my (
	    $cog_name,          $cog_id,         $gene_oid,
	    $gene_display_name, $scf_ext_accession,
	    $scf_seq_length,    $scf_gc_percent, $scf_read_depth
	    ) = $cur->fetchrow();
	last if !$gene_oid;
	next if $done{$gene_oid} ne "";
	$count++;

	print "<input type='checkbox' name='gene_oid' value='$gene_oid' />\n";
	my $url = "$main_cgi?section=GeneDetail"
	    . "&page=geneDetail&gene_oid=$gene_oid";
	print alink( $url, $gene_oid ) . " "
	    . escHtml("$gene_display_name ( $cog_id )");
	print "<br/>";
	print nbsp(4);
	$scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
	my $depth;
	$scf_read_depth = sprintf( "%.2f", $scf_read_depth );
	$depth = " depth=$scf_read_depth" if $scf_read_depth > 0;
	print " ([$scf_ext_accession] ${scf_seq_length}bp "
	    . "gc=$scf_gc_percent$depth)";
	print "<br/>\n";
	$done{$gene_oid} = 1;
    }
    $cur->finish();
    print "<br/>\n";
    print "</p>\n";
    #$dbh->disconnect();
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printBinPfams - Show protein famlies and count of genes.
############################################################################
sub printBinPfams {
    my $bin_oid = param("bin_oid");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select pf.name, pf.ext_accession, count( distinct g.gene_oid )
       from gene_pfam_families gpf, pfam_family pf, bin_scaffolds bs, gene g
       where gpf.gene_oid = g.gene_oid
       and gpf.pfam_family = pf.ext_accession
       and g.scaffold = bs.scaffold
       and bs.bin_oid = ?
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       group by pf.name, pf.ext_accession
       having count(distinct g.gene_oid) > 0
       order by lower( pf.name ), pf.ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    printMainForm();
    print "<h1>Pfam Families</h1>\n";
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";
    print "The number of genes in each Pfam family is shown in parentheses.\n";
    print "</p>\n";
    print "<p>\n";

    for ( ; ; ) {
	my ( $name, $ext_accession, $gene_count ) = $cur->fetchrow();
	last if !$name;
	$count++;
	my $url =
	    "$section_cgi&page=binPfamGeneList" . "&ext_accession=$ext_accession";
	$url .= "&bin_oid=$bin_oid";
	print "$ext_accession " . escHtml($name);
	print " (" . alink( $url, $gene_count ) . ")<br/>\n";
    }
    print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";

    #print "<div id='status'>\n";
    #print "$count Pfam assignment(s) retrieved.\n";
    #print "</div>\n";
    print "</p>\n";
    printStatusLine( "$count Pfam assignments retrieved.", 2 );
    print end_form();
}

############################################################################
# printBinPfamGeneList - Show genes under one protein family.
############################################################################
sub printBinPfamGeneList {
    my $bin_oid       = param("bin_oid");
    my $ext_accession = param("ext_accession");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select distinct pf.name, pf.ext_accession, g.gene_oid
       from gene_pfam_families gpf, pfam_family pf, gene g, bin_scaffolds bs
       where gpf.pfam_family = pf.ext_accession
       and gpf.gene_oid = g.gene_oid
       and g.scaffold = bs.scaffold
       and bs.bin_oid = ?
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and pf.ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid, $ext_accession );
    
    my $count = 0;
    my @gene_oids;
    my %done;
    for ( ; ; ) {
    	my ( $name, $ext_accession, $gene_oid ) = $cur->fetchrow();
    	last if !$name;
    	next if $done{$gene_oid} ne "";
    	$count++;
    	push( @gene_oids, $gene_oid );
    	$done{$gene_oid} = 1;
    }
    $cur->finish();

    if ( $count == 1 ) {
    	my $gene_oid = $gene_oids[0];
    	use GeneDetail;
    	GeneDetail::printGeneDetail($gene_oid);
    	return 0;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>\n";
    print "Pfam Genes\n";
    print "</h1>\n";
    
    my $it = new InnerTable( 1, "MetagGenes$$", "MetagGenes", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Genome ID",    "number asc", "right" );
    $it->addColSpec( "Genome Name",       "char asc",   "left" );
    
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    printGeneCartFooter() if $count > 10;
    print "<p>\n";
    $it->printOuterTable(1);
    print "</p>\n";
    printGeneCartFooter();
    
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printBinTIGRfams - Show protein famlies and count of genes.
############################################################################
sub printBinTIGRfams {
    my $bin_oid = param("bin_oid");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select tf.expanded_name, tf.ext_accession, count( distinct g.gene_oid )
       from tigrfam tf, gene_tigrfams gtf, bin_scaffolds bs, gene g
       where gtf.ext_accession = tf.ext_accession
       and gtf.gene_oid = g.gene_oid
       and g.scaffold = bs.scaffold
       and bs.bin_oid = ?
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       group by tf.expanded_name, tf.ext_accession
       having count(distinct g.gene_oid) > 0
       order by lower( tf.expanded_name ), tf.ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $count = 0;
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    printMainForm();
    print "<h1>TIGRfam Families</h1>\n";
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";
    print "The number of genes in each TIGRfam "
	. "family is shown in parentheses.\n";
    print "</p>\n";
    print "<p>\n";

    for ( ; ; ) {
	my ( $name, $ext_accession, $gene_count ) = $cur->fetchrow();
	last if !$name;
	$count++;
	my $url = "$section_cgi&page=binTIGRfamGeneList"
	    . "&ext_accession=$ext_accession";
	$url .= "&bin_oid=$bin_oid";
	print "$ext_accession " . escHtml($name);
	print " (" . alink( $url, $gene_count ) . ")<br/>\n";
    }
    print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    print "</p>\n";
    printStatusLine( "$count TIGRfam assignments retrieved.", 2 );
    print end_form();
}

############################################################################
# printBinTIGRfamGeneList - Show genes under one protein family.
############################################################################
sub printBinTIGRfamGeneList {
    my $bin_oid       = param("bin_oid");
    my $ext_accession = param("ext_accession");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select distinct g.gene_oid
       from tigrfam tf, gene_tigrfams gtf, gene g, bin_scaffolds bs
       where gtf.ext_accession = tf.ext_accession
       and gtf.gene_oid = g.gene_oid
       and g.scaffold = bs.scaffold
       and bs.bin_oid = ?
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and tf.ext_accession = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid, $ext_accession );

    my $count = 0;
    my @gene_oids;
    my %done;
    for ( ; ; ) {
    	my ($gene_oid) = $cur->fetchrow();
    	last if !$gene_oid;
    	next if $done{$gene_oid} ne "";
    	$count++;
    	push( @gene_oids, $gene_oid );
    	$done{$gene_oid} = 1;
    }
    $cur->finish();

    if ( $count == 1 ) {
    	my $gene_oid = $gene_oids[0];
    	use GeneDetail;
    	GeneDetail::printGeneDetail($gene_oid);
    	return 0;
    }
    
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>\n";
    print "TIGRfam Genes\n";
    print "</h1>\n";

    my $it = new InnerTable( 1, "MetagGenes$$", "MetagGenes", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Genome ID",    "number asc", "right" );
    $it->addColSpec( "Genome Name",       "char asc",   "left" );
    
    HtmlUtil::flushGeneBatchSorting( $dbh, \@gene_oids, $it );

    printGeneCartFooter();
    print "<p>\n";
    $it->printOuterTable(1);
    print "</p>\n";

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printBinEnzymes - Print enzymes list.
############################################################################
sub printBinEnzymes {
    my $bin_oid = param("bin_oid");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select ez.enzyme_name, ez.ec_number, count( distinct g.gene_oid )
       from gene g, gene_ko_enzymes ge, enzyme ez, bin_scaffolds bs
       where g.gene_oid = ge.gene_oid
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and ge.enzymes = ez.ec_number
       and g.scaffold = bs.scaffold
       and bs.bin_oid = ?
       group by ez.enzyme_name, ez.ec_number
       order by ez.enzyme_name, ez.ec_number
    };
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid );
    my $count = 0;
    printMainForm();
    print "<h1>Enzymes</h1>\n";
    printStatusLine( "Loading ...", 1 );
    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    print "The number of genes of each enzyme is shown in parentheses.\n";
    print "</p>\n";
    print "<p>\n";

    for ( ; ; ) {
	my ( $enzyme_name, $ec_number, $gene_count ) = $cur->fetchrow();
	last if !$ec_number;
	$count++;
	my $url = "$section_cgi&page=binEnzymeGeneList&ec_number=$ec_number";
	$url .= "&bin_oid=$bin_oid";
	print escHtml("$enzyme_name $ec_number");
	print " (" . alink( $url, $gene_count ) . ")<br/>\n";
    }
    print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;
    print "<p>\n";
    printStatusLine( "$count enzyme assignments retrieved.", 2 );
    print end_form();
}

############################################################################
# printBinEnzymeGeneList - Show genes under one enzyme.
############################################################################
sub printBinEnzymeGeneList {
    my $bin_oid   = param("bin_oid");
    my $ec_number = param("ec_number");

    my $dbh = dbLogin();
    webLog "Run SQL " . currDateTime() . "\n" if $verbose >= 1;
    my $sql = qq{
       select g.gene_oid, g.gene_display_name, ge.enzymes, scf.ext_accession,
          ss.seq_length, ss.gc_percent, scf.read_depth
       from gene g, gene_ko_enzymes ge, bin_scaffolds bs, scaffold scf,
         scaffold_stats ss
       where g.gene_oid = ge.gene_oid
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       and g.scaffold = bs.scaffold
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       and bs.bin_oid = ?
       and ge.enzymes = ?
    };
    my @binds = ( $bin_oid, $ec_number );
    my $cur = execSql( $dbh, $sql, $verbose, $bin_oid, $ec_number );
    my $count = 0;
    my @gene_oids;
    my @recs;

    for ( ; ; ) {
	my (
	    $gene_oid,          $gene_display_name, $enzyme,
	    $scf_ext_accession, $scf_seq_length,    $scf_gc_percent,
	    $scf_read_depth
	    ) = $cur->fetchrow();
	last if !$gene_oid;

	my $rec = "$gene_oid\t";
	$rec .= "$gene_display_name\t";
	$rec .= "$enzyme\t";
	$rec .= "$scf_ext_accession\t";
	$rec .= "$scf_seq_length\t";
	$rec .= "$scf_gc_percent\t";
	$rec .= "$scf_read_depth\t";
	push( @recs,      $rec );
	push( @gene_oids, $gene_oid );
    }
    if ( scalar(@gene_oids) == 1 ) {
	my $gene_oid = $gene_oids[0];
	require GeneDetail;
	GeneDetail::printGeneDetail($gene_oid);
	return 0;
    }
    printMainForm();
    print "<h1>\n";
    print "Genes Assigned to $ec_number\n";
    print "</h1>\n";
    printGeneCartFooter();
    print "<p>\n";
    my $count = 0;

    for my $r (@recs) {
	my (
	    $gene_oid,          $gene_display_name, $enzyme,
	    $scf_ext_accession, $scf_seq_length,    $scf_gc_percent,
	    $scf_read_depth
	    ) = split( /\t/, $r );
	last if !$gene_oid;
	$count++;
	print "<input type='checkbox' name='gene_oid' value='$gene_oid' />\n";
	my $url = "$main_cgi?section=GeneDetail"
	    . "&page=geneDetail&gene_oid=$gene_oid";
	print alink( $url, $gene_oid ) . " "
	    . escHtml("$gene_display_name ($enzyme)");
	print "<br/>\n";
	$scf_gc_percent = sprintf( "%.2f", $scf_gc_percent );
	$scf_read_depth = sprintf( "%.2f", $scf_read_depth );
	my $depth;
	$depth = " depth=$scf_read_depth" if $scf_read_depth > 0;
	print nbsp(4);
	print "([$scf_ext_accession] $scf_seq_length}bp "
	    . "gc=$scf_gc_percent$depth)<br/>";
    }
    $cur->finish();
    printGeneCartFooter() if $count > 10;
    print "</p>\n";
    #$dbh->disconnect();
    print "<br/>\n";
    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printArtemisForm - Print form for generating GenBank file.
############################################################################
sub printArtemisForm {
    my $bin_oid        = param("bin_oid");
    my $scaffold_count = param("scaffold_count");

    my $dbh = dbLogin();
    my $taxon_oid = binOid2TaxonOid( $dbh, $bin_oid );
    checkTaxonPerm( $dbh, $taxon_oid );

    if ( $scaffold_count eq '' || $scaffold_count <= 0 ) {
	$scaffold_count = binScaffoldCount( $dbh, $bin_oid );
    }

    my $sql = qq{
       select scf.scaffold_oid, scf.ext_accession, scf.scaffold_name, ss.seq_length
       from bin_scaffolds bs, scaffold scf, scaffold_stats ss
       where bs.bin_oid = ?
       and bs.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       order by ss.seq_length desc, scf.ext_accession
    };

    GenerateArtemisFile::printGenerateForm( $dbh, $sql, '', $bin_oid, '', $scaffold_count, 1 );
}

############################################################################
# existMetagenomeStats - Test of metagenome stats exist.
############################################################################
sub existMetagenomeStats {
    my ( $dbh, $taxon_oid ) = @_;

    return 0 if !WebUtil::tableExists( $dbh, "dt_phylum_dist_stats" );

    #   my $rclause = urClause( "g.taxon" );
    #   my $sql_old = qq{
    #      select count(*)
    #      from dt_phylum_dist_genes dt, gene g
    #      where dt.taxon_oid = ?
    #      and dt.gene_oid = g.gene_oid
    #      $rclause
    #   };
    my $sql = qq{
      select count(*)
      from dt_phylum_dist_stats pds
      where pds.taxon_oid = ?
      and pds.domain is not null
      and rownum < 2
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# loadUnassignedCount - Load unique genes information for a taxon.
############################################################################
sub loadUnassignedCount {
    my ($taxon_oid) = @_;
    my $path = "$taxon_stats_dir/$taxon_oid.noFunc.tab.txt";
    webLog "loadUnassignedCount: '$path'\n" if $verbose >= 1;
    my $rfh = newReadFileHandle( $path, "loadUnassignedCount", 1 );
    if ( !$rfh ) {
	webLog("loadUnassignedCount: cannot read '$path'\n");
	return;
    }
    my $s     = $rfh->getline(); # skip header
    my $count = 0;
    while ( my $s = $rfh->getline() ) {
	chomp $s;
	my ( $gene_oid, $similarity ) = split( /\t/, $s );
	next if $similarity;
	$count++;
    }
    close $rfh;
    return $count;
}

1;
