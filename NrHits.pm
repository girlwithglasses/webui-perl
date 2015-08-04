###########################################################################
# NrHits - Module to handle precomputed NR hits list.
#
# $Id: NrHits.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package NrHits;
my $section = "NrHits";
use strict;
use Data::Dumper;
use CGI qw( :standard );
use LWP;
use HTTP::Request::Common qw( POST );
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $tmp_dir = $env->{ tmp_dir };
my $cgi_tmp_dir = $env->{ cgi_tmp_dir };
my $nrhits_dir = $env->{ nrhits_dir };
my $blast_data_dir = $env->{ blast_data_dir };
my $fastacmd_bin = $env->{ fastacmd_bin };
my $ncbi_blast_server_url = $env->{ ncbi_blast_server_url };
my $verbose = $env->{ verbose };

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( $page eq "" ) {
    }
    else {
    }
}

############################################################################
# loadNrHits - Load NR hits data.
############################################################################
sub loadNrHits {
    my( $dbh, $gene_oid, $outRecs_ref, $maxRows ) = @_;

    return 0;
#
#    my $sql = qq{
#       select dt.gene_oid, dt.file_number, dt.file_position
#       from dt_nr_hits dt
#       where dt.gene_oid = $gene_oid
#    };
#    my $cur = execSql( $dbh, $sql, $verbose );
#    my @recs;
#    my $trunc = 0;
#    for( ;; ) {
#       my( $gene_oid, $file_number, $file_position ) = $cur->fetchrow( );
#       last if !$gene_oid;
#       my( $cnt, $trunc2 ) = 
#	  readHitsFile( $gene_oid, $file_number, $file_position, 
#	     \@recs, $maxRows );
#       webLog( "$cnt nrhits (trunc=$trunc2) " . 
#	  "found for $gene_oid from file $file_number\n" );
#       $trunc = $trunc2;
#    }
#    $cur->finish( );
#    my %gi2DescLen;
#    loadGi2DescLen( \@recs, \%gi2DescLen );
#    denormalizeGenes( \@recs, \%gi2DescLen, $outRecs_ref );
#    return $trunc;
}

############################################################################
# loadNcbiServerHits - Load hits from ncbiBlastServer.cgi.
############################################################################
sub loadNcbiServerHits {
    my( $dbh, $gene_oid, $outRecs_ref, $maxRows ) = @_;

    $maxRows = 200 if $maxRows eq "";

    my $sql = qq{
       select aa_seq_length, aa_residue
       from gene
       where gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my( $aa_seq_length, $aa_residue ) = $cur->fetchrow( );
    $cur->finish( );
    my $ua = WebUtil::myLwpUserAgent(); 
    $ua->agent( "img2.x/genePageTopNrHits" );
    my $req = POST $ncbi_blast_server_url, [
       gene_oid => $gene_oid,
       seq => $aa_residue,
       db => "nr",
       top_n => $maxRows,
    ];
    my $res = $ua->request( $req );
    if( $res->is_success( ) ) {
       my @lines = split( /\n/, $res->content );
       my @recs;
       for my $s( @lines ) {
 	   if( $s =~ /^ERROR/ ) {
	      webDie( "Configuration error: $s\n" );
	   }
           my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
	       $qstart, $qend, $sstart, $send, $evalue, $bitScore ) =
	          split( /\t/, $s );
	   my( $gi, $giNo, $db, $ext_accession, undef ) = split( /\|/, $sid );
           my $r = "$gene_oid\t";
	   $r .= "$giNo\t";
	   $r .= "$db\t";
	   $r .= "$ext_accession\t";
	   $r .= "$percIdent\t";
	   $r .= "$alen\t";
	   $r .= "$qstart\t";
	   $r .= "$qend\t";
	   $r .= "$sstart\t";
	   $r .= "$send\t";
	   $r .= "$evalue\t";
	   $r .= "$bitScore\t";
	   push( @recs, $r );
       }
       my %gi2DescLen;
       loadGi2DescLen( \@recs, \%gi2DescLen );
       denormalizeGenes( \@recs, \%gi2DescLen, $outRecs_ref );
    }
    else {
       webLog( $res->status_line . "\n" );
       warn( $res->status_line . "\n" );
    }
}


############################################################################
# readHitsFile  - Read NR hits file.
############################################################################
sub readHitsFile {
    my( $gene_oid, $file_number, $file_position, $recs_ref, $maxRows ) = @_;
    my $path = "$nrhits_dir/nrhits.$file_number.m8.txt";
    my $rfh = newReadFileHandle( $path );
    seek( $rfh, $file_position, 0 );
    my $count = 0;
    my $trunc = 0;
    while( my $s = $rfh->getline( ) ) {
       chomp $s;
       my( $qid, $sid, $percIdent, $alen, $nMisMatch, $nGaps,
           $qstart, $qend, $sstart, $send, $evalue, $bitScore ) = 
              split( /\t/, $s );
       $qid = WebUtil::firstDashTok( $qid );
       my( $giTag, $giNo, $db, $ext_accession, undef ) = split( /\|/, $sid );
       last if $count > 0 && $qid ne $gene_oid;
       if( $qid eq $gene_oid ) {
	   $count++;
	   if( $count > $maxRows && $maxRows > 0 ) {
	       $trunc = 1;
	       webLog( "readHitsFile: truncated at maxRows=$maxRows\n" );
	       last;
	   }
	   my $r = "$gene_oid\t";
	   $r .= "$giNo\t";
	   $r .= "$db\t";
	   $r .= "$ext_accession\t";
	   $r .= "$percIdent\t";
	   $r .= "$alen\t";
	   $r .= "$qstart\t";
	   $r .= "$qend\t";
	   $r .= "$sstart\t";
	   $r .= "$send\t";
	   $r .= "$evalue\t";
	   $r .= "$bitScore\t";
           push( @$recs_ref, $r );
       }
    }
    close $rfh;
    return( $count, $trunc );
}

############################################################################
# loadGi2DescLen - Get descriptions for GI numbers.
#  Append a tab separator with AA sequence length.
############################################################################
sub loadGi2DescLen {
   my( $recs_ref, $map_ref ) = @_;
   my %giNos;
   for my $r( @$recs_ref ) {
       my( $gene_oid, $giNo, undef ) = split( /\t/, $r );
       $giNos{ $giNo } = $giNo;
   }
   my @keys = sort( keys( %giNos ) );
   my $tmpFile = "$cgi_tmp_dir/giNos$$.txt";
   my $wfh = newWriteFileHandle( $tmpFile, "loadGi2DescLen" );
   for my $k( @keys ) {
      print $wfh "$k\n";
   }
   my $cmd = "$fastacmd_bin -d $blast_data_dir/nr -i $tmpFile";
   WebUtil::unsetEnvPath( );
   my $cfh = newCmdFileHandle( $cmd, "loadGi2DescLen" );
   my $old_gi;
   my $aa_seq_length;
   while( my $s = $cfh->getline( ) ) {
      next if blankStr( $s );
      if( $s =~ /^>/ ) {
	  if( $old_gi ne "" ) {
	     $map_ref->{ $old_gi } .= "\t$aa_seq_length";
	     $aa_seq_length = 0;
	  }
          $s =~ s/^>//;
          my( $id, @toks ) = split( / /, $s );
          my( $giTag, $giNo, undef ) = split( /\|/, $id );
          $map_ref->{ $giNo } = $s;
	  $old_gi = $giNo;
      }
      else {
	 $s =~ s/\s+//g;
	 $aa_seq_length += length( $s );
      }
   }
   if( $old_gi ne "" ) {
       $map_ref->{ $old_gi } .= "\t$aa_seq_length";
   }
   close $cfh;
   WebUtil::resetEnvPath( );
   wunlink( $tmpFile );
}

############################################################################
# denormalizeGenes - From GI description, denormalize gene entries
#   with organism separation.  Sort by descending bit score.
############################################################################
sub denormalizeGenes {
   my( $inRecs_ref, $gi2DescLen_ref, $outRecs_ref ) =  @_;

   my @recs;
   for my $r0( @$inRecs_ref ) {
      my( $gene_oid, $giNo, $db, $ext_accession, 
	  $percIdent, $alen, $qstart, $qend, $sstart, $send,
	  $evalue, $bitScore ) = split( /\t/, $r0 );
      my $descAndLen = $gi2DescLen_ref->{ $giNo };
      next if $descAndLen eq "";
      my( $desc, $aa_seq_length ) = split( /\t/, $descAndLen );
      my( @entries ) = split( /\>/, $desc );
      for my $e( @entries ) {
	 $e =~ s/^\s+//;
	 $e =~ s/\s+$//;
	 #$e =~ s/\[/ \[/;
	 my( $id, @toks ) = split( / /, $e );
	 my( $giTag, $giNo, $db, $ext_accession, undef ) = split( /\|/, $id );
	 next if $giNo eq "";
	 my $desc;
	 my $inTaxon = 0;
	 my $genome;
	 for my $tok( @toks ) {
	    if( $tok =~ /^\[/ ) {
	       $inTaxon = 1;
	       $tok =~ s/\[//;
	       $genome .= "$tok ";
	       next;
	    }
	    if( !$inTaxon ) {
	       $desc .= "$tok ";
	    }
	    else {
	       $tok =~ s/[\[\]]//g;
	       $genome .= "$tok ";
	    }
	 }
	 chop $desc;
	 chop $genome;
	 next if $genome eq "";
	 next if $genome =~ /Includes/;
	 $bitScore = sprintf( "%d", $bitScore );
	 my $r = "$bitScore\t";
	 $r .= "$gene_oid\t";
	 $r .= "$giNo\t";
	 $r .= "$db\t";
	 $r .= "$ext_accession\t";
	 $r .= "$desc\t";
	 $r .= "$percIdent\t";
	 $r .= "$alen\t";
	 $r .= "$qstart\t";
	 $r .= "$qend\t";
	 $r .= "$sstart\t";
	 $r .= "$send\t";
	 $r .= "$evalue\t";
	 $r .= "$bitScore\t";
	 $r .= "$aa_seq_length\t";
	 $r .= "$genome\t";
	 push( @recs, $r );
      }
   }
   my @recs2 = reverse( sort{ $a <=> $b }( @recs ) );
   for my $r( @recs2 ) {
       my( $bitScore, @toks ) = split( /\t/, $r );
       my $r2 = join( "\t", @toks );
       push( @$outRecs_ref, $r2 );
   }

}

