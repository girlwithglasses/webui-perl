############################################################################
# TaxonList - Show list of taxons in alphabetical or phylogenetic order.
# --es 09/17/2004
#
# $Id: TaxonList.pm 33841 2015-07-29 20:48:56Z klchu $
############################################################################
package TaxonList;
my $section = "TaxonList";
require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
  printPangenomeTable
);
use strict;
use CGI qw( :standard );
use DBI;
use Data::Dumper;
use WebConfig;
use WebUtil;
use PhyloNode;
use PhyloTreeMgr;
use TermNodeMgr;
use TermNode;
use InnerTable;
use DataEntryUtil;
use GoldDataEntryUtil;
use ChartUtil;
use TaxonTableConfiguration;
use OracleUtil;
use HtmlUtil;

my $env                  = getEnv();
my $main_cgi             = $env->{main_cgi};
my $section_cgi          = "$main_cgi?section=$section";
my $verbose              = $env->{verbose};
my $tmp_dir              = $env->{tmp_dir};
my $user_restricted_site = $env->{user_restricted_site};
my $img_internal         = $env->{img_internal};
my $img_lite             = $env->{img_lite};
my $use_img_gold         = $env->{use_img_gold};
my $tmp_url              = $env->{tmp_url};
my $base_url             = $env->{base_url};
my $taxonomy_base_url    = $env->{taxonomy_base_url};
my $YUI                  = $env->{yui_dir_28};
my $yui_tables           = $env->{yui_tables};
my $include_metagenomes  = $env->{include_metagenomes};
my $in_file              = $env->{in_file};
my $img_er_submit_url    = $env->{img_er_submit_url};
my $img_mer_submit_url   = $env->{img_mer_submit_url};

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");

    if ( $page eq "findGenomes" ) {
        printTaxonTable();
    } elsif($page eq 'lastupdated') {
        printLastUpdated();
    } elsif ( $page eq "taxonListAlpha"
              || paramMatch("setTaxonOutputCol") ne "" )
    {
        printTaxonTable();
    } elsif ( $page eq "taxonListPhylo" ) {
        printTaxonTree();
    } elsif ( $page eq "restrictedMicrobes" ) {
        printTaxonTable();
    } elsif ( $page eq "lineageMicrobes" ) {
        printTaxonTable();
    } elsif ( $page eq "pangenome"
              || paramMatch("setPangenomeOutputCol") ne "" )
    {
        printPangenomeTable();
    } elsif ( $page eq "categoryBrowser" ) {
    	require FindGenomesByMetadata;
    	FindGenomesByMetadata::printMetadataCategoryChartResults ();
        #if ($use_img_gold) {
        #    printCategoryBrowser_ImgGold();
        #} else {
        #    printCategoryBrowser();
        #}
    } elsif ( $page eq "genomeCategories" ) {
        if ($use_img_gold) {
            printGenomeCategories();
        }
    } elsif ( $page eq "categoryTaxons" ) {
        if ($use_img_gold) {
            printCategoryTaxons_ImgGold();
        } 
    } elsif ( $page eq "categoryChart" ) {
        if ($use_img_gold) {
            my $category = param("category");

            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq { 
                <response> 
                <div id='piechart'><![CDATA[ 
            };
            printChartForCategory($category);
            print qq { 
                ]]></div>
                </response> 
            };
        }
    } elsif ( $page eq "privateGenomeUsers" ) {
        printPrivateGenomeUsers();
    } elsif ( $page eq "privateGenomeList" ) {
        printPrivateGenomeList();
    } elsif ( $page eq "gebaList" || paramMatch("gebaList") ne "" ) {
        printTaxonTable(1);
    } elsif ( $page eq "selected" || paramMatch("selected") ne "" ) {

        # display only user selected genomes
        printTaxonTable( "", 1 );

    } else {

        # --es 01/02/2006 because of AppHeader has to be handled in main.pl.
        #elsif( paramMatch( "uploadTaxonSelections" ) ne "" ) {
        #   my $taxon_filter_oid_str = uploadTaxonSelections( );
        #   setTaxonSelections( $taxon_filter_oid_str );
        #   printTaxonTable( );
        #}
        printTaxonTable();
    }
}


sub printLastUpdated {
   my $erDate = param('erDate');
    my $imgclause = WebUtil::imgClause('t');
    
    my $imgclause2 = WebUtil::imgClause('t2');
    my $sql2 = qq{
select max(t2.add_date) 
from taxon t2
where 1 = 1
$imgclause2 
    };
    
    if($erDate) {
        $sql2 = qq{
select max(t2.add_date) 
from taxon t2
where t2.obsolete_flag = 'No'
and t2.genome_type = 'isolate'
        };
        $imgclause .= " and t.genome_type = 'isolate' ";
    }
    
    my $sql = qq{
select t.taxon_oid
from taxon t
where t.add_date >= (
$sql2
)
$imgclause
    };
    
    my $dbh = dbLogin();
    require GenomeList;
    
    my $title;
    if($include_metagenomes) {
        $title = 'Newest Metagenomes';
    }

    if($erDate) {
        $title = 'Newest Genomes';
    }

    $title = '<h1>' . $title . '</h1>';

    if($user_restricted_site) {
        $title .= qq{
        <p>
        You may not see all newly added genomes because user permissions
        </p>
        };
    }
    
    GenomeList::printGenomesViaSql($dbh, $sql, $title);
}

############################################################################
# printTaxonTable - Show taxon list in table format.  Columns are
#   configurable as output columns.
#   Inputs:
#     taxon_filter_oid_str - selected genomes list
#     restriction_oid_str - restriction genome list
#
# $geba - 1 to run geba taxonlist
#
############################################################################
sub printTaxonTable {
    my ( $geba, $selected ) = @_;

    my $phylum     = param('phylum');
    my $seq_center = param('seq_center');    # JGI vs Non-JGI
    my $seq_center_clause;
    if ( $seq_center eq "JGI" ) {
        $seq_center_clause = " and nvl(tx.seq_center, 'na') like 'DOE%' ";
    } elsif ( $seq_center eq "Non-JGI" ) {
        $seq_center_clause = " and nvl(tx.seq_center, 'na') not like 'DOE%' ";
    }

    my $gebaClause    = "";
    my @bindList_geba = ();
    if ( $geba == 1 ) {
        my $seq_status   = param("seq_status");
        my $clause       = "";
        my @bindList_seq = ();
        if (    $seq_status eq "Finished"
             || $seq_status eq "Draft"
             || $seq_status eq "Permanent Draft" )
        {
            $clause = " and tx.seq_status = ? ";
            push( @bindList_seq, "$seq_status" );
        }
        $gebaClause = qq{
	        and tx.taxon_oid in (
	        select c1.taxon_permissions
	        from contact_taxon_permissions c1, contact c2
	        where c1.contact_oid = c2.contact_oid
	        and c2.username = ?
	        )
	        $clause
       };
        push( @bindList_geba, "GEBA" );
        push( @bindList_geba, @bindList_seq );
    }

    my $selectedOnlyClause = "";
    my @bindList_txs       = ();

    my $dbh = dbLogin();

    if ($selected) {
        my $txs = txsClause( "tx", $dbh );
        require GenomeCart;
        GenomeCart::insertToGtt($dbh);
        $selectedOnlyClause = $txs;
    }

    my $outputColStr = param("outputCol");
    my @outputCol    = processParamValue($outputColStr);
    my $sortCol      = param("sortCol");

    if (    scalar(@outputCol) == 0
         && paramMatch("setTaxonOutputCol") eq ''
         && param("entry") ne "sort" )
    {
        push( @outputCol, "seq_center" );
        push( @outputCol, "proposal_name" );
        push( @outputCol, "total_gene_count" );
        push( @outputCol, "total_bases" );
        param( -name => "outputCol", -value => \@outputCol );
    }

    my $contact_oid = getContactOid();

    my $inFileClause;
    if ($in_file) {
        $inFileClause = "tx.in_file";
    } else {
        $inFileClause = "'No'";
    }

    my $outColClause;
    my $anyStn       = -1;
    my $mOutStartIdx = -1;
    my @mOutCol      = ();
    for ( my $i = 0 ; $i < scalar(@outputCol) ; $i++ ) {
        my $c         = $outputCol[$i];
        my $tableType = TaxonTableConfiguration::findColType($c);
        if ( $tableType eq 'g' ) {
            if ( $c =~ /add_date/i || $c =~ /release_date/i ) {

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

    my $restrictClause;
    my ( $restrictSql, $bindList_res_aref, $note ) = getParamRestrictionClause();
    my @bindList_res = @$bindList_res_aref;
    $restrictClause = $restrictSql if !blankStr($restrictSql);


    my $rdbms = getRdbms();
    my $x     = 1;
    $x = 0 if $rdbms eq "mysql";
    my $sortClause = "order by substr( tx.domain, $x, 3 ), tx.taxon_display_name";

    my $sortQual = TaxonTableConfiguration::getColSortQual { $sortCol };
    $sortClause = "order by $sortCol $sortQual" if !blankStr($sortCol);

    my ( $rclause, @bindList_ur ) = urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my @bindList = ();
    if ( !blankStr($restrictSql) && scalar(@bindList_res) > 0 ) {
        push( @bindList, @bindList_res );
    }
    processBindList( \@bindList, \@bindList_geba, \@bindList_txs, \@bindList_ur );

    my $sql = qq{
          select tx.taxon_oid
          from taxon tx
          where 1 = 1
          $restrictClause
          $gebaClause
          $selectedOnlyClause
          $rclause
          $imgClause
    };       
    #print "printTaxonTable() sql=$sql<br/>\n";
    #print "printTaxonTable() bindList=@bindList<br/>\n";
    require GenomeList;
    GenomeList::printGenomesViaSql( '', $sql, '', \@bindList, 'TaxonList', $note );

    return;
}

############################################################################
# printPangenomeTable - prints a table of the component oids
#                       for the pangenome
############################################################################
sub printPangenomeTable {
    my ( $taxon_oid, $configure ) = @_;
    if ( $taxon_oid eq "" ) {
        $taxon_oid = param("taxon_oid");
        $configure = "Yes";
    }

    print "<h2>Pangenome Composition</h2>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh       = dbLogin();
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql       = qq{
        select distinct pangenome_composition
        from taxon_pangenome_composition t
        where taxon_oid = ?
        $imgClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @taxon_oids = ();
    for ( ; ; ) {
        my ($id) = $cur->fetchrow();
        last if !$id;
        push( @taxon_oids, $id );
    }
    $cur->finish();
    push( @taxon_oids, $taxon_oid );    # add the pangenome id to the list
    my $taxon_str = join( ",", @taxon_oids );

    my $txTableName = "pangenome_composition";
    print start_form(
                      -id     => $txTableName . "_frm",
                      -name   => "mainForm",
                      -action => "$main_cgi"
    );

    my $outputColStr = param("outputCol");
    my @outputCol    = processParamValue($outputColStr);
    my $sortCol      = param("sortCol");
    if (    scalar(@outputCol) == 0
         && paramMatch("setTaxonOutputCol") eq ''
         && param("entry") ne "sort" )
    {
        push( @outputCol, "seq_center" );
        push( @outputCol, "total_gene_count" );
        push( @outputCol, "total_bases" );
        push( @outputCol, "proposal_name" );
        param( -name => "outputCol", -value => \@outputCol );
    }
    if ( !$configure ) {
        @outputCol = ( "seq_center", "proposal_name", "total_gene_count", "total_bases" );
        param( -name => "pangenomeOutputCol", -value => \@outputCol );
    }

    my $inFileClause;
    if ($in_file) {
        $inFileClause = "tx.in_file";
    } else {
        $inFileClause = "'No'";
    }

    my $outColClause;
    my $mOutStartIdx = -1;
    my @mOutCol      = ();
    for ( my $i = 0 ; $i < scalar(@outputCol) ; $i++ ) {
        my $c         = $outputCol[$i];
        my $tableType = TaxonTableConfiguration::findColType($c);
        if ( $tableType eq 'g' ) {
            if ( $c =~ /add_date/i || $c =~ /release_date/i ) {

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
        }
    }
    if ( $mOutStartIdx >= 0 ) {
        $outColClause .= ", tx.sample_gold_id, tx.submission_id, tx.gold_id";
    }

    my $rdbms = getRdbms();
    my $x     = 1;
    $x = 0 if $rdbms eq "mysql";
    my $sortClause = "order by substr( domain, $x, 3 ), taxon_display_name";

    my $sortQual = TaxonTableConfiguration::getColSortQual { $sortCol };
    $sortClause = "order by $sortCol $sortQual" if !blankStr($sortCol);
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
        select tx.taxon_oid, tx.domain, tx.seq_status,
               tx.taxon_display_name,
               $inFileClause $outColClause
        from taxon tx, taxon_stats stn
        where tx.taxon_oid = stn.taxon_oid
        and tx.taxon_oid in ($taxon_str)
        $imgClause
        $sortClause
    };

    my $cur = execSql( $dbh, $sql, 1 );

    my @recs                = ();
    my @tOids               = ();
    my %tOids2SubmissionIds = ();    #submissionIds, goldIds
    my %tOids2GoldIds       = ();
    my %taxons_in_file;

    for ( ; ; ) {
        my ( $taxon_oid, $domain, $seq_status, $taxon_display_name, $in_file_val, @outColVals ) = $cur->fetchrow();
        last if !$taxon_oid;

        if ( $in_file_val eq 'Yes' ) {
            $taxons_in_file{$taxon_oid} = 1;
        }

        my $r = "$taxon_oid\t";
        $r .= "$domain\t";
        $r .= "$seq_status\t";
        $r .= "$taxon_display_name\t";

        my $nOutColVals = scalar(@outColVals);
        for ( my $j = 0 ; $j < $nOutColVals ; $j++ ) {
            if (
                 $mOutStartIdx >= 0
                 && (    $j == $nOutColVals - 3
                      || $j == $nOutColVals - 2
                      || $j == $nOutColVals - 1 )
              )
            {
                if ( $j == $nOutColVals - 2 ) {
                    $tOids2SubmissionIds{$taxon_oid} = $outColVals[$j]
                      if ( $outColVals[$j] ne '' );
                } elsif ( $j == $nOutColVals - 1 ) {
                    $tOids2GoldIds{$taxon_oid} = $outColVals[$j]
                      if ( $outColVals[$j] ne '' );

                    # gold id for metagenomes is actually $sample_gold_id - ken
                    # but not all metagenomes have sample_gold_id
                    # so use the gold_id
                    # but this gold_id is project_info level metadata
                    my $sample_gold_id = $outColVals[ $nOutColVals - 3 ];
                    if ( $sample_gold_id ne "" ) {
                        $tOids2GoldIds{$taxon_oid} = $sample_gold_id;
                    }
                }
            } else {
                if ( $outColVals[$j] eq '' ) {

                    # to stop the shift on a blank split
                    $r .= "_\t";
                } else {
                    $r .= "$outColVals[$j]\t";
                }
            }
        }
        push( @recs,  $r );
        push( @tOids, $taxon_oid );
    }
    $cur->finish();

    my %tOids2Meta = {};
    %tOids2Meta = GoldDataEntryUtil::getMetadataForAttrs_new_2_0( \%tOids2SubmissionIds, \%tOids2GoldIds, \@mOutCol )
      if ( $mOutStartIdx >= 0 );

    print "<p>\n";
    print domainLetterNote() . "<br/>\n";
    print completionLetterNoteParen();
    print "</p>\n";


    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    my @taxon_oids           = split( /,/, $taxon_filter_oid_str );
    my %taxon_filter         = WebUtil::array2Hash(@taxon_oids);

    my $it = new InnerTable( 1, $txTableName . "$$", $txTableName, 1 );
    my $sd = $it->getSdDelim();    # sort delimiter
    $it->addColSpec("Select");
    $it->addColSpec( "Domain", "char asc", "center", "",
                     "*=Microbiome, B=Bacteria, A=Archaea, E=Eukarya, P=Plasmids, G=GFragment, V=Viruses" );  #D for 'domain'
    $it->addColSpec( "Status", "char asc", "center", "", "Sequencing Status: F=Finished, P=Permanent Draft, D=Draft" )
      ;    #C for 'seq_status'
    $it->addColSpec( TaxonTableConfiguration::getColLabel("taxon_display_name"), "char asc", "left" );

    foreach my $col (@outputCol) {
        my $colName  = TaxonTableConfiguration::getColLabel($col);
        my $tooltip  = TaxonTableConfiguration::getColTooltip($col);
        my $colAlign = TaxonTableConfiguration::getColAlign($col);
        if ( $colAlign eq "num asc right" ) {
            $it->addColSpec( "$colName", "asc", "right", '', $tooltip );
        } elsif ( $colAlign eq "num desc right" ) {
            $it->addColSpec( "$colName", "desc", "right", '', $tooltip );
        } elsif ( $colAlign eq "num desc left" ) {
            $it->addColSpec( "$colName", "desc", "left", '', $tooltip );
        } elsif ( $colAlign eq "char asc left" ) {
            $it->addColSpec( "$colName", "asc", "left", '', $tooltip );
        } elsif ( $colAlign eq "char desc left" ) {
            $it->addColSpec( "$colName", "desc", "left", '', $tooltip );
        } else {
            $it->addColSpec( "$colName", '', '', '', $tooltip );
        }
    }

    my $count = 0;
    foreach my $r (@recs) {
        my ( $taxon_oid, $domain, $seq_status, $taxon_display_name, @outColVals ) =
          split( /\t/, $r );
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
        $count++;

        my $checked = "";
        $checked = " checked " if $taxon_filter{$taxon_oid} ne "";
        $checked = " checked " if blankStr($taxon_filter_oid_str);

        my $row;
        $row .= $sd
          . "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' $checked />\t"
          . $domain
          . $sd
          . substr( $domain, 0, 1 ) . "\t"
          . $seq_status
          . $sd
          . substr( $seq_status, 0, 1 ) . "\t";

        my $url;
        if ( $taxons_in_file{$taxon_oid} ) {
            $url = "$main_cgi?section=MetaDetail" . "&page=metaDetail&taxon_oid=$taxon_oid";
        } else {
            $url = "$main_cgi?section=TaxonDetail" . "&page=taxonDetail&taxon_oid=$taxon_oid";
        }
        $row .= $taxon_display_name . $sd . alink( $url, $taxon_display_name ) . "\t";

        for ( my $j = 0 ; $j < scalar(@outputCol) ; $j++ ) {
            my $col    = $outputCol[$j];
            my $colVal = $outColVals[$j];

            #print "$col: $colVal<br/>\n";
            if ( $col eq 'proposal_name' ) {

                # to make sorting work - ken
                my $mynull = $colVal;
                if ( $colVal eq "" ) {
                    $mynull = "zzz";
                    $colVal = "_";
                }
                $row .= $mynull . $sd . $colVal . "\t";
            } elsif ( $colVal eq '_' && $col ne 'proposal_name' ) {

                # shift stop - see above where I add '_' for blanks and in metadata from gold - ken
                $row .= '-1' . $sd . '_' . "\t";
            } elsif ( $col eq "seq_center" && $colVal =~ /JGI/ ) {
                my $x1      = "<font color='red'>";
                my $x2      = "</font>";
                my $colVal2 = $colVal;
                $colVal2 =~ s/JGI/${x1}JGI${x2}/;
                $row .= $colVal . $sd . $colVal2 . "\t";
            } elsif ( $col eq "seq_center" && $colVal =~ /DOE Joint Genome Institute/ ) {
                my $x1      = "<font color='red'>";
                my $x2      = "</font>";
                my $colVal2 = $colVal;
                $colVal2 =~ s/DOE Joint Genome Institute/${x1}DOE Joint Genome Institute${x2}/;
                $row .= $colVal . $sd . $colVal2 . "\t";
            } elsif ( $col eq 'ncbi_taxon_id' && $colVal ) {
                my $ncbiTxid_url = "$taxonomy_base_url$colVal";
                $ncbiTxid_url = alink( $ncbiTxid_url, $colVal );
                $row .= $colVal . $sd . $ncbiTxid_url . "\t";
            } elsif ( $col eq 'refseq_project_id' && $colVal ) {
                my $ncbiPid_url = TaxonSearchUtil::getNCBIProjectIdLink($colVal);
                $row .= $colVal . $sd . $ncbiPid_url . "\t";
            } elsif ( $col eq 'gbk_project_id' && $colVal ) {
                my $ncbiPid_url = TaxonSearchUtil::getNCBIProjectIdLink($colVal);
                $row .= $colVal . $sd . $ncbiPid_url . "\t";
            } elsif ( $col eq 'gold_id' && $colVal ) {
                my $goldId_url = HtmlUtil::getGoldUrl($colVal);
                $goldId_url = alink( $goldId_url, $colVal );
                $row .= $colVal . $sd . $goldId_url . "\t";
            } elsif ( $col eq 'sample_gold_id' && $colVal ) {
                my $goldId_url = HtmlUtil::getGoldUrl($colVal);
                $goldId_url = alink( $goldId_url, $colVal );
                $row .= $colVal . $sd . $goldId_url . "\t";
            } elsif ( $col eq 'submission_id' && $colVal ) {
                my $url = $img_er_submit_url;
                $url = $img_mer_submit_url if ( $domain eq "*Microbiome" );
                $url = $url . $colVal;
                $url = alink( $url, $colVal );
                $row .= $colVal . $sd . $url . "\t";
            } elsif ( $col eq 'project_info' && $colVal ) {
                my $url =
                  "https://img.jgi.doe.gov/cgi-bin/submit/main.cgi?section=ProjectInfo&page=displayProject&project_oid=";
                $url .= $colVal;
                $url = alink( $url, $colVal );
                $row .= $colVal . $sd . $url . "\t";
            } else {

                #$colVal = nbsp(1) if !$colVal;
                if ( !$colVal || blankStr($colVal) ) {
                    $row .= '-1' . $sd . '_' . "\t";
                } else {
                    $row .= $colVal . $sd . $colVal . "\t";
                }
            }
        }
        $it->addRow($row);
    }

    print hiddenVar( "page",          "message" );
    print hiddenVar( "message",       "Genome selection saved and enabled." );
    print hiddenVar( "menuSelection", "Genomes" );
    print hiddenVar( "mainPageStats", param("mainPageStats") );
    print hiddenVar( "taxon_oid",     $taxon_oid );

    if ( $count > 10 ) {
        print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('$txTableName')"
        );
        print nbsp(1);
        WebUtil::printButtonFooter($txTableName . "1", $txTableName . "0");
    }
    $it->printOuterTable(1);

    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('$txTableName')"
    );
    print nbsp(1);
    WebUtil::printButtonFooter($txTableName . "1", $txTableName . "0");

    ## Configuration form
    if ( $configure eq "Yes" ) {
        my %outputColHash = WebUtil::array2Hash(@outputCol);
        printTaxonTableConfiguration( \%outputColHash, 0, 1 );
    }
    printStatusLine( "$count genome(s) retrieved.", 2 );
    print end_form();
    ##$dbh->disconnect();
}

############################################################################
# taxonListPhyloRestrictions - Add any rank restrictions from
#   parent page.
############################################################################
sub taxonListPhyloRestrictions {
    return getParamRestrictionUrl();
}

############################################################################
# printTaxonTableConfiguration - Print output attributtes for optional
#   configuration information.
############################################################################
sub printTaxonTableConfiguration {
    my ( $outputColHash_ref, $geba, $is_pangenome, $selected ) = @_;

    my $name = "_section_${section}_setTaxonOutputCol";
    if ($is_pangenome) {
        $name = "_section_${section}_setPangenomeOutputCol";
        my $taxon_oid = param("taxon_oid");
        print qq{
           <input type="hidden" name='taxon_oid' value='$taxon_oid' />
       };
    }

    my $seq_center = param("seq_center");
    if ( $seq_center ne "" ) {
        print qq{
           <input type="hidden" name='seq_center' value='$seq_center' />
       };
    }

    if ($geba) {
        $name = "_section_${section}_gebaList";
        my $seq_status = param("seq_status");
        print qq{
           <input type="hidden" name='page' value='gebaList' />
           <input type="hidden" name='seq_status' value='$seq_status' />
       };
    }

    if ($selected) {
        $name = "_section_${section}_selected";
        my $seq_status = param("seq_status");
        print qq{
           <input type="hidden" name='page' value='selected' />
       };
    }

    TaxonTableConfiguration::appendTaxonTableConfiguration( $outputColHash_ref, $name );
}

############################################################################
# sortLink - Utility function to generate URL link for sorting
#   in the genome table.
############################################################################
sub sortLink {
    my ( $colName, $geba, $selected ) = @_;
    my $url = "$section_cgi&page=taxonListAlpha&entry=sort";
    if ($geba) {
        my $seq_status = param("seq_status");
        my $clause     = "";
        if ( $seq_status ne "" ) {
            $clause = "&seq_status=$seq_status";
        }

        $url = "$section_cgi&page=gebaList&mainPageStats=1&entry=sort" . $clause;
    }

    if ($selected) {
        $url = "$section_cgi&page=selected&mainPageStats=1&entry=sort";
    }

    my $seq_center = param("seq_center");
    $url .= "&seq_center=$seq_center" if ( $seq_center ne '' );

    my @outputCol = param("outputCol");
    for my $c (@outputCol) {
        $url .= "&outputCol=$c";
    }
    $url .= "&sortCol=$colName";
    $url .= getParamRestrictionUrl();
    my $s = alink( $url, TaxonTableConfiguration::getColLabel($colName) );
    return $s;
}

############################################################################
# printTaxonTree - Show taxon list as a phylogenetic tree.
############################################################################
sub printTaxonTree {
    my $taxon_filter_oid_str = WebUtil::getTaxonFilterOidStr();
    my @taxon_oids = split( /,/, $taxon_filter_oid_str );
    my %taxon_filter;
    for my $t (@taxon_oids) {
        $taxon_filter{$t} = $t;
    }
    printMainForm();
    print "<h1>Genome Browser</h1>\n";
    printStatusLine( "Loading ...", 1 );

    my $dbh = dbLogin();

    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('');"
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
	. "onClick='selectAllTaxons(1)' class='smbutton' />";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  "
	. "onClick='selectAllTaxons(0)' class='smbutton' />";
    print nbsp(1);
    my $url = "$section_cgi&page=taxonListAlpha";
    $url .= getParamRestrictionUrl();
    print buttonUrl( $url, "View Alphabetically", "smbutton" );
    printTreeNotes();

    ## Load taxon_oid => taxon_display_names map.
    my %taxonNames;
    my %seqCenter;
    my %envSample;
    my ( $rclause, @bindList_ur ) = urClauseBind("");
    my $imgClause = WebUtil::imgClauseNoTaxon('t.taxon_oid');
    my $sql       = qq{
      select taxon_oid, taxon_display_name, seq_center, env_sample
      from vw_taxon t
      where 1 = 1
      $rclause
      $imgClause
    };
    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, 1 );

    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $seq_center, $env_sample ) = $cur->fetchrow();
        last if !$taxon_oid;
        $taxonNames{$taxon_oid} = $taxon_display_name;
        $seqCenter{$taxon_oid}  = $seq_center;
        $envSample{$taxon_oid}  = $env_sample;
    }
    $cur->finish();

    my $mgr = new PhyloTreeMgr();
    $mgr->loadPhyloTree("pageRestrictedMicrobes");
    my @keys             = keys(%taxon_filter);
    my $taxon_filter_cnt = @keys;
    $mgr->printSelectableTree( \%taxon_filter, $taxon_filter_cnt );
    print "<br/>\n";

    #print "</div>\n";
    print "</p>\n";

    #print hiddenVar( "page", "taxonListPhylo" );
    print hiddenVar( "page",          "message" );
    print hiddenVar( "message",       "Genome selection saved and enabled." );
    print hiddenVar( "menuSelection", "Genomes" );
    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('');"
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
	. "onClick='selectAllTaxons(1)', class='smbutton' />";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  " 
	. "onClick='selectAllTaxons(0)', class='smbutton' />";
    print nbsp(1);
    my $url = "$section_cgi&page=taxonListAlpha";
    $url .= getParamRestrictionUrl();
    print buttonUrl( $url, "View Alphabetically", "smbutton" );
    ##$dbh->disconnect();
    printStatusLine( "Loaded.", 2 );
    print end_form();
}

############################################################################
# printTreeNotes - Show additional notes.
############################################################################
sub printTreeNotes {
    TaxonSearchUtil::printNotesHint();
    print "<p>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
}

############################################################################
# getParamRestrictionClause - Get SQL restrictions from CGI parameters.
############################################################################
sub getParamRestrictionClause {
    my $genome_type = param("genome_type");
    my $domain      = param("domain");
    my $phylum      = param("phylum");
    my $ir_class    = param("ir_class");
    my $ir_order    = param("ir_order");
    my $family      = param("family");
    my $genus       = param("genus");

    my $release_date = param('release_date');    # format yyyy-mm-dd

    # new - ken
    my $species = param("species");

    my $seq_center    = param("seq_center");
    my $seq_status    = param("seq_status");
    my $mainPageStats = param("mainPageStats");
    my $restrictClause;

    my @bindList = ();

    my $release_date_clause;
    if ( $release_date ne '' ) {
        $release_date_clause = " and is_public = 'Yes' and tx.release_date >= to_date(?, 'yyyy-mm-dd') ";
        $restrictClause .= $release_date_clause;
        push( @bindList, $release_date );
    }

    if ( $domain ne "" && $domain ne "all") {
        if ( $domain =~ /Plasmid/ ) {
            $restrictClause .= "and tx.domain like ? ";
            push( @bindList, 'Plasmid%' );
        } elsif ( $domain =~ /^GFragment/ ) {
            $restrictClause .= "and tx.domain like ? ";
            push( @bindList, 'GFragment%' );
        } elsif ( $domain =~ /^Vir/ ) {
            $restrictClause .= "and tx.domain like ? ";
            push( @bindList, 'Vir%' );
        } else {
            $restrictClause .= "and tx.domain = ? ";
            push( @bindList, "$domain" );
        }
    } elsif ( $mainPageStats eq "" ) {
        my $hideViruses = getSessionParam("hideViruses");
        $hideViruses = "Yes" if $hideViruses eq "";
        if ( $hideViruses eq "Yes" ) {
            $restrictClause .= "and tx.domain not like ? ";
            push( @bindList, 'Vir%' );
        }
        my $hidePlasmids = getSessionParam("hidePlasmids");
        $hidePlasmids = "Yes" if $hidePlasmids eq "";
        if ( $hidePlasmids eq "Yes" ) {
            $restrictClause .= "and tx.domain not like ? ";
            push( @bindList, 'Plasmid%' );
        }
        my $hideGFragment = getSessionParam("hideGFragment");
        $hideGFragment = "Yes" if $hideGFragment eq "";
        if ( $hideGFragment eq "Yes" ) {
            $restrictClause .= "and tx.domain not like ? ";
            push( @bindList, 'GFragment%' );
        }
    }

    my $note = "";
    if ( $phylum ne "" ) {
        $restrictClause .= "and tx.phylum = ? ";
        push( @bindList, "$phylum" );
	$note .= "<br/>" if $note ne "";
	$note .= "<u>Phylum</u>: $phylum";
    }
    if ( $ir_class ne "" ) {
        $restrictClause .= "and tx.ir_class = ? ";
        push( @bindList, "$ir_class" );
	$note .= "<br/>" if $note ne "";
	$note .= "<u>Class</u>: $ir_class";
    }
    if ( $ir_order ne "" ) {
        $restrictClause .= "and tx.ir_order = ? ";
        push( @bindList, "$ir_order" );
	$note .= "<br/>" if $note ne "";
	$note .= "<u>Order</u>: $ir_order";
    }
    if ( $family ne "" ) {
        $restrictClause .= "and tx.family = ? ";
        push( @bindList, "$family" );
	$note .= "<br/>" if $note ne "";
	$note .= "<u>Family</u>: $family";
    }
    if ( $genus ne "" ) {
        $restrictClause .= "and tx.genus = ? ";
        push( @bindList, "$genus" );
	$note .= "<br/>" if $note ne "";
	$note .= "<u>Genus</u>: $genus";
    }
    if ( $species ne "" ) {
        $restrictClause .= "and tx.species = ? ";
        push( @bindList, "$species" );
	$note .= "<br/>" if $note ne "";
	$note .= "<u>Species</u>: $species";
    }
    $note = "<p>$note</p>" if $note ne "";

    if ( $seq_center ne "" ) {
        if ( $seq_center eq "JGI" ) {
            $restrictClause .= "and nvl(tx.seq_center, 'na') like ? ";
            push( @bindList, 'DOE%' );
        } elsif ( $seq_center eq "Non-JGI" ) {
            $restrictClause .= "and nvl(tx.seq_center, 'na') not like ? ";
            push( @bindList, 'DOE%' );
        } else {
            $restrictClause .= "and tx.seq_center = ? ";
            push( @bindList, "$seq_center" );
        }
    }
    if ( $seq_status ne "" ) {
        $restrictClause .= "and tx.seq_status = ? ";
        push( @bindList, "$seq_status" );
    }

    return ( $restrictClause, \@bindList, $note );
}

############################################################################
# printParamRestrictionVars - Preserve restriction parameters.
############################################################################
sub printParamRestrictionVars {
    my $domain     = param("domain");
    my $phylum     = param("phylum");
    my $ir_class   = param("ir_class");
    my $ir_order   = param("ir_order");
    my $family     = param("family");
    my $genus      = param("genus");
    my $seq_center = param("seq_center");
    my $seq_status = param("seq_status");
    print hiddenVar( "domain",     $domain );
    print hiddenVar( "phylum",     $phylum );
    print hiddenVar( "ir_class",   $ir_class );
    print hiddenVar( "ir_order",   $ir_order );
    print hiddenVar( "family",     $family );
    print hiddenVar( "genus",      $genus );
    print hiddenVar( "seq_center", $seq_center );
    print hiddenVar( "seq_status", $seq_status );
}

############################################################################
# getParamRestrictionUrl - Preserve restriction parameters in URL.
###########################################################################
sub getParamRestrictionUrl {
    my $genome_type = massageToUrl( param("genome_type") );
    my $domain      = massageToUrl( param("domain") );
    my $phylum      = massageToUrl( param("phylum") );
    my $ir_class    = massageToUrl( param("ir_class") );
    my $ir_order    = massageToUrl( param("ir_order") );
    my $family      = massageToUrl( param("family") );
    my $genus       = massageToUrl( param("genus") );
    my $seq_center  = massageToUrl( param("seq_center") );
    my $seq_status  = massageToUrl( param("seq_status") );
    my $s;
    $s .= "&domain=$domain"           if $domain      ne "";
    $s .= "&phylum=$phylum"           if $phylum      ne "";
    $s .= "&ir_class=$ir_class"       if $ir_class    ne "";
    $s .= "&ir_order=$ir_order"       if $ir_order    ne "";
    $s .= "&family=$family"           if $family      ne "";
    $s .= "&genus=$genus"             if $genus       ne "";
    $s .= "&seq_center=$seq_center"   if $seq_center  ne "";
    $s .= "&seq_status=$seq_status"   if $seq_status  ne "";
    $s .= "&genome_type=$genome_type" if $genome_type ne "";
    return $s;
}

############################################################################
# uploadTaxonSelections - Upload with loading message.
############################################################################
sub uploadTaxonSelections {
    use MyIMG;
    my @taxon_oids;
    my $errmsg;
    if ( !MyIMG::uploadOidsFromFile( "taxon_oid", \@taxon_oids, \$errmsg ) ) {
        printStatusLine( "Error.", 2 );
        webError($errmsg);
    }
    my $dbh = dbLogin();
    my @finalOids;
    my @badOids;
    taxonOidsMap( $dbh, \@taxon_oids, \@finalOids, \@badOids );
    ##$dbh->disconnect();
    if ( scalar(@badOids) > 0 ) {
        my $bad_oid_str = join( ', ', @badOids );
        param( -name => "bad_oid_str", -value => $bad_oid_str );
    }
    my $taxon_filter_oid_str = join( ',', @finalOids );
    setSessionParam( "taxon_filter_oid_str", $taxon_filter_oid_str );
    return $taxon_filter_oid_str;
}

############################################################################
# printCategoryBrowser - Show list of categories.
############################################################################
sub printCategoryBrowser {

    print "<h1>Category Browser (Experimental)</h1>\n";
    print "<p>\n";
    print "Genomes are organized into various genome categories<br/>";
    print "<a href='#phenotype'>phenotype<a>, ";
    print "<a href='#ecotype'>habitat<a>, ";
    print "<a href='#disease'>disease<a>, and ";
    print "<a href='#relevance'>relevance</a>. <br/>";
    print "Please select a category below.<br/>\n";
    print "</p>\n";

    my $dbh = dbLogin();
    print "<p>\n";

    print "<a name='phenotype' id='phenotype'></a>\n";
    my $url = "$section_cgi&page=categoryTaxons&category=phenotype";
    print "<h3><b>" . alink( $url, "Phenotype" ) . "</b></h3>\n";
    printCategoryValues( $dbh, "phenotype" );

    print "<hr>\n";

    print "<a name='ecotype' id='ecotype'></a>\n";
    my $url = "$section_cgi&page=categoryTaxons&category=ecotype";
    print "<h3><b>" . alink( $url, "Habitat" ) . "</b></h3>\n";
    printCategoryValues( $dbh, "ecotype" );

    print "<hr>\n";

    print "<a name='disease' id='disease'></a>\n";
    my $url = "$section_cgi&page=categoryTaxons&category=disease";
    print "<h3><b>" . alink( $url, "Disease" ) . "</b></h3>\n";
    printCategoryValues( $dbh, "disease" );

    print "<hr>\n";

    print "<a name='relevance' id='relevance'></a>\n";
    my $url = "$section_cgi&page=categoryTaxons&category=relevance";
    print "<h3><b>" . alink( $url, "Relevance" ) . "</b></h3>\n";
    printCategoryValues( $dbh, "relevance" );

    print "</p>\n";
    ##$dbh->disconnect();
}

############################################################################
# printCategoryBrowser_ImgGold - Show list of categories.
############################################################################
sub printCategoryBrowser_ImgGold {
    print "<h1>Category Browser</h1>\n";

    print "<p>\n";
    print "Genomes are organized into various genome categories:<br/>";
    my @attrs = DataEntryUtil::getGoldCondAttr();
    my $count = 0;
    for my $attr1 (@attrs) {
        if ( $count > 0 ) {
            print ", ";
            if ( $count % 5 == 0 ) {
                print "<br/>";
            }
        }
        $count++;
        print "<a href='#" . $attr1 . "'>" . DataEntryUtil::getGoldAttrDisplayName($attr1) . "</a>";
    }
    print "</p>";

    print "<p>";
    print "Please select a category below.<br/>\n";
    print "</p>\n";

    my $dbh = WebUtil::dbGoldLogin();

    print "<p>\n";
    for my $attr1 (@attrs) {
        print "<a name='$attr1' id='attr1'></a>\n";

        #my $url = "$section_cgi&page=categoryTaxons&category=$attr1";
        #if (    exists $chart_attrs{$attr1}
        #     || exists $chart_host_attrs{$attr1} )
        #{
        #    $url = "$section_cgi&page=categoryChart&category=$attr1";
        #}

        my $url = "$section_cgi&page=genomeCategories#";

        print "<h2>" . alink( $url, DataEntryUtil::getGoldAttrDisplayName($attr1) ) . "</h2>\n";
        my $cv_sql = DataEntryUtil::getGoldAttrCVQuery($attr1);
        if ( !blankStr($cv_sql) ) {
            print "<p>";
            printControlledValues( $dbh, $attr1, $cv_sql );
            print "</p>";
        }

        ### add this
        #	my %dist = getGoldAttrDistribution($attr1);
        #	for my $key (keys %dist) {
        #	    print "<p>$key: " . $dist{$key} . "</p>\n";
        #	}
        ### end
    }

    print "</p>\n";
    ##$dbh->disconnect();
}

############################################################################
# printGenomeCategories
############################################################################
sub printGenomeCategories {
    print "<script src='$base_url/overlib.js'></script>\n";    ## for tooltips
    print "<h1>Metadata Categories</h1>\n";

    print "<h2>Organism Metadata</h2>\n";
    my @chart_attrs = (
        'oxygen_req',            'cell_shape',    'motility',   'sporulation',
        'salinity',              'temp_range',    'gram_stain', 'biotic_rel',
        'symbiotic_interaction', 'symbiotic_rel', 'symbiont'
    );

    print "<p>\n";
    for my $attr1 (@chart_attrs) {
        my $url = "xml.cgi?section=$section" 
            . "&page=categoryChart&category=$attr1";
        print "<a href='#' "
          . "onclick=javascript:showChart('righttop','$url')>"
          . DataEntryUtil::getGoldAttrDisplayName($attr1)
          . "</a><br/>";
    }
    print "</p>\n";

    if ($include_metagenomes) {
        print "<h2>Ecosystem Metadata</h2>\n";
        my @chart_eco_attrs =
          ( 'ecosystem', 'ecosystem_category', 'ecosystem_type', 'ecosystem_subtype', 'specific_ecosystem' );

        print "<p>\n";
        for my $attr1 (@chart_eco_attrs) {
            my $url = "xml.cgi?section=$section" . "&page=categoryChart&category=$attr1";
            print "<a href='#' "
              . "onclick=javascript:showChart('righttop','$url')>"
              . DataEntryUtil::getGoldAttrDisplayName($attr1)
              . "</a><br/>";
        }
        print "</p>\n";
    }

    print "<h2>Host Metadata</h2>\n";
    my @chart_host_attrs = ( 'host_name', 'host_gender', 'host_health' );

    print "<p>\n";
    for my $attr2 (@chart_host_attrs) {
        my $url = "xml.cgi?section=$section" . "&page=categoryChart&category=$attr2";
        print "<a href='#' "
          . "onclick=javascript:showChart('righttop','$url')>"
          . DataEntryUtil::getGoldAttrDisplayName($attr2)
          . "</a><br />";
    }
    print "</p>\n";

    print qq{ 
        <link rel="stylesheet" type="text/css" 
            href="$YUI/build/container/assets/skins/sam/container.css" />
        <script type="text/javascript" 
            src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script> 
        <script type="text/javascript" 
            src="$YUI/build/dragdrop/dragdrop-min.js"></script>
        <script type="text/javascript" 
            src="$YUI/build/container/container-min.js"></script>
        <script src="$YUI/build/yahoo/yahoo-min.js"></script>
        <script src="$YUI/build/event/event-min.js"></script>
        <script src="$YUI/build/connection/connection-min.js"></script>
    };

    print "<script src='$base_url/chart.js'></script>\n";
    print qq{ 
        <script language='JavaScript' type='text/javascript'>
        function showChart(divid, url) {
            showDiv(divid, url);
        }
 
        function handleSuccess(req) {
            try { 
                id = req.argument;
                response = req.responseXML.documentElement;
                var html = response.getElementsByTagName
                    ('div')[0].firstChild.data;
                document.getElementById(id).innerHTML = html; 
            } catch(e) { 
            } 
            YAHOO.example.container.wait.hide(); 
        }

        function showDiv(id, url) {
            YAHOO.namespace("example.container");
            if (!YAHOO.example.container.wait) { 
                initializeWaitPanel(); 
            } 
 
            var callback = {
              success: handleSuccess,
              failure: function(req) { 
                  YAHOO.example.container.wait.hide();
              },
              argument: id
            };

            if (url != null && url != "") { 
                YAHOO.example.container.wait.show(); 
                var request = YAHOO.util.Connect.asyncRequest
                    ('GET', url, callback);
            } 
        } 
        </script> 
    };

    print "<div id='righttop'></div>";
}

############################################################################
# printChartForCategory - display a pie chart for a given category attribute
############################################################################
sub printChartForCategory {
    my ($category)  = @_;
    
    my $section_url = "$section_cgi&page=categoryTaxons&category=$category";
    my $name        = DataEntryUtil::getGoldAttrDisplayName($category);

    print "<h2>$name</h2>\n";

    #### PREPARE THE PIECHART ######
    my $chart = newPieChart();
    $chart->WIDTH(250);
    $chart->HEIGHT(250);
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_URLS("yes");
    $chart->ITEM_URL($section_url);
    $chart->URL_SECTION_NAME("categoryValue");
    my @chartseries;
    my @chartcategoryvalues;
    my @chartdata;
    #################################

    webLog "Get results " . currDateTime() . "\n" if $verbose >= 1;

    print "<p>\n";
    print "<table border=0>\n";
    print "<tr>";
    print "<td valign='top'>\n";

    if ($yui_tables) {
        print qq{
        <link rel="stylesheet" type="text/css"
            href="$YUI/build/datatable/assets/skins/sam/datatable.css" />
	};

        print <<YUI;
        <div class='yui-dt'>
        <table style='font-size:12px'>
        <th>
	    <div class='yui-dt-liner'>
	        <span>Categories</span>
	    </div>
	</th>
        <th>
	    <div class='yui-dt-liner'>
	        <span style='text-align:right'>Count</span>
	    </div>
	</th>
	</tr>
YUI
    } else {
        print "<table class='img'>\n";
        print "<th class='img' >Categories</th>\n";
        print "<th class='img' >Count</th>\n";
    }
    
    my $dbh = WebUtil::dbGoldLogin();
    my $sql = DataEntryUtil::getGoldAttrCVQuery($category);
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ; ; ) {
        my ($cv_val) = $cur->fetchrow();
        last if !defined($cv_val);
        push @chartcategoryvalues, $cv_val;
    }
    $cur->finish();

    my $dbh2 = dbLogin();
    my $total_count = QueryUtil::getTotalTaxonCount( $dbh2 );
    require GenomeList;
    my %dist = GenomeList::getMetadataCategoryTaxonCount($dbh2, $category);
    #print "printChartForCategory() dist:<br/>\n";
    #print Dumper(\%dist);
    #print "<br/>\n";

    my @values;
    foreach my $val1 (@chartcategoryvalues) {
        my $count = 0;
        if ( exists $dist{$val1}
             && defined $dist{$val1} )
        {
            $count       = $dist{$val1};
            $total_count = ( $total_count - $count );
            push @values,    $val1;
            push @chartdata, $count;
        }
    }

    if ( $category ne "body_sample_site" ) {
        push @chartdata, $total_count;
        push @values,    "Unknown";
    }

    push @chartseries, "count";
    $chart->SERIES_NAME( \@chartseries );
    $chart->CATEGORY_NAME( \@values );
    my $datastr = join( ",", @chartdata );
    my @datas = ($datastr);
    $chart->DATA( \@datas );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    my $idx = 0;
    my $classStr;
    for my $value1 (@values) {
        last if !$value1;
        my $url = "$section_cgi&page=categoryTaxons";
        $url .= "&category=$category";
        $url .= "&categoryValue=$value1";

        if ($yui_tables) {
            $classStr = !$idx ? "yui-dt-first " : "";
            $classStr .= ( $idx % 2 == 0 ) ? "yui-dt-even" : "yui-dt-odd";
        } else {
            $classStr = "img";
        }

        print "<tr class='$classStr' >\n";
        print "<td class='$classStr' >\n";
        print "<div class='yui-dt-liner'>\n" if $yui_tables;

        if ( $st == 0 ) {
            if ( $value1 eq "Unknown" ) {
                print "<img src='$tmp_url/" . $chart->FILE_PREFIX . "-color-" . $idx . ".png' border=0>";
                print "&nbsp;&nbsp;";
            } else {
                print "<a href='$url'>";
                print "<img src='$tmp_url/" . $chart->FILE_PREFIX . "-color-" . $idx . ".png' border=0>";
                print "</a>";
                print "&nbsp;&nbsp;";
            }
        }
        print escHtml($value1);
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "<td style='text-align:right' class='$classStr'>\n";
        print "<div class='yui-dt-liner'>\n" if $yui_tables;
        if ( $value1 eq "Unknown" ) {
            print "$chartdata[$idx]";
        } else {
            print alink( $url, $chartdata[$idx] );
        }
        print "</div>\n" if $yui_tables;
        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }

    print "</table>\n";
    print "</td>\n";
    print "<td valign=top align=left>\n";

    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html", "printChartForCategory", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/" . $chart->FILE_PREFIX . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################

    #$dbh2->disconnect();
    webLog "Done " . currDateTime() . "\n" if $verbose >= 1;

    print "</td></tr>\n";
    print "</table>\n";
    print "</p>\n";
}


############################################################################
# printControlledValues
############################################################################
sub printControlledValues {
    my ( $dbh, $type, $cv_sql ) = @_;

    my $cur = execSql( $dbh, $cv_sql, $verbose );
    my $cnt = 0;
    for ( ; ; ) {
        my ($cv_val) = $cur->fetchrow();
        last if !defined($cv_val);

        my $url = "$main_cgi?section=TaxonList&page=categoryTaxons";
        $url .= "&category=$type";
        $url .= "&categoryValue=" . massageToUrl($cv_val);
        my $val = alink( $url, $cv_val );

        print nbsp(2) . $val . "<br/>\n";

        $cnt++;
        if ( $cnt > 2000 ) {
            print "<font color='red'>Too Many Values!</font><br/>\n";
            last;
        }
    }
    $cur->finish();
}

############################################################################
# printCategoryValues - Show category values with taxons.
############################################################################
sub printCategoryValues {
    my ( $dbh, $category ) = @_;

    print "<p>\n";
    my $mgr = new TermNodeMgr();
    $mgr->loadTree( $dbh, $category );
    my $root = $mgr->getRoot();
    $root->printTaxonCategoryNode($category);
    print "</p>\n";
}

sub printCategoryValuesFlat {
    my ( $dbh, $category ) = @_;

    my ( $rclause, @bindList_ur ) = urClauseBind("tx.taxon_oid");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select distinct cv.${category}_term
       from project_info_${category}s pi, ${category}cv cv, taxon tx
       where pi.${category}s = cv.${category}_oid
       and pi.project_oid = tx.project
       $rclause
       $imgClause
       order by cv.${category}_term
    };
    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    print "<p>\n";
    for ( ; ; ) {
        my ($category_term) = $cur->fetchrow();
        last if !$category_term;
        print nbsp(4);
        my $url = "$section_cgi&page=categoryTaxons";
        $url .= "&category=$category";
        $url .= "&categoryValue=" . massageToUrl($category_term);
        print alink( $url, $category_term );
        print "<br/>\n";
    }
    print "</p>\n";
    $cur->finish();
    print "<br/>\n";
}

############################################################################
# printCategoryTaxons - Show taxons under a category.
############################################################################
sub printCategoryTaxonsHier {
    my $category      = param("category");
    my $categoryValue = param("categoryValue");

    my $category2 = substr( $category, 0, 1 );
    $category2 =~ tr/a-z/A-Z/;
    $category2 .= substr( $category, 1 );

    print "<h1>$category2</h1>\n";
    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );
    printMainForm();
    printFooterButtons();
    print "<p>\n";
    print domainLetterNoteParen() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    print "<p>\n";
    my $mgr = new TermNodeMgr();
    $mgr->loadTree( $dbh, $category );
    my $root = $mgr->getRoot();
    $root->printCategoryNodeTaxons( $dbh, $category );
    print "</p>\n";
    printStatusLine( "Loaded.", 2 );
    print end_form();
    ##$dbh->disconnect();
}

###########################################################################
# printCategoryTaxonStats_ImgGold
###########################################################################
sub printCategoryTaxonStats_ImgGold {
    my $category = param("category");

    print "<h1>" . DataEntryUtil::getGoldAttrDisplayName($category) . "</h1>\n";

    if ( blankStr($category) ) {
        print end_form();
        return;
    }

    printStatusLine( "Loading ...", 1 );
    printMainForm();

    my $dbh2 = dbLogin();
    require GenomeList;
    my %dist = GenomeList::getMetadataCategoryTaxonCount($dbh2, $category);
    for my $key ( keys %dist ) {
        my $cnt = $dist{$key};
        print "<p>$key: $cnt</p>\n";
    }

    printStatusLine( "Loaded.", 2 );
    print end_form();
}

###########################################################################
# printCategoryTaxons_ImgGold
###########################################################################
sub printCategoryTaxons_ImgGold {
    
    my $category      = param("category");
    my $categoryValue = param("categoryValue");

    printStatusLine( "Loading ...", 1 );
    printMainForm();
    print "<h1>" . DataEntryUtil::getGoldAttrDisplayName($category) . "</h1>\n";

    require GenomeList;
    my @gids = GenomeList::getMetadataCategoryGids( $category, $categoryValue );
    
    if ( scalar(@gids) == 0 ) {
        printStatusLine( "Loaded.", 2 );
        print "<b>\n";
        print escHtml($categoryValue);
        print "</b>\n";
        if ( lc($categoryValue) eq "unknown" ) {
            print "<p>Genomes with no known metadata information.</p>\n";
        } else {
            print "<p>There are no genomes in this IMG database " 
                . "for the selected category value.</p>\n";
        }
        print end_form();
        return;
    }

    print "<p>\n";
    print "Genomes are shown under closest parent category.<br/><br/>\n";
    print domainLetterNoteParen() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";

    my $dbh                = dbLogin();
    my $oids_str = OracleUtil::getFuncIdsInClause( $dbh, @gids );    
    my ( $rclause, @bindList_ur ) = urClauseBind("tx.taxon_oid");
    my $imgClause = WebUtil::imgClause('tx');

    my $sql  = qq{
        select tx.taxon_oid, tx.taxon_display_name, tx.domain, tx.seq_status
        from taxon tx
        where tx.sequencing_gold_id in ($oids_str)
        $rclause
        $imgClause
        order by tx.taxon_display_name
    };
    #print "printCategoryTaxons_ImgGold() sql=$sql<br/>\n";

    my $cur = execSqlBind( $dbh, $sql, \@bindList_ur, $verbose );

    printFooterButtons();

    print "<p><b>\n";
    print escHtml($categoryValue);
    print "</b></p>\n";

    print "<p>\n";
    my $count = 0;
    for ( ; ; ) {
        my ( $taxon_oid, $taxon_display_name, $domain, $seq_status ) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );

        print nbsp(2);
        print "<input type='checkbox' name='taxon_filter_oid' value='$taxon_oid' />\n";
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";
        print alink( $url, $taxon_display_name );
        print nbsp(1);
        print "($domain)[$seq_status]";
        print "<br/>\n";
    }
    $cur->finish();
    print "</p>\n";

    if ( $count == 0 ) {
        print "<p>There are no genomes in this IMG database " 
            . "for the selected category value.</p>\n";
    }

    printFooterButtons() if $count > 10;
    printStatusLine( "Loaded. (count = $count)", 2 );
    print end_form();
}

############################################################################
# printFooterButtons - Show selection buttions.
############################################################################
sub printFooterButtons {
    print hiddenVar( "page",    "message" );
    print hiddenVar( "message", "Genome selection saved and enabled." );
    print submit(
                  -name    => 'setTaxonFilter',
                  -value   => 'Add Selected to Genome Cart',
                  -class   => 'meddefbutton',
                  -onClick => "return isGenomeSelected('');"
    );
    print nbsp(1);
    print "<input type='button' name='selectAll' value='Select All'  "
	. "onClick='selectAllTaxons(1)' class='smbutton' />";
    print nbsp(1);
    print "<input type='button' name='clearAll' value='Clear All'  "
	. "onClick='selectAllTaxons(0)' class='smbutton' />";
    print "<br/>\n";
}

############################################################################
# printPrivateGenomeUsers - Show list of users with their private genomes.
############################################################################
sub printPrivateGenomeUsers {

    print "<h1>Private Genome Users</h1>\n";
    printStatusLine( "Loading ...", 1 );
    my $dbh                 = dbLogin();
    my %masterUsers         = getMasterUsers($dbh);
    my @master_contact_oids = sort( keys(%masterUsers) );
    my $nMasterContactOids  = @master_contact_oids;
    if ( $nMasterContactOids > 1000 ) {
        webDie("printPrivateGenomeUsers: $nMasterContactOids, too many");
    }
    my $masterClause;
    my $x = join( ',', @master_contact_oids );
    $masterClause = "and c.contact_oid not in( $x )" if $x ne "";

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();

    my $tclause = "";
    if ( $super_user ne "Yes" ) {
        $tclause = "and c.contact_oid = ? ";
    }
    my $imgClause = WebUtil::imgClause('tx');
    my $sql       = qq{
       select c.username, c.name, tx.taxon_oid, tx.domain, tx.seq_status, 
          tx.taxon_display_name
       from contact c, contact_taxon_permissions ctp, taxon tx
       where c.contact_oid = ctp.contact_oid
       and ctp.taxon_permissions = tx.taxon_oid
       and tx.is_public = ? 
       $tclause
       $imgClause
       order by c.username, tx.taxon_display_name
    };

    #and( c.super_user is null or c.super_user = 'No' )

    my @bindList = ();
    push( @bindList, 'No' );
    if ( $super_user ne "Yes" ) {
        push( @bindList, "$contact_oid" );
    }
    my $cur = execSqlBind( $dbh, $sql, \@bindList, $verbose );

    print "<p>\n";
    print "Users and their access to private genomes is shown below.<br/>\n";
    print domainLetterNoteParen() . "<br/>\n";
    print completionLetterNoteParen() . "<br/>\n";
    print "</p>\n";
    print "<p>\n";
    my $old_username;
    my $count = 0;
    my %taxonOids;

    for ( ; ; ) {
        my ( $username, $name, $taxon_oid, $domain, $seq_status, $taxon_display_name ) = $cur->fetchrow();
        last if !$taxon_oid;
        $count++;
        $taxonOids{$taxon_oid} = 1;
        $domain     = substr( $domain,     0, 1 );
        $seq_status = substr( $seq_status, 0, 1 );
        my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail";
        $url .= "&taxon_oid=$taxon_oid";

        if ( $username ne $old_username ) {
            print "<br/>" if $old_username ne "";
            print "<b>" . escHtml($username) . "</b>";
            print " - " . escHtml($name);
            print "<br/>\n";
        }
        print nbsp(2);
        print alink( $url, $taxon_display_name );
        print "[$domain]";
        print "($seq_status)";
        print "<br/>\n";
        $old_username = $username;
    }
    $cur->finish();
    print "</p>\n";

    ##$dbh->disconnect();
    my $nTaxons = keys(%taxonOids);
    printStatusLine( "$nTaxons genome(s) retrieved.", 2 );
}

############################################################################
# getMasterUsers - Discern master users who have access to all
#   private genomes.
############################################################################
sub getMasterUsers {
    my ($dbh) = @_;

    my %users;
    my $sql = qq{
        select contact_oid
        from contact
        where super_user = ? 
    };
    my $cur = execSql( $dbh, $sql, $verbose, 'Yes' );
    for ( ; ; ) {
        my ($contact_oid) = $cur->fetchrow();
        last if !$contact_oid;
        $users{$contact_oid} = $contact_oid;
    }
    $cur->finish();
    return %users;
}

############################################################################
# printPrivateGenomeList - Print private genome list.
############################################################################
sub printPrivateGenomeList {
    my $sortSpec = param("sortSpec");

    my $contact_oid = getContactOid();
    my $super_user  = getSuperUser();
    my $imgClause   = WebUtil::imgClause('tx');

    my $clause;
    if ( $super_user ne "Yes" ) {
        $clause = "and ctp.contact_oid = '$contact_oid'";
    }
    my $sql1 = qq{
select tx.taxon_oid
from taxon tx, contact_taxon_permissions ctp
where tx.taxon_oid = ctp.taxon_permissions
and tx.is_public = 'No'
$clause
$imgClause
        };

    require GenomeList;
    GenomeList::printGenomesViaSql( '', $sql1, '<h1>Private Genomes</h1>' );
    return;
}

############################################################################
# privSortLink - Private genome sort linke.
############################################################################
sub privSortLink {
    my ( $name, $sortSpec ) = @_;

    my $s   = "<th class='img'>";
    my $url = "$section_cgi&page=privateGenomeList";
    $url .= "&sortSpec=$sortSpec";
    $s   .= alink( $url, $name );
    $s   .= "</th>\n";
    return $s;
}

1;
