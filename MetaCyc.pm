###########################################################################
#
# $Id: MetaCyc.pm 32375 2014-12-03 20:49:53Z jinghuahuang $
#
package MetaCyc;

use strict;
use CGI qw( :standard );
use Data::Dumper;
use DBI;
use WebUtil;
use WebConfig;
use InnerTable;
use TaxonDetailUtil;
use HtmlUtil;
use MetaCycNode;
use MetaUtil;

$| = 1;
my $section = "MetaCyc";
my $env          = getEnv();
my $cgi_dir      = $env->{cgi_dir};
my $cgi_url      = $env->{cgi_url};
my $main_cgi     = $env->{main_cgi};
my $inner_cgi    = $env->{inner_cgi};
my $tmp_url      = $env->{tmp_url};
my $verbose      = $env->{verbose};
my $web_data_dir = $env->{web_data_dir};
my $img_internal = $env->{img_internal};
my $cgi_tmp_dir  = $env->{cgi_tmp_dir};
my $enzyme_base_url    = $env->{enzyme_base_url};
my $metacyc_url  = $env->{metacyc_url};
my $include_metagenomes  = $env->{include_metagenomes};

my $metacycURL = "http://biocyc.org/META/NEW-IMAGE?object=";
if ( $metacyc_url ne "" ) {
    $metacycURL = $metacyc_url;
}

my $pubchem_base_url  = $env->{pubchem_base_url};
if ( ! $pubchem_base_url ) {
    $pubchem_base_url = "http://pubchem.ncbi.nlm.nih.gov/summary/summary.cgi?cid=";
}

my $detailURL = "$main_cgi?section=MetaCyc&page=detail&pathway_id=";

my $YUI = $env->{yui_dir_28};

my $nvl = getNvl();

my $maxGeneListResults = 1000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
} 

sub dispatch {
    my $page     = param("page");
    my $database = getRdbms();
    if ( $page eq "detail" ) {
        printPathwayEC();
    } elsif ( $page eq "gene" ) {
        printGeneList();
    } elsif ( $page eq "reaction" ) {
        printMetaCycReaction();
    } elsif ( $page eq "cpdList" ) {
        printMetaCycCpdList();
    } elsif ( $page eq "compound" ) {
        printMetaCycCompound();
    } elsif ( $page eq "tree" ) {

        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;

        #printTree();
        if ( $database eq "mysql" ) {
            buildCatNodes2();
        } else {
            buildCatNodes();
        }

        HtmlUtil::cgiCacheStop();
    } elsif ( $page eq "tree2" ) {
        buildCatNodes2();
    } else {

        my $sid = 0;
        HtmlUtil::cgiCacheInitialize( $section);
        HtmlUtil::cgiCacheStart() or return;    

        #printList();
        if ( $database eq "mysql" ) {
            buildCatNodes2();
        } else {
            buildCatNodes();
        }
        
        HtmlUtil::cgiCacheStop();
    }
}

sub getPathwayName {
    my ( $dbh, $pathway_id ) = @_;

    my $sql = qq{
        select common_name
        from biocyc_pathway
        where unique_id = ?
    };

    my @a      = ($pathway_id);
    my $cur    = WebUtil::execSqlBind( $dbh, $sql, \@a, $verbose );
    my ($name) = $cur->fetchrow();
    $cur->finish();
    return $name;
}

sub printList {

    print "<h1>MetaCyc Pathways</h1>\n";

    print qq{
        <p>
        <a href='main.cgi?section=MetaCyc&page=tree'> View as Tree</a>
        </p>
   };

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $sql = qq{
select distinct p1.unique_id, p2.types, $nvl(p1.common_name, 'n/a') 
from biocyc_pathway p1, biocyc_pathway_types p2
where p1.unique_id = p2.unique_id
order by lower(p2.types), 3
    };

    print "<p>\n";

    my $cur = execSql( $dbh, $sql, $verbose );
    my %count;
    my %cat_count;
    my $tmp = 0;

    my $old_type;
    for ( ; ; ) {
        my ( $unique_id, $type, $common_name ) = $cur->fetchrow();
        last if !$unique_id;
        $count{$unique_id} = "";
        $cat_count{$type}  = "";
        $tmp++;
        if ( lc($old_type) ne lc($type) ) {
            print "<br/>\n" if $tmp > 1;
            print "<b>\n";
            print $type;
            print "</b>\n";
            print "<br/>\n";
        }
        print nbsp(4);
        my $url =
          "$main_cgi?section=MetaCyc" . "&page=detail&pathway_id=$unique_id";

        # metacyc has html code in the name to make it look nice for display
        #if ( $unique_id =~ /^PWY/ ) {
        print "<a href='$url'>$common_name</a><br/>\n ";

        #} else {
        #print "$common_name<br/>\n ";
        #}

        #print alink( $url, $common_name ) . "<br/>\n";

        $old_type = $type;

    }

    $cur->finish();
    #$dbh->disconnect();

    print "</p>\n";
    my $tmp1 = keys %count;
    my $tmp2 = keys %cat_count;
    printStatusLine( "$tmp1 pathways ($tmp2 types) .", 2 );
}

sub printGeneList {
    my $pathway_id = param("unique_id");
    my $ec_number  = param("ec_number");
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");

    print "<h1>MetaCyc Pathway Gene List</h1>\n";

    #printStatusLine( "Loading ...", 1 );
    my $dbh = dbLogin();
    my $pname = getPathwayName( $dbh, $pathway_id );
    my $url = $metacycURL . escHtml("$pathway_id");

    print qq{
        <p>
        <a href='$url'> <b>$pname</b> </a><br/>
        $ec_number
        </p>
    };

    my $in_file = "No";
    my $taxon_name = $taxon_oid;
    if ( $taxon_oid ) {
	my $rclause   = WebUtil::urClause('t.taxon_oid');
	my $sql = "select t.taxon_oid, t.taxon_display_name, t.in_file " .
	    "from taxon t where t.taxon_oid = ? $rclause ";
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	my ($tid2, $tname, $in_f) = $cur->fetchrow();
	$cur->finish();
	$taxon_name = $tname;

	if ( ! $tid2 ) {
	    $taxon_oid = 0;
	}
	else {
	    $in_file = $in_f;
	}

	my $taxon_name = WebUtil::genomeName($dbh, $taxon_oid);
	my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid"; 
	print "<p>Genome $taxon_oid: " . alink($taxon_url, $taxon_name) . "</p>\n";
    }

    my %bc_gene_h;
    if ( $cluster_id ) {
	my $url2 = "$main_cgi?section=BiosyntheticDetail" .
	    "&page=cluster_detail&taxon_oid=$taxon_oid" .
	    "&cluster_id=$cluster_id"; 
	print "<p>Cluster ID: " . alink($url2, $cluster_id); 
	print "</p>"; 

	my $sql = "select feature_id from bio_cluster_features_new " .
	    "where cluster_id = ? and feature_type = 'gene'";
	my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
	for (;;) {
	    my ($gene_id) = $cur->fetchrow();
	    last if ! $gene_id;
	    $bc_gene_h{$gene_id} = 1;
	}
	$cur->finish();
    }

    my @gene_oids = ();
    if ( $in_file eq 'Yes' && $taxon_oid ) {
	for my $data_type ( 'assembled', 'unassembled' ) {
	    if ( $cluster_id && $data_type eq 'unassembled' ) {
		next;
	    }

	    my %gene1 = MetaUtil::getTaxonFuncGenes($taxon_oid, $data_type, $ec_number);
	    for my $key (keys %gene1) {
		if ( $cluster_id && ! $bc_gene_h{$key} ) {
		    next;
		}
		my $workspace_id = "$taxon_oid $data_type $key";
		push @gene_oids, ( $workspace_id );
	    }
	}
    }
    else {
	my $rclause   = WebUtil::urClause('g.taxon');
	my $sql = qq{
            select distinct g.gene_oid
            from biocyc_pathway bp, biocyc_reaction_in_pwys brp,
            biocyc_reaction br, gene_biocyc_rxns g
            where bp.unique_id = brp.in_pwys
            $rclause
            and brp.unique_id = br.unique_id
            and br.unique_id = g.biocyc_rxn
            and br.ec_number = g.ec_number
            and bp.unique_id = ?
            and g.ec_number = ?
            and br.ec_number = g.ec_number
            };

	if ( $taxon_oid ) {
	    $sql .= " and g.taxon = $taxon_oid ";
	}
	my $cur = execSql( $dbh, $sql, $verbose, $pathway_id, $ec_number );
	for (;;) {
	    my ($gene_oid) = $cur->fetchrow();
	    last if ! $gene_oid;

	    if ( $cluster_id && ! $bc_gene_h{$gene_oid} ) {
		next;
	    }
	    push @gene_oids, ( $gene_oid );
	}
	$cur->finish();
    }
    #$dbh->disconnect();

    if ( $in_file eq 'Yes' ) {
	my $it = new InnerTable( 1, "geneSet$$", "geneSet", 1 );
	$it->addColSpec( "Select" ); 
	$it->addColSpec( "Gene ID", "asc", "left" );
	$it->addColSpec( "Locus Tag", "asc", "left" );
	$it->addColSpec( "Gene Product Name", "asc", "left" );
	$it->addColSpec( "Genome Name", "asc", "left" );
	my $sd = $it->getSdDelim(); 
	my $cnt = 0;
	for my $gene_oid ( @gene_oids ) {
	    my ($t2, $d2, $locus_tag) = split(/ /, $gene_oid);
	    my $r = $sd . "<input type='checkbox' name='gene_oid' "
		. "value='$gene_oid' /> \t";
	    my $url = "$main_cgi?section=MetaGeneDetail"
                . "&page=geneDetail&gene_oid=$locus_tag"
                . "&taxon_oid=$taxon_oid&data_type=assembled";
	    $r .= $locus_tag . $sd . alink( $url, $locus_tag ) . "\t";
	    $r .= $locus_tag . $sd . $locus_tag . "\t";
	    my $gene_name = $locus_tag;
            my ($n2, $src2) = MetaUtil::getGeneProdNameSource($locus_tag,
                                                              $t2,
                                                              'assembled');
            if ( $n2 ) {
                $gene_name = $n2; 
            } 
            else { 
                $gene_name = 'hypothetical protein';
	    }
	    $r .= $gene_name . $sd . $gene_name . "\t"; 
	    my $t_url = "$main_cgi?section=MetaDetail" .
		"&page=metaDetail&taxon_oid=$taxon_oid";
	    $r .= $taxon_name . $sd . alink($t_url, $taxon_name) . "\t";
	    $it->addRow($r);
	    $cnt++;
	}

	if ( $cnt ) {
	    printMainForm();
	    $it->printOuterTable(1);
	    WebUtil::printGeneCartFooter();
	    print end_form();
	}
    }
    else {
	TaxonDetailUtil::printGeneListSectionSortingNoSql(\@gene_oids, "");
    }

#    my ($cnt, $s) = TaxonDetailUtil::printGeneListSectionSorting( $sql, "", "",  
#								  $pathway_id, $ec_number );
}

sub printPathwayEC {
    my $pathway_id = param("pathway_id");
    my $taxon_oid = param("taxon_oid");
    my $cluster_id = param("cluster_id");

    print "<h1>MetaCyc Pathway Details</h1>\n";

    printStatusLine( "Loading ...", 1 );
    my $dbh   = dbLogin();
    my $pname = getPathwayName( $dbh, $pathway_id );

    my $url = $metacycURL . escHtml("$pathway_id");

    print qq{
        <p>
        <a href='$url'> <b>$pname</b> </a>
        </p>
    };

    my $genome_type = "";
    my $in_file = "No";
    my %iso_cnt_h;
    my %meta_cnt_h;
    my %bc_cnt_h;

    printMainForm();

    if ( $taxon_oid ) {
	my $rclause   = WebUtil::urClause('t.taxon_oid');
	my $sql = qq{
              select t.taxon_oid, t.taxon_display_name, t.genome_type, t.in_file
              from taxon t
              where t.taxon_oid = ? 
              $rclause
              };
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid);
	my ($tid2, $taxon_name, $g_type, $in_f) = $cur->fetchrow();
	$cur->finish();

	if ( ! $tid2 ) {
	    $dbh->disconnect();
	    print end_form();
	    return;
	}

	my $taxon_url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid"; 
	print "<p>Genome $taxon_oid: " . alink($taxon_url, $taxon_name) . "</p>\n";

	$genome_type = $g_type;
	$in_file = $in_f;
    }

    if ( $cluster_id ) {
	my $url2 = "$main_cgi?section=BiosyntheticDetail" .
	    "&page=cluster_detail&taxon_oid=$taxon_oid" .
	    "&cluster_id=$cluster_id"; 
	print "<p>Cluster ID: " . alink($url2, $cluster_id); 
	print "</p>"; 
    }

    my %rxn_name_h;
    my %rxn_ec_h;
    my %rxn_left_h;
    my %rxn_right_h;
    my $sql = qq{
        select br.unique_id, br.common_name, br.ec_number,
               left.substrate, bc.unique_id, bc.common_name
        from biocyc_reaction_in_pwys brp, 
            biocyc_reaction br, biocyc_reaction_left_hand left,
            biocyc_comp bc
        where brp.in_pwys = ?
        and brp.unique_id = br.unique_id
        and brp.unique_id = left.unique_id
        and left.substrate = bc.unique_id (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_id );
    for ( ; ; ) {
        my ( $id1, $rxn_name, $enzyme, $id2, $bc_id, $name ) = $cur->fetchrow();
        last if !$id1;

	if ( $rxn_name ) {
	    $rxn_name_h{$id1} = $rxn_name;
	}
	else {
	    $rxn_name_h{$id1} = "-";
	}

	$rxn_ec_h{$id1} = $enzyme;

	my $url2 = "main.cgi?section=MetaCyc&page=compound&unique_id=$bc_id";
	if ( $taxon_oid ) {
	    $url2 .= "&taxon_oid=$taxon_oid";
	}
	if ( ! $name ) {
	    $name = $id2;
	}

	if ( $rxn_left_h{$id1} ) {
	    if ( $bc_id ) {
		$rxn_left_h{$id1} .= " + " . alink($url2, $name, "", 1);
	    }
	    else {
		$rxn_left_h{$id1} .= " + " . $name;
	    }
	}
	else {
	    if ( $bc_id ) {
		$rxn_left_h{$id1} = alink($url2, $name, "", 1);
	    }
	    else {
		$rxn_left_h{$id1} = $name;
	    }
	}
    }
    $cur->finish();

    my $sql = qq{
        select br.unique_id, br.common_name, br.ec_number,
               right.substrate, bc.unique_id, bc.common_name
        from biocyc_reaction_in_pwys brp, 
            biocyc_reaction br, biocyc_reaction_right_hand right,
            biocyc_comp bc
        where brp.in_pwys = ?
        and brp.unique_id = br.unique_id
        and brp.unique_id = right.unique_id
        and right.substrate = bc.unique_id (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_id );
    for ( ; ; ) {
        my ( $id1, $rxn_name, $enzyme, $id2, $bc_id, $name ) = $cur->fetchrow();
        last if !$id1;

	if ( $rxn_name ) {
	    $rxn_name_h{$id1} = $rxn_name;
	}
	else {
	    $rxn_name_h{$id1} = "-";
	}

	$rxn_ec_h{$id1} = $enzyme;

	my $url2 = "main.cgi?section=MetaCyc&page=compound&unique_id=$bc_id";
	if ( $taxon_oid ) {
	    $url2 .= "&taxon_oid=$taxon_oid";
	}
	if ( ! $name ) {
	    $name = $id2;
	}

	if ( $rxn_right_h{$id1} ) {
	    if ( $bc_id ) {
		$rxn_right_h{$id1} .= " + " . alink($url2, $name, "", 1);
	    }
	    else {
		$rxn_right_h{$id1} .= " + " . $name;
	    }
	}
	else {
	    if ( $bc_id ) {
		$rxn_right_h{$id1} = alink($url2, $name, "", 1);
	    }
	    else {
		$rxn_right_h{$id1} = $name;
	    }
	}
    }
    $cur->finish();
    print "<p>\n";

    print "<h2>Reactions in Pathway</h2>\n";
    my $inner_table_display = 0;
    if ( $inner_table_display ) {
	my $it2 = new InnerTable( 1, "metacyc_rxn$$", "metacyc_rxn", 0 );
	my $sd = $it2->getSdDelim();    # sort delimiter
	$it2->addColSpec( "Reaction ID",   "char asc", "left" );
	$it2->addColSpec( "Reaction Name", "char asc", "left" );
	$it2->addColSpec( "Enzyme", "char asc", "left" );
	$it2->addColSpec( "Definition", "char asc", "left" );

	for my $key (keys %rxn_name_h) {
	    my $url2 = "main.cgi?section=MetaCyc&page=reaction&unique_id=$key";
	    if ( $taxon_oid ) {
		$url2 .= "&taxon_oid=$taxon_oid";
	    }
	    my $r = $key . $sd . alink($url2, $key) . "\t";
	    $r .= $rxn_name_h{$key} . $sd . $rxn_name_h{$key} . "\t";

	    if ( $rxn_ec_h{$key} ) {
		my $ec_number = $rxn_ec_h{$key};
		my $e_url = $enzyme_base_url . $ec_number;
		$r .= $ec_number . $sd . alink($e_url, $ec_number) . "\t";
	    }
	    else {
		$r .= "-" . $sd . "-" . "\t";
	    }

	    my $defn = $rxn_left_h{$key} . " => " . $rxn_right_h{$key};
	    $r .= $defn . $sd . $defn . "\t";
	    $it2->addRow($r);
	}
	$it2->printOuterTable(1);
    }
    else {
	print "<table class='img' border='1'>\n";
	print "<th class='img'>Reaction ID</th>\n";
	print "<th class='img'>Reaction Name</th>\n";
	print "<th class='img'>Enzyme</th>\n";
	print "<th class='img'>Definition</th>\n";

	for my $key (sort (keys %rxn_name_h)) {
	    print "<tr class='img'>";
	    my $url2 = "main.cgi?section=MetaCyc&page=reaction&unique_id=$key";
	    if ( $taxon_oid ) {
		$url2 .= "&taxon_oid=$taxon_oid";
	    }
	    print "<td class='img'>" . alink($url2, $key) . "</td>\n";
	    print "<td class='img'>" . $rxn_name_h{$key} . "</td>\n";

	    if ( $rxn_ec_h{$key} ) {
		my $ec_number = $rxn_ec_h{$key};
		my $e_url = $enzyme_base_url . $ec_number;
		print "<td class='img'>" . alink($e_url, $ec_number) . "</td>\n";
	    }
	    else {
		print "<td class='img'>-</td>\n";
	    }

	    my $defn = $rxn_left_h{$key} . " => " . $rxn_right_h{$key};
	    print "<td class='img'>" . $defn . "</td>\n";
	    print "</tr>\n";
	}

	print "</table>\n";
    }

    # get enzymes and reactions
    print "<h2>Enzymes in Pathway</h2>\n";
    my %ec_h;
    my $cnt = 0;
    my $ec_str;
    my $sql = qq{
        select br.ec_number, e.enzyme_name, br.unique_id
        from biocyc_pathway bp, biocyc_reaction_in_pwys brp, 
            biocyc_reaction br, enzyme e
        where bp.unique_id = ?
        and bp.unique_id = brp.in_pwys
        and brp.unique_id = br.unique_id
        and br.ec_number = e.ec_number
    };
    my $cur = execSql( $dbh, $sql, $verbose, $pathway_id );
    for ( ; ; ) {
        my ( $ec, $ec_name, $rxn ) = $cur->fetchrow();
        last if !$ec;

	$ec_h{$ec} = $ec_name . "\t" . $rxn;

	# we shouldn't have more than 1000 enzymes in one pathway
	if ( $cnt == 0 ) {
	    $ec_str = "'" . $ec . "'";
	}
	elsif ( $cnt < 1000 ) {
	    $ec_str .= ", '" . $ec . "'";
	}
	$cnt++;
    }
    $cur->finish();

    if ( $cnt == 0 ) {
	printStatusLine( "Loaded.", 2 );
	print "<p>No genes found.\n";
	$dbh->disconnect();
	return;
    }

    printFuncCartFooter(0);

    if ( $taxon_oid ) {
	if ( $in_file eq 'No' ) {
	    $sql = qq{
                select v.enzyme, v.gene_count
                from mv_taxon_ec_stat v
                where v.taxon_oid = ?
                and v.enzyme in ( $ec_str )
                };
	}
	else {
	    $sql = qq{
                select v.func_id, v.gene_count
                from taxon_ec_count v
                where v.taxon_oid = ?
                and v.func_id in ( $ec_str )
                };
	}
	$cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	for ( ; ; ) {
	    my ( $ec, $count ) = $cur->fetchrow();
	    last if ! $ec;

	    if ( $genome_type eq 'isolate' ) {
		$iso_cnt_h{$ec} = $count;
	    }
	    else {
		$meta_cnt_h{$ec} = $count;
	    }
	}
	$cur->finish();

	if ( $cluster_id ) {
	    if ( $in_file eq 'No' ) {
		my $sql2 = qq{
                   select gke.enzymes, count(unique gke.gene_oid)
                   from bio_cluster_features_new bcg,
                        gene_ko_enzymes gke
                   where bcg.cluster_id = ?
                   and bcg.gene_oid = gke.gene_oid
                   and gke.enzymes in ( $ec_str )
                   group by gke.enzymes
                };
		my $cur2 = execSql( $dbh, $sql2, $verbose, $cluster_id );
		for ( ; ; ) {
		    my ( $ec, $count ) = $cur2->fetchrow();
		    last if ! $ec;

		    $bc_cnt_h{$ec} = $count;
		}
		$cur2->finish();
	    }
	    else {
		# in file
		my %bc_gene_h;
		my $sql = "select feature_id from bio_cluster_features_new " .
		    "where cluster_id = ? and feature_type = 'gene'";
		my $cur = execSql( $dbh, $sql, $verbose, $cluster_id );
		for (;;) {
		    my ($gene_id) = $cur->fetchrow();
		    last if ! $gene_id;
		    $bc_gene_h{$gene_id} = 1;
		}
		$cur->finish();

		for my $ec2 (keys %ec_h) {
		    my %gene2 = MetaUtil::getTaxonFuncGenes($taxon_oid, 'assembled', $ec2);
		    for my $key (keys %gene2) {
			if ( $bc_gene_h{$key} ) {
			    if ( $bc_cnt_h{$ec2} ) {
				$bc_cnt_h{$ec2} += 1;
			    }
			    else {
				$bc_cnt_h{$ec2} = 1;
			    }
			}
		    }
		}
	    }
	}
    }
    else {
	# all taxons
	my $rclause   = WebUtil::urClause('v.taxon_oid');
	my $imgClause = WebUtil::imgClauseNoTaxon('v.taxon_oid', 1);

	# isolate first
	$sql = qq{
             select v.enzyme, sum(v.gene_count)
             from mv_taxon_ec_stat v
             where v.enzyme in ( $ec_str )
             $rclause
             $imgClause
             group by v.enzyme
             };
	$cur = execSql( $dbh, $sql, $verbose );
	for ( ; ; ) {
	    my ( $ec, $count ) = $cur->fetchrow();
	    last if ! $ec;

	    if ( $iso_cnt_h{$ec} ) {
		$iso_cnt_h{$ec} += $count;
	    }
	    else {
		$iso_cnt_h{$ec} = $count;
	    }
	}
	$cur->finish();

	# metagenomes in database
	if ( $include_metagenomes ) {
	    $imgClause = WebUtil::imgClauseNoTaxon('v.taxon_oid', 2);
	    $sql = qq{
             select v.enzyme, sum(v.gene_count)
             from mv_taxon_ec_stat v
             where v.enzyme in ( $ec_str )
             $rclause
             $imgClause
             group by v.enzyme
             };
	    $cur = execSql( $dbh, $sql, $verbose );
	    for ( ; ; ) {
		my ( $ec, $count ) = $cur->fetchrow();
		last if ! $ec;

		if ( $meta_cnt_h{$ec} ) {
		    $meta_cnt_h{$ec} += $count;
		}
		else {
		    $meta_cnt_h{$ec} = $count;
		}
	    }
	    $cur->finish();

	    # metagenomes in files
	    $imgClause = WebUtil::imgClauseNoTaxon('v.taxon_oid', 2);
	    $sql = qq{
             select v.func_id, sum(v.gene_count)
             from taxon_ec_count v
             where v.func_id in ( $ec_str )
             $rclause
             $imgClause
             group by v.func_id
             };
	    $cur = execSql( $dbh, $sql, $verbose );
	    for ( ; ; ) {
		my ( $ec, $count ) = $cur->fetchrow();
		last if ! $ec;

		if ( $meta_cnt_h{$ec} ) {
		    $meta_cnt_h{$ec} += $count;
		}
		else {
		    $meta_cnt_h{$ec} = $count;
		}
	    }
	    $cur->finish();
	}
    }

    # show result
    my $count = 0;

    my $it = new InnerTable( 1, "metacyc$$", "metacyc", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "EC Number",   "char asc", "left" );
    $it->addColSpec( "Enzyme Name", "char asc", "left" );
    $it->addColSpec( "Reaction ID", "char asc", "left" );

    if ( $taxon_oid ) {
	if ( $cluster_id ) {
	    $it->addColSpec( "Total Gene Count", "number desc", "right" );
	    $it->addColSpec( "Gene Count in Cluster", "number desc", "right" );
	}
	else {
	    $it->addColSpec( "Gene Count", "number desc", "right" );
	}
    }
    else {
	$it->addColSpec( "Isolate Gene Count", "number desc", "right" );
	if ( $include_metagenomes ) {
	    $it->addColSpec( "Metagenome Gene Count", "number desc", "right" );
	}
    }

    my @keys = (keys %ec_h);
    for my $ec_number ( @keys ) {
	my ($ecname, $rxn_id) = split(/\t/, $ec_h{$ec_number});

        # checkbox
        my $r = $sd
	    . "<input type='checkbox' name='ec_number' "
	    . "value='$ec_number' />" . "\t";

        $r .= $ec_number . $sd . $ec_number . "\t";
        $r .= $ecname . $sd . $ecname . "\t";

#        my $url = $metacycURL . "$rxn_id";
	my $url = "main.cgi?section=MetaCyc&page=reaction&unique_id=$rxn_id";
	if ( $taxon_oid ) {
	    $url .= "&taxon_oid=$taxon_oid";
	}
        $url = alink( $url, $rxn_id );

        if ( $rxn_id ne "" ) {
            $r .= $rxn_id . $sd . "$url" . "\t";
        } else {
            $r .= $rxn_id . $sd . " &nbsp; " . "\t";
        }

	if ( $taxon_oid ) {
	    my $url = "main.cgi?section=MetaCyc&page=gene&unique_id=$pathway_id";
	    $url .= "&ec_number=$ec_number";
	    $url .= "&taxon_oid=$taxon_oid";

	    my $gcount = 0;
	    if ( $genome_type eq 'isolate' ) {
		$gcount = $iso_cnt_h{$ec_number};
	    }
	    else {
		$gcount = $meta_cnt_h{$ec_number};
	    }

	    if ( $gcount > 0 ) {
		$r .= $gcount . $sd . alink($url, $gcount) . "\t";
	    } else {
		$r .= "0" . $sd . "0" . "\t";
	    }

	    if ( $cluster_id ) {
		my $url2 = $url . "&cluster_id=$cluster_id";
		my $gcount2 = $bc_cnt_h{$ec_number};
		if ( $gcount2 > 0 ) {
		    $r .= $gcount2 . $sd . 
			alink($url2, $gcount2) . "\t";
		} else {
		    $r .= "0" . $sd . "0" . "\t";
		}
	    }
	}
	else {
	    my $gcount1 = $iso_cnt_h{$ec_number};
	    my $url = "main.cgi?section=FindFunctions&page=EnzymeGenomeList&" .
		"ec_number=$ec_number";

	    if ( $gcount1 > 0 ) {
		my $url1 = alink( $url . "&gtype=isolate", $gcount1 );
		$r .= "$gcount1" . $sd . "$url1" . "\t";
	    } else {
		$r .= "0" . $sd . "0" . "\t";
	    }

	    if ( $include_metagenomes ) {
		my $gcount2 = $meta_cnt_h{$ec_number};
		if ( $gcount2 > 0 ) {
		    my $url2 = alink( $url . "&gtype=metagenome", $gcount2 );
		    $r .= "$gcount2" . $sd . "$url2" . "\t";
		} else {
		    $r .= "0" . $sd . "0" . "\t";
		}
	    }
	}

        $it->addRow($r);

        $count++;
    }

    $it->printOuterTable(1);
    $cur->finish();
    #$dbh->disconnect();

    print "</p>\n";

    printFuncCartFooter(0);

    print qq{
        <input type="hidden" name='metacyc' value='metacyc' />
    };

    print end_form();
    printStatusLine( "$count Loaded.", 2 );
}

sub printMetaCycReaction {
    my $reaction_id = param("unique_id");

    if ( ! $reaction_id ) {
	return;
    }

    print "<h1>MetaCyc Reaction Detail</h1>\n";
    my $taxon_oid = param('taxon_oid');
    my $dbh   = dbLogin();
    my $sql = "select unique_id, common_name, balance_state, comments, " .
	"ec_number, is_official_ec, is_orphan, is_spontaneous from biocyc_reaction " .
	"where unique_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $reaction_id);
    my ( $id2, $common_name, $balance_state, $comments, $ec_number, $is_official_ec,
	 $is_orphan, $is_spontaneous )
	= $cur->fetchrow();
    $cur->finish();

    my $m_url = $metacycURL . escHtml("$reaction_id") . 
	"&type=REACTION-IN-PATHWAY";

    print "<p><a href='$m_url'> <b>";
    if ( $common_name ) {
	print $common_name;
    }
    else {
	print $reaction_id;
    }
    print "</b> </a> </p>\n";

    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "Unique ID", $reaction_id );
    if ( $common_name ) {
	printAttrRowRaw( "Common Name", $common_name );
    }
    if ( $balance_state ) {
	printAttrRowRaw( "Balance State", $balance_state );
    }
    if ( $ec_number ) {
	my $e_url = $enzyme_base_url . $ec_number;
	printAttrRowRaw( "EC Number", alink($e_url, $ec_number) );
    }
    if ( $is_official_ec ) {
	printAttrRowRaw( "Is Official EC?", $is_official_ec );
    }
    if ( $is_orphan ) {
	printAttrRowRaw( "Is Orphan?", $is_orphan );
    }
    if ( $is_spontaneous ) {
	printAttrRowRaw( "Is Spontaneous?", $is_spontaneous );
    }
    if ( $comments ) {
	printAttrRowRaw( "Comments", $comments );
    }

    # in pathway
    my $in_pwy = "";
    my $p_cnt = 0;
    my $sql = "select pr.in_pwys, p.common_name " .
	"from biocyc_pathway p, biocyc_reaction_in_pwys pr " .
	"where pr.unique_id = ? and pr.in_pwys = p.unique_id ";
    my $cur = execSql( $dbh, $sql, $verbose, $reaction_id );
    for ( ; ; ) {
        my ( $id2, $name ) = $cur->fetchrow();
	last if ! $id2;

	$p_cnt++;
	my $url2 = "main.cgi?section=MetaCyc&page=detail&pathway_id=$id2";
	if ( $taxon_oid ) {
	    $url2 .= "&taxon_oid=$taxon_oid";
	}
	if ( $in_pwy ) {
	    $in_pwy .= "<br/>" . alink($url2, $id2) . ": " . $name;
	}
	else {
	    $in_pwy = alink($url2, $id2) . ": " . $name;
	}
    }
    $cur->finish();
    if ( $in_pwy ) {
	if ( $p_cnt > 1 ) {
	    printAttrRowRaw( "In Pathways", $in_pwy );
	}
	else {
	    printAttrRowRaw( "In Pathway", $in_pwy );
	}
    }

    # definition
    # left hand
    my $left_hand = "";
    my $sql = qq{
        select left.substrate, bc.unique_id, bc.common_name
        from biocyc_reaction_left_hand left, biocyc_comp bc
        where left.unique_id = ?
        and left.substrate = bc.unique_id (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $reaction_id );
    for ( ; ; ) {
        my ( $id2, $bc_id, $name ) = $cur->fetchrow();
        last if !$id2;

	my $url2 = "main.cgi?section=MetaCyc&page=compound&unique_id=$bc_id";
	if ( $taxon_oid ) {
	    $url2 .= "&taxon_oid=$taxon_oid";
	}
	if ( ! $name ) {
	    $name = $id2;
	}

	if ( $left_hand ) {
	    if ( $bc_id ) {
		$left_hand .= " + " . alink($url2, $name, "", 1);
	    }
	    else {
		$left_hand .= " + " . $name;
	    }
	}
	else {
	    if ( $bc_id ) {
		$left_hand = alink($url2, $name, "", 1);
	    }
	    else {
		$left_hand = $name;
	    }
	}
    }
    $cur->finish();

    # right hand
    my $right_hand = "";
    my $sql = qq{
        select right.substrate, bc.unique_id, bc.common_name
        from biocyc_reaction_right_hand right, biocyc_comp bc
        where right.unique_id = ?
        and right.substrate = bc.unique_id (+)
    };
    my $cur = execSql( $dbh, $sql, $verbose, $reaction_id );
    for ( ; ; ) {
        my ( $id2, $bc_id, $name ) = $cur->fetchrow();
        last if !$id2;

	my $url2 = "main.cgi?section=MetaCyc&page=compound&unique_id=$bc_id";
	if ( $taxon_oid ) {
	    $url2 .= "&taxon_oid=$taxon_oid";
	}
	if ( ! $name ) {
	    $name = $id2;
	}

	if ( $right_hand ) {
	    if ( $bc_id ) {
		$right_hand .= " + " . alink($url2, $name, "", 1);
	    }
	    else {
		$right_hand .= " + " . $name;
	    }
	}
	else {
	    if ( $bc_id ) {
		$right_hand = alink($url2, $name, "", 1);
	    }
	    else {
		$right_hand = $name;
	    }
	}
    }
    $cur->finish();
    printAttrRowRaw( "Definition", $left_hand . " => " . $right_hand );

    # synonyms
    my $synonyms = "";
    $sql = "select unique_id, synonyms from biocyc_reaction_synonyms " .
	"where unique_id = ?";
    $cur = execSql( $dbh, $sql, $verbose, $reaction_id);
    for (;;) {
	my ( $id2, $name2 ) = $cur->fetchrow();
	last if ! $id2;

	if ( ! $name2 ) {
	    next;
	}

	if ( $synonyms ) {
	    $synonyms .= "<br/>" . $name2;
	}
	else {
	    $synonyms = $name2;
	}
    }
    $cur->finish();
    if ( $synonyms ) {
	printAttrRowRaw( "Synonyms", $synonyms );
    }

    # ext link
    $sql = "select unique_id, db_name, id from biocyc_reaction_ext_links " .
	"where unique_id = ?";
    $cur = execSql( $dbh, $sql, $verbose, $reaction_id);
    for (;;) {
	my ( $id2, $db_name, $id3 ) = $cur->fetchrow();
	last if ! $id2;

	printAttrRowRaw( $db_name, $id3 );
    }
    $cur->finish();

    print "</table>\n";

    print end_form();
}

###################################################################
# printMetaCycCpdList
###################################################################
sub printMetaCycCpdList {

    print "<h1>MetaCyc Compound List</h1>\n";

    printStatusLine( "loading ...", 1 );

    my $dbh   = dbLogin();

    # ext link
    my %ligand_h;
    my %chebi_h;
    my $sql = "select unique_id, db_name, id from biocyc_comp_ext_links ";
    my $cur = execSql( $dbh, $sql, $verbose );
    for (;;) {
	my ( $id2, $db_name, $id3 ) = $cur->fetchrow();
	last if ! $id2;

	if ( $db_name eq 'LIGAND-CPD' ) {
	    $ligand_h{$id2} = $id3;
	}
	elsif ( $db_name eq 'CHEBI' ) {
	    $chebi_h{$id2} = "CHEBI:" . $id3;
	}
    }
    $cur->finish();

    $sql = "select unique_id, common_name, systematic_name, comments, " .
	"mol_wt, smiles, db_source, formula from biocyc_comp ";
    $cur = execSql( $dbh, $sql, $verbose );
    my $count = 0;

    my $it = new InnerTable( 1, "metacyc_cpd$$", "metacyc_cpd", 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Compound ID",   "char asc", "left" );
    $it->addColSpec( "Compound Name", "char asc", "left" );
    $it->addColSpec( "CHEBI", "char asc", "left" );
    $it->addColSpec( "KEGG LIGAND", "char asc", "left" );
    $it->addColSpec( "Formula", "char asc", "left" );
    $it->addColSpec( "Mol. Weight", "number asc", "right" );

    for (;;) {
	my ( $id2, $common_name, $sys_name, $comments, $mol_wt, $smiles, 
	     $db_source, $formula ) 
	    = $cur->fetchrow();
	last if ( ! $id2 );

	my $r = "";
	my $url = "main.cgi?section=MetaCyc&page=compound&unique_id=$id2";
	$r .= $id2 . $sd . alink($url, $id2) . "\t";
	$r .= $common_name . $sd . $common_name . "\t";

	if ( $chebi_h{$id2} ) {
	    my $id3 = $chebi_h{$id2};
	    my $url3 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" . $id3;
	    $r .= $id3 . $sd . alink($url3, $id3) . "\t";
	}
	else {
	    $r .= "-" . $sd . "-" . "\t";
	}

	if ( $ligand_h{$id2} ) {
	    my $id3 = $ligand_h{$id2};
	    my $url3 = "http://www.kegg.jp/entry/" . $id3;
	    $r .= $id3 . $sd . alink($url3, $id3) . "\t";
	}
	else {
	    $r .= "-" . $sd . "-" . "\t";
	}

	$r .= $formula . $sd . $formula . "\t";
	$r .= $mol_wt . $sd . $mol_wt . "\t";

        $it->addRow($r);

        $count++;
    }

    $it->printOuterTable(1);
    $cur->finish();

    printStatusLine( "$count Loaded.", 2 );

    print end_form();
}

#################################################################
# printMetaCycCompound
#################################################################
sub printMetaCycCompound {

    my $taxon_oid = param('taxon_oid');
    my $compound_id = param("unique_id");

    if ( ! $compound_id ) {
    	return;
    }

    printMainForm( ); 

    print "<h1>MetaCyc Compound Detail</h1>\n";
    #print hiddenVar('func_id', "MetaCyc:$compound_id");

    my @names = ();
    my $dbh   = dbLogin();
    my $sql = "select unique_id, common_name, systematic_name, comments, " .
	"mol_wt, smiles, db_source, formula from biocyc_comp " .
	"where unique_id = ?";
    my $cur = execSql( $dbh, $sql, $verbose, $compound_id);
    my ( $id2, $common_name, $sys_name, $comments, $mol_wt, $smiles, 
	 $db_source, $formula ) 
	= $cur->fetchrow();
    $cur->finish();

    print "<table class='img' border='1'>\n"; 
    printAttrRowRaw( "Unique ID", $compound_id );
    if ( $common_name ) {
    	printAttrRowRaw( "Common Name", $common_name );
    	push @names, ( $common_name );
    }
    if ( $sys_name ) {
    	printAttrRowRaw( "Systematic Name", $sys_name );
    	push @names, ( $sys_name );
    }
    if ( $formula ) {
    	printAttrRowRaw( "Formula", $formula );
    }
    if ( $comments ) {
    	printAttrRowRaw( "Comments", $comments );
    }
    if ( $mol_wt ) {
    	printAttrRowRaw( "Mol. Weight", $mol_wt );
    }
    if ( $smiles ) {
    	printAttrRowRaw( "SMILES", $smiles );
    }
    if ( $db_source ) {
    	printAttrRowRaw( "DB Source", $db_source );
    }

    # synonyms
    my $synonyms = "";
    $sql = "select unique_id, synonyms from biocyc_comp_synonyms " .
	"where unique_id = ?";
    $cur = execSql( $dbh, $sql, $verbose, $compound_id);
    for (;;) {
    	my ( $id2, $name2 ) = $cur->fetchrow();
    	last if ! $id2;
    
    	if ( ! $name2 ) {
    	    next;
    	}
    	push @names, ( $name2 );
    
    	if ( $synonyms ) {
    	    $synonyms .= "<br/>" . $name2;
    	}
    	else {
    	    $synonyms = $name2;
    	}
    }
    $cur->finish();
    if ( $synonyms ) {
    	printAttrRowRaw( "Synonyms", $synonyms );
    }

    # in reactions and pathways
    my %pwy_h;
    my $in_rxn = "";
    $sql = qq{
        select rc.rxn_id, rc.rxn_dir, r.common_name, 
               p.unique_id, p.common_name
        from biocyc_pathway p, biocyc_reaction_in_pwys pr,
             biocyc_reaction r,
             (select unique_id rxn_id, 'LHS' rxn_dir
              from biocyc_reaction_left_hand
 	      where substrate = ? union
	      select unique_id, 'RHS' from biocyc_reaction_right_hand
	      where substrate = ? ) rc
        where r.unique_id = rc.rxn_id
        and r.unique_id = pr.unique_id
        and pr.in_pwys = p.unique_id (+)
        };
    $cur = execSql( $dbh, $sql, $verbose, $compound_id, $compound_id);
    for (;;) {
	my ( $id2, $side, $rxn_name, $pwy_id, $pwy_name ) = 
	    $cur->fetchrow();
	last if ! $id2;

	my $url2 = "main.cgi?section=MetaCyc&page=reaction&unique_id=$id2";
	if ( $taxon_oid ) {
	    $url2 .= "&taxon_oid=$taxon_oid";
	}
	my $rxn = "(" . $side . ") " . alink($url2, $id2);

	if ( $in_rxn ) {
	    $in_rxn .= "<br/>" . $rxn;
	}
	else {
	    $in_rxn = $rxn;
	}
	if ( $rxn_name ) {
	    $in_rxn .= " (" . $rxn_name . ")";
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
    	    my $url3 = "main.cgi?section=MetaCyc&page=detail&pathway_id=$pid";
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

    # ext link
    my $ligand_id = "";
    my $chebi_id = "";
    $sql = "select unique_id, db_name, id from biocyc_comp_ext_links " .
	"where unique_id = ?";
    $cur = execSql( $dbh, $sql, $verbose, $compound_id);
    for (;;) {
	my ( $id2, $db_name, $id3 ) = $cur->fetchrow();
	last if ! $id2;

	my $url3 = "";
	if ( $db_name eq 'LIGAND-CPD' ) {
	    $url3 = "http://www.kegg.jp/entry/" . $id3;
	    $ligand_id = $id3;
	}
	if ( $db_name eq 'CHEBI' ) {
	    $url3 = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId=" . $id3;
	    $chebi_id = "CHEBI:" . $id3;
	}
	if ( $db_name eq 'PUBCHEM' ) {
	    $url3 = $pubchem_base_url . $id3;
	}

	if ( $url3 ) {
	    printAttrRowRaw( $db_name, alink($url3, $id3) );
	}
	else {
	    printAttrRowRaw( $db_name, $id3 );
	}
    }
    $cur->finish();

    my %img_compound_oids = matchImgCompound($dbh, $chebi_id, $ligand_id, \@names);
    for my $id3 ( keys %img_compound_oids ) {
    	my $name3 = $img_compound_oids{$id3};
    	my $url3 = "$main_cgi?section=ImgCompound&page=imgCpdDetail&compound_oid=$id3";
    	if ( $name3 ) {
    	    printAttrRowRaw( "IMG Compound", alink($url3, $id3) . " " . $name3);
    	}
    	else {
    	    printAttrRowRaw( "IMG Compound", alink($url3, $id3) );
    	}
    }

    print "</table>\n";

    #my $name = "_section_FuncCartStor_addToFuncCart"; 
    #print submit( 
    #      -name  => $name, 
    #      -value => "Add to Function Cart", 
    #      -class => "meddefbutton" 
    #); 

    print end_form();
}

sub matchImgCompound {
    my ($dbh, $chebi_id, $ligand_id, $name_aref) = @_;

    my %img_compound_h;


    if ( $chebi_id ) {
	my $sql = "select c.compound_oid, c.compound_name from img_compound c ";
	$sql .= "where c.db_source = 'CHEBI' and ext_accession = ? ";

	my $cur = execSql( $dbh, $sql, $verbose, $chebi_id );
	for (;;) {
	    my ( $id3, $name3 ) = $cur->fetchrow();
	    last if ! $id3;

	    $img_compound_h{$id3} = $name3;
	}
	$cur->finish();
    }

    if ( $ligand_id ) {
	my $sql = "select c.compound_oid, c.compound_name from img_compound c ";
	$sql .= "where c.db_source = 'KEGG LIGAND' and ext_accession = ? ";

	my $cur = execSql( $dbh, $sql, $verbose, $ligand_id );
	for (;;) {
	    my ( $id3, $name3 ) = $cur->fetchrow();
	    last if ! $id3;

	    $img_compound_h{$id3} = $name3;
	}
	$cur->finish();
    }

    my $name_str = "";
    my $cnt = 0;
    for my $name ( @$name_aref ) {
	$cnt++;
	if ( $cnt > 1000 ) {
	    last;
	}

	$name = lc($name);
	$name =~ s/'/''/g;    # replace ' with ''
	if ( $name_str ) {
	    $name_str .= ", '" . $name . "'";
	}
	else {
	    $name_str = "'" . $name . "'";
	}
    }

    if ( $name_str ) {
	my $sql = "select c.compound_oid, c.compound_name from img_compound c ";
	$sql .= "where lower(c.compound_name) in (" . $name_str . ") ";
	$sql .= "or lower(c.common_name) in (" . $name_str . ") ";
	$sql .= "or c.compound_oid in (select a.compound_oid from img_compound_aliases a ";
	$sql .= " where lower(a.aliases) in (" . $name_str . ")) ";

	my $cur = execSql( $dbh, $sql, $verbose );
	for (;;) {
	    my ( $id3, $name3 ) = $cur->fetchrow();
	    last if ! $id3;

	    $img_compound_h{$id3} = $name3;
	}
	$cur->finish();
    }

    return %img_compound_h;
}


sub printTree_old {

    print "<h1>MetaCyc Pathways</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    my $treeRoots_href   = getRootNodes($dbh);
    my $subpathways_href = getSubPathways($dbh);
    my $pathways_href    = getPathways($dbh);

    #$dbh->disconnect();

    # build the initial root od the tree,
    # with types and id and sub root, and sub sub root
    #
    # pathway
    #  - type 1
    #      - id 1
    #      - id 2
    #  - type 2
    #      - id 2.1

    # unique id => Node object
    my %id2Node;
    my $root = new MetaCycNode( "Pathway", "Pathway", "Pathway" );
    foreach my $type ( sort keys %$treeRoots_href ) {

        # types as a sub root
        my @a = split( /\s/, $type );
        my $node = new MetaCycNode( $a[0], $type, $type );
        $root->addChild($node);

        my $id_href = $treeRoots_href->{$type};
        foreach my $id ( keys %$id_href ) {
            my $name = $id_href->{$id};
            my $child = new MetaCycNode( $id, $name, $type );
            $node->addChild($child);

            $id2Node{$id} = $child;
        }
    }

    # build sub pathways
    foreach my $id ( keys %$subpathways_href ) {

        my $aref = $subpathways_href->{$id};

        foreach my $subid (@$aref) {
            if ( exists $id2Node{$id} ) {

                # this id has a sub pathway and the node was created already
                my $childNode = $id2Node{$id};

                if ( exists $id2Node{$subid} ) {
                    my $subNode = $id2Node{$subid};
                    $childNode->addChild($subNode);
                } else {
                    my $newChild =
                      new MetaCycNode( $subid, $pathways_href->{$subid},
                        $subid );
                    $childNode->addChild($newChild);
                    $id2Node{$subid} = $newChild;
                }

            } else {

                # parent node not created yet
                my $pnode = new MetaCycNode( $id, $pathways_href->{$id}, $id );
                $id2Node{$id} = $pnode;

                if ( exists $id2Node{$subid} ) {
                    my $child = $id2Node{$subid};
                    $pnode->addChild($child);
                } else {
                    my $newChild =
                      new MetaCycNode( $subid, $pathways_href->{$subid},
                        $subid );
                    $id2Node{$subid} = $newChild;
                    $pnode->addChild($newChild);
                }
            }
        }
    }

    printHTMLTree($root);

    printStatusLine( "Loaded.", 2 );
}

sub getPathways {
    my ($dbh) = @_;

    my $sql = qq{
        select  unique_id, type, common_name
        from biocyc_pathway        
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $type, $name ) = $cur->fetchrow();
        last if !$id;

        $hash{$id} = "$name\t$type";

    }

    $cur->finish();

    return \%hash;

}

# TODO - ken
# the original id's type is NOT added to this list of distinct types

# $id - unique id to search for super pathways
# $super_href - hash of array of super pathways
# $pathways_href - list of all the pathways is => name \t type
# $type_href - initial empty set of distinct super pathway types
#
sub hasSuperPathway {
    my ( $id, $super_href, $pathways_href, $type_href ) = @_;
    if ( exists( $super_href->{$id} ) ) {
        my $aref = $super_href->{$id};
        foreach my $i (@$aref) {
            my $line = $pathways_href->{$i};
            my ( $name, $type ) = split( /\t/, $line );
            $type_href->{$type} = "";

            # see if the super path has a super pathway
            hasSuperPathway( $i, $super_href, $pathways_href, $type_href );
        }
    }
}

sub getSupPathways {
    my ($dbh) = @_;

    my $sql = qq{
        select unique_id, super_pwys
        from biocyc_pathway_super_pwys        
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $sub ) = $cur->fetchrow();
        last if !$id;

        if ( exists $hash{$id} ) {
            my $aref = $hash{$id};
            push( @$aref, $sub );
        } else {
            my @a = ($sub);
            $hash{$id} = \@a;
        }

    }

    $cur->finish();

    return \%hash;

}

sub getSubPathways {
    my ($dbh) = @_;

    my $sql = qq{
        select unique_id, sub_pwys
        from biocyc_pathway_sub_pwys        
    };

    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $sub ) = $cur->fetchrow();
        last if !$id;

        if ( exists $hash{$id} ) {
            my $aref = $hash{$id};
            push( @$aref, $sub );
        } else {
            my @a = ($sub);
            $hash{$id} = \@a;
        }

    }

    $cur->finish();

    return \%hash;

}

sub buildCatNodes {

    print "<h1>MetaCyc Pathways</h1>\n";
    # hide gene counts because they can be inconsistent
#    print qq{
#      <p>
#      * - pathways associated with IMG genomes.
#      <br/>
#      () - gene count
#      </p>  
#    };
    print qq{
      <p>
      * - pathways associated with IMG genomes.
      </p>  
    };

    my $c_url = "main.cgi?section=MetaCyc&page=cpdList";
    print "<p>" . alink($c_url, "MetaCyc Compounds") . "\n";

    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    # list of metacyc data link in img
    my $linked_href = getLinkPathways($dbh);

# TODO - check query for 3.0
    my $sql = qq{
select distinct c.unique_id, ct.types, $nvl(c.common_name,c.unique_id),
       p.unique_id as child_id, pt.types as child_type, p.common_name as chlid_name,
sys_connect_by_path(ct.types,'/') "path"
from biocyc_class c, biocyc_class_types ct, biocyc_pathway p,
biocyc_pathway_types pt
where c.unique_id = pt.types
and c.unique_id = ct.unique_id
and p.unique_id = pt.unique_id
connect by  prior ct.unique_id  = ct.types
start with ct.types = 'Pathways' or ct.types = 'Biosynthesis'
order by "path", pt.types, p.common_name      
    };

    my $root = new MetaCycNode( "Pathways", "Pathways", "Pathways" );
    my %parentCatNode;

    # hash of cat node location id => cat node
    $parentCatNode{"Pathways"} = $root;

    # exception child node
    my $bio = new MetaCycNode( "Biosynthesis", "Biosynthesis", "Biosynthesis" );
    $parentCatNode{"Biosynthesis"} = $bio;
    $root->addChild($bio);

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my (
            $parent_id,  $parent_type, $parent_name, $child_id,
            $child_type, $child_name,  $path
          )
          = $cur->fetchrow();
        last if !$parent_id;

        if ( !exists $parentCatNode{$child_type} ) {

            # the child's parent node does not exists
            my $parentNode =
              new MetaCycNode( $parent_id, $parent_name, $parent_type );
            $parentCatNode{$child_type} = $parentNode;
            my $parentParentNode = $parentCatNode{$parent_type};
            $parentParentNode->addChild($parentNode);
        }

        # create child node
        my $childNode = new MetaCycNode( $child_id, $child_name, $child_type );
        my $parentNode = $parentCatNode{$child_type};
        #$parentNode->addChild($childNode);
        $parentNode->addChildUnique($childNode);
    }
    $cur->finish();

    #$dbh->disconnect();

    print <<EOF;
    <script language="javascript" type="text/javascript">

    function selectMetaCyc(parentId, level) {
        var f = document.mainForm;
        var found = false;
        for( var i = 0; i < f.length; i++ ) {
          var e = f.elements[ i ];
          if(found) {
              
            if( e.type == "checkbox" ) {
                //alert("id = " + e.id + " value = "  + e.value);
                e.checked = true;
            }
            
            if(e.type == "button" ) {
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                //alert("button out id=" + a + " name= " + e.name + " level=" + b);
                found = false;
                return;
                }
            }
            
          }
          if(e.type == "button" && e.name == parentId) {
              //alert(level + " found " + parentId);
              found = true;
          }
        }
    }

    function clearMetaCyc(parentId, level) {
        var f = document.mainForm;
        var found = false;
        for( var i = 0; i < f.length; i++ ) {
          var e = f.elements[ i ];
          if(found) {
              
            if( e.type == "checkbox" ) {
                //alert("id = " + e.id + " value = "  + e.value);
                e.checked = false;
            }
            
            if(e.type == "button" ) {
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                //alert("button out id=" + a + " name= " + e.name + " level=" + b);
                found = false;
                return;
                }
            }
            
          }
          if(e.type == "button" && e.name == parentId) {
              //alert(level + " found " + parentId);
              found = true;
          }
        }        
    }

    </script>
EOF

    printMainForm();
    printFuncCartFooter(0);

    #print Dumper \%parentCatNode ;
    #print Dumper $root;
    print "<p>\n";
    my $count = printHTMLTree( $root, 0, $linked_href );
    print "</p>\n";
    printStatusLine( "$count Loaded.", 2 );
    print end_form();

}

sub buildCatNodes2 {

    # hide gene counts because they can be inconsistent
    print "<h1>MetaCyc Pathways</h1>\n";
#    print qq{
#      <p>
#      * - pathways associated with IMG genomes.
#      <br/>
#      () - gene count
#      </p>  
#    };
    print qq{
      <p>
      * - pathways associated with IMG genomes.
      </p>  
    };
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    # list of metacyc data link in img
    my $linked_href = getLinkPathways($dbh);

    my $sql = qq{
select distinct c.unique_id, ct.types, $nvl(c.common_name,c.unique_id),
       p.unique_id, pt.types, p.common_name
from biocyc_class c, biocyc_class_types ct, biocyc_pathway p,
biocyc_pathway_types pt
where c.unique_id = pt.types
and c.unique_id = ct.unique_id
and p.unique_id = pt.unique_id 
order by ct.types, $nvl(c.common_name,c.unique_id), pt.types, p.common_name    
    };

    my $root = new MetaCycNode( "Pathways", "Pathways", "Pathways" );

    # exception child node
    my $bio = new MetaCycNode( "Biosynthesis", "Biosynthesis", "Biosynthesis" );
    $root->addChild($bio);

    # hash of cat node location id => cat node
    my %catNode;
    $catNode{"Pathways"}     = $root;
    $catNode{"Biosynthesis"} = $bio;
    my @results;

    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $grandparent_type, $name, $child_id, $childparent_type,
            $child_name )
          = $cur->fetchrow();
        last if !$id;
        push( @results,
                "$id\t$grandparent_type\t$name\t$child_id"
              . "\t$childparent_type\t$child_name" );

        if ( !exists $catNode{$id} ) {

            # curernt node or parent node
            my $node = new MetaCycNode( $id, $name, $grandparent_type );
            $catNode{$id} = $node;
        }
    }
    $cur->finish();
    #$dbh->disconnect();

    # now connect parents to grand parents
    # can there be duplicates?
    foreach my $line (@results) {
        my ( $id, $grandparent_type, $name, $child_id, $childparent_type,
            $child_name )
          = split( /\t/, $line );

        my $parentNode      = $catNode{$id};
        my $grandparentNode = $catNode{$grandparent_type};
        if ( !exists $catNode{$grandparent_type} ) {
            $grandparentNode =
              new MetaCycNode( $grandparent_type, $grandparent_type,
                $grandparent_type );
            $catNode{$grandparent_type} = $grandparentNode;
        }
        $grandparentNode->addChildUnique($parentNode);
    }

    foreach my $line (@results) {
        my ( $id, $grandparent_type, $name, $child_id, $childparent_type,
            $child_name )
          = split( /\t/, $line );

        my $parentNode = $catNode{$childparent_type};
        my $childNode  = $catNode{$child_id};
        if ( !exists $catNode{$child_id} ) {
            $childNode =
              new MetaCycNode( $child_id, $child_name, $childparent_type );
            $catNode{$child_id} = $childNode;
        }

        $parentNode->addChildUnique($childNode);
    }

    print <<EOF;
    <script language="javascript" type="text/javascript">

    function selectMetaCyc(parentId, level) {
        var f = document.mainForm;
        var found = false;
        for( var i = 0; i < f.length; i++ ) {
          var e = f.elements[ i ];
          if(found) {
            
            if(e.type == "button" ) {
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                //alert("button out id=" + a + " name= " + e.name + " level=" + b);
                found = false;
                return;
                }
            }
  
          if( e.type == "checkbox" ) {
                //alert("id = " + e.id + " value = "  + e.value);
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                 found = false;
                return;                   
                }
                e.checked = true;
            }  
            
          }
          if(e.type == "button" && e.name == parentId) {
              //alert(level + " found " + parentId);
              found = true;
          }
        }
    }

    function clearMetaCyc(parentId, level) {
        var f = document.mainForm;
        var found = false;
        for( var i = 0; i < f.length; i++ ) {
          var e = f.elements[ i ];
          if(found) {
            if(e.type == "button" ) {
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                //alert("button out id=" + a + " name= " + e.name + " level=" + b);
                found = false;
                return;
                }
            }

            if( e.type == "checkbox" ) {
                //alert("id = " + e.id + " value = "  + e.value);
                var a = parseInt(e.id);
                var b = parseInt(level);
                if(a <= level) {
                 found = false;
                return;                   
                } 
                e.checked = false;
            }
            
          }
          if(e.type == "button" && e.name == parentId) {
              //alert(level + " found " + parentId);
              found = true;
          }
        }        
    }

    </script>
EOF

    printMainForm();
    printFuncCartFooter(0);

    #print Dumper \%parentCatNode ;
    #print Dumper $root;
    print "<p>\n";
    my $count = printHTMLTree( $root, 0, $linked_href );
    print "</p>\n";
    printStatusLine( "$count Loaded.", 2 );
    print end_form();

}

sub getRootNodes {
    my ($dbh) = @_;

    my $sql = qq{
        select bp.unique_id, bp.type, bp.common_name
        from biocyc_pathway bp
        left join biocyc_pathway_super_pwys bpsup on bp.unique_id = bpsup.unique_id
        where bpsup.unique_id is null
        order by 2        
    };

    # hash of hash: type => id => name
    my %hash;
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ( $id, $type, $name ) = $cur->fetchrow();
        last if !$id;
        if ( exists $hash{$type} ) {
            my $href = $hash{$type};
            $href->{$id} = $name;
        } else {
            my %tmp;
            $tmp{$id}    = $name;
            $hash{$type} = \%tmp;
        }
    }

    $cur->finish();

    return \%hash;
}

# node
# level - 0 is root
sub printHTMLTree {
    my ( $node, $level, $linked_href ) = @_;

    my $ident = 4;

    my $name          = $node->getName();
    my $children_aref = $node->getChildren();
    my $id            = escHtml( $node->getUniqueId() );
    my $url           = $detailURL . "$id";
    my $url2          = $metacycURL . $id;
    my $count         = 0;

 # for the js script to do select all or none
 # 1. button id=level is the level to know when to stop
 # 2. button name=id is the pathway id parent node, use to find
 #    which button the user pressed
 # 3. check box id=level to know which box to check, box id level > button level
 # 4. checkbox value= is prefix with MetaCyc:$id for function cart
    if ( $#$children_aref > -1 ) {

        print nbsp( $level * $ident );
        printf "%02d ", $level;
        print "<b>" . alink( $url2, $name, "", 1 ) . "</b>\n";
        print qq{
            <input id='$level' name='$id' type='button' value='All' Class='tinybutton' 
            onClick='selectMetaCyc("$id", $level)' />
            <input type='button' value='None' Class='tinybutton' 
            onClick='clearMetaCyc("$id", $level)' />
            <br/>
        };

    } else {
        print nbsp( $level * $ident );
        printf "%02d ", $level;
        print qq{
            <input id='$level' type='checkbox' name='func_id'  value='MetaCyc:$id' />
            &nbsp;
        };
        if ( exists $linked_href->{$id} ) {
            print "<b>*</b> &nbsp;";
#            print alink( $url, $name, "", 1 ) . " ("
#              . $linked_href->{$id}
#              . ") <br/>\n";
            print alink( $url, $name, "", 1 ) . "<br/>\n";
        } else {
            print "&nbsp; &nbsp;";
            print alink( $url2, $name, "", 1 ) . "<br/>\n";
        }

        $count++;
    }

    foreach my $childNode (@$children_aref) {

        # has children
        $count = $count + printHTMLTree( $childNode, $level + 1, $linked_href );
    }
    return $count;
}


sub getLinkPathways {
    my ($dbh) = @_;

    my $sql = qq{
        select v.pwy_id, sum(v.gene_cnt)
        from mv_metacyc_stats v
        group by v.pwy_id
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

1;
