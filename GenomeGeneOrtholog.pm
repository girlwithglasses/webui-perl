#
# $Id: GenomeGeneOrtholog.pm 29917 2014-01-24 21:01:43Z klchu $
#
package GenomeGeneOrtholog;

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use MetagenomeGraph;
use GeneCassette;
use OracleUtil;
use HtmlUtil;
use TaxonTarDir;
use GenomeListJSON;

my $section               = "GenomeGeneOrtholog";
my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $section_cgi           = "$main_cgi?section=$section";
my $tmp_url               = $env->{tmp_url};
my $tmp_dir               = $env->{tmp_dir};
my $verbose               = $env->{verbose};
my $web_data_dir          = $env->{web_data_dir};
my $preferences_url       = "$main_cgi?section=MyIMG&page=preferences";
my $img_lite              = $env->{img_lite};
my $img_internal          = $env->{img_internal};
my $include_cassette_bbh  = $env->{include_cassette_bbh};
my $include_cassette_pfam = $env->{include_cassette_pfam};
my $enable_cassette       = $env->{enable_cassette};
my $public_nologin_site   = $env->{public_nologin_site};
my $user_restricted_site  = $env->{user_restricted_site};
my $include_metagenomes   = $env->{include_metagenomes};
my $bbh_zfiles_dir        = $env->{bbh_zfiles_dir};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $cgi_url              = $env->{cgi_url};

my $max_subject = 50;

sub dispatch {
    my ($numTaxon) = @_;
    my $page = param('page');
    if ( $page eq 'compare' ) {
        timeout( 60 * 20 );
        #printResults();
        printResults3();
    } elsif ( $page eq 'compare3' ) {
        timeout( 60 * 20 );
        printResults3();
    } elsif ( $page eq 'form3' ) {
        timeout( 60 * 20 );
        printForm3($numTaxon);

    } else {
        #printForm();
        printForm3($numTaxon);
    }
}

sub printResults {
    my $percentage = param('percentage');

    print "<h1>Genome Gene Best Homologs</h1>";
    printStatusLine( "Loading ...", 1 );

    my %taxonOids;       # list of all taxon oids
    my @findList;        # list of find   taxon   oids
    my @collList;        # list of taxon ids Collocated in
    my %valid_taxons;    # same as collList
    my $dbh = dbLogin();

    my $urClause = urClause("t.taxon_oid");
    my @binds;
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    if ( $hideViruses eq "Yes" ) {
        $virusClause = "and t.domain not like ?";
        push( @binds, "Vir%" );
    }

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;

    if ( $hidePlasmids eq "Yes" ) {
        $plasmidClause = "and t.domain not like ?";
        push( @binds, "Plasmid%" );
    }

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $gFragmentClause;
    if ( $hideGFragment eq "Yes" ) {
        $gFragmentClause = "and t.domain not like ?";
        push( @binds, "GFragment%" );
    }

    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
       select t.taxon_oid, taxon_display_name
       from taxon t
       where t.obsolete_flag = 'No'
       $urClause
       $imgClause
       $virusClause
       $plasmidClause
       $gFragmentClause       
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    for ( ; ; ) {
        my ( $taxon_oid, $name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonOids{$taxon_oid} = $name;
    }

    #
    # Now find what user had selected on the form
    #
    my @excludedList = ();

    foreach my $toid ( keys %taxonOids ) {
        my $profileVal = param("profile$toid");
        next if $profileVal eq "0" || $profileVal eq "";

        if ( $profileVal eq "find" ) {
            push( @findList, $toid );
        } elsif ( $profileVal eq "coll" ) {
            push( @collList, $toid );
            $valid_taxons{$toid} = $toid;
        } elsif ( $profileVal eq "exclude" ) {
            push( @excludedList, $toid );
        }

        if ( $#findList > 1 ) {

            #$dbh->disconnect();
            printStatusLine( "Loaded.", 2 );
            webError( "Please select only 1 genome " . "in the \"Find Gene In\" column." );
            return;
        }

        if ( $#collList > ( $max_subject - 1 ) ) {

            #$dbh->disconnect();
            printStatusLine( "Loaded.", 2 );
            webError( "Please select only $max_subject genome " . "in the \"Ortholog In\" column." );
            return;
        }
    }

    # check size of arrays
    if ( $#findList > 0 || $#findList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webError( "Please select only 1 genome " . "in the \"Find Gene In\" column." );
        return;
    }

    if ( $#collList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webError( "Please select at least 1 genome " . "in the \"Ortholog In\" column" );
        return;
    }

    my $taxon_oid = $findList[0];
    my $turl      = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    print qq{
        <h3><a href="$turl">
           $taxonOids{$taxon_oid}
        </a></h3>
    };

    print "<p>\n";
    my $turl = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";
    foreach my $oid (@collList) {
        my $x = $turl . $oid;
        print alink( $x, $taxonOids{$oid} );
        print "<br/>\n";
    }
    print "</p>\n";

    printStartWorkingDiv();
    WebUtil::unsetEnvPath();

    # find orthologs
    my @data_genes;
    my @all_genes;    # list of all genes to get names

    my @excludedGenes = ();
    for my $taxon_oid2 (@excludedList) {

        my @otfHits;
        TaxonTarDir::getGenomePairData( $taxon_oid, $taxon_oid2, \@otfHits );
        my $rev = 0;
        if ( @otfHits == 0 ) {
            webLog("Try reversal with $taxon_oid2 vs $taxon_oid\n");
            TaxonTarDir::getGenomePairData( $taxon_oid2, $taxon_oid, \@otfHits );
            $rev = 1;
        }

        for my $s (@otfHits) {
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );

            if ($rev) {
                my $tmp = $qid;
                $qid = $sid;
                $sid = $tmp;
            }

            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

            next if ( $percIdent >= $percentage );

            #print "to excluded:[$qgene_oid][$s]<br>";
            push( @excludedGenes, $qgene_oid );
        }

    }

    for my $taxon_oid2 (@collList) {
        my @otfHits;
        TaxonTarDir::getGenomePairData( $taxon_oid, $taxon_oid2, \@otfHits );

        # Try reversal if no rows found.
        my $rev = 0;
        if ( @otfHits == 0 ) {
            webLog("Try reversal with $taxon_oid2 vs $taxon_oid\n");
            TaxonTarDir::getGenomePairData( $taxon_oid2, $taxon_oid, \@otfHits );
            $rev = 1;
        }

        for my $s (@otfHits) {
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );

            # Swap query and subject if using reverse file.
            if ($rev) {
                my $tmp = $qid;
                $qid = $sid;
                $sid = $tmp;
            }

            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

            # excluding
            my @matches = grep( /$qgene_oid/, @excludedGenes );
            if ( scalar(@matches) ne 0 ) {

                #print "exclude this gene in ref genome: $qgene_oid<br>";
                next;
            }

            # Currently only gene_oids are being returned in
            # $qid and $sid by usearch on the fly.
            # So insert taxon_oids if needed. +BSJ 05/09/12
            if ( !$qtaxon || !$staxon ) {
                $staxon = $taxon_oid2 if ( !$staxon );
                $qtaxon = $taxon_oid  if ( !$qtaxon );

                # Insert taxon oids
                $qid = join( "_", ( $qgene_oid, $qtaxon, $qlen ) );
                $sid = join( "_", ( $sgene_oid, $staxon, $slen ) );

                # Recreate line with taxon oids for use in table below
                $s = join(
                           "\t",
                           (
                             $qid,    $sid,  $percIdent, $alen, $nMisMatch, $nGaps,
                             $qstart, $qend, $sstart,    $send, $evalue,    $bitScore
                           )
                );

            }

            # filtering
            next if $percIdent < $percentage;
            next if ( !$valid_taxons{$staxon} );
            next if $bitScore eq "";               # bad record

            #print "###A### qstart[". $qstart."]-qend[".$qend."]-sstart[".$sstart."]-send[".$send."]<br>";
            #print "original[$s]<br><br>";
            push( @data_genes, $s );
            push( @all_genes,  $qgene_oid );
            push( @all_genes,  $sgene_oid );
            print "$qgene_oid  $qtaxon ===  $sgene_oid, $staxon === $percIdent $alen $nMisMatch $nGaps <br/>\n";
        }
    }

    # no data found
    if ( $#all_genes < 0 ) {
        printEndWorkingDiv();

        #$dbh->disconnect();
        print "<p>No orthologs found at ${percentage}%+.</p>";
        printStatusLine( "0 orthologs loaded.", 2 );
        WebUtil::webExit(0);
    }

    # get gene names
    print "Getting gene names<br/>\n";
    my %gene_names;
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@all_genes );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid, g.gene_display_name, g.locus_tag
        from gene g
        where g.gene_oid in(select id from gtt_num_id)
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $name, $locus_tag ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_names{$gene_oid} = "$locus_tag\t$name";
    }

    printEndWorkingDiv();

    my $it = new InnerTable( 1, "${section}$$", "$section", 0 );
    $it->disableSelectButtons();
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Reference Gene ID",     "number asc", "right" );
    $it->addColSpec( "Reference Gene Name",   "char asc",   "left" );
    $it->addColSpec( "Reference Locus Tag",   "char asc",   "left" );
    $it->addColSpec( "Reference Coordinates", "char asc",   "right" );

    $it->addColSpec( "Query Gene ID",     "number asc", "right" );
    $it->addColSpec( "Query Gene Name",   "char asc",   "left" );
    $it->addColSpec( "Query Locus Tag",   "char asc",   "left" );
    $it->addColSpec( "Query Coordinates", "char asc",   "right" );
    $it->addColSpec( "Query Genome",      "char asc",   "left" );

    $it->addColSpec( "Percent Identity", "number asc", "right" );
    $it->addColSpec( "Bit Score",        "number asc", "right" );
    $it->addColSpec( "E-value",          "number asc", "right" );

    my $count = 0;
    foreach my $r (@data_genes) {
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $r );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

        my $url  = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=";
        my $turl = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

        my $r = $sd . "<input type='checkbox' name='gene_oid' value='$qgene_oid'  />\t";
        my $tmp = alink( $url . $qgene_oid, $qgene_oid );
        $r .= $qgene_oid . $sd . $tmp . "\t";
        my $str = $gene_names{$qgene_oid};
        my ( $locus_tag, $name ) = split( /\t/, $str );
        $r .= $name . $sd . $name . "\t";
        $r .= "$locus_tag" . $sd . "$locus_tag" . "\t";
        $r .= "$qstart, $qend" . $sd . "$qstart, $qend" . "\t";

        my $tmp = alink( $url . $sgene_oid, $sgene_oid );
        $r .= $sgene_oid . $sd . $tmp . "\t";
        my $str = $gene_names{$sgene_oid};
        my ( $locus_tag, $name ) = split( /\t/, $str );
        $r .= $name . $sd . $name . "\t";
        $r .= "$locus_tag" . $sd . "$locus_tag" . "\t";
        $r .= "$sstart, $send" . $sd . "$sstart, $send" . "\t";
        my $tname = $taxonOids{$staxon};
        my $tmp = alink( $turl . $staxon, $tname );
        $r .= $tname . $sd . $tmp . "\t";

        $r .= "$percIdent" . $sd . "$percIdent" . "\t";
        $r .= "$bitScore" . $sd . "$bitScore" . "\t";
        $r .= "$evalue" . $sd . "$evalue" . "\t";

        $it->addRow($r);
        $count++;
    }

    #$dbh->disconnect();
    printMainForm();
    WebUtil::printHint2(
"<p>Reference coordinates and query coordinates refer to the start and end positions of aligned regions in reference and query genes (rather than gene coordinates on chromosomes).</p>"
    );
    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();
    print end_form();
    printStatusLine( "$count orthologs loaded.", 2 );
}

sub printResults3 {
    my $percentage = param('percentage');

    print "<h1>Genome Gene Best Homologs</h1>";
    printStatusLine( "Loading ...", 1 );

    my %taxonOids;    # list of all taxon oids
    my @findList = param('selectedGenome1');    # list of find   taxon   oids
    my @collList = param('selectedGenome2');    # list of taxon ids Collocated in
    my @excludedList = param('selectedGenome3');
    my %valid_taxons;                           # same as collList
    foreach my $id (@collList) {
        $valid_taxons{$id} = $id;
    }

    my $dbh = dbLogin();

    my $urClause = urClause("t.taxon_oid");
    my @binds;
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    if ( $hideViruses eq "Yes" ) {
        $virusClause = "and t.domain not like ?";
        push( @binds, "Vir%" );
    }

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;

    if ( $hidePlasmids eq "Yes" ) {
        $plasmidClause = "and t.domain not like ?";
        push( @binds, "Plasmid%" );
    }

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $gFragmentClause;
    if ( $hideGFragment eq "Yes" ) {
        $gFragmentClause = "and t.domain not like ?";
        push( @binds, "GFragment%" );
    }

    my $imgClause = WebUtil::imgClause('t');
    my $sql       = qq{
       select t.taxon_oid, taxon_display_name
       from taxon t
       where t.obsolete_flag = 'No'
       $urClause
       $imgClause
       $virusClause
       $plasmidClause
       $gFragmentClause       
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    for ( ; ; ) {
        my ( $taxon_oid, $name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonOids{$taxon_oid} = $name;
    }

    if ( $#findList > 1 ) {
        printStatusLine( "Loaded.", 2 );
        webError( "Please select only 1 genome " . "in the \"Find Gene In\" column." );
        return;
    }

    if ( $#collList > ( $max_subject - 1 ) ) {
        printStatusLine( "Loaded.", 2 );
        webError( "Please select only $max_subject genome " . "in the \"Ortholog In\" column." );
        return;
    }

    # check size of arrays
    if ( $#findList > 0 || $#findList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webError( "Please select only 1 genome " . "in the \"Find Gene In\" column." );
        return;
    }

    if ( $#collList < 0 ) {

        #$dbh->disconnect();
        printStatusLine( "Loaded.", 2 );
        webError( "Please select at least 1 genome " . "in the \"Ortholog In\" column" );
        return;
    }

    my $taxon_oid = $findList[0];
    my $turl      = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    print qq{
        <h3><a href="$turl">
           $taxonOids{$taxon_oid}
        </a></h3>
    };

    print "<p>\n";
    my $turl = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";
    foreach my $oid (@collList) {
        my $x = $turl . $oid;
        print alink( $x, $taxonOids{$oid} );
        print "<br/>\n";
    }
    print "</p>\n";

    printStartWorkingDiv();
    WebUtil::unsetEnvPath();

    # find orthologs
    my @data_genes;
    my @all_genes;    # list of all genes to get names

    my @excludedGenes = ();
    for my $taxon_oid2 (@excludedList) {

        my @otfHits;
        TaxonTarDir::getGenomePairData( $taxon_oid, $taxon_oid2, \@otfHits );
        my $rev = 0;
        if ( @otfHits == 0 ) {
            webLog("Try reversal with $taxon_oid2 vs $taxon_oid\n");
            TaxonTarDir::getGenomePairData( $taxon_oid2, $taxon_oid, \@otfHits );
            $rev = 1;
        }

        for my $s (@otfHits) {
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );

            if ($rev) {
                my $tmp = $qid;
                $qid = $sid;
                $sid = $tmp;
            }

            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

            next if ( $percIdent >= $percentage );

            #print "to excluded:[$qgene_oid][$s]<br>";
            push( @excludedGenes, $qgene_oid );
        }

    }

    for my $taxon_oid2 (@collList) {
        my @otfHits;
        TaxonTarDir::getGenomePairData( $taxon_oid, $taxon_oid2, \@otfHits );

        # Try reversal if no rows found.
        my $rev = 0;
        if ( @otfHits == 0 ) {
            webLog("Try reversal with $taxon_oid2 vs $taxon_oid\n");
            TaxonTarDir::getGenomePairData( $taxon_oid2, $taxon_oid, \@otfHits );
            $rev = 1;
        }

        for my $s (@otfHits) {
            my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
              split( /\t/, $s );

            # Swap query and subject if using reverse file.
            if ($rev) {
                my $tmp = $qid;
                $qid = $sid;
                $sid = $tmp;
            }

            my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
            my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

            # excluding
            my @matches = grep( /$qgene_oid/, @excludedGenes );
            if ( scalar(@matches) ne 0 ) {

                #print "exclude this gene in ref genome: $qgene_oid<br>";
                next;
            }

            # Currently only gene_oids are being returned in
            # $qid and $sid by usearch on the fly.
            # So insert taxon_oids if needed. +BSJ 05/09/12
            if ( !$qtaxon || !$staxon ) {
                $staxon = $taxon_oid2 if ( !$staxon );
                $qtaxon = $taxon_oid  if ( !$qtaxon );

                # Insert taxon oids
                $qid = join( "_", ( $qgene_oid, $qtaxon, $qlen ) );
                $sid = join( "_", ( $sgene_oid, $staxon, $slen ) );

                # Recreate line with taxon oids for use in table below
                $s = join(
                           "\t",
                           (
                             $qid,    $sid,  $percIdent, $alen, $nMisMatch, $nGaps,
                             $qstart, $qend, $sstart,    $send, $evalue,    $bitScore
                           )
                );

            }

            # filtering
            next if $percIdent < $percentage;
            next if ( !$valid_taxons{$staxon} );
            next if $bitScore eq "";               # bad record

            #print "###A### qstart[". $qstart."]-qend[".$qend."]-sstart[".$sstart."]-send[".$send."]<br>";
            #print "original[$s]<br><br>";
            push( @data_genes, $s );
            push( @all_genes,  $qgene_oid );
            push( @all_genes,  $sgene_oid );
            print "$qgene_oid  $qtaxon ===  $sgene_oid, $staxon === $percIdent $alen $nMisMatch $nGaps <br/>\n";
        }
    }

    # no data found
    if ( $#all_genes < 0 ) {
        printEndWorkingDiv();

        #$dbh->disconnect();
        print "<p>No orthologs found at ${percentage}%+.</p>";
        printStatusLine( "0 orthologs loaded.", 2 );
        WebUtil::webExit(0);
    }

    # get gene names
    print "Getting gene names<br/>\n";
    my %gene_names;
    OracleUtil::insertDataArray( $dbh, "gtt_num_id", \@all_genes );

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.gene_oid, g.gene_display_name, g.locus_tag
        from gene g
        where g.gene_oid in(select id from gtt_num_id)
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $name, $locus_tag ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_names{$gene_oid} = "$locus_tag\t$name";
    }

    printEndWorkingDiv();

    my $it = new InnerTable( 1, "${section}$$", "$section", 0 );
    $it->disableSelectButtons();
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Reference Gene ID",     "number asc", "right" );
    $it->addColSpec( "Reference Gene Name",   "char asc",   "left" );
    $it->addColSpec( "Reference Locus Tag",   "char asc",   "left" );
    $it->addColSpec( "Reference Coordinates", "char asc",   "right" );

    $it->addColSpec( "Query Gene ID",     "number asc", "right" );
    $it->addColSpec( "Query Gene Name",   "char asc",   "left" );
    $it->addColSpec( "Query Locus Tag",   "char asc",   "left" );
    $it->addColSpec( "Query Coordinates", "char asc",   "right" );
    $it->addColSpec( "Query Genome",      "char asc",   "left" );

    $it->addColSpec( "Percent Identity", "number asc", "right" );
    $it->addColSpec( "Bit Score",        "number asc", "right" );
    $it->addColSpec( "E-value",          "number asc", "right" );

    my $count = 0;
    foreach my $r (@data_genes) {
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $r );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );

        my $url  = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=";
        my $turl = "main.cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

        my $r = $sd . "<input type='checkbox' name='gene_oid' value='$qgene_oid'  />\t";
        my $tmp = alink( $url . $qgene_oid, $qgene_oid );
        $r .= $qgene_oid . $sd . $tmp . "\t";
        my $str = $gene_names{$qgene_oid};
        my ( $locus_tag, $name ) = split( /\t/, $str );
        $r .= $name . $sd . $name . "\t";
        $r .= "$locus_tag" . $sd . "$locus_tag" . "\t";
        $r .= "$qstart, $qend" . $sd . "$qstart, $qend" . "\t";

        my $tmp = alink( $url . $sgene_oid, $sgene_oid );
        $r .= $sgene_oid . $sd . $tmp . "\t";
        my $str = $gene_names{$sgene_oid};
        my ( $locus_tag, $name ) = split( /\t/, $str );
        $r .= $name . $sd . $name . "\t";
        $r .= "$locus_tag" . $sd . "$locus_tag" . "\t";
        $r .= "$sstart, $send" . $sd . "$sstart, $send" . "\t";
        my $tname = $taxonOids{$staxon};
        my $tmp = alink( $turl . $staxon, $tname );
        $r .= $tname . $sd . $tmp . "\t";

        $r .= "$percIdent" . $sd . "$percIdent" . "\t";
        $r .= "$bitScore" . $sd . "$bitScore" . "\t";
        $r .= "$evalue" . $sd . "$evalue" . "\t";

        $it->addRow($r);
        $count++;
    }

    #$dbh->disconnect();
    printMainForm();
    WebUtil::printHint2(
"<p>Reference coordinates and query coordinates refer to the start and end positions of aligned regions in reference and query genes (rather than gene coordinates on chromosomes).</p>"
    );
    printGeneCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printGeneCartFooter();
    print end_form();
    printStatusLine( "$count orthologs loaded.", 2 );
}



#
#
#
sub printForm {

    my $description =
"<p>Find corresponding genes between a reference and a set of query genomes.<br/>Please select only <b>ONE</b> Reference Genome and up to <b>$max_subject</b> Query Genomes.</p>";

    my $description_m =
      $description
      . "<p>For Metagenomes, please use either <a href=main.cgi?section=MetagPhyloDist&page=form>Metagenome Phylogenetic Distribution</a> or <a href=main.cgi?section=GenomeHits>Genome vs Metagenomes</a>.<br/>These tools can be found under Compare Genomes-><a href=main.cgi?section=MetagPhyloDist&page=top>Phylogenetic Distribution</a></p>";

    if ($include_metagenomes) {
        WebUtil::printHeaderWithInfo( "Genome Gene Best Homologs",
                                      $description_m, "show description for this tool",
                                      "GGBH Info", 1 );
    } else {
        WebUtil::printHeaderWithInfo( "Genome Gene Best Homologs",
                                      $description, "show description for this tool",
                                      "GGBH Info" );
    }

    # Redundant with WebUtil::printHeaderWith Info
    #if ($include_metagenomes) {
    #    print $description_m;
    #} else {
    #    print $description;
    #}

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    my $dbh         = dbLogin();
    my @binds       = ();
    my $taxonClause = txsClause( "tx1", $dbh );
    my ( $rclause, @bindList_ur ) = urClauseBind("tx1");
    if ( scalar(@bindList_ur) > 0 ) {
        push( @binds, @bindList_ur );
    }

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause;
    if ( $hideViruses eq "Yes" ) {
        $virusClause = "and tx1.domain not like ?";
        push( @binds, "Vir%" );
    }

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    my $plasmidClause;

    if ( $hidePlasmids eq "Yes" ) {
        $plasmidClause = "and tx1.domain not like ?";
        push( @binds, "Plasmid%" );
    }

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    my $gFragmentClause;
    if ( $hideGFragment eq "Yes" ) {
        $gFragmentClause = "and tx1.domain not like ?";
        push( @binds, "GFragment%" );
    }

    # find only taxon with cassettes
    # faster than doing join

    my $imgClause = WebUtil::imgClause('tx1');
    my $sql       = qq{
       select  tx1.domain, tx1.phylum, tx1.ir_class, tx1.ir_order, tx1.family, 
          tx1.genus, tx1.species, tx1.strain, 
          tx1.taxon_display_name, tx1.taxon_oid, tx1.seq_status
       from taxon tx1
       where tx1.obsolete_flag = 'No'
       and genome_type = 'isolate'
       $taxonClause
       $rclause
       $imgClause
       $virusClause
       $plasmidClause
       $gFragmentClause
       order by tx1.domain, tx1.phylum, tx1.ir_class, tx1.ir_order, tx1.family, 
          tx1.genus, tx1.species, tx1.strain, tx1.taxon_display_name
    };

    my $cur = execSqlBind( $dbh, $sql, \@binds, $verbose );

    # where the query data is stored
    my @recs;
    my $old_domain;
    my $old_phylum;
    my $old_genus;
    my $old_taxon_oid;

    # run query and store the data in @recs
    # for each rec, the values are tab delimited
    # also add '__lineRange__' used to for the UI display and
    # javascript event actions
    #
    for ( ; ; ) {
        my (
             $domain,  $phylum, $ir_class,           $ir_order,  $family, $genus,
             $species, $strain, $taxon_display_name, $taxon_oid, $seq_status
          )
          = $cur->fetchrow();
        last if !$domain;
        next if $domain =~ /Microbiome/i;    # hide Microbiomes
        if ( $old_domain ne $domain ) {
            my $rec = "domain\t";
            $rec .= "$domain\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            push( @recs, $rec );
        }
        if ( $old_phylum ne $phylum ) {
            my $rec = "phylum\t";
            $rec .= "$phylum\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum";
            push( @recs, $rec );
        }
        if ( $old_genus ne $genus ) {
            my $rec = "genus\t";
            $rec .= "$genus\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus";
            push( @recs, $rec );
        }
        if ( $old_taxon_oid ne $taxon_oid ) {
            my $rec = "taxon_display_name\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus\t";
            $rec .= "$taxon_oid\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "$seq_status\t";
            push( @recs, $rec );
        }
        $old_domain    = $domain;
        $old_phylum    = $phylum;
        $old_genus     = $genus;
        $old_taxon_oid = $taxon_oid;
    }

    $cur->finish();

    # fill in the javascript event actions func calls
    my @recs2 = fillLineRange( \@recs );

    print qq{
<p>

    Percent Identity &nbsp; <select name="percentage">
    <option value="20"> 20+ </option>
    <option value="30"> 30+ </option>
    <option value="40"> 40+ </option>
    <option value="50"> 50+ </option>
    <option value="60" selected="selected"> 60+ </option>
    <option value="70"> 70+ </option>
    <option value="80"> 80+ </option>
    <option value="90"> 90+ </option>
    </select>
    </p>
    };

    # TODO
    #print qq{
    #
    #    <input type='checkbox' name='onlybesthit' value='besthit'/>
    #    &nbsp; Show only the top best hit to query genome genes.
    #};

    # TODO javascript ???
    printJavaScript2();

    # table column headers
    print "<table class='img' border='1'>\n";
    print "<th class='img'>Reference <br/> Genome*</th>\n";
    print "<th class='img'>Query <br/> Genomes</th>\n";
    print "<th class='img'>Excluded <br/> Genomes</th>\n";
    print "<th class='img'>Ignoring</th>\n";
    print "<th class='img'></th>\n";
    my $count     = 0;
    my $taxon_cnt = 0;
    for my $r (@recs2) {
        $count++;
        my ( $type, $type_value, $lineRange, $domain, undef ) =
          split( /\t/, $r );
        if ( $type eq "domain" || $type eq "phylum" || $type eq "genus" ) {
            my ( $line1, $line2 ) = split( /:/, $lineRange );

            print "<tr class='highlight'>\n";

            my $func1 = "selectGroupProfile($line1,$line2,0,'find')";
            my $func2 = "selectGroupProfile($line1,$line2,1,'collocated')";
            my $func3 = "selectGroupProfile($line1,$line2,2,'exlude')";
            my $func4 = "selectGroupProfile($line1,$line2,3,'ignore')";
            print qq{
                <td class='img' >
                  <input type='hidden' onClick="$func1" 
                      name='groupProfile.$count' value='find' 
                  />&nbsp;
                </td>\n

                <td class='img' >
                  <input type='radio' onClick="$func2" 
                      name='groupProfile.$count' value='coll'
                  />&nbsp;
                </td>\n

                <td class='img' >
                  <input type='radio' onClick="$func3"  
                      name='groupProfile.$count' value='exclude'
                  />&nbsp;
                </td>\n

                <td class='img' >
                  <input type='radio' onClick="$func4"  
                      name='groupProfile.$count' value='ignore'
                  />&nbsp;
                </td>\n

            };

            my $sp;
            $sp = nbsp(2) if $type eq "phylum";
            $sp = nbsp(4) if $type eq "genus";

            print "<td class='img' >\n";
            print $sp;
            my $incr = '+0';
            $incr = "+1" if $type eq "domain";
            $incr = "+1" if $type eq "phylum";
            print "<font size='$incr'>\n";
            print "<b>\n";
            print escHtml($type_value);
            print "</b>\n";
            print "</font>\n";
            print "</td>\n";

            print "</tr>\n";

        } elsif ( $type eq "taxon_display_name" && $domain ne '*Microbiome' ) {
            my ( $type, $type_value, $lineRange, $domain, $phylum, $genus, $taxon_oid, $taxon_display_name, $seq_status ) =
              split( /\t/, $r );
            $seq_status = substr( $seq_status, 0, 1 );

            print qq{
              <tr class='img' >\n
                <td class='img' >
                  <input type='radio' 
                    onClick="checkFindCount(mainForm.elements['profile$taxon_oid'])"
                    name='profile$taxon_oid' 
                    value='find'
                  />
                </td>\n

                <td class='img' >
                  <input type='radio' 
                    onClick="checkCollCount(mainForm.elements['profile$taxon_oid'])"
                    name='profile$taxon_oid' 
                    value='coll'
                  />
                </td>\n

                <td class='img' >
                  <input type='radio' 
                    onClick="checkCollCount(mainForm.elements['profile$taxon_oid'])"
                    name='profile$taxon_oid' 
                    value='exclude'
                  />
                </td>\n

                <td class='img' >
                  <input type='radio' name='profile$taxon_oid' value='0' checked />
                </td>\n

                <td class='img' >
            };

            print nbsp(6);
            my $c;
            $c = "[$seq_status]" if $seq_status ne "";
            my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail" . "&taxon_oid=$taxon_oid";
            if ($img_internal) {
                print alink( $url, "$taxon_display_name ($taxon_oid)" );
            } else {
                print alink( $url, "$taxon_display_name" );
            }
            print nbsp(1) . $c;
            print "</td>\n";
            print "</tr>\n";
            $taxon_cnt++;
        }
    }
    print "</table>\n";

    # tell main.pl where to go on submit
    print hiddenVar( "section", $section );
    print hiddenVar( "page",    "compare" );

    print submit( -class => 'smdefbutton', -name => 'submit', -value => 'Go' );
    print nbsp(1);
    print reset( -class => 'smbutton' );

    #$dbh->disconnect();
    printStatusLine( "$taxon_cnt Loaded.", 2 );
    print end_form();

}

sub printForm3 {
    my ($numTaxon) = @_;
    my $description =
"<p>Find corresponding genes between a reference and a set of query genomes.<br/>Please select only <b>ONE</b> Reference Genome and up to <b>$max_subject</b> Query Genomes.</p>";

    my $description_m =
      $description
      . "<p>For Metagenomes, please use either <a href=main.cgi?section=MetagPhyloDist&page=form>Metagenome Phylogenetic Distribution</a> or <a href=main.cgi?section=GenomeHits>Genome vs Metagenomes</a>.<br/>These tools can be found under Compare Genomes-><a href=main.cgi?section=MetagPhyloDist&page=top>Phylogenetic Distribution</a></p>";

    if ($include_metagenomes) {
        WebUtil::printHeaderWithInfo( "Genome Gene Best Homologs",
                                      $description_m, "show description for this tool",
                                      "GGBH Info", 1 );
    } else {
        WebUtil::printHeaderWithInfo( "Genome Gene Best Homologs",
                                      $description, "show description for this tool",
                                      "GGBH Info" );
    }

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    my $dbh = dbLogin();

    print qq{
<p>

    Percent Identity &nbsp; <select name="percentage">
    <option value="20"> 20+ </option>
    <option value="30"> 30+ </option>
    <option value="40"> 40+ </option>
    <option value="50"> 50+ </option>
    <option value="60" selected="selected"> 60+ </option>
    <option value="70"> 70+ </option>
    <option value="80"> 80+ </option>
    <option value="90"> 90+ </option>
    </select>
    </p>
    };

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new( filename => "$base_dir/genomeJsonThreeDiv.html" );
    $template->param( isolate              => 1 );
    $template->param( include_metagenomes  => 0 );
    $template->param( gfr                  => 1 ) if ( $hideGFragment eq 'No' );
    $template->param( pla                  => 1 ) if ( $hidePlasmids eq 'No' );
    $template->param( vir                  => 1 ) if ( $hideViruses eq 'No' );
    $template->param( all                  => 1 );
    $template->param( cart                 => 1 );
    $template->param( xml_cgi              => $xml_cgi );
    $template->param( prefix               => '' );
    $template->param( selectedGenome1Title => 'Reference Genome' );
    $template->param( selectedGenome2Title => 'Query Genomes (50 max)' );
    $template->param( selectedGenome3Title => 'Excluded Genomes' );
    $template->param( from                 => '' );
    $template->param( maxSelected2         => 50 );
    $template->param( maxSelected3         => -1 );

    GenomeListJSON::printHiddenInputType( $section, 'compare3' );
    my $s = GenomeListJSON::printMySubmitButtonXDiv( '', 'Submit', 'Submit', '', $section, 'compare3' );
    $template->param( mySubmitButton => $s );
    print $template->output;

    GenomeListJSON::showGenomeCart($numTaxon);
    printStatusLine( "Loaded.", 2 );
    print end_form();

}

# form page helper
#
# calculate the radio button information
#
sub fillLineRange {
    my ($recs_ref) = @_;
    my @recs2;
    my $nRecs = @$recs_ref;
    for ( my $i = 0 ; $i < $nRecs ; $i++ ) {
        my $r = $recs_ref->[$i];
        my ( $type, $type_val, $lineRange, $domain, $phylum, $genus, $taxon_oid, $taxon_display_name ) = split( /\t/, $r );
        if ( $type eq "domain" || $type eq "phylum" || $type eq "genus" ) {
            my $j = $i + 1;
            for ( ; $j < $nRecs ; $j++ ) {
                my $r2 = $recs_ref->[$j];
                my ( $type2, $type_val2, $lineRange2, $domain, $phylum, $genus, $taxon_oid, $taxon_display_name ) =
                  split( /\t/, $r2 );
                last if ( $domain ne $type_val ) && $type eq "domain";
                last if ( $phylum ne $type_val ) && $type eq "phylum";
                last if ( $genus  ne $type_val ) && $type eq "genus";
            }
            $r =~ s/__lineRange__/$i:$j/;
        }
        if ( $type eq "taxon_display_name" && $domain eq "*Microbiome" ) {
            my $j = $i + 1;
            for ( ; $j < $nRecs ; $j++ ) {
                my $r2 = $recs_ref->[$j];
                my ( $type2, $type_val2, $lineRange2, $domain2, $phylum2, $genus2, $taxon_oid2, $taxon_display_name2 ) =
                  split( /\t/, $r2 );
                last if ( $taxon_oid ne $taxon_oid2 );
            }
            $r =~ s/__lineRange__/$i:$j/;
        }
        push( @recs2, $r );
    }
    return @recs2;
}

#
# prints form page javascript
#
sub printJavaScript2 {
    print <<EOF;
    
    <script language='JavaScript' type='text/javascript'>

// document element start location of Find radio button
var findButton = 1;
// document element start location of Collocated radio button
var collButton = 2;

// max number a user can select
var maxFind = 1;
var maxColl = $max_subject;
EOF

    print qq{
// number of radio button cols
var numOfCols = 4;
        };

    print <<EOF;
/*
 * When user selects a radio button highlight in blue, 'a parent taxon' not a
 * child / leaf taxon param begin item number offest by findButton param end last
 * radio button param offset which column param type which column type
 */
function selectGroupProfile(begin, end, offset, type) {
    var f = document.mainForm;
    var count = 0;
    var idx1 = begin * numOfCols;
    var idx2 = end * numOfCols;
    for ( var i = idx1; i < f.length && i < idx2; i++) {
        var e = f.elements[i + findButton];
        if (e.type == "radio" && i % numOfCols == offset) {
            e.checked = true;
        }
    }

    /*
     * now count the number of leafs selected max is 10
     */
    if (type == 'find' && !checkFindCount(null)) {
        selectGroupProfile(begin, end, (numOfCols - 1), 'ignore');
    } else if (type == 'collocated' && !checkCollCount(null)) {
        selectGroupProfile(begin, end, (numOfCols - 1), 'ignore');
    }  
}

/*
 */
function checkFindCount(obj) {
    var f = document.mainForm;
    var count = 0;

    // I KNOW where the objects are located in the form
    for ( var i = findButton; i < f.length; i = i + numOfCols) {
        var e = f.elements[i];
        var name = e.name;
        if (e.type == "radio" && e.checked == true
                && name.indexOf("profile") > -1) {
            // alert("radio button is checked " + name);
            count++;
            if (count > maxFind) {
                alert("Please select only " + maxFind + " genome");
                if (obj != null) {
                    // i know which taxon leaf to un-check
                    obj[0].checked = false;
                    obj[numOfCols - 1].checked = true;
                }
                return false;
            }
        }
    }
    return true;
}

/*
 * 
 */
function checkCollCount(obj) {
    var f = document.mainForm;
    var count = 0;

    // I KNOW where the objects are located in the form
    for ( var i = collButton; i < f.length; i = i + numOfCols) {
        var e = f.elements[i];
        var name = e.name;
        if (e.type == "radio" && e.checked == true
                && name.indexOf("profile") > -1) {
            // alert("radio button is checked " + name);
            count++;
            if (count > maxColl) {
                alert("Please select " + maxColl + " or less genomes");
                if (obj != null) {
                    obj[1].checked = false;
                    obj[numOfCols - 1].checked = true;
                }
                return false;
            }
        }
    }
    return true;
}

    
    </script>
    
EOF

}

1;
