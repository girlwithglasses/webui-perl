###########################################################################
# Interpro.pm
# $Id: Interpro.pm 30115 2014-02-17 06:15:54Z jinghuahuang $
############################################################################
package Interpro;

use strict;
use CGI qw/:standard/;
use Data::Dumper;
use WebConfig;
use WebUtil;
use InnerTable;
use HtmlUtil;
use WorkspaceUtil;

$| = 1;

my $env          = getEnv();
my $base_url     = $env->{base_url};
my $base_dir     = $env->{base_dir};
my $main_cgi     = $env->{main_cgi};
my $cgi_url      = $env->{cgi_url};
my $verbose      = $env->{verbose};
my $ipr_base_url = $env->{ipr_base_url};
my $section      = "Interpro";
my $section_cgi  = "$main_cgi?section=$section";
my $include_metagenomes   = $env->{include_metagenomes};

sub dispatch {
    my $sid = getContactOid();

    HtmlUtil::cgiCacheInitialize( $section);
    HtmlUtil::cgiCacheStart() or return;

    my $page = param("page");
    if ( $page eq 'genelist' ) {
        printGeneList();
    } elsif ( $page eq 'genomelist' ) {
        printGenomeList();
    } else {
        printInterproList();
    }
    HtmlUtil::cgiCacheStop();
}

sub printGeneList {
    my $ipr_id = param('ipr_id');
    print "<h1>InterPro Gene List</h1>";

    my $dbh = dbLogin();

    my $name = getIprName( $dbh, $ipr_id );
    my $url =  $ipr_base_url . $ipr_id;
    my $link = alink($url, $ipr_id.", ".$name);
    print "<p>$link</p>";

    #$dbh->disconnect();

    my $urclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $metag_clause = "";
    if ($include_metagenomes) {
    	$metag_clause = ("and t.genome_type = 'isolate'");
    }
    my $sql = qq{
        select distinct gi.gene_oid, g.gene_display_name, t.taxon_display_name
        from gene_xref_families gi, gene g, taxon t
        where gi.db_name = 'InterPro'
        and gi.id = ?
        and gi.gene_oid = g.gene_oid
        and g.taxon = t.taxon_oid
        $metag_clause
        $urclause
        $imgClause
    };

    require TaxonDetailUtil;
    TaxonDetailUtil::printGeneListSectionSorting( $sql, "", "", $ipr_id );

}

sub printGenomeList {
    
    my $ipr_id = param('ipr_id');

    printMainForm();
    print "<h1>InterPro Genome List</h1>";

    my $dbh = dbLogin();
    my $name = getIprName( $dbh, $ipr_id );
    my $url =  $ipr_base_url . $ipr_id;
    my $link = alink($url, $ipr_id.", ".$name);
    print "<p>$link</p>";

    my $metag_clause = ""; 
    if ($include_metagenomes) { 
        $metag_clause = ("and t.genome_type = 'isolate'");
    } 
    my $urclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    
    my $sql = qq{
        select distinct t.taxon_oid, t.taxon_display_name
        from mv_taxon_ipr_stat g, taxon t
        where g.iprid = ?
        and g.taxon_oid = t.taxon_oid
        $metag_clause
        $urclause
        $imgClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $ipr_id );

    my $it = new InnerTable( 1, "interprogeneomelist$$", "interprogenomelist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Genome ID",   "asc", "left" );
    $it->addColSpec( "Genome Name", "asc", "left" );

    my $select_id_name = "taxon_filter_oid";

    my $count = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $name ) = $cur->fetchrow();
        last if ( !$taxon_oid );
        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$taxon_oid' />" . "\t";
        my $url = 'main.cgi?section=TaxonDetail&taxon_oid=' . $taxon_oid;
        $url = alink( $url, $taxon_oid );
        $r .= $taxon_oid . $sd . $url . "\t";
        $r .= $name . $sd . $name . "\t";
        $it->addRow($r);
    }
    $cur->finish();
    #$dbh->disconnect();

    if ($count > 10) {
        print submit(
              -name    => 'setTaxonFilter',
              -value   => 'Add Selected to Genome Cart',
              -class   => 'meddefbutton',
              -onClick => "return isGenomeSelected('interprogenomelist');"
        );
        print nbsp(2);
        WebUtil::printButtonFooter();
    }
    $it->printOuterTable(1);
    print submit(
          -name    => 'setTaxonFilter',
          -value   => 'Add Selected to Genome Cart',
          -class   => 'meddefbutton',
          -onClick => "return isGenomeSelected('interprogenomelist');"
    );
    print nbsp(2);
    WebUtil::printButtonFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    printStatusLine( "$count Loaded", 2 );
    print end_form();
}

sub printInterproList {
    my $link = "<a href=http://www.ebi.ac.uk/interpro>InterPro</a>";
    my $text = "$link is a database of protein families, domains, and functional sites. In this database, identifiable features found in known proteins can be applied to new protein sequences in order to functionally characterize them. ";
 
    if ($include_metagenomes) { 
        WebUtil::printHeaderWithInfo 
            ("InterPro Browser", $text, 
             "show description for this tool", "InterPro Info", 1);
    } else { 
        WebUtil::printHeaderWithInfo 
            ("InterPro Browser", $text,
             "show description for this tool", "InterPro Info");
    } 

    printMainForm();
    printStatusLine("Loading ...");

    my $sql = qq{
        select ext_accession, name
        from interpro        
    };

    my $dbh = dbLogin();
    my $counts_href = getCounts($dbh);
    my $cur = execSql( $dbh, $sql, $verbose );

    my $it = new InnerTable( 1, "interprolist$$", "interprolist", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Interpro ID",  "asc", "left" );
    $it->addColSpec( "Name",         "asc", "left" );
    $it->addColSpec( "Gene Count",   "asc", "right" );
    $it->addColSpec( "Genome Count", "asc", "right" );

    my $select_id_name = "ipr_id";

    my $count = 0;
    for ( ; ; ) {
        my ( $ext_accession, $name ) = $cur->fetchrow();
        last if ( !$ext_accession );

        $count++;
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$ext_accession' />" . "\t";

        my $url = alink( $ipr_base_url . $ext_accession, $ext_accession );
        $r .= $ext_accession . $sd . $url . "\t";
        $r .= $name . $sd . $name . "\t";

        my $line = $counts_href->{$ext_accession};
        if ( $line ne "" ) {
            my ( $gene_count, $geome_count ) = split( /\t/, $line );

            my $url = $section_cgi . '&page=genelist&ipr_id=' . $ext_accession;
            $url = alink( $url, $gene_count );
            $r .= $gene_count . $sd . $url . "\t";

            my $url = $section_cgi . '&page=genomelist&ipr_id=' . $ext_accession;
            $url = alink( $url, $geome_count );
            $r .= $geome_count . $sd . $url . "\t";
        } else {
            $r .= 0 . $sd . 0 . "\t";
            $r .= 0 . $sd . 0 . "\t";
        }
        $it->addRow($r);
    }
    $cur->finish();
    #$dbh->disconnect();

    WebUtil::printFuncCartFooter() if ($count > 10);
    $it->printOuterTable(1);
    WebUtil::printFuncCartFooter();

    if ($count > 0) {
        print hiddenVar( 'save_func_id_name', 'ipr_id' );
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }

    printStatusLine( "$count Loaded", 2 );
    print end_form();
}

sub getCounts {
    my ($dbh) = @_;

    my $rclause = WebUtil::urClause('mv.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('mv.taxon_oid');        

    my $sql = qq{
        select /*+ result_cache */ mv.iprid, sum(mv.gene_count), count(distinct mv.taxon_oid)
        from mv_taxon_ipr_stat mv
        where 1 = 1
        $rclause
        $imgClause
	    group by mv.iprid
    };
    #print "Intepro::getCounts() sql: $sql<br/>\n";
    my $cur = execSql( $dbh, $sql, $verbose );
    my %data;
    for ( ; ; ) {
        my ( $iprid, $gene_count, $taxon_count ) = $cur->fetchrow();
        last if ( !$iprid );
        $data{$iprid} = "$gene_count\t$taxon_count";
    }
    $cur->finish();

    return \%data;
}

sub getIprName {
    my ( $dbh, $ipr_id ) = @_;

    my $sql = qq{
        select name
        from interpro
        where ext_accession = ?  
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ipr_id );
    my ($name) = $cur->fetchrow();
    $cur->finish();

    return $name;
}

1;
