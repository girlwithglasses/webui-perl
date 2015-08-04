############################################################################
# Sequence.pm - DNA Sequence Display
# all calculations are from Ernest's code in SixPack.pm
# $Id: Sequence.pm 30377 2014-03-10 23:39:16Z jinghuahuang $
############################################################################
package Sequence;
my $section = "Sequence";

require Exporter;
@ISA = qw( Exporter );
@EXPORT = qw(
    printSequence
    findSequence
    getFeatures
    getTranslationAsString
);

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebUtil;
use WebConfig;
use ChartUtil;
use GeneUtil;

$| = 1;


my $env = getEnv();
my $main_cgi = $env->{ main_cgi }; 
my $base_url = $env->{base_url};
my $tmp_url = $env->{ tmp_url };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $sixpack_bin = $env->{ sixpack_bin };
my $taxon_lin_fna_dir = $env->{ taxon_lin_fna_dir };
my $verbose = $env->{ verbose };
my $chart_exe = $env->{ chart_exe };
my $YUI = $env->{ yui_dir_28 };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );
    if ( paramMatch("sequence") ne"" ||
         $page eq "sequence" ) {
        computeSequence();
    } else {
        printQueryForm();
    }
}

############################################################################
# printQueryForm - Show form for adjusting parameters.
############################################################################
sub printQueryForm {
    my $gene_oid = param("genePageGeneOid"); 
    my $taxon_oid = param("taxon_oid"); 
    my $data_type = param("data_type");
 
    print "<h1>Sequence Viewer</h1>\n"; 
    printMainForm(); 

    my $dbh = dbLogin(); 

    my $isTaxonInFile;
    if ($taxon_oid ne "") {
        $isTaxonInFile = MerFsUtil::isTaxonInFile( $dbh, $taxon_oid );
    }

    my ($gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid);

    if ($isTaxonInFile) {

    	my $name_src;
        ( $gene_display_name, $name_src ) = 
    	    MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );

        my ( $gene_oid2, $locus_type2, $locus_tag2, $gene_display_name2, $start2, $end2, $strand2, $scaffold2 )
            = MetaUtil::getGeneInfo($gene_oid, $taxon_oid, $data_type);
        $start_coord = $start2;
        $end_coord = $end2;
        $strand = $strand2;
        $scaffold_oid = $scaffold2;

    } else {
        
    	WebUtil::checkGenePerm($dbh, $gene_oid); 
    	my $sql = qq{ 
            select gene_oid, gene_display_name, start_coord, end_coord, strand, scaffold
            from gene
            where gene_oid = ? 
        }; 

    	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid ); 
    	( $gene_oid, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid ) 
    	    = $cur->fetchrow(); 
    	$cur->finish(); 

    }

    print hiddenVar("gene_oid", $gene_oid); 
    print hiddenVar("gene_display_name", $gene_display_name); 
    print hiddenVar("taxon_oid", $taxon_oid); 
    print hiddenVar("data_type", $data_type); 
    print hiddenVar("in_file", $isTaxonInFile); 
    print hiddenVar("start_coord", $start_coord); 
    print hiddenVar("end_coord", $end_coord); 
    if ( $strand eq '+' ) {
        print hiddenVar("strand", 'plus');
    }
    elsif ( $strand eq '-' ) {
        print hiddenVar("strand", 'minus');
    }
    else {
        print hiddenVar("strand", $strand);         
    }
    print hiddenVar("scaffold_oid", $scaffold_oid); 
 
    my $url = "$main_cgi?section=GeneDetail" 
            . "&page=geneDetail&gene_oid=$gene_oid"; 
    if ($isTaxonInFile) {
    	$url = "$main_cgi?section=MetaGeneDetail"
    	     . "&page=metaGeneDetail&gene_oid=$gene_oid"
    	     . "&data_type=$data_type&taxon_oid=$taxon_oid";
    }

    print "<p>\n"; 
    print "Select parameters to view the six frame translation<br/>"; 
    print "Gene: " . alink($url, $gene_oid)
	. "&nbsp;&nbsp;<i>" . escHtml( $gene_display_name ) .  "</i><br/>\n"
        . "$start_coord..$end_coord($strand)<br/>"; 
    print "</p>\n"; 
 
    print "<p>\n"; 
    print "<font color='blue'><b>Select gene neighborhood</b></font>:<br>\n"; 
    print nbsp(2); 
    print "<input type='text' size='3' " 
        . "name='up_stream' value='-0' />\n"; 
    print "bp upstream\n"; 
    print nbsp(2); 
    print "<input type='text' size='3' " 
        . "name='down_stream' value='+0' />\n"; 
    print "bp downstream\n"; 
    print "<br/>\n"; 
    print "<br/>\n"; 
    print "<font color='blue'><b>Select minimum ORF size</b></font>:<br>\n"; 
    print nbsp(2); 
    print "<input type='text' size='3' " 
        . "name='orfminsize' value='1' />aa\n"; 

    print "<br/>\n"; 
    print "<br/>\n";
    print "<font color='blue'><b>Output Format</b></font>:<br>\n";
    print nbsp(2); 
    print "<input type='radio' "
	. "name='output_format' value='text' />"
        . "Text";
    print nbsp(2);
    print "<input type='radio' "
	. "name='output_format' value='graphics' checked />"
        . "Graphics\n";
    print "</p>\n"; 
 
    my $name = "_section_${section}_sequence"; 
    print submit( 
      -name  => $name, 
      -value => "Submit", 
      -class => "smdefbutton" 
    ); 
 
    print nbsp(2); 
    print reset( -class => "smbutton" ); 
 
    print end_form(); 
    #$dbh->disconnect(); 
} 

############################################################################
# findSequence - find the sequence for a missing gene
############################################################################
sub findSequence {
    my ( $taxon_oid, $scaffold_oid, $ext_accession, 
	 $mystart1, $myend1, $mystrand ) = @_;
    $taxon_oid = WebUtil::sanitizeInt( $taxon_oid );

    my $mystart = $mystart1 - 120;
    my $myend = $myend1 + 120;

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();
    checkTaxonPerm( $dbh, $taxon_oid );

    my $path = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
    my $seq = WebUtil::readLinearFasta( $path, $ext_accession, 
			       $mystart, $myend, "+" );
    my $seq_len = length( $seq );
    if( $seq_len == 0 ) {
	printStatusLine( "Cannot read sequence.", 2 );
        webError( "Cannot read sequence for taxon_oid=$taxon_oid " .
                  "scf_ext_accession='$ext_accession'\n" );
    }

    my $highlightSpec = "";

    print "<h2>Sequence Viewer</h2>\n";
    print "<p>\n"; 
    print "Neighborhood six frame translation for<br/>"
	. "a missing gene at coordinates $mystart1..$myend1 ($mystrand)<br/>"
	. "(padded by 120 bps at both ends)\n";
    print "</p>\n"; 
    printSequence( $seq, $mystart, $myend,
		   $mystrand, 100, $highlightSpec, "", "", 120, "yes" );
        
    print end_form();
    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

############################################################################
# computeSequence
############################################################################
sub computeSequence {
    #print "Sequence::computeSequence() <br/>\n";

    my $format = param( "output_format" );
    my $gene_oid = param( "gene_oid" );
    my $taxon_oid = param("taxon_oid"); 
    my $data_type = param("data_type");
    my $isTaxonInFile = param("in_file");
    my $orfminsize = param( "orfminsize" );
    my $up_stream = param( "up_stream" );
    my $down_stream = param( "down_stream" );
    my $up_stream_int = sprintf( "%d", $up_stream );
    my $down_stream_int = sprintf( "%d", $down_stream );

    $up_stream =~ s/\s+//g;
    $down_stream =~ s/\s+//g;
    $up_stream =~ /([\-\+]{0,1}[0-9]+)/;
    $up_stream = $1;
    $down_stream =~ /([\-\+]{0,1}[0-9]+)/;
    $down_stream = $1;
    $orfminsize = WebUtil::sanitizeInt( $orfminsize );

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<h1>Sequence Viewer</h1>\n";

    if( $up_stream_int > 0 || !isInt( $up_stream ) ) {
        webError( "Expected negative integer for up stream." );
    }
    if( $down_stream_int < 0 || !isInt( $down_stream ) ) {
        webError( "Expected positive integer for down stream." );
    }

    my ( $gene_display_name, $taxon, $scf_ext_accession, 
    	 $start_coord0, $end_coord0, $strand, $cds_frag_coord, $scf_seq_length );
    my @coordLines;

    my $seq1;
    if ($isTaxonInFile) {
        $gene_display_name = param("gene_display_name");
        $start_coord0 = param("start_coord");
        $end_coord0 = param("end_coord");
    	$strand = param("strand");
        if ( $strand eq 'plus' ) {
            $strand = '+';
        }
        elsif ( $strand eq 'minus' ) {
            $strand = '-';
        }

    	my $scaffold_oid = param("scaffold_oid");
    	$seq1 = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );

        my ( $scf_start, $scf_end, $scf_strand ) = 
	    MetaUtil::getScaffoldCoord( $taxon_oid, $data_type, $scaffold_oid );
        $scf_seq_length = $scf_end - $scf_start + 1;

    } else {
    	my $dbh = dbLogin();
    	$gene_oid = WebUtil::sanitizeInt( $gene_oid );
    	WebUtil::checkGenePerm( $dbh, $gene_oid );
    	my $sql = qq{
            select g.gene_oid, g.gene_display_name, 
                   g.taxon, scf.ext_accession, 
                   g.start_coord, g.end_coord, 
                   g.strand, g.cds_frag_coord, ss.seq_length
            from gene g, scaffold scf, scaffold_stats ss
            where g.gene_oid = ?
            and g.scaffold = scf.scaffold_oid 
    	    and scf.scaffold_oid = ss.scaffold_oid
        };
    	my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    	( $gene_oid, $gene_display_name, $taxon, $scf_ext_accession, 
    	  $start_coord0, $end_coord0,
    	  $strand, $cds_frag_coord, $scf_seq_length ) = $cur->fetchrow();
    	$cur->finish();

        #need to test genes with fragments having start position = 1, 
        #like "section=Sequence&page=queryForm&genePageGeneOid=644807278"
        @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
    }

    my $url = "$main_cgi?section=GeneDetail"
	    . "&page=geneDetail&gene_oid=$gene_oid";
    if ($isTaxonInFile) {
    	$url = "$main_cgi?section=MetaGeneDetail"
    	     . "&page=metaGeneDetail&gene_oid=$gene_oid"
    	     . "&data_type=$data_type&taxon_oid=$taxon_oid";
    }

    print "<p>\n";
    print "Neighborhood six frame translation "
        . "with putative ORF's shown below <br/>";
    print "Gene: " . alink($url, $gene_oid)
	. "&nbsp;&nbsp;<i>" . escHtml( $gene_display_name ) .  "</i><br/>\n";
    print "$start_coord0..$end_coord0";
    print GeneUtil::formMultFragCoordsLine( @coordLines );
    print " ($strand)<br/>";
    if ($up_stream > 0 || $down_stream > 0) {
    	print "$up_stream upstream $down_stream downstream";
    }
    print "</p>\n";

    my $start_coord = $start_coord0 + $up_stream;
    my $end_coord = $end_coord0 + $down_stream;
    if ( $strand eq "-" ) {
        $start_coord = $start_coord0 - $down_stream;
        $end_coord = $end_coord0 - $up_stream;
    }

    # out of range adjustment
    my $adjust_up = 0;
    my $adjust_down = 0;
    #print "coords5[$start_coord, $end_coord], scaf len[$scf_seq_length]<br>";
    if ( $start_coord < 1 ) {
        # because position 0 does not exist,
        # the difference between -1 and 1 is 1bp not 2bp
        $adjust_up = $start_coord - 1; 
        $start_coord = 1;
    }

    if ( $end_coord > $scf_seq_length ) {
        $adjust_down = $end_coord - $scf_seq_length;
        $end_coord = $scf_seq_length;
    }
    #print "adjusts1 up and down [$adjust_up, $adjust_down]<br>";

    if ( $strand eq '-' ) {
        my $tmp = $adjust_up;
        $adjust_up = -1 * $adjust_down;
        $adjust_down = -1 * $tmp;
    }
 
    #print "adjusts2 up and down [$adjust_up, $adjust_down]<br>";
    #print "coords[$start_coord, $end_coord]<br>";

    if ($isTaxonInFile) {
        #webLog "$scf_ext_accession $start_coord..$end_coord ($strand)\n"
        #       if $verbose >= 1;
    	if ( $strand eq '-' ) {
    	    $seq1 = WebUtil::getSequence( $seq1, $end_coord, $start_coord );
    	} else {
    	    $seq1 = WebUtil::getSequence( $seq1, $start_coord, $end_coord );
    	}

    } else {
        #webLog "$ext_accession $start_coord..$end_coord fragments(@coordLines) ($strand)\n"
        #     if $verbose >= 1;
        my @adjustedCoordsLines = GeneUtil::adjustMultFragCoordsLine( \@coordLines, $strand, $up_stream, $down_stream );

    	my $path = "$taxon_lin_fna_dir/$taxon.lin.fna";
    	$seq1 = WebUtil::readLinearFasta( $path, $scf_ext_accession, 
			 $start_coord, $end_coord, $strand, \@adjustedCoordsLines );
    }
    my $seq1_len = length( $seq1 );
    if( $seq1_len == 0 ) {
        webError( "Cannot read sequence for taxon_oid=$taxon " .
                  "scf_ext_accession='$scf_ext_accession'\n" );
    }

    my $highlightSpec;

    ## coords for upstream and downstream highlighting are computed the same
    ## whether a + or - strand gene is given.
    ## because when a - strand gene is given, it is also drawn 
    ## on the top (first line of sequence),
    ## its reverse complimentary (+ strand) is on the bottom (second line 
    ## of sequence). Therefore, the highlighting scheme is still like this:
    ## (left) upstream region in green + GENE + downstream region in green (right)
    ## - yjlin 2013-04-16

    my $us = -1 * $up_stream + $adjust_up;
    #print "us = $us (-1 * $up_stream + $adjust_up) <br>";

    #if ($strand eq "-") {
    #$us = 1 * $down_stream;
    #}

    $us = WebUtil::sanitizeInt( $us );
    $highlightSpec .= "1-$us green " if $us >= 1;

    my $codon1 = substr( $seq1, $us, 3 );
    if( isStartCodon( $codon1 ) ) {
        my $sc1 = $us + 1;
        my $sc2 = $sc1 + 3 - 1;
        $sc1 = WebUtil::sanitizeInt( $sc1 );
        $sc2 = WebUtil::sanitizeInt( $sc2 );
        $highlightSpec .= "$sc1-$sc2 red ";
    }

    my $ds1 = $seq1_len - $down_stream + $adjust_down + 1;
    #print "ds1 ($ds1) = seql len - downstream + adjust1 + 1 ";
    #print " ( $seq1_len - $down_stream + $adjust_down + 1)<br>";

    # if ($strand eq "-") {
    #     $ds1 = $seq1_len + $up_stream + 1;
    #}

    my $ds2 = $seq1_len;
    my $sc1 = $ds1 - 4;
    my $codon2 = substr( $seq1, $sc1, 3 );
    if( isStopCodon( $codon2 ) ) {
        $sc1 += 1;
        my $sc2 = $sc1 + 3 - 1;
        $sc1 = WebUtil::sanitizeInt( $sc1 );
        $sc2 = WebUtil::sanitizeInt( $sc2 );
        $highlightSpec .= "$sc1-$sc2 red ";
    }
    $ds1 = WebUtil::sanitizeInt( $ds1 );
    $ds2 = WebUtil::sanitizeInt( $ds2 );
    $highlightSpec .= "$ds1-$ds2 green " if $ds2 >= $ds1;
    chop $highlightSpec;

    #print 'highlightSpec ['. $highlightSpec .']<br>';
    #print 'sequence ['. $seq1 .']<br>';

    if ($format eq "graphics") {
        printSequence( $seq1, $start_coord, $end_coord,
                       $strand, 100, $highlightSpec );
    } else {
    	my $seq2 = WebUtil::wrapSeq( $seq1 );
        my $tmpInFile = "$cgi_tmp_dir/sixpack$$.fna";
        $tmpInFile = checkTmpPath( $tmpInFile );
        my $wfh = newWriteFileHandle( $tmpInFile, "printSixPack" );
        print $wfh ">$gene_oid\n";
        print $wfh "$seq2\n";
        close $wfh;

        my $tmpOutFile = "$cgi_tmp_dir/sixpack$$.out.txt";
        my $tmpSeqFile = "$cgi_tmp_dir/sixpack$$.out.faa";

    	$start_coord = WebUtil::sanitizeInt( $start_coord );
        my $cmd = "$sixpack_bin -sequence $tmpInFile ";
        $cmd .= "-offset $start_coord -orfminsize $orfminsize ";
        $cmd .= "-noname -nodescription ";
        $cmd .= "-html -outfile $tmpOutFile -outseq $tmpSeqFile ";
        $cmd .= "-highlight '$highlightSpec' ";

        ## Count the beginning of a sequence as a possible ORF, 
        ## even if it is inferior to the minimal ORF size.
        ## Count the end of a sequence as a possible ORF, 
        ## even if it is not finishing with a STOP, 
        ## or inferior to the minimal ORF size.
        #$cmd .= "-nofirst -nolast ";
        $cmd .= ' -firstorf -lastorf';

        WebUtil::unsetEnvPath();
        webLog( "+ $cmd\n" );
        my $st = system( $cmd );
        if ( $st != 0 ) {
            webDie( "status=$st '$cmd'\n" );
        }

        print "<hr/>\n";
        printHint("To test ORF translation, copy and paste the " .
                  "sequence to BLAST and InterPro scan.<br/>");

    	# Sixpack reports (by default) the ORFs at the 
    	# beginning and end of the sequence in case they are part 
    	# of a longer translation. Thus, ORFs shorter than the
    	# specified orfminsize are eliminated from output using
    	# -nofirst and -nolast
        print "<pre>\n";
    	my $idx = 0;
        my $rfh = newReadFileHandle( $tmpSeqFile, "printSixPack" );
        my $keep_this = 1;
        while( my $s = $rfh->getline() ) {
            chomp $s;
            if ( $s =~ />/ ) {
                my @s_split = split(',', $s);
                my $s_idx = scalar(@s_split) - 1;
                my $s_length_str = @s_split[$s_idx];
                $s_length_str =~ s/\s+//g; # trim out all spaces
                $s_length_str =~ s/aa//g;
                if ( $s_length_str < $orfminsize ) {
                    $keep_this = 0;
                    next;
                } else {
                    $keep_this = 1;
                }

        		print "<br/>\n" if ($idx > 0);
                print "<font color='blue'>$s</font>\n";

            } else {
                print "$s\n" if ( $keep_this eq 1 );
            }
    	    $idx++;
        }
        close $rfh;
        print "</pre>\n";

        wunlink( $tmpInFile );
        wunlink( $tmpOutFile );
        wunlink( $tmpSeqFile );
    }
    
    print end_form();
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printSequence - prints the sequence wrapped to page
############################################################################
sub printSequence {
    my( $seq, $start_coord, $end_coord, $strand, 
	$gc_window, $highlightSpec, $noGc, $seqhash_ref,
	$padding, $showgene, $myframe) = @_;

    my $start = param("start");
    if ($start eq "") {
        $start = 0;
    }

    print "<hr>\n";
    my $hintstr = "";
    if ($seqhash_ref) { 
	$hintstr =
           "<tr><td></td><td>".
	   "Click on the reading frame to see the alignments</td></tr>\n".
           "<tr><td></td><td>".
           "(only reading frames with alignments are shown as links)".
           "</td></tr>\n".
	   "<tr><td bgcolor='yellow'>&nbsp;&nbsp;&nbsp;</td>". 
           "<td>indicates potential start codon region</td></tr>\n".
           "<tr><td bgcolor='aqua'>&nbsp;&nbsp;&nbsp;</td>". 
           "<td>indicates possible Shine-Dalgarno region</td></tr>\n".
           "<tr><td bgcolor='#FFCCFF'>&nbsp;&nbsp;&nbsp;</td>". 
           "<td>indicates alignment of read fragment to gene protein".
           "</td></tr>\n".
           "<tr><td bgcolor='#CCCC99'>&nbsp;&nbsp;&nbsp;</td>". 
           "<td>indicates multiple alignments of read fragment ".
           "to gene protein</td></tr>\n";
    } elsif ($showgene eq "yes") {
	$hintstr =
           "<tr><td bgcolor='yellow'>&nbsp;&nbsp;&nbsp;</td>". 
           "<td>indicates potential start codon region</td></tr>\n". 
           "<tr><td bgcolor='aqua'>&nbsp;&nbsp;&nbsp;</td>". 
           "<td>indicates possible Shine-Dalgarno region</td></tr>\n".
           "<tr><td bgcolor='#FFCCFF'>&nbsp;&nbsp;&nbsp;</td>". 
           "<td>highlights the gene.</td></tr>\n";
    } else {
	$hintstr =
           "<tr><td bgcolor='yellow'>&nbsp;&nbsp;&nbsp;</td>".
	   "<td>indicates potential start codon region</td></tr>\n".
           "<tr><td bgcolor='aqua'>&nbsp;&nbsp;&nbsp;</td>".
           "<td>indicates possible Shine-Dalgarno region</td></tr>\n";
    }
    if (!$noGc || $noGc ne "y") {
	$hintstr .= 
	    "<tr><td><font color='blue'><b>---</b></font></td>".
	    "<td>blue line is the GC content graph</td></tr>";
    }
    printHint2($hintstr);

    print "<p><div id='container' class='yui-skin-sam'>";
    print qq { 
        <link rel="stylesheet" type="text/css"
          href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script type="text/javascript" 
            src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript" 
            src="$YUI/build/container/container-min.js"></script>
 
        <script type='text/javascript'>
            YAHOO.namespace("example.container"); 
            YAHOO.example.container.tt2 =
                new YAHOO.widget.Tooltip("tt2", { context:"link" });

            function initPanel() {
                YAHOO.example.container.panel1 = new YAHOO.widget.Panel
                  ("panel1", { 
                    // width:"400px",
                    visible:false, 
                    underlay:"none",
                    zindex:"10",
		    fixedcenter:true,
		    dragOnly:true,
                    // constraintoviewport:true,
                    // context:['anchor','tl','br']
                  } );
                YAHOO.example.container.panel1.render("container"); 
	    };
            YAHOO.util.Event.addListener(window, "load", initPanel);


	    function showAlignment(frame, alignArray) {
		var aligns = alignArray.split(":");
		var myText = "<pre><u>Frame: "+frame+"</u><br><br>";

		for (var i=0; i<aligns.length; i++) {
		    var items = aligns[i].split("#");
		    myText = myText+items[1]+"&nbsp;&nbsp;"+
			"Read("+items[2]+","+items[3]+")<br>"+
			"<font color='blue'>"+items[4]+"</font><br>"+
			items[5]+"&nbsp;&nbsp;"+
			"Gene("+items[6]+","+items[7]+")<br><br>"
		}

		myText = myText+"</pre>";
	        YAHOO.example.container.panel1.setHeader
		    ("Alignments of Read Fragment to Gene Protein");
                YAHOO.util.Dom.setStyle 
                (YAHOO.example.container.panel1.body, 
		 'font-family', 'monospace'); 
		YAHOO.example.container.panel1.setBody(myText);
	        YAHOO.example.container.panel1.render("container");
	        YAHOO.example.container.panel1.show();
	    } 
	</script>
    };

    my $len = 60;
    my $seqlen = length( $seq );
    my $cseq = WebUtil::getSequence( $seq, $seqlen, 1 );

    my %colors = highlightColorCoords( $highlightSpec ); 
    my @f1 = getTranslation( $seq, 0 );
    my @f2 = getTranslation( $seq, 1 ); 
    my @f3 = getTranslation( $seq, 2 );
    my @f4 = getTranslation( $cseq, 0 );
    my @f6 = getTranslation( $cseq, 1 );
    my @f5 = getTranslation( $cseq, 2 );
    my %features = getFeatures( $seq );
    my %cfeatures = getFeatures( $cseq );

    my %alignment_f0;
    my %alignment_f1;
    my %alignment_f2;
    my %alignment_r0; 
    my %alignment_r1; 
    my %alignment_r2; 
    if ($seqhash_ref) {
	%alignment_f0 = getAlignment( $seqhash_ref, "f", 0 );
	%alignment_f1 = getAlignment( $seqhash_ref, "f", 1 );
	%alignment_f2 = getAlignment( $seqhash_ref, "f", 2 );
        %alignment_r0 = getAlignment( $seqhash_ref, "r", 0 );
        %alignment_r1 = getAlignment( $seqhash_ref, "r", 1 );
        %alignment_r2 = getAlignment( $seqhash_ref, "r", 2 );

	#my @align_array = @{ $alignment_f1{ 'f1' }};
	#my $align_array =  $alignment_f1{ 'f1' };
	#print "\nALIGN: "."@{$align_array}";
	#my $align_array = join(':', @{$alignment_f1{ 'f1' }});
	#print "\nALIGN: "."$align_array";
    }

    # find which frame the gene is on, 
    # using the start coordinate:
    my $fidx;
    my $gene_frame = "";
    if ($padding ne "") {
	if ($strand eq "-") {
	    $fidx = $padding;
	    $gene_frame = "r0" if $f4[ $fidx ] ne " ";
	    $gene_frame = "r2" if $f5[ $fidx ] ne " ";
	    $gene_frame = "r1" if $f6[ $fidx ] ne " ";
	} else {
	    $fidx = $padding;
	    $gene_frame = "f0" if $f1[ $fidx ] ne " ";
	    $gene_frame = "f1" if $f2[ $fidx ] ne " ";
	    $gene_frame = "f2" if $f3[ $fidx ] ne " ";
	}
    }

    my $style = " style='font-size: 11px; "
	. "font-family: Arial,Helvetica,sans-serif; "
	. "line-height: 1.0em;' ";
    my $style2 = " style='font-size: 10px; "
	. "font-family: Arial,Helvetica,sans-serif; "
	. "line-height: 1.0em;' ";
    my $style3 = " style='font-size: 11px; "
	. "font-family: Arial,Helvetica,sans-serif; "
	. "line-height: 1.0em; "
	. "width: 80px;' ";

    for ( my $idx = 0; $idx < $seqlen; $idx += $len ) {
        my $start_coord2 = $start_coord + $idx;
        my $range = $idx + $len;
        if ($range > $seqlen) {
            $len = $seqlen - $idx;
        }
        
        my @gc_data;    # gc data for the chart
 
	my $tableW = 80 + (720 * $len / 60);
        print "<table style='table-layout: fixed;' "
	    . "width=$tableW border=0 cellpadding=0 cellspacing=0>";
        print "<tr>";
        if ($seqhash_ref && %alignment_f0) { 
            my $frame = 'f0'; 
            my $align_array = join(':', @{$alignment_f0{ 'f0' }});
            my $link = 
		"javascript:showAlignment(\"$frame\", \"$align_array\")";
            print "<td $style3 id='anchor'><a href='$link'>F1</a></td>";
        } else {
            print "<td $style3 id='anchor'>F1</td>"; 
        } 
        for ( my $i = 0; $i < $len; $i++ ) {
            my $f1 = $f1[ $idx + $i ]; 
            my $offset = $idx + $i; 
            my $index = $seqlen - $offset - 1;
            if (%alignment_f0) {
                my $value; 
                my $align = ' '; 
                if( $value = $alignment_f0{ $idx + $i } ) {
		    if (length($value) > 1) {
			$align = "bgcolor='#CCCC99'";
		    } else {
			$align = "bgcolor='#FFCCFF'";
		    }
                } 
 
                print "<td ".$align." $style"
		    . " id='link' title=".$value.">";
                print "$f1"; 
                print "</td>";

            } elsif ('f0' eq $gene_frame &&
                     $index >= $padding && $index <= ($seqlen-$padding)) {
                my $align = "bgcolor='#FFCCFF'";
                print "<td ".$align." $style>"; 
                print "$f1"; 
                print "</td>"; 

            } else { 
                print "<td $style>";
                print "$f1";
                print "</td>";
            } 
        } 
        
        print "</tr>\n"; 
	print "<tr>";
	if ($seqhash_ref && %alignment_f1) {
	    my $frame = 'f1';
	    my $align_array = join(':', @{$alignment_f1{ 'f1' }});
	    my $link = 
		"javascript:showAlignment(\"$frame\", \"$align_array\")";
	    print "<td $style3><a href='$link'>F2</a></td>"; 
	} else {
	    print "<td $style3>F2</td>"; 
	}
        for ( my $i = 0; $i < $len; $i++ ) { 
            my $f2 = $f2[ $i + $idx ];
            my $offset = $idx + $i; 
            my $index = $seqlen - $offset - 1;
	    if (%alignment_f1) {
		my $value; 
		my $align = ' '; 
		if( $value = $alignment_f1{ $idx + $i } ) { 
                    if (length($value) > 1) {
                        $align = "bgcolor='#CCCC99'";
                    } else { 
                        $align = "bgcolor='#FFCCFF'";
                    } 
		} 

		print "<td ".$align 
		    ." $style id='link' title=".$value.">"; 
		print "$f2"; 
		print "</td>"; 

            } elsif ('f1' eq $gene_frame &&
                     $index >= $padding && $index <= ($seqlen-$padding)) {
                my $align = "bgcolor='#FFCCFF'";
                print "<td ".$align." $style>"; 
                print "$f2"; 
                print "</td>"; 

	    } else {
		print "<td $style>";
		print "$f2";
		print "</td>";
	    }
        } 
        
        print "</tr>\n"; 
        print "<tr>";
        if ($seqhash_ref && %alignment_f2) { 
            my $frame = 'f2'; 
            my $align_array = join(':', @{$alignment_f2{ 'f2' }});
            my $link = 
		"javascript:showAlignment(\"$frame\", \"$align_array\")";
            print "<td $style3><a href='$link'>F3</a></td>";
        } else {
            print "<td $style3>F3</td>"; 
        } 
        for ( my $i = 0; $i < $len; $i++ ) {
            my $f3 = $f3[ $idx + $i ];
            my $offset = $idx + $i; 
            my $index = $seqlen - $offset - 1;
            if (%alignment_f2) {
                my $value; 
                my $align = ' '; 
                if( $value = $alignment_f2{ $idx + $i } ) {
                    if (length($value) > 1) { 
                        $align = "bgcolor='#CCCC99'"; 
                    } else { 
                        $align = "bgcolor='#FFCCFF'";
                    }
                } 
 
                print "<td ".$align 
                    . " $style id='link' title=".$value.">";
                print "$f3"; 
                print "</td>";

            } elsif ('f2' eq $gene_frame &&
                     $index >= $padding && $index <= ($seqlen-$padding)) {
                my $align = "bgcolor='#FFCCFF'";
                print "<td ".$align." $style>"; 
                print "$f3"; 
                print "</td>"; 

            } else { 
                print "<td $style>";
                print "$f3";
                print "</td>";
            } 
        } 
        
        print "</tr>\n"; 
        print "<tr>"; 
        print "<td $style3><font color='teal'>GC</font></td>"; 
        for ( my $i = 0; $i < $len; $i++ ) { 
            my $gc1 = getGc( $seq, $idx + $i, $len, $gc_window );
            print "<td $style2><font color='teal'>"; 
            print "$gc1"; 
            print "</font></td>"; 
            push @gc_data, $gc1;
        } 

        print "</tr>\n";

        # CHART for GC ####################
        if (!$noGc || $noGc ne "y") {
	    my $chart = newLineChart(); 
	    my $width = 720 * $len / 60;

	    $chart->WIDTH($width);
	    $chart->HEIGHT(50); 
	    $chart->INCLUDE_TOOLTIPS("yes"); 

	    my @chartcategories; 
	    push @chartcategories, "gc";
	    $chart->CATEGORY_NAME(\@chartcategories);
	    my $datastr = join(",", @gc_data);
	    my @datas = ($datastr); 
	    $chart->DATA(\@datas); 

	    my $st = -1;
	    if ($env->{ chart_exe } ne "") {
		$st = generateChart($chart); 

		print "<tr>";
		print "<td $style2>&nbsp;</td>"; 
		print "<td width=$width align='left' colspan=$len>";

		if ($st == 0) {
		    my $FH = newReadFileHandle
			( $chart->FILEPATH_PREFIX . ".html",
			  "six-frame-translation", 1 );
		    while ( my $s = $FH->getline() ) {
			print $s; 
		    }
		    close($FH); 
		    print "<img src='$tmp_url/"
			. $chart->FILE_PREFIX.".png' BORDER=0 "; 
		    print " width=".$chart->WIDTH." HEIGHT=".$chart->HEIGHT; 
		    print " USEMAP='#" . $chart->FILE_PREFIX . "'>";
		}
		print "</td></tr>\n"; 
	    }
        }
        ###################################

        print "<tr>";
        print "<td $style3 id='link'>$start_coord2&nbsp;&nbsp;&nbsp;</td>";
        for ( my $i = 0; $i < $len; $i++ ) { 
            my $offset = $i + $idx;
            my $pos = $start_coord + $offset; 
            
            my $na = substr( $seq, $offset, 1 ); 
            my( $x1, $x2 ); 
            my $color = $colors{ $offset }; 
            if( $color ne "" ) { 
                $x1 = "<font color='$color'>"; 
                $x2 = "</font>"; 
            } 
            
            my $startCodonCode1 = "bgcolor='silver'"; 
            my $shineDalgarnoCode1 = ' '; 
            my $startCodonCode2 = "bgcolor='silver'"; 
            my $shineDalgarnoCode2 = ' '; 
            if( $features{ $offset } =~ /start-codon/ ) { 
                $startCodonCode1 = "bgcolor='yellow'"; 
            } 
            if( $features{ $offset } =~ /shine-dalgarno/ ) { 
                $shineDalgarnoCode1 = "bgcolor='aqua'"; 
                $startCodonCode1 = ' '; 
            } 
            
            print "<td ".$startCodonCode1.$shineDalgarnoCode1
                ." $style id='link' title=".$pos.">";
            print "$x1$na$x2"; 
            print "</td>"; 
        }
        
        print "</tr>\n";
        print "<tr>"; 
        print "<td $style3>&nbsp;</td>";
        for ( my $i = 0; $i < $len; $i++ ) { 
            my $symbol = "-";
            if ($i == 1) { 
                $symbol = ":";
            }
            elsif ($i == 6) {
                $symbol = "|";
            }
            elsif ($i < 11) { 
                $symbol = "-";
            }
            elsif (($i-6)%10 == 0) {
                $symbol = "|";
            }
            elsif (($i-6)%5 == 0) { 
                $symbol = ":";
            }
            print "<td $style align='center'>";
            print $symbol;
            print "</td>";
        }
        
        print "</tr>\n";
        print "<tr>"; 
        print "<td $style3>$start_coord2&nbsp;&nbsp;&nbsp;</td>"; 
        for ( my $i = 0; $i < $len; $i++ ) {
            my $offset = $idx + $i;
            my $pos = $start_coord + $offset;

            my $na = substr( $seq, $offset, 1 );
            my $cna = $na;
            $cna =~ tr/actgACTG/tgacTGAC/;
            
            my $startCodonCode2 = "bgcolor='silver'";
            my $shineDalgarnoCode2 = ' ';
            my $k = $seqlen - $offset - 1;
            if( $cfeatures{ $k } =~ /start-codon/ ) {
                $startCodonCode2 = "bgcolor='yellow'";
            }
            if( $cfeatures{ $k } =~ /shine-dalgarno/ ) {
                $shineDalgarnoCode2 = "bgcolor='aqua'";
                $startCodonCode2 = ' '; 
            }
            
            print "<td ".$startCodonCode2.$shineDalgarnoCode2
                ." $style id='link' title=".$pos.">";
            print "$cna";
            print "</td>"; 
        }
        
        print "</tr>\n";
        print "<tr color=blue'>"; 
        print "<td $style3><font color='teal'>GC</font></td>"; 
        for ( my $i = 0; $i < $len; $i++ ) {
            my $offset = $idx + $i;
            my $gc1 = getGc( $seq, $offset, $len, $gc_window );
            my $gc2 = 100 - $gc1; 
            print "<td $style2><font color='teal'>";
            print "$gc2";
            print "</font></td>"; 
        } 
        
        print "</tr>\n"; 
        print "<tr>";
        if ($seqhash_ref && %alignment_r1) { 
            my $frame = 'r1'; 
            my $align_array = join(':', @{$alignment_r1{ 'r1' }});
            my $link = 
		"javascript:showAlignment(\"$frame\", \"$align_array\")";
            print "<td $style3><a href='$link'>F6</a></td>";
        } else {
            print "<td $style3>F6</td>"; 
        } 
        for ( my $i = 0; $i < $len; $i++ ) { 
            my $offset = $idx + $i;
            my $f6 = $f6[ $seqlen - $offset - 1 ];
            my $index = $seqlen - $offset - 1;
            if (%alignment_r1) {
                my $value; 
                my $align = ' '; 
                if( $value = $alignment_r1{ $seqlen - $offset - 1 } ) { 
                    if (length($value) > 1) { 
                        $align = "bgcolor='#CCCC99'"; 
                    } else { 
                        $align = "bgcolor='#FFCCFF'";
                    }
                }
 
                print "<td ".$align 
                    . " $style id='link' title=".$value.">";
                print "$f6"; 
                print "</td>"; 

            } elsif ('r1' eq $gene_frame &&
                     $index >= $padding && $index <= ($seqlen-$padding)) {
                my $align = "bgcolor='#FFCCFF'";
                print "<td ".$align." $style>"; 
                print "$f6"; 
                print "</td>"; 

            } else { 
                print "<td $style>";
                print "$f6";
                print "</td>"; 
            }
        } 
 
        print "</tr>\n"; 
        print "<tr>"; 
        if ($seqhash_ref && %alignment_r2) { 
            my $frame = 'r2'; 
            my $align_array = join(':', @{$alignment_r2{ 'r2' }});
            my $link = 
		"javascript:showAlignment(\"$frame\", \"$align_array\")";
            print "<td $style3><a href='$link'>F5</a></td>";
        } else {
            print "<td $style3>F5</td>"; 
        } 
        for ( my $i = 0; $i < $len; $i++ ) {
            my $offset = $idx + $i;
            my $f5 = $f5[ $seqlen - $offset - 1 ];
            my $index = $seqlen - $offset - 1;
            if (%alignment_r2) {
                my $value; 
                my $align = ' '; 
                if( $value = $alignment_r2{ $seqlen - $offset - 1 } ) { 
                    if (length($value) > 1) { 
                        $align = "bgcolor='#CCCC99'"; 
                    } else { 
                        $align = "bgcolor='#FFCCFF'";
                    }
                }
 
                print "<td ".$align 
                    . " $style id='link' title=".$value.">";
                print "$f5"; 
                print "</td>"; 

	    } elsif ('r2' eq $gene_frame &&
		     $index >= $padding && $index <= ($seqlen-$padding)) {
		my $align = "bgcolor='#FFCCFF'";
		print "<td ".$align." $style>"; 
		print "$f5"; 
		print "</td>"; 
		
            } else { 
                print "<td $style>";
                print "$f5";
                print "</td>"; 
            }
        } 
        
        print "</tr>\n"; 
        print "<tr>";
        if ($seqhash_ref && %alignment_r0) { 
            my $frame = 'r0'; 
            my $align_array = join(':', @{$alignment_r0{ 'r0' }});
            my $link = 
		"javascript:showAlignment(\"$frame\", \"$align_array\")";
            print "<td $style3><a href='$link'>F4</a></td>";
        } else {
            print "<td $style3>F4</td>"; 
        } 
        for ( my $i = 0; $i < $len; $i++ ) {
            my $offset = $idx + $i;
            my $f4 = $f4[ $seqlen - $offset - 1 ];
	    my $index = $seqlen - $offset - 1;
            if (%alignment_r0) {
                my $value; 
                my $align = ' '; 
                if( $value = $alignment_r0{ $seqlen - $offset - 1 } ) { 
                    if (length($value) > 1) { 
                        $align = "bgcolor='#CCCC99'"; 
                    } else { 
                        $align = "bgcolor='#FFCCFF'";
                    }
                }
 
                print "<td ".$align 
                    . " $style id='link' title=".$value.">";
                print "$f4"; 
                print "</td>"; 

	    } elsif ('r0' eq $gene_frame &&
		     $index >= $padding && $index <= ($seqlen-$padding)) {
                my $align = "bgcolor='#FFCCFF'";
                print "<td ".$align." $style>";
                print "$f4";
                print "</td>";

            } else { 
                print "<td $style>";
                print "$f4";
                print "</td>"; 
            }
        } 
        
        print "</tr>\n";
        print "</table>";
        print "<br>";
        print "<br>";
    }
    print "</div>\n";
}

############################################################################
# getAlignment - Get the alignment given offset.
############################################################################
sub getAlignment {
    my( $seqhash_ref, $type, $offset ) = @_;

    my $frame = $type.$offset;
    my $value_array_ref = $seqhash_ref->{$frame};
    my $value = @$value_array_ref[0]; 

    my ( $translation, $rest ) = split( /\t/, $value );
    my $size = @$value_array_ref; 

    my $len = length( $translation );
    my $index = 0;
    for( my $i = 0; $i < $offset; $i++ ) {
       $index++;
    }

    ## convert tab separators to # for javascript 
    ## javascript seems to read tabs and newlines as spaces
    my %h;
    my @align_array;
    for (my $i=0; $i < $size; $i++) {
        my $value1 = @$value_array_ref[$i];
	my $value2 = join('#', split(/\t/, $value1));
        push(@align_array, $value2);
        @{$h{ $frame }} = @align_array;
    }

    my %shash;
    for (my $j=0; $j < $size; $j++) {
	my $value = @$value_array_ref[$j];
	#print "\nVALUE:::$value";
	my( $translation, $read_seq, $r_start_coord, $r_end_coord, 
	    $align_seq, $gene_seq, $g_start_coord, $g_end_coord ) = 
		split( /\t/, $value );
	
	my @align_chars = split(//, $align_seq);
	my $end = $r_end_coord - $r_start_coord + 1;
	if ($end > length($read_seq)) {
	    $end = length($read_seq);
	}
	for (my $k=0; $k < $end; $k++) {
	    my $achar = ' ';
	    if (exists $align_chars[$k]) {
		$achar = $align_chars[$k];
	    }
	    $shash{ ($r_start_coord+$k-1) } .= $achar;
	}
    }

    ### add the extra spaces to the hash index keys
    for( my $i = 0; $i < $len; $i++ ) {
	my $value = $shash{ $i };
	if (exists $shash{ $i }) {
	    $h{ $index++ } = $value;
	    my $blank = ' ';
	    if (length($value) > 1) {
		$blank = '  ';
	    }  
	    $h{ $index++ } = $blank;
	    $h{ $index++ } = $blank;
	} else {
	    $index = $index + 3;
	}
    }

    return %h;
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
# getTranslationAsString - Return translation as a string
############################################################################ 
sub getTranslationAsString { 
    my( $seq, $offset ) = @_; 
 
    my $len = length( $seq ); 
    my $a; 
    for( my $i = $offset; $i < $len; $i += 3 ) { 
	my $codon = substr( $seq, $i, 3 ); 
	my $aa = geneticCode( $codon ); 
	$aa = ' ' if $aa eq ""; 
	$a .= $aa;
    } 
    return $a; 
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
               my $codon2 = substr( $seq, $j, 3 );
               if( isStartCodon( $codon2 ) ) {
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

