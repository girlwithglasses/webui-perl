###########################################################################
#
# $Id: SequenceExportUtil.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
#
###########################################################################
package SequenceExportUtil;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use Bio::Perl;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;
use Bio::Location::Split;
use Bio::Location::Simple;
use Bio::LocationI;
use IO::String;
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use MerFsUtil;
use MetaUtil;
use GeneUtil;
use OracleUtil;

$| = 1;

my $env                 = getEnv();
my $cgi_dir             = $env->{cgi_dir};
my $cgi_url             = $env->{cgi_url};
my $main_cgi            = $env->{main_cgi};
my $inner_cgi           = $env->{inner_cgi};
my $tmp_url             = $env->{tmp_url};
my $verbose             = $env->{verbose};

my $taxon_faa_dir       = $env->{taxon_faa_dir};
my $taxon_fna_dir       = $env->{taxon_fna_dir};
my $taxon_lin_fna_dir   = $env->{taxon_lin_fna_dir};
my $cgi_tmp_dir         = $env->{cgi_tmp_dir};

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) { 
    $merfs_timeout_mins = 60; 
} 

my $gene_batch_size = 20000;

my $no_sequence_found = "No sequence found\n";
#my $no_sequence_found = "\n";

############################################################################
# printGeneFaaSeq - Print FASTA amino acid sequences. Export.
############################################################################
sub printGeneFaaSeq {
    my ($genes_ref, $outFile) = @_;

    my @gene_oids;
    if ($genes_ref) {
        @gene_oids = @$genes_ref;
    }
    else {
        @gene_oids = param("gene_oid");
    }

    if ( scalar(@gene_oids) <= 0) {
        webError("Select genes first.");
    }

    my $wfh;
    if ( $outFile ) {
        $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
    }

    if (!$wfh) {
        print "<h1>Export Gene Fasta Amino Acid Sequence</h1>\n";
        print "<pre>\n";
    }

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if (scalar(@dbOids) > 0) {
        my $dbh = dbLogin();
        printFaaSeqDb( $dbh, \@dbOids, $wfh );
        #$dbh->disconnect();
    }

    if (scalar(@metaOids) > 0) {
        timeout( 60 * $merfs_timeout_mins ); 
        
        for my $key ( sort @metaOids ) {            
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );
            my $seq = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
            
            my $seq2;
            if ( blankStr($seq) ) {
                webLog( "printGeneFaaSeq() no aa sequence found for gene_oid=$gene_oid\n" );
                $seq2 = $no_sequence_found;
            }
            else {
                $seq2 = WebUtil::wrapSeq($seq);
            }    
            
            my ( $new_name, $source ) = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
            if ($wfh) {
                print $wfh ">$gene_oid $new_name\n";
                print $wfh "$seq2\n";
            }
            else {
                print "<font color='blue'>";
                print ">$gene_oid $new_name";
                print "</font>\n";
                print "$seq2\n";
            }
        }   # end for my key

    }

    if (!$wfh) {
        print "</pre>\n";
    }

    if ( $wfh ) {
        close $wfh;
    }

}

### Batch support subroutine.
sub printFaaSeqDb {
    my ( $dbh, $geneOids_ref, $wfh ) = @_;

    my $rclause = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    
    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$geneOids_ref );
    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.locus_tag, g.gene_symbol, 
	       tx.genus, tx.species, g.aa_residue, scf.scaffold_name
        from  gene g, taxon tx, scaffold scf
        where g.taxon = tx.taxon_oid
        and g.gene_oid in( $gene_oid_str )
    	and g.scaffold = scf.scaffold_oid
        $rclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name, $locus_tag, $gene_symbol, $genus,
             $species, $aa_residue, $scaffold_name )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $seq;
        if ( blankStr($aa_residue) ) {
            webLog( "printFaaSeqDb() no aa sequence found for gene_oid=$gene_oid\n" );
            $seq = $no_sequence_found;
        }
        else {
            $seq = WebUtil::wrapSeq($aa_residue);
        }
        
        my $ids;
        $ids = $locus_tag   if !blankStr($locus_tag);
        $ids = $gene_symbol if !blankStr($gene_symbol);
        if ($wfh) {
            print $wfh ">$gene_oid $ids $gene_display_name [$scaffold_name]\n";
            print $wfh "$seq\n";
        }
        else {
            print "<font color='blue'>";
            print ">$gene_oid $ids $gene_display_name [$scaffold_name]";
            print "</font>\n";
            print "$seq\n";
        }
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $gene_oid_str =~ /gtt_num_id/i );

}

############################################################################
## getGeneFnaSeq - returns FASTA nucleic acid sequence in a hash
# Input: an array of gene_oids 
# For genes in DB only, not for MER-FS
# Similar to printGeneFnaSeq, but it doesn't print to ui. 
# Instead, it returns a hash of gene sequences to its caller.
############################################################################
sub getGeneFnaSeqDb {
    my ($genes_ref) = @_;

    my @gene_oids;
    if ($genes_ref) {
        @gene_oids = @$genes_ref;
    }
    else {
        @gene_oids = param("gene_oid");
    }

    my $up_stream       = param("up_stream");
    my $down_stream     = param("down_stream");
    $up_stream = 0 if ( !$up_stream );
    $down_stream = 0 if ( !$down_stream );

    my $up_stream_int   = sprintf( "%d", $up_stream );
    my $down_stream_int = sprintf( "%d", $down_stream );
    $up_stream   =~ s/\s+//g;
    $down_stream =~ s/\s+//g;

    if ( scalar(@gene_oids) <= 0) {
        webError("Select genes first.");
    }
    if ( $up_stream_int > 0 || !isInt($up_stream) ) {
        webError("Expected negative integer for up stream.");
    }
    if ( $down_stream_int < 0 || !isInt($down_stream) ) {
        webError("Expected positive integer for down stream.");
    }

    my %seqHashDb;
    if (scalar(@gene_oids) > 0) {
        my $dbh = dbLogin();
        my @recs = getFnaSeqDbRecs( $dbh, \@gene_oids );
        for my $rec ( @recs ) {
            my ( $seq, $gene_oid, @junk ) 
                = processFnaSeqDbRec( $dbh, $rec, $up_stream, $down_stream );
            $seqHashDb{$gene_oid} = $seq;
        }
    }

    return \%seqHashDb;

}

############################################################################
# printGeneFnaSeq - Show FASTA nucleic acid sequence. Export.
#  Inputs parameters:
#    gene_oid - gene object identifer
#    up_stream - up stream offset
#    down_stream - down stream offset
############################################################################
sub printGeneFnaSeq {
    my ($genes_ref, $outFile) = @_;

    my @gene_oids;
    if ($genes_ref) {
        @gene_oids = @$genes_ref;
    }
    else {
        @gene_oids = param("gene_oid");
    }

    my $up_stream       = param("up_stream");
    my $down_stream     = param("down_stream");
    my $up_stream_int   = sprintf( "%d", $up_stream );
    my $down_stream_int = sprintf( "%d", $down_stream );
    $up_stream   =~ s/\s+//g;
    $down_stream =~ s/\s+//g;

    if ( scalar(@gene_oids) <= 0) {
        webError("Select genes first.");
    }

    if ( $up_stream_int > 0 || !isInt($up_stream) ) {
        webError("Expected negative integer for up stream.");
    }
    if ( $down_stream_int < 0 || !isInt($down_stream) ) {
        webError("Expected positive integer for down stream.");
    }

    my $wfh;
    if ( $outFile ) {
        $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
    }

    if (!$wfh) {
        print "<h1>Export Gene Fasta Nucleic Acid Sequence</h1>\n";

        print "<font color='red'>Red</font> = start or stop codon, ";
        print "<font color='green'>Green</font> "
          . "= upstream or downstream padding.<br>\n";
    
        print "<pre>\n";
    }

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@gene_oids);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if (scalar(@dbOids) > 0) {
        my $dbh = dbLogin();
        printFnaSeqDb( $dbh, \@dbOids, $up_stream, $down_stream, $wfh );
        #$dbh->disconnect();
    }

    if (scalar(@metaOids) > 0) {
        timeout( 60 * $merfs_timeout_mins ); 

        my %scaf2fna_h;
        for my $key ( sort @metaOids ) {
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );
            my @vals = MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
            my $j = 0;
            if ( scalar(@vals) > 7 ) {
                $j = 1;
            }
            my $locus_type        = $vals[$j];
            my $gene_display_name = $vals[ $j + 2 ];
            my $start_coord0       = $vals[ $j + 3 ];
            my $end_coord0         = $vals[ $j + 4 ];
            my $strand            = $vals[ $j + 5 ];
            my $scaffold_oid      = $vals[ $j + 6 ];

            my $workspace_id = "$taxon_oid $data_type $scaffold_oid";
            my $seq = $scaf2fna_h{$workspace_id};
            if ( !$seq ) {
                $seq = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );
                if ( $seq ) {
                    $scaf2fna_h{$workspace_id} = $seq;
                }
            }
    
            my $start_coord = $start_coord0 + $up_stream; 
            $start_coord = 1 if $start_coord < 1; 
            my $end_coord = $end_coord0 + $down_stream;
            if ( $strand eq "-" ) {
                $start_coord = $start_coord0 - $down_stream; 
                $end_coord   = $end_coord0 - $up_stream;
            } 
    
            if ( $start_coord < 1 ) {
                $start_coord = 1;
            }
            if ( $end_coord < 0 ) {
                $end_coord = $end_coord0;
            }
    
            my $gene_seq = "";
            if ( $strand eq '-' ) {
                $gene_seq = WebUtil::getSequence( $seq, $end_coord, $start_coord );
            }
            else {
                $gene_seq = WebUtil::getSequence( $seq, $start_coord, $end_coord );
            }
    
            if ( !$gene_display_name ) {
                my ($new_name, $source) = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
                $gene_display_name = $new_name;
            }

            if ( $wfh ) {
                print $wfh ">$gene_oid $gene_display_name [$scaffold_oid] strand($strand)\n";
            }
            else {
                print "<font color='blue'>";
                print ">$gene_oid $gene_display_name [$scaffold_oid] strand($strand)";
                print "</font>\n";
            }

            if ( blankStr($seq) ) {
                webLog "printGeneFnaSeq() no dna sequence for gene_oid=$gene_oid\n";
                if ( $wfh ) {
                    print $wfh "$no_sequence_found\n";
                }
                else {
                    print "$no_sequence_found\n";                
                }
            }
            else {
                my $seq2 = WebUtil::wrapSeq($gene_seq);
                if ( $wfh ) {
                    print $wfh "$seq2\n";
                }
                else {
                    $seq2 =~ s/\n//g;
                    colorSequence($seq2, $locus_type, $strand, $start_coord0, $end_coord0,
                          $start_coord, $end_coord);                
                }                
            }
        }  # end for my key
        
    }

    if (!$wfh) {
        print "</pre>\n";
    } else {
        close $wfh;
    }
    
}

sub getFnaSeqDbRecs {
    my ( $dbh, $geneOids_ref ) = @_;

    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $gene_oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$geneOids_ref );
    my $sql          = qq{
        select g.gene_oid, g.gene_display_name, g.locus_type, g.taxon,
              g.start_coord, g.end_coord, g.strand, g.cds_frag_coord, 
              scf.ext_accession, scf.scaffold_name, ss.seq_length
        from gene g, scaffold scf, scaffold_stats ss
        where g.scaffold = scf.scaffold_oid
        and scf.scaffold_oid = ss.scaffold_oid
        and g.start_coord > 0
        and g.end_coord > 0
        and g.gene_oid in ( $gene_oid_str )
        $rclause
        $imgClause
    };
    #print "getFnaSeqDbRecs() sql=$sql<br/>\n";

    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
             $gene_oid,       $gene_display_name, $locus_type, $taxon_oid,
             $start_coord0,   $end_coord0,        $strand, $cds_frag_coord,
             $ext_accession,  $scaffold_name,     $scf_seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;

        my $rec;
        $rec .= $gene_oid . "\t";
        $rec .= $gene_display_name . "\t";
        $rec .= $locus_type . "\t";
        $rec .= $taxon_oid . "\t";
        $rec .= $start_coord0 . "\t";
        $rec .= $end_coord0 . "\t";
        $rec .= $strand . "\t";
        $rec .= $cds_frag_coord . "\t";
        $rec .= $ext_accession . "\t";        
        $rec .= $scaffold_name . "\t";        
        $rec .= $scf_seq_length;        
        push(@recs, $rec);
    }
    $cur->finish();

    OracleUtil::truncTable( $dbh, "gtt_num_id" )
      if ( $gene_oid_str =~ /gtt_num_id/i );

    return ( @recs );
}

############################################################################
## processFnaSeqDbRec
############################################################################
sub processFnaSeqDbRec {
    my ( $dbh, $rec, $up_stream, $down_stream ) = @_;

    my (
         $gene_oid,       $gene_display_name, $locus_type, $taxon_oid,      
         $start_coord0,   $end_coord0,        $strand,     $cds_frag_coord,
         $ext_accession,  $scaffold_name,     $scf_seq_length
      )
      = split(/\t/, $rec);
    
    # Reverse convention for reverse strand.
    my $start_coord = $start_coord0 + $up_stream;
    my $end_coord = $end_coord0 + $down_stream;
    if ( $strand eq "-" ) {
        $start_coord = $start_coord0 - $down_stream;
        $end_coord   = $end_coord0 - $up_stream;
    }

    $start_coord   = 1               if $start_coord < 1;
    $end_coord     = $scf_seq_length if $end_coord > $scf_seq_length;

    my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );
    my @adjustedCoordsLines = GeneUtil::adjustMultFragCoordsLine( \@coordLines, $strand, $up_stream, $down_stream );

    #webLog "$ext_accession $start_coord..$end_coord fragments(@coordLines) ($strand)\n"
    #     if $verbose >= 1;

    my $path = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
    my $seq = WebUtil::readLinearFasta( $path, $ext_accession, 
                     $start_coord, $end_coord, $strand, \@adjustedCoordsLines );

    my $nameLine = "$gene_display_name [$scaffold_name]";

    return ( $seq, $gene_oid, $nameLine, $locus_type, $taxon_oid, $ext_accession,
             $start_coord, $end_coord, $start_coord0, $end_coord0, $strand, 
             \@coordLines, $path );
}

############################################################################
## Batch support routine
############################################################################
sub printFnaSeqDb {
    my ( $dbh, $geneOids_ref, $up_stream, $down_stream, $wfh ) = @_;

    my @recs = getFnaSeqDbRecs( $dbh, $geneOids_ref );
            
    for my $rec ( @recs ) {

        my ( $seq, $gene_oid, $nameLine, $locus_type, $taxon_oid, $ext_accession,
             $start_coord, $end_coord, $start_coord0, $end_coord0, $strand, 
             $coordLines_ref, $path ) 
            = processFnaSeqDbRec( $dbh, $rec, $up_stream, $down_stream );

        if ($wfh) {
            print $wfh ">$gene_oid $nameLine ($strand)strand\n";
        }
        else {
            print "<font color='blue'>";
            print ">$gene_oid $nameLine ($strand)strand";
            print "</font>\n";
        }

        if ( blankStr($seq) ) {
            webLog "printFnaSeqDb() no dna sequence for gene_oid=$gene_oid\n";
            if ( $wfh ) {
                print $wfh "$no_sequence_found\n";
            }
            else {
                print "$no_sequence_found\n";                
            }
        }
        else {
            my $seq2 = WebUtil::wrapSeq($seq);
            if ( $wfh ) {
                print $wfh "$seq2\n";
            }
            else {
                $seq2 =~ s/\n//g;
                colorSequence($seq2, $locus_type, $strand, $start_coord0, $end_coord0,
                      $start_coord, $end_coord, $coordLines_ref);            
            }
        }
    }

}

############################################################################
# colorSequence
############################################################################
sub colorSequence {
    my ($seq, $locus_type, $strand, $start_coord0, $end_coord0, 
	    $start_coord, $end_coord, $coordLines_ref, $wfh) = @_;

    my $us_len = $start_coord0 - $start_coord;    # upstream length
    $us_len = $end_coord - $end_coord0 if $strand eq "-"; 
    $us_len = 0 if $us_len < 0;
    
    my $dna_len;
    if ( $coordLines_ref ne '' && scalar(@$coordLines_ref) > 1 ) {
        $dna_len = GeneUtil::getMultFragCoordsLength(@$coordLines_ref);
    }
    else {
        $dna_len = $end_coord0 - $start_coord0 + 1;
    }
    #print "colorSequence() ($start_coord0, $end_coord0), ($start_coord, $end_coord), $us_len, $dna_len\n";

    my $dna_len1 = 3;                             # start codon
    my $dna_len2 = $dna_len - 6;                  # middle
    my $dna_len3 = 3;                             # end codon
    
    # Set critical coordinates from segment lengths.
    my $c0           = 1; 
    my $c1           = $c0 + $us_len;
    my $c2           = $c1 + $dna_len1;
    my $c3           = $c2 + $dna_len2; 
    my $c4           = $c3 + $dna_len3; 
    my $c1StartCodon = 0;
    my $startCodon0  = substr( $seq, $c1 - 1, 3 );
    $c1StartCodon = 1 if isStartCodon($startCodon0); 
    my $stopCodon0 = substr( $seq, $c3 - 1, 3 ); 
    my $c3StopCodon = 0; 
    $c3StopCodon = 1 if isStopCodon($stopCodon0);

    if ( $verbose >= 1 ) {
        webLog "start_coord0=$start_coord0 ";
        webLog "start_coord=$start_coord\n";
        webLog "end_coord=$end_coord ";
        webLog "end_coord0=$end_coord0 ";
        webLog "c0=$c0 c1=$c1 c2=$c2 c3=$c3 c4=$c4\n";
        webLog "startCodon0='$startCodon0' c1StartCodon=$c1StartCodon\n";
        webLog "stopCodon0 ='$stopCodon0' c3StopCodon=$c3StopCodon\n";
    } 

    printBases($seq, $locus_type, $c0, $c1, $c2, $c3, $c4, 
               $c1StartCodon, $c3StopCodon, $wfh);

}

############################################################################
sub printBases {
    my ($seq, $locus_type, $c0, $c1, $c2, $c3, $c4, 
        $c1StartCodon, $c3StopCodon, $wfh) = @_;
 
    my @bases        = split( //, $seq ); 
    my $baseCount    = 0;
    my $maxWrapCount = 50; 
    my $wrapCount    = 0;
    for my $b (@bases) { 
        $baseCount++; 
        $wrapCount++; 
     
        # upstream start
        if ( $baseCount == $c0 ) { 
            if ( !$wfh ) {
                print "<font color='green'>";
            }
        } 
     
        # start codon
        if ( $baseCount == $c1 ) { 
            if ( !$wfh ) {
                print "</font>";
                print "<font color='red'>"
                  if ( $c1StartCodon && $locus_type eq "CDS" );
            }
        }
     
        # dna body start
        if ( $baseCount == $c2 ) {
            if ( !$wfh ) {
                print "</font>" if ($c1StartCodon && $locus_type eq "CDS");
            }
        } 
     
        # stop codon
        if ( $baseCount == $c3 ) { 
            if ( !$wfh ) {
                print "</font>";
                print "<font color='red'>"
                  if ( $c3StopCodon && $locus_type eq "CDS" );
            }
        } 
        if ( $baseCount == $c4 ) {
            if ( !$wfh ) {
                print "</font>" if ($c3StopCodon && $locus_type eq "CDS");
                print "<font color='green'>";
            }
        } 
        if ( $wfh ) {
            print $wfh $b;
        }
        else {
            print $b;
        }
        if ( $wrapCount >= $maxWrapCount ) {
            if ( $wfh ) {
                print $wfh "\n";
            }
            else {
                print "\n";
            }
            $wrapCount = 0; 
        } 
    } 
    if ( !$wfh ) {
        print "</font>";
    }
    if ( $wfh ) {
        print $wfh "\n\n";
    }
    else {
        print "\n\n";
    }
}


############################################################################
# getGeneDnaSequence - Get DNA sequence given a gene.
############################################################################
sub getGeneDnaSequence {
    my ( $dbh, $gene_oid, $up_stream, $down_stream, $is_rna ) = @_;

    my @geneOids = ( $gene_oid );
    my @recs = getFnaSeqDbRecs( $dbh, \@geneOids );

    my ( $seq, $gene_oid2, $nameLine, $locus_type, $taxon_oid, $ext_accession,
         $start_coord, $end_coord, $start_coord0, $end_coord0, $strand, 
         $coordLines_ref, $path );

    if ( scalar(@recs) == 1 ) {                
        for my $rec ( @recs ) {
           ( $seq, $gene_oid2, $nameLine, $locus_type, $taxon_oid, $ext_accession,
             $start_coord, $end_coord, $start_coord0, $end_coord0, $strand, 
             $coordLines_ref, $path ) 
                = processFnaSeqDbRec( $dbh, $rec, $up_stream, $down_stream );
        }
    }

    if ( $is_rna ne "" && $start_coord == 0 && $end_coord == 0 ) {
        $seq = "na";
    }

    return ( $seq, $gene_oid, $nameLine, $locus_type, $taxon_oid, $ext_accession,
             $start_coord, $end_coord, $start_coord0, $end_coord0, $strand, 
             $coordLines_ref, $path );
}

############################################################################
# printGeneFnaSeqWorkspace
# write file one by one, browser friendly
############################################################################
sub printGeneFnaSeqWorkspace {
    my ($genes_ref, $outFile) = @_;

    webLog("SequenceExportUtil::printGeneFnaSeqWorkspace() into printGeneFnaSeqWorkspace: ". currDateTime() ."\n");

    my $wfh;
    if ( $outFile ) {
        $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
    }

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@$genes_ref);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    # process database genes first
    if (scalar(@dbOids) > 0) {
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace() start " . scalar(@dbOids). " db oids DNA sequence download: ". currDateTime() ."\n");

        my $dbh   = dbLogin();
        execExportGeneDNA($dbh, $wfh, \@dbOids);
        #$dbh->disconnect();
        
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace() done " . scalar(@dbOids). " db oids DNA sequence download: ". currDateTime() ."\n");
    }

    if (scalar(@metaOids) > 0) {
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace() start " . scalar(@metaOids). " meta oids DNA sequence download: ". currDateTime() ."\n");

        my %scaf2fna_h;
        for my $key ( @metaOids ) {
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );
                        
            my ($seq, $strand, $scaf_oid) = MetaUtil::getGeneFna($gene_oid, $taxon_oid, $data_type, \%scaf2fna_h);
                
            my $seq2;
            if ( blankStr($seq) ) {
                webLog( "printGeneFnaSeqWorkspace() no dna sequence found for worskpace gene_oid=$key\n" );
                $seq = $no_sequence_found;
            }
            else {
                $seq2 = WebUtil::wrapSeq($seq);
            }

            my ( $new_name, $source ) = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
            if ( $wfh ) {
                print $wfh ">$gene_oid $new_name [$scaf_oid] ($strand)strand\n";
                print $wfh "$seq2\n";
            }
            else {
                print ">$gene_oid $new_name [$scaf_oid] ($strand)strand\n";
                print "$seq2\n";
            }
            
        }  # end for my key

        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace() done " . scalar(@metaOids). " meta oids DNA sequence download: ". currDateTime() ."\n");
    }

    if ( $wfh ) {
        close $wfh;
    }
}

############################################################################
# printGeneFnaSeqWorkspace_toEmail - not used,incomplete,incorrect
# write file in block, not browser friendly
############################################################################
sub printGeneFnaSeqWorkspace_toEmail {
    my ($genes_ref, $outFile) = @_;

    webLog("SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail() into printGeneFnaSeqWorkspace: ". currDateTime() ."\n");

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@$genes_ref);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;
    #webLog("printGeneFnaSeqWorkspace_toEmail() dbOids: @dbOids<br/>\n");
    #webLog("printGeneFnaSeqWorkspace_toEmail() metaOids: @metaOids<br/>\n");

    # process database genes first
    if (scalar(@dbOids) > 0) {
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() start " . scalar(@dbOids). " db oids DNA sequence download: ". currDateTime() ."\n");

        my $wfh;
        if ( $outFile ) {
            $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
        }
        my $dbh   = dbLogin();
        execExportGeneDNA($dbh, $wfh, \@dbOids);
        if ( $wfh ) {
            close $wfh;
        }
        #$dbh->disconnect();
        
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail() done " . scalar(@dbOids). " db oids DNA sequence download: ". currDateTime() ."\n");
    }
    
    if (scalar(@metaOids) > 0) {
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail() start " . scalar(@metaOids). " meta oids DNA sequence download: ". currDateTime() ."\n");
        my $cnt0 = scalar(@metaOids);
        if ($cnt0 <= $gene_batch_size) {
            processBatchMetaGeneFnaSeqQorkspace_toEmail(\@metaOids, $outFile);
        }
        else {
            my $cnt1   = 0;
            my @batch = ();
            my @sorted_metaOids = sort @metaOids;
            for my $mOid (@sorted_metaOids) {
                push(@batch, $mOid);
                $cnt1++;    
                if ( ( $cnt1 % $gene_batch_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                    processBatchMetaGeneFnaSeqQorkspace_toEmail(\@batch, $outFile);
                    @batch = ();
                }                
            }
        }
       
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail() done " . scalar(@metaOids). " meta oids DNA sequence download: ". currDateTime() ."\n");
    }

}

sub processBatchMetaGeneFnaSeqQorkspace_toEmail {
    my ($batch_ref, $outFile) = @_;
    my @batch = @$batch_ref;
    
    if (scalar(@batch) > 0) {
        my %genes_h;
        for my $workspace_id ( @batch ) {
            $genes_h{$workspace_id} = 1;
        }

        my %taxon_genes = MetaUtil::getOrganizedTaxonGenes( @batch );
        
        my %gene_name_h;
        MetaUtil::getAllMetaGeneNames(\%genes_h, \@batch, \%gene_name_h, \%taxon_genes);
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail() done fetching " . scalar(@batch). " meta oids names: ". currDateTime() ."\n");

        my %gene_fna_h;
        my %gene_strand_h;
        my %gene_scaf_h;
        MetaUtil::getAllMetaGeneFna(\%genes_h, \@batch, \%gene_fna_h, \%gene_strand_h, \%gene_scaf_h, \%taxon_genes);
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail() done fetching " . scalar(@batch). " meta oids fastas: ". currDateTime() ."\n");

        my $wfh;
        if ( $outFile ) {
            $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
        }
        for my $key ( @batch ) {
            #webLog("SequenceExportUtil::printGeneFaaSeqWorkspace() meta oid $key: ". currDateTime() ."\n");
            # file
    
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );

            my $seq2;
            my $seq = $gene_fna_h{$key};
            if ($seq) {
                $seq2 = WebUtil::wrapSeq($seq);
            }
            else {
                webLog("printGeneFnaSeqWorkspace_toEmail() no dna sequence found for workspace gene_oid=$key\n");
                $seq2 = $no_sequence_found;
            }
            my $new_name = $gene_name_h{$key};
            my $strand = $gene_strand_h{$key};
            my $scaf_oid = $gene_scaf_h{$key};

            if ( $wfh ) {
                print $wfh ">$gene_oid $new_name [$scaf_oid] ($strand)strand\n";
                print $wfh "$seq2\n";
            }
            else {
                print ">$gene_oid $new_name [$scaf_oid] ($strand)strand\n";
                print "$seq2\n";
            }
        }  # end for my key
        if ( $wfh ) {
            close $wfh;
        }
        webLog("SequenceExportUtil::printGeneFnaSeqWorkspace_toEmail() done appending " . scalar(@batch). " meta oids sequence: ". currDateTime() ."\n");
    }
        
}

sub execExportGeneDNA {
    my ( $dbh, $wfh, $dbOids_ref ) = @_;

    my @recs = getFnaSeqDbRecs( $dbh, $dbOids_ref );
    for my $rec ( @recs ) {
        my (
             $gene_oid,      $gene_display_name, $locus_type, $taxon_oid,      
             $start_coord,   $end_coord,         $strand,     $cds_frag_coord,
             $ext_accession, $scaffold_name,     $scf_seq_length
          )
          = split(/\t/, $rec);
    
        $start_coord   = 1               if $start_coord < 1;
        $end_coord     = $scf_seq_length if $end_coord > $scf_seq_length;

        #my @coordLines;
        my @coordLines = GeneUtil::getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );

        #webLog "$ext_accession $start_coord..$end_coord fragments(@coordLines) ($strand)\n"
        #     if $verbose >= 1;

        my $path = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
        my $gene_seq = WebUtil::readLinearFasta( $path, $ext_accession, 
                         $start_coord, $end_coord, $strand, \@coordLines );

        my $seq2;
        if ( blankStr($gene_seq) ) {
            webLog( "execExportGeneDNA() no dna sequence found for gene_oid=$gene_oid\n" );
            $seq2 = $no_sequence_found;
        }
        else {
            $seq2 = wrapSeq($gene_seq);
        }

        if ($wfh) {
            print $wfh ">$gene_oid ";
            print $wfh "$gene_display_name [$scaffold_name] ($strand)strand\n";
            print $wfh "$seq2\n";                        
        }
        else {
            print ">$gene_oid ";
            print "$gene_display_name [$scaffold_name] ($strand)strand\n";
            print "$seq2\n";
        }

    }

}

sub getMetaGeneFnaAndStrand {
    my ( $taxon_oid, $data_type, $gene_oid ) = @_;

    my @vals = MetaUtil::getGeneInfo( $gene_oid, $taxon_oid, $data_type );
    my $j = 0;
    if ( scalar(@vals) > 7 ) {
        $j = 1;
    }
    my $locus_type        = $vals[$j];
    my $gene_display_name = $vals[ $j + 2 ];
    my $start_coord       = $vals[ $j + 3 ];
    my $end_coord         = $vals[ $j + 4 ];
    my $strand            = $vals[ $j + 5 ];
    my $scaffold_oid      = $vals[ $j + 6 ];

    my $seq = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );
    
    my $gene_seq = "";
    if ( $strand eq '-' ) {
        $gene_seq = WebUtil::getSequence( $seq, $end_coord, $start_coord );
    }
    else {
        $gene_seq = WebUtil::getSequence( $seq, $start_coord, $end_coord );
    }

    return ($gene_seq, $strand);
}


############################################################################
# printGeneFaaSeqWorkspace
# write file one by one, browser friendly
############################################################################
sub printGeneFaaSeqWorkspace {
    my ($genes_ref, $outFile) = @_;

    webLog("SequenceExportUtil::printGeneFaaSeqWorkspace() 0 ". currDateTime() ."\n");

    my $wfh;
    if ( $outFile ) {
        $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
    }

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@$genes_ref);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;
    #webLog("printGeneFaaSeqWorkspace() dbOids: @dbOids<br/>\n");
    #webLog("printGeneFaaSeqWorkspace() metaOids: @metaOids<br/>\n");

    # process database genes first
    if (scalar(@dbOids) > 0) {
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace() start " . scalar(@dbOids). " db oids AA sequence download: ". currDateTime() ."\n");
        my $dbh   = dbLogin();
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

        my $db_ids_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );
        execExportGeneAA($dbh, $wfh, $db_ids_str, $rclause, $imgClause);

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $db_ids_str =~ /gtt_num_id/i );
        #$dbh->disconnect();
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace() done " . scalar(@dbOids). " db oids AA sequence download: ". currDateTime() ."\n");
    }
    
    if (scalar(@metaOids) > 0) {
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace() start " . scalar(@metaOids). " meta oids AA sequence download: ". currDateTime() ."\n");
        for my $key ( @metaOids ) {
            # file
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );
            my $seq = MetaUtil::getGeneFaa( $gene_oid, $taxon_oid, $data_type );
            my$seq2;
            if ( blankStr($seq) ) {
                webLog( "printGeneFaaSeqWorkspace() no aa sequence found for workspace gene_oid=$key\n" );
                $seq2 = $no_sequence_found;
            }
            else {
                $seq2 = WebUtil::wrapSeq($seq);
            }

            my ($new_name, $source) = MetaUtil::getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
            if ( $wfh ) {
                print $wfh ">$gene_oid $new_name\n";
                print $wfh "$seq2\n";
            }
            else {
                print ">$gene_oid $new_name\n";
                print "$seq2\n";
            }
        }  # end for my key
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace() done " . scalar(@metaOids). " meta oids AA sequence download: ". currDateTime() ."\n");
    }

    if ( $wfh ) {
        close $wfh;
    }
       
}

############################################################################
# printGeneFaaSeqWorkspace_toEmail
# write file in block, not browser friendly
############################################################################
sub printGeneFaaSeqWorkspace_toEmail {
    my ($genes_ref, $outFile) = @_;

    webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() into printGeneFaaSeqWorkspace: ". currDateTime() ."\n");

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@$genes_ref);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;
    #webLog("printGeneFaaSeqWorkspace_toEmail() dbOids: @dbOids<br/>\n");
    #webLog("printGeneFaaSeqWorkspace_toEmail() metaOids: @metaOids<br/>\n");

    # process database genes first
    if (scalar(@dbOids) > 0) {
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() start " . scalar(@dbOids). " db oids AA sequence download: ". currDateTime() ."\n");

        my $dbh   = dbLogin();
        my $rclause = WebUtil::urClause('g.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
        my $db_ids_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );

        my $wfh;
        if ( $outFile ) {
            $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
        }
        execExportGeneAA($dbh, $wfh, $db_ids_str, $rclause, $imgClause);
        if ( $wfh ) {
            close $wfh;
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $db_ids_str =~ /gtt_num_id/i );
        #$dbh->disconnect();
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() done " . scalar(@dbOids). " db oids AA sequence download: ". currDateTime() ."\n");
    }
    
    if (scalar(@metaOids) > 0) {
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() start " . scalar(@metaOids). " meta oids AA sequence download: ". currDateTime() ."\n");
        my $cnt0 = scalar(@metaOids);
        if ($cnt0 <= $gene_batch_size) {
            processBatchMetaGeneFaaSeqWorkspace_toEmail(\@metaOids, $outFile);
        }
        else {
            my $cnt1   = 0;
            my @batch = ();
            my @sorted_metaOids = sort @metaOids;
            for my $mOid (@sorted_metaOids) {
                push(@batch, $mOid);
                $cnt1++;    
                if ( ( $cnt1 % $gene_batch_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                    processBatchMetaGeneFaaSeqWorkspace_toEmail(\@batch, $outFile);
                    @batch = ();
                }                
            }
        }
       
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() done " . scalar(@metaOids). " meta oids AA sequence download: ". currDateTime() ."\n");
    }

}

sub processBatchMetaGeneFaaSeqWorkspace_toEmail {
    my ($batch_ref, $outFile) = @_;
    my @batch = @$batch_ref;
    
    if (scalar(@batch) > 0) {
        my %genes_h;
        for my $workspace_id ( @batch ) {
            $genes_h{$workspace_id} = 1;
        }

        my %taxon_genes = MetaUtil::getOrganizedTaxonGenes( @batch );
        
        my %gene_name_h;
        MetaUtil::getAllMetaGeneNames(\%genes_h, \@batch, \%gene_name_h, \%taxon_genes);
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() done fetching " . scalar(@batch). " meta oids names: ". currDateTime() ."\n");

        my %gene_faa_h;
        MetaUtil::getAllMetaGeneFaa(\%genes_h, \@batch, \%gene_faa_h, \%taxon_genes);
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() done fetching " . scalar(@batch). " meta oids fastas: ". currDateTime() ."\n");

        my $wfh;
        if ( $outFile ) {
            $wfh = newAppendFileHandle( $outFile, "writeGeneFastaFile" );        
        }
        for my $key ( @batch ) {
            #webLog("SequenceExportUtil::printGeneFaaSeqWorkspace() meta oid $key: ". currDateTime() ."\n");
            # file
    
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $key );
            my $seq = $gene_faa_h{$key};

            my $seq2;
            if ( blankStr($seq) ) {
                webLog( "processBatchMetaGeneFaaSeqWorkspace_toEmail() no aa sequence found for workspace gene_oid=$key\n" );
                $seq2 = $no_sequence_found;
            }
            else {
                $seq2 = WebUtil::wrapSeq($seq);
            }
            
            my $new_name = $gene_name_h{$key};
            if ( $wfh ) {
                print $wfh ">$gene_oid $new_name\n";
                print $wfh "$seq2\n";
            }
            else {
                print ">$gene_oid $new_name\n";
                print "$seq2\n";
            }
        }  # end for my key
        if ( $wfh ) {
            close $wfh;
        }
        webLog("SequenceExportUtil::printGeneFaaSeqWorkspace_toEmail() done appending " . scalar(@batch). " meta oids sequence: ". currDateTime() ."\n");
    }
        
}

sub execExportGeneAA {
    my ($dbh, $wfh, $db_ids_str, $rclause, $imgClause) = @_;

    if ( ! $db_ids_str ) {
        return;
    }

    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.aa_residue 
        from gene g
        where g.gene_oid in ($db_ids_str) 
        $rclause
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $gene_name, $aa ) = $cur->fetchrow();
        last if !$gene_oid;

        my $seq2;
        if ( blankStr($aa) ) {
            webLog( "execExportGeneAA() no aa sequence found for gene_oid=$gene_oid\n" );
            $seq2 = $no_sequence_found;
        }
        else {
            $seq2 = wrapSeq($aa);
        }
        
        if ( $wfh ne '' ) {
            print $wfh ">$gene_oid $gene_name\n";
            print $wfh "$seq2\n";
        }
        else {
            print ">$gene_oid $gene_name\n";
            print "$seq2\n";
        }
    }
    $cur->finish();
}


############################################################################
# printScaffoldFastaDnaFile
############################################################################
sub printScaffoldFastaDnaFile {
    my ($scaffolds_ref, $outFile) = @_;

    my $wfh;
    if ( $outFile ) {
        $wfh = newAppendFileHandle( $outFile, "writeScaffoldFastaFile" );        
    }

    my ($dbOids_ref, $metaOids_ref) = MerFsUtil::splitDbAndMetaOids(@$scaffolds_ref);
    my @dbOids = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    # process database genes first
    if (scalar(@dbOids) > 0) {
        my $dbh = dbLogin();
        my $rclause = WebUtil::urClause('s.taxon');
        my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

        my $db_ids_str = OracleUtil::getNumberIdsInClause( $dbh, @dbOids );
    
        # database
        my $sql = qq{
            select s.scaffold_oid, s.taxon, s.ext_accession, ss.seq_length 
            from scaffold s, scaffold_stats ss 
            where s.scaffold_oid = ss.scaffold_oid 
            and s.scaffold_oid in ($db_ids_str)
            $rclause
            $imgClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );

        my %scaffold2taxon_h;
        my %scaffold2extacc_h;        
        my %scaffold2seqlen_h;
        for ( ; ; ) {
            my ($id, $taxon_oid, $ext_acc, $seq_length ) = $cur->fetchrow();
            last if ( !$id );
            if ( !$taxon_oid || !$ext_acc ) {
                next;
            }

            $scaffold2taxon_h{$id} = $taxon_oid;
            $scaffold2extacc_h{$id} = $ext_acc;
            $scaffold2seqlen_h{$id} = $seq_length;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $db_ids_str =~ /gtt_num_id/i );

        for my $key( keys(%scaffold2taxon_h) ) {
            my $taxon_oid = $scaffold2taxon_h{$key};
            my $ext_acc = $scaffold2extacc_h{$key};
            my $seq_length = $scaffold2seqlen_h{$key};

            if ( !$taxon_oid || !$ext_acc ) {
                next;
            }
            my $inFile = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
            my $seq = WebUtil::readLinearFasta( $inFile, $ext_acc, 1, $seq_length, "+" );

            my$seq2;
            if ( blankStr($seq) ) {
                webLog( "printScaffoldFastaDnaFile() no dna sequence found for scaffold $key $ext_acc\n" );
                $seq2 = $no_sequence_found;
            }
            else {
                $seq2 = WebUtil::wrapSeq($seq);
            }

            if ( $wfh ) {
                # we need to add img scaffold oids to the header - but how to format?
                print $wfh ">$key $ext_acc\n";
                print $wfh "$seq2\n";
            }
            else {
                print ">$key $ext_acc\n";
                print "$seq2\n";
            }                    
        }
        #$dbh->disconnect();
    }

    if (scalar(@metaOids) > 0) {
        for my $key ( @metaOids ) {
            # file
            my ( $taxon_oid, $data_type, $scaffold_oid ) = split( / /, $key );
            my $seq = MetaUtil::getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );

            my$seq2;
            if ( blankStr($seq) ) {
                webLog( "printScaffoldFastaDnaFile() no dna sequence found for wrokspace scaffold=$key\n" );
                $seq2 = $no_sequence_found;
            }
            else {
                $seq2 = WebUtil::wrapSeq($seq);
            }

            if ( $wfh ) {
                print $wfh ">$scaffold_oid\n";
                print $wfh "$seq2\n";
            }
            else {
                print ">$scaffold_oid\n";
                print "$seq2\n";
            }
        }  # end for my key
    }
    
    if ( $wfh ) {
        close $wfh;
    }
    
}


############################################################################
# getFastaFileForScaffolds - makes fasta file for selected scaffolds
############################################################################
sub getFastaFileForScaffolds {
    my ($scaffold_oids_ref, $name_first) = @_;

    # export data
    my $tmpFile = "$cgi_tmp_dir/scaffolds$$.fna";
    my $wfh = newWriteFileHandle( $tmpFile, "exportFasta" );

    my ( $dbOids_ref, $metaOids_ref ) =
      MerFsUtil::splitDbAndMetaOids(@$scaffold_oids_ref);
    my @dbOids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@dbOids) > 0 ) {
        my $dbh = dbLogin();
        my $scaffold_href = getScaffoldExts( $dbh, \@dbOids );
        #$dbh->disconnect();

        for my $scaffold_oid (@dbOids) {
            my $line = $scaffold_href->{$scaffold_oid};
            my ( $taxon_oid, $ext_acc, $seq_length ) = split( /\t/, $line );

            if ( !$taxon_oid || !$ext_acc ) {
                next;
            }
            my $inFile = "$taxon_lin_fna_dir/$taxon_oid.lin.fna";
            my $seq = WebUtil::readLinearFasta( $inFile, $ext_acc, 1, $seq_length, "+" );
            next if $seq eq "";
            my $seq2 = WebUtil::wrapSeq($seq);

            if ($name_first) {
                # this order is for Kmer analysis of scaffolds:
                print $wfh ">$ext_acc $scaffold_oid\n";
            } else {
                print $wfh ">$scaffold_oid $ext_acc\n";
            }
            print $wfh "$seq2\n";
        }
    }

    if ( scalar(@metaOids) > 0 ) {
        for my $key (@metaOids) {
            # file
            my ($taxon_oid, $data_type, $scaffold_oid) = split( / /, $key );
            my $seq = MetaUtil::getScaffoldFna($taxon_oid, $data_type, $scaffold_oid);
            next if $seq eq "";
            my $seq2 = WebUtil::wrapSeq($seq);

            print $wfh ">$scaffold_oid\n";
            print $wfh "$seq2\n";
        }
    }

    close $wfh;
    return $tmpFile;
}

sub getScaffoldExts {
    my ( $dbh, $scaffold_aref ) = @_;

    my $rclause   = WebUtil::urClause('s.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('s.taxon');

    my $oid_str = OracleUtil::getNumberIdsInClause( $dbh, @$scaffold_aref );
    my $sql = qq{
        select s.scaffold_oid, s.taxon, s.ext_accession, ss.seq_length
        from scaffold s , scaffold_stats ss
        where s.scaffold_oid = ss.scaffold_oid
        and s.scaffold_oid in ( $oid_str )
        $rclause
        $imgClause
    };

    # found scaffold ids
    my %foundIds;
    my $cur = execSql( $dbh, $sql, 1 );
    for ( ; ; ) {
        my ( $sid, $taxon, $ext, $len ) = $cur->fetchrow();
        last if ( !$sid );
        $foundIds{$sid} = "$taxon\t$ext\t$len";
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $oid_str =~ /gtt_num_id/i );

    return \%foundIds;
}

sub exportGenbankFile {
    my ($taxon, $genes, $low, $high, $outFileName) = @_;

    #WebUtil::unsetEnvPath();

    #Read Scaffold Information
    $taxon = sanitizeInt($taxon);
    my $genomef = "$taxon_fna_dir/". $taxon . ".fna";
    if (!(-e $genomef)) {
      print "$0: File $genomef doesn't exist\n";
      exit;
    }
    my $proteinf = "$taxon_faa_dir/" . $taxon . ".faa";

    my $scfCnt = 0;
    foreach my $ext_scf (keys %$genes) {
        if ( $scfCnt > 0 ) {
            print "<br/>\n";            
        }
        
        #Read Scaffold Information
        my $objscf;
        my $sub_sequence;
        my $success = 0;
        my $seqio_obj = Bio::SeqIO->new(-file => $genomef, -format => "fasta" );
        #print "Read Scaffold Information seqio_obj done<br/>\n"; 
        while ( my $seq_obj = $seqio_obj->next_seq ){
            my $fastaSCF = $seq_obj->display_id;
            next unless ( $seq_obj->display_id eq $ext_scf );
            $objscf = $seq_obj->display_id;
            $sub_sequence = $seq_obj->subseq($low, $high);
            $success = 1;
            last;
        }
        if ( $success == 0 ){ 
            print "ERROR: $ext_scf Scaffold not found.\n"; 
            next;
        }
        # untaint the variable to make it safe for Perl
        if ( $sub_sequence =~ /^(.*)$/ ) { $sub_sequence = $1; }
        #print "exportGenbankFile() objscf=$objscf sub_sequence=$sub_sequence<br/>\n"; 

        #READ AA SEQS
        my %aa;
        my $aa_objio = Bio::SeqIO->new(-file => $proteinf, -format => "fasta");
        while ( my $aa_obj = $aa_objio->next_seq ) {
            my $prot_id = $aa_obj->display_id;
            my $aa_seq = $aa_obj->seq;
            if ( exists $genes->{ $objscf }->{ $prot_id } ){
                $aa{$prot_id} = $aa_seq;
            }
        }
        #print "exportGenbankFile() aa=<br/>\n";
        #print Dumper(\%aa) . "<br/>\n";

        my $feat; 
        my $splitlocation;

        #print "Processing $objscf<br/>\n"; 
        my $new_obj = Bio::Seq->new(
            -seq => $sub_sequence,
            -display_id => $objscf,
            -accession_number => $objscf,
        );

        #Add SORTED Features to SeqIO Object
        for my $geneID ( 
            sort { $genes->{$objscf}->{$a}->{'start'} <=> $genes->{$objscf}->{$b}->{'start'} }
            keys %{$genes->{$objscf}} ){
                if( $genes->{ $objscf }->{ $geneID }->{ 'start' } && !exists $genes->{ $objscf }->{ $geneID }->{ 'coords' } ){ 
                    #Process Genes That Are not split
                    #print "DEBUG1 $genes->{ $objscf }->{ $geneID }->{ 'start' }<br/>\n";
                    #print "DEBUG AA $aa{$geneID}<br/>\n";
                    $feat = new Bio::SeqFeature::Generic (
                        -start => $genes->{ $objscf }->{ $geneID }->{ 'start' },
                        -end => $genes->{ $objscf }->{ $geneID }->{ 'end' },
                        -strand => $genes->{ $objscf }->{ $geneID }->{ 'strand' },
                        -tag => { 
                            locus_tag => $geneID, 
                            product => $genes->{ $objscf }->{ $geneID }->{ 'product' },
                            translation  => $aa{$geneID},
                        },
                        -primary => 'CDS',
                    );
                    $new_obj->add_SeqFeature($feat);
    
                } elsif( $genes->{ $objscf }->{ $geneID }->{ 'coords' } ){
                    #Process Split Genes
                    #print "DEBUG2 $genes->{ $objscf }->{ $geneID }->{ 'coords' }<br/>\n";
                    #print "DEBUG2AA $aa{$geneID}<br/>\n";
                    $feat = new Bio::SeqFeature::Generic (
                        -strand => $genes->{ $objscf }->{ $geneID }->{ 'strand' },
                        -tag => { 
                                locus_tag => $geneID, 
                                product => $genes->{ $objscf }->{ $geneID }->{ 'product' },
                                translation  => $aa{$geneID},
                        },
                        -primary => 'CDS',
                    );
        
                    $splitlocation = Bio::Location::Split->new();
                    #print $genes->{ $objscf }->{ $geneID }->{ 'coords' } . "<br/>\n";
                    my $coords_cleaned;
                    if ($genes->{ $objscf }->{ $geneID }->{ 'coords' } =~ m/join\((\d+.*\d+)\)/){
                        $coords_cleaned =$1;
                    } else{
                        print "Error parsing split coordinates $genes->{ $objscf }->{ $geneID }->{ 'coords' }\n";
                    }
                    #print $coords_cleaned . "\n";
                    #my @spltarr=split(/,/,$genes->{ $objscf }->{ $geneID }->{ 'coords' });
                    my @spltarr=split(/,/,$coords_cleaned);
                    my @splt_sorted;
                    if ($genes->{ $objscf }->{ $geneID }->{ 'strand' } eq '-') {
                        @splt_sorted = sort  { lc($b) cmp lc($a) } @spltarr;
                    } else {
                        @splt_sorted = @spltarr;
                    }
                    while ( my $splits=shift(@splt_sorted) ) {
                        $splits=~s/\>|\<//g;
                        $splits=~m/(\d+)\.\.(\d+)/;
                        my $st=$1;
                        my $en=$2;
                        $splitlocation->add_sub_Location(Bio::Location::Simple->new(
                            -start => $st - $low + 1,
                            -end => $en - $low + 1,
                            -strand => $genes->{ $objscf }->{ $geneID }->{ 'strand' },)); 
                    }
                    $feat->location($splitlocation);
                    $new_obj->add_SeqFeature($feat);
                }
        }
        #print "exportGenbankFile() Processing $objscf done new_obj=<br/>\n";
        #print Dumper($new_obj) . "<br/>\n";


        if ( $outFileName ) {
            my $dir  = WebUtil::getGenerateDir();
            my $outf = "$dir/$outFileName";
            if ( $outf =~ /^(.*)$/ ) { $outf = $1; }
            wunlink($outf);
            #print "exportGenbankFile() write to file '$outf'<br/>\n";    
            my $myseq_obj = Bio::SeqIO->new(-file => ">$outf", -format => 'genbank' );
            #print "Write myseq_obj done<br/>\n"; 
            $myseq_obj->write_seq($new_obj);
            #print "Done Processing Scaffolds<br/>\n";
        }
        else {
            my $string;
            my $stringio = IO::String->new($string);;
            my $out = Bio::SeqIO->new(-fh => $stringio, -format => 'genbank');
            #output goes into $string
            $out->write_seq($new_obj);
            #print "Done Processing Scaffolds<br/>\n";
            print "<pre>";
            print $string;
            print "</pre>";
        }

        $scfCnt++;
    }
    #WebUtil::resetEnvPath();

}



1;
