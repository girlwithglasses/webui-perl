###########################################################################
#
# $Id: GeneUtil.pm 29739 2014-01-07 19:11:08Z klchu $
#
package GeneUtil;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;

$| = 1;

my $env          = getEnv();
my $cgi_dir      = $env->{cgi_dir};
my $cgi_url      = $env->{cgi_url};
my $main_cgi     = $env->{main_cgi};
my $inner_cgi    = $env->{inner_cgi};
my $tmp_url      = $env->{tmp_url};
my $verbose      = $env->{verbose};
my $web_data_dir = $env->{web_data_dir};
my $img_internal = $env->{img_internal};
my $cgi_tmp_dir  = $env->{cgi_tmp_dir};

#print Dumper parseCdsFragCoord("complement(join(670585..671022,671025..671816))");

############################################################################
# getMultFragCoordsLine - Get line for fragment coordinates.
############################################################################
sub getMultFragCoordsLine {
    my ( $dbh, $gene_oid, $cds_frag_coord ) = @_;
    
    my @coordLines = getMultFragCoords( $dbh, $gene_oid, $cds_frag_coord );    
    my $coordsLine = formMultFragCoordsLine ( @coordLines );
    return $coordsLine;
}

############################################################################
# forMultFragCoordsLine - Get line for fragment coordinates.
############################################################################
sub formMultFragCoordsLine {
    my ( @coordLines ) = @_;
    
    my $coordsLine;
    if ( scalar(@coordLines) > 1 ) {
        $coordsLine = ", fragments(";
        my $cnt;
        foreach my $line (@coordLines) {
            if ( $cnt > 0 ) {
                $coordsLine .= ", ";
            }
            $coordsLine .= "$line";
            $cnt++;
        }
        $coordsLine .= ") ";    
    }

    return $coordsLine;
}


############################################################################
# adjustMultFragCoordsLine - adjust line for fragment coordinates with up and down stream.
############################################################################
sub adjustMultFragCoordsLine {
    my ( $coordLines_ref, $strand, $up_stream, $down_stream ) = @_;
    
    my @adjustedCoordsLines;
    if ( scalar(@$coordLines_ref) > 1 
    && ( ($up_stream ne '' && $up_stream ne 0) || ($down_stream ne '' && $down_stream ne 0) ) ) {
        my $coordsSize = scalar(@$coordLines_ref);
        my $cnt;
        for my $frag ( @$coordLines_ref ) {
            if ( $cnt == 0 ) {
                my ( $fragStart, $fragEnd ) = split(/\.\./, $frag);
                my $adjustedFragStart;
                if ( $strand eq "-" ) {
                    $adjustedFragStart = $fragStart - $down_stream;
                }
                else {
                    $adjustedFragStart = $fragStart + $up_stream;                    
                }
                push(@adjustedCoordsLines, "$adjustedFragStart..$fragEnd");                
            }
            elsif ( $cnt == $coordsSize - 1 ) {
                my ( $fragStart, $fragEnd ) = split(/\.\./, $frag);
                my $adjustedFragEnd;
                if ( $strand eq "-" ) {
                    $adjustedFragEnd = $fragEnd - $up_stream;
                }
                else {
                    $adjustedFragEnd = $fragEnd + $down_stream;
                }
                push(@adjustedCoordsLines, "$fragStart..$adjustedFragEnd");
            }
            else {
                push(@adjustedCoordsLines, $frag);
            }
            $cnt++;
        }
    }
    else {
        @adjustedCoordsLines = @$coordLines_ref;
    }

    return @adjustedCoordsLines;
}

############################################################################
# getMultFragCoordsLength - Get length from multiple fragment coordinates.
############################################################################
sub getMultFragCoordsLength {
    my ( @coordLines ) = @_;

    my $fragsLength;
    if ( scalar(@coordLines) > 1 ) {
        foreach my $line (@coordLines) {
            my ( $frag_start, $frag_end ) = split( /\.\./, $line );
            if ( $frag_end < $frag_start ) {
                $fragsLength += $frag_start - $frag_end + 1;
            }
            else {
                $fragsLength += $frag_end - $frag_start + 1;
            }
        }
    }
    
    return $fragsLength;
    
}

############################################################################
# getMultFragCoords - Get fragment coordinates.
############################################################################
sub getMultFragCoords {
    my ( $dbh, $gene_oid, $cds_frag_coord ) = @_;
    
    my @coordLines;
    if ( hasMultFrags( $dbh, $gene_oid ) ) {
        my @orderedCoords = getMultFragCoordsInOrder( $dbh, $gene_oid );
        foreach my $line (@orderedCoords) {
            push(@coordLines, $line);
        }
    }
    elsif ( $cds_frag_coord ) {
        my $list_aref = parseCdsFragCoord($cds_frag_coord);
        @coordLines = @$list_aref;
    }

    return @coordLines;
}

############################################################################
# hasMultFrags - whether a gene has multiple gragments or not
############################################################################
sub hasMultFrags {
    my ( $dbh, $gene_oid ) = @_;
    
    if ( WebUtil::isInt($gene_oid) ) {        
        my $sql = qq{
            select count(1)
            from gene_frag_coords
            where gene_oid = ?
        };
        #print "hasMultFrags() sql: $sql<br/>\n";
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        my ($cnt) = $cur->fetchrow();
        $cur->finish();
        
        if ( $cnt > 1 ) {
            return 1;
        }
    }

    return 0;    
}

############################################################################
# getMultFragCoordsInOrder - Get fragment coordinates in order
############################################################################
sub getMultFragCoordsInOrder {
    my ( $dbh, $gene_oid ) = @_;
    
    my @orderedCoords;
    
    if ( WebUtil::isInt($gene_oid) ) {        
        my $sql = qq{
            select frag_order, start_coord, end_coord
            from gene_frag_coords 
            where gene_oid = ?
            order by frag_order
        };
        #print "getMultFragCoordsInHash() sql for $gene_oid: $sql<br/>\n";
        
        #my $fragsLength;
        my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
        for ( ; ; ) {
            my( $frag_order, $start_coord, $end_coord ) = $cur->fetchrow();
            last if !$frag_order;
            push(@orderedCoords, "$start_coord..$end_coord");
            
            #if ( $end_coord < $start_coord ) {
            #    $fragsLength += $start_coord - $end_coord + 1;
            #}
            #else {
            #    $fragsLength += $end_coord - $start_coord + 1;                
            #}
        }
        $cur->finish();
        #print "getMultFragCoordsInOrder() dump orderedCoords:<br/>\n";
        #print Dumper(\@orderedCoords);
        #print "<br/>\n";
        #print "getMultFragCoordsInOrder() fragsLength = $fragsLength<br/>\n";
    }
    
    return @orderedCoords;
}

############################################################################
# parseCdsFragCoord - process line from g.cds_frag_coord of Gene table.
############################################################################
sub parseCdsFragCoord {
    my ( $cds_frag_coord ) = @_;
    
    if( $cds_frag_coord eq "" ) {
        return "";
    }
    $cds_frag_coord = lc($cds_frag_coord );
    $cds_frag_coord =~ s/complement|join//g;    
    $cds_frag_coord =~ s/\(|\)//g;
    $cds_frag_coord =~ s/>//g;
    $cds_frag_coord =~ s/<//g;
    
    # list of start and end, separated by '..'
    my @list = split(/,/, $cds_frag_coord);

    return \@list;
}

############################################################################
# getFragSeqs - Get fragment sequences and concatenate them together.
############################################################################
sub getFragSeqs {
    my ( $dbh, $gene_oid, $strand, $seq ) = @_;

    my $desc;
    $desc = "desc" if $strand eq "-";
    my $sql = qq{
        select frag_order, start_coord, end_coord
        from gene_frag_coords 
        where gene_oid = ? 
        order by frag_order $desc
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my $seq2;
    for( ;; ) {
        my( $frag_order, $start_coord, $end_coord ) = $cur->fetchrow( );
        last if !$frag_order;
        
        my( $c1, $c2 ) = ( $start_coord, $end_coord );
        ( $c1, $c2 ) = ( $end_coord, $start_coord ) if $strand eq "-";
        $seq2 .= getSequence( $seq, $c1, $c2 );
    }
    $cur->finish( );
    return $seq2;
}

############################################################################
# flushRnaHomologRecs
############################################################################
sub flushRnaHomologRecs {
    my ( $dbh, $gene_oids_aref, $homologRecs_href ) = @_;

    if ( scalar(@$gene_oids_aref) > 0 ) {
        my $oids_str = OracleUtil::getNumberIdsInClause( $dbh, @$gene_oids_aref );
        my $sql = qq{
            select g.gene_oid, g.locus_type, g.dna_seq_length,
                tx.taxon_oid, tx.domain, tx.seq_status, tx.taxon_display_name,
                scf.scaffold_oid, scf.ext_accession, scf.scaffold_name, 
                ss.seq_length, ss.gc_percent, scf.read_depth
            from gene g, scaffold scf, scaffold_stats ss, taxon tx
            where g.scaffold = scf.scaffold_oid
            and scf.scaffold_oid = ss.scaffold_oid
            and g.taxon = tx.taxon_oid
            and g.gene_oid in( $oids_str )
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my @vals     = $cur->fetchrow();
            my $gene_oid = $vals[0];
            last if !$gene_oid;
            my $rec = join( "\t", @vals );
            $homologRecs_href->{$gene_oid} = $rec;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $oids_str =~ /gtt_num_id/i );
    }
    
}

############################################################################
# flushRnaMetaHomologRecs
############################################################################
sub flushRnaMetaHomologRecs {
    my ( $dbh, $meta_gene_oids_ref, $homologRecs_href ) = @_;

    if ( scalar(@$meta_gene_oids_ref) > 0 ) {

        my %genes_h;
        my %taxon_oid_h;
        for my $workspace_id (@$meta_gene_oids_ref) {
            $genes_h{$workspace_id} = 1;
    
            my @vals = split( / /, $workspace_id );
            if ( scalar(@vals) >= 3 ) {
                $taxon_oid_h{ $vals[0] } = 1;
            }
        }

        my %taxon_info_h;
        my @metaTaxons = keys(%taxon_oid_h);
        my $taxon_oid_list = OracleUtil::getNumberIdsInClause( $dbh, @metaTaxons );                
        my $sql = QueryUtil::getTaxonDataSql( $taxon_oid_list );
        QueryUtil::executeTaxonDataSql( $dbh, $sql, \%taxon_info_h );
        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $taxon_oid_list =~ /gtt_num_id/i );

        my %taxon_genes = MetaUtil::getOrganizedTaxonGenes(@$meta_gene_oids_ref);

        my %gene_info_h;
        my %scaf_id_h;
        MetaUtil::getAllMetaGeneInfo( \%genes_h, $meta_gene_oids_ref, \%gene_info_h, \%scaf_id_h, \%taxon_genes, 1, 0, 1 );
        #print "flushRnaMetaHomologRecs() MetaUtil::getAllMetaGeneInfo done<br/>\n";

        my %scaffold_h;
        MetaUtil::getAllScaffoldInfo( \%scaf_id_h, \%scaffold_h );
        #print "flushRnaMetaHomologRecs() MetaUtil::getAllScaffoldInfo done<br/>\n";

        for my $workspace_id (@$meta_gene_oids_ref) {
            if ( ! $gene_info_h{$workspace_id} ) {
                next;
            }
            
            my ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid, $tid2, $dtype2 )
                  = split( /\t/, $gene_info_h{$workspace_id} );    
            my $dna_seq_length = $end_coord - $start_coord + 1;
    
            my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $workspace_id );
            my ( $domain, $seq_status, $taxon_name ) = split( /\t/, $taxon_info_h{$taxon_oid} );

            my $ws_scaf_id = "$taxon_oid $data_type $scaffold_oid";
            my ( $scaf_len, $scaf_gc, $scaf_gene_cnt, $scaf_depth ) = split( /\t/, $scaffold_h{$ws_scaf_id} );
    
            my $rec = "$workspace_id\t";
            $rec .= "$locus_type\t";
            $rec .= "$dna_seq_length\t";
            $rec .= "$taxon_oid\t";
            $rec .= "$domain\t";
            $rec .= "$seq_status\t";
            $rec .= "$taxon_name\t";
            $rec .= "$scaffold_oid\t";
            $rec .= "\t"; #scaf ext_accession
            $rec .= "\t"; #scaf name
            $rec .= "$scaf_len\t";
            $rec .= "$scaf_gc\t";
            $rec .= "$scaf_depth\t";
            $homologRecs_href->{$workspace_id} = $rec;
        }
    }
}


1;