###########################################################################
#
# $Id: OracleUtil.pm 33157 2015-04-13 00:02:52Z jinghuahuang $
#
#
#
#
# As a min. the following
# gtt must exist in the schema
#
# gtt_num_id - used to store things like gene_oid, taxon_oid etc
# gtt_num_id2
# gtt_num_id3 - new for 3.2
#
# gtt_func_id - used to store things like cog id, pfam ids etc
# gtt_func_id2  - new for 3.2
# gtt_func_id3  - new for 3.2
# 
#
#
# example query
# select *
# from gene
# where gene_oid in (select id from gtt_num_id)
#
# - Ken
#
# gtt tables are session based and data will be lost on a disconnect
# You can delete the data in gtt use method delete.
# You might need to delete when you need taxon_oids and then gene_oids
#
#
package OracleUtil;

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use Data::Dumper;
use DBI;
use Storable;
use CGI qw( :standard );
use Digest::SHA qw(sha256_hex);
use HtmlUtil;
use WebUtil;
use WebConfig;


$| = 1;

my $env                  = getEnv();
my $cgi_dir              = $env->{cgi_dir};
my $cgi_url              = $env->{cgi_url};
my $main_cgi             = $env->{main_cgi};
my $inner_cgi            = $env->{inner_cgi};
my $tmp_url              = $env->{tmp_url};
my $verbose              = $env->{verbose};
my $include_metagenomes  = $env->{include_metagenomes};
my $web_data_dir         = $env->{web_data_dir};
my $img_internal         = $env->{img_internal};
my $user_restricted_site = $env->{user_restricted_site};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $base_url             = $env->{base_url};
my $YUI                  = $env->{yui_dir_28};
my $tmp_dir              = $env->{tmp_dir};
my $img_ken              = $env->{img_ken};


# for when the user does not select any genomes
# and the new feature of  seq seq satus and domain filter is in use
# for  pages find genes and find functions
sub getTaxonInClause {
    my $seq_status = param("seqstatus");
    my $domain     = param("domainfilter");

    my $seqstatusClause = "";
    my $domainClause    = "";

    if ( $seq_status ne "" && $seq_status ne "both" ) {
        $seqstatusClause = "and seq_status = '$seq_status' ";
    }

    if ( $domain ne "" && $domain ne "All" ) {
        if ( $domain eq "Vir" || $domain eq "Plasmid" || $domain eq "GFragment" ) {
            $domainClause = "and domain like '$domain%'";
        } else {
            $domainClause = "and domain = '$domain' ";
        }
    }

    my $sql = "";
    if ( $seqstatusClause ne "" || $domainClause ne "" ) {
        $sql =
            "select taxon_oid from taxon "
          . " where obsolete_flag = 'No' "
          . " $seqstatusClause $domainClause ";
    }
    return $sql;

}

sub getTaxonInClauseBind {
    my ( $useAlt ) = @_;
    
    my $seq_status = getSeqStatusChoice( $useAlt );
    my $domain = getDomainChoice( $useAlt );

    my $seqstatusClause = "";
    my $domainClause    = "";
    my @bindList        = ();

    if ( $seq_status ne "" && $seq_status ne "both" ) {
        $seqstatusClause = "and seq_status = ? ";
        push( @bindList, "$seq_status" );
    }

    if ( $domain ne "" && $domain ne "All" ) {
        if ( $domain eq "Vir" || $domain eq "Plasmid" || $domain eq "GFragment" ) {
            $domainClause = "and domain like ?";
            push( @bindList, "$domain%" );
        } else {
            $domainClause = "and domain = ? ";
            push( @bindList, "$domain" );
        }
    }

    my $sql = "";
    if ( $seqstatusClause ne "" || $domainClause ne "" ) {
        $sql =
            "select taxon_oid from taxon "
          . " where obsolete_flag = 'No' "
          . " $seqstatusClause $domainClause ";
    }
    return ( $sql, @bindList );
}

sub getSeqStatusChoice {
    my ( $useAlt ) = @_;

    my $seq_status;
    if ($useAlt) {
        $seq_status = param("seqstatus_alt");
    }
    else {
        $seq_status = param("seqstatus");
    }
    $seq_status = getSessionParam("seqstatus") if ($seq_status eq '');

    return $seq_status;
}


sub getDomainChoice {
    my ( $useAlt ) = @_;

    my $domain;
    if ($useAlt) {
        $domain = param("domainfilter_alt");
    }
    else {
        $domain = param("domainfilter");
    }
    $domain = getSessionParam("domainfilter") if ($domain eq '');

    return $domain;
}

sub getTaxonSelectionClause {

    # $tSym: symbol for table + taxon
    my ( $dbh, $tSym, @genomeFilterSelections ) = @_;

    my $taxonClause = "";
    if ( scalar(@genomeFilterSelections) > 0 ) {
        $taxonClause = getTaxonOidClause($dbh, $tSym, \@genomeFilterSelections);
    } else {

        # user has selected nothing
        my $insql = getTaxonInClause();
        if ( $insql ne "" ) {
            $taxonClause = " and $tSym in($insql) ";
        }
        
        my $taxonChoice = getTaxonChoice();
        if ( $taxonChoice ne "All" ) {
            my $txsClause = WebUtil::txsClause("$tSym", $dbh);
            $taxonClause .= $txsClause;
        }
    }
    return $taxonClause;

}

sub getTaxonSelectionClauseBind {
    # $tSym: symbol for table + taxon
    my ( $dbh, $tSym, $genomeFilterSelections_ref, $useAlt ) = @_;

    my @genomeFilterSelections = ();
    if ($genomeFilterSelections_ref ne '' && defined($genomeFilterSelections_ref)) {
        @genomeFilterSelections = @$genomeFilterSelections_ref;
    }
    my $taxonClause = "";
    my @bindList    = ();
    if ( scalar(@genomeFilterSelections) > 0 ) {
        $taxonClause = getTaxonOidClause($dbh, $tSym, \@genomeFilterSelections);
    } else {

        # user has selected nothing
        my ( $insql, @bindList1 ) = getTaxonInClauseBind($useAlt);
        if ( $insql ne "" ) {
            $taxonClause = " and $tSym in ($insql) ";
            if ( scalar(@bindList1) > 0 ) {
                push( @bindList, @bindList1 );
            }
        }

        my $taxonChoice = getTaxonChoice( $useAlt );
        if ( $taxonChoice ne "All" ) {
            my $txs = WebUtil::txsClause("$tSym", $dbh);
            $taxonClause .= $txs;
        }
    }

    return ( $taxonClause, @bindList );
}

sub getTaxonChoice {
    my ( $useAlt ) = @_;

    my $taxonChoice;
    if ($useAlt) {
        $taxonChoice = param("taxonChoice_alt");
    }
    else {
        $taxonChoice = param("taxonChoice");
    }
    $taxonChoice = getSessionParam("taxonChoice") if ($taxonChoice eq '');

    return $taxonChoice;
}

sub getTaxonOidClause {

    # $tSym: symbol for table + taxon
    my ( $dbh, $tSym, $genomes_ref, $customDefinedMax  ) = @_;

    my $taxonClause = "";
    if ( scalar(@$genomes_ref) > 0 ) {
        my $taxon_oid_str = getNumberIdsInCustomClause( $dbh, $genomes_ref, $customDefinedMax );
        $taxonClause = "and $tSym in ( $taxon_oid_str ) ";
    } 
    return $taxonClause;

}


############################################################################
# processTaxonSelectionParam - process taxons selected from either list or tree
############################################################################
sub processTaxonSelectionParam {
    my ( $prm) = @_;

    my @taxonSelections = param($prm); #genome list
    #print "processTaxonSelectionParam() $prm: @taxonSelections<br/>";
    if (scalar(@taxonSelections) == 1 && $taxonSelections[0] =~ /\,/) {
        @taxonSelections = processParamValue(param($prm));  #genome tree
    }
    return (@taxonSelections);
}

############################################################################
# processTaxonSelectionParam - process taxons selected from either list or tree
############################################################################
sub processTaxonSelectionSingleParam {
    my ( $prm) = @_;

    my $taxon_oid = param($prm); #genome list
    if ($taxon_oid ne '' && $taxon_oid =~ /\,/) {
        my @taxonSelections = processParamValue($taxon_oid);  #genome tree
        $taxon_oid = $taxonSelections[0]; #choose the first
    }
    return $taxon_oid;
}

############################################################################
# processTaxonBinOids - Get taxon or bin oid from printPhyloBinSelectionList.
#    Currently type is either "t" (taxon) or "b" (bin).
############################################################################
sub processTaxonBinOids {
    my( $type, $selectName) = @_;
    if ($selectName eq '') {
    	$selectName = "profileTaxonBinOid";
    }
    my @toids = processTaxonSelectionParam( $selectName );
    my @oids2;
    for my $toid( @toids ) {
       my( $type2, $oid ) = split( /:/, $toid );
       if( $type2 eq $type ) {
          push( @oids2, $oid );
       }
    }
    return @oids2;
}

# not used currently
sub isAllTaxons {
    my $seq_status = param("seqstatus");
    my $domain     = param("domainfilter");

    if (    ( $seq_status eq "" || $seq_status eq "both" )
         && ( $domain eq "" || $domain eq "All" ) )
    {
        return 1;
    }
    return -1;
}

# $attr1 could use upper case
# $lattr2 use contain
# $lattr3 use contain
sub addContainWhereClause {
    my ($idPrefix, $isPrefixForInt, $searchTermLc, $attr1, $lattr2, $lattr3, $isFirstUpperCase) = @_;

    my @terms = WebUtil::splitTerm($searchTermLc, 0, 0);
    my $moreWhereClause;
    my @bindList = ();
    if ( ($#terms + 1) > 0 ) {
        my $count = 0;
        for my $tok (@terms) {
            my $tok_attr1;
            if ($isFirstUpperCase) {
                $tok_attr1 = uc($tok);
            } 
            else {
                $tok_attr1 = $tok;
            }
            
            $moreWhereClause .= "( ";
            if ($idPrefix ne '' 
                && (!$isPrefixForInt || ($isPrefixForInt && isInt($tok)))) {
                my $prefixedIdTok = $tok_attr1;
                if ( $tok_attr1 !~ /^$idPrefix/i ) {
                    $prefixedIdTok = $idPrefix.$tok_attr1;
                }
                $moreWhereClause .= "$attr1 = ? ";
                push(@bindList, "$prefixedIdTok");
            }
            else {
                $moreWhereClause .= "$attr1 = ? ";                
                push(@bindList, "$tok_attr1");
            }
            $moreWhereClause .= " or contains($lattr2, ? ) > 0 ";
            push(@bindList, "%$tok%");
            if ($lattr3 ne '') {
                $moreWhereClause .= " or contains($lattr3, ? ) > 0 ";
                push(@bindList, "%$tok%");
            }
            $moreWhereClause .= " )";
            if ($count < $#terms) {
                $moreWhereClause .= " or ";
            }
            $count ++;
        }
    }
    return ($moreWhereClause, @bindList);
}

sub addMoreWhereClause {
    my ($idPrefix, $isPrefixForInt, $searchTermLc, $lattr1, $lattr2, $lattr3, $isThirdLike) = @_;

    my @terms = WebUtil::splitTerm($searchTermLc, 0, 0);
    my $moreWhereClause;
    my @bindList = ();
    if ( ($#terms + 1) > 0 ) {
        my $count = 0;
        for my $tok (@terms) {
            $moreWhereClause .= "( ";
            if ($idPrefix ne '' 
                && (!$isPrefixForInt || ($isPrefixForInt && isInt($tok)))) {
                my $prefixedIdTok = $tok;
                if ( $tok !~ /^$idPrefix/i ) {
                    $prefixedIdTok = $idPrefix.$tok;
                }
                $moreWhereClause .= "$lattr1 = ? ";
                push(@bindList, "$prefixedIdTok");
            }
            else {
                $moreWhereClause .= "$lattr1 = ? ";                
                push(@bindList, "$tok");
            }
            $moreWhereClause .= " or $lattr2 like ? ";
            push(@bindList, "%$tok%");
            if ($lattr3 ne '') {
                if ($isThirdLike) {
                    $moreWhereClause .= " or $lattr3 like ? ";
                    push(@bindList, "%$tok%");
                } else {
                    $moreWhereClause .= " or $lattr3 = ? ";
                    push(@bindList, "%$tok%");
                }
            }
            $moreWhereClause .= " )";
            if ($count < $#terms) {
                $moreWhereClause .= " or ";
            }
            $count ++;
        }
    }
    return ($moreWhereClause, @bindList);
}

sub addIdWhereClause {
    my ($idPrefix, $idPrefixForInt, $searchTerm, $intFlag, $noErrorFlag, $removeIdPrefix, $useLowerCase) = @_;
    if ( $useLowerCase ) {
        $searchTerm =~ tr/A-Z/a-z/;
    }
    else {
        $searchTerm =~ tr/a-z/A-Z/;        
    }
    
    my @terms = WebUtil::splitTerm($searchTerm, $intFlag, $noErrorFlag); 
    #print "addIdWhereClause() terms: @terms<br/>\n";
    
    my @idTerms;
    if ( ($#terms + 1) > 0 ) {
        for my $tok (@terms) {
            if ( $removeIdPrefix ) {
                if ( $idPrefix ne '' ) {
                    if ( $tok =~ /^$idPrefix/i ) {
                        #print "addIdWhereClause() 1 tok: $tok<br/>\n";
                        $tok =~ s/^$idPrefix//i;
                        #print "addIdWhereClause() 2 tok: $tok<br/>\n";
                    }
                }                
            }
            else {
                if ( $idPrefix ne '' && $tok !~ /^$idPrefix/i ) {
                    if ($idPrefixForInt ne '' && isInt($tok)) {
                        $tok = $idPrefixForInt.$tok;
                    }
                    else {
                        $tok = $idPrefix.$tok;
                    }
                }                
            }
            push(@idTerms, $tok);
        }
    }
    #print "addIdWhereClause() idTerms: @idTerms<br/>\n";

    my $idWhereClause;
    if ( $intFlag ) {
        $idWhereClause = join( ',', @idTerms );
    }
    else {
        $idWhereClause = WebUtil::joinSqlQuoted( ',', @idTerms );
    }
    if ( WebUtil::blankStr($idWhereClause) && !$noErrorFlag ) {
        webError("Please enter a comma separated list of valid ID's.");
    }

    return ($idWhereClause);
}

sub addIdLikeWhereClause {
    my ($idPrefix, $idPrefixForInt, $searchTerm, $attr) = @_;
    
    my @terms = WebUtil::splitTerm($searchTerm, 0, 0);
    my $idLikeClause;
    my @bindList_like = ();
    foreach my $term(@terms) {
        if ( ! blankStr($idLikeClause) ) {
            $idLikeClause .= " or ";
        }
        $idLikeClause .= " $attr like ? ";
        push(@bindList_like, "%$term%");
    }

    return ($idLikeClause, @bindList_like);
}

sub useTempTable {
    my ($size, $customDefinedMax) = @_;

    my $oracle = getRdbms();

    my $oraclemax = WebUtil::getORACLEMAX();
    my $max = $oraclemax;
    if ( $customDefinedMax && $customDefinedMax > 0 && $customDefinedMax < $oraclemax ) {
        $max = $customDefinedMax;
    }

    if ( $size > $max && $oracle eq "oracle" ) {
        return 1;
    }

    return 0;
}

sub createGlobalTempTableNumber {
    my ( $dbh, $tablename ) = @_;
    my $sql = qq{
        create global temporary table $tablename ( id number not null)
        on commit preserve rows      
    };

    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
}

sub createGlobalTempTableChar {
    my ( $dbh, $tablename ) = @_;
    my $sql = qq{
        create global temporary table $tablename ( id varchar2(255) not null)
        on commit preserve rows         
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
}

sub createGlobalTempTableFromExistingTable {
    my ( $dbh, $tableName, $asValues) = @_;

    my $sql = qq{
        create global temporary table $tableName
        on commit preserve rows
        as ($asValues)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
    #$dbh->do($sql);
}

sub createGlobalTempTable {
    my ( $dbh, $tableName, $colsStr) = @_;

    my $sql = qq{
        create global temporary table $tableName(
            $colsStr
        )
        on commit preserve rows
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
    #$dbh->do($sql);
}

sub createTableIndex {
    my ( $dbh, $tableName, $indexName, $colsStr) = @_;

    $indexName = $tableName.'_idx' if ($indexName eq '');
    my $sql = qq{
        create index $indexName on $tableName (
            $colsStr
        )
    };
    $dbh->do($sql);
}

sub insertIntoTable {
    my ( $dbh, $tableName, $asValues, $bindList_ref ) = @_;

    my $sql = qq{
        insert into $tableName
        $asValues
    };
    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );
    $cur->finish();

#    $sql = qq{
#        EXEC dbms_stats.gather_table_stats(ownname=>user,tabname=>'$tableName');
#    };
#    $cur = execSql( $dbh, $sql, $verbose );
#    $cur->finish();

    execDbmsStats($dbh, 'img_core_v400', 'gtt_num_id');
}

#
# I cannot get to run as a stand alone command - ken
# You cannot use exec, you must use begin ... end; block
# ownname => 'img_core_v400', tabname => 'gtt_num_id'
# or imgsg_dev for gold db
# OracleUtil::execDbmsStats($dbh, 'img_core_v400', 'gtt_num_id');
#
sub execDbmsStats {
    my ( $dbh, $owner, $tableName ) = @_;
    my $sql = qq{
BEGIN dbms_stats.gather_table_stats(ownname => '$owner', tabname => '$tableName'); END;
    };
    #webLog("$sql\n");
    my $cur = execSql( $dbh, $sql, $verbose );
}

sub createTempTableReady {
    my ( $dbh, $tableName, $createSql, $type, $indexName, $colsStr) = @_;

    if ( ! WebUtil::tableExists($dbh, $tableName, 1) ) {
    	if ($type eq '' || $type == 0) {
            createGlobalTempTable( $dbh, $tableName, $createSql) if ($type eq '' || $type == 0);    		
    	}
    	else {
            createGlobalTempTableFromExistingTable( $dbh, $tableName, $createSql);    		
    	}
        #createTableIndex( $dbh, $tableName, $indexName, $colsStr) if ($colsStr ne '');
    }
}

sub setTempTableReady {
    my ( $dbh, $tableName, $asValues, $bindList_ref ) = @_;
    
    truncTable( $dbh, $tableName ) if (hasDataInTable($dbh, $tableName));
    insertIntoTable( $dbh, $tableName, $asValues, $bindList_ref );
}

sub hasDataInTable {
    my ( $dbh, $tableName ) = @_;

    my $sql = qq{
        select count(*) from $tableName
    };
    my $cur = execSql( $dbh, $sql, $verbose);
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    
    return $cnt;    
}

# not used currently
sub isTableExist {
    my ( $dbh, $tablename ) = @_;

    my $tName = uc($tablename);
    my $sql = qq{
        select count(table_name) 
        from all_tables 
        where table_name = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tName );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();

    return $cnt;
}

# not used currently
sub tableExist {
    my ( $dbh, $table ) = @_;

    my $tmp = uc($table);

    my $sql = qq{
        select '1'
        from user_tables
        where table_name = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $tmp );
    my ($ans) = $cur->fetchrow();
    $cur->finish();

    if ( $ans eq "1" ) {
        return 1;
    }
    return 0;
}

sub insertDataSql {
    my ( $dbh, $tablename, $selectSql ) = @_;

    my $sql = qq{
        insert into $tablename (id) 
        $selectSql
    };
    my $cur = execSql( $dbh, $sql, $verbose);
    $cur->finish();
}

# this takes about 20 sec to insert 1300+ records from home - ken
#
#
# try to use begin end - old java batch ways
#
sub insertDataArray {
    my ( $dbh, $tablename, $aref ) = @_;

    webLog("$tablename gtt insert \n");
    my $sql = " insert into $tablename (id) values (?) ";

    my $size = $#$aref + 1;
    # bug fix - no data to insert just return;
    return if ($size < 1);
    
    my $t    = currDateTime();
    #print("$t Start gtt insert $size records using execute_array $sql <br/>\n");
    webLog("$t Start gtt insert $size records using execute_array \n$sql\n");

    my $cur = $dbh->prepare($sql)
      or webDie("execSqlBind: cannot preparse statement: $DBI::errstr\n");
    $cur->bind_param_array( 1, $aref )
      or webDie("execSqlBind: cannot bind param: $DBI::errstr\n");
    $cur->execute_array( { ArrayTupleStatus => \my @status } )
      or webDie("execSqlBind: cannot execute: $DBI::errstr\n");
    $cur->finish();
    $t = currDateTime();
    
#    webLog("$t run dbms stats \n");
#    $sql = qq{
#EXEC dbms_stats.gather_table_stats(ownname=>user,tabname=>'$tablename');
#    };
#    $cur = execSql( $dbh, $sql, $verbose );
#    $cur->finish();
#    $t = currDateTime();

    webLog("$t done gtt insert \n");    
}


# where the hash keys are the ids
sub insertDataHash {
    my ( $dbh, $tablename, $href ) = @_;
    my @values = keys %$href;
    insertDataArray($dbh, $tablename, \@values);
}

sub truncTable {
    my ( $dbh, $tablename ) = @_;
    my $sql = qq{
        truncate table $tablename
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    $cur->finish();
}

############################################################################
# getFuncIdsInClause - returns the 'in' clause for func_ids
############################################################################
sub getFuncIdsInClause {
    my ( $dbh, @func_ids ) = @_;

    return getIdsInClause( $dbh, 'gtt_func_id', '', 0, \@func_ids );
}

sub getFuncIdsInCustomClause {
    my ( $dbh, $func_ids_ref, $customDefinedMax ) = @_;

    return getIdsInClause( $dbh, 'gtt_func_id', '', 0, $func_ids_ref, $customDefinedMax );
}

############################################################################
# getFuncIdsInClause1 - returns the 'in' clause for func_ids
############################################################################
sub getFuncIdsInClause1 {
    my ( $dbh, @func_ids ) = @_;

    my $createSql = qq{
        ID      VARCHAR2(255 BYTE)
    };
    return getIdsInClause( $dbh, 'gtt_func_id1', $createSql, 0, \@func_ids );
}

sub getFuncIdsInCustomClause1 {
    my ( $dbh, $func_ids_ref, $customDefinedMax ) = @_;

    my $createSql = qq{
        ID      VARCHAR2(255 BYTE)
    };
    return getIdsInClause( $dbh, 'gtt_func_id1', $createSql, 0, $func_ids_ref, $customDefinedMax );
}

############################################################################
# getFuncIdsInClause2 - returns the 'in' clause for func_ids
############################################################################
sub getFuncIdsInClause2 {
    my ( $dbh, @func_ids ) = @_;

    return getIdsInClause( $dbh, 'gtt_func_id2', '', 0, \@func_ids );
}

sub getFuncIdsInCustomClause2 {
    my ( $dbh, $func_ids_ref, $customDefinedMax ) = @_;

    return getIdsInClause( $dbh, 'gtt_func_id2', '', 0, $func_ids_ref, $customDefinedMax );
}

############################################################################
# getFuncIdsInClause3 - returns the 'in' clause for func_ids
############################################################################
sub getFuncIdsInClause3 {
    my ( $dbh, @func_ids ) = @_;

    return getIdsInClause( $dbh, 'gtt_func_id3', '', 0, \@func_ids );
}

sub getFuncIdsInCustomClause3 {
    my ( $dbh, $func_ids_ref, $customDefinedMax ) = @_;

    return getIdsInClause( $dbh, 'gtt_func_id3', '', 0, $func_ids_ref, $customDefinedMax );
}

############################################################################
# getNumIdsInClause - returns the 'in' clause for num ids
# use global temp table gtt_num_id
############################################################################
sub getNumberIdsInClause {
    my ( $dbh, @num_ids ) = @_;

    return getIdsInClause( $dbh, 'gtt_num_id', '', 1, \@num_ids );
}

sub getNumberIdsInCustomClause {
    my ( $dbh, $num_ids_ref, $customDefinedMax ) = @_;

    return getIdsInClause( $dbh, 'gtt_num_id', '', 1, $num_ids_ref, $customDefinedMax );
}

############################################################################
# getNumIdsInClause1 - returns the 'in' clause for num ids
# use global temp table gtt_num_id1
############################################################################
sub getNumberIdsInClause1 {
    my ( $dbh, @num_ids ) = @_;

    my $createSql = qq{
        ID      NUMBER
    };
    return getIdsInClause( $dbh, 'gtt_num_id1', $createSql, 1, \@num_ids );
}

sub getNumberIdsInCustomClause1 {
    my ( $dbh, $num_ids_ref, $customDefinedMax ) = @_;

    my $createSql = qq{
        ID      NUMBER
    };
    return getIdsInClause( $dbh, 'gtt_num_id1', $createSql, 1, $num_ids_ref, $customDefinedMax );
}

############################################################################
# getNumIdsInClause2 - returns the 'in' clause for num ids
# use global temp table gtt_num_id2
############################################################################
sub getNumberIdsInClause2 {
    my ( $dbh, @num_ids ) = @_;

    return getIdsInClause( $dbh, 'gtt_num_id2', '', 1, \@num_ids );
}


sub getNumberIdsInCustomClause2 {
    my ( $dbh, $num_ids_ref, $customDefinedMax ) = @_;

    return getIdsInClause( $dbh, 'gtt_num_id2', '', 1, $num_ids_ref, $customDefinedMax );
}

############################################################################
# getNumIdsInClause3 - returns the 'in' clause for num ids
# use global temp table gtt_num_id3
############################################################################
sub getNumberIdsInClause3 {
    my ( $dbh, @num_ids ) = @_;

    return getIdsInClause( $dbh, 'gtt_num_id3', '', 1, \@num_ids );
}

sub getNumberIdsInCustomClause3 {
    my ( $dbh, $num_ids_ref, $customDefinedMax ) = @_;

    return getIdsInClause( $dbh, 'gtt_num_id3', '', 1, $num_ids_ref, $customDefinedMax );
}

############################################################################
# getTaxonIdsInClause - returns the 'in' clause for taxon ids
############################################################################
sub getTaxonIdsInClause {
    my ( $dbh, @oids ) = @_;
    
    return getIdsInClause( $dbh, 'gtt_taxon_oid', '', 1, \@oids );
}

sub getTaxonIdsInCustomClause {
    my ( $dbh, $oids_ref, $customDefinedMax ) = @_;
    
    return getIdsInClause( $dbh, 'gtt_taxon_oid', '', 1, $oids_ref, $customDefinedMax );
}

############################################################################
# getIdsInClause - returns the 'in' clause for ids
############################################################################
sub getIdsInClause {
    my ( $dbh, $tableName, $createSql, $isIdNum, $ids_ref, $customDefinedMax ) = @_;

    my $idsInClause = '';
    if ( scalar(@$ids_ref) > 0 ) {
        if ( useTempTable( scalar(@$ids_ref), $customDefinedMax ) ) {
            if ( $createSql && !isTableExist($dbh, $tableName) ) {
                createTempTableReady( $dbh, $tableName, $createSql);                
            }
            truncTable( $dbh, $tableName );
            insertDataArray( $dbh, $tableName, $ids_ref );
            $idsInClause = " select id from $tableName ";
        }
        else {
            if ($isIdNum) {
                $idsInClause = join( ',', @$ids_ref );
            }
            else {
                $idsInClause = WebUtil::joinSqlQuoted( ',', @$ids_ref );
            }
        }
    }
    return $idsInClause;
}

sub getIdClause {
    my ($dbh, $tableName, $idColName, $ids_ref) = @_;

    my $clause = "";
    if (scalar(@$ids_ref) > 0) {
        if (OracleUtil::useTempTable(scalar(@$ids_ref))) {
            OracleUtil::truncTable($dbh, $tableName);
            OracleUtil::insertDataArray($dbh, $tableName, $ids_ref);
            $clause .= "$idColName in (select id from $tableName) ";
        } else {
            my $join_str = join(',', @$ids_ref);
            $clause .= "$idColName in ($join_str) ";
        }
    }

    return $clause;
}


#
# cached exec sql
# for now to delete the cache you have to do it manually
# 
# also the first column is a non null field, eg pk id
# for the sql fetch loop to stop
#
#
# input:
# $dbh -db handle
# $sql
# $filename - cache filenamem just the name no path 
# $forceSql - 0 or 1 - 1 to force to do sql
# @binds - list of bind vars 
#
# return:
# ref array of arrays
#
sub execSqlCached {
    my($dbh, $sql, $filename, $forceSql, @binds) = @_;
    my $cacheDir = '/webfs/scratch/img/sqlcache/';
    if( $env->{img_ken_localhost}){
        $cacheDir = '/tmp/';
    }
    
    my $cache = HtmlUtil::isCgiCacheEnable();
    if(!$cache) {
        # user turn off caching
        $forceSql = 1;
    }
    
    # use a hash key for the file name
    # I still need file name becuz select * from where id = ? always hashes to the same key
    # ? may I should use the binds to append to teh text for uniqueness 
    # - Kenpler array 
    # 
    my $scal = join(",", @binds);
    my $digest1 = sha256_hex($sql . $filename . $scal);
    my $file = $cacheDir . $digest1;
    $file = each %{ { $file, 0 } }; # untaint
    
    if(!$forceSql && -e $file) {
        my $now   = time();
        my $t    = fileAtime($file);
        my $diff = $now - $t;
        my $max_time_diff = 60 * 60 * 48;  # 48 hours
        
        if ( $diff < $max_time_diff ) {
            # read cache file and return data
            webLog("reading cache data for sql:\n $sql\n");
            my $aref = retrieve("$file");
            return $aref;
        }
    }
    
    # exec sql and save it
    my $cur = WebUtil::execSql($dbh, $sql, $verbose, @binds);
    my @data;
    my $cnt = 0;
    for(;;) {
        my @innerArray = $cur->fetchrow();
        last if(!$innerArray[0]);
        push(@data, \@innerArray );
        $cnt++;
    }
    
    # cache data
    webLog("caching rows " . $#data . "\n");
    store \@data, "$file";
     
    return \@data;
} 

1;
