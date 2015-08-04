############################################################################
# ImgTermBrowser.pm - Browse IMG terms from this module.
#   Include IMG term details.
#
# $Id: ImgTermStats.pm 31256 2014-06-25 06:27:22Z jinghuahuang $
############################################################################
package ImgTermStats;
my $section = "ImgTermStats";
use strict;
use CGI qw( :standard );
use Data::Dumper;
use InnerTable;
use WebConfig;
use WebUtil;
use FuncUtil;
use OracleUtil;
use QueryUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $base_dir             = $env->{base_dir};
my $base_url             = $env->{base_url};
my $img_internal         = $env->{img_internal};
my $tmp_dir              = $env->{tmp_dir};
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $show_private         = $env->{show_private};
my $content_list         = $env->{content_list};
my $pfam_base_url        = $env->{pfam_base_url};
my $cog_base_url         = $env->{cog_base_url};
my $tigrfam_base_url     = $env->{tigrfam_base_url};
my $ko_base_url          = $env->{kegg_orthology_url};
my $include_img_term_bbh = $env->{include_img_term_bbh};
my $YUI = $env->{yui_dir_28};

my $max_gene_batch     = 500;
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}
my $preferences_url = "$main_cgi?section=MyIMG&form=preferences";

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    my $sid = getContactOid();
    HtmlUtil::cgiCacheInitialize( $section);
    HtmlUtil::cgiCacheStart() or return;

    if ( $page eq 'functionCompare' ) {

        # top level page
        printFunctionComparePage();

    } elsif ( $page eq "paralog" ) {
        printParalogTable();
    } elsif ( $page eq "paraloggenelist" ) {
        printImgTermsGeneParalogGeneList();
    } elsif ( $page eq "paralogsamegenelist" ) {
        printImgTermsGeneParalogSameTermGeneList();
    } elsif ( $page eq "bbh" ) {
        printBbhTable();
    } elsif ( $page eq "bbhdetail" ) {
        printBbhDetailTable();
    } elsif ( $page eq "bbhgenelist" ) {
        printTermBbhGeneList();
    } elsif ( $page eq "bbhgenelisttotal" ) {
        printBbhGeneTotalGeneList();
    } elsif ( $page eq "bbhgenelistother" ) {
        printOtherTermBbhGeneList();
    } elsif ( $page eq "bbhgenelistother2" ) {
        printOtherTermBbhGeneList2();
    } elsif ( $page eq "bbhgenelistnoterm" ) {
        printNoTermBbhGeneList();
    } elsif ( $page eq "termscombo" ) {
        printTermsComboTable();
    } elsif ( $page eq "termscombo2" ) {
        printTermsComboTable2();
    } elsif ( $page eq "combodetail" ) {
        printComboDetail();
    } elsif ( $page eq "combogenelist" ) {
        printComboGeneList();
    } elsif ( $page eq "combogenelistfusion" ) {
        printComboGeneListFusion();
    } elsif ( $page eq "combogenelistother" ) {
        printComboGeneListOther();
    } elsif ( $page eq "combogenelistother2" ) {
        printComboGeneListOther2();
    } elsif ( $page eq "combogenelistno" ) {
        printComboGeneListNoTerm();
    } elsif ( $page eq "ko" ) {
        printKoTable();
    } elsif ( $page eq "koimgtermgenelist" ) {
        printTermKoGenes();
    } elsif ( $page eq "nokoimgtermgenelist" ) {
        printTermNoKoGenes();
    } elsif ( $page eq "kotermlist" ) {
        printKoTerms();
    } elsif ( $page eq "kodetail" ) {
        printKoDetail();
    } elsif ( $page eq "koimgtermgenelist2" ) {
        printTermKoGenes2();
    } elsif ( $page eq "kootherimgterm" ) {
        printKoOtherImgTermGene();
    } elsif ( $page eq "kootherimgterm2" ) {
        printKoOtherImgTermGene2();
    } elsif ( $page eq "konoimgterm" ) {
        printKoNoImgTermGeneList();

    } elsif ( $page eq "genomelist" ) {
        printTermGenomeList();

    } else {

        #printParalogTable();
    }

    HtmlUtil::cgiCacheStop();
}

sub printFunctionComparePage {
    
   
    print qq{
        <h1> Protein Family Comparison </h1>
        <p>
        
        </p>
    };
    printStatusLine( "Loading ...", 1 );
    print qq{
            <p>
            <b>Warning: IMG Term Statistics are very slow to run.</b>
            </p>
            <table class='img'>
            <th class='img'> IMG Statistics </th>
            <th class='img'> Description </th>
        };

    print qq{
<tr class='img' >
  <td class='img' >
  <a href='main.cgi?section=KoTermStats&page=combo'> KO Term Protein Families </a> 
  </td>
  <td class='img' >
  KO Term Distribution across Protein Families in IMG 
  </td>
</tr>

<tr class='img' >
  <td class='img' >
  <a href='main.cgi?section=KoTermStats&page=paralog'> KO Term Genomes &amp; Paralog Clusters </a> 
  </td>
  <td class='img' >
  KO Term Distribution across Genomes and Paralog Clusters in IMG
  </td>
</tr>
    };


    print qq{
<tr class='img' >
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=paralog'>IMG Term Paralog</a> 
  </td>
  <td class='img' ></td>
</tr>

<tr>
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=termscombo2'>IMG Term Combinations</a> 
  </td>
  <td class='img' ></td>
</tr>
    };

    if ($include_img_term_bbh) {
        print qq{
<tr>
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=bbh'>IMG Ortholog Clusters</a> 
  </td>
  <td class='img' ></td>
</tr>
    };
    }

    print qq{
<tr>
  <td class='img' >
  <a href='main.cgi?section=ImgTermStats&page=ko'>IMG Term KO</a> 
  </td>
  <td class='img' ></td>
</tr>
    };
    print "</table>\n";

    printStatusLine( "Loaded.", 2 );
}

# gets term name
sub getImgTermName {
    my ( $dbh, $term_oid ) = @_;
    my $sql = qq{
    select term
    from img_term
    where term_oid = ?
    };

    my @a      = ($term_oid);
    my $cur    = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    return $term;
}

# gets all img terms
sub getImgTerms {
    my ($dbh) = @_;
    my $sql = qq{
    select term_oid, term
    from img_term
    where term_type = 'GENE PRODUCT'
    };

    # hash of hashes, child id => hash of parent ids
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $term ) = $cur->fetchrow();
        last if !$id;
        $term =~ s/\t/ /g;
        $hash{$id} = $term;
    }
    $cur->finish();
    return \%hash;
}

# gets all img terms
sub getImgTermsGenomeCnt {
    my ($dbh) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.function, count(distinct g.taxon)
        from gene_img_functions g
        where g.function is not null
        $rclause
        $imgClause
        group by g.function
    };

    # hash of hashes, child id => hash of parent ids
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# average number of genes with term per genome
sub getImgTermsAvgGenome {
    my ($dbh) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select a.function, avg(a.gcnt)
        from (
            select g.function, g.taxon, count(g.gene_oid) as gcnt
            from gene_img_functions g
            where g.function is not null
            $rclause
            $imgClause
            group by g.function, g.taxon
        ) a
        group by a.function
    };

    # hash of hashes, child id => hash of parent ids
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# number of genes with term in paralog cluster
sub getImgTermsGeneParalog {
    my ($dbh) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my $sql = qq{
        select g.function, count(distinct g.gene_oid)
        from gene_img_functions g, gene_paralogs gp
        where g.gene_oid = gp.gene_oid
        and g.function is not null
        $rclause
        $imgClause
        group by g.function
    };

    # hash of hashes, child id => hash of parent ids
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# number of genes with term in paralog cluster gene list
sub printImgTermsGeneParalogGeneList {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();

    my $name = getImgTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      Paralog Gene List <br/>
      $name
      </h1>  
    };

    #$term_oid =~ s/'/''/g;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif.gene_oid, g.gene_display_name
        from gene_img_functions gif, gene_paralogs gp, gene g
        where gif.gene_oid = gp.gene_oid
        and g.gene_oid = gif.gene_oid 
        and gif.function = ?
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid );
}

# number of genes with term whose
# paralog is annotated with the same term
sub getImgTermsGeneParalogSameTerm {
    my ($dbh) = @_;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.function, count(distinct g.gene_oid)
        from gene_img_functions g, gene_paralogs gp,
            gene_img_functions gif2
        where g.gene_oid = gp.gene_oid
        and gp.paralog = gif2.gene_oid
        and g.function is not null
        $rclause
        $imgClause
        group by g.function
    };

    # hash of hashes, child id => hash of parent ids
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# number of genes with term whose
# paralog is annotated with the same term
# gene list
sub printImgTermsGeneParalogSameTermGeneList {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();

    my $name = getImgTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      Paralog Gene List <br/>
      $name
      </h1>  
    };

    #$term_oid =~ s/'/''/g;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif.gene_oid, g.gene_display_name
        from gene_img_functions gif, gene_paralogs gp, 
            gene_img_functions gif2, gene g
        where gif.gene_oid = gp.gene_oid
        and gp.paralog = gif2.gene_oid
        and gif.gene_oid = g.gene_oid
        and gif.function = gif2.function
        and gif.function is not null
        and gif.function = ?
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid );
}

# average % identtity between paralogs annotated with the
# same img term
sub getImgTermsParalogPercent {
    my ($dbh) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select g.function, avg(gp.percent_identity)
        from gene_img_functions g, gene_paralogs gp
        where g.gene_oid = gp.gene_oid
        and g.function is not null
        $rclause
        $imgClause
        group by g.function
    };

    # hash of hashes, child id => hash of parent ids
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# print paralog html table
sub printParalogTable {

    print qq{
      <h1> IMG Terms Paralog </h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $terms_href = getImgTerms($dbh);
    print "Getting terms genome count.<br/>\n";
    my $terms_genome_cnt_href = getImgTermsGenomeCnt($dbh);
    print "Getting terms gene count.<br/>\n";
    my $terms_gene_cnt_href = getTermsGeneCnt($dbh);
    print "Getting avg.<br/>\n";
    my $avgGenome_href = getImgTermsAvgGenome($dbh);
    print "Getting paralog.<br/>\n";
    my $geneParalog_href = getImgTermsGeneParalog($dbh);
    print "Getting paralog same term.<br/>\n";
    my $sameterm_href = getImgTermsGeneParalogSameTerm($dbh);
    print "Getting percent.<br/>\n";
    my $percentIdent_href = getImgTermsParalogPercent($dbh);
    printEndWorkingDiv();

    printMainForm();
    WebUtil::printFuncCartFooterForEditor();

    my $count = 0;
    my $it    = new InnerTable( 1, "imgtermparalog$$", "imgtermparalog", 1 );
    my $sd    = $it->getSdDelim();                                              # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "IMG Term ID",    "number asc",  "right" );
    $it->addColSpec( "IMG Term Name",  "char asc",    "left" );
    $it->addColSpec( "Num of Genes",   "number desc", "right" );
    $it->addColSpec( "Num of Genomes", "number desc", "right" );
    my $title = "Avg num of genes with this IMG term per taxon id";
    $it->addColSpec( "Avg # Genes per Genome", "number desc", "right", "", "title='$title'" );
    $title = "Num of genes with term in paralog cluster";
    $it->addColSpec( "Num of Genes in Paralog", "number desc", "right", "", "title='$title'" );
    $title = "Num of genes with term whose paralog is annotated witht same term";
    $it->addColSpec( "Num of Genes whose Paralog has Same Term", "number desc", "right", "", "title='$title'" );
    $title = "Avg percent indentity between paralogs annotated with the same IMG term";
    $it->addColSpec( "Avg % indentity", "number desc", "right", "", "title='$title'" );

    foreach my $term_oid ( keys %$terms_href ) {
        my $term = $terms_href->{$term_oid};
        my $avg = sprintf( "%.2f", $avgGenome_href->{$term_oid} );
        $avg = 0 if ( $avg eq "" || $avg == 0 );
        my $para = $geneParalog_href->{$term_oid};
        $para = 0 if ( $para eq "" );
        my $same = $sameterm_href->{$term_oid};
        $same = 0 if ( $same eq "" );
        my $perc = sprintf( "%.2f", $percentIdent_href->{$term_oid} );
        $perc = 0 if ( $perc eq "" || $perc == 0 );
        $count++;
        my $r;

        my $padded_term_oid = FuncUtil::termOidPadded($term_oid);
        $r .= $sd . "<input type='checkbox' name='term_oid' " . "value='$padded_term_oid' />" . "\t";

        my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
        $url .= "&term_oid=$padded_term_oid";
        $r   .= $padded_term_oid . $sd . alink( $url, $padded_term_oid ) . "\t";

        #my $url = "$section_cgi&page=bbhdetail&term_oid=$term_oid";
        #$url = alink( $url, $term );
        $r .= $term . $sd . $term . "\t";

        # gene count
        my $tmpcnt = $terms_gene_cnt_href->{$term_oid};
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        if ( $tmpcnt > 0 ) {
            my $url = "main.cgi?section=ImgTermBrowser&page=imgTermBrowserGenes&term_oid=$term_oid";
            $url = alink( $url, $tmpcnt );
            $r .= $tmpcnt . $sd . $url . "\t";
        } else {
            $r .= $tmpcnt . $sd . $tmpcnt . "\t";
        }

        # genome count
        my $tmpcnt = $terms_genome_cnt_href->{$term_oid};
        $tmpcnt = 0 if ( $tmpcnt eq "" );
        my $url = "$section_cgi&page=genomelist&term_oid=$term_oid";
        $url = alink( $url, $tmpcnt );
        $r .= $tmpcnt . $sd . $url . "\t";

        $r .= $avg . $sd . $avg . "\t";

        if ( $para > 0 ) {
            my $url = "$section_cgi&page=paraloggenelist&term_oid=$term_oid";
            $url = alink( $url, $para );
            $r .= $para . $sd . $url . "\t";
        } else {
            $r .= $para . $sd . $para . "\t";
        }

        # paralogsamegenelist
        if ( $same > 0 ) {
            my $url = "$section_cgi&page=paralogsamegenelist&term_oid=$term_oid";
            $url = alink( $url, $same );
            $r .= $same . $sd . $url . "\t";
        } else {
            $r .= $same . $sd . $same . "\t";
        }

        $r .= $perc . $sd . $perc . "\t";

        $it->addRow($r);
    }

    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();

    printStatusLine( "$count Loaded.", 2 );

}

# get cluster name
sub getBbhName {
    my ( $dbh, $cluster_id ) = @_;
    my $sql = qq{
select bc.cluster_name
from bbh_cluster bc
where bc.cluster_id = ?
    };

    my @a      = ($cluster_id);
    my $cur    = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    return $term;
}

# gets all bbh for a img term
sub getTermBbh {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select distinct bc.cluster_id, bc.cluster_name
        from gene_img_functions g, bbh_cluster_member_genes bcmg, bbh_cluster bc
        where g.function = ?
        and g.gene_oid = bcmg.member_genes
        and bcmg.cluster_id = bc.cluster_id
        $rclause
        $imgClause
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $name;
    }
    $cur->finish();
    return \%hash;
}

# number of genes with specified img term in img ortholog cluster
sub getTermBbhGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select bcmg.cluster_id, count(distinct g.gene_oid)
        from gene_img_functions g, bbh_cluster_member_genes bcmg
        where g.function = ?
        and g.gene_oid = bcmg.member_genes
        $rclause
        $imgClause
        group by bcmg.cluster_id     
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printTermBbhGeneList {
    my $term_oid   = param("term_oid");
    my $cluster_id = param("cluster_id");

    my $dbh = dbLogin();

    #$cluster_id =~ s/'/''/g;
    my $bbh_name = getBbhName( $dbh,     $cluster_id );
    my $name     = getImgTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Ortholog Cluster <br/>
      $bbh_name <br/>
      $name
      </h1>  
    };

    #$term_oid   =~ s/'/''/g;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif.gene_oid, g.gene_display_name
        from gene_img_functions gif, bbh_cluster_member_genes bcmg, gene g
        where gif.function = ?
        and gif.gene_oid = bcmg.member_genes
        and gif.gene_oid = g.gene_oid
        and bcmg.cluster_id = ?
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "",, $term_oid, $cluster_id );
}

# total number of genes in img ortholog cluster
sub getBbhGeneTotalCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select bcmg2.cluster_id, count(distinct bcmg2.member_genes)
        from bbh_cluster_member_genes bcmg2, gene g
        where bcmg2.cluster_id in(
          select bcmg.cluster_id
          from gene_img_functions gif, bbh_cluster_member_genes bcmg
          where gif.function = ?
          and gif.gene_oid = bcmg.member_genes)
        and g.gene_oid = bcmg2.member_genes
        $rclause
        $imgClause
        group by bcmg2.cluster_id   
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# total number of genes in img ortholog cluster
sub printBbhGeneTotalGeneList {
    my $term_oid   = param("term_oid");
    my $cluster_id = param("cluster_id");

    my $dbh      = dbLogin();
    my $bbh_name = getBbhName( $dbh, $cluster_id );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Ortholog Cluster <br/>
      $bbh_name <br/>
      </h1>  
    };

    #$term_oid   =~ s/'/''/g;
    #$cluster_id =~ s/'/''/g;

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
select distinct bcmg2.member_genes, g.gene_display_name
from bbh_cluster_member_genes bcmg2, gene g
where bcmg2.cluster_id = ?
and g.gene_oid = bcmg2.member_genes
$rclause
$imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $cluster_id );
}

# number of genes in img ortholog cluster with img term other
# than the specified img term
#
# this counts genes with muliple terms that are counted "with img term"
# - so its counted twice or more
#
sub getOtherTermBbhGeneTotalCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select bcmg2.cluster_id, count(distinct g.gene_oid)
        from gene_img_functions g, bbh_cluster_member_genes bcmg2
        where g.gene_oid = bcmg2.member_genes
        and g.function != ?
        and bcmg2.cluster_id in(
          select bcmg.cluster_id
          from gene_img_functions gif, bbh_cluster_member_genes bcmg
          where gif.function = ?
          and gif.gene_oid = bcmg.member_genes)
        $rclause
        $imgClause
        group by bcmg2.cluster_id  
    };

    my @a = ( $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# number of genes in img ortholog cluster with img term other
# than the specified img term
#
# this one ignore genes already counted in term in that bbh
#
sub getOtherTermBbhGeneTotalCnt2 {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select bcmg2.cluster_id, count(distinct g.gene_oid)
        from gene_img_functions g, bbh_cluster_member_genes bcmg2
        where g.gene_oid = bcmg2.member_genes
        and g.function != ?
        and bcmg2.cluster_id in(
          select bcmg.cluster_id
          from gene_img_functions gif, bbh_cluster_member_genes bcmg
          where gif.function = ?
          and gif.gene_oid = bcmg.member_genes)
        and g.gene_oid not in(
          select gif3.gene_oid
          from gene_img_functions gif3
          where gif3.function = ?)
        $rclause
        $imgClause
        group by bcmg2.cluster_id  
    };

    my @a = ( $term_oid, $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printOtherTermBbhGeneList {
    my $term_oid   = param("term_oid");
    my $cluster_id = param("cluster_id");

    my $dbh = dbLogin();

    #$term_oid   =~ s/'/''/g;
    #$cluster_id =~ s/'/''/g;
    my $bbh_name = getBbhName( $dbh, $cluster_id );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Ortholog Cluster <br/>
      $bbh_name <br/>
      with other IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif2.gene_oid, g.gene_display_name
        from gene_img_functions gif2, bbh_cluster_member_genes bcmg2, gene g
        where gif2.gene_oid = bcmg2.member_genes
        and gif2.function != ?
        and bcmg2.cluster_id = ?
        and g.gene_oid =  bcmg2.member_genes
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid, $cluster_id );
}

sub printOtherTermBbhGeneList2 {
    my $term_oid   = param("term_oid");
    my $cluster_id = param("cluster_id");

    my $dbh = dbLogin();

    #$term_oid   =~ s/'/''/g;
    #$cluster_id =~ s/'/''/g;
    my $bbh_name = getBbhName( $dbh, $cluster_id );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Ortholog Cluster <br/>
      $bbh_name <br/>
      with other IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif2.gene_oid, g.gene_display_name
        from gene_img_functions gif2, bbh_cluster_member_genes bcmg2, gene g
        where gif2.gene_oid = bcmg2.member_genes
        and gif2.function != ?
        and bcmg2.cluster_id = ?
        and g.gene_oid =  bcmg2.member_genes
        and gif2.gene_oid not in (
            select gif3.gene_oid
            from gene_img_functions gif3
            where gif3.function = ?
        )
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid, $cluster_id, $term_oid );
}

# get all terms bbh gene cnt
sub getAllTermsBbhGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select bcmg.cluster_id, count(distinct g.gene_oid)
        from gene_img_functions g, bbh_cluster_member_genes bcmg
        where g.gene_oid = bcmg.member_genes
        and bcmg.cluster_id in(
          select bcmg2.cluster_id
          from gene_img_functions gif2, bbh_cluster_member_genes bcmg2
          where gif2.function = ?
          and gif2.gene_oid = bcmg2.member_genes
        )
        $rclause
        $imgClause
        group by bcmg.cluster_id     
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printNoTermBbhGeneList {
    my $term_oid   = param("term_oid");
    my $cluster_id = param("cluster_id");

    my $dbh = dbLogin();

    #$term_oid   =~ s/'/''/g;
    #$cluster_id =~ s/'/''/g;
    my $bbh_name = getBbhName( $dbh, $cluster_id );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Ortholog Cluster <br/>
      $bbh_name <br/>
      with No IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g2.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g2.taxon');
    my $sql    = qq{
        select distinct g2.gene_oid, g2.gene_display_name
        from bbh_cluster_member_genes bcmg2, gene g2
        where bcmg2.cluster_id = ?
        and g2.gene_oid = bcmg2.member_genes
        $rclause
        $imgClause
        minus
        select g.gene_oid, g.gene_display_name
        from gene_img_functions gif, bbh_cluster_member_genes bcmg, gene g
        where gif.gene_oid = bcmg.member_genes
        and bcmg.cluster_id = ?
        and gif.gene_oid = g.gene_oid
    };

    printGeneListSectionSorting( $sql, "", "", $cluster_id, $cluster_id );
}

sub getTermsBbhCount {
    my ($dbh)  = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.function, count(distinct bc.cluster_id)
        from gene_img_functions g, bbh_cluster_member_genes bcmg, bbh_cluster bc
        where g.gene_oid = bcmg.member_genes
        and bcmg.cluster_id = bc.cluster_id
        $rclause
        $imgClause
        group by g.function
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $cnt ) = $cur->fetchrow();
        last if !$id;
        $hash{$id} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# print img ortholog cluster table for a given term
sub printBbhTable {

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    print qq{
      <h1> IMG Terms IMG Ortholog Clusters </h1>  
    };

    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $terms_href = getImgTerms($dbh);
    print "Getting bbh counts.<br/>\n";
    my $bbhcnt_href = getTermsBbhCount($dbh);
    printEndWorkingDiv();

    my $count = 0;
    my $it    = new InnerTable( 1, "imgtermbbh$$", "imgtermbbh", 1 );
    my $sd    = $it->getSdDelim();                                      # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "IMG Term ID",                "number asc",  "right" );
    $it->addColSpec( "Name",                       "char asc",    "left" );
    $it->addColSpec( "IMG Ortholog Cluster Count", "number desc", "right" );

    foreach my $term_oid ( keys %$terms_href ) {
        my $term = $terms_href->{$term_oid};
        my $cnt  = $bbhcnt_href->{$term_oid};
        $cnt = 0 if ( $cnt eq "" );

        $count++;
        my $r;

        my $padded_term_oid = FuncUtil::termOidPadded($term_oid);
        $r .= $sd . "<input type='checkbox' name='term_oid' " . "value='$padded_term_oid' />" . "\t";

        my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
        $url .= "&term_oid=$padded_term_oid";
        $r   .= $padded_term_oid . $sd . alink( $url, $padded_term_oid ) . "\t";

        $r .= $term . $sd . $term . "\t";

        if ( $cnt == 0 ) {
            $r .= $cnt . $sd . $cnt . "\t";
        } else {
            my $url = "$section_cgi&page=bbhdetail&term_oid=$term_oid";
            $url = alink( $url, $cnt );
            $r .= $cnt . $sd . $url . "\t";
        }

        $it->addRow($r);
    }
    $it->printOuterTable(1);
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

# print img ortholog cluster table for a given term
sub printBbhDetailTable {
    my $term_oid = param("term_oid");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $name = getImgTermName( $dbh, $term_oid );

    print qq{
      <h1> IMG Ortholog Clusters with IMG Term<br/> $name </h1>  
    };

    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $termBbh_href = getTermBbh( $dbh, $term_oid );
    print "Getting term counts.<br/>\n";
    my $termBbhGeneCnt_href = getTermBbhGeneCnt( $dbh, $term_oid );
    print "Getting total counts.<br/>\n";
    my $termBbhGeneTotalCnt_href = getBbhGeneTotalCnt( $dbh, $term_oid );
    print "Getting other term count.<br/>\n";
    my $other_href = getOtherTermBbhGeneTotalCnt( $dbh, $term_oid );
    print "Getting other term count ignore gene.<br/>\n";
    my $other_href2 = getOtherTermBbhGeneTotalCnt2( $dbh, $term_oid );
    print "Getting bbh with no term count.<br/>\n";
    my $no_href = getAllTermsBbhGeneCnt( $dbh, $term_oid );
    printEndWorkingDiv();

    # 0 sort col
    my $it = new InnerTable( 1, "imgtermbbh$$", "imgtermbbh", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "IMG Ortholog Cluster ID",                    "number asc",  "right" );
    $it->addColSpec( "Name",                                       "char asc",    "left" );
    $it->addColSpec( "Num of Genes with IMG Term",                 "number desc", "right" );
    $it->addColSpec( "Total Num of Genes in IMG Ortholog Cluster", "number desc", "right" );
    my $title = "Num of genes in IMG ortholog cluster with addition IMG terms other than the specified IMG term";
    $it->addColSpec( "Num of Genes with other IMG Term", "number desc", "right", "", "title='$title'" );
    my $title = "Num of genes in IMG ortholog cluster with only IMG terms other than the specified IMG term";
    $it->addColSpec( "Num of Genes with other IMG Term **", "number desc", "right", "", "title='$title'" );
    $it->addColSpec( "Num of Genes without IMG Term", "number desc", "right" );

    my $count = 0;
    foreach my $bbh_oid ( sort keys %$termBbh_href ) {
        my $name           = $termBbh_href->{$bbh_oid};
        my $gene_cnt       = $termBbhGeneCnt_href->{$bbh_oid};
        my $total_gene_cnt = $termBbhGeneTotalCnt_href->{$bbh_oid};
        my $other_gene_cnt = $other_href->{$bbh_oid};
        $other_gene_cnt = 0 if ( $other_gene_cnt eq "" );
        my $other_gene_cnt2 = $other_href2->{$bbh_oid};
        $other_gene_cnt2 = 0 if ( $other_gene_cnt2 eq "" );
        my $no_cnt = $total_gene_cnt - $no_href->{$bbh_oid};
        $no_cnt = 0 if ( $no_cnt eq "" );

        $count++;
        my $r;
        $r .= $bbh_oid . $sd . $bbh_oid . "\t";
        $r .= $name . $sd . $name . "\t";

        # bbhgenelist
        if ( $gene_cnt > 0 ) {
            my $url = "$section_cgi&page=bbhgenelist" . "&cluster_id=$bbh_oid&term_oid=$term_oid";
            $url = alink( $url, $gene_cnt );
            $r .= $gene_cnt . $sd . $url . "\t";
        } else {
            $r .= $gene_cnt . $sd . $gene_cnt . "\t";
        }

        # bbhgenelisttotal
        if ( $total_gene_cnt > 0 ) {
            my $url = "$section_cgi&page=bbhgenelisttotal" . "&cluster_id=$bbh_oid&term_oid=$term_oid";
            $url = alink( $url, $total_gene_cnt );
            $r .= $total_gene_cnt . $sd . $url . "\t";
        } else {
            $r .= $total_gene_cnt . $sd . $total_gene_cnt . "\t";
        }

        # bbhgenelistother
        if ( $other_gene_cnt > 0 ) {
            my $url = "$section_cgi&page=bbhgenelistother" . "&cluster_id=$bbh_oid&term_oid=$term_oid";
            $url = alink( $url, $other_gene_cnt );
            $r .= $other_gene_cnt . $sd . $url . "\t";
        } else {
            $r .= $other_gene_cnt . $sd . $other_gene_cnt . "\t";
        }

        #  bbhgenelistother2
        if ( $other_gene_cnt2 > 0 ) {
            my $url = "$section_cgi&page=bbhgenelistother2" . "&cluster_id=$bbh_oid&term_oid=$term_oid";
            $url = alink( $url, $other_gene_cnt2 );
            $r .= $other_gene_cnt2 . $sd . $url . "\t";
        } else {
            $r .= $other_gene_cnt2 . $sd . $other_gene_cnt2 . "\t";
        }

        # bbhgenelistnoterm
        if ( $no_cnt > 0 ) {
            my $url = "$section_cgi&page=bbhgenelistnoterm" . "&cluster_id=$bbh_oid&term_oid=$term_oid";
            $url = alink( $url, $no_cnt );
            $r .= $no_cnt . $sd . $url . "\t";
        } else {
            $r .= $no_cnt . $sd . $no_cnt . "\t";
        }
        $it->addRow($r);
    }

    $it->printOuterTable(1);
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

# ------------------------ combo table 3

# table 3 frome spec doc

# get all terms combo
sub getTermsCombo {
    my ($dbh)  = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct g.function, dtc.combo_oid, 
            dtc.cog_ids, dtc.pfam_ids, dtc.tigrfam_ids, dtc.ko_ids
        from gene_img_functions g, dt_func_combo_genes_4iterms dtg, dt_func_combo_4iterms dtc
        where g.gene_oid = dtg.gene_oid
        and dtg.combo_oid = dtc.combo_oid
        and g.function is not null
        $rclause
        $imgClause
        order by 1 
    };

    if ( $rclause eq "" ) {
        $sql = qq{
            select distinct gif.function, 
                dtc.combo_oid, dtc.cog_ids, dtc.pfam_ids, dtc.tigrfam_ids, dtc.ko_ids
            from gene_img_functions gif, dt_func_combo_genes_4iterms dtg, dt_func_combo_4iterms dtc
            where gif.gene_oid = dtg.gene_oid
            and dtg.combo_oid = dtc.combo_oid
            and gif.function is not null
            order by 1 
        };
    }

    my @a;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $term_oid, $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids, $ko_ids ) = $cur->fetchrow();
        last if !$term_oid;
        push( @a, "$term_oid\t$combo_oid\t$cog_ids\t$pfam_ids\t$tigrfam_ids\t$ko_ids" );
    }
    $cur->finish();
    return \@a;
}

# convert all hash keys to string separate by a space
sub hashKey2String {
    my ($href) = @_;
    my $str;
    foreach my $key ( keys %$href ) {
        $str = $str . " " . $key;
    }
    return $str;
}

# convert array list of objects to hash keys
sub addList2Hash {
    my ( $aref, $href ) = @_;
    foreach my $x (@$aref) {
        $href->{$x} = "";
    }
}

# print terms combo table
sub printTermsComboTable {

    print qq{
      <h1> IMG Term Combinations</h1>  

      <p>
      Summary <a href='$section_cgi&page=termscombo2'> version </a>
      </p>
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $terms_href = getImgTerms($dbh);
    print "Getting combos.<br/>\n";
    my $terms_aref = getTermsCombo($dbh);
    printEndWorkingDiv();

    printMainForm();
    WebUtil::printFuncCartFooterForEditor();

    # 0 sort col
    my $it = new InnerTable( 1, "imgtermcombo$$", "imgtermcombo", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Term ID",              "number asc",  "right" );
    $it->addColSpec( "Name",                 "char asc",    "left" );
    $it->addColSpec( "COG IDs",              "char asc",    "left" );
    $it->addColSpec( "Pfam IDs",             "char asc",    "left" );
    $it->addColSpec( "TIGRfam IDs",          "char asc",    "left" );
    $it->addColSpec( "Num of Unique Combos", "number desc", "right" );

    my $count        = 0;
    my $last_term_id = "";
    my $term_count   = 0;
    my %cog_hash;
    my %pfam_hash;
    my %tigr_hash;
    foreach my $line (@$terms_aref) {
        my ( $term_oid, $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids ) =
          split( /\t/, $line );

        if ( $last_term_id eq "" ) {
            $last_term_id = $term_oid;
            $count++;
        }

        if ( $term_oid eq $last_term_id ) {
            my @cogline = split( / /, $cog_ids );
            addList2Hash( \@cogline, \%cog_hash );
            my @pfamline = split( / /, $pfam_ids );
            addList2Hash( \@pfamline, \%pfam_hash );
            my @tigrfamline = split( / /, $tigrfam_ids );
            addList2Hash( \@tigrfamline, \%tigr_hash );
            $term_count++;
        } else {
            my $term_name = $terms_href->{$last_term_id};
            my $r;

            #$r .= $last_term_id . $sd . $last_term_id . "\t";
            my $padded_term_oid = FuncUtil::termOidPadded($last_term_id);

            $r .= $sd . "<input type='checkbox' name='term_oid' " . "value='$padded_term_oid' />" . "\t";

            my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
            $url .= "&term_oid=$padded_term_oid";
            $r   .= $padded_term_oid . $sd . alink( $url, $padded_term_oid ) . "\t";

            $r .= $term_name . $sd . $term_name . "\t";

            my $str = hashKey2String( \%cog_hash );
            $r .= $str . $sd . $str . "\t";
            my $str = hashKey2String( \%pfam_hash );
            $r .= $str . $sd . $str . "\t";
            my $str = hashKey2String( \%tigr_hash );
            $r .= $str . $sd . $str . "\t";

            if ( $term_count != 0 ) {
                my $url = $section_cgi . "&page=combodetail" . "&term_oid=$last_term_id";    # . "&combo_oid=$last_combo_id";
                $url = alink( $url, $term_count );
                $r .= $term_count . $sd . $url . "\t";
            } else {
                $r .= $term_count . $sd . $term_count . "\t";
            }

            $it->addRow($r);

            %cog_hash   = ();
            %pfam_hash  = ();
            %tigr_hash  = ();
            $term_count = 1;
            $count++;
            my @cogline = split( / /, $cog_ids );
            addList2Hash( \@cogline, \%cog_hash );
            my @pfamline = split( / /, $pfam_ids );
            addList2Hash( \@pfamline, \%pfam_hash );
            my @tigrfamline = split( / /, $tigrfam_ids );
            addList2Hash( \@tigrfamline, \%tigr_hash );
        }

        $last_term_id = $term_oid;
    }

    # last record
    my $term_name = $terms_href->{$last_term_id};
    my $r;
    my $padded_term_oid = FuncUtil::termOidPadded($last_term_id);
    $r .= $sd . "<input type='checkbox' name='term_oid' " . "value='$padded_term_oid' />" . "\t";
    my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
    $url .= "&term_oid=$padded_term_oid";
    $r   .= $padded_term_oid . $sd . alink( $url, $padded_term_oid ) . "\t";

    $r .= $term_name . $sd . $term_name . "\t";

    my $str = hashKey2String( \%cog_hash );
    $r .= $str . $sd . $str . "\t";
    my $str = hashKey2String( \%pfam_hash );
    $r .= $str . $sd . $str . "\t";
    my $str = hashKey2String( \%tigr_hash );
    $r .= $str . $sd . $str . "\t";

    if ( $term_count != 0 ) {
        my $url = $section_cgi . "&page=combodetail" . "&term_oid=$last_term_id";    # . "&combo_oid=$last_combo_id";
        $url = alink( $url, $term_count );
        $r .= $term_count . $sd . $url . "\t";
    } else {
        $r .= $term_count . $sd . $term_count . "\t";
    }

    $it->addRow($r);

    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

# summary - shows only counts
sub printTermsComboTable2 {

    print qq{
      <h1> IMG Term Combinations</h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $terms_href = getImgTerms($dbh);
    print "Getting combos.<br/>\n";
    my $terms_aref = getTermsCombo($dbh);
    printEndWorkingDiv();

    printMainForm();
    WebUtil::printFuncCartFooterForEditor();

    # 0 sort col
    my $it = new InnerTable( 1, "imgtermcombo$$", "imgtermcombo", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Term ID",              "number asc",  "right" );
    $it->addColSpec( "Name",                 "char asc",    "left" );
    $it->addColSpec( "COG Count",            "number desc", "left" );
    $it->addColSpec( "Pfam Count",           "number desc", "left" );
    $it->addColSpec( "TIGRfam Count",        "number desc", "left" );
    $it->addColSpec( "KO Count",             "number desc", "left" );
    $it->addColSpec( "Num of Unique Combos", "number desc", "right" );

    my $count        = 0;
    my $last_term_id = "";
    my $term_count   = 0;
    my %cog_hash;
    my %pfam_hash;
    my %tigr_hash;
    my %ko_hash;
    my %term_printed;

    foreach my $line (@$terms_aref) {
        my ( $term_oid, $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids, $ko_ids ) = split( /\t/, $line );

        next if ( !exists $terms_href->{$term_oid} );

        $term_printed{$term_oid} = 1;

        if ( $last_term_id eq "" ) {
            $last_term_id = $term_oid;
        }

        if ( $term_oid eq $last_term_id ) {
            my @cogline = split( / /, $cog_ids );
            addList2Hash( \@cogline, \%cog_hash );
            my @pfamline = split( / /, $pfam_ids );
            addList2Hash( \@pfamline, \%pfam_hash );
            my @tigrfamline = split( / /, $tigrfam_ids );
            addList2Hash( \@tigrfamline, \%tigr_hash );
            my @koline = split( / /, $ko_ids );
            addList2Hash( \@koline, \%ko_hash );
            $term_count++;
        } else {
            my $term_name = $terms_href->{$last_term_id};
            my $r;

            #$r .= $last_term_id . $sd . $last_term_id . "\t";
            my $padded_term_oid = FuncUtil::termOidPadded($last_term_id);

            $r .= $sd . "<input type='checkbox' name='term_oid' " . "value='$padded_term_oid' />" . "\t";

            my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
            $url .= "&term_oid=$padded_term_oid";
            $r   .= $padded_term_oid . $sd . alink( $url, $padded_term_oid ) . "\t";

            $r .= $term_name . $sd . $term_name . "\t";

            # comboproteinlist
            my $str = keys %cog_hash;
            $r .= $str . $sd . $str . "\t";
            my $str = keys %pfam_hash;
            $r .= $str . $sd . $str . "\t";
            my $str = keys %tigr_hash;
            $r .= $str . $sd . $str . "\t";
            my $str = keys %ko_hash;
            $r .= $str . $sd . $str . "\t";

            if ( $term_count != 0 ) {
                my $url = $section_cgi . "&page=combodetail" . "&term_oid=$last_term_id";    # . "&combo_oid=$last_combo_id";
                $url = alink( $url, $term_count );
                $r .= $term_count . $sd . $url . "\t";
            } else {
                $r .= $term_count . $sd . $term_count . "\t";
            }

            $it->addRow($r);

            %cog_hash   = ();
            %pfam_hash  = ();
            %tigr_hash  = ();
            %ko_hash    = ();
            $term_count = 1;
            $count++;
            my @cogline = split( / /, $cog_ids );
            addList2Hash( \@cogline, \%cog_hash );
            my @pfamline = split( / /, $pfam_ids );
            addList2Hash( \@pfamline, \%pfam_hash );
            my @tigrfamline = split( / /, $tigrfam_ids );
            addList2Hash( \@tigrfamline, \%tigr_hash );
            my @koline = split( / /, $ko_ids );
            addList2Hash( \@koline, \%ko_hash );
        }

        $last_term_id = $term_oid;
    }

    # last record
    my $term_name = $terms_href->{$last_term_id};
    $term_printed{$last_term_id} = 1;

    my $r;
    my $padded_term_oid = FuncUtil::termOidPadded($last_term_id);
    $r .= $sd . "<input type='checkbox' name='term_oid' " . "value='$padded_term_oid' />" . "\t";
    my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
    $url .= "&term_oid=$padded_term_oid";
    $r   .= $padded_term_oid . $sd . alink( $url, $padded_term_oid ) . "\t";

    $r .= $term_name . $sd . $term_name . "\t";

    my $str = keys %cog_hash;
    $r .= $str . $sd . $str . "\t";
    my $str = keys %pfam_hash;
    $r .= $str . $sd . $str . "\t";
    my $str = keys %tigr_hash;
    $r .= $str . $sd . $str . "\t";
    my $str = keys %ko_hash;
    $r .= $str . $sd . $str . "\t";

    if ( $term_count != 0 ) {
        my $url = $section_cgi . "&page=combodetail" . "&term_oid=$last_term_id";    # . "&combo_oid=$last_combo_id";
        $url = alink( $url, $term_count );
        $r .= $term_count . $sd . $url . "\t";
    } else {
        $r .= $term_count . $sd . $term_count . "\t";
    }
    $it->addRow($r);
    $count++;

    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();

    my $cnt = keys %$terms_href;

    printStatusLine( "$cnt Loaded.", 2 );
}

# table 4 - combo details sections ----------------------------

# and sort the array too
sub array2String {
    my ($aref) = @_;
    my $str = "";
    foreach my $id ( sort @$aref ) {
        if ( $str eq "" ) {
            $str = $id;
        } else {
            $str = $str . " " . $id;
        }
    }
    return $str;
}

# gets all combo for a given term
sub getCombo {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct dtc.combo_oid, dtc.cog_ids, dtc.pfam_ids, dtc.tigrfam_ids, dtc.ko_ids
        from gene_img_functions g, dt_func_combo_genes_4iterms dtg, dt_func_combo_4iterms dtc
        where g.gene_oid = dtg.gene_oid
        and dtg.combo_oid = dtc.combo_oid
        and g.function = ?
        $rclause
        $imgClause
    };

    my @a = ($term_oid);
    my @res;
    my %distinct_cog;
    my %distinct_pfam;
    my %distinct_tigrfam;
    my %distinct_ko;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids, $ko_ids ) = $cur->fetchrow();
        last if !$combo_oid;

        # sort function ids alph not by position as stored in db
        my @tmp = split( /\s/, $cog_ids );
        $cog_ids     = array2String( \@tmp );
        @tmp         = split( /\s/, $pfam_ids );
        $pfam_ids    = array2String( \@tmp );
        @tmp         = split( /\s/, $tigrfam_ids );
        $tigrfam_ids = array2String( \@tmp );
        @tmp         = split( /\s/, $ko_ids );
        $ko_ids      = array2String( \@tmp );

        push( @res, "$combo_oid\t$cog_ids\t$pfam_ids\t$tigrfam_ids\t$ko_ids" );

        my @tmp = split( /\s/, $cog_ids );
        addList2Hash( \@tmp, \%distinct_cog );
        my @tmp = split( /\s/, $pfam_ids );
        addList2Hash( \@tmp, \%distinct_pfam );
        my @tmp = split( /\s/, $tigrfam_ids );
        addList2Hash( \@tmp, \%distinct_tigrfam );
        my @tmp = split( /\s/, $ko_ids );
        addList2Hash( \@tmp, \%distinct_ko );
    }
    $cur->finish();
    return ( \@res, \%distinct_cog, \%distinct_pfam, \%distinct_tigrfam, \%distinct_ko );
}

# gets number of genes with combination and img term
sub getComboGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select dtg.combo_oid, count(g.gene_oid)
        from gene_img_functions g, dt_func_combo_genes_4iterms dtg
        where g.gene_oid = dtg.gene_oid
        and g.function = ?
        $rclause
        $imgClause
        group by dtg.combo_oid
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printComboGeneList {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    my $name = getImgTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Term Combination Gene List<br/>
      $name
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif.gene_oid, g.gene_display_name
        from gene_img_functions gif, dt_func_combo_genes_4iterms dtg, gene g
        where gif.gene_oid = dtg.gene_oid
        and dtg.combo_oid = ?
        and gif.function = ?
        and g.gene_oid = gif.gene_oid
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $combo_oid, $term_oid );
}

sub printComboGeneListFusion {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    my $name = getImgTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Term Combination Fusion Gene List<br/>
      $name
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif.gene_oid, g.gene_display_name
        from gene_img_functions gif, dt_func_combo_genes_4iterms dtg, gene g,
            gene_fusion_components gfc
        where gif.gene_oid = dtg.gene_oid
        and dtg.combo_oid = ?
        and gif.function = ?
        and g.gene_oid = gif.gene_oid
        and gfc.gene_oid = gif.gene_oid
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $combo_oid, $term_oid );
}

# gets number of genes with combination and different img term
sub getComboGeneCntOther {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select dtg2.combo_oid, count(distinct g.gene_oid)
        from gene_img_functions g, dt_func_combo_genes_4iterms dtg2
        where g.gene_oid = dtg2.gene_oid
        and g.function != ?
        and dtg2.combo_oid in 
            (select dtg.combo_oid
            from gene_img_functions gif, dt_func_combo_genes_4iterms dtg
            where gif.gene_oid = dtg.gene_oid
            and gif.function = ?)
        $rclause
        $imgClause
        group by dtg2.combo_oid
    };

    my @a = ( $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printComboGeneListOther {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    #my $name = getImgTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Term Combo Gene List<br/>
      with other IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif2.gene_oid, g.gene_display_name
        from gene_img_functions gif2, dt_func_combo_genes_4iterms dtg2, gene g
        where gif2.gene_oid = dtg2.gene_oid
        and dtg2.combo_oid = ?
        and gif2.function != ?
        and gif2.gene_oid = g.gene_oid
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $combo_oid, $term_oid );
}

sub printComboGeneListOther2 {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    #my $name = getImgTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Term Combo Gene List<br/>
      with other IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gif2.gene_oid, g.gene_display_name
        from gene_img_functions gif2, dt_func_combo_genes_4iterms dtg2, gene g
        where gif2.gene_oid = dtg2.gene_oid
        and dtg2.combo_oid = ?
        and gif2.function != ?
        and gif2.gene_oid = g.gene_oid
        $rclause
        $imgClause
        minus
        select gif3.gene_oid, g3.gene_display_name
        from gene_img_functions gif3, dt_func_combo_genes_4iterms dtg3, gene g3
        where gif3.gene_oid = dtg3.gene_oid
        and dtg3.combo_oid = ? 
        and gif3.function = ?
        and gif3.gene_oid = g3.gene_oid
    };

    printGeneListSectionSorting( $sql, "", "", $combo_oid, $term_oid, $combo_oid, $term_oid );
}

# gets number of genes with combination and different img term
# ignore genes already counted in "in"
sub getComboGeneCntOther2 {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select  dtg2.combo_oid, count(distinct a.gene_oid)
        from (
            select gif2.gene_oid as gene_oid
            from gene_img_functions gif2
            where gif2.function != ?
            minus
            select gif3.gene_oid
            from gene_img_functions gif3
            where gif3.function = ?
        ) a, 
        dt_func_combo_genes_4iterms dtg2, gene g
        where a.gene_oid = dtg2.gene_oid
        and g.gene_oid = a.gene_oid
        and dtg2.combo_oid in 
        ( select dtg.combo_oid
          from gene_img_functions gif, dt_func_combo_genes_4iterms dtg
          where gif.gene_oid = dtg.gene_oid
          and gif.function = ?
        )
        $rclause
        $imgClause
        group by dtg2.combo_oid
    };

    my @a = ( $term_oid, $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# get combo total gene count for all given terms combos
sub getComboTotalGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select dtg2.combo_oid, count(dtg2.gene_oid)
        from dt_func_combo_genes_4iterms dtg2, gene g
        where g.gene_oid = dtg2.gene_oid
        and dtg2.combo_oid in 
        (select dtg.combo_oid
        from gene_img_functions gif, dt_func_combo_genes_4iterms dtg
        where gif.gene_oid = dtg.gene_oid
        and gif.function = ?)
        $rclause
        $imgClause
        group by dtg2.combo_oid
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub getComboGeneCntNoTerm {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select dtg4.combo_oid, count(distinct dtg4.gene_oid)
        from dt_func_combo_genes_4iterms dtg4, gene g
        where g.gene_oid = dtg4.gene_oid
        and dtg4.gene_oid in (
            select dtg.gene_oid
            from dt_func_combo_genes_4iterms dtg
            where dtg.combo_oid in(
                select dtg3.combo_oid
                from gene_img_functions gif3, dt_func_combo_genes_4iterms dtg3
                where gif3.gene_oid = dtg3.gene_oid
                and gif3.function = ?)
            minus        
            select gif2.gene_oid
            from gene_img_functions gif2, dt_func_combo_genes_4iterms dtg2
            where gif2.gene_oid = dtg2.gene_oid
            and dtg2.combo_oid in(
                select dtg3.combo_oid
                from gene_img_functions gif3, dt_func_combo_genes_4iterms dtg3
                where gif3.gene_oid = dtg3.gene_oid
                and gif3.function = ?)
        )
        $rclause
        $imgClause
        group by dtg4.combo_oid
    };

    my @a = ( $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printComboGeneListNoTerm {
    my $term_oid  = param("term_oid");
    my $combo_oid = param("combo_oid");

    my $dbh = dbLogin();

    #$term_oid  =~ s/'/''/g;
    #$combo_oid =~ s/'/''/g;

    #my $name = getImgTermName( $dbh, $term_oid );

    #$dbh->disconnect();

    print qq{
      <h1>
      Combination Gene List<br/>
      with No IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct g.gene_oid, g.gene_display_name
        from dt_func_combo_genes_4iterms dtg, gene g
        where dtg.gene_oid = g.gene_oid
        and dtg.combo_oid = ?
        $rclause
        $imgClause
        minus
        select gif2.gene_oid, g2.gene_display_name
        from gene_img_functions gif2, dt_func_combo_genes_4iterms dtg2, gene g2
        where gif2.gene_oid = dtg2.gene_oid
        and dtg2.combo_oid = ? 
        and gif2.gene_oid = g2.gene_oid
    };

    printGeneListSectionSorting( $sql, "", "", $combo_oid, $combo_oid );
}

sub getComboDetailFusionCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select dtg.combo_oid, count(distinct gif.gene_oid)
        from gene_img_functions gif, dt_func_combo_genes_4iterms dtg, gene_fusion_components g
        where gif.gene_oid = dtg.gene_oid
        and gif.function = ?
        and g.gene_oid = gif.gene_oid
        $rclause
        $imgClause
        group by dtg.combo_oid
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $combo_oid, $cnt ) = $cur->fetchrow();
        last if !$combo_oid;
        $hash{$combo_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# print comdo detail table
sub printComboDetail {
    my $term_oid = param("term_oid");
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $name = getImgTermName( $dbh, $term_oid );
    print qq{
      <h1> IMG Term Combination Detail<br/>
      $name
      </h1>  
    };

    printStartWorkingDiv();
    print "Getting combos.<br/>\n";

    # (\@res, \%distinct_cog, \%distinct_pfam, \%distinct_tigrfam);
    my ( $terms_aref, $distinct_cog_href, $distinct_pfam_href, $distinct_tigrfam_href, $distinct_ko_href ) =
      getCombo( $dbh, $term_oid );

    print "Getting function names.<br/>\n";

    # cog
    my $cog_name_href = QueryUtil::getCogNames( $dbh, $distinct_cog_href );

    # pfam
    my $pfam_name_href = QueryUtil::getPfamNames( $dbh, $distinct_pfam_href );

    # tigrfam
    my $tigrfam_name_href = QueryUtil::getTigrfamNames( $dbh, $distinct_tigrfam_href );

    # ko
    my $ko_name_href = QueryUtil::getKoDefinitions( $dbh, $distinct_ko_href );

    print "Getting combos counts.<br/>\n";
    my $gene_cnt_href = getComboGeneCnt( $dbh, $term_oid );
    print "Getting combos other gene counts.<br/>\n";
    my $other_gene_cnt_href = getComboGeneCntOther( $dbh, $term_oid );

    print "Getting combos other gene counts ignore in genes.<br/>\n";
    my $other_gene_cnt_href2 = getComboGeneCntOther2( $dbh, $term_oid );

    #print "Getting combos total gene counts.<br/>\n";
    #my $total_gene_cnt_href = getComboTotalGeneCnt( $dbh, $term_oid );
    print "Getting combos gene counts with no img terms.<br/>\n";
    my $noterm_gene_cnt_href = getComboGeneCntNoTerm( $dbh, $term_oid );

    print "Getting fusion count.<br/>\n";
    my $fusion_cnt_href = getComboDetailFusionCnt( $dbh, $term_oid );
    printEndWorkingDiv();

    # get filters
    my @filter_cog = param("cog");
    my %filter_cog_h;
    my @filter_pfam = param("pfam");
    my %filter_pfam_h;
    my @filter_tigrfam = param("tigrfam");
    my %filter_tigrfam_h;
    my @filter_ko = param("ko");
    my %filter_ko_h;

    foreach my $id (@filter_cog) {
        $filter_cog_h{$id} = 1;
    }
    foreach my $id (@filter_pfam) {
        $filter_pfam_h{$id} = 1;
    }
    foreach my $id (@filter_tigrfam) {
        $filter_tigrfam_h{$id} = 1;
    }
    foreach my $id (@filter_ko) {
        $filter_ko_h{$id} = 1;
    }
    print "<h2>Protein List</h2>\n";
    printMainForm();

    print <<EOF;
    <script language="javascript" type="text/javascript">

function checkBoxes(name, x ) {
   var f = document.mainForm;
   for( var i = 0; i < f.length; i++ ) {
        var e = f.elements[ i ];

        if( e.name == name && e.type == "checkbox" ) {
           e.checked = ( x == 0 ? false : true );
        }
   }
}
    </script>
    
EOF

    # section=ImgTermStats&page=combodetail&term_oid=5777
    print hiddenVar( "page",     "combodetail" );
    print hiddenVar( "section",  "ImgTermStats" );
    print hiddenVar( "term_oid", $term_oid );

    print "<p>\n";
    my $linebreak = 5;
    my $itemcnt   = 0;
    if ( keys %$distinct_cog_href > 0 ) {
        my $cnt = keys %$distinct_cog_href;
        print "<b>COG ($cnt) </b>\n";
        print nbsp(1);
        print "<input type='button' name='selectAll' value='Select All'  "
          . "onClick=\"checkBoxes('cog',1)\" class='tinybutton' />\n";
        print nbsp(1);
        print "<input type='button' name='clearAll' value='Clear All'  "
          . "onClick=\"checkBoxes('cog',0)\" class='tinybutton' />\n";
        print "<br/>\n";
        foreach my $id ( sort keys %$distinct_cog_href ) {
            my $title = "title='" . $cog_name_href->{$id} . "'";
            my $url   = "$cog_base_url$id";
            $url = "<a href='$url' $title> $id </a>";
            if ( $itemcnt >= $linebreak ) {
                print "<br/>\n";
                $itemcnt = 0;
            }

            my $ck = "checked" if ( exists $filter_cog_h{$id} );
            print "<input type='checkbox' name='cog' " . "value='$id' $ck $title/> &nbsp; $url &nbsp;&nbsp;\n";
            $itemcnt++;
        }
        print "<br/>";
    }
    $itemcnt = 0;
    if ( keys %$distinct_pfam_href > 0 ) {
        my $cnt = keys %$distinct_pfam_href;
        print "<br/><b>Pfam ($cnt) </b>\n";
        print nbsp(1);
        print "<input type='button' name='selectAll' value='Select All'  "
          . "onClick=\"checkBoxes('pfam',1)\" class='tinybutton' />\n";
        print nbsp(1);
        print "<input type='button' name='clearAll' value='Clear All'  "
          . "onClick=\"checkBoxes('pfam',0)\" class='tinybutton' />\n";
        print "<br/>\n";
        foreach my $id ( sort keys %$distinct_pfam_href ) {
            my $title = "title='" . $pfam_name_href->{$id} . "'";
            my $id2   = $id;
            $id2 =~ s/pfam/PF/;
            my $url = "$pfam_base_url$id2";
            $url = "<a href='$url' $title> $id </a>";
            if ( $itemcnt >= $linebreak ) {
                print "<br/>\n";
                $itemcnt = 0;
            }

            my $ck = "checked" if ( exists $filter_pfam_h{$id} );
            print "<input type='checkbox' name='pfam' " . "value='$id' $ck $title/> &nbsp; $url &nbsp;&nbsp;\n";
            $itemcnt++;
        }
        print "<br/>";
    }
    $itemcnt = 0;
    if ( keys %$distinct_tigrfam_href > 0 ) {
        my $cnt = keys %$distinct_tigrfam_href;
        print "<br/><b>TIGRfam ($cnt) </b>\n";
        print nbsp(1);
        print "<input type='button' name='selectAll' value='Select All'  "
          . "onClick=\"checkBoxes('tigrfam',1)\" class='tinybutton' />\n";
        print nbsp(1);
        print "<input type='button' name='clearAll' value='Clear All'  "
          . "onClick=\"checkBoxes('tigrfam',0)\" class='tinybutton' />\n";
        print "<br/>\n";
        foreach my $id ( sort keys %$distinct_tigrfam_href ) {
            my $title = "title='" . $tigrfam_name_href->{$id} . "'";
            my $url   = "$tigrfam_base_url$id";
            $url = "<a href='$url' $title> $id </a>";
            if ( $itemcnt >= $linebreak ) {
                print "<br/>\n";
                $itemcnt = 0;
            }

            my $ck = "checked" if ( exists $filter_tigrfam_h{$id} );
            print "<input type='checkbox' name='tigrfam' " . "value='$id' $ck $title/> &nbsp; $url &nbsp;&nbsp;\n";
            $itemcnt++;
        }
    }
    $itemcnt = 0;
    if ( keys %$distinct_ko_href > 0 ) {
        my $cnt = keys %$distinct_ko_href;
        print "<br/><b>KO Terms ($cnt) </b>\n";
        print nbsp(1);
        print "<input type='button' name='selectAll' value='Select All'  "
          . "onClick=\"checkBoxes('ko',1)\" class='tinybutton' />\n";
        print nbsp(1);
        print "<input type='button' name='clearAll' value='Clear All'  "
          . "onClick=\"checkBoxes('ko',0)\" class='tinybutton' />\n";
        print "<br/>\n";
        foreach my $id ( sort keys %$distinct_ko_href ) {
            my $title = "title='" . $ko_name_href->{$id} . "'";

            # TODO find url
            my $koid_short = $id;
            $koid_short =~ s/KO://;
            my $url = "$ko_base_url$koid_short";
            $url = "<a href='$url' $title> $id </a>";
            if ( $itemcnt >= $linebreak ) {
                print "<br/>\n";
                $itemcnt = 0;
            }

            my $ck = "checked" if ( exists $filter_ko_h{$id} );
            print "<input type='checkbox' name='ko' " . "value='$id' $ck $title/> &nbsp; $url &nbsp;&nbsp;\n";
            $itemcnt++;
        }
    }

    print "</p>\n";

    print submit(
                  -name  => "_section_ImgTermStats_combodetail",
                  -value => "Filter",
                  -class => "meddefbutton"
    );
    print end_form();

    my $it = new InnerTable( 1, "imgtermcombo$$", "imgtermcombo", 0 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Combo ID",                   "number asc",  "right" );
    $it->addColSpec( "COG IDs",                    "char asc",    "left" );
    $it->addColSpec( "Pfam IDs",                   "char asc",    "left" );
    $it->addColSpec( "TIGRfam IDs",                "char asc",    "left" );
    $it->addColSpec( "KO IDs",                     "char asc",    "left" );
    $it->addColSpec( "Num of Genes",               "number desc", "right" );
    $it->addColSpec( "Num of Fusion Genes",        "number desc", "right" );
    $it->addColSpec( "Num of Genes Other Term",    "number desc", "right" );
    $it->addColSpec( "Num of Genes Other Term **", "number desc", "right" );
    $it->addColSpec( "Num of Genes No Term",       "number desc", "right" );

    my $count = 0;
    foreach my $line (@$terms_aref) {
        my ( $combo_oid, $cog_ids, $pfam_ids, $tigrfam_ids, $ko_ids ) =
          split( /\t/, $line );

        if (    keys %filter_cog_h > 0
             || keys %filter_pfam_h > 0
             || keys %filter_tigrfam_h > 0
             || keys %filter_ko_h > 0 )
        {
            my $match_filter = 0;

            # check cog filter
            foreach my $id ( keys %filter_cog_h ) {
                if ( $cog_ids =~ $id ) {
                    $match_filter = 1;
                    my $hlight = "<font color='red'> $id </font>";
                    $cog_ids =~ s/$id/$hlight/;
                }
            }

            # check pfam filter
            foreach my $id ( keys %filter_pfam_h ) {
                if ( $pfam_ids =~ $id ) {
                    $match_filter = 1;
                    my $hlight = "<font color='red'> $id </font>";
                    $pfam_ids =~ s/$id/$hlight/;
                }
            }

            # check tigrfam
            foreach my $id ( keys %filter_tigrfam_h ) {
                if ( $tigrfam_ids =~ $id ) {
                    $match_filter = 1;
                    my $hlight = "<font color='red'> $id </font>";
                    $tigrfam_ids =~ s/$id/$hlight/;
                }
            }

            # check ko
            foreach my $id ( keys %filter_ko_h ) {
                if ( $ko_ids =~ $id ) {
                    $match_filter = 1;
                    my $hlight = "<font color='red'> $id </font>";
                    $ko_ids =~ s/$id/$hlight/;
                }
            }

            next if ( $match_filter == 0 );
        }

        my $gene_count       = $gene_cnt_href->{$combo_oid};
        my $other_gene_count = $other_gene_cnt_href->{$combo_oid};
        $other_gene_count = 0 if ( $other_gene_count eq "" );

        my $other_gene_count2 = $other_gene_cnt_href2->{$combo_oid};
        $other_gene_count2 = 0 if ( $other_gene_count2 eq "" );

        #my $total = $total_gene_cnt_href->{$combo_oid};
        #$total = 0 if ( $total eq "" );
        #my $total_no_term = $total - $gene_count - $other_gene_count;
        #$total_no_term = "$total - $gene_count - $other_gene_count"
        #  if ( $total_no_term < 0 );
        my $total_no_term = $noterm_gene_cnt_href->{$combo_oid};
        $total_no_term = 0 if ( $total_no_term eq "" );

        my $fusion_cnt = $fusion_cnt_href->{$combo_oid};
        $fusion_cnt = 0 if ( $fusion_cnt eq "" );

        my $r;
        $r .= $combo_oid . $sd . $combo_oid . "\t";
        $r .= $cog_ids . $sd . $cog_ids . "\t";
        $r .= $pfam_ids . $sd . $pfam_ids . "\t";
        $r .= $tigrfam_ids . $sd . $tigrfam_ids . "\t";
        $r .= $ko_ids . $sd . $ko_ids . "\t";

        #combogenelist
        if ( $gene_count > 0 ) {
            my $url = $section_cgi . "&page=combogenelist" . "&term_oid=$term_oid" . "&combo_oid=$combo_oid";
            $url = alink( $url, $gene_count );
            $r .= $gene_count . $sd . $url . "\t";
        } else {
            $r .= $gene_count . $sd . $gene_count . "\t";
        }

        # fusion count
        if ( $fusion_cnt > 0 ) {
            my $url = $section_cgi . "&page=combogenelistfusion" . "&term_oid=$term_oid" . "&combo_oid=$combo_oid";
            $url = alink( $url, $fusion_cnt );
            $r .= $fusion_cnt . $sd . $url . "\t";
        } else {
            $r .= $fusion_cnt . $sd . $fusion_cnt . "\t";
        }

        #combogenelistother
        if ( $other_gene_count > 0 ) {
            my $url = $section_cgi . "&page=combogenelistother" . "&term_oid=$term_oid" . "&combo_oid=$combo_oid";
            $url = alink( $url, $other_gene_count );
            $r .= $other_gene_count . $sd . $url . "\t";
        } else {
            $r .= $other_gene_count . $sd . $other_gene_count . "\t";
        }

        #combogenelistother2
        if ( $other_gene_count2 > 0 ) {
            my $url = $section_cgi . "&page=combogenelistother2" . "&term_oid=$term_oid" . "&combo_oid=$combo_oid";
            $url = alink( $url, $other_gene_count2 );
            $r .= $other_gene_count2 . $sd . $url . "\t";
        } else {
            $r .= $other_gene_count2 . $sd . $other_gene_count2 . "\t";
        }

        #combogenelistno
        if ( $total_no_term > 0 ) {
            my $url = $section_cgi . "&page=combogenelistno" . "&term_oid=$term_oid" . "&combo_oid=$combo_oid";
            $url = alink( $url, $total_no_term );
            $r .= $total_no_term . $sd . $url . "\t";
        } else {
            $r .= $total_no_term . $sd . $total_no_term . "\t";
        }

        $it->addRow($r);
        $count++;
    }

    $it->printOuterTable(1);
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

# KO section ---------------------------------------------

# gets all img terms ko gene count
# number of genes with this img term and ko term
sub getTermsKoGenes {
    my ($dbh)  = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.function, count(distinct g.gene_oid)
        from gene_img_functions g, gene_ko_terms gk
        where g.function is not null
        and g.gene_oid = gk.gene_oid
        and g.taxon = gk.taxon
        $rclause
        $imgClause
        group by g.function
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $term_oid, $cnt ) = $cur->fetchrow();
        last if !$term_oid;
        $hash{$term_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printTermKoGenes {
    my $term_oid = param("term_oid");

    my $dbh = dbLogin();

    #$term_oid =~ s/'/''/g;
    my $name = getImgTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Term KO Gene List<br/>
      $name
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene_img_functions gif, gene_ko_terms gk, gene g
        where gif.gene_oid = gk.gene_oid
        and gif.function = ?
        and gif.gene_oid = g.gene_oid
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid );
}

# gets terms gene count
# for use in calc (this - getTermsKoGenes)
#   number of genes with this img term and no ko term
sub getTermsGeneCnt {
    my ($dbh)  = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.function, count(distinct g.gene_oid)
        from gene_img_functions g
        where g.function is not null
        $rclause
        $imgClause
        group by g.function
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $term_oid, $cnt ) = $cur->fetchrow();
        last if !$term_oid;
        $hash{$term_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# img terms with no ko
sub printTermNoKoGenes {
    my $term_oid = param("term_oid");

    #my $dbh = dbLogin();
    #$term_oid =~ s/'/''/g;

    ##$dbh->disconnect();

    print qq{
      <h1>
      IMG Terms without KO Gene List
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.gene_oid, g.gene_display_name
        from gene g
        where 1 = 1
        $rclause 
        $imgClause
        and g.gene_oid in (
            select gif2.gene_oid
            from gene_img_functions gif2
            where gif2.function = ? 
            minus
            select gif.gene_oid
            from gene_img_functions gif, gene_ko_terms gk
            where gif.gene_oid = gk.gene_oid
            and gif.function = ?
        )
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid, $term_oid );
}

# gets terms ko count
sub getTermsKoCnt {
    my ($dbh)  = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select gif.function, count(distinct g.ko_terms)
        from gene_img_functions gif, gene_ko_terms g
        where gif.gene_oid = g.gene_oid
        and gif.function is not null
        $rclause
        $imgClause
        group by gif.function
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $term_oid, $cnt ) = $cur->fetchrow();
        last if !$term_oid;
        $hash{$term_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printKoTerms {
    my $term_oid = param("term_oid");
    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    #$term_oid =~ s/'/''/g;
    my $name = getImgTermName( $dbh, $term_oid );

    print qq{
      <h1>
      IMG Terms<br/>
      $name<br/>
      KO Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct g.ko_terms, k.ko_name, k.definition
        from gene_img_functions gif, gene_ko_terms g, ko_term k
        where gif.gene_oid = g.gene_oid
        and gif.function = ?
        and g.ko_terms = k.ko_id
        $rclause
        $imgClause
    };
    my $count = 0;
    my $it    = new InnerTable( 1, "imgtermkoterm$$", "imgtermkoterm", 0 );
    my $sd    = $it->getSdDelim();                                            # sort delimiter
    $it->addColSpec( "KO Term ID", "char asc", "left" );
    $it->addColSpec( "Name",       "char asc", "left" );
    $it->addColSpec( "Definition", "char asc", "left" );

    my $cur = execSql( $dbh, $sql, $verbose, $term_oid );
    for ( ; ; ) {
        my ( $ko_oid, $name, $defn ) = $cur->fetchrow();
        last if !$ko_oid;
        $count++;
        my $r;
        $r .= $ko_oid . $sd . $ko_oid . "\t";
        $r .= $name . $sd . $name . "\t";
        $r .= $defn . $sd . $defn . "\t";
        $it->addRow($r);

    }
    $cur->finish();

    $it->printOuterTable(1);
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
}

# prints ko term table
# add gene list links
sub printKoTable {
    print qq{
      <h1>IMG Term KO </h1>  
    };

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printStartWorkingDiv();
    print "Getting terms.<br/>\n";
    my $terms_href = getImgTerms($dbh);
    print "Getting terms ko gene count.<br/>\n";
    my $term_ko_href = getTermsKoGenes($dbh);
    print "Getting terms gene count.<br/>\n";
    my $terms_gene_cnt = getTermsGeneCnt($dbh);
    print "Getting terms ko count.<br/>\n";
    my $terms_ko_cnt = getTermsKoCnt($dbh);

    print "Getting paralog.<br/>\n";
    my $geneParalog_href = getImgTermsGeneParalog($dbh);

    my $bbhcnt_href;
    if ($include_img_term_bbh) {
        print "Getting bbh counts.<br/>\n";
        $bbhcnt_href = getTermsBbhCount($dbh);
    }
    printEndWorkingDiv();

    printMainForm();
    WebUtil::printFuncCartFooterForEditor();

    my $count = 0;
    my $it    = new InnerTable( 1, "imgtermko$$", "imgtermko", 1 );
    my $sd    = $it->getSdDelim();                                    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "IMG Term ID",             "number asc",  "right" );
    $it->addColSpec( "Name",                    "char asc",    "left" );
    $it->addColSpec( "Num of Genes with KO",    "number desc", "right" );
    $it->addColSpec( "Num of Genes without KO", "number desc", "right" );
    $it->addColSpec( "Num of KO terms",         "number desc", "right" );
    my $title = "Num of genes with term in paralog cluster";
    $it->addColSpec( "Num of Genes in Paralog", "number desc", "right", "", "title='$title'" );

    # TODO bbh on ko
    if ($include_img_term_bbh) {
        $it->addColSpec( "IMG Ortholog Cluster Count", "number desc", "right" );
    }

    foreach my $term_oid ( keys %$terms_href ) {
        my $term        = $terms_href->{$term_oid};
        my $ko_gene_cnt = $term_ko_href->{$term_oid};
        $ko_gene_cnt = 0 if ( $ko_gene_cnt eq "" );
        my $no_ko_cnt = $terms_gene_cnt->{$term_oid} - $ko_gene_cnt;
        my $ko_cnt    = $terms_ko_cnt->{$term_oid};
        $ko_cnt = 0 if ( $ko_cnt eq "" );

        my $para = $geneParalog_href->{$term_oid};
        $para = 0 if ( $para eq "" );

        my $bbh_cnt = 0;
        if ($include_img_term_bbh) {
            $bbh_cnt = $bbhcnt_href->{$term_oid};
            $bbh_cnt = 0 if ( $bbh_cnt eq "" );
        }

        $count++;
        my $r;

        my $padded_term_oid = FuncUtil::termOidPadded($term_oid);
        $r .= $sd . "<input type='checkbox' name='term_oid' " . "value='$padded_term_oid' />" . "\t";

        my $url = "$main_cgi?section=ImgTermBrowser&page=imgTermDetail";
        $url .= "&term_oid=$padded_term_oid";
        $r   .= $padded_term_oid . $sd . alink( $url, $padded_term_oid ) . "\t";

        my $url = $section_cgi . "&page=kodetail" . "&term_oid=$term_oid";
        $url = alink( $url, $term );
        $r .= $term . $sd . $url . "\t";

        # koimgtermgenelist
        if ( $ko_gene_cnt > 0 ) {
            my $url = $section_cgi . "&page=koimgtermgenelist" . "&term_oid=$term_oid";
            $url = alink( $url, $ko_gene_cnt );
            $r .= $ko_gene_cnt . $sd . $url . "\t";
        } else {
            $r .= $ko_gene_cnt . $sd . $ko_gene_cnt . "\t";
        }

        # nokoimgtermgenelist
        if ( $no_ko_cnt > 0 ) {
            my $url = $section_cgi . "&page=nokoimgtermgenelist" . "&term_oid=$term_oid";
            $url = alink( $url, $no_ko_cnt );
            $r .= $no_ko_cnt . $sd . $url . "\t";
        } else {
            $r .= $no_ko_cnt . $sd . $no_ko_cnt . "\t";
        }

        # kotermlist
        if ( $ko_cnt > 0 ) {
            my $url = $section_cgi . "&page=kotermlist" . "&term_oid=$term_oid";
            $url = alink( $url, $ko_cnt );
            $r .= $ko_cnt . $sd . $url . "\t";
        } else {
            $r .= $ko_cnt . $sd . $ko_cnt . "\t";
        }

        # paralog
        if ( $para > 0 ) {
            my $url = "$section_cgi&page=paraloggenelist&term_oid=$term_oid";
            $url = alink( $url, $para );
            $r .= $para . $sd . $url . "\t";
        } else {
            $r .= $para . $sd . $para . "\t";
        }

        # bbh
        if ($include_img_term_bbh) {
            if ( $bbh_cnt == 0 ) {
                $r .= $bbh_cnt . $sd . $bbh_cnt . "\t";
            } else {
                my $url = "$section_cgi&page=bbhdetail&term_oid=$term_oid";
                $url = alink( $url, $bbh_cnt );
                $r .= $bbh_cnt . $sd . $url . "\t";
            }
        }

        $it->addRow($r);
    }

    $it->printOuterTable(1);
    print end_form();
    #$dbh->disconnect();

    printStatusLine( "$count Loaded.", 2 );

}

# ko detail  ------------------

# gets all ko term of a given img term
sub getKoImgTerms {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct g.ko_terms , k.ko_name
        from gene_img_functions gif, gene_ko_terms g, ko_term k
        where gif.gene_oid = g.gene_oid
        and g.ko_terms = k.ko_id
        and gif.function = ?
        $rclause
        $imgClause
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $ko_oid, $name ) = $cur->fetchrow();
        last if !$ko_oid;
        $hash{$ko_oid} = $name;
    }
    $cur->finish();
    return \%hash;
}

sub getKoTerm {
    my ( $dbh, $ko_oid ) = @_;

    my $sql = qq{
  select ko_name
  from  ko_term
  where ko_id = ?
    };

    my @a      = ($ko_oid);
    my $cur    = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($term) = $cur->fetchrow();
    $cur->finish();
    return $term;
}

# number of genes with ko term and the sp\ecified img term
sub getKoImgTermGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.ko_terms, count(distinct g.gene_oid) 
        from gene_img_functions gif, gene_ko_terms g
        where gif.gene_oid = g.gene_oid
        and gif.function = ?
        $rclause
        $imgClause
        group by g.ko_terms
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $ko_oid, $cnt ) = $cur->fetchrow();
        last if !$ko_oid;
        $hash{$ko_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printTermKoGenes2 {
    my $term_oid = param("term_oid");
    my $ko_oid   = param("ko_oid");
    my $dbh      = dbLogin();

    #$term_oid =~ s/'/''/g;
    #$ko_oid   =~ s/'/''/g;
    my $name   = getImgTermName( $dbh, $term_oid );
    my $koname = getKoTerm( $dbh,      $ko_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      IMG Term KO Gene List<br/>
      $name<br/>
      $koname
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene_img_functions gif, gene_ko_terms gk, gene g
        where gif.gene_oid = gk.gene_oid
        and gif.function = ?
        and gif.gene_oid = g.gene_oid
        and gk.ko_terms = ?
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid, $ko_oid );
}

# number of genes with ko term and an img term different from the specified
sub getKoOtherImgTermGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.ko_terms, count(distinct g.gene_oid) 
        from gene_img_functions gif, gene_ko_terms g
        where gif.gene_oid = g.gene_oid
        $rclause
        $imgClause
        and gif.function != ?
        and g.ko_terms in (
          select gk2.ko_terms
          from gene_img_functions gif2, gene_ko_terms gk2
          where gif2.gene_oid = gk2.gene_oid
          and gif2.function = ?
        )
        group by g.ko_terms
    };

    my @a = ( $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $ko_oid, $cnt ) = $cur->fetchrow();
        last if !$ko_oid;
        $hash{$ko_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printKoOtherImgTermGene {
    my $term_oid = param("term_oid");
    my $ko_oid   = param("ko_oid");

    my $dbh = dbLogin();

    #$term_oid =~ s/'/''/g;
    #$ko_oid   =~ s/'/''/g;
    my $name = getImgTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      KO Gene List<br/>
      with Other IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gk.gene_oid, g.gene_display_name 
        from gene_img_functions gif, gene_ko_terms gk, gene g
        where gif.gene_oid = gk.gene_oid
        and g.gene_oid = gk.gene_oid
        and gif.function != ?
        and gk.ko_terms = ?
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid, $ko_oid );
}

sub printKoOtherImgTermGene2 {
    my $term_oid = param("term_oid");
    my $ko_oid   = param("ko_oid");

    my $dbh = dbLogin();

    #$term_oid =~ s/'/''/g;
    #$ko_oid   =~ s/'/''/g;
    my $name = getImgTermName( $dbh, $term_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      KO Gene List<br/>
      with Other IMG Terms
      </h1>  
    };
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct gk.gene_oid, g.gene_display_name 
        from gene_img_functions gif, gene_ko_terms gk, gene g
        where gif.gene_oid = gk.gene_oid
        and g.gene_oid = gk.gene_oid
        and gif.function != ?
        and gk.ko_terms = ?
        $rclause
        $imgClause
        minus
        select gk.gene_oid, g.gene_display_name 
        from gene_img_functions gif, gene_ko_terms gk, gene g
        where gif.gene_oid = gk.gene_oid
        and g.gene_oid = gk.gene_oid
        and gif.function = ?
        and gk.ko_terms = ?
    };

    printGeneListSectionSorting( $sql, "", "", $term_oid, $ko_oid, $term_oid, $ko_oid );
}

# number of genes with ko term and an img term different from the specified
# BUT ignore genes with mulitple terms
sub getKoOtherImgTermGeneCnt2 {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.ko_terms, count(distinct g.gene_oid) 
        from gene_img_functions gif, gene_ko_terms g
        where gif.gene_oid = g.gene_oid
        $rclause
        $imgClause
        and gif.function != ?
        and g.ko_terms in (
          select gk2.ko_terms
          from gene_img_functions gif2, gene_ko_terms gk2
          where gif2.gene_oid = gk2.gene_oid
          and gif2.function = ?
        )
        and g.gene_oid not in (
          select gk3.gene_oid
          from gene_img_functions gif3, gene_ko_terms gk3
          where gif3.gene_oid = gk3.gene_oid
          and gif3.function = ?
        )
        group by g.ko_terms
    };

    my @a = ( $term_oid, $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $ko_oid, $cnt ) = $cur->fetchrow();
        last if !$ko_oid;
        $hash{$ko_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

# get total gene count for ko term, list of ko term determine by the
# given img term
sub getKoTermTotalGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select g.ko_terms, count(distinct g.gene_oid) 
        from gene_ko_terms g
        where 1 = 1
        and g.ko_terms in (
          select gk2.ko_terms
          from gene_img_functions gif2, gene_ko_terms gk2
          where gif2.gene_oid = gk2.gene_oid
          and gif2.function = ?
        )
        $rclause
        $imgClause
        group by g.ko_terms
    };

    my @a = ($term_oid);
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $ko_oid, $cnt ) = $cur->fetchrow();
        last if !$ko_oid;
        $hash{$ko_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub getKoNoTermGeneCnt {
    my ( $dbh, $term_oid ) = @_;
    my $rclause1   = WebUtil::urClause('gk2.taxon');
    my $imgClause1 = WebUtil::imgClauseNoTaxon('gk2.taxon');
    my $rclause2   = WebUtil::urClause('gk.taxon');
    my $imgClause2 = WebUtil::imgClauseNoTaxon('gk.taxon');
    my $sql    = qq{
        select a.ko_terms, count(distinct a.gene_oid)
        from (
        select gk2.ko_terms, gk2.gene_oid
        from gene_ko_terms gk2
        where gk2.ko_terms in(
          select gk3.ko_terms
          from gene_img_functions gif3, gene_ko_terms gk3
          where gif3.gene_oid = gk3.gene_oid
          and gif3.function = ?
          $rclause1
          $imgClause1
        )
        minus
        select gk.ko_terms, gk.gene_oid
        from gene_img_functions gif, gene_ko_terms gk
        where gif.gene_oid = gk.gene_oid
        $rclause2
        $imgClause2
        and gk.ko_terms in(
          select gk3.ko_terms
          from gene_img_functions gif3, gene_ko_terms gk3
          where gif3.gene_oid = gk3.gene_oid
          and gif3.function = ?
        )) a
        where 1 = 1
        group by a.ko_terms
    };

    my @a = ( $term_oid, $term_oid );
    my %hash;
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $ko_oid, $cnt ) = $cur->fetchrow();
        last if !$ko_oid;
        $hash{$ko_oid} = $cnt;
    }
    $cur->finish();
    return \%hash;
}

sub printKoNoImgTermGeneList {
    my $term_oid = param("term_oid");
    my $ko_oid   = param("ko_oid");
    my $dbh      = dbLogin();

    #$term_oid =~ s/'/''/g;
    #$ko_oid   =~ s/'/''/g;

    #my $name = getImgTermName( $dbh, $term_oid );
    my $koname = getKoTerm( $dbh, $ko_oid );
    #$dbh->disconnect();

    print qq{
      <h1>
      KO Gene List<br/>
      without IMG Terms
      </h1>  
    };

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql    = qq{
        select distinct g.gene_oid, g.gene_display_name
        from gene g
        where g.gene_oid in(
            select gk2.gene_oid
            from gene_ko_terms gk2
            where gk2.ko_terms = ?
            minus
            select gk.gene_oid
            from gene_img_functions gif, gene_ko_terms gk
            where gif.gene_oid = gk.gene_oid
            and gk.ko_terms = ?
        )
        $rclause
        $imgClause
    };

    printGeneListSectionSorting( $sql, "", "", $ko_oid, $ko_oid );
}

sub printKoDetail {
    my $term_oid = param("term_oid");

    printStatusLine( "Loading ...", 1 );
    my $dbh  = dbLogin();
    my $term = getImgTermName( $dbh, $term_oid );

    print qq{
      <h1> IMG Term KO Detail<br/>$term</h1>  
    };

    printStartWorkingDiv();
    print "Getting KO with IMG terms.<br/>\n";
    my $ko_href = getKoImgTerms( $dbh, $term_oid );
    print "Getting KO with IMG terms gene count.<br/>\n";
    my $ko_gene_cnt_href = getKoImgTermGeneCnt( $dbh, $term_oid );
    print "Getting KO with other IMG terms gene count.<br/>\n";
    my $other_href = getKoOtherImgTermGeneCnt( $dbh, $term_oid );
    print "Getting KO with other IMG terms gene count, ignore genes.<br/>\n";
    my $other_href2 = getKoOtherImgTermGeneCnt2( $dbh, $term_oid );
    print "Getting KO total gene count.<br/>\n";
    my $total_gene_cnt_href = getKoNoTermGeneCnt( $dbh, $term_oid );

    #getKoTermTotalGeneCnt( $dbh, $term_oid );

    printEndWorkingDiv();

    my $count      = 0;
    my $count_gene = 0;
    my $it         = new InnerTable( 1, "imgtermkodetail$$", "imgtermkodetail", 0 );
    my $sd         = $it->getSdDelim();                                                # sort delimiter
    $it->addColSpec( "KO ID",                                       "char asc",    "left" );
    $it->addColSpec( "KO Name",                                     "char asc",    "left" );
    $it->addColSpec( "Num of Genes with KO with IMG Term",          "number desc", "right" );
    $it->addColSpec( "Num of Genes with KO with other IMG Term",    "number desc", "right" );
    $it->addColSpec( "Num of Genes with KO with other IMG Term**",  "number desc", "right" );
    $it->addColSpec( "Num of Genes with KO terms without IMG Term", "number desc", "right" );

    foreach my $ko_oid ( keys %$ko_href ) {
        my $ko_name  = $ko_href->{$ko_oid};
        my $gene_cnt = $ko_gene_cnt_href->{$ko_oid};
        $gene_cnt = 0 if ( $gene_cnt eq "" );
        my $other_cnt = $other_href->{$ko_oid};
        $other_cnt = 0 if ( $other_cnt eq "" );
        my $other_cnt2 = $other_href2->{$ko_oid};
        $other_cnt2 = 0 if ( $other_cnt2 eq "" );

        my $no_term_cnt = $total_gene_cnt_href->{$ko_oid};
        $no_term_cnt = 0 if ( $no_term_cnt eq "" );

        $count++;
        $count_gene += $gene_cnt;
        my $r;
        $r .= $ko_oid . $sd . $ko_oid . "\t";
        $r .= $ko_name . $sd . $ko_name . "\t";

        # koimgtermgenelist2
        if ( $gene_cnt > 0 ) {
            my $url = $section_cgi . "&page=koimgtermgenelist2" . "&term_oid=$term_oid" . "&ko_oid=$ko_oid";
            $url = alink( $url, $gene_cnt );
            $r .= $gene_cnt . $sd . $url . "\t";
        } else {
            $r .= $gene_cnt . $sd . $gene_cnt . "\t";
        }

        # kootherimgterm
        if ( $other_cnt > 0 ) {
            my $url = $section_cgi . "&page=kootherimgterm" . "&term_oid=$term_oid" . "&ko_oid=$ko_oid";
            $url = alink( $url, $other_cnt );
            $r .= $other_cnt . $sd . $url . "\t";
        } else {
            $r .= $other_cnt . $sd . $other_cnt . "\t";
        }

        if ( $other_cnt2 > 0 ) {
            my $url = $section_cgi . "&page=kootherimgterm2" . "&term_oid=$term_oid" . "&ko_oid=$ko_oid";
            $url = alink( $url, $other_cnt2 );
            $r .= $other_cnt2 . $sd . $url . "\t";
        } else {
            $r .= $other_cnt2 . $sd . $other_cnt2 . "\t";
        }

        #konoimgterm
        if ( $no_term_cnt > 0 ) {
            my $url = $section_cgi . "&page=konoimgterm" . "&term_oid=$term_oid" . "&ko_oid=$ko_oid";
            $url = alink( $url, $no_term_cnt );
            $r .= $no_term_cnt . $sd . $url . "\t";
        } else {
            $r .= $no_term_cnt . $sd . $no_term_cnt . "\t";
        }

        $it->addRow($r);
    }

    $it->printOuterTable(1);
    #$dbh->disconnect();

    print qq{
      <p>
      gene count: $count_gene
      </p>  
    };
    printStatusLine( "$count Loaded.", 2 );
}

sub printTermGenomeList {
    my $term_oid = param("term_oid");

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $name = getImgTermName( $dbh, $term_oid );

    print qq{
      <h1>
      IMG Term<br/>
      $name<br/>
      Genome List
      </h1>  
    };
    printMainForm();
    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');
    my $sql = qq{
        select distinct t.taxon_oid, t.taxon_display_name, t.domain, t.seq_status
        from gene_img_functions g, vw_taxon t
        where g.taxon = t.taxon_oid
        and g.function = ?
        $rclause
        $imgClause
    };

    my $count       = 0;
    my $txTableName = "imgtermgenome";                                          # name of current instance of taxon table
    my $it          = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd          = $it->getSdDelim();                                        # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Domain", "char asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "char asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome ID", "number asc", "right" );
    $it->addColSpec( "Genome Name",      "char asc",   "left" );

    my @a = ($term_oid);
    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $domain, $seq_status ) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;
        my $r;

        my $tmp = "<input type='checkbox' " . "name='taxon_filter_oid' value='$taxon_oid' checked />";
        $r .= $sd . $tmp . "\t";
        $tmp = substr( $domain, 0, 1 );
        $r .= $tmp . $sd . $tmp . "\t";
        $tmp = substr( $seq_status, 0, 1 );
        $r .= $tmp . $sd . $tmp . "\t";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail" . "&taxon_oid=$taxon_oid";
        $url = alink( $url, $taxon_oid );
        $r .= $taxon_oid . $sd . $url . "\t";
        $r .= $taxon_display_name . $sd . $taxon_display_name . "\t";

        $it->addRow($r);

    }
    $cur->finish();
    #$dbh->disconnect();

    print hiddenVar( "page",          "message" );
    print hiddenVar( "message",       "Genome selection saved and enabled." );
    print hiddenVar( "menuSelection", "Genomes" );

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "Click on column name to sort.<br/>\n";
    print "</p>\n";

    printTaxonButtons($txTableName);
    $it->printOuterTable(1);
    printTaxonButtons($txTableName);
    print end_form();
    printStatusLine( "$count Loaded.", 2 );
}

#
# prints gene list with sorting
#
sub printGeneListSectionSorting {
    my ( $sql, $title, $notitlehtmlesc, @binds ) = @_;

    #koimgtermgenelist
    my $page = param("page");

    printMainForm();
    if ( $title ne "" ) {
        print "<h1> \n";
        if ( defined $notitlehtmlesc ) {
            print $title . "\n";
        } else {
            print escHtml($title) . "\n";
        }
        print "</h1>\n";
    }
    printGeneCartFooter();
    printStatusLine( "Loading ...", 1 );
    print "<p>\n";

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, @binds );
    my @gene_oids;
    my $count = 0;
    if ( getSessionParam("maxGeneListResults") ne "" ) {
        $maxGeneListResults = getSessionParam("maxGeneListResults");
    }

    my $it = new InnerTable( 1, "sorttaxon$$", "sorttaxon", 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",    "number asc", "right" );
    $it->addColSpec( "Locus Tag",         "char asc",   "left" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Genome Name",       "char asc",   "left" );
    if ( $page eq "koimgtermgenelist" ) {
        $it->addColSpec( "KO ID", "char asc", "left" );
    }
    $it->addColSpec( "COG Count",     "number desc", "right" );
    $it->addColSpec( "Pfam Count",    "number desc", "right" );
    $it->addColSpec( "TIGRfam Count", "number desc", "right" );
    if ( $page ne "koimgtermgenelist" ) {
        $it->addColSpec( "KO Count", "number desc", "right" );
    }

    $it->addColSpec( "Fusion",          "char asc", "left" );
    $it->addColSpec( "IMG Term Status", "char asc", "left" );
    $it->addColSpec( "Username",        "char asc", "left" );

    for ( ; ; ) {
        my ( $gene_oid, @junk ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        if ( $count > $maxGeneListResults ) {
            last;
        }
        if ( scalar(@gene_oids) > $max_gene_batch ) {
            flushGeneBatchSortingLocal( $dbh, \@gene_oids, $it );
            @gene_oids = ();
        }
        push( @gene_oids, $gene_oid );
    }
    flushGeneBatchSortingLocal( $dbh, \@gene_oids, $it );

    $it->printOuterTable(1);
    if ( $count > $maxGeneListResults ) {
        print "<br/>\n";
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" ) . " to change \"Max. Gene List Results\" limit. )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count gene(s) retrieved.", 2 );
    }
    print "</p>\n";
    $cur->finish();
    #$dbh->disconnect();
    print end_form();

}

#
# a html table with sorting
#
sub flushGeneBatchSortingLocal {
    my ( $dbh, $gene_oids_ref, $it, $taxon_oid_ortholog, $showSeqLen ) = @_;
    my @gene_oids    = param("gene_oid");
    my %geneOids     = WebUtil::array2Hash(@gene_oids);
    my $gene_oid_str = join( ",", @$gene_oids_ref );
    return if blankStr($gene_oid_str);

    my $term_oid = param("term_oid");

    #koimgtermgenelist
    my $page = param("page");

    # ko
    my %gene_ko;
    if ( $page eq "koimgtermgenelist" ) {
        my $sql = qq{
        select gene_oid, ko_terms 
        from gene_ko_terms
        where gene_oid in ($gene_oid_str)
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $ko ) = $cur->fetchrow();
            last if !$gene_oid;
            if ( exists $gene_ko{$gene_oid} ) {
                $gene_ko{$gene_oid} = "$gene_ko{$gene_oid}\t$ko";
            } else {
                $gene_ko{$gene_oid} = "$ko";
            }
        }
        $cur->finish();
    }

    # cog count
    my %gene_cog;
    my $sql = qq{
       select gene_oid, count(*)
       from gene_cog_groups
       where gene_oid in ( $gene_oid_str )
       group by gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_cog{$gene_oid} = $cnt;
    }
    $cur->finish();

    # pfam count
    my %gene_pfam;
    my $sql = qq{
       select gene_oid, count(*)
       from gene_pfam_families
       where gene_oid in ( $gene_oid_str )
       group by gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_pfam{$gene_oid} = $cnt;
    }
    $cur->finish();

    # tigrfam count
    my %gene_tigrfam;
    my $sql = qq{
       select gene_oid, count(*)
       from gene_tigrfams
       where gene_oid in ( $gene_oid_str )
       group by gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $cnt ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_tigrfam{$gene_oid} = $cnt;
    }
    $cur->finish();

    # ko count
    my %gene_ko;
    if ( $page ne "koimgtermgenelist" ) {
        my $sql = qq{
       select gene_oid, count(*)
       from gene_ko_terms
       where gene_oid in ( $gene_oid_str )
       group by gene_oid
       };

        my $cur = execSql( $dbh, $sql, $verbose );
        for ( ; ; ) {
            my ( $gene_oid, $cnt ) = $cur->fetchrow();
            last if !$gene_oid;
            $gene_ko{$gene_oid} = $cnt;
        }
        $cur->finish();
    }

    # fusion gene list
    my %gene_fusion;
    my $sql = qq{
       select gfc.gene_oid
       from gene_fusion_components gfc
       where gfc.gene_oid in ( $gene_oid_str )
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($gene_oid) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_fusion{$gene_oid} = 1;
    }
    $cur->finish();

    # img term user and flag
    my %gene_img_term;
    my $sql = qq{
        select gif.gene_oid, gif.f_flag, c.username
        from gene_img_functions gif 
        left join contact c on gif.modified_by = c.contact_oid
        where gif.function = '$term_oid'
        and gif.gene_oid in ($gene_oid_str)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $gene_oid, $f_flag, $username ) = $cur->fetchrow();
        last if !$gene_oid;
        $gene_img_term{$gene_oid} = "$f_flag\t$username";
    }
    $cur->finish();

    my $rclause   = WebUtil::urClause('tx');
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{
       select g.gene_oid, g.gene_display_name, g.gene_symbol, g.locus_tag, g.locus_type, 
         tx.taxon_oid, tx.ncbi_taxon_id, 
         tx.taxon_display_name, tx.genus, tx.species, 
         g.aa_seq_length, tx.seq_status, scf.ext_accession, ss.seq_length
       from taxon tx, scaffold scf, scaffold_stats ss, gene g
       where g.taxon = tx.taxon_oid
       $rclause
       $imgClause
       and g.gene_oid in ( $gene_oid_str )
       and g.scaffold = scf.scaffold_oid
       and scf.scaffold_oid = ss.scaffold_oid
       
   };

    # order by tx.taxon_display_name, g.gene_oid
    my $cur = execSql( $dbh, $sql, $verbose );

    my @recs;
    for ( ; ; ) {
        my (
             $gene_oid,  $gene_display_name, $gene_symbol,        $locus_tag,     $locus_type,
             $taxon_oid, $ncbi_taxon_id,     $taxon_display_name, $genus,         $species,
             $aa_seq_length, $seq_status,    $ext_accession,      $seq_length
          )
          = $cur->fetchrow();
        last if !$gene_oid;
        my $rec = "$gene_oid\t";
        $rec .= "$gene_display_name\t";
        $rec .= "$gene_symbol\t";
        $rec .= "$locus_tag\t";
        $rec .= "$locus_type\t";
        $rec .= "$taxon_oid\t";
        $rec .= "$ncbi_taxon_id\t";
        $rec .= "$taxon_display_name\t";
        $rec .= "$genus\t";
        $rec .= "$species\t";
        $rec .= "$aa_seq_length\t";
        $rec .= "$seq_status\t";
        $rec .= "$ext_accession\t";
        $rec .= "$seq_length\t";
        push( @recs, $rec );
    }

    # now print soriing html
    my $sd = $it->getSdDelim();

    my %done;
    for my $r (@recs) {
        my (
             $gene_oid,  $gene_display_name, $gene_symbol,        $locus_tag,     $locus_type,
             $taxon_oid, $ncbi_taxon_id,     $taxon_display_name, $genus,         $species,
             $aa_seq_length, $seq_status,    $ext_accession,      $seq_length
          )
          = split( /\t/, $r );
        next if $done{$gene_oid} ne "";
        my $ck = "checked" if $geneOids{$gene_oid} ne "";

        my $r;
        $r .= $sd . "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\t";

        my $url = "$main_cgi?section=GeneDetail" . "&page=geneDetail&gene_oid=$gene_oid";
        $r .= $gene_oid . $sd . "<a href='" . $url . "'>  $gene_oid </a>" . "\t";

        $r .= $locus_tag . $sd . "$locus_tag\t";

        my $seqLen;
        $seqLen = " (${aa_seq_length}aa) "
          if $aa_seq_length ne "" && $showSeqLen;

        if ( $locus_type ne "CDS" ) {
            $gene_symbol =~ s/tRNA-//;
            $gene_display_name .= " ( $locus_type $gene_symbol ) ";
        }

        my $scfInfo;
        if ( $locus_type ne "CDS" ) {
            $scfInfo = " ($ext_accession: ${seq_length}bp)";
        }

        my $tmpname = " ${seqLen} $scfInfo";
        if ( $gene_display_name ne "" ) {
            $tmpname = $gene_display_name . $tmpname;
        }
        $r .= $tmpname . $sd . "\t";

        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=$taxon_oid";
        $url = alink( $url, "$taxon_display_name" );
        $r .= $taxon_display_name . $sd . $url . "\t";

        # ko
        if ( $page eq "koimgtermgenelist" ) {
            if ( exists $gene_ko{$gene_oid} ) {
                $r .= $gene_ko{$gene_oid} . $sd . $gene_ko{$gene_oid} . "\t";
            } else {
                $r .= "" . $sd . "" . "\t";
            }
        }

        # function counts
        if ( exists $gene_cog{$gene_oid} ) {
            $r .= $gene_cog{$gene_oid} . $sd . $gene_cog{$gene_oid} . "\t";
        } else {
            $r .= 0 . $sd . 0 . "\t";
        }
        if ( exists $gene_pfam{$gene_oid} ) {
            $r .= $gene_pfam{$gene_oid} . $sd . $gene_pfam{$gene_oid} . "\t";
        } else {
            $r .= 0 . $sd . 0 . "\t";
        }

        if ( exists $gene_tigrfam{$gene_oid} ) {
            $r .= $gene_tigrfam{$gene_oid} . $sd . $gene_tigrfam{$gene_oid} . "\t";
        } else {
            $r .= 0 . $sd . 0 . "\t";
        }

        if ( $page ne "koimgtermgenelist" ) {
            if ( exists $gene_ko{$gene_oid} ) {
                $r .= $gene_ko{$gene_oid} . $sd . $gene_ko{$gene_oid} . "\t";
            } else {
                $r .= 0 . $sd . 0 . "\t";
            }
        }

        if ( exists $gene_fusion{$gene_oid} ) {
            $r .= "Yes" . $sd . "Yes" . "\t";
        } else {
            $r .= "No" . $sd . "No" . "\t";
        }

        if ( exists $gene_img_term{$gene_oid} ) {
            my ( $f_flag, $username ) =
              split( /\t/, $gene_img_term{$gene_oid} );
            $r .= "$f_flag" . $sd . "$f_flag" . "\t";
            $r .= "$username" . $sd . "$username" . "\t";
        } else {
            $r .= "" . $sd . "" . "\t";
            $r .= "" . $sd . "" . "\t";
        }

        $it->addRow($r);

        $done{$gene_oid} = 1;
    }
    $cur->finish();

}

1;

