#
#
# $Id: BiosyntheticSearch.pm 31620 2014-08-27 04:30:27Z jinghuahuang $
#
package BiosyntheticSearch;

use strict;
use POSIX qw(ceil floor);
use CGI qw( :standard );
use Data::Dumper;
use HTML::Template;
use WebConfig;
use WebUtil;
use HtmlUtil;
use OracleUtil;
use InnerTable;

my $env             = getEnv();
my $main_cgi        = $env->{main_cgi};
my $inner_cgi       = $env->{inner_cgi};
my $cgi_url         = $env->{cgi_url};
my $xml_cgi         = $cgi_url . '/xml.cgi';
my $tmp_url         = $env->{tmp_url};
my $tmp_dir         = $env->{tmp_dir};
my $verbose         = $env->{verbose};
my $base_dir        = $env->{base_dir};
my $base_url        = $env->{base_url};

my $ncbi_base_url   = $env->{ncbi_entrez_base_url};
my $pfam_base_url   = $env->{pfam_base_url};
my $img_ken         = $env->{img_ken};
my $YUI             = $env->{yui_dir_28};
my $nvl             = getNvl();
my $enable_biocluster = $env->{enable_biocluster};

############################################################################
# printBiosyntheticSearchForm - Show Biosynthetic search form.
#   Read from template file and replace some template components.
############################################################################
sub printBiosyntheticSearchForm {
    printMainForm();
    print qq{
        <h1>Biosynthetic Cluster (BC) Search</h1>
    };
    my $idSearchUrl = "main.cgi?section=BcNpIDSearch&option=bc";
    my $idSearchLink = alink($idSearchUrl, "Search Biosynthetic Cluster by ID");
    print qq{
        <p>$idSearchLink</p>
    };
    print qq{
        <script language='JavaScript' type='text/javascript' src='$base_url/validation.js'>
        </script>
    };

    my $checkboxSelectionMode = 1;
    my $result_page = "$main_cgi?section=BcSearch&page=bcSearchResult";
    
    my $templateFile = "$base_dir/biosyntheticSearch.html";
    my $rfh = newReadFileHandle($templateFile, "printBiosyntheticSearchForm");
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        
        #webLog("$s\n");
        
        $s =~ s/__main_cgi__/$result_page/g;
        if ( $s =~ /__domainOptions__/ ) {
            printDomainOptionList();
        }
        if ( $s =~ /__showButton__/ ) {
            $s =~ s/__showButton__//g;
            printShowButton( $checkboxSelectionMode );
        }
        if ( $s =~ /__phylogeneticTree__/ ) {
            printPhylogeneticTree( $checkboxSelectionMode );
        }
        elsif ( $s =~ /__bcTypeOptions__/ ) {
            require MeshTree;
            MeshTree::printBCTypeTreeDiv();
        }
        elsif ( $s =~ /__evidenceOptions__/ ) {
            printEvidenceOptionList();
        }
        elsif ( $s =~ /__npActivityOptions__/ ) {
            printNpActivityOptionList();
        }
        elsif ( $s =~ /__npTypeOptions__/ ) {
            printNpTypeTreeOption( $checkboxSelectionMode );
        }
        elsif ( $s =~ /__hint__/ ) {
            printPageHint();
        }
        elsif ( $s =~ /__javascript__/ ) {
            printJavaScript( $checkboxSelectionMode );
        }
        else {
            print "$s\n";
        }
    }
    close $rfh;

    print end_form();
    printStatusLine( "Loaded.", 2 ); 
}

############################################################################
# printDomainOptionList - Print options for domain.
############################################################################
sub printDomainOptionList {
    my $rclause   = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClauseNoTaxon("t");
    
    my $sql = qq{
        select distinct t.domain
        from taxon t
        where 1 = 1
        $rclause
        $imgClause
        order by t.domain
    };

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my @domains;
    for ( ; ; ) {
        my ( $domain ) = $cur->fetchrow();
        last if !$domain;
        push(@domains, $domain);
    }
    $cur->finish();
    
    print qq{
        <option selected></option>
    };
    for my $domain (@domains) {
        print qq{
            <option value="$domain">$domain</option>
        };
    }
    print qq{
        <option value="all">All (Slow)</option>
    };

}

############################################################################
# printShowButton
############################################################################
sub printShowButton {
    my ($checkboxSelectionMode) = @_;

    print qq{
        <input id='showButton' type="button" value='Show' 
            onclick="showButtonClicked('$base_url', '$xml_cgi', $checkboxSelectionMode, 'bc');">
    };
}

############################################################################
# printPhylogeneticTree - Print phylogenetic tree.
############################################################################
sub printPhylogeneticTree {
    my ($checkboxSelectionMode) = @_;
    
    my $checkboxSelectionYUIClass;
    if ($checkboxSelectionMode) {
        $checkboxSelectionYUIClass = "class='ygtv-checkbox'";
    }

    #Browser does not award "style='min-height: 100px;'" for either <tr> or <td>
    #call javascript and use <br/> to generate empty space
    print qq{
        <div id="treedivBcPhylo"></div>
        <div id="treediv1BcPhylo" $checkboxSelectionYUIClass></div>
        <script type="text/javascript">
        printEmptyPhylo('bc');
        </script>
    };
}

############################################################################
# printBcTypeOptionList - Print options for BC type.
############################################################################
sub printBcTypeOptionList {
    my $sql = qq{
        select bc_code, bc_desc
        from bc_type
    };

    my $dbh = dbLogin();
    my $aref = OracleUtil::execSqlCached($dbh, $sql, 'printBcTypeOptionList_new', 0);
    
    my %bc_types;

    foreach my $inner_aref (@$aref) {
        my ( $bc_type, $desc ) = @$inner_aref;
        $bc_types{$bc_type} = $desc;
    }
    
    print qq{
        <option selected></option>
    };

    foreach my $bc_type (sort keys %bc_types) {
        my $desc =  $bc_types{$bc_type};
        print qq{
            <option value="$bc_type">$desc</option>
        };        
    }
}

############################################################################
# printEvidenceOptionList - Print options for Evidence.
############################################################################
sub printEvidenceOptionList {
    my @evidences = ('Experimental', 'Predicted');
    print qq{
        <option selected></option>
    };
    for my $evidence (@evidences) {
        print qq{
            <option value="$evidence">$evidence</option>
        };        
    }
}

############################################################################
# printNpActivityOptionList - Print options for NP type.
############################################################################
sub printNpActivityOptionList {
    my $sql = qq{
        select distinct md.name
        from mesh_dtree md, img_compound_activity ia, 
             np_biosynthesis_source nbs
        where md.node = ia.activity
        and ia.compound_oid = nbs.compound_oid
        order by md.name
    };

    my $dbh = dbLogin();
    #my $cur = execSql( $dbh, $sql, $verbose );
    my $aref = OracleUtil::execSqlCached($dbh, $sql, 'printNpActivityOptionList', 0);
    
    my @np_activities;
    #for ( ; ; ) {
    foreach my $inner_aref (@$aref) {
#        my ( $md_name ) = $cur->fetchrow();
#        last if !$md_name;
         my ( $md_name ) = @$inner_aref;

        push(@np_activities, $md_name);
    }
    #$cur->finish();
    
    print qq{
        <option selected></option>
    };
    for my $np_activity (@np_activities) {
        print qq{
            <option value="$np_activity">$np_activity</option>
        };        
    }
}

############################################################################
# printNpTypeOption - Print options for NP type.
############################################################################
sub printNpTypeTreeOption {
    my ($checkboxSelectionMode) = @_;
    
    require MeshTree;
    MeshTree::printTreeAllDiv( $checkboxSelectionMode );
}

############################################################################
# printPageHint - Show hint text for this page.
############################################################################
sub printPageHint {
    #WebUtil::printHint(
    #    qq{
    #      All searches treat the keyword as a substring (a word or part of a word).
    #      <br />
    #      The search should contain some alphanumeric characters.<br/>
    #      Inexact searches may use matching metacharacters.<br/>
    #    }
    #);
}

############################################################################
# printJavaScript
############################################################################
sub printJavaScript {
    my ($checkboxSelectionMode) = @_;

    print qq{
    <script type="text/javascript" >
    window.onload = function() {
        //window.alert("window.onload");
        showButtonClicked('$base_url', '$xml_cgi', $checkboxSelectionMode, 'bc');
    }
    </script>
    };
}

############################################################################
# printBiosyntheticSearchResult
############################################################################
sub printBiosyntheticSearchResult {
    my $taxonLimit = 1000;
    my $clusterLimit = 10000;

    if ( !$enable_biocluster ) {
        WebUtil::webError("Biosynthetic Cluster not supported!");
    }

    my @genomeFilterSelections = 
	OracleUtil::processTaxonSelectionParam("genomeFilterSelections");
    #if ( scalar(@genomeFilterSelections) >= $taxonLimit ) {
    #        webError("Your taxon selection in Phylogentic Option is " 
    #            . scalar(@genomeFilterSelections) . ".<br/>" 
    #            . "Please the number to less than $taxonLimit .");
    #}

    my $bcsearch_type = param("bcsearch_type");
    my @bcTypes = param("bcTypes");
    my $evidence = param("evidence");

    my $from_probability = param("from_probability");
    $from_probability = WebUtil::processSearchTerm( $from_probability ) 
        if ( $from_probability );
    my $to_probability = param("to_probability");
    $to_probability = WebUtil::processSearchTerm( $to_probability ) 
        if ( $to_probability );
    if ( $from_probability || $to_probability ) {
        if ( $from_probability ) {
            WebUtil::webError("Invalid Prediction Probability (From)") 
                if (!WebUtil::isNumber($from_probability));
            if ( $from_probability < 0 || $from_probability > 1 ) {
                #$from_probability = 0 if ( $from_probability < 0 );
                #$from_probability = 1 if ( $from_probability > 1 );
                WebUtil::webError("Prediction Probability (From) value not valid. Only numbers between 0 and 1 are accepted.");
            }
        }
        if ( $to_probability ) {
            WebUtil::webError("Invalid Prediction Probability (To)") 
                if (!WebUtil::isNumber($to_probability));
            if ( $to_probability < 0 || $to_probability > 1 ) {
                #$to_probability = 0 if ( $to_probability < 0 );
                #$to_probability = 1 if ( $to_probability > 1 );
                WebUtil::webError("Prediction Probability (To) value not valid. Only numbers between 0 and 1 are accepted.");
            }
        }
        if ( $from_probability && $to_probability 
            && $from_probability > $to_probability ) {
            my $to = $from_probability;
            $from_probability = $to_probability;
            $to_probability = $to;
        }
    }
    
    my $from_length = param("from_length");
    $from_length = WebUtil::processSearchTerm( $from_length ) 
        if ( $from_length );
    my $to_length = param("to_length");
    $to_length = WebUtil::processSearchTerm( $to_length ) 
        if ( $to_length );
    if ( $from_length || $to_length ) {
        if ( $from_length ) {
            WebUtil::webError("Invalid Length Range (From)") 
                if (!WebUtil::isInt($from_length));
            if ( $from_length < 0 ) {
                #$from_length = 0;
                WebUtil::webError("Length Range (From) value not valid. Only none-negative integers are accepted.");
            }
        }
        if ( $to_length ) {
            WebUtil::webError("Invalid Length Range (To)") 
                if (!WebUtil::isInt($to_length));
            if ( $to_length < 0 ) {
                #$to_length = 0;
                WebUtil::webError("Length Range (To) value not valid. Only none-negative integers are accepted.");
            }
        }
        if ( $from_length && $to_length
            && $from_length > $to_length ) {
            my $to = $from_length;
            $from_length = $to_length;
            $to_length = $to;
        }
    }

    my $from_gene_cnt = param("from_gene_cnt");
    $from_gene_cnt = WebUtil::processSearchTerm( $from_gene_cnt ) 
        if ( $from_length );
    my $to_gene_cnt = param("to_gene_cnt");
    $to_gene_cnt = WebUtil::processSearchTerm( $to_gene_cnt ) 
        if ( $to_gene_cnt );
    if ( $from_gene_cnt || $to_gene_cnt ) {
        if ( $from_gene_cnt ) {
            WebUtil::webError("Invalid Gene Count (From)") 
                if (!WebUtil::isInt($from_gene_cnt));
            if ( $from_gene_cnt < 0 ) {
                #$from_gene_cnt = 0;
                WebUtil::webError("Gene Count (From) value not valid. Only none-negative integers are accepted.");
            }
        }
        if ( $to_gene_cnt ) {
            WebUtil::webError("Invalid Gene Count (To)") 
                if (!WebUtil::isInt($to_gene_cnt));
            if ( $to_gene_cnt < 0 ) {
                #$to_length = 0;
                WebUtil::webError("Gene Count (To) value not valid. Only none-negative integers are accepted.");
            }
        }
        if ( $from_gene_cnt && $to_gene_cnt
            && $from_gene_cnt > $to_gene_cnt ) {
            my $to = $from_gene_cnt;
            $from_gene_cnt = $to_gene_cnt;
            $to_gene_cnt = $to;
        }
    }

    my $npName = param("npName");
    if ( $npName ) {
        WebUtil::processSearchTermCheck($npName, 'Secondary Metabolite Name');
        $npName = WebUtil::processSearchTerm($npName, 1);
    }
    my $npActivity = param("npActivity");
    my @npTypes = OracleUtil::processTaxonSelectionParam("npTypes");

    my $pfamSearchTerm = param("pfamSearchTerm");
    if ( $pfamSearchTerm ) {
        WebUtil::processSearchTermCheck( $pfamSearchTerm, 'Pfam ID (list)' );
        $pfamSearchTerm = WebUtil::processSearchTerm( $pfamSearchTerm, 1 );
        $pfamSearchTerm = lc($pfamSearchTerm);
    }

    if ( scalar(@genomeFilterSelections) <= 0 
        && !$evidence
        && !$from_probability
        && !$to_probability
        && !$from_length
        && !$to_length
        && !$from_gene_cnt
        && !$to_gene_cnt
        && !$npName
        && !$npActivity
        && scalar(@npTypes) <= 0
        && scalar(@bcTypes) <= 0
        && !$pfamSearchTerm ) {
        webError("Please make selections!");
    }

    printStatusLine( "Loading ...", 1 );

    my $title = "Biosynthetic Cluster Search Results";
    my $subTitle;
    $subTitle .= qq{
        <u>Secondary Metabolite Name</u>: $npName<br/>
    } if ( $npName );
    $subTitle .= qq{
        <u>Secondary Metabolite Activity</u>: $npActivity<br/>
    } if ( $npActivity );

    my $bct_str;
    if ( scalar @bcTypes > 0) {
	$bct_str = join(";", @bcTypes);
	if (scalar @bcTypes == 1) {
	    # comes back as comma-separated str
	    my @types = split(",", @bcTypes[0]);
	    $bct_str = join(";", @types);
	    $bct_str = @bcTypes[0] 
		if $bcsearch_type eq "inexact_and" || 
		   $bcsearch_type eq "inexact_or";
	}

	$subTitle .= 
	    "<u>Biosynthetic Enzymatic Activity Type</u>: "
	    . $bct_str." (Exact)<br/>" if $bcsearch_type eq "exact";
	$subTitle .= 
	    "<u>Biosynthetic Enzymatic Activity Type</u>: "
	    . $bct_str." (Inexact \"AND\")<br/>" 
	    if $bcsearch_type eq "inexact_and";
	$subTitle .= 
	    "<u>Biosynthetic Enzymatic Activity Type</u>: "
	    . $bct_str." (Inexact \"OR\")<br/>" 
	    if $bcsearch_type eq "inexact_or";
    }

    $subTitle .= qq{
        <u>Evidence</u>: $evidence<br/>
    } if ( $evidence );
    if ( $from_probability || $to_probability ) {
        $subTitle .= qq{
            <u>Probability</u>: 
        };
        $subTitle .= qq{
            from $from_probability
        } if ($from_probability);
        $subTitle .= qq{
            to $to_probability
        } if ($to_probability);
        $subTitle .= qq{
            <br/>
        };
    }
    if ( $from_length || $to_length ) {
        $subTitle .= qq{
            <u>Length Range</u>: 
        };
        $subTitle .= qq{
            from $from_length
        } if ($from_length);
        $subTitle .= qq{
            to $to_length
        } if ($to_length);
        $subTitle .= qq{
            <br/>
        };
    }
    if ( $from_gene_cnt || $to_gene_cnt ) {
        $subTitle .= qq{
            <u>Gene Count</u>: 
        };
        $subTitle .= qq{
            from $from_gene_cnt
        } if ($from_gene_cnt);
        $subTitle .= qq{
            to $to_gene_cnt
        } if ($to_gene_cnt);
        $subTitle .= qq{
            <br/>
        };
    }
    $subTitle .= qq{
        <u>Pfam ID (list)</u>: $pfamSearchTerm<br/>
    } if ( $pfamSearchTerm );
    if ( scalar(@genomeFilterSelections) > 0 ) {
        my $selectedCnt = scalar(@genomeFilterSelections);
        $subTitle .= qq{
            <u>Phylogenetic Option</u>: $selectedCnt genomes selected<br/>
        };
    }
    if ( scalar(@npTypes) > 0 ) {
        my $selectedCnt = scalar(@npTypes);
        $subTitle .= qq{
            <u>Secondary Metabolite Type</u>: $selectedCnt selected<br/>
        };
    }

    my $dbh = dbLogin();

    my $rclause   = WebUtil::urClause('g.taxon');
    my $imgClause;# = WebUtil::imgClauseNoTaxon('g.taxon');
    my %validTaxons = WebUtil::getAllTaxonsHashed( $dbh );
    
    my @binds;
    
    my $npNameClause;
    if ( $npName ) {
        my $npNameLc = lc($npName);
        $npNameClause = qq{
            and g.cluster_id in (
                select np.cluster_id
                from np_biosynthesis_source np, img_compound c
                where np.compound_oid = c.compound_oid
                and lower(c.compound_name) like ?
            )
        };
        push(@binds, "%$npNameLc%");        
    }

    my $npActivityClause;
    if ( $npActivity ) {
        $npActivityClause = qq{
            and g.cluster_id in (
                select np.cluster_id
                from np_biosynthesis_source np, 
                     img_compound_activity ia, mesh_dtree md
                where np.compound_oid = ia.compound_oid
                and ia.activity = md.node
                and md.name = ?
            )
        };
        push(@binds, $npActivity);        
    }

    my $attributeClause;
    if ( $evidence || $from_probability || $to_probability || 
	 $from_length || $to_length || scalar @bcTypes > 0) {

        my $bcids_length_clause;
        if ( $from_length || $to_length ) {
            my $lengthSql .= qq{
                select cluster_id, start_coord, end_coord
                from bio_cluster_new
            };
            my $cur = execSql( $dbh, $lengthSql, $verbose );
            
            my %bcid_h;
            my %bcid2end;
            for ( ;; ) {
                my ( $bc_id, $start_coord, $end_coord ) = $cur->fetchrow();
                last if !$bc_id;        
        
                $bcid2end{$bc_id} = $end_coord;
                
		my $start = $start_coord;
		my $end = $bcid2end{$bc_id};
		if ( $end && $start ) {
		    my $length;
		    if ( $end >= $start ) {
			$length = $end - $start;                            
		    }
		    else {
			$length = $start - $end;
		    }
		    
		    if ( $from_length && $to_length ) {
			if ( $length >= $from_length && $length <= $to_length ) {
			    $bcid_h{$bc_id} = 1;
			}
		    }
		    elsif ( $from_length ) {
			if ( $length >= $from_length ) {
			    $bcid_h{$bc_id} = 1;
			}                            
		    }
		    elsif ( $to_length ) {
			if ( $length <= $to_length ) {
			    $bcid_h{$bc_id} = 1;
			}
		    }
		}
		
            }
            $cur->finish();

            my @bcids_length = keys %bcid_h;
            if ( scalar(@bcids_length) > 0 ) {
                my $bcids_str = OracleUtil::getFuncIdsInClause
		    ( $dbh, @bcids_length );
                $bcids_length_clause = " and bcd.cluster_id in ($bcids_str) ";
            }
        }

        my $attributeSql;
        if ( scalar @bcTypes > 0 ) {
	    if ($bcsearch_type eq "exact") {
		$attributeSql .= qq{
                    select bcd.cluster_id
                    from bio_cluster_data_new bcd
                    where bcd.bc_type = '$bct_str'
                    $bcids_length_clause
                };
	    } else {
		my @types = split(",", @bcTypes[0]);
		my $sql;
		foreach my $type (@types) {
		    if (! WebUtil::blankStr($sql)) {
			if ($bcsearch_type eq "inexact_and") {
			    $sql .= " INTERSECT " ;
			} elsif ($bcsearch_type eq "inexact_or") {
			    $sql .= " UNION ";
			}
		    }

		    $sql .= qq {
                        select bcd.cluster_id
                        from bio_cluster_data_new bcd
                        where bcd.bc_type LIKE '%$type%'
                        $bcids_length_clause
                    };
		}

		$attributeSql .= $sql;
	    }
        }
        
        if ( $evidence ) {
            if ( ! WebUtil::blankStr($attributeSql) ) {
                $attributeSql .= qq{
                    INTERSECT
                }
            }
            $attributeSql .= qq{
                select bcd.cluster_id
                from bio_cluster_data_new bcd
                where bcd.evidence = ?
                $bcids_length_clause
            };
            #push(@binds, 'EVIDENCE');
            push(@binds, $evidence);
        }
        
        if ( $from_probability || $to_probability ) {
            if ( ! WebUtil::blankStr($attributeSql) ) {
                $attributeSql .= qq{
                    INTERSECT
                }
            }

            #push(@binds, 'PROBABILITY');

            my $from_probability_clause;
            if ( $from_probability ) {
                $from_probability_clause = "and bcd.probability >= ? ";
                push(@binds, $from_probability);
            }

            my $to_probability_clause;
            if ( $to_probability ) {
                $to_probability_clause = "and bcd.probability <= ? ";
                push(@binds, $to_probability);
            }
            
            $attributeSql .= qq{
                select bcd.cluster_id
                from bio_cluster_data_new bcd
                where 1 = 1
                $from_probability_clause
                $to_probability_clause
                $bcids_length_clause
            };
        }

        if ( $attributeSql ) {
            $attributeClause = qq{
                and g.cluster_id in (
                    $attributeSql
                )
            }            
        }
    }

    my $geneCntClause;
    if ( $from_gene_cnt || $to_gene_cnt ) {
        my $sql = qq{
            select bcf.cluster_id, count(distinct bcf.feature_id)
            from bio_cluster_features_new bcf
            where bcf.feature_type = 'gene'
            group by bcf.cluster_id
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        
        my %bcid2geneCnt;
        for ( ;; ) {
            my ($cluster_id, $gene_count) = $cur->fetchrow();
            last if !$cluster_id;
            if ( $from_gene_cnt && $to_gene_cnt ) {
                if ( $gene_count >= $from_gene_cnt && 
		     $gene_count <= $to_gene_cnt ) {
                    $bcid2geneCnt{$cluster_id} = $gene_count;
                }
            }
            elsif ( $from_gene_cnt ) {
                if ( $gene_count >= $from_gene_cnt ) {
                    $bcid2geneCnt{$cluster_id} = $gene_count;
                }                            
            }
            elsif ( $to_gene_cnt ) {
                if ( $gene_count <= $to_gene_cnt ) {
                    $bcid2geneCnt{$cluster_id} = $gene_count;
                }
            }
        }
        $cur->finish();

        my @bcids_gene_cnt = keys %bcid2geneCnt;
        if ( scalar(@bcids_gene_cnt) > 0 ) {
            my $bcids_str = OracleUtil::getFuncIdsInClause1
		( $dbh, @bcids_gene_cnt );
            $geneCntClause = " and bcf.cluster_id in ($bcids_str) ";
        }
    }

    my $pfamClause;
    my $pfamFrom;
    if ( $pfamSearchTerm ) {
        my $idWhereClause = OracleUtil::addIdWhereClause
	    ( '', '', $pfamSearchTerm, '', '', '', 1 );
        $pfamClause = qq{
            and g.taxon = gpf.taxon
            and bcf.GENE_OID = gpf.gene_oid
            and gpf.PFAM_FAMILY in ( $idWhereClause )
        };
        $pfamFrom = ', GENE_PFAM_FAMILIES gpf';
    }
        
    my $taxonClause;
    if ( scalar(@genomeFilterSelections) > 0 ) {
        $taxonClause = OracleUtil::getTaxonOidClause
	    ($dbh, "g.taxon", \@genomeFilterSelections);        
        #OracleUtil::execDbmsStats($dbh, 'gtt_num_id');
    }

    my $npTypeClause;
    if ( scalar(@npTypes) > 0 ) {
        my $npTypes_str = OracleUtil::getFuncIdsInClause2( $dbh, @npTypes );
        $npTypeClause = qq{
            and g.cluster_id in (
                select np.cluster_id
                from np_biosynthesis_source np, img_compound c, 
                     img_compound_meshd_tree icmt, mesh_dtree md
                where np.compound_oid = c.compound_oid
                and c.compound_oid = icmt.compound_oid
                and icmt.node = md.node
                and md.node in ($npTypes_str)
            )
        };
    }
    #print "printBiosyntheticSearchResult() prepared clause " . currDateTime() . "<br/>\n";
    
    my $sql = qq{
        select distinct g.cluster_id, g.taxon
        from bio_cluster_new g, bio_cluster_features_new bcf $pfamFrom
        where g.cluster_id = bcf.cluster_id
        $npNameClause
        $npActivityClause
        $attributeClause
        $geneCntClause
        $pfamClause
        $taxonClause
        $npTypeClause
        $rclause
        $imgClause
        
    };
    # order by g.cluster_id, g.taxon
    #print "printBiosyntheticSearchResult() sql: $sql<br/>";
    #print "printBiosyntheticSearchResult() binds: @binds<br/>";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $cnt = 0;
    my $trunc = 0;
    my %bcid2taxons;
    for ( ;; ) {
        my ( $bc_id, $taxon ) = $cur->fetchrow();
        last if !$bc_id;
        
        next if(!exists $validTaxons{$taxon});

        my $taxons_ref = $bcid2taxons{$bc_id};
        if ( $taxons_ref ) {
            push(@$taxons_ref, $taxon);
        }
        else {
            my @taxons = ($taxon);
            $bcid2taxons{$bc_id} = \@taxons;
            $cnt++;
        }
        if ( $cnt >= $clusterLimit ) {
            $trunc = 1;
            last;
        }
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $taxonClause =~ /gtt_num_id/i ); 
    OracleUtil::truncTable( $dbh, "gtt_func_id1" ) 
        if ( $geneCntClause =~ /gtt_func_id1/i ); 
    OracleUtil::truncTable( $dbh, "gtt_func_id2" ) 
        if ( $npTypeClause =~ /gtt_func_id2/i ); 
    #print "printBiosyntheticSearchResult() $cnt clusters retrieved " . currDateTime() . "<br/>\n";

    if ( $cnt == 0 ) {
        printMainForm();
        print "<h1>$title</h1>";
        print "<p>$subTitle</p>";        
        WebUtil::printNoHitMessage();
        printStatusLine( "$cnt Biosynthetic Clusters retrieved.", 2 );
        print end_form();
        return;
    }

    my $truncMsg;
    if ( $trunc ) {
        $truncMsg = "Results limited to $clusterLimit Biosynthetic Clusters.";
        $subTitle .= "<font color='red'>$truncMsg</font>";
    }
    
    webLog("Done search - now getting details\n");    
    require BiosyntheticDetail;
    my $count = BiosyntheticDetail::processBiosyntheticClusters
	( $dbh, '', '', \%bcid2taxons, $title, $subTitle );
    if ( $trunc ) {
        printStatusLine( $truncMsg, 2 );
    }
    #print "printBiosyntheticSearchResult() detail page done " . currDateTime() . "<br/>\n";
}

1;
