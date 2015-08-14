###########################################################################
# DotPlot.pm - Runs mummer for two genomes
# $Id: DotPlot.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package DotPlot;
my $section = "DotPlot";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use InnerTable;
use WebConfig;
use WebUtil;
use ChartUtil;
use GenomeListJSON;

$| = 1;

my $env = getEnv();
my $cgi_dir = $env->{ cgi_dir };
my $cgi_url  = $env->{ cgi_url };
my $tmp_url = $env->{ tmp_url };
my $tmp_dir = $env->{ tmp_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $taxon_fna_dir = $env->{ taxon_fna_dir };
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=TaxonDetail";
my $verbose = $env->{ verbose };
my $base_dir = $env->{ base_dir };
my $base_url = $env->{ base_url };
my $mummer_dir = $env->{ mummer_dir };
my $include_metagenomes = $env->{ include_metagenomes };
my $perl = $env->{ perl_bin };

my $nvl = getNvl();
my $YUI = $env->{ yui_dir_28 };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    my $page = param("page");
    timeout( 60 * 40 );    # timeout in 40 minutes (from main.pl)
    if ($page eq "plot") {
        printStatusLine("Loading ...", 1);

	my $note = getNote();
	if ($include_metagenomes) {
	    WebUtil::printHeaderWithInfo
		("DotPlot", $note,
		 "show description for this tool",
		 "Dot Plot Info", 1, "Dotplot.pdf");
	} else {
	    WebUtil::printHeaderWithInfo
		("DotPlot", $note,
		 "show description for this tool",
		 "Dot Plot Info", 0, "Dotplot.pdf");
	}
	print "<p style='width: 950px;'>$note</p>\n";

        printMainForm();
	print "<p>\n";
	print "<font color='#003366'>"
	    . "Please select 2 genomes."
	    . "</font>\n";
	printForm();

	print "<p>\n";
	print "<b>Algorithm</b>:<br/>\n";
	print "<input type='radio' name='algorithm' "
	    . "value='nucmer' checked />"
	    . "Nucleotide sequence based comparisons<br/>\n";
	print "<input type='radio' name='algorithm' "
	    . "value='promer' />"
	    . "Protein sequence based comparisons<br/>\n";
	print "</p>\n";

        print "<p>\n";
        print "<b>Reference</b>:<br/>\n";
        print "<input type='radio' name='reference' "
            . "value='1' checked />Use 1 as reference<br/>\n";
        print "<input type='radio' name='reference' "
            . "value='2' />Use 2 as reference<br/>\n";
        print "</p>\n";

        my $name = "_section_DotPlot_runPlot";
	GenomeListJSON::printHiddenInputType( $section, 'runPlot' );
	my $button = GenomeListJSON::printMySubmitButtonXDiv
	    ( 'go', $name, 'Dotplot', '', $section,
	      'runPlot', 'meddefbutton', 'selectedGenome1', 2 );
	print $button;

        print nbsp(1);
	print reset( -class => "smbutton" );
        print end_form();
	GenomeListJSON::showGenomeCart($numTaxon);

    } elsif (paramMatch("runPlot") ne "") {
	runPlot();
    } elsif (paramMatch("continuePlot") ne "") {
	param("continue", "yes");
        runPlot();
    }
}

sub printForm {
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new
        ( filename => "$base_dir/genomeJsonOneDiv.html" );

    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( isolate      => 1 );
    $template->param( all          => 0 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => 2 );
    $template->param( selectedGenome1Title => 'Please select 2 genomes:' );

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;
}

sub getNote {
    my $url1 = "http://mummer.sourceforge.net/manual/";
    my $url2 = "http://mummer.sourceforge.net/examples/#nucmernucmer";
    my $url3 = "http://mummer.sourceforge.net/examples/#promerpromer";
    my $note =
        "<b>Dot Plot</b> employs <a href=$url1 target=_blank>Mummer</a> "
      . "to generate dotplot diagrams between two genomes. It uses input "
      . "DNA sequences directly for comparing genomes with similar "
      . "sequences (<a href=$url2 target=_blank>NUCmer</a>). It uses the "
      . "six frame amino acid translation of the DNA input sequences "
      . "(<a href=$url3 target=_blank>PROmer</a>) for comparing genomes "
      . "with dissimilar sequences (because the DNA sequence is not as "
      . "highly conserved as the amino acid translation).";
    return $note;
}

############################################################################
# runPlot - calls mummer
#     MUMmer program - takes as input two fasta sequence files
############################################################################
sub runPlot {
    my $algorithm = param( "algorithm" );
    my $reference = param( "reference" );
    my $continue = param( "continue" );
    my @scaffolds1 = param( "scaffold_oid1" );
    my @scaffolds2 = param( "scaffold_oid2" );

    my @oids;
    if ($continue ne "") {
	my $idstr = param("oids");
	@oids = split(",", $idstr);
    } else {
	@oids = param("selectedGenome1");
    }

    my $nTaxons = @oids;
    if ( $nTaxons != 2 ) {
	webError( "Please select 2 genomes.<br/>\n" );
    }

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $sql = qq{
	select taxon_display_name, seq_status, genome_type
	from taxon
	where taxon_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $oids[0] );
    my ($name1, $seq_status1, $genome_type1) = $cur->fetchrow();
    $cur->finish();
    my $cur = execSql( $dbh, $sql, $verbose, $oids[1] );
    my ($name2, $seq_status2, $genome_type2) = $cur->fetchrow();
    $cur->finish();

    if ($genome_type1 eq "metagenome" || $genome_type2 eq "metagenome") {
	webError("Currently this tool does not support metagenomes. "
	       . "Please select isolate genomes only.");
    }

    my $sql = qq{
	select ext_accession
	from scaffold
	where taxon = ?
	and ext_accession is not null
    };

    my @ext_accessions1;
    if (scalar @scaffolds1 > 0 && $continue eq "no") {
	my $scaffold_oids_str1 = join(",", @scaffolds1);
	my $sql0 = qq{
	    select distinct ext_accession
	    from scaffold
	    where taxon = ?
	    and scaffold_oid in ($scaffold_oids_str1)
	    and ext_accession is not null
	};
        my $cur = execSql( $dbh, $sql0, $verbose, $oids[0] );
        for ( ;; ) {
            my ($ext_accession) = $cur->fetchrow();
            last if !$ext_accession;
            push( @ext_accessions1, $ext_accession);
        }
        $cur->finish();
    } else {
	my $cur = execSql( $dbh, $sql, $verbose, $oids[0] );
	for ( ;; ) {
	    my ($ext_accession) = $cur->fetchrow();
	    last if !$ext_accession;
	    push( @ext_accessions1, $ext_accession);

	}
	$cur->finish();
    }

    my @ext_accessions2;
    if (scalar @scaffolds2 > 0 && $continue eq "no") {
        my $scaffold_oids_str2 = join(",", @scaffolds2);
        my $sql0 = qq{
            select distinct ext_accession
            from scaffold
            where taxon = ?
            and scaffold_oid in ($scaffold_oids_str2)
            and ext_accession is not null
        };
        my $cur = execSql( $dbh, $sql0, $verbose, $oids[1] );
        for ( ;; ) {
            my ($ext_accession) = $cur->fetchrow();
            last if !$ext_accession;
            push( @ext_accessions2, $ext_accession);
        }
        $cur->finish();
    } else {
	my $cur = execSql( $dbh, $sql, $verbose, $oids[1] );
	for ( ;; ) {
	    my ($ext_accession) = $cur->fetchrow();
	    last if !$ext_accession;
	    push( @ext_accessions2, $ext_accession);

	}
	$cur->finish();
    }

    my $nScaffolds1 = scalar @ext_accessions1;
    my $nScaffolds2 = scalar @ext_accessions2;
    if ( $reference eq "2" ) {
	$nScaffolds1 = scalar @ext_accessions2;
	$nScaffolds2 = scalar @ext_accessions1;
    }

    if ($continue eq "") {
	my $max_scaffolds = 150;
	if ((scalar @ext_accessions1 > $max_scaffolds &&
	     scalar @ext_accessions2 > $max_scaffolds) ||
	    (scalar @ext_accessions1 > 2 * $max_scaffolds) ||
	    (scalar @ext_accessions2 > 2 * $max_scaffolds)) {
	    selectScaffolds($dbh, \@oids, $algorithm, $reference);
	    printStatusLine( "Done.", 2 );
	    #$dbh->disconnect();
	    return;
	}
    }

    ### get the fasta file for all scaffolds for each genome:
    my $tmpFile1 = "$taxon_fna_dir/$oids[0].fna";
    my $tmpFile2 = "$taxon_fna_dir/$oids[1].fna";
    if ( $reference eq "2" ) {
        $tmpFile1 = "$taxon_fna_dir/$oids[1].fna";
        $tmpFile2 = "$taxon_fna_dir/$oids[0].fna";
    }

    my $length1 = 0;
    my $txt = "";
    my $write = 0;

    if (scalar @scaffolds1 > 0 && $continue eq "no") {
	my $tmpFile = "$cgi_tmp_dir/scaffolds1.fna$$.txt";
	my $wfh = newWriteFileHandle( $tmpFile, "runPlot" );

	my $file = "$taxon_fna_dir/$oids[0].fna";
	my $rfh  = newReadFileHandle($file);
	while ( my $line = $rfh->getline() ) {
	    chomp $line;
	    # see if the line starts with ">scaffold name"
	    if ($line=~/^>/) {
		$write=0;
		foreach my $acc1 (@ext_accessions1) {
		    if ($line=~/\s*$acc1\s*/) {
			$write=1;
		    }
		}
	    }
	    if ($write==1) {
		$length1 += length($line);
		print $wfh "$line\n";
	    }
	}
	close $rfh;
	close $wfh;

	if ( $reference eq "2" ) {
	    $tmpFile2 = $tmpFile;
	} else {
	    $tmpFile1 = $tmpFile;
	}
	if ($length1 > 536870908) {
	    $txt = "$tmpFile is $length1 in length.";
	}
    }

    my $length2 = 0;
    if (scalar @scaffolds2 > 0 && $continue eq "no") {
        my $tmpFile = "$cgi_tmp_dir/scaffolds2.fna$$.txt";
        my $wfh = newWriteFileHandle( $tmpFile, "runPlot" );

	my $file = "$taxon_fna_dir/$oids[1].fna";
	my $rfh  = newReadFileHandle($file);
	while ( my $line = $rfh->getline() ) {
	    chomp $line;
	    # see if the line starts with ">scaffold name"
	    if ($line=~/^>/) {
		$write=0;
		foreach my $acc2 (@ext_accessions2) {
		    if ($line=~/\s*$acc2\s*/) {
			$write=1;
		    }
		}
	    }
	    if ($write==1) {
		$length2 += length($line);
		print $wfh "$line\n";
	    }
	}
	close $rfh;
        close $wfh;

        if ( $reference eq "2" ) {
            $tmpFile1 = $tmpFile;
        } else {
            $tmpFile2 = $tmpFile;
        }
	if ($length2 > 536870908) {
	    $txt = "$tmpFile is $length2 in length.";
	}
    }

#    if ($length1 > 536870908 || $length2 > 536870908) {
#        printStatusLine( "Input file is too large.", 2 );
#        #$dbh->disconnect();
#	webError( "Input file length cannot exceed 536870908.<br/> $txt"
#		. "<br/>Please select fewer scaffolds." );
#    }

    my $returnval = -s $tmpFile1;
    print STDERR "\n\nDotPlot: $returnval\n";
    if ( $returnval == 0 ) {
        printStatusLine( "Cannot read sequence.", 2 );
	#$dbh->disconnect();
        webError( "Sequence file for taxon_oid=$oids[0] " .
                  "is empty\n" );
    }
    my $returnval = -s $tmpFile2;
    print STDERR "\n\nDotPlot: $returnval\n";
    if ( $returnval == 0 ) {
        printStatusLine( "Cannot read sequence.", 2 );
	#$dbh->disconnect();
        webError( "Sequence file for taxon_oid=$oids[1] " .
                  "is empty\n" );
    }

    #my $algorithm = param( "algorithm" );
    my $method = "nucmer";
    if ( $algorithm eq "promer" ) {
	$method = "promer";
    }

    #my $reference = param( "reference" );
    #if ( $reference eq "2" ) {
    #	$tmpFile1 = "$taxon_fna_dir/$oids[1].fna";
    #	$tmpFile2 = "$taxon_fna_dir/$oids[0].fna";
    #} else {
    #	$tmpFile1 = "$taxon_fna_dir/$oids[0].fna";
    #	$tmpFile2 = "$taxon_fna_dir/$oids[1].fna";
    #}

    my $deltaFile  = $tmp_dir . "/ref_qry$$.delta";
    my $coordsFile = $tmp_dir . "/ref_qry$$.coords";
    my $alignsFile = $tmp_dir . "/ref_qry$$.aligns";
    my $filterFile = $tmp_dir . "/ref_qry$$.filter";
    my $st = 0;

    # to prevent Perl -Taint error
    $tmpFile1 = checkPath($tmpFile1);
    $tmpFile2 = checkPath($tmpFile2);

    printStartWorkingDiv();
    print "Running $nScaffolds1 scaffolds against $nScaffolds2 scaffolds.<br/>";
    print "Calling $method to generate cluster and delta files.<br/>";

    open my $oldout, ">&STDOUT";
    WebUtil::unsetEnvPath();
    my $cmd = "$mummer_dir/$method --maxgap=500 --mincluster=100 "
	. "--prefix=$tmp_dir/ref_qry$$ $tmpFile1 $tmpFile2";

    $st = runCmdNoExit($cmd);
    print STDERR "\n$st";

    print "Calling show-coords to parse the delta alignment.<br/>";
    $cmd = "$mummer_dir/show-coords -rcl $deltaFile";
    close STDOUT;
    open STDOUT, "+>", $coordsFile;
    $st = runCmdNoExit($cmd);
    print STDERR "\n$st";

    close STDOUT;
    open STDOUT, ">&", $oldout;
    print "Calling show-aligns to parse the delta alignment. ";

    close STDOUT;
    open STDOUT, "+>", $alignsFile;
    for my $id1( @ext_accessions1 ) {
	for my $id2( @ext_accessions2 ) {
	    if ( $reference eq "2" ) {
		$cmd = "$mummer_dir/show-aligns $deltaFile $id2 $id1";
	    } else {
		$cmd = "$mummer_dir/show-aligns $deltaFile $id1 $id2";
	    }
	    close STDOUT;

	    open STDOUT, ">&", $oldout;
	    print ". ";
	    close STDOUT;

	    open STDOUT, ">>", $alignsFile;
	    $st = runCmdNoExit($cmd);
            # webLog "status: $st";
	    print STDERR "\n$st";
	}
    }

    close STDOUT;
    open STDOUT, ">&", $oldout;
    print "<br/>";

    my $returnval = -s $alignsFile;
    print STDERR "\n\nDotPlot: $returnval\n";
    ### need to check if $alignsFile is empty ###
    if ($returnval == 0) {
    	printStatusLine( "No alignments.", 2 );
	#$dbh->disconnect();
        webError( "No alignments found.<br/>\n" );
    }

    print "Calling delta-filter to output only the desired alignments.<br/>";
    $cmd = "$mummer_dir/delta-filter -q -r $deltaFile";

    close STDOUT;
    open STDOUT, ">", $filterFile;
    $st = runCmdNoExit($cmd);
    print STDERR "\n$st";

    close STDOUT;
    $cmd = "$cgi_dir/mummerplot-basic.pl -p $tmp_dir/out$$ $filterFile "
	. "-R $tmpFile1 -Q $tmpFile2 --filter --layout";
    $st = runCmdNoExit("$perl -I $mummer_dir/scripts $cmd");
    print STDERR "\n$st";

    WebUtil::resetEnvPath();

    open STDOUT, ">&", $oldout;

    printEndWorkingDiv();

    my $url1 = "$main_cgi?section=TaxonDetail"
	     . "&page=taxonDetail&taxon_oid=$oids[0]";
    my $url2 = "$main_cgi?section=TaxonDetail"
	     . "&page=taxonDetail&taxon_oid=$oids[1]";
    my $link1 = alink($url1, $name1);
    my $link2 = alink($url2, $name2);

    my $label1 = $name1;
    my $label2 = $name2;
    if ( $reference eq "2" ) {
	print "<h2>$name2 vs. <br/>$name1</h2>\n";
	$label1 = $name2;
	$label2 = $name1;
    } else {
	print "<h2>$name1 vs. <br/>$name2</h2>\n";
    }

    print "<p>Using <u>$method</u> to compare genomes:</p>";

    #### PREPARE THE DOTCHART ######
    my $url = "xml.cgi?section=GeneDetail&page=neighborhoodAlignment";
    my $chart = newDotChart();
    $chart->WIDTH(800);
    $chart->HEIGHT(540);
    $chart->DOMAIN_AXIS_LABEL($label1);
    $chart->RANGE_AXIS_LABEL($label2);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($url);
    $chart->INCLUDE_SECTION_URLS("yes");
    $chart->IMAGEMAP_ONCLICK('neighborhood');

    my @xchartdata;
    my @ychartdata;
    my @xydirdata;
    my @chartscaffolds;
    #################################

    my $sql = "select scaffold_oid, ext_accession from scaffold "
            . "where taxon in ($oids[0], $oids[1]) and ext_accession = ?";

    my @scaffolddata;
    my $FH = newReadFileHandle("$tmp_dir/out$$.gp", "dotplot", 1);
    while (my $s = $FH->getline()) {
	chomp $s;
        my( $a, $scf, $coord) = split( /:/, $s );
	if (!$scf || $scf eq "") {
	    push @scaffolddata, "$a: : :$coord";
	    next;
	}
	my $cur = execSql( $dbh, $sql, $verbose, $scf );
	for( ;; ) {
	    my ( $scaffold_oid, $ext_accession ) = $cur->fetchrow();
	    last if !$scaffold_oid;
	    push @scaffolddata, "$a:$scaffold_oid:$ext_accession:$coord";
	}
	$cur->finish();
    }
    close($FH);
    #$dbh->disconnect();

    my $scaffolddatastr = join(",", @scaffolddata);
    push @chartscaffolds, $scaffolddatastr;

    my (@fplot, @xdata, @ydata, @xydirs);
    my $FH = newReadFileHandle("$tmp_dir/out$$.fplot", "dotplot", 1);
    while (my $s = $FH->getline()) {
	chomp $s;
	push @fplot, $s;
    }
    close($FH);
    my @newfplot = sort {
	substr($a,0,index($a,"-")) <=> substr($b,0,index($b,"-"))
    } @fplot;

    #my $a = $newfplot[2];
    #my $b = substr($a,0,index($a,","));
    #my ($c, $d) = split(/-/, $b);
    #my $e = ($c < $d) ? $c : $d;
    #print "ANNA: $a<br/>$e\n";

    foreach my $item(@newfplot) {
        my( $xcoord, $ycoord, $xyd) = split( /,/, $item );
        push @xdata, $xcoord;
        push @ydata, $ycoord;
        push @xydirs, $xyd;
    }

    my $xdatastr = join(",", @xdata);
    my $ydatastr = join(",", @ydata);
    my $xydirstr = join(",", @xydirs);
    push @xchartdata, $xdatastr;
    push @ychartdata, $ydatastr;
    push @xydirdata, $xydirstr;

    my (@rplot, @xdata, @ydata, @xydirs);
    my $FH = newReadFileHandle("$tmp_dir/out$$.rplot", "dotplot", 1);
    while (my $s = $FH->getline()) {
	chomp $s;
	push @rplot, $s;
    }
    close($FH);
    my @newrplot = sort {
        substr($a,0,index($a,"-")) <=> substr($b,0,index($b,"-"))
    } @rplot;

    foreach my $item(@newrplot) {
        my( $xcoord, $ycoord, $xyd) = split( /,/, $item );
        push @xdata, $xcoord;
        push @ydata, $ycoord;
        push @xydirs, $xyd;
    }

    my $xdatastr = join(",", @xdata);
    my $ydatastr = join(",", @ydata);
    my $xydirstr = join(",", @xydirs);
    push @xchartdata, $xdatastr;
    push @ychartdata, $ydatastr;
    push @xydirdata, $xydirstr;

    $chart->XAXIS(\@xchartdata);
    $chart->YAXIS(\@ychartdata);
    $chart->SLOPE(\@xydirdata);
    $chart->DATA(\@chartscaffolds);

    my @chartcategories;
    push @chartcategories, "fplot";
    push @chartcategories, "rplot";
    $chart->CATEGORY_NAME(\@chartcategories);

    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        $st = generateChart($chart);
    }

    if ($env->{ chart_exe } ne "") {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle
                ($chart->FILEPATH_PREFIX.".html", "runPlot", 1);
	    if ($FH) {
		while (my $s = $FH->getline()) {
		    print $s;
		}
		close ($FH);
	    }
            print "<img src='$tmp_url/".$chart->FILE_PREFIX.".png' BORDER=0 ";
            print " width=".$chart->WIDTH." HEIGHT=".$chart->HEIGHT;
            print " USEMAP='#".$chart->FILE_PREFIX."'>\n";

	    print "<p>";
	    my $pdf_url = "$tmp_url/".$chart->FILE_PREFIX.".pdf";
	    my $contact_oid = WebUtil::getContactOid();
	    print alink( $pdf_url, "Download PDF", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link dot plot PDF']);" );
	    print "<br/>";
            my $tiff_url = "$tmp_url/".$chart->FILE_PREFIX.".tiff";
            print alink( $tiff_url, "Download TIFF", '', '', '', "_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link dot plot TIFF']);" );
	    print "</p>";
        }
	else {
	    print "<font color='red'>Error getting chart</font>";
	}
    }

    wunlink( $tmpFile1 );
    wunlink( $tmpFile2 );
    wunlink( $deltaFile );
    #wunlink( $coordsFile );
    wunlink( $alignsFile );
    wunlink( $filterFile );
    wunlink( $tmp_dir . "/ref_qry$$.cluster" );
    printStatusLine( "Done.", 2 );

    printScript();
    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{
        <script type='text/javascript'>
	    YAHOO.namespace("example.container");
        YAHOO.util.Event.addListener(window, "load", initPanel("container"));
        </script>
	};
    print "</div>\n";

}

############################################################################
# selectScaffolds - select the scaffolds to use for Dot Plot
############################################################################
sub selectScaffolds {
    my ( $dbh, $oids, $algorithm, $reference ) = @_;
    printStatusLine("Loading ...", 1);
    print "<h1>Dotplot</h1>\n";

    print "<p>\n";
    print "The selected genomes are composed of too many scaffolds "
        . "and plot computation may time-out. <br/>You may instead select "
	. "individual scaffolds for each genome. Otherwise, click "
	. "<font color='red'>continue</font> to proceed <br/>with "
	. "the current calculation.";
    print "</p>\n";

    printMainForm();

    my $oidstr = join(",", @$oids);
    print hiddenVar("oids", $oidstr);
    print hiddenVar("continue", "no");
    print hiddenVar("algorithm", $algorithm);
    print hiddenVar("reference", $reference);

    my $name = "_section_DotPlot_continuePlot";
    print submit(
            -name  => $name,
            -value => "Continue",
            -class => "meddefbutton"
    );

    my $sql = qq{
        select taxon_display_name
        from taxon
	where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, @$oids[0] );
    my ($name1) = $cur->fetchrow();
    $cur->finish();
    my $cur = execSql( $dbh, $sql, $verbose, @$oids[1] );
    my ($name2) = $cur->fetchrow();
    $cur->finish();

    my $url1 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=@$oids[0]";
    my $url2 = "$main_cgi?section=TaxonDetail"
             . "&page=taxonDetail&taxon_oid=@$oids[1]";
    my $link1 = alink($url1, $name1, "_blank");
    my $link2 = alink($url2, $name2, "_blank");

    print "<h2>Select Scaffolds</h2>";
    if ( $reference eq "2" ) {
    print qq{
	<p>
	&nbsp;&nbsp;&nbsp;&nbsp;<a href="#genome2">
	Select Scaffolds</a> for $link2
	<br/>
	&nbsp;&nbsp;&nbsp;&nbsp;<a href="#genome1">
	Select Scaffolds</a> for $link1
	<br/>
	</p>
    };
    } else {
    print qq{
	<p>
	&nbsp;&nbsp;&nbsp;&nbsp;<a href="#genome1">
	Select Scaffolds</a> for $link1
	<br/>
	&nbsp;&nbsp;&nbsp;&nbsp;<a href="#genome2">
	Select Scaffolds</a> for $link2
	<br/>
	</p>
    };
    }

    if ( $reference eq "2" ) {
	print WebUtil::getHtmlBookmark("genome2", "<h2>1. $name2</h2>");
	printScaffolds($dbh, @$oids[1], 2);
	print WebUtil::getHtmlBookmark("genome1", "<h2>2. $name1</h2>");
	printScaffolds($dbh, @$oids[0], 1);
    } else {
	print WebUtil::getHtmlBookmark("genome1", "<h2>1. $name1</h2>");
	printScaffolds($dbh, @$oids[0], 1);
	print WebUtil::getHtmlBookmark("genome2", "<h2>2. $name2</h2>");
	printScaffolds($dbh, @$oids[1], 2);
    }

    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();

    my $name = "_section_DotPlot_runPlot";
    print submit(
	    -name  => $name,
            -value => "Dotplot",
            -class => "meddefbutton"
    );
    print nbsp(1);

    my @tables = ('scaffolds1', 'scaffolds2');
    printResetFormButton(\@tables);
    print end_form();
}

############################################################################
# printScaffolds() - Show a list of scaffolds to choose for Dot Plot
############################################################################
sub printScaffolds {
    my ( $dbh, $taxon_oid, $cnt ) = @_;

    my $sql = qq{
	select distinct s.scaffold_name, ss.seq_length,
	       ss.count_total_gene, ss.gc_percent, s.read_depth,
               s.scaffold_oid, s.mol_type, s.mol_topology
        from scaffold s, scaffold_stats ss
	where s.taxon = ?
	and s.taxon = ss.taxon
	and s.scaffold_oid = ss.scaffold_oid
	and s.ext_accession is not null
	order by ss.seq_length desc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable( 1, $taxon_oid."-scaffolds$$",
			     "scaffolds".$cnt, 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Scaffold",    "asc",  "left" );
    $it->addColSpec( "Length (bp)", "desc", "right" );
    $it->addColSpec( "GC",          "desc", "right" );
    $it->addColSpec( "Type",        "asc",  "left" );
    $it->addColSpec( "Topology",    "asc",  "left" );
    $it->addColSpec( "No. Genes",   "desc", "right" );
    #$it->addColSpec( "Coordinate Range", "desc", "right" );

    for ( ;; ) {
        my ( $scaffold_name, $seq_length, $total_gene_count,
             $gc_percent,    $read_depth, $scaffold_oid,
             $mol_type,      $mol_topology, undef
	     ) = $cur->fetchrow();
        last if !$scaffold_oid;

        $gc_percent = sprintf( "%.2f", $gc_percent );
        $read_depth = sprintf( "%.2f", $read_depth );
        $read_depth = "-" if $read_depth == 0;
        print "<tr class='img' >\n";

        my $scaffold_name2 = WebUtil::getChromosomeName($scaffold_name);
        my $r;
	$r .= $sd
	    . "<input type='checkbox' name='scaffold_oid$cnt' "
	    . "value='$scaffold_oid' />" . "\t";

        $r .= $scaffold_name2 . $sd . attrLabel($scaffold_name2) . "\t";
        $r .= ${seq_length} . $sd . ${seq_length} . "\t";
        $r .= ${gc_percent} . $sd . ${gc_percent} . "\t";
        $r .= $mol_type . $sd . $mol_type . "\t";
        $r .= $mol_topology . $sd . $mol_topology . "\t";
        $r .= $total_gene_count . $sd . $total_gene_count . "\t";
	#if ( $seq_length > 0 ) {
        #    my $range = "1\.\.$seq_length";
        #    $r .= $seq_length . $sd . $range . "\t";
	#} else {
       	#    $r .= "" . $sd . nbsp(1) . "\t";
	#}

        $it->addRow($r);
    }
    $it->printOuterTable(1);
    $cur->finish();
}


sub printScript {
    print "<script src='$base_url/chart.js'></script>\n";
    print "<script src='$base_url/overlib.js'></script>\n"; ## for tooltips

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

    print qq {
	<script language="javascript" type="text/javascript">
	function initPanel() {
	    if (!YAHOO.example.container.panelA) {
		YAHOO.example.container.panelA = new YAHOO.widget.Panel
		    ("panelA", {
		      visible:false,
			//draggable:true,
		      fixedcenter:true,
		      dragOnly:true,
		      underlay:"none",
		      zindex:"10",
			//context:['nbhood','bl','tr']
			} );
		YAHOO.example.container.panelA.setHeader("Gene Neighborhood");
		YAHOO.example.container.panelA.setBody("Test Panel.");
		YAHOO.example.container.panelA.render("container");
		//alert("initPanel");
	    }
	}

	function handleSuccess(req) {
            try {
                response = req.responseXML.documentElement;
                var html = response.getElementsByTagName
                    ('div')[0].firstChild.data;
                YAHOO.example.container.panelA.setBody(html);
                YAHOO.example.container.panelA.render("container");
                YAHOO.example.container.panelA.show();
            } catch(e) {
                alert("exception: "+req.responseXML+" "+req.responseText);
            }
	    YAHOO.example.container.wait.hide();
	}

        function neighborhood(url) {
            YAHOO.namespace("example.container");
            if (!YAHOO.example.container.wait) {
                initializeWaitPanel();
            }

	    //alert("url: "+url);

            var callback = {
              success: handleSuccess,
              failure: function(req) {
		  alert("failure : "+req);
                  YAHOO.example.container.wait.hide();
              }
            };

            if (url != null && url != "") {
		YAHOO.example.container.wait.show();
                var request = YAHOO.util.Connect.asyncRequest
                    ('GET', url, callback);
            }
        }
	</script>
    };
}


1;
