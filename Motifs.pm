###########################################################################
# Motifs.pm  
# $Id: Motifs.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package Motifs; 
my $section = "Motifs"; 
 
use strict; 
use CGI qw( :standard ); 
use Data::Dumper; 
use Sequence;
use StaticInnerTable;
use WebConfig; 
use WebUtil; 
 
my $env         = getEnv(); 
my $main_cgi    = $env->{main_cgi}; 
my $section_cgi = "$main_cgi?section=$section"; 
my $inner_cgi   = $env->{inner_cgi}; 
my $verbose     = $env->{verbose}; 
my $base_dir    = $env->{base_dir}; 
my $base_url    = $env->{base_url}; 
my $nvl         = getNvl();
my $pageSize    = 1000;
 
############################################################################
# printMotifs - prints unique motifs for a specified sample and experiment
############################################################################
sub printFindMotifsScript {
    print "<script src='$base_url/overlib.js'></script>\n";
    print qq{ 
        <script language='JavaScript' type='text/javascript'> 
        function findMotif (name) { 
            var els = document.getElementsByName('motif');
            for (var i=0; i < els.length; i++) {
                var el = els[i];
                if (!el) continue;
                try {
                    var val = el.getAttribute("value");
                    if (!val) continue;
		    if (val == name) {
                        //el.bgColor = 'fuchsia';
                        el.bgColor = '#FF66FF';
                    } else {
		        el.bgColor = 'silver';
		        cClick(); // closes the sticky popup
                    }
                } catch(e) {
                    //alert("exception: "+e);
                }
            }
        } 
        </script> 
    };
}

############################################################################
# findGenes - finds all genes on the specified sequence so as to mark them
############################################################################
sub findGenes {
    my ($dbh, $seq, $scaffold_oid, $start_coord, $end_coord, $strand0) = @_;
    my $len = length( $seq );

    my $sql = qq{
        select distinct g.gene_oid, g.start_coord, g.end_coord, g.strand
        from scaffold s, gene g
        where g.scaffold = s.scaffold_oid
        and s.scaffold_oid = ?
        and g.end_coord > ?
        and g.start_coord < ? 
        and g.start_coord > 0
        and g.end_coord > 0
        and g.obsolete_flag = 'No'
        and s.ext_accession is not null
        order by g.start_coord
    };
    #and g.start_coord >= ? and g.end_coord <= ?
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid, 
		       $start_coord, $end_coord );

    my %h;
    for ( ;; ) {
        my ( $gene_oid, $start, $end, $strand ) = $cur->fetchrow();
        last if !$gene_oid;
	next if ($strand ne $strand0);

	for ( my $i = $start; $i <= $end; $i++ ) {
	    $h{$i} = "gene";
	}
    }

    return %h;
}
############################################################################
# findMotifs - finds the motifs on the specified sequence so as 
#              to mark each coordinate
############################################################################
sub findMotifs {
    my ($seq, $motifs_ref, $strand) = @_;
    my $len = length( $seq );
    my @motifs = @$motifs_ref;

    my %h;
    MOTIF: foreach my $motif_info (@motifs) {
	my ($motif, $text) = split(/\t/, $motif_info);
	my $motif_len = length( $motif );

	my $motif2 = $motif;
	if ($strand eq "-") {
	    $motif2 = reverse $motif;
	}

	SEQ: for ( my $i = 0; $i < $len; $i++ ) {
	    my $seq2 = substr( $seq, $i, $motif_len );
	    if ($strand eq "-") {
		$seq2 =~ tr/actgACTG/tgacTGAC/;
	    }

	    my @seq_chars = split("", $seq2);
	    my @motif_chars = split("", $motif2);

	    my $found = 0;
	    if ( $motif2 eq $seq2 ) {
		$found = 1;
	    } else {
		CHAR: foreach ( my $j = 0; $j < $motif_len; $j++ ) {
		    if ($motif_chars[$j] =~ /[ATGC]/) {
			next SEQ if ($motif_chars[$j] ne $seq_chars[$j]);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "N") {
			# N can be any base
			next CHAR;
		    } elsif ($motif_chars[$j] eq "R") {
			# R can be A or G
			next SEQ if ($seq_chars[$j] !~ /[AG]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "W") {
			# W can be A or T
			next SEQ if ($seq_chars[$j] !~ /[AT]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "Y") {
			# Y can be C or T
			next SEQ if ($seq_chars[$j] !~ /[CT]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "S") {
			# S can be G or C
			next SEQ if ($seq_chars[$j] !~ /[GC]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "K") {
			# K can be G or T
			next SEQ if ($seq_chars[$j] !~ /[GT]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "M") {
			# M can be A or C
			next SEQ if ($seq_chars[$j] !~ /[AC]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "B") {
			# B can be C or G or T
			next SEQ if ($seq_chars[$j] !~ /[CGT]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "D") {
			# D can be A or G or T
			next SEQ if ($seq_chars[$j] !~ /[AGT]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "H") {
			# H can be A or C or T
			next SEQ if ($seq_chars[$j] !~ /[ACT]/);
			next CHAR;
		    } elsif ($motif_chars[$j] eq "V") {
			# V can be A or C or G
			next SEQ if ($seq_chars[$j] !~ /[ACG]/);
			next CHAR;
		    }
		}
		$found = 1;
	    }

	    if ( $found ) {
		foreach ( my $j = 0; $j < $motif_len; $j++ ) {
		    $h{$i++} = "motif\t$motif\t$text";
		}
	    }
	}
    }
    return %h;
}

############################################################################
# selectScaffolds - gets the sequence for the scaffold to display
############################################################################
sub selectScaffolds {
    my ($taxon_oid, $sample_oid, $exp_oid) = @_;

    # get selected params if any:
    my $scaffold_oid_len = param("scaffold_oid_len");
    my ( $myscaffold_oid, $myseq_length )
	= split( /:/, $scaffold_oid_len );

    # from "Next" or "Prev" buttons
    my $mystart = param("start_coord");
    my $myend = param("end_coord");

    # from "Redisplay" button
    if ($mystart eq "" || $myend eq "") {
	$mystart = param("start");
	$myend = param("end");
    }

    my $dbh = dbLogin();
    printMainForm();

    printFindMotifsScript();

    my $rclause = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    my $sql = qq{
        select distinct s.scaffold_name, ss.seq_length,
               s.scaffold_oid, tx.taxon_display_name,
               s.mol_type, s.mol_topology, s.ext_accession
        from scaffold s, scaffold_stats ss, taxon tx
        where s.taxon = ?
        and s.taxon = ss.taxon
        and s.scaffold_oid = ss.scaffold_oid
        and s.taxon = tx.taxon_oid
        and s.ext_accession is not null
        $rclause
        $imgClause
        order by ss.seq_length desc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my @scaffoldRecs;
    my $count;
    for ( ;; ) {
        my ( $scaffold_name,      $seq_length, $scaffold_oid,
             $taxon_display_name, $mol_type,   $mol_topology, 
	     $ext_accession ) = $cur->fetchrow();
        last if !$scaffold_oid;

        substr( $scaffold_name, length($taxon_display_name) );
        my $scaffold_name2    = WebUtil::getChromosomeName($scaffold_name);

        my $rec = "$scaffold_oid\t";
        $rec .= "$scaffold_name2\t";
        $rec .= "$seq_length";
        push( @scaffoldRecs, $rec ) if $seq_length > 0;
    }

    print "<h2>Motifs on Sequence</h2>";
    print "<a name='sequence'></a>";
    printHint(   "Click on a motif in the table to "
               . "<span style='background-color: #FF66FF;"        # fuchsia
               . " color: black'>&nbsp;highlight&nbsp;</span>"
               . " its position on the sequence."
               . "<br/>Mouseover the sequence to see detail"

	       . "<br/><span style='background-color: #A7E1FF;'>" # lightblue
               . "&nbsp;&nbsp;&nbsp;&nbsp;</span>"
               . " indicates gene coding region"

	       #. "<br/><span style='background-color: #FFFF33;'>" # yellow
               #. "&nbsp;&nbsp;&nbsp;&nbsp;</span>"
               #. " indicates potential start codon region"

               #. "<br/><span style='background-color: #66FFFF;'>" # aqua
               #. "&nbsp;&nbsp;&nbsp;&nbsp;</span>"
               #. " indicates possible Shine-Dalgarno region"

               . "<br/><span style='background-color: #66FF33;'>" # lime
               . "&nbsp;&nbsp;&nbsp;&nbsp;</span>"
               . " indicates methylated bases" );

    print "<p>\n";
    print "<select name='scaffold_oid_len' length='30'>\n";
    for my $r (@scaffoldRecs) {
        my ( $scaffold_oid, $scaffold_name, $seq_length ) = split( /\t/, $r );
	my $selected = ""; 
	$selected = "selected=\"true\"" if $scaffold_oid eq $myscaffold_oid;
        print "<option $selected value='$scaffold_oid:$seq_length'>";
        print escHtml($scaffold_name) . "  1..$seq_length" . nbsp(3);
        print "</option>\n";
    }
    print "</select>\n";

    my ( $scaffold_oid, $scaffold_name, $seqlen ) 
	= split( /\t/, $scaffoldRecs[0] );

    my $start = 1;
    my $end = $seqlen;
    $end = $pageSize if $seqlen > $pageSize;

    if ($mystart ne "" && $myend ne "" 
	&& $mystart > 0 && $myend > 0
	&& $myend > $mystart && $mystart <= $seqlen) {
	$start = $mystart;
	$end = $myend;
	$end = $seqlen if $myend > $seqlen;
	$start = ($end - 5000) if ($myend-$mystart) > 5000;
    }

    print "Start ";
    print "<input type='text' name='start' size='10' value='$start' />\n";
    print "End ";
    print "<input type='text' name='end' size='10' value='$end' />\n";
    print "&nbsp;";
    print "<br/>";

    print hiddenVar( "taxon_oid",  $taxon_oid );
    print hiddenVar( "exp_oid",    $exp_oid );
    print hiddenVar( "sample_oid", $sample_oid );
    my $name = "_section_Methylomics_motifsummary";
    print submit(
                  -name  => $name,
                  -value => "Redisplay",
                  -class => "smdefbutton"
    );
    print "&nbsp;&nbsp;[ Range cannot exceed 5000 bps ]";
    print "</p>\n";

    printSequence($dbh, $taxon_oid, $sample_oid, $scaffold_oid, $start, $end);

    my $end1 = $start - 1;
    my $start1 = $end1 - $pageSize;
    $start1 = 1 if $start1 < 1;

    my $prevUrl = "$main_cgi?section=Methylomics&page=motifsummary"
        . "&scaffold_oid=$scaffold_oid"
        . "&sample_oid=$sample_oid"
        . "&taxon_oid=$taxon_oid"
        . "&start_coord=$start1&end_coord=$end1";

    my $start2 = $end + 1;
    my $end2 = $start2 + $pageSize;
    $end2 = $seqlen if $end2 > $seqlen;

    my $nextUrl = "$main_cgi?section=Methylomics&page=motifsummary"
	. "&scaffold_oid=$scaffold_oid"
	. "&sample_oid=$sample_oid"
	. "&taxon_oid=$taxon_oid"
	. "&start_coord=$start2&end_coord=$end2";

    if ($start > 1) {
	print buttonUrl( $prevUrl, "&lt; Previous Range", "smbutton" );
    }
    if ($end < $seqlen && $seqlen > 0) {
	print buttonUrl( $nextUrl, "Next Range &gt;", "smbutton" );
    }

    # view genes in neighborhood
    print "<h2>Sequence Neighborhood</h2>";
    print "<p>";
    printNeighborhood($dbh, $scaffold_oid, $start, $end, $sample_oid);
    #$dbh->disconnect();
    print end_form();
}

############################################################################
# printNeighborhood - prints the neighborhood for the specified coordinate
#                     range, zoomed 10x and methylated
############################################################################
sub printNeighborhood {
    my ($dbh, $scaffold_oid, $start_coord, $end_coord, $sample_oid) = @_;

    my $mid_coord =
	int(($end_coord - $start_coord) / 2) + $start_coord + 1;
    my $flank_length = 2500;
    my $left_flank  = $mid_coord - $flank_length + 1;
    my $left_flank  = $left_flank > 0 ? $left_flank : 0;
    my $right_flank = $mid_coord + $flank_length + 1;

    use GeneDetail;
    my $sp = GeneDetail::getScaffoldPanel
	( "", $start_coord, $end_coord, $scaffold_oid, "", 0.1 );

    use Methylomics;
    Methylomics::addMethylations( $dbh, $scaffold_oid, $sp, "+",
				  #$start_coord, $end_coord,
				  $left_flank, $right_flank,
				  $sample_oid );

    my $s = $sp->getMapHtml("overlib");
    print "$s";
    print "<br/>";
}

############################################################################
# printSequence - prints the double stranded DNA sequence for the 
#                 specified coordinate range
############################################################################
sub printSequence {
    my( $dbh, $taxon_oid, $sample_oid, $scaffold_oid,
	$start_coord, $end_coord, $strand ) = @_;


    my $sql = qq{
        select m.motif_string,
               m.center_pos, m.fraction, m.n_detected,
               m.n_genome, m.group_tag,
               $nvl(m.partner_motif_string, ''),
               m.mean_score, m.mean_ipd_ratio, m.mean_coverage,
               m.objective_score, m.modification_type
        from meth_sample s, meth_motif_summary m
        where m.sample = s.sample_oid
        and m.experiment = s.experiment
        and s.sample_oid = ?
        and s.IMG_taxon_oid = ?
        order by m.motif_summ_oid
    };
    my @motifs;
    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid, $taxon_oid );
    for ( ;; ) {
        my ($motif_str, $center_pos, $fraction, $n_detected,
            $n_genome, $group_tag, $partner_motif_str, $mean_score,
            $mean_ipd_ratio, $mean_coverage, $objective_score, $m_type)
	    = $cur->fetchrow();
        last if !$motif_str;


	$fraction = sprintf("%.7f", $fraction);
        if ($motif_str ne "" && $center_pos ne ""
            && length($motif_str) >= $center_pos) {
            push(@motifs, 
		 $motif_str . "\t"
	       . "Motif String: $motif_str"
	       . "<br/>Center Pos: $center_pos"
	       . "<br/>Fraction: $fraction"
	       . "<br/>N detected: $n_detected"
	       . "<br/>Group Tag: $group_tag"
	       . "<br/>Mean Score: $mean_score"
	       . "<br/>Modification Type: $m_type");
        }
    }

    my $sql = qq{
        select distinct m.modification_oid, $nvl(m.IMG_scaffold_oid, ''),
               $nvl(motif_string, ''), m.methylation_coord, m.score,
               m.strand, m.context, m.coverage
        from meth_modification m, meth_sample s
        where m.sample = s.sample_oid
        and m.experiment = s.experiment
        and m.IMG_scaffold_oid = ?
        and s.sample_oid = ?
        and s.IMG_taxon_oid = ?
    };

    my $count = 0;
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid, 
		       $sample_oid, $taxon_oid );
    my %posPositions;
    my %negPositions;
    for ( ;; ) {
        my ($motif_oid, $scaffold_oid, $motif_str, $start, $score, $strand,
            $context, $coverage) = $cur->fetchrow();
        last if !$motif_oid;

	if ($strand eq "+") {
	    $posPositions{$start} = 1;
	} elsif ($strand eq "-") {
	    $negPositions{$start} = 1;
	}
    }

    my $seq = WebUtil::getScaffoldSeq
	($dbh, $scaffold_oid, $start_coord, $end_coord);

    my $len = 90;
    my $seqlen = length( $seq );
    my $cseq = WebUtil::getSequence( $seq, $seqlen, 1 );

    my $style = " style='font-size: 11px; "
        . "font-family: Arial,Helvetica,sans-serif; "
	. "text-align: center; "
        . "line-height: 1.0em;' ";
    my $style2 = " style='font-size: 11px; "
        . "font-family: Arial,Helvetica,sans-serif; "
        . "line-height: 1.0em; "
	. "text-align: left; "
        . "width: 80px;' ";
    my $style3 = " style='font-size: 11px; "
        . "font-family: Arial,Helvetica,sans-serif; "
        . "line-height: 1.0em; "
	. "text-align: center; "
        . "width: 100px;' ";

    #my %features = Sequence::getFeatures( $seq );
    #my %cfeatures = Sequence::getFeatures( $cseq );
    my %motifHash = findMotifs( $seq, \@motifs );
    my %cmotifHash = findMotifs( $seq, \@motifs, "-" );

    my %genesHash = findGenes( $dbh, $seq, $scaffold_oid,
			       $start_coord, $end_coord, "+" );
    my %cgenesHash = findGenes( $dbh, $seq, $scaffold_oid,
				$start_coord, $end_coord, "-" );
#    print "<br/>ANNA: seq : ".substr($seq, 0, 10);
#    print "<br/>ANNA: cseq1 : ".substr($cseq, 0, 10);
#    print "<br/>ANNA: cseq2 : ".substr($cseq, $seqlen-10, $seqlen);

    print "<p><div id='container' class='yui-skin-sam'>";
    print "<table id='seqTable' cellspacing=0>";
    for ( my $idx = 0; $idx < $seqlen; $idx += $len ) {
        my $start_coord2 = $start_coord + $idx;
        my $range = $idx + $len;
        if ($range > $seqlen) {
            $len = $seqlen - $idx;
        }

        my $tableW = 90 + (810 * $len / 90);
        print "<table style='table-layout: fixed; text-align: left; ' "
            . "width=$tableW border=0 cellpadding=0 cellspacing=0>";

	# print the first strand:
        print "<tr>";
        print "<td $style2>$start_coord2&nbsp;&nbsp;&nbsp;</td>";
        for ( my $i = 0; $i < $len; $i++ ) {
            my $offset = $i + $idx;
            my $pos = $start_coord + $offset;

            my $na = substr( $seq, $offset, 1 );
            my( $x1, $x2 );

            my $startCodonCode1 = "bgcolor='silver'";
            my $shineDalgarnoCode1 = ' ';
            #if ( $features{ $offset } =~ /start-codon/ ) {
            #    $startCodonCode1 = "bgcolor='#FFFF33'"; # yellow
            #}
            #if ( $features{ $offset } =~ /shine-dalgarno/ ) {
            #    $shineDalgarnoCode1 = "bgcolor='#66FFFF'"; # aqua
            #    $startCodonCode1 = ' ';
            #}
	    my $codingRegion = ' ';
	    if ( $genesHash{ $pos } =~ /gene/ ) {
                $shineDalgarnoCode1 = "";
                $startCodonCode1 = "";
		$codingRegion = "bgcolor='#A7E1FF'"; # lightblue
	    }
	    my $methCode = "";
	    if ( $motifHash{ $offset } =~ /motif/ ) {
		my ($item, $motif, $text) = split("\t", $motifHash{ $offset });
		$text = $text . "<br/>DNA Coord: " . ($pos);

		if ($motif ne "") {
		$methCode = #"id='motif' name='$motif' ";
                    "name='motif' value='$motif' "
                  . "onmouseover=\"return overlib('$text', "
                  . "ABOVE, STICKY, MOUSEOFF, '$motif')\" "
                  . "onmouseout='return nd()' ";
		}
	    }

	    if ($posPositions{$pos}) {
                #$x1 = "<font color='maroon'>";
                #$x2 = "</font>";
                $shineDalgarnoCode1 = "";
                $startCodonCode1 = "";
		$codingRegion = "";
		$methCode = "bgcolor='#66FF33'"; # lime
	    }

            print "<td ".$startCodonCode1.$shineDalgarnoCode1
		        .$codingRegion.$methCode
                ." $style title=".$pos.">";
            print "$x1$na$x2";
            print "</td>";
        }
        print "</tr>\n";

        # print the complement strand:
        print "<tr>";
        print "<td $style2>$start_coord2&nbsp;&nbsp;&nbsp;</td>";
        for ( my $i = 0; $i < $len; $i++ ) {
            my $offset = $idx + $i;
            my $pos = $start_coord + $offset;

            my $na = substr( $seq, $offset, 1 );
            my $cna = $na;
            $cna =~ tr/actgACTG/tgacTGAC/;

            my( $x1, $x2 );
            my $startCodonCode2 = "bgcolor='silver'";
            my $shineDalgarnoCode2 = ' ';
            my $k = $seqlen - $offset - 1;
            #if ( $cfeatures{ $k } =~ /start-codon/ ) {
            #    $startCodonCode2 = "bgcolor='#FFFF33'"; # yellow
            #}
            #if ( $cfeatures{ $k } =~ /shine-dalgarno/ ) {
            #    $shineDalgarnoCode2 = "bgcolor='#66FFFF'"; # aqua
            #    $startCodonCode2 = ' ';
            #}
            my $codingRegion = ' ';
            if ( $cgenesHash{ $pos } =~ /gene/ ) {
                $shineDalgarnoCode2 = "";
                $startCodonCode2 = "";
                $codingRegion = "bgcolor='#A7E1FF'"; # lightblue
            }
            my $methCode = "";
            if ( $cmotifHash{ $offset } =~ /motif/ ) {
                my ($item, $motif, $text) 
		    = split("\t", $cmotifHash{ $offset });
		$text = $text . "<br/>DNA Coord: " . ($pos);

		if ($motif ne "") {
                $methCode = 
                    "name='motif' value='$motif' "
                  . "onmouseover=\"return overlib('$text', "
                  . "ABOVE, STICKY, MOUSEOFF, '$motif')\" "
                  . "onmouseout='return nd()' ";
		}
            }

	    if ($negPositions{$pos}) {
                #$x1 = "<font color='maroon'>";
                #$x2 = "</font>";
                $shineDalgarnoCode2 = "";
                $startCodonCode2 = "";
		$codingRegion = "";
		$methCode = "bgcolor='#66FF33'"; # lime
	    }

            print "<td ".$startCodonCode2.$shineDalgarnoCode2
		        .$codingRegion.$methCode
                ." $style title=".$pos.">";
            print "$x1$cna$x2";
            print "</td>";
        }
        print "</tr>\n";

        print "</table>";
        print "<br>";
    }
    print "</table>";
    print "</div>\n";

}


1;

