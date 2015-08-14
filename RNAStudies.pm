############################################################################
# RNAStudies.pm - displays rna expression data
# $Id: RNAStudies.pm 33981 2015-08-13 01:12:00Z aireland $
############################################################################
package RNAStudies;
my $section = "RNAStudies";
my $study = "rnaseq";

use POSIX qw(ceil floor);
use strict;
use CGI qw( :standard);
use Data::Dumper;
use DBI;
use WebConfig;
use WebUtil;
use InnerTable;
use GD;
use DrawTree;
use DrawTreeNode;
use OracleUtil;
use ProfileHeatMap;
use Storable;
use ChartUtil;
use GeneTableConfiguration;
use HtmlUtil;
use QueryUtil;

$| = 1;

my $env           = getEnv();
my $cgi_dir       = $env->{cgi_dir};
my $cgi_url       = $env->{cgi_url};
my $cgi_tmp_dir   = $env->{cgi_tmp_dir};
my $tmp_url       = $env->{tmp_url};
my $tmp_dir       = $env->{tmp_dir};
my $main_cgi      = $env->{main_cgi};
my $section_cgi   = "$main_cgi?section=RNAStudies";
my $verbose       = $env->{verbose};
my $base_url      = $env->{base_url};
my $cluster_bin   = $env->{cluster_bin};
my $r_bin         = $env->{r_bin};
my $R             = "R"; # $env->{r_bin};
my $nvl           = getNvl();
my $img_er        = $env->{img_er};

my $user_restricted_site  = $env->{user_restricted_site};
my $color_array_file = $env->{large_color_array_file};
my $include_metagenomes = $env->{include_metagenomes};

my $batch_size = 60;
my $YUI = $env->{yui_dir_28};

my $enzyme_base_url    = $env->{enzyme_base_url};
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
    timeout( 60 * 20 );    # timeout in 20 mins (from main.pl)
    if ($page eq "rnastudies" ||
	paramMatch("rnastudies") ne "") {
        printOverview();
    }
    elsif ($page eq "experiments") {
	printExperiments();
    }
    elsif (paramMatch("setGeneOutputCol") ne "") {
	printDataForSample(1);
    }
    elsif ($page eq "sampledata") {
	printDataForSample();
    }
    elsif ($page eq "genereads") {
        printInfoForGene();
    }
    elsif ($page eq "genomestudies" ||
	   paramMatch("genomestudies") ne "") {
	printStudiesForGenome();
    }
    elsif ($page eq "genomesByProposal" ||
	   paramMatch("genomesByProposal") ne "") {
	printGenomesForProposal();
    }
    elsif ($page eq "samplesByProposal" ||
	   paramMatch("samplesByProposal") ne "") {
	printSamplesForProposal();
    }
    elsif ($page eq "describeOneSample" ||
	   paramMatch("describeOneSample") ne "") {
	printDescribeSamples("describe_one");
    }
    elsif ($page eq "describeSamples" ||
	   paramMatch("describeSamples") ne "") {
	printDescribeSamples();
    }
    elsif ($page eq "compareSamples" ||
	   paramMatch("compareSamples") ne "") {
	printCompareSamples();
    }
    elsif ($page eq "describeClustered" ||
	   paramMatch("describeClustered") ne "") {
        printDescribeSamples("describe_clustered");
    }
    elsif ($page eq "clusterResults" ||
	   paramMatch("clusterResults") ne "") {
        printClusterResults();
    }
    elsif ($page eq "clusterMapSort" ||
	   paramMatch("clusterMapSort") ne "") {
	printClusterMapSort();
    }
    elsif ($page eq "previewSamples" ||
           paramMatch("previewSamples") ne "") {
        printPreviewGraph();
    }
    elsif ($page eq "samplePathways" ||
           paramMatch("samplePathways") ne "") {
        printPathwaysForSample();
    }
    elsif ($page eq "byFunction" ||
           paramMatch("byFunction") ne "") {
        printExpressionByFunction();
    }
    elsif ($page eq "compareByFunction" ||
           paramMatch("compareByFunction") ne "") {
        printExpressionByFunction("pairwise");
    }
    elsif ($page eq "doSpearman" ||
           paramMatch("doSpearman") ne "") {
        doSpearman();
    }
    elsif ($page eq "doRegression" ||
	   paramMatch("doRegression") ne "") {
	doRegression();
    }
    elsif ($page eq "geneGroup" ||
	   paramMatch("geneGroup") ne "") {
	printGeneGroup();
    }
    elsif ($page eq "differenitalExpression" ||
           paramMatch("differenitalExpression") ne "") {
        printDifferentialExpression();
    }
    elsif ( $page eq "downloadDEInTab" ) {
        checkAccess();
        downloadDEInTab();
        WebUtil::webExit(0);
    }
    elsif ( $page eq "downloadDEInRData" ) {
        checkAccess();
        downloadDEInRData();
        WebUtil::webExit(0);
    }
}

############################################################################
# printOverview - prints all the rna expression experiments in IMG
############################################################################
sub printOverview {
    my $dbh = dbLogin();
    my $d = param("domain");
    my $domainClause = "";
    $domainClause = " and tx.domain = '$d' " if $d ne "";

    my $rclause = urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $datasetClause = datasetClause("dts");

    WebUtil::printHeaderWithInfo
        ("RNASeq Expression Studies", "", "", "", 0, "RNAStudies.pdf");
    print "<p>*Showing studies for $d only</p>" if $d ne "";

    printMainForm();

    use TabHTML;
    TabHTML::printTabAPILinks("allexperimentsTab");

    my @tabIndex = ( "#allexptab1", "#allexptab2" );
    my @tabNames = ( "Studies", "Studies by Ref. Data Set" );
    TabHTML::printTabDiv("allexperimentsTab", \@tabIndex, \@tabNames);

    print "<div id='allexptab1'>";
    my $sql = qq{
        select distinct gs.study_name, tx.domain, dts.dataset_type,
               count(distinct dts.reference_taxon_oid),
               count(dts.gold_id)
        from rnaseq_dataset dts, gold_study\@imgsg_dev gs,
             gold_sp_study_gold_id\@imgsg_dev gssg, taxon tx
        where dts.gold_id = gssg.gold_id
        and gssg.study_gold_id = gs.gold_id
        and dts.reference_taxon_oid = tx.taxon_oid
        $rclause
        $imgClause
        $domainClause
        $datasetClause
        group by gs.study_name, tx.domain, dts.dataset_type
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %allproposals;
    for ( ;; ) {
        my ($proposal, $domain, $dataset_type, $num_genomes, $num_samples)
            = $cur->fetchrow();
        last if !$proposal;
        next if !$num_samples;

        my $rec = "$domain\t$dataset_type\t$num_genomes\t$num_samples";

        if (exists($allproposals{ "$proposal" })) {
            my $rec1 = $allproposals{ $proposal };
            my ($domain1, $dataset_type1, $num_genomes1, $num_samples1) = split("\t", $rec1);
            my $d = "";
            $d = $domain if ($domain eq $domain1);
            $rec = "$d\t$dataset_type\t";
            $rec .= ($num_genomes + $num_genomes1) . "\t";
            $rec .= ($num_samples + $num_samples1) . "\t";
        }
        $allproposals{ "$proposal" } = $rec;
    }

    my $it = new InnerTable(1, "studieslist$$", "studieslist", 0);
    $it->hideAll();
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Study Name (Proposal Name)", "asc", "left" );
    $it->addColSpec( "Data Set Type", "asc", "left" );
    $it->addColSpec( "Total<br/>Ref. Data Sets", "desc", "right",
		     "", "Data Set mapped to by RNASeq data" );
    $it->addColSpec( "Total<br/>RNA Seq Data Sets", "desc", "right" );

    my $item_count = 0;
    foreach my $proposal (keys %allproposals) {
        my $rec = $allproposals{ $proposal };
        my ($domain, $dataset_type, $num_genomes, $num_samples) = split("\t", $rec);

        my $row = $proposal . $sd . $proposal . "\t";
        $row .= $dataset_type . $sd . $dataset_type . "\t";
        my $pp = WebUtil::massageToUrl2($proposal);
        my $url = "$section_cgi&page=genomesByProposal"
	        . "&proposal=$pp&domain=$domain";
        $row .= $num_genomes.$sd.alink($url, $num_genomes, "_blank")."\t";

        my $url = "$section_cgi&page=samplesByProposal"
	        . "&proposal=$pp&domain=$domain&genomes=$num_genomes";
        $row .= $num_samples.$sd.alink($url, $num_samples, "_blank")."\t";
        $it->addRow($row);
        $item_count++;
    }

    $it->printOuterTable("nopage");
    print "</div>"; # end allexptab1

    print "<div id='allexptab2'>";
    print "<p>".WebUtil::domainLetterNote()."</p>" if $d eq "";

    my $it = new InnerTable(1, "genomestudies$$", "genomestudies", 1);
    $it->hideAll();
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Ref. Data Set", "asc", "left" );
    $it->addColSpec( "Domain", "asc", "left" ) if $d eq "";
    $it->addColSpec( "Total<br/>RNA Seq Data Sets", "desc", "right" );

    my %hrecs; # for proper sorting by domain, name
    my $sql = qq{
        select distinct dts.reference_taxon_oid,
               tx.taxon_display_name, tx.domain,
               count(dts.gold_id)
        from rnaseq_dataset dts, taxon tx,
             gold_sp_study_gold_id\@imgsg_dev gssg
        where dts.gold_id = gssg.gold_id
        and dts.reference_taxon_oid = tx.taxon_oid
        $rclause
        $imgClause
        $domainClause
        $datasetClause
        group by dts.reference_taxon_oid, tx.taxon_display_name, tx.domain
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for ( ;; ) {
        my ($tx, $txname, $txdomain, $num_samples) = $cur->fetchrow();
        last if !$tx;

        my $dm = substr( $txdomain, 0, 1 );
	my $rec = "$tx\t$txname\t$dm\t$num_samples";
	$hrecs{$dm.$txname} = $rec;
    }
    $cur->finish();

    foreach my $key ( sort keys %hrecs ) {
	my $rec = $hrecs{ $key };
        my ($tx, $txname, $dm, $num_samples) = split("\t", $rec);

        my $row;
        my $url = "$main_cgi?section=TaxonDetail"
	        . "&page=taxonDetail&taxon_oid=$tx";
        $row .= $txname.$sd.alink($url, $txname, "_blank")."\t";
        $row .= $dm."\t" if $d eq "";

        my $url = "$section_cgi&page=genomestudies&taxon_oid=$tx"; # for now
        $row .= $num_samples.$sd.alink($url, $num_samples, "_blank")."\t";

        $it->addRow($row);
    }

    $it->printOuterTable("nopage");
    print "</div>"; # end allexptab2

    TabHTML::printTabDivEnd();
    printStatusLine("$item_count proposals loaded", 2);
    print end_form();
}

############################################################################
# printGenomesForProposal - lists the genomes for a given proposal
#                           linked to rnaseq studies
############################################################################
sub printGenomesForProposal {
    my $proposal = param("proposal");
    my $domain = param("domain");
    my $domainClause;
    $domainClause = " and tx.domain = '$domain' " if $domain ne "";

    print "<h1>Ref. Genomes for RNASeq Study</h1>";
    print "<p><u>Study Name (Proposal Name)</u>: $proposal</p>";

    my $rclause = urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $datasetClause = datasetClause("dts");

    my $dbh = dbLogin();

    printMainForm();
    my $it = new InnerTable(1, "genomesforstudy$$", "genomesforstudy", 1);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Genome ID", "asc", "right" );
    $it->addColSpec( "Genome Name", "asc", "left" );
    $it->addColSpec( "Add Date", "desc", "right" );
    $it->addColSpec( "Release Date", "desc", "right" );
    $it->addColSpec( "Modified Date", "desc", "right" );
    $it->addColSpec( "Is Public", "asc", "left" );
    $it->addColSpec( "Sequencing<br/>Center", "asc", "left" );
    $it->addColSpec( "Total<br/>RNA Seq Data Sets", "desc", "right" );

    my $sql = qq{
        select distinct
               tx.taxon_oid,
               tx.taxon_display_name,
               to_char(tx.add_date, 'yyyy-mm-dd'),
               to_char(tx.release_date, 'yyyy-mm-dd'),
               to_char(tx.mod_date, 'yyyy-mm-dd'),
               tx.is_public, tx.seq_center,
               count(distinct dts.gold_id)
        from rnaseq_dataset dts, gold_study\@imgsg_dev gs,
             gold_sp_study_gold_id\@imgsg_dev gssg, taxon tx
        where dts.gold_id = gssg.gold_id
        and gssg.study_gold_id = gs.gold_id
        and dts.reference_taxon_oid = tx.taxon_oid
        and gs.study_name = ?
        $rclause
        $imgClause
        $domainClause
        $datasetClause
        group by tx.taxon_oid, tx.taxon_display_name,
                 to_char(tx.add_date, 'yyyy-mm-dd'),
                 to_char(tx.release_date, 'yyyy-mm-dd'),
                 to_char(tx.mod_date, 'yyyy-mm-dd'),
                 tx.is_public, tx.seq_center
    };
    my $cur = execSql( $dbh, $sql, $verbose, $proposal );
    my $count = 0;
    for ( ;; ) {
        my ($taxon_oid, $taxon_name, $add_date, $release_date, $mod_date,
            $is_public, $seq_center, $num_samples) = $cur->fetchrow();
        last if !$taxon_oid;

        my $row = $sd."<input type='checkbox' "
                . "name='taxon_filter_oid' value='$taxon_oid'/>\t";
        my $url = "$main_cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$taxon_oid";
        $row .= $taxon_oid."\t";
        $row .= $taxon_name.$sd.alink($url, $taxon_name, "_blank")."\t";
        $row .= $add_date."\t";
        $row .= $release_date."\t";
        $row .= $mod_date."\t";
        $row .= $is_public."\t";
        $row .= $seq_center."\t";

        my $url = "$section_cgi&page=genomestudies&taxon_oid=$taxon_oid";
        $row .= $num_samples.$sd.alink($url, $num_samples, "_blank")."\t";

        $it->addRow($row);
        $count++;
    }

    WebUtil::printGenomeCartFooter() if ($count > 10);
    $it->printOuterTable(1);
    WebUtil::printGenomeCartFooter();

    print end_form;
}

############################################################################
# printSamplesForProposal - lists the samples for a given proposal
#                           linked to rnaseq studies
############################################################################
sub printSamplesForProposal {
    my $proposal = param("proposal");
    my $domain = param("domain");
    my $num_genomes = param("genomes");

    my $domainClause;
    $domainClause = " and tx.domain = '$domain' " if $domain ne "";

    my $rclause = urClause("tx");
    my $imgClause = WebUtil::imgClause("tx");
    my $datasetClause = datasetClause("dts");

    my $sql = qq{
        select distinct dts.gold_id, gsp.display_name, dts.dataset_oid,
               dts.reference_taxon_oid, tx.taxon_display_name,
               tx.in_file, tx.genome_type
        from rnaseq_dataset dts, taxon tx, gold_study\@imgsg_dev gs,
             gold_sp_study_gold_id\@imgsg_dev gssg,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.gold_id = gssg.gold_id
        and gssg.study_gold_id = gs.gold_id
        and dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = tx.taxon_oid
        and gs.study_name = ?
        $rclause
        $imgClause
        $domainClause
        $datasetClause
    };
    my $dbh = dbLogin();
    my $cur = execSql( $dbh, $sql, $verbose, $proposal );

    my $text = "<b>Study Name (Proposal Name)</b>: $proposal";
    WebUtil::printHeaderWithInfo
        ("Data Sets for RNASeq Study",$text,"show description for this study",
         "Study Description", 0, "RNAStudies.pdf");
    print "<p style='width: 950px;'>"
	. "<u>Study Name (Proposal Name)</u>: $proposal</p>";

    setLinkTarget("_blank");
    printMainForm();
    printRNASeqJavascript();

    use TabHTML;
    TabHTML::printTabAPILinks("experimentsTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("experimentsTab");
        </script>
    };

    my @tabIndex = ( "#exptab1" );
    my @tabNames = ( "Select Samples" );
    my $idx = 2;
    if ($num_genomes == 1 && $domain ne "" && $domain ne "*Microbiome") {
        push @tabIndex, "#exptab".$idx++;
        push @tabNames, "View in GBrowse";
    }
    push @tabIndex, "#exptab".$idx++;
    push @tabIndex, "#exptab".$idx++;
    push @tabIndex, "#exptab".$idx++;

    push @tabNames, "Single Sample Analysis";
    push @tabNames, "Pairwise Sample Analysis";
    push @tabNames, "Multiple Sample Analysis";

    TabHTML::printTabDiv("experimentsTab", \@tabIndex, \@tabNames);
    print "<div id='exptab1'>";

    printNormalizationInfo();

    # rnaexps is used as id to locate element in script:
    my $it = new InnerTable(1, "rnaexps$$", "rnaexps", 3);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "GOLD ID", "asc", "right" );
    $it->addColSpec( "Data Set Name", "asc", "left" );
    $it->addColSpec( "Data Set ID", "asc", "right" );
    $it->addColSpec( "Genes<br/>with Reads", "desc", "right" );
    $it->addColSpec( "Total Reads<br/>Count", "desc", "right" );
    $it->addColSpec( "Average Reads<br/>per Gene", "desc", "right" );
    $it->addColSpec( "Ref. Data Set", "asc", "left",
		     "", "Data Set mapped to by RNASeq data" );

    printStartWorkingDiv();

    my $count;
    my $in_file;
    my $genome_type;
    my %study_taxons;
    my %types;
    my @recs;
    print "Querying for data...<br/>";
    for ( ;; ) {
        my ($gold_id, $sample_name, $sample, $taxon_oid, $taxon_name,
	    $in_file0, $genome_type0) = $cur->fetchrow();
        last if !$gold_id;

	$study_taxons{ $taxon_oid } = 1;
	$in_file = $in_file0;

	$genome_type = $genome_type0;
	$types{ $genome_type0 } = 1;
        my $rec = "$gold_id\t$sample_name\t"
	        . "$sample\t$taxon_oid\t$taxon_name\t\t\t";
	push @recs, $rec;
    }

    my $num_genomes = scalar keys %study_taxons;
    $genome_type = "" if scalar (keys %types) != 1;

    my %sample2counts;
    foreach my $taxon_oid (keys %study_taxons) {
	print "Getting sample counts for TX:$taxon_oid...<br/>";
	# use rnaseq_dataset_stats table:
        my $sql = qq{
            select dts.dataset_oid,
            dts.gene_count, dts.total_reads_count, dts.avg_reads_count
            from rnaseq_dataset rd, rnaseq_dataset_stats dts
            where rd.reference_taxon_oid = ?
            and dts.dataset_oid = rd.dataset_oid
            $datasetClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ;; ) {
            my ($dataset_oid, $geneCount, $totalReads, $avgReads)
                = $cur->fetchrow();
            last if !$dataset_oid;
            my $rec = "$dataset_oid\t$geneCount\t$totalReads\t$avgReads";
            $sample2counts{ $dataset_oid } = $rec;
        }
	next; # ignore the rest here...

	my %s2cnt = MetaUtil::getRNASeqSampleCountsForTaxon($taxon_oid);
	@sample2counts{ keys %s2cnt } = values %s2cnt;
        next if (keys %s2cnt > 0);

	print "...querying database for genes and reads...<br/>";
	my $sql = qq{
            select dts.dataset_oid,
            count(distinct es.IMG_gene_oid),
            sum(es.reads_cnt), round(avg(es.reads_cnt), 2)
            from rnaseq_dataset dts, rnaseq_expression es
            where dts.reference_taxon_oid = ?
            and dts.dataset_oid = es.dataset_oid
            $datasetClause
            group by dts.dataset_oid
            order by dts.dataset_oid
        };
	# anna: will remove when rnaseq_expression is cleaned out
	$cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	for ( ;; ) {
            my ($sample, $geneCount, $totalReads, $avgReads)
                = $cur->fetchrow();
            last if !$sample;
            my $rec = "$sample\t$geneCount\t$totalReads\t$avgReads";
            $sample2counts{ $sample } = $rec;
	}
    }

    print "Preparing the data...<br/>";
    foreach my $rec ( @recs ) {
        my ($gold_id, $sample_name, $sample, $taxon_oid, $taxon_name,
	    $geneCount, $totalReads, $avgReads)
            = split("\t", $rec);

        if (%sample2counts && $sample2counts{ $sample } ne "") {
            my $line = $sample2counts{ $sample };
            ($sample, $geneCount, $totalReads, $avgReads)
                = split("\t", $line);
	}

        my $row = $sd."<input type='checkbox' "
	        . "name='exp_samples' value='$sample'/>\t";
	if (!blankStr($gold_id)) {
	    my $url = HtmlUtil::getGoldUrl($gold_id);
	    $row .= $gold_id.$sd
		. alink($url, $gold_id, "_blank")."\t";
	} else {
	    $row .= $gold_id."\t";
	}

        my $url = "$section_cgi&page=sampledata&sample=$sample";
        $row .= $sample_name.$sd
            . "<a href='$url' id='link$sample' target='_blank'>"
            . $sample_name."</a>"."\t";

        $row .= $sample."\t";
        #$row .= $sample.$sd
        #    . "<a href='$url' id='link$sample' target='_blank'>"
        #    . $sample."</a>"."\t";

        $row .= $geneCount."\t";
        $row .= $totalReads."\t";
        $row .= $avgReads."\t";

        my $url = "$main_cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$taxon_oid";
	#anna: add <span id=$sample></span>
        #$row .= $taxon_name.$sd.alink($url, $taxon_name, "_blank")."\t";
        $row .= $taxon_name.$sd
            . "<a href='$url' id='txlink$sample' name='$taxon_oid' "
	    . "target='_blank'>".$taxon_name."</a>"."\t";

        $it->addRow($row);
        $count++;
    }

    printEndWorkingDiv();

    if ($count > 10) {
        print "<input type=button name='selectAll' value='Select All' "
            . "onClick='selectAllByName(\"exp_samples\", 1)' "
            . "class='smbutton' />\n";
        print nbsp( 1 );
        print "<input type='button' name='clearAll' value='Clear All' "
            . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    } else {
	$it->hideAll();
    }

    $it->printOuterTable(1);
    print "<input type=button name='selectAll' value='Select All' "
        . "onClick='selectAllByName(\"exp_samples\", 1)' "
        . "class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' "
        . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    printNotes("studysamples");
    print "</div>"; # end exptab1

#    if (scalar keys %study_taxons > 1) {
#	TabHTML::printTabDivEnd();
#        print end_form();
#        printStatusLine("$count sample(s) loaded.", 2);
#        return;
#    }

    my $idx = 2;
    if ($num_genomes == 1 && $domain ne "" && $domain ne "*Microbiome") {
        my $tab = "exptab".$idx++;
        print "<div id='$tab'>";
        # Link to GBrowse:
	my $taxon_oid = (keys %study_taxons)[0];
        if ($taxon_oid ne "") {
            my $gbrowse_base_url = $env->{ gbrowse_base_url };
            my $gbrowseUrl = $gbrowse_base_url."gb2/gbrowse/";
            # need to encode the taxon_oid for security:
            my $tx = encode($taxon_oid);
            #print "<br/>> encoded tx: $tx"; ## anna for configuring gbrowse
            $gbrowseUrl .= $tx;

            print qq{
            <p><a href=$gbrowseUrl target="_blank">
            <img src="$base_url/images/GBrowse-win.jpg" width="320" height="217" border="0" style="border:2px #99CCFF solid;" alt="View in GBrowse" title="View gene coverage for samples in GBrowse"/>
            </a>
            <br/><a href=$gbrowseUrl target="_blank">View in GBrowse
            </a></p>
            };
        }
        print "</div>"; # end exptab2
    }

    my $tab = "exptab".$idx++;
    print "<div id='$tab'>";

    print hiddenVar( "section",  $section );
    print hiddenVar( "study",    $study );
    print hiddenVar( "proposal", $proposal );

    my $taxon_oid = (keys %study_taxons)[0];
    if ($num_genomes == 1) {
	print hiddenVar( "taxon_oid", $taxon_oid );
	print hiddenVar( "in_file", $in_file );
	print hiddenVar( "genome_type", $genome_type );
    } else {
	$taxon_oid = "";
	$in_file = "";
    }

    printDescribeOneTab($taxon_oid, $in_file, $genome_type);
    print "</div>"; # end exptab3

    if (scalar @recs < 2) {
	TabHTML::printTabDivEnd();
        print end_form();
        printStatusLine("$count sample(s) loaded.", 2);
        return;
    }

    $tab = "exptab".$idx++;
    print "<div id='$tab'>";
    printPairwiseTab($taxon_oid, $in_file, $genome_type);
    print "</div>"; # end exptab4

    $tab = "exptab".$idx++;
    print "<div id='$tab'>";
    print printDescribeMultiTab($taxon_oid, $count);
    print "</div>"; # end exptab5

    TabHTML::printTabDivEnd();

    print qq{
        <script type='text/javascript'>
        tabview1.addListener("activeTabChange", function(e) {
            if (e.newValue.get('label') == "Multiple Sample Analysis") {
                setSelectedTaxons();
            }
            if (e.newValue.get('label') == "Pairwise Sample Analysis") {
                setReference();
            }
        });
        </script>
    };

    print end_form;
    printStatusLine("$count sample(s) loaded.", 2);
}

sub printDescribeOneTab {
    my ($taxon_oid, $in_file, $genome_type) = @_;
    print "<h2>Describe Sample</h2>";
    print "<p>You may select a sample to view its gene expression and the "
        . "associated functions.<br/>";
    print "Choose <font color='blue'><u>Pathways</font></u> to see a list of "
        . "pathways in which genes from this sample are found to participate.";
    print "<br/>Choose <font color='blue'><u>Chromosome Viewer</font></u> "
        . "to view the chromosome colored by expression values for the "
        . "selected sample.";
    print "</p>\n";

    use GeneCartStor;
    my $gc = new GeneCartStor();
    my $recs = $gc->readCartFile(); # get records
    my @cart_keys = keys(%$recs);

    print "<p>\n";
    print "<input type='checkbox' name='describe_cart_genes_1' "
        . "id='describe_cart_genes_1' "
        . "onclick='checkIt(\"describe_cart_genes_1\")' />\n";
    print "Use only genes from gene cart ";
    print "</p>\n";

    my $name = "_section_${section}_describeOneSample";
    print submit( -name    => $name,
                  -value   => "Gene Expression Summary",
                  -class   => "smdefbutton",
                  -onclick => "return validateSampleSelection(1);" );
    print nbsp(1);
    my $name = "_section_${section}_samplePathways";
    print submit( -name    => $name,
                  -value   => "Pathways",
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(1);" );
    print nbsp(1);
    my $name = "_section_TaxonDetail_scaffolds";
    if ($genome_type eq "metagenome") {
        $name = "_section_MetaDetail_scaffolds";
    }
    print submit( -name    => $name,
                  -value   => "Chromosome Viewer",
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(1);" );
}

sub printPairwiseTab {
    my ($taxon_oid, $in_file, $genome_type) = @_;
    print "<h2>Find Up/Down Regulated Genes</h2>";

    print "<p>\n";
    print "You may select 2 samples to identify genes "
        . "that are up or down regulated.<br/>\n"
        . "Choose <font color='blue'><u>Compare by Function</u></font> "
        . "to see whether genes participating in a given <br/>function "
        . "have been up- or down- regulated between the 2 samples "
        . "as a group. ";
    print "</p>\n";

    print "<p>\n";
    print "<b>Reference</b>:<br/>\n";
    print "<input type='radio' name='reference' id='reference1' "
        . "value='1' checked />";
    print "<label id='ref1' for='reference1'> "
        . "Use 1 as reference</label><br/>\n";
    print "<input type='radio' name='reference' id='reference2' "
        . "value='2' />";
    print "<label id='ref2' for='reference2'> "
        . "Use 2 as reference</label><br/>\n";
    print "</p>\n";

    print "<p>\n";
    print "<b>Metric</b>:<br/>\n";
    print "<input type='radio' name='metric' "
        . "value='logR' checked />"
        . "logR=log2(query / reference)"
        . "<br/>\n";
    print "<input type='radio' name='metric' "
        . "value='RelDiff' />"
        . "RelDiff=2(query - reference)/(query + reference)"
        . "<br/>\n";
    print "</p>\n";

    print "<p>\n";
    print "<b>Threshold</b>: ";
    print "<input type='text' name='threshold' "
        . "size='1' maxLength=10 value='1' />\n";
    print "(default=1)";

    if ($taxon_oid eq "") {
	print "<br/><br/><u>Please note</u>: If the 2 samples selected are from <font color='red'>different genomes</font>, then they cannot be compared <br/>using gene expression analysis";
    }
    print "</p>\n";

    # need div id for yui container
    print "<p><div id='container' class='yui-skin-sam'>";
    print qq{
        <script type='text/javascript'>
        YAHOO.namespace("example.container");
        YAHOO.util.Event.on("anchor1", "click", initPanel());
        </script>
    };
    print "</div>\n";
    ######### end preview div

    my $url = "xml.cgi?section=RNAStudies&page=previewSamples";
    $url .= "&taxon_oid=$taxon_oid&in_file=$in_file";

    print "<input type='BUTTON' id='anchor1' value='Preview' "
	. "class='smbutton' onclick=javascript:doPreview('$url') />";
    print nbsp(1);
    my $name = "_section_${section}_compareSamples";
    print submit( -id      => "compare",
		  -name    => $name,
                  -value   => "Compare",
                  -class   => "smdefbutton",
                  -onclick => "return validateSampleSelection(2);" );
    print nbsp(1);
    my $name = "_section_${section}_compareByFunction";
    print submit( -name    => $name,
                  -value   => "Compare by Function",
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(2);" );

    if ($genome_type ne "metagenome") {
	WebUtil::printSubHeaderWithInfo
	    ("Spearman's Rank Correlation", "", "", "", $include_metagenomes);
        print "<p>\n";
        print "You may analyze more closely the strength of the association between each pair of expression measurements <br/>by performing a Spearman's Rank Correlation. This involves 1) ranking the values under each condition and then <br/>2) calculating the correlation on pairs of ranks. The resulting correlation values for each comparison are in the <br/>range of -1 to 1 (where values in between -1 and -0.5 indicate strong negative correlation, 0 means that the ranked <br/>value pairs are completely independent and there is no correlation, and values in between 0.5 and 1 indicate strong <br/>positive correlation).";
        print "</p>\n";

        my $name = "_section_${section}_doSpearman";
        print submit( -name    => $name,
                      -id      => "spearman",
                      -value   => "Spearman",
                      -class   => "smbutton",
                      -onclick => "return validateSampleSelection(2);" );
    }

    print "<h2>Linear Regression</h2>";

    print "<p>\n";
    print "You may select 2 samples to compare using linear regression analysis and R-squared. <br/>This analysis can help determine whether the selected samples are replicates.";
    print "</p>\n";

    my $name = "_section_${section}_doRegression";
    print submit( -id      => "regress",
		  -name    => $name,
                  -value   => "Regress",
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(2);" );
}

sub printDescribeMultiTab {
    my ($taxon_oid, $count) = @_;
    print "<h2>Describe Samples</h2>";

    print "<p>\n";
    print "You may select samples to compare and describe. If you choose "
        . "to first cluster the samples<br/> to have the results colored "
        . "by the cluster grouping, go to <font color='blue'><u>"
        . "Map Clusters to Pathways</u></font> below.<br/>"
        . "Choose <font color='blue'><u>Expression by Function</u></font> "
        . "to see, for each selected sample, the average expression<br/>"
        . "of genes participating in a given function as a group.";
    print "</p>\n";

    use GeneCartStor;
    my $gc = new GeneCartStor();
    my $recs = $gc->readCartFile(); # get records
    my @cart_keys = keys(%$recs);

    print "<p>\n";
    print "<input type='checkbox' name='describe_cart_genes' "
        . "id='describe_cart_genes' "
        . "onclick='checkIt(\"describe_cart_genes\")' />\n";
    print "Use only genes from gene cart ";
    print "</p>\n";

    if ($taxon_oid eq "") {
	print "<p>\n";
        print "<u>Please note</u>: If the samples selected are from <font color='red'>different genomes</font>, then they cannot be compared <br/>using gene expression analysis";
	print "</p>\n";
    }

    my $name = "_section_${section}_describeSamples";
    print submit( -id      => "expression_summary",
		  -name    => $name,
                  -value   => "Gene Expression Summary",
                  -class   => "smdefbutton",
                  -onclick => "return validateSampleSelection(1,1);" );
    print nbsp(1);
    my $name = "_section_${section}_byFunction";
    print submit( -id      => "expression_byfunction",
		  -name    => $name,
                  -value   => "Expression by Function",
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(1,1);" );

    print "<h2>Cluster Samples</h2>";
    print "<p>\n";
    print "You may select samples and cluster them based on the ";
    print "abundance of the expressed genes.<br/>\n";
    print "Proximity of grouping indicates the relative degree ";
    print "of similarity of samples to each other.<br/>\n";
    print "</p>\n";

    print "<p>\n";
    print "<b>Clustering Method</b>:<br/>\n";
    print "<input type='radio' name='method' "
        . "value='m' checked />Pairwise complete-linkage (default)<br/>\n";
    print "<input type='radio' name='method' "
        . "value='s' />Pairwise single-linkage<br/>\n";
    #print "<input type='radio' name='method' "
    #   . "value='c' />Pairwise centroid-linkage<br/>\n";
    print "<input type='radio' name='method' "
        . "value='a' />Pairwise average-linkage<br/>\n";
    print "</p>\n";

    print "<p>\n";
    print "<b>Distance Measure</b>:<br/>\n";
    #print "<input type='radio' name='correlation' "
    #   . "value='0' />No gene clustering<br/>\n";
    #print "<input type='radio' name='correlation' "
    #   . "value='1' />Uncentered correlation<br/>\n";
    print "<input type='radio' name='correlation' "
        . "value='2' checked />Pearson correlation (default)<br/>\n";
    #print "<input type='radio' name='correlation' "
    #   . "value='3' />Uncentered correlation, absolute value<br/>\n";
    #print "<input type='radio' name='correlation' "
    #   . "value='4' />Pearson correlation, absolute value<br/>\n";
    print "<input type='radio' name='correlation' "
        . "value='5' />Spearman's rank correlation<br/>\n";
    #print "<input type='radio' name='correlation' "
    #   . "value='6' />Kendall's tau<br/>\n";
    print "<input type='radio' name='correlation' "
        . "value='7' />Euclidean distance<br/>\n";
    print "<input type='radio' name='correlation' "
        . "value='8' />City-block distance (Manhattan)<br/>\n";
    print "</p>\n";

    my $max_length = length($count);
    print "<p>\n";
    print "<b>Minimum number of samples in which a gene should "
        . "appear in order to be included</b>: ";
    print "<input type='text' name='min_num' "
        . "size='1' maxLength=$max_length value='3' />\n";
    print "(default=3, total=$count)";
    print "</p>\n";

    print "<p>\n";
    print "Cut-off threshold: "
        . "<input type='text' name='cluster_threshold' "
        . "size='1' maxLength='10' value='0.8' />\n";
    print "(default=0.8)";
    print "</p>\n";

    print "<p>\n";
    print "<input type='checkbox' name='cluster_cart_genes' "
	. "id='cluster_cart_genes' "
	. "onclick='checkIt(\"cluster_cart_genes\")' />\n";
    print "Use only genes from gene cart ";
    print "</p>\n";

    my $name = "_section_${section}_clusterResults";
    print submit( -id      => "cluster",
		  -name    => $name,
                  -value   => "Cluster",
                  -class   => "smdefbutton",
                  -onclick => "return validateSampleSelection(3,1);" );
    print nbsp(1);
    my $name = "_section_${section}_describeClustered";
    print submit( -id      => "map_clusters",
		  -name    => $name,
                  -value   => "Map Clusters to Pathways",
                  -class   => "smbutton",
                  -onclick => "return validateSampleSelection(3,1);" );
    return; # printing return here seems to eliminate an unwanted "1"
}

sub printRNASeqJavascript {
    print qq{
        <script language='JavaScript' type='text/javascript'>
        function checkIt(item) {
            var checked = document.getElementById(item).checked;
            if (checked == true) {
              document.mainForm.describe_cart_genes_1.checked = true;
              document.mainForm.describe_cart_genes.checked = true;
              document.mainForm.cluster_cart_genes.checked = true;
            } else {
              document.mainForm.describe_cart_genes_1.checked = false;
              document.mainForm.describe_cart_genes.checked = false;
              document.mainForm.cluster_cart_genes.checked = false;
            }
        }

        function validateSampleSelection(num, ismin) {
            var startElement = document.getElementById("rnaexps");
            var els = startElement.getElementsByTagName('input');

            var count = 0;
            for (var i = 0; i < els.length; i++) {
                var e = els[i];
                if (e.type == "checkbox" &&
                    e.name == "exp_samples" &&
                    e.checked) {
                    count++;
                }
            }

            if (count < num) {
                var txt = "";
                if (ismin == 1) {
                    txt = " at least";
                }
                if (num == 1) {
                    alert("Please select"+txt+" 1 sample");
                } else {
                    alert("Please select"+txt+" "+num+" samples");
                }
                return false;
            }

            return true;
        }
        </script>
    };

    print qq{
        <script language="JavaScript" type="text/javascript">
        function setSelectedTaxons() {
            var startElement = document.getElementById("rnaexps");
            var els = startElement.getElementsByTagName('input');

            var checks = 0;
            var tx1 = "", tx2 = "";
            for (var i=0; i<els.length; i++) {
                var el = els[i];
                if (el.type == "checkbox" && el.checked) {
                    var value = el.value;
                    try {
                        var tx = document.getElementById('txlink'+value).name;
                        if (checks == 0) tx1 = tx;
                        if (checks >= 1 && tx != tx1) tx2 = tx;
                    } catch(e) {}
                    checks++;
                }

                if (tx1 != "" && tx2 != "") break;
            }

            var bt1 = document.getElementById('expression_summary');
            var bt3 = document.getElementById('cluster');
            var bt4 = document.getElementById('map_clusters');

            var disable = (tx1 != "" && tx2 != "" && tx1 != tx2);
            setBtnStyle(bt1, disable);
            setBtnStyle(bt3, disable);
            setBtnStyle(bt4, disable);
        }

        function setBtnStyle(btn, disable) {
            if (disable) {
                btn.disabled = true;
                btn.style.color = 'gray';
                btn.style.background = 'lightgray';
            } else {
                btn.disabled = false;
                btn.style.color = 'black';
                btn.style.background = 'white';
            }
        }

        function setReference() {
            var ref1 = "Use 1 as reference";
            var ref2 = "Use 2 as reference";

            var tx1 = "", tx2 = "";

            var checks = 0;
            var startElement = document.getElementById("rnaexps");
            var els = startElement.getElementsByTagName('input');

            for (var i=0; i<els.length; i++) {
                var el = els[i];
                if (el.type == "checkbox" && el.checked) {
                    var value = el.value;
                    var ref = document.getElementById('link'+value).innerHTML;
                    if (checks == 0) ref1 = ref;
                    if (checks == 1) ref2 = ref;

                    try {
                        var tx = document.getElementById('txlink'+value).name;
                        if (checks == 0) tx1 = tx;
                        if (checks == 1) tx2 = tx;
                    } catch(e) {}
                    checks++;
                }

                if (checks > 1) break;
            }

            document.getElementById('ref1').innerHTML=ref1;
            document.getElementById('ref2').innerHTML=ref2;

            var bt1 = document.getElementById('anchor1');
            var bt2 = document.getElementById('compare');
            var bt3 = document.getElementById('spearman');
            var bt4 = document.getElementById('regress');

            var disable = (tx1 != "" && tx2 != "" && tx1 != tx2);
            setBtnStyle(bt1, disable);
            setBtnStyle(bt2, disable);
            if (bt3) setBtnStyle(bt3, disable);
            setBtnStyle(bt4, disable);
        }
        </script>
    };

    ######### for preview graph
    print "<script src='$base_url/imgCharts.js'></script>\n";
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
        function initPanel() {
            if (!YAHOO.example.container.panel1) {
                YAHOO.example.container.panel1 = new YAHOO.widget.Panel
                    ("panel1", {
                      visible:false,
                      //fixedcenter:true,
                      dragOnly:true,
                      underlay:"none",
                      zindex:"10",
                      context:['anchor1','bl','tr']
                      } );
                YAHOO.example.container.panel1.render();
                //alert("initPanel");
            }
        }

        function doPreview(url) {
            if (validateSampleSelection(2)) {
                showImage(getURL(url));
            }
        }

        function getURL(url) {
            var startElement = document.getElementById("rnaexps");
            var els = startElement.getElementsByTagName('input');
            var ref = 1;
            var sampleA = "";
            var sampleB = "";
            var normalization = "";

            for (var i=0; i<document.mainForm.elements.length; i++) {
                var el = document.mainForm.elements[i];
                if (el.type == "radio") {
                    if (el.name == "normalization" &&
                        el.checked) {
                        url = url+"&normalization="+el.value;
                    }
                }
            }

            for (var i = 0; i < els.length; i++) {
                var e = els[i];

                if (e.type == "checkbox" &&
                    e.name == "exp_samples" &&
                    e.checked == true) {
                    if (sampleA == null || sampleA.length == 0) {
                        sampleA = e.value;
                    } else {
                        sampleB = e.value;
                        break;
                    }
                }
            }

            var els2 = document.getElementsByName('reference');
            for (var i = 0; i < els2.length; i++) {
                var e = els2[i];
                if (e.type == "radio" &&
                    e.name == "reference" &&
                    e.checked == true) {
                    ref = e.value;
                }
            }
            if (ref == 2) {
                return url+"&sample1="+sampleB+"&sample2="+sampleA;
            }
            return url+"&sample1="+sampleA+"&sample2="+sampleB;
        }
        </script>
    };
}

############################################################################
# printGeneCartFooter - prints the table buttons
############################################################################
sub printGeneCartFooter {
    my ( $name ) = @_;
    my $id0 = "";
    my $id1 = "";
    if ($name ne "") {
	$id0 = "id=$name"."0";
	$id1 = "id=$name"."1";
    }

    print hiddenVar( "from", "rnastudies" );
    my $name = "_section_GeneCartStor_addToGeneCart";
    print submit( -name  => $name,
                  -value => "Add Selections To Gene Cart",
                  -class => "meddefbutton" );
    print nbsp( 1 );
    print "<input $id1 " .
	  "type='button' name='selectAll' value='Select All' " .
          "onClick='selectAllCheckBoxes(1)', class='smbutton' />";
    print nbsp( 1 );
    print "<input $id0 " .
	  "type='button' name='clearAll' value='Clear All' " .
          "onClick='selectAllCheckBoxes(0)' class='smbutton' />";
}

############################################################################
# printDataForSample - prints info for one sample of an experiment
############################################################################
sub printDataForSample {
    my ($configureCols) = @_;
    my $sample = param("sample");
    my $normalization = param("normalization");

    my $dbh = dbLogin();
    printStatusLine("Loading ...", 1);

    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select distinct dts.gold_id, gsp.display_name,
               dts.reference_taxon_oid, tx.taxon_display_name,
               tx.genome_type
        from rnaseq_dataset dts, taxon tx,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.dataset_oid = ?
        and dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = tx.taxon_oid
        $datasetClause
    };
    my $cur = execSql($dbh, $sql, $verbose, $sample);
    my ($gold_id, $sample_desc, $taxon_oid, $taxon_name, $genome_type)
	= $cur->fetchrow();
    $cur->finish();

    if ( $sample_desc eq "" ) {
        printStatusLine( "unauthorized user", 2 );
        printMessage("You do not have permission to view this experiment.");
        return;
    }

    WebUtil::printHeaderWithInfo
	("RNASeq Expression Data", "", "", "", 0, "RNAStudies.pdf");

    if ($genome_type eq "metagenome") {
        my $url1 = "$main_cgi?section=MetaDetail"
	    . "&page=geneCountScaffoldDist"
	    . "&taxon_oid=$taxon_oid&study=$study&sample=$sample";
        print buttonUrl( $url1, "Scaffolds by Gene Count", "smbutton" );
        print nbsp(1);
        my $url2 = "$main_cgi?section=MetaDetail"
	    . "&page=seqLengthScaffoldDist"
	    . "&taxon_oid=$taxon_oid&study=$study&sample=$sample";
        print buttonUrl( $url2, "Scaffolds by Sequence Length", "smbutton" );

        #$url = "$main_cgi?section=MetaDetail&page=scaffolds"
        #. "&taxon_oid=$taxon_oid"
        #. "&study=$study&sample=@sample_oids[0]";

    } else {
        my $url = "$main_cgi?section=TaxonDetail&page=scaffolds"
          . "&taxon_oid=$taxon_oid&study=$study&sample=$sample";
        print buttonUrl( $url, "Chromosome Viewer", "smbutton" );
    }
    print "<br/>";

    my $url = "$main_cgi?section=TaxonDetail"
      . "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p><u>Sample</u>: $sample_desc";
    if ( !blankStr($gold_id) ) {
        my $url = HtmlUtil::getGoldUrl($gold_id);
	print " [".alink($url, $gold_id, "_blank")."]";
    }
    print "<br/><u>Genome</u>: " . alink( $url, $taxon_name, "_blank" );
    print "</p>\n";

    printMainForm();

    my $it = new InnerTable( 1, "rnasampledata$$", "rnasampledata", 5 );
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID",            "asc",  "right" );
    $it->addColSpec( "Locus Tag",          "asc",  "left" );
    $it->addColSpec( "Product Name",       "asc",  "left" );
    $it->addColSpec( "DNA Seq<br/>Length", "desc", "right" );
    $it->addColSpec( "Reads<br/>Count",    "desc", "right" );
    $it->addColSpec( "Normalized Coverage<sup>1</sup><br/> * 10<sup>9</sup>",
		     "desc", "right" );

    # for gene table configuration:
    my $fixedColIDs;    # = "gene_oid,locus_tag,desc,dna_seq_length,";
    my $colIDs = GeneTableConfiguration::readColIdFile($study);
    #my @fixedCols = WebUtil::processParamValue($fixedColIDs);
    #foreach my $c (@fixedCols) {
    #    $colIDs  =~ s/$c//i;
    #}
    my @outCols = WebUtil::processParamValue($colIDs);
    if ( $configureCols ne "" ) {
        my $outputCol_ref =
	    GeneTableConfiguration::getOutputCols($fixedColIDs, $study);
        @outCols = @$outputCol_ref;
    }
    GeneTableConfiguration::addColIDs($it, \@outCols);

    my $count = 0;
    my $trunc = 0;

    # reads and genes are now in sdb
    my ($total_gene_cnt, $total_read_cnt) =
	MetaUtil::getCountsForRNASeqSample( $sample, $taxon_oid );

    if ($total_gene_cnt > 0) { # found
        my %gene2info =
	    MetaUtil::getGenesForRNASeqSample( $sample, $taxon_oid );
        my @genes = keys %gene2info;

        my %recs;
        if ($configureCols ne "" || scalar @outCols > 0) {
            my $recs_href =
		GeneTableConfiguration::getOutputColValues
		($fixedColIDs, $study, \@genes, $taxon_oid, "assembled");
            %recs = %$recs_href;
        }

        my %prodNames;
        if ($genome_type eq "metagenome") {
            %prodNames =
		MetaUtil::getGeneProdNamesForTaxon($taxon_oid, "assembled");
        } else {
            my $gene2prod = getGeneProductNames($dbh, $taxon_oid, \@genes);
            %prodNames = %$gene2prod;
        }

        foreach my $gene (keys %gene2info) {
            last if $trunc;

            my $line = $gene2info{$gene};

            # each line is in tab-delimited format:
            # gene_oid locus_type locus_tag strand scaffold_oid
            # length reads_cnt mean median stdev reads_cnta meana
            # mediana stdeva exp_id sample_oid
            my ($geneid, $locus_type, $locus_tag, $strand,
                $scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
		= split( "\t", $line );
            #next if $readsCount == 0;

            my $product = $prodNames{$gene};
            $product = "hypothetical protein" if $product eq "";

            my $coverage = "0";
            if ($dna_seq_length > 0 && $total_read_cnt > 0) {
                $coverage = ($reads_cnt / $dna_seq_length / $total_read_cnt);
            }

            my $url1 = "$main_cgi?section=GeneDetail"
		. "&page=geneDetail&gene_oid=$gene";
            my $genelink = $gene;
            if ($genome_type eq "metagenome") {
                $url1 = "$main_cgi?section=MetaGeneDetail"
		    . "&page=metaGeneDetail&gene_oid=$gene"
		    . "&data_type=assembled&taxon_oid=$taxon_oid";
                $genelink = "$taxon_oid assembled $gene";
            }

            my $row = $sd . "<input type='checkbox' "
		. "name='gene_oid' value='$genelink'/>\t";
            $row .= $gene . $sd . alink( $url1, $gene, "_blank" ) . "\t";
            $row .= $locus_tag . "\t";
            $row .= $product . "\t";
            $row .= $dna_seq_length . "\t";
            $row .= $reads_cnt . $sd . "\t";
            $row .= sprintf( "%.3f", $coverage * 10**9 ) . "\t";

            if ($configureCols ne "" || scalar @outCols > 0) {
                my $data_type = "assembled";
                my $gene_oid;
                if (WebUtil::isInt($gene)) {
                    $data_type = "database";
                    $gene_oid  = $gene;
                } else {
                    #my @vals = split(/ /, $gene);
                    $data_type = "assembled";
                    $gene_oid  = "$taxon_oid assembled $gene";
                }

                my (@outColVals) = split( "\t", $recs{$gene_oid} );
                $row = GeneTableConfiguration::addCols2Row
                    ($gene, $data_type, $taxon_oid, "",    #$scaffold_oid,
		     $row, $sd, \@outCols, \@outColVals);
            }

            $it->addRow($row);

            $count++;
            if ($count >= $maxGeneListResults) {
                $trunc = 1;
                last;
            }
        }

    } else {
        # anna: genes and reads should come from sdb
        # anna: will remove when rnaseq_expression is cleaned out
        my $sql = qq{
            select sum(es.reads_cnt)
            from rnaseq_expression es
            where es.dataset_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $sample );
        my ($total) = $cur->fetchrow();
        $cur->finish();

        if ( !$total || $total == 0 ) {
            printStatusLine( "no data", 2 );
            webError("No data was found for dataset $sample.");
        }

        my $sql = qq{
            select distinct es.IMG_gene_oid, g.gene_display_name,
                   g.locus_tag, g.product_name,
                   g.DNA_seq_length, es.reads_cnt,
                   round(es.reads_cnt/g.DNA_seq_length/$total, 12)
            from rnaseq_expression es, gene g
            where es.dataset_oid = ?
            and es.reads_cnt > 0.0000000
            and g.gene_oid = es.IMG_gene_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose, $sample );

        my @rowRecs;
        my @genes;
        for ( ;; ) {
            my ($gene, $gene_name, $locus_tag, $product,
                $dna_seq_length, $readsCount, $coverage)
		= $cur->fetchrow();
            last if !$gene;
            push @genes, $gene;
            my $r = $gene."\t".$gene_name."\t".$locus_tag."\t".$product."\t";
            $r .= $dna_seq_length . "\t" . $readsCount . "\t" . $coverage;
            push @rowRecs, $r;
        }

        my %recs;
        if ($configureCols ne "" || scalar @outCols > 0) {
            my $recs_href =
		GeneTableConfiguration::getOutputColValues
		($fixedColIDs, $study, \@genes);
            %recs = %$recs_href;
        }

        foreach my $item (@rowRecs) {
            my ($gene, $gene_name, $locus_tag, $product,
                $dna_seq_length, $readsCount, $coverage)
		= split( "\t", $item );

            my $url1 = "$main_cgi?section=GeneDetail"
		. "&page=geneDetail&gene_oid=$gene";
            $product = "hypothetical protein" if $product eq "";

            my $row;
            my $row = $sd . "<input type='checkbox' "
		. "name='gene_oid' value='$gene'/>\t";
            $row .= $gene . $sd . alink( $url1, $gene, "_blank" ) . "\t";
            $row .= $locus_tag . "\t";
            $row .= $product . "\t";
            $row .= $dna_seq_length . "\t";
            $row .= $readsCount . $sd . "\t";
            $row .= sprintf("%.3f", $coverage * 10**9) . "\t";

            if ($configureCols ne "" || scalar @outCols > 0) {
                my (@outColVals) = split("\t", $recs{$gene});
                $row = GeneTableConfiguration::addCols2Row
                    ($gene, "database", $taxon_oid, "",    #$scaffold_oid,
		     $row, $sd, \@outCols, \@outColVals);
            }

            $it->addRow($row);
            $count++;
        }
        $cur->finish();
    }

    printGeneCartFooter();
    $it->printOuterTable(1);
    printGeneCartFooter();

    my $colIDs = $fixedColIDs;
    foreach my $col (@outCols) {
        $colIDs .= "$col,";
    }
    GeneTableConfiguration::writeColIdFile($colIDs, $study);

    ## Table Configuration
    print hiddenVar("sample", $sample);
    print hiddenVar("normalization", $normalization);

    use GeneTableConfiguration;
    my %outputColHash = WebUtil::array2Hash(@outCols);
    my $name = "_section_${section}_setGeneOutputCol";
    GeneTableConfiguration::appendGeneTableConfiguration
	(\%outputColHash, $name);

    print end_form();
    printNotes("samplegenes");

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink( $preferences_url, "Preferences" )
	    . " to change \"Max. Gene List Results\". )\n";
        printStatusLine( $s, 2 );
    } else {
        printStatusLine( "$count genes loaded.", 2 );
    }
}

############################################################################
# normalizeData - normalizes data for samples of an experiment
############################################################################
sub normalizeData {
    my ($sampleIds_ref, $profiles_ref, $geneIds_ref, $normalization) = @_;
    my @sample_oids = @$sampleIds_ref;
    my %sampleProfiles = %$profiles_ref;
    my @gene_oids = @$geneIds_ref;

    my $tmpInputFile = "$tmp_dir/R_input$$.txt";
    my $tmpOutputFile = "$tmp_dir/R_output$$.txt";

    my $wfh = newWriteFileHandle( $tmpInputFile, "doNormalization" );
    my $s = "gene_oid\t";
    foreach my $i( @sample_oids ) {
        $s .= "$i\t";
    }
    chop $s;
    print $wfh "$s\n";

    GENE: foreach my $gene( @gene_oids ) {
	print $wfh "$gene";

        foreach my $sid (@sample_oids) {
            my $profile = $sampleProfiles{ $sid };
            my $coverage = $profile->{ $gene };

            if ($coverage eq "") {
                $coverage = 0;
	    }
	    print $wfh "\t$coverage";
	}
	print $wfh "\n";
    }

    my $program = "$cgi_dir/bin/quantileNorm.R";
    if ($normalization eq "affine") {
        $program = "$cgi_dir/bin/affineNorm.R";
    }

    WebUtil::unsetEnvPath();
    #my $environ = "PATH='/bin:/usr/bin'; export PATH";
    my $cmd = "$R --slave --args "
	    . "'$tmpInputFile' '$tmpOutputFile' < $program > /dev/null";
    webLog("+ $cmd\n");
    my $st = system($cmd);
    WebUtil::resetEnvPath();

    if ($st != 0) {
        webError( "Problem running R script: $program." );
    }
    my $rfh = newReadFileHandle
        ( $tmpOutputFile, "readNormalizationResults" );

    my @allSamples; # order should be the same as @sample_oids
    my %normData;
    my $count1 = 0;

    while( my $s = $rfh->getline() ) {
	chomp $s;
	$count1++;
	if ($count1 == 1) {
	    @allSamples = split( /,/, $s );
	    splice(@allSamples, 0, 1); # starts with the 2nd element
	}

	next if $count1 < 2;
	my( $gid, $values ) = split( /,/, $s, 2 );
        # values are ordered by the allSamples
	$normData{ $gid } = $values;
    }
    close $rfh;

    return \%normData;
}

############################################################################
# printNotes - print footnotes for tables
############################################################################
sub printNotes {
    my ( $which_page ) = @_;

    my $coverage =
	"After each experiment, reads are generated for each gene.<br/>"
	. nbsp(3)
	. "<u>Coverage</u> for a gene is defined as the count of "
	. "these reads divided by the size of the gene.\n";
    my $normCoverage =
	"<u>Normalized Coverage</u> is the coverage for a gene "
	. "in the given experiment divided by the <br/>"
	. nbsp(3)
	. "total number of reads in that experiment.\n";
    my $normQuantile;
    my $normAffine;

    print "<br/>";
    print "<b>Notes</b>:<br/>\n";
    print "<p>\n";
    if ($which_page eq "studysamples") {
	print "1 - <u>Normalization Methods</u>:";
	print "<br/>For additional information see: ";
	my $url = "http://www.biomedcentral.com/1471-2105/11/94";
	print alink($url, "Quantile", "_blank") . ", ";
	$url = "http://www.ncbi.nlm.nih.gov/pmc/articles/PMC1534066/";
	print alink($url, "Affine", "_blank") . ", ";
	#$url = "http://www.clcbio.com/manual/genomics/Definition_RPKM.html";
	$url = "http://www.nature.com/nmeth/journal/v5/n7/full/nmeth.1226.html";
	print alink($url, "RPKM", "_blank") . ", ";
	$url = "http://rss.acs.unt.edu/Rdoc/library/aroma/html/Calibration_and_Normalization.html";
	print alink($url, "R doc", "_blank");

    } else {
	print "1 - ";
	print $coverage;
	print "<br/>\n";
	print nbsp(3);
	print $normCoverage;
    }
    print "</p>\n";
}

############################################################################
# printStudiesForGenome - prints all studies that use a given genome
############################################################################
sub printStudiesForGenome {
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    my ($taxon_name, $in_file, $genome_type)
        = QueryUtil::fetchSingleTaxonNameGenomeType( $dbh, $taxon_oid );

    my $url = "$main_cgi?section=TaxonDetail"
	    . "&page=taxonDetail&taxon_oid=$taxon_oid";
    WebUtil::printHeaderWithInfo
        ("RNASeq Expression Studies", "", "", "", 0, "RNAStudies.pdf");
    print "<p style='width: 650px;'>";
    print "<u>Ref. Data Set</u>: ".alink($url, $taxon_name)."</p>\n";


    printStartWorkingDiv();

    my %sample2counts;
    my $datasetClause = datasetClause("dts");
    # use rnaseq_dataset_stats table:
    print "<p>Querying for gene counts for datasets from rnaseq_dataset_stats";
    my $sql = qq{
        select dts.dataset_oid,
        dts.gene_count, dts.total_reads_count, dts.avg_reads_count
        from rnaseq_dataset rd, rnaseq_dataset_stats dts
        where rd.reference_taxon_oid = ?
        and dts.dataset_oid = rd.dataset_oid
        $datasetClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ;; ) {
	my ($dataset_oid, $geneCount, $totalReads, $avgReads)
	    = $cur->fetchrow();
	last if !$dataset_oid;
	my $rec = "$dataset_oid\t$geneCount\t$totalReads\t$avgReads";
	$sample2counts{ $dataset_oid } = $rec;
    }
    $cur->finish();

    if (0) { # not needed now:
    print "<br/>Querying SDB for counts TX:$taxon_oid";
    my %s2cnt = MetaUtil::getRNASeqSampleCountsForTaxon($taxon_oid, "", 1);
    @sample2counts{ keys %s2cnt } = values %s2cnt;
    if (keys %s2cnt < 1) {
	# anna: will remove when rnaseq_expression is cleaned out
	print "<br/>querying Oracle DB for counts";
        my $sql = qq{
            select dts.dataset_oid,
            count(distinct es.IMG_gene_oid),
            sum(es.reads_cnt), round(avg(es.reads_cnt), 2)
            from rnaseq_dataset dts, rnaseq_expression es
            where dts.reference_taxon_oid = ?
            and dts.dataset_oid = es.dataset_oid
            $datasetClause
            group by dts.dataset_oid
            order by dts.dataset_oid
        };

        $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ;; ) {
            my ($sample, $geneCount, $totalReads, $avgReads)
                = $cur->fetchrow();
            last if !$sample;
            my $rec = "$sample\t$geneCount\t$totalReads\t$avgReads";
            $sample2counts{ $sample } = $rec;
        }
    }
    }

    print "<br/>querying GOLD for proposal";
    my $sql = qq{
        select distinct gs.study_name, dts.gold_id,
               gsp.display_name, dts.dataset_oid
        from rnaseq_dataset dts, taxon tx, gold_study\@imgsg_dev gs,
             gold_sp_study_gold_id\@imgsg_dev gssg,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.gold_id = gssg.gold_id
        and gssg.study_gold_id = gs.gold_id
        and dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = ?
        $datasetClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    printEndWorkingDiv();

    setLinkTarget("_blank");
    printMainForm();
    printRNASeqJavascript();

    use TabHTML;
    TabHTML::printTabAPILinks("experimentsTab", 1);
    print qq{
        <script type='text/javascript'>
        var tabview1 = new YAHOO.widget.TabView("experimentsTab");
        </script>
    };

    my @tabIndex = ( "#exptab1" );
    my @tabNames = ( "Select Samples" );
    my $idx = 2;
    if ($genome_type ne "metagenome") {
        push @tabIndex, "#exptab".$idx++;
        push @tabNames, "View in GBrowse";
    }
    push @tabIndex, "#exptab".$idx++;
    push @tabIndex, "#exptab".$idx++;
    push @tabIndex, "#exptab".$idx++;

    push @tabNames, "Single Sample Analysis";
    push @tabNames, "Pairwise Sample Analysis";
    push @tabNames, "Multiple Sample Analysis";

    TabHTML::printTabDiv("experimentsTab", \@tabIndex, \@tabNames);
    print "<div id='exptab1'>";

    printNormalizationInfo();

    # rnaexps is used as id to locate element in script:
    my $it = new InnerTable(1, "rnaexps$$", "rnaexps", 3);
    $it->hideAll();

    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "GOLD ID", "asc", "right" );
    $it->addColSpec( "Data Set Name", "asc", "left" );
    $it->addColSpec( "Data Set ID", "asc", "right" );
    $it->addColSpec( "Study Name (Proposal Name)", "asc", "left" );
    $it->addColSpec( "Genes<br/>with Reads", "desc", "right" );
    $it->addColSpec( "Total Reads<br/>Count", "desc", "right" );
    $it->addColSpec( "Average Reads<br/>per Gene", "desc", "right" );

    my $count = 0;
    for ( ;; ) {
        my ($project, $gold_id, $desc, $dataset_oid) = $cur->fetchrow();
        last if !$project;

        my $row = $sd."<input type='checkbox' "
                . "name='exp_samples' value='$dataset_oid'/>\t";
        if (!blankStr($gold_id)) {
            my $url = HtmlUtil::getGoldUrl($gold_id);
            $row .= $gold_id.$sd
                . alink($url, $gold_id, "_blank")."\t";
        } else {
            $row .= $gold_id."\t";
        }
        my $url = "$section_cgi&page=sampledata&sample=$dataset_oid";
        $row .= $desc.$sd
              . "<a href='$url' id='link$dataset_oid' target='_blank'>"
              . $desc."</a>"."\t";

        $row .= $dataset_oid."\t";
        $row .= $project."\t";

        if (%sample2counts && $sample2counts{ $dataset_oid } ne "") {
	    my $item = $sample2counts{ $dataset_oid };
	    my ($sample_oid, $geneCount, $readsCount, $avgReads)
		= split("\t", $item);
	    $row .= $geneCount."\t";
	    $row .= $readsCount."\t";
	    $row .= $avgReads."\t";
	} else {
	    $row .= "\t";
	    $row .= "\t";
	    $row .= "\t";
	}

        $it->addRow($row);
	$count++;
    }
    $cur->finish();

    if ($count > 10) {
        print "<input type=button name='selectAll' value='Select All' "
            . "onClick='selectAllByName(\"exp_samples\", 1)' "
            . "class='smbutton' />\n";
        print nbsp( 1 );
        print "<input type='button' name='clearAll' value='Clear All' "
            . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";
    }

    $it->printOuterTable(1);
    print "<input type=button name='selectAll' value='Select All' "
        . "onClick='selectAllByName(\"exp_samples\", 1)' "
        . "class='smbutton' />\n";
    print nbsp( 1 );
    print "<input type='button' name='clearAll' value='Clear All' "
        . "onClick='selectAllCheckBoxes(0)' class='smbutton' />\n";

    printNotes("studysamples");
    print "</div>"; # end exptab1

    my $idx = 2;
    if ($genome_type ne "metagenome") {
        my $tab = "exptab".$idx++;
        print "<div id='$tab'>";
        # Link to GBrowse:
	my $gbrowse_base_url = $env->{ gbrowse_base_url };
	my $gbrowseUrl = $gbrowse_base_url."gb2/gbrowse/";
	# need to encode the taxon_oid for security:
	my $tx = encode($taxon_oid);
	#print "<br/>> encoded tx: $tx"; ## anna for configuring gbrowse
	$gbrowseUrl .= $tx;

	print qq{
        <p><a href=$gbrowseUrl target="_blank">
        <img src="$base_url/images/GBrowse-win.jpg" width="320" height="217" border="0" style="border:2px #99CCFF solid;" alt="View in GBrowse" title="View gene coverage for samples in GBrowse"/>
        </a>
        <br/><a href=$gbrowseUrl target="_blank">View in GBrowse
        </a></p>
        };
	print "</div>"; # end exptab2
    }

    my $tab = "exptab".$idx++;
    print "<div id='$tab'>";

    print hiddenVar( "section",     $section );
    print hiddenVar( "study",       $study );
    print hiddenVar( "taxon_oid",   $taxon_oid );
    print hiddenVar( "genome_type", $genome_type );

    printDescribeOneTab($taxon_oid, $in_file, $genome_type);
    print "</div>"; # end exptab3

    if ($count < 2) {
	TabHTML::printTabDivEnd();
        print end_form();
        printStatusLine("$count sample(s) loaded.", 2);
        return;
    }

    $tab = "exptab".$idx++;
    print "<div id='$tab'>";
    printPairwiseTab($taxon_oid, $in_file, $genome_type);
    print "</div>"; # end exptab4

    $tab = "exptab".$idx++;
    print "<div id='$tab'>";
    print printDescribeMultiTab($taxon_oid, $count);
    print "</div>"; # end exptab5

    TabHTML::printTabDivEnd();

    print qq{
        <script type='text/javascript'>
        tabview1.addListener("activeTabChange", function(e) {
            if (e.newValue.get('label') == "Pairwise Sample Analysis") {
                setReference();
            }
        });
        </script>
    };

    print end_form;
    printStatusLine("$count sample(s) loaded.", 2);
}

sub printNormalizationInfo {
    # Normalization:
    my $urlq = "http://www.biomedcentral.com/1471-2105/11/94";
    my $urla = "http://www.ncbi.nlm.nih.gov/pmc/articles/PMC1534066/";
    my $urlr = "http://www.clcbio.com/manual/genomics/Definition_RPKM.html";
    $urlr = "http://www.nature.com/nmeth/journal/v5/n7/full/nmeth.1226.html";
    $urlr = "https://wiki.nci.nih.gov/pages/viewpage.action?pageId=71439191";
    printHint
        ( "<span style='font-style: normal;'>"
        . "You may change the "
        . "<font color='blue'><u>Normalization Method</u></font> "
        . "used to compute abundances of the genes in any given sample: "
        . "<input type='radio' name='normalization' value='quantile' />\n"
        . alink($urlq, "Quantile", "_blank")
        . "<input type='radio' name='normalization' value='affine' />\n"
        . alink($urla, "Affine", "_blank")
        . "<input type='radio' name='normalization' value='coverage' "
        . "checked='checked' />\n"
        . alink($urlr, "RPKM", "_blank")
        . " (Reads Per Kilobase of gene)</span>"
    );
    print "<br/>";
}

############################################################################
# printInfoForGene - links gene page to rnaseq expression data;
#        displays the experimental samples in which the given
#        gene was expressed and its reads count in that sample
############################################################################
sub printInfoForGene {
    my $gene_oid = param("gene_oid");
    my $taxon_oid = param("taxon_oid");

    my $dbh = dbLogin();
    my $sql = qq{
      select distinct tx.taxon_display_name, tx.in_file, tx.genome_type
      from taxon tx
      where tx.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($taxon_name, $in_file, $genome_type) = $cur->fetchrow();

    print "<h1>RNASeq Data for Gene</h1>\n";

    my %sample2reads;

    if ($genome_type eq "metagenome") {
	my %prodNames = MetaUtil::getGeneProdNamesForTaxon
	    ($taxon_oid, "assembled");
	my $product_name = $prodNames{ $gene_oid };
	$product_name = "hypothetical protein" if $product_name eq "";

	my $url = "$main_cgi?section=MetaGeneDetail"
	        . "&page=metaGeneDetail&gene_oid=$gene_oid"
		. "&data_type=assembled&taxon_oid=$taxon_oid";

	print "<pre>\n";
	print "<font color='blue'>";
	print ">Gene: ".alink($url, $gene_oid, "_blank")
	    ." $product_name";
	#." $product_name <br/> [$scaffold_name]";
	print "</font>\n";
	print "</pre>\n";

    } else {
	my $sql2 = qq{
            select g.gene_oid, g.gene_display_name, scf.scaffold_name
            from  gene g, scaffold scf
            where g.gene_oid = ?
            and g.scaffold = scf.scaffold_oid
        };

	my $url = "$main_cgi?section=GeneDetail"
	        . "&page=geneDetail&gene_oid=";
	my $cur = execSql( $dbh, $sql2, $verbose, $gene_oid );
	for( ;; ) {
	    my( $gene_oid, $gene_display_name, $scaffold_name )
		= $cur->fetchrow();
	    last if !$gene_oid;

	    print "<pre>\n";
	    print "<font color='blue'>";
	    print ">Gene: ".alink($url.$gene_oid, $gene_oid, "_blank")
		." $gene_display_name <br/> [$scaffold_name]";
	    print "</font>\n";
	    print "</pre>\n";
	}

	# rnaseq gene and reads info should be in sdb
	# anna: will remove when rnaseq_expression is cleaned out
	my $sql3 = qq{
            select dts.dataset_oid, es.reads_cnt
            from rnaseq_dataset dts, rnaseq_expression es
            where es.dataset_oid = dts.dataset_oid
            and es.IMG_gene_oid = ?
            and es.reads_cnt > 0.0000000
            order by dts.dataset_oid
        };
	my $cur = execSql( $dbh, $sql3, $verbose, $gene_oid );
	for ( ;; ) {
	    my ($sample, $readsCount) = $cur->fetchrow();
	    last if !$sample;
	    $sample2reads{ $sample } = $readsCount;
	}
    }

    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select distinct dts.dataset_oid, dts.gold_id, gsp.display_name
        from rnaseq_dataset dts,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = ?
        $datasetClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable(1, "rnaseqgenedata$$", "rnaseqgenedata", 0);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Data Set ID", "asc", "right" );
    $it->addColSpec( "Data Set Name", "asc", "left" );
    $it->addColSpec( "GOLD ID", "asc", "right" );
    $it->addColSpec( "Reads Count", "desc", "right" );

    my $count = 0;
    for ( ;; ) {
        my ($dt_oid, $gold_id, $sample_desc) = $cur->fetchrow();
        last if !$dt_oid;

	$count++;
	my ($geneid, $locus_type, $locus_tag, $strand,
	    $scaffold_oid, $dna_seq_length, $reads_cnt)
	    = MetaUtil::getGeneInRNASeqSample($gene_oid, $dt_oid, $taxon_oid);
	my $readsCount = $reads_cnt;

	if ($readsCount == 0) {
	    $readsCount = $sample2reads{ $dt_oid };
	    next if $readsCount == 0 || $readsCount eq "";
	}

        my $row;
        $row .= $dt_oid."\t";
        my $url1 = "$section_cgi&page=sampledata&sample=$dt_oid";
        $row .= $sample_desc.$sd.alink($url1, $sample_desc, "_blank")."\t";
        if (!blankStr($gold_id)) {
            my $url = HtmlUtil::getGoldUrl($gold_id);
            $row .= $gold_id.$sd
                . alink($url, $gold_id, "_blank")."\t";
        } else {
            $row .= $gold_id."\t";
        }
        $row .= $readsCount."\t";
        $it->addRow($row);
    }
    $cur->finish();

    $it->printOuterTable(1);
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
        select distinct tx.in_file, tx.genome_type
        from taxon tx
        where tx.taxon_oid = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my ($in_file, $genome_type) = $cur->fetchrow();

    my %s2cnt = MetaUtil::getRNASeqSampleCountsForTaxon($taxon_oid);
    if (scalar keys %s2cnt < 1) {
	# anna: will remove when rnaseq_expression is cleaned out
	my $sql = qq{
            select dts.dataset_oid,
	           count(distinct es.IMG_gene_oid),
	           sum(es.reads_cnt), round(avg(es.reads_cnt), 2)
   	      from rnaseq_dataset dts, rnaseq_expression es
             where dts.reference_taxon_oid = ?
	       and dts.dataset_oid = es.dataset_oid
          group by dts.dataset_oid
          order by dts.dataset_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
	for ( ;; ) {
	    my ($sample, $geneCount, $readsCount, $avgReads)
		= $cur->fetchrow();
	    last if !$sample;
	    $s2cnt{ $sample } =
		$sample."\t".$geneCount."\t".$readsCount."\t".$avgReads;
	}
    }

    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select distinct dts.dataset_oid, dts.gold_id, gsp.display_name
        from rnaseq_dataset dts,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = ?
        $datasetClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );

    my $it = new InnerTable(1, "rnaexps$$", "rnaexps", 1);
    $it->{pageSize} = 10;
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Choose" );
    $it->addColSpec( "Data Set ID", "asc", "right" );
    $it->addColSpec( "Data Set Name","asc", "left" );
    $it->addColSpec( "GOLD ID", "asc", "right" );
    $it->addColSpec( "Genes<br/>with Reads", "desc", "right" );
    $it->addColSpec( "Total Reads<br/>Count", "desc", "right" );
    $it->addColSpec( "Average Reads<br/>per Gene", "desc", "right" );

    my $count;
    for ( ;; ) {
        my ($sample, $gold_id, $desc) = $cur->fetchrow();
        last if !$sample;

	my $item = $s2cnt{ $sample };
	my ($sample_oid, $geneCount, $readsCount, $avgReads)
	    = split("\t", $item);
	my $url = "$section_cgi&page=sampledata&sample=$sample";

        my $row;
        my $row = $sd."<input type='radio' "
                . "onclick='setStudy(\"$study\")' "
	        . "name='exp_samples' value='$sample'/>\t";
        $row .= $sample."\t";
        $row .= $desc.$sd.alink($url, $desc, "_blank")."\t";
        $row .= $gold_id."\t";
        $row .= $geneCount."\t";
        $row .= $readsCount."\t";
        $row .= $avgReads."\t";
        $it->addRow($row);
        $count++;
    }
    $cur->finish();
    $it->printOuterTable(1);
    #$dbh->disconnect();
}

############################################################################
# doSpearman - run the spearman rank correlation
# Note: WIG files are not computed for metagenomes at this time
############################################################################
sub doSpearman {
    my @sample_oids = param("exp_samples");
    my $nSamples = @sample_oids;
    my $sample1 = @sample_oids[0];
    my $sample2 = @sample_oids[1];
    my $proposal = param("proposal");
    my $taxon_oid = param("taxon_oid");

    webLog "SPEARMAN: $sample1 $sample2 $taxon_oid";

    if ($nSamples < 2) {
        webError( "Please select 2 samples." );
    }

    printStartWorkingDiv();

    my $dbh = dbLogin();
    my $sample_oid_str = $sample1.",".$sample2;
    if ($taxon_oid eq "") {
        my $sql = qq{
            select distinct dts.reference_taxon_oid
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = tx.taxon_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        ( $taxon_oid ) = $cur->fetchrow();
        $cur->finish();
    }

    my $program = "$cgi_dir/spearman.pl";
    # /global/dna/projectdirs/microbial/omics-rnaseq/
    # /global/projectb/sandbox/IMG_web/img_web_data/Transcriptomics/
    my $baseDir = '/webfs/scratch/img/Transcriptomics/';

    my $wig_dir = $baseDir .$taxon_oid."/wig/";
    my $gff_dir = $baseDir .$taxon_oid."/gff/";

    my $gff_file = $gff_dir.$taxon_oid.".gbk.gff";
    my $tmp_out_file = "$tmp_dir/R_spearman_output$$.txt";

    my $wig_dir_directional = $wig_dir."directional_lib/";
    my $wig_dir_nodirectional = $wig_dir."no_directional_lib/";

    # check if there are directional libs
    my $is_directional = 1;
    my $wig_dir0 = $wig_dir_directional;

    opendir(my $DH, $wig_dir0);
    if (scalar(grep( !/^\.\.?$/, readdir($DH) )) == 0) {
	$is_directional = 2;
	$wig_dir0 = $wig_dir_nodirectional;
    }
    closedir($DH);

    print "Computing spearman correlation...<br/>";

    # check if the file exists: if (!(-e $filename)) ...
    if (!(-e $gff_file) || !(-e $wig_dir0)) {
	printEndWorkingDiv();
	if (!(-e $gff_file)) {
	    print "$gff_file";
	}
	if (!(-e $wig_dir0)) {
	    print "<br/>$wig_dir0";
	}
	webError( "Could not find the necessary files for $taxon_oid" );
    }

    # to prevent Perl -Taint error
    $gff_file  = checkPath($gff_file);
    $wig_dir0  = checkPath($wig_dir0);
    $sample1   = checkPath($sample1);
    $sample2   = checkPath($sample2);
    $tmp_out_file = checkPath($tmp_out_file);

    WebUtil::unsetEnvPath();

    my $cmd = "$cgi_dir/spearman.pl "
            . "--gff      $gff_file "
            . "--dir      $is_directional "
            . "--wigdir   $wig_dir0 "        # i.e. the genome's wig directory
            . "--sampleA  $sample1 "
            . "--sampleB  $sample2 "
            . "--out      $tmp_out_file ";
    my $perl_bin = $env->{ perl_bin };
    my $st = runCmdNoExit("$perl_bin -I `pwd`  $cmd");

    webLog("\nSPEARMAN: + $cmd\n");
    WebUtil::resetEnvPath();
    print "Done computing spearman.<br/>";
    printEndWorkingDiv();

    WebUtil::printHeaderWithInfo
      ("Spearman's Rank Correlation", "", "", "", 0, "RNAStudies.pdf#page=9");

    if ($proposal ne "") {
	print "<span style='font-size: 12px; "
	    . "font-family: Arial, Helvetica, sans-serif;'>\n";
        my $expurl = "$section_cgi&page=samplesByProposal"
                   . "&proposal=$proposal&genomes=1";
        print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
	print "</span>\n";
    }

    if (!(-e $tmp_out_file)) {
	webError( "Cannot find the output file." );
    }
    my $rfh = newReadFileHandle( $tmp_out_file, "doSpearman" );
    my $count = 0;
    my @allGenes;
    my @allValues;
    my %spearman_data;

    while( my $s = $rfh->getline() ) {
        chomp $s;
        $count++;
        if ($count == 1) {
            # chrGff gene geneOID strandG type len SPEARMAN
            my @column_names = split( /\t/, $s );
            #splice(@column_names, 0, 4); # starts with the 4th element
        }

        next if $count < 2;
        my( $chrGff, $locus, $gid, $strand, $type, $len, $value )
            = split( /\t/, $s, 7 );
        push( @allGenes, $gid );
	push( @allValues, $value );
        $spearman_data{ $gid } = $value;
    }
    close $rfh;

    my $names_ref = getNamesForSamples($dbh, $sample_oid_str);
    my %sampleNames = %$names_ref;

    my $surl = "$section_cgi&page=sampledata&sample=";
    print "<p>\n";
    print "Samples compared:<br/>";
    print alink($surl.$sample1, $sampleNames{$sample1}, "_blank");
    print "<br/>";
    print alink($surl.$sample2, $sampleNames{$sample2}, "_blank");
    print "</p>\n";

    my %gene2info1 = MetaUtil::getGenesForRNASeqSample($sample1, $taxon_oid);
    my %gene2info2 = MetaUtil::getGenesForRNASeqSample($sample2, $taxon_oid);
    my %gene2info = (%gene2info1, %gene2info2);

    # anna: will remove when rnaseq_expression is cleaned out
    my $sql = qq{
        select distinct es.IMG_gene_oid,
            g.gene_display_name,
            g.locus_tag, g.product_name,
            g.DNA_seq_length
        from rnaseq_expression es, gene g
        where es.dataset_oid in ($sample_oid_str)
        and es.IMG_gene_oid = g.gene_oid
        order by es.IMG_gene_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    my %geneProfile;
    for( ;; ) {
        my( $gid, $gene_name, $locus_tag, $product,
            $dna_seq_length ) = $cur->fetchrow();
        last if !$gid;
        $geneProfile{ $gid } =
            "$gene_name\t$locus_tag\t$product\t$dna_seq_length";
    }
    $cur->finish();

    use TabHTML;
    TabHTML::printTabAPILinks("spearmanTab");
    my @tabIndex = ( "#spearmantab1", "#spearmantab2" );
    my @tabNames = ( "Spearman's Coefficient", "Graph" );
    TabHTML::printTabDiv("spearmanTab", \@tabIndex, \@tabNames);

    print "<div id='spearmantab1'><p>";
    printMainForm();
    my $it = new InnerTable(1, "spearman$$", "spearman", 4);
    my $sd = $it->getSdDelim();
    $it->{ pageSize } = "25";
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left" );
    $it->addColSpec( "Product Name", "asc", "left" );
    $it->addColSpec( "Spearman's Rho", "desc", "right", "", "", "wrap" );

    my $count;
    foreach my $gene( @allGenes ) {
	my $url1 = "$main_cgi?section=GeneDetail"
                 . "&page=geneDetail&gene_oid=$gene";

	my $row;
	my $row = $sd."<input type='checkbox' "
	    . "name='gene_oid' value='$gene'/>\t";
	$row .= $gene.$sd.alink($url1, $gene, "_blank")."\t";

	if (exists($geneProfile{$gene})) {
	    my ($name, $locus, $product, $dna_seq_length)
		= split('\t', $geneProfile{$gene});
	    $product = "hypothetical protein" if $product eq "";
	    $row .= $locus.$sd.$locus."\t";
	    $row .= $product.$sd.$product."\t";
	} else {
	    my $line = $gene2info{ $gene };
            my ($geneid, $locus_type, $locus_tag, $strand,
                $scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
                = split("\t", $line);
            my $product = WebUtil::geneOid2Name($dbh, $gene);
	    $product = "hypothetical protein" if $product eq "";
	    $row .= $locus_tag.$sd.$locus_tag."\t";
	    $row .= $product.$sd.$product."\t";
	}

	my $val = $spearman_data{ $gene };
	$val = sprintf("%.3f", $val);
	$row .= $val.$sd.$val."\t";
	$it->addRow($row);
	$count++;
    }

    printGeneCartFooter() if ($count > 10);
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
    print "</p></div>"; # end spearmantab1

    print "<div id='spearmantab2'>";

    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";

    # CHART for scatterplot ####################
    my $chart = ChartUtil::newScatterChart();
    $chart->WIDTH(700);
    $chart->HEIGHT(400);
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_URLS("yes");
    #$chart->SHOW_XLABELS("yes");
    $chart->SHOW_YLABELS("yes");
    $chart->ITEM_URL($url);
    $chart->DOMAIN_AXIS_LABEL("Gene");
    $chart->RANGE_AXIS_LABEL("Spearman's Rho");
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_SECTION_URLS("yes");

    # sort by spearman's coefficient first:
    my @sortedKeys = sort { $spearman_data{$b} <=> $spearman_data{$a} }
    keys %spearman_data;

    my @sortedValues;
    my @sortedGenes;
    my $idx = 0;
    my @indeces;
    foreach my $gene( @sortedKeys ) {
	push @sortedValues, $spearman_data{ $gene };
        #my ($name, $locus, $product, $dna_seq_length)
        #    = split('\t', $geneProfile{$gene});
	push @indeces, $idx;
	#push @sortedGenes, "[$gene - $locus - $product]";
	$idx++;
    }

    my @chartseries;
    push @chartseries, "genes";
    $chart->SERIES_NAME(\@chartseries);

    my $datastr = join(",", @sortedKeys);
    my @datas = ($datastr);
    $chart->DATA(\@datas);

    my $xdatastr = join(",", @indeces);
    my @xdatas = ($xdatastr);
    $chart->XAXIS(\@xdatas);
    my $ydatastr = join(",", @sortedValues);
    my @ydatas = ($ydatastr);
    $chart->YAXIS(\@ydatas);

    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        $st = ChartUtil::generateChart($chart);

        if ($st == 0) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "spearman-rnaseq", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
		. $chart->FILE_PREFIX . ".png' BORDER=0 "
		. " width=" . $chart->WIDTH . " height=" . $chart->HEIGHT
		. " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }

    print "</div>"; # end spearmantab2
    TabHTML::printTabDivEnd();
}

############################################################################
# doRegression - run linear regression analysis and compute r-squared
############################################################################
sub doRegression {
    my @sample_oids = param("exp_samples");
    my $nSamples = @sample_oids;
    my $sample1 = @sample_oids[0];
    my $sample2 = @sample_oids[1];
    my $proposal = param("proposal");
    my $taxon_oid = param("taxon_oid");
    my $normalization = param("normalization");
    my $in_file = param("in_file");
    my $genome_type = param("genome_type");

    webLog "LINEAR REGRESSION: $sample1 $sample2 $taxon_oid";

    if ($nSamples < 2) {
        webError( "Please select 2 samples." );
    }

    @sample_oids = ( $sample1, $sample2 ); # more could be selected in ui
    my $sample_oid_str = $sample1.",".$sample2;

    my $dbh = dbLogin();

    if ($taxon_oid eq "") {
        my $sql = qq{
            select distinct dts.reference_taxon_oid, tx.in_file, tx.genome_type
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = tx.taxon_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        ( $taxon_oid, $in_file, $genome_type ) = $cur->fetchrow();
        $cur->finish();
    }

    printStartWorkingDiv();

    my $inputFile = "$tmp_dir/regression$$.in.txt";
    my ($names_ref, $notes_ref, $sampleProfiles, $gid_ref,
	$gprofile, $raw_profiles_ref)
	= makeProfileFile($dbh, $inputFile, $normalization,
			  \@sample_oids, $sample_oid_str, "", 1,
			  $in_file, 0, 1);
    my %sampleNames = %$names_ref;
    #$dbh->disconnect();

    my $program = "$cgi_dir/bin/r_squared_linear_regression.R";
    my $outputFile = "$tmp_dir/rsquared$$.txt";
    my $outputPng = "$tmp_dir/rsquared$$.png";

    WebUtil::unsetEnvPath();
    #my $environ = "PATH='/bin:/usr/bin'; export PATH";
    my $cmd = "$R --slave --args "
            . "$inputFile $outputFile $outputPng "
            . "< $program > /dev/null";
    print "<br/>Command: $cmd";
    my $st = system($cmd);
    runCmd( "/bin/cp $program $tmp_dir/" );
    WebUtil::resetEnvPath();

    if ($st != 0) {
	printEndWorkingDiv();
        webError( "Problem running R script: $program." );
    }

    print "Done computing r-squared.<br/>";

    printEndWorkingDiv();

    WebUtil::printHeaderWithInfo
        ("Linear Regression Analysis", "", "", "", 0, "RNAStudies.pdf");

    if ($proposal ne "") {
	print "<span style='font-size: 12px; "
	    . "font-family: Arial, Helvetica, sans-serif;'>\n";
        my $expurl = "$section_cgi&page=samplesByProposal"
            . "&proposal=$proposal&genomes=1";
        print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
	print "</span>\n";
    }

    my $surl = "$section_cgi&page=sampledata&sample=";
    my $name1 = $sampleNames{$sample1};
    my $name2 = $sampleNames{$sample2};

    print "<p>\n";
    print "Samples compared:<br/>";
    print alink($surl.$sample1, $name1, "_blank");
    print "<br/>";
    print alink($surl.$sample2, $name2, "_blank");
    print "</p>\n";

    use TabHTML;
    TabHTML::printTabAPILinks("regressionTab");
    my @tabIndex = ( "#regressiontab1", "#regressiontab2" );
    my @tabNames = ( "Regression Graph", "R<sup>2</sup> Output" );
    TabHTML::printTabDiv("regressionTab", \@tabIndex, \@tabNames);

    print "<div id='regressiontab1'>";
    printHint(  "Mouse over a point to see the Gene ID and expression "
	      . "values for each sample.<br/>"
	      . "Click on a point to go to the Gene Details page.");

    my $url = "$main_cgi?section=GeneDetail&page=geneDetail&gene_oid=";
    if ($genome_type eq "metagenome") {
        $url = "$main_cgi?section=MetaGeneDetail&page=metaGeneDetail"
             . "&data_type=assembled&taxon_oid=$taxon_oid&gene_oid="
    }

    # CHART for linear regression ####################
    my $chart = ChartUtil::newScatterChart();
    $chart->WIDTH(700);
    $chart->HEIGHT(500);
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("no");
    $chart->INCLUDE_URLS("yes");
    $chart->SHOW_REGRESSION("yes");
    $chart->SHOW_XLABELS("yes");
    $chart->SHOW_YLABELS("yes");
    $chart->ITEM_URL($url);
    $chart->DOMAIN_AXIS_LABEL($name1);
    $chart->RANGE_AXIS_LABEL($name2);
    $chart->ROTATE_DOMAIN_AXIS_LABELS("yes");
    $chart->INCLUDE_SECTION_URLS("yes");

    my @chartseries;
    push @chartseries, "Linear Regression";
    $chart->SERIES_NAME(\@chartseries);

    my $profile_ref1 = $sampleProfiles->{$sample1};
    my $profile_ref2 = $sampleProfiles->{$sample2};
    my @geneIds = sort (keys (%$profile_ref1));
    my @keys = (keys %$sampleProfiles);
    my $values = $sampleProfiles->{@keys[0]};
    my @keys1 = (keys %$values);

    my @values1;
    my @values2;
    foreach my $gene( @geneIds ) {
        push @values1, $profile_ref1->{ $gene };
        push @values2, $profile_ref2->{ $gene };
    }

    my $datastr = join(",", @geneIds);
    my @datas = ($datastr);
    $chart->DATA(\@datas);

    my $xdatastr = join(",", @values1);
    my @xdatas = ($xdatastr);
    $chart->XAXIS(\@xdatas);
    my $ydatastr = join(",", @values2);
    my @ydatas = ($ydatastr);
    $chart->YAXIS(\@ydatas);

    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        $st = ChartUtil::generateChart($chart);
        if ($st == 0) {
            print "<script src='$base_url/overlib.js'></script>\n";
            my $FH = newReadFileHandle( $chart->FILEPATH_PREFIX . ".html",
                                        "regression-rnaseq", 1 );
            while ( my $s = $FH->getline() ) {
                print $s;
            }
            close($FH);
            print "<img src='$tmp_url/"
                . $chart->FILE_PREFIX . ".png' BORDER=0 "
                . " width=" . $chart->WIDTH . " height=" . $chart->HEIGHT
                . " USEMAP='#" . $chart->FILE_PREFIX . "'>\n";
        }
    }

    print qq{
        <p><a href="$tmp_url/rsquared$$.png" alt='Linear Regression'
            target="_blank">View R-generated Graph</a>
        </p>
    };

    print "</div>"; # end regressiontab1
    print "<div id='regressiontab2'>";
    print "<p style='width: 950px;'>";
    print "R-squared is a statistical measure that provides an indication of how well the regression line approximates the real data points. R-squared of 1.0 indicates that the regression line perfectly fits the data. When 2 replicate samples from the same experiment are compared, the expression of the genes in the 2 replicates should be the same. In this case, a straight-diagonal regression line is expected, with all data points distributed around the line and an R-squared within 0.9 to 1.0 range.";
    print "<br/><br/>";
    print alink("$tmp_url/r_squared_linear_regression.R",
		"View R file", "_blank")
              . " used to compute this output.";
    print "</p>";

    print "<h2>Output of R-squared</h2>";
    print "<p>";
    my $idx = 0;
    my $rfh = newReadFileHandle( $outputFile, "rsquared" );
    while( my $s = $rfh->getline() ) {
	if ($idx == 0 && blankStr($s)) {
	    # don't print first empty line
	} else {
	    print $s;
	    print "<br/>";
	    $idx++;
	}
    }
    close $rfh;
    print "</p>";

    print "</div>"; # end regressiontab2
    TabHTML::printTabDivEnd();
}

############################################################################
# printPreviewGraph - compares 2 selected samples to identify genes
#                     that are up or down regulated
############################################################################
sub printPreviewGraph {
    my $taxon_oid = param("taxon_oid");
    my $sample1 = param("sample1");
    my $sample2 = param("sample2");
    my $normalization = param("normalization");
    my $in_file = param("in_file");
    my $genome_type = param("genome_type");

    webLog "PREVIEW: $sample1 $sample2 $taxon_oid $normalization";

    if ($sample1 eq "" || $sample2 eq "") {
        my $header = "Preview";
        my $body = "Please select 2 samples.";
	my $script = "$base_url/overlib.js";

        print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
        print qq {
            <response>
                <header>$header</header>
                <text>$body</text>
		<script>$script</script>
            </response>
        };
        return;
    }

    my $sample_oid_str = $sample1.",".$sample2;
    my @sample_oids = ($sample1, $sample2);

    my $dbh = dbLogin();
    if ($taxon_oid eq "") {
        my $sql = qq{
            select distinct dts.reference_taxon_oid, tx.in_file
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = tx.taxon_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
	( $taxon_oid, $in_file ) = $cur->fetchrow();
        $cur->finish();
    }

    my $inputFile = "$tmp_dir/preview$$.tab.txt";
    my ($names_ref, $notes_ref, $profiles_ref, $gid_ref,
	$gprofile, $raw_profiles_ref)
	= makeProfileFile($dbh, $inputFile, $normalization,
			  \@sample_oids, $sample_oid_str, "", 0,
			  $in_file, 1);
    my %sampleProfiles = %$profiles_ref;
    my %sampleNames = %$names_ref;
    my @geneIds = @$gid_ref;
    #$dbh->disconnect();

    my @logR_data;
    my @relDiff_data;
    foreach my $gene( @geneIds ) {
	my $profile1 = $sampleProfiles{ $sample1 };
	my $profile2 = $sampleProfiles{ $sample2 };
	my $coverage1 = $profile1->{ $gene }; # ref coverage
	my $coverage2 = $profile2->{ $gene };
	if ($coverage1 eq "0" || $coverage2 eq "0") {
	    next;
	}

	if ($normalization eq "coverage") {
	    $coverage1 = $coverage1 * 10**9;
	    $coverage2 = $coverage2 * 10**9;
	}

	$coverage1 = sprintf("%.3f", $coverage1);
	$coverage2 = sprintf("%.3f", $coverage2);

	# logR
	if (abs($coverage1) == $coverage1 &&
	    abs($coverage2) == $coverage2 &&
	    abs($coverage1) > 0 &&
	    abs($coverage2) > 0) {
	    # check for bad (negative) values - these seem
	    # to show up during affine normalization
	    my $delta1 = log($coverage2/$coverage1)/log(2);
	    $delta1 = sprintf("%.5f", $delta1);
	    push @logR_data, $delta1;
	}

	# RelDiff
	my $delta2 = 2*($coverage2 - $coverage1)/($coverage2 + $coverage1);
	$delta2 = sprintf("%.5f", $delta2);
	push @relDiff_data, $delta2;
    }

    # CHART for distribution ####################
    my $chart = ChartUtil::newHistogramChart();
    $chart->WIDTH(400);
    $chart->HEIGHT(300);
    $chart->INCLUDE_TOOLTIPS("yes");
    $chart->INCLUDE_LEGEND("yes");
    $chart->DOMAIN_AXIS_LABEL("Metric");
    $chart->RANGE_AXIS_LABEL("Gene Count");

    my @chartseries;
    my @datas;
    if (scalar @logR_data > 0) {
	push @chartseries, "logR";
	my $datastr1 = join(",", @logR_data);
	push @datas, $datastr1;
    }
    my $datastr2 = join(",", @relDiff_data);
    push @datas, $datastr2;
    push @chartseries, "RelDiff";

    $chart->SERIES_NAME(\@chartseries);
    $chart->DATA(\@datas);

    my $name = "Difference in expression between 2 samples";
    my $st = -1;
    if ($env->{ chart_exe } ne "") {
        $st = ChartUtil::generateChart($chart);

	if ($st == 0) {
            my $url = "$tmp_url/".$chart->FILE_PREFIX.".png";
            my $imagemap = "#".$chart->FILE_PREFIX;
            my $script = "$base_url/overlib.js";
	    my $width = $chart->WIDTH;
            my $height = $chart->HEIGHT;

            print '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';
            print qq {
                <response>
                    <header>$name</header>
                    <script>$script</script>
                    <maptext><![CDATA[
            };

            my $FH = newReadFileHandle
                ($chart->FILEPATH_PREFIX.".html", "rnaseq-histogram", 1);
            while (my $s = $FH->getline()) {
                print $s;
            }
            close ($FH);

	    my $asample1 = WebUtil::escHtml(substr($sample1,0,40));
	    my $asample2 = WebUtil::escHtml(substr($sample2,0,40));

            print qq {
                    ]]></maptext>
 		    <text>Reference: $asample1</text>
 		    <text>Query: $asample2</text>
                    <url>$url</url>
                    <imagemap>$imagemap</imagemap>
                    <width>$width</width>
                    <height>$height</height>
                </response>
            };
	}
    }
    # END CHART ##################################
}

############################################################################
# printCompareSamples - compares 2 selected samples to identify genes
#                       that are up or down regulated
############################################################################
sub printCompareSamples {
    my @sample_oids = param("exp_samples");
    my $nSamples = @sample_oids;
    my $proposal = param("proposal");
    my $taxon_oid = param("taxon_oid");
    my $normalization = param("normalization");
    my $in_file = param("in_file");
    my $genome_type = param("genome_type");

    if ($nSamples < 2) {
        webError( "Please select 2 samples." );
    }

    my $reference = param( "reference" );
    my $threshold = param( "threshold" );
    my $metric = param( "metric" );

    my $sample1 = @sample_oids[0];
    my $sample2 = @sample_oids[1];
    if ( $reference eq "2" ) {
	$sample1 = @sample_oids[1];
	$sample2 = @sample_oids[0];
    }
    my $sample_oid_str = $sample1.",".$sample2;
    @sample_oids = ($sample1, $sample2);
    printStatusLine("Loading ...", 1);

    my $dbh = dbLogin();
    my @taxons;
    if ($taxon_oid eq "") {
        my $sql = qq{
            select distinct dts.reference_taxon_oid, tx.in_file, tx.genome_type
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = tx.taxon_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
            my( $txid, $in, $gtype ) = $cur->fetchrow();
            last if !$txid;
            push @taxons, $txid;
            $in_file = $in;
	    $genome_type = $gtype;
        }
        $cur->finish();
        $taxon_oid = @taxons[0] if (scalar @taxons == 1);
    } else {
        push @taxons, $taxon_oid;
    }

    my $inputFile = "$tmp_dir/compare$$.tab.txt";
    my ($names_ref, $notes_ref, $profiles_ref, $gid_ref,
	$gprofile, $raw_profiles_ref)
        = makeProfileFile($dbh, $inputFile, $normalization,
                          \@sample_oids, $sample_oid_str, "", 1,
                          $in_file, 1);
    my %sampleProfiles = %$profiles_ref;
    my %sampleProfilesRaw = %$raw_profiles_ref;
    my %sampleNames = %$names_ref;
    my @geneIds = @$gid_ref;

    WebUtil::printHeaderWithInfo
        ("Up/Down Regulation", "", "", "", 0, "RNAStudies.pdf#page=7");

    print "<p style='width: 650px;'>";
    if ($proposal ne "") {
	print "<span style='font-size: 12px; "
	    . "font-family: Arial, Helvetica, sans-serif;'>\n";
	my $expurl = "$section_cgi&page=samplesByProposal"
	           . "&proposal=$proposal&genomes=1";
	print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
	print "</span>\n";
    }

    if ($taxon_oid ne "") {
        my $sql = qq{
            select taxon_display_name
            from taxon
            where taxon_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my ($taxon_name) = $cur->fetchrow();
        $cur->finish();

        my $url = "$main_cgi?section=TaxonDetail"
	        . "&page=taxonDetail&taxon_oid=$taxon_oid";
	print "<br/>" if $proposal ne "";
        print "<u>Genome</u>: ".alink($url, $taxon_name, "_blank");
    }
    print "</p>";

    printHint
      ("Click on a tab to select up- or down- regulated genes ".
       "to add to gene cart<br/>".
       "Difference in expression levels is computed using the <u>".
       $metric."</u> metric<br/>".
       "Expression levels differ by a <u>threshold</u>: ".$threshold.
       "<br/><u>Normalization</u>: $normalization");

    my $url = "$section_cgi&page=sampledata&sample=";
    print "<p>\n";
    print "Reference sample: "
	. alink($url.$sample1, $sampleNames{$sample1}, "_blank");
    print "<br/>";
    print "Query sample: "
	. alink($url.$sample2, $sampleNames{$sample2}, "_blank");
    print "</p>\n";

    ## Template of all genes:
    my %geneProfile;
    if ($in_file eq "Yes" || scalar (keys %$gprofile) > 0) {
	%geneProfile = %$gprofile;
    } else {
	# anna: will remove when rnaseq_expression is cleaned out
	my $sql = qq{
            select distinct es.IMG_gene_oid,
                g.gene_display_name,
                g.locus_tag, g.product_name,
                g.DNA_seq_length
            from rnaseq_expression es, gene g
            where es.dataset_oid in ($sample_oid_str)
            and es.IMG_gene_oid = g.gene_oid
            and es.reads_cnt > 0.0000000
            order by es.IMG_gene_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gid, $gene_name, $locus_tag, $product,
		$dna_seq_length ) = $cur->fetchrow();
	    last if !$gid;
	    $geneProfile{ $gid } =
		"$gene_name\t$locus_tag\t$product\t$dna_seq_length";
	}
	$cur->finish();
    }

    use TabHTML;
    TabHTML::printTabAPILinks("imgTab");
    my @tabIndex = ( "#tab1", "#tab2" );
    my @tabNames = ( "Up-regulated Genes", "Down-regulated Genes" );
    TabHTML::printTabDiv("imgTab", \@tabIndex, \@tabNames);

    foreach my $tab (@tabIndex) {
	my $a = "tab1";
	$a = "tab2" if $tab eq "#tab2";

	print "<div id='$a'><p>\n";
        # For separate tables in multiple tabs, set the form id to be the
        # InnerTable table name (3rd argument) followed by "_frm" :
        print start_form(-id     => $a."genes_frm",
                         -name   => "mainForm",
                         -action => "$main_cgi" );

	my $it = new InnerTable(1, $a."genes$$", $a."genes", 8);
	my $sd = $it->getSdDelim();
	$it->addColSpec( "Select" );
	$it->addColSpec( "Gene ID", "asc", "right" );
	$it->addColSpec( "Locus Tag", "asc", "left" );
	$it->addColSpec( "Product Name", "asc", "left" );

	foreach my $s( @sample_oids ) {
	    if ($normalization eq "coverage") {
		$it->addColSpec
                ( $sampleNames{$s}." [".$s."]", "desc", "right", "",
                  "Normalized Coverage<sup>1</sup> * 10<sup>9</sup> for: "
                . $sampleNames{$s}, "wrap" );
	    } else {
		$it->addColSpec
                ( $sampleNames{$s}." [".$s."]", "desc", "right", "",
                  "Normalized ($normalization) "
                . "Expression Data<sup>1</sup><br/>for: "
                . $sampleNames{$s}, "wrap" );
	    }
	    $it->addColSpec
		( $sampleNames{$s}." [".$s."]<br/>Raw Count",
		  "desc", "right", "", "Raw Count (Reads) for: "
		. $sampleNames{$s}, "wrap" );
	}

	if ($a eq "tab1") {
	    $it->addColSpec( $metric, "desc", "right" );
	} else {
	    $it->addColSpec( $metric, "asc", "right" );
	}

	my $count;
	foreach my $gene( @geneIds ) {
	    my $url1 = "$main_cgi?section=GeneDetail"
		     . "&page=geneDetail&gene_oid=$gene";
	    my $genelink = $gene;
	    if ($genome_type eq "metagenome") {
		$url1 = "$main_cgi?section=MetaGeneDetail"
		      . "&page=metaGeneDetail&gene_oid=$gene"
		      . "&data_type=assembled&taxon_oid=$taxon_oid";
		$genelink = "$taxon_oid assembled $gene";
	    }

	    my $row = $sd."<input type='checkbox' "
		    . "name='gene_oid' value='$genelink'/>\t";

	    my ($name, $locus, $product, $dna_seq_length)
		= split('\t', $geneProfile{$gene});
	    $product = "hypothetical protein" if $product eq "";

            $row .= $gene.$sd.alink($url1, $gene, "_blank")."\t";
	    $row .= $locus.$sd.$locus."\t";
	    $row .= $product.$sd.$product."\t";

	    my $profile1 = $sampleProfiles{ $sample1 };
	    my $profile2 = $sampleProfiles{ $sample2 };
	    my $coverage1 = $profile1->{ $gene }; # ref coverage
	    my $coverage2 = $profile2->{ $gene };
	    if ($coverage1 eq "0" || $coverage2 eq "0") {
		next;
	    }

	    if ($normalization eq "coverage") {
		$coverage1 = $coverage1 * 10**9;
		$coverage2 = $coverage2 * 10**9;
	    }

	    my $profileRaw1 = $sampleProfilesRaw{ $sample1 };
	    my $profileRaw2 = $sampleProfilesRaw{ $sample2 };
            my $reads1 = $profileRaw1->{ $gene };
            my $reads2 = $profileRaw2->{ $gene };

	    $coverage1 = sprintf("%.3f", $coverage1);
	    $coverage2 = sprintf("%.3f", $coverage2);
	    $row .= $coverage1.$sd.$coverage1."\t";
            $row .= $reads1."\t";
	    $row .= $coverage2.$sd.$coverage2."\t";
            $row .= $reads2."\t";

	    my $s1 = $coverage1;
	    my $s2 = $coverage2;
	    my $delta;
	    if ($metric eq "logR") {
		if (abs($s1) == $s1 && abs($s2) == $s2 &&
		    abs($s1) > 0 && abs($s2) > 0) {
		    # check for bad (negative) values - these seem
		    # to show up during affine normalization
		    $delta = log($s2/$s1)/log(2);
		} else {
                    # flag problem ?
		    next;
		}
	    } elsif ($metric eq "RelDiff") {
		$delta = 2*($s2 - $s1)/($s2 + $s1);
	    }
	    $delta = sprintf("%.5f", $delta);
	    next if ($a eq "tab1" &&
		     ($delta < $threshold)); # for up-regulation
	    next if ($a eq "tab2" &&
		     ($delta > -1*$threshold)); # for down-regulation
	    $row .= $delta.$sd.$delta."\t";

	    $it->addRow($row);
	    $count++;
	}

	printGeneCartFooter($a."genes") if ($count > 10);
	$it->printOuterTable(1);
	printGeneCartFooter($a."genes");

	print end_form();
	print "</p></div>\n";
    }

    TabHTML::printTabDivEnd();
    printNotes("studysamples");
    printStatusLine("Loaded.", 2);
}

############################################################################
# printExpressionByFunction - compares selected samples per gene group:
#                     COG function, KEGG pathways, KEGG modules, etc.
############################################################################
sub printExpressionByFunction {
    my ($pairwise)= @_;
    my @sample_oids = param("exp_samples");
    my $nSamples = scalar (@sample_oids);
    my $proposal = param("proposal");
    my $taxon_oid = param("taxon_oid");
    my $normalization = param("normalization");
    my $in_file = param("in_file");

    if ($pairwise ne "") {
        if ($nSamples < 2) {
            webError( "Please select 2 samples." );
        }
        my @samples = (@sample_oids[0], @sample_oids[1]);
        my $reference = param( "reference" );
        if ( $reference eq "2" ) {
            @samples = (@sample_oids[1], @sample_oids[0]);
        }
        @sample_oids = @samples;
        $nSamples = 2;
    }
    if ($nSamples == 1) {
        $normalization = "coverage";
    }
    if ($nSamples < 1) {
	webError( "Please select at least 1 sample." );
    }

    my $cart_genes = param("describe_cart_genes");
    my @cart_gene_oids;
    if ($cart_genes) {
        use GeneCartStor;
        my $gc = new GeneCartStor();
        my $recs = $gc->readCartFile(); # get records
        @cart_gene_oids = sort { $a <=> $b } keys(%$recs);
        if (scalar @cart_gene_oids < 1) {
            webError( "Your Gene Cart is empty." );
        }
    }

    printStatusLine("Loading ...", 1);

    WebUtil::printHeaderWithInfo
        ("Expression by Function for Selected Samples",
	 "", "", "", 0, "RNAStudies.pdf#page=13");

    my $dbh = dbLogin();
    my %sample2taxon;
    my %taxons;

    my $sample_oid_str = join(",", @sample_oids);
    my $sql = qq{
        select distinct dts.dataset_oid, dts.reference_taxon_oid,
               tx.in_file, tx.genome_type
        from rnaseq_dataset dts, taxon tx
        where dts.dataset_oid in ($sample_oid_str)
        and dts.reference_taxon_oid = tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
        my( $sid, $tx, $in, $gt ) = $cur->fetchrow();
        last if !$sid;
        $sample2taxon{ $sid } = $tx;
        $taxons{ $tx } = $in;
	#$taxons{ $tx } = $in . "," . $gt;
    }
    $cur->finish();

    my @taxons = keys %taxons;
    if (scalar @taxons == 1) {
	$taxon_oid = @taxons[0];
	$in_file = $taxons{ $taxon_oid };
    } else {
	$taxon_oid = "";
	$in_file = "";
    }

    print "<p style='width: 950px;'>";
    if ($proposal ne "") {
	print "<span style='font-size: 12px; "
	    . "font-family: Arial, Helvetica, sans-serif;'>\n";
        my $expurl = "$section_cgi&page=samplesByProposal"
                   . "&proposal=$proposal&genomes=1";
        print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
	print "</span>\n";
    }

    if ($taxon_oid ne "") {
        my $sql = qq{
            select taxon_display_name
            from taxon
            where taxon_oid = ?
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        my ($taxon_name) = $cur->fetchrow();
        $cur->finish();

        my $url = "$main_cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$taxon_oid";
	print "<br/>" if $proposal ne "";
        print "<u>Genome</u>: ".alink($url, $taxon_name, "_blank");
    }
    print "</p>";

    my $hint =
	"Click on a tab to select grouping of genes "
      . "by kegg or by cog function. "
      . "For each sample, the average of normalized expression values "
      . "for each group of genes is displayed."
      . "<br/><u>Normalization</u>: $normalization"
      . "<br/>$nSamples sample(s) selected";
    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	$hint .= "<br/>*Showing only genes from gene cart";
    }
    printHint($hint);

    my $inputFile = "$tmp_dir/byfunction$$.tab.txt";
    my ($names_ref, $notes_ref, $profiles_ref, $gid_ref,
	$gprofile, $raw_profiles_ref)
        = makeProfileFile($dbh, $inputFile, $normalization,
                          \@sample_oids, $sample_oid_str,
			  \@cart_gene_oids, $pairwise, $in_file, 1);
    my %sampleProfiles = %$profiles_ref;
    my %sampleNames = %$names_ref;
    my %sampleProfilesRaw = %$raw_profiles_ref;
    #my @geneIds = @$gid_ref;

    if ($pairwise ne "") {
	my $url = "$section_cgi&page=sampledata&sample=";
	print "<p>\n";
	my $sample1 = @sample_oids[0];
	my $sample2 = @sample_oids[1];
	print "Reference sample: "
	    . alink($url.$sample1, $sampleNames{$sample1}, "_blank");
	print "<br/>";
	print "Query sample: "
	    . alink($url.$sample2, $sampleNames{$sample2}, "_blank");
	print "</p>\n";
    } else {
	print "<br/>";
    }

    printStartWorkingDiv();

    my %kegg_hash;
    my %cog_hash;
    my %pathw2genes;
    my %cog2genes;

    # 1. get all the pathways for this genome
    # 2. get "all" genes for the function id
    # 3. check if the genes are present in the sample

    my %all_kegg_pathways;
    my %all_kos;
    my %all_cogs;
    foreach my $tx (keys %taxons) {
	my $infile = $taxons{ $tx };
	if ($infile eq "Yes") {
	    print "<br/>Getting pathway gene counts (FS) [$tx] ...";
	    my %tx_kpathws = MetaUtil::getTaxonFuncCount
		($tx, 'assembled', 'kegg_pathway');
	    my %tx_kos = MetaUtil::getTaxonFuncCount($tx, 'assembled', 'ko');
	    @all_kegg_pathways{ keys %tx_kpathws } = values %tx_kpathws;
	    @all_kos{ keys %tx_kos } = values %tx_kos;

	    print "<br/>Getting pathway info ... [$tx]";
	    my $ksql = qq{
                select distinct pw.pathway_name, pw.pathway_oid,
                       pw.image_id, irk.ko_terms
                from kegg_pathway pw, image_roi roi, image_roi_ko_terms irk
                where pw.pathway_oid = roi.pathway
                and roi.roi_id = irk.roi_id
                order by pw.pathway_name
            };
	    my $cur = execSql( $dbh, $ksql, $verbose );

	    my %done;
	    my $old_image_id;
	    my $old_pathway_name;
	    my %allpathwgenes;
	    for ( ;; ) {
		my ( $pathway_name, $pathway_oid, $image_id, $ko )
		    = $cur->fetchrow();
		last if !$image_id;
		last if !$ko;
		next if ($image_id eq 'map01100');
		next if (!$all_kegg_pathways{$pathway_oid});
		next if (!$all_kos{$ko});

		if ($old_pathway_name eq "") {
		    $old_pathway_name = $pathway_name;
		    $old_image_id = $image_id;
		}
		if ($image_id ne $old_image_id) {
		    my $gene_count = scalar (keys %allpathwgenes);
		    print "<br/>Getting $old_image_id gene counts (FS) ...";
		    if ($gene_count > 0) {
			my $key = "$old_pathway_name\t$old_image_id";
			if (exists $kegg_hash{ $key }) {
			    my $gcnt = $kegg_hash{ $key };
			    $kegg_hash{ $key } = $gene_count + $gcnt;
			} else {
			    $kegg_hash{ $key } = $gene_count
				if $gene_count > 0;
			}
		    }
		    undef %allpathwgenes;
		}

		$old_pathway_name = $pathway_name;
		$old_image_id = $image_id;

		my %ko_genes = MetaUtil::getTaxonFuncGenes($tx, "assembled", $ko);
		my @gene_group = keys %ko_genes;
		next if (scalar @gene_group == 0);

		foreach my $s( @sample_oids ) {
		    my $profile = $sampleProfiles{ $s };
		    # check if a gene is in profile genes for this sample:
		    GENE: foreach my $gene( @gene_group ) {
			next if (!exists ($profile->{$gene}));
			next if (!$profile->{ $gene });
			next if $done{ "$s"."$gene"."$image_id" };
			$pathw2genes{ $s.$image_id } .= $gene."\t";
			$done{ "$s"."$gene"."$image_id" } = 1;
			$allpathwgenes{ $gene } = 1;
		    }
		}
	    }

	    print "<br/>Getting cog gene counts (FS) [$tx] ...";
	    my %tx_cogs = MetaUtil::getTaxonFuncCount($tx, 'assembled', 'cog');
	    @all_cogs{ keys %tx_cogs } = values %tx_cogs;

	    print "<br/>Getting cog info ... [$tx]";
	    my $csql = qq{
                select cf.function_code, cf.definition, cfs.cog_id
                from cog_function cf, cog_functions cfs
                where cf.function_code = cfs.functions
                order by cf.function_code
            };
	    my $cur = execSql( $dbh, $csql, $verbose );

	    my %done;
	    my $old_func_code;
	    my $old_definition;
	    my %allcoggenes;
	    for ( ;; ) {
		my ( $func_code, $definition, $cog_id ) = $cur->fetchrow();
		last if !$func_code;
		next if (!$all_cogs{$cog_id});

		if ($old_func_code eq "") {
		    $old_func_code = $func_code;
		    $old_definition = $definition;
		}
		if ($func_code ne $old_func_code) {
		    my $gene_count = scalar (keys %allcoggenes);
		    print "<br/>Getting $old_func_code gene counts (FS) ...";
		    if ($gene_count > 0) {
                        my $key = "$old_func_code\t$old_definition";
                        if (exists $cog_hash{ $key }) {
                            my $gcnt = $cog_hash{ $key };
                            $cog_hash{ $key } = $gene_count + $gcnt;
                        } else {
                            $cog_hash{ $key } = $gene_count if $gene_count > 0;
                        }
		    }
		    undef %allcoggenes;
		}

		$old_func_code = $func_code;
		$old_definition = $definition;

		my %cog_genes = MetaUtil::getTaxonFuncGenes($tx, "assembled", $cog_id);
		my @gene_group = keys %cog_genes;
		next if (scalar @gene_group == 0);

		foreach my $s( @sample_oids ) {
		    my $profile = $sampleProfiles{ $s };
		    # check if a gene is in profile genes for this sample:
		    GENE: foreach my $gene( @gene_group ) {
			next if (!exists($profile->{ $gene }));
			next if (!$profile->{ $gene });
			next if $done{ "$s"."$gene"."$func_code" };
			$cog2genes{ $s.$func_code } .= $gene."\t";
			$done{ "$s"."$gene"."$func_code" } = 1;
			$allcoggenes{ $gene } = 1;
		    }
		}
	    }

	} else {   # not $in_file
	    # rnaseq genes are in sdb
	    my %sample2genes;
	    foreach my $s (@sample_oids) {
		my $tx2 = $sample2taxon{ $s };
		next if $tx2 ne $tx;
		my ($total_gene_cnt, $total_read_cnt) =
		    MetaUtil::getCountsForRNASeqSample($s, $tx);

		if ($total_gene_cnt > 0) { # found
		    my %gene2info = MetaUtil::getGenesForRNASeqSample($s, $tx);
		    my @genes = keys %gene2info;
		    $sample2genes{ $s } = join("\t", @genes);

		} else {
		    # anna: genes and reads should come from sdb
		    # anna: will remove when rnaseq_expression is cleaned out
		    my $sql = qq{
                        select es.IMG_gene_oid
                        from rnaseq_expression es
                        where es.dataset_oid = ?
                    };
		    my $cur = execSql( $dbh, $sql, $verbose, $s );
		    my @genes;
		    for ( ;; ) {
			my ($gene) = $cur->fetchrow();
			last if !$gene;
			push @genes, $gene;
		    }
		    $sample2genes{ $s } = join("\t", @genes);
		}
		#ANNA: go through the genes here? FIXME
	    }

	    # get the genes for each pathway
	    print "<br/>Getting pathway genes for genome from db [$tx] ...";
	    my $sql = qq{
                select distinct gkmp.gene_oid, gkmp.image_id
                from dt_gene_ko_module_pwys gkmp
                where gkmp.taxon = ?
            };
	    my $cur = execSql( $dbh, $sql, $verbose, $tx );
	    for( ;; ) {
		my( $gene_oid, $image_id ) = $cur->fetchrow();
		last if !$gene_oid;
		next if ($image_id eq 'map01100');

		SAMPLE: foreach my $s (@sample_oids) {
		    my $tx2 = $sample2taxon{ $s };
		    next if $tx2 ne $tx;
		    my @sgenes = split("\t", $sample2genes{ $s });
		    foreach my $g (@sgenes) {
			if ($g eq $gene_oid) { # found!
			    $pathw2genes{ $s.$image_id } .= $gene_oid."\t";
			    next SAMPLE;
			}
		    }
		}
	    }
	    $cur->finish();

            my $sql = qq{
                select distinct pw.pathway_name, pw.image_id
                from kegg_pathway pw, dt_gene_ko_module_pwys gkmp
                where pw.pathway_oid = gkmp.pathway_oid
                and gkmp.taxon = ?
            };
            my $cur = execSql( $dbh, $sql, $verbose, $tx );
            for( ;; ) {
                my( $pathway_name, $image_id ) = $cur->fetchrow();
                last if !$image_id;
                next if ($image_id eq 'map01100');

                my %unique_genes;
		foreach my $s (@sample_oids) {
		    my $geneStr = $pathw2genes{ $s.$image_id };
		    chop $geneStr;
		    my @sgenes = split("\t", $geneStr);
		    foreach my $g (@sgenes) {
			$unique_genes{ $g } = 1;
		    }
		}

                my $gene_count = scalar keys %unique_genes;
		my $key = "$pathway_name\t$image_id";
		if (exists $kegg_hash{ $key }) {
		    my $gcnt = $kegg_hash{ $key };
		    $kegg_hash{ $key } = $gene_count + $gcnt;
		} else {
		    $kegg_hash{ $key } = $gene_count if $gene_count > 0;
		}
            }
            $cur->finish();

	    # get the genes for each cog
	    print "<br/>Getting cog genes for genome from db [$tx] ...";
	    my $sql = qq{
                select distinct gcg.gene_oid, cfs.functions
                from gene_cog_groups gcg, cog_functions cfs
                where gcg.cog = cfs.cog_id
                and gcg.taxon = ?
            };
	    my $cur = execSql( $dbh, $sql, $verbose, $tx );
	    for ( ;; ) {
		my ( $gene_oid, $cog_fn ) = $cur->fetchrow();
		last if !$gene_oid;

                SAMPLE: foreach my $s (@sample_oids) {
		    my $tx2 = $sample2taxon{ $s };
		    next if $tx2 ne $tx;
		    my @sgenes = split("\t", $sample2genes{ $s });
                    foreach my $g (@sgenes) {
                        if ($g eq $gene_oid) {
			    $cog2genes{ $s.$cog_fn } .= $gene_oid."\t";
                            next SAMPLE;
                        }
                    }
                }
	    }
	    $cur->finish();

            my $sql = qq{
                select distinct cf.function_code, cf.definition
                from gene_cog_groups gcg,
                     cog_functions cfs, cog_function cf
                where gcg.cog = cfs.cog_id
                and cfs.functions = cf.function_code
                and gcg.taxon = ?
            };
            my $cur = execSql( $dbh, $sql, $verbose, $tx );
            for ( ;; ) {
                my ( $cog_fn, $cog_def ) = $cur->fetchrow();
                last if !$cog_fn;

                my %unique_genes;
		foreach my $s (@sample_oids) {
		    my $geneStr = $cog2genes{ $s.$cog_fn };
                    chop $geneStr;
                    my @sgenes = split("\t", $geneStr);
                    foreach my $g (@sgenes) {
                        $unique_genes{ $g } = 1;
                    }
                }

                my $gene_count = scalar keys %unique_genes;
		my $key = "$cog_fn\t$cog_def";
		if (exists $cog_hash{ $key }) {
		    my $gcnt = $cog_hash{ $key };
		    $cog_hash{ $key } = $gene_count + $gcnt;
		} else {
		    $cog_hash{ $key } = $gene_count if $gene_count > 0;
		}
            }
            $cur->finish();
	}
    } # end of foreach taxon

    printEndWorkingDiv();

    my $metric = param( "metric" );
    my $total1;  # ref
    my $total2;

    use TabHTML;
    TabHTML::printTabAPILinks("imgTab");
    my @tabIndex = ( "#tab1", "#tab2" );
    my @tabNames = ( "By KEGG", "By COG" );
    TabHTML::printTabDiv("imgTab", \@tabIndex, \@tabNames);

    print "<div id='tab1'><p>\n";
    my $it = new InnerTable(1, "bykeggfunc$$", "bykeggfunc", 0);
    my $sd = $it->getSdDelim();

    # in the future, add all functions for a category to function cart:
    # $it->addColSpec( "Select" );

    $it->addColSpec( "KEGG Pathway", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Gene Count", "asc", "right", "", "", "wrap" );
    foreach my $s( @sample_oids ) {
	$it->addColSpec( "Gene Count<br/>".$sampleNames{$s}." [$s]",
			 "asc", "right", "", "", "wrap" );
	if ($normalization eq "coverage") {
	    $it->addColSpec
		( "Average Expression<br/>".$sampleNames{$s}." [".$s."]",
		  "desc", "right", "",
		  "Average Normalized Coverage<sup>1</sup>"
	        . " * 10<sup>9</sup> for: "
	        . $sampleNames{$s}, "wrap" );
	} else {
	    $it->addColSpec
		( "Average Expression<br/>".$sampleNames{$s}." [".$s."]",
		  "desc", "right", "",
		  "Average Normalized ($normalization) "
	        . "Expression Data<sup>1</sup><br/>for: "
	        . $sampleNames{$s}, "wrap" );
	}
	#$it->addColSpec
	#    ( $sampleNames{$s}." [".$s."]<br/>Raw Count",
	#      "desc", "right", "", "Raw Count (Reads) for: "
	#    . $sampleNames{$s}, "wrap" );
    }
    if ($pairwise ne "") {
	$it->addColSpec( $metric, "desc", "right" );
    }

    foreach my $r (keys %kegg_hash) {
        my ($pathway, $image_id) = split(/\t/, $r);
	my $gene_count = $kegg_hash{ $r };

        my $url = "$main_cgi?section=PathwayMaps"
                . "&page=keggMapSamples&map_id=$image_id"
		. "&study=$study&samples=$sample_oid_str";

        my $row;
#        my $row = $sd."<input type='checkbox' "
#	    . "name='func_id' value='$image_id'/>\t";
        $row .= $pathway.$sd.alink($url, $pathway, "_blank", 0, 1)."\t";
        $row .= $gene_count."\t";

        my $idx=0;
        foreach my $s( @sample_oids ) {
            my $geneStr = $pathw2genes{ $s.$image_id };
            chop $geneStr;

	    my $taxon_oid = $sample2taxon{ $s };
	    my $group_url = "$section_cgi&page=geneGroup"
		. "&proposal=$proposal&sample=$s"
		. "&taxon_oid=$taxon_oid"
		. "&fn_id=$image_id&fn=kegg";
            my @gene_group = split("\t", $geneStr);
	    my $group_count = scalar(@gene_group);
            if ($group_count == 0) {
                $row .= $group_count."\t";
            } else {
                $row .= $group_count.$sd
                    .alink($group_url, $group_count, "_blank", 0, 1)."\t";
            }

            my $total = 0;
            my $profile = $sampleProfiles{ $s };
            GENE: foreach my $gene( @gene_group ) {
		my $coverage = $profile->{ $gene };
		if ($normalization eq "coverage") {
		    $coverage = $coverage * 10**9;
		}
		if ($coverage eq "0" || $coverage eq "") {
		    next GENE if ($nSamples == 1 || $pairwise ne "");
		    $coverage = sprintf("%.3f", $coverage);
		} else {
		    $coverage = sprintf("%.3f", $coverage);
		}
                $total = $coverage + $total;
            }

	    # need to change to average expression sprintf
	    my $average = 0;
	    if ($group_count > 0) {
		$average = $total/$group_count;
		$average = sprintf("%.3f", $average);
	    }
            $row .= "$average\t";

	    if ($pairwise ne "") {
		if ($idx == 0) {
		    $total1 = $total;
		} else {
		    $total2 = $total;
		}
	    }
            $idx++;
	}

	if ($pairwise ne "") {
 	    my $delta;
            if ($metric eq "logR") {
                if (abs($total1) == $total1 &&
                    abs($total2) == $total2 &&
		    abs($total1) > 0 && abs($total2) > 0) {
                    # check for bad (negative) values - these seem
                    # to show up during affine normalization
                    $delta = log($total2/$total1)/log(2);
                }
            } elsif ($metric eq "RelDiff") {
                $delta = 2*($total2 - $total1)/($total2 + $total1);
            }
            $delta = sprintf("%.5f", $delta);
	    $row .= "$delta\t";
	}
        $it->addRow($row);
    }

    $it->printOuterTable(1);
    print "</p></div>\n"; # keggs div

    print "<div id='tab1'><p>\n";
    my $it = new InnerTable(1, "bycogfunc$$", "bycogfunc", 0);
    my $sd = $it->getSdDelim();

    # in the future, add all functions for a category to function cart:
    # $it->addColSpec( "Select" );

    $it->addColSpec( "COG Function", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Gene Count", "asc", "right", "", "", "wrap" );
    foreach my $s( @sample_oids ) {
	$it->addColSpec( "Gene Count<br/>".$sampleNames{$s}." [$s]",
			 "asc", "right", "", "", "wrap" );
        if ($normalization eq "coverage") {
            $it->addColSpec
                ( "Average Expression<br/>".$sampleNames{$s}." [".$s."]",
                  "desc", "right", "",
                  "Average Normalized Coverage<sup>1</sup>"
                  . " * 10<sup>9</sup> for: "
                  . $sampleNames{$s}, "wrap" );
        } else {
            $it->addColSpec
                ( "Average Expression<br/>".$sampleNames{$s}." [".$s."]",
                  "desc", "right", "",
                  "Average Normalized ($normalization) "
                  . "Expression Data<sup>1</sup><br/>for: "
                  . $sampleNames{$s}, "wrap" );
        }
    }
    if ($pairwise ne "") {
        $it->addColSpec( $metric, "desc", "right" );
    }

    foreach my $r (keys %cog_hash) {
        my ($cog_fn, $cog_def) = split(/\t/, $r);
        my $gene_count = $cog_hash{ $r };

	my $url = "$main_cgi?section=CogCategoryDetail"
	        . "&page=cogCategoryDetailForSamples"
		. "&function_code=$cog_fn"
		. "&taxon_oid=$taxon_oid"
		. "&study=$study&samples=$sample_oid_str";

        my $row;
#        my $row = $sd."<input type='checkbox' "
#	    . "name='func_id' value='$cog_fn'/>\t";
	$row .= $cog_def.$sd.alink($url, $cog_fn, "_blank", 0, 1)
	      . " - ".$cog_def."\t";
        $row .= $gene_count."\t";

	my $idx=0;
        foreach my $s( @sample_oids ) {
	    my $geneStr = $cog2genes{ $s.$cog_fn };
	    chop $geneStr;

	    my $taxon_oid = $sample2taxon{ $s };
            my $group_url = "$section_cgi&page=geneGroup"
                . "&proposal=$proposal&sample=$s"
                . "&taxon_oid=$taxon_oid"
		. "&fn_id=$cog_fn&fn=cog";
            my @gene_group = split("\t", $geneStr);
            my $group_count = scalar(@gene_group);
            $row .= $group_count.$sd
                .alink($group_url, $group_count, "_blank", 0, 1)."\t";

	    my $total=0;
            my $profile = $sampleProfiles{ $s };
	    GENE: foreach my $gene( @gene_group ) {
		my $coverage = $profile->{ $gene };
		if ($normalization eq "coverage") {
		    $coverage = $coverage * 10**9;
		}
		if ($coverage eq "0" || $coverage eq "") {
		    next GENE if ($nSamples == 1 || $pairwise ne "");
		    $coverage = sprintf("%.3f", $coverage);
		} else {
		    $coverage = sprintf("%.3f", $coverage);
		}
		$total = $coverage + $total;
	    }

	    # need to change to average expression sprintf
	    my $average = 0;
	    if ($group_count > 0) {
		$average = $total/$group_count;
		$average = sprintf("%.3f", $average);
	    }
            $row .= "$average\t";

            if ($pairwise ne "") {
                if ($idx == 0) {
                    $total1 = $total;
                } else {
                    $total2 = $total;
                }
            }
            $idx++;
        }

        if ($pairwise ne "") {
            my $delta;
            if ($metric eq "logR") {
                if (abs($total1) == $total1 &&
                    abs($total2) == $total2 &&
		    abs($total1) > 0 && abs($total2) > 0) {
                    # check for bad (negative) values - these seem
                    # to show up during affine normalization
                    $delta = log($total2/$total1)/log(2);
                }
            } elsif ($metric eq "RelDiff") {
                $delta = 2*($total2 - $total1)/($total2 + $total1);
            }
            $delta = sprintf("%.5f", $delta);
            $row .= "$delta\t";
        }
        $it->addRow($row);
    }

    $it->printOuterTable(1);
    print "</p></div>\n"; # cogs div

    #$dbh->disconnect();
    TabHTML::printTabDivEnd();
    printNotes("studysamples");
    printStatusLine("Loaded.", 2);
}

############################################################################
# printGeneGroup - prints a table of genes with gene info
############################################################################
sub printGeneGroup {
    my $taxon_oid = param("taxon_oid");
    my $sample = param("sample");
    my $proposal = param("proposal");
    my $fn_id = param("fn_id");
    my $fn = param("fn");
    my $id = param("id");

    printStatusLine("Loading ...", 1);
    my $dbh = dbLogin();

    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select dts.gold_id, gsp.display_name,
               tx.taxon_display_name, tx.genome_type, tx.in_file
        from rnaseq_dataset dts, taxon tx,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.gold_id = gsp.gold_id
        and dts.dataset_oid = ?
        and dts.reference_taxon_oid = ?
        and dts.reference_taxon_oid = tx.taxon_oid
        $datasetClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $sample, $taxon_oid );
    my ($gold_id, $sample_desc,
	$taxon_name, $genome_type, $in_file) = $cur->fetchrow();
    $cur->finish();

    my $sql;
    my $fn_str;
    if ($fn eq "kegg") {
	my $kegg_sql = qq{
	    select pw.pathway_name
            from kegg_pathway pw
	    where pw.image_id = ?
	};
	my $cur = execSql( $dbh, $kegg_sql, $verbose, $fn_id );
	my ($pathway_name) = $cur->fetchrow();
	$cur->finish();

	$fn_str = "<u>Function (KEGG)</u>: $pathway_name";

	$sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
    	           g.locus_tag, g.product_name, g.DNA_seq_length
            from kegg_pathway pw, image_roi roi, image_roi_ko_terms irk,
                 gene g, gene_ko_terms gkt
            where pw.pathway_oid = roi.pathway
            and roi.roi_id = irk.roi_id
            and irk.ko_terms = gkt.ko_terms
            and gkt.gene_oid = g.gene_oid
	    and pw.image_id = ?
        };

    } elsif ($fn eq "cog") {
	my $cog_sql = qq{
	    select cf.definition
	    from cog_function cf
	    where cf.function_code = ?
	};
        my $cur = execSql( $dbh, $cog_sql, $verbose, $fn_id );
        my ($definition) = $cur->fetchrow();
        $cur->finish();

	$fn_str = "<u>Function (COG)</u>: $definition";
	$fn_str = $fn_str." <u>$id</u>" if $id ne "";
	my $idclause = "";
	$idclause = "and c.cog_id = '$id'" if $id ne "";

	$sql = qq{
            select distinct g.gene_oid, g.gene_display_name,
	           g.locus_tag, g.product_name, g.DNA_seq_length
            from gene g, gene_cog_groups gcg, cog c,
                 cog_functions cfs, cog_function cf
            where g.gene_oid = gcg.gene_oid
            and gcg.cog = c.cog_id
            and c.cog_id = cfs.cog_id
            and cfs.functions = ?
            $idclause
        };
    }

    my %geneInfo;
    if ($genome_type eq "metagenome") {
	my %gene2info = MetaUtil::getGenesForRNASeqSample($sample, $taxon_oid);
	my %prodNames = MetaUtil::getGeneProdNamesForTaxon($taxon_oid, "assembled");

	if ($fn eq "kegg") {
    	my %all_kos = MetaUtil::getTaxonFuncCount
	    ($taxon_oid, 'assembled', 'ko');
        my $ksql = qq{
            select distinct pw.pathway_name, pw.image_id, irk.ko_terms
            from kegg_pathway pw, image_roi roi, image_roi_ko_terms irk
            where pw.pathway_oid = roi.pathway
            and roi.roi_id = irk.roi_id
            and pw.image_id = ?
            order by irk.ko_terms
        };
        my $cur = execSql( $dbh, $ksql, $verbose, $fn_id );
        for ( ;; ) {
            my ( $pathway_name, $image_id, $ko ) = $cur->fetchrow();
            last if !$ko;
            next if (!$all_kos{$ko});
            #next if (!$all_kegg_pathways{$pathway_oid});

            my %ko_genes = MetaUtil::getTaxonFuncGenes($taxon_oid, "assembled", $ko);
            my @gene_group = keys %ko_genes;
            next if (scalar @gene_group == 0);

            foreach my $gene ( @gene_group ) {
		next if (!exists $gene2info{ $gene });
                my $line = $gene2info{ $gene };
                my ($geneid, $locus_type, $locus_tag, $strand,
                    $scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
                    = split("\t", $line);
                next if (! $reads_cnt > 0.0000000);

                my $product = $prodNames{ $gene };
		$product = "hypothetical protein" if $product eq "";
                $geneInfo{ $gene } =
                    "$product\t$locus_tag\t$product\t$dna_seq_length";
            }
	}

	} elsif ($fn eq "cog") {
	    my %all_cogs = MetaUtil::getTaxonFuncCount
		($taxon_oid, 'assembled', 'cog');
	    my $idclause = "";
	    $idclause = "and cfs.cog_id = '$id'" if $id ne "";

	    my $csql = qq{
                select cf.function_code, cfs.cog_id
                from cog_function cf, cog_functions cfs
                where cf.function_code = cfs.functions
                and cf.function_code = ?
                $idclause
                order by cfs.cog_id
            };
	    my $cur = execSql( $dbh, $csql, $verbose, $fn_id );
	    for ( ;; ) {
		my ( $func_code, $cog_id ) = $cur->fetchrow();
		last if !$cog_id;
		next if (!$all_cogs{$cog_id});

		my %cog_genes = MetaUtil::getTaxonFuncGenes
		    ($taxon_oid, "assembled", $cog_id);
		my @gene_group = keys %cog_genes;
		next if (scalar @gene_group == 0);

		foreach my $gene ( @gene_group ) {
		    next if (!exists $gene2info{ $gene });

		    my $line = $gene2info{ $gene };
		    my ($geneid, $locus_type, $locus_tag, $strand,
			$scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
			= split("\t", $line);
		    next if (! $reads_cnt > 0.0000000);

		    my $product = $prodNames{ $gene };
		    $geneInfo{ $gene } =
			"$product\t$locus_tag\t$product\t$dna_seq_length";
		}
	    }
	}

    } else {
	# get the genes for this dataset:
	my @genes;
	my %dataset_genes;
	my ($total_gene_cnt, $total_read_cnt) =
	    MetaUtil::getCountsForRNASeqSample($sample, $taxon_oid);

	if ($total_gene_cnt > 0) { # found
	    my %gene2info =
		MetaUtil::getGenesForRNASeqSample($sample, $taxon_oid);
	    @genes = keys %gene2info;
	    %dataset_genes = %gene2info;

	} else {
	    # anna: genes and reads should come from sdb
	    # anna: will remove when rnaseq_expression is cleaned out
	    my $sql = qq{
                select es.IMG_gene_oid
                from rnaseq_expression es
                where es.dataset_oid = ?
            };
	    my $cur = execSql( $dbh, $sql, $verbose, $sample );
	    for ( ;; ) {
		my ($gene) = $cur->fetchrow();
		last if !$gene;
		push @genes, $gene;
		$dataset_genes{ $gene } = 1;
	    }
	}

	my $cur = execSql( $dbh, $sql, $verbose, $fn_id );
	for ( ;; ) {
	    my ($gene, $gene_name, $locus_tag, $product, $dna_seq_length)
		= $cur->fetchrow();
	    last if !$gene;
	    next if (!exists $dataset_genes{ $gene });
	    $geneInfo{ $gene } =
		"$gene_name\t$locus_tag\t$product\t$dna_seq_length";
	}
	$cur->finish();
    }

    print "<h1>RNASeq Expression for Function</h1>\n";
    my $url = "$section_cgi&page=sampledata&sample=$sample";
    print "<p><u>Sample</u>: ".alink($url, $sample_desc, "_blank");
    if (!blankStr($gold_id)) {
        my $url = HtmlUtil::getGoldUrl($gold_id);
	print " [".alink($url, $gold_id, "_blank")."]";
    }
    print "<br/>\n";

    print "$fn_str<br/>";
    if ($proposal ne "") {
	my $expurl = "$section_cgi&page=samplesByProposal"
	    . "&proposal=$proposal&genomes=1";
	print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
    }
    print "</p>";

    printMainForm();

    my $it = new InnerTable(1, "genegroupfn$$", "genegroupfn", 1);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Product Name", "asc", "left" );

    foreach my $gene (keys %geneInfo) {
        my ($gene_name, $locus_tag, $product, $dna_seq_length)
	    = split("\t", $geneInfo{ $gene });
	$product = "hypothetical protein" if $product eq "";

        my $url1 = "$main_cgi?section=GeneDetail"
	         . "&page=geneDetail&gene_oid=$gene";
	my $genelink = $gene;
	if ($genome_type eq "metagenome") {
	    $url1 = "$main_cgi?section=MetaGeneDetail"
		  . "&page=metaGeneDetail&gene_oid=$gene"
		  . "&data_type=assembled&taxon_oid=$taxon_oid";
	    $genelink = "$taxon_oid assembled $gene";
	}

	my $row = $sd."<input type='checkbox' "
		. "name='gene_oid' value='$genelink'/>\t";
        $row .= $gene.$sd.alink($url1, $gene, "_blank")."\t";
        $row .= $locus_tag."\t";
        $row .= $product."\t";
        $row .= $dna_seq_length."\t";
        $it->addRow($row);
    }

    printGeneCartFooter();
    $it->printOuterTable(1);
    printGeneCartFooter();

    print end_form();
    printStatusLine("Loaded.", 2);
}

############################################################################
# printDescribeSamples - compares selected samples per gene: coverage,
#                        COG function, KEGG pathways
############################################################################
sub printDescribeSamples {
    my ($type) = @_;

    my @sample_oids = param("exp_samples");
    if ($type eq "describe_one") {
	@sample_oids = (@sample_oids[0]);
    }
    my $nSamples = @sample_oids;
    my $proposal = param("proposal");
    my $taxon_oid = param("taxon_oid");
    my $in_file = param("in_file");

    my $normalization = param("normalization");
    if ($nSamples == 1) {
	$normalization = "coverage";
    }
    my $min_abundance = param("min_num");
    if ($min_abundance < 3 || $min_abundance > $nSamples) {
        $min_abundance = 3;
    }
    my $showall = 0;
    if ($type eq "describe_clustered") {
	if ($nSamples < 3) {
	    webError( "Please select at least 3 samples." );
	}
    } else {
	if ($nSamples < 1) {
	    webError( "Please select at least 1 sample." );
	}
	$showall = 1 if $nSamples < 3; # no need to check
    }

    my $cart_genes = param("describe_cart_genes");
    my @cart_gene_oids;
    if ($cart_genes) {
	use GeneCartStor;
	my $gc = new GeneCartStor();
	my $recs = $gc->readCartFile(); # get records
	@cart_gene_oids = sort { $a <=> $b } keys(%$recs);
	if (scalar @cart_gene_oids < 1) {
	    webError( "Your Gene Cart is empty." );
	}
    }

    printStatusLine("Loading ...", 1);
    my $dbh = dbLogin();

    my %sampleNames;
    my %sampleNotes;
    my %taxon_hash;

    my $sample_oid_str = join(",", @sample_oids);

    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select dts.dataset_oid, dts.gold_id,
               gsp.display_name, dts.reference_taxon_oid,
               tx.taxon_display_name, tx.in_file, tx.genome_type
        from rnaseq_dataset dts, taxon tx,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.dataset_oid in ($sample_oid_str)
        and dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = tx.taxon_oid
        $datasetClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my ($sid, $gold_id, $sample_desc, $taxon, $taxon_name,
	    $in_file, $genome_type) = $cur->fetchrow();
	last if !$sid;
	$sampleNames{$sid} = $sample_desc;
	$sampleNotes{$sid} = $gold_id;
	$taxon_hash{$taxon} = $in_file."\t".$genome_type."\t".$taxon_name;
    }
    $cur->finish();

    my @taxons = keys %taxon_hash;
    $taxon_oid = @taxons[0] if (scalar @taxons == 1);

    if ($nSamples == 1 && $taxon_oid ne "") {
	print "<h1>RNASeq Expression Data for Selected Sample</h1>";
        if ($cart_genes && (scalar @cart_gene_oids > 0)) {
            print "<p>*Showing only genes from gene cart</p>";
        }
	my $url = "$main_cgi?section=TaxonDetail&page=scaffolds"
	        . "&taxon_oid=$taxon_oid"
	        . "&study=$study&sample=@sample_oids[0]";
	my ($infile, $gtype, $name) = split("\t", $taxon_hash{ $taxon_oid });
	$in_file = $infile;
	if ($gtype eq "metagenome") {
	    $url = "$main_cgi?section=MetaDetail&page=scaffolds"
	         . "&taxon_oid=$taxon_oid"
	         . "&study=$study&sample=@sample_oids[0]";
	}
	print buttonUrl( $url, "Chromosome Viewer", "smbutton" );

	print "<p style='width: 950px;'>";
	if ($proposal ne "") {
	    print "<span style='font-size: 12px; "
		. "font-family: Arial, Helvetica, sans-serif;'>\n";
	    my $expurl = "$section_cgi&page=samplesByProposal"
		       . "&proposal=$proposal&genomes=1";
	    print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
	    print "</span>\n";
	    print "<br/>";
	}

        my $url = "$main_cgi?section=TaxonDetail"
                . "&page=taxonDetail&taxon_oid=$taxon_oid";
        print "<u>Genome</u>: ".alink($url, $name, "_blank");

	my $sname = $sampleNames{ @sample_oids[0] };
	my $url = "$section_cgi&page=sampledata&sample=@sample_oids[0]";
	print "<br/><u>Sample</u>: ".alink($url, $sname);

	my $note = $sampleNotes{ @sample_oids[0] };
	if (!blankStr($note)) {
	    my $url = HtmlUtil::getGoldUrl($note);
	    print " [".alink($url, $note, "_blank")."]";
	}
	print "</p>\n";

    } else { # ANNA:TODO - fix taxons
	print "<h1>RNASeq Expression Data for Selected Samples</h1>\n";

	print "<p style='width: 950px;'>";
        if ($proposal ne "") {
	    print "<span style='font-size: 12px; "
		. "font-family: Arial, Helvetica, sans-serif;'>\n";
            my $expurl = "$section_cgi&page=samplesByProposal"
                       . "&proposal=$proposal&genomes=1";
            print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
	    print "</span>\n";
	    print "<br/>";
        }

	if ($taxon_oid ne "") {
	    my ($infile, $gtype, $name) =
		split("\t", $taxon_hash{ $taxon_oid });
	    $in_file = $infile;
	    my $url = "$main_cgi?section=TaxonDetail"
                    . "&page=taxonDetail&taxon_oid=$taxon_oid";
	    print "<u>Genome</u>: ".alink($url, $name, "_blank");
	    print "<br/>";
	}
	print "<u>Normalization</u>: $normalization";
	print "<br/>$nSamples sample(s) selected";
	if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	    print "<br/>*Showing only genes from gene cart";
	}
	print "</p>\n";
    }

    my $tmpOutputFileName;
    my %clusteredData;
    my %uniqueClusters;
    my %color_hash;
    my @color_array;
    my $im = new GD::Image( 10, 10 );

    my ($names_ref, $notes_ref, $profiles_ref, $gid_ref,
	$gprofile, $raw_profiles_ref);

    if ($type eq "describe_clustered") {
	my $threshold = param("cluster_threshold");
	if ($threshold eq "") {
	    $threshold = 0.8;
	}
	my $method = param("method");
	$method =~ /([msca])/;
	$method = $1;
	if ($method eq "") {
	    $method = "m";
	}
	# new clustering method : need to map
	# params from Cluster 3.0 to those used by hclust
	if ($method eq "m") {
	    $method = "complete";
	} elsif ($method eq "s") {
	    $method = "single";
	} elsif ($method eq "c") {
	    $method = "centroid";
	} elsif ($method eq "a") {
	    $method = "average";
	}
	$method = checkPath($method);

	my $correlation = param("correlation");
	$correlation =~ /([0-8])/;
	$correlation = $1;
	if ($correlation eq "") {
	    $correlation = 2;
	}
	if ($correlation eq "2") {
	    $correlation = "pearson";
	} elsif ($correlation eq "5") {
	    $correlation = "spearman";
	} elsif ($correlation eq "7") {
	    $correlation = "euclidean";
	} elsif ($correlation eq "8") {
	    $correlation = "manhattan";
	}
	$correlation = checkPath($correlation);

	print "<p>\n";
	if ($nSamples < 8) {
	    print "<u>Note</u>: selecting too few conditions may result "
		. "in skewed clusters.<br/>";
	}

        print "Each gene is set to appear in at least "
            . "$min_abundance (out of $nSamples) samples.<br/>";
	print "Clustering samples (and genes) ... using log values<br/>\n";
	print "Cut-off threshold set to: $threshold";
	print "</p>";

	printStartWorkingDiv();

	# make an input file:
	print "<p>Making profile file...<br/>";
	my $inputFile = "$tmp_dir/profile$$.tab.txt";
	($names_ref, $notes_ref, $profiles_ref, $gid_ref,
	 $gprofile, $raw_profiles_ref)
	    = makeProfileFile($dbh, $inputFile, $normalization,
			      \@sample_oids, $sample_oid_str,
			      \@cart_gene_oids, 0, $in_file, 0, 1);

        my $program = "$cgi_dir/bin/hclust2CDT_cutTree.R";
	my $groups = 1;
	my $inputFileRoot = "$tmp_dir/cluster$$";
	$threshold = checkPath($threshold);

        WebUtil::unsetEnvPath();
        print "Running hclust...<br/>";
        #my $environ = "PATH='/bin:/usr/bin'; export PATH";
        my $cmd = "$R --slave --args "
                . "$inputFile $correlation $method $groups "
		. "$threshold $inputFileRoot 1 "
		. "< $program > /dev/null";
	print "Command: $cmd <br/>";
        my $st = system($cmd);
        WebUtil::resetEnvPath();

	if ($st != 0) {
	    printEndWorkingDiv();
	    #$dbh->disconnect();
	    webError( "Problem running R script: $program." );
	}

	$tmpOutputFileName = "cluster$$.groups.txt";
	my $tmpOutputFile = "$tmp_dir/cluster$$.groups.txt";

	my $rfh = newReadFileHandle
	    ( $tmpOutputFile, "describeClustered" );
	my $i = 0;
	while( my $s = $rfh->getline() ) {
	    $i++;
	    next if $i == 1;
	    chomp $s;

	    my( $gid, $value ) = split( / /, $s );
	    $gid =~ s/"//g;
	    $clusteredData{ $gid } = $value;
            $uniqueClusters{ $value } = 1;
	}
	close $rfh;

        my $colors;
        @color_array = loadMyColorArray($im, $color_array_file);
        print "Loading colors...<br/>";

        my @clusters = sort keys( %uniqueClusters );
        my $nClusters = scalar @clusters;
        my $n = ceil($nClusters/255);
        my $i = 0;
        foreach my $cluster (@clusters) {
            #my $idx = ceil($i/$n);
            #$color_hash{ $cluster } = $color_array[ $idx ];
            if ($i == 246) { $i = 0; }
	    $color_hash{ $cluster } = $color_array[ $i ];
            $i++;
        }
	print "Querying for data...<br/>";

    } else {
	# make an input file:
	printStartWorkingDiv();
	print "Making profile file...<br/>";

	my $inputFile = "$tmp_dir/profile$$.tab.txt";
	($names_ref, $notes_ref, $profiles_ref, $gid_ref,
	 $gprofile, $raw_profiles_ref)
	    = makeProfileFile($dbh, $inputFile, $normalization,
			      \@sample_oids, $sample_oid_str,
			      \@cart_gene_oids, 0, $in_file, $showall, 1);
    }

    my %sampleProfiles = %$profiles_ref;
    my %sampleProfilesRaw = %$raw_profiles_ref;
    my @geneIds = @$gid_ref;
    my %geneProfile;

    my %gene2pathw;
    my %gene2module;
    my %gene2ec;
    my %gene2cog;

    my ($in_file, $genome_type, $taxon_name) =
	split("\t", $taxon_hash{ $taxon_oid });

    if ($in_file eq "Yes") { # ANNA:TODO - fix taxons
	%geneProfile = %$gprofile;

        print "<br/>Getting pathway info (FS) ... $taxon_oid";
        my %all_kegg_pathways = MetaUtil::getTaxonFuncCount
	    ($taxon_oid, 'assembled', 'kegg_pathway');
        my %all_kos = MetaUtil::getTaxonFuncCount($taxon_oid, 'assembled', 'ko');
        my %all_ecs = MetaUtil::getTaxonFuncCount($taxon_oid, 'assembled', 'ec');

        print "<br/>Getting KO and EC info (FS) ...";
	# try to first get all MER-FS pathways for this taxon
	# then, find the associated ko and genes
	my @kos = sort keys (%all_kos);
	my @pws = sort keys (%all_kegg_pathways);
	my $pws_str;
	if (OracleUtil::useTempTable(scalar @pws)) {
	    OracleUtil::insertDataArray($dbh, "gtt_func_id", \@pws);
	    $pws_str = "select id from gtt_func_id";
	} else {
	    $pws_str = join( ',', @pws );
	}

	print "<br/>Got ".(scalar @pws)." pathways and ".(scalar @kos)." KOs";
	print "<br/>Querying for pathway info via KO (FS)...";

        my $ksql = qq{
            select distinct pw.pathway_name, pw.image_id, irk.ko_terms
            from kegg_pathway pw, image_roi_ko_terms irk, image_roi ir
            where pw.pathway_oid = ir.pathway
            and ir.roi_id = irk.roi_id
            and pw.pathway_oid in ($pws_str)
        };

        my $cur = execSql( $dbh, $ksql, $verbose );
	my %ko2pw;
        for ( ;; ) {
            my ( $pathway_name, $image_id, $ko ) = $cur->fetchrow();
            last if !$image_id;
	    last if !$ko;
            next if ($image_id eq 'map01100');
            next if (!$all_kos{$ko});
	    $ko2pw{ $ko } .= $pathway_name."\t".$image_id."#";
	}
	OracleUtil::truncTable($dbh, "gtt_func_id"); # clean up temp table
	$cur->finish();

	my $totalko = scalar keys (%ko2pw);
	print "<br/>Total KO: $totalko";
	print "<br/>Getting genes for each KO (MER-FS)...";

	my $count = 0;
	foreach my $k (@kos) {
	    if ($count % 100 == 0) {
		print "<br/>Getting genes for KO $k...";
	    }
	    my $pw = $ko2pw{ $k };

        my %ko_genes = MetaUtil::getTaxonFuncGenes($taxon_oid, "assembled", $k);
        my @gene_group = keys %ko_genes;

        foreach my $gene_oid (@gene_group) {
            $gene2pathw{ $gene_oid } = $pw;
        }
	    $count++;
	}

	print "<br/>Getting genes for each EC (MER-FS)...";
	foreach my $ec (keys %all_ecs) {
	    my %ec_genes = MetaUtil::getTaxonFuncGenes($taxon_oid, "assembled", $ec);
	    my @gene_group = keys %ec_genes;
	    foreach my $gene_oid (@gene_group) {
		$gene2ec{ $gene_oid } = $ec;
	    }
	}

        print "<br/>Getting COG info (FS) ...";
        my %all_cogs = MetaUtil::getTaxonFuncCount
	    ($taxon_oid, 'assembled', 'cog');
        my $csql = qq{
            select cf.function_code, cf.definition, cfs.cog_id
            from cog_function cf, cog_functions cfs
            where cf.function_code = cfs.functions
            order by cf.function_code
        };
        my $cur = execSql( $dbh, $csql, $verbose );

        my %done;
        for ( ;; ) {
            my ( $cog_fn, $cog_fn_def, $cog_id ) = $cur->fetchrow();
            last if !$cog_fn;
            next if (!$all_cogs{$cog_id});

            my %cog_genes = MetaUtil::getTaxonFuncGenes
		($taxon_oid, "assembled", $cog_id);
            my @gene_group = keys %cog_genes;
    	    foreach my $gene_oid (@gene_group) {
		next if $done{ "$gene_oid"."$cog_fn" };
		$gene2cog{ $gene_oid } .= $cog_fn."\t".$cog_fn_def."#";
		$done{ "$gene_oid"."$cog_fn" } = 1;
    	    }
    	}

    } else {
	if (scalar (keys %$gprofile) > 0) {
	    %geneProfile = %$gprofile;
	} else {
	    ## Template of all genes:
	    print "Querying for gene profile...<br/>";

	    my $sql = qq{
            select distinct es.IMG_gene_oid, es.dataset_oid,
	    g.gene_display_name, g.locus_tag, g.product_name,
            g.DNA_seq_length, gcg.cassette_oid
            from rnaseq_expression es, gene g
	    left join gene_cassette_genes gcg
	    on gcg.gene = g.gene_oid
            where es.dataset_oid in ($sample_oid_str)
	    and es.IMG_gene_oid = g.gene_oid
            and es.reads_cnt > 0.0000000
            order by es.IMG_gene_oid
            };
	    my $cur = execSql( $dbh, $sql, $verbose );
	    for( ;; ) {
		my( $gid, $sample, $gene_name, $locus_tag, $product,
		    $dna_seq_length, $cassette ) = $cur->fetchrow();
		last if !$gid;
		$geneProfile{ $gid } =
		"$gene_name\t$locus_tag\t$product\t$dna_seq_length\t$cassette";
	    }
	    $cur->finish();
	}

	my @genes = keys( %geneProfile );
	my $idsInClause = OracleUtil::getNumberIdsInClause($dbh, @genes);

        print "Querying for EC...<br/>";

	my $gidsClause;
	$gidsClause = " and gke.gene_oid in ($idsInClause) "
	    if scalar @genes > 0;

        my $sql = qq{
            select gke.gene_oid, ez.ec_number, ez.enzyme_name
            from gene_ko_enzymes gke, enzyme ez
            where gke.enzymes = ez.ec_number
            $gidsClause
        };
        my $cur = execSql( $dbh, $sql, $verbose );
        for( ;; ) {
            my ($gene_oid, $ec, $ecname) = $cur->fetchrow();
            last if !$gene_oid;
            $gene2ec{ $gene_oid } = $ec;
        }
        $cur->finish();

	print "Querying for KEGG pathways and modules...<br/>";

	my $gidsClause;
	$gidsClause = " and gkmp.gene_oid in ($idsInClause) "
	    if scalar @genes > 0;
	# FIXME : do in query for genes - no genes in rnaseq_expression -Anna
	# get the kegg pathways
        my $sql = qq{
            select distinct gkmp.gene_oid,
                   pw.pathway_name, pw.image_id,
                   km.module_name, km.module_id
            from kegg_pathway pw,
                 dt_gene_ko_module_pwys gkmp
            left join kegg_module km on km.module_id = gkmp.module_id
            where pw.pathway_oid = gkmp.pathway_oid
            $gidsClause
            order by gkmp.gene_oid, km.module_name, pw.pathway_name
        };
	my $cur = execSql( $dbh, $sql, $verbose );

	my %done;
	for( ;; ) {
	    my ($gene_oid, $pathway_name, $image_id, $module, $module_id, $ec)
		= $cur->fetchrow();
	    last if !$gene_oid;
	    next if ($image_id eq 'map01100');
	    next if $done{ "$gene_oid"."$image_id"."$module" };

	    $gene2module{ $gene_oid } .=
		$module."\t".$pathway_name."\t".$image_id."#";
	    $gene2pathw{ $gene_oid } .=
		$pathway_name."\t".$image_id."#";
	    $done{ "$gene_oid"."$image_id"."$module" } = 1;
	}
	$cur->finish();

	print "Querying for COGs...<br/>";

	my $gidsClause;
	$gidsClause = " and gcg.gene_oid in ($idsInClause) "
	    if scalar @genes > 0;

	# get the cogs
	my $sql = qq{
            select distinct gcg.gene_oid, cf.function_code, cf.definition
            from gene_cog_groups gcg, cog c, cog_functions cfs,
                 cog_function cf, rnaseq_dataset dts
            where gcg.cog = c.cog_id and c.cog_id = cfs.cog_id
            $gidsClause
            and cfs.functions = cf.function_code
	    and dts.dataset_oid in ($sample_oid_str)
            and dts.reference_taxon_oid = gcg.taxon
            order by gcg.gene_oid, cf.function_code
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	my %done;
	for ( ;; ) {
	    my ( $gene_oid, $cog_fn, $cog_fn_def ) = $cur->fetchrow();
	    last if !$gene_oid;
	    next if $done{ "$gene_oid"."$cog_fn" };
	    $gene2cog{ $gene_oid } .= $cog_fn."\t".$cog_fn_def."#";
	    $done{ "$gene_oid"."$cog_fn" } = 1;
	}
	$cur->finish();

	OracleUtil::truncTable($dbh, "gtt_num_id");
    }

    printEndWorkingDiv();
    printMainForm();

    my $it = new InnerTable(1, "descsamples$$", "descsamples", 1);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc", "left", "", "", "wrap" );
    $it->addColSpec( "Product Name", "asc", "left" );
    if ($type eq "describe_clustered") {
	$it->addColSpec( "Cluster ID", "asc", "right", "", "", "wrap" );
    }
    foreach my $s( @sample_oids ) {
	if ($normalization eq "coverage") {
	    $it->addColSpec
		( $sampleNames{$s}." [".$s."]", "desc", "right", "",
		  "Normalized Coverage<sup>1</sup> * 10<sup>9</sup> for: "
		. $sampleNames{$s}, "wrap" );
	} else {
            $it->addColSpec
                ( $sampleNames{$s}." [".$s."]", "desc", "right", "",
                  "Normalized ($normalization) "
		. "Expression Data<sup>1</sup><br/>for: "
                . $sampleNames{$s}, "wrap" );
	}
	$it->addColSpec
	    ( $sampleNames{$s}." [".$s."]<br/>Raw Count", "desc", "right", "",
	      "Raw Count (Reads) for: "
	    . $sampleNames{$s}, "wrap" );
    }
    if ($in_file ne "Yes") {
	$it->addColSpec( "Cassette ID", "asc", "right", "", "", "wrap" );
    }
    $it->addColSpec( "COG function", "asc", "left" );
    $it->addColSpec( "KEGG pathway", "asc", "left" );
    $it->addColSpec( "EC Number", "asc", "left" );
    if ($in_file ne "Yes") {
	$it->addColSpec( "KEGG module", "asc", "left" );
    }

    my $count;
    GENE: foreach my $gene( @geneIds ) {
        my $url1 = "$main_cgi?section=GeneDetail"
                 . "&page=geneDetail&gene_oid=$gene";
	my $genelink = $gene;
	if ($genome_type eq "metagenome") {
	    $url1 = "$main_cgi?section=MetaGeneDetail"
		  . "&page=metaGeneDetail&gene_oid=$gene"
		  . "&data_type=assembled&taxon_oid=$taxon_oid";
	    $genelink = "$taxon_oid assembled $gene";
	}

	my $row = $sd."<input type='checkbox' "
	        . "name='gene_oid' value='$genelink'/>\t";
        $row .= $gene.$sd.alink($url1, $gene, "_blank")."\t";

	my ($product, $locus, $dna_seq_length, $cassette);
	if ($in_file eq "Yes" || scalar keys %$gprofile > 0) {
	    ($product, $locus, $product, $dna_seq_length)
		= split('\t', $geneProfile{$gene});
	} else {
	    ($product, $locus, $dna_seq_length, $cassette)
		= split('\t', $geneProfile{$gene});
	}
	$product = "hypothetical protein" if $product eq "";
        $row .= $locus.$sd.$locus."\t";
        $row .= $product.$sd.$product."\t";

	if ($type eq "describe_clustered") {
	    my $clusterid = $clusteredData{ $gene };
	    my $color  = $color_hash{ $clusterid };
	    my ( $r, $g, $b ) = $im->rgb( $color );

	    $row .= $clusterid.$sd;
            $row .= "<span style='border-right:1em solid rgb($r, $g, $b); "
		  . "padding-right:0.5em; margin-right:0.5em'> "
		  . "$clusterid</span>";
	    $row .= "\t";
	    #$row .= $clusterid.$sd.$clusterid."\t";
	}

        foreach my $sid (@sample_oids) {
            my $profile = $sampleProfiles{ $sid };
            my $coverage = $profile->{ $gene };
	    #if ($normalization eq "coverage") {
	    #	$coverage = $coverage * 10**9;
	    #}
            if ($coverage eq "0" || $coverage eq "") {
                next GENE if ($nSamples == 1);
                $coverage = sprintf("%.3f", $coverage);
                $row .= $coverage.$sd.
                    "<span style='background-color:lightgray; ";
                $row .= "'>";
                $row .= $coverage;
                $row .= "</span>\t";
            } else {
                $coverage = sprintf("%.3f", $coverage);
                $row .= $coverage.$sd.$coverage."\t";
            }
            my $profileRaw = $sampleProfilesRaw{ $sid };
            my $reads = $profileRaw->{ $gene };
	    $row .= $reads."\t";
        }

	if ($in_file ne "Yes") {
	    my $url4 = "$main_cgi?section=GeneCassette"
		. "&page=cassetteBox&gene_oid=$gene&cassette_oid=$cassette";
	    $row .= $cassette.$sd.alink($url4, $cassette, "_blank")."\t";
	}

	my $allcogs = $gene2cog{ $gene };
	my @cogs = split('#', $allcogs);
	my $s;
	foreach my $item(@cogs) {
	    my ($c, $desc) = split('\t', $item);
	    my $url2 = "$main_cgi?section=CogCategoryDetail"
		     . "&page=cogCategoryDetailForSamples"
		     . "&function_code=$c"
		     . "&taxon_oid=$taxon_oid"
		     . "&study=$study&samples=$sample_oid_str";
	    $s .= alink($url2, $c, "_blank", 0, 1)." - ".$desc."<br/>";
	}
	chop $s;
	$row .= $s.$sd.$s."\t";

	my $allpathw = $gene2pathw{ $gene };
	my @pathways = split('#', $allpathw);
	my %set;
	@set{@pathways} = ();
	my @unique_pathways = keys %set;

        my $s;
        foreach my $item(@unique_pathways) {
            my ($p, $im) = split('\t', $item);
            my $url4 = "$main_cgi?section=PathwayMaps"
                     . "&page=keggMapSamples&map_id=$im"
		     . "&study=$study&samples=$sample_oid_str";
	    if ($type eq "describe_clustered") {
		$url4 .= "&file=$tmpOutputFileName";
		#$url4 .= "&dataFile=profile$$.tab.txt"; # tmpProfileFile
		$url4 .= "&dataFile=cluster$$.cdt"; # cdtFile
	    }
            $s .= alink($url4, $p, "_blank", 0, 1)."<br/>";
        }
        chop $s;
        $row .= $s.$sd.$s."\t";

	my $ec = $gene2ec{ $gene };
        my $ec2 = $ec;
        $ec2 =~ tr/A-Z/a-z/;
        my $ec_url = "$enzyme_base_url$ec2";
	$row .= $ec.$sd.alink($ec_url, $ec, "_blank")."\t";

	# no modules for MER-FS
	if ($in_file ne "Yes") {
	my $allmodules = $gene2module{ $gene };
	my @keggmodules = split('#', $allmodules);

	my $s;
	my $module0;
	my @images;
	foreach my $item(@keggmodules) {
	    my ($m, $p, $im) = split('\t', $item);
	    next if $m eq "";

	    if ($module0 eq "") {
		$module0 = $m;
	    }
	    if ($module0 ne $m) {
		if (scalar @images == 1) {
		    my $url3 = "$main_cgi?section=PathwayMaps"
			     . "&page=keggMapSamples&map_id=$images[0]"
			     . "&study=$study&samples=$sample_oid_str";
		    if ($type eq "describe_clustered") {
			$url3 .= "&file=$tmpOutputFileName";
			#$url3 .= "&dataFile=profile$$.tab.txt";
			$url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
		    }
		    $s .= alink($url3, $module0, "_blank", 0, 1)."<br/>";
		} elsif (scalar @images > 1) {
		    my $imageStr;
		    foreach my $image (sort @images) {
			my $url3 = "$main_cgi?section=PathwayMaps"
			         . "&page=keggMapSamples&map_id=$image"
				 . "&study=$study&samples=$sample_oid_str";
			if ($type eq "describe_clustered") {
			    $url3 .= "&file=$tmpOutputFileName";
			    #$url3 .= "&dataFile=profile$$.tab.txt";
			    $url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
			}
			if ($imageStr ne "") {
			    $imageStr .= ", ";
			}
			$imageStr .= alink($url3, $image, "_blank", 0, 1);
		    }
		    $s .= $module0." ($imageStr) <br/>";
		}
		$module0 = $m;
		@images = ();
	    }
	    if ($module0 eq $m) {
		push (@images, $im);
	    }
	}
	if (scalar @images == 1) {
	    my $url3 = "$main_cgi?section=PathwayMaps"
		     . "&page=keggMapSamples&map_id=$images[0]"
		     . "&study=$study&samples=$sample_oid_str";
	    if ($type eq "describe_clustered") {
		$url3 .= "&file=$tmpOutputFileName";
		#$url3 .= "&dataFile=profile$$.tab.txt";
		$url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
	    }
	    $s .= alink($url3, $module0, "_blank", 0, 1)."<br/>";
	} elsif (scalar @images > 1) {
	    my $imageStr;
	    foreach my $image (sort @images) {
		my $url3 = "$main_cgi?section=PathwayMaps"
		         . "&page=keggMapSamples&map_id=$image"
			 . "&study=$study&samples=$sample_oid_str";
		if ($type eq "describe_clustered") {
		    $url3 .= "&file=$tmpOutputFileName";
		    #$url3 .= "&dataFile=profile$$.tab.txt";
		    $url3 .= "&dataFile=cluster$$.cdt"; # cdtFile
		}
		if ($imageStr ne "") {
		    $imageStr .= ", ";
		}
		$imageStr .= alink($url3, $image, "_blank", 0, 1);
	    }
	    $s .= $module0." ($imageStr) <br/>";
	}
	#$s .= $module0." ($imageStr) <br/>";
	chop $s;
        $row .= $s.$sd.$s."\t";
	} # end modules

        $it->addRow($row);
        $count++;
    }

    printGeneCartFooter() if ($count > 10);
    $it->printOuterTable(1);
    printGeneCartFooter();

    #$dbh->disconnect();
    print end_form();
    printNotes("studysamples");
    printStatusLine("$count genes loaded.", 2);
}

############################################################################
# makeProfileFile - makes an input profile file
#             for R program that computes cluster groupings
############################################################################
sub makeProfileFile {
    my ($dbh, $tmpProfileFile, $normalization, $samples, $sample_oid_str,
	$cart_genes, $pairwise, $in_file, $show_all, $adjust) = @_;

    $show_all = 0 if ($show_all eq "");   # doesn't check min_abundance
    $adjust = 0 if ($adjust eq "");       # adjusts coverage values

    my @cart_gene_oids = ();
    if ($cart_genes ne "") {
	@cart_gene_oids = @$cart_genes;
    }
    my @sample_oids = @$samples;
    my $nSamples = scalar(@sample_oids);
    $show_all = 1 if $nSamples == 1;

    my $min_abundance = param("min_num");
    if ($min_abundance < 3 || $min_abundance > $nSamples) {
        $min_abundance = 3;
    }
    if ($pairwise) {
	$min_abundance = 2;
    }

    my %sampleNames;
    my %sampleNotes;
    my %sampleTotals;

    my %sample2taxon;
    my %taxons;

    my $sql = qq{
        select distinct dts.dataset_oid, dts.gold_id, gsp.display_name,
               dts.reference_taxon_oid, tx.genome_type
        from rnaseq_dataset dts, taxon tx,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.dataset_oid in ($sample_oid_str)
        and dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = tx.taxon_oid
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
        my ($sid, $gold_id, $sample_desc, $tx, $genome_type)
	    = $cur->fetchrow();
        last if !$sid;
        $sampleNames{ $sid } = $sample_desc;
        $sampleNotes{ $sid } = $gold_id;
	$sample2taxon{ $sid } = $tx;
	$taxons{ $tx } = $genome_type;
    }
    $cur->finish();

    foreach my $tx (keys %taxons) {
	my %stotals = MetaUtil::getRNASeqSampleCountsForTaxon($tx, 1);
	@sampleTotals{ keys %stotals } = values %stotals;
    }

    if (scalar keys %sampleTotals < 1) {
	my $sql = qq{
            select distinct dts.dataset_oid, sum(es.reads_cnt)
            from rnaseq_dataset dts, rnaseq_expression es
            where dts.dataset_oid in ($sample_oid_str)
            and dts.dataset_oid = es.dataset_oid
            and es.reads_cnt > 0.0000000
            group by dts.dataset_oid
            order by dts.dataset_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $sid, $total ) = $cur->fetchrow();
	    last if !$sid;
	    $sampleTotals{ $sid } = $total;
	}
	$cur->finish();
    }

    ## Template
    my %geneProfileFS;
    my %sampleProfileFS;
    my %sampleProfileFSRaw;
    my %template; ## count each time a gene is present in a given sample

    # reads and genes are now in sdb; no longer if ($in_file eq "Yes") check
    foreach my $sample (@sample_oids) {
	#my ($total_gene_cnt, $total_read_cnt) =
	#MetaUtil::getCountsForRNASeqSample($sample, $taxon_oid);

	my $taxon_oid = $sample2taxon{ $sample };
	my $genome_type = $taxons{ $taxon_oid };
	my %gene2info = MetaUtil::getGenesForRNASeqSample($sample, $taxon_oid);
	my @genes = keys %gene2info;
	# genes may be missing in sdb, - check oracle

	my %prodNames;
	if ($genome_type eq "metagenome") {
	    %prodNames =
		MetaUtil::getGeneProdNamesForTaxon($taxon_oid, "assembled");
	} else {
	    my $gene2prod = getGeneProductNames($dbh, $taxon_oid, \@genes);
	    %prodNames = %$gene2prod;
	}

	if (scalar @cart_gene_oids > 0) {
	    @genes = @cart_gene_oids;
	}

	my %gProfile;
	my %gProfileRaw;
	foreach my $gene ( @genes ) {
	    my @tokens = split(/ /, $gene);
	    if (scalar @tokens == 3) {
		next if $tokens[1] eq "unassembled";
		$gene = $tokens[2];
	    }

	    my $line = $gene2info{ $gene };
	    next if (!$line || $line eq "");

	    my ($geneid, $locus_type, $locus_tag, $strand,
		$scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
		= split("\t", $line);
	    next if (! $reads_cnt > 0.0000000);

	    my $product = $prodNames{ $gene };
	    $product = "hypothetical protein" if $product eq "";
	    $geneProfileFS{ $gene } =
		"$product\t$locus_tag\t$product\t$dna_seq_length";

	    my $coverage = $reads_cnt;
	    if ($normalization eq "coverage") {
		$coverage = $reads_cnt/$dna_seq_length;
		$coverage = $coverage/($sampleTotals{ $sample });
		if ($adjust) {
		    $coverage = $coverage * 10**9;
		    $coverage = sprintf("%.3f", $coverage);
		}
	    }

	    if ( !defined($template{ $gene }) ) {
		$template{ $gene } = 0;
	    }
	    $template{ $gene }++;
	    $gProfile{ $gene } = $coverage;
	    $gProfileRaw{ $gene } = $reads_cnt;
	}
	$sampleProfileFS{ $sample } = \%gProfile;
	$sampleProfileFSRaw{ $sample } = \%gProfileRaw;
    }

    if (scalar keys %template < 1) {
	my $sql = qq{
            select distinct es.IMG_gene_oid, es.dataset_oid
            from rnaseq_expression es, gene g
            where es.dataset_oid in ($sample_oid_str)
            and es.IMG_gene_oid = g.gene_oid
            and es.reads_cnt > 0.0000000
            order by es.IMG_gene_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose );

	for( ;; ) {
	    my( $gid, $s ) = $cur->fetchrow();
	    last if !$gid;
            if (scalar @cart_gene_oids > 0) {
		my $found = 0;
		CHECKCART: foreach my $cg (@cart_gene_oids) {
		    if ($gid == $cg) {
			$found = 1;
			last CHECKCART;
		    }
		}
		next if !$found;
            }

	    if ( !defined($template{ $gid }) ) {
		$template{ $gid } = 0;
	    }
	    $template{ $gid }++;
	}
	$cur->finish();
    }

    ## get only the genes that appear in at least x number of samples
    my %template2;
    my @gids = sort( keys( %template ) );
    if (scalar @gids == 0 && scalar @cart_gene_oids > 0) {
	printEndWorkingDiv();
	#$dbh->disconnect();
	webError("Genes in gene cart are not found in this study.");
    }
    foreach my $i( @gids ) {
        if (!$show_all && $template{ $i } < $min_abundance) { next; }
        $template2{ $i } = 0;
    }
    if (scalar keys( %template2 ) == 0) {
	printEndWorkingDiv();
	#$dbh->disconnect();
	webError("No genes found in this sample.") if $nSamples == 1;
	webError("No gene in this study appears (has reads) in $min_abundance samples.");
    }

    ## Normalized values
    my $select;
    if ($normalization eq "coverage") {
        $select = "es.reads_cnt/g.DNA_seq_length";
    } else {
        $select = "es.reads_cnt";
    }

    # get the coverage
    my %sampleProfiles;
    my %sampleProfilesRaw;
    my $sql = qq{
        select distinct g.gene_oid, $select, es.reads_cnt
        from rnaseq_expression es, gene g
        where es.dataset_oid = ?
        and es.IMG_gene_oid = g.gene_oid
        and es.reads_cnt > 0.0000000
    };

    foreach my $sample_oid( @sample_oids ) {
        my %profile = %template2; # list of all the included genes
        my %profileRaw = %template2; # list of all the included genes

	# reads and genes are now in sdb;
	# no longer if ($in_file eq "Yes") check
	my $gProfile_ref = $sampleProfileFS{ $sample_oid };
	my %gProfile = %$gProfile_ref;
	my $gProfileRaw_ref = $sampleProfileFSRaw{ $sample_oid };
	my %gProfileRaw = %$gProfileRaw_ref;
	my @genes = keys( %gProfile );

	foreach my $g (@genes) {
	    next if ( !defined($template2{ $g }) );
	    next if ( !$show_all && $template{ $g } < $min_abundance );
	    my $coverage = $gProfile{ $g };
	    $profile{ $g } = $coverage;
	    my $raw = $gProfileRaw{ $g };
	    $profileRaw{ $g } = $raw;
	}

	my $not_all_zeros = grep { $_ > 0 } values %profile;
	if (!$not_all_zeros) { # anna - missing sdb data, for now
	    my $cur = execSql( $dbh, $sql, $verbose, $sample_oid );
	    for ( ;; ) {
		my ( $gid, $coverage, $raw ) = $cur->fetchrow();
		last if !$gid;
		next if ( !defined($template2{ $gid }) );
		next if ( !$show_all && $template{ $gid } < $min_abundance );
		if ($normalization eq "coverage") {
		    $coverage = $coverage/($sampleTotals{ $sample_oid });
		    if ($adjust) {
			$coverage = $coverage * 10**9;
			$coverage = sprintf("%.3f", $coverage);
		    }
		}
		$profile{ $gid } = $coverage;
		$profileRaw{ $gid } = $raw;
	    }
	}
        $sampleProfiles{ $sample_oid } = \%profile;
        $sampleProfilesRaw{ $sample_oid } = \%profileRaw;
    }

    my %allprofile;
    if ($normalization ne "coverage") {
        my $allProfiles_ref = normalizeData
            (\@sample_oids, \%sampleProfiles, \@gids, $normalization);
        %allprofile = %$allProfiles_ref;
    }

    my $wfh = newWriteFileHandle( $tmpProfileFile, "printClusterResults" );
    my $s = "gene_oid\t";
    foreach my $i( @sample_oids ) {
        $s .= "$i\t";
    }
    chop $s;
    print $wfh "$s\n";

    my @geneIds = sort( keys( %template2 ) );
#    if (scalar @cart_gene_oids > 0) {
#        @geneIds = @cart_gene_oids;
#    }
    foreach my $g ( @geneIds ) {
	my @tokens = split(/ /, $g);
	if (scalar @tokens == 3) {
	    next if $tokens[1] eq "unassembled";
	    $g = $tokens[2];
	}
        print $wfh "$g\t";
        my $s;

	my $i = 0; # order of samples
        foreach my $sample_oid( @sample_oids ) {
            my $profile_ref = $sampleProfiles{ $sample_oid };

	    if ($normalization ne "coverage") {
		my $valstr = $allprofile{ $g }; # coverage
		my @values = split(',', $valstr);
		my $coverage = $values[$i];
		#if ($adjust) {
		#    $coverage = $coverage * 10**9;
		#    $coverage = sprintf("%.3f", $coverage);
		#}
		$profile_ref->{ $g } = $coverage;
		$i++;
	    }

            my $nsaf = $profile_ref->{ $g };
            $s .= "$nsaf\t";
        }
        chop $s;
        print $wfh "$s\n";
    }
    close $wfh;
    return (\%sampleNames, \%sampleNotes, \%sampleProfiles,
	    \@geneIds, \%geneProfileFS, \%sampleProfilesRaw);
}

sub getGeneProductNames {
    my ($dbh, $taxon_oid, $genes_ref) = @_;
    my @genes = @$genes_ref;
    my %gene2prod;
    return \%gene2prod if scalar @genes < 1;

    my $idsInClause = OracleUtil::getNumberIdsInClause($dbh, @genes);
    my $sql = qq{
        select g.gene_oid, g.gene_display_name, g.description
        from gene g
        where g.gene_oid in ($idsInClause)
        and g.taxon = ?
    };
    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    for ( ;; ) {
	my ( $gene_oid, $prod_name, $desc ) = $cur->fetchrow();
	last if !$gene_oid;
	$gene2prod{ $gene_oid } = $prod_name;
    }
    $cur->finish();

    OracleUtil::truncTable($dbh, "gtt_num_id");
    return \%gene2prod;
}

############################################################################
# printPathwaysForSample - list of all pathways for the sample
############################################################################
sub printPathwaysForSample {
    my @sample_oids = param("exp_samples");
    my $nSamples = @sample_oids;
    my $taxon_oid = param("taxon_oid");
    my $in_file = param("in_file");
    my $normalization = "coverage";

    if ($nSamples < 1) {
        webError( "Please select 1 sample." );
    }

    printStatusLine("Loading ...", 1);
    my $dbh = dbLogin();

    my $sample = @sample_oids[0];
    if ( $taxon_oid eq "" && $sample ne "" ) {
	my $sql = qq{
            select dts.reference_taxon_oid, tx.in_file
            from rnaseq_dataset dts, taxon tx
            where dts.dataset_oid = ?
            and tx.taxon_oid = dts.reference_taxon_oid
        };
        my $cur = execSql( $dbh, $sql, $verbose, $sample );
        ($taxon_oid, $in_file) = $cur->fetchrow();
        $cur->finish();
    }
    if ( $taxon_oid eq "" ) {
        webDie("printPathwaysForSample: taxon_oid not specified");
    }

    my $cart_genes = param("describe_cart_genes");
    my @cart_gene_oids;
    if ($cart_genes) {
        use GeneCartStor;
        my $gc = new GeneCartStor();
        my $recs = $gc->readCartFile(); # get records
        @cart_gene_oids = sort { $a <=> $b } keys(%$recs);
        if (scalar @cart_gene_oids < 1) {
            webError( "Your Gene Cart is empty." );
        }
    }

    my $sample_oid_str = $sample_oids[0];
    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select dts.gold_id, gsp.display_name,
               tx.taxon_display_name, tx.genome_type, tx.in_file
        from rnaseq_dataset dts, taxon tx,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.dataset_oid = ?
        and dts.gold_id = gsp.gold_id
        and dts.reference_taxon_oid = ?
        and dts.reference_taxon_oid = tx.taxon_oid
        $datasetClause
    };
    my $cur = execSql( $dbh, $sql, $verbose, @sample_oids[0], $taxon_oid );
    my ($gold_id, $sample_desc,
        $taxon_name, $genome_type, $in_file) = $cur->fetchrow();
    $cur->finish();

    print "<h1>Pathways for Sample</h1>";
    my $url = "$section_cgi&page=sampledata&sample=@sample_oids[0]";
    print "<p>".alink($url, $sample_desc, "_blank");
    if (!blankStr($gold_id)) {
        my $url = HtmlUtil::getGoldUrl($gold_id);
	print " [".alink($url, $gold_id, "_blank")."]";
    }
    print "</p>\n";

    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	printHint("The number of genes from gene cart that are found to "
	        . "participate in any given pathway is shown in parentheses.");
 	print "<p>*Showing counts for genes from gene cart only</p>";
    } else {
	printHint("The number of genes from this sample that are found to "
		. "participate in any given pathway is shown in parentheses.");
	print "<br/>";
    }

    # removed module query see cvs version 1.42
    my $sql = qq{
        select distinct pw.pathway_name, pw.image_id, gkmp.gene_oid
        from kegg_pathway pw, rnaseq_expression es,
             dt_gene_ko_module_pwys gkmp
        where pw.pathway_oid = gkmp.pathway_oid
        and es.dataset_oid = ?
        and es.IMG_gene_oid = gkmp.gene_oid
        order by pw.pathway_name
    };

    my %ids;
    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	foreach my $id (@cart_gene_oids) {
	    $ids{ $id } = 1
	}
    }

    my %pathway2count;
    my $sample = @sample_oids[0];
    my %gene2info = MetaUtil::getGenesForRNASeqSample($sample, $taxon_oid);
    my @genes = keys %gene2info;

    if (scalar @genes > 0 && $in_file ne "Yes") {
	my $idsInClause = OracleUtil::getNumberIdsInClause($dbh, @genes);
	my $gidsClause;
	$gidsClause = " and gkmp.gene_oid in ($idsInClause) "
	    if scalar @genes > 0;

	$sql = qq{
            select distinct pw.pathway_name, pw.image_id, gkmp.gene_oid
            from kegg_pathway pw, dt_gene_ko_module_pwys gkmp
            where pw.pathway_oid = gkmp.pathway_oid
            $gidsClause
            order by pw.pathway_name
        };
    }

    if ($in_file eq "Yes") {
	my $ksql = qq{
            select distinct pw.pathway_name, pw.pathway_oid,
                   pw.image_id, irk.ko_terms
            from kegg_pathway pw, image_roi roi, image_roi_ko_terms irk
            where pw.pathway_oid = roi.pathway
            and roi.roi_id = irk.roi_id
            order by pw.pathway_name
        };
        my %all_kos = MetaUtil::getTaxonFuncCount
	    ($taxon_oid, 'assembled', 'ko');
	my %all_kegg_pathways = MetaUtil::getTaxonFuncCount
	    ($taxon_oid, 'assembled', 'kegg_pathway');

        my $cur = execSql( $dbh, $ksql, $verbose );
        my %done;
        for ( ;; ) {
            my ( $pathway_name, $pathway_oid, $image_id, $ko )
		= $cur->fetchrow();
            last if !$image_id;
            last if !$ko;
            next if ($image_id eq 'map01100');
            next if (!$all_kos{$ko});
            next if (!$all_kegg_pathways{$pathway_oid});

            my %ko_genes = MetaUtil::getTaxonFuncGenes($taxon_oid, "assembled", $ko);
            my @gene_group = keys %ko_genes;
            next if (scalar @gene_group == 0);

            my $key2 = $pathway_name."\t".$image_id;
            foreach my $gene ( @gene_group ) {
                next if (!exists $gene2info{ $gene });
		next if $done{ "$gene"."$image_id" };
		if ($cart_genes && (scalar @cart_gene_oids > 0)) {
		    next if (!exists $ids{ $gene }) ;
		}
		if ( !defined($pathway2count{ $key2 }) ) {
		    $pathway2count{ $key2 } = 0;
		}
		$pathway2count{ $key2 }++;
		$done{ "$gene"."$image_id" } = 1;
            }
	}

    } else {
	my $cur;
	if (scalar @genes > 0) {
	    $cur = execSql( $dbh, $sql, $verbose );
	} else {
	    $cur = execSql( $dbh, $sql, $verbose, @sample_oids[0] );
	}
	for( ;; ) {
	    my( $pathway_name, $image_id, $gid ) = $cur->fetchrow();
	    last if !$gid;
	    next if ($image_id eq 'map01100');
	    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
		next if (!exists $ids{ $gid }) ;
	    }

	    my $key2 = $pathway_name."\t".$image_id;
	    if ( !defined($pathway2count{ $key2 }) ) {
		$pathway2count{ $key2 } = 0;
	    }
	    $pathway2count{ $key2 }++;
	}
	$cur->finish();

	OracleUtil::truncTable($dbh, "gtt_num_id");
    }

    #$dbh->disconnect();

    my @pathways = sort keys(%pathway2count);
    my $nPathways = scalar @pathways;

    print qq{
	<table border=0>
	<tr>
	<td nowrap>
    };
    foreach my $item(@pathways) {
	my ($p, $im) = split('\t', $item);
	my $count1 = $pathway2count{ $item };

	my $url = "$main_cgi?section=PathwayMaps"
	    . "&page=keggMapSamples&map_id=$im"
	    . "&study=$study&samples=$sample_oid_str";
	print alink( $url, $p, "_blank", 0, 1 ) . " ($count1)<br/>\n";
    }
    print qq{
        </td>
        </tr>
        </table>
        </p>
    };

    print end_form();
    printStatusLine("$nPathways pathways loaded.", 2);
}

############################################################################
# loadMyColorArray - allocates the array of colors for the specified image
############################################################################
sub loadMyColorArray {
    my ($im, $color_array_file) = @_;

    my $white = $im->colorAllocate( 255, 255, 255 );
    my $red = $im->colorAllocate( 255, 0, 0 );
    my $green = $im->colorAllocate( 99, 204, 99 );
    my $blue = $im->colorAllocate( 0, 0, 255 );
    my $purple = $im->colorAllocate( 155, 48, 255 );
    my $yellow = $im->colorAllocate( 255, 250, 205 );
    my $cyan = $im->colorAllocate( 200, 255, 255 );
    my $pink = $im->colorAllocate( 255, 225, 255 );
    my $light_purple = $im->colorAllocate( 208, 161, 254 );

    $im->transparent( $white );
    $im->interlaced( 'true' );

    my $rfh = newReadFileHandle( $color_array_file, "loadMyColorArray", 1 );

    my $count = 0;
    my %done;
    my @color_array;
    while ( my $s = $rfh->getline() ) {
        chomp $s;

        next if $s eq "";
        next if $s =~ /^#/;
        next if $s =~ /^\!/;
        $count++;

        $s =~ s/^\s+//;
        $s =~ s/\s+$//;
        $s =~ s/\s+/ /g;

        my ( $r, $g, $b, @junk ) = split( / /, $s );
        next if scalar(@junk) > 1;

        my $val = "$r,$g,$b";
        next if $done{$val} ne "";
        push( @color_array, $val );
        $done{$val} = 1;
    }
    close $rfh;

    my @colors;
    foreach my $k (@color_array) {
        my ( $r, $g, $b ) = split( /,/, $k );
        my $color = $im->colorAllocate( $r, $g, $b );
	if ($color == -1) {
	    $color = $im->colorClosest( $r, $g, $b );
	}
        push( @colors, $color );
    }
    webLog("\nTOTAL colors in array: ".@colors."\n");
    return @colors;
}

############################################################################
# printClusterResults - clusters samples based on the relative abundance
#                       measure of the expressed genes.
############################################################################
sub printClusterResults {
    my @sample_oids = param("exp_samples");
    my $nSamples = @sample_oids;
    my $proposal = param("proposal");
#    my $domain = param("domain");
    my $taxon_oid = param("taxon_oid");
    my $in_file = param("in_file");
    my $method = param("method");
    my $correlation = param("correlation");
    my $min_abundance = param("min_num");
    my $normalization = param("normalization");

    if ($nSamples < 2) {
        webError( "Please select at least 2 samples." );
    }
    if ($min_abundance < 3 ||
	$min_abundance > $nSamples) {
	$min_abundance = 3;
    }

    my $cart_genes = param("cluster_cart_genes");
    my @cart_gene_oids;
    if ($cart_genes) {
        use GeneCartStor;
        my $gc = new GeneCartStor();
        my $recs = $gc->readCartFile(); # get records
        @cart_gene_oids = sort { $a <=> $b } keys(%$recs);
	if (scalar @cart_gene_oids < 1) {
	    webError( "Your Gene Cart is empty." );
	}
    }

    $correlation =~ /([0-8])/;
    $correlation = $1;

    $method =~ /([msca])/;
    $method = $1;

    if ($method eq "") {
	$method = "m";
    }
    if ($correlation eq "") {
	$correlation = 2;
    }

    print "<h1>Cluster Results for Selected Samples</h1>\n";
    if ($proposal ne "") {
	print "<span style='font-size: 12px; "
	    . "font-family: Arial, Helvetica, sans-serif;'>\n";
        my $expurl = "$section_cgi&page=samplesByProposal"
                   . "&proposal=$proposal&genomes=1";
        print "<u>Proposal</u>: ".alink($expurl, $proposal, "_blank")."\n";
	print "</span>\n";
    }

    print "<p>\n";
    print "Each gene in the heat map is set to appear in "
	. "at least $min_abundance (out of $nSamples) samples";
    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
	print "<br/>*Showing only genes from gene cart";
    }
    print "<br/>Normalization: $normalization";
    print "</p>\n";

    printHint
      ("Click on a <font color='blue'><b>sample</b></font> on the left ".
       "to sort the row based on descending coverage values.<br/>\n".
       "Mouse over sample or gene labels to see names, click to see details.<br/>\n".
       "Mouse over parent tree nodes to see distances.<br/>\n".
       "Mouse over heat map to see: <font color='red'>normalized values ".
       "(original values) [sampleid:geneid]</font>.<br/>\n");

    my $dbh = dbLogin();
    printStatusLine( "Loading ...", 1 );

    printStartWorkingDiv();

    # make an input file:
    print "<p>Making profile file...<br/>";
    my $sample_oid_str = join(",", @sample_oids);
    my $inputFile = "$tmp_dir/cluster-profile$$.tab.txt";
    my ($names_ref, $notes_ref, $profiles_ref, $gid_ref,
	$gprofile, $raw_profiles_ref)
	= makeProfileFile($dbh, $inputFile, $normalization,
			  \@sample_oids, $sample_oid_str,
			  \@cart_gene_oids, 0, $in_file, 0, 0);

    my %sampleProfiles = %$profiles_ref;
    my %sampleNames = %$names_ref;
    my @geneIds = @$gid_ref;
    my %geneProfile;
    if ($in_file eq "Yes" || scalar (keys %$gprofile) > 0) {
        %geneProfile = %$gprofile;
    } else {
	my $sql = qq{
            select distinct es.IMG_gene_oid, es.dataset_oid,
                   g.gene_display_name, g.locus_tag,
                   g.product_name, g.DNA_seq_length
            from rnaseq_expression es, gene g
            where es.dataset_oid in ($sample_oid_str)
            and es.IMG_gene_oid = g.gene_oid
            and es.reads_cnt > 0.0000000
            order by es.IMG_gene_oid
        };
	my $cur = execSql( $dbh, $sql, $verbose );
	for( ;; ) {
	    my( $gid, $s, $gene_name, $locus_tag,
		$product, $dna_seq_length ) = $cur->fetchrow();
	    last if !$gid;
	    $geneProfile{ $gid } =
		"$gene_name\t$locus_tag\t$product\t$dna_seq_length";
	}
	$cur->finish();
    }

    my %rowDict;
    foreach my $sid( keys %sampleNames ) {
	my $surl = "$section_cgi&page=sampledata&sample=$sid";
	my $sname = $sampleNames{ $sid };
	$rowDict{ $sid } = $sname."\t".$surl;
    }

    my %template2;
    foreach my $i( @geneIds ) {
        $template2{ $i } = 0;
    }

    my $count = 0;
    my %colDict;
    my %origSampleProfiles;
    my $i = 0;

    #print "<p>\n";
    foreach my $s( @sample_oids ) {
	if ($count == 0) {
	    print "Find profile for <i>sample(s)</i> $s";
	} else {
	    print ", $s";
	}
	$count++;

	# get the kegg pathways
	# ANNA : TOFIX
        my $sql = qq{
            select distinct gkmp.gene_oid, pw.pathway_name, pw.image_id
            from kegg_pathway pw, dt_gene_ko_module_pwys gkmp,
                 rnaseq_expression es
            where pw.pathway_oid = gkmp.pathway_oid
            and es.dataset_oid = ?
            and es.IMG_gene_oid = gkmp.gene_oid
            order by gkmp.gene_oid, pw.pathway_name
        };
	my $cur = execSql( $dbh, $sql, $verbose, $s );

	my %done;
	my %gene2pathw;
	for( ;; ) {
	    my( $gene_oid, $pathway_name, $image_id ) = $cur->fetchrow();
	    last if !$pathway_name;
	    next if $done{ "$gene_oid"."$image_id" };
            #if ($template{ $gene_oid } < $min_abundance) { next; }
	    next if (!exists $template2{ $gene_oid });

	    $gene2pathw{$gene_oid} .= $pathway_name.",";
	    $done{ "$gene_oid"."$image_id" } = 1;
	}
        $cur->finish();

        my %profile4sample = %template2;
	my $profile = $sampleProfiles{ $s };

	foreach my $gene( @geneIds ) {
	    my $coverage = $profile->{ $gene };
	    if ($normalization eq "coverage") {
		$coverage = $coverage * 10**9;
	    }

	    $coverage = sprintf("%.3f", $coverage);####
            $profile4sample{ $gene } = $coverage;

            my $gurl = "$main_cgi?section=GeneDetail&page=geneDetail"
                     . "&gene_oid=$gene";
            if ($in_file eq "Yes") {
                $gurl = "$main_cgi?section=MetaGeneDetail"
                      . "&page=metaGeneDetail&gene_oid=$gene"
                      . "&data_type=assembled&taxon_oid=$taxon_oid";
            }
            my $pathwstr = $gene2pathw{ $gene };
            chop $pathwstr;

            #if ($template{ $gene } < $min_abundance) { next; }
	    next if (!exists $template2{ $gene });

            my ($name, $locus_tag, $product, $dna_seq_length)
                = split('\t', $geneProfile{$gene});
            $colDict{ $gene } = $locus_tag
                . " [".$name."] [".$pathwstr."]\t".$gurl;
        }
        $origSampleProfiles{ $s } = \%profile4sample;
        $i++;
    }
    if ($count > 0) {
	print " ...<br/>\n";
    }

    #$dbh->disconnect();

    ## Set up and run cluster
    my $tmpProfileFile = "$tmp_dir/profile$$.tab.txt";
    my $tmpClusterRoot = "$tmp_dir/cluster$$";
    my $tmpClusterCdt = "$tmp_dir/cluster$$.cdt";
    my $tmpClusterGtr = "$tmp_dir/cluster$$.gtr";
    my $tmpClusterAtr = "$tmp_dir/cluster$$.atr";

    my $wfh = newWriteFileHandle( $tmpProfileFile, "printClusterResults" );
    my $s = "gene_oid\tNAME\t";
    my @sample_oids = sort( keys( %origSampleProfiles ) );
    foreach my $i( @sample_oids ) {
        $s .= "$i\t";
        #$s .= "$sampleNames{ $i }."\t";
	# * may need to re-write to use sample names
    }
    chop $s;
    print $wfh "$s\n";

#    if ($cart_genes && (scalar @cart_gene_oids > 0)) {
#        @geneIds = @cart_gene_oids;
#    }

    foreach my $i( @geneIds ) {
	my @items = split( /\t/, $colDict{ $i } );
        print $wfh "$i\t" . "$i - $items[0]\t";
        my $s;
	foreach my $sample_oid( @sample_oids ) {
	    my $profile_ref = $origSampleProfiles{ $sample_oid };
            my $nsaf = $profile_ref->{ $i };
            $s .= "$nsaf\t";
        }
        chop $s;
        print $wfh "$s\n";
    }
    close $wfh;

    my $stateFile = "rnaseq_samples_heatMap$$";
    my %sid2Rec;
    foreach my $sample_oid( @sample_oids ) {
        my $url = "$main_cgi?section=$section&page=clusterMapSort";
        $url .= "&stateFile=$stateFile";
        $url .= "&sortId=$sample_oid";

	my @sampleinfo = split(/\t/, $rowDict{ $sample_oid });
	my $highlight = 0;
	my $r = "$sample_oid\t";
	#my $r = substr($sampleinfo[0], 0, 11)."\t";
	$r .= "$highlight\t";
	$r .= "Sort row on coverage of genes found in sample: "
	    . "$sample_oid - ".$sampleinfo[0]."\t";
	$r .= "$url\t";
	$sid2Rec{ $sample_oid } = $r;
    }

    my %gid2Rec;
    foreach my $gid( @geneIds ) {
        my $url = "$main_cgi?section=GeneDetail"
                . "&page=geneDetail&gene_oid=$gid";
	if ($in_file eq "Yes") {
	    $url = "$main_cgi?section=MetaGeneDetail"
		 . "&page=metaGeneDetail&gene_oid=$gid"
		 . "&data_type=assembled&taxon_oid=$taxon_oid";
	}

        my $highlight = 0;
        my $r = "$gid\t";
        $r .= "$highlight\t";
	$r .= $colDict{ $gid }."\t";
        $r .= "$url\t";
        $gid2Rec{ $gid } = $r;
    }

    print "Clustering samples (and genes) ... using log values<br/>\n";
    print "Profile file $tmpProfileFile ... ";

    WebUtil::unsetEnvPath();
    $correlation = checkPath($correlation);
    $method = checkPath($method);

    runCmd( "$cluster_bin -ng -l "
	  . "-g $correlation -e $correlation -m $method "
	  . "-cg a -ca a "
	  . "-f $tmpProfileFile -u $tmpClusterRoot" );
    WebUtil::resetEnvPath();

    # preset the urls for Java TreeView:
    my $gurl = "$cgi_url/$main_cgi?section=GeneDetail"
	     . "&amp;page=geneDetail&amp;gene_oid=HEADER";
    if ($in_file eq "Yes") {
	$gurl = "$cgi_url/$main_cgi?section=MetaGeneDetail"
	      . "&amp;page=metaGeneDetail&amp;gene_oid=HEADER"
	      . "&amp;data_type=assembled&amp;taxon_oid=$taxon_oid";
    }

    my $surl = "$cgi_url/$main_cgi?section=RNAStudies"
	. "&amp;page=sampledata&amp;sample=HEADER";

    my $s = "<DocumentConfig>\n"
	."<UrlExtractor urlTemplate='$gurl' index='1' isEnabled='1'/>\n"
	."<ArrayUrlExtractor urlTemplate='$surl' index='0' isEnabled='1'/>\n"
	."</DocumentConfig>";

    my $tmpClusterJtvFile = "$tmp_dir/cluster$$.jtv";
    my $wfh = newWriteFileHandle( $tmpClusterJtvFile, "printClusterResults" );
    print $wfh "$s\n";
    close $wfh;

    print "Making clustered tree for samples ... <br/>\n";

    require DrawTree;
    require DrawTreeNode;
    my $dt = new DrawTree();

    # display the cluster tree for samples:
    $dt->loadAtrCdtFiles( $tmpClusterAtr, $tmpClusterCdt, \%sid2Rec );
    my $tmpFile = "drawTree$$.png";
    my $outPath = "$tmp_dir/$tmpFile";
    my $outUrl = "$tmp_url/$tmpFile";
    $dt->drawAlignedToFile( $outPath );
    my $treemap = $dt->getMap( $outUrl, 0 );

    print "Creating heat map ...<br/>\n";

    my $rfh = newReadFileHandle( $tmpClusterCdt, "printClusterResults" );
    my $count1 = 0;
    my %normData;
    my %normSampleData;
    my @allSamples;
    my @allGenes;
    while( my $s = $rfh->getline() ) {
	chomp $s;
	$count1++;
	if ($count1 == 1) {
	    @allSamples = split( /\t/, $s );
	    splice(@allSamples, 0, 4); # starts with the 4th element
	}

	next if $count1 < 4;
	my( $idx, $gid, $name, $weightx, $values ) = split( /\t/, $s, 5 );
	push( @allGenes, $gid );

	# values are ordered by the allSamples
	$normData{ $gid } = $values;

	# values of all genes for each sample
	# ordered by @allGenes
        my $x = 0;
	my $nSamples = @allSamples;
        foreach my $sid (@allSamples) {
            my @geneData = split(/\t/, $values);
            my $cellVal = $geneData[$x]; # coverage
	    if ($cellVal eq "") {
		$cellVal = "undef"; # logged data has empty values
	    }
            $normSampleData{ $sid } .= "$cellVal\t";
            $x++;
        }
    }
    close $rfh;

    my %normSampleProfiles;
    foreach my $sid( @allSamples ) {
        my $values = $normSampleData{ $sid };
        chop $values;
        my @geneData = split(/\t/, $values);

        my %profile; ## = %template2;
        @profile{ @allGenes } = @geneData;
        $normSampleProfiles{ $sid } = \%profile;
    }

    printEndWorkingDiv();

    my $ids = $dt->getIds(); # same as allSamples
    my $state = {
        geneIds      => \@allGenes,
        sampleOids   => \@$ids,
        normProfiles => \%normSampleProfiles,
        origProfiles => \%origSampleProfiles,
        rowDict      => \%rowDict,
        colDict      => \%colDict,
	treeMap      => $treemap,
	cdtFileName  => "cluster$$",
        stateFile    => $stateFile,
    };
    store( $state, checkTmpPath("$cgi_tmp_dir/$stateFile") );
    printClusterMap($state);

    printStatusLine( "Loaded.", 2 );
    printHint("Mouse over heat map to see coverage value ".
	      "of the gene in the given sample.<br/>\n");
}

############################################################################
# printClusterMapSort - print the heat map and the sample cluster tree with
#    genes sorted based on descending order of values for the given sample
############################################################################
sub printClusterMapSort {
    my $stateFile = param("stateFile");
    my $sortId = param("sortId");
    my $path = "$cgi_tmp_dir/$stateFile";
    if (!( -e $path )) {
        webError("Your session has expired. Please start over again.");
    }
    webLog "retrieve '$path' " . currDateTime() . "\n"
	if $verbose >= 1;
    my $state = retrieve($path);
    if ( !defined($state) ) {
        webLog("printClusterMapSort: bad state from '$stateFile'\n");
        webError("Your session has expired. Please start over again.");
    }

    my $normProfiles_ref = $state->{normProfiles};
    my $stateFile2       = $state->{stateFile};

    if ( $stateFile2 ne $stateFile ) {
        webLog( "printClusterMapSort: stateFile mismatch "
		. "'$stateFile2' vs. '$stateFile'\n" );
        WebUtil::webExit(-1);
    }
    webLog "retrieved done " . currDateTime() . "\n"
	if $verbose >= 1;
    printStatusLine( "Loading ...", 1 );

    if ($sortId ne "") {
	my $profile_ref = $normProfiles_ref->{ $sortId };
	my %profile = %$profile_ref;
	my @sortedGenes = sort{ $profile{$b} <=> $profile{$a} } keys %profile;
	$state->{geneIds} = \@sortedGenes;

	print "<h1>Sorted Cluster Results</h1>";
	print "<p>\n";
	print "Genes are now sorted on coverage values high->low for "
	    . "sample $sortId. <br/>Genes are no longer in clustered order.";
	print "</p>\n";

	printMainForm();
	print hiddenVar( "sortId", "" );
	print hiddenVar( "stateFile", $stateFile );
	my $name = "_section_${section}_clusterMapSort";
	print submit( -name  => $name,
		      -value => "Restore Original Order",
		      -class => "smdefbutton" );
	print "<br/>\n";
	print end_form();

    } else {
        print "<h1>Restored Cluster Results</h1>";
	print "<p>\n";
        print "Genes are again in clustered order.";
	print "</p>\n";

	printHint
	  ("Click on a <font color='blue'><b>sample</b></font> on the left ".
	   "to sort the row based on descending coverage values.<br/>\n".
	   "Mouse over sample or gene labels to see names, click to see details.<br/>\n".
	   "Mouse over parent tree nodes to see distances.<br/>\n".
	   "Mouse over heat map to see: <font color='red'>normalized values ".
	   "(original values) [sampleid:geneid]</font>.<br/>\n");
    }

    printClusterMap($state, $sortId);
    printStatusLine( "Loaded.", 2 );
}

############################################################################
# printClusterMap - print the heat map and the sample cluster tree
############################################################################
sub printClusterMap {
    my ($state, $sortId) = @_;
    my $geneIds_ref      = $state->{geneIds};
    my $sampleOids_ref   = $state->{sampleOids};
    my $normProfiles_ref = $state->{normProfiles};
    my $origProfiles_ref = $state->{origProfiles};
    my $rowDict_ref      = $state->{rowDict};
    my $colDict_ref      = $state->{colDict};
    my $treemap          = $state->{treeMap};
    my $cdtFileName      = $state->{cdtFileName};
    my $stateFile        = $state->{stateFile};

    my @allGenes = @$geneIds_ref;
    my $nGenes = @allGenes;

    if ($sortId eq "") {
	# call the Java TreeView applet:
	my $archive = "$base_url/TreeViewApplet.jar,"
	             ."$base_url/nanoxml-2.2.2.jar,"
	             ."$base_url/Dendrogram.jar";
	print qq{
	    <APPLET code="edu/stanford/genetics/treeview/applet/ButtonApplet.class"
		archive="$archive"
		width='250' height='50'>
	    <PARAM name="cdtFile" value="$tmp_url/$cdtFileName.cdt">
	    <PARAM name="cdtName" value="with Java TreeView">
	    <PARAM name="jtvFile" value="$tmp_url/$cdtFileName.jtv">
	    <PARAM name="styleName" value="linked">
	    <PARAM name="plugins" value="edu.stanford.genetics.treeview.plugin.dendroview.DendrogramFactory">
	    </APPLET>
	};
    }

    my $idx = 0;
    my $count = 0;
    print "<table border='0'>\n";
    while ($idx < $nGenes) {
        $count++;
        my $max = $batch_size + $idx;
        if ($max > $nGenes) {
            $max = $nGenes;
        }
        my @genes = @allGenes[$idx..($max - 1)];

        my %table;
        foreach my $sid (@$sampleOids_ref) {
            my $profile = $origProfiles_ref->{ $sid };
            my $s;
            foreach my $gid (@genes) {
                my $cellVal = $profile->{ $gid }; # coverage
                $s .= "$cellVal\t";
            }
            chop $s;
            $table{ $sid } = $s;
        }

        my %normalizedTable;
        foreach my $sid (@$sampleOids_ref) {
            my $profile = $normProfiles_ref->{ $sid };
            my $s;
            foreach my $gid (@genes) {
                my $cellVal = $profile->{ $gid }; # coverage
                $s .= "$cellVal\t";
            }
            chop $s;
            $normalizedTable{ $sid } = $s;   # with normalized values
        }

        my $stateFile = "rnaseq_samples_${count}_heatMap$$";
	if ($sortId ne "") {
	    $stateFile = $stateFile. "_${sortId}";
	}

        my $state = {
            geneIds    => \@genes,
            normTable  => \%normalizedTable,
            table      => \%table,
            sampleOids => \@$sampleOids_ref,
            rowDict    => \%$rowDict_ref,
            colDict    => \%$colDict_ref,
            stateFile  => $stateFile,
        };
        store( $state, checkTmpPath("$cgi_tmp_dir/$stateFile") );

        print "<tr>\n";
        print "<td valign='top'>\n";
        print "$treemap\n";
        print "</td>\n";
        print "<td valign='top'>\n";
        printHeatMapSection($count, $idx, $state);
        print "</td>\n";
        print "</tr>\n";

        $idx = $idx + $batch_size;
    }
    print "</table>\n";
}

############################################################################
# printHeatMapSection - Generates one heat map section.
############################################################################
sub printHeatMapSection {
    my ($cntId, $idx, $state) = @_;

    my $geneIds_ref    = $state->{geneIds};
    my $normTable_ref  = $state->{normTable};
    my $table_ref      = $state->{table};
    my $sampleOids_ref = $state->{sampleOids};
    my $rowDict_ref    = $state->{rowDict};
    my $colDict_ref    = $state->{colDict};
    my $stateFile      = $state->{stateFile};

    my $id      = "${cntId}_rnaseq_samples_heatMap$$";
    my $outFile = "$tmp_dir/$id.png";
    my $n_rows  = @$sampleOids_ref;
    my $n_cols  = @$geneIds_ref;

    my $args = {
	id         => $id,
	n_rows     => $n_rows,
	n_cols     => $n_cols,
	image_file => $outFile,
	taxon_aref => $sampleOids_ref,
	use_colors => "all"
    };
    my $hm = new ProfileHeatMap($args);
    my $html =
	$hm->drawSpecial
	( $table_ref, $sampleOids_ref, $geneIds_ref, $rowDict_ref,
	  $colDict_ref, $normTable_ref, $stateFile, 1 );
    $hm->printToFile();
    print "$html\n";
}

sub getNameForSample {
    my ($dbh, $sample) = @_;
    my $names_ref = getNamesForSamples($dbh, $sample);
    return $names_ref->{ $sample };
}

sub getNamesForSamples {
    my ($dbh, $sample_oid_str) = @_;
    my %sampleNames;

    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select dts.dataset_oid, gsp.display_name
        from rnaseq_dataset dts,
             gold_sequencing_project\@imgsg_dev gsp
        where dts.gold_id = gsp.gold_id
        and dts.dataset_oid in ($sample_oid_str)
        $datasetClause
    };
    my $cur = execSql( $dbh, $sql, $verbose );
    for( ;; ) {
	my( $sid, $sname ) = $cur->fetchrow();
	last if !$sid;
	$sampleNames{ $sid } = $sname;
    }
    $cur->finish();
    return \%sampleNames;
}

sub datasetClause {
    my ($alias) = @_;

    if (!$user_restricted_site) {
        return " and $alias.is_public = 'Yes' ";
    }

    my $dataset_oid_attr = "dataset_oid";
    $dataset_oid_attr = "$alias.dataset_oid"
        if $alias ne ""
        && $alias ne "dataset_oid"
        && $alias !~ /\./;

    $dataset_oid_attr = $alias
        if $alias ne ""
        && $alias ne "dataset_oid"
        && $alias =~ /\./;

    #my $whichIMGClause = " rdt.dataset_type = 'Metatranscriptome' ";
    #$whichIMGClause = " rdt.dataset_type = 'Transcriptome' " if $img_er;
# where $whichIMGClause
    my $clause = qq{
        and $dataset_oid_attr in
            ( select rdt.dataset_oid
              from rnaseq_dataset rdt

            )
        };

    my $super_user = getSuperUser();
    return $clause if ( $super_user eq "Yes" );
    my $contact_oid = getContactOid();
    return $clause if !$contact_oid;

#               and $whichIMGClause
    my $clause = qq{
        and $dataset_oid_attr in
            ( select rdt.dataset_oid
              from rnaseq_dataset rdt
              where rdt.is_public = 'Yes'

              union all
              select crdp.dataset_oid
              from contact_rna_data_permissions crdp
              where crdp.contact_oid = $contact_oid
            )
        };

    return $clause;
}


sub printDifferentialExpression {
    printMainForm();
    printStatusLine( "Loading ...", 1 );

    my $contact_oid = WebUtil::getContactOid();

    my $taxon_oid = param("taxon_oid");
    my $dbh = dbLogin();
    my ($taxon_name, $in_file, $genome_type)
        = QueryUtil::fetchSingleTaxonNameGenomeType( $dbh, $taxon_oid );

    WebUtil::printHeaderWithInfo("RNASeq Gene Differential Expression Data");
    my $url = "$main_cgi?section=TaxonDetail"
	. "&page=taxonDetail&taxon_oid=$taxon_oid";
    print "<p style='width: 650px;'>";
    print "Genome: ".alink($url, $taxon_name, "_blank");
    print "</p>\n";

    my ($datasetIds_ref, $dataset2name_href, $gene2dataset2read_href,
	$gene2locus_href) = processDifferentialExpression($dbh, $taxon_oid);

    if (scalar(@$datasetIds_ref) <= 0) {
        print "<p>\n";
        print "No results returned.\n";
        print "</p>\n";
        printStatusLine( "0 genes retrieved.", 2 );
        print end_form();
        return;
    }

    # create export file
    my $sessionId  = getSessionId();
    my $exportfile = $taxon_oid . "DE$$-" . $sessionId;
    my $exportPath = "$cgi_tmp_dir/$exportfile";
    my $res        = newWriteFileHandle( $exportPath, "runJob" );

    # create table headers and export headers
    my $it = new InnerTable(1, "rnasdedata$$", "rnasdedata", 1);
    my $sd = $it->getSdDelim();
    $it->addColSpec( "Select" );
    $it->addColSpec( "Gene ID", "asc", "right" );
    $it->addColSpec( "Locus Tag", "asc",  "left" );
    print $res "Gene\t";

    my $datasetSize = scalar(@$datasetIds_ref);
    my $datasetCnt = 0;
    foreach my $dataset_oid (@$datasetIds_ref) {
        $datasetCnt++;
        my $dataset_name = $dataset2name_href->{$dataset_oid};
        $it->addColSpec( $dataset_oid, "asc", "right", '', $dataset_name );
        if ($datasetCnt == $datasetSize) {
            print $res "$dataset_oid";
        } else {
            print $res "$dataset_oid\t";
        }
    }
    print $res "\n";

    my $count;
    my $trunc;

    foreach my $gene_oid (keys %$gene2dataset2read_href) {
        #last if $trunc;
        my $row;

        my $locus_tag = $gene2locus_href->{$gene_oid};
        if ( ! $trunc ) {
            my $url1 = "$main_cgi?section=GeneDetail"
		. "&page=geneDetail&gene_oid=$gene_oid";
            if ($in_file eq "Yes") {
                $url1 = "$main_cgi?section=MetaGeneDetail"
                      . "&page=metaGeneDetail&gene_oid=$gene_oid"
                      . "&data_type=assembled&taxon_oid=$taxon_oid";
            }
            $row = $sd . "<input type='checkbox' "
                . "name='gene_oid' value='$gene_oid'/>\t";
            $row .= $gene_oid . $sd . alink($url1, $gene_oid, "_blank") . "\t";
            $row .= $locus_tag . $sd . $locus_tag . "\t";
        }
        print $res "$locus_tag\t";

        my $dataset2read_href = $gene2dataset2read_href->{$gene_oid};
        $datasetCnt = 0;
        foreach my $dataset_oid (@$datasetIds_ref) {
            $datasetCnt++;
            my $readsCount = $dataset2read_href->{$dataset_oid};

            if (! $trunc) {
                $row .= $readsCount . $sd . $readsCount . "\t";
            }

            if (! $readsCount) {
                $readsCount = 0;
            }
            if ($datasetCnt == $datasetSize) {
                print $res "$readsCount";
            } else {
                print $res "$readsCount\t";
            }
        }

        if ( ! $trunc ) {
            chop $row; # remove the last \t
            $it->addRow($row);
        }
        print $res "\n";

        $count++;
        if ($count >= $maxGeneListResults) {
            $trunc = 1;
        }
    }
    close $res;

    if ($count > 10) {
        printExportLinkForDE( $contact_oid, $exportfile );
        printGeneCartFooter();
    }
    $it->printOuterTable(1);
    printGeneCartFooter();
    printExportLinkForDE( $contact_oid, $exportfile );

    if ($trunc) {
        my $s = "Results limited to $maxGeneListResults genes.\n";
        $s .= "( Go to " . alink($preferences_url, "Preferences")
        . " to change \"Max. Gene List Results\". )\n";
        printStatusLine($s, 2);
    } else {
        printStatusLine("$count genes loaded.", 2);
    }

    print end_form();
}

sub processDifferentialExpression {
    my ( $dbh, $taxon_oid ) = @_;

    my $datasetClause = datasetClause("dts");
    my $sql = qq{
        select distinct dts.dataset_oid
        from rnaseq_dataset dts
        where dts.reference_taxon_oid = ?
        $datasetClause
    };

    my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
    my @datasetIds;
    for ( ;; ) {
    my ($dataset_oid) = $cur->fetchrow();
        last if !$dataset_oid;
        push(@datasetIds, $dataset_oid);
    }
    $cur->finish();

    my @validDatasetIds;
    my %dataset2name;
    my %gene2dataset2read;
    my %gene2locus;

    if ( scalar(@datasetIds) > 0 ) {
        my $dataset_oid_str =
	    OracleUtil::getNumberIdsInClause($dbh, @datasetIds);
        my $sql = qq{
            select distinct dts.dataset_oid, gsp.display_name
            from rnaseq_dataset dts,
                 gold_sequencing_project\@imgsg_dev gsp
            where dts.gold_id = gsp.gold_id
            and dts.reference_taxon_oid = ?
            and dts.dataset_oid in ( $dataset_oid_str )
            $datasetClause
        };
        my $cur = execSql( $dbh, $sql, $verbose, $taxon_oid );
        for ( ;; ) {
            my ($dataset_oid, $desc) = $cur->fetchrow();
            last if !$dataset_oid;
            $dataset2name{$dataset_oid} = $desc
        }
        $cur->finish();

        @validDatasetIds = keys %dataset2name;
        my ($dataset2gene2info_href) = MetaUtil::getGenesForRNASeqSamples
	    (\@validDatasetIds, $taxon_oid);
        if ($dataset2gene2info_href) {
            foreach my $dataset_oid (keys %$dataset2gene2info_href) {
                my $gene2info_href = $dataset2gene2info_href->{$dataset_oid};

                foreach my $gene_oid (keys %$gene2info_href) {
                    my $info = $gene2info_href->{$gene_oid};
                    my ($geneid, $locus_type, $locus_tag, $strand,
                        $scaffold_oid, $dna_seq_length, $reads_cnt, @rest)
			= split( "\t", $info );
                    $gene2locus{$gene_oid} = $locus_tag;
                    my $dataset2read_href = $gene2dataset2read{$gene_oid};
                    if (! $dataset2read_href) {
                        my %dataset2read;
                        $dataset2read_href = \%dataset2read;
                        $gene2dataset2read{$gene_oid} = $dataset2read_href;
                    }
                    $dataset2read_href->{$dataset_oid} = $reads_cnt;
                }
            }
        } else {
            my $sql = qq{
                select distinct es.IMG_gene_oid, g.locus_tag,
                       es.dataset_oid, es.reads_cnt
                from rnaseq_expression es, gene g
                where es.dataset_oid in ( $dataset_oid_str )
                and es.reads_cnt > 0.0000000
                and g.gene_oid = es.IMG_gene_oid
            };
            my $cur = execSql( $dbh, $sql, $verbose );
            for ( ;; ) {
                my ($gene_oid, $locus_tag,$dataset_oid, $reads_cnt)
		    = $cur->fetchrow();
                last if !$gene_oid;

                $gene2locus{$gene_oid} = $locus_tag;
                my $dataset2read_href = $gene2dataset2read{$gene_oid};
                if (! $dataset2read_href) {
                    my %dataset2read;
                    $dataset2read_href = \%dataset2read;
                    $gene2dataset2read{$gene_oid} = $dataset2read_href;
                }
                $dataset2read_href->{$dataset_oid} = $reads_cnt;
            }
            $cur->finish();
        }

        OracleUtil::truncTable( $dbh, "gtt_num_id" )
            if ( $dataset_oid_str =~ /gtt_num_id/i );
    }

    return (\@validDatasetIds, \%dataset2name,
	    \%gene2dataset2read, \%gene2locus);
}

# export DE link
sub printExportLinkForDE {
    my ( $contact_oid, $exportfile ) = @_;

    print qq{
        <p>
        <a href='main.cgi?section=$section&page=downloadDEInTab&file=$exportfile&noHeader=1' onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link downloadDEInTab']);\">
        Export data in Tab-Delimited format</a>
        <br/>
        <a href='main.cgi?section=$section&page=downloadDEInRData&file=$exportfile&noHeader=1' onclick=\"_gaq.push(['_trackEvent', 'Export', '$contact_oid', 'img link downloadDEInRData']);\">
        Export data in RData binary format for DESeq2, EdgeR, or BaySeq</a>
        </p>
    };
}

# we assume file is located at $cgi_tmp_dir
sub downloadDEInTab {
    my $file = param("file");
    my $path = "$cgi_tmp_dir/$file";
    if ( !-e $path ) {
        webErrorHeader
	    ("Export file no longer exist. Please go back and refresh page.");
    }

    print "Content-type: application/text\n";
    print "Content-Disposition: inline; filename=$file.txt\n";
    print "\n";

    my $rfh = newReadFileHandle( $path, "download" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}

# we assume file is located at $cgi_tmp_dir
sub downloadDEInRData {
    my $file = param("file");
    my $inputFile = "$cgi_tmp_dir/$file";
    my $outFileName = $file . ".RData";
    my $outputFile = "$cgi_tmp_dir/$outFileName";
    generateRDataFile($inputFile, $outputFile);
    if ( !-e $outputFile ) {
        webErrorHeader
	    ("Export file no longer exist. Please go back and refresh page.");
    }

    print "Content-type: application/octet-stream\n";
    print "Content-Disposition: inline; filename=$outFileName\n";
    print "\n";

    my $rfh = newReadFileHandle( $outputFile, "download" );
    while ( my $s = $rfh->getline() ) {
        chomp $s;
        print "$s\n";
    }
    close $rfh;
}

sub generateRDataFile {
    my ($inputFile, $outputFile) = @_;
    if ( !-e $inputFile ) {
        webErrorHeader("Input file no longer exist. Please refresh page.");
    }

    my $program = "$cgi_dir/bin/exportDE.R";
    if ( !-e $program ) {
        webErrorHeader("Cannot find the script file " . $program);
    }

    # keep it as example:
    #WebUtil::unsetEnvPath();
    #my $env = "PATH='/bin:/usr/bin'; export PATH";
    #my $cmd = "$env; $r_bin --slave "
    #    . "--args '$inputFile' '$outputFile' < $program > /dev/null";
    #$cmd = each %{{$cmd,0}};  # untaint the variable to make it safe for Perl
    #my $st = system($cmd);
    #WebUtil::resetEnvPath();

    WebUtil::unsetEnvPath();
    my $cmd = "$R --slave --args "
        . "'$inputFile' '$outputFile' < $program > /dev/null";
    $cmd = each %{{$cmd,0}};  # untaint the variable to make it safe for Perl

    webLog("generateRDataFile() cmd=$cmd\n");
    my $st = system($cmd);
    WebUtil::resetEnvPath();

    if ($st != 0) {
        webError( "Problem running R script: $program." );
    }
}


1;

