############################################################################
#  OtfBlast.pm - On the fly BLAST.  Run BLAST with just FASTA files
#    from gene_oid specification.  Generate temp BLAST db dynamically.
#   --es 12/03/2005
#
# $Id: OtfBlast.pm 33478 2015-05-29 20:48:54Z klchu $
############################################################################
package OtfBlast;
my $section = "OtfBlast";
use strict;
use Data::Dumper;
use CGI qw( :standard );
use DBI;
use LWP;
use HTTP::Request::Common qw( POST );
use WebConfig;
use WebUtil;
use InnerTable;
use AvaCache;
use OracleUtil;
use GenomeListFilter;
use HtmlUtil;
use MerFsUtil;
use MetaUtil;
use Command;
use GenomeCart;
use GenomeListJSON;
use HTML::Template;
use FindGenesBlast;

my $env                     = getEnv();
my $main_cgi                = $env->{main_cgi};
my $section_cgi             = "$main_cgi?section=$section";
my $tmp_dir                 = $env->{tmp_dir};
my $cgi_tmp_dir             = $env->{cgi_tmp_dir};
my $cgi_dir                 = $env->{cgi_dir};
my $cgi_url               = $env->{cgi_url};
my $base_dir               = $env->{base_dir};
my $mer_data_dir            = $env->{mer_data_dir};
my $taxon_faa_dir           = $env->{taxon_faa_dir};
my $taxon_fna_dir           = $env->{taxon_fna_dir};
my $common_tmp_dir          = $env->{common_tmp_dir};
my $include_metagenomes     = $env->{include_metagenomes};
my $show_myimg_login        = $env->{show_myimg_login};
my $blast_server_url        = $env->{blast_server_url};
my $sandbox_blast_data_dir  = $env->{sandbox_blast_data_dir};
my $img_lid_blastdb         = $env->{img_lid_blastdb};
my $img_iso_blastdb         = $env->{img_iso_blastdb};
my $lite_homologs_url       = $env->{lite_homologs_url};
my $use_app_lite_homologs   = $env->{use_app_lite_homologs};
my $img_hmms_serGiDb        = $env->{img_hmms_serGiDb};
my $img_hmms_singletonsGiDb = $env->{img_hmms_singletonsDb};
my $user_restricted_site    = $env->{user_restricted_site};
my $blastall_bin            = $env->{blastall_bin};
my $formatdb_bin            = $env->{formatdb_bin};
my $blastallm0_server_url   = $env->{blastallm0_server_url};
my $img_ken                 = $env->{img_ken};
my $z_arg                   = "-z 1000000";
my $verbose                 = $env->{verbose};

my $blast_max_genome = $env->{blast_max_genome};

my $cgi_blast_cache_enable = $env->{cgi_blast_cache_enable};
my $blast_wrapper_script   = $env->{blast_wrapper_script};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my($numTaxon) = @_;
    my $page = param("page");

    my $sid = getContactOid();

    if ( paramMatch("genePageGenomeBlast") ) {
#        if($img_ken) {
            printGenePageGenomeBlastForm_new($numTaxon);
#        } else {
#            printGenePageGenomeBlastForm();
#        }
    } elsif ( $page eq "genomeBlastResults" ) {
        if ($cgi_blast_cache_enable) {
            HtmlUtil::cgiCacheInitialize($section);
            HtmlUtil::cgiCacheStart() or return;
        }
        timeout( 60 * 20 );    # timeout in 20 minutes
        printGenomeBlastResults();
        HtmlUtil::cgiCacheStop() if ($cgi_blast_cache_enable);
    } else {
#        if($img_ken) {
        printGenePageGenomeBlastForm_new($numTaxon);
#        } else {
#            printGenePageGenomeBlastForm();
#        }
    }
}

############################################################################
# genePageAlignments - Get gene page alignments from various criteria.
# NOT IN USE for almost 3  years. Called in sub testOtfBlast() which has
# not been used either -- marked by yjlin 03/13/2013
############################################################################
sub genePageAlignments {
    my ( $dbh, $gene_oid, $homologRecs_ref ) = @_;
    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpQueryFile = "$cgi_tmp_dir/gid$gene_oid.$$.faa";
    my $tmpDbFile    = "$cgi_tmp_dir/db$gene_oid.$$.faa";

    writeQueryFile( $dbh, $gene_oid, $tmpQueryFile );

    my $sql = qq{
       select distinct gpf.pfam_family
       from gene_pfam_families gpf
       where gpf.gene_oid = $gene_oid
   };
    my $cur = execSql( $dbh, $sql, $verbose );
    my @pfam_families;
    for ( ; ; ) {
        my ($pfam_family) = $cur->fetchrow();
        last if !$pfam_family;
        push( @pfam_families, $pfam_family );
    }
    $cur->finish();
    my $cnt_pfam = @pfam_families;

    my @cogs;
    if ( $cnt_pfam == 0 ) {
        my $sql = qq{
           select distinct gcg.cog
           from gene_cog_groups gcg
           where gcg.gene_oid = ?
       };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ($cog) = $cur->fetchrow();
            last if !$cog;
            push( @cogs, $cog );
        }
        $cur->finish();
    }
    my $cnt_cog = @cogs;

    webLog("cnt_pfam=$cnt_pfam cnt_cog=$cnt_cog\n") if $verbose >= 1;

    my $filterType;
    if ( $cnt_pfam > 0 ) {
        webLog "Using alternative Pfam homologs for gene_oid=$gene_oid\n"
          if $verbose >= 1;
        blastDbAltPfam( $dbh, $gene_oid, \@pfam_families, $tmpDbFile );
        $filterType = "Pfam";
    } elsif ( $cnt_cog > 0 ) {
        webLog "Using alternative COG homologs for gene_oid=$gene_oid\n"
          if $verbose >= 1;
        blastDbAltCog( $dbh, $gene_oid, \@cogs, $tmpDbFile );
        $filterType = "COG";
    } else {
        webLog("No cluster found.  Returning.\n");
        return;
    }
    my $logFile = "$tmpDbFile.log";
    $tmpDbFile = checkTmpPath($tmpDbFile);
    $logFile   = checkTmpPath($logFile);
    my $cmd = "$formatdb_bin -i $tmpDbFile -o T -p T -l $logFile";

    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );

    #runCmd($cmd);

    runBlast( $tmpQueryFile, $tmpDbFile, $homologRecs_ref );
    purgeBlastDb($tmpDbFile);
    wunlink($tmpQueryFile);
    wunlink($tmpDbFile);
    return $filterType;
}

############################################################################
# genePageTopHits - Get top hits for real "on the fly" BLAST.
#
# $vbose - set to 1 to use the working div progress
#   - all it does is print messages, the working div should be setup
#   - by the calling package - ken
#
# $seq_merfs - gene seq from a merfs genome called from MetaGeneDetail::printTopHomologs
############################################################################
sub genePageTopHits {
    my ( $dbh, $gene_oid, $homologRecs_ref, $top_n, $isLite, $vbose, $opType, $homologType, $seq_merfs ) = @_;

    print "Finding genomes<br/>\n" if ($vbose);
    my %validTaxons = WebUtil::getAllTaxonsHashed( $dbh, 1 );

    print "Starting...<br>\n" if ($vbose);
    my $maxHomologResults = getSessionParam("maxHomologResults");
    if ( $top_n eq "" && $maxHomologResults ne "" ) {
        $top_n = $maxHomologResults;
    }

    my $blast_url = $blast_server_url;
    $blast_url = $lite_homologs_url
      if $lite_homologs_url ne "" && ( $isLite || $opType ne "" );
    webLog("blast url: $blast_server_url\n");
    #print("blast url: $blast_server_url<br/>\n");

    if ( $homologType eq "clusterHomologs" ) {
        return AvaCache::getGeneHits( $gene_oid, $opType, \%validTaxons, $homologRecs_ref, $homologType );
    } elsif ( $blast_url eq ""
              || ( $use_app_lite_homologs && ( $isLite || $opType ne "" ) ) )
    {
        webLog("genePageTopHits: using AvaCache\n");

        #return AvaCache::getHitsGenomePair(
        #   $dbh, $gene_oid, '*', $homologRecs_ref );
        return AvaCache::getGeneHits( $gene_oid, $opType, \%validTaxons, $homologRecs_ref );
    }

    my $sessionId = getSessionId();

    # TODO - on the fly blast for top homolgs - ken
    my $aa_residue;
    if ( $seq_merfs ne '' ) {
        # merfs gene
        $aa_residue = $seq_merfs;
    } else {
        my $sql = qq{
            select g.aa_residue
            from gene g
            where g.gene_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        ($aa_residue) = $cur->fetchrow();
        $cur->finish();
    }
    webLog("aa_residue=$aa_residue\n");
    #print("aa_residue=$aa_residue<br/>\n");

    my $ua = WebUtil::myLwpUserAgent(); 
    $ua->timeout(1000);
    $ua->agent("img2.x/genePageTopHits");

    my $db = $img_lid_blastdb;
    $db = $img_iso_blastdb
      if $img_iso_blastdb ne ""
      && param("homologs") eq "topIsolates";
    webLog("gene_oid=$gene_oid db='$db' top_n='$top_n' opType='$opType'\n");
    #print("gene_oid=$gene_oid db='$db' top_n='$top_n' opType='$opType'<br/>\n");

    webLog( "Post request " . currDateTime() . "\n" );
    my $req = POST $blast_url, [
        gene_oid => $gene_oid,
        seq      => $aa_residue,
        db       => $db,
        #top_n   => 10000,   # make large number
        top_n    => $top_n,  # make large number
        opType   => $opType, # Ortholog or Paralog filter (optional)
    ];

    print "Getting blast data<br/>\n" if ($vbose);
    my $res = $ua->request($req);
    if ( $res->is_success() ) {
        my @lines = split( /\n/, $res->content );
        my $idx = 0;
        my @sortRecs;
        my @hrecs;
        my %done;
        for my $s (@lines) {
            if ( $s =~ /ERROR:/ ) {
                webError($s);
            }
            my (
                 $qid,  $sid,    $percIdent, $alen,   $nMisMatch, $nGaps, $qstart,
                 $qend, $sstart, $send,      $evalue, $bitScore,  $opType
              )
              = split( /\t/, $s );
            my ( $gene_oid, undef ) = split( /_/, $qid );
            my ( $homolog, $staxon, undef ) = split( /_/, $sid );
            next if !$validTaxons{$staxon};
            next if $done{$sid};

            #print "Getting $qid, $sid<br>\n" if ($vbose);

            my $r = "$gene_oid\t";
            $r .= "$homolog\t";
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
            $done{$sid} = 1;
            $idx++;
        }

        # Resort by gene_oid asc, bit_score desc
        my @sortRecs2 = reverse( sort { $a <=> $b } (@sortRecs) );
        for my $sr (@sortRecs2) {
            my ( $bit_score, $idx ) = split( /\t/, $sr );
            my $hrec = $hrecs[$idx];
            push( @$homologRecs_ref, $hrec );
        }
    } else {
        #print( $res->status_line . "\n" );
        webLog( $res->status_line . "\n" );
        warn( $res->status_line . "\n" );
    }
    
    return "topHits";
}

############################################################################
# geneCogHomologs - Find homologs based on COG's.
############################################################################
sub geneCogHomologs {
    my ( $dbh, $gene_oid, $homologRecs_ref ) = @_;

    my $workspace_id = $gene_oid;
    my @v = split( / /, $workspace_id );
    my $taxon_oid;
    my $data_type;

    if ( scalar(@v) > 1 ) {
        $taxon_oid = $v[0];
        $data_type = $v[1];
        $gene_oid  = $v[2];
    } else {
        $taxon_oid = 0;
        $data_type = 'database';
    }

    my $gid2 = MetaUtil::sanitizeGeneId3($gene_oid);
    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpQueryFile = "$cgi_tmp_dir/gid$gid2.$$.faa";
    my $tmpDbFile    = "$cgi_tmp_dir/db$gid2.$$.faa";

    writeQueryFile( $dbh, $workspace_id, $tmpQueryFile );

    my @cogs;
    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        @cogs = MetaUtil::getGeneCogId( $gene_oid, $taxon_oid, $data_type );
    } elsif ( isInt($workspace_id) && isInt($gene_oid) ) {
                                                              # top 5 hits
        my $sql = qq{
           select distinct gcg.cog, gcg.bit_score
           from gene_cog_groups gcg
           where gcg.gene_oid = ?
           and rownum < 6
           order by gcg.bit_score desc
           };

        # and gcg.rank_order = 1
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my ( $cog, $bit_score ) = $cur->fetchrow();
            last if !$cog;
            push( @cogs, $cog );
        }
        $cur->finish();
    }
    my $cnt2 = @cogs;

    if ( $cnt2 > 0 ) {
        webLog "Using COG homologs for gene_oid=$gene_oid\n"
          if $verbose >= 1;
        if ( isInt($gene_oid) ) {
            blastDbAltCog( $dbh, $gene_oid, \@cogs, $tmpDbFile );
        } else {
            blastDbAltCog( $dbh, 0, \@cogs, $tmpDbFile );
        }
    } else {
        webLog("No cluster found.  Returning.\n");
        return;
    }

    my $logFile = "$tmpDbFile.log";
    $tmpDbFile = checkTmpPath($tmpDbFile);
    $logFile   = checkTmpPath($logFile);
    my $cmd = "$formatdb_bin -i $tmpDbFile -o T -p T -l $logFile";

    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );

    #runCmd($cmd);

    print "<p>Running BLAST ...\n";
    runBlast( $tmpQueryFile, $tmpDbFile, $homologRecs_ref );
    purgeBlastDb($tmpDbFile);
    wunlink($tmpQueryFile);
    wunlink($tmpDbFile);
}

############################################################################
# writeQueryFile - Write FASTA file for query gene.
############################################################################
sub writeQueryFile {
    my ( $dbh, $gene_oid, $outFile ) = @_;

    my $workspace_id = $gene_oid;
    my @v = split( / /, $workspace_id );
    my $taxon;
    my $data_type;

    if ( scalar(@v) > 1 ) {
        $taxon     = $v[0];
        $data_type = $v[1];
        $gene_oid  = $v[2];
    } else {
        $taxon     = 0;
        $data_type = 'database';
    }

    my $aa_residue;

    if (    isInt($workspace_id)
         && isInt($gene_oid)
         && $data_type ne 'assembled'
         && $data_type ne 'unassembled' )
    {
        my $sql = qq{
           select g.aa_residue, g.taxon
           from gene g 
           where g.gene_oid = ?
           };
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        ( $aa_residue, $taxon ) = $cur->fetchrow();
        $cur->finish();
    } else {
        $aa_residue = MetaUtil::getGeneFaa( $gene_oid, $taxon, $data_type );
    }

    if ( blankStr($aa_residue) || $taxon eq "" ) {
        webLog( "writeQueryFile: invalid aa_residue='$aa_residue' " . "taxon='$taxon' for gene_oid=$gene_oid\n" );
        return;
    }
    my $wfh = newWriteFileHandle( $outFile, "writeQueryFile" );
    print $wfh ">${gene_oid}_${taxon}\n";
    print $wfh "$aa_residue\n";
    close $wfh;
}

############################################################################
# blastDbAltPfam - Altenrate for gene page alignments blast database,
#    using Pfam id joins.
############################################################################
sub blastDbAltPfam {
    my ( $dbh, $gene_oid, $pfam_families_ref, $outDb ) = @_;

    my $pfam_family_str = joinSqlQuoted( ",",         @$pfam_families_ref );
    my $wfh             = newWriteFileHandle( $outDb, "blastDbAltPfam" );
    my $sql             = qq{
	select g.gene_oid, g.taxon, g.aa_residue
	from gene_pfam_families gpf, gene g
	where gpf.pfam_family in( $pfam_family_str )
	and gpf.gene_oid != ?
	and g.gene_oid = gpf.gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my %done;
    for ( ; ; ) {
        my ( $gene_oid, $taxon, $aa_residue ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid} ne "";
        print $wfh ">${gene_oid}_${taxon}\n";
        print $wfh "$aa_residue\n";
        $done{$gene_oid} = 1;
    }
    $cur->finish();
    close $wfh;
}

############################################################################
# blastDbAltCog - Alternate for gene page alignments blast database,
#    using Cog joins.
############################################################################
sub blastDbAltCog {
    my ( $dbh, $gene_oid, $cogs_ref, $outDb ) = @_;

    my $cog_str = joinSqlQuoted( ",", @$cogs_ref );
    my $wfh = newWriteFileHandle( $outDb, "blastDbAltCog" );

    #    my $sql     = qq{
    #	select gcg.gene_oid, g.taxon, g.aa_residue
    #	from gene_cog_groups gcg, gene g, scaffold scf
    #	where gcg.cog in( $cog_str )
    #	and gcg.gene_oid != ?
    #	and g.gene_oid = gcg.gene_oid
    #	and g.scaffold = scf.scaffold_oid
    #    };
    my $sql = qq{
    select gcg.gene_oid, g.taxon, g.aa_residue
    from gene_cog_groups gcg, gene g, taxon t
    where gcg.cog in( $cog_str )
    and gcg.gene_oid != ?
    and g.gene_oid = gcg.gene_oid
    and g.taxon = t.taxon_oid
    and rownum < 10000 
    };

    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my %done;
    for ( ; ; ) {
        my ( $gene_oid, $taxon, $aa_residue ) = $cur->fetchrow();
        last if !$gene_oid;
        next if $done{$gene_oid} ne "";
        print $wfh ">${gene_oid}_${taxon}\n";
        print $wfh "$aa_residue\n";
        $done{$gene_oid} = 1;
    }
    $cur->finish();
    close $wfh;
}

############################################################################
# blastDbAlt2 - Altenrate 2 for gene page alignments blastdb
#   orthologs and paralogs.
############################################################################
sub blastDbAlt2 {
    my ( $dbh, $gene_oid, $outDb ) = @_;

    my $wfh = newWriteFileHandle( $outDb, "blastDbAlt2" );
    my $sql = qq{
        select go.ortholog, go.taxon, g2.aa_residue, gp2.paralog, g3.aa_residue
	from gene_orthologs go
	left join gene g2
	   on go.ortholog = g2.gene
	left join gene_paralogs gp2
	   on go.ortholog = gp2.gene_oid
        left join gene g3
	   on gp2.paralog = g3.gene
        where go.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my %done;
    for ( ; ; ) {
        my ( $ortholog, $taxon, $aa_residue1, $paralog, $aa_residue2 ) = $cur->fetchrow();
        last if !$ortholog;
        if ( $aa_residue1 ne "" && $done{$ortholog} eq "" ) {
            print $wfh ">${ortholog}_${taxon}\n";
            print $wfh "$aa_residue1\n";
        }
        if ( $aa_residue2 ne "" && $done{$paralog} eq "" ) {
            print $wfh ">${paralog}_${taxon}\n";
            print $wfh "$aa_residue2\n";
        }
        $done{$ortholog} = 1;
        $done{$paralog} = 1 if $paralog ne "";
    }
    $cur->finish();
    close $wfh;
}

############################################################################
# runBlast - Run BLAST and get results in homologs standard file
#    output.
############################################################################
sub runBlast {
    my ( $queryFile, $dbFile, $homologRecs_ref ) = @_;

    $queryFile = checkTmpPath($queryFile);
    $dbFile    = checkTmpPath($dbFile);
    if ( !( -e $dbFile ) ) {
        webLog("runBlast: cannot find '$dbFile'\n");
        return;
    }

    ## New BLAST
    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p blastp -i $queryFile -d $dbFile "
      . " -e 1e-2 -m 8 $z_arg -b 1000 "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013

    webLog "+ $cmd\n";
    WebUtil::unsetEnvPath();

    #    if ( $blast_wrapper_script ne "" ) {
    #        $cmd = "$blast_wrapper_script $cmd";
    #    }
    print "Calling blast api<br/>\n" if ($img_ken);
    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
    if ( $stdOutFile == -1 ) {

        # close working div but do not clear the data
        printEndWorkingDiv( '', 1 );
        ##$dbh->disconnect();
        printStatusLine( "Error.", 2 );
        WebUtil::webExit(-1);
    }
    print "blast done<br/>\n"                 if ($img_ken);
    print "Reading output $stdOutFile<br/>\n" if ($img_ken);
    my $cfh = WebUtil::newReadFileHandle($stdOutFile);

    #my $cfh = newCmdFileHandle( $cmd, "runBlast" );
    my %done;
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }

        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );
        next if $qid eq $sid;
        my $k = "$qid-$sid";
        next if $done{$k} ne "";
        my ( $qid_gene_oid, $qid_taxon ) = split( /_/, $qid );
        my ( $sid_gene_oid, $sid_taxon ) = split( /_/, $sid );
        my $r = "$qid_gene_oid\t";
        $r .= "$sid_gene_oid\t";
        $r .= "$sid_taxon\t";
        $r .= "$percIdent\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        $r .= "$evalue\t";
        $r .= "$bitScore\t";
        $r .= "$alen\n";
        push( @$homologRecs_ref, $r );
        $done{$k} = 1;
    }
    close $cfh;
    WebUtil::resetEnvPath();
}

############################################################################
# purgeBlastDb - Purge BLAST db files.
############################################################################
sub purgeBlastDb {
    my ($dbPath) = @_;
    wunlink("$dbPath.phr");
    wunlink("$dbPath.pin");
    wunlink("$dbPath.psd");
    wunlink("$dbPath.psi");
    wunlink("$dbPath.psq");
    wunlink("$dbPath.log");
}

############################################################################
# testOtfBlast - Test this module.
# NOT IN USE for almost 3  years -- marked by yjlin 03/13/2013
############################################################################
sub testOtfBlast {    # NOT IN USE
    my ($gene_oid) = @_;
    my $dbh = dbLogin();
    my @recs;
    genePageAlignments( $dbh, $gene_oid, \@recs );

    #$dbh->disconnect();
    for my $r (@recs) {
        my (
             $gene_oid,   $homolog,  $taxon,  $percent_identity, $query_start, $query_end,
             $subj_start, $subj_end, $evalue, $bit_score,        $align_length
          )
          = split( /\t/, $r );
        printf( "%-20s : '%s'\n", "gene_oid",         $gene_oid );
        printf( "%-20s : '%s'\n", "homolog",          $homolog );
        printf( "%-20s : '%s'\n", "taxon",            $taxon );
        printf( "%-20s : '%s'\n", "percent_identity", $percent_identity );
        printf( "%-20s : '%s'\n", "query_start",      $query_start );
        printf( "%-20s : '%s'\n", "query_end",        $query_end );
        printf( "%-20s : '%s'\n", "subj_start",       $subj_start );
        printf( "%-20s : '%s'\n", "subj_end",         $subj_end );
        printf( "%-20s : '%s'\n", "evalue",           $evalue );
        printf( "%-20s : '%s'\n", "bit_score",        $bit_score );
        printf( "%-20s : '%s'\n", "align_length",     $align_length );
        print "\n";
    }
    my $nRecs = @recs;
    print "$nRecs rows returned\n";
}

############################################################################
# printGenePageGenomeBlastForm - Show form for selecting genomes
#   for finding homologs.
############################################################################
sub printGenePageGenomeBlastForm {
    my $gene_oid = param("genePageGeneOid");

    printMainForm();

    print "<h1>BLAST Against Selected Genomes for Gene $gene_oid</h1>\n";
    print "<p>\n";
    print "Please select one or more genomes ";
    print "for finding protein sequence similaries (homologs).\n";
    print "<br/>\n";
    print qq{
         If you select more than <b>$blast_max_genome</b> genomes <u>All genomes</u> in IMG will be used.
    };
    print "</p>\n";

    my $dbh = dbLogin();
    GenomeListFilter::appendGenomeListFilter( $dbh, '', '', '', '', '', $include_metagenomes, '', '', '' );

    #$dbh->disconnect( );

    print "<br/>\n";

    print "<table class='img' border='1'>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Program</th>\n";
    print "<td class='img'>\n";
    print qq{
<select id="toScan" name="blast_program">
<option value="blastp">blastp (Protein vs. Protein)</option>
<option value="blastn">blastn (DNA vs. DNA)</option>
</select>
    };
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Max. E-value</th>\n";
    print "<td class='img'>\n";
    print popup_menu(
                      -name    => "maxEvalue",
                      -values  => [ "10e-0", "5e-0", "2e-0", "1e-0", "1e-2", "1e-5", "1e-8", "1e-10", "1e-20", "1e-50" ],
                      -default => "1e-2"
    );
    print "</td>\n";
    print "</tr>\n";

    #
    print "<tr class='img'>\n";
    print "<th class='subhead'>Min. Percent Identity</th>\n";
    print "<td class='img'>\n";
    print popup_menu(
                      -name    => "minPercIdent",
                      -values  => [ "10", "20", "30", "40", "50", "60", "70", "80", "90" ],
                      -default => "30"
    );
    print "</td>\n";
    print "</tr>\n";

    #
    print "</table>\n";
    print "<p>\n";
    print "<input type='checkbox' name='bbh' value='1' checked />\n";
    print "Compute bidirectional best hits also. " . "( <i>applicable only when running BLASTP against isolates</i> ).\n";
    print "</p>\n";

    print hiddenVar( "page", "genomeBlastResults" );
    my $name = "_section_${section}_genomeBlastResults";
    print submit(
                  -id    => "go",
                  -name  => $name,
                  -value => "Run BLAST",
                  -class => "smdefbutton"
    );
    print nbsp(1);
    print "<input id='reset' type='button' name='clearSelections' value='Reset' class='smbutton' />\n";
    printHint(   "- Hold down control key (or command key in the case of the Mac) "
               . "to select multiple genomes.<br/>\n"
               . "- Drag down list to select all genomes.<br/>\n"
               . "- More genome and function selections result in slower query.<br>\n"
               . "- BLAST will run against <u>all</u> isolate genomes in IMG (slow) "
               . "if 0 genome is selected.\n" );

    my $genome_type = param("genome_type");
    my $taxon_oid   = param("taxon_oid");
    my $data_type   = param("data_type");
    print hiddenVar( "genePageGeneOid", $gene_oid );
    print hiddenVar( "genome_type",     $genome_type );
    print hiddenVar( "query_taxon_oid", $taxon_oid );
    print hiddenVar( "query_data_type", $data_type );
    print end_form();
}

# new form
sub printGenePageGenomeBlastForm_new {
    my($numTaxon) = @_;
    my $gene_oid = param("genePageGeneOid");

    printMainForm();

    print "<h1>BLAST Against Selected Genomes for Gene $gene_oid</h1>\n";
    print "<p>\n";
    print "Please select one or more genomes ";
    print "for finding protein sequence similaries (homologs).\n";
    print "<br/>\n";
    print qq{
         If you select more than <b>$blast_max_genome</b> genomes <u>All genomes</u> in IMG will be used.
    };
    print "</p>\n";

    my $templateFile = "$base_dir/findGenesBlast_new.html";
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $xml_cgi = $cgi_url . '/xml.cgi';
    $include_metagenomes = 0 if ( $include_metagenomes eq "" );
    my $template = HTML::Template->new( filename => "$base_dir/genomeJson.html" );
    $template->param( isolate      => 1 );
    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( isolate      => 1 );
    $template->param( all          => 1 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( include_metagenomes      => $include_metagenomes );
    
    # prefix
    $template->param( prefix => '' );
    print $template->output;

    GenomeListJSON::showGenomeCart($numTaxon);

    HtmlUtil::printMetaDataTypeChoice('', 1);

    print "<br/>\n";
    print "<table class='img' border='1'>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Program</th>\n";
    print "<td class='img'>\n";
    print qq{
        <select id="toScan" name="blast_program">
        <option value="blastp">blastp (Protein vs. Protein)</option>
        <option value="blastn">blastn (DNA vs. DNA)</option>
        </select>
    };
    print "</td>\n";
    print "</tr>\n";

    print "<tr class='img'>\n";
    print "<th class='subhead'>Max. E-value</th>\n";
    print "<td class='img'>\n";
    print popup_menu(
                      -name    => "maxEvalue",
                      -values  => [ "10e-0", "5e-0", "2e-0", "1e-0", "1e-2", "1e-5", "1e-8", "1e-10", "1e-20", "1e-50" ],
                      -default => "1e-2"
    );
    print "</td>\n";
    print "</tr>\n";

    #
    print "<tr class='img'>\n";
    print "<th class='subhead'>Min. Percent Identity</th>\n";
    print "<td class='img'>\n";
    print popup_menu(
                      -name    => "minPercIdent",
                      -values  => [ "10", "20", "30", "40", "50", "60", "70", "80", "90" ],
                      -default => "30"
    );
    print "</td>\n";
    print "</tr>\n";

    #
    print "</table>\n";
    print "<p>\n";
    print "<input type='checkbox' name='bbh' value='1' checked />\n";
    print "Compute bidirectional best hits also. " . "( <i>applicable only when running BLASTP against isolates</i> ).\n";
    print "</p>\n";

#    print hiddenVar( "page", "genomeBlastResults" );
    my $name = "_section_${section}_genomeBlastResults";
#    print submit(
#                  -id    => "go",
#                  -name  => $name,
#                  -value => "Run BLAST",
#                  -class => "smdefbutton"
#    );

    GenomeListJSON::printHiddenInputType($section, 'genomeBlastResults');
    GenomeListJSON::printMySubmitButtonBlast( "go", $name, "Run BLAST",
                                             '', $section, 'genomeBlastResults', 'smdefbutton' );  

    
    print nbsp(1);
    print "<input id='reset' type='button' name='clearSelections' value='Reset' class='smbutton' />\n";
    printHint(   "- Hold down control key (or command key in the case of the Mac) "
               . "to select multiple genomes.<br/>\n"
               . "- Drag down list to select all genomes.<br/>\n"
               . "- More genome and function selections result in slower query.<br>\n"
               . "- BLAST will run against <u>all</u> isolate genomes in IMG (slow) "
               . "if 0 genome is selected.\n" );

    my $genome_type = param("genome_type");
    my $taxon_oid   = param("taxon_oid");
    my $data_type   = param("data_type");
    print hiddenVar( "genePageGeneOid", $gene_oid );
    print hiddenVar( "genome_type",     $genome_type );
    print hiddenVar( "query_taxon_oid", $taxon_oid );
    print hiddenVar( "query_data_type", $data_type );
    
    if ($numTaxon) {
        GenomeListJSON::showGenomeCart($numTaxon);
    }
    
    print end_form();
}


############################################################################
# loadDomainTaxons - Load the domain related to a taxon.
############################################################################
sub loadDomainTaxons {
    my ( $dbh, $domain, $taxon_oids_ref ) = @_;

    my $sql = qq{
       select taxon_oid
       from taxon 
       where domain like '$domain%'
       order by taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @$taxon_oids_ref, $taxon_oid );
    }
    $cur->finish();
}

############################################################################
# loadPhylumTaxons - Load the domain related to a taxon.
############################################################################
sub loadPhylumTaxons {
    my ( $dbh, $phylum, $taxon_oids_ref ) = @_;

    my $sql = qq{
       select taxon_oid
       from taxon 
       where phylum = ?
       order by taxon_display_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $phylum );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        push( @$taxon_oids_ref, $taxon_oid );
    }
    $cur->finish();
}

############################################################################
# printGenomeBlastResults - Print results from running blast against
#   selected genomes.
############################################################################
sub printGenomeBlastResults {
    my $query_gene_oid   = param("genePageGeneOid");
    my $query_gene_taxon = param("query_taxon_oid");
    my $query_data_type  = param("query_data_type");
    my $maxEvalue        = param("maxEvalue");
    my $minPercIdent     = param("minPercIdent");
    my $bbh              = param("bbh");
    my $blast_program    = param("blast_program");
    $blast_program = "blastp" if ( !$blast_program );
    my $assemble_type    = param('data_type');

    #debug lines
    my $debug_flag = 0;

    print "<h1>Genome " . uc($blast_program) . " Results for Gene $query_gene_oid</h1>\n";
    my @taxon_oids = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");
    my $nTaxons    = @taxon_oids;

    # what is user select no genomes but has genomes in genome cart?
#    my $cartGenomes_aref = GenomeCart::getAllGenomeOids();
#    if ( $#$cartGenomes_aref > -1 && $nTaxons == 0 ) {
#        @taxon_oids = @$cartGenomes_aref;
#        $nTaxons    = @taxon_oids;
#    }

    my $all = 0;
    if ( $nTaxons == 0 || ( $nTaxons eq 1 && @taxon_oids[0] eq '-1' ) ) {
        $all = 1;
    }

    # if user selected mroe than 100 genomes do blast all - ken
    if($nTaxons >= $blast_max_genome) {
        $all = 1;
        @taxon_oids = ();
        $nTaxons = 0;
    }

    my $dbh = WebUtil::dbLogin();

    my @all_taxons = @taxon_oids;
    if ( $query_gene_taxon eq '' ) {
        $query_gene_taxon = WebUtil::geneOid2TaxonOid( $dbh, $query_gene_oid );
    }
    if ( $query_gene_taxon ne '' ) {
        push( @all_taxons, $query_gene_taxon ) if ( $query_gene_taxon ne '' );
    }
    print "printGenomeBlastResults query_gene_taxon [ $query_gene_taxon ]<br>"
      if ( $debug_flag eq 1 );
    print "printGenomeBlastResults all_taxons [ @all_taxons ]<br>"
      if ( $debug_flag eq 1 );

    my %infile_h = MerFsUtil::fetchTaxonsInFile( $dbh, @all_taxons );

    my $query_sequence;
    if ( $infile_h{$query_gene_taxon} eq 1 ) {
        if ( $blast_program eq 'blastp' ) {
            $query_sequence = MetaUtil::getGeneFaa( $query_gene_oid, $query_gene_taxon, $query_data_type );
        } else {
            my @vals = MetaUtil::getGeneInfo( $query_gene_oid, $query_gene_taxon, $query_data_type );

            my $j = 0;
            $j = 1 if ( scalar(@vals) > 7 );
            my $locus_type        = $vals[$j];
            my $gene_display_name = $vals[ $j + 2 ];
            my $start_coord       = $vals[ $j + 3 ];
            my $end_coord         = $vals[ $j + 4 ];
            my $strand            = $vals[ $j + 5 ];
            my $scaffold_oid      = $vals[ $j + 6 ];

            my $scaffold_seq = MetaUtil::getScaffoldFna( $query_gene_taxon, $query_data_type, $scaffold_oid );

            if ( $strand eq '-' ) {
                $query_sequence = WebUtil::getSequence( $scaffold_seq, $end_coord, $start_coord );
            } else {
                $query_sequence = WebUtil::getSequence( $scaffold_seq, $start_coord, $end_coord );
            }
        }
    } else {
        $query_gene_taxon = WebUtil::geneOid2TaxonOid( $dbh, $query_gene_oid );
        if ( $blast_program eq 'blastp' ) {
            $query_sequence = WebUtil::geneOid2AASeq( $dbh, $query_gene_oid );
        } else {
            my @goids = ($query_gene_oid);
            require SequenceExportUtil;
            my $href = SequenceExportUtil::getGeneFnaSeqDb( \@goids );
            $query_sequence = $href->{$query_gene_oid};
        }
    }

    my $query_seq_length = length($query_sequence);

    if ( blankStr($query_sequence) ) {
        webError("Please select a gene with a protein sequence.");
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    
    # do not call for blast all since it has a new framework - ekn
    # printStartWorkingDiv() if ( $debug_flag eq 0 );
    
    print "<p>\n";

    my @homologRecs;
    my @missingDb = ();
    my %orthologs;
    my %paralogs;    # these two hashes orthologs and paralogs wont be filled
                     # if blast_program is not blastp
    my ( $cnt, $coord_href );    # BLASTN: hash to save start and end coordinates for
                                 # all hits from each scaffold

    if ( $all eq 1 ) {           # blast against all
        print " Running $blast_program against all genomes. ";
        print "This might take a while...<br>";
        ( $cnt, $coord_href ) =
          processGenomeBlast( $query_gene_oid, $query_sequence, 'all', '', $maxEvalue, $minPercIdent, $blast_program,
                              \@homologRecs );
        print "Processing $blast_program results...<br>";
    } else {                     # blast against selected
        printStartWorkingDiv() if ( $debug_flag eq 0 );
        my %dbExistence_hash;
        for my $taxon_oid (@taxon_oids) {
            my @taxon_data_types = ($assemble_type);#qw/assembled unassembled/;
            if ( $infile_h{$taxon_oid} ne 1 ) {
                @taxon_data_types = qw/database/;
            }

            for my $taxon_data_type (@taxon_data_types) {
                my $cnt;
                ( $cnt, $coord_href ) = processGenomeBlast(
                                                          $query_gene_oid, $query_sequence, $taxon_oid,     $taxon_data_type,
                                                          $maxEvalue,      $minPercIdent,   $blast_program, \@homologRecs );
                if ( $cnt ne -1 ) {
                    $dbExistence_hash{$taxon_oid} = 1
                      unless ( exists( $dbExistence_hash{$taxon_oid} ) );

                    # if db exists for assembled data but not unassemble,
                    # we think db exists
                } else {
                    print "NEW missing[ $taxon_oid, $taxon_data_type ]<br>"
                      if ( $debug_flag eq 1 );
                    next;
                }

                my $taxon_display_name = taxonOid2Name( $dbh, $taxon_oid );
                my $msg = "$cnt hit(s) found for <i>" . escHtml($taxon_display_name);
                $msg .= " ($taxon_data_type)" if ( $taxon_data_type ne 'database' );
                $msg .= "</i><br/>\n";
                $msg = "<font color='red'>$msg</font>" if $cnt > 0;
                print $msg;

                if ( $cnt > 0 && $blast_program eq 'blastp' ) {

                    # longOrthologs and loadParalogs retrieve ortholog and
                    # paralog info from db gene_orthologs, gene_paralogs table
                    #loadOrthologs( $dbh, $query_gene_oid, $taxon_oid, \%orthologs );
                    loadParalogs( $dbh, $query_gene_oid, $taxon_oid, \%paralogs )
                      if ( $infile_h{$query_gene_taxon} ne 1 );

                    # TODO revise this for in_file
                }
            }
        }

        for my $x (@taxon_oids) {
            push( @missingDb, $x )
              unless ( grep( /^$x$/, keys %dbExistence_hash ) );
        }

    }
    print "Processing blastp output...<br>";

    my @recs_db;
    my @recs_fs;
    my %recs_fs_hash;
    my %homologTaxon2Gene;
    for my $s (@homologRecs) {
        my (
             $gene_oid,  $homolog,    $subj_taxon_oid, $subj_data_type, $percent_identity, $query_start,
             $query_end, $subj_start, $subj_end,       $evalue,         $bit_score,        $align_length
          )
          = split( /\t/, $s );
        #next if $gene_oid eq $homolog;
        $homolog =~ s/[><=]//g;    # remove invalid characters in homolog gene oid
        my $subj_id;
        if ( $blast_program eq 'blastn' ) {
            $subj_id = "$subj_taxon_oid.$homolog";

            # homolog is ext_accession, which can not be used
            # to specify a scaffold without providing a taxon
        } else {
            $subj_id = $homolog;

            # homolog is gene_oid, which is unique so taxon_oid is not needed.
        }
        my $r = "$subj_id\t";
        $r .= "$percent_identity\t";
        $r .= "$evalue\t";
        $r .= "$bit_score\t";
        $r .= "$query_start\t";
        $r .= "$query_end\t";
        $r .= "$subj_start\t";
        $r .= "$subj_end\t";
        $r .= "$align_length";

        my $key = "$subj_taxon_oid.$subj_data_type";
        if ( $infile_h{$subj_taxon_oid} eq 1 ) {
            push( @recs_fs, $r );
            if ( exists $recs_fs_hash{$key} ) {
                push( @{ $recs_fs_hash{$key} }, $r );
            } else {
                $recs_fs_hash{$key} = [$r];
            }
        } else {
            push( @recs_db, $r );
        }

        # Take first hit for a taxon which is the best hit.
        if (    $homologTaxon2Gene{$subj_taxon_oid} eq ""
             && $subj_taxon_oid ne $query_gene_taxon )
        {
            $homologTaxon2Gene{$subj_taxon_oid} = $homolog;
        }
    }

    my $nRecs = scalar(@recs_db) + scalar(@recs_fs);
    if ( $nRecs == 0 ) {
        printStatusLine( "0 gene(s) retrieved", 2 );
        if($img_ken) {
            printEndWorkingDiv('', 1);
        } else {
            printEndWorkingDiv();
        }
        print end_form();
        print "<p>No hits were found in selected genome(s).</p>";

        #$dbh->disconnect();
        return;
    }
    my $query_gene_oid_computeBBH;
    if ( $infile_h{$query_gene_taxon} eq 1 ) {
        $query_gene_oid_computeBBH = MetaUtil::getMetaGeneOid( $query_gene_oid, $query_data_type, $query_gene_taxon );
    } else {
        $query_gene_oid_computeBBH = $query_gene_oid;
    }

    if ( $bbh && $blast_program eq 'blastp' ) {
        computeBBH( $dbh, $query_gene_oid_computeBBH, \%homologTaxon2Gene, \%orthologs, $maxEvalue, $minPercIdent,
                    \%infile_h );
    }

    print "<p>\n";
    print "Retrieving gene attribute data ...<br/>\n";
    print "</p>\n";

    require GeneDetail;
    require MetaGeneDetail;
    my @recs;
    if ( $blast_program eq 'blastp' ) {

        # get info for hits from db
        @recs = GeneDetail::getGeneTaxonAttributes( $dbh, \@recs_db );

        # get infor for hits from fs
        for my $key ( keys %recs_fs_hash ) {
            my ( $toid, $dtype ) = split( /\./, $key );
            my @tmp = MetaGeneDetail::getMetaGeneTaxonAttributes( $dbh, $toid, $dtype, $recs_fs_hash{$key} );
            for my $x (@tmp) {
                my @x_parts = split( /\t/, $x, 2 );
                my @v2 = MetaUtil::parseMetaGeneOid( $x_parts[0] );
                $x_parts[0] = $v2[2] . " " . $v2[1] . " " . $v2[0];
                push( @recs, $x_parts[0] . "\t" . $x_parts[1] );
            }
        }

        if($img_ken) {
            printEndWorkingDiv('', 1);
        } else {
            printEndWorkingDiv();
        }

        MetaGeneDetail::printAddQueryGeneCheckBox( $query_gene_oid, $query_gene_taxon, $query_data_type );
        printGenomeBlastpResultTable( $dbh, \@recs, $query_gene_oid, $query_seq_length, \%orthologs, \%paralogs,
                                      \@missingDb );
    } else {    # blastn
                # query is a gene, but all other checkboxes in the yui table are scaffolds.
                # so it is inappropriate to print the query gene checkbox here.
        my $n_db = scalar(@recs_db);
        my $n_fs = scalar(@recs_fs);

        if ( $n_db != 0 ) {
            @recs = GeneDetail::getScaffoldAttributes( $dbh, \@recs_db );
        }
        if ( $n_fs != 0 ) {
            require MetaScaffoldGraph;
            my @recs2 = MetaScaffoldGraph::getMetaScaffoldAttributes( $dbh, \@recs_fs );
            push( @recs, $_ ) for (@recs2);
        }
        printGenomeBlastnResultTable( $dbh, \@recs, $coord_href, $query_gene_oid, $query_seq_length, \@missingDb );
    }

    #$dbh->disconnect();
}

############################################
sub printGenomeBlastnResultTable {
    my ( $dbh, $recs_aref, $coord_href, $query_gene_oid, $query_seq_length, $missingDb_aref ) = @_;

    my $it = new InnerTable( 0, "genomeBlast$$", "genomeBlast", 9 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Scaffold ID",          "asc",  "left" );
    $it->addColSpec( "External Accession",   "asc",  "left" );
    $it->addColSpec( "Scaffold Name",        "asc",  "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec( "E-value",       "asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "desc", "right" );
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids,  G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    $it->addColSpec( "Scaffold<br/>Length", "desc", "right" );
    $it->addColSpec( "Scaffold<br/>GC",     "desc", "right" );
    my $count = 0;
    for my $r (@$recs_aref) {
        my (
             $scf_ext_accession,  $scaffold_oid,   $scaffold_name,  $taxon_oid, $percent_identity,
             $evalue,             $bit_score,      $query_start,    $query_end, $subj_start,
             $subj_end,           $align_length,   $opType,         $domain,    $seq_status,
             $taxon_display_name, $scf_seq_length, $scf_gc_percent, $scf_read_depth,
          )
          = split( /\t/, $r );
        $count++;
        $scf_gc_percent   = sprintf( "%.2f", $scf_gc_percent );
        $percent_identity = sprintf( "%.2f", $percent_identity );
        my $alignPercent = $align_length / $query_seq_length * 100;

        my $input_checkbox_value = $scaffold_oid;
        my $scaffold_id_display  = $scaffold_oid;
        my $scaffold_id_sort     = $scaffold_oid;
        my $scaffold_url;
        my ( $goid, $dtype, $toid ) = MetaUtil::parseMetaGeneOid($scaffold_oid);
        if ( $goid ne '' ) {    #gene is from MERFS
            $scaffold_id_display  = $goid;
            $scaffold_id_sort     = "$toid $goid";
            $input_checkbox_value = "$toid $dtype $goid";
            $scaffold_url = "$main_cgi?section=MetaDetail&page=metaScaffoldDetail" 
                . "&taxon_oid=$toid&scaffold_oid=$goid&data_type=$dtype";
        } else {
            my $k = $taxon_oid . "." . $scf_ext_accession;
            require GeneDetail;
            $scaffold_url =
              GeneDetail::getScaffoldUrl( "", $subj_start, $subj_end, $scaffold_oid, $scf_seq_length, $coord_href->{$k}, );
        }

        my $r;
        $r .= "$sd<input type='checkbox' name='scaffold_oid' ";
        $r .= "value='$input_checkbox_value' />\t";

        $r .= $scaffold_id_sort . $sd . alink( $scaffold_url, $scaffold_id_display ) . "\t";
        $r .= $scf_ext_accession . $sd . $scf_ext_accession . "\t";

        $r .= $scaffold_name . $sd . $scaffold_name . "\t";
        $r .= $percent_identity . $sd . $percent_identity . "\t";
        $r .= $sd . alignImage( $query_start, $query_end, $query_seq_length ) . "\t";

        # scaffold is usually very long, so it does not
        # make sense to show the alignment of subject, and scaffold length

        my $evalue2    = sprintf( "%.1e", $evalue );
        my $bit_score2 = sprintf( "%d",   $bit_score );
        $r .= $evalue . $sd . $evalue2 . "\t";
        $r .= $bit_score2 . $sd . $bit_score2 . "\t";

        require TaxonDetail;
        $domain     = TaxonDetail::getShortDomain($domain);
        $seq_status = TaxonDetail::getShortDomain($seq_status);
        $r .= "$domain\t";
        $r .= "$seq_status\t";

        my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= $taxon_display_name . $sd . alink( $taxon_url, $taxon_display_name ) . "\t";

        $r .= "$scf_seq_length\t";
        $r .= "$scf_gc_percent\t";

        $it->addRow($r);
    }

        if($img_ken) {
            printEndWorkingDiv('', 1);
        } else {
            printEndWorkingDiv();
        }


    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";

    my $missing_cnt = @$missingDb_aref;
    if ( $missing_cnt > 0 ) {
        my $missing_oid_str = join( ",", @$missingDb_aref );
        my $sql             = qq{
            select taxon_oid, taxon_name 
            from taxon 
            where taxon_oid in ($missing_oid_str)
        };

        my $message;
        my $dbh = WebUtil::dbLogin();
        my $cur = execSql( $dbh, $sql );
        for ( ; ; ) {
            my ( $t, $tname ) = $cur->fetchrow();
            last if !$t;
            $message .= "&nbsp;&nbsp;&nbsp;&nbsp; - &nbsp; $tname ($t)<br>\n";
        }
        $cur->finish();

        #$dbh->disconnect();

        if ($message) {
            print "<p><font color='red'>\n";
            print "<b>Note</b>: IMG does not have BLAST data for the following genome(s):<br>\n";
            print $message;
            print "<br></font></p>\n";
        }
    }

    WebUtil::printScaffoldCartFooter( $dbh, $query_gene_oid ) if $count > 0;
    $it->printOuterTable(1);
    print "</p>\n";
    WebUtil::printScaffoldCartFooter( $dbh, $query_gene_oid ) if $count > 10;

    printStatusLine( "$count gene(s) retrieved", 2 );

    print end_form();

    #$dbh->disconnect();
}

############################################
sub printGenomeBlastpResultTable {
    my ( $dbh, $recs_aref, $query_gene_oid, $query_seq_length, $orthologs_href, $paralogs_href, $missingDb_aref ) = @_;
    my $it = new InnerTable( 0, "genomeBlast$$", "genomeBlast", 9 );
    my $sd = $it->getSdDelim();

    $it->addColSpec("Select");
    $it->addColSpec( "Homolog",      "asc", "left" );
    $it->addColSpec( "T",            "asc", "left", "", "Types: O=Ortholog, P=Paralog, - = other unidirectional hit" );
    $it->addColSpec( "Product Name", "asc", "left" );
    $it->addColSpec( "Percent<br/>Identity", "desc", "right" );
    $it->addColSpec("Alignment<br/>On<br/>Query<br/>Gene");
    $it->addColSpec("Alignment<br/>On<br/>Subject<br/>Gene");
    $it->addColSpec( "Length",        "desc", "right" );
    $it->addColSpec( "E-value",       "asc",  "left" );
    $it->addColSpec( "Bit<br/>Score", "desc", "right" );
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids,  G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    if ($include_metagenomes) {
        $it->addColSpec( "Scaffold ID",         "asc",  "left" );
        $it->addColSpec( "Scaffold<br/>Length", "desc", "right" );
        $it->addColSpec( "Scaffold<br/>GC",     "desc", "right" );
    }

    my $count = 0;
    for my $r (@$recs_aref) {
        my (
             $homolog,            $gene_display_name,  $percent_identity, $evalue,         $bit_score,
             $query_start,        $query_end,          $subj_start,       $subj_end,       $align_length,
             $opType,             $subj_aa_seq_length, $taxon_oid,        $domain,         $seq_status,
             $taxon_display_name, $scf_ext_accession,  $scf_seq_length,   $scf_gc_percent, $scf_read_depth
          )
          = split( /\t/, $r );
        $count++;
        $scf_gc_percent   = sprintf( "%.2f", $scf_gc_percent );
        $percent_identity = sprintf( "%.2f", $percent_identity );
        my $alignPercent = $align_length / $query_seq_length * 100;
        my $gene_url     = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$homolog";
        my ( $t2, $d2, $g2 ) = split( / /, $homolog );
        my $homolog_display = $homolog;

        if ( $d2 eq 'assembled' || $d2 eq 'unassembled' ) {
            $homolog_display = $g2;
            $gene_url        =
              "$main_cgi?section=MetaGeneDetail" . "&page=geneDetail&gene_oid=$g2" . "&taxon_oid=$t2&data_type=$d2";
        }
        my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        my $r;
        $r .= "$sd<input type='checkbox' name='gene_oid' " . "value='$homolog' />\t";
        $r .= $homolog . $sd . alink( $gene_url, $homolog_display ) . "\t";
        my $op = "-";
        $op = "O" if $orthologs_href->{$homolog};
        $op = "P" if $paralogs_href->{$homolog};
        $r .= "$op\t";
        $r .= "$gene_display_name\t";
        $r .= "$percent_identity\t";

        $r .= $sd . alignImage( $query_start, $query_end, $query_seq_length ) . "\t";
        $r .= $sd . alignImage( $subj_start,  $subj_end,  $subj_aa_seq_length ) . "\t";
        $r .= "${subj_aa_seq_length}${sd}${subj_aa_seq_length}aa\t";

        my $evalue2    = sprintf( "%.1e", $evalue );
        my $bit_score2 = sprintf( "%d",   $bit_score );
        $r .= $evalue . $sd . $evalue2 . "\t";
        $r .= $bit_score2 . $sd . $bit_score2 . "\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= $taxon_display_name . $sd . alink( $taxon_url, $taxon_display_name ) . "\t";

        if ($include_metagenomes) {
            $r .= "$scf_ext_accession\t";
            $r .= "$scf_seq_length\t";
            $r .= "$scf_gc_percent\t";
        }

        $it->addRow($r);
    }

    print hiddenVar( "genePageGeneOid", $query_gene_oid );

    print "<p>\n";
    print "Types (T): O = Ortholog, P = Paralog, " . "- = other unidirectional hit.<br/>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";

    my $missing_cnt = @$missingDb_aref;
    if ( $missing_cnt > 0 ) {
        my $missing_oid_str = join( ",", @$missingDb_aref );
        my $sql             = qq{
            select taxon_oid, taxon_name 
            from taxon 
            where taxon_oid in ($missing_oid_str)
        };

        my $message;
        my $dbh = WebUtil::dbLogin();
        my $cur = execSql( $dbh, $sql );
        for ( ; ; ) {
            my ( $t, $tname ) = $cur->fetchrow();
            last if !$t;
            $message .= "&nbsp;&nbsp;&nbsp;&nbsp; - &nbsp; $tname ($t)<br>\n";
        }
        $cur->finish();

        #$dbh->disconnect();

        if ($message) {
            print "<p><font color='red'>\n";
            print "<b>Note</b>: IMG does not have BLAST data for the following genome(s):<br>\n";
            print $message;
            print "<br></font></p>\n";
        }
    }

    printHomologFooter( $dbh, $query_gene_oid ) if $count > 0;
    $it->printOuterTable(1);
    print "</p>\n";
    printHomologFooter( $dbh, $query_gene_oid ) if $count > 10;

    printStatusLine( "$count gene(s) retrieved", 2 );
    print end_form();

    #$dbh->disconnect();
}

############################################################################
# loadOrthologs - Load orthologs.
############################################################################
#sub loadOrthologs {
#    my ( $dbh, $gene_oid, $taxon_oid, $orthologs_ref ) = @_;
#    my $sql = qq{
#	select go.ortholog
#	from gene_orthologs go
#	where go.gene_oid = ?
#	and go.taxon = ?
#    };
#    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid, $taxon_oid );
#    for ( ; ; ) {
#        my ($ortholog) = $cur->fetchrow();
#        last if !$ortholog;
#        $orthologs_ref->{$ortholog} = 1;
#    }
#    $cur->finish();
#}

############################################################################
# loadParalogs - Load paralogs list.
############################################################################
sub loadParalogs {
    my ( $dbh, $gene_oid, $taxon_oid, $paralogs_ref ) = @_;
    my $sql = qq{
	select gp.paralog
	from gene_paralogs gp
	where gp.gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    for ( ; ; ) {
        my ($paralog) = $cur->fetchrow();
        last if !$paralog;
        $paralogs_ref->{$paralog} = 1;
    }
    $cur->finish();
}

############################################################################
# computeBBH - Compute BBH's on the fly by taking the reverse hits.
############################################################################
sub computeBBH {
    my ( $dbh, $query_gene_oid, $homologTaxon2Gene_ref, $orthologs_ref, $maxEvalue, $minPercIdent, $infile_href ) = @_;

    # debug lines
    my $debug_flag = 0;
    printEndWorkingDiv() if ( $debug_flag eq 1 );

    my @keys = keys(%$homologTaxon2Gene_ref);
    my @homolog_oids;
    my %done;
    for my $k (@keys) {
        my $homolog_oid = $homologTaxon2Gene_ref->{$k};
        push( @homolog_oids, $homolog_oid );
        if ( $done{$homolog_oid} ) {
            ## should not get here
            warn("computeBBH: duplicate homolog_oid=$homolog_oid\n");
            next;
        }
        $done{$homolog_oid} = 1;
    }

    print "computeBBH - query_gene_oid: [$query_gene_oid]<br>"
      if ( $debug_flag eq 1 );

    my $query_gene_taxon;
    my ( $goid, $dtype, $toid ) = MetaUtil::parseMetaGeneOid($query_gene_oid);
    if ( $goid eq '' ) {    # gene is from database
        $query_gene_taxon = WebUtil::geneOid2TaxonOid( $dbh, $query_gene_oid );
    } else {
        $query_gene_taxon = $toid;
    }

    print "computeBBH - query_gene_taxon: [$query_gene_taxon]<br>"
      if ( $debug_flag eq 1 );

    print "<p>\n";

    my $sql = qq{
         select g.aa_residue, tx.taxon_display_name
         from gene g, taxon tx
         where g.gene_oid = ?
         and g.taxon = tx.taxon_oid
         and g.taxon != ?
         and g.aa_residue is not null
        };
    my $cur = prepSql( $dbh, $sql, $verbose );

    print "computeBBH - sql: [$sql]<br>" if ( $debug_flag eq 1 );

    for my $homolog_oid (@homolog_oids) {
        my ( $homolog_faa, $taxon_display_name );
        print "computeBBH - homolog_oid: [$homolog_oid]<br>" if ( $debug_flag eq 1 );

        my ( $goid, $dtype, $toid ) = MetaUtil::parseMetaGeneOid($homolog_oid);
        if ( $goid eq '' ) {    # gene is from database
            WebUtil::execStmt( $cur, $homolog_oid, $query_gene_taxon );
            ( $homolog_faa, $taxon_display_name ) = $cur->fetchrow();
        } else {                # gene is from metagenome
            $homolog_faa = MetaUtil::getGeneFaa( $goid, $toid, $dtype );
        }
        print "computeBBH - homolog_faa: [$homolog_faa]<br>" if ( $debug_flag eq 1 );

        if ( blankStr($homolog_faa) ) {
            webLog("computeBBH: no faa found for $homolog_oid\n");
            warn("computeBBH: no faa found for $homolog_oid\n");
            next;
        }

        if ( $debug_flag eq 1 ) {
            print "computeBBH - query_gene_oid: [$query_gene_oid]<br>";
            print "computeBBH - query_gene_taxon: [$query_gene_taxon]<br>";
        }

        my $cnt =
          processReverseOrthologBlast( $homolog_oid, $homolog_faa, $query_gene_taxon, $maxEvalue, $minPercIdent,
                                       $query_gene_oid, $orthologs_ref, $infile_href );
        if ( $cnt > 0 ) {
            print "$cnt reverse best hit found from gene $homolog_oid in <i>" . escHtml($taxon_display_name) . "</i><br/>\n";
        }
    }
    print "</p>\n";
    $cur->finish();
}

############################################################################
# processGenomeBlast - Process results for one genome
#   Return count of hits and a record of hits.
############################################################################
sub processGenomeBlast {
    my ( $gene_oid, $query_seq, $taxon_oid, $data_type, $maxEvalue, $minPercIdent, $blast_program, $homologRecs_ref ) = @_;

    # save coordinates for more than one hits from one scaffold,
    # only used when blast_program equals blastn
    my %coord_hash;

    my @v = split( / /, $gene_oid );
    my $gene_oid2 = $gene_oid;
    if ( scalar(@v) > 1 ) {
        $gene_oid2 = $v[2];
    }

    $gene_oid2 = MetaUtil::sanitizeGeneId3($gene_oid2);
    $maxEvalue = checkEvalue($maxEvalue);

    my $seqType;
    if ( $blast_program eq "blastp" ) {
        $seqType = 'faa';
    } else {
        $seqType = 'fna';
    }

    # db location and check existence
    my $db;
    if ( $taxon_oid eq 'all' ) {
        my $tmpDbFile = "$cgi_tmp_dir/$seqType";
        if ( $blast_program eq "blastp" ) {
            $tmpDbFile .= "Db$$.pal";
            $db = $tmpDbFile;
            $db =~ s/\.pal$//;
            FindGenesBlast::writePalFile($tmpDbFile);
        } else {
            $tmpDbFile .= "Db$$.nal";
            $db = $tmpDbFile;
            $db =~ s/\.nal$//;
            FindGenesBlast::writeNalFile($tmpDbFile);
        }
    } else {
        my $dbDir;
        $taxon_oid = sanitizeInt($taxon_oid);

        if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
            if ( $sandbox_blast_data_dir ne '' ) {
                $dbDir = $sandbox_blast_data_dir . "/" . $taxon_oid;
            } else {

                # OBSOLETE location
                $dbDir = "$mer_data_dir/$taxon_oid/$data_type/blast.data";
            }
            $db = $dbDir . "/" . $taxon_oid . "." . substr( $data_type, 0, 1 ) . "." . $seqType;
        } else {    # data_type equals database
            if ( $blast_program eq 'blastp' ) {
                if ( $sandbox_blast_data_dir ne '' ) {
                    $dbDir = "$sandbox_blast_data_dir/$taxon_oid";
                } else {
                    $dbDir = "$taxon_faa_dir/$taxon_oid.$seqType.blastdb";
                }
            } else {
                if ( $sandbox_blast_data_dir ne '' ) {
                    $dbDir = "$sandbox_blast_data_dir/$taxon_oid";
                } else {
                    $dbDir = "$taxon_fna_dir/$taxon_oid.$seqType.blastdb";
                }
            }
            if ( $sandbox_blast_data_dir ne '' ) {
                $db = "$dbDir/$taxon_oid" . '.' . $seqType;
            } else {
                $db = "$dbDir/$taxon_oid";
            }
        }

        if ( !( -e $dbDir ) ) {
            webLog("processGenomeBlast: cannot find '$dbDir'\n");
            return (-1);    # minus one indicates that blast db is not available
        }
    }

    # write sequence to tmp dir
    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpQueryFile = "$cgi_tmp_dir/g$gene_oid2-$taxon_oid.$seqType";
    $tmpQueryFile = checkTmpPath($tmpQueryFile);
    my $wfh = newWriteFileHandle( $tmpQueryFile, "processGenomeBlast" );
    print $wfh ">$gene_oid2\n";
    print $wfh "$query_seq\n";
    close $wfh;

    if ( $blast_program =~ /^(.*)$/ ) { $blast_program = $1; }    # untaint

    ## New BLAST
    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p $blast_program -d $db -e $maxEvalue -F 'm S' "
      . " -m 8 -i $tmpQueryFile "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013
    webLog "processGenomeBlast + $cmd\n";

    WebUtil::unsetEnvPath();

    my $cfh;
    my $reportFile;
    if ( $taxon_oid eq 'all' && $blastallm0_server_url ne "" ) {

        # hack for now - ken
        # the blast queue cgi script is not creating the report file
        # for now replace the blast queue url with the old one 
        #
        # 2015-03-13
        #
        #$blastallm0_server_url = $env->{worker_base_url} . "/cgi-bin/blast/generic/blastallServer2.cgi";

        # For security reasons, we don't put in the whole
        # path, but make some assumptions about the report
        # being in common_tmp_dir.
        if ( $common_tmp_dir ne "" ) {
           my $sessionId = getSessionId();
#           my $hostname = WebUtil::getHostname();
#            my $urlTag = $env->{urlTag};
            $reportFile = "blast.$sessionId.$$.tabular.txt";
        }

        # Heuristic to discover IMG (Oracle) database name.
        my $database = $img_lid_blastdb;
        $database =~ s/_lid$//;
        my %args;
        $args{gene_oid} = "query$gene_oid2";
        $args{seq}      = $query_seq;
        $args{mopt}     = "6";                 # '-outfmt 6' for tabular output. (-m 8)
        $args{eopt}     = $maxEvalue;
        if ( $blast_program eq 'blastp' ) {
            $args{db} = "allFaa";
        } else {
            $args{db} = "allFna";
        }
        $args{database}           = $database;
        $args{top_n}              = 10000;
        $args{pgm}                = $blast_program;
        $args{private_taxon_oids} = FindGenesBlast::getPrivateTaxonOids();
        $args{super_user}         = getSuperUser();
        $args{report_file}        = $reportFile if $reportFile ne "";

        #print Dumper(%args);
        #print "LwpHandle---- $blastallm0_server_url <br/>\n";
        webLog(   ">>> Calling '$blastallm0_server_url' database='$database' "
                . "db='allFaa' pgm='$blast_program' reportFile='$reportFile'\n" );
        $cfh = new LwpHandle( $blastallm0_server_url, \%args );
    } else {

        print "Calling blast api<br/>\n" if ($img_ken);
        my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
        my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
        if ( $stdOutFile == -1 ) {

            # close working div but do not clear the data
            printEndWorkingDiv( '', 1 );
            ##$dbh->disconnect();
            printStatusLine( "Error.", 2 );
            WebUtil::webExit(-1);
        }
        print "blast done<br/>\n"                 if ($img_ken);
        print "Reading output $stdOutFile<br/>\n" if ($img_ken);
        $cfh = WebUtil::newReadFileHandle($stdOutFile);

    }

    if ( $reportFile ne "" ) {
        my $qFile;
        while ( my $s = $cfh->getline() ) {
            chomp $s;
            if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                      # contain PID. This has happened.
                                      # - yjlin 20130411
                my ( $junk, $pid ) = split( /=/, $s );
                WebUtil::setBlastPid($pid);
                next;
            }
            if ( $s =~ /\^.report_file / ) {
                my ( $tag, $val ) = split( /\s+/, $s );
                $reportFile = $val;
                webLog("Reading reportFile='$reportFile'\n");
                close $cfh if ($cfh);
                last;
            } elsif ( $s =~ /^\.status / ) {
                my ( $tag, @toks ) = split( /\s+/, $s );
                my $tok_str = join( " ", @toks );
                print "$tok_str<br/>\n";
            } elsif ( $s =~ /^\.qFile / ) {
                my ( $tag, $val ) = split( /\s+/, $s );
                $qFile = $val;
            }
        }
        if ( $qFile ne "" ) {
            FindGenesBlast::waitForResults( $reportFile, $qFile );
        }
        
        webLog("Reading reportFile='$reportFile'\n");
        $cfh = newReadFileHandle( "$common_tmp_dir/$reportFile", "processGenomeBlast" );
    }

    my %done;
    my $count = 0;

    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }

        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );
        #print "processGenomeBlast() qid=$qid<br/>\n";
        #print "processGenomeBlast() sid=$sid<br/>\n";

        #next if $qid eq $sid;
        my $k = "$qid-$sid";
        next if $done{$k} ne "";
        next if $percIdent < $minPercIdent;
        $count++;
        if ( $blast_program eq 'blastn' ) {
            if ( $coord_hash{$sid} eq "" ) {
                $coord_hash{$sid} = $sstart . "_" . $send;
            } else {
                $coord_hash{$sid} .= "__" . $sstart . "_" . $send;
            }
        }

        # TODO double check if there is a reason for this
        #my ( $qid_gene_oid, undef ) = split( /_/, $qid );
        my $qid_gene_oid = $qid;
        my $r            = "$qid_gene_oid\t";

        my $taxon;    # original 'taxon_oid' could be string 'all', so it is
                      # safer to get it from blast output lines
        my $sid_oid;
        if ($taxon_oid eq 'all' && $blast_program eq 'blastn' ) {
            # only all has a "dot" '.' between taxon and scaffold otherwise its a whitespace
#print "sid: $sid<br>\n";            
            
            ( $taxon, $sid_oid ) = split( /\./, $sid, 2 );    #ext_accession
                                                              # format of sid: # taxon_oid dot ext_accession
                                                              # Note: ext_accession itself could contain underscore and dot
             $taxon =~ s/^\>//; #remove '>' in taxon
        } else {                                              # blastp
                                                              # if infile equals Yes, format of sid:
                                                              # taxon_oid DOT assemble_type COLON locus_tag
            $sid_oid = $sid;
        }

        $r .= "$sid_oid\t";
        if ( $taxon_oid eq 'all' && $blast_program eq 'blastn' ) {
            $r .= "$taxon\t";                                 # subj taxon oid
        } else {
            $r .= "$taxon_oid\t";                             # subj taxon oid
        }
        $r .= "$data_type\t";
        $r .= "$percIdent\t";
        $r .= "$qstart\t";
        $r .= "$qend\t";
        $r .= "$sstart\t";
        $r .= "$send\t";
        $r .= "$evalue\t";
        $r .= "$bitScore\t";
        $r .= "$alen\n";

        #print "processGenomeBlast() r=$r<br/>\n";
        push( @$homologRecs_ref, $r );
        $done{$k} = 1;
    }

    $cfh->close();
    WebUtil::resetEnvPath();
    wunlink($tmpQueryFile);
    return ( $count, \%coord_hash );
}

############################################################################
# processReverseOrthologBlast - Mark BBH orthologs in blast.
#   Take top hit to query as marker.
#   BBH is only for faa seqs and blastp
# Inputs:
#   -- reverse_query_sequence: query sequence used in reverse blast,
#      i.e. hit sequence
#   -- taxon_oid: taxon oid for blast db in reverse blast
#      i.e. taxon oid for original query,
############################################################################
sub processReverseOrthologBlast {
    my ( $gene_oid, $reverse_query_sequence, $taxon_oid, $maxEvalue, $minPercIdent, $query_gene_oid, $orthologs_ref,
         $infile_href )
      = @_;

    # debug lines
    my $debug_flag = 0;
    if ( $debug_flag eq 1 ) {
        printEndWorkingDiv();
        print "processReverseOrthologBlast --- query:[$gene_oid]<br>";
        print "processReverseOrthologBlast --- " . "taxon of original query:[$taxon_oid]<br>";
    }

    $taxon_oid = sanitizeInt($taxon_oid);
    $maxEvalue = checkEvalue($maxEvalue);

    # check inputs
    my ( $goid, $dtype, $toid ) = MetaUtil::parseMetaGeneOid($gene_oid);
    if ( $goid eq '' ) {    # gene is from database
        $gene_oid = MetaUtil::sanitizeGeneId3($gene_oid);
    } else {                # gene is from metagenome
        $gene_oid = $goid;
    }

    # db location and check existence
    my ( $db, $dbDir );
    if ( $infile_href->{$taxon_oid} eq 1 ) {
        if ( $sandbox_blast_data_dir ne '' ) {
            $dbDir = $sandbox_blast_data_dir . "/" . $taxon_oid;
        } else {

            # OBSOLETE location
            $dbDir = "$mer_data_dir/$taxon_oid/assembled/blast.data";
        }
        $db = "$dbDir/$taxon_oid.a.faa";
    } else {
        if ( $sandbox_blast_data_dir ne '' ) {
            $dbDir = "$sandbox_blast_data_dir/$taxon_oid";
            $db    = "$dbDir/$taxon_oid" . '.faa';
        } else {
            $dbDir = "$taxon_faa_dir/$taxon_oid.faa.blastdb";
            $db    = "$dbDir/$taxon_oid";
        }
    }
    if ( !( -e $dbDir ) ) {
        webLog("processReverseOrthologBlast: cannot find '$dbDir'\n");
        return;
    }

    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpQueryFile = "$cgi_tmp_dir/g$gene_oid-$taxon_oid.faa";

    if ( $debug_flag eq 1 ) {
        print "processReverseOrthologBlast --- dbDir:[$dbDir]<br>";
        print "processReverseOrthologBlast --- db:[$db]<br>";
        print "processReverseOrthologBlast --- tmpQueryFile:[$tmpQueryFile]<br>";
        print "processReverseOrthologBlast --- " . "reverse_query_sequence:[$reverse_query_sequence]<br>";
    }

    $tmpQueryFile = checkTmpPath($tmpQueryFile);
    my $wfh = newWriteFileHandle( $tmpQueryFile, "processReverseOrthologBlast" );
    print $wfh ">$gene_oid\n";
    print $wfh "$reverse_query_sequence\n";
    close $wfh;

    ## New BLAST
    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p blastp -d $db -e $maxEvalue -F 'm S' -b 250 "
      . " -m 8 -i $tmpQueryFile "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013
    webLog "+ $cmd\n";

    WebUtil::unsetEnvPath();

    #    if ( $blast_wrapper_script ne "" ) {
    #        $cmd = "$blast_wrapper_script $cmd";
    #    }

    print "Calling blast api<br/>\n" if ($img_ken);
    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
    if ( $stdOutFile == -1 ) {

        # close working div but do not clear the data
        printEndWorkingDiv( '', 1 );
        ##$dbh->disconnect();
        printStatusLine( "Error.", 2 );
        WebUtil::webExit(-1);
    }
    print "blast done<br/>\n"                 if ($img_ken);
    print "Reading output $stdOutFile<br/>\n" if ($img_ken);
    my $cfh = WebUtil::newReadFileHandle($stdOutFile);

    my %done;
    my $count    = 0;
    my $hitCount = 0;
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        print "processReverseOrthologBlast BLAST OUTPUT:[$s]<br>"
          if ( $debug_flag eq 1 );

        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }
        my ( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps, $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
          split( /\t/, $s );
        $count++;
        my ( $qid_gene_oid, undef ) = split( /_/, $qid );
        my ( $sid_gene_oid, undef ) = split( /_/, $sid );
        if ( $qid_gene_oid eq $sid_gene_oid ) {
            ## Should not get here.
            warn( "processReverseOrthologBlast: $qid_gene_oid qid=sid same " . "for taxon_oid=$taxon_oid\n" );
            next;
        }
        if ( $qid_gene_oid eq $query_gene_oid ) {
            ## Should not get here.
            warn(   "processReverseOrthologBlast: $qid_gene_oid qid same "
                  . "for query_gene=$query_gene_oid in taxon_oid=$taxon_oid\n" );
            next;
        }
        next if $percIdent < $minPercIdent;
        ## Look at first hit that matches the percent identity constraints
        if ( $sid_gene_oid eq $query_gene_oid ) {
            $orthologs_ref->{$qid_gene_oid} = 1;
            $hitCount++;
        }
        last;
    }
    close $cfh;
    WebUtil::resetEnvPath();
    wunlink($tmpQueryFile);
    return $hitCount;
}

############################################################################
# printHomologFooter - Print homolog footer with standard button
#   to add to gene cart, select all, clear all, phylo distribution, etc.
############################################################################
sub printHomologFooter {
    my ( $dbh, $gene_oid ) = @_;

    my $name = "_section_GeneCartStor_addToGeneCart";
    print submit(
                  -name  => $name,
                  -value => "Add Selections To Gene Cart",
                  -class => "meddefbutton"
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllCheckBoxes(1)', class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    print "<br/>\n";
}

1;
