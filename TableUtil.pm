############################################################################
# Utility subroutines for tables e.g. phylogenetic table
# $Id: TableUtil.pm 30097 2014-02-14 20:56:28Z klchu $
############################################################################
package TableUtil;
my $section = "TableUtil"; 

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(
    getSelectedTaxons
);

use strict;
use CGI qw( :standard );

use Data::Dumper;
use DBI;
use WebConfig; 
use WebUtil; 

$| = 1;

my $env = getEnv();
my $main_cgi = $env->{ main_cgi };
my $verbose = $env->{ verbose };
my $base_url = $env->{ base_url }; 
my $YUI = $env->{ yui_dir_28 }; 
my $in_file = $env->{ in_file }; 

my $SHOW_ALL = 0;
my $HIDE_METAG = 1;
my $ONLY_METAG = 2;

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    if ($page eq "allGenomes") {
	my $merfs = param("merfs");
	my $hidemetag = param("hidemetag");
        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq { 
            <response> 
                <div id='allGenomes$hidemetag'><![CDATA[ 
        }; 
        writeDiv(2, "", $merfs, $hidemetag);
        print qq { 
            ]]></div>
            <name></name>
            </response> 
        }; 
    }
}

sub printGenomeTableTitle {
    print "<h2>Genome List</h2>";
    print "<p>\n";
    print domainLetterNoteParen() . "<br/>\n";
    print completionLetterNoteParen();
    print "</p>\n";
}

############################################################################
# printGenomeTable - prints the actual html table based on the phylogenetic
#     tree records retrieved for selected genomes
############################################################################
sub printGenomeTable {
    my ($mywrite, $restrict_selection, $include_mer_fs, $hide_metag) = @_;
    $mywrite = 1 if ($mywrite eq "");
    $hide_metag = $SHOW_ALL if ($hide_metag eq "");

    print "<script src='$base_url/chart.js'></script>\n";
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

    print qq{ 
        <script language='JavaScript' type='text/javascript'>
        YAHOO.util.Event.onDOMReady(function() {
            try {
            document.getElementById('taxonClause0').value = 'selected';
            } catch(e) {}
            try {
            document.getElementById('taxonClause1').value = 'selected';
            } catch(e) {}
            try {
            document.getElementById('taxonClause2').value = 'selected';
            } catch(e) {}
        });

        function showAllGenomes(show, url, metag) {
            if (show == 'yes') {
                var startId = "startElement1"+metag;
                clearAllIds(startId, 1);
                if (document.getElementById
                    ('allGenomes'+metag).innerHTML == "") {
                    showDiv('allGenomes'+metag, url, metag);
                } else {
                    document.getElementById
                      ('myGenomes'+metag).style.display = 'none';
                    document.getElementById
                      ('allGenomes'+metag).style.display = 'block';
                    document.getElementById('taxonClause'+metag).value = 'all';
                }
            } else {
            var startId = "startElement2"+metag;
            clearAllIds(startId, 1); 
            document.getElementById('myGenomes'+metag).style.display = 'block';
            document.getElementById('allGenomes'+metag).style.display = 'none';
            document.getElementById('taxonClause'+metag).value = 'selected';
            }
        }
 
        function handleSuccess(req) {
            try { 
                id = req.argument[0];
                metag = req.argument[1];

                response = req.responseXML.documentElement;
                var html = response.getElementsByTagName
                    ('div')[0].firstChild.data;
                document.getElementById(id).innerHTML = html; 
                document.getElementById
                    ('myGenomes'+metag).style.display = 'none';
                document.getElementById
                    ('allGenomes'+metag).style.display = 'block';
                document.getElementById('taxonClause'+metag).value = 'all';
            } catch(e) { 
            } 
            YAHOO.example.container.wait.hide(); 
        }

        function showDiv(id, url, metag) {
            YAHOO.namespace("example.container");
            if (!YAHOO.example.container.wait) { 
                initializeWaitPanel(); 
            } 
 
            var callback = {
              success: handleSuccess,
              failure: function(req) { 
                  YAHOO.example.container.wait.hide();
              },
              argument: [id, metag]
            };

            if (url != null && url != "") { 
                YAHOO.example.container.wait.show(); 
                var request = YAHOO.util.Connect.asyncRequest
                    ('GET', url, callback);
            } 
        } 
        </script> 
    };

    printGroupSelectionScript(2);
    print hiddenVar("taxonClause$hide_metag", "selected");

    print "<div id='myGenomes$hide_metag' style='display: block;'>";
    writeDiv($mywrite, $restrict_selection, $include_mer_fs, $hide_metag);
    print "</div>\n";
    print "<div id='allGenomes$hide_metag' style='display: none;'>"; 
    print "</div>";
}

############################################################################
# writeDiv - writes out the table html for either the selected genomes
#            or for all genomes
############################################################################
sub writeDiv { 
    my ($which, $restrict_selection, $include_mer_fs, $hide_metag) = @_;
    my $url = "xml.cgi?section=$section&page=allGenomes"
	    . "&merfs=$include_mer_fs&hidemetag=$hide_metag";

    my $dbh = dbLogin();

    my $taxonClause = txsClause("tx", $dbh);
    my $startElement;

    if ($which == 1) {
        $startElement = "startElement1".$hide_metag;
        my $func = "clearAllIds('$startElement', 1)";
        my $func2 = "selectAllIds('$startElement', 0)";
 
        if ($taxonClause ne "") { 
	    if (!$restrict_selection) {
		print "<input id='selAllButton' type='button' "
		    . "name='selectAll' value='Select All' " 
		    . "onClick=\"$func2\" class='smbutton' />\n"; 
		print nbsp( 1 ); 
	    }
        } 
        print "<input id='resetButton' type='button' "
	    . "name='clearSelections' value='Clear All' "
            . "onClick=\"$func\" class='smbutton' />\n";

        if ($taxonClause ne "") {
            print nbsp(1);
            print "<input id='showAllButton' type='button' "
		. "class='medbutton' name='genomes' "
                . "value='Show All Genomes' "
                . "onclick='showAllGenomes(\"yes\",\"$url\",$hide_metag)' />";
        }

    } elsif ($which == 2) {     
        if ($taxonClause eq "") {
	    #$dbh->disconnect();
	    return;
        }
        $startElement = "startElement2".$hide_metag;
        my $func = "clearAllIds('$startElement', 1)";

        print "<input id='resetButton' type='button' "
	    . "name='clearSelections' value='Clear All' "
            . "onClick=\"$func\" class='smbutton' />\n";

        if ($taxonClause ne "") {
            print nbsp(1); 
            print "<input  id='showSelButton' type='button' "
		. "class='medbutton' name='genomes'"
                . " value='Show Selected Genomes'"
                . " onclick='showAllGenomes(\"no\",\"$url\",$hide_metag)' />";
        }
        $taxonClause = "";

    } elsif ($which == 3) {
        # for metag tools - ken
	$startElement = "startElement1".$hide_metag;
        my $func = "clearAllIds('$startElement', 1)";

        print "<input id='resetButton' type='button' "
	    . "name='clearSelections' value='Clear All' "
            . "onClick=\"$func\" class='smbutton' />\n";
        $taxonClause .= " and tx.genome_type = 'metagenome' ";      
    }

    # fill in the javascript event actions func calls
    my @recs = fillLineRange(getPhyloTree
			     ($taxonClause, $dbh, 
			      $include_mer_fs, $hide_metag));
    #$dbh->disconnect();

    # table column headers
    print "<table id='$startElement' class='img' border='1' >\n";
    print "<th class='img'>Select</th>\n";
    print "<th class='img'>Ignore</th>\n";
    print "<th class='img'>Taxon Name</th>\n";

    my $count = 0;
    my $taxon_cnt = 0;
    for my $r (@recs) {
        $count++;

        my ($genome, $type, $type_value, $lineRange, $domain, undef) =
            split(/\t/, $r);

        if ($type eq "domain" || $type eq "phylum" || $type eq "genus") {
	    next if ($hide_metag == $ONLY_METAG && $genome ne 'metagenome');
            my ($line1, $line2) = split(/:/, $lineRange);

            print "<tr class='highlight'>\n";

            my $func = 
                "selectGroupProfile('$startElement',$line1,$line2,0,'find')";
            print "<td class='img' >\n";
            print "  <input type='radio' onClick=\"$func\" "
                . "name='groupProfile.$count$which' value='find' />\n";
            print "</td>\n";

            my $func = 
                "selectGroupProfile('$startElement',$line1,$line2,1,'ignore')";
            print "<td class='img' >\n";
            print "  <input type='radio' onClick=\"$func\" "
                . "name='groupProfile.$count$which' value='ignore' />\n";
            print "</td>\n";

            my $sp;
            $sp = nbsp(2) if $type eq "phylum";
            $sp = nbsp(4) if $type eq "genus";

            print "<td class='img' >\n";
            print $sp;
            my $incr = '+0';
            $incr = "+1" if $type eq "domain";
            $incr = "+1" if $type eq "phylum";
            print "<font size='$incr'>\n";
            print "<b>\n";
            print escHtml($type_value);
            print "</b>\n";
            print "</font>\n";
            print "</td>\n";

            print "</tr>\n";

        } elsif ($type eq "taxon_display_name" && $genome eq 'metagenome') {
	    next if ($hide_metag == $HIDE_METAG);
            my ($genome_type,
		$type,      $type_value,         $lineRange,
                $domain,    $phylum,             $genus, 
                $taxon_oid, $taxon_display_name, $seq_status, 
		$mer_fs) = split( /\t/, $r ); 

            print "<tr class='img' >\n"; 

            print "<td class='img' >\n";
            print "<input type='radio' onClick=\""
                . "checkFindCount(mainForm.elements['profile$taxon_oid'])\""
                . " name='profile$taxon_oid$which' "
                . "value='find' />\n";
            print "</td>\n"; 

            print "<td class='img' >\n"; 
            print "<input type='radio' name='profile$taxon_oid$which' "
                . "value='ignore' "
                . "   checked  />\n";
            print "</td>\n";

            print "<td class='img' >\n"; 
            print nbsp(8); 
            my $url = "$main_cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$taxon_oid";
	    if ($mer_fs eq 'Yes') {
		$url = "$main_cgi?section=MetaDetail"
		     . "&page=metaDetail&taxon_oid=$taxon_oid";
	    }
            print "<b>[ "; 
            print alink( $url, $taxon_display_name );
            print " ]</b>"; 
            print "</td>\n"; 
            print "</tr>\n";

        } elsif ($type eq "taxon_display_name" && $genome ne 'metagenome') {
	    next if ($hide_metag == $ONLY_METAG);
            my ($genome_type,
		$type,      $type_value,         $lineRange,
                $domain,    $phylum,             $genus,
                $taxon_oid, $taxon_display_name, $seq_status, 
		$mer_fs) = split(/\t/, $r);

            print "<tr class='img' >\n";
            print "<td class='img' >\n";
            print "<input type='radio' onClick=\""
                . "checkFindCount(mainForm.elements['profile$taxon_oid'])\""
                . " name='profile$taxon_oid$which' "
                . "value='find' />\n";
            print "</td>\n";

            print "<td class='img' >\n";
            print "  <input type='radio' name='profile$taxon_oid$which' "
                . "value='ignore' "
                . "  checked />\n";
            print "</td>\n";

            print "<td class='img' >\n";
            print nbsp(8);
            my $d = substr($domain, 0 , 1);
            my $c = substr($seq_status, 0 , 1);
            my $url = "$main_cgi?section=TaxonDetail&page=taxonDetail"
                    . "&taxon_oid=$taxon_oid";
	    if ($mer_fs eq 'Yes') {
		$url = "$main_cgi?section=MetaDetail"
		     . "&page=metaDetail&taxon_oid=$taxon_oid";
	    }
            print alink($url, "$taxon_display_name");
            print nbsp(1) . " ($d)[$c]";
            print "</td>\n";
            print "</tr>\n";
            $taxon_cnt++;
        }
    }
    print "</table>\n";
}

############################################################################
# getPhyloTree - retrieves the array of records needed to construct the
#    phylogenetic tree for genome selection based on selected genomes
############################################################################
sub getPhyloTree {
    my ($taxonClause, $dbh, $include_mer_fs, $hide_metag) = @_;

    my $rclause = urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");

    my $hideViruses = getSessionParam("hideViruses");
    $hideViruses = "Yes" if $hideViruses eq "";
    my $virusClause = "and tx.domain not like 'Vir%'"
        if $hideViruses eq "Yes";
 
    my $hidePlasmids = getSessionParam("hidePlasmids"); 
    $hidePlasmids = "Yes" if $hidePlasmids eq ""; 
    my $plasmidClause = "and tx.domain not like 'Plasmid%'" 
        if $hidePlasmids eq "Yes";

    my $selectClause = 
	"select tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, " .
	"tx.genus, tx.species, tx.strain, tx.taxon_display_name, " .
	"tx.taxon_oid, tx.seq_status, tx.genome_type, tx.in_file ";

    my $gFragmentClause = '';
    my $hideGFragment = getSessionParam("hideGFragment");
    $hideGFragment = "Yes" if $hideGFragment eq "";
    if ($hideGFragment eq "Yes"){
        $gFragmentClause = "and tx.domain not like 'GFragment%' ";
    }

    my $sql = qq{
	$selectClause
        from taxon tx
        where 1 = 1
        $taxonClause
        $rclause
        $imgClause
        $virusClause
        $plasmidClause
        $gFragmentClause
        order by
        tx.domain, tx.phylum, tx.ir_class, tx.ir_order, tx.family, 
        tx.genus, tx.species, tx.strain, tx.taxon_display_name
    };
    #print "TableUtil::getPhyloTree() sql: $sql<br/>\n";

    my $cur = execSql($dbh, $sql, $verbose);

    # where the query data is stored
    my @recs;
    my $old_domain;
    my $old_phylum;
    my $old_genus;
    my $old_taxon_oid;

    # run query and store the data in @recs
    # for each rec, the values are tab delimited
    
    for ( ;; ) {
        my ($domain,             $phylum,    $ir_class,   $ir_order,
            $family,             $genus,     $species,    $strain,
            $taxon_display_name, $taxon_oid, $seq_status, $genome_type,
	    $mer_fs) = $cur->fetchrow();
        last if !$domain;

	next if (!$include_mer_fs && $mer_fs eq 'Yes');
	next if ($hide_metag == 1 && $genome_type eq 'metagenome');
	next if ($hide_metag == 2 && $genome_type ne 'metagenome');

        if ($old_domain ne $domain) {
	    my $rec = "$genome_type\t";
            $rec .= "domain\t";
            $rec .= "$domain\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            push(@recs, $rec);
        }
        if ($old_phylum ne $phylum) {
	    my $rec = "$genome_type\t";
            $rec .= "phylum\t";
            $rec .= "$phylum\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum";
            push(@recs, $rec);
        }
        if ($old_genus ne $genus) {
	    my $rec = "$genome_type\t";
            $rec .= "genus\t";
            $rec .= "$genus\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus";
            push(@recs, $rec);
        }
        if ($old_taxon_oid ne $taxon_oid) {
	    my $rec = "$genome_type\t";
            $rec .= "taxon_display_name\t";
            $rec .= "$taxon_display_name\t";
            $rec .= "__lineRange__\t";
            $rec .= "$domain\t";
            $rec .= "$phylum\t";
            $rec .= "$genus\t";
            $rec .= "$taxon_oid\t";

	    if ($mer_fs eq 'Yes') {
		$rec .= "$taxon_display_name (MER-FS)\t";
	    } else {
		$rec .= "$taxon_display_name\t";
	    }
            $rec .= "$seq_status\t";
            $rec .= "$mer_fs\t";
            push(@recs, $rec);
        }
        $old_domain    = $domain;
        $old_phylum    = $phylum;
        $old_genus     = $genus;
        $old_taxon_oid = $taxon_oid;
    }

    $cur->finish();
    return \@recs;
}

############################################################################
# getSelectedTaxons - returns the selected genomes
#      $use_other_genomes - whether to use selections from "all taxons"
############################################################################
sub getSelectedTaxons {
    my ($use_other_genomes, $hide_metag) = @_;
    $hide_metag = $SHOW_ALL if ($hide_metag eq "");

    my $metagClause;     # when using tree viewer - ken
    my $fromviewer = param("fromviewer");
    if ($fromviewer eq "TreeFileMgr") {
        my @toids = param("taxon_filter_oid");
        return \@toids;
    } elsif ($fromviewer eq "MetagPhyloDist") {
        $metagClause = " and tx.genome_type = 'metagenome' ";
    }
    
    my @all_taxon_oids;
    my $dbh = dbLogin();
    my $taxonClause = "";     
    if (!$use_other_genomes ||      # for backwards compatibility
	$use_other_genomes eq "") { # use only selections from genome cart
	$taxonClause = txsClause("tx", $dbh);
    }
    my $rclause = urClause("tx"); 
    my $imgClause = WebUtil::imgClause("tx");

    my $x = 1;
    my $taxonVal = param("taxonClause".$hide_metag);
    if ($taxonVal eq "all") {
        $taxonClause = "";
        $x = 2;
    }
    if ($fromviewer eq "MetagPhyloDist") {
	$x = 3;
    }
    #print "<br/>ANNA: [$taxonVal] $x metag=$hide_metag";
    my $sql = qq{
	select distinct tx.taxon_oid
        from taxon tx
	where 1 = 1
	$taxonClause
	$rclause
        $imgClause
	$metagClause
    };
    my $cur = execSql($dbh, $sql, $verbose);
    for ( ;; ) {
        my ($taxon_oid) = $cur->fetchrow();
        last if !$taxon_oid;
        push(@all_taxon_oids, $taxon_oid);
    }

    # Read form profile ids, which radio buttons selected
    # number unique taxons user has selected
    my @find_toi;
    for my $taxon_oid (@all_taxon_oids) {
        my $profileVal = param("profile$taxon_oid$x");
        next if $profileVal eq "0" || $profileVal eq "";

        if ($profileVal eq "find") {
            push(@find_toi, "$taxon_oid");
        }
    }

    #$dbh->disconnect();
    return \@find_toi;
}

############################################################################
# fillLineRange - Fill __lineRange__ paramater in record for javascript.
############################################################################
sub fillLineRange {
    my ($recs_ref) = @_;
    my @recs2;
    my $nRecs = @$recs_ref;

    for (my $i = 0 ; $i < $nRecs ; $i++) {
        my $r = $recs_ref->[$i];
        my ($genome_type, $type, $type_val, $lineRange, 
            $domain, $phylum, $genus, 
            $taxon_oid, $taxon_display_name) = split(/\t/, $r);

        if ($type eq "domain" || $type eq "phylum" || $type eq "genus") {
            my $j = $i + 1;
            for (; $j < $nRecs ; $j++) {
                my $r2 = $recs_ref->[$j];
                my ($genome_type, $type2, $type_val2, $lineRange2,
		    $domain, $phylum, $genus,
		    $taxon_oid, $taxon_display_name) = split(/\t/, $r2);
                last if ($domain ne $type_val) && $type eq "domain";
                last if ($phylum ne $type_val) && $type eq "phylum";
                last if ($genus  ne $type_val) && $type eq "genus";
            }
            $r =~ s/__lineRange__/$i:$j/;
        }

        if ($type eq "taxon_display_name" && $genome_type eq "metagenome") {
            my $j = $i + 1;
            for (; $j < $nRecs ; $j++) {
                my $r2 = $recs_ref->[$j];
                my ($genome_type, $type2, $type_val2, $lineRange2, 
		    $domain2, $phylum2, $genus2, $taxon_oid2, 
		    $taxon_display_name2)
                    = split(/\t/, $r2);
                last if ($taxon_oid ne $taxon_oid2);
            }
            $r =~ s/__lineRange__/$i:$j/;
        }

        push(@recs2, $r);
    }

    return @recs2;
}

############################################################################
# printGroupSelectionScript - the script that handles selection of genomes
# in the phylogenetic table (id of that table is set to e.g. 'startElement' 
#     for ease of retrieving the relevant radio button elements)
############################################################################
sub printGroupSelectionScript {
    my ($numOfCols) = @_; 
    my $oraclemax = WebUtil::getORACLEMAX();

    print qq{
        <script language='JavaScript' type='text/javascript'>
        var numOfCols = $numOfCols;
        var maxColl = $oraclemax;
        var maxFind;

        function selectGroupProfile(startId, begin, end, offset, type) {
            var startElement = document.getElementById(startId);
            var els = startElement.getElementsByTagName('input');

            var idx1 = begin * numOfCols;
            var idx2 = end * numOfCols;
            for (var i = idx1; i < els.length && i < idx2; i++) {
                var e = els[i];
                if (e.type == "radio" && i % numOfCols == offset) {
                    e.checked = true;
                }
            }

            if (type == 'find' && !checkFindCount(startId, null)) {
                selectGroupProfile
                    (startId, begin, end, (numOfCols - 1), 'ignore');
            }
        }

        function selectAllIds(startId, offset) {
            var startElement = document.getElementById(startId);
            var els = startElement.getElementsByTagName('input'); 
 
            for (var i = offset; i < els.length; i = i + numOfCols) { 
                var e = els[i]; 
                var name = e.name; 
 
                if (e.type == "radio" && i % numOfCols == offset
                    && (name.charAt(0) == 'p')) {
                    e.checked = true;
                }
            } 
        } 
 
        function clearAllIds(startId, offset) {
            var startElement = document.getElementById(startId);
            var els = startElement.getElementsByTagName('input');

            for (var i = offset; i < els.length; i = i + numOfCols) {
                var e = els[i]; 
                var name = e.name;

                if (e.type == "radio" && i % numOfCols == offset) {
                    e.checked = true;
                }
            }
        }       

        function checkFindCount(startId, obj) {
            if (startId == undefined) return true;
            var startElement = document.getElementById(startId);
            var els = startElement.getElementsByTagName('input');

            var count = 0;
            for (var i = 0; i < els.length; i = i + numOfCols) {
                var e = els[i];
                var name = e.name;

                if (e.type == "radio" && e.checked == true &&
                    name.indexOf("profile") > -1) {
                    // alert("radio button is checked: " + name);
                    count++;
                }
            }
            return true;
        }
        </script>
    };
}


1;
