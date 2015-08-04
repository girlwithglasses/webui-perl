###########################################################################
#
# $Id: HorizontalTransfer.pm 30400 2014-03-12 19:20:25Z klchu $
#
package HorizontalTransfer;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use InnerTable;

use HtmlUtil;

$| = 1;

my $section              = "HorizontalTransfer";
my $env          = getEnv();
my $cgi_dir      = $env->{cgi_dir};
my $cgi_url      = $env->{cgi_url};
my $main_cgi     = $env->{main_cgi};
my $section_cgi  = "$main_cgi?section=HorizontalTransfer";
my $inner_cgi    = $env->{inner_cgi};
my $tmp_url      = $env->{tmp_url};
my $verbose      = $env->{verbose};
my $web_data_dir = $env->{web_data_dir};
my $img_internal = $env->{img_internal};
my $cgi_tmp_dir  = $env->{cgi_tmp_dir};
my $user_restricted_site = $env->{user_restricted_site};

sub dispatch {
    my $sid       = getContactOid();
    my $page = param("page");
    my $taxon_oid = param("taxon_oid");    # REQUIRED ------

    HtmlUtil::cgiCacheInitialize( $section );
    HtmlUtil::cgiCacheStart() or return;

    # HT domain related pages
    if ( $page eq "domain" ) {
        printDomain();
    } elsif ( $page eq "homologphylum" ) {
        printHomologPhylum();
    } elsif ( $page eq "homologphylumgenelist" ) {
        printHomologPhylumGeneList();
    } elsif ( $page eq "homologfamily" ) {
        printHomologFamily();
    } elsif ( $page eq "homologfamilygenelist" ) {
        printHomologFamilyGeneList();
    } elsif ( $page eq "homologgenusgenelist" ) {
        printHomologGenusGeneList();
    }

    # HT phylum related pages
    if (   $page eq "phylum"
        || $page eq "class"
        || $page eq "order"
        || $page eq "family"
        || $page eq "genus" )
    {
        printPhylum();
    } elsif ( $page eq "homologphylum2" ) {
        printHomologPhylum2();
    } elsif ( $page eq "homologphylum2genelist" ) {
        printHomologPhylum2GeneList();
    } elsif ( $page eq "homologfamily2" ) {
        printHomologFamily2();
    } elsif ( $page eq "homologfamily2genelist" ) {
        printHomologFamily2GeneList();
    } elsif ( $page eq "homologgenus2genelist" ) {
        printHomologGenus2GeneList();
    } elsif ( $page eq "outsidegenelist" ) {
        printOutsideGeneList();
    }

    HtmlUtil::cgiCacheStop();
}

sub printPhylum {
    my $phylo_level = param("phylo_level");
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");

    print "<h1>Putative Horizontally Transferred</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "</p>";

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select t.domain, t.phylum, count(distinct g.gene_oid), 
    count(distinct hth.homolog) 
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    group by t.domain, t.phylum       
    };

    my @a = ( $taxon_oid, $phylo_level, $phylo_val );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my $count = 0;
    my $it    = new InnerTable( 1, "ht$$", "ht", 1 );
    my $sd    = $it->getSdDelim();                      # sort delimiter

    $it->addColSpec( "From Domain",     "char asc",    "right" );
    $it->addColSpec( "From Phylum",     "char asc",    "left" );
    $it->addColSpec( "Gene Count",      "number desc", "right" );
    $it->addColSpec( "From Gene Count", "number desc", "right" );

    for ( ; ; ) {
        my ( $hg_domain, $phylum, $gene_cnt, $homolog_cnt ) = $cur->fetchrow();
        last if !$hg_domain;
        $count++;
        my $r;
        $r .= $hg_domain . $sd . $hg_domain . "\t";
        my $url =
            "$section_cgi&page=homologphylum2"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$phylum";
        $url = alink( $url, $phylum );
        $r .= $phylum . $sd . $url . "\t";
        my $url =
            "$section_cgi&page=homologphylum2genelist"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$phylum";
        $url = alink( $url, $gene_cnt );
        $r .= $gene_cnt . $sd . $url . "\t";
        $r .= $homolog_cnt . $sd . $homolog_cnt . "\t";

        $it->addRow($r);
    }

    $cur->finish();
    #$dbh->disconnect();

    $it->printOuterTable(1);
    printStatusLine( "$count Loaded.", 2 );
}

sub printHomologPhylum2 {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");

    print "<h1>Putative Horizontally Transferred</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "</p>";

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select t.ir_class, t.ir_order, t.family,
    count(distinct g.gene_oid), count(distinct hth.homolog) 
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    group by t.ir_class, t.ir_order, t.family 
    };

    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my $count = 0;
    my $it    = new InnerTable( 1, "ht$$", "ht", 0 );
    my $sd    = $it->getSdDelim();                      # sort delimiter

    $it->addColSpec( "From Class",      "char asc",    "right" );
    $it->addColSpec( "From Order",      "char asc",    "left" );
    $it->addColSpec( "From Family",     "char asc",    "left" );
    $it->addColSpec( "Gene Count",      "number desc", "right" );
    $it->addColSpec( "From Gene Count", "number desc", "right" );

    for ( ; ; ) {
        my ( $hg_class, $hg_order, $hg_family, $gene_cnt, $homolog_cnt ) =
          $cur->fetchrow();
        last if !$hg_class;
        $count++;
        my $r;
        $r .= $hg_class . $sd . $hg_class . "\t";
        $r .= $hg_order . $sd . $hg_order . "\t";
        my $url =
            "$section_cgi"
          . "&page=homologfamily2"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$hg_phylum"
          . "&hg_family=$hg_family";
        $url .= "&hg_class=$hg_class" if ( $hg_class ne "" );
        $url .= "&hg_order=$hg_order" if ( $hg_order ne "" );
        $url = alink( $url, $hg_family );
        $r .= $hg_family . $sd . $url . "\t";
        my $url =
            "$section_cgi"
          . "&page=homologfamily2genelist"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$hg_phylum"
          . "&hg_family=$hg_family";
        $url .= "&hg_class=$hg_class" if ( $hg_class ne "" );
        $url .= "&hg_order=$hg_order" if ( $hg_order ne "" );
        $url = alink( $url, $gene_cnt );
        $r .= $gene_cnt . $sd . $url . "\t";
        $r .= $homolog_cnt . $sd . $homolog_cnt . "\t";

        $it->addRow($r);
    }

    $cur->finish();
    #$dbh->disconnect();

    $it->printOuterTable(1);
    printStatusLine( "$count Loaded.", 2 );

}

sub printHomologPhylum2GeneList {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");

    print "<h1>Putative Horizontally Transferred Gene List</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "</p>";

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select distinct g.gene_oid, g.gene_display_name,
      g2.gene_oid, g2.gene_display_name,
      t.taxon_oid, t.taxon_display_name
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    };
    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    printHorTransferredLevelVal( $dbh, $sql, \@a );
    #$dbh->disconnect();

}

sub printHomologFamily2 {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");
    my $hg_class    = param("hg_class");
    my $hg_order    = param("hg_order");
    my $hg_family   = param("hg_family");

    print "<h1>Putative Horizontally Transferred</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "From Class: $hg_class <br/>\n";
    print "From Order: $hg_order <br/>\n";
    print "From Family: $hg_family <br/>\n";
    print "</p>";

    my $clause;
    $clause .= " and t.ir_class = ? " if ( $hg_class  ne "" );
    $clause .= " and t.ir_order = ? " if ( $hg_order  ne "" );
    $clause .= " and t.family = ? "   if ( $hg_family ne "" );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select t.genus, t.species,
    count(distinct g.gene_oid), count(distinct hth.homolog) 
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    $clause
    group by t.genus, t.species 
    };

    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    push( @a, $hg_class )  if ( $hg_class  ne "" );
    push( @a, $hg_order )  if ( $hg_order  ne "" );
    push( @a, $hg_family ) if ( $hg_family ne "" );

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my $count = 0;
    my $it    = new InnerTable( 1, "ht$$", "ht", 0 );
    my $sd    = $it->getSdDelim();                      # sort delimiter

    $it->addColSpec( "From Genus",      "char asc",    "right" );
    $it->addColSpec( "From Species",    "char asc",    "left" );
    $it->addColSpec( "Gene Count",      "number desc", "right" );
    $it->addColSpec( "From Gene Count", "number desc", "right" );

    for ( ; ; ) {
        my ( $hg_genus, $hg_species, $gene_cnt, $homolog_cnt ) =
          $cur->fetchrow();
        last if !$hg_genus;
        $count++;
        my $r;
        $r .= $hg_genus . $sd . $hg_genus . "\t";
        $r .= $hg_species . $sd . $hg_species . "\t";
        my $url =
            "$section_cgi"
          . "&page=homologgenusgenelist"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$hg_phylum"
          . "&hg_family=$hg_family";
        $url .= "&hg_class=$hg_class"     if ( $hg_class   ne "" );
        $url .= "&hg_order=$hg_order"     if ( $hg_order   ne "" );
        $url .= "&hg_genus=$hg_genus"     if ( $hg_genus   ne "" );
        $url .= "&hg_species=$hg_species" if ( $hg_species ne "" );
        $url = alink( $url, $gene_cnt );
        $r .= $gene_cnt . $sd . $url . "\t";
        $r .= $homolog_cnt . $sd . $homolog_cnt . "\t";

        $it->addRow($r);
    }

    $cur->finish();
    #$dbh->disconnect();

    $it->printOuterTable(1);
    printStatusLine( "$count Loaded.", 2 );
}

sub printHomologFamily2GeneList {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");
    my $hg_class    = param("hg_class");
    my $hg_order    = param("hg_order");
    my $hg_family   = param("hg_family");

    print "<h1>Putative Horizontally Transferred Gene List</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "From Class: $hg_class <br/>\n";
    print "From Order: $hg_order <br/>\n";
    print "From Family: $hg_family <br/>\n";
    print "</p>";

    # t.ir_class, t.ir_order, t.family,
    my $clause;
    $clause .= " and t.ir_class = ? " if ( $hg_class  ne "" );
    $clause .= " and t.ir_order = ? " if ( $hg_order  ne "" );
    $clause .= " and t.family = ? "   if ( $hg_family ne "" );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select distinct g.gene_oid, g.gene_display_name,
      g2.gene_oid, g2.gene_display_name,
      t.taxon_oid, t.taxon_display_name
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    $clause
    };
    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    push( @a, $hg_class )  if ( $hg_class  ne "" );
    push( @a, $hg_order )  if ( $hg_order  ne "" );
    push( @a, $hg_family ) if ( $hg_family ne "" );

    printHorTransferredLevelVal( $dbh, $sql, \@a );
    #$dbh->disconnect();
}

sub printHomologGenus2GeneList {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");
    my $hg_class    = param("hg_class");
    my $hg_order    = param("hg_order");
    my $hg_family   = param("hg_family");
    my $hg_genus    = param("hg_genus");
    my $hg_species  = param("hg_species");

    print "<h1>Putative Horizontally Transferred Gene List</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "From Class: $hg_class <br/>\n";
    print "From Order: $hg_order <br/>\n";
    print "From Family: $hg_family <br/>\n";
    print "From Genus: $hg_genus <br/>\n";
    print "From Species: $hg_species <br/>\n";
    print "</p>";

    # t.ir_class, t.ir_order, t.family,
    my $clause;
    $clause .= " and t.ir_class = ? " if ( $hg_class   ne "" );
    $clause .= " and t.ir_order = ? " if ( $hg_order   ne "" );
    $clause .= " and t.family = ? "   if ( $hg_family  ne "" );
    $clause .= " and t.genus = ? "    if ( $hg_genus   ne "" );
    $clause .= " and t.species = ? "  if ( $hg_species ne "" );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select distinct g.gene_oid, g.gene_display_name,
      g2.gene_oid, g2.gene_display_name,
      t.taxon_oid, t.taxon_display_name
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    $clause
    };
    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    push( @a, $hg_class )  if ( $hg_class  ne "" );
    push( @a, $hg_order )  if ( $hg_order  ne "" );
    push( @a, $hg_family ) if ( $hg_family ne "" );

    push( @a, $hg_genus )   if ( $hg_genus   ne "" );
    push( @a, $hg_species ) if ( $hg_species ne "" );

    printHorTransferredLevelVal( $dbh, $sql, \@a );
    #$dbh->disconnect();
}

# --------------
# end of phylum section
# -------------

# --------------
# Domain section
# -------------

sub printDomain {

    # domain, phylum etc
    my $phylo_level = param("phylo_level");
    my $taxon_oid   = param("taxon_oid");

    # domain name: Archaea, bacteria etc
    my $phylo_val = param("phylo_val");

    print "<h1>Putative Horizontally Transferred</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "</p>";

    # some gene_oid hit multiple homologs, which may spread
    # over different phylum some the sum of gene_oid
    # may be greater than the sum genes under the domain
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select t.domain, t.phylum, count(distinct g.gene_oid), 
    count(distinct hth.homolog) 
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    group by t.domain, t.phylum       
    };

    my @a = ( $taxon_oid, $phylo_level, $phylo_val );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my $count = 0;
    my $it    = new InnerTable( 1, "ht$$", "ht", 1 );
    my $sd    = $it->getSdDelim();                      # sort delimiter

    $it->addColSpec( "From Domain",     "char asc",    "right" );
    $it->addColSpec( "From Phylum",     "char asc",    "left" );
    $it->addColSpec( "Gene Count",      "number desc", "right" );
    $it->addColSpec( "From Gene Count", "number desc", "right" );

    for ( ; ; ) {
        my ( $hg_domain, $phylum, $gene_cnt, $homolog_cnt ) = $cur->fetchrow();
        last if !$hg_domain;
        $count++;
        my $r;
        $r .= $hg_domain . $sd . $hg_domain . "\t";
        my $url =
            "$section_cgi&page=homologphylum"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$phylum";
        $url = alink( $url, $phylum );
        $r .= $phylum . $sd . $url . "\t";
        my $url =
            "$section_cgi&page=homologphylumgenelist"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$phylum";
        $url = alink( $url, $gene_cnt );
        $r .= $gene_cnt . $sd . $url . "\t";
        $r .= $homolog_cnt . $sd . $homolog_cnt . "\t";

        $it->addRow($r);
    }

    $cur->finish();
    #$dbh->disconnect();

    $it->printOuterTable(1);
    printStatusLine( "$count Loaded.", 2 );

}

sub printHomologPhylum {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");

    print "<h1>Putative Horizontally Transferred</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "</p>";

    # some gene_oid hit multiple homologs, which may spread
    # over different phylum some the sum of gene_oid
    # may be greater than the sum genes under the domain
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select t.ir_class, t.ir_order, t.family,
    count(distinct g.gene_oid), count(distinct hth.homolog) 
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    group by t.ir_class, t.ir_order, t.family 
    };

    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my $count = 0;
    my $it    = new InnerTable( 1, "ht$$", "ht", 0 );
    my $sd    = $it->getSdDelim();                      # sort delimiter

    $it->addColSpec( "From Class",      "char asc",    "right" );
    $it->addColSpec( "From Order",      "char asc",    "left" );
    $it->addColSpec( "From Family",     "char asc",    "left" );
    $it->addColSpec( "Gene Count",      "number desc", "right" );
    $it->addColSpec( "From Gene Count", "number desc", "right" );

    for ( ; ; ) {
        my ( $hg_class, $hg_order, $hg_family, $gene_cnt, $homolog_cnt ) =
          $cur->fetchrow();
        last if !$hg_class;
        $count++;
        my $r;
        $r .= $hg_class . $sd . $hg_class . "\t";
        $r .= $hg_order . $sd . $hg_order . "\t";
        my $url =
            "$section_cgi"
          . "&page=homologfamily"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$hg_phylum"
          . "&hg_family=$hg_family";
        $url .= "&hg_class=$hg_class" if ( $hg_class ne "" );
        $url .= "&hg_order=$hg_order" if ( $hg_order ne "" );
        $url = alink( $url, $hg_family );
        $r .= $hg_family . $sd . $url . "\t";
        my $url =
            "$section_cgi"
          . "&page=homologfamilygenelist"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$hg_phylum"
          . "&hg_family=$hg_family";
        $url .= "&hg_class=$hg_class" if ( $hg_class ne "" );
        $url .= "&hg_order=$hg_order" if ( $hg_order ne "" );
        $url = alink( $url, $gene_cnt );
        $r .= $gene_cnt . $sd . $url . "\t";
        $r .= $homolog_cnt . $sd . $homolog_cnt . "\t";

        $it->addRow($r);
    }

    $cur->finish();
    #$dbh->disconnect();

    $it->printOuterTable(1);
    printStatusLine( "$count Loaded.", 2 );

}

sub printHomologPhylumGeneList {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");

    print "<h1>Putative Horizontally Transferred Gene List</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "</p>";

    # some gene_oid hit multiple homologs, which may spread
    # over different phylum some the sum of gene_oid
    # may be greater than the sum genes under the domain
    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select distinct g.gene_oid, g.gene_display_name,
      g2.gene_oid, g2.gene_display_name,
      t.taxon_oid, t.taxon_display_name
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    };
    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    printHorTransferredLevelVal( $dbh, $sql, \@a );
    #$dbh->disconnect();

}

sub printHomologFamily {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");
    my $hg_class    = param("hg_class");
    my $hg_order    = param("hg_order");
    my $hg_family   = param("hg_family");

    print "<h1>Putative Horizontally Transferred</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "From Class: $hg_class <br/>\n";
    print "From Order: $hg_order <br/>\n";
    print "From Family: $hg_family <br/>\n";
    print "</p>";

    my $clause;
    $clause .= " and t.ir_class = ? " if ( $hg_class  ne "" );
    $clause .= " and t.ir_order = ? " if ( $hg_order  ne "" );
    $clause .= " and t.family = ? "   if ( $hg_family ne "" );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select t.genus, t.species,
    count(distinct g.gene_oid), count(distinct hth.homolog) 
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    $clause
    group by t.genus, t.species 
    };

    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    push( @a, $hg_class )  if ( $hg_class  ne "" );
    push( @a, $hg_order )  if ( $hg_order  ne "" );
    push( @a, $hg_family ) if ( $hg_family ne "" );

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );

    my $count = 0;
    my $it    = new InnerTable( 1, "ht$$", "ht", 0 );
    my $sd    = $it->getSdDelim();                      # sort delimiter

    $it->addColSpec( "From Genus",      "char asc",    "right" );
    $it->addColSpec( "From Species",    "char asc",    "left" );
    $it->addColSpec( "Gene Count",      "number desc", "right" );
    $it->addColSpec( "From Gene Count", "number desc", "right" );

    for ( ; ; ) {
        my ( $hg_genus, $hg_species, $gene_cnt, $homolog_cnt ) =
          $cur->fetchrow();
        last if !$hg_genus;
        $count++;
        my $r;
        $r .= $hg_genus . $sd . $hg_genus . "\t";
        $r .= $hg_species . $sd . $hg_species . "\t";
        my $url =
            "$section_cgi"
          . "&page=homologgenusgenelist"
          . "&phylo_val=$phylo_val"
          . "&phylo_level=$phylo_level"
          . "&taxon_oid=$taxon_oid"
          . "&hg_domain=$hg_domain"
          . "&hg_phylum=$hg_phylum"
          . "&hg_family=$hg_family";
        $url .= "&hg_class=$hg_class"     if ( $hg_class   ne "" );
        $url .= "&hg_order=$hg_order"     if ( $hg_order   ne "" );
        $url .= "&hg_genus=$hg_genus"     if ( $hg_genus   ne "" );
        $url .= "&hg_species=$hg_species" if ( $hg_species ne "" );
        $url = alink( $url, $gene_cnt );
        $r .= $gene_cnt . $sd . $url . "\t";
        $r .= $homolog_cnt . $sd . $homolog_cnt . "\t";

        $it->addRow($r);
    }

    $cur->finish();
    #$dbh->disconnect();

    $it->printOuterTable(1);
    printStatusLine( "$count Loaded.", 2 );
}

sub printHomologFamilyGeneList {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");
    my $hg_class    = param("hg_class");
    my $hg_order    = param("hg_order");
    my $hg_family   = param("hg_family");

    print "<h1>Putative Horizontally Transferred Gene List</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "From Class: $hg_class <br/>\n";
    print "From Order: $hg_order <br/>\n";
    print "From Family: $hg_family <br/>\n";
    print "</p>";

    # t.ir_class, t.ir_order, t.family,
    my $clause;
    $clause .= " and t.ir_class = ? " if ( $hg_class  ne "" );
    $clause .= " and t.ir_order = ? " if ( $hg_order  ne "" );
    $clause .= " and t.family = ? "   if ( $hg_family ne "" );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select distinct g.gene_oid, g.gene_display_name,
      g2.gene_oid, g2.gene_display_name,
      t.taxon_oid, t.taxon_display_name
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    $clause
    };
    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    push( @a, $hg_class )  if ( $hg_class  ne "" );
    push( @a, $hg_order )  if ( $hg_order  ne "" );
    push( @a, $hg_family ) if ( $hg_family ne "" );

    printHorTransferredLevelVal( $dbh, $sql, \@a );
    #$dbh->disconnect();
}

sub printHomologGenusGeneList {
    my $taxon_oid   = param("taxon_oid");
    my $phylo_val   = param("phylo_val");
    my $phylo_level = param("phylo_level");
    my $hg_domain   = param("hg_domain");
    my $hg_phylum   = param("hg_phylum");
    my $hg_class    = param("hg_class");
    my $hg_order    = param("hg_order");
    my $hg_family   = param("hg_family");
    my $hg_genus    = param("hg_genus");
    my $hg_species  = param("hg_species");

    print "<h1>Putative Horizontally Transferred Gene List</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print "$domain, $phylum, $class, $order, $family, $genus $species<br/>\n";
    print "From Domain: $hg_domain <br/>\n";
    print "From Phylum: $hg_phylum <br/>\n";
    print "From Class: $hg_class <br/>\n";
    print "From Order: $hg_order <br/>\n";
    print "From Family: $hg_family <br/>\n";
    print "From Genus: $hg_genus <br/>\n";
    print "From Species: $hg_species <br/>\n";
    print "</p>";

    # t.ir_class, t.ir_order, t.family,
    my $clause;
    $clause .= " and t.ir_class = ? " if ( $hg_class   ne "" );
    $clause .= " and t.ir_order = ? " if ( $hg_order   ne "" );
    $clause .= " and t.family = ? "   if ( $hg_family  ne "" );
    $clause .= " and t.genus = ? "    if ( $hg_genus   ne "" );
    $clause .= " and t.species = ? "  if ( $hg_species ne "" );

    my $rclause   = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');
    my $sql = qq{
    select distinct g.gene_oid, g.gene_display_name,
      g2.gene_oid, g2.gene_display_name,
      t.taxon_oid, t.taxon_display_name
    from gene g, dt_ht_hits hth, gene g2, taxon t
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is not null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t.taxon_oid
    and t.domain = ?
    and t.phylum = ?
    $clause
    };
    my @a = ( $taxon_oid, $phylo_level, $phylo_val, $hg_domain, $hg_phylum );
    push( @a, $hg_class )  if ( $hg_class  ne "" );
    push( @a, $hg_order )  if ( $hg_order  ne "" );
    push( @a, $hg_family ) if ( $hg_family ne "" );

    push( @a, $hg_genus )   if ( $hg_genus   ne "" );
    push( @a, $hg_species ) if ( $hg_species ne "" );

    printHorTransferredLevelVal( $dbh, $sql, \@a );
    #$dbh->disconnect();
}

# --------------
# end of Domain section
# -------------

sub printOutsideGeneList {
    my $taxon_oid     = param("taxon_oid");
    my $phylo_val     = param("phylo_val");
    my $phylo_level   = param("phylo_level");
    my $not_phylo_val = param("nnot_phylo_val");
            # IE bug fix &not == &not;
            # change to &nnot

    #print "<h1>Putative Horizontally Transferred Outside Gene List</h1>\n";

    my $dbh = dbLogin();
    my $taxon_name = taxonOid2Name( $dbh, $taxon_oid );
    print qq{
     <h1>
     Genes in $taxon_name<br/>
     with Best Hits to Genes from $phylo_val<br/>
     and No Hits to Genes from $not_phylo_val
     </h1>
    };

    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      getTaxonPhylaInfo( $dbh, $taxon_oid );
    my $url =
      "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
    $url = alink( $url, "<i>$taxon_name</i>", "", 1 );
    print "<p> $url <br/>\n";
    print
"with <b>Lineage:</b> $domain, $phylum, $class, $order, $family, $genus $species<br/>\n";

    #print "<br/>\n";
    #print "Inside " . ucfirst($phylo_level) . ": $phylo_val<br/>\n";
    print "</p>";
    my $rclause   = WebUtil::urClause('t2');
    my $imgClause = WebUtil::imgClause('t2');
    my $sql = qq{
select distinct g.gene_oid, g.gene_display_name,
      g2.gene_oid, g2.gene_display_name,
      t2.taxon_oid, t2.taxon_display_name, 
      t2.domain, t2.phylum,
      t2.ir_class, t2.ir_order, t2.family, t2.genus, t2.species
    from gene g, dt_ht_hits hth,  gene g2, taxon t2
    where g.gene_oid = hth.gene_oid
    and g.taxon = ?
    $rclause
    $imgClause
    and g.obsolete_flag = 'No'
    and hth.phylo_level = ?
    and hth.phylo_val = ?
    and hth.rev_gene_oid is null
    and hth.homolog = g2.gene_oid
    and g2.taxon = t2.taxon_oid
  order by 1  
    };

    my @a = ( $taxon_oid, $phylo_level, $phylo_val );

    printHorTransferredLevelVal( $dbh, $sql, \@a, 1 );

    #$dbh->disconnect();
}

# query cols
#       g.gene_oid, g.gene_display_name,
#       g2.gene_oid, g2.gene_display_name,
#       tx2.taxon_oid, tx2.taxon_display_name
sub printHorTransferredLevelVal {
    my ( $dbh, $sql, $bind_aref, $phlyacol ) = @_;

    printMainForm();
    printStatusLine( "Loading ...", 1 );
    my $clobberCache = 1;
    my $it = new InnerTable( $clobberCache, "ht_hits$$", "ht_hits", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene<br/>Object<br/>Identifier", "number asc", "left" );
    $it->addColSpec( "Product Name",                   "char asc",   "left" );
    $it->addColSpec( "From<br/>Gene",                  "number asc", "left" );
    $it->addColSpec( "From<br/>Product",               "char asc",   "left" );
    $it->addColSpec( "From<br/>Genome",                "char asc",   "left" );
    if ($phlyacol) {
        $it->addColSpec( "Lineage", "char asc", "left" );
    }
    my $sd = $it->getSdDelim();

    my $cur = WebUtil::execSqlBind( $dbh, $sql, $bind_aref, $verbose );
    my %genes;
    my $count = 0;

    my (
        $gene_oid,  $gene_display_name,  $homolog, $gene_display_name2,
        $taxon_oid, $taxon_display_name, $domain,  $phylum,
        $ir_class,  $ir_order,           $family,  $genus,
        $species
    );

    for ( ; ; ) {
        if ($phlyacol) {
            (
                $gene_oid,           $gene_display_name, $homolog,
                $gene_display_name2, $taxon_oid,         $taxon_display_name,
                $domain,             $phylum,            $ir_class,
                $ir_order,           $family,            $genus,
                $species
              )
              = $cur->fetchrow();

        } else {
            (
                $gene_oid,           $gene_display_name, $homolog,
                $gene_display_name2, $taxon_oid,         $taxon_display_name
              )
              = $cur->fetchrow();
        }
        last if !$gene_oid;
        $count++;

        my $r;

        $r .= $sd
          . "<input type='checkbox' name='gene_oid' "
          . "value='$gene_oid' />\t";

        my $url = "$main_cgi?section=GeneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . alink( $url, $gene_oid ) . "\t";
        $r .= "$gene_display_name\t";

        my $url = "$main_cgi?section=GeneDetail&gene_oid=$homolog";
        $r .= $homolog . $sd . alink( $url, $homolog ) . "\t";
        $r .= "$gene_display_name2\t";

        my $url = "$main_cgi?section=TaxonDetail&taxon_oid=$taxon_oid";
        $r .=
          $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        if ($phlyacol) {
            my $tmp =
                "$domain, $phylum, $ir_class, $ir_order, $family,"
              . "  $genus, $species";
            $r .= $tmp . $sd . $tmp;
        }

        $it->addRow($r);
        $genes{$gene_oid} = $gene_oid;
    }
    $cur->finish();

    printGeneCartFooter();
    $it->printOuterTable(1);
    printGeneCartFooter() if $count > 10;
    my $nGenes = keys(%genes);
    printStatusLine( "$nGenes genes $count rows loaded.", 2 );
    print end_form();
}

sub getTaxonPhylaInfo {
    my ( $dbh, $taxon_oid ) = @_;

    my $sql = qq{
        select t.domain, t.phylum, t.ir_class, t.ir_order, t.family,
        t.genus, t.species
        from taxon t
        where t.taxon_oid = ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $domain, $phylum, $class, $order, $family, $genus, $species ) =
      $cur->fetchrow();

    $cur->finish();

    return ( $domain, $phylum, $class, $order, $family, $genus, $species );
}


1;
