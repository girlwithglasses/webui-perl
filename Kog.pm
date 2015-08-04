############################################################################
# KOG
#
# $Id: Kog.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package Kog;

use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use InnerTable;

my $section              = "FindFunctions";
my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $base_url             = $env->{base_url};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $show_private         = $env->{show_private};
my $tmp_dir              = $env->{tmp_dir};
my $web_data_dir         = $env->{web_data_dir};
my $user_restricted_site = $env->{user_restricted_site};
my $preferences_url      = "$main_cgi?section=MyIMG&page=preferences";
my $include_metagenomes  = $env->{include_metagenomes};
my $rdbms                = getRdbms();
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $kog_base_url         = $env->{kog_base_url}; 

$| = 1;

sub dispatch {
    my $page    = param("page");
    my $subpage = param("subpage");
    my $time    = 3600 * 1;           # 1 hour cache
    my $sid     = 0;
    HtmlUtil::cgiCacheInitialize( $section);
    HtmlUtil::cgiCacheStart() or return;

    if ( $subpage eq "list" ) {
        printKogList();
    } elsif ( $subpage eq "kogGroupList" ) {
        printKogGroupList();
    } elsif ( $subpage eq "kogCodeList" ) {
        printKogCodeList();
    } else {
        printKogBrowser();
    }

    HtmlUtil::cgiCacheStop();
}

# list all kog given by a function group and function code
sub printKogCodeList {
    my $function_group = param("function_group");
    my $function_code = param("function_code");
    my $definition = param("definition");
    
    print "<h1>KOG Function Code</h1>\n";
    print "<h3> $function_group <br/> $definition  </h3>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh   = dbLogin();
    my $count = 0;

    my $sql = qq{
select k.kog_id, k.kog_name
from kog k, kog_functions kfs, kog_function kf 
where k.kog_id = kfs.kog_id
and kfs.functions = kf.function_code
and kf.function_group = ?
and kf.function_code = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_group, $function_code );

    my $it = new InnerTable( 1, "koglist$$", "koglist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KOG ID",              "char asc", "left" );
    $it->addColSpec( "Name",                "char asc", "left" );

    for ( ; ; ) {
        my ( $kog_id, $kog_name) = $cur->fetchrow();
        last if !$kog_id;
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='kog_id' " . "value='$kog_id' />" . "\t";

        my $url = "$kog_base_url$kog_id";
        $r .= $kog_id . $sd;
	if ($kog_base_url) { # create a link only if url is available
	    $r .= alink( $url, $kog_id );
	} else {
	    $r .= $kog_id;
	}
	$r .= "\t";
        $r .= $kog_name . $sd . $kog_name . "\t";

        $it->addRow($r);
    }
    $it->printOuterTable(1);

    $cur->finish();
    #$dbh->disconnect();

    printStatusLine( "$count loaded.", 2 );
    
}

# list all kog by a given function group
sub printKogGroupList {
    my $function_group = param("function_group");
    print "<h1>KOG Function Group</h1>\n";
    print "<h3> $function_group </h3>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh   = dbLogin();
    my $count = 0;

    my $sql = qq{
select k.kog_id, k.kog_name, kf.function_code, kf.definition
from kog k, kog_functions kfs, kog_function kf 
where k.kog_id = kfs.kog_id
and kfs.functions = kf.function_code
and kf.function_group = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $function_group );

    my $it = new InnerTable( 1, "koglist$$", "koglist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KOG ID",              "char asc", "left" );
    $it->addColSpec( "Name",                "char asc", "left" );
    $it->addColSpec( "Function Code",       "char asc", "left" );
    $it->addColSpec( "Function Definition", "char asc", "left" );

    for ( ; ; ) {
        my ( $kog_id, $kog_name, $function_code, $definition ) = $cur->fetchrow();
        last if !$kog_id;
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='kog_id' " . "value='$kog_id' />" . "\t";

        my $url = "$kog_base_url$kog_id";
        $r .= $kog_id . $sd;
	if ($kog_base_url) { # create a link only if url is available
	    $r .= alink( $url, $kog_id );
	} else {
	    $r .= $kog_id;
	}
	$r .= "\t";

        $r .= $kog_name . $sd . $kog_name . "\t";
        $r .= $function_code . $sd . $function_code . "\t";
        $r .= $definition . $sd . $definition . "\t";

        $it->addRow($r);
    }
    $it->printOuterTable(1);

    $cur->finish();
    #$dbh->disconnect();

    printStatusLine( "$count loaded.", 2 );

}

# browser list of all kog grouped by function group
sub printKogBrowser {
    print "<h1>KOG Browser</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
select kf.function_code, kf.function_group, kf.definition
from kog_function kf
order by kf.function_group, kf.definition
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    print "<p>\n";
    my $url = "$section_cgi&page=Kog&subpage=list";
    print alink( $url, "KOG list" );
    print "</p><p>\n";

    my $count = 0;
    my $last_function_group;

    for ( ; ; ) {
        my ( $function_code, $function_group, $definition ) = $cur->fetchrow();
        last if !$function_code;
        $count++;
        if ( $last_function_group ne $function_group ) {
            print "<br/>\n" if ( $count > 1 );
            my $url = $section_cgi . "&page=Kog&subpage=kogGroupList";
            $url .= "&function_group=$function_group";
            print alink( $url, $function_group ) . " <br/>\n";
        }

        # print defn
        my $url = $section_cgi . "&page=Kog&subpage=kogCodeList";
        $url .= "&function_group=$function_group";
        $url .= "&function_code=$function_code";
        $url .= "&definition=$definition";
        print nbsp(4);
        print alink( $url, $definition ) . " [$function_code] <br/>\n";
        $last_function_group = $function_group;
    }

    $cur->finish();
    #$dbh->disconnect();

    print "</p>\n";
    printStatusLine( "$count loaded.", 2 );
}

# list of all kogs
sub printKogList {
    print "<h1>KOG List</h1>\n";

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    my $dbh = dbLogin();
    my $sql = qq{
        select kog_id, kog_name, description
        from kog
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my $count = 0;
    print "<p>\n";

    my $it = new InnerTable( 1, "koglist$$", "koglist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "KOG ID",      "char asc", "left" );
    $it->addColSpec( "Name",        "char asc", "left" );
    $it->addColSpec( "Description", "char asc", "left" );

    for ( ; ; ) {
        my ( $kog_id, $name, $description ) = $cur->fetchrow();
        last if !$kog_id;
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='kog_id' " . "value='$kog_id' />" . "\t";

        my $url = "$kog_base_url$kog_id";
        $r .= $kog_id . $sd;
	if ($kog_base_url) { # create a link only if url is available
	    $r .= alink( $url, $kog_id );
	} else {
	    $r .= $kog_id;
	}
	$r .= "\t";
        $r .= $name . $sd . $name . "\t";
        $r .= $description . $sd . $description . "\t";

        $it->addRow($r);
    }
    $it->printOuterTable(1);
    $cur->finish();
    #$dbh->disconnect();

    print "</p>\n";

    print end_form();
    printStatusLine( "$count Loaded", 2 );

}

1;
