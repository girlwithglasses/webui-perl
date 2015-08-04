###########################################################################
# AvaCache.pm - Process from precomputed BLAST results
#    in "all vs. all cache".  BLAST results are from blastall -m 8
#    tab delimited output.
#   --es 10/04/2006
############################################################################
package AvaCache;
use strict;
use Data::Dumper;
use WebConfig;
use WebUtil;

my $env = getEnv( );

my $ava_batch_dir         = $env->{ ava_batch_dir };
#my $grep_bin             = $env->{ grep_bin };
my $findHit_bin           = $env->{ findHit_bin };
my $webMblast_url         = $env->{ webMblast_url };
my $webMblast_db          = $env->{ webMblast_db };
my $use_webMblast_genePage = $env->{ use_webMblast_genePage };
my $gene_hits_zfiles_dir  = $env->{ gene_hits_zfiles_dir };
my $verbose               = $env->{ verbose };

############################################################################
# getHitsGenomePair - Get hits given a gene_oid and taxon (or '*' for all
#    taxons).  Sort resuls in descending bit score order.
# NO LONGER IN USE - 20120824
############################################################################
sub getHitsGenomePair_old {
    my( $dbh, $gene_oid, $taxon, $homologRecs_ref, 
        $maxEvalue, $minPercIdent ) = @_;

    $gene_oid = sanitizeInt( $gene_oid );
    if( $taxon eq  '*' ) {
       $taxon = '*';  # For security reasons.
    }
    else {
       $taxon = sanitizeInt( $taxon );
    }
    my $sql = qq{
       select g.gene_oid, g.taxon, g.aa_seq_length
       from gene g
       where g.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid);
    my( $gene_oid, $taxon_lid, $aa_seq_length ) = $cur->fetchrow( );
    $cur->finish( );
    my $gene_lid = "${gene_oid}_${taxon_lid}_${aa_seq_length}"; #long ID

    my %validTaxons = WebUtil::getAllTaxonsHashed( $dbh );
    my $gene_taxon_oid = geneOid2TaxonOid( $dbh, $gene_oid );

    my $dir = "$ava_batch_dir/$gene_taxon_oid";
    if( !-e( $dir ) ) {
        webDie( "getHits: directory '$dir' does not exist\n" );
    }
    webLog( "+ chdir $dir\n" );
    chdir( $dir );

    # --es 11/18/2006 Use my findHit for a slightly more robust implementation.
    #my $cmd = "$grep_bin -H '^$gene_lid\t' $gene_taxon_oid-$taxon.m8.txt";
    #my $cmd = "$grep_bin -H '^$gene_oid' $gene_taxon_oid-$taxon.m8.txt";
    my $taxon2 = $taxon;
    $taxon2 = "x" if $taxon eq "*";
    my $filePattern = "$gene_taxon_oid-$taxon2.m8.txt";
    my $cmd = "$findHit_bin $gene_lid $dir $filePattern";
    webLog( "+ $cmd\n" );
    WebUtil::unsetEnvPath();
    my $cfh = newCmdFileHandle( $cmd, "getHits" );
    my @recs2;
    while( my $s =  $cfh->getline( ) ) {
        chomp $s;
	if( $s =~ /ERROR/ ) {
        WebUtil::resetEnvPath();
	    webDie( $s );
	}
	my( $fileName, $row ) = split( /:/, $s );
	my $froot = fileRoot( $fileName );
	my( $taxon1, $taxon2 ) = split( /\-/, $froot );
	next if !$validTaxons{ $taxon2 };
        my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
            $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
	         split( /\t/, $row );
	next if $maxEvalue ne "" && $evalue > $maxEvalue;
	next if $minPercIdent ne "" && $percIdent < $minPercIdent;
	my( $gene_oid2, undef ) = split( /_/, $qid );
	next if $gene_oid2 ne $gene_oid;
        my $row2 = $bitScore . "\t" . $taxon2 . "\t" . $row;
	push( @recs2, $row2 );
    }
    close $cfh;
    WebUtil::resetEnvPath();
    my @recs3 = reverse( sort{ $a <=> $b }( @recs2 ) );
    for my $r( @recs3 ) {
        my( $bitScore0, $taxon2, $qid, $sid, $percIdent, $alen,
	    $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send,
	    $evalue, $bitScore ) = split( /\t/, $r );
	my( $homolog, undef ) = split( /_/, $sid );
        my $r = "$gene_oid\t";
        $r .= "$homolog\t";
        $r .= "$taxon2\t";
        $r .= "$percIdent\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        $r .= "$evalue\t";
        $r .= "$bitScore\t";
        $r .= "$alen\t";
        push( @$homologRecs_ref, $r );
    }
    my $count = @recs3;
    if( $taxon ne '*' ) {
        return $count;
    }
    else {
        return "topHits";
    }
}

############################################################################
# getGeneHits - Use gene.hits.files.
############################################################################
sub getGeneHits {
    my( $gene_oid, $opType, $validTaxons_href, $homologRecs_aref,
        $homologType ) = @_;

    my @rows;
    if( $webMblast_url ne "" &&  $use_webMblast_genePage ) {
        @rows = Mblast::runMblastM8( "blastp", $gene_oid, '', 1e-2 );
    }
    elsif( $homologType eq "clusterHomologs" ) {
        @rows = getClusterHomologRows( $gene_oid, $opType, $validTaxons_href );
    }
    elsif( $gene_hits_zfiles_dir ne "" ) {
        my $dbh = dbLogin( );
        @rows = getGeneHitsZipRows( $dbh, 
	   $gene_oid, $opType, $validTaxons_href );
        #$dbh->disconnect( );
    }
    else {
        @rows = getGeneHitsRows( $gene_oid, $opType, $validTaxons_href );
    }
    my $idx = 0;
    my @hrecs;
    my @sortRecs;
    my %done;
    for my $r0( @rows ) {
        my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
            $qstart, $qend, $sstart, $send, $evalue, $bitScore, $opType ) = 
	       split( /\t/, $r0 );
        my( $qgene_oid, $qtaxon, $qlen ) = split( /_/, $qid );
        my( $sgene_oid, $staxon, $slen ) = split( /_/, $sid );
        my $r = "$qgene_oid\t";
        $r .= "$sgene_oid\t";
        $r .= "$staxon\t";
        $r .= "$percIdent\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        $r .= "$evalue\t";
        $r .= "$bitScore\t";
        $r .= "$alen\t";
        $r .= "$opType\t";
        push( @hrecs, $r );
        my $key = "$bitScore\t$idx";
        push( @sortRecs, $key );
	$done{ $sid } = 1;
	$idx++;
    }
    # Resort by gene_oid asc, bit_score desc
    my @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
    my @a;
    for my $sr (@sortRecs2) {
        my ( $bit_score, $idx ) = split( /\t/, $sr );
        my $hrec = $hrecs[$idx];
        push( @$homologRecs_aref, $hrec );
    }
    return "topHits";
}

1;
