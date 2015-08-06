############################################################################
# CompTaxonStats.pm  - Module for comparative taxon statistics
#   based on a single RDBMS stats table joined to taxon.
#     --es 05/06/2005
#
# $Id: CompTaxonStats.pm 33827 2015-07-28 19:36:22Z aireland $
############################################################################
package CompTaxonStats;
use strict;
use warnings;

use CGI qw( :standard  );
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;
use Pangenome;
use HtmlUtil;

my $section = "CompTaxonStats";
my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $user_restricted_site = $env->{ user_restricted_site };
my $preferences_url = "$main_cgi?section=MyIMG&page=preferences";

my $verbose = $env->{ verbose };

my $page_url = "$main_cgi?section=CompareGenomes&page=taxonBreakdownStats";

############################################################################
# new - Allocate new instance.
############################################################################
sub new {
    my( $myType, $dbh, $statTableName, $pangenome_oid ) = @_;
    my $self = { };
    bless( $self, $myType );

    $self->{ dbh } = $dbh; # database handle
    $self->{ statTableName }= $statTableName;
    $self->{ pangenome_oid } = $pangenome_oid;

    my @a;
    $self->{ colNames } = \@a;     # actual column names
    $self->{ colName2Idx } = { };  # map to array index
    $self->{ idx2ColName } = { };  # map to URL encoding character
    $self->{ colName2Header } = { }; # map to table header
#    $self->{ colName2Desc } = { }; # map to description
    $self->{ colNamesAutoSelected } = { }; # auto select or default output
    $self->{ colNameSortQual } = { }; # sort qualification
    $self->{ genomeCount } = 0;       # number of selected genomes

    return $self;
}

############################################################################
# Accessors - Accessors for caller modified data.
############################################################################
sub colName2Header {
   my( $self ) = @_;
   return $self->{ colName2Header };
}
#sub colName2Desc {
#   my( $self ) = @_;
#   return $self->{ colName2Desc };
#}
sub colNamesAutoSelected {
   my( $self ) = @_;
   return $self->{ colNamesAutoSelected };
}
sub colNameSortQual {
   my( $self ) = @_;
   return $self->{ colNameSortQual };
}

############################################################################
# loadColNames - Load column names to maps.
#   Take a reference to an array input ( $colNames_ref ).
############################################################################
sub loadColNames {
    my( $self, $colNames_ref ) = @_;

    $self->{ colNames } = $colNames_ref;
    my $colName2Idx_ref = $self->{ colName2Idx };
    my $idx2ColName_ref = $self->{ idx2ColName };

    my $count = 0;
    for my $column_name( @$colNames_ref ) {
       $count++;
       my $idx = $count - 1;
       $colName2Idx_ref->{ $column_name } = $idx;
       $idx2ColName_ref->{ $idx } = $column_name;
    }
    if ( $verbose >= 5 ) {
	    webLog ">>> loadColName\n";
        webLog Dumper $self;
    }
}

############################################################################
# setColNameIdxs - Map column names to indexes.
############################################################################
sub setColNameIdxs {
    my( $self,  $tabpage ) = @_;

    my $dbh = $self->{ dbh };
    my $statTableName = $self->{ statTableName };
    my $colNames_ref = $self->{ colNames };
    my $idx2ColName_ref = $self->{ idx2ColName };
    my $colName2Idx_ref = $self->{ colName2Idx };
    my $colNameAutoSelected_ref = $self->{ colNamesAutoSelected };

    ## From sort column
    my $colNameIdxs = param( "colNameIdxs" );
    return if ! WebUtil::blankStr( $colNameIdxs );

    ## From resetting output columns
    my @outputCol = param( "outputCol" .  $tabpage);
    if ( paramMatch( "setTaxonBreakdownStatCols" ) ne "" ) {
       my $colNameIdxs = "";
       for my $colName( @outputCol ) {
	  my $idx = $colName2Idx_ref->{ $colName };
	  $colNameIdxs .= "$idx.";
        }
        param( -name => "colNameIdxs", -value => $colNameIdxs );
        return;
    }

    ## From initial entry point.
    $colNameIdxs = "";
    my $initial = param( "initial" );
    for my $colName( @$colNames_ref ) {
	next if !$initial;
        next if $colNameAutoSelected_ref->{ $colName } eq "";
	my $idx = $colName2Idx_ref->{ $colName };
	$colNameIdxs .= "$idx.";
    }
    param( -name => "colNameIdxs", -value => $colNameIdxs );
}

############################################################################
# printOrgTable - Print organism/genome table.
############################################################################
sub printOrgTable {
    my( $self, $tabpage ) = @_;

    my $dbh = $self->{ dbh };
    my $statTableName = $self->{ statTableName };
    my $colNames_ref = $self->{ colNames };
    my $colName2Idx_ref = $self->{ colName2Idx };
    my $idx2ColName_ref = $self->{ idx2ColName };
    my $colName2Header_ref = $self->{ colName2Header };
    my $colNameSortQual_ref = $self->{ colNameSortQual };
    my $pangenome_oid = $self->{ pangenome_oid };

    my $hideViruses = getSessionParam( "hideViruses" );
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    $virusClause = "and tx.domain not like 'Vir%'" if $hideViruses eq "Yes";

    my $hidePlasmids = getSessionParam( "hidePlasmids" );
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;
    $plasmidClause = "and tx.domain not like 'Plasmid%'"
       if $hidePlasmids eq "Yes";

    my $hideGFragment = getSessionParam( "hideGFragment" );
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $gFragmentClause;
    $gFragmentClause = "and tx.domain not like 'GFragment%'"
       if $hideGFragment eq "Yes";

    $self->setColNameIdxs( $tabpage );
    my $colNameIdxs = param( "colNameIdxs" );
    my $sortIdx = param( "sortIdx" );
    my $sortDomain = param( "sortDomain" );
    my $sortSeqStatus = param( "sortSeqStatus" );
    my $sortAbbrName = param( "sortAbbrName" );
    my $blockDatatableCss = $self->{ blockDatatableCss };

    my $it = new InnerTable( 1, "$statTableName" . $$, "$statTableName", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->{ blockDatatableCss } = $blockDatatableCss;

    $it->addColSpec("Select");
    $it->addColSpec
	( "Domain", "asc", "center", "",
	  "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec
	( "Status", "asc", "center", "",
	  "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    my @outColNames;
    my $outputClause;
    my @colNameIdxsArr = split( /\./, $colNameIdxs );

    for my $idx( @colNameIdxsArr ) {
    	next if $idx eq "";
        my $colName = $idx2ColName_ref->{ $idx };
    	my $sortDir = "desc";
    	my $align = "right";
    	my $ta = tabAlias( $colName );

    	$sortDir = "asc" if $ta eq "tx";
    	$align = "left" if $ta eq "tx";
    	$it->addColSpec( $colName2Header_ref->{ $colName },
            "$sortDir", $align, "", "", "wrap" );
    	push( @outColNames, $colName );
    	my $ta = tabAlias( $colName );
    	$outputClause .= ", $ta.$colName";
    }

    my $rdbms = getRdbms( );
    my $x = 1;
    $x = 0 if $rdbms eq "mysql";

    my $taxonClause = txsClause( "tx", $dbh );
    my $orderByClause = "order by substr( tx.domain, $x, 3 ),
       tx.taxon_display_name";
    $orderByClause = "order by substr( tx.domain, $x, 3 ),
        tx.taxon_display_name" if $sortDomain;
    $orderByClause = "order by tx.seq_status, tx.taxon_display_name"
       if $sortSeqStatus;
    $orderByClause = "order by tx.taxon_display_name" if $sortAbbrName;

    if ( $sortIdx ne "" ) {
       my $sortColName = $idx2ColName_ref->{ $sortIdx };
       my $sortQual = $colNameSortQual_ref->{ $sortColName };
       my $ta = tabAlias( $sortColName );
       my $sortDir = "desc";
       $sortDir = "asc" if $ta eq "tx";
       $orderByClause = "order by $ta.$sortColName $sortDir $sortQual";
    }
    my $rclause = WebUtil::urClause( "tx" );
    my $imgClause = WebUtil::imgClause('tx');

    print WebUtil::hiddenVar( "statTableName" , $statTableName );
    print WebUtil::hiddenVar( "pangenome_oid" , $pangenome_oid );
    if ($tabpage ne "") {
        print WebUtil::hiddenVar( "exportColNameIdxs" . $tabpage , $colNameIdxs );
    } else {
        print WebUtil::hiddenVar( "exportColNameIdxs" , $colNameIdxs );
    }

    if ( $pangenome_oid ne "" ) {
    	Pangenome::printInCategoryCogStats
	    ($dbh, "display", $pangenome_oid, \@outColNames);
    	return;
    }
    my $sql = qq{
        select tx.domain, tx.seq_status,
    	    tx.taxon_oid, tx.taxon_display_name $outputClause
    	from $statTableName stn, taxon tx
    	where stn.taxon_oid (+) = tx.taxon_oid
    	$taxonClause
    	$rclause
        $imgClause
    	$virusClause
    	$plasmidClause
    	$gFragmentClause
    	$orderByClause
    };
    my $cur = WebUtil::execSql( $dbh, $sql, $verbose );
    my $count = 0;
    for ( ;; ) {
        my( $domain, $seq_status,
	    $taxon_oid, $taxon_display_name, @outColVals ) =
	       $cur->fetchrow( );
    	last if !$taxon_oid;

    	my $row = $sd."<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />\t";
    	$row .= $domain.$sd.substr( $domain, 0, 1 )."\t";
    	$row .= $seq_status.$sd.substr( $seq_status, 0, 1 )."\t";
    	my $url = "$main_cgi?section=TaxonDetail" .
    	   "&page=taxonDetail&taxon_oid=$taxon_oid";
    	$row .= $taxon_display_name . $sd
	      . WebUtil::alink( $url, $taxon_display_name )."\t";

    	my $nCols = @outColVals;
    	for ( my $i = 0; $i < $nCols; $i++ ) {
    	   my $colVal = $outColVals[ $i ];
    	   my $colName = $outColNames[ $i ];

    	   if ( $colName =~ /_pc$/ ) {
     	       $row .= $colVal.$sd.sprintf ("%.2f%%", $colVal)."\t";
           }
           elsif ( $colName eq 'gold_id' && $colVal ) {
               my $goldId_url = HtmlUtil::getGoldUrl($colVal);
               $goldId_url = alink( $goldId_url, $colVal );
               $row .= $colVal . $sd . $goldId_url . "\t";
    	   }
    	   elsif ( $colName eq "total_kegg_gene_count" ) {
    	       my $url_kegg = "$main_cgi?section=TaxonDetail" .
    		   "&page=kegg&taxon_oid=$taxon_oid";
    	       $row .= $colVal.$sd.WebUtil::alink( $url_kegg, $colVal )."\t";
    	   }
           elsif ( $colName eq "total_cog_gene_count" ) {
               my $url_cog = "$main_cgi?section=TaxonDetail" .
                       "&page=cogs&cat=cat&taxon_oid=$taxon_oid";
    	       $row .= $colVal.$sd.WebUtil::alink( $url_cog, $colVal )."\t";
           }
           elsif ( $colName eq "total_kog_gene_count" ) {
               my $url_kog = "$main_cgi?section=TaxonDetail" .
                       "&page=kogs&cat=cat&taxon_oid=$taxon_oid";
    	       $row .= $colVal.$sd.WebUtil::alink( $url_kog, $colVal )."\t";
           }
    	   elsif ( $colName eq "gc_percent" ) {
     	       $row .= ($colVal*100).$sd.sprintf ("%.0f%%", ($colVal*100))."\t";
    	   }
    	   else {
     	       $row .= $colVal.$sd.$colVal."\t";
    	   }
    	}
    	$it->addRow( $row );
    	$count++;
    }
    $self->{ genomeCount } = $count;
    $cur->finish( );
    WebUtil::printGenomeCartFooter() if $count > 10;
    $it->printOuterTable(1);
    WebUtil::printGenomeCartFooter();
}

############################################################################
# tabAlias - Map table alias.
############################################################################
sub tabAlias {
    my( $colName ) = @_;
    my %h = (
       taxon_oid     => 1,
       ncbi_taxon_id => 1,
       phylum        => 1,
       ir_class      => 1,
       ir_order      => 1,
       family        => 1,
       genus         => 1,
       gold_id       => 1,
    );
    return "tx" if $h{ $colName } ne "";
    return "stn";
}

############################################################################
# printExport - Show the export button.
############################################################################
sub printExport {
    my( $self, $tabpage ) = @_;

    if ($tabpage ne "") {
		my $name = "_section_CompareGenomes_excel_exportCompStats_" . $tabpage;
		my $contact_oid = WebUtil::getContactOid();
		my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name");

		print qq{
			<input id='exportButton$tabpage' class='lgdefbutton' name='$name' type="submit" value="Export Tab Delimited To Excel" $str />
		};
    } else {
		my $name = "_section_CompareGenomes_excel_exportCompStats";
		my $contact_oid = WebUtil::getContactOid();
		my $str = HtmlUtil::trackEvent("Export", $contact_oid, "img button $name");
		print qq{
			<input id='exportButton' class='lgdefbutton' name='$name' type="submit" value="Export Tab Delimited To Excel" $str />
		};
    }
}

############################################################################
# printCompStatExport - Print statistics export table.
############################################################################
sub printCompStatExport {
    my( $self, $tabpage ) = @_;

    my $dbh = $self->{ dbh };
    my $statTableName = $self->{ statTableName };
    my $colNames_ref = $self->{ colNames };
    my $colName2Idx_ref = $self->{ colName2Idx };
    my $idx2ColName_ref = $self->{ idx2ColName };
    my $colName2Header_ref = $self->{ colName2Header };
    my $colNameSortQual_ref = $self->{ colNameSortQual };
    my $pangenome_oid = $self->{ pangenome_oid };

    my $colNameIdxs = param( "exportColNameIdxs" .$tabpage );

    my $sortIdx = param( "sortIdx" );
    my $colHeader;
    $colHeader .= "taxon_oid\t";
    $colHeader .= "Genome Name\t";
    $colHeader .= "Sequencing Status\t";
    $colHeader .= "Domain\t";
    my @colNameIdxsArr = split( /\./, $colNameIdxs );
    my @outColNames;
    my $outputClause;

    for my $idx( @colNameIdxsArr ) {
	next if $idx eq "";
        my $colName = $idx2ColName_ref->{ $idx };
	my $colHdr = $colName2Header_ref->{ $colName };
	$colHeader .= "$colHdr\t";
	push( @outColNames, $colName );
	my $ta = tabAlias( $colName );
	$outputClause .= ", $ta.$colName";
    }
    chop $colHeader;
    if ( $pangenome_oid ne "" ) {
        Pangenome::printInCategoryCogStats
            ($dbh, "export", $pangenome_oid, \@outColNames);
        return;
    }
    print "$colHeader\n";

    my $taxonClause = txsClause( "tx", $dbh );
    my $orderByClause = "order by tx.taxon_display_name";
    if ( $sortIdx ne "" ) {
       my $sortColName = $idx2ColName_ref->{ $sortIdx };
       my $sortQual = $colNameSortQual_ref->{ $sortColName };
       my $ta = tabAlias( $sortColName );
       my $sortDir = "desc";
       $sortDir = "asc" if $ta eq "tx";
       $orderByClause = "order by $ta.$sortColName $sortDir $sortQual";
    }

    my $rclause = WebUtil::urClause( "tx" );
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select tx.taxon_oid, tx.taxon_display_name, tx.seq_status,
    	    tx.domain $outputClause
    	from $statTableName stn, taxon tx
    	where stn.taxon_oid = tx.taxon_oid
    	$taxonClause
    	$rclause
        $imgClause
    	$orderByClause
    };
    my $cur = WebUtil::execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my( $taxon_oid, $taxon_display_name, $seq_status,
	    $domain, @outColVals ) = $cur->fetchrow( );
	last if !$taxon_oid;
	my $colVals;
	$colVals .= "$taxon_oid\t";
	$colVals .= "$taxon_display_name\t";
	$colVals .= "$seq_status\t";
	$colVals .= "$domain\t";
	my $nCols = @outColVals;

	for ( my $i = 0; $i < $nCols; $i++ ) {
	   my $colVal = $outColVals[ $i ];
	   my $colName = $outColNames[ $i ];
	   if ( $colName =~ /_pc$/ ) {
	       $colVals .= sprintf( "%.2f%%", $colVal ) . "\t";
	   }
	   else {
	       $colVals .= "$colVal\t";
	   }
	}
	chop $colVals;
	print "$colVals\n";
    }
    $cur->finish( );
}

############################################################################
# sortLink - Generate sorting URL link so bheader can be clicked for
#    sorting the rows based on one column.
############################################################################
sub sortLink {
    my( $self, $colName, $sortIdx ) = @_;

    my $statTableName = $self->{ statTableName };
    my $colNames_ref = $self->{ colNames };
    my $idx2ColName_ref = $self->{ idx2ColName };
    my $colName2Header_ref = $self->{ colName2Header };

    my $colNameIdxs = param( "colNameIdxs" );
    my $url = "$page_url&colNameIdxs=$colNameIdxs&sortIdx=$sortIdx";
    $url .= "&statTableName=$statTableName";
    $url .= "&sortDomain=1" if $colName eq "domain";
    $url .= "&sortSeqStatus=1" if $colName eq "seq_status";
    $url .= "&sortAbbrName=1" if $colName eq "taxon_display_name";
    my $colHeader = $colName2Header_ref->{ $colName };
    $colHeader = $colName if WebUtil::blankStr( $colHeader );
    $colHeader = "Genome Name" if $colName eq "taxon_display_name";
    $colHeader = "D" if $colName eq "domain";
    my $s = WebUtil::alink( $url, $colHeader );
    return $s;
}

############################################################################
# addDefaultCols - Add default columns, if none are selected.
#  $outputCol_ref is a reference to an array with default column
#  names to output by default.
############################################################################
sub addDefaultCols {
    my( $self, $outputCol_ref ) = @_;

    my $colNames_ref = $self->{ colNames };
    my $colNamesAutoSelected_ref = $self->{ colNamesAutoSelected };
    for my $colName( @$colNames_ref ) {
       next if $colNamesAutoSelected_ref->{ $colName } eq "";
       push( @$outputCol_ref, $colName );
    }
}

############################################################################
# printConfigTable - Print configuration table.  This table allows
#   the user to specify the output columns to display.
#
# param $tabpage can be null or "" - I need this because everything is on
# one page page for tabbing - ken
#
############################################################################
sub printConfigTable {
    my( $self, $tabpage ) = @_;

    my $dbh = $self->{ dbh };
    my $statTableName = $self->{ statTableName };
    my $colNames_ref = $self->{ colNames };
    my $colName2Idx_ref = $self->{ colName2Idx };
    my $idx2ColName_ref = $self->{ idx2ColName };
    my $colName2Header_ref = $self->{ colName2Header };
    #my $colName2Desc_ref = $self->{ colName2Desc };
    my $colNameAutoSelected_ref = $self->{ colNamesAutoSelected };
    my $pangenome_oid = $self->{ pangenome_oid };
    my $blockDatatableCss = $self->{ blockDatatableCss };

    my $colNameIdxs = param( "colNameIdxs" );
    my %selected;
    my @colNameIdxsArr = split( /\./, $colNameIdxs );
    for my $idx( @colNameIdxsArr ) {
    	next if $idx eq "";
    	my $colName = $idx2ColName_ref->{ $idx };
    	$selected{ $colName } = $colName;
    }

    my $it = new StaticInnerTable( 1, "config$$", "config", 0 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Show" );
    $it->addColSpec( "Column Name", "", "left", "", "", "wrap" );
    #if ($pangenome_oid eq "") {
    #	$it->addColSpec( "Description", "", "left", "", "", "wrap" );
    #}

    foreach my $colName( @$colNames_ref ) {
        my $ck;
        $ck = "checked" if $selected{ $colName };

        my $row;
        my $row = $sd."<input type='checkbox' "
            . "name='outputCol".$tabpage."' value='$colName' $ck />\t";

    	#if ($pangenome_oid eq "") {
    	    my $abbr = $colName2Header_ref->{ $colName };
    	    $row .= $abbr.$sd.escHtml($abbr)."\t";
    	#}

        #my $desc = $colName2Desc_ref->{ $colName };
        #$row .= $desc.$sd.escHtml($desc)."\t";
        $it->addRow($row);
    }

    $it->{ blockDatatableCss } = $blockDatatableCss;
    $it->printOuterTable("nopage");

    if ($tabpage ne "") {
        # TODO new way for tabbed pages
        # note we need custom javascript for this - ken
        my $name = "_section_CompareGenomes_setTaxonBreakdownStatCols_$tabpage";

        print "<input type='submit' id='dispGenomesButton' class='meddefbutton' "
        	. "name='$name' value='Display Genomes Again' />\n";
        # Can not be replaced by WebUtil::printButtonFooter();
        print "<input id='selAll' type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllOutputCol".$tabpage."(1)' class='smbutton' />\n";
        print "<input id='selCnts' type='button' name='selectAll' value='Select Counts Only' " .
        "onClick='selectCountOutputCol".$tabpage."(1)' class='smbutton' />\n";
        print "<input id='clrAll' type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllOutputCol".$tabpage."(0)' class='smbutton' />\n";
    } else {
        # original way
        my $name = "_section_CompareGenomes_setTaxonBreakdownStatCols";

        print "<input type='submit' id='dispGenomesButton' class='meddefbutton' "
        	. "name='$name' value='Display Genomes Again' />\n";
        # Can not be replaced by WebUtil::printButtonFooter();
        print "<input id='selAll' type='button' name='selectAll' value='Select All' " .
        "onClick='selectAllOutputCol(1)' class='smbutton' />\n";
        print "<input id='selCnts' type='button' name='selectAll' value='Select Counts Only' " .
        "onClick='selectCountOutputCol(1)' class='smbutton' />\n";
        print "<input id='clrAll' type='button' name='clearAll' value='Clear All' " .
        "onClick='selectAllOutputCol(0)' class='smbutton' />\n";
    }
}

############################################################################
# encodeOutputCol - Encode the output column names with one letter char.
#  Takes a reference to an array input.
############################################################################
sub encodeOutputCols {
    my( $self, $outputCol_ref ) = @_;
    my $colName2Idx_ref = $self->{ colName2Idx };

    my $s;
    for my $colName( @$outputCol_ref ) {
        my $idx = $colName2Idx_ref->{ $colName };
	$s .= "$idx.";
    }
    return $s;
}

1;
