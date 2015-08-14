###########################################################################
# Display kegg map and do appropriate highlighting.
# --es  11/03/2004
# $Id: KeggMap.pm 33981 2015-08-13 01:12:00Z aireland $
###########################################################################
package KeggMap;
my $section = "KeggMap";

use strict;
use CGI qw( :standard );
use DBI;
use GD;
use Data::Dumper;
use WebConfig;
use WebUtil;
use DataEntryUtil;
use InnerTable;
use HtmlUtil;
use MetaUtil;
use WorkspaceUtil;

my $env            = getEnv();
my $main_cgi       = $env->{main_cgi};
my $section_cgi    = "$main_cgi?section=$section";
my $base_url       = $env->{base_url};
my $img_lite       = $env->{img_lite};
my $use_gene_priam = $env->{use_gene_priam};
my $verbose        = $env->{verbose};
my $kegg_data_dir  = $env->{kegg_data_dir};
if ( $kegg_data_dir eq "" ) {
    $kegg_data_dir = $env->{web_data_dir} . "/kegg.maps";
}

my $user_restricted_site  = $env->{user_restricted_site};
my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $ko_base_url      = $env->{kegg_orthology_url};
my $ec_base_url      = $env->{enzyme_base_url};
my $pngDir           = "$kegg_data_dir";
my $max_gene_batch   = 100;
my $tmp_dir          = $env->{tmp_dir};
my $tmp_url          = $env->{tmp_url};
my $show_myimg_login = $env->{show_myimg_login};
my %roiDone;

# see GeneDetails::printKeggPathways()
my %badmaps = ('map01100' => 1);

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    my $map_id   = param("map_id");
    timeout( 60 * 20 );    # timeout in 20 mins (from main.pl)
    if ( exists $badmaps{$map_id}) {
        my $str = qq{
            <a href='http://www.genome.jp/kegg/pathway/map/map01100.html'>
            Kegg Overview Map</a>
        };
        webError("Kegg mapp $map_id is an overview map"
	       . " and cannot be displayed!<br/> $str\n");
    }

    if ( $page eq "kpdViewKeggMapForOneGenome" ||
	 paramMatch("kpdViewKeggMapForOneGenome") ne "" ) {
        my $taxon_oid = param("taxon_oid");
        my $mapType   = param("mapType");
        if ( $taxon_oid eq "" ) {
            webError("Please select one genome.");
        }
        if ( $mapType eq "missingEnzymes" ) {
            printKeggMapMissingECByTaxonOid();
        } else {
            printKeggMapByTaxonOid();
        }
    } elsif ( $page eq "kpdAbundanceZscoreNote" ) {
        printZscoreNote();
    } elsif ( $page eq "keggMap" ) {
        printKeggMapByGeneOid();
    } elsif ( $page eq "keggMapRelated" ) {
        printKeggMapByTaxonOid();
    } elsif ( $page eq "keggMapTaxonGenes" ) {
        printKeggMapTaxonGenes();
    } elsif ( $page eq "keggMapTaxonGenesEc" ) {
        printKeggMapTaxonGenesEc();
    } elsif ( $page eq "keggMapTaxonGenesKo" ) {
        printKeggMapTaxonGenesKo();
    } elsif ( $page eq "myIMGKeggMapTaxonGenes" ) {
        printMyIMGKeggMapTaxonGenes();
    } elsif ( $page eq "keggMapEcEquiv" ) {
        printKeggMapEcEquivGenes();
    } elsif ( $page eq "keggMapKoEquiv" ) {
        printKeggMapKoEquivGenes();
    } else {
        webLog("KeggMap::dispatch: unknown page='$page'\n");
        warn("KeggMap::dispatch: unknown page='$page'\n");
    }
}

############################################################################
# printKeggMapByGeneOid - Print a KEGG map by gene_oid from the gene page.
############################################################################
sub printKeggMapByGeneOid {
    my $map_id    = param("map_id");
    my $gene_oid  = param("gene_oid");
    my $myimg     = param("myimg");
    my $taxon_oid = param('taxon_oid');
    my $data_type = param('data_type');

    my $dbh = dbLogin();

    my $taxon_in_fs = 0;
    if ( $taxon_oid && ( $data_type eq 'assembled'
		      || $data_type eq 'unassembled' ) ) {
	checkTaxonPerm( $dbh, $taxon_oid );
	$taxon_in_fs = 1;
    }
    elsif ( isInt($gene_oid) ) {
	checkGenePerm( $dbh, $gene_oid );
    }

    printStatusLine( "Loading ...", 1 );
    print "<h1>KEGG Map</h1>\n";

    my ($name, $locus, $taxon_name);

    if ( $taxon_in_fs ) {
	$locus = $gene_oid;
	my $sql = "select taxon_display_name from taxon where taxon_oid = ?";
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	($taxon_name) = $cur->fetchrow();
	$cur->finish();

	my $source = "";
	($name, $source) = MetaUtil::getGeneProdNameSource
	    ($gene_oid, $taxon_oid, $data_type);
    }
    else {
	my $sql = qq{
	    select distinct g.gene_display_name, g.locus_tag,
	           tx.taxon_oid, tx.taxon_display_name
            from gene g, taxon tx
	    where g.gene_oid = ?
	    and g.taxon = tx.taxon_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	($name, $locus, $taxon_oid, $taxon_name) = $cur->fetchrow();
	$cur->finish();
    }

    my $urlg = "$main_cgi?section=GeneDetail"
 	     . "&page=geneDetail&gene_oid=$gene_oid";
    my $urlt = "$main_cgi?section=TaxonDetail"
	     . "&page=taxonDetail&taxon_oid=$taxon_oid";

    if ( $taxon_in_fs ) {
	$urlg = "$main_cgi?section=MetaGeneDetail" .
	        "&page=metaGeneDetail&gene_oid=$gene_oid" .
	        "&taxon_oid=$taxon_oid&data_type=$data_type";
	$urlt = "$main_cgi?section=MetaDetail" .
	        "&page=metaDetail&taxon_oid=$taxon_oid";
    }

    print "<p>Current Genome: ".alink($urlt, $taxon_name);
    print "<br/>Current Gene: "
	. alink( $urlg, "$gene_oid [$locus]")."</p>";

    printMainForm();
    printStartWorkingDiv();

    ## Current gene (red)
    my @redRecs;
    my %redRoiIds;
    if ( $taxon_in_fs ) {
	my @kos = MetaUtil::getGeneKoId($gene_oid, $taxon_oid, $data_type);

	if ( scalar(@kos) > 0 ) {
	    my $ko_list = "";
	    for my $ko_id ( @kos ) {
		if ( $ko_list ) {
		    $ko_list .= ", '" . $ko_id . "'";
		} else {
		    $ko_list = "'" . $ko_id . "'";
		}
	    }

	    my $sql = qq{
                select distinct iroi.roi_id, iroi.shape,
                       iroi.x_coord, iroi.y_coord, iroi.coord_string,
                       iroi.width, iroi.height
                from image_roi_ko_terms irk,
                     image_roi iroi, kegg_pathway pw
                where pw.image_id = '$map_id'
                and irk.roi_id = iroi.roi_id
                and iroi.roi_type in ('ko_term', 'enzyme')
                and irk.ko_terms in ( $ko_list )
                and iroi.pathway = pw.pathway_oid
            };
	    print "Getting current gene <br/>\n";
	    my $cur = execSql( $dbh, $sql, $verbose );

	    for ( ;; ) {
		my ( $roi_id, $shape, $x_coord, $y_coord, $coord_str,
		     $width, $height ) = $cur->fetchrow();
		last if !$roi_id;
		next if $shape eq "line";

		$redRoiIds{$roi_id} = 1;

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
		$r .= "$shape\t";
		$r .= "$taxon_oid $data_type $gene_oid";

		push( @redRecs, $r );
	    }
	    $cur->finish();
	}

    } else {
	my $sql = qq{
            select distinct g.gene_oid, iroi.shape,
                   iroi.x_coord, iroi.y_coord, iroi.coord_string,
                   iroi.width, iroi.height
            from image_roi_ko_terms irk, gene_ko_terms gk,
                 image_roi iroi, kegg_pathway pw, gene g
            where pw.image_id = ?
            and irk.roi_id = iroi.roi_id
            and iroi.roi_type in ('ko_term', 'enzyme')
            and irk.ko_terms = gk.ko_terms
            and gk.gene_oid = g.gene_oid
            and iroi.pathway = pw.pathway_oid
            and g.gene_oid = ?
            and g.taxon = ?
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
        };
	print "Getting current gene <br/>\n";
	my $cur = execSql( $dbh, $sql, $verbose,
			   $map_id, $gene_oid, $taxon_oid );

	for ( ;; ) {
	    my ( $gene, $shape, $x_coord, $y_coord, $coord_str,
		 $width, $height ) = $cur->fetchrow();
	    last if !$gene;

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
	    $r .= "$shape\t";
	    $r .= "$gene";

	    push( @redRecs, $r );
	}
	$cur->finish();
    }

    ## Positional cluster genes (green)
    my @greenRecs;
    if ( $taxon_in_fs ) {
	# FS
    } else {
	# DB
	my $sql = qq{
         select distinct g.gene_oid, iroi.shape,
                iroi.x_coord, iroi.y_coord, iroi.coord_string,
                iroi.width, iroi.height
           from image_roi_ko_terms irk, gene_ko_terms gk, gene g,
	        image_roi iroi, kegg_pathway pw,
                positional_cluster_genes pcg1,
	        positional_cluster_genes pcg2
           where pw.image_id = ?
           and irk.roi_id = iroi.roi_id
           and iroi.roi_type in ('ko_term', 'enzyme')
           and irk.ko_terms = gk.ko_terms
           and gk.gene_oid = g.gene_oid
           and iroi.pathway = pw.pathway_oid
           and g.taxon = ?
           and g.locus_type = 'CDS'
           and g.obsolete_flag = 'No'
           and pcg1.genes = ?
           and pcg1.group_oid = pcg2.group_oid
           and pcg2.genes != ?
           and pcg2.genes = gk.gene_oid
           order by iroi.x_coord, iroi.y_coord,
           iroi.width, iroi.height, g.gene_oid
           };
	print "Positional cluster genes <br/>\n";
	my $cur = execSql( $dbh, $sql, $verbose,
			   $map_id, $taxon_oid, $gene_oid, $gene_oid );

	my $old_roi;
	my %unique_genes;
	for ( ;; ) {
	    my ( $gene, $shape, $x_coord, $y_coord, $coord_str,
		 $width, $height ) = $cur->fetchrow();
	    last if !$gene;

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

	    if ( $old_roi eq "" ) {
		$old_roi = $r;
	    }
	    if ( $old_roi eq $r ) {
		$unique_genes{$gene} = 1;
	    } else {
		my $geneStr = join(",", sort(keys(%unique_genes)));
		%unique_genes = ();

		$old_roi .= "\t$geneStr";
		push( @greenRecs, $old_roi );
		$unique_genes{$gene} = 1;
	    }
	    $old_roi = $r;
	}
	my $geneStr = join(",", keys(%unique_genes));
	$old_roi .= "\t$geneStr";
	push( @greenRecs, $old_roi );
	$cur->finish();
    }

    ## Taxon genes (blue)
    my @blueRecs;
    if ( $taxon_in_fs ) {
	# FS
	my %all_ko = MetaUtil::getTaxonFuncCount($taxon_oid, 'both', 'ko');
	my $sql = qq{
               select distinct iroi.roi_id, irk.ko_terms,
                      kt.ko_name, kt.definition,
                      iroi.roi_label, iroi.shape,
                      iroi.x_coord, iroi.y_coord, iroi.coord_string,
                      iroi.width, iroi.height
               from image_roi_ko_terms irk, ko_term kt,
                    image_roi iroi, kegg_pathway pw
               where pw.image_id = ?
               and irk.roi_id = iroi.roi_id
               and iroi.roi_type in ('ko_term', 'enzyme')
               and iroi.pathway = pw.pathway_oid
               and irk.ko_terms = kt.ko_id
               order by 1, 2
               };
	print "Getting current gene <br/>\n";
	my $cur = execSql( $dbh, $sql, $verbose, $map_id );

	my $prev_roi_id = 0;
	my $prev_ko_id = "";
	my $ko_str = "";
	my $ko_label = "";
	my $r2 = "";
	for ( ;; ) {
	    my ( $roi_id, $ko_term, $ko_name, $ko_defn, $roi_label,
                 $shape, $x_coord, $y_coord, $coord_str, $width, $height )
		= $cur->fetchrow();
	    last if !$roi_id;

	    if ( ! $all_ko{$ko_term} ) {
		# don't have this KO
		next;
	    }

	    if ( $redRoiIds{$roi_id} ) {
		# already colored red
		next;
	    }

	    if ( $roi_id == $prev_roi_id ) {
		# same one
		if ( $ko_term eq $prev_ko_id ) {
		    # duplicate
		    next;
		}
		else {
		    if ( $ko_str ) {
			$ko_str .= ", " . $ko_term;
		    }
		    else {
			$ko_str = $ko_term;
		    }

		    my $label2 = "$roi_label, $ko_name";
		    $label2 .= ", $ko_defn" if $ko_defn ne "";

		    if ( $ko_label ) {
			$ko_label .= "; " . $label2;
		    }
		    else {
			$ko_label = $label2;
		    }

		    $prev_ko_id = $ko_term;
		}
	    }
	    else {
		# new one
		if ( $prev_roi_id ) {
		    my $r = $r2;
		    $r .= "$ko_str\t";
		    $r .= "$ko_label";
		    push( @blueRecs, $r );
		}

		$prev_roi_id = $roi_id;
		$prev_ko_id = $ko_term;
		$ko_str = $ko_term;
		my $label2 = "$roi_label, $ko_name";
		$label2 .= ", $ko_defn" if $ko_defn ne "";
		$ko_label = $label2;

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

		$r2 = "$x_coord\t";
		$r2 .= "$y_coord\t";
		$r2 .= "$width\t";
		$r2 .= "$height\t";
		$r2 .= "$shape\t";
	    }
	}
	$cur->finish();

	# last one
	if ( $prev_roi_id ) {
	    my $r = $r2;
	    $r .= "$ko_str\t";
	    $r .= "$ko_label";
	    push( @blueRecs, $r );
	}

    } else {
	# DB
	my $sql = qq{
           select distinct iroi.roi_label, iroi.shape,
                iroi.x_coord, iroi.y_coord, iroi.coord_string,
                iroi.width, iroi.height,
                kt.ko_name, kt.definition
           from image_roi_ko_terms irk, gene_ko_terms gk,
                image_roi iroi, kegg_pathway pw, gene g, ko_term kt
           where pw.image_id = ?
           and irk.roi_id = iroi.roi_id
           and iroi.roi_type in ('ko_term', 'enzyme')
	   and irk.ko_terms = gk.ko_terms
	   and gk.gene_oid = g.gene_oid
	   and iroi.pathway = pw.pathway_oid
	   and g.taxon = ?
	   and g.locus_type = 'CDS'
	   and g.obsolete_flag = 'No'
	   and gk.gene_oid != ?
	   and kt.ko_id = gk.ko_terms
	   order by iroi.x_coord, iroi.y_coord,
	   iroi.width, iroi.height, iroi.roi_label
        };
	print "Genomes genes <br/>\n";
	my $cur = execSql( $dbh, $sql, $verbose,
			   $map_id, $taxon_oid, $gene_oid );

	my $old_roi;
	my %unique_ko;
	for ( ;; ) {
	    my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
		 $width, $height, $ko_name, $ko_defn ) = $cur->fetchrow();
	    last if !$roi_label;

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
		my $koLabelStr = join("; \n", sort(values(%unique_ko)));

		%unique_ko = ();

		$old_roi .= "\t$koStr" . "\t$koLabelStr";
		push( @blueRecs, $old_roi );
		$unique_ko{$ko} = $koLabel;
	    }
	    $old_roi = $r;
	}

	my $koStr = join(",", keys(%unique_ko));
	my $koLabelStr = join(",", values(%unique_ko));

	$old_roi .= "\t$koStr" . "\t$koLabelStr";
	push( @blueRecs, $old_roi );
	$cur->finish();
    }

    ## MyIMG genes (cyan)
    my @cyanRecs;
    if ( $taxon_in_fs ) {
	# FS
    } else {
	# DB
	my $sql = qq{
            select distinct iroi.roi_label, iroi.shape,
                   iroi.x_coord, iroi.y_coord, iroi.coord_string,
                   iroi.width, iroi.height
            from image_roi_ko_terms irkt, ko_term_enzymes kte,
                 gene_myimg_enzymes gme, gene g,
                 image_roi iroi, kegg_pathway pw
            where pw.image_id = ?
            and iroi.roi_id = irkt.roi_id
            and iroi.roi_type in ('ko_term', 'enzyme')
            and irkt.ko_terms = kte.ko_id
            and kte.enzymes = gme.ec_number
            and gme.gene_oid = g.gene_oid
            and gme.modified_by = ?
            and iroi.pathway = pw.pathway_oid
            and g.taxon = ?
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            order by iroi.x_coord, iroi.y_coord,
            iroi.width, iroi.height, iroi.roi_label
        };

	my $old_roi;
	my %unique_ko;
	my $contact_oid = getContactOid();
	if ( $contact_oid > 0 && $show_myimg_login ) {
	    my $cur = execSql( $dbh, $sql, $verbose,
			       $map_id, $contact_oid, $taxon_oid );
	    for ( ;; ) {
		my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
		     $width, $height ) = $cur->fetchrow();
		last if !$roi_label;

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
		if ( $old_roi eq "" ) {
		    $old_roi = $r;
		}
		if ( $old_roi eq $r ) {
		    $unique_ko{$ko} = 1;
		} else {
		    my $koStr = join(",", sort(keys(%unique_ko)));
		    %unique_ko = ();

		    $old_roi .= "\t$koStr";
		    push( @cyanRecs, $old_roi );
		    $unique_ko{$ko} = 1;
		}
		$old_roi = $r;
	    }

	    my $koStr = join(",", keys(%unique_ko));
	    $old_roi .= "\t$koStr";
	    push( @cyanRecs, $old_roi );
	    $cur->finish();
	}
    }

    ## EC equivalogs (orange)
    my @orangeRecs;
    my $sql = qq{
           select distinct ir.roi_label, ir.shape,
                  ir.x_coord, ir.y_coord, ir.coord_string,
                  ir.width, ir.height,
                  dt.taxon, kt.ko_name, kt.definition
           from dt_gene_ko_module_pwys dt, ko_term kt,
                image_roi ir, image_roi_ko_terms irk
           where dt.taxon != ?
           and dt.image_id = ?
           and dt.pathway_oid = ir.pathway
           and ir.roi_id = irk.roi_id
           and ir.roi_type in ('ko_term', 'enzyme')
           and ir.roi_label = kt.ko_id
           order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
    };

    print "Getting all genomes <br/>\n";
    my %validTaxons = WebUtil::getAllTaxonsHashed($dbh);

    print "EC equivalogs <br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $map_id );

    my $old_roi;
    my %unique_tx;
    my %unique_ko;

    my $tmpcnt = 0;
    my $tmpcnt2 = 1;
    print "Getting data <br/>";
    for ( ;; ) {
	my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
	     $width, $height, $taxon, $ko_name, $ko_defn ) = $cur->fetchrow();
	last if !$roi_label;

	$tmpcnt++;
	if ($tmpcnt % 2000 == 0) {
	    print ". ";
	    $tmpcnt2++;
	    $tmpcnt = 0;
	}
	if($tmpcnt2 % 80 == 0) {
	    print "<br/>\n";
	    $tmpcnt2 = 1;
	}
	next if $validTaxons{$taxon} eq "";

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
	    $unique_tx{$taxon} = 1;
	} else {
	    my @keys = keys(%unique_tx);
	    my $count = @keys;
	    my $koStr = join(",", sort(keys(%unique_ko)));
	    my $koLabelStr = join("; \n", sort(values(%unique_ko)));

	    %unique_tx = ();
	    %unique_ko = ();

	    $old_roi .= "\t$count" . "\t$koStr" . "\t$koLabelStr";
	    push( @orangeRecs, $old_roi );

	    $unique_ko{$ko} = $koLabel;
	    $unique_tx{$taxon} = 1;
	}
	$old_roi = $r;
    }

    my @keys = keys(%unique_tx);
    my $count = @keys;
    my $koStr = join(",", keys(%unique_ko));
    my $koLabelStr = join(",", values(%unique_ko));

    $old_roi .= "\t$count" . "\t$koStr" . "\t$koLabelStr";
    push( @orangeRecs, $old_roi );
    $cur->finish();

    print "End of EC equivalogs query<br/>\n";
    printEndWorkingDiv();
    webLog("kegg map file $pngDir/$map_id.png \n");

    my $inFile = "$pngDir/$map_id.png";
    if ( !-e $inFile) {
        webDie("printKeggByGeneOid: cannot read '$inFile'\n");
    }
    my $im = new GD::Image($inFile);
    if ( !$im ) {
        webDie("printKeggByGeneOid: cannot read '$inFile'\n");
    }

    applyCoords( $im, \@redRecs,    "red" ) if !$myimg;
    applyCoords( $im, \@cyanRecs,   "cyan" );
    applyCoords( $im, \@greenRecs,  "green" );
    applyCoords( $im, \@blueRecs,   "blue" );
    applyCoords( $im, \@orangeRecs, "orange" );

    $gene_oid =~ /([0-9]+)/;
    $gene_oid = $1;
    my $tmpPngFile = "$tmp_dir/$map_id.g$gene_oid.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.g$gene_oid.png";

    my $wfh = newWriteFileHandle( $tmpPngFile, "printKeggByGeneOid" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    printGeneLegend( $taxon_name, $taxon_filter_oid_str, $myimg );

    print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";

    print "<map name='mapdata'>\n";
    if ( ! $taxon_in_fs && isInt($gene_oid) ) {
	printMyIMGMapCoords( \@cyanRecs, $map_id, $taxon_oid, $gene_oid );
    }
    printMapCoords( \@redRecs, $map_id, $taxon_oid, $gene_oid );

    if ( ! $taxon_in_fs && isInt($gene_oid) ) {
	printMapCoords( \@greenRecs, $map_id, $taxon_oid, $gene_oid );
    }

    if ( ! $taxon_in_fs && isInt($gene_oid) ) {
	printKoMapCoords( \@blueRecs, $map_id, $taxon_oid, $gene_oid );
    }
    else {
	printKoMapCoords( \@blueRecs, $map_id, $taxon_oid,
			  "$taxon_oid $data_type $locus" );
    }

    if ( ! $taxon_in_fs && isInt($gene_oid) ) {
	printKoEquivMapCoords( \@orangeRecs, $map_id, $taxon_oid, $gene_oid );
    }
    else {
	printKoEquivMapCoords( \@orangeRecs, $map_id, $taxon_oid, "" );
    }

    printRelatedCoords( $dbh, $map_id, $taxon_oid );
    print "</map>\n";

    printKeggPathwayDetailLink( $dbh, $map_id );
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
    print end_form();
}

############################################################################
# printKeggMapByTaxonOid - Print KEGG map by taxon_oid as related KEGG map.
############################################################################
sub printKeggMapByTaxonOid {
    my ($taxon)   = @_;
    my $map_id    = param("map_id");
    my $taxon_oid = param("taxon_oid");
    if ( $taxon ne "" ) {
        $taxon_oid = $taxon;
    }

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_oid, t.taxon_display_name, t.in_file " .
	"from taxon t where t.taxon_oid = ? " . $rclause;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $tid2, $taxon_name, $tx_in_file ) =
	$cur->fetchrow();
    $cur->finish();
    if ( ! $tid2 ) {
	#$dbh->disconnect();
	return;
    }

    my $taxon_in_fs = 0;
    if ( $tx_in_file eq 'Yes' ) {
	$taxon_in_fs = 1;
    }

    printMainForm();

    my $cluster_id = param('cluster_id');

    printStatusLine( "Loading ...", 1 );

    ## Cluster genes
    my %bc_gene_h;
    my %bc_ko_h;
    if ( $cluster_id ) {
	if ( $taxon_in_fs ) {
	    my $sql = "select feature_id from bio_cluster_features_new " .
		      "where cluster_id = ? and feature_type = 'gene'";
	    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
	    for ( ;; ) {
		my ($gene_id) = $cur->fetchrow();
		last if ! $gene_id;
		$bc_gene_h{$gene_id} = 1;

		my @kos = MetaUtil::getGeneKoId($gene_id, $taxon_oid, 'assembled');
		for my $ko ( @kos ) {
		    $bc_ko_h{$ko} = 1;
		}
	    }
	    $cur->finish();
	}
	else {
	    my $sql = "select bcf.gene_oid, gkt.ko_terms " .
		"from bio_cluster_features_new bcf, gene_ko_terms gkt " .
		"where bcf.cluster_id = ? and feature_type = 'gene' " .
		"and bcf.gene_oid = gkt.gene_oid (+) ";
	    my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
	    for ( ;; ) {
		my ($gene_id, $ko) = $cur->fetchrow();
		last if ! $gene_id;
		$bc_gene_h{$gene_id} = 1;
		if ( $ko ) {
		    $bc_ko_h{$ko} = 1;
		}
	    }
	    $cur->finish();
	}
    }

    ## Taxon genes (blue)
    my @blueRecs;
    my @bcRecs;
    if ( $taxon_in_fs ) {
	# FS
	my %all_ko = MetaUtil::getTaxonFuncCount($taxon_oid, 'both', 'ko');
	my $sql = qq{
            select distinct iroi.roi_id, irk.ko_terms,
                   kt.ko_name, kt.definition,
                   iroi.roi_label, iroi.shape,
                   iroi.x_coord, iroi.y_coord, iroi.coord_string,
                   iroi.width, iroi.height
            from image_roi_ko_terms irk, ko_term kt,
                 image_roi iroi, kegg_pathway pw
            where pw.image_id = ?
            and irk.roi_id = iroi.roi_id
            and iroi.roi_type in ('ko_term', 'enzyme')
            and iroi.pathway = pw.pathway_oid
            and irk.ko_terms = kt.ko_id
            order by 1, 2
        };
	my $cur = execSql( $dbh, $sql, $verbose, $map_id );

	my $prev_roi_id = 0;
	my $prev_ko_id = "";
	my $ko_str = "";
	my $ko_label = "";
	my $r2 = "";
	my $in_bc = 0;
	for ( ;; ) {
	    my ( $roi_id, $ko_term, $ko_name, $ko_defn, $roi_label,
                 $shape, $x_coord, $y_coord, $coord_str, $width, $height )
		= $cur->fetchrow();
	    last if !$roi_id;

	    if ( ! $all_ko{$ko_term} ) {
		# don't have this KO
		next;
	    }

	    if ( $bc_ko_h{$ko_term} ) {
		$in_bc = 1;
	    }

	    if ( $roi_id == $prev_roi_id ) {
		# same one
		if ( $ko_term eq $prev_ko_id ) {
		    # duplicate
		    next;
		}
		else {
		    if ( $ko_str ) {
			$ko_str .= ", " . $ko_term;
		    }
		    else {
			$ko_str = $ko_term;
		    }

		    my $label2 = "$roi_label, $ko_name";
		    $label2 .= ", $ko_defn" if $ko_defn ne "";

		    if ( $ko_label ) {
			$ko_label .= "; " . $label2;
		    }
		    else {
			$ko_label = $label2;
		    }

		    $prev_ko_id = $ko_term;
		}
	    }
	    else {
		# new one
		if ( $prev_roi_id ) {
		    my $r = $r2;
		    $r .= "$ko_str\t";
		    $r .= "$ko_label";

		    if ( $in_bc ) {
			push( @bcRecs, $r );
			$in_bc = 0;
		    }
		    else {
			push( @blueRecs, $r );
		    }
		}

		$prev_roi_id = $roi_id;
		$prev_ko_id = $ko_term;
		$ko_str = $ko_term;
		my $label2 = "$roi_label, $ko_name";
		$label2 .= ", $ko_defn" if $ko_defn ne "";
		$ko_label = $label2;

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

		$r2 = "$x_coord\t";
		$r2 .= "$y_coord\t";
		$r2 .= "$width\t";
		$r2 .= "$height\t";
		$r2 .= "$shape\t";
		$in_bc = 0;
	    }
	}
	$cur->finish();

	# last one
	if ( $prev_roi_id ) {
	    my $r = $r2;
	    $r .= "$ko_str\t";
	    $r .= "$ko_label";
	    if ( $in_bc ) {
		push( @bcRecs, $r );
		$in_bc = 0;
	    }
	    else {
		push( @blueRecs, $r );
	    }
	}
    }
    else {
	# DB
	my $sql = qq{
             select distinct iroi.roi_label, iroi.shape,
                    iroi.x_coord, iroi.y_coord, iroi.coord_string,
	            iroi.width, iroi.height,
                    kt.ko_name, kt.definition, kt.ko_id
             from image_roi_ko_terms irk, gene_ko_terms gk, gene g,
	            image_roi iroi, kegg_pathway pw, ko_term kt
	     where pw.image_id = ?
              and irk.roi_id = iroi.roi_id
              and iroi.roi_type in ('ko_term', 'enzyme')
	      and irk.ko_terms = gk.ko_terms
	      and gk.gene_oid = g.gene_oid
	      and iroi.pathway = pw.pathway_oid
	      and g.taxon = ?
	      and g.locus_type = 'CDS'
	      and g.obsolete_flag = 'No'
	      and kt.ko_id = gk.ko_terms
	      order by iroi.x_coord, iroi.y_coord,
	      iroi.width, iroi.height, iroi.roi_label
              };
	my $cur = execSql( $dbh, $sql, $verbose, $map_id, $taxon_oid );

	my $old_roi;
	my $old_in_bc = 0;
	my $in_bc = 0;
	my %unique_ko;
	for ( ;; ) {
	    my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
		 $width, $height, $ko_name, $ko_defn, $ko_id )
		= $cur->fetchrow();
	    last if !$roi_label;

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
	    $in_bc = 0;
	    if ( $ko_id && $bc_ko_h{$ko_id} ) {
		$in_bc = 1;
	    }

	    my $ko = "$roi_label";
	    my $koLabel = "$roi_label, $ko_name";
	    $koLabel .= ", $ko_defn" if $ko_defn ne "";

	    if ( $old_roi eq "" ) {
		$old_roi = $r;
		$old_in_bc = $in_bc;
	    }
	    if ( $old_roi eq $r ) {
		$unique_ko{$ko} = $koLabel;
	    } else {
		my $koStr = join(",", sort(keys(%unique_ko)));
		my $koLabelStr = join("; \n", sort(values(%unique_ko)));

		%unique_ko = ();

		$old_roi .= "\t$koStr" . "\t$koLabelStr";
		if ( $old_in_bc ) {
		    push( @bcRecs, $old_roi );
		    $old_in_bc = 0;
		}
		else {
		    push( @blueRecs, $old_roi );
		}
		$unique_ko{$ko} = $koLabel;
	    }
	    $old_roi = $r;
	    $old_in_bc = $in_bc;
	}

	my $koStr = join(",", keys(%unique_ko));
	my $koLabelStr = join(",", values(%unique_ko));

	$old_roi .= "\t$koStr" . "\t$koLabelStr";
	if ( $old_in_bc ) {
	    push( @bcRecs, $old_roi );
	    $old_in_bc = 0;
	}
	else {
	    push( @blueRecs, $old_roi );
	}
	$cur->finish();
    }

    ## MyIMG genes (cyan)
    my @cyanRecs;
    if ( $taxon_in_fs ) {
	# FS
    } else {
	# DB
	my $sql = qq{
            select distinct iroi.roi_label, iroi.shape,
                   iroi.x_coord, iroi.y_coord, iroi.coord_string,
                   iroi.width, iroi.height
            from image_roi_ko_terms irkt, ko_term_enzymes kte,
                 gene_myimg_enzymes gme, gene g,
                 image_roi iroi, kegg_pathway pw
            where pw.image_id = ?
            and iroi.roi_id = irkt.roi_id
            and iroi.roi_type in ('ko_term', 'enzyme')
            and irkt.ko_terms = kte.ko_id
            and kte.enzymes = gme.ec_number
            and gme.gene_oid = g.gene_oid
            and gme.modified_by = ?
            and iroi.pathway = pw.pathway_oid
            and g.taxon = ?
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            order by iroi.x_coord, iroi.y_coord,
            iroi.width, iroi.height, iroi.roi_label
        };

	my $old_roi;
	my %unique_ko;
	my $contact_oid = getContactOid();
	if ( $contact_oid > 0 && $show_myimg_login ) {
	    my $cur = execSql( $dbh, $sql, $verbose,
			       $map_id, $contact_oid, $taxon_oid );
	    for ( ;; ) {
		my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
		     $width, $height ) = $cur->fetchrow();
		last if !$roi_label;

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
		if ( $old_roi eq "" ) {
		    $old_roi = $r;
		}
		if ( $old_roi eq $r ) {
		    $unique_ko{$ko} = 1;
		} else {
		    my $koStr = join(",", sort(keys(%unique_ko)));
		    %unique_ko = ();

		    $old_roi .= "\t$koStr";
		    push( @cyanRecs, $old_roi );
		    $unique_ko{$ko} = 1;
		}
		$old_roi = $r;
	    }

	    my $koStr = join(",", keys(%unique_ko));
	    $old_roi .= "\t$koStr";
	    push( @cyanRecs, $old_roi );
	    $cur->finish();
	}
    }

    ## EC equivalogs (orange)
    my @orangeRecs;
    my $sql = qq{
        select distinct ir.roi_label, ir.shape,
               ir.x_coord, ir.y_coord, ir.coord_string,
               ir.width, ir.height,
               dt.taxon, kt.ko_name, kt.definition
        from dt_gene_ko_module_pwys dt, ko_term kt,
             image_roi ir, image_roi_ko_terms irk
        where dt.taxon != ?
        and dt.image_id = ?
        and dt.pathway_oid = ir.pathway
        and ir.roi_id = irk.roi_id
        and ir.roi_type in ('ko_term', 'enzyme')
        and ir.roi_label = kt.ko_id
        order by ir.x_coord, ir.y_coord, ir.width, ir.height, ir.roi_label
    };

    my %validTaxons = WebUtil::getAllTaxonsHashed($dbh);
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $map_id );

    my $old_roi;
    my %unique_tx;
    my %unique_ko;
    for ( ;; ) {
        my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
	     $width, $height, $taxon, $ko_id, $ko_name, $ko_defn )
	    = $cur->fetchrow();
        last if !$roi_label;
        next if !$validTaxons{$taxon};

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
            $unique_tx{$taxon} = 1;
        } else {
            my @keys = keys(%unique_tx);
            my $count = @keys;
            my $koStr = join(",", sort(keys(%unique_ko)));
            my $koLabelStr = join("; \n", sort(values(%unique_ko)));

            %unique_tx = ();
            %unique_ko = ();

	    $old_roi .= "\t$count" . "\t$koStr" . "\t$koLabelStr";
	    push( @orangeRecs, $old_roi );

            $unique_ko{$ko} = $koLabel;
            $unique_tx{$taxon} = 1;
        }
        $old_roi = $r;
    }

    my @keys = keys(%unique_tx);
    my $count = @keys;
    my $koStr = join(",", keys(%unique_ko));
    my $koLabelStr = join(",", values(%unique_ko));

    $old_roi .= "\t$count" . "\t$koStr" . "\t$koLabelStr";
    push( @orangeRecs, $old_roi );

    $cur->finish();

    my $inFile = "$pngDir/$map_id.png";
    my $im     = new GD::Image($inFile);
    if ( !$im ) {
        webDie("printKeggMapByTaxonOid: cannot read '$inFile'\n");
    }

    applyCoords( $im, \@cyanRecs,   "cyan" );
    applyCoords( $im, \@bcRecs,     "purple" );
    applyCoords( $im, \@blueRecs,   "blue" );
    applyCoords( $im, \@orangeRecs, "orange" );

    $taxon_oid =~ /([0-9]+)/;
    $taxon_oid = $1;
    my $tmpPngFile = "$tmp_dir/$map_id.t$taxon_oid.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.t$taxon_oid.png";

    my $wfh = newWriteFileHandle( $tmpPngFile, "printKeggMapByTaxonOid" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    print "<h1>KEGG Map</h1>\n";
    my $urlt = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>Current Genome: ".alink($urlt, $taxon_name);

    if ( $cluster_id ) {
        my $url2 = "$main_cgi?section=BiosyntheticDetail" .
            "&page=cluster_detail&taxon_oid=$taxon_oid" .
            "&cluster_id=$cluster_id";
        print "<br/>Cluster ID: " . alink($url2, $cluster_id);
    }

    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    printTaxonLegend($taxon_name, $taxon_filter_oid_str, 0, 0, 0, $cluster_id);
    print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";

    print "<map name='mapdata'>\n";
    if ( ! $taxon_in_fs ) {
	printMyIMGMapCoords( \@cyanRecs, $map_id, $taxon_oid );
    }
    printKoMapCoords( \@blueRecs, $map_id, $taxon_oid );
    if ( $cluster_id ) {
	printKoMapCoords( \@bcRecs, $map_id, $taxon_oid );
    }
    printKoEquivMapCoords( \@orangeRecs, $map_id, $taxon_oid );
    printRelatedCoords( $dbh, $map_id, $taxon_oid );
    print "</map>\n";

    printKeggPathwayDetailLink( $dbh, $map_id );

    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printKeggMapMissingECByTaxonOid - Print KEGG map by taxon_oid
#   as related KEGG map. (duplicate for missing EC function)
############################################################################
sub printKeggMapMissingECByTaxonOid {
    my ($taxon)     = @_;
    my $map_id      = param("map_id");
    my $taxon_oid   = param("taxon_oid");
    my $pathway_oid = param("pathway_oid");
    if ( $taxon ne "" ) {
        $taxon_oid = $taxon;
    }

    my $dbh = dbLogin();
    my ( $taxon_oid, $taxon_name ) =
      getTaxonRecByTaxonOid( $dbh, $taxon_oid );
    checkTaxonPerm( $dbh, $taxon_oid );

    print "<h1>KEGG Map (for Finding Missing Enzymes)</h1>\n";
    my $urlt = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>Current Genome: ".alink($urlt, $taxon_name);

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    ## roi ko to ec conversion
    my %ko2ec;
    my $sql2 = "select ko_id, enzymes from ko_term_enzymes";
    my $cur2 = execSql( $dbh, $sql2, $verbose );
    for (;;) {
        my ($ko2, $ec2) = $cur2->fetchrow();
        last if ! $ko2;

        $ko2ec{$ko2} = $ec2;
    }
    $cur2->finish();

    ## Taxon genes (blue)
    my $sql = qq{
        select distinct iroi.roi_label, iroi.shape,
              iroi.x_coord, iroi.y_coord, iroi.coord_string,
              iroi.width, iroi.height
        from image_roi_ko_terms irkt, ko_term_enzymes kte,
             gene_ko_enzymes ge, gene g,
             image_roi iroi, kegg_pathway pw
        where pw.image_id = ?
        and iroi.roi_id = irkt.roi_id
        and iroi.roi_type in ('ko_term', 'enzyme')
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = ge.enzymes
        and ge.gene_oid = g.gene_oid
        and iroi.pathway = pw.pathway_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        order by iroi.x_coord, iroi.y_coord,
        iroi.width, iroi.height, iroi.roi_label
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id, $taxon_oid );

    my @blueRecs;
    my @allbluerecs;
    my $old_roi;
    my %unique_roi;
    for ( ;; ) {
        my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
	     $width, $height ) = $cur->fetchrow();
        last if !$roi_label;

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

	push( @allbluerecs,
	      "$x_coord\t$y_coord\t$width\t$height\t$shape\t$roi_label");

        my $r = "$x_coord\t";
        $r .= "$y_coord\t";
        $r .= "$width\t";
        $r .= "$height\t";
        $r .= "$shape";

        if ($width <= 0 || $height <= 0) {
            next; # can't display this roi
        }
        if ( $old_roi eq "" ) {
            $old_roi = $r;
        }
        if ( $old_roi eq $r ) {
            $unique_roi{$roi_label} = 1;
        } else {
            my $roiStr = join(",", sort(keys(%unique_roi)));
            %unique_roi = ();

            $old_roi .= "\t$roiStr";
            push( @blueRecs, $old_roi );
            $unique_roi{$roi_label} = 1;
        }
        $old_roi = $r;
    }

    my $roiStr = join(",", keys(%unique_roi));
    $old_roi .= "\t$roiStr";
    push( @blueRecs, $old_roi );
    $cur->finish();

    ## MyIMG genes (cyan)
    my $sql = qq{
        select distinct iroi.roi_label, iroi.shape,
               iroi.x_coord, iroi.y_coord, iroi.coord_string,
               iroi.width, iroi.height
        from image_roi_ko_terms irkt, ko_term_enzymes kte,
             gene_myimg_enzymes gme, gene g,
             image_roi iroi, kegg_pathway pw
        where pw.image_id = ?
        and iroi.roi_id = irkt.roi_id
        and iroi.roi_type in ('ko_term', 'enzyme')
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = gme.ec_number
        and gme.gene_oid = g.gene_oid
        and gme.modified_by = ?
        and iroi.pathway = pw.pathway_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        order by iroi.x_coord, iroi.y_coord,
                 iroi.width, iroi.height, iroi.roi_label
    };

    my @cyanRecs;
    my @allcyanrecs;
    my $old_roi;
    my %unique_roi;
    my $contact_oid = getContactOid();
    if ( $contact_oid && $show_myimg_login ) {
        my $cur = execSql( $dbh, $sql, $verbose,
			   $map_id, $contact_oid, $taxon_oid );
        for ( ;; ) {
            my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
		 $width, $height ) = $cur->fetchrow();
            last if !$roi_label;

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

	    push( @allcyanrecs,
		  "$x_coord\t$y_coord\t$width\t$height\t$shape\t$roi_label");

	    my $r = "$x_coord\t";
	    $r .= "$y_coord\t";
	    $r .= "$width\t";
	    $r .= "$height\t";
	    $r .= "$shape";

	    if ($width <= 0 || $height <= 0) {
		next; # can't display this roi
	    }
	    if ( $old_roi eq "" ) {
		$old_roi = $r;
	    }
	    if ( $old_roi eq $r ) {
		$unique_roi{$roi_label} = 1;
	    } else {
		my $roiStr = join(",", sort(keys(%unique_roi)));
		%unique_roi = ();

		$old_roi .= "\t$roiStr";
		push( @cyanRecs, $old_roi );
		$unique_roi{$roi_label} = 1;
	    }
	    $old_roi = $r;
	}

	my $roiStr = join(",", keys(%unique_roi));
	$old_roi .= "\t$roiStr";
	push( @cyanRecs, $old_roi );
	$cur->finish();
    }

    ## missing enzymes (white) (or light green if with ko)
    my %enzyme_h;
    my $sql2 = qq{
        select kte.enzymes
	from gene g, gene_candidate_ko_terms gckt, ko_term_enzymes kte
	where g.gene_oid = gckt.gene_oid
	and g.taxon = ?
	and gckt.ko_terms = kte.ko_id
        and kte.enzymes is not null
    };
    my $cur2 = execSql( $dbh, $sql2, $verbose, $taxon_oid );
    for (;;) {
	my ($ec2) = $cur2->fetchrow();
	last if ! $ec2;

	if ( $enzyme_h{$ec2} ) {
	    $enzyme_h{$ec2} += 1;
	}
	else {
	    $enzyme_h{$ec2} = 1;
	}
    }
    $cur2->finish();

    my @koEcRecs;
    my $sql = qq{
       select distinct iroi.roi_label, iroi.shape,
              iroi.x_coord, iroi.y_coord, iroi.coord_string,
              iroi.width, iroi.height
         from image_roi_ko_terms irkt, ko_term_enzymes kte,
              image_roi iroi, kegg_pathway pw
        where pw.image_id = ?
          and iroi.roi_id = irkt.roi_id
          and iroi.roi_type in ('ko_term', 'enzyme')
          and irkt.ko_terms = kte.ko_id
	  and iroi.pathway = pw.pathway_oid
     order by iroi.x_coord, iroi.y_coord,
	      iroi.width, iroi.height, iroi.roi_label
    };

    my @whiteRecs;
    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    for ( ;; ) {
        my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
	     $width, $height ) = $cur->fetchrow();
        last if !$roi_label;

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

        my $r1 .= "$x_coord\t";
        $r1 .= "$y_coord\t";
        $r1 .= "$width\t";
        $r1 .= "$height\t";
        $r1 .= "$shape\t";
        my $r = $r1 . "$roi_label";

        if ( WebUtil::inArray( $r, @allbluerecs ) ||
	     WebUtil::inArray( $r, @allcyanrecs ) ) {
            next;
        }

        my $ko2 = "KO:" . $roi_label;
        my $ec2 = $ko2ec{$ko2};
	if ( $enzyme_h{$ec2} ) {
            push( @koEcRecs, $r );
        }

        if ( $ec2 ) {
            my ($part1, $part2) = split(/\:/, $ec2);
            my $r2 = $r1 . "$part2" . "\t" . $roi_label;
            push( @whiteRecs, $r2 );
        }
    }
    $cur->finish();

    my $inFile = "$pngDir/$map_id.png";
    my $im     = new GD::Image($inFile);
    if ( !$im ) {
        webDie("printKeggMapByTaxonOid: cannot read '$inFile'\n");
    }
    applyCoords( $im, \@cyanRecs,  "cyan" );
    applyCoords( $im, \@blueRecs,  "blue" );
    applyCoords( $im, \@koEcRecs,  "green" );
    applyCoords( $im, \@whiteRecs, "yellow" );

    $taxon_oid =~ /([0-9]+)/;
    $taxon_oid = $1;
    my $tmpPngFile = "$tmp_dir/$map_id.t$taxon_oid.$$.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.t$taxon_oid.$$.png";

    my $wfh = newWriteFileHandle( $tmpPngFile, "printKeggMapByTaxonOid" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    printTaxonLegend( $taxon_name, $taxon_filter_oid_str, 1, 1, 1 );
    print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";

    print "<map name='mapdata'>\n";
    printMyIMGMapCoords( \@cyanRecs, $map_id, $taxon_oid );
    printEcMapCoords( \@blueRecs, $map_id, $taxon_oid );
    printMissingECCoords( \@whiteRecs, $map_id, $taxon_oid );
    printRelatedCoords( $dbh, $map_id, $taxon_oid );
    print "</map>\n";

    printKeggPathwayDetailLink( $dbh, $map_id );

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printAbundanceByTaxonOid - KEGG map by taxon_oid for relative abundance.
#      obsolete & no longer used
############################################################################
sub printAbundanceByTaxonOid {
    my ($taxon)   = @_;
    my $map_id    = param("map_id");
    my $taxon_oid = param("taxon_oid");
    if ( $taxon ne "" ) {
        $taxon_oid = $taxon;
    }

    my $dbh = dbLogin();
    my ( $taxon_oid, $taxon_name ) =
      getTaxonRecByTaxonOid( $dbh, $taxon_oid );
    checkTaxonPerm( $dbh, $taxon_oid );

    printMainForm();
    print "<h1>Relative Abundance KEGG Map</h1>\n";
    my $urlt = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>Current Genome: ".alink($urlt, $taxon_name);

    printStatusLine( "Loading ...", 1 );

    ## Taxon genes by heat map
    my $sql = qq{
        select distinct iroi.roi_label, iroi.shape,
               iroi.x_coord, iroi.y_coord, iroi.coord_string,
               iroi.width, iroi.height, dt.score
        from image_roi_ko_terms irkt, ko_term_enzymes kte,
             gene_ko_enzymes ge, gene g,
             image_roi iroi, kegg_pathway pw, dt_kegg_enzyme_abundance dt
        where pw.image_id = ?
        and iroi.roi_id = irkt.roi_id
        and iroi.roi_type in ('ko_term', 'enzyme')
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = ge.enzymes
        and dt.ec_number = ge.enzymes
        and dt.taxon_oid = ?
        and dt.kegg_image_id = ?
        and ge.gene_oid = g.gene_oid
        and iroi.pathway = pw.pathway_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        order by iroi.x_coord, iroi.y_coord,
                 iroi.width, iroi.height, iroi.roi_label
    };
    my $cur = execSql( $dbh, $sql, $verbose,
		       $map_id, $taxon_oid, $map_id, $taxon_oid );

    my @recs;
    for ( ;; ) {
        my ( $roi_label, $shape, $x_coord, $y_coord, $coord_str,
	     $width, $height, $score ) =
          $cur->fetchrow();
        last if !$roi_label;

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
	$r .= "$shape\t";
        $r .= "$score\t";
	$r .= "$roi_label";
        push( @recs, $r );
    }
    $cur->finish();

    my $inFile = "$pngDir/$map_id.png";
    my $im     = new GD::Image($inFile);
    if ( !$im ) {
        webDie("printAbundanceByTaxonOid: cannot read '$inFile'\n");
    }
    applyHeatMapCoords( $im, \@recs );

    $taxon_oid =~ /([0-9]+)/;
    $taxon_oid = $1;
    my $tmpPngFile = "$tmp_dir/$map_id.ab.t$taxon_oid.png";
    my $tmpPngUrl  = "$tmp_url/$map_id.ab.t$taxon_oid.png";

    my $wfh = newWriteFileHandle( $tmpPngFile, "printAbundanceByTaxonOid" );
    binmode $wfh;
    print $wfh $im->png;
    close $wfh;

    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    printAbundanceLegend();
    print "<image src='$tmpPngUrl' usemap='#mapdata' border='0' />\n";

    print "<map name='mapdata'>\n";
    printEcMapCoords( \@recs, $map_id, $taxon_oid );
    printRelatedCoords( $dbh, $map_id, $taxon_oid, "abundance" );
    print "</map>\n";

    printKeggPathwayDetailLink( $dbh, $map_id );

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printGeneLegend - Print legend for different colors in KEGG map.
############################################################################
sub printGeneLegend {
    my ( $taxon_display_name, $taxon_filter_oid_str, $myimg ) = @_;

    print "<p>\n";

    if ( !$myimg ) {
        print "<image src='$base_url/images/current.gif' "
          . "width='10' height='10' />\n";
        print "Current Gene\n";
        print "<br/>\n";
    }

    print "<image src='$base_url/images/poscluster.gif' "
      . "width='10' height='10' />\n";
    print "Positional Cluster Gene\n";
    print "<br/>\n";

    print "<image src='$base_url/images/intaxon.gif' "
      . "width='10' height='10' />\n";
    print "Other genes in " . escHtml($taxon_display_name);
    print "<br/>\n";

    print "<image src='$base_url/images/ecequiv.gif' "
      . "width='10' height='10' />\n";

    print "Genes found in other genomes";
    print "<br/>\n";

    if ($show_myimg_login) {
        print "<image src='$base_url/images/myimg.gif' "
          . "width='10' height='10' />\n";
        print "MyIMG annotated EC numbers";
        print "<br/>\n";
    }

    my $filterMsg = "";
    $filterMsg = "( Taxon filter enabled )"
	if !blankStr($taxon_filter_oid_str);

    print "</p>\n";

}

############################################################################
# printAbundanceLegend - Print legend for different colors in KEGG map.
############################################################################
sub printAbundanceLegend {
    print "<p>\n";

    my $url = "$section_cgi&page=kpdAbundanceZscoreNote";
    my $link = alink( $url, "z-score" );
    print "$link ranges for relative abundance of enzymes.\n";
    print "<br/>\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-124-218-144.png' "
      . "width='10' height='10' />\n";
    print "&lt;= 0.0\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-144-238-144.png' "
      . "width='10' height='10' />\n";
    print "[ 0.0 - < 0.5 )\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-200-255-50.png' "
      . "width='10' height='10' />\n";
    print "[ 0.5 - < 1.0 )\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-240-100-100.png' "
      . "width='10' height='10' />\n";
    print "[ 1.0 - 1.5 )\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-255-100-100.png' "
      . "width='10' height='10' />\n";
    print "[ 1.5 - 2.0 )\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-255-50-50.png' "
      . "width='10' height='10' />\n";
    print "[ 2.0 - 2.5 )\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-255-20-20.png' "
      . "width='10' height='10' />\n";
    print "[ 2.5 - 3.0 )\n";
    print "<br/>\n";

    print "<image src='$base_url/images/rgb-255-10-10.png' "
      . "width='10' height='10' />\n";
    print "&gt;= 3.0\n";

    print "</p>\n";
}

############################################################################
# printZscoreNote - Print z-score note.
############################################################################
sub printZscoreNote {
    print qq{
       <p>
       The z-score is a measure of relative abundance over the
       average of all genomes in the database for a
       given enzyme in a pathway map.
       Scaling for variance (standard deviation) is taken
       into account in the scoring.
       </p>

       <p>
       Background frequencies (count of genes assigned to enzymes)
       are taken from all
       database genomes (bacterial, archaeal, eukaryotic, and metagenome).
       (Viruses, GFragment and orhpan plasmids are not included.)
       The frequences are normalized in terms of count of genes with enzyme
       assignments over the total gene count for the genome.
       These frequencies are computed
       for each KEGG pathway and enzyme in each pathway.  For
       enzyme in a pathway, the mean and standard
       deviation is calculated.  From the mean and standard
       deviation, a z-score is computed for each genome.
       </p>

       <p>
       <i>x = Normalized enzyme frequency</i><br/>
       <i>z<sub>x</sub> = ( x - mean<sub>x</sub> ) /
       standard.deviation<sub>x</sub></i>
       <br/>
       </p>

       <p>
       Note: The z-score may not necessarily correlate well with
       the actual gene count.  Rather it's a statement about
       abundance over a <i>background average</i>.
       </p>
    };
}

############################################################################
# printTaxonLegend - Print legend for different colors in KEGG map.
############################################################################
sub printTaxonLegend {
    my ( $taxon_display_name, $taxon_filter_oid_str,
	 $hide_others, $has_ec, $missing, $in_cluster ) = @_;

    print "<p>\n";

    print "<image src='$base_url/images/intaxon.gif' "
	. "width='10' height='10' />\n";
    print "Genes in " . escHtml($taxon_display_name);
    print "<br/>\n";

    if ( !$hide_others ) {
        print "<image src='$base_url/images/ecequiv.gif' "
	    . "width='10' height='10' />\n";
        print "Genes found in other genomes";
        print "<br/>\n";
    }

    if ($show_myimg_login) {
        print "<image src='$base_url/images/myimg.gif' "
	    . "width='10' height='10' />\n";
        print "MyIMG annotated EC numbers";
        print "<br/>\n";
    }

    if ($has_ec) {
        print "<image src='$base_url/images/green-square.gif' "
	    . "width='10' height='10' />\n";
        print "Enzymes with KO hits";
        print "<br/>\n";
    }

    if ($missing) {
        print "<image src='$base_url/images/yellow-square.gif' "
	    . "width='10' height='10' />\n";
        print "Missing Enzymes";
        print "<br/>\n";
    }

    if ($in_cluster) {
        print "<image src='$base_url/images/purple-square.gif' "
	    . "width='10' height='10' />\n";
        print "Genes in Cluster";
        print "<br/>\n";
    }

    my $filterMsg = "";
    $filterMsg = "( Taxon filter enabled )"
	if !blankStr($taxon_filter_oid_str);

    print "</p>\n";
}

############################################################################
# getTaxonRecByGeneOid - Map gene_oid -> taxon_oid
############################################################################
sub getTaxonRecByGeneOid {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
      select g.taxon, tx.taxon_display_name
      from gene g, taxon tx
      where g.gene_oid = ?
      and g.taxon = tx.taxon_oid
      and g.obsolete_flag = 'No'
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
    $cur->finish();
    return ( $taxon_oid, $taxon_display_name );
}

############################################################################
# getTaxonRecByTaxonOid - Get taxon information from taxon_oid.
############################################################################
sub getTaxonRecByTaxonOid {
    my ( $dbh, $taxon_oid ) = @_;
    my $sql = qq{
      select tx.taxon_oid, tx.taxon_display_name
      from taxon tx
      where tx.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
    $cur->finish();
    return ( $taxon_oid, $taxon_display_name );
}

############################################################################
# applyCoords - Apply color to boxes given image ROI (region of interest)
#   coordinates.
#   Inputs:
#      im - image buffer
#      recs_ref - records reference to regions of interest (genes)
#      color - what color for coloring these regions
############################################################################
sub applyCoords {
    my ( $im, $recs_ref, $colorName ) = @_;
    foreach my $r (@$recs_ref) {
        my ( $x, $y, $w, $h, $shape, @ignore ) = split( /\t/, $r );

        next if $roiDone{"$x,$y"} ne "";
        next if ($w <= 0 || $h <= 0) && $shape eq "rect";

        my $coord_str;
        my $poly;

	my $black = $im->colorClosest( 0, 0, 0 );
	if ( $black == -1 ) {
	    $black = $im->colorAllocate( 0, 0, 0 );
	}

        if ($shape eq "rect") {
	    if ( $colorName eq 'purple' ) {
		highlightRectRgb( $im, $x, $y, $w, $h, 183, 0, 91, 50 );
	    } else {
		highlightRect( $im, $x, $y, $w, $h, $colorName );
	    }

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

	    my $color = getColor($im, $colorName);
            $im->filledPolygon($poly, $color);
            $im->polygon($poly, $black);
        }

        $roiDone{"$x,$y"} = 1;
    }
}

sub getColor {
    my ($im, $colorName) = @_;
    my $color;
    if ( $colorName eq "green" ) {
	$color = $im->colorExact( 100, 255, 100 );
        $color = $im->colorAllocate( 100, 255, 100 ) if $color < 0;
    } elsif ( $colorName eq "red" ) {
	$color = $im->colorExact( 255, 100, 100 );
        $color = $im->colorAllocate( 255, 100, 100 ) if $color < 0;
    } elsif ( $colorName eq "blue" ) {
	$color = $im->colorExact( 140, 140, 255 );
        $color = $im->colorAllocate( 140, 140, 255 ) if $color < 0;
    } elsif ( $colorName eq "orange" ) {
	$color = $im->colorExact( 255, 185, 100 );
        $color = $im->colorAllocate( 255, 185, 100 ) if $color < 0;
    } elsif ( $colorName eq "cyan" ) {
	$color = $im->colorExact( 140, 255, 255 );
        $color = $im->colorAllocate( 140, 255, 255 ) if $color < 0;
    } elsif ( $colorName eq "yellow" ) {
	$color = $im->colorExact( 255, 255, 140 );
        $color = $im->colorAllocate( 255, 255, 140 ) if $color < 0;
    } elsif ( $colorName eq "purple" ) {
	$color = $im->colorExact( 183, 0, 91 );
        $color = $im->colorAllocate( 183, 0, 91 )    if $color < 0;
    } else {
	# return white color
	$color = $im->colorExact( 255, 255, 255 );
        $color = $im->colorAllocate( 255, 255, 255 ) if $color < 0;
    }
    return $color;
}

############################################################################
# applyHeatMapCoords - Apply color to boxes given image ROI coordinates.
#   Inputs:
#   im - image buffer
#   recs_ref - records reference to regions of interest (genes) with score.
#   color - what color for coloring these regions
############################################################################
sub applyHeatMapCoords {
    my ( $im, $recs_ref ) = @_;
    foreach my $r (@$recs_ref) {
        my ( $x, $y, $w, $h, $shape, $score, $roiStr ) = split( /\t/, $r );
        next if $roiDone{"$x,$y"} ne "";

        my ( $r, $g, $b ) = ( 255, 255, 255 );
        if ( $score <= 0 ) {
            ( $r, $g, $b ) = ( 124, 218, 144 );
        } elsif ( $score >= 0 && $score < 0.5 ) {
            ( $r, $g, $b ) = ( 144, 238, 144 );
        } elsif ( $score >= .5 && $score < 1.0 ) {
            ( $r, $g, $b ) = ( 200, 255, 50 );
        } elsif ( $score >= 1.0 && $score < 1.5 ) {
            ( $r, $g, $b ) = ( 240, 100, 100 );
        } elsif ( $score >= 1.5 && $score < 2.0 ) {
            ( $r, $g, $b ) = ( 255, 100, 100 );
        } elsif ( $score >= 2.0 && $score < 2.5 ) {
            ( $r, $g, $b ) = ( 255, 50, 50 );
        } elsif ( $score >= 2.5 && $score < 3.0 ) {
            ( $r, $g, $b ) = ( 255, 20, 20 );
        } elsif ( $score >= 3.0 ) {
            ( $r, $g, $b ) = ( 255, 10, 10 );
        }
        webLog "applyHeatMap: (x=$x,y=$y) score=$score (r=$r,g=$g,b=$b)\n"
          if $verbose >= 1;
        highlightRectRgb( $im, $x, $y, $w, $h, $r, $g, $b );

        if ( $shape ne "rect" ) {
            my $black = $im->colorClosest( 0, 0, 0 );
            if ( $black == -1 ) {
                $black = $im->colorAllocate( 0, 0, 0 );
            }
            $im->rectangle( $x, $y, $x+$w, $y+$h, $black );
        }
        $roiDone{"$x,$y"} = 1;
    }
}

############################################################################
# printMapCoords - Print map coordinates as selectable links.
############################################################################
sub printMapCoords {
    my ( $recs_ref, $map_id, $taxon_oid, $gid0 ) = @_;
    my %recs;
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $workspace_id ) = split( /\t/, $r );
	my ($t2, $d2, $gene_oid) = split(/ /, $workspace_id);
	if ( ! $gene_oid ) {
	    $gene_oid = $t2;
	    $d2 = 'database';
	}

	my $url = "$main_cgi?section=GeneDetail"
                . "&page=geneDetail&gene_oid=$gene_oid";
	if ( $d2 eq 'assembled' || $d2 eq 'unassembled' ) {
	    $url = "$main_cgi?section=MetaGeneDetail"
		. "&page=metaGeneDetail&gene_oid=$gene_oid"
		. "&taxon_oid=$t2&data_type=$d2";
	}

	my @items = split(/,/, $gene_oid);
	if (scalar @items > 1) {
	    $url = "$section_cgi&page=keggMapTaxonGenes"
		. "&taxon_oid=$taxon_oid"
		. "&map_id=$map_id"
		. "&genes=$gene_oid&gene_oid=$gid0";
	}

        if ($shape eq "rect") {
            my $x2  = $x1 + $w;
            my $y2  = $y1 + $h;

            print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
                . " target='_blank' title='Gene(s)=$gene_oid' >\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' title='Gene(s)=$gene_oid' >\n";
        }
    }
}

############################################################################
# printEcMapCoords - Print map coordinates as selectable links for
#  using EC number as argument.
############################################################################
sub printEcMapCoords {
    my ( $recs_ref, $map_id, $taxon_oid, $gene_oid ) = @_;
    my %recs;
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $ecStr ) = split( /\t/, $r );

        my $url = "$section_cgi&page=keggMapTaxonGenesEc";
	$url .= "&taxon_oid=$taxon_oid";
        $url .= "&map_id=$map_id";
	$url .= "&ec_number=$ecStr";
        $url .= "&gene_oid=$gene_oid" if $gene_oid ne "";

        if ($shape eq "rect") {
            my $x2  = $x1 + $w;
            my $y2  = $y1 + $h;

            print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
                . " target='_blank' title='EC=$ecStr' >\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' title='EC=$ecStr' >\n";
        }
    }
}

############################################################################
# printKoMapCoords - overlays the image map for the pathway map
############################################################################
sub printKoMapCoords {
    my ( $recs_ref, $map_id, $taxon_oid, $gene_oid ) = @_;
    my %recs;
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $koStr, $koLabelStr ) =
          split( /\t/, $r );

        my $url = "$section_cgi&page=keggMapTaxonGenesKo";
	$url .= "&taxon_oid=$taxon_oid";
        $url .= "&map_id=$map_id";
        $url .= "&gene_oid=$gene_oid" if $gene_oid ne "";
        $url .= "&ko=$koStr";

        if ($shape eq "rect") {
            my $x2  = $x1 + $w;
            my $y2  = $y1 + $h;

            print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
                . " target='_blank' title='$koLabelStr' >\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' title='$koLabelStr' >\n";
        }
    }
}

############################################################################
# printMyIMGMapCoords - Print map coordinates as selectable links for
#  using EC number as argument.
############################################################################
sub printMyIMGMapCoords {
    my ( $recs_ref, $map_id, $taxon_oid, $gene_oid ) = @_;
    my %recs;
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $ec_str ) = split( /\t/, $r );

        my $url = "$section_cgi&page=myIMGKeggMapTaxonGenes";
	$url .= "&taxon_oid=$taxon_oid";
        $url .= "&map_id=$map_id";
        $url .= "&gene_oid=$gene_oid" if $gene_oid ne "";
	$url .= "&ec_number=$ec_str";

	my $text;
	$text = "Gene=$gene_oid " if $gene_oid ne "";
	$text .= "EC=$ec_str";

        if ($shape eq "rect") {
            my $x2  = $x1 + $w;
            my $y2  = $y1 + $h;

            print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
                . " target='_blank' title='$text' >\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' title='$text' >\n";
        }
    }
}

############################################################################
# printKoEquivMapCoords - overlays the image map for the pathway map
############################################################################
sub printKoEquivMapCoords {
    my ( $recs_ref, $map_id, $taxon_oid, $gene_oid ) = @_;
    my %recs;
    foreach my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $count, $koStr, $koLabelStr )
	    = split( /\t/, $r );

        my $url = "$section_cgi&page=keggMapKoEquiv";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&map_id=$map_id";
        $url .= "&gene_oid=$gene_oid" if $gene_oid ne "";
        $url .= "&ko=$koStr";

	my $text = "($count other genomes), $koLabelStr";
        if ($shape eq "rect") {
            my $x2  = $x1 + $w;
            my $y2  = $y1 + $h;

            print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
                . " target='_blank' title='$text' >\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' title='$text' >\n";
        }
    }
}

############################################################################
# printMissingECCoords - Print missing EC selectable links.
############################################################################
sub printMissingECCoords {
    my ( $recs_ref, $map_id, $taxon_oid, $gene_oid ) = @_;
    my $pathway_oid = param('pathway_oid');

    my %recs;
    my %done;
    for my $r (@$recs_ref) {
        my ( $x1, $y1, $w, $h, $shape, $ec_number, $roi_label ) = split( /\t/, $r );
        my $k = "$ec_number-$x1-$y1";
        next if $done{$k};

        my $url = "$main_cgi?section=MissingGenes&page=candidatesForm";
	$url .= "&taxon_oid=$taxon_oid";
        $url .= "&funcId=EC:$ec_number";
        $url .= "&pathway_oid=$pathway_oid";
	$url .= "&map_id=$map_id";
	if ( $roi_label ) {
	    $url .= "&roi_label=$roi_label";
	}

        if ($shape eq "rect") {
            my $x2  = $x1 + $w;
            my $y2  = $y1 + $h;

            print "<area shape='rect' coords='$x1,$y1,$x2,$y2' href=\"$url\" "
                . " target='_blank' title='EC=$ec_number' >\n";
        } elsif ($shape eq "poly") {
            my $coord_str = $h;
            print "<area shape='poly' coords='$coord_str' href=\"$url\" "
                . " target='_blank' title='EC=$ec_number' >\n";
        }

        $done{$k} = 1;
    }
}

############################################################################
# printRelatedCoords -  Print for selectability of related KEGG pathways.
############################################################################
sub printRelatedCoords {
    my ( $dbh, $map_id, $taxon_oid, $mapType ) = @_;

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
        if ( $mapType eq "abundance" ) {
            print "href=$main_cgi?section=KeggPathwyaDetail"
              . "&kpdViewKeggMapForOneGenome=1&mapType=$mapType"
              . "&map_id=$image_id&taxon_oid=$taxon_oid>\n";
        } else {
            print "href=$section_cgi&page=keggMapRelated"
              . "&map_id=$image_id&taxon_oid=$taxon_oid>\n";
        }
    }
    $cur->finish();
}

############################################################################
# printKeggMapTaxonGenesKo - prints the ko with the given genes
############################################################################
sub printKeggMapTaxonGenes {
    my $map_id    = param("map_id");
    my $taxon_oid = param("taxon_oid");
    my $genes = param("genes");
    my $gene_oid  = param("gene_oid");

    my $dbh = dbLogin();
    my ( $taxon_oid, $taxon_name ) = getTaxonRecByTaxonOid($dbh, $taxon_oid);

    my $text;
    my $current_gene;
    my @genes = split(/,/, $genes);
    if ( $gene_oid ne "" && scalar @genes > 1) {
        $text = "Positional Cluster ";

        my $sql = qq{
            select distinct g.gene_display_name, g.locus_tag
            from gene g where g.gene_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	my ($name, $locus) = $cur->fetchrow();
        $cur->finish();

        my $urlg = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gene_oid";
        $current_gene = "<br/>Current Gene: "
            . alink( $urlg, "$gene_oid [$locus]");
    }

    my $urlt = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<h1>$text"."Genes</h1>\n";
    print "<p>Current Genome: ".alink($urlt, $taxon_name)."$current_gene</p>";

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name, g.locus_tag,
               iroi.roi_label
        from image_roi_ko_terms irk, gene_ko_terms gk,
             image_roi iroi, kegg_pathway pw, gene g
        where pw.image_id = ?
        and iroi.pathway = pw.pathway_oid
        and irk.roi_id = iroi.roi_id
        and iroi.roi_type in ('ko_term', 'enzyme')
        and irk.ko_terms = gk.ko_terms
        and gk.gene_oid = g.gene_oid
        and g.taxon = ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and gk.gene_oid in ($genes)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id, $taxon_oid );

    printMainForm();

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",   "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "KO",        "asc", "left"  );

    my $count = 0;
    for ( ;; ) {
	my ( $gid, $name, $locus_tag, $ko ) = $cur->fetchrow();
	last if !$gid;

	my $url1 = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gid";
        my $url2 = "$ko_base_url$ko";

        my $row = $sd."<input type='checkbox' "
            . "name='gene_oid' value='$gid'/>\t";
        $row .= $gid.$sd.alink($url1, $gid)."\t";
        $row .= $locus_tag.$sd.$locus_tag."\t";
        $row .= $name.$sd.$name."\t";
        $row .= $ko.$sd.alink($url2, $ko)."\t";
        $it->addRow($row);
        $count++;
    }
    $cur->finish();

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
}

############################################################################
# printKeggMapTaxonGenesEc - Print genes related to same taxon for EC number.
#  (Blue box selected).
############################################################################
sub printKeggMapTaxonGenesEc {
    my $map_id    = param("map_id");
    my $ec_str    = param("ec_number");
    my $taxon_oid = param("taxon_oid");
    my $gene_oid  = param("gene_oid");

    my $dbh = dbLogin();
    my ( $taxon_oid, $taxon_name ) = getTaxonRecByTaxonOid($dbh, $taxon_oid);
    print "<h1>Genes with EC: <font color='darkblue'>"
        . "<u>$ec_str</u></font></h1>\n";

    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>Current Genome: ".alink($url, $taxon_name)."</p>";

    my $gene_oid_clause;
    $gene_oid_clause = "and g.gene_oid != ?" if $gene_oid ne "";

    my @ec = split(",", $ec_str);
    $ec_str = joinSqlQuoted(",", @ec);

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name, g.locus_tag,
               iroi.roi_label
        from image_roi_ko_terms irkt, ko_term_enzymes kte,
             gene_ko_enzymes ge, gene g,
             image_roi iroi, kegg_pathway pw
        where pw.image_id = ?
        and iroi.roi_id = irkt.roi_id
        and iroi.roi_type in ('ko_term', 'enzyme')
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = ge.enzymes
        and ge.gene_oid = g.gene_oid
        and iroi.pathway = pw.pathway_oid
        and g.taxon = ?
        and iroi.roi_label in ($ec_str)
        and g.obsolete_flag = 'No'
        $gene_oid_clause
    };
    my $cur;
    if ( $gene_oid ne "" ) {
        $cur = execSql
            ( $dbh, $sql, $verbose, $map_id, $taxon_oid, $gene_oid );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $map_id, $taxon_oid );
    }

    printMainForm();

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",   "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "EC",        "asc", "left"  );

    my $count = 0;
    for ( ;; ) {
        my ( $gene_oid, $name, $locus_tag, $ec )
            = $cur->fetchrow();
        last if !$gene_oid;

        my $url1 = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gene_oid";
        my $url2 = "$ec_base_url"."EC:$ec";

        my $row = $sd."<input type='checkbox' "
            . "name='gene_oid' value='$gene_oid'/>\t";
        $row .= $gene_oid.$sd.alink($url1, $gene_oid)."\t";
        $row .= $locus_tag.$sd.$locus_tag."\t";
        $row .= $name.$sd.$name."\t";
        $row .= $ec.$sd.alink($url2, $ec)."\t";
        $it->addRow($row);
	$count++;
    }
    $cur->finish();

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
}

############################################################################
# printKeggMapTaxonGenesKo - prints the genes with the given ko number
############################################################################
sub printKeggMapTaxonGenesKo {
    my $map_id    = param("map_id");
    my $ko_str    = param("ko");
    my $taxon_oid = param("taxon_oid");
    my $gene_oid  = param("gene_oid");

    my $dbh = dbLogin();
    my $rclause = urClause("t.taxon_oid");
    my $sql = "select t.taxon_oid, t.taxon_display_name, t.in_file " .
 	      "from taxon t where t.taxon_oid = ? " . $rclause;
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_oid, $taxon_name, $in_file) = $cur->fetchrow();
    $cur->finish();

    if ( $in_file eq 'Yes' ) {
	## different method for MER-FS
	printKeggMapTaxonGenesKo_fs($taxon_oid, $taxon_name, $map_id,
				    $ko_str, $gene_oid);
	return;
    }

    my $text;
    my $gene;
    my $gene_oid_clause;
    if ( $gene_oid ne "" ) {
	$text = "Other ";
	$gene_oid_clause = "and g.gene_oid != ?";

	my $sql = qq{
	    select distinct g.gene_display_name, g.locus_tag
	    from gene g where g.gene_oid = ?
	};
	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
	my ($name, $locus) = $cur->fetchrow();
	$cur->finish();

        my $urlg = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gene_oid";
	$gene = "<br/>Current Gene: "
	    . alink( $urlg, "$gene_oid [$locus]");
    }

    my $urlt = "$main_cgi?section=TaxonDetail"
    	. "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<h1>$text"."Genes with KO: <font color='darkblue'>"
	. "<u>$ko_str</u></font></h1>\n";
    print "<p>Current Genome: ".alink($urlt, $taxon_name)."$gene</p>";

    my @ko = split(",", $ko_str);
    $ko_str = joinSqlQuoted(",", @ko);
    $ko_str =~ s/KO://;
    my $sql = qq{
      select distinct g.gene_oid, g.gene_display_name, g.locus_tag,
             iroi.roi_label
        from image_roi_ko_terms irk, gene_ko_terms gk, gene g,
	     image_roi iroi, kegg_pathway pw
       where pw.image_id = ?
         and irk.roi_id = iroi.roi_id
         and iroi.roi_type in ('ko_term', 'enzyme')
	 and irk.ko_terms = gk.ko_terms
	 and gk.gene_oid = g.gene_oid
	 and iroi.pathway = pw.pathway_oid
	 and g.taxon = ?
	 and iroi.roi_label in ($ko_str)
	 and g.obsolete_flag = 'No'
	 $gene_oid_clause
    };
    my $cur;
    if ( $gene_oid ne "" ) {
        $cur = execSql
            ( $dbh, $sql, $verbose, $map_id, $taxon_oid, $gene_oid );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $map_id, $taxon_oid );
    }

    printMainForm();

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",   "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "KO",        "asc", "left"  );

    my $count = 0;
    for ( ;; ) {
        my ( $gene_oid, $name, $locus_tag, $ko )
            = $cur->fetchrow();
        last if !$gene_oid;

        my $url1 = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gene_oid";
        my $url2 = "$ko_base_url$ko";

        my $row = $sd."<input type='checkbox' "
            . "name='gene_oid' value='$gene_oid'/>\t";
        $row .= $gene_oid.$sd.alink($url1, $gene_oid)."\t";
        $row .= $locus_tag.$sd.$locus_tag."\t";
        $row .= $name.$sd.$name."\t";
        $row .= $ko.$sd.alink($url2, $ko)."\t";
        $it->addRow($row);
	$count++;
    }
    $cur->finish();

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
}


############################################################################
# printKeggMapTaxonGenesKo_fs - prints the genes with the given ko number
# (MER-FS version)
############################################################################
sub printKeggMapTaxonGenesKo_fs {
    my ($taxon_oid, $taxon_name, $map_id, $ko_str, $workspace_id) = @_;

    my $gene = "";
    if ( $workspace_id ) {
	my ($t2, $d2, $gene_oid) = split(/ /, $workspace_id);
	my $locus = $gene_oid;

	my ($name, $source) =
	    MetaUtil::getGeneProdNameSource($gene_oid, $t2, $d2);

	my $urlg = "$main_cgi?section=MetaGeneDetail" .
	           "&page=metaGeneDetail&gene_oid=$gene_oid" .
		   "&taxon_oid=$t2&data_type=$d2";
	my $gene = "<br/>Current Gene: " . alink( $urlg, "$gene_oid");
    }

    my $urlt = "$main_cgi?section=MetaDetail"
    	     . "&page=metaDetail&taxon_oid=$taxon_oid";
    print "<h1>Other Genes with <font color='darkblue'>"
	. "<u>$ko_str</u></font></h1>\n";
    print "<p>Current Genome: ".alink($urlt, $taxon_name)."$gene</p>";

    my @kos = split(",", $ko_str);

    printMainForm();

    printStatusLine( "Loading ...", 1 );
    printStartWorkingDiv();

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",   "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "KO", "asc", "left"  );

    my $select_id_name = "gene_oid";

    my $trunc = 0;
    my %genes;
    $genes{$workspace_id} = 1;
    my $count = 0;

    for my $ko ( @kos ) {
    	if ( $trunc ) {
    	    last;
    	}
    	print "<p>Retrieving $ko genes ...\n";

        my %ko_genes = MetaUtil::getTaxonFuncGenes($taxon_oid, "both", $ko);
	for my $gene_oid (keys %ko_genes) {
	    if ( $count >= $maxGeneListResults ) {
		$trunc = 1;
		last;
	    }

	    my $locus_tag = $gene_oid;

	    my $ws_id = $ko_genes{$gene_oid};
	    if ( $genes{$ws_id} ) {
		# duplicated
		next;
	    }
	    else {
		$genes{$ws_id} = 1;
	    }

	    my ($t3, $d3, $g3) = split(/ /, $ws_id);
	    my $url1 = "$main_cgi?section=MetaGeneDetail" .
		       "&page=metaGeneDetail&gene_oid=$g3" .
		       "&taxon_oid=$t3&data_type=$d3";
	    my $url2 = "$ko_base_url$ko";
	    my ($name, $source) = MetaUtil::getGeneProdNameSource($g3, $t3, $d3);
	    my $row = $sd."<input type='checkbox' " .
		      "name='$select_id_name' value='$ws_id'/>\t";
	    $row .= $ws_id.$sd.alink($url1, $gene_oid)."\t";
	    $row .= $locus_tag.$sd.$locus_tag."\t";
	    $row .= $name.$sd.$name."\t";
	    $row .= $ko.$sd.alink($url2, $ko)."\t";
	    $it->addRow($row);

	    $count++;
	    if ( ($count % 10) == 0 ) {
		print ".";
	    }
	    if ( ($count % 1800) == 0 ) {
		print "<br/>";
	    }
	}
    }

    printEndWorkingDiv();

    if ( ! $count ) {
    	print "<p><b>No genes have been foud.</b>\n";
    	print end_form();
    	return;
    }

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    if ( $count > 0 ) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to "
          . alink( $preferences_url, "Preferences" )
          . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) loaded", 2 );
    }

    print end_form();
}


############################################################################
# printMyIMGKeggMapTaxonGenes - Print genes related to same taxon for EC num
#  (Blue box selected).
############################################################################
sub printMyIMGKeggMapTaxonGenes {
    my $map_id    = param("map_id");
    my $ec_str    = param("ec_number");
    my $taxon_oid = param("taxon_oid");
    my $gene_oid  = param("gene_oid");

    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError("Session expired. Please start over again.");
    }
    my $dbh = dbLogin();
    my ( $taxon_oid, $taxon_name ) =
        getTaxonRecByTaxonOid( $dbh, $taxon_oid );
    print "<h1>Genes with EC: <font color='darkblue'>"
        . "<u>$ec_str</u></font></h1>\n";

    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p>Current Genome: ".alink($url, $taxon_name)."</p>";

    my @ec = split(",", $ec_str);
    $ec_str = joinSqlQuoted(",", @ec);

    my $gene_oid_clause;
    $gene_oid_clause = "and g.gene_oid != ?" if $gene_oid ne "";

    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name, g.locus_tag,
               iroi.roi_label
        from image_roi_ko_terms irkt, ko_term_enzymes kte,
             gene_myimg_enzymes gme, gene g,
             image_roi iroi, kegg_pathway pw
        where pw.image_id = ?
        and iroi.roi_id = irkt.roi_id
        and iroi.roi_type in ('ko_term', 'enzyme')
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = gme.ec_number
        and gme.gene_oid = g.gene_oid
        and gme.modified_by = ?
        and iroi.pathway = pw.pathway_oid
        and g.taxon = ?
        and iroi.roi_label in ($ec_str)
        and g.obsolete_flag = 'No'
        $gene_oid_clause
    };
    my $cur;
    if ( $gene_oid ne "" ) {
        $cur = execSql
            ( $dbh, $sql, $verbose, $map_id,
	      $contact_oid, $taxon_oid, $gene_oid );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $map_id,
			$contact_oid, $taxon_oid );
    }

    printMainForm();

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",   "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "EC",        "asc", "left"  );

    my $count = 0;
    for ( ;; ) {
        my ( $gene_oid, $name, $locus_tag, $ec )
            = $cur->fetchrow();
        last if !$gene_oid;

        my $url1 = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gene_oid";
        my $url2 = "$ec_base_url"."EC:$ec";

        my $row = $sd."<input type='checkbox' "
            . "name='gene_oid' value='$gene_oid'/>\t";
        $row .= $gene_oid.$sd.alink($url1, $gene_oid)."\t";
        $row .= $locus_tag.$sd.$locus_tag."\t";
        $row .= $name.$sd.$name."\t";
        $row .= $ec.$sd.alink($url2, $ec)."\t";
        $it->addRow($row);
	$count++;
    }
    $cur->finish();

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
}

############################################################################
# printKeggMapEcEquivGenes  - Print EC equivalog coordinate genes.
#   Include orthologs to equivalogs.  (Orange box selected).
############################################################################
sub printKeggMapEcEquivGenes {
    my $map_id    = param("map_id");
    my $ec_number = param("ec_number");
    my $taxon_oid = param("taxon_oid");
    my $gene_oid  = param("gene_oid");

    my $roi_label = $ec_number;
    $roi_label =~ s/^EC://;
    my $gene_oid_clause;
    $gene_oid_clause = "and g.gene_oid != ?"
      if $gene_oid ne "";

    my $sql = qq{
        select distinct g.gene_oid, g.taxon
        from image_roi_ko_terms irkt, ko_term_enzymes kte,
             gene_ko_enzymes ge, gene g,
             image_roi iroi, kegg_pathway pw
        where pw.image_id = ?
        and iroi.roi_id = irkt.roi_id
        and iroi.roi_type in ('ko_term', 'enzyme')
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = ge.enzymes
        and ge.gene_oid = g.gene_oid
        and iroi.pathway = pw.pathway_oid
        and g.taxon != ?
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        and iroi.roi_label = ?
        $gene_oid_clause
    };

    my $dbh = dbLogin();
    my %validTaxons = WebUtil::getAllTaxonsHashed($dbh);

    my $cur;
    if ( $gene_oid ne "" ) {
        $cur = execSql
	    ( $dbh, $sql, $verbose, $map_id, $taxon_oid,
	      $roi_label, $gene_oid );
    } else {
        $cur = execSql
	    ( $dbh, $sql, $verbose, $map_id, $taxon_oid, $roi_label );
    }

    my @gene_oids;
    my $rowCount    = 0;
    for ( ; ; ) {
        my ( $gene_oid, $taxon ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $validTaxons{$taxon} eq "";
        push( @gene_oids,     $gene_oid );
        $rowCount++;
    }
    $cur->finish();

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>\n";
    print "Genes found in other genomes\n";
    print "</h1>\n";
    print "<p>\n";
    print "Genes with the same EC number found in other genomes\n";
    print "</p>\n";

    printGeneCartFooter() if $rowCount > 10;
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    printStatusLine( "$rowCount gene(s) retrieved", 2 );
    print end_form();
}

############################################################################
# printKeggMapKoEquivGenes - prints the genes with the given ko numbers
############################################################################
sub printKeggMapKoEquivGenes {
    my $map_id    = param("map_id");
    my $ko_str    = param("ko");
    my $taxon_oid = param("taxon_oid");
    my $gene_oid  = param("gene_oid");

    my $dbh = dbLogin();
    my $url = "$main_cgi?section=TaxonDetail"
        . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my ( $taxon_oid, $taxon_name ) =
        getTaxonRecByTaxonOid( $dbh, $taxon_oid );
    print "<h1>Genes with KO: <font color='darkblue'>"
	. "<u>$ko_str</u></font> found in other genomes</h1>\n";
    print "<p>Current Genome: ".alink($url, $taxon_name)."</p>";

    my @ko = split(",", $ko_str);
    $ko_str = joinSqlQuoted(",", @ko);
    $ko_str =~ s/KO://;

    my $gene_oid_clause;
    $gene_oid_clause = "and g.gene_oid != ?" if $gene_oid ne "";

    my $sql = qq{
	select distinct g.gene_oid, g.gene_display_name,
	       g.locus_tag, g.taxon, tx.taxon_name, iroi.roi_label
	  from image_roi_ko_terms irk, gene_ko_terms gk, gene g,
	       image_roi iroi, kegg_pathway pw, taxon tx
	 where pw.image_id = ?
	   and irk.roi_id = iroi.roi_id
           and iroi.roi_type in ('ko_term', 'enzyme')
	   and irk.ko_terms = gk.ko_terms
	   and gk.gene_oid = g.gene_oid
	   and iroi.pathway = pw.pathway_oid
	   and g.taxon != ?
	   and g.taxon = tx.taxon_oid
	   and g.locus_type = 'CDS'
	   and g.obsolete_flag = 'No'
	   and iroi.roi_label in ($ko_str)
	   $gene_oid_clause
       };

    my $dbh = dbLogin();
    my $cur;
    if ( $gene_oid ne "" ) {
        $cur = execSql
	    ( $dbh, $sql, $verbose, $map_id, $taxon_oid, $gene_oid );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $map_id, $taxon_oid );
    }

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my %validTaxons = WebUtil::getAllTaxonsHashed($dbh);

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",   "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left"  );
    $it->addColSpec( "Gene Product Name", "asc", "left"  );
    $it->addColSpec( "Genome",    "asc", "left"  );
    $it->addColSpec( "KO",        "asc", "left"  );

    my $count = 0;
    for ( ;; ) {
        my ( $gene_oid, $name, $locus_tag, $taxon_oid, $taxon_name, $ko )
            = $cur->fetchrow();
        last if !$gene_oid;
        next if $validTaxons{$taxon_oid} eq "";

        my $url1 = "$main_cgi?section=GeneDetail"
            . "&page=geneDetail&gene_oid=$gene_oid";
        my $url2 = "$main_cgi?section=TaxonDetail"
            . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $url3 = "$ko_base_url$ko";

        my $row = $sd."<input type='checkbox' "
            . "name='gene_oid' value='$gene_oid'/>\t";
        $row .= $gene_oid.$sd.alink($url1, $gene_oid)."\t";
        $row .= $locus_tag.$sd.$locus_tag."\t";
        $row .= $name.$sd.$name."\t";
        $row .= $taxon_name.$sd.alink($url2, $taxon_name)."\t";
        $row .= $ko.$sd.alink($url3, $ko)."\t";
        $it->addRow($row);
	$count++;
    }
    $cur->finish();

    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();

    printStatusLine( "$count gene(s) retrieved", 2 );
    print end_form();
}

############################################################################
# printKeggPathwayDetailLink - Show KEGG detail link.
############################################################################
sub printKeggPathwayDetailLink {
    my ( $dbh, $map_id ) = @_;

    my $sql = qq{
       select pathway_oid
       from kegg_pathway
       where image_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $map_id );
    my $pathway_oid = $cur->fetchrow();
    $cur->finish();

    return if !$pathway_oid;
    my $url = "$main_cgi?section=KeggPathwayDetail&page=keggPathwayDetail";
    $url .= "&pathway_oid=$pathway_oid";
    print "<p>\n";
    print alink( $url, "Pathway Details" );
    print "</p>\n";
}

1;
