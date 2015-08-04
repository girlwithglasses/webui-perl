############################################################################
#
# $Id: MyGeneDetail.pm 33027 2015-03-19 17:50:11Z imachen $
############################################################################
package MyGeneDetail;
my $section = "MyGeneDetail";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;
use GeneDetail;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $img_internal         = $env->{img_internal};
my $tmp_dir              = $env->{tmp_dir};
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $show_private         = $env->{show_private};
my $content_list         = $env->{content_list};
my $web_data_dir         = $env->{web_data_dir};
my $nvl                  = getNvl();

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {

    my $page = param("page");
    if ( $page eq "geneDetail" ) {
        printGeneDetail();
    } elsif ( $page eq "aa_seq" ) {
        printAminoAcidSeq();
    } elsif ( $page eq "seq" ) {
        printSeq();
    }
}

sub checkMyGeneAccess {
    my ( $dbh, $mygene_oid ) = @_;

    my $contact_oid = getContactOid();
    my $super_user = getSuperUser();
    return 1 if $super_user eq "Yes";

    my $sql = qq{
      select mg.modified_by, mg.is_public, c.img_group, mg.taxon
      from mygene mg, contact c
      where mg.mygene_oid = ?
      and mg.modified_by = c.contact_oid
    };
    my @a = ($mygene_oid);
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ( $coid, $is_public, $group, $t_oid ) = $cur->fetchrow();
    $cur->finish();

    checkTaxonPerm($dbh, $t_oid);

    if ( $is_public eq 'Yes' ) {
	return 1;
    }

    if ( $contact_oid eq $coid ) {
        return 1;
    }

    # now check group access
    # get user's group
    my $sql = qq{
        select count(*)
        from contact_img_groups\@imgsg_dev cig, 
             mygene_img_groups\@img_ext mig
        where cig.contact_oid = ?
        and cig.img_group = mig.group_id
        and mig.mygene_oid = ?
    };
    my @a            = ($contact_oid, $mygene_oid);
    my $cur          = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($group_cnt) = $cur->fetchrow();
    $cur->finish();

    if ( $group_cnt > 0 ) {
        return 1;
    }

    return 0;
}

sub printGeneDetail {
    my ($gene_oid) = @_;

    $gene_oid = param("gene_oid") if $gene_oid eq "";

    if ( blankStr($gene_oid) ) {
        webError("No Gene ID specified.");
    }
    print "<h1>My Gene Detail</h1>\n";
    my $dbh = dbLogin();

    my $suc = checkMyGeneAccess( $dbh, $gene_oid );
    if ( $suc == 0 ) {
        webError("You do not have access to this page!");
        return;
    }

    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
      select mg.mygene_oid, mg.gene_symbol, mg.gene_display_name, 
      mg.product_name, mg.ec_number ,mg.locus_type, mg.locus_tag, 
      mg.dna_coords, mg.strand,
      mg.aa_seq_length, mg.is_pseudogene, t.taxon_display_name,
      t.taxon_oid, mg.scaffold, mg.hitgene_oid, mg.is_public,
      mg.replacing_gene
      from mygene mg, taxon t
      where mg.mygene_oid = ?
      and mg.taxon = t.taxon_oid
    };

    my @a = ($gene_oid);
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my (
        $mygene_oid,   $gene_symbol,   $gene_display_name,
        $product_name, $ec_number,     $locus_type,
        $locus_tag,    $dna_coords,
        $strand,       $aa_seq_length, $is_pseudogene,
        $taxon_name,   $taxon_oid,     $scaffold, $hitgene_oid, 
	$is_public, $replacing_gene
      )
      = $cur->fetchrow();
    $cur->finish();

    my ($s1, $e1, $partial_gene, $msg1) = WebUtil::parseDNACoords($dna_coords);

    print WebUtil::getHtmlBookmark( "information",
        "<h2>Gene Information</h2>" );
    print "<table class='img' border='1'>\n";
    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Gene Information</th>\n";
    print "</font>\n";
    print "<td class='img'>" . nbsp(1) . "</td>\n";
    print "</tr>\n";

    GeneDetail::printAttrRowRaw( "Gene ID", $gene_oid );
    GeneDetail::printAttrRowRaw( "Gene Symbol",    nbspWrap($gene_symbol) );
    GeneDetail::printAttrRowRaw( "Locus Type",      $locus_type );
    GeneDetail::printAttrRowRaw( "Locus Tag",      $locus_tag );
    GeneDetail::printAttrRowRaw( "Product Name", escHtml($product_name) );

    if ( $is_pseudogene ) {
	GeneDetail::printAttrRowRaw( "Is Pseudogene?",
				     escHtml($is_pseudogene) );
      }

    my $url =
        "$main_cgi?section=TaxonDetail"
      . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $link = alink( $url, $taxon_name );
    GeneDetail::printAttrRowRaw( "Genome", $link );

    my ( $scaffold_name, $seq_len, $scaffold_file ) =
      getScaffoldName( $dbh, $scaffold );


    my $start_coord = 0; 
    my $end_coord = 0; 
    my $dna_seq = getMyGeneSeq($dbh, $gene_oid, $scaffold, $dna_coords, $strand);
    my $dna_seq_length = length($dna_seq);

    my $sign = "pos";
    $sign = "neg" if($strand eq "-");
    my $url            =
        $section_cgi
      . "&page=seq&taxon_oid=$taxon_oid"
      . "&gene_oid=$mygene_oid";
#      . "&scaffold_oid=$scaffold"
#      . "&start=$start_coord"
#      . "&end=$end_coord"
#      . "&strand=$sign";

    $url = alink( $url, $dna_seq_length . "bp" );
    my $dna_coord_disp = $dna_coords;
    if ( ! $dna_coord_disp ) {
        $dna_coord_disp = "$start_coord..$end_coord";
    }
    my $partial_gene_msg = "";
    if ( $partial_gene ) {
	$partial_gene_msg = " -- partial gene";
    }
    GeneDetail::printAttrRowRaw( "DNA Coordinates",
        "$dna_coord_disp ($strand)($url) $partial_gene_msg" );
#    GeneDetail::printAttrRowRaw( "DNA Coordinates",      $dna_coords );
#    GeneDetail::printAttrRowRaw( "Strand",      $strand );

    my $url =
      GeneDetail::getScaffoldUrl( $mygene_oid, $start_coord, $end_coord,
        $scaffold, $seq_len );

    $url = alink( $url, $scaffold_name );
    GeneDetail::printAttrRowRaw( "Scaffold Source", $url );

    GeneDetail::printAttrRowRaw( "Is Public?",      $is_public );

    if ($replacing_gene) {
	my $r = "";
	my @old_genes = split(/\,/, $replacing_gene);
	for my $g2 ( @old_genes ) {
	    $g2 = strTrim($g2); 
	    if ( $g2 && isInt($g2) ) { 
		my $url = "$main_cgi?section=GeneDetail"
		    . "&page=geneDetail&gene_oid=$g2"; 
		$r .= alink( $url, $g2 ) . "<br/>";
	    }
	}  # end for g2

	GeneDetail::printAttrRowRaw( "Replacing Gene(s)", $r );
    }

    $sql = qq{
           select g.gene_oid from gene g
           where g.gene_oid = ?
           and g.obsolete_flag = 'No'
           };
    $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    my ($id_in_gene_table) = $cur->fetchrow();
    $cur->finish();
    if ( $id_in_gene_table ) {
	my $url3 = "$main_cgi?section=GeneDetail"
	    . "&page=geneDetail&gene_oid=$id_in_gene_table"; 
	GeneDetail::printAttrRowRaw( "Added in IMG?", 
				     "Yes -- " . alink($url3, $id_in_gene_table) );
    }
    else {
	GeneDetail::printAttrRowRaw( "Added in IMG?", "No" );
    }

    # protein info
    my $dna_seq = getMyGeneSeq($dbh, $gene_oid, $scaffold, $dna_coords, $strand);
    printProtein($dbh, $mygene_oid, $hitgene_oid, $dna_seq);

    print "</table>\n";

    $sql = qq{
           select g.mygene_oid, g.term_oid, t.term, g.evidence, g.mod_date
           from mygene_terms g, img_term t
           where g.mygene_oid = ?
           and g.term_oid = t.term_oid
           };
    my $cur = execSql( $dbh, $sql, $verbose, $mygene_oid );
    my $is_first = 1;

    for (;;) {
	my ($gid2, $term_oid, $term, $evidence, $mod_date) = $cur->fetchrow();
	last if ! $gid2;

	if ( $is_first ) {
	    $is_first = 0;
	    print "<h5>Associated IMG Term(s)</h5>\n";
	    print "<table class='img'>\n";
	    print "<th class='img'>Term ID</th>\n";
	    print "<th class='img'>Term</th>\n";
	    print "<th class='img'>Evidence</th>\n";
	    print "<th class='img'>Mod Date</th>\n";
	}

	my $func_id = "ITERM:" . $term_oid;
	print "<tr class='img'>\n";
	my $url = "$main_cgi?section=ImgTermBrowser" . 
	    "&page=imgTermDetail&term_oid=$term_oid"; 
	print "<td class='img'>" . alink($url, $func_id) . "</td>\n";
	print "<td class='img'>" . $term . "</td>\n";
	print "<td class='img'>" . $evidence . "</td>\n";
	print "<td class='img'>" . $mod_date . "</td>\n";
	print "</tr>\n";
    }
    $cur->finish();

    if ( ! $is_first ) {
	print "</table>\n";
    }

    # $dbh, $gene_oid, $cassette_oid, $mygene_oid
    GeneDetail::printFuncEvidence( $dbh, $gene_oid, "", $gene_oid, $hitgene_oid );

    print "</table>\n";
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

sub printProtein {
    my($dbh, $mygene_oid, $hitgene_oid, $seq) = @_;

    if ( ! $hitgene_oid && ! $seq ) {
	return;
    }

    if ( $seq ) {
	print "<tr class='highlight'>\n";
	print "<th class='subhead' align='center'>";
	print "<font color='darkblue'>\n";
	print "Protein Information</th>\n";
	print "</font>\n";
	print "<td class='img'> </td>\n";
	print "</tr>\n";

	#GeneDetail::printAttrRowRaw( "DNA Sequence", "todo get dna seq" );
        #GeneDetail::printAttrRowRaw("print seq", $seq );

	my $aa_seq = WebUtil::getaa($seq);
	my $url2 = $section_cgi
	    . "&page=aa_seq&gene_oid=$mygene_oid";
	$url2 = alink($url2, length($aa_seq) . "aa");
	GeneDetail::printAttrRowRaw( "Amino Acid Sequence Length", $url2);
    }

    if ( ! $hitgene_oid ) {
	return;
    }

    print "<tr class='highlight'>\n";
    print "<th class='subhead' align='center'>";
    print "<font color='darkblue'>\n";
    print "Hit Gene Protein Information ** </th>\n";
    print "</font>\n";
    my $url = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=$hitgene_oid";
    $url = alink($url, $hitgene_oid);
    print "<td class='img'> Hit Gene ID: " . $url . "</td>\n";
    print "</tr>\n";

    GeneDetail::printCogName( $dbh, $hitgene_oid );
    
    if($img_internal){
	GeneDetail::printCogFuncDefn( $dbh, $hitgene_oid );
    }
    
    GeneDetail::printImgTerms( $dbh, $hitgene_oid );
    #GeneDetail::printGeneXrefFamilies( $dbh, $hitgene_oid );
    #GeneDetail::printStructureXref( $dbh, $hitgene_oid );
    #GeneDetail::printTmHmm( $dbh, $hitgene_oid );
    #GeneDetail::printSignalp( $dbh, $hitgene_oid );
    
    GeneDetail::printProteinPfam($dbh, $hitgene_oid);
    
    if($img_internal){
	GeneDetail::printTigrfamsMainRole($dbh, $hitgene_oid);
    }
}

sub getMyGeneSeq {
    my ($dbh, $gene_oid, $scaffold_oid, $dna_coords, $strand) = @_;

    my ( $scaffold_name, $seq_len, $scaffold_file ) =
      getScaffoldName( $dbh, $scaffold_oid );

    my $suc = checkMyGeneAccess( $dbh, $gene_oid );
    if ( $suc == 0 ) {
        return "";
    }

    my $seq;
    if ( $dna_coords ) { 
	my @coords = split(/\,/, $dna_coords); 
	for my $coord2 ( @coords ) {
	    my ($s2, $e2) = split(/\.\./, $coord2);

	    if ( $s2 =~ /^\</ ) {
		# partial gene
		$s2 = substr($s2, 1);
	    }
	    if ( $e2 =~ /^\>/ ) { 
		# partial gene
		$e2 = substr($e2, 1);
	    } 

	    if ( isInt($s2) && $s2 > 0 && isInt($e2) && $e2 > 0 ) {
		if ( $strand eq "neg" || $strand eq "-" ) {
		    my $seq2 = getScaffoldSeq($dbh, $scaffold_oid, $e2, $s2);   
                    $seq = $seq2 . $seq;
		}
		else {
		    my $seq2 = getScaffoldSeq($dbh, $scaffold_oid, $s2, $e2);   
                    $seq .= $seq2; 
		}
	    }
	}
    } 

    return $seq;
}

sub printAminoAcidSeq {
    my $gene_oid     = param("gene_oid");

    print "<h1>My Gene Amino Acid Sequence</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $suc = checkMyGeneAccess( $dbh, $gene_oid );
    if ( $suc == 0 ) {
	#$dbh->disconnect();
        webError("You do not have access to this page!");
        return;
    }

    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
      select mg.mygene_oid, mg.gene_symbol, mg.gene_display_name, 
      mg.product_name, mg.ec_number ,mg.locus_type, mg.locus_tag, 
      mg.dna_coords, mg.strand,
      mg.aa_seq_length, mg.is_pseudogene, t.taxon_display_name,
      t.taxon_oid, mg.scaffold, mg.hitgene_oid, mg.is_public
      from mygene mg, taxon t
      where mg.mygene_oid = ?
      and mg.taxon = t.taxon_oid
    };

    my @a = ($gene_oid);
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my (
        $mygene_oid,   $gene_symbol,   $gene_display_name,
        $product_name, $ec_number,     $locus_type,
        $locus_tag,    $dna_coords,
        $strand2,       $aa_seq_length, $is_pseudogene,
        $taxon_name,   $taxon_oid,     $scaffold, $hitgene_oid, $is_public
      )
      = $cur->fetchrow();
    $cur->finish();

    my ( $scaffold_name, $seq_len, $scaffold_file ) =
      getScaffoldName( $dbh, $scaffold );

    my $seq = getMyGeneSeq($dbh, $gene_oid, $scaffold, $dna_coords, $strand2);
    my $aa_seq = WebUtil::getaa($seq);
    $aa_seq = wrapSeq($aa_seq);
    print "<pre>\n";

    print "<font color='blue'>\>$mygene_oid $product_name [$taxon_name]</font>\n";
    print "$aa_seq ";
    print "</pre>\n";
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

sub printSeq {
    my $gene_oid     = param("gene_oid");

    print "<h1>My Gene Detail DNA Sequence</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $suc = checkMyGeneAccess( $dbh, $gene_oid );
    if ( $suc == 0 ) {
	#$dbh->disconnect();
        webError("You do not have access to this page!");
        return;
    }

    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
      select mg.mygene_oid, mg.gene_symbol, mg.gene_display_name, 
      mg.product_name, mg.ec_number ,mg.locus_type, mg.locus_tag, 
      mg.dna_coords, mg.strand,
      mg.aa_seq_length, mg.is_pseudogene, t.taxon_display_name,
      t.taxon_oid, mg.scaffold, mg.hitgene_oid, mg.is_public
      from mygene mg, taxon t
      where mg.mygene_oid = ?
      and mg.taxon = t.taxon_oid
    };

    my @a = ($gene_oid);
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my (
        $mygene_oid,   $gene_symbol,   $gene_display_name,
        $product_name, $ec_number,     $locus_type,
        $locus_tag,    $dna_coords,
        $strand2,       $aa_seq_length, $is_pseudogene,
        $taxon_name,   $taxon_oid,     $scaffold, $hitgene_oid, $is_public
      )
      = $cur->fetchrow();
    $cur->finish();

    my ( $scaffold_name, $seq_len, $scaffold_file ) =
      getScaffoldName( $dbh, $scaffold );

    #my $seq = getSeq( $taxon_oid, $start, $end, $scaffold_file, $strand );
    my $seq = getMyGeneSeq($dbh, $gene_oid, $scaffold, $dna_coords, $strand2);
    $seq = wrapSeq($seq);
    print "<pre>\n";

#    print "$scaffold_name <br/>  $start .. $end ($strand2) <br/>\n";
    
    print "<font color='blue'>\>$mygene_oid $product_name [$taxon_name] ($strand2)</font>\n";
    
    print "$seq ";
    print "</pre>\n";
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

# gets name and length
sub getScaffoldName {
    my ( $dbh, $soid ) = @_;

    my $sql = qq{
        select s.scaffold_name, ss.seq_length, s.seq_file 
        from scaffold s, scaffold_stats ss
        where s.scaffold_oid = ?
        and s.scaffold_oid = ss.scaffold_oid
    };
    my @a = ($soid);
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ( $name, $seq_len, $file ) = $cur->fetchrow();
    $cur->finish();
    return ( $name, $seq_len, $file );
}

# taxon oid
# start coord
# end coord
# fna file
# - old way forgot to consider contigs in file 
sub getSeq {
    my ( $taxon_oid, $start, $end, $filename, $strand ) = @_;

    my $file = "$web_data_dir/all.fna.files/$taxon_oid/$filename";

    if ( !-e $file ) {
        webLog("Seq filename $file\n");
        webError(
            "Cannot file sequence file all.fna.files/$taxon_oid/$filename");
        return;
    }

    my $fh  = newReadFileHandle($file);
    my $seq = "";

    # number of characters read so far
    my $count = 0;

    # read seq from 1 to eol - end of line is greater than end and start
    while ( my $line = $fh->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        next if ( $line =~ /^>/ );

        my $len = length($line);
        $count += $len;
        $seq .= $line;
        if ( $count > ($start) && $count > ($end) ) {
            last;
        }
    }
    close $fh;

    my $orig_seq = "";
    if ( $strand eq "pos" ) {
        my $range = $end - $start + 1;
        $orig_seq = substr( $seq, $start - 1, $range );
    } else {
        # the db stores start < end all the time!
        my $range = $end - $start + 1;
        $orig_seq = substr( $seq, $start - 1, $range );

        $orig_seq = reverse($orig_seq);
        $orig_seq =~ tr/actgACTG/tgacTGAC/;
    }
    return $orig_seq;

}

1;
