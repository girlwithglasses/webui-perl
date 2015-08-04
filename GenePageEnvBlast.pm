############################################################################
# GenePageEnvBlast.pm - Run BLAST from gene object detail page
#   for environmental samples.
#       --es 06/15/2005
#
# $Id: GenePageEnvBlast.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package GenePageEnvBlast;
my $section = "GenePageEnvBlast";
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use ScaffoldPanel;
use WebConfig;
use WebUtil;
use HtmlUtil;
use QueryUtil;
use GeneUtil;

$| = 1;

my $env                    = getEnv();
my $main_cgi               = $env->{main_cgi};
my $section_cgi            = "$main_cgi?section=$section";
my $verbose                = $env->{verbose};
my $snp_blast_data_dir     = $env->{snp_blast_data_dir};
my $blastall_bin           = $env->{blastall_bin};
my $all_fna_files_dir      = $env->{all_fna_files_dir};
my $taxon_fna_dir          = $env->{taxon_fna_dir};
my $taxon_lin_fna_dir      = $env->{taxon_lin_fna_dir};
my $env_blast_dbs          = $env->{env_blast_dbs};
my $env_blast_defaults     = $env->{env_blast_defaults};
my $env_blast_restrictions = $env->{env_blast_restrictions};
my $blast_a_flag           = $env->{blast_a_flag};
$blast_a_flag = "-a 16" if $blast_a_flag eq "";

my $tmp_dir      = $env->{tmp_dir};
my $tmp_url      = $env->{tmp_url};
my $base_dir     = $env->{base_dir};
my $base_url     = $env->{base_url};
my $img_internal = $env->{img_internal};
my $snpCount_bin = $env->{snpCount_bin};

my $max_blast_scaffold_length = 100000;
$max_blast_scaffold_length = $env->{max_blast_scaffold_length}
  if $env->{max_blast_scaffold_length} ne "";

$ENV{BLAST_DB} = $snp_blast_data_dir;

my $user_restricted_site   = $env->{user_restricted_site};
my $cgi_blast_cache_enable = $env->{cgi_blast_cache_enable};
my $blast_wrapper_script   = $env->{blast_wrapper_script};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    my $sid  = getContactOid();

    if ( $page eq "genePageEnvBlast" ) {
        printGenePageEnvBlastForm();
    } elsif ( $page eq "snpBlastMERFS" ) {
	printSnpBlastMERFS();
    } elsif ( paramMatch("runSnpBlastMERFS") ne "" ) {
	runSnpBlastMERFS();
    } elsif ( $page eq "ecoVista" ) {
        printEcoVista();
    } elsif ( $page eq "envBlastOut" ) {
        if ($cgi_blast_cache_enable) {
            HtmlUtil::cgiCacheInitialize( $section );
            HtmlUtil::cgiCacheStart() or return;
        }
        runLocalEnvBlast();
        HtmlUtil::cgiCacheStop() if ($cgi_blast_cache_enable);
    } else {
        printGenePageEnvBlastForm();
    }
}

sub printSnpBlastMERFS {
    my $gene_oid = param("gene_oid");
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type"); 

    my $scaffold_oid = param("scaffold_oid");
    my $start_coord = param("start_coord");
    my $end_coord = param("end_coord");
    my $strand = param("strand");

    my $dbh = dbLogin();
    printMainForm();

    print "<h1>SNP BLAST</h1>\n";

    my $sql = "select taxon_display_name from taxon "
	    . "where taxon_oid = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $taxon_display_name ) = $cur->fetchrow();
    $cur->finish();

    my $url1 = "$main_cgi?section=MetaDetail"
             . "&page=metaDetail&taxon_oid=$taxon_oid";
    my $link1 = alink( $url1, $taxon_display_name, "_blank" );

    my $url2 = "$main_cgi?section=MetaGeneDetail"
	     . "&page=metaGeneDetail&gene_oid=$gene_oid"
	     . "&data_type=$data_type&taxon_oid=$taxon_oid";
    my $link2 = alink( $url2, $gene_oid, "_blank" );

    print "<p style='width: 650px;'>$link1</p>";

    print "<p>BLAST current gene against unassembled reads from "
	. "the same genome to look for SNP variations.</p>";
    print "<p>$link2</p>";

    # TODO: call this only if scaffold is not known
    my ($fna, $strand, $scaf_oid) = MetaUtil::getGeneFna($gene_oid, $taxon_oid, $data_type);
    my $seq = ">$gene_oid\n";
    $seq .= wrapSeq($fna);
    print textarea(
                    -name    => "fasta",
                    -default => $seq,
                    -rows    => 10,
                    -columns => 60
    );
    print "<br/>\n";

    print "<p>";
    print "E-value: ";
    print popup_menu(
          -name   => "blast_evalue",
          -values => [ "1e-2", "1e-5", "1e-8", "1-e10", "1e-20", "1e-50" ]
    );
    print "<br/>\n";

    print "Extend gene coordinates ";
    print "<input type='text' size='5' name='up_stream' value='-0'/>";
    print "bp upstream and ";
    print "<input type='text' size='5' name='down_stream' value='+0'/>";
    print "bp downstream\n";
    print "<br/>\n";

    if ($scaffold_oid ne "") {
	print "<input type='checkbox' ";
	print "name='use_contig' value='$scaffold_oid' />\n";
	print "Use entire contig instead of gene sequence.";
	print "<br/>\n";
    }

    print hiddenVar( "taxon_oid", $taxon_oid );
    print hiddenVar( "gene_oid", $gene_oid );
    print hiddenVar( "scaffold_oid", $scaffold_oid );
    print hiddenVar( "start_coord", $start_coord );
    print hiddenVar( "end_coord", $end_coord );
    print hiddenVar( "strand", $strand );

    my $name = "_section_${section}_runSnpBlastMERFS";
    print submit(
                  -name  => $name,
                  -value => "Run BLAST",
                  -class => "smdefbutton"
    );

    print end_form();
    #$dbh->disconnect();
}

sub runSnpBlastMERFS {
    my $gene_oid     = param("gene_oid");
    my $taxon_oid    = param("taxon_oid");
    my $use_contig   = param("use_contig");

    my $fasta        = param("fasta");
    my $evalue       = param("blast_evalue");
    my $up_stream    = param("up_stream");
    my $down_stream  = param("down_stream");

    my $scaffold_oid = param("scaffold_oid");
    my $start_coord  = param("start_coord");
    my $end_coord    = param("end_coord");
    my $strand       = param("strand");

    $evalue = checkEvalue($evalue);
    $taxon_oid = sanitizeInt($taxon_oid);

    my ( $scf_start, $scf_end, $scf_strand ) =
	MetaUtil::getScaffoldCoord($taxon_oid, "assembled", $scaffold_oid);
    my $scf_seq_length = $scf_end - $scf_start + 1;
    my $seq = MetaUtil::getScaffoldFna($taxon_oid, "assembled", $scaffold_oid);

    if ( $use_contig ne "" && $scaffold_oid ne "" ) {
	my $seq2 = wrapSeq($seq);
        $fasta = ">$scaffold_oid\n";
        $fasta .= "$seq\n";
    }

    my $url =
            "$main_cgi?section=MetaScaffoldGraph"
          . "&page=metaScaffoldGraph&scaffold_oid=$scaffold_oid"
          . "&taxon_oid=$taxon_oid"
	  . "&start_coord=$scf_start&end_coord=$scf_end"
	  . "&marker_gene=$gene_oid&seq_length=$scf_seq_length";
    my $link = alink( $url, "$scaffold_oid (${scf_seq_length}bp)" );
    if ( !isInt($up_stream) || $up_stream > 0 ) {
        webError("Upstream should be zero or negative integer.");
    }
    if ( !isInt($down_stream) || $down_stream < 0 ) {
        webError("Downstream should be zero or positive integer.");
    }

    if ( $use_contig ne "" ) { # use entire contig
	$start_coord = $scf_start;
	$end_coord = $scf_end;
	$strand = $scf_strand;
    }

    my $c1 = $start_coord + $up_stream;
    my $c2 = $end_coord + $down_stream;
    $c1 = 1 if $c1 < 1;
    $c2 = $scf_seq_length if $c2 > $scf_seq_length;

    if ( $strand eq "-" ) {
	$c2 = $start_coord - $down_stream;
	$c1 = $end_coord - $up_stream;
	$c2 = 1 if $c2 < 1;
	$c1 = $scf_seq_length if $c1 > $scf_seq_length;
    }

    my $seq = WebUtil::getSequence( $seq, $c1, $c2 );
    $fasta = ">${scaffold_oid}__${c1}..${c2}\n";
    $fasta .= "$seq\n";

    printMainForm();
    print "<h1>BLAST Results</h1>\n";
    print "<p>$link</p>";

    blastProcCheck();
    printStatusLine( "Loading ...", 1 );

    my $tmpFile = "$tmp_dir/merfssnpblast$$.fna";
    my $snp_blast_data_dir =
	"/global/dna/projectdirs/microbial/img_web_data_merfs/";
    my $dbFile  = "$snp_blast_data_dir/$taxon_oid/unassembled/"
	        . "blast.data/$taxon_oid" . ".u.fna";

    my $wfh = newWriteFileHandle( $tmpFile, "runLocalEnvBlast" );
    print $wfh "$fasta\n";
    print $wfh "\n";
    close $wfh;

    webLog "Start MER-FS SNP BLAST " . currDateTime() . "\n" if $verbose >= 1;

    ## New BLAST
    my $cmd = "$blastall_bin/legacy_blast.pl blastall "
            . " -p blastn -d $dbFile -i $tmpFile "
            . " -m 3 -F F -b 30000 -K 30000 -e $evalue -T F $blast_a_flag "
            . " --path $blastall_bin ";
            # --path is needed although fullpath of legacy_blast.pl is
            # specified in the beginning of command! ---yjlin 03/12/2013


    webLog "Start BLAST process=$$ " . currDateTime() . "\n" if $verbose >= 1;
    webLog "+ $cmd\n" if $verbose >= 1;
    my $blastOutFile = "blastOut$$";
    my $blastOutPath = "$tmp_dir/$blastOutFile";

    WebUtil::unsetEnvPath();

    if ( $blast_wrapper_script ne "" ) {
        $cmd = "$blast_wrapper_script $cmd";
    }

    my $cfh = newCmdFileHandle( $cmd, "runSnpBlastMERFS" );
    my $wfh = newWriteFileHandle( $blastOutPath, "runSnpBlastMERFS" );

    print "<pre>\n";
    print "<font color='blue'>\n";

    my $foundQuery = 0;
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) { # some genome/gene names might 
                               # contain PID. This has happened. 
                               # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }
        if ( $s =~ /QUERY/ || $s =~ /Query/ ) {
            $foundQuery = 1;
        }
        if ( $s =~ /^1_0/ ) {
            $s =~ s/^1_0  /QUERY/;
        }
        print "$s\n";
        print $wfh "$s\n";
    }
    print "</font>\n";
    print "</pre>\n";

    if ( !$foundQuery ) {
	printStatusLine( "Error", 2 );
	return;
    }

    print "<br/>\n";
    my $url = "$section_cgi&page=ecoVista&blastOut=$blastOutFile";
    print buttonUrl( $url, "Run SNP VISTA", "smdefbutton" );

    close $cfh;
    close $wfh;
    WebUtil::resetEnvPath();
    wunlink($tmpFile);

    printStatusLine( "Loaded.", 2 );
    webLog "BLAST Done process=$$ " . currDateTime() . "\n" if $verbose >= 1;
    print end_form();
}

############################################################################
# printGenePageEnvBlastForm - Gene page environmental (SNP)
#   BLAST query form.
############################################################################
sub printGenePageEnvBlastForm {
    my $gene_oid = param("genePageGeneOid");

    printMainForm();
    print "<h1>BLAST against SNP Databases</h1>\n";
    print "<p>\n";
    print "BLAST against contigs and reads to look for SNP variations ";
    print "on this gene.<br/>\n";
    print "Please be sure to select the appropriate database.<br/>\n";
    print "<p>\n";

    my $dbh = dbLogin();
    checkGenePerm( $dbh, $gene_oid );

    my ($rclause) = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.taxon, scf.ext_accession, 
          g.start_coord, g.end_coord, g.strand, g.cds_frag_coord, tx.jgi_species_code
        from gene g, scaffold scf, taxon tx
        where g.scaffold = scf.scaffold_oid
        and g.gene_oid = $gene_oid
        and g.taxon = tx.taxon_oid
    	$rclause
    	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ( $gene_oid, $gene_display_name, $taxon, $ext_accession, $start_coord,
         $end_coord, $strand, $cds_frag_coord, $jgi_species_code ) = $cur->fetchrow();
    $cur->finish();

    #my $path = "$taxon_fna_dir/$taxon.fna";
    #my $scaffold_seq = readMultiFasta( $path, $ext_accession );
    #my $start = $start_coord;
    #my $end = $end_coord;
    #if( $strand eq "-" ) {
    #   $start = $end_coord;
    #   $end =  $start_coord;
    #}
    #my $seq = getSequence( $scaffold_seq, $start, $end );

    my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );

    my $path = "$taxon_lin_fna_dir/$taxon.lin.fna";
    my $seq  = WebUtil::readLinearFasta
	( $path, $ext_accession, $start_coord, $end_coord, $strand, \@coordLines );
    my $seq2 = wrapSeq($seq);

    print hiddenVar( "page",              "envBlastOut" );
    print hiddenVar( "blast_gene_oid",    $gene_oid );
    print hiddenVar( "gene_display_name", $gene_display_name );

    my $fasta = ">$gene_oid $gene_display_name\n";
    $fasta .= wrapSeq($seq);
    print textarea(
                    -name    => "fasta",
                    -default => $fasta,
                    -rows    => 10,
                    -columns => 60
    );
    print "<br/>\n";

    my %validDbs;    # valid databases for permssions
    %validDbs = validEnvBlastDbs($dbh); # is this obsolete?
    moreValidDbs( $dbh, \%validDbs );

    print "<table class='img' border='1'>\n";
    print "<tr class='img' >\n";
    print "<th class='subhead' align='left'>Database:</th>\n";
    print "<td class='img' >\n";
    print "<select name='blast_db'>\n";

    my $defaultDb = $env_blast_defaults->{$jgi_species_code};
    $defaultDb = "all_env" if $defaultDb eq "";
    my $nBlastDbs = scalar(@$env_blast_dbs) / 2;
    for ( my $i = 0 ; $i < $nBlastDbs ; $i++ ) {
        my $blastDb = $env_blast_dbs->[ $i * 2 ];
        my $name    = $env_blast_dbs->[ $i * 2 + 1 ];
        ## --es 06/20/2007
        next if $validDbs{$blastDb} eq "";
        my $selected;
        $selected = "selected" if $blastDb eq $defaultDb;
        print "<option value='$blastDb' $selected>"
	    . escHtml($name)
	    . "</option>\n";
    }

    # taxon_oid version of SNP blast data
    my @files = dirList($snp_blast_data_dir);
    for my $f (@files) {
        next if $f !~ /\.nsq$/;
        my $taxon_oid = fileRoot($f);
        next if !isInt($taxon_oid);
        my $blastDb = $taxon_oid;
        next if $validDbs{$blastDb} eq "";
        my $name = taxonOid2Name( $dbh, $taxon_oid );
        my $selected;
        $selected = "selected" if $blastDb eq $taxon;
        print "<option value='$blastDb' $selected>"
	    . escHtml($name)
	    . "</option>\n";
    }
    print "</select>\n";
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img' >\n";
    print "<th class='subhead' align='left'>E-value:</th>\n";
    print "<td class='img' >\n";
    print popup_menu(
	-name   => "blast_evalue",
	-values => [ "1e-2", "1e-5", "1e-8", "1-e10", "1e-20", "1e-50" ]
    );
    print "</td>\n";
    print "</tr>\n";

    print "</table>\n";
    print "<br/>\n";

    print hiddenVar( "query_gene_oid", $gene_oid );

    print "<p>\n";
    print "Extend gene <i>$gene_oid</i> coordinates ";
    print "<input type='text' size='5' name='up_stream' value='-0' />\n";
    print "bp upstream.\n";
    print nbsp(2);
    print "<input type='text' size='5' name='down_stream' value='+0' />\n";
    print "bp downstream\n";
    print "<br/>\n";

    ## BLAST by scaffod option.
    my $sql = qq{
        select scf.scaffold_oid, scf.ext_accession, 
               ss.seq_length, tx.env_sample
        from gene g, scaffold scf, scaffold_stats ss, taxon tx
        where g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
        and g.gene_oid = ?
        and g.taxon = tx.taxon_oid
    	$rclause
    	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ( $scaffold_oid, $scf_ext_accession, $scf_seq_length, $env_sample ) =
      $cur->fetchrow();
    $cur->finish();

    if ( $scaffold_oid ne "" 
	 && $scf_seq_length < $max_blast_scaffold_length ) {
        print "or ";
        print "<input type='checkbox' ";
        print "name='scaffold_oid' value='$scaffold_oid' />\n";
        print "Use contig " . "<i>"
          . escHtml($scf_ext_accession)
          . "</i> (${scf_seq_length}bp) instead of gene sequence.<br/>\n";
        print "<br/>\n";
    } else {
        print "Scaffold <i>"
          . escHtml($scf_ext_accession)
          . "</i> is too long (${scf_seq_length}bp).<br/>\n";
        print "The whole scaffold is not available for SNP BLAST.\n";
        print "Use only the above gene sequence.<br/>\n";
        print "<br/>\n";
    }
    print "</p>\n";

    print hiddenVar( "section", $section );
    my $name = "_section_${section}_runBlast";
    print submit(
                  -name  => $name,
                  -value => "Run BLAST",
                  -class => "smdefbutton"
    );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# runLocalEnvBlast - Run from local BLAST databases.
#   Inputs:
#      gene_oid - gene object identifier
#      gene_display_name - gene namee
#      fasta - FASTA sequence
#      db - BLAST database
############################################################################
sub runLocalEnvBlast {
    my $gene_oid          = param("blast_gene_oid");
    my $gene_display_name = param("gene_name");
    my $fasta             = param("fasta");
    my $db                = param("blast_db");
    my $evalue            = param("blast_evalue");
    my $scaffold_oid      = param("scaffold_oid");
    my $up_stream         = param("up_stream");
    my $down_stream       = param("down_stream");

    if ( $scaffold_oid ne "" ) {
        my $dbh = dbLogin();
        my $sql = qq{
           select scf.ext_accession
           from scaffold scf
           where scf.scaffold_oid = $scaffold_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        my ($scf_ext_accession) = $cur->fetchrow();
        $cur->finish();

        my $seq = getScaffoldSeq( $dbh, $scaffold_oid );
        #$dbh->disconnect();
        $fasta = ">$scf_ext_accession\n";
        $fasta .= "$seq\n";
    }
    if ( !isInt($up_stream) || $up_stream > 0 ) {
        webError("Upstream should be zero or negative integer.");
    }
    if ( !isInt($down_stream) || $down_stream < 0 ) {
        webError("Downstream should be zero or positive integer.");
    }
    if (    isInt($up_stream)
         && isInt($down_stream)
         && ( $up_stream < 0 || $down_stream > 0 ) )
    {
        my $dbh = dbLogin();
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql = qq{
            select g.start_coord, g.end_coord, g.strand, g.scaffold,
	          scf.ext_accession, ss.seq_length
            from gene g, scaffold scf, scaffold_stats ss
            where g.scaffold = scf.scaffold_oid
            and scf.scaffold_oid = ss.scaffold_oid
            and g.gene_oid = ?
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        my ( $start_coord, $end_coord, $strand, $g_scaffold, 
	     $scf_ext_accession, $scf_seq_length ) = $cur->fetchrow();
        $cur->finish();

        my $c1 = $start_coord + $up_stream;
        my $c2 = $end_coord + $down_stream;
        $c1 = 1 if $c1 < 1;
        $c2 = $scf_seq_length if $c2 > $scf_seq_length;

        if ( $strand eq "-" ) {
            $c2 = $start_coord - $down_stream;
            $c1 = $end_coord - $up_stream;
            $c2 = 1 if $c2 < 1;
            $c1 = $scf_seq_length if $c1 > $scf_seq_length;
        }

        my $seq = getScaffoldSeq( $dbh, $g_scaffold, $c1, $c2 );
        #$dbh->disconnect();
        $fasta = ">${scf_ext_accession}__${c1}..${c2}\n";
        $fasta .= "$seq\n";

        #if( length( $seq ) > $max_blast_scaffold_length ) {
        #   webError( "Scaffold range specification is too long. " .
        # "Try values resulting in < ${max_blast_scaffold_length}bp's." );
        #}
    }

    printMainForm();
    print "<h1>BLAST Results</h1>\n";
    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
    print buttonUrl( $url, "Gene Details", "smdefbutton" );
    print "<p>\n";
    print "(SNP VISTA can be run from the bottom of the page ";
    print "once BLAST results are completed.)<br/>\n";
    print "</p>\n";
    $evalue = checkEvalue($evalue);
    $db =~ /([a-zA-Z_0-9]+)/;
    $db = $1;

    ## --es 05/05/2005 Check for IMG BLAST limits.
    blastProcCheck();

    printStatusLine( "Loading ...", 1 );

    my $dbFile  = "$snp_blast_data_dir/$db";
    my $tmpFile = "$tmp_dir/blast$$.fna";

    my $wfh = newWriteFileHandle( $tmpFile, "runLocalEnvBlast" );
    print $wfh "$fasta\n";
    print $wfh "\n";
    close $wfh;

    webLog "Start BLAST " . currDateTime() . "\n" if $verbose >= 1;

    ## New BLAST
    my $cmd = "$blastall_bin/legacy_blast.pl blastall "
            . " -p blastn -d $dbFile -i $tmpFile "
            . " -m 3 -F F -b 30000 -K 30000 -e $evalue -T F $blast_a_flag "
            . " --path $blastall_bin ";
            # --path is needed although fullpath of legacy_blast.pl is 
            # specified in the beginning of command! ---yjlin 03/12/2013
    
    webLog "Start BLAST process=$$ " . currDateTime() . "\n" if $verbose >= 1;
    webLog "+ $cmd\n" if $verbose >= 1;
    my $blastOutFile = "blastOut$$";
    my $blastOutPath = "$tmp_dir/$blastOutFile";

    WebUtil::unsetEnvPath();

    if ( $blast_wrapper_script ne "" ) {
        $cmd = "$blast_wrapper_script $cmd";
    }

    my $cfh = newCmdFileHandle( $cmd,            "runLocalEnvBlast" );
    my $wfh = newWriteFileHandle( $blastOutPath, "runLocalEnvBlast" );

    print "<pre>\n";
    print "<font color='blue'>\n";

    my $foundQuery = 0;
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) { # some genome/gene names might 
                               # contain PID. This has happened. 
                               # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }

        if ( $s =~ /QUERY/ || $s =~ /Query/ ) {
            $foundQuery = 1;
        }
        if ( $s =~ /^1_0/ ) {
            # bug fix
            # the vista applet is expecting QUERY not 1_0
            # I must replace 2 space too!
            $s =~ s/^1_0  /QUERY/;
        }
        print "$s\n";
        print $wfh "$s\n";
    }
    print "</font>\n";
    print "</pre>\n";

    if ( !$foundQuery ) {
    printStatusLine( "Error", 2 );
    webLog("SNP BLAST error. Possibly ran out of memory gene_oid=$gene_oid\n");
    warn("SNP BLAST error. Possibly ran out of memory gene_oid=$gene_oid\n");
    return;
    }

    print "<br/>\n";
    my $url = "$section_cgi&page=ecoVista&blastOut=$blastOutFile";
    print buttonUrl( $url, "Run SNP VISTA", "smdefbutton" );

    #if( $img_internal ) {
    #    printSnpCount( $blastOutPath );
    #    print buttonUrlNewWindow( $url, "Run SNP VISTA", "smdefbutton" );
    #}
    #printEcoVista( $blastOutFile );
    close $cfh;
    close $wfh;
    WebUtil::resetEnvPath();
    wunlink($tmpFile);

    printStatusLine( "Loaded.", 2 );
    webLog "BLAST Done process=$$ " . currDateTime() . "\n" if $verbose >= 1;
    print end_form();
}

############################################################################
# printSnpCount - Print SNP counts.  Use command line tool snpCount
#   to parse BLAST output to show the SNP counts and statistics.
############################################################################
sub printSnpCount {
    my ($blastFile) = @_;
    WebUtil::unsetEnvPath();
    my $cmd = "$snpCount_bin -i $blastFile -v 1";
    webLog "+ $cmd\n" if $verbose >= 1;
    my $cfh            = newCmdFileHandle( $cmd, "runLocalEnvBlast" );
    my $minDepth       = 0;
    my $snpBaseCount   = 0;
    my $queryBaseCount = 0;
    my $snpPercentage  = 0;

    while ( my $s = $cfh->getline() ) {
        chomp $s;
        my ( $tag, $val ) = split( / /, $s );
        if ( $tag eq ".minDepth" ) {
            $minDepth = $val;
        } elsif ( $tag eq ".snpBaseCount" ) {
            $snpBaseCount = $val;
        } elsif ( $tag eq ".queryBaseCount" ) {
            $queryBaseCount = $val;
        } elsif ( $tag eq ".snpPercentage" ) {
            $snpPercentage = $val;
        }
    }
    close $cfh;
    WebUtil::resetEnvPath();
    print "<pre>\n";
    print "<font color='green'>\n";
    print "No. of Point Mutations (depth >= $minDepth): $snpBaseCount\n";
    print "Total Query Base Positions (including gaps): $queryBaseCount\n";
    print "Single Nucleotide Polymorphism Rate: $snpPercentage%\n";
    print "</font>\n";
    print "</pre>\n";
}

############################################################################
# printEcoVista - Print ecoVista applet button.
############################################################################
sub printEcoVista {
    my $blastOutFile = param("blastOut");

    my $blast_out_url  = "$tmp_url/$blastOutFile";
    my $blast_out_file = "$tmp_dir/$blastOutFile";
    if ( !( -e $blast_out_file ) ) {
        webError("Session expired.  Please re-run BLAST.");
    }

    print "<h1>SNP VISTA</h1>\n";
    print "<p>\n";
    print "Please wait for the applet to load.\n";
    print "</p>\n";

    print "<applet name='EcoVista' ";
    print "code='gov.lbl.genome.ecovista.gui.common.Test' ";
    print "width='1000' height='700' ";
    print "archive='$base_url/EcoVista.jar'>\n";
    print "<param name='blast' value='$blast_out_url'>\n";
    print "alt='applet is not running'";
    print "</applet>\n";
}

############################################################################
# printEcoVistaWebStart - Print ecoVista with java web start.
############################################################################
sub printEcoVistaWebStart {
    my ($blastOutFile) = @_;

    my $blast_out_url  = "$tmp_url/$blastOutFile";
    my $blast_out_file = "$tmp_dir/$blastOutFile";
    if ( !( -e $blast_out_file ) ) {
        webLog("printEcoVistaWebStart: '$blast_out_file' expired.");
    }
    print "Content-type: application/x-java-jnlp-file\n\n";
    print "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    my $s = qq{
    <!-- JNLP File for EcoVISTA Application -->
    <jnlp
      spec="1.0+"
      codebase="$base_url"
      href="">
      <information>
        <title>SNP VISTA</title>
        <vendor>LBNL</vendor>
        <homepage href=""/>
        <description>SNP VISTA Application</description>
        <description kind="short">SNP VISTA</description>
        <offline-allowed/>
      </information>
      <security>
      </security>
      <resources>
        <j2se version="1.4+" java-vm-args="-esa -Xnoclassgc"/>
        <jar href="$base_url/EcoVista.jar"/>
      </resources>
      <application-desc main-class=
         "gov.lbl.genome.ecovista.gui.common.EcoVista">
          <argument>$blast_out_url</argument>
      </application-desc>
    </jnlp>
    };
    print "$s\n";
}

############################################################################
# moreValidDbs - More Valid databases.
############################################################################
sub moreValidDbs {
    my ( $dbh, $validDbs_href ) = @_;

    my ($rclause) = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
        select tx.taxon_oid
    	from taxon tx
    	where tx.genome_type = 'metagenome'
    	$rclause
    	$imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $validDbs_href->{$taxon_oid} = 1;
    }
    $cur->finish();

    my $contact_oid = getContactOid();
    return if $contact_oid eq "";

    my $sql = QueryUtil::getContactTaxonPermissionSql();
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $validDbs_href->{$taxon_oid} = 1;
    }
    $cur->finish();
}

1;

