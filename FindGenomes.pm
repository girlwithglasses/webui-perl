############################################################################
# FindGenomes.pm - Formerly taxonList.pl
#  Handle the options under the "Find Genomes" tab menu.
#    --es 07/07/2005
#
# $Id: FindGenomes.pm 33878 2015-08-03 17:14:58Z jinghuahuang $
############################################################################
package FindGenomes;
my $section = "FindGenomes";
use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use OracleUtil;
use TaxonSearchUtil;
use TaxonSearch;
use TaxonList;
use PhyloNode;
use PhyloTreeMgr;
use TermNode;
use TermNodeMgr;
use DataEntryUtil;
use GoldDataEntryUtil;
use Data::Dumper;
use TabViewFrame;
use FindGenomesByMetadata;
use TaxonTableConfiguration;
use HtmlUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $tmp_dir              = $env->{tmp_dir};
my $base_dir             = $env->{base_dir};

my $taxonomy_base_url    = $env->{taxonomy_base_url};
my $user_restricted_site = $env->{user_restricted_site};
my $img_internal         = $env->{img_internal};
my $img_lite             = $env->{img_lite};
my $include_metagenomes  = $env->{include_metagenomes};
my $cgi_tmp_dir          = $env->{cgi_tmp_dir};
my $in_file              = $env->{in_file};
my $img_er_submit_url    = $env->{img_er_submit_url};
my $img_mer_submit_url   = $env->{img_mer_submit_url};

### optional genome field columns to configuration and display 
my @optCols = getGenomeFieldAttrs();

my %colName2Label = getColName2Label_g();

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    #print "FindGenomes::dispatch() page:$page<br/>\n";

    if ( $page eq "genomeSearch" ) {
	    printGenomeSearchForm();
    } elsif ( $page eq "findGenomeResults") {
          my $redisplay = param('redisplay');
          if ( $redisplay ne 1 ) {
                printFindGenomeResults();
          } else {
                my $genome_filename = param('genomeListFile');
                my $taxon_oids_aref = WebUtil::getArrayFromFile($genome_filename, 1, 1);
                #my $column_filename = param('columnListFile');
                #my $columns_aref = WebUtil::getArrayFromFile($column_filename, 1, 1);
                my $title = "Genome Field Search Results";
                require GenomeList;
                GenomeList::printGenomesViaList( $taxon_oids_aref, '', 
                        $title, $genome_filename, 'findGenomeResultsRedisplay' );
          }
    } elsif ( paramMatch("setTaxonOutputCol") ne "" ) {
        printFindGenomeResults('Yes');
    } elsif ( $page eq "metadataCategorySearchResults" ) {
        FindGenomesByMetadata::printMetadataCategorySearchResults();
    } elsif ( $page eq "metadataCategoryOperationResults" ) {
	    FindGenomesByMetadata::printMetadataCategoryOperationResults();
    } elsif ( $page eq "metadataCategoryChartResults" ||
        paramMatch("metadataCategoryChartResults") ne "" ) {
	    FindGenomesByMetadata::printMetadataCategoryChartResults();
    } elsif ( $page eq "geneList" ) {
        printGeneList();
    } else {
        TaxonList::printTaxonTable();
    }
}

############################################################################
# printGenomeSearchForm - Print find genomes page.
############################################################################
sub printGenomeSearchForm {
    print "<h1>Genome Search</h1>\n";

    TabViewFrame::printTabViewMarkup();
    FindGenomesByMetadata::printTreeViewMarkup();

    my @tabNames = ("by Fields", "by Metadata Categories", 
		    "by Metadata Category Operation",
	"by Metadata Category Chart");
    my @tabIds = TabViewFrame::printTabViewWidgetStart(@tabNames);

    TabViewFrame::printTabIdDivStart($tabIds[0]);
    printFieldForm();
    TabViewFrame::printTabIdDivEnd();

    TabViewFrame::printTabIdDivStart($tabIds[1]);
    FindGenomesByMetadata::printMetadataCategorySearchForm();
    TabViewFrame::printTabIdDivEnd();
    #TabViewFrame::printTabIdDiv_NoneActive($tabIds[1]);
    TabViewFrame::printTabIdDiv_NoneActive($tabIds[2]);
    TabViewFrame::printTabIdDiv_NoneActive($tabIds[3]);

    TabViewFrame::printTabViewWidgetEnd();
}

sub printFieldForm {
    printStatusLine( "Loading ...", 1 );

    my $templateFile = "$base_dir/findGenomes.html";
    my $rfh = newReadFileHandle( $templateFile, "printGenomeSearchForm" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        $s =~ s/__main_cgi__/$section_cgi/g;
        if ( $s =~ /__optionList__/ ) {
            printFoOptionList();
        } elsif ( $s =~ /__hint__/ ) {
            printPageHint();
        } else {
            print "$s\n";
        }
    }
    close $rfh;

    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printFoOptionList - Print option list for "Fo" (find organisms).
############################################################################
sub printFoOptionList {
    print qq{
       <option value="taxon_display_name">Genome Name</option>
       <option value="proposal_name">Study Name</option>
       <option value="ncbi_taxon_id">NCBI Taxon ID (list)</option>
       <option value="refseq_project_id">RefSeq Project ID (list)</option>
       <option value="gbk_project_id">GenBank Project ID (list)</option>
       <option value="ext_accession">Scaffold External Accession (list)</option>
       <option value="scaffold_oid">Scaffold ID (list)</option>
       <option value="taxon_oid">IMG Genome ID (IMG Taxon ID) (list)</option>
       <option value="submission_id">IMG Submission ID (list)</option>
       <option value="jgi_project_id">JGI Project ID (list)</option>
       <option value="domain">Domain</option>
       <option value="phylum">Phylum</option>
       <option value="seq_status">Sequencing Status</option>
       <option value="seq_center">Sequencing Center</option>
       <option value="funding_agency">Funding Agency</option>
       <option value="img_version">IMG Release</option>
    };
    if ($img_internal) {
        print qq{
           <option value="is_public">Is Public</option>
           <option value="jgi_project_id">JGI Project ID (list)</option>
           <option value="cog_id">COG ID (exact)</option>
           <option value="cog_name">COG Name</option>
           <option value="pfam_id">Pfam ID (exact)</option>
           <option value="pfam_name">Pfam Name</option>
      };
    }
    print qq{
       <option value="all" title="aka Quick Genome Search">All field names*</option>
    };
}

############################################################################
# printOptionColumn - Show option of extra display columns 
############################################################################
sub printOptionColumn {

    my $treeId = "optionColumns";
    print "<div id='$treeId' class='ygtv-checkbox'>\n";
    print "</div>\n";

    my $jsObject = "{label:'<b>Additional Output Columns</b>', children: [";    
    for (my $i = 0; $i < scalar(@optCols); $i++) {
    	my $key = $optCols[$i];
        next if ($key eq 'taxon_display_name' || $key eq 'domain' || $key eq 'seq_status');

        if ($i != 0) {
            $jsObject .= ", ";
        }
        my $val = $colName2Label{$key};
        #print "$key => $val\n";
        #my $myLabel = "<input type='checkbox' name='outputCol' value='$key' />$val";
        #$jsObject .= "{id:\"$key\", label:\"$myLabel\"}";
        $jsObject .= "{id:\"$key\", label:\"$val\"}";
    }
    $jsObject .= "]}";

    my $categoriesObj = "{category:[{name:'$treeId', value:[" . $jsObject . "]}]}";
    #webLog("$categoriesObj\n");
    #print "$categoriesObj\n";

    print qq{
        <script type="text/javascript">
           setMoreJSObjects($categoriesObj);
           moreTreeInit();
        </script>
    };
    
    if ($img_internal) {
        print qq{
           <span><font color='red'>(not applied to 'COG ID', 'COG Name', 'Pfam ID', 'Pfam Name' searches)</font></span>
      };
    }
    
}

############################################################################
# printFindGenomeResults - Show expanded results of find genomes search.
############################################################################
sub printFindGenomeResults {

    ### process input
    my ($expanded) = @_;

    my $taxonSearchFilter = param("taxonSearchFilter");
    my $taxonSearchTerm   = param("taxonSearchTerm");
    #print "printFindGenomeResults() taxonSearchFilter: $taxonSearchFilter<br/>\n";
    #print "printFindGenomeResults() taxonSearchTerm: $taxonSearchTerm<br/>\n";
    if ($expanded ne 'Yes') {
	    WebUtil::processSearchTermCheck($taxonSearchTerm);
	    $taxonSearchTerm = WebUtil::processSearchTerm($taxonSearchTerm, 1);      
    }
    my $taxonSearchTermLc = $taxonSearchTerm;
    $taxonSearchTermLc =~ tr/A-Z/a-z/;

    ### For all fields searches (redirect elsewhere)
    if ( $taxonSearchFilter eq "all" && $taxonSearchTerm ne '' ) {
        param( -name => "taxonTerm", -value => $taxonSearchTerm );
        TaxonSearch::printTaxonList();
        return;
    }
 
    ### For these 4 filter types (redirect elsewhere)
    my @filter_types = ( "cog_id", "pfam_id", "cog_name", "pfam_name");
    if ( grep( /^$taxonSearchFilter$/, @filter_types ) ) {
        printProteinGenomeResults( $taxonSearchFilter, $taxonSearchTermLc );
        return;
    } 

    ### For all other filter types (done here)
    printMainForm();
    print "<h1>Genome Field Search Results</h1>\n";
    print hiddenVar( 'taxonTerm', $taxonSearchTerm );
    print hiddenVar( 'taxonSearchFilter', $taxonSearchFilter );

    ### outputCol: columns to display in addition to default columns and the searched column
    my @taxonColumns           = param('genome_field_col');    # empty if not redisplay
    my @projectMetadataColumns = param('metadata_col');        # empty if not redisplay
    my @sampleMetadataColumns  = param('sample_metadata_col'); # empty if not redisplay
    my @statsColumns           = param('stats_col');           # empty if not redisplay

    # add columns always displayed
    #my @defaults = ( 'domain', 'seq_status', 'proposal_name', 'taxon_display_name', 'seq_center' );
    #push( @taxonColumns, @defaults );
    my @defaults = ( 'total_bases', 'total_gene_count' );
    push( @statsColumns, @defaults );

    # columns to be displayed this time
    my @outputCol;
    push( @outputCol, @taxonColumns );
    push( @outputCol, @projectMetadataColumns );
    push( @outputCol, @sampleMetadataColumns );
    push( @outputCol, @statsColumns );
    #print "printFindGenomeResults outputCol: @outputCol<br/>\n";

    my $inFileClause = "'No', ";
    $inFileClause = "tx.in_file, " if ( $in_file );

    ### outColClause: output column clause
    my $outColClause = '';
    my $anyStn       = -1;
    my $mOutStartIdx = -1;
    my @mOutCol      = ();
    for ( my $i = 0 ; $i < scalar(@outputCol) ; $i++ ) {
        my $c = $outputCol[$i];
        my $tableType = TaxonTableConfiguration::findColType($c);
        if ( $tableType eq 'g' ) {
	        if ( $c =~ /add_date/i || $c =~ /release_date/i) {
	              # its a date column
	              # use iso format yyyy-mm-dd s.t. its ascii sortable - ken
                      $outColClause .= ", to_char(tx.$c, 'yyyy-mm-dd') ";
	        } else {
                      $outColClause .= ", tx.$c ";
	        }
        } elsif ( $tableType eq 'm' ) {
                $mOutStartIdx = $i if ( $mOutStartIdx == -1 );
                push( @mOutCol, $c );
        } elsif ( $tableType eq 's' ) {
                $outColClause .= ", stn.$c ";
                $anyStn = 1;
        }
    }
    if ( $mOutStartIdx >= 0 ) {
        $outColClause .= ", tx.sample_gold_id, tx.submission_id, tx.gold_id";
    }
    
    my @genomeFindResults = ();
    if ($expanded eq 'Yes') {
        @genomeFindResults = OracleUtil::processTaxonSelectionParam("taxonOids");
    }

    my ($rclause, @bindList_ur) = WebUtil::urClauseBind('tx');
    my $imgClause = WebUtil::imgClause('tx');

    my @bindList = ();
    my $sql;
    my $dbh = WebUtil::dbLogin();

    if ($expanded eq 'Yes' && scalar(@genomeFindResults) > 0) {
        my ($taxonClause, @bindList_txs) 
          = OracleUtil::getTaxonSelectionClauseBind($dbh, "tx.taxon_oid", \@genomeFindResults);
        my @filter_types = ( "ext_accession", "scaffold_oid" );
        if ( grep( /^$taxonSearchFilter$/, @filter_types ) ) {
            $sql = qq{
                select distinct tx.taxon_oid, tx.domain, tx.seq_status, 
                    tx.proposal_name, tx.taxon_display_name, tx.seq_center, 
                    $inFileClause scf.$taxonSearchFilter $outColClause
                from taxon tx, taxon_stats stn, scaffold scf
                where tx.taxon_oid = stn.taxon_oid
                $taxonClause
                $rclause
                $imgClause
                and scf.taxon = tx.taxon_oid
                order by tx.domain, tx.taxon_display_name
            };
        }
        else {
            $sql = qq{
                select distinct tx.taxon_oid, tx.domain, tx.seq_status, 
                    tx.proposal_name, tx.taxon_display_name, tx.seq_center, 
                   $inFileClause tx.$taxonSearchFilter $outColClause
               from taxon tx, taxon_stats stn
               where tx.taxon_oid = stn.taxon_oid
               $taxonClause
               $rclause
               $imgClause
               order by tx.domain, tx.taxon_display_name
            };
        }
        WebUtil::processBindList(\@bindList, undef, \@bindList_txs, \@bindList_ur);
    }
    else {
	    my $whereClause = "";
        my @filter_types = ( "taxon_oid", "submission_id", "ncbi_taxon_id", "jgi_project_id" );
        if ( grep( /^$taxonSearchFilter$/, @filter_types ) ) {
	        my $term_str;
	        if ($taxonSearchFilter eq "taxon_oid") {
	            $term_str = splitSearchTerm($taxonSearchTerm, 1, 0, 1);         
	        }
	        else {
	            $term_str = splitSearchTerm($taxonSearchTerm, 1, 0);            
	        }
	        $whereClause = "and tx.$taxonSearchFilter in ( $term_str ) ";
	    } elsif ( $taxonSearchFilter eq "scaffold_oid") {
	        my $term_str;
	        $term_str = splitSearchTerm($taxonSearchTerm, 1, 0);
	        $whereClause = "and scf.$taxonSearchFilter in ( $term_str ) ";
	    } elsif ( $taxonSearchFilter eq "ext_accession") {
	        my $term_str;
	        $term_str = splitSearchTerm($taxonSearchTermLc, 0);
	        $whereClause = "and lower(scf.ext_accession) in ( $term_str )";
	    } elsif ( $taxonSearchFilter eq "refseq_project_id"
	        || $taxonSearchFilter eq "gbk_project_id" ) {
	        $whereClause = "and ( ";
	        my $anyNull = 0;
	        if (index($taxonSearchTermLc, 'null') >= 0) {
	            $taxonSearchTerm =~ s/null//gi;
	            $whereClause .= " tx.$taxonSearchFilter is NULL ";
	            $anyNull = 1;
	        }
	        my $term_str;
	        $term_str = splitSearchTerm($taxonSearchTerm, 1, 1);
	        if ( blankStr($term_str) && !$anyNull ) {
	            webError("Please enter a comma separated list of valid ID's.");
	        } elsif ( !blankStr($term_str) ) {
	            if ($anyNull) {
	                $whereClause .= "or ";         
	            }
	            $whereClause .= "tx.$taxonSearchFilter in ( $term_str ) ";
	        }
	        $whereClause .= " )";
	    } else {
	        $whereClause = "and lower( tx.$taxonSearchFilter ) like ? ";        
	        push(@bindList, "%$taxonSearchTermLc%");
	    }
        #print "printFindGenomeResults() whereClause=$whereClause<br/>\n";
	
	    my ($restrictClause, @bindList_res) = TaxonSearchUtil::getPreferenceRestrictClause();
	
	    if ( $taxonSearchFilter eq "ext_accession" || $taxonSearchFilter eq "scaffold_oid") {
	    	if ($anyStn == 1) {
	            $sql = qq{
                    select distinct tx.taxon_oid, tx.domain, tx.seq_status, 
                        tx.proposal_name, tx.taxon_display_name, tx.seq_center, 
	                    $inFileClause scf.$taxonSearchFilter $outColClause
	                from taxon tx, taxon_stats stn, scaffold scf
	                where tx.taxon_oid = stn.taxon_oid
	                $whereClause
	                and scf.taxon = tx.taxon_oid
	                $restrictClause
	                $rclause
	                $imgClause
	                order by tx.domain, tx.taxon_display_name
	            };	    		
	    	}
	    	else {
	            $sql = qq{
                    select distinct tx.taxon_oid, tx.domain, tx.seq_status, 
                        tx.proposal_name, tx.taxon_display_name, tx.seq_center, 
	                    $inFileClause scf.$taxonSearchFilter $outColClause
	                from taxon tx, scaffold scf
	                where 1 = 1
	                $whereClause
	                and scf.taxon = tx.taxon_oid
	                $restrictClause
	                $rclause
	                $imgClause
	                order by tx.domain, tx.taxon_display_name
	            };	    		
	    	}
	    }
	    else {
            if ($anyStn == 1) {
	            $sql = qq{
                   select distinct tx.taxon_oid, tx.domain, tx.seq_status, 
                        tx.proposal_name, tx.taxon_display_name, tx.seq_center, 
	                   $inFileClause tx.$taxonSearchFilter $outColClause
	               from taxon tx, taxon_stats stn
	               where tx.taxon_oid = stn.taxon_oid
	               $whereClause
	               $restrictClause
	               $rclause
	               $imgClause
	               order by tx.domain, tx.taxon_display_name
	            };
            }
            else {
	            $sql = qq{
                   select distinct tx.taxon_oid, tx.domain, tx.seq_status, 
                        tx.proposal_name, tx.taxon_display_name, tx.seq_center, 
	                   $inFileClause tx.$taxonSearchFilter $outColClause
	               from taxon tx
	               where 1 = 1
	               $whereClause
	               $restrictClause
	               $rclause
	               $imgClause
	               order by tx.domain, tx.taxon_display_name
	            };
            }
	    }   
	
	    WebUtil::processBindList(\@bindList, undef, \@bindList_res, \@bindList_ur);
    }
    #print "printFindGenomeResults() sql: $sql<br/>\n";
    #print "printFindGenomeResults() bindList size: ".scalar(@bindList)."<br/>\n";
    #print "printFindGenomeResults() bindList: @bindList<br/>\n";

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@bindList, $verbose );

    ### Retrieve data from SQL output
    my @recs;
    my @tOids;
    my %tOids2SubmissionIds  = (); #submissionIds, goldIds
    my %tOids2ProjectGoldIds = (); # taxon to gold project ids
    my %tOids2GoldIds        = ();
    my %taxons_in_file;

    for ( ; ; ) {
        my ( $taxon_oid, $domain, $seq_status, 
            $proposal_name, $taxon_display_name, $seq_center, 
            $in_file_val, $fieldVal, @outColVals
           ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( $in_file_val eq 'Yes' ) {
            $taxons_in_file{$taxon_oid} = 1;
        }

        my $r = "$taxon_oid\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$proposal_name\t";
        $r .= "$taxon_display_name\t";
        $r .= "$seq_center\t";
        $r .= "$fieldVal\t"; 

        my $nOutColVals = scalar(@outColVals);
        for ( my $j = 0 ; $j < $nOutColVals ; $j++ ) {
            if ( $mOutStartIdx >= 0
                 && ( $j == $nOutColVals - 3 || $j == $nOutColVals - 2 || $j == $nOutColVals - 1 ) )
            {
                if ( $j == $nOutColVals - 2 ) {
                    $tOids2SubmissionIds{$taxon_oid} = $outColVals[$j] if ( $outColVals[$j] ne '' );
                } elsif ( $j == $nOutColVals - 1 ) {
                    $tOids2GoldIds{$taxon_oid} = $outColVals[$j] if ( $outColVals[$j] ne '' );
                    $tOids2ProjectGoldIds{$taxon_oid} = $outColVals[$j] if ( $outColVals[$j] ne '' );
                    # gold id for metagenomes is actually $sample_gold_id - ken
                    # but not all metagenomes have sample_gold_id so the gold_id is
                    # use - but this gold_id is project_info level metadata
                    my $sample_gold_id = $outColVals[$nOutColVals - 3];
                    if ( $sample_gold_id ne "" ) {
                        $tOids2GoldIds{$taxon_oid} = $sample_gold_id;
                    }
                }
            } else {
                if($outColVals[$j] eq '') {
                    # to stop the shift on a blank split
                    $r .= "_\t";
                } else {
                    $r .= "$outColVals[$j]\t";
                }
            }
        }
                
        push( @recs, $r );
        push( @tOids, $taxon_oid );
    }
    $cur->finish();

    my %tOids2Meta = GoldDataEntryUtil::getMetadataForAttrs_new_2_0( 
                  \%tOids2SubmissionIds, \%tOids2GoldIds, 
                  \@mOutCol, \%tOids2ProjectGoldIds )
             if ( $mOutStartIdx >= 0 );

    if ( scalar(@recs) == 0 ) {
        print "<p>0 genomes retrieved.</p>\n";

        my $hideViruses = getSessionParam("hideViruses");
        $hideViruses = "Yes" if $hideViruses eq "";
        my $hidePlasmids = getSessionParam("hidePlasmids");
        $hidePlasmids = "Yes" if $hidePlasmids eq "";
        my $hideGFragment = getSessionParam("hideGFragment");
        $hideGFragment = "Yes" if $hideGFragment eq "";        

        if ($hideGFragment eq "Yes" || $hidePlasmids eq "Yes" || $hideViruses eq "Yes" ) {
            print qq{
                Note your search preference to hide from search results are as follows:<br>
                Hide viruses: $hideViruses<br>
                Hide plasmids: $hidePlasmids<br>
                Hide genome fragment: $hideGFragment<br>
            };
        }          
        
        WebUtil::printStatusLine( "0 genomes retrieved.", 2 );
        return;
    }
    my $txTableName = "GenomeSearch";  # name of current instance of taxon table
    TaxonSearchUtil::printNotes();
    TaxonSearchUtil::printButtonFooter($txTableName);
    print "<br/>";

    my $domain_explain = "*=Microbiome, B=Bacteria, A=Archaea, "
                       . "E=Eukarya, P=Plasmids, G=GFragment, V=Viruses";
    my $status_explain = "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft";
  
    ### Start putting together InnerTable
    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec( "Select" );

    my @myCols = ('domain', 'seq_status', 'taxon_display_name', 'proposal_name', 'seq_center');
    $it->addColSpec( "Domain", "char asc", "center", "", $domain_explain );
    $it->addColSpec( "Status", "char asc", "center", "", $status_explain );
    # always display proposal_name, taxon_display_name, seq_center columns even if it's not searched against
    my $colLabel;    
    $colLabel = TaxonTableConfiguration::getColLabel("proposal_name");
    $it->addColSpec( "$colLabel", "char asc", "left" );
    $colLabel = TaxonTableConfiguration::getColLabel("taxon_display_name");
    $it->addColSpec( "$colLabel", "char asc", "left" );
    $colLabel = TaxonTableConfiguration::getColLabel("seq_center");
    $it->addColSpec( "$colLabel", "char asc", "left" );

    # always display the column searched against if not in myCols
    if ( $taxonSearchFilter ne "proposal_name" 
        && $taxonSearchFilter ne "taxon_display_name" 
        && $taxonSearchFilter ne "seq_center" ) {
        $colLabel = TaxonTableConfiguration::getColLabel($taxonSearchFilter);
        $it->addColSpec( "$colLabel", "char asc", "left" );
        push( @myCols, $taxonSearchFilter);        
    }

    # display additional columns selected in Table Configuration section
    foreach my $col (@outputCol) {
        next if ( grep( /^$col$/, @myCols ) );
        push( @myCols, $col );

        my $colName  = TaxonTableConfiguration::getColLabel($col);
        my $tooltip  = TaxonTableConfiguration::getColTooltip($col);
        my $colAlign = TaxonTableConfiguration::getColAlign($col);
        if ( $colAlign eq "num asc right" ) {
            $it->addColSpec( "$colName", "number asc", "right", '', $tooltip );
        } elsif ( $colAlign eq "num desc right" ) {
            $it->addColSpec( "$colName", "number desc", "right", '', $tooltip );
        } elsif ( $colAlign eq "num desc left" ) {
            $it->addColSpec( "$colName", "number desc", "left", '', $tooltip );
        } elsif ( $colAlign eq "char asc left" ) {
            $it->addColSpec( "$colName", "char asc", "left", '', $tooltip );
        } elsif ( $colAlign eq "char desc left" ) {
            $it->addColSpec( "$colName", "char desc", "left", '', $tooltip );
        } else {
            $it->addColSpec( "$colName", '', '', '', $tooltip );
        }
    }

    my $count = 0;
    my @taxon_oids =  ();
    for my $r (@recs) {
        my ( $taxon_oid, $domain, $seq_status, $proposal_name, $taxon_display_name, $seq_center, 
            $fieldVal, @outColVals ) = split( /\t/, $r );
         if ( $mOutStartIdx >= 0 ) {
            my $mOutColVals_str = $tOids2Meta{$taxon_oid};
            my @mOutColVals = split( /\t/, $mOutColVals_str );
            if ( scalar(@mOutColVals) < scalar(@mOutCol) ) {
                my $diff = scalar(@mOutCol) - scalar(@mOutColVals);
                for ( my $i = 0 ; $i < $diff ; $i++ ) {
                    push( @mOutColVals, '' );
                }
            }
            splice( @outColVals, $mOutStartIdx, 0, @mOutColVals );
        }
        push( @taxon_oids, $taxon_oid );
        $count++;
 
    	my $row;
        $row .= $sd . "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />\t";
        $row .= $domain . $sd . substr( $domain, 0, 1 ) . "\t";
        $row .= $seq_status . $sd . substr( $seq_status, 0, 1 ) . "\t";

        # Always display the proposal_name
        my $mynull = $proposal_name;
        if ( $proposal_name eq "" ) {
            $mynull = "zzz";
            $proposal_name = "_";
        }
        if ( $taxonSearchFilter eq "proposal_name" ) {
            my $matchText = WebUtil::highlightMatchHTML2( $proposal_name, $taxonSearchTerm );
           $row .= $proposal_name . $sd . $matchText . "\t";
        } else {
            $row .= $proposal_name . $sd . $proposal_name . "\t";
        }

    	# Always display the taxon_display_name column
        my $url = $main_cgi;
        if ( $taxons_in_file{$taxon_oid} ) {
            $url .= "?section=MetaDetail&page=metaDetail";
        } else {
            $url .= "?section=TaxonDetail&page=taxonDetail";
        }
        $url .= "&taxon_oid=$taxon_oid";
    	my $link = alink( $url, $taxon_display_name );
    	#$row .= $taxon_display_name . $sd . $link . "\t"
    	#       if $taxonSearchFilter ne "taxon_display_name";
        if ( $taxonSearchFilter eq "taxon_display_name" ) {
            my $matchText = WebUtil::highlightMatchHTML2( $taxon_display_name, $taxonSearchTerm );
           $row .= $taxon_display_name . $sd . alink( $url, $matchText, "", 1 ) . "\t";
        } else {
            $row .= $taxon_display_name . $sd . $link . "\t";
        }

        # Always display the seq_center
        my $seq_center2 = $seq_center;
        if ( $seq_center =~ /JGI/ ) {
            my $x1      = "<font color='red'>";
            my $x2      = "</font>";
            $seq_center2 =~ s/JGI/${x1}JGI${x2}/;
        } elsif ( $seq_center =~ /DOE Joint Genome Institute/ ) {
            my $x1      = "<font color='red'>";
            my $x2      = "</font>";
            $seq_center2 =~ s/DOE Joint Genome Institute/${x1}DOE Joint Genome Institute${x2}/;
        }
        if ( $taxonSearchFilter eq "seq_center" 
        && $taxonSearchTerm !~ /JGI/ 
        && $taxonSearchTerm !~ /DOE Joint Genome Institute/ ) {
            my $matchText = WebUtil::highlightMatchHTML2( $seq_center2, $taxonSearchTerm );
           $row .= $seq_center . $sd . $matchText . "\t";
        } else {
            $row .= $seq_center . $sd . $seq_center2 . "\t";
        }

    	# display the field value
        if ( $taxonSearchFilter ne "taxon_display_name" 
            && $taxonSearchFilter ne "proposal_name" 
            && $taxonSearchFilter ne "seq_center" ) {
            my $matchText;
            my @filter_types = ( "taxon_oid", "submission_id", "ncbi_taxon_id", "jgi_project_id",
                  "refseq_project_id", "gbk_project_id", "ext_accession", "scaffold_oid" );
            if ( grep( /^$taxonSearchFilter$/, @filter_types ) ) {
                $matchText = "<font color='green'><b>" .$fieldVal. "</b></font>";
            } else {
                $matchText = WebUtil::highlightMatchHTML2( $fieldVal, $taxonSearchTerm );
            }        
           $row .= $matchText . $sd . $matchText. "\t";
        }

    	#print "printFindGenomeResults() outputCol : @outputCol <br/>\n";
        for ( my $j = 0; $j < scalar(@outputCol); $j++ ) {
            my $col = $outputCol[$j];
            my $colVal  = $outColVals[$j];
            #print "col=$col: colVal=$colVal<br/>\n";
        
            if ($colVal eq '_' && $col ne 'proposal_name') {
                # shift stop - see above where I add '_' for blanks and in metadata from gold - ken
                 $row .= '-1' . $sd . '_' . "\t";
            } elsif ($col eq 'ncbi_taxon_id' && $colVal) {
                my $ncbiTxid_url = "$taxonomy_base_url$colVal";
                $ncbiTxid_url = alink( $ncbiTxid_url, $colVal );
                $row .= $colVal . $sd . $ncbiTxid_url . "\t";  
            } elsif ($col eq 'refseq_project_id' && $colVal) {
                my $ncbiPid_url = TaxonSearchUtil::getNCBIProjectIdLink($colVal);
                $row .= $colVal . $sd . $ncbiPid_url . "\t";  
            } elsif ($col eq 'gbk_project_id' && $colVal) {
                my $ncbiPid_url = TaxonSearchUtil::getNCBIProjectIdLink($colVal);
                $row .= $colVal . $sd . $ncbiPid_url . "\t";  
            } elsif ($col eq 'gold_id' && $colVal) {
                my $goldId_url = HtmlUtil::getGoldUrl($colVal);
                $goldId_url = alink( $goldId_url, $colVal );
                $row .= $colVal . $sd . $goldId_url . "\t";  
            } elsif ( $col eq 'sample_gold_id' && $colVal ) {
                my $goldId_url = HtmlUtil::getGoldUrl($colVal);
                $goldId_url = alink( $goldId_url, $colVal );
                $row .= $colVal . $sd . $goldId_url . "\t";
            } elsif ($col eq 'submission_id' && $colVal) {
                my $url = $img_er_submit_url;
                $url = $img_mer_submit_url if ($domain eq "*Microbiome");
                $url = $url . $colVal;
                $url = alink($url, $colVal);
                $row .= $colVal . $sd . $url . "\t";
            } elsif ($col eq 'project_info' && $colVal) {    
                my $url = "http://img.jgi.doe.gov/cgi-bin/submit/main.cgi?"
		        . "section=ProjectInfo&page=displayProject&project_oid=";
                $url .= $colVal;
                $url = alink($url, $colVal);
                 $row .= $colVal . $sd . $url . "\t";
            } else {
                #$colVal = nbsp(1) if !$colVal;
                if ( !$colVal || blankStr($colVal)) {
                    $row .= '-1' . $sd . '_' . "\t";
                } else {
                    $row .= $colVal . $sd . $colVal . "\t";
                }
            }
        }
    	$it->addRow($row);
    }
    ### End putting together InnerTable

    $it->printOuterTable(1);

    print "</p>\n";
    if ( $count > 10 ) {
        TaxonSearchUtil::printButtonFooter($txTableName);
        print "<br/>";
    }
    print "<p>\n";
    print "(Only the first match is highlighted.)<br/>\n";
    print "</p>\n";

    print "<h2>Table Configuration</h2>";
    my $name = "_section_${section}_findGenomeResults";
    print submit(
        -id    => "moreGo",
        -name  => $name,
        -value => "Display Genomes Again",
        -class => "meddefbutton"
    );


    my %taxonColumns_hash           = map { substr $_, 1+index($_, ".") => 1 } @taxonColumns;
    my %projectMetadataColumns_hash = map { substr $_, 1+index($_, ".") => 1 } @projectMetadataColumns;
    my %sampleMetadataColumns_hash  = map { substr $_, 1+index($_, ".") => 1 } @sampleMetadataColumns;
    my %statsColumns_hash           = map { substr $_, 1+index($_, ".") => 1 } @statsColumns;

    if ( exists( $taxonColumns_hash{$taxonSearchFilter} ) ) {
        push( @taxonColumns, $taxonSearchFilter );
    } elsif ( exists( $projectMetadataColumns_hash{$taxonSearchFilter} ) ) {
        push( @projectMetadataColumns, $taxonSearchFilter );
    } elsif ( exists( $sampleMetadataColumns_hash{$taxonSearchFilter} ) ) {
        push( @sampleMetadataColumns, $taxonSearchFilter );
    } elsif ( exists( $statsColumns_hash{$taxonSearchFilter} ) ) {
        push( @statsColumns, $taxonSearchFilter );
    }

    @taxonColumns = @defaults;
    @defaults = ( 'ts.total_bases', 'ts.total_gene_count' );
    push( @defaults, @statsColumns );
    @statsColumns = @defaults;

    require GenomeList;
    GenomeList::printConfigDiv( \@taxonColumns, \@projectMetadataColumns,
                    \@sampleMetadataColumns, \@statsColumns );

    print submit(
        -id    => "moreGo",
        -name  => $name,
        -value => "Display Genomes Again",
        -class => "meddefbutton"
    );


    # save taxon oids as a file for redisplay
    my $session_id = getSessionId();
    my $process_id = $$;
    my $filename = 'genomelist' . $process_id . '_' . $session_id;
    print hiddenVar( 'genomeListFile', $filename );
    my $wfh = newWriteFileHandle("$cgi_tmp_dir/$filename");
    foreach my $taxon_oid ( @taxon_oids ) {
        print $wfh "$taxon_oid\n";
    }
    close $wfh;

    # save column names as a file for redisplay
    $filename = 'columnlist' . $process_id . '_' . $session_id;
    print hiddenVar( 'columnListFile', $filename );

    my $wfh = newWriteFileHandle("$cgi_tmp_dir/$filename");
    foreach my $c ( @myCols ) {
        print $wfh "$c\n";
    }
    close $wfh;

    print hiddenVar( 'section',            $section           );
    print hiddenVar( 'page',               'findGenomeResults');
    print hiddenVar( 'redisplay',          1                  );

    ## Configuration form
     print hiddenVar( "taxonSearchFilter",    $taxonSearchFilter );
     print hiddenVar( "taxonSearchTerm", $taxonSearchTerm );
     my $taxon_oid_str = join( ',', @tOids );
     print hiddenVar( "taxonOids", $taxon_oid_str );
     my $taxonSearchFilterType = TaxonTableConfiguration::findColType($taxonSearchFilter);
#    if ( $taxonSearchFilterType eq 'g' ) {
#        push(@outputCol, $taxonSearchFilter);    	
#    }
#    my %outputColHash = WebUtil::array2Hash(@outputCol);
#    my $name = "_section_${section}_setTaxonOutputCol";
#    TaxonTableConfiguration::appendTaxonTableConfiguration( \%outputColHash, $name );
        
    printStatusLine( "$count genomes retrieved.", 2 );
    print end_form();
}

############################################################################
# splitSearchTerm - Split comma separated list of ID's
#   currently used for Taxon ID and Scaffold External Accession ID
############################################################################
sub splitSearchTerm {
    my ($taxonSearchTerm, $intFlag, $noFlag, $validateOid) = @_;
    #print "<h5>splitSearchTerm \$taxonSearchTerm: $taxonSearchTerm</h5>";
    #print "<h5>splitSearchTerm \$intFlag: $intFlag</h5>";
    
    my @terms = WebUtil::splitTerm($taxonSearchTerm, $intFlag, $noFlag);
    if ($validateOid && scalar(@terms) > 0) {
    	@terms = validateOids(@terms);
    }
    
    my $term_str;
    if ($intFlag) {
        $term_str = join( ',', @terms );
    }
    else {
        $term_str = WebUtil::joinSqlQuoted( ',', @terms );    	
    }
    if ( blankStr($term_str) && !$noFlag) {
        webError("Please enter a comma separated list of valid ID's.");
    }
    
    return $term_str;
}

sub validateOids {
    my (@terms) = @_;

    my $term_str = join( ',', @terms );
	my $sql = WebUtil::getTaxonReplacementSql($term_str);
    #print "validateOids \$sql: $sql<br/>";
	
	my $dbh = dbLogin();
	my $cur = execSql( $dbh, $sql, $verbose);   

	my @taxon_oids = ();
	for( ;; ) {
	   my( $taxon_oid ) = $cur->fetchrow( );
	   last if !$taxon_oid;
	   push( @taxon_oids, $taxon_oid );
	}
    $cur->finish( );
    ##$dbh->disconnect();

    if (scalar(@taxon_oids)) {
    	push(@terms, @taxon_oids);
    }
    
    return (@terms);
}

############################################################################
# highlightMatchingTextHTML - Highlight matching text in comma
#   seprated list.
############################################################################
sub highlightMatchingTextHTML {
    my ( $matchVals_ref, $str ) = @_;
    my @toks = split( /,/, $str );
    my @toks2;
    for my $t (@toks) {
        $t =~ s/^\s+//;
        $t =~ s/\s+$//;
        push( @toks2, $t );
    }
    my $s;
    for my $t (@toks2) {
        my $found = 0;
        for my $mv (@$matchVals_ref) {
            if ( $mv eq $t ) {
                $s .= "<font color='green'><b>$t</b></font>, ";
                $found = 1;
                last;
            }
        }
        if ( !$found ) {
            $s .= "$t, ";
        }
    }
    chop $s;
    chop $s;
    return $s;
}

############################################################################
# printPageHint - Print this page's hint.
############################################################################
sub printPageHint {
    printWideHint(
        qq{
            All searches treat the keyword as a substring 
        	(a word or part of a word).  <br />
            The search should contain some alphanumeric characters.<br/>
        	Use an underscore (_) as a single-character wildcard. <br />
        	Use % to match zero or more characters.  <br />
        	All matches are case insensitive. <br />
        }
    );
}


#
# protein genome search - cog id, cog name, pfam id, pfam name
#
# find genomes with all the in funcs
# excluding genomes that have the not funcs
#
sub printProteinGenomeResults {
    my ( $taxonSearchFilter, $taxonSearchTerm ) = @_;

    printStatusLine("Loading ...");

    if ( $taxonSearchFilter eq "cog_id" ) {
        print "<h1>Genome COG ID Search Results</h1>\n";
    } elsif ( $taxonSearchFilter eq "pfam_id" ) {
        print "<h1>Genome Pfam ID Search Results</h1>\n";
    } elsif ( $taxonSearchFilter eq "cog_name" ) {
        print "<h1>Genome COG Name Search Results</h1>\n";
    } elsif ( $taxonSearchFilter eq "pfam_name" ) {
        print "<h1>Genome Pfam Name Search Results</h1>\n";
    }
    
    $taxonSearchTerm = strTrim($taxonSearchTerm);
    if ( $taxonSearchTerm eq "" ) {
        webError("Please enter a term to search!");
    }

    my @terms = split( /,/, $taxonSearchTerm );
    # limit the in statement size
    my $max_size = 20;
    if ( $#terms > ( $max_size - 1 ) ) {
        webError("Please limit to $max_size terms!");
    }

    my @in;
    my @notIn;

    foreach my $x (@terms) {
        chomp $x;
        $x = strTrim($x);

        next if ( $x eq "" );

        if ( $x =~ /^!/ ) {
            $x =~ s/^!//;
            if ( $taxonSearchFilter eq "cog_id" ) {
                push( @notIn, uc($x) );
            } else {
                push( @notIn, lc($x) );
            }
        } else {
            if ( $taxonSearchFilter eq "cog_id" ) {
                push( @in, uc($x) );
            } else {
                push( @in, lc($x) );
            }
        }
    }

    if ( $#in < 0 && $#notIn < 0 ) {
        webError("Please enter a term to search!");
    }

    print "<p>\n";
    print "Find genomes with: " . join( ", ", @in ) . "<br>\n" if ( $#in > -1 );
    print "Excluding genomes with: " . join( ", ", @notIn ) . "<br>\n" if ( $#notIn > -1 );
    print "</p>";

    my ($recs_ref, $gene_counts_ref, $count);
    if ( $taxonSearchFilter eq "cog_id" || $taxonSearchFilter eq "pfam_id" )
    {
        ($recs_ref, $gene_counts_ref, $count) = printProteinIdResults($taxonSearchFilter, \@in, \@notIn);
    } elsif ( $taxonSearchFilter eq "cog_name" || $taxonSearchFilter eq "pfam_name" )
    {
        ($recs_ref, $gene_counts_ref, $count) = printProteinNameResults($taxonSearchFilter, \@in, \@notIn);
    }

    if ($count == 0) {
    	WebUtil::printNoHitMessage();
        printStatusLine( "$count Loaded.", 2 );
    	return;
    }

    printGenomeList( $recs_ref, $gene_counts_ref );

    printStatusLine( "$count Loaded.", 2 );

    printJSForm( $taxonSearchFilter, $taxonSearchTerm );
}

#
# protein genome search - cog id, cog name, pfam id, pfam name
#
# find genomes with all the in funcs
# excluding genomes that have the not funcs
#
sub printProteinIdResults {
    my ( $taxonSearchFilter, $in_ref, $notIn_ref) = @_;
    my @in = @$in_ref;
    my @notIn = @$notIn_ref;
    
    my $inClause = getJoinedBindString(@in);
    my $notInClause = getJoinedBindString(@notIn);

    my $sql;
    my $sql_count;
    my $dbh = dbLogin();
    my $taxonClause = txsClause('t', $dbh);
    my $rclause = WebUtil::urClause('t');
    my $imgClause = WebUtil::imgClause('t');

    if ( $taxonSearchFilter eq "cog_id" ) {
        $inClause = "and gc.cog in(" . $inClause . ")" 
            if ( $inClause ne "" );

        $notInClause = qq{
            and t.taxon_oid not in (
            select distinct gc2.taxon
            from gene_cog_groups gc2
            where gc2.cog in ($notInClause) 
            )  
        } if ( $notInClause ne "" );

        if ( $#in < 0 ) {
            $sql = getOnlyNotGenomeSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql = qq{
                select distinct t.taxon_oid, t.taxon_display_name, gc.cog
                from taxon t, gene_cog_groups gc
                where t.taxon_oid = gc.taxon
                $inClause
                $notInClause
                $taxonClause
                $rclause
                $imgClause
                order by t.taxon_oid
            };
        }

        if ( $#in < 0 ) {
            $sql_count = getOnlyNotGenomeGeneCountSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql_count = qq{
                select t.taxon_oid, count(distinct g.gene_oid)
                from taxon t, gene_cog_groups gc
                where t.taxon_oid = gc.taxon
                $inClause
                $notInClause
                $taxonClause
                $rclause
                $imgClause
                group by t.taxon_oid    
            };
        }

    } elsif ( $taxonSearchFilter eq "pfam_id" ) {
        $inClause = "and gp.pfam_family in(" . $inClause . ")"
          if ( $inClause ne "" );

        $notInClause = qq{
            and t.taxon_oid not in (
            select distinct t2.taxon_oid
            from taxon t2, gene g2, gene_pfam_families gp2
            where t2.taxon_oid = g2.taxon
            and g2.gene_oid = gp2.gene_oid
            and gp2.pfam_family in ($notInClause) 
          )  
        } if ( $notInClause ne "" );

        if ( $#in < 0 ) {
            $sql = getOnlyNotGenomeSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql = qq{
                select distinct t.taxon_oid, t.taxon_display_name, gp.pfam_family
                from taxon t, gene g, gene_pfam_families gp
                where t.taxon_oid = g.taxon
                and g.gene_oid = gp.gene_oid
                $inClause
                $notInClause
                $taxonClause
                $rclause
                $imgClause
                order by t.taxon_oid
            };
        }

        if ( $#in < 0 ) {
            $sql_count = getOnlyNotGenomeGeneCountSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql_count = qq{
                select t.taxon_oid, count(distinct g.gene_oid)
                from taxon t, gene g, gene_pfam_families gp
                where t.taxon_oid = g.taxon
                and g.gene_oid = gp.gene_oid
                $inClause
                $notInClause
                $taxonClause
                $rclause
                $imgClause
                group by t.taxon_oid
            };
        }

    }
    #print "getProteinIdResults \$sql: $sql<br/>";
    #print "getProteinIdResults \$sql_count: $sql_count<br/>";

    my @alist;
    push( @alist, @in );
    push( @alist, @notIn );
#    if ($taxonClause ne "") {
#        push( @alist, "$sessionId" );
#    }
    #print "\@alist: @alist<br/>";

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@alist, $verbose );

    # store data in hash- i know the number of in func equals the number
    # rows for a given taxon oid - true for func id search
    #
    my %hash_cnt;
    for ( ; ; ) {
        my ( $toid, $tname, $fnc ) = $cur->fetchrow();
        last if !$toid;
        my $key = "$toid\t$tname";
        if ( exists( $hash_cnt{$key} ) ) {
            $hash_cnt{$key} = $hash_cnt{$key} + 1;
        } else {
            $hash_cnt{$key} = 1;
        }
    }
    $cur->finish();

    # TODO run query to get taxon to gene counts
    # hash taxon oid => gene counts
    my %gene_counts;
    my $cur = WebUtil::execSqlBind( $dbh, $sql_count, \@alist, $verbose );
    for ( ; ; ) {
        my ( $toid, $gcount ) = $cur->fetchrow();
        last if !$toid;
        $gene_counts{$toid} = $gcount;
    }

    $cur->finish();

    ##$dbh->disconnect();

    # now filter by "in" func ids matches or if no in funcs ids and all
    # "not in" funcs ids
    my $count = 0;
    my @recs;
    my $in_size = $#in + 1;
    foreach my $key ( sort keys %hash_cnt ) {
        if ( $hash_cnt{$key} >= $in_size ) {
            push( @recs, $key );
            $count++;
        }
    }

    return ( \@recs, \%gene_counts, $count );
}

sub getJoinedBindString {
    my (@bin) = @_;

    my $bindStr = "";
    for ( my $i = 0 ; $i <= $#bin ; $i++ ) {
        $bindStr .= "?";
        if ( $i < $#bin ) {
            $bindStr .= ",";
        }
    }

    return $bindStr;
}

sub getOnlyNotGenomeSql {
    my ($notInClause, $taxonClause, $rclause, $imgClause) = @_;

    # end case - only not functions
    # no in part so ignore fnc
    my $sql = qq{
        select distinct t.taxon_oid, t.taxon_display_name, 'nofnc'
        from taxon t, gene g
        where t.taxon_oid = g.taxon
        $notInClause
        $taxonClause
        $rclause
        $imgClause
        order by t.taxon_oid              
    };

    return ($sql);
}

sub getOnlyNotGenomeGeneCountSql {
    my ($notInClause, $taxonClause, $rclause, $imgClause) = @_;

    # end case - only not functions
    my $sql_count = qq{
        select t.taxon_oid, count(distinct g.gene_oid)
        from taxon t, gene g
        where t.taxon_oid = g.taxon
        $notInClause
        $taxonClause
        $rclause 
        $imgClause
        group by t.taxon_oid              
    };

    return ($sql_count);
}


# similar to printProteinIdResults BUT filtering is different becuz the query
# can return many rows sice its doing a like % ? %
#
sub printProteinNameResults {
    my ( $taxonSearchFilter, $in_ref, $notIn_ref) = @_;
    my @in = @$in_ref;
    my @notIn = @$notIn_ref;

    my $sql;
    my $sql_count;
    my $inClause    = "";
    my $notInClause = "";

    my $dbh = dbLogin();
    my $taxonClause = txsClause("t", $dbh);
    my $rclause = WebUtil::urClause("t");
    my $imgClause = WebUtil::imgClause('t');

    my @alist;

    if ( $taxonSearchFilter eq "cog_name" ) {
        if ( $#in > -1 ) {
            $inClause = getMoreProteinNameClause("c.cog_name", \@in, \@alist);
        }

        if ( $#notIn > -1 ) {
            $notInClause = qq{
             and t.taxon_oid not in (
                select distinct gc2.taxon
                from gene_cog_groups gc2, cog c2
                where gc2.cog = c2.cog_id
            };
            my $moreClause = getMoreProteinNameClause("c2.cog_name", \@notIn, \@alist);
            $notInClause .= $moreClause;
            $notInClause .= ")";
        }

        if ( $#in < 0 ) {
            $sql = getOnlyNotGenomeSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql = qq{
            select distinct t.taxon_oid, t.taxon_display_name, c.cog_name
            from taxon t, gene_cog_groups gc, cog c
            where t.taxon_oid = gc.taxon
            and gc.cog = c.cog_id
            $inClause
            $notInClause
            $taxonClause
            $rclause
            $imgClause
            order by t.taxon_oid
            };
        }

        if ( $#in < 0 ) {
            $sql_count = getOnlyNotGenomeGeneCountSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql_count = qq{
                select t.taxon_oid, count(distinct gc.gene_oid)
                from taxon t, gene_cog_groups gc, cog c
                where t.taxon_oid = gc.taxon
                and gc.cog = c.cog_id
                $inClause
                $notInClause
                $taxonClause
                $rclause
                $imgClause
                group by t.taxon_oid            
            };
        }

    } elsif ( $taxonSearchFilter eq "pfam_name" ) {
        if ( $#in > -1 ) {
            $inClause = getMoreProteinNameClause("p.name", \@in, \@alist);
        }

        if ( $#notIn > -1 ) {
            $notInClause = qq{
                and t.taxon_oid not in (
                select distinct gp2.taxon
                from gene_pfam_families gp2, pfam_family p2
                where gp2.pfam_family = p2.ext_accession
            };
            my $moreClause = getMoreProteinNameClause("p2.name", \@notIn, \@alist);
            $notInClause .= $moreClause;
            $notInClause .= ")";
        }

        if ( $#in < 0 ) {
            $sql = getOnlyNotGenomeSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql = qq{
                select distinct t.taxon_oid, t.taxon_display_name, p.name
                from taxon t, gene g, gene_pfam_families gp, pfam_family p
                where t.taxon_oid = g.taxon
                and g.gene_oid = gp.gene_oid
                and gp.pfam_family = p.ext_accession
                $inClause
                $notInClause
                $taxonClause
                $rclause
                $imgClause
                order by t.taxon_oid
            };
        }

        if ( $#in < 0 ) {
            $sql_count = getOnlyNotGenomeGeneCountSql($notInClause, $taxonClause, $rclause, $imgClause);
        }
        else {
            $sql_count = qq{
                select t.taxon_oid, count(distinct g.gene_oid)
                from taxon t, gene g, gene_pfam_families gp, pfam_family p
                where t.taxon_oid = g.taxon
                and g.gene_oid = gp.gene_oid
                and gp.pfam_family = p.ext_accession
                $inClause
                $notInClause
                $taxonClause
                $rclause
                $imgClause
                group by t.taxon_oid            
            };
        }
    }
    #print "getProteinNameResults \$sql: $sql<br/>";
    #print "getProteinNameResults \$sql_count: $sql_count<br/>";

#    if ($taxonClause ne "") {
#        push( @alist, "$sessionId" );
#    }
    #print "\@alist: @alist";

    my $cur = WebUtil::execSqlBind( $dbh, $sql, \@alist, $verbose );

    my $count = 0;
    my @recs;

    # store data in hash of hash
    # hash 1 taxon oid \t taxon name => hash 2
    # hash 2 "in fnc" => "" - its the "in func" the name matched to
    #
    my %hash_cnt;
    for ( ; ; ) {
        my ( $toid, $tname, $fnc ) = $cur->fetchrow();
        last if !$toid;
        my $key = "$toid\t$tname";
        if ( exists( $hash_cnt{$key} ) ) {
            my $fnc_href = $hash_cnt{$key};
            my $tmp_key = match( lc($fnc), \@in );
            next if ( $tmp_key eq "" );
            $fnc_href->{$tmp_key} = "";
        } else {
            my %fnc_hash;
            $hash_cnt{$key} = \%fnc_hash;

            # TODO what happen if match is "" do not insert into hash?
            # which in func did the query name match to
            my $tmp_key = match( lc($fnc), \@in );
            next if ( $tmp_key eq "" );
            $fnc_hash{$tmp_key} = "";
        }

    }
    $cur->finish();

    # TODO run query to get taxon to gene counts
    # hash taxon oid => gene counts
    my %gene_counts;
    my $cur = WebUtil::execSqlBind( $dbh, $sql_count, \@alist, $verbose );
    for ( ; ; ) {
        my ( $toid, $gcount ) = $cur->fetchrow();
        last if !$toid;
        $gene_counts{$toid} = $gcount;
    }

    $cur->finish();
    ##$dbh->disconnect();

    #print Dumper \%hash_cnt;

    # now filter by "in" func ids matches or if no in funcs ids and all
    # "not in" funcs ids
    #
    # PROBLEM - with name search count is not good enough because its not exact
    # matches e.g. if you search for abc and efg there can be 2 or more abc rows
    # and no efg rows - should we still display all the results
    my $in_size = $#in + 1;
    print "<p>\n";
    foreach my $key ( sort keys %hash_cnt ) {
        my $fnc_href  = $hash_cnt{$key};
        my $hash_size = keys(%$fnc_href);

        #        print "$key <br>";
        #        print Dumper $fnc_href;
        #        print "<br>";
        #        print "in size: $in_size  size: $hash_size <br><br>";
        #

        if ( $hash_size >= $in_size ) {
            push( @recs, $key );
            $count++;
        } elsif ( $#in < 0 ) {

            # end case
            push( @recs, $key );
            $count++;
        }
    }

    return ( \@recs, \%gene_counts, $count );
}

sub getMoreProteinNameClause {
    my ($tableColName, $bin_ref, $alist_ref) = @_;
    
    my $moreClause = "and (";
    for ( my $i = 0 ; $i < scalar(@$bin_ref); $i++ ) {
        my $tmp_str = $bin_ref->[$i]; # escapeSingleQuote( $bin_ref->[$i] );
        $tmp_str = escapeInnerChars($tmp_str);
        $moreClause .= "lower($tableColName) like ? escape '\\' ";
        push( @$alist_ref, "%$tmp_str%");
        if ( $i < scalar(@$bin_ref) - 1 ) {
            $moreClause .= " or \n";
        }
    }
    $moreClause .= ")";
            
    return ($moreClause);
}

#
# javascript form for gene count
#
sub printJSForm {
    my ( $taxonSearchFilter, $taxonSearchTerm ) = @_;

    print qq{
        <script language="JavaScript" type="text/javascript">
        <!--
        function mySubmit (toid ) {
            document.mainForm2.taxon_oid.value = toid;
            document.mainForm2.submit();
        }
        -->
        </script>    
    };

    WebUtil::printMainFormName("2");

    print hiddenVar( "filter",    $taxonSearchFilter );
    print hiddenVar( "terms",     $taxonSearchTerm );
    print hiddenVar( "page",      "geneList" );
    print hiddenVar( "section",   $section );
    print hiddenVar( "taxon_oid", "0" );

    print end_form();
}

#
# does any array item match name
# return the array element it match too
# otherwise return ""
sub match {
    my ( $name, $aref ) = @_;

    foreach my $key (@$aref) {
        # remove oracle % and _ wild cards
        # i'll only use the '%' for now
        my $pattern = $key;

        # only \ or % at the beginning
        if ( $pattern =~ /^%/ ) {
            $pattern =~ s/^%//;
        } elsif ( $pattern =~ /^\\%/ ) {
            $pattern =~ s/^\\%/%/;
        }

        # only \% or % at the end of the line
        if ( $pattern =~ /\\%$/ ) {
            $pattern =~ s/\\%$/%/;
        } elsif ( $pattern =~ /%$/ ) {
            $pattern =~ s/%$//;
        }

        if ( $name =~ /$pattern/ ) {
            #print "matched: $pattern $key $name<br>";
            return $key;
        }
    }
    return "";
}

# escape some oracle chars I'm not allowing ui to use
# eg. '_' '&'
# the escape char is '\'
#
# escape oracle single quote
sub escapeSingleQuote {
    my ($str) = @_;

    $str =~ s/'/''/g;

    return $str;
}

# escape special oracle characters within the str
# I only allow % at the beginning and end of string
# thus this allows \ at the beginning and 2nd last char to escape %
# cases:
# 1. str
# 2. % str
# 3. str %
# 4. % str %
# 5. \% str - escape the %
# 6. str \%
# 7. \% str \%
#
sub escapeInnerChars {
    my ($str) = @_;

    my $newStr = "";
    my @chars = split( //, $str );
    my $last_char = "";

    for ( my $i = 0 ; $i <= $#chars ; $i++ ) {
        # current char
        my $c = $chars[$i];
        if ( $i == 0 ) {
            # 1st char
            # can be anything - % or \ ok  at the beginning of line
            if ( $#chars == 0 ) {
                # only one char
                if ( $c eq "%" || $c eq "&" || $c eq "_" || $c eq "\\" ) {
                    $newStr .= "\\";
                }
            } elsif ( $#chars > 0 ) {
                # more than one char - look ahead for %
                if ( $c eq "\\" && $chars[1] ne "%" ) {
                    $newStr .= "\\";
                }
            }
        } elsif ( $i == 1 ) {
            # 2nd char
            # % and last char was \
            if ( $last_char eq "\\" && $c eq "%" ) {
                # user escaped %
                #print "here 1\n";
                #$newStr .= "\\";
            } elsif ( $c eq "%" || $c eq "&" || $c eq "_" || $c eq "\\" ) {
                # escape these chars
                $newStr .= "\\";
            }
        } elsif ( $i > 1 && $i < ( $#chars - 1 ) ) {
            # 3rd char to 3rd last char
            if ( $c eq "%" || $c eq "&" || $c eq "_" || $c eq "\\" ) {
                $newStr .= "\\";
            }
        } elsif ( $i == ( $#chars - 1 ) ) {
            # 2nd last char
            if ( $c eq "%" || $c eq "&" || $c eq "_" ) {
                # escape these chars
                $newStr .= "\\";
            } elsif ( $c eq "\\" && $chars[$#chars] ne "%" ) {
                # look ahead
                $newStr .= "\\";
            }
        } elsif ( $i == $#chars ) {
            # last char
            if ( $c eq "&" || $c eq "_" || $c eq "\\" ) {
                $newStr .= "\\";
            }
        }
        $newStr .= $c;
        $last_char = $c;
    }

    return $newStr;
}

#
# print html table
#
sub printGenomeList {
    my ( $rec_aref, $gene_counts_href ) = @_;

    printMainForm();

    my $txTableName = "genome";  # name of current instance of taxon table

    # The JS function isGenomeSelected() for onClick event below is in header.js
    print submit(
        -name    => 'setTaxonFilter',
        -value   => 'Add Selected to Genome Cart',
        -class   => 'meddefbutton',
	-onClick => "return isGenomeSelected('$txTableName');"
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllTaxons(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllTaxons(0)' class='smbutton' />\n";

    my $it = new InnerTable( 1, "$txTableName$$", $txTableName, 1 );
    $it->addColSpec("Select");
    $it->addColSpec( "Genome ID",   "number asc",  "right" );
    $it->addColSpec( "Genome Name", "char asc",    "left" );
    $it->addColSpec( "Gene Count",  "number desc", "right" );

    my $sd = $it->getSdDelim();    # sort delimit

    my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail&taxon_oid=";

    foreach my $line (@$rec_aref) {
        my ( $toid, $tname ) = split( /\t/, $line );
        my $r;

        $r .= $sd
          . "<input type='checkbox' "
          . "name='taxon_filter_oid' value='$toid' /> \t";

        $r .= $toid . $sd . "<a href='" . $url . $toid . "'> $toid </a>" . "\t";

        $r .= $tname . $sd . "\t";

        if ( $gene_counts_href ne "" ) {
            my $count = $gene_counts_href->{$toid};
            $r .=
              $count . $sd
              . "<a href=\"javascript:mySubmit('$toid')\"> $count </a> \t";
        } else {
            $r .= "0" . $sd . "- \t";
        }

        $it->addRow($r);
    }

    $it->printOuterTable(1);

    print submit(
        -name    => 'setTaxonFilter',
        -value   => 'Add Selected to Genome Cart',
        -class   => 'meddefbutton',
	-onClick => "return isGenomeSelected('$txTableName');"
     );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All' "
      . "onClick='selectAllTaxons(1)' class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All' "
      . "onClick='selectAllTaxons(0)' class='smbutton' />\n";

    #print hiddenVar( "page",          "message" );
    #print hiddenVar( "message",       "Genome selection saved and enabled." );
    print hiddenVar( "menuSelection", "Genomes" );

    print end_form();
}

#
# only cog id and pfam id use ? in sql / binding
#
sub getFunIdGeneListQuery {
    my ( $filter, $searchTerms, $taxon_oid ) = @_;

    my @terms = split( /,/, $searchTerms );
    my @in;
    #my @notIn;

    foreach my $x (@terms) {
        chomp $x;
        $x = strTrim($x);

        next if ( $x eq "" );

        if ( $x =~ /^!/ ) {
            next;
        } else {
            if ( $filter eq "cog_id" ) {
                push( @in, uc($x) );
            } else {
                push( @in, lc($x) );
            }
        }
    }

    my $inClause = "";
    if ( $filter eq "cog_id" || $filter eq "pfam_id" ) {
        $inClause = getJoinedBindString(@in);
    }

    my $taxonClause = "and g.taxon = ? ";
    my $rclause = WebUtil::urClause('g.taxon');
    my $imgClause = WebUtil::imgClauseNoTaxon('g.taxon');

    my @alist;
    my $sql;

    if ( $filter eq "cog_id" ) {
        if ( $#in < 0 ) {
            $sql = getOnlyNotGeneListSql($taxonClause, $rclause, $imgClause);
        } else {
    	    $inClause = "and gc.cog in(" . $inClause . ")" 
    		if ( $inClause ne "" );
    	    
    	    $sql = qq{
    	        select distinct g.gene_oid, g.gene_display_name, gc.cog
        		from gene g, gene_cog_groups gc
        		where g.gene_oid = gc.gene_oid
        		$inClause   
        		$taxonClause
                $rclause
                $imgClause
    	    };
            push( @alist, @in );
            #push( @alist, @notIn );
        }

    } elsif ( $filter eq "pfam_id" ) {
        if ( $#in < 0 ) {
            $sql = getOnlyNotGeneListSql($taxonClause, $rclause, $imgClause);
        } else {
	        $inClause = "and gp.pfam_family in(" . $inClause . ")" 
	           if ( $inClause ne "" );
	    
	        $sql = qq{
		        select distinct g.gene_oid, g.gene_display_name, gp.pfam_family
		        from gene g, gene_pfam_families gp
		        where g.gene_oid = gp.gene_oid
		        $inClause
		        $taxonClause
                $rclause
                $imgClause
	        };
            push( @alist, @in );
            #push( @alist, @notIn );
        }

    } elsif ( $filter eq "cog_name" ) {
        if ( $#in < 0 ) {
            $sql = getOnlyNotGeneListSql($taxonClause, $rclause, $imgClause);
        } else {
        	if ( $#in > -1 ) {
                $inClause = getMoreProteinNameClause("c.cog_name", \@in, \@alist);
        	}
	        $sql = qq{
		        select distinct g.gene_oid, g.gene_display_name, c.cog_name
		        from gene g, gene_cog_groups gc, cog c
		        where g.gene_oid = gc.gene_oid
		        and gc.cog = c.cog_id
		        $inClause
		        $taxonClause
                $rclause
                $imgClause
	        };
        }

    } elsif ( $filter eq "pfam_name" ) {
        if ( $#in < 0 ) {
            $sql = getOnlyNotGeneListSql($taxonClause, $rclause, $imgClause);
        } else {
	        if ( $#in > -1 ) {
                $inClause = getMoreProteinNameClause("p.name", \@in, \@alist);
	        }
	        $sql = qq{
		        select distinct g.gene_oid, g.gene_display_name, p.name
		        from gene g, gene_pfam_families gp, pfam_family p
		        where g.gene_oid = gp.gene_oid
		        and gp.pfam_family = p.ext_accession
		        $inClause
		        $taxonClause
                $rclause
                $imgClause
	        };
        }
    } 
    
    push( @alist, "$taxon_oid" );

    return ( $sql, \@alist );
}

sub getOnlyNotGeneListSql {
    my ($taxonClause, $rclause, $imgClause) = @_;
	
    # end case - only not functions
    # no in part so ignore fnc
    my $sql = qq{
        select distinct g.gene_oid, g.gene_display_name, ' '
        from gene g
        where 1 = 1
        $taxonClause           
        $rclause
        $imgClause
    };
    return ($sql);
}

sub printGeneList {
    my $terms     = param("terms");
    my $taxon_oid = param("taxon_oid");
    my $filter    = param("filter");

    printStatusLine("Loading ...");

    print "<h1>Gene List</h1>\n";
    print "<p>";
    print "Genome ID: $taxon_oid<br>\n";
    print "Search Type: $filter<br>\n";
    print "Search Terms: $terms</p>\n";

    my ($sql, $alist_aref) = getFunIdGeneListQuery( $filter, $terms, $taxon_oid );

    #print("$sql\n");
    #webLog("$sql\n");

    my $dbh = dbLogin();    
    my $cur = WebUtil::execSqlBind( $dbh, $sql, $alist_aref, $verbose );

    my $count = 0;
    my @recs;
    for ( ; ; ) {
        my ( $gene_oid, $gname, $func ) = $cur->fetchrow();
        last if !$gene_oid;
        $count++;
        push( @recs, "$gene_oid\t$gname\t$func" );
    }

    $cur->finish();
    ##$dbh->disconnect();

    # print "<input type='checkbox' name='gene_oid' value='$gene_oid' $ck />\n";
    my $it = new InnerTable( 1, "genomeGeneList$$", "genomeGeneList", 1 );

    $it->addColSpec("Select");
    $it->addColSpec( "Gene ID",   "number asc", "right" );
    $it->addColSpec( "Gene Product Name", "char asc",   "left" );
    $it->addColSpec( "Function", "char asc",   "left" );
    my $sd = $it->getSdDelim();    # sort delimit

    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    foreach my $line (@recs) {
        my ( $oid, $name, $func ) = split( /\t/, $line );
        my $r;
        $r .=
          $sd . "<input type='checkbox' name='gene_oid' value='$oid' />" . "\t";

        $r .= $oid . $sd . "<a href='" . $url . $oid . "'> $oid </a>" . "\t";

        $r .= $name . $sd . "\t";
        $r .= $func . $sd . "\t";

        $it->addRow($r);
    }

    printMainForm();
    printGeneCartFooter() if ( $count > 0 );

    $it->printOuterTable(1);

    printGeneCartFooter() if ( $count > 0 );

    printStatusLine( "$count Loaded.", 2 );
    print end_form();
}

1;

