############################################################################
#  Append Genome List Filter into other HTML.
# $Id: GenomeListFilter.pm 29739 2014-01-07 19:11:08Z klchu $
############################################################################
package GenomeListFilter;
my $section = "GenomeListFilter"; 

require Exporter;
@ISA    = qw( Exporter );
@EXPORT = qw(
);

use strict;
use CGI qw( :standard );
use DBI;
use Time::localtime;
use WebConfig;
use WebUtil;
use OracleUtil;
use MerFsUtil;
use TreeViewFrame;

my $env                   = getEnv();
my $main_cgi              = $env->{main_cgi};
my $verbose               = $env->{verbose};
my $base_dir              = $env->{base_dir};
my $base_url              = $env->{base_url};
my $img_internal          = $env->{img_internal};
my $tmp_dir               = $env->{tmp_dir};
my $web_data_dir          = $env->{web_data_dir};
my $YUI                   = $env->{yui_dir_28}; 
my $include_metagenomes   = $env->{include_metagenomes};
my $img_er                = $env->{img_er};
my $env_blast_dbs         = $env->{env_blast_dbs};
my $snp_blast_data_dir    = $env->{snp_blast_data_dir};
my $taxon_reads_fna_dir   = $env->{taxon_reads_fna_dir};
my $in_file               = $env->{in_file};
my $user_restricted_site = $env->{user_restricted_site};

my $tSplitSym = ":::";

sub dispatch {
    my $page = param("page");
    my $isSingleSelect = param("isSingleSelect");
    my $phyloType = param("phyloType");
    my $include_mer_fs = param("include_mer_fs");
    my $myBinAllowed = param("myBinAllowed");
    my $hideMetag = param("hideMetag");
    my $hideSingleCell = param("hideSingleCell");
    my $dbh = dbLogin();
    if ($page eq "allGenomes") {
        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq { 
            <response> 
                <div id='allGenomes'><![CDATA[ 
        };
        writeDiv($dbh, 2, $isSingleSelect, $phyloType, 
          $include_mer_fs, $myBinAllowed, $hideMetag, $hideSingleCell);
        print qq { 
            ]]></div>
            <name></name>
            </response>
        }; 
    }
    elsif ($page eq "myGenomes") {
        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq { 
            <response> 
                <div id='myGenomes'><![CDATA[ 
        }; 
        writeDiv($dbh, 1, $isSingleSelect, $phyloType, 
          $include_mer_fs, $myBinAllowed, $hideMetag, $hideSingleCell);
        print qq { 
            ]]></div>
            <name></name>
            </response>
        }; 
    }
    #$dbh->disconnect();
}

############################################################################
# appendGenomeListFilter - print basic genome selection form.
#   Read from template file and replace some template components.
############################################################################
sub appendGenomeListFilter {
    my ($dbh, $isSingleSelect, $phyloType, 
    $selectName, $hasYuiTable, $hasTreeView, 
	$include_mer_fs, $myBinAllowed, $hideMetag, $hideSingleCell) = @_;
    #print("GenomeListFilter::appendGenomeListFilter() hideSingleCell: $hideSingleCell<br/>\n");
	
    $phyloType = 0 if ($phyloType eq ''); #0 default
    $phyloType = 1 if ($phyloType eq 'Yes'); #1 forPhyloBin, #2 blast
    $include_metagenomes = 0 if $hideMetag;

    my $anySelectInGenomeBrowser = 0;
    my $txsClause = WebUtil::txsClause ("tx", $dbh);
    $anySelectInGenomeBrowser = 1 if ($txsClause ne '');

    my $templateFile = "$base_dir/genomeListFilter.html";
    my $rfh = newReadFileHandle( $templateFile, "appendGenomeListFilter" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        if ( $s =~ /__historyMarkup__/ ) {
            printHistoryMarkup(
              $isSingleSelect, $phyloType, $selectName, $hasYuiTable,
              $anySelectInGenomeBrowser);
            printTreeViewMarkup($hasTreeView);
        } elsif ( $s =~ /__genomeFilterAreaDivStart__/ ) {
            printGenomeFilterAreaDivStart();
        } elsif ( $s =~ /__taxonNote__/ ) {
            printTaxonNote();
        } elsif ( $s =~ /__seqstatus_list__/ ) {
            printSeqStatusFilterOptions();
        } elsif ( $s =~ /__domain_list__/ ) {
            printDomainFilterOptions($isSingleSelect);
        } elsif ( $s =~ /__taxonDisplayType__/ ) {
            printTaxonDisplayType();
        } elsif ( $s =~ /__taxonChoice__/ ) {
            printTaxonChoices(
              $dbh, $isSingleSelect, $phyloType, $include_mer_fs, 
              $myBinAllowed, $hideMetag, $hideSingleCell, 
              $anySelectInGenomeBrowser);
        } elsif ( $s =~ /__hiddenTreeButtons__/ ) {
            printHiddenTreeButtons();
        } elsif ( $s =~ /__taxonDisplayArea__/ ) {
            printTaxonDisplayArea();
        } else {
            print "$s\n";
        }
    }
    close $rfh;
}

sub printHistoryMarkup {
    my ($isSingleSelect, $phyloType, $selectName, $hasYuiTable,
        $anySelectInGenomeBrowser) = @_;

    if ($ENV{ HTTP_USER_AGENT } =~ /MSIE/) {
        print qq{
            <iframe id='genomeListFilter-history-iframe' src="$base_dir\/blank.html"><\/iframe>
            <style type='text/css'>
                #genomeListFilter-history-iframe {
                  position: absolute;
                  top: 0;
                  left: 0;
                  width: 1px;
                  height: 1px;
                  visibility: hidden;
                }
            </style>
        }; 
    }
    else {
        print qq{
            <div id='genomeListFilter-history-iframe'><\/div>
        };     	
    }
    print qq{
        <input id="genomeListFilter-history-field" type="hidden">
    };      

    if ($hasYuiTable eq 'Yes') {
        print qq{
            <script type="text/javascript" src="$YUI/build/yahoo/yahoo-min.js"></script>
            <script type="text/javascript" src="$YUI/build/event/event-min.js"></script>
         }; 
        print qq{
            <script type='text/javascript'>
                var hasYuiTable = true;
            </script>
        };        
    }
    else {
        print qq{
            <link rel="stylesheet" type="text/css" href="$YUI/build/container/assets/skins/sam/container.css" />
            <script type="text/javascript" src="$YUI/build/yahoo-dom-event/yahoo-dom-event.js"></script> 
            <script type="text/javascript" src="$YUI/build/dragdrop/dragdrop-min.js"></script>
            <script type="text/javascript" src="$YUI/build/container/container-min.js"></script>
            <script type="text/javascript" src="$YUI/build/yahoo/yahoo-min.js"></script>
            <script type="text/javascript" src="$YUI/build/event/event-min.js"></script>
            <script type="text/javascript" src="$YUI/build/connection/connection-min.js"></script>
        };

        #there are interference if YUI table has history-min.js included already
        print qq{
            <!-- Browser History Manager source file -->
            <script type="text/javascript" src="$YUI/build/history/history-min.js"></script>
        };
    }

#    if ($phyloType == 2 && $anySelectInGenomeBrowser == 1) { #blast
#        print qq{
#            <script type='text/javascript'>
#                isAllState = true;
#            </script>
#        };
#    }

    print qq{
        <script type="text/javascript" src='$base_url/chart.js'></script>
        <script type='text/javascript' src='$base_url/genomeFilter.js'>
        </script>
    };

    if ($isSingleSelect eq 'Yes') {
	    print qq{
	        <script type='text/javascript'>
	            setSingleSelect();
	        </script>
	    };
    }

    if ($selectName ne '') {
        print qq{
            <script type='text/javascript'>
                setSelectName('$selectName');
            </script>
        };
    }
    elsif ($phyloType == 1) { #phyloBin
        print qq{
            <script type='text/javascript'>
                setSelectName('profileTaxonBinOid');
            </script>
        };    	
    }
}

sub printTreeViewMarkup {
    my ($hasTreeView) = @_;

    printTreeMarkup() if ($hasTreeView ne 'Yes');
    print qq{
        <script type='text/javascript'>
            setMultipleLevel();
        </script>
        <script type='text/javascript' src='$base_url/genomeFilterTree.js'>
        </script>
    };
}


   
sub printGenomeFilterAreaDivStart {
    print qq{
        <div id='genomeFilterArea' >
    };
}

sub printTaxonNote {
    print domainLetterNoteParen();
    print "<br/>\n";
    print completionLetterNoteParen();
    print "\n";
}

sub printSeqStatusFilterOptions {
    my $seq_status = param("seq_status");

    my $ck = "";
    $ck = "selected='selected'"
      if ( $seq_status eq "both" || $seq_status eq "" );

    print qq{
		<select id='seqstatus' name='seqstatus' style="width:270px;" >
		<option value='both'  $ck > All Finished, Permanent Draft and Draft </option>
    };

    my $ck = "";
    $ck = "selected='selected'" if ( $seq_status eq "Finished" );
    print qq{
		<option value='Finished'  $ck > Finished  </option>
    };

    my $ck = "";
    $ck = "selected='selected'" if ( $seq_status eq "Permanent Draft" );
    print qq{
        <option value='Permanent Draft'   $ck > Permanent Draft  </option>
    };

    my $ck = "";
    $ck = "selected='selected'" if ( $seq_status eq "Draft" );
    print qq{
		<option value='Draft'  $ck> Draft </option>
		</select>
    };
}

sub printDomainFilterOptions {
    my ($isSingleSelect) = @_;

    my $domain = param("domain");

    my $ck = "";
    $ck = "selected='selected'" if ( $domain eq "All" || $domain eq "" );
    print qq{
        <select id='domainfilter' name='domainfilter' style="width:100px;">
        <option value='All'  $ck>All </option>
    };

    my $ck = "";
    $ck = "selected='selected'" if ( $domain eq "Bacteria" );
    print qq{
        <option value='Bacteria'  $ck>Bacteria</option>
    };

    my $ck = "";
    $ck = "selected='selected'" if ( $domain eq "Archaea" );
    print qq{
        <option value='Archaea'  $ck>Archaea</option>
    };

    my $ck = "";
    $ck = "selected='selected'" if ( $domain eq "Eukaryota" );
    print qq{
        <option value='Eukaryota'  $ck>Eukarya</option>
    };

    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    if ( $hidePlasmids ne "Yes" ) {
        my $ck = "";
        $ck = "selected='selected'" if ( $domain eq "Plasmid" );
        print "<option value='Plasmid'  $ck>Plasmids</option>";
    }
    
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    if ( $hideViruses ne "Yes" ) {
        my $ck = "";
        $ck = "selected='selected'" if ( $domain eq "Vir" );
        print "<option value='Vir'   $ck>Viruses</option>";
    }

    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    if ( $hideGFragment ne "Yes" ) {
        my $ck = "";
        $ck = "selected='selected'" if ( $domain eq "GFragment" );
        print "<option value='GFragment'  $ck>GFragment</option>";
    }

    if ($include_metagenomes && $isSingleSelect ne "Yes") {
        my $ck = "";
        $ck = "selected='selected'" if ( $domain eq "Microbiome" );
        print "<option value='Microbiome'  $ck>Microbiome</option>";
    }

    print qq{
        </select>
    };    
}

sub printTaxonDisplayType {
    print qq{
        <input type='radio' id='displayType1' name='displayType' value='list' style='vertical-align:text-bottom;' checked='checked'/><b>List</b>
        <input type='radio' id='displayType2' name='displayType' value='tree' style='vertical-align:text-bottom;' /><b>Tree</b>
    };
}

sub printTaxonChoices {
    my ($dbh, $isSingleSelect, $phyloType, 
        $include_mer_fs, $myBinAllowed, $hideMetag, $hideSingleCell, 
        $anySelectInGenomeBrowser) = @_; 
        #print("GenomeListFilter::printTaxonChoices() hideSingleCell: $hideSingleCell<br/>\n");

#    if ($phyloType == 2 && $anySelectInGenomeBrowser == 1) { #blast
#	    print "<input type='hidden' id='taxonChoice' name='taxonChoice' value='All' />";
#	    print "<div id='myGenomes' style='display: none;'>";
#	    print "</div>\n";
#	    print "<div id='allGenomes' style='display: block;'>";
#	    writeDiv($dbh, 2, $isSingleSelect, $phyloType, 
#           $include_mer_fs, $myBinAllowed, $hideMetag, $hideSingleCell );
#	    print "</div>";
#    }
#    else {
	    print "<input type='hidden' id='taxonChoice' name='taxonChoice' value='Selected' />";
	    print "<div id='myGenomes' style='display: block;'>";
	    writeDiv($dbh, 1, $isSingleSelect, $phyloType, 
	       $include_mer_fs, $myBinAllowed, $hideMetag, $hideSingleCell);
	    print "</div>\n";
	    print "<div id='allGenomes' style='display: none;'>"; 
	    print "</div>";    	
#    }

    printStatusLine("Loaded.", 2);
}


sub writeDiv { 
    my ($dbh, $which, $isSingleSelect, $phyloType, 
        $include_mer_fs, $myBinAllowed, $hideMetag, $hideSingleCell) = @_;

    my $txsClause = WebUtil::txsClause("tx", $dbh);
    my ($rclause, @bindList_ur) = WebUtil::urClauseBind("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $singleCellClause = WebUtil::singleCellClause('tx', $hideSingleCell);
    #print("GenomeListFilter::writeDiv() hideSingleCell: $hideSingleCell<br/>\n");
    #print("GenomeListFilter::writeDiv() singleCellClause: $singleCellClause<br/>\n");
    
    if ($which == 1) {
        if ($txsClause ne "") {
            my $url = "xml.cgi?section=$section&page=allGenomes"
                    ."&isSingleSelect=$isSingleSelect&phyloType=$phyloType"
                    ."&include_mer_fs=$include_mer_fs&myBinAllowed=$myBinAllowed"
                    ."&hideMetag=$hideMetag&hideSingleCell=$hideSingleCell";
            print nbsp(1);
            print "<input type='button' class='medbutton' id='showAllGenomesButton' name='showAllGenomesButton'"
                . " value='Show All Genomes'"
                . " onclick='showAllGenomes(\"$url\")' />";

        	#print "<br/>\n";
        	#print "<input type='checkbox' name='only_cart_genomes' id='only_cart_genomes' />\n";
        	#print "Use all genomes from genome cart ";
        }
    } 
    elsif ($which == 2) {
        if ($txsClause eq "") {
            return;
        }
        if ($txsClause ne "") {
            my $url = "xml.cgi?section=$section&page=myGenomes"
                    ."&isSingleSelect=$isSingleSelect&phyloType=$phyloType"
                    ."&include_mer_fs=$include_mer_fs&myBinAllowed=$myBinAllowed"
                    ."&hideMetag=$hideMetag&hideSingleCell=$hideSingleCell";
            print nbsp(1); 
            print "<input type='button' class='medbutton' id='showSelectedGenomesButton' name='showSelectedGenomesButton'"
                . " value='Show Selected Genomes'"
                . " onclick='showSelectedGenomes(\"$url\")' />";
        }
        $txsClause = "";
    } 

    printTaxonOptionList($dbh, $isSingleSelect, $phyloType, $which, 
        $txsClause, $rclause, $imgClause, $singleCellClause, 
        \@bindList_ur, $include_mer_fs, $myBinAllowed);
}

############################################################################
# printTaxonOptionList - Print option list for taxons, mainly to
#   be inserted in the template HTML.  Fill in the template option.
############################################################################
sub printTaxonOptionList {
    my ($dbh, $isSingleSelect, $phyloType, $which, 
        $txsClause, $rclause, $imgClause, $singleCellClause, 
        $bindList_ur_ref, $include_mer_fs, $myBinAllowed) = @_;

    my @bindList = ();

    if (scalar(@$bindList_ur_ref) > 0) {
        push (@bindList, @$bindList_ur_ref);
    }

    my $virusClause = '';
    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    if ($hideViruses eq "Yes") {
        $virusClause = "and tx.domain not like ? ";
        push(@bindList, 'Vir%');
    }

    my $plasmidClause = '';
    my $hidePlasmids = getSessionParam("hidePlasmids");
    $hidePlasmids = "Yes" if $hidePlasmids eq "";
    if ($hidePlasmids eq "Yes"){
        $plasmidClause = "and tx.domain not like ? ";
        push(@bindList, 'Plasmid%');
    }

    my $gFragmentClause = '';
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    if ($hideGFragment eq "Yes"){
        $gFragmentClause = "and tx.domain not like ? ";
        push(@bindList, 'GFragment%');
    }

    my $microbiomeClause = '';
    if (!$include_metagenomes || $isSingleSelect eq "Yes") {
        $microbiomeClause = "and tx.domain not like ? ";
        push(@bindList, '%Microbiome');
    }

    my ($count, $value);
    if ($phyloType == 2) {
        ($count, $value) = getTaxonOptionListBlastValue(
        	 $dbh, $txsClause, $rclause, $imgClause, $singleCellClause, 
        	 $virusClause, $plasmidClause, $microbiomeClause, $gFragmentClause, 
        	 \@bindList, $include_mer_fs, $myBinAllowed);
    }
    else {
        ($count, $value) = getTaxonOptionListPhyloValue(
        	 $dbh, $txsClause, $rclause, $imgClause, $singleCellClause, 
        	 $virusClause, $plasmidClause, $microbiomeClause, $gFragmentClause, 
        	 \@bindList, $phyloType, $include_mer_fs, $myBinAllowed);
    }

    if($count == 0) {
        $value .= "<option value='-1'>";
        $value .= "No genomes match filter criteria";
        $value .= "</option>\n";
    }

    if ($which == 2) {
        print "<input type='hidden' id='allTaxons' name='allTaxons' value=\"$value\" />";
    }
    else {
        print "<input type='hidden' id='myTaxons' name='myTaxons' value=\"$value\" />";
    }
}

sub getTaxonOptionListPhyloValue {
    my ($dbh, $txsClause, $rclause, $imgClause, $singleCellClause, 
        $virusClause, $plasmidClause, $microbiomeClause, $gFragmentClause, 
        $bindList_ref, $phyloType, $include_mer_fs, $myBinAllowed) = @_;

    my %taxon_bins;
    if ($phyloType == 1 || $myBinAllowed == 1) {
        %taxon_bins = getTaxonBinMap($dbh, $phyloType, $myBinAllowed);    	
    }
 
    my $inFileClause = MerFsUtil::getInFileClause();

    my $sql = qq{
        select tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, tx.genus, tx.species, 
            tx.taxon_display_name, tx.seq_status, $inFileClause, tx.taxon_oid
        from taxon tx
        where 2 = 2
        $txsClause
        $rclause
        $imgClause
        $virusClause
        $plasmidClause
        $gFragmentClause
        $microbiomeClause
        $singleCellClause
        order by tx.domain, tx.taxon_display_name, tx.taxon_oid
    };
    #print("GenomeListFilter::getTaxonOptionListPhyloValue() sql: $sql<br/>\n");
    #print("GenomeListFilter::getTaxonOptionListPhyloValue() bindList_ref: @$bindList_ref<br/>\n");
    #webLog("GenomeListFilter::getTaxonOptionListPhyloValue() sql: $sql\n");

    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );

    my $count = 0;
    my $value = '';
    my $old_taxon_oid;
    my $title;
    for ( ; ; ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
            $taxon_display_name, $seq_status, $inFileVal, $taxon_oid) =
        $cur->fetchrow();
        last if !$taxon_oid;
        if ( $inFileVal eq 'Yes' ) {
        	if ($include_mer_fs) {
	            #webLog("getTaxonOptionListPhyloValue inFileVal: $inFileVal taxon_oid: $taxon_oid\n");
	            $taxon_display_name= MerFsUtil::getShortTaxonDisplayName($taxon_display_name);        		
        	}
        	else {
        		next;
        	}
        }
    	elsif ( length($taxon_display_name) > 120 ) {
    	    my $len = length($taxon_display_name);
    	    $taxon_display_name = substr($taxon_display_name, 0, 60) . " ... " .
    		substr($taxon_display_name, $len-60);
    	}

        $count++;
        
        my $d = substr( $domain,     0, 1 );
        my $c = substr( $seq_status, 0, 1 );

        if ($phyloType == 1) {
	        if( $old_taxon_oid ne $taxon_oid ) {
	            $title = $domain . $tSplitSym . $phylum . $tSplitSym . $ir_class
	            . $tSplitSym . $ir_order . $tSplitSym . $family . $tSplitSym
	            . $genus . $tSplitSym . $species;
	            $title = escapeQuote($title);
                $value .= "<option title='$title' value='t:$taxon_oid'>";
	            $value .= escHtml($taxon_display_name);
	            $value .= " ($d)[$c]";
	            $value .= "</option>\n";
	        }
	        
	        $value = printTaxonBinMap($phyloType, $value, $title, $d, $c, '', $taxon_oid, %taxon_bins);	
        }
        else {  #default type
            if( $old_taxon_oid ne $taxon_oid ) {
		        $title = $domain . $tSplitSym . $phylum . $tSplitSym . $ir_class
		        . $tSplitSym . $ir_order . $tSplitSym . $family . $tSplitSym
		        . $genus . $tSplitSym . $species;
		        $title = escapeQuote($title);
                $value .= "<option title='$title' value='$taxon_oid'>";
		        $value .= escHtml($taxon_display_name);
		        $value .= " ($d)[$c]";
		        $value .= "</option>\n";
            }        	

            $value = printTaxonBinMap($phyloType, $value, $title, $d, $c, '', $taxon_oid, %taxon_bins);
        }

        $old_taxon_oid = $taxon_oid;
    }
    $cur->finish();

    return ($count, $value);
}

sub getTaxonBinMap {
    my ($dbh, $phyloType, $myBinAllowed) = @_;

    my %taxon_bins; #array list of tab delimited line bin_oids
    if (!$phyloType && !$myBinAllowed) { #$phyloType=0 && $myBinAllowed=0
        return %taxon_bins;
    }
    if (!$include_metagenomes && !$img_er) { #database w does not have taxon column in bin_scaffolds
        return %taxon_bins;
    }
        
    my $sql = qq{
        select distinct b.bin_oid, b.display_name, b.description, bm.description, bs.taxon
        from bin b, bin_method bm, bin_scaffolds bs
        where b.bin_method = bm.bin_method_oid
        and b.bin_oid = bs.bin_oid
    };
    #webLog("getTaxonBinMap sql: $sql\n");
    my $cur = execSql( $dbh, $sql, $verbose );
            
    my %taxon_bins; #array list of tab delimited line bin_oids
    for ( ; ; ) {
        my ( $bin_oid, $display_name, $description, $bmDescription, $taxon ) =  $cur->fetchrow();
        last if !$bin_oid;
        if (($phyloType == 0 || $phyloType == 2) && $myBinAllowed) { #($phyloType=0 || $phyloType=2) && $myBinAllowed=1
            next if ($bmDescription ne 'My Bins');        	
        }
        if ($phyloType == 1 && !$myBinAllowed) { #$phyloType=1 && $myBinAllowed=0
            next if ($bmDescription eq 'My Bins');
        }
        #webLog("getTaxonBinMap: $bin_oid\t$display_name\t$description\t$bmDescription\n");
        if (exists $taxon_bins{$taxon}) {
            my $aref = $taxon_bins{$taxon};
            push(@$aref, "$bin_oid\t$display_name\t$description\t$bmDescription");
        } else {
            my @a = ("$bin_oid\t$display_name\t$description\t$bmDescription");
            $taxon_bins{$taxon} = \@a;
        }
    }
    $cur->finish();
    
    return %taxon_bins;
}

sub printTaxonBinMap {
    my ($phyloType, $value, $title, $d, $c, $selected_taxon_oid, $taxon_oid, %taxon_bins) = @_;

    if (exists $taxon_bins{$taxon_oid}) {
        my $aref = $taxon_bins{$taxon_oid};
        foreach my $line (@$aref) { 
            my($bin_oid, $bin_display_name, $bin_description, $bmDescription) = split(/\t/,$line);
            if( $bin_oid ne '') {
                #webLog("bin_oid: $bin_oid ($d)[$c]\n");
                if ($selected_taxon_oid ne "" && $selected_taxon_oid eq "bin_$bin_oid") {
                	if ($phyloType == 1) { #phyBin
                        $value .= "<option title='$title' value='b:$bin_oid' selected='selected'>";                     
                	}
                	else { #blast and default
                        $value .= "<option title='$title' value='bin_:$bin_oid' selected='selected'>";                      
                	}
                } else {
                    if ($phyloType == 1) { #phyBin
                        $value .= "<option title='$title' value='b:$bin_oid'>";
                    }
                    else { #blast and default
                        $value .= "<option title='$title' value='bin_:$bin_oid'>";
                    }
                }
                if ($bmDescription eq 'My Bins') {
                    $value .= "-- (My Bin) ";
                }
                else {
                    $value .= "-- (Bin) ";                          
                }
                $value .= escHtml( $bin_display_name );
                $value .= " ($d)[$c]";
                $value .= "</option>\n";                
            }
        }
    }           
    return $value;
}

sub getTaxonOptionListBlastValue {
    my ($dbh, $txsClause, $rclause, $imgClause, $singleCellClause, 
        $virusClause, $plasmidClause, $microbiomeClause,$gFragmentClause, 
        $bindList_ref, $include_mer_fs, $myBinAllowed) = @_;

    # select taxon for "Blast Genome" from genome detail page
    my $selected_taxon_oid = param("taxon_oid");

    my %taxon_bins = getTaxonBinMap($dbh, 0, $myBinAllowed); #PhyloBin not needed

    my $inFileClause = MerFsUtil::getInFileClause();

    my $envBlastDb = 0;
    $envBlastDb = 1 if ($include_metagenomes && defined($env_blast_dbs) && defined($snp_blast_data_dir));

    my $sql = qq{
        select tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, tx.genus, tx.species, 
            tx.taxon_display_name, tx.seq_status, $inFileClause, tx.taxon_oid, tx.jgi_species_code
        from taxon tx
        where 3 = 3
        $txsClause
        $rclause
        $imgClause
        $virusClause
        $plasmidClause
        $gFragmentClause
        $microbiomeClause
        $singleCellClause
        order by tx.domain, tx.taxon_display_name, tx.taxon_oid
    };

    my $cur = execSqlBind( $dbh, $sql, $bindList_ref, $verbose );

    my $count = 0;
    my $value = '';
    my $value_reads = '';
    for ( ; ; ) {
        my ( $domain, $phylum, $ir_class, $ir_order, $family, $genus, $species, 
            $taxon_display_name, $seq_status, $inFileVal, $taxon_oid, $jgi_species_code ) =
          $cur->fetchrow();
        last if !$taxon_oid;
        if ( $inFileVal eq 'Yes' ) {
            if ($include_mer_fs) {
                #webLog("getTaxonOptionListBlastValue inFileVal: $inFileVal taxon_oid: $taxon_oid\n");
                $taxon_display_name= MerFsUtil::getShortTaxonDisplayName($taxon_display_name);             
            }
            else {
                next;
            }
        }
    	elsif ( length($taxon_display_name) > 120 ) {
    	    my $len = length($taxon_display_name);
    	    $taxon_display_name = substr($taxon_display_name, 0, 60) . " ... " .
    		substr($taxon_display_name, $len-60);
    	}

        $count++;
        
        my $title_tail = $tSplitSym . $phylum . $tSplitSym . $ir_class
        . $tSplitSym . $ir_order . $tSplitSym . $family . $tSplitSym
        . $genus . $tSplitSym . $species;
        my $title = $domain . $title_tail;
        $title = escapeQuote($title);
        if ($selected_taxon_oid ne "" && $selected_taxon_oid eq $taxon_oid) {
            $value .= "<option title='$title' value='$taxon_oid' selected='selected'>";
        } else {        
            $value .= "<option title='$title' value='$taxon_oid'>";
        }
        $value .= escHtml($taxon_display_name);
        my $d = substr( $domain,     0, 1 );
        my $c = substr( $seq_status, 0, 1 );
        $value .= " ($d)[$c]";
        $value .= "</option>\n";
        
        if ($envBlastDb && $domain eq '*Microbiome') {
            my $title_reads = $domain.' (reads databases)' . $title_tail;
            my $snpDb1 = "$snp_blast_data_dir/$taxon_oid.nsq";
            my $snpDb2 = "$snp_blast_data_dir/$jgi_species_code.nsq";
            my $readsDb = "$taxon_reads_fna_dir/$taxon_oid.reads.fna.nsq";
            if( -e $snpDb1 ) {
               $value_reads .= "<option title='$title_reads' value='snp_$taxon_oid'>"
                  . escHtml($taxon_display_name)
                  . "  (DNA contigs and reads v2)</option>\n";
            }
            if( -e $snpDb2 ) {
               $value_reads .= "<option title='$title_reads' value='snp_$jgi_species_code'>"
                  . escHtml($taxon_display_name)
                  . "  (DNA contigs and reads v1)</option>\n";
            }
            if( -e $readsDb ) {
               $value_reads .= "<option title='$title_reads' value='readsDb_$taxon_oid'>"
                  . escHtml($taxon_display_name)
                  . "  (DNA: reads db)</option>\n";
            }
        }
        
        $value = printTaxonBinMap(2, $value, $title, $d, $c, $selected_taxon_oid, $taxon_oid, %taxon_bins);
        
    }
    $cur->finish();
    
    $value .= $value_reads;
    return ($count, $value);
}

sub printHiddenTreeButtons {
    print qq{
        <div id='treeButtons' style='display:none;'>
            <input type='button' class='khakibutton' id='expand' name='expand' value='Expand All'>
            <input type='button' class='khakibutton' id='collapse' name='collapse' value='Collapse All'>
        </div>
    };
}

sub printTaxonDisplayArea {
    # style="resize:horizontal; min-width: 100px; max-width: 1000px; width: 500px"
    print qq{
		<div id='taxonDisplayArea' style='overflow:auto;'>
		</div>
    };
}

1;
