############################################################################
# TaxonSearch.pm - Set up for keyword search for taxons.
# --es 12/22/2004
#
# $Id: TaxonSearch.pm 33504 2015-06-03 20:00:02Z klchu $
############################################################################
package TaxonSearch;
my $section = "TaxonSearch";
use strict;
use CGI qw( :standard );
use DBI;
use WebConfig;
use WebUtil;
use DataEntryUtil;
use GoldDataEntryUtil;
use TaxonSearchUtil;
use TaxonTableConfiguration;
use InnerTable;
use OracleUtil;
use Data::Dumper;

my $env = getEnv( );
my $main_cgi = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=$section";
my $verbose = $env->{ verbose };
my $taxonomy_base_url    = $env->{taxonomy_base_url};
my $swiss_prot_base_url  = $env->{ swiss_prot_base_url };
my $img_internal         = $env->{img_internal};
my $img_lite             = $env->{img_lite};
my $in_file              = $env->{in_file};
my $img_er_submit_url    = $env->{img_er_submit_url};
my $img_mer_submit_url   = $env->{img_mer_submit_url};
my $preferences_url      = "$main_cgi?section=MyIMG&page=preferences";

### optional genome field columns to configuration and display 
my @gOptCols = getGenomeFieldAttrs();
splice(@gOptCols, 0, 0, 'proposal_name'); #add 'taxon_display_name' at index 0
splice(@gOptCols, 1, 0, 'taxon_display_name'); #add 'taxon_display_name' at index 0
splice(@gOptCols, 6, 0, 'domain'); #add 'domain' at index 5
splice(@gOptCols, 14, 0, 'seq_status'); #add 'seq_status' at index 13

my @mOptCols = DataEntryUtil::getGoldCondAttr();
my @sOptCols = TaxonTableConfiguration::getOptStatsAttrs();

my @termCols = ();
push(@termCols, @gOptCols);
push(@termCols, @mOptCols);
push(@termCols, @sOptCols);

my $dateRegEx = '^(19|20)\d\d[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])$';

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param( "page" );

    if( param( "taxonTerm" ) ne "" || $page eq "orgsearch" ) {
        printTaxonList( );
    }
    elsif( $page eq "taxonSearchExamples" ) {
        printTaxonSearchExamples( );
    }
    else {
        printTaxonList( );
    }
}

############################################################################
# taxonSearchForm - Show basic gene search form.
############################################################################
sub taxonSearchForm {
    my $s;
    $s .= "<label>Search for Genomes (";
    my $url = "$section_cgi&page=taxonSearchExamples";
    $s .= alink( $url, "E.g's" ) . ")<br/>\n";
    $s .= textfield( -name => "taxonTerm", -size => 25 );
    my $name = "_section_${section}_taxonSearch";
    $s .= submit( -name => $name, -value => "Go" );
    $s .= "<br/>\n";
    return $s;
}

############################################################################
# printTaxonList - Show resulting taxon list with highliting match
#   regions from keyword search on various fields. 
############################################################################
sub printTaxonList {

    my $page = param( "page" );
    my $searchTerm = param( "taxonTerm" );
    WebUtil::processSearchTermCheck($searchTerm);
    $searchTerm = WebUtil::processSearchTerm($searchTerm, 1);
    my $searchTermLc = $searchTerm;
    $searchTermLc =~ tr/A-Z/a-z/;
    my $searchTermLiteral = $searchTerm;
    my $title = "All Fields Genome Search Results";

    # obtain data: taxon_oids, 
    my $dbh = dbLogin( );

    my $filedClause = "";
    for (my $i = 0; $i<scalar(@gOptCols); $i++) { #exclude phenotype, etc.
        if ( $gOptCols[$i] =~ /add_date/i ) {
            # its a date column
            # use iso format yyyy-mm-dd s.t. its ascii sortable - ken
            $filedClause .= "to_char(tx.$gOptCols[$i], 'yyyy-mm-dd')"
        } else {
            $filedClause .= "tx.".$gOptCols[$i];
        }
        $filedClause .= ', ';
    }

    my @bindList_eq = ();
    my $toidEqClause = '';
    my $matchEqClause = '';

    if ($searchTerm =~ /^[0-9]+$/) {
    	my @taxon_oids = validateOid($dbh, $searchTerm);
    	if (scalar(@taxon_oids) <= 0) {
	        $toidEqClause = qq{
	            tx.taxon_oid = ? or
	        };
            push(@bindList_eq, "$searchTerm");
    	} elsif (scalar(@taxon_oids) == 1) {
            $toidEqClause = qq{
                tx.taxon_oid = ? or
            };
            push(@bindList_eq, "$taxon_oids[0]");
        } else {
            my $oid_str = OracleUtil::getTaxonIdsInClause( $dbh, @taxon_oids );
            $toidEqClause = qq{
                tx.taxon_oid in ($oid_str) or
            };
    	}

        $matchEqClause = $toidEqClause;

	    my $eqClause = qq{
	        tx.ncbi_taxon_id = ? or
	        tx.refseq_project_id = ? or
	        tx.gbk_project_id = ? or
	        tx.submission_id = ? 
	    };
	    $eqClause .= " or tx.jgi_project_id = ? " if ($img_internal);
   	    $matchEqClause .= $eqClause;

        for (my $i = 0; $i < 4; $i++) {
            push(@bindList_eq, "$searchTerm");
        }
        push(@bindList_eq, "$searchTerm") if ($img_internal);
    }
    else {
	    my $matchClause = qq{
	      lower( tx.taxon_display_name ) like ?  or
	      lower( tx.domain ) like ?  or
	      lower( tx.phylum ) like ?  or
	      lower( tx.ir_class ) like ?  or
	      lower( tx.ir_order ) like ?  or
	      lower( tx.family ) like ?  or
	      lower( tx.genus ) like ?  or
	      lower( tx.species ) like ?  or
	      lower( tx.strain ) like ?  or
	      lower( tx.seq_status ) like ?  or
	      lower( tx.seq_center ) like ?  or
	      lower( tx.funding_agency ) like ? or
	      lower( tx.is_public ) like ? or
	      lower( tx.img_version ) like ? or
	      lower( tx.img_product_flag ) like ? or
          lower( tx.analysis_project_id ) like ? or
lower( tx.study_gold_id ) like ? or
lower( tx.sequencing_gold_id ) like ? or  
	      lower( tx.proposal_name ) like ?
	    };
	    $matchClause .= " or lower( tx.is_std_reference ) like ? " if ($img_internal && $img_lite);
	    $matchClause .= " or TRUNC(tx.add_date)=to_date(?, 'yyyy-mm-dd')" if ($searchTerm =~ /$dateRegEx/);
        $matchEqClause = $matchClause;

        for (my $i = 0; $i < 19; $i++) {
            push(@bindList_eq, "%$searchTermLc%");     	
        }
        push(@bindList_eq, "%$searchTermLc%") if ($img_internal && $img_lite);
        push(@bindList_eq, "$searchTerm") if ($searchTerm =~ /$dateRegEx/);
    }

    my ($restrictClause, @bindList_res) = getPreferenceRestrictClause();


    my ($rclause, @bindList_ur) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');
   
    my $sql = qq{
       select distinct tx.taxon_oid, $filedClause
           '', '', '', ''
       from taxon tx
       where 1 = 1 and (
           $matchEqClause
       )
       $restrictClause
       $rclause
       $imgClause
    };
   
    my @bindList = ();
    if (scalar(@bindList_eq) > 0) {
        push(@bindList, @bindList_eq);      
    }
    if (scalar(@bindList_res) > 0) {
        push(@bindList, @bindList_res);   
    }
    if (scalar(@bindList_ur) > 0) {
        push(@bindList, @bindList_ur);   
    }

    #print "printTaxonList \$sql: $sql<br/>\n"; 	 
    #print "\@bindList size: ".scalar(@bindList)."<br/>\n";
    #print "\@bindList: @bindList<br/>\n";

    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    my @recs;
    my %done;
    my $count = 0;
    my %found_indexes; # hash of column index where matches are found
    for( ;; ) {
       my( $taxon_oid, @terms ) = $cur->fetchrow( );
       last if !$taxon_oid;
       next if $done{ $taxon_oid } ne "";
       $count++;

       my $rec = join( "\t", @terms );
       $done{ $taxon_oid } = $taxon_oid;

       push( @recs, $rec );
      
       for (my $i = 2; $i<scalar(@terms); $i++) {
          # skip genome name $i=0 since $proposal_name, genome name column always printed
          # find column index of column with the last match
          if($terms[$i] =~ /$searchTermLiteral/i) {
              $found_indexes{$i} = $i;
          }
       }
    }

    ### start html printing
    if( $count == 0 ) {
    	OracleUtil::truncTable( $dbh, "gtt_taxon_oid" ) 
        	if ( $toidEqClause =~ /gtt_taxon_oid/i );
		#$dbh->disconnect();

        # DO NOT move this check as codes below assume that 
        # the number of taxon_oids is larger than zero.
        print "<p>\n0 genomes retrieved.\n</p>\n";
        
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
        
        printStatusLine( "0 genomes retrieved.", 2 );
        return;
    }

    #print "<p> \n"; 	 
    #print Dumper \%found_indexes; 	 
    #print "<p>\n"; 	 

    my @taxon_oids = keys %done;
    my @outputCol = processParamValue(param("outputCol"));

    if (    scalar(@outputCol) == 0
         && paramMatch("setTaxonOutputCol") eq ''
         && param("entry") ne "sort" )
    {
        param( -name => "outputCol", -value => \@outputCol );
    }

    my $outColClause  = '';
    my $mOutStartIdx  = -1;
    my @mOutCol       = ();
    my @sOutCol       = ();
    my @outColIndexes = ();
    for (my $i = 0; $i<scalar(@outputCol); $i++) {
        for (my $j = 0; $j<scalar(@termCols); $j++) { #outputCol are within genome fields
    	    if ($outputCol[$i] ne '' && $outputCol[$i] eq $termCols[$j]) {
        		my $c         = $outputCol[$i];
        		my $tableType = TaxonTableConfiguration::findColType($c);
        		if ( $tableType eq 'm' ) {
        		    $mOutStartIdx = $i if ( $mOutStartIdx == -1 );
        		    push( @mOutCol, $c );
        		}
        		elsif ( $tableType eq 's' ) {
        		    $outColClause .= ", stn.$c ";
        		    push @sOutCol, $c;
        		}
        		push(@outColIndexes, $j);
        		last;
    	    }
        }
    }
#    if ( $mOutStartIdx >= 0 ) {
#	    $outColClause .= ", tx.SEQUENCING_GOLD_ID, tx.submission_id, tx.ANALYSIS_PROJECT_ID";
#    }

#    my $taxon_oid_str = OracleUtil::getTaxonIdsInClause( $dbh, @taxon_oids );
#    my $sql = qq{
#        select tx.taxon_oid $outColClause
#        from taxon tx, taxon_stats stn
#        where tx.taxon_oid in ($taxon_oid_str)
#        and tx.taxon_oid = stn.taxon_oid
#    };
#
#    my $cur = execSql( $dbh, $sql, $verbose );
#
#    my %statVals;
#    my %tOids2SubmissionIds = (); #submissionIds, goldIds
#    my %tOids2GoldIds       = ();
#    my %tOids2ProjectGoldIds = (); # taxon to gold project ids
#    for ( ; ; ) {
#    	my ($taxon_oid, @outColVals) = $cur->fetchrow();
#    	last if !$taxon_oid;
#    	my %colHash;
#    	my $nOutColVals = scalar(@outColVals);
#    	for ( my $j = 0 ; $j < $nOutColVals ; $j++ ) {
#    	    if ($mOutStartIdx >= 0
#    		&& (   $j == $nOutColVals - 3
#    		       || $j == $nOutColVals - 2
#    		       || $j == $nOutColVals - 1 )
#    		)
#    	    {
#        		if ( $j == $nOutColVals - 2 ) {
#        		    $tOids2SubmissionIds{$taxon_oid} = $outColVals[$j]
#        			  if ( $outColVals[$j] ne '' );
#        		}
#        		elsif ( $j == $nOutColVals - 1 ) {
#        		    $tOids2GoldIds{$taxon_oid} = $outColVals[$j]
#        			if ( $outColVals[$j] ne '' );
#                            $tOids2ProjectGoldIds{$taxon_oid} = $outColVals[$j]
#                                if ( $outColVals[$j] ne '' );
#                            # gold id for metagenomes is actually $sample_gold_id - ken
#                            # but not all metagenomes have sample_gold_id so the gold_id is
#                            # use - but this gold_id is project_info level metadata
#        		    my $sample_gold_id = $outColVals[ $nOutColVals - 3 ];
#        		    $tOids2GoldIds{$taxon_oid} = $sample_gold_id
#                                if ( $sample_gold_id ne "" );
#        		}
#    	    } else {
#    		    $colHash{$sOutCol[$j]} = $outColVals[$j];
#    	    }
#    	}
#    	$statVals{$taxon_oid} = \%colHash;
#    }
#
#    OracleUtil::truncTable( $dbh, "gtt_taxon_oid" ) 
#        if ( $taxon_oid_str =~ /gtt_taxon_oid/i );
    #$dbh->disconnect();

#    my %tOids2Meta;
#    %tOids2Meta = getMetadataForAttrs_new_2_0
#	( \%tOids2SubmissionIds, \%tOids2GoldIds, \@mOutCol, \%tOids2ProjectGoldIds )
#	if ( $mOutStartIdx >= 0 );

#    for my $oid (@taxon_oids) {
#    	my ( @outColVals ) = split(/\t/, $tOids2Meta{$oid});
#    	for (my $i = 0; $i < @mOutCol; $i++) {
#    	    $statVals{$oid}{$mOutCol[$i]} = $outColVals[$i];
#    	}
#    }

    ### which columns to display
    my %found_column;
    foreach my $key (sort {$a<=>$b} keys %found_indexes) {
        my $col = $termCols[$key];
        $found_column{$col} = 1;
        push( @outputCol, $col );
    }
    if (scalar(@outColIndexes) > 0) {
        for (my $i = 0; $i<scalar(@outColIndexes); $i++) {
            my $key = $outColIndexes[$i];
            my $col = $termCols[$key];
            next if $found_column{$col};
            push( @outputCol, $col );
        }
    }


    # hack for add_date to match the GenomeList name
    my $i = 0;
    foreach my $x( @outputCol) {
        if($x =~ /add_date/) {
             $outputCol[$i] = "to_char(t.add_date, 'yyyy-mm-dd')";
             last;       
        }
        $i++;
    }


    # No difference between 'quick genome search' and 'Genome Search with all field names'
    require GenomeList;
    GenomeList::printQuickSearchGenomes(\@taxon_oids, $title, $searchTerm, \@outputCol);
    return;

}



############################################################################
# printTaxonSearchExamples - Show some search examples.
#   (Made obsolete by external HTML documentation.)
############################################################################
sub printTaxonSearchExamples {
   my $s = qq{  Examples: "firmicutes", "thermo", "pseudomonas", "coli", "k12",
      "JGI", "TIGR", "DOE", "NIH", "draft", "finished".
   };
   printHint( $s );
}

############################################################################
# validateOid - Get taxon oids from search term
############################################################################
sub validateOid {
    my ($dbh, $term) = @_;
    my $sql = WebUtil::getTaxonReplacementSql();
    my $cur = execSql( $dbh, $sql, $verbose, $term);   

    my @taxon_oids = ();
    for( ;; ) {
       my( $taxon_oid ) = $cur->fetchrow( );
       last if !$taxon_oid;
       push( @taxon_oids, $taxon_oid );
    }
    $cur->finish( );

    return (@taxon_oids);
}

1;
