############################################################################
# FindGenesBlast.pm - Formerly geneSearchBlast.pl
#   This handles the BLAST option under the "Find Genes" menu option.
#  --es 07/07/2005
#
# $Id: FindGenesBlast.pm 33949 2015-08-09 07:37:16Z jinghuahuang $
############################################################################
package FindGenesBlast;
my $section = "FindGenesBlast";

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use ScaffoldPanel;
use WebConfig;
use WebUtil;
use LwpHandle;
use OracleUtil;
use Mblast;
use GenomeListFilter;
use TreeViewFrame;
use HtmlUtil;
use MerFsUtil;
use MetaGeneTable;
use MetaUtil;
use QueryUtil;
use Command;
use GenomeListJSON;
use HTML::Template;

$| = 1;

my $env                    = getEnv();
my $main_cgi               = $env->{main_cgi};
my $section_cgi            = "$main_cgi?section=$section";
my $verbose                = $env->{verbose};
my $base_dir               = $env->{base_dir};
my $user_restricted_site   = $env->{user_restricted_site};
my $no_restricted_message  = $env->{no_restricted_message};
my $web_data_dir           = $env->{web_data_dir};
my $all_faa_blastdb        = $env->{all_faa_blastdb};
my $all_fna_blastdb        = $env->{all_fna_blastdb};
my $img_lid_blastdb        = $env->{img_lid_blastdb};
my $env_blast_dbs          = $env->{env_blast_dbs};
my $aa_blast_data_dir      = "$web_data_dir/all.blastdb";
my $na_blast_data_dir      = "$web_data_dir/all.fna.blastdbs";
my $blastall_bin           = $env->{blastall_bin};
my $taxon_faa_dir          = $env->{taxon_faa_dir};
my $taxon_fna_dir          = $env->{taxon_fna_dir};
my $taxon_lin_fna_dir      = $env->{taxon_lin_fna_dir};
my $snp_blast_data_dir     = $env->{snp_blast_data_dir};
my $sandbox_blast_data_dir = $env->{sandbox_blast_data_dir};
my $taxon_reads_fna_dir    = $env->{taxon_reads_fna_dir};
my $cgi_tmp_dir            = $env->{cgi_tmp_dir};
my $cgi_url                = $env->{cgi_url};
my $common_tmp_dir         = $env->{common_tmp_dir};
my $blast_q_dir            = $env->{blast_q_dir};
my $include_metagenomes    = $env->{include_metagenomes};
my $img_internal           = $env->{img_internal};
my $img_er                 = $env->{img_er};
my $img_ken                = $env->{img_ken};
my $tmp_dir                = $env->{tmp_dir};
my $enable_workspace       = $env->{enable_workspace};
my $workspace_dir          = $env->{workspace_dir};
my $enable_mybin           = $env->{enable_mybin};
my $mybin_blast_dir        = $env->{mybin_blast_dir};
my $blastallm0_server_url  = $env->{blastallm0_server_url};
my $default_timeout_mins   = $env->{default_timeout_mins};
my $blast_a_flag           = $env->{blast_a_flag};
$blast_a_flag = "-a 16" if $blast_a_flag eq "";

my $cgi_blast_cache_enable = $env->{cgi_blast_cache_enable};
my $blast_wrapper_script   = $env->{blast_wrapper_script};

my $blast_max_genome = $env->{blast_max_genome};
my $mer_data_dir = $env->{mer_data_dir};

my $max_merfs_metagenome_selections = 20;

my $OFFSET = 6000;    # offset range to get list of known genes

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    timeout( 60 * 40 );

    my $page = param("page");
    if ( $page eq "TrueSeqCoords" ) {
        getTrueSeqCoords();
    } elsif ( paramMatch("ffgGeneSearchBlast") ne "" ) {
        printGeneSearchBlastResults();
    } else {
        printGeneSearchBlastForm($numTaxon);
    }
}

############################################################################
# validateMerfsTaxonNumber
############################################################################
sub validateMerfsTaxonNumber {
    my ( @taxon_oids ) = @_;

    if ($include_metagenomes) {
        my $dbh = dbLogin();
        my %mer_fs_taxons = MerFsUtil::fetchTaxonsInFile( $dbh, @taxon_oids );
        my @merfs_taxons = keys %mer_fs_taxons;
        if (scalar(@merfs_taxons) > $max_merfs_metagenome_selections ) {
            webError("You have selected more than $max_merfs_metagenome_selections MER-FS metagenomes.");
            return;
        }
    }
}

#
# gets scaffold seq file name from db
#
sub getSeqFilename {
    my ( $dbh, $seq_ext ) = @_;
    my $sql = qq{
        select seq_file 
        from scaffold
        where ext_accession = ?        
    };

    my @a      = ($seq_ext);
    my $cur    = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($name) = $cur->fetchrow();
    $cur->finish();

    return ( $name, $seq_ext );
}

#
# gets scaffold seq file name from db
# not used currently
sub getSeqFilename2 {
    my ( $dbh, $gene_oid ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select s.seq_file 
        from gene g, scaffold s
        where g.scaffold = s.scaffold_oid
        and g.gene_oid = ?     
        $rclause
        $imgClause
    };

    my @a      = ($gene_oid);
    my $cur    = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($name) = $cur->fetchrow();
    $cur->finish();
    return $name;
}

#
# gets scaffold seq file name from db
#
sub getSeqFilename3 {
    my ( $dbh, $scaffold_oid ) = @_;

    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');
    my $sql       = qq{
        select s.seq_file, s.ext_accession, s.taxon
        from scaffold s
        where s.scaffold_oid = ?
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my ( $name, $ext, $taxon ) = $cur->fetchrow();
    $cur->finish();

    #    my $seq = WebUtil::getScaffoldSeq($dbh, $scaffold_oid, 0, 0 );
    #    my $fh = newWriteFileHandle("$tmp_dir/$name");
    #    print $fh ">$ext\n";
    #    print $fh "$seq\n";
    #    close $fh;

    return ( "$taxon" . ".fna", $ext );
}

#
# find the genes start and end coord
#
sub getTrueSeqCoords {
    my ($query_aref) = @_;
    my @query = param("coords");
    if ( $#query < 0 ) {
        @query = @$query_aref;
    }

    my ( $gene_oid, $qstart, $qend, $taxon_oid, $sstart, $send, $frame, $scaffold_id, $bit_score, $evalue );

    my $dbh = dbLogin();

    my @coords;
    if ($img_internal) {
        print "<p>\n";
        print "query gene start end, subject taxon start end frame<br/>\n";
    }
    foreach my $line (@query) {
        ( $gene_oid, $qstart, $qend, $taxon_oid, $sstart, $send, $frame, $scaffold_id, $bit_score, $evalue ) =
          split( /,/, $line );

        my ( $scaffold_taxon_id, $scaffold_ext ) = split( /\./, $scaffold_id );

        my $knowngenes_href = getTaxonKnowGenes( $dbh, $taxon_oid, $sstart, $send, $scaffold_ext );

        if ($img_internal) {
            print "$line <br/>\n";
        }

        #or my $file = "$taxon_fna_dir/$taxon_oid.fna";
        my $file = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";

        my ( $start, $end, $x ) = getSeq( $sstart, $send, $file, $knowngenes_href, $scaffold_ext );

        if ($img_internal) {
            print "&nbsp;&nbsp; <b>new gene true coords: $start, $end </b>" . "<br/><br/> \n";
        }
        push( @coords, "$line,$start,$end" );
    }
    if ($img_internal) {
        print "</p>\n";
    }

    #$dbh->disconnect();

    return \@coords;
}

#
# find the genes start and end coord
#
# for blastx from scaffold view
sub getTrueSeqCoords2 {
    my ( $que_aref, $sub_aref, $scaffold_oid, $query_orig_start_coord, $query_orig_end_coord ) = @_;

    my ( $scaffold_oid, $qstart, $qend, $taxon_oid, $sstart, $send, $frame, $sgene_oid, $bit_score, $evalue );

    my $dbh = dbLogin();

    my @coords;
    if ($img_internal) {

        # subject gene is the hit gene
        print "<p>\n";
        print "orig query start $query_orig_start_coord<br/>\n";
        print "orig query end $query_orig_end_coord<br/>\n";
        print "query scaffold start end, subject taxon start end frame" . " gene bit-score evalue<br/>\n";
    }
    for ( my $i = 0 ; $i <= $#$que_aref ; $i++ ) {
        my $qline = $que_aref->[$i];
        my $sline = $sub_aref->[$i];
        ( $scaffold_oid, $qstart, $qend ) = split( /,/, $qline );

        my $query_taxon_oid = getTaxonOid2( $dbh, $scaffold_oid );

        # now offset the coords of  query  seq, since
        # the seq was  pasted into a form, its 1 to n
        # but needs to be offset from its true location
        # via scaffold view
        if ($img_internal) {
            print qq{
            offset qstart = $query_orig_start_coord + $qstart - 1; <br/>
            offset qend   = $query_orig_start_coord + $qend  - 1;  <br/>
                };
        }

        #        if ( $qstart > $qend ) {
        #            $qstart = $query_orig_end_coord - $qstart + 1;
        #            $qend   = $query_orig_start_coord + $qend - 1;
        #
        #        } else {
        $qstart = $query_orig_start_coord + $qstart - 1;
        $qend   = $query_orig_start_coord + $qend - 1;

        #}
        $qline = "$scaffold_oid,$qstart,$qend ";

        ( $taxon_oid, $sstart, $send, $frame, $sgene_oid, $bit_score, $evalue ) = split( /,/, $sline );

        my $knowngenes_href = getTaxonKnowGenes3( $dbh, $sstart, $send, $scaffold_oid );

        my ( $filename, $contig ) = getSeqFilename3( $dbh, $scaffold_oid );

        my $file = "$web_data_dir/taxon.fna/$filename";

        my ( $start, $end, $x ) = getSeq( $qstart, $qend, $file, $knowngenes_href, $contig );
        if ($img_internal) {
            print "$qline, $sline<br/>\n";
            print "&nbsp;&nbsp; <b>new gene true coords: $start, $end </b>" . "<br/><br/> \n";
        }
        push( @coords, "$qline,$sline,$start,$end" );
    }
    if ($img_internal) {
        print "</p>\n";
    }

    #$dbh->disconnect();

    return \@coords;
}

#
# gets taxon oid from gene oid
#
sub getTaxonOid {
    my ( $dbh, $gene_oid ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.taxon
        from gene g
        where g.gene_oid = ?  
        $rclause
        $imgClause
    };

    my @a           = ($gene_oid);
    my $cur         = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

#
# gets taxon oid from scaffold oid
#
sub getTaxonOid2 {
    my ( $dbh, $scaffold_oid ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.taxon
        from gene g 
        where g.scaffold = ?
        $rclause
        $imgClause
        and rownum < 2
    };
    my $cur = execSql( $dbh, $sql, $verbose, $scaffold_oid );
    my ($taxon_oid) = $cur->fetchrow();
    $cur->finish();
    return $taxon_oid;
}

#
# find the genes start and end coord
#
# for blastx from scaffold view for all db search
sub getTrueSeqCoords3 {
    my ( $que_aref, $sub_aref, $scaffold_oid, $query_orig_start_coord, $query_orig_end_coord ) = @_;

    my ( $scaffold_oid, $qstart, $qend, $sstart, $send, $frame, $sgene_oid, $bit_score, $evalue );

    my $dbh = dbLogin();

    my @coords;
    if ($img_internal) {

        # subject gene is the hit gene
        print "<p>\n";
        print "orig query start $query_orig_start_coord<br/>\n";
        print "orig query end $query_orig_end_coord<br/>\n";
        print "query scaffold, start, end, subject start end frame" . " gene bit-score evalue<br/>\n";
    }
    for ( my $i = 0 ; $i <= $#$que_aref ; $i++ ) {
        my $qline = $que_aref->[$i];
        my $sline = $sub_aref->[$i];
        ( $scaffold_oid, $qstart, $qend ) = split( /,/, $qline );

        #print "getTrueSeqCoords3() qline: $qline<br/>\n";

        my $query_taxon_oid;
        if ( isInt($scaffold_oid) ) {
            my $query_taxon_oid = getTaxonOid2( $dbh, $scaffold_oid );
        } else {
            my ( $txid, $dt, $scfid ) = split( / /, $scaffold_oid );
            $query_taxon_oid = $txid;
        }

        # now offset the coords of  query  seq, since
        # the seq was  pasted into a form, its 1 to n
        # but needs to be offset from its true location
        # via scaffold viewer
        if ($img_internal) {
            print qq{
                offset qstart = $query_orig_start_coord + $qstart - 1; <br/>
                offset qend   = $query_orig_start_coord + $qend - 1;  <br/>
            };
        }

        #        if ( $qstart > $qend ) {
        #            $qstart = $query_orig_end_coord - $qstart + 1;
        #            $qend   = $query_orig_start_coord + $qend - 1;
        #
        #        } else {
        $qstart = $query_orig_start_coord + $qstart - 1;
        $qend   = $query_orig_start_coord + $qend - 1;

        #        }
        $qline = "$scaffold_oid,$qstart,$qend ";

        ( $sstart, $send, $frame, $sgene_oid, $bit_score, $evalue ) =
          split( /,/, $sline );

        my $taxon_oid = getTaxonOid( $dbh, $sgene_oid );

        my $knowngenes_href = getTaxonKnowGenes3( $dbh, $sstart, $send, $scaffold_oid );

        my ( $filename, $contig ) = getSeqFilename3( $dbh, $scaffold_oid );

        my $file = "$web_data_dir/taxon.fna/$filename";

        my ( $start, $end, $x ) = getSeq( $qstart, $qend, $file, $knowngenes_href, $contig );
        if ($img_internal) {
            print "$qline, $sline<br/>\n";
            print "&nbsp;&nbsp; <b>new gene true coords: $start, $end </b>" . "<br/><br/> \n";
        }
        push( @coords, "$qline,$taxon_oid,$sline,$start,$end" );
    }
    if ($img_internal) {
        print "</p>\n";
    }

    #$dbh->disconnect();

    return \@coords;
}

# subject taxon
# subject $start
# subject end
sub getTaxonKnowGenes {
    my ( $dbh, $taxon_oid, $start, $end, $scaffold_ext ) = @_;

    # see getSeq() too!
    my $offset = $OFFSET;

    my $s = $start - $offset;
    my $e = $end + $offset;
    if ( $start > $end ) {
        $s = $end - $offset;
        $e = $start + $offset;
    }

    # I know the start < end  and stran indicates the reverse
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.start_coord, g.end_coord, g.strand
        from gene g, scaffold s
        where g.taxon = ?
        and g.scaffold = s.scaffold_oid
        and s.ext_accession = ?
        and (g.start_coord between ? and ?
        or g.end_coord between ? and ?)
        $rclause
        $imgClause
    };

    my %results;    # start => end
    my @a = ( $taxon_oid, $scaffold_ext, $s, $e, $s, $e );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $start_coord, $end_coord, $stran ) = $cur->fetchrow();
        last if ( $start_coord eq "" );
        $results{$start_coord} = $end_coord;
    }
    $cur->finish();
    return \%results;
}

sub getTaxonKnowGenes2 {
    my ( $dbh, $taxon_oid, $start, $end, $gene_oid ) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.scaffold
        from gene g
        where g.gene_oid = ?
        $rclause
        $imgClause
    };
    my @a             = ($gene_oid);
    my $cur           = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($scaffold_id) = $cur->fetchrow();
    $cur->finish();

    # see getSeq() too!
    my $offset = $OFFSET;

    my $s = $start - $offset;
    my $e = $end + $offset;
    if ( $start > $end ) {
        $s = $end - $offset;
        $e = $start + $offset;
    }

    # I know the start < end  and stran indicates the reverse
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.start_coord, g.end_coord, g.strand
        from gene g
        where g.taxon = ?
        and g.scaffold = ?
        and (g.start_coord between ? and ?
        or g.end_coord between ? and ?)
        $rclause
        $imgClause
    };

    my %results;    # start => end
    my @a = ( $taxon_oid, $scaffold_id, $s, $e, $s, $e );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $start_coord, $end_coord, $stran ) = $cur->fetchrow();
        last if ( $start_coord eq "" );
        $results{$start_coord} = $end_coord;
    }
    $cur->finish();
    return \%results;
}

sub getTaxonKnowGenes3 {
    my ( $dbh, $start, $end, $scaffold_id ) = @_;

    # see getSeq() too!
    my $offset = $OFFSET;

    my $s = $start - $offset;
    my $e = $end + $offset;
    if ( $start > $end ) {
        $s = $end - $offset;
        $e = $start + $offset;
    }

    # I know the start < end  and stran indicates the reverse
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql       = qq{
        select g.start_coord, g.end_coord, g.strand
        from gene g
        where g.scaffold = ?
        and (g.start_coord between ? and ?
        or g.end_coord between ? and ?)
        $rclause
        $imgClause
    };

    my %results;    # start => end
    my @a = ( $scaffold_id, $s, $e, $s, $e );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $start_coord, $end_coord, $stran ) = $cur->fetchrow();
        last if ( $start_coord eq "" );
        $results{$start_coord} = $end_coord;
    }
    $cur->finish();
    return \%results;
}

# check to see if the new coord is within another known gene
sub isWithInGene {
    my ( $coord, $knowngenes_href ) = @_;
    my $within = 0;
    foreach my $start ( sort keys %$knowngenes_href ) {
        my $end = $knowngenes_href->{$start};
        if ( $coord >= $start && $coord <= $end ) {
            $within = 1;
            last;
        }
    }

    return $within;
}

# find genes start and end coord using fna file
# help method for getTrueSeqCoords()
# start coord
# end coord
# fna file
# list of genomes' known genes start and end
# $contig - some files have multiple contigs in one file
sub getSeq {
    my ( $start, $end, $file, $knowngenes_href, $contig ) = @_;

    if ($img_ken) {
        print "<p> contig $contig getSeq: $file </p>\n";
    }

    # how far to walk up the line
    # also see getTaxonKnowGenes()
    my $offset = $OFFSET;

    # number of dna char to read next
    my $charstep = 3;

    my $fh = newReadFileHandle($file);

    my $seq = "";

    # number of characters read so far
    my $count = 0;

    # read file until I find the right contig header
    my $found = 0;
    while ( my $line = $fh->getline() ) {
        chomp $line;
        if ( $line =~ /$contig/ ) {
            $found = 1;
            last;
        }
    }
    if ( $found == 0 ) {
        webError("Cannot find $contig in file $file");
    }

    # read seq from 1 to eol - end of line is greater than end and start
    while ( my $line = $fh->getline() ) {
        chomp $line;
        next if ( $line eq "" );
        next if ( $line =~ /^>/ );

        my $len = length($line);
        $count += $len;
        $seq .= $line;
        if ( $count > ( $start + $offset ) && $count > ( $end + $offset ) ) {
            last;
        }
    }
    close $fh;

    my $orig_seq  = "";
    my $new_start = -1;
    my $new_end   = -1;
    if ( $start < $end ) {
        my $range = $end - $start + 1;

        #$orig_seq = substr( $seq, $start - 1, $range );

        # sc check
        # sc .. sc +2 = ATG TTG GTG
        my $len = length($seq);
        my $i   = 0;
        for ( $i = 0 ; $i <= $len ; $i = $i + $charstep ) {

            # get up 10 chars
            my $x = substr( $seq, $start - 1 - $i, 10 );
            my $test = substr( $x, 0, 3 );
            if ( $test eq "ATG" || $test eq "TTG" || $test eq "GTG" ) {

                $new_start = $start - $i;
                if ( $new_start < 1 ) {
                    $new_start = "1*";
                    last;
                }
                if ( isWithInGene( $new_start, $knowngenes_href ) ) {
                    $new_start = $new_start . "*";
                }
                last;
            }
        }

        # ec check 'TAG'||'TGA'||'TAA'
        # ec - 2 .. ec
        my $i = 0;
        for ( $i = 0 ; $i <= $len ; $i = $i + $charstep ) {

            # get up 10 chars
            my $x = substr( $seq, $end - 1 - 2 + $i, 10 );
            my $test = substr( $x, 0, 3 );

            #print "here <br/>\n";
            if ($img_ken) {
                print "============ $test $i $end <br/>";
                print "$x <br/>";
            }

            if ( $test eq "TAG" || $test eq "TGA" || $test eq "TAA" ) {
                $new_end = $end + $i;
                if ( isWithInGene( $new_end, $knowngenes_href ) ) {
                    $new_end = $new_end . "*";
                }
                last;
            }
        }

    } else {

        # check location
        my $range = $start - $end + 1;

        #$orig_seq = substr( $seq, $end - 1, $range );
        #$orig_seq = reverse($orig_seq);
        #$orig_seq =~ tr/actgACTG/tgacTGAC/;

        # sc check
        # sc .. sc + 2 (sc .. sc- 2 if not reversed) should be
        # CAT || CAA || CAC
        # to be the begining of the gene

        my $len = length($seq);
        my $i   = 0;

        for ( $i = 0 ; $i <= $len ; $i = $i + $charstep ) {
            my $x = substr( $seq, $start - 1 - 2 + $i, 10 );

            #$x = reverse($x);
            #$x =~ tr/actgACTG/tgacTGAC/;

            # sc check
            # sc + 2 (- 2 if not reversed) should be
            # CAT || CAA || CAC
            # to be the begining of the gene
            my $test = substr( $x, 0, 3 );
            if ($img_ken) {
                print "looking at $start - 1 + $i  ==> $test $i $x  <br/>";
            }

            #if ( $test eq "CAT" || $test eq "CAA" || $test eq "CAC" ) {
            if ( $test eq "CAT" || $test eq "CAA" || $test eq "CAC" ) {

                #if ( $test eq "ATG" || $test eq "TTG" || $test eq "GTG" ) {
                $new_start = $start + $i;
                if ( isWithInGene( $new_start, $knowngenes_href ) ) {
                    $new_start = $new_start . "*";
                }
                last;
            }
        }

        # now check ec
        # ec - 2
        my $i = 0;
        for ( $i = 0 ; $i <= $len ; $i = $i + $charstep ) {
            my $x = substr( $seq, $end - 1 - $i, 10 );

            #$x = reverse($x);
            #$x =~ tr/actgACTG/tgacTGAC/;

            my $test = substr( $x, 0, 3 );

            if ( $test eq "CTA" || $test eq "TCA" || $test eq "TTA" ) {

                #if($test eq "CTA" || $test eq "TCA" || $test eq "TTA") {
                #if ( $test eq "TAG" || $test eq "TGA" || $test eq "TAA" ) {
                $new_end = $end - $i;
                if ( $new_end < 1 ) {
                    $new_end = "1*";
                    last;
                }
                if ( isWithInGene( $new_end, $knowngenes_href ) ) {
                    $new_end = $new_end . "*";
                }
                last;
            }
        }

    }

    return ( $new_start, $new_end, $orig_seq );
}

############################################################################
# geneSearchBlastForm_old - Basic BLAST form on gene search page.
############################################################################
sub printGeneSearchBlastForm_old {
    my $templateFile = "$base_dir/findGenesBlast.html";
    my $rfh          = newReadFileHandle( $templateFile, "printGeneSearchBlastForm" );
    my $dbh          = dbLogin();

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$main_cgi/g;
        if ( $s =~ /__genomeSelectionMessage__/ ) {
            printGenomeSelectionMessage( );            
        } elsif ( $s =~ /__metaChoice__/ ) {
            HtmlUtil::printMetaDataTypeChoice();
        } elsif ( $s =~ /__genomeListFilter__/ ) {
            my $myBinAllowed = 0;
            if ($enable_mybin) {
                my $contact_oid = getContactOid();
                if ( canEditBin( $dbh, $contact_oid ) ) {
                    $myBinAllowed = 1;
                }
            }
            #print "myBinAllowed: $myBinAllowed<br/>\n";
            GenomeListFilter::appendGenomeListFilter( $dbh, '', 2, 'imgBlastDb', '', '', 1, $myBinAllowed );
        } elsif ( $s =~ /__hint__/ ) {
            printPageHint();
        } elsif ( $s =~ /__userRestrictedBlastMessage__/ ) {
            if ( $user_restricted_site && !$no_restricted_message ) {
                #printUserRestrictedBlastMessage( );
            }
        } elsif ( $s =~ "<h1>BLAST</h1>" ) {
            my $text = "Blast is used to find sequence similarity in selected genomes";
            WebUtil::printHeaderWithInfo( "BLAST", $text, "show description", "Blast", 0, "Blast.pdf" );
        } else {
            print "$s\n";
        }
    }
    close $rfh;

    #$dbh->disconnect();
}

sub printGeneSearchBlastForm {
    my ( $numTaxon, $useGenomeSet, $submitNameText, $submitOnClickText ) = @_;
    
    my $taxon_oid = param('taxon_oid');
    my $domain = param('domain');    
    my $templateFile = "$base_dir/findGenesBlast_new.html";
    my $rfh = newReadFileHandle( $templateFile, "printGeneSearchBlastForm" );

    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$main_cgi/g;
        if ( $s =~ /__genomeSelectionMessage__/ ) {
            printGenomeSelectionMessage( $useGenomeSet );            
        } elsif ( $s =~ /__metaChoice__/ ) {
            if ( $useGenomeSet ) {
                HtmlUtil::printMetaDataTypeChoice('_b');
            } else {
                HtmlUtil::printMetaDataTypeChoice();
            }
        } elsif ( $s =~ /__genomeListFilter__/ ) {

            if ( $useGenomeSet ) {
                print submit(
                    -name    => $submitNameText,
                    -value   => "Run Blast",
                    -class   => "meddefbutton",
                    -onClick => $submitOnClickText
                );
            } else {
                my $hideViruses = getSessionParam("hideViruses");
                $hideViruses = ( $hideViruses eq "" || $hideViruses eq "Yes" ) ? 0 : 1;
                my $hidePlasmids = getSessionParam("hidePlasmids");
                $hidePlasmids = ( $hidePlasmids eq "" || $hidePlasmids eq "Yes" ) ? 0 : 1;
                my $hideGFragment = getSessionParam("hideGFragment");
                $hideGFragment = ( $hideGFragment eq "" || $hideGFragment eq "Yes" ) ? 0 : 1;

                my $xml_cgi = $cgi_url . '/xml.cgi';
                $include_metagenomes = 0 if ( $include_metagenomes eq "" );
                my $template = HTML::Template->new( filename => "$base_dir/genomeJson.html" );
                $template->param( isolate             => 1 );
                $template->param( gfr                 => $hideGFragment );
                $template->param( pla                 => $hidePlasmids );
                $template->param( vir                 => $hideViruses );
                $template->param( isolate             => 1 );
                $template->param( all                 => 1 );
                $template->param( cart                => 1 );
                $template->param( xml_cgi             => $xml_cgi );
                $template->param( prefix              => '' );
                $template->param( include_metagenomes => $include_metagenomes );
    
                # prefix
                $template->param( prefix => '' );
                print $template->output;
    
                GenomeListJSON::printHiddenInputType( 'FindGenesBlast', 'ffgGeneSearchBlast' );
                GenomeListJSON::printMySubmitButtonBlast( "go", 'ffgGeneSearchBlast', "Run BLAST", '', 'FindGenesBlast',
                    'ffgGeneSearchBlast', 'smdefbutton' );
            }

        } elsif ( $s =~ /__hint__/ ) {
            printPageHint( $useGenomeSet );
        } elsif ( $s =~ /__userRestrictedBlastMessage__/ ) {
            if ( $user_restricted_site && !$no_restricted_message ) {
                #printUserRestrictedBlastMessage( );
            }
        } elsif ( $s =~ "<h1>BLAST</h1>" ) {
            my $text = "Blast is used to find sequence similarity in selected genomes";
            WebUtil::printHeaderWithInfo( "BLAST", $text, "show description", "Blast", 0, "Blast.pdf" );
        } else {
            print "$s\n";
        }
    }
    close $rfh;
    
    if ( !$useGenomeSet ) {
        if ($taxon_oid) {
            GenomeListJSON::preSelectGenome($taxon_oid, $domain);
        } elsif ($numTaxon) {
            GenomeListJSON::showGenomeCart($numTaxon);
        }
    }
}

# custom submit to stop js min checking
#
sub printMySubmitButton2 {
    my ( $id, $name, $value, $title, $section, $page, $class ) = @_;

    print "<input type='submit' ";
    print qq{ id="$id" } if ( $id ne '' );
    if ( $class ne '' ) {
        print qq{ class="$class" };
    } else {
        print qq{ class="meddefbutton" };
    }
    print qq{ value="$value" } if ( $value ne '' );
    print qq{ name="$name" }   if ( $name  ne '' );
    print qq{ title="$title" } if ( $title ne '' );
    print qq{ >};
}

############################################################################
# printGeneSearchBlastResults
############################################################################
sub printGeneSearchBlastResults {
    my ( $genomes_ref, $msg ) = @_;

    my $blast_program = param("blast_program");
    my $evalue = param("blast_evalue");
    my $fasta  = param("fasta");
    if ( blankStr($fasta) ) {
        webError("Query sequence not specified.");
    }
    if ( $fasta !~ /[a-zA-Z]+/ ) {
        webError("Query sequence should have letter characters.");
    }
    
    my @imgBlastDbs;
    if ( $genomes_ref && scalar(@$genomes_ref) > 0 ) {
        @imgBlastDbs = @$genomes_ref;
    }
    else {
        @imgBlastDbs = param('genomeFilterSelections');
        if ($#imgBlastDbs < 0) {
             @imgBlastDbs = OracleUtil::processTaxonSelectionParam("imgBlastDb");
        }
        #if ($img_ken) {
        #    print "<p>\n";
        #    print Dumper \@imgBlastDbs;
        #    print "<br>\n";
        #} 
    }
                    
    my @taxon_oids;
    my @readDbs;
    my @mybinDbs;
    for my $i (@imgBlastDbs) {
        if ( isInt($i) ) {
            push( @taxon_oids, $i );
        } elsif ( $i =~ /^snp_/ ) {
            push( @readDbs, $i );
        } elsif ( $i =~ /^readsDb_/ ) {
            push( @readDbs, $i );
        } elsif ( $i =~ /^bin_/ ) {
            push( @mybinDbs, $i );
        }
    }

    my $nTaxons   = @taxon_oids;
    my $nReadDbs  = @readDbs;
    my $nMybinDbs = @mybinDbs;

    my $all;
    if ( $nTaxons <= 0 && $nReadDbs <= 0 && $nMybinDbs <= 0 ) {
        $all = 1;
    }    
    # if user selected more than 100 genomes use all feature instead
    if ($#imgBlastDbs > $blast_max_genome) {
        $all = 1;
    }
    #print "printGeneSearchBlastResults() all=$all<br/>\n";

    if ( ! $all ) {
        validateMerfsTaxonNumber(@taxon_oids);
    }

    print "<h1>Blast Results</h1>\n";
    print "<p>\n";
    print "Program: " . $blast_program ."<br/>\n";
    print "E-value: " . $evalue ."<br/>\n";
    if ( $all ) {
        print qq{
            <font color='red'>
                <u>All isolate genomes</u> in IMG (no selection or over $blast_max_genome genomes selected)
            </font>
            <br/>\n
        };
    }
    else {
        if ( $genomes_ref && scalar(@$genomes_ref) > 0 && $msg ) {
            print $msg;
        }
        else {
            print "Selected Genomes: " . scalar(@taxon_oids) . "<br/>\n";            
        }
    }
    print "</p>\n";

    if ( $blast_program eq "tblastn" || $blast_program eq "blastn" ) {
        if ($all) {
            if ($cgi_blast_cache_enable) {
                HtmlUtil::cgiCacheInitialize($section);
                HtmlUtil::cgiCacheStart() or return;
            }
            printGeneSearchDnaBlastForAll();
        } elsif ( $nTaxons > 0 ) {
            if ($cgi_blast_cache_enable) {
                HtmlUtil::cgiCacheInitialize($section);
                HtmlUtil::cgiCacheStart() or return;
            }
            printGeneSearchBlastForTaxons( \@taxon_oids );
        } elsif ( $nReadDbs > 0 ) {
            if ($cgi_blast_cache_enable) {
                HtmlUtil::cgiCacheInitialize($section);
                HtmlUtil::cgiCacheStart() or return;
            }
            printEnvBlastForDbs( \@readDbs );
        } elsif ( $nMybinDbs > 0 ) {
            # TODO my bins -ken
            printEnvBlastForDbs( \@mybinDbs );
        }
        HtmlUtil::cgiCacheStop() if ($cgi_blast_cache_enable);

    } else {
        # blastx uses 1 - all, 2 - select taxons, 3 genome cart
        # from scaffold viewer - missing gene fetaure  number 2
        if ($all) {
            if ($cgi_blast_cache_enable) {
                HtmlUtil::cgiCacheInitialize($section);
                HtmlUtil::cgiCacheStart() or return;
            }
            printGeneSearchProteinBlastForAll();
            HtmlUtil::cgiCacheStop() if ($cgi_blast_cache_enable);
        } elsif ( $nTaxons > 0 ) {
            if ($cgi_blast_cache_enable) {
                HtmlUtil::cgiCacheInitialize($section);
                HtmlUtil::cgiCacheStart() or return;
            }
            printGeneSearchBlastForTaxons( \@taxon_oids );
            HtmlUtil::cgiCacheStop() if ($cgi_blast_cache_enable);
        } elsif ( $nReadDbs > 0 ) {
            webError("Read databases do not suppport proteins.");
        } elsif ( $nMybinDbs > 0 ) {
            # TODO my bins -ken
            #webError("My bins databases do not suppport proteins yet.");
            printEnvBlastForDbs( \@mybinDbs, 1 );
        }
    }

}

############################################################################
# flushRecs - Flush a batch of gene results
#   Inputs:
#     dbh - database handle
#     gene_oid_str - gene object identifer string, comma separated
#     blastRec_ref - reference to BLAST record results
############################################################################
sub flushRecs {
    my ( $dbh, $gene_oid_str, $blastRec_ref ) = @_;
    return if blankStr($gene_oid_str);

    my ($rclause) = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select g.gene_oid, g.locus_tag, g.gene_display_name, 
          tx.genus, tx.species
        from gene g, taxon tx
        where g.taxon = tx.taxon_oid
        and g.gene_oid in( $gene_oid_str )
        $rclause
        $imgClause
        order by g.gene_oid
   };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $gene_display_name, $genus, $species ) = $cur->fetchrow();
        last if !$gene_oid;

        my ( $percIdent, $evalue, $bitScore ) =
          split( /\t/, $blastRec_ref->{$gene_oid} );
        print "<input type='checkbox' name='gene_oid' value='$gene_oid' />\n";
        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        print alink( $url, $gene_oid ) . " ";
        print "<font color='green'>\n";
        print "evalue=$evalue ${percIdent}% score=$bitScore";
        print "</font>\n";
        print "<i>" . escHtml($locus_tag) . "</i> ";
        print escHtml($gene_display_name) . " ";
        print escHtml("\[$genus $species\]");
        print "<br/>\n";
    }
    $cur->finish();
}

############################################################################
# printGeneSearchProteinBlastForAll - Run BLAST for all IMG genes,
#   single database version.
#     Inputs:
#        fasta - FASTA sequence
#        evalue - max. evalue cutoff
############################################################################
sub printGeneSearchProteinBlastForAll {
    my ($fasta) = @_;
    if ( !defined($fasta) ) {
        $fasta = param("fasta");
    }

    my $evalue = param("blast_evalue");
    unless ( defined($evalue) ) {
        $evalue = param("maxEvalue");
    }
    my $blast_pgm = "blastp";
    $blast_pgm = "blastx" if param("blast_program") eq "blastx";

    # from scaffold graph
    my $from         = param("from");
    my $scaffold_oid = param("scaffold_oid");
    #print "printGeneSearchProteinBlastForAll() from: $from, scaffold_oid: $scaffold_oid<br/>\n";

    ## --es 05/05/2005 Limit no. of BLAST jobs.
    WebUtil::blastProcCheck();
    printStatusLine( "Loading...", 1 );
    if ( blankStr($fasta) ) {
        webError("FASTA query sequence not specified.");
        return;
    }
    printStatusLine( "Loading...", 1 );

    validateQuerySequenceType( $fasta, $blast_pgm );

    webLog "Start BLAST IMG DB process=$$ " . currDateTime() . "\n"
      if $verbose >= 1;

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
    $fasta =~ s/^\s+//;
    $fasta =~ s/\s+$//;
    my $fasta2 = $fasta;
    if ( $fasta !~ /^>/ ) {
        $fasta2 = ">query$$\n";
        $fasta2 .= "$fasta\n";
    }

    #my $dbFile = checkPath( $all_faa_blastdb );
    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpDbFile = "$cgi_tmp_dir/faaDb$$.pal";
    my $dbFile    = $tmpDbFile;
    $dbFile =~ s/\.pal$//;
    writePalFile($tmpDbFile);

    my $tmpFile = "$cgi_tmp_dir/blast$$.faa";
    my $wfh = newWriteFileHandle( $tmpFile, "prinGeneSearchBlastForAll" );
    print $wfh "$fasta2\n";
    close $wfh;

    ## Prepare for BLAST
    printMainForm();
    webLog "Start BLAST " . currDateTime() . "\n" if $verbose >= 1;
    $evalue = checkEvalue($evalue);

    ## New BLAST
    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p $blast_pgm -d $dbFile $blast_a_flag -e $evalue -m 0 "
      . " -b 2000 -v 2000 -i $tmpFile "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013

    WebUtil::unsetEnvPath();

    if ( checkMblastUse($blast_pgm) ) {
        runMblastM0( $blast_pgm, $seq_id, $seq, $evalue, 0 );
        WebUtil::resetEnvPath();
        return 0;
    }

    my $cfh;
    my $reportFile;
    if ( $blastallm0_server_url ne "" ) {

        # For security reasons, we don't put in the whole
        # path, but make some assumptions about the report
        # being in common_tmp_dir.
        if ( $common_tmp_dir ne "" ) {
            my $sessionId = getSessionId();
            $reportFile = "blast.$sessionId.$$.m0.txt";
        }

        # Heuristic to discover IMG (Oracle) database name.
        my $database = $img_lid_blastdb;
        $database =~ s/_lid$//;
        my %args;
        $args{gene_oid}           = $seq_id;
        $args{seq}                = $seq;
        $args{mopt}               = "0";
        $args{eopt}               = $evalue;
        $args{db}                 = "allFaa";
        $args{database}           = $database;
        $args{top_n}              = 10000;
        $args{pgm}                = $blast_pgm;
        $args{private_taxon_oids} = getPrivateTaxonOids();
        $args{super_user}         = getSuperUser();
        $args{report_file}        = $reportFile if $reportFile ne "";

        #print "printGeneSearchProteinBlastForAll() blastallm0_server_url: $blastallm0_server_url<br/>\n";
        #print Dumper(%args);
        #print "<br/>\n";
        webLog( ">>> Calling '$blastallm0_server_url' database='$database' "
              . "db='allFaa' pgm='$blast_pgm' reportFile='$reportFile'\n" );
        $cfh = new LwpHandle( $blastallm0_server_url, \%args );
    } else {

        #webLog "+ $cmd\n" if $verbose >= 1;
        #if ( $blast_wrapper_script ne "" ) {
        #    $cmd = "$blast_wrapper_script $cmd";
        #}
        #$cfh = newCmdFileHandle( $cmd, "printGeneSearchBlastForAll" );
        #my $img_ken = 1; 
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
            }
    	    elsif( $s =~ /^\.status / ) {
    	       my( $tag, @toks ) = split( /\s+/, $s );
    	       my $tok_str = join( " ", @toks );
    	       print "$tok_str<br/>\n";
    	    }
    	    elsif( $s =~ /^\.qFile / ) {
    	       my( $tag, $val ) = split( /\s+/, $s );
    	       $qFile = $val;
    	    }
        }
    	if ( $qFile ne "" ) {
    	   waitForResults( $reportFile, $qFile );
    	}

        webLog("Reading reportFile='$reportFile'\n");
        $cfh = newReadFileHandle( "$common_tmp_dir/$reportFile", "printGeneSearchProteinBlastForAll" );
    }

    my $anyHits = 0;
    my @lines;
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }
        if ( $s =~ /^Sequences producing significant alignments/ ) {
            $anyHits = 1;
        }
        push( @lines, $s );

    }
    $cfh->close();
    WebUtil::resetEnvPath();
    wunlink($tmpFile);
    wunlink($tmpDbFile);

    if ($anyHits) {
        print "</pre>\n";
        WebUtil::printGeneCartFooter();
        print "<pre>\n";
    }

    print "<pre><font color='blue'>\n";
    my ( $query_coords_ref, $subjt_coords_ref ) = processProteinBlastResult( \@lines, '', $scaffold_oid, 0 );
    #print "printGeneSearchProteinBlastForAll() que: @$query_coords_ref<br/>\n";
    #print "printGeneSearchProteinBlastForAll() sub: @$subjt_coords_ref<br/>\n";
    print "</font></pre>\n";

    if ($anyHits) {
        print "</pre>\n";
        WebUtil::printGeneCartFooter();
        ## save to workspace
        WorkspaceUtil::printSaveGeneToWorkspace2('gene_oid');
        print "<pre>\n";
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
    webLog "BLAST Done for IMG DB process=$$ " . currDateTime() . "\n"
      if $verbose >= 1;

    if ( $from eq "ScaffoldGraphDNA" && ( $img_internal || $img_er ) ) {
        my $query_orig_start_coord = param("query_orig_start_coord");
        my $query_orig_end_coord   = param("query_orig_end_coord");

        print qq{
              <form method="post" action="main.cgi" 
              enctype="application/x-www-form-urlencoded" 
              name="mainForm2">
        };

        # find true coorrds ???
        my @query_coords = @$query_coords_ref;
        if ( $#query_coords > -1 ) {
            my $aref =
              getTrueSeqCoords3( $query_coords_ref, $subjt_coords_ref, $scaffold_oid, $query_orig_start_coord,
                $query_orig_end_coord );
            foreach my $line (@$aref) {
                print qq{
                    <input type="hidden" name='coords' 
                    value='$line' />
                };
            }

            print qq{
                <h2>Missing Gene</h2>
                <input type='hidden' name='page' value='scaffoldMissingGene' />
                <input type="submit" name="_section_MyIMG_scaffoldMissingGene"
                value="Add Missing Gene"
                class="meddefbutton" />
            };
        }
    }

}

############################################################################
# writePalFile - Write list of BLAST databases.
############################################################################
sub writePalFile {
    my ($outFile) = @_;

    my $wfh = newWriteFileHandle( $outFile, "writePalFile" );

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    my $taxon_dir   = $taxon_faa_dir;
    my $all_blastdb = $all_faa_blastdb;
    my $dbName      = lastPathTok($all_blastdb);

    my $title  = "TITLE $dbName";
    my $dblist = "DBLIST $all_blastdb";

    if ( !$contact_oid || $super_user eq "Yes" ) {
        if ( $super_user eq "Yes" ) {
            $title  .= ".suser";
            $dblist .= ".suser";
        }
        print $wfh "$title\n";
        print $wfh "$dblist\n";
        close $wfh;
        webLog("$outFile: $title\n");
        return;
    }

    my $dbh = dbLogin();
    my $sql = QueryUtil::getContactTaxonPermissionSql();
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();    # private taxon_oid
        last if !$taxon_oid;
        $title .= "+$taxon_oid";
        if ( $sandbox_blast_data_dir ne '' ) {
            $dblist .= " $sandbox_blast_data_dir/$taxon_oid/$taxon_oid" . '.faa';
        } else {
            $dblist .= " $taxon_dir/$taxon_oid.faa.blastdb/$taxon_oid";
        }
    }
    print $wfh "$title\n";
    print $wfh "$dblist\n";
    close $wfh;
    webLog("$outFile: $title\n");

}

############################################################################
# getPrivateTaxonOids - Get private taxon_oid's for which this
#    user has permission.
############################################################################
sub getPrivateTaxonOids {

    my $contact_oid = getContactOid();
    return "" if ( !$user_restricted_site || !$contact_oid );

    my $dbh = dbLogin();
    my $sql = QueryUtil::getContactTaxonPermissionSql();
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my $s;
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();    # private taxon_oid
        last if !$taxon_oid;
        $s .= "$taxon_oid,";
    }
    #print "getPrivateTaxonOids() s=$s<br/>\n";

    return $s;
}

############################################################################
# printGeneSearchDnaBlastForAll - Run BLAST for all IMG genes,
#   single database version.  Done for DNA database version.
#     Inputs:
#        fasta - FASTA sequence
#        evalue - maximum e-value cutoff
############################################################################
sub printGeneSearchDnaBlastForAll {
    my ($fasta) = @_;
    if ( !defined($fasta) ) {
        $fasta = param("fasta");
    }

    my $evalue = param("blast_evalue");
    unless ( defined($evalue) ) {
        $evalue = param("maxEvalue");
    }

    my $blast_pgm = param("blast_program");
    $blast_pgm =~ /([a-zA-Z0-9_]+)/;
    $blast_pgm = $1;

    ## --es 05/05/2005 Limit no. of BLAST jobs.
    WebUtil::blastProcCheck();
    printStatusLine( "Loading...", 1 );
    if ( blankStr($fasta) ) {
        webError("FASTA query sequence not specified.");
        return;
    }
    $evalue = checkEvalue($evalue);
    webLog "Start BLAST IMG DB process=$$ " . currDateTime() . "\n"
      if $verbose >= 1;

    #printStatusLine( "Loading...", 1 );

    validateQuerySequenceType( $fasta, $blast_pgm );

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
    $fasta =~ s/^\s+//;
    $fasta =~ s/\s+$//;
    my $fasta2 = $fasta;
    if ( $fasta !~ /^>/ ) {
        $fasta2 = ">query$$\n";
        $fasta2 .= "$fasta\n";
    }
    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpDbFile = "$cgi_tmp_dir/fnaDb$$.nal";
    my $dbFile    = $tmpDbFile;
    $dbFile =~ s/\.nal$//;
    writeNalFile($tmpDbFile);

    my $tmpFile = "$cgi_tmp_dir/blast$$.fna";
    my $wfh = newWriteFileHandle( $tmpFile, "printGeneSearchDnaBlastForAll" );
    print $wfh "$fasta2\n";
    close $wfh;

    ## Run BLAST
    printMainForm();
    webLog "Start BLAST " . currDateTime() . "\n" if $verbose >= 1;

    ## New BLAST
    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p $blast_pgm -d $dbFile $blast_a_flag -e $evalue -m 0 "
      . " -b 2000 -v 2000 -i $tmpFile "
      . " --path $blastall_bin ";
    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013
    #print "printGeneSearchDnaBlastForAll() cmd: $cmd<br/>\n";
    webLog "+ $cmd\n" if $verbose >= 1;
    WebUtil::unsetEnvPath();

    my $cfh;
    my $reportFile;
    if ( $blastallm0_server_url ne "" ) {

        # For security reasons, we don't put in the whole
        # path, but make some assumptions about the report
        # being in common_tmp_dir.
        if ( $common_tmp_dir ne "" ) {
            my $sessionId = getSessionId();
            $reportFile = "blast.$sessionId.$$.m0.txt";
        }

        # --es 08/30/08
        # Heuristic to discover IMG (Oracle) database name.
        my $database = $img_lid_blastdb;
        $database =~ s/_lid$//;
        my %args;
        $args{gene_oid}           = $seq_id;
        $args{seq}                = $seq;
        $args{mopt}               = "0";
        $args{eopt}               = $evalue;
        $args{db}                 = "allFna";
        $args{database}           = $database;
        $args{top_n}              = 10000;
        $args{pgm}                = $blast_pgm;
        $args{private_taxon_oids} = getPrivateTaxonOids();
        $args{super_user}         = getSuperUser();
        $args{report_file}        = $reportFile if $reportFile ne "";

        #print "printGeneSearchDnaBlastForAll() blastallm0_server_url: $blastallm0_server_url<br/>\n";
        #print Dumper(%args);
        #print "<br/>\n";
        #print ">>> Calling '$blastallm0_server_url' database='$database' "
        #        . "db='allFna' pgm='$blast_pgm' reportFile='$reportFile'<br/>\n";
        webLog( ">>> Calling '$blastallm0_server_url' database='$database' "
              . "db='allFna' pgm='$blast_pgm' reportFile='$reportFile'\n" );
        $cfh = new LwpHandle( $blastallm0_server_url, \%args );
    } else {

        #if ( $blast_wrapper_script ne "" ) {
        #    $cmd = "$blast_wrapper_script $cmd";
        #}
        #$cfh = newCmdFileHandle( $cmd, "printGeneSearchDnaBlastForAll" );
        #print "Calling blast api<br/>\n";
        my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
        my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
        if ( $stdOutFile == -1 ) {

            # close working div but do not clear the data
            printEndWorkingDiv( '', 1 );
            ##$dbh->disconnect();
            printStatusLine( "Error.", 2 );
            WebUtil::webExit(-1);
        }

        #print "blast done<br/>\n";
        #print "Reading output $stdOutFile<br/>\n";
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
            }
    	    elsif( $s =~ /^\.status / ) {
    	       my( $tag, @toks ) = split( /\s+/, $s );
    	       my $tok_str = join( " ", @toks );
    	       print "$tok_str<br/>\n";
    	    }
    	    elsif( $s =~ /^\.qFile / ) {
    	       my( $tag, $val ) = split( /\s+/, $s );
    	       $qFile = $val;
    	    }
        }
    	if( $qFile ne "" ) {
    	   waitForResults( $reportFile, $qFile );
    	}
        webLog("Reading reportFile='$common_tmp_dir/$reportFile'\n");
        #print "Reading reportFile=$common_tmp_dir/$reportFile<br/>\n";
        $cfh = newReadFileHandle( "$common_tmp_dir/$reportFile", "printGeneSearchDnaBlastForAll" );
    }

    my $anyHits = 0;
    my @lines;
    while ( my $s = $cfh->getline() ) {
        #print "Reading reportFile s=$s<br/>\n";
        chomp $s;
        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }
        if ( $s =~ /^Sequences producing significant alignments/ ) {
            $anyHits = 1;
        }
        push( @lines, $s );
    }
    $cfh->close();
    WebUtil::resetEnvPath();
    wunlink($tmpFile);
    wunlink($tmpDbFile);

    if ($anyHits) {
        print "</pre>\n";
        WebUtil::printScaffoldCartFooter();
        print "<pre>\n";
    }

    print "<pre><font color='blue'>\n";
    my ( $query_coords_ref, $subjt_coords_ref ) = processDnaSearchResult( \@lines, '', 0, $evalue );
    #print "printGeneSearchDnaBlastForAll() que: @$query_coords_ref<br/>\n";
    #print "printGeneSearchDnaBlastForAll() sub: @$subjt_coords_ref<br/>\n";
    print "</font></pre>\n";

    if ($anyHits) {
        print "</pre>\n";
        WebUtil::printScaffoldCartFooter();
        ## save to workspace
        WorkspaceUtil::printSaveScaffoldToWorkspace('scaffold_oid');
        print "<pre>\n";
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
    webLog "BLAST Done for IMG DB process=$$ " . currDateTime() . "\n"
      if $verbose >= 1;
}

############################################################################
# writeNalFile - Write list of BLAST databases.
############################################################################
sub writeNalFile {
    my ($outFile) = @_;

    my $wfh = newWriteFileHandle( $outFile, "writeNalFile" );

    my $dbh         = dbLogin();
    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    my $taxon_dir   = "$web_data_dir/all.fna.blastdbs";
    my $all_blastdb = $all_fna_blastdb;
    my $dbName      = lastPathTok($all_blastdb);

    my $title  = "TITLE $dbName";
    my $dblist = "DBLIST $all_blastdb";

    if ( !$contact_oid || $super_user eq "Yes" ) {
        print $wfh "$title\n";
        print $wfh "$dblist\n";
        close $wfh;
        #print "writeNalFile() contact_oid=$contact_oid; super_user=$super_user; $outFile: $title; $dblist<br/>\n";
        webLog("$outFile: $title\n");
        return;
    }

    my $dbh = dbLogin();
    my $sql = QueryUtil::getContactTaxonPermissionSql();
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    for ( ; ; ) {
        my ($taxon_oid) = $cur->fetchrow();    # private taxon_oid
        last if !$taxon_oid;
        $title .= "+$taxon_oid";
        if ( $sandbox_blast_data_dir ne '' ) {
            $dblist .= " $sandbox_blast_data_dir/$taxon_oid/$taxon_oid" . '.fna';
        } else {
            $dblist .= " $taxon_dir/$taxon_oid.fna.blastdb/$taxon_oid";
        }

    }
    print $wfh "$title\n";
    print $wfh "$dblist\n";
    close $wfh;
    #print "writeNalFile() contact_oid=$contact_oid; super_user=$super_user; $outFile: $title; $dblist<br/>\n";
    webLog("$outFile: $title\n");

}

############################################################################
# printGeneSearchProteinBlastByTaxon - Run BLAST for IMG genes split
#   by taxons, one BLAST database per taxon for one taxon.
#    Inputs:
#       fasta - FASTA sequence
#       evalue - E-value cutoff
#       taxon_oid - taxon object identifier
############################################################################
sub printGeneSearchProteinBlastByTaxon {
    my ( $fasta, $evalue, $taxon_oid, $in_file ) = @_;

    if ( blankStr($fasta) ) {
        webError("FASTA query sequence not specified.");
        return;
    }

    $evalue = checkEvalue($evalue);

    $fasta =~ s/^\s+//;
    $fasta =~ s/\s+$//;
    my $fasta2 = $fasta;
    if ( $fasta !~ /^>/ ) {
        $fasta2 = ">query$$\n";
        $fasta2 .= "$fasta\n";
    }

    my $data_type = param('data_type');

    my $blast_pgm = param("blast_program");
    $blast_pgm =~ /([a-z]+)/;
    $blast_pgm = $1;
    my $dbFile = "";
    if ( $in_file ) {
        my $file_name;
        if ( $sandbox_blast_data_dir ne '' && $data_type eq 'assembled' ) {
            $file_name = $sandbox_blast_data_dir . "/" . sanitizeInt($taxon_oid) . "/" . sanitizeInt($taxon_oid) . ".a.faa";
        } elsif ( $sandbox_blast_data_dir ne '' && $data_type eq 'unassembled' ) {
            $file_name = $sandbox_blast_data_dir . "/" . sanitizeInt($taxon_oid) . "/" . sanitizeInt($taxon_oid) . ".u.faa";
        } else {
            # both not supported yet
            print
"<p><font color='red'>Genome $taxon_oid $blast_pgm database does not support blasting both assembled and unassembled at the same time yet.</font></p>\n";
            my @q = ();
            my @s = ();
            return ( \@q, \@s );
        }
        if ( -e $file_name ) {
            #print "<p><font color='magenta'>Blast database only has assembled part of genome $taxon_oid.</font>\n";
            print "<p><font color='magenta'>Blast database $data_type part of genome $taxon_oid.</font>\n";
            $dbFile = checkPath($file_name);
        } else {
            print "<p><font color='red'>-- Genome $taxon_oid does not have $data_type $blast_pgm database.</font></p>\n";
            my @q = ();
            my @s = ();
            return ( \@q, \@s );
        }
    } else {
        if ( $sandbox_blast_data_dir ne '' ) {
            $dbFile = checkPath( "$sandbox_blast_data_dir/$taxon_oid/$taxon_oid" . '.faa' );
        } else {
            $dbFile = checkPath("$web_data_dir/taxon.faa/$taxon_oid.faa.blastdb/$taxon_oid");
        }
    }

    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpFile = "$cgi_tmp_dir/blast$$.faa";
    my $wfh = newWriteFileHandle( $tmpFile, "printGeneSearchProteinBlastByTaxon" );
    print $wfh "$fasta2\n";
    close $wfh;

    ## Run BLAST
    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p $blast_pgm -d $dbFile $blast_a_flag -e $evalue -m 0 "
      . " -b 2000 -v 2000 -i $tmpFile "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013

    webLog "+ $cmd\n" if $verbose >= 1;
    WebUtil::unsetEnvPath();

    #    if ( $blast_wrapper_script ne "" ) {
    #        $cmd = "$blast_wrapper_script $cmd";
    #    }

    #print "printGeneSearchProteinBlastByTaxon() cmd: $cmd<br/>\n";
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

    #    my $cfh = newCmdFileHandle( $cmd, "printGeneSeachBlastByTaxon" );
    my @lines;
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }
        push( @lines, $s );

    }
    close $cfh;
    WebUtil::resetEnvPath();
    wunlink($tmpFile);

    print "<pre><font color='blue'>\n";
    my $scaffold_oid = param("scaffold_oid");
    my ( $query_coords_ref, $subjt_coords_ref ) = processProteinBlastResult( \@lines, $taxon_oid, $scaffold_oid, $in_file );
    print "</font></pre>\n";

    #return ( \@query_coords, \@subjt_coords );
    return ( $query_coords_ref, $subjt_coords_ref );
}

############################################################################
# printGeneSearchDnaBlastByTaxon - Run BLAST for IMG genes split
#   by taxons, one BLAST database per taxon for one taxon.
#   Done for all DNA scaffold files.
#     Inputs:
#        fasta - FASTA sequence
#        evalue - max. evalue cutoff
#        taxon_oid - taxon object identifier
############################################################################
sub printGeneSearchDnaBlastByTaxon {
    my ( $fasta, $evalue, $taxon_oid, $in_file, $data_type ) = @_;

    # $assembled is only used if taxon_oid belongs to metagenome

    webError("FASTA query sequence not specified.")
      if ( blankStr($fasta) );

    $evalue = checkEvalue($evalue);
    ## --es 05/05/2005 Limit no. of BLAST jobs.
    WebUtil::blastProcCheck();
    $fasta =~ s/^\s+//;
    $fasta =~ s/\s+$//;
    my $fasta2 = $fasta;
    if ( $fasta !~ /^>/ ) {
        $fasta2 = ">query$$\n";
        $fasta2 .= "$fasta\n";
    }

    my $blast_pgm = param("blast_program");
    $blast_pgm =~ /([a-zA-Z_]+)/;
    $blast_pgm = $1;

    $taxon_oid = sanitizeInt($taxon_oid);
    
    ## db
    my $dbFile;
    if ( $in_file ) {
        # metagenome
        if ( $sandbox_blast_data_dir ne '' ) {
            $dbFile = $sandbox_blast_data_dir . "/" . $taxon_oid . "/" . $taxon_oid;
        } else {

            # OBSOLETE location
            $dbFile = "$mer_data_dir/" . $taxon_oid . "/$data_type/blast.data/" . $taxon_oid;
        }

        if ( $data_type eq "unassembled" ) {
            $dbFile .= ".u.fna";
        } else {
            $dbFile .= ".a.fna";
        }
    } else {    
        if ( $sandbox_blast_data_dir ne '' ) {
            $dbFile = "$sandbox_blast_data_dir/" . $taxon_oid . '/' . $taxon_oid . '.fna';
        } else {
            $dbFile = "$taxon_fna_dir/" . $taxon_oid . ".fna.blastdb/" . $taxon_oid;
        }
    }
    #print "printGeneSearchDnaBlastByTaxon() taxon_fna_dir: $taxon_fna_dir<br/>\n";
    #print "printGeneSearchDnaBlastByTaxon() mer_data_dir: $mer_data_dir<br/>\n";
    #print "printGeneSearchDnaBlastByTaxon() dbFile: $dbFile<br/>\n";

    ## check if dbFile exists
    my $abortBlast = 0;
    my $errMsg     = "<p><font color='blue'>BLAST data is not available.</font></p>";
    if ( $in_file ) {
        # metagenome
        unless ( -e $dbFile ) {
            $abortBlast = 1;
        }
    } else {    
        my @dbFileList = glob("$dbFile*");
        my $nfiles     = scalar(@dbFileList);
        if ( $nfiles eq 0 ) {
            $abortBlast = 1;
        }
    }

    # Stop if dbFile does not exist
    if ( $abortBlast eq 1 ) {
        print $errMsg;
        my @query_coords;
        my @subjt_coords;
        return ( \@query_coords, \@subjt_coords );
    }

    ## input file
    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken

    my $tmpFile = "$cgi_tmp_dir/blast$$.fna";
    my $wfh = newWriteFileHandle( $tmpFile, "printGeneSearchDnaBlastByTaxon" );
    print $wfh "$fasta2\n";
    close $wfh;

    ## Run BLAST
    my $cmd_part1 = "$blastall_bin/legacy_blast.pl blastall " . " -p $blast_pgm -d $dbFile $blast_a_flag -e $evalue";
    my $cmd_part2 = " -b 2000 -v 2000 -i $tmpFile " . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013

    my $cmd = $cmd_part1 . " -m 0 " . $cmd_part2;
    webLog "+ $cmd\n" if $verbose >= 1;

    #my $cmd2 = $cmd_part1 . " -m 8 " . $cmd_part2; # get tab-delimited output
    #webLog "+ $cmd2\n" if $verbose >= 1;

    #if ( $blast_wrapper_script ne "" ) {
    #    $cmd  = "$blast_wrapper_script $cmd";
    #}
    #print "printGeneSearchDnaBlastByTaxon() cmd: $cmd<br/>\n";
    #print "printGeneSearchDnaBlastByTaxon() cmd2: $cmd2<br/>\n";

    WebUtil::unsetEnvPath();

    #print "Calling blast api<br/>\n";
    my ( $cmdFile, $stdOutFilePath ) = Command::createCmdFile($cmd);
    my $stdOutFile = Command::runCmdViaUrl( $cmdFile, $stdOutFilePath );
    if ( $stdOutFile == -1 ) {

        # close working div but do not clear the data
        printEndWorkingDiv( '', 1 );
        printStatusLine( "Error.", 2 );
        WebUtil::webExit(-1);
    }
    #print "blast done<br/>\n";
    #print "Reading output $stdOutFile<br/>\n";
    my $cfh = WebUtil::newReadFileHandle($stdOutFile);

    ## Obtain coordinates information for multiple hits on one scaffold
    #my $cfh2 = newCmdFileHandle( $cmd2, "printGeneSearchDnaBlastByTaxon" );
    #my @lines2;
    #while ( my $s = $cfh2->getline() ) {
    #    chomp $s;
    #    if ( $s =~ /^PID=/ ) { # some genome/gene names might
    #                           # contain PID. This has happened.
    #                           # - yjlin 20130411
    #        my ( $junk, $pid ) = split( /=/, $s );
    #        WebUtil::setBlastPid($pid);
    #        next;
    #    }
    #    push( @lines2, $s );
    #}
    #close $cfh2;

    # Run BLAST for output
    #my $cfh = newCmdFileHandle( $cmd, "printGeneSearchDnaBlastByTaxon" );
    my @lines;
    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }
        push( @lines, $s );
    }
    close $cfh;
    WebUtil::resetEnvPath();
    wunlink($tmpFile);

    print "<pre><font color='blue'>\n";
    my ( $query_coords_ref, $subjt_coords_ref ) = processDnaSearchResult( \@lines, $taxon_oid, $in_file, $evalue );
    print "</font></pre>\n";

    #return ( \@query_coords, \@subjt_coords );
    return ( $query_coords_ref, $subjt_coords_ref );
}

############################################################################
# printGeneSearchBlastForTaxons  - Wrapper for above for multiple taxons.
#    Inputs:
#      fasta - FASTA protein sequence
#      evalue - max. evalue cutoff
#      isDna - Is DNA sequence
############################################################################
sub printGeneSearchBlastForTaxons {
    my ( $taxon_oids_ref ) = @_;

    my $isDnaSearch = 0;
    my $blast_program = param("blast_program");
    if ( $blast_program eq "tblastn" || $blast_program eq "blastn" ) {
        $isDnaSearch = 1;
    }    

    my $fasta         = param("fasta");
    my $evalue        = param("blast_evalue");

    # this is non null if from the missing gene
    my $gene_oid = param("gene_oid");

    # from scaffold graph
    my $from         = param("from");
    my $scaffold_oid = param("scaffold_oid");
    #print "printGeneSearchProteinBlastForAll() from: $from, scaffold_oid: $scaffold_oid<br/>\n";

    validateQuerySequenceType( $fasta, $blast_program );

    my $dbh = dbLogin();
    my ($taxon2name_href, $taxon_in_file_href, $taxon_db_href, $taxon_oids_str) 
        = QueryUtil::fetchTaxonsOidAndNameFile($dbh, $taxon_oids_ref);

    my @recs;
    foreach my $taxon_oid (keys %$taxon2name_href) {
        my $taxon_display_name = $taxon2name_href->{$taxon_oid};
        my $in_file = $taxon_in_file_href->{$taxon_oid};
        if ( $in_file && $blast_program ne "blastp" && $blast_program ne "blastn" ) {
            print "<p><font color='red'>- Genome '$taxon_display_name' " 
                . "does not have $blast_program database.</font>\n";
            next;
        }
        push( @recs, $taxon_oid );        
    }
    #print "printGeneSearchBlastForTaxons() recs=@recs<br/>\n";
    
    my $nRecs = scalar(@recs);
    if ( $nRecs == 0 ) {
        webError("No genomes selected for BLAST.");
    }

    printStartingForm();
    printCartButton( $isDnaSearch, $gene_oid );

    if ( $gene_oid ) {
        print qq{
            <input type="hidden" name='gene_oid' value='$gene_oid' />
            <input type='button' 
                    class='lgbutton' 
                    value='Return to Phylogenetic Profiler Results' 
                    onClick='history.go(-2)' /> &nbsp;
       
        };
        print end_form();
    }

    my @que;    # query list of strings
    my @sub;    # subject list of strings
    my $has_mer_fs = 0;
    my $count = 0;
    
    for my $taxon_oid (@recs) {
        my $taxon_display_name = $taxon2name_href->{$taxon_oid};
        my $in_file = $taxon_in_file_href->{$taxon_oid};

        if ( $isDnaSearch ) {
            if ( $in_file ) {
                # metagenome
                my $data_type = param("data_type");    # assembled, unassembled, both
                my @data_type_list = MetaUtil::getDataTypeList($data_type);

                for my $a (@data_type_list) {
                    $count++;
                    print "<div id='message'>\n<p>\n";
                    print "$count BLAST against <b>" . escHtml($taxon_display_name) . "</b> ($a)\n";
                    print "</p>\n</div>\n";

                    my ( $que_aref, $sub_aref ) =
                      printGeneSearchDnaBlastByTaxon( $fasta, $evalue, $taxon_oid, $in_file, $a );

                    if ( $que_aref ne "" && $sub_aref ne "" ) {
                        push( @que, @$que_aref );
                        push( @sub, @$sub_aref );
                    }
                }
            } 
            else {    
                $count++;
                print "<div id='message'>\n<p>\n";
                print "$count BLAST against <b>" . escHtml($taxon_display_name) . "</b>\n";
                print "</p>\n</div>\n";
                my ( $que_aref, $sub_aref ) = printGeneSearchDnaBlastByTaxon( $fasta, $evalue, $taxon_oid, $in_file );
                if ( $que_aref ne "" && $sub_aref ne "" ) {
                    push( @que, @$que_aref );
                    push( @sub, @$sub_aref );
                }
            }

        } else {

            # from scaffold viewer
            if ( $in_file ) {
                $has_mer_fs = 1;
            }

            my ( $que_aref, $sub_aref ) = printGeneSearchProteinBlastByTaxon( $fasta, $evalue, $taxon_oid, $in_file );
            if ( $que_aref ne "" && $sub_aref ne "" ) {
                push( @que, @$que_aref );
                push( @sub, @$sub_aref );
            }
        }
        print "<hr>\n" if $count < $nRecs;
    }
    #print "printGeneSearchBlastForTaxon() que: @que<br/>\n";
    #print "printGeneSearchBlastForTaxon() sub: @sub<br/>\n";

    printCartButtonWithWorkspaceSaving( $isDnaSearch, $gene_oid );
    printEndingForm( $nRecs ); 

    # parse the page for tblast - missing
    if ( $gene_oid ne "" && ( $img_internal || $img_er ) ) {
        print qq{
              <form method="post" action="main.cgi" 
              enctype="application/x-www-form-urlencoded" 
              name="mainForm2">
        };

        my @query;
        for ( my $i = 0 ; $i <= $#que ; $i++ ) {
            my $qline = $que[$i];
            my $sline = $sub[$i];
            my ( $sstart, $send, $frame, $taxon_oid, $curr_scaf_id, $bit_score, $evalue ) = split( /,/, $sline );

            # query gene start end - subject taxon start end
            push( @query, "$gene_oid,$qline,$taxon_oid,$sstart,$send,$frame,$curr_scaf_id,$bit_score,$evalue" );
        }

        # get new calc start and end
        my $query_aref = getTrueSeqCoords( \@query );

        foreach my $line (@$query_aref) {
            print qq{
                <input type="hidden" name='coords' 
                value='$line' />
            };
        }

        print qq{
          <h2>Missing Gene</h2>
          <input type='hidden' name='page' value='potentialMissingGene' />
          <input type="submit" name="_section_MyIMG_potentialMissingGene"
                 value="Add Missing Gene"
                 class="meddefbutton" />
        };
        print end_form();

    }

    if ( $from eq "ScaffoldGraphDNA" && ( $img_internal || $img_er ) ) {
        #print "printGeneSearchBlastForTaxons() inside<br/>\n";
        my $query_orig_start_coord = param("query_orig_start_coord");
        my $query_orig_end_coord   = param("query_orig_end_coord");

        print qq{
              <form method="post" action="main.cgi" 
              enctype="application/x-www-form-urlencoded" 
              name="mainForm2">
        };

        # find true coorrds
        if ( $#que > -1 ) {
            my $aref = getTrueSeqCoords2( \@que, \@sub, $scaffold_oid, $query_orig_start_coord, $query_orig_end_coord );
            foreach my $line (@$aref) {
                print qq{
                    <input type="hidden" name='coords' 
                    value='$line' />
                };
            }

            print qq{
                <h2>Missing Gene</h2>
                <input type='hidden' name='page' value='scaffoldMissingGene' />
                <input type="submit" name="_section_MyIMG_scaffoldMissingGene"
                value="Add Missing Gene"
                class="meddefbutton" />
            };
        }
        print end_form();
    }

}

sub printCartButton {
    my ( $isDnaSearch, $gene_oid ) = @_;

    if ( !$isDnaSearch || $gene_oid ) {
        WebUtil::printGeneCartFooter();
    }

    if ($isDnaSearch) {
        WebUtil::printScaffoldCartFooter();
    }

}

sub printCartButtonWithWorkspaceSaving {
    my ( $isDnaSearch, $gene_oid ) = @_;

    # add to gene cart
    if ( !$isDnaSearch || $gene_oid ne "" ) {
        WebUtil::printGeneCartFooter();
        ## save to workspace
        WorkspaceUtil::printSaveGeneToWorkspace2('gene_oid');
    }

    if ($isDnaSearch) {
        WebUtil::printScaffoldCartFooter();
        ## save to workspace
        WorkspaceUtil::printSaveScaffoldToWorkspace('scaffold_oid');
    }

}

sub printStartingForm {

    my $s = qq{
        Multiple BLAST jobs will run for each selected genome. 
        Scroll down to see BLAST job for each genome.
    };
    printHint($s);
    printMainForm();
    printStatusLine( "Loading...", 1 );

}

sub printEndingForm {
    my ( $nRecs ) = @_;

    printStatusLine( "$nRecs Loaded.", 2 );
    print end_form();
}


############################################################################
# validateQuerySequenceType
############################################################################
sub validateQuerySequenceType {
    my ( $fasta, $blast_program ) = @_;

    # check fasta sequence to see if it is protein
    # If the sequence contains only 'ATCGatcg', it is likely to be DNA.
    my $fasta_check = $fasta;
    $fasta_check =~ s/[ATCGNatcgn]//g;
    my $query_type;    # most likely query type based on sequence (DNA or protein)
    if ( $fasta_check =~ /^\s*$/ ) {

        # if the remaining string contains only whitespaces
        $query_type = 'DNA';
    } else {
        $query_type = 'protein';
    }

    if (   ( $query_type eq 'DNA' && ( $blast_program eq 'blastp' || $blast_program eq 'tblastn' ) )
        || ( $query_type eq 'protein' && ( $blast_program eq 'blastn' || $blast_program eq 'blastx' ) ) )
    {
        print qq{
             <p><font color='red'>
                <b>Warning:</b> The query looks like a $query_type sequence.
                Please make sure an appropriate BLAST program is chosen.
             </font></p>\n
         };
    }

}

############################################################################
# printGenomeSelectionMessage
############################################################################
sub printGenomeSelectionMessage {
    my ( $useGenomeSet ) = @_;
    
    if ( $useGenomeSet ) {
        print qq{
            Find matches in genomes of selected genome sets.  
            <br/> 
            The total selection can not be more than <b>$blast_max_genome</b> genomes (including metagenomes).
            <br/>
        };        
    }
    else {
        print qq{
            Find matches in genomes selected below.  
            <br/> 
            <u>All isolate genomes</u> in IMG will be used if no selection.  This is equivalent to the old 'All IMG Genes - One large Database' option.
            <br/> 
            <u>All isolate genomes</u> in IMG will also be used if the selection is more than <b>$blast_max_genome</b> genomes (including metagenomes).
            <br/>
        };        
    }
}

############################################################################
# printUserRestrictedBlastMessage - Print warning message.
############################################################################
sub printUserRestrictedBlastMessage {

    print "<p>\n";
    print "<font color='red'>\n";
    print "\"All IMG Genes, one large BLAST database\" ";
    print "is restricted to public genomes for users\n";
    print "with restricted access to selected genomes.<br/>\n";
    print "However, users may BLAST against currently selected genomes\n";
    print "to find similarities in the genomes where they\n";
    print "have private access.<br/>\n";
    print "</font>\n";
    print "</p>\n";
}

############################################################################
# printPageHint - Print this page's hint.
############################################################################
sub printPageHint {
    my ( $useGenomeSet ) = @_;

    my $hintMessage = qq{
        -- BLAST may be slow for large protein queries.<br />
    };
    if ( ! $useGenomeSet ) {
        $hintMessage .= qq{
            -- Hold down contrl key (or command key in the case of the Mac) 
               to select or deselect multiple BLAST databases. 
               Drag down the list to select many items.<br/>
            -- The optimum E-value will depend on the size of the BLAST
               database you select.  (For a larger database,
               use a larger E-value cutoff.)<br/>
            -- Due to performance constraints, the DNA BLAST database
               does not include the higher Eukaryotes.<br/>
        };
    }
    printHint( $hintMessage );
}

############################################################################
# xal4Taxons - Generate db.[p|n]al list for selected taxons.
#  type = "faa" or "fna".
############################################################################
sub xal4Taxons {
    my ( $type, $outFile ) = @_;

    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    my @taxon_oids = split( /,/, $taxon_filter_oid_str );
    if ( scalar(@taxon_oids) == 0 ) {
        my $dbh = dbLogin();
        my ( $sql, @bindList ) = QueryUtil::getAllTaxonOidBindSql();
        my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );
        for ( ; ; ) {
            my ($taxon_oid) = $cur->fetchrow();
            last if !$taxon_oid;
            push( @taxon_oids, $taxon_oid );
        }
        $cur->finish();

        #$dbh->disconnect();
    }
    my $cnt = @taxon_oids;
    my $wfh = newWriteFileHandle( $outFile, "xal4Taxons" );
    print $wfh "TITLE $cnt selected genomes\n";
    print $wfh "DBLIST ";
    my $count = 0;
    for my $taxon_oid (@taxon_oids) {
        my $taxon_dir;
        $count++;
        if ( $type eq "faa" ) {
            $taxon_dir = $taxon_faa_dir;
        } elsif ( $type eq "fna" ) {
            $taxon_dir = $taxon_fna_dir;
        } else {
            webDie("xal4Taxons: expected type 'faa' or 'fna': got '$type'\n");
        }
        if ( $taxon_dir =~ /\/\// ) {
            webDie("xal4Taxons: illegal taxon_dir='$taxon_dir'\n");
        }
        my $path;
        if ( $sandbox_blast_data_dir ne '' ) {
            $path = "$sandbox_blast_data_dir/$taxon_oid/$taxon_oid" . '.' . $type;
        } else {
            $path = "$taxon_dir/$taxon_oid.$type.blastdb/$taxon_oid";
        }

        print $wfh "$path ";
    }
    print $wfh "\n";
    webLog "$count taxons in $outFile\n" if $verbose >= 1;
    close $wfh;
}

############################################################################
# printEnvBlastForDbs - Print envrinoment blast for multiple databases.
############################################################################
sub printEnvBlastForDbs {
    my ( $readDbs_ref, $proteinFlag ) = @_;

    my $s = "( Multiple BLAST jobs will run for each selected databases. ";
    $s .= "Scroll down to see BLAST job for each database. )\n";
    printHint($s);
    for my $readDb (@$readDbs_ref) {
        print "<div id='message'>\n";
        print "<p>\n";
        print "BLAST against reads database <b>$readDb</b>.\n";
        print "</p>\n";
        print "</div>\n";
        printEnvBlast( $readDb, $proteinFlag );
    }
}

############################################################################
# printEnvBlast - Print results of enviromental BLAST.
############################################################################
sub printEnvBlast {
    my ( $imgBlastDb, $proteinFlag ) = @_;

    my $blast_pgm = param("blast_program");
    my $fasta     = param("fasta");

    #my $imgBlastDb = param( "imgBlastDb" );
    my $evalue = param("blast_evalue");

    ## --es 05/05/2005 Limit no. of BLAST jobs.
    WebUtil::blastProcCheck();
    printStatusLine( "Loading...", 1 );
    if ( blankStr($fasta) ) {
        webError("FASTA query sequence not specified.");
        return;
    }
    $evalue = checkEvalue($evalue);
    webLog "Start BLAST IMG DB process=$$ " . currDateTime() . "\n"
      if $verbose >= 1;
    $fasta =~ s/^\s+//;
    $fasta =~ s/\s+$//;
    my $fasta2 = $fasta;
    if ( $fasta !~ /^>/ ) {
        $fasta2 = ">query$$\n";
        $fasta2 .= "$fasta\n";
    }
    $imgBlastDb =~ /([a-zA-Z0-9_]+)/;
    $imgBlastDb = $1;
    my $dbFile;
    if ( $imgBlastDb =~ /^snp_/ ) {
        $imgBlastDb =~ s/^snp_//;
        $dbFile = "$snp_blast_data_dir/$imgBlastDb";
    } elsif ( $imgBlastDb =~ /^readsDb_/ ) {
        $imgBlastDb =~ s/^readsDb_//;
        $dbFile = "$taxon_reads_fna_dir/$imgBlastDb.reads.fna";
    } elsif ( $imgBlastDb =~ /^bin_/ ) {

        # TODO my bins - ken
        $imgBlastDb =~ s/^bin_//;
        $dbFile = "$mybin_blast_dir/$imgBlastDb.fna";
        if ($proteinFlag) {
            $dbFile = "$mybin_blast_dir/$imgBlastDb.faa";
        }
    } else {
        printStatusLine( "Error.", 2 );
        webError("BLAST DB not found for '$imgBlastDb'.");
    }
    $cgi_tmp_dir = Command::createSessionDir();    # change dir - ken
    my $tmpFile   = "$cgi_tmp_dir/blast$$.fna";
    my $tmpDb     = "$cgi_tmp_dir/selectedDb$$";
    my $tmpDbFile = "$tmpDb.nal";
    my $wfh       = newWriteFileHandle( $tmpFile, "printEnvBlast" );
    print $wfh "$fasta2\n";
    close $wfh;

    ## Run BLAST
    printMainForm();
    webLog "Start BLAST " . currDateTime() . "\n" if $verbose >= 1;
    $blast_pgm =~ /([a-zA-Z0-9_]+)/;
    $blast_pgm = $1;

    ## New BLAST
    my $cmd =
        "$blastall_bin/legacy_blast.pl blastall "
      . " -p $blast_pgm -d $dbFile $blast_a_flag -e $evalue -m 0 "
      . " -b 2000 -v 2000 -i $tmpFile "
      . " --path $blastall_bin ";

    # --path is needed although fullpath of legacy_blast.pl is
    # specified in the beginning of command! ---yjlin 03/12/2013

    webLog "+ $cmd\n" if $verbose >= 1;
    WebUtil::unsetEnvPath();

    #    if ( $blast_wrapper_script ne "" ) {
    #        $cmd = "$blast_wrapper_script $cmd";
    #    }
    #    my $cfh = newCmdFileHandle( $cmd, "printEnvBlast" );
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

    print "<pre>\n";
    print "<font color='blue'>\n";
    my $inSummary = 0;

    while ( my $s = $cfh->getline() ) {
        chomp $s;
        if ( $s =~ /^PID=/ ) {    # some genome/gene names might
                                  # contain PID. This has happened.
                                  # - yjlin 20130411
            my ( $junk, $pid ) = split( /=/, $s );
            WebUtil::setBlastPid($pid);
            next;
        }
        print "$s\n";
    }
    print "</font>\n";
    print "</pre>\n";
    close $cfh;
    WebUtil::resetEnvPath();
    wunlink($tmpFile);
    wunlink($tmpDbFile);

    printStatusLine( "Loaded.", 2 );
    print end_form();
    webLog "BLAST Done for IMG DB process=$$ " . currDateTime() . "\n"
      if $verbose >= 1;
}

############################################################################
# processDnaSearchResult - Add links to scaffold regions in chromosome
#   browser given alignments along scaffold.
############################################################################
sub processDnaSearchResult {
    my ( $lines_ref, $taxon_oid, $in_file, $evalue ) = @_;

    my %coords;
    my $coord1;
    my $coord2;
    my $curr_scaf_id;

    my @t_oids         = ();
    my @ext_accessions = ();

    # Scan for coordinates in scaffolds
    for my $s (@$lines_ref) {
        #webLog("$s\n");

        if ( $s =~ /^>/ ) {
            if ( $curr_scaf_id ne "" && $coord1 ne "" && $coord2 ne "" ) {
                my $k = "$curr_scaf_id:$coord1";
                my $v = "$coord1:$coord2";
                $coords{$k} = $v;
                $coord1 = $coord2 = "";
            }
            $curr_scaf_id = findID($s);
            $coord1       = $coord2 = "";
      		#print "processDnaSearchResult() > line: $s, curr_scaffold_id: $curr_scaf_id, coord1: $coord1, coord2: $coord2<br/>\n";

            if ( ! $in_file ) {
                #isolate
                if ( $curr_scaf_id =~ /\./ && ! $taxon_oid ) {
                    # this is only for blast all
                    my ( $t_oid, undef ) = split( /\./, $curr_scaf_id );
                    my $s_accession = substr $curr_scaf_id, 1 + length($t_oid);
                    push( @t_oids,         $t_oid );
                    push( @ext_accessions, $s_accession );
                } elsif ( $taxon_oid ) {
                    push( @t_oids,         $taxon_oid );
                    push( @ext_accessions, $curr_scaf_id );
                } else {
                    push( @ext_accessions, $curr_scaf_id );
                }
            }
        } elsif ( $s =~ /Score = / ) {
            if ( $curr_scaf_id ne "" && $coord1 ne "" && $coord2 ne "" ) {
                my $k = "$curr_scaf_id:$coord1";
                my $v = "$coord1:$coord2";
                $coords{$k} = $v;
                $coord1 = $coord2 = "";
            }
        } elsif ( $curr_scaf_id ne "" && $s =~ /^Sbjct/ ) {
            my $s2 = $s;
            $s2 =~ s/\s+/ /g;
            my ( $sbjct, $coord, @toks ) = split( / /, $s2 );
            $coord1 = $coord if ( $coord1 eq "" );
            my $nToks   = @toks;
            my $lastTok = $toks[ $nToks - 1 ];
            $coord2 = $lastTok;
            #print "processDnaSearchResult() Sbjct line: $s, sbjct: $sbjct, coord: $coord, toks: @toks, curr_scaffold_id: $curr_scaf_id, coord1: $coord1, coord2: $coord2<br/>\n";
        }
    }
    if ( $curr_scaf_id ne "" && $coord1 ne "" && $coord2 ne "" ) {
        my $k = "$curr_scaf_id:$coord1";
        my $v = "$coord1:$coord2";
        $coords{$k} = $v;
        $coord1 = $coord2 = "";
    }
    $curr_scaf_id = '';

    my ( $accession2scaf_href, $accession2tax_href );
    if ( !$in_file && scalar(@ext_accessions) > 0 ) {
        #print "processDnaSearchResult() t_oids=@t_oids<br/>\n";
        #print "processDnaSearchResult() ext_accessions=@ext_accessions<br/>\n";
        ( $accession2scaf_href, $accession2tax_href ) = getScaffoldIds( \@t_oids, \@ext_accessions );
        #print "processDnaSearchResult() accession2scaf_h=<br/>\n";
        #print Dumper $accession2scaf_href;
        #print "<br/>\n";
        #print "processDnaSearchResult() accession2tax_h=<br/>\n";
        #print Dumper $accession2tax_href;
        #print "<br/>\n";
    }

    my @query_coords;
    my @subjt_coords;

    my $frame       = 0;
    my $bit_score   = 0;
    my $e_value     = 0;
    my $curr_qstart = -1;
    my $curr_qend   = -1;
    my $curr_sstart = -1;
    my $curr_send   = -1;

    my %someId2url;
    my $inSummary = 0;
    for my $s (@$lines_ref) {
        chomp $s;

        if ( $s =~ /^Sequences producing significant alignments/ ) {
            $inSummary = 1;
            print "$s\n";
        } elsif ( $inSummary && !blankStr($s) && $s =~ /^[0-9A-Za-z]+/ ) {
            my $s2 = $s;
            $s2 =~ s/\s+/ /g;
            $curr_scaf_id = findID($s2);
            #print "processDnaSearchResult() inSummary curr_scaf_id: $curr_scaf_id<br/>\n";

            my $checkbox;
            my $url;
            if ( $in_file ) {
                #metagenome
                my ( $t_oid,     $t_s_oid ) = split( /\./, $curr_scaf_id );
                my ( $data_type, $s_oid )   = split( /\:/, $t_s_oid );
                my $start_coord = $coord1;
                my $end_coord   = $coord2;
                if ( $coord1 > $coord2 ) {
                    $start_coord = $coord2;
                    $end_coord   = $coord1;
                }
                $data_type = 'assembled'   if ( $data_type eq 'a' );
                $data_type = 'unassembled' if ( $data_type eq 'u' );
                my $workspace_id = "$t_oid $data_type $s_oid";
                $checkbox = "<input type='checkbox' name='scaffold_oid' value='$workspace_id'/>";
                $url      =
                    "$main_cgi?section=MetaDetail&page=metaScaffoldDetail&scaffold_oid=$s_oid"
                  . "&taxon_oid=$t_oid&data_type=$data_type";
                $someId2url{$curr_scaf_id} = $url;
            } else {
                my $sbjt_scaf_oid = $accession2scaf_href->{$curr_scaf_id};
                $checkbox = "<input type='checkbox' " . "name='scaffold_oid' value='$sbjt_scaf_oid'/>";
                $url      = "main.cgi?section=ScaffoldGraph&page=scaffoldDetail" . "&scaffold_oid=$sbjt_scaf_oid";
                $someId2url{$curr_scaf_id} = $url;
            }
            my $x1 = "<a href='$url'>";
            my $x2 = "</a>";
            $s =~ s/$curr_scaf_id/${x1}${curr_scaf_id}${x2}/;
            $s = $checkbox . ' ' . $s;

            print "$s\n";

        } elsif ( $s =~ /^>/ ) {
            $inSummary    = 0;
            $curr_scaf_id = findID($s);
            my $url = $someId2url{$curr_scaf_id};
            if ($url) {
                my $x1 = "<a href='$url'>";
                my $x2 = "</a>";
                $s =~ s/${curr_scaf_id}/${x1}${curr_scaf_id}${x2}/;
            }
            print "$s\n";
        } elsif ( $curr_scaf_id ne "" && $s =~ /^Sbjct/ ) {
            my $s2 = $s;
            $s2 =~ s/\s+/ /g;
            my ( $sbjct, $coord, @toks ) = split( / /, $s2 );
            my $k = "$curr_scaf_id:$coord";
            my $x = $coords{$k};
            if ( $x ne "" ) {

                my ( $t_oid, $t_s_oid, $type, $s_oid );

                my ( $coord1, $coord2 ) = split( /:/, $x );

                my $start_coord = $coord1;
                my $end_coord   = $coord2;
                if ( $coord1 > $coord2 ) {
                    $start_coord = $coord2;
                    $end_coord   = $coord1;
                }

                ## adjust start and end coords to show a longer fragment of scaffold
                my $show_length = 25000;
                if ( $end_coord - $start_coord < $show_length ) {
                    my $mid_coord = ( $start_coord + $end_coord ) / 2;
                    $start_coord = int( $mid_coord - $show_length / 2 );
                    $end_coord   = int( $mid_coord + $show_length / 2 );

                    $start_coord = 1 if $start_coord < 1;

                    # get scaffold length
                    my $len;
                    if ( $in_file ) {
                        #metagenome
                        ( $t_oid, $t_s_oid ) = split( /\./, $curr_scaf_id );
                        ( $type,  $s_oid )   = split( /\:/, $t_s_oid );
                        ( $len, undef ) = MetaUtil::getScaffoldStats( $t_oid, $type, $s_oid );
                    } else {
                        my ( $curr_scaf_taxon, $curr_scaf_ext ) = split( /\./, $curr_scaf_id );
                        my $rclause   = WebUtil::urClause('ss.taxon');
                        my $imgClause = WebUtil::imgClauseNoTaxon('ss.taxon');
                        my $sql       = qq{
                            select ss.scaffold_oid, ss.seq_length
                            from scaffold_stats ss, scaffold s
                            where ss.scaffold_oid = s.scaffold_oid
                                and s.taxon = ?
                                and s.ext_accession = ?
                                $rclause
                                $imgClause
                        };
                        my $dbh = WebUtil::dbLogin();

                        #print "[$curr_scaf_taxon, $curr_scaf_ext]<br>sql1:[$sql]<br>";
                        my $cur = execSql( $dbh, $sql, $verbose, $curr_scaf_taxon, $curr_scaf_ext );
                        for ( ; ; ) {
                            my ( $s_oid, $s_len ) = $cur->fetchrow();
                            last if !$s_oid;
                            $len = $s_len;
                        }
                    }
                    $end_coord = $len if ( $end_coord > $len );

                    #print "coords: [start $start_coord, end:$end_coord, 1: $coord1, 2: $coord2]<br>";
                }    # if ( $end_coord - $start_coord < $show_length )
                     # mark genes overlapping with aligned region as marker genes
                my $marker_gene_oid;
                if ( $in_file ) {
                    #webLog("here 5 $s\n");
                    #webLog("here 5-1  $curr_scaf_id $t_oid, $type, $s_oid\n");

                    # bug fix http://issues.jgi-psf.org/browse/IMGSUPP-127

                    if ( $t_oid eq '' ) {
                        ( $t_oid, $t_s_oid ) = split( /\./, $curr_scaf_id );
                        ( $type,  $s_oid )   = split( /\:/, $t_s_oid );
                    }

                    #webLog("here 5-1a $t_oid, $type, $s_oid\n");

                    my @genes_on_s = MetaUtil::getScaffoldGenes( $t_oid, $type, $s_oid );
                    #webLog("here 5-2\n");
                    for my $g2 (@genes_on_s) {
                        my ( $hit_gene_oid, $hit_gene_locus_type, $hit_gene_locus_tag, $hit_gene_display_name,
                            $hit_gene_start_coord, $hit_gene_end_coord, undef )
                          = split( /\t/, $g2 );
                        last if ( !$hit_gene_oid );
                        if (   $hit_gene_start_coord > $coord2
                            || $hit_gene_end_coord < $coord1 )
                        {

                            # no overlap
                        } else {
                            $marker_gene_oid = $hit_gene_oid;

                            #print "marker gene: [$marker_gene_oid]<br>";
                            last;

                            # There might be (very unlikely?) multiple genes
                            # covering this region. Only the first one is highlighted
                            # as marker gene now. Changes are needed if we want to
                            # highlight more than one genes. - yjlin 04/11/2014
                        }

                    }

                } else {    
                    my ( $curr_scaf_taxon, $curr_scaf_ext ) = split( /\./, $curr_scaf_id );
                    my $rclause   = WebUtil::urClause('g.taxon');
                    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
                    my $sql       = qq{
                        select g.gene_oid, g.start_coord, g.end_coord
                        from gene g, scaffold s
                        where g.scaffold = s.scaffold_oid
                            and s.taxon = ?
                            and s.ext_accession = ?
                            $rclause
                            $imgClause
                    };
                    my $dbh = WebUtil::dbLogin();

                    #print "[$curr_scaf_taxon, $curr_scaf_ext]<br>sql2:[$sql]<br>";
                    my $cur = execSql( $dbh, $sql, $verbose, $curr_scaf_taxon, $curr_scaf_ext );
                    for ( ; ; ) {
                        my ( $hit_gene_oid, $hit_gene_start_coord, $hit_gene_end_coord ) = $cur->fetchrow();
                        last if !$hit_gene_oid;
                        if ( $hit_gene_start_coord > $hit_gene_end_coord ) {
                            my $tmp = $hit_gene_start_coord;
                            $hit_gene_start_coord = $hit_gene_end_coord;
                            $hit_gene_end_coord   = $tmp;

                            # hit_gene_start_coord and hit_gene_end_coord is only
                            # used to compare with coord1 and coord2. hit_gene_start_coord
                            # is always smaller than hit_gene_end_coord.
                        }
                        if (   ( $hit_gene_start_coord > $coord1 && $hit_gene_start_coord > $coord2 )
                            || ( $hit_gene_end_coord < $coord1 && $hit_gene_end_coord < $coord2 ) )
                        {

                            # no overlap
                        } else {
                            $marker_gene_oid = $hit_gene_oid;

                            #print "marker gene: [$marker_gene_oid]";
                            #print "coords: [$hit_gene_start_coord, $hit_gene_end_coord]<br>";
                            last;

                            # There might be (very unlikely?) multiple genes
                            # covering this region. Only the first one is highlighted
                            # as marker gene now. Changes are needed if we want to
                            # highlight more than one genes. - yjlin 04/11/2014
                        }
                    }

                }
                
                my $url;
                if ( $in_file ) {
                    $url = "$main_cgi?section=MetaScaffoldGraph";
                    $url .= "&page=metaScaffoldGraph&taxon_oid=$t_oid&scaffold_oid=$s_oid";
                    $url .= "&start_coord=$start_coord&end_coord=$end_coord";
                } else {
                    # Bug https://issues.jgi-psf.org/browse/IMGSUPP-604 - ken
                    my $tax;
                    my $curr_scaf_id2;
#print "0 - $curr_scaf_id <br>\n";                    
                    if($curr_scaf_id =~ /\./) {
                        my $junk;
                        my @a = split(/\./, $curr_scaf_id, 2);
                        $tax = $accession2tax_href->{$curr_scaf_id};
                        $curr_scaf_id2 = $tax . "," . $a[1]; # we need the ext_acc id not the scaffold oid

#print "1 scaffold oid = $curr_scaf_id2   tax = $tax <br>\n";

                    } else {
                        $tax = $accession2tax_href->{$curr_scaf_id};
                        $curr_scaf_id2 = $tax . "," . $curr_scaf_id;

#print "2 scaffold oid = $curr_scaf_id  tax = $tax <br>\n";                       
                    }
                    $url = "$main_cgi?section=ScaffoldGraph";
                    $url .= "&page=alignment&scaffold_id=$curr_scaf_id2";
                    $url .= "&coord1=$coord1&coord2=$coord2";
                }
                $url .= "&marker_gene=$marker_gene_oid"
                  if ( $marker_gene_oid ne "" );
                my $x1 = "<a href='$url'>";
                my $x2 = "</a>";
                $s =~ s/ $coord1 / ${x1}${coord1}${x2} /;
            }

            print "$s\n";
        } else {
            print "$s\n";
        }

        if ( $img_internal || $img_er ) {
            if ( $s =~ /Score =/ ) {

                # Score = 70.5 bits (171), Expect = 8e-14
                my @tmp = split( /\s/, $s );
                my $in = 0;
                foreach my $x (@tmp) {
                    next if ( $x =~ /\s/ );
                    next if ( $x eq "" );
                    if ( $x eq "=" ) {
                        $in = 1;
                    } elsif ( $in == 1 ) {
                        $bit_score = $x;
                        last;
                    }
                }

                # its 3 because there are spaces in the front of the line
                #$bit_score = $tmp[3];
                $evalue = $tmp[$#tmp];
            }

            if ( $s =~ /Frame =/ ) {
                if ( $curr_qstart != -1 ) {
                    push( @query_coords, "$curr_qstart,$curr_qend" );
                    if ( !$taxon_oid ) {
                        push( @subjt_coords, "$curr_sstart,$curr_send,$frame," . "$curr_scaf_id,$bit_score,$evalue" );
                    } else {
                        push( @subjt_coords,
                            "$curr_sstart,$curr_send,$frame,$taxon_oid," . "$curr_scaf_id,$bit_score,$evalue" );
                    }
                }

                my @tmp = split( /\s/, $s );
                $frame       = $tmp[$#tmp];
                $curr_qstart = -1;
                $curr_qend   = -1;
                $curr_sstart = -1;
                $curr_send   = -1;
            }

            # find coord lines
            # Sbjct: start seq end
            if ( $s =~ /^Sbjct/ ) {
                if ( $s =~ /^Sbjct <a href='.*>(\d+)<\/a>.* (\d+)/ ) {

                    # start is a link
                    # ^Sbjct <a href='.*>(\d+)</a>.* (\d+)
                    #push( @subjt_coords, "$1,$2,$frame" );
                    $curr_sstart = $1;
                    $curr_send   = $2;

                } else {
                    my @tmp = split( /\s/, $s );
                    $curr_send = $tmp[$#tmp];
                }
            } elsif ( $s =~ /^Query/ ) {
                my @tmp = split( /\s/, $s );
                $curr_qstart = $tmp[1] if ( $curr_qstart == -1 );
                $curr_qend = $tmp[$#tmp];
            }
        }

    }
    if ( $curr_qstart != -1 ) {
        push( @query_coords, "$curr_qstart,$curr_qend" );
        if ( !$taxon_oid ) {
            push( @subjt_coords, "$curr_sstart,$curr_send,$frame," . "$curr_scaf_id,$bit_score,$evalue" );
        } else {
            push( @subjt_coords, "$curr_sstart,$curr_send,$frame,$taxon_oid," . "$curr_scaf_id,$bit_score,$evalue" );
        }
    }

    return ( \@query_coords, \@subjt_coords );
}

############################################################################
# getScaffoldIds - get scaffold_oid with given taxon_oid and ext_accession,
############################################################################
sub getScaffoldIds {
    my ( $taxon_oids_ref, $ext_accessions_ref ) = @_;

    my %accession2scaf_h;
    my %accession2tax_h;

    my $dbh       = WebUtil::dbLogin();
    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

    my $taxonClause;
    if ( scalar(@$taxon_oids_ref) > 0 ) {
        my $taxon_oids_str = OracleUtil::getNumberIdsInClause( $dbh, @$taxon_oids_ref );
        $taxonClause = "and s.taxon in ($taxon_oids_str) ";
    }
    my $ext_accessions_str = OracleUtil::getFuncIdsInClause( $dbh, @$ext_accessions_ref );
 
    my $sql = qq{
        select s.taxon, s.ext_accession, s.scaffold_oid 
        from scaffold s
        where 1 = 1
        $taxonClause
        and s.ext_accession in ($ext_accessions_str)
        $rclause
        $imgClause
    };
    #print "getScaffoldIds() sql: $sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $ext_accession, $scaffold_oid ) = $cur->fetchrow();
        last if !$taxon_oid;

        $accession2scaf_h{$ext_accession} = $scaffold_oid;
        $accession2tax_h{$ext_accession}  = $taxon_oid;
        my $t_accession = $taxon_oid . '.' . $ext_accession;
        $accession2scaf_h{$t_accession} = $scaffold_oid;
        $accession2tax_h{$t_accession}  = $taxon_oid;
        #print "getScaffoldIds() added taxon=$taxon_oid scaffold=$scaffold_oid for $t_accession<br/>\n";
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" )  if ( $taxonClause        =~ /gtt_num_id/i );
    OracleUtil::truncTable( $dbh, "gtt_func_id" ) if ( $ext_accessions_str =~ /gtt_func_id/i );

    #print "getScaffoldIds() accession2scaf_h=<br/>\n";
    #print Dumper \%accession2scaf_h;
    #print "<br/>\n";
    #print "getScaffoldIds() accession2tax_h=<br/>\n";
    #print Dumper \%accession2tax_h;
    #print "<br/>\n";

    return ( \%accession2scaf_h, \%accession2tax_h );
}

############################################################################
# processProteinBlastResult - Process the result of protein blast
############################################################################
sub processProteinBlastResult {
    my ( $lines_ref, $taxon_oid, $scaffold_oid, $in_file ) = @_;

    my @query_coords;
    my @subjt_coords;

    my $frame       = 0;
    my $bit_score   = 0;
    my $e_value     = 0;
    my $curr_qstart = -1;
    my $curr_qend   = -1;
    my $curr_sstart = -1;
    my $curr_send   = -1;
    my $curr_sgene  = -1;

    my %someId2url;
    my $inSummary = 0;
    for my $s (@$lines_ref) {
        chomp $s;

        # missing gene how to parse this blastx page?
        if ( $s =~ /^Sequences producing significant alignments/ ) {
            $inSummary = 1;
            print "$s\n";
        } elsif ( $inSummary && !blankStr($s) && $s =~ /^[0-9A-Za-z]+/ ) {
            my $s2 = $s;
            $s2 =~ s/\s+/ /g;
            my $gene_id = findID($s2);

            #print "processProteinBlastResult() inSummary curr_gene_id: $gene_id<br/>\n";

            my $checkbox;
            my $url;
            if ( $in_file ) {
                my ( $t_oid, $t_g_oid ) = split( /\./, $gene_id, 2 );
                my ( $data_type, $g_oid ) = split( /\:/, $t_g_oid );
                $data_type = 'assembled'   if ( $data_type eq 'a' );
                $data_type = 'unassembled' if ( $data_type eq 'u' );
                my $workspace_id = "$t_oid $data_type $g_oid";
                $checkbox = "<input type='checkbox' name='gene_oid' " 
                    . "value='$workspace_id'/>";
                $url      =
                    "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
                  . "&taxon_oid=$taxon_oid&data_type=$data_type&gene_oid=$g_oid";
                $someId2url{$gene_id} = $url;
            } else {
                $checkbox = "<input type='checkbox' name='gene_oid' " 
                    . "value='$gene_id'/>";
                $url = "$main_cgi?section=GeneDetail" 
                    . "&page=geneDetail&gene_oid=$gene_id";
                $someId2url{$gene_id} = $url;
            }
            my $x1 = "<a href='$url'>";
            my $x2 = "</a>";
            $s =~ s/$gene_id/${x1}${gene_id}${x2}/;
            $s = $checkbox . ' ' . $s;
            print "$s\n";
        } elsif ( $s =~ /^>/ ) {
            $inSummary = 0;
            if ( $curr_qstart != -1 ) {

                # now push data to array
                push( @query_coords, "$scaffold_oid,$curr_qstart,$curr_qend" );
                if ( !$taxon_oid ) {
                    push( @subjt_coords, "$curr_sstart,$curr_send,$frame," . "$curr_sgene,$bit_score,$e_value" );
                } else {
                    push( @subjt_coords, "$taxon_oid,$curr_sstart,$curr_send,$frame," . "$curr_sgene,$bit_score,$e_value" );
                }
            }
            $curr_qstart = -1;
            $curr_qend   = -1;
            $curr_sstart = -1;
            $curr_send   = -1;
            $curr_sgene  = -1;

            my $gene_id = findID($s);
            my $url     = $someId2url{$gene_id};
            if ($url) {
                my $x1 = "<a href='$url'>";
                my $x2 = "</a>";
                $s =~ s/${gene_id}/${x1}${gene_id}${x2}/;
            }
            print "$s\n";

            $curr_sgene = $gene_id;
        } else {
            print "$s\n";
        }

        if ( $s =~ /^Sbjct/ ) {
            my @tmp = split( /\s/, $s );
            $curr_sstart = $tmp[1] if ( $curr_sstart == -1 );
            $curr_send = $tmp[$#tmp];
        } elsif ( $s =~ /^Query/ ) {
            my @tmp = split( /\s/, $s );
            $curr_qstart = $tmp[1] if ( $curr_qstart == -1 );
            $curr_qend = $tmp[$#tmp];
        } elsif ( $s =~ /Score =/ ) {
            if ( $curr_qstart != -1 ) {

                # now push data to array
                push( @query_coords, "$scaffold_oid,$curr_qstart,$curr_qend" );
                if ( !$taxon_oid ) {
                    push( @subjt_coords, "$curr_sstart,$curr_send,$frame," . "$curr_sgene,$bit_score,$e_value" );
                } else {
                    push( @subjt_coords, "$taxon_oid,$curr_sstart,$curr_send,$frame," . "$curr_sgene,$bit_score,$e_value" );
                }

                $curr_qstart = -1;
                $curr_qend   = -1;
                $curr_sstart = -1;
                $curr_send   = -1;
            }

            #  Score = 56.2 bits (134), Expect = 1e-09
            $s =~ /^\s+.* (\d+\.*\d*) .* (\d+e-*\d+)$/;
            $bit_score = $1;
            $e_value   = $2;
            if ( $bit_score eq "" || $e_value eq "" ) {

                # from scaffold viewer
                # Score = 1053 bits (2722), Expect = 0.0
                # hit itself
                $s =~ /^\s+.* (\d+\.*\d*) .* (\d+\.*\d*)$/;
                $bit_score = $1;
                $e_value   = $2;
            }
        } elsif ( $s =~ /Frame =/ ) {

            # frame
            my @tmp = split( /\s/, $s );
            $frame = $tmp[$#tmp];
        }
    }
    if ( $curr_qstart != -1 ) {

        # now push data to array
        push( @query_coords, "$scaffold_oid,$curr_qstart,$curr_qend" );
        if ( !$taxon_oid ) {
            push( @subjt_coords, "$curr_sstart,$curr_send,$frame," . "$curr_sgene,$bit_score,$e_value" );
        } else {
            push( @subjt_coords, "$taxon_oid,$curr_sstart,$curr_send,$frame," . "$curr_sgene,$bit_score,$e_value" );
        }
    }

    return ( \@query_coords, \@subjt_coords );
}

############################################################################
# findID - find ID
############################################################################
sub findID {
    my ($line) = @_;
    my ( $id_str, $junk1 ) = split( / /, $line );
    $id_str =~ s/^>//;
    my $id_new_str = removeDatabaseNamePrefix($id_str);
    $id_new_str =~ s/^>//;

    return $id_new_str;
}

############################################################################
# removeDatabaseNamePrefix - remove 'gnl|' or 'lcl|', etc.
############################################################################
sub removeDatabaseNamePrefix {
    my ($str) = @_;

    if ( $str =~ /\|/ ) {
        my ( $dbName, $newStr ) = split( /\|/, $str );
        return $newStr;
    }
    return $str;
}

###########################################################################
# waitForResults
###########################################################################
sub waitForResults {
    my ( $reportFile, $qFile ) = @_;

    my $rFile = $qFile;
    $rFile =~ s/\.q$/.r/;
    my $reportPath = "$common_tmp_dir/$reportFile";

    printStartWorkingDiv("waitForResults");
    for ( my $i = 0 ; $i < 10000 ; $i++ ) {
        my @files = dirList($blast_q_dir);
        my $count = 0;
        for my $f (@files) {
            next if $f !~ /\.q$/ && $f !~ /\.r$/;
            $count++;
            if ( $f eq $qFile || $f eq $rFile ) {
                last;
            }
        }
        print "Waiting on $count job(s) " . currDateTime() . "<br/>\n";
        if ( $count == 0 ) {
            print "No more jobs in queue " . currDateTime() . "<br/>\n";
            sleep 5;
            last;
        }
        sleep 30;
        if ( -e $reportPath ) {
            print "BLAST done " . currDateTime() . "<br/>\n";
            last;
        }
    }
    printEndWorkingDiv("waitForResults");
}

1;

