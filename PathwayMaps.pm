###########################################################################
# PathwayMaps.pm - for display of pathway maps
# $Id: PathwayMaps.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package PathwayMaps;
my $section = "PathwayMaps";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use GD;
use ChartUtil;
use IMGProteins;
use InnerTable;
use KeggMap;
use MetaUtil;
use MetaGeneTable;
use OracleUtil;
use RNAStudies;
use WebConfig;
use WebUtil;
use WorkspaceUtil;

$| = 1;

my $env           = getEnv();
my $cgi_dir       = $env->{cgi_dir};
my $tmp_url       = $env->{tmp_url};
my $tmp_dir       = $env->{tmp_dir};
my $taxon_fna_dir = $env->{taxon_fna_dir};
my $main_cgi      = $env->{main_cgi};
my $section_cgi   = "$main_cgi?section=$section";
my $verbose       = $env->{verbose};
my $base_url      = $env->{base_url};
my $kegg_data_dir = $env->{kegg_data_dir};
my $ko_base_url   = $env->{kegg_orthology_url};

my $include_metagenomes  = $env->{include_metagenomes};
my $user_restricted_site = $env->{user_restricted_site};

my $preferences_url    = "$main_cgi?section=MyIMG&page=preferences";
my $maxGeneListResults = 1000;
if (getSessionParam("maxGeneListResults") ne "") {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $pngDir = "$kegg_data_dir";
my $max_gene_batch = 100;
my $nvl = getNvl();
my %roiDone;
my $YUI = $env->{yui_dir_28};


############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 mins (from main.pl)
    if ( $page eq "mapGenesKo" ) {
        printMapGenesKo();
    } elsif ( $page eq "mapGenesSamples" ) {
	printMapGenesSamples();
    } elsif ( $page eq "mapGenesOneSample" ) {
	printMapGenesOneSample();
    } elsif ( $page eq "keggMapTaxons" ) {
	showMapForTaxons();
    } elsif ( $page eq "keggMapAllTaxons" ) {
    } elsif ( paramMatch("showMap") ne "" ) {
        showMap();
    } elsif ( $page eq "keggMapSamples" ||
	      paramMatch("keggMapSamples") ne "" ) {
        showMapForSamples();
    } elsif ( $page eq "exprGraph" ||
	      paramMatch("exprGraph") ne "" ) {
        printExpressionForGenes();
    } elsif ( $page eq "selectedFns" ||
	      paramMatch("selectedFns") ne "" ) {
	pathwaysForSelectedFns();
    } elsif ( $page eq "keggMapFunctions" ) {
	showMapForFunctions();
    } elsif ( $page eq "mapFunctions" ) {
	printMapFunctions();
    } elsif ( $page eq "selectedGeneFns" ||
	      paramMatch("selectedGeneFns") ne "" ) {
	pathwaysForSelectedGeneFns();
    }
}

############################################################################
# pathwaysForSelectedFns - show a list of pathways for selected functions
############################################################################
sub pathwaysForSelectedGeneFns {
    my @gene_oids = param("gene_oid");

    print "<h1>Pathways for Selected Genes</h1>";
    printHint("The number of genes from those selected that are found to "
	    . "participate in any given pathway is shown in parentheses.");
    print "<br/>";

    if ( scalar(@gene_oids) == 0 ) {
        webError("Please select some genes.");
    }

    my ($dbOids_ref, $metaOids_ref) =
        MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    my @kofuncs;
    my @ecfuncs;
    my %func2genes;

    if (scalar(@dbOids) > 0) {
    	my $dbh = dbLogin();
        my $inClause = OracleUtil::getNumberIdsInClause($dbh, @dbOids);

        my $ecsql = qq{
            select distinct enzymes, gene_oid
            from gene_ko_enzymes
            where gene_oid in ($inClause)
        };
        my $cur = execSql( $dbh, $ecsql, $verbose );
        for ( ;; ) {
            my ($func, $gene) = $cur->fetchrow();
            last if !$func;
            if ( !defined($func2genes{ $func }) ) {
		push(@ecfuncs, $func);
                $func2genes{ $func } = $gene;
            } else {
		$func2genes{ $func } .= ",".$gene;
    	    }
        }

        my $kosql = qq{
            select distinct ko_terms, gene_oid
            from gene_ko_terms
            where gene_oid in ($inClause)
        };
        my $cur = execSql( $dbh, $kosql, $verbose );
        for ( ;; ) {
            my ($func, $gene) = $cur->fetchrow();
            last if !$func;
            if ( !defined($func2genes{ $func }) ) {
		push(@kofuncs, $func);
                $func2genes{ $func } = $gene;
            } else {
		$func2genes{ $func } .= ",".$gene;
    	    }
        }
        $cur->finish();

        OracleUtil::truncTable($dbh, "gtt_num_id")
	    if ($inClause =~ /gtt_num_id/i);
    }

    if (scalar(@metaOids) > 0) {
        foreach my $mOid (@metaOids) {
    	    my ($taxon_oid, $data_type, $g2) = split(/ /, $mOid);

    	    # KO only:
    	    my @g_func1 = MetaUtil::getGeneKoId($g2, $taxon_oid, $data_type);
    	    push( @kofuncs, @g_func1 );
            foreach my $func( @g_func1 ) {
                if ( !defined($func2genes{ $func }) ) {
                    $func2genes{ $func } = $g2;
                } else {
                    $func2genes{ $func } .= ",".$g2;
                }
            }

            # EC only:
    	    my @g_func2 = MetaUtil::getGeneEc($g2, $taxon_oid, $data_type);
    	    push( @ecfuncs, @g_func2 );
    	    foreach my $func( @g_func2 ) {
		if ( !defined($func2genes{ $func }) ) {
		    $func2genes{ $func } = $g2;
		} else {
		    $func2genes{ $func } .= ",".$g2;
		}
    	    }
    	}
    }

    if ( scalar(@kofuncs) == 0 && scalar(@ecfuncs) == 0 ) {
	webError("Selected genes do not map to KO or EC functions.");
    }

    pathwaysForFunctions(\@kofuncs, \@ecfuncs, \%func2genes);
}

############################################################################
# pathwaysForSelectedFns - show a list of pathways for selected functions
############################################################################
sub pathwaysForSelectedFns {
    my @func_ids = param("func_id");

    print "<h1>Pathways for Selected Functions</h1>";
    printHint("The number of functions from those selected that are found to "
	    . "participate in any given pathway is shown in parentheses.");
    print "<br/>";

    if ( scalar(@func_ids) == 0 ) {
        webError("Please select some functions.");
    }

    my @koids;
    my @ecids;
    foreach my $func_id (@func_ids) {
    	if ( $func_id =~ /^EC:/ ) {
    	    push @ecids, $func_id;
    	} elsif ( $func_id =~ /^KO:/ ) {
    	    push @koids, $func_id;
    	}
    }

    if ( scalar(@koids) == 0 && scalar(@ecids) == 0 ) {
        webError("Please select some KO or EC functions.");
    }

    pathwaysForFunctions(\@koids, \@ecids);
}

sub pathwaysForFunctions {
    my ($koids_ref, $ecids_ref, $func2genes_ref) = @_;

    my @koids;
    my @ecids;
    @koids = @$koids_ref if $koids_ref ne "";
    @ecids = @$ecids_ref if $ecids_ref ne "";

    printStatusLine("Loading ...", 1);
    my $dbh = dbLogin();

    my %pathway2count;
    my %pathway2func;

    if ( scalar @koids > 0 ) {
    	my $inClause = OracleUtil::getFuncIdsInClause($dbh, @koids);
    	my $kosql = qq{
            select distinct pw.pathway_name, pw.image_id, pw.pathway_oid,
                   irk.ko_terms
            from kegg_pathway pw, image_roi_ko_terms irk, image_roi ir
            where pw.pathway_oid = ir.pathway
            and ir.roi_id = irk.roi_id
            and irk.ko_terms in ($inClause)
        };
    	my $cur = execSql( $dbh, $kosql, $verbose );
    	for ( ;; ) {
    	    my ( $pathway_name, $image_id, $pathway_oid, $ko )
    		= $cur->fetchrow();
            last if !$image_id;
    	    last if !$ko;
            next if ($image_id eq 'map01100');

            my $k = $pathway_name."\t".$image_id;
            if ( !defined($pathway2count{ $k }) ) {
                $pathway2count{ $k } = 0;
            }
            $pathway2count{ $k }++;

    	    if ( !defined($pathway2func{ $k }) ) {
		$pathway2func{ $k } = $ko;
    	    } else {
		$pathway2func{ $k } .= ",".$ko;
    	    }
    	}
    }

    if ( scalar @ecids > 0 ) {
    	my $inClause = OracleUtil::getFuncIdsInClause($dbh, @ecids);
    	my $ecsql = qq{
            select distinct pw.pathway_name, pw.image_id, pw.pathway_oid,
                   kte.enzymes
            from kegg_pathway pw, image_roi_ko_terms irkt,
                 ko_term_enzymes kte, image_roi ir
            where pw.pathway_oid = ir.pathway
            and ir.roi_id = irkt.roi_id
            and irkt.ko_terms = kte.ko_id
            and kte.enzymes in ($inClause)
        };
    	my $cur = execSql( $dbh, $ecsql, $verbose );
    	for ( ;; ) {
    	    my ( $pathway_name, $image_id, $pathway_oid, $ec )
    		= $cur->fetchrow();
            last if !$image_id;
    	    last if !$ec;
            next if ($image_id eq 'map01100');

            my $k = $pathway_name."\t".$image_id;
            if ( !defined($pathway2count{ $k }) ) {
                $pathway2count{ $k } = 0;
            }
            $pathway2count{ $k }++;

    	    if ( !defined($pathway2func{ $k }) ) {
		$pathway2func{ $k } = $ec;
    	    } else {
		$pathway2func{ $k } .= ",".$ec;
    	    }
    	}
    }

    print qq{
        <table border=0>
        <tr>
        <td nowrap>
    };

    my @pathways = sort keys(%pathway2count);
    my $nPathways = scalar @pathways;

    foreach my $item(@pathways) {
        my ($p, $im) = split('\t', $item);
        my $count1 = $pathway2count{ $item };

    	my $fn_str = $pathway2func{ $item };
    	if ($func2genes_ref ne "") {
    	    my @genes;
    	    my %unique_genes;

    	    my @fns = split(",", $fn_str);
    	    foreach my $f (@fns) {
		my $genes_str = $func2genes_ref->{ $f };
		push(@genes, split(",", $genes_str));
    	    }
    	    foreach my $g (@genes) {
		$unique_genes{ $g } = 1;
    	    }
    	    $count1 = scalar (keys %unique_genes);
    	}
        my $url = "$main_cgi?section=PathwayMaps"
                . "&page=keggMapFunctions&map_id=$im"
                . "&func=$fn_str";
        print alink( $url, $p, "_blank", 0, 1 ) . " ($count1)<br/>\n";
    }
    print qq{
        </td>
        </tr>
        </table>
        </p>
    };

    #$dbh->disconnect();
    printStatusLine("$nPathways pathways loaded.", 2);
}

############################################################################
# showMapForFunctions - displays pathway map where rois for selected
#                       functions are colored green
############################################################################
sub showMapForFunctions {
    my $map_id = param("map_id");
    my $fn_str = param("func");

    my @koids;
    my @ecids;
    my @fns = split(",", $fn_str);
    foreach my $func_id (@fns) {
        if ( $func_id =~ /^EC:/ ) {
            push @ecids, $func_id;
        } elsif ( $func_id =~ /^KO:/ ) {
            push @koids, $func_id;
        }
    }
    if ( scalar(@koids) == 0 && scalar(@ecids) == 0  ) {
        webDie("showMapForFunctions: no KO or EC funcs\n");
    }

    my $dbh = dbLogin();
    my $sql = qq{
        select pathway_name, pathway_oid
        from kegg_pathway
        where image_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    my ( $pathway_name, $pathway_oid ) = $cur->fetchrow();
    $cur->finish();

    my $inFile = "$pngDir/$map_id.png";
    my $im = new GD::Image($inFile);
    if ( !$im ) {
        webDie("showMapForFunctions: cannot read '$inFile'\n");
    }

    my @recs;
    # KO items:
    if ( scalar(@koids) > 0 ) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @koids );
        my $sql = qq{
           select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                  ir.width, ir.height, ir.roi_label,
                  kt.ko_id, kt.ko_name, kt.definition
           from ko_term kt, image_roi ir, image_roi_ko_terms irk
           where irk.ko_terms in ( $ids_str )
           and ir.pathway = ?
           and ir.roi_id = irk.roi_id
           and ir.roi_type in ('ko_term', 'enzyme')
           and irk.ko_terms = kt.ko_id
           order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
        };
        my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
        for ( ;; ) {
            my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
		 $roi_label, $ko_id, $ko_name, $ko_defn ) = $cur->fetchrow();
            last if !$roi_label;

            my $s = "$shape\t$x_coord\t$y_coord\t$coord_str\t$width\t$height"
		  . "\t$roi_label\t$ko_id\t$ko_name\t$ko_defn";
            push @recs, ( $s );
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
            if ( $ids_str =~ /gtt_func_id/i );
    }

    # EC items:
    if ( scalar(@ecids) > 0 ) {
        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @ecids );
        my $sql = qq{
           select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                  ir.width, ir.height, ir.roi_label,
                  ez.ec_number, ez.enzyme_name, ez.systematic_name
           from enzyme ez, image_roi ir,
                image_roi_ko_terms irkt, ko_term_enzymes kte
           where kte.enzymes in ( $ids_str )
           and ir.pathway = ?
           and ir.roi_id = irkt.roi_id
           and ir.roi_type in ('ko_term', 'enzyme')
           and irkt.ko_terms = kte.ko_id
           and kte.enzymes = ez.ec_number
           order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
        };
        my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
        for ( ;; ) {
	    my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
		 $roi_label, $id, $name, $defn ) = $cur->fetchrow();
	    last if !$roi_label;
            # roi_label does not have the EC: in front (use ec_number instead)
            my $s = "$shape\t$x_coord\t$y_coord\t$coord_str\t" .
		    "$width\t$height\t$id\t" .
                    "$id\t$name\t$defn";
            push @recs, ( $s );
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_func_id" )
            if ( $ids_str =~ /gtt_func_id/i );
    }

    my $old_roi;
    my %unique_ko;
    my $koStr;
    my @fnRecs;

    foreach my $s ( sort @recs ) {
        my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
	     $roi_label, $ko_id, $ko_name, $ko_defn ) = split( /\t/, $s );

        next if $shape eq "line";
        if ($shape eq "poly") {
            # anna: strip the coord_str to get only the coords:
            my $begin = index($coord_str, "(");
            my $end = index((reverse $coord_str), ")");
            $coord_str = substr($coord_str, $begin+1, -($end+1));
            $width = -1;
            $height = $coord_str;
        }
        #if ($shape eq "line") {
        #    $width = 10;
        #    $height = 10;
        #    $shape = "rect";
        #}
        next if ($width <= 0 || $height <= 0) && $shape eq "rect";
        next if ($height <= 0); # can't display this roi

        my $r = "$x_coord\t";
        $r .= "$y_coord\t";
        $r .= "$width\t";
        $r .= "$height\t";
        $r .= "$shape";

        my $ko = "$roi_label";
        my $koLabel = "$roi_label, $ko_name";
        $koLabel .= ", $ko_defn" if $ko_defn ne "";

        if ( $old_roi eq "" ) {
            $old_roi = $r;
        }
        if ( $old_roi eq $r ) {
            $unique_ko{$ko} = $koLabel;
        } else {
            my $koStr = join(",", sort(keys(%unique_ko)));
            my $koLabelStr = join("; ", sort(values(%unique_ko)));

            %unique_ko = ();
	    $old_roi .= "\t$koStr" . "\t$koLabelStr";
	    push( @fnRecs, $old_roi );
            $unique_ko{$ko} = $koLabel;
        }
        $old_roi = $r;
    }
    my $koStr = join(",", keys(%unique_ko));
    my $koLabelStr = join("; ", values(%unique_ko));
    $old_roi .= "\t$koStr" . "\t$koLabelStr";
    push( @fnRecs, $old_roi );

    applyHighlightsRGB( $im, \@fnRecs, 0, 255, 0, 50, "green" );

    my $tmpPngFile = "$tmp_dir/$map_id.$$.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.$$.png";
    my $wfh = newWriteFileHandle( $tmpPngFile, "showMapForFunctions" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    print "<h1>KEGG Map: $pathway_name</h1>";
    my $hintstr .=
          "<span style='border:.1em solid rgb(0, 0, 0); "
        . "background-color: rgb(100, 255, 100)'>&nbsp;&nbsp;&nbsp;</span> "
	. "Selected functions mapping to this pathway are marked in green."
        . "<br/><span style='border:.1em solid rgb(255, 0, 0); "
        . "background-color: rgb(190, 190, 190)'>&nbsp;&nbsp;&nbsp;</span> "
        . "a red border indicates that more than one function maps to "
        . "this reaction.";
    printHint($hintstr);
    print "<br/>";

    print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";
    print "<map name='mapdata'>\n";
    printMapCoordsForFuncs( \@fnRecs, $map_id, $fn_str );

    my $url_fragm = "&page=keggMapFunctions&func=$fn_str";
    printRelatedCoords( $dbh, $map_id, $url_fragm );
    print "</map>\n";

    #$dbh->disconnect();
    printStatusLine( "Done.", 2 );
}

############################################################################
# printRelatedCoords -  show link to related KEGG pathway
############################################################################
sub printRelatedCoords {
    my ( $dbh, $map_id, $url_fragm ) = @_;

    my $sql = qq{
	select distinct pw.image_id, roi.x_coord, roi.y_coord,
	       roi.width, roi.height
          from kegg_pathway pw, image_roi roi, kegg_pathway pw0
         where pw0.image_id = ?
           and pw0.pathway_oid = roi.pathway
	   and roi.related_pathway = pw.pathway_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    for ( ;; ) {
        my ( $image_id, $x_coord, $y_coord, $width, $height ) =
	    $cur->fetchrow();
        last if !$image_id;

        my $x1 = $x_coord;
        my $y1 = $y_coord;

        my $x2 = $x1 + $width;
        my $y2 = $y1 + $height;

        print "<area shape='rect' coords='$x1,$y1,$x2,$y2' ";
	my $url = "$section_cgi&map_id=$image_id" . $url_fragm;
	print "href=\"$url\"" . " target='_blank' />";
    }
    $cur->finish();
}

############################################################################
# showMap - displays the pathway map with coloring based on:
#      whether the genes for the given ROI are found in up to 25%, >25%,
#      >50%, >75%, or in all (100%) of selected genomes
############################################################################
sub showMap {
    my $pathway_oid = param("pathway_oid");
    my $map_id = param("map_id");
    my @oids = param("selectedGenome1");
    my $nTaxons = @oids;

    if ( $pathway_oid eq "" ) {
        webError("Please select a pathway to display.<br/>\n");
    }
    if ( $nTaxons < 1 ) {
        webError("Please select at least 1 genome.<br/>\n");
    }
    my $dbh = dbLogin();
    if ( $nTaxons == 1 ) {
    	my $sql = qq{
    	    select is_pangenome
    	    from taxon
    	    where taxon_oid = ?
    	};
    	my $cur = execSql( $dbh, $sql, $verbose, $oids[0] );
    	my ( $is_pangenome ) = $cur->fetchrow();
    	$cur->finish();

    	if (lc($is_pangenome) ne "yes") {
    	    my $mapType = param("mapType");
	    if ( $mapType eq "missingEnzymes" ) {
		KeggMap::printKeggMapMissingECByTaxonOid( $oids[0] );
    	    } else {
		KeggMap::printKeggMapByTaxonOid( $oids[0] );
    	    }

    	    return;
    	}
    }

    printStatusLine( "Loading ...", 1 );

    my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @oids );
    my $taxons_str = "where taxon_oid in ( $oids_str )";
    my $sql = qq{
       select is_pangenome, taxon_oid
       from taxon
       $taxons_str
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my @newoids;
    my @pangenomeids;
    for ( ;; ) {
    	my ( $is_pangenome, $taxon_oid ) = $cur->fetchrow();
    	last if !$taxon_oid;
    	if (lc($is_pangenome) eq "yes") {
    	    push @pangenomeids, $taxon_oid;
    	} else {
    	    push @newoids, $taxon_oid;
    	}
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )
        if ( $oids_str =~ /gtt_num_id/i );

    if (scalar @pangenomeids > 0) {
        my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @pangenomeids );
    	my $pangenomes_str = "where taxon_oid in ( $oids_str ) ";

    	my $sql = qq{
    	    select pangenome_composition, taxon_oid
    	    from taxon_pangenome_composition
    	    $pangenomes_str
        };
    	my $cur = execSql($dbh, $sql, $verbose);
    	my $old_id;
    	for ( ;; ) {
    	    my ( $pcomp, $taxon_oid ) = $cur->fetchrow();
    	    last if !$taxon_oid;
    	    if ($old_id ne $taxon_oid) {
        		push @newoids, $taxon_oid;
        		$old_id = $taxon_oid;
    	    }
    	    push @newoids, $pcomp;
    	}
    	$cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
            if ( $oids_str =~ /gtt_num_id/i );
    }
    #$dbh->disconnect();

    my $taxon_oid_str = join( ',', @newoids );
    showMapForTaxons( $map_id, $taxon_oid_str );
}

############################################################################
# showMapForTaxons - displays the pathway map with coloring based on:
#      whether the genes for the given ROI are found in up to 25%, >25%,
#      >50%, >75%, or in all (100%) of selected genomes
############################################################################
sub showMapForTaxons {
    my ( $map_id, $taxon_oid_str ) = @_;
    if ( $map_id eq "" ) {
	$map_id = param("map_id");
	$taxon_oid_str = param("taxons");
    }

    my $dbh = dbLogin();
    my $sql = qq{
        select pathway_name, pathway_oid
        from kegg_pathway
        where image_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    my ( $pathway_name, $pathway_oid ) = $cur->fetchrow();
    $cur->finish();

    my @taxons = split( ',', $taxon_oid_str );
    my $nTaxons = @taxons;
    my $taxon_oid_str2 = $taxon_oid_str;

    if (OracleUtil::useTempTable($nTaxons + 1)) {
        OracleUtil::insertDataArray($dbh, "gtt_num_id", \@taxons);
        $taxon_oid_str2 = "select id from gtt_num_id";
    }

    printMainForm();
    print "<h1>KEGG Map: $pathway_name</h1>";

    print "<p>";
    print "$nTaxons genomes selected<br/>\n";
    print "<image src='$base_url/images/blue-square.gif' "
	. "width='10' height='10' />\n";
    print "Genes found in all selected genomes";
    print "<br/>\n";

    print "<image src='$base_url/images/yellow-square.gif' "
	. "width='10' height='10' />\n";
    print "<image src='$base_url/images/peach-square.gif' "
	. "width='10' height='10' />\n";
    print "<image src='$base_url/images/pink-square.gif' "
	. "width='10' height='10' />\n";
    print "<image src='$base_url/images/purple-square.gif' "
	. "width='10' height='10' />\n";
    print "Genes found in some of the selected genomes [for up to 25%";
    print "<image src='$base_url/images/yellow-square.gif' "
	. "width='10' height='10' />\n";
    print ">25%";
    print "<image src='$base_url/images/peach-square.gif' "
	. "width='10' height='10' />\n";
    print ">50%";
    print "<image src='$base_url/images/pink-square.gif' "
	. "width='10' height='10' />\n";
    print ">75%";
    print "<image src='$base_url/images/purple-square.gif' "
	. "width='10' height='10' />\n";
    print "]";
    print "<br/>\n";
    print "</p>";

    my $hintstr .=
          "<span style='border:.1em solid rgb(255, 0, 0); "
        . "background-color: rgb(190, 190, 190)'>&nbsp;&nbsp;&nbsp;</span> "
        . "a red border indicates that more than one function maps to "
        . "this reaction.";
    printHint($hintstr);
    print "<br/>";

    printStartWorkingDiv();
    print "<p>Retrieving pathway information from database ...";

    ## Taxon genes (blue)
    my $sql = qq{
           select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                  ir.width, ir.height, ir.roi_label,
                  dt.taxon, kt.ko_id, kt.ko_name, kt.definition
           from dt_gene_ko_module_pwys dt, ko_term kt,
                image_roi ir, image_roi_ko_terms irk
           where dt.taxon in ($taxon_oid_str2)
           and dt.image_id = ?
           and dt.ko_terms = irk.ko_terms
           and dt.pathway_oid = ir.pathway
           and ir.roi_id = irk.roi_id
           and ir.roi_type in ('ko_term', 'enzyme')
           and irk.ko_terms = kt.ko_id
           order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
    };

    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    my @recs = ();
    for ( ;; ) {
        my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
	     $roi_label, $taxon, $ko_id, $ko_name, $ko_defn )
	    = $cur->fetchrow();
        last if !$roi_label;
        my $s = "$shape\t$x_coord\t$y_coord\t$coord_str\t" .
	        "$width\t$height\t$roi_label\t" .
	        "$taxon\t$ko_id\t$ko_name\t$ko_defn";
	push @recs, ( $s );
    }
    $cur->finish();

    if ( $include_metagenomes ) {
	print "<br/>Retrieving pathway information for MER-FS ...";
	my %ko_rois;
	my %ko_names;
	$sql = qq{
            select ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                   ir.width, ir.height, ir.roi_label,
                   ko.ko_id, ko.ko_name, ko.definition
            from image_roi ir, image_roi_ko_terms rk, ko_term ko
            where ir.pathway = ?
            and ir.roi_id = rk.roi_id
            and ir.roi_type in ('ko_term', 'enzyme')
            and rk.ko_terms = ko.ko_id
        };
        $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
	for ( ;; ) {
	    my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
		 $roi_label, $ko_id, $ko_name, $ko_defn ) = $cur->fetchrow();
	    last if !$roi_label;

	    $ko_rois{ $ko_id } =
		"$shape\t$x_coord\t$y_coord\t$coord_str\t" .
		"$width\t$height\t$roi_label";
	    $ko_names{ $ko_id } = "$ko_name\t$ko_defn";
	}
	$cur->finish();

	my $imgClause = WebUtil::imgClause("tx");
        my $rclause = WebUtil::urClause("tx.taxon_oid");
        $sql = qq{
            select tx.taxon_oid
            from taxon tx
            where tx.in_file = 'Yes'
            and tx.taxon_oid in ($taxon_oid_str2)
	    $rclause
            $imgClause
        };
        $cur = execSql( $dbh, $sql, $verbose );
        for ( ;; ) {
            my ( $tx_oid ) = $cur->fetchrow();
            last if ! $tx_oid;

            print ". ";
            my %funcs = MetaUtil::getTaxonFuncCount($tx_oid, '', 'ko');

            for my $ko_id (keys %ko_names) {
		next if (!$funcs{$ko_id});

		my $s = $ko_rois{ $ko_id } .
		        "\t$tx_oid\t$ko_id\t" .
			$ko_names{ $ko_id };
		push @recs, ( $s );
            }
         }
        $cur->finish();
        print "<br/>";
    }

    my @blueRecs;
    my @orangeRecs;
    my @box1;
    my @box2;
    my @box3;
    my @box4;
    my @box5;

    my $group1 = floor( $nTaxons / 4 );
    my $group2 = floor( $nTaxons / 2 );
    my $group3 = floor( $nTaxons * 3 / 4 );

    my $old_roi;
    my %unique_tx;
    my %unique_ko;
    my $koStr;

    my %ko2tx;

    print "<br/>Getting ROI info ...";
    foreach my $s ( sort @recs ) {
        my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
	     $roi_label, $taxon, $ko_id, $ko_name, $ko_defn )
	    = split( /\t/, $s );

	next if $shape eq "line";
	if ($shape eq "poly") {
	    # anna: strip the coord_str to get only the coords:
	    my $begin = index($coord_str, "(");
	    my $end = index((reverse $coord_str), ")");
	    $coord_str = substr($coord_str, $begin+1, -($end+1));
	    $width = -1;
	    $height = $coord_str;
	}
        #if ($shape eq "line") {
        #    $width = 10;
        #    $height = 10;
	#    $shape = "rect";
        #}
        my $r = "$x_coord\t";
        $r .= "$y_coord\t";
        $r .= "$width\t";
        $r .= "$height\t";
	$r .= "$shape";

	next if ($width <= 0 || $height <= 0) && $shape eq "rect";
	next if ($height <= 0); # can't display this roi

        my $ko = "$roi_label";
        my $koLabel = "$roi_label, $ko_name";
 	$koLabel .= ", $ko_defn" if $ko_defn ne "";

        if ( $old_roi eq "" ) {
            $old_roi = $r;
        }
        if ( $old_roi eq $r ) {
	    $unique_ko{$ko} = $koLabel;
	    $unique_tx{$taxon} = 1;
	    $ko2tx{$ko}++;
        } else {
	    my @kos = keys(%unique_ko);
	    my $allblue = 1;
	    my $allsame = 1;
	    my @labels;
	    my $mycnt;

	    foreach my $k (@kos) {
		my $koLabelStr = $unique_ko{ $k };
		my $cnt = $ko2tx{$k};
		$mycnt = $cnt if $mycnt eq "";
		$allsame = 0 if $cnt != $mycnt;

		$koLabelStr = $cnt. "/" . $nTaxons . " " . $koLabelStr;
		push @labels, $koLabelStr;
		$allblue = 0 if $cnt < $nTaxons;
	    }

	    my $koStr = join(",", sort(keys(%unique_ko)));
	    my $koLabelStr = join("; ", sort(@labels));

	    my $count = scalar keys (%unique_tx);
	    $old_roi .= "\t$koStr" . "\t$koLabelStr";

            %unique_tx = ();
	    %unique_ko = ();
	    %ko2tx = ();

            if ( $allblue ) {
                push( @blueRecs, $old_roi );
            } else {
                push( @orangeRecs, $old_roi );

		if (scalar @kos > 1 && !$allsame) {
		    push( @box5, $old_roi);
		} else {
		    $count = $mycnt if @kos > 1;
		    if ( $count > $group3 ) {
			push( @box4, $old_roi );
		    } elsif ( $count > $group2 ) {
			push( @box3, $old_roi );
		    } elsif ( $count > $group1 ) {
			push( @box2, $old_roi );
		    } else {
			push( @box1, $old_roi );
		    }
		}
            }
	    $unique_ko{$ko} = $koLabel;
	    $unique_tx{$taxon} = 1;
	    $ko2tx{$ko}++;
        }
        $old_roi = $r;
    }

    OracleUtil::truncTable($dbh, "gtt_num_id"); # clean up temp table

    printEndWorkingDiv();

    my @kos = keys(%unique_ko);
    my $allblue = 1;
    my $allsame = 1;
    my @labels;
    my $mycnt;

    foreach my $k (@kos) {
	my $koLabelStr = $unique_ko{ $k };
	my $cnt = $ko2tx{$k};
	$mycnt = $cnt if $mycnt eq "";
	$allsame = 0 if $cnt != $mycnt;

	$koLabelStr = $cnt. "/" . $nTaxons . " " . $koLabelStr;
	push @labels, $koLabelStr;
	$allblue = 0 if $cnt < $nTaxons;
    }

    my $koStr = join(",", sort(keys(%unique_ko)));
    my $koLabelStr = join("; ", sort(@labels));

    my $count = scalar keys (%unique_tx);
    $old_roi .= "\t$koStr" . "\t$koLabelStr";

    if ( $allblue ) {
	push( @blueRecs, $old_roi );
    } else {
	push( @orangeRecs, $old_roi );

	if (scalar @kos > 1 && !$allsame) {
	    push( @box5, $old_roi);
	} else {
	    $count = $mycnt if @kos > 1;
	    if ( $count > $group3 ) {
		push( @box4, $old_roi );
	    } elsif ( $count > $group2 ) {
		push( @box3, $old_roi );
	    } elsif ( $count > $group1 ) {
		push( @box2, $old_roi );
	    } else {
		push( @box1, $old_roi );
	    }
	}
    }

    my $inFile = "$pngDir/$map_id.png";
    GD::Image->trueColor(1);
    my $im = new GD::Image($inFile);
    if ( !$im ) {
        webDie("showMapForTaxons: cannot read '$inFile'\n");
    }

    applyHighlights( $im, \@blueRecs, "blue" );

    applyHighlightsRGB( $im, \@box1, 255, 255,  0,  50 );
    applyHighlightsRGB( $im, \@box2, 255, 158,  32, 50 );
    applyHighlightsRGB( $im, \@box3, 255, 64,   64, 50 );
    applyHighlightsRGB( $im, \@box4, 192, 0,    86, 50 );
    applyHighlightsRGB( $im, \@box5, 190, 190, 190, 50 );

    my $tmpPngFile = "$tmp_dir/$map_id.$$.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.$$.png";
    my $wfh = newWriteFileHandle( $tmpPngFile, "showMapForTaxons" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";
    print "<map name='mapdata'>\n";
    printImageMapCoords( \@blueRecs,   $map_id, $taxon_oid_str );
    printImageMapCoords( \@orangeRecs, $map_id, $taxon_oid_str );

    my $url_fragm = "&page=keggMapTaxons&taxons=$taxon_oid_str";
    printRelatedCoords( $dbh, $map_id, $url_fragm );
    print "</map>\n";

    #$dbh->disconnect();
    printStatusLine( "Done.", 2 );
}

############################################################################
# showMapForSamples - displays the kegg map with coloring based on:
#      whether the genes for the given ROI are found in up to 25%, >25%,
#      >50%, >75%, or in all (100%) of selected samples
############################################################################
sub showMapForSamples {
    my $map_id = param("map_id");
    my $study = param("study");
    my $sample_oid_str = param("samples");
    my @sample_oids = split(',', $sample_oid_str);
    my $nSamples = @sample_oids;

    if ( $map_id eq "" ) {
        webError("Please select a pathway to display.<br/>\n");
    }
    if ($nSamples < 1) {
        webError( "Please select at least 1 sample." );
    } elsif ($nSamples == 1) {
	showMapForOneSample($map_id, @sample_oids[0], $study);
	return;
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select pathway_name, pathway_oid
        from kegg_pathway
        where image_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    my ( $pathway_name, $pathway_oid ) = $cur->fetchrow();
    $cur->finish();
    print "<h1>KEGG Map: $pathway_name</h1>";

    my $clusterFileName = param("file");   # cluster id mapping
    my $dataFileName = param("dataFile");  # expression data
    if ($clusterFileName eq "") {
	print "<p>";
	print "$nSamples samples selected ($sample_oid_str)<br/>\n";
	print "<image src='$base_url/images/blue-square.gif' "
	    . "width='10' height='10' />\n";
	print "Genes found in all selected samples";
	print "<br/>\n";

	print "<image src='$base_url/images/yellow-square.gif' "
	    . "width='10' height='10' />\n";
	print "<image src='$base_url/images/peach-square.gif' "
	    . "width='10' height='10' />\n";
	print "<image src='$base_url/images/pink-square.gif' "
	    . "width='10' height='10' />\n";
	print "<image src='$base_url/images/purple-square.gif' "
	    . "width='10' height='10' />\n";
	print "Genes found in some of the selected samples [for up to 25%";
	print "<image src='$base_url/images/yellow-square.gif' "
	    . "width='10' height='10' />\n";
	print ">25%";
	print "<image src='$base_url/images/peach-square.gif' "
	    . "width='10' height='10' />\n";
	print ">50%";
	print "<image src='$base_url/images/pink-square.gif' "
	    . "width='10' height='10' />\n";	print ">75%";
	print "<image src='$base_url/images/purple-square.gif' "
	    . "width='10' height='10' />\n";
	print "]";
	print "<br/>\n";
	print "</p>";

	my $hintstr .=
	    "<span style='border:.1em solid rgb(255, 0, 0); "
	  . "background-color: rgb(190, 190, 190)'>&nbsp;&nbsp;&nbsp;</span> "
	  . "a red border indicates that more than one function maps to "
	  . "this reaction.";
	printHint($hintstr);
	print "<br/>";
    }

    printStartWorkingDiv("samples");
    print "Retrieving pathway information for samples ... <br/>\n";

    my ($taxon_oid, $in_file, $genome_type);
    my %sample2taxon;
    my %taxons;
    my %dtNames;
    my %genes4all;
    my %sample2geneInfo;

    if ($study eq "rnaseq") {
        my $names_ref = RNAStudies::getNamesForSamples($dbh, $sample_oid_str);
        %dtNames = %$names_ref;

        # see if this taxon is MER-FS
	my $datasetClause = RNAStudies::datasetClause("dts");
        my $txsql = qq{
            select distinct dts.dataset_oid, dts.reference_taxon_oid,
                   tx.in_file, tx.genome_type
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = tx.taxon_oid
            $datasetClause
        };
        my $cur = execSql( $dbh, $txsql, $verbose );
        for( ;; ) {
            my( $sid, $tx, $in, $gt ) = $cur->fetchrow();
            last if !$sid;
            $sample2taxon{ $sid } = $tx;
            $taxons{ $tx } = $in . "," . $gt;

	    # get the genes from SDB:
	    my %gene2info = MetaUtil::getGenesForRNASeqSample($sid, $tx);
	    my @genes = keys %gene2info;
	    if (scalar @genes < 1) {
		# get genes for this sample from Oracle database:
		my $dtClause = RNAStudies::datasetClause("es");
		my $sql = qq{
                    select distinct g.gene_oid,
                    g.gene_display_name, g.locus_tag
                    from rnaseq_expression es, gene g
                    where es.dataset_oid = ?
                    and es.reads_cnt > 0.0000000
                    and es.IMG_gene_oid = g.gene_oid
                    $dtClause
                };
		my $cur = execSql( $dbh, $sql, $verbose, $sid );
		for ( ;; ) {
		    my ( $gid, $name, $locus_tag ) = $cur->fetchrow();
		    last if !$gid;
		    push @genes, $gid;
		    $gene2info{ $gid } = $gid."\t".$name."\t".$locus_tag;
		}
	    }
	    $sample2geneInfo{ $tx.$sid } = \%gene2info;
	    %genes4all = (%genes4all, %gene2info);
        }
        $cur->finish();

        my @taxons = keys %taxons;
        if (scalar @taxons == 1) {
            $taxon_oid = @taxons[0];
            ($in_file, $genome_type) = split(",", $taxons{ $taxon_oid });
        }

    } else {
        my $txsql = qq{
            select s.IMG_taxon_oid, tx.in_file
            from ms_sample s, taxon tx
            where s.sample_oid in ($sample_oid_str)
            and s.IMG_taxon_oid = tx.taxon_oid
        };
        my $cur = execSql( $dbh, $txsql, $verbose );
        ($taxon_oid, $in_file) = $cur->fetchrow();
        $cur->finish();
    }

    my @recs = ();
    my %allkoGenes; # get genes for this image
    my %allKo2genes;

    if ($study eq "rnaseq") {
	print "Retrieving ko information ... <br/>\n";
	my %all_kos;
	my %prodNames;

        foreach my $tx (keys %taxons) {
            my ($infile, $gt) = split(",", $taxons{ $tx });
            if ($infile eq "Yes") {
		print "TX:$tx kos from file <br/>";
		my %tx_kos = MetaUtil::getTaxonFuncCount
		    ($tx, 'assembled', 'ko');
                #@all_kos{ keys %tx_kos } = values %tx_kos;
		$all_kos{ $tx } = \%tx_kos;
            } else {
		print "TX:$tx kos from db <br/>";
		my $sql = qq{
                    select distinct gkt.ko_terms
                    from gene_ko_terms gkt
                    where gkt.taxon = ?
        	};
		my $cur = execSql( $dbh, $sql, $verbose, $tx );
		my %txkos;
		for ( ;; ) {
		    my ($koid) = $cur->fetchrow();
		    last if !$koid;
		    $txkos{ $koid } = 1;
		}
		$all_kos{ $tx } = \%txkos;
    	    }

    	    if ($clusterFileName ne "") {
		if ($gt eq "metagenome") {
		    %prodNames = MetaUtil::getGeneProdNamesForTaxon
			($tx, "assembled");
		} else {
		    my @genes = keys %genes4all;
		    my $gene2prod = RNAStudies::getGeneProductNames
			($dbh, $tx, \@genes);
		    %prodNames = %$gene2prod;
		}
    	    }
        }

	print "Getting ROI info for pathway $pathway_oid <br/>";
	$sql = qq{
            select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                   ir.width, ir.height, ir.roi_label,
                   ko.ko_id, ko.ko_name, ko.definition
            from image_roi ir, image_roi_ko_terms rk, ko_term ko
            where ir.pathway = ?
            and ir.roi_id = rk.roi_id
            and ir.roi_type in ('ko_term', 'enzyme')
            and rk.ko_terms = ko.ko_id
        };
	$cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
	my %done;
	for ( ;; ) {
	    my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
		 $roi_label, $ko_id, $ko_name, $ko_defn ) = $cur->fetchrow();
	    last if !$roi_label;
	    #next if (!$all_kos{$ko_id});
	    my $ko = $ko_id;
	    $ko =~ s/KO://g;

            TX: foreach my $tx (keys %taxons) {
		my $tx_kos_ref = $all_kos{ $tx };
		next if (!$tx_kos_ref->{ $ko_id });
		my ($infile, $gt) = split(",", $taxons{ $tx });
                #my $infile = $taxons{ $tx };

		my @gene_group;
		if ($infile ne "Yes") {
		    my $rclause   = WebUtil::urClause('g.taxon');
		    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
		    my $sql       = qq{
                        select distinct g.gene_oid
                        from gene g, gene_ko_terms gkt
                        where gkt.taxon = ?
                        and gkt.ko_terms = ?
                        and g.gene_oid = gkt.gene_oid
                        and g.locus_type = 'CDS'
                        and g.obsolete_flag = 'No'
                        $rclause
                        $imgClause
                    };
		    my $cur2 = execSql( $dbh, $sql, $verbose, $tx, $ko_id );
		    for ( ;; ) {
			my ($kgid) = $cur2->fetchrow();
			last if !$kgid;
			push @gene_group, $kgid;
		    }

		} else {
		    my %ko_genes = MetaUtil::getTaxonFuncGenes
			($tx, "assembled", $ko_id);
		    @gene_group = keys %ko_genes;
		}
		next TX if scalar @gene_group == 0;

	        SAMPLE: foreach my $s (@sample_oids) {
		    my $g2is_ref = $sample2geneInfo{ $tx.$s };
		    GENE: foreach my $gene_oid (@gene_group) {
		      if (exists $g2is_ref->{ $gene_oid }) {
			  my $sname = $dtNames{ $s };
                          my $r = "$shape\t$x_coord\t$y_coord\t$coord_str\t" .
                                  "$width\t$height\t$roi_label\t$s\t$sname\t" .
                                  "$ko_id\t$ko_name\t$ko_defn";
                          push @recs, ( $r );
                          next SAMPLE;
		      }
		    }
		}

		GENE: foreach my $gene_oid (@gene_group) {
		  SAMPLE: foreach my $s (@sample_oids) {
		      my $g2is_ref = $sample2geneInfo{ $tx.$s };
                      if (exists $g2is_ref->{ $gene_oid }) {
			  if ($clusterFileName ne ""
			      && !$done{$ko.$gene_oid}) {

			      my $product = $prodNames{ $gene_oid };
			      my $line = $g2is_ref->{ $gene_oid };
			      my ($geneid, $gn, $locus_tag, @rest)
				  = split("\t", $line);
			      $product = $gn if !$product || $product eq "";

			      if (exists $allkoGenes{ $gene_oid } &&
				  defined $allkoGenes{ $gene_oid } ) {
				  $allkoGenes{ $gene_oid } .= ",$ko";
			      } else {
				  $allkoGenes{ $gene_oid } =
				      $product."\t".$locus_tag."\t".$ko;
			      }

			      $allKo2genes{ $ko } .= $gene_oid;
			      $allKo2genes{ $ko } .= "#";

			      $done{$ko.$gene_oid} = 1;
			  }
			  next GENE;
                      }
                  }
		}
            }
        }
	$cur->finish();

    } else {
	# proteomics query
	my $sql = qq{
            select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                   ir.width, ir.height, ir.roi_label,
	           dt.sample_oid, dt.sample_desc,
                   kt.ko_id, kt.ko_name, kt.definition
    	      from image_roi_ko_terms irk,
	           image_roi ir,
                   ko_term kt,
	           gene_ko_terms gkt,
                   dt_img_gene_prot_pep_sample dt
             where ir.roi_id= irk.roi_id
               and ir.roi_type in ('ko_term', 'enzyme')
	       and irk.ko_terms = gkt.ko_terms
	       and gkt.gene_oid = dt.gene_oid
  	       and dt.sample_oid in ($sample_oid_str)
               and ir.pathway = ?
               and gkt.ko_terms = kt.ko_id
          order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
        };

	print "Retrieving information from database ... <br/>\n";
	my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
	for ( ;; ) {
            my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
		 $roi_label, $sample, $sname, $ko_id, $ko_name, $ko_defn )
                = $cur->fetchrow();
            last if !$roi_label;
	    $sname = $dtNames{ $sample } if $study eq "rnaseq";
            my $r = "$shape\t$x_coord\t$y_coord\t$coord_str\t" .
		    "$width\t$height\t$roi_label\t$sample\t$sname\t" .
                    "$ko_id\t$ko_name\t$ko_defn";
            push @recs, ( $r );
	}
	$cur->finish();
    }

    printEndWorkingDiv("samples");

    my @blueRecs;
    my @orangeRecs;
    my @box1;
    my @box2;
    my @box3;
    my @box4;
    my @box5;

    my $group1 = floor( $nSamples / 4 );
    my $group2 = floor( $nSamples / 2 );
    my $group3 = floor( $nSamples * 3 / 4 );

    my $old_roi;
    my %unique_ss;
    my %unique_ko;
    my $koStr;

    my %allKo;
    my %roi2ko;
    my %ko2ss;
    my %sampleNames;

    foreach my $s ( sort @recs) {
        my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
	     $roi_label, $sample, $sname, $ko_id, $ko_name, $ko_defn )
	    = split( /\t/, $s );

        $sampleNames{ $sample } = $sname;
        $allKo{ $ko_id } = 1; # collect all ko terms

	next if $shape eq "line";
        if ($shape eq "poly") {
            # anna: strip the coord_str to get only the coords:
            my $begin = index($coord_str, "(");
            my $end = index((reverse $coord_str), ")");
            $coord_str = substr($coord_str, $begin+1, -($end+1));
            $width = -1;
            $height = $coord_str;
        }
	#if ($shape eq "line") {
	#    $width = 10;
	#    $height = 10;
	#    $shape = "rect";
	#}
        my $r = "$x_coord\t";
        $r .= "$y_coord\t";
        $r .= "$width\t";
        $r .= "$height\t";
	$r .= "$shape";

        next if ($width <= 0 || $height <= 0) && $shape eq "rect";
        next if ($height <= 0); # can't display this roi

	my $ko = "$roi_label";
	my $koLabel = "$roi_label, $ko_name";
	$koLabel .= ", $ko_defn" if $ko_defn ne "";

	$roi2ko{$r} .= $ko."#";

        if ( $old_roi eq "" ) {
            $old_roi = $r;
        }
        if ( $old_roi eq $r ) {
	    $unique_ko{$ko} = $koLabel;
	    $unique_ss{$sample} = 1;
	    $ko2ss{$ko}++;
        } else {
            my @kos = keys(%unique_ko);
            my $allblue = 1;
            my $allsame = 1;
            my @labels;
            my $mycnt;

            foreach my $k (@kos) {
                my $koLabelStr = $unique_ko{ $k };
                my $cnt = $ko2ss{$k};
                $mycnt = $cnt if $mycnt eq "";
                $allsame = 0 if $cnt != $mycnt;

                $koLabelStr = $cnt. "/" . $nSamples . " " . $koLabelStr;
                push @labels, $koLabelStr;
                $allblue = 0 if $cnt < $nSamples;
            }

	    my $koStr = join(",", sort(keys(%unique_ko)));
	    my $koLabelStr = join("; ", sort(@labels));

            my $count = scalar keys (%unique_ss);
            $old_roi .= "\t$koStr" . "\t$koLabelStr";

	    %unique_ss = ();
	    %unique_ko = ();
	    %ko2ss = ();

            if ( $count == $nSamples ) {
                push( @blueRecs, $old_roi );
            } else {
                push( @orangeRecs, $old_roi );

                if (scalar @kos > 1 && !$allsame) {
                    push( @box5, $old_roi);
                } else {
                    $count = $mycnt if @kos > 1;
		    if ( $count > $group3 ) {
			push( @box4, $old_roi );
		    } elsif ( $count > $group2 ) {
			push( @box3, $old_roi );
		    } elsif ( $count > $group1 ) {
			push( @box2, $old_roi );
		    } else {
			push( @box1, $old_roi );
		    }
		}
	    }
	    $unique_ko{$ko} = $koLabel;
	    $unique_ss{$sample} = 1;
	    $ko2ss{$ko}++;
        }
        $old_roi = $r;
    }

    my @kos = keys(%unique_ko);
    my $allblue = 1;
    my $allsame = 1;
    my @labels;
    my $mycnt;

    foreach my $k (@kos) {
        my $koLabelStr = $unique_ko{ $k };
        my $cnt = $ko2ss{$k};
        $mycnt = $cnt if $mycnt eq "";
        $allsame = 0 if $cnt != $mycnt;

        $koLabelStr = $cnt. "/" . $nSamples . " " . $koLabelStr;
        push @labels, $koLabelStr;
        $allblue = 0 if $cnt < $nSamples;
    }

    my $koStr = join(",", sort(keys(%unique_ko)));
    my $koLabelStr = join("; ", sort(@labels));

    my $count = scalar keys (%unique_ss);
    $old_roi .= "\t$koStr" . "\t$koLabelStr";

    if ( $allblue ) {
        push( @blueRecs, $old_roi );
    } else {
        push( @orangeRecs, $old_roi );

        if (scalar @kos > 1 && !$allsame) {
            push( @box5, $old_roi);
        } else {
            $count = $mycnt if @kos > 1;
	    if ( $count > $group3 ) {
		push( @box4, $old_roi );
	    } elsif ( $count > $group2 ) {
		push( @box3, $old_roi );
	    } elsif ( $count > $group1 ) {
		push( @box2, $old_roi );
	    } else {
		push( @box1, $old_roi );
	    }
	}
    }

    my $inFile = "$pngDir/$map_id.png";
    GD::Image->trueColor(1);
    my $im = new GD::Image($inFile);
    if ( !$im ) {
        webDie("showMap: cannot read '$inFile'\n");
    }

    my %ko2genes;
    my %allGenes; # get genes for this image
    if ($clusterFileName ne "" &&
	($study eq "rnaseq" || $study eq "proteomics")) {
	my $hintstr =
              "Samples have been clustered into cluster groups. "
	    . "Functions with genes belonging to the same cluster are colored "
	    . "by the color of that cluster group (see Cluster ID).<br/>"
	    . "<span style='border:.1em solid rgb(255, 0, 0); "
	    . "background-color: rgb(190, 190, 190)'>&nbsp;&nbsp;&nbsp;"
	    . "</span> indicates that genes mapping to this function belong "
	    . "to different clusters.";
	printHint($hintstr);

	print qq{
	    <script type='text/javascript'
            src='$YUI/build/yahoo-dom-event/yahoo-dom-event.js'>
	    </script>

	    <script language='JavaScript' type='text/javascript'>
	    function showColors(type) {
            if (type == 'nocolors') {
                document.getElementById('showcolors').style.display = 'none';
                document.getElementById('hidecolors').style.display = 'block';
            } else {
                document.getElementById('showcolors').style.display = 'block';
                document.getElementById('hidecolors').style.display = 'none';
            }
            }

	    function getUrl(url) {
                var els = document.getElementsByName('gene_oid');
                var found = 0;
                for (var i = 0; i < els.length; i++) {
                    var e = els[i];
                    if (e.checked == true) {
			if (found == 0) {
                            url = url+"&genes="+e.id;
			} else {
			    url = url+","+e.id;
			}
			found++;
			if (found == 5) break; // only 5 genes allowed
                    }
		}
		return url;
	    }
            </script>
	};

        # read the cluster id for each gene:
	my $clusterFile = $tmp_dir."/".$clusterFileName;
	if (! -e $clusterFile) {
	    webError("Cannot find the cdt cluster file $clusterFile. "
		   . "Please reload clusters to pathways mapping.");
	}

        my $rfh = newReadFileHandle( $clusterFile, "loadClusters" );
	my %uniqueClusters;
	my %clusteredData;
	my %color_hash;
	my $i = 0;
        while( my $s = $rfh->getline() ) {
	    $i++;
	    next if $i == 1; # header line
            chomp $s;

            my( $gid, $value ) = split( / /, $s );
            $gid =~ s/"//g;
            $clusteredData{ $gid } = $value;
            $uniqueClusters{ $value } = 1;
        }
        close $rfh;

        # load color array
	my $colors;
	my $color_array_file = $env->{ large_color_array_file };
	my @color_array = RNAStudies::loadMyColorArray
            ($im, $color_array_file);

	my @clusters = sort keys( %uniqueClusters );
	my $nClusters = scalar @clusters;
	my $n = ceil($nClusters/255);
	my $i = 0;

	foreach my $cluster (@clusters) {
	    #my $idx = ceil($i/$n);
	    #$color_hash{ $cluster } = $color_array[ $idx ];
            if ($i == 246) { $i = 0; }
	    $color_hash{ $cluster } = $color_array[ $i ];
	    $i++;
	}

        # map gene to koterm
        my @ko = sort keys(%allKo);
        my $allKoStr;
        if (OracleUtil::useTempTable($#ko + 1)) {
            OracleUtil::insertDataArray($dbh, "gtt_func_id", \@ko);
            $allKoStr = "select id from gtt_func_id";
        } else {
            $allKoStr = joinSqlQuoted(",", @ko);
            $allKoStr =~ s/KO://g;
        }

        if (scalar @ko == 0) {
            my $tmpPngFile = "$tmp_dir/$map_id.$$.png";
            my $tmpPngUrl  = "$tmp_url/$map_id.$$.png";
            my $wfh = newWriteFileHandle( $tmpPngFile, "showMapForSamples" );
            binmode $wfh;
            print $wfh $im->png;
            close $wfh;

            print "<br/>";
            print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";
            print "<map id='mapdata' name='mapdata'>\n";
            my $url_fragm = "&page=keggMapSamples"
                          . "&study=$study&samples=$sample_oid_str";
            #if ($clusterFileName ne "") {
                $url_fragm .= "&file=$clusterFileName";
                if ($dataFileName ne "") {
                    $url_fragm .= "&dataFile=$dataFileName";
                }
            #}
            printRelatedCoords( $dbh, $map_id, $url_fragm );
            print "</map>\n";

            #$dbh->disconnect();
            printStatusLine( "Done.", 2 );
            return;
        }

        # when using only genes from GeneCart:
        # should we be able to do this?
        #my $gene_str = join(",", sort keys ( %clusteredData ));
        #and g.gene_oid in ($gene_str)

	printStartWorkingDiv("genes");

	if ($study eq "rnaseq") {
	    foreach my $ko (@ko) {
		$ko =~ s/KO://g;

		my $gstr = $allKo2genes{ $ko };
		my @kogenes = split("#", $gstr);

		foreach my $gene ( @kogenes ) {
		    next if $gene eq "";
		    my $clusterID = $clusteredData{ $gene };
		    my $infostr = $allkoGenes{ $gene };
		    my ($product, $locus_tag, $kostr) = split("\t", $infostr);

		    if (exists $allGenes{ $gene } &&
			defined $allGenes{ $gene } ) {
			$allGenes{ $gene } .= ",$ko";
		    } else {
			$allGenes{ $gene } =
			    $product."\t".$locus_tag."\t".$ko;
		    }

		    $ko2genes{ $ko } .=
			$gene."\t".$product."\t".$locus_tag."\t".$clusterID;
		    $ko2genes{ $ko } .= "#";
		}
	    }

	} elsif ($study eq "proteomics") {
	    my $sql = qq{
                select distinct iroi.roi_label, g.gene_oid,
                       g.gene_display_name, g.locus_tag
                from image_roi_ko_terms irk, gene_ko_terms gk,
                     image_roi iroi, kegg_pathway pw,
                     dt_img_gene_prot_pep_sample dt, gene g
               where pw.image_id = ?
                 and irk.roi_id = iroi.roi_id
                 and irk.ko_terms = gk.ko_terms
                 and gk.gene_oid = g.gene_oid
                 and iroi.pathway = pw.pathway_oid
                 and dt.sample_oid in ($sample_oid_str)
                 and dt.gene_oid = g.gene_oid
                 and dt.coverage > 0.000
                 and iroi.roi_label in ($allKoStr)
                 and g.obsolete_flag = 'No'
            order by iroi.roi_label, g.gene_oid
 	    };

	    print "Querying database for genes ... <br/>\n";
	    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
	    for ( ;; ) {
		my ( $koterm, $gene, $gene_name, $locus_tag )
		    = $cur->fetchrow();
		last if !$koterm;

		my $clusterID = $clusteredData{ $gene };

		if (exists $allGenes{ $gene } &&
		    defined $allGenes{ $gene } ) {
		    $allGenes{ $gene } .= ",$koterm";
		} else {
		    $allGenes{ $gene } =
			$gene_name."\t".$locus_tag."\t".$koterm;
		}
		$ko2genes{ $koterm } .=
		    $gene."\t".$gene_name."\t".$locus_tag."\t".$clusterID;
		$ko2genes{ $koterm } .= "#";
	    }
	    $cur->finish();
	}

	webLog("\nTOTAL GENES (for IMAGE $map_id): "
	       . scalar (keys %allGenes) ."\n");

	printEndWorkingDiv("genes");

	# read expression data for each gene and sample:
	my %gene2data;
	my @samples;
        if ($dataFileName ne "") {
	    my $dataFile = $tmp_dir."/".$dataFileName;
	    webLog("\nDATA FILE: $dataFile");
	    my $rfh = newReadFileHandle( $dataFile, "loadData" );
	    my $i = 0;
	    while( my $s = $rfh->getline() ) {
		chomp $s;
		$i++;
		if ($i == 1) {
		    @samples = split( /\t/, $s );
		    splice(@samples, 0, 4); # starts with the 4th element
		}
 		next if $i < 4;

		my( $idx, $gid, $name, $weightx, $valuesStr )
		    = split( /\t/, $s, 5 );
		my @values = split( /\t/, $valuesStr );
		$gene2data{ $gid } = join(",", @values);
	    }
	    close $rfh;
	}

	printMainForm();
        my $it = new InnerTable(1, "clustercolors$$", "clustercolors", 1);
	$it->disableSelectButtons();
        $it->{ pageSize } = "10";

        my $sd = $it->getSdDelim();
	$it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID", "asc", "right" );
        $it->addColSpec( "Cluster ID", "asc", "right" );
        $it->addColSpec( "Locus Tag", "asc", "left" );
        $it->addColSpec( "Product Name", "asc", "left" );
        $it->addColSpec( "KO", "asc", "left" );

        foreach my $s( @samples ) {
	    $s=~s/^\s+//;
	    $s=~s/\s+$//;
	    $it->addColSpec
                ( $sampleNames{$s}." [".$s."]", "desc", "right", "",
                  "Normalized Expression Data<br/>for: "
                  . $sampleNames{$s}, "wrap" );
        }

	printJSForExpression();
        foreach my $gene( keys %allGenes ) {
            my $url1 = "$main_cgi?section=GeneDetail"
		     . "&page=geneDetail&gene_oid=$gene";
	    if ($in_file eq "Yes") {
		$url1 = "$main_cgi?section=MetaGeneDetail"
		      . "&page=metaGeneDetail&gene_oid=$gene"
		      . "&data_type=assembled&taxon_oid=$taxon_oid";
	    }

            my $clusterid = $clusteredData{ $gene };
            my $color  = $color_hash{ $clusterid };
            my ( $r, $g, $b ) = $im->rgb( $color );

            my ($product, $locus, $ko)
                = split('\t', $allGenes{$gene});

	    my $row = $sd."<input type='checkbox' id='$gene' "
		    . "onclick=\"javascript:draw('$gene', '$ko')\" "
                    . "name='gene_oid' value='$ko'/>\t";
            $row .= $gene.$sd.alink($url1, $gene, "_blank")."\t";

            $row .= $clusterid.$sd;
            $row .= "<span style='border-right:1em solid rgb($r, $g, $b); "
                 . "padding-right:0.5em; margin-right:0.5em'> "
                 . "$clusterid</span>";
            $row .= "\t";

            $row .= $locus.$sd.$locus."\t";
            $row .= $product.$sd.$product."\t";

            $row .= $ko.$sd.$ko."\t";

	    my @values = split(",", $gene2data{ $gene });
	    foreach my $expr (@values) {
		$expr = sprintf("%.3f", $expr);
		$row .= $expr.$sd;

		my $ff0;
		if ( $expr < 0.00 ) {
		    $ff0 = -1 * $expr;
		} else {
		    $ff0 = $expr;
		}
		if ($ff0 > 1.0000000) { # should not really happen ...
		    $ff0 = 1.0;
		}

		my ($r, $g, $b);
		if ($expr < 0.00) {
		    $r = 0;
		    $g = int(205*$ff0 + 50);
		    $b = 0;
		} else {
		    $r = int(205*$ff0 + 50);
		    $g = 0;
		    $b = 0;
		}

		$row .= "<span style='border-right:1em solid rgb($r, $g, $b); "
		    . "padding-right:0.5em; margin-right:0.5em'> "
		    . "$expr</span>";
		$row .= "\t";
	    }

            $it->addRow($row);
        }

        print "<div id='hidecolors' style='display: none;'>";
        print "<input type='button' class='medbutton' name='view'"
            . " value='Show Cluster Colors'"
            . " onclick='showColors(\"colors\")' />";
        print "</div>\n";

        print "<div id='showcolors' style='display: block;'>";
        print "<input type='button' class='medbutton' name='view'"
            . " value='Hide Cluster Colors'"
            . " onclick='showColors(\"nocolors\")' />";

	print qq{
	    <p>Selecting a gene, finds it on the map and marks it with
	       <image src='$base_url/images/roi-marker.jpg' /><br/>
	       Gene expression data coloring is based on
	       red (high) to green (low) expression.<br/>
	       <image src='$base_url/images/colorstrip.80.png'
	       width='300' height='10' /></p>
	};

        $it->printOuterTable(1);

	my $url2 = "xml.cgi?section=PathwayMaps&page=exprGraph";
	#$url2 .= "&samples=$sample_oid_str";
	$url2 .= "&study=$study";
	if ($dataFileName ne "") {
	    $url2 .= "&dataFile=$dataFileName";
	}

        print "<input type='button' class='medbutton' "
            . " id='anchor1' value='Compare Selected' "
            . " onclick=javascript:showImage(getUrl('$url2')) />";

	print end_form();
        print "</div>\n";

        colorByCluster( $im, \%roi2ko, \%ko2genes, \%color_hash );

    } else {
        applyHighlights( $im, \@blueRecs, "blue" );
        applyHighlightsRGB( $im, \@box1, 255, 255,  0,  50 );
        applyHighlightsRGB( $im, \@box2, 255, 158,  32, 50 );
        applyHighlightsRGB( $im, \@box3, 255, 64,   64, 50 );
        applyHighlightsRGB( $im, \@box4, 192, 0,    86, 50 );
	applyHighlightsRGB( $im, \@box5, 190, 190, 190, 50 );
    }

    my $tmpPngFile = "$tmp_dir/$map_id.$$.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.$$.png";
    my $wfh = newWriteFileHandle( $tmpPngFile, "showMapForSamples" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    print qq{
	<script type="application/javascript">
        function draw(item, kostring) {
	    var checked = document.getElementById(item).checked;
	    var startElement = document.getElementById('mapdata');
	    var els = startElement.getElementsByTagName('area');

	    if (checked == false) {
		// see if other rows with same ko are still checked
		var kels = document.getElementsByName('gene_oid');
		var strs = kostring.split(",");

	        outer: for (var k = 0; k < strs.length; k++) {
		    for (var i = 0; i < kels.length; i++) {
			var e = kels[i];

			if (e.id == item) continue;
			if (e.value == kostring &&
			    e.checked == true) {
			    return;
			} else if (e.value == strs[k] &&
				   e.checked == true) {
			    return;
			} else {
			    var kos = e.value.split(",");
			    for (var j = 0; j < kos.length; j++) {
				if (strs[k] == kos[j] &&
				    e.checked == true) {
				    continue outer;
				}
			    }
		        }
		    }
		    findOnMap(strs[k], false);
		}
		return;
	    }

	    findOnMap(kostring, checked);
	}

	function findOnMap(kostring, checked) {
            var startElement = document.getElementById('mapdata');
            var els = startElement.getElementsByTagName('area');

            for (var i = 0; i < els.length; i++) {
                var e = els[i];
                if (e.id == kostring) {
                    markIt(e.coords, checked);
                } else {
                    var kos = e.id.split(",");
                    var strs = kostring.split(",");
                    matchem: for (var j = 0; j < kos.length; j++) {
                        for (var k = 0; k < strs.length; k++) {
                            if (kos[j] == strs[k]) {
                                markIt(e.coords, checked);
                                break matchem;
                            }
                        }
                    }
                }
            }
	}

	function clearCanvas() {
            var canvas = document.getElementById("imgCanvas");
            if (canvas.getContext) {
                var ctx = canvas.getContext("2d");
		ctx.clearRect(0, 0, canvas.width, canvas.height);
	    }
	}

	function markIt(coords, checked) {
	    var canvas = document.getElementById("imgCanvas");
	    if (canvas.getContext) {
		var ctx = canvas.getContext("2d");

		var coordsArray = coords.split(",");
		var x = parseInt(coordsArray[0]);
		var y = parseInt(coordsArray[1]);

		var x1 = x+5;
		var x2 = x+10;
		var y1 = y;
		var y2 = y1-10;

		//alert("markIt x: "+x+"  y: "+y1+" ? "+checked);
		if (checked == true) {
		    ctx.fillStyle = "rgb(0,0,0)";
		    ctx.beginPath();
		    ctx.moveTo(x1, y1);
		    ctx.lineTo(x2, y2);
		    ctx.lineTo(x, y2);
		    ctx.closePath();
		    ctx.stroke();

		    //ctx.fillStyle = "rgba(0,255,0, 0.5)";
		    //ctx.fillRect(430, 218, 46, 17);

		    ctx.fillStyle = "rgb(0,255,255)";
		    ctx.beginPath();
		    ctx.moveTo(x1, y1);
		    ctx.lineTo(x2, y2);
		    ctx.lineTo(x, y2);
		    ctx.fill();
		} else {
		    ctx.clearRect(x-5, y1-15, 20, 20);
		}
	    }
	}
	</script>
    };

    # position just the image of the pathway in the layer underneath
    print "<div style='position: relative; z-index: 8'>";
    print "<image src='$tmpPngUrl' border='0' />\n";

    # add an overlay of same size as the image for the marker canvas
    print "<div style='display: block; left: 0px; top: 0px; "
	. "position: absolute; z-index:5'>";
    my ($w, $h) = $im->getBounds();
    print "<canvas id='imgCanvas' width='$w' height='$h' border='0'>"
	. "Your browser does not support canvas.</canvas>";

    # add an outermost transparent overlay containing the imagemap
    print "<div style='display: block; left: 0px; top: 0px; "
        . "position: absolute; z-index:5'>";
    my $im2 = new GD::Image($w, $h);
    my $white = $im2->colorAllocate( 255, 255, 255 );
    $im2->transparent( $white );
    $im2->interlaced('true');
    $im2->fill(0,0,$white);

    my $tmpPngFile2 = "$tmp_dir/overlay.$$.png";
    my $tmpPngUrl2  = "$tmp_url/overlay.$$.png";
    my $wfh2 = newWriteFileHandle( $tmpPngFile2, "showMapForSamples" );
    binmode $wfh2;
    print $wfh2 $im2->png;
    close $wfh2;

    print "<image src='$tmpPngUrl2' usemap='#mapdata' border='0' />\n";
    print "<map id='mapdata' name='mapdata'>\n";
    printMapCoordsForSamples
	( \@blueRecs,   $map_id, $sample_oid_str, $study, \%ko2genes );
    printMapCoordsForSamples
	( \@orangeRecs, $map_id, $sample_oid_str, $study );

    my $url_fragm = "&page=keggMapSamples"
	          . "&study=$study&samples=$sample_oid_str";
    if ($clusterFileName ne "") {
	$url_fragm .= "&file=$clusterFileName";
	if ($dataFileName ne "") {
	    $url_fragm .= "&dataFile=$dataFileName";
	}
    }
    printRelatedCoords( $dbh, $map_id, $url_fragm );
    print "</map>\n";

    print "</div>"; # top overlay: transparent imagemap
    print "</div>"; # middle overlay: markers
    print "</div>"; # lowest layer: image

    #$dbh->disconnect();
    printStatusLine( "Done.", 2 );
}

sub printJSForExpression {
    ######### for expression graph
    print "<script src='$base_url/imgCharts.js'></script>\n";
    print qq{
        <link rel="stylesheet" type="text/css"
          href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript"
          src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript"
          src="$YUI/build/container/container-min.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js"></script>
        <script src="$YUI/build/event/event-min.js"></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
    };

    print qq{
        <script language='JavaScript' type='text/javascript'>
	function initPanel() {
	    if (!YAHOO.example.container.panel1) {
                YAHOO.example.container.panel1 = new YAHOO.widget.Panel
                    ("panel1", {
                      visible:false,
                      //fixedcenter:true,
                      dragOnly:true,
                      underlay:"none",
                      zindex:"10",
                      context:['anchor1','bl','tr']
                      } );
                YAHOO.example.container.panel1.render();
                //alert("initPanel");
            }
	}
        </script>
    };

    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{
        <script type='text/javascript'>
	    YAHOO.namespace("example.container");
            YAHOO.util.Event.on("anchor1", "click", initPanel());
        </script>
        };
    print "</div>\n";
}

############################################################################
# printExpressionForGenes - displays a bar graph comparing expression for
#       selected genes (over multiple samples) - limit 5 genes
############################################################################
sub printExpressionForGenes {
    my $study = param("study");
    my $geneStr = param("genes");
    my @gene_oids = split(",", $geneStr);
    my $dataFileName = param("dataFile");

    my $header = "Expression for selected gene(s)";
    my $script = "$base_url/overlib.js";
    if (scalar @gene_oids < 1) {
        my $body = "Please select up to 5 genes.";

        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq {
            <response>
                <header>$header</header>
                <text>$body</text>
                <script>$script</script>
            </response>
        };
        return;
    }

    # read expression data for each gene and sample:
    my %gene2data;
    my @samples;
    my @datas;
    foreach my $gene (@gene_oids) {
	$gene2data{ $gene } = 1;
    }

    if ($dataFileName ne "") {
	my $dataFile = $tmp_dir."/".$dataFileName;
	my $rfh = newReadFileHandle( $dataFile, "loadData" );
	my $i = 0;
	while( my $s = $rfh->getline() ) {
	    chomp $s;
	    $i++;
	    if ($i == 1) {
		@samples = split( /\t/, $s );
		splice(@samples, 0, 4); # starts with the 4th element
	    }
	    next if $i < 4;

	    my( $idx, $gid, $name, $weightx, $valuesStr )
		= split( /\t/, $s, 5 );
	    next if (!exists($gene2data{ $gid }));
	    my @values = split( /\t/, $valuesStr );
	    $gene2data{ $gid } = join(",", @values);
	}
	close $rfh;
    }

    # get sample names:
    my $dbh = dbLogin();
    my %sampleNames;

    if ($study eq "rnaseq") {
	my $sample_oid_str = join(",", @samples);
	my $names_ref = RNAStudies::getNamesForSamples($dbh, $sample_oid_str);
	%sampleNames = %$names_ref;

    } elsif ($study eq "proteomics") {
	my $sample_oid_str = join(",", @samples);
	my $sql = qq{
            select distinct s.sample_oid, s.description
            from ms_sample s
            where s.sample_oid in ($sample_oid_str)
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
            my( $sid, $sname ) = $cur->fetchrow();
            last if !$sid;
            $sampleNames{ $sid } = $sname;
        }
        $cur->finish();
    }
    #$dbh->disconnect();

    my @test = values %sampleNames;
    my $a = scalar @test;

    my $idx = 0;
    my @snames;
    my %valid_genes;
    foreach my $s (@samples) {
	my $dataStr;
	foreach my $g (@gene_oids) {
	    my $valuesStr = $gene2data{ $g };
	    my @values = split(",", $valuesStr);
	    next if scalar @values != scalar @samples;
	    $valid_genes{$g} = 1;
	    $dataStr .= @values[$idx];
	    $dataStr .= ",";
	}
	chop $dataStr;
	push @datas, $dataStr;
	push @snames, $s." ".$sampleNames{ $s };
	$idx++;
    }

    my @valid_genes = keys %valid_genes;
    if (scalar @valid_genes < 1) {
        my $body = "Please select up to 5 genes that have Cluster ID.";

        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq {
            <response>
                <header>$header</header>
                <text>$body</text>
                <script>$script</script>
            </response>
        };
        return;
    }

    my $n = scalar @samples;
    my $m = scalar @valid_genes;

    my $chartW = 200;
    $chartW = $chartW + $n*30 + $m*5;
    my $chartH = 400;
    $chartH = $chartH + $n*10;
    $chartH = 400 if ($n > 30); # no legend then

    # PREPARE THE BAR CHART
    my $chart = ChartUtil::newBarChart();
    $chart->WIDTH($chartW);
    $chart->HEIGHT($chartH);
    $chart->DOMAIN_AXIS_LABEL("Gene ID");
    $chart->RANGE_AXIS_LABEL("Expression");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("yes");
    $chart->INCLUDE_URLS("no");
    # $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->SERIES_NAME(\@snames);
    $chart->CATEGORY_NAME(\@valid_genes);
    $chart->DATA(\@datas);

    if ($n > 30) {
	$chart->INCLUDE_LEGEND("no");
    }

    if ($env->{ chart_exe } ne "") {
        my $st = -1;
        $st = ChartUtil::generateChart($chart);
        if ($st == 0) {
            my $url = "$tmp_url/".$chart->FILE_PREFIX.".png";
            my $imagemap = "#".$chart->FILE_PREFIX;
            my $width = $chart->WIDTH;
            my $height = $chart->HEIGHT;
	    #my $header = "Expression";
            #my $script = "$base_url/overlib.js";

            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq {
                <response>
                <header>$header</header>
		<script>$script</script>
		<maptext><![CDATA[
	    };
	    my $FH = newReadFileHandle
	        ($chart->FILEPATH_PREFIX.".html", "gene_expr", 1);
	    while (my $s = $FH->getline()) {
		print $s;
	    }
	    close ($FH);

	    print qq {
		]]></maptext>
                <url>$url</url>
		<imagemap>$imagemap</imagemap>
		<width>$width</width>
		<height>$height</height>
                </response>
            };
        }
    }
}

############################################################################
# showMapForOneSample - displays the map with coloring based on coverage
#       of the genes for the specified sample
############################################################################
sub showMapForOneSample {
    my ( $map_id, $sample_oid, $study ) = @_;
    if ( $map_id eq "" ) {
        webError("Please select a pathway to display.<br/>\n");
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select pathway_name, pathway_oid
        from kegg_pathway
        where image_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    my ( $pathway_name, $pathway_oid ) = $cur->fetchrow();
    $cur->finish();

    print "<h1>KEGG Map: $pathway_name</h1>";
    print "<p>";
    print "Coloring is based on abundance of genes for sample: $sample_oid";
    print "<br/>(red-high to green-low expression)";
    print "</p>";

    print "<image src='$base_url/images/colorstrip.80.png' "
	. "width='300' height='10' />\n";

    my $hintstr .=
	"<span style='border:.1em solid rgb(0, 200, 200); "
	. "background-color: rgb(175, 0, 0)'>&nbsp;&nbsp;&nbsp;</span> "
	. "light blue outline indicates that more than one gene maps to "
	. "this function.<br/>"
	. "For any given function, the coloring is based on the coverage "
	. "value for the highest expressing gene that maps to it.";
    printHint($hintstr);
    print "<br/>";

    printStartWorkingDiv();

    #$sample_oid =~ s/'//g;
    my $sample_oid2 = $sample_oid;
    $sample_oid2 =~ tr/'//d;

    my @genes;
    my @genes4sample;
    my @values;
    my ($taxon_oid, $in_file, $genome_type);
    my @recs = ();

    if ( $study eq "rnaseq" ) {
	my $txsql = qq{
            select dts.reference_taxon_oid, tx.in_file, tx.genome_type
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid = ?
            and dts.reference_taxon_oid = tx.taxon_oid
        };
	my $cur = execSql( $dbh, $txsql, $verbose, $sample_oid2 );
	($taxon_oid, $in_file, $genome_type) = $cur->fetchrow();
	$cur->finish();

	my ($total_gene_cnt, $total_read_cnt) =
	    MetaUtil::getCountsForRNASeqSample($sample_oid2, $taxon_oid);
	my %gene2info =
	    MetaUtil::getGenesForRNASeqSample($sample_oid2, $taxon_oid);
	@genes4sample = keys %gene2info;
	my %prodNames;

	if (scalar @genes4sample > 0) {
	    print "<p>Retrieving gene info for $taxon_oid  ...\n";

	    if ($genome_type eq "metagenome") {
		%prodNames = MetaUtil::getGeneProdNamesForTaxon
		    ($taxon_oid, "assembled");
	    } else {
		my $gene2prod = RNAStudies::getGeneProductNames
		    ($dbh, $taxon_oid, \@genes4sample);
		%prodNames = %$gene2prod;
	    }

	    foreach my $gene ( keys %gene2info ) {
		my $line = $gene2info{ $gene };
		# each line is in tab-delimited format:
		# gene_oid locus_type locus_tag strand scaffold_oid
		# length reads_cnt mean median stdev reads_cnta meana
		# mediana stdeva exp_id sample_oid
		my ($geneid, $locus_type, $locus_tag, $strand,
		    $scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
		    = split("\t", $line);
		next if $reads_cnt == 0;

		my $product = $prodNames{ $gene };
		my $coverage = "0";
		if ($dna_seq_length > 0 && $total_read_cnt > 0) {
		    $coverage = ($reads_cnt/$dna_seq_length/$total_read_cnt);
		    $coverage = sprintf("%.3f", $coverage * 10**9);
		}
		if ($coverage > 0.0000000) {
		    push @genes, $gene;
		    push @values, $coverage;
		}
	    }

	} else {
	    print "Retrieving information from database ... <br/>\n";
	    my $sql2 = qq{
	        select sum(es.reads_cnt)
	        from rnaseq_expression es
	        where es.dataset_oid = ?
	    };
	    my $cur = execSql( $dbh, $sql2, $verbose, $sample_oid2 );
	    my ($total) = $cur->fetchrow();
	    $cur->finish();

	    if ($total eq "") {
		printEndWorkingDiv();
		webError("Could not compute abundances for sample $sample_oid.");
	    }
	    my $sql = qq{
	        select distinct es.IMG_gene_oid,
		round(es.reads_cnt/g.DNA_seq_length/$total, 12)
                from rnaseq_expression es, gene g
                where es.dataset_oid = ?
                and es.reads_cnt > 0.0000000
                and g.gene_oid = es.IMG_gene_oid
	    };
	    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid2 );
	    for ( ;; ) {
		my ( $gid, $coverage ) = $cur->fetchrow();
		last if !$gid;

		if ($study eq "rnaseq") {
		    $coverage = $coverage * 10**9;
		}
		if ($coverage eq "0") {
		    next;
		}

		push @genes, $gid;
		push @values, $coverage;
	    }
	    $cur->finish();
	}

	if ($in_file eq "Yes") {
	    print "<p>Retrieving pathway info for $taxon_oid from MER-FS ...";
	    my %ko_rois;
	    my %ko_names;
	    $sql = qq{
                select distinct ir.shape, ir.x_coord, ir.y_coord,
                       ir.coord_string, ir.width, ir.height, ir.roi_label,
                       ko.ko_id, ko.ko_name, ko.definition
                from image_roi ir, image_roi_ko_terms rk, ko_term ko
                where ir.pathway = ?
                and ir.roi_id = rk.roi_id
                and ir.roi_type in ('ko_term', 'enzyme')
                and rk.ko_terms = ko.ko_id
            };
	    $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
	    for ( ;; ) {
		my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
		     $roi_label, $ko_id, $ko_name, $ko_defn )
		    = $cur->fetchrow();
		last if !$roi_label;

		$ko_rois{ $ko_id } =
		    "$shape\t$x_coord\t$y_coord\t$coord_str\t" .
		    "$width\t$height\t$roi_label";
		$ko_names{ $ko_id } = "$ko_name\t$ko_defn";
	    }
	    $cur->finish();

	    my %all_kos =
		MetaUtil::getTaxonFuncCount($taxon_oid, 'assembled', 'ko');
	    foreach my $ko_id (keys %ko_names) {
		print "<p>Retrieving info for KO: $ko_id  ...\n";
		next if (!$all_kos{$ko_id});

		my %ko_genes = MetaUtil::getTaxonFuncGenes
		    ($taxon_oid, "assembled", $ko_id);
		my @gene_group = keys %ko_genes;
		next if (scalar @gene_group == 0);

		foreach my $gene ( @gene_group ) {
		    next if (!exists $gene2info{ $gene });
		    my $line = $gene2info{ $gene };
		    my ($geneid, $locus_type, $locus_tag, $strand,
			$scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
			= split("\t", $line);
		    next if ($reads_cnt <= 0.0000000);

		    my $product = $prodNames{ $gene };
		    if ($ko_rois{ $ko_id } && $ko_names{ $ko_id }) {
			my $s = $ko_rois{ $ko_id } . "\t" .
                                "$gene\t$product\t$locus_tag\t$ko_id\t" .
                                $ko_names{ $ko_id };
			push @recs, ( $s );
		    }
		}
	    }
	}

    } elsif ($study eq "proteomics") {
	# get the coverage values for each gene in the sample
	my $sql = qq{
            select distinct
                   dt.gene_oid, round(sum(dt.coverage), 7)
            from dt_img_gene_prot_pep_sample dt, gene g
	    where dt.sample_oid = ?
	    and dt.gene_oid = g.gene_oid
	    group by dt.gene_oid
        };

	my $cur = execSql( $dbh, $sql, $verbose, $sample_oid2 );
	for ( ;; ) {
	    my ( $gid, $coverage ) = $cur->fetchrow();
	    last if !$gid;

	    if ($coverage eq "0") {
		next;
	    }

	    push @genes, $gid;
	    push @values, $coverage;
	}
	$cur->finish();
    }

    my $tvalues = logTransform(\@values);
    my $cvalues = center($tvalues);
    my $nvalues_ref = normalize($cvalues);
    my @nvalues = @$nvalues_ref;

    my $idx = 0;
    my %profile;
    foreach my $gene (@genes) {
	$profile{ $gene } = $nvalues[$idx];
	$idx++;
    }

    my $sql = qq{
        select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
               ir.width, ir.height, ir.roi_label,
               g.gene_oid, g.gene_display_name, g.locus_tag,
               kt.ko_id, kt.ko_name, kt.definition
          from image_roi_ko_terms irk,
               image_roi ir,
               ko_term kt,
               gene_ko_terms gkt,
               gene g,
               dt_img_gene_prot_pep_sample dt
         where ir.roi_id= irk.roi_id
           and ir.roi_type in ('ko_term', 'enzyme')
           and irk.ko_terms = gkt.ko_terms
           and gkt.gene_oid = dt.gene_oid
           and dt.gene_oid = g.gene_oid
           and dt.sample_oid = ?
           and ir.pathway = ?
           and gkt.ko_terms = kt.ko_id
      order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
    };

    if ( $study eq "rnaseq" ) {
        $sql = qq{
            select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                   ir.width, ir.height, ir.roi_label,
	           g.gene_oid, g.gene_display_name, g.locus_tag,
                   kt.ko_id, kt.ko_name, kt.definition
              from image_roi_ko_terms irk,
                   image_roi ir,
                   ko_term kt,
                   gene_ko_terms gkt,
		   gene g,
                   rnaseq_expression es
             where ir.roi_id= irk.roi_id
               and ir.roi_type in ('ko_term', 'enzyme')
               and irk.ko_terms = gkt.ko_terms
               and gkt.gene_oid = es.IMG_gene_oid
	       and g.gene_oid = es.IMG_gene_oid
               and es.dataset_oid = ?
               and ir.pathway = ?
               and gkt.ko_terms = kt.ko_id
          order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
        };

	if (scalar @genes4sample > 0 && $in_file ne "Yes") {
	    my $idsInClause =
		OracleUtil::getNumberIdsInClause($dbh, @genes4sample);
	    my $gidsClause = " and g.gene_oid in ($idsInClause) ";

	    $sql = qq{
            select distinct ir.shape, ir.x_coord, ir.y_coord, ir.coord_string,
                   ir.width, ir.height, ir.roi_label,
                   g.gene_oid, g.gene_display_name, g.locus_tag,
                   kt.ko_id, kt.ko_name, kt.definition
              from image_roi_ko_terms irk,
                   image_roi ir,
                   ko_term kt,
                   gene_ko_terms gkt,
                   gene g
             where ir.roi_id = irk.roi_id
               and ir.roi_type in ('ko_term', 'enzyme')
               and irk.ko_terms = gkt.ko_terms
               and gkt.gene_oid = g.gene_oid
               $gidsClause
               and ir.pathway = ?
               and gkt.ko_terms = kt.ko_id
          order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
            };
	}
    }

    if ($in_file eq "Yes") {
	# already computed
    } else {
        print "<p>Retrieving pathway info for $taxon_oid  ...\n";
        my $cur;
        if (scalar @genes4sample > 0) {
	    $cur = execSql($dbh, $sql, $verbose, $pathway_oid);
        } else {
	    $cur = execSql($dbh, $sql, $verbose, $sample_oid2, $pathway_oid);
        }
	for ( ;; ) {
	    my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
		 $roi_label, $gene_oid, $name, $locus,
		 $ko_id, $ko_name, $ko_defn ) = $cur->fetchrow();
	    last if !$roi_label;
	    my $s = "$shape\t$x_coord\t$y_coord\t$coord_str\t" .
		    "$width\t$height\t" .
		    "$roi_label\t$gene_oid\t$name\t$locus\t" .
		    "$ko_id\t$ko_name\t$ko_defn";
	    push @recs, ( $s );
	}
	$cur->finish();
	OracleUtil::truncTable($dbh, "gtt_num_id");
    }

    my %unique_ko;
    my $old_roi;
    my %roi2gene;
    my $koStr;
    my @allRecs;

    foreach my $s ( sort @recs ) {
	my ( $shape, $x_coord, $y_coord, $coord_str, $width, $height,
	     $roi_label, $gene_oid, $name, $locus, $ko_id, $ko_name, $ko_defn )
	    = split( /\t/, $s );

	next if $shape eq "line";
        if ($shape eq "poly") {
            # anna: strip the coord_str to get only the coords:
            my $begin = index($coord_str, "(");
            my $end = index((reverse $coord_str), ")");
            $coord_str = substr($coord_str, $begin+1, -($end+1));
            $width = -1;
            $height = $coord_str;
        }
        #if ($shape eq "line") {
        #    $width = 10;
        #    $height = 10;
        #    $shape = "rect";
        #}
	my $r = "$x_coord\t";
	$r .= "$y_coord\t";
	$r .= "$width\t";
	$r .= "$height\t";
	$r .= "$shape";

        next if ($width <= 0 || $height <= 0) && $shape eq "rect";
        next if ($height <= 0); # can't display this roi

	my $ko = "$roi_label";
	my $koLabel = "$roi_label, $ko_name";
	$koLabel .= ", $ko_defn" if $ko_defn ne "";

	$roi2gene{$r} .= "$gene_oid\t$name\t$locus"."#";

	if ( $old_roi eq "" ) {
	    $old_roi = $r;
	}
	if ( $old_roi eq $r ) {
	    $unique_ko{$ko} = $koLabel;
	} else {
	    my $koStr = join(",", sort(keys(%unique_ko)));
	    my $koLabelStr = join("; ", sort(values(%unique_ko)));

	    %unique_ko = ();
	    $old_roi .= "\t$koStr" . "\t$koLabelStr";
	    push( @allRecs, $old_roi );
	    $unique_ko{$ko} = $koLabel;
	}
	$old_roi = $r;
    }

    my $koStr = join(",", keys(%unique_ko));
    my $koLabelStr = join("; ", values(%unique_ko));
    $old_roi .= "\t$koStr" . "\t$koLabelStr";
    push( @allRecs, $old_roi );

    printEndWorkingDiv();

    my $inFile = "$pngDir/$map_id.png";
    GD::Image->trueColor(1);
    my $im = new GD::Image($inFile);
    if ( !$im ) {
        webDie("showMapForOneSample: cannot read '$inFile'\n");
    }
    colorByAbundance( $im, \%roi2gene, \%profile );

    my $tmpPngFile = "$tmp_dir/$map_id.$$.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.$$.png";
    my $wfh = newWriteFileHandle( $tmpPngFile, "showMapForOneSample" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";
    print "<map name='mapdata'>\n";
    printMapCoordsForOneSample
	( \@allRecs, $map_id, \%roi2gene, $sample_oid, $study );

    my $url_fragm = "&page=keggMapSamples"
	          . "&study=$study&samples=$sample_oid";
    printRelatedCoords( $dbh, $map_id, $url_fragm );
    print "</map>\n";

    #$dbh->disconnect();
    printStatusLine( "Done.", 2 );
}

############################################################################
# applyHighlights - overlays the highlight coloring on the pathway map
############################################################################
sub applyHighlights {
    my ( $im, $recs_ref, $colorName ) = @_;
    if (!$recs_ref || $recs_ref eq "") {
	return;
    }
    foreach my $r (@$recs_ref) {
        my ( $x, $y, $w, $h, $shape, @ignore ) = split( /\t/, $r );

        next if $roiDone{"$x,$y"} ne "";
	next if ($w <= 0 || $h <= 0) && $shape eq "rect";

        my $coord_str;
        my $poly;

        if ($shape eq "rect") {
	    highlightRect( $im, $x, $y, $w, $h, $colorName );
            my $black = $im->colorClosest( 0, 0, 0 );
	    $im->rectangle( $x, $y, $x+$w, $y+$h, $black );
	} elsif ($shape eq "poly") {
            $coord_str = $h;
            my $poly = new GD::Polygon;
            my @pts = split(",", $coord_str);
            for (my $i=0; $i<(scalar @pts); $i=$i+2) {
                $poly->addPt(@pts[$i],@pts[1+$i]);
            }
            # draw a slightly larger poly
            my $side = 0;
            my @segLengths = $poly->segLength();
            my @vertices = $poly->vertices();
            for (my $i=0; $i<scalar @vertices; $i++) {
                $side = @segLengths[$i] > $side;
            }
            if (scalar @vertices == 3) {
                $poly->scale(1.5, 1.5, $poly->centroid());
            }

	    my $color = $im->colorClosest( 204, 204, 255 );
            $im->filledPolygon($poly, $color);

            my $black = $im->colorClosest( 0, 0, 0 );
            $im->polygon($poly, $black);
        }

        $roiDone{"$x,$y"} = 1;
    }
}

############################################################################
# applyHighlightsRGB - overlays the highlight coloring on the pathway map
############################################################################
sub applyHighlightsRGB {
    my ( $im, $recs_ref, $r, $g, $b, $perc, $colorName ) = @_;
    foreach my $rec (@$recs_ref) {
        my ( $x, $y, $w, $h, $shape, $koStr, @ignore ) = split( /\t/, $rec );

        next if $roiDone{"$x,$y"} ne "";
	next if ($w <= 0 || $h <= 0) && $shape eq "rect";

	my $coord_str;
	my $poly;

	if ($shape eq "rect") {
	    highlightRectRgb( $im, $x, $y, $w, $h, $r, $g, $b, $perc );
            my $black = $im->colorClosest( 0, 0, 0 );
	    $im->rectangle( $x, $y, $x+$w, $y+$h, $black );
	} elsif ($shape eq "poly") {
	    $coord_str = $h;
	    $poly = new GD::Polygon;
	    my @pts = split(",", $coord_str);
	    for (my $i=0; $i<(scalar @pts); $i=$i+2) {
		$poly->addPt(@pts[$i],@pts[1+$i]);
	    }
	    # draw a slightly larger poly
	    my $side = 0;
	    my @segLengths = $poly->segLength();
	    my @vertices = $poly->vertices();
	    for (my $i=0; $i<scalar @vertices; $i++) {
		$side = @segLengths[$i] > $side;
	    }
	    if (scalar @vertices == 3) {
		$poly->scale(1.5, 1.5, $poly->centroid());
	    }

	    my $color;
	    if ($colorName ne "") {
		$color = KeggMap::getColor($im, $colorName);
	    } else {
		$color = $im->colorClosest( $r, $g, $b );
	    }
	    $im->filledPolygon($poly, $color);

            my $black = $im->colorClosest( 0, 0, 0 );
	    $im->polygon($poly, $black);
        }

	my @kos = split(",", $koStr);
        if (scalar @kos > 1) { # show these outlined in red
	    my $red = $im->colorExact( 255, 0, 0 );
	    $red = $im->colorAllocate( 255, 0, 0 ) if $red < 0;

	    if ($shape eq "poly") {
		$im->polygon($poly, $red);
	    } else {
		$im->rectangle( $x, $y, $x+$w, $y+$h, $red );
	    }
	}

        $roiDone{"$x,$y"} = 1;
    }
}

############################################################################
# colorByCluster - overlays cluster-based coloring on the map
############################################################################
sub colorByCluster {
    my ( $im, $roi2ko_ref, $ko2genes_ref, $color_hash_ref ) = @_;
    if (!$roi2ko_ref || !$ko2genes_ref || $color_hash_ref eq "") {
        return;
    }

    my @rois = keys(%$roi2ko_ref);
    foreach my $roi (@rois) {
        my ( $x, $y, $w, $h, $shape ) = split( /\t/, $roi );
        next if ($w <= 0 || $h <= 0) && $shape eq "rect";

        my $coord_str;
        my $poly;

        my $koStr = $roi2ko_ref->{$roi};
        chop $koStr;

	my @kos = split("#", $koStr);
	my %allGenes;
	foreach my $ko (@kos) {
	    my $geneStr = $ko2genes_ref->{$ko};
	    my @genes = split("#", $geneStr);
	    foreach my $gene (@genes) {
		$allGenes{ $gene } = 1;
	    }
	}

        my $color0;
	my $n = 0;
        foreach my $gene (keys %allGenes) {
            my ( $gene_oid, $name, $locus, $clusterid )
		= split( /\t/, $gene );
            my $color = $color_hash_ref->{ $clusterid };
	    if ($color ne $color0) {
		$n++;
		$color0 = $color;
	    }
	}

	my ( $r, $g, $b ) = $im->rgb( $color0 );

        if ($shape eq "rect") {
	    my $perc = 80;
            highlightRectRgb( $im, $x, $y, $w, $h, $r, $g, $b, $perc );
            my $black = $im->colorClosest( 0, 0, 0 );
            $im->rectangle( $x, $y, $x+$w, $y+$h, $black );
        } elsif ($shape eq "poly") {
            $coord_str = $h;
            $poly = new GD::Polygon;
            my @pts = split(",", $coord_str);
            for (my $i=0; $i<(scalar @pts); $i=$i+2) {
                $poly->addPt(@pts[$i],@pts[1+$i]);
            }
            # draw a slightly larger poly
            my $side = 0;
            my @segLengths = $poly->segLength();
            my @vertices = $poly->vertices();
            for (my $i=0; $i<scalar @vertices; $i++) {
                $side = @segLengths[$i] > $side;
            }
            if (scalar @vertices == 3) {
                $poly->scale(1.8, 1.8, $poly->centroid());
            }

            my $color;
            $color = $im->colorClosest( $r, $g, $b );
            $im->filledPolygon($poly, $color);

            my $black = $im->colorClosest( 0, 0, 0 );
            $im->polygon($poly, $black);
        }

	if ($n > 1) { # show these in red
	    $color0 = $im->colorClosest( 190, 190, 190 );
	    my $red = $im->colorClosest( 255, 0, 0 );
	    if ( $red == -1 ) {
		$red = $im->colorAllocate( 255, 0, 0 );
	    }
            if ($shape eq "poly") {
                $im->polygon( $poly, $red );
            } else {
                $im->rectangle( $x, $y, $x+$w, $y+$h, $red );
            }
	}
    }
}

############################################################################
# colorByAbundance - overlays the abundance based coloring on the map
############################################################################
sub colorByAbundance {
    my ( $im, $roi2gene_ref, $profile_ref ) = @_;
    if (!$roi2gene_ref || $profile_ref eq "") {
        return;
    }

    my @rois = keys(%$roi2gene_ref);
    foreach my $roi (@rois) {
        my ( $x, $y, $w, $h, $shape ) = split( /\t/, $roi );
        next if ($w <= 0 || $h <= 0) && $shape eq "rect";

        my $coord_str;
        my $poly;

	my $genesStr = $roi2gene_ref->{$roi};
	chop $genesStr;

	my @genes = split("#", $genesStr);
	my $max;
	foreach my $gene (@genes) {
	    my ( $gene_oid, $name, $locus ) = split( /\t/, $gene );
	    my $val = $profile_ref->{$gene_oid};
	    if ($max eq "") {
		$max = $val;
	    }
	    if ($val > $max) {
		$max = $val;
	    }
	}

	my $val = 10*$max;
	my $ff0;
	if ( $val < 0.00 ) {
	    $ff0 = -1 * $val;
	} else {
	    $ff0 = $val;
	}
	if ($ff0 > 1.0000000) { # should not really happen ...
	    $ff0 = 1.0;
	}

	my ($r, $g, $b);
	if ($val < 0.00) {
	    $r = 0;
	    $g = int(205*$ff0 + 50);
	    $b = 0;
	} else {
	    $r = int(205*$ff0 + 50);
	    $g = 0;
	    $b = 0;
	}

        if ($shape eq "rect") {
	    my $perc = 80;
            highlightRectRgb( $im, $x, $y, $w, $h, $r, $g, $b, $perc );
            my $black = $im->colorClosest( 0, 0, 0 );
            $im->rectangle( $x, $y, $x+$w, $y+$h, $black );
        } elsif ($shape eq "poly") {
            $coord_str = $h;
            $poly = new GD::Polygon;
            my @pts = split(",", $coord_str);
            for (my $i=0; $i<(scalar @pts); $i=$i+2) {
                $poly->addPt(@pts[$i],@pts[1+$i]);
            }
            # draw a slightly larger poly
            my $side = 0;
            my @segLengths = $poly->segLength();
            my @vertices = $poly->vertices();
            for (my $i=0; $i<scalar @vertices; $i++) {
                $side = @segLengths[$i] > $side;
            }
            if (scalar @vertices == 3) {
                $poly->scale(1.8, 1.8, $poly->centroid());
            }

            my $color;
            $color = $im->colorClosest( $r, $g, $b );
            $im->filledPolygon($poly, $color);

            my $black = $im->colorClosest( 0, 0, 0 );
            $im->polygon($poly, $black);
        }

        if (scalar @genes > 1) { # show these in red
            my $blue = $im->colorClosest( 0, 200, 200 );
            if ( $blue == -1 ) {
                $blue = $im->colorAllocate( 0, 200, 200 );
            }
            if ($shape eq "poly") {
                $im->polygon( $poly, $blue );
            } else {
		$im->rectangle( $x, $y, $x+$w, $y+$h, $blue );
	    }
        }
    }
}

############################################################################
# printImageMapCoords - overlays the image map for the pathway map
############################################################################
sub printImageMapCoords {
    my ( $recs_ref, $map_id, $taxon_oid_str ) = @_;

    #print "<script src='$base_url/overlib.js'></script>\n";
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $koStr, $koLabelStr ) =
	    split( /\t/, $r );

        my $url = "$section_cgi&page=mapGenesKo&taxons=$taxon_oid_str";
        $url .= "&map_id=$map_id&ko=$koStr";

	my $text = $koLabelStr;
        my $width;
        if (length($text) > 400) {
            $width = "WIDTH,'400',";
        }

	#my $s = "onMouseOver=\"return overlib"
	#      . "('$text', $width FGCOLOR, '#E0FFC2')\" ";
	#$s .= "onMouseOut=\"return nd()\" ";
	#print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
	#. $s . ">\n";

	if ($shape eq "rect") {
	    my $x2  = $x1 + $w;
	    my $y2  = $y1 + $h;

	    print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
		. " target='_blank' title='$koLabelStr' " . ">\n";
	} elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' title='$koLabelStr' " . ">\n";
	}
    }
}

############################################################################
# printMapCoordsForSamples - overlays the image map for the pathway map
############################################################################
sub printMapCoordsForSamples {
    my ( $recs_ref, $map_id, $sample_oid_str, $study, $ko2genes_ref ) = @_;

    print "<script src='$base_url/overlib.js'></script>\n";
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $koStr, $koLabelStr ) =
	    split( /\t/, $r );

	my $text;
	if ( $ko2genes_ref ne "" && $ko2genes_ref && $study eq "rnaseq"
	     && scalar %$ko2genes_ref > 0 ) {
	    my @kos = split(",", $koStr);
	    my %allGenes;
	    foreach my $ko (@kos) {
		my $geneStr = $ko2genes_ref->{$ko};
		my @genes = split("#", $geneStr);
		foreach my $gene (@genes) {
		    $allGenes{ $gene } = 1;
		}
	    }
	    my %clusterHash;
	    foreach my $gene (keys %allGenes) {
		my ( $gene_oid, $name, $locus, $clusterid )
		    = split( /\t/, $gene );
		$clusterHash{ $clusterid } = 1; # if $clusterid ne "";
	    }
	    my @clusters = keys %clusterHash;
	    my $clusterStr = join(", ", @clusters);
	    $text = "[Cluster(s): $clusterStr] ";
        } else {
	    $text = "";
        }

        my $url = "$section_cgi&page=mapGenesSamples"
	        . "&study=$study&samples=$sample_oid_str"
	        . "&map_id=$map_id&ko=$koStr";

        $text .= "$koLabelStr";
	$text =~ s/'//g;

	my $width;
	if (length($text) > 400) {
	    $width = "WIDTH,'400',";
	}

	my $s = "onMouseOver=\"return overlib"
	    . "('$text', $width FGCOLOR, '#E0FFC2')\" "
	    . "onMouseOut=\"return nd()\" ";

	if ($shape eq "rect") {
	    my $x2  = $x1 + $w;
	    my $y2  = $y1 + $h;

	    print "<area id='$koStr' name='$koStr' "
		. "shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
		. "target='_blank' "
		. $s . ">\n";
	} elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' id='$koStr' name='$koStr' " . $s . ">\n";
	}
    }
}

############################################################################
# printMapCoordsForFuncs - overlays the image map for the pathway map
############################################################################
sub printMapCoordsForFuncs {
    my ( $recs_ref, $map_id, $func_str ) = @_;

    print "<script src='$base_url/overlib.js'></script>\n";
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $koStr, $koLabelStr ) =
	    split( /\t/, $r );

	my $roi = $x1."\t".$y1."\t".$w."\t".$h."\t".$shape;
        my $str = "$koLabelStr";
        $str =~ s/'//g;

        my $width;
        if (length($str) > 400) {
            $width = "WIDTH,'400',";
        }

        my $s = "onMouseOver=\"return overlib"
	      . "('$str', $width FGCOLOR, '#E0FFC2')\" "
	      . "onMouseOut=\"return nd()\" ";

        if ($shape eq "rect") {
	    my $x2  = $x1 + $w;
	    my $y2  = $y1 + $h;
	    print "<area shape='rect' coords='$x1,$y1,$x2,$y2' " . $s . ">\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' " . $s . ">\n";
        }
    }
}

############################################################################
# printMapCoordsForOneSample - overlays the image map for the pathway map
############################################################################
sub printMapCoordsForOneSample {
    my ( $recs_ref, $map_id, $roi2gene_ref, $sample_oid, $study ) = @_;

    print "<script src='$base_url/overlib.js'></script>\n";
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $koStr, $koLabelStr ) =
	    split( /\t/, $r );

	my $roi = $x1."\t".$y1."\t".$w."\t".$h."\t".$shape;
        my $genesStr = $roi2gene_ref->{$roi};
        chop $genesStr;

        my @genes = split("#", $genesStr);
        my $count = scalar @genes;
	#my $locusStr;
        #foreach my $gene (@genes) {
        #    my ( $gene_oid, $name, $locus ) = split( /\t/, $gene );
	#    $locusStr .= $locus.",";
	#}
	#chop $locusStr;

        my $url = "$section_cgi&page=mapGenesOneSample"
  	        . "&study=$study&sample=$sample_oid"
		. "&map_id=$map_id&ko=$koStr";

	my $str = $count . " genes, ";
	if ($count == 1) {
	    $str = $count . " gene, ";
	}
	$str .= "$koLabelStr";
	$str =~ s/'//g;

	my $width;
	if (length($str) > 400) {
	    $width = "WIDTH,'400',";
	}

        my $s = "onMouseOver=\"return overlib"
              . "('$str', $width FGCOLOR, '#E0FFC2')\" "
	      . "onMouseOut=\"return nd()\" ";

        if ($shape eq "rect") {
	    my $x2  = $x1 + $w;
	    my $y2  = $y1 + $h;
	    print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
		. "target='_blank' "
		. $s . ">\n";
        #print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
        #    . " title='$str'"
        #    . " >\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' id='$koStr' name='$koStr' " . $s . ">\n";
        }
    }
}

############################################################################
# printMapGenesKo - prints the genes with the given ko number for
#           selected genomes
############################################################################
sub printMapGenesKo {
    my $map_id = param("map_id");
    my $ko_str = param("ko");
    my $taxon_oid_str = param("taxons");

    print "<h1>Genes with KO: <font color='darkblue'><u>$ko_str</u></font>"
	. " found among selected genomes</h1>\n";
    my $dbh = dbLogin();

    $ko_str =~ s/KO://g;
    my @ko = split(",", $ko_str);
    my $ko_str2;
    if (OracleUtil::useTempTable($#ko + 1)) {
        OracleUtil::insertDataArray($dbh, "gtt_func_id", \@ko);
        $ko_str2 = "select id from gtt_func_id";
    } else {
        $ko_str2 = joinSqlQuoted(",", @ko);
        $ko_str2 =~ s/KO://g;
    }

    my @toids = split(",", $taxon_oid_str);
    my $taxon_oid_str2;
    if (OracleUtil::useTempTable($#toids + 1)) {
        OracleUtil::insertDataArray($dbh, "gtt_num_id", \@toids);
        $taxon_oid_str2 = "select id from gtt_num_id";
    } else {
        $taxon_oid_str2 = $taxon_oid_str;
    }

    printMainForm();

    printStartWorkingDiv();
    print "<p>Retrieving genome information from database ... \n";

    my %mer_fs_taxons;
    if ( $include_metagenomes ) {
	my $imgClause = WebUtil::imgClause("tx");
	my $rclause = WebUtil::urClause("tx.taxon_oid");
	my $sql = qq{
            select tx.taxon_oid, tx.taxon_display_name
            from taxon tx
            where tx.in_file = 'Yes'
            and tx.taxon_oid in ($taxon_oid_str2)
            $rclause
            $imgClause
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	for ( ;; ) {
	    my ($t_oid, $t_name) = $cur->fetchrow();
	    last if !$t_oid;
	    $mer_fs_taxons{$t_oid} = $t_name;
	}
	$cur->finish();
    }

    print "<br/>Retrieving pathway information from database ... \n";
    my $sql = qq{
	select distinct g.gene_oid, g.gene_display_name, g.locus_tag,
	       g.taxon, tx.taxon_name, iroi.roi_label
        from image_roi_ko_terms irk, gene_ko_terms gk, gene g, taxon tx,
	     image_roi iroi, kegg_pathway pw
        where pw.image_id = ?
	and irk.roi_id = iroi.roi_id
	and irk.ko_terms = gk.ko_terms
	and gk.gene_oid = g.gene_oid
	and iroi.pathway = pw.pathway_oid
	and g.taxon = tx.taxon_oid
	and tx.taxon_oid in ($taxon_oid_str2)
	and iroi.roi_label in ($ko_str2)
	and g.obsolete_flag = 'No'
	order by iroi.roi_label, g.gene_oid, g.taxon
    };

    my $cur = execSql( $dbh, $sql, $verbose, $map_id );

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome", "asc", "left" );
    $it->addColSpec( "KO", "asc", "left" );
    my $sd = $it->getSdDelim();

    my %txHash;
    my $gene_cnt = 0;
    my $trunc = 0;
    for ( ;; ) {
        my ( $gene_oid, $name, $locus_tag, $taxon_oid, $taxon_name, $ko )
	    = $cur->fetchrow();
        last if !$gene_oid;
	$name = "hypothetical protein" if $name eq "";

        my $url1 = "$main_cgi?section=GeneDetail"
                 . "&page=geneDetail&gene_oid=$gene_oid";
        my $url2 = "$main_cgi?section=TaxonDetail"
                 . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $url3 = "$ko_base_url$ko";

	my $row = $sd."<input type='checkbox' "
	        . "name='gene_oid' value='$gene_oid'/>\t";
	$row .= $gene_oid.$sd.alink($url1, $gene_oid, "_blank")."\t";
	$row .= $locus_tag.$sd.$locus_tag."\t";
	$row .= $name.$sd.$name."\t";
	$row .= $taxon_name.$sd.alink($url2, $taxon_name, "_blank")."\t";
        $row .= $ko.$sd.alink($url3, $ko, "_blank")."\t";
        $it->addRow($row);

	$gene_cnt++;
	$txHash{ $taxon_oid } = 0;
	if ( $gene_cnt >= $maxGeneListResults ) {
	    $trunc = 1;
	    last;
	}
    }

    OracleUtil::truncTable($dbh, "gtt_func_id"); # clean up temp table
    OracleUtil::truncTable($dbh, "gtt_num_id");  # clean up temp table
    $cur->finish();
    #$dbh->disconnect();

    my $mer_fs_genes = 0;
    my $skip_gene_name = 0;
    if ( !$trunc && scalar(keys %mer_fs_taxons) > 0 ) {
	for my $taxon_oid (keys %mer_fs_taxons) {
	    if ( $trunc ) {
		last;
	    }

	    my $taxon_name = $mer_fs_taxons{$taxon_oid};
	    print "<br/>Retrieving genes for $taxon_name ... <br/>\n";
	    for my $ko_id ( @ko ) {
		if ( $trunc ) {
		    last;
		}
		my %genes = MetaUtil::getTaxonFuncGenes
		    ($taxon_oid, "", "KO:" . $ko_id);
		if ( scalar(keys %genes) > 100 ) {
		    $skip_gene_name = 1;
		}
		if ( scalar(keys %genes) > 0 ) {
		    $txHash{ $taxon_oid } = 0;
		}
		for my $gene_oid (keys %genes) {
		    my $workspace_id = $genes{$gene_oid};
		    my ($tid2, $data_type, $gid2) = split(/ /, $workspace_id);
		    my $locus_tag = $gene_oid;
		    my $name = "";
		    if ( ! $skip_gene_name ) {
			my ($value, $source) = MetaUtil::getGeneProdNameSource
			    ($gene_oid, $taxon_oid, $data_type);
			$name = $value;
		    }
		    my $url1 = "$main_cgi?section=MetaGeneDetail" .
			"&page=metaGeneDetail&taxon_oid=$taxon_oid" .
			"&data_type=$data_type&gene_oid=$gene_oid";
		    my $url2 = "$main_cgi?section=MetaDetail"
			. "&page=metaDetail&taxon_oid=$taxon_oid";
		    my $url3 = "$ko_base_url$ko_id";

		    my $row = $sd."<input type='checkbox' "
			. "name='gene_oid' value='$workspace_id'/>\t";
		    $row .= $gene_oid.$sd
			  . alink($url1, $gene_oid, "_blank")."\t";
		    $row .= $locus_tag.$sd.$locus_tag."\t";
		    $row .= $name.$sd.$name."\t";
		    $row .= $taxon_name.$sd
			  . alink($url2, $taxon_name, "_blank")."\t";
		    $row .= $ko_id . $sd . alink($url3, $ko_id, "_blank")."\t";
		    $it->addRow($row);
		    $mer_fs_genes = 1;

		    $gene_cnt++;
		    if ( $gene_cnt >= $maxGeneListResults ) {
			$trunc = 1;
			last;
		    }
		}
	    }
	}
    }

    printEndWorkingDiv();

    my $msg = '';
    if ($skip_gene_name) {
        $msg .= " Some MER-FS gene names are not displayed."
	      . " Use 'Expand Gene Table Display' option to view"
              . " detailed gene information.";
        printHint($msg);
    }

    printGeneCartFooter() if ($gene_cnt > 10);
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ($skip_gene_name) {
        printHint($msg);
    }

    ## save to workspace
    if ( $gene_cnt > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
    	WorkspaceUtil::printSaveGeneToWorkspace("gene_oid");
    }

    my $genomes = keys %txHash;
    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
            . alink( $preferences_url, "Preferences" )
            . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_cnt gene(s) and $genomes genome(s) retrieved",
			 2 );
    }

    print end_form();
}

############################################################################
# printMapGenesSamples - prints the genes with the given ko number for
#           selected samples
############################################################################
sub printMapGenesSamples {
    my $map_id = param("map_id");
    my $ko_str = param("ko");
    my $study = param("study");
    my $sample_oid_str = param("samples");
    my @sample_oids = split(",", $sample_oid_str);
#ANNA: need to add cluster id column

    print "<h1>Genes with KO: <font color='blue'><u>$ko_str</u></font>"
        . " found among selected samples</h1>\n";

    my @ko = split(",", $ko_str);
    $ko_str = joinSqlQuoted(",", @ko);
    $ko_str =~ s/KO://g;

    my $dbh = dbLogin();

    my %sampleNames;
    my %sample2taxon;
    my %taxons;
    my %genes4sample;
    my %sample2geneInfo;

    if ( $study eq "rnaseq" ) {
	my $names_ref = RNAStudies::getNamesForSamples($dbh, $sample_oid_str);
	%sampleNames = %$names_ref;

	# get info about the genomes for selected samples:
        my $datasetClause = RNAStudies::datasetClause("dts");
	my $txsql = qq{
            select distinct dts.dataset_oid, dts.reference_taxon_oid,
                   tx.in_file, tx.genome_type
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = tx.taxon_oid
            $datasetClause
        };
	my $cur = execSql( $dbh, $txsql, $verbose );
        for ( ;; ) {
            my( $sid, $tx, $in, $gt ) = $cur->fetchrow();
            last if !$sid;
            $sample2taxon{ $sid } = $tx;
            $taxons{ $tx } = $in . "," . $gt;

            # get the genes from SDB:
            my %gene2info = MetaUtil::getGenesForRNASeqSample($sid, $tx);
            my @genes = keys %gene2info;
            if (scalar @genes < 1) {
                # get genes for this sample from Oracle database:
                my $dtClause = RNAStudies::datasetClause("es");
                my $sql2 = qq{
                    select distinct g.gene_oid,
                    g.gene_display_name, g.locus_tag
                    from rnaseq_expression es, gene g
                    where es.dataset_oid = ?
                    and es.reads_cnt > 0.0000000
                    and es.IMG_gene_oid = g.gene_oid
                    $dtClause
                };
                my $cur = execSql( $dbh, $sql2, $verbose, $sid );
                for ( ;; ) {
                    my ( $gid, $name, $locus_tag ) = $cur->fetchrow();
		    last if !$gid;
                    push @genes, $gid;
                    $gene2info{ $gid } = $gid."\t".$name."\t".$locus_tag;
                }
            }
            $genes4sample{ $sid } = @genes;
            $sample2geneInfo{ $tx.$sid } = \%gene2info;
        }
	$cur->finish();

    } elsif ($study eq "proteomics") {
	my $txsql = qq{
            select s.sample_oid, s.IMG_taxon_oid, tx.in_file, tx.genome_type
            from ms_sample s, taxon tx
            where s.sample_oid in ($sample_oid_str)
            and s.IMG_taxon_oid = tx.taxon_oid
        };
        my $cur = execSql( $dbh, $txsql, $verbose );
        for ( ;; ) {
            my( $sid, $tx, $in, $gt ) = $cur->fetchrow();
            last if !$sid;
            $sample2taxon{ $sid } = $tx;
	    $taxons{ $tx } = $in . "," . $gt;
	}
        $cur->finish();

        my $sql2 = qq{
            select distinct s.sample_oid, s.description
            from ms_sample s
            where s.sample_oid in ($sample_oid_str)
        };
        my $cur = execSql( $dbh, $sql2, $verbose );
        for( ;; ) {
            my( $sid, $sname ) = $cur->fetchrow();
            last if !$sid;
            $sampleNames{ $sid } = $sname;
        }
	$cur->finish();
    }

    my @recs = ();
    if ($study eq "rnaseq") {
	foreach my $k (@ko) {
	    my $kid = "KO:".$k;

	    TX: foreach my $tx (keys %taxons) {
	        my ($infile, $gt) = split(",", $taxons{ $tx });

		my @gene_group;
		my %prodNames;
		if ($gt eq "metagenome") {
		    %prodNames = MetaUtil::getGeneProdNamesForTaxon
			($tx, "assembled");
		}
		if ($infile eq "Yes") {
		    my %ko_genes = MetaUtil::getTaxonFuncGenes
			($tx, "assembled", $kid);
		    @gene_group = keys %ko_genes;

		} else {
		    my $rclause   = WebUtil::urClause('g.taxon');
		    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
		    my $sql       = qq{
                       select distinct g.gene_oid
                       from gene g, gene_ko_terms gkt
                       where gkt.taxon = ?
                       and gkt.ko_terms = ?
                       and g.gene_oid = gkt.gene_oid
                       and g.locus_type = 'CDS'
                       and g.obsolete_flag = 'No'
                       $rclause
                       $imgClause
                    };
		    my $cur2 = execSql( $dbh, $sql, $verbose, $tx, $kid );
		    for ( ;; ) {
			my ($kgid) = $cur2->fetchrow();
			last if !$kgid;
			push @gene_group, $kgid;
		    }
		}

	        SAMPLE: foreach my $sid (@sample_oids) {
		    my $g2is_ref = $sample2geneInfo{ $tx.$sid };
		    foreach my $gene_oid (@gene_group) {
			next if (!exists $g2is_ref->{ $gene_oid });

			my $product = $prodNames{ $gene_oid };
			my $line = $g2is_ref->{ $gene_oid };
			my ($geneid, $gn, $locus_tag, @rest)
			    = split("\t", $line);
			$product = $gn if !$product || $product eq "";
			my $name = $sampleNames{ $sid };
			my $r = "$gene_oid\t$product\t$locus_tag\t"
			    . "$sid\t$name\t$k\ttx";
			push @recs, ($r);
		    }
		}
	    }
	}

    } elsif ($study eq "proteomics") {
	my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name, g.locus_tag,
	       dt.sample_oid, dt.sample_desc, iroi.roi_label, g.taxon
        from image_roi_ko_terms irk, gene_ko_terms gk, gene g,
             image_roi iroi, kegg_pathway pw,
	     dt_img_gene_prot_pep_sample dt
        where pw.image_id = ?
        and irk.roi_id = iroi.roi_id
        and irk.ko_terms = gk.ko_terms
        and gk.gene_oid = g.gene_oid
        and iroi.pathway = pw.pathway_oid
        and dt.sample_oid in ($sample_oid_str)
        and dt.gene_oid = g.gene_oid
        and iroi.roi_label in ($ko_str)
        and g.obsolete_flag = 'No'
	order by iroi.roi_label, g.gene_oid, dt.sample_oid
        };

	my $cur = execSql( $dbh, $sql, $verbose, $map_id );
	for ( ;; ) {
	    my ( $gene_oid, $name, $locus_tag, $sample_oid, $sample_name,
		 $ko, $tx ) = $cur->fetchrow();
	    last if !$gene_oid;
	    my $sample_name = $sampleNames{$sample_oid} if $study eq "rnaseq";
	    my $r = "$gene_oid\t$name\t$locus_tag\t"
		  . "$sample_oid\t$sample_name\t$ko\ttx";
	    push @recs, ($r);
	}
	$cur->finish();
    }

    printMainForm();

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",            "asc", "right" );
    $it->addColSpec( "Locus Tag",          "asc", "left"  );
    $it->addColSpec( "Gene Product Name",  "asc", "left"  );
    $it->addColSpec( "Sample ID",          "asc", "right" );
    $it->addColSpec( "Sample Description", "asc", "left"  );
    $it->addColSpec( "KO",                 "asc", "left"  );

    my $cnt = 0;
    foreach my $r ( @recs ) {
        my ($gene_oid, $name, $locus_tag, $sample_oid, $sample_name, $ko, $tx)
	    = split( /\t/, $r );
 	$name = "hypothetical protein" if $name eq "";

        my $url1 = "$main_cgi?section=GeneDetail"
                 . "&page=geneDetail&gene_oid=$gene_oid";
	my ($in_file, $gt) = split(",", $taxons{ $tx });
	if ($in_file eq "Yes") {
	    $url1 = "$main_cgi?section=MetaGeneDetail"
		  . "&page=metaGeneDetail&gene_oid=$gene_oid"
		  . "&data_type=assembled&taxon_oid=$tx";
	}
        my $url2 = "$main_cgi?section=IMGProteins"
                 . "&page=sampledata&sample=$sample_oid";
	if ( $study eq "rnaseq" ) {
	    $url2 = "$main_cgi?section=RNAStudies"
		  . "&page=sampledata&sample=$sample_oid";
	}
	my $url3 = "$ko_base_url$ko";

        my $row = $sd."<input type='checkbox' "
                . "name='gene_oid' value='$gene_oid'/>\t";
        $row .= $gene_oid.$sd.alink($url1, $gene_oid, "_blank")."\t";
	$row .= $locus_tag.$sd.$locus_tag."\t";
        $row .= $name.$sd.$name."\t";
        $row .= $sample_oid.$sd.$sample_oid."\t";
        $row .= $sample_name.$sd.alink($url2, $sample_name, "_blank")."\t";
        $row .= $ko.$sd.alink($url3, $ko, "_blank")."\t";
        $it->addRow($row);
	$cnt++;
    }

    printGeneCartFooter();
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
    #$dbh->disconnect();
    printStatusLine("$cnt items for $ko_str", 2);
}

############################################################################
# printMapGenesOneSample - prints the genes with the given ko number for
#           the one selected sample
############################################################################
sub printMapGenesOneSample {
    my $map_id = param("map_id");
    my $ko_str = param("ko");
    my $study = param("study");
    my $sample_oid = param("sample");

    my $dbh = dbLogin();
    my $sql = qq{
        select s.description, s.IMG_taxon_oid, tx.in_file, tx.genome_type
        from ms_sample s, taxon tx
        where s.sample_oid = ?
        and s.IMG_taxon_oid = tx.taxon_oid
    };
    if ( $study eq "rnaseq" ) {
        $sql = qq{
            select dts.dataset_oid, dts.reference_taxon_oid,
                   tx.in_file, tx.genome_type
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid = ?
            and dts.reference_taxon_oid = tx.taxon_oid
        };
    }

    my $sample_oid2 = $sample_oid;
    $sample_oid2 =~ tr/'//d;

    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid2 );
    my ($sample_desc, $taxon_oid, $in_file, $genome_type) = $cur->fetchrow();
    $cur->finish();

    $sample_desc = RNAStudies::getNameForSample($dbh, $sample_oid)
	if $study eq "rnaseq";

    print "<h1>Genes with KO: <font color='blue'>$ko_str</font>"
        . " for sample</h1>\n";

    my $url = "$main_cgi?section=IMGProteins"
	    . "&page=sampledata&sample=$sample_oid";
    if ( $study eq "rnaseq" ) {
	$url = "$main_cgi?section=RNAStudies"
	     . "&page=sampledata&sample=$sample_oid";
    }
    print "<p>".alink($url, $sample_desc, "_blank", 0, 1)."</p>\n";

    my @ko = split(",", $ko_str);
    $ko_str = joinSqlQuoted(",", @ko);
    $ko_str =~ s/KO://g;

    my @kkos;
    foreach my $ko (@ko) {
	push @kkos, "KO:".$ko;
    }
    my $kko_str = joinSqlQuoted(",", @kkos);

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name,
               g.locus_tag, gk.ko_terms,
               round(sum(dt.coverage), 7)
        from gene g, gene_ko_terms gk,
             dt_img_gene_prot_pep_sample dt
        where dt.gene_oid = gk.gene_oid
        and gk.gene_oid = g.gene_oid
        and gk.ko_terms in ($kko_str)
        and dt.sample_oid = ?
        and g.obsolete_flag = 'No'
        group by g.gene_oid, g.gene_display_name, g.locus_tag, gk.ko_terms
        order by g.gene_oid, g.gene_display_name, g.locus_tag, gk.ko_terms
    };

    my @recs = ();
    if ($study eq "rnaseq") {
	my ($total_gene_cnt, $total_read_cnt) =
	    MetaUtil::getCountsForRNASeqSample($sample_oid2, $taxon_oid);
    	my %gene2info =
	    MetaUtil::getGenesForRNASeqSample($sample_oid2, $taxon_oid);
    	my @genes = keys %gene2info;

	if (scalar @genes < 1) {
	    # get genes for this sample from Oracle database:
	    my $dtClause = RNAStudies::datasetClause("es");
            my $sql2 = qq{
                select sum(es.reads_cnt)
                from rnaseq_expression es
                where es.dataset_oid = ?
                $dtClause
            };
            my $cur = execSql( $dbh, $sql2, $verbose, $sample_oid2 );
            my ($total) = $cur->fetchrow();
            $cur->finish();

	    my $sql = qq{
                select distinct g.gene_oid,
                g.gene_display_name, g.locus_tag,
                round(es.reads_cnt/g.DNA_seq_length/$total, 12)
                from rnaseq_expression es, gene g
                where es.dataset_oid = ?
                and es.reads_cnt > 0.0000000
                and es.IMG_gene_oid = g.gene_oid
                and g.obsolete_flag = 'No'
                $dtClause
            };
	    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid2 );
	    for ( ;; ) {
		my ( $gid, $name, $locus_tag, $covg ) = $cur->fetchrow();
		last if !$gid;
		push @genes, $gid;
		$gene2info{ $gid } = $gid."\t".$name."\t".$locus_tag.
		                     "\t"."\t"."\t".$covg;
	    }
	}

        my %prodNames;
        if ($genome_type eq "metagenome") {
            %prodNames =
                MetaUtil::getGeneProdNamesForTaxon($taxon_oid, "assembled");
        } else {
            my $gene2prod = RNAStudies::getGeneProductNames
		($dbh, $taxon_oid, \@genes);
            %prodNames = %$gene2prod;
        }

        my %all_kos;
    	if ($in_file eq "Yes") {
    	    %all_kos = MetaUtil::getTaxonFuncCount
		($taxon_oid, 'assembled', 'ko');
    	} else {
    	    my $sql = qq{
                select distinct gkt.ko_terms
                from gene_ko_terms gkt
                where gkt.taxon = ?
            };
    	    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    	    for ( ;; ) {
    		my ($koid) = $cur->fetchrow();
    		last if !$koid;
    		$all_kos{ $koid } = 1;
    	    }
    	}

        foreach my $ko_id (@ko) { # the selected ko
	    my $kid = "KO:".$ko_id;
            next if (!$all_kos{$kid});

	    my @gene_group;
	    if ($in_file eq "Yes") {
		my %ko_genes = MetaUtil::getTaxonFuncGenes
		    ($taxon_oid, "assembled", $kid);
		@gene_group = keys %ko_genes;

	    } else {
		my $rclause   = WebUtil::urClause('g.taxon');
		my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
		my $sql       = qq{
                    select distinct g.gene_oid
                    from gene g, gene_ko_terms gkt
                    where gkt.taxon = ?
                    and gkt.ko_terms = ?
                    and g.gene_oid = gkt.gene_oid
                    and g.locus_type = 'CDS'
                    and g.obsolete_flag = 'No'
                    $rclause
                    $imgClause
                };
		my $cur2 = execSql( $dbh, $sql, $verbose, $taxon_oid, $kid );
		for ( ;; ) {
		    my ($kgid) = $cur2->fetchrow();
		    last if !$kgid;
		    push @gene_group, $kgid;
		}
	    }
	    #next if (scalar @gene_group == 0);

	    foreach my $gene ( @gene_group ) {
		next if (!exists $gene2info{ $gene });

		my $line = $gene2info{ $gene };
		my ($geneid, $locus_type, $locus_tag, $strand,
		    $scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
		    = split("\t", $line);
		next if $reads_cnt == 0;

		my $product = $prodNames{ $gene };
		my $coverage = "0";
		if ($dna_seq_length > 0 && $total_read_cnt > 0) {
		    $coverage = ($reads_cnt/$dna_seq_length/$total_read_cnt);
		} else {
		    $coverage = $reads_cnt;
		}
		if ($coverage > 0.0000000) {
		    my $s = "$gene\t$product\t$locus_tag\t$ko_id\t$coverage";
		    push @recs, ( $s );
		}
	    }
	}

    } else {
	my $cur = execSql( $dbh, $sql, $verbose, $sample_oid2 );
	for ( ;; ) {
	    my ( $gene_oid, $name, $locus_tag, $ko, $coverage )
		= $cur->fetchrow();
	    last if !$gene_oid;
	    $ko =~ s/KO://g;

	    my $s = "$gene_oid\t$name\t$locus_tag\t$ko\t$coverage";
	    push @recs, ( $s );
	}
	$cur->finish();
    }

    printMainForm();

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    if ($study eq "rnaseq") {
        $it->addColSpec( "Normalized Coverage<sup>1</sup><br/>"
                       . " * 10<sup>9</sup>", "desc", "right" );
    } else {
        $it->addColSpec( "Coverage<sup>1</sup>", "desc", "right" );
    }
    $it->addColSpec( "KO", "asc", "left" );
    my $sd = $it->getSdDelim();

    foreach my $s ( sort @recs ) {
        my ( $gene_oid, $name, $locus_tag, $ko, $coverage )
            = split( /\t/, $s );
	$name = "hypothetical protein" if $name eq "";

        my $url1 = "$main_cgi?section=GeneDetail"
                 . "&page=geneDetail&gene_oid=$gene_oid";
	if ($in_file eq "Yes") {
	    $url1 = "$main_cgi?section=MetaGeneDetail"
		  . "&page=metaGeneDetail&gene_oid=$gene_oid"
		  . "&data_type=assembled&taxon_oid=$taxon_oid";
	}
        my $url3 = "$ko_base_url$ko";

        my $row = $sd."<input type='checkbox' "
            . "name='gene_oid' value='$gene_oid'/>\t";
        $row .= $gene_oid.$sd.alink($url1, $gene_oid, "_blank")."\t";
        $row .= $locus_tag.$sd.$locus_tag."\t";
        $row .= $name.$sd.$name."\t";

        if ($study eq "rnaseq") {
            $coverage = $coverage * 10**9;
	    $coverage = sprintf("%.3f", $coverage);
        } elsif ($study eq "proteomics") {
	    $coverage = sprintf("%.7f", $coverage);
        }
	$row .= $coverage.$sd.$coverage."\t";
        $row .= $ko.$sd.alink($url3, $ko, "_blank")."\t";
        $it->addRow($row);
    }

    printGeneCartFooter();
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
    #$dbh->disconnect();

    if ($study eq "proteomics") {
        IMGProteins::printNotes("samplegenes");
    } elsif ($study eq "rnaseq") {
        RNAStudies::printNotes("samplegenes");
    }
}

############################################################################
# makeColorStrip - draws a red-to-green color strip
############################################################################
sub makeColorStrip {
    my ($im2) = @_;
    my $white = $im2->colorAllocate( 255, 255, 255 );
    $im2->transparent( $white );
    $im2->interlaced( 'true' );

    my $im = new GD::Image(240, 10);
    my $cell_height = 10;
    my $cell_width = 10;
    my $idx = 0;
    my $r = 255; my $g = 0; my $b = 0;

    for ( my $i = 1; $i <= 12; $i++ ) {
	$r = 255 - 20*$i;
	$g = 0;
	$b = 0;
	my $color = $im->colorAllocate( $r, $g, $b );

	my $x1 = $idx * $cell_width;
	my $y1 = 0;
	my $x2 = $x1 + $cell_width;
	my $y2 = $cell_height;
	$im->filledRectangle( $x1, $y1, $x2, $y2, $color );
	$idx++;
    }
    for ( my $i = 1; $i <= 12; $i++ ) {
	$r = 0;
	$g = 0 + 21*$i;
	$b = 0;
	my $color = $im->colorAllocate( $r, $g, $b );

	my $x1 = $idx * $cell_width;
	my $y1 = 0;
	my $x2 = $x1 + $cell_width;
	my $y2 = $cell_height;
	$im->filledRectangle( $x1, $y1, $x2, $y2, $color );
	$idx++;
    }

    #$idx++;
    #my $x1 = $idx * $cell_width;
    #my $x2 = $x1 + $cell_width;
    #my $gray = $im->colorAllocate( 150, 150, 150 );
    #$im->filledRectangle( $x1, 0, $x2, $cell_height, $gray );

    $im2->copyMerge( $im, 0,0,0,0, 240, 10, 80);
    #$im->colorDeallocate();
}

# replace all values x by log base 2 of (x)
sub logTransform {
    my ($values) = @_;
    my @tvalues;
    foreach my $v (@$values) {
	my $t = log($v)/log(2);
	push @tvalues, $t;
    }
    return \@tvalues;
}

# center values by subtracting the mean
sub center {
    my ($values) = @_;

    my $cnt = scalar @$values;
    my $sum = 0;
    foreach my $v (@$values) {
        $sum += $v;
    }
    my $mean = $sum/$cnt;
    my @cvalues;
    foreach my $v (@$values) {
	my $c = $v - $mean;
	push @cvalues, $c;
    }
    return \@cvalues;
}

# normalize: multiply all values by a scale factor S so that
# the sum of the squares of the values in each row is 1.0
sub normalize {
    my ($values) = @_;

    my $sum = 0;
    foreach my $v (@$values) {
	$sum += $v*$v;
    }
    my $sval = sqrt(1/$sum);

    my @nvalues;
    foreach my $v (@$values) {
	my $n = $sval * $v;
	push @nvalues, sprintf("%.3f", $n);
    }
    return \@nvalues;
}

# normalize all values to 0-100 range
sub normalizeTo {
    my ($values) = @_;

    my $high = @$values[0];
    my $low = @$values[0];
    foreach my $v (@$values) {
        if ($v > $high) {
            $high = $v;
        }
        if ($v < $low) {
            $low = $v;
        }
    }

    print "<br/>Low: $low High: $high";
    my @nvalues;
    foreach my $v (@$values) {
        my $n = ($v-$low)*100/($high-$low);
        push @nvalues, sprintf("%.3f", $n);
    }
    return \@nvalues;
}

# normalize all values to -1 to 1 range
sub normalizeTo2 {
    my ($values) = @_;

    my $high = @$values[0];
    my $low = @$values[0];
    foreach my $v (@$values) {
	if ($v > $high) {
	    $high = $v;
	}
	if ($v < $low) {
	    $low = $v;
	}
    }

    print "<br/>Low: $low High: $high";
    my @nvalues;
    foreach my $v (@$values) {
        my $n = (($v-$low)*2/($high-$low)) - 1;
        push @nvalues, sprintf("%.3f", $n);
    }
    return \@nvalues;
}


1;
