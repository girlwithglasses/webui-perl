package OperonFile;
########################################################
# functions that return sql queries
# used in Operons.pm
#
# $Id: OperonFile.pm 29739 2014-01-07 19:11:08Z klchu $
########################################################
use strict;

use CGI qw( :standard );
use DBI;

use Data::Dumper;
use WebConfig;
use WebUtil;
use OperonSQL;
use OracleUtil;
use QueryUtil;

my $env         = getEnv();
my $cgi_dir     = $env->{cgi_dir};
my $cgi_tmp_dir = $env->{cgi_tmp_dir};    # application tmp directory
my $main_cgi    = $env->{main_cgi};
my $verbose     = $env->{verbose};
my $tmp_dir     = $env->{tmp_dir};        # viewable image tmp directory
my $tmp_url     = $env->{tmp_url};

my $OPERON_DATA_DIR = $env->{operon_data_dir};
my $COG_DATA_DIR    = "$OPERON_DATA_DIR/cog_coeff";
my $PFAM_DATA_DIR   = "$OPERON_DATA_DIR/pfam_coeff";
my $BBH_DATA_DIR    = "$OPERON_DATA_DIR/bbh_coeff";

# test cog COG0714
# http://localhost/~ken/cgi-bin/web25.htd/main.cgi?section=Operon&page=geneConnections&genePageGeneOid=641275938&expansion=2&clusterMethod=cog
sub getCoeff {
    my ( $dbh, $func_aref, $type ) = @_;

    printStartWorkingDiv();

    # hash func id => array of tab delimited string
    my %hash;

    # read files
    foreach my $file (@$func_aref) {
        print "Reading file: $file<br/>\n";

        # file
        my $fh;
        if ( $type eq 'bbh' ) {
            if ( -e "$BBH_DATA_DIR/" . uc($file) ) {
                $fh = newReadFileHandle( "$BBH_DATA_DIR/" . uc($file) );
            } else {
                $fh = newReadFileHandle( "$BBH_DATA_DIR/" . lc($file) );
            }
        } elsif ( $type eq 'pfam' ) {
            if ( -e "$PFAM_DATA_DIR/" . lc($file) ) {
                $fh = newReadFileHandle( "$PFAM_DATA_DIR/" . lc($file) );
            } else {
                $fh = newReadFileHandle( "$PFAM_DATA_DIR/" . uc($file) );
            }
        } else {
            if ( -e "$COG_DATA_DIR/" . uc($file) ) {
                $fh = newReadFileHandle( "$COG_DATA_DIR/" . uc($file) );
            } else {
                $fh = newReadFileHandle( "$COG_DATA_DIR/" . lc($file) );
            }
        }

        my $count = 0;
        print "Reading..";

        my @a;
        $hash{$file} = \@a;
        while ( my $s = $fh->getline() ) {
            chomp $s;
            my @tmp = split( /\t/, $s );

            # skip records
            next if ( $tmp[0] eq $tmp[1] );

            # commCassTaxaNo col
            next if ( $type ne 'bbh' && $tmp[5] < 1 );
            next if ( $type eq 'bbh' && $tmp[5] <= 0 );

            my $aref = $hash{$file};
            push( @$aref, $s );

            if ( $count % 100 == 0 ) {
                print "..";
            }

            $count++;
        }
        close $fh;
        print "<br/>\n";
    }

    print "Getting function names.<br/>\n";
    my $func_href;
    if ( $type eq 'bbh' ) {

        # TODO there are 200k bbh's should I add the func id to the query?
        $func_href = getBbhNames($dbh);
    } elsif ( $type eq 'pfam' ) {
        $func_href = QueryUtil::getAllPfamNames($dbh);
    } else {
        $func_href = QueryUtil::getAllCogNames($dbh);
    }

    my @results;

    print "Creating records.<br/>\n";
    foreach my $key ( keys %hash ) {
        my $aref = $hash{$key};

        foreach my $line (@$aref) {
            my (
                $gene1,            $gene2,      $taxa1,
                $taxa2,            $commTaxaNo, $commCassTaxaNo,
                $commFusionTaxaNo, $coeff_gts,  $coeff_gns,
                $coeff_gfs
              )
              = split( /\t/, $line );

            my $name1 = $func_href->{$gene1};
            my $name2 = $func_href->{$gene2};

            push( @results,
                    "$gene1\t$name1\t$gene2\t$name2\t$taxa1\t$taxa2\t"
                  . "$commTaxaNo\t$commCassTaxaNo\t$commFusionTaxaNo\t"
                  . "$coeff_gts\t$coeff_gns\t$coeff_gfs" );
        }
    }

    printEndWorkingDiv();
    return \@results;
}

sub getFamilyConnections {
    my ( $dbh, $cluster_id_aref, $type ) = @_;

    # query func ids to ignore
    #    my %cluster_id_hash;
    #    foreach my $x (@$cluster_id_aref) {
    #        $cluster_id_hash{ uc($x) } = "";
    #    }

    # hash set of gene1 to gene2 already seen
    # key will be  func1 . "_" . func2
    # object is ""
    my %ignore_pairs;

    printStartWorkingDiv();
    print "Getting families.<br/>\n";

    # list of families from query protein
    my @families = OperonSQL::getFamily( $cluster_id_aref, $type );

    # func id => hash set of family ids
    my $family_href;
    if ( lc($type) eq "bbh" ) {
        $family_href = getBbhFamily( $dbh, \@families );
    } elsif ( lc($type) eq "pfam" ) {
        $family_href = getPfamFamily( $dbh, \@families );
    } else {
        $family_href = getCogFamily( $dbh, \@families );
    }

    # hash func id => array of tab delimited string
    my %hash;

    # read files
    foreach my $file ( keys %$family_href ) {
        print "Reading file: $file<br/>\n";

        # file
        my $fh;
        if ( $type eq 'bbh' ) {
            if ( -e "$BBH_DATA_DIR/" . uc($file) ) {
                $fh = newReadFileHandle( "$BBH_DATA_DIR/" . uc($file) );
            } else {
                $fh = newReadFileHandle( "$BBH_DATA_DIR/" . lc($file) );
            }
        } elsif ( $type eq 'pfam' ) {
            if ( -e "$PFAM_DATA_DIR/" . lc($file) ) {
                $fh = newReadFileHandle( "$PFAM_DATA_DIR/" . lc($file) );
            } else {
                $fh = newReadFileHandle( "$PFAM_DATA_DIR/" . uc($file) );
            }
        } else {
            if ( -e "$COG_DATA_DIR/" . uc($file) ) {    
                $fh = newReadFileHandle( "$COG_DATA_DIR/" . uc($file) );
            } else {
                $fh = newReadFileHandle( "$COG_DATA_DIR/" . lc($file) );
            }
        }

        my $count = 0;
        print "Reading..";

        # currect file or func id family ids
        my $f_href = $family_href->{$file};

        my @a;
        $hash{$file} = \@a;
        while ( my $s = $fh->getline() ) {
            chomp $s;
            my @tmp = split( /\t/, $s );

            # skip records
            #  coeff_gns col
            next if ( $tmp[8] <= 0 );

            # ignore gene2 if query gene / func id
            #if ( exists $cluster_id_hash{ uc( $tmp[1] ) } ) {

            #print "==== $tmp[1]  <br/>";
            #   next;
            #}

            # check to see if pair is already seen
            next if ( exists $ignore_pairs{ $tmp[0] . "_" . $tmp[1] } );
            next if ( exists $ignore_pairs{ $tmp[1] . "_" . $tmp[0] } );

            # 2nd col is gene2 / func
            # so gene 1 fam and gene 2 fam must match
            my $f_href2 = $family_href->{ $tmp[1] };
            my $found   = 0;
            foreach my $key2 ( keys %$f_href2 ) {
                if ( exists $f_href->{$key2} ) {
                    $found = 1;
                    last;
                }
            }
            next if ( $found == 0 );

            my $aref = $hash{$file};
            push( @$aref, $s );

            $ignore_pairs{ $tmp[0] . "_" . $tmp[1] } = "";

            if ( $count % 100 == 0 ) {
                print ".";
            }

            $count++;
        }
        close $fh;
        print "<br/>\n";
    }

    print "Getting function names.<br/>\n";
    my $func_href;
    if ( $type eq 'bbh' ) {

        # TODO there are 200k bbh's should I add the func id to the query?
        $func_href = getBbhNames($dbh);
    } elsif ( $type eq 'pfam' ) {
        $func_href = QueryUtil::getAllPfamNames($dbh);
    } else {
        $func_href = QueryUtil::getAllCogNames($dbh);
    }

    my @results;
    print "Creating records.<br/>\n";
    foreach my $key ( keys %hash ) {
        my $aref = $hash{$key};

        foreach my $line (@$aref) {
            my (
                $gene1,            $gene2,      $taxa1,
                $taxa2,            $commTaxaNo, $commCassTaxaNo,
                $commFusionTaxaNo, $coeff_gts,  $coeff_gns,
                $coeff_gfs
              )
              = split( /\t/, $line );

            my $name1 = $func_href->{$gene1};
            my $name2 = $func_href->{$gene2};

            #  gene1,gene2,coeff_gts,coeff_gns,coeff_gfs,c1.cog_name,c2.cog_name
            push( @results,
                    "$gene1\t$gene2\t"
                  . "$coeff_gts\t$coeff_gns\t$coeff_gfs\t"
                  . "$name1\t$name2" );
        }
    }

    printEndWorkingDiv();
    return \@results;

}

sub getCogFamily {
    my ( $dbh, $func_aref ) = @_;

    # quote elements
    my $str;
    if(OracleUtil::useTempTable(scalar(@$func_aref))) {
        OracleUtil::insertDataArray($dbh, "gtt_func_id", \@$func_aref);
        $str = " select id from gtt_func_id ";
    } else {
        $str = "'" . join("','", @$func_aref) . "'";
    }

    my $sql = qq{
        select cog_id, families
        from cog_families 
        where families in ($str)
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $oid, $name ) = $cur->fetchrow();
        last if !$oid;

        if ( exists $hash{$oid} ) {
            my $tmp = $hash{$oid};
            $tmp->{$name} = "";
        } else {
            my %tmp;
            $tmp{$name} = "";
            $hash{$oid} = \%tmp;
        }

    }

    $cur->finish();
    OracleUtil::truncTable($dbh, "gtt_func_id") if(OracleUtil::useTempTable(scalar(@$func_aref)));
    return \%hash;
}

sub getPfamFamily {
    my ( $dbh, $func_aref ) = @_;

    # quote elements
    my $str;
    if(OracleUtil::useTempTable(scalar(@$func_aref))) {
        OracleUtil::insertDataArray($dbh, "gtt_func_id", \@$func_aref);
        $str = " select id from gtt_func_id ";
    } else {
        $str = "'" . join("','", @$func_aref) . "'";
    }

    my $sql = qq{
        select ext_accession, families
        from pfam_family_families  
        where families in ($str)
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $oid, $name ) = $cur->fetchrow();
        last if !$oid;

        if ( exists $hash{$oid} ) {
            my $tmp = $hash{$oid};
            $tmp->{$name} = "";
        } else {
            my %tmp;
            $tmp{$name} = "";
            $hash{$oid} = \%tmp;
        }

    }
    $cur->finish();
    OracleUtil::truncTable($dbh, "gtt_func_id") if(OracleUtil::useTempTable(scalar(@$func_aref)));
    return \%hash;
}

sub getBbhFamily {
    my ( $dbh, $func_aref ) = @_;

    # quote elements
    my $str;
    if(OracleUtil::useTempTable(scalar(@$func_aref))) {
        OracleUtil::insertDataArray($dbh, "gtt_func_id", \@$func_aref);
        $str = " select id from gtt_func_id ";
    } else {
        $str = "'" . join("','", @$func_aref) . "'";
    }

    my $sql = qq{
        select cluster_id, families
        from bbh_cluster_families
        where families in ($str)
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $oid, $name ) = $cur->fetchrow();
        last if !$oid;

        if ( exists $hash{$oid} ) {
            my $tmp = $hash{$oid};
            $tmp->{$name} = "";
        } else {
            my %tmp;
            $tmp{$name} = "";
            $hash{$oid} = \%tmp;
        }
    }

    $cur->finish();
    OracleUtil::truncTable($dbh, "gtt_func_id") if(OracleUtil::useTempTable(scalar(@$func_aref)));    
    return \%hash;
}

sub getBbhNames {
    my ($dbh) = @_;

    my %hash;

    my $sql = qq{
        select cluster_id, cluster_name
        from bbh_cluster
    };

    my $count = 0;
    my $dotcnt = 0;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $oid, $name ) = $cur->fetchrow();
        last if !$oid;
        $hash{$oid} = $name;

        if ( $count % 1000 == 0 ) {
            print "..";
            $dotcnt++;
        }
        if($dotcnt % 80 == 0) {
            print "<br/>\n";
            $dotcnt = 0;
        }

        $count++;
    }

    $cur->finish();

    print "<br/>\n";

    return \%hash;
}

1;
