############################################################################
# KeggPathwayDetail.pm - Show detail page for kegg pathway.
#   --es 07/08/2005
# $Id: KeggPathwayDetail.pm 33963 2015-08-10 23:37:20Z jinghuahuang $
############################################################################
package KeggPathwayDetail;
my $section = "KeggPathwayDetail";

use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use ScaffoldPanel;
use Time::localtime;
use CachedTable;
use PhyloNode;
use PhyloTreeMgr;
use WebConfig;
use WebUtil;
use OracleUtil;
use HtmlUtil;
use GeneDetail;
use InnerTable;
use TaxonDetailUtil;
use PathwayMaps;
use MetaUtil;
use MetaGeneTable;
use MerFsUtil;
use WorkspaceUtil;
use QueryUtil;
use GenomeListJSON;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $cgi_url              = $env->{cgi_url};
my $base_dir             = $env->{base_dir};
my $img_internal         = $env->{img_internal};
my $show_myimg_login     = $env->{show_myimg_login};
my $tmp_dir              = $env->{tmp_dir};
my $max_gene_batch       = 100;
my $max_taxon_batch      = 20;
my $max_scaffold_batch   = 20;
my $user_restricted_site = $env->{user_restricted_site};
my $include_metagenomes  = $env->{include_metagenomes};
my $show_private         = $env->{show_private};
my $new_func_count       = $env->{new_func_count};

my $min_scaffold_length = 50000;
my $scaffold_page_size  = $min_scaffold_length * 3;

my $kegg_tree_file     = $env->{kegg_tree_file};
my $kegg_orthology_url = $env->{kegg_orthology_url};
my $kegg_module_url    = $env->{kegg_module_url};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $kegg_reaction_url  = $env->{kegg_reaction_url};
my $go_base_url        = $env->{go_base_url};
my $cog_base_url       = $env->{cog_base_url};

my $pubchem_base_url  = $env->{pubchem_base_url};
if ( ! $pubchem_base_url ) {
    $pubchem_base_url = "http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid=";
} 

my $preferences_url    = "$main_cgi?section=MyIMG&page=preferences";
my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

my $merfs_timeout_mins = $env->{merfs_timeout_mins};
if ( ! $merfs_timeout_mins ) { 
    $merfs_timeout_mins = 60; 
} 

my $nvl = WebUtil::getNvl();

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my ($numTaxon) = @_;
    timeout( 60 * $merfs_timeout_mins );

    my $page = param("page");

    if ( $page eq "keggPathwayDetail" ) {
        printKeggPathwayDetail($numTaxon);
    } elsif ( $page eq "keggModulePathway" ) {
        printKeggModulePathway();
    } elsif ( $page eq "kpdKeggPathwayDetailGenomes" ) {
        printKpdKeggPathwayDetailGenomes();
    } elsif ( $page eq "kpdPhyloDist" ) {
        printKpdPhyloDist();
    } elsif ( $page eq "kpdKeggPathwayDetailGenes" ) {
        printKpdKeggPathwayDetailGenes();
    } elsif ( $page eq "kpdSelectScaffolds" ) {
        printKpdSelectScaffolds();
    } elsif ( paramMatch("kpdViewScaffoldProfile") ne "" ) {
        printKpdScaffoldProfile();
    } elsif ( $page eq "kpdKeggScaffoldGenes" ) {
        printKpdKeggScaffoldGenes();
    } elsif ( $page eq "koterm" ) {
        printKOtermDetail($numTaxon);
    } elsif ( $page eq "koterm2" ) {
        printKoTermDetail2();
    } elsif ( $page eq "kogenelist" ) {
        printKoGeneList();
    } elsif ( $page eq "kogenomelist" ) {
        printKoGenomeList();
    } elsif ( $page eq "koterm2" ) {
        print "TODO - ko terms list ";
    } elsif ( $page eq "komodule" ) {
        printKOModuleDetail($numTaxon);
    } elsif ( $page eq "komodgenelist" ) {
        printKoModGeneList();
    #} elsif ( $page eq "komodgenomelist" ) {
    #    printKoModGenomeList();
    } elsif ( $page eq "cpdList" ) {
        printKeggCpdList();
    } elsif ( $page eq "compound" ) {
        printKeggCompound();
    } else {
        printKeggPathwayDetail($numTaxon);
    }
}

###############################################################################
# printKOModuleDetail
###############################################################################
sub printKOModuleDetail {
    my ($numTaxon) = @_;
    my $pathway_id = param("pathway_id");
    my $module_id  = param("module_id");

    print "<h1>KEGG Module Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my ( $pathway_name, $image_id );
    print "<p>\n";
    my $sql = qq{
	select pathway_name, image_id
	from kegg_pathway
	where pathway_oid = ? 
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_id );
    ( $pathway_name, $image_id ) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
	select module_id, module_name
	from kegg_module
	where module_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $module_id );
    my ( $id, $name ) = $cur->fetchrow();
    $cur->finish();

    print "<p>\n";
    print "KEGG Pathway: <i>" . escHtml($pathway_name) . "</i><br/>\n";
    my $url = $kegg_module_url . $id;
    $url = alink( $url, $name );
    print "KO Module: $url\n";
    print "</p>\n";

    # For separate tables in multiple tabs, set the form id to be the
    # InnerTable table name (3rd argument) followed by "_frm" :
    print start_form(
                      -id     => "ko_frm",
                      -name   => "mainForm",
                      -action => "$main_cgi"
    );

    use TabHTML;
    TabHTML::printTabAPILinks("pathwaymodTab");
    my @tabIndex = ( "#pathwmodtab1", "#pathwmodtab2", "#pathwmodtab3" );
    my @tabNames = ( "KO Terms in Pathway", "Save to My Workspace",
		     "View Map for Selected Genomes" );
    TabHTML::printTabDiv( "pathwaymodTab", \@tabIndex, \@tabNames );

    print "<div id='pathwmodtab1'>";

    if ($include_metagenomes) {
        printHint( "Click <font color='blue'>'view'</font> to see "
		 . "genome or gene list for each individual KO Term." );
        print "<br/>";
    }

#    $sql = qq{
#        select kt.ko_id, kt.ko_name, kt.definition
#        from kegg_pathway_modules kpm, ko_term kt, kegg_module_ko_terms kmk
#        where kpm.pathway_oid = ?
#        and kpm.modules = kmk.module_id
#        and kpm.modules = ?
#        and kmk.ko_terms = kt.ko_id
#    };
    
    $sql = qq{
select kmt.ko_terms, kt.ko_name, kt.definition
  from image_roi_ko_terms irk, image_roi iroi, 
  kegg_pathway pw, kegg_module_ko_terms kmt, ko_term kt
    where kmt.ko_terms = irk.ko_terms
  and irk.roi_id = iroi.roi_id
  and iroi.pathway = pw.pathway_oid
  and  kmt.ko_terms = kt.ko_id
  and pw.PATHWAY_OID = ?
  and kmt.module_id = ?        
    };
    
    my @a = ( $pathway_id, $module_id );
    $cur = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my %ko_h;
    for ( ; ; ) {
        my ( $k_id, $k_name, $k_defn ) = $cur->fetchrow();
        last if !$k_id;
        $ko_h{$k_id} = $k_name . "\t" . $k_defn;
    }
    $cur->finish();

    my $it = new InnerTable( 1, "ko$$", "ko", 1 );
    my $sd = $it->getSdDelim(); # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "KO ID",        "asc",  "right" );
    $it->addColSpec( "KO Name",      "asc",  "left" );
    $it->addColSpec( "Definition",   "asc",  "left" );
    $it->addColSpec( "Gene Count",   "desc", "right" );
    $it->addColSpec( "Genome Count", "desc", "right" );

    my $select_id_name = "func_id";

    printStartWorkingDiv();
    
    my $count = 0;
    for my $ko_id ( keys %ko_h ) {
        print "Retrieving $ko_id information from database ... <br/>\n";

        # takes too long
        #	$sql = qq{
        #               select count(distinct g.gene_oid), count(distinct g.taxon)
        #               from gene_ko_terms gkt, gene g
        #               where gkt.ko_terms = ?
        #               and gkt.gene_oid = g.gene_oid
        #               and g.locus_type = 'CDS'
        #               and g.obsolete_flag = 'No'
        #               };
        #	$cur = execSql( $dbh, $sql, $verbose, $ko_id );
        #        my ( $gene_cnt, $taxon_cnt ) = $cur->fetchrow();
        #	$cur->finish();

        my $gene_cnt  = "view";
        my $taxon_cnt = "view";
        $count++;

        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$ko_id' />\t";
        my $tmp = $ko_id;
        $tmp =~ s/KO://;
        my $url = $kegg_orthology_url . $tmp;
        $url = alink( $url, $ko_id );
        $r .= $ko_id . $sd . $url . "\t";

        my ( $name, $defn ) = split( /\t/, $ko_h{$ko_id} );
        $r .= $name . $sd . $name . "\t";
        $r .= $defn . $sd . $defn . "\t";
        my $url = $section_cgi . "&page=kogenelist"
	    . "&ko_id=$ko_id&pathway_id=$pathway_id&module_id=$module_id";
        $url = alink( $url, $gene_cnt );
        $r .= $gene_cnt . $sd . $url . "\t";
        my $url = $section_cgi . "&page=kogenomelist" 
	    . "&ko_id=$ko_id&pathway_id=$pathway_id&module_id=$module_id";
        $url = alink( $url, $taxon_cnt );
        $r .= $taxon_cnt . $sd . $url . "\t";

        $it->addRow($r);
    }

    printEndWorkingDiv();

    printFuncCartFooter() if $count > 10;
    $it->printOuterTable(1);
    printFuncCartFooter();
    print "</div>";    # end pathwmodtab1

    print "<div id='pathwmodtab2'>";
    if ($count > 0) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }
    print "</div>";    # end pathwmodtab2

    print "<div id='pathwmodtab3'>";
    printViewPathwayForm( $dbh, $pathway_id, $image_id, $numTaxon );
    print "</div>";    # end pathwmodtab3

    TabHTML::printTabDivEnd();
    print end_form();

    printStatusLine( "$count Loaded.", 2 );
    #$dbh->disconnect();
}

sub printKoModGeneList {
    my $ko_id      = param("ko_id");
    my $pathway_id = param("pathway_id");
    my $module_id  = param("module_id");

    print "<h1>KEGG Module Gene List</h1>\n";

    my $dbh = dbLogin();

    my $sql = qq{
      select ko_name, definition
      from ko_term
      where ko_id = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my ( $koname, $kodefn ) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
      select pathway_name
      from kegg_pathway
      where pathway_oid = ?
   };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_id );
    my ($pathway_name) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
	select module_name
	    from kegg_module
	    where module_id = ?
	};
    my $cur = execSql( $dbh, $sql, $verbose, $module_id );
    my ($module_name) = $cur->fetchrow();
    $cur->finish();

    #$dbh->disconnect();
    print "<p>\n";
    print "$koname $kodefn<br/>$module_name<br/>";
    print "KEGG Pathway <i>" . escHtml($pathway_name) . "</i>\n";
    print "</p>\n";

    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql = qq{
	select distinct g.gene_oid
	    from kegg_module km, kegg_pathway kp, kegg_pathway_modules kpm,
	    gene_ko_terms gk, gene g, ko_term kt, kegg_module_ko_terms kmk
	    where km.pathway = kp.pathway_oid
	    and kp.pathway_oid = ?
	    and kp.pathway_oid = kpm.pathway_oid
	    and kpm.modules = km.module_id
	    and km.module_id = kmk.module_id
	    and kmk.ko_terms = gk.ko_terms
	    and gk.gene_oid = g.gene_oid
	    and km.module_id = ?
	    and kt.ko_id = gk.ko_terms
	    and gk.ko_terms = ? 
	    $imgClause
	};

    TaxonDetailUtil::printGeneListSectionSorting( $sql, "", "", $pathway_id, $module_id, $ko_id );
}

###############################################################################
# printKoGeneList: list all genes with ko_id
###############################################################################
sub printKoGeneList {
    my $ko_id      = param("ko_id");
    my $pathway_id = param("pathway_id");
    my $taxon_oid  = param("taxon_oid");
    my $gtype      = param("gtype");
    if ( !$gtype ) {
        $gtype = 'isolate';
    }

    printMainForm();

    if ( $gtype eq 'metagenome' ) {
        print "<h1>KEGG Orthology (KO) Term Metagenome Genes</h1>\n";
    } else {
        print "<h1>KEGG Orthology (KO) Term Isolate Genes</h1>\n";
    }

    my $dbh = dbLogin();

    my $sql = qq{
        select ko_name, definition
        from ko_term
        where ko_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my ( $koname, $kodefn ) = $cur->fetchrow();
    $cur->finish();

    my $taxonClause1 = WebUtil::txsClause( "t.taxon_oid", $dbh );
    if ( $taxon_oid ne "" && isInt($taxon_oid) ) {
        $taxonClause1 = " and t.taxon_oid = ? ";
    }

    my $rclause1   = WebUtil::urClause("t.taxon_oid");
    my $imgClause1 = WebUtil::imgClauseNoTaxon("t.taxon_oid", 1);
    $imgClause1 = WebUtil::imgClauseNoTaxon("t.taxon_oid", 2)
        if ($gtype eq "metagenome");;

    my %taxon_info;
    my %mer_fs_taxons;
    my $sql1 = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file
        from taxon t
        where 1 = 1
        $taxonClause1
        $rclause1
        $imgClause1
    };

    if ($taxon_oid ne "" && isInt($taxon_oid)) {
        $cur = execSql( $dbh, $sql1, $verbose, $taxon_oid );
    } else {
        $cur = execSql( $dbh, $sql1, $verbose );
    }

    for ( ; ; ) {
        my ($taxon_oid, $taxon_name, $in_file) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxon_info{ $taxon_oid } = $taxon_name;
        if ( $in_file eq 'Yes' ) {
            $mer_fs_taxons{$taxon_oid} = 1;
        }
    }
    $cur->finish();

    my $pathway_name = WebUtil::keggPathwayName( $dbh, $pathway_id );
    print "<p>\n";
    #print "<p style='width: 650px;'>";
    print "KO Term: <i>$koname $kodefn</i><br/>";
    print "KEGG Pathway: <i>" . escHtml($pathway_name) . "</i>\n";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause1 ne "" && $taxon_oid eq "";
    print "<br/>Genome: " . $taxon_info{ $taxon_oid } if $taxon_oid ne "";
    print "</p>\n";

    printStartWorkingDiv();
    print "<p>Retrieving genome information from database ... \n";

    my $it = new InnerTable( 1, "genelist$$", "genelist", 1 );
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",           "asc", "right" );
    $it->addColSpec( "Locus Tag",         "asc", "left" );
    $it->addColSpec( "Gene Product Name", "asc", "left" );
    $it->addColSpec( "Genome",            "asc", "left" );
    my $sd = $it->getSdDelim();

    my $select_id_name = "gene_oid";

    my $taxonClause = WebUtil::txsClause("g.taxon", $dbh);
    if ( $taxon_oid ne "" && isInt($taxon_oid) ) {
        $taxonClause = " and g.taxon = ? ";
    }
    my $rclause   = WebUtil::urClause("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon", 1);
    $imgClause = WebUtil::imgClauseNoTaxon("g.taxon", 2)
        if ($gtype eq "metagenome");

    $sql = qq{
        select distinct g.gene_oid, g.locus_tag, g.gene_display_name, g.taxon
    	from gene_ko_terms gkt, gene g
    	where gkt.ko_terms = ?
        and gkt.gene_oid = g.gene_oid
        and g.locus_type = 'CDS'
        and g.obsolete_flag = 'No'
        $rclause
        $imgClause
        $taxonClause
    };

    if ( $taxon_oid ne "" && isInt($taxon_oid) ) {
        $cur = execSql( $dbh, $sql, $verbose, $ko_id, $taxon_oid );
    } else {
        $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    }

    my $gene_cnt = 0;
    my $trunc    = 0;
    for ( ; ; ) {
        my ( $gene_oid, $locus_tag, $name, $taxon_oid ) = $cur->fetchrow();
        last if !$gene_oid;
        next if !$taxon_info{$taxon_oid};

        my $taxon_name = $taxon_info{$taxon_oid};

        my $url1 = "$main_cgi?section=GeneDetail" 
	    . "&page=geneDetail&gene_oid=$gene_oid";
        my $url2 = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";

        my $row = $sd . "<input type='checkbox' " 
            . "name='$select_id_name' value='$gene_oid'/>\t";
        $row .= $gene_oid . $sd . alink( $url1, $gene_oid, "_blank" ) . "\t";
        $row .= $locus_tag . $sd . $locus_tag . "\t";
    	if ( ! $name ) {
    	    $name = 'hypothetical protein';
    	}
        $row .= $name . $sd . $name . "\t";
        $row .= $taxon_name . $sd
	    . alink( $url2, $taxon_name, "_blank" ) . "\t";
        $it->addRow($row);

        $gene_cnt++;
        if ( $gene_cnt >= $maxGeneListResults ) {
            $trunc = 1;
            last;
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    my $mer_fs_genes   = 0;
    my $skip_gene_name = 0;
    if ( !$trunc && scalar( keys %mer_fs_taxons ) > 0 
	 && $gtype eq "metagenome") {

	timeout( 60 * $merfs_timeout_mins );
        print "<p>Retrieving genome information from MER-FS ... <br/>\n";

        foreach my $taxon_oid ( keys %mer_fs_taxons ) {
            last if $trunc;

            print "Retrieving genes for $taxon_oid ... <br/>\n";
            if ( $ko_id =~ /^KO\:/ ) {
                # full ID
            } else {
                $ko_id = "KO:" . $ko_id;
            }

            my %genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, "", $ko_id );
            my $taxon_name = $taxon_info{ $taxon_oid };

            foreach my $gene_oid ( keys %genes ) {
                my $workspace_id = $genes{$gene_oid};
                my ( $tid2, $data_type, $gid2 ) = split( / /, $workspace_id );
                my $locus_tag = $gene_oid;
                my $name      = "";
                if ( !$skip_gene_name ) {
                    my ( $value, $source ) = MetaUtil::getGeneProdNameSource
			( $gene_oid, $taxon_oid, $data_type );
                    $name = $value;
		    if ( ! $name ) {
			$name = 'hypothetical protein';
		    }
                }
                my $url1 =
                    "$main_cgi?section=MetaGeneDetail"
                  . "&page=metaGeneDetail&taxon_oid=$taxon_oid"
                  . "&data_type=$data_type&gene_oid=$gene_oid";
                my $url2 = "$main_cgi?section=MetaDetail"
		         . "&page=metaDetail&taxon_oid=$taxon_oid";

                my $row = $sd . "<input type='checkbox' " 
		    . "name='gene_oid' value='$workspace_id'/>\t";
                $row .= $workspace_id . $sd . alink( $url1, $gene_oid, "_blank" ) . "\t";
                $row .= $locus_tag . $sd . $locus_tag . "\t";
                $row .= $name . $sd . $name . "\t";
                $row .= $taxon_name . $sd . alink( $url2, $taxon_name, "_blank" ) . "\t";
                $it->addRow($row);
                $mer_fs_genes = 1;

                $gene_cnt++;
                if ( $gene_cnt >= $maxGeneListResults ) {
                    $trunc = 1;
                    last;
                }
            }
        }
    }

    printEndWorkingDiv();

    if ($gene_cnt > 10) {
        WebUtil::printGeneCartFooter();
    }
    $it->printOuterTable(1);
    WebUtil::printGeneCartFooter();

    if ($gene_cnt > 0) {
        MetaGeneTable::printMetaGeneTableSelect();
        WorkspaceUtil::printSaveGeneToWorkspace($select_id_name);
    }

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" )
	    . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$gene_cnt gene(s) retrieved", 2 );
    }

    print end_form();
}

# anna: deprecated ?
sub printKoModGenomeList {
    my $ko_id      = param("ko_id");
    my $pathway_id = param("pathway_id");
    my $module_id  = param("module_id");

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>KEGG Module Genome List</h1>\n";

    my $dbh = dbLogin();

    my $sql = qq{
	select ko_name, definition
	    from ko_term
	    where ko_id = ?
	};
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my ( $koname, $kodefn ) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
	select pathway_name
	    from kegg_pathway
	    where pathway_oid = ?
	};
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_id );
    my ($pathway_name) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
	select module_name
	    from kegg_module
	    where module_id = ?
	};
    my $cur = execSql( $dbh, $sql, $verbose, $module_id );
    my ($module_name) = $cur->fetchrow();
    $cur->finish();

    print "<p>\n";
    print "$koname $kodefn<br/>$module_name<br/>";
    print "KEGG Pathway <i>" . escHtml($pathway_name) . "</i>\n";
    print "</p>\n";

    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql = qq{
	select distinct t.taxon_oid, t.taxon_display_name
	    from kegg_module km, kegg_pathway kp, kegg_pathway_modules kpm,
	    gene_ko_terms gk, gene g, ko_term kt, kegg_module_ko_terms kmk,
	    taxon t
	    where km.pathway = kp.pathway_oid
	    and kp.pathway_oid = '$pathway_id'
	    and kp.pathway_oid = kpm.pathway_oid
	    and kpm.modules = km.module_id
	    and km.module_id = kmk.module_id
	    and kmk.ko_terms = gk.ko_terms
	    and gk.gene_oid = g.gene_oid
	    and km.module_id = '$module_id'
	    and kt.ko_id = gk.ko_terms
	    and gk.ko_terms = '$ko_id'
	    and g.taxon = t.taxon_oid     
	    $imgClause
	};

    my $count = printGenomeList( $dbh, $sql );
    #$dbh->disconnect();
    
    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}

###############################################################################
# printKOGenomeList: list genomes with gene count for ko_id
###############################################################################
sub printKoGenomeList {
    my $ko_id       = param("ko_id");
    my $pathway_oid = param("pathway_id");
    my $gtype       = param("gtype");
    if ( !$gtype ) {
        $gtype = 'isolate';
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    if ( $gtype eq 'metagenome' ) {
	print "<h1>KEGG Orthology (KO) Term Metagenomes</h1>\n";
    } else {
	print "<h1>KEGG Orthology (KO) Term Isolate Genomes</h1>\n";
    }

    my $dbh = dbLogin();

    my $sql = qq{
	select ko_name, definition
	from ko_term
	where ko_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my ( $koname, $kodefn ) = $cur->fetchrow();
    $cur->finish();

    my $pathway_name = WebUtil::keggPathwayName( $dbh, $pathway_oid );
    print "<p>\n";
    print "KO Term: <i>$koname $kodefn</i><br/>";
    print "KEGG Pathway: <i>" . escHtml($pathway_name) . "</i>\n";
    print "</p>\n";

    my $taxonClause = WebUtil::txsClause("g.taxon_oid", $dbh);
    my $rclause   = WebUtil::urClause('g.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 1);
    $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 2)
        if ($gtype eq "metagenome");;

    my $sql = qq{
	select /*+ result_cache */ g.taxon_oid, g.gene_count
        from mv_taxon_ko_stat g
        where g.ko_term  = ?
        $rclause
        $imgClause
        $taxonClause
    };

    my $count = printGenomeList( $dbh, $sql, $gtype, $pathway_oid, $ko_id );
    #$dbh->disconnect();
    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}

sub printGenomeList {
    my ( $dbh, $sql, $gtype, $pathway_id, $ko_id ) = @_;

    printStartWorkingDiv();
    print "Retrieving genome information from database ... <br/>\n";

    my $taxonClause1 = WebUtil::txsClause( "t.taxon_oid", $dbh );
    my $rclause1   = WebUtil::urClause("t.taxon_oid");
    my $imgClause1 = WebUtil::imgClauseNoTaxon("t.taxon_oid", 1);
    $imgClause1 = WebUtil::imgClauseNoTaxon("t.taxon_oid", 2)
        if ($gtype eq "metagenome");;

    my %taxon_info;
    my $sql1 = qq{
        select t.taxon_oid, t.domain, t.seq_status, 
               t.taxon_display_name, t.in_file
        from taxon t
        where 1 = 1
        $taxonClause1
        $rclause1
        $imgClause1
    };
    my $cur = execSql( $dbh, $sql1, $verbose );
    for ( ; ; ) {
        my ($taxon_oid, $domain, $seq_status, $taxon_name, $in_file)
	    = $cur->fetchrow();
        last if !$taxon_oid;

        $taxon_info{$taxon_oid} = substr( $domain, 0, 1 ) . "\t"
            . substr( $seq_status, 0, 1 ) . "\t" . $taxon_name
	    . "\t" . $in_file;
    }
    $cur->finish();

    my $it = new InnerTable( 1, "genome$$", "genome", 0 );
    my $sd = $it->getSdDelim();  # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Domain", "asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $it->addColSpec( "Status", "asc", "center", "",
		     "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    $it->addColSpec( "Gene Count",  "asc", "right" );

    my $select_id_name = "taxon_filter_oid";
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my $count = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $gene_cnt ) = $cur->fetchrow();
        last if !$taxon_oid;
        next if (! $taxon_info{$taxon_oid} );
        $count++;

        my ( $domain, $seq_status, $taxon_display_name, $in_file ) 
	    = split( /\t/, $taxon_info{$taxon_oid} );
        
        my $r;
        $r .= $sd . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";

        my $url = "$main_cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$taxon_oid";
        if ( $in_file ) {
            $url = "$main_cgi?section=MetaDetail"
		 . "&page=metaDetail&taxon_oid=$taxon_oid";
        }
        $r .= $taxon_display_name . $sd 
	    . alink( $url, $taxon_display_name ) . "\t";

        if ($gene_cnt) {
	    my $g_url = "$section_cgi&page=kogenelist";
	    $g_url .= "&taxon_oid=$taxon_oid";
	    $g_url .= "&pathway_id=$pathway_id" if $pathway_id ne "";
	    $g_url .= "&ko_id=$ko_id&gtype=$gtype";
            $r .= $gene_cnt . $sd . alink( $g_url, $gene_cnt ) . "\t";
        } else {
            $r .= "0" . $sd . "0" . "\t";
        }
        $it->addRow($r);
    }
    $cur->finish();

    if ($include_metagenomes && $gtype eq "metagenome" && $ko_id ne "") {
        print "<p>Retriving metagenome gene counts ...<br/>\n";

        if ( $ko_id =~ /^KO\:/ ) {
            # full ID
        } else {
            $ko_id = "KO:" . $ko_id;
        }

	my $taxonClause = WebUtil::txsClause("g.taxon_oid", $dbh);
	my $rclause   = WebUtil::urClause("g.taxon_oid");
	my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 2);

        my %gene_func_count; 
        if ( $new_func_count ) { 
            my $sql3 = qq{
               select g.taxon_oid, g.gene_count
               from taxon_ko_count g
               where g.func_id = ?
               and g.gene_count > 0
               $rclause
               $imgClause
               $taxonClause
            };
            my $cur3 = execSql( $dbh, $sql3, $verbose, $ko_id ); 
            for (;;) { 
                my ( $tid3, $cnt3 ) = $cur3->fetchrow(); 
                last if ! $tid3; 
 
                if ( $gene_func_count{$tid3} ) { 
                    $gene_func_count{$tid3} += $cnt3; 
                } else { 
                    $gene_func_count{$tid3} = $cnt3;
                } 
            } 
            $cur3->finish(); 
        }

        foreach my $taxon_oid (keys %taxon_info) {
	    my ( $domain, $seq_status, $taxon_display_name, $in_file )
		= split( /\t/, $taxon_info{$taxon_oid} );
	    next if $in_file ne "Yes";
            print "Retriving gene information for $taxon_oid ...<br/>\n";

            my $gene_cnt = 0; 
            if ( $new_func_count ) { 
                $gene_cnt = $gene_func_count{$taxon_oid}; 
            } else { 
                $gene_cnt = MetaUtil::getTaxonOneFuncCnt( $taxon_oid, "", $ko_id ); 
            } 

            if ($gene_cnt) {
                $count++;

		my $r;
		$r .= $sd . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
		$r .= "$domain\t";
		$r .= "$seq_status\t";

		my $url = "$main_cgi?section=MetaDetail"
		        . "&page=metaDetail&taxon_oid=$taxon_oid";
		$r .= $taxon_display_name . $sd
		    . alink( $url, $taxon_display_name ) . "\t";


                if ($gene_cnt) {
		    my $g_url = "$section_cgi&page=kogenelist";
		    $g_url .= "&taxon_oid=$taxon_oid";
		    $g_url .= "&pathway_id=$pathway_id" if $pathway_id ne "";
		    $g_url .= "&ko_id=$ko_id&gtype=$gtype";
                    $r .= $gene_cnt . $sd . alink( $g_url, $gene_cnt ) . "\t";
                } else {
                    $r .= "0" . $sd . "0" . "\t";
                }
                $it->addRow($r);
            }
        }
    }

    printEndWorkingDiv();

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNote() . "<br/>\n";
    print "</p>\n";
    
    if ($count > 10) {
        WebUtil::printGenomeCartFooter();
    }
    $it->printOuterTable(1);
    WebUtil::printGenomeCartFooter();

    if ($count > 0) {
        WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
    }

    return $count;
}

###############################################################################
# printKOTermDetail
###############################################################################
sub printKOtermDetail {
    my ($numTaxon) = @_;
    my $kegg_id     = param("kegg_id");
    my $pathway_oid = param("pathway_id");
    if ( $pathway_oid eq "" ) {
        printKOtermDetailNoPath();
        return;
    }

    print "<h1>KEGG Pathway Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
    	select pathway_name, image_id
    	from kegg_pathway
    	where pathway_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    my ( $pathway_name, $image_id ) = $cur->fetchrow();
    $cur->finish();

    my $taxonClause = WebUtil::txsClause( "g.taxon_oid", $dbh );

    print "<p>\n";
    print "Details for Pathway: ";
    print "<i>".escHtml($pathway_name)."</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause ne "";
    print "</p>\n";

    ## get KEGG module names
    my %kegg_mod_h;
    $sql = "select module_id, module_name from kegg_module";
    $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
    	my ($mod_id, $mod_name) = $cur->fetchrow();
    	last if ! $mod_id;
    	$kegg_mod_h{$mod_id} = $mod_name;
    }
    $cur->finish();

    ## get all ko term and kegg module for this pathway
    my %allKO;
    my %ko_term_2_module_h;
    $sql = qq{
        select distinct k.ko_id, k.ko_name, k.definition, kmt.module_id
        from image_roi_ko_terms irk, image_roi iroi,
             kegg_module_ko_terms kmt, ko_term k
        where irk.roi_id = iroi.roi_id
        and iroi.pathway = ?
        and k.ko_id = irk.ko_terms
        and k.ko_id = kmt.ko_terms (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for (;;) {
    	my ( $ko_id, $ko_name, $ko_defn, $mod_id ) = $cur->fetchrow();
    	last if ! $ko_id;
    	$allKO{$ko_id} = "$ko_name\t$ko_defn";
    	if ( $ko_term_2_module_h{$ko_id} ) {
    	    $ko_term_2_module_h{$ko_id} .= "\t" . $mod_id;
    	}
    	else {
    	    $ko_term_2_module_h{$ko_id} = $mod_id;
    	}
    }
    $cur->finish();

    # For separate tables in multiple tabs, set the form id to be the
    # InnerTable table name (3rd argument) followed by "_frm" :
    print start_form(
          -id     => "ko_frm",
          -name   => "mainForm",
          -action => "$main_cgi"
    );

    use TabHTML;
    TabHTML::printTabAPILinks("pathwayTab");
    my @tabIndex = ( "#pathwtab1",
		     "#pathwtab2",
		     "#pathwtab3" );
    my @tabNames = ( "KO Terms in Pathway", 
		     "Save to My Workspace",
		     "View Map for Selected Genomes" );
    TabHTML::printTabDiv( "pathwayTab", \@tabIndex, \@tabNames );
    print "<div id='pathwtab1'>";

    print "<h2>KEGG Orthology (KO) Terms in Pathway</h2>\n";

    printStartWorkingDiv();

    ## get count from Oracle database
    print "<p>Retrieving counts from database ...\n";
    my %ko_gene_cnt;
    my %m_ko_gene_cnt;
    my %ko_genome_cnt;
    my %m_ko_genome_cnt;

    my $taxonClause = WebUtil::txsClause( "g.taxon_oid", $dbh );
    my $rClause = WebUtil::urClause( "g.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 1 );

    $sql = qq{
        select /*+ result_cache */ g.ko_term, 
               sum(g.gene_count),
               count(distinct g.taxon_oid)
        from image_roi ir, image_roi_ko_terms irk, mv_taxon_ko_stat g
        where ir.pathway = ?
        and ir.roi_id = irk.roi_id
        and irk.ko_terms = g.ko_term
        $taxonClause
        $rClause
        $imgClause
        group by g.ko_term
    };

    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for ( ; ; ) {
	my ($id, $gene_cnt, $taxon_cnt) = $cur->fetchrow();
        last if !$id;

	if ( $ko_gene_cnt{$id} ) {
	    $ko_gene_cnt{$id} += $gene_cnt;
	} else {
	    $ko_gene_cnt{$id} = $gene_cnt;
	}

	if ( $ko_genome_cnt{$id} ) {
	    $ko_genome_cnt{$id} += $taxon_cnt;
	} else {
	    $ko_genome_cnt{$id} = $taxon_cnt;
	}
    }
    $cur->finish();

    if ($include_metagenomes) {
    	print "<p>Counting metagenomes ...\n";

	my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 2);
	$sql = qq{
            select /*+ result_cache */ g.ko_term,
                   sum(g.gene_count),
                   count(distinct g.taxon_oid)
            from image_roi ir, image_roi_ko_terms irk, mv_taxon_ko_stat g
            where ir.pathway = ?
            and ir.roi_id = irk.roi_id
            and irk.ko_terms = g.ko_term
            $taxonClause
            $rClause
            $imgClause
            group by g.ko_term
        };

	my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
	for ( ; ; ) {
	    my ($id, $gene_cnt, $taxon_cnt) = $cur->fetchrow();
	    last if !$id;

	    if ( $m_ko_gene_cnt{$id} ) {
		$m_ko_gene_cnt{$id} += $gene_cnt;
	    } else {
		$m_ko_gene_cnt{$id} = $gene_cnt;
	    }

	    if ( $m_ko_genome_cnt{$id} ) {
		$m_ko_genome_cnt{$id} += $taxon_cnt;
	    } else {
		$m_ko_genome_cnt{$id} = $taxon_cnt;
	    }
	}
	$cur->finish();

    	if ( $new_func_count ) {
	    $sql = qq{
                select g.func_id, sum(g.gene_count),
                       count(distinct g.taxon_oid)
                from taxon_ko_count g
                where g.gene_count > 0
                $rClause
                $imgClause
                $taxonClause
                group by g.func_id
            };
	    my $cur = execSql( $dbh, $sql, $verbose );
	    for ( ; ; ) {
		my ($ko_id, $gene_cnt, $taxon_cnt) = $cur->fetchrow();
		last if !$ko_id;

		if ( $m_ko_gene_cnt{$ko_id} ) {
		    $m_ko_gene_cnt{$ko_id} += $gene_cnt;
		} else {
		    $m_ko_gene_cnt{$ko_id} = $gene_cnt;
		}

		if ( $m_ko_genome_cnt{$ko_id} ) {
		    $m_ko_genome_cnt{$ko_id} += $taxon_cnt;
		} else {
		    $m_ko_genome_cnt{$ko_id} = $taxon_cnt;
		}
    	    }
    	    $cur->finish();
            print "<br/>\n";
    	
    	} else {
	    my $taxonClause1 = WebUtil::txsClause("t.taxon_oid", $dbh);
            $sql = MerFsUtil::getTaxonsInFileSql($taxonClause1);
            $sql .= " and t.genome_type = 'metagenome' ";
            $cur = execSql( $dbh, $sql, $verbose );
            for ( ; ; ) {
                my ($t_oid) = $cur->fetchrow();
                last if !$t_oid;
		
                print ". "; 
                my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'ko' );
		
		foreach my $id ( keys %funcs ) {
		    my $gene_cnt = $funcs{$id};
		    if ( $m_ko_gene_cnt{$id} ) {
			$m_ko_gene_cnt{$id} += $gene_cnt;
		    } else {
			$m_ko_gene_cnt{$id} = $gene_cnt;
		    }

		    if ( $m_ko_genome_cnt{$id} ) {
			$m_ko_genome_cnt{$id} += 1;
		    } else {
			$m_ko_genome_cnt{$id} = 1;
		    }
		}
    	    } 
    	    $cur->finish();
    	    print "<br/>\n";
    	}
    }

    my $hasIsolates = scalar (keys %ko_genome_cnt) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_ko_genome_cnt) > 0 ? 1 : 0;

    my $it = new InnerTable( 1, "ko$$", "ko", 1 );
    my $sd = $it->getSdDelim(); # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "KO Term ID",     "asc",  "right" );
    $it->addColSpec( "KO Name",        "asc",  "left"  );
    $it->addColSpec( "Definition",     "asc",  "left"  );
    $it->addColSpec( "KO Module ID",   "asc",  "left"  );
    $it->addColSpec( "KO Module Name", "asc",  "left"  );
    if ($include_metagenomes) {
	$it->addColSpec( "Isolate<br/>Gene Count", "desc", "right" )
	    if $hasIsolates;
        $it->addColSpec( "Isolate<br/>Genome Count", "desc", "right" )
            if $hasIsolates;
	$it->addColSpec( "Metagenome<br/>Gene Count", "desc", "right" )
	    if $hasMetagenomes;
        $it->addColSpec( "Metagenome<br/>Count", "asc",  "right" )
            if $hasMetagenomes;
    } else {
	$it->addColSpec( "Gene Count", "desc", "right" )
	    if $hasIsolates;
        $it->addColSpec( "Genome<br/>Count", "desc", "right" )
            if $hasIsolates;
    }

    my $select_id_name = "func_id";
    my $count = 0;
    my %distinct_koid;
    foreach my $id ( sort keys %allKO ) {
	my $name = "";
	my $defn = "";

	if ( $allKO{$id} ) {
	    ($name, $defn) = split(/\t/, $allKO{$id});
	}
	else {
	    next;
	}

	$distinct_koid{$id} = 1;

	my @kegg_mods = split(/\t/, $ko_term_2_module_h{$id});
	if ( scalar(@kegg_mods) == 0 ) {
	    ## not linked to kegg module
	    my $r;
	    $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$id' />\t";
	    my $tmp = $id;
	    $tmp =~ s/KO://;
	    my $url = $kegg_orthology_url . $tmp;
	    $url = alink( $url, $id );
	    $r .= $id . $sd . $url . "\t";
	    $r .= $name . $sd . $name . "\t";
	    $r .= $defn . $sd . $defn . "\t";

	    $r .= "zzzzz" . $sd . "&nbsp;" . "\t";
	    $r .= "zzzzz" . $sd . "&nbsp;" . "\t";

	    # gene count
	    my $gene_cnt = $ko_gene_cnt{$id};
	    if ($hasIsolates) {
		if ($gene_cnt) {
		    my $url = "$section_cgi&page=kogenelist";
		    $url .= "&pathway_id=$pathway_oid";
		    $url .= "&ko_id=$id&gtype=isolate";
		    $url = alink( $url, $gene_cnt );
		    $r .= $gene_cnt . $sd . $url . "\t";
		} else {
		    $r .= "0" . $sd . "0" . "\t";
		}
	    }

	    # genome count
	    my $taxon_cnt = $ko_genome_cnt{$id};
	    if ($hasIsolates) {
		if ($taxon_cnt) {
		    my $url = "$section_cgi&page=kogenomelist";
		    $url .= "&pathway_id=$pathway_oid";
		    $url .= "&ko_id=$id&gtype=isolate";
		    $url = alink( $url, $taxon_cnt );
		    $r .= $taxon_cnt . $sd . $url . "\t";
		} else {
		    $r .= "0" . $sd . "0" . "\t";
		}
	    }

	    if ($include_metagenomes) {
                my $m_gene_cnt = $m_ko_gene_cnt{$id};
                if ($hasMetagenomes) {
                    if ($m_gene_cnt) {
                        my $m_url = "$section_cgi&page=kogenelist";
                        $m_url .= "&pathway_id=$pathway_oid";
                        $m_url .= "&ko_id=$id&gtype=metagenome";
                        $m_url = alink( $m_url, $m_gene_cnt );
                        $r .= $m_gene_cnt . $sd . $m_url . "\t";
                    } else {
                        $r .= "0" . $sd . "0" . "\t";
                    }
                }

		my $m_taxon_cnt = $m_ko_genome_cnt{$id};
		if ($hasMetagenomes) {
		    if ($m_taxon_cnt) {
			my $m_url = "$section_cgi&page=kogenomelist";
			$m_url .= "&pathway_id=$pathway_oid";
			$m_url .= "&ko_id=$id&gtype=metagenome";
			$m_url = alink( $m_url, $m_taxon_cnt );
			$r .= $m_taxon_cnt . $sd . $m_url . "\t";
		    } else {
			$r .= "0" . $sd . "0" . "\t";
		    }
		}
	    }

	    $it->addRow($r);
	    $count++;
	    next;
	}

	foreach my $modid ( @kegg_mods ) {
	    my $r;
	    $r .= $sd . "<input type='checkbox' name='$select_id_name' " . "value='$id' />\t";
	    my $tmp = $id;
	    $tmp =~ s/KO://;
	    my $url = $kegg_orthology_url . $tmp;
	    $url = alink( $url, $id );
	    $r .= $id . $sd . $url . "\t";
	    $r .= $name . $sd . $name . "\t";
	    $r .= $defn . $sd . $defn . "\t";

	    if ( $modid eq "" ) {
		$r .= "zzzzz" . $sd . "&nbsp;" . "\t";
	    } else {
		my $url = $kegg_module_url . $modid;
		$url = alink( $url, $modid );
		$r .= $modid . $sd . $url . "\t";
	    }

	    my $modname = $kegg_mod_h{$modid};
	    if ( ! $modname || $modname eq "" ) {
		$r .= "zzzzz" . $sd . "&nbsp;" . "\t";
	    } else {
		my $url = $section_cgi . "&page=komodule" 
		    . "&pathway_id=$pathway_oid&module_id=$modid";
		$url = alink( $url, $modname );
		$r .= $modname . $sd . $url . "\t";
	    }

            # gene count
            my $gene_cnt = $ko_gene_cnt{$id};
            if ($hasIsolates) {
                if ($gene_cnt) {
                    my $url = "$section_cgi&page=kogenelist";
                    $url .= "&pathway_id=$pathway_oid";
                    $url .= "&ko_id=$id&gtype=isolate";
                    $url = alink( $url, $gene_cnt );
                    $r .= $gene_cnt . $sd . $url . "\t";
                } else {
                    $r .= "0" . $sd . "0" . "\t";
                }
            }

            # genome count
            my $taxon_cnt = $ko_genome_cnt{$id};
            if ($hasIsolates) {
                if ($taxon_cnt) {
                    my $url = "$section_cgi&page=kogenomelist";
                    $url .= "&pathway_id=$pathway_oid";
                    $url .= "&ko_id=$id&gtype=isolate";
                    $url = alink( $url, $taxon_cnt );
                    $r .= $taxon_cnt . $sd . $url . "\t";
                } else {
                    $r .= "0" . $sd . "0" . "\t";
                }
            }

            if ($include_metagenomes) {
                my $m_gene_cnt = $m_ko_gene_cnt{$id};
                if ($hasMetagenomes) {
                    if ($m_gene_cnt) {
                        my $m_url = "$section_cgi&page=kogenelist";
                        $m_url .= "&pathway_id=$pathway_oid";
                        $m_url .= "&ko_id=$id&gtype=metagenome";
                        $m_url = alink( $m_url, $m_gene_cnt );
                        $r .= $m_gene_cnt . $sd . $m_url . "\t";
                    } else {
                        $r .= "0" . $sd . "0" . "\t";
                    }
                }

                my $m_taxon_cnt = $m_ko_genome_cnt{$id};
                if ($hasMetagenomes) {
                    if ($m_taxon_cnt) {
                        my $m_url = "$section_cgi&page=kogenomelist";
                        $m_url .= "&pathway_id=$pathway_oid";
                        $m_url .= "&ko_id=$id&gtype=metagenome";
                        $m_url = alink( $m_url, $m_taxon_cnt );
                        $r .= $m_taxon_cnt . $sd . $m_url . "\t";
                    } else {
                        $r .= "0" . $sd . "0" . "\t";
                    }
                }
            }

	    $it->addRow($r);
	    $count++;
	}
    }
    $cur->finish();

    printEndWorkingDiv();

    my $tmp = keys %distinct_koid;
    if ($count > 0 && $tmp > 0) {
    	printFuncCartFooter() if $count > 10;
    	$it->printOuterTable(1);
    	printFuncCartFooter();
    }
    print "</div>";    # end pathwtab1

    print "<div id='pathwtab2'>";
    ## save to workspace
    if ($count > 0) {
        WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
    }
    print "</div>";    # end pathwtab2

    print "<div id='pathwtab3'>";
    printViewPathwayForm( $dbh, $pathway_oid, $image_id, $numTaxon );
    print "</div>";    # end pathwtab3

    TabHTML::printTabDivEnd();
    print end_form();

    printStatusLine( "$count rows $tmp ko terms", 2 );
    #$dbh->disconnect();
}

# no pathways -TEST does not work - ken
sub printKOtermDetailNoPath {
    my $kegg_id = param("kegg_id");

    print "<h1>KEGG KO Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    printMainForm();
    printFuncCartFooter();

    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql = qq{
	select kt.ko_id, kt.ko_name, kt.definition,
	km.module_id, km.module_name, count (distinct gk.gene_oid),
	count(distinct g.taxon)
	    from kegg_pathway pw, image_roi iroi, image_roi_ko_terms irk, 
	    gene_ko_terms gk, gene g,
	    ko_term kt left join kegg_module_ko_terms kmt
	    on kt.ko_id = kmt.ko_terms
	    left join kegg_module km on kmt.module_id = km.module_id  
	    where pw.kegg_id = ?
	    and iroi.pathway   = pw.pathway_oid
	    and irk.roi_id     = iroi.roi_id
	    and irk.ko_terms   = gk.ko_terms
	    and gk.ko_terms    = kt.ko_id
	    and gk.gene_oid = g.gene_oid
	    $imgClause
	    group by kt.ko_id, kt.ko_name, kt.definition,
	    km.module_id, km.module_name    
	};

    my $cur = execSql( $dbh, $sql, $verbose, $kegg_id );

    my $count = 0;
    my $it    = new InnerTable( 1, "ko$$", "ko", 1 );
    my $sd    = $it->getSdDelim(); # sort delimiter

    $it->addColSpec( "Select" );
    $it->addColSpec( "KO Term ID",     "char asc",    "right" );
    $it->addColSpec( "KO Name",        "char asc",    "left" );
    $it->addColSpec( "Definition",     "char asc",    "left" );
    $it->addColSpec( "KO Module ID",   "char asc",    "left" );
    $it->addColSpec( "KO Module Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",     "number desc", "right" );
    $it->addColSpec( "Genome Count",   "number desc", "right" );
    my %distinct_koid;

    for ( ; ; ) {
        my ( $id, $name, $defn, $modid, $modname, $gene_cnt, $taxon_cnt ) = $cur->fetchrow();
        last if !$id;
        $count++;
        $distinct_koid{$id} = "";
        my $r;
        $r .= $sd . "<input type='checkbox' name='func_id' " . "value='$id' />\t";
        my $tmp = $id;
        $tmp =~ s/KO://;
        my $url = $kegg_orthology_url . $tmp;
        $url = alink( $url, $id );
        $r .= $id . $sd . $url . "\t";
        $r .= $name . $sd . $name . "\t";
        $r .= $defn . $sd . $defn . "\t";

        if ( $modid eq "" ) {
            $r .= "zzzzz" . $sd . "&nbsp;" . "\t";
        } else {
            my $url = $kegg_module_url . $modid;
            $url = alink( $url, $modid );
            $r .= $modid . $sd . $url . "\t";
        }

        if ( $modname eq "" ) {
            $r .= "zzzzz" . $sd . "&nbsp;" . "\t";
        } else {
            $r .= $modname . $sd . $modname . "\t";
        }

        $r .= $gene_cnt . $sd . $gene_cnt . "\t";
        $r .= $taxon_cnt . $sd . $taxon_cnt . "\t";

        $it->addRow($r);
    }

    $cur->finish();

    $it->printOuterTable(1);

    print end_form();

    my $tmp = keys %distinct_koid;
    printStatusLine( "$count rows $tmp ko terms", 2 );
    #$dbh->disconnect();
}

# this is the one for a gene details page
sub printKoTermDetail2 {
    my $ko_id    = param("ko_id");
    my $gene_oid = param("gene_oid");

    print "<h1>KO Term Gene Detail</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select kt.ko_id, kt.ko_name, kt.definition
        from ko_term kt
        where kt.ko_id = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my ( $id, $name, $defn ) = $cur->fetchrow();
    $cur->finish();

    my $sql = qq{
        select gene_display_name 
        from gene
        where gene_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $gene_oid );
    my ($gene_display_name) = $cur->fetchrow();
    $cur->finish();

    my $tmp = $id;
    $tmp =~ s/KO://;
    my $url = $kegg_orthology_url . $tmp;
    $url = alink( $url, $id );

    my $url2 = "main.cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
    $url2 = alink( $url2, $gene_oid );
    print qq{
        <p>
        <b>For gene</b> $url2 $gene_display_name
        <br/><br/>
        $url $name $defn
        </p>
    };

    print "<h2>Modules</h2>\n";

    # TODO maybe ko modules not pathways ????
    # - i'll have to do left join to modules
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql = qq{
	    select distinct $nvl(km.module_id, 'n/a'),
	       km.module_name, pw.pathway_oid, pw.pathway_name
	    from gene_ko_terms gk,  gene g, 
	    ko_term kt 
	    left join kegg_module_ko_terms kmt on kt.ko_id = kmt.ko_terms 
	    left join kegg_module km on kmt.module_id = km.module_id
	    left join kegg_pathway pw on km.pathway = pw.pathway_oid
	    left join image_roi iroi on pw.pathway_oid = iroi.pathway
	    left join image_roi_ko_terms irk on iroi.roi_id = irk.roi_id
	    where g.gene_oid = ?
	    and gk.ko_terms = ?
	    and gk.ko_terms  = kt.ko_id
	    and gk.gene_oid = g.gene_oid
	    $imgClause
	};
    my @a = ( $gene_oid, $ko_id );
    my $cur   = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my $count = 0;
    my $it    = new InnerTable( 1, "ko$$", "ko", 0 );
    my $sd    = $it->getSdDelim(); # sort delimiter
    $it->addColSpec( "KO Module ID",   "char asc", "left" );
    $it->addColSpec( "KO Module Name", "char asc", "left" );
    $it->addColSpec( "Pathway Name",   "char asc", "left" );

    for ( ; ; ) {
        my ( $modid, $modname, $pathway_id, $pathway_name ) = $cur->fetchrow();
        last if !$modid;
        $count++;
        my $r;

        if ( $modid ne "n/a" ) {
            my $url = $kegg_module_url . $modid;
            $url = alink( $url, $modid );
            $r .= $modid . $sd . $url . "\t";

            if ( $pathway_id ne "" ) {
                my $url = $section_cgi . "&page=komodule" . "&pathway_id=$pathway_id&module_id=$modid";
                $url = alink( $url, $modname );
                $r .= $modname . $sd . $url . "\t";

            } else {
                $r .= $modname . $sd . $modname . "\t";
            }

        } else {
            $r .= "" . $sd . "&nbsp;" . "\t";
            $r .= "" . $sd . "&nbsp;" . "\t";
        }

        if ( $pathway_name ne "" ) {
            $r .= $pathway_name . $sd . $pathway_name . "\t";
        } else {
            $r .= "" . $sd . "&nbsp;" . "\t";
        }

        $it->addRow($r);
    }
    $cur->finish();
    $it->printOuterTable(1);

    print "<br/><h1>KO Term Detail</h1>\n";

    print "<h2>KO Term Pathway</h2>\n";
    print "<p>\n";
    $sql = qq{
       select distinct irk.ko_terms, pw.pathway_name
       from kegg_pathway pw, image_roi roi, image_roi_ko_terms irk
       where pw.pathway_oid = roi.pathway
       and roi.roi_id = irk.roi_id
       and irk.ko_terms = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my @recs;
    for ( ; ; ) {
        my ( $ko_id2, $pathway_name ) = $cur->fetchrow();
        last if !$ko_id2;

        push( @recs, "$ko_id2\t$pathway_name" );
    }
    $cur->finish();
    my @headers = ( "KO ID", "Pathway Name" );
    printTable( \@headers, \@recs );
    print "</p>\n";

    print "<h2>KO Term Module</h2>\n";
    print "<p>\n";
    $sql = qq{
        select distinct kmkt.ko_terms, km.module_id, km.module_name
        from kegg_module_ko_terms kmkt, kegg_module km
        where  kmkt.ko_terms = ?
        and kmkt.module_id = km.module_id  
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my @recs;
    for ( ; ; ) {
        my ( $ko_id2, $module_id, $module_name ) = $cur->fetchrow();
        last if !$ko_id2;

        push( @recs, "$ko_id2\t$module_id\t$module_name" );
    }
    $cur->finish();
    my @headers = ( "KO ID", "Module ID", "Module Name" );
    printTable( \@headers, \@recs );
    print "</p>\n";

    print "<h2>KO Term Reactions</h2>\n";
    print "<p>\n";
    $sql = qq{
        select distinct k1.ko_id,k1.reactions, r1.rxn_name, r1.rxn_definition, 
        r1.rxn_equation 
        from ko_term_reactions k1, reaction r1
        where k1.ko_id = ? 
        and k1.reactions = r1.ext_accession
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my @recs;
    for ( ; ; ) {
        my ( $ko_id2, $reactions, $rxn_name, $rxn_definition, $rxn_equation ) = $cur->fetchrow();
        last if !$ko_id2;

        if ( $reactions ne "" ) {
            my $url = $kegg_reaction_url . $reactions;
            $url = alink( $url, $reactions );
            push( @recs, "$ko_id2\t$url\t$rxn_name\t$rxn_definition\t$rxn_equation" );
        } else {
            push( @recs, "$ko_id2\t$reactions\t$rxn_name\t$rxn_definition\t$rxn_equation" );
        }

    }
    $cur->finish();
    my @headers = ( "KO ID", "Reaction", "Reaction Name", "Definition", "Equation" );
    printTable( \@headers, \@recs );

    print "</p>\n";

    print "<h2>KO Term Enzymes</h2>\n";
    print "<p>\n";
    $sql = qq{
        select ke.ko_id, ke.enzymes, enzyme_name, comments, rxn_desc
        from ko_term_enzymes ke, enzyme e
        where ke.ko_id = ?
        and ke.enzymes = e.ec_number
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my @recs;
    for ( ; ; ) {
        my ( $ko_id2, $enzymes, $enzyme_name, $comments, $rxn_desc ) = $cur->fetchrow();
        last if !$ko_id2;

        if ( $enzymes ne "" ) {
            my $url = $enzyme_base_url . $enzymes;
            $url = alink( $url, $enzymes );
            push( @recs, "$ko_id2\t$url\t$enzyme_name\t$comments\t$rxn_desc" );
        } else {
            push( @recs, "$ko_id2\t$enzymes\t$enzyme_name\t$comments\t$rxn_desc" );
        }
    }
    $cur->finish();
    my @headers = ( "KO ID", "Enzyme", "Enzyme Name", "Comments", "Description" );
    printTable( \@headers, \@recs );
    print "</p>\n";

    print "<h2>KO Term Connected to COGS</h2>\n";
    print "<p>\n";
    $sql = qq{
        select k.ko_id, k.cogs, c.cog_name, c.description
        from ko_term_cogs k , cog c
        where k.ko_id = ?
        and k.cogs = c.cog_id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my @recs;
    for ( ; ; ) {
        my ( $ko_id2, $cogs, $cog_name, $description ) = $cur->fetchrow();
        last if !$ko_id2;
        if ( $cogs ne "" ) {
            my $url = $cog_base_url . $cogs;
            $url = alink( $url, $cogs );
            push( @recs, "$ko_id2\t$url\t$cog_name\t$description" );
        } else {
            push( @recs, "$ko_id2\t$cogs\t$cog_name\t$description" );
        }
    }
    $cur->finish();
    my @headers = ( "KO ID", "COG ID", "COG Name", "Description" );
    printTable( \@headers, \@recs );
    print "</p>\n";

    print "<h2>KO Term Connected to GO</h2>\n";
    print "<p>\n";
    $sql = qq{
        select k.ko_id, k.go_ids, g.go_term, g.go_type, g.definition
        from ko_term_go_ids k, go_term g
        where k.ko_id = ?
        and k.go_ids = g.go_id
    };
    my $cur = execSql( $dbh, $sql, $verbose, $ko_id );
    my @recs;
    for ( ; ; ) {
        my ( $ko_id2, $go_ids, $go_term, $go_type, $definition ) = $cur->fetchrow();
        last if !$ko_id2;
        if ( $go_ids ne "" ) {
            my $url = $go_base_url . $go_ids;
            $url = alink( $url, $go_ids );
            push( @recs, "$ko_id2\t$url\t$go_term\t$go_type\t$definition" );
        } else {
            push( @recs, "$ko_id2\t$go_ids\t$go_term\t$go_type\t$definition" );
        }
    }
    $cur->finish();
    my @headers = ( "KO ID", "GO ID", "GO Term", "Go Type", "Definition" );
    printTable( \@headers, \@recs );
    print "</p>\n";

    printStatusLine( "Loaded.", 2 );
    #$dbh->disconnect();
}

#
# $rows_aref tab delimited rows of data
sub printTable {
    my ( $colHeader_aref, $rows_aref ) = @_;

    print "<table class='img'>\n";
    foreach my $header (@$colHeader_aref) {
        print "<th class='img'> $header </th>\n";
    }

    foreach my $line (@$rows_aref) {
        my @array = split( /\t/, $line );
        print "<tr class='img'>\n";

        foreach my $col (@array) {
            print "<td class='img'> $col </td>\n";
        }

        print "</tr>\n";
    }

    print "</table>\n";
}

############################################################################
# printKeggPathwayDetail - Show detail page for kegg pathway.
############################################################################
sub printKeggPathwayDetail {
    my ($numTaxon) = @_;
    my $pathway_oid = param("pathway_oid");

    print "<h1>KEGG Pathway Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $sql = qq{
        select pathway_name, image_id
        from kegg_pathway
        where pathway_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    my ( $pathway_name, $image_id ) = $cur->fetchrow();
    $cur->finish();

    my $taxonClause = WebUtil::txsClause( "g.taxon_oid", $dbh );

    print "<p>\n";
    print "Details for Pathway: ";
    print "<i>".escHtml($pathway_name)."</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause ne "";
    print "</p>\n";

    # For separate tables in multiple tabs, set the form id to be the
    # InnerTable table name (3rd argument) followed by "_frm" :
    print start_form(
          -id     => "enz_frm",
          -name   => "mainForm",
          -action => "$main_cgi"
    );

    use TabHTML;
    TabHTML::printTabAPILinks("ecpathwayTab");
    my @tabIndex;
    my @tabNames;
    if ($include_metagenomes) {
        @tabIndex = ( "#pathwtab1", "#pathwtab2", "#pathwtab3" );
        @tabNames = ( "Enzymes in Pathway", "Save to My Workspace", 
		      "View Map for Selected Genomes" );        
    } else {
        @tabIndex = ( "#pathwtab1", "#pathwtab3" );
        @tabNames = ( "Enzymes in Pathway", 
		      "View Map for Selected Genomes" );
    }
    TabHTML::printTabDiv( "ecpathwayTab", \@tabIndex, \@tabNames );

    print "<div id='pathwtab1'>";
    print "<h2>Enzymes in Pathway</h2>\n";

    my %ec_cnts;
    my %m_ec_cnts;

    printStartWorkingDiv();

    print "<p>Retrieving EC pathway information ...\n";
    my %allEC;
    my $sql = qq{
        select distinct ez.ec_number, ez.enzyme_name
        from kegg_pathway pw,
             image_roi_ko_terms irkt, ko_term_enzymes kte,
             image_roi roi, enzyme ez
        where pw.pathway_oid = ?
        and pw.pathway_oid = roi.pathway
        and roi.roi_id = irkt.roi_id
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = ez.ec_number
    };
    print "printKeggPathwayDetail() 0 sql: $sql<br/>";
    $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for ( ; ; ) {
        my ( $ec_number, $ec_name ) = $cur->fetchrow();
        last if !$ec_number;
        $allEC{$ec_number} = $ec_name;
    }
    $cur->finish();

    print "<p>Counting isolate genomes ...\n";

    my $rclause = WebUtil::urClause( "g.taxon_oid" );
    my $imgClause = WebUtil::imgClauseNoTaxon( "g.taxon_oid", 1 );
    my $sql = qq{
        select g.enzyme, count( distinct g.taxon_oid )
        from image_roi ir, image_roi_ko_terms irkt, ko_term_enzymes kte,
             mv_taxon_ec_stat g
        where ir.pathway = ?
        and ir.roi_id = irkt.roi_id
        and irkt.ko_terms = kte.ko_id
        and kte.enzymes = g.enzyme
        $taxonClause
        $rclause
        $imgClause
        group by g.enzyme
    };
    print "printKeggPathwayDetail() 1 sql: $sql<br/>";
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
    for ( ; ; ) {
        my ( $ec_number, $cnt ) = $cur->fetchrow();
        last if !$ec_number;
        $ec_cnts{$ec_number} = $cnt;
    }
    $cur->finish();

    if ($include_metagenomes) {
        print "<p>Counting metagenomes ...\n";

        my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 2);
    	my $sql = qq{
            select g.enzyme, count( distinct g.taxon_oid )
            from image_roi ir, image_roi_ko_terms irkt, ko_term_enzymes kte,
                 mv_taxon_ec_stat g
            where ir.pathway = ?
            and ir.roi_id = irkt.roi_id
            and irkt.ko_terms = kte.ko_id
            and kte.enzymes = g.enzyme
            $taxonClause
            $rclause
            $imgClause
            group by g.enzyme
        };
        print "printKeggPathwayDetail() 2 sql: $sql<br/>";

        $cur = execSql( $dbh, $sql, $verbose, $pathway_oid );
        for ( ; ; ) {
            my ( $ec_number, $cnt ) = $cur->fetchrow();
            last if !$ec_number;
            $m_ec_cnts{$ec_number} = $cnt;
        }
        $cur->finish();

        if ( $new_func_count ) { 
            my $rclause2   = WebUtil::urClause( "f.taxon_oid" );
            my $imgClause2 = WebUtil::imgClauseNoTaxon( "f.taxon_oid", 2 );
            my $taxonClause2 = WebUtil::txsClause( "f.taxon_oid", $dbh );
 
            $sql = qq{
               select f.func_id, count(distinct f.taxon_oid)
               from taxon_ec_count f
               where f.gene_count > 0
               $rclause2
               $imgClause2
               $taxonClause2
               group by f.func_id
            }; 
 
            $cur  = execSql( $dbh, $sql, $verbose ); 
            for ( ; ; ) { 
                my ($ec_id, $t_cnt) = $cur->fetchrow(); 
                last if !$ec_id; 
                if ( $m_ec_cnts{$ec_id} ) {
                    $m_ec_cnts{$ec_id} += $t_cnt;
                } else {
                    $m_ec_cnts{$ec_id} = $t_cnt;
                }
            }
            $cur->finish();
            print "<br/>\n";

    	} else { 
    	    my $taxonClause1 = WebUtil::txsClause("t.taxon_oid", $dbh);
    	    $sql = MerFsUtil::getTaxonsInFileSql($taxonClause1);
	    $sql .= " and t.genome_type = 'metagenome' ";
    	    $cur = execSql( $dbh, $sql, $verbose );
    	    for ( ;; ) {
		my ($t_oid) = $cur->fetchrow();
		last if !$t_oid;
		
		print ". ";    
		my %funcs = MetaUtil::getTaxonFuncCount( $t_oid, '', 'ec' );
		foreach my $k ( keys %funcs ) {
		    if ( $m_ec_cnts{$k} ) {
    			$m_ec_cnts{$k} += 1;
		    } else {
    			$m_ec_cnts{$k} = 1;
		    }
		}
    	    }
    	    $cur->finish();
    	    print "<br/>\n";
    	}
    }

    my $baseUrl = "$section_cgi&page=keggPathwayDetail";
    $baseUrl .= "&pathway_oid=$pathway_oid";

    my $hasIsolates = scalar (keys %ec_cnts) > 0 ? 1 : 0;
    my $hasMetagenomes = scalar (keys %m_ec_cnts) > 0 ? 1 : 0;

    my $it = new InnerTable( 1, "enz$$", "enz", 1 );
    my $sdDelim = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "EC Number",   "asc", "left" );
    $it->addColSpec( "Enzyme Name", "asc", "left" );
    if ($include_metagenomes) {
        $it->addColSpec("Isolate<br/>Genome Count", "desc", "right")
	    if $hasIsolates;
        $it->addColSpec("Metagenome<br/>Count", "asc",  "right")
	    if $hasMetagenomes;
    } else {
        $it->addColSpec("Genome Count", "desc", "right")
	    if $hasIsolates;
    }

    my $select_id_name = "ec_number";
    my $count = 0;
    foreach my $ec_number ( keys %allEC ) {
        my $ec_name = $allEC{$ec_number};
        $count++;

        my $r = $sdDelim . "<input type='checkbox' name='$select_id_name' "
	      . "value='$ec_number' />\t";
        $r .= "$ec_number\t";
        $r .= "$ec_name\t";

        my $cnt = $ec_cnts{$ec_number};
    	if ($hasIsolates) {
    	    if ($cnt) {
		my $url = "$section_cgi&page=kpdKeggPathwayDetailGenomes";
		$url .= "&pathway_oid=$pathway_oid";
		$url .= "&ec_number=$ec_number&gtype=isolate";
		$r   .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
    	    } else {
		$r .= "0" . $sdDelim . "0" . "\t";
    	    }
    	}
	
        if ($include_metagenomes) {
            my $m_cnt = $m_ec_cnts{$ec_number};
    	    if ($hasMetagenomes) {
		if ($m_cnt) {
		    my $m_url = "$section_cgi&page=kpdKeggPathwayDetailGenomes";
		    $m_url .= "&pathway_oid=$pathway_oid";
		    $m_url .= "&ec_number=$ec_number&gtype=metagenome";
		    $r .= $m_cnt . $sdDelim . alink( $m_url, $m_cnt ) . "\t";
		} else {
		    $r .= "0" . $sdDelim . "0" . "\t";
		}
    	    }
        }

        $it->addRow($r);
    }

    printEndWorkingDiv();

    printStatusLine( "Loaded.", 2 );

    my $zero_count_msg = "There are no enzymes in this pathway.";

    if ($count) {
        WebUtil::printFuncCartFooter() if $count > 10;
        $it->printOuterTable(1);
        WebUtil::printFuncCartFooter();
        printHint("The Function Cart allows for phylogenetic profile comparisons.");
    } else {
        printMessage( $zero_count_msg );
    }
    print "</div>"; # end pathwtab1

    if ($include_metagenomes) {
        print "<div id='pathwtab2'>";
        if ($count) {
            ## save to workspace
            print hiddenVar( 'save_func_id_name', 'ec_number' );
            WorkspaceUtil::printSaveFunctionToWorkspace($select_id_name);
        } else {
            printMessage( $zero_count_msg );
        }
        print "</div>"; # end pathwtab2
    }

    print "<div id='pathwtab3'>";
    printViewPathwayForm( $dbh, $pathway_oid, $image_id, $numTaxon );
    print "</div>"; # end pathwtab3

    TabHTML::printTabDivEnd();
    print end_form();

    #    if ( $include_metagenomes && $img_internal ) {
    #        print "<h2>Experimental</h2>\n";
    #        my $url = "$section_cgi&page=kpdSelectScaffolds";
    #        $url .= "&pathway_oid=$pathway_oid";
    #        print buttonUrl( $url, "Scaffold Profiler", "smbutton" );
    #    }

}

############################################################################
# printKeggPathwayInfo - Show kegg pathway for specifc gene_oid and ko_id.
############################################################################
sub printKeggModulePathway {
    my $ko_id     = param("ko_id");
    my $ko_name   = param("ko_name");
    my $ko_def    = param("ko_def");
    my $gene_oid  = param("gene_oid");
    my $taxon_oid = param("taxon_oid");

    printMainForm();
    print "<h1>KEGG Module and Pathway</h1>\n";
    my $koid_url = $kegg_orthology_url . $ko_id;
    $koid_url = alink( $koid_url, $ko_id );
    my $ko_name_def = $ko_name . "; " . $ko_def;
    my $gene_url    = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=$gene_oid";
    $gene_url = alink( $gene_url, $gene_oid );
    print "<p>\n";
    print "For KO term <i>$koid_url ($ko_name_def)</i> at Gene <i>$gene_url</i>\n";
    print "</p>\n";

    print hiddenVar( 'func_id', $ko_id );
    my $name = "_section_FuncCartStor_addToFuncCart";
    print submit(
                  -name  => $name,
                  -value => 'Add to Function Cart',
                  -class => 'meddefbutton'
    );

    printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();

    my $count_module = printModuleComponent( $dbh, $ko_id, $gene_oid );
    my $count_pathway = printPathwayComponent( $dbh, $ko_id, $gene_oid, $taxon_oid );

    if ( $count_module == 0 && $count_pathway == 0 ) {
        print "<p>\n";
        print "No results returned.\n";
        print "</p>\n";
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

sub printModuleComponent {
    my ( $dbh, $ko_id, $gene_oid ) = @_;

    my $sql = qq{
        select distinct gk.ko_terms, km.module_id, 
               km.module_name, km.module_type
        from gene_ko_terms gk, kegg_module_ko_terms kmkt, kegg_module km
        where gk.gene_oid  = ?
        and gk.ko_terms  = ?
        and gk.ko_terms = kmkt.ko_terms
        and kmkt.module_id = km.module_id
        order by km.module_id
    };

    my @bindList = ( $gene_oid, $ko_id );
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my $count = 0;
    for ( ;; ) {
        my ( $ko_id, $module_id, $module_name, $module_type ) 
	    = $cur->fetchrow();
        last if !$ko_id;
        $count++;
        my $rec .= "$ko_id\t";
        $rec    .= "$module_id\t";
        $rec    .= "$module_name\t";
        $rec    .= "$module_type\t";
        push( @recs, $rec );
    }
    $cur->finish();

    if ( $count > 0 ) {
        print "<h2>Kegg Module</h2>\n";
        print "<p>\n";

        my $it = new InnerTable( 1, "keggmodule$$", "keggmodule", 1 );
        my $sd = $it->getSdDelim();    # sort delimiter
        $it->addColSpec( "Module ID",   "asc" );
        $it->addColSpec( "Module Name", "asc" );
        $it->addColSpec( "Module Type", "asc" );

        for my $r (@recs) {
            my ( $ko_id, $module_id, $module_name, $module_type, $pathway_oid, $ko_pathway_id, $category, $pathway_name ) =
              split( /\t/, $r );

            my $row;

            my $ko_module_url = $kegg_module_url . $module_id;
            $ko_module_url = alink( $ko_module_url, $module_id );
            $row .= $module_id . $sd . $ko_module_url . "\t";
            $row .= $module_name . $sd . $module_name . "\t";
            $row .= $module_type . $sd . $module_type . "\t";

            $it->addRow($row);
        }
        $it->printOuterTable(1);

        print "</p>\n";
    }

    return $count;
}

sub printPathwayComponent {
    my ( $dbh, $ko_id, $gene_oid, $taxon_oid ) = @_;

    my $sql = qq{
        select distinct gk.ko_terms, pw.pathway_oid, pw.image_id,
	       pw.ko_pathway_id, pw.category, pw.pathway_name
        from gene_ko_terms gk, image_roi_ko_terms irk,
             image_roi iroi, kegg_pathway pw
        where gk.gene_oid  = ?
        and gk.ko_terms  = ?
        and gk.ko_terms = irk.ko_terms
        and irk.roi_id = iroi.roi_id
        and iroi.pathway = pw.pathway_oid
        order by pw.category, pw.pathway_name
    };

    my @bindList = ( $gene_oid, $ko_id );
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my $count = 0;
    for ( ;; ) {
        my ( $ko_id, $pathway_oid, $image_id, $ko_pathway_id,
	     $category, $pathway_name ) = $cur->fetchrow();
        last if !$ko_id;
        $count++;
        my $rec .= "$ko_id\t";
        $rec    .= "$pathway_oid\t";
        $rec    .= "$image_id\t";
        $rec    .= "$ko_pathway_id\t";
        $rec    .= "$category\t";
        $rec    .= "$pathway_name\t";
        push( @recs, $rec );
    }
    $cur->finish();

    if ( $count > 0 ) {
        print "<h2>Kegg Pathway</h2>\n";
        print "<p>\n";

        my $it = new InnerTable( 1, "keggpathway$$", "keggpathway", 1 );
        my $sd = $it->getSdDelim(); # sort delimiter

        $it->addColSpec( "Selection", "", "center" );
        $it->addColSpec( "KO Pathway ID", "asc" );
        $it->addColSpec( "Category",      "asc" );
        $it->addColSpec( "Pathway Name",  "asc" );

        my $ko_url = $kegg_orthology_url;
        chop($ko_url);
        chop($ko_url);
        chop($ko_url);

        for my $r (@recs) {
            my ( $ko_id, $pathway_oid, $image_id, $ko_pathway_id,
		 $category, $pathway_name ) = split( /\t/, $r );

            my $row;
            $row .= $sd . "<input type='checkbox' title='$image_id' "
		  . "name='pathway_oid' value='$pathway_oid' />\t";

            my $ko_pathway_url = $ko_url . $ko_pathway_id . '+' . $ko_id;
            $ko_pathway_url = alink( $ko_pathway_url, $ko_pathway_id );
            $row .= $ko_pathway_id . $sd . $ko_pathway_url . "\t";

            $row .= $category . $sd . $category . "\t";
            $row .= $pathway_name . $sd . $pathway_name . "\t";

            $it->addRow($row);
        }
        $it->printOuterTable(1);

        print hiddenVar( 'map_id',           '' );
        print hiddenVar( 'fromviewer',       'TreeFileMgr' );
        print hiddenVar( 'taxon_filter_oid', $taxon_oid );

        my $name = "_section_PathwayMaps_showMap";
        print submit(
                      -id      => "viewMapButton",
                      -name    => $name,
                      -value   => "View Map",
                      -class   => "meddefbutton",
                      -onclick => "return setMapId()"
        );

        print qq{
            <script type='text/javascript'>
            function setMapId() {
                var checkedCount = 0;
                var checkedTitle = '';
                var checkObj = document.mainForm.elements['pathway_oid'];
                for (j = 0; j < checkObj.length; j++) {
                    if (checkObj[j].checked) { 
                        checkedCount++;
                        checkedTitle = checkObj[j].title;
			if (checkedCount > 1) {
			    window.alert("Please select exactly one pathway.");
			    return false;
			}
                    }
                }
                if (checkedCount == 0) {
                    window.alert("Please select one pathway.");
                    return false;
                }
                var mapIdObj = document.mainForm.elements['map_id'];
	        mapIdObj.value = checkedTitle;
		return true;
            }
            </script>
        };
        print "</p>\n";
    }

    return $count;
}

sub printForm {
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = ($hideViruses eq "" || $hideViruses eq "Yes") ? 0 : 1;
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = ($hidePlasmids eq "" || $hidePlasmids eq "Yes") ? 0 : 1;
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = ($hideGFragment eq "" || $hideGFragment eq "Yes") ? 0 : 1;

    my $xml_cgi = $cgi_url . '/xml.cgi';
    my $template = HTML::Template->new
        ( filename => "$base_dir/genomeJsonOneDiv.html" );

    $template->param( gfr          => $hideGFragment );
    $template->param( pla          => $hidePlasmids );
    $template->param( vir          => $hideViruses );
    $template->param( isolate      => 1 );
    $template->param( all          => 1 );
    $template->param( cart         => 1 );
    $template->param( xml_cgi      => $xml_cgi );
    $template->param( prefix       => '' );
    $template->param( maxSelected1 => -1 );
    $template->param( selectedGenome1Title => 'Please select genomes to highlight on KEGG Pathway Map:' );

    if ( $include_metagenomes ) {
        $template->param( include_metagenomes => 1 );
        $template->param( selectedAssembled1  => 1 );
    }

    my $s = "";
    $template->param( mySubmitButton => $s );
    print $template->output;
}

sub printViewPathwayForm {
    my ( $dbh, $pathway_oid, $image_id, $numTaxon ) = @_;

    print "<h2>KEGG Map for Selected Genomes</h2>";
    printForm(); # genome loader

    print hiddenVar( "pathway_oid", $pathway_oid );
    print hiddenVar( "map_id",      $image_id );

    my $contact_oid = getContactOid();
    print "<p>\n";
    if ( $show_myimg_login && $contact_oid ) {
        print "<input type='radio' name='mapType' value='ecEquivalogs' />";
        print "Genes in selected genome<br/>\n";
        print "<input type='radio' name='mapType' value='missingEnzymes' />";
        print "Find missing enzymes<br/>\n";
        print "<input type='radio' name='mapType' value='' checked />";
        print "None<br/>\n";
    } else {
        print "<input type='checkbox' name='mapType' value='missingEnzymes'/>";
        print "Find missing enzymes. (For single genome selection)<br/>\n";
    }
    print "</p>\n";

    my $name = "_section_PathwayMaps_showMap";
    GenomeListJSON::printHiddenInputType( 'PathwayMaps', 'showMap' );
    my $button = GenomeListJSON::printMySubmitButtonXDiv
	( 'go', $name, 'View Map', '', 'PathwayMaps',
	  'showMap', 'meddefbutton', 'selectedGenome1', 1 );
    print $button;

    print nbsp(1);
    print reset( -class => "smbutton" );

    GenomeListJSON::showGenomeCart($numTaxon);
}

############################################################################
# printKpdKeggPathwayDetailGenomes - Show list of genomes for an
#   in a KEGG map enzyme.
############################################################################
sub printKpdKeggPathwayDetailGenomes {
    my $pathway_oid = param("pathway_oid");
    my $ec_number   = param("ec_number");
    my $gtype       = param('gtype');
    if ( !$gtype ) {
        $gtype = 'isolate';
    }

    my $dbh = dbLogin();

    printMainForm();
    if ( $gtype eq 'metagenome' ) {
        print "<h1>Metagenomes with $ec_number</h1>";
    } else {
        print "<h1>Isolate Genomes with $ec_number</h1>";
    }

    my $taxonClause1 = WebUtil::txsClause( "t.taxon_oid", $dbh );
    my $rclause1   = WebUtil::urClause("t.taxon_oid");
    my $imgClause1 = WebUtil::imgClauseNoTaxon("t.taxon_oid", 1);
    $imgClause1 = WebUtil::imgClauseNoTaxon("t.taxon_oid", 2) 
	if ($gtype eq "metagenome");;

    print "<p>\n";
    my $pathway_name = WebUtil::keggPathwayName( $dbh, $pathway_oid );
    my $ec_name      = WebUtil::enzymeName( $dbh, $ec_number );
    print "Genomes with <i>" . escHtml($ec_name) . "</i>";
    print "<br/>*Showing counts for genomes in genome cart only"
        if $taxonClause1 ne "";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $url = "$section_cgi&page=kpdPhyloDist";
    $url .= "&pathway_oid=$pathway_oid";
    $url .= "&ec_number=$ec_number";
    $url .= "&gtype=$gtype";
    print buttonUrl( $url, "Phylogenetic Distribution", "medbutton" );

    printStartWorkingDiv();
    print "Retrieving information from database ... <br/>\n";

    my %taxon_info;
    my $sql = qq{
        select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name
	from taxon t
        where 1 = 1
        $taxonClause1
        $rclause1
        $imgClause1
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($taxon_oid, $domain, $seq_status, $taxon_name) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxon_info{$taxon_oid} = substr( $domain, 0, 1 ) . "\t" 
	    . substr( $seq_status, 0, 1 ) . "\t" . $taxon_name;
    }
    $cur->finish();

    my $taxonClause = WebUtil::txsClause("g.taxon_oid", $dbh);
    my $rclause   = WebUtil::urClause("g.taxon_oid");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 1);
    $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 2) 
	if ($gtype eq "metagenome");;

    $sql = qq{
        select /*+ result_cache */ g.taxon_oid, g.gene_count
        from mv_taxon_ec_stat g
        where g.enzyme = ?
        $rclause
        $imgClause
        $taxonClause
    };

    $cur = execSql( $dbh, $sql, $verbose, $ec_number );

    my $baseUrl = "$section_cgi&page=kpdKeggPathwayDetailGenomes";
    $baseUrl .= "&pathway_oid=$pathway_oid";
    $baseUrl .= "&ec_number=$ec_number";

    my $cachedTable = new CachedTable( "keggGenomes$pathway_oid", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $cachedTable->addColSpec( "Select" );
    $cachedTable->addColSpec( "Domain", "asc", "center", "",
                              "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );
    $cachedTable->addColSpec( "Status", "asc", "center", "",
			      "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" );
    $cachedTable->addColSpec( "Genome", "asc", "left" );
    $cachedTable->addColSpec( "Gene Count", "desc", "right" );

    my $select_id_name = "taxon_filter_oid";

    # first add the rows from db stat table
    my $count = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;
        next if !$taxon_info{$taxon_oid};

        my ( $domain, $seq_status, $taxon_display_name ) =
          split( /\t/, $taxon_info{$taxon_oid} );
        $count++;

        my $r;
        $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$taxon_oid' /> \t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";

        my $url = "$main_cgi?section=TaxonDetail" 
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $r .= "$taxon_display_name" . $sdDelim 
	    . alink( $url, $taxon_display_name ) . "\t";

        my $url = "$section_cgi&page=kpdKeggPathwayDetailGenes";
        $url .= "&pathway_oid=$pathway_oid";
        $url .= "&ec_number=$ec_number";
        $url .= "&taxon_oid=$taxon_oid";
        $url .= "&count=$cnt";

        $r .= $cnt . $sdDelim . alink( $url, $cnt ) . "\t";
        $cachedTable->addRow($r);
    }
    $cur->finish();

    # additional rows for metagenomes
    my $m_count = 0;
    if ( $gtype eq 'metagenome' ) {
        # count MER-FS
        print "<p>Retrieving metagenome gene counts ...<br/>\n";

        my %gene_func_count;
        if ( $new_func_count ) {
            my $sql3 = qq{
               select g.taxon_oid, g.gene_count
               from taxon_ec_count g
               where g.func_id = ?
               and g.gene_count > 0
               $rclause
               $imgClause
               $taxonClause
            };
            my $cur3 = execSql( $dbh, $sql3, $verbose, $ec_number );
            for ( ;; ) {
                my ( $tid3, $cnt3 ) = $cur3->fetchrow();
                last if ! $tid3; 
 
                if ( $gene_func_count{$tid3} ) { 
                    $gene_func_count{$tid3} += $cnt3; 
                } else { 
                    $gene_func_count{$tid3} = $cnt3; 
                } 
            }
            $cur3->finish();
        } 

        my $sql2 = qq{
            select t.taxon_oid, t.domain, t.seq_status, t.taxon_display_name
            from taxon t
            where t.in_file = 'Yes'
            $rclause1
            $imgClause1
            $taxonClause1
        };

        my $cur2 = execSql( $dbh, $sql2, $verbose );
        for ( ; ; ) {
            my ( $t_oid, $domain, $seq_status, $taxon_display_name )
		= $cur2->fetchrow();
            last if !$t_oid;

            $m_count++;
            if ( ( $m_count % 10 ) == 0 ) {
		print ". ";
    	    }
            if ( ( $m_count % 1800 ) == 0 ) {
                print "<br/>\n";
            }

    	    my $g_cnt = 0;
            if ( $new_func_count ) { 
                $g_cnt = $gene_func_count{$t_oid}; 
            } else { 
		$g_cnt = MetaUtil::getTaxonOneFuncCnt($t_oid, "", $ec_number);
    	    }

            if ( $g_cnt > 0 ) {
                $domain     = substr( $domain,     0, 1 );
                $seq_status = substr( $seq_status, 0, 1 );
                my $url = "$main_cgi?section=MetaDetail&page=metaDetail";
                $url .= "&taxon_oid=$t_oid";
                my $r;
                $r .= $sdDelim . "<input type='checkbox' name='$select_id_name' value='$t_oid' /> \t";
                $r .= "$domain\t";
                $r .= "$seq_status\t";
                $r .= $taxon_display_name . $sdDelim . alink( $url, $taxon_display_name ) . "\t";

                my $url = "$section_cgi&page=kpdKeggPathwayDetailGenes";
                $url .= "&pathway_oid=$pathway_oid";
                $url .= "&ec_number=$ec_number";
                $url .= "&taxon_oid=$t_oid";
                $url .= "&count=$g_cnt";

                $r .= $g_cnt . $sdDelim . alink( $url, $g_cnt ) . "\t";
                $cachedTable->addRow($r);
                $count++;
            }
        }
        $cur2->finish();
    }
    #$dbh->disconnect();

    printEndWorkingDiv();

    if ( $count == 0 ) {
        print "0 genomes retrieved.<br/>\n";
    }
    else {
        print "<p>\n";
        print domainLetterNote() . "<br/>\n";
        print completionLetterNote() . "<br/>\n";
        print "</p>\n";
    
	WebUtil::printGenomeCartFooter() if $count > 10;
        $cachedTable->printTable();
        WebUtil::printGenomeCartFooter();
    
        if ($count > 0) {
            WorkspaceUtil::printSaveGenomeToWorkspace($select_id_name);
        }        
    }

    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();
}

############################################################################
# printKpdPhyloDist - Print phylo distribution of enzymes for the
#   given kegg pathway.
############################################################################
sub printKpdPhyloDist {
    my $pathway_oid = param("pathway_oid");
    my $ec_number   = param("ec_number");
    my $gtype       = param('gtype');
    if ( !$gtype ) {
        $gtype = 'isolate';
    }

    my $dbh = dbLogin();
    printMainForm();
    print "<h1>Phylogenetic Distribution for $ec_number</h1>\n";

    printStatusLine( "Loading ...", 1 );

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("taxonSelections");

    printStartWorkingDiv();
    print "<p>Retrieving information from database ...<br/>\n";

    my $rclause = WebUtil::urClause("g.taxon_oid");
    my $taxonClause = WebUtil::txsClause("g.taxon_oid", $dbh);
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 1);
    $imgClause = WebUtil::imgClauseNoTaxon("g.taxon_oid", 2)
        if ($gtype eq "metagenome");;

    my $sql = qq{
        select /*+ result_cache */ g.taxon_oid, g.gene_count
        from mv_taxon_ec_stat g
        where g.enzyme = ?
        $rclause
        $imgClause
        $taxonClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $ec_number );
    my @taxon_oids;
    for ( ; ; ) {
        my ( $taxon_oid, $cnt ) = $cur->fetchrow();
        last if !$taxon_oid;
        $mgr->setCount( $taxon_oid, $cnt );
        push( @taxon_oids, $taxon_oid );
    }
    $cur->finish();

    # MER-FS metagenomes
    if ( $include_metagenomes && $gtype eq "metagenome" ) {
        print "<p>Checking metagenomes ...<br/>\n";

        my %gene_func_count; 
        if ( $new_func_count ) { 
            my $sql3 = qq{
               select g.taxon_oid, g.gene_count
               from taxon_ec_count g
               where g.func_id = ?
               and g.gene_count > 0
               $rclause
               $imgClause
               $taxonClause
            };
            my $cur3 = execSql( $dbh, $sql3, $verbose, $ec_number ); 
            for ( ;; ) { 
                my ( $tid3, $cnt3 ) = $cur3->fetchrow(); 
                last if ! $tid3; 
 
                if ( $gene_func_count{$tid3} ) { 
                    $gene_func_count{$tid3} += $cnt3; 
                } else { 
                    $gene_func_count{$tid3} = $cnt3; 
                } 
            } 
            $cur3->finish(); 
        } 

	my $taxonClause1 = WebUtil::txsClause("t.taxon_oid", $dbh);
        $sql = MerFsUtil::getTaxonsInFileSql($taxonClause1);
	$sql .= " and t.genome_type = 'metagenome' ";
        $cur = execSql( $dbh, $sql, $verbose );
        my $cnt1 = 0;
        for ( ; ; ) {
            my ($t_oid) = $cur->fetchrow();
            last if !$t_oid;

            $cnt1++;
            if ( ( $cnt1 % 10 ) == 0 ) {
		print ". ";
	    }
            if ( ( $cnt1 % 1800 ) == 0 ) {
                print "<br/>\n";
            }

	    my $taxon_g_cnt = 0;
            if ( $new_func_count ) { 
                $taxon_g_cnt = $gene_func_count{$t_oid}; 
            } else { 
		$taxon_g_cnt = MetaUtil::getTaxonOneFuncCnt
		    ( $t_oid, "", $ec_number );
	    }
            if ($taxon_g_cnt) {
                $mgr->setCount( $t_oid, $taxon_g_cnt );
                push( @taxon_oids, $t_oid );
            }
        }
        $cur->finish();
        print "<br/>\n";
    }

    printEndWorkingDiv();

    if ($show_private) {
        require TreeQ;
        TreeQ::printAppletForm( \@taxon_oids );
    }

    print "<p>Enzyme: ";
    my $ec_name = enzymeName( $dbh, $ec_number );
    print "<i>".escHtml($ec_name)."</i>";
    if ( $gtype eq 'metagenome' ) {
        print "<br/>*Showing counts for metagenomes in genome cart only"
            if $taxonClause ne "";
        print "<br/>*Showing counts for all metagenomes"
            if $taxonClause eq "";
    } else {
        print "<br/>*Showing counts for isolate genomes in genome cart only"
            if $taxonClause ne "";
        print "<br/>*Showing counts for all isolate genomes"
            if $taxonClause eq "";
    }
    print "</p>";

    print "<p>\n";
    if ($taxonClause ne "") {
        print "(User selected genomes with hits are shown in "
            . "<font color=red>red</font>)<br/>\n";
    } else {
        print "(Hits are shown in <font color=red>red</font>)<br/>\n";
    }
    print "<br/>";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    $mgr->aggCount();
    print "<p>\n";
    print "<pre>\n";
    $mgr->printHtmlCounted();
    print "</pre>\n";
    print "</p>\n";

    printStatusLine( "Loaded.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printKpdKeggPathwayDetailGenes - Print list of genes for one genome
#   in a KEGG map.
############################################################################
sub printKpdKeggPathwayDetailGenes {
    my $pathway_oid = param("pathway_oid");
    my $ec_number   = param("ec_number");
    my $taxon_oid   = param("taxon_oid");

    printMainForm();
    print hiddenVar( 'taxon_oid', $taxon_oid );
    print hiddenVar( 'func_id',   $ec_number );

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    # get genome info
    my $rclause   = WebUtil::urClause("t.taxon_oid");
    my $imgClause = WebUtil::imgClause("t");
    my $sql       = qq{
        select t.taxon_oid, t.taxon_display_name, t.in_file 
        from taxon t where taxon_oid = ? 
        $rclause 
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ( $id2, $taxon_name, $in_file ) = $cur->fetchrow();
    $cur->finish();
    if ( !$id2 ) {
        #$dbh->disconnect();
        return;
    }

    my $gene_count = 0;
    if ( $in_file eq 'Yes' ) {
        # MER-FS
        print "<h1>Genome Genes with Enzyme</h1>\n";
        my $pathway_name = WebUtil::keggPathwayName( $dbh, $pathway_oid );
        my $subtitle = escHtml($taxon_name) . " with $ec_number in "
	    . "<i>" . escHtml($pathway_name) . ".</i>\n";
        print "<p>$subtitle\n";

        my $it = new InnerTable( 1, "ecGenes$$", "ecGenes", 1 );
        my $sd = $it->getSdDelim();
        $it->addColSpec( "Select" );
        $it->addColSpec( "Gene ID",    "asc", "right" );
        $it->addColSpec( "Gene Product Name", "asc", "left" );
        $it->addColSpec( "Genome Name",       "asc", "left" );

        my %genes = MetaUtil::getTaxonFuncGenes( $taxon_oid, '', $ec_number );
        my @gene_oids = ( keys %genes );
        for my $key (@gene_oids) {
            my $workspace_id = $genes{$key};
            my ( $tid, $dt, $id2 ) = split( / /, $workspace_id );

            my $row = $sd . "<input type='checkbox' name='gene_oid' value='$workspace_id' />\t";
            $row .=
                $workspace_id . $sd
              . "<a href='main.cgi?section=MetaGeneDetail"
              . "&page=metaGeneDetail&taxon_oid=$tid"
              . "&data_type=$dt&gene_oid=$key'>$key</a></td>\t";

            my ( $value, $source ) = 
		MetaUtil::getGeneProdNameSource( $key, $tid, $dt );
            $row .= $value . $sd . $value . "\t";
            $row .=
                $taxon_name . $sd
              . "<a href='main.cgi?section=MetaDetail"
              . "&page=metaDetail&taxon_oid=$tid'>$taxon_name</a></td>\t";

            $it->addRow($row);
            $gene_count++;
        }

        print "</p>\n";
        $it->printOuterTable(1);
        WebUtil::printButtonFooter();

        if ( $gene_count > 0 ) {
            MetaGeneTable::printMetaGeneTableSelect();

            print hiddenVar ( 'data_type', 'both' );
            WorkspaceUtil::printSaveGeneToWorkspace_withAllTaxonFuncGenes();
        }

        printStatusLine( "$gene_count gene(s) retrieved.", 2 );

    } else {
        $rclause = urClause("g.taxon");
        $sql     = qq{
            select distinct g.gene_oid
            from gene g, gene_ko_enzymes ge,
                 image_roi_ko_terms irkt, ko_term_enzymes kte,
                 image_roi roi
            where g.gene_oid = ge.gene_oid
            and ge.enzymes = kte.enzymes
            and ge.enzymes = ?
            and roi.roi_id = irkt.roi_id
            and irkt.ko_terms = kte.ko_id
            and roi.pathway = ?
            and g.taxon = ?
            and g.locus_type = 'CDS'
            and g.obsolete_flag = 'No'
            $rclause
         };
        my @gene_oids = HtmlUtil::fetchGeneList
	    ( $dbh, $sql, $verbose, $ec_number, $pathway_oid, $taxon_oid );

        my $taxon_display_name = WebUtil::genomeName( $dbh, $taxon_oid );
        my $pathway_name = WebUtil::keggPathwayName( $dbh, $pathway_oid );

        my $title    = "Genome Genes with Enzyme";
        my $subtitle = escHtml($taxon_display_name) . " with $ec_number in "
	    . "<i>" . escHtml($pathway_name) . "</i>\n";
        HtmlUtil::printGeneListHtmlTable($title, $subtitle, $dbh, \@gene_oids);
    }

    #$dbh->disconnect();
    print end_form();
}

############################################################################
# printKpdSelectScaffolds - Select scaffolds for scaffold profiler.
############################################################################
sub printKpdSelectScaffolds {
    my $pathway_oid = param("pathway_oid");

    my $dbh = dbLogin();
    printMainForm();

    print "<h1>Select KEGG Pathway Scaffolds</h1>\n";
    print "<p>\n";
    print "Select scaffolds for scaffold profiler.<br/>\n";
    print "Scaffolds > ${min_scaffold_length}bp are candidates.<br/>\n";
    my $keggName = WebUtil::keggPathwayName( $dbh, $pathway_oid );
    print "Scaffolds with genes in <i>" . escHtml($keggName) . "</i> are shown.<br/>\n";
    print "</p>\n";

    printStatusLine( "Loading ...", 1 );

    my $taxonClause = WebUtil::txsClause( "tx", $dbh );
    my $imgClause = WebUtil::imgClause("tx");
    my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("tx");
    my $sql = qq{
       select dgkmp.scaffold, s.scaffold_name, dgkmp.taxon,
              tx.taxon_display_name, ss.seq_length
       from dt_gene_ko_module_pwys dgkmp, scaffold_stats ss,
            scaffold s, taxon tx
       where ss.seq_length > ?
       and dgkmp.pathway_oid = ?
       and dgkmp.scaffold = ss.scaffold_oid
       and dgkmp.scaffold = s.scaffold_oid
       and dgkmp.taxon = tx.taxon_oid
       $taxonClause
       $rclause
       $imgClause
       order by tx.taxon_display_name, ss.seq_length desc
    };

    my @bindList = ( $min_scaffold_length, $pathway_oid );
    if ( scalar(@bindList_ur) > 0 ) {
        push( @bindList, @bindList_ur );
    }

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my $count = 0;
    my @recs;
    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name, $taxon_oid, $taxon_display_name, $seq_length ) = $cur->fetchrow();
        last if !$scaffold_oid;
        $count++;
        my $r = "$scaffold_oid\t";
        $r .= "$scaffold_name\t";
        $r .= "$taxon_oid\t";
        $r .= "$taxon_display_name\t";
        $r .= "$seq_length\t";
        push( @recs, $r );
    }
    if ( $count == 0 ) {
        print "<p>\n";
        print "No scaffolds found for the current context.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }
    my $count = 0;
    my $it    = new InnerTable( 1, "ko$$", "ko", 1 );
    my $sd    = $it->getSdDelim(); # sort delimiter
    $it->addColSpec( "Select" );
    $it->addColSpec( "Scaffold Name",            "asc",  "left" );
    $it->addColSpec( "Sequence<br/>Length (bp)", "desc", "right" );

    my $old_taxon_oid;
    for my $r (@recs) {
        $count++;
        my ( $scaffold_oid, $scaffold_name, $taxon_oid, $taxon_display_name, $seq_length ) = split( /\t/, $r );

        my $r   = $sd . "<input type='checkbox' name='scaffold_oid' value='$scaffold_oid' />\t";
        my $url = "$main_cgi?section=ScaffoldGraph&page=scaffoldGraph";
        $url .= "&scaffold_oid=$scaffold_oid";
        $url .= "&start_coord=1";
        my $end_coord = $scaffold_page_size;
        $end_coord = $seq_length if $seq_length < $scaffold_page_size;
        $url .= "&end_coord=$end_coord";
        $url .= "&seq_length=$seq_length";
        $scaffold_name =~ s/'|\[|\]//g;    #'
        $r .= $scaffold_name . $sd . alink( $url, $scaffold_name ) . "\t";
        $r .= $seq_length . $sd . $seq_length . "\t";
        $old_taxon_oid = $taxon_oid;
        $it->addRow($r);
    }
    $cur->finish();
    $it->printOuterTable(1);

    print hiddenVar( "pathway_oid", $pathway_oid );

    my $name = "_section_${section}_kpdViewScaffoldProfile";
    print submit(
                  -name  => $name,
                  -value => "Continue",
                  -class => "smdefbutton"
    );
    print nbsp(1);
    print reset( -name => "Reset", -value => "Reset", -class => "smbutton" );

    printStatusLine( "$count scaffold(s) retrieved.", 2 );
    print end_form();
    #$dbh->disconnect();
}

############################################################################
# printKpdScaffoldProfile - Show COG category profile.
############################################################################
sub printKpdScaffoldProfile {
    my $pathway_oid = param("pathway_oid");

    my @scaffold_oids = param("scaffold_oid");
    my $scaffold_selection_str = join( ',', @scaffold_oids );
    if ( blankStr($scaffold_selection_str) ) {
        webError("Please select scaffolds for profiling.");
    }
    my $nScaffolds = @scaffold_oids;
    if ( $nScaffolds < 1 ) {
        webError("Please select at least one scaffold.");
    }
    if ( $nScaffolds > $max_scaffold_batch ) {
        webError( "Please select from one to a maximum of " . "$max_scaffold_batch scaffolds." );
    }
    my $dbh = dbLogin();

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<h1>KEGG Scaffold Profile</h1>\n";

    my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $sql       = qq{
        select scf.scaffold_oid, scf.scaffold_name
        from scaffold scf, taxon tx
        where scf.scaffold_oid in( $scaffold_selection_str )
        and scf.taxon = tx.taxon_oid
        $rclause
        $imgClause
        order by tx.domain, tx.phylum, tx.ir_class, tx.ir_order,
                 tx.family, tx.genus, tx.taxon_display_name
    };

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    my @scaffoldRecs;
    for ( ; ; ) {
        my ( $scaffold_oid, $scaffold_name ) = $cur->fetchrow();
        last if !$scaffold_oid;
        my $r = "$scaffold_oid\t";
        $r .= "$scaffold_name\t";
        push( @scaffoldRecs, $r );
    }
    $cur->finish();

    my ( $rclause, @bindList_ur ) = WebUtil::urClauseBind("g.taxon");
    my $imgClause = WebUtil::imgClauseNoTaxon("g.taxon");
    my $sql       = qq{
        select ez.ec_number, ez.enzyme_name, g.scaffold,
               count( distinct g.gene_oid )
        from gene g, gene_ko_enzymes ge, 
             image_roi_ko_terms irkt, ko_term_enzymes kte, image_roi roi,
             enzyme ez, kegg_pathway pw
       where pw.pathway_oid = ?
         and pw.pathway_oid = roi.pathway
         and roi.roi_id = irkt.roi_id
         and irkt.ko_terms = kte.ko_id
         and kte.enzymes = ez.ec_number
         and kte.enzymes = ge.enzymes
         and ge.gene_oid = g.gene_oid
         and g.scaffold in( $scaffold_selection_str )
         and g.locus_type = ? 
         and g.obsolete_flag = ? 
         $rclause
         $imgClause
         group by ez.ec_number, ez.enzyme_name, g.scaffold
         order by ez.ec_number, ez.enzyme_name, g.scaffold
    };

    my @bindList = ( $pathway_oid, 'CDS', 'No' );
    if ( scalar(@bindList_ur) > 0 ) {
        push( @bindList, @bindList_ur );
    }

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my %ecScaffold2GeneCount;
    for ( ; ; ) {
        my ( $ec_number, $enzyme_name, $scaffold_oid, $cnt ) = $cur->fetchrow();
        last if !$ec_number;
        my $k = "$ec_number\t$scaffold_oid";
        $ecScaffold2GeneCount{$k} = $cnt;
    }
    $cur->finish();

    my @colSpec;
    push(
          @colSpec,
          {
             displayColName => "EC Number",
             sortSpec       => "char asc",
             align          => "left",
          }
    );
    push(
          @colSpec,
          {
             displayColName => "Enzyme Name",
             sortSpec       => "char asc",
             align          => "left",
          }
    );
    for my $r (@scaffoldRecs) {
        my ( $scaffold_oid, $scaffold_name ) = split( /\t/, $r );
        my $colName = abbrScaffoldName( $scaffold_oid, $scaffold_name, 1 );

        push(
              @colSpec,
              {
                 displayColName => $colName,
                 sortSpec       => "number desc",
                 align          => "right",
                 title          => $scaffold_name,
                 useColorMap    => 1,
              }
        );
    }
    my $baseUrl = "$section_cgi&kpdViewScaffoldProfile=1";
    $baseUrl .= "&pathway_oid=$pathway_oid";
    for my $scaffold_oid (@scaffold_oids) {
        $baseUrl .= "&scaffold_oid=$scaffold_oid";
    }
    my @colorMap = ( "1:5:bisque", "5:1000000:yellow", );

    my $cachedTable = new CachedTable( "keggScaffolds$pathway_oid", $baseUrl );
    my $sdDelim = CachedTable::getSdDelim();
    $cachedTable->addColSpec( "EC Number", "asc", "left" );
    $cachedTable->addColSpec( "EC Name",   "asc", "left" );
    for my $r (@scaffoldRecs) {
        my ( $scaffold_oid, $scaffold_name ) = split( /\t/, $r );
        my $colName = abbrScaffoldName( $scaffold_oid, $scaffold_name, 1 );
        $cachedTable->addColSpec( $colName, "desc", "right", "", $scaffold_name );
    }

    my $sql = qq{
       select ez.ec_number, ez.enzyme_name
       from image_roi_ko_terms irkt, ko_term_enzymes kte,
            image_roi roi, enzyme ez, kegg_pathway pw
       where pw.pathway_oid = ?
       and pw.pathway_oid = roi.pathway
       and roi.roi_id = irkt.roi_id
       and irkt.ko_terms = kte.ko_id
       and kte.enzymes = ez.ec_number
       group by ez.ec_number, ez.enzyme_name
       order by ez.ec_number, ez.enzyme_name
    };
    my $cur   = execSql( $dbh, $sql, $verbose, $pathway_oid );
    my $count = 0;

    # YUI tables look better with more vertical padding:
    my $vPadding = 4;

    for ( ; ; ) {
        my ( $ec_number, $enzyme_name, $cnt ) = $cur->fetchrow();
        last if !$ec_number;
        $count++;
        my $r = $ec_number . $sdDelim . "$ec_number\t";
        $r .= $enzyme_name . $sdDelim . "$enzyme_name\t";
        for my $scaffoldRec (@scaffoldRecs) {
            my ( $scaffold_oid, $scaffold_name ) = split( /\t/, $scaffoldRec );
            my $k   = "$ec_number\t$scaffold_oid";
            my $cnt = $ecScaffold2GeneCount{$k};
            $cnt = 0 if $cnt eq "";
            my $color = "white";
            $color = "bisque" if $cnt >= 1 && $cnt < 5;
            $color = "yellow" if $cnt >= 5;

            if ( $cnt > 0 ) {
                my $url = "$section_cgi&page=kpdKeggScaffoldGenes";
                $url .= "&pathway_oid=$pathway_oid";
                $url .= "&ec_number=$ec_number";
                $url .= "&scaffold_oid=$scaffold_oid";

                $r .=
                    $cnt . $sdDelim
                  . "<span style='background-color:$color;padding:${vPadding}px 10px;'>"
                  . alink( $url, $cnt )
                  . "</span>\t";
            } else {
                $r .= "0$sdDelim" . "<span style='padding:${vPadding}px 10px;'>" . "0</span>\t";
            }
        }
        $cachedTable->addRow($r);
    }
    $cur->finish();

    if ( $count == 0 ) {
        print "<p>\n";
        print "No enzymes match the profile.\n";
        print "</p>\n";
        printStatusLine( "Loaded.", 2 );
        return;
    }
    print "<p>\n";
    my $keggName = WebUtil::keggPathwayName( $dbh, $pathway_oid );
    print "KEGG profile for <i>" . escHtml($keggName) . "</i> with $nScaffolds scaffolds.\n";
    print "<br/>\n";
    print "The count of genes is shown under the genome abbreviation.<br/>\n";
    print "(Larger numbers have brighter cell coloring.)<br/>\n";
    print "</p>\n";

    printHint("Mouse over scaffold abbreviation to see scaffold name.");
    print "<br/>";
    $cachedTable->printTable();
    #$dbh->disconnect();

    my $url = "$section_cgi&page=keggPathwayDetail&pathway_oid=$pathway_oid";
    print buttonUrl( $url, "Return to KEGG Pathway Detail", "lgbutton" );
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printKpdKeggScaffoldGenes - Show cog category genes.
############################################################################
sub printKpdKeggScaffoldGenes {
    my $pathway_oid  = param("pathway_oid");
    my $ec_number    = param("ec_number");
    my $scaffold_oid = param("scaffold_oid");

    my $dbh = dbLogin();
    my $sql = qq{
       select distinct g.gene_oid, g.gene_display_name 
       from gene g, gene_ko_enzymes ge, 
            image_roi_ko_terms irkt, ko_term_enzymes kte, image_roi roi,
            enzyme ez, kegg_pathway pw
       where pw.pathway_oid = ?
       and pw.pathway_oid = roi.pathway
       and roi.roi_id = irkt.roi_id
       and irkt.ko_terms = kte.ko_id
       and kte.enzymes = ez.ec_number
       and kte.enzymes = ge.enzymes
       and ge.enzymes = ?
       and g.scaffold = ?
       and ge.gene_oid = g.gene_oid
       and g.locus_type = 'CDS'
       and g.obsolete_flag = 'No'
       order by g.gene_display_name
   };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_oid, $ec_number, $scaffold_oid );
    my @gene_oids;
    for ( ; ; ) {
        my ( $gene_oid, $gene_display_name ) = $cur->fetchrow();
        last if !$gene_oid;
        push( @gene_oids, $gene_oid );
    }
    $cur->finish();

    my $count = scalar(@gene_oids);
    if ( $count == 1 ) {
        GeneDetail::printGeneDetail( $gene_oids[0] );
        return;
    }

    printMainForm();
    printStatusLine( "Loading ...", 1 );

    print "<h1>Genes for $ec_number</h1>\n";
    printGeneCartFooter() if $count > 10;
    HtmlUtil::flushGeneBatch( $dbh, \@gene_oids );
    printGeneCartFooter();

    printStatusLine( "$count gene(s) retrieved.", 2 );
    print end_form();
}

#########################################################################
# printKeggCpdList
#########################################################################
sub printKeggCpdList {
    print "<h1>KEGG Compound List</h1>\n";
 
    printStatusLine( "loading ...", 1 );
 
    my $dbh   = dbLogin(); 
    my $sql = qq{
        select ext_accession, compound_name, cas_number, formula, class 
        from img_compound
    };
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my $count = 0; 
 
    my $it = new InnerTable( 1, "kegg_cpd$$", "kegg_cpd", 1 ); 
    my $sd = $it->getSdDelim();    # sort delimiter                                                                          
    $it->addColSpec( "Compound ID",   "char asc", "left" ); 
    $it->addColSpec( "Compound Name", "char asc", "left" );
    $it->addColSpec( "CAS Number", "char asc", "left" );
    $it->addColSpec( "Formula", "char asc", "left" );
    $it->addColSpec( "Class", "char asc", "left" );
    $it->addColSpec( "KEGG URL", "char asc", "left" );

    for (;;) { 
        my ( $id2, $name, $cas, $formula, $class )
            = $cur->fetchrow(); 
        last if ( ! $id2 );
 
        my $r = ""; 
        my $url = "main.cgi?section=KeggPathwayDetail&page=compound&ext_accession=$id2";
        $r .= $id2 . $sd . alink($url, $id2) . "\t"; 
        $r .= $name . $sd . $name . "\t"; 
	$r .= $cas . $sd . $cas . "\t"; 
 
        $r .= $formula . $sd . $formula . "\t";
        $r .= $class . $sd . $class . "\t";

        my $url2 = "http://www.kegg.jp/entry/" . $id2;
        $r .= $id2 . $sd . alink($url2, $id2) . "\t"; 
 
        $it->addRow($r); 
 
        $count++; 
    }
 
    $it->printOuterTable(1); 
    $cur->finish(); 
 
    printStatusLine( "$count Loaded.", 2 );
 
    print end_form(); 
} 

#########################################################################
# printKeggCompound
#########################################################################
sub printKeggCompound {
    my $compound_id = param("ext_accession");
    my $taxon_oid = param("taxon_oid");

    if ( ! $compound_id ) {
        return; 
    }

    print "<h1>Kegg Compound Detail</h1>\n";

    my $dbh   = dbLogin(); 
    my $sql = qq{
        select ext_accession, compound_name, cas_number, formula, class 
        from img_compound
        where ext_accession = ? 
    };
    my $cur = execSql( $dbh, $sql, $verbose, $compound_id ); 
    my ( $id2, $name, $cas, $formula, $class )
        = $cur->fetchrow(); 
    $cur->finish(); 
 
    print "<table class='img' border='1'>\n";
    my $url2 = "http://www.kegg.jp/entry/" . $id2;
    printAttrRowRaw( "Ext Accession", alink($url2, $compound_id) );

    if ( $name ) { 
        printAttrRowRaw( "Compound Name", $name );
    }
    if ( $cas ) { 
        printAttrRowRaw( "CAS Number", $cas );
    }
    if ( $formula ) { 
        printAttrRowRaw( "Formula", $formula ); 
    } 
    if ( $class ) { 
        printAttrRowRaw( "Class", $class ); 
    } 

    # alias
    my $alias = ""; 
    $sql = "select ext_accession, aliases from compound_aliases " .
        "where ext_accession = ?";
    $cur = execSql( $dbh, $sql, $verbose, $compound_id);
    for (;;) { 
        my ( $id2, $name2 ) = $cur->fetchrow();
        last if ! $id2;
 
        if ( ! $name2 ) {
            next; 
        } 
 
        if ( $alias ) { 
            $alias .= "<br/>" . $name2;
        } 
        else { 
            $alias = $name2;
        }
    } 
    $cur->finish(); 
    if ( $alias ) { 
        printAttrRowRaw( "Aliases", $alias );
    } 

    # in reactions and pathways
    my %pwy_h; 
    my $in_rxn = ""; 
    $sql = qq{
        select r.ext_accession, r.rxn_name, r.rxn_definition, r.rxn_equation,
               kpm.pathway_oid, p.pathway_name
        from reaction r, reaction_compounds rc,
             kegg_module_reactions kmr, kegg_pathway_modules kpm,
             kegg_pathway p
        where rc.compounds = ?
        and rc.ext_accession = r.ext_accession
        and r.ext_accession = kmr.reactions
        and kmr.module_id = kpm.modules
        and kpm.pathway_oid = p.pathway_oid
        };
    $cur = execSql( $dbh, $sql, $verbose, $compound_id );
    for (;;) { 
        my ( $id2, $rxn_name, $rxn_def, $rxn_eqn, $pwy_id, $pwy_name ) =
            $cur->fetchrow();
        last if ! $id2;
 
        my $url2 = "main.cgi?section=MetaCyc&page=reaction&unique_id=$id2";
        if ( $taxon_oid ) {
            $url2 .= "&taxon_oid=$taxon_oid"; 
        } 
#        my $rxn = "(" . $side . ") " . alink($url2, $id2); 
#	my $rxn = $id2 . ", " . $rxn_name . ", " . $rxn_def . ", " . $rxn_eqn;
	my $rxn = $id2;
	if ( $rxn_name ) {
	    $rxn .= " (" . $rxn_name . ")";
	}
	$rxn .= ": " . $rxn_def;

        if ( $in_rxn ) { 
            $in_rxn .= "<br/>" . $rxn; 
        } 
        else { 
            $in_rxn = $rxn; 
        } 
 
        if ( $pwy_id ) { 
            if ( $pwy_name ) {
                $pwy_h{$pwy_id} = $pwy_name; 
            } 
            else { 
                $pwy_h{$pwy_id} = $pwy_id;
            } 
        } 
    } 
    $cur->finish();
    if ( $in_rxn ) { 
        printAttrRowRaw( "In Reaction(s)", $in_rxn );
    } 
 
    if ( scalar(keys %pwy_h) > 0 ) {
        my $in_pwy = ""; 
        for my $pid (keys %pwy_h) {
            my $url3 = "main.cgi?section=KeggPathwayDetail" .
		"&page=keggPathwayDetail&pathway_oid=$pid";
            if ( $taxon_oid ) {
                $url3 .= "&taxon_oid=$taxon_oid";
            } 
 
            if ( $in_pwy ) {
                $in_pwy .= "<br/>" . alink($url3, $pid); 
            } 
            else { 
                $in_pwy = alink($url3, $pid);
            } 
            $in_pwy .= " (" . $pwy_h{$pid} . ")";
        }
        printAttrRowRaw( "In Pathway(s)", $in_pwy );
    } 

    # IMG compound
    my $img_compound = ""; 
    $sql = "select compound_oid, compound from img_compound_kegg_compounds " .
        "where compound = ?";
    $cur = execSql( $dbh, $sql, $verbose, $compound_id);
    for (;;) { 
        my ( $id2, $id3 ) = $cur->fetchrow();
        last if ! $id2;
 
        my $url2 = "main.cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$id2";
        if ( $img_compound ) { 
            $img_compound .= "<br/>" . alink($url2, $id2);
        } 
        else { 
            $img_compound = alink($url2, $id2);
        }
    } 
    $cur->finish(); 
    if ( $img_compound ) { 
        printAttrRowRaw( "IMG Compound", $img_compound );
    } 

    # ext link
    my $ext_link = ""; 
    $sql = "select ext_accession, db_name, id from compound_ext_links "
         . "where ext_accession = ?";
    $cur = execSql( $dbh, $sql, $verbose, $compound_id);
    for ( ;; ) { 
        my ( $id2, $db3, $id3 ) = $cur->fetchrow();
        last if ! $id2;

	if ( lc($db3) eq 'chebi' || lc($db3) eq 'pubchem' ) {
	    my @ids = split(/ /, $id3);
	    my $id_list = "";
	    for my $id4 ( @ids ) {
		if ( ! $id4 ) {
		    next;
		}

		my $url4 = "";
		if ( lc($db3) eq 'chebi' ) {
		    $id4 = "CHEBI:" . strTrim($id4);
		    $url4 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" . $id4;
		}
		elsif ( lc($db3) eq 'pubchem' ) {
		    $url4 = $pubchem_base_url . $id4;
		}

		my $c_id = $id4;
		if ( $url4 ) {
		    $c_id = alink($url4, $id4);
		}

		if ( $id_list ) {
		    $id_list .= " " . $c_id;
		}
		else {
		    $id_list = $c_id;
		}
	    }
	    if ( $id_list ) {
		printAttrRowRaw( $db3,$id_list );
	    }
	}
	else {
	    printAttrRowRaw( $db3, $id3 );
	}
    } 
    $cur->finish(); 

    print "</table>\n"; 
 
    print end_form();
}



1;

