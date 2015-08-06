############################################################################
#   Misc. web utility functions for file system
# $Id: MetaUtil.pm 33902 2015-08-05 01:24:06Z jinghuahuang $
############################################################################
package MetaUtil;
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  Connect_IMG_MER_v330
  sanitizeGeneId3
  sanitizeEcId2
  getFno
  getGeneInfo
  getGeneGc
  getGeneHomoTaxon
  getGeneScaffold
  getGeneBBH
  getTaxonGeneEstCopy
  getTaxonEstCopy
  getTaxonFuncGeneCopy
  getScaffoldStats
  getScaffoldGc
  getScaffoldCoord
  getScaffoldDepth
  getPhyloGeneCounts
  getUnzipFileName
  hasAssembled
  hasUnassembled
  hasMerFsTaxons
  sanitizeVar
  hasRNASeq
  getGeneInRNASeqSample
  getGenesForRNASeqSample
  getRNASeqSampleCountsForTaxon
  getCountsForRNASeqSample
  getGenesForRNASeqTaxon
  getGenesForRNASeqSampleInScaffold
  taxonHashNoBins
);

use POSIX qw(ceil floor);
use strict;
use Archive::Zip;
use DBI;
use Data::Dumper;
use FileHandle;
use WebConfig;
use WebUtil;
use HashUtil;
use BerkeleyDB;
use MerFsUtil;
use OracleUtil;
use QueryUtil;

my $env                = getEnv();
my $main_cgi           = $env->{main_cgi};
my $base_url           = $env->{base_url};
my $web_data_dir       = $env->{web_data_dir};
my $mer_data_dir       = $env->{mer_data_dir};
#my $mer_rnaseq_sdb_dir = $web_data_dir . "/rnaSeq";
my $mer_rnaseq_sdb_dir = "/global/dna/projectdirs/microbial/img_web_data_ava/rnaSeq";
my $in_file            = $env->{in_file};
my $enable_biocluster  = $env->{enable_biocluster};
my $new_func_count     = 1;
my $verbose            = $env->{verbose};

my $block_size       = 500;
my $large_block_size = 5000;
my $max_gene_cnt_for_product_file = 280000000;

my $debug   = 0;
my $MIN_FILE_SIZE = 100; # in bytes - ken

my $maxGeneListResults = 10000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

######################################################################
# connect to img_mer_v330
# temporary usage
######################################################################
sub Connect_IMG_MER_v330 {

    # use the test database img_mer_v330
    my $user2    = "img_mer_v330";
    my $pw2      = "img_mer_v330123";
    my $service2 = "imgmer01";

    my $ora_host = "data.jgi-psf.org";
    my $ora_port = "1521";
    my $ora_sid  = "imgmer01";

    # my $dsn2 = "dbi:Oracle:host=$service2";
    my $dsn2 = "dbi:Oracle:host=$ora_host;port=$ora_port;sid=$ora_sid";
    my $dbh2 = DBI->connect( $dsn2, $user2, $pw2 );
    if ( !defined($dbh2) ) {
        webDie("cannot login to IMG MER V330\n");
    }
    $dbh2->{LongReadLen} = 50000;
    $dbh2->{LongTruncOk} = 1;
    return $dbh2;
}

######################################################################
# getLargeBlockSize
######################################################################
sub getLargeBlockSize {
    return $large_block_size;
}

######################################################################
# getBinCount
######################################################################
sub getBinCount {
    my ( $taxon_oid, $data_type, $tag ) = @_;

    my $bin = 1;
    $taxon_oid = sanitizeInt($taxon_oid);
    my $taxon_hash_name = $mer_data_dir . "/" . $taxon_oid . "/";
    if ( $data_type eq 'assembled' ) {
        $taxon_hash_name .= "assembled/";
    } elsif ( $data_type eq 'unassembled' ) {
        $taxon_hash_name .= "unassembled/";
    } else {
        return $bin;
    }

    $taxon_hash_name .= "taxon_hash.txt";

    if (   $taxon_hash_name
        && $tag
        && ( -e $taxon_hash_name ) )
    {
        my $fh = newReadFileHandle($taxon_hash_name);
        while ( my $line = $fh->getline() ) {
            chomp $line;
            my ( $a1, $a2, $a3, @rest ) = split( /\,/, $line );
            if ( $a1 eq $tag ) {
                $bin = $a3;
                last;
            }
        }
        close $fh;
    }

    return $bin;
}

######################################################################
# get file number
######################################################################
sub getFno {
    my ( $gene_id, $total_gene_cnt ) = @_;

    my $genes_per_zip = 2000000;
    my $no_files      = ceil( $total_gene_cnt * 1.0 / $genes_per_zip );

    my $new_id = $gene_id;
    $new_id =~ s/\:/\_/g;

    my $len  = length($new_id);
    my $code = 0;
    my $j    = 0;
    while ( $j < $len ) {
        $code += ( substr( $new_id, $j, 1 ) - '0' );
        $j++;
    }
    return ( $code % $no_files ) + 1;
}

############################################################################
# sanitizeGeneId3 - Sanitize to integer, char and _ for security purposes.
############################################################################
sub sanitizeGeneId3 {
    my ($s) = @_;
    return $s if ( !$s );

    if ( $s !~ /^[0-9A-Za-z\_\.\-]+$/ ) {
        webDie("sanitizeGeneId3: invalid id '$s'\n");
    }
    $s =~ /([0-9A-Za-z\_\.\-]+)/;
    $s = $1;
    return $s;
}

############################################################################
# sanitizeEcId2 - Sanitize EC ID
############################################################################
sub sanitizeEcId2 {
    my ($s) = @_;
    if ( $s !~ /^[0-9n_\.\-]+$/ ) {
        webDie("sanitizeEcId2: invalid EC number '$s'\n");
    }
    $s =~ /([0-9n_\.\-]+)/;
    $s = $1;
    return $s;
}

############################################################################
# getGeneFaa
############################################################################
sub getGeneFaa {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    # read gene faa info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my $hash_file = $mer_data_dir . "/$taxon_oid/$t2/taxon_hash.txt";
    my $code      = HashUtil::get_hash_code( $hash_file, "faa", $gene_oid );
    my $faa_file  = $mer_data_dir . "/$taxon_oid/$t2/faa";

    if ($code) {
        $code = sanitizeGeneId3($code);
        $faa_file .= "/faa_" . $code;
    }
    my $sdb_name = $faa_file . ".sdb";

    #print "getGeneFaa() sdb_name = $sdb_name<br/>\n";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = "select gene_oid, faa from gene_faa where gene_oid = ?";
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute($gene_oid);
        my ( $id3, $seq ) = $sth->fetchrow_array();
        $sth->finish();
        $dbh3->disconnect();
        return $seq;
    }

    my $zip_name = $faa_file . ".zip";
    if ( !( -e $zip_name ) ) {
        return;
    }

    WebUtil::unsetEnvPath();

    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneInfo' );
    my $line = $fh->getline();
    chomp($line);
    my $seq = $line;
    close $fh;

    WebUtil::resetEnvPath();

    return $seq;
}

############################################################################
# doGeneIdSearch
############################################################################
sub doGeneIdSearch {
    my ( $print_msg, $taxon_oid, $data_type, $termNotFoundArray_ref, $result_info_href ) = @_;

    my @metaOids;
    if ( $termNotFoundArray_ref ne '' && scalar(@$termNotFoundArray_ref) > 0 ) {
        for my $term (@$termNotFoundArray_ref) {
            my $workspace_id = "$taxon_oid $data_type $term";
            push( @metaOids, $workspace_id );
        }
        getAllMetaGeneInfo( '', \@metaOids, $result_info_href, '', '', $print_msg, 1 );
    }
}

############################################################################
# doGeneIdSearchInProdFile
############################################################################
sub doGeneIdSearchInProdFile {
    my (
        $print_msg,        $needUntaint, $taxon_oid,     $data_type,
        $total_gene_cnt,   $tag,         $term_list_ref, $termFoundHash_ref,
        $result_info_href, $gene_count,  $trunc,         $max_rows
      )
      = @_;

    if ($print_msg) {
        print "Check metagenome $taxon_oid $data_type gene ID for @$term_list_ref from product file<br/>\n";
    }

    my $hasGeneProdSqliteFile = hasSdbGeneProductFile( $taxon_oid, $data_type );
    if ($hasGeneProdSqliteFile) {
        my %names = getGeneProdNamesForTaxonGenesFromSqlite( $taxon_oid, $data_type, $term_list_ref, 1 );
        if ( scalar( keys %names ) > 0 ) {
            foreach my $gene_oid ( keys %names ) {
                my $workspace_id = "$taxon_oid $data_type $gene_oid";
                $result_info_href->{$workspace_id} = $names{$gene_oid};

                $termFoundHash_ref->{ lc($gene_oid) } = 1;
                $gene_count++;
                if ($print_msg) {
                    print ".";
                    if ( ( $gene_count % 180 ) == 0 ) {
                        print "<br/>\n";
                    }
                }
            }

            if ( $max_rows ne '' && isInt($max_rows) ) {
                if ( $gene_count >= $max_rows ) {
                    $trunc = 1;
                    last;
                }
            }

        }
    } else {
        if ($print_msg) {
            print "No results retrieved from sqlite for $taxon_oid $data_type <br/>\n";
        }
        webLog "MetaUtil::doGeneIdSearchInProdFile() no results retrieved from sqlite $taxon_oid $data_type<br/>\n";

        if (   $total_gene_cnt ne ''
            && isInt($total_gene_cnt)
            && $total_gene_cnt > 0
            && $total_gene_cnt < $max_gene_cnt_for_product_file )
        {
            my $isGeneProductTxtFileExist = 0;
            ( $gene_count, $trunc, $isGeneProductTxtFileExist ) = doGeneIdSearchInProdTxtFile(
                $print_msg,  $needUntaint,   $taxon_oid,         $data_type,
                $tag,        $term_list_ref, $termFoundHash_ref, $result_info_href,
                $gene_count, $trunc,         $max_rows
            );
        } else {

            #too large, pipe fail
        }
    }

    return ( $gene_count, $trunc );

}

############################################################################
# doGeneIdSearchInProdTxtFile
############################################################################
sub doGeneIdSearchInProdTxtFile {
    my (
        $print_msg,  $needUntaint,   $taxon_oid,         $data_type,
        $tag,        $term_list_ref, $termFoundHash_ref, $result_info_href,
        $gene_count, $trunc,         $max_rows
      )
      = @_;

    my $isGeneProductTxtFileExist = 0;
    my $geneProductTxtFile        = $mer_data_dir . '/' . $taxon_oid . '/' . $data_type . '/gene_product.txt';

#print "MetaUtil::doGeneIdSearchInProdTxtFile() search " . scalar(@$term_list_ref) . " terms in $taxon_oid geneProductTxtFile: $geneProductTxtFile<br/>\n";
    if ( -e $geneProductTxtFile ) {
        if ($print_msg) {
            print "Check metagenome $taxon_oid $data_type gene product file $geneProductTxtFile ...<br/>\n";
        }
        $isGeneProductTxtFileExist = 1;

        WebUtil::unsetEnvPath();

        my ($termNotFoundArray_ref) = MerFsUtil::getTermNotFound( $term_list_ref, $termFoundHash_ref );

        my $term_list_str = join( '|', @$termNotFoundArray_ref );
        if ($needUntaint) {
            ($term_list_str) = $term_list_str =~ /([A-Za-z0-9_-|]+)/;
        }
        my $cmd = "/bin/egrep -iw \"$term_list_str\" $geneProductTxtFile";

        #print "MetaUtil::doGeneIdSearchInProdTxtFile() cmd: $cmd, term_list_str: $term_list_str<br/>\n";
        my $rfh = newCmdFileHandle( $cmd, $tag );
        if ( !$rfh ) {
            return next;
        }

        while ( my $line = $rfh->getline() ) {
            chomp($line);
            my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
            my $gene_oid_lc = lc($gene_oid);

            foreach my $t (@$termNotFoundArray_ref) {

                #print "MetaUtil::doGeneIdSearchInProdTxtFile() compare $t with $gene_oid<br/>\n";
                if ( $gene_oid_lc eq lc($t) ) {

                    # match
                    #print "MetaUtil::doGeneIdSearchInProdTxtFile() matching $line<br/>\n";
                    my $workspace_id = "$taxon_oid $data_type $gene_oid";
                    $result_info_href->{$workspace_id} = $product_name;

                    $termFoundHash_ref->{$gene_oid_lc} = 1;
                    $gene_count++;
                    if ($print_msg) {
                        print ".";
                        if ( ( $gene_count % 180 ) == 0 ) {
                            print "<br/>\n";
                        }
                    }
                    last;
                }
            }

            if ( $max_rows ne '' && isInt($max_rows) ) {
                if ( $gene_count >= $max_rows ) {
                    $trunc = 1;
                    last;
                }
            }

            if ( scalar(@$term_list_ref) <= scalar( keys(%$termFoundHash_ref) ) ) {
                last;
            }
        }
        close $rfh;

        WebUtil::resetEnvPath();
    }

    return ( $gene_count, $trunc, $isGeneProductTxtFileExist );
}

############################################################################
# doCogPfamSearch - Replacment for actual MER-FS product name search
#   which is extremely slow.  Since the product names come from COG
#   and Pfam, we search COG and Pfam tables, and lookup the genes associated
#   with these.      --es
############################################################################
sub doCogPfamSearch {
    my (
        $dbh,        $print_msg,        $needUntaint, $taxon_oid, $data_type, $tag,
        $searchTerm, $result_info_href, $gene_count,  $trunc,     $max_rows
      )
      = @_;

    # Taxau (taxon_oid.<a|u>) directory of MER-FS metagenome section.
    my $txd = $mer_data_dir . '/' . $taxon_oid . '/' . $data_type;

    # We search Pfam first, then override with COG, since COG
    # takes precedence.
    my %genes;
    searchPfamFs( $dbh, $txd, $searchTerm, \%genes );
    searchCogFs( $dbh, $txd, $searchTerm, \%genes );

    my @gene_oids = sort( keys(%genes) );
    for my $gene_oid (@gene_oids) {
        my $prodName     = $genes{$gene_oid};
        my $workspace_id = "$taxon_oid $data_type $gene_oid";
        $result_info_href->{$workspace_id} = $prodName;
        $gene_count++;
        if ( $gene_count >= $max_rows ) {
            $trunc = 1;
            last;
        }
    }
    return ( $gene_count, $trunc );
}

############################################################################
# searchCogFs - Search the file system MER-FS for COG.
############################################################################
sub searchCogFs {
    my ( $dbh, $txd, $term, $genes_href ) = @_;

    my $sdbFile = "$txd/cog_genes.sdb";
    return if !-e $sdbFile;
    my $dbh2  = WebUtil::sdbLogin($sdbFile);
    my $term2 = "%$term%";
    my $sql   = qq{
        select cog_id, cog_id||': '||cog_name
        from cog
        where lower( cog_name ) like ? or 
           cog_id = ?
    };
    my $cur  = execSql( $dbh, $sql, $verbose, $term2, $term );
    my $sql2 = "select genes from cog_genes where cog = ?";
    my $cur2 = $dbh2->prepare($sql2)
      || webDie("searchCogFs: Cannot prep '$sql2'\n");

    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $cur2->execute($id)
          || webDie("searchCogFs: Cannot execute '$id'\n");
        my $genes2_s = $cur2->fetchrow();
        my @genes2_a = split( /\s+/, $genes2_s );
        for my $g2 (@genes2_a) {
            $genes_href->{$g2} = $name;
        }
    }
    $cur2->finish();
    $cur->finish();
    $dbh2->disconnect();
}

############################################################################
# searchPfamFs - Search the file system MER-FS for Pfam.
############################################################################
sub searchPfamFs {
    my ( $dbh, $txd, $term, $genes_href ) = @_;

    my $sdbFile = "$txd/pfam_genes.sdb";
    return if !-e $sdbFile;
    my $dbh2  = WebUtil::sdbLogin($sdbFile);
    my $term2 = "%$term%";
    my $sql   = qq{
        select ext_accession, ext_accession||':'||name||': '||description
        from pfam_family
        where lower( name ) like ? or 
           lower( description ) like ? or 
           ext_accession = ?
    };
    my $cur  = execSql( $dbh, $sql, $verbose, $term2, $term2, $term );
    my $sql2 = "select genes from pfam_genes where pfam = ?";
    my $cur2 = $dbh2->prepare($sql2)
      || webDie("searchPfamFs: Cannot prep '$sql2'\n");

    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $cur2->execute($id)
          || webDie("searchPfamFs: Cannot execute '$id'\n");
        my $genes2_s = $cur2->fetchrow();
        my @genes2_a = split( /\s+/, $genes2_s );
        for my $g2 (@genes2_a) {
            $genes_href->{$g2} = $name;
        }
    }
    $cur2->finish();
    $cur->finish();
    $dbh2->disconnect();
}

############################################################################
# doGeneProdNameSearch
############################################################################
sub doGeneProdNameSearch {
    my (
        $print_msg,  $needUntaint,      $taxon_oid,  $data_type, $tag,
        $searchTerm, $result_info_href, $gene_count, $trunc,     $max_rows
      )
      = @_;

    my $dataTypeDir = $mer_data_dir . '/' . $taxon_oid . '/' . $data_type;
    if ( !( -e $dataTypeDir ) ) {
        return ( $gene_count, $trunc );
    }

    # --es 07/02/13
    my $geneProductGenesFile = getGeneProductGenesFile( $taxon_oid, $data_type );
    if ( $geneProductGenesFile ne "" && -e $geneProductGenesFile ) {
        if ($print_msg) {
            print "Check metagenome $taxon_oid $data_type product name " . "for $searchTerm (inverted index)...<br/>\n";
        }
        my $dbh = WebUtil::sdbLogin($geneProductGenesFile);
        my $sql =
          "select gene_display_name, img_product_source, genes " . "from product where lower( gene_display_name ) like ?";
        my $cur = execSql( $dbh, $sql, $verbose, "%${searchTerm}%" );
        my $count = 0;
        for ( ; ; ) {
            my ( $gene_display_name, $img_product_source, $genes ) = $cur->fetchrow();
            last if !$gene_display_name;
            my @genes_a = split( /\s+/, $genes );
            for my $gene (@genes_a) {
                my $workspace_id = "$taxon_oid $data_type $gene";
                $result_info_href->{$workspace_id} = $gene_display_name;
                $gene_count++;
                if ( $gene_count >= $max_rows ) {
                    $trunc = 1;
                    last;
                }
            }
        }
        $cur->finish();
        $dbh->disconnect();
        return ( $gene_count, $trunc );
    }

    my $hasGeneProdSqliteFile = hasSdbGeneProductFile( $taxon_oid, $data_type );
    if ($hasGeneProdSqliteFile) {
        if ($print_msg) {
            print "Check metagenome $taxon_oid $data_type product name for $searchTerm ...<br/>\n";
        }

        my $sql = "select gene_oid, gene_display_name, img_product_source from gene where gene_display_name LIKE ?";
        my @sdb_names = getSdbGeneProductFile( '', $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            foreach my $sdb_name (@sdb_names) {

                #print "MetaUtil::doGeneProdNameSearch() sdb_name: $sdb_name<br/>\n";
                my (%geneNames) =
                  fetchGeneNameForTaxonFromSqlite( $taxon_oid, $data_type, $sdb_name, $sql, "%$searchTerm%" );

                if ( scalar( keys %geneNames ) > 0 ) {
                    foreach my $gene_oid ( keys %geneNames ) {
                        my $workspace_id = "$taxon_oid $data_type $gene_oid";
                        $result_info_href->{$workspace_id} = $geneNames{$gene_oid};

                        $gene_count++;
                        if ( $max_rows ne '' && isInt($max_rows) ) {
                            if ( $gene_count >= $max_rows ) {
                                $trunc = 1;
                                last;
                            }
                        }
                    }
                }

            }
        }

    } else {
        if ($print_msg) {
            print
"<p>No sqlite gene product file, retrieving gene name from gene_product.txt file for genome $taxon_oid $data_type<br/>\n";
        }
        webLog "MetaUtil::doGeneProdNameSearch() no results retrieved from sqlite for genome $taxon_oid $data_type<br/>\n";

        my $geneProductTxtFile = $mer_data_dir . '/' . $taxon_oid . '/' . $data_type . '/gene_product.txt';
        if ( -e $geneProductTxtFile ) {
            if ($print_msg) {
                print "using $geneProductTxtFile to search<br/>\n";
            }

            WebUtil::unsetEnvPath();

            my $searchTermUntainted;
            if ($needUntaint) {
                ($searchTermUntainted) = ( $searchTerm =~ /^(.*)$/g );
            } else {
                ($searchTermUntainted) = $searchTerm;
            }
            my $cmd = "/bin/grep -i \"$searchTermUntainted\" $geneProductTxtFile";

#print "MetaUtil::doGeneProdNameSearch() cmd: $cmd, searchTermUntainted: $searchTermUntainted, searchTerm: $searchTerm<br/>\n";
            my $rfh = newCmdFileHandle( $cmd, $tag );
            if ( !$rfh ) {
                return next;
            }
            while ( my $line = $rfh->getline() ) {
                chomp($line);
                my ( $gene_oid, $product_name, $source ) = split( /\t/, $line );
                if ( $product_name =~ /$searchTerm/i ) {

                    # match
                    #print "MetaUtil::doGeneProdNameSearch() matching $line<br/>\n";
                    my $workspace_id = "$taxon_oid $data_type $gene_oid";
                    $result_info_href->{$workspace_id} = $product_name;

                    $gene_count++;
                    if ( $max_rows ne '' && isInt($max_rows) ) {
                        if ( $gene_count >= $max_rows ) {
                            $trunc = 1;
                            last;
                        }
                    }
                }
            }
            close $rfh;

            WebUtil::resetEnvPath();
        }
    }

    return ( $gene_count, $trunc );
}

############################################################################
# getGeneProdNameSource
############################################################################
sub getGeneProdNameSource {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    # read gene info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @sdb_names = getSdbGeneProductFile( $gene_oid, $taxon_oid, $data_type );
    if ( scalar(@sdb_names) > 0 ) {
        my $sdb_name = $sdb_names[0];
        if ( $sdb_name && ( -e $sdb_name ) && (-s $sdb_name > $MIN_FILE_SIZE) ) {
            my $dbh3 = WebUtil::sdbLogin($sdb_name)
              or return;

            my $sql3 = "select gene_oid, gene_display_name, img_product_source from gene where gene_oid = ?";
            my $sth  = $dbh3->prepare($sql3);
            $sth->execute($gene_oid);
            my ( $id3, $prod_name, $prod_source ) = $sth->fetchrow_array();
            if ( !$prod_name ) {
                $prod_name = "hypothetical protein";
            }
            $sth->finish();
            $dbh3->disconnect();
            return ( $prod_name, $prod_source );
        }
    }

    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
    my $code      = HashUtil::get_hash_code( $hash_file, "gene_product", $gene_oid );

    my $zip_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/gene_product";
    if ($code) {
        $code = sanitizeGeneId3($code);
        $zip_name .= "/gene_product_" . $code;
    }
    $zip_name .= ".zip";

    #print("MetaUtil::getGeneProdNameSource() zip_name: $zip_name<br/>\n");

    if ( !( -e $zip_name ) ) {
        return "";
    }

    WebUtil::unsetEnvPath();

    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $cmd = "/usr/bin/unzip -C -p $zip_name $i2 ";

    #print("MetaUtil::getGeneProdNameSource() cmd: $cmd<br/>\n");
    my $fh = newCmdFileHandle( $cmd, 'geneInfo' );
    my $line = $fh->getline();
    chomp($line);
    my ( $g3, $prod_name, $source ) = split( /\t/, $line );
    close $fh;

    WebUtil::resetEnvPath();

    if ( blankStr($prod_name) ) {
        $prod_name = "hypothetical protein";
    }
    return ( $prod_name, $source );
}

############################################################################
# getGeneProdName
############################################################################
sub getGeneProdName {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my ( $prod_name, $source ) = getGeneProdNameSource( $gene_oid, $taxon_oid, $data_type );
    return ($prod_name);
}

############################################################################
# getGeneProdNamesForTaxon
# key is not workspace id in return hash
#
# if max_count is specified, then only return max_count rows
############################################################################
sub getGeneProdNamesForTaxon {
    my ( $taxon_oid, $data_type, $max_count, $printMsg ) = @_;
    $taxon_oid = sanitizeInt($taxon_oid);

    my %names;

    my $hasGeneProdSqliteFile = hasSdbGeneProductFile( $taxon_oid, $data_type );
    if ($hasGeneProdSqliteFile) {

        my $sql = "select gene_oid, gene_display_name, img_product_source from gene";

        my @sdb_names = getSdbGeneProductFile( '', $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            foreach my $sdb_name (@sdb_names) {
                if ($printMsg) {
                    print "MetaUtil::getGeneProdNamesForTaxon() sdb_name: $sdb_name<br/>\n";
                }

                #print "MetaUtil::getGeneProdNamesForTaxon() sdb_name: $sdb_name<br/>\n";
                my (%geneNames) = fetchGeneNameForTaxonFromSqlite( $taxon_oid, $data_type, $sdb_name, $sql );
                for my $gene_oid ( keys %geneNames ) {
                    $names{$gene_oid} = $geneNames{$gene_oid};
                }

                #print "MetaUtil::getGeneProdNamesForTaxon() names retrieved: ". scalar(keys(%names)) ."<br/>\n";
                if ( $max_count && scalar( keys %names ) >= $max_count ) {
                    last;
                }
            }
        }
    } else {
        my $file_name = $mer_data_dir . "/$taxon_oid/$data_type/gene_product.txt";

        if ( -e $file_name ) {
            my $rfh = newReadFileHandle($file_name);
            if ($rfh) {
                my $line_no = 0;
                while ( my $line = $rfh->getline() ) {
                    chomp($line);
                    my ( $gene_oid, $gene_name ) = split( /\t/, $line );
                    $names{$gene_oid} = $gene_name;

                    $line_no++;
                    if ( $max_count && $line_no >= $max_count ) {
                        last;
                    }
                }
            }
            close $rfh;
        }
    }

    if ($printMsg) {
        print "Done MetaUtil::getGeneProdNamesForTaxon()<br/>\n";
    }

    return %names;
}

############################################################################
# getGeneProdNamesForTaxonGenes
# not workspace id used as key in return hash
############################################################################
sub getGeneProdNamesForTaxonGenes {
    my ( $taxon_oid, $data_type, $oids_ref ) = @_;

    my %names;

    my $hasGeneProdSqliteFile = hasSdbGeneProductFile( $taxon_oid, $data_type );
    if ($hasGeneProdSqliteFile) {
        %names = getGeneProdNamesForTaxonGenesFromSqlite( $taxon_oid, $data_type, $oids_ref );
    } else {
        my $file_name = $mer_data_dir . "/$taxon_oid/$data_type/gene_product.txt";

        if ( -e $file_name ) {
            my $rfh = newReadFileHandle($file_name);
            if ($rfh) {
                while ( my $line = $rfh->getline() ) {
                    chomp($line);
                    my ( $gene_oid, $gene_name ) = split( /\t/, $line );
                    if ( WebUtil::inArray_ignoreCase( $gene_oid, @$oids_ref ) ) {
                        $names{$gene_oid} = $gene_name;
                    }
                }
            }
            close $rfh;
        }
    }

    return (%names);
}

############################################################################
# getGeneProdNamesForTaxonGenesFromSqlite
# not workspace id used as key in return hash
############################################################################
sub getGeneProdNamesForTaxonGenesFromSqlite {
    my ( $taxon_oid, $data_type, $oids_ref, $useCaseInsensitive ) = @_;

    my %names;
    if ( $oids_ref ne '' && scalar(@$oids_ref) > 0 ) {
        $taxon_oid = sanitizeInt($taxon_oid);

        my $hasGeneProdSqliteFile = hasSdbGeneProductFile( $taxon_oid, $data_type );
        if ($hasGeneProdSqliteFile) {
            my %prodFile_genes;
            my $singleProdFile = getSingleSdbGeneProductFile( $taxon_oid, $data_type );
            if ($singleProdFile) {
                $prodFile_genes{$singleProdFile} = $oids_ref;
            } else {
                if ($useCaseInsensitive) {
                    my @sdb_names = getSdbGeneProductFile( '', $taxon_oid, $data_type );
                    my @empty     = ();
                    my $cnt       = 0;
                    for my $sdb_name (@sdb_names) {
                        if ( $cnt == 0 ) {
                            $prodFile_genes{$sdb_name} = $oids_ref;
                            $cnt = 1;
                        } else {

                            #to dynamically build $oid_ref
                            $prodFile_genes{$sdb_name} = \@empty;
                        }
                    }
                } else {
                    %prodFile_genes = getOrganizedTaxonGeneProductFiles( $taxon_oid, $data_type, @$oids_ref );
                }
            }

            for my $prodFile ( keys %prodFile_genes ) {
                my $file_oids_ref = $prodFile_genes{$prodFile};
                my $cnt0          = scalar(@$file_oids_ref);
                if ( $cnt0 == 0 ) {
                    if ($useCaseInsensitive) {

                        #dynamically build $oid_ref
                        my @notFoundIds = ();
                        my @foundIds    = keys %names;
                        for my $oid (@$oids_ref) {
                            if ( WebUtil::inArray_ignoreCase( $oid, @foundIds ) ) {
                                next;
                            }
                            push( @notFoundIds, $oid );
                        }
                        $file_oids_ref = \@notFoundIds;
                    } else {
                        next;
                    }
                }

                my $cnt1         = 0;
                my $file_oid_str = '';
                for my $file_oid (@$file_oids_ref) {
                    if ($file_oid_str) {
                        $file_oid_str .= ", '" . $file_oid . "'";
                    } else {
                        $file_oid_str = "'" . $file_oid . "'";
                    }
                    $cnt1++;
                    if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                        my $sql = "select gene_oid, gene_display_name, img_product_source from gene ";

                        #$useCaseInsensitive is used
                        if ($useCaseInsensitive) {
                            $file_oid_str =~ tr/A-Z/a-z/;
                            $sql .= " where lower(gene_oid) in ($file_oid_str)";
                        } else {
                            $sql .= " where gene_oid in ($file_oid_str)";
                        }
                        my (%geneNames) = fetchGeneNameForTaxonFromSqlite( $taxon_oid, $data_type, $prodFile, $sql );
                        if ( scalar( keys %geneNames ) > 0 ) {
                            foreach my $gene_oid ( keys %geneNames ) {
                                $names{$gene_oid} = $geneNames{$gene_oid};
                            }
                        }
                        $file_oid_str = '';
                    }
                }
            }
        }

    }

    return (%names);
}

############################################################################
# getGeneInfo
############################################################################
sub getGeneInfo {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    # read gene info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";

    my $code = HashUtil::get_hash_code( $hash_file, "gene", $gene_oid );

    my $file_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/gene";
    if ($code) {
        $code = sanitizeGeneId3($code);
        $file_name .= "/gene_" . $code;
    }
    my $sdb_name = $file_name . ".sdb";

    my @vals = ();

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return @vals;

        my $sql3 =
            "select gene_oid, locus_type, locus_tag, product_name, "
          . "start_coord, end_coord, strand, scaffold_oid from gene where gene_oid = ?";
        my $sth = $dbh3->prepare($sql3);
        $sth->execute($gene_oid);
        (@vals) = $sth->fetchrow_array();
        $sth->finish();
        $dbh3->disconnect();
        return @vals;
    }

    my $zip_name = $file_name . ".zip";
    if ( !( -e $zip_name ) ) {
        return @vals;
    }

    WebUtil::unsetEnvPath();

    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneInfo' );
    my $line = $fh->getline();
    chomp($line);
    @vals = split( /\t/, $line );
    close $fh;

    WebUtil::resetEnvPath();

    return @vals;
}

############################################################################
# getGeneInfosForTaxon
# key is workspace id in return hash
#
# if max_count is specified, then only return max_count rows
############################################################################
sub getGeneInfosForTaxon {
    my ( $taxon_oid, $data_type, $max_count ) = @_;
    $taxon_oid = sanitizeInt($taxon_oid);

    my %gene_infos;

    my $hasGeneInfoSqliteFile = hasSdbGeneInfoFile( $taxon_oid, $data_type );
    if ($hasGeneInfoSqliteFile) {

        my $sql =
            "select gene_oid, locus_type, locus_tag, product_name, "
          . "start_coord, end_coord, strand, scaffold_oid from gene ";

        my @sdb_names = getSdbGeneInfoFile( '', $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            my $count = 0;
            foreach my $sdb_name (@sdb_names) {

                #print "MetaUtil::getGeneInfosForTaxon() sdb_name: $sdb_name<br/>\n";
                my (%geneInfos) = fetchGeneInfoForTaxonFromSqlite( $taxon_oid, $data_type, $sdb_name, $sql );

                #print Dumper(\%geneInfos);

                for my $gene_oid ( keys %geneInfos ) {
                    my $workspace_id = "$taxon_oid $data_type $gene_oid";
                    $gene_infos{$workspace_id} = $geneInfos{$gene_oid};
                }

                #print "MetaUtil::getGeneInfosForTaxon() geneInfos retrieved: ". scalar(keys(%geneInfos)) ."<br/>\n";

                $count .= scalar( keys %geneInfos );
                if ( $max_count && $count >= $max_count ) {
                    last;
                }
            }
        }
    } else {

        my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $data_type . "/taxon_hash.txt";
        my $max_lot_cnt   = 0;
        if ( -e $hash_file ) {
            my $fh2 = newReadFileHandle($hash_file);
            if ( !$fh2 ) {
                next;
            }
            while ( my $line1 = $fh2->getline() ) {
                chomp($line1);

                my ( $a0, $a1, $a2, @a3 ) = split( /\,/, $line1 );
                if ( $a0 eq 'gene' && isInt($a2) ) {
                    $max_lot_cnt = $a2;
                    last;
                }
            }
            close $fh2;
        }

        my $count = 0;
        $max_lot_cnt = sanitizeInt($max_lot_cnt);
        for ( my $j = 1 ; $j <= $max_lot_cnt ; $j++ ) {
            my $zip_name = $mer_data_dir . "/$taxon_oid" . "/" . $data_type . "/gene/gene_" . $j . ".zip";
            if ( !( -e $zip_name ) ) {
                next;
            }

            my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name ", 'geneInfo' );
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp($line);
                my ( $gene_oid, @rest ) = split( /\t/, $line );

                my $workspace_id = "$taxon_oid $data_type $gene_oid";
                $gene_infos{$workspace_id} = join( "\t", @rest );

                $count++;
                if ( $max_count && $count >= $max_count ) {
                    last;
                }

            }    # end while line
            close $fh;
        }    # end for j

    }

    return %gene_infos;
}

############################################################################
# getGeneGc
############################################################################
sub getGeneGc {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my ( $gene_seq, $strand, $scaf_oid ) = getGeneFna( $gene_oid, $taxon_oid, $data_type );
    my ( $a, $b, $c ) = gcContent($gene_seq);
    return $c;
}

############################################################################
# getGeneFna
############################################################################
sub getGeneFna {
    my ( $gene_oid, $taxon_oid, $data_type, $scaf2fna_href ) = @_;

    # read gene fna info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @vals = getGeneInfo( $gene_oid, $taxon_oid, $data_type );
    my $scaffold_oid;
    my $start_coord;
    my $end_coord;
    my $strand;

    if ( scalar(@vals) > 0 && scalar(@vals) <= 7 ) {
        $start_coord  = $vals[3];
        $end_coord    = $vals[4];
        $strand       = $vals[5];
        $scaffold_oid = $vals[6];
    } elsif ( scalar(@vals) > 7 ) {
        $start_coord  = $vals[4];
        $end_coord    = $vals[5];
        $strand       = $vals[6];
        $scaffold_oid = $vals[7];
    }

    my $workspace_id = "$taxon_oid $data_type $scaffold_oid";
    my $line;
    if ( $scaf2fna_href ne '' ) {
        $line = $scaf2fna_href->{$workspace_id};
    }
    if ( !$line ) {
        $line = getScaffoldFna( $taxon_oid, $data_type, $scaffold_oid );
        if ( $line && $scaf2fna_href ne '' ) {
            $scaf2fna_href->{$workspace_id} = $line;
        }
    }

    my $gene_seq = "";
    if ( $strand eq '-' ) {
        $gene_seq = getSequence( $line, $end_coord, $start_coord );
    } else {
        $gene_seq = getSequence( $line, $start_coord, $end_coord );
    }

    return ( $gene_seq, $strand, $scaffold_oid );
}

############################################################################
# getGeneCogInfo: get COG information for this gene
############################################################################
sub getGeneCogInfo {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my @cogs;
    my $sdbFileExist;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $name_dir  = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
    my $tag       = "gene2cog";
    my $code;

    ## check sqlite first
    my $sdb_name = $name_dir . "/gene_cog.sdb";
    if ( !( -e $sdb_name ) ) {
        my $bin = getBinCount( $taxon_oid, $t2, $tag );
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
        if ( $bin > 1 || $code ) {
            $sdb_name = $name_dir . "/$tag/gene_cog_" . $code . ".sdb";
        }
    }
    #print "MetaUtil::getGeneCogInfo() gene_oid: $gene_oid, sdb_name: $sdb_name<br/>\n";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        $sdbFileExist = 1;
        my $dbh2 = WebUtil::sdbLogin($sdb_name)
          or return (\@cogs, $sdbFileExist);

        my $sql2 =
            "select gene_oid, cog, percent_identity, align_length, query_start, "
          . "query_end, subj_start, subj_end, evalue, bit_score "
          . "from gene_cog where gene_oid = ?";

        #print "MetaUtil::getGeneCogInfo() sql2: $sql2<br/>\n";
        my $sth = $dbh2->prepare($sql2);
        $sth->execute($gene_oid);

        my ( $gene_oid, @rest );
        while ( ( $gene_oid, @rest ) = $sth->fetchrow_array() ) {
            if ( !$gene_oid ) {
                last;
            }

            my $line = $gene_oid . "\t" . join( "\t", @rest );
            push @cogs, ($line);
        }

        $sth->finish();
        $dbh2->disconnect();

        return (\@cogs, $sdbFileExist);
    }

    if ( !$code ) {
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
    }

    #print "MetaUtil::getGeneCogInfo() $gene_oid, code: $code<br/>\n";
    $code = sanitizeGeneId3($code);

    my $zip_name = $name_dir . "/$tag";
    if ($code) {
        $zip_name .= "/gene2cog_" . $code;
    }
    $zip_name .= ".zip";
    if ( !( -e $zip_name ) ) {
        return (\@cogs, $sdbFileExist);
    }

    WebUtil::unsetEnvPath();

    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneCog' );
    while ( my $line = $fh->getline() ) {
        chomp($line);
        push @cogs, ($line);
    }
    close $fh;

    WebUtil::resetEnvPath();

    return (\@cogs, $sdbFileExist);
}

############################################################################
# getGeneCogId: get COG ID for this gene
############################################################################
sub getGeneCogId {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my ($cogs_ref, $sdbFileExist) = getGeneCogInfo( $gene_oid, $taxon_oid, $data_type );

    my @cogIds;
    if ( $cogs_ref && scalar(@$cogs_ref) > 0 ) {
        my %cogId_h;
        for my $line (@$cogs_ref) {
            my ( $id1, $id2, @rest ) = split( /\t/, $line );
            $cogId_h{$id2} = 1;
        }
        @cogIds = keys %cogId_h;
    }
    elsif ( ! $sdbFileExist ) {
        #use alternative for metagenomes that do not have gene_cog.sdb file or /gene2cog/gene_cog_x.sdb file
        my %genes_h;
        $genes_h{$gene_oid} = 1;
        my %gene2funcs = getTaxonGeneFuncsAlternative( $taxon_oid, $data_type, 'cog', \%genes_h );
        my $funs_ref = $gene2funcs{$gene_oid};
        if ( $funs_ref && scalar(@$funs_ref) > 0 ) {
            @cogIds = @$funs_ref;
        }
    }

    return @cogIds;
}

############################################################################
# getGenePfamInfo: get Pfam for this gene
############################################################################
sub getGenePfamInfo {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my @pfams;
    my $sdbFileExist;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $name_dir  = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
    my $tag       = "gene2pfam";
    my $code;

    my $sdb_name = $name_dir . "/gene_pfam.sdb";
    if ( !( -e $sdb_name ) ) {
        my $bin = getBinCount( $taxon_oid, $t2, $tag );
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
        if ( $bin > 1 || $code ) {
            $sdb_name = $name_dir . "/$tag/gene_pfam_" . $code . ".sdb";
        }
    }
    #print "MetaUtil::getGenePfamInfo() gene_oid: $gene_oid, sdb_name: $sdb_name<br/>\n";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        $sdbFileExist = 1;
        my $dbh2 = WebUtil::sdbLogin($sdb_name)
          or return (\@pfams, $sdbFileExist);

        my $sql2 =
            "select gene_oid, pfam, percent_identity, query_start, "
          . "query_end, subj_start, subj_end, evalue, bit_score, align_length "
          . "from gene_pfam where gene_oid = ?";
        my $sth = $dbh2->prepare($sql2);
        $sth->execute($gene_oid);

        my ( $gene_oid, @rest );
        while ( ( $gene_oid, @rest ) = $sth->fetchrow_array() ) {
            if ( !$gene_oid ) {
                last;
            }

            my $line = $gene_oid . "\t" . join( "\t", @rest );
            push @pfams, ($line);
        }

        $sth->finish();
        $dbh2->disconnect();

        return (\@pfams, $sdbFileExist);
    }

    if ( !$code ) {
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
    }
    #print "MetaUtil::getGenePfamInfo() $gene_oid, code: $code<br/>\n";
    $code = sanitizeGeneId3($code);

    my $zip_name = $name_dir . "/$tag";
    if ($code) {
        $zip_name .= "/gene2pfam_" . $code;
    }
    $zip_name .= ".zip";
    if ( !( -e $zip_name ) ) {
        return (\@pfams, $sdbFileExist);
    }

    WebUtil::unsetEnvPath();
    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'genePfam' );
    while ( my $line = $fh->getline() ) {
        chomp($line);
        push @pfams, ($line);
    }
    close $fh;

    WebUtil::resetEnvPath();

    return (\@pfams, $sdbFileExist);
}

############################################################################
# getGenePfamId: get Pfam IDs for this gene
############################################################################
sub getGenePfamId {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;
    
    my ($pfams_ref, $sdbFileExist) = getGenePfamInfo( $gene_oid, $taxon_oid, $data_type );

    my @pfamIds;
    if ( $pfams_ref && scalar(@$pfams_ref) > 0 ) {
        my %pfamId_h;
        for my $line (@$pfams_ref) {
            my ( $id1, $id2, @rest ) = split( /\t/, $line );
            $pfamId_h{$id2} = 1;
        }
        @pfamIds = keys %pfamId_h;
    }
    elsif ( ! $sdbFileExist ) {
        #use alternative for metagenomes that do not have gene_pfam.sdb file or /gene2pfam/gene_pfam_x.sdb file
        my %genes_h;
        $genes_h{$gene_oid} = 1;
        my %gene2funcs = getTaxonGeneFuncsAlternative( $taxon_oid, $data_type, 'pfam', \%genes_h );
        my $funs_ref = $gene2funcs{$gene_oid};
        if ( $funs_ref && scalar(@$funs_ref) > 0 ) {
            @pfamIds = @$funs_ref;
        }
    }

    return @pfamIds;
}

############################################################################
# getGeneTIGRfamInfo: get TIGRfam information for this gene
############################################################################
sub getGeneTIGRfamInfo {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my @tigrfams;
    my $sdbFileExist;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $name_dir  = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
    my $tag       = "gene2tigr";
    my $code;

    ## check sqlite first
    my $sdb_name = $name_dir . "/gene_tigr.sdb";
    if ( !( -e $sdb_name ) ) {
        my $bin = getBinCount( $taxon_oid, $t2, $tag );
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
        if ( $bin > 1 || $code ) {
            $sdb_name = $name_dir . "/$tag/gene_tigr_" . $code . ".sdb";
        }
    }
    #print "MetaUtil::getGeneTIGRfamInfo() gene_oid: $gene_oid, sdb_name: $sdb_name<br/>\n";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        $sdbFileExist = 1;
        my $dbh2 = WebUtil::sdbLogin($sdb_name)
          or return (\@tigrfams, $sdbFileExist);

        my $sql2 =
            "select gene_oid, tigr, bit_score, percent_identity, "
          . "evalue, sfstart, sfend "
          . "from gene_tigr where gene_oid = ?";
        my $sth = $dbh2->prepare($sql2);
        $sth->execute($gene_oid);

        my ( $gene_oid, @rest );
        while ( ( $gene_oid, @rest ) = $sth->fetchrow_array() ) {
            if ( !$gene_oid ) {
                last;
            }

            my $line = $gene_oid . "\t" . join( "\t", @rest );
            push (@tigrfams, $line);
        }

        $sth->finish();
        $dbh2->disconnect();

        return (\@tigrfams, $sdbFileExist);
    }

    if ( !$code ) {
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
    }
    #print "MetaUtil::getGeneTIGRfamInfo() $gene_oid, code: $code<br/>\n";
    $code = sanitizeGeneId3($code);

    my $zip_name = $name_dir . "/$tag";
    if ($code) {
        $zip_name .= "/gene2tigr_" . $code;
    }
    $zip_name .= ".zip";
    if ( !( -e $zip_name ) ) {
        return (\@tigrfams, $sdbFileExist);
    }

    WebUtil::unsetEnvPath();

    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my %tigrfam_score;
    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneTigrfam' );
    while ( my $line = $fh->getline() ) {
        chomp($line);
        push (@tigrfams, $line);
    }
    close $fh;

    WebUtil::resetEnvPath();

    return (\@tigrfams, $sdbFileExist);
}


############################################################################
# getGeneTIGRfamId: get TIGRfam ID (only) for this gene
############################################################################
sub getGeneTIGRfamId {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my ($tigrfams_ref, $sdbFileExist) = getGeneTIGRfamInfo( $gene_oid, $taxon_oid, $data_type );

    my @tigrfamIds;
    if ( $tigrfams_ref && scalar(@$tigrfams_ref) > 0 ) {
        my %tigrfamId_h;
        for my $line (@$tigrfams_ref) {
            my ( $id1, $id2, @rest ) = split( /\t/, $line );
            $tigrfamId_h{$id2} = 1;
        }
        @tigrfamIds = keys %tigrfamId_h;
    }
    elsif ( ! $sdbFileExist ) {
        #use alternative for metagenomes that do not have gene_tigr.sdb file or /gene2tigr/gene_tigr_x.sdb file
        my %genes_h;
        $genes_h{$gene_oid} = 1;
        my %gene2funcs = getTaxonGeneFuncsAlternative( $taxon_oid, $data_type, 'tigr', \%genes_h );
        my $funs_ref = $gene2funcs{$gene_oid};
        if ( $funs_ref && scalar(@$funs_ref) > 0 ) {
            @tigrfamIds = @$funs_ref;
        }
    }

    return @tigrfamIds;
}

############################################################################
# getGeneKoInfo: get KO for this gene
############################################################################
sub getGeneKoInfo {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my @kos;
    my $sdbFileExist;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $name_dir  = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
    my $tag       = "gene2ko";
    my $code;

    ## check sqlite first
    my $sdb_name = $name_dir . "/gene_ko.sdb";
    if ( !( -e $sdb_name ) ) {
        my $bin = getBinCount( $taxon_oid, $t2, $tag );
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
        if ( $bin > 1 || $code ) {
            $sdb_name = $name_dir . "/$tag/gene_ko_" . $code . ".sdb";
        }
    }
    #print "MetaUtil::getGeneKoInfo() gene_oid: $gene_oid, sdb_name: $sdb_name<br/>\n";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        $sdbFileExist = 1;
        my $dbh2 = WebUtil::sdbLogin($sdb_name)
          or return (\@kos, $sdbFileExist);

        my $sql2 =
            "select gene_oid, ko, percent_identity, query_start, "
          . "query_end, subj_start, subj_end, evalue, bit_score, align_length "
          . "from gene_ko where gene_oid = ?";
        my $sth = $dbh2->prepare($sql2);
        $sth->execute($gene_oid);

        my ( $gene_oid, @rest );
        while ( ( $gene_oid, @rest ) = $sth->fetchrow_array() ) {
            if ( !$gene_oid ) {
                last;
            }

            my $line = $gene_oid . "\t" . join( "\t", @rest );
            push @kos, ($line);
        }

        $sth->finish();
        $dbh2->disconnect();

        return (\@kos, $sdbFileExist);
    }

    if ( !$code ) {
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
    }
    #print "MetaUtil::getGeneKoInfo() $gene_oid, code: $code<br/>\n";
    $code = sanitizeGeneId3($code);

    my $zip_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/gene2ko";
    if ($code) {
        $zip_name .= "/gene2ko_" . $code;
    }
    $zip_name .= ".zip";

    if ( !( -e $zip_name ) ) {
        return (\@kos, $sdbFileExist);
    }

    WebUtil::unsetEnvPath();
    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneKo' );
    while ( my $line = $fh->getline() ) {
        chomp($line);
        push @kos, ($line);
    }
    close $fh;

    WebUtil::resetEnvPath();

    return (\@kos, $sdbFileExist);
}

############################################################################
# getGeneKoId: get KO ID (only) for this gene
############################################################################
sub getGeneKoId {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my ($kos_ref, $sdbFileExist) = getGeneKoInfo( $gene_oid, $taxon_oid, $data_type );

    my @koIds;
    if ( $kos_ref && scalar(@$kos_ref) > 0 ) {
        for my $line (@$kos_ref) {
            my @flds = split( /\t/, $line );
            if ( scalar(@flds) > 3 ) {
                my $ko_id;
                if ( $flds[3] =~ /^KO/ ) {
                    $ko_id = $flds[3];
                } elsif ( $flds[1] =~ /^KO/ ) {
                    $ko_id = $flds[1];
                }
                push @koIds, ($ko_id);
            }
        }
    }
    elsif ( ! $sdbFileExist ) {
        #use alternative for metagenomes that do not have gene_ko.sdb file or /gene2ko/gene_ko_x.sdb file
        my %genes_h;
        $genes_h{$gene_oid} = 1;
        my %gene2funcs = getTaxonGeneFuncsAlternative( $taxon_oid, $data_type, 'ko', \%genes_h );
        my $funs_ref = $gene2funcs{$gene_oid};
        if ( $funs_ref && scalar(@$funs_ref) > 0 ) {
            @koIds = @$funs_ref;
        }
    }

    return @koIds;
}

############################################################################
# getGeneHomoTaxon
############################################################################
sub getGeneHomoTaxon {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    for my $percent ( 30, 60, 90 ) {
        my $full_dir_name = getPhyloDistTaxonDir($taxon_oid) . "/" . $data_type . "." . $percent . ".sdb";
        if ( -e $full_dir_name ) {

            # use sdb
            my $dbh3 = WebUtil::sdbLogin($full_dir_name)
              or next;

            my $sql3 = getPhyloDistSingleGeneSql();
            my $sth  = $dbh3->prepare($sql3);
            $sth->execute($gene_oid);
            my ( $g_id2, $gene_perc, $homolog_gene, $homo_taxon, $copies ) = $sth->fetchrow_array();
            $sth->finish();
            $dbh3->disconnect();

            if ($homo_taxon) {
                return $homo_taxon;
            }
        }
    }

    return 0;
}

sub getPhyloGenesForHomoTaxon {
    my ( $taxon_oid, $data_type, $homo_taxon, @percent_identities ) = @_;

    my %phylo_genes_h;

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        for my $percent (@percent_identities) {
            my $full_dir_name = getPhyloDistTaxonDir($taxon_oid) . "/" . $t2 . "." . $percent . ".sdb";
            if ( -e $full_dir_name ) {

                # use sdb
                my $dbh3 = WebUtil::sdbLogin($full_dir_name)
                  or next;

                my $sql = getPhyloDistSingleHomoTaxonSql();
                my $sth = $dbh3->prepare($sql);
                $sth->execute($homo_taxon);
                my ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon2, $copies );
                while ( ( $gene_oid, $gene_perc, $homolog_gene, $homo_taxon2, $copies ) = $sth->fetchrow_array() ) {
                    last if ( !$gene_oid );

                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    $phylo_genes_h{$workspace_id} = "$gene_oid\t$gene_perc\t$homolog_gene\t$copies";
                }
            }
        }
    }

    return %phylo_genes_h;
}

############################################################################
# getGeneEc: get EC for this gene
############################################################################
sub getGeneEc {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my @ecs;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $name_dir  = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
    my $tag       = "gene2ec";
    my $code;

    ## check sqlite first
    my $sdb_name = $name_dir . "/gene_ec.sdb";
    if ( !( -e $sdb_name ) ) {
        my $bin = getBinCount( $taxon_oid, $t2, $tag );
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
        if ( $bin > 1 || $code ) {
            $sdb_name = $name_dir . "/$tag/gene_ec_" . $code . ".sdb";
        }
    }
    #print "MetaUtil::getGeneEc() gene_oid: $gene_oid, sdb_name: $sdb_name<br/>\n";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh2 = WebUtil::sdbLogin($sdb_name)
          or return @ecs;

        my $sql2 = "select gene_oid, ec " . "from gene_ec where gene_oid = ?";
        my $sth  = $dbh2->prepare($sql2);
        $sth->execute($gene_oid);

        my ( $gene_oid, $ec );
        while ( ( $gene_oid, $ec ) = $sth->fetchrow_array() ) {
            if ( !$gene_oid ) {
                last;
            }

            push @ecs, ($ec);
        }

        $sth->finish();
        $dbh2->disconnect();

        return @ecs;
    }
    else {        
        #use alternative for metagenomes that do not have gene_ec.sdb file or /gene2ec/gene_ec_x.sdb file
        my %genes_h;
        $genes_h{$gene_oid} = 1;
        my %gene2funcs = getTaxonGeneFuncsAlternative( $taxon_oid, $data_type, 'ec', \%genes_h );
        my $funs_ref = $gene2funcs{$gene_oid};
        if ( $funs_ref && scalar(@$funs_ref) > 0 ) {
            @ecs = @$funs_ref;
        }
        
        return @ecs;
    }

    if ( !$code ) {
        $code = HashUtil::get_hash_code( $hash_file, $tag, $gene_oid );
    }
    #print "MetaUtil::getGeneEc() $gene_oid, code: $code<br/>\n";
    $code = sanitizeGeneId3($code);

    my $zip_name = $name_dir . "/$tag";
    if ($code) {
        $zip_name .= "/gene2ec_" . $code;
    }
    $zip_name .= ".zip";

    if ( !( -e $zip_name ) ) {
        return @ecs;
    }

    WebUtil::unsetEnvPath();
    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneEc' );
    while ( my $line = $fh->getline() ) {
        chomp($line);
        push @ecs, ($line);
    }
    close $fh;

    WebUtil::resetEnvPath();

    return @ecs;
}

############################################################################
# getGeneEstCopy
############################################################################
sub getGeneEstCopy {
    my ( $taxon_oid, $data_type, $gene_oid ) = @_;

    if ( $data_type eq 'both' || blankStr($data_type) ) {
        $data_type = 'assembled';
    }
    if ( $data_type ne 'assembled' ) {
        return 1;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my %gene_copies_h;

    # check sqlite
    my $db_file_name = $mer_data_dir . "/" . $taxon_oid . "/assembled/gene_copy.sdb";

    if ( -e $db_file_name ) {
        my $dbh2 = WebUtil::sdbLogin($db_file_name)
          or return 1;

        my $sql2 = "select gene_copy from gene_copy where gene_oid = '" . $gene_oid . "'";
        my $sth  = $dbh2->prepare($sql2);
        $sth->execute();
        my ($g_copy) = $sth->fetchrow_array();
        if ( !$g_copy ) {
            $g_copy = 1;
        }
        $sth->finish();
        $dbh2->disconnect();

        return $g_copy;
    }

    # check for DB first
    $db_file_name = $mer_data_dir . "/" . $taxon_oid . "/assembled/gene_copy.db";

    if ( -e $db_file_name ) {
        tie %gene_copies_h, "BerkeleyDB::Hash",
          -Filename => $db_file_name,
          -Flags    => DB_RDONLY,
          -Property => DB_DUP;
    }

    if ( tied(%gene_copies_h) ) {
        my $g_copy = 1;
        if ( $gene_copies_h{$gene_oid} ) {
            $g_copy = $gene_copies_h{$gene_oid};
        }

        untie %gene_copies_h;
        return $g_copy;
    }

    # get data from zip
    my $zip_name = $mer_data_dir . "/" . $taxon_oid . "/assembled/gene_copy.zip";
    if ( !( -e $zip_name ) ) {
        return;
    }

    WebUtil::unsetEnvPath();

    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $gene_copy = 1;
    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneEstCopy' );
    while ( my $line = $fh->getline() ) {
        chomp($line);

        my ( $gid, $n ) = split( /\t/, $line );
        if ($n) {
            $gene_copy = $n;
            last;
        }
    }
    close $fh;

    WebUtil::resetEnvPath();
    return $gene_copy;
}

############################################################################
# getGeneScaffold
############################################################################
sub getGeneScaffold {
    my ( $taxon_oid, $data_type, $gene_oid ) = @_;

    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $data_type . "/taxon_hash.txt";
    my $code      = HashUtil::get_hash_code( $hash_file, "gene", $gene_oid );

    # read gene info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }
    $taxon_oid = sanitizeInt($taxon_oid);

    my $zip_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/gene";
    if ($code) {
        $code = sanitizeGeneId3($code);
        $zip_name .= "/gene_" . $code;
    }
    my $sdb_name = $zip_name . ".sdb";
    $zip_name .= ".zip";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = "select gene_oid, start_coord, end_coord, strand, scaffold_oid " . "from gene where gene_oid = ?";
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute($gene_oid);
        my ( $id3, $start_coord, $end_coord, $strand, $scaffold_oid ) = $sth->fetchrow_array();
        $sth->finish();
        $dbh3->disconnect();
        return ( $start_coord, $end_coord, $strand, $scaffold_oid );
    }

    if ( !( -e $zip_name ) ) {
        return ( 0, 0, "", "" );
    }

    WebUtil::unsetEnvPath();

    my $i2 = $gene_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneInfo' );
    my $line = $fh->getline();
    chomp($line);

    my @vals = split( /\t/, $line );
    my ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid ) =
      split( /\t/, $line );
    if ( scalar(@vals) > 7 ) {
        my $id2;
        ( $id2, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $scaffold_oid ) =
          split( /\t/, $line );
    }
    close $fh;

    WebUtil::resetEnvPath();

    return ( $start_coord, $end_coord, $strand, $scaffold_oid );
}

sub getGeneScaffoldWorkspaceId {
    my ( $taxon_oid, $data_type, $gene_oid ) = @_;

    my ( $start_coord, $end_coord, $strand, $scaffold_oid ) = getGeneScaffold( $taxon_oid, $data_type, $gene_oid );

    return "$taxon_oid $data_type $scaffold_oid";
}

############################################################################
# getGeneBBH
############################################################################
sub getGeneBBH {
    my ( $taxon_oid, $data_type, $gene_oid ) = @_;

    my $taxon_oid = sanitizeInt($taxon_oid);
    my @type_list = getDataTypeList($data_type);

    WebUtil::unsetEnvPath();

    my $bbh          = "";
    my $phylo_prefix = "";
    my $percent      = 30;
    for my $t2 (@type_list) {
        if ($bbh) {
            last;
        }

        for my $percent ( 30, 60, 90 ) {
            if ($bbh) {
                last;
            }

            my $full_dir_name = getPhyloDistTaxonDir($taxon_oid) . "/" . $phylo_prefix . $t2 . "." . $percent . ".sdb";
            if ( -e $full_dir_name ) {

                # use sdb
                my $dbh3 = WebUtil::sdbLogin($full_dir_name)
                  or next;
                my $sql3 = getPhyloDistSingleGeneSql();
                my $sth  = $dbh3->prepare($sql3);
                $sth->execute($gene_oid);
                my ( $g_id2, $gene_perc, $homolog_gene, $homo_taxon, $copies ) = $sth->fetchrow_array();
                $sth->finish();
                $dbh3->disconnect();

                if ($g_id2) {
                    $bbh = "$g_id2\t$gene_perc\t$homolog_gene\t$homo_taxon\t$copies";
                    return $bbh;
                }
            }
        }    # end for percent
    }    # end for t2

    WebUtil::resetEnvPath();

    return $bbh;
}

############################################################################
# getGenomeScaffoldWorkspaceId
############################################################################
sub getGenomeScaffoldWorkspaceId_old {
    my ( $taxon_oid, $data_type, $print_msg ) = @_;

    if ($print_msg) {
        print "Check metagenome $taxon_oid $data_type ...<br/>\n";
    }

    my @zip_list_members;
    my $tag = 'fileList';

    $taxon_oid = sanitizeInt($taxon_oid);
    my $full_dir_name = $mer_data_dir . "/" . $taxon_oid . "/$data_type/scaffold_stats/";
    if ( !( -e $full_dir_name ) ) {
        if ($print_msg) {
            print "Cannot find directory $full_dir_name ...</br>\n";
        }
        return @zip_list_members;
    }

    my @dir_zip_file_members;
    opendir( DIR, $full_dir_name ) || webDie("Cannot open directory '$full_dir_name' \n");
    my @files = readdir(DIR);
    foreach my $file (@files) {
        if ( $file =~ /stats/i ) {
            push( @dir_zip_file_members, $file );
        }
    }
    closedir(DIR);

    if ( scalar(@dir_zip_file_members) > 0 ) {

        #WebUtil::unsetEnvPath();
        for my $zip_name (@dir_zip_file_members) {
            if ($print_msg) {
                print "unzip file $zip_name ...</br>\n";
            }

            $zip_name = $full_dir_name . $zip_name;
            if ( !( -e $zip_name ) ) {
                next;
            }

            my $zip = Archive::Zip->new();
            $zip->read($zip_name);
            my @members = $zip->members();
            for my $m (@members) {
                my $memberFileName = $m->fileName();

                #print "member file name: $memberFileName</br>\n";
                my $workspace_id = "$taxon_oid $data_type $memberFileName";
                push( @zip_list_members, $workspace_id );
            }
        }

        #WebUtil::resetEnvPath();
    }

    return @zip_list_members;
}

#
# use sdb file
sub getGenomeScaffoldWorkspaceId {
    my ( $taxon_oid, $data_type, $print_msg ) = @_;

    if ($print_msg) {
        print "Check metagenome $taxon_oid $data_type ...<br/>\n";
    }

    my @zip_list_members;

    $taxon_oid = sanitizeInt($taxon_oid);
    my @type_list = getDataTypeList($data_type);
    for my $d2 (@type_list) {
        my $sdb_name = $mer_data_dir . "/" . $taxon_oid . "/$d2/scaffold_stats.sdb";
        if ( !( -e $sdb_name ) ) {
            if ($print_msg) {
                print "Cannot find directory $sdb_name ...</br>\n";
            }
            next;
        }

        my $dbh3 = WebUtil::sdbLogin($sdb_name) or next;
        my $sql3 = "select scaffold_oid from scaffold_stats ";
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute( );

        for ( ; ; ) {
            my ( $id3 ) = $sth->fetchrow_array();
            last if !$id3;
            my $workspace_id = "$taxon_oid $d2 $id3";
            push( @zip_list_members, $workspace_id );
        }
        $sth->finish();
        $dbh3->disconnect();
    }
    
    return @zip_list_members;
}

############################################################################
# getGenomeStats
############################################################################
sub getGenomeStats {
    my ( $taxon_oid, $data_type, $stats ) = @_;

    my @type_list = getDataTypeList($data_type);

    my $count = 0;
    $taxon_oid = sanitizeInt($taxon_oid);

    for my $t2 (@type_list) {
        my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/taxon_stats.txt";
        if ( !( -e $file_name ) ) {
            next;
        }
        my $fh = newReadFileHandle($file_name);
        if ( !$fh ) {
            next;
        }
        my $line = "";
        while ( $line = $fh->getline() ) {
            chomp $line;
            my ( $tag, $val ) = split( /\t/, $line );

            if ( $tag =~ /$stats/ ) {
                $count += $val;
                last;
            }
        }
        close $fh;
    }

    return $count;
}


############################################################################
# getFuncTagFromFuncType
############################################################################
sub getFuncTagFromFuncType {
    my ( $func_type ) = @_;

    my $func_tag;
    if ( $func_type =~ /COG/i ) {
        $func_tag = "cog";
    }
    elsif ( $func_type =~ /PFAM/i ) {
        $func_tag = "pfam";
    }
    elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRfam/i ) {
        $func_tag = "tigr";
    }
    elsif ( $func_type =~ /KO/i ) {
        $func_tag = "ko";
    }
    elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i ) {
        $func_tag = "ec";
    }

    return $func_tag;
}

############################################################################
# getFuncTagFromFuncId
############################################################################
sub getFuncTagFromFuncId {
    my ( $func_id ) = @_;

    my $func_tag;
    
    if (   $func_id =~ /COG\_Category/i
        || $func_id =~ /COG\_Pathway/i ) {
        $func_tag = "cog";
    } 
    elsif ( $func_id =~ /COG/i ) {
        $func_tag = "cog";
    } 
    elsif ( $func_id =~ /Pfam\_Category/i ) {
        $func_tag = "pfam";
    } 
    elsif ( $func_id =~ /pfam/i ) {
        $func_tag = "pfam";
    } 
    elsif ( $func_id =~ /TIGRfam\_Role/i ) {
        $func_tag = "tigr";
    } 
    elsif ( $func_id =~ /TIGR/i ) {
        $func_tag = "tigr";
    } 
    elsif ( $func_id =~ /KEGG\_Category\_KO/i
        || $func_id =~ /KEGG\_Pathway\_KO/i )
    {
        $func_tag = "ko";
    } 
    elsif ( $func_id =~ /KO/i ) {
        $func_tag = "ko";
    } 
    elsif ( $func_id =~ /KEGG\_Category\_EC/i
        || $func_id =~ /KEGG\_Pathway\_EC/i )
    {
        $func_tag = "ec";
    } 
    elsif ( $func_id =~ /EC/i ) {
        $func_tag = "ec";
    } 
    elsif ( $func_id =~ /MetaCyc/i ) {
        $func_tag = "ec";
    } 

    return $func_tag;
}


############################################################################
# getTaxonFuncsGenes
# try to use $limiting_genes_href to improve performance, 
# but final filtering still needs to be performed later on
############################################################################
sub getTaxonFuncsGenes {
    my ( $taxon_oid, $data_type, $func_type, $func_id_aref, $limiting_genes_href ) = @_;

    my %h;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $file_name_base = $mer_data_dir . "/" . $taxon_oid . "/";

    my @type_list = getDataTypeList($data_type);
    foreach my $t2 (@type_list) {
        #print "getTaxonFuncsGenes() $taxon_oid $t2 $func_type <br/>\n";

        my $fname;
        my $func_attr;
        if ( $func_type =~ /COG/i ) {
            $fname     = 'cog_genes';
            $func_attr = "cog";
        } elsif ( $func_type =~ /PFAM/i ) {
            $fname     = 'pfam_genes';
            $func_attr = "pfam";
        } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
            $fname     = 'tigr_genes';
            $func_attr = "tigr";
        } elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
            $fname     = 'ec_genes';
            $func_attr = "ec";
        } elsif ( $func_type =~ /KO/i ) {
            $fname     = 'ko_genes';
            $func_attr = "ko";
        } else {
            next;
        }

        # check sqlite
        my $sdb_name = $file_name_base . $t2 . "/" . $fname . ".sdb";
        #print "getTaxonFuncsGenes() sdb_name: $sdb_name<br/>\n";
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            my $dbh2 = WebUtil::sdbLogin($sdb_name)
              or return %h;

            my $sql2 = "select $func_attr, genes from " . $func_attr . "_genes";
            #print "getTaxonFuncsGenes() func_id_aref: @$func_id_aref<br/>\n" if ($func_id_aref);
            #if ($limiting_genes_href) {
            #    print "getTaxonFuncsGenes() limiting_genes_href:<br/>\n";                
            #    print Dumper($limiting_genes_href);
            #    print "<br/>\n";
            #}
            if ( $func_id_aref && scalar(@$func_id_aref) > 0 ) {
                my $cond = " where $func_attr in ('" . join( "', '", @$func_id_aref ) . "') ";
                $sql2 .= $cond;
            }
            
            if ( $limiting_genes_href ) {
                my @limiting_genes = keys %$limiting_genes_href;
                #limit the size to 20
                if ( scalar(@limiting_genes) > 0 && scalar(@limiting_genes) <= 20 ) {
                    if ( $func_id_aref && scalar(@$func_id_aref) > 0 ) {
                        $sql2 .= " and ";
                    }
                    else {
                        $sql2 .= " where ";                        
                    }
    
                    my $cond;
                    my $cnt = 0;
                    for my $gene_oid (@limiting_genes) {
                        if ( $cnt > 0 ) {
                            $cond .= " or ";
                        }
                        $cond .= " genes like '%$gene_oid%' ";
                        $cnt++;
                    }
                    $sql2 .= '(' . $cond . ')';
                }
            }
            #print "getTaxonFuncsGenes() sql2: $sql2<br/>\n";

            my $sth = $dbh2->prepare($sql2);
            $sth->execute();

            my ( $id2, $genes );
            while ( ( $id2, $genes ) = $sth->fetchrow_array() ) {
                if ( !$id2 ) {
                    last;
                }
                if ( $genes ) {
                    if ( $limiting_genes_href && scalar(keys %$limiting_genes_href) > 0 ) {
                        my @genes_array = split( /\t/, $genes );
                        foreach my $gene ( @genes_array ) {
                            if ( $limiting_genes_href->{$gene} ) {
                                my $genes_str = $h{$id2};
                                if ($genes_str) {
                                    if ( $genes_str =~ /\t$/ ) {
                                        $h{$id2} = $genes_str . $genes;
                                    } else {
                                        $h{$id2} = $genes_str . "\t" . $genes;
                                    }
                                } else {
                                    $h{$id2} = $genes;
                                }
                                last;
                            }
                        }
                    }
                    else {
                        my $genes_str = $h{$id2};
                        if ($genes_str) {
                            if ( $genes_str =~ /\t$/ ) {
                                $h{$id2} = $genes_str . $genes;
                            } else {
                                $h{$id2} = $genes_str . "\t" . $genes;
                            }
                        } else {
                            $h{$id2} = $genes;
                        }                    
                    }
                }

                #if ( $id2 eq 'COG1056' || $id2 eq 'COG1057' ) {
                #    print "getTaxonFuncsGenes() $id2: " . $h{$id2} . " <br/>\n";
                #}
            }
            $sth->finish();
            $dbh2->disconnect();
        }

    }

    return %h;
}

############################################################################
# getTaxonCategories - reads the precomputed count file for fn categories
############################################################################
sub getTaxonCategories {
    my ( $taxon_oid, $data_type, $func_type, $funcs_ref ) = @_;

    my $fname;
    if ( $func_type =~ /COG/i ) {
        $fname = 'cog_cate_count.txt';
    } elsif ( $func_type =~ /PFAM/i ) {
        $fname = 'pfam_cate_count.txt';
    } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
        $fname = 'tigr_cate_count.txt';
    #} elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
    #} elsif ( $func_type =~ /KO/i ) {
    } elsif ( $func_type =~ /METACYC/i ) {
        $fname = 'metacyc_count.txt';
    } else {
        return -1;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname;
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }

            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );
                if ( defined( $funcs_ref->{$id} ) ) {
                    $funcs_ref->{$id} += $cnt;
                }
            }
            close $fh;
        }
    }
    return 0;
}

############################################################################
# getTaxonCate
############################################################################
sub getTaxonCate {
    my ( $taxon_oid, $data_type, $func_type ) = @_;

    my %funcs;
    my $fname;
    if ( $func_type =~ /COG/i ) {
        $fname = 'cog_cate_count.txt';
    } elsif ( $func_type =~ /PFAM/i ) {
        $fname = 'pfam_cate_count.txt';
    } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
        $fname = 'tigr_cate_count.txt';
    #} elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
    #} elsif ( $func_type =~ /KO/i ) {
    } elsif ( $func_type =~ /KEGG/i ) {
        $fname = 'kegg_count.txt';
    } elsif ( $func_type =~ /METACYC/i ) {
        $fname = 'metacyc_count.txt';
    } else {
        return %funcs;
    }
    
    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname;
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }

            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );
                if ( $funcs{$id} ) {
                    $funcs{$id} += $cnt;
                } else {
                    $funcs{$id} = $cnt;
                }
            }    # end while line
            close $fh;
        }
    }    # end for t2

    return %funcs;
}

############################################################################
# getTaxonCate2: for TIGRfam_Role
############################################################################
sub getTaxonCate2 {
    my ( $taxon_oid, $data_type, $func_type, $funcs_ref ) = @_;

    my %cate_h;
    my %funcs;
    %funcs = %$funcs_ref if $funcs_ref ne "";
    my $base_type = "";
    my $sql       = "";

    if ( $func_type =~ /cog_pathway/i ) {
        $base_type = "cog";
        $sql       = qq{
            select unique cpcm.cog_pathway_oid, cpcm.cog_members
            from cog_pathway_cog_members cpcm
        };
    } elsif ( $func_type =~ /kegg_category_ec/i ) {
        $base_type = "ec";
        $sql       = qq{
    	    select unique kp.category, kte.enzymes
    	    from image_roi ir, ko_term_enzymes kte,
    	    image_roi_ko_terms irkt, kegg_pathway kp
    	    where ir.roi_id = irkt.roi_id 
            and irkt.ko_terms = kte.ko_id
            and ir.pathway = kp.pathway_oid
        };
    } elsif ( $func_type =~ /kegg_category_ko/i ) {
        $base_type = "ko";
        $sql       = qq{
            select unique kp.category, rk.ko_terms 
            from image_roi ir, image_roi_ko_terms rk, kegg_pathway kp 
            where ir.roi_id = rk.roi_id and ir.pathway = kp.pathway_oid
        };
    } elsif ( $func_type =~ /kegg_pathway_ec/i ) {
        $base_type = "ec";
        $sql       = qq{
	    select unique ir.pathway, kte.enzymes 
	    from image_roi ir, ko_term_enzymes kte,
	    image_roi_ko_terms irkt
	    where ir.roi_id = irkt.roi_id
            and irkt.ko_terms = kte.ko_id
        };
    } elsif ( $func_type =~ /kegg_pathway_ko/i ) {
        $base_type = "ko";
        $sql       = qq{
            select unique ir.pathway, rk.ko_terms 
            from image_roi ir, image_roi_ko_terms rk 
            where ir.roi_id = rk.roi_id
        };
    } elsif ( $func_type =~ /metacyc/i ) {
        $base_type = "ec";
        $sql       = qq{
            select unique brp.in_pwys, br.ec_number 
            from biocyc_reaction_in_pwys brp, biocyc_reaction br 
            where brp.unique_id = br.unique_id
        };
    } elsif ( $func_type =~ /tigrfam_role/i ) {
        $base_type = "tigr";
        $sql       = qq{
            select unique trs.roles, trs.ext_accession 
            from tigrfam_roles trs
        };
    } else {
        return %funcs;
    }

    my $dbh = dbLogin();

    my %kegg_cate_h;
    if (   $func_type =~ /kegg_category_ec/i
        || $func_type =~ /kegg_category_ko/i )
    {
        my $sql2 = qq{
            select kp.category, min(kp.pathway_oid) 
            from kegg_pathway kp 
            group by kp.category
        };
        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ( $cate_id, $pwy_id ) = $cur2->fetchrow();
            last if !$cate_id;
            $kegg_cate_h{$cate_id} = $pwy_id;
        }
        $cur2->finish();
    }

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $cate_id, $func_id ) = $cur->fetchrow();
        last if !$cate_id;

        if (   $func_type =~ /kegg_category_ec/i
            || $func_type =~ /kegg_category_ko/i )
        {
            if ( $kegg_cate_h{$cate_id} ) {
                $cate_id = $kegg_cate_h{$cate_id};
            }
        }

        if ( $cate_h{$cate_id} ) {
            $cate_h{$cate_id} .= "\t" . $func_id;
        } else {
            $cate_h{$cate_id} = $func_id;
        }
    }
    $cur->finish();

    #$dbh->disconnect();

    my @keys = ( keys %cate_h );
    if ( scalar(@keys) == 0 ) {
        return %funcs;
    }

    my @type_list = getDataTypeList($data_type);
    foreach my $t2 (@type_list) {
        my %h = MetaUtil::getTaxonFuncsGenes( $taxon_oid, $t2, $base_type );

        foreach my $key (@keys) {
            next if ( $funcs_ref ne "" && !defined( $funcs_ref->{$key} ) );
            my %workspace_h;
            my @func_ids = split( /\t/, $cate_h{$key} );
            foreach my $func_id (@func_ids) {
                my @recs = split( /\t/, $h{$func_id} );
                foreach my $gene_oid (@recs) {
                    $workspace_h{$gene_oid} = 1;
                }
            }    # end for func_id

            my $cnt = scalar( keys %workspace_h );
            if ( $funcs{$key} ) {
                $funcs{$key} += $cnt;
            } else {
                $funcs{$key} = $cnt;
            }
        }    # end for key
    }    # end for t2

    return %funcs;
}

############################################################################
# getTaxonFuncCount
############################################################################
sub getTaxonFuncCount {
    my ( $taxon_oid, $data_type, $func_type ) = @_;

    my %funcs;

    if ($new_func_count) {
        my $f_table_name = "";
        if ( $func_type =~ /COG/i ) {
            $f_table_name = 'taxon_cog_count';
        } elsif ( $func_type =~ /PFAM/i ) {
            $f_table_name = 'taxon_pfam_count';
        } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
            $f_table_name = 'taxon_tigr_count';
        } elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
            $f_table_name = 'taxon_ec_count';
        } elsif ( $func_type =~ /KO/i ) {
            $f_table_name = 'taxon_ko_count';
        }

        if ( $f_table_name ne '' ) {
            my $dataTypeClause = '';
            if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                $dataTypeClause = " and data_type='$data_type' ";
            }

            my $sql = qq{
                select taxon_oid, data_type, func_id, gene_count 
                from $f_table_name
                where taxon_oid = ?
                $dataTypeClause
            };

            #print "getTaxonFuncCount() sql: $sql<br/>\n";
            my $dbh = dbLogin();
            my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
            for ( ; ; ) {
                my ( $t2, $d2, $id, $cnt ) = $cur->fetchrow();
                last if !$t2;

                if ( $funcs{$id} ) {
                    $funcs{$id} += $cnt;
                } else {
                    $funcs{$id} = $cnt;
                }
            }
            $cur->finish();

            #$dbh->disconnect();

            return %funcs;
        }
    }

    my $fname;
    if ( $func_type =~ /COG/i ) {
        $fname = 'cog_count.txt';
    } elsif ( $func_type =~ /PFAM/i ) {
        $fname = 'pfam_count.txt';
    } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
        $fname = 'tigr_count.txt';
    } elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
        $fname = 'ec_count.txt';
    } elsif ( $func_type =~ /KO/i ) {
        $fname = 'ko_count.txt';
    } elsif ( lc($func_type) eq 'kegg' ) {
        $fname = 'kegg_cate.txt';
    } elsif ( lc($func_type) eq 'kegg_pathway' ) {
        $fname = 'kegg_count.txt';
    } elsif ( $func_type =~ /METACYC/i ) {
        $fname = 'metacyc_count.txt';
    } else {
        return %funcs;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname;
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }
            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );
                if ( $funcs{$id} ) {
                    $funcs{$id} += $cnt;
                } else {
                    $funcs{$id} = $cnt;
                }
            }    # end while line
            close $fh;
        }
    }    # end for t2

    return %funcs;
}

############################################################################
# getTaxonOneFuncCnt: get one function count
############################################################################
sub getTaxonOneFuncCnt {
    my ( $taxon_oid, $data_type, $func_id ) = @_;

    my $func_count = 0;

    if ($new_func_count) {
        my $f_table_name = "";
        if ( $func_id =~ /COG/i ) {
            $f_table_name = 'taxon_cog_count';
        } elsif ( $func_id =~ /pfam/i ) {
            $f_table_name = 'taxon_pfam_count';
        } elsif ( $func_id =~ /TIGR/i ) {
            $f_table_name = 'taxon_tigr_count';
        } elsif ( $func_id =~ /EC\:/i ) {
            $f_table_name = 'taxon_ec_count';
        } elsif ( $func_id =~ /KO\:/i ) {
            $f_table_name = 'taxon_ko_count';
        }

        if ( $f_table_name ne '' ) {
            my $dataTypeClause = '';
            if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                $dataTypeClause = " and data_type='$data_type' ";
            }

            my $sql = qq{
                select taxon_oid, data_type, func_id, gene_count 
                from $f_table_name
                where taxon_oid = ?
                and func_id = ?
                $dataTypeClause
            };

            my $dbh = dbLogin();
            my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $func_id );
            for ( ; ; ) {
                my ( $t2, $d2, $id, $cnt ) = $cur->fetchrow();
                last if !$t2;
                if ( $id eq $func_id ) {
                    $func_count += $cnt;
                    last;
                }
            }
            $cur->finish();

            #$dbh->disconnect();

            return $func_count;
        }

    }

    my $fname = "";
    if ( $func_id =~ /COG/i ) {
        $fname = 'cog_count.txt';
    } elsif ( $func_id =~ /pfam/i ) {
        $fname = 'pfam_count.txt';
    } elsif ( $func_id =~ /TIGR/i ) {
        $fname = 'tigr_count.txt';
    } elsif ( $func_id =~ /EC\:/i ) {
        $fname = 'ec_count.txt';
    } elsif ( $func_id =~ /KO\:/i ) {
        $fname = 'ko_count.txt';
    }

    if ( !$fname ) {
        return 0;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname;
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }

            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );
                if ( $id eq $func_id ) {
                    $func_count += $cnt;
                    last;
                }
            }    # end while line
            close $fh;
        }
    }    # end for t2

    return $func_count;
}

############################################################################
# getTaxonFuncsCnt: get function count
############################################################################
sub getTaxonFuncsCnt {
    my ( $taxon_oid, $data_type, $func_ids_ref ) = @_;

    my %funcs;
    my $func_id = @$func_ids_ref[0];

    if ($new_func_count) {
        my $f_table_name;
        if ( $func_id =~ /COG/i ) {
            $f_table_name = 'taxon_cog_count';
        } elsif ( $func_id =~ /pfam/i ) {
            $f_table_name = 'taxon_pfam_count';
        } elsif ( $func_id =~ /TIGR/i ) {
            $f_table_name = 'taxon_tigr_count';
        } elsif ( $func_id =~ /EC\:/i ) {
            $f_table_name = 'taxon_ec_count';
        } elsif ( $func_id =~ /KO\:/i ) {
            $f_table_name = 'taxon_ko_count';
        }

        if ( $f_table_name ) {
            my $dataTypeClause;
            if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
                $dataTypeClause = " and data_type='$data_type' ";
            }

            my $dbh = dbLogin();
            my $func_ids_str = OracleUtil::getFuncIdsInClause( $dbh, @$func_ids_ref ); 

            my $sql = qq{
                select taxon_oid, data_type, func_id, gene_count 
                from $f_table_name
                where taxon_oid = ?
                and func_id in ($func_ids_str)
                $dataTypeClause
            };

            my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid, $func_id );
            for ( ; ; ) {
                my ( $t2, $d2, $id, $cnt ) = $cur->fetchrow();
                last if !$t2;

                if ( $funcs{$id} ) {
                    $funcs{$id} += $cnt;
                } else {
                    $funcs{$id} = $cnt;
                }
            }
            $cur->finish();

            return %funcs;
        }

    }

    my $fname = "";
    if ( $func_id =~ /COG/i ) {
        $fname = 'cog_count.txt';
    } elsif ( $func_id =~ /pfam/i ) {
        $fname = 'pfam_count.txt';
    } elsif ( $func_id =~ /TIGR/i ) {
        $fname = 'tigr_count.txt';
    } elsif ( $func_id =~ /EC\:/i ) {
        $fname = 'ec_count.txt';
    } elsif ( $func_id =~ /KO\:/i ) {
        $fname = 'ko_count.txt';
    }

    if ( !$fname ) {
        return %funcs;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname;
        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }

            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );
                if ( WebUtil::inArray($id, @$func_ids_ref) ) {
                    if ( $funcs{$id} ) {
                        $funcs{$id} += $cnt;
                    } else {
                        $funcs{$id} = $cnt;
                    }
                }
            }    # end while line
            close $fh;
        }
    }    # end for t2

     return %funcs;
}

############################################################################
# getTaxonFuncCopy
############################################################################
sub getTaxonFuncCopy {
    my ( $taxon_oid, $data_type, $func_type ) = @_;

    my %funcs;
    my $fname;
    my $c_fname;
    if ( $func_type =~ /COG/i ) {
        $fname   = 'cog_count.txt';
        $c_fname = 'cog_copy.txt';
    } elsif ( $func_type =~ /PFAM/i ) {
        $fname   = 'pfam_count.txt';
        $c_fname = 'pfam_copy.txt';
    } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
        $fname   = 'tigr_count.txt';
        $c_fname = 'tigr_copy.txt';
    } elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
        $fname   = 'ec_count.txt';
        $c_fname = 'ec_copy.txt';
    } elsif ( $func_type =~ /KO/i ) {
        $fname   = 'ko_count.txt';
        $c_fname = 'ko_copy.txt';
    } else {
        return %funcs;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $c_fname;
        if ( !( -e $file ) ) {

            # read count file instead
            $file = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname;
        }

        if ( -e $file ) {
            my $fh = newReadFileHandle($file);
            if ( !$fh ) {
                next;
            }

            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id, $cnt ) = split( /\t/, $line );
                if ( $funcs{$id} ) {
                    $funcs{$id} += $cnt;
                } else {
                    $funcs{$id} = $cnt;
                }
            }    # end while line
            close $fh;
        }
    }    # end for t2

    return %funcs;
}

############################################################################
# getTaxonFuncGenes
# try to use $limiting_genes_href to improve performance
############################################################################
sub getTaxonFuncGenes {
    my ( $taxon_oid, $data_type, $func_id, $limiting_genes_href ) = @_;

    my %genes;
    my $fname     = "";
    my $func_type = "";
    if ( $func_id =~ /COG/i ) {
        $func_id   = sanitizeGeneId3($func_id);
        $fname     = 'cog_genes';
        $func_type = "cog";
    } elsif ( $func_id =~ /pfam/i ) {
        $func_id   = sanitizeGeneId3($func_id);
        $fname     = 'pfam_genes';
        $func_type = "pfam";
    } elsif ( $func_id =~ /TIGR/i ) {
        $func_id   = sanitizeGeneId3($func_id);
        $fname     = 'tigr_genes';
        $func_type = "tigr";
    } elsif ( $func_id =~ /EC\:/i ) {
        my ( $i1, $i2 ) = split( /\:/, $func_id );
        $func_id   = "EC:" . sanitizeEcId2($i2);
        $fname     = 'ec_genes';
        $func_type = "ec";
    } elsif ( $func_id =~ /KO\:/i ) {
        my ( $i1, $i2 ) = split( /\:/, $func_id );
        $func_id   = "KO:" . sanitizeGeneId3($i2);
        $fname     = 'ko_genes';
        $func_type = "ko";
    } elsif ( $func_id =~ /BC\:/i && $enable_biocluster ) {
        %genes = getTaxonBcFuncGenes( $taxon_oid, $data_type, $func_id );
    }

    if ( !$fname ) {
        return %genes;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @type_list = getDataTypeList($data_type);
    foreach my $t2 (@type_list) {

        # check sqlite
        my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname . ".sdb";
        #print "getTaxonFuncGenes() file_name=$file_name<br/>\n";
        my $func_attr = $func_type;
        if ( -e $file_name ) {
            my $dbh2 = WebUtil::sdbLogin($file_name) or return %genes;

            my $func_attr_gene_table = $func_attr . "_genes";
            my $sql2 = qq{
                select $func_attr, genes 
                from $func_attr_gene_table 
                where $func_attr = ?
            };
            #print "getTaxonFuncGenes() sql2=$sql2 func_id=$func_id<br/>\n";
            my $sth  = $dbh2->prepare($sql2);
            $sth->execute($func_id);

            my ( $id2, $genes ) = $sth->fetchrow_array();
            $sth->finish();
            $dbh2->disconnect();

            if ( $id2 && $genes ) {
                my @gene_list = split( /\t/, $genes );
                for my $gene_oid (@gene_list) {
                    my $workspace_id = "$taxon_oid $t2 $gene_oid";
                    $genes{$gene_oid} = $workspace_id;
                }
            }
            next;
        }

        # check db
        $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname . ".db";
        if ( -e $file_name ) {
            my %h;
            tie %h, "BerkeleyDB::Hash",
              -Filename => $file_name,
              -Flags    => DB_RDONLY,
              -Property => DB_DUP;

            if ( tied(%h) ) {
                if ( $h{$func_id} ) {
                    my @gene_list = split( /\t/, $h{$func_id} );
                    for my $gene_oid (@gene_list) {
                        my $workspace_id = "$taxon_oid $t2 $gene_oid";
                        $genes{$gene_oid} = $workspace_id;
                    }
                }

                untie %h;
                next;
            }
        }

        WebUtil::unsetEnvPath();

        # else, use zip
        $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname . ".zip";
        if ( -e $file_name ) {
            my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name $func_id ", 'FuncGenes' );
            if ( !$fh ) {
                next;
            }

            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id2, $gene_oid ) = split( /\t/, $line );
                if ( !$gene_oid ) {
                    $gene_oid = $id2;
                }
                my $workspace_id = "$taxon_oid $t2 $gene_oid";
                $genes{$gene_oid} = $workspace_id;
            }    # end while line

            close $fh;
        }
        WebUtil::resetEnvPath();
    }    # end for t2

    return %genes;
}

############################################################################
# getTaxonGeneEstCopy
############################################################################
sub getTaxonGeneEstCopy {
    my ( $taxon_oid, $data_type, $gene_copies_h ) = @_;

    my $count = 0;

    if ( $data_type eq 'both' || blankStr($data_type) ) {
        $data_type = 'assembled';
    }
    if ( $data_type ne 'assembled' ) {
        return;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    # check for DB first
    my $db_file_name = $mer_data_dir . "/" . $taxon_oid . "/assembled/gene_copy.db";
    if ( -e $db_file_name ) {
        tie %$gene_copies_h, "BerkeleyDB::Hash",
          -Filename => $db_file_name,
          -Flags    => DB_RDONLY,
          -Property => DB_DUP;

        if ( tied(%$gene_copies_h) ) {
            return;
        }
    }

    # check sqlite
    $db_file_name = $mer_data_dir . "/" . $taxon_oid . "/assembled/gene_copy.sdb";

    if ( -e $db_file_name ) {
        my $dbh2 = WebUtil::sdbLogin($db_file_name)
          or return;

        my $sql2 = "select gene_oid, gene_copy from gene_copy ";
        my $sth  = $dbh2->prepare($sql2);
        $sth->execute();

        my ( $id2, $g_copy );
        while ( ( $id2, $g_copy ) = $sth->fetchrow_array() ) {
            if ( !$id2 ) {
                last;
            }

            if ( !$g_copy ) {
                $g_copy = 1;
            }
            $gene_copies_h->{$id2} = $g_copy;
        }
        $sth->finish();
        $dbh2->disconnect();

        return;
    }

    # get data from zip
    WebUtil::unsetEnvPath();

    my $zip_name = $mer_data_dir . "/" . $taxon_oid . "/assembled/gene_copy.zip";
    if ( !( -e $zip_name ) ) {
        return;
    }

    my $zip = Archive::Zip->new();
    $zip->read($zip_name);
    my @members = $zip->members();
    for my $m (@members) {
        my @lines = split( /\n/, $m->contents() );
        for my $line (@lines) {
            chomp($line);
            my ( $gid, $n ) = split( /\t/, $line );
            if ( $n > 1 ) {
                $gene_copies_h->{$gid} = $n;
            }
        }
    }

    WebUtil::resetEnvPath();
}

############################################################################
# getTaxonFuncGeneEstCopy
############################################################################
sub getTaxonFuncGeneEstCopy {
    my ( $taxon_oid, $data_type, $func_id, $gene_copies_h ) = @_;

    my $count = 0;
    my %genes;

    my $fname     = "";
    my $func_attr = "";
    if ( $func_id =~ /COG/i ) {
        $func_id   = sanitizeGeneId3($func_id);
        $fname     = 'cog_genes';
        $func_attr = "cog";
    } elsif ( $func_id =~ /pfam/i ) {
        $func_id   = sanitizeGeneId3($func_id);
        $fname     = 'pfam_genes';
        $func_attr = "pfam";
    } elsif ( $func_id =~ /TIGR/i ) {
        $func_id   = sanitizeGeneId3($func_id);
        $fname     = 'tigr_genes';
        $func_attr = "tigr";
    } elsif ( $func_id =~ /EC\:/i ) {
        my ( $i1, $i2 ) = split( /\:/, $func_id );
        $func_id   = "EC:" . sanitizeEcId2($i2);
        $fname     = 'ec_genes';
        $func_attr = "ec";
    } elsif ( $func_id =~ /KO\:/i ) {
        my ( $i1, $i2 ) = split( /\:/, $func_id );
        $func_id   = "KO:" . sanitizeGeneId3($i2);
        $fname     = 'ko_genes';
        $func_attr = "ko";
    }
    if ( !$fname ) {
        return $count;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    WebUtil::unsetEnvPath();

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {

        # check db first
        my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname . ".db";
        if ( -e $file_name ) {
            my %h;
            tie %h, "BerkeleyDB::Hash",
              -Filename => $file_name,
              -Flags    => DB_RDONLY,
              -Property => DB_DUP;

            if ( tied(%h) ) {
                if ( $h{$func_id} ) {
                    my @gene_list = split( /\t/, $h{$func_id} );
                    for my $gene_oid (@gene_list) {
                        if ( $genes{$gene_oid} ) {

                            # already counted
                        } else {
                            my $gene_est_copy = 1;
                            if ( $gene_copies_h->{$gene_oid} ) {
                                $gene_est_copy = $gene_copies_h->{$gene_oid};
                            }
                            $count += $gene_est_copy;
                            $genes{$gene_oid} = 1;
                        }
                    }
                }

                untie %h;
                next;
            }
        }

        # next, check sqlite
        $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname . ".sdb";
        if ( -e $file_name ) {
            my $dbh2 = WebUtil::sdbLogin($file_name) or return $count;

            my $sql2 = "select $func_attr, genes from " . $func_attr . "_genes " . " where $func_attr = '" . $func_id . "' ";
            my $sth  = $dbh2->prepare($sql2);
            $sth->execute();

            my ( $id2, $genes ) = $sth->fetchrow_array();
            $sth->finish();
            $dbh2->disconnect();

            if ( $id2 && $genes ) {
                my @gene_list = split( /\t/, $genes );
                for my $gene_oid (@gene_list) {
                    if ( $genes{$gene_oid} ) {

                        # already counted
                    } else {
                        my $gene_est_copy = 1;
                        if ( $gene_copies_h->{$gene_oid} ) {
                            $gene_est_copy = $gene_copies_h->{$gene_oid};
                        }
                        $count += $gene_est_copy;
                        $genes{$gene_oid} = 1;
                    }
                }
            }
            next;
        }

        # check zip
        $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $fname . ".zip";
        if ( -e $file_name ) {
            my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name $func_id ", 'FuncGenes' );
            if ( !$fh ) {
                next;
            }

            while ( my $line = $fh->getline() ) {
                chomp $line;
                my ( $id2, $gene_oid ) = split( /\t/, $line );
                if ( !$gene_oid ) {
                    $gene_oid = $id2;
                }

                if ( $genes{$gene_oid} ) {

                    # already counted
                } else {
                    my $gene_est_copy = 1;
                    if ( $gene_copies_h->{$gene_oid} ) {
                        $gene_est_copy = $gene_copies_h->{$gene_oid};
                    }
                    $count += $gene_est_copy;
                    $genes{$gene_oid} = 1;
                }
            }    # end while line
            close $fh;
        }
    }    # end for t2

    WebUtil::resetEnvPath();

    return $count;
}

############################################################################
# getTaxonFuncGeneCopy
############################################################################
sub getTaxonFuncGeneCopy {
    my ( $taxon_oid, $func_id, $gene_list, $gene_copies_h ) = @_;

    my $count = 0;
    my %genes;

    $taxon_oid = sanitizeInt($taxon_oid);

    my @gene_array = split( /\t/, $gene_list );
    for my $gene_oid (@gene_array) {
        if ( $genes{$gene_oid} ) {

            # already counted
        } else {
            my $gene_est_copy = 1;
            if ( $gene_copies_h->{$gene_oid} ) {
                $gene_est_copy = $gene_copies_h->{$gene_oid};
            }
            $count += $gene_est_copy;
            $genes{$gene_oid} = 1;
        }
    }

    return $count;
}

############################################################################
# getTaxonBcFuncGenes
############################################################################
sub getTaxonBcFuncGenes {
    my ( $taxon_oid, $data_type, $func_id ) = @_;

    my %genes;
    if ( $data_type ne 'unassembled' ) {
        $data_type = 'assembled';

        if ( $func_id =~ /BC\:/i ) {
            my ( $i1, $i2 ) = split( /\:/, $func_id );
            $func_id = $i2;
        }
        my $idClause    = " and g.cluster_id = ? ";
        my @bindList_id = ($func_id);

        my $taxonClause  = " and g.taxon = ? ";
        my @bindList_txs = ($taxon_oid);
        my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
        my ( $sql, @bindList ) =
          getBcGeneListSql_merfs( $idClause, $taxonClause, $rclause, $imgClause, \@bindList_id, \@bindList_txs,
            \@bindList_ur );

        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose, @bindList );

        for ( ; ; ) {
            my ( $g_oid, $taxon ) = $cur->fetchrow();
            last if !$g_oid;
            my $workspace_id = "$taxon $data_type $g_oid";
            $genes{$g_oid} = $workspace_id;
        }
        $cur->finish();

    }

    return (%genes);
}

############################################################################
# getMetaTaxonsBcFuncGenes
############################################################################
sub getMetaTaxonsBcFuncGenes {
    my ( $dbh, $metaOids_ref, $data_type, $func_ids_ref ) = @_;

    if ( $data_type eq 'unassembled' ) {
        webError("Biosynthetic Cluster does not support $data_type.");
    }
    $data_type = 'assembled';

    my %workspaceIds_h;
    if ( scalar(@$func_ids_ref) > 0 ) {
        my @func_ids = ();
        for my $func_id (@$func_ids_ref) {
            if ( $func_id =~ /BC\:/i ) {
                my ( $i1, $i2 ) = split( /\:/, $func_id );
                $func_id = $i2;
            }
            push( @func_ids, $func_id );
        }

        my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @func_ids );
        my $idClause = " and g.cluster_id in ($ids_str) ";
        my @bindList_id;

        my ( $taxonClause, @bindList_txs );
        if ( $metaOids_ref && scalar(@$metaOids_ref) > 0 ) {
            ( $taxonClause, @bindList_txs ) = OracleUtil::getTaxonSelectionClauseBind( $dbh, "g.taxon", \@$metaOids_ref );
        } 
        my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
        my ( $sql, @bindList ) =
          getBcGeneListSql_merfs( $idClause, $taxonClause, $rclause, $imgClause, \@bindList_id, \@bindList_txs,
            \@bindList_ur );
        my $cur = execSql( $dbh, $sql, $verbose, @bindList );

        for ( ; ; ) {
            my ( $g_oid, $taxon ) = $cur->fetchrow();
            last if !$g_oid;
            my $workspaceId = "$taxon $data_type $g_oid";
            $workspaceIds_h{$workspaceId} = 1;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
          if ( $taxonClause =~ /gtt_num_id/i );

        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $idClause =~ /gtt_func_id/i );
    }

    return (%workspaceIds_h);
}

sub getBcGeneListSql_merfs {
    my ( $idClause, $taxonClause, $rclause, $imgClause, $bindList_id_ref, $bindList_txs_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct bcg.feature_id, g.taxon
        from bio_cluster_features_new bcg, bio_cluster_new g, taxon t
        where bcg.cluster_id = g.cluster_id
        and g.taxon = t.taxon_oid
        and t.in_file = 'Yes'
        $idClause
        $taxonClause
        $rclause
        $imgClause
    };

    my @bindList = ();
    processBindList( \@bindList, $bindList_id_ref, $bindList_txs_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}


############################################################################
# getTaxonRnaGenes
############################################################################
sub getTaxonRnaGenes {
    my ( $taxon_oid, $data_type, $rna_type_name ) = @_;

    my %genes;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'assembled';
    if ( $data_type eq 'unassembled' ) {
        $t2 = 'unassembled';
    }

    my $file_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/" . $rna_type_name;
    my $sdb_name = $file_name . ".sdb";
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        #print "MetaUtil::getTaxonRnaGenes() data_type=$data_type $t2=$t2 sdb_name=$sdb_name<br/>\n";
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = qq{
            select gene_oid, locus_type, locus_tag, product_name, 
                start_coord, end_coord, strand, scaffold_oid
            from gene 
        };
        my $sth = $dbh3->prepare($sql3);
        $sth->execute();
        for ( ; ; ) {
            my ( $id3, @rest ) = $sth->fetchrow_array();
            last if !$id3;

            my $workspace_id = "$taxon_oid $t2 $id3";
            my $line = $id3 . "\t" . join( "\t", @rest );
            $genes{$workspace_id} = $line;
        }
        $sth->finish();
        $dbh3->disconnect();
        return %genes;
    }

    my $zip_name = $file_name . ".zip";
    if ( !( -e $zip_name ) ) {
        return %genes;
    }
    #print "MetaUtil::getTaxonRnaGenes() zip_name=$zip_name<br/>\n";

    WebUtil::unsetEnvPath();

    my $zip = Archive::Zip->new();
    $zip->read($zip_name);

    my @members = $zip->members();
    for my $m (@members) {
        my $line = $m->contents();
        chomp($line);

        my ( $gene_oid, $locus_type, $locus_tag, $gene_symbol, $start_coord, $end_coord, $strand,
            $scf_ext_accession )
          = split( /\t/, $line );

        my $workspace_id = "$taxon_oid $t2 $gene_oid";
        $genes{$workspace_id} = $line;
    }

    WebUtil::resetEnvPath();

    return %genes;
}


############################################################################
# getScaffoldBcFuncId2Genes
############################################################################
sub getScaffoldBcFuncGenes {
    my ( $taxon_oid, $data_type, $scaffold_oid, $func_id ) = @_;

    my %genes_h;
    if ( $data_type ne 'unassembled' ) {
        $data_type = 'assembled';

        if ( $func_id =~ /BC\:/i ) {
            my ( $i1, $i2 ) = split( /\:/, $func_id );
            $func_id = $i2;
        }
        my $idClasue    = " and g.cluster_id = ? ";
        my @bindList_id = ($func_id);

        my @bindList_txs;
        my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
        my ( $sql, @bindList ) =
          getScaffoldBcFuncGeneSql_merfs( $scaffold_oid, $idClasue, $rclause, $imgClause, \@bindList_id, \@bindList_ur );

        my $dbh = dbLogin();
        my $cur = execSql( $dbh, $sql, $verbose, @bindList );

        for ( ; ; ) {
            my ($g_oid) = $cur->fetchrow();
            last if !$g_oid;
            $genes_h{$g_oid} = 1;
        }
        $cur->finish();

    }

    return (%genes_h);
}

sub getScaffoldBcFuncGeneSql_merfs {
    my ( $scaffold_oid, $idClasue, $rclause, $imgClause, $bindList_id_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct bcg.feature_id
        from bio_cluster_features_new bcg, bio_cluster_new g
        where bcg.cluster_id = g.cluster_id
        and g.scaffold = ?
        $idClasue
        $rclause
        $imgClause
    };

    my @bindList_sql = ($scaffold_oid);
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_id_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

############################################################################
# getScaffoldBcFuncId2Genes
############################################################################
sub getScaffoldBcFuncId2Genes {
    my ( $taxon_oid, $data_type, $scaffold_oid, $func_ids_ref ) = @_;

    my %bcId2genes;
    if ( $data_type ne 'unassembled' ) {
        $data_type = 'assembled';

        my $dbh = dbLogin();

        my $idClause;
        if ( scalar(@$func_ids_ref) > 0 ) {
            my @func_ids = ();
            for my $func_id (@$func_ids_ref) {
                if ( $func_id =~ /BC\:/i ) {
                    my ( $i1, $i2 ) = split( /\:/, $func_id );
                    $func_id = $i2;
                }
                push( @func_ids, $func_id );
            }
            if ( scalar(@func_ids) > 0 ) {
                my $ids_str = OracleUtil::getFuncIdsInClause( $dbh, @func_ids );
                $idClause = " and g.cluster_id in ($ids_str) ";
            }
        }
        my @bindList_id;

        my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
        my ( $sql, @bindList ) =
          getScaffoldBcFuncId2GeneSql_merfs( $scaffold_oid, $idClause, $rclause, $imgClause, \@bindList_id, \@bindList_ur );

        my $cur = execSql( $dbh, $sql, $verbose, @bindList );

        for ( ; ; ) {
            my ( $bc_id, $g_oid ) = $cur->fetchrow();
            last if !$bc_id;

            my $val = $bcId2genes{$bc_id};
            if ($val) {
                $val .= "\t" . $g_oid;
            } else {
                $val = $g_oid;
            }
            $bcId2genes{$bc_id} = $val;
        }
        $cur->finish();

        OracleUtil::truncTable( $dbh, "gtt_func_id" )
          if ( $idClause =~ /gtt_func_id/i );

    }

    return (%bcId2genes);
}

sub getScaffoldBcFuncId2GeneSql_merfs {
    my ( $scaffold_oid, $idClasue, $rclause, $imgClause, $bindList_id_ref, $bindList_ur_ref ) = @_;

    my $sql = qq{
        select distinct bcg.cluster_id, bcg.feature_id
        from bio_cluster_features_new bcg, bio_cluster_new g
        where bcg.cluster_id = g.cluster_id
        and g.scaffold = ?
        $idClasue
        $rclause
        $imgClause
    };

    my @bindList_sql = ($scaffold_oid);
    my @bindList     = ();
    processBindList( \@bindList, \@bindList_sql, $bindList_id_ref, $bindList_ur_ref );

    return ( $sql, @bindList );
}

############################################################################
# getScaffoldStats - stats for specified scaffold
############################################################################
sub getScaffoldStats {
    my ( $taxon_oid, $data_type, $scaffold_oid ) = @_;

    my $gc      = 0;
    my $len     = 0;
    my $n_genes = 0;
    my $t2      = 'assembled';
    if ( $data_type eq 'unassembled' ) {
        $t2 = 'unassembled';
    }
    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/$t2/taxon_hash.txt";
    my $code = HashUtil::get_hash_code( $hash_file, "scaffold_stats", $scaffold_oid );
    $code = sanitizeGeneId3($code);

    $taxon_oid = sanitizeInt($taxon_oid);
    my $sdb_name = $mer_data_dir . "/$taxon_oid" . "/$t2/scaffold_stats.sdb";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = qq{
            select scaffold_oid, length, gc, n_genes 
            from scaffold_stats 
            where scaffold_oid = ?
        };
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute($scaffold_oid);
        my ( $id3, $len, $gc, $n_genes ) = $sth->fetchrow_array();
        $sth->finish();
        $dbh3->disconnect();
        return ( $len, $gc, $n_genes );
    }

    my $zip_name = $mer_data_dir . "/$taxon_oid" . "/$t2/scaffold_stats/scaffold_stats";
    if ($code) {
        $zip_name .= "_" . $code;
    }
    $zip_name .= ".zip";

    if ( !( -e $zip_name ) ) {
        return ( $len, $gc, $n_genes );
    }

    WebUtil::unsetEnvPath();

    my $i2 = $scaffold_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    #webLog("unzip -p $zip_name $i2\n");

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", "scaffoldGc" );
    my $line = $fh->getline();
    chomp($line);

    my $id4 = "";
    ( $id4, $len, $gc, $n_genes ) = split( /\t/, $line );
    close $fh;

    WebUtil::resetEnvPath();

    return ( $len, $gc, $n_genes );
}

############################################################################
# getScaffoldStatsInLenRange - stats for specified scaffolds in length range
############################################################################
sub getScaffoldStatsInLengthRange {
    my ( $taxon_oid, $data_type, $lower, $upper, $maxResults ) = @_;

    my $trunc = 0;
    my @lines = ();
    my @scafs = ();

    $taxon_oid = sanitizeInt($taxon_oid);
    my $sdb_name = $mer_data_dir . "/$taxon_oid/$data_type/scaffold_stats.sdb";
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name) or return "";

        my $sql3 = "select scaffold_oid, length, gc, n_genes from scaffold_stats " . "where length between ? and ?";
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute( $lower, $upper );

        my $cnt = 0;
        for ( ; ; ) {
            my ( $id3, $len, $gc, $n_genes ) = $sth->fetchrow_array();
            last if !$id3;

            my $line = "$id3\t$len\t$gc\t$n_genes";
            push( @lines, $line );
            push( @scafs, $id3 );

            if ( $maxResults ne '' && $maxResults > 0 ) {
                $cnt++;
                if ( $cnt > $maxResults ) {
                    $trunc = 1;
                    last;
                }
            }
        }
        $sth->finish();
        $dbh3->disconnect();
    }

    return ( $trunc, \@lines, \@scafs );
}

############################################################################
# getScaffoldStatsWithFixedGeneCnt - stats for specified scaffolds
# with certain number of gene count
############################################################################
sub getScaffoldStatsWithFixedGeneCnt {
    my ( $taxon_oid, $data_type, $gene_count, $maxResults ) = @_;

    my $trunc = 0;
    my @lines = ();
    my @scafs = ();

    $taxon_oid = sanitizeInt($taxon_oid);
    my $i2 = sanitizeInt($gene_count);

    my $sdb_name = $mer_data_dir . "/$taxon_oid/$data_type/scaffold_stats.sdb";
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name) or return "";

        my $sql3 = "select scaffold_oid, length, gc, n_genes from scaffold_stats " . "where n_genes = ?";
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute($i2);

        my $cnt = 0;
        for ( ; ; ) {
            my ( $id3, $len, $gc, $n_genes ) = $sth->fetchrow_array();
            last if !$id3;

            my $line = "$id3\t$len\t$gc\t$n_genes";
            push( @lines, $line );
            push( @scafs, $id3 );

            if ( $maxResults ne '' && $maxResults > 0 ) {
                $cnt++;
                if ( $cnt > $maxResults ) {
                    $trunc = 1;
                    last;
                }
            }
        }
        $sth->finish();
        $dbh3->disconnect();
    }

    return ( $trunc, \@lines, \@scafs );
}

############################################################################
# getScaffoldStatsForTaxon - all scaffold stats for taxon
############################################################################
sub getScaffoldStatsForTaxon {
    my ( $taxon_oid, $data_type, $sqlSuffix, $maxResults ) = @_;

    my $trunc = 0;
    my @lines = ();

    $taxon_oid = sanitizeInt($taxon_oid);
    my $sdb_name = $mer_data_dir . "/$taxon_oid/$data_type/scaffold_stats.sdb";
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name) or return "";

        my $sql3 = "select scaffold_oid, length, gc, n_genes from scaffold_stats ";
        if ( $sqlSuffix ne '' ) {
            $sql3 .= $sqlSuffix;
        }
        my $sth = $dbh3->prepare($sql3);
        $sth->execute();

        my $cnt = 0;
        for ( ; ; ) {
            my ( $id3, $len, $gc, $n_genes ) = $sth->fetchrow_array();
            last if !$id3;

            my $line = "$id3\t$len\t$gc\t$n_genes";
            push( @lines, $line );

            if ( $maxResults ne '' && $maxResults > 0 ) {
                $cnt++;
                if ( $cnt > $maxResults ) {
                    $trunc = 1;
                    last;
                }
            }
        }
        $sth->finish();
        $dbh3->disconnect();
    }

    return ( $trunc, @lines );
}

############################################################################
# getScaffoldStatsForTaxonScaffolds2 - stats for selected scaffolds
#        returns a hash of stats for each scaffold
############################################################################
sub getScaffoldStatsForTaxonScaffolds2 {
    my ( $taxon_oid, $data_type, $scaffolds_ref ) = @_;

    $taxon_oid = sanitizeInt($taxon_oid);

    my $t2 = 'assembled';
    if ( $data_type eq 'unassembled' ) {
        $t2 = 'unassembled';
    }

    my @ids = @$scaffolds_ref;
    my %stats;

    my $sdb_name = $mer_data_dir . "/$taxon_oid" . "/$t2/scaffold_stats.sdb";
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = "select scaffold_oid, length, gc, n_genes from scaffold_stats " . "where scaffold_oid = ?";
        my $sth  = $dbh3->prepare($sql3);
        for my $scaf_id (@ids) {
            $sth->execute($scaf_id);
            my ( $id3, $len, $gc, $n_genes ) = $sth->fetchrow_array();
            $sth->finish();
            my $line = "$id3\t$len\t$gc\t$n_genes";
            $stats{$scaf_id} = $line;
        }
        $dbh3->disconnect();
        return \%stats;
    }

    my $hash_file = $mer_data_dir . "/$taxon_oid/$t2/taxon_hash.txt";

    my %code2ids;
    foreach my $id (@ids) {
        my $code = HashUtil::get_hash_code( $hash_file, "scaffold_stats", $id );
        $code2ids{$code} .= $id . " ";
    }

    WebUtil::unsetEnvPath();

    foreach my $code ( keys %code2ids ) {
        $code = sanitizeGeneId3($code);

        my $zip_name = $mer_data_dir . "/$taxon_oid" . "/$t2/scaffold_stats/scaffold_stats";
        if ($code) {
            $zip_name .= "_" . $code;
        }
        $zip_name .= ".zip";

        next if ( !( -e $zip_name ) );

        my $ids_str = $code2ids{$code};
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );

        my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $ids_str ", "statsForScaffolds" );
        while ( my $line = $fh->getline() ) {
            chomp($line);

            # $scaffold_oid, $len, $gc, $gene_cnt
            my ( $scaffold_oid, @rest ) = split( /\t/, $line );
            $stats{$scaffold_oid} = $line;
        }
        close $fh;
    }

    WebUtil::resetEnvPath();

    return \%stats;
}

############################################################################
# getScaffoldGc
############################################################################
sub getScaffoldGc {
    my ( $taxon_oid, $data_type, $scaffold_oid ) = @_;

    my ( $len, $gc, $n_genes ) = getScaffoldStats( $taxon_oid, $data_type, $scaffold_oid );
    return $gc;
}

############################################################################
# getScaffoldCoord
############################################################################
sub getScaffoldCoord {
    my ( $taxon_oid, $data_type, $scaffold_oid ) = @_;

    my $start_coord = 0;
    my $end_coord   = 0;
    my $strand      = '+';

    my ( $len, $gc, $n_genes ) = getScaffoldStats( $taxon_oid, $data_type, $scaffold_oid );
    if ($len) {
        $start_coord = 1;
        $end_coord   = $len;
    }

    return ( $start_coord, $end_coord, $strand );
}

############################################################################
# getScaffoldGenes
############################################################################
sub getScaffoldGenes {

    #scaffold_oid: not full workspace id
    my ( $taxon_oid, $data_type, $scaffold_oid ) = @_;

    my @genes_on_s = ();

    # read scaffold info from file
    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'assembled';
    if ( $data_type eq 'unassembled' ) {
        $t2 = 'unassembled';
    }
    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/$t2/taxon_hash.txt";
    my $code = HashUtil::get_hash_code( $hash_file, "scaffold_genes", $scaffold_oid );
    $code = sanitizeGeneId3($code);

    my $file_name = $mer_data_dir . "/$taxon_oid" . "/$t2/scaffold_genes";
    if ($code) {
        $file_name .= "/scaffold_genes_" . $code;
    }
    my $sdb_name = $file_name . ".sdb";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = qq{
            select gene_oid, locus_type, locus_tag, product_name, 
                start_coord, end_coord, strand, scaffold_oid 
            from scaffold_genes 
            where scaffold_oid = ?
        };
        my $sth = $dbh3->prepare($sql3);
        $sth->execute($scaffold_oid);
        for ( ; ; ) {
            my ( $id3, @rest ) = $sth->fetchrow_array();
            last if !$id3;

            my $line = $id3 . "\t" . join( "\t", @rest );
            push( @genes_on_s, $line );
        }
        $sth->finish();
        $dbh3->disconnect();
        return @genes_on_s;
    }

    my $zip_name = $file_name . ".zip";
    if ( !( -e $zip_name ) ) {
        return @genes_on_s;
    }

    #print "MetaUtil::getScaffoldGenes zip file: $zip_name<br/>\n";

    WebUtil::unsetEnvPath();

    my $i2 = $scaffold_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'scaffold' );
    my $line = "";
    while ( $line = $fh->getline() ) {
        chomp($line);
        push( @genes_on_s, $line );
    }
    close $fh;

    WebUtil::resetEnvPath();

    return @genes_on_s;
}

sub getScaffoldGenesForTaxonScaffolds {
    my ( $taxon_oid, $data_type, $oids_ref, $print_msg ) = @_;

    my %scafOid2scafGenes;
    if ( $oids_ref ne '' && scalar(@$oids_ref) > 0 ) {
        my $hasScaffoldGenesSqliteFile = hasSdbScaffoldGenesFile( $taxon_oid, $data_type );
        if ($hasScaffoldGenesSqliteFile) {
            if ($print_msg) {
                print "<p>Retrieving scaffold genes for genome $taxon_oid $data_type ...<br/>\n";
            }

            my %scafGenesFile_scafs = getOrganizedTaxonScaffoldGenesFiles( $taxon_oid, $data_type, @$oids_ref );
            for my $scafGenesFile ( keys %scafGenesFile_scafs ) {
                my $file_oids_ref = $scafGenesFile_scafs{$scafGenesFile};
                my $cnt0          = scalar(@$file_oids_ref);
                if ( $cnt0 == 0 ) {
                    next;
                }

                my $cnt1         = 0;
                my $file_oid_str = '';
                for my $file_oid (@$file_oids_ref) {
                    if ($file_oid_str) {
                        $file_oid_str .= ", '" . $file_oid . "'";
                    } else {
                        $file_oid_str = "'" . $file_oid . "'";
                    }
                    $cnt1++;
                    if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                        my $sql = qq{
                            select gene_oid, locus_type, locus_tag, product_name, 
                                start_coord, end_coord, strand, scaffold_oid 
                            from scaffold_genes 
                            where scaffold_oid in ($file_oid_str)
                        };
                        my (%scafGenes) =
                          fetchScaffoldGenesForTaxonFromSqlite( $taxon_oid, $data_type, $scafGenesFile, $sql );
                        if ( scalar( keys %scafGenes ) > 0 ) {
                            foreach my $s_oid ( keys %scafGenes ) {
                                my $workspace_id = "$taxon_oid $data_type $s_oid";
                                $scafOid2scafGenes{$workspace_id} = $scafGenes{$s_oid};
                            }
                        }
                        $file_oid_str = '';
                    }
                }
            }

        } else {
            if ($print_msg) {
                print
                  "<p>No sqlite DNA file, retrieving scaffold genes from zip file for genome $taxon_oid $data_type<br/>\n";
            }
            webLog(
"MetaUtil::getScaffoldGenesForTaxonScaffolds() no sqlite scaffold genes file for genome $taxon_oid $data_type\n"
            );

            my $tag = "scaffold_genes";
            doFlieReading( $print_msg, 1, $taxon_oid, $data_type, $oids_ref, $tag, \%scafOid2scafGenes );
        }
    }

    return %scafOid2scafGenes;
}

############################################################################
# getScaffoldFna
############################################################################
sub getScaffoldFna {
    my ( $taxon_oid, $data_type, $scaffold_oid ) = @_;

    # read gene fna info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
    my $code      = HashUtil::get_hash_code( $hash_file, "fna", $scaffold_oid );

    my $fna_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/fna";
    if ($code) {
        $code = sanitizeGeneId3($code);
        $fna_name .= "/fna_" . $code;
    }
    my $sdb_name = $fna_name . ".sdb";

    #webLog("sdb ==== $sdb_name\n");
    #webLog("config ==== $scaffold_oid\n");

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = "select scaffold_oid, fna from scaffold_fna where scaffold_oid = ?";

        #        webLog("$sql3\n");

        my $sth = $dbh3->prepare($sql3);
        $sth->execute($scaffold_oid);
        my ( $id3, $seq ) = $sth->fetchrow_array();
        $sth->finish();
        $dbh3->disconnect();
        return $seq;
    }

    my $zip_name = $fna_name . ".zip";

    #webLog("zip ==== $zip_name\n");
    if ( !( -e $zip_name ) ) {
        return "";
    }

    WebUtil::unsetEnvPath();

    my $i2 = $scaffold_oid;
    $i2 =~ s/\:/\_/g;
    $i2 =~ s/\//\_/g;
    $i2 = sanitizeGeneId3($i2);

    my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'geneInfo' );

    my $line = $fh->getline();
    chomp($line);
    my $seq = $line;

    close $fh;
    WebUtil::resetEnvPath();

    return $seq;
}

############################################################################
# getScaffoldDepth
############################################################################
sub getScaffoldDepth {
    my ( $taxon_oid, $data_type, $scaffold_oid ) = @_;

    my $scaf_depth = 1;

    if ( $data_type eq 'unassembled' ) {

        # unassembled only have 1 copy
        return $scaf_depth;
    }

    # read scaffold info from file
    $taxon_oid = sanitizeInt($taxon_oid);

    my $sdb_name = $mer_data_dir . "/$taxon_oid/assembled/scaffold_depth.sdb";
    my $singleScaffoldDepthFile = getSingleSdbScaffoldDepthFile( $taxon_oid, $data_type );
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE) {
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = "select scaffold_oid, depth from scaffold_depth where scaffold_oid = ?";
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute($scaffold_oid);
        my ( $id3, $depth ) = $sth->fetchrow_array();
        if ( $depth && isNumber($depth) ) {
            $scaf_depth = floor( $depth + 0.5 );
        }
        $sth->finish();
        $dbh3->disconnect();
        return $scaf_depth;
    }

    my $zip_name = $mer_data_dir . "/$taxon_oid/assembled/scaffold_depth.zip";
    if ( !( -e $zip_name ) ) {

        # check other directory
        $zip_name = $mer_data_dir . "/$taxon_oid" . "/assembled/scaffold_stats/scaffold_depth.zip";

        if ( !( -e $zip_name ) ) {

            # no depth data. assume 1 copy.
            return $scaf_depth;
        }
    }

    if ($scaffold_oid) {

        # only this scaffold
        WebUtil::unsetEnvPath();

        my $i2 = $scaffold_oid;
        $i2 =~ s/\:/\_/g;
        $i2 =~ s/\//\_/g;
        $i2 = sanitizeGeneId3($i2);

        my $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $zip_name $i2 ", 'scaffold' );
        my $line = "";
        if ($fh) {
            $line = $fh->getline();
            chomp($line);
            my ( $n1, $n2 ) = split( /\t/, $line );
            if ( $n2 && isNumber($n2) ) {
                $scaf_depth = floor( $n2 + 0.5 );
            }
        }
        close $fh;

        WebUtil::resetEnvPath();
    }

    if ( !$scaf_depth ) {
        $scaf_depth = 1;
    }

    return $scaf_depth;
}

############################################################################
# getScaffoldLineage
############################################################################
sub getScaffoldLineage {
    my ( $taxon_oid, $data_type, $scaffold_oid ) = @_;

    my ( $lineage, $percentage, $rank );
    if ( $data_type eq 'unassembled' ) {
        return ( $lineage, $percentage, $rank );
    }

    my $singleScaffoldLineageFile = getSingleSdbScaffoldLineageFile( $taxon_oid, $data_type );
    if ($singleScaffoldLineageFile) {

        # use sdb
        my $dbh3 = WebUtil::sdbLogin($singleScaffoldLineageFile)
          or next;
        my $sql3 = "select scaffold_oid, lineage, rank, percentage " 
            . "from contig_lin where scaffold_oid = ? ";
        my $sth  = $dbh3->prepare($sql3);
        $sth->execute($scaffold_oid);
        my ( $scaffold_oid2, $lineage2, $rank2, $percentage2 ) = $sth->fetchrow_array();
        if ( $scaffold_oid2 eq $scaffold_oid ) {
            $lineage    = $lineage2;
            $percentage = $percentage2;
            $rank       = $rank2;
        }
        $sth->finish();
        $dbh3->disconnect();
    }

    return ( $lineage, $percentage, $rank );
}

sub getScaffoldFuncId2GenesInHashes {

    #scaffold_oid: not full workspace id
    my ( $taxon_oid, $data_type, $scaffold_oid, $funcIds_href ) = @_;

    my @func_ids;
    if ($funcIds_href) {
        @func_ids = keys %$funcIds_href;
    }

    my $funcType = '';
    if ( !$funcIds_href || scalar(@func_ids) <= 0 ) {
        $funcType = 'ALL';
    }

    # function types list
    my (
        $go_ids_ref,    $cog_ids_ref,     $kog_ids_ref,   $pfam_ids_ref,    $tigr_ids_ref,
        $ec_ids_ref,    $ko_ids_ref,      $ipr_ids_ref,   $tc_fam_nums_ref, $bc_ids_ref,
        $np_ids_ref,    $metacyc_ids_ref, $iterm_ids_ref, $ipway_ids_ref,   $plist_ids_ref,
        $netwk_ids_ref, $icmpd_ids_ref,   $irexn_ids_ref, $prule_ids_ref,   $unrecognized_ids_ref
      )
      = QueryUtil::groupFuncIds(\@func_ids);

    my %cogId2genes;
    my %pfamId2genes;
    my %tigrfamId2genes;
    my %koId2genes;
    my %ec2genes;

    my @genes_on_s = getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );
    for my $g (@genes_on_s) {
        my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
          split( /\t/, $g );

        #print "MetaUtil::getScaffoldFuncId2GenesHashes() gene_oid: $gene_oid<br/>\n";

        if ( $funcType eq 'ALL' || scalar(@$cog_ids_ref) > 0 ) {
            my @cogIds = getGeneCogId( $gene_oid, $taxon_oid, $data_type );
            for my $cogId (@cogIds) {
                if ( $funcType eq 'ALL' || $funcIds_href->{$cogId} ) {
                    my $val = $cogId2genes{$cogId};
                    if ($val) {
                        $val .= "\t" . $gene_oid;
                    } else {
                        $val = $gene_oid;
                    }
                    $cogId2genes{$cogId} = $val;
                }
            }
        }

        if ( $funcType eq 'ALL' || scalar(@$pfam_ids_ref) > 0 ) {
            my @pfamIds = getGenePfamId( $gene_oid, $taxon_oid, $data_type );
            for my $pfamId (@pfamIds) {
                if ( $funcType eq 'ALL' || $funcIds_href->{$pfamId} ) {
                    my $val = $pfamId2genes{$pfamId};
                    if ($val) {
                        $val .= "\t" . $gene_oid;
                    } else {
                        $val = $gene_oid;
                    }
                    $pfamId2genes{$pfamId} = $val;
                }
            }
        }

        if ( $funcType eq 'ALL' || scalar(@$tigr_ids_ref) > 0 ) {
            my @tigrfamIds = getGeneTIGRfamId( $gene_oid, $taxon_oid, $data_type );
            for my $tigrfamId (@tigrfamIds) {
                if ( $funcType eq 'ALL' || $funcIds_href->{$tigrfamId} ) {
                    my $val = $tigrfamId2genes{$tigrfamId};
                    if ($val) {
                        $val .= "\t" . $gene_oid;
                    } else {
                        $val = $gene_oid;
                    }
                    $tigrfamId2genes{$tigrfamId} = $val;
                }
            }
        }

        if ( $funcType eq 'ALL' || scalar(@$ko_ids_ref) > 0 ) {
            my @koIds = getGeneKoId( $gene_oid, $taxon_oid, $data_type );
            for my $koId (@koIds) {
                if ( $funcType eq 'ALL' || $funcIds_href->{$koId} ) {
                    my $val = $koId2genes{$koId};
                    if ($val) {
                        $val .= "\t" . $gene_oid;
                    } else {
                        $val = $gene_oid;
                    }
                    $koId2genes{$koId} = $val;
                }
            }
        }

        if ( $funcType eq 'ALL' || scalar(@$ec_ids_ref) > 0 ) {
            my @ecs = getGeneEc( $gene_oid, $taxon_oid, $data_type );
            for my $ec (@ecs) {
                if ( $funcType eq 'ALL' || $funcIds_href->{$ec} ) {
                    my $val = $ec2genes{$ec};
                    if ($val) {
                        $val .= "\t" . $gene_oid;
                    } else {
                        $val = $gene_oid;
                    }
                    $ec2genes{$ec} = $val;
                }
            }
        }

    }

    my %bc2genes;
    if ( ( $funcType eq 'ALL' || scalar(@$bc_ids_ref) > 0 ) && $enable_biocluster ) {
        %bc2genes = getScaffoldBcFuncId2Genes( $taxon_oid, $data_type, $scaffold_oid, $bc_ids_ref );
    }

    return ( \%cogId2genes, \%pfamId2genes, \%tigrfamId2genes, \%koId2genes, \%ec2genes, \%bc2genes );
}

sub getScaffoldFuncId2GenesInOneHash {

    #scaffold_oid: not full workspace id
    my ( $taxon_oid, $data_type, $scaffold_oid, $funcIds_ref ) = @_;

    my ( $cogId2genes_ref, $pfamId2genes_ref, $tigrfamId2genes_ref, $koId2genes_ref, $ec2genes_ref, $bc2genes_ref ) =
      getScaffoldFuncId2GenesInHashes( $taxon_oid, $data_type, $scaffold_oid, $funcIds_ref );

    #print "MetaUtil::getScaffoldFuncId2GenesOneHash() cogId2genes size: ".scalar(keys(%$cogId2genes_ref))."<br/>\n";
    #print "MetaUtil::getScaffoldFuncId2GenesOneHash() pfamId2genes size: ".scalar(keys(%$pfamId2genes_ref))."<br/>\n";
    #print "MetaUtil::getScaffoldFuncId2GenesOneHash() tigrfamId2genes size: ".scalar(keys(%$tigrfamId2genes_ref))."<br/>\n";
    #print "MetaUtil::getScaffoldFuncId2GenesOneHash() koId2genes size: ".scalar(keys(%$koId2genes_ref))."<br/>\n";
    #print "MetaUtil::getScaffoldFuncId2GenesOneHash() ec2genes size: ".scalar(keys(%$ec2genes_ref))."<br/>\n";
    #print "MetaUtil::getScaffoldFuncId2GenesOneHash() bc2genes size: ".scalar(keys(%$bc2genes_ref))."<br/>\n";

    #add symbol to ID
    my %bcFunc2genes;
    for my $bc_id ( keys %$bc2genes_ref ) {
        $bcFunc2genes{"BC:$bc_id"} = $bc2genes_ref->{$bc_id};
    }

    #print Dumper(\%bcFunc2genes);
    #print "<br/>\n";

    my %funcId2genes =
      ( %$cogId2genes_ref, %$pfamId2genes_ref, %$tigrfamId2genes_ref, %$koId2genes_ref, %$ec2genes_ref, %bcFunc2genes );

    #print "MetaUtil::getScaffoldFuncId2GenesOneHash() funcId2genes size: ".scalar(keys(%funcId2genes))."<br/>\n";

    return %funcId2genes;
}

sub getScaffoldFuncGenes {

    #scaffold_oid: not full workspace id
    my ( $taxon_oid, $data_type, $scaffold_oid, $func_id ) = @_;

    my $func_id_uc     = uc($func_id);
    my @func_gene_data = ();

    my %genes_h;
    if ( $func_id =~ /BC\:/i && $enable_biocluster ) {
        %genes_h = getScaffoldBcFuncGenes( $taxon_oid, $data_type, $scaffold_oid, $func_id );
    }

    my @genes_on_s = getScaffoldGenes( $taxon_oid, $data_type, $scaffold_oid );
    for my $g (@genes_on_s) {
        my ( $gene_oid, $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord, $strand, $seq_id, $source ) =
          split( /\t/, $g );

        #print "MetaUtil::getScaffoldFuncId2GenesHashes() gene_oid: $gene_oid<br/>\n";

        if ( $func_id =~ /COG/i ) {
            my @cogIds = getGeneCogId( $gene_oid, $taxon_oid, $data_type );
            for my $cogId (@cogIds) {
                if ( uc($cogId) eq $func_id_uc ) {
                    push( @func_gene_data, $g );
                }
            }
        } elsif ( $func_id =~ /pfam/i ) {
            my @pfamIds = getGenePfamId( $gene_oid, $taxon_oid, $data_type );
            for my $pfamId (@pfamIds) {
                if ( uc($pfamId) eq $func_id_uc ) {
                    push( @func_gene_data, $g );
                }
            }
        } elsif ( $func_id =~ /TIGR/i ) {
            my @tigrfamIds = getGeneTIGRfamId( $gene_oid, $taxon_oid, $data_type );
            for my $tigrfamId (@tigrfamIds) {
                if ( uc($tigrfamId) eq $func_id_uc ) {
                    push( @func_gene_data, $g );
                }
            }
        } elsif ( $func_id =~ /KO\:/i ) {
            my @koIds = getGeneKoId( $gene_oid, $taxon_oid, $data_type );
            for my $koId (@koIds) {
                if ( uc($koId) eq $func_id_uc ) {
                    push( @func_gene_data, $g );
                }
            }
        } elsif ( $func_id =~ /EC\:/i ) {
            my @ecs = getGeneEc( $gene_oid, $taxon_oid, $data_type );
            for my $ec (@ecs) {
                if ( uc($ec) eq $func_id_uc ) {
                    push( @func_gene_data, $g );
                }
            }
        }

        #TODO: currently only for bc, apply for others in future
        if ( $genes_h{$gene_oid} ) {
            push( @func_gene_data, $g );
        }
    }

    return (@func_gene_data);
}

############################################################################
## getTaxonFuncMetaGenes -- get all metagenome genes for specified function
##                     and taxon_oid, data_type
## need to be merged with getTaxonFuncGenes or getTaxonFuncsGenes
############################################################################
sub getTaxonFuncMetaGenes {
    my ( $taxon_oid, $data_type, $func_id ) = @_;

    my %gene_h;
    my @genes;

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = "assembled";
    if ( $data_type eq 'unassembled' ) {
        $t2 = "unassembled";
    }

    my $data_type_dir = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
    if ( ! (-e $data_type_dir) ) {
        return @genes;
    }

    my $fname;
    my $file_name;

    my @func_list;
    my $func_attr;
    
    if (   $func_id =~ /COG\_Category/i
        || $func_id =~ /COG\_Pathway/i )
    {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        my $dbh = dbLogin();
        my $sql = "select cf.cog_id from cog_functions cf where cf.functions = ?";
        if ( $func_id =~ /COG\_Pathway/i ) {
            $sql = "select cpcm.cog_members from cog_pathway_cog_members cpcm " . "where cpcm.cog_pathway_oid = ?";
        }
        my $cur = execSql( $dbh, $sql, $verbose, $id2 );
        for ( ; ; ) {
            my ($cog_id) = $cur->fetchrow();
            last if !$cog_id;
            push @func_list, ($cog_id);
        }
        $cur->finish();

        $fname     = "cog_genes";
        $func_attr = "cog";
    } elsif ( $func_id =~ /COG/i ) {

        # COG
        @func_list = ($func_id);
        $fname     = "cog_genes";
        $func_attr = "cog";
    } elsif ( $func_id =~ /Pfam\_Category/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        my $dbh = dbLogin();
        my $sql = "select pfc.ext_accession from pfam_family_cogs pfc " . "where pfc.functions = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $id2 );
        for ( ; ; ) {
            my ($pfam_id) = $cur->fetchrow();
            last if !$pfam_id;
            push @func_list, ($pfam_id);
        }
        $cur->finish();

        $fname     = "pfam_genes";
        $func_attr = "pfam";
    } elsif ( $func_id =~ /pfam/i ) {

        # pfam
        @func_list = ($func_id);
        $fname     = "pfam_genes";
        $func_attr = "pfam";
    } elsif ( $func_id =~ /TIGRfam\_Role/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        my $dbh = dbLogin();
        my $sql = "select tr.ext_accession from tigrfam_roles tr where tr.roles = ?";
        my $cur = execSql( $dbh, $sql, $verbose, $id2 );
        for ( ; ; ) {
            my ($tigr_id) = $cur->fetchrow();
            last if !$tigr_id;
            push @func_list, ($tigr_id);
        }
        $cur->finish();

        $fname     = "tigr_genes";
        $func_attr = "tigr";
    } elsif ( $func_id =~ /TIGR/i ) {

        # tigrfam
        @func_list = ($func_id);
        $fname     = "tigr_genes";
        $func_attr = "tigr";
    } elsif ( $func_id =~ /KEGG\_Category\_KO/i
        || $func_id =~ /KEGG\_Pathway\_KO/i )
    {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        my $dbh = dbLogin();
        if ( $func_id =~ /KEGG\_Category\_KO/i ) {
            my $sql2 = "select category from kegg_pathway where pathway_oid = ?";
            my $cur2 = execSql( $dbh, $sql2, $verbose, $id2 );
            ($id2) = $cur2->fetchrow();
            $cur2->finish();
        }
        my $sql;
        if ( $func_id =~ /KEGG\_Category\_KO/i ) {
            $sql =
                "select distinct rk.ko_terms "
              . "from image_roi_ko_terms rk, image_roi ir, kegg_pathway kp "
              . "where ir.pathway = kp.pathway_oid and rk.roi_id = ir.roi_id "
              . "and kp.category = ?";
        } elsif ( $func_id =~ /KEGG\_Pathway\_KO/i ) {
            $sql =
                "select distinct rk.ko_terms "
              . "from image_roi_ko_terms rk, image_roi ir "
              . "where ir.pathway = ? and rk.roi_id = ir.roi_id";
        }
        my $cur = execSql( $dbh, $sql, $verbose, $id2 );
        for ( ; ; ) {
            my ($ec_id) = $cur->fetchrow();
            last if !$ec_id;
            push @func_list, ($ec_id);
        }
        $cur->finish();

        $fname     = "ko_genes";
        $func_attr = "ko";
    } elsif ( $func_id =~ /KO/i ) {

        # ko
        @func_list = ($func_id);
        $fname     = "ko_genes";
        $func_attr = "ko";
    } elsif ( $func_id =~ /KEGG\_Category\_EC/i
        || $func_id =~ /KEGG\_Pathway\_EC/i )
    {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        my $dbh = dbLogin();
        if ( $func_id =~ /KEGG\_Category\_EC/i ) {
            my $sql2 = "select category from kegg_pathway " . "where pathway_oid = ?";
            my $cur2 = execSql( $dbh, $sql2, $verbose, $id2 );
            ($id2) = $cur2->fetchrow();
            $cur2->finish();
        }
        my $sql = qq{
            select distinct kte.enzymes
            from image_roi ir, image_roi_ko_terms irkt, 
                 ko_term_enzymes kte
            where ir.pathway = ? 
            and irkt.roi_id = ir.roi_id
            and irkt.ko_terms = kte.ko_id
        };
        if ( $func_id =~ /KEGG\_Category\_EC/ ) {
            $sql = qq{
                select distinct kte.enzymes 
                from image_roi_ko_terms irkt, ko_term_enzymes kte,
                     image_roi ir, kegg_pathway kp 
                where ir.pathway = kp.pathway_oid 
                and irkt.roi_id = ir.roi_id 
                and irkt.ko_terms = kte.ko_id
                and kp.category = ?
            };
        }

        my $cur = execSql( $dbh, $sql, $verbose, $id2 );
        for ( ; ; ) {
            my ($ec_id) = $cur->fetchrow();
            last if !$ec_id;
            push @func_list, ($ec_id);
        }
        $cur->finish();

        $fname     = "ec_genes";
        $func_attr = "ec";
    } elsif ( $func_id =~ /EC/i ) {

        # EC
        @func_list = ($func_id);
        $fname     = "ec_genes";
        $func_attr = "ec";
    } elsif ( $func_id =~ /BC/i ) {
        %gene_h = getTaxonBcFuncGenes( $taxon_oid, $t2, $func_id );
        @genes = keys %gene_h;
        return @genes;
    } elsif ( $func_id =~ /MetaCyc/i ) {
        my ( $id1, $id2 ) = split( /\:/, $func_id );
        my @metacyc_ids = ($id2);

        my $dbh = dbLogin();
        my ( $metacyc2ec_href, $ec2metacyc_href ) = QueryUtil::fetchMetaCyc2EcHash( $dbh, \@metacyc_ids );
        my @ec_ids = keys %$ec2metacyc_href;
        push @func_list, (@ec_ids);

        #print "MetaUtil::getTaxonFuncMetaGenes() $func_id @ec_ids<br/>\n";

        $fname     = "ec_genes";
        $func_attr = "ec";
    } else {
        return @genes;
    }

    # check sqlite first
    $file_name = $data_type_dir . "/" . $fname . ".sdb";
    if ( -e $file_name ) {
        my $dbh2 = WebUtil::sdbLogin($file_name)
          or return @genes;

        my $sql2 = "select $func_attr, genes from " . $func_attr . "_genes ";
        $sql2 .= " where $func_attr in ('" . join( "', '", @func_list ) . "') ";

        my $sth = $dbh2->prepare($sql2);
        $sth->execute();

        my ( $id2, $genes );
        while ( ( $id2, $genes ) = $sth->fetchrow_array() ) {
            if ( !$id2 ) {
                last;
            }

            my @gene_list = split( /\t/, $genes );
            for my $gene_oid (@gene_list) {
                $gene_h{$gene_oid} = 1;
            }
        }
        $sth->finish();
        $dbh2->disconnect();

        @genes = ( keys %gene_h );
        return @genes;
    }

    # next, check db
    my $db_file_name = $data_type_dir . "/" . $fname . ".db";
    if ( -e $db_file_name ) {
        my %h;
        tie %h, "BerkeleyDB::Hash",
          -Filename => $db_file_name,
          -Flags    => DB_RDONLY,
          -Property => DB_DUP;

        if ( tied(%h) ) {
            for my $id2 (@func_list) {
                if ( $h{$id2} ) {
                    my @gene_list = split( /\t/, $h{$id2} );
                    for my $gene_oid (@gene_list) {
                        $gene_h{$gene_oid} = 1;
                    }
                }
            }

            untie %h;
            @genes = ( keys %gene_h );
            return @genes;
        }
    }

    # else, use zip
    $file_name = $data_type_dir . "/" . $fname . ".zip";
    if ( !$file_name || !( -e $file_name ) ) {
        return @genes;
    }

    WebUtil::unsetEnvPath();

    for my $id3 (@func_list) {
        if ( $id3 =~ /COG/i || $id3 =~ /pfam/i || $id3 =~ /TIGR/i ) {
            $id3 = sanitizeGeneId3($id3);
        } elsif ( $id3 =~ /KO/i ) {

            # ko
            my ( $ko1, $ko2 ) = split( /\:/, $id3 );
            $id3 = "KO:" . sanitizeGeneId3($ko2);
        } elsif ( $id3 =~ /EC/i ) {

            # EC
            my ( $ec1, $ec2 ) = split( /\:/, $id3 );
            $id3 = "EC:" . sanitizeEcId2($ec2);
        }

        my $fh;
        $fh = newCmdFileHandle( "/usr/bin/unzip -C -p $file_name $id3 ", 'FuncGenes' );
        if ( !$fh ) {
            next;
        }

        my $line = "";
        while ( $line = $fh->getline() ) {
            chomp($line);
            my ( $id1, $id2 ) = split( /\t/, $line );
            my $gene_oid = $id2;
            if ( !$gene_oid ) {
                $gene_oid = $id1;
            }

            $gene_h{$gene_oid} = 1;
        }

        close $fh;
    }

    WebUtil::resetEnvPath();

    @genes = ( keys %gene_h );
    return @genes;
}

############################################################################
## getPhyloGeneCounts
############################################################################
sub getPhyloGeneCounts {
    my ( $taxon_oid, $data_type, $domain, $phylum, $ir_class, $family, $genus ) = @_;
    my $taxon_oid = sanitizeInt($taxon_oid);

    my $dbh = dbLogin();

    my @binds   = ( $domain, $phylum );
    my $rclause = WebUtil::urClause('t.taxon_oid');
    my $sql     =
        "select t.taxon_oid, t.taxon_display_name, "
      . "t.family, t.genus, t.species from taxon t "
      . "where t.domain = ? and t.phylum = ? ";
    if ( $ir_class && $ir_class ne "" ) {
        $sql .= " and t.ir_class = ? ";
        push @binds, ($ir_class);
    }
    if ( $family && $family ne "" ) {
        $sql .= " and t.family = ? ";
        push @binds, ($family);
    }
    if ( $genus && $genus ne "" ) {
        $sql .= " and t.genus = ? ";
        push @binds, ($genus);
    }
    $sql .= " and t.obsolete_flag = 'No' " . $rclause;

    my @taxons = ();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    for ( ; ; ) {
        my ($taxon2) = $cur->fetchrow();
        last if !$taxon2;
        push @taxons, ($taxon2);
    }
    $cur->finish();

    #$dbh->disconnect();

    my $count     = 0;
    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        for my $percent ( 30, 60, 90 ) {
            my $sdb_name = getPhyloDistTaxonDir($taxon_oid) . "/" . $t2 . "." . $percent . ".sdb";
            next if ( !-e $sdb_name );

            my $dbh3 = WebUtil::sdbLogin($sdb_name) or next;
            
            my $taxons_str = join( ",", @taxons );
            my $sql3 = qq{
                select count(*)
                from phylo_dist
                where homo_taxon in ( $taxons_str )
            };
            my $sth = $dbh3->prepare($sql3);
            $sth->execute();
            my ($cnt2) = $sth->fetchrow();
            $sth->finish();

            if ($cnt2) {
                $count += $cnt2;
            }

            $dbh3->disconnect();
        }

        #print "> (COUNT:$count) TAXON: $taxon_oid $t2 p:$phylum c:$ir_class f:$family g:$genus <br/>\n";
    }

    #print "> (COUNT:$count) TAXON: $taxon_oid p:$phylum c:$ir_class "
    #	. "f:$family g:$genus HOMOLOGS:" . @taxons ."<br/>";
    return $count;
}

############################################################################
# hasMerFsTaxons
############################################################################
sub hasMerFsTaxons {
    my ($taxon_ref) = @_;
    if ( !$in_file ) {
        return 0;
    }

    my $dbh        = dbLogin();
    my $taxon_list = "";
    my $count      = 0;
    for my $taxon (@$taxon_ref) {
        $count++;
        if ($taxon_list) {
            $taxon_list .= "," . $taxon;
        } else {
            $taxon_list = $taxon;
        }

        if ( $count >= 1000 ) {
            my $sql = "select count(*) from taxon t " . "where t.$in_file = 'Yes' " . "and t.taxon_oid in ($taxon_list)";
            my $cur = execSql( $dbh, $sql, $verbose );
            my $fs_count = $cur->fetchrow();
            $cur->finish();
            if ($fs_count) {

                #$dbh->disconnect();
                return 1;
            }
            $count      = 0;
            $taxon_list = "";
        }
    }

    if ($taxon_list) {
        my $sql      = "select count(*) from taxon t " . "where t.$in_file = 'Yes' " . "and t.taxon_oid in ($taxon_list)";
        my $cur      = execSql( $dbh, $sql, $verbose );
        my $fs_count = $cur->fetchrow();
        $cur->finish();
        if ($fs_count) {

            #$dbh->disconnect();
            return 1;
        }
    }

    #$dbh->disconnect();
    return 0;
}

############################################################################
# hasAssembled - return 1 if the genome has assembled genes
############################################################################
sub hasAssembled {
    my ($taxon_oid) = @_;
    my $t2 = 'assembled';

    $taxon_oid = sanitizeInt($taxon_oid);
    my $dir_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2;
    if ( !( -e $dir_name ) ) {
        return 0;
    }
    return 1;
}

############################################################################
# hasUnassembled - return 1 if the genome has unassembled genes
############################################################################
sub hasUnassembled {
    my ($taxon_oid) = @_;
    my $t2 = 'unassembled';

    $taxon_oid = sanitizeInt($taxon_oid);
    my $dir_name = $mer_data_dir . "/$taxon_oid" . "/" . $t2;
    if ( !( -e $dir_name ) ) {
        return 0;
    }
    return 1;
}

############################################################################
# sanitizePhylum - Sanitize to integer, char - and _ for security purposes.
############################################################################
sub sanitizePhylum {
    my ($s) = @_;
    if ( !$s ) {
        return $s;
    }

    if ( $s !~ /^[ 0-9A-Za-z\-\_\:\.]+$/ ) {
        webDie("sanitizePhylum **: invalid id '$s'\n");
    }
    $s =~ /([ 0-9A-Za-z\-\_\:\.]+)/;
    $s = $1;
    return $s;
}

############################################################################
# sanitizePhylum2 - Sanitize to integer, char, - and _ for security purposes.
############################################################################
sub sanitizePhylum2 {
    my ($s) = @_;
    if ( !$s ) {
        return $s;
    }

    if ( $s !~ /^[ 0-9A-Za-z\-\_\:\,\.\-]+$/ ) {
        webDie("sanitizePhylum2: invalid id '$s'\n");
    }
    $s =~ /([ 0-9A-Za-z\-\_\:\,\.\-]+)/;
    $s = $1;
    return $s;
}

############################################################################
# sanitizeVar - Sanitize to integer, char, - and _ for security purposes.
############################################################################
sub sanitizeVar {
    my ($s) = @_;
    if ( !$s ) {
        return $s;
    }

    if ( $s !~ /^[ 0-9A-Za-z\-\_\:\,\.\-]+$/ ) {
        webDie("sanitizeVar: invalid variable '$s'\n");
    }
    $s =~ /([ 0-9A-Za-z\-\_\:\,\.\-]+)/;
    $s = $1;
    return $s;
}

############################################################################
# getUnzipFileName
############################################################################
sub getUnzipFileName {
    my ($s) = @_;

    $s =~ s/^\s+//;
    $s =~ s/\s+$//;

    my ( $size1, $date1, $time1, $name1 ) = split( /[ \t\s]+/, $s, 4 );
    if ( !$size1 || !isInt($size1) || $size1 <= 0 ) {
        return "";
    }
    return $name1;
}

############################################################################
# getSdbGeneProductFile
############################################################################
sub getSdbGeneProductFile {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my @sdb_names = ();

    my $sdb_name = getSingleSdbGeneProductFile( $taxon_oid, $data_type );
    if ($sdb_name) {
        push( @sdb_names, $sdb_name );
        return @sdb_names;
    }

    $taxon_oid = sanitizeInt($taxon_oid);
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $sdb_name_dir = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/gene_product_sdb";

    if ($gene_oid) {
        my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
        my $code      = HashUtil::get_hash_code( $hash_file, "sdb_gene_name", $gene_oid );

        if ($code) {
            $code = sanitizeGeneId3($code);
            my $sdb_name = $sdb_name_dir . "/gene_product_" . $code . ".sdb";
            if ( -e $sdb_name ) {
                push( @sdb_names, $sdb_name );
            }
        }
    } else {
        opendir( DIR, "$sdb_name_dir" );
        my @files = readdir(DIR);
        closedir(DIR);

        if ( scalar(@files) > 0 ) {
            foreach my $file (@files) {
                if ( $file eq "." || $file eq ".." || $file =~ /~$/ ) {
                    next;
                }
                $sdb_name = "$sdb_name_dir/$file";

                #print "MetaUtil::getSdbGeneProductFile() sdb_name: $sdb_name<br/>\n";
                if ( -e $sdb_name ) {
                    push( @sdb_names, $sdb_name );
                }
            }
        }
    }

    return @sdb_names;
}

############################################################################
# getSingleSdbGeneProductFile
############################################################################
sub getSingleSdbGeneProductFile {
    my ( $taxon_oid, $data_type ) = @_;

    # read gene fna info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my $sdb_name = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/gene_product.sdb";
    if ( -e $sdb_name ) {
        return $sdb_name;
    }

    return '';
}

############################################################################
# getGeneProductGenesFile
#    --es 07/02/13 Inverted index.
############################################################################
sub getGeneProductGenesFile {
    my ( $taxon_oid, $data_type ) = @_;

    if ( $data_type eq 'assembled' || $data_type eq 'unassembled' ) {
        $taxon_oid = sanitizeInt($taxon_oid);
        my $sdb_name = $mer_data_dir . "/" . $taxon_oid . "/" . $data_type . "/gene_product_genes.sdb";
        if ( -e $sdb_name ) {
            return $sdb_name;
        }
    }

    return '';
}

############################################################################
# hasSdbGeneProductFile
############################################################################
sub hasSdbGeneProductFile {
    my ( $taxon_oid, $data_type ) = @_;

    my $sdb_name = getSingleSdbGeneProductFile( $taxon_oid, $data_type );
    if ( -e $sdb_name ) {
        return 1;
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $res       = 0;
    my $hash_file = $mer_data_dir . "/$taxon_oid/$t2/taxon_hash.txt";
    if ( -e $hash_file ) {
        open( HFILE, $hash_file );
        while ( my $line1 = <HFILE> ) {
            chomp($line1);
            my ( $a0, $a1, $a2, @a3 ) = split( /\,/, $line1 );

            if ( $a0 eq "sdb_gene_name" ) {
                $res = 1;
                last;
            }
        }
        close HFILE;
    }

    return $res;
}

############################################################################
# getSdbGeneInfoFile
############################################################################
sub getSdbGeneInfoFile {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @sdb_names    = ();
    my $sdb_name_dir = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/gene";

    if ($gene_oid) {
        my $hash_file = getTaxonHashFile( $taxon_oid, $t2 );
        my $code = HashUtil::get_hash_code( $hash_file, "gene", $gene_oid );

        if ($code) {
            $code = sanitizeGeneId3($code);
            my $sdb_name = $sdb_name_dir . "/gene_" . $code . ".sdb";
            if ( -e $sdb_name ) {
                push( @sdb_names, $sdb_name );
            }
        }
    } else {
        opendir( DIR, "$sdb_name_dir" );
        my @files = readdir(DIR);
        closedir(DIR);

        if ( scalar(@files) > 0 ) {
            foreach my $file (@files) {
                if ( $file eq "." || $file eq ".." || $file =~ /~$/ ) {
                    next;
                }
                if ( $file =~ /.sdb/ ) {
                    my $sdb_name = "$sdb_name_dir/$file";

                    #print "MetaUtil::getSdbGeneInfoFile() sdb_name: $sdb_name<br/>\n";
                    if ( -e $sdb_name ) {
                        push( @sdb_names, $sdb_name );
                    }
                }
            }
        }
    }

    return @sdb_names;
}

############################################################################
# hasSdbGeneInfoFile
############################################################################
sub hasSdbGeneInfoFile {
    my ( $taxon_oid, $data_type ) = @_;

    my @sdb_names = getSdbGeneInfoFile( '', $taxon_oid, $data_type );
    if ( scalar(@sdb_names) > 0 ) {
        return 1;
    }

    return 0;
}

############################################################################
# getSdbScaffoldGenesFile
############################################################################
sub getSdbScaffoldGenesFile {
    my ( $s_oid, $taxon_oid, $data_type ) = @_;

    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @sdb_names    = ();
    my $sdb_name_dir = $mer_data_dir . "/$taxon_oid/$t2/scaffold_genes";

    if ($s_oid) {
        my $hash_file = getTaxonHashFile( $taxon_oid, $t2 );
        my $code = HashUtil::get_hash_code( $hash_file, "scaffold_genes", $s_oid );

        if ($code) {
            $code = sanitizeGeneId3($code);
            my $sdb_name = $sdb_name_dir . "/scaffold_genes_" . $code . ".sdb";
            if ( -e $sdb_name ) {
                push( @sdb_names, $sdb_name );
            }
        }
    } else {
        opendir( DIR, "$sdb_name_dir" );
        my @files = readdir(DIR);
        closedir(DIR);

        if ( scalar(@files) > 0 ) {
            foreach my $file (@files) {
                if ( $file eq "." || $file eq ".." || $file =~ /~$/ ) {
                    next;
                }
                if ( $file =~ /.sdb/ ) {
                    my $sdb_name = "$sdb_name_dir/$file";

                    #print "MetaUtil::getSdbScaffoldGenesFile() sdb_name: $sdb_name<br/>\n";
                    if ( -e $sdb_name ) {
                        push( @sdb_names, $sdb_name );
                    }
                }
            }
        }
    }

    return @sdb_names;
}

############################################################################
# getSdbScaffoldDnaFile
############################################################################
sub getSdbScaffoldDnaFile {
    my ( $s_oid, $taxon_oid, $data_type ) = @_;

    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @sdb_names    = ();
    my $sdb_name_dir = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/fna";

    if ($s_oid) {
        my $hash_file = getTaxonHashFile( $taxon_oid, $t2 );
        my $code = HashUtil::get_hash_code( $hash_file, "fna", $s_oid );

        if ($code) {
            $code = sanitizeGeneId3($code);
            my $sdb_name = $sdb_name_dir . "/fna_" . $code . ".sdb";
            if ( -e $sdb_name ) {
                push( @sdb_names, $sdb_name );
            }
        }
    } else {
        opendir( DIR, "$sdb_name_dir" );
        my @files = readdir(DIR);
        closedir(DIR);

        if ( scalar(@files) > 0 ) {
            foreach my $file (@files) {
                if ( $file eq "." || $file eq ".." || $file =~ /~$/ ) {
                    next;
                }
                if ( $file =~ /.sdb/ ) {
                    my $sdb_name = "$sdb_name_dir/$file";

                    #print "MetaUtil::getSdbScaffoldDnaFile() sdb_name: $sdb_name<br/>\n";
                    if ( -e $sdb_name ) {
                        push( @sdb_names, $sdb_name );
                    }
                }
            }
        }
    }

    return @sdb_names;
}

############################################################################
# getSdbGeneAAFile
############################################################################
sub getSdbGeneAAFile {
    my ( $gene_oid, $taxon_oid, $data_type ) = @_;

    # read gene fna info
    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    $taxon_oid = sanitizeInt($taxon_oid);

    my @sdb_names    = ();
    my $sdb_name_dir = $mer_data_dir . "/" . $taxon_oid . "/" . $t2 . "/faa";

    if ($gene_oid) {
        my $hash_file = getTaxonHashFile( $taxon_oid, $t2 );
        my $code = HashUtil::get_hash_code( $hash_file, "faa", $gene_oid );

        if ($code) {
            $code = sanitizeGeneId3($code);
            my $sdb_name .= $sdb_name_dir . "/faa_" . $code . ".sdb";
            if ( -e $sdb_name ) {
                push( @sdb_names, $sdb_name );
            }
        }
    } else {
        opendir( DIR, "$sdb_name_dir" );
        my @files = readdir(DIR);
        closedir(DIR);

        if ( scalar(@files) > 0 ) {
            foreach my $file (@files) {
                if ( $file eq "." || $file eq ".." || $file =~ /~$/ ) {
                    next;
                }
                if ( $file =~ /.sdb/ ) {
                    my $sdb_name = "$sdb_name_dir/$file";

                    #print "MetaUtil::getSdbGeneAAFile() sdb_name: $sdb_name<br/>\n";
                    if ( -e $sdb_name ) {
                        push( @sdb_names, $sdb_name );
                    }
                }
            }
        }
    }

    return @sdb_names;
}

############################################################################
# hasSdbGeneAAFile
############################################################################
sub hasSdbGeneAAFile {
    my ( $taxon_oid, $data_type ) = @_;

    my @sdb_names = getSdbGeneAAFile( '', $taxon_oid, $data_type );
    if ( scalar(@sdb_names) > 0 ) {
        return 1;
    }

    return 0;
}

############################################################################
# hasSdbScaffoldGenesFile
############################################################################
sub hasSdbScaffoldGenesFile {
    my ( $taxon_oid, $data_type ) = @_;

    my @sdb_names = getSdbScaffoldGenesFile( '', $taxon_oid, $data_type );
    if ( scalar(@sdb_names) > 0 ) {
        return 1;
    }

    return 0;
}

############################################################################
# hasSdbScaffoldDnaFile
############################################################################
sub hasSdbScaffoldDnaFile {
    my ( $taxon_oid, $data_type ) = @_;

    my @sdb_names = getSdbScaffoldDnaFile( '', $taxon_oid, $data_type );
    if ( scalar(@sdb_names) > 0 ) {
        return 1;
    }

    return 0;
}

############################################################################
# getSingleSdbScaffoldStatsFile
############################################################################
sub getSingleSdbScaffoldStatsFile {
    my ( $taxon_oid, $data_type ) = @_;

    $taxon_oid = sanitizeInt($taxon_oid);

    my $t2 = 'unassembled';
    if ( $data_type eq 'assembled' ) {
        $t2 = 'assembled';
    }

    my $sdb_name = $mer_data_dir . "/$taxon_oid/$t2/scaffold_stats.sdb";
    if ( -e $sdb_name ) {
        return $sdb_name;
    }

    return '';
}

############################################################################
# hasSdbScaffoldStatsFile
############################################################################
sub hasSdbScaffoldStatsFile {
    my ( $taxon_oid, $data_type ) = @_;

    my $sdb_name = getSingleSdbScaffoldStatsFile( $taxon_oid, $data_type );
    if ( -e $sdb_name ) {
        return 1;
    }

    return 0;
}

############################################################################
# getSingleSdbScaffoldDepthFile
############################################################################
sub getSingleSdbScaffoldLineageFile {
    my ( $taxon_oid, $data_type ) = @_;

    $taxon_oid = sanitizeInt($taxon_oid);

    my $t2 = 'assembled';
    if ( $data_type eq 'unassembled' ) {
        $t2 = 'unassembled';
    }

    my $sdb_name = getPhyloDistTaxonDir($taxon_oid) . "/contigLin.assembled.sdb";
    if ( -e $sdb_name ) {
        return $sdb_name;
    }

    return '';
}

############################################################################
# getSingleSdbScaffoldDepthFile
############################################################################
sub getSingleSdbScaffoldDepthFile {
    my ( $taxon_oid, $data_type ) = @_;
    $taxon_oid = sanitizeInt($taxon_oid);

    my $t2 = 'assembled';
    if ( $data_type eq 'unassembled' ) {
        $t2 = 'unassembled';
    }

    my $sdb_name = $mer_data_dir . "/$taxon_oid/$t2/scaffold_depth.sdb";
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE) {
        return $sdb_name;
    }

    return '';
}

############################################################################
# hasRNASeq - return 1 if the specified gene_oid has RNASeq data
############################################################################
sub hasRNASeq {
    my ( $mygene_oid, $taxon_oid ) = @_;
    $taxon_oid = sanitizeInt($taxon_oid);

    my $sdb_name = $mer_rnaseq_sdb_dir . 
	           "/$taxon_oid/$taxon_oid" . ".rnaSeq.sdb";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $sdbh = WebUtil::sdbLogin($sdb_name) or return "";
        my $sql  = qq{
            select img_gene_oid
            from rnaseq_expression
            where img_gene_oid = ?
        };
        my $sth = $sdbh->prepare($sql);
        $sth->execute($mygene_oid);
        my ($gene_oid) = $sth->fetchrow_array();

        $sth->finish();
        $sdbh->disconnect();
        return 1 if ( $gene_oid eq $mygene_oid );
    }

    my $zip_name = $mer_data_dir
	         . "/$taxon_oid/assembled/rnaseq_expression.zip";
    if ( !( -e $zip_name ) ) {
        return 0;
    }

    WebUtil::unsetEnvPath();

    my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name ", 'hasRNASeq' );
    my $count = 0;
    while ( my $line = $fh->getline() ) {
        chomp($line);
        my ( $item1, $item2, @rest ) = split( /\t/, $line );
        return 1 if ( $item1 eq $mygene_oid );
        return 1 if ( $item2 eq $mygene_oid );
        $count++;
    }
    close $fh;

    WebUtil::resetEnvPath();

    return 0;
}

############################################################################
# getGeneInRNASeqSample - return gene info for the specified
#                         gene, sample, and taxon
############################################################################
sub getGeneInRNASeqSample {
    my ( $mygene_oid, $sample_oid, $taxon_oid ) = @_;
    $taxon_oid  = sanitizeInt($taxon_oid);
    $sample_oid = sanitizeVar($sample_oid);

    my $sdb_name = $mer_rnaseq_sdb_dir 
	         . "/$taxon_oid/$taxon_oid" . ".rnaSeq.sdb";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $sdbh = WebUtil::sdbLogin($sdb_name) or return 0;
        my $sql  = qq{
            select img_gene_oid, locus_type, locus_tag,
                   strand, img_scaffold_oid, length, reads_cnt
            from rnaseq_expression
            where dataset_oid = ?
            and img_gene_oid = ?
        };
        my $sth = $sdbh->prepare($sql);
        $sth->execute( $sample_oid, $mygene_oid );

        my ( $gene_oid, $locus_type, $locus_tag, $strand, $scaffold_oid,
	     $length, $reads_cnt ) = $sth->fetchrow_array();

        $sth->finish();
        $sdbh->disconnect();

        return ( $gene_oid, $locus_type, $locus_tag, $strand, $scaffold_oid,
		 $length, $reads_cnt ) if ( $gene_oid eq $mygene_oid );
    }

    my $zip_name = $mer_data_dir 
	. "/$taxon_oid/assembled/rnaseq_expression." . $sample_oid . ".zip";
    if ( !( -e $zip_name ) ) {
        return ( 0, 0, 0, 0, 0, 0, 0 );
    }

    WebUtil::unsetEnvPath();

    my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name ",
			       'getGeneInRNASeqSample' );

    # each line is in tab-delimited format:
    # gene_oid locus_type locus_tag strand scaffold_oid
    # length reads_cnt mean median stdev reads_cnta meana
    # mediana stdeva exp_id sample_oid
    while ( my $line = $fh->getline() ) {
        chomp($line);
        my ( $gene_oid, $locus_type, $locus_tag, $strand, $scaffold_oid,
	     $length, $reads_cnt, @rest ) = split( "\t", $line );
        return ( $gene_oid, $locus_type, $locus_tag, $strand, $scaffold_oid,
		 $length, $reads_cnt ) if ( $gene_oid eq $mygene_oid );
    }
    close $fh;

    WebUtil::resetEnvPath();

    return ( 0, 0, 0, 0, 0, 0, 0 );
}

############################################################################
# getGenesForRNASeqSampleInScaffold - return genes for the specified sample
#         and taxon which are on the scaffold specified
############################################################################
sub getGenesForRNASeqSampleInScaffold {
    my ( $sample_oid, $taxon_oid, $scaffold_oid ) = @_;
    $taxon_oid  = sanitizeInt($taxon_oid);
    $sample_oid = sanitizeVar($sample_oid);

    my $sdb_name = $mer_rnaseq_sdb_dir
	         . "/$taxon_oid/$taxon_oid" . ".rnaSeq.sdb";

    my %gene2info;
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $sdbh = WebUtil::sdbLogin($sdb_name) or return "";
        my $sql  = qq{
            select distinct img_gene_oid, locus_type, locus_tag,
                   strand, img_scaffold_oid, length, reads_cnt
            from rnaseq_expression
            where dataset_oid = ?
            and scaffold_accession = ?
            and reads_cnt > 0.00000
        };
        my $sth = $sdbh->prepare($sql);
        $sth->execute( $sample_oid, $scaffold_oid );

	#
	# NOTE: scaffold_oid is not reliable here - error in submission
	# get scaffold_oid from gene table for isolates
	# get it using scaffold_accession in rnaseq_expression for metagenomes
	#

        my $count = 0;
        for ( ; ; ) {
            my ( $gene_oid, $locus_type, $locus_tag, $strand, $scaffold_oid,
		 $length, $reads_cnt ) = $sth->fetchrow_array();
            last if !$gene_oid;
            last if $count > $maxGeneListResults;
            $gene2info{$gene_oid} = $gene_oid . "\t"
		                  . $locus_type . "\t"
				  . $locus_tag . "\t"
				  . $strand . "\t"
				  . $scaffold_oid . "\t"
				  . $length . "\t"
				  . $reads_cnt;
            $count++;
        }

        $sth->finish();
        $sdbh->disconnect();
    }

    return %gene2info;
}

############################################################################
# getGenesForRNASeqSample - return genes for the specified sample & taxon
############################################################################
sub getGenesForRNASeqSample {
    my ( $sample_oid, $taxon_oid ) = @_;

    $taxon_oid  = sanitizeInt($taxon_oid);
    my @sample_oids = ( $sample_oid );

    my ($dataset2gene2info_href) = getGenesForRNASeqSamples( \@sample_oids, $taxon_oid, 1 );
    if ( $dataset2gene2info_href ) {
        my $gene2info_href = $dataset2gene2info_href->{$sample_oid};
        if ( $gene2info_href ) {
            return %$gene2info_href;            
        }
    }

    my %gene2info;
    
    my $zip_name = $mer_data_dir 
	. "/$taxon_oid/assembled/rnaseq_expression." . $sample_oid . ".zip";
    if ( !( -e $zip_name ) ) {
        return %gene2info;
    }

    WebUtil::unsetEnvPath();

    my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name ",
			       'genesForRNASeqSample' );

    # each line is in tab-delimited format:
    # gene_oid locus_type locus_tag strand scaffold_oid
    # length reads_cnt mean median stdev reads_cnta meana
    # mediana stdeva exp_id sample_oid
    while ( my $line = $fh->getline() ) {
        chomp($line);
        my ( $gene_oid, @rest ) = split( /\t/, $line );
        $gene2info{$gene_oid} = $line;
    }
    close $fh;

    WebUtil::resetEnvPath();

    return %gene2info;
}

sub getGenesForRNASeqSamples {
    my ( $sample_oids_ref, $taxon_oid, $toLimitMax ) = @_;

    $taxon_oid  = sanitizeInt($taxon_oid);

    my $sdb_name = $mer_rnaseq_sdb_dir 
        . "/$taxon_oid/$taxon_oid" . ".rnaSeq.sdb";

    my %dataset2gene2info;
#    my %gene2dataset2info;
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $sdbh = WebUtil::sdbLogin($sdb_name) or return "";
        
        my $sampleClause;
        if ( $sample_oids_ref ) {
            if ( scalar(@$sample_oids_ref) == 1 ) {
                $sampleClause = " and dataset_oid = ? "
            }
            else {
                my $data_oids_str = join( ",", @$sample_oids_ref );
                $sampleClause = " and dataset_oid in ( $data_oids_str ) "
            }
        }
        
        my $sql  = qq{
            select distinct dataset_oid, 
                   img_gene_oid, locus_type, locus_tag, strand, 
                   img_scaffold_oid, length, reads_cnt
            from rnaseq_expression
            where reads_cnt > 0.00000
            $sampleClause
        };
        my $sth = $sdbh->prepare($sql);
        if ( $sample_oids_ref && scalar(@$sample_oids_ref) == 1 ) {
            my $sample_oid = @$sample_oids_ref[0];
            $sample_oid = sanitizeVar($sample_oid);
            $sth->execute($sample_oid);
        }
        else {
            $sth->execute();
        }

        my $count = 0;
        for ( ;; ) {
            my ( $dataset_oid, $gene_oid, $locus_type, $locus_tag, $strand, 
                $scaffold_oid, $length, $reads_cnt ) = $sth->fetchrow_array();
            last if !$dataset_oid;

            my $info = $gene_oid . "\t"
                      . $locus_type . "\t"
                      . $locus_tag . "\t"
                      . $strand . "\t"
                      . $scaffold_oid . "\t"
                      . $length . "\t"
                      . $reads_cnt;

            my $gene2info_href = $dataset2gene2info{$dataset_oid};
            if ( ! $gene2info_href ) {
                my %gene2info;
                $gene2info_href = \%gene2info;
                $dataset2gene2info{$dataset_oid} = $gene2info_href;
            }
            $gene2info_href->{$gene_oid} = $info;

#            my $dataset2info_href = $gene2dataset2info{$gene_oid};
#            if ( ! $dataset2info_href ) {
#                my %dataset2info;
#                $dataset2info_href = \%dataset2info;
#                $gene2dataset2info{$gene_oid} = $dataset2info_href;
#            }
#            $dataset2info_href->{$dataset_oid} = $info;
            
            $count++;
            if ( $toLimitMax ) {
                last if $count >= $maxGeneListResults;
            }
        }

        $sth->finish();
        $sdbh->disconnect();
    }

    return (\%dataset2gene2info);
}


############################################################################
# getRNASeqSampleCountsForTaxon - returns all sample counts for a taxon
# if $idx param is specified as 1, then returns only the total gene count
############################################################################
sub getRNASeqSampleCountsForTaxon {
    my ( $taxon_oid, $idx, $show_status ) = @_;
    $show_status = 0 if $show_status eq "";
    $taxon_oid = sanitizeInt($taxon_oid);

    my $sdb_name = $mer_rnaseq_sdb_dir 
                 . "/$taxon_oid/$taxon_oid" . ".rnaSeq.sdb";

    my %counts;
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $sdbh = WebUtil::sdbLogin($sdb_name) or return "";
        my $sql  = qq{
            select distinct dataset_oid,
                   count(distinct img_gene_oid),
                   sum(reads_cnt), round(avg(reads_cnt), 2)
            from rnaseq_expression
            group by dataset_oid
        };
        my $sth = $sdbh->prepare($sql);
        $sth->execute();

        for ( ;; ) {
            my ($sample_oid, $total_gene_cnt, $total_read_cnt, $avg_read_cnt)
		= $sth->fetchrow_array();
            last if !$sample_oid;
	    print "<br/>...getting rnaseq counts for sample: $sample_oid "
		if $show_status;

            if ( $idx == 1 ) {
                $counts{$sample_oid} = $total_read_cnt;
            } else {
		$counts{$sample_oid} = $sample_oid . "\t" 
		                     . $total_gene_cnt . "\t"
				     . $total_read_cnt . "\t" 
				     . $avg_read_cnt;
	    }
        }

        $sth->finish();
        $sdbh->disconnect();
        return %counts;
    }

    my $file_name = $mer_data_dir . "/$taxon_oid/assembled/sample_counts.txt";
    if ( !( -e $file_name ) ) {
        return %counts;
    }

    my $rfh = newReadFileHandle($file_name);
    if ($rfh) {
        while ( my $line = $rfh->getline() ) {
            chomp($line);
            my ( $sample_oid, $total_gene_cnt, $total_read_cnt ) =
              split( /\t/, $line );
            if ( $idx == 1 ) {
                $counts{$sample_oid} = $total_read_cnt;
            } else {
                $counts{$sample_oid} = $line;
            }
        }
    }
    close $rfh;
    return %counts;
}

############################################################################
# getCountsForRNASeqSample - returns counts for the specified sample & taxon
############################################################################
sub getCountsForRNASeqSample {
    my ( $mysample_oid, $taxon_oid ) = @_;
    $taxon_oid    = sanitizeInt($taxon_oid);
    $mysample_oid = sanitizeVar($mysample_oid);

    my $sdb_name = $mer_rnaseq_sdb_dir 
	         . "/$taxon_oid/$taxon_oid" . ".rnaSeq.sdb";

    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $sdbh = WebUtil::sdbLogin($sdb_name) or return "";
        my $sql  = qq{
            select count(distinct img_gene_oid), sum(reads_cnt)
            from rnaseq_expression
            where dataset_oid = ?
        };
        my $sth = $sdbh->prepare($sql);
        $sth->execute($mysample_oid);
        my ( $total_gene_cnt, $total_read_cnt ) = $sth->fetchrow_array();

        $sth->finish();
        $sdbh->disconnect();
        return ( $total_gene_cnt, $total_read_cnt );
    }

    my $file_name = $mer_data_dir . "/$taxon_oid/assembled/sample_counts.txt";
    if ( !( -e $file_name ) ) {
        return ( 0, 0 );
    }

    my $rfh = newReadFileHandle($file_name);
    if ($rfh) {
        while ( my $line = $rfh->getline() ) {
            chomp($line);
            my ( $sample_oid, $total_gene_cnt, $total_read_cnt ) =
              split( /\t/, $line );
            return ( $total_gene_cnt, $total_read_cnt )
              if ( $sample_oid eq $mysample_oid );
        }
    }
    close $rfh;
    return ( 0, 0 );
}

############################################################################
# getGenesForRNASeqTaxon - returns gene_oid -> rnaseq info
#
# rnaseq info is in tab-delimited format:
# gene_oid locus_type locus_tag strand scaffold
# length reads_cnt mean median stdev reads_cnta meana
# mediana stdeva experiment sample desc
############################################################################
sub getGenesForRNASeqTaxon {
    my ($taxon_oid) = @_;
    $taxon_oid = sanitizeInt($taxon_oid);

    my $sdb_name = $mer_rnaseq_sdb_dir 
	         . "/$taxon_oid/$taxon_oid" . ".rnaSeq.sdb";

    my %rnaseq_h;
    if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
        my $sdbh = WebUtil::sdbLogin($sdb_name) or return "";
        my $sql  = qq{
            select distinct img_gene_oid, locus_type, locus_tag,
                   strand, img_scaffold_oid, length, reads_cnt
            from rnaseq_expression
            where reads_cnt > 0.00000
        };
        my $sth = $sdbh->prepare($sql);
        $sth->execute();

        my $count = 0;
        for ( ; ; ) {
            my ( $gene_oid, $locus_type, $locus_tag, $strand, $scaffold_oid,
		 $length, $reads_cnt ) = $sth->fetchrow_array();
            last if !$gene_oid;
            last if $count > $maxGeneListResults;
            $rnaseq_h{$gene_oid} = $gene_oid . "\t"
		                 . $locus_type . "\t"
				 . $locus_tag . "\t"
				 . $strand . "\t"
				 . $scaffold_oid . "\t"
				 . $length . "\t"
				 . $reads_cnt;
            $count++;
        }

        $sth->finish();
        $sdbh->disconnect();
        return %rnaseq_h;
    }

    my $zip_name = $mer_data_dir 
	         . "/$taxon_oid/assembled/rnaseq_expression.zip";
    if ( !( -e $zip_name ) ) {
        return %rnaseq_h;
    }

    WebUtil::unsetEnvPath();

    my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name ", 'taxonRnaSeq' );
    while ( my $line = $fh->getline() ) {
        chomp($line);
        my ( $gene_oid, @rest ) = split( /\t/, $line );
        $rnaseq_h{$gene_oid} = $line;
    }
    close $fh;

    WebUtil::resetEnvPath();

    return %rnaseq_h;
}

###############################################################################
# getAllGeneNames
###############################################################################
sub getAllGeneNames {
    my ( $gene_href, $gene_name_href, $print_msg ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) = 
	MerFsUtil::splitDbAndMetaOids( keys %$gene_href );
    my @db_ids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@db_ids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving gene names from database ... <br/>\n";
        }
        
        my $dbh = dbLogin();
        my $db_str = OracleUtil::getNumberIdsInClause( $dbh, @db_ids );
        my $sql = "select g.gene_oid, g.gene_display_name, g.taxon "
        . "from gene g where g.gene_oid in ($db_str) ";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id2, $name2, $t_oid ) = $cur->fetchrow();
            last if !$id2;
            if ( !$name2 ) {
                $name2 = "hypothetical protein";
            }
            $gene_name_href->{$id2} = $name2;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $db_str =~ /gtt_num_id/i );        
    }
    #print "MetaUtil::getAllGeneNames() 1 " . currDateTime() . "<br/>\n";

    if ( scalar(@metaOids) > 0 ) {
        getAllMetaGeneNames( $gene_href, \@metaOids, $gene_name_href, '', $print_msg );
    }
    #print "MetaUtil::getAllGeneNames() 2 " . currDateTime() . "<br/>\n";
}

###############################################################################
# getAllMetaGeneNames
###############################################################################
sub getAllMetaGeneNames {
    my ( $gene_href, $metaOids_ref, $gene_name_href, $taxon_genes_href, $print_msg ) = @_;

    #print "MetaUtil::getAllMetaGeneNames() 1 " . currDateTime() . "<br/>\n";

    my @metaOids;
    if ( $metaOids_ref eq '' ) {
        @metaOids = keys %$gene_href;
    } else {
        @metaOids = @$metaOids_ref;
    }

    if ( scalar(@metaOids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving gene names from filesystem ... <br/>\n";
        }

        my %taxon_genes;
        if ( $taxon_genes_href eq '' ) {
            %taxon_genes = getOrganizedTaxonGenes(@metaOids);
        } else {
            %taxon_genes = %$taxon_genes_href;
        }

        my $count = 0;
        my $trunc = 0;
        for my $key ( keys %taxon_genes ) {
            my ( $taxon_oid, $data_type ) = split( / /, $key );
            $taxon_oid = sanitizeInt($taxon_oid);

            #print "MetaUtil::getAllMetaGeneNames() $taxon_oid $data_type " . currDateTime() . "<br/>\n";

            my $oid_ref = $taxon_genes{$key};
            if ( $oid_ref ne '' && scalar(@$oid_ref) > 0 ) {
                my $hasGeneProdSqliteFile = hasSdbGeneProductFile( $taxon_oid, $data_type );

                if ($hasGeneProdSqliteFile) {
                    if ($print_msg) {
                        print "<p>Retrieving gene names for genome $taxon_oid $data_type ...<br/>\n";
                    }

                    my %prodFile_genes;
                    my $singleProdFile = getSingleSdbGeneProductFile( $taxon_oid, $data_type );

                   #print "getAllMetaGeneNames() singleProdFile $singleProdFile for genome $taxon_oid $data_type ...<br/>\n";
                    if ($singleProdFile) {
                        $prodFile_genes{$singleProdFile} = $oid_ref;
                    } else {
                        %prodFile_genes = getOrganizedTaxonGeneProductFiles( $taxon_oid, $data_type, @$oid_ref );

           #print "getAllMetaGeneNames() getOrganizedTaxonGeneProductFiles done for genome $taxon_oid $data_type ...<br/>\n";
                    }

                    for my $prodFile ( keys %prodFile_genes ) {
                        my $file_oids_ref = $prodFile_genes{$prodFile};
                        my $cnt0          = scalar(@$file_oids_ref);

                       #print "getAllMetaGeneNames() $prodFile with $cnt0 genes for genome $taxon_oid $data_type ...<br/>\n";
                        if ( $cnt0 == 0 ) {
                            next;
                        }

                        my $cnt1         = 0;
                        my $file_oid_str = '';
                        for my $file_oid (@$file_oids_ref) {
                            if ($file_oid_str) {
                                $file_oid_str .= ", '" . $file_oid . "'";
                            } else {
                                $file_oid_str = "'" . $file_oid . "'";
                            }
                            $cnt1++;
                            if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                                my $sql =
"select gene_oid, gene_display_name, img_product_source from gene where gene_oid in ($file_oid_str)";
                                my (%geneNames) = fetchGeneNameForTaxonFromSqlite( $taxon_oid, $data_type, $prodFile, $sql );
                                if ( scalar( keys %geneNames ) > 0 ) {
                                    foreach my $gene_oid ( keys %geneNames ) {
                                        my $workspace_id = "$taxon_oid $data_type $gene_oid";
                                        $gene_name_href->{$workspace_id} = $geneNames{$gene_oid};
                                        $count++;
                                    }
                                }
                                $file_oid_str = '';
                            }
                        }
                    }    #end of for prodFile

                } else {
                    if ($print_msg) {
                        print
"<p>No sqlite gene product file, retrieving gene name from gene_product.txt file for genome $taxon_oid $data_type<br/>\n";
                    }
                    webLog("MetaUtil::getAllMetaGeneNames() no sqlite gene product file for genome $taxon_oid $data_type\n");

                    my $tag = "gene_product";

                    my @mTaxonOids          = ($taxon_oid);
                    my $dbh                 = dbLogin();
                    my %taxon_gene_cnt_hash = QueryUtil::fetchTaxonOid2GeneCntHash( $dbh, \@mTaxonOids );

                    #$dbh->disconnect();

                    my $total_gene_cnt = $taxon_gene_cnt_hash{$taxon_oid};
                    if ( scalar(@$oid_ref) > 20
                        && $total_gene_cnt <= $max_gene_cnt_for_product_file )
                    {
                        my %termFoundHash;
                        my $isGeneProductTxtFileExist;
                        ( $count, $trunc, $isGeneProductTxtFileExist ) = doGeneIdSearchInProdTxtFile(
                            $print_msg, '',              $taxon_oid,      $data_type, $tag,
                            $oid_ref,   \%termFoundHash, $gene_name_href, $count,     $trunc
                        );

                        if ( !$isGeneProductTxtFileExist ) {
                            doFlieReading( $print_msg, '', $taxon_oid, $data_type, $oid_ref, $tag, $gene_name_href,
                                $gene_href );
                        }
                    } else {
                        doFlieReading( $print_msg, '', $taxon_oid, $data_type, $oid_ref, $tag, $gene_name_href, $gene_href );
                    }

                    #added below due to
                    #some gene_product zip files have no newline at the end
                    #or no gene_product.txt file
                    for my $oid (@$oid_ref) {
                        my $workspace_id = "$taxon_oid $data_type $oid";

                        if ( $gene_name_href->{$workspace_id} ) {
                            next;
                        }

                        if ($print_msg) {
                            print
"MetaUtil::getAllGeneNames() taxon $taxon_oid $data_type for gene $oid may not have newline at the end of its product files<br/>\n";
                        }

                        my $prod_name = getGeneProdName( $oid, $taxon_oid, $data_type );
                        if ($prod_name) {
                            $gene_name_href->{$workspace_id} = $prod_name;
                            $count++;
                        }

                        if ($print_msg) {
                            if ( ( $count % 10 ) == 0 ) {
                                print ".";
                            }
                            if ( ( $count % 1800 ) == 0 ) {
                                print "<br/>\n";
                            }
                        }
                    }

                }

            }

        }    # end for key
    }

    #print "MetaUtil::getAllMetaGeneNames() 2 " . currDateTime() . "<br/>\n";
}

###############################################################################
# getAllGeneInfo
###############################################################################
sub getAllGeneInfo {
    my ( $gene_href, $gene_info_href, $scaf_href, $print_msg ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids( keys %$gene_href );
    my @db_ids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@db_ids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving gene informations from database ... <br/>\n";
        }

        my $dbh = dbLogin();
        my $db_str = OracleUtil::getNumberIdsInClause( $dbh, @db_ids );
        my $sql =
            "select gene_oid, locus_type, "
          . "locus_tag, gene_display_name, "
          . "start_coord, end_coord, strand, scaffold, taxon "
          . "from gene where gene_oid in ($db_str) ";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id2, @rest ) = $cur->fetchrow();
            last if !$id2;

            $gene_info_href->{$id2} = join( "\t", @rest );

            if ( defined($scaf_href) && $scaf_href ne '' ) {
                if ( scalar(@rest) >= 7 ) {
                    my $scaf2 = $rest[6];
                    if ($scaf2) {
                        $scaf_href->{$scaf2} = 1;
                    }
                }
            }
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $db_str =~ /gtt_num_id/i );        
    }
    #print "MetaUtil::getAllGeneInfo() 1 " . currDateTime() . "<br/>\n";

    if ( scalar(@metaOids) > 0 ) {
        getAllMetaGeneInfo( $gene_href, \@metaOids, $gene_info_href, $scaf_href, '', $print_msg );
    }

    #print "MetaUtil::getAllGeneInfo() 2 " . currDateTime() . "<br/>\n";

}

###############################################################################
# getAllMetaGeneInfo
###############################################################################
sub getAllMetaGeneInfo {
    my (
        $gene_href, $metaOids_ref,       $gene_info_href,    $scaf_href, $taxon_genes_href,
        $print_msg, $useCaseInsensitive, $onlyAssembledScaf, $maxCount
      )
      = @_;

    #print "MetaUtil::getAllMetaGeneInfo() 1 " . currDateTime() . "<br/>\n";

    my @metaOids;
    if ( $metaOids_ref eq '' ) {
        @metaOids = keys %$gene_href;
    } else {
        @metaOids = @$metaOids_ref;
    }

    if ( scalar(@metaOids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving gene information from filesystem ... <br/>\n";
        }

        my %taxon_genes;
        if ( $taxon_genes_href eq '' ) {
            %taxon_genes = getOrganizedTaxonGenes(@metaOids);
        } else {
            %taxon_genes = %$taxon_genes_href;
        }

        my $tag = "gene";
        my @foundIds;
        my $maxCounter = 0;
        for my $key ( keys %taxon_genes ) {
            if ($maxCount && $maxCounter > $maxCount ) {
                last;
            }

            #print "<p>key: $key\n";
            my ( $taxon_oid, $data_type ) = split( / /, $key );

            #print "MetaUtil::getAllMetaGeneInfo() $taxon_oid $data_type " . currDateTime() . "<br/>\n";
            $taxon_oid = sanitizeInt($taxon_oid);

            my $oid_ref = $taxon_genes{$key};
            if ( $oid_ref ne '' && scalar(@$oid_ref) > 0 ) {
                my $hasGeneInfoSqliteFile = hasSdbGeneInfoFile( $taxon_oid, $data_type );

                if ($hasGeneInfoSqliteFile) {
                    if ($print_msg) {
                        print "<p>Retrieving gene information for genome $taxon_oid $data_type ...<br/>\n";
                    }

                    my %geneInfoFile_genes;
                    if ($useCaseInsensitive) {
                        my @sdb_names = getSdbGeneInfoFile( '', $taxon_oid, $data_type );
                        my @empty     = ();
                        my $cnt       = 0;
                        for my $sdb_name (@sdb_names) {
                            if ( $cnt == 0 ) {
                                $geneInfoFile_genes{$sdb_name} = $oid_ref;
                                $cnt = 1;
                            } else {

                                #to dynamically build $oid_ref
                                $geneInfoFile_genes{$sdb_name} = \@empty;
                            }
                        }
                    } else {
                        %geneInfoFile_genes = getOrganizedTaxonGeneInfoFiles( $taxon_oid, $data_type, @$oid_ref );
                    }

                    for my $geneInfoFile ( keys %geneInfoFile_genes ) {

                        if ($print_msg) {
                            print "$maxCounter gene file $geneInfoFile<br/>\n";
                        }

                        my $file_oids_ref = $geneInfoFile_genes{$geneInfoFile};
                        my $cnt0          = scalar(@$file_oids_ref);
                        if ( $cnt0 == 0 ) {
                            if ($useCaseInsensitive) {

                                #dynamically build $oid_ref
                                my @notFoundIds = ();
                                for my $oid (@$oid_ref) {
                                    if ( WebUtil::inArray_ignoreCase( $oid, @foundIds ) ) {
                                        next;
                                    }
                                    push( @notFoundIds, $oid );
                                }
                                $file_oids_ref = \@notFoundIds;
                            } else {
                                next;
                            }
                        }

                        my $cnt1         = 0;
                        my $file_oid_str = '';
                        for my $file_oid (@$file_oids_ref) {
                            if ($maxCount && $maxCounter > $maxCount ) {
                                last;
                            }

                            if ($file_oid_str) {
                                $file_oid_str .= ", '" . $file_oid . "'";
                            } else {
                                $file_oid_str = "'" . $file_oid . "'";
                            }
                            $cnt1++;
                            if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                                my $sql =
                                    "select gene_oid, locus_type, locus_tag, product_name, "
                                  . "start_coord, end_coord, strand, scaffold_oid from gene ";

                                #$useCaseInsensitive is used
                                if ($useCaseInsensitive) {
                                    $file_oid_str =~ tr/A-Z/a-z/;
                                    $sql .= " where lower(gene_oid) in ($file_oid_str)";
                                } else {
                                    $sql .= " where gene_oid in ($file_oid_str)";
                                }
                                my (%geneInfos) =
                                  fetchGeneInfoForTaxonFromSqlite( $taxon_oid, $data_type, $geneInfoFile, $sql );

                                #print Dumper(\%geneInfos);
                                if ( scalar( keys %geneInfos ) > 0 ) {
                                    foreach my $gene_oid ( keys %geneInfos ) {
                                        $maxCounter++;
                                        if ($useCaseInsensitive) {
                                            push( @foundIds, $gene_oid );
                                        }
                                        my $workspace_id = "$taxon_oid $data_type $gene_oid";
                                        $gene_info_href->{$workspace_id} = $geneInfos{$gene_oid};
                                        if ( $scaf_href && defined($scaf_href) ) {
                                            if ( !$onlyAssembledScaf || ( $onlyAssembledScaf && $data_type eq 'assembled' ) )
                                            {
                                                my ( $locus_type, $locus_tag, $gene_display_name, $start_coord, $end_coord,
                                                    $strand, $scaffold_oid )
                                                  = split( /\t/, $geneInfos{$gene_oid} );
                                                if ($scaffold_oid) {
                                                    my $ws_scaf_id = "$taxon_oid $data_type $scaffold_oid";
                                                    $scaf_href->{$ws_scaf_id} = 1;
                                                }
                                            }
                                        }
                                    }
                                }
                                $file_oid_str = '';
                            }
                        }
                    }
                } else {
                    if ($print_msg) {
                        print
"<p>No gene information sqlite file, retrieving gene information from zip file for genome $taxon_oid $data_type<br/>\n";
                    }
                    webLog(
                        "MetaUtil::getAllMetaGeneInfo() no gene information sqlite file for genome $taxon_oid $data_type\n");

                    doFlieReading( $print_msg, 1, $taxon_oid, $data_type, $oid_ref, $tag, $gene_info_href, $gene_href,
                        $scaf_href );
                }
            }
        }    # end for key
    }

    #print "MetaUtil::getAllMetaGeneInfo() 2 " . currDateTime() . "<br/>\n";

    if ($print_msg) {
        print "Done MetaUtil::getAllMetaGeneInfo()<br/>\n";
    }

}

###############################################################################
# getAllGeneFna - not used, incomplete
###############################################################################
sub getAllGeneFna {
    my ( $gene_href, $gene_fna_href, $gene_strand_href, $gene_scaf_href, $print_msg ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids( keys %$gene_href );
    my @db_ids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@db_ids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving fna for database genes ... <br/>\n";
        }

        #Todo future
    }

    if ( scalar(@metaOids) > 0 ) {
        getAllMetaGeneFna( $gene_href, $metaOids_ref, $gene_fna_href, $gene_strand_href, $gene_scaf_href, '', $print_msg );
    }

}

###############################################################################
# getAllMetaGeneFna
###############################################################################
sub getAllMetaGeneFna {
    my ( $gene_href, $metaOids_ref, $gene_fna_href, $gene_strand_href, $gene_scaf_href, $taxon_genes_href, $print_msg ) = @_;

    my @metaOids;
    if ( $metaOids_ref eq '' ) {
        @metaOids = keys %$gene_href;
    } else {
        @metaOids = @$metaOids_ref;
    }

    if ( scalar(@metaOids) > 0 ) {

        #webLog("MetaUtil::getAllMetaGeneFna() Retrieving fna from filesystem genes\n");
        if ($print_msg) {
            print "<p>Retrieving fna from filesystem genes ... <br/>\n";
        }

        my %taxon_genes;
        if ( $taxon_genes_href eq '' ) {
            %taxon_genes = getOrganizedTaxonGenes(@metaOids);
        } else {
            %taxon_genes = %$taxon_genes_href;
        }

        my %gene_info_h;
        my %scaf_id_h;
        getAllMetaGeneInfo( $gene_href, $metaOids_ref, \%gene_info_h, \%scaf_id_h, \%taxon_genes );

        #print Dumper(\%scaf_id_h)."<br/>\n";
        #webLog("MetaUtil::getAllMetaGeneFna() scaf_id_h: \n");
        #my $dumperScafLine = Dumper(\%scaf_id_h);
        #webLog("$dumperScafLine\n");
        #webLog("MetaUtil::getAllMetaGeneFna() gene_info_h: \n");
        #my $dumperGeneLine = Dumper(\%gene_info_h);
        #webLog("$dumperGeneLine\n");

        my $count           = 0;
        my $trunc           = 0;
        my %taxon_scaffolds = getOrganizedTaxonScaffolds( keys %scaf_id_h );
        for my $key ( keys %taxon_scaffolds ) {
            my ( $taxon_oid, $data_type ) = split( / /, $key );
            $taxon_oid = sanitizeInt($taxon_oid);

            my $oid_ref = $taxon_scaffolds{$key};

            #webLog("MetaUtil::getAllMetaGeneFna() taxon_scaffolds $taxon_oid $data_type oid_ref=@$oid_ref\n");
            #print "MetaUtil::getAllMetaGeneFna() taxon_scaffolds $taxon_oid $data_type oid_ref=@$oid_ref\n";
            if ( $oid_ref ne '' && scalar(@$oid_ref) > 0 ) {
                my %scafOid2fna;
                my $hasScaffoldDnaSqliteFile = hasSdbScaffoldDnaFile( $taxon_oid, $data_type );
                if ($hasScaffoldDnaSqliteFile) {
                    if ($print_msg) {
                        print "<p>Retrieving scaffold fna for genome $taxon_oid $data_type ...<br/>\n";
                    }

                    my %dnaFile_scafs = getOrganizedTaxonScaffoldDnaFiles( $taxon_oid, $data_type, @$oid_ref );
                    for my $dnaFile ( keys %dnaFile_scafs ) {
                        my $file_oids_ref = $dnaFile_scafs{$dnaFile};
                        my $cnt0          = scalar(@$file_oids_ref);
                        if ( $cnt0 == 0 ) {
                            next;
                        }

                        my $cnt1         = 0;
                        my $file_oid_str = '';
                        for my $file_oid (@$file_oids_ref) {
                            if ($file_oid_str) {
                                $file_oid_str .= ", '" . $file_oid . "'";
                            } else {
                                $file_oid_str = "'" . $file_oid . "'";
                            }
                            $cnt1++;
                            if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                                my $sql = "select scaffold_oid, fna from scaffold_fna where scaffold_oid in ($file_oid_str)";
                                my (%scafDNAs) =
                                  fetchScaffoldDnaForTaxonFromSqlite( $taxon_oid, $data_type, $dnaFile, $sql );
                                if ( scalar( keys %scafDNAs ) > 0 ) {
                                    foreach my $s_oid ( keys %scafDNAs ) {
                                        my $workspace_id = "$taxon_oid $data_type $s_oid";
                                        $scafOid2fna{$workspace_id} = $scafDNAs{$s_oid};
                                    }
                                }
                                $file_oid_str = '';
                            }
                        }
                    }

                } else {
                    if ($print_msg) {
                        print "<p>No sqlite DNA file, retrieving fna from zip file for genome $taxon_oid $data_type<br/>\n";
                    }
                    webLog("MetaUtil::getAllMetaGeneFna() no sqlite DNA file for genome $taxon_oid $data_type\n");

                    my $tag = "fna";
                    doFlieReading( $print_msg, 1, $taxon_oid, $data_type, $oid_ref, $tag, \%scafOid2fna );
                }

                #webLog("MetaUtil::getAllMetaGeneFna() scafOid2fna: \n");
                #my $dumperLine = Dumper(\%scafOid2fna);
                #webLog("$dumperLine\n");

                my $gene_oids_ref = $taxon_genes{$key};
                for my $g_oid (@$gene_oids_ref) {
                    my $workspace_id = "$taxon_oid $data_type $g_oid";
                    my (
                        $locus_type, $locus_tag,    $gene_display_name, $start_coord, $end_coord,
                        $strand,     $scaffold_oid, $tid2,              $dtype2
                      )
                      = split( /\t/, $gene_info_h{$workspace_id} );
                    my $workspace_s_id = "$taxon_oid $data_type $scaffold_oid";
                    my $line           = $scafOid2fna{$workspace_s_id};

                    #webLog("MetaUtil::getAllMetaGeneFna() workspace_s_id=$workspace_s_id\n");
                    #webLog("MetaUtil::getAllMetaGeneFna() line=$line\n");

                    my $gene_seq = "";
                    if ( $strand eq '-' ) {
                        $gene_seq = WebUtil::getSequence( $line, $end_coord, $start_coord );
                    } else {
                        $gene_seq = WebUtil::getSequence( $line, $start_coord, $end_coord );
                    }
                    $gene_fna_href->{$workspace_id}    = $gene_seq;
                    $gene_strand_href->{$workspace_id} = $strand;
                    $gene_scaf_href->{$workspace_id}   = $scaffold_oid;
                    $count++;
                }
            }
        }    # end for key
    }

    #print "MetaUtil::getAllMetaGeneFna() 2 " . currDateTime() . "<br/>\n";
}

###############################################################################
# getAllGeneFaa - not used, incomplete
###############################################################################
sub getAllGeneFaa {
    my ( $gene_href, $gene_faa_href, $print_msg ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids( keys %$gene_href );
    my @db_ids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@db_ids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving faa for database genes ... <br/>\n";
        }

        #Todo future
    }

    if ( scalar(@metaOids) > 0 ) {
        getAllMetaGeneFaa( $gene_href, $metaOids_ref, $gene_faa_href, '', $print_msg );
    }

}

###############################################################################
# getAllMetaGeneFaa
###############################################################################
sub getAllMetaGeneFaa {
    my ( $gene_href, $metaOids_ref, $gene_faa_href, $taxon_genes_href, $print_msg ) = @_;

    my @metaOids;
    if ( $metaOids_ref eq '' ) {
        @metaOids = keys %$gene_href;
    } else {
        @metaOids = @$metaOids_ref;
    }

    if ( scalar(@metaOids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving faa from filesystem genes ... <br/>\n";
        }

        my %taxon_genes;
        if ( $taxon_genes_href eq '' ) {
            %taxon_genes = getOrganizedTaxonGenes(@metaOids);
        } else {
            %taxon_genes = %$taxon_genes_href;
        }

        my $count = 0;
        my $trunc = 0;
        for my $key ( keys %taxon_genes ) {
            my ( $taxon_oid, $data_type ) = split( / /, $key );
            $taxon_oid = sanitizeInt($taxon_oid);

            #print "MetaUtil::getAllMetaGeneFaa() $taxon_oid $data_type " . currDateTime() . "<br/>\n";

            my $oid_ref = $taxon_genes{$key};
            if ( $oid_ref ne '' && scalar(@$oid_ref) > 0 ) {
                my $hasGeneAASqliteFile = hasSdbGeneAAFile( $taxon_oid, $data_type );

                if ($hasGeneAASqliteFile) {
                    if ($print_msg) {
                        print "<p>Retrieving faa for genome $taxon_oid $data_type ...<br/>\n";
                    }

                    my %aaFile_genes = getOrganizedTaxonGeneAAFiles( $taxon_oid, $data_type, @$oid_ref );
                    for my $aaFile ( keys %aaFile_genes ) {
                        my $file_oids_ref = $aaFile_genes{$aaFile};
                        my $cnt0          = scalar(@$file_oids_ref);
                        if ( $cnt0 == 0 ) {
                            next;
                        }

                        my $cnt1         = 0;
                        my $file_oid_str = '';
                        for my $file_oid (@$file_oids_ref) {
                            if ($file_oid_str) {
                                $file_oid_str .= ", '" . $file_oid . "'";
                            } else {
                                $file_oid_str = "'" . $file_oid . "'";
                            }
                            $cnt1++;
                            if ( ( $cnt1 % 20000 ) == 0 || ( $cnt1 == $cnt0 ) ) {
                                my $sql = "select gene_oid, faa from gene_faa where gene_oid in ($file_oid_str)";
                                my (%geneAAs) = fetchGeneAAForTaxonFromSqlite( $taxon_oid, $data_type, $aaFile, $sql );

                                #print Dumper(\%geneAAs)."<br/>\n";
                                if ( scalar( keys %geneAAs ) > 0 ) {
                                    foreach my $gene_oid ( keys %geneAAs ) {
                                        my $workspace_id = "$taxon_oid $data_type $gene_oid";
                                        $gene_faa_href->{$workspace_id} = $geneAAs{$gene_oid};
                                        $count++;
                                    }
                                }
                                $file_oid_str = '';
                            }
                        }
                    }
                } else {
                    if ($print_msg) {
                        print "<p>No sqlite AA file, retrieving faa from zip file for genome $taxon_oid $data_type<br/>\n";
                    }
                    webLog("MetaUtil::getAllMetaGeneAA() no sqlite AA file for genome $taxon_oid $data_type\n");

                    my $tag = "faa";
                    doFlieReading( $print_msg, 1, $taxon_oid, $data_type, $oid_ref, $tag, $gene_faa_href, $gene_href );
                }

            }

        }    # end for key
    }

    #print "MetaUtil::getAllMetaGeneFaa() 2 " . currDateTime() . "<br/>\n";
}

sub doFlieReading {
    my ( $print_msg, $needUntaint, $taxon_oid, $data_type, $oid_ref, $tag, $result_info_href, $gene_href, $scaf_href ) = @_;

    my %fileName2oids_h = getFileName2OidsHash( $taxon_oid, $data_type, $tag, $oid_ref );

    #print "MetaUtil::doFlieReading() filename gathered " . currDateTime() . "<br/>\n";

    my $line_no = 0;
    for my $fname ( keys %fileName2oids_h ) {
        my $zip_name = $mer_data_dir . "/$taxon_oid" . "/" . $data_type . "/" . $tag . "/" . $fname;
        if ( !( -e $zip_name ) ) {
            if ($print_msg) {
                print "<p>Cannot find $zip_name\n";
            }
            next;
        }

        my $ids_ref = $fileName2oids_h{$fname};
        if ( scalar(@$ids_ref) > 0 && scalar(@$ids_ref) > $block_size ) {
            my $cnt   = 0;
            my @batch = ();
            for my $gid (@$ids_ref) {
                push( @batch, $gid );
                $cnt++;

                if ( $cnt % $block_size == 0 || $cnt == scalar(@$ids_ref) ) {
                    if ( $tag eq "gene" ) {
                        $line_no = processUnzipGeneInfoFlie(
                            $line_no,  $print_msg, $needUntaint,      $taxon_oid, $data_type, $tag,
                            $zip_name, \@batch,    $result_info_href, $gene_href, $scaf_href
                        );
                    } elsif ( $tag eq "gene_product" ) {
                        $line_no = processUnzipGeneProductFlie(
                            $line_no, $print_msg, $needUntaint, $taxon_oid,        $data_type,
                            $tag,     $zip_name,  \@batch,      $result_info_href, $gene_href
                        );
                    } elsif ( $tag eq "faa" ) {
                        $line_no = processUnzipGeneFaaFlie(
                            $line_no, $print_msg, $needUntaint, $taxon_oid,        $data_type,
                            $tag,     $zip_name,  \@batch,      $result_info_href, $gene_href
                        );
                    } elsif ( $tag eq "fna" ) {
                        $line_no = processUnzipScaffoldFnaFlie(
                            $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type,
                            $tag,     $zip_name,  \@batch,      $result_info_href
                        );
                    } elsif ( $tag eq "scaffold_genes" ) {
                        $line_no = processUnzipScaffoldGenesFlie(
                            $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type,
                            $tag,     $zip_name,  \@batch,      $result_info_href
                        );
                    } elsif ( $tag eq "scaffold_stats" ) {
                        $line_no = processUnzipScaffoldStatsFlie(
                            $line_no, $print_msg, '',      $taxon_oid, $data_type,
                            $tag,     $zip_name,  \@batch, $result_info_href
                        );
                    }
                    @batch = ();
                }

            }
        } else {
            if ( $tag eq "gene" ) {
                $line_no = processUnzipGeneInfoFlie(
                    $line_no,  $print_msg, $needUntaint,      $taxon_oid, $data_type, $tag,
                    $zip_name, $ids_ref,   $result_info_href, $gene_href, $scaf_href
                );
            } elsif ( $tag eq "gene_product" ) {
                $line_no = processUnzipGeneProductFlie(
                    $line_no, $print_msg, $needUntaint, $taxon_oid,        $data_type,
                    $tag,     $zip_name,  $ids_ref,     $result_info_href, $gene_href
                );
            } elsif ( $tag eq "faa" ) {
                $line_no = processUnzipGeneFaaFlie(
                    $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type,
                    $tag,     $zip_name,  $ids_ref,     $result_info_href
                );
            } elsif ( $tag eq "fna" ) {
                $line_no = processUnzipScaffoldFnaFlie(
                    $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type,
                    $tag,     $zip_name,  $ids_ref,     $result_info_href
                );
            } elsif ( $tag eq "scaffold_genes" ) {
                $line_no = processUnzipScaffoldGenesFlie(
                    $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type,
                    $tag,     $zip_name,  $ids_ref,     $result_info_href
                );
            } elsif ( $tag eq "scaffold_stats" ) {
                $line_no =
                  processUnzipScaffoldStatsFlie( $line_no, $print_msg, '', $taxon_oid, $data_type, $tag, $zip_name, $ids_ref,
                    $result_info_href );
            }
        }
    }

    #print "MetaUtil::doFlieReading() finished reading filenames " . currDateTime() . "<br/>\n";

}

sub getFileName2OidsHash {
    my ( $taxon_oid, $data_type, $tag, $oid_ref ) = @_;

    my %fileName2oids_h;

    my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $data_type . "/taxon_hash.txt";
    if ( -e $hash_file ) {
        my $fh2 = newReadFileHandle($hash_file);
        if ( !$fh2 ) {
            next;
        }

        my $max_lot_cnt = 0;
        while ( my $line1 = $fh2->getline() ) {
            chomp($line1);

            my ( $a0, $a1, $a2, @a3 ) = split( /\,/, $line1 );
            if ( $a0 eq $tag && isInt($a2) ) {
                $max_lot_cnt = $a2;
                last;
            }
        }
        close $fh2;

        $max_lot_cnt = sanitizeInt($max_lot_cnt);

        #print "MetaUtil::getFileName2OidsHash() tag: $tag, max_cnt: $max_lot_cnt " . currDateTime() . "<br/>\n";

        if ( $max_lot_cnt == 1 ) {
            my $file_name = $tag . "_1.zip";
            $fileName2oids_h{$file_name} = $oid_ref;
        } else {
            for my $id (@$oid_ref) {
                my $code = HashUtil::hash_mod( $id, $max_lot_cnt );

                #print "MetaUtil::getFileName2OidsHash() code: $code<br/>\n";
                my $file_name = $tag . "_" . $code . ".zip";
                if ( $fileName2oids_h{$file_name} ) {
                    my $ids_ref = $fileName2oids_h{$file_name};
                    push( @$ids_ref, $id );
                } else {
                    my @ids = ($id);
                    $fileName2oids_h{$file_name} = \@ids;
                }
            }
        }

    }

    return %fileName2oids_h;
}

sub processUnzipGeneInfoFlie {
    my (
        $line_no,  $print_msg, $needUntaint,      $taxon_oid, $data_type, $tag,
        $zip_name, $ids_ref,   $result_info_href, $gene_href, $scaf_href
      )
      = @_;

    my @ids = @$ids_ref;

    my $len3     = length($zip_name) - 3;
    my $sdb_name = "";
    if ( $len3 > 0 ) {
        $sdb_name = substr( $zip_name, 0, $len3 ) . "sdb";
    }

    if ( $sdb_name && ( -e $sdb_name ) && ( -s $sdb_name > $MIN_FILE_SIZE ) ) {
        if ($print_msg) {
            print "<p>Retrieving gene information ...\n";
        }
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 =
            "select gene_oid, locus_type, locus_tag, product_name, "
          . "start_coord, end_coord, strand, scaffold_oid from gene where gene_oid in ('";
        $sql3 .= join( "', '", @ids ) . "')";
        my $sth = $dbh3->prepare($sql3);
        $sth->execute();
        for ( ; ; ) {
            my ( $oid, @rest ) = $sth->fetchrow_array();
            last if !$oid;
            my $workspace_id = "$taxon_oid $data_type $oid";

            if ( defined($gene_href) && $gene_href ne '' ) {
                if ( $gene_href->{$workspace_id} ) {
                    $result_info_href->{$workspace_id} = join( "\t", @rest );
                    if ( defined($scaf_href) && $scaf_href ne '' ) {
                        if ( $data_type eq 'assembled' && scalar(@rest) >= 7 ) {
                            my $scaf2 = $rest[6];
                            if ($scaf2) {
                                my $ws_scaf_id = "$taxon_oid $data_type $scaf2";
                                $scaf_href->{$ws_scaf_id} = 1;
                            }
                        }
                    }
                }
            }
        }
        $sth->finish();
        $dbh3->disconnect();
        return;
    }

    if ($print_msg) {
        print "<p>Processing $zip_name listed file size: " . scalar(@$ids_ref) . "<br/>\n";
    }

    WebUtil::unsetEnvPath();

    my $ids_str = join( ' ', @ids );
    if ($needUntaint) {
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );
    }
    my $cmd = "/usr/bin/unzip -C -p $zip_name $ids_str";

    #print "MetaUtil::processUnzipGeneInfoFlie() processing cmd: $cmd, ids_str: $ids_str<br/>\n";
    my $fh = newCmdFileHandle( $cmd, $tag );
    if ( !$fh ) {
        WebUtil::resetEnvPath();
        return $line_no;
    }

    #print "MetaUtil::processUnzipGeneInfoFlie() $zip_name opened<br/>\n";

    while ( my $line = $fh->getline() ) {

        #print "MetaUtil::processUnzipGeneInfoFlie() line: $line<br/>\n";
        chomp $line;
        $line_no++;
        if ($print_msg) {
            if ( ( $line_no % 10000 ) == 0 ) {
                print ".";
            }
            if ( ( $line_no % 1800000 ) == 0 ) {
                print "<br/>\n";
            }
        }
        my ( $oid, @rest ) = split( /\t/, $line );
        my $workspace_id = "$taxon_oid $data_type $oid";

        #for detailed gene info with key as workspace id
        if ( defined($gene_href) && $gene_href ne '' ) {
            if ( $gene_href->{$workspace_id} ) {
                $result_info_href->{$workspace_id} = join( "\t", @rest );
                if ( defined($scaf_href) && $scaf_href ne '' ) {
                    if ( $data_type eq 'assembled' && scalar(@rest) >= 7 ) {
                        my $scaf2 = $rest[6];
                        if ($scaf2) {
                            my $ws_scaf_id = "$taxon_oid $data_type $scaf2";
                            $scaf_href->{$ws_scaf_id} = 1;
                        }
                    }
                }
            }
        }

        #for search results with key as workspace id
        else {
            for my $id (@ids) {
                if ( lc($id) eq lc($oid) ) {
                    $result_info_href->{$workspace_id} = join( "\t", @rest );
                    last;
                }
            }
        }

    }    # end while line
    close $fh;

    #print "MetaUtil::processUnzipGeneInfoFlie() $zip_name closed<br/>\n";

    WebUtil::resetEnvPath();

    return $line_no;
}

sub processUnzipGeneProductFlie {
    my (
        $line_no, $print_msg, $needUntaint, $taxon_oid,        $data_type,
        $tag,     $zip_name,  $ids_ref,     $result_info_href, $gene_href
      )
      = @_;

    my @ids = @$ids_ref;

    my $len3     = length($zip_name) - 3;
    my $sdb_name = "";
    if ( $len3 > 0 ) {
        $sdb_name = substr( $zip_name, 0, $len3 ) . "sdb";
    }

    if ( $sdb_name && ( -e $sdb_name ) && ( -s $sdb_name > $MIN_FILE_SIZE ) ) {
        if ($print_msg) {
            print "<p>Retrieving gene information ...\n";
        }
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = "select gene_oid, gene_display_name from gene where gene_oid in ('";
        $sql3 .= join( "', '", @ids ) . "')";
        my $sth = $dbh3->prepare($sql3);
        $sth->execute();
        for ( ; ; ) {
            my ( $oid, $prod_name ) = $sth->fetchrow_array();
            last if !$oid;

            if ( !$prod_name ) {
                $prod_name = "hypothetical protein";
            }
            my $workspace_id = "$taxon_oid $data_type $oid";

            if ( defined($gene_href) && $gene_href ne '' ) {
                if ( $gene_href->{$workspace_id} ) {
                    $result_info_href->{$workspace_id} = $prod_name;
                }
            }
        }
        $sth->finish();
        $dbh3->disconnect();
        return;
    }

    if ($print_msg) {
        print "<p>Processing $zip_name listed file size: " . scalar(@$ids_ref) . "<br/>\n";
    }

    my $ids_str = join( ' ', @ids );
    if ($needUntaint) {
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );
    }
    my $cmd = "/usr/bin/unzip -C -p $zip_name $ids_str";

    #print "MetaUtil::processUnzipGeneProductFlie() processing cmd: $cmd, ids_str: $ids_str<br/>\n";

    WebUtil::unsetEnvPath();

    my $fh = newCmdFileHandle( $cmd, $tag );
    if ( !$fh ) {
        WebUtil::resetEnvPath();
        return $line_no;
    }

    #print "MetaUtil::processUnzipGeneProductFlie() $zip_name opened<br/>\n";

    while ( my $line = $fh->getline() ) {

        #print "MetaUtil::processUnzipGeneProductFlie() line: $line<br/>\n";
        chomp $line;
        $line_no++;
        if ($print_msg) {
            if ( ( $line_no % 10000 ) == 0 ) {
                print ".";
            }
            if ( ( $line_no % 1800000 ) == 0 ) {
                print "<br/>\n";
            }
        }

        my ( $oid, $prod_name, $source ) = split( /\t/, $line );
        my $workspace_id = "$taxon_oid $data_type $oid";

        #for detailed gene info with key as workspace id
        if ( defined($gene_href) && $gene_href ne '' ) {
            if ( $gene_href->{$workspace_id} ) {
                if ( blankStr($prod_name) ) {
                    $prod_name = "hypothetical protein";
                }
                $result_info_href->{$workspace_id} = $prod_name;
            }
        }

        #for search results with key as workspace id
        else {
            for my $id (@ids) {
                if ( lc($id) eq lc($oid) ) {
                    if ( blankStr($prod_name) ) {
                        $prod_name = "hypothetical protein";
                    }
                    $result_info_href->{$workspace_id} = $prod_name;
                    last;
                }
            }
        }

    }    # end while line
    close $fh;

    WebUtil::resetEnvPath();

    return $line_no;
}

#should not used any longer
sub processUnzipScaffoldGenesFlie {
    my ( $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type, $tag, $zip_name, $ids_ref, $result_info_href ) = @_;

    if ($print_msg) {
        print "<p>Processing $zip_name listed file size: " . scalar(@$ids_ref) . "<br/>\n";
    }

    WebUtil::unsetEnvPath();

    my @ids = @$ids_ref;
    my $ids_str = join( ' ', @ids );
    if ($needUntaint) {
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );
    }
    my $cmd = "/usr/bin/unzip -C -c $zip_name $ids_str";

    #print "MetaUtil::processUnzipScaffoldFnaFlie() processing cmd: $cmd, ids_str: $ids_str<br/>\n";

    my $fh = newCmdFileHandle( $cmd, $tag );
    if ( !$fh ) {
        WebUtil::resetEnvPath();
        return $line_no;
    }

    #print "MetaUtil::processUnzipScaffoldFnaFlie() $zip_name opened<br/>\n";

    my $memberFileName;
    while ( my $line = $fh->getline() ) {

        #print "MetaUtil::processUnzipScaffoldFnaFlie() line: $line<br/>\n";
        chomp $line;
        $line_no++;
        if ($print_msg) {
            if ( ( $line_no % 10000 ) == 0 ) {
                print ".";
            }
            if ( ( $line_no % 1800000 ) == 0 ) {
                print "<br/>\n";
            }
        }

        next if ( $line eq '' );
        next if ( blankStr($line) );
        $line = strTrim($line);
        if ( $line =~ /^inflating/ || $line =~ /^Archive/ ) {
            next;
        }

        if ( $line =~ /^extracting/i ) {
            my @splitVals = split( /:/, $line );
            if ( scalar(@splitVals) == 2 ) {
                $memberFileName = $splitVals[1];
                $memberFileName = strTrim($memberFileName);
            }
        } else {
            if ( $memberFileName ne '' && !blankStr($memberFileName) ) {
                for my $id (@ids) {
                    if ( lc($id) eq lc($memberFileName) ) {
                        my $workspace_id = "$taxon_oid $data_type $memberFileName";
                        $result_info_href->{$workspace_id} = $line;
                        $memberFileName = '';
                        last;
                    }
                }
            }
        }
    }    # end while line
    close $fh;

    WebUtil::resetEnvPath();

    return $line_no;
}

sub processUnzipScaffoldFnaFlie {
    my ( $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type, $tag, $zip_name, $ids_ref, $result_info_href ) = @_;

    if ($print_msg) {
        print "<p>Processing $zip_name listed file size: " . scalar(@$ids_ref) . "<br/>\n";
    }

    WebUtil::unsetEnvPath();

    my @ids = @$ids_ref;
    my $ids_str = join( ' ', @ids );
    if ($needUntaint) {
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );
    }
    my $cmd = "/usr/bin/unzip -C -c $zip_name $ids_str";

    #print "MetaUtil::processUnzipScaffoldFnaFlie() processing cmd: $cmd, ids_str: $ids_str<br/>\n";

    my $fh = newCmdFileHandle( $cmd, $tag );
    if ( !$fh ) {
        WebUtil::resetEnvPath();
        return $line_no;
    }

    #print "MetaUtil::processUnzipScaffoldFnaFlie() $zip_name opened<br/>\n";

    my $memberFileName;
    while ( my $line = $fh->getline() ) {

        #print "MetaUtil::processUnzipScaffoldFnaFlie() line: $line<br/>\n";
        chomp $line;
        $line_no++;
        if ($print_msg) {
            if ( ( $line_no % 10000 ) == 0 ) {
                print ".";
            }
            if ( ( $line_no % 1800000 ) == 0 ) {
                print "<br/>\n";
            }
        }

        next if ( $line eq '' );
        next if ( blankStr($line) );
        $line = strTrim($line);
        if ( $line =~ /^inflating/ || $line =~ /^Archive/ ) {
            next;
        }

        if ( $line =~ /^extracting/i ) {
            my @splitVals = split( /:/, $line );
            if ( scalar(@splitVals) == 2 ) {
                $memberFileName = $splitVals[1];
                $memberFileName = strTrim($memberFileName);
            }
        } else {
            if ( $memberFileName ne '' && !blankStr($memberFileName) ) {
                for my $id (@ids) {
                    if ( lc($id) eq lc($memberFileName) ) {
                        my $workspace_id = "$taxon_oid $data_type $memberFileName";
                        $result_info_href->{$workspace_id} = $line;
                        $memberFileName = '';
                        last;
                    }
                }
            }
        }
    }    # end while line
    close $fh;

    WebUtil::resetEnvPath();

    return $line_no;
}

sub processUnzipGeneFaaFlie {
    my ( $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type, $tag, $zip_name, $ids_ref, $result_info_href ) = @_;

    my @ids = @$ids_ref;

    my $len3     = length($zip_name) - 3;
    my $sdb_name = "";
    if ( $len3 > 0 ) {
        $sdb_name = substr( $zip_name, 0, $len3 ) . "sdb";
    }

    if ( $sdb_name && ( -e $sdb_name ) && ( -s $sdb_name > $MIN_FILE_SIZE ) ) {
        if ($print_msg) {
            print "<p>Retrieving gene information ...\n";
        }
        my $dbh3 = WebUtil::sdbLogin($sdb_name)
          or return "";

        my $sql3 = "select gene_oid, faa from gene_faa where gene_oid in ('";
        $sql3 .= join( "', '", @ids ) . "')";
        my $sth = $dbh3->prepare($sql3);
        $sth->execute();
        for ( ; ; ) {
            my ( $oid, $line ) = $sth->fetchrow_array();
            last if !$oid;
            my $workspace_id = "$taxon_oid $data_type $oid";

            $result_info_href->{$workspace_id} = $line;
        }
        $sth->finish();
        $dbh3->disconnect();
        return;
    }

    if ($print_msg) {
        print "<p>Processing $zip_name listed file size: " . scalar(@$ids_ref) . "<br/>\n";
    }

    WebUtil::unsetEnvPath();

    my $ids_str = join( ' ', @ids );
    if ($needUntaint) {
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );
    }
    my $cmd = "/usr/bin/unzip -C -c $zip_name $ids_str";

    #print "MetaUtil::processUnzipGeneFaaFlie() processing cmd: $cmd, ids_str: $ids_str<br/>\n";

    my $fh = newCmdFileHandle( $cmd, $tag );
    if ( !$fh ) {
        WebUtil::resetEnvPath();
        return $line_no;
    }

    #print "MetaUtil::processUnzipGeneFaaFlie() $zip_name opened<br/>\n";

    my $memberFileName;
    while ( my $line = $fh->getline() ) {

        #print "MetaUtil::processUnzipGeneFaaFlie() line: $line<br/>\n";
        chomp $line;
        $line_no++;
        if ($print_msg) {
            if ( ( $line_no % 10000 ) == 0 ) {
                print ".";
            }
            if ( ( $line_no % 1800000 ) == 0 ) {
                print "<br/>\n";
            }
        }

        next if ( $line eq '' );
        next if ( blankStr($line) );
        $line = strTrim($line);
        if ( $line =~ /^inflating/ || $line =~ /^Archive/ ) {
            next;
        }

        if ( $line =~ /^extracting/i ) {
            my @splitVals = split( /:/, $line );
            if ( scalar(@splitVals) == 2 ) {
                $memberFileName = $splitVals[1];
                $memberFileName = strTrim($memberFileName);
            }
        } else {
            if ( $memberFileName ne '' && !blankStr($memberFileName) ) {
                for my $id (@ids) {
                    if ( lc($id) eq lc($memberFileName) ) {
                        my $workspace_id = "$taxon_oid $data_type $memberFileName";
                        $result_info_href->{$workspace_id} = $line;
                        $memberFileName = '';
                        last;
                    }
                }
            }
        }
    }    # end while line
    close $fh;

    WebUtil::resetEnvPath();

    return $line_no;
}

###############################################################################
# getAllScaffoldInfo
###############################################################################
sub getAllScaffoldInfo {
    my ( $scaf_href, $scaf_info_href, $needLineage, $print_msg ) = @_;

    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids( keys %$scaf_href );
    my @db_ids   = @$dbOids_ref;
    my @metaOids = @$metaOids_ref;

    if ( scalar(@db_ids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving scaffold informations from database ... <br/>\n";
        }

        my $dbh = dbLogin();
        my $db_str = OracleUtil::getNumberIdsInClause( $dbh, @db_ids );
        my $sql =
            "select s.scaffold_oid, ss.seq_length, "
          . "ss.gc_percent, ss.count_total_gene, "
          . "s.read_depth from scaffold s, scaffold_stats ss "
          . "where s.scaffold_oid in ($db_str) "
          . "and s.scaffold_oid = ss.scaffold_oid ";
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $id2, $scaf_len, $scaf_gc, $scaf_gene_cnt, $depth ) = $cur->fetchrow();
            last if !$id2;

            #if ( ! $depth ) {
            #   $depth = 1;
            #}
            my $scaf_line = "$scaf_len\t$scaf_gc\t$scaf_gene_cnt\t$depth\t\t\t";
            if ($needLineage) {
                #the last three \t for lineage, percentage and rank
                $scaf_line .= "\t\t\t";
            }
            $scaf_info_href->{$id2} = $scaf_line;
        }
        $cur->finish();
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $db_str =~ /gtt_num_id/i );        
    }
    #print "MetaUtil::getAllScaffoldInfo() 1 " . currDateTime() . "<br/>\n";

    if ( scalar(@metaOids) > 0 ) {
        getAllMetaScaffoldInfo( $scaf_href, \@metaOids, $scaf_info_href, $needLineage, $print_msg );
    }
    #print "MetaUtil::getAllScaffoldInfo() 2 " . currDateTime() . "<br/>\n";
}

###############################################################################
# getAllMetaScaffoldInfo
###############################################################################
sub getAllMetaScaffoldInfo {
    my ( $scaf_href, $metaOids_ref, $scaf_info_href, $needLineage, $print_msg ) = @_;

    #print "MetaUtil::getAllMetaScaffoldInfo() 1 " . currDateTime() . "<br/>\n";

    my @metaOids;
    if ( $metaOids_ref eq '' ) {
        @metaOids = keys %$scaf_href;
    } else {
        @metaOids = @$metaOids_ref;
    }

    if ( scalar(@metaOids) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving scaffold information from filesystem ... <br/>\n";
        }

        my %taxon_scaffolds = getOrganizedTaxonScaffolds(@metaOids);

        for my $key ( keys %taxon_scaffolds ) {
            my ( $taxon_oid, $data_type ) = split( / /, $key );

            #print "MetaUtil::getAllMetaScaffoldInfo() $taxon_oid $data_type " . currDateTime() . "<br/>\n";
            $taxon_oid = sanitizeInt($taxon_oid);

            if ($print_msg) {
                print "<p>Retrieving scaffold information for genome $taxon_oid $data_type ...<br/>\n";
            }

            my $oid_ref = $taxon_scaffolds{$key};
            if ( $oid_ref ne '' && scalar(@$oid_ref) > 0 ) {

                #stats
                my %scaffold_stats_h = getScaffoldStatsForTaxonScaffolds( $taxon_oid, $data_type, $oid_ref, $print_msg );

                #print Dumper(\%scaffold_stats_h);
                #depth
                my %scaffold_depth_h = getScaffoldDepthForTaxonScaffolds( $taxon_oid, $data_type, $oid_ref, $print_msg );

                #print Dumper(\%scaffold_depth_h);

                #lineage
                my %scaffold_lineage_h;
                if ($needLineage) {
                    %scaffold_lineage_h =
                      getScaffoldLineageForTaxonScaffolds( $taxon_oid, $data_type, $oid_ref, $print_msg );
                }

                #print Dumper(\%scaffold_lineage_h);

                #info
                if ( scalar( keys %scaffold_stats_h ) > 0 ) {
                    foreach my $workspace_id ( keys %scaffold_stats_h ) {

                        #for detailed scaffold info
                        if ( defined($scaf_href) && $scaf_href ne '' ) {

                     #print "getAllMetaScaffoldInfo() workspace_id in scaf_href: " . $scaf_href->{$workspace_id} . "<br/>\n";
                            if ( $scaf_href->{$workspace_id} ) {
                                my $scaf_depth = $scaffold_depth_h{$workspace_id};
                                if ( !$scaf_depth && $data_type eq 'assembled' ) {
                                    $scaf_depth = 1;
                                }
                                my $scaf_info_line = $scaffold_stats_h{$workspace_id} . "\t$scaf_depth";

                                if ($needLineage) {
                                    my $scaf_lineage = $scaffold_lineage_h{$workspace_id};
                                    $scaf_info_line .= "\t$scaf_lineage";
                                }
                                $scaf_info_href->{$workspace_id} = $scaf_info_line;

                            #print "getAllMetaScaffoldInfo() workspace_id: $workspace_id, scaf info: $scaf_info_line<br/>\n";
                            }
                        }
                    }
                }

            }

        }    # end for key

    }

    #print "MetaUtil::getAllMetaScaffoldInfo() 2 " . currDateTime() . "<br/>\n";

}

###############################################################################
# getScaffoldDepthForTaxonScaffolds
###############################################################################
sub getScaffoldDepthForTaxonScaffolds {
    my ( $taxon_oid, $data_type, $oids_ref, $print_msg ) = @_;

    my %scaffold_depth_h;

    my $singleScaffoldDepthFile = getSingleSdbScaffoldDepthFile( $taxon_oid, $data_type );

#print "getScaffoldDepthForTaxonScaffolds() singleScaffoldDepthFile $singleScaffoldDepthFile for genome $taxon_oid $data_type ...<br/>\n";

    if ($singleScaffoldDepthFile) {
        if ($print_msg) {
            print "<p>Retrieving scaffold depth for genome $taxon_oid $data_type ...<br/>\n";
        }

        my $cnt0 = scalar(@$oids_ref);

#print "getScaffoldDepthForTaxonScaffolds() $scaffoldDepthFile with $cnt0 scaffolds for genome $taxon_oid $data_type ...<br/>\n";
        if ( $cnt0 == 0 ) {
            next;
        }

        my $cnt1     = 0;
        my $oids_str = '';
        for my $oid (@$oids_ref) {
            if ($oids_str) {
                $oids_str .= ", '" . $oid . "'";
            } else {
                $oids_str = "'" . $oid . "'";
            }
            $cnt1++;
            if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                my $sql = "select scaffold_oid, depth from scaffold_depth where scaffold_oid in ($oids_str)";
                my (%scaffoldDepths) =
                  fetchScaffoldDepthForTaxonFromSqlite( $taxon_oid, $data_type, $singleScaffoldDepthFile, $sql );
                if ( scalar( keys %scaffoldDepths ) > 0 ) {
                    foreach my $key ( keys %scaffoldDepths ) {
                        my $workspace_id = "$taxon_oid $data_type $key";
                        $scaffold_depth_h{$workspace_id} = $scaffoldDepths{$key};
                    }
                }
                $oids_str = '';
            }
        }    #end of for scaffoldDepthFile

    } else {
        #should not used any longer
        if ($print_msg) {
            print
"<p>No sqlite scaffold depth file, retrieving scaffold depth from zip file for genome $taxon_oid $data_type<br/>\n";
        }
        webLog(
            "MetaUtil::getScaffoldDepthForTaxonScaffolds() no sqlite scaffold depth file for genome $taxon_oid $data_type\n"
        );

        my $depth_zip_name = $mer_data_dir . "/$taxon_oid/" . $data_type . "/scaffold_depth.zip";
        if ( !( -e $depth_zip_name ) ) {
            $depth_zip_name = $mer_data_dir . "/$taxon_oid/" . $data_type . "/scaffold_stats/scaffold_depth.zip";
        }
        if ( -e $depth_zip_name ) {
            my $tag     = "depth";
            my $line_no = 0;
            if ( scalar(@$oids_ref) > $block_size ) {
                my $cnt0  = scalar(@$oids_ref);
                my $cnt   = 0;
                my @batch = ();
                for my $oid (@$oids_ref) {
                    push( @batch, $oid );
                    $cnt++;

                    if ( $cnt % $block_size == 0 || $cnt == $cnt0 ) {
                        $line_no = processUnzipScaffoldDepthFlie(
                            $line_no,        $print_msg, '', $taxon_oid, $data_type, $tag,
                            $depth_zip_name, \@batch,    \%scaffold_depth_h
                        );
                        @batch = ();
                    }
                }
            } else {
                $line_no = processUnzipScaffoldDepthFlie(
                    $line_no,        $print_msg, '', $taxon_oid, $data_type, $tag,
                    $depth_zip_name, $oids_ref,  \%scaffold_depth_h
                );
            }
        }
    }

    return %scaffold_depth_h;
}

#should not used any longer
sub processUnzipScaffoldDepthFlie {
    my ( $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type, $tag, $zip_name, $ids_ref, $scaffold_depth_h ) = @_;

    if ($print_msg) {
        print "<p>Processing $zip_name listed file size: " . scalar(@$ids_ref) . "<br/>\n";
    }

    WebUtil::unsetEnvPath();

    my $ids_str = join( ' ', @$ids_ref );
    if ($needUntaint) {
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );
    }
    my $cmd = "/usr/bin/unzip -C -p $zip_name $ids_str";

    #print "MetaUtil::processUnzipScaffoldDepthFlie() processing cmd: $cmd, ids_str: $ids_str<br/>\n";
    my $fh = newCmdFileHandle( $cmd, $tag );
    if ( !$fh ) {
        WebUtil::resetEnvPath();
        return $line_no;
    }

    #print "MetaUtil::processUnzipScaffoldDepthFlie() $zip_name opened<br/>\n";

    while ( my $line = $fh->getline() ) {

        #print "MetaUtil::processUnzipScaffoldDepthFlie() line: $line<br/>\n";
        chomp $line;
        $line_no++;
        if ($print_msg) {
            if ( ( $line_no % 10000 ) == 0 ) {
                print ".";
            }
            if ( ( $line_no % 1800000 ) == 0 ) {
                print "<br/>\n";
            }
        }

        my ( $workspace_id, $n2 ) = split( /\t/, $line );
        if ( $n2 && isNumber($n2) ) {
            my $scaf_depth = floor( $n2 + 0.5 );
            $scaffold_depth_h->{$workspace_id} = $scaf_depth;

         #print "MetaUtil::processUnzipScaffoldDepthFlie() into scaffold_depth_h $workspace_id scaf_depth: $scaf_depth<br/>\n";
        }
    }    # end while line
    close $fh;

    WebUtil::resetEnvPath();

    return $line_no;
}

###############################################################################
# getScaffoldLineageForTaxonScaffolds
###############################################################################
sub getScaffoldLineageForTaxonScaffolds {
    my ( $taxon_oid, $data_type, $oids_ref, $print_msg ) = @_;

    my %scaffold_lineage_h;

    my $singleScaffoldLineageFile = getSingleSdbScaffoldLineageFile( $taxon_oid, $data_type );
    if ($singleScaffoldLineageFile) {
        if ($print_msg) {
            print "<p>Retrieving scaffold lineage for genome $taxon_oid $data_type ...<br/>\n";
        }

        my $cnt0 = scalar(@$oids_ref);
        #print "getScaffoldLineageForTaxonScaffolds() $scaffoldLineageFile with $cnt0 scaffolds for genome $taxon_oid $data_type ...<br/>\n";
        if ( $cnt0 == 0 ) {
            next;
        }

        my $cnt1     = 0;
        my $oids_str = '';
        for my $oid (@$oids_ref) {
            if ($oids_str) {
                $oids_str .= ", '" . $oid . "'";
            } else {
                $oids_str = "'" . $oid . "'";
            }
            $cnt1++;
            if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                my $sql = "select scaffold_oid, lineage, percentage, rank " 
                  . "from contig_lin where scaffold_oid in ($oids_str) ";
                my (%scaffoldLineages) =
                  fetchScaffoldLineageForTaxonFromSqlite( $taxon_oid, $data_type, $singleScaffoldLineageFile, $sql );
                if ( scalar( keys %scaffoldLineages ) > 0 ) {
                    foreach my $key ( keys %scaffoldLineages ) {
                        my $workspace_id = "$taxon_oid $data_type $key";
                        $scaffold_lineage_h{$workspace_id} = $scaffoldLineages{$key};
                    }
                }
                $oids_str = '';
            }
        }

    }

    return %scaffold_lineage_h;
}

###############################################################################
# getScaffoldStatsForTaxonScaffolds
###############################################################################
sub getScaffoldStatsForTaxonScaffolds {
    my ( $taxon_oid, $data_type, $oids_ref, $print_msg ) = @_;

    my %scaffold_stats_h;

    my $hasScaffoldStatsSqliteFile = hasSdbScaffoldStatsFile( $taxon_oid, $data_type );
    if ($hasScaffoldStatsSqliteFile) {
        if ($print_msg) {
            print "<p>Retrieving scaffold stats for genome $taxon_oid $data_type ...<br/>\n";
        }

        #apply to complicated cases, though over-used currently
        my %scaffoldStatsFile_scafs;
        my $singleScaffoldStatsFile = getSingleSdbScaffoldStatsFile( $taxon_oid, $data_type );

#print "getScaffoldStatsForTaxonScaffolds() singleScaffoldStatsFile $singleScaffoldStatsFile for genome $taxon_oid $data_type ...<br/>\n";
        if ($singleScaffoldStatsFile) {
            $scaffoldStatsFile_scafs{$singleScaffoldStatsFile} = $oids_ref;
        }

        for my $scaffoldStatsFile ( keys %scaffoldStatsFile_scafs ) {
            my $file_oids_ref = $scaffoldStatsFile_scafs{$scaffoldStatsFile};
            my $cnt0          = scalar(@$file_oids_ref);

#print "getScaffoldStatsForTaxonScaffolds() $scaffoldStatsFile with $cnt0 scaffolds for genome $taxon_oid $data_type ...<br/>\n";
            if ( $cnt0 == 0 ) {
                next;
            }

            my $cnt1         = 0;
            my $file_oid_str = '';
            for my $file_oid (@$file_oids_ref) {
                if ($file_oid_str) {
                    $file_oid_str .= ", '" . $file_oid . "'";
                } else {
                    $file_oid_str = "'" . $file_oid . "'";
                }
                $cnt1++;
                if ( ( $cnt1 % $large_block_size ) == 0 || ( $cnt1 == $cnt0 ) ) {
                    my $sql =
                      "select scaffold_oid, length, gc, n_genes from scaffold_stats where scaffold_oid in ($file_oid_str)";
                    my (%scaffoldStats) =
                      fetchScaffoldStatsForTaxonFromSqlite( $taxon_oid, $data_type, $scaffoldStatsFile, $sql );

                    #print Dumper(\%scaffoldStats);
                    if ( scalar( keys %scaffoldStats ) > 0 ) {
                        foreach my $oid ( keys %scaffoldStats ) {
                            my $workspace_id = "$taxon_oid $data_type $oid";
                            $scaffold_stats_h{$workspace_id} = $scaffoldStats{$oid};
                        }
                    }
                    $file_oid_str = '';
                }
            }
        }    #end of for scaffoldStatsFile

    } else {
        if ($print_msg) {
            print
"<p>No sqlite scaffold stats file, retrieving scaffold information from zip file for genome $taxon_oid $data_type<br/>\n";
        }
        webLog(
            "MetaUtil::getScaffoldStatsForTaxonScaffolds() no sqlite scaffold stats file for genome $taxon_oid $data_type\n"
        );

        my $tag = "scaffold_stats";
        doFlieReading( $print_msg, '', $taxon_oid, $data_type, $oids_ref, $tag, \%scaffold_stats_h );
    }

    return %scaffold_stats_h;
}

#should not used any longer
sub processUnzipScaffoldStatsFlie {
    my ( $line_no, $print_msg, $needUntaint, $taxon_oid, $data_type, $tag, $zip_name, $ids_ref, $result_info_href ) = @_;

    if ($print_msg) {
        print "<p>Processing $zip_name listed file size: " . scalar(@$ids_ref) . "<br/>\n";
    }

    WebUtil::unsetEnvPath();

    my $ids_str = join( ' ', @$ids_ref );
    if ($needUntaint) {
        ($ids_str) = ( $ids_str =~ /([A-Za-z0-9_-\s]+)/ );
    }
    my $cmd = "/usr/bin/unzip -C -p $zip_name $ids_str";

    #print "MetaUtil::processUnzipScaffoldStatsFlie() processing cmd: $cmd, ids_str: $ids_str<br/>\n";
    my $fh = newCmdFileHandle( $cmd, $tag );
    if ( !$fh ) {
        WebUtil::resetEnvPath();
        return $line_no;
    }

    #print "MetaUtil::processUnzipScaffoldStatsFlie() $zip_name opened<br/>\n";

    while ( my $line = $fh->getline() ) {

        #print "MetaUtil::processUnzipScaffoldStatsFlie() line: $line<br/>\n";
        chomp $line;
        $line_no++;
        if ($print_msg) {
            if ( ( $line_no % 10000 ) == 0 ) {
                print ".";
            }
            if ( ( $line_no % 1800000 ) == 0 ) {
                print "<br/>\n";
            }
        }

        #scaffold: ($oid, $scaf_len, $scaf_gc, $scaf_gene_cnt)
        my ( $oid, @rest ) = split( /\t/, $line );
        my $workspace_id = "$taxon_oid $data_type $oid";
        $result_info_href->{$workspace_id} = join( "\t", @rest );
        $line_no++;
    }    # end while line
    close $fh;

    WebUtil::resetEnvPath();

    return $line_no;
}

###############################################################################
# getAllGeneFuncs
###############################################################################
sub getAllGeneFuncs {
    my ( $func_type, $gene_href, $gene_func_href, $print_msg ) = @_;


    my ( $dbOids_ref, $metaOids_ref ) = MerFsUtil::splitDbAndMetaOids(keys %$gene_href);
    if ( scalar(@$dbOids_ref) > 0 ) {
        if ($print_msg) {
            print "<p>Retrieving gene $func_type annotations from database ... <br/>\n";
        }

        my $dbh = dbLogin();
        my $dbOids_str = OracleUtil::getNumberIdsInClause( $dbh, @$dbOids_ref );

        my $sql;
        if ( $func_type =~ /COG/i ) {
            $sql = qq{
                select distinct g.gene_oid, g.cog 
                from gene_cog_groups g 
                where g.gene_oid in ($dbOids_str) 
                order by 1, 2
            };
        } elsif ( $func_type =~ /PFAM/i ) {
            $sql = qq{
                select distinct g.gene_oid, g.pfam_family 
                from gene_pfam_families g 
                where g.gene_oid in ($dbOids_str) 
                order by 1, 2
            };
        } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
            $sql = qq{
                select distinct g.gene_oid, g.ext_accession 
                from gene_tigrfams g 
                where g.gene_oid in ($dbOids_str) 
                order by 1, 2
            };
        } elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
            $sql = qq{
                select distinct g.gene_oid, g.enzymes 
                from gene_ko_enzymes g 
                where g.gene_oid in ($dbOids_str) 
                order by 1, 2
            };
        } elsif ( $func_type =~ /KO/i ) {
            $sql = qq{
                select distinct g.gene_oid, g.ko_terms 
                from gene_ko_terms g 
                where g.gene_oid in ($dbOids_str) 
                order by 1, 2
            };
        }
        if ($sql) {
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ( $id2, $func_id ) = $cur->fetchrow();
                last if !$id2;
                if ( $gene_href->{$id2} ) {
                    addToGeneFuncHash( $id2, $func_id, $gene_func_href );
                }
            }
            $cur->finish();
        }
        OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
            if ( $dbOids_str =~ /gtt_num_id/i );        
    }

    if ( scalar(@$metaOids_ref) > 0 ) {
        getAllMetaGeneFuncs( $func_type, $metaOids_ref, $gene_href, $gene_func_href, $print_msg );
    }
}


###############################################################################
# getAllMetaGeneFuncs
###############################################################################
sub getAllMetaGeneFuncs {
    my ( $func_type, $metaOids_ref, $gene_href, $gene_func_href, $print_msg ) = @_;

    my $max_cnt = 2;

    my @metaOids;
    if ( $metaOids_ref && scalar(@$metaOids_ref) > 0) {
        @metaOids = @$metaOids_ref;
    }
    else {
        @metaOids = keys %$gene_href;
    }
    my %taxon_genes = getOrganizedTaxonGenes(@metaOids);
    #print "MetaUtil::getAllMetaGeneFuncs() taxon_genes:<br/>\n";
    #print Dumper(\%taxon_genes);
    #print "<br/>\n";

    # get gene functions from file system
    for my $key ( keys %taxon_genes ) {
        my ( $taxon_oid, $data_type ) = split( / /, $key );
        $taxon_oid = sanitizeInt($taxon_oid);
        my $t2 = "assembled";
        if ( $data_type eq 'unassembled' ) {
            $t2 = "unassembled";
        }

        my $oid_ref = $taxon_genes{$key};
        my %gene_oids_h;
        for my $gene_oid ( @$oid_ref ) {
            $gene_oids_h{$gene_oid} = 1;
        }
        
        my $gene_cnt_in_key = scalar(keys %gene_oids_h);        
        if ( $gene_cnt_in_key > $max_cnt ) {
            # file scan
            if ($print_msg) {
                print "<p>Retrieving gene $func_type annotation for genome $taxon_oid $data_type through file scan ...<br/>\n";
            }

            my $sdbFileExist;

            my $name_dir  = $mer_data_dir . "/" . $taxon_oid . "/" . $t2;
            my $sdb_name = $name_dir . "/gene_" . $func_type . ".sdb";
            if ( -e $sdb_name ) {
                #print "MetaUtil::getAllMetaGeneFuncs() sdb_name=$sdb_name found<br/>\n";
                $sdbFileExist = 1;
                fetchGeneFuncsForTaxonFromSqlite( $taxon_oid, $data_type, $sdb_name, 
                    $func_type, \%gene_oids_h, $gene_func_href );
            }
            else {
                my $tag       = "gene2" . $func_type;
                my $hash_file = $mer_data_dir . "/$taxon_oid" . "/" . $t2 . "/taxon_hash.txt";
                my $max_lot_cnt   = 0;
                if ( -e $hash_file ) {
                    my $fh2 = newReadFileHandle($hash_file);
                    if ( !$fh2 ) {
                        next;
                    }
                    while ( my $line1 = $fh2->getline() ) {
                        chomp($line1);
    
                        my ( $a0, $a1, $a2, @a3 ) = split( /\,/, $line1 );
                        if ( $a0 eq $tag && isInt($a2) ) {
                            $max_lot_cnt = $a2;
                            last;
                        }
                    }
                    close $fh2;
                }

                $max_lot_cnt = sanitizeInt($max_lot_cnt);
    
                WebUtil::unsetEnvPath();

                my $cnt0;
                for ( my $j = 1 ; $j <= $max_lot_cnt ; $j++ ) {
                    my $sdb_file_name = $name_dir . "/" . $tag . "/gene_" . $func_type . "_" . $j . ".sdb";
                    if ( -e $sdb_file_name ) {
                        #print "MetaUtil::getAllMetaGeneFuncs() sdb_file_name=$sdb_file_name found<br/>\n";
                        $sdbFileExist = 1;
                        my $cnt = fetchGeneFuncsForTaxonFromSqlite( $taxon_oid, $data_type, $sdb_file_name, 
                            $func_type, \%gene_oids_h, $gene_func_href );
                        $cnt0 += $cnt;
                        if ( $cnt0 >= $gene_cnt_in_key ) {
                            last;
                        }
                        next;
                    }
    
                    my $zip_name = $name_dir . "/" . $tag . "/" . $tag . "_" . $j . ".zip";
                    if ( !( -e $zip_name ) ) {
                        next;
                    }
    
                    my $fh = newCmdFileHandle( "/usr/bin/unzip -p $zip_name ", "$tag" );
                    if ( !$fh ) {
                        next;
                    }
    
                    my $cnt;
                    while ( my $line = $fh->getline() ) {
                        chomp $line;
                        
                        my $gene_oid;
                        my $func_id;
                        my @rest;
                        if ( $func_type eq 'ko' ) {
                            my ( $fld1, $fld2, $fld3 );
                            ( $gene_oid, $fld1, $fld2, $fld3, @rest ) =
                              split( /\t/, $line );
                            if ( $fld3 =~ /^KO/ ) {
                                $func_id = $fld3;
                            } elsif ( $fld1 =~ /^KO/ ) {
                                $func_id = $fld1;
                            } else {
                                next;
                            }
                        } else {
                            ( $gene_oid, $func_id, @rest ) = split( /\t/, $line );
                        }

                        if ( $gene_oids_h{$gene_oid} ) {
                            my $workspace_id = "$taxon_oid $data_type $gene_oid";    
                            addToGeneFuncHash( $workspace_id, $func_id, $gene_func_href );
                            $cnt++;
                            if ( $cnt >= $gene_cnt_in_key ) {
                                last;
                            }
                        }
                    }    # end while line
                }    # end for my j
    
                WebUtil::resetEnvPath();
            }
            
            if ( ! $sdbFileExist ) {
                #use alternative for metagenomes that do not have gene_{$func_type}.sdb file
                if ($print_msg) {
                    print "<p>Retrieving gene $func_type annotation for genome $taxon_oid $data_type through alternative way ...<br/>\n";
                }
                my %gene2funcs = getTaxonGeneFuncsAlternative( $taxon_oid, $data_type, $func_type, \%gene_oids_h );
                for my $gene_oid ( keys %gene_oids_h ) {
                    my $funs_ref = $gene2funcs{$gene_oid};
                    if ( $funs_ref && scalar(@$funs_ref) > 0 ) {
                        my $workspace_id = "$taxon_oid $data_type $gene_oid";    
                        $gene_func_href->{$workspace_id} = join( "\t", @$funs_ref );
                    }
                }
            }

        }    # end if > max_cnt
        else {

            # individual access
            if ($print_msg) {
                print "<p>Retrieving gene $func_type annotation for genome $taxon_oid $data_type through individual access ...<br/>\n";
            }

            for my $gene_oid ( keys %gene_oids_h ) {
                my $workspace_id = "$taxon_oid $data_type $gene_oid";
                $gene_href->{$workspace_id} = $taxon_oid;
        
                my @recs;
                if ( $func_type =~ /COG/i ) {
                    @recs = getGeneCogId( $gene_oid, $taxon_oid, $data_type );
                    #print "MetaUtil::getAllMetaGeneFuncs() using getGeneCogId, COG $gene_oid: " . join( ',', @recs ) . "<br/>\n";
                } elsif ( $func_type =~ /PFAM/i ) {
                    @recs = getGenePfamId( $gene_oid, $taxon_oid, $data_type );
                } elsif ( $func_type =~ /TIGR/i || $func_type =~ /TIGRFAM/i) {
                    @recs = getGeneTIGRfamId( $gene_oid, $taxon_oid, $data_type );
                    #print "MetaUtil::getAllMetaGeneFuncs() using getGeneTIGRfamId, Tigrfam $gene_oid: " . join( ',', @recs ) . "<br/>\n";
                } elsif ( $func_type =~ /EC/i || $func_type =~ /ENZYME/i) {
                    @recs = getGeneEc( $gene_oid, $taxon_oid, $data_type );
                } elsif ( $func_type =~ /KO/i ) {
                    @recs = getGeneKoId( $gene_oid, $taxon_oid, $data_type );
                }
                if ( scalar(@recs) > 0 ) {
                    $gene_func_href->{$workspace_id} = join( "\t", @recs );
                }
            }
        }
    }    # end for key
    #print "MetaUtil::getAllMetaGeneFuncs() gene_func_href:<br/>\n";
    #print Dumper($gene_func_href);
    #print "<br/>\n";

}


sub fetchGeneFuncsForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $func_type, $gene_oids_href, $gene_func_href ) = @_;

    my $dbh3 = WebUtil::sdbLogin($sdb_name)
      or return;

    my $sql3 = "select gene_oid, $func_type from gene_" . $func_type;
    
    my @gene_oids = keys %$gene_oids_href;
    my $gene_cnt_in_key = scalar(@gene_oids);
    #limit the size to 900
    if ( $gene_cnt_in_key <= 900 ) {
        my $genes_str = WebUtil::joinSqlQuoted( ",", @gene_oids );
        $sql3 .= " where gene_oid in ($genes_str) ";
    }
    #print "fetchGeneFuncsForTaxonFromSqlite() sql3: $sql3<br/>\n";

    my $sth  = $dbh3->prepare($sql3);
    $sth->execute();
                
    my $cnt;
    for ( ; ; ) {
        my ( $gene_oid, $func_id ) = $sth->fetchrow_array();
        last if !$gene_oid;
        #print "MetaUtil::fetchGeneFuncsForTaxonFromSqlite() gene_oid: $gene_oid, func_id: $func_id<br/>\n";
        if ( $gene_oids_href->{$gene_oid} ) {
            my $workspace_id = "$taxon_oid $data_type $gene_oid";
            addToGeneFuncHash( $workspace_id, $func_id, $gene_func_href );
            $cnt++;
            if ( $cnt >= $gene_cnt_in_key ) {
                last;
            }
        }
    }
    $sth->finish();
    $dbh3->disconnect();
    
    return $cnt;
}

sub addToGeneFuncHash {
    my ( $workspace_id, $func_id, $gene_func_href ) = @_;

    if ( $gene_func_href->{$workspace_id} ) {
        # check duplicates
        my @func_s = split( /\t/, $gene_func_href->{$workspace_id} );
        if ( ! WebUtil::inArray($func_id, @func_s) ) {
            $gene_func_href->{$workspace_id} .= "\t" . $func_id;
        }
    } else {
        $gene_func_href->{$workspace_id} = $func_id;
    }

}

############################################################################
# getTaxonGeneFuncsAlternative: get specific funns for this gene 
# through {$func}_gene.sdb file, not gene_{$func}.sdb file
# because gene_{$func}.sdb file missing in some metagenomes
############################################################################
sub getTaxonGeneFuncsAlternative {
    my ( $taxon_oid, $data_type, $func_type, $limiting_genes_href ) = @_;

    my %gene2funcs;

    my %func_genes = getTaxonFuncsGenes( $taxon_oid, $data_type, $func_type, '', $limiting_genes_href );
    if ( scalar( keys %func_genes ) > 0 ) {
        foreach my $func (keys %func_genes) {
            if ( $func_genes{$func} ) {
                my @genes = split( /\t/, $func_genes{$func} );
                for my $gene ( @genes ) {
                    if ( $limiting_genes_href && $limiting_genes_href->{$gene} ) {
                        my $funcs_ref = $gene2funcs{$gene};
                        if ($funcs_ref) {
                            if ( ! WebUtil::inArray($func, @$funcs_ref) ) {
                                push(@$funcs_ref, $func);
                            }
                        } else {
                            my @funcs = ( $func );
                            $gene2funcs{$gene} = \@funcs;
                        }
                    }
                    else {
                        my $funcs_ref = $gene2funcs{$gene};
                        if ($funcs_ref) {
                            if ( ! WebUtil::inArray($func, @$funcs_ref) ) {
                                push(@$funcs_ref, $func);
                            }
                        } else {
                            my @funcs = ( $func );
                            $gene2funcs{$gene} = \@funcs;
                        }
                    }                    
                }
            }
        }
    }

    return %gene2funcs;
}


############################################################################
# fetchGeneNameForTaxonFromSqlite
############################################################################
sub fetchGeneNameForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %geneNames;

    if ($sdb_name) {

        #print "MetaUtil::fetchGeneNameForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);
        } else {
            webLog("MetaUtil::fetchGeneNameForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( defined($sdbh) && $sdbh ne '' ) {

            #print "MetaUtil::fetchGeneNameForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchGeneNameForTaxonFromSqlite() bind: $bind<br/>\n";
            my $sth = $sdbh->prepare($sql);
            if ( defined($bind) && $bind ne '' ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $gene_oid, $product_name, $prod_source ) = $sth->fetchrow_array();
                last if !$gene_oid;
                if ( !$product_name ) {
                    $product_name = "hypothetical protein";
                }
                $geneNames{$gene_oid} = $product_name;
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%geneNames);
}

sub fetchGeneInfoForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %geneInfos;

    if ($sdb_name) {

        #print "MetaUtil::fetchGeneAAForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);
        } else {
            webLog("MetaUtil::fetchGeneInfoForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( $sdbh ne '' && defined($sdbh) ) {

            #print "MetaUtil::fetchGeneInfoForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchGeneInfoForTaxonFromSqlite() bind: $bind<br/>\n";
            webLog("MetaUtil::fetchGeneInfoForTaxonFromSqlite() sql: $sql\n");

            my $sth = $sdbh->prepare($sql);
            if ( $bind ne '' && defined($bind) ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $gene_oid, @rest ) = $sth->fetchrow_array();
                last if !$gene_oid;
                $geneInfos{$gene_oid} = join( "\t", @rest );

                #print "MetaUtil::fetchGeneInfoForTaxonFromSqlite() $gene_oid added<br/>\n";
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%geneInfos);
}

sub fetchGeneAAForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %geneAAs;

    if ($sdb_name) {

        #print "MetaUtil::fetchGeneAAForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);
        } else {
            webLog("MetaUtil::fetchGeneAAForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( $sdbh ne '' && defined($sdbh) ) {

            #print "MetaUtil::fetchGeneAAForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchGeneAAForTaxonFromSqlite() bind: $bind<br/>\n";
            my $sth = $sdbh->prepare($sql);
            if ( $bind ne '' && defined($bind) ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $gene_oid, $faa ) = $sth->fetchrow_array();
                last if !$gene_oid;
                $geneAAs{$gene_oid} = $faa;
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%geneAAs);
}

sub fetchScaffoldGenesForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %scafGenes;

    if ($sdb_name) {

        #print "MetaUtil::fetchScaffoldGenesForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);
        } else {
            webLog("MetaUtil::fetchScaffoldGenesForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( $sdbh ne '' && defined($sdbh) ) {

            #print "MetaUtil::fetchScaffoldGenesForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchScaffoldGenesForTaxonFromSqlite() bind: $bind<br/>\n";
            my $sth = $sdbh->prepare($sql);
            if ( $bind ne '' && defined($bind) ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $g_oid, @rest ) = $sth->fetchrow_array();
                last if !$g_oid;
                my $size  = scalar(@rest);
                my $s_oid = $rest[ $size - 1 ];
                my $line  = $g_oid . "\t" . join( "\t", @rest );

                my $scaf_genes_ref = $scafGenes{$s_oid};
                if ( $scaf_genes_ref ne '' ) {
                    push( @$scaf_genes_ref, $line );
                } else {
                    my @scaf_genes = ($line);
                    $scafGenes{$s_oid} = \@scaf_genes;
                }
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%scafGenes);
}

sub fetchScaffoldDnaForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %scafDnas;

    if ($sdb_name) {

        #print "MetaUtil::fetchScaffoldDnaForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);
        } else {
            webLog("MetaUtil::fetchScaffoldDnaForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( $sdbh ne '' && defined($sdbh) ) {

            #print "MetaUtil::fetchScaffoldDnaForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchScaffoldDnaForTaxonFromSqlite() bind: $bind<br/>\n";
            my $sth = $sdbh->prepare($sql);
            if ( $bind ne '' && defined($bind) ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $s_oid, $fna ) = $sth->fetchrow_array();
                last if !$s_oid;
                $scafDnas{$s_oid} = $fna;
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%scafDnas);
}

sub fetchScaffoldStatsForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %scaffoldStats;

    if ($sdb_name) {

        #print "MetaUtil::fetchScaffoldStatsForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);
        } else {
            webLog("MetaUtil::fetchScaffoldStatsForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( defined($sdbh) && $sdbh ne '' ) {

            #print "MetaUtil::fetchScaffoldStatsForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchScaffoldStatsForTaxonFromSqlite() bind: $bind<br/>\n";
            my $sth = $sdbh->prepare($sql);
            if ( defined($bind) && $bind ne '' ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $scaffold_oid, $length, $gc, $n_genes ) = $sth->fetchrow_array();
                last if !$scaffold_oid;
                my $line = "$length\t$gc\t$n_genes";
                $scaffoldStats{$scaffold_oid} = $line;

                #print "MetaUtil::fetchScaffoldStatsForTaxonFromSqlite() line: $line<br/>\n";
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%scaffoldStats);
}

sub fetchScaffoldLineageForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %scaffoldLineages;

    if ($sdb_name) {

        #print "MetaUtil::fetchScaffoldLineageForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);
        } else {
            webLog("MetaUtil::fetchScaffoldLineageForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( defined($sdbh) && $sdbh ne '' ) {

            #print "MetaUtil::fetchScaffoldLineageForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchScaffoldLineageForTaxonFromSqlite() bind: $bind<br/>\n";
            my $sth = $sdbh->prepare($sql);
            if ( defined($bind) && $bind ne '' ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $scaffold_oid, $lineage, $percentage, $rank ) = $sth->fetchrow_array();
                last if !$scaffold_oid;
                $scaffoldLineages{$scaffold_oid} = $lineage . "\t" . $percentage . "\t" . $rank;
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%scaffoldLineages);
}

sub fetchScaffoldDepthForTaxonFromSqlite {
    my ( $taxon_oid, $data_type, $sdb_name, $sql, $bind ) = @_;

    my %scaffoldDepths;

    if ($sdb_name) {

        #print "MetaUtil::fetchScaffoldDepthForTaxonFromSqlite() sdb_name: $sdb_name<br/>\n";
        my $sdbh;
        if ( -e $sdb_name && -s $sdb_name > $MIN_FILE_SIZE ) {
            $sdbh = WebUtil::sdbLogin($sdb_name);   
        } else {
            webLog("MetaUtil::fetchScaffoldDepthForTaxonFromSqlite() do not exist $sdb_name");
        }
        if ( defined($sdbh) && $sdbh ne '' ) {

            #print "MetaUtil::fetchScaffoldDepthForTaxonFromSqlite() sql: $sql<br/>\n";
            #print "MetaUtil::fetchScaffoldDepthForTaxonFromSqlite() bind: $bind<br/>\n";
            my $sth = $sdbh->prepare($sql);
            if ( defined($bind) && $bind ne '' ) {
                $sth->execute($bind);
            } else {
                $sth->execute();
            }

            for ( ; ; ) {
                my ( $scaffold_oid, $depth ) = $sth->fetchrow_array();
                last if !$scaffold_oid;
                if ( $depth && isNumber($depth) ) {
                    my $scaf_depth = floor( $depth + 0.5 );
                    $scaffoldDepths{$scaffold_oid} = $scaf_depth;

                    #print "fetchScaffoldDepthForTaxonFromSqlite() $scaffold_oid scaf_depth: $scaf_depth<br/>\n";
                }
            }
            $sth->finish();
            $sdbh->disconnect();
        }
    }

    return (%scaffoldDepths);
}

###############################################################################
# getOrganizedTaxonGenes
###############################################################################
sub getOrganizedTaxonGenes {
    my (@metaOids) = @_;

    my %taxon_genes;
    for my $mOid (@metaOids) {
        my ( $taxon_oid, $data_type, $gene_oid ) = split( / /, $mOid );
        my $key = "$taxon_oid $data_type";
        if ( $taxon_genes{$key} ) {
            my $oid_ref = $taxon_genes{$key};
            push( @$oid_ref, $gene_oid );
        } else {
            my @oid = ($gene_oid);
            $taxon_genes{$key} = \@oid;
        }
    }

    return (%taxon_genes);
}

###############################################################################
# getOrganizedTaxonGeneProductFiles
###############################################################################
sub getOrganizedTaxonGeneProductFiles {
    my ( $taxon_oid, $data_type, @oids ) = @_;

    my %prodFile_genes;
    for my $gene_oid (@oids) {
        my @sdb_names = getSdbGeneProductFile( $gene_oid, $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            for my $sdbFile (@sdb_names) {
                if ( $prodFile_genes{$sdbFile} ) {
                    my $oid_ref = $prodFile_genes{$sdbFile};
                    push( @$oid_ref, $gene_oid );
                } else {
                    my @oid = ($gene_oid);
                    $prodFile_genes{$sdbFile} = \@oid;
                }
            }
        }
    }

    return (%prodFile_genes);
}

###############################################################################
# getOrganizedTaxonGeneInfoFiles
###############################################################################
sub getOrganizedTaxonGeneInfoFiles {
    my ( $taxon_oid, $data_type, @oids ) = @_;

    my %geneInfoFile_genes;
    for my $gene_oid (@oids) {
        my @sdb_names = getSdbGeneInfoFile( $gene_oid, $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            for my $sdbFile (@sdb_names) {
                if ( $geneInfoFile_genes{$sdbFile} ) {
                    my $oid_ref = $geneInfoFile_genes{$sdbFile};
                    push( @$oid_ref, $gene_oid );
                } else {
                    my @oid = ($gene_oid);
                    $geneInfoFile_genes{$sdbFile} = \@oid;
                }
            }
        }
    }

    return (%geneInfoFile_genes);
}

###############################################################################
# getOrganizedTaxonGeneAAFiles
###############################################################################
sub getOrganizedTaxonGeneAAFiles {
    my ( $taxon_oid, $data_type, @oids ) = @_;

    my %aaFile_genes;
    for my $gene_oid (@oids) {
        my @sdb_names = getSdbGeneAAFile( $gene_oid, $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            for my $sdbFile (@sdb_names) {
                if ( $aaFile_genes{$sdbFile} ) {
                    my $oid_ref = $aaFile_genes{$sdbFile};
                    push( @$oid_ref, $gene_oid );
                } else {
                    my @oid = ($gene_oid);
                    $aaFile_genes{$sdbFile} = \@oid;
                }
            }
        }
    }

    return (%aaFile_genes);
}

###############################################################################
# getOrganizedTaxonScaffolds
###############################################################################
sub getOrganizedTaxonScaffolds {
    my (@metaOids) = @_;

    my %taxon_scaffolds;
    for my $mOid (@metaOids) {
        my ( $taxon_oid, $data_type, $scaffold_oid ) = split( / /, $mOid );
        my $key = "$taxon_oid $data_type";
        if ( $taxon_scaffolds{$key} ) {
            my $oid_ref = $taxon_scaffolds{$key};
            push( @$oid_ref, $scaffold_oid );
        } else {
            my @oid = ($scaffold_oid);
            $taxon_scaffolds{$key} = \@oid;
        }
    }

    return (%taxon_scaffolds);
}

###############################################################################
# getOrganizedTaxonScaffoldGenesFiles
###############################################################################
sub getOrganizedTaxonScaffoldGenesFiles {
    my ( $taxon_oid, $data_type, @oids ) = @_;

    my %scafGeneFile_scafs;
    for my $s_oid (@oids) {
        my @sdb_names = getSdbScaffoldGenesFile( $s_oid, $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            for my $sdbFile (@sdb_names) {
                if ( $scafGeneFile_scafs{$sdbFile} ) {
                    my $oid_ref = $scafGeneFile_scafs{$sdbFile};
                    push( @$oid_ref, $s_oid );
                } else {
                    my @oid = ($s_oid);
                    $scafGeneFile_scafs{$sdbFile} = \@oid;
                }
            }
        }
    }

    return (%scafGeneFile_scafs);
}

###############################################################################
# getOrganizedTaxonScaffoldDnaFiles
###############################################################################
sub getOrganizedTaxonScaffoldDnaFiles {
    my ( $taxon_oid, $data_type, @oids ) = @_;

    my %dnaFile_scafs;
    for my $s_oid (@oids) {
        my @sdb_names = getSdbScaffoldDnaFile( $s_oid, $taxon_oid, $data_type );
        if ( scalar(@sdb_names) > 0 ) {
            for my $sdbFile (@sdb_names) {
                if ( $dnaFile_scafs{$sdbFile} ) {
                    my $oid_ref = $dnaFile_scafs{$sdbFile};
                    push( @$oid_ref, $s_oid );
                } else {
                    my @oid = ($s_oid);
                    $dnaFile_scafs{$sdbFile} = \@oid;
                }
            }
        }
    }

    return (%dnaFile_scafs);
}

###############################################################################
# getTaxonHashFile
###############################################################################
sub getTaxonHashFile {
    my ( $taxon_oid, $data_type ) = @_;

    return "$mer_data_dir/$taxon_oid/$data_type/taxon_hash.txt";
}

###############################################################################
# isMetaGene
###############################################################################
sub isMetaGene {
    my ($gene_oid) = @_;
    if ( WebUtil::isInt($gene_oid) ) {
        return 0;
    } else {
        return 1;
    }
}

###############################################################################
# parseMetaGeneOid
###############################################################################
sub parseMetaGeneOid {
    my ($gene_oid) = @_;
    my ( $goid, $dtype, $toid );

    if ( isMetaGene($gene_oid) ) {
        my $dtype_goid;
        ( $toid,  $dtype_goid ) = split( /\./, $gene_oid );
        ( $dtype, $goid )       = split( /:/,  $dtype_goid );
        if ( $dtype = 'a' ) {
            $dtype = 'assembled';
        } else {
            $dtype = 'unassembled';
        }
    }
    my @v = ( $goid, $dtype, $toid );
    return @v;

}
###############################################################################
# getMetaGeneOid
###############################################################################
sub getMetaGeneOid {
    my ( $goid, $dtype, $toid ) = @_;

    $goid = sanitizeGeneId3($goid);
    $toid = sanitizeInt($toid);

    if ( $dtype eq 'assembled' ) {
        $dtype = 'a';
    } elsif ( $dtype eq 'unassembled' ) {
        $dtype = 'u';
    } elsif ( $dtype ne 'u' && $dtype ne 'a' ) {
        webDie("Bad data_type for MetaUtil::getMetaGeneOid()\n");
    }

    return $toid . "." . $dtype . ":" . $goid;
}

############################################################################
# taxonHashNoBins -  Get number of bins from taxon_hash table.
#    Convenience routine.
############################################################################
sub taxonHashNoBins {
    my ( $taxau, $type0 ) = @_;

    my ( $taxon_oid, $au ) = split( /\./, $taxau );
    my $webMerFsDir = "$web_data_dir/mer.fs";
    my $taxonDir    = "$webMerFsDir/$taxon_oid";
    my $auLong      = "assembled";
    $auLong = "unassembled" if $au eq "u";
    my $txd = "$taxonDir/$auLong";

    my $taxonHashFile = "$txd/taxon_hash.txt";
    my $rfh           = newReadFileHandle( $taxonHashFile, "taxonHashNoBins" );
    my $nBins         = 0;
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        my ( $type, $method, $bins ) = split( /,/, $s );
        if ( $type eq $type0 ) {
            $nBins = $bins;
            last;
        }
    }
    close $rfh;
    if ( $nBins == 0 ) {
        webDie( "taxonHasNoBins: cannot find nBins for " . "taxau='$taxau' type='$type0'\n" );
    }
    return $nBins;
}

############################################################################
# getPhyloDistProfileTxt
############################################################################
sub getPhyloDistProfileTxt {
    my ( $phylo_prefix, $taxon_oid, $data_type ) = @_;

    my %h;

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $filename = getPhyloDistTaxonDir($taxon_oid) . "/" . $phylo_prefix . $t2 . ".profile.txt";
        if ( !( -e $filename ) ) {
            next;
        }

        my $res = newReadFileHandle($filename);
        while ( my $line = $res->getline() ) {
            chomp $line;
            my ( $taxon_oid, @rest ) = split( /\t/, $line );
            if ( isInt($taxon_oid) ) {
                if ( $h{$taxon_oid} ) {
                    $h{$taxon_oid} .= "\n" . $line;
                } else {
                    $h{$taxon_oid} = $line;
                }
            }
        }
        close $res;
    }

    return %h;
}

############################################################################
# getPhyloDistEstCopyCount
############################################################################
sub getPhyloDistEstCopyCount {
    my ( $phylo_prefix, $taxon_oid, $data_type ) = @_;

    my $totalCopyCount = 0;

    my @type_list = getDataTypeList($data_type);
    for my $t2 (@type_list) {
        my $file_name = getPhyloDistTaxonDir($taxon_oid) . "/" . $phylo_prefix . $t2 . ".profile.txt";
        if ( -e $file_name ) {
            my $fh = newReadFileHandle($file_name);
            if ( !$fh ) {
                next;
            }
            my $line = "";
            while ( $line = $fh->getline() ) {
                chomp $line;
                my ( $tag, $val ) = split( /\t/, $line );
                if ( $tag eq 'TotalEstCopy' ) {
                    $totalCopyCount += $val;
                    last;
                }
            }
            close $fh;
        }
    }

    return $totalCopyCount;
}

###############################################################################

#
# old metagenomes only have assembled data
#
sub isOldMetagenomeGeneId {
    my ( $dbh, $old_gene_oid ) = @_;

    my $sql = qq{
        select gene_oid, merfs_gene_id, locus_tag, taxon
        from merfs_gene_mapping
        where gene_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $old_gene_oid );
    my ( $gene_oid, $merfs_gene_id, $locus_tag, $taxon ) = $cur->fetchrow();
    $cur->finish();
    return ( $gene_oid, $merfs_gene_id, $locus_tag, $taxon );
}

sub isOldMetagenomeGeneIds {
    my ( $dbh, $aref ) = @_;

    my $term_str = join( ',', @$aref );

    my $sql = qq{
        select gene_oid, merfs_gene_id, locus_tag, taxon
        from merfs_gene_mapping
        where gene_oid in ($term_str)
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $merfs_gene_id, $locus_tag, $taxon ) = $cur->fetchrow();
        last if !$gene_oid;
        my @a = split( /\s/, $merfs_gene_id );
        $hash{$gene_oid} = lc( $a[2] );
    }
    $cur->finish();
    return \%hash;
}

###############################################################################
# getPhyloDistTaxonDir
###############################################################################
sub getPhyloDistTaxonDir {
    my ($taxon_oid) = @_;

    return "$web_data_dir/phyloDist/$taxon_oid";
}


###############################################################################
# getPhyloDistHomoTaxonsSql
###############################################################################
sub getPhyloDistHomoTaxonsSql {
    my ( @taxon_list ) = @_;

    my $taxons_str = join( ",", @taxon_list );
    my $sql = qq{
        select gene_oid, perc, homolog, homo_taxon, est_copy 
        from phylo_dist
        where homo_taxon in ( $taxons_str )
    };
    return $sql;
}

###############################################################################
# getPhyloDistSingleHomoTaxonSql
###############################################################################
sub getPhyloDistSingleHomoTaxonSql {

    my $sql = qq{
        select gene_oid, perc, homolog, homo_taxon, est_copy 
        from phylo_dist 
        where homo_taxon = ? 
    };
    return $sql;
}

###############################################################################
# getPhyloDistGenesSql
###############################################################################
sub getPhyloDistGenesSql {
    my ( @gene_list ) = @_;

    my $genes_str = WebUtil::joinSqlQuoted( ",", @gene_list );
    my $sql = qq{
        select gene_oid, perc, homolog, homo_taxon, est_copy 
        from phylo_dist 
        where gene_oid in ( $genes_str )  
    };
    return $sql;
}

###############################################################################
# getPhyloDistSingleGeneSql
###############################################################################
sub getPhyloDistSingleGeneSql {

    my $sql = qq{
        select gene_oid, perc, homolog, homo_taxon, est_copy 
        from phylo_dist 
        where gene_oid = ? 
    };
    return $sql;
}

###############################################################################
# getPercentClause
###############################################################################
sub getPercentClause {
    my ( $percent, $plus ) = @_;

    my $percentClause;
    if ( $percent == 30 ) {
        if ( $plus ) {
            $percentClause = "and perc >= 30 ";
        }
        else {
            $percentClause = "and perc >= 30 and perc < 60 ";
        }
    } elsif ( $percent == 60 ) {
        if ( $plus ) {
            $percentClause = "and perc >= 60 ";
        }
        else {
            $percentClause = "and perc >= 60 and perc < 90 ";
        }
    } else {
        $percentClause = "and perc >= 90 ";
    }

    return $percentClause;
}

###############################################################################
# getDataTypeList
###############################################################################
sub getDataTypeList {
    my ($data_type) = @_;

    my @type_list;
    if ( $data_type eq 'assembled' ) {
        @type_list = ('assembled');
    } elsif ( $data_type eq 'unassembled' ) {
        @type_list = ('unassembled');
    } else {
        @type_list = ( 'assembled', 'unassembled' );
    }

    return (@type_list);
}

1;
