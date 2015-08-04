############################################################################
# Methylomics.pm - displays DNA methylation data
# $Id: Methylomics.pm 33080 2015-03-31 06:17:01Z jinghuahuang $
############################################################################
package Methylomics;
my $section = "Methylomics";
my $study = "methylomics";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;
use GD;

$| = 1;

my $env         = getEnv();
my $cgi_dir     = $env->{ cgi_dir }; 
my $cgi_url     = $env->{ cgi_url }; 
my $cgi_tmp_dir = $env->{ cgi_tmp_dir }; 
my $tmp_url     = $env->{ tmp_url };
my $tmp_dir     = $env->{ tmp_dir };
my $main_cgi    = $env->{ main_cgi };
my $section_cgi = "$main_cgi?section=Methylomics";
my $verbose     = $env->{ verbose };
my $base_url    = $env->{ base_url };
my $R           = $env->{ r_bin };
my $nvl         = getNvl();

my $user_restricted_site  = $env->{ user_restricted_site };
my $batch_size = 40;
my $YUI = $env->{yui_dir_28};

my $preferences_url    = "$main_cgi?section=MyIMG&form=preferences";
my $maxGeneListResults = 10000;
if ( getSessionParam("maxGeneListResults") ne "" ) {
    $maxGeneListResults = getSessionParam("maxGeneListResults");
}

############################################################################
# dispatch - Dispatch loop.
############################################################################
sub dispatch {
    my $page = param("page");
    if ($page eq "methylomics" ||
	paramMatch("methylomics") ne "") {
        printOverview();
    }
    elsif ($page eq "experiments") {
	printExperiments();
    }
    elsif ($page eq "sampledata") {
	printDataForSample();
    }
    elsif ($page eq "motifsummary" ||
	   paramMatch("motifsummary") ne "") {
	printMotifSummary();
    }
    elsif ($page eq "motifStats" ||
	   paramMatch("motifStats") ne "") {
	printMethModificationChart();

    }
    elsif ($page eq "genomestudies" ||
	   paramMatch("genomestudies") ne "") {
	printStudiesForGenome();
    }
    elsif ($page eq "heatmap" ||
	paramMatch("heatmap") ne "") {
	#printHeatMapIndex();
	loadHeatMap();
    }
    elsif ($page eq "functionChanged" ||
	   paramMatch("functionChanged") ne "") {
	loadHeatMap();
    }
    elsif ($page eq "functionCartSelected" ||
	   paramMatch("functionCartSelected") ne "") {
	newHeatMap();
    }
}

############################################################################
# printOverview - prints all the methylomics experiments in IMG
############################################################################
sub printOverview {
    my $dbh = dbLogin(); 
    my $d = param("domain");
    my $domainClause = "";
    $domainClause = " and tx.domain = '$d' " if $d ne "";

    my $rclause = urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $expClause = expClause("e");
    my $expClause = ""; # for now
    my $sql = qq{ 
        select distinct m.motif_summ_oid, e.exp_oid 
        from meth_motif_summary m, meth_experiment e
        where e.exp_oid = m.experiment
        $expClause
    }; 
    my $cur = execSql( $dbh, $sql, $verbose ); 
    my %motifCntHash; 
    for ( ;; ) { 
        my ($motif, $exp) = $cur->fetchrow(); 
        last if !$exp; 
        $motifCntHash{ $exp }++; 
    } 

    my $sql = qq{ 
        select distinct 
               e.exp_oid,
               e.exp_name,
               $nvl(e.project_name, 'unknown'), 
               $nvl(e.chemistry_type, ''),
               tx.domain,
               tx.taxon_oid,
               tx.taxon_display_name,
               count(s.sample_oid)
          from meth_experiment e,
	       meth_sample s, taxon tx
	 where e.exp_oid = s.experiment
	   and s.IMG_taxon_oid = tx.taxon_oid
           $rclause
           $expClause
           $imgClause
           $domainClause
      group by e.exp_oid, e.exp_name, e.project_name,
               e.chemistry_type, tx.domain,
               tx.taxon_oid, tx.taxon_display_name
      order by e.exp_oid 
    }; 
    $cur = execSql( $dbh, $sql, $verbose ); 
    #and tx.is_public = 'Yes'

    print "<h1>Methylomics Experiments</h1>\n"; 
    print "<p>*Showing experiments and stats for $d only</p>" if $d ne "";

    setLinkTarget("_blank");
    printMainForm();

    use TabHTML;
    TabHTML::printTabAPILinks("allexperimentsTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("allexperimentsTab");
        </script>
    };

    my @tabIndex = ( "#allexptab1", "#allexptab2", 
		     "#allexptab4", "#allexptab5" );
    my @tabNames = ( "Experiments", "Stats by Chemistry", 
		     "Explore Motifs", "Stats by Function" );

    TabHTML::printTabDiv("allexperimentsTab", \@tabIndex, \@tabNames);
    print "<div id='allexptab1'>";

    my $it = new InnerTable(1, "allstudies$$", "allstudies", 1);
    #$it->hideAll();
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "ID", "asc", "right" );
    $it->addColSpec( "Experiment Name", "asc", "left" );
    #$it->addColSpec( "Project Name", "asc", "left" );
    $it->addColSpec( "Chemistry Type", "asc", "left" );
    $it->addColSpec( "Total Samples", "desc", "right" );
    $it->addColSpec( "Unique Motifs", "desc", "right" );
    $it->addColSpec( "Domain", "asc", "left" ) if $d eq "";
    $it->addColSpec( "Genome", "asc", "left" );

    my @exps;
    my %unique_txs;
    my %exp2name;
    for ( ;; ) { 
        my ($exp_oid, $experiment, $project, $chemistry, 
	    $domain, $taxon_oid, $taxon_name, $num_samples)
	    = $cur->fetchrow(); 
        last if !$exp_oid;

	push @exps, $exp_oid if $exp_oid > 3;
	print hiddenVar("exp_oid", $exp_oid) if $exp_oid > 3;
	$unique_txs{ $taxon_oid } = $taxon_name;

	my $url = "$section_cgi&page=experiments&exp_oid=$exp_oid";
	$exp2name{ $exp_oid } = $experiment." [".$taxon_name."]\t".$url;

        my $row; 
        my $row = $sd."<input type='checkbox' "
                . "name='exp_oid' value='$exp_oid' />\t";
        $row .= $exp_oid."\t"; 
        $row .= $experiment.$sd.alink($url, $experiment)."\t";
	#$row .= $project."\t";
	$row .= $chemistry."\t";
        $row .= $num_samples."\t";
	$row .= $motifCntHash{$exp_oid}."\t"; 

        my $dm = substr( $domain, 0, 1 );
	$row .= $dm."\t" if $d eq "";

	my $txurl = "$main_cgi?section=TaxonDetail"
	          . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_name.$sd.alink($txurl, $taxon_name)."\t";

        $it->addRow($row); 
    } 
    $cur->finish(); 

    print "<input type=button id='allstudies1' "
        . "name='selectAll' value='Select All' "
	. "onClick='selectAllByName(\"exp_oid\", 1)' "
        . "class='smbutton' />\n";
    print nbsp(1);
    print "<input type='button' id='allstudies0' "
        . "name='clearAll' value='Clear All' "
	. "onClick='selectAllByName(\"exp_oid\", 0)' "
        . "class='smbutton' />\n";
    $it->printOuterTable(1); 
    #$dbh->disconnect();
    print "</div>"; # end allexptab1

    print "<div id='allexptab2'>";
    #print "<h2>Most Frequently Modified Motifs</h2>";
    #print "<p style='width: 650px;'>";
    print "<p>";
    print "For each chemistry type, the present motif modifications and "
	. "the frequency of modification of each motif are listed below.";
    print "</p>";
    my $exp_str = join(",", @exps);

    my $sql = qq{
        select distinct
               e.chemistry_type, mm.motif_string,
               count(distinct mm.modification_oid)
          from meth_experiment e, meth_modification mm
         where e.exp_oid = mm.experiment
           and e.chemistry_type is not NULL
           and e.exp_oid in ($exp_str)
      group by e.chemistry_type, mm.motif_string
      order by e.chemistry_type, mm.motif_string
    };
    $cur = execSql( $dbh, $sql, $verbose );

    my %recs;
    my %motifHash;
    for ( ;; ) {
        my ($chemistry, $motif_str, $num_mods) = $cur->fetchrow();
	last if !$chemistry;

	my $r = $chemistry."\t".$motif_str."\t".$num_mods;
	if ( exists $recs{$chemistry} ) {
	    push @{$recs{$chemistry}}, $r;
	} else {
	    $recs{$chemistry} = [ $r ];
	}

	$motifHash{$motif_str} = 1;
    }
    $cur->finish();

    my @unique_motifs = sort keys %motifHash;
    print qq{
        <script language='JavaScript' type='text/javascript'>
        function showView(type) {
        if (type == 'graphical') {
            document.getElementById('tableView').style.display = 'none';
            document.getElementById('graphicalView').style.display = 'block';
        } else {
            document.getElementById('tableView').style.display = 'block';
            document.getElementById('graphicalView').style.display = 'none';
        }
        }
        </script>
    };

    print "<div id='tableView' style='display: block;'>";
    writeDiv("table", \%recs, \@unique_motifs);
    print "</div>";

    print "<div id='graphicalView' style='display: none;'>";
    writeDiv("graphical", \%recs, \@unique_motifs);
    print "</div>";

    print "</div>"; # end allexptab2

    print "<div id='allexptab4'>";
    my $sql = qq{
        select mms.sample, mms.motif_string, mms.fraction
          from meth_motif_summary mms
         where mms.experiment > 3
           and mms.experiment in ($exp_str)
      order by mms.sample, mms.motif_string
    };
    $cur = execSql( $dbh, $sql, $verbose );

    my %recs;
    my %motifHash;
    for ( ;; ) {
        my ($sample, $motif_str, $fraction) = $cur->fetchrow();
        last if !$sample;

        if ( exists $recs{$sample} ) {
            push @{$recs{$sample}}, $motif_str."\t".$fraction;
        } else {
            $recs{$sample} = [ $motif_str."\t".$fraction ];
        }

	$motifHash{$motif_str} = 1;
    }
    my @unique_motifs = sort keys %motifHash;
    my $nmotifs = scalar @unique_motifs;

    print "<p style='width: 650px;'>";
    print "Each motif can be observed in multiple genomes under "
	. "various experimental conditions. "
	. "Choose <font color='blue'><u>Stats by Motifs</u></font> "
        . "to see a chart displaying the fraction modified for each "
	. "selected motif. You may select all motifs for this function.";
    print "<br/>";
    print "Choose <font color='blue'><u>Motifs by Taxonomy</u></font> "
        . "to view the occurence of motifs in the context of the taxonomic "
	. "lineage of the genomes in which they are observed. You may select "
	. "up to 7 motifs for this function.";
    print "</p>";

    use RadialPhyloTree;
    RadialPhyloTree::printMainJS();
    print hiddenVar("meth_motifs", 1);
    print hiddenVar("domain", $d);
    printMainJS();

    print "<input type=button name='selectAllMtf' value='Select All' "
	. "onClick='selectAllIds()' class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAllMtf' value='Clear All' "
	. "onClick='clearAllIds()' class='smbutton' />\n";
    
    my $size = 30;
    $size = $nmotifs if $nmotifs < 30;
    print "<p>";
    print "<select id='motifbox' name='motifs_txm' size=$size " # all items
        . "style='min-height: 100px' multiple>\n";
    foreach my $mt (@unique_motifs) {
	print "<option name='motifs_txm' value='$mt' title='$mt' >\n";
	print escHtml($mt);
	print "</option>\n";
    }
    print "</select>\n";
    print "</p>";

    my $name = "_section_RadialPhyloTree_runTree";
    print submit(
	-name    => $name,
	-value   => "Generate Tree",
	-class   => "meddefbutton",
	-onClick => "return countMotifSelections(7);"
    );
    print nbsp(1);
    my $name = "_section_${section}_motifStats";
    print submit(
        -name    => $name,
        -value   => "Stats by Motifs",
        -class   => "meddefbutton",
        -onClick => "return countMotifSelections($nmotifs);"
    );
    print "</div>"; # end allexptab4

    print "<div id='allexptab5'>";
    print "<p>For each experiment, the modification count for a given "
	. "function is displayed in the heat map below.<br/>You may restrict "
	. "functions to those in the function cart.</p>";
    printHint
      ("Mouse over experiment or function labels to see names, ".
       "click to see details.<br/>".
       "Mouse over heat map to see: <font color='red'>normalized values ".
       "(original values) [fnid:expid]</font>.<br/>\n");

    my $stateFile  = "methexp_fns_heatMap$$";
    my $stateFile1 = "cog_".$stateFile;
    my $stateFile2 = "pfam_".$stateFile;
    my $stateFile3 = "ko_".$stateFile;
    my $stateFile4 = "ec_".$stateFile;

    my $fnurl = "xml.cgi?section=Methylomics&page=functionChanged";

    my $fnurl1 = $fnurl . "&stateFile=$stateFile1";
    my $fnurl2 = $fnurl . "&stateFile=$stateFile2";
    my $fnurl3 = $fnurl . "&stateFile=$stateFile3";
    my $fnurl4 = $fnurl . "&stateFile=$stateFile4";

    my $funcall1 = "javascript:reload('$fnurl1', 'heatmap')";
    my $funcall2 = "javascript:reload('$fnurl2', 'heatmap')";
    my $funcall3 = "javascript:reload('$fnurl3', 'heatmap')";
    my $funcall4 = "javascript:reload('$fnurl4', 'heatmap')";

    print "<p>";
    print "Function:&nbsp;&nbsp;";
    print "<input type='radio' onchange=\"$funcall1\" name='func' value='cog' checked />";
    print "COG";
    print "<input type='radio' onclick=\"$funcall2\" name='func' value='pfam'/>";
    print "Pfam";
    print "<input type='radio' onclick=\"$funcall3\" name='func' value='ko'/>";
    print "KO";
    print "<input type='radio' onclick=\"$funcall4\" name='func' value='ec'/>";
    print "EC";
    print "<input type='radio' name='func' value='all' disabled/>";
    print "All (Functions in Cart)";
    print "</p>";

    use FuncCartStor;
    my $fc = new FuncCartStor();
    my $recs = $fc->{recs};
    my @cart_keys = keys(%$recs);
    if (scalar @cart_keys > 0) {
	my $fncarturl = "xml.cgi?section=Methylomics"
	              . "&page=functionCartSelected&hm=$stateFile";
	my $funcall = "javascript:funcCart('$fncarturl', '$fnurl1', 'heatmap')";

	print "<p>\n";
	print "<input type='checkbox' name='cart_fns' id='cart_fns' "
	    . "onclick=\"$funcall\" />\n";
	print "Use only features from function cart ";
	print "</p>\n"; # re-display when checked
    }

    my $fnClause = "";
    #my $fnStr = joinSqlQuoted(",", @cart_keys);
    #$fnClause = "and mfc.function_id in ($fnStr)" if (scalar @cart_keys > 0);
    my $sql = qq{
        select mfc.exp_oid, mfc.function_type, 
               mfc.function_id, mfc.modification_count
          from meth_function_coverage mfc
         where mfc.exp_oid > 3
           and mfc.exp_oid in ($exp_str)
           --and mfc.function_type = 'COG'
           $fnClause
      order by mfc.exp_oid, mfc.function_type
    };
    $cur = execSql( $dbh, $sql, $verbose );

    my %cogrecs;
    my %pfamrecs;
    my %ecrecs;
    my %korecs;

    my %cogs;
    my %pfams;
    my %enzymes;
    my %kos;

    for ( ;; ) {
        my ($expr, $fntype, $fnid, $mod_count) = $cur->fetchrow();
        last if !$expr;

	if (lc($fntype) eq "cog" ) {
	    $cogrecs{$expr.$fnid} = $mod_count;
	    $cogs{ $fnid } = 1;
	} elsif (lc($fntype) eq "pfam") {
	    $pfamrecs{$expr.$fnid} = $mod_count;
	    $pfams{ $fnid } = 1;
	} elsif (lc($fntype) eq "ko") {
	    $korecs{$expr.$fnid} = $mod_count;
	    $kos{ $fnid } = 1;
	} elsif (lc($fntype) eq "enzyme" ||
		 lc($fntype) eq "ec") {
	    $ecrecs{$expr.$fnid} = $mod_count;
	    $enzymes{ $fnid } = 1;
	}
    }

    my @cogids = sort keys %cogs;
    my @pfamids = sort keys %pfams;
    my @koids = sort keys %kos;
    my @ecids = sort keys %enzymes;

    my %cogDict;
    my $url = "$main_cgi?section=FuncCartStor&addToFuncCart=1";
    my $sql = qq{
       select cog_id, cog_name
       from cog
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $cogDict{$id} = $name."\t".$url."&cog_id=$id";
    }
    
    # see: AbundanceToolkit::getFuncDict($dbh, $fntype);
    my %pfamDict;
    my $sql = "select ext_accession, description from pfam_family";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
	my ( $id, $name ) = $cur->fetchrow();
	last if !$id;
	$pfamDict{$id} = $name."\t".$url."&pfam_id=$id";
    }
    $cur->finish();

    my %koDict;
    my $sql = "select ko_id, definition from ko_term";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $koDict{$id} = $name."\t".$url."&ko_id=$id";
    }
    $cur->finish();

    my %ecDict;
    my $sql = "select ec_number, enzyme_name from enzyme";
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $ecDict{$id} = $name."\t".$url."&ec_number=$id";
    }
    $cur->finish();

    use Storable;
    my $state = {
	expids       => \@exps,
	fnids        => \@cogids,
	fntype       => "cog",
	fnrecs       => \%cogrecs,
	rowDict      => \%cogDict,
	colDict      => \%exp2name,
	stateFile    => $stateFile1,
    };
    Storable::store( $state, checkTmpPath("$cgi_tmp_dir/$stateFile1") );

    my $state2 = {
        expids       => \@exps,
        fnids        => \@pfamids,
        fntype       => "pfam",
        fnrecs       => \%pfamrecs,
        rowDict      => \%pfamDict,
        colDict      => \%exp2name,
        stateFile    => $stateFile2,
    };
    Storable::store( $state2, checkTmpPath("$cgi_tmp_dir/$stateFile2") );

    my $state3 = {
        expids       => \@exps,
        fnids        => \@koids,
        fntype       => "ko",
        fnrecs       => \%korecs,
        rowDict      => \%koDict,
        colDict      => \%exp2name,
        stateFile    => $stateFile3,
    };
    Storable::store( $state3, checkTmpPath("$cgi_tmp_dir/$stateFile3") );

    my $state4 = {
        expids       => \@exps,
        fnids        => \@ecids,
        fntype       => "ec",
        fnrecs       => \%ecrecs,
        rowDict      => \%ecDict,
        colDict      => \%exp2name,
        stateFile    => $stateFile4,
    };
    Storable::store( $state4, checkTmpPath("$cgi_tmp_dir/$stateFile4") );

    printHeatMap($state, 0, 0);
    
    print "</div>"; # end allexptab5

    TabHTML::printTabDivEnd();
    print qq{
        <script type='text/javascript'>
        tabview1.addListener("activeTabChange", function(e) {
        });
        </script>
    };

    print end_form();
}

sub newHeatMap {
    my $use_cart = param("cart");
    my $fntype = param("type");
    my $hm = param("hm");

    if ($use_cart eq "") {
	my $stateFile0 = $fntype."_".$hm;
	print hiddenVar("stateFile", $stateFile0);
	loadHeatMap();
	return;
    }

    my $stateFile0 = "cog_".$hm;
    my $path = "$cgi_tmp_dir/$stateFile0";
    if (!( -e $path )) {
        webError("Your session has expired. Please start over again.");
    }
    my $state0 = retrieve($path);
    if ( !defined($state0) ) {
        webError("Your session has expired. Please start over again.");
    }

    my $stateFile2 = $state0->{stateFile};
    if ( $stateFile2 ne $stateFile0 ) {
        webError( "newHeatMap: stateFile mismatch "
                . "'$stateFile2' vs. '$stateFile0'\n" );
    }
    my $expids_ref  = $state0->{expids};
    my $colDict_ref = $state0->{colDict};
    my $exp_str = join(",", @$expids_ref);

    my $dbh = dbLogin(); 

    use FuncCartStor;
    my $fc = new FuncCartStor();
    my $recs = $fc->{recs};
    my @cart_keys = keys(%$recs);

    my $fnClause = "";
    my $fnStr = joinSqlQuoted(",", @cart_keys);
    $fnClause = "and mfc.function_id in ($fnStr)" if (scalar @cart_keys > 0);
    my $sql = qq{
        select mfc.exp_oid, mfc.function_type,
               mfc.function_id, mfc.modification_count
          from meth_function_coverage mfc
         where mfc.exp_oid > 3
           and mfc.exp_oid in ($exp_str)
           --and mfc.function_type = 'COG'
           $fnClause
      order by mfc.exp_oid, mfc.function_type
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my %recs;
    my %fns;
    for ( ;; ) {
        my ($expr, $fntype, $fnid, $mod_count) = $cur->fetchrow();
        last if !$expr;
	$recs{$expr.$fnid} = $mod_count;
	$fns{ $fnid } = 1;
    }
    my @fnids = sort keys %fns;

    my %fnDict;
    my $url = "$main_cgi?section=FuncCartStor&addToFuncCart=1";
    my $sql = qq{
       select cog_id, cog_name
       from cog where cog_id in ($fnStr)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $fnDict{$id} = $name."\t".$url."&cog_id=$id";
    }
    my $sql = qq{
        select ext_accession, description 
        from pfam_family where ext_accession in ($fnStr)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $fnDict{$id} = $name."\t".$url."&pfam_id=$id";
    }
    my $sql = qq{
        select ko_id, definition from ko_term 
        where ko_id in ($fnStr)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $fnDict{$id} = $name."\t".$url."&ko_id=$id";
    }
    my $sql = qq{
        select ec_number, enzyme_name 
        from enzyme where ec_number in ($fnStr)
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ( $id, $name ) = $cur->fetchrow();
        last if !$id;
        $fnDict{$id} = $name."\t".$url."&ec_number=$id";
    }
    $cur->finish();

    use Storable;
    my $stateFile = "all_".$hm;
    my $state = {
        expids       => $expids_ref,
        fnids        => \@fnids,
        fntype       => "all",
        fnrecs       => \%recs,
        rowDict      => \%fnDict,
        colDict      => $colDict_ref,
        stateFile    => $stateFile,
    };
    Storable::store( $state, checkTmpPath("$cgi_tmp_dir/$stateFile") );

    loadHeatMap($stateFile);
}

sub loadHeatMap {
    my ($stateFile) = @_;
    if ($stateFile eq "") {
	$stateFile = param("stateFile");
    }
    my $row_idx = param("row_index");
    my $col_idx = param("col_index");

    my $path = "$cgi_tmp_dir/$stateFile";
    if (!( -e $path )) {
        webError("Your session has expired. Please start over again.");
    }
    my $state = retrieve($path);
    if ( !defined($state) ) {
        webError("Your session has expired. Please start over again.");
    }

    my $stateFile2 = $state->{stateFile};
    if ( $stateFile2 ne $stateFile ) {
        webError( "loadHeatMap: stateFile mismatch "
                . "'$stateFile2' vs. '$stateFile'\n" );
    }

    print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
    print qq{
        <response>
            <maptext><![CDATA[
    };

    printHeatMap($state, $row_idx, $col_idx);

    print qq{
            ]]></maptext>
            <imagemap></imagemap>
        </response>
    };
}

sub printMainJS {
    print qq {
    <script type="text/javascript">
    function reload(url, div) {
        //alert("calling reload: "+url);
        var callback = {
            success: handleSuccess,
            argument: [div]
        };

        if (url != null && url != "") {
            var request = YAHOO.util.Connect.asyncRequest
                ('GET', url, callback);
        }
    }
    function handleSuccess(req) {
        var bodyText;
        try {
            div = req.argument[0];
            response = req.responseXML.documentElement;
            var maptext = response.getElementsByTagName
              ("maptext")[0].firstChild.data;

            //alert("Success!!! "+maptext);
            bodyText = maptext;
        } catch(e) {
        }
        var el = document.getElementById(div);
        el.innerHTML = bodyText;
    }

    function selectAllIds(startId) {
        var el = document.getElementById('motifbox');
        var els = el.getElementsByTagName('option');
        for (var i = 0; i < els.length; i++) {
            var e = els[i];
            e.selected = true;
        }
    }

    function clearAllIds(startId) {
        var el = document.getElementById('motifbox');
        var els = el.getElementsByTagName('option');
        for (var i = 0; i < els.length; i++) {
            var e = els[i];
            e.selected = false;
        }
    }

    function funcCart(url, url2, div) {
        var el = document.getElementById('cart_fns');
        if (el.type == "checkbox") {
            if (el.checked == true) {
                url = url + "&cart=1";

                var els = document.getElementsByTagName('input');
                for (var i = 0; i < els.length; i++) {
                    var e = els[i];
                    if (e.type == 'radio' && e.name == "func") {
                        if (e.value == "all") {
                            e.checked = true;
                        } else {
                            e.disabled = true;
                        }
                    }
                }

            } else {
                var els = document.getElementsByTagName('input');
                var all_checked;
                for (var i = 0; i < els.length; i++) {
                    var e = els[i];
                    if (e.type == 'radio' && e.name == "func") {
                        if (e.value == "all") {
                            all_checked = true;
                        } else {
                            e.disabled = false;
                        }
                    }
                }

                for (var i = 0; i < els.length; i++) {
                    var e = els[i];
                    if (e.type == 'radio' && e.value == 'cog'
                        && all_checked == true) {
                        reload(url2, div);
                        e.checked = true;
                    }
                    if (e.type == 'radio' && e.checked == true
                        && e.name == "func") {
                        url = url + "&type=" + e.value;
                    }
                }

                return;
            }
        }
        //alert("calling funcCart: "+url);
        var callback = {
            success: handleSuccess,
            argument: [div]
        };

        if (url != null && url != "") {
            var request = YAHOO.util.Connect.asyncRequest
                ('GET', url, callback);
        }
    }

    function countMotifSelections(maxFind) {
        var els = document.getElementsByTagName('input');
        var count = 0;
        for (var i = 0; i < els.length; i++) {
            var e = els[i];
            if (e.type == "checkbox" && e.checked == true
                && e.name == "motifs_txm") {
                count++;
                if (count > maxFind) {
                   alert("Please select no more than " + maxFind + " motifs");
                   return false;
                }
            }
        }

        var el = document.getElementById('motifbox');
        var els = el.getElementsByTagName('option');
        for (var i = 0; i < els.length; i++) {
            var e = els[i];
            if (e.selected == true) {
                count++;
                if (count > maxFind) {
                   alert("Please select no more than " + maxFind + " motifs");
                   return false;
                }
            }
        }

        if (count < 1) {
           alert("Please select at least one item");
           return false;
        }

        return true;
    }
    </script>
   };
}

sub printMethModificationChart {
    my @motifs = param("motifs_txm");
    my $motifs_str = joinSqlQuoted(",", @motifs);
    my @exps = param("exp_oid");
    my $exps_str = join(",", @exps);

    if (scalar @motifs < 2) {
        webError( "Please select at least 2 motifs." );
    }

    print "<h1>Methylation modification fraction for selected motifs</h1>";
    print "<p>";
    print "Each motif can be observed in multiple genomes under various "
        . "experimental conditions.<br/>The chart below displays the "
        . "fraction modified for each selected motif.";
    print "</p>";

    my $dbh = dbLogin();
    my $sql = qq{
        select mms.sample, mms.motif_string, mms.fraction
          from meth_motif_summary mms
         where mms.experiment > 3
           and mms.experiment in ($exps_str)
           and mms.motif_string in ($motifs_str)
      order by mms.sample, mms.motif_string
    };
    my $cur = execSql( $dbh, $sql, $verbose );

    my %recs;
    my %motifHash;
    for ( ;; ) {
        my ($sample, $motif_str, $fraction) = $cur->fetchrow();
        last if !$sample;

        if ( exists $recs{$sample} ) {
            push @{$recs{$sample}}, $motif_str."\t".$fraction;
        } else {
            $recs{$sample} = [ $motif_str."\t".$fraction ];
        }

        $motifHash{$motif_str} = 1;
    }

    my $tmpInFile = "$tmp_dir/"."motifs_chart$$.in.tab.txt";
    my $wfh = newWriteFileHandle( $tmpInFile, "inputFile-motifs" );

    my $str;
    my @unique_motifs = sort keys %motifHash;
    my $nmotifs = scalar @unique_motifs;
    foreach my $motif_str (@unique_motifs) {
        $str .= "$motif_str\t";
    }
    chop $str;
    print $wfh "$str\n";

    my @samples = sort keys %recs;
    foreach my $s (@samples) {
        my $sample_recs = $recs{ $s };
        my @srecs = @$sample_recs;
        # iterate through the unique motifs
        my $fraction_str = "";

        OUTER: foreach my $motif (@unique_motifs) {
	    foreach my $rec (@$sample_recs) {
		my ($motif_str, $fraction) = split("\t", $rec);
		if ($motif_str eq $motif) {
		    $fraction_str .= "$fraction\t";
		    next OUTER;
		}
	    }
	    $fraction_str .= "\t";
        }
        chop $fraction_str;
        print $wfh "$fraction_str\n";
        #print $wfh ".98\t.78\t.56\t\t\t\t\t\t.77\t.96\n"; # test
    }
    close $wfh;

    print "<p style='width: 650px;'>";
    print alink("$tmp_url/"."motifs_chart$$.in.tab.txt",
                "View input file", "_blank");
    print "</p>";

    my $tmpRcmdFile = "$tmp_dir/cmd$$".".r";
    my $tmpJpegFile = "$tmp_dir/motifs$$".".jpeg";

    my $wfh = newWriteFileHandle( $tmpRcmdFile, "motifs_chart" );
    my $width = $nmotifs * 20;
    $width = $width + 200 if $nmotifs < 15;
    print $wfh "fracs <- read.table"
	. "('$tmpInFile', sep='\\t', header=T, fill=T)\n";
    print $wfh "jpeg('$tmpJpegFile', width=$width, height=600, units='px')\n";
    print $wfh "par(mar=c(12,4,1,2)+0.1)\n"; # margins B, L, T, R
    print $wfh "boxplot(fracs, "
            #. "main='Methylation modification fraction for motifs', "
             . "xlab='', ylab='Fraction modified', "
             . "varwidth = TRUE, " # box width prop to sqrt num pts in group
               # las - style of labeling, cex - scaling
             . "col=c('skyblue'), cex.axis=0.75, las=2)\n";
    print $wfh "grid(NULL, NULL)\n"; # default align to tick marks
    print $wfh "abline(h=1:$nmotifs, v=1:$nmotifs, col='lightgray', lty=3)\n";
    print $wfh "mtext('Motif',side=1,line=10)\n"; # custom x label
    #. "col=c('royalblue'), cex=1.2, las=2, quote=FALSE)\n";
    close $wfh;

    WebUtil::unsetEnvPath();
    my $cmd = "R --slave < $tmpRcmdFile > /dev/null";
    my $st = system( $cmd );
    WebUtil::resetEnvPath();

    if ( ! (-e $tmpJpegFile) ) {
        print "<p><font color='red'>No data to display. "
            . "(no $tmpJpegFile)</font></p>\n";
        printStatusLine( "Loaded.", 2 );
    }

    print "<img src='$tmp_url/motifs$$.jpeg'>\n";
}

############################################################################
# printHeatMap - print the heat map of experiments vs functions
############################################################################
sub printHeatMapIndex {
    my $stateFile = param("stateFile");
    my $row_idx = param("row_index");
    my $col_idx = param("col_index");

    my $url = "$section_cgi&page=methylomics";
    my $link = alink($url, "Methylomics Experiments");
    print "<p>Back to $link</p>";

    my $path = "$cgi_tmp_dir/$stateFile";
    if (!( -e $path )) {
        webError("Your session has expired. Please start over again.");
    }
    my $state = retrieve($path);
    if ( !defined($state) ) {
        webError("Your session has expired. Please start over again.");
    }

    my $stateFile2 = $state->{stateFile};
    if ( $stateFile2 ne $stateFile ) {
        webError( "printHeatMapIndex: stateFile mismatch "
		. "'$stateFile2' vs. '$stateFile'\n" );
    }
    printHeatMap($state, $row_idx, $col_idx);
}

sub printHeatMap {
    my ($state, $row_idx, $col_idx) = @_;
    $row_idx = 0 if ($row_idx eq "");
    $col_idx = 0 if ($col_idx eq "");

    my $expids_ref    = $state->{expids};
    my $fnids_ref     = $state->{fnids};
    my $fntype        = $state->{fntype};
    my $fnrecs_ref    = $state->{fnrecs};
    my $rowDict_ref   = $state->{rowDict};
    my $colDict_ref   = $state->{colDict};
    my $stateFile     = $state->{stateFile};

    my $n_fns = scalar @$fnids_ref;
    my $n_exps = scalar @$expids_ref;

    print "<div id='heatmap'>";
    print "<table border='0'>\n";
    my $row_max = $batch_size + $row_idx;
    $row_max = $n_fns if ($row_max > $n_fns);
    my @myfns = @$fnids_ref[$row_idx..($row_max - 1)];
    
    use AbundanceProfiles;
    my %table;
    my %normTable;
    foreach my $c (@myfns) {
	my $str;
	my $str2;
	foreach my $e (@$expids_ref) {
	    my $cnt = $fnrecs_ref->{$e.$c};
	    $cnt = 0 if $cnt eq "";
	    $str .= $cnt."\t";
	    
	    my $val2 = AbundanceProfiles::countToBound($cnt);
	    $str2 .= $val2."\t";
	}
	chop $str;
	$table{ $c } = $str;
	$normTable{ $c } = $str2;
    }

    use Storable;
    my $stateFile2 = "methexp_$fntype"."_${row_idx}_${col_idx}_heatMap$$";
    my $state2 = {
	expids       => $expids_ref,
	fnids        => \@myfns,
	fntype       => $fntype,
	table        => \%table,
	normTable    => \%normTable,
	rowDict      => $rowDict_ref,
	colDict      => $colDict_ref,
	stateFile    => $stateFile2,
    };
    Storable::store( $state2, checkTmpPath("$cgi_tmp_dir/$stateFile2") );
    
    print "<tr>\n";
    print "<td valign='top'>\n";
    printHeatMapSection($row_idx, $col_idx, $state2);
    print "</td>\n";
    print "</tr>\n";
    print "</table>\n";

    my $next_idx = $row_idx + $batch_size;
    my $prev_idx = $row_idx - $batch_size;
    my $nextUrl = "xml.cgi?section=Methylomics&page=heatmap"
                . "&stateFile=$stateFile"
		. "&row_index=$next_idx&col_index=$col_idx";

    my $prevUrl = "xml.cgi?section=Methylomics&page=heatmap"
                . "&stateFile=$stateFile"
		. "&row_index=$prev_idx&col_index=$col_idx";

    if ($row_idx > 0) {
	my $func = "javascript:reload('$prevUrl', 'heatmap')";
	print "<input type='button' class='smbutton' "
	    . "value='&lt; Previous Range' "
	    . "onClick=\"$func\" />\n";
    }
    if ($next_idx < $n_fns) {
	my $func = "javascript:reload('$nextUrl', 'heatmap')";
	print "<input type='button' class='smbutton' "
	    . "value='Next Range &gt;' "
	    . "onClick=\"$func\" />\n";
    }
    print "</div>"; # div for re-display
}

############################################################################ 
# printHeatMapSection - Generates one heat map section.
############################################################################ 
sub printHeatMapSection { 
    my ($row_idx, $col_idx, $state) = @_; 

    my $expids_ref    = $state->{expids}; 
    my $fnids_ref     = $state->{fnids}; 
    my $fntype        = $state->{fntype}; 
    my $table_ref     = $state->{table}; 
    my $normTable_ref = $state->{normTable}; 
    my $rowDict_ref   = $state->{rowDict}; 
    my $colDict_ref   = $state->{colDict}; 
    my $stateFile     = $state->{stateFile}; 

    my $id      = "${row_idx}_${col_idx}_methexp_${fntype}fns_heatMap$$"; 
    my $outFile = "$tmp_dir/$id.png"; 
    my $n_rows  = scalar @$fnids_ref; 
    my $n_cols  = scalar @$expids_ref; 

    my $chars = 3;          # for now - length($exp_oid)
    my $args = {
            id            => $id,
            n_rows        => $n_rows,
            n_cols        => $n_cols,
            image_file    => $outFile,
            taxon_aref    => $fnids_ref,
            y_label_chars => $chars,
            y_labels      => "both",
    };

    use ProfileHeatMap;
    my $hm = new ProfileHeatMap($args);
    my $html = $hm->drawSpecial
	( $table_ref, $fnids_ref, $expids_ref, $rowDict_ref, $colDict_ref,
	  $normTable_ref, $stateFile, 0 );
    $hm->printToFile();
    print "$html\n";
}

sub writeDiv {
    my ($which, $recs_href, $motif_aref) = @_;

    if ($which eq "table") {
        print "<input type='button' class='medbutton' name='view'"
            . " value='Graphical View'"
            . " onclick='showView(\"graphical\")' />";
        print "<br/>";
        printStatsByChemTableView($recs_href);

    } elsif ($which eq "graphical") {
        print "<input type='button' class='medbutton' name='view'"
            . " value='Table View'"
            . " onclick='showView(\"table\")' />";
        print "<br/>";
        printStatsByChemGraphicalView($recs_href, $motif_aref);
        print "<br/>";
    }
}

sub printStatsByChemTableView {
    my ($recs_href) = @_;
    my %recs = %$recs_href;
    my @chemistry_types = keys %recs;

    my $width = 800;
    print "<table border=0>";
    print "<tr>";
    my $i = 0;
    foreach my $ch (@chemistry_types) {
        print "<td valign=top align=left>";
        print "<span style='font-size: 12px; color: navy; "
            . "font-family: Arial, Helvetica, sans-serif;'>\n";
        print "<b>$ch</b><br/>";
        print "</span>";
        $i++;

        my $itID = "chem".$i;
        my $it = new InnerTable(1, "$itID$$", $itID, 1);
        $it->hideAll();
        my $sd = $it->getSdDelim();
        $it->addColSpec( "Motif String", "asc", "left" );
        $it->addColSpec( "Motif Count", "desc", "right" );

	my $chem_recs = $recs{ $ch };
	foreach my $r (@$chem_recs) {
	    my ($chemistry, $motif_str, $num_mods) = split("\t", $r);
	    my $row;
	    $row .= $motif_str."\t";
	    $row .= $num_mods;
	    $it->addRow($row);
	}
	$it->printOuterTable("nopage");
	print "</td>";
	print "<td>&nbsp;&nbsp;&nbsp;</td>"; # spacing
    }
    print "</tr>";
    print "</table>";    
}

sub printStatsByChemGraphicalView {
    my ($recs_href, $motif_aref) = @_;
    my %recs = %$recs_href;
    my @chemistry_types = keys %recs;
    my @unique_motifs = @$motif_aref;
    my $nmotifs = scalar @unique_motifs;

    my @datas;
    foreach my $ch (@chemistry_types) {
        my $chem_recs = $recs{ $ch };
        my $datastr;
        OUTER: foreach my $m (@unique_motifs) {
            my $cnt = 0;
	    foreach my $r (@$chem_recs) {
		my ($chemistry, $motif_str, $num_mods) = split("\t", $r);
		if ($m eq $motif_str) {
		    $cnt = log($num_mods)/log(2); # use log2 ?
		    #$cnt = $num_mods;
		    $datastr .= $cnt.",";
		    next OUTER;
		}
	    }
	    $datastr .= $cnt.",";
        }
        chop $datastr;
        push @datas, $datastr;
    }

    my $width = $nmotifs * 12 * (scalar @chemistry_types);
    my $table_width = $width + 100;

    # PREPARE THE BAR CHART
    #my $chart = newStackedChart();
    use ChartUtil;
    my $chart = ChartUtil::newBarChart();
    $chart->WIDTH($width);
    $chart->HEIGHT(700);
    $chart->DOMAIN_AXIS_LABEL("Motif String");
    $chart->RANGE_AXIS_LABEL("Log2(Motif Count)");
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("yes");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_URLS("no");
    #$chart->DO_LOG("2");
    $chart->SERIES_NAME( \@chemistry_types );
    $chart->CATEGORY_NAME( \@unique_motifs );
    $chart->DATA( \@datas );

    my $st = -1;
    if ( $env->{chart_exe} ne "" ) {
        $st = generateChart($chart);
    }

    print "<table width=$table_width border=0>\n";
    print "<tr>";
    print "<td padding=0 valign=top align=left>\n";
    ###########################
    if ( $env->{chart_exe} ne "" ) {
        if ( $st == 0 ) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "statsByChemGraphical", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . ".png' BORDER=0 ";
            print " width=" . $chart->WIDTH . " HEIGHT=" . $chart->HEIGHT;
            print " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }
    ###########################
    print "</td>\n";
    print "<td>\n";
    print "<table border='0'>\n";

    my $idx = 0;
    foreach my $series1 (@chemistry_types) {
        last if !$series1;

        print "<tr>\n";
        print
          "<td align=left style='font-family: Calibri, Arial, Helvetica; "
	  . "white-space: nowrap;'>\n";
        if ( $st == 0 ) {
            print "<img src='$tmp_url/"
              . $chart->FILE_PREFIX
              . "-color-"
              . $idx
              . ".png' border=0>";
            print "&nbsp;&nbsp;";
        }

        print $series1;
        print "</td>\n";
        print "</tr>\n";
        $idx++;
    }

    print "</table>\n";
    print "</td></tr>\n";
    print "</table>\n";
}

############################################################################ 
# printDataForSample - prints info for one sample of an experiment 
############################################################################ 
sub printDataForSample { 
    my $sample = param("sample"); 

    my $dbh = dbLogin(); 
    printStatusLine("Loading ...", 1);
 
    #my $expClause = expClause("e");
    my $expClause = "";
    my $sql = qq{ 
        select $nvl(s.description, 'unknown'),
               e.exp_oid,
               e.exp_name, 
               $nvl(e.project_name, 'unknown'),
	       s.IMG_taxon_oid
        from meth_sample s, meth_experiment e, taxon tx
        where s.sample_oid = ?
        and s.experiment = e.exp_oid 
        and s.IMG_taxon_oid = tx.taxon_oid
	$expClause
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $sample ); 
    my ($sample_desc, $exp_oid, $exp_name, 
	$project_name, $taxon_oid) = $cur->fetchrow(); 
    $cur->finish(); 

    if ($sample_desc eq "") {
        printStatusLine( "unauthorized user", 2 );
        printMessage( "You do not have permission to view this experiment." );
	#$dbh->disconnect(); 
        return; 
    }
 
    print "<h1>Base Modifications</h1>\n";
    print "<p>Sample: $sample_desc</p>\n";

    my $url = "$main_cgi?section=TaxonDetail&page=scaffolds"
	    . "&taxon_oid=$taxon_oid&study=$study&sample=$sample";
    print buttonUrl( $url, "Chromosome Viewer", "smbutton" );
    print "<br/>";

    print "<span style='font-size: 12px; "
	. "font-family: Arial, Helvetica, sans-serif;'>\n";
    my $url = "$section_cgi&page=experiments"
	    . "&exp_oid=$exp_oid"; 
    print alink($url, $exp_name, "_blank")."\n"; 
    print "</span>\n";

    printMainForm(); 

    my $sql = qq{
        select distinct m.modification_oid, $nvl(m.IMG_scaffold_oid, ''),
               $nvl(m.motif_string, ''), m.start_coord, m.end_coord, 
               m.methylation_coord, m.score,
               m.strand, $nvl(m.context, ''), m.coverage
        from meth_modification m, meth_sample s
        where m.sample = s.sample_oid
        and m.experiment = s.experiment
        and s.sample_oid = ?
        and s.IMG_taxon_oid = ?
    };

    my $it = new InnerTable(1, "methsampledata$$", "methsampledata", 1);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "ID", "asc", "right" );
    $it->addColSpec( "Motif Context", "asc", "left" );
    $it->addColSpec( "Motif String", "asc", "left" );
    $it->addColSpec( "Start Coord", "asc", "right" );
    $it->addColSpec( "End Coord", "asc", "right" );
    $it->addColSpec( "Methylation Coord", "asc", "right" );
    $it->addColSpec( "Strand", "asc", "left" );
    #$it->addColSpec( "Modification Type", "asc", "left" );
    $it->addColSpec( "Score", "asc", "right" );
    $it->addColSpec( "Coverage", "asc", "right" );
    $it->addColSpec( "Scaffold ID", "asc", "right" );

    my $count = 0;
    my $cur = execSql( $dbh, $sql, $verbose, $sample, $taxon_oid ); 
    for ( ;; ) {
        my ($motif_oid, $scaffold_oid, $motif_str, $start, $end, $mcoord,
	    $score, $strand, $context, $coverage) = $cur->fetchrow();
        last if !$motif_oid;

	my $flank_length = 2500;
	my $start0 = $mcoord - $flank_length + 1;
	my $start0 = $start0 > 0 ? $start0 : 0;
	my $end0 = $start + $flank_length + 1;
	my $url = "$main_cgi?section=ScaffoldGraph"
	        . "&page=scaffoldGraph&scaffold_oid=$scaffold_oid"
	        . "&start_coord=$start0&end_coord=$end0";

        my $row;
        my $row = $sd."<input type='checkbox' "
                . "name='exp_motifs' value='$motif_oid'/>\t";
        $row .= $motif_oid."\t";
        $row .= $context."\t";
        $row .= $motif_str."\t";
        $row .= $start."\t";
        $row .= $end."\t";
        $row .= $mcoord."\t";
	$row .= $strand."\t";
	#$row .= $mtype."\t";
	$row .= $score."\t";
	$row .= $coverage."\t";
	if ($scaffold_oid ne "") {
	    $row .= $scaffold_oid.$sd.alink($url, $scaffold_oid)."\t";
	} else {	
	    $row .= $scaffold_oid."\t";
	}
        $it->addRow($row);
	$count++;
    }

    $it->printOuterTable(1); 
    #$dbh->disconnect(); 

    print end_form();
    printStatusLine("$count genes loaded.", 2);
} 

############################################################################ 
# printStudiesForGenome - prints all studies that use a given genome
############################################################################ 
sub printStudiesForGenome { 
    my $taxon_oid = param("taxon_oid");
    my $dbh = dbLogin(); 

    my $sql = qq{ 
        select taxon_name 
        from taxon
        where taxon_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
    my ($taxon_name) = $cur->fetchrow(); 
    $cur->finish(); 
 
    my $sql = qq{ 
        select distinct m.motif_summ_oid, s.experiment 
        from meth_motif_summary m, meth_sample s
        where s.sample_oid = m.sample
	and s.IMG_taxon_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
    my %motifCntHash;
    for ( ;; ) { 
        my ($motif, $exp) = $cur->fetchrow();
        last if !$exp;
        $motifCntHash{ $exp }++; 
    } 
    $cur->finish(); 

    my $rclause = urClause("tx");
    my $imgClause = WebUtil::imgClause('tx');
    my $sql = qq{ 
        select distinct e.exp_oid, 
               e.exp_name, count(s.sample_oid)
        from meth_experiment e, 
             meth_sample s, taxon tx 
        where e.exp_oid = s.experiment 
        and s.IMG_taxon_oid = tx.taxon_oid
        and tx.taxon_oid = ?
        $rclause
        $imgClause
        group by e.exp_oid, e.exp_name
        order by e.exp_oid 
    }; 
    #and tx.is_public = 'Yes'
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid ); 
 
    my $url = "$main_cgi?section=TaxonDetail"
	     ."&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<h1>Methylomics Experiments</h1>\n"; 
    print "<p style='width: 650px;'>";
    print "<u>Genome</u>: ".alink($url, $taxon_name)."</p>\n"; 

    my $it = new InnerTable(1, "methylomics$$", "methylomics", 0);
    $it->hideAll();
 
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Experiment ID", "asc", "right" ); 
    $it->addColSpec( "Experiment Name", "asc", "left" );
    $it->addColSpec( "Total Samples", "desc", "right" );
    $it->addColSpec( "Unique Motifs", "desc", "right" );

    for ( ;; ) { 
        my ($exp_oid, $experiment, $num_samples) = $cur->fetchrow(); 
        last if !$exp_oid; 
 
        my $url = "$section_cgi&page=experiments"
	        . "&exp_oid=$exp_oid"
	        . "&taxon_oid=$taxon_oid"; 

        my $row;
        $row .= $exp_oid."\t"; 
        $row .= $experiment.$sd.alink($url, $experiment)."\t"; 
        $row .= $num_samples."\t";
	$row .= $motifCntHash{$exp_oid}."\t";

        $it->addRow($row); 
    } 
    $cur->finish(); 
    $it->printOuterTable("nopage");
    #$dbh->disconnect(); 
} 

############################################################################
# printSelectOneSample - prints a table of all samples for the genome
#        where the entries are exclusively selectable (radiobuttons)
#        * ANNA: need to modify for MER-FS
############################################################################
sub printSelectOneSample {
    my ($taxon_oid) = @_;
    if ($taxon_oid eq "") {
	$taxon_oid = param("taxon_oid"); 
    }

    my $dbh = dbLogin(); 
    printStatusLine("Loading ...", 1); 

    my $sql = qq{
        select s.IMG_taxon_oid, s.sample_oid,
               $nvl(s.description, 'unknown'),
               count(distinct mm.modification_oid)
          from meth_sample s, meth_modification mm
         where s.IMG_taxon_oid = ?
           and s.sample_oid = mm.sample
      group by s.IMG_taxon_oid, s.sample_oid, s.description
      order by s.IMG_taxon_oid, s.sample_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable(1, "methexps$$", "methexps", 1); 
    $it->{pageSize} = 10;
    my $sd = $it->getSdDelim(); 
    $it->addColSpec( "Choose" );
    $it->addColSpec( "Sample ID", "asc", "right" );
    $it->addColSpec( "Sample Name","asc", "left" );
    $it->addColSpec( "Motif Count", "desc", "right" );

    my $count; 
    for ( ;; ) { 
        my ($taxon, $sample, $desc, $motifCount) = $cur->fetchrow(); 
        last if !$sample; 

        my $url = "$section_cgi&page=sampledata&sample=$sample"; 

        my $row; 
        my $row = $sd."<input type='radio' "
                . "onclick='setStudy(\"$study\")' "
	        . "name='exp_samples' value='$sample'/>\t";
        $row .= $sample."\t"; 
        $row .= $desc.$sd.alink($url, $desc, "_blank")."\t";
        $row .= $motifCount."\t"; 
        $it->addRow($row);
        $count++; 
    } 
    $cur->finish(); 
    $it->printOuterTable(1); 
    #$dbh->disconnect();
}

############################################################################
# printExperiments - prints all experiments (for the genome)
############################################################################
sub printExperiments { 
    my $taxon_oid = param("taxon_oid"); 
    my $exp_oid = param("exp_oid");
    my $dbh = dbLogin(); 
    printStatusLine("Loading ...", 1);

    #my $expClause = expClause("e");
    my $expClause = ""; # for now ...
    my $sql = qq{ 
        select e.exp_name, $nvl(e.project_name, 'unknown'),
               e.description, e.exp_contact, 
               $nvl(eel.custom_url, 'unknown')
        from meth_experiment e
	left outer join meth_experiment_ext_links eel 
	on e.exp_oid = eel.exp_oid
        where e.exp_oid = ?
	$expClause
    }; 
    my $sql = qq{ 
        select e.exp_name, e.project_name, 
               e.description, e.exp_contact, ''
        from meth_experiment e
        where e.exp_oid = ?
    }; 
    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );
    my ($exp_name, $project_name, 
	$exp_desc, $exp_contact, $curl) = $cur->fetchrow();
    $cur->finish(); 

    if ($exp_name eq "") {
        printStatusLine( "unauthorized user", 2 );
        printMessage( "You do not have permission to view this experiment." );
        return; 
    }

    my $sql = qq{
	select publications
	from meth_experiment_publications
	where exp_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );
    my ($publications) = $cur->fetchrow();
    $cur->finish();

    # check if this is PubMed
    if ($publications =~ m/^PMID/) {
        my $pubmed = $env->{ pubmed_base_url };
	my $url = $pubmed . substr($publications, 6);
	$publications = "<a href=$url target=_blank>PubMed</a>";
    }

    # get the study description:
    my $text = "<b>$exp_name</b><br/><b>Synopsis: </b>$exp_desc"
	     . "<br/><b>Publication: </b>$publications<br/><br/>"
	     . "<b>Contacts: </b>";
    if ($curl ne "") {
	$text .= "<a href=$curl target=_blank>$curl</a>";
    } else {
	$text .= "$exp_contact";
    }

    WebUtil::printHeaderWithInfo 
	("Methylomics Experiment", $text, 
	 "show description for this experiment", 
	 "Experiment Description", 0, "Methylomics.pdf"); 

    my $total_genomes = 0;
    my %taxon2info;
    my @study_taxons;

    if ($taxon_oid eq "") {
        my $sql = qq{
            select distinct tx.taxon_oid, tx.taxon_display_name
            from taxon tx, meth_sample s
            where s.IMG_taxon_oid = tx.taxon_oid
            and s.experiment = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );
        for ( ;; ) {
            my ($tx, $tx_name) = $cur->fetchrow();
            last if !$tx;
            $taxon2info{ $tx } = $tx_name;
        }
        $cur->finish();

        @study_taxons = keys( %taxon2info );
        $total_genomes = scalar @study_taxons;

        print "<p style='width: 650px;'>\n";
        if ($total_genomes == 1) {
            $taxon_oid = $study_taxons[0];
            my $taxon_name = $taxon2info{ $taxon_oid };
            my $txurl = "$main_cgi?section=TaxonDetail"
 		      . "&page=taxonDetail&taxon_oid=$taxon_oid";
            print "<u>Genome</u>: ".alink($txurl, $taxon_name, "_blank");
            print "<br/>";
        }

        print "<u>Experiment</u>: $exp_name</p>\n";

    } else {
        $total_genomes = 1;
        my $sql = qq{
            select taxon_display_name
              from taxon
             where taxon_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my ($taxon_name) = $cur->fetchrow();
        $taxon2info{ $taxon_oid } = $taxon_name;
        push @study_taxons, $taxon_oid;
        $cur->finish();

        my $txurl = "$main_cgi?section=TaxonDetail"
	          . "&page=taxonDetail&taxon_oid=$taxon_oid";
        print "<p style='width: 650px;'>\n";
        print "<u>Genome</u>: ".alink($txurl, $taxon_name, "_blank");
        print "<br/><u>Experiment</u>: $exp_name</p>\n";
    }

    setLinkTarget("_blank");
    printMainForm();

    use TabHTML; 
    TabHTML::printTabAPILinks("experimentsTab");

    my @tabIndex = ( "#exptab1" );
    my @tabNames = ( "Select Samples" );
    my $idx = 2;
    
    push @tabIndex, "#exptab".$idx++;
    push @tabNames, "View in GBrowse";

    TabHTML::printTabDiv("experimentsTab", \@tabIndex, \@tabNames);
    print "<div id='exptab1'>";

    my @recs;
    my $sql = qq{
	select s.IMG_taxon_oid, s.sample_oid, 
               $nvl(s.description, 'unknown'),
               count(distinct m.motif_summ_oid)
	from meth_sample s, meth_motif_summary m
	where s.experiment = ?
        and s.sample_oid = m.sample
        and s.experiment = m.experiment
        group by s.IMG_taxon_oid, s.sample_oid, s.description
        order by s.IMG_taxon_oid, s.sample_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid );  
    for ( ;; ) {
	my ($taxon, $sample, $desc, $cnt) = $cur->fetchrow();
	last if !$sample;
	my $rec = "$taxon\t$sample\t$desc\t$cnt";
	push @recs, $rec;
    }

    my $it = new InnerTable(1, "methexps$$", "methexps", 1);
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Sample ID", "asc", "right" );
    $it->addColSpec( "Sample Name","asc", "left" );
    $it->addColSpec( "Unique Motifs", "desc", "right" );
    if (scalar @study_taxons > 1) {
        $it->addColSpec( "Genome Name","asc", "left" );
    }

    my $count;
    foreach my $rec ( @recs ) {
	my ($taxon, $sample, $desc, $cnt) = split("\t", $rec);

        my $url = "$section_cgi&page=sampledata&sample=$sample";
        my $txurl = "$main_cgi?section=TaxonDetail"
	          . "&page=taxonDetail&taxon_oid=$taxon";

	my $row;
        my $row = $sd."<input type='checkbox' "
	        . "name='exp_samples' value='$sample'/>\t"; 
        $row .= $sample."\t";
        $row .= $desc.$sd 
            . "<a href='$url' id='link$sample' target='_blank'>"
	    . escHtml($desc)."</a>"."\t";
	my $murl = "$section_cgi&page=motifsummary&taxon_oid=$taxon_oid"
	         . "&sample_oid=$sample&exp_oid=$exp_oid";
	$row .= $cnt.$sd.alink($murl, $cnt, "_blank")."\t";

        if (scalar @study_taxons > 1) {
            my $genome = $taxon2info{ $taxon };
            $row .= $genome.$sd
                .alink($txurl, $genome, "_blank")."\t";
        }

        $it->addRow($row); 
	$count++;
    } 

    if ($count > 10) {
	print "<input type=button name='selectAll' value='Select All' "
	    . "onClick='selectAllByName(\"exp_samples\", 1)' "
	    . "class='smbutton' />\n"; 
	print nbsp( 1 ); 
	print "<input type='button' name='clearAll' value='Clear All' "
	    . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 
    }
    $it->printOuterTable("nopage");
    print "<input type=button name='selectAll' value='Select All' "
	. "onClick='selectAllByName(\"exp_samples\", 1)' "
	. "class='smbutton' />\n"; 
    print nbsp( 1 ); 
    print "<input type='button' name='clearAll' value='Clear All' "
	. "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n"; 

    #$dbh->disconnect(); 
    print "</div>"; # end exptab1

    if (scalar @study_taxons > 1) {
	TabHTML::printTabDivEnd();
	print end_form();
	printStatusLine("$count sample(s) loaded.", 2);
	return;
    }

    my $idx = 2;
    my $tab = "exptab".$idx++;
    print "<div id='$tab'>";
    # Link to GBrowse:
    if ($taxon_oid ne "") {
	my $gbrowse_base_url = $env->{ gbrowse_base_url };
	my $gbrowseUrl = $gbrowse_base_url."gb2/gbrowse/";
	# need to encode the taxon_oid for security:
	#my $tx = encode($study.$exp_oid.$taxon_oid);
	my $tx = encode($study.$taxon_oid);
	#print "<br/>> encoded tx: $tx"; ## anna for configuring gbrowse
	$gbrowseUrl .= $tx;
	
	print qq{ 
	    <p>
            <a href=$gbrowseUrl target="_blank">
            <img src="$base_url/images/GBrowse-ME.jpg" 
                 width="320" height="217" border="0" 
                 style="border:2px #99CCFF solid;" alt="View in GBrowse"
                 title="View genome sequence in GBrowse"/>
	    </a>
	    <br/><a href=$gbrowseUrl target="_blank">View in GBrowse</a>
            </p> 
	}; 
    }
    print "</div>"; # end exptab2
    TabHTML::printTabDivEnd(); 

    print end_form();
    printStatusLine("$count sample(s) loaded.", 2);
} 

############################################################################
# printMotifSummary - prints unique motifs for a specified sample,
#                     experiment, and taxon
############################################################################
sub printMotifSummary {
    my $taxon_oid = param("taxon_oid"); 
    my $sample = param("sample_oid");
    my $exp_oid = param("exp_oid");

    my $dbh = dbLogin(); 
    my $expClause = "";
    my $sql = qq{
        select $nvl(s.description, 'unknown'),
               e.exp_oid, e.exp_name,
               $nvl(e.project_name, 'unknown')
        from meth_sample s, meth_experiment e
        where s.sample_oid = ?
        and s.experiment = e.exp_oid
        $expClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $sample );
    my ($sample_desc, $exp_oid, $exp_name, $project_name) = $cur->fetchrow();
    $cur->finish();

    if ($sample_desc eq "") {
        printStatusLine( "unauthorized user", 2 );
        printMessage( "You do not have permission to view this experiment." );
	#$dbh->disconnect(); 
        return;
    }

    my $sql = qq{
        select taxon_name
        from taxon
        where taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name) = $cur->fetchrow();
    $cur->finish();

    my $url = "$main_cgi?section=TaxonDetail"
	     ."&page=taxonDetail&taxon_oid=$taxon_oid";
    my $surl = "$section_cgi&page=sampledata&sample=$sample";

    print "<h1>Motif Summary</h1>\n";
    print "<p style='width: 650px;'>";
    print "Genome: ".alink($url, $taxon_name, "_blank"); 
    print "<br/>";
    print "Sample: ".alink($surl, $sample_desc, "_blank");
    print "<br/>";
    print "<span style='font-size: 12px; "
        . "font-family: Arial, Helvetica, sans-serif;'>\n";
    my $url = "$section_cgi&page=experiments&exp_oid=$exp_oid";
    print "Experiment: ".alink($url, $exp_name, "_blank")."\n";
    print "</span>\n";
    print "</p>\n";

    my $sql = qq{
        select m.motif_summ_oid, m.motif_string,
               m.center_pos, m.fraction, m.n_detected,
               m.n_genome, m.group_tag, 
               $nvl(m.partner_motif_string, ''),
               m.mean_score, m.mean_ipd_ratio, m.mean_coverage,
               m.objective_score, m.modification_type,
               s.IMG_taxon_oid, s.sample_oid,
               $nvl(s.description, 'unknown')
        from meth_sample s, meth_motif_summary m
        where s.experiment = ?
        and s.sample_oid = ?
        and s.experiment = m.experiment
        and m.IMG_taxon_oid = ?
        order by m.motif_summ_oid
    };

    my $it = new InnerTable(1, "methmotifs$$", "methmotifs", 0);
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "ID", "asc", "right" );
    $it->addColSpec( "Motif String","asc", "left" );
    $it->addColSpec( "Center Pos", "asc", "right" );
    $it->addColSpec( "Fraction", "asc", "right" );
    $it->addColSpec( "N Detected", "asc", "right" );
    $it->addColSpec( "N Genome", "asc", "right" );
    $it->addColSpec( "Group Tag", "asc", "left" );
    $it->addColSpec( "Partner Motif String", "asc", "left" );
    $it->addColSpec( "Mean Score", "asc", "right" );
    $it->addColSpec( "Mean IPD Ratio", "asc", "right" );
    $it->addColSpec( "Mean Coverage", "asc", "right" );
    $it->addColSpec( "Objective Score", "asc", "right" );
    $it->addColSpec( "Modification Type", "asc", "left" );

    my $cur = execSql( $dbh, $sql, $verbose, $exp_oid, $sample, $taxon_oid );
    for ( ;; ) {
        my ($motif_oid, $motif_str, $center_pos, $fraction, $n_detected,
	    $n_genome, $group_tag, $partner_motif_str, $mean_score,
	    $mean_ipd_ratio, $mean_coverage, $objective_score, $m_type,
	    $taxon, $sample, $desc) = $cur->fetchrow();
        last if !$motif_oid;

        my $row;
        my $link = "<a href='#sequence' "
	         . "onclick=javascript:findMotif('$motif_str')>$motif_oid</a>";
        $row .= $motif_oid.$sd.$link."\t";
        #$row .= $motif_oid."\t";

	my $motif_str2 = $motif_str;
	if ($motif_str ne "" && $center_pos ne "" 
	    && length($motif_str) >= $center_pos) {
	    my @chars = split("", $motif_str);
	    my $start = substr($motif_str, 0, $center_pos);
	    my $c = substr($motif_str, $center_pos, 1);
	    my $end = substr($motif_str, $center_pos+1);
	    $motif_str2 = "$start<font color=red><u>$c</u></font>$end";
	}
        $row .= $motif_str.$sd.$motif_str2."\t";
        $row .= $center_pos."\t";

	$fraction = sprintf("%.7f", $fraction);
        $row .= $fraction."\t";
        $row .= $n_detected."\t";
        $row .= $n_genome."\t";
        $row .= $group_tag."\t";
        $row .= $partner_motif_str."\t";
        $row .= $mean_score."\t";
        $row .= $mean_ipd_ratio."\t";
        $row .= $mean_coverage."\t";
        $row .= $objective_score."\t";
        $row .= $m_type."\t";

        $it->addRow($row);
    }
    $it->printOuterTable("nopage");

    #$dbh->disconnect(); 

    use Motifs;
    Motifs::selectScaffolds($taxon_oid, $sample, $exp_oid);
}

############################################################################
# addMethylations - mark areas where there are methylated bases
############################################################################
sub addMethylations {
    my ( $dbh, $scaffold_oid, $scf_panel, $panelStrand, 
	 $scf_start_coord, $scf_end_coord, $sample ) = @_;

    # see if there is any methylomics data:
    my $methylomics_data = $env->{methylomics};
    return if (!$methylomics_data);

    my $nvl = getNvl();
    my $sql = qq{
        select distinct m.methylation_coord, m.strand
        from meth_modification m
        where m.sample = ?
        and m.IMG_scaffold_oid = ?
        and m.methylation_coord >= ?
        and m.methylation_coord <= ?
    };

    my $cur = execSql( $dbh, $sql, $verbose, $sample, $scaffold_oid,
		       $scf_start_coord, $scf_end_coord );
    my $count = 0;
    for ( ;; ) {
        my ( $meth_coord, $strand ) = $cur->fetchrow();
        last if !$meth_coord;
        $count++;
        $scf_panel->addMethylations( $meth_coord, $strand );
    }
    $cur->finish();
}

sub expClause {
    my ($alias) = @_; 

    return "" if !$user_restricted_site;
    my $super_user = getSuperUser();
    return "" if ( $super_user eq "Yes" );
    my $contact_oid = getContactOid();
    return "" if !$contact_oid; 

    my $exp_oid_attr = "exp_oid"; 
    $exp_oid_attr = "$alias.exp_oid"
	if $alias ne "" 
	&& $alias ne "exp_oid" 
	&& $alias !~ /\./; 

    $exp_oid_attr = $alias 
	if $alias ne "" 
	&& $alias ne "exp_oid" 
	&& $alias =~ /\./;
    
    my $clause = qq{ 
	and $exp_oid_attr in
            ( select exp.exp_oid
	      from meth_experiment exp
	      where exp.is_public = 'Yes' 
	      union all
	      select cmp.meth_permissions
	      from contact_meth_permissions cmp
	      where cmp.contact_oid = $contact_oid
	    ) 
	}; 
    
    return $clause;
}

1;

