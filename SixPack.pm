############################################################################
# SixPack.pm - Six  frame translation.
#    --es 06/22/08
#
# $Id: SixPack.pm 30377 2014-03-10 23:39:16Z jinghuahuang $
############################################################################
package SixPack;
my $section = "SixPack";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebUtil;
use WebConfig;
use GeneUtil;

$| = 1;


my $env = getEnv( );
my $sixpack_bin = $env->{ sixpack_bin };
my $taxon_lin_fna_dir = $env->{ taxon_lin_fna_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $bin_dir =  $env->{ bin_dir };
my $verbose = $env->{ verbose };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( paramMatch( "sixPack" ) ne "" ) {
       printSixPack( );
    }
    else {
       printQueryForm( );
    }
}

############################################################################
# printQueryForm - Show form for adjusting parameters.
############################################################################
sub printQueryForm {
   my $gene_oid = param( "genePageGeneOid" );

   # print "<h1>Six Frame Translation</h1>\n";
   print "<h1>Sequence Viewer</h1>\n";
   printMainForm( );
   print hiddenVar( "gene_oid", $gene_oid );

   my $dbh = dbLogin( );
   checkGenePerm( $dbh, $gene_oid );
   my $sql = qq{
       select g.gene_oid, g.gene_display_name,
          g.start_coord, g.end_coord, g.strand
       from gene g
       where g.gene_oid = ?
   };
   my @binds = ($gene_oid);
   my $cur = execSql( $dbh, $sql, $verbose, @binds );
   my( $gene_oid, $gene_display_name, $start_coord, $end_coord, $strand ) = 
      $cur->fetchrow( );
   $cur->finish( );

   print "<p>\n";
   print "Neighborhood six frame translation " . 
      "with putative ORF's shown below<br/>";
    print "Gene: $gene_oid&nbsp;&nbsp;<i>" . escHtml( $gene_display_name ) .  "</i><br/>\n";
    print "$start_coord..$end_coord";
    print " ($strand)<br/>";
   print "</p>\n";

   print "<p>\n";
   print "<font color='blue'><b>Select gene neighborhood</b></font>:<br>\n";
   print nbsp( 2 );
   print "<input type='text' size='3' "
      . "name='up_stream' value='-0' />\n";
   print "bp upstream.\n";
   print nbsp(2);
   print "<input type='text' size='3' "
     . "name='down_stream' value='+0' />\n";
   print "bp downstream\n";
   print "<br/>\n";
   print "<br/>\n";
   print "<font color='blue'><b>Select minimum ORF size</b></font>:<br>\n";
   print nbsp( 2 );
   print "<input type='text' size='3' "
     . "name='orfminsize' value='1' />aa\n";

   print "</p>\n";

   my $name = "_section_${section}_sixPack";
   print submit( -name => $name,
      -value => "Submit",
      -class => "smdefbutton" 
   );
   print nbsp( 2 );
   print reset( -class => "smbutton" );

   print end_form( );
   #$dbh->disconnect();
}

############################################################################
# printSixPack - Print sixpack output.
############################################################################
sub printSixPack {
   my $gene_oid = param( "gene_oid" );
   my $orfminsize = param( "orfminsize" );
   my $up_stream = param( "up_stream" );
   my $down_stream = param( "down_stream" );
   my $up_stream_int = sprintf( "%d", $up_stream );
   my $down_stream_int = sprintf( "%d", $down_stream );
   $gene_oid = sanitizeInt( $gene_oid );
   $up_stream =~ s/\s+//g;
   $down_stream =~ s/\s+//g;
   $up_stream =~ /([\-\+]{0,1}[0-9]+)/;
   $up_stream = $1;
   $down_stream =~ /([\-\+]{0,1}[0-9]+)/;
   $down_stream = $1;
   $orfminsize = sanitizeInt( $orfminsize );

   printMainForm( );
   #print "<h1>Six Frame Translation</h1>\n";
   print "<h1>Sequence Viewer</h1>\n";
   printStatusLine( "Loading ...", 1 );

   if( $up_stream_int > 0 || !isInt( $up_stream ) ) {
       webError( "Expected negative integer for up stream." );
   }
   if( $down_stream_int < 0 || !isInt( $down_stream ) ) {
       webError( "Expected positive integer for down stream." );
   }

   my $dbh = dbLogin( );
   checkGenePerm( $dbh, $gene_oid );

   my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.taxon, scf.ext_accession, 
          g.start_coord, g.end_coord, g.strand, g.cds_frag_coord, ss.seq_length
       from gene g, scaffold scf, scaffold_stats ss
       where g.gene_oid = ?
       and g.scaffold = scf.scaffold_oid 
       and scf.scaffold_oid = ss.scaffold_oid
   };
   my @binds = ($gene_oid);
   my $cur = execSql( $dbh, $sql, $verbose, @binds );
   my( $gene_oid, $gene_display_name, $taxon, $scf_ext_accession, 
       $start_coord0, $end_coord0, $strand, $cds_frag_coord, $scf_seq_length ) = 
          $cur->fetchrow( );
   $cur->finish( );

    #need to test genes with fragments having start position = 1, 
    #like "section=SixPack&genePageGeneOid=644807278"
    my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
    my @adjustedCoordsLines = GeneUtil::adjustMultFragCoordsLine( \@coordLines, $strand, $up_stream, $down_stream );

    print "<p>\n";
    print "Neighborhood six frame translation with putative ORF's shown below<br/>";
    print "Gene: $gene_oid&nbsp;&nbsp;<i>" . escHtml( $gene_display_name ) .  "</i><br/>\n";
    print "$start_coord0..$end_coord0";
    print GeneUtil::formMultFragCoordsLine( @coordLines );
    print " ($strand)<br/>";
    if ($up_stream > 0 || $down_stream > 0) {
        print "$up_stream upstream $down_stream downstream";
    }
    print "</p>\n";

   my $start_coord = $start_coord0 + $up_stream;
   my $end_coord = $end_coord0 + $down_stream;
   if( $strand eq "-" ) {
       $start_coord = $start_coord0 - $down_stream;
       $end_coord = $end_coord0 - $up_stream;
   }
   $start_coord = 1 if $start_coord < 1;
   $end_coord = $scf_seq_length if $end_coord > $scf_seq_length;
   
   webLog "$scf_ext_accession: $start_coord..$end_coord ($strand)\n"
         if $verbose >= 1;
   my $path = "$taxon_lin_fna_dir/$taxon.lin.fna";
   my $seq1 = WebUtil::readLinearFasta( $path, $scf_ext_accession, 
      $start_coord, $end_coord, $strand, \@adjustedCoordsLines );
      
   my $seq1_len = length( $seq1 );
   if( $seq1_len == 0 ) {
      webError( "Cannot read sequence for taxon_oid=$taxon " .
        "scf_ext_accession='$scf_ext_accession'\n" );
   }
   my $seq2 = wrapSeq( $seq1 );

   my $tmpInFile = "$cgi_tmp_dir/sixpack$$.fna";
   $tmpInFile = checkTmpPath( $tmpInFile );
   my $wfh = newWriteFileHandle( $tmpInFile, "printSixPack" );
   print $wfh ">$gene_oid\n";
   print $wfh "$seq2\n";
   close $wfh;
   my $tmpOutFile = "$cgi_tmp_dir/sixpack$$.out.txt";
   my $tmpSeqFile = "$cgi_tmp_dir/sixpack$$.out.faa";

   my $highlightSpec;

   my $us = -1 * $up_stream;
   $us = sanitizeInt( $us );
   $highlightSpec .= "1-$us green " if $us >= 1;

   my $codon1 = substr( $seq1, $us, 3 );
   if( isStartCodon( $codon1 ) ) {
      my $sc1 = $us + 1;
      my $sc2 = $sc1 + 3 - 1;
      $sc1 = sanitizeInt( $sc1 );
      $sc2 = sanitizeInt( $sc2 );
      $highlightSpec .= "$sc1-$sc2 red ";
   }

   my $ds1 = $seq1_len - $down_stream + 1;
   my $ds2 = $seq1_len;
   my $sc1 = $ds1 - 4;
   my $codon2 = substr( $seq1, $sc1, 3 );
   if( isStopCodon( $codon2 ) ) {
      $sc1 += 1;
      my $sc2 = $sc1 + 3 - 1;
      $sc1 = sanitizeInt( $sc1 );
      $sc2 = sanitizeInt( $sc2 );
      $highlightSpec .= "$sc1-$sc2 red ";
   }
   $ds1 = sanitizeInt( $ds1 );
   $ds2 = sanitizeInt( $ds2 );
   $highlightSpec .= "$ds1-$ds2 green " if $ds2 >= $ds1;

   chop $highlightSpec;
   #$highlightSpec = "";  # for debugging highlighting
   #$highlightSpec = "1-1 green 2-4 red 917-918 red 920-921 green";

   my $cmd = "$sixpack_bin -sequence $tmpInFile " .
      "-offset $start_coord -orfminsize $orfminsize " . 
      "-noname -nodescription " .
      "-html -outfile $tmpOutFile -outseq $tmpSeqFile " .
      "-highlight '$highlightSpec' ";

   # --es 06/20/08 buggy cause of runCmd/wsystem arg handling
   # for -highlight 'spec'.  So we do it manually here.
   #runCmd( $cmd ); 
   WebUtil::unsetEnvPath();
   webLog( "+ $cmd\n" );
   my $st = system( $cmd );

   if( $st != 0 ) {
      webDie( "status=$st '$cmd'\n" );
   }

   my $rfh = newReadFileHandle( $tmpOutFile, "printSixPack" );
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       print "$s\n";
   }
   close $rfh;
   print "</pre>\n";

   print "<hr/>\n";
   printHint(
      "Copy and paste " .
      "sequence to BLAST and InterPro scan " .
      "to test ORF translation."
   );
   print "<pre>\n";
   my $rfh = newReadFileHandle( $tmpSeqFile, "printSixPack" );
   while( my $s = $rfh->getline( ) ) {
       chomp $s;
       if ( $s =~ />/ ) {
          print "<br/>\n";
	  print "<font color='blue'>$s</font>\n";
       }
       else {
          print "$s\n";
       }
   }
   close $rfh;

   print "</pre>\n";
   wunlink( $tmpInFile );
   wunlink( $tmpOutFile );
   wunlink( $tmpSeqFile );
   printBaseTable( $seq1, $start_coord, $end_coord, $strand, 100,
      $highlightSpec );
   print end_form( );
   printStatusLine( "Loaded.", 2 );
   #$dbh->disconnect();
}

############################################################################
# printBaseTable - Show base table with information.
############################################################################
sub printBaseTable {
    my( $seq, $start_coord, $end_coord, $strand, $gc_window,
        $highlightSpec ) = @_;

    # complimentary sequence
    my $len = length( $seq );
    my $cseq = getSequence( $seq, $len, 1 );
    print "<hr>\n";
    print "<b>Base Table:</b>\n";
    printHint( 
       "'+' after base indicates potential start codon region.<br/>" .
       "'%' after base indicates possible Shine-Dalgarno region.<br/>"
    );
    #print "<br/>\n";
    #print "<br/>\n";
    print "<pre>\n";
    printf "%9s ", "Position";
    printf "%4s ", "Base";
    printf "%3s ", "GC";
    printf "%2s ", "F1";
    printf "%2s ", "F2";
    printf "%2s ", "F3";
    printf "  ";
    printf "%4s ", "Base";
    printf "%3s ", "GC";
    printf "%2s ", "F4";
    printf "%2s ", "F5";
    printf "%2s ", "F6";
    print "\n";
    my %colors = highlightColorCoords( $highlightSpec );
    my @f1 = getTranslation( $seq, 0 );
    my @f2 = getTranslation( $seq, 1 );
    my @f3 = getTranslation( $seq, 2 );
    my @f4 = getTranslation( $cseq, 0 );
    my @f6 = getTranslation( $cseq, 1 );
    my @f5 = getTranslation( $cseq, 2 );
    my %features = getFeatures( $seq );
    my %cfeatures = getFeatures( $cseq );
    for( my $i = 0; $i < $len; $i++ ) {
        my $pos = $start_coord + $i;
	my $na = substr( $seq, $i, 1 );
	my $cna = $na;
	$cna =~ tr/actgACTG/tgacTGAC/;
	my( $x1, $x2 );
	my $color = $colors{ $i };
	if( $color ne "" ) {
	   $x1 = "<font color='$color'>";
	   $x2 = "</font>";
	}
	my $f1 = $f1[ $i ];
	my $f2 = $f2[ $i ];
	my $f3 = $f3[ $i ];
	my $f4 = $f4[ $len - $i - 1 ];
	my $f5 = $f5[ $len - $i - 1 ];
	my $f6 = $f6[ $len - $i - 1 ];
	my $gc1 = getGc( $seq, $i, $len, $gc_window );
	my $gc2 = 100 - $gc1;
	my $startCodonCode1 = ' ';
	my $shineDalgarnoCode1 = ' ';
	my $startCodonCode2 = ' ';
	my $shineDalgarnoCode2 = ' ';
	if( $features{ $i } =~ /start-codon/ ) {
	   $startCodonCode1 = '+';
	}
	if( $features{ $i } =~ /shine-dalgarno/ ) {
	   $shineDalgarnoCode1 = '%';
	}
	my $k = $len - $i - 1;
	if( $cfeatures{ $k } =~ /start-codon/ ) {
	    $startCodonCode2 = '+';
	}
	if( $cfeatures{ $k } =~ /shine-dalgarno/ ) {
	    $shineDalgarnoCode2 = '%';
	}
	printf "%9d ", $pos;

	#printf "$x1%4s$x2 ", $na;
	print "$x1$na$x2";
	print $startCodonCode1;
	print $shineDalgarnoCode1;
	print "  ";
	printf "%3d ", $gc1;
	printf "%2s ", $f1;
	printf "%2s ", $f2;
	printf "%2s ", $f3;
	printf "  ";

	#printf "%4s ", $cna;
	print "$cna";
	print $startCodonCode2;
	print $shineDalgarnoCode2;
	print "  ";
	printf "%3d ", $gc2;
	printf "%2s ", $f4;
	printf "%2s ", $f5;
	printf "%2s ", $f6;
	print "\n";
    }
    print "</pre>\n";
}

############################################################################
# getTranslation - Get translation given offset.
############################################################################
sub getTranslation {
    my( $seq, $offset ) = @_;

    my $len = length( $seq );
    my @a;
    for( my $i = 0; $i < $offset; $i++ ) {
       push( @a, ' ' );
    }
    for( my $i = $offset; $i < $len; $i += 3 ) {
       my $codon = substr( $seq, $i, 3 );
       my $aa = geneticCode( $codon );
       $aa = ' ' if $aa eq "";
       push( @a, $aa );
       push( @a, ' ' );
       push( @a, ' ' );
    }
    my $len2 = @a;
    my $diff = $len - $len2;
    for( my $i = 0; $i < $diff; $i++ ) {
        push( @a, ' ' );
    }
    if( $diff < 0 ) {
       $diff *= -1;
       for( my $i = 0; $i < $diff; $i++ ) {
          pop( @a );
       }
    }
    my $len3 = @a;
    if( $len3 != $len ) {
       webDie( "getTranslation:  len=$len len3=$len3 offset=$offset\n" );
    }
    return @a;
}


############################################################################
# getGc - Get GC content
############################################################################
sub getGc {
    my( $seq, $i0, $len, $window ) = @_;

    my $w2 = int( $window / 2 );
    my $gc = 0;
    my $at = 0;
    my $w = 0;
    for( my $i = $i0; $i < $len; $i++ ) {
	last if $w > $w2;
        my $c = substr( $seq, $i, 1 );
	$gc++ if $c =~ /[GC]/;
	$at++ if $c =~ /[AT]/;
	$w++;
    }
    my $w = 0;
    for( my $i = $i0 - 1; $i > 0; $i-- ) {
	last if $w > $w2;
        my $c = substr( $seq, $i, 1 );
	$gc++ if $c =~ /[GC]/;
	$at++ if $c =~ /[AT]/;
	$w++;
    }
    my $gc_perc = 0;
    $gc_perc = $gc / ( $gc + $at ) 
       if $gc > 0 || $at > 0;
    $gc_perc *= 100;
    return int( $gc_perc );
}

############################################################################
# highlightColorCoords - Get highlight color coordinates.
#   Parse spec and generate coordinate map.
############################################################################
sub highlightColorCoords {
    my( $spec ) = @_;

    my @toks = split( /\s+/, $spec );
    my $nToks = @toks;
    my %h;
    for( my $i = 0; $i < $nToks; $i += 2 ) {
        my $range = $toks[ $i ];
        my $color = $toks[ $i + 1 ];
	my( $lo, $hi ) = split( /-/, $range );
	for( my $i = $lo; $i <= $hi; $i++ ) {
	   my $idx = $i - 1;
	   $h{ $idx } = $color;
	}
    }
    return %h;
}

############################################################################
# getFeatures  - Get special features like
#  1. potential start codons.
#  2. Shine-Dalgarno region: AGGAGG 6-7bp upstream of start codon.
############################################################################
sub getFeatures {
    my( $seq ) = @_;

    my $len = length( $seq );
    my %h;
    for( my $i = 0; $i < $len; $i++ ) {
        my $seq2 = substr( $seq, $i, 16 );
	my $codon = substr( $seq, $i, 3 );
	if( isStartCodon( $codon ) ) {
	   $h{ $i++ } .= "start-codon,";
	   $h{ $i++ } .= "start-codon,";
	   $h{ $i++ } .= "start-codon,";
	}
	# Shine Dalgarno: look upstream for start codon
	#if( $seq2 =~ /^AGGAGG/ ) {
	if( shineDalgarnoMatch( $seq2 ) >= 4 ) {
	   my $startIdx = $i + 6 + 5; # AGGAGG(6) + 5bp gap
	   my $endIdx = $i + length( $seq2 );
	   my $foundStartCodon = 0;
	   for( my $j = $startIdx; $j < $endIdx; $j++ ) {
	       my $condon2 = substr( $seq, $j, 3 );
	       if( isStartCodon( $condon2 ) ) {
		  $foundStartCodon = 1;
		  last;
	       }
	   }
	   if( $foundStartCodon ) {
              $h{ $i++ } .= "shine-dalgarno,";
              $h{ $i++ } .= "shine-dalgarno,";
              $h{ $i++ } .= "shine-dalgarno,";
	      $h{ $i++ } .= "shine-dalgarno,";
	      $h{ $i++ } .= "shine-dalgarno,";
	      $h{ $i++ } .= "shine-dalgarno,";
	   }
	}
    }
    return %h;
}

############################################################################
# shineDalgarnoMatch - Give score for shine dalgarno match.
############################################################################
sub shineDalgarnoMatch {
    my( $seq ) = @_;

    my $count = 0;
    for( my $i = 0; $i < 6; $i++ ) {
       my $c1 = substr( $seq, $i, 1 );
       my $c2 = substr( "AGGAGG", $i, 1 );
       $count++ if $c1 eq $c2;
    }
    return $count;
}


1;

