############################################################################
# LoadGeneImgTerm.pm - load Gene and IMG term association
#
# $Id: LoadGeneImgTerm.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package LoadGeneImgTerm;
use strict;
use Data::Dumper;
use DBI;

# Force flush
$| = 1;

my $line_no = 0;

###########################################################################
# load - the main loading function
###########################################################################
sub load {
    my ( $dsn, $user, $pw, $in_f_name, $data_dir, $replace ) = @_;

    my $gene_function_file = $data_dir . "/gene_img_functions.tab.txt";
    my $term_file          = $data_dir . "/img_term.tab.txt";
    my $synonym_file       = $data_dir . "/img_term_synonyms.tab.txt";

    my $dbh = DBI->connect( "dbi:Oracle:$dsn", $user, $pw );
    if ( !defined($dbh) ) {
        die "Cannot login as $user/$pw\@dsn\n";
    }
    $dbh->{LongTruncOk} = 1;

    my $contact_oid =
      findID( $dbh, "CONTACT", "contact_oid", "lower(username)", lc $user );
    my $max_term_oid = findMaxID( $dbh, "IMG_TERM", "term_oid" );

    my %term_h;
    my %f_order_h;

    my %gene_term_data;
    my %term_data;
    my %synonym_data;

    my $key;
    my $val;

    my $line;
    $line_no = 0;

    my $alt_table_name = "";

    my $tables_th = $dbh->table_info();
    while ( my ( $qual, $owner, $name, $type, $remarks ) =
            $tables_th->fetchrow_array() )
    {
        if ( uc($owner) eq uc($user) ) {
            if (    uc($name) eq "GENE_ALT_IDENTIFIERS"
                 || uc($name) eq "GENE_REPLACEMENTS" )
            {
                $alt_table_name = $name;
            }
        }
    }

    open( FILE, $in_f_name ) or die "Cannot open file $in_f_name\n";

    while ( $line = <FILE> ) {
        my ( $gene_oid, $term ) = split( /\t/, $line );

        $line_no++;

        # check Gene OID
        if ( isInt($gene_oid) == 0 ) {
            print
"Error (line $line_no): Gene ID '$gene_oid' must be an integer.\n";
            next;
        }
        my ( $found, $product, $new_gene_oid ) =
          checkGeneOid( $dbh, $gene_oid, $alt_table_name );
        if ( !$found ) {
            print
              "Error (line $line_no): Gene ID '$gene_oid' does not exist.\n";
            next;
        }

        # check to see whether gene_oid is an alternate oid
        if ( $new_gene_oid ne $gene_oid ) {
            print
"Warning (line $line_no): Input gene_oid '$gene_oid' is mapped to '$new_gene_oid'.\n";
            $gene_oid = $new_gene_oid;
        }

        # get f_order
        if ( !$f_order_h{$gene_oid} ) {
            if ($replace) {

                # replace mode - start with 0
                $f_order_h{$gene_oid} = 0;
            } else {

                # add mode - check database to get next f_order
                my $j = getFOrder( $dbh, $gene_oid );
                $f_order_h{$gene_oid} = $j;
            }
        }

        # check term
        # remove leading, trailing spaces, and double quotes
        $term = removeQuoteSpace($term);
        if ( length($term) == 0 ) {
            print "Error (line $line_no): Term is blank.\n";
            next;
        }

        my $lc_term = lc $term;
        if ( $term_h{$lc_term} ) {

            # already there
            my $term_oid = $term_h{$lc_term};
            my %cond_h;
            $cond_h{"term_oid"} = $term_oid;
            my $s1 = $product;
            $s1 =~ s/'/''/g;
            $cond_h{"lower(synonyms)"} = "'" . ( lc $s1 ) . "'";
            if (
                 !isPseudo($product)
                 && !isInDatabase( $dbh, "IMG_TERM_SYNONYMS", "synonyms",
                                   \%cond_h )
              )
            {

                # add to IMG_TERM_SYNONYMS
                $key = "$term_oid $product";
                if ( !$synonym_data{$key} ) {
                    $val = "$term_oid\t$product\t$contact_oid\n";
                    $synonym_data{$key} = $val;
                }
            }

            # add to GENE_IMG_FUNCTIONS
            $key = "$gene_oid $term_oid";
            if ( !$gene_term_data{$key} ) {

                # check database to see whether the association is already there
                my %cond_h;
                $cond_h{"gene_oid"} = $gene_oid;
                $cond_h{"function"} = $term_oid;
                if (
                     !isInDatabase( $dbh,       "GENE_IMG_FUNCTIONS",
                                    "gene_oid", \%cond_h )
                  )
                {

                    # add
                    my $f_order = $f_order_h{$gene_oid};
                    $val = "$gene_oid\t$term_oid\t$f_order\t$contact_oid\tM\n";
                    $gene_term_data{$key} = $val;
                    $f_order_h{$gene_oid} = $f_order;
                }
            }
        } else {
            my $term_oid = findTerm( $dbh, $term );
            if ( $term_oid < 0 ) {

                # new term
                print "Warning (line $line_no): Term '$term' does not exist.\n";

                $max_term_oid++;
                $term_oid = $max_term_oid;

                # add to IMG_TERM and IMG_TERM_SYNONYMS
                $key = $term_oid;
                $val = "$term_oid\t$term\tGENE PRODUCT\t$contact_oid\tNo\n";
                $term_data{$key} = $val;

                if ( !isPseudo($product) ) {
                    $key = "$term_oid $product";
                    if ( !$synonym_data{$key} ) {
                        $val = "$term_oid\t$product\t$contact_oid\n";
                        $synonym_data{$key} = $val;
                    }
                }

                $term_h{$lc_term} = $term_oid;

                # add to GENE_IMG_FUNCTIONS
                $key = "$gene_oid $term_oid";
                if ( !$gene_term_data{$key} ) {
                    my %cond_h;
                    $cond_h{"gene_oid"} = $gene_oid;
                    $cond_h{"function"} = $term_oid;
                    if (
                         !isInDatabase( $dbh,       "GENE_IMG_FUNCTIONS",
                                        "gene_oid", \%cond_h )
                      )
                    {
                        my $f_order = $f_order_h{$gene_oid};
                        $val =
                          "$gene_oid\t$term_oid\t$f_order\t$contact_oid\tM\n";
                        $gene_term_data{$key} = $val;
                        $f_order_h{$gene_oid} = $f_order++;
                    }
                }
            } else {

                # existing term
                $term_h{$lc_term} = $term_oid;

                my %cond_h;
                $cond_h{"term_oid"} = $term_oid;
                my $s1 = $product;
                $s1 =~ s/'/''/g;
                $cond_h{"lower(synonyms)"} = "'" . ( lc $s1 ) . "'";
                if (
                     !isPseudo($product)
                     && !isInDatabase( $dbh,       "IMG_TERM_SYNONYMS",
                                       "synonyms", \%cond_h )
                  )
                {

                    # add to IMG_TERM_SYNONYMS
                    $key = "$term_oid $product";
                    if ( !$synonym_data{$key} ) {
                        $val = "$term_oid\t$product\t$contact_oid\n";
                        $synonym_data{$key} = $val;
                    }
                }

                # add to GENE_IMG_FUNCTIONS
                $key = "$gene_oid $term_oid";
                if ( !$gene_term_data{$key} ) {
                    my %cond_h;
                    $cond_h{"gene_oid"} = $gene_oid;
                    $cond_h{"function"} = $term_oid;
                    if (
                         !isInDatabase( $dbh,       "GENE_IMG_FUNCTIONS",
                                        "gene_oid", \%cond_h )
                      )
                    {
                        my $f_order = $f_order_h{$gene_oid};
                        $val =
                          "$gene_oid\t$term_oid\t$f_order\t$contact_oid\tM\n";
                        $gene_term_data{$key} = $val;
                        $f_order_h{$gene_oid} = $f_order++;
                    }
                }
            }
        }
    }

    close(FILE);

    # generate output files
    # output gene_img_functions.tab.txt
    open( GENE_FUNCTION, '>', $gene_function_file )
      or die "Cannot open file $gene_function_file\n";
    print GENE_FUNCTION "gene_oid\tfunction\tf_order\tmodified_by\tf_flag\n";
    for $key ( sort ( keys %gene_term_data ) ) {
        print GENE_FUNCTION $gene_term_data{$key};
    }
    close(GENE_FUNCTION);

    # output img_term.tab.txt
    open( TERM, '>', $term_file )
      or die "Cannot open file $term_file\n";
    print TERM "term_oid\tterm\tterm_type\tmodified_by\tis_valid\n";
    for $key ( sort ( keys %term_data ) ) {
        print TERM $term_data{$key};
    }
    close(TERM);

    # output img_term_synonyms.tab.txt
    open( SYNONYM, '>', $synonym_file )
      or die "Cannot open file $synonym_file\n";
    print SYNONYM "term_oid\tsynonyms\tmodified_by\n";
    for $key ( sort ( keys %synonym_data ) ) {
        print SYNONYM $synonym_data{$key};
    }
    close(SYNONYM);

    #$dbh->disconnect();
}

#############################################################################
# checkGeneOid
#############################################################################
sub checkGeneOid {
    my ( $dbh, $gene_oid, $alt_table_name ) = @_;

    my $found        = 0;
    my $prod         = "";
    my $new_gene_oid = "";

    if ( isInt($gene_oid) == 0 ) {
        return ( $found, $prod, $new_gene_oid );
    }

    my $sql =
      "select gene_oid, product_name from GENE where gene_oid = ?";

    my $cur = $dbh->prepare($sql)
      || return ( 0, $prod, $new_gene_oid );
    $cur->execute($gene_oid)
      || return ( 0, $prod, $new_gene_oid );

    for ( ; ; ) {
        my ( $db_id, $db_val ) = $cur->fetchrow();
        last if !$db_id;

        $found        = 1;
        $prod         = $db_val;
        $new_gene_oid = $gene_oid;
    }

    if ($found) {
        return ( $found, $prod, $new_gene_oid );
    }

    if ( uc($alt_table_name) eq "GENE_REPLACEMENTS" ) {

        # check GENE_REPLACEMENTS (IMG 2.0)
        #? to use $sql = getGeneReplacementSql();
        $sql =
 "select gene_oid from GENE_REPLACEMENTS where old_gene_oid = ?";
    } elsif ( uc($alt_table_name) eq "GENE_ALT_IDENTIFIERS" ) {

        # check GENE_ALT_IDENTIFIERS (IMG 1.*)
        $sql =
"select gene_oid from GENE_ALT_IDENTIFIERS where alt_identifiers = ?";
    } else {
        return ( 0, $prod, $new_gene_oid );
    }

    $cur = $dbh->prepare($sql);
    if ($cur) {
        if ( $cur->execute($gene_oid) ) {
            for ( ; ; ) {
                my ($db_id) = $cur->fetchrow();
                last if !$db_id;

                $found        = 1;
                $new_gene_oid = $db_id;
            }
        }
    }

    if ( $found == 0 ) {
        return ( 0, $prod, $new_gene_oid );
    }

    # get gene product for $new_gene_oid
    $found = 0;
    my $sql =
      "select gene_oid, product_name from GENE where gene_oid = ?";

    my $cur = $dbh->prepare($sql)
      || return ( 0, $prod, $new_gene_oid );
    $cur->execute($new_gene_oid)
      || return ( 0, $prod, $new_gene_oid );

    for ( ; ; ) {
        my ( $db_id, $db_val ) = $cur->fetchrow();
        last if !$db_id;

        $found = 1;
        $prod  = $db_val;
    }

    return ( $found, $prod, $new_gene_oid );
}

#############################################################################
# isInt - Is integer.
#############################################################################
sub isInt {
    my $s = shift;

    if ( $s =~ /^\-{0,1}[0-9]+$/ ) {
        return 1;
    } elsif ( $s =~ /^\+{0,1}[0-9]+$/ ) {
        return 1;
    } else {
        return 0;
    }
}

#############################################################################
# removeQuoteSpace
#############################################################################
sub removeQuoteSpace {
    my $s = shift;

    chomp($s);
    if ( $s =~ /^\s*"(.*)"$/ ) {
        my ($s1) = ( $s =~ /^\s*"(.*)"$/ );
        return $s1;
    }

    my ($s1) = ( $s =~ /^\s*(.*)$/ );
    return $s1;
}

#############################################################################
# isInDatabase
#############################################################################
sub isInDatabase {
    my ( $dbh, $table_name, $attr_name, $cond_ref ) = @_;

    my $found     = 0;
    my $sql       = "select $attr_name from $table_name";
    my $where_and = " where ";
    for my $k ( keys %$cond_ref ) {
        $sql .= $where_and . $k . " = " . $cond_ref->{$k};
        $where_and = " and ";
    }

    my $cur = $dbh->prepare($sql)
      || return 0;
    $cur->execute()
      || return 0;

    for ( ; ; ) {
        my ($db_val) = $cur->fetchrow();
        last if !$db_val;

        $found = 1;
    }

    return $found;
}

#############################################################################
# findTerm - find Img Term OID for term (or synonym)
#
# use case-insensitive match
#############################################################################
sub findTerm {
    my ( $dbh, $term ) = @_;

    my $term_oid = -1;
    my $lc_term  = lc $term;
    #$lc_term =~ s/'/''/g;

    my $sql = "select term_oid from IMG_TERM where lower(term) = ? ";

    my $cur = $dbh->prepare($sql)
      || return -9;
    $cur->execute($lc_term)
      || return -9;

    for ( ; ; ) {
        my ($db_val) = $cur->fetchrow();
        last if !$db_val;

        if ( $term_oid < 0 ) {
            $term_oid = $db_val;
        }
    }

    if ( $term_oid >= 0 ) {
        print "Term: $term, OID: $term_oid\n";
        return $term_oid;
    }

    # now, search for synonym
    $sql =
"select term_oid from IMG_TERM_SYNONYMS where lower(synonyms) = ? ";

    $cur = $dbh->prepare($sql)
      || return -9;
    $cur->execute($lc_term)
      || return -9;

    for ( ; ; ) {
        my ($db_val) = $cur->fetchrow();
        last if !$db_val;

        if ( $term_oid < 0 ) {
            $term_oid = $db_val;
        }
    }

    if ( $term_oid >= 0 ) {
        print "Synonym: $term, OID: $term_oid\n";
    }

    return $term_oid;
}

############################################################################
# findMaxID - find the max ID of a table
############################################################################
sub findMaxID {
    my ( $dbh, $table_name, $attr_name ) = @_;

    # SQL statement
    my $sql = "select max($attr_name) from $table_name";

    my $cur = $dbh->prepare($sql)
      || return 0;
    $cur->execute()
      || return 0;

    my $max_id = 0;
    for ( ; ; ) {
        my ($val) = $cur->fetchrow();
        last if !$val;

        # set max ID
        $max_id = $val;
    }

    return $max_id;
}

############################################################################
# findID - find ID
############################################################################
sub findID {
    my ( $dbh, $table_name, $id_name, $attr_name, $val ) = @_;

    # SQL statement
    #$val =~ s/'/''/g;
    my $sql = "select $id_name from $table_name where $attr_name = ? ";

    my $cur = $dbh->prepare($sql)
      || return 0;
    $cur->execute($val)
      || return 0;

    my $id = "";
    for ( ; ; ) {
        my ($val) = $cur->fetchrow();
        last if !$val;

        # set max ID
        $id = $val;
    }

    return $id;
}

############################################################################
# getFOrder - get the "next" f_order for gene oid
############################################################################
sub getFOrder {
    my ( $dbh, $gene_oid ) = @_;

    my %h;
    my $f_order = 0;

    #exec SQL
    my $sql = qq{ 
	select max(f_order)+1
	    from gene_img_functions 
	    where gene_oid = ? 
	};

    my $cur = $dbh->prepare($sql)
      || return 0;
    $cur->execute($gene_oid)
      || return 0;

    for ( ; ; ) {
        my ($fo) = $cur->fetchrow();
        last if !$fo;

        # get the next number
        $f_order = $fo;
    }    # end for loop

    return $f_order;
}

############################################################################
# isPseudo
############################################################################
sub isPseudo {
    my $val = shift;

    my $s = lc $val;

    require WebUtil;
    if (    WebUtil::blankStr($s)
         || $s =~ /hypothetic/
         || $s =~ /unknown/
         || $s =~ /unnamed/ )
    {
        return 1;
    }

    return 0;
}

1;

