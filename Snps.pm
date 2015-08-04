###########################################################################
# Snps.pm  
# $Id: Snps.pm 30377 2014-03-10 23:39:16Z jinghuahuang $
############################################################################
package Snps; 
my $section = "Snps"; 
 
use strict; 
use CGI qw( :standard ); 
use Data::Dumper; 
use Sequence;
use StaticInnerTable;
use WebConfig; 
use WebUtil;
use GeneUtil;
 
my $env          = getEnv(); 
my $main_cgi     = $env->{main_cgi}; 
my $section_cgi  = "$main_cgi?section=$section"; 
my $inner_cgi    = $env->{inner_cgi}; 
my $verbose      = $env->{verbose}; 
my $base_dir     = $env->{base_dir}; 
my $base_url     = $env->{base_url}; 
my $snp_enabled  = $env->{snp_enabled};
 

############################################################################
# printGeneSnps - prints all snps for a specified gene and experiment
############################################################################
sub printGeneSnps {
    my $gene_oid = param("gene_oid");
    my $exp_oid  = param("exp_oid");

    print "<h1>SNP</h1>";
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $contact_oid = getContactOid();
    my $super_user  = 'No';
    if ($contact_oid) {
        $super_user = getSuperUser();
    }

    my $sql = qq{
	select s.gene_oid, exp.exp_oid, exp.exp_name
	    from gene_snp s, snp_experiment exp
	    where s.gene_oid = ?
	    and exp.exp_oid = ?
	    and s.experiment = exp.exp_oid
	};

    if ( !$contact_oid ) {
        $sql .= " and exp.is_public = 'Yes' ";
    } elsif ( $super_user ne 'Yes' ) {
        $sql .= " and (exp.is_public = 'Yes' or "
	      . "exp.exp_oid in "
              . "(select snp_exp_permissions "
              . " from contact_snp_exp_permissions "
              . " where contact_oid = $contact_oid))";
    }

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $exp_oid );
    my ( $gid3, $exp_oid, $exp_name ) = $cur->fetchrow();
    $cur->finish();

    print "<script src='$base_url/overlib.js'></script>\n";
    print qq{ 
        <script language='JavaScript' type='text/javascript'> 
        function findSnp(name) { 
	    var tableEl = document.getElementById('seqTable');
            var els = tableEl.getElementsByTagName('td');
            for (var i=0; i < els.length; i++) {
                var el = els[i];
		if (el.id == 'snp' && el.name != name) {
		    el.bgColor = 'silver';
		    cClick(); // closes the sticky popup
		}
            }
	    var els = document.getElementsByName(name);
            for (var i=0; i < els.length; i++) {
                var el = els[i]; 
		el.bgColor = 'pink';
		//el.onmouseover();
	    }
        } 
        </script> 
    };

    print "<h2>Experiment: $exp_name</h2>\n";
    printSnpSeqBatch( $dbh, $gene_oid, 0, 0, $exp_oid );
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

############################################################################
# printSnpSeqBatch - gets all snps for a given gene and experiment,
#    highlights them on the gene sequence, and shows detailed info in table
############################################################################
sub printSnpSeqBatch {
    my ( $dbh, $gene_oid, $up_stream, $down_stream, $exp_oid ) = @_;
    my $taxon_lin_fna_dir = $env->{taxon_lin_fna_dir};

    my $sql = qq{ 
        select g.gene_oid, g.gene_display_name, g.locus_type, 
               tx.taxon_oid, tx.genus, tx.species, 
               g.start_coord, g.end_coord, g.strand, g.cds_frag_coord, 
               scf.ext_accession, scf.scaffold_name, ss.seq_length 
        from gene g, scaffold scf, scaffold_stats ss, taxon tx 
        where g.scaffold = scf.scaffold_oid 
        and scf.scaffold_oid = ss.scaffold_oid 
        and g.taxon = tx.taxon_oid 
        and g.start_coord > 0 
        and g.end_coord > 0 
        and g.gene_oid = ?
    };
    my @binds = ($gene_oid);
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my ( $gene_oid,       $gene_display_name, $locus_type,
         $taxon_oid,      $genus,             $species,
         $start_coord0,   $end_coord0,        $strand,
         $cds_frag_coord, $ext_accession,
         $scaffold_name,  $scf_seq_length ) = $cur->fetchrow();

    # Reverse convention for reverse strand.
    my $start_coord = $start_coord0 + $up_stream;
    my $end_coord = $end_coord0 + $down_stream;
    if ( $strand eq "-" ) {
        $start_coord = $start_coord0 - $down_stream;
        $end_coord   = $end_coord0 - $up_stream;
    }
    $start_coord   = 1               if $start_coord < 1;
    $end_coord     = $scf_seq_length if $end_coord > $scf_seq_length;

    my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
    my @adjustedCoordsLines = GeneUtil::adjustMultFragCoordsLine( \@coordLines, $strand, $up_stream, $down_stream );

    #webLog "$ext_accession $start_coord..$end_coord fragments(@coordLines) ($strand)\n"
    #     if $verbose >= 1;

    my $url = "$main_cgi?section=GeneDetail"
	    . "&page=geneDetail&gene_oid=$gene_oid";

    print "<pre>\n";
    print "<font color='blue'>";
    print ">" . alink( $url, $gene_oid ) . "<br/>";
    print "$gene_display_name [$scaffold_name] ($strand)strand";
    print "</font><br/>\n";
    #print "start: $start_coord, end: $end_coord, strand: $strand";
    print "$start_coord0..$end_coord0";
    print GeneUtil::formMultFragCoordsLine( @coordLines );
    print " ($strand)<br/>";
    print "</pre>\n";

    my $path = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
    my $seq1 = WebUtil::readLinearFasta( $path, $ext_accession,
				$start_coord, $end_coord,
				$strand, \@adjustedCoordsLines );

    if ( blankStr($seq1) ) {
        return;
    }
    my $us_len = $start_coord0 - $start_coord;    # upstream length
    $us_len = $end_coord - $end_coord0 if $strand eq "-";
    $us_len = 0 if $us_len < 0;
    
    my $dna_len;
    if ( scalar(@coordLines) > 1 ) {
        $dna_len = GeneUtil::getMultFragCoordsLength(@coordLines);
    }
    else {
        $dna_len = $end_coord0 - $start_coord0 + 1;
    }

    my $dna_len1 = 3;               # start codon
    my $dna_len2 = $dna_len - 6;    # middle
    my $dna_len3 = 3;               # end codon

    # Set critical coordinates from segment lengths.
    my $c0 = 1;
    my $c1 = $c0 + $us_len;
    my $c2 = $c1 + $dna_len1;
    my $c3 = $c2 + $dna_len2;
    my $c4 = $c3 + $dna_len3;

    my $c1StartCodon = 0;
    my $startCodon0  = substr( $seq1, $c1 - 1, 3 );
    $c1StartCodon = 1 if isStartCodon($startCodon0);
    my $stopCodon0 = substr( $seq1, $c3 - 1, 3 );
    my $c3StopCodon = 0;
    $c3StopCodon = 1 if isStopCodon($stopCodon0);

    if ( $verbose >= 5 ) {
        webLog "up_stream=$up_stream ";
        webLog "start_coord0=$start_coord0 ";
        webLog "start_coord=$start_coord\n";
        webLog "end_coord=$end_coord ";
        webLog "end_coord0=$end_coord0 ";
        webLog "c0=$c0 c1=$c1 c2=$c2 c3=$c3 c4=$c4\n";
        webLog "startCodon0='$startCodon0' " 
	     . "c1StartCodon=$c1StartCodon\n";
        webLog "stopCodon0 ='$stopCodon0' c3StopCodon=$c3StopCodon\n";
    }

    # now we get all SNP
    $sql = qq{
	select s.gene_oid, s.ref_position, exp.exp_oid, exp.exp_name,
	s.frame, s.snp_position, s.reference_seq, s.query_seq,
	s.reference_nucleotide, s.query_nucleotide,
	s.type, s.support, s.position_coverage
	from gene_snp s, snp_experiment exp
	where s.gene_oid = ?
	and exp.exp_oid = ?
	and s.experiment = exp.exp_oid
	order by 1, 2, 5
    };
    $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $exp_oid );

    my $disp_cnt = 0;
    my $snpText;
    my $snpSpec;
    my @snps;
    my @texts;
    my @recs;

    for ( ;; ) {
        my ( $gid3,    $ref_pos, $exp_oid,   $exp_name, $frame,
             $snp_pos, $ref_seq, $query_seq, $aa1,      $aa2,
             $type,    $support, $coverage ) = $cur->fetchrow();
        last if !$gid3;

        $disp_cnt++;
        if ( $disp_cnt > 100 ) {
            print "<p>Too many SNPs ...</p>\n";
            last;
        }

        $snpText =
            "Reference position: $ref_pos, SNP position in codon: "
          . "$frame, SNP position from gene start: $snp_pos, "
          . "Codon change: "
          . uc($ref_seq) . " -> "
          . uc($query_seq) . ", "
          . "Amino acid change: "
          . $aa1 . " -> "
          . $aa2
          . ", Type: $type, Read/Contig support: $support";

        push @snps,  "SNP$disp_cnt";
        push @texts, $snpText;
        my $r = "$ref_pos\t";
        $r .= "$frame\t";
        $r .= "$snp_pos\t";
        $r .= uc($ref_seq) . "->" . uc($query_seq) . "\t";
        $r .= $aa1 . "->" . $aa2 . "\t";
        $r .= "$type\t";
        $r .= "$support\t";
        $r .= "$coverage\t";
        push @recs, $r;

        my $use_snp_pos = 1;
        my $new_pos     = $ref_pos;
        if ($use_snp_pos) {
            $new_pos = $snp_pos;
            if ( $snp_pos < 0 ) {
                $new_pos = -$snp_pos;
            }
        }

        my $highlight_start = $new_pos;
        my $highlight_end   = $new_pos + 2;

        if ( $frame == 2 ) {
            $highlight_start = $new_pos - 1;
            $highlight_end   = $new_pos + 1;
        } elsif ( $frame == 3 ) {
            $highlight_start = $new_pos - 2;
            $highlight_end   = $new_pos;
        }
        $snpSpec .= "$highlight_start-$highlight_end\t"
	          . "SNP$disp_cnt\t$snpText\t";
    }

    $cur->finish();

    printDNASequence( $seq1, $start_coord, $end_coord, $snpSpec );
    print "<br/>";

    my $it = new StaticInnerTable(); 
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "SNP", "", "left" ); 
    $it->addColSpec( "Reference Position", "", "right" ); 
    $it->addColSpec( "SNP Position in codon", "", "right" ); 
    $it->addColSpec( "SNP Position from Gene Start", "", "right" ); 
    $it->addColSpec( "Codon Change", "", "center" ); 
    $it->addColSpec( "AA Change", "", "center" ); 
    $it->addColSpec( "Type", "", "left" ); 
    $it->addColSpec( "Position Coverage", "", "right" ); 
    $it->addColSpec( "Read/Contig support", "", "right" ); 

    my $idx = 0;
    foreach my $snp (@snps) {
        my $r = $recs[$idx];
        my ( $ref_pos, $frame, $snp_pos, $codon_ch,
             $aa_ch,   $type,  $support, $coverage )
	    = split( /\t/, $r );
        my $link = "<a href='#sequence' "
                . "onclick=javascript:findSnp('$snp')>$snp</a>";

	my $row;
	$row .= $link."\t";
	$row .= $ref_pos."\t";
	$row .= $frame."\t";
	$row .= $snp_pos."\t";
	$row .= $codon_ch."\t";
	$row .= $aa_ch."\t";
	$row .= $type."\t";
	$row .= $coverage."\t";
	$row .= $support."\t";
	$it->addRow($row); 

        $idx++;
    }
    $it->printOuterTable(1); 
}

############################################################################
# snpCoords - reorganizes the snp details into a hash by coordinate of snp
############################################################################
sub snpCoords {
    my ($spec) = @_;
    my @toks = split( /\t/, $spec );
    my $nToks = @toks;
    my %h;
    for ( my $i = 0 ; $i < $nToks ; $i += 3 ) {
        my $range = $toks[$i];
        my $snp   = $toks[ $i + 1 ];
        my $text  = $toks[ $i + 2 ];
        my ( $lo, $hi ) = split( /-/, $range );
        for ( my $i = $lo ; $i <= $hi ; $i++ ) {
            my $idx = $i;    ###$i - 1;
            $h{$idx} = "$snp\t$text";
        }
    }
    return %h;
}

############################################################################
# printDNASequence - prints the DNA seq with snps highlighted
############################################################################
sub printDNASequence {
    my ( $seq, $start_coord, $end_coord, $snpSpec ) = @_;

    my $len = 60;
    my $seqlen = length($seq);
    my %features = Sequence::getFeatures($seq);

    #my %colors = Sequence::highlightColorCoords( $highlightSpec );
    my %snps = snpCoords($snpSpec);

    print "<a name='sequence'></a>";
    printHint(   "Click on a SNP in the table to "
	       . "<span style='background-color: pink;"
               . " color: fuchsia'>&nbsp;<u>highlight</u>&nbsp;</span>"
               . " its position on the sequence."
               . "<br/>Mouseover the sequence to see SNP detail"
               . "<br/><span style='background-color: aqua;'>"
               . "&nbsp;&nbsp;&nbsp;&nbsp;</span>"
               . " indicates possible Shine-Dalgarno region" );

    print "<p><div>";
    my $style = " style='font-size: 11px; " 
        . "font-family: Arial,Helvetica,sans-serif; " 
        . "line-height: 1.0em;' "; 

    print "<table id='seqTable' cellspacing=0>";
    for ( my $idx = 0 ; $idx < $seqlen ; $idx += $len ) {
        my $start_coord2 = $start_coord + $idx;
        my $range = $idx + $len;
        if ( $range > $seqlen ) {
            $len = $seqlen - $idx;
        }
        print "<tr>";
        print "<td $style id='link'>$start_coord2&nbsp;&nbsp;&nbsp;</td>";
        for ( my $i = 0 ; $i < $len ; $i++ ) {
            my $offset = $i + $idx;
            my $pos = $start_coord + $offset;

            my $na = substr( $seq, $offset, 1 );
            my ( $x1, $x2 );

            #my $color = $colors{ $offset };
            #if( $color ne "" ) {
            #    $x1 = "<font color='$color'>";
            #    $x2 = "</font>";
            #}
            my $snpcode = "";
            my ( $snp, $text ) = split( /\t/, $snps{$offset} );

            #my $snp = $snps{ $offset };
            if ( $snp ne "" ) {
                $x1 = "<font color='fuchsia'><b><u>";
                $x2 = "</u></b></font>";
                $snpcode =
                    "id='snp' name='$snp' "
                  . "onmouseover=\"return overlib('$text', "
                  . "ABOVE, STICKY, CLOSECLICK, CAPTION, '$snp')\" "
                  . "onmouseout='return nd()' ";
            }

            my $startCodonCode1    = "bgcolor='silver'";
            my $shineDalgarnoCode1 = ' ';
            my $startCodonCode2    = "bgcolor='silver'";
            my $shineDalgarnoCode2 = ' ';

            #if( $features{ $offset } =~ /start-codon/ ) {
            #    $startCodonCode1 = "bgcolor='yellow'";
            #}
            if ( $features{$offset} =~ /shine-dalgarno/ ) {
                $shineDalgarnoCode1 = "bgcolor='aqua'";
                $startCodonCode1    = ' ';
            }

            print "<td $style "
		. $snpcode
		. $startCodonCode1
		. $shineDalgarnoCode1
		. " title=" . $pos . ">";
            print "$x1$na$x2";
            print "</td>";
        }
        print "</tr>\n";
    }
    print "</table>";
    print "</div>\n";
}


1;

