############################################################################
# GeneNeighborhood - Print gene neighborhoods for multiple orthologs
#  or for selected genes.
# $Id: GeneNeighborhood.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package GeneNeighborhood;
my $section = "GeneNeighborhood";

use strict;
use CGI qw( :standard );
use DBI;
use GeneCartStor;
use ScaffoldPanel;
use Data::Dumper;
use WebConfig;
use WebUtil;
use GeneUtil;
use GeneCassette;
use MetaUtil;
use OracleUtil;

my $env              = getEnv();
my $main_cgi         = $env->{main_cgi};
my $section_cgi      = "$main_cgi?section=$section";
my $tmp_url          = $env->{tmp_url};
my $tmp_dir          = $env->{tmp_dir};
my $verbose          = $env->{verbose};
my $web_data_dir     = $env->{web_data_dir};
my $preferences_url  = "$main_cgi?section=MyIMG&page=preferences";
my $img_lite         = $env->{img_lite};
my $include_bbh_lite = $env->{include_bbh_lite};

my $flank_length     = 25000;
my $maxNeighborhoods = 5;
my $maxColors        = 246;

# checkbox for neighborhood cart - ken 2009-07-02
my $show_checkbox = 0;

my $base_url      = $env->{base_url};
my $YUI           = $env->{yui_dir_28};
my $cgi_tmp_dir   = $env->{cgi_tmp_dir};
my $bbh_files_dir = $env->{bbh_files_dir};

# gene cart neighborhood
# check box to remove gene from gene cart when selected and update
my $show_checkbox_remove = 0;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    timeout( 60 * 20 );    # timeout in 20 mins (from main.pl)

    $show_checkbox = param("show_checkbox");
    if ( $show_checkbox eq "" ) {
        $show_checkbox = 0;
    }

    if ( $page eq "geneOrthologNeighborhood"
         || paramMatch("geneOrthologNeighborhood") ne "" )
    {
        printOrthologNeighborhoods();
    } elsif ( $page eq "selectedGeneNeighborhoods"
              || paramMatch("selectedGeneNeighborhoods") ne "" )
    {
        $show_checkbox_remove = 1;
        printSelectedNeighborhoods();
    } elsif ( $page eq "neighborhoodCart" ) {

        # show selected neighborhoods
        printCartNeighborhoods();
    } elsif ( $page eq "neigFile" ) {

        # next button pressed on neighhood viewer
        printNextNeighborhoods();
    } else {
        webLog("GeneNeighborhood::dispatch: unknonwn page='$page'\n");
        warn("GeneNeighborhood::dispatch: unknonwn page='$page'\n");
    }
}

############################################################################
# printOrthologNeighborhoods - Print gene neighborhoods based
#  on orthologs of one gene.
############################################################################
sub printOrthologNeighborhoods {
    my $gene_oid  = param("gene_oid");
    my $taxon_oid = param("taxon_oid");
    my $data_type = param("data_type");

    my $genome_type = "metagenome";
    if ( isInt($gene_oid) ) {
        my $dbh          = dbLogin();
        my $genome_type2 = geneOid2GenomeType( $dbh, $gene_oid );

        #$dbh->disconnect();
        $genome_type = $genome_type2 if ($genome_type2);
    }

    my $use_bbh_lite = param("use_bbh_lite");

    #    if ($img_lite) {

    if ( $use_bbh_lite && $genome_type eq "isolate" ) {
        printOrthologNeighborhoodsBBHLite($gene_oid);
    } else {
        if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
            my $workspace_id = "$taxon_oid $data_type $gene_oid";

            #webLog("here 2 ================= \n");
            #printOrthologNeighborhoodsCog($workspace_id);

            printOrthologNeighborhoodsCog_new_merfs( $taxon_oid, $data_type, $gene_oid );
        } else {

            #webLog("here 3 ================= \n");
            printOrthologNeighborhoodsCog_new($gene_oid);

            #printOrthologNeighborhoodsCog($gene_oid);
        }
    }

    #    } elsif ( !$img_lite && $include_bbh_lite ) {
    #        printOrthologNeighborhoodsBBHLite($gene_oid);
    #    } else {
    #        printOrthologNeighborhoodsGo($gene_oid);
    #    }
}

###
# BBH gene_orthologs version
#
sub printOrthologNeighborhoodsGo {
    my ($gene_oid) = @_;

    my $cog_color = param("cog_color");
    my $gene_oid  = param("gene_oid");

    my $dbh = dbLogin();
    checkGenePerm( $dbh, $gene_oid );

    printMainForm();
    print "<h1>Gene Ortholog Neighborhoods</h1>";
    printStatusLine("Loading ...");

    my $temp = getSessionParam("maxNeighborhoods");
    $maxNeighborhoods = $temp if $temp ne "";

    printStartWorkingDiv();
    print "Retrieving ortholog neighborhoods ...<br/>\n";

    my $taxon_filter_clause_go = txsClause( "go.taxon", $dbh );
    my $rclause_go             = urClause("go.taxon");
    my $sql                    = qq{
       select go.gene_oid, go.ortholog, g1.strand, g2.strand
       from gene g1, gene g2, gene_orthologs go
       where go.gene_oid = ?
       and go.gene_oid = g1.gene_oid
       and go.ortholog = g2.gene_oid
       and g1.obsolete_flag = 'No'
       and g2.obsolete_flag = 'No'
       and g2.aa_seq_length < 1.3*g1.aa_seq_length
       and g2.aa_seq_length > 0.7*g1.aa_seq_length
       and g1.end_coord > 0
       and g2.end_coord > 0
       $taxon_filter_clause_go
       $rclause_go
       order by go.bit_score desc, go.evalue, go.percent_identity
          desc
    };
    webLog ">>> geneNeighborhood start\n";

    my @recs;
    my $cur   = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $count = 0;

    # create cache file
    my $sid      = getSessionId();
    my $file     = "neig" . "$$" . "_" . $sid;
    my $path     = "$cgi_tmp_dir/$file";
    my $fh       = newWriteFileHandle($path);
    my $shownext = 0;                            # show next button

    for ( ; ; ) {
        my ( $gene_oid, $ortholog, $strand1, $strand2, undef ) = $cur->fetchrow();

        $shownext = 1 if $count > $maxNeighborhoods;
        last if !$gene_oid;

        $count++;
        if ( $count == 1 ) {

            # this is ref gene - initial gene
            my $rec = "$gene_oid\t+";
            push( @recs, $rec );
            print $fh "$rec\n";
        }
        my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
        my $rec = "$ortholog\t$panelStrand";
        print $fh "$rec\n";
        push( @recs, $rec ) if $count <= $maxNeighborhoods;
    }
    $cur->finish();
    close $fh;

    if ( $count == 0 ) {
        printStatusLine( "Loaded.", 2 );

        #$dbh->disconnect();
        printEndWorkingDiv();
        webError( "No orthologs for other gene neighborhoods found " . "for roughly the same sized gene." );
        return;
    }
    printEndWorkingDiv();

    print "<p>\n";
    print "Neighborhoods of roughly same sized orthologs " . "in user-selected genomes are shown below.<br/>";
    print "Genes of the same color (except light yellow) ";
    print "are from the same orthologous group (top COG hit).";
    print "</p>\n";

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment, "
               . "White = pseudo gene" );

    printTrackerDiv( $cog_color, $gene_oid );
    printNeighborhoodPanels( $dbh, "orth", \@recs, $count );

    #$dbh->disconnect();

    if ($shownext) {

        # Next button
        my $url = "$section_cgi&page=neigFile&index=2&file=$file" . "&cog_color=$cog_color&show_checkbox=$show_checkbox";
        print qq{
            <input class='smbutton'
                   type="button"
                   value="Next &gt;"
                   onclick="window.open('$url', '_self')">
        };
    }

    print end_form();
}

###
# BBH lite files version.
#
sub printOrthologNeighborhoodsBBHLite {
    my ($gene_oid) = @_;

    my $cog_color = param("cog_color");
    my $gene_oid  = param("gene_oid");

    my $dbh = dbLogin();
    checkGenePerm( $dbh, $gene_oid );

    printMainForm();
    print "<h1>\n";
    print "Gene Ortholog Neighborhoods\n";
    print "</h1>\n";

    printStatusLine("Loading ...");

    my $temp = getSessionParam("maxNeighborhoods");
    $maxNeighborhoods = $temp if $temp ne "";

    printStartWorkingDiv();

    print "Retrieving ortholog neighborhoods ...<br/>\n";
    webLog ">>> geneNeighborhood start\n";

    my $tclause   = txsClause( "tx", $dbh );
    my $rclause   = WebUtil::urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select tx.taxon_oid
        from taxon tx
        where 1 = 1
        $rclause
        $imgClause
        $tclause
    };
    my %validTaxons;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        $validTaxons{$taxon_oid} = 1;
    }
    $cur->finish();

    my $count = 0;

    # create cache file
    my $sid      = getSessionId();
    my $file     = "neig" . "$$" . "_" . $sid;
    my $path     = "$cgi_tmp_dir/$file";
    my $fh       = newWriteFileHandle($path);
    my $shownext = 0;

    my @recs;
    my @bbhRows = WebUtil::getBBHLiteRows( $gene_oid, \%validTaxons );
    foreach my $r (@bbhRows) {
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $r );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        next if $slen > 1.3 * $qlen;
        next if $slen < 0.7 * $qlen;

        my $strand1 = getStrand( $dbh, $qgene_oid );
        my $strand2 = getStrand( $dbh, $sgene_oid );

        $shownext = 1 if $count > $maxNeighborhoods;
        $count++;
        if ( $count == 1 ) {
            my $rec = "$qgene_oid\t+";
            push( @recs, $rec );
            print $fh "$rec\n";
        }
        my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
        my $rec = "$sgene_oid\t$panelStrand";
        print $fh "$rec\n";
        push( @recs, $rec ) if $count <= $maxNeighborhoods;
    }
    $cur->finish();
    close $fh;

    if ( $count == 0 ) {
        printStatusLine( "Loaded.", 2 );

        #$dbh->disconnect();
        printEndWorkingDiv();
        webError( "No orthologs for other gene neighborhoods found " . "for roughly the same sized gene." );
        return;
    }
    printEndWorkingDiv();

    print "<p>\n";
    print "Neighborhoods of roughly same sized orthologs " . "in user-selected genomes are shown below.<br/>";
    print "</p>\n";

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment, "
               . "White = pseudo gene" );

    printTrackerDiv( $cog_color, $gene_oid );
    printNeighborhoodPanels( $dbh, "orth", \@recs, $count );

    #$dbh->disconnect();

    if ($shownext) {

        # Next button
        my $url = "$section_cgi&page=neigFile&index=2&file=$file" . "&cog_color=$cog_color&show_checkbox=$show_checkbox";
        print qq{
            <input class='smbutton'
                   type="button"
                   value="Next &gt;"
                   onclick="window.open('$url', '_self')">
        };
    }

    print end_form();
}

sub printOrthologNeighborhoodsCog_new_merfs {
    my ( $taxon_oid, $data_type, $gene_oid ) = @_;
    my $workspace_id = "$taxon_oid $data_type $gene_oid";

    my $dbh = dbLogin();

    checkTaxonPerm( $dbh, $taxon_oid );

    printStatusLine("Loading ...");

    # html print
    printMainForm();
    print "<h1>Gene Neighborhoods</h1>\n";

    printStartWorkingDiv();
    print "Getting query gene cog<br/>\n";
    my @cogs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type );
    print $cogs[0] . " <br/>\n";

    my $maxHomologResults = getSessionParam("maxHomologResults");
    $maxHomologResults = 200 if $maxHomologResults eq "";

    my $num_neighborhoods = param("num_neighborhoods");
    $num_neighborhoods = $maxNeighborhoods if ( $num_neighborhoods eq "" );


    my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold ) =
      MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
    print "Top Isolate Hits<br/>\n";

    my $fasta               = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
    my $query_aa_seq_length = length($fasta);

    if ( blankStr($fasta) ) {
        webError("FASTA query sequence not specified.");
        return;
    }

    blastProcCheck();
    my $seq;
    my @lines = split( /\n/, $fasta );
    my $seq_id = "query";
    for my $line (@lines) {
        if ( $line =~ /^>/ ) {
            $line =~ s/>//g;
            if ( length($line) > 240 ) {
                $seq_id = substr( $line, 0, 240 );
            } else {
                $seq_id = $line;
            }
            $seq_id =~ s/^\s+//;
            $seq_id =~ s/\s+$//;
            $seq_id =~ s/\r//g;
            if ( $seq_id eq '' ) {
                $seq_id = "query";
            }
        } else {
            $seq .= "$line\n";
        }
    }

    my $blast_data_dir = $env->{blast_data_dir};

    my $a_flag = "-a 32";      # Number of processors
    my $e_flag = "-e 1e-2";    # E-value cutoff.
    my $b_flag = "-b 1000";    # Maximum number of hits.

    my $img_lid_blastdb = $env->{img_lid_blastdb};
    my $img_iso_blastdb = $env->{img_iso_blastdb};
    my $db              = $img_lid_blastdb;
    $db = $img_iso_blastdb
      if $img_iso_blastdb ne ""
      && param("homologs") eq "topIsolates";
    $db =~ /([a-zA-Z0-9_\-]+)/;
    my $dbFile = "$blast_data_dir/$db";

    webLog( ">>> loadHomologOtfBlast get sequence gene_oid='$gene_oid' " . currDateTime() . "\n" );

    #    my $aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );
    my $aa_seq_length = length($seq);
    my @homologRecs;
    print "Calculating top hits<br>\n";
    require OtfBlast;

    my $filterType   = OtfBlast::genePageTopHits( $dbh, $workspace_id, \@homologRecs, "", 0, 1, '', '', $seq );

    print "Done calculating top hits<br>\n";

    my $nHomologRecs = @homologRecs;

    print "<p>nHomologs: $nHomologRecs\n";

    my $trunc = 0;
    my @homologRecsVaild;
    my $count = 0;
    my @isolateGenes;
    for my $s (@homologRecs) {
        my (
             $gene_oid,    $homolog,   $taxon,  $percent_identity, $query_start0, $query_end0,
             $subj_start0, $subj_end0, $evalue, $bit_score,        $align_length, $opType
          )
          = split( /\t/, $s );

        my ( $homo_gene, $homo_taxon, $perc ) = split( /\_/, $homolog );

        next if $gene_oid eq $homo_gene;

        # filter bad bit sores
        next if ( $bit_score > 10000 );

        # natalia suggest 50% identity too
        next if $percent_identity < 50;

        # +- 30% of query length
        #my $len         = abs( $query_start0 - $query_end0 );
        #my $max_length  = $len * 1.3;
        #my $min_length  = $len * 0.7;
        #my $subj_length = abs( $subj_end0 - $subj_start0 );
        #next if $subj_length > $max_length;
        #next if $subj_length < $min_length;

        if ( $count > $maxHomologResults ) {
            $trunc = 1;
            last;
        }
        $count++;
        my $query_start = $query_start0;
        my $query_end   = $query_end0;
        if ( $query_start0 > $query_end0 ) {
            $query_start = $query_end0;
            $query_end   = $query_start0;
        }

        my $r = "$homo_gene\t";
        $r .= "$percent_identity\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start0\t";
        $r .= "$subj_end0\t";
        $r .= "$align_length\t";
        $r .= "$opType\t";
        push( @homologRecsVaild, $r );
        push(@isolateGenes, $homo_gene);
    }

    # sort by bit score
    my @sortRecs;
    for my $s (@homologRecsVaild) {
        my (
             $homo_gene,    $percent_identity,   $evalue,  $bit_score, $query_start, $query_end,
             $subj_start0, $subj_end0, $align_length, $opType
          )
          = split( /\t/, $s );
         my $r = "$bit_score\t$homo_gene\t";
        push( @sortRecs, $r );
    }
    my @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
    my @gene_oids = ();
    foreach my $sr (@sortRecs2) {
        my ( $bit_score, $gid ) = split( /\t/, $sr );
        push( @gene_oids, $gid );
    }

    print "Retrieving positional information ...<br/>\n";

    my $strand1;
    my $aa_seq_length1 = 0;
    my $aa = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
    $aa_seq_length1 = length($aa);
    my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold ) =
      MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
    $strand1 = $strand;



    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    OracleUtil::insertDataArray( $dbh, 'gtt_num_id', \@isolateGenes );

    my $sql = qq{
        select g.gene_oid, g.strand, g.aa_seq_length
        from gene g
        where g.gene_oid in ( select * from gtt_num_id )
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %strands;
    my %geneOid2Len;
    for ( ; ; ) {
        my ( $gene_oid2, $strand, $aa_seq_length ) = $cur->fetchrow();
        last if !$gene_oid2;
        $strands{$gene_oid2} = $strand;
        $strand1 = $strand if $gene_oid2 eq $gene_oid;
        $geneOid2Len{$gene_oid2} = $aa_seq_length;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, 'gtt_num_id' );

    my @srecs;
    foreach my $gid (@gene_oids) {
        my $strand2 = $strands{$gid};
        my $len     = $geneOid2Len{$gid};
        my $r       = "$gene_oid\t";
        $r .= "$gid\t";
        $r .= "$strand1\t";
        $r .= "$strand2\t";
        $r .= "$len\t";
        push( @srecs, $r );
    }

    printEndWorkingDiv();

    my $count = 0;
    my @recs  = ();
    foreach my $r (@srecs) {
        my ( $gene_oid2, $ortholog, $strand1, $strand2, $len ) =
          split( /\t/, $r );
        last if !$gene_oid2;

        if ( $count == 0 ) {

            # add the ref gene:
            $count++;
            my $rec = "$workspace_id\t+";
            push( @recs, $rec );
        }

        # Filter on length
        #next if $len < 0.7 * $aa_seq_length1 || $len > 1.3 * $aa_seq_length1;

        $count++;
        my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
        my $rec         = "$ortholog\t$panelStrand";

        if ( $count > $num_neighborhoods ) {

            # do nothing
        } else {
            push( @recs, $rec );
        }

    }

#    my $x1 = $#homologRecsVaild;
#    webLog("======= size 1 = $x1\n");
#    my $x1 = $#recs;
#    webLog("======= size 2 = $x1\n");
#    my $x1 = $#srecs;
#    webLog("======= size 3 = $x1\n");

    # in case user entered a value that is too high:
    $num_neighborhoods = $count if ( $num_neighborhoods > $count );

    if ( $count == 0 ) {    # TODO should this be $count < 2 ?
        printStatusLine( "Loaded.", 2 );
        print end_form();

        #$dbh->disconnect();
        my $errMsg = qq{
            No homolog for other gene neighborhoods found
            for roughly the same sized gene.
        };
        webError($errMsg);
        return;
    }

    print "<p>\n";
    print "Neighborhoods of genes in other genomes with the same top COG "
      . "hit and roughly same matching length are shown below.<br/>";
    print "Genes of the same color (except light yellow) ";
    print "are from the same orthologous group (top COG hit).";
    print "</p>\n";

    # provide option to display more or less neighborhood panels
    if ( $count > $num_neighborhoods ) {
        my $nitems     = scalar(@recs);
        my $warningMsg = "";

        $warningMsg = "$nitems (out of $count) neighborhoods are shown.";
        if ( $count > 50 ) {
            $warningMsg .= qq{
                Please note that showing <u>all
                $count</u> neighborhoods may take time.
            };
        }

        print "<p>";
        print "<font color='magenta'>$warningMsg</font><br/>";
        my $max_length = length($count);
        print "Number of neighborhoods to display: ";
        print "<input type='text' name='num_neighborhoods' "
          . "size='1' maxLength=$max_length value='$num_neighborhoods' />\n";
        print "(default=$maxNeighborhoods, total=$count)<br/>";
        my $name = "_section_${section}_geneOrthologNeighborhood";
        print submit(
                      -name  => $name,
                      -value => "Redisplay",
                      -class => 'medbutton'
        );
        print "</p>";

        my $show_checkbox = param("show_checkbox");
        my $cog_color     = param("cog_color");
        print hiddenVar( "taxon_oid",     $taxon_oid );
        print hiddenVar( "data_type",     $data_type );
        print hiddenVar( "gene_oid",      $gene_oid );
        print hiddenVar( "show_checkbox", $show_checkbox );
        print hiddenVar( "cog_color",     $cog_color );
    }

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment, "
               . "<font color='red'>Red</font> = marker gene" );

    printTrackerDiv( "yes", $gene_oid );
    printNeighborhoodPanels( $dbh, "orth", \@recs, $count );

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

#
# isolate
#
sub printOrthologNeighborhoodsCog_new {
    my ($gene_oid) = @_;
    my $temp = getSessionParam("maxNeighborhoods");
    $maxNeighborhoods = $temp if $temp ne "";

    my $num_neighborhoods = param("num_neighborhoods");
    $num_neighborhoods = $maxNeighborhoods if ( $num_neighborhoods eq "" );

    my $taxon_oid;

    my $dbh = dbLogin();

    my $query_aa_seq_length = geneOid2AASeqLength( $dbh, $gene_oid );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
            select g.taxon
            from gene g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    checkTaxonPerm( $dbh, $taxon_oid );

    # +- 30% of query length
    my $max_length = $query_aa_seq_length * 1.3;
    my $min_length = $query_aa_seq_length * 0.7;

    # html print
    printMainForm();
    print "<h1>Gene Neighborhoods</h1>\n";

    my $sql = qq{
        select taxon_display_name from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_display_name) = $cur->fetchrow();
    $cur->finish();

    my $txurl = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $gurl  = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

    print "<p style='width: 650px;'>";
    print alink( $txurl, $taxon_display_name ) . " (Gene: ";
    print alink( $gurl,  $gene_oid ) . ")";
    print "</p>";

    printStatusLine("Loading ...");
    printStartWorkingDiv();

    # get query gene cog
    my $cog = getGeneCog( $dbh, $gene_oid );

    print "Retrieving top homologs ...<br/>\n";

    my @homologRecs;
    my @homologRecsVaild;
    require OtfBlast;
    my $filterType = OtfBlast::genePageTopHits( $dbh, $gene_oid, \@homologRecs, "", '', 1 );
    my @homolog_genes;

    print "Filtering top homologs ...<br/>\n";
    for my $s (@homologRecs) {
        my (
             $gene_oid,    $homolog,   $taxon,  $percent_identity, $query_start0, $query_end0,
             $subj_start0, $subj_end0, $evalue, $bit_score,        $align_length, $opType
          )
          = split( /\t/, $s );
        next if $gene_oid == $homolog;

        # filter bad bit sores
        if ( $bit_score > 10000 ) {
            next;
        }

        # natalia suggest 50% identity too
        next if $percent_identity < 50;

        my $subj_length = abs( $subj_end0 - $subj_start0 );
        next if $subj_length > $max_length;
        next if $subj_length < $min_length;

        push( @homolog_genes,    $homolog );
        push( @homologRecsVaild, $s );
    }

    # TODO I still need all the homolog cogs to match too?
    print "Getting cogs ...<br/>\n";
    my $validGenes_href = getGenesCog( $dbh, $cog, \@homolog_genes );
    my @sortRecs;
    for my $s (@homologRecsVaild) {
        my (
             $gene_oid,    $homolog,   $taxon,  $percent_identity, $query_start0, $query_end0,
             $subj_start0, $subj_end0, $evalue, $bit_score,        $align_length, $opType
          )
          = split( /\t/, $s );

        # homolog does not have the same cog as query gene
        next if ( !exists $validGenes_href->{$homolog} );
        my $r = "$bit_score\t$homolog\t";
        push( @sortRecs, $r );
    }
    my @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
    my @gene_oids = ();
    foreach my $sr (@sortRecs2) {
        my ( $bit_score, $gid ) = split( /\t/, $sr );
        push( @gene_oids, $gid );
    }

    ### obtain positional info
    print "Retrieving positional information ...<br/>\n";

    my $strand1;
    my $aa_seq_length1 = 0;
    my $rclause        = WebUtil::urClause('g.taxon');
    my $imgClause      = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql            = qq{
            select g.strand, g.aa_seq_length
            from gene g
            where g.gene_oid = ?
            $rclause
            $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    ( $strand1, $aa_seq_length1 ) = $cur->fetchrow();
    $cur->finish();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    OracleUtil::insertDataArray( $dbh, 'gtt_num_id', \@gene_oids );

    my $sql = qq{
        select g.gene_oid, g.strand, g.aa_seq_length
        from gene g
        where g.gene_oid in ( select * from gtt_num_id )
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %strands;
    my %geneOid2Len;
    for ( ; ; ) {
        my ( $gene_oid2, $strand, $aa_seq_length ) = $cur->fetchrow();
        last if !$gene_oid2;
        $strands{$gene_oid2} = $strand;
        $strand1 = $strand if $gene_oid2 eq $gene_oid;
        $geneOid2Len{$gene_oid2} = $aa_seq_length;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, 'gtt_num_id' );

    my @srecs;
    foreach my $gid (@gene_oids) {
        my $strand2 = $strands{$gid};
        my $len     = $geneOid2Len{$gid};
        my $r       = "$gene_oid\t";
        $r .= "$gid\t";
        $r .= "$strand1\t";
        $r .= "$strand2\t";
        $r .= "$len\t";
        push( @srecs, $r );
    }

    printEndWorkingDiv();
    webLog ">>> geneNeighborhood start\n";

    my $count = 0;
    my @recs  = ();
    foreach my $r (@srecs) {
        my ( $gene_oid2, $ortholog, $strand1, $strand2, $len ) =
          split( /\t/, $r );
        last if !$gene_oid2;

        if ( $count == 0 ) {

            # add the ref gene:
            $count++;
            my $rec = "$gene_oid2\t+";
            push( @recs, $rec );
        }

        $count++;
        my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
        my $rec         = "$ortholog\t$panelStrand";

        if ( $count > $num_neighborhoods ) {

            # do nothing
        } else {
            push( @recs, $rec );
        }

    }

    # in case user entered a value that is too high:
    $num_neighborhoods = $count if ( $num_neighborhoods > $count );

    if ( $count == 0 ) {    # TODO should this be $count < 2 ?
        printStatusLine( "Loaded.", 2 );
        print end_form();
        my $errMsg = qq{
            No homolog for other gene neighborhoods found
            for roughly the same sized gene.
        };
        webError($errMsg);
        return;
    }

    print "<p>\n";
    print "Neighborhoods of genes in other genomes with the same top COG "
      . "hit and roughly same matching length are shown below.<br/>";
    print "Genes of the same color (except light yellow) ";
    print "are from the same orthologous group (top COG hit).";
    print "</p>\n";

    # provide option to display more or less neighborhood panels
    if ( $count > $num_neighborhoods ) {
        my $nitems     = scalar(@recs);
        my $warningMsg = "";

        $warningMsg = "$nitems (out of $count) neighborhoods are shown.";
        if ( $count > 50 ) {
            $warningMsg .= qq{
                Please note that showing <u>all
                $count</u> neighborhoods may take time.
            };
        }

        print "<p>";
        print "<font color='magenta'>$warningMsg</font><br/>";
        my $max_length = length($count);
        print "Number of neighborhoods to display: ";
        print "<input type='text' name='num_neighborhoods' "
          . "size='1' maxLength=$max_length value='$num_neighborhoods' />\n";
        print "(default=$maxNeighborhoods, total=$count)<br/>";
        my $name = "_section_${section}_geneOrthologNeighborhood";
        print submit(
                      -name  => $name,
                      -value => "Redisplay",
                      -class => 'medbutton'
        );
        print "</p>";

        my $show_checkbox = param("show_checkbox");
        my $cog_color     = param("cog_color");
        print hiddenVar( "taxon_oid",     $taxon_oid );
        print hiddenVar( "gene_oid",      $gene_oid );
        print hiddenVar( "show_checkbox", $show_checkbox );
        print hiddenVar( "cog_color",     $cog_color );
    }

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment, "
               . "<font color='red'>Red</font> = marker gene" );

    printTrackerDiv( "yes", $gene_oid );
    printNeighborhoodPanels( $dbh, "orth", \@recs, $count );

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

sub getGenesCog {
    my ( $dbh, $query_cog, $genes_aref ) = @_;

    OracleUtil::insertDataArray( $dbh, 'gtt_num_id', $genes_aref );

    my %validGenes;
    my $sql = qq{
        select gcg.gene_oid
        from  gene_cog_groups gcg
        where gcg.cog = ?
        and gcg.gene_oid in (select * from gtt_num_id)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $query_cog );
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        $validGenes{$id} = $id;
    }
    OracleUtil::truncTable( $dbh, 'gtt_num_id' );
    return \%validGenes;
}

sub getGeneCog {
    my ( $dbh, $gene_oid ) = @_;
    my $sql = qq{
        select gcg.cog
        from gene_cog_groups gcg
        where gcg.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($cog) = $cur->fetchrow();
    $cur->finish();
    return $cog;
}

###
# On the fly BLAST version
#
sub printOrthologNeighborhoodsCog {
    my ($gene_oid) = @_;

    my $temp = getSessionParam("maxNeighborhoods");
    $maxNeighborhoods = $temp if $temp ne "";

    my $num_neighborhoods = param("num_neighborhoods");
    $num_neighborhoods = $maxNeighborhoods if ( $num_neighborhoods eq "" );

    my $workspace_id = $gene_oid;
    my ( $taxon_oid, $data_type, $g2 ) = split( / /, $workspace_id );

    my $dbh = dbLogin();

    if ( isInt($gene_oid) ) {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql       = qq{
            select g.taxon
            from gene g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        ($taxon_oid) = $cur->fetchrow();
        $cur->finish();
        $data_type = 'database';
    }

    if ( !$taxon_oid ) {

        #$dbh->disconnect();
        return;
    }
    checkTaxonPerm( $dbh, $taxon_oid );

    # html print
    printMainForm();
    print "<h1>Gene Neighborhoods</h1>\n";

    my $sql = qq{
        select taxon_display_name from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_display_name) = $cur->fetchrow();
    $cur->finish();

    my $txurl = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
    my $gurl  = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";

    print "<p style='width: 650px;'>";
    print alink( $txurl, $taxon_display_name ) . " (Gene: ";
    print alink( $gurl,  $gene_oid ) . ")";
    print "</p>";

    printStatusLine("Loading ...");
    printStartWorkingDiv();
    print "Retrieving similarity results ...<br/>\n";

    ### obtain hits
    my @homologs;
    require OtfBlast;
    OtfBlast::geneCogHomologs( $dbh, $workspace_id, \@homologs );

    my @sortRecs;
    my %validTaxon = getSelectedTaxonsHashed($dbh);
    foreach my $h (@homologs) {
        my (
             $gene_oid2,   $homolog,   $taxon,  $percent_identity, $query_start, $query_end,
             $subj_start0, $subj_end0, $evalue, $bit_score,        $align_length
          )
          = split( /\t/, $h );

        next if $homolog eq $gene_oid;
        next if !$validTaxon{$taxon};

        my $r = "$bit_score\t$homolog\t";
        push( @sortRecs, $r );
    }
    my $nRecs = scalar(@sortRecs);
    webLog(">>> $nRecs hits with the same COG  found\n");

    my @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
    my @gene_oids = ();
    foreach my $sr (@sortRecs2) {
        my ( $bit_score, $gid ) = split( /\t/, $sr );
        next if $gid eq $gene_oid;
        push( @gene_oids, $gid );
    }

    my $gene_oid_str = join( ',', @gene_oids );
    if ( blankStr($gene_oid_str) ) {
        printEndWorkingDiv();
        print end_form();

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webError("No homologs were found from this query.");
    }

    ### obtain positional info
    print "Retrieving positional information ...<br/>\n";

    my $strand1;
    my $aa_seq_length1 = 0;
    if (    isInt($gene_oid)
         && $data_type ne 'assembled'
         && $data_type ne 'unassembled' )
    {
        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql       = qq{
            select g.strand, g.aa_seq_length
            from gene g
            where g.gene_oid = ?
            $rclause
            $imgClause
	};
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        ( $strand1, $aa_seq_length1 ) = $cur->fetchrow();
        $cur->finish();
    } else {
        my $aa = MetaUtil::getGeneFaa( $g2, $taxon_oid, $data_type );
        $aa_seq_length1 = length($aa);
        my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold ) =
          MetaUtil::getGeneInfo( $g2, $taxon_oid, $data_type );
        $strand1 = $strand;
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid, g.strand, g.aa_seq_length
        from gene g
        where g.gene_oid in ( $gene_oid_str )
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    my %strands;
    my %geneOid2Len;
    for ( ; ; ) {
        my ( $gene_oid2, $strand, $aa_seq_length ) = $cur->fetchrow();
        last if !$gene_oid2;
        $strands{$gene_oid2} = $strand;
        $strand1 = $strand if $gene_oid2 eq $gene_oid;
        $geneOid2Len{$gene_oid2} = $aa_seq_length;
    }
    $cur->finish();

    my @srecs;
    foreach my $gid (@gene_oids) {
        my $strand2 = $strands{$gid};
        my $len     = $geneOid2Len{$gid};
        my $r       = "$gene_oid\t";
        $r .= "$gid\t";
        $r .= "$strand1\t";
        $r .= "$strand2\t";
        $r .= "$len\t";
        push( @srecs, $r );
    }

    printEndWorkingDiv();
    webLog ">>> geneNeighborhood start\n";

    my $count = 0;
    my @recs  = ();
    foreach my $r (@srecs) {
        my ( $gene_oid2, $ortholog, $strand1, $strand2, $len ) =
          split( /\t/, $r );
        last if !$gene_oid2;

        if ( $count == 0 ) {

            # add the ref gene:
            $count++;
            my $rec = "$gene_oid2\t+";
            push( @recs, $rec );
        }

        # Filter on length
        next if $len < 0.7 * $aa_seq_length1 || $len > 1.3 * $aa_seq_length1;

        $count++;
        my $panelStrand = $strand1 eq $strand2 ? "+" : "-";
        my $rec         = "$ortholog\t$panelStrand";

        if ( $count > $num_neighborhoods ) {

            # do nothing
        } else {
            push( @recs, $rec );
        }

    }

    # in case user entered a value that is too high:
    $num_neighborhoods = $count if ( $num_neighborhoods > $count );

    if ( $count == 0 ) {    # TODO should this be $count < 2 ?
        printStatusLine( "Loaded.", 2 );
        print end_form();

        #$dbh->disconnect();
        my $errMsg = qq{
            No orthologs for other gene neighborhoods found
            for roughly the same sized gene.
        };
        webError($errMsg);
        return;
    }

    print "<p>\n";
    print "Neighborhoods of genes in other genomes with the same top COG "
      . "hit and roughly same matching length are shown below.<br/>";
    print "Genes of the same color (except light yellow) ";
    print "are from the same orthologous group (top COG hit).";
    print "</p>\n";

    # provide option to display more or less neighborhood panels
    if ( $count > $num_neighborhoods ) {
        my $nitems     = scalar(@recs);
        my $warningMsg = "";

        $warningMsg = "$nitems (out of $count) neighborhoods are shown.";
        if ( $count > 50 ) {
            $warningMsg .= qq{
                Please note that showing <u>all
                $count</u> neighborhoods may take time.
            };
        }

        print "<p>";
        print "<font color='magenta'>$warningMsg</font><br/>";
        my $max_length = length($count);
        print "Number of neighborhoods to display: ";
        print "<input type='text' name='num_neighborhoods' "
          . "size='1' maxLength=$max_length value='$num_neighborhoods' />\n";
        print "(default=$maxNeighborhoods, total=$count)<br/>";
        my $name = "_section_${section}_geneOrthologNeighborhood";
        print submit(
                      -name  => $name,
                      -value => "Redisplay",
                      -class => 'medbutton'
        );
        print "</p>";

        my $show_checkbox = param("show_checkbox");
        my $cog_color     = param("cog_color");
        print hiddenVar( "taxon_oid",     $taxon_oid );
        print hiddenVar( "data_type",     $data_type );
        print hiddenVar( "gene_oid",      $gene_oid );
        print hiddenVar( "show_checkbox", $show_checkbox );
        print hiddenVar( "cog_color",     $cog_color );
    }

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment, "
               . "<font color='red'>Red</font> = marker gene" );

    printTrackerDiv( "yes", $gene_oid );
    printNeighborhoodPanels( $dbh, "orth", \@recs, $count );

    printStatusLine( "Loaded.", 2 );

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# getStrand - queries for the strand (+ or -) for the gene_oid
############################################################################
sub getStrand {
    my ( $dbh, $gene_oid ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.strand
        from gene g
        where g.gene_oid = ?
    };
#        $rclause
#        $imgClause

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($strand) = $cur->fetchrow();
    $cur->finish();
    return $strand;
}

############################################################################
# printSelectedNeighborhoods - Print neighborhoods for genes selected in
#                              the gene cart.
#    Inputs:
#      gene_oids_ref    Reference to gene_oid string, comma separated.
#      alignGenes   1 = align genes in same direction
#                   0 = allow original strand direction
############################################################################
sub printSelectedNeighborhoods {
    my @gene_oids          = param("gene_oid");
    my $alignGenes         = param("alignGenes");
    my $cog_color          = param("cog_color");
    my $gene_oid_neigh_str = param("gene_oid_neigh_str");
    my $index              = param("index");                # for next page
    $index = 1 if ( $index eq "" );

    my $geneCart             = new GeneCartStor();
    my $gene_cart_genes_href = $geneCart->getGeneOids();

    my @sorted = sort { $a <=> $b } @gene_oids;             # numerical sort
    @gene_oids = @sorted;

    my $temp = getSessionParam("maxNeighborhoods");
    $maxNeighborhoods = $temp if $temp ne "";

    if ( $index > 1 ) {
        my $start = ( $index - 1 ) * $maxNeighborhoods;
        my $end   = $#gene_oids;

        my @tmp;
        for ( my $i = $start ; $i <= $end ; $i++ ) {
            push( @tmp, $gene_oids[$i] );
        }
        @gene_oids = @tmp;
    }

    my $gene_oids_ref = \@gene_oids;
    my $nGenes        = @$gene_oids_ref;
    if ( $nGenes == 0 ) {
        webError("Please select some genes to display neighborhoods.");
        return;
    }

    printMainForm();

    my $folder = param('directory');
    if ($folder) {
        print "<h1>Workspace Gene Set Neighborhoods</h1>\n";
        print hiddenVar( 'directory', $folder );
    } else {
        print "<h1>Gene Cart Neighborhoods</h1>\n";
    }

    print qq{
        <script language="JavaScript" type="text/javascript">
        function mySubmit(x, c) {
            var f = document.mainForm.gene_oid_neigh;
            var str = "";
            for (var i = 0; i < f.length; i++) {
                var e = f[i];
                if (e.type == "checkbox" && e.checked == true) {
                    str = str + "," + e.value;
                }
            }

            //alert(str);
            document.mainForm.gene_oid_neigh_str.value =
		document.mainForm.gene_oid_neigh_str.value + str;
            document.mainForm.index.value = x;
            document.mainForm.cog_color.value = c;
            document.mainForm.submit();
        }
        </script>
    };

    print hiddenVar( "alignGenes",           $alignGenes );
    print hiddenVar( "index",                1 );
    print hiddenVar( "section",              $section );
    print hiddenVar( "page",                 "selectedGeneNeighborhoods" );
    print hiddenVar( "cog_color",            "$cog_color" );
    print hiddenVar( "show_checkbox",        "$show_checkbox" );
    print hiddenVar( "show_checkbox_remove", "$show_checkbox_remove" );
    print hiddenVar( "gene_oid_neigh_str",   "$gene_oid_neigh_str" );

    my $gene_oid_str = join( ',', @$gene_oids_ref );
    my @genegroups;    # when there are over 1000 genes - oracle limit
    my @allgroups;     # make groups of genes
    my $items = 0;

    foreach my $id (@sorted) {
        # print original list of genes
        print hiddenVar( "gene_oid", $id );
    }

    foreach my $id (@gene_oids) {
        if ( !isInt($id) ) {
            next;
        }

        push( @genegroups, $id );
        $items++;
        if ( $items == 1000 ) {
            my @gids;
            foreach my $g (@genegroups) {
                push( @gids, $g );
            }
            my $genestr = join( ",", @gids );
            push( @allgroups, $genestr );
            @genegroups = ();
            $items      = 0;
        }
    }

    if ( $items > 0 ) {
        my $genestr = join( ",", @genegroups );
        push( @allgroups, $genestr );
    }

    my $dbh = dbLogin();

    my @bad_gene_oids;
    foreach my $genes (@allgroups) {
        last if !$genes;

        my $rclause   = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $sql       = qq{
    	    select g.gene_oid
    	    from gene g
    	    where g.obsolete_flag = 'Yes'
    	    and g.gene_oid in( $genes )
    	    $rclause
    	    $imgClause
    	};

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ($gene_oid) = $cur->fetchrow();
            last if !$gene_oid;
            push( @bad_gene_oids, $gene_oid );
        }
        $cur->finish();
    }
    if ( scalar(@bad_gene_oids) > 0 ) {
        my $gene_oid_str = join( ',', @bad_gene_oids );
        webError( "Obsolete genes (gene_oid=($gene_oid_str)) "
		. "are not supported for gene neighborhood viewing." );
        return;
    }

    my $direction =
	"5'-3' direction of each gene selected in the gene cart left to right";
    $direction =
	"5'-3' direction of the (+) plus strand always left to right, on top"
	if (!$alignGenes);

    print "<p>\n";
    print "Neighborhoods of genes selected in the gene cart are shown below.";
    print "<br/>Genes of the same color (except light yellow) ";
    print "are from the same orthologous group (top COG hit).";
    print "<br/><u>Note</u>: You chose to view the $direction ";
    print "</p>\n";

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment, "
               . "<font color='red'>Red</font> = selected gene(s)" );

    printTrackerDiv( $cog_color, $sorted[0] );
    printStatusLine("Loading ...");

    my @recs;
    my $count = 0;
    foreach my $genes (@gene_oids) {
        last if !$genes;

        if ( isInt($genes) ) {
            my $rclause   = WebUtil::urClause('tx');
            my $imgClause = WebUtil::imgClause('tx');
            my $sql       = qq{
    	        select g.gene_oid, g.strand, tx.ncbi_taxon_id
                from gene g, taxon tx
    	        where g.gene_oid in( $genes )
      	        and g.taxon = tx.taxon_oid
    	        and g.obsolete_flag = 'No'
    	        and g.end_coord > 0
                $rclause
                $imgClause
    	        order by g.gene_oid
    	    };

            #print "printSelectedNeighborhoods sql: ".$sql."<br/>\n";
            my $cur = execSql( $dbh, $sql, $verbose );

            for ( ; ; ) {
                my ( $gene_oid, $strand, $taxon ) = $cur->fetchrow();
                last if !$gene_oid;

                $count++;
                last if $count > $maxNeighborhoods;

                my $panelStrand = $strand eq "+" ? "+" : "-";
                $panelStrand = "+" if !$alignGenes;
                my $rec = "$gene_oid\t$panelStrand";
                push( @recs, $rec );
            }
            $cur->finish();

        } else {
            # MER-FS
            $count++;
            last if $count > $maxNeighborhoods;

            my ( $t2, $d2, $g2 ) = split( / /, $genes );
            if ( $d2 eq 'assembled' ) {
                my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name,
		     $start_coord, $end_coord, $strand, $scaffold_oid )
                  = MetaUtil::getGeneInfo( $g2, $t2, $d2 );
                my $panelStrand = $strand eq "+" ? "+" : "-";
                $panelStrand = "+" if !$alignGenes;
                my $rec = "$genes\t$panelStrand";
                push( @recs, $rec );
            }
        }
    }

    printNeighborhoodPanels( $dbh, "gCart$alignGenes", \@recs, $count, $gene_cart_genes_href );

    #$dbh->disconnect();

    if ( $count > $maxNeighborhoods ) {
        if ( $index > 1 ) {

            # print Prev button
            print qq{
		<input class='smbutton'
		       type="button"
		       value="&lt; Prev"
		       onclick="javascript:history.back()">
	    };
        }
        $index++;

        # Next button
        print qq{
            <input class='smbutton'
		   type="button"
		   value="Next &gt;"
		   onclick="javascript:mySubmit('$index', '$cog_color')">
	};
    } else {
        if ( $index > 1 ) {

            # print Prev button
            print qq{
                <input class='smbutton'
                       type="button"
                       value="&lt; Prev"
                       onclick="javascript:history.back()">
            };
        }
    }

    print end_form();
}

############################################################################
# printNeighborhoodPanels - Print the ScaffoldPanel's.
#   Print out the neighborhoods.
#   Inputs:
#     dbh - Database handle.
#     tag - Tag for temp files
#     recs_ref - Reference to information about records on genes.
#     count -  Current count of neighborhoods to be printed.
############################################################################
sub printNeighborhoodPanels {
    my ( $dbh, $tag, $recs_ref, $count, $gene_cart_genes_href ) = @_;

    print toolTipCode();
    print "<script src='$base_url/overlib.js'></script>\n";
    print "<table border='0'>" if ( $show_checkbox || $show_checkbox_remove );

    ## Get ortholog colors
    my %groupCount;
    for my $r (@$recs_ref) {
        my ( $gene_oid, $panelStrand ) = split( /\t/, $r );
        webLog "get color gene_oid='$gene_oid' " . currDateTime() . "\n"
          if $verbose >= 1;
        getColors( $dbh, $gene_oid, \%groupCount );
    }
    my %groupColors;
    assignGroupColors( \%groupCount, \%groupColors );

    ## Print neighborhoods
    for my $r (@$recs_ref) {
        my ( $gene_oid, $panelStrand ) = split( /\t/, $r );
        webLog "print gene_oid='$gene_oid' " . currDateTime() . "\n"
          if $verbose >= 1;

        print "<tr>\n" if ( $show_checkbox || $show_checkbox_remove );
        printOneNeighborhood( $dbh, $tag, $gene_oid, $panelStrand,
			      \%groupColors, $gene_cart_genes_href );
        print "</tr>\n" if ( $show_checkbox || $show_checkbox_remove );
    }

    print "</table>\n" if ( $show_checkbox || $show_checkbox_remove );
    print "<br/>\n";

    if ( $count > $maxNeighborhoods ) {
        my $s = "Results limited to $maxNeighborhoods neighborhoods.\n";
        $s .=
          "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Taxon Gene Neighborhoods\" limit. )";
        printStatusLine( $s, 2 );
    }

    #$dbh->disconnect();

    if ( $count <= $maxNeighborhoods ) {
        printStatusLine( "Loaded", 2 );
    }
}

############################################################################
# printOneNeighborhood - Print one neighborhood for one ScaffoldPanel.
#   Inputs:
#      dbh - Database handle.
#      tag - Tag for temp files.
#      gene_oid0 - Original gene object identifier
#      panelStrand - Orientation of panel ( "+" or "-" )
#      groupColors_ref - Reference to mapping of COG to group colors.
############################################################################
sub printOneNeighborhood {
    my ( $dbh, $tag, $gene_oid0, $panelStrand, $groupColors_ref, $gene_cart_genes_href ) = @_;

    my $folder = param('directory');
    my ( $scaffold_oid, $scaffold_name, $scf_seq_length, $start_coord0,
	 $end_coord0, $strand0, $taxon_display_name, $taxon_oid );
    my $topology = "linear";

    if ( isInt($gene_oid0) ) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');

        my $sql = qq{
           select scf.scaffold_oid, scf.scaffold_name, ss.seq_length,
              g.start_coord, g.end_coord, g.strand, tx.taxon_display_name,
              tx.taxon_oid, scf.mol_topology
           from gene g, scaffold scf, scaffold_stats ss, taxon tx
           where g.taxon = tx.taxon_oid
           $rclause
           $imgClause
           and g.gene_oid = ?
           and g.scaffold = scf.scaffold_oid
           and scf.scaffold_oid = ss.scaffold_oid
           and g.obsolete_flag = 'No'
           and g.start_coord > 0
           and g.end_coord > 0
           and scf.ext_accession is not null
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid0 );
        ( $scaffold_oid, $scaffold_name, $scf_seq_length,
	  $start_coord0, $end_coord0,
	  $strand0, $taxon_display_name, $taxon_oid, $topology )
	    = $cur->fetchrow();
        $cur->finish();

    } else {
        # MER-FS
        my ( $t2, $d2, $g2 ) = split( / /, $gene_oid0 );
        if ( isInt($t2) ) {
            my $rclause   = WebUtil::urClause('tx');
            my $imgClause = WebUtil::imgClause('tx');
            my $sql       = qq{
                select tx.taxon_display_name
                from taxon tx
                where tx.taxon_oid = ?
                $rclause
                $imgClause
            };
            my $cur = execSql( $dbh, $sql, $verbose, $t2 );
            ($taxon_display_name) = $cur->fetchrow();
            $cur->finish();
        }

        if ( $d2 eq 'assembled' ) {
            my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name,
		      $start_coord, $end_coord, $strand, $scaf_oid ) =
              MetaUtil::getGeneInfo( $g2, $t2, $d2 );
            $scaffold_oid = $t2 . "_" . $d2 . "_" . $scaf_oid;
            if ( length($taxon_display_name) > 80 ) {
                $scaffold_name =
                    substr( $taxon_display_name, 0, 40 ) . " ... "
                  . substr( $taxon_display_name, length($taxon_display_name) - 40 ) . ": "
                  . $scaf_oid;
            } else {
                $scaffold_name = $taxon_display_name . ": " . $scaf_oid;
            }

            my ( $scaf_len, $scaf_gc, $scaf_gene_cnt )
		      = MetaUtil::getScaffoldStats( $t2, $d2, $scaf_oid );

            $scf_seq_length = $scaf_len;
            $start_coord0   = $start_coord;
            $end_coord0     = $end_coord;
            $strand0        = $strand;
        }
    }

    return if !$scaffold_oid;

    my $scaffold_name2 = $scaffold_name;
    my $bin_names;
    if ( isInt($scaffold_oid) ) {
        $bin_names = getScaffold2BinNames( $dbh, $scaffold_oid );
    }
    $scaffold_name2 .= " (bin(s): $bin_names)"
      if $bin_names ne "";

    webLog "printOneNeighborhood: "
	 . "gene_oid=$gene_oid0 $start_coord0..$end_coord0 ($strand0) "
	 . "scaffold=$scaffold_oid\n";

    #ANNA: fix the size of the neighborhood if scaffold is smaller
    #$flank_length = $scf_seq_length/2
    #if $scf_seq_length/2 < $flank_length && $topology eq "circular";

    my $mid_coord   = int(($end_coord0 - $start_coord0)/2) + $start_coord0 + 1;
    my $left_flank  = $mid_coord - $flank_length + 1;
    my $right_flank = $mid_coord + $flank_length + 1;

    # 25000 bp on each side of midline
    my ( $rf1, $rf2, $lf1, $lf2 );    # when circular and in boundry line
    my $in_boundry = 0;
    if ( $topology eq "circular" && $flank_length < $scf_seq_length/2 ) {
        if ( $left_flank <= 1 ) {
            my $left_flank2 = $scf_seq_length + $left_flank;
            $lf1        = $left_flank2;
            $rf1        = $scf_seq_length;
            $lf2        = 1;
            $rf2        = $right_flank;
            $in_boundry = 1;
        } elsif (    $left_flank <= $scf_seq_length
                  && $right_flank >= $scf_seq_length )
        {

            my $right_flank2 = $right_flank - $scf_seq_length;
            $lf1        = $left_flank;
            $rf1        = $scf_seq_length;
            $lf2        = 1;
            $rf2        = $right_flank2;
            $in_boundry = 1;
        }
    }

    my @recs = ();
    #my %gene2Enzymes;
    if ( isInt($gene_oid0) && isInt($scaffold_oid) ) {
        #WebUtil::gene2EnzymesMap( $dbh, $scaffold_oid, $left_flank, $right_flank, \%gene2Enzymes );

    } else {
        # MER-FS
        my ( $t2, $d2, $g2 )   = split( / /,  $gene_oid0 );
        my ( $t3, $d3, @rest ) = split( /\_/, $scaffold_oid );
        my $s3 = join( "_", @rest );
        my @genes_on_s = MetaUtil::getScaffoldGenes( $t2, $d2, $s3 );

        foreach my $g (@genes_on_s) {
            my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name,
		         $start_coord, $end_coord, $strand, $seq_id,
                 $source ) = split( /\t/, $g );

            next if ( !$gene_oid || ( !$start_coord && !$end_coord ) );
            if ( $start_coord >= $left_flank && $end_coord <= $right_flank ) {
                # in the range
            } elsif (    ( $end_coord + $start_coord ) / 2 >= $left_flank
                      && ( $end_coord + $start_coord ) / 2 <= $right_flank )
            {
                # in the range
            } else {
                next;
            }

            my @cogs = MetaUtil::getGeneCogId( $gene_oid, $t2, $d2 );
            my $cluster_id = join( ",", @cogs );

            my ( $prod_name, $source )
        		= MetaUtil::getGeneProdNameSource( $gene_oid, $t2, $d2 );
            if ($prod_name) {
                $gene_display_name = $prod_name;
            }
            my $aa_seq        = MetaUtil::getGeneFaa( $gene_oid, $t2, $d2 );
            my $aa_seq_length = length($aa_seq);

            my $workspace_id = "$t2 $d2 $gene_oid";

            my $r =
                "$workspace_id\t\t$gene_display_name\t"
              . "$locus_type\t$locus_tag\t"
              . "$start_coord\t$end_coord\t$strand\t"
              . "$aa_seq_length\t$cluster_id\t$s3\t" . "No\t\t";
            push @recs, ($r);
        }
    }

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select distinct g.gene_oid, g.gene_symbol,
              g.gene_display_name,
              g.locus_type, g.locus_tag,
              g.start_coord, g.end_coord, g.strand,
              g.aa_seq_length, dt.cog, g.scaffold,
              g.is_pseudogene, g.cds_frag_coord
        from gene_cog_groups dt, gene g
        where g.scaffold = ?
        $rclause
        $imgClause
        and g.gene_oid = dt.gene_oid (+)
        and g.start_coord > 0
        and g.end_coord > 0
        and ( (g.start_coord >= ? and g.end_coord <= ?) or
              ( (g.end_coord + g.start_coord) / 2 >= ? and
                (g.end_coord + g.start_coord) / 2 <= ? ) )
    };
    my @binds = ( $scaffold_oid, $left_flank, $right_flank, $left_flank, $right_flank );

    my ( $t2, $d2, $g2 ) = split( / /, $gene_oid0 );
    if ( !isInt($gene_oid0) ) {
        $taxon_oid = $t2;
    }
    my $id = "gn.$tag.$scaffold_oid.$start_coord0.x.$end_coord0.$$";
    my $args = {
               id                      => $id,
               start_coord             => $left_flank,
               end_coord               => $right_flank,
               coord_incr              => 5000,
               strand                  => $panelStrand,
               title                   => $scaffold_name2,
               has_frame               => 1,
               gene_page_base_url      => "$main_cgi?section=GeneDetail&page=geneDetail",
               meta_gene_page_base_url => "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail&taxon_oid=$t2&data_type=$d2",
               color_array_file        => $env->{large_color_array_file},
               tmp_dir                 => $tmp_dir,
               tmp_url                 => $tmp_url,
               scf_seq_length          => $scf_seq_length,
               topology                => $topology,
               in_boundry              => $in_boundry,
               tx_url                  => "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid"
    };

    my $sp          = new ScaffoldPanel($args);
    my $color_array = $sp->{color_array};
    my %currGene;

    my $parts = 1;
    my ( @binds1, @binds2 );
    if ($in_boundry) {
        @binds1 = ( $scaffold_oid, $lf1, $rf1, $lf1, $rf1 );
        @binds2 = ( $scaffold_oid, $lf2, $rf2, $lf2, $rf2 );
        $parts  = 2;
    }
    if ( isInt($gene_oid0) && isInt($scaffold_oid) ) {
        for ( my $i = 0 ; $i < $parts ; $i++ ) {
            my @mybinds = @binds;
            if ($in_boundry) {
                @mybinds = @binds1;
                if ( $i == 1 ) {
                    @mybinds = @binds2;
                }
            }
            my $cur = execSql( $dbh, $sql, $verbose, @mybinds );
            for ( ; ; ) {
                my (
                     $gene_oid, $gene_symbol, $gene_display_name,
                     $locus_type, $locus_tag, $start_coord, $end_coord,
                     $strand, $aa_seq_length,
                     $cluster_id, $scaffold, $is_pseudogene, $cds_frag_coord
                  )
                  = $cur->fetchrow();
                last if !$gene_oid;

                my $r =
                    "$gene_oid\t$gene_symbol\t$gene_display_name\t"
                  . "$locus_type\t$locus_tag\t"
                  . "$start_coord\t$end_coord\t$strand\t"
                  . "$aa_seq_length\t$cluster_id\t$scaffold\t"
                  . "$is_pseudogene\t$cds_frag_coord";
                push @recs, ($r);
            }
            $cur->finish();
        }
    }

    foreach my $r (@recs) {
        my (
             $gene_oid, $gene_symbol, $gene_display_name, $locus_type,
             $locus_tag, $start_coord, $end_coord, $strand, $aa_seq_length,
             $cluster_id, $scaffold, $is_pseudogene, $cds_frag_coord
          )
          = split( /\t/, $r );

        my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );

        my $label = $gene_symbol;
        $label = $locus_tag       if $label eq "";
        $label = "gene $gene_oid" if $label eq "";
        $label .= " : $gene_display_name";
        $label .= " $start_coord..$end_coord";
        $label .= GeneUtil::formMultFragCoordsLine( @coordLines );

        if ( $locus_type eq "CDS" ) {
            $label .= "(${aa_seq_length}aa)";
        } else {
            my $len = $end_coord - $start_coord + 1;
            $label .= "(${len}bp)";
        }
        my $group_color_idx = $groupColors_ref->{$cluster_id};
        my $color           = $sp->{color_yellow};
        $color = @$color_array[$group_color_idx]
          if $group_color_idx ne ""
          && !blankStr($cluster_id);

        my $cog_color = param("cog_color");
        if ( !blankStr($cluster_id) && $cog_color ne "" ) {
            $color = GeneCassette::getCogColor( $sp, $cluster_id );
        }

        $color = $sp->{color_red} if $gene_oid eq $gene_oid0;

        # All pseudo gene should be white - 2008-04-10 ken
        if ( ( $gene_oid ne $gene_oid0 ) && ( uc($is_pseudogene) eq "YES" ) ) {
            $color = $sp->{color_white};
        }

        my ( $r, $g, $b ) = $sp->{im}->rgb($color);
        my $cog;
        $cog = "($cluster_id)" if $cluster_id ne "";
        my $rgbStr = sprintf( "#%02x%02x%02x", $r, $g, $b );

        $label .= "${cog}";
        if ( $gene_oid eq $gene_oid0 ) {
            $currGene{start_coord} = $start_coord;
            $currGene{end_coord}   = $end_coord;
            $currGene{strand}      = $strand;
            $currGene{label}       = $label;
        }

        $color = $sp->{color_yellow} if $color eq "";

        if ( scalar(@coordLines) > 1 ) {
            foreach my $line (@coordLines) {
                my ( $frag_start, $frag_end ) = split( /\.\./, $line );
                my $tmplabel = $label . " $frag_start..$frag_end";
                $sp->addGene( $gene_oid, $frag_start, $frag_end,
			      $strand, $color, $tmplabel );
            }
        } else {
            $sp->addGene( $gene_oid, $start_coord, $end_coord,
			  $strand, $color, $label );
        }

        if ( $gene_cart_genes_href ne ""
             && exists $gene_cart_genes_href->{$gene_oid} )
        {
            # color gene cart genes red
            $sp->addBox( $start_coord, $end_coord, $sp->{color_red},
			 $strand, "Gene Cart $label", $gene_oid );
        }
    }    # end foreach r

    ## Current gene overlay
    my $gene_oid    = $gene_oid0;
    my $start_coord = $currGene{start_coord};
    my $end_coord   = $currGene{end_coord};
    my $strand      = $currGene{strand};
    my $label       = $currGene{label};
    my $color       = $sp->{color_red};

    my $bracketType1 = "left";
    my $bracketType2 = "right";
    if ( $panelStrand eq "-" ) {
        $bracketType1 = "right";
        $bracketType2 = "left";
    }
    if ( $left_flank <= 1 ) {
        if ( $topology eq "circular" ) {
            $sp->addBracket( 1, "boundry" );
        } else {
            $sp->addBracket( 1, $bracketType1 );
        }
    }
    if (    $left_flank <= $scf_seq_length
         && $scf_seq_length <= $right_flank )
    {
        if ( $topology eq "circular" ) {
            $sp->addBracket( $scf_seq_length, "boundry" );
        } else {
            $sp->addBracket( $scf_seq_length, $bracketType2 );
        }
    }

    if ( isInt($scaffold_oid) ) {
        WebUtil::addNxFeatures( $dbh, $scaffold_oid, $sp, $panelStrand, $left_flank, $right_flank );
        WebUtil::addRepeats( $dbh, $scaffold_oid, $sp, $panelStrand, $left_flank, $right_flank );
        WebUtil::addIntergenic( $dbh, $scaffold_oid, $sp, $panelStrand, $left_flank, $right_flank );
    }

    my $s = $sp->getMapHtml("overlib");

    # $gene_oid0 - the red gene marker gene
    if ($show_checkbox) {
        my $ck   = "";
        my $href = getSessionParam("neighborhood");
        if ( $href ne "" && exists $href->{$gene_oid0} ) {
            $ck = "checked";
        }
        my $url = "xml.cgi?section=Cart&gene_oid=$gene_oid0";
        print qq{
            <td>
            <input id='ncbox$gene_oid0'
                   name='plotbox'
                   type='checkbox'
                   $ck
                   title='Add to neighborhood cart'
                   value='$gene_oid0'
                   onclick="addNeighborhoodCart('$url', 'ncbox$gene_oid0')">
            </td>
            <td>
        };
    } elsif ($show_checkbox_remove) {
        my $title = "Remove selected gene from gene cart";
        if ($folder) {
            $title = " ";
        }

        print qq{
            <td>
            <input name='gene_oid_neigh'
                   type='checkbox'
                   title='$title'
                   value='$gene_oid0' >
            </td>
            <td>
        };
    }
    print "$s\n";

    print "</td>\n" if ( $show_checkbox || $show_checkbox_remove );
}

############################################################################
# getColors - Get color mapping for orthologs.
#  WARNING: "duplicate" SQL code from above. Need to keep in sync.
#   Inputs:
#     dbh - Database handle.
#     gene_oid0 - Original gene object identifier.
#     groupCounts_ref - Reference to group counts of COGs.
############################################################################
sub getColors {
    my ( $dbh, $gene_oid0, $groupCount_ref ) = @_;

    my ( $scaffold_oid, $start_coord0, $end_coord0, $strand0, $taxon_oid, $taxon_display_name );

    if ( isInt($gene_oid0) ) {
        my $rclause   = WebUtil::urClause('tx');
        my $imgClause = WebUtil::imgClause('tx');
        my $sql       = qq{
            select scf.scaffold_oid, g.start_coord, g.end_coord, g.strand,
                   tx.taxon_oid, tx.taxon_display_name
            from gene g, scaffold scf, taxon tx
            where g.gene_oid = ?
            and g.taxon = tx.taxon_oid
            and g.scaffold = scf.scaffold_oid
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid0 );
        ( $scaffold_oid, $start_coord0, $end_coord0, $strand0, $taxon_oid, $taxon_display_name ) = $cur->fetchrow();
        if ( !$scaffold_oid ) {
            webDie("Cannot find gene_oid '$gene_oid0'\n");
        }
        webLog "getColor: gene_oid=$gene_oid0 $start_coord0..$end_coord0 ($strand0) scaffold=$scaffold_oid\n";
        $cur->finish();
    } else {
        my ( $t2, $d2, $g2 ) = split( / /, $gene_oid0 );
        my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaf_oid ) =
          MetaUtil::getGeneInfo( $g2, $t2, $d2 );
        $start_coord0 = $start_coord;
        $end_coord0   = $end_coord;
        $strand0      = $strand;
        $scaffold_oid = $t2 . "_" . $d2 . "_" . $scaf_oid;
        $taxon_oid    = $t2;
    }

    my $mid_coord   = int( ( $end_coord0 - $start_coord0 ) / 2 ) + $start_coord0 + 1;
    my $left_flank  = $mid_coord - $flank_length + 1;
    my $right_flank = $mid_coord + $flank_length + 1;

    if ( isInt($gene_oid0) ) {
        my $sql = qq{
	    select dt.gene_oid, dt.cog
            from gene_cog_groups dt
	    where dt.scaffold = ?
	    and dt.subj_start >= ?
	    and dt.subj_end <= ?
	    and dt.cog is not null
        };
        my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid, $left_flank, $right_flank );
        my %cluster2Scaffold;

        for ( ; ; ) {
            my ( $gene_oid, $cluster_id ) = $cur->fetchrow();
            last if !$gene_oid;
            next if blankStr($cluster_id);
            if ( $cluster2Scaffold{$cluster_id} ne $scaffold_oid ) {
                $groupCount_ref->{$cluster_id}++;
            }
            $cluster2Scaffold{$cluster_id} = $scaffold_oid;
        }
        $cur->finish();

    } else {
        # MER-FS
        my ( $t3, $d3, @rest ) = split( /\_/, $scaffold_oid );
        my $s3 = join( "_", @rest );
        my @genes_on_s = MetaUtil::getScaffoldGenes( $taxon_oid, 'assembled', $s3 );

        my %cluster2Scaffold;
        foreach my $g (@genes_on_s) {
            my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id,
                 $source ) = split( /\t/, $g );
            if (    $start_coord >= $left_flank
                 && $end_coord <= $right_flank )
            {
                my @cogs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, 'assembled' );
                my $cluster_id = join( ",", @cogs );
                if (    $cluster_id
                     && $cluster2Scaffold{$cluster_id} ne $scaffold_oid )
                {
                    $groupCount_ref->{$cluster_id}++;
                }
                $cluster2Scaffold{$cluster_id} = $scaffold_oid;
            }
        }
    }
}

############################################################################
# assignGroupColors - Assign colors if it appears more than once
#  for two orthologs to hilite ortholog relationships.
#    Inputs:
#       groupCount_ref - Input to group counts.
#       group2Color_ref - Reference output mapping group to a color.
############################################################################
sub assignGroupColors {
    my ( $groupCount_ref, $group2Color_ref ) = @_;

    ## Get groups with largest count first.
    my @countRecs;
    my @keys = keys(%$groupCount_ref);
    foreach my $k (@keys) {
        my $count = $groupCount_ref->{$k};
        my $r = sprintf( "%07d\t%s", $count, $k );
        push( @countRecs, $r );
    }
    my @countRecsSorted = reverse( sort(@countRecs) );
    my %group2Color;
    for ( my $i = 0 ; $i < scalar(@countRecsSorted) ; $i++ ) {
        last if $i > $maxColors;
        my ( $count, $groupId ) = split( /\t/, $countRecsSorted[$i] );
        last                                     if $count < 2;
        webLog "count=$count groupId=$groupId\n" if $verbose >= 3;
        ## Set color index
        $group2Color_ref->{$groupId} = $i;
    }
}

############################################################################
# getScaffCogsByFile - Get scaffold COGs by cache file.
#  This is faster than querying the database.  The file is a cache
#  of the database already split by scaffolds.
#
#  OBSOLETE
#
#    Inputs:
#      taxon_oid - Taxon object identifier.
#      scaffold_oid - Scaffold object identifier.
#      left_flank - Coordinate of left margin.
#      right_flank - Coordinate of right margin.
#      recs_ref - Reference to gene record information.
############################################################################
sub getScaffoldCogsByFile {
    my ( $taxon_oid, $scaffold_oid, $left_flank, $right_flank, $recs_ref ) = @_;

    my $inFile = "$web_data_dir/tab.files/scaffoldCogs" . "/$taxon_oid/$scaffold_oid.tab.txt";
    my $rfh = newReadFileHandle( $inFile, "getScaffoldCogsByFile", 1 );
    if ( !$rfh ) {
        webLog("getScaffoldCogsByFile: WARNING: cannot read '$inFile'\n");
        return;
    }
    my $s = $rfh->getline();    # skip header
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $start_coord, $end_coord, $gene_oid, $cog ) = split( /\t/, $s );
        next if $start_coord < $left_flank;
        last if $end_coord > $right_flank;
        my $rec = "$gene_oid\t";
        $rec .= "$scaffold_oid\t";
        $rec .= "$cog";
        push( @$recs_ref, $rec );
    }
    close $rfh;
}

sub printCartNeighborhoods {
    my $href = getSessionParam("neighborhood");

    my @alist;
    my @fslist;
    foreach my $id ( keys %$href ) {
        if ( isInt($id) ) {
            push( @alist, $id );
        } else {
            push( @fslist, $id );
        }
    }
    my $gstr  = join( ",", @alist );
    my $fgstr = join( ",", @fslist );
    if ( $gstr eq "" && $fgstr eq "" ) {
        webError("Please select at least 1 neighborhood.");
    }

    my $cog_color = param("cog_color");

    #  used to get the strand
    my $subj_gene_oid = param("subj_gene_oid");
    my $workspace_id  = $subj_gene_oid;
    my ( $t2, $d2, $g2 ) = split( / /, $workspace_id );
    if ( $d2 eq 'assembled' || $d2 eq 'unassembled' ) {
    } else {
        $d2 = 'database';
    }

    my $dbh = dbLogin();

    printMainForm();
    print "<h1>Gene Ortholog Neighborhoods Cart</h1>\n";
    printStatusLine("Loading ...");

    my $firststrand;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    if ( $d2 eq 'database' && isInt($subj_gene_oid) ) {
        my $sql = qq{
            select  g.strand
            from gene g
            where g.gene_oid = ?
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $subj_gene_oid );
        ($firststrand) = $cur->fetchrow();
        $cur->finish();
    } else {
        my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaf_oid ) =
          MetaUtil::getGeneInfo( $g2, $t2, $d2 );
        $firststrand = $strand;
        $firststrand = "+" if $strand eq "";
    }

    # the panel is always +
    # the subject gene may not be selected
    # but we do orientation by subject gene

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
       select g.gene_oid, g.strand
       from gene g
       where g.gene_oid in ($gstr)
       $rclause
       $imgClause
    };

    my %strand_h;
    my $pstrand;    # panel strand

    if ( $gstr ne "" ) {
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $strand ) = $cur->fetchrow();
            last if !$gene_oid;

            if ( $firststrand eq $strand ) {
                $pstrand = "+";
            } else {
                $pstrand = "-";
            }
            my $rec = "$gene_oid\t$pstrand";
            $strand_h{$gene_oid} = $rec;
        }
        $cur->finish();
    }

    foreach my $id2 (@fslist) {
        my ( $t3, $d3, $g3 ) = split( / /, $id2 );
        my ( $gene_oid2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaf_oid ) =
          MetaUtil::getGeneInfo( $g3, $t3, $d3 );

        if ( $firststrand eq $strand ) {
            $pstrand = "+";
        } else {
            $pstrand = "-";
        }
        my $rec = "$id2\t$pstrand";
        $strand_h{$id2} = $rec;
    }

    my @recs;
    foreach my $id ( keys %$href ) {
        if ( $strand_h{$id} ) {
            push( @recs, $strand_h{$id} );
        }
    }

    print "<p>\n";
    print "Neighborhoods of roughly same sized orthologs " . "in user-selected genomes are shown below.<br/>";
    print "Genes of the same color (except light yellow) ";
    print "are from the same orthologous group (top COG hit).";
    print "</p>\n";

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment"
               . "<br>White = pseudo gene, "
               . "<font color='red'>Red</font> = marker gene" );

    printTrackerDiv( $cog_color, $subj_gene_oid );
    printNeighborhoodPanels( $dbh, "orth", \@recs, 0 );

    #$dbh->disconnect();
    print end_form();
}

sub printNextNeighborhoods {
    my $cog_color = param("cog_color");
    my $file      = param("file");
    my $index     = param("index");

    my $temp = getSessionParam("maxNeighborhoods");
    $maxNeighborhoods = $temp if $temp ne "";

    my $dbh = dbLogin();

    printMainForm();
    print "<h1>Gene Ortholog Neighborhoods</h1>\n";

    printStatusLine("Loading ...");

    my @recs;
    my $path = "$cgi_tmp_dir/$file";
    WebUtil::checkFileName($file);
    WebUtil::fileTouch($path);
    my $res   = newReadFileHandle( $path, "runJob" );
    my $count = 0;

    my $end   = $index * $maxNeighborhoods + 2;
    my $start = ( $index - 1 ) * $maxNeighborhoods + 2;

    while ( my $line = $res->getline() ) {
        chomp $line;
        if ( $count == 0 ) {

            # always add the first gene / ref gene oid
            push( @recs, $line );
        }

        $count++;
        next if ( $count < $start );
        if ( $count >= $end ) {

            # just count the number of lines
            last;
        } else {
            push( @recs, $line );
        }
    }

    close $res;

    print "<p>\n";
    print "Neighborhoods of roughly same sized orthologs " . "in user-selected genomes are shown below.<br/>";
    print "Genes of the same color (except light yellow) ";
    print "are from the same orthologous group (top COG hit).";
    print "</p>\n";

    printHint(   "Mouse over a gene to see details (once page has loaded)."
               . "<br/>Light yellow = no COG assignment, "
               . "White = pseudo gene" );

    printTrackerDiv($cog_color);
    printNeighborhoodPanels( $dbh, "orth", \@recs, 0 );

    #$dbh->disconnect();

    if ( $count >= $end ) {
        if ( $index > 1 ) {

            # print Prev button
            print qq{
            <input class='smbutton'
                   type="button"
                   value="&lt; Prev"
                   onclick="javascript:history.back()">
            };
        }

        $index++;

        # Next button
        my $url =
          "$section_cgi&page=neigFile&index=$index&file=$file" . "&cog_color=$cog_color&show_checkbox=$show_checkbox";
        print qq{
            <input class='smbutton'
                   type="button"
                   value="Next &gt;"
                   onclick="window.open('$url', '_self')">
        };
    }

    print end_form();
}

sub printTrackerDiv {
    my ( $cog_color, $subj_gene_oid ) = @_;
    my $folder = param('directory');

    if ($show_checkbox) {
        print qq{
        <script src="$base_url/cart.js" ></script>
        <script type="text/javascript"
          src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js" ></script>
        <script src="$YUI/build/event/event-min.js" ></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
        };

        require Cart;
        my $size  = Cart::getNeighborhoodSize();
        my $size2 = Cart::getGeneCartSize();

        print qq{
        <script language='JavaScript' type='text/javascript'>
        function showSelectGenes() {
            var checked1 = document.getElementById('geneselect').checked;
            if (checked1 == true) {
              document.getElementById('geneSelectDiv').style.display = 'block';
            } else {
              document.getElementById('geneSelectDiv').style.display = 'none';
            }
        }
        </script>
        };

        print qq{
        <p>
        <input id='genedetails' type='radio' name='mygenedetail'
        onchange='showSelectGenes()' value='gene_details' checked>
        Use mouse-click on a gene in a neighborhood to <u>view the details</u>
        page for that gene
        <br/>
        <input id='geneselect' type='radio' name='mygenedetail'
        onchange='showSelectGenes()' value='gene_oid' >
        Use mouse-click on a gene in a neighborhood to <u>select</u> it
        into a virtual cart
        </p>
        };

        print qq{
        <div id='geneSelectDiv' style='display: none;'>
        <p>
        <input type="button" class="smbutton" value="View selected genes"
        onclick="window.open('main.cgi?section=Cart&page=genelist','_blank')">

        &nbsp;
        <input type="button" class="smbutton" value="Clear selected genes"
        onclick="javascript:clearGene()">
        </p>
        </div>

        <div id='tracker'>
        <p>
        <u>Selected</u>: Neighborhoods = $size &nbsp;&nbsp; Genes = $size2
        </p>
        </div>

        <p>
        <input type="button" class="medbutton"
        value="View selected neighborhoods"
        onclick="window.open('main.cgi?section=GeneNeighborhood&page=neighborhoodCart&show_checkbox=$show_checkbox&cog_color=$cog_color&subj_gene_oid=$subj_gene_oid','_self')" >

        &nbsp;
        <input type="button" class="medbutton"
        value="Clear selected neighborhoods"
        onclick="javascript:clearNeighborhood()" >

        </p>
        };

        print qq{
            <input type="hidden" id="refreshed" value="no">
            <script type="text/javascript">
            onload=function() {
                var e=document.getElementById("refreshed");
                if (e.value=="no") {
                    e.value="yes";
                } else {
                    e.value="no";
                    refreshTracker();
                    e.value="yes"; // need yes since page is not reloading
                }

                showSelectGenes();
            }
            </script>
        };

    } elsif ($show_checkbox_remove) {
        if ($folder) {
            print "<p>\n";
        } else {
            my $name = "_section_GeneCartStor_deleteSelectedCartGenesNeigh";
            print submit(
                          -name  => $name,
                          -value => "Remove Selected",
                          -class => 'smdefbutton'
            );
            print "<p>";
        }
    }
}

1;

