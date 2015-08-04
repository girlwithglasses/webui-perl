############################################################################
# MyFuncCat - My functional categories.   This is mainly to support
#   subsystem comparisons with user defined subsystems.
#   User must be logged in to do this because the categories are
#   associated with the user account.
#     --es 01/19/08
#
# $Id: MyFuncCat.pm 33566 2015-06-11 10:47:36Z jinghuahuang $
############################################################################
package MyFuncCat;
my $section = "MyFuncCat";

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $include_metagenomes  = $env->{include_metagenomes};
my $user_restricted_site = $env->{user_restricted_site};
my $img_lite             = $env->{img_lite};
my $show_private         = $env->{show_private};
my $cog_base_url         = $env->{cog_base_url};
my $pfam_base_url        = $env->{pfam_base_url};
my $enzyme_base_url      = $env->{enzyme_base_url};
my $tigrfam_base_url     = $env->{tigrfam_base_url};

my $max_func_batch = 1000;

############################################################################
# dispatch - Dispatch loop
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "otherFuncCats" ) {
        printOtherFuncCats();
    } elsif ( $page eq "userCat" ) {
        printUserCat();
    } else {
        printEditForm();
    }
}

############################################################################
# printEditForm - Print main data entry form.
############################################################################
sub printEditForm {
    my @func_ids = param("func_id");
    my @a;

    # Get only recognized function types for now.
    for my $func_id (@func_ids) {
        next
          if $func_id !~ /^COG/
          && $func_id !~ /^pfam/
          && $func_id !~ /^EC/
          && $func_id !~ /^TIGR/;
        push( @a, $func_id );
    }
    @func_ids = @a;

    print getHtmlBookmark( "", "<h1>My Function Categories</h1>" );
    print "<p>\n";
    my $url = "$main_cgi?section=AbundanceComparisonsSub";
    my $link = alink( $url, "Function Category Comparisons" );
    print "User defined function categories are meant to be used ";
    print "together with $link.<br/>\n";
    print "</p>\n";

    my $nFuncs = @func_ids;
    if ( $nFuncs > $max_func_batch ) {
        webError(   "Please select less than $max_func_batch functions "
                  . "to add.<br/>\n" );
    }
    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError("Session expired.  Please login again.");
    }

    my $dbh = dbLogin();
    printMainForm();

    ## Check to see if there's anything to update, and do it.
    my $inserted = updateDb( $dbh, $contact_oid );
    if ($inserted) {
        @func_ids = ();
    }
    printStatusLine( "Loading ...", 1 );

    print getHtmlBookmark( "", "<h2>Existing Categories</h2>" );
    print "<p>\n";
    print "Select categories or members to delete.<br/>\n";
    print "</p>\n";
    
    my $sql = qq{
        select mfc.func_db, mfc.cat_oid, mfc.category_name, mfcm.members
        from myfunc_cat mfc, myfunc_cat_members mfcm
        where mfc.cat_oid = mfcm.cat_oid
        and mfc.contact = ?
        order by mfc.func_db, mfc.category_name, mfcm.members
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );

    my @recs;
    my @f_ids;
    for ( ; ; ) {
        my ( $func_db, $cat_oid, $category_name, $func_id ) =
          $cur->fetchrow();
        last if !$cat_oid;

        my $rec = "$func_db\t$cat_oid\t$category_name\t$func_id";        
        push( @recs, $rec );
        push( @f_ids, $func_id );
    }
    my %funcId2Name = QueryUtil::fetchFuncIdAndName($dbh, \@f_ids);
    
    my $count = 0;
    my $old_cat_oid;
    print "<p>\n";
    for my $rec (@recs) {
        my ( $func_db, $cat_oid, $category_name, $func_id ) =
          split( /\t/, $rec );
        next if !$cat_oid;
        $count++;
        
        if ( $old_cat_oid ne "" && $cat_oid ne $old_cat_oid ) {
            print "<br/>\n";
        }
        if ( $cat_oid ne $old_cat_oid ) {
            print "<input type='checkbox' name='del_cat_oid' ";
            print "value='$cat_oid' />\n";
            print nbsp(1);
            print "<b>\n";
            print escHtml($category_name);
            print "</b>\n";
            print "<br/>\n";
        }
        print nbsp(2);
        print "<input type='checkbox' name='del_cat_func_id' ";
        print "value='${cat_oid} ${func_id}' />\n";
        if ( $func_id =~ /^COG/ ) {
            print alink( "$cog_base_url$func_id", $func_id );
        } elsif ( $func_id =~ /^pfam/ ) {
            my $id2 = $func_id;
            $id2 =~ s/pfam/PF/;
            print alink( "$pfam_base_url$id2", $func_id );
        } elsif ( $func_id =~ /^EC/ ) {
            print alink( "$enzyme_base_url$func_id", $func_id );
        } elsif ( $func_id =~ /^TIGR/ ) {
            print alink( "$tigrfam_base_url$func_id", $func_id );
        }
        print " - ";
        my $func_name = $funcId2Name{$func_id};        
        print escHtml($func_name);
        print "<br/>\n";
        $old_cat_oid = $cat_oid;
    }
    $cur->finish();
    print "</p>\n";
    
    if ( $count == 0 ) {
        print "<p>\n";
        print "<i>\n";
        print "(No user defind categories found for me.)<br/>\n";
        print "</i>\n";
        print "</p>\n";
    }
    
    my $otherCount = countOtherFuncCat( $dbh, $contact_oid );
    if ( $otherCount > 0 ) {
        my $url = "$section_cgi&page=otherFuncCats";
        print alink( $url, "Other User Functional Categories" );
        print "<br/>\n";
    }

    if ( !$inserted && $nFuncs > 0 ) {
        print getHtmlBookmark( "", "<h2>New Categories</h2>" );
        print "<p>\n";
        print "Fill in new category name to add new categories.<br/>\n";
        print "</p>\n";
    }

    ## COG
    my @cog_ids;
    for my $func_id (@func_ids) {
        next if $func_id !~ /^COG/;
        push( @cog_ids, $func_id );
    }
    printCogEntries( $dbh, \@cog_ids );

    ## Pfam
    my @pfam_ids;
    for my $func_id (@func_ids) {
        next if $func_id !~ /^pfam/;
        push( @pfam_ids, $func_id );
    }
    printPfamEntries( $dbh, \@pfam_ids );

    ## Enzyme
    my @enzyme_ids;
    for my $func_id (@func_ids) {
        next if $func_id !~ /^EC/;
        push( @enzyme_ids, $func_id );
    }
    printEnzymeEntries( $dbh, \@enzyme_ids );

    ## TIGRfam
    my @tigrfam_ids;
    for my $func_id (@func_ids) {
        next if $func_id !~ /^TIGR/;
        push( @tigrfam_ids, $func_id );
    }
    printTigrfamEntries( $dbh, \@tigrfam_ids );

    ## hidden variables for next form
    for my $func_id (@func_ids) {
        print hiddenVar( "func_id", $func_id );
    }

    if ( $nFuncs > 0 || $count > 0 ) {
        my $name = "_section_${section}_editForm";
        print submit(
                      -name  => $name,
                      -value => "Update Database",
                      -class => "meddefbutton"
        );
        print nbsp(1);
        print reset( -class => "smbutton" );
        print nbsp(1);
        my $name = "_section_FuncCartStor_funcCartForm";
        print submit(
                      -name  => $name,
                      -value => "Return to Function Cart",
                      -class => "medbutton"
        );
        print "<br/>\n";
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printCogEntries - Print new COG entries.
############################################################################
sub printCogEntries {
    my ( $dbh, $ids_aref ) = @_;

    my $id_str = joinSqlQuoted( ',', @$ids_aref );
    return if $id_str eq "";

    print "<font size='-1'>\n";
    print "Enter new COG category name.<br/>\n";
    print "</font>\n";
    print "<input type='text' name='cog_cat' size='70' />\n";
    print "<br/>\n";
    print "<p>\n";

    my $sql = qq{
        select c.cog_id, c.cog_name
	from cog c
	where c.cog_id in( $id_str )
	order by c.cog_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        print nbsp(2);
        print alink( "$cog_base_url$id", $id );
        print " - ";
        print escHtml($name);
        print "<br/>\n";
    }
    $cur->finish();
    print "<br/>\n";
    print "</p>\n";
}

############################################################################
# printPfamEntries - Print new Pfam entries.
############################################################################
sub printPfamEntries {
    my ( $dbh, $ids_aref ) = @_;

    my $id_str = joinSqlQuoted( ',', @$ids_aref );
    return if $id_str eq "";

    print "<font size='-1'>\n";
    print "Enter new Pfam category name.<br/>\n";
    print "</font>\n";
    print "<input type='text' name='pfam_cat' size='70' />\n";
    print "<br/>\n";
    print "<p>\n";

    my $sql = qq{
        select pf.ext_accession, pf.name
	from pfam_family pf
	where pf.ext_accession in( $id_str )
	order by pf.name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        print nbsp(2);
        my $id2 = $id;
        $id2 =~ s/pfam/PF/;
        print alink( "$pfam_base_url$id2", $id );
        print " - ";
        print escHtml($name);
        print "<br/>\n";
    }
    $cur->finish();
    print "<br/>\n";
    print "</p>\n";
}

############################################################################
# printEnzymeEntries - Print new enzyme entries.
############################################################################
sub printEnzymeEntries {
    my ( $dbh, $ids_aref ) = @_;

    my $id_str = joinSqlQuoted( ',', @$ids_aref );
    return if $id_str eq "";

    print "<font size='-1'>\n";
    print "Enter new enzyme category name.<br/>\n";
    print "</font>\n";
    print "<input type='text' name='enzyme_cat' size='70' />\n";
    print "<br/>\n";
    print "<p>\n";

    my $sql = qq{
         select ez.ec_number, ez.enzyme_name
	 from enzyme ez
	 where ez.ec_number in( $id_str )
	 order by ez.enzyme_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        print nbsp(2);
        print alink( "$enzyme_base_url$id", $id );
        print " - ";
        print escHtml($name);
        print "<br/>\n";
    }
    $cur->finish();
    print "<br/>\n";
    print "</p>\n";
}

############################################################################
# printTigrfamEntries - Print new TIGRfam entries.
############################################################################
sub printTigrfamEntries {
    my ( $dbh, $ids_aref ) = @_;

    my $id_str = joinSqlQuoted( ',', @$ids_aref );
    return if $id_str eq "";

    print "<font size='-1'>\n";
    print "Enter new TIGRfam category name.<br/>\n";
    print "</font>\n";
    print "<input type='text' name='tigrfam_cat' size='70' />\n";
    print "<br/>\n";
    print "<p>\n";

    my $sql = qq{
        select tf.ext_accession, tf.expanded_name
	from tigrfam tf
	where tf.ext_accession in( $id_str )
	order by tf.expanded_name
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        print nbsp(2);
        print alink( "$tigrfam_base_url$id", $id );
        print " - ";
        print escHtml($name);
        print "<br/>\n";
    }
    $cur->finish();
    print "<br/>\n";
    print "</p>\n";
}

############################################################################
# updateDb - Update database from previous form, if any.
############################################################################
sub updateDb {
    my ( $dbh, $contact_oid ) = @_;
    my @del_cat_oids     = param("del_cat_oid");
    my @del_cat_func_ids = param("del_cat_func_id");
    my $cog_cat          = param("cog_cat");
    my $pfam_cat         = param("pfam_cat");
    my $enzyme_cat       = param("enzyme_cat");
    my $tigrfam_cat      = param("tigrfam_cat");
    my @func_ids         = param("func_id");

    # Strip preceding and trailing spaces
    $cog_cat     =~ s/^\s+//;
    $cog_cat     =~ s/\s+$//;
    $pfam_cat    =~ s/^\s+//;
    $pfam_cat    =~ s/\s+$//;
    $enzyme_cat  =~ s/^\s+//;
    $enzyme_cat  =~ s/\s+$//;
    $tigrfam_cat =~ s/^\s+//;
    $tigrfam_cat =~ s/\s+$//;

    # SQL single quote escapes
    my $cog_cat2 = $cog_cat;
    $cog_cat2 =~ s/'/''/;
    my $pfam_cat2 = $pfam_cat;
    $pfam_cat2 =~ s/'/''/;
    my $enzyme_cat2 = $enzyme_cat;
    $enzyme_cat2 =~ s/'/''/;
    my $tigrfam_cat2 = $tigrfam_cat;
    $tigrfam_cat2 =~ s/'/''/;

    return if !$contact_oid;

    ## Check for existing names.
    my $sql = qq{
        select count(*)
	from myfunc_cat
	where contact = ?
	and func_db = 'COG'
	and category_name = ?
     };
    checkNameExists( $dbh, $sql, $cog_cat, $contact_oid, $cog_cat2 );
    my $sql = qq{
        select count(*)
	from myfunc_cat
	where contact = ?
	and func_db = 'pfam'
	and category_name = ?
     };
    checkNameExists( $dbh, $sql, $pfam_cat, $contact_oid, $pfam_cat2 );
    my $sql = qq{
        select count(*)
	from myfunc_cat
	where contact = ?
	and func_db = 'EC'
	and category_name = ?
     };
    checkNameExists( $dbh, $sql, $enzyme_cat, $contact_oid, $enzyme_cat2 );
    my $sql = qq{
        select count(*)
	from myfunc_cat
	where contact = ?
	and func_db = 'TIGR'
	and category_name = ?
     };
    checkNameExists( $dbh, $sql, $tigrfam_cat, $contact_oid, $tigrfam_cat2 );

    execSqlOnly( $dbh, "commit work" );
    execSqlOnly( $dbh, "set transaction read write" );

    my $sql = qq{
         select max( cat_oid )
	 from myfunc_cat
     };
    my $cur = execSql( $dbh, $sql, $verbose );
    my $next_cat_oid = $cur->fetchrow();
    $next_cat_oid++;
    $cur->finish();

    printStartWorkingDiv();

    for my $del_cat_func_id (@del_cat_func_ids) {
        my ( $cat_oid, $func_id ) = split( / /, $del_cat_func_id );
        my $category_name = catOid2Name( $dbh, $cat_oid );
        print "deleting function <i>$func_id</i> in <i>";
        print escHtml($category_name);
        print "</i>...<br/>\n";
        my $sql = qq{
	    delete from myfunc_cat_members mfcm
	    where mfcm.cat_oid = $cat_oid
	    and mfcm.members = '$func_id'
	 };
        execSqlOnly( $dbh, $sql );
    }
    for my $del_cat_oid (@del_cat_oids) {
        my $category_name = catOid2Name( $dbh, $del_cat_oid );
        print "deleting category <i>";
        print escHtml($category_name);
        print "</i>...<br/>\n";
        my $sql = qq{
	    delete from myfunc_cat_members mfcm
	    where mfcm.cat_oid = $del_cat_oid
	 };
        execSqlOnly( $dbh, $sql );
        my $sql = qq{
	    delete from myfunc_cat mfc
	    where mfc.cat_oid = $del_cat_oid
	    and mfc.contact = $contact_oid
	 };
        execSqlOnly( $dbh, $sql );
    }

    ## Delete categories that don't have any members.
    my $sql = qq{
        select mfc.cat_oid
	from myfunc_cat mfc
	where mfc.cat_oid not in(
	   select distinct x.cat_oid
	   from myfunc_cat_members x
	)
     };
    my @del_lone_cat_oids;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($cat_oid) = $cur->fetchrow();
        last if !$cat_oid;
        push( @del_lone_cat_oids, $cat_oid );
    }
    $cur->finish();
    for my $cat_oid (@del_lone_cat_oids) {
        my $sql = qq{
	   delete from myfunc_cat
	   where cat_oid = $cat_oid
	};
        execSqlOnly( $dbh, $sql, $verbose );
    }

    my $inserted = 0;
    if ( $cog_cat ne "" ) {
        print "Inserting <i>" . escHtml($cog_cat) . "</i>...<br/>\n";
        my $sql = qq{
	     insert into myfunc_cat( cat_oid, category_name,
	        contact, func_db )
	     values( $next_cat_oid, '$cog_cat2', $contact_oid, 'COG' )
	 };
        execSqlOnly( $dbh, $sql, $verbose );
        for my $func_id (@func_ids) {
            next if $func_id !~ /^COG/;
            print nbsp(2);
            print "Inserting <i>$func_id</i>...<br/>\n";
            my $sql = qq{
	        insert into myfunc_cat_members( cat_oid, members )
		values( $next_cat_oid, '$func_id' )
	     };
            execSqlOnly( $dbh, $sql, $verbose );
        }
        $next_cat_oid++;
        $inserted = 1;
    }

    if ( $pfam_cat ne "" ) {
        print "Inserting <i>" . escHtml($pfam_cat) . "</i>...</br/>\n";
        my $sql = qq{
	     insert into myfunc_cat( cat_oid, category_name,
	        contact, func_db )
	     values( $next_cat_oid, '$pfam_cat2', $contact_oid, 'pfam' )
	 };
        execSqlOnly( $dbh, $sql, $verbose );
        for my $func_id (@func_ids) {
            next if $func_id !~ /^pfam/;
            print nbsp(2);
            print "Inserting <i>$func_id</i>...<br/>\n";
            my $sql = qq{
	        insert into myfunc_cat_members( cat_oid, members )
		values( $next_cat_oid, '$func_id' )
	     };
            execSqlOnly( $dbh, $sql, $verbose );
        }
        $next_cat_oid++;
        $inserted = 1;
    }

    if ( $enzyme_cat ne "" ) {
        print "Inserting <i>" . escHtml($enzyme_cat) . "</i>...</br/>\n";
        my $sql = qq{
	     insert into myfunc_cat( cat_oid, category_name,
	        contact, func_db )
	     values( $next_cat_oid, '$enzyme_cat2', $contact_oid, 'EC' )
	 };
        execSqlOnly( $dbh, $sql, $verbose );
        for my $func_id (@func_ids) {
            next if $func_id !~ /^EC/;
            print nbsp(2);
            print "Inserting <i>$func_id</i>...<br/>\n";
            my $sql = qq{
	        insert into myfunc_cat_members( cat_oid, members )
		values( $next_cat_oid, '$func_id' )
	     };
            execSqlOnly( $dbh, $sql, $verbose );
        }
        $next_cat_oid++;
        $inserted = 1;
    }

    if ( $tigrfam_cat ne "" ) {
        print "Inserting <i>" . escHtml($tigrfam_cat) . "</i>...</br/>\n";
        execSqlOnly( $dbh, $sql, $verbose );
        my $sql = qq{
	     insert into myfunc_cat( cat_oid, category_name,
	        contact, func_db )
	     values( $next_cat_oid, '$tigrfam_cat2', $contact_oid, 'TIGR' )
	 };
        execSqlOnly( $dbh, $sql, $verbose );
        for my $func_id (@func_ids) {
            next if $func_id !~ /^TIGR/;
            print nbsp(2);
            print "Inserting <i>$func_id</i>...<br/>\n";
            my $sql = qq{
	        insert into myfunc_cat_members( cat_oid, members )
		values( $next_cat_oid, '$func_id' )
	     };
            execSqlOnly( $dbh, $sql, $verbose );
        }
        $next_cat_oid++;
        $inserted = 1;
    }

    execSqlOnly( $dbh, "commit work" );
    printEndWorkingDiv();

    return $inserted;
}

############################################################################
# checkNameExists - Check to see of category name already exists.
############################################################################
sub checkNameExists {
    my ( $dbh, $sql, $name, @binds ) = @_;
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return if $cnt == 0;
    webError(   "The name <i>'"
              . escHtml($name)
              . "'</i> is already "
              . "used.  Please select another category name.<br/>\n" );
}

############################################################################
# countOtherFuncCat - Count other functional categories.
############################################################################
sub countOtherFuncCat {
    my ( $dbh, $contact_oid ) = @_;

    my $sql = qq{
        select count(*)
	from myfunc_cat
	where contact != ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my ($cnt) = $cur->fetchrow();
    $cur->finish();
    return $cnt;
}

############################################################################
# printOtherFuncCats - Print other people's functional categories.
############################################################################
sub printOtherFuncCats {
    my $dbh = dbLogin();
    printMainForm();

    print "<h1>Other User Functional Categories</h1>\n";

    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError("Session has expired. Please start over.<br/>\n");
    }
    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
        select c.contact_oid, c.username, 
	    mfc.func_db, mfc.cat_oid, mfc.category_name
	from myfunc_cat mfc, contact c
	where mfc.contact != ?
	and mfc.contact = c.contact_oid
	order by c.username, mfc.func_db, mfc.category_name
    };
    my $cur = execSql( $dbh, $sql, $verbose, $contact_oid );
    my $count = 0;
    my $old_username;
    print "<p>\n";
    for ( ; ; ) {
        my ( $user_contact_oid, $username, $func_db, $cat_oid, $category_name )
          = $cur->fetchrow();
        last if !$cat_oid;
        $count++;
        if ( $old_username ne "" && $username ne $old_username ) {
            print "<br/>\n";
        }
        if ( $username ne $old_username ) {
            print "<b>\n";
            print escHtml($username);
            print "</b>\n";
            print "<br/>\n";
        }
        print nbsp(2);
        my $url = "$section_cgi&page=userCat&cat_oid=$cat_oid";
        $url .= "&user_contact_oid=$user_contact_oid";
        print alink( $url, $category_name );
        print nbsp(1);
        print "[$func_db]";
        print "<br/>\n";
        $old_username = $username;
    }
    $cur->finish();
    print "</p>\n";
    if ( $count == 0 ) {
        print "<p>\n";
        print "<i>\n";
        print "(No other user defind categories found.)<br/>\n";
        print "</i>\n";
        print "</p>\n";
    }
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printUserCat - Print user category.
############################################################################
sub printUserCat {
    my $user_contact_oid = param("user_contact_oid");
    my $cat_oid          = param("cat_oid");

    my $dbh = dbLogin();
    printMainForm();

    print "<h1>Other User Functional Category</h1>\n";

    my $contact_oid = getContactOid();
    if ( !$contact_oid ) {
        webError("Session has expired. Please start over.<br/>\n");
    }
    printStatusLine( "Loading ...", 1 );

    my $sql = qq{
        select mfc.func_db, mfc.cat_oid, mfc.category_name, mfcm.members
        from myfunc_cat mfc, myfunc_cat_members mfcm
        where mfc.cat_oid = mfcm.cat_oid
    	and mfc.cat_oid = ?
        and mfc.contact = ?
        order by mfc.func_db, mfc.category_name, mfcm.members
    };
    my $cur = execSql( $dbh, $sql, $verbose, $cat_oid, $user_contact_oid );

    my @recs;
    my @f_ids;
    for ( ; ; ) {
        my ( $func_db, $cat_oid, $category_name, $func_id ) =
          $cur->fetchrow();
        last if !$cat_oid;

        my $rec = "$func_db\t$cat_oid\t$category_name\t$func_id";        
        push( @recs, $rec );
        push( @f_ids, $func_id );
    }
    my %funcId2Name = QueryUtil::fetchFuncIdAndName($dbh, \@f_ids);
        
    my $count = 0;
    for my $rec (@recs) {
        my ( $func_db, $cat_oid, $category_name, $func_id ) =
          split( /\t/, $rec );
        next if !$cat_oid;
        $count++;

        if ( $count == 1 ) {
            print "<p>\n";
            print "Functions for user defined category ";
            print "<i>\n";
            print "<b>\n";
            print escHtml($category_name);
            print "</b>\n";
            print "</i>.\n";
            print "<br/>\n";
            print "</p>\n";
            print "<p>\n";
        }
        
        my $idType;
        if ( $func_id =~ /^COG/ ) {
            $idType = "cog_id";
        } elsif ( $func_id =~ /^pfam/ ) {
            $idType = "pfam_id";
        } elsif ( $func_id =~ /^EC/ ) {
            $idType = "ec_number";
        } elsif ( $func_id =~ /^TIGR/ ) {
            $idType = "tigrfam_id";
        } else {
            webDie("printUserCat: unuspported idType for '$func_id'\n");
        }
        print "<input type='checkbox' "
          . "name='$idType' value='$func_id' checked />\n";
        print nbsp(1);
        print "$func_id - ";
        my $func_name = $funcId2Name{$func_id};        
        print escHtml($func_name);
        print "<br/>\n";
    }
    print "</p>\n";
    $cur->finish();

    print "<br/>\n";
    printFuncCartFooter();

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

1;
