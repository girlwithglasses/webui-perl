############################################################################
# PhyloDist.pm - Phylogenetic distribution display.
#   This shows a list of genomes, in fixed width font,
#   in indented outline format,
#   colored red if there's a hit (or occurrence in the genome).
#    --es 02/06/2005
#
# $Id: PhyloDist.pm 30360 2014-03-08 00:12:52Z jinghuahuang $
############################################################################
package PhyloDist;
my $section = "PhyloDist";

use strict;
use CGI qw( :standard );
use DBI;
use PhyloNode;
use PhyloTreeMgr;
use WebConfig;
use WebUtil;

my $env              = getEnv();
my $main_cgi         = $env->{main_cgi};
my $section_cgi      = "$main_cgi?section=$section";
my $verbose          = $env->{verbose};
my $tmp_dir          = $env->{tmp_dir};
my $cgi_tmp_dir      = $env->{cgi_tmp_dir};
my $preferences_url  = "$main_cgi?section=MyIMG&page=preferences";
my $show_private     = $env->{show_private};
my $img_internal     = $env->{img_internal};
my $bbh_files_dir    = $env->{bbh_files_dir};
my $bbh_zfiles_dir   = $env->{bbh_zfiles_dir};
my $include_bbh_lite = $env->{include_bbh_lite};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( paramMatch("phyloOccurProfiles") ne "" ) {
        printPhyloOccurProfileResults();
    } elsif ( paramMatch("phyloDist") ne "" ) {
        printPhyloDistCounted();
    } else {
        webLog("PhyloDist::dispatch: no param match\n");
        warn("PhyloDist::dispatch: no param match\n");
    }
}

############################################################################
# printPhyloDistCounted - Show taxon list as a phylogenetic tree with
#   counts > 0 highlighted.
############################################################################
sub printPhyloDistCounted {
    my @taxon_hit = param("taxon_hit");
    my %taxonHilite;
    for my $taxon_oid (@taxon_hit) {
        $taxonHilite{$taxon_oid} = $taxon_oid;
    }
    my $xlogSource = param("xlogSource");
    my $gene_oid   = param("genePageGeneOid");

    if ( blankStr($gene_oid) ) {
        webDie("printPhyloDistCounted: null gene_oid\n");
        return;
    }

    my $minHomologPercentIdentity =
      getSessionParam("minHomologPercentIdentity");
    my $minHomologAlignPercent = getSessionParam("minHomologAlignPercent");
    $minHomologPercentIdentity = 5 if $minHomologPercentIdentity eq "";
    $minHomologAlignPercent    = 5 if $minHomologAlignPercent    eq "";

    printStatusLine( "Loading ...", 1 );

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree();

    my $dbh = dbLogin();
    my @taxon_oids;

    my $taxon_oid = getTaxonOid4GeneOid( $dbh, $gene_oid );
    $mgr->incrCount($taxon_oid);
    push( @taxon_oids, $taxon_oid );

    if ( $xlogSource eq "homologs" ) {
        my @homologRecs;

        #getFileHomologs( $dbh, $gene_oid, \@homologRecs );
        getIdxHomologs( $dbh, $gene_oid, \@homologRecs );
        for my $r (@homologRecs) {
            my (
                 $gene_oid,         $homolog,     $taxon,
                 $percent_identity, $query_start, $query_end,
                 $subj_start,       $subj_end,    $evalue,
                 $bit_score,        $align_length
              )
              = split( /\t/, $r );
            next if $percent_identity < $minHomologPercentIdentity;
            $mgr->incrCount($taxon);
            push( @taxon_oids, $taxon );
        }
    } elsif ( $xlogSource eq "fusionComponents" ) {
        my $sql = qq{
             select distinct gfc.taxon
             from gene_all_fusion_components gfc
             where gfc.gene_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ($taxon) = $cur->fetchrow();
            last if !$taxon;
            $mgr->incrCount($taxon);
            push( @taxon_oids, $taxon );
        }
        $cur->finish();
    } elsif ( $xlogSource eq "fusionRelated" ) {
        my $rclause   = WebUtil::urClause('tx1');
        my $imgClause = WebUtil::imgClause('tx1');
        my $sql = qq{
             select tx1.taxon_oid
             from gene_all_fusion_components gfc, gene g1, taxon tx1
             where gfc.gene_oid = g1.gene_oid
                 $rclause
                 $imgClause
                 and g1.taxon = tx1.taxon_oid
                 and gfc.component = ?
       };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ($taxon) = $cur->fetchrow();
            last if !$taxon;
            $mgr->incrCount($taxon);
            push( @taxon_oids, $taxon );
        }
        $cur->finish();
    } elsif ( $xlogSource eq "otfBlast" ) {
        my $gene_oid = param("genePageGeneOid");
        my $inFile   = "$cgi_tmp_dir/otfTaxonsHit.$gene_oid.txt";
        if ( !( -e $inFile ) ) {
            webError("Session expired.  Please refresh gene page.");
        }
        my $rfh = newReadFileHandle( $inFile, "printPhyloDistCounted" );
        while ( my $s = $rfh->getline() ) {
            chomp $s;
            $mgr->incrCount($s);
            push( @taxon_oids, $s );
        }
        close $rfh;
    } else {
        my $sql = qq{
          select go.taxon
 	  from gene_orthologs go
	  where go.gene_oid = ?
       };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ($taxon) = $cur->fetchrow();
            last if !$taxon;
            $mgr->incrCount($taxon);
            push( @taxon_oids, $taxon );
        }
        $cur->finish();
    }
    #$dbh->disconnect();

    if ($show_private) {
        require TreeQ;
        TreeQ::printAppletForm( \@taxon_oids );
    }

    my $xlogSource = param("xlogSource");
    my $redstr = "<font color='red'>red</font>";
    if ( $xlogSource eq "orthologs" ) {
	print "<h1>Phylogenetic Distribution of Orthologs</h1>";
        print "<p>The distribution of orthologs (bidirectional best hits) "
	    . "is shown in $redstr.<br/>\n";
    } elsif ( $xlogSource eq "otfBlast" ) {
	print "<h1>Phylogenetic Distribution of Top Hit Homologs</h1>";
        print "<p>The distribution of top hit homologs is shown in $redstr.<br/>\n";
    } elsif ( $xlogSource eq "fusionComponents" ) {
	print "<h1>Phylogenetic Distribution of Fusion Components</h1>";
        print "<p>The distribution of fusion components is shown in $redstr.<br/>\n";
    } elsif ( $xlogSource eq "fusionRelated" ) {
	print "<h1>Phylogenetic Distribution of Related Fusion Genes</h1>";
        print "<p>The distribution created of related fusion genes "
	    . "is shown in $redstr.<br/>\n";
    } else {
	print "<h1>Phylogenetic Distribution of Homologs</h1>";
        print "<p>The distribution of homologs (unidirectional hits) "
	    . "is shown in $redstr.<br/>\n";
    }

    print "<br/>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    $mgr->aggCount();
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";

    #print end_form( );
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# phyloArray - Generate phylo array based on phylogentic level.
############################################################################
sub phyloArray {
    my ( $dbh, $level ) = @_;
    my @recs;
    my $taxonClause = txsClause("", $dbh);
    #my $rclause     = urClause("taxon_oid");
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql         = qq{
      select distinct t.domain, t.phylum, 
          t.ir_class, t.ir_order, t.family, 
          t.taxon_display_name, t.taxon_oid
      from taxon t
      where 1 = 1
          and t.domain not like 'Vir%'
          and t.domain not like 'Plasmid%'
          and t.domain not like 'GFragment%'
          and t.genome_type != 'metagenome'
          $taxonClause
          $rclause
          $imgClause
      order by t.domain, t.phylum, t.ir_class, t.ir_order, 
          t.family, t.taxon_display_name, t.taxon_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family,
             $taxon_display_name, $taxon_oid )
          = $cur->fetchrow();
        last if !$taxon_oid;
        if ( $domain eq "" ) {
            $domain = "?";
            webLog "phyloArray: null domain for taxon_oid='$taxon_oid'\n"
              if $verbose >= 1;
        }
        my $d = substr( $domain, 0, 1 );
        my $r = "$d\t";
        $r .= "$phylum\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name";
        push( @recs, $r );
    }
    return @recs;
}

############################################################################
# orthologArrayPositions - Return array position records based on orthologs
#   of a gene.
############################################################################
sub orthologArrayPositions {
    my ( $dbh, $phyloRecs_ref, $gene_oid ) = @_;
    my %taxon_oids;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
      select g.taxon
      from gene g
      where g.gene_oid =  $gene_oid
          $rclause
          $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my ($taxon) = $cur->fetchrow();
    $taxon_oids{$taxon} = $taxon if $taxon ne "";
    $cur->finish();
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
      select go.taxon
      from gene_orthologs go, taxon tx
      where go.gene_oid = ?
          $rclause
          $imgClause
          and go.taxon = tx.taxon_oid
          and tx.domain not like 'Vir%'
          and tx.domain not like 'Plasmid%'
          and tx.domain not like 'GFragment%'
          and tx.genome_type != 'metagenome'
   };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );

    for ( ; ; ) {
        my ($taxon) = $cur->fetchrow();
        last if !$taxon;
        $taxon_oids{$taxon} = $taxon;
    }
    $cur->finish();
    my @recs;
    for my $pr (@$phyloRecs_ref) {
        my ( $domainLetter, $phylum, $taxon_oid, $taxon_display_name ) =
          split( /\t/, $pr );
        if ( $taxon_oids{$taxon_oid} ne "" ) {
            push( @recs, "$pr\t1" );
        } else {
            push( @recs, "$pr\t0" );
        }
    }
    return @recs;
}
############################################################################
# orthologArrayPositionsBBHLite - BBH lite version.
############################################################################
sub orthologArrayPositionsBBHLite {
    my ( $dbh, $phyloRecs_ref, $gene_oid ) = @_;

    my @recs = getBBHLiteRows($gene_oid);
    my %taxon_oids;

    for my $r (@recs) {
        my (
             $qid,       $sid,   $percIdent, $alen,
             $nMisMatch, $nGaps, $qstart,    $qend,
             $sstart,    $send,  $evalue,    $bitScore
          )
          = split( /\t/, $r );
        my ( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my ( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        $taxon_oids{$staxon} = 1;
    }
    my @recs;
    for my $pr (@$phyloRecs_ref) {
        my ( $domainLetter, $phylum, $taxon_oid, $taxon_display_name ) =
          split( /\t/, $pr );
        if ( $taxon_oids{$taxon_oid} ne "" ) {
            push( @recs, "$pr\t1" );
        } else {
            push( @recs, "$pr\t0" );
        }
    }
    return @recs;
}

############################################################################
# printPhyloOccurResults - Phylogenetic occurrence profile results.
############################################################################
sub printPhyloOccurProfileResults {
    my @gene_oids = param("gene_oid");

    my $nGenes = @gene_oids;
    printMainForm();
    print "<h1>Phylogenetic Occurrence Profile</h1>\n";
    if ( $nGenes < 1 ) {
        webError("You must select at least one gene.\n");
    }
    checkPhyloOccurGenes();
    print "<p>\n";
    print "Phylogenetic occurrence profile for selected genomes.\n";
    print nbsp(1);
    print "(Viruses, GFragment and orphan plasmids are not included.)<br/>\n";
    print "</p>\n";
    printHint("Mouse over domain letter to see genome name.");
    print "<p>\n";
    print domainLetterNoteNoVNoM() . "<br/>\n";
    print "(Profiles based on bidirectional best hit orthologs.<br/>\n";
    print nbsp(1);
    print " A dot '.' means there is no bidirectional best hit\n";
    print "for the genome.)<br/>\n";
    print "</p>\n";
    printStatusLine( "Loading ...", 1 );
    my $dbh        = dbLogin();
    my @phyloRecs  = phyloArray( $dbh, "species" );
    my $nPhyloRecs = @phyloRecs;
    my @arrays;

    for my $gene_oid (@gene_oids) {
        my @arr;
        if ( $include_bbh_lite && $bbh_zfiles_dir ne "" ) {
            @arr =
              orthologArrayPositionsBBHLite( $dbh, \@phyloRecs, $gene_oid );
        } else {
            @arr = orthologArrayPositions( $dbh, \@phyloRecs, $gene_oid );
        }
        push( @arrays, \@arr );
    }

    #print "<div id='mouseoveronly'>\n";
    print "<font color='blue'>\n";
    print "<pre>\n";
    my $i    = 0;
    my $incr = 70;
    for ( ; $i < $nPhyloRecs ; $i += $incr ) {
        printPhyloPanel( \@gene_oids, \@arrays, $i, $incr );
        print "\n";
    }
    print "</pre>\n";
    print "</font>\n";

    #print "</div>\n";
    printGeneLegend( $dbh, \@gene_oids );
    printStatusLine( "Loaded", 2 );
    #$dbh->disconnect();
    print toolTipCode();
    print end_form();
}

############################################################################
# checkPhyloOccurGenes - Check for protein coding genes.
############################################################################
sub checkPhyloOccurGenes {
    my @gene_oids = param("gene_oid");
    my $nGenes    = @gene_oids;
    if ( $nGenes > 100 ) {
        webError(   "Maximum number of genes (100) selected exceeded. "
                  . "Please select a smaller number." );
    }
    my $dbh         = dbLogin();
    my $gene_clause = join( ',', @gene_oids );
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql         = qq{
       select g.gene_oid, g.locus_type, g.obsolete_flag
       from gene g
       where g.gene_oid in( $gene_clause )
           $rclause
           $imgClause
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @badGeneOids;
    for ( ; ; ) {
        my ( $gene_oid, $locus_type, $obsolete_flag ) = $cur->fetchrow();
        last if !$gene_oid;
        if ( $locus_type ne "CDS" ) {
            push( @badGeneOids, $gene_oid );
        }
        if ( $obsolete_flag ne "No" ) {
            push( @badGeneOids, $gene_oid );
        }
    }
    #$dbh->disconnect();
    if ( scalar(@badGeneOids) > 0 ) {
        my $geneOidStr = join( ', ', @badGeneOids );
        webError(   "Genes such as $geneOidStr are not protein coding genes or "
                  . "are obsolete genes.  Please select only "
                  . "non-obsolete protein coding genes." );
    }
}

############################################################################
# printPhyloPanel - Print one panel subsection of occurrence profile.
#   Inputs:
#      gene_oids_ref - gene object identifier array reference
#      arrays_ref - array of phylogenetic positions for one gene
#      startIdx - start index for panel
#      incr - increment for panel
############################################################################
sub printPhyloPanel {
    my ( $gene_oids_ref, $arrays_ref, $startIdx, $incr ) = @_;
    my $nGenes = @$gene_oids_ref;
    my $nRows  = @$arrays_ref;
    if ( $nGenes != $nRows ) {
        webDie("printPhyloPanel: nGenes=$nGenes != nRows=$nRows\n");
    }
    for ( my $i = 0 ; $i < $nGenes ; $i++ ) {
        my $gene_oid = $gene_oids_ref->[$i];
        my $arr_ref  = $arrays_ref->[$i];
        my $url      =
            "$main_cgi?section=GeneDetail"
          . "&page=geneDetail&gene_oid=$gene_oid";
        my $nPad = 16 - length($gene_oid);
        my $pad  = " " x $nPad;
        print "<a href='$url'>$gene_oid</a>$pad";
        my $nCols = @$arr_ref;
        $nCols = $startIdx + $incr if $nCols > $startIdx + $incr;

        for ( my $j = $startIdx ; $j < $nCols ; $j++ ) {
            my $rec = $arr_ref->[$j];
            my ( $domain, $phylum, $taxon_oid, $taxon_display_name, $match ) =
              split( /\t/, $rec );
            my $url = '#';
            $taxon_display_name =~ s/'/ /g;
            my $label = escHtml("[$phylum] $taxon_display_name");
            my $xx    = "title='$label'";
            print "<a href='$url' $xx>";
            if ($match) {
                print "$domain</a>";
            } else {
                print ".</a>";
            }
        }
        print "\n";
    }
}

############################################################################
# printGeneLegend - Match gene_oid's with description and show in table.
#   Inputs:
#      dbh - database handle
#      gene_oids_ref - gene object identifers reference to array
############################################################################
sub printGeneLegend {
    my ( $dbh, $gene_oids_ref ) = @_;
    my $gene_oid_str = join( ',', @$gene_oids_ref );
    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql          = qq{
      select g.gene_oid, g.gene_display_name, tx.genus, tx.species
      from gene g, taxon tx
      where g.taxon = tx.taxon_oid
          $rclause
          $imgClause
          and g.gene_oid in( $gene_oid_str )
          and g.obsolete_flag = 'No'
      order by g.gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    print "<table class='img'  border=1>\n";
    print "<th class='img' >Gene ID</th>\n";
    print "<th class='img' >Product Name</th>\n";

    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $genus, $species ) =
          $cur->fetchrow();
        last if !$gene_oid;
        print "<tr class='img' >\n";
        print "  <td class='img' >$gene_oid</td>\n";
        my $s = escHtml("$gene_display_name [$genus $species]");
        print "<td class='img' >$s</td>\n";
        print "</tr>\n";
    }
    print "</table>\n";
    $cur->finish();
}

1;

