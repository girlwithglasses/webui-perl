#
#
# $Id: NaturalProductSearch.pm 31620 2014-08-27 04:30:27Z jinghuahuang $
#
package NaturalProductSearch;

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
# printNaturalProductSearchForm - Show Secondary Metabolite search form.
#   Read from template file and replace some template components.
############################################################################
sub printNaturalProductSearchForm {
    my ( $includeJS ) = @_;

    printMainForm();
    if ( $includeJS ) {
        print qq{
            <h1>Secondary Metabolite (SM) Search by Attributes</h1>
            <script language='JavaScript' type='text/javascript' src='$base_url/validation.js'>
            </script>
        };        
    } else {
	print "<br/>";
    }

    my $checkboxSelectionMode = 1;
    my $result_page = "$main_cgi?section=BcSearch&page=npSearchResult";
    
    my $templateFile = "$base_dir/naturalProductSearch.html";
    my $rfh = newReadFileHandle( $templateFile, "printNaturalProductSearchForm" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
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
            onclick="showButtonClicked('$base_url', '$xml_cgi', $checkboxSelectionMode, 'np');">
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
        <div id="treedivNpPhylo"></div>
        <div id="treediv1NpPhylo" $checkboxSelectionYUIClass></div>
        <script type="text/javascript">
        printEmptyPhylo('np');
        </script>
    };

}


############################################################################
# printNpActivityOptionList - Print options for SM type.
############################################################################
sub printNpActivityOptionList {

    my $sql = qq{
        select distinct md.name
        from mesh_dtree md, img_compound_activity ia, np_biosynthesis_source nbs
        where md.node = ia.activity
        and ia.compound_oid = nbs.compound_oid
        order by md.name
    };

    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose );
    
    my @np_activities;
    for ( ; ; ) {
        my ( $md_name ) = $cur->fetchrow();
        last if !$md_name;
        push(@np_activities, $md_name);
    }
    $cur->finish();
    
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
# printNpTypeOption - Print options for SM type.
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
                showButtonClicked('$base_url', '$xml_cgi', $checkboxSelectionMode, 'np');
            }
            
        </script>
    };
}


############################################################################
# printNaturalProductSearchResult
############################################################################
sub printNaturalProductSearchResult {

    if ( !$enable_biocluster ) {
        WebUtil::webError("Secondary Metabolite not supported!");
    }

    my @genomeFilterSelections = OracleUtil::processTaxonSelectionParam("genomeFilterSelections");
    
    my $npName = param("npName");
    if ( $npName ) {
        WebUtil::processSearchTermCheck( $npName, 'Secondary Metabolite Name' );
        $npName = WebUtil::processSearchTerm( $npName, 1 );
    }
    my $npActivity = param("npActivity");
    my @npTypes = OracleUtil::processTaxonSelectionParam("npTypes");
    my $formula = param("formula");
    if ( $formula ) {
        WebUtil::processSearchTermCheck( $formula, 'Formula' );
        $formula = WebUtil::processSearchTerm( $formula, 1 );
    }

    my $from_num_atoms = param("from_num_atoms");
    $from_num_atoms = WebUtil::processSearchTerm( $from_num_atoms ) 
        if ( $from_num_atoms );
    my $to_num_atoms = param("to_num_atoms");
    $to_num_atoms = WebUtil::processSearchTerm( $to_num_atoms ) 
        if ( $to_num_atoms );
    if ( $from_num_atoms || $to_num_atoms ) {
        if ( $from_num_atoms ) {
            WebUtil::webError("Invalid Number of Atoms (From)") 
                if (!WebUtil::isInt($from_num_atoms));
            if ( $from_num_atoms < 0 ) {
                #$from_num_atoms = 0;
                WebUtil::webError("Number of Atoms (From) value not valid. Only none-negative integers are accepted.");
            }
        }
        if ( $to_num_atoms ) {
            WebUtil::webError("Invalid Number of Atoms (To)") 
                if (!WebUtil::isInt($to_num_atoms));
            if ( $to_num_atoms < 0 ) {
                #$to_num_atoms = 0;
                WebUtil::webError("Number of Atoms (To) value not valid. Only none-negative integers are accepted.");
            }
        }
        if ( $from_num_atoms && $to_num_atoms
            && $from_num_atoms > $to_num_atoms ) {
            my $to = $from_num_atoms;
            $from_num_atoms = $to_num_atoms;
            $to_num_atoms = $to;
        }
    }

    my $from_mol_weight = param("from_mol_weight");
    $from_mol_weight = WebUtil::processSearchTerm( $from_mol_weight ) 
        if ( $from_mol_weight );
    my $to_mol_weight = param("to_mol_weight");
    $to_mol_weight = WebUtil::processSearchTerm( $to_mol_weight ) 
        if ( $to_mol_weight );
    if ( $from_mol_weight || $to_mol_weight ) {
        if ( $from_mol_weight ) {
            WebUtil::webError("Invalid Molecular Weight (From)") 
                if (!WebUtil::isNumber($from_mol_weight));
            if ( $from_mol_weight < 0 ) {
                #$from_mol_weight = 0;
                WebUtil::webError("Molecular Weight (From) value not valid. Only none-negative numbers are accepted.");
            }
        }
        if ( $to_mol_weight ) {
            WebUtil::webError("Invalid Molecular Weight (To)") 
                if (!WebUtil::isNumber($to_mol_weight));
            if ( $to_mol_weight < 0 ) {
                #$to_mol_weight = 0;
                WebUtil::webError("Molecular Weight (To) value not valid. Only none-negative numbers are accepted.");
            }
        }
        if ( $from_mol_weight && $to_mol_weight
            && $from_mol_weight > $to_mol_weight ) {
            my $to = $from_mol_weight;
            $from_mol_weight = $to_mol_weight;
            $to_mol_weight = $to;
        }
    }

    if ( scalar(@genomeFilterSelections) <= 0 
        && !$npName
        && !$npActivity
        && scalar(@npTypes) <= 0
        && !$formula
        && !$from_num_atoms
        && !$to_num_atoms
        && !$from_mol_weight
        && !$to_mol_weight ) {
        webError("Please make selections!");
    }

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $title = "Secondary Metabolite (SM) Search Results by Fields";
    my $subTitle;
    $subTitle .= qq{
        <u>Secondary Metabolite Name</u>: $npName<br/>
    } if ( $npName );
    $subTitle .= qq{
        <u>Secondary Metabolite Activity</u>: $npActivity<br/>
    } if ( $npActivity );
    if ( scalar(@npTypes) > 0 ) {
        my $selectedCnt = scalar(@npTypes);
        $subTitle .= qq{
            <u>Secondary Metabolite Type</u>: $selectedCnt selected<br/>
        };
    }
    if ( scalar(@genomeFilterSelections) > 0 ) {
        my $selectedCnt = scalar(@genomeFilterSelections);
        $subTitle .= qq{
            <u>Phylogenetic Option</u>: $selectedCnt genomes selected<br/>
        };
    }
    $subTitle .= qq{
        <u>Formula</u>: $formula<br/>
    } if ( $formula );
    if ( $from_num_atoms || $to_num_atoms ) {
        $subTitle .= qq{
            <u>Number of Atoms</u>: 
        };
        $subTitle .= qq{
            from $from_num_atoms
        } if ($from_num_atoms);
        $subTitle .= qq{
            to $to_num_atoms
        } if ($to_num_atoms);
        $subTitle .= qq{
            <br/>
        };
    }
    if ( $from_mol_weight || $to_mol_weight ) {
        $subTitle .= qq{
            <u>Molecular Weight</u>: 
        };
        $subTitle .= qq{
            from $from_mol_weight
        } if ($from_mol_weight);
        $subTitle .= qq{
            to $to_mol_weight
        } if ($to_mol_weight);
        $subTitle .= qq{
            <br/>
        };
    }

    print "<h1>$title</h1>";
    print "<p>$subTitle</p>";        

    my $dbh = dbLogin();

    my $rclause   = WebUtil::urClause('nbs.taxon_oid');
    my $imgClause = WebUtil::imgClauseNoTaxon('nbs.taxon_oid');
    
    my @binds;

    my $imgCompoundClause;
    if ( $npName || $formula || $from_num_atoms || $to_num_atoms || $from_mol_weight || $to_mol_weight ) {

        my $imgCompoundSql = qq{
            select np.compound_oid
            from np_biosynthesis_source np, img_compound c
            where np.compound_oid = c.compound_oid
        };
        
        if ( $npName ) {
            my $npNameLc = lc($npName);
            $imgCompoundSql .= qq{
                and lower(c.compound_name) like ?
            };
            push(@binds, "%$npNameLc%");        
        }

        if ( $formula ) {
            my $formulaLc = lc($formula);
            $imgCompoundSql .= qq{
                and lower(c.formula) like ?
            };
            push(@binds, "%$formulaLc%");        
        }

        if ( $from_num_atoms || $to_num_atoms ) {
            my $from_num_atoms_clause;
            if ( $from_num_atoms ) {
                $from_num_atoms_clause = "and c.num_atoms >= ? ";
                push(@binds, $from_num_atoms);
            }

            my $to_num_atoms_clause;
            if ( $to_num_atoms ) {
                $to_num_atoms_clause = "and c.num_atoms <= ? ";
                push(@binds, $to_num_atoms);
            }

            $imgCompoundSql .= qq{
                $from_num_atoms_clause
                $to_num_atoms_clause
            };
            
        }

        if ( $from_mol_weight || $to_mol_weight ) {
            my $from_mol_weight_clause;
            if ( $from_mol_weight ) {
                $from_mol_weight_clause = "and c.mol_weight >= ? ";
                push(@binds, $from_mol_weight);
            }

            my $to_mol_weight_clause;
            if ( $to_mol_weight ) {
                $to_mol_weight_clause = "and c.mol_weight <= ? ";
                push(@binds, $to_mol_weight);
            }

            $imgCompoundSql .= qq{
                $from_mol_weight_clause
                $to_mol_weight_clause
            };
            
        }

        if ( $imgCompoundSql ) {
            $imgCompoundClause = qq{
                and nbs.compound_oid in (
                    $imgCompoundSql
                )
            }            
        }
        
    }

    my $npActivityClause;
    if ( $npActivity ) {
        $npActivityClause = qq{
            and nbs.compound_oid in (
                select np.compound_oid
                from np_biosynthesis_source np, img_compound_activity ia, mesh_dtree md
                where np.compound_oid = ia.compound_oid
                and ia.activity = md.node
                and md.name = ?
            )
        };
        push(@binds, $npActivity);        
    }
    
    my $taxonClause;
    if ( scalar(@genomeFilterSelections) > 0 ) {
        $taxonClause = OracleUtil::getTaxonOidClause($dbh, "nbs.taxon_oid", \@genomeFilterSelections);
    }
        
    my $npTypeClause;
    if ( scalar(@npTypes) > 0 ) {
        my $npTypes_str = OracleUtil::getFuncIdsInClause2( $dbh, @npTypes );
        $npTypeClause = qq{
            and nbs.compound_oid in (
                select np.compound_oid
                from np_biosynthesis_source np, img_compound c, img_compound_meshd_tree icmt, mesh_dtree md
                where np.compound_oid = c.compound_oid
                and c.compound_oid = icmt.compound_oid
                and icmt.node = md.node
                and md.node in ($npTypes_str)
            )
        };
    }

    my $sql = qq{
        select distinct nbs.compound_oid, nbs.taxon_oid
        from np_biosynthesis_source nbs
        where 1 = 1
        $imgCompoundClause
        $npActivityClause
        $taxonClause
        $npTypeClause
        $rclause
        $imgClause
        order by nbs.compound_oid
    };
    #print "printNaturalProductSearchResult() sql: $sql<br/>";
    #print "printNaturalProductSearchResult() binds: @binds<br/>";

    my $cur = execSql( $dbh, $sql, $verbose, @binds );

    my $cnt = 0;
    my %npid2taxons;
    for ( ;; ) {
        my ( $np_id, $taxon ) = $cur->fetchrow();
        last if !$np_id;

        my $taxons_ref = $npid2taxons{$np_id};
        if ( $taxons_ref ) {
            push(@$taxons_ref, $taxon);
        }
        else {
            my @taxons = ($taxon);
            $npid2taxons{$np_id} = \@taxons;
        }
        $cnt++;
    }
    $cur->finish();
    OracleUtil::truncTable( $dbh, "gtt_num_id" ) 
        if ( $taxonClause =~ /gtt_num_id/i ); 
    OracleUtil::truncTable( $dbh, "gtt_func_id2" ) 
        if ( $npTypeClause =~ /gtt_func_id2/i ); 

    #print "printNaturalProductSearchResult() npid2taxon<br/>\n";
    #print Dumper(\%npid2taxons);
    #print "<br/>\n";

    if ( $cnt == 0 ) {
        WebUtil::printNoHitMessage();
        printStatusLine( "$cnt Secondary Metabolites retrieved.", 2 );
    }
    else {
        require NaturalProd;
        my $count = NaturalProd::printNaturalProducts( $dbh, \%npid2taxons );
        printStatusLine( "$count retrieved.", 2 );
    }

    print end_form();
}

1;
